import 'package:flutter/material.dart';

import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/theme/app_colors.dart';
import '../../specialist/data/models/specialist_models.dart';
import 'models/world_models.dart';

/// Curated Egyptian Arabic content, adventures, minimal pairs, mini-stories,
/// and non-punitive collectible rewards powering Yasser's living world.
abstract final class WorldCatalog {
  static const List<
    ({String id, String labelAr, Color sky, Color grass, Color accent})
  >
  themes = [
    (
      id: 'sunlit_meadow',
      labelAr: 'مرج الشمس',
      sky: Color(0xFFFFEFC7),
      grass: Color(0xFFD5F2C9),
      accent: AppColors.primary,
    ),
    (
      id: 'sky_breeze',
      labelAr: 'نسيم البحر',
      sky: Color(0xFFE3F2FD),
      grass: Color(0xFFCDEEE5),
      accent: AppColors.accentSky,
    ),
    (
      id: 'berry_garden',
      labelAr: 'حديقة التوت',
      sky: Color(0xFFF3EFFF),
      grass: Color(0xFFDDF3DA),
      accent: AppColors.secondary,
    ),
    (
      id: 'golden_sand',
      labelAr: 'واحة النخيل',
      sky: Color(0xFFFFEBD2),
      grass: Color(0xFFEAE3B6),
      accent: AppColors.worldForestAccent,
    ),
  ];

  static const List<({String id, String labelAr, String illustrationKey})>
  avatars = [
    (id: 'star_explorer', labelAr: 'مستكشف النجوم', illustrationKey: 'star'),
    (id: 'kind_bunny', labelAr: 'أرنوب السريع', illustrationKey: 'arnab'),
    (id: 'sea_dolphin', labelAr: 'سمكة النهر', illustrationKey: 'samaka'),
    (id: 'smart_owl', labelAr: 'الهدهد الذكي', illustrationKey: 'hodhod'),
    (id: 'cute_cat', labelAr: 'القطة اللطيفة', illustrationKey: '2etta'),
    (id: 'sunny_duck', labelAr: 'البطة الشقية', illustrationKey: 'batta'),
  ];

  static const List<CollectibleItem> collectibles = [
    // Flowers (plantable inside My Personal Home)
    CollectibleItem(
      id: 'flower_meadow_daisy',
      kind: CollectibleKind.flower,
      titleAr: 'زهرة البداية',
      descriptionAr: 'أول وردة جميلة بترحب بيك في بيت ياسر!',
      regionId: WorldRegionId.yasserHome,
      illustrationKey: 'flower',
      accentColor: AppColors.primary,
    ),
    CollectibleItem(
      id: 'flower_sun_garden',
      kind: CollectibleKind.flower,
      titleAr: 'زهرة الشمس الذهبية',
      descriptionAr: 'نمت بعد مغامرتك في حديقة الأصوات!',
      regionId: WorldRegionId.soundGarden,
      illustrationKey: 'flower',
      accentColor: AppColors.worldGardenAccent,
    ),
    CollectibleItem(
      id: 'flower_forest_lily',
      kind: CollectibleKind.flower,
      titleAr: 'زنبقة الغابة',
      descriptionAr: 'هدية من أصدقاء الحيوانات اللطيفة.',
      regionId: WorldRegionId.animalForest,
      illustrationKey: 'flower',
      accentColor: AppColors.worldForestAccent,
    ),
    CollectibleItem(
      id: 'flower_island_bloom',
      kind: CollectibleKind.flower,
      titleAr: 'زهرة الجزيرة الزرقاء',
      descriptionAr: 'تفتّحت بعد عبور كوبري جزيرة الكلمات!',
      regionId: WorldRegionId.wordIsland,
      illustrationKey: 'flower',
      accentColor: AppColors.worldIslandAccent,
    ),
    CollectibleItem(
      id: 'flower_story_violet',
      kind: CollectibleKind.flower,
      titleAr: 'بنفسجة الحكايات',
      descriptionAr: 'تنمو لما تساعد ياسر يكمّل القصص.',
      regionId: WorldRegionId.storyCity,
      illustrationKey: 'flower',
      accentColor: AppColors.worldStoryAccent,
    ),

    // Companion Animals
    CollectibleItem(
      id: 'animal_bunny',
      kind: CollectibleKind.animal,
      titleAr: 'الأرنب فرفور',
      descriptionAr: 'ينط في الحديقة لما تلمسه!',
      regionId: WorldRegionId.yasserHome,
      illustrationKey: 'arnab',
      accentColor: AppColors.accentCoral,
    ),
    CollectibleItem(
      id: 'animal_duck',
      kind: CollectibleKind.animal,
      titleAr: 'البطة توتة',
      descriptionAr: 'بتحب صوت الطاء والميه الصافية.',
      regionId: WorldRegionId.animalForest,
      illustrationKey: 'batta',
      accentColor: AppColors.accentGold,
    ),
    CollectibleItem(
      id: 'animal_cat',
      kind: CollectibleKind.animal,
      titleAr: 'القطة مشمشة',
      descriptionAr: 'بتنام جنب بيت ياسر وتسلّم عليك.',
      regionId: WorldRegionId.yasserHome,
      illustrationKey: '2etta',
      accentColor: AppColors.primary,
    ),
    CollectibleItem(
      id: 'animal_butterfly',
      kind: CollectibleKind.animal,
      titleAr: 'الفراشة لولي',
      descriptionAr: 'بتطير فوق الزهور في حديقة الأصوات.',
      regionId: WorldRegionId.soundGarden,
      illustrationKey: 'farasha',
      accentColor: AppColors.secondary,
    ),

    // Home Decorations
    CollectibleItem(
      id: 'deco_lantern',
      kind: CollectibleKind.decoration,
      titleAr: 'فانوس البيت الدافي',
      descriptionAr: 'فانوس صغير منوّر جنب باب بيت ياسر.',
      regionId: WorldRegionId.yasserHome,
      illustrationKey: 'house',
      accentColor: AppColors.accentGold,
    ),
    CollectibleItem(
      id: 'deco_rainbow',
      kind: CollectibleKind.decoration,
      titleAr: 'قوس قزح الحديقة',
      descriptionAr: 'قوس ألوان مبهج في سماء بيتك.',
      regionId: WorldRegionId.wordIsland,
      illustrationKey: 'sun',
      accentColor: AppColors.accentCoral,
    ),

    // Stickers, Story Pages & Adventure Badges
    CollectibleItem(
      id: 'sticker_yasser_wave',
      kind: CollectibleKind.sticker,
      titleAr: 'ملصق تحية ياسر',
      descriptionAr: 'أهلاً بك في عالم ياسر الصوتي!',
      regionId: WorldRegionId.yasserHome,
      illustrationKey: 'boy',
      accentColor: AppColors.primary,
    ),
    CollectibleItem(
      id: 'badge_garden_explorer',
      kind: CollectibleKind.badge,
      titleAr: 'وسام مزارع الأصوات',
      descriptionAr: 'أتممت مغامرة حديقة الأصوات بمرح!',
      regionId: WorldRegionId.soundGarden,
      illustrationKey: 'star',
      accentColor: AppColors.worldGardenAccent,
    ),
    CollectibleItem(
      id: 'badge_forest_friend',
      kind: CollectibleKind.badge,
      titleAr: 'وسام صديق الحيوانات',
      descriptionAr: 'سمعت وميّزت أصوات أصحاب الغابة.',
      regionId: WorldRegionId.animalForest,
      illustrationKey: 'kalb',
      accentColor: AppColors.worldForestAccent,
    ),
    CollectibleItem(
      id: 'badge_island_captain',
      kind: CollectibleKind.badge,
      titleAr: 'وسام كابتن الجزيرة',
      descriptionAr: 'اكتشفت كنوز جزيرة الكلمات!',
      regionId: WorldRegionId.wordIsland,
      illustrationKey: 'samaka',
      accentColor: AppColors.worldIslandAccent,
    ),
    CollectibleItem(
      id: 'story_garden_ball',
      kind: CollectibleKind.storyPage,
      titleAr: 'صفحة: كورة ياسر الحمرا',
      descriptionAr: 'حكاية الكورة اللي اتدحرجت وسط الورد.',
      regionId: WorldRegionId.storyCity,
      illustrationKey: 'kora',
      accentColor: AppColors.worldStoryAccent,
    ),
    CollectibleItem(
      id: 'badge_castle_hero',
      kind: CollectibleKind.badge,
      titleAr: 'تاج بطل الحروف',
      descriptionAr: 'أنهيت تحدي قلعة الأبطال بكل ثقة!',
      regionId: WorldRegionId.heroCastle,
      illustrationKey: 'dahab',
      accentColor: AppColors.worldCastleAccent,
    ),
  ];

  static CollectibleItem? collectibleById(String id) {
    for (final c in collectibles) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Complete adventures across all 6 world regions.
  /// Leading flagship vertical slice: `adv_sound_garden` (5 connected steps!).
  static const List<WorldAdventure> adventures = [
    WorldAdventure(
      id: 'adv_sound_garden',
      regionId: WorldRegionId.soundGarden,
      titleAr: 'مغامرة حديقة الأصوات',
      storyGoalAr:
          'الحديقة محتاجة زهور جديدة! استكشف الكلمات واسمع الأصوات وانطقها مع ياسر لتتفتح زهرة الشمس الذهبية.',
      rewardCollectibleId: 'flower_sun_garden',
      steps: [
        AdventureStep(
          id: 'garden_step_1',
          titleAr: '١. اكتشف كلمات الحديقة',
          subtitleAr: 'المس الصور واسمع أصواتها مع ياسر',
          gameType: MiniGameType.discoverWord,
          targetWordIds: ['word_kora', 'word_samaka', 'word_shams'],
        ),
        AdventureStep(
          id: 'garden_step_2',
          titleAr: '٢. اسمع الفرق بودانك',
          subtitleAr: 'ميّز بين الكلمات المتقاربة في الصوت',
          gameType: MiniGameType.hearDifference,
          targetWordIds: ['word_kora', 'word_samaka'],
        ),
        AdventureStep(
          id: 'garden_step_3',
          titleAr: '٣. اسمع واختار الصورة',
          subtitleAr: 'دوس على الصورة اللي قالها ياسر',
          gameType: MiniGameType.listenAndChoose,
          targetWordIds: [
            'word_kora',
            'word_samaka',
            'word_shams',
            'word_farasha',
          ],
        ),
        AdventureStep(
          id: 'garden_step_4',
          titleAr: '٤. ردّد وراء ياسر',
          subtitleAr: 'اسمع النطق الواضح وبعدها جرّب بصوتك',
          gameType: MiniGameType.repeatAfterYasser,
          targetWordIds: ['word_kora', 'word_samaka'],
        ),
        AdventureStep(
          id: 'garden_step_5',
          titleAr: '٥. سمّي الصورة بنفسك',
          subtitleAr: 'قول اسم الصورة لياسر وافتح الزهرة الذهبية!',
          gameType: MiniGameType.nameThePicture,
          targetWordIds: ['word_kora', 'word_batta', 'word_2etta'],
        ),
      ],
    ),
    WorldAdventure(
      id: 'adv_yasser_home',
      regionId: WorldRegionId.yasserHome,
      titleAr: 'كنوز بيت ياسر',
      storyGoalAr:
          'افتح صناديق الأصوات السرية في بيتك واجمع زينة جميلة لبيت ياسر.',
      rewardCollectibleId: 'deco_rainbow',
      steps: [
        AdventureStep(
          id: 'home_step_1',
          titleAr: '١. اكتشف أشياء البيت',
          subtitleAr: 'بيت، باب، كتاب، قلم',
          gameType: MiniGameType.discoverWord,
          targetWordIds: ['word_beit', 'word_bab', 'word_ketab', 'word_alam'],
        ),
        AdventureStep(
          id: 'home_step_2',
          titleAr: '٢. صناديق الأصوات السرية',
          subtitleAr: 'افتح الصندوق ووصّل الصوت بالصورة',
          gameType: MiniGameType.mysterySoundBoxes,
          targetWordIds: ['word_beit', 'word_ketab', 'word_alam'],
        ),
      ],
    ),
    WorldAdventure(
      id: 'adv_animal_forest',
      regionId: WorldRegionId.animalForest,
      titleAr: 'رحلة غابة الحيوانات',
      storyGoalAr:
          'أصحابنا الحيوانات مستنيين نعرف أسماءهم وأصواتهم عشان نزور البط والقطط في الحديقة.',
      rewardCollectibleId: 'animal_duck',
      steps: [
        AdventureStep(
          id: 'forest_step_1',
          titleAr: '١. قابل حيوانات الغابة',
          subtitleAr: 'أرنب، بطة، كلب، قطة، زرافة',
          gameType: MiniGameType.discoverWord,
          targetWordIds: [
            'word_arnab',
            'word_batta',
            'word_kalb',
            'word_2etta',
          ],
        ),
        AdventureStep(
          id: 'forest_step_2',
          titleAr: '٢. محقق الأصوات في الغابة',
          subtitleAr: 'طلّع الحيوانات اللي بتبدأ بنفس الصوت',
          gameType: MiniGameType.soundDetective,
          targetWordIds: [
            'word_arnab',
            'word_batta',
            'word_kalb',
            'word_2etta',
          ],
        ),
        AdventureStep(
          id: 'forest_step_3',
          titleAr: '٣. سمّي حيوانات الغابة',
          subtitleAr: 'انطق أسماء الأصحاب بصوت واضح',
          gameType: MiniGameType.nameThePicture,
          targetWordIds: ['word_arnab', 'word_batta', 'word_2etta'],
        ),
      ],
    ),
    WorldAdventure(
      id: 'adv_word_island',
      regionId: WorldRegionId.wordIsland,
      titleAr: 'كنوز جزيرة الكلمات',
      storyGoalAr:
          'اعبر الكوبري الخشبي واكتشف الفواكه والمواصلات لفتح زهرة الجزيرة الزرقاء.',
      rewardCollectibleId: 'flower_island_bloom',
      steps: [
        AdventureStep(
          id: 'island_step_1',
          titleAr: '١. اسمع واختار من الجزيرة',
          subtitleAr: 'تفاحة، موزة، عربية، طيارة',
          gameType: MiniGameType.listenAndChoose,
          targetWordIds: [
            'word_tofa7a',
            'word_moza',
            'word_3arabeya',
            'word_tayara',
          ],
        ),
        AdventureStep(
          id: 'island_step_2',
          titleAr: '٢. صناديق كنز الجزيرة',
          subtitleAr: 'طابق الصوت بالصورة السرية',
          gameType: MiniGameType.mysterySoundBoxes,
          targetWordIds: ['word_tofa7a', 'word_moza', 'word_tayara'],
        ),
      ],
    ),
    WorldAdventure(
      id: 'adv_story_city',
      regionId: WorldRegionId.storyCity,
      titleAr: 'حكايات مدينة القصص',
      storyGoalAr:
          'اسمع حكايات ياسر وأكمل الكلمات الناقصة لفتح صفحة قصة جديدة في ألبومك.',
      rewardCollectibleId: 'story_garden_ball',
      steps: [
        AdventureStep(
          id: 'story_step_1',
          titleAr: '١. أكمل الحكاية مع ياسر',
          subtitleAr: 'اختار الكلمة اللي تكمّل الصورة',
          gameType: MiniGameType.completeTheStory,
          targetWordIds: [
            'word_kora',
            'word_samaka',
            'word_arnab',
            'word_tofa7a',
          ],
        ),
        AdventureStep(
          id: 'story_step_2',
          titleAr: '٢. ردّد بطل القصة',
          subtitleAr: 'قول كلمة الحكاية بصوتك',
          gameType: MiniGameType.repeatAfterYasser,
          targetWordIds: ['word_kora', 'word_samaka'],
        ),
      ],
    ),
    WorldAdventure(
      id: 'adv_hero_castle',
      regionId: WorldRegionId.heroCastle,
      titleAr: 'تحدي قلعة الأبطال',
      storyGoalAr:
          'جرّب تمييز الأصوات والتحقيق في القلعة واكسب تاج بطل الحروف!',
      rewardCollectibleId: 'badge_castle_hero',
      steps: [
        AdventureStep(
          id: 'castle_step_1',
          titleAr: '١. اسمع الفرق السريع',
          subtitleAr: 'اختبر تركيز ودانك في القلعة',
          gameType: MiniGameType.hearDifference,
          targetWordIds: ['word_kora', 'word_batta', 'word_shams'],
        ),
        AdventureStep(
          id: 'castle_step_2',
          titleAr: '٢. محقق القلعة',
          subtitleAr: 'جمّع كلمات الحرف المطلوب',
          gameType: MiniGameType.soundDetective,
          targetWordIds: ['word_kalb', 'word_ketab', 'word_kora', 'word_shams'],
        ),
      ],
    ),
  ];

  static WorldAdventure adventureForRegion(WorldRegionId region) => adventures
      .firstWhere((a) => a.regionId == region, orElse: () => adventures.first);

  /// Specialist-reviewed Egyptian Arabic minimal pair stimuli for Game 2 (Hear the Difference).
  static const List<MinimalPairItem> minimalPairs = [
    MinimalPairItem(
      id: 'mp_kora_tora',
      wordA: 'كورة',
      wordB: 'تورة',
      targetPhonemeA: 'ك',
      contrastPhonemeB: 'ت',
      illustrationKeyA: 'kora',
      illustrationKeyB: 'kora',
      hintAr: 'ركّز في أول حرف: كـ كورة ولا تـ تورة؟',
    ),
    MinimalPairItem(
      id: 'mp_samaka_samaka',
      wordA: 'سمكة',
      wordB: 'سمكة',
      targetPhonemeA: 'س',
      contrastPhonemeB: 'س',
      illustrationKeyA: 'samaka',
      illustrationKeyB: 'samaka',
      hintAr: 'اسمع الكلمتين بنفس الصوت السليم: سمكة!',
    ),
    MinimalPairItem(
      id: 'mp_samaka_thamaka',
      wordA: 'سمكة',
      wordB: 'ثمكة',
      targetPhonemeA: 'س',
      contrastPhonemeB: 'ث',
      illustrationKeyA: 'samaka',
      illustrationKeyB: 'samaka',
      hintAr: 'السين صفارة ناعمة، أما الثاء بين الأسنان!',
    ),
    MinimalPairItem(
      id: 'mp_arnab_anlab',
      wordA: 'أرنب',
      wordB: 'أنلب',
      targetPhonemeA: 'ر',
      contrastPhonemeB: 'ل',
      illustrationKeyA: 'arnab',
      illustrationKeyB: 'arnab',
      hintAr: 'اسمع حرف الراء المهتز في أرنب!',
    ),
    MinimalPairItem(
      id: 'mp_kora_kora',
      wordA: 'كورة',
      wordB: 'كورة',
      targetPhonemeA: 'ك',
      contrastPhonemeB: 'ك',
      illustrationKeyA: 'kora',
      illustrationKeyB: 'kora',
      hintAr: 'الاتنين نطقوا كورة بنفس الصوت!',
    ),
    MinimalPairItem(
      id: 'mp_batta_batta_t',
      wordA: 'بطة',
      wordB: 'بتة',
      targetPhonemeA: 'ط',
      contrastPhonemeB: 'ت',
      illustrationKeyA: 'batta',
      illustrationKeyB: 'batta',
      hintAr: 'الطاء صوتها تخين ومفخم غير التاء الرفيعة!',
    ),
    MinimalPairItem(
      id: 'mp_shams_sams',
      wordA: 'شمس',
      wordB: 'سمس',
      targetPhonemeA: 'ش',
      contrastPhonemeB: 'س',
      illustrationKeyA: 'shams',
      illustrationKeyB: 'shams',
      hintAr: 'الشين فيها ششش.. غير السين سسس!',
    ),
    MinimalPairItem(
      id: 'mp_batta_same',
      wordA: 'بطة',
      wordB: 'بطة',
      targetPhonemeA: 'ط',
      contrastPhonemeB: 'ط',
      illustrationKeyA: 'batta',
      illustrationKeyB: 'batta',
      hintAr: 'الكلمتين طلعوا بطة بوضوح!',
    ),
  ];

  /// Illustrated Egyptian Arabic mini-stories for Game 8 (Complete the Story).
  static const List<StoryChallengeItem> stories = [
    StoryChallengeItem(
      id: 'story_1',
      regionId: WorldRegionId.soundGarden,
      titleAr: 'كورة في الحديقة',
      storyPrefixAr: 'في يوم جميل، ياسر نزل الحديقة وشاط',
      storySuffixAr: 'الألوان بين الزهور!',
      missingWordId: 'word_kora',
      missingWordArabic: 'الكورة',
      distractorWordIds: ['word_ketab', 'word_samaka', 'word_bab'],
      targetPhoneme: 'ك',
    ),
    StoryChallengeItem(
      id: 'story_2',
      regionId: WorldRegionId.wordIsland,
      titleAr: 'النهر الأزرق',
      storyPrefixAr: 'عند الميه الصافية، البطة شافت',
      storySuffixAr: 'بتعوم وتضحك معاها!',
      missingWordId: 'word_samaka',
      missingWordArabic: 'السمكة',
      distractorWordIds: ['word_tayara', 'word_shams', 'word_alam'],
      targetPhoneme: 'س',
    ),
    StoryChallengeItem(
      id: 'story_3',
      regionId: WorldRegionId.animalForest,
      titleAr: 'فطار الغابة',
      storyPrefixAr: 'نط الأرنب فرفور ورا الشجرة وأكل',
      storySuffixAr: 'حمرا مسكرة!',
      missingWordId: 'word_tofa7a',
      missingWordArabic: 'تفاحة',
      distractorWordIds: ['word_3arabeya', 'word_bab', 'word_kalb'],
      targetPhoneme: 'ح',
    ),
    StoryChallengeItem(
      id: 'story_4',
      regionId: WorldRegionId.storyCity,
      titleAr: 'السماء الصافية',
      storyPrefixAr: 'بص ياسر لفوق في السماء وشاف',
      storySuffixAr: 'بتلمع فوق السحاب!',
      missingWordId: 'word_shams',
      missingWordArabic: 'شمس',
      distractorWordIds: ['word_batta', 'word_moza', 'word_feel'],
      targetPhoneme: 'ش',
    ),
  ];
}

/// Transparent rules selecting daily greetings and personalized word sets
/// based on child preferences, local progress, and specialist assignments
/// (never infers clinical diagnoses).
abstract final class WorldContentAdapter {
  static String buildDailyGreeting({
    required ChildProfile profile,
    required ChildWorldState worldState,
    SpecialistActivityAssignment? activeAssignment,
  }) {
    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'بطل';

    if (worldState.unseenCollectibleIds.isNotEmpty) {
      final col = WorldCatalog.collectibleById(
        worldState.unseenCollectibleIds.first,
      );
      if (col != null) {
        return 'أهلاً يا $name! صندوق الكنز فيه "${col.titleAr}" مستنياك تشوفها!';
      }
    }

    if (activeAssignment != null && activeAssignment.isActive) {
      final phonemes = activeAssignment.targetPhonemes.join(' • ');
      return 'أهلاً يا $name! الأخصائي جهّزلك مغامرة مخصصة لأصوات ($phonemes) لما تحب تبدأ.';
    }

    if (worldState.completedAdventureIds.isEmpty &&
        worldState.outcomes.isEmpty) {
      return 'أهلاً يا $name! أنا ياسر صاحبك، يلا نبدأ أول مغامرة في حديقة الأصوات!';
    }

    if (worldState.lastSessionAt != null &&
        DateTime.now().difference(worldState.lastSessionAt!).inHours >= 48) {
      return 'نورت بيتك من تاني يا $name! خد وقتك واختار أي لعبة تحبها.';
    }

    if (worldState.lastActiveActivityId != null &&
        !worldState.completedActivityIds.contains(
          worldState.lastActiveActivityId,
        )) {
      return 'أهلاً يا $name! نقدر نكمّل رحلتنا من المكان اللي وقفنا عنده أو نستكشف مكان جديد.';
    }

    if (worldState.completedAdventureIds.isNotEmpty) {
      return 'يا سلام يا $name! زرعت ${worldState.plantedFlowerIds.length} زهور جميلة وجمّعت ${worldState.discoveredWordIds.length} كلمة!';
    }

    return 'أهلاً يا $name! جاهز نلعب ونسمع أصوات جديدة النهاردة؟';
  }

  /// Transparently prioritizes words matching specialist target phonemes,
  /// difficulty ceiling, child's undiscovered words, and preferred interests.
  static List<VocabularyWord> selectWords({
    required List<VocabularyWord> dictionary,
    List<String>? targetPhonemes,
    int? maxDifficulty,
    Set<String> discoveredWordIds = const {},
    int limit = 5,
  }) {
    final normalizedTargets = (targetPhonemes ?? const [])
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet();

    final scored = <(VocabularyWord word, int score)>[];
    for (final w in dictionary) {
      int score = 0;
      if (normalizedTargets.isNotEmpty &&
          normalizedTargets.contains(w.targetPhoneme.trim())) {
        score += 100;
      }
      if (maxDifficulty != null && w.difficultyLevel <= maxDifficulty) {
        score += 25;
      }
      if (!discoveredWordIds.contains(w.id)) {
        score += 15;
      }
      if (w.id == 'word_kora' ||
          w.id == 'word_samaka' ||
          w.id == 'word_batta' ||
          w.id == 'word_2etta') {
        score += 5;
      }
      scored.add((w, score));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList(growable: false);
  }
}
