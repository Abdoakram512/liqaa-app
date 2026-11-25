import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'ai_asset_helper.dart';
import 'ort_dynamic_session.dart';

class VadSegment {
  final int startMs;
  final int endMs;
  final int startSample;
  final int sampleCount;
  final double confidence;
  final double rms;

  const VadSegment({
    required this.startMs,
    required this.endMs,
    this.startSample = 0,
    this.sampleCount = 0,
    required this.confidence,
    this.rms = 0.0,
  });

  int get durationMs => endMs - startMs;
}

class VadAnalysisResult {
  final bool speechDetected;
  final int speechStartMs;
  final int speechEndMs;
  final List<double> speechProbabilities;
  final List<double> energyEnvelope;
  final Float32List? trimmedSamples;
  final List<VadSegment> segments;
  final bool isNativeModel;
  final String? errorMessage;

  const VadAnalysisResult({
    required this.speechDetected,
    required this.speechStartMs,
    required this.speechEndMs,
    required this.speechProbabilities,
    this.energyEnvelope = const [],
    this.trimmedSamples,
    this.segments = const [],
    this.isNativeModel = false,
    this.errorMessage,
  });

  int get durationMs => speechEndMs - speechStartMs;
}

class SileroVadEngine {
  static const int vadWindowSize = 512;

  final double speechThreshold;
  final int minSpeechDurationMs;
  final int speechSilencePaddingMs;
  final int preRollMs;
  final int postRollMs;
  final String? modelPathOverride;

  sherpa_onnx.VoiceActivityDetector? _vad;
  bool _isInitialized = false;
  bool _isNativeAvailable = false;
  String? _modelPath;
  String? _lastError;

  SileroVadEngine({
    this.speechThreshold = 0.35, // Tuned for child speech onset & soft consonants
    this.minSpeechDurationMs = 80, // Preserve monosyllabic Arabic words & isolated phonemes
    this.speechSilencePaddingMs = 200,
    this.preRollMs = 150,
    this.postRollMs = 200,
    this.modelPathOverride,
  });

  bool get isInitialized => _isInitialized;
  bool get isNativeAvailable => _isNativeAvailable;
  String? get modelPath => _modelPath;
  String? get lastError => _lastError;

  /// Initializes Silero VAD ONNX model via Sherpa-ONNX native bindings.
  Future<void> initialize() async {
    if (_isInitialized && _isNativeAvailable) return;
    _lastError = null;

    try {
      OrtRuntimeLoader.ensureWindowsPreloaded();
      sherpa_onnx.initBindings();
    } catch (e) {
      _lastError = 'Sherpa-ONNX native binding failure: $e';
      debugPrint('[SileroVadEngine] $_lastError');
    }

    try {
      _modelPath = modelPathOverride ??
          await AiAssetHelper.getLocalAssetPath('assets/ai_models/silero/silero_vad.onnx');

      if (_modelPath == null || !File(_modelPath!).existsSync()) {
        _isNativeAvailable = false;
        _lastError = 'Silero VAD model file missing at $_modelPath';
        _isInitialized = true;
        return;
      }

      final int fileSize = File(_modelPath!).lengthSync();
      if (fileSize < 100000) {
        _isNativeAvailable = false;
        _lastError = 'Silero VAD model invalid/truncated ($fileSize bytes)';
        _isInitialized = true;
        return;
      }

      final config = sherpa_onnx.VadModelConfig(
        sileroVad: sherpa_onnx.SileroVadModelConfig(
          model: _modelPath!,
          threshold: speechThreshold,
          minSilenceDuration: speechSilencePaddingMs / 1000.0,
          minSpeechDuration: minSpeechDurationMs / 1000.0,
          windowSize: vadWindowSize,
          maxSpeechDuration: 15.0,
        ),
        sampleRate: 16000,
        numThreads: 1,
        provider: 'cpu',
        debug: false,
      );

      _vad?.free();
      _vad = sherpa_onnx.VoiceActivityDetector(
        config: config,
        bufferSizeInSeconds: 30.0,
      );
      _isNativeAvailable = true;
      _lastError = null;
      debugPrint('[SileroVadEngine] Initialized real Silero VAD ONNX at $_modelPath ($fileSize bytes)');
    } catch (e) {
      _isNativeAvailable = false;
      _lastError = 'Silero VAD ONNX initialization error: $e';
      debugPrint('[SileroVadEngine] $_lastError');
    }

    _isInitialized = true;
  }

  /// Analyzes 16kHz mono float32 samples in exact 512-sample windows, drains all segments before and
  /// after flush() (without checking isDetected() after flush), and preserves pre/post-roll speech context.
  VadAnalysisResult analyze(Float32List samples, {int sampleRate = 16000}) {
    if (samples.isEmpty) {
      return const VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: [],
        energyEnvelope: [],
        trimmedSamples: null,
      );
    }

    final int numFrames = math.max(1, samples.length ~/ vadWindowSize);
    final energyEnv = _computeAcousticEnergyEnvelope(samples, frameSize: vadWindowSize);

    // 1. Native Silero VAD inference when initialized cleanly
    if (_vad != null && _isNativeAvailable) {
      try {
        _vad!.reset();
        _vad!.clear();

        final List<_RawSpan> rawSpans = [];

        // Feed exact 512-sample chunks so Sherpa's internal window queue accumulates all frames
        for (int offset = 0; offset < samples.length; offset += vadWindowSize) {
          final int end = math.min(offset + vadWindowSize, samples.length);
          Float32List chunk;
          if (end - offset == vadWindowSize) {
            chunk = Float32List.sublistView(samples, offset, end);
          } else {
            chunk = Float32List(vadWindowSize);
            chunk.setRange(0, end - offset, samples, offset);
          }

          _vad!.acceptWaveform(chunk);
          while (!_vad!.isEmpty()) {
            final seg = _vad!.front();
            if (seg.samples.isNotEmpty) {
              rawSpans.add(_RawSpan(seg.start, seg.samples.length));
            }
            _vad!.pop();
          }
        }

        // Flush tail segment and drain ALL queued segments regardless of post-flush isDetected()
        _vad!.flush();
        while (!_vad!.isEmpty()) {
          final seg = _vad!.front();
          if (seg.samples.isNotEmpty) {
            rawSpans.add(_RawSpan(seg.start, seg.samples.length));
          }
          _vad!.pop();
        }
        _vad!.clear();

        if (rawSpans.isEmpty) {
          return VadAnalysisResult(
            speechDetected: false,
            speechStartMs: 0,
            speechEndMs: 0,
            speechProbabilities: List<double>.filled(numFrames, 0.0),
            energyEnvelope: energyEnv,
            trimmedSamples: null,
            segments: const [],
            isNativeModel: true,
          );
        }

        // Expand with pre-roll / post-roll padding and merge overlapping segments
        final int preSamples = (preRollMs * sampleRate / 1000).round();
        final int postSamples = (postRollMs * sampleRate / 1000).round();
        final List<_RawSpan> padded = rawSpans.map((s) {
          final int start = math.max(0, s.startSample - preSamples);
          final int end = math.min(samples.length, s.startSample + s.length + postSamples);
          return _RawSpan(start, math.max(1, end - start));
        }).toList()
          ..sort((a, b) => a.startSample.compareTo(b.startSample));

        final List<_RawSpan> merged = [];
        for (final span in padded) {
          if (merged.isEmpty) {
            merged.add(span);
          } else {
            final prev = merged.last;
            final prevEnd = prev.startSample + prev.length;
            final spanEnd = span.startSample + span.length;
            if (span.startSample <= prevEnd + (350 * sampleRate ~/ 1000)) {
              merged[merged.length - 1] =
                  _RawSpan(prev.startSample, math.max(prevEnd, spanEnd) - prev.startSample);
            } else {
              merged.add(span);
            }
          }
        }

        int totalTrimmed = 0;
        for (final span in merged) {
          totalTrimmed += span.length;
        }
        final Float32List combinedTrimmed = Float32List(totalTrimmed);
        int writePos = 0;
        final List<VadSegment> vadSegments = [];
        final List<double> speechMask = List<double>.filled(numFrames, 0.0);

        for (final span in merged) {
          final slice = Float32List.sublistView(
            samples,
            span.startSample,
            span.startSample + span.length,
          );
          combinedTrimmed.setRange(writePos, writePos + span.length, slice);
          writePos += span.length;

          double sumSq = 0.0;
          for (int i = 0; i < slice.length; i++) {
            sumSq += slice[i] * slice[i];
          }
          final double segRms = math.sqrt(sumSq / math.max(1, slice.length));
          final int startMs = (span.startSample * 1000 / sampleRate).round();
          final int endMs = ((span.startSample + span.length) * 1000 / sampleRate).round();

          vadSegments.add(VadSegment(
            startMs: startMs,
            endMs: endMs,
            startSample: span.startSample,
            sampleCount: span.length,
            confidence: 1.0,
            rms: segRms,
          ));

          final int sf = (span.startSample ~/ vadWindowSize).clamp(0, numFrames - 1);
          final int ef = ((span.startSample + span.length + vadWindowSize - 1) ~/ vadWindowSize)
              .clamp(0, numFrames);
          for (int f = sf; f < ef; f++) {
            speechMask[f] = 1.0;
          }
        }

        return VadAnalysisResult(
          speechDetected: true,
          speechStartMs: vadSegments.first.startMs,
          speechEndMs: vadSegments.last.endMs,
          speechProbabilities: speechMask,
          energyEnvelope: energyEnv,
          trimmedSamples: combinedTrimmed,
          segments: vadSegments,
          isNativeModel: true,
        );
      } catch (e) {
        _lastError = 'Silero VAD native inference failed: $e';
        debugPrint('[SileroVadEngine] $_lastError');
        return VadAnalysisResult(
          speechDetected: false,
          speechStartMs: 0,
          speechEndMs: 0,
          speechProbabilities: List<double>.filled(numFrames, 0.0),
          energyEnvelope: energyEnv,
          trimmedSamples: null,
          isNativeModel: false,
          errorMessage: _lastError,
        );
      }
    }

    // Only allow acoustic energy fallback if initialize() was never called (unit test mode);
    // if initialize() ran and failed to load native Silero VAD, expose failure honestly.
    if (_isInitialized && _lastError != null) {
      return VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: List<double>.filled(numFrames, 0.0),
        energyEnvelope: energyEnv,
        trimmedSamples: null,
        isNativeModel: false,
        errorMessage: _lastError,
      );
    }

    return _calibratedAcousticAnalyze(samples, sampleRate: sampleRate, energyEnv: energyEnv);
  }

  List<double> _computeAcousticEnergyEnvelope(Float32List samples, {required int frameSize}) {
    final int numFrames = samples.length ~/ frameSize;
    if (numFrames == 0) return const [];
    final List<double> env = [];

    for (int f = 0; f < numFrames; f++) {
      double frameEnergy = 0.0;
      final int offset = f * frameSize;
      for (int i = 0; i < frameSize; i++) {
        final double s = samples[offset + i];
        frameEnergy += s * s;
      }
      frameEnergy /= frameSize;
      env.add(math.sqrt(frameEnergy).clamp(0.0, 1.0));
    }
    return env;
  }

  VadAnalysisResult _calibratedAcousticAnalyze(
    Float32List samples, {
    required int sampleRate,
    required List<double> energyEnv,
  }) {
    const int frameSize = vadWindowSize;
    final int numFrames = samples.length ~/ frameSize;
    if (numFrames == 0) {
      return const VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: [],
        energyEnvelope: [],
        trimmedSamples: null,
      );
    }

    final List<double> probs = [];
    for (int f = 0; f < numFrames; f++) {
      double frameEnergy = 0.0;
      int zeroCrossings = 0;
      final int offset = f * frameSize;

      for (int i = 0; i < frameSize; i++) {
        final double s = samples[offset + i];
        frameEnergy += s * s;
        if (i > 0 && ((samples[offset + i - 1] >= 0) != (s >= 0))) {
          zeroCrossings++;
        }
      }

      frameEnergy = math.sqrt(frameEnergy / frameSize);
      final double energyScore = ((frameEnergy - 0.008) / 0.04).clamp(0.0, 1.0);
      final double zcrRate = zeroCrossings / frameSize;
      final double zcrWeight = (zcrRate > 0.02 && zcrRate < 0.45) ? 1.0 : 0.4;
      probs.add((energyScore * zcrWeight).clamp(0.0, 1.0));
    }

    int firstSpeechFrame = -1;
    int lastSpeechFrame = -1;
    int consecutiveSpeechFrames = 0;
    final int minFramesRequired = math.max(1, (minSpeechDurationMs * sampleRate / (frameSize * 1000)).round());

    for (int f = 0; f < probs.length; f++) {
      if (probs[f] >= speechThreshold) {
        consecutiveSpeechFrames++;
        if (firstSpeechFrame == -1 && consecutiveSpeechFrames >= math.min(2, minFramesRequired)) {
          firstSpeechFrame = math.max(0, f - consecutiveSpeechFrames + 1);
        }
        lastSpeechFrame = f;
      } else {
        consecutiveSpeechFrames = 0;
      }
    }

    if (firstSpeechFrame == -1 || lastSpeechFrame == -1) {
      return VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: probs,
        energyEnvelope: energyEnv,
        trimmedSamples: null,
      );
    }

    final int paddingFrames = (speechSilencePaddingMs * sampleRate / (frameSize * 1000)).round();
    final int paddedStartFrame = math.max(0, firstSpeechFrame - paddingFrames);
    final int paddedEndFrame = math.min(numFrames - 1, lastSpeechFrame + paddingFrames);

    final int startSample = paddedStartFrame * frameSize;
    final int endSample = math.min(samples.length, (paddedEndFrame + 1) * frameSize);

    final int startMs = (startSample * 1000 / sampleRate).round();
    final int endMs = (endSample * 1000 / sampleRate).round();

    if (endMs - startMs < minSpeechDurationMs) {
      return VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: probs,
        energyEnvelope: energyEnv,
        trimmedSamples: null,
      );
    }

    final Float32List trimmed = Float32List.sublistView(samples, startSample, endSample);

    return VadAnalysisResult(
      speechDetected: true,
      speechStartMs: startMs,
      speechEndMs: endMs,
      speechProbabilities: probs,
      energyEnvelope: energyEnv,
      trimmedSamples: Float32List.fromList(trimmed),
      segments: [
        VadSegment(
          startMs: startMs,
          endMs: endMs,
          startSample: startSample,
          sampleCount: trimmed.length,
          confidence: 0.75,
        ),
      ],
      isNativeModel: false,
    );
  }

  void dispose() {
    _vad?.free();
    _vad = null;
    _isInitialized = false;
    _isNativeAvailable = false;
  }
}

class _RawSpan {
  final int startSample;
  final int length;
  const _RawSpan(this.startSample, this.length);
}
