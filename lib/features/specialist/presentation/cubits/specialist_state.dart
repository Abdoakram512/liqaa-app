import 'package:equatable/equatable.dart';

import '../../data/models/specialist_models.dart';

class SpecialistState extends Equatable {
  final bool isLoading;
  final List<SpecialistCase> allCases;
  final List<TrainingSessionRecord> allSessions;
  final List<PronunciationAttemptRecord> allAttempts;
  final Map<String, List<SpecialistNoteEntry>> notesByCase;
  final String searchQuery;
  final CaseStatus? statusFilter;
  final String? errorMessage;

  const SpecialistState({
    this.isLoading = false,
    this.allCases = const [],
    this.allSessions = const [],
    this.allAttempts = const [],
    this.notesByCase = const {},
    this.searchQuery = '',
    this.statusFilter,
    this.errorMessage,
  });

  List<SpecialistCase> get filteredCases {
    final q = searchQuery.trim().toLowerCase();
    return allCases.where((c) {
      if (statusFilter != null && c.status != statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final inName = c.childName.toLowerCase().contains(q);
      final inPhone = (c.guardianPhone ?? '').toLowerCase().contains(q);
      final inPhonemes = c.targetPhonemes.any((p) => p.contains(q));
      return inName || inPhone || inPhonemes;
    }).toList();
  }

  int get activeCasesCount =>
      allCases.where((c) => c.status == CaseStatus.active).length;

  SpecialistCase? caseById(String caseId) {
    for (final c in allCases) {
      if (c.id == caseId) return c;
    }
    return null;
  }

  List<TrainingSessionRecord> sessionsForCase(String caseId) =>
      allSessions.where((s) => s.caseId == caseId).toList();

  List<PronunciationAttemptRecord> attemptsForCase(String caseId) =>
      allAttempts.where((a) => a.caseId == caseId).toList();

  List<SpecialistNoteEntry> notesForCase(String caseId) =>
      notesByCase[caseId] ?? const [];

  CaseProgressSummary summaryForCase(String caseId) {
    return CaseProgressSummary.compute(
      sessions: sessionsForCase(caseId),
      attempts: attemptsForCase(caseId),
    );
  }

  SpecialistState copyWith({
    bool? isLoading,
    List<SpecialistCase>? allCases,
    List<TrainingSessionRecord>? allSessions,
    List<PronunciationAttemptRecord>? allAttempts,
    Map<String, List<SpecialistNoteEntry>>? notesByCase,
    String? searchQuery,
    CaseStatus? statusFilter,
    bool clearStatusFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SpecialistState(
      isLoading: isLoading ?? this.isLoading,
      allCases: allCases ?? this.allCases,
      allSessions: allSessions ?? this.allSessions,
      allAttempts: allAttempts ?? this.allAttempts,
      notesByCase: notesByCase ?? this.notesByCase,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    allCases,
    allSessions,
    allAttempts,
    notesByCase,
    searchQuery,
    statusFilter,
    errorMessage,
  ];
}
