import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import 'onboarding_indicator.dart';

class OnboardingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final int totalPages;
  final bool isLastPage;
  final bool isFirstPage;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Color activeColor;

  const OnboardingNavigationBar({
    super.key,
    required this.currentIndex,
    required this.totalPages,
    required this.isLastPage,
    required this.isFirstPage,
    required this.onNext,
    required this.onPrevious,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicator in Center
          OnboardingIndicator(
            count: totalPages,
            currentIndex: currentIndex,
            activeColor: activeColor,
          ),

          SizedBox(height: 20.h),

          // Navigation buttons row
          Row(
            children: [
              // Back Button (shown if not first page)
              if (!isFirstPage) ...[
                IconButton(
                  onPressed: onPrevious,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.borderSoft),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 12.w),
              ],

              // Next or "يلا نبدأ" CTA Button
              Expanded(
                child: PrimaryButton(
                  label: isLastPage
                      ? LocaleKeys.onboardingStart.tr()
                      : LocaleKeys.onboardingNext.tr(),
                  backgroundColor: isLastPage
                      ? AppColors.accentCoral
                      : activeColor,
                  icon: Icon(
                    isLastPage
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
