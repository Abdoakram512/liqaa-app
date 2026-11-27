import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Connected adventure destinations across Yasser's living world.
enum WorldRegionId {
  yasserHome(
    'yasser_home',
    'بيت ياسر',
    'مساحتك الشخصية وحديقتك المتطورة',
    Icons.cottage_rounded,
  ),
  soundGarden(
    'sound_garden',
    'حديقة الأصوات',
    'ازرع زهوراً باكتشاف أصوات جديدة',
    Icons.local_florist_rounded,
  ),
  animalForest(
    'animal_forest',
    'غابة الحيوانات',
    'قابل أصدقاء الغابة واسمع أصواتهم',
    Icons.pets_rounded,
  ),
  wordIsland(
    'word_island',
    'جزيرة الكلمات',
    'اعبر الكوبري واكتشف كنوز الكلمات',
    Icons.explore_rounded,
  ),
  storyCity(
    'story_city',
    'مدينة الحكايات',
    'عش قصص ياسر وأكمل أحداثها',
    Icons.auto_stories_rounded,
  ),
  heroCastle(
    'hero_castle',
    'قلعة الأبطال',
    'تحديات شجاعة وأوسمة الأبطال',
    Icons.castle_rounded,
  );

  final String id;
  final String titleAr;
  final String subtitleAr;
  final IconData icon;

  const WorldRegionId(this.id, this.titleAr, this.subtitleAr, this.icon);

  Color get accentColor => switch (this) {
    WorldRegionId.yasserHome => AppColors.worldHomeAccent,
    WorldRegionId.soundGarden => AppColors.worldGardenAccent,
    WorldRegionId.animalForest => AppColors.worldForestAccent,
    WorldRegionId.wordIsland => AppColors.worldIslandAccent,
    WorldRegionId.storyCity => AppColors.worldStoryAccent,
    WorldRegionId.heroCastle => AppColors.worldCastleAccent,
  };

  Color get softColor => switch (this) {
    WorldRegionId.yasserHome => AppColors.worldHomeSoft,
    WorldRegionId.soundGarden => AppColors.worldGardenSoft,
    WorldRegionId.animalForest => AppColors.worldForestSoft,
    WorldRegionId.wordIsland => AppColors.worldIslandSoft,
    WorldRegionId.storyCity => AppColors.worldStorySoft,
    WorldRegionId.heroCastle => AppColors.worldCastleSoft,
  };

  Color get deepColor => switch (this) {
    WorldRegionId.yasserHome => AppColors.worldHomeDeep,
    WorldRegionId.soundGarden => AppColors.worldGardenDeep,
    WorldRegionId.animalForest => AppColors.worldForestDeep,
    WorldRegionId.wordIsland => AppColors.worldIslandDeep,
    WorldRegionId.storyCity => AppColors.worldStoryDeep,
    WorldRegionId.heroCastle => AppColors.worldCastleDeep,
  };

  static WorldRegionId fromId(String? id) => WorldRegionId.values.firstWhere(
    (r) => r.id == id,
    orElse: () => WorldRegionId.soundGarden,
  );
}

/// All 8 required interactive learning mini-game types.
/// Only [repeatAfterYasser] and [nameThePicture] activate the microphone / ONNX speech pipeline.
enum MiniGameType {
  discoverWord(
    'discover_word',
    'اكتشف الكلمة',
    'استكشف شكل الكلمة وصوتها بدون ضغط',
    Icons.touch_app_rounded,
    false,
  ),
  hearDifference(
    'hear_difference',
    'اسمع الفرق',
    'ميّز بين صوتين متقاربين بودانك',
    Icons.hearing_rounded,
    false,
  ),
  listenAndChoose(
    'listen_and_choose',
    'اسمع واختار',
    'اسمع ياسر واختار الصورة المناسبة',
    Icons.image_search_rounded,
    false,
  ),
  repeatAfterYasser(
    'repeat_after_yasser',
    'ردّد وراء ياسر',
    'اسمع نطق ياسر الأول وقول زيه',
    Icons.record_voice_over_rounded,
    true,
  ),
  nameThePicture(
    'name_the_picture',
    'سمّي الصورة',
    'قول اسم الصورة بصوتك الواضح',
    Icons.mic_rounded,
    true,
  ),
  mysterySoundBoxes(
    'mystery_sound_boxes',
    'صناديق الأصوات السرية',
    'افتح الصناديق ووصّل كل صوت بصورته',
    Icons.card_giftcard_rounded,
    false,
  ),
  soundDetective(
    'sound_detective',
    'محقق الأصوات',
    'جمّع الصور اللي بتبدأ بنفس الصوت',
    Icons.search_rounded,
    false,
  ),
  completeTheStory(
    'complete_the_story',
    'أكمل الحكاية',
    'اسمع القصة واختار الكلمة الناقصة',
    Icons.menu_book_rounded,
    false,
  );

  final String id;
  final String titleAr;
  final String subtitleAr;
  final IconData icon;
  final bool usesMicrophoneAndAi;

  const MiniGameType(
    this.id,
    this.titleAr,
    this.subtitleAr,
    this.icon,
    this.usesMicrophoneAndAi,
  );

  static MiniGameType fromId(String? id) => MiniGameType.values.firstWhere(
    (g) => g.id == id,
    orElse: () => MiniGameType.discoverWord,
  );
}

enum CollectibleKind { flower, animal, sticker, decoration, storyPage, badge }

class CollectibleItem extends Equatable {
  final String id;
  final CollectibleKind kind;
  final String titleAr;
  final String descriptionAr;
  final WorldRegionId regionId;
  final String illustrationKey;
  final Color accentColor;

  const CollectibleItem({
    required this.id,
    required this.kind,
    required this.titleAr,
    required this.descriptionAr,
    required this.regionId,
    required this.illustrationKey,
    required this.accentColor,
  });

  @override
  List<Object?> get props => [id, kind, titleAr, regionId, illustrationKey];
}

class MinimalPairItem extends Equatable {
  final String id;
  final String wordA;
  final String wordB;
  final String targetPhonemeA;
  final String contrastPhonemeB;
  final String illustrationKeyA;
  final String illustrationKeyB;
  final String hintAr;

  const MinimalPairItem({
    required this.id,
    required this.wordA,
    required this.wordB,
    required this.targetPhonemeA,
    required this.contrastPhonemeB,
    required this.illustrationKeyA,
    required this.illustrationKeyB,
    required this.hintAr,
  });

  bool get isSame => wordA == wordB;

  @override
  List<Object?> get props => [
    id,
    wordA,
    wordB,
    targetPhonemeA,
    contrastPhonemeB,
  ];
}

class StoryChallengeItem extends Equatable {
  final String id;
  final WorldRegionId regionId;
  final String titleAr;
  final String storyPrefixAr;
  final String storySuffixAr;
  final String missingWordId;
  final String missingWordArabic;
  final List<String> distractorWordIds;
  final String targetPhoneme;

  const StoryChallengeItem({
    required this.id,
    required this.regionId,
    required this.titleAr,
    required this.storyPrefixAr,
    required this.storySuffixAr,
    required this.missingWordId,
    required this.missingWordArabic,
    required this.distractorWordIds,
    required this.targetPhoneme,
  });

  @override
  List<Object?> get props => [id, regionId, missingWordId, targetPhoneme];
}

class AdventureStep extends Equatable {
  final String id;
  final String titleAr;
  final String subtitleAr;
  final MiniGameType gameType;
  final List<String> targetWordIds;

  const AdventureStep({
    required this.id,
    required this.titleAr,
    required this.subtitleAr,
    required this.gameType,
    required this.targetWordIds,
  });

  @override
  List<Object?> get props => [id, gameType, targetWordIds];
}

class WorldAdventure extends Equatable {
  final String id;
  final WorldRegionId regionId;
  final String titleAr;
  final String storyGoalAr;
  final String rewardCollectibleId;
  final List<AdventureStep> steps;

  const WorldAdventure({
    required this.id,
    required this.regionId,
    required this.titleAr,
    required this.storyGoalAr,
    required this.rewardCollectibleId,
    required this.steps,
  });

  @override
  List<Object?> get props => [id, regionId, rewardCollectibleId, steps];
}

/// Privacy-respecting local child customization profile.
/// Uses optional display nickname + curated visual preferences (zero real PII/photos).
class ChildProfile extends Equatable {
  final String id;
  final String displayName;
  final String avatarId;
  final String favoriteColorId;
  final String favoriteAnimalId;
  final String themeId;
  final List<String> interests;
  final DateTime createdAt;
  final DateTime lastVisitedAt;

  const ChildProfile({
    required this.id,
    this.displayName = 'بطل لقاء',
    this.avatarId = 'star_explorer',
    this.favoriteColorId = 'sunny_orange',
    this.favoriteAnimalId = 'animal_bunny',
    this.themeId = 'sunlit_meadow',
    this.interests = const ['الحيوانات', 'الكورة', 'الحكايات'],
    required this.createdAt,
    required this.lastVisitedAt,
  });

  ChildProfile copyWith({
    String? displayName,
    String? avatarId,
    String? favoriteColorId,
    String? favoriteAnimalId,
    String? themeId,
    List<String>? interests,
    DateTime? lastVisitedAt,
  }) {
    return ChildProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId ?? this.avatarId,
      favoriteColorId: favoriteColorId ?? this.favoriteColorId,
      favoriteAnimalId: favoriteAnimalId ?? this.favoriteAnimalId,
      themeId: themeId ?? this.themeId,
      interests: interests ?? this.interests,
      createdAt: createdAt,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'avatar_id': avatarId,
    'favorite_color_id': favoriteColorId,
    'favorite_animal_id': favoriteAnimalId,
    'theme_id': themeId,
    'interests': interests,
    'created_at': createdAt.toIso8601String(),
    'last_visited_at': lastVisitedAt.toIso8601String(),
  };

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ChildProfile(
      id: json['id'] as String? ?? 'profile_default',
      displayName: json['display_name'] as String? ?? 'بطل لقاء',
      avatarId: json['avatar_id'] as String? ?? 'star_explorer',
      favoriteColorId: json['favorite_color_id'] as String? ?? 'sunny_orange',
      favoriteAnimalId: json['favorite_animal_id'] as String? ?? 'animal_bunny',
      themeId: json['theme_id'] as String? ?? 'sunlit_meadow',
      interests: List<String>.from(
        (json['interests'] as List<dynamic>?) ?? const ['الحيوانات', 'الكورة'],
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? now,
      lastVisitedAt:
          DateTime.tryParse(json['last_visited_at'] as String? ?? '') ?? now,
    );
  }

  @override
  List<Object?> get props => [
    id,
    displayName,
    avatarId,
    favoriteColorId,
    favoriteAnimalId,
    themeId,
    interests,
    createdAt,
    lastVisitedAt,
  ];
}

/// Strictly separates participation/listening/discrimination/pronunciation/inconclusive
/// outcomes so engagement rewards are never confused with clinical mastery.
class ActivityOutcomeRecord extends Equatable {
  final String id;
  final String activityId;
  final MiniGameType gameType;
  final WorldRegionId regionId;
  final DateTime timestamp;
  final bool completed;
  final int listeningCorrect;
  final int listeningTotal;
  final int discriminationCorrect;
  final int discriminationTotal;
  final bool? pronunciationPassed;
  final int inconclusiveTechnicalCount;
  final List<String> targetPhonemes;

  const ActivityOutcomeRecord({
    required this.id,
    required this.activityId,
    required this.gameType,
    required this.regionId,
    required this.timestamp,
    this.completed = true,
    this.listeningCorrect = 0,
    this.listeningTotal = 0,
    this.discriminationCorrect = 0,
    this.discriminationTotal = 0,
    this.pronunciationPassed,
    this.inconclusiveTechnicalCount = 0,
    this.targetPhonemes = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'activity_id': activityId,
    'game_type': gameType.id,
    'region_id': regionId.id,
    'timestamp': timestamp.toIso8601String(),
    'completed': completed,
    'listening_correct': listeningCorrect,
    'listening_total': listeningTotal,
    'discrimination_correct': discriminationCorrect,
    'discrimination_total': discriminationTotal,
    'pronunciation_passed': pronunciationPassed,
    'inconclusive_technical_count': inconclusiveTechnicalCount,
    'target_phonemes': targetPhonemes,
  };

  factory ActivityOutcomeRecord.fromJson(Map<String, dynamic> json) {
    return ActivityOutcomeRecord(
      id: json['id'] as String? ?? '',
      activityId: json['activity_id'] as String? ?? '',
      gameType: MiniGameType.fromId(json['game_type'] as String?),
      regionId: WorldRegionId.fromId(json['region_id'] as String?),
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      completed: json['completed'] as bool? ?? true,
      listeningCorrect: json['listening_correct'] as int? ?? 0,
      listeningTotal: json['listening_total'] as int? ?? 0,
      discriminationCorrect: json['discrimination_correct'] as int? ?? 0,
      discriminationTotal: json['discrimination_total'] as int? ?? 0,
      pronunciationPassed: json['pronunciation_passed'] as bool?,
      inconclusiveTechnicalCount:
          json['inconclusive_technical_count'] as int? ?? 0,
      targetPhonemes: List<String>.from(
        (json['target_phonemes'] as List<dynamic>?) ?? const <String>[],
      ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    activityId,
    gameType,
    regionId,
    timestamp,
    completed,
    listeningCorrect,
    listeningTotal,
    discriminationCorrect,
    discriminationTotal,
    pronunciationPassed,
    inconclusiveTechnicalCount,
  ];
}

class ChildWorldState extends Equatable {
  final String profileId;
  final List<String> plantedFlowerIds;
  final List<String> placedHomeDecorationIds;
  final Set<String> unlockedCollectibleIds;
  final Set<String> discoveredWordIds;
  final Set<String> completedActivityIds;
  final Set<String> completedAdventureIds;
  final List<ActivityOutcomeRecord> outcomes;
  final WorldRegionId? lastActiveRegionId;
  final String? lastActiveActivityId;
  final Set<String> unseenCollectibleIds;
  final DateTime? lastSessionAt;

  const ChildWorldState({
    required this.profileId,
    this.plantedFlowerIds = const [],
    this.placedHomeDecorationIds = const [],
    this.unlockedCollectibleIds = const {
      'flower_meadow_daisy',
      'animal_bunny',
      'sticker_yasser_wave',
      'deco_lantern',
    },
    this.discoveredWordIds = const {},
    this.completedActivityIds = const {},
    this.completedAdventureIds = const {},
    this.outcomes = const [],
    this.lastActiveRegionId,
    this.lastActiveActivityId,
    this.unseenCollectibleIds = const {},
    this.lastSessionAt,
  });

  int get listeningTotal => outcomes.fold(0, (s, o) => s + o.listeningTotal);
  int get listeningCorrect =>
      outcomes.fold(0, (s, o) => s + o.listeningCorrect);
  int get discriminationTotal =>
      outcomes.fold(0, (s, o) => s + o.discriminationTotal);
  int get discriminationCorrect =>
      outcomes.fold(0, (s, o) => s + o.discriminationCorrect);
  int get pronunciationAttempts =>
      outcomes.where((o) => o.pronunciationPassed != null).length;
  int get pronunciationPassedCount =>
      outcomes.where((o) => o.pronunciationPassed == true).length;
  int get inconclusiveCount =>
      outcomes.fold(0, (s, o) => s + o.inconclusiveTechnicalCount);

  ChildWorldState copyWith({
    List<String>? plantedFlowerIds,
    List<String>? placedHomeDecorationIds,
    Set<String>? unlockedCollectibleIds,
    Set<String>? discoveredWordIds,
    Set<String>? completedActivityIds,
    Set<String>? completedAdventureIds,
    List<ActivityOutcomeRecord>? outcomes,
    WorldRegionId? lastActiveRegionId,
    String? lastActiveActivityId,
    bool clearLastActiveActivity = false,
    Set<String>? unseenCollectibleIds,
    DateTime? lastSessionAt,
  }) {
    return ChildWorldState(
      profileId: profileId,
      plantedFlowerIds: plantedFlowerIds ?? this.plantedFlowerIds,
      placedHomeDecorationIds:
          placedHomeDecorationIds ?? this.placedHomeDecorationIds,
      unlockedCollectibleIds:
          unlockedCollectibleIds ?? this.unlockedCollectibleIds,
      discoveredWordIds: discoveredWordIds ?? this.discoveredWordIds,
      completedActivityIds: completedActivityIds ?? this.completedActivityIds,
      completedAdventureIds:
          completedAdventureIds ?? this.completedAdventureIds,
      outcomes: outcomes ?? this.outcomes,
      lastActiveRegionId: lastActiveRegionId ?? this.lastActiveRegionId,
      lastActiveActivityId: clearLastActiveActivity
          ? null
          : (lastActiveActivityId ?? this.lastActiveActivityId),
      unseenCollectibleIds: unseenCollectibleIds ?? this.unseenCollectibleIds,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'planted_flower_ids': plantedFlowerIds,
    'placed_home_decoration_ids': placedHomeDecorationIds,
    'unlocked_collectible_ids': unlockedCollectibleIds.toList(),
    'discovered_word_ids': discoveredWordIds.toList(),
    'completed_activity_ids': completedActivityIds.toList(),
    'completed_adventure_ids': completedAdventureIds.toList(),
    'outcomes': outcomes.map((e) => e.toJson()).toList(),
    'last_active_region_id': lastActiveRegionId?.id,
    'last_active_activity_id': lastActiveActivityId,
    'unseen_collectible_ids': unseenCollectibleIds.toList(),
    'last_session_at': lastSessionAt?.toIso8601String(),
  };

  factory ChildWorldState.fromJson(Map<String, dynamic> json) {
    return ChildWorldState(
      profileId: json['profile_id'] as String? ?? 'profile_default',
      plantedFlowerIds: List<String>.from(
        (json['planted_flower_ids'] as List<dynamic>?) ?? const <String>[],
      ),
      placedHomeDecorationIds: List<String>.from(
        (json['placed_home_decoration_ids'] as List<dynamic>?) ??
            const <String>[],
      ),
      unlockedCollectibleIds: Set<String>.from(
        (json['unlocked_collectible_ids'] as List<dynamic>?) ??
            const <String>[
              'flower_meadow_daisy',
              'animal_bunny',
              'sticker_yasser_wave',
              'deco_lantern',
            ],
      ),
      discoveredWordIds: Set<String>.from(
        (json['discovered_word_ids'] as List<dynamic>?) ?? const <String>[],
      ),
      completedActivityIds: Set<String>.from(
        (json['completed_activity_ids'] as List<dynamic>?) ?? const <String>[],
      ),
      completedAdventureIds: Set<String>.from(
        (json['completed_adventure_ids'] as List<dynamic>?) ?? const <String>[],
      ),
      outcomes: ((json['outcomes'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ActivityOutcomeRecord.fromJson)
          .toList(),
      lastActiveRegionId: json['last_active_region_id'] != null
          ? WorldRegionId.fromId(json['last_active_region_id'] as String?)
          : null,
      lastActiveActivityId: json['last_active_activity_id'] as String?,
      unseenCollectibleIds: Set<String>.from(
        (json['unseen_collectible_ids'] as List<dynamic>?) ?? const <String>[],
      ),
      lastSessionAt: json['last_session_at'] != null
          ? DateTime.tryParse(json['last_session_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    profileId,
    plantedFlowerIds,
    placedHomeDecorationIds,
    unlockedCollectibleIds,
    discoveredWordIds,
    completedActivityIds,
    completedAdventureIds,
    outcomes,
    lastActiveRegionId,
    lastActiveActivityId,
    unseenCollectibleIds,
    lastSessionAt,
  ];
}
