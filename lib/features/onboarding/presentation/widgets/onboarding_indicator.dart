import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/yasser_design_tokens.dart';

class OnboardingIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color activeColor;

  const OnboardingIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = YasserMotion.isReducedMotion(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final bool isActive = index == currentIndex;
        final bool isCompleted = index < currentIndex;
        return AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          height: 10.h.clamp(8.0, 12.0),
          width: isActive ? 32.w : 10.w,
          decoration: ShapeDecoration(
            color: isActive
                ? activeColor
                : (isCompleted
                      ? activeColor.withValues(alpha: 0.38)
                      : AppColors.borderStrong.withValues(alpha: 0.55)),
            shape: YasserShapes.squircle(6),
            shadows: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
