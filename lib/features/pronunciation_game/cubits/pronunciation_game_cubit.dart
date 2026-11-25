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
  bool _startingRecording = false;
  bool _closing = false;
  final Set<String> _masteredWordIds = {};

  bool get _speechModelsReady =>
      _repository.vadEngine.isNativeAvailable &&
      _repository.phonemeEngine.isNativeAvailable;

  bool get _canInteract =>
      !_closing &&
      !_startingRecording &&
      _prompt == null &&
      !state.isListening &&
      state.status != GameStatus.evaluating &&
      state.status != GameStatus.loading;

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
        emit(state.copyWith(isPlayingAudioPrompt: true));
      } else if (state.isPlayingAudioPrompt) {
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
          status: _speechModelsReady ? GameStatus.readyToSpeak : GameStatus.error,
          errorMessage: _speechModelsReady ? null : 'التدريب الصوتي مش جاهز دلوقتي. جرّب تاني.',
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

  /// Selects a specific word card by index
  void selectWord(int index) {
    if (!_canInteract || index < 0 || index >= state.words.length) return;
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
    if (!_canInteract || state.currentWord == null) return;
    _startingRecording = true;
    try {
      if (!_speechModelsReady) {
        emit(state.copyWith(status: GameStatus.loading, clearAssessment: true));
        if (!_repository.vadEngine.isNativeAvailable) {
          await _repository.vadEngine.initialize();
        }
        if (!_repository.phonemeEngine.isNativeAvailable) {
          await _repository.phonemeEngine.initialize();
        }
        if (_closing) return;
        if (!_speechModelsReady) {
          emit(state.copyWith(
            status: GameStatus.error,
            errorMessage: 'التدريب الصوتي مش جاهز دلوقتي. جرّب تاني.',
            yasserMessage: 'التدريب الصوتي مش جاهز دلوقتي. جرّب تاني.',
            yasserPose: 'thinking',
          ));
          return;
        }
      }
      await _repository.recorder.startRecording();
      if (_closing) {
        await _repository.recorder.stopRecording();
        return;
      }
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
          errorMessage: 'فشل فتح الميكروفون: $e',
        ),
      );
    } finally {
      _startingRecording = false;
    }
  }

  /// Stops recording and runs real on-device evaluation with honest error differentiation
  Future<void> stopListeningAndEvaluate() async {
    if (_closing || !state.isListening) return;
    emit(state.copyWith(isListening: false, status: GameStatus.evaluating));

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
            errorMessage: _repository.recorder.lastError ?? 'لم يتم تسجيل بيانات صوتية.',
            yasserMessage: 'تعذّر تسجيل الصوت من الميكروفون.. تأكد من الصلاحية وجرب تاني.',
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
      if (assessment.errorType.isSystemFailure ||
          (assessment.passed && assessment.recognizedPhonemes.isEmpty)) {
        emit(
          state.copyWith(
            status: GameStatus.error,
            clearAssessment: true,
            errorMessage: 'تعذّر تحليل الصوت. جرّب تاني.',
            yasserMessage: 'تعذّر تحليل الصوت. جرّب تاني.',
            yasserPose: 'thinking',
          ),
        );
      } else if (assessment.passed &&
          assessment.errorType == AssessmentErrorType.correct) {
        final firstMastery = _masteredWordIds.add(word.id);
        final newStars = state.totalStarsEarned + (firstMastery ? assessment.stars : 0);
        final newMastered = _masteredWordIds.length;

        emit(
          state.copyWith(
            status: GameStatus.successCelebration,
            lastAssessment: assessment,
            totalStarsEarned: newStars,
            wordsMasteredCount: newMastered,
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
          yasserMessage: 'تعذّر تسجيل أو تحليل الصوت. جرّب تاني.',
          yasserPose: 'thinking',
        ),
      );
    }
  }

  Future<void> playYasserAudioPrompt() async {
    if (!_canInteract) return;
    final prompt = YasserPrompt.byWordId[state.currentWord?.id];
    if (prompt == null) return;

    _prompt = prompt;
    try {
      final starting = _audioPlayer.play(AssetSource(prompt.assetPath));
      _startingPrompt = starting;
      await starting;
      if (!_closing && _audioPlayer.state != PlayerState.playing) {
        _clearPrompt();
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
        isPlayingAudioPrompt: false,
        promptViseme: YasserViseme.rest,
      ),
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _amplitudeSubscription.cancel();
    await _positionSubscription.cancel();
    await _playbackSubscription.cancel();
    try {
      await _startingPrompt;
    } catch (_) {
      // The owning playback call handles startup errors.
    }
    try {
      await _audioPlayer.dispose();
      if (state.isListening) await _repository.recorder.stopRecording();
    } finally {
      await super.close();
    }
  }
}
