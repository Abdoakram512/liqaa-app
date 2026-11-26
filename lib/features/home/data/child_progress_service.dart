import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists genuine child pronunciation milestones locally without fabricating
/// initial scores or stars.
class ChildProgressSnapshot {
  final int totalStars;
  final Set<String> masteredWordIds;
  final int completedSessions;
  final int practicedAttempts;
  final String? lastPracticedWordArabic;

  const ChildProgressSnapshot({
    this.totalStars = 0,
    this.masteredWordIds = const {},
    this.completedSessions = 0,
    this.practicedAttempts = 0,
    this.lastPracticedWordArabic,
  });

  int get masteredCount => masteredWordIds.length;

  Map<String, dynamic> toJson() => {
    'total_stars': totalStars,
    'mastered_word_ids': masteredWordIds.toList(),
    'completed_sessions': completedSessions,
    'practiced_attempts': practicedAttempts,
    'last_practiced_word_arabic': lastPracticedWordArabic,
  };

  factory ChildProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return ChildProgressSnapshot(
      totalStars: json['total_stars'] as int? ?? 0,
      masteredWordIds: Set<String>.from(
        (json['mastered_word_ids'] as List<dynamic>?) ?? const <String>[],
      ),
      completedSessions: json['completed_sessions'] as int? ?? 0,
      practicedAttempts: json['practiced_attempts'] as int? ?? 0,
      lastPracticedWordArabic: json['last_practiced_word_arabic'] as String?,
    );
  }
}

class ChildProgressService extends ChangeNotifier {
  static const String _storageKey = 'yasser_child_progress_v1';
  final SharedPreferences _prefs;
  ChildProgressSnapshot _snapshot = const ChildProgressSnapshot();

  ChildProgressService(this._prefs) {
    _load();
  }

  ChildProgressSnapshot get snapshot => _snapshot;

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      _snapshot = ChildProgressSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _snapshot = const ChildProgressSnapshot();
    }
  }

  Future<void> recordPracticeAttempt({
    required String wordId,
    required String wordArabic,
    required bool passed,
    required int starsAwarded,
  }) async {
    final nextMastered = Set<String>.from(_snapshot.masteredWordIds);
    int addedStars = 0;
    if (passed && starsAwarded > 0) {
      final isFirstMastery = nextMastered.add(wordId);
      if (isFirstMastery) {
        addedStars = starsAwarded;
      }
    }

    _snapshot = ChildProgressSnapshot(
      totalStars: _snapshot.totalStars + addedStars,
      masteredWordIds: nextMastered,
      completedSessions: _snapshot.completedSessions,
      practicedAttempts: _snapshot.practicedAttempts + 1,
      lastPracticedWordArabic: wordArabic,
    );
    await _persist();
  }

  Future<void> recordCompletedSession() async {
    _snapshot = ChildProgressSnapshot(
      totalStars: _snapshot.totalStars,
      masteredWordIds: _snapshot.masteredWordIds,
      completedSessions: _snapshot.completedSessions + 1,
      practicedAttempts: _snapshot.practicedAttempts,
      lastPracticedWordArabic: _snapshot.lastPracticedWordArabic,
    );
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(_storageKey, jsonEncode(_snapshot.toJson()));
    notifyListeners();
  }
}
