import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

import 'models/phoneme_token.dart';
import 'phoneme_recognition_engine.dart';
import 'speech_to_text_engine.dart';

/// Persistent dedicated background Isolate worker that owns heavyweight native ONNX
/// sessions (`Wav2Vec2-eSpeak` & `Whisper Tiny`) cleanly off the Flutter UI thread.
///
/// Native FFI pointers remain strictly confined inside the worker isolate; only plain
/// Dart typed audio buffers and immutable result payloads cross isolate ports.
class AiInferenceWorker {
  Isolate? _isolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  StreamSubscription<dynamic>? _portSub;

  int _nextReqId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  Future<void>? _initFuture;
  bool _isReady = false;
  bool _disposed = false;
  String? _lastError;

  bool get isReady => _isReady && _workerSendPort != null;
  String? get lastError => _lastError;

  /// Spawns the worker isolate and initializes ONNX sessions using resolved filesystem paths.
  Future<bool> initialize({
    String? wav2vecModelPath,
    String? wav2vecVocabPath,
    String? whisperEncoderPath,
    String? whisperDecoderPath,
    String? whisperTokensPath,
  }) async {
    if (_disposed) return false;
    if (isReady) return true;
    if (_initFuture != null) {
      await _initFuture;
      return isReady;
    }

    final completer = Completer<void>();
    _initFuture = completer.future;

    try {
      _mainReceivePort = ReceivePort();
      final readyPort = ReceivePort();

      _isolate = await Isolate.spawn(
        _workerMain,
        readyPort.sendPort,
        debugName: 'YasserOnnxWorker',
      );

      _workerSendPort =
          await readyPort.first.timeout(const Duration(seconds: 5)) as SendPort;
      readyPort.close();

      _portSub = _mainReceivePort!.listen((message) {
        if (message is Map<String, dynamic>) {
          final id = message['id'] as int?;
          if (id != null && _pending.containsKey(id)) {
            _pending.remove(id)!.complete(message);
          }
        }
      });

      final res = await _sendRequest({
        'cmd': 'init',
        'wav2vecModelPath': wav2vecModelPath,
        'wav2vecVocabPath': wav2vecVocabPath,
        'whisperEncoderPath': whisperEncoderPath,
        'whisperDecoderPath': whisperDecoderPath,
        'whisperTokensPath': whisperTokensPath,
      }, timeout: const Duration(seconds: 30));

      _isReady = res['ok'] == true;
      _lastError = res['error'] as String?;
      return _isReady;
    } catch (e) {
      _lastError = 'Worker initialization error: $e';
      _isReady = false;
      await dispose();
      _disposed = false; // Allow retry if needed later
      return false;
    } finally {
      completer.complete();
      _initFuture = null;
    }
  }

  /// Runs blind acoustic phoneme recognition inside the persistent background isolate.
  Future<PhonemeRecognitionResult> recognizePhonemes(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (!isReady) {
      return PhonemeRecognitionResult(
        tokens: const [],
        latencyMs: 0,
        frameCount: 0,
        audioDurationMs: (samples.length * 1000 / sampleRate).round(),
        isNativeModel: false,
        errorMessage: _lastError ?? 'Background AI worker not initialized.',
      );
    }

    final res = await _sendRequest({
      'cmd': 'phonemes',
      'pcm': TransferableTypedData.fromList([samples]),
      'sampleRate': sampleRate,
    }, timeout: const Duration(seconds: 25));

    if (res['ok'] != true && (res['error'] as String?) != null) {
      return PhonemeRecognitionResult(
        tokens: const [],
        latencyMs: res['latencyMs'] as int? ?? 0,
        frameCount: res['frameCount'] as int? ?? 0,
        audioDurationMs: res['audioDurationMs'] as int? ?? 0,
        isNativeModel: res['isNative'] as bool? ?? false,
        errorMessage: res['error'] as String?,
      );
    }

    final rawTokens = (res['tokens'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (m) => PhonemeToken(
            symbol: m['symbol'] as String? ?? '',
            arabicSymbol: m['arabicSymbol'] as String? ?? '',
            tokenId: m['tokenId'] as int? ?? 0,
            confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
            acousticMargin: (m['acousticMargin'] as num?)?.toDouble(),
            startFrame: m['startFrame'] as int? ?? 0,
            endFrame: m['endFrame'] as int? ?? 0,
            startMs: m['startMs'] as int? ?? 0,
            endMs: m['endMs'] as int? ?? 0,
            isAccurate: m['isAccurate'] as bool? ?? true,
            isTimestampEstimated: m['isTimestampEstimated'] as bool? ?? false,
          ),
        )
        .toList();

    return PhonemeRecognitionResult(
      tokens: rawTokens,
      latencyMs: res['latencyMs'] as int? ?? 0,
      frameCount: res['frameCount'] as int? ?? 0,
      audioDurationMs: res['audioDurationMs'] as int? ?? 0,
      averageConfidence: (res['avgConf'] as num?)?.toDouble(),
      averageAcousticMargin: (res['avgMargin'] as num?)?.toDouble(),
      isNativeModel: res['isNative'] as bool? ?? false,
      errorMessage: res['error'] as String?,
    );
  }

  /// Runs Whisper Tiny Arabic transcription inside the persistent background isolate.
  Future<SttResult> transcribe(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (!isReady) {
      return SttResult(
        text: '',
        confidence: null,
        latencyMs: 0,
        realTimeFactor: 0.0,
        isModelInference: false,
        errorMessage: _lastError ?? 'Background AI worker not initialized.',
      );
    }

    final res = await _sendRequest({
      'cmd': 'stt',
      'pcm': TransferableTypedData.fromList([samples]),
      'sampleRate': sampleRate,
    }, timeout: const Duration(seconds: 25));

    return SttResult(
      text: res['text'] as String? ?? '',
      confidence: null,
      latencyMs: res['latencyMs'] as int? ?? 0,
      realTimeFactor: (res['rtf'] as num?)?.toDouble() ?? 0.0,
      isModelInference: res['isNative'] as bool? ?? false,
      tokens: (res['tokens'] as List? ?? const []).cast<String>(),
      timestamps: (res['timestamps'] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      errorMessage: res['error'] as String?,
    );
  }

  Future<Map<String, dynamic>> _sendRequest(
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) async {
    final sendPort = _workerSendPort;
    final replyPort = _mainReceivePort?.sendPort;
    if (sendPort == null || replyPort == null) {
      return {'ok': false, 'error': 'Worker port unavailable.'};
    }

    final id = ++_nextReqId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    sendPort.send({...payload, 'id': id, 'replyPort': replyPort});

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        return {'ok': false, 'error': 'Worker request $id timed out.'};
      },
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _isReady = false;
    try {
      _workerSendPort?.send({'cmd': 'dispose'});
    } catch (_) {}
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete({'ok': false, 'error': 'Worker disposed.'});
      }
    }
    _pending.clear();
    await _portSub?.cancel();
    _portSub = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _workerSendPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  static void _workerMain(SendPort initReplyPort) {
    final cmdPort = ReceivePort();
    initReplyPort.send(cmdPort.sendPort);

    PhonemeRecognitionEngine? phonemeEngine;
    SpeechToTextEngine? sttEngine;

    // Serialize worker queue sequentially to match native session constraints.
    Future<void> chain = Future<void>.value();

    cmdPort.listen((rawMsg) {
      if (rawMsg is! Map<String, dynamic>) return;
      final cmd = rawMsg['cmd'] as String?;
      final id = rawMsg['id'] as int?;
      final replyPort = rawMsg['replyPort'] as SendPort?;

      if (cmd == 'dispose') {
        phonemeEngine?.dispose();
        sttEngine?.dispose();
        phonemeEngine = null;
        sttEngine = null;
        cmdPort.close();
        return;
      }

      chain = chain.then((_) async {
        try {
          if (cmd == 'init') {
            final w2vModel = rawMsg['wav2vecModelPath'] as String?;
            final w2vVocab = rawMsg['wav2vecVocabPath'] as String?;
            final whEnc = rawMsg['whisperEncoderPath'] as String?;
            final whDec = rawMsg['whisperDecoderPath'] as String?;
            final whTok = rawMsg['whisperTokensPath'] as String?;

            if (w2vModel != null && w2vVocab != null) {
              phonemeEngine?.dispose();
              phonemeEngine = PhonemeRecognitionEngine(
                modelPathOverride: w2vModel,
                vocabPathOverride: w2vVocab,
              );
              await phonemeEngine!.initialize();
            }
            if (whEnc != null && whDec != null && whTok != null) {
              sttEngine?.dispose();
              sttEngine = SpeechToTextEngine(
                encoderPathOverride: whEnc,
                decoderPathOverride: whDec,
                tokensPathOverride: whTok,
              );
              await sttEngine!.initialize();
            }
            final bool w2vOk = phonemeEngine?.isNativeAvailable ?? false;
            replyPort?.send({
              'id': id,
              'ok': w2vOk,
              'error': phonemeEngine?.lastError,
            });
          } else if (cmd == 'phonemes') {
            final ttd = rawMsg['pcm'] as TransferableTypedData;
            final sr = rawMsg['sampleRate'] as int? ?? 16000;
            final Float32List samples = ttd.materialize().asFloat32List();
            if (phonemeEngine == null) {
              replyPort?.send({
                'id': id,
                'ok': false,
                'isNative': false,
                'error': 'PhonemeRecognitionEngine not initialized in worker.',
              });
              return;
            }
            final res = await phonemeEngine!.recognizePhonemesDetailed(
              samples,
              sampleRate: sr,
            );
            replyPort?.send({
              'id': id,
              'ok': !res.hasError,
              'isNative': res.isNativeModel,
              'latencyMs': res.latencyMs,
              'frameCount': res.frameCount,
              'audioDurationMs': res.audioDurationMs,
              'avgConf': res.averageConfidence,
              'avgMargin': res.averageAcousticMargin,
              'error': res.errorMessage,
              'tokens': res.tokens
                  .map(
                    (t) => {
                      'symbol': t.symbol,
                      'arabicSymbol': t.arabicSymbol,
                      'tokenId': t.tokenId,
                      'confidence': t.confidence,
                      'acousticMargin': t.acousticMargin,
                      'startFrame': t.startFrame,
                      'endFrame': t.endFrame,
                      'startMs': t.startMs,
                      'endMs': t.endMs,
                      'isAccurate': t.isAccurate,
                      'isTimestampEstimated': t.isTimestampEstimated,
                    },
                  )
                  .toList(),
            });
          } else if (cmd == 'stt') {
            final ttd = rawMsg['pcm'] as TransferableTypedData;
            final sr = rawMsg['sampleRate'] as int? ?? 16000;
            final Float32List samples = ttd.materialize().asFloat32List();
            if (sttEngine == null) {
              replyPort?.send({
                'id': id,
                'ok': false,
                'isNative': false,
                'error': 'SpeechToTextEngine not initialized in worker.',
              });
              return;
            }
            final res = await sttEngine!.transcribe(samples, sampleRate: sr);
            replyPort?.send({
              'id': id,
              'ok': !res.hasError,
              'isNative': res.isModelInference,
              'text': res.text,
              'latencyMs': res.latencyMs,
              'rtf': res.realTimeFactor,
              'tokens': res.tokens,
              'timestamps': res.timestamps,
              'error': res.errorMessage,
            });
          }
        } catch (e) {
          replyPort?.send({
            'id': id,
            'ok': false,
            'error': 'Worker execution exception: $e',
          });
        }
      });
    });
  }
}
