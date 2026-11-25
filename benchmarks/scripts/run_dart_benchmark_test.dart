import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:liqaa_app/core/ai/audio_preprocessor.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/ai/phoneme_recognition_engine.dart';
import 'package:liqaa_app/core/ai/pronunciation_evaluator.dart';
import 'package:liqaa_app/core/ai/pronunciation_repository.dart';
import 'package:liqaa_app/core/ai/rnnoise_denoiser_engine.dart';
import 'package:liqaa_app/core/ai/silero_vad_engine.dart';
import 'package:liqaa_app/core/ai/speech_to_text_engine.dart';

Map<String, VocabularyWord> _loadDictionaryMap() {
  final raw = File('assets/pronunciation/egyptian_arabic_dictionary.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final list = data['words'] as List<dynamic>;
  final map = <String, VocabularyWord>{};
  for (final item in list) {
    final w = VocabularyWord.fromJson(item as Map<String, dynamic>);
    map[w.wordArabic] = w;
    map[w.wordArabic.replaceFirst(RegExp(r'^ال'), '')] = w;
  }
  return map;
}

VocabularyWord _targetWordForEntry(
  Map<String, dynamic> entry,
  Map<String, VocabularyWord> dictMap,
  PhonemeRecognitionEngine phonemeEngine,
) {
  final target = (entry['target_word'] as String? ?? '').trim();
  if (target.isNotEmpty) {
    final clean = target.replaceFirst(RegExp(r'^ال'), '');
    if (dictMap.containsKey(target)) return dictMap[target]!;
    if (dictMap.containsKey(clean)) return dictMap[clean]!;
  }

  final fallbackWord = target.isNotEmpty ? target : 'كورة';
  final refStr = (entry['reference_ipa'] as String? ?? '').trim();
  final expIpa = refStr.isNotEmpty
      ? refStr.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList()
      : fallbackWord.split('').map(phonemeEngine.mapArToIpa).toList();
  final expAr = fallbackWord.split('');
  final firstConsonant = expAr.isNotEmpty ? expAr.first : 'ك';

  return VocabularyWord(
    id: 'bench_${entry['sample_id']}',
    wordArabic: fallbackWord,
    wordTransliteration: fallbackWord,
    meaningEn: 'BenchmarkTarget',
    targetPhoneme: (entry['target_phoneme'] as String? ?? '').isNotEmpty
        ? entry['target_phoneme'] as String
        : firstConsonant,
    targetPhonemeIpa: expIpa.isNotEmpty ? expIpa.first : 'k',
    phonemeCategory: 'Benchmark',
    difficultyLevel: 1,
    expectedPhonemes: expIpa.isNotEmpty ? expIpa : const ['k'],
    expectedArabicPhonemes: expAr.isNotEmpty ? expAr : const ['ك'],
    yasserTip: '',
  );
}

Uint8List _buildTypedWav({
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
  required int audioFormat,
  required double durationSec,
  double dcOffset = 0.0,
  double amplitude = 0.4,
  bool includeExtraJunk = false,
}) {
  final int frames = math.max(1, (sampleRate * durationSec).round());
  final int bytesPerSample = bitsPerSample ~/ 8;
  final int blockAlign = channels * bytesPerSample;
  final int dataSize = frames * blockAlign;
  final payload = Uint8List(dataSize);
  final bd = ByteData.sublistView(payload);

  for (int f = 0; f < frames; f++) {
    final double s = (dcOffset + amplitude * math.sin(2 * math.pi * 440.0 * f / sampleRate)).clamp(-1.0, 1.0);
    for (int ch = 0; ch < channels; ch++) {
      final int pos = f * blockAlign + ch * bytesPerSample;
      if (audioFormat == 3 && bitsPerSample == 32) {
        bd.setFloat32(pos, s, Endian.little);
      } else if (bitsPerSample == 8) {
        payload[pos] = ((s * 127.0) + 128.0).round().clamp(0, 255);
      } else if (bitsPerSample == 16) {
        bd.setInt16(pos, (s * 32767.0).round().clamp(-32768, 32767), Endian.little);
      } else if (bitsPerSample == 24) {
        final int v = (s * 8388607.0).round().clamp(-8388608, 8388607);
        payload[pos] = v & 0xFF;
        payload[pos + 1] = (v >> 8) & 0xFF;
        payload[pos + 2] = (v >> 16) & 0xFF;
      } else if (bitsPerSample == 32) {
        bd.setInt32(pos, (s * 2147483647.0).round(), Endian.little);
      }
    }
  }

  final junk = includeExtraJunk ? 'LIST_metadata_data_fmt_trap'.codeUnits : <int>[];
  final junkPad = junk.length.isOdd ? [...junk, 0] : junk;
  final int totalSize = 4 + (includeExtraJunk ? 8 + junkPad.length : 0) + (8 + 16) + (8 + dataSize);

  final b = BytesBuilder();
  b.add('RIFF'.codeUnits);
  b.add((ByteData(4)..setUint32(0, totalSize, Endian.little)).buffer.asUint8List());
  b.add('WAVE'.codeUnits);
  if (includeExtraJunk) {
    b.add('LIST'.codeUnits);
    b.add((ByteData(4)..setUint32(0, junkPad.length, Endian.little)).buffer.asUint8List());
    b.add(junkPad);
  }
  b.add('fmt '.codeUnits);
  b.add((ByteData(4)..setUint32(0, 16, Endian.little)).buffer.asUint8List());
  b.add((ByteData(16)
        ..setUint16(0, audioFormat, Endian.little)
        ..setUint16(2, channels, Endian.little)
        ..setUint32(4, sampleRate, Endian.little)
        ..setUint32(8, sampleRate * blockAlign, Endian.little)
        ..setUint16(12, blockAlign, Endian.little)
        ..setUint16(14, bitsPerSample, Endian.little))
      .buffer
      .asUint8List());
  b.add('data'.codeUnits);
  b.add((ByteData(4)..setUint32(0, dataSize, Endian.little)).buffer.asUint8List());
  b.add(payload);
  return b.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const preprocessor = AudioPreprocessor();
  const evaluator = PronunciationEvaluator();
  final resultsDir = Directory('benchmarks/results')..createSync(recursive: true);
  final enhancedSamplesDir = Directory('benchmarks/results/samples')..createSync(recursive: true);

  late SileroVadEngine vadEngine;
  late RnnoiseDenoiserEngine denoiserEngine;
  late PhonemeRecognitionEngine phonemeEngine;
  late SpeechToTextEngine sttEngine;
  late PronunciationRepository repo;
  late Map<String, VocabularyWord> dictMap;

  setUpAll(() async {
    vadEngine = SileroVadEngine(modelPathOverride: 'assets/ai_models/silero/silero_vad.onnx');
    denoiserEngine = RnnoiseDenoiserEngine(
      preprocessor: preprocessor,
      modelPathOverride: 'assets/ai_models/gtcrn/gtcrn_simple.onnx',
    );
    phonemeEngine = PhonemeRecognitionEngine(
      preprocessor: preprocessor,
      modelPathOverride: 'assets/ai_models/wav2vec2_espeak/model_q4f16.onnx',
      vocabPathOverride: 'assets/ai_models/wav2vec2_espeak/vocab.json',
    );
    sttEngine = SpeechToTextEngine(
      preprocessor: preprocessor,
      encoderPathOverride: 'assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx',
      decoderPathOverride: 'assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx',
      tokensPathOverride: 'assets/ai_models/whisper_tiny/tiny-tokens.txt',
    );

    dictMap = _loadDictionaryMap();
    repo = PronunciationRepository(
      preprocessor: preprocessor,
      vadEngine: vadEngine,
      denoiserEngine: denoiserEngine,
      phonemeEngine: phonemeEngine,
      evaluator: evaluator,
      sttEngine: sttEngine,
    );
  });

  tearDownAll(() {
    vadEngine.dispose();
    denoiserEngine.dispose();
    phonemeEngine.dispose();
    sttEngine.dispose();
  });

  test('Execute Full 100-Sample Benchmark, Preprocessing Stress, Ablation, Anti-Cheating & Runtime Stability', () async {
    // ------------------------------------------------------------------
    // 1. Measure Cold-Start Init Latency & RSS Delta (Section 14)
    // ------------------------------------------------------------------
    final int rssStart = ProcessInfo.currentRss;
    final swVadInit = Stopwatch()..start();
    await vadEngine.initialize();
    swVadInit.stop();
    final int rssAfterVad = ProcessInfo.currentRss;

    final swGtcrnInit = Stopwatch()..start();
    await denoiserEngine.initialize();
    swGtcrnInit.stop();
    final int rssAfterGtcrn = ProcessInfo.currentRss;

    final swW2vInit = Stopwatch()..start();
    await phonemeEngine.initialize();
    swW2vInit.stop();
    final int rssAfterW2v = ProcessInfo.currentRss;

    final swSttInit = Stopwatch()..start();
    await sttEngine.initialize();
    swSttInit.stop();
    final int rssAfterStt = ProcessInfo.currentRss;

    expect(vadEngine.isNativeAvailable, isTrue, reason: vadEngine.lastError);
    expect(denoiserEngine.isNativeAvailable, isTrue, reason: denoiserEngine.lastError);
    expect(phonemeEngine.isNativeAvailable, isTrue, reason: phonemeEngine.lastError);
    expect(sttEngine.isNativeAvailable, isTrue, reason: sttEngine.lastError);

    // ------------------------------------------------------------------
    // 2. Section 6: AudioPreprocessor Stress Suite
    // ------------------------------------------------------------------
    final prepResults = <Map<String, dynamic>>[];
    final stressCases = <Map<String, dynamic>>[
      {'id': 'sr_8k', 'bytes': _buildTypedWav(sampleRate: 8000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.6), 'expectOk': true},
      {'id': 'sr_16k', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.6), 'expectOk': true},
      {'id': 'sr_22k', 'bytes': _buildTypedWav(sampleRate: 22050, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.6), 'expectOk': true},
      {'id': 'sr_24k', 'bytes': _buildTypedWav(sampleRate: 24000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.6), 'expectOk': true},
      {'id': 'sr_44k', 'bytes': _buildTypedWav(sampleRate: 44100, channels: 2, bitsPerSample: 16, audioFormat: 1, durationSec: 0.6), 'expectOk': true},
      {'id': 'sr_48k', 'bytes': _buildTypedWav(sampleRate: 48000, channels: 2, bitsPerSample: 16, audioFormat: 1, durationSec: 0.6), 'expectOk': true},
      {'id': 'pcm8', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 8, audioFormat: 1, durationSec: 0.5), 'expectOk': true},
      {'id': 'pcm24', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 24, audioFormat: 1, durationSec: 0.5), 'expectOk': true},
      {'id': 'pcm32_int', 'bytes': _buildTypedWav(sampleRate: 44100, channels: 1, bitsPerSample: 32, audioFormat: 1, durationSec: 0.5), 'expectOk': true},
      {'id': 'float32_ieee', 'bytes': _buildTypedWav(sampleRate: 44100, channels: 1, bitsPerSample: 32, audioFormat: 3, durationSec: 0.5), 'expectOk': true},
      {'id': 'extra_riff_list', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.5, includeExtraJunk: true), 'expectOk': true},
      {'id': 'very_short_40ms', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.04), 'expectOk': true},
      {'id': 'long_8s', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 8.0), 'expectOk': true},
      {'id': 'clipped_high', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.5, amplitude: 1.5), 'expectOk': true},
      {'id': 'low_amp_speech', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.5, amplitude: 0.005), 'expectOk': true},
      {'id': 'dc_offset_plus_035', 'bytes': _buildTypedWav(sampleRate: 16000, channels: 1, bitsPerSample: 16, audioFormat: 1, durationSec: 0.5, dcOffset: 0.35, amplitude: 0.2), 'expectOk': true},
      {'id': 'truncated_wav_30b', 'bytes': Uint8List(30), 'expectOk': false},
      {'id': 'corrupted_header', 'bytes': Uint8List.fromList('JUNK_NOT_RIFF_WAV_PAYLOAD_00000000000000000000000'.codeUnits), 'expectOk': false},
      {'id': 'missing_header_pcm', 'bytes': Uint8List(3200), 'expectOk': false},
      {'id': 'empty_bytes', 'bytes': Uint8List(0), 'expectOk': false},
    ];

    for (final sc in stressCases) {
      final raw = sc['bytes'] as Uint8List;
      final bool expectOk = sc['expectOk'] as bool;
      bool ok = false;
      String? err;
      int? outSamples;
      int? durMs;
      double? rms;
      double? peak;
      int? clips;
      bool validOutWav = false;
      try {
        final res = preprocessor.preprocessWav(raw, targetSampleRate: 16000);
        final outMeta = preprocessor.parseWavMetadata(res.wavBytes);
        ok = true;
        outSamples = res.sampleCount;
        durMs = res.durationMs;
        rms = res.rms;
        peak = res.peakAmplitude;
        clips = res.clippingCount;
        validOutWav = outMeta.sampleRate == 16000 && outMeta.channels == 1;
      } catch (e) {
        ok = false;
        err = e.toString();
      }
      expect(ok, equals(expectOk), reason: 'Stress ${sc['id']} failed: err=$err');
      prepResults.add({
        'id': sc['id'],
        'expect_ok': expectOk,
        'actual_ok': ok,
        'out_samples': outSamples,
        'duration_ms': durMs,
        'rms': rms,
        'peak': peak,
        'clipping_count': clips,
        'valid_out_wav': validOutWav,
        'error': err,
      });
    }
    File('${resultsDir.path}/preprocessing_stress.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(prepResults),
    );

    // ------------------------------------------------------------------
    // 3. Sections 7–11 & 13: Run All 100 Independent Samples
    // ------------------------------------------------------------------
    final manifestLines = File('benchmarks/audio/manifest.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    final sampleLogFile = File('${resultsDir.path}/sample_level_results.jsonl');
    if (sampleLogFile.existsSync()) sampleLogFile.deleteSync();
    final sampleSink = sampleLogFile.openWrite(mode: FileMode.append);

    for (int i = 0; i < manifestLines.length; i++) {
      final entry = jsonDecode(manifestLines[i]) as Map<String, dynamic>;
      final sid = entry['sample_id'] as String;
      final rawBytes = File(entry['file_path'] as String).readAsBytesSync();
      final prep = preprocessor.preprocessWav(rawBytes, targetSampleRate: 16000);
      final cleanMono = preprocessor.removeDcOffset(prep.samples);
      final rawRms = preprocessor.calculateRms(cleanMono);
      final rawPeak = preprocessor.calculatePeak(cleanMono);

      // Independent Silero VAD
      final swVad = Stopwatch()..start();
      final vad = vadEngine.analyze(cleanMono);
      swVad.stop();
      final int retainedSamples = vad.trimmedSamples?.length ?? 0;
      final int retainedMs = (retainedSamples * 1000 / 16000).round();

      // Independent GTCRN (on VAD speech or whole audio if non-speech)
      final Float32List denoiseIn = (vad.trimmedSamples != null && vad.trimmedSamples!.isNotEmpty)
          ? vad.trimmedSamples!
          : cleanMono;
      denoiserEngine.enabled = true;
      denoiserEngine.mode = DenoiserMode.neuralGtcrn;
      final swDen = Stopwatch()..start();
      final denoise = denoiserEngine.process(denoiseIn);
      swDen.stop();
      bool denoisedWavValid = false;
      if (denoise.hasValidAudio) {
        try {
          final w = preprocessor.float32ToWav(denoise.processedSamples, sampleRate: 16000);
          final m = preprocessor.parseWavMetadata(w);
          denoisedWavValid = m.dataSize > 0 && m.sampleRate == 16000;
        } catch (_) {}
      }

      // Phoneme Recognition Ablation B (raw), C (VAD), D (GTCRN only), E (VAD+GTCRN) — ZERO target hint!
      final resRaw = await phonemeEngine.recognizePhonemesDetailed(cleanMono);
      final resVad = (vad.trimmedSamples != null && vad.trimmedSamples!.isNotEmpty)
          ? await phonemeEngine.recognizePhonemesDetailed(vad.trimmedSamples!)
          : null;
      final resGtcrn = denoise.hasValidAudio
          ? await phonemeEngine.recognizePhonemesDetailed(denoise.processedSamples)
          : null;
      final resFullRawGtcrn = (vad.trimmedSamples != null && vad.trimmedSamples!.isNotEmpty)
          ? await (() async {
              final dFull = denoiserEngine.process(cleanMono);
              return dFull.hasValidAudio ? phonemeEngine.recognizePhonemesDetailed(dFull.processedSamples) : null;
            })()
          : resGtcrn;

      // Independent Whisper Tiny ASR (only on first <= 6s slice if very long to prevent decode hang, capturing real latency/RTF)
      final Float32List sttInput = (vad.trimmedSamples != null && vad.trimmedSamples!.isNotEmpty)
          ? vad.trimmedSamples!
          : cleanMono;
      final stt = await sttEngine.transcribe(sttInput);

      // Full Production PronunciationRepository Assessment (real production entry point)
      final targetWord = _targetWordForEntry(entry, dictMap, phonemeEngine);
      final evalDefault = await repo.evaluateAudio(rawAudioBytes: rawBytes, targetWord: targetWord);

      // Ablation F (no denoise) vs Forced denoise evaluated using exact VAD / VAD+GTCRN outputs
      final evalNoDenoise = (!vad.speechDetected || resVad == null)
          ? evalDefault
          : evaluator.evaluate(word: targetWord, recognizedTokens: resVad.tokens, latencyMs: resVad.latencyMs);
      final evalForceDenoise = (!vad.speechDetected || resGtcrn == null)
          ? evalDefault
          : evaluator.evaluate(word: targetWord, recognizedTokens: resGtcrn.tokens, latencyMs: resGtcrn.latencyMs);

      final record = {
        'sample_id': sid,
        'category': entry['category'],
        'original_dataset': entry['original_dataset'],
        'dialect': entry['arabic_dialect'],
        'audio_type': entry['audio_type'],
        'target_word': entry['target_word'],
        'actual_spoken_word': entry['actual_spoken_word'],
        'reference_ipa': entry['reference_ipa'],
        'actual_speech_present': entry['actual_speech_present'],
        'expected_outcome': entry['expected_outcome'],
        'gt_reliability': entry['ground_truth_reliability'],
        'in_dictionary': entry['in_dictionary'],
        'src_sample_rate': prep.sourceMetadata.sampleRate,
        'src_bits': prep.sourceMetadata.bitsPerSample,
        'duration_ms': prep.durationMs,
        'raw_rms': rawRms,
        'raw_peak': rawPeak,
        'vad_detected': vad.speechDetected,
        'vad_segments': vad.segments.length,
        'vad_retained_ms': retainedMs,
        'vad_latency_ms': swVad.elapsedMilliseconds,
        'gtcrn_ok': denoise.hasValidAudio,
        'gtcrn_wav_valid': denoisedWavValid,
        'gtcrn_rms_before': denoise.rmsBefore,
        'gtcrn_rms_after': denoise.rmsAfter,
        'gtcrn_snr_before': denoise.snrBeforeDb,
        'gtcrn_snr_after': denoise.snrAfterDb,
        'gtcrn_latency_ms': swDen.elapsedMilliseconds,
        'w2v_raw_ipa': resRaw.tokens.map((t) => t.symbol).toList(),
        'w2v_raw_conf': resRaw.averageConfidence,
        'w2v_raw_margin': resRaw.averageAcousticMargin,
        'w2v_raw_latency_ms': resRaw.latencyMs,
        'w2v_raw_token_ids': resRaw.tokens.map((t) => t.tokenId).toList(),
        'w2v_raw_tokens': resRaw.tokens.map((t) => t.toJson()).toList(),
        'w2v_vad_ipa': resVad?.tokens.map((t) => t.symbol).toList() ?? const <String>[],
        'w2v_vad_gtcrn_ipa': resGtcrn?.tokens.map((t) => t.symbol).toList() ?? const <String>[],
        'w2v_gtcrn_only_ipa': resFullRawGtcrn?.tokens.map((t) => t.symbol).toList() ?? const <String>[],
        'whisper_text': stt.text,
        'whisper_latency_ms': stt.latencyMs,
        'whisper_rtf': stt.realTimeFactor,
        'eval_default_passed': evalDefault.passed,
        'eval_default_score': evalDefault.overallScore,
        'eval_default_stars': evalDefault.stars,
        'eval_default_error': evalDefault.errorType.name,
        'eval_default_latency_ms': evalDefault.latencyMs,
        'eval_default_ipa': evalDefault.recognizedPhonemes.map((t) => t.symbol).toList(),
        'eval_no_denoise_passed': evalNoDenoise.passed,
        'eval_no_denoise_score': evalNoDenoise.overallScore,
        'eval_no_denoise_error': evalNoDenoise.errorType.name,
        'eval_force_denoise_passed': evalForceDenoise.passed,
        'eval_force_denoise_score': evalForceDenoise.overallScore,
        'eval_force_denoise_error': evalForceDenoise.errorType.name,
      };
      sampleSink.writeln(jsonEncode(record));
      if ((i + 1) % 10 == 0 || i == 0) {
        await sampleSink.flush();
        // ignore: avoid_print
        print('BENCH_PROGRESS ${i + 1}/${manifestLines.length} ($sid ${entry['category']})');
      }
    }
    await sampleSink.flush();
    await sampleSink.close();

    // ------------------------------------------------------------------
    // 4. Controlled Paired Noise (Section 8) & Synthetic Minimal Pairs
    // ------------------------------------------------------------------
    final ctrlLines = File('benchmarks/audio/controlled_manifest.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
    final ctrlLogs = <String>[];
    for (final line in ctrlLines) {
      final entry = jsonDecode(line) as Map<String, dynamic>;
      if (entry['type'] == 'paired_noisy_speech') {
        final noisyBytes = File(entry['noisy_path'] as String).readAsBytesSync();
        final cleanBytes = File(entry['clean_path'] as String).readAsBytesSync();
        final noisyPrep = preprocessor.preprocessWav(noisyBytes, targetSampleRate: 16000);
        final cleanPrep = preprocessor.preprocessWav(cleanBytes, targetSampleRate: 16000);

        denoiserEngine.enabled = true;
        denoiserEngine.mode = DenoiserMode.neuralGtcrn;
        final sw = Stopwatch()..start();
        final den = denoiserEngine.process(noisyPrep.samples);
        sw.stop();

        final enhPath = '${enhancedSamplesDir.path}/${entry['id']}_denoised.wav';
        if (den.hasValidAudio) {
          File(enhPath).writeAsBytesSync(preprocessor.float32ToWav(den.processedSamples, sampleRate: 16000));
        }

        final vadNoisy = vadEngine.analyze(noisyPrep.samples);
        final vadClean = vadEngine.analyze(cleanPrep.samples);
        final w2vClean = await phonemeEngine.recognizePhonemesDetailed(cleanPrep.samples);
        final w2vNoisyRaw = await phonemeEngine.recognizePhonemesDetailed(noisyPrep.samples);
        final w2vDenoised = den.hasValidAudio
            ? await phonemeEngine.recognizePhonemesDetailed(den.processedSamples)
            : null;

        ctrlLogs.add(jsonEncode({
          ...entry,
          'enh_path': den.hasValidAudio ? enhPath.replaceAll('\\', '/') : null,
          'gtcrn_latency_ms': sw.elapsedMilliseconds,
          'vad_clean_detected': vadClean.speechDetected,
          'vad_noisy_detected': vadNoisy.speechDetected,
          'clean_ipa': w2vClean.tokens.map((t) => t.symbol).toList(),
          'noisy_raw_ipa': w2vNoisyRaw.tokens.map((t) => t.symbol).toList(),
          'denoised_ipa': w2vDenoised?.tokens.map((t) => t.symbol).toList() ?? const <String>[],
        }));
      } else if (entry['type'] == 'controlled_synthetic_tts') {
        final rawBytes = File(entry['path'] as String).readAsBytesSync();
        final tw = _targetWordForEntry(entry, dictMap, phonemeEngine);
        final prep = preprocessor.preprocessWav(rawBytes, targetSampleRate: 16000);
        final w2v = await phonemeEngine.recognizePhonemesDetailed(prep.samples);
        final ev = await repo.evaluateAudio(rawAudioBytes: rawBytes, targetWord: tw);
        ctrlLogs.add(jsonEncode({
          ...entry,
          'ipa': w2v.tokens.map((t) => t.symbol).toList(),
          'passed': ev.passed,
          'score': ev.overallScore,
          'error_type': ev.errorType.name,
        }));
      }
    }
    File('${resultsDir.path}/controlled_paired_results.jsonl').writeAsStringSync('${ctrlLogs.join('\n')}\n');

    // ------------------------------------------------------------------
    // 5. Section 12: Anti-Cheating & Target Leakage Verification
    // ------------------------------------------------------------------
    final koraAudio = File('assets/audio_samples/correct_kora.wav').readAsBytesSync();
    final testTargets = ['كورة', 'سمكة', 'أرنب', 'باب', 'مدرسة'];
    final targetEvalResults = <Map<String, dynamic>>[];
    String? baselineIpaSignature;

    for (final twStr in testTargets) {
      final tw = dictMap[twStr] ?? VocabularyWord(
        id: 't_$twStr', wordArabic: twStr, wordTransliteration: twStr, meaningEn: twStr,
        targetPhoneme: twStr[0], targetPhonemeIpa: phonemeEngine.mapArToIpa(twStr[0]),
        phonemeCategory: 'Test', difficultyLevel: 1,
        expectedPhonemes: twStr.split('').map(phonemeEngine.mapArToIpa).toList(),
        expectedArabicPhonemes: twStr.split(''), yasserTip: '',
      );
      final res = await repo.evaluateAudio(rawAudioBytes: koraAudio, targetWord: tw);
      final sig = res.recognizedPhonemes.map((t) => '${t.symbol}@${t.startMs}-${t.endMs}').join('|');
      baselineIpaSignature ??= sig;
      expect(sig, equals(baselineIpaSignature), reason: 'Target leakage detected! Phonemes changed for $twStr');
      targetEvalResults.add({
        'target_word': twStr,
        'recognized_ipa_sig': sig,
        'passed': res.passed,
        'score': res.overallScore,
        'error_type': res.errorType.name,
      });
    }

    // Also verify missing model fails cleanly with modelInitFailed
    final missingPhoneme = PhonemeRecognitionEngine(
      modelPathOverride: 'assets/ai_models/wav2vec2_espeak/nonexistent.onnx',
      vocabPathOverride: 'assets/ai_models/wav2vec2_espeak/vocab.json',
    );
    await missingPhoneme.initialize();
    final brokenRepo = PronunciationRepository(
      vadEngine: vadEngine,
      denoiserEngine: denoiserEngine,
      phonemeEngine: missingPhoneme,
    );
    final brokenRes = await brokenRepo.evaluateAudio(rawAudioBytes: koraAudio, targetWord: dictMap['كورة']!);
    expect(brokenRes.errorType.name, equals('modelInitFailed'));
    missingPhoneme.dispose();

    File('${resultsDir.path}/anti_cheating_results.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'same_audio_different_targets': targetEvalResults,
        'ipa_invariant_across_all_targets': true,
        'missing_model_error_type': brokenRes.errorType.name,
        'missing_model_stage_failed': brokenRes.pipelineStageFailed,
      }),
    );

    // ------------------------------------------------------------------
    // 6. Section 14: 50 Consecutive Inference Cycles Memory & Latency Stability
    // ------------------------------------------------------------------
    final koraPrep = preprocessor.preprocessWav(koraAudio, targetSampleRate: 16000);
    final runLatenciesMs = <int>[];
    final rssTimelineMb = <Map<String, dynamic>>[];

    for (int iter = 1; iter <= 50; iter++) {
      final swRun = Stopwatch()..start();
      final v = vadEngine.analyze(koraPrep.samples);
      final d = denoiserEngine.process(v.trimmedSamples ?? koraPrep.samples);
      final p = await phonemeEngine.recognizePhonemesDetailed(d.processedSamples);
      swRun.stop();
      expect(p.hasError, isFalse);
      runLatenciesMs.add(swRun.elapsedMilliseconds);
      if (iter == 1 || iter % 10 == 0) {
        rssTimelineMb.add({
          'iteration': iter,
          'rss_mb': double.parse((ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(2)),
          'latency_ms': swRun.elapsedMilliseconds,
        });
      }
    }

    final sortedLat = [...runLatenciesMs]..sort();
    final meanLat = runLatenciesMs.reduce((a, b) => a + b) / runLatenciesMs.length;
    final p50Lat = sortedLat[sortedLat.length ~/ 2];
    final p95Lat = sortedLat[((sortedLat.length - 1) * 0.95).round()];

    File('${resultsDir.path}/runtime_stability.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'cold_start_ms': {
          'silero_vad': swVadInit.elapsedMilliseconds,
          'gtcrn_denoiser': swGtcrnInit.elapsedMilliseconds,
          'wav2vec2_espeak': swW2vInit.elapsedMilliseconds,
          'whisper_tiny': swSttInit.elapsedMilliseconds,
        },
        'rss_mb': {
          'baseline': double.parse((rssStart / (1024 * 1024)).toStringAsFixed(2)),
          'after_vad': double.parse((rssAfterVad / (1024 * 1024)).toStringAsFixed(2)),
          'after_gtcrn': double.parse((rssAfterGtcrn / (1024 * 1024)).toStringAsFixed(2)),
          'after_wav2vec2': double.parse((rssAfterW2v / (1024 * 1024)).toStringAsFixed(2)),
          'after_whisper': double.parse((rssAfterStt / (1024 * 1024)).toStringAsFixed(2)),
        },
        'fifty_runs': {
          'audio_duration_ms': koraPrep.durationMs,
          'mean_latency_ms': double.parse(meanLat.toStringAsFixed(1)),
          'median_p50_ms': p50Lat,
          'p95_ms': p95Lat,
          'min_ms': sortedLat.first,
          'max_ms': sortedLat.last,
          'rtf_mean': double.parse((meanLat / math.max(1, koraPrep.durationMs)).toStringAsFixed(3)),
          'rss_timeline': rssTimelineMb,
        },
      }),
    );
  }, timeout: const Timeout(Duration(minutes: 30)));
}
