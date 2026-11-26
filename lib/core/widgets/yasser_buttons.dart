import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/yasser_design_tokens.dart';
import 'yasser_tactile_surface.dart';

/// Lighter outline squircle button for tertiary / alternative actions.
class YasserOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final double? width;
  final double? height;

  const YasserOutlineButton({
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
    final Color fg = enabled ? AppColors.textPrimary : AppColors.disabledText;

    return YasserTactileButtonSurface(
      onPressed: onPressed,
      isLoading: isLoading,
      fillColor: AppColors.surface,
      lipColor: AppColors.borderStrong,
      borderColor: AppColors.borderInput,
      radius: AppSpacing.radiusM,
      lipDepth: AppSpacing.lipSm,
      width: width,
      height: height ?? AppSpacing.buttonHeightSmall.h.clamp(46.0, 56.0),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      semanticLabel: label,
      child: isLoading
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
          : IconTheme(
              data: IconThemeData(color: fg, size: 19),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, SizedBox(width: 8.w)],
                  Flexible(
                    child: Text(
                      label,
                      style: AppTextStyles.labelLarge.copyWith(color: fg),
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

/// Consistent tactile squircle icon button (>=48x48dp accessible hit area).
class YasserIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? iconColor;
  final Color? fillColor;
  final Color? lipColor;
  final double size;

  const YasserIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor,
    this.fillColor,
    this.lipColor,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSize = math.max(AppSpacing.minTouchTarget, size);
    final enabled = onPressed != null;

    return YasserTactileButtonSurface(
      onPressed: onPressed,
      fillColor: fillColor ?? AppColors.surface,
      lipColor: lipColor ?? AppColors.borderStrong,
      borderColor: AppColors.borderSoft,
      radius: AppSpacing.radiusS + 2,
      lipDepth: AppSpacing.lipSm,
      width: effectiveSize,
      height: effectiveSize,
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      semanticLabel: tooltip,
      child: Icon(
        icon,
        size: 22,
        color: enabled
            ? (iconColor ?? AppColors.textPrimary)
            : AppColors.disabledText,
      ),
    );
  }
}

/// Larger expressive CTA button designed for children's training activities.
class YasserGameActionButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color fillColor;
  final Color lipColor;
  final bool isLoading;

  const YasserGameActionButton({
    super.key,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onPressed,
    this.fillColor = AppColors.primary,
    this.lipColor = AppColors.primaryDark,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color fg = enabled ? Colors.white : AppColors.disabledText;

    return YasserTactileButtonSurface(
      onPressed: onPressed,
      isLoading: isLoading,
      fillColor: fillColor,
      lipColor: lipColor,
      radius: AppSpacing.radiusL,
      lipDepth: AppSpacing.lipLg,
      height: AppSpacing.buttonHeightGame.h.clamp(62.0, 74.0),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      semanticLabel: label,
      heavyHaptic: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: enabled ? 0.22 : 0.4),
              shape: YasserShapes.squircle(12),
            ),
            child: Icon(icon, color: fg, size: 23),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: fg.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum RecordingOrbState { idle, recording, processing, completed, disabled }

/// Expressive tactile microphone control with distinct visual & motion states
/// (`idle`, `recording`, `processing`, `completed`, `disabled`).
class YasserRecordingButton extends StatefulWidget {
  final RecordingOrbState state;
  final double liveAmplitude;
  final VoidCallback? onTap;
  final String statusLabel;

  const YasserRecordingButton({
    super.key,
    required this.state,
    required this.onTap,
    required this.statusLabel,
    this.liveAmplitude = 0.0,
  });

  @override
  State<YasserRecordingButton> createState() => _YasserRecordingButtonState();
}

class _YasserRecordingButtonState extends State<YasserRecordingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant YasserRecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.state == RecordingOrbState.recording ||
        widget.state == RecordingOrbState.processing) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = YasserMotion.isReducedMotion(context);
    final bool canInteract =
        widget.onTap != null &&
        widget.state != RecordingOrbState.processing &&
        widget.state != RecordingOrbState.disabled;

    final (Color fill, Color lip, IconData icon) = switch (widget.state) {
      RecordingOrbState.idle => (
        AppColors.primary,
        AppColors.primaryDark,
        Icons.mic_rounded,
      ),
      RecordingOrbState.recording => (
        AppColors.accentCoral,
        AppColors.accentCoralDark,
        Icons.stop_rounded,
      ),
      RecordingOrbState.processing => (
        AppColors.secondary,
        AppColors.secondaryDark,
        Icons.graphic_eq_rounded,
      ),
      RecordingOrbState.completed => (
        AppColors.success,
        AppColors.successDark,
        Icons.check_rounded,
      ),
      RecordingOrbState.disabled => (
        AppColors.disabledSurface,
        AppColors.disabledLip,
        Icons.mic_off_rounded,
      ),
    };

    const double orbSize = AppSpacing.recordingOrbSize;
    final double lipDepth = canInteract ? 6.0 : 2.5;
    final double pressOffset = _isPressed ? 4.2 : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: canInteract,
          label: widget.statusLabel,
          child: GestureDetector(
            onTapDown: canInteract
                ? (_) => setState(() => _isPressed = true)
                : null,
            onTapUp: canInteract
                ? (_) {
                    setState(() => _isPressed = false);
                    YasserUiFeedback.triggerTap(heavy: true);
                    widget.onTap?.call();
                  }
                : null,
            onTapCancel: canInteract
                ? () => setState(() => _isPressed = false)
                : null,
            child: SizedBox(
              width: 128,
              height: 116,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Concentric organic pulse rings (CustomPainter + RepaintBoundary)
                  if (!reducedMotion &&
                      (widget.state == RecordingOrbState.recording ||
                          widget.state == RecordingOrbState.processing))
                    RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(128, 116),
                            painter: _RecordingHaloPainter(
                              progress: _pulseController.value,
                              amplitude: widget.liveAmplitude,
                              color: fill,
                            ),
                          );
                        },
                      ),
                    ),

                  // 3D Tactile Squircle Orb
                  SizedBox(
                    width: orbSize,
                    height: orbSize + lipDepth,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: lipDepth,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: lip,
                              shape: YasserShapes.squircle(30),
                              shadows: [
                                if (canInteract && !_isPressed)
                                  BoxShadow(
                                    color: fill.withValues(alpha: 0.30),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: reducedMotion
                              ? Duration.zero
                              : YasserMotion.pressIn,
                          left: 0,
                          right: 0,
                          top: pressOffset,
                          height: orbSize,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: fill,
                              shape: YasserShapes.squircle(
                                30,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.32),
                                  width: 2.0,
                                ),
                              ),
                            ),
                            child: Center(
                              child:
                                  widget.state == RecordingOrbState.processing
                                  ? const SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      icon,
                                      size: 42,
                                      color:
                                          widget.state ==
                                              RecordingOrbState.disabled
                                          ? AppColors.disabledText
                                          : Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.statusLabel,
            key: ValueKey(widget.statusLabel),
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: widget.state == RecordingOrbState.recording
                  ? AppColors.accentCoralDark
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordingHaloPainter extends CustomPainter {
  final double progress;
  final double amplitude;
  final Color color;

  const _RecordingHaloPainter({
    required this.progress,
    required this.amplitude,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double ampBoost = (amplitude.clamp(0.0, 1.0)) * 14.0;

    for (int ring = 0; ring < 2; ring++) {
      final double p = (progress + ring * 0.5) % 1.0;
      final double radius = 44.0 + p * 20.0 + ampBoost * (1.0 - p * 0.4);
      final double alpha = (1.0 - p) * 0.28;

      final RRect halo = RRect.fromRectAndRadius(
        Rect.fromCircle(center: center, radius: radius),
        Radius.circular(radius * 0.72),
      );
      canvas.drawRRect(
        halo,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingHaloPainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.01 ||
        (oldDelegate.amplitude - amplitude).abs() > 0.02 ||
        oldDelegate.color != color;
  }
}
