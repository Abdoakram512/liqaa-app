import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/yasser_design_tokens.dart';

/// Tactile squircle phoneme tile highlighting target Arabic letters cleanly.
class PhoneticBreakdownPill extends StatelessWidget {
  final String letter;
  final String ipa;
  final bool isTarget;
  final bool isAccurate;
  final bool isError;
  final bool showIpa;

  const PhoneticBreakdownPill({
    super.key,
    required this.letter,
    required this.ipa,
    this.isTarget = false,
    this.isAccurate = false,
    this.isError = false,
    this.showIpa = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color lip, Color text) = isError
        ? (
            AppColors.warningSoft,
            AppColors.warning,
            AppColors.primaryDark,
            AppColors.primaryDeep,
          )
        : isAccurate
        ? (
            AppColors.successSoft,
            AppColors.success,
            AppColors.successDark,
            AppColors.successDark,
          )
        : isTarget
        ? (
            AppColors.primarySoft,
            AppColors.primary,
            AppColors.primaryDark,
            AppColors.primaryDeep,
          )
        : (
            AppColors.surface,
            AppColors.borderSoft,
            AppColors.borderStrong,
            AppColors.textPrimary,
          );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: const EdgeInsets.only(bottom: 3),
      decoration: ShapeDecoration(color: lip, shape: YasserShapes.squircle(15)),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: bg,
          shape: YasserShapes.squircle(
            15,
            side: BorderSide(
              color: border,
              width: (isTarget || isError || isAccurate) ? 1.8 : 1.2,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                letter,
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: text,
                ),
              ),
              if (showIpa) ...[
                SizedBox(height: 2.h),
                Text(
                  '/$ipa/',
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 10.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
