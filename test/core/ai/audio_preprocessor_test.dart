import 'dart:math' as math;
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
      expect(sum / clean.length, closeTo(0.0, 1e-6));
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
      expect(preprocessor.calculateRms(signal), closeTo(1.0, 0.001));
    });

    test('addWavHeader produces valid 44-byte RIFF/WAVE header', () {
      final Uint8List dummyPcm = Uint8List(3200);
      final Uint8List wav = preprocessor.addWavHeader(dummyPcm, sampleRate: 16000, channels: 1);

      expect(wav.length, equals(3200 + 44));
      final meta = preprocessor.parseWavMetadata(wav);
      expect(meta.sampleRate, equals(16000));
      expect(meta.channels, equals(1));
      expect(meta.bitsPerSample, equals(16));
      expect(meta.dataSize, equals(3200));
    });

    test('parseWavMetadata walks chunks cleanly and ignores JUNK chunk containing fake "data" ASCII', () {
      final Uint8List pcm = preprocessor.float32ToPcm16(
        Float32List.fromList(List.generate(1600, (i) => 0.3 * math.sin(i * 0.1))),
      );
      final List<int> junkPayload = 'metadata_data_trap!!'.codeUnits; // 20 bytes
      final int fmtSize = 16;
      final int dataSize = pcm.length;
      final int totalSize = 4 + (8 + junkPayload.length) + (8 + fmtSize) + (8 + dataSize);

      final builder = BytesBuilder();
      builder.add('RIFF'.codeUnits);
      builder.add((ByteData(4)..setUint32(0, totalSize, Endian.little)).buffer.asUint8List());
      builder.add('WAVE'.codeUnits);
      builder.add('JUNK'.codeUnits);
      builder.add((ByteData(4)..setUint32(0, junkPayload.length, Endian.little)).buffer.asUint8List());
      builder.add(junkPayload);
      builder.add('fmt '.codeUnits);
      builder.add((ByteData(4)..setUint32(0, 16, Endian.little)).buffer.asUint8List());
      final fmt = ByteData(16)
        ..setUint16(0, 1, Endian.little)
        ..setUint16(2, 1, Endian.little)
        ..setUint32(4, 16000, Endian.little)
        ..setUint32(8, 32000, Endian.little)
        ..setUint16(12, 2, Endian.little)
        ..setUint16(14, 16, Endian.little);
      builder.add(fmt.buffer.asUint8List());
      builder.add('data'.codeUnits);
      builder.add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List());
      builder.add(pcm);

      final prep = preprocessor.preprocessWav(builder.toBytes(), targetSampleRate: 16000);
      expect(prep.sampleCount, equals(1600));
      expect(prep.sourceMetadata.dataSize, equals(dataSize));
      expect(prep.rms, greaterThan(0.15));
    });

    test('preprocessWav downmixes stereo 48kHz WAV to mono 16kHz', () {
      const int srcRate = 48000;
      const int frames = 24000; // 0.5 sec
      final ByteData stereoPcm = ByteData(frames * 4);
      for (int f = 0; f < frames; f++) {
        final int val = (0.4 * math.sin(2 * math.pi * 440 * f / srcRate) * 32767).round();
        stereoPcm.setInt16(f * 4, val, Endian.little);
        stereoPcm.setInt16(f * 4 + 2, val, Endian.little);
      }
      final wav = preprocessor.addWavHeader(
        stereoPcm.buffer.asUint8List(),
        sampleRate: srcRate,
        channels: 2,
      );

      final prep = preprocessor.preprocessWav(wav, targetSampleRate: 16000);
      expect(prep.sourceMetadata.sampleRate, equals(48000));
      expect(prep.sourceMetadata.channels, equals(2));
      expect(prep.sampleCount, closeTo(8000, 10));
      expect(prep.durationMs, closeTo(500, 10));
      expect(prep.rms, greaterThan(0.2));
    });

    test('preprocessWav rejects non-RIFF corrupt payload explicitly', () {
      final bogus = Uint8List.fromList(List.filled(200, 0xAB));
      expect(
        () => preprocessor.preprocessWav(bogus),
        throwsA(isA<InvalidAudioFormatException>()),
      );
    });
  });
}
