import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/rnnoise_denoiser_engine.dart';

void main() {
  late RnnoiseDenoiserEngine denoiser;

  setUp(() {
    denoiser = RnnoiseDenoiserEngine(initialEnabled: true);
  });

  group('RnnoiseDenoiserEngine Tests', () {
    test('Bypass mode returns original samples without alteration', () {
      denoiser.enabled = false;
      final Float32List original = Float32List.fromList([0.1, 0.2, -0.3, 0.4]);
      final result = denoiser.process(original);

      expect(result.wasSuppressionApplied, isFalse);
      expect(result.processedSamples, equals(original));
      expect(result.snrImprovementDb, equals(0.0));
    });

    test('Enabled mode reduces noise and computes positive SNR improvement', () {
      denoiser.enabled = true;
      const int sampleRate = 16000;
      const int length = sampleRate * 1; // 1 second
      final Float32List noisy = Float32List(length);

      // Create signal + background hiss
      for (int i = 0; i < length; i++) {
        final double t = i / sampleRate;
        final double tone = 0.6 * math.sin(2.0 * math.pi * 500.0 * t);
        final double noise = 0.25 * math.sin(2.0 * math.pi * 3200.0 * t);
        noisy[i] = (tone + noise).clamp(-1.0, 1.0);
      }

      final result = denoiser.process(noisy);

      expect(result.wasSuppressionApplied, isTrue);
      expect(result.processedSamples.length, equals(noisy.length));
      expect(result.snrAfterDb, greaterThanOrEqualTo(result.snrBeforeDb));
    });
  });
}
