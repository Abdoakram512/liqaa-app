import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'ai_asset_helper.dart';
import 'audio_preprocessor.dart';
import 'ort_dynamic_session.dart';

class SttResult {
  final String text;
  final double? confidence; // Null unless decoder exposes a calibrated acoustic posterior
  final int latencyMs;
  final double realTimeFactor;
  final bool isModelInference;
  final List<String> tokens;
  final List<double> timestamps;
  final String? errorMessage;

  const SttResult({
    required this.text,
    this.confidence,
    required this.latencyMs,
    required this.realTimeFactor,
    this.isModelInference = false,
    this.tokens = const [],
    this.timestamps = const [],
    this.errorMessage,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

class SpeechToTextEngine {
  final AudioPreprocessor _preprocessor;
  final String? encoderPathOverride;
  final String? decoderPathOverride;
  final String? tokensPathOverride;

  sherpa_onnx.OfflineRecognizer? _recognizer;
  bool _isInitialized = false;
  bool _isNativeAvailable = false;
  String? _encoderPath;
  String? _decoderPath;
  String? _tokensPath;
  String? _lastError;

  SpeechToTextEngine({
    AudioPreprocessor? preprocessor,
    this.encoderPathOverride,
    this.decoderPathOverride,
    this.tokensPathOverride,
  }) : _preprocessor = preprocessor ?? const AudioPreprocessor();

  bool get isInitialized => _isInitialized;
  bool get isNativeAvailable => _isNativeAvailable;
  String? get lastError => _lastError;

  /// Initializes Sherpa-ONNX Whisper Tiny multilingual speech recognizer (Arabic ASR).
  Future<void> initialize() async {
    if (_isInitialized && _isNativeAvailable) return;
    _lastError = null;

    try {
      OrtRuntimeLoader.ensureWindowsPreloaded();
      sherpa_onnx.initBindings();
    } catch (e) {
      _lastError = 'Sherpa-ONNX native binding failure: $e';
      debugPrint('[SpeechToTextEngine] $_lastError');
    }

    try {
      _encoderPath = encoderPathOverride ??
          await AiAssetHelper.getLocalAssetPath(
            'assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx',
          );
      _decoderPath = decoderPathOverride ??
          await AiAssetHelper.getLocalAssetPath(
            'assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx',
          );
      _tokensPath = tokensPathOverride ??
          await AiAssetHelper.getLocalAssetPath(
            'assets/ai_models/whisper_tiny/tiny-tokens.txt',
          );

      final hasEncoder = _encoderPath != null && File(_encoderPath!).existsSync();
      final hasDecoder = _decoderPath != null && File(_decoderPath!).existsSync();
      final hasTokens = _tokensPath != null && File(_tokensPath!).existsSync();

      if (!hasEncoder || !hasDecoder || !hasTokens) {
        _isNativeAvailable = false;
        _lastError = 'Whisper Tiny model files incomplete '
            '(enc=$hasEncoder, dec=$hasDecoder, tok=$hasTokens).';
        _isInitialized = true;
        return;
      }

      final whisperConfig = sherpa_onnx.OfflineWhisperModelConfig(
        encoder: _encoderPath!,
        decoder: _decoderPath!,
        language: 'ar',
        task: 'transcribe',
      );

      final modelConfig = sherpa_onnx.OfflineModelConfig(
        whisper: whisperConfig,
        tokens: _tokensPath!,
        modelType: 'whisper',
        numThreads: 2,
        provider: 'cpu',
        debug: false,
      );

      final recognizerConfig = sherpa_onnx.OfflineRecognizerConfig(
        model: modelConfig,
      );

      _recognizer?.free();
      _recognizer = sherpa_onnx.OfflineRecognizer(recognizerConfig);
      _isNativeAvailable = true;
      _lastError = null;
      debugPrint('[SpeechToTextEngine] Initialized native Whisper Tiny ASR (Arabic)');
    } catch (e) {
      _lastError = 'Whisper Tiny initialization error: $e';
      _isNativeAvailable = false;
      debugPrint('[SpeechToTextEngine] $_lastError');
    }

    _isInitialized = true;
  }

  /// Blindly transcribes 16kHz audio samples to Arabic text. Zero target hint parameter.
  Future<SttResult> transcribe(Float32List samples, {int sampleRate = 16000}) async {
    final Stopwatch sw = Stopwatch()..start();

    if (!_isInitialized) {
      await initialize();
    }

    if (samples.isEmpty) {
      sw.stop();
      return SttResult(
        text: '',
        confidence: null,
        latencyMs: sw.elapsedMilliseconds,
        realTimeFactor: 0.0,
      );
    }

    final double audioDurationMs = (samples.length / sampleRate) * 1000.0;
    final double rms = _preprocessor.calculateRms(samples);

    if (rms < 0.002) {
      sw.stop();
      return SttResult(
        text: '',
        confidence: null,
        latencyMs: sw.elapsedMilliseconds,
        realTimeFactor: 0.0,
        isModelInference: _isNativeAvailable,
      );
    }

    if (_recognizer == null || !_isNativeAvailable) {
      sw.stop();
      return SttResult(
        text: '',
        confidence: null,
        latencyMs: sw.elapsedMilliseconds,
        realTimeFactor: 0.0,
        isModelInference: false,
        errorMessage: _lastError ?? 'Whisper Tiny model is not available.',
      );
    }

    try {
      final stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      stream.free();

      sw.stop();
      final int latency = sw.elapsedMilliseconds;
      final double rtf = audioDurationMs > 0 ? (latency / audioDurationMs) : 0.0;

      final rawText = result.text.trim();
      final cleanedText = rawText.replaceAll(RegExp(r'[.,!?؟]'), '').trim();

      return SttResult(
        text: cleanedText,
        // Sherpa-ONNX Whisper OfflineRecognizerResult does not provide token posteriors; keep null honestly.
        confidence: null,
        latencyMs: latency,
        realTimeFactor: double.parse(rtf.toStringAsFixed(3)),
        isModelInference: true,
        tokens: result.tokens,
        timestamps: result.timestamps,
      );
    } catch (e) {
      sw.stop();
      _lastError = 'Whisper Tiny inference failed: $e';
      debugPrint('[SpeechToTextEngine] $_lastError');
      return SttResult(
        text: '',
        confidence: null,
        latencyMs: sw.elapsedMilliseconds,
        realTimeFactor: 0.0,
        isModelInference: false,
        errorMessage: _lastError,
      );
    }
  }

  void dispose() {
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
    _isNativeAvailable = false;
  }
}
