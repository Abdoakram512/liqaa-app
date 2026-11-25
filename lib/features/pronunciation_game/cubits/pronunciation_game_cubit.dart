import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ai/models/pronunciation_assessment.dart';
import '../../../core/ai/pronunciation_repository.dart';
import '../../../core/animation/yasser/yasser_viseme.dart';
import '../models/yasser_prompt.dart';
import 'pronunciation_game_state.dart';

class PronunciationGameCubit extends Cubit<PronunciationGameState> {
  final PronunciationRepository _repository;
  final AudioPlayer _audioPlayer;
  late final StreamSubscription<double> _amplitudeSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<PlayerState> _playbackSubscription;
  YasserPrompt? _prompt;
  Future<void>? _startingPrompt;
  Future<void>? _startingRecording;
  final _masteredWordIds = <String>{};
  bool _closing = false;

  PronunciationGameCubit(this._repository, {AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer(),
      super(const PronunciationGameState()) {
    _amplitudeSubscription = _repository.recorder.amplitudeStream.listen((amp) {
      if (!_closing && state.isListening) {
        emit(state.copyWith(liveAmplitude: amp));
      }
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (_closing || !state.isPlayingAudioPrompt) return;
      final pose = _prompt?.poseAt(position) ?? YasserViseme.rest;
      if (pose != state.promptViseme) emit(state.copyWith(promptViseme: pose));
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
        _clearPrompt();
      }
    });
  }

  /// Initializes game session and loads 28 vocabulary cards
  Future<void> initializeGame() async {
    emit(state.copyWith(status: GameStatus.loading));
    try {
      await _repository.initialize();
      if (_closing) return;
      final words = _repository.vocabulary;
      final currentWord = words.isNotEmpty ? words.first : null;

      emit(
        state.copyWith(
          status: GameStatus.readyToSpeak,
          words: words,
          currentWordIndex: 0,
          currentWord: currentWord,
          yasserMessage: 'أهلاً بيك يا بطل! يلا ندوس على المايك وننطق سوا!',
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

  /// Selects a specific word card by index
  void selectWord(int index) {
    if (_closing ||
        !state.canChooseWord ||
        index < 0 ||
        index >= state.words.length) {
      return;
    }
    final word = state.words[index];
    emit(
      state.copyWith(
        currentWordIndex: index,
        currentWord: word,
        status: GameStatus.readyToSpeak,
        clearAssessment: true,
        yasserMessage: 'يلا ننطق كلمة "${word.wordArabic}" مع ياسر!',
        yasserPose: 'waving',
      ),
    );
  }

  /// Advances to next word in dictionary
  void nextWord() {
    if (state.words.isEmpty) return;
    final nextIndex = (state.currentWordIndex + 1) % state.words.length;
    selectWord(nextIndex);
  }

  /// Goes to previous word in dictionary
  void previousWord() {
    if (state.words.isEmpty) return;
    final prevIndex =
        (state.currentWordIndex - 1 + state.words.length) % state.words.length;
    selectWord(prevIndex);
  }

  /// Starts child recording
  Future<void> startListening() async {
    if (_closing || !state.canStartAudio) return;
    emit(
      state.copyWith(
        status: GameStatus.preparingRecording,
        clearAssessment: true,
        liveAmplitude: 0,
        yasserMessage: 'ثانية واحدة، بنجهّز الميكروفون.',
        yasserPose: 'thinking',
      ),
    );
    try {
      final starting = _repository.recorder.startRecording();
      _startingRecording = starting;
      await starting;
      if (_closing) return;
      emit(
        state.copyWith(
          isListening: true,
          clearAssessment: true,
          status: GameStatus.listening,
          yasserMessage: 'ياسر سامعك.. اتكلم يا بطل!',
          yasserPose: 'thinking',
        ),
      );
    } catch (e) {
      if (_closing) return;
      emit(
        state.copyWith(
          isListening: false,
          status: GameStatus.error,
          yasserMessage: 'اتأكد إن إذن الميكروفون مفتوح وجرب تاني.',
          errorMessage: 'فشل فتح الميكروفون: $e',
        ),
      );
    } finally {
      _startingRecording = null;
    }
  }

  /// Stops recording and runs real on-device evaluation with honest error differentiation
  Future<void> stopListeningAndEvaluate() async {
    if (_closing || !state.isListening) return;
    emit(
      state.copyWith(
        isListening: false,
        liveAmplitude: 0,
        status: GameStatus.evaluating,
        yasserMessage: 'ثانية واحدة، بنراجع التسجيل.',
      ),
    );

    try {
      final Uint8List rawBytes = await _repository.recorder.stopRecording();
      if (_closing) return;
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

      // Run AI pipeline
      final assessment = await _repository.evaluateAudio(
        rawAudioBytes: rawBytes,
        targetWord: word,
      );

      if (_closing) return;
      if (assessment.errorType.isSystemFailure) {
        emit(
          state.copyWith(
            status: GameStatus.error,
            lastAssessment: assessment,
            errorMessage:
                assessment.diagnosticError ?? assessment.clinicalErrorName,
            yasserMessage: assessment.yasserFeedbackMessage,
            yasserPose: 'thinking',
          ),
        );
      } else if (assessment.passed &&
          assessment.errorType == AssessmentErrorType.correct) {
        final newStars = state.totalStarsEarned + assessment.stars;
        _masteredWordIds.add(word.id);

        emit(
          state.copyWith(
            status: GameStatus.successCelebration,
            lastAssessment: assessment,
            totalStarsEarned: newStars,
            wordsMasteredCount: _masteredWordIds.length,
            yasserMessage: assessment.yasserFeedbackMessage,
            yasserPose: assessment.yasserPose,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: GameStatus.supportiveHint,
            lastAssessment: assessment,
            yasserMessage: assessment.yasserFeedbackMessage,
            yasserPose: assessment.yasserPose == 'celebrating'
                ? 'thinking'
                : assessment.yasserPose,
          ),
        );
      }
    } catch (e) {
      if (_closing) return;
      emit(
        state.copyWith(
          status: GameStatus.error,
          clearAssessment: true,
          errorMessage: e.toString(),
          yasserMessage: 'تعذّر تسجيل أو تحليل الصوت: $e',
          yasserPose: 'thinking',
        ),
      );
    }
  }

  Future<void> playYasserAudioPrompt() async {
    if (_closing || !state.canStartAudio || _startingPrompt != null) return;
    final prompt = YasserPrompt.byWordId[state.currentWord?.id];
    if (prompt == null) return;

    _prompt = prompt;
    emit(
      state.copyWith(
        status: GameStatus.preparingPrompt,
        clearAssessment: true,
        yasserMessage: 'اسمع الكلمة من ياسر، وبعدها جرّب تقولها.',
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
          _clearPrompt();
        }
      }
    } catch (_) {
      if (_closing) return;
      _clearPrompt();
      emit(
        state.copyWith(
          yasserMessage: 'مش قادر أشغّل المثال دلوقتي. جرّب تاني.',
        ),
      );
    } finally {
      _startingPrompt = null;
    }
  }

  void _clearPrompt() {
    _prompt = null;
    emit(
      state.copyWith(
        status: GameStatus.readyToSpeak,
        isPlayingAudioPrompt: false,
        promptViseme: YasserViseme.rest,
        yasserMessage: 'دلوقتي دورك. اضغط على الميكروفون وقول الكلمة.',
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
    } catch (_) {
      // The owning playback call handles startup errors.
    }
    var shouldCancelRecording = wasListening;
    try {
      if (startingRecording != null) {
        try {
          await startingRecording;
          shouldCancelRecording = true;
        } catch (_) {
          // Startup failed before this cubit acquired the microphone.
        }
      }
      if (shouldCancelRecording) {
        await _repository.recorder.cancelRecording();
      }
    } finally {
      try {
        await _audioPlayer.dispose();
      } finally {
        await super.close();
      }
    }
  }
}
