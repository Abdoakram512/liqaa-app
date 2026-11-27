import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/animation/yasser/yasser_companion_controller.dart';
import '../../../../core/audio/yasser_audio_coordinator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/world_painters/personal_home_painter.dart';
import '../../../../core/widgets/yasser_audio_settings_sheet.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_speech_bubble.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../authentication/data/repos/auth_repo.dart';
import '../../../home/data/child_progress_service.dart';
import '../../../onboarding/data/repos/onboarding_repo.dart';
import '../../../specialist/presentation/cubits/specialist_cubit.dart';
import '../../data/models/world_models.dart';
import '../../data/world_catalog.dart';
import '../cubits/child_world_cubit.dart';

/// Tab 1 (`عالمي`): Interactive personal home & evolving garden where children
/// greet Yasser, touch flowers & companion animals, open treasure chests,
/// customize their environment persistently, and resume adventures.
class MyPersonalHomeView extends StatefulWidget {
  final VoidCallback onOpenMap;
  final VoidCallback onOpenGames;

  const MyPersonalHomeView({
    super.key,
    required this.onOpenMap,
    required this.onOpenGames,
  });

  @override
  State<MyPersonalHomeView> createState() => _MyPersonalHomeViewState();
}

class _MyPersonalHomeViewState extends State<MyPersonalHomeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breezeController;
  String? _interactiveBubbleText;
  int _animalHopCount = 0;

  @override
  void initState() {
    super.initState();
    _breezeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breezeController.dispose();
    super.dispose();
  }

  void _playTapSfx() {
    if (sl.isRegistered<YasserAudioCoordinator>()) {
      sl<YasserAudioCoordinator>().playSfx(YasserSfx.buttonTap);
    }
  }

  Future<void> _handleLogout() async {
    if (sl.isRegistered<AuthRepo>()) {
      await sl<AuthRepo>().logout();
    }
    if (mounted) context.go(AppRoutes.auth);
  }

  Future<void> _handleReplayOnboarding() async {
    if (sl.isRegistered<OnboardingRepo>()) {
      await sl<OnboardingRepo>().resetOnboarding();
    }
    if (mounted) context.go(AppRoutes.onboarding);
  }

  void _showCustomizeHomeSheet(
    BuildContext context,
    ChildWorldState worldState,
  ) {
    final unlockedFlowers = WorldCatalog.collectibles
        .where(
          (c) =>
              c.kind == CollectibleKind.flower &&
              worldState.unlockedCollectibleIds.contains(c.id),
        )
        .toList();
    final unlockedDecos = WorldCatalog.collectibles
        .where(
          (c) =>
              c.kind == CollectibleKind.decoration &&
              worldState.unlockedCollectibleIds.contains(c.id),
        )
        .toList();

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
        bloc: context.read<ChildWorldCubit>(),
        builder: (ctx, st) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'زيّن بيتك وحديقتك',
                    style: AppTextStyles.headlineMedium,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'اختار الزهور والزينة اللي تحب تبان في بيت ياسر.. كل تغييراتك بتتحفظ فوراً.',
                    style: AppTextStyles.bodySmall,
                  ),
                  SizedBox(height: 14.h),
                  Text('زهور الحديقة', style: AppTextStyles.titleMedium),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: unlockedFlowers.map((fl) {
                      final planted = st.worldState.plantedFlowerIds.contains(
                        fl.id,
                      );
                      return FilterChip(
                        selected: planted,
                        label: Text(fl.titleAr),
                        avatar: IllustratedVocabularyWidget(
                          objectKey: 'flower',
                          accentColor: fl.accentColor,
                          size: 20,
                        ),
                        selectedColor: AppColors.worldGardenSoft,
                        onSelected: (_) => context
                            .read<ChildWorldCubit>()
                            .togglePlantedFlower(fl.id),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 14.h),
                  Text('زينة البيت', style: AppTextStyles.titleMedium),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: unlockedDecos.map((dc) {
                      final placed = st.worldState.placedHomeDecorationIds
                          .contains(dc.id);
                      return FilterChip(
                        selected: placed,
                        label: Text(dc.titleAr),
                        selectedColor: AppColors.primaryContainer,
                        onSelected: (_) => context
                            .read<ChildWorldCubit>()
                            .toggleHomeDecoration(dc.id),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 14.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTreasureChestSheet(
    BuildContext context,
    ChildWorldState worldState,
  ) {
    _playTapSfx();
    context.read<ChildWorldCubit>().markCollectiblesSeen();
    final unlocked = WorldCatalog.collectibles
        .where((c) => worldState.unlockedCollectibleIds.contains(c.id))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'صندوق كنوزك (${unlocked.length})',
                style: AppTextStyles.headlineMedium,
              ),
              SizedBox(height: 8.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: unlocked.length,
                  separatorBuilder: (_, _) => SizedBox(height: 8.h),
                  itemBuilder: (_, idx) {
                    final item = unlocked[idx];
                    return ListTile(
                      shape: YasserShapes.squircle(16),
                      tileColor: AppColors.surfaceSubtle,
                      leading: IllustratedVocabularyWidget(
                        objectKey: item.illustrationKey,
                        accentColor: item.accentColor,
                        size: 40,
                      ),
                      title: Text(
                        item.titleAr,
                        style: AppTextStyles.titleSmall,
                      ),
                      subtitle: Text(
                        item.descriptionAr,
                        style: AppTextStyles.bodySmall,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = YasserMotion.isReducedMotion(context);
    final progressService = sl.isRegistered<ChildProgressService>()
        ? sl<ChildProgressService>()
        : null;
    final specialistCubit = sl.isRegistered<SpecialistCubit>()
        ? sl<SpecialistCubit>()
        : null;

    return PhonologicalBackground(
      variant: PhonologicalSceneVariant.playfulHills,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
          builder: (context, worldCubitState) {
            final profile = worldCubitState.activeProfile;
            final worldState = worldCubitState.worldState;
            final themePreset = WorldCatalog.themes.firstWhere(
              (t) => t.id == profile.themeId,
              orElse: () => WorldCatalog.themes.first,
            );
            final animalItem =
                WorldCatalog.collectibleById(profile.favoriteAnimalId) ??
                WorldCatalog.collectibleById('animal_bunny')!;
            final avatarPreset = WorldCatalog.avatars.firstWhere(
              (a) => a.id == profile.avatarId,
              orElse: () => WorldCatalog.avatars.first,
            );

            final activeAssignment = specialistCubit?.state
                .activeAssignmentForProfile(profile.id);

            final greetingMessage =
                _interactiveBubbleText ??
                WorldContentAdapter.buildDailyGreeting(
                  profile: profile,
                  worldState: worldState,
                  activeAssignment: activeAssignment,
                );

            final targetAdventureRegion =
                worldState.lastActiveRegionId ?? WorldRegionId.soundGarden;
            final targetAdventure = WorldCatalog.adventureForRegion(
              targetAdventureRegion,
            );

            return ListenableBuilder(
              listenable: progressService ?? ChangeNotifier(),
              builder: (context, _) {
                final progress =
                    progressService?.snapshot ?? const ChildProgressSnapshot();

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 24.h),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // 1. Personal Header Bar
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      context.push(AppRoutes.profileSetup),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 4.h,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: ShapeDecoration(
                                            color: themePreset.sky,
                                            shape: YasserShapes.squircle(
                                              16,
                                              side: BorderSide(
                                                color: themePreset.accent,
                                                width: 1.8,
                                              ),
                                            ),
                                          ),
                                          child: Center(
                                            child: IllustratedVocabularyWidget(
                                              objectKey:
                                                  avatarPreset.illustrationKey,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'بيت ${profile.displayName}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    AppTextStyles.headlineSmall,
                                              ),
                                              Text(
                                                'اضغط لتخصيص شخصيتك',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                      color:
                                                          AppColors.primaryDeep,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Flowers & Stars counter
                              DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: AppColors.accentGoldSoft,
                                  shape: YasserShapes.squircle(
                                    14,
                                    side: const BorderSide(
                                      color: AppColors.accentGold,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 7.h,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_florist_rounded,
                                        color: AppColors.worldGardenAccent,
                                        size: 18,
                                      ),
                                      SizedBox(width: 3.w),
                                      Text(
                                        '${worldState.plantedFlowerIds.length}',
                                        style: AppTextStyles.titleSmall,
                                      ),
                                      SizedBox(width: 8.w),
                                      const Icon(
                                        Icons.star_rounded,
                                        color: AppColors.primaryDark,
                                        size: 18,
                                      ),
                                      SizedBox(width: 3.w),
                                      Text(
                                        '${progress.totalStars}',
                                        style: AppTextStyles.titleSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              YasserIconButton(
                                icon: Icons.tune_rounded,
                                tooltip: 'الإعدادات والصوت',
                                onPressed: () {
                                  if (!sl
                                      .isRegistered<YasserAudioCoordinator>()) {
                                    return;
                                  }
                                  showYasserAudioSettingsSheet(
                                    context,
                                    coordinator: sl<YasserAudioCoordinator>(),
                                    onReplayOnboarding: _handleReplayOnboarding,
                                    onLogout: _handleLogout,
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 14.h),

                          // 2. Interactive Living Home & Garden Scene
                          DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: YasserShapes.squircle(
                                28,
                                side: const BorderSide(
                                  color: AppColors.borderSoft,
                                  width: 1.6,
                                ),
                              ),
                              shadows: const [
                                BoxShadow(
                                  color: AppColors.shadowWarm,
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: SizedBox(
                                height: 224.h.clamp(200.0, 260.0),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _breezeController,
                                        builder: (context, _) {
                                          return RepaintBoundary(
                                            child: CustomPaint(
                                              painter: PersonalHomeScenePainter(
                                                themeSkyTop: themePreset.sky,
                                                themeGardenGrass:
                                                    themePreset.grass,
                                                plantedFlowerIds:
                                                    worldState.plantedFlowerIds,
                                                placedDecorationIds: worldState
                                                    .placedHomeDecorationIds,
                                                breezePhase: reduced
                                                    ? 0.0
                                                    : _breezeController.value,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // Interactive Flower Touch Target
                                    Positioned(
                                      left: 16.w,
                                      bottom: 14.h,
                                      child: Semantics(
                                        button: true,
                                        label: 'لمس زهور الحديقة',
                                        child: GestureDetector(
                                          onTap: () {
                                            _playTapSfx();
                                            setState(() {
                                              _interactiveBubbleText =
                                                  'عندك ${worldState.plantedFlowerIds.length} زهرة جميلة في حديقتك! كل مغامرة بتفتح زهرة جديدة.';
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: ShapeDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.88,
                                              ),
                                              shape: YasserShapes.squircle(14),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.palette_rounded,
                                                  size: 16,
                                                  color: AppColors
                                                      .worldGardenAccent,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'الحديقة',
                                                  style: AppTextStyles
                                                      .labelSmall
                                                      .copyWith(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Tappable Companion Animal
                                    Positioned(
                                      left: 102.w,
                                      bottom: 14.h,
                                      child: Semantics(
                                        button: true,
                                        label: 'تفاعل مع ${animalItem.titleAr}',
                                        child: GestureDetector(
                                          onTap: () {
                                            _playTapSfx();
                                            setState(() {
                                              _animalHopCount++;
                                              _interactiveBubbleText =
                                                  '${animalItem.titleAr} مبسوط بيك وبيسلّم عليك!';
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: YasserMotion.effective(
                                              context,
                                              const Duration(milliseconds: 220),
                                            ),
                                            transform:
                                                Matrix4.translationValues(
                                                  0,
                                                  _animalHopCount.isOdd
                                                      ? -6
                                                      : 0,
                                                  0,
                                                ),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IllustratedVocabularyWidget(
                                              objectKey:
                                                  animalItem.illustrationKey,
                                              size: 38,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Interactive Treasure Chest Button
                                    Positioned(
                                      right: 14.w,
                                      top: 12.h,
                                      child: Semantics(
                                        button: true,
                                        label: 'فتح صندوق الكنوز',
                                        child: InkWell(
                                          onTap: () => _showTreasureChestSheet(
                                            context,
                                            worldState,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: DecoratedBox(
                                            decoration: ShapeDecoration(
                                              color: AppColors.accentGoldSoft,
                                              shape: YasserShapes.squircle(
                                                14,
                                                side: const BorderSide(
                                                  color: AppColors.accentGold,
                                                  width: 1.4,
                                                ),
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.inventory_2_rounded,
                                                    size: 16,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    'الكنوز (${worldState.unlockedCollectibleIds.length})',
                                                    style: AppTextStyles
                                                        .labelSmall
                                                        .copyWith(
                                                          color: AppColors
                                                              .primaryDeep,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Customize Home button
                                    Positioned(
                                      left: 14.w,
                                      top: 12.h,
                                      child: InkWell(
                                        onTap: () => _showCustomizeHomeSheet(
                                          context,
                                          worldState,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        child: DecoratedBox(
                                          decoration: ShapeDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.92,
                                            ),
                                            shape: YasserShapes.squircle(14),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.brush_rounded,
                                                  size: 15,
                                                  color: AppColors.primaryDark,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'زيّن بيتك',
                                                  style: AppTextStyles
                                                      .labelSmall
                                                      .copyWith(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Yasser Companion standing in his home yard
                                    Positioned(
                                      right: 26.w,
                                      bottom: 6.h,
                                      child: Hero(
                                        tag: 'yasser_primary_stage_hero',
                                        child: YasserCharacter(
                                          state: YasserAnimationState.greeting,
                                          width: 112.w.clamp(98.0, 128.0),
                                          height: 154.h.clamp(138.0, 176.0),
                                          enableTapReaction: true,
                                          onTap: () {
                                            _playTapSfx();
                                            if (sl
                                                .isRegistered<
                                                  YasserCompanionController
                                                >()) {
                                              sl<YasserCompanionController>()
                                                  .speakLine(
                                                    scriptId: 'g01',
                                                    arabicText:
                                                        'أهلاً يا ${profile.displayName}! مبسوط إني معاك النهاردة.',
                                                  );
                                            }
                                            setState(() {
                                              _interactiveBubbleText =
                                                  'أهلاً يا ${profile.displayName}! مبسوط إني معاك النهاردة.';
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // 3. Contextual Speech Bubble from Yasser
                          YasserSpeechBubble(
                            tailDirection: SpeechBubbleTailDirection.top,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    greetingMessage,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'اسمع كلام ياسر',
                                  onPressed: () {
                                    if (sl
                                        .isRegistered<
                                          YasserCompanionController
                                        >()) {
                                      sl<YasserCompanionController>().speakLine(
                                        scriptId: 'g02',
                                        arabicText: greetingMessage,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.volume_up_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // 4. Specialist-Assigned Adventure Highlight (if any)
                          if (activeAssignment != null) ...[
                            YasserSurfaceCard(
                              backgroundColor: AppColors.secondaryUltraLight,
                              borderColor: AppColors.secondary.withValues(
                                alpha: 0.35,
                              ),
                              padding: EdgeInsets.all(14.w),
                              onTap: () => context.push(
                                '/adventure/${activeAssignment.assignedRegionId}',
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: ShapeDecoration(
                                      color: AppColors.secondaryContainer,
                                      shape: YasserShapes.squircle(14),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'مغامرة مقترحة لك: ${activeAssignment.title}',
                                          style: AppTextStyles.titleSmall,
                                        ),
                                        Text(
                                          'أصوات مقترحة: ${activeAssignment.targetPhonemes.join(' • ')}',
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: AppColors.secondary,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 14.h),
                          ],

                          // 5. Primary Adventure Journey Card (The Garden Adventure / Next Adventure)
                          YasserSurfaceCard(
                            backgroundColor: AppColors.surface,
                            borderColor: targetAdventure.regionId.accentColor
                                .withValues(alpha: 0.4),
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    DecoratedBox(
                                      decoration: ShapeDecoration(
                                        color:
                                            targetAdventure.regionId.softColor,
                                        shape: YasserShapes.squircle(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Icon(
                                          targetAdventure.regionId.icon,
                                          color: targetAdventure
                                              .regionId
                                              .accentColor,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            targetAdventure.titleAr,
                                            style: AppTextStyles.titleLarge,
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            targetAdventure.storyGoalAr,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 14.h),
                                PrimaryButton(
                                  label: 'ابدأ المغامرة الآن',
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  onPressed: () {
                                    _playTapSfx();
                                    context.push(
                                      '/adventure/${targetAdventure.regionId.id}',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // 6. Quick Explore Shortcuts (World Map & All 8 Games)
                          Row(
                            children: [
                              Expanded(
                                child: YasserSurfaceCard(
                                  padding: EdgeInsets.all(14.w),
                                  backgroundColor: AppColors.worldGardenSoft,
                                  onTap: widget.onOpenMap,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.map_rounded,
                                        color: AppColors.worldGardenAccent,
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'خريطة العالم',
                                        style: AppTextStyles.titleSmall,
                                      ),
                                      Text(
                                        '٦ مناطق ومغامرات',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: YasserSurfaceCard(
                                  padding: EdgeInsets.all(14.w),
                                  backgroundColor: AppColors.worldIslandSoft,
                                  onTap: widget.onOpenGames,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.extension_rounded,
                                        color: AppColors.worldIslandAccent,
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'ألعاب الأصوات',
                                        style: AppTextStyles.titleSmall,
                                      ),
                                      Text(
                                        '٨ ألعاب تفاعلية',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (kDebugMode) ...[
                            SizedBox(height: 16.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: [
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.science_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('مختبر الذكاء'),
                                  onPressed: () =>
                                      context.push(AppRoutes.aiLab),
                                ),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.animation_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('مختبر ياسر'),
                                  onPressed: () =>
                                      context.push(AppRoutes.animationLab),
                                ),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.medical_services_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('لوحة الأخصائي'),
                                  onPressed: () => context.push(
                                    AppRoutes.specialistDashboard,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
