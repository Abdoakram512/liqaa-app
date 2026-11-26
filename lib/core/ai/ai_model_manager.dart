import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'ai_asset_helper.dart';
import 'models/ai_model_info.dart';
import 'phoneme_recognition_engine.dart';
import 'rnnoise_denoiser_engine.dart';
import 'silero_vad_engine.dart';
import 'speech_to_text_engine.dart';

/// Manages verification, native ONNX runtime loading, RAM tracking, and honest smoke tests
/// for every real model bundled in LIQAA.
class AiModelManager {
  final Map<String, AiModelInfo> _models = {};
  bool _isInitialized = false;

  SileroVadEngine? _activeVad;
  RnnoiseDenoiserEngine? _activeDenoiser;
  PhonemeRecognitionEngine? _activePhoneme;
  SpeechToTextEngine? _activeStt;

  bool get isInitialized => _isInitialized;
  List<AiModelInfo> get models => _models.values.toList();

  double _getProcessRssMb() {
    try {
      return ProcessInfo.currentRss / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Silero VAD v4
    String sileroPath = 'assets/ai_models/silero/silero_vad.onnx';
    bool sileroExists = false;
    double sileroSizeMb = 0.0;
    String? sileroErr;
    try {
      sileroPath = await AiAssetHelper.getLocalAssetPath(sileroPath);
      sileroExists = AiAssetHelper.fileExists(sileroPath);
      if (sileroExists) {
        sileroSizeMb = File(sileroPath).lengthSync() / (1024 * 1024);
      }
    } catch (e) {
      sileroErr = e.toString();
    }

    _models['silero_vad'] = AiModelInfo(
      key: 'silero_vad',
      name: 'Silero VAD v4 (ONNX)',
      description:
          'Neural Voice Activity Detection (16kHz, 512-sample windows)',
      format: 'ONNX',
      sampleRate: 16000,
      sizeMb: double.parse(sileroSizeMb.toStringAsFixed(2)),
      license: 'MIT',
      status: sileroExists ? 'ready' : 'missing',
      isLoadedInMemory: false,
      ramUsageMb: 0.0,
      diskPath: sileroPath,
      error: sileroErr,
    );

    // 2. GTCRN Neural Speech Enhancement
    String gtcrnPath = 'assets/ai_models/gtcrn/gtcrn_simple.onnx';
    bool gtcrnExists = false;
    double gtcrnSizeMb = 0.0;
    String? gtcrnErr;
    try {
      gtcrnPath = await AiAssetHelper.getLocalAssetPath(gtcrnPath);
      gtcrnExists = AiAssetHelper.fileExists(gtcrnPath);
      if (gtcrnExists) {
        gtcrnSizeMb = File(gtcrnPath).lengthSync() / (1024 * 1024);
      }
    } catch (e) {
      gtcrnErr = e.toString();
    }

    _models['gtcrn_denoiser'] = AiModelInfo(
      key: 'gtcrn_denoiser',
      name: 'GTCRN Neural Denoiser (ONNX)',
      description:
          '16kHz Neural Speech Enhancement (replaces incompatible 48kHz BFCC rnnoise.onnx)',
      format: 'ONNX',
      sampleRate: 16000,
      sizeMb: double.parse(gtcrnSizeMb.toStringAsFixed(2)),
      license: 'MIT',
      status: gtcrnExists ? 'ready' : 'missing',
      isLoadedInMemory: false,
      ramUsageMb: 0.0,
      diskPath: gtcrnPath,
      error: gtcrnErr,
    );

    // 3. Wav2Vec2-LV60-eSpeak-CV-FT Acoustic IPA Phoneme Model
    String w2vPath = PhonemeRecognitionEngine.defaultModelAsset;
    String w2vVocab = PhonemeRecognitionEngine.defaultVocabAsset;
    bool w2vExists = false;
    double w2vSizeMb = 0.0;
    String? w2vErr;
    try {
      w2vPath = await AiAssetHelper.getLocalAssetPath(w2vPath);
      w2vVocab = await AiAssetHelper.getLocalAssetPath(w2vVocab);
      w2vExists =
          AiAssetHelper.fileExists(w2vPath) &&
          AiAssetHelper.fileExists(w2vVocab);
      if (AiAssetHelper.fileExists(w2vPath)) {
        w2vSizeMb = File(w2vPath).lengthSync() / (1024 * 1024);
      }
    } catch (e) {
      w2vErr = e.toString();
    }

    _models['wav2vec2_espeak'] = AiModelInfo(
      key: 'wav2vec2_espeak',
      name: 'Wav2Vec2-LV60 eSpeak IPA (Q4F16)',
      description:
          'Blind Acoustic CTC Phoneme Recognizer (392 IPA units, Arabic gutturals/emphatics)',
      format: 'ONNX Q4F16',
      sampleRate: 16000,
      sizeMb: double.parse(w2vSizeMb.toStringAsFixed(1)),
      license: 'Apache-2.0',
      status: w2vExists ? 'ready' : 'missing',
      isLoadedInMemory: false,
      ramUsageMb: 0.0,
      diskPath: w2vPath,
      error: w2vErr,
    );

    // 4. Whisper Tiny Multilingual ASR (Optional word-level reference)
    String whisperEnc = 'assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx';
    String whisperDec = 'assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx';
    String whisperTok = 'assets/ai_models/whisper_tiny/tiny-tokens.txt';
    bool whisperReady = false;
    double whisperSizeMb = 0.0;
    String? whisperErr;
    try {
      whisperEnc = await AiAssetHelper.getLocalAssetPath(whisperEnc);
      whisperDec = await AiAssetHelper.getLocalAssetPath(whisperDec);
      whisperTok = await AiAssetHelper.getLocalAssetPath(whisperTok);
      whisperReady =
          AiAssetHelper.fileExists(whisperEnc) &&
          AiAssetHelper.fileExists(whisperDec) &&
          AiAssetHelper.fileExists(whisperTok);
      if (whisperReady) {
        final totalBytes =
            File(whisperEnc).lengthSync() +
            File(whisperDec).lengthSync() +
            File(whisperTok).lengthSync();
        whisperSizeMb = totalBytes / (1024 * 1024);
      }
    } catch (e) {
      whisperErr = e.toString();
    }

    _models['whisper_tiny'] = AiModelInfo(
      key: 'whisper_tiny',
      name: 'Whisper Tiny Arabic ASR (INT8)',
      description:
          'Word-level Arabic ASR (diagnostic telemetry only; not phoneme scoring)',
      format: 'ONNX INT8',
      sampleRate: 16000,
      sizeMb: double.parse(whisperSizeMb.toStringAsFixed(1)),
      license: 'MIT',
      status: whisperReady ? 'ready' : 'missing',
      isLoadedInMemory: false,
      ramUsageMb: 0.0,
      diskPath: whisperEnc,
      error: whisperErr,
    );

    _isInitialized = true;
    debugPrint(
      '[AiModelManager] Initialized with ${_models.length} verified ONNX entries',
    );
  }

  /// Reflects live initialization state from shared repository engines without double-loading.
  void syncEngineStatus({
    SileroVadEngine? vad,
    RnnoiseDenoiserEngine? denoiser,
    PhonemeRecognitionEngine? phoneme,
    SpeechToTextEngine? stt,
  }) {
    if (vad != null && _models.containsKey('silero_vad')) {
      _activeVad = vad;
      _models['silero_vad'] = _models['silero_vad']!.copyWith(
        status: vad.isNativeAvailable
            ? 'ready'
            : (vad.lastError != null ? 'error' : 'missing'),
        isLoadedInMemory: vad.isNativeAvailable,
        error: vad.lastError,
      );
    }
    if (denoiser != null && _models.containsKey('gtcrn_denoiser')) {
      _activeDenoiser = denoiser;
      _models['gtcrn_denoiser'] = _models['gtcrn_denoiser']!.copyWith(
        status: denoiser.isNativeAvailable
            ? 'ready'
            : (denoiser.lastError != null ? 'error' : 'missing'),
        isLoadedInMemory: denoiser.isNativeAvailable,
        error: denoiser.lastError,
      );
    }
    if (phoneme != null && _models.containsKey('wav2vec2_espeak')) {
      _activePhoneme = phoneme;
      _models['wav2vec2_espeak'] = _models['wav2vec2_espeak']!.copyWith(
        status: phoneme.isNativeAvailable
            ? 'ready'
            : (phoneme.lastError != null ? 'error' : 'missing'),
        isLoadedInMemory: phoneme.isNativeAvailable,
        error: phoneme.lastError,
      );
    }
    if (stt != null && _models.containsKey('whisper_tiny')) {
      _activeStt = stt;
      _models['whisper_tiny'] = _models['whisper_tiny']!.copyWith(
        status: stt.isNativeAvailable
            ? 'ready'
            : (stt.lastError != null ? 'error' : 'missing'),
        isLoadedInMemory: stt.isNativeAvailable,
        error: stt.lastError,
      );
    }
  }

  /// Instantiates the ONNX session cleanly and verifies native availability before marking loaded.
  Future<void> loadModelIntoMemory(String key) async {
    final resolvedKey = key == 'rnnoise' ? 'gtcrn_denoiser' : key;
    final model = _models[resolvedKey];
    if (model == null) return;

    final double rssBefore = _getProcessRssMb();
    bool loaded = false;
    String? err;

    try {
      if (resolvedKey == 'silero_vad') {
        _activeVad ??= SileroVadEngine();
        await _activeVad!.initialize();
        loaded = _activeVad!.isNativeAvailable;
        err = _activeVad!.lastError;
      } else if (resolvedKey == 'gtcrn_denoiser') {
        _activeDenoiser ??= RnnoiseDenoiserEngine();
        await _activeDenoiser!.initialize();
        loaded = _activeDenoiser!.isNativeAvailable;
        err = _activeDenoiser!.lastError;
      } else if (resolvedKey == 'wav2vec2_espeak') {
        _activePhoneme ??= PhonemeRecognitionEngine();
        await _activePhoneme!.initialize();
        loaded = _activePhoneme!.isNativeAvailable;
        err = _activePhoneme!.lastError;
      } else if (resolvedKey == 'whisper_tiny') {
        _activeStt ??= SpeechToTextEngine();
        await _activeStt!.initialize();
        loaded = _activeStt!.isNativeAvailable;
        err = _activeStt!.lastError;
      }
    } catch (e) {
      loaded = false;
      err = e.toString();
      debugPrint('[AiModelManager] Error loading $resolvedKey: $e');
    }

    final double rssAfter = _getProcessRssMb();
    final double rssDelta = math.max(0.0, rssAfter - rssBefore);

    _models[resolvedKey] = model.copyWith(
      status: loaded ? 'ready' : 'error',
      isLoadedInMemory: loaded,
      ramUsageMb: loaded ? double.parse(rssDelta.toStringAsFixed(1)) : 0.0,
      error: err,
    );
  }

  Future<void> unloadModelFromMemory(String key) async {
    final resolvedKey = key == 'rnnoise' ? 'gtcrn_denoiser' : key;
    final model = _models[resolvedKey];
    if (model == null) return;

    if (resolvedKey == 'silero_vad') {
      _activeVad?.dispose();
      _activeVad = null;
    } else if (resolvedKey == 'gtcrn_denoiser') {
      _activeDenoiser?.dispose();
      _activeDenoiser = null;
    } else if (resolvedKey == 'wav2vec2_espeak') {
      _activePhoneme?.dispose();
      _activePhoneme = null;
    } else if (resolvedKey == 'whisper_tiny') {
      _activeStt?.dispose();
      _activeStt = null;
    }

    _models[resolvedKey] = model.copyWith(
      isLoadedInMemory: false,
      ramUsageMb: 0.0,
    );
  }

  double getTotalRamUsageMb() {
    double total = 0.0;
    for (final m in _models.values) {
      if (m.isLoadedInMemory) {
        total += m.ramUsageMb;
      }
    }
    return double.parse(total.toStringAsFixed(1));
  }

  /// Runs real ONNX inference smoke tests verifying model init, valid tensor outputs, and rejection of silence.
  Future<bool> runSmokeTest(String key) async {
    final resolvedKey = key == 'rnnoise' ? 'gtcrn_denoiser' : key;
    try {
      if (resolvedKey == 'silero_vad') {
        final vad = SileroVadEngine();
        await vad.initialize();
        if (!vad.isNativeAvailable) {
          vad.dispose();
          return false;
        }
        // Pure silence MUST be rejected
        final silenceRes = vad.analyze(Float32List(8000));
        vad.dispose();
        return silenceRes.isNativeModel && !silenceRes.speechDetected;
      }

      if (resolvedKey == 'gtcrn_denoiser') {
        final denoiser = RnnoiseDenoiserEngine();
        await denoiser.initialize();
        if (!denoiser.isNativeAvailable) {
          denoiser.dispose();
          return false;
        }
        const int n = 8000;
        final signal = Float32List(n);
        for (int i = 0; i < n; i++) {
          signal[i] =
              0.25 * math.sin(2 * math.pi * 400 * (i / 16000.0)) +
              0.08 * math.sin(2 * math.pi * 3500 * (i / 16000.0));
        }
        final res = denoiser.process(signal);
        denoiser.dispose();
        return res.hasValidAudio && res.isNeuralModel && res.rmsAfter > 0.0;
      }

      if (resolvedKey == 'wav2vec2_espeak') {
        final phone = PhonemeRecognitionEngine();
        await phone.initialize();
        if (!phone.isNativeAvailable) {
          phone.dispose();
          return false;
        }
        final silenceRes = await phone.recognizePhonemesDetailed(
          Float32List(8000),
        );
        phone.dispose();
        return silenceRes.isNativeModel &&
            !silenceRes.hasError &&
            silenceRes.tokens.isEmpty;
      }

      if (resolvedKey == 'whisper_tiny') {
        final stt = SpeechToTextEngine();
        await stt.initialize();
        if (!stt.isNativeAvailable) {
          stt.dispose();
          return false;
        }
        final res = await stt.transcribe(Float32List(8000));
        stt.dispose();
        return res.isModelInference && !res.hasError;
      }

      return false;
    } catch (e) {
      debugPrint('[AiModelManager] Smoke test failed for $resolvedKey: $e');
      return false;
    }
  }

  void dispose() {
    _activeVad?.dispose();
    _activeDenoiser?.dispose();
    _activePhoneme?.dispose();
    _activeStt?.dispose();
    _activeVad = null;
    _activeDenoiser = null;
    _activePhoneme = null;
    _activeStt = null;
    _isInitialized = false;
  }
}
