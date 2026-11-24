import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder;

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  Timer? _amplitudeTimer;

  AudioRecorderService({
    AudioRecorder? recorder,
  })  : _recorder = recorder ?? AudioRecorder();

  bool get isRecording => _isRecording;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  DateTime? get recordingStartTime => _recordingStartTime;

  /// Requests microphone permission
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
      return true; // Desktop fallback
    }
  }

  /// Checks if microphone permission is granted
  Future<bool> hasPermission() async {
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await Permission.microphone.isGranted;
      }
      return await _recorder.hasPermission();
    } catch (_) {
      return true;
    }
  }

  /// Starts recording 16kHz Mono 16-bit PCM audio
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPerm = await requestMicrophonePermission();
    if (!hasPerm) {
      throw Exception('Microphone permission not granted');
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

      // Poll amplitude for live visualization
      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
        if (!_isRecording) return;
        try {
          final amp = await _recorder.getAmplitude();
          // amp.current is typically in dB (-160 to 0)
          final double normalized = (1.0 + (amp.current / 60.0)).clamp(0.0, 1.0);
          _amplitudeController.add(normalized);
        } catch (_) {}
      });
    } catch (e) {
      _isRecording = false;
      debugPrint('[AudioRecorderService] Start recording error: $e');
      rethrow;
    }
  }

  /// Stops recording and returns the raw audio bytes (16-bit PCM or WAV)
  Future<Uint8List> stopRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    if (!_isRecording) {
      return Uint8List(0);
    }

    try {
      final String? path = await _recorder.stop();
      _isRecording = false;

      final filePath = path ?? _currentRecordingPath;
      if (filePath != null && File(filePath).existsSync()) {
        final File file = File(filePath);
        final Uint8List bytes = await file.readAsBytes();
        return bytes;
      }
      return Uint8List(0);
    } catch (e) {
      _isRecording = false;
      debugPrint('[AudioRecorderService] Stop recording error: $e');
      return Uint8List(0);
    }
  }

  /// Cancels the active recording
  Future<void> cancelRecording() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
    }
  }

  /// Disposes the recorder and stream resources
  Future<void> dispose() async {
    _amplitudeTimer?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}
