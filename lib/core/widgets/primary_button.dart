import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'yasser_tactile_surface.dart';

enum YasserButtonState { normal, success, error }

/// Flagship brand-orange tactile 3D squircle primary CTA button.
///
/// Preserves full compatibility with existing callers while upgrading geometry,
/// tactile bottom-lip physics, duplicate-submission blocking, and accessible contrast.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final YasserButtonState state;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height,
    this.backgroundColor,
    this.state = YasserButtonState.normal,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    final Color fill = switch (state) {
      YasserButtonState.success => AppColors.success,
      YasserButtonState.error => AppColors.error,
      YasserButtonState.normal => backgroundColor ?? AppColors.primary,
    };

    final Color lip = switch (state) {
      YasserButtonState.success => AppColors.successDark,
      YasserButtonState.error => AppColors.errorDark,
      YasserButtonState.normal =>
        (backgroundColor != null && backgroundColor != AppColors.primary)
            ? HSLColor.fromColor(backgroundColor!)
                  .withLightness(
                    (HSLColor.fromColor(backgroundColor!).lightness - 0.14)
                        .clamp(0.12, 0.85),
                  )
                  .toColor()
            : AppColors.primaryDark,
    };

    final Color fg = enabled ? Colors.white : AppColors.disabledText;

    final double effectiveHeight =
        height ?? AppSpacing.buttonHeight.h.clamp(54.0, 66.0);

    return YasserTactileButtonSurface(
      onPressed: onPressed,
      isLoading: isLoading,
      fillColor: fill,
      lipColor: lip,
      radius: AppSpacing.radiusM,
      lipDepth: AppSpacing.lipMd,
      width: width,
      height: effectiveHeight,
      padding: EdgeInsets.symmetric(
        horizontal: effectiveHeight <= 50 ? 12 : 20,
      ),
      semanticLabel: label,
      heavyHaptic: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: isLoading
            ? SizedBox(
                key: const ValueKey('primary_loading'),
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : IconTheme(
                key: ValueKey('primary_content_$label'),
                data: IconThemeData(color: fg, size: 21),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.buttonLabel.copyWith(color: fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (icon != null) ...[SizedBox(width: 10.w), icon!],
                  ],
                ),
              ),
      ),
    );
  }
}
