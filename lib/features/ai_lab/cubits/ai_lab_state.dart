import 'package:equatable/equatable.dart';
import '../../../../core/ai/models/ai_model_info.dart';
import '../../../../core/ai/models/audio_processing_result.dart';
import '../../../../core/ai/models/lab_task_mode.dart';
import '../../../../core/ai/models/phoneme_token.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/phoneme_recognition_engine.dart';
import '../../../../core/ai/rnnoise_denoiser_engine.dart';
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
  final PhonemeRecognitionResult? lastPhonemeResult;
  final bool noiseReductionEnabled;
  final bool rawBypassMode;
  final DenoiserMode denoiserMode;
  final String? errorMessage;
  final String? comparisonJson;
  final String? lastBlindTranscript;
  final List<PhonemeToken> lastBlindPhonemes;
  final List<PhonemeToken> lastRawPhonemes;
  final LabExecutionTelemetry? lastTelemetry;
  final String? dualReplaySummary;

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
    this.lastPhonemeResult,
    this.noiseReductionEnabled = true,
    this.rawBypassMode = false,
    this.denoiserMode = DenoiserMode.neuralGtcrn,
    this.errorMessage,
    this.comparisonJson,
    this.lastBlindTranscript,
    this.lastBlindPhonemes = const [],
    this.lastRawPhonemes = const [],
    this.lastTelemetry,
    this.dualReplaySummary,
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
    PhonemeRecognitionResult? lastPhonemeResult,
    bool? noiseReductionEnabled,
    bool? rawBypassMode,
    DenoiserMode? denoiserMode,
    String? errorMessage,
    bool clearError = false,
    String? comparisonJson,
    String? lastBlindTranscript,
    List<PhonemeToken>? lastBlindPhonemes,
    List<PhonemeToken>? lastRawPhonemes,
    LabExecutionTelemetry? lastTelemetry,
    String? dualReplaySummary,
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
      lastRecognizedPhonemes:
          lastRecognizedPhonemes ?? this.lastRecognizedPhonemes,
      lastAssessment: lastAssessment ?? this.lastAssessment,
      lastSttResult: lastSttResult ?? this.lastSttResult,
      lastPhonemeResult: lastPhonemeResult ?? this.lastPhonemeResult,
      noiseReductionEnabled:
          noiseReductionEnabled ?? this.noiseReductionEnabled,
      rawBypassMode: rawBypassMode ?? this.rawBypassMode,
      denoiserMode: denoiserMode ?? this.denoiserMode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      comparisonJson: comparisonJson ?? this.comparisonJson,
      lastBlindTranscript: lastBlindTranscript ?? this.lastBlindTranscript,
      lastBlindPhonemes: lastBlindPhonemes ?? this.lastBlindPhonemes,
      lastRawPhonemes: lastRawPhonemes ?? this.lastRawPhonemes,
      lastTelemetry: lastTelemetry ?? this.lastTelemetry,
      dualReplaySummary: dualReplaySummary ?? this.dualReplaySummary,
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
    lastPhonemeResult,
    noiseReductionEnabled,
    rawBypassMode,
    denoiserMode,
    errorMessage,
    lastBlindTranscript,
    lastBlindPhonemes,
    lastRawPhonemes,
    lastTelemetry,
    dualReplaySummary,
  ];
}
