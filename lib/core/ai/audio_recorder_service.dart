import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_preprocessor.dart';

enum AudioRecordingErrorKind {
  permissionDenied,
  micBusy,
  nativeStartFailed,
  nativeStopFailed,
  timeout,
  corruptOrEmptyWav,
  disposed,
}

/// Exception thrown when native microphone capture fails or produces an unfinalized/corrupt WAV file.
class AudioRecordingException implements Exception {
  final String message;
  final AudioRecordingErrorKind kind;
  final int attemptId;

  const AudioRecordingException(
    this.message, {
    this.kind = AudioRecordingErrorKind.nativeStopFailed,
    this.attemptId = 0,
  });

  @override
  String toString() => 'AudioRecordingException(${kind.name}): $message';
}

/// Captured WAV metadata returned cleanly alongside bytes for diagnostics & lab telemetry.
class RecordedCaptureInfo {
  final int attemptId;
  final String owner;
  final String filePath;
  final int durationMs;
  final int wavBytesLength;
  final bool recoveredFromError;

  const RecordedCaptureInfo({
    required this.attemptId,
    required this.owner,
    required this.filePath,
    required this.durationMs,
    required this.wavBytesLength,
    this.recoveredFromError = false,
  });
}

/// Injectable backend contract wrapping [AudioRecorder] so deterministic lifecycle
/// stress-tests (100+ cycles) run without touching physical hardware.
abstract class RecorderBackend {
  Future<bool> hasPermission();
  Future<bool> isRecording();
  Future<void> start(RecordConfig config, {required String path});
  Future<String?> stop();
  Future<void> cancel();
  Future<double> getAmplitudeDbfs();
  Future<void> dispose();
}

class _PlatformRecordBackend implements RecorderBackend {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Future<void> start(RecordConfig config, {required String path}) =>
      _recorder.start(config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<double> getAmplitudeDbfs() async {
    final amp = await _recorder.getAmplitude();
    return amp.current;
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Serialized, fault-tolerant microphone capture service (16kHz mono PCM16 WAV).
///
/// Prevents overlapping start/stop/cancel operations, verifies native state, creates
/// unique per-attempt temporary WAV paths, guards async amplitude polling, and
/// recreates the underlying native backend whenever state becomes invalid.
class AudioRecorderService {
  static const Duration _nativeOpTimeout = Duration(seconds: 5);
  static const Duration _minRecordFlushDuration = Duration(milliseconds: 150);

  final AudioPreprocessor _preprocessor;
  final RecorderBackend Function() _backendFactory;
  final Future<bool> Function()? _permissionRequesterOverride;
  final Future<bool> Function()? _permissionCheckerOverride;
  final Future<Directory> Function()? _tempDirProvider;

  RecorderBackend? _backend;
  String? _currentRecordingPath;
  String? _activeOwner;
  int _attemptSeq = 0;
  int _activeAttemptId = 0;
  bool _isRecording = false;
  bool _disposed = false;
  bool _recoveredLastAttempt = false;
  int _recoveryCount = 0;
  DateTime? _recordingStartTime;
  String? _lastError;
  AudioRecordingErrorKind? _lastErrorKind;
  RecordedCaptureInfo? _lastCaptureInfo;

  // Serialized FIFO operation chain preventing start/stop/cancel/dispose races.
  Future<void> _opChain = Future<void>.value();

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Timer? _amplitudeTimer;
  bool _amplitudePollInFlight = false;

  AudioRecorderService({
    AudioPreprocessor? preprocessor,
    RecorderBackend Function()? backendFactory,
    Future<bool> Function()? permissionRequesterOverride,
    Future<bool> Function()? permissionCheckerOverride,
    Future<Directory> Function()? tempDirProvider,
  }) : _preprocessor = preprocessor ?? const AudioPreprocessor(),
       _backendFactory = backendFactory ?? (() => _PlatformRecordBackend()),
       _permissionRequesterOverride = permissionRequesterOverride,
       _permissionCheckerOverride = permissionCheckerOverride,
       _tempDirProvider = tempDirProvider;

  bool get isRecording => _isRecording;
  String? get activeOwner => _activeOwner;
  int get activeAttemptId => _activeAttemptId;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get lastError => _lastError;
  AudioRecordingErrorKind? get lastErrorKind => _lastErrorKind;
  int get recoveryCount => _recoveryCount;
  bool get recoveredLastAttempt => _recoveredLastAttempt;
  RecordedCaptureInfo? get lastCaptureInfo => _lastCaptureInfo;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  RecorderBackend _ensureBackend() => _backend ??= _backendFactory();

  Future<T> _runSerialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _opChain = _opChain.catchError((_) {}).then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Checks and requests microphone permission using permission_handler on mobile and record on desktop.
  Future<bool> requestMicrophonePermission() async {
    if (_permissionRequesterOverride != null) {
      return _permissionRequesterOverride();
    }
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.microphone.request();
        return status.isGranted;
      }
      return await _ensureBackend().hasPermission().timeout(_nativeOpTimeout);
    } catch (e) {
      debugPrint('[AudioRecorderService] Permission error: $e');
      _lastError = 'Microphone permission check failed: $e';
      _lastErrorKind = AudioRecordingErrorKind.permissionDenied;
      return false;
    }
  }

  /// Checks current microphone permission status without prompting.
  Future<bool> hasPermission() async {
    if (_permissionCheckerOverride != null) {
      return _permissionCheckerOverride();
    }
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await Permission.microphone.isGranted;
      }
      return await _ensureBackend().hasPermission().timeout(_nativeOpTimeout);
    } catch (e) {
      _lastError = 'Microphone permission status failed: $e';
      _lastErrorKind = AudioRecordingErrorKind.permissionDenied;
      return false;
    }
  }

  /// Serialized capture start (default owner) preserving zero-arg contract.
  Future<void> startRecording() => startOwnedRecording('default');

  /// Serialized capture start with fresh attempt ID, unique path, and owner isolation.
  Future<void> startOwnedRecording(String owner) {
    return _runSerialized(() async {
      if (_disposed) {
        throw const AudioRecordingException(
          'Recorder service has been disposed.',
          kind: AudioRecordingErrorKind.disposed,
        );
      }

      if (_isRecording) {
        if (_activeOwner == owner) {
          throw AudioRecordingException(
            'Recording already active for owner "$owner".',
            kind: AudioRecordingErrorKind.micBusy,
            attemptId: _activeAttemptId,
          );
        }
        throw AudioRecordingException(
          'Microphone busy (owned by "$_activeOwner").',
          kind: AudioRecordingErrorKind.micBusy,
          attemptId: _activeAttemptId,
        );
      }

      _lastError = null;
      _lastErrorKind = null;
      _recoveredLastAttempt = false;

      final bool hasPerm = await requestMicrophonePermission();
      if (!hasPerm) {
        _lastError = 'Microphone permission not granted';
        _lastErrorKind = AudioRecordingErrorKind.permissionDenied;
        throw const AudioRecordingException(
          'Microphone permission not granted',
          kind: AudioRecordingErrorKind.permissionDenied,
        );
      }

      // Check whether the native recorder remained wedged from an external or interrupted failure.
      await _reconcileStaleNativeState();

      final int attemptId = ++_attemptSeq;
      final Directory tempDir =
          await (_tempDirProvider?.call() ?? getTemporaryDirectory());
      final String path =
          '${tempDir.path}/yasser_rec_a${attemptId}_${DateTime.now().millisecondsSinceEpoch}.wav';
      _deleteFileSafe(path);

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
        androidConfig: AndroidRecordConfig(
          manageBluetooth: false,
          audioSource: AndroidAudioSource.mic,
          audioManagerMode: AudioManagerMode.modeNormal,
        ),
      );

      try {
        await _ensureBackend()
            .start(config, path: path)
            .timeout(_nativeOpTimeout);
        final bool nativeActive = await _ensureBackend().isRecording().timeout(
          _nativeOpTimeout,
        );
        if (!nativeActive) {
          throw AudioRecordingException(
            'Native recorder reported isRecording=false right after start.',
            kind: AudioRecordingErrorKind.nativeStartFailed,
            attemptId: attemptId,
          );
        }

        _currentRecordingPath = path;
        _activeOwner = owner;
        _activeAttemptId = attemptId;
        _isRecording = true;
        _recordingStartTime = DateTime.now();
        _startAmplitudeTimer(attemptId);
      } catch (e) {
        await _recreateBackendOnFailure('start failure ($e)');
        _deleteFileSafe(path);
        _clearActiveAttemptState();
        final kind = e is AudioRecordingException
            ? e.kind
            : (e is TimeoutException
                  ? AudioRecordingErrorKind.timeout
                  : AudioRecordingErrorKind.nativeStartFailed);
        _lastError = 'Start recording failed: $e';
        _lastErrorKind = kind;
        debugPrint('[AudioRecorderService] $_lastError');
        throw AudioRecordingException(
          _lastError!,
          kind: kind,
          attemptId: attemptId,
        );
      }
    });
  }

  /// Stops recording safely (default contract) and validates finalized WAV bytes.
  Future<Uint8List> stopRecording() => stopOwnedRecording(null);

  /// Stops recording safely, validates finalized WAV bytes, and always releases ownership.
  Future<Uint8List> stopOwnedRecording(String? owner) {
    return _runSerialized(() async {
      _stopAmplitudeTimer();

      if (_disposed || !_isRecording) {
        return Uint8List(0);
      }
      if (owner != null && _activeOwner != null && _activeOwner != owner) {
        throw AudioRecordingException(
          'Stop rejected: owner "$owner" does not match active "$_activeOwner".',
          kind: AudioRecordingErrorKind.micBusy,
          attemptId: _activeAttemptId,
        );
      }

      final int attemptId = _activeAttemptId;
      final String currentOwner = _activeOwner ?? 'default';
      final String? fallbackPath = _currentRecordingPath;
      final DateTime? startedAt = _recordingStartTime;

      try {
        final int elapsedMs = startedAt != null
            ? DateTime.now().difference(startedAt).inMilliseconds
            : 0;
        if (elapsedMs < _minRecordFlushDuration.inMilliseconds) {
          await Future.delayed(
            Duration(
              milliseconds: _minRecordFlushDuration.inMilliseconds - elapsedMs,
            ),
          );
        }

        final String? stoppedPath = await _ensureBackend().stop().timeout(
          _nativeOpTimeout,
        );
        final String? filePath = (stoppedPath != null && stoppedPath.isNotEmpty)
            ? stoppedPath
            : fallbackPath;

        if (filePath == null || filePath.isEmpty) {
          throw AudioRecordingException(
            'Recorder stopped without producing a file path.',
            kind: AudioRecordingErrorKind.corruptOrEmptyWav,
            attemptId: attemptId,
          );
        }

        final File file = File(filePath);
        final Uint8List bytes = await _waitForFinalizedWavFile(
          file,
          attemptId: attemptId,
        );
        final meta = _preprocessor.parseWavMetadata(bytes);

        _lastError = null;
        _lastErrorKind = null;
        _lastCaptureInfo = RecordedCaptureInfo(
          attemptId: attemptId,
          owner: currentOwner,
          filePath: filePath,
          durationMs: meta.durationMs,
          wavBytesLength: bytes.length,
          recoveredFromError: _recoveredLastAttempt,
        );
        return bytes;
      } catch (e) {
        await _recreateBackendOnFailure('stop/wav failure ($e)');
        if (fallbackPath != null) _deleteFileSafe(fallbackPath);
        if (e is AudioRecordingException) {
          _lastError = e.message;
          _lastErrorKind = e.kind;
          rethrow;
        }
        final kind = e is InvalidAudioFormatException
            ? AudioRecordingErrorKind.corruptOrEmptyWav
            : (e is TimeoutException
                  ? AudioRecordingErrorKind.timeout
                  : AudioRecordingErrorKind.nativeStopFailed);
        _lastError = 'Stop recording failed: $e';
        _lastErrorKind = kind;
        debugPrint('[AudioRecorderService] $_lastError');
        throw AudioRecordingException(
          _lastError!,
          kind: kind,
          attemptId: attemptId,
        );
      } finally {
        _clearActiveAttemptState();
      }
    });
  }

  /// Releases active microphone session safely.
  Future<void> cancelRecording() => cancelOwnedRecording(null);

  /// Releases active microphone session safely for [owner] (or any owner if null).
  Future<void> cancelOwnedRecording(String? owner) {
    return _runSerialized(() async {
      if (_disposed) return;
      if (_backend == null && !_isRecording) return;
      if (owner != null && _activeOwner != null && _activeOwner != owner) {
        return;
      }

      _stopAmplitudeTimer();
      final String? stalePath = _currentRecordingPath;
      bool needsRecreate = false;

      try {
        final bool nativeActive = await _ensureBackend()
            .isRecording()
            .timeout(_nativeOpTimeout)
            .catchError((_) => true);
        if (_isRecording || nativeActive) {
          await _ensureBackend().cancel().timeout(_nativeOpTimeout);
        }
      } catch (e) {
        debugPrint(
          '[AudioRecorderService] Cancel error -> recreating backend: $e',
        );
        needsRecreate = true;
      } finally {
        _clearActiveAttemptState();
        if (stalePath != null) _deleteFileSafe(stalePath);
      }

      if (needsRecreate) {
        await _recreateBackendOnFailure('cancel exception');
      }
    });
  }

  /// Explicitly tears down and recreates the native [RecorderBackend] (for developer recovery or severe HAL lockups).
  Future<void> resetRecorder() {
    return _runSerialized(() async {
      _stopAmplitudeTimer();
      final String? stalePath = _currentRecordingPath;
      _clearActiveAttemptState();
      if (stalePath != null) _deleteFileSafe(stalePath);
      await _recreateBackendOnFailure('explicit reset');
      _lastError = null;
      _lastErrorKind = null;
    });
  }

  Future<void> _reconcileStaleNativeState() async {
    try {
      final backend = _ensureBackend();
      final bool nativeActive = await backend.isRecording().timeout(
        _nativeOpTimeout,
      );
      if (nativeActive) {
        await backend.cancel().timeout(_nativeOpTimeout);
        await _recreateBackendOnFailure('stale active native state');
      }
    } catch (e) {
      await _recreateBackendOnFailure('stale state probe failed ($e)');
    }
  }

  Future<void> _recreateBackendOnFailure(String reason) async {
    debugPrint(
      '[AudioRecorderService] Recreating native AudioRecorder ($reason)',
    );
    try {
      await _backend?.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _backend = null;
    _recoveredLastAttempt = true;
    _recoveryCount++;
  }

  void _clearActiveAttemptState() {
    _isRecording = false;
    _activeOwner = null;
    _activeAttemptId = 0;
    _currentRecordingPath = null;
    _recordingStartTime = null;
  }

  void _startAmplitudeTimer(int attemptId) {
    _stopAmplitudeTimer();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (
      _,
    ) async {
      if (!_isRecording || _disposed || _activeAttemptId != attemptId) return;
      if (_amplitudePollInFlight) return;
      _amplitudePollInFlight = true;
      try {
        final dbfs = await _ensureBackend().getAmplitudeDbfs().timeout(
          const Duration(milliseconds: 250),
        );
        if (!_isRecording || _disposed || _activeAttemptId != attemptId) return;
        final double normalized = (1.0 + (dbfs / 60.0)).clamp(0.0, 1.0);
        if (!_amplitudeController.isClosed) {
          _amplitudeController.add(normalized);
        }
      } catch (_) {
      } finally {
        _amplitudePollInFlight = false;
      }
    });
  }

  void _stopAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudePollInFlight = false;
  }

  Future<Uint8List> _waitForFinalizedWavFile(
    File file, {
    required int attemptId,
  }) async {
    int prevLen = -1;
    for (int attempt = 0; attempt < 16; attempt++) {
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
        kind: AudioRecordingErrorKind.corruptOrEmptyWav,
        attemptId: attemptId,
      );
    }
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.length <= 44) {
      throw AudioRecordingException(
        'Recorded WAV file is empty or incomplete (${bytes.length} bytes).',
        kind: AudioRecordingErrorKind.corruptOrEmptyWav,
        attemptId: attemptId,
      );
    }
    return bytes;
  }

  void _deleteFileSafe(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  /// Disposes the recorder and stream resources cleanly.
  Future<void> dispose() async {
    if (_disposed) return;
    await _runSerialized(() async {
      if (_disposed) return;
      _disposed = true;
      _stopAmplitudeTimer();
      _clearActiveAttemptState();
      try {
        await _backend?.dispose().timeout(const Duration(seconds: 2));
      } catch (_) {}
      _backend = null;
      if (!_amplitudeController.isClosed) {
        await _amplitudeController.close();
      }
    });
  }
}
