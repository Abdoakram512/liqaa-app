import 'package:equatable/equatable.dart';
import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/ai/models/pronunciation_assessment.dart';

enum GameStatus {
  initial,
  loading,
  readyToSpeak,
  listening,
  evaluating,
  successCelebration,
  supportiveHint,
  error
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
  }) {
    return PronunciationGameState(
      status: status ?? this.status,
      words: words ?? this.words,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      currentWord: currentWord ?? this.currentWord,
      isListening: isListening ?? this.isListening,
      liveAmplitude: liveAmplitude ?? this.liveAmplitude,
      lastAssessment: lastAssessment ?? this.lastAssessment,
      totalStarsEarned: totalStarsEarned ?? this.totalStarsEarned,
      wordsMasteredCount: wordsMasteredCount ?? this.wordsMasteredCount,
      yasserMessage: yasserMessage ?? this.yasserMessage,
      yasserPose: yasserPose ?? this.yasserPose,
      errorMessage: errorMessage ?? this.errorMessage,
      isPlayingAudioPrompt: isPlayingAudioPrompt ?? this.isPlayingAudioPrompt,
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
  ];
}
