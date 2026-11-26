import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/yasser_design_tokens.dart';
import 'primary_button.dart';
import 'yasser_tactile_surface.dart';

/// Squircle card with subtle warm lip & clean elevation used across Yasser's world.
class YasserSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color backgroundColor;
  final Color borderColor;
  final Color? lipColor;
  final double lipDepth;
  final double radius;
  final VoidCallback? onTap;

  const YasserSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.borderSoft,
    this.lipColor,
    this.lipDepth = 0.0,
    this.radius = AppSpacing.radiusL,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final innerCard = DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: YasserShapes.squircle(
          radius,
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        shadows: YasserDesignTokens.of(context).softCardShadows,
      ),
      child: Padding(padding: padding ?? EdgeInsets.all(18.w), child: child),
    );

    final content = lipDepth > 0
        ? DecoratedBox(
            decoration: ShapeDecoration(
              color: lipColor ?? borderColor,
              shape: YasserShapes.squircle(radius),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: lipDepth),
              child: innerCard,
            ),
          )
        : innerCard;

    if (onTap == null) return content;

    return GestureDetector(
      onTap: () {
        YasserUiFeedback.triggerTap();
        onTap!();
      },
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Tactile selectable card for roles, training categories, and case filters.
class YasserSelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  const YasserSelectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill = isSelected
        ? accentColor.withValues(alpha: 0.10)
        : AppColors.surface;
    final Color border = isSelected ? accentColor : AppColors.borderSoft;

    return Semantics(
      selected: isSelected,
      button: true,
      label: '$title - $subtitle',
      child: GestureDetector(
        onTap: () {
          YasserUiFeedback.triggerTap();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: YasserMotion.microState,
          curve: YasserMotion.calmCurve,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12.w : 16.w,
            vertical: compact ? 10.h : 14.h,
          ),
          decoration: ShapeDecoration(
            color: fill,
            shape: YasserShapes.squircle(
              AppSpacing.radiusM + 2,
              side: BorderSide(color: border, width: isSelected ? 2.2 : 1.4),
            ),
            shadows: [
              BoxShadow(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.18)
                    : AppColors.shadowWarm,
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 38 : 46,
                height: compact ? 38 : 46,
                decoration: ShapeDecoration(
                  color: isSelected
                      ? accentColor
                      : accentColor.withValues(alpha: 0.14),
                  shape: YasserShapes.squircle(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : accentColor,
                  size: compact ? 20 : 24,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: YasserMotion.microState,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accentColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? accentColor : AppColors.borderStrong,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable empty/error/info state widget with vector icon & action button.
class YasserEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final Color accentColor;

  const YasserEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.action,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final bodyText = message ?? subtitle ?? '';
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: ShapeDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: YasserShapes.squircle(22),
              ),
              child: Icon(icon, size: 34, color: accentColor),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSmall,
            ),
            if (bodyText.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                bodyText,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: 20.h),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 20.h),
              PrimaryButton(
                label: actionLabel!,
                width: 220.w,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum YasserBannerTone { success, warning, error, info }

void showYasserSnackBar(
  BuildContext context, {
  required String message,
  YasserBannerTone tone = YasserBannerTone.info,
}) {
  final (Color bg, IconData icon) = switch (tone) {
    YasserBannerTone.success => (AppColors.success, Icons.check_circle_rounded),
    YasserBannerTone.warning => (AppColors.warningDark, Icons.info_rounded),
    YasserBannerTone.error => (AppColors.error, Icons.error_outline_rounded),
    YasserBannerTone.info => (
      AppColors.textPrimary,
      Icons.auto_awesome_rounded,
    ),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: YasserShapes.squircle(AppSpacing.radiusM),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
