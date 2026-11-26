import 'dart:math' as math;
import 'dart:typed_data';

/// Exception thrown when an audio recording or WAV payload is corrupt, truncated, or unsupported.
class InvalidAudioFormatException implements Exception {
  final String message;
  const InvalidAudioFormatException(this.message);

  @override
  String toString() => 'InvalidAudioFormatException: $message';
}

/// Parsed RIFF/WAVE header & chunk metadata.
class WavAudioMetadata {
  final int audioFormat; // 1 = PCM, 3 = IEEE Float
  final int channels;
  final int sampleRate;
  final int byteRate;
  final int blockAlign;
  final int bitsPerSample;
  final int dataOffset;
  final int dataSize;

  const WavAudioMetadata({
    required this.audioFormat,
    required this.channels,
    required this.sampleRate,
    required this.byteRate,
    required this.blockAlign,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataSize,
  });

  int get frameCount => blockAlign > 0 ? dataSize ~/ blockAlign : 0;
  int get durationMs =>
      sampleRate > 0 ? (frameCount * 1000 / sampleRate).round() : 0;

  Map<String, dynamic> toJson() => {
    'audio_format': audioFormat,
    'channels': channels,
    'sample_rate': sampleRate,
    'byte_rate': byteRate,
    'block_align': blockAlign,
    'bits_per_sample': bitsPerSample,
    'data_offset': dataOffset,
    'data_size': dataSize,
    'frame_count': frameCount,
    'duration_ms': durationMs,
  };
}

/// Unified preprocessed audio container (mono Float32 normalized + canonical PCM16 WAV).
class PreprocessedAudio {
  final WavAudioMetadata sourceMetadata;
  final int targetSampleRate;
  final Float32List samples;
  final Uint8List pcm16Mono;
  final Uint8List wavBytes;
  final int durationMs;
  final double rms;
  final double peakAmplitude;
  final int clippingCount;
  final List<double> waveformPoints;

  const PreprocessedAudio({
    required this.sourceMetadata,
    required this.targetSampleRate,
    required this.samples,
    required this.pcm16Mono,
    required this.wavBytes,
    required this.durationMs,
    required this.rms,
    required this.peakAmplitude,
    required this.clippingCount,
    required this.waveformPoints,
  });

  int get sampleCount => samples.length;
}

/// Unified audio capture, RIFF/WAVE validation, downmixing, resampling, and telemetry preprocessor.
class AudioPreprocessor {
  const AudioPreprocessor();

  static const int defaultSampleRate = 16000;

  /// Converts 16-bit little-endian signed PCM bytes to normalized [-1.0, 1.0] Float32List.
  Float32List pcm16ToFloat32(Uint8List pcmBytes) {
    final int sampleCount = pcmBytes.length ~/ 2;
    final Float32List floatList = Float32List(sampleCount);
    final ByteData byteData = ByteData.sublistView(pcmBytes);

    for (int i = 0; i < sampleCount; i++) {
      final int intVal = byteData.getInt16(i * 2, Endian.little);
      floatList[i] = intVal / 32768.0;
    }
    return floatList;
  }

  /// Converts Float32List [-1.0, 1.0] back to 16-bit little-endian signed PCM bytes.
  Uint8List float32ToPcm16(Float32List floatList) {
    final Uint8List pcmBytes = Uint8List(floatList.length * 2);
    final ByteData byteData = ByteData.sublistView(pcmBytes);

    for (int i = 0; i < floatList.length; i++) {
      final double clamped = floatList[i].clamp(-1.0, 1.0);
      final int intVal = (clamped * 32767.0).round();
      byteData.setInt16(i * 2, intVal, Endian.little);
    }
    return pcmBytes;
  }

  /// Parses RIFF/WAVE container strictly by walking chunk IDs and sizes.
  /// Handles JUNK, LIST, INFO, fact, bext, or arbitrary metadata chunks safely.
  WavAudioMetadata parseWavMetadata(Uint8List wavBytes) {
    if (wavBytes.length < 44) {
      throw InvalidAudioFormatException(
        'Audio buffer too short (${wavBytes.length} bytes < 44 byte WAV header).',
      );
    }

    if (!_matchesFourCc(wavBytes, 0, 'RIFF') ||
        !_matchesFourCc(wavBytes, 8, 'WAVE')) {
      throw const InvalidAudioFormatException(
        'Missing RIFF/WAVE container signature.',
      );
    }

    final ByteData bd = ByteData.sublistView(wavBytes);
    int offset = 12;

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? byteRate;
    int? blockAlign;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    while (offset + 8 <= wavBytes.length) {
      final String chunkId = String.fromCharCodes(
        wavBytes.sublist(offset, offset + 4),
      );
      final int chunkSize = bd.getUint32(offset + 4, Endian.little);
      final int payloadStart = offset + 8;

      if (chunkId == 'fmt ') {
        if (chunkSize < 16 || payloadStart + 16 > wavBytes.length) {
          throw const InvalidAudioFormatException(
            'Corrupt or truncated WAV fmt chunk.',
          );
        }
        audioFormat = bd.getUint16(payloadStart, Endian.little);
        channels = bd.getUint16(payloadStart + 2, Endian.little);
        sampleRate = bd.getUint32(payloadStart + 4, Endian.little);
        byteRate = bd.getUint32(payloadStart + 8, Endian.little);
        blockAlign = bd.getUint16(payloadStart + 12, Endian.little);
        bitsPerSample = bd.getUint16(payloadStart + 14, Endian.little);

        // Handle WAVE_FORMAT_EXTENSIBLE (0xFFFE) if SubFormat matches PCM (1) or IEEE Float (3)
        if (audioFormat == 0xFFFE &&
            chunkSize >= 40 &&
            payloadStart + 26 <= wavBytes.length) {
          audioFormat = bd.getUint16(payloadStart + 24, Endian.little);
        }
      } else if (chunkId == 'data') {
        dataOffset = payloadStart;
        final int available = wavBytes.length - payloadStart;
        // Handle streaming/unfinalized recorders where chunkSize is 0xFFFFFFFF or slightly stale
        dataSize = (chunkSize == 0 || chunkSize > available)
            ? available
            : chunkSize;
        break;
      }

      // RIFF chunks are word-aligned (even byte boundary)
      final int paddedSize = chunkSize + (chunkSize.isOdd ? 1 : 0);
      final int nextOffset = payloadStart + paddedSize;
      if (nextOffset <= offset ||
          nextOffset > wavBytes.length && chunkId != 'data') {
        break;
      }
      offset = nextOffset;
    }

    if (audioFormat == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        blockAlign == null ||
        byteRate == null) {
      throw const InvalidAudioFormatException(
        'WAV file is missing required fmt chunk.',
      );
    }

    if (audioFormat != 1 && audioFormat != 3) {
      throw InvalidAudioFormatException(
        'Unsupported WAV audioFormat=$audioFormat (expected 1=PCM or 3=IEEE Float).',
      );
    }

    if (channels < 1 || channels > 8) {
      throw InvalidAudioFormatException(
        'Unsupported channel count: $channels.',
      );
    }

    if (sampleRate < 8000 || sampleRate > 192000) {
      throw InvalidAudioFormatException(
        'Unsupported WAV sample rate: $sampleRate Hz.',
      );
    }

    if (bitsPerSample != 8 &&
        bitsPerSample != 16 &&
        bitsPerSample != 24 &&
        bitsPerSample != 32) {
      throw InvalidAudioFormatException(
        'Unsupported WAV bitsPerSample: $bitsPerSample.',
      );
    }

    if (dataOffset == null || dataSize == null || dataSize <= 0) {
      throw const InvalidAudioFormatException(
        'WAV file contains no audio data chunk.',
      );
    }

    return WavAudioMetadata(
      audioFormat: audioFormat,
      channels: channels,
      sampleRate: sampleRate,
      byteRate: byteRate,
      blockAlign: blockAlign,
      bitsPerSample: bitsPerSample,
      dataOffset: dataOffset,
      dataSize: dataSize,
    );
  }

  /// Extracts raw PCM data payload from a WAV file (returns original bytes only if headerless fallback).
  Uint8List parseWavPcm(Uint8List wavBytes) {
    if (wavBytes.length >= 12 && _matchesFourCc(wavBytes, 0, 'RIFF')) {
      final meta = parseWavMetadata(wavBytes);
      final int end = math.min(
        wavBytes.length,
        meta.dataOffset + meta.dataSize,
      );
      return wavBytes.sublist(meta.dataOffset, end);
    }
    return wavBytes;
  }

  /// Complete unified preprocessing pipeline:
  /// Validates RIFF/WAVE -> decodes 8/16/24/32 PCM or Float32 -> downmixes multi-channel to mono
  /// -> resamples to [targetSampleRate] (default 16000 Hz) -> computes RMS, peak, clipping, & WAV bytes.
  PreprocessedAudio preprocessWav(
    Uint8List rawBytes, {
    int targetSampleRate = defaultSampleRate,
    bool allowHeaderlessPcm16Fallback = false,
  }) {
    if (rawBytes.isEmpty) {
      throw const InvalidAudioFormatException(
        'Recorded audio buffer is empty (0 bytes).',
      );
    }

    late final WavAudioMetadata meta;
    late final Float32List decodedMono;

    final bool hasRiff =
        rawBytes.length >= 12 &&
        _matchesFourCc(rawBytes, 0, 'RIFF') &&
        _matchesFourCc(rawBytes, 8, 'WAVE');

    if (hasRiff) {
      meta = parseWavMetadata(rawBytes);
      final int end = math.min(
        rawBytes.length,
        meta.dataOffset + meta.dataSize,
      );
      final Uint8List payload = Uint8List.sublistView(
        rawBytes,
        meta.dataOffset,
        end,
      );
      decodedMono = _decodeToMonoFloat32(payload, meta);
    } else if (allowHeaderlessPcm16Fallback) {
      if (rawBytes.length < 2 || rawBytes.length.isOdd) {
        throw InvalidAudioFormatException(
          'Invalid raw PCM16 length (${rawBytes.length} bytes).',
        );
      }
      meta = WavAudioMetadata(
        audioFormat: 1,
        channels: 1,
        sampleRate: targetSampleRate,
        byteRate: targetSampleRate * 2,
        blockAlign: 2,
        bitsPerSample: 16,
        dataOffset: 0,
        dataSize: rawBytes.length,
      );
      decodedMono = pcm16ToFloat32(rawBytes);
    } else {
      throw const InvalidAudioFormatException(
        'Input is not a valid RIFF/WAVE container (header missing or invalid).',
      );
    }

    if (decodedMono.isEmpty) {
      throw const InvalidAudioFormatException(
        'Decoded WAV audio contains zero samples.',
      );
    }

    final Float32List resampled = meta.sampleRate == targetSampleRate
        ? decodedMono
        : resampleLinear(decodedMono, meta.sampleRate, targetSampleRate);

    final double rms = calculateRms(resampled);
    final double peak = calculatePeak(resampled);
    final int clippingCount = countClippingSamples(resampled);
    final int durationMs = (resampled.length * 1000 / targetSampleRate).round();
    final Uint8List pcm16Mono = float32ToPcm16(resampled);
    final Uint8List canonicalWav = addWavHeader(
      pcm16Mono,
      sampleRate: targetSampleRate,
      channels: 1,
    );

    return PreprocessedAudio(
      sourceMetadata: meta,
      targetSampleRate: targetSampleRate,
      samples: resampled,
      pcm16Mono: pcm16Mono,
      wavBytes: canonicalWav,
      durationMs: durationMs,
      rms: rms,
      peakAmplitude: peak,
      clippingCount: clippingCount,
      waveformPoints: downsampleForWaveform(resampled, 60),
    );
  }

  /// Decodes interleaved multi-channel PCM (8/16/24/32-bit) or IEEE Float32 to mono Float32.
  Float32List _decodeToMonoFloat32(Uint8List payload, WavAudioMetadata meta) {
    final int bytesPerSample = meta.bitsPerSample ~/ 8;
    final int frameSize = meta.blockAlign > 0
        ? meta.blockAlign
        : bytesPerSample * meta.channels;
    final int frameCount = payload.length ~/ frameSize;
    if (frameCount <= 0) {
      return Float32List(0);
    }

    final ByteData bd = ByteData.sublistView(payload);
    final Float32List out = Float32List(frameCount);

    for (int f = 0; f < frameCount; f++) {
      final int frameBase = f * frameSize;
      double monoSum = 0.0;

      for (int ch = 0; ch < meta.channels; ch++) {
        final int pos = frameBase + ch * bytesPerSample;
        double sample = 0.0;

        if (meta.audioFormat == 3 && meta.bitsPerSample == 32) {
          sample = bd.getFloat32(pos, Endian.little).clamp(-1.0, 1.0);
        } else if (meta.bitsPerSample == 16) {
          sample = bd.getInt16(pos, Endian.little) / 32768.0;
        } else if (meta.bitsPerSample == 8) {
          sample = (payload[pos] - 128) / 128.0;
        } else if (meta.bitsPerSample == 24) {
          int v =
              payload[pos] | (payload[pos + 1] << 8) | (payload[pos + 2] << 16);
          if ((v & 0x800000) != 0) v |= 0xFF000000;
          sample = v.toSigned(32) / 8388608.0;
        } else if (meta.bitsPerSample == 32) {
          sample = bd.getInt32(pos, Endian.little) / 2147483648.0;
        }

        monoSum += sample;
      }

      out[f] = (monoSum / meta.channels).toDouble();
    }

    return out;
  }

  /// High-quality linear interpolation resampler with simple box anti-aliasing when downsampling.
  Float32List resampleLinear(Float32List input, int fromRate, int toRate) {
    if (input.isEmpty || fromRate == toRate || fromRate <= 0 || toRate <= 0) {
      return input;
    }

    final double ratio = fromRate / toRate;
    final int outLength = math.max(1, (input.length / ratio).round());
    final Float32List out = Float32List(outLength);

    if (ratio > 1.0) {
      // Downsampling: average window around srcPos for anti-aliasing + linear blend
      final int halfWin = math.max(1, (ratio / 2.0).floor());
      for (int i = 0; i < outLength; i++) {
        final double center = i * ratio;
        final int start = math.max(0, center.floor() - halfWin);
        final int end = math.min(input.length - 1, center.ceil() + halfWin);
        double acc = 0.0;
        for (int j = start; j <= end; j++) {
          acc += input[j];
        }
        out[i] = (acc / (end - start + 1)).toDouble();
      }
      return out;
    }

    for (int i = 0; i < outLength; i++) {
      final double srcIdx = i * ratio;
      final int i0 = srcIdx.floor().clamp(0, input.length - 1);
      final int i1 = math.min(i0 + 1, input.length - 1);
      final double frac = srcIdx - i0;
      out[i] = (input[i0] * (1.0 - frac) + input[i1] * frac).toDouble();
    }
    return out;
  }

  /// Removes DC offset by subtracting the mean across all samples.
  Float32List removeDcOffset(Float32List samples) {
    if (samples.isEmpty) return samples;
    double sum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sum += samples[i];
    }
    final double mean = sum / samples.length;
    final Float32List out = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      out[i] = (samples[i] - mean).clamp(-1.0, 1.0);
    }
    return out;
  }

  /// Peak-normalizes float32 samples to [targetPeak] when audible (> 0.005 RMS).
  Float32List normalizePeak(Float32List samples, {double targetPeak = 0.9}) {
    if (samples.isEmpty) return samples;
    final double peak = calculatePeak(samples);
    if (peak < 1e-4) return samples;
    final double gain = targetPeak / peak;
    if (gain <= 1.05) {
      return samples; // Avoid unnecessary amplification of loud audio
    }
    final Float32List out = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      out[i] = (samples[i] * gain).clamp(-1.0, 1.0);
    }
    return out;
  }

  /// Counts samples hitting or exceeding +/-0.999 full-scale clipping.
  int countClippingSamples(Float32List samples) {
    int count = 0;
    for (int i = 0; i < samples.length; i++) {
      if (samples[i].abs() >= 0.999) count++;
    }
    return count;
  }

  /// Computes peak normalized amplitude of float32 samples [0.0, 1.0].
  double calculatePeak(Float32List samples) {
    double maxAbs = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final double a = samples[i].abs();
      if (a > maxAbs) maxAbs = a;
    }
    return maxAbs;
  }

  /// Computes Root-Mean-Square (RMS) energy of float32 samples.
  double calculateRms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sumSquares += samples[i] * samples[i];
    }
    return math.sqrt(sumSquares / samples.length);
  }

  /// Computes estimated Signal-to-Noise Ratio (SNR) in dB.
  double estimateSnrDb(Float32List samples) {
    if (samples.length < 320) return 0.0;

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

    final int noiseCount = math.max(1, (numFrames * 0.1).round());
    double noiseSum = 0.0;
    for (int i = 0; i < noiseCount; i++) {
      noiseSum += frameEnergies[i];
    }
    final double noiseEnergy = math.max(1e-9, noiseSum / noiseCount);

    final int signalStart = (numFrames * 0.6).round();
    double signalSum = 0.0;
    int sigCount = 0;
    for (int i = signalStart; i < numFrames; i++) {
      signalSum += frameEnergies[i];
      sigCount++;
    }
    final double signalEnergy = math.max(
      1e-9,
      signalSum / math.max(1, sigCount),
    );

    final double ratio = signalEnergy / noiseEnergy;
    if (ratio <= 0) return 0.0;
    return (10.0 * (math.log(ratio) / math.ln10)).clamp(0.0, 60.0);
  }

  /// Downsamples audio waveform to N display points for UI visualizers.
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

  /// Creates a standard 44-byte RIFF/WAVE header for 16-bit PCM.
  Uint8List addWavHeader(
    Uint8List pcmData, {
    int sampleRate = 16000,
    int channels = 1,
  }) {
    final int totalDataLen = pcmData.length;
    final int totalAudioLen = totalDataLen + 36;
    final int byteRate = sampleRate * channels * 2;

    final Uint8List header = Uint8List(44);
    final ByteData bd = ByteData.sublistView(header);

    header[0] = 0x52;
    header[1] = 0x49;
    header[2] = 0x46;
    header[3] = 0x46;
    bd.setUint32(4, totalAudioLen, Endian.little);
    header[8] = 0x57;
    header[9] = 0x41;
    header[10] = 0x56;
    header[11] = 0x45;
    header[12] = 0x66;
    header[13] = 0x6D;
    header[14] = 0x74;
    header[15] = 0x20;
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, channels * 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    header[36] = 0x64;
    header[37] = 0x61;
    header[38] = 0x74;
    header[39] = 0x61;
    bd.setUint32(40, totalDataLen, Endian.little);

    final Uint8List wav = Uint8List(44 + totalDataLen);
    wav.setRange(0, 44, header);
    wav.setRange(44, 44 + totalDataLen, pcmData);
    return wav;
  }

  /// Converts Float32 mono samples directly into a valid 16kHz (or specified rate) PCM16 WAV buffer.
  Uint8List float32ToWav(Float32List samples, {int sampleRate = 16000}) {
    return addWavHeader(
      float32ToPcm16(samples),
      sampleRate: sampleRate,
      channels: 1,
    );
  }

  bool _matchesFourCc(Uint8List bytes, int offset, String tag) {
    if (offset + 4 > bytes.length) return false;
    return bytes[offset] == tag.codeUnitAt(0) &&
        bytes[offset + 1] == tag.codeUnitAt(1) &&
        bytes[offset + 2] == tag.codeUnitAt(2) &&
        bytes[offset + 3] == tag.codeUnitAt(3);
  }
}
