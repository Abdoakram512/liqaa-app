import 'package:equatable/equatable.dart';

enum CaseStatus {
  active,
  followUp,
  completed,
  archived;

  String get arabicLabel => switch (this) {
    CaseStatus.active => 'نشطة',
    CaseStatus.followUp => 'متابعة',
    CaseStatus.completed => 'مكتملة',
    CaseStatus.archived => 'مؤرشفة',
  };
}

class SpecialistCase extends Equatable {
  final String id;
  final String childName;
  final int ageYears;
  final String? guardianPhone;
  final List<String> targetPhonemes;
  final String clinicalNotes;
  final CaseStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SpecialistCase({
    required this.id,
    required this.childName,
    required this.ageYears,
    this.guardianPhone,
    required this.targetPhonemes,
    this.clinicalNotes = '',
    this.status = CaseStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  SpecialistCase copyWith({
    String? childName,
    int? ageYears,
    String? guardianPhone,
    List<String>? targetPhonemes,
    String? clinicalNotes,
    CaseStatus? status,
    DateTime? updatedAt,
  }) {
    return SpecialistCase(
      id: id,
      childName: childName ?? this.childName,
      ageYears: ageYears ?? this.ageYears,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      targetPhonemes: targetPhonemes ?? this.targetPhonemes,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'child_name': childName,
    'age_years': ageYears,
    'guardian_phone': guardianPhone,
    'target_phonemes': targetPhonemes,
    'clinical_notes': clinicalNotes,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory SpecialistCase.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? CaseStatus.active.name;
    final parsedStatus = CaseStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => CaseStatus.active,
    );
    final created =
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now();
    final updated =
        DateTime.tryParse(json['updated_at'] as String? ?? '') ?? created;

    return SpecialistCase(
      id: json['id'] as String? ?? '',
      childName: json['child_name'] as String? ?? '',
      ageYears: json['age_years'] as int? ?? 5,
      guardianPhone: json['guardian_phone'] as String?,
      targetPhonemes: List<String>.from(
        (json['target_phonemes'] as List<dynamic>?) ?? const <String>[],
      ),
      clinicalNotes: json['clinical_notes'] as String? ?? '',
      status: parsedStatus,
      createdAt: created,
      updatedAt: updated,
    );
  }

  @override
  List<Object?> get props => [
    id,
    childName,
    ageYears,
    guardianPhone,
    targetPhonemes,
    clinicalNotes,
    status,
    createdAt,
    updatedAt,
  ];
}

class SpecialistNoteEntry extends Equatable {
  final String id;
  final String caseId;
  final String content;
  final DateTime createdAt;

  const SpecialistNoteEntry({
    required this.id,
    required this.caseId,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'case_id': caseId,
    'content': content,
    'created_at': createdAt.toIso8601String(),
  };

  factory SpecialistNoteEntry.fromJson(Map<String, dynamic> json) {
    return SpecialistNoteEntry(
      id: json['id'] as String? ?? '',
      caseId: json['case_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, caseId, content, createdAt];
}

class TrainingSessionRecord extends Equatable {
  final String id;
  final String caseId;
  final String title;
  final List<String> targetPhonemes;
  final String notes;
  final DateTime startedAt;
  final DateTime? completedAt;

  const TrainingSessionRecord({
    required this.id,
    required this.caseId,
    required this.title,
    required this.targetPhonemes,
    this.notes = '',
    required this.startedAt,
    this.completedAt,
  });

  TrainingSessionRecord copyWith({String? notes, DateTime? completedAt}) {
    return TrainingSessionRecord(
      id: id,
      caseId: caseId,
      title: title,
      targetPhonemes: targetPhonemes,
      notes: notes ?? this.notes,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'case_id': caseId,
    'title': title,
    'target_phonemes': targetPhonemes,
    'notes': notes,
    'started_at': startedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  factory TrainingSessionRecord.fromJson(Map<String, dynamic> json) {
    return TrainingSessionRecord(
      id: json['id'] as String? ?? '',
      caseId: json['case_id'] as String? ?? '',
      title: json['title'] as String? ?? 'جلسة تدريب نطق',
      targetPhonemes: List<String>.from(
        (json['target_phonemes'] as List<dynamic>?) ?? const <String>[],
      ),
      notes: json['notes'] as String? ?? '',
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    caseId,
    title,
    targetPhonemes,
    notes,
    startedAt,
    completedAt,
  ];
}

/// Real recorded speech attempt linked to a [SpecialistCase] and [TrainingSessionRecord].
///
/// Note: [scoreIndicator] represents the automated acoustic alignment indicator
/// (0..100) for educational tracking, NOT a clinical medical diagnosis.
class PronunciationAttemptRecord extends Equatable {
  final String id;
  final String caseId;
  final String sessionId;
  final String wordId;
  final String wordArabic;
  final String targetPhoneme;
  final String recognizedTranscript;
  final double? scoreIndicator;
  final int stars;
  final String errorType;
  final bool passed;
  final DateTime timestamp;

  const PronunciationAttemptRecord({
    required this.id,
    required this.caseId,
    required this.sessionId,
    required this.wordId,
    required this.wordArabic,
    required this.targetPhoneme,
    required this.recognizedTranscript,
    required this.scoreIndicator,
    required this.stars,
    required this.errorType,
    required this.passed,
    required this.timestamp,
  });

  String get arabicOutcomeLabel => switch (errorType) {
    'correct' => 'مطابق للهدف',
    'substitution' => 'إبدال صوتي',
    'deletion' => 'حذف صوتي',
    'insertion' => 'إضافة صوت',
    'distortion' => 'عدم وضوح مخارج',
    'noSpeech' => 'لم يُلتقط كلام',
    'poorAudioQuality' => 'ضوضاء محيطة',
    'unrelatedWord' => 'كلمة مختلفة',
    'uncertain' => 'استدلال غير مؤكد',
    _ => 'محاولة غير مكتملة',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'case_id': caseId,
    'session_id': sessionId,
    'word_id': wordId,
    'word_arabic': wordArabic,
    'target_phoneme': targetPhoneme,
    'recognized_transcript': recognizedTranscript,
    'score_indicator': scoreIndicator,
    'stars': stars,
    'error_type': errorType,
    'passed': passed,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PronunciationAttemptRecord.fromJson(Map<String, dynamic> json) {
    return PronunciationAttemptRecord(
      id: json['id'] as String? ?? '',
      caseId: json['case_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      wordId: json['word_id'] as String? ?? '',
      wordArabic: json['word_arabic'] as String? ?? '',
      targetPhoneme: json['target_phoneme'] as String? ?? '',
      recognizedTranscript: json['recognized_transcript'] as String? ?? '',
      scoreIndicator: (json['score_indicator'] as num?)?.toDouble(),
      stars: json['stars'] as int? ?? 0,
      errorType: json['error_type'] as String? ?? 'unrecognized',
      passed: json['passed'] as bool? ?? false,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    caseId,
    sessionId,
    wordId,
    wordArabic,
    targetPhoneme,
    scoreIndicator,
    stars,
    errorType,
    passed,
    timestamp,
  ];
}

/// Real computed progress metrics derived strictly from recorded attempts.
class CaseProgressSummary extends Equatable {
  final int totalSessions;
  final int totalAttempts;
  final int scoredAttemptsCount;
  final int passedAttemptsCount;
  final double? averageScoreIndicator;
  final List<PronunciationAttemptRecord> scoredTrajectory;

  const CaseProgressSummary({
    required this.totalSessions,
    required this.totalAttempts,
    required this.scoredAttemptsCount,
    required this.passedAttemptsCount,
    required this.averageScoreIndicator,
    required this.scoredTrajectory,
  });

  factory CaseProgressSummary.compute({
    required List<TrainingSessionRecord> sessions,
    required List<PronunciationAttemptRecord> attempts,
  }) {
    final chronological = List<PronunciationAttemptRecord>.from(attempts)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final scored = chronological
        .where((a) => a.scoreIndicator != null)
        .toList();
    final passed = chronological.where((a) => a.passed).length;

    double? avg;
    if (scored.isNotEmpty) {
      final sum = scored.fold<double>(0.0, (acc, a) => acc + a.scoreIndicator!);
      avg = sum / scored.length;
    }

    return CaseProgressSummary(
      totalSessions: sessions.length,
      totalAttempts: attempts.length,
      scoredAttemptsCount: scored.length,
      passedAttemptsCount: passed,
      averageScoreIndicator: avg,
      scoredTrajectory: scored,
    );
  }

  @override
  List<Object?> get props => [
    totalSessions,
    totalAttempts,
    scoredAttemptsCount,
    passedAttemptsCount,
    averageScoreIndicator,
    scoredTrajectory,
  ];
}
