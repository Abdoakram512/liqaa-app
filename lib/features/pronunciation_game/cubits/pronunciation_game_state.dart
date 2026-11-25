import 'package:equatable/equatable.dart';
import '../../../core/animation/yasser/yasser_viseme.dart';
import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/ai/models/pronunciation_assessment.dart';

enum GameStatus {
  initial,
  loading,
  readyToSpeak,
  preparingPrompt,
  preparingRecording,
  listening,
  evaluating,
  successCelebration,
  supportiveHint,
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
  final String yasserMessage;
  final String yasserPose; // 'celebrating', 'thinking', 'pointing', 'waving'
  final String? errorMessage;
  final bool isPlayingAudioPrompt;
  final YasserViseme promptViseme;

  bool get canChooseWord =>
      words.isNotEmpty &&
      !isPlayingAudioPrompt &&
      (status == GameStatus.readyToSpeak ||
          status == GameStatus.successCelebration ||
          status == GameStatus.supportiveHint ||
          status == GameStatus.error);

  bool get canStartAudio => canChooseWord && currentWord != null;

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
    this.yasserMessage = 'أهلاً بيك يا بطل! جاهز ننطق سوا؟',
    this.yasserPose = 'waving',
    this.errorMessage,
    this.isPlayingAudioPrompt = false,
    this.promptViseme = YasserViseme.rest,
  });

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
    String? yasserMessage,
    String? yasserPose,
    String? errorMessage,
    bool? isPlayingAudioPrompt,
    YasserViseme? promptViseme,
    bool clearAssessment = false,
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
      yasserMessage: yasserMessage ?? this.yasserMessage,
      yasserPose: yasserPose ?? this.yasserPose,
      errorMessage: errorMessage ?? (status == null ? this.errorMessage : null),
      isPlayingAudioPrompt: isPlayingAudioPrompt ?? this.isPlayingAudioPrompt,
      promptViseme: promptViseme ?? this.promptViseme,
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
    yasserMessage,
    yasserPose,
    isPlayingAudioPrompt,
    promptViseme,
    errorMessage,
  ];
}
