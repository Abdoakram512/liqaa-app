import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/yasser_design_tokens.dart';

/// Optional global hook so [YasserAudioCoordinator] can attach gentle UI tap SFX
/// and user-configured haptics without coupling widgets to service locator state.
abstract final class YasserUiFeedback {
  static VoidCallback? onButtonPress;
  static bool enableHaptics = true;

  static void triggerTap({bool heavy = false}) {
    if (enableHaptics) {
      if (heavy) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    onButtonPress?.call();
  }
}

/// Tactile 3D squircle interactive surface powering all Yasser buttons and
/// selectable cards without shifting layout bounds during press states.
class YasserTactileButtonSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color fillColor;
  final Color lipColor;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final double lipDepth;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final String? tooltip;
  final bool heavyHaptic;

  const YasserTactileButtonSurface({
    super.key,
    required this.child,
    required this.onPressed,
    this.isLoading = false,
    required this.fillColor,
    required this.lipColor,
    this.borderColor,
    this.borderWidth = 1.4,
    this.radius = AppSpacing.radiusM,
    this.lipDepth = AppSpacing.lipMd,
    this.width,
    this.height = AppSpacing.buttonHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.semanticLabel,
    this.tooltip,
    this.heavyHaptic = false,
  });

  @override
  State<YasserTactileButtonSurface> createState() =>
      _YasserTactileButtonSurfaceState();
}

class _YasserTactileButtonSurfaceState
    extends State<YasserTactileButtonSurface> {
  bool _isPressed = false;
  bool _isFocused = false;
  bool _isHovered = false;

  bool get _isInteractive => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (!_isInteractive) return;
    if (_isPressed != value && mounted) {
      setState(() => _isPressed = value);
    }
  }

  void _activate() {
    if (!_isInteractive) return;
    YasserUiFeedback.triggerTap(heavy: widget.heavyHaptic);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = YasserMotion.isReducedMotion(context);
    final bool enabled = widget.onPressed != null;

    final Color effectiveFill = enabled
        ? widget.fillColor
        : AppColors.disabledSurface;
    final Color effectiveLip = enabled
        ? widget.lipColor
        : AppColors.disabledLip;
    final Color effectiveBorder = enabled
        ? (widget.borderColor ?? widget.lipColor.withValues(alpha: 0.35))
        : AppColors.disabledLip;

    final double maxLip = enabled ? widget.lipDepth : 2.0;
    final double pressTravel = (_isPressed && _isInteractive)
        ? (maxLip * 0.76)
        : 0.0;
    final double visibleLip = (maxLip - pressTravel).clamp(0.5, maxLip);

    Widget interactive = Semantics(
      button: true,
      enabled: _isInteractive,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _isInteractive,
        mouseCursor: _isInteractive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _isFocused = v),
        onShowHoverHighlight: (v) => setState(() => _isHovered = v),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _isInteractive ? (_) => _setPressed(true) : null,
          onTapUp: _isInteractive
              ? (_) {
                  _setPressed(false);
                  _activate();
                }
              : null,
          onTapCancel: _isInteractive ? () => _setPressed(false) : null,
          child: AnimatedScale(
            scale: (!reducedMotion && _isPressed && _isInteractive)
                ? 0.988
                : 1.0,
            duration: _isPressed
                ? YasserMotion.pressIn
                : YasserMotion.pressRelease,
            curve: _isPressed
                ? YasserMotion.pressCurve
                : YasserMotion.springOut,
            child: SizedBox(
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Bottom 3D Lip & Ground Shadow Layer
                  Positioned(
                    left: 0,
                    right: 0,
                    top: maxLip,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: effectiveLip,
                        shape: YasserShapes.squircle(widget.radius),
                        shadows: enabled && !_isPressed
                            ? [
                                BoxShadow(
                                  color: effectiveLip.withValues(alpha: 0.24),
                                  blurRadius: _isHovered ? 14 : 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  ),

                  // 2. Top Interactive Cap Layer
                  AnimatedPositioned(
                    duration: reducedMotion
                        ? Duration.zero
                        : (_isPressed
                              ? YasserMotion.pressIn
                              : YasserMotion.pressRelease),
                    curve: _isPressed
                        ? YasserMotion.pressCurve
                        : YasserMotion.springOut,
                    left: 0,
                    right: 0,
                    top: pressTravel,
                    bottom: visibleLip,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: effectiveFill,
                        shape: YasserShapes.squircle(
                          widget.radius,
                          side: BorderSide(
                            color: _isFocused
                                ? AppColors.secondary
                                : effectiveBorder,
                            width: _isFocused ? 2.4 : widget.borderWidth,
                          ),
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Subtle top inner specular highlight
                          if (enabled)
                            Positioned(
                              top: 1.5,
                              left: 14,
                              right: 14,
                              height: 3,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(99),
                                    color: Colors.white.withValues(alpha: 0.24),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: widget.padding,
                            child: Center(child: widget.child),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      interactive = Tooltip(message: widget.tooltip!, child: interactive);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double? resolvedWidth =
            widget.width ??
            (constraints.hasBoundedWidth ? double.infinity : null);
        return SizedBox(
          width: resolvedWidth,
          height: widget.height,
          child: interactive,
        );
      },
    );
  }
}
