import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import 'onboarding_indicator.dart';

/// Unified onboarding bottom bar.
///
/// Enforces consistent brand-orange primary CTA styling across all pages (fixing
/// the legacy page-dependent purple/coral button switch) while letting
/// supporting accents highlight only the progress pill indicator.
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
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 18.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingIndicator(
            count: totalPages,
            currentIndex: currentIndex,
            activeColor: AppColors.primary,
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              if (!isFirstPage) ...[
                YasserIconButton(
                  icon: isRtl
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  tooltip: LocaleKeys.onboardingBack.tr(),
                  size: 56,
                  onPressed: onPrevious,
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: PrimaryButton(
                  label: isLastPage
                      ? LocaleKeys.onboardingStart.tr()
                      : LocaleKeys.onboardingNext.tr(),
                  // Strictly preserve consistent brand-orange primary CTA across every step
                  backgroundColor: AppColors.primary,
                  icon: Icon(
                    isLastPage
                        ? Icons.play_arrow_rounded
                        : Icons.arrow_forward_rounded,
                    size: 22,
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
