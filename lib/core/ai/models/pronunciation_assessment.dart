import 'package:equatable/equatable.dart';
import 'phoneme_token.dart';

enum AssessmentErrorType {
  correct, // نطـق صحيح
  substitution, // إبدال فونيمي
  deletion, // حذف
  insertion, // إضافة
  distortion, // تشويه / عدم وضوح
  unrecognized, // غير واضح أو صمت
}

class PhonemeAlignment extends Equatable {
  final String expectedPhoneme;
  final String expectedArabic;
  final PhonemeToken? recognizedToken;
  final bool isMatch;
  final String status; // 'correct', 'substituted', 'deleted', 'inserted'

  const PhonemeAlignment({
    required this.expectedPhoneme,
    required this.expectedArabic,
    this.recognizedToken,
    required this.isMatch,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'expected_phoneme': expectedPhoneme,
    'expected_arabic': expectedArabic,
    'recognized_token': recognizedToken?.toJson(),
    'is_match': isMatch,
    'status': status,
  };

  @override
  List<Object?> get props => [
    expectedPhoneme,
    expectedArabic,
    recognizedToken,
    isMatch,
    status,
  ];
}

class PronunciationAssessment extends Equatable {
  final String targetWord;
  final String targetWordArabic;
  final String recognizedTranscript;
  final double overallScore; // 0.0 to 100.0
  final int stars; // 1, 2, or 3
  final AssessmentErrorType errorType;
  final String? clinicalErrorName;
  final String? targetPhoneme;
  final String? substitutedPhoneme;
  final List<PhonemeAlignment> alignments;
  final List<PhonemeToken> recognizedPhonemes;
  final String yasserFeedbackMessage;
  final String yasserPose; // 'celebrating', 'thinking', 'pointing', 'waving'
  final int latencyMs;
  final bool passed;

  const PronunciationAssessment({
    required this.targetWord,
    required this.targetWordArabic,
    required this.recognizedTranscript,
    required this.overallScore,
    required this.stars,
    required this.errorType,
    this.clinicalErrorName,
    this.targetPhoneme,
    this.substitutedPhoneme,
    required this.alignments,
    required this.recognizedPhonemes,
    required this.yasserFeedbackMessage,
    this.yasserPose = 'thinking',
    this.latencyMs = 0,
    required this.passed,
  });

  Map<String, dynamic> toJson() => {
    'target_word': targetWord,
    'target_word_arabic': targetWordArabic,
    'recognized_transcript': recognizedTranscript,
    'overall_score': overallScore,
    'stars': stars,
    'error_type': errorType.name,
    'clinical_error_name': clinicalErrorName,
    'target_phoneme': targetPhoneme,
    'substituted_phoneme': substitutedPhoneme,
    'alignments': alignments.map((e) => e.toJson()).toList(),
    'recognized_phonemes': recognizedPhonemes.map((e) => e.toJson()).toList(),
    'yasser_feedback_message': yasserFeedbackMessage,
    'yasser_pose': yasserPose,
    'latency_ms': latencyMs,
    'passed': passed,
  };

  @override
  List<Object?> get props => [
    targetWord,
    recognizedTranscript,
    overallScore,
    stars,
    errorType,
    targetPhoneme,
    substitutedPhoneme,
    passed,
  ];
}
