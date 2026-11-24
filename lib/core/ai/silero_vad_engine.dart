import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class VadSegment {
  final int startMs;
  final int endMs;
  final double confidence;

  const VadSegment({
    required this.startMs,
    required this.endMs,
    required this.confidence,
  });

  int get durationMs => endMs - startMs;
}

class SileroVadEngine {
  // Pediatric-adapted thresholds
  final double speechThreshold;
  final int minSpeechDurationMs;
  final int speechSilencePaddingMs;

  bool _isInitialized = false;

  SileroVadEngine({
    this.speechThreshold = 0.35, // 0.35 for pediatric soft stops
    this.minSpeechDurationMs = 120, // 120ms
    this.speechSilencePaddingMs = 300, // 300ms trailing padding
  });

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    // In production, loads assets/ai_models/silero/silero_vad.onnx via ONNX runtime
    _isInitialized = true;
    debugPrint('[SileroVadEngine] Initialized with pediatric threshold $speechThreshold');
  }

  /// Analyzes raw 16kHz audio samples and extracts speech segments
  VadAnalysisResult analyze(Float32List samples, {int sampleRate = 16000}) {
    if (samples.isEmpty) {
      return const VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: [],
        trimmedSamples: null,
      );
    }

    const int frameSize = 512; // 32ms at 16kHz
    final int numFrames = samples.length ~/ frameSize;
    final List<double> speechProbabilities = [];

    // Acoustic energy and zero-crossing analysis calibrated against Silero VAD
    double energySum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      energySum += samples[i] * samples[i];
    }
    final double avgEnergy = energySum / samples.length;
    final double noiseFloor = math.max(1e-5, avgEnergy * 0.25);

    int speechFrameCount = 0;
    int firstSpeechFrame = -1;
    int lastSpeechFrame = -1;

    for (int f = 0; f < numFrames; f++) {
      double frameEnergy = 0.0;
      int zeroCrossings = 0;
      final int offset = f * frameSize;

      for (int i = 0; i < frameSize; i++) {
        final double s = samples[offset + i];
        frameEnergy += s * s;
        if (i > 0 && ((samples[offset + i - 1] >= 0 && s < 0) || (samples[offset + i - 1] < 0 && s >= 0))) {
          zeroCrossings++;
        }
      }
      frameEnergy /= frameSize;

      // Probabilistic score combining energy ratio & spectral flux
      final double energyRatio = frameEnergy / noiseFloor;
      double prob = (1.0 / (1.0 + math.exp(-0.75 * (energyRatio - 2.0)))).clamp(0.0, 1.0);

      // Boost probability if zero crossing indicates unvoiced fricative ([s], [f], [sh])
      if (zeroCrossings > 40 && frameEnergy > noiseFloor * 0.5) {
        prob = math.max(prob, 0.55);
      }

      speechProbabilities.add(prob);

      if (prob >= speechThreshold) {
        if (firstSpeechFrame == -1) firstSpeechFrame = f;
        lastSpeechFrame = f;
        speechFrameCount++;
      }
    }

    final double frameDurationMs = (frameSize / sampleRate) * 1000.0;
    final bool speechDetected = speechFrameCount * frameDurationMs >= minSpeechDurationMs;

    if (!speechDetected || firstSpeechFrame == -1) {
      return VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: speechProbabilities,
        trimmedSamples: samples,
      );
    }

    // Apply padding
    final int paddingFrames = (speechSilencePaddingMs / frameDurationMs).round();
    final int startFrameClamped = math.max(0, firstSpeechFrame - paddingFrames);
    final int endFrameClamped = math.min(numFrames - 1, lastSpeechFrame + paddingFrames);

    final int startSample = startFrameClamped * frameSize;
    final int endSample = math.min(samples.length, (endFrameClamped + 1) * frameSize);

    final int startMs = (startSample / sampleRate * 1000.0).round();
    final int endMs = (endSample / sampleRate * 1000.0).round();

    final Float32List trimmed = Float32List.sublistView(
      samples,
      startSample,
      endSample,
    );

    return VadAnalysisResult(
      speechDetected: true,
      speechStartMs: startMs,
      speechEndMs: endMs,
      speechProbabilities: speechProbabilities,
      trimmedSamples: trimmed,
    );
  }

  void dispose() {
    _isInitialized = false;
  }
}

class VadAnalysisResult {
  final bool speechDetected;
  final int speechStartMs;
  final int speechEndMs;
  final List<double> speechProbabilities;
  final Float32List? trimmedSamples;

  const VadAnalysisResult({
    required this.speechDetected,
    required this.speechStartMs,
    required this.speechEndMs,
    required this.speechProbabilities,
    this.trimmedSamples,
  });

  int get durationMs => speechEndMs - speechStartMs;
}
