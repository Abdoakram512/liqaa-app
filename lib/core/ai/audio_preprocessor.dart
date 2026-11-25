import 'dart:math' as math;
import 'dart:typed_data';

class AudioPreprocessor {
  const AudioPreprocessor();

  /// Converts 16-bit PCM byte array (little endian) to normalized Float32List (-1.0 to +1.0)
  Float32List pcm16ToFloat32(Uint8List pcmBytes) {
    final int sampleCount = pcmBytes.length ~/ 2;
    final Float32List floatList = Float32List(sampleCount);
    final ByteData byteData = ByteData.sublistView(pcmBytes);

    for (int i = 0; i < sampleCount; i++) {
      final int sample16 = byteData.getInt16(i * 2, Endian.little);
      floatList[i] = sample16 / 32768.0;
    }
    return floatList;
  }

  /// Converts normalized Float32List (-1.0 to +1.0) back to 16-bit PCM byte array
  Uint8List float32ToPcm16(Float32List floatList) {
    final Uint8List pcmBytes = Uint8List(floatList.length * 2);
    final ByteData byteData = ByteData.sublistView(pcmBytes);

    for (int i = 0; i < floatList.length; i++) {
      final double clamped = floatList[i].clamp(-1.0, 1.0);
      final int sample16 = (clamped * 32767.0).round();
      byteData.setInt16(i * 2, sample16, Endian.little);
    }
    return pcmBytes;
  }

  /// Extracts raw PCM16 bytes from a standard RIFF/WAVE container
  Uint8List parseWavPcm(Uint8List wavBytes) {
    if (wavBytes.length < 44) return wavBytes;
    // Check "RIFF" and "WAVE" header markers
    if (wavBytes[0] == 0x52 && wavBytes[1] == 0x49 && wavBytes[2] == 0x46 && wavBytes[3] == 0x46) {
      // Find "data" chunk
      for (int i = 12; i < wavBytes.length - 8; i++) {
        if (wavBytes[i] == 0x64 && wavBytes[i + 1] == 0x61 && wavBytes[i + 2] == 0x74 && wavBytes[i + 3] == 0x61) {
          final ByteData bd = ByteData.sublistView(wavBytes);
          final int dataLength = bd.getUint32(i + 4, Endian.little);
          final int start = i + 8;
          final int end = math.min(wavBytes.length, start + dataLength);
          return wavBytes.sublist(start, end);
        }
      }
      // Standard 44-byte fallback if data marker parsing fails
      return wavBytes.sublist(44);
    }
    return wavBytes;
  }

  /// Removes DC Offset from audio signal
  Float32List removeDcOffset(Float32List samples) {
    if (samples.isEmpty) return samples;
    double sum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sum += samples[i];
    }
    final double mean = sum / samples.length;
    final Float32List output = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      output[i] = samples[i] - mean;
    }
    return output;
  }

  /// Peak normalization with headroom target (e.g., targetPeak = 0.95)
  Float32List normalizePeak(Float32List samples, {double targetPeak = 0.95}) {
    if (samples.isEmpty) return samples;
    double maxAbs = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final double abs = samples[i].abs();
      if (abs > maxAbs) maxAbs = abs;
    }

    if (maxAbs < 1e-4) return samples; // Silent audio

    final double gain = targetPeak / maxAbs;
    final Float32List output = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      output[i] = (samples[i] * gain).clamp(-1.0, 1.0);
    }
    return output;
  }

  /// Calculates true Peak Amplitude (0.0 to 1.0)
  double calculatePeak(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double maxAbs = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final double abs = samples[i].abs();
      if (abs > maxAbs) maxAbs = abs;
    }
    return maxAbs;
  }

  /// Calculates Root Mean Square (RMS) energy
  double calculateRms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sumSquares += samples[i] * samples[i];
    }
    return math.sqrt(sumSquares / samples.length);
  }

  /// Computes estimated Signal-to-Noise Ratio (SNR) in dB
  double estimateSnrDb(Float32List samples) {
    if (samples.length < 320) return 0.0;

    // Use lowest 10% energy frames as noise floor estimate
    const int frameSize = 160; // 10ms at 16kHz
    final int numFrames = samples.length ~/ frameSize;
    if (numFrames < 2) return 20.0;

    final List<double> frameEnergies = [];
    for (int f = 0; f < numFrames; f++) {
      double e = 0.0;
      for (int i = 0; i < frameSize; i++) {
        final double s = samples[f * frameSize + i];
        e += s * s;
      }
      frameEnergies.add(e / frameSize);
    }
    frameEnergies.sort();

    // Noise floor from lowest 10%
    final int noiseCount = math.max(1, (numFrames * 0.1).round());
    double noiseSum = 0.0;
    for (int i = 0; i < noiseCount; i++) {
      noiseSum += frameEnergies[i];
    }
    final double noiseEnergy = math.max(1e-9, noiseSum / noiseCount);

    // Signal energy from top 40%
    final int signalStart = (numFrames * 0.6).round();
    double signalSum = 0.0;
    int sigCount = 0;
    for (int i = signalStart; i < numFrames; i++) {
      signalSum += frameEnergies[i];
      sigCount++;
    }
    final double signalEnergy = math.max(1e-9, signalSum / math.max(1, sigCount));

    final double ratio = signalEnergy / noiseEnergy;
    if (ratio <= 0) return 0.0;
    return (10.0 * (math.log(ratio) / math.ln10)).clamp(0.0, 60.0);
  }

  /// Downsamples audio waveform to N display points for UI visualizers
  List<double> downsampleForWaveform(Float32List samples, int targetPoints) {
    if (samples.isEmpty || targetPoints <= 0) return const [];
    final List<double> points = List.filled(targetPoints, 0.0);
    final double step = samples.length / targetPoints;

    for (int i = 0; i < targetPoints; i++) {
      final int start = (i * step).floor();
      final int end = math.min(samples.length, ((i + 1) * step).ceil());
      double maxAbs = 0.0;
      for (int j = start; j < end; j++) {
        final double a = samples[j].abs();
        if (a > maxAbs) maxAbs = a;
      }
      points[i] = maxAbs.clamp(0.0, 1.0);
    }
    return points;
  }

  /// Creates a standard 44-byte WAV header for 16-bit mono PCM
  Uint8List addWavHeader(Uint8List pcmData, {int sampleRate = 16000, int channels = 1}) {
    final int totalDataLen = pcmData.length;
    final int totalAudioLen = totalDataLen + 36;
    final int byteRate = sampleRate * channels * 2;

    final Uint8List header = Uint8List(44);
    final ByteData bd = ByteData.sublistView(header);

    // "RIFF"
    header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46;
    bd.setUint32(4, totalAudioLen, Endian.little);
    // "WAVE"
    header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45;
    // "fmt "
    header[12] = 0x66; header[13] = 0x6D; header[14] = 0x74; header[15] = 0x20;
    bd.setUint32(16, 16, Endian.little); // SubChunk1Size (16 for PCM)
    bd.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, channels * 2, Endian.little); // BlockAlign
    bd.setUint16(34, 16, Endian.little); // BitsPerSample
    // "data"
    header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61;
    bd.setUint32(40, totalDataLen, Endian.little);

    final Uint8List wav = Uint8List(44 + totalDataLen);
    wav.setRange(0, 44, header);
    wav.setRange(44, 44 + totalDataLen, pcmData);
    return wav;
  }
}
