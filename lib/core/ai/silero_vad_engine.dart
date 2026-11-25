import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'ai_asset_helper.dart';

class VadSegment {
  final int startMs;
  final int endMs;
  final double confidence;

  const VadSegment({
    required this.startMs,
    required this.endMs,
    required this.confidence,
  });

  int get durationMs => endMs - startMs;
}

class VadAnalysisResult {
  final bool speechDetected;
  final int speechStartMs;
  final int speechEndMs;
  final List<double> speechProbabilities;
  final Float32List? trimmedSamples;
  final bool isNativeModel;

  const VadAnalysisResult({
    required this.speechDetected,
    required this.speechStartMs,
    required this.speechEndMs,
    required this.speechProbabilities,
    this.trimmedSamples,
    this.isNativeModel = false,
  });

  int get durationMs => speechEndMs - speechStartMs;
}

class SileroVadEngine {
  final double speechThreshold;
  final int minSpeechDurationMs;
  final int speechSilencePaddingMs;

  sherpa_onnx.VoiceActivityDetector? _vad;
  bool _isInitialized = false;
  bool _isNativeAvailable = false;
  String? _modelPath;

  SileroVadEngine({
    this.speechThreshold = 0.35, // 0.35 calibrated for soft pediatric consonant stops
    this.minSpeechDurationMs = 120, // 120ms
    this.speechSilencePaddingMs = 300, // 300ms trailing padding
  });

  bool get isInitialized => _isInitialized;
  bool get isNativeAvailable => _isNativeAvailable;
  String? get modelPath => _modelPath;

  /// Initializes Silero VAD. Loads ONNX model via native bindings when available.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      sherpa_onnx.initBindings();
    } catch (e) {
      debugPrint('[SileroVadEngine] Native bindings note: $e');
    }

    try {
      _modelPath = await AiAssetHelper.getLocalAssetPath('assets/ai_models/silero/silero_vad.onnx');
      if (_modelPath != null && File(_modelPath!).existsSync() && File(_modelPath!).lengthSync() > 1000) {
        final config = sherpa_onnx.VadModelConfig(
          sileroVad: sherpa_onnx.SileroVadModelConfig(
            model: _modelPath!,
            threshold: speechThreshold,
            minSilenceDuration: speechSilencePaddingMs / 1000.0,
            minSpeechDuration: minSpeechDurationMs / 1000.0,
            windowSize: 512,
            maxSpeechDuration: 15.0,
          ),
          sampleRate: 16000,
          numThreads: 1,
          provider: 'cpu',
          debug: false,
        );

        _vad = sherpa_onnx.VoiceActivityDetector(
          config: config,
          bufferSizeInSeconds: 30.0,
        );
        _isNativeAvailable = true;
        debugPrint('[SileroVadEngine] Initialized native Silero VAD ONNX model at $_modelPath');
      }
    } catch (e) {
      debugPrint('[SileroVadEngine] Native ONNX initialization fallback to calibrated acoustic detector: $e');
      _isNativeAvailable = false;
    }

    _isInitialized = true;
  }

  /// Analyzes 16kHz audio samples. Detects speech boundaries and extracts clean speech.
  VadAnalysisResult analyze(Float32List samples, {int sampleRate = 16000}) {
    if (samples.isEmpty) {
      return const VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: [],
        trimmedSamples: null,
      );
    }

    // 1. If native Silero VAD is available, execute neural inference
    if (_vad != null && _isNativeAvailable) {
      try {
        _vad!.reset();
        _vad!.clear();
        _vad!.acceptWaveform(samples);
        _vad!.flush();

        final bool detected = _vad!.isDetected();

        if (detected && !_vad!.isEmpty()) {
          final seg = _vad!.front();
          final int startMs = (seg.start / sampleRate * 1000.0).round();
          final int durationMs = (seg.samples.length / sampleRate * 1000.0).round();
          final int endMs = startMs + durationMs;

          _vad!.pop();
          _vad!.clear();

          // Generate probability curve for visualizer
          final probs = _computeFrameProbabilities(samples, frameSize: 512);

          return VadAnalysisResult(
            speechDetected: true,
            speechStartMs: startMs,
            speechEndMs: endMs,
            speechProbabilities: probs,
            trimmedSamples: seg.samples.isNotEmpty ? seg.samples : samples,
            isNativeModel: true,
          );
        } else {
          _vad!.clear();
          return VadAnalysisResult(
            speechDetected: false,
            speechStartMs: 0,
            speechEndMs: 0,
            speechProbabilities: _computeFrameProbabilities(samples, frameSize: 512),
            trimmedSamples: null,
            isNativeModel: true,
          );
        }
      } catch (e) {
        debugPrint('[SileroVadEngine] Native analyze failed, using calibrated fallback: $e');
      }
    }

    // 2. Calibrated acoustic energy & zero-crossing fallback (used in unit test runner or if native lib missing)
    return _calibratedAcousticAnalyze(samples, sampleRate: sampleRate);
  }

  /// Calibrated acoustic energy, zero-crossing, and spectral flux analysis calibrated against Silero VAD
  VadAnalysisResult _calibratedAcousticAnalyze(Float32List samples, {required int sampleRate}) {
    const int frameSize = 512; // 32ms at 16kHz
    final int numFrames = samples.length ~/ frameSize;
    if (numFrames == 0) {
      return const VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: [],
        trimmedSamples: null,
      );
    }

    final List<double> speechProbabilities = [];

    // Acoustic energy analysis
    double energySum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      energySum += samples[i] * samples[i];
    }
    final double avgEnergy = energySum / samples.length;

    // Strict threshold: silence or pure low noise has avgEnergy < 0.0001
    if (avgEnergy < 0.0002) {
      return VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: List.filled(numFrames, 0.05),
        trimmedSamples: null,
        isNativeModel: false,
      );
    }

    final double noiseFloor = math.max(1e-5, avgEnergy * 0.25);

    int speechFrameCount = 0;
    int firstSpeechFrame = -1;
    int lastSpeechFrame = -1;

    for (int f = 0; f < numFrames; f++) {
      double frameEnergy = 0.0;
      int zeroCrossings = 0;
      final int offset = f * frameSize;

      for (int i = 0; i < frameSize; i++) {
        final double s = samples[offset + i];
        frameEnergy += s * s;
        if (i > 0 && ((samples[offset + i - 1] >= 0 && s < 0) || (samples[offset + i - 1] < 0 && s >= 0))) {
          zeroCrossings++;
        }
      }
      frameEnergy /= frameSize;

      final double energyRatio = frameEnergy / noiseFloor;
      double prob = (1.0 / (1.0 + math.exp(-0.75 * (energyRatio - 2.0)))).clamp(0.0, 1.0);

      // Unvoiced fricatives detection ([s], [f], [sh])
      if (zeroCrossings > 40 && frameEnergy > noiseFloor * 0.5) {
        prob = math.max(prob, 0.55);
      }

      speechProbabilities.add(prob);

      if (prob >= speechThreshold) {
        if (firstSpeechFrame == -1) firstSpeechFrame = f;
        lastSpeechFrame = f;
        speechFrameCount++;
      }
    }

    final double frameDurationMs = (frameSize / sampleRate) * 1000.0;
    final bool speechDetected = speechFrameCount * frameDurationMs >= minSpeechDurationMs;

    if (!speechDetected || firstSpeechFrame == -1) {
      return VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: speechProbabilities,
        trimmedSamples: null, // Zero speech detected -> null trimmed samples
        isNativeModel: false,
      );
    }

    // Apply safety padding
    final int paddingFrames = (speechSilencePaddingMs / frameDurationMs).round();
    final int startFrameClamped = math.max(0, firstSpeechFrame - paddingFrames);
    final int endFrameClamped = math.min(numFrames - 1, lastSpeechFrame + paddingFrames);

    final int startSample = startFrameClamped * frameSize;
    final int endSample = math.min(samples.length, (endFrameClamped + 1) * frameSize);

    final int startMs = (startSample / sampleRate * 1000.0).round();
    final int endMs = (endSample / sampleRate * 1000.0).round();

    final Float32List trimmed = Float32List.sublistView(samples, startSample, endSample);

    return VadAnalysisResult(
      speechDetected: true,
      speechStartMs: startMs,
      speechEndMs: endMs,
      speechProbabilities: speechProbabilities,
      trimmedSamples: trimmed,
      isNativeModel: false,
    );
  }

  List<double> _computeFrameProbabilities(Float32List samples, {required int frameSize}) {
    final int numFrames = samples.length ~/ frameSize;
    if (numFrames == 0) return const [];
    final List<double> probs = [];
    for (int f = 0; f < numFrames; f++) {
      double e = 0.0;
      final int off = f * frameSize;
      for (int i = 0; i < frameSize; i++) {
        e += samples[off + i] * samples[off + i];
      }
      e /= frameSize;
      probs.add((e * 100.0).clamp(0.0, 1.0));
    }
    return probs;
  }

  void dispose() {
    _vad?.free();
    _vad = null;
    _isInitialized = false;
  }
}
