import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'ai_asset_helper.dart';
import 'audio_preprocessor.dart';
import 'models/phoneme_token.dart';
import 'ort_dynamic_session.dart';

/// Result returned by blind acoustic phoneme recognition (`Wav2Vec2-LV60-eSpeak-CV-FT`).
class PhonemeRecognitionResult {
  final List<PhonemeToken> tokens;
  final int latencyMs;
  final int frameCount;
  final int audioDurationMs;
  final double? averageConfidence;
  final double? averageAcousticMargin;
  final bool isNativeModel;
  final String modelName;
  final String? errorMessage;

  const PhonemeRecognitionResult({
    required this.tokens,
    required this.latencyMs,
    required this.frameCount,
    required this.audioDurationMs,
    this.averageConfidence,
    this.averageAcousticMargin,
    required this.isNativeModel,
    this.modelName = 'Wav2Vec2-LV60-eSpeak-CV-FT (ONNX Q4F16)',
    this.errorMessage,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

/// Real Blind On-Device Acoustic Phoneme Recognition Engine.
///
/// Architecture:
/// - Model: `onnx-community/wav2vec2-lv-60-espeak-cv-ft-ONNX` (`model_q4f16.onnx`, Apache-2.0, 392 IPA tokens)
/// - Runtime: `OrtDynamicSession` over `sherpa_onnx`'s bundled ONNX Runtime (v1.28.2, supports `MatMulNBits`)
/// - Zero target-word hint, zero Whisper transcript leakage, zero G2P fabrication.
/// - Emits true frame-level acoustic IPA tokens with real softmax posteriors, `top1 - top2` margins,
///   and CTC frame alignment timestamps (`isTimestampEstimated: false`).
class PhonemeRecognitionEngine {
  static const String defaultModelAsset = 'assets/ai_models/wav2vec2_espeak/model_q4f16.onnx';
  static const String defaultVocabAsset = 'assets/ai_models/wav2vec2_espeak/vocab.json';
  static const int _minWav2VecSamples = 1600; // 100ms minimum at 16kHz

  final AudioPreprocessor _preprocessor;
  final String? modelPathOverride;
  final String? vocabPathOverride;

  OrtDynamicSession? _session;
  final Map<int, String> _idToToken = {};
  final Map<String, int> _tokenToId = {};
  final Set<int> _skipTokenIds = {};

  bool _isInitialized = false;
  bool _isNativeAvailable = false;
  String? _modelPath;
  String? _vocabPath;
  String? _lastError;

  PhonemeRecognitionEngine({
    AudioPreprocessor? preprocessor,
    this.modelPathOverride,
    this.vocabPathOverride,
  }) : _preprocessor = preprocessor ?? const AudioPreprocessor();

  bool get isInitialized => _isInitialized;
  bool get isNativeAvailable => _isNativeAvailable;
  int get tokenCount => _idToToken.length;
  String? get modelPath => _modelPath;
  String? get lastError => _lastError;

  /// Loads `vocab.json` and opens the quantized Wav2Vec2-eSpeak ONNX session.
  Future<void> initialize() async {
    if (_isInitialized && _isNativeAvailable) return;
    _lastError = null;

    try {
      _modelPath = modelPathOverride ?? await AiAssetHelper.getLocalAssetPath(defaultModelAsset);
      _vocabPath = vocabPathOverride ?? await AiAssetHelper.getLocalAssetPath(defaultVocabAsset);

      if (!File(_modelPath!).existsSync()) {
        _isNativeAvailable = false;
        _lastError = 'Wav2Vec2-eSpeak ONNX model missing at $_modelPath';
        _isInitialized = true;
        return;
      }
      if (!File(_vocabPath!).existsSync()) {
        _isNativeAvailable = false;
        _lastError = 'Wav2Vec2-eSpeak vocab.json missing at $_vocabPath';
        _isInitialized = true;
        return;
      }

      _loadVocab(_vocabPath!);
      _session?.dispose();
      _session = null;
      // Android CPU may lack the Float16 fused GELU kernel selected by
      // extended graph optimizations. Basic/disabled optimization avoids
      // introducing that fusion when the original graph is supported.
      final levels = Platform.isAndroid ? const [1, 0] : const [99];
      final failures = <String>[];
      for (final level in levels) {
        OrtDynamicSession? candidate;
        try {
          candidate = OrtDynamicSession.fromFile(
            _modelPath!, numThreads: 2, graphOptimizationLevel: level,
          );
          // This is a runtime compatibility probe, not a pronunciation test.
          final probe = candidate.runFloat32(Float32List(16000), [1, 16000]);
          _validateOutput(probe);
          _session = candidate;
          candidate = null;
          debugPrint('[PhonemeRecognitionEngine] ORT optimization=$level passed inference probe');
          break;
        } catch (e) {
          failures.add('optimization=$level: $e');
        } finally {
          candidate?.dispose();
        }
      }
      if (_session == null) {
        throw StateError('No compatible Wav2Vec2 session: ${failures.join("; ")}');
      }
      _isNativeAvailable = true;
      _lastError = null;
      debugPrint(
        '[PhonemeRecognitionEngine] Initialized real Wav2Vec2-eSpeak ONNX '
        '(ORT ${_session!.runtimeVersion}, ${_idToToken.length} IPA tokens)',
      );
    } catch (e) {
      _isNativeAvailable = false;
      _lastError = 'Wav2Vec2-eSpeak initialization failed: $e';
      debugPrint('[PhonemeRecognitionEngine] $_lastError');
    }

    _isInitialized = true;
  }

  void _loadVocab(String vocabPath) {
    _idToToken.clear();
    _tokenToId.clear();
    _skipTokenIds.clear();

    final decoded = jsonDecode(File(vocabPath).readAsStringSync()) as Map<String, dynamic>;
    decoded.forEach((token, rawId) {
      final id = rawId as int;
      _idToToken[id] = token;
      _tokenToId[token] = id;
      if (token == '<pad>' || token == '<s>' || token == '</s>' || token == '<unk>' || token == '|') {
        _skipTokenIds.add(id);
      }
    });
  }

  /// Blindly recognizes IPA phonemes directly from 16kHz float32 audio samples.
  /// Returns detailed result with calibrated posteriors, frame timestamps, latency, or explicit error.
  Future<PhonemeRecognitionResult> recognizePhonemesDetailed(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    final Stopwatch sw = Stopwatch()..start();

    if (!_isInitialized) {
      await initialize();
    }

    final Float32List prepared = sampleRate == 16000
        ? samples
        : _preprocessor.resampleLinear(samples, sampleRate, 16000);
    final int durationMs = (prepared.length * 1000 / 16000).round();

    if (prepared.isEmpty || durationMs < 60) {
      sw.stop();
      return PhonemeRecognitionResult(
        tokens: const [],
        latencyMs: sw.elapsedMilliseconds,
        frameCount: 0,
        audioDurationMs: durationMs,
        isNativeModel: _isNativeAvailable,
      );
    }

    final double rms = _preprocessor.calculateRms(prepared);
    final double peak = _preprocessor.calculatePeak(prepared);
    if (rms < 0.0005 && peak < 0.003) {
      sw.stop();
      return PhonemeRecognitionResult(
        tokens: const [],
        latencyMs: sw.elapsedMilliseconds,
        frameCount: 0,
        audioDurationMs: durationMs,
        isNativeModel: _isNativeAvailable,
      );
    }

    if (_session == null || !_isNativeAvailable) {
      sw.stop();
      return PhonemeRecognitionResult(
        tokens: const [],
        latencyMs: sw.elapsedMilliseconds,
        frameCount: 0,
        audioDurationMs: durationMs,
        isNativeModel: false,
        errorMessage: _lastError ?? 'Wav2Vec2-eSpeak acoustic model is not initialized.',
      );
    }

    try {
      // Pad ultra-short speech bursts (< 100ms) so Wav2Vec2 CNN stride kernels succeed cleanly
      final Float32List padded = prepared.length >= _minWav2VecSamples
          ? prepared
          : (Float32List(_minWav2VecSamples)..setRange(0, prepared.length, prepared));

      final Float32List normalized = _zeroMeanUnitVar(padded);
      final OrtFloatTensorResult out = _session!.runFloat32(
        normalized,
        [1, normalized.length],
      );

      if (out.shape.length != 3 || out.shape[0] != 1 || out.shape[1] <= 0 || out.shape[2] != _idToToken.length || out.data.length != out.shape[1] * out.shape[2] || out.data.any((v) => !v.isFinite)) {
        sw.stop();
        return PhonemeRecognitionResult(
          tokens: const [],
          latencyMs: sw.elapsedMilliseconds,
          frameCount: 0,
          audioDurationMs: durationMs,
          isNativeModel: true,
          errorMessage: 'Unexpected Wav2Vec2 output shape: ${out.shape}',
        );
      }

      final int tFrames = out.shape[1];
      final int vocabSize = out.shape[2];
      final double msPerFrame = (normalized.length * 1000.0 / 16000.0) / tFrames;

      final List<PhonemeToken> decoded = _ctcGreedyDecode(
        out.data,
        tFrames: tFrames,
        vocabSize: vocabSize,
        msPerFrame: msPerFrame,
        maxAudioMs: durationMs,
      );

      sw.stop();
      double? avgConf;
      double? avgMargin;
      if (decoded.isNotEmpty) {
        avgConf = decoded.map((t) => t.confidence).reduce((a, b) => a + b) / decoded.length;
        final margins = decoded.map((t) => t.acousticMargin).whereType<double>().toList();
        if (margins.isNotEmpty) {
          avgMargin = margins.reduce((a, b) => a + b) / margins.length;
        }
      }

      return PhonemeRecognitionResult(
        tokens: decoded,
        latencyMs: sw.elapsedMilliseconds,
        frameCount: tFrames,
        audioDurationMs: durationMs,
        averageConfidence: avgConf,
        averageAcousticMargin: avgMargin,
        isNativeModel: true,
      );
    } catch (e) {
      sw.stop();
      _lastError = 'Wav2Vec2-eSpeak inference error: $e';
      debugPrint('[PhonemeRecognitionEngine] $_lastError');
      return PhonemeRecognitionResult(
        tokens: const [],
        latencyMs: sw.elapsedMilliseconds,
        frameCount: 0,
        audioDurationMs: durationMs,
        isNativeModel: false,
        errorMessage: _lastError,
      );
    }
  }

  /// Standard `List<PhonemeToken>` convenience wrapper (blind, no expected answer).
  Future<List<PhonemeToken>> recognizePhonemes(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    final res = await recognizePhonemesDetailed(samples, sampleRate: sampleRate);
    return res.tokens;
  }

  void _validateOutput(OrtFloatTensorResult out) {
    if (out.shape.length != 3 || out.shape[0] != 1 ||
        out.shape[1] <= 0 || out.shape[2] != _idToToken.length ||
        out.data.length != out.shape[1] * out.shape[2] ||
        out.data.any((value) => !value.isFinite)) {
      throw StateError('Invalid Wav2Vec2 logits: ${out.shape}');
    }
  }

  Float32List _zeroMeanUnitVar(Float32List samples) {
    double sum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sum += samples[i];
    }
    final double mean = sum / samples.length;

    double varSum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final double d = samples[i] - mean;
      varSum += d * d;
    }
    final double std = math.sqrt(varSum / samples.length + 1e-7);

    final Float32List out = Float32List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      out[i] = ((samples[i] - mean) / std).toDouble();
    }
    return out;
  }

  List<PhonemeToken> _ctcGreedyDecode(
    Float32List logits, {
    required int tFrames,
    required int vocabSize,
    required double msPerFrame,
    required int maxAudioMs,
  }) {
    final List<PhonemeToken> tokens = [];

    int prevId = -1;
    int? activeId;
    int activeStartFrame = 0;
    final List<double> activeProbs = [];
    final List<double> activeMargins = [];

    void flushActive(int endFrameInclusive) {
      if (activeId == null) return;
      final String symbol = _idToToken[activeId!] ?? '';
      if (symbol.isNotEmpty && !_skipTokenIds.contains(activeId)) {
        final double meanProb =
            activeProbs.reduce((a, b) => a + b) / math.max(1, activeProbs.length);
        final double meanMargin =
            activeMargins.reduce((a, b) => a + b) / math.max(1, activeMargins.length);
        final int startMs = (activeStartFrame * msPerFrame).round().clamp(0, maxAudioMs);
        final int endMs = ((endFrameInclusive + 1) * msPerFrame).round().clamp(startMs, maxAudioMs);

        tokens.add(PhonemeToken(
          symbol: symbol,
          arabicSymbol: mapIpaToAr(symbol),
          tokenId: activeId!,
          confidence: double.parse(meanProb.clamp(0.0, 1.0).toStringAsFixed(3)),
          acousticMargin: double.parse(meanMargin.clamp(0.0, 1.0).toStringAsFixed(3)),
          startFrame: activeStartFrame,
          endFrame: endFrameInclusive,
          startMs: startMs,
          endMs: endMs,
          isAccurate: true,
          isTimestampEstimated: false,
        ));
      }
      activeId = null;
      activeProbs.clear();
      activeMargins.clear();
    }

    for (int t = 0; t < tFrames; t++) {
      final int rowBase = t * vocabSize;
      double maxLogit = -1e30;
      double secondLogit = -1e30;
      int maxId = 0;

      for (int c = 0; c < vocabSize; c++) {
        final double v = logits[rowBase + c];
        if (v > maxLogit) {
          secondLogit = maxLogit;
          maxLogit = v;
          maxId = c;
        } else if (v > secondLogit) {
          secondLogit = v;
        }
      }

      double sumExp = 0.0;
      for (int c = 0; c < vocabSize; c++) {
        sumExp += math.exp(logits[rowBase + c] - maxLogit);
      }
      final double top1Prob = 1.0 / sumExp;
      final double top2Prob = math.exp(secondLogit - maxLogit) / sumExp;
      final double margin = top1Prob - top2Prob;

      if (_skipTokenIds.contains(maxId)) {
        if (activeId != null) {
          flushActive(t - 1);
        }
        prevId = maxId;
        continue;
      }

      if (maxId == prevId && activeId == maxId) {
        activeProbs.add(top1Prob);
        activeMargins.add(margin);
      } else {
        if (activeId != null) {
          flushActive(t - 1);
        }
        activeId = maxId;
        activeStartFrame = t;
        activeProbs.add(top1Prob);
        activeMargins.add(margin);
      }
      prevId = maxId;
    }

    if (activeId != null) {
      flushActive(tFrames - 1);
    }

    return tokens;
  }

  /// Maps an IPA phoneme symbol (including eSpeak IPA vowels/allophones) to Arabic script.
  String mapIpaToAr(String ipa) {
    final clean = ipa.replaceAll('ː', '').split('_').first;
    switch (clean) {
      case 'k':
      case 'kʰ':
      case 'c':
        return 'ك';
      case 't':
      case 'tʰ':
        return 'ت';
      case 'b':
      case 'p':
        return 'ب';
      case 's':
        return 'س';
      case 'ʃ':
      case 'ɕ':
        return 'ش';
      case 'r':
      case 'ɾ':
      case 'ɹ':
        return 'ر';
      case 'l':
      case 'ɫ':
        return 'ل';
      case 'm':
        return 'م';
      case 'n':
      case 'ŋ':
        return 'ن';
      case 'f':
      case 'v':
        return 'ف';
      case 'ħ':
        return 'ح';
      case 'x':
      case 'χ':
        return 'خ';
      case 'd':
        return 'د';
      case 'ɡ':
      case 'g':
      case 'dʒ':
        return 'ج';
      case 'z':
        return 'ز';
      case 'ʕ':
        return 'ع';
      case 'ɣ':
      case 'ʁ':
        return 'غ';
      case 'q':
        return 'ق';
      case 'tˤ':
        return 'ط';
      case 'sˤ':
        return 'ص';
      case 'dˤ':
        return 'ض';
      case 'ðˤ':
      case 'zˤ':
        return 'ظ';
      case 'ð':
        return 'ذ';
      case 'θ':
        return 'ث';
      case 'h':
        return 'هـ';
      case 'w':
      case 'u':
      case 'o':
      case 'ɔ':
      case 'ʊ':
      case 'ʉ':
        return 'و';
      case 'j':
      case 'i':
      case 'e':
      case 'ɪ':
      case 'ɛ':
      case 'y':
        return 'ي';
      case 'ʔ':
        return 'أ';
      case 'a':
      case 'ɑ':
      case 'æ':
      case 'ə':
      case 'ʌ':
      case 'ɐ':
      case 'aɪ':
        return 'ا';
      default:
        return ipa;
    }
  }

  /// Linguistic lexicon helper: maps Arabic letter to Egyptian Arabic IPA phoneme.
  /// (Not used during acoustic inference.)
  String mapArToIpa(String ar) {
    switch (ar) {
      case 'ك': return 'k';
      case 'ت': return 't';
      case 'ب': return 'b';
      case 'س': return 's';
      case 'ش': return 'ʃ';
      case 'ر': return 'r';
      case 'ل': return 'l';
      case 'م': return 'm';
      case 'ن': return 'n';
      case 'ف': return 'f';
      case 'ح': return 'ħ';
      case 'خ': return 'x';
      case 'د': return 'd';
      case 'ج': return 'ɡ';
      case 'ز': return 'z';
      case 'ع': return 'ʕ';
      case 'غ': return 'ɣ';
      case 'ق': return 'ʔ';
      case 'ط': return 'tˤ';
      case 'ص': return 'sˤ';
      case 'ض': return 'dˤ';
      case 'ظ': return 'ðˤ';
      case 'ذ': return 'd';
      case 'ث': return 's';
      case 'ه':
      case 'هـ': return 'h';
      case 'و': return 'uː';
      case 'ي': return 'iː';
      case 'ى': return 'aː';
      case 'ا':
      case 'آ':
      case 'أ':
      case 'إ':
      case 'ء':
      case 'ئ':
      case 'ؤ': return 'ʔ';
      case 'ة': return 'a';
      case 'َ': return 'a';
      case 'ُ': return 'u';
      case 'ِ': return 'i';
      default: return ar;
    }
  }

  /// Linguistic lexicon utility ONLY: converts reference dictionary text into expected phoneme symbols.
  List<PhonemeToken> textToPhonemes(
    String text, {
    double baseConfidence = 1.0,
    int totalDurationMs = 800,
  }) {
    if (text.isEmpty) return const [];
    final cleanText = text.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
    final chars = cleanText.split('');
    if (chars.isEmpty) return const [];
    final double segDuration = totalDurationMs / chars.length;

    final List<PhonemeToken> tokens = [];
    for (int idx = 0; idx < chars.length; idx++) {
      final char = chars[idx];
      final ipa = mapArToIpa(char);
      final startMs = (idx * segDuration).round();
      final endMs = ((idx + 1) * segDuration).round();
      tokens.add(PhonemeToken(
        symbol: ipa,
        arabicSymbol: char,
        tokenId: _tokenToId[ipa] ?? 0,
        confidence: double.parse(baseConfidence.toStringAsFixed(2)),
        acousticMargin: null,
        startFrame: (startMs / 20.0).round(),
        endFrame: (endMs / 20.0).round(),
        startMs: startMs,
        endMs: endMs,
        isAccurate: true,
        isTimestampEstimated: true,
      ));
    }
    return tokens;
  }

  void dispose() {
    _session?.dispose();
    _session = null;
    _idToToken.clear();
    _tokenToId.clear();
    _skipTokenIds.clear();
    _isInitialized = false;
    _isNativeAvailable = false;
  }
}
