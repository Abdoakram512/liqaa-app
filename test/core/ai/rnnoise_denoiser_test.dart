import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/rnnoise_denoiser_engine.dart';

void main() {
  late RnnoiseDenoiserEngine denoiser;

  setUp(() async {
    denoiser = RnnoiseDenoiserEngine(
      initialEnabled: true,
      modelPathOverride: 'assets/ai_models/gtcrn/gtcrn_simple.onnx',
    );
    await denoiser.initialize();
  });

  tearDown(() {
    denoiser.dispose();
  });

  group('GTCRN Neural Denoiser Tests', () {
    test('Initializes real GTCRN ONNX model cleanly', () {
      expect(denoiser.isInitialized, isTrue);
      expect(denoiser.isNativeAvailable, isTrue);
      expect(denoiser.lastError, isNull);
    });

    test('Bypass mode returns original samples without alteration', () {
      denoiser.enabled = false;
      final Float32List original = Float32List.fromList([0.1, 0.2, -0.3, 0.4]);
      final result = denoiser.process(original);

      expect(result.wasSuppressionApplied, isFalse);
      expect(result.filterType, equals('bypass'));
      expect(result.processedSamples, equals(original));
      expect(result.snrImprovementDb, equals(0.0));
    });

    test(
      'Real GTCRN neural denoiser processes audio with valid non-silent finite output',
      () {
        denoiser.enabled = true;
        denoiser.mode = DenoiserMode.neuralGtcrn;
        const int sampleRate = 16000;
        const int length = sampleRate; // 1 second
        final Float32List noisy = Float32List(length);

        for (int i = 0; i < length; i++) {
          final double t = i / sampleRate;
          final double tone = 0.45 * math.sin(2.0 * math.pi * 500.0 * t);
          final double noise = 0.08 * math.sin(2.0 * math.pi * 3200.0 * t);
          noisy[i] = (tone + noise).clamp(-1.0, 1.0);
        }

        final result = denoiser.process(noisy);

        expect(result.hasValidAudio, isTrue);
        expect(result.wasSuppressionApplied, isTrue);
        expect(result.isNeuralModel, isTrue);
        expect(result.filterType, equals('gtcrn_neural'));
        expect(result.processedSamples.length, greaterThan(sampleRate ~/ 2));
        expect(result.rmsAfter, greaterThan(0.02));
      },
    );

    test('DSP Wiener explicit mode runs only when selected explicitly', () {
      denoiser.enabled = true;
      denoiser.mode = DenoiserMode.dspWienerFallback;
      final Float32List sig = Float32List.fromList(
        List.generate(
          8000,
          (i) => 0.4 * math.sin(2 * math.pi * 500 * i / 16000),
        ),
      );
      final result = denoiser.process(sig);

      expect(result.hasValidAudio, isTrue);
      expect(result.isNeuralModel, isFalse);
      expect(result.filterType, equals('dsp_wiener_fallback'));
    });

    test(
      'Missing GTCRN model surfaces honest error instead of silent fallback',
      () async {
        final broken = RnnoiseDenoiserEngine(
          modelPathOverride: 'assets/ai_models/gtcrn/does_not_exist.onnx',
        );
        await broken.initialize();
        expect(broken.isNativeAvailable, isFalse);
        expect(broken.lastError, isNotNull);

        final res = broken.process(Float32List(1600));
        expect(res.hasValidAudio, isFalse);
        expect(res.wasSuppressionApplied, isFalse);
        expect(res.errorMessage, isNotNull);
        broken.dispose();
      },
    );
  });
}
