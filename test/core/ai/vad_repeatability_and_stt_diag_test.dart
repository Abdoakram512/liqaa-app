// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/ai_inference_worker.dart';
import 'package:liqaa_app/core/ai/audio_preprocessor.dart';
import 'package:liqaa_app/core/ai/models/lab_task_mode.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/ai/phoneme_recognition_engine.dart';
import 'package:liqaa_app/core/ai/pronunciation_evaluator.dart';
import 'package:liqaa_app/core/ai/pronunciation_repository.dart';
import 'package:liqaa_app/core/ai/rnnoise_denoiser_engine.dart';
import 'package:liqaa_app/core/ai/silero_vad_engine.dart';
import 'package:liqaa_app/core/ai/speech_to_text_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const preprocessor = AudioPreprocessor();

  late SileroVadEngine vadEngine;
  late RnnoiseDenoiserEngine denoiserEngine;
  late PhonemeRecognitionEngine phonemeEngine;
  late SpeechToTextEngine sttEngine;
  late PronunciationRepository repo;

  setUpAll(() async {
    vadEngine = SileroVadEngine(
      modelPathOverride: 'assets/ai_models/silero/silero_vad.onnx',
    );
    denoiserEngine = RnnoiseDenoiserEngine(
      preprocessor: preprocessor,
      modelPathOverride: 'assets/ai_models/gtcrn/gtcrn_simple.onnx',
    );
    phonemeEngine = PhonemeRecognitionEngine(
      preprocessor: preprocessor,
      modelPathOverride: 'assets/ai_models/wav2vec2_espeak/model_q4f16.onnx',
      vocabPathOverride: 'assets/ai_models/wav2vec2_espeak/vocab.json',
    );
    sttEngine = SpeechToTextEngine(
      preprocessor: preprocessor,
      encoderPathOverride:
          'assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx',
      decoderPathOverride:
          'assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx',
      tokensPathOverride: 'assets/ai_models/whisper_tiny/tiny-tokens.txt',
    );
    await vadEngine.initialize();
    await denoiserEngine.initialize();
    await phonemeEngine.initialize();
    await sttEngine.initialize();
    repo = PronunciationRepository(
      preprocessor: preprocessor,
      vadEngine: vadEngine,
      denoiserEngine: denoiserEngine,
      phonemeEngine: phonemeEngine,
      sttEngine: sttEngine,
      evaluator: const PronunciationEvaluator(),
    );
  });

  tearDownAll(() {
    vadEngine.dispose();
    denoiserEngine.dispose();
    phonemeEngine.dispose();
    sttEngine.dispose();
  });

  test(
    '50 consecutive real Silero VAD iterations match fresh instances cleanly',
    () async {
      final files = [
        'assets/audio_samples/human_arabic_adult.wav',
        'assets/audio_samples/silence.wav',
        'assets/audio_samples/white_noise.wav',
        'assets/audio_samples/noisy_speech.wav',
        'assets/audio_samples/word_madrasa.wav',
      ];
      final loaded = files
          .map(
            (p) =>
                preprocessor.preprocessWav(File(p).readAsBytesSync()).samples,
          )
          .toList();

      final freshRef = <bool>[];
      final freshStarts = <int>[];
      for (final s in loaded) {
        final freshVad = SileroVadEngine(
          modelPathOverride: 'assets/ai_models/silero/silero_vad.onnx',
        );
        await freshVad.initialize();
        final r = freshVad.analyze(s);
        freshRef.add(r.speechDetected);
        freshStarts.add(r.speechStartMs);
        freshVad.dispose();
      }

      int mismatches = 0;
      for (int iter = 0; iter < 50; iter++) {
        final idx = iter % loaded.length;
        final res = vadEngine.analyze(loaded[idx]);
        if (res.speechDetected != freshRef[idx] ||
            res.speechStartMs != freshStarts[idx]) {
          mismatches++;
        }
        expect(res.errorMessage, isNull);
      }
      print('[50x VAD Check] freshRef=$freshRef mismatches=$mismatches');
      expect(mismatches, 0);
    },
  );

  test(
    'Task-routed latencies, off-UI worker execution & Whisper max_tokens_per_second=24 diag',
    () async {
      final adultBytes = File(
        'assets/audio_samples/human_arabic_adult.wav',
      ).readAsBytesSync();
      final madrasaBytes = File(
        'assets/audio_samples/word_madrasa.wav',
      ).readAsBytesSync();
      const koraWord = VocabularyWord(
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

      // Measure single-task modes (zero redundant calls)
      final freeCold = await repo.runTaskAnalysis(
        rawAudioBytes: adultBytes,
        mode: LabTaskMode.freePhonemeRecognition,
      );
      final freeWarm = await repo.runTaskAnalysis(
        rawAudioBytes: madrasaBytes,
        mode: LabTaskMode.freePhonemeRecognition,
      );
      final gameWarm = await repo.runTaskAnalysis(
        rawAudioBytes: madrasaBytes,
        mode: LabTaskMode.pronunciationAssessment,
        targetWord: koraWord,
      );
      final sttWarm = await repo.runTaskAnalysis(
        rawAudioBytes: adultBytes,
        mode: LabTaskMode.speechToText,
      );
      final fullWarm = await repo.runTaskAnalysis(
        rawAudioBytes: adultBytes,
        mode: LabTaskMode.fullDiagnostics,
        targetWord: koraWord,
      );

      print(
        '[Post-Fix Latency] freeCold=${freeCold.telemetry.totalLatencyMs}ms calls=${freeCold.telemetry.invocations.toJson()} | '
        'freeWarm=${freeWarm.telemetry.totalLatencyMs}ms calls=${freeWarm.telemetry.invocations.toJson()} | '
        'gameWarm=${gameWarm.telemetry.totalLatencyMs}ms calls=${gameWarm.telemetry.invocations.toJson()} | '
        'sttWarm=${sttWarm.telemetry.totalLatencyMs}ms calls=${sttWarm.telemetry.invocations.toJson()} | '
        'fullWarm=${fullWarm.telemetry.totalLatencyMs}ms calls=${fullWarm.telemetry.invocations.toJson()}',
      );

      expect(freeWarm.telemetry.invocations.wav2vec2, 1);
      expect(freeWarm.telemetry.invocations.whisper, 0);
      expect(gameWarm.telemetry.invocations.wav2vec2, 1);
      expect(gameWarm.telemetry.invocations.whisper, 0);
      expect(sttWarm.telemetry.invocations.whisper, 1);
      expect(sttWarm.telemetry.invocations.wav2vec2, 0);
      expect(fullWarm.telemetry.invocations.wav2vec2, 1);

      // Verify persistent background isolate worker executes real ONNX cleanly off UI isolate
      final worker = AiInferenceWorker();
      final ok = await worker.initialize(
        wav2vecModelPath: 'assets/ai_models/wav2vec2_espeak/model_q4f16.onnx',
        wav2vecVocabPath: 'assets/ai_models/wav2vec2_espeak/vocab.json',
        whisperEncoderPath:
            'assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx',
        whisperDecoderPath:
            'assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx',
        whisperTokensPath: 'assets/ai_models/whisper_tiny/tiny-tokens.txt',
      );
      expect(ok, isTrue);
      final adultSamples = preprocessor.preprocessWav(adultBytes).samples;
      final swW = Stopwatch()..start();
      final workerPh = await worker.recognizePhonemes(adultSamples);
      final wPhMs = swW.elapsedMilliseconds;
      swW
        ..reset()
        ..start();
      final workerStt = await worker.transcribe(adultSamples);
      final wSttMs = swW.elapsedMilliseconds;
      await worker.dispose();
      print(
        '[Background Isolate Worker] wPh=${wPhMs}ms tokens=${workerPh.tokens.length} | wStt=${wSttMs}ms text="${workerStt.text}"',
      );
      expect(workerPh.isNativeModel, isTrue);
      expect(workerPh.tokens, isNotEmpty);
      expect(workerStt.isModelInference, isTrue);

      // Inspect post-fix Whisper Tiny (max_tokens_per_second=24) on adult & pediatric clips across Original/VAD-trimmed/Denoised
      final manifestFile = File('benchmarks/audio/manifest.jsonl');
      if (manifestFile.existsSync()) {
        final lines = manifestFile
            .readAsLinesSync()
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final adultSamplesList = <Map<String, dynamic>>[];
        final childSamplesList = <Map<String, dynamic>>[];
        final noiseSamplesList = <Map<String, dynamic>>[];
        for (final line in lines) {
          final m = jsonDecode(line) as Map<String, dynamic>;
          if (!File(m['file_path'] as String).existsSync()) continue;
          if (m['category'] == 'adult_arabic_speech' &&
              adultSamplesList.length < 10) {
            adultSamplesList.add(m);
          } else if (m['category'] == 'correct_pediatric' &&
              childSamplesList.length < 10) {
            childSamplesList.add(m);
          } else if ((m['category'] == 'silence_near_silence' ||
                  m['category'] == 'environmental_noise') &&
              noiseSamplesList.length < 10) {
            noiseSamplesList.add(m);
          }
        }
        final sttDump = <Map<String, dynamic>>[];
        for (final row in [
          ...adultSamplesList,
          ...childSamplesList,
          ...noiseSamplesList,
        ]) {
          final raw = File(row['file_path'] as String).readAsBytesSync();
          final prep = preprocessor.preprocessWav(raw);
          final orig = await sttEngine.transcribe(prep.samples);
          final vad = vadEngine.analyze(prep.samples);
          final trimmed = (vad.speechDetected && vad.trimmedSamples != null)
              ? vad.trimmedSamples!
              : prep.samples;
          final vadOnly = await sttEngine.transcribe(trimmed);
          final den = denoiserEngine.process(trimmed);
          final denSamples = den.processedSamples.isNotEmpty
              ? den.processedSamples
              : trimmed;
          final denRes = await sttEngine.transcribe(denSamples);
          sttDump.add({
            'id': row['sample_id'],
            'cat': row['category'],
            'gt': row['actual_spoken_word'] ?? '',
            'orig': orig.text,
            'trim': vadOnly.text,
            'den': denRes.text,
            'durMs': (prep.samples.length * 1000 / 16000).round(),
          });
        }
        print('[STT_DIAG_JSON] ${jsonEncode(sttDump)}');
      }
    },
  );
}
