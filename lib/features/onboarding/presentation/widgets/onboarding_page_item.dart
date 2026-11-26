import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../data/models/onboarding_item_model.dart';
import 'onboarding_character_scene.dart';

class OnboardingPageItem extends StatelessWidget {
  final OnboardingItemModel item;
  final bool isActive;
  final double parallaxOffset;

  const OnboardingPageItem({
    super.key,
    required this.item,
    this.isActive = true,
    this.parallaxOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = YasserMotion.isReducedMotion(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompactHeight = constraints.maxHeight < 520;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              Expanded(
                flex: isCompactHeight ? 5 : 6,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 340,
                      height: 360,
                      child: OnboardingCharacterScene(
                        item: item,
                        isActive: isActive,
                        parallaxOffset: parallaxOffset,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Expanded(
                flex: 4,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.maxFormWidth,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: AppColors.surface.withValues(alpha: 0.90),
                          shape: YasserShapes.squircle(
                            AppSpacing.radiusL,
                            side: const BorderSide(
                              color: AppColors.borderSoft,
                              width: 1.4,
                            ),
                          ),
                          shadows: const [
                            BoxShadow(
                              color: AppColors.shadowWarm,
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 16.h,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DecoratedBox(
                                decoration: ShapeDecoration(
                                  color: item.badgeBackgroundColor,
                                  shape: YasserShapes.squircle(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 5.h,
                                  ),
                                  child: Text(
                                    item.badgeKey.tr(),
                                    style: AppTextStyles.badgeLabel.copyWith(
                                      color:
                                          item.accentColor == AppColors.primary
                                          ? AppColors.primaryDeep
                                          : item.accentColor,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                    item.titleKey.tr(),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.headlineLarge.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 21.sp,
                                    ),
                                  )
                                  .animate(
                                    key: ValueKey('title_${item.id}'),
                                    target: reduced ? 0 : 1,
                                  )
                                  .fadeIn(duration: 340.ms),
                              SizedBox(height: 8.h),
                              Text(
                                    item.subtitleKey.tr(),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                  .animate(
                                    key: ValueKey('desc_${item.id}'),
                                    target: reduced ? 0 : 1,
                                  )
                                  .fadeIn(delay: 90.ms, duration: 360.ms),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
