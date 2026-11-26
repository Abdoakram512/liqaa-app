import 'package:equatable/equatable.dart';

class ChildErrorRule extends Equatable {
  final String pronouncedWord;
  final String errorType; // substitution, deletion, insertion, distortion
  final String? substitutedPhoneme;
  final String? deletedPhoneme;
  final String targetPhoneme;
  final String clinicalName;
  final String feedbackAr;
  final String yasserPose; // celebrating, thinking, pointing, waving

  const ChildErrorRule({
    required this.pronouncedWord,
    required this.errorType,
    this.substitutedPhoneme,
    this.deletedPhoneme,
    required this.targetPhoneme,
    required this.clinicalName,
    required this.feedbackAr,
    this.yasserPose = 'thinking',
  });

  factory ChildErrorRule.fromJson(Map<String, dynamic> json) {
    return ChildErrorRule(
      pronouncedWord: json['pronounced_word'] as String? ?? '',
      errorType: json['error_type'] as String? ?? 'substitution',
      substitutedPhoneme: json['substituted_phoneme'] as String?,
      deletedPhoneme: json['deleted_phoneme'] as String?,
      targetPhoneme: json['target_phoneme'] as String? ?? '',
      clinicalName: json['clinical_name'] as String? ?? '',
      feedbackAr: json['feedback_ar'] as String? ?? '',
      yasserPose: json['yasser_pose'] as String? ?? 'thinking',
    );
  }

  Map<String, dynamic> toJson() => {
    'pronounced_word': pronouncedWord,
    'error_type': errorType,
    'substituted_phoneme': substitutedPhoneme,
    'deleted_phoneme': deletedPhoneme,
    'target_phoneme': targetPhoneme,
    'clinical_name': clinicalName,
    'feedback_ar': feedbackAr,
    'yasser_pose': yasserPose,
  };

  @override
  List<Object?> get props => [
    pronouncedWord,
    errorType,
    substitutedPhoneme,
    deletedPhoneme,
    targetPhoneme,
    clinicalName,
  ];
}

class VocabularyWord extends Equatable {
  final String id;
  final String wordArabic;
  final String wordTransliteration;
  final String meaningEn;
  final String targetPhoneme;
  final String targetPhonemeIpa;
  final String phonemeCategory;
  final int difficultyLevel;
  final List<String> expectedPhonemes;
  final List<String> expectedArabicPhonemes;
  final String yasserTip;
  final List<ChildErrorRule> commonChildErrors;

  const VocabularyWord({
    required this.id,
    required this.wordArabic,
    required this.wordTransliteration,
    required this.meaningEn,
    required this.targetPhoneme,
    required this.targetPhonemeIpa,
    required this.phonemeCategory,
    required this.difficultyLevel,
    required this.expectedPhonemes,
    required this.expectedArabicPhonemes,
    required this.yasserTip,
    this.commonChildErrors = const [],
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    return VocabularyWord(
      id: json['id'] as String? ?? '',
      wordArabic: json['word_arabic'] as String? ?? '',
      wordTransliteration: json['word_transliteration'] as String? ?? '',
      meaningEn: json['meaning_en'] as String? ?? '',
      targetPhoneme: json['target_phoneme'] as String? ?? '',
      targetPhonemeIpa: json['target_phoneme_ipa'] as String? ?? '',
      phonemeCategory: json['phoneme_category'] as String? ?? '',
      difficultyLevel: json['difficulty_level'] as int? ?? 1,
      expectedPhonemes: List<String>.from(json['expected_phonemes'] ?? []),
      expectedArabicPhonemes: List<String>.from(
        json['expected_arabic_phonemes'] ?? [],
      ),
      yasserTip: json['yasser_tip'] as String? ?? '',
      commonChildErrors:
          (json['common_child_errors'] as List<dynamic>?)
              ?.map((e) => ChildErrorRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word_arabic': wordArabic,
    'word_transliteration': wordTransliteration,
    'meaning_en': meaningEn,
    'target_phoneme': targetPhoneme,
    'target_phoneme_ipa': targetPhonemeIpa,
    'phoneme_category': phonemeCategory,
    'difficulty_level': difficultyLevel,
    'expected_phonemes': expectedPhonemes,
    'expected_arabic_phonemes': expectedArabicPhonemes,
    'yasser_tip': yasserTip,
    'common_child_errors': commonChildErrors.map((e) => e.toJson()).toList(),
  };

  @override
  List<Object?> get props => [id, wordArabic, targetPhoneme, expectedPhonemes];
}
