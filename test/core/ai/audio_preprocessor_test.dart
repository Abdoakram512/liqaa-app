import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/audio_preprocessor.dart';

void main() {
  const preprocessor = AudioPreprocessor();

  group('AudioPreprocessor Tests', () {
    test('pcm16ToFloat32 and float32ToPcm16 roundtrip preserves values', () {
      final Float32List original = Float32List.fromList([0.0, 0.5, -0.5, 0.99, -0.99]);
      final Uint8List pcm = preprocessor.float32ToPcm16(original);
      expect(pcm.length, equals(original.length * 2));

      final Float32List recovered = preprocessor.pcm16ToFloat32(pcm);
      for (int i = 0; i < original.length; i++) {
        expect(recovered[i], closeTo(original[i], 0.001));
      }
    });

    test('removeDcOffset successfully zeros out DC bias', () {
      final Float32List biased = Float32List.fromList([0.5, 0.6, 0.4, 0.5, 0.5]);
      final Float32List clean = preprocessor.removeDcOffset(biased);

      double sum = 0.0;
      for (final s in clean) {
        sum += s;
      }
      final double mean = sum / clean.length;
      expect(mean, closeTo(0.0, 1e-6));
    });

    test('normalizePeak scales signal to target peak', () {
      final Float32List quiet = Float32List.fromList([0.1, -0.2, 0.05, 0.0]);
      final Float32List normalized = preprocessor.normalizePeak(quiet, targetPeak: 0.95);

      double maxAbs = 0.0;
      for (final s in normalized) {
        if (s.abs() > maxAbs) maxAbs = s.abs();
      }
      expect(maxAbs, closeTo(0.95, 0.001));
    });

    test('calculateRms computes correct root mean square', () {
      final Float32List signal = Float32List.fromList([1.0, -1.0, 1.0, -1.0]);
      final double rms = preprocessor.calculateRms(signal);
      expect(rms, closeTo(1.0, 0.001));
    });

    test('addWavHeader produces valid 44-byte RIFF/WAVE header', () {
      final Uint8List dummyPcm = Uint8List(3200); // 100ms at 16kHz
      final Uint8List wav = preprocessor.addWavHeader(dummyPcm, sampleRate: 16000, channels: 1);

      expect(wav.length, equals(3200 + 44));
      // "RIFF"
      expect(String.fromCharCode(wav[0]), equals('R'));
      expect(String.fromCharCode(wav[1]), equals('I'));
      expect(String.fromCharCode(wav[2]), equals('F'));
      expect(String.fromCharCode(wav[3]), equals('F'));
      // "WAVE"
      expect(String.fromCharCode(wav[8]), equals('W'));
      expect(String.fromCharCode(wav[9]), equals('A'));
      expect(String.fromCharCode(wav[10]), equals('V'));
      expect(String.fromCharCode(wav[11]), equals('E'));
    });
  });
}
