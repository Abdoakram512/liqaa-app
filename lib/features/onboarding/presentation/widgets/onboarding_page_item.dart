import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/onboarding_item_model.dart';
import 'onboarding_character_scene.dart';

class OnboardingPageItem extends StatelessWidget {
  final OnboardingItemModel item;

  const OnboardingPageItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          // Character Scene Composition with Responsive Proportions
          Expanded(
            flex: 6,
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 340,
                  height: 360,
                  child: OnboardingCharacterScene(item: item),
                ),
              ),
            ),
          ),

          SizedBox(height: 14.h),

          // Informational Content Block
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category / Feature Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: item.badgeBackgroundColor,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text(
                      item.badgeKey.tr(),
                      style: AppTextStyles.badgeLabel.copyWith(
                        color: item.accentColor,
                        fontSize: 13.sp,
                      ),
                    ),
                  )
                      .animate(key: ValueKey('badge_${item.id}'))
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                  SizedBox(height: 12.h),

                  // Main Title
                  Text(
                    item.titleKey.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  )
                      .animate(key: ValueKey('title_${item.id}'))
                      .fadeIn(delay: 150.ms, duration: 450.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                  SizedBox(height: 8.h),

                  // Subtitle / Description
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      item.subtitleKey.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  )
                      .animate(key: ValueKey('desc_${item.id}'))
                      .fadeIn(delay: 250.ms, duration: 450.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
