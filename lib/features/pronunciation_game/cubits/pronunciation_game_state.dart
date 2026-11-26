import 'package:equatable/equatable.dart';

import '../../../core/ai/models/pronunciation_assessment.dart';
import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/animation/yasser/yasser_viseme.dart';

enum GameStatus {
  initial,
  loading,
  preparingPrompt,
  readyToSpeak,
  preparingRecording,
  listening,
  evaluating,
  successCelebration,
  supportiveHint,
  sessionCompleted,
  error,
}

class PronunciationGameState extends Equatable {
  final GameStatus status;
  final List<VocabularyWord> words;
  final int currentWordIndex;
  final VocabularyWord? currentWord;
  final bool isListening;
  final double liveAmplitude;
  final PronunciationAssessment? lastAssessment;
  final int totalStarsEarned;
  final int wordsMasteredCount;
  final int attemptsCount;
  final String yasserMessage;
  final String yasserPose; // 'celebrating', 'thinking', 'pointing', 'waving'
  final String? errorMessage;
  final bool isPlayingAudioPrompt;
  final YasserViseme promptViseme;
  final String? activeCaseName;

  const PronunciationGameState({
    this.status = GameStatus.initial,
    this.words = const [],
    this.currentWordIndex = 0,
    this.currentWord,
    this.isListening = false,
    this.liveAmplitude = 0.0,
    this.lastAssessment,
    this.totalStarsEarned = 0,
    this.wordsMasteredCount = 0,
    this.attemptsCount = 0,
    this.yasserMessage = 'أهلاً بيك يا بطل! جاهز ننطق سوا؟',
    this.yasserPose = 'waving',
    this.errorMessage,
    this.isPlayingAudioPrompt = false,
    this.promptViseme = YasserViseme.rest,
    this.activeCaseName,
  });

  bool get isBusyWithAudio =>
      isListening ||
      isPlayingAudioPrompt ||
      status == GameStatus.loading ||
      status == GameStatus.preparingPrompt ||
      status == GameStatus.preparingRecording ||
      status == GameStatus.evaluating;

  bool get canChooseWord => !isBusyWithAudio;
  bool get canStartAudio => !isBusyWithAudio && currentWord != null;

  PronunciationGameState copyWith({
    GameStatus? status,
    List<VocabularyWord>? words,
    int? currentWordIndex,
    VocabularyWord? currentWord,
    bool? isListening,
    double? liveAmplitude,
    PronunciationAssessment? lastAssessment,
    int? totalStarsEarned,
    int? wordsMasteredCount,
    int? attemptsCount,
    String? yasserMessage,
    String? yasserPose,
    String? errorMessage,
    bool? isPlayingAudioPrompt,
    YasserViseme? promptViseme,
    String? activeCaseName,
    bool clearAssessment = false,
    bool clearError = false,
  }) {
    return PronunciationGameState(
      status: status ?? this.status,
      words: words ?? this.words,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      currentWord: currentWord ?? this.currentWord,
      isListening: isListening ?? this.isListening,
      liveAmplitude: liveAmplitude ?? this.liveAmplitude,
      lastAssessment: clearAssessment
          ? null
          : lastAssessment ?? this.lastAssessment,
      totalStarsEarned: totalStarsEarned ?? this.totalStarsEarned,
      wordsMasteredCount: wordsMasteredCount ?? this.wordsMasteredCount,
      attemptsCount: attemptsCount ?? this.attemptsCount,
      yasserMessage: yasserMessage ?? this.yasserMessage,
      yasserPose: yasserPose ?? this.yasserPose,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPlayingAudioPrompt: isPlayingAudioPrompt ?? this.isPlayingAudioPrompt,
      promptViseme: promptViseme ?? this.promptViseme,
      activeCaseName: activeCaseName ?? this.activeCaseName,
    );
  }

  @override
  List<Object?> get props => [
    status,
    words,
    currentWordIndex,
    currentWord,
    isListening,
    liveAmplitude,
    lastAssessment,
    totalStarsEarned,
    wordsMasteredCount,
    attemptsCount,
    yasserMessage,
    yasserPose,
    isPlayingAudioPrompt,
    promptViseme,
    errorMessage,
    activeCaseName,
  ];
}
