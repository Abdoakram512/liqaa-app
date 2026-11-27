import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/world_clippers.dart';
import '../../../../core/widgets/world_painters/illustrated_object_painter.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../data/models/world_models.dart';
import '../../data/world_catalog.dart';
import '../cubits/child_world_cubit.dart';

/// Narrative chapter overview for any [WorldRegionId] showing its story goal,
/// ordered playful steps, reward preview, and step-by-step launchers.
class AdventureDetailView extends StatelessWidget {
  final WorldRegionId regionId;

  const AdventureDetailView({super.key, required this.regionId});

  void _launchStep(
    BuildContext context,
    WorldAdventure adventure,
    int stepIndex,
  ) {
    final step = adventure.steps[stepIndex];
    final isLast = stepIndex == adventure.steps.length - 1;
    final uri = Uri(
      path: '/activity/${step.gameType.id}',
      queryParameters: {
        'regionId': regionId.id,
        'adventureId': adventure.id,
        'stepId': step.id,
        'stepIndex': '$stepIndex',
        'totalSteps': '${adventure.steps.length}',
        'words': step.targetWordIds.join(','),
        if (isLast) 'rewardId': adventure.rewardCollectibleId,
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final adventure = WorldCatalog.adventureForRegion(regionId);
    final reward = WorldCatalog.collectibleById(adventure.rewardCollectibleId);

    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.playfulHills,
        child: SafeArea(
          child: BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
            builder: (context, cubitState) {
              final world = cubitState.worldState;
              final completedCount = adventure.steps
                  .where((s) => world.completedActivityIds.contains(s.id))
                  .length;
              final nextIncompleteIdx = adventure.steps.indexWhere(
                (s) => !world.completedActivityIds.contains(s.id),
              );
              final startIndex = nextIncompleteIdx >= 0 ? nextIncompleteIdx : 0;

              return Column(
                children: [
                  ClipPath(
                    clipper: const StoryHeaderWaveClipper(waveHeight: 16),
                    child: Container(
                      width: double.infinity,
                      color: regionId.softColor,
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 26.h),
                      child: Row(
                        children: [
                          YasserIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'رجوع للخريطة',
                            onPressed: () => context.pop(),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  regionId.titleAr,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: regionId.deepColor,
                                  ),
                                ),
                                Text(
                                  adventure.titleAr,
                                  style: AppTextStyles.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            regionId.icon,
                            size: 36,
                            color: regionId.accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 24.h),
                      children: [
                        // Yasser narrative invitation + reward preview
                        YasserSurfaceCard(
                          padding: EdgeInsets.all(14.w),
                          child: Row(
                            children: [
                              const YasserCharacter(
                                state: YasserAnimationState.pointing,
                                width: 82,
                                height: 112,
                                showShadow: false,
                                enableTapReaction: false,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      adventure.storyGoalAr,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (reward != null) ...[
                                      SizedBox(height: 8.h),
                                      Row(
                                        children: [
                                          IllustratedVocabularyWidget(
                                            objectKey: reward.illustrationKey,
                                            accentColor: reward.accentColor,
                                            size: 26,
                                          ),
                                          SizedBox(width: 6.w),
                                          Expanded(
                                            child: Text(
                                              'الهدية: ${reward.titleAr}',
                                              style: AppTextStyles.labelMedium
                                                  .copyWith(
                                                    color: regionId.deepColor,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 14.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'خطوات المغامرة',
                              style: AppTextStyles.titleMedium,
                            ),
                            Text(
                              '$completedCount / ${adventure.steps.length} مكتملة',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: regionId.deepColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        ...List.generate(adventure.steps.length, (i) {
                          final step = adventure.steps[i];
                          final isDone = world.completedActivityIds.contains(
                            step.id,
                          );
                          return Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: YasserSurfaceCard(
                              padding: EdgeInsets.all(14.w),
                              borderColor: isDone
                                  ? AppColors.success
                                  : (i == startIndex
                                        ? regionId.accentColor
                                        : AppColors.borderSoft),
                              onTap: () => _launchStep(context, adventure, i),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: ShapeDecoration(
                                      color: isDone
                                          ? AppColors.successSoft
                                          : regionId.softColor,
                                      shape: YasserShapes.squircle(14),
                                    ),
                                    child: Icon(
                                      isDone
                                          ? Icons.check_rounded
                                          : step.gameType.icon,
                                      color: isDone
                                          ? AppColors.successDark
                                          : regionId.accentColor,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.titleAr,
                                          style: AppTextStyles.titleSmall,
                                        ),
                                        Text(
                                          step.subtitleAr,
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: regionId.accentColor,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        SizedBox(height: 10.h),
                        PrimaryButton(
                          label: completedCount == adventure.steps.length
                              ? 'إعادة المغامرة للمتعة'
                              : 'العب الخطوة التالية',
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: () =>
                              _launchStep(context, adventure, startIndex),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
