import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'ai_asset_helper.dart';
import 'audio_preprocessor.dart';
import 'ort_dynamic_session.dart';

enum DenoiserMode { neuralGtcrn, dspWienerFallback, bypass }

class DenoiseResult {
  final Float32List processedSamples;
  final int sampleRate;
  final double rmsBefore;
  final double rmsAfter;
  final double peakBefore;
  final double peakAfter;
  final double snrBeforeDb;
  final double snrAfterDb;
  final double snrImprovementDb;
  final bool wasSuppressionApplied;
  final bool isNeuralModel;
  final String filterType;
  final String? errorMessage;

  const DenoiseResult({
    required this.processedSamples,
    this.sampleRate = 16000,
    this.rmsBefore = 0.0,
    this.rmsAfter = 0.0,
    this.peakBefore = 0.0,
    this.peakAfter = 0.0,
    required this.snrBeforeDb,
    required this.snrAfterDb,
    required this.snrImprovementDb,
    required this.wasSuppressionApplied,
    this.isNeuralModel = false,
    this.filterType = 'gtcrn_neural',
    this.errorMessage,
  });

  bool get hasValidAudio => errorMessage == null && processedSamples.isNotEmpty;
}

/// Neural Speech Enhancement & Noise Suppression Engine.
///
/// Primary engine: GTCRN Simple ONNX (`gtcrn_simple.onnx`, 16kHz native, MIT license) executed via
/// `sherpa_onnx.OfflineSpeechDenoiser`.
/// Note: Legacy `rnnoise.onnx` in assets expects 48kHz `[batch, 100, 42]` BFCC features and cannot
/// directly consume 16kHz waveforms; therefore GTCRN 16kHz neural enhancement is the active neural denoiser.
class RnnoiseDenoiserEngine {
  final AudioPreprocessor _preprocessor;
  final String? modelPathOverride;

  bool enabled = true;
  DenoiserMode mode = DenoiserMode.neuralGtcrn;

  sherpa_onnx.OfflineSpeechDenoiser? _gtcrn;
  bool _isInitialized = false;
  bool _isNativeAvailable = false;
  String? _modelPath;
  String? _lastError;

  RnnoiseDenoiserEngine({
    AudioPreprocessor? preprocessor,
    bool initialEnabled = true,
    this.modelPathOverride,
  }) : _preprocessor = preprocessor ?? const AudioPreprocessor(),
       enabled = initialEnabled;

  bool get isInitialized => _isInitialized;
  bool get isNativeAvailable => _isNativeAvailable;
  String? get modelPath => _modelPath;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_isInitialized && _isNativeAvailable) return;
    _lastError = null;

    try {
      OrtRuntimeLoader.ensureWindowsPreloaded();
      sherpa_onnx.initBindings();
    } catch (e) {
      _lastError = 'Sherpa-ONNX binding error for GTCRN denoiser: $e';
      debugPrint('[RnnoiseDenoiserEngine] $_lastError');
    }

    try {
      _modelPath =
          modelPathOverride ??
          await AiAssetHelper.getLocalAssetPath(
            'assets/ai_models/gtcrn/gtcrn_simple.onnx',
          );

      if (_modelPath == null || !File(_modelPath!).existsSync()) {
        _isNativeAvailable = false;
        _lastError = 'GTCRN model file missing at $_modelPath';
        _isInitialized = true;
        return;
      }

      final int fileSize = File(_modelPath!).lengthSync();
      if (fileSize < 100000) {
        _isNativeAvailable = false;
        _lastError = 'GTCRN model truncated/invalid ($fileSize bytes)';
        _isInitialized = true;
        return;
      }

      final config = sherpa_onnx.OfflineSpeechDenoiserConfig(
        model: sherpa_onnx.OfflineSpeechDenoiserModelConfig(
          gtcrn: sherpa_onnx.OfflineSpeechDenoiserGtcrnModelConfig(
            model: _modelPath!,
          ),
          numThreads: 1,
          debug: false,
          provider: 'cpu',
        ),
      );

      _gtcrn?.free();
      _gtcrn = sherpa_onnx.OfflineSpeechDenoiser(config);
      _isNativeAvailable = true;
      _lastError = null;
      debugPrint(
        '[RnnoiseDenoiserEngine] Initialized real GTCRN ONNX denoiser at $_modelPath ($fileSize bytes)',
      );
    } catch (e) {
      _isNativeAvailable = false;
      _lastError = 'GTCRN ONNX initialization failed: $e';
      debugPrint('[RnnoiseDenoiserEngine] $_lastError');
    }

    _isInitialized = true;
  }

  /// Processes 16kHz mono float32 audio.
  /// Never silently returns unmodified input on failure when neural denoising fails.
  DenoiseResult process(Float32List inputSamples, {int sampleRate = 16000}) {
    if (inputSamples.isEmpty) {
      return DenoiseResult(
        processedSamples: Float32List(0),
        snrBeforeDb: 0.0,
        snrAfterDb: 0.0,
        snrImprovementDb: 0.0,
        wasSuppressionApplied: false,
        isNeuralModel: false,
        filterType: 'none',
        errorMessage: 'Empty audio input to denoiser.',
      );
    }

    final double rmsBefore = _preprocessor.calculateRms(inputSamples);
    final double peakBefore = _preprocessor.calculatePeak(inputSamples);
    final double snrBefore = _preprocessor.estimateSnrDb(inputSamples);

    if (!enabled || mode == DenoiserMode.bypass) {
      return DenoiseResult(
        processedSamples: Float32List.fromList(inputSamples),
        sampleRate: sampleRate,
        rmsBefore: rmsBefore,
        rmsAfter: rmsBefore,
        peakBefore: peakBefore,
        peakAfter: peakBefore,
        snrBeforeDb: snrBefore,
        snrAfterDb: snrBefore,
        snrImprovementDb: 0.0,
        wasSuppressionApplied: false,
        isNeuralModel: false,
        filterType: 'bypass',
      );
    }

    if (mode == DenoiserMode.neuralGtcrn) {
      if (_gtcrn == null || !_isNativeAvailable) {
        final String err =
            _lastError ?? 'GTCRN neural denoiser is not initialized.';
        return DenoiseResult(
          processedSamples: Float32List(0),
          sampleRate: sampleRate,
          rmsBefore: rmsBefore,
          rmsAfter: 0.0,
          peakBefore: peakBefore,
          peakAfter: 0.0,
          snrBeforeDb: snrBefore,
          snrAfterDb: 0.0,
          snrImprovementDb: 0.0,
          wasSuppressionApplied: false,
          isNeuralModel: false,
          filterType: 'gtcrn_error',
          errorMessage: err,
        );
      }

      try {
        final denoised = _gtcrn!.run(
          samples: inputSamples,
          sampleRate: sampleRate,
        );
        Float32List outSamples = denoised.samples;
        if (denoised.sampleRate != sampleRate && denoised.sampleRate > 0) {
          outSamples = _preprocessor.resampleLinear(
            outSamples,
            denoised.sampleRate,
            sampleRate,
          );
        }

        if (outSamples.isEmpty) {
          return DenoiseResult(
            processedSamples: Float32List(0),
            sampleRate: sampleRate,
            rmsBefore: rmsBefore,
            rmsAfter: 0.0,
            peakBefore: peakBefore,
            peakAfter: 0.0,
            snrBeforeDb: snrBefore,
            snrAfterDb: 0.0,
            snrImprovementDb: 0.0,
            wasSuppressionApplied: false,
            isNeuralModel: true,
            filterType: 'gtcrn_error',
            errorMessage: 'GTCRN denoiser returned zero output samples.',
          );
        }

        // Verify finite non-corrupt float output
        for (int i = 0; i < outSamples.length; i++) {
          if (!outSamples[i].isFinite) {
            return DenoiseResult(
              processedSamples: Float32List(0),
              sampleRate: sampleRate,
              rmsBefore: rmsBefore,
              rmsAfter: 0.0,
              peakBefore: peakBefore,
              peakAfter: 0.0,
              snrBeforeDb: snrBefore,
              snrAfterDb: 0.0,
              snrImprovementDb: 0.0,
              wasSuppressionApplied: false,
              isNeuralModel: true,
              filterType: 'gtcrn_error',
              errorMessage:
                  'GTCRN output contained non-finite float values (NaN/Inf).',
            );
          }
        }

        final double rmsAfter = _preprocessor.calculateRms(outSamples);
        final double peakAfter = _preprocessor.calculatePeak(outSamples);

        // Guard against silent model collapse on voiced input
        if (rmsBefore > 0.02 && peakAfter < 1e-5) {
          return DenoiseResult(
            processedSamples: Float32List(0),
            sampleRate: sampleRate,
            rmsBefore: rmsBefore,
            rmsAfter: rmsAfter,
            peakBefore: peakBefore,
            peakAfter: peakAfter,
            snrBeforeDb: snrBefore,
            snrAfterDb: 0.0,
            snrImprovementDb: 0.0,
            wasSuppressionApplied: false,
            isNeuralModel: true,
            filterType: 'gtcrn_error',
            errorMessage:
                'GTCRN denoiser collapsed audible input ($rmsBefore) to near-zero output ($peakAfter).',
          );
        }

        final double snrAfter = _preprocessor.estimateSnrDb(outSamples);
        final double snrImprovement = snrAfter - snrBefore;

        return DenoiseResult(
          processedSamples: outSamples,
          sampleRate: sampleRate,
          rmsBefore: rmsBefore,
          rmsAfter: rmsAfter,
          peakBefore: peakBefore,
          peakAfter: peakAfter,
          snrBeforeDb: snrBefore,
          snrAfterDb: snrAfter,
          snrImprovementDb: snrImprovement,
          wasSuppressionApplied: true,
          isNeuralModel: true,
          filterType: 'gtcrn_neural',
        );
      } catch (e) {
        _lastError = 'GTCRN inference exception: $e';
        return DenoiseResult(
          processedSamples: Float32List(0),
          sampleRate: sampleRate,
          rmsBefore: rmsBefore,
          rmsAfter: 0.0,
          peakBefore: peakBefore,
          peakAfter: 0.0,
          snrBeforeDb: snrBefore,
          snrAfterDb: 0.0,
          snrImprovementDb: 0.0,
          wasSuppressionApplied: false,
          isNeuralModel: false,
          filterType: 'gtcrn_error',
          errorMessage: _lastError,
        );
      }
    }

    // Explicit DSP Wiener mode (only when user/lab explicitly selects DenoiserMode.dspWienerFallback)
    return _dspWienerProcess(
      inputSamples,
      sampleRate,
      rmsBefore,
      peakBefore,
      snrBefore,
    );
  }

  DenoiseResult _dspWienerProcess(
    Float32List inputSamples,
    int sampleRate,
    double rmsBefore,
    double peakBefore,
    double snrBefore,
  ) {
    const int frameSize = 160;
    final int numFrames = inputSamples.length ~/ frameSize;
    final Float32List outputSamples = Float32List(inputSamples.length);
    double runningNoiseEnergy = 0.0005;

    for (int f = 0; f < numFrames; f++) {
      final int offset = f * frameSize;
      double frameEnergy = 0.0;
      for (int i = 0; i < frameSize; i++) {
        final double s = inputSamples[offset + i];
        frameEnergy += s * s;
      }
      frameEnergy /= frameSize;

      if (f < 5 || frameEnergy < runningNoiseEnergy * 1.5) {
        runningNoiseEnergy =
            0.9 * runningNoiseEnergy + 0.1 * math.max(1e-6, frameEnergy);
      }

      final double snrLinear = frameEnergy / math.max(1e-6, runningNoiseEnergy);
      final double gain = snrLinear < 3.0
          ? (snrLinear / 3.0).clamp(0.15, 1.0)
          : 1.0;

      for (int i = 0; i < frameSize; i++) {
        outputSamples[offset + i] = (inputSamples[offset + i] * gain).clamp(
          -1.0,
          1.0,
        );
      }
    }

    final int processedTail = numFrames * frameSize;
    for (int i = processedTail; i < inputSamples.length; i++) {
      outputSamples[i] = inputSamples[i];
    }

    final double rmsAfter = _preprocessor.calculateRms(outputSamples);
    final double peakAfter = _preprocessor.calculatePeak(outputSamples);
    final double snrAfter = _preprocessor.estimateSnrDb(outputSamples);

    return DenoiseResult(
      processedSamples: outputSamples,
      sampleRate: sampleRate,
      rmsBefore: rmsBefore,
      rmsAfter: rmsAfter,
      peakBefore: peakBefore,
      peakAfter: peakAfter,
      snrBeforeDb: snrBefore,
      snrAfterDb: snrAfter,
      snrImprovementDb: snrAfter - snrBefore,
      wasSuppressionApplied: true,
      isNeuralModel: false,
      filterType: 'dsp_wiener_fallback',
    );
  }

  void dispose() {
    _gtcrn?.free();
    _gtcrn = null;
    _isInitialized = false;
    _isNativeAvailable = false;
  }
}
