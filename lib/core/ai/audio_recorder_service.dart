import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_preprocessor.dart';

/// Exception thrown when native microphone capture fails or produces an unfinalized/corrupt WAV file.
class AudioRecordingException implements Exception {
  final String message;
  const AudioRecordingException(this.message);

  @override
  String toString() => 'AudioRecordingException: $message';
}

/// Real device microphone capture service backed by [AudioRecorder] (16kHz mono PCM16 WAV).
class AudioRecorderService {
  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();
  final AudioPreprocessor _preprocessor;
  String? _currentRecordingPath;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  String? _lastError;

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Timer? _amplitudeTimer;

  AudioRecorderService({AudioPreprocessor? preprocessor})
    : _preprocessor = preprocessor ?? const AudioPreprocessor();

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get lastError => _lastError;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Checks and requests microphone permission using permission_handler on mobile and record on desktop.
  Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.microphone.request();
        return status.isGranted;
      }
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[AudioRecorderService] Permission error: $e');
      _lastError = 'Microphone permission check failed: $e';
      return false;
    }
  }

  /// Checks current microphone permission status without prompting.
  Future<bool> hasPermission() async {
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await Permission.microphone.isGranted;
      }
      return await _recorder.hasPermission();
    } catch (e) {
      _lastError = 'Microphone permission status failed: $e';
      return false;
    }
  }

  /// Starts recording 16kHz Mono 16-bit PCM WAV audio.
  Future<void> startRecording() async {
    if (_isRecording) return;
    _lastError = null;

    final hasPerm = await requestMicrophonePermission();
    if (!hasPerm) {
      _lastError = 'Microphone permission not granted';
      throw const AudioRecordingException('Microphone permission not granted');
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      );

      await _recorder.start(config, path: _currentRecordingPath!);
      _isRecording = true;
      _recordingStartTime = DateTime.now();

      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (
        _,
      ) async {
        if (!_isRecording) return;
        try {
          final amp = await _recorder.getAmplitude();
          final double normalized = (1.0 + (amp.current / 60.0)).clamp(
            0.0,
            1.0,
          );
          _amplitudeController.add(normalized);
        } catch (_) {}
      });
    } catch (e) {
      _isRecording = false;
      _lastError = 'Start recording failed: $e';
      debugPrint('[AudioRecorderService] Start recording error: $e');
      throw AudioRecordingException(_lastError!);
    }
  }

  /// Stops recording, waits for WAV file finalization & chunk verification, and returns raw WAV bytes.
  /// Throws [AudioRecordingException] if capture failed or produced corrupt/empty audio.
  Future<Uint8List> stopRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    if (!_isRecording) {
      return Uint8List(0);
    }

    try {
      final elapsedMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      if (elapsedMs < 150) {
        // Allow Android AudioRecord HAL to flush at least one buffer frame before stop
        await Future.delayed(Duration(milliseconds: 150 - elapsedMs));
      }

      final String? path = await _recorder.stop();
      _isRecording = false;

      final String? filePath = path ?? _currentRecordingPath;
      if (filePath == null || filePath.isEmpty) {
        _lastError = 'Recorder stopped without producing a file path.';
        throw AudioRecordingException(_lastError!);
      }

      final File file = File(filePath);
      final Uint8List bytes = await _waitForFinalizedWavFile(file);
      // Verify RIFF/WAVE header & chunk consistency before handing off to AI engines
      _preprocessor.parseWavMetadata(bytes);
      _lastError = null;
      return bytes;
    } catch (e) {
      _isRecording = false;
      if (e is AudioRecordingException) rethrow;
      _lastError = 'Stop recording failed: $e';
      debugPrint('[AudioRecorderService] Stop recording error: $e');
      throw AudioRecordingException(_lastError!);
    }
  }

  Future<Uint8List> _waitForFinalizedWavFile(File file) async {
    int prevLen = -1;
    for (int attempt = 0; attempt < 12; attempt++) {
      if (await file.exists()) {
        final int len = await file.length();
        if (len > 44 && len == prevLen) {
          return file.readAsBytes();
        }
        prevLen = len;
      }
      await Future.delayed(const Duration(milliseconds: 25));
    }

    if (!await file.exists()) {
      throw AudioRecordingException(
        'Recorded WAV file missing at ${file.path}',
      );
    }
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.length <= 44) {
      throw AudioRecordingException(
        'Recorded WAV file is empty or incomplete (${bytes.length} bytes).',
      );
    }
    return bytes;
  }

  /// Cancels the active recording.
  Future<void> cancelRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
  }

  /// Disposes the recorder and stream resources.
  Future<void> dispose() async {
    _amplitudeTimer?.cancel();
    await _amplitudeController.close();
    await _recorderInstance?.dispose();
  }
}
