import 'dart:math' as math;
import 'models/phoneme_token.dart';
import 'models/pronunciation_assessment.dart';
import 'models/vocabulary_word.dart';

class PronunciationEvaluator {
  const PronunciationEvaluator();

  static const Set<String> _vowelSymbols = {
    'a',
    'aː',
    'ɑ',
    'æ',
    'ə',
    'ʌ',
    'ɐ',
    'aɪ',
    'ɑu',
    'ɑu5',
    'a5',
    'u',
    'uː',
    'o',
    'oː',
    'ɔ',
    'ʊ',
    'ʉ',
    'i',
    'iː',
    'e',
    'eː',
    'ɪ',
    'ɛ',
    'y',
    'iɜ',
    'yɜ',
  };

  bool _isVowelSymbol(String s) {
    final clean = s
        .replaceAll('ː', '')
        .replaceAll(RegExp(r'[0-9.]'), '')
        .split('_')
        .first;
    return _vowelSymbols.contains(s) || _vowelSymbols.contains(clean);
  }

  /// Evaluates blindly recognized acoustic IPA phonemes against target vocabulary word
  /// using Wagner-Fischer dynamic programming sequence alignment.
  PronunciationAssessment evaluate({
    required VocabularyWord word,
    required List<PhonemeToken> recognizedTokens,
    int latencyMs = 0,
    bool speechDetected = false,
  }) {
    // 1. Distinguish confirmed speech with empty decoded phonemes from true silence
    if (recognizedTokens.isEmpty) {
      if (speechDetected) {
        return PronunciationAssessment(
          targetWord: word.id,
          targetWordArabic: word.wordArabic,
          recognizedTranscript: '',
          overallScore: 0.0,
          stars: 0,
          errorType: AssessmentErrorType.unrecognized,
          clinicalErrorName:
              'عدم وضوح الكلمة (Speech Detected Without Clear Phonemes)',
          targetPhoneme: word.targetPhoneme,
          alignments: const [],
          recognizedPhonemes: const [],
          yasserFeedbackMessage:
              'سمعت صوتك يا بطل، بس الكلمة ما كانتش واضحة. يلا نجرب نقولها بالراحة!',
          yasserPose: 'thinking',
          latencyMs: latencyMs,
          passed: false,
        );
      }
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: '',
        overallScore: 0.0,
        stars: 0,
        errorType: AssessmentErrorType.noSpeech,
        clinicalErrorName: 'لم يُكتشف صوت كلام (No Speech Detected)',
        targetPhoneme: word.targetPhoneme,
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

    final String recognizedArabic = recognizedTokens
        .map((t) => t.arabicSymbol)
        .join();
    final String recognizedSymbols = recognizedTokens
        .map((t) => t.symbol)
        .join(' ');

    // 2. Check genuine acoustic certainty (reject near-random low-posterior decodings)
    final double meanTokenConf =
        recognizedTokens.map((t) => t.confidence).reduce((a, b) => a + b) /
        recognizedTokens.length;
    final margins = recognizedTokens
        .map((t) => t.acousticMargin)
        .whereType<double>()
        .toList();
    final double? meanMargin = margins.isEmpty
        ? null
        : margins.reduce((a, b) => a + b) / margins.length;

    if (meanTokenConf < 0.25 || (meanMargin != null && meanMargin < 0.08)) {
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: recognizedSymbols,
        overallScore: 0.0,
        stars: 0,
        errorType: AssessmentErrorType.uncertain,
        clinicalErrorName:
            'عدم وضوح الاستدلال الصوتي (Uncertain Acoustic Posterior)',
        targetPhoneme: word.targetPhoneme,
        alignments: const [],
        recognizedPhonemes: recognizedTokens,
        yasserFeedbackMessage:
            'الصوت مش واضح كفاية يا بطل.. قرّب من المايك وقول الكلمة بوضوح!',
        yasserPose: 'thinking',
        latencyMs: latencyMs,
        passed: false,
      );
    }

    // 3. True Wagner-Fischer DP Alignment
    final List<PhonemeAlignment> alignments = _alignPhonemesDP(
      expected: word.expectedPhonemes,
      expectedArabic: word.expectedArabicPhonemes,
      recognized: recognizedTokens,
      targetPhonemeArabic: word.targetPhoneme,
      targetPhonemeIpa: word.targetPhonemeIpa,
    );

    // 4. Match target phoneme + clinical error rules
    ChildErrorRule? matchedRule;
    for (final a in alignments) {
      if (a.expectedArabic == word.targetPhoneme &&
          !a.isMatch &&
          a.recognizedToken != null) {
        for (final rule in word.commonChildErrors) {
          if (rule.errorType == 'substitution' &&
              (rule.substitutedPhoneme == a.recognizedToken!.arabicSymbol ||
                  _matchesClinicalPhoneme(
                    rule.substitutedPhoneme,
                    a.recognizedToken!.symbol,
                  ))) {
            matchedRule = rule;
            break;
          }
        }
        if (matchedRule != null) break;
      }
    }

    if (matchedRule == null) {
      for (final rule in word.commonChildErrors) {
        if (recognizedArabic == rule.pronouncedWord) {
          matchedRule = rule;
          break;
        }
      }
    }

    // 5. Score computation from aligned tokens
    int matches = 0;
    int substitutions = 0;
    int deletions = 0;
    double consonantInsertions = 0.0;
    double vowelInsertions = 0.0;
    double confidenceSum = 0.0;
    bool targetPhonemeMatched = false;

    for (final a in alignments) {
      if (a.isMatch) {
        matches++;
        confidenceSum += a.recognizedToken?.confidence ?? 0.0;
        if (a.expectedArabic == word.targetPhoneme ||
            a.expectedPhoneme == word.targetPhonemeIpa) {
          targetPhonemeMatched = true;
        }
      } else if (a.status == 'substituted') {
        substitutions++;
      } else if (a.status == 'deleted') {
        deletions++;
      } else if (a.status == 'inserted') {
        final tok = a.recognizedToken;
        if (tok != null && _isVowelSymbol(tok.symbol)) {
          // Arabic dictionaries often omit short medial diacritic vowels; penalize gently
          vowelInsertions += 0.15;
        } else {
          consonantInsertions += 0.55;
        }
      }
    }

    final int totalExpected = math.max(1, word.expectedPhonemes.length);
    final double netMatches = math.max(
      0.0,
      matches - consonantInsertions - math.min(0.45, vowelInsertions),
    );
    final double rawMatchRatio = netMatches / totalExpected;
    final double avgConfidence = matches > 0
        ? (confidenceSum / matches)
        : meanTokenConf;

    double score = (rawMatchRatio * 85.0 + avgConfidence * 15.0).clamp(
      0.0,
      100.0,
    );

    // Reject completely unrelated words (< 30% alignment)
    if (rawMatchRatio < 0.30) {
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: recognizedArabic.isNotEmpty
            ? recognizedArabic
            : recognizedSymbols,
        overallScore: double.parse(math.min(score, 30.0).toStringAsFixed(1)),
        stars: 1,
        errorType: AssessmentErrorType.unrelatedWord,
        clinicalErrorName: 'كلمة غير مطابقة (Unrelated Word)',
        targetPhoneme: word.targetPhoneme,
        alignments: alignments,
        recognizedPhonemes: recognizedTokens,
        yasserFeedbackMessage:
            'سمعت كلمة تانية يا بطل.. يلا نقول مع ياسر: ${word.wordArabic}!',
        yasserPose: 'thinking',
        latencyMs: latencyMs,
        passed: false,
      );
    }

    // Apply clinical error feedback (fronting, lateralization, interdental lisp, stopping)
    if (matchedRule != null) {
      score = math.min(score, 65.0);
      return PronunciationAssessment(
        targetWord: word.id,
        targetWordArabic: word.wordArabic,
        recognizedTranscript: recognizedArabic.isNotEmpty
            ? recognizedArabic
            : recognizedSymbols,
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

    // Target phoneme accuracy & zero deletions are required to pass
    if (!targetPhonemeMatched || deletions > 0) {
      score = math.min(score, 68.0);
    }

    final bool isPassed =
        score >= 80.0 && targetPhonemeMatched && deletions == 0;
    final int stars = isPassed ? (score >= 88.0 ? 3 : 2) : 1;

    AssessmentErrorType errorType = AssessmentErrorType.correct;
    String feedback = '';
    String pose = 'celebrating';
    String? clinicalName;

    if (isPassed) {
      errorType = AssessmentErrorType.correct;
      feedback =
          'ممتاز يا بطل! نطقت كلمة "${word.wordArabic}" صحيحة وواضحة جداً!';
      pose = 'celebrating';
    } else if (substitutions > 0) {
      errorType = AssessmentErrorType.substitution;
      clinicalName = 'إبدال صوتي (Phonetic Substitution)';
      feedback =
          'شاطر! بس ركز في صوت حرف الـ (${word.targetPhoneme}).. يلا نقول مع ياسر: ${word.wordArabic}!';
      pose = 'thinking';
    } else if (deletions > 0) {
      errorType = AssessmentErrorType.deletion;
      clinicalName = 'حذف صوت (Phonetic Deletion)';
      feedback =
          'قربت قوي! نسيت صوت في النص.. يلا ننطق كل الحروف مع بعض: ${word.wordArabic}!';
      pose = 'pointing';
    } else if (consonantInsertions > 0) {
      errorType = AssessmentErrorType.insertion;
      clinicalName = 'إضافة أصوات زائدة (Phonetic Insertion)';
      feedback =
          'شاطر! بس زودت أصوات زيادة.. يلا نقول: ${word.wordArabic} من غير زيادة!';
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
      recognizedTranscript: recognizedArabic.isNotEmpty
          ? recognizedArabic
          : recognizedSymbols,
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

  bool _matchesClinicalPhoneme(String? subAr, String recIpa) {
    if (subAr == null) return false;
    final normIpa = recIpa.replaceAll('ː', '').split('_').first;
    switch (subAr) {
      case 'ت':
        return normIpa == 't' || normIpa == 'tʰ';
      case 'ث':
        return normIpa == 'θ' || normIpa == 's';
      case 'ل':
        return normIpa == 'l' || normIpa == 'ɫ';
      case 'د':
        return normIpa == 'd';
      case 'ك':
        return normIpa == 'k' || normIpa == 'kʰ';
      case 'س':
        return normIpa == 's';
      default:
        return false;
    }
  }

  /// Wagner-Fischer DP sequence alignment accounting for acoustic IPA vowels & epenthesis.
  List<PhonemeAlignment> _alignPhonemesDP({
    required List<String> expected,
    required List<String> expectedArabic,
    required List<PhonemeToken> recognized,
    required String targetPhonemeArabic,
    required String targetPhonemeIpa,
  }) {
    final int m = expected.length;
    final int n = recognized.length;

    final dp = List.generate(m + 1, (_) => List<double>.filled(n + 1, 0.0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i * 1.0;
    }
    for (int j = 0; j <= n; j++) {
      final tok = j > 0 ? recognized[j - 1] : null;
      final stepIns = (tok != null && _isVowelSymbol(tok.symbol)) ? 0.35 : 1.0;
      dp[0][j] = (j == 0) ? 0.0 : dp[0][j - 1] + stepIns;
    }

    for (int i = 1; i <= m; i++) {
      final exp = expected[i - 1];
      final expAr = (i - 1 < expectedArabic.length)
          ? expectedArabic[i - 1]
          : exp;
      final bool isTargetConsonant =
          expAr == targetPhonemeArabic || exp == targetPhonemeIpa;

      for (int j = 1; j <= n; j++) {
        final rec = recognized[j - 1];
        final bool isEq = _isPhoneticallyEquivalent(
          exp,
          expAr,
          rec.symbol,
          rec.arabicSymbol,
          isWordInitial: i == 1 && j == 1,
          strictTarget: isTargetConsonant,
        );
        final double matchCost = isEq ? 0.0 : 1.0;
        final double insCost = _isVowelSymbol(rec.symbol) ? 0.35 : 1.0;

        final double costSub = dp[i - 1][j - 1] + matchCost;
        final double costDel = dp[i - 1][j] + 1.0;
        final double costIns = dp[i][j - 1] + insCost;

        dp[i][j] = math.min(costSub, math.min(costDel, costIns));
      }
    }

    final List<PhonemeAlignment> reversedAlignments = [];
    int i = m;
    int j = n;
    const double eps = 1e-6;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final exp = expected[i - 1];
        final expAr = (i - 1 < expectedArabic.length)
            ? expectedArabic[i - 1]
            : exp;
        final rec = recognized[j - 1];
        final bool isTargetConsonant =
            expAr == targetPhonemeArabic || exp == targetPhonemeIpa;
        final bool isEq = _isPhoneticallyEquivalent(
          exp,
          expAr,
          rec.symbol,
          rec.arabicSymbol,
          isWordInitial: i == 1 && j == 1,
          strictTarget: isTargetConsonant,
        );
        final double matchCost = isEq ? 0.0 : 1.0;

        if ((dp[i][j] - (dp[i - 1][j - 1] + matchCost)).abs() < eps) {
          reversedAlignments.add(
            PhonemeAlignment(
              expectedPhoneme: exp,
              expectedArabic: expAr,
              recognizedToken: rec,
              isMatch: isEq,
              status: isEq ? 'correct' : 'substituted',
            ),
          );
          i--;
          j--;
          continue;
        }
      }

      if (i > 0 && (dp[i][j] - (dp[i - 1][j] + 1.0)).abs() < eps) {
        final exp = expected[i - 1];
        final expAr = (i - 1 < expectedArabic.length)
            ? expectedArabic[i - 1]
            : exp;
        reversedAlignments.add(
          PhonemeAlignment(
            expectedPhoneme: exp,
            expectedArabic: expAr,
            recognizedToken: null,
            isMatch: false,
            status: 'deleted',
          ),
        );
        i--;
      } else if (j > 0) {
        final rec = recognized[j - 1];
        reversedAlignments.add(
          PhonemeAlignment(
            expectedPhoneme: '',
            expectedArabic: '',
            recognizedToken: rec,
            isMatch: false,
            status: 'inserted',
          ),
        );
        j--;
      }
    }

    return reversedAlignments.reversed.toList();
  }

  /// Checks phonetic equivalence between expected dictionary phoneme and Wav2Vec2-eSpeak IPA output.
  bool _isPhoneticallyEquivalent(
    String expIpa,
    String expAr,
    String recIpa,
    String recAr, {
    bool isWordInitial = false,
    bool strictTarget = false,
  }) {
    if (expIpa == recIpa || expAr == recAr) return true;

    final baseExp = expIpa
        .replaceAll('ː', '')
        .replaceAll(RegExp(r'[0-9.]'), '')
        .split('_')
        .first;
    final baseRec = recIpa
        .replaceAll('ː', '')
        .replaceAll(RegExp(r'[0-9.]'), '')
        .split('_')
        .first;
    if (baseExp == baseRec) return true;

    final normExpAr = _normalizeArabicChar(expAr);
    final normRecAr = _normalizeArabicChar(recAr);
    if (normExpAr == normRecAr) return true;

    // 1. Word-initial glottal stop [ʔ] in Arabic ('أ', 'إ') often acoustic-onset transitions into 'a'
    if (isWordInitial && !strictTarget && (expIpa == 'ʔ' || normExpAr == 'ء')) {
      if (baseRec == 'ʔ' || _isVowelSymbol(baseRec)) return true;
    }

    // 2. Egyptian Arabic dialectal variants & eSpeak acoustic realizations
    if ((expAr == 'ج' || baseExp == 'ɡ' || baseExp == 'g') &&
        (recAr == 'ج' || baseRec == 'ɡ' || baseRec == 'g' || baseRec == 'dʒ')) {
      return true;
    }
    if ((baseExp == 'k' || baseExp == 'kʰ') &&
        (baseRec == 'k' || baseRec == 'kʰ')) {
      return true;
    }
    if ((baseExp == 't' || baseExp == 'tʰ') &&
        (baseRec == 't' || baseRec == 'tʰ')) {
      return true;
    }
    if ((baseExp == 'r' || expAr == 'ر') &&
        (baseRec == 'r' || baseRec == 'ɾ' || baseRec == 'ɹ')) {
      return true;
    }
    if ((baseExp == 'l' || expAr == 'ل') &&
        (baseRec == 'l' || baseRec == 'ɫ')) {
      return true;
    }
    if ((baseExp == 'x' || expAr == 'خ') &&
        (baseRec == 'x' || baseRec == 'χ')) {
      return true;
    }
    if ((baseExp == 'ɣ' || expAr == 'غ') &&
        (baseRec == 'ɣ' || baseRec == 'ʁ')) {
      return true;
    }
    if ((baseExp == 'ʔ' || expAr == 'ق' || expAr == 'ء') &&
        (baseRec == 'ʔ' ||
            baseRec == 'q' ||
            recAr == 'ق' ||
            recAr == 'ء' ||
            recAr == 'أ')) {
      return true;
    }
    // 3. Vowel allophones across Arabic MSA / Egyptian / eSpeak IPA inventory
    if ((baseExp == 'u' || baseExp == 'o' || expAr == 'و') &&
        (baseRec == 'u' ||
            baseRec == 'o' ||
            baseRec == 'ɔ' ||
            baseRec == 'ʊ' ||
            baseRec == 'ʉ' ||
            baseRec == 'w')) {
      return true;
    }
    if ((baseExp == 'a' || expAr == 'ا' || expAr == 'ة') &&
        (baseRec == 'a' ||
            baseRec == 'ɑ' ||
            baseRec == 'æ' ||
            baseRec == 'ə' ||
            baseRec == 'ʌ' ||
            baseRec == 'ɐ' ||
            baseRec == 'aɪ' ||
            baseRec == 'ɑu')) {
      return true;
    }
    if ((baseExp == 'i' || baseExp == 'e' || expAr == 'ي') &&
        (baseRec == 'i' ||
            baseRec == 'e' ||
            baseRec == 'ɪ' ||
            baseRec == 'ɛ' ||
            baseRec == 'y' ||
            baseRec == 'j')) {
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
      case 'ؤ':
        return 'ء';
      case 'ى':
        return 'ي';
      case 'ة':
      case 'ه':
        return 'ه';
      default:
        return c;
    }
  }
}
