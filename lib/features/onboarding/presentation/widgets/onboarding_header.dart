import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';

class OnboardingHeader extends StatelessWidget {
  final VoidCallback onSkip;
  final bool showSkip;
  final int currentStep;
  final int totalSteps;

  const OnboardingHeader({
    super.key,
    required this.onSkip,
    this.showSkip = true,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: YasserShapes.squircle(
                  AppSpacing.radiusM,
                  side: const BorderSide(
                    color: AppColors.borderSoft,
                    width: 1.4,
                  ),
                ),
                shadows: const [
                  BoxShadow(
                    color: AppColors.shadowWarm,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Text(
                        LocaleKeys.onboardingStepOf.tr(
                          namedArgs: {
                            'current': '$currentStep',
                            'total': '$totalSteps',
                          },
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showSkip)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              ),
              child: Text(
                LocaleKeys.onboardingSkip.tr(),
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
