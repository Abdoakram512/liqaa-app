import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../data/models/specialist_models.dart';
import '../../data/repos/specialist_repository.dart';
import 'specialist_state.dart';

class SpecialistCubit extends Cubit<SpecialistState> {
  final SpecialistRepository _repository;
  int _idCounter = 0;

  SpecialistCubit(this._repository) : super(const SpecialistState());

  String _generateId(String prefix) {
    _idCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  Future<void> loadWorkspace() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _repository.getCases(),
        _repository.getSessions(),
        _repository.getAttempts(),
        _repository.getAssignments(),
      ]);
      final cases = results[0] as List<SpecialistCase>;
      final sessions = results[1] as List<TrainingSessionRecord>;
      final attempts = results[2] as List<PronunciationAttemptRecord>;
      final assignments = results[3] as List<SpecialistActivityAssignment>;

      final Map<String, List<SpecialistNoteEntry>> notesMap = {};
      for (final c in cases) {
        notesMap[c.id] = await _repository.getNotes(c.id);
      }

      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          allCases: cases,
          allSessions: sessions,
          allAttempts: attempts,
          notesByCase: notesMap,
          allAssignments: assignments,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'تعذّر تحميل بيانات الحالات: $e',
        ),
      );
    }
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void setStatusFilter(CaseStatus? status) {
    if (status == null) {
      emit(state.copyWith(clearStatusFilter: true));
    } else {
      emit(state.copyWith(statusFilter: status));
    }
  }

  Future<SpecialistCase> createCase({
    required String childName,
    required int ageYears,
    String? guardianPhone,
    required List<String> targetPhonemes,
    String clinicalNotes = '',
    CaseStatus status = CaseStatus.active,
  }) async {
    final now = DateTime.now();
    final created = SpecialistCase(
      id: _generateId('case'),
      childName: childName.trim(),
      ageYears: ageYears,
      guardianPhone: guardianPhone?.trim().isEmpty == true
          ? null
          : guardianPhone?.trim(),
      targetPhonemes: targetPhonemes,
      clinicalNotes: clinicalNotes.trim(),
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.saveCase(created);
    if (clinicalNotes.trim().isNotEmpty) {
      await _repository.addNote(
        SpecialistNoteEntry(
          id: _generateId('note'),
          caseId: created.id,
          content: clinicalNotes.trim(),
          createdAt: now,
        ),
      );
    }
    await loadWorkspace();
    return created;
  }

  Future<void> updateCase(SpecialistCase updated) async {
    await _repository.saveCase(updated.copyWith(updatedAt: DateTime.now()));
    await loadWorkspace();
  }

  Future<void> deleteCase(String caseId) async {
    await _repository.deleteCase(caseId);
    await loadWorkspace();
  }

  Future<void> addCaseNote({
    required String caseId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    await _repository.addNote(
      SpecialistNoteEntry(
        id: _generateId('note'),
        caseId: caseId,
        content: trimmed,
        createdAt: DateTime.now(),
      ),
    );
    await loadWorkspace();
  }

  Future<TrainingSessionRecord> startGuidedSession({
    required String caseId,
    String? customTitle,
    List<String>? targetPhonemes,
    String notes = '',
  }) async {
    final targetCase =
        state.caseById(caseId) ?? await _repository.getCaseById(caseId);
    final phonemes = targetPhonemes ?? targetCase?.targetPhonemes ?? const [];
    final existingCount = state.sessionsForCase(caseId).length;

    final session = TrainingSessionRecord(
      id: _generateId('session'),
      caseId: caseId,
      title: customTitle?.trim().isNotEmpty == true
          ? customTitle!.trim()
          : 'جلسة تدريب #${existingCount + 1}',
      targetPhonemes: phonemes,
      notes: notes.trim(),
      startedAt: DateTime.now(),
    );
    await _repository.saveSession(session);
    await loadWorkspace();
    return session;
  }

  /// Records a genuine speech evaluation into the active case & session history.
  ///
  /// Excludes system/hardware failures and withholds numeric scores on
  /// silence/noise/uncertain audio so progress charts never display fake data.
  Future<void> recordEvaluatedAttempt({
    required String caseId,
    required String sessionId,
    required VocabularyWord word,
    required PronunciationAssessment assessment,
  }) async {
    if (assessment.errorType.isSystemFailure) return;

    final bool hasValidScoreIndicator = !const {
      AssessmentErrorType.noSpeech,
      AssessmentErrorType.poorAudioQuality,
      AssessmentErrorType.uncertain,
      AssessmentErrorType.unrecognized,
    }.contains(assessment.errorType);

    final record = PronunciationAttemptRecord(
      id: _generateId('attempt'),
      caseId: caseId,
      sessionId: sessionId,
      wordId: word.id,
      wordArabic: word.wordArabic,
      targetPhoneme: word.targetPhoneme,
      recognizedTranscript: assessment.recognizedTranscript,
      scoreIndicator: hasValidScoreIndicator ? assessment.overallScore : null,
      stars: assessment.passed ? assessment.stars : 0,
      errorType: assessment.errorType.name,
      passed:
          assessment.passed &&
          assessment.errorType == AssessmentErrorType.correct,
      timestamp: DateTime.now(),
    );

    await _repository.recordAttempt(record);
    await loadWorkspace();
  }

  Future<SpecialistActivityAssignment> assignPersonalizedAdventure({
    required String caseId,
    String childProfileId = 'profile_default',
    required String title,
    required List<String> targetPhonemes,
    int difficultyLevel = 1,
    String assignedRegionId = 'sound_garden',
    List<String> assignedGameTypes = const [
      'discover_word',
      'hear_difference',
      'listen_and_choose',
      'repeat_after_yasser',
      'name_the_picture',
    ],
  }) async {
    final assignment = SpecialistActivityAssignment(
      id: _generateId('assign'),
      caseId: caseId,
      childProfileId: childProfileId,
      title: title.trim().isEmpty ? 'مسار تدريب مخصص' : title.trim(),
      targetPhonemes: targetPhonemes,
      difficultyLevel: difficultyLevel,
      assignedRegionId: assignedRegionId,
      assignedGameTypes: assignedGameTypes,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await _repository.saveAssignment(assignment);
    await loadWorkspace();
    return assignment;
  }

  Future<void> removeAssignment(String assignmentId) async {
    await _repository.deleteAssignment(assignmentId);
    await loadWorkspace();
  }
}
