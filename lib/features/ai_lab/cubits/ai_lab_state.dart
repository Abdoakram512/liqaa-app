import 'package:equatable/equatable.dart';
import '../../../../core/ai/models/ai_model_info.dart';
import '../../../../core/ai/models/audio_processing_result.dart';
import '../../../../core/ai/models/phoneme_token.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/speech_to_text_engine.dart';

enum AiLabStatus { initial, loading, recording, processing, ready, error }

class AiLabState extends Equatable {
  final AiLabStatus status;
  final List<AiModelInfo> models;
  final double totalRamUsageMb;
  final List<VocabularyWord> vocabulary;
  final VocabularyWord? selectedWord;
  final bool isRecording;
  final double currentLiveAmplitude;
  final AudioProcessingResult? lastAudioResult;
  final List<PhonemeToken> lastRecognizedPhonemes;
  final PronunciationAssessment? lastAssessment;
  final SttResult? lastSttResult;
  final bool noiseReductionEnabled;
  final String? errorMessage;
  final String? comparisonJson;
  final String? lastBlindTranscript;
  final List<PhonemeToken> lastBlindPhonemes;

  const AiLabState({
    this.status = AiLabStatus.initial,
    this.models = const [],
    this.totalRamUsageMb = 0.0,
    this.vocabulary = const [],
    this.selectedWord,
    this.isRecording = false,
    this.currentLiveAmplitude = 0.0,
    this.lastAudioResult,
    this.lastRecognizedPhonemes = const [],
    this.lastAssessment,
    this.lastSttResult,
    this.noiseReductionEnabled = true,
    this.errorMessage,
    this.comparisonJson,
    this.lastBlindTranscript,
    this.lastBlindPhonemes = const [],
  });

  AiLabState copyWith({
    AiLabStatus? status,
    List<AiModelInfo>? models,
    double? totalRamUsageMb,
    List<VocabularyWord>? vocabulary,
    VocabularyWord? selectedWord,
    bool? isRecording,
    double? currentLiveAmplitude,
    AudioProcessingResult? lastAudioResult,
    List<PhonemeToken>? lastRecognizedPhonemes,
    PronunciationAssessment? lastAssessment,
    SttResult? lastSttResult,
    bool? noiseReductionEnabled,
    String? errorMessage,
    String? comparisonJson,
    String? lastBlindTranscript,
    List<PhonemeToken>? lastBlindPhonemes,
  }) {
    return AiLabState(
      status: status ?? this.status,
      models: models ?? this.models,
      totalRamUsageMb: totalRamUsageMb ?? this.totalRamUsageMb,
      vocabulary: vocabulary ?? this.vocabulary,
      selectedWord: selectedWord ?? this.selectedWord,
      isRecording: isRecording ?? this.isRecording,
      currentLiveAmplitude: currentLiveAmplitude ?? this.currentLiveAmplitude,
      lastAudioResult: lastAudioResult ?? this.lastAudioResult,
      lastRecognizedPhonemes: lastRecognizedPhonemes ?? this.lastRecognizedPhonemes,
      lastAssessment: lastAssessment ?? this.lastAssessment,
      lastSttResult: lastSttResult ?? this.lastSttResult,
      noiseReductionEnabled: noiseReductionEnabled ?? this.noiseReductionEnabled,
      errorMessage: errorMessage ?? this.errorMessage,
      comparisonJson: comparisonJson ?? this.comparisonJson,
      lastBlindTranscript: lastBlindTranscript ?? this.lastBlindTranscript,
      lastBlindPhonemes: lastBlindPhonemes ?? this.lastBlindPhonemes,
    );
  }

  @override
  List<Object?> get props => [
    status,
    models,
    totalRamUsageMb,
    vocabulary,
    selectedWord,
    isRecording,
    currentLiveAmplitude,
    lastAudioResult,
    lastRecognizedPhonemes,
    lastAssessment,
    lastSttResult,
    noiseReductionEnabled,
    errorMessage,
    lastBlindTranscript,
    lastBlindPhonemes,
  ];
}
