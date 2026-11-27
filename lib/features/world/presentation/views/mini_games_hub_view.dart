import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../../specialist/presentation/cubits/specialist_cubit.dart';
import '../../../../app/dependency_injection/service_locator.dart';
import '../../data/models/world_models.dart';
import '../cubits/child_world_cubit.dart';

/// Tab 3 (`ألعابي`): Handcrafted showcase of all 8 interactive learning mini-games
/// grouped clearly by interaction style, honoring specialist target phonemes when assigned.
class MiniGamesHubView extends StatelessWidget {
  const MiniGamesHubView({super.key});

  void _launchGame(
    BuildContext context,
    MiniGameType gameType, {
    List<String>? targetPhonemes,
  }) {
    final uri = Uri(
      path: '/activity/${gameType.id}',
      queryParameters: {
        'regionId': WorldRegionId.soundGarden.id,
        if (targetPhonemes != null && targetPhonemes.isNotEmpty)
          'phonemes': targetPhonemes.join(','),
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final specialistCubit = sl.isRegistered<SpecialistCubit>()
        ? sl<SpecialistCubit>()
        : null;

    return SafeArea(
      bottom: false,
      child: BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
        builder: (context, worldCubitState) {
          final activeAssignment = specialistCubit?.state
              .activeAssignmentForProfile(worldCubitState.activeProfileId);

          final groups = [
            (
              title: 'ألعاب الاستكشاف والاستماع (بدون ميكروفون)',
              subtitle:
                  'تعلّم وتمييز الأصوات باللعب والصور بدون تشغيل نماذج الكلام',
              games: [
                MiniGameType.discoverWord,
                MiniGameType.hearDifference,
                MiniGameType.listenAndChoose,
              ],
              accent: AppColors.worldGardenAccent,
              soft: AppColors.worldGardenSoft,
            ),
            (
              title: 'ألعاب النطق بصوتك مع ياسر',
              subtitle:
                  'اسمع ياسر أولاً ثم انطق بصوتك الواضح مع حماية التسجيل الآمنة',
              games: [
                MiniGameType.repeatAfterYasser,
                MiniGameType.nameThePicture,
              ],
              accent: AppColors.primary,
              soft: AppColors.primaryContainer,
            ),
            (
              title: 'ألعاب الألغاز والحكايات',
              subtitle: 'افتح الصناديق السرية ودوّر على الأصوات وأكمل القصص',
              games: [
                MiniGameType.mysterySoundBoxes,
                MiniGameType.soundDetective,
                MiniGameType.completeTheStory,
              ],
              accent: AppColors.secondary,
              soft: AppColors.secondaryContainer,
            ),
          ];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'ألعاب الأصوات الثمانية',
                      style: AppTextStyles.headlineMedium,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      activeAssignment != null
                          ? 'مفعّل حالياً تركيز الأخصائي على: ${activeAssignment.targetPhonemes.join(' • ')}'
                          : 'اختار اللعبة اللي تحب تلعبها مع ياسر النهاردة!',
                      style: AppTextStyles.bodySmall,
                    ),
                    SizedBox(height: 16.h),
                    ...groups.map((grp) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(grp.title, style: AppTextStyles.titleMedium),
                          SizedBox(height: 2.h),
                          Text(grp.subtitle, style: AppTextStyles.bodySmall),
                          SizedBox(height: 10.h),
                          ...grp.games.map((g) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: YasserSurfaceCard(
                                padding: EdgeInsets.all(14.w),
                                borderColor: grp.accent.withValues(alpha: 0.32),
                                onTap: () => _launchGame(
                                  context,
                                  g,
                                  targetPhonemes:
                                      activeAssignment?.targetPhonemes,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: ShapeDecoration(
                                        color: grp.soft,
                                        shape: YasserShapes.squircle(15),
                                      ),
                                      child: Icon(
                                        g.icon,
                                        color: grp.accent,
                                        size: 26,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            g.titleAr,
                                            style: AppTextStyles.titleSmall,
                                          ),
                                          Text(
                                            g.subtitleAr,
                                            style: AppTextStyles.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      g.usesMicrophoneAndAi
                                          ? Icons.mic_none_rounded
                                          : Icons.play_circle_outline_rounded,
                                      color: grp.accent,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          SizedBox(height: 10.h),
                        ],
                      );
                    }),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
