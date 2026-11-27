import 'package:equatable/equatable.dart';

/// Task-specific inference pipelines avoiding unnecessary duplicate model execution.
enum LabTaskMode {
  recorderOnly,
  vadOnly,
  noiseReduction,
  speechToText,
  freePhonemeRecognition,
  pronunciationAssessment,
  fullDiagnostics,
}

class ModelInvocationCounts extends Equatable {
  final int vad;
  final int gtcrn;
  final int wav2vec2;
  final int whisper;

  const ModelInvocationCounts({
    this.vad = 0,
    this.gtcrn = 0,
    this.wav2vec2 = 0,
    this.whisper = 0,
  });

  Map<String, int> toJson() => {
    'vad': vad,
    'gtcrn': gtcrn,
    'wav2vec2': wav2vec2,
    'whisper': whisper,
  };

  @override
  List<Object?> get props => [vad, gtcrn, wav2vec2, whisper];
}

class LabExecutionTelemetry extends Equatable {
  final int attemptId;
  final LabTaskMode taskMode;
  final int durationMs;
  final int wavBytesLength;
  final int sampleRate;
  final int sampleCount;
  final double rawRms;
  final double rawPeak;
  final double nonZeroSampleRatio;
  final bool vadDetected;
  final int vadSegmentsCount;
  final double denoisedRms;
  final double denoisedPeak;
  final int vadLatencyMs;
  final int denoiseLatencyMs;
  final int phonemeLatencyMs;
  final int sttLatencyMs;
  final int evalLatencyMs;
  final int totalLatencyMs;
  final ModelInvocationCounts invocations;
  final String? failedStage;
  final String? technicalError;
  final int recorderRecoveryCount;
  final bool usedBackgroundWorker;

  const LabExecutionTelemetry({
    required this.attemptId,
    required this.taskMode,
    required this.durationMs,
    required this.wavBytesLength,
    required this.sampleRate,
    required this.sampleCount,
    required this.rawRms,
    required this.rawPeak,
    required this.nonZeroSampleRatio,
    required this.vadDetected,
    required this.vadSegmentsCount,
    required this.denoisedRms,
    required this.denoisedPeak,
    required this.vadLatencyMs,
    required this.denoiseLatencyMs,
    required this.phonemeLatencyMs,
    required this.sttLatencyMs,
    required this.evalLatencyMs,
    required this.totalLatencyMs,
    required this.invocations,
    this.failedStage,
    this.technicalError,
    this.recorderRecoveryCount = 0,
    this.usedBackgroundWorker = false,
  });

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptId,
    'task_mode': taskMode.name,
    'duration_ms': durationMs,
    'wav_bytes': wavBytesLength,
    'sample_rate': sampleRate,
    'sample_count': sampleCount,
    'raw_rms': rawRms,
    'raw_peak': rawPeak,
    'non_zero_sample_ratio': nonZeroSampleRatio,
    'vad_detected': vadDetected,
    'vad_segments_count': vadSegmentsCount,
    'denoised_rms': denoisedRms,
    'denoised_peak': denoisedPeak,
    'latencies_ms': {
      'vad': vadLatencyMs,
      'denoise': denoiseLatencyMs,
      'phoneme': phonemeLatencyMs,
      'stt': sttLatencyMs,
      'eval': evalLatencyMs,
      'total': totalLatencyMs,
    },
    'invocations': invocations.toJson(),
    'failed_stage': failedStage,
    'technical_error': technicalError,
    'recorder_recovery_count': recorderRecoveryCount,
    'used_background_worker': usedBackgroundWorker,
  };

  @override
  List<Object?> get props => [
    attemptId,
    taskMode,
    durationMs,
    wavBytesLength,
    totalLatencyMs,
    invocations,
    failedStage,
    technicalError,
    recorderRecoveryCount,
    usedBackgroundWorker,
  ];
}
