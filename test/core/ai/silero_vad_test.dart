import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/silero_vad_engine.dart';

void main() {
  late SileroVadEngine vad;

  setUp(() {
    vad = SileroVadEngine(
      speechThreshold: 0.35,
      minSpeechDurationMs: 100,
      speechSilencePaddingMs: 200,
    );
  });

  group('SileroVadEngine Tests', () {
    test('Empty audio returns speechDetected = false', () {
      final result = vad.analyze(Float32List(0));
      expect(result.speechDetected, isFalse);
      expect(result.durationMs, equals(0));
    });

    test('Detects speech with synthetic tone bursts and trims silence', () {
      const int sampleRate = 16000;
      const int totalSamples = sampleRate * 2; // 2 seconds
      final Float32List samples = Float32List(totalSamples);

      // Add 600ms speech burst from sample 8000 (0.5s) to 17600 (1.1s)
      for (int i = 8000; i < 17600; i++) {
        final double t = i / sampleRate;
        samples[i] = 0.8 * math.sin(2.0 * math.pi * 440.0 * t);
      }

      final result = vad.analyze(samples, sampleRate: sampleRate);

      expect(result.speechDetected, isTrue);
      expect(result.speechStartMs, greaterThanOrEqualTo(250));
      expect(result.speechEndMs, greaterThanOrEqualTo(1000));
      expect(result.trimmedSamples, isNotNull);
      expect(result.trimmedSamples!.length, lessThan(samples.length));
    });
  });
}
