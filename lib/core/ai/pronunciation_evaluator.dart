import 'dart:math' as math;
import 'models/phoneme_token.dart';
import 'models/pronunciation_assessment.dart';
import 'models/vocabulary_word.dart';

class PronunciationEvaluator {
  const PronunciationEvaluator();

  /// Evaluates recognized phonemes against target vocabulary word using Levenshtein DP sequence alignment
  PronunciationAssessment evaluate({
    required VocabularyWord word,
    required List<PhonemeToken> recognizedTokens,
    int latencyMs = 85,
  }) {
    // 1. Handle empty / silent audio -> NoSpeech failure state
    if (recognizedTokens.isEmpty) {
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: '',
        overallScore: 0.0,
        stars: 0,
        errorType: AssessmentErrorType.noSpeech,
        clinicalErrorName: 'صمت تام (No Speech Detected)',
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
        yasserFeedbackMessage: 'مش سامع صوتك يا بطل! علّي صوتك ويلا نجرب تاني.',
        yasserPose: 'thinking',
        latencyMs: latencyMs,
        passed: false,
      );
    }

    final String recognizedArabic = recognizedTokens.map((t) => t.arabicSymbol).join();
    final String recognizedSymbols = recognizedTokens.map((t) => t.symbol).join();

    // 2. Perform True Dynamic Programming (Wagner-Fischer) Alignment
    final List<PhonemeAlignment> alignments = _alignPhonemesDP(
      expected: word.expectedPhonemes,
      expectedArabic: word.expectedArabicPhonemes,
      recognized: recognizedTokens,
    );

    // 3. Clinical Child Error Rule Matching
    ChildErrorRule? matchedRule;
    for (final rule in word.commonChildErrors) {
      if (recognizedArabic == rule.pronouncedWord ||
          recognizedArabic.contains(rule.pronouncedWord) ||
          rule.pronouncedWord.contains(recognizedArabic)) {
        matchedRule = rule;
        break;
      }
    }

    // Check if the target phoneme alignment specifically matches a clinical substitution
    if (matchedRule == null) {
      for (final a in alignments) {
        if (a.expectedArabic == word.targetPhoneme && !a.isMatch && a.recognizedToken != null) {
          for (final rule in word.commonChildErrors) {
            if (rule.errorType == 'substitution' &&
                rule.substitutedPhoneme == a.recognizedToken!.arabicSymbol) {
              matchedRule = rule;
              break;
            }
          }
          if (matchedRule != null) break;
        }
      }
    }

    // 4. Score calculation based on alignment results (penalizing insertions, deletions, substitutions)
    int matches = 0;
    int substitutions = 0;
    int deletions = 0;
    int insertions = 0;
    double confidenceSum = 0.0;
    bool targetPhonemeMatched = false;

    for (final a in alignments) {
      if (a.isMatch) {
        matches++;
        confidenceSum += a.recognizedToken?.confidence ?? 0.8;
        if (a.expectedArabic == word.targetPhoneme) {
          targetPhonemeMatched = true;
        }
      } else if (a.status == 'substituted') {
        substitutions++;
      } else if (a.status == 'deleted') {
        deletions++;
      } else if (a.status == 'inserted') {
        insertions++;
      }
    }

    final int totalExpected = math.max(1, word.expectedPhonemes.length);
    // Insertion penalty: deduct 0.5 per inserted phoneme
    final double netMatches = math.max(0.0, matches - (insertions * 0.5));
    final double rawMatchRatio = netMatches / totalExpected;
    final double avgConfidence = matches > 0 ? (confidenceSum / matches) : 0.5;

    double score = (rawMatchRatio * 85.0 + avgConfidence * 15.0).clamp(0.0, 100.0);

    // Completely unrelated word spoken (e.g. match ratio < 30%)
    if (rawMatchRatio < 0.30) {
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: recognizedArabic.isNotEmpty ? recognizedArabic : recognizedSymbols,
        overallScore: math.min(score, 30.0),
        stars: 1,
        errorType: AssessmentErrorType.unrelatedWord,
        clinicalErrorName: 'كلمة غير مطابقة (Unrelated Word)',
        targetPhoneme: word.targetPhoneme,
        alignments: alignments,
        recognizedPhonemes: recognizedTokens,
        yasserFeedbackMessage: 'سمعت كلمة تانية يا بطل.. يلا نقول مع ياسر: ${word.wordArabic}!',
        yasserPose: 'thinking',
        latencyMs: latencyMs,
        passed: false,
      );
    }

    // Clinical substitution rule applied
    if (matchedRule != null) {
      score = math.min(score, 65.0);
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: recognizedArabic.isNotEmpty ? recognizedArabic : recognizedSymbols,
        overallScore: double.parse(score.toStringAsFixed(1)),
        stars: 1,
        errorType: matchedRule.errorType == 'deletion'
            ? AssessmentErrorType.deletion
            : AssessmentErrorType.substitution,
        clinicalErrorName: matchedRule.clinicalName,
        targetPhoneme: word.targetPhoneme,
        substitutedPhoneme: matchedRule.substitutedPhoneme,
        alignments: alignments,
        recognizedPhonemes: recognizedTokens,
        yasserFeedbackMessage: matchedRule.feedbackAr,
        yasserPose: matchedRule.yasserPose,
        latencyMs: latencyMs,
        passed: false,
      );
    }

    // Target phoneme MUST be correct to pass
    if (!targetPhonemeMatched) {
      score = math.min(score, 68.0);
    }

    final bool isPassed = score >= 80.0 && targetPhonemeMatched;
    final int stars = score >= 90.0 ? 3 : (score >= 75.0 ? 2 : 1);

    AssessmentErrorType errorType = AssessmentErrorType.correct;
    String feedback = '';
    String pose = 'celebrating';
    String? clinicalName;

    if (isPassed) {
      errorType = AssessmentErrorType.correct;
      feedback = 'ممتاز يا بطل! نطقت كلمة "${word.wordArabic}" صحيحة وواضحة جداً!';
      pose = 'celebrating';
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
    } else if (insertions > 0) {
      errorType = AssessmentErrorType.insertion;
      clinicalName = 'إضافة أصوات زائدة (Phonetic Insertion)';
      feedback = 'شاطر! بس زودت أصوات زيادة.. يلا نقول: ${word.wordArabic} من غير زيادة!';
      pose = 'thinking';
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
      alignments: alignments,
      recognizedPhonemes: recognizedTokens,
      yasserFeedbackMessage: feedback,
      yasserPose: pose,
      latencyMs: latencyMs,
      passed: isPassed,
    );
  }

  /// True Wagner-Fischer Dynamic Programming alignment matrix
  List<PhonemeAlignment> _alignPhonemesDP({
    required List<String> expected,
    required List<String> expectedArabic,
    required List<PhonemeToken> recognized,
  }) {
    final int m = expected.length;
    final int n = recognized.length;

    // dp[i][j] stores the minimum edit distance
    final dp = List.generate(m + 1, (_) => List<double>.filled(n + 1, 0.0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i * 1.0;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j * 1.0;
    }

    for (int i = 1; i <= m; i++) {
      final exp = expected[i - 1];
      final expAr = (i - 1 < expectedArabic.length) ? expectedArabic[i - 1] : exp;

      for (int j = 1; j <= n; j++) {
        final rec = recognized[j - 1];
        final bool isEq = _isPhoneticallyEquivalent(exp, expAr, rec.symbol, rec.arabicSymbol);
        final double matchCost = isEq ? 0.0 : 1.0;

        final double costSub = dp[i - 1][j - 1] + matchCost;
        final double costDel = dp[i - 1][j] + 1.0;
        final double costIns = dp[i][j - 1] + 1.0;

        dp[i][j] = math.min(costSub, math.min(costDel, costIns));
      }
    }

    // Backtracking from (m, n) to (0, 0) to reconstruct optimal alignment
    final List<PhonemeAlignment> reversedAlignments = [];
    int i = m;
    int j = n;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final exp = expected[i - 1];
        final expAr = (i - 1 < expectedArabic.length) ? expectedArabic[i - 1] : exp;
        final rec = recognized[j - 1];
        final bool isEq = _isPhoneticallyEquivalent(exp, expAr, rec.symbol, rec.arabicSymbol);
        final double matchCost = isEq ? 0.0 : 1.0;

        if (dp[i][j] == dp[i - 1][j - 1] + matchCost) {
          reversedAlignments.add(PhonemeAlignment(
            expectedPhoneme: exp,
            expectedArabic: expAr,
            recognizedToken: rec,
            isMatch: isEq,
            status: isEq ? 'correct' : 'substituted',
          ));
          i--;
          j--;
          continue;
        }
      }

      if (i > 0 && dp[i][j] == dp[i - 1][j] + 1.0) {
        final exp = expected[i - 1];
        final expAr = (i - 1 < expectedArabic.length) ? expectedArabic[i - 1] : exp;
        reversedAlignments.add(PhonemeAlignment(
          expectedPhoneme: exp,
          expectedArabic: expAr,
          recognizedToken: null,
          isMatch: false,
          status: 'deleted',
        ));
        i--;
      } else if (j > 0) {
        final rec = recognized[j - 1];
        reversedAlignments.add(PhonemeAlignment(
          expectedPhoneme: '',
          expectedArabic: '',
          recognizedToken: rec,
          isMatch: false,
          status: 'inserted',
        ));
        j--;
      }
    }

    return reversedAlignments.reversed.toList();
  }

  /// Checks phonetic equivalence between expected and recognized phonemes,
  /// accounting for Egyptian Arabic dialectal variants and vowel length variations.
  bool _isPhoneticallyEquivalent(String expIpa, String expAr, String recIpa, String recAr) {
    if (expIpa == recIpa || expAr == recAr) return true;

    // Normalization of Arabic characters
    final normExpAr = _normalizeArabicChar(expAr);
    final normRecAr = _normalizeArabicChar(recAr);
    if (normExpAr == normRecAr) return true;

    // Egyptian Arabic variants
    // 1. جيم [g] vs [ɡ]
    if ((expAr == 'ج' || expIpa == 'ɡ') && (recAr == 'ج' || recIpa == 'ɡ')) return true;
    // 2. همزة [ʔ] vs [ء] / [أ] / [إ] / [آ] / [ق] (Egyptian dialectal Qaf -> glottal stop)
    if ((expIpa == 'ʔ' || expAr == 'ق' || expAr == 'ء') &&
        (recIpa == 'ʔ' || recAr == 'ق' || recAr == 'ء' || recAr == 'أ' || recAr == 'إ')) {
      return true;
    }
    // 3. Long vs short vowels: [uː] vs [u], [aː] vs [a], [iː] vs [i]
    if ((expIpa == 'uː' || expIpa == 'u' || expIpa == 'oː') &&
        (recIpa == 'uː' || recIpa == 'u' || recIpa == 'oː' || recAr == 'و' || recAr == 'ُ')) {
      return true;
    }
    if ((expIpa == 'aː' || expIpa == 'a') &&
        (recIpa == 'aː' || recIpa == 'a' || recAr == 'ا' || recAr == 'ة' || recAr == 'َ')) {
      return true;
    }
    if ((expIpa == 'iː' || expIpa == 'i' || expIpa == 'eː') &&
        (recIpa == 'iː' || recIpa == 'i' || recIpa == 'eː' || recAr == 'ي' || recAr == 'ِ')) {
      return true;
    }

    return false;
  }

  String _normalizeArabicChar(String c) {
    switch (c) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ء':
      case 'ئ':
      case 'ؤ': return 'ء';
      case 'ى': return 'ي';
      case 'ة':
      case 'ه': return 'ه';
      default: return c;
    }
  }
}
