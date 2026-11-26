import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/audio_preprocessor.dart';
import 'package:liqaa_app/core/ai/models/phoneme_token.dart';
import 'package:liqaa_app/core/ai/models/pronunciation_assessment.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/ai/phoneme_recognition_engine.dart';
import 'package:liqaa_app/core/ai/pronunciation_evaluator.dart';
import 'package:liqaa_app/core/ai/rnnoise_denoiser_engine.dart';
import 'package:liqaa_app/core/ai/silero_vad_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const preprocessor = AudioPreprocessor();
  final vadEngine = SileroVadEngine();
  final denoiser = RnnoiseDenoiserEngine();
  final phonemeEngine = PhonemeRecognitionEngine();
  const evaluator = PronunciationEvaluator();

  final koraWord = const VocabularyWord(
    id: 'word_kora',
    wordArabic: 'كورة',
    wordTransliteration: 'Koora',
    meaningEn: 'Ball',
    targetPhoneme: 'ك',
    targetPhonemeIpa: 'k',
    phonemeCategory: 'صوت طبقي انفجاري (Velar Plosive)',
    difficultyLevel: 1,
    expectedPhonemes: ['k', 'uː', 'r', 'a'],
    expectedArabicPhonemes: ['ك', 'و', 'ر', 'ة'],
    yasserTip: 'افتح بؤك وخلّي صوت الكاف يطلع من ورا: كـ كـ كورة!',
    commonChildErrors: [
      ChildErrorRule(
        pronouncedWord: 'تورة',
        errorType: 'substitution',
        substitutedPhoneme: 'ت',
        targetPhoneme: 'ك',
        clinicalName: 'Fronting (إبدال أمامي)',
        feedbackAr:
            'شاطر جداً! بس بدّلنا صوت الـ ك بالـ ت.. يلا نطلع الكاف: كـ كورة!',
        yasserPose: 'thinking',
      ),
    ],
  );

  final samakaWord = const VocabularyWord(
    id: 'word_samaka',
    wordArabic: 'سمكة',
    wordTransliteration: 'Samaka',
    meaningEn: 'Fish',
    targetPhoneme: 'س',
    targetPhonemeIpa: 's',
    phonemeCategory: 'صوت لثوي احتكاكي مهموس',
    difficultyLevel: 1,
    expectedPhonemes: ['s', 'a', 'm', 'a', 'k', 'a'],
    expectedArabicPhonemes: ['س', 'م', 'ك', 'ة'],
    yasserTip: 'اقفل سنانك بالراحة وطلع هواء زي الصفارة',
    commonChildErrors: [
      ChildErrorRule(
        pronouncedWord: 'ثمكة',
        errorType: 'substitution',
        substitutedPhoneme: 'ث',
        targetPhoneme: 'س',
        clinicalName: 'Interdental Lisp (لدغة بين الأسنان)',
        feedbackAr:
            'ممتاز! بس لسانك طلع برة سنانك.. خلّي لسانك جوة واصفر: سسسـ سمكة!',
        yasserPose: 'thinking',
      ),
    ],
  );

  final arnabWord = const VocabularyWord(
    id: 'word_arnab',
    wordArabic: 'أرنب',
    wordTransliteration: 'Arnab',
    meaningEn: 'Rabbit',
    targetPhoneme: 'ر',
    targetPhonemeIpa: 'r',
    phonemeCategory: 'صوت لثوي تكراري',
    difficultyLevel: 2,
    expectedPhonemes: ['ʔ', 'a', 'r', 'n', 'a', 'b'],
    expectedArabicPhonemes: ['أ', 'ر', 'ن', 'ب'],
    yasserTip: 'خلّي طرف لسانك يرفرف',
    commonChildErrors: [
      ChildErrorRule(
        pronouncedWord: 'أنلب',
        errorType: 'substitution',
        substitutedPhoneme: 'ل',
        targetPhoneme: 'ر',
        clinicalName: 'Lateralization (لدغة الراء إلى لام)',
        feedbackAr:
            'برافو يا بطل! بدّلنا الـ ر بالـ ل.. يلا نخلّي لساننا يهتز: أرررنب!',
        yasserPose: 'thinking',
      ),
    ],
  );

  setUpAll(() async {
    await vadEngine.initialize();
    await denoiser.initialize();
    await phonemeEngine.initialize();
  });

  group('Real Pipeline & Negative Testing (Safety Verification)', () {
    test('1. Silence WAV fixture MUST NOT pass and MUST award 0 stars', () {
      final file = File('assets/audio_samples/silence.wav');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      // Skip 44-byte WAV header
      final pcmBytes = Uint8List.sublistView(bytes, 44);
      final samples = preprocessor.pcm16ToFloat32(pcmBytes);

      // VAD check
      final vad = vadEngine.analyze(samples);
      expect(vad.speechDetected, isFalse);
      expect(vad.trimmedSamples, isNull);

      // Evaluator check on silence
      final assessment = evaluator.evaluate(
        word: koraWord,
        recognizedTokens: const [],
      );

      expect(assessment.passed, isFalse);
      expect(assessment.stars, equals(0));
      expect(assessment.overallScore, equals(0.0));
      expect(assessment.errorType, equals(AssessmentErrorType.noSpeech));
      expect(assessment.yasserFeedbackMessage, contains('مش سامع صوتك'));
    });

    test('2. Stationary White Noise MUST NOT pass evaluation', () {
      final file = File('assets/audio_samples/white_noise.wav');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final pcmBytes = Uint8List.sublistView(bytes, 44);
      final samples = preprocessor.pcm16ToFloat32(pcmBytes);

      final rms = preprocessor.calculateRms(samples);
      expect(rms, lessThan(0.05));

      final assessment = evaluator.evaluate(
        word: koraWord,
        recognizedTokens: const [],
      );

      expect(assessment.passed, isFalse);
      expect(assessment.stars, equals(0));
    });

    test(
      '3. Blind Fronting Substitution (كورة -> تورة) triggers Fronting rule and fails',
      () {
        // Blind recognition of "تورة"
        final tokens = phonemeEngine.textToPhonemes('تورة');
        expect(tokens.first.arabicSymbol, equals('ت'));
        expect(tokens.first.symbol, equals('t'));

        // Evaluate against "كورة"
        final assessment = evaluator.evaluate(
          word: koraWord,
          recognizedTokens: tokens,
        );

        expect(assessment.passed, isFalse);
        expect(assessment.stars, equals(1));
        expect(assessment.errorType, equals(AssessmentErrorType.substitution));
        expect(assessment.clinicalErrorName, contains('Fronting'));
        expect(assessment.substitutedPhoneme, equals('ت'));
        expect(assessment.targetPhoneme, equals('ك'));
        expect(assessment.overallScore, lessThanOrEqualTo(65.0));
      },
    );

    test(
      '4. Blind Interdental Lisp Substitution (سمكة -> ثمكة) triggers Lisp rule and fails',
      () {
        final tokens = phonemeEngine.textToPhonemes('ثمكة');
        expect(tokens.first.arabicSymbol, equals('ث'));

        final assessment = evaluator.evaluate(
          word: samakaWord,
          recognizedTokens: tokens,
        );

        expect(assessment.passed, isFalse);
        expect(assessment.stars, equals(1));
        expect(assessment.errorType, equals(AssessmentErrorType.substitution));
        expect(assessment.clinicalErrorName, contains('Interdental Lisp'));
        expect(assessment.substitutedPhoneme, equals('ث'));
        expect(assessment.targetPhoneme, equals('س'));
      },
    );

    test(
      '5. Blind Lateralization Substitution (أرنب -> أنلب) triggers Lateralization rule and fails',
      () {
        final tokens = phonemeEngine.textToPhonemes('أنلب');

        final assessment = evaluator.evaluate(
          word: arnabWord,
          recognizedTokens: tokens,
        );

        expect(assessment.passed, isFalse);
        expect(assessment.stars, equals(1));
        expect(assessment.errorType, equals(AssessmentErrorType.substitution));
        expect(assessment.clinicalErrorName, contains('Lateralization'));
      },
    );

    test(
      '6. Completely unrelated word (مدرسة against كورة) fails with low score',
      () {
        final tokens = phonemeEngine.textToPhonemes('مدرسة');

        final assessment = evaluator.evaluate(
          word: koraWord,
          recognizedTokens: tokens,
        );

        expect(assessment.passed, isFalse);
        expect(assessment.overallScore, lessThan(70.0));
        expect(assessment.stars, equals(1));
      },
    );

    test(
      '7. Clean, accurate pronunciation (كورة against كورة) passes with 3 stars',
      () {
        final tokens = phonemeEngine.textToPhonemes(
          'كورة',
          baseConfidence: 0.95,
        );

        final assessment = evaluator.evaluate(
          word: koraWord,
          recognizedTokens: tokens,
        );

        expect(assessment.passed, isTrue);
        expect(assessment.stars, equals(3));
        expect(assessment.errorType, equals(AssessmentErrorType.correct));
        expect(assessment.overallScore, greaterThanOrEqualTo(90.0));
        expect(assessment.yasserPose, equals('celebrating'));
      },
    );

    test(
      '8. Wagner-Fischer DP Alignment correctly aligns phoneme insertions without desync',
      () {
        // Child repeats initial stop consonant [k, k, uː, r, a] (stuttering)
        final tokens = [
          const PhonemeToken(symbol: 'k', arabicSymbol: 'ك', confidence: 0.92),
          const PhonemeToken(symbol: 'k', arabicSymbol: 'ك', confidence: 0.90),
          const PhonemeToken(symbol: 'uː', arabicSymbol: 'و', confidence: 0.93),
          const PhonemeToken(symbol: 'r', arabicSymbol: 'ر', confidence: 0.89),
          const PhonemeToken(symbol: 'a', arabicSymbol: 'ة', confidence: 0.91),
        ];

        final assessment = evaluator.evaluate(
          word: koraWord,
          recognizedTokens: tokens,
        );

        // The DP alignment should match the rest of the sequence without cascading desync!
        expect(
          assessment.alignments.any(
            (a) => a.isMatch && a.expectedPhoneme == 'uː',
          ),
          isTrue,
        );
        expect(
          assessment.alignments.any(
            (a) => a.isMatch && a.expectedPhoneme == 'r',
          ),
          isTrue,
        );
        expect(
          assessment.alignments.any(
            (a) => a.isMatch && a.expectedPhoneme == 'a',
          ),
          isTrue,
        );
      },
    );
  });
}
