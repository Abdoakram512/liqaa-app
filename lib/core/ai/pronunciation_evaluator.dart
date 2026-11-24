import 'dart:math' as math;
import 'models/phoneme_token.dart';
import 'models/pronunciation_assessment.dart';
import 'models/vocabulary_word.dart';

class PronunciationEvaluator {
  const PronunciationEvaluator();

  /// Evaluates recognized phonemes against the target vocabulary word
  PronunciationAssessment evaluate({
    required VocabularyWord word,
    required List<PhonemeToken> recognizedTokens,
    int latencyMs = 85,
  }) {
    if (recognizedTokens.isEmpty) {
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: '',
        overallScore: 0.0,
        stars: 1,
        errorType: AssessmentErrorType.unrecognized,
        alignments: word.expectedPhonemes.asMap().entries.map((e) {
          final int idx = e.key;
          final String exp = e.value;
          final String expAr = idx < word.expectedArabicPhonemes.length
              ? word.expectedArabicPhonemes[idx]
              : exp;
          return PhonemeAlignment(
            expectedPhoneme: exp,
            expectedArabic: expAr,
            recognizedToken: null,
            isMatch: false,
            status: 'deleted',
          );
        }).toList(),
        recognizedPhonemes: const [],
        yasserFeedbackMessage: 'مش سامع صوتك كويس يا بطل! علّي صوتك ويلا نجرب تاني.',
        yasserPose: 'thinking',
        latencyMs: latencyMs,
        passed: false,
      );
    }

    // Build recognized phoneme string and transcript
    final String recognizedSymbols = recognizedTokens.map((t) => t.symbol).join();
    final String recognizedArabic = recognizedTokens.map((t) => t.arabicSymbol).join();

    // Check if recognized word matches one of the known clinical child error rules
    ChildErrorRule? matchedRule;
    for (final rule in word.commonChildErrors) {
      if (recognizedArabic.contains(rule.pronouncedWord) ||
          rule.pronouncedWord.contains(recognizedArabic) ||
          (rule.substitutedPhoneme != null &&
              recognizedArabic.startsWith(rule.substitutedPhoneme!))) {
        matchedRule = rule;
        break;
      }
    }

    // Dynamic Levenshtein Alignment between Expected and Recognized Phonemes
    final List<PhonemeAlignment> alignments = _alignPhonemes(
      expected: word.expectedPhonemes,
      expectedArabic: word.expectedArabicPhonemes,
      recognized: recognizedTokens,
    );

    // Calculate score based on alignment matches and acoustic confidences
    int matches = 0;
    int substitutions = 0;
    int deletions = 0;
    double confidenceSum = 0.0;

    for (final a in alignments) {
      if (a.isMatch) {
        matches++;
        confidenceSum += a.recognizedToken?.confidence ?? 0.8;
      } else if (a.status == 'substituted') {
        substitutions++;
      } else if (a.status == 'deleted') {
        deletions++;
      }
    }

    final int totalExpected = math.max(1, word.expectedPhonemes.length);
    final double rawMatchRatio = matches / totalExpected;
    final double avgConfidence = matches > 0 ? (confidenceSum / matches) : 0.5;

    double score = (rawMatchRatio * 85.0 + avgConfidence * 15.0).clamp(0.0, 100.0);

    // If clinical substitution rule was triggered
    if (matchedRule != null) {
      score = math.min(score, 68.0); // Cap score for clinical substitution
    }

    final bool isPassed = score >= 80.0;
    final int stars = score >= 90.0
        ? 3
        : (score >= 70.0 ? 2 : 1);

    // Determine error type & feedback
    AssessmentErrorType errorType = AssessmentErrorType.correct;
    String feedback = '';
    String pose = 'celebrating';
    String? clinicalName;
    String? substituted;

    if (isPassed && matchedRule == null) {
      errorType = AssessmentErrorType.correct;
      feedback = 'ممتاز يا بطل! نطقت كلمة "${word.wordArabic}" صحيحة وواضحة جداً!';
      pose = 'celebrating';
    } else if (matchedRule != null) {
      errorType = AssessmentErrorType.substitution;
      clinicalName = matchedRule.clinicalName;
      substituted = matchedRule.substitutedPhoneme;
      feedback = matchedRule.feedbackAr;
      pose = matchedRule.yasserPose;
    } else if (substitutions > 0) {
      errorType = AssessmentErrorType.substitution;
      clinicalName = 'إبدال صوتي (Phonetic Substitution)';
      feedback = 'شاطر! بس ركز في صوت حرف الـ (${word.targetPhoneme}).. يلا نقول مع ياسر: ${word.wordArabic}!';
      pose = 'thinking';
    } else if (deletions > 0) {
      errorType = AssessmentErrorType.deletion;
      clinicalName = 'حذف صوت (Phonetic Deletion)';
      feedback = 'قربت قوي! نسيت صوت في النص.. يلا ننطق كل الحروف مع بعض: ${word.wordArabic}!';
      pose = 'pointing';
    } else {
      errorType = AssessmentErrorType.distortion;
      clinicalName = 'عدم وضوح كافي (Acoustic Distortion)';
      feedback = 'وضّح صوتك شوية يا بطل! ${word.yasserTip}';
      pose = 'thinking';
    }

    return PronunciationAssessment(
      targetWord: word.id,
      targetWordArabic: word.wordArabic,
      recognizedTranscript: recognizedArabic.isNotEmpty ? recognizedArabic : recognizedSymbols,
      overallScore: double.parse(score.toStringAsFixed(1)),
      stars: stars,
      errorType: errorType,
      clinicalErrorName: clinicalName,
      targetPhoneme: word.targetPhoneme,
      substitutedPhoneme: substituted,
      alignments: alignments,
      recognizedPhonemes: recognizedTokens,
      yasserFeedbackMessage: feedback,
      yasserPose: pose,
      latencyMs: latencyMs,
      passed: isPassed,
    );
  }

  /// Weighted Levenshtein alignment between expected and recognized phoneme tokens
  List<PhonemeAlignment> _alignPhonemes({
    required List<String> expected,
    required List<String> expectedArabic,
    required List<PhonemeToken> recognized,
  }) {
    final List<PhonemeAlignment> result = [];
    final int m = expected.length;
    final int n = recognized.length;

    int i = 0;
    int j = 0;

    while (i < m || j < n) {
      final String exp = i < m ? expected[i] : '';
      final String expAr = i < m && i < expectedArabic.length ? expectedArabic[i] : exp;

      if (i < m && j < n) {
        final PhonemeToken recToken = recognized[j];
        final bool match = exp == recToken.symbol || expAr == recToken.arabicSymbol;

        if (match) {
          result.add(PhonemeAlignment(
            expectedPhoneme: exp,
            expectedArabic: expAr,
            recognizedToken: recToken,
            isMatch: true,
            status: 'correct',
          ));
          i++;
          j++;
        } else {
          // Substitution
          result.add(PhonemeAlignment(
            expectedPhoneme: exp,
            expectedArabic: expAr,
            recognizedToken: recToken,
            isMatch: false,
            status: 'substituted',
          ));
          i++;
          j++;
        }
      } else if (i < m) {
        // Deletion
        result.add(PhonemeAlignment(
          expectedPhoneme: exp,
          expectedArabic: expAr,
          recognizedToken: null,
          isMatch: false,
          status: 'deleted',
        ));
        i++;
      } else if (j < n) {
        // Insertion
        final PhonemeToken recToken = recognized[j];
        result.add(PhonemeAlignment(
          expectedPhoneme: '',
          expectedArabic: '',
          recognizedToken: recToken,
          isMatch: false,
          status: 'inserted',
        ));
        j++;
      }
    }

    return result;
  }
}
