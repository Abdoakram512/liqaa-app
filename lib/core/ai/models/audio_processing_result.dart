import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class VadSegmentSummary extends Equatable {
  final int index;
  final int startMs;
  final int endMs;
  final int startSample;
  final int sampleCount;
  final double rms;

  const VadSegmentSummary({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.startSample,
    required this.sampleCount,
    required this.rms,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'start_ms': startMs,
    'end_ms': endMs,
    'start_sample': startSample,
    'sample_count': sampleCount,
    'rms': rms,
  };

  @override
  List<Object?> get props => [
    index,
    startMs,
    endMs,
    startSample,
    sampleCount,
    rms,
  ];
}

class AudioProcessingResult extends Equatable {
  final bool speechDetected;
  final int speechStartMs;
  final int speechEndMs;
  final int durationMs;
  final double averageRms;
  final double peakAmplitude;
  final double snrDb;
  final double snrImprovementDb;

  /// Canonical 16kHz mono PCM16 WAV (or raw bytes if invalid format)
  final Uint8List rawAudioBytes;

  /// Valid WAV container bytes for VAD-trimmed speech (null if no speech detected)
  final Uint8List? trimmedAudioBytes;

  /// Valid WAV container bytes for denoised speech (null if denoiser failed or skipped)
  final Uint8List? denoisedAudioBytes;

  final List<double> waveformPoints;
  final List<double> denoisedWaveformPoints;

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int sampleCount;
  final int clippingCount;
  final double denoisedRms;
  final double denoisedPeakAmplitude;
  final String denoiserFilterType;
  final List<VadSegmentSummary> vadSegments;
  final bool isValidAudio;
  final String? errorMessage;

  const AudioProcessingResult({
    required this.speechDetected,
    required this.speechStartMs,
    required this.speechEndMs,
    required this.durationMs,
    required this.averageRms,
    required this.peakAmplitude,
    required this.snrDb,
    this.snrImprovementDb = 0.0,
    required this.rawAudioBytes,
    this.trimmedAudioBytes,
    this.denoisedAudioBytes,
    required this.waveformPoints,
    this.denoisedWaveformPoints = const [],
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.sampleCount = 0,
    this.clippingCount = 0,
    this.denoisedRms = 0.0,
    this.denoisedPeakAmplitude = 0.0,
    this.denoiserFilterType = 'none',
    this.vadSegments = const [],
    this.isValidAudio = true,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'is_valid_audio': isValidAudio,
    'error_message': errorMessage,
    'speech_detected': speechDetected,
    'speech_start_ms': speechStartMs,
    'speech_end_ms': speechEndMs,
    'duration_ms': durationMs,
    'sample_rate': sampleRate,
    'channels': channels,
    'bits_per_sample': bitsPerSample,
    'sample_count': sampleCount,
    'clipping_count': clippingCount,
    'average_rms': averageRms,
    'peak_amplitude': peakAmplitude,
    'snr_db': snrDb,
    'denoised_rms': denoisedRms,
    'denoised_peak_amplitude': denoisedPeakAmplitude,
    'snr_improvement_db': snrImprovementDb,
    'denoiser_filter_type': denoiserFilterType,
    'vad_segments': vadSegments.map((s) => s.toJson()).toList(),
    'raw_bytes_length': rawAudioBytes.length,
    'trimmed_bytes_length': trimmedAudioBytes?.length ?? 0,
    'denoised_bytes_length': denoisedAudioBytes?.length ?? 0,
  };

  @override
  List<Object?> get props => [
    speechDetected,
    speechStartMs,
    speechEndMs,
    durationMs,
    averageRms,
    peakAmplitude,
    snrDb,
    sampleRate,
    channels,
    sampleCount,
    clippingCount,
    denoisedRms,
    denoiserFilterType,
    isValidAudio,
    errorMessage,
  ];
}
