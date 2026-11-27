import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/child_world_repository.dart';
import '../../data/models/world_models.dart';

class ChildWorldCubitState extends Equatable {
  final List<ChildProfile> profiles;
  final String activeProfileId;
  final ChildWorldState worldState;
  final bool isLoaded;

  const ChildWorldCubitState({
    required this.profiles,
    required this.activeProfileId,
    required this.worldState,
    this.isLoaded = false,
  });

  ChildProfile get activeProfile => profiles.firstWhere(
    (p) => p.id == activeProfileId,
    orElse: () => profiles.first,
  );

  ChildWorldCubitState copyWith({
    List<ChildProfile>? profiles,
    String? activeProfileId,
    ChildWorldState? worldState,
    bool? isLoaded,
  }) {
    return ChildWorldCubitState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      worldState: worldState ?? this.worldState,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [profiles, activeProfileId, worldState, isLoaded];
}

class ChildWorldCubit extends Cubit<ChildWorldCubitState> {
  final ChildWorldRepository _repository;

  ChildWorldCubit(this._repository) : super(_initialState(_repository));

  static ChildWorldCubitState _initialState(ChildWorldRepository repo) {
    final profiles = repo.loadProfiles();
    final activeId = repo.loadActiveProfileId(profiles);
    final worldState = repo.loadWorldState(activeId);
    return ChildWorldCubitState(
      profiles: profiles,
      activeProfileId: activeId,
      worldState: worldState,
      isLoaded: true,
    );
  }

  Future<void> reload() async {
    final profiles = _repository.loadProfiles();
    final activeId = _repository.loadActiveProfileId(profiles);
    final world = _repository.loadWorldState(activeId);
    emit(
      ChildWorldCubitState(
        profiles: profiles,
        activeProfileId: activeId,
        worldState: world,
        isLoaded: true,
      ),
    );
  }

  Future<void> updateActiveProfile({
    String? displayName,
    String? avatarId,
    String? favoriteColorId,
    String? favoriteAnimalId,
    String? themeId,
    List<String>? interests,
  }) async {
    final current = state.activeProfile;
    final updated = current.copyWith(
      displayName: displayName?.trim().isEmpty == true
          ? current.displayName
          : displayName?.trim(),
      avatarId: avatarId,
      favoriteColorId: favoriteColorId,
      favoriteAnimalId: favoriteAnimalId,
      themeId: themeId,
      interests: interests,
      lastVisitedAt: DateTime.now(),
    );
    final nextProfiles = state.profiles
        .map((p) => p.id == updated.id ? updated : p)
        .toList();
    await _repository.saveProfiles(nextProfiles);
    emit(state.copyWith(profiles: nextProfiles));
  }

  Future<ChildProfile> createAndSwitchProfile({
    required String displayName,
    String avatarId = 'star_explorer',
    String favoriteColorId = 'sunny_orange',
    String favoriteAnimalId = 'animal_bunny',
    String themeId = 'sunlit_meadow',
    List<String> interests = const ['الحيوانات', 'الحكايات'],
  }) async {
    final now = DateTime.now();
    final profile = ChildProfile(
      id: 'profile_${now.microsecondsSinceEpoch}',
      displayName: displayName.trim().isEmpty ? 'بطل جديد' : displayName.trim(),
      avatarId: avatarId,
      favoriteColorId: favoriteColorId,
      favoriteAnimalId: favoriteAnimalId,
      themeId: themeId,
      interests: interests,
      createdAt: now,
      lastVisitedAt: now,
    );
    final nextProfiles = [...state.profiles, profile];
    await _repository.saveProfiles(nextProfiles);
    await _repository.saveActiveProfileId(profile.id);
    final nextWorld = _repository.loadWorldState(profile.id);
    await _repository.saveWorldState(nextWorld);
    emit(
      state.copyWith(
        profiles: nextProfiles,
        activeProfileId: profile.id,
        worldState: nextWorld,
      ),
    );
    return profile;
  }

  Future<void> switchProfile(String profileId) async {
    if (!state.profiles.any((p) => p.id == profileId)) return;
    await _repository.saveActiveProfileId(profileId);
    final world = _repository.loadWorldState(profileId);
    emit(state.copyWith(activeProfileId: profileId, worldState: world));
  }

  Future<void> markWordDiscovered(String wordId) async {
    if (state.worldState.discoveredWordIds.contains(wordId)) return;
    final next = state.worldState.copyWith(
      discoveredWordIds: {...state.worldState.discoveredWordIds, wordId},
      lastSessionAt: DateTime.now(),
    );
    await _repository.saveWorldState(next);
    emit(state.copyWith(worldState: next));
  }

  Future<void> setActiveDestination(
    WorldRegionId regionId, {
    String? activityId,
  }) async {
    final next = state.worldState.copyWith(
      lastActiveRegionId: regionId,
      lastActiveActivityId: activityId,
      lastSessionAt: DateTime.now(),
    );
    await _repository.saveWorldState(next);
    emit(state.copyWith(worldState: next));
  }

  Future<void> recordActivityOutcome(
    ActivityOutcomeRecord outcome, {
    String? stepIdToMarkComplete,
    String? rewardCollectibleId,
    bool markAdventureCompleteId = false,
    String? adventureId,
  }) async {
    final cur = state.worldState;
    final nextCompleted = {...cur.completedActivityIds};
    if (outcome.completed) {
      nextCompleted.add(outcome.activityId);
      if (stepIdToMarkComplete != null && stepIdToMarkComplete.isNotEmpty) {
        nextCompleted.add(stepIdToMarkComplete);
      }
    }
    final nextAdventures = {...cur.completedAdventureIds};
    if (markAdventureCompleteId && adventureId != null) {
      nextAdventures.add(adventureId);
    }
    final nextUnlocked = {...cur.unlockedCollectibleIds};
    final nextUnseen = {...cur.unseenCollectibleIds};
    if (rewardCollectibleId != null && rewardCollectibleId.isNotEmpty) {
      if (nextUnlocked.add(rewardCollectibleId)) {
        nextUnseen.add(rewardCollectibleId);
      }
    }
    final nextPlanted = [...cur.plantedFlowerIds];
    if (rewardCollectibleId != null &&
        rewardCollectibleId.startsWith('flower_') &&
        !nextPlanted.contains(rewardCollectibleId)) {
      nextPlanted.add(rewardCollectibleId);
    }

    final next = cur.copyWith(
      completedActivityIds: nextCompleted,
      completedAdventureIds: nextAdventures,
      unlockedCollectibleIds: nextUnlocked,
      unseenCollectibleIds: nextUnseen,
      plantedFlowerIds: nextPlanted,
      outcomes: [...cur.outcomes, outcome],
      lastActiveRegionId: outcome.regionId,
      clearLastActiveActivity: outcome.completed,
      lastSessionAt: DateTime.now(),
    );
    await _repository.saveWorldState(next);
    emit(state.copyWith(worldState: next));
  }

  Future<void> unlockAndPlantCollectible(String collectibleId) async {
    final cur = state.worldState;
    final nextUnlocked = {...cur.unlockedCollectibleIds, collectibleId};
    final nextPlanted = [...cur.plantedFlowerIds];
    if (collectibleId.startsWith('flower_') &&
        !nextPlanted.contains(collectibleId)) {
      nextPlanted.add(collectibleId);
    }
    final next = cur.copyWith(
      unlockedCollectibleIds: nextUnlocked,
      plantedFlowerIds: nextPlanted,
      unseenCollectibleIds: {...cur.unseenCollectibleIds, collectibleId},
      lastSessionAt: DateTime.now(),
    );
    await _repository.saveWorldState(next);
    emit(state.copyWith(worldState: next));
  }

  Future<void> togglePlantedFlower(String flowerId) async {
    final cur = state.worldState;
    if (!cur.unlockedCollectibleIds.contains(flowerId)) return;
    final nextPlanted = [...cur.plantedFlowerIds];
    if (nextPlanted.contains(flowerId)) {
      nextPlanted.remove(flowerId);
    } else {
      nextPlanted.add(flowerId);
    }
    final next = cur.copyWith(plantedFlowerIds: nextPlanted);
    await _repository.saveWorldState(next);
    emit(state.copyWith(worldState: next));
  }

  Future<void> toggleHomeDecoration(String decoId) async {
    final cur = state.worldState;
    if (!cur.unlockedCollectibleIds.contains(decoId)) return;
    final nextDecos = [...cur.placedHomeDecorationIds];
    if (nextDecos.contains(decoId)) {
      nextDecos.remove(decoId);
    } else {
      nextDecos.add(decoId);
    }
    final next = cur.copyWith(placedHomeDecorationIds: nextDecos);
    await _repository.saveWorldState(next);
    emit(state.copyWith(worldState: next));
  }

  Future<void> markCollectiblesSeen() async {
    if (state.worldState.unseenCollectibleIds.isEmpty) return;
    final next = state.worldState.copyWith(unseenCollectibleIds: const {});
    await _repository.saveWorldState(next);
    emit(state.copyWith(worldState: next));
  }
}
