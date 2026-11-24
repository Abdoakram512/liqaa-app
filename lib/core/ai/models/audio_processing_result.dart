import 'dart:typed_data';
import 'package:equatable/equatable.dart';

class AudioProcessingResult extends Equatable {
  final bool speechDetected;
  final int speechStartMs;
  final int speechEndMs;
  final int durationMs;
  final double averageRms;
  final double peakAmplitude;
  final double snrDb;
  final double snrImprovementDb;
  final Uint8List rawAudioBytes;
  final Uint8List? trimmedAudioBytes;
  final Uint8List? denoisedAudioBytes;
  final List<double> waveformPoints;

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
  });

  Map<String, dynamic> toJson() => {
    'speech_detected': speechDetected,
    'speech_start_ms': speechStartMs,
    'speech_end_ms': speechEndMs,
    'duration_ms': durationMs,
    'average_rms': averageRms,
    'peak_amplitude': peakAmplitude,
    'snr_db': snrDb,
    'snr_improvement_db': snrImprovementDb,
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
    snrDb,
  ];
}
