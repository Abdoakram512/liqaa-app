import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ai/pronunciation_repository.dart';
import 'pronunciation_game_state.dart';

class PronunciationGameCubit extends Cubit<PronunciationGameState> {
  final PronunciationRepository _repository;
  final AudioPlayer _audioPlayer;
  StreamSubscription<double>? _amplitudeSubscription;

  PronunciationGameCubit(
    this._repository, {
    AudioPlayer? audioPlayer,
  })  : _audioPlayer = audioPlayer ?? AudioPlayer(),
        super(const PronunciationGameState()) {
    _amplitudeSubscription = _repository.recorder.amplitudeStream.listen((amp) {
      if (state.isListening) {
        emit(state.copyWith(liveAmplitude: amp));
      }
    });
  }

  /// Initializes game session and loads 28 vocabulary cards
  Future<void> initializeGame() async {
    emit(state.copyWith(status: GameStatus.loading));
    try {
      await _repository.initialize();
      final words = _repository.vocabulary;
      final currentWord = words.isNotEmpty ? words.first : null;

      emit(state.copyWith(
        status: GameStatus.readyToSpeak,
        words: words,
        currentWordIndex: 0,
        currentWord: currentWord,
        yasserMessage: 'أهلاً بيك يا بطل! يلا ندوس على المايك وننطق سوا!',
        yasserPose: 'waving',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: GameStatus.error,
        errorMessage: 'فشل تحميل الكلمات: $e',
      ));
    }
  }

  /// Selects a specific word card by index
  void selectWord(int index) {
    if (index < 0 || index >= state.words.length) return;
    final word = state.words[index];
    emit(state.copyWith(
      currentWordIndex: index,
      currentWord: word,
      status: GameStatus.readyToSpeak,
      lastAssessment: null,
      yasserMessage: 'يلا ننطق كلمة "${word.wordArabic}" مع ياسر!',
      yasserPose: 'waving',
    ));
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
    final prevIndex = (state.currentWordIndex - 1 + state.words.length) % state.words.length;
    selectWord(prevIndex);
  }

  /// Starts child recording
  Future<void> startListening() async {
    if (state.isListening) return;
    try {
      await _repository.recorder.startRecording();
      emit(state.copyWith(
        isListening: true,
        status: GameStatus.listening,
        yasserMessage: 'ياسر سامعك.. اتكلم يا بطل!',
        yasserPose: 'thinking',
      ));
    } catch (e) {
      emit(state.copyWith(
        isListening: false,
        status: GameStatus.error,
        errorMessage: 'فشل فتح الميكروفون: $e',
      ));
    }
  }

  /// Stops recording and runs on-device evaluation
  Future<void> stopListeningAndEvaluate() async {
    if (!state.isListening) return;
    emit(state.copyWith(isListening: false, status: GameStatus.evaluating));

    try {
      final Uint8List rawBytes = await _repository.recorder.stopRecording();
      final word = state.currentWord;

      if (word == null || rawBytes.isEmpty) {
        emit(state.copyWith(
          status: GameStatus.readyToSpeak,
          yasserMessage: 'مش سامع صوتك يا بطل! يلا نجرب تاني.',
          yasserPose: 'thinking',
        ));
        return;
      }

      // Run AI pipeline
      final assessment = await _repository.evaluateAudio(
        rawAudioBytes: rawBytes,
        targetWord: word,
      );

      if (assessment.passed) {
        final newStars = state.totalStarsEarned + assessment.stars;
        final newMastered = state.wordsMasteredCount + 1;

        emit(state.copyWith(
          status: GameStatus.successCelebration,
          lastAssessment: assessment,
          totalStarsEarned: newStars,
          wordsMasteredCount: newMastered,
          yasserMessage: assessment.yasserFeedbackMessage,
          yasserPose: assessment.yasserPose,
        ));
      } else {
        emit(state.copyWith(
          status: GameStatus.supportiveHint,
          lastAssessment: assessment,
          yasserMessage: assessment.yasserFeedbackMessage,
          yasserPose: assessment.yasserPose,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: GameStatus.readyToSpeak,
        yasserMessage: 'حصل خطأ بسيط.. يلا ندوس على المايك ونجرب تاني!',
        yasserPose: 'thinking',
      ));
    }
  }

  /// Plays pronunciation audio prompt from Yasser
  Future<void> playYasserAudioPrompt() async {
    emit(state.copyWith(isPlayingAudioPrompt: true));
    try {
      final word = state.currentWord;
      if (word != null) {
        final fixturePath = 'audio_samples/correct_${word.wordTransliteration.toLowerCase()}.wav';
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(fixturePath));
      }
    } catch (e) {
      // Audio playback fallback for test environment or missing audio driver
    } finally {
      emit(state.copyWith(isPlayingAudioPrompt: false));
    }
  }

  @override
  Future<void> close() {
    _amplitudeSubscription?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
