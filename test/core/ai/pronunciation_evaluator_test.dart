import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/models/phoneme_token.dart';
import 'package:liqaa_app/core/ai/models/pronunciation_assessment.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/ai/pronunciation_evaluator.dart';

void main() {
  const evaluator = PronunciationEvaluator();

  final testWord = VocabularyWord(
    id: 'word_kora',
    wordArabic: 'كورة',
    wordTransliteration: 'Koora',
    meaningEn: 'Ball',
    targetPhoneme: 'ك',
    targetPhonemeIpa: 'k',
    phonemeCategory: 'صوت طبقي انفجاري (Velar Plosive)',
    difficultyLevel: 1,
    expectedPhonemes: const ['k', 'uː', 'r', 'a'],
    expectedArabicPhonemes: const ['ك', 'و', 'ر', 'ة'],
    yasserTip: 'افتح بؤك وخلّي صوت الكاف يطلع من ورا!',
    commonChildErrors: const [
      ChildErrorRule(
        pronouncedWord: 'تورة',
        errorType: 'substitution',
        substitutedPhoneme: 'ت',
        targetPhoneme: 'ك',
        clinicalName: 'Fronting (إبدال أمامي)',
        feedbackAr: 'شاطر جداً! بس بدّلنا صوت الـ ك بالـ ت.. يلا نطلع الكاف: كـ كورة!',
        yasserPose: 'thinking',
      ),
    ],
  );

  group('PronunciationEvaluator Clinical Diagnostic Tests', () {
    test('Accurate pronunciation evaluates to passed and 3 stars', () {
      final recognized = [
        const PhonemeToken(symbol: 'k', arabicSymbol: 'ك', confidence: 0.95),
        const PhonemeToken(symbol: 'uː', arabicSymbol: 'و', confidence: 0.92),
        const PhonemeToken(symbol: 'r', arabicSymbol: 'ر', confidence: 0.90),
        const PhonemeToken(symbol: 'a', arabicSymbol: 'ة', confidence: 0.94),
      ];

      final assessment = evaluator.evaluate(
        word: testWord,
        recognizedTokens: recognized,
      );

      expect(assessment.passed, isTrue);
      expect(assessment.stars, equals(3));
      expect(assessment.errorType, equals(AssessmentErrorType.correct));
      expect(assessment.yasserPose, equals('celebrating'));
      expect(assessment.overallScore, greaterThanOrEqualTo(90.0));
    });

    test('Fronting error (كورة -> تورة) triggers clinical substitution feedback', () {
      final recognized = [
        const PhonemeToken(symbol: 't', arabicSymbol: 'ت', confidence: 0.92),
        const PhonemeToken(symbol: 'uː', arabicSymbol: 'و', confidence: 0.91),
        const PhonemeToken(symbol: 'r', arabicSymbol: 'ر', confidence: 0.88),
        const PhonemeToken(symbol: 'a', arabicSymbol: 'ة', confidence: 0.93),
      ];

      final assessment = evaluator.evaluate(
        word: testWord,
        recognizedTokens: recognized,
      );

      expect(assessment.passed, isFalse);
      expect(assessment.errorType, equals(AssessmentErrorType.substitution));
      expect(assessment.clinicalErrorName, contains('Fronting'));
      expect(assessment.yasserFeedbackMessage, contains('بدّلنا صوت الـ ك'));
      expect(assessment.yasserPose, equals('thinking'));
      expect(assessment.alignments.first.status, equals('substituted'));
    });

    test('Omission error (dropping /r/) triggers deletion classification', () {
      final recognized = [
        const PhonemeToken(symbol: 'k', arabicSymbol: 'ك', confidence: 0.92),
        const PhonemeToken(symbol: 'uː', arabicSymbol: 'و', confidence: 0.90),
        const PhonemeToken(symbol: 'a', arabicSymbol: 'ة', confidence: 0.90),
      ];

      final assessment = evaluator.evaluate(
        word: testWord,
        recognizedTokens: recognized,
      );

      expect(assessment.passed, isFalse);
      expect(assessment.overallScore, lessThan(80.0));
      expect(assessment.alignments.any((a) => a.status == 'deleted'), isTrue);
    });
  });
}
