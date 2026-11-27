import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:liqaa_app/core/ai/audio_preprocessor.dart';
import 'package:liqaa_app/core/ai/audio_recorder_service.dart';
import 'package:liqaa_app/core/ai/models/lab_task_mode.dart';
import 'package:liqaa_app/core/ai/models/phoneme_token.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/ai/phoneme_recognition_engine.dart';
import 'package:liqaa_app/core/ai/pronunciation_repository.dart';
import 'package:liqaa_app/core/ai/rnnoise_denoiser_engine.dart';
import 'package:liqaa_app/core/ai/silero_vad_engine.dart';
import 'package:liqaa_app/core/ai/speech_to_text_engine.dart';
import 'package:liqaa_app/core/audio/yasser_audio_coordinator.dart';
import 'package:liqaa_app/features/ai_lab/cubits/ai_lab_cubit.dart';
import 'package:liqaa_app/features/pronunciation_game/cubits/pronunciation_game_cubit.dart';
import 'package:liqaa_app/features/pronunciation_game/cubits/pronunciation_game_state.dart';
import 'package:record/record.dart';

class _InjectableFakeBackend implements RecorderBackend {
  bool failNextStart = false;
  bool failNextStop = false;
  bool corruptNextWav = false;
  bool wedgeNativeActive = false;
  int disposeCount = 0;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;

  bool _recording = false;
  String? _path;
  final AudioPreprocessor _prep = const AudioPreprocessor();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isRecording() async => _recording || wedgeNativeActive;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCount++;
    if (failNextStart) {
      failNextStart = false;
      throw StateError('Simulated native AudioRecord start failure');
    }
    _recording = true;
    _path = path;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    _recording = false;
    if (failNextStop) {
      failNextStop = false;
      throw StateError('Simulated native AudioRecord stop hang/failure');
    }
    if (_path != null) {
      if (corruptNextWav) {
        corruptNextWav = false;
        File(_path!).writeAsBytesSync(Uint8List.fromList([1, 2, 3, 4]));
      } else {
        // Generate realistic 16kHz PCM16 speech-envelope WAV (silence + burst + silence)
        // so frame-floor SNR estimation accurately sees a non-stationary speech burst (> 20 dB SNR).
        final samples = Float32List(12800);
        for (int i = 2400; i < 10400; i++) {
          samples[i] = 0.25 * math.sin(2 * math.pi * 400 * i / 16000.0);
        }
        File(
          _path!,
        ).writeAsBytesSync(_prep.float32ToWav(samples, sampleRate: 16000));
      }
    }
    return _path;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    _recording = false;
    wedgeNativeActive = false;
  }

  @override
  Future<double> getAmplitudeDbfs() async => -18.0;

  @override
  Future<void> dispose() async {
    disposeCount++;
    _recording = false;
  }
}

class _CountingVadEngine extends SileroVadEngine {
  int callCount = 0;
  bool nextSpeechDetected = true;

  @override
  bool get isNativeAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  VadAnalysisResult analyze(Float32List samples, {int sampleRate = 16000}) {
    callCount++;
    if (!nextSpeechDetected) {
      return const VadAnalysisResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        speechProbabilities: [],
        isNativeModel: true,
      );
    }
    return VadAnalysisResult(
      speechDetected: true,
      speechStartMs: 0,
      speechEndMs: (samples.length * 1000 / sampleRate).round(),
      speechProbabilities: const [0.9],
      trimmedSamples: samples,
      segments: [
        VadSegment(
          startMs: 0,
          endMs: 500,
          confidence: 0.9,
          rms: 0.15,
          sampleCount: samples.length,
        ),
      ],
      isNativeModel: true,
    );
  }
}

class _CountingDenoiserEngine extends RnnoiseDenoiserEngine {
  int callCount = 0;

  @override
  bool get isNativeAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  DenoiseResult process(Float32List inputSamples, {int sampleRate = 16000}) {
    callCount++;
    return DenoiseResult(
      processedSamples: Float32List.fromList(inputSamples),
      sampleRate: sampleRate,
      rmsBefore: 0.1,
      rmsAfter: 0.1,
      peakBefore: 0.3,
      peakAfter: 0.3,
      snrBeforeDb: 12.0,
      snrAfterDb: 16.0,
      snrImprovementDb: 4.0,
      wasSuppressionApplied: true,
      isNeuralModel: true,
    );
  }
}

class _CountingPhonemeEngine extends PhonemeRecognitionEngine {
  int callCount = 0;
  List<PhonemeToken> nextTokens = const [
    PhonemeToken(
      symbol: 'k',
      arabicSymbol: 'ك',
      tokenId: 10,
      confidence: 0.9,
      acousticMargin: 0.7,
      startFrame: 0,
      endFrame: 2,
      startMs: 0,
      endMs: 40,
      isAccurate: true,
      isTimestampEstimated: false,
    ),
    PhonemeToken(
      symbol: 'uː',
      arabicSymbol: 'و',
      tokenId: 11,
      confidence: 0.9,
      acousticMargin: 0.7,
      startFrame: 3,
      endFrame: 5,
      startMs: 40,
      endMs: 90,
      isAccurate: true,
      isTimestampEstimated: false,
    ),
    PhonemeToken(
      symbol: 'r',
      arabicSymbol: 'ر',
      tokenId: 12,
      confidence: 0.9,
      acousticMargin: 0.7,
      startFrame: 6,
      endFrame: 8,
      startMs: 90,
      endMs: 140,
      isAccurate: true,
      isTimestampEstimated: false,
    ),
    PhonemeToken(
      symbol: 'a',
      arabicSymbol: 'ة',
      tokenId: 13,
      confidence: 0.9,
      acousticMargin: 0.7,
      startFrame: 9,
      endFrame: 12,
      startMs: 140,
      endMs: 200,
      isAccurate: true,
      isTimestampEstimated: false,
    ),
  ];

  @override
  bool get isNativeAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<PhonemeRecognitionResult> recognizePhonemesDetailed(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    callCount++;
    return PhonemeRecognitionResult(
      tokens: nextTokens,
      latencyMs: 12,
      frameCount: 25,
      audioDurationMs: (samples.length * 1000 / sampleRate).round(),
      averageConfidence: 0.9,
      averageAcousticMargin: 0.7,
      isNativeModel: true,
    );
  }
}

class _CountingSttEngine extends SpeechToTextEngine {
  int callCount = 0;

  @override
  bool get isNativeAvailable => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<SttResult> transcribe(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    callCount++;
    return const SttResult(
      text: 'اختبار',
      confidence: null,
      latencyMs: 15,
      realTimeFactor: 0.1,
      isModelInference: true,
    );
  }
}

class _MockPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '105+ serialized recording lifecycle stress test with fault injection & recovery',
    () async {
      final tmpDir = Directory.systemTemp.createTempSync('yasser_rec_test_');
      bool permGranted = true;
      final createdBackends = <_InjectableFakeBackend>[];
      final recorder = AudioRecorderService(
        tempDirProvider: () async => tmpDir,
        permissionRequesterOverride: () async => permGranted,
        permissionCheckerOverride: () async => permGranted,
        backendFactory: () {
          final b = _InjectableFakeBackend();
          createdBackends.add(b);
          return b;
        },
      );

      try {
        // 105 repeated cycles mixing normal captures, start failures, stop failures, corrupt WAVs, cancels & wedges
        final seenAttemptIds = <int>{};
        final seenPaths = <String>{};

        for (int i = 0; i < 105; i++) {
          if (i % 15 == 3) {
            // Simulated start failure followed by clean recovery
            createdBackends.last.failNextStart = true;
            await expectLater(
              recorder.startOwnedRecording('game'),
              throwsA(isA<AudioRecordingException>()),
            );
            expect(recorder.isRecording, isFalse);
          } else if (i % 15 == 6) {
            // Simulated stop failure -> auto recreate -> next start succeeds cleanly
            await recorder.startOwnedRecording('game');
            createdBackends.last.failNextStop = true;
            await expectLater(
              recorder.stopOwnedRecording('game'),
              throwsA(isA<AudioRecordingException>()),
            );
            expect(recorder.isRecording, isFalse);
          } else if (i % 15 == 9) {
            // Simulated corrupt 4-byte WAV -> rejected -> recovery
            await recorder.startOwnedRecording('game');
            createdBackends.last.corruptNextWav = true;
            await expectLater(
              recorder.stopOwnedRecording('game'),
              throwsA(isA<AudioRecordingException>()),
            );
          } else if (i % 15 == 12) {
            // Cancel and immediate restart
            await recorder.startOwnedRecording('lab');
            await recorder.cancelOwnedRecording(
              'game',
            ); // Wrong owner MUST NOT cancel 'lab'!
            expect(recorder.isRecording, isTrue);
            await recorder.cancelOwnedRecording('lab');
            expect(recorder.isRecording, isFalse);
          } else {
            // Normal valid capture cycle + concurrency rejection check
            await recorder.startOwnedRecording('game');
            seenAttemptIds.add(recorder.activeAttemptId);
            seenPaths.add(recorder.currentRecordingPath!);
            await expectLater(
              recorder.startOwnedRecording('lab'),
              throwsA(
                isA<AudioRecordingException>().having(
                  (e) => e.kind,
                  'kind',
                  AudioRecordingErrorKind.micBusy,
                ),
              ),
            );
            final bytes = await recorder.stopOwnedRecording('game');
            expect(bytes.length, greaterThan(44));
          }
        }

        expect(seenAttemptIds.length, greaterThan(60));
        expect(seenPaths.length, equals(seenAttemptIds.length));
        expect(recorder.recoveryCount, greaterThan(10));

        // Permission denied -> permission granted recovery
        permGranted = false;
        await expectLater(
          recorder.startOwnedRecording('game'),
          throwsA(
            isA<AudioRecordingException>().having(
              (e) => e.kind,
              'kind',
              AudioRecordingErrorKind.permissionDenied,
            ),
          ),
        );
        permGranted = true;
        await recorder.startOwnedRecording('game');
        final recoveryBytes = await recorder.stopOwnedRecording('game');
        expect(recoveryBytes.length, greaterThan(44));
      } finally {
        await recorder.dispose();
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'Task-specific Lab routing runs exact model invocations (zero 3x redundant Wav2Vec2)',
    () async {
      final vad = _CountingVadEngine();
      final den = _CountingDenoiserEngine();
      final ph = _CountingPhonemeEngine();
      final stt = _CountingSttEngine();
      const prep = AudioPreprocessor();

      final repo = PronunciationRepository(
        preprocessor: prep,
        vadEngine: vad,
        denoiserEngine: den,
        phonemeEngine: ph,
        sttEngine: stt,
      );
      await repo.initialize();

      final cubit = AiLabCubit(repo);
      final rawSamples = Float32List(16000);
      for (int i = 0; i < rawSamples.length; i++) {
        // Speech-like burst + modest noise so snr < 14 dB exercises conditional GTCRN when enabled
        rawSamples[i] = 0.25 * math.sin(2 * math.pi * 320 * i / 16000.0);
      }
      final wav = prep.float32ToWav(rawSamples, sampleRate: 16000);

      // 1. recorderOnly -> ZERO neural calls
      await cubit.runTaskOnWavBytes(wav, mode: LabTaskMode.recorderOnly);
      expect(
        [vad.callCount, den.callCount, ph.callCount, stt.callCount],
        [0, 0, 0, 0],
      );

      // 2. vadOnly -> 1 VAD ONLY
      await cubit.runTaskOnWavBytes(wav, mode: LabTaskMode.vadOnly);
      expect(
        [vad.callCount, den.callCount, ph.callCount, stt.callCount],
        [1, 0, 0, 0],
      );

      // 3. speechToText -> 1 Whisper, ZERO Wav2Vec2
      await cubit.runTaskOnWavBytes(wav, mode: LabTaskMode.speechToText);
      expect(ph.callCount, 0);
      expect(stt.callCount, 1);

      // 4. freePhonemeRecognition -> 1 Wav2Vec2, ZERO Whisper
      await cubit.runTaskOnWavBytes(
        wav,
        mode: LabTaskMode.freePhonemeRecognition,
      );
      expect(ph.callCount, 1);
      expect(stt.callCount, 1); // unchanged

      // 5. pronunciationAssessment -> +1 Wav2Vec2, ZERO Whisper
      const word = VocabularyWord(
        id: 'word_kora',
        wordArabic: 'كورة',
        wordTransliteration: 'Koora',
        meaningEn: 'Ball',
        targetPhoneme: 'ك',
        targetPhonemeIpa: 'k',
        phonemeCategory: 'Plosive',
        difficultyLevel: 1,
        expectedPhonemes: ['k', 'uː', 'r', 'a'],
        expectedArabicPhonemes: ['ك', 'و', 'ر', 'ة'],
        yasserTip: 'tip',
        commonChildErrors: [],
      );
      await cubit.runTaskOnWavBytes(
        wav,
        mode: LabTaskMode.pronunciationAssessment,
        wordOverride: word,
      );
      expect(ph.callCount, 2);
      expect(stt.callCount, 1); // still 1 (unchanged)

      // 6. fullDiagnostics -> +1 Wav2Vec2, +1 Whisper (NEVER 3x Wav2Vec2)
      await cubit.runTaskOnWavBytes(
        wav,
        mode: LabTaskMode.fullDiagnostics,
        wordOverride: word,
      );
      expect(ph.callCount, 3);
      expect(stt.callCount, 2);

      // 7. Empty audio -> ZERO neural model calls
      await cubit.runTaskOnWavBytes(
        Uint8List(0),
        mode: LabTaskMode.fullDiagnostics,
      );
      expect(ph.callCount, 3);
      expect(stt.callCount, 2);

      await cubit.close();
    },
  );

  test(
    'Picture naming game recovers after failed/silent attempts & ignores inconclusive fails in progress',
    () async {
      final tmpDir = Directory.systemTemp.createTempSync('yasser_game_rec_');
      final backends = <_InjectableFakeBackend>[];
      final firstBackend = _InjectableFakeBackend();
      bool usedFirst = false;
      final recorder = AudioRecorderService(
        tempDirProvider: () async => tmpDir,
        permissionRequesterOverride: () async => true,
        permissionCheckerOverride: () async => true,
        backendFactory: () {
          final b = usedFirst ? _InjectableFakeBackend() : firstBackend;
          usedFirst = true;
          backends.add(b);
          return b;
        },
      );
      final vad = _CountingVadEngine();
      final ph = _CountingPhonemeEngine();
      final repo = PronunciationRepository(
        recorder: recorder,
        vadEngine: vad,
        denoiserEngine: _CountingDenoiserEngine(),
        phonemeEngine: ph,
        sttEngine: _CountingSttEngine(),
      );
      final coordinator = YasserAudioCoordinator(
        enablePlatformAudio: false,
        observeAppLifecycle: false,
      );
      int persistedProgressCount = 0;
      final mockPlayer = _MockPlayer();
      when(
        () => mockPlayer.onDurationChanged,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.onPositionChanged,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockPlayer.onPlayerStateChanged,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.stop()).thenAnswer((_) async {});
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
      final cubit = PronunciationGameCubit(
        repo,
        audioPlayer: mockPlayer,
        audioCoordinator: coordinator,
        onAttemptEvaluated: (_, _) async {
          persistedProgressCount++;
        },
      );

      try {
        await cubit.initializeGame();
        expect(cubit.state.words, isNotEmpty);

        // Attempt 1: Native failure on start -> cleanly recoverable Error state
        firstBackend.failNextStart = true;
        await cubit.startListening();
        expect(cubit.state.status, GameStatus.error);
        expect(cubit.state.attemptsCount, 0);

        // Attempt 2: Undetected VAD silence -> supportiveHint, MUST NOT count against child progress
        vad.nextSpeechDetected = false;
        await cubit.startListening();
        expect(cubit.state.isListening, isTrue);
        await cubit.stopListeningAndEvaluate();
        expect(cubit.state.status, GameStatus.supportiveHint);
        expect(cubit.state.attemptsCount, 0);
        expect(persistedProgressCount, 0);

        // Attempt 3: Clear valid speech on same word -> succeeds cleanly!
        final w1 = cubit.state.currentWord!;
        ph.nextTokens = List.generate(w1.expectedPhonemes.length, (idx) {
          return PhonemeToken(
            symbol: w1.expectedPhonemes[idx],
            arabicSymbol: idx < w1.expectedArabicPhonemes.length
                ? w1.expectedArabicPhonemes[idx]
                : w1.expectedPhonemes[idx],
            tokenId: 10 + idx,
            confidence: 0.92,
            acousticMargin: 0.75,
            startFrame: idx * 3,
            endFrame: idx * 3 + 2,
            startMs: idx * 60,
            endMs: (idx + 1) * 60,
            isAccurate: true,
            isTimestampEstimated: false,
          );
        });
        vad.nextSpeechDetected = true;
        await cubit.startListening();
        expect(cubit.state.isListening, isTrue);
        await cubit.stopListeningAndEvaluate();
        expect(cubit.state.status, GameStatus.successCelebration);
        expect(cubit.state.attemptsCount, 1);
        expect(persistedProgressCount, 1);

        // Attempt 4: Switch word cards (بطة/سمكة) & repeat -> succeeds again!
        cubit.nextWord();
        final w2 = cubit.state.currentWord!;
        ph.nextTokens = List.generate(w2.expectedPhonemes.length, (idx) {
          return PhonemeToken(
            symbol: w2.expectedPhonemes[idx],
            arabicSymbol: idx < w2.expectedArabicPhonemes.length
                ? w2.expectedArabicPhonemes[idx]
                : w2.expectedPhonemes[idx],
            tokenId: 20 + idx,
            confidence: 0.92,
            acousticMargin: 0.75,
            startFrame: idx * 3,
            endFrame: idx * 3 + 2,
            startMs: idx * 60,
            endMs: (idx + 1) * 60,
            isAccurate: true,
            isTimestampEstimated: false,
          );
        });
        await cubit.startListening();
        await cubit.stopListeningAndEvaluate();
        expect(cubit.state.status, GameStatus.successCelebration);
        expect(cubit.state.attemptsCount, 2);
        expect(persistedProgressCount, 2);
      } finally {
        await cubit.close();
        await coordinator.dispose();
        await recorder.dispose();
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      }
    },
  );
}
