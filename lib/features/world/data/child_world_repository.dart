import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/world_models.dart';

/// Offline multi-profile persistence repository for Yasser's Personalized World.
/// Strictly isolates profiles, custom gardens, discovered words, and outcomes per [ChildProfile.id].
class ChildWorldRepository {
  static const String _profilesKey = 'yasser_world_profiles_v2';
  static const String _activeProfileKey = 'yasser_active_profile_id_v2';
  static String _stateKey(String profileId) =>
      'yasser_world_state_v2_$profileId';

  final SharedPreferences _prefs;

  ChildWorldRepository(this._prefs);

  List<ChildProfile> loadProfiles() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) {
      final now = DateTime.now();
      return [
        ChildProfile(
          id: 'profile_default',
          displayName: 'بطل لقاء',
          createdAt: now,
          lastVisitedAt: now,
        ),
      ];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .whereType<Map<String, dynamic>>()
          .map(ChildProfile.fromJson)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    final now = DateTime.now();
    return [
      ChildProfile(
        id: 'profile_default',
        displayName: 'بطل لقاء',
        createdAt: now,
        lastVisitedAt: now,
      ),
    ];
  }

  Future<void> saveProfiles(List<ChildProfile> profiles) async {
    await _prefs.setString(
      _profilesKey,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }

  String loadActiveProfileId(List<ChildProfile> profiles) {
    final stored = _prefs.getString(_activeProfileKey);
    if (stored != null && profiles.any((p) => p.id == stored)) {
      return stored;
    }
    return profiles.first.id;
  }

  Future<void> saveActiveProfileId(String profileId) async {
    await _prefs.setString(_activeProfileKey, profileId);
  }

  ChildWorldState loadWorldState(String profileId) {
    final raw = _prefs.getString(_stateKey(profileId));
    if (raw == null || raw.isEmpty) {
      return ChildWorldState(
        profileId: profileId,
        plantedFlowerIds: const ['flower_meadow_daisy'],
        placedHomeDecorationIds: const ['deco_lantern'],
      );
    }
    try {
      return ChildWorldState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ChildWorldState(
        profileId: profileId,
        plantedFlowerIds: const ['flower_meadow_daisy'],
        placedHomeDecorationIds: const ['deco_lantern'],
      );
    }
  }

  Future<void> saveWorldState(ChildWorldState state) async {
    await _prefs.setString(
      _stateKey(state.profileId),
      jsonEncode(state.toJson()),
    );
  }
}
