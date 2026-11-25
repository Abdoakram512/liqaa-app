import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:liqaa_app/core/ai/audio_preprocessor.dart';
import 'package:liqaa_app/core/ai/models/phoneme_token.dart';
import 'package:liqaa_app/core/ai/models/pronunciation_assessment.dart';
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
  const evaluator = PronunciationEvaluator();

  late SileroVadEngine vadEngine;
  late RnnoiseDenoiserEngine denoiserEngine;
  late PhonemeRecognitionEngine phonemeEngine;
  late SpeechToTextEngine sttEngine;
  late PronunciationRepository repo;

  const koraWord = VocabularyWord(
    id: 'word_kora',
    wordArabic: 'كورة',
    wordTransliteration: 'Koora',
    meaningEn: 'Ball',
    targetPhoneme: 'ك',
    targetPhonemeIpa: 'k',
    phonemeCategory: 'Velar Plosive',
    difficultyLevel: 1,
    expectedPhonemes: ['k', 'uː', 'r', 'a'],
    expectedArabicPhonemes: ['ك', 'و', 'ر', 'ة'],
    yasserTip: 'كـ كـ كورة',
    commonChildErrors: [
      ChildErrorRule(
        pronouncedWord: 'تورة',
        errorType: 'substitution',
        substitutedPhoneme: 'ت',
        targetPhoneme: 'ك',
        clinicalName: 'Fronting (إبدال أمامي)',
        feedbackAr: 'بدّلنا صوت الـ ك بصوت الـ ت.. يلا نطلع الكاف: كـ كورة!',
        yasserPose: 'thinking',
      ),
    ],
  );

  const arnabWord = VocabularyWord(
    id: 'word_arnab',
    wordArabic: 'أرنب',
    wordTransliteration: 'Arnab',
    meaningEn: 'Rabbit',
    targetPhoneme: 'ر',
    targetPhonemeIpa: 'r',
    phonemeCategory: 'Alveolar Trill',
    difficultyLevel: 2,
    expectedPhonemes: ['ʔ', 'r', 'n', 'b'],
    expectedArabicPhonemes: ['أ', 'ر', 'ن', 'ب'],
    yasserTip: 'أرررنب',
    commonChildErrors: [
      ChildErrorRule(
        pronouncedWord: 'أنلب',
        errorType: 'substitution',
        substitutedPhoneme: 'ل',
        targetPhoneme: 'ر',
        clinicalName: 'Lateralization (لدغة الراء إلى لام)',
        feedbackAr: 'بدّلنا صوت الـ ر بالـ ل.. يلا نخلّي لساننا يهتز: أرررنب!',
        yasserPose: 'thinking',
      ),
    ],
  );

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
      encoderPathOverride: 'assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx',
      decoderPathOverride: 'assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx',
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
      evaluator: evaluator,
      sttEngine: sttEngine,
    );
  });

  tearDownAll(() {
    vadEngine.dispose();
    denoiserEngine.dispose();
    phonemeEngine.dispose();
    sttEngine.dispose();
  });

  group('Real ONNX End-to-End Verification', () {
    test('All 4 real ONNX engines initialize natively on host/runtime', () {
      expect(vadEngine.isNativeAvailable, isTrue, reason: vadEngine.lastError);
      expect(denoiserEngine.isNativeAvailable, isTrue, reason: denoiserEngine.lastError);
      expect(phonemeEngine.isNativeAvailable, isTrue, reason: phonemeEngine.lastError);
      expect(sttEngine.isNativeAvailable, isTrue, reason: sttEngine.lastError);
    });

    test('Silero VAD rejects silence and white noise, accepts full human speech & prompts', () {
      final silence = preprocessor.preprocessWav(File('assets/audio_samples/silence.wav').readAsBytesSync());
      final vadSilence = vadEngine.analyze(silence.samples);
      expect(vadSilence.isNativeModel, isTrue);
      expect(vadSilence.speechDetected, isFalse);

      final white = preprocessor.preprocessWav(File('assets/audio_samples/white_noise.wav').readAsBytesSync());
      final vadWhite = vadEngine.analyze(white.samples);
      expect(vadWhite.isNativeModel, isTrue);
      expect(vadWhite.speechDetected, isFalse);

      final promptKora = preprocessor.preprocessWav(File('assets/pronunciation/prompts/kora.wav').readAsBytesSync());
      final vadKora = vadEngine.analyze(promptKora.samples);
      expect(vadKora.speechDetected, isTrue);
      expect(vadKora.segments, isNotEmpty);
      expect(vadKora.trimmedSamples!.length, greaterThan(4000));

      // Long multi-word human Arabic speech must NOT truncate to trailing single chunk!
      final humanSpeech = preprocessor.preprocessWav(File('assets/audio_samples/human_arabic_adult.wav').readAsBytesSync());
      final vadHuman = vadEngine.analyze(humanSpeech.samples);
      expect(vadHuman.speechDetected, isTrue);
      expect(vadHuman.trimmedSamples!.length, greaterThan(32000));
    });

    test('Lab analysis produces valid playable RIFF/WAVE bytes for trimmed & GTCRN denoised outputs', () {
      final bytes = File('assets/audio_samples/correct_kora.wav').readAsBytesSync();
      final res = repo.analyzeAudioForLab(bytes);

      expect(res.isValidAudio, isTrue);
      expect(res.speechDetected, isTrue);
      expect(res.trimmedAudioBytes, isNotNull);
      expect(res.denoisedAudioBytes, isNotNull);
      expect(res.denoiserFilterType, equals('gtcrn_neural'));

      // Both buffers must parse cleanly as valid RIFF/WAVE files (not headerless PCM)
      final trimmedMeta = preprocessor.parseWavMetadata(res.trimmedAudioBytes!);
      final denoisedMeta = preprocessor.parseWavMetadata(res.denoisedAudioBytes!);
      expect(trimmedMeta.sampleRate, equals(16000));
      expect(denoisedMeta.sampleRate, equals(16000));
      expect(denoisedMeta.dataSize, greaterThan(4000));
    });

    test('Blind Wav2Vec2-eSpeak emits real calibrated IPA on human Arabic speech and empty on silence/noise', () async {
      final silence = preprocessor.preprocessWav(File('assets/audio_samples/silence.wav').readAsBytesSync());
      final sRes = await phonemeEngine.recognizePhonemesDetailed(silence.samples);
      expect(sRes.hasError, isFalse);
      expect(sRes.tokens, isEmpty);

      final human = preprocessor.preprocessWav(File('assets/audio_samples/human_arabic_adult.wav').readAsBytesSync());
      final hRes = await phonemeEngine.recognizePhonemesDetailed(human.samples);
      expect(hRes.hasError, isFalse);
      expect(hRes.isNativeModel, isTrue);
      expect(hRes.tokens.length, greaterThan(10));
      for (final tok in hRes.tokens) {
        expect(tok.isTimestampEstimated, isFalse);
        expect(tok.acousticMargin, isNotNull);
        expect(tok.confidence, inInclusiveRange(0.0, 1.0));
        expect(tok.endMs, greaterThanOrEqualTo(tok.startMs));
      }
      final ipaJoined = hRes.tokens.map((t) => t.symbol).join(' ');
      // Real Arabic speech corpus sample contains Arabic pharyngeals/emphatics/fricatives
      expect(ipaJoined, matches(RegExp(r'[ħʔðθqχʃ]')));
    });

    test('Minimal pairs distinguish correct pronunciation vs fronting/lateralization/unrelated via real inference', () async {
      // 1. Correct "كورة" -> PASS
      final koraBytes = File('assets/audio_samples/correct_kora.wav').readAsBytesSync();
      final koraAssess = await repo.evaluateAudio(rawAudioBytes: koraBytes, targetWord: koraWord);
      expect(koraAssess.passed, isTrue, reason: 'Expected kora to pass: ${koraAssess.recognizedPhonemes.map((t) => t.symbol).toList()} score=${koraAssess.overallScore}');
      expect(koraAssess.errorType, equals(AssessmentErrorType.correct));
      expect(koraAssess.stars, greaterThanOrEqualTo(2));

      // 2. Fronting error "تورة" against target "كورة" -> FAIL with Fronting substitution
      final toraBytes = File('assets/audio_samples/error_tora.wav').readAsBytesSync();
      final toraAssess = await repo.evaluateAudio(rawAudioBytes: toraBytes, targetWord: koraWord);
      expect(toraAssess.passed, isFalse);
      expect(toraAssess.errorType, equals(AssessmentErrorType.substitution));

      // 3. Correct "أرنب" -> PASS
      final arnabBytes = File('assets/audio_samples/correct_arnab.wav').readAsBytesSync();
      final arnabAssess = await repo.evaluateAudio(rawAudioBytes: arnabBytes, targetWord: arnabWord);
      expect(arnabAssess.passed, isTrue, reason: 'Expected arnab to pass: ${arnabAssess.recognizedPhonemes.map((t) => t.symbol).toList()} score=${arnabAssess.overallScore}');

      // 4. Lateralization "أنلب" against target "أرنب" -> FAIL
      final anlabBytes = File('assets/audio_samples/error_anlab.wav').readAsBytesSync();
      final anlabAssess = await repo.evaluateAudio(rawAudioBytes: anlabBytes, targetWord: arnabWord);
      expect(anlabAssess.passed, isFalse);
      expect(anlabAssess.errorType, equals(AssessmentErrorType.substitution));

      // 5. Unrelated word "مدرسة" against target "كورة" -> FAIL
      final madrasaBytes = File('assets/audio_samples/word_madrasa.wav').readAsBytesSync();
      final madrasaAssess = await repo.evaluateAudio(rawAudioBytes: madrasaBytes, targetWord: koraWord);
      expect(madrasaAssess.passed, isFalse);
      expect(madrasaAssess.overallScore, lessThan(45.0));
    });

    test('Robustness on noisy speech & quiet speech after preprocessing', () async {
      final orig = preprocessor.preprocessWav(File('assets/audio_samples/correct_kora.wav').readAsBytesSync());

      // Quiet speech (15% amplitude)
      final quietF32 = Float32List.fromList(orig.samples.map((s) => s * 0.15).toList());
      final quietWav = preprocessor.float32ToWav(quietF32, sampleRate: 16000);
      final quietAssess = await repo.evaluateAudio(rawAudioBytes: quietWav, targetWord: koraWord);
      expect(quietAssess.passed, isTrue);

      // Additive moderate white noise + speech -> GTCRN denoiser + Wav2Vec2 still recognizes kora
      final rng = math.Random(42);
      final noisyF32 = Float32List(orig.samples.length);
      for (int i = 0; i < noisyF32.length; i++) {
        noisyF32[i] = (orig.samples[i] + 0.04 * (rng.nextDouble() * 2 - 1)).clamp(-1.0, 1.0);
      }
      final noisyWav = preprocessor.float32ToWav(noisyF32, sampleRate: 16000);
      final noisyAssess = await repo.evaluateAudio(rawAudioBytes: noisyWav, targetWord: koraWord);
      expect(noisyAssess.errorType.isSystemFailure, isFalse);
      expect(noisyAssess.recognizedPhonemes, isNotEmpty);
    });

    test('Missing model fails honestly with modelInitFailed, never noSpeech or fake score', () async {
      final brokenPhone = PhonemeRecognitionEngine(
        modelPathOverride: 'assets/ai_models/wav2vec2_espeak/missing_model.onnx',
        vocabPathOverride: 'assets/ai_models/wav2vec2_espeak/vocab.json',
      );
      await brokenPhone.initialize();
      expect(brokenPhone.isNativeAvailable, isFalse);

      final brokenRepo = PronunciationRepository(
        vadEngine: vadEngine,
        denoiserEngine: denoiserEngine,
        phonemeEngine: brokenPhone,
      );
      final koraBytes = File('assets/audio_samples/correct_kora.wav').readAsBytesSync();
      final res = await brokenRepo.evaluateAudio(rawAudioBytes: koraBytes, targetWord: koraWord);

      expect(res.passed, isFalse);
      expect(res.errorType, equals(AssessmentErrorType.modelInitFailed));
      expect(res.pipelineStageFailed, equals('PhonemeRecognition'));
      expect(res.diagnosticError, isNotNull);
      brokenPhone.dispose();
    });

    test('Regression: eSpeak central vowel [ʉ] matches uː in kora and quiet padded audio reaches VAD', () async {
      // 1. Direct regression for child pronunciation [k, ʉ, r, aː]
      final koraRounded = evaluator.evaluate(
        word: koraWord,
        recognizedTokens: const [
          PhonemeToken(symbol: 'k', arabicSymbol: 'ك', confidence: 0.72),
          PhonemeToken(symbol: 'ʉ', arabicSymbol: 'و', confidence: 0.65),
          PhonemeToken(symbol: 'r', arabicSymbol: 'ر', confidence: 0.70),
          PhonemeToken(symbol: 'aː', arabicSymbol: 'ا', confidence: 0.75),
        ],
      );
      expect(koraRounded.passed, isTrue);
      expect(koraRounded.errorType, equals(AssessmentErrorType.correct));

      // 2. Quiet padded audio (1.5s silence + soft kora burst -> overall RMS < 0.002, peak > 0.03)
      final orig = preprocessor.preprocessWav(File('assets/audio_samples/correct_kora.wav').readAsBytesSync());
      final padded = Float32List(24000 + orig.samples.length);
      for (int i = 0; i < orig.samples.length; i++) {
        padded[24000 + i] = orig.samples[i] * 0.06;
      }
      final paddedWav = preprocessor.float32ToWav(padded, sampleRate: 16000);
      final paddedRes = await repo.evaluateAudio(rawAudioBytes: paddedWav, targetWord: koraWord);
      expect(paddedRes.errorType, isNot(equals(AssessmentErrorType.noSpeech)));
      final labResult = repo.analyzeAudioForLab(paddedWav);
      expect(labResult.speechDetected, isTrue,
          reason: 'Lab must not reject quiet padded speech that reaches game VAD.');
    });
  });
}
