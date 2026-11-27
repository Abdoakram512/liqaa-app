import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ai/audio_recorder_service.dart';
import '../../../core/ai/models/pronunciation_assessment.dart';
import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/ai/pronunciation_repository.dart';
import '../../../core/animation/yasser/yasser_viseme.dart';
import '../../../core/audio/yasser_audio_coordinator.dart';
import '../../home/data/child_progress_service.dart';
import '../models/yasser_prompt.dart';
import 'pronunciation_game_state.dart';

typedef AttemptEvaluatedCallback =
    Future<void> Function(
      VocabularyWord word,
      PronunciationAssessment assessment,
    );

class PronunciationGameCubit extends Cubit<PronunciationGameState>
    with WidgetsBindingObserver {
  final PronunciationRepository _repository;
  final AudioPlayer _audioPlayer;
  final YasserAudioCoordinator? _audioCoordinator;
  final ChildProgressService? _progressService;
  final AttemptEvaluatedCallback? _onAttemptEvaluated;
  final String? _categoryFilter;
  final List<String>? _targetPhonemeFilter;

  late final StreamSubscription<double> _amplitudeSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<PlayerState> _playbackSubscription;

  YasserPrompt? _prompt;
  Future<void>? _startingPrompt;
  Future<void>? _startingRecording;
  bool _closing = false;
  int _evalSeq = 0;
  final Set<String> _masteredWordIds = {};

  bool get _speechModelsReady =>
      _repository.vadEngine.isNativeAvailable &&
      _repository.phonemeEngine.isNativeAvailable;

  bool get _canInteract =>
      !_closing &&
      _startingRecording == null &&
      _startingPrompt == null &&
      _prompt == null &&
      !state.isListening &&
      state.status != GameStatus.evaluating &&
      state.status != GameStatus.loading;

  PronunciationGameCubit(
    this._repository, {
    AudioPlayer? audioPlayer,
    YasserAudioCoordinator? audioCoordinator,
    ChildProgressService? progressService,
    AttemptEvaluatedCallback? onAttemptEvaluated,
    String? categoryFilter,
    List<String>? targetPhonemeFilter,
    String? activeCaseName,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer(),
       _audioCoordinator = audioCoordinator,
       _progressService = progressService,
       _onAttemptEvaluated = onAttemptEvaluated,
       _categoryFilter = categoryFilter,
       _targetPhonemeFilter = targetPhonemeFilter,
       super(PronunciationGameState(activeCaseName: activeCaseName)) {
    _amplitudeSubscription = _repository.recorder.amplitudeStream.listen((amp) {
      if (!_closing && state.isListening) {
        emit(state.copyWith(liveAmplitude: amp));
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (_closing || !state.isPlayingAudioPrompt) return;
      final pose = _prompt?.poseAt(position) ?? YasserViseme.rest;
      if (pose != state.promptViseme) {
        emit(state.copyWith(promptViseme: pose));
      }
    });

    _playbackSubscription = _audioPlayer.onPlayerStateChanged.listen((
      playback,
    ) {
      if (_closing || _prompt == null) return;
      if (playback == PlayerState.playing) {
        emit(
          state.copyWith(
            status: GameStatus.readyToSpeak,
            isPlayingAudioPrompt: true,
          ),
        );
      } else if (state.isPlayingAudioPrompt ||
          playback == PlayerState.completed) {
        _clearPrompt(announceTurn: true);
      }
    });

    _audioCoordinator?.registerExternalAudioStopHook(_stopGamePromptAudio);
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  Future<void> _stopGamePromptAudio() async {
    _prompt = null;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    if (!_closing && state.isPlayingAudioPrompt) {
      emit(
        state.copyWith(
          isPlayingAudioPrompt: false,
          promptViseme: YasserViseme.rest,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closing) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_handleBackgroundInterruption());
    }
  }

  Future<void> _handleBackgroundInterruption() async {
    await _stopGamePromptAudio();
    if (state.isListening || _repository.recorder.isRecording) {
      await _repository.recorder.cancelRecording();
      _audioCoordinator?.exitRecordingSession();
      if (!_closing) {
        emit(
          state.copyWith(
            isListening: false,
            liveAmplitude: 0.0,
            status: GameStatus.readyToSpeak,
            yasserMessage: 'تقدر تضغط على المايك وتكمل التدريب لما تكون جاهز!',
            yasserPose: 'waving',
          ),
        );
      }
    }
  }

  List<VocabularyWord> _filterWords(List<VocabularyWord> allWords) {
    if (allWords.isEmpty) return allWords;

    if (_targetPhonemeFilter != null && _targetPhonemeFilter.isNotEmpty) {
      final filtered = allWords
          .where((w) => _targetPhonemeFilter.contains(w.targetPhoneme))
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }

    if (_categoryFilter != null && _categoryFilter.isNotEmpty) {
      const frontOral = {'ب', 'م', 'ت', 'د', 'ل', 'ن', 'ر'};
      const fricatives = {'س', 'ز', 'ش', 'ف', 'ث', 'ذ', 'ه'};
      const backEmphatic = {
        'ك',
        'ق',
        'ج',
        'خ',
        'غ',
        'ع',
        'ح',
        'ط',
        'ص',
        'ض',
        'ظ',
      };

      final Set<String>? allowed = switch (_categoryFilter) {
        'front_oral' => frontOral,
        'fricatives' => fricatives,
        'back_emphatic' => backEmphatic,
        _ => null,
      };
      if (allowed != null) {
        final subset = allWords
            .where((w) => allowed.contains(w.targetPhoneme))
            .toList();
        if (subset.isNotEmpty) return subset;
      }
    }

    return allWords;
  }

  /// Initializes game session and loads vocabulary cards.
  Future<void> initializeGame() async {
    emit(state.copyWith(status: GameStatus.loading, clearError: true));
    try {
      await _repository.initialize();
      if (_closing) return;
      final words = _filterWords(_repository.vocabulary);
      final currentWord = words.isNotEmpty ? words.first : null;

      emit(
        state.copyWith(
          status: _speechModelsReady
              ? GameStatus.readyToSpeak
              : GameStatus.error,
          errorMessage: _speechModelsReady
              ? null
              : 'التدريب الصوتي مش جاهز دلوقتي على الجهاز ده. جرّب تاني.',
          words: words,
          currentWordIndex: 0,
          currentWord: currentWord,
          yasserMessage: _speechModelsReady
              ? 'أهلاً بيك يا بطل! يلا ندوس على المايك وننطق سوا!'
              : 'التدريب الصوتي مش جاهز دلوقتي. جرّب تاني.',
          yasserPose: 'waving',
        ),
      );
    } catch (e) {
      if (_closing) return;
      emit(
        state.copyWith(
          status: GameStatus.error,
          errorMessage: 'فشل تحميل الكلمات: $e',
        ),
      );
    }
  }

  /// Selects a specific word card by index.
  void selectWord(int index) {
    if (!_canInteract || index < 0 || index >= state.words.length) return;
    final word = state.words[index];
    emit(
      state.copyWith(
        currentWordIndex: index,
        currentWord: word,
        status: GameStatus.readyToSpeak,
        clearAssessment: true,
        clearError: true,
        yasserMessage: 'يلا ننطق كلمة "${word.wordArabic}" مع ياسر!',
        yasserPose: 'waving',
      ),
    );
  }

  /// Advances to next word or completes the session at the end of a specialist/child deck.
  void nextWord() {
    if (state.words.isEmpty) return;
    final nextIndex = (state.currentWordIndex + 1) % state.words.length;
    selectWord(nextIndex);
  }

  /// Goes to previous word in dictionary.
  void previousWord() {
    if (state.words.isEmpty) return;
    final prevIndex =
        (state.currentWordIndex - 1 + state.words.length) % state.words.length;
    selectWord(prevIndex);
  }

  /// Transitions to the celebratory session summary screen.
  Future<void> finishSession() async {
    if (!_canInteract) return;
    await _progressService?.recordCompletedSession();
    _audioCoordinator?.playSfx(YasserSfx.sessionComplete);
    if (_closing) return;
    emit(
      state.copyWith(
        status: GameStatus.sessionCompleted,
        yasserMessage: YasserVoiceCue.sessionCompleted.arabicText,
        yasserPose: 'celebrating',
      ),
    );
  }

  /// Resets to the first card for another practice round.
  void restartSession() {
    if (state.words.isEmpty) return;
    selectWord(0);
  }

  /// Starts child recording with strict playback mutual exclusion & cleanup guard.
  Future<void> startListening() async {
    if (!_canInteract || state.currentWord == null) return;

    await _audioCoordinator?.enterRecordingSession();

    Future<void>? startOp;
    try {
      if (!_speechModelsReady) {
        emit(
          state.copyWith(
            status: GameStatus.loading,
            clearAssessment: true,
            clearError: true,
          ),
        );
        if (!_repository.vadEngine.isNativeAvailable) {
          await _repository.vadEngine.initialize();
        }
        if (!_repository.phonemeEngine.isNativeAvailable) {
          await _repository.phonemeEngine.initialize();
        }
        if (_closing) {
          _audioCoordinator?.exitRecordingSession();
          return;
        }
        if (!_speechModelsReady) {
          _audioCoordinator?.exitRecordingSession();
          emit(
            state.copyWith(
              status: GameStatus.error,
              errorMessage: 'التدريب الصوتي مش جاهز دلوقتي. جرّب تاني.',
              yasserMessage: 'التدريب الصوتي مش جاهز دلوقتي. جرّب تاني.',
              yasserPose: 'thinking',
            ),
          );
          return;
        }
      }

      emit(
        state.copyWith(
          status: GameStatus.preparingRecording,
          clearAssessment: true,
          clearError: true,
        ),
      );

      startOp = _repository.recorder.startRecording();
      _startingRecording = startOp;
      await startOp;

      if (_closing) {
        await _repository.recorder.cancelRecording();
        _audioCoordinator?.exitRecordingSession();
        return;
      }

      emit(
        state.copyWith(
          isListening: true,
          clearAssessment: true,
          status: GameStatus.listening,
          yasserMessage: 'ياسر سامعك.. اتكلم بوضوح يا بطل!',
          yasserPose: 'thinking',
        ),
      );
    } on AudioRecordingException catch (e) {
      _audioCoordinator?.exitRecordingSession();
      if (_closing) return;
      final String msg = switch (e.kind) {
        AudioRecordingErrorKind.permissionDenied =>
          'محتاجين إذن الميكروفون علشان نسمع صوتك يا بطل!',
        AudioRecordingErrorKind.micBusy =>
          'الميكروفون مشغول دلوقتي.. استنى ثانية وجرّب تاني.',
        _ => 'حصل مشكلة في فتح الميكروفون.. جاهزين نجرب تاني!',
      };
      emit(
        state.copyWith(
          isListening: false,
          status: GameStatus.error,
          errorMessage: e.toString(),
          yasserMessage: msg,
          yasserPose: 'thinking',
        ),
      );
    } catch (e) {
      _audioCoordinator?.exitRecordingSession();
      if (_closing) return;
      emit(
        state.copyWith(
          isListening: false,
          status: GameStatus.error,
          errorMessage: 'فشل فتح الميكروفون: $e',
          yasserMessage:
              'مقدرتش أفتح المايك.. اتأكد من صلاحية الميكروفون وجرّب تاني.',
          yasserPose: 'thinking',
        ),
      );
    } finally {
      if (identical(_startingRecording, startOp)) {
        _startingRecording = null;
      }
    }
  }

  /// Stops recording and runs real on-device evaluation with honest error differentiation.
  Future<void> stopListeningAndEvaluate() async {
    if (_closing || !state.isListening) return;
    final int evalSeq = ++_evalSeq;
    emit(
      state.copyWith(
        isListening: false,
        liveAmplitude: 0.0,
        status: GameStatus.evaluating,
      ),
    );

    try {
      final Uint8List rawBytes = await _repository.recorder.stopRecording();
      _audioCoordinator?.exitRecordingSession(playStopChime: false);

      if (_closing || evalSeq != _evalSeq) return;
      final word = state.currentWord;

      if (word == null) {
        emit(
          state.copyWith(
            status: GameStatus.error,
            clearAssessment: true,
            errorMessage: 'لم يتم تحديد كلمة للتدريب.',
            yasserPose: 'thinking',
          ),
        );
        return;
      }

      if (rawBytes.isEmpty) {
        emit(
          state.copyWith(
            status: GameStatus.error,
            clearAssessment: true,
            errorMessage:
                _repository.recorder.lastError ?? 'لم يتم تسجيل بيانات صوتية.',
            yasserMessage:
                'تعذّر تسجيل الصوت من الميكروفون.. تأكد من الصلاحية وجرب تاني.',
            yasserPose: 'thinking',
          ),
        );
        return;
      }

      // Run real ONNX AI pipeline (Preprocessor -> Silero VAD -> Conditional GTCRN -> Wav2Vec2 -> Evaluator)
      final assessment = await _repository.evaluateAudio(
        rawAudioBytes: rawBytes,
        targetWord: word,
      );

      if (_closing || evalSeq != _evalSeq) return;

      if (assessment.errorType.isSystemFailure ||
          (assessment.passed && assessment.recognizedPhonemes.isEmpty)) {
        emit(
          state.copyWith(
            status: GameStatus.error,
            clearAssessment: true,
            errorMessage:
                assessment.diagnosticError ?? 'تعذّر تحليل الصوت. جرّب تاني.',
            yasserMessage: assessment.yasserFeedbackMessage,
            yasserPose: 'thinking',
          ),
        );
        return;
      }

      // Technical/inconclusive cases (digital silence, weak RMS, undetected VAD, low confidence)
      // MUST NOT count as failed pronunciation attempts against child clinical progress.
      final bool countProgress =
          !assessment.errorType.isInconclusiveOrTechnical;
      if (countProgress) {
        await _progressService?.recordPracticeAttempt(
          wordId: word.id,
          wordArabic: word.wordArabic,
          passed:
              assessment.passed &&
              assessment.errorType == AssessmentErrorType.correct,
          starsAwarded: assessment.stars,
        );
        if (_onAttemptEvaluated != null) {
          await _onAttemptEvaluated(word, assessment);
        }
      }
      if (_closing || evalSeq != _evalSeq) return;

      if (assessment.passed &&
          assessment.errorType == AssessmentErrorType.correct) {
        final firstMastery = _masteredWordIds.add(word.id);
        final newStars =
            state.totalStarsEarned + (firstMastery ? assessment.stars : 0);
        final newMastered = _masteredWordIds.length;

        _audioCoordinator?.playSfx(YasserSfx.starReward);

        emit(
          state.copyWith(
            status: GameStatus.successCelebration,
            lastAssessment: assessment,
            totalStarsEarned: newStars,
            wordsMasteredCount: newMastered,
            attemptsCount: state.attemptsCount + 1,
            yasserMessage: assessment.yasserFeedbackMessage,
            yasserPose: assessment.yasserPose,
          ),
        );
      } else {
        _audioCoordinator?.playSfx(
          assessment.errorType == AssessmentErrorType.noSpeech ||
                  assessment.errorType == AssessmentErrorType.poorAudioQuality
              ? YasserSfx.retryGentle
              : YasserSfx.retryGentle,
        );

        emit(
          state.copyWith(
            status: GameStatus.supportiveHint,
            lastAssessment: assessment,
            attemptsCount: countProgress
                ? state.attemptsCount + 1
                : state.attemptsCount,
            yasserMessage: assessment.yasserFeedbackMessage,
            yasserPose: assessment.yasserPose == 'celebrating'
                ? 'thinking'
                : assessment.yasserPose,
          ),
        );
      }
    } catch (e) {
      _audioCoordinator?.exitRecordingSession();
      if (_closing || evalSeq != _evalSeq) return;
      emit(
        state.copyWith(
          status: GameStatus.error,
          clearAssessment: true,
          errorMessage: e.toString(),
          yasserMessage: 'تعذّر تسجيل أو تحليل الصوت. جرّب تاني.',
          yasserPose: 'thinking',
        ),
      );
    }
  }

  Future<void> playYasserAudioPrompt() async {
    if (!_canInteract) return;
    if (_audioCoordinator != null && !_audioCoordinator.voiceEnabled) {
      emit(
        state.copyWith(
          yasserMessage: 'صوت ياسر متوقف من الإعدادات. تقدر تشغّله في أي وقت!',
        ),
      );
      return;
    }

    final prompt = YasserPrompt.byWordId[state.currentWord?.id];
    if (prompt == null) return;

    _prompt = prompt;
    emit(
      state.copyWith(
        status: GameStatus.preparingPrompt,
        yasserMessage: 'اسمع الكلمة من ياسر، وبعدها جرّب تقولها!',
        yasserPose: 'pointing',
      ),
    );

    try {
      final starting = _audioPlayer.play(AssetSource(prompt.assetPath));
      _startingPrompt = starting;
      await starting;
      if (!_closing && _prompt != null) {
        if (_audioPlayer.state == PlayerState.playing) {
          emit(
            state.copyWith(
              status: GameStatus.readyToSpeak,
              isPlayingAudioPrompt: true,
            ),
          );
        } else {
          _clearPrompt(announceTurn: false);
        }
      }
    } catch (_) {
      if (_closing) return;
      _clearPrompt(announceTurn: false);
      emit(
        state.copyWith(
          yasserMessage: 'مش قادر أشغّل المثال دلوقتي. جرّب تاني.',
        ),
      );
    } finally {
      _startingPrompt = null;
    }
  }

  void _clearPrompt({required bool announceTurn}) {
    _prompt = null;
    emit(
      state.copyWith(
        status: state.status == GameStatus.preparingPrompt
            ? GameStatus.readyToSpeak
            : state.status,
        isPlayingAudioPrompt: false,
        promptViseme: YasserViseme.rest,
        yasserMessage: announceTurn
            ? 'دلوقتي دورك يا بطل! اضغط على الميكروفون وقول الكلمة.'
            : state.yasserMessage,
      ),
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    final startingRecording = _startingRecording;
    final startingPrompt = _startingPrompt;
    final wasListening = state.isListening;

    await _amplitudeSubscription.cancel();
    await _positionSubscription.cancel();
    await _playbackSubscription.cancel();

    try {
      await startingPrompt;
    } catch (_) {}

    bool shouldCancelRecording = wasListening;
    try {
      if (startingRecording != null) {
        try {
          await startingRecording;
          shouldCancelRecording = true;
        } catch (_) {}
      }
      if (shouldCancelRecording) {
        await _repository.recorder.cancelRecording();
      }
    } finally {
      _audioCoordinator?.unregisterExternalAudioStopHook(_stopGamePromptAudio);
      _audioCoordinator?.exitRecordingSession();
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      try {
        await _audioPlayer.dispose();
      } finally {
        await super.close();
      }
    }
  }
}
