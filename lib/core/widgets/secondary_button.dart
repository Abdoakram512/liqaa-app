import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'yasser_tactile_surface.dart';

/// Supporting brand-compatible tactile button that complements [PrimaryButton]
/// without competing visually with the dominant orange CTA.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double? width;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color fg = enabled ? AppColors.secondaryDeep : AppColors.disabledText;

    return YasserTactileButtonSurface(
      onPressed: onPressed,
      isLoading: isLoading,
      fillColor: AppColors.secondaryUltraLight,
      lipColor: const Color(0xFFD5CCFA),
      borderColor: AppColors.secondary.withValues(alpha: 0.35),
      radius: AppSpacing.radiusM,
      lipDepth: AppSpacing.lipSm + 0.5,
      width: width,
      height: height ?? AppSpacing.buttonHeight.h.clamp(52.0, 64.0),
      semanticLabel: label,
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          : IconTheme(
              data: IconThemeData(color: AppColors.secondary, size: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, SizedBox(width: 8.w)],
                  Flexible(
                    child: Text(
                      label,
                      style: AppTextStyles.buttonLabel.copyWith(color: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
