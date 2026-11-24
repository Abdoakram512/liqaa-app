import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'audio_preprocessor.dart';

class DenoiseResult {
  final Float32List processedSamples;
  final double snrBeforeDb;
  final double snrAfterDb;
  final double snrImprovementDb;
  final bool wasSuppressionApplied;

  const DenoiseResult({
    required this.processedSamples,
    required this.snrBeforeDb,
    required this.snrAfterDb,
    required this.snrImprovementDb,
    required this.wasSuppressionApplied,
  });
}

class RnnoiseDenoiserEngine {
  final AudioPreprocessor _preprocessor;
  bool enabled = true;
  bool _isInitialized = false;

  RnnoiseDenoiserEngine({
    AudioPreprocessor? preprocessor,
    bool initialEnabled = true,
  })  : _preprocessor = preprocessor ?? const AudioPreprocessor(),
        enabled = initialEnabled;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    // In production, loads assets/ai_models/rnnoise/rnnoise.onnx via ONNX runtime
    _isInitialized = true;
    debugPrint('[RnnoiseDenoiserEngine] Initialized (enabled: $enabled)');
  }

  /// Denoisers 16kHz audio samples. If enabled == false, acts as zero-latency bypass.
  DenoiseResult process(Float32List inputSamples) {
    if (inputSamples.isEmpty) {
      return DenoiseResult(
        processedSamples: inputSamples,
        snrBeforeDb: 0.0,
        snrAfterDb: 0.0,
        snrImprovementDb: 0.0,
        wasSuppressionApplied: false,
      );
    }

    final double snrBefore = _preprocessor.estimateSnrDb(inputSamples);

    // If disabled, bypass without modification
    if (!enabled) {
      return DenoiseResult(
        processedSamples: inputSamples,
        snrBeforeDb: snrBefore,
        snrAfterDb: snrBefore,
        snrImprovementDb: 0.0,
        wasSuppressionApplied: false,
      );
    }

    // RNNoise neural attenuation simulation:
    // Frame size = 160 (10ms at 16kHz)
    const int frameSize = 160;
    final int numFrames = inputSamples.length ~/ frameSize;
    final Float32List outputSamples = Float32List(inputSamples.length);

    // Estimate noise spectrum from quiet frames
    double runningNoiseEnergy = 0.001;

    for (int f = 0; f < numFrames; f++) {
      final int offset = f * frameSize;
      double frameEnergy = 0.0;
      for (int i = 0; i < frameSize; i++) {
        final double s = inputSamples[offset + i];
        frameEnergy += s * s;
      }
      frameEnergy /= frameSize;

      if (f < 5 || frameEnergy < runningNoiseEnergy * 1.5) {
        runningNoiseEnergy = 0.9 * runningNoiseEnergy + 0.1 * math.max(1e-6, frameEnergy);
      }

      // Gain computation via Wiener-like suppression curve: G = max(G_min, 1 - (N / S)^gamma)
      final double snrLinear = frameEnergy / math.max(1e-6, runningNoiseEnergy);
      double gain = 1.0;
      if (snrLinear < 3.0) {
        // Low SNR frame -> attenuate background noise
        gain = (snrLinear / 3.0).clamp(0.12, 1.0);
      } else {
        gain = 1.0;
      }

      for (int i = 0; i < frameSize; i++) {
        outputSamples[offset + i] = (inputSamples[offset + i] * gain).clamp(-1.0, 1.0);
      }
    }

    // Remaining tail samples
    final int processedTail = numFrames * frameSize;
    for (int i = processedTail; i < inputSamples.length; i++) {
      outputSamples[i] = inputSamples[i];
    }

    final double snrAfter = _preprocessor.estimateSnrDb(outputSamples);
    final double snrImprovement = (snrAfter - snrBefore).clamp(0.0, 30.0);

    return DenoiseResult(
      processedSamples: outputSamples,
      snrBeforeDb: snrBefore,
      snrAfterDb: snrAfter,
      snrImprovementDb: snrImprovement,
      wasSuppressionApplied: true,
    );
  }

  void dispose() {
    _isInitialized = false;
  }
}
