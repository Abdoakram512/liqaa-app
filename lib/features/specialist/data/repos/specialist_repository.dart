import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/specialist_models.dart';

/// Clean repository boundary for Specialist Case Management, Training Sessions,
/// Attempt History, and Clinical Observations.
///
/// Backed locally by [SharedPreferences] JSON persistence today and structured
/// for seamless future swap with a remote clinical API adapter.
abstract class SpecialistRepository {
  Future<List<SpecialistCase>> getCases();
  Future<SpecialistCase?> getCaseById(String caseId);
  Future<SpecialistCase> saveCase(SpecialistCase item);
  Future<void> deleteCase(String caseId);

  Future<List<TrainingSessionRecord>> getSessions({String? caseId});
  Future<TrainingSessionRecord> saveSession(TrainingSessionRecord session);

  Future<List<PronunciationAttemptRecord>> getAttempts({
    String? caseId,
    String? sessionId,
  });
  Future<PronunciationAttemptRecord> recordAttempt(
    PronunciationAttemptRecord attempt,
  );

  Future<List<SpecialistNoteEntry>> getNotes(String caseId);
  Future<SpecialistNoteEntry> addNote(SpecialistNoteEntry note);

  Future<List<SpecialistActivityAssignment>> getAssignments({
    String? caseId,
    String? childProfileId,
  });
  Future<SpecialistActivityAssignment> saveAssignment(
    SpecialistActivityAssignment assignment,
  );
  Future<void> deleteAssignment(String assignmentId);
}

class SpecialistLocalRepository implements SpecialistRepository {
  static const String _casesKey = 'yasser_specialist_cases_v1';
  static const String _sessionsKey = 'yasser_specialist_sessions_v1';
  static const String _attemptsKey = 'yasser_specialist_attempts_v1';
  static const String _notesKey = 'yasser_specialist_notes_v1';
  static const String _assignmentsKey = 'yasser_specialist_assignments_v2';

  final SharedPreferences _prefs;

  SpecialistLocalRepository(this._prefs);

  List<T> _readList<T>(
    String key,
    T Function(Map<String, dynamic> json) parser,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().map(parser).toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _writeList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T item) serializer,
  ) async {
    final encoded = jsonEncode(items.map(serializer).toList());
    await _prefs.setString(key, encoded);
  }

  @override
  Future<List<SpecialistCase>> getCases() async {
    final list = _readList(_casesKey, SpecialistCase.fromJson);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<SpecialistCase?> getCaseById(String caseId) async {
    final cases = await getCases();
    for (final c in cases) {
      if (c.id == caseId) return c;
    }
    return null;
  }

  @override
  Future<SpecialistCase> saveCase(SpecialistCase item) async {
    final cases = _readList(_casesKey, SpecialistCase.fromJson);
    final idx = cases.indexWhere((c) => c.id == item.id);
    if (idx >= 0) {
      cases[idx] = item;
    } else {
      cases.add(item);
    }
    await _writeList(_casesKey, cases, (c) => c.toJson());
    return item;
  }

  @override
  Future<void> deleteCase(String caseId) async {
    final cases = _readList(_casesKey, SpecialistCase.fromJson)
      ..removeWhere((c) => c.id == caseId);
    final sessions = _readList(_sessionsKey, TrainingSessionRecord.fromJson)
      ..removeWhere((s) => s.caseId == caseId);
    final attempts = _readList(
      _attemptsKey,
      PronunciationAttemptRecord.fromJson,
    )..removeWhere((a) => a.caseId == caseId);
    final notes = _readList(_notesKey, SpecialistNoteEntry.fromJson)
      ..removeWhere((n) => n.caseId == caseId);

    await Future.wait([
      _writeList(_casesKey, cases, (c) => c.toJson()),
      _writeList(_sessionsKey, sessions, (s) => s.toJson()),
      _writeList(_attemptsKey, attempts, (a) => a.toJson()),
      _writeList(_notesKey, notes, (n) => n.toJson()),
    ]);
  }

  @override
  Future<List<TrainingSessionRecord>> getSessions({String? caseId}) async {
    final all = _readList(_sessionsKey, TrainingSessionRecord.fromJson);
    final filtered = caseId == null
        ? all
        : all.where((s) => s.caseId == caseId).toList();
    filtered.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return filtered;
  }

  @override
  Future<TrainingSessionRecord> saveSession(
    TrainingSessionRecord session,
  ) async {
    final sessions = _readList(_sessionsKey, TrainingSessionRecord.fromJson);
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.add(session);
    }
    await _writeList(_sessionsKey, sessions, (s) => s.toJson());

    // Touch parent case updatedAt
    final parent = await getCaseById(session.caseId);
    if (parent != null) {
      await saveCase(parent.copyWith(updatedAt: DateTime.now()));
    }
    return session;
  }

  @override
  Future<List<PronunciationAttemptRecord>> getAttempts({
    String? caseId,
    String? sessionId,
  }) async {
    final all = _readList(_attemptsKey, PronunciationAttemptRecord.fromJson);
    final filtered = all.where((a) {
      if (caseId != null && a.caseId != caseId) return false;
      if (sessionId != null && a.sessionId != sessionId) return false;
      return true;
    }).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  @override
  Future<PronunciationAttemptRecord> recordAttempt(
    PronunciationAttemptRecord attempt,
  ) async {
    final attempts = _readList(
      _attemptsKey,
      PronunciationAttemptRecord.fromJson,
    )..add(attempt);
    await _writeList(_attemptsKey, attempts, (a) => a.toJson());

    final parent = await getCaseById(attempt.caseId);
    if (parent != null) {
      await saveCase(parent.copyWith(updatedAt: attempt.timestamp));
    }
    return attempt;
  }

  @override
  Future<List<SpecialistNoteEntry>> getNotes(String caseId) async {
    final all =
        _readList(
            _notesKey,
            SpecialistNoteEntry.fromJson,
          ).where((n) => n.caseId == caseId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<SpecialistNoteEntry> addNote(SpecialistNoteEntry note) async {
    final notes = _readList(_notesKey, SpecialistNoteEntry.fromJson)..add(note);
    await _writeList(_notesKey, notes, (n) => n.toJson());

    final parent = await getCaseById(note.caseId);
    if (parent != null) {
      await saveCase(parent.copyWith(updatedAt: note.createdAt));
    }
    return note;
  }

  @override
  Future<List<SpecialistActivityAssignment>> getAssignments({
    String? caseId,
    String? childProfileId,
  }) async {
    final all = _readList(
      _assignmentsKey,
      SpecialistActivityAssignment.fromJson,
    );
    final filtered = all.where((a) {
      if (caseId != null && a.caseId != caseId) return false;
      if (childProfileId != null && a.childProfileId != childProfileId) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  @override
  Future<SpecialistActivityAssignment> saveAssignment(
    SpecialistActivityAssignment assignment,
  ) async {
    final all = _readList(
      _assignmentsKey,
      SpecialistActivityAssignment.fromJson,
    );
    final idx = all.indexWhere((a) => a.id == assignment.id);
    if (idx >= 0) {
      all[idx] = assignment;
    } else {
      all.add(assignment);
    }
    await _writeList(_assignmentsKey, all, (a) => a.toJson());
    return assignment;
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    final all = _readList(
      _assignmentsKey,
      SpecialistActivityAssignment.fromJson,
    )..removeWhere((a) => a.id == assignmentId);
    await _writeList(_assignmentsKey, all, (a) => a.toJson());
  }
}
