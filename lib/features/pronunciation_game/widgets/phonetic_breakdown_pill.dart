import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PhoneticBreakdownPill extends StatelessWidget {
  final String letter;
  final String ipa;
  final bool isTarget;
  final bool isAccurate;
  final bool isError;

  const PhoneticBreakdownPill({
    super.key,
    required this.letter,
    required this.ipa,
    this.isTarget = false,
    this.isAccurate = true,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color border = AppColors.borderSoft;
    Color textColor = AppColors.textPrimary;

    if (isError) {
      bg = Colors.red.shade50;
      border = Colors.red.shade400;
      textColor = Colors.red.shade900;
    } else if (isTarget) {
      bg = AppColors.primaryLight.withOpacity(0.5);
      border = AppColors.primary;
      textColor = AppColors.primaryDark;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: isTarget || isError ? 2 : 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowWarm,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            letter,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '[$ipa]',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
