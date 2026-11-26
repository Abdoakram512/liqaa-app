import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum SpeechBubbleTailDirection { bottom, top, start, end, none }

/// Custom-painted organic speech bubble for Yasser's dialogue across Onboarding,
/// Authentication, Home, and Pronunciation Training.
class YasserSpeechBubble extends StatelessWidget {
  final Widget child;
  final SpeechBubbleTailDirection tailDirection;
  final Color backgroundColor;
  final Color borderColor;
  final Color? lipColor;
  final EdgeInsetsGeometry padding;

  const YasserSpeechBubble({
    super.key,
    required this.child,
    this.tailDirection = SpeechBubbleTailDirection.top,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.borderSoft,
    this.lipColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    const double tailSize = 10.0;

    final EdgeInsets extraInset = switch (tailDirection) {
      SpeechBubbleTailDirection.top => const EdgeInsets.only(top: tailSize),
      SpeechBubbleTailDirection.bottom => const EdgeInsets.only(
        bottom: tailSize,
      ),
      SpeechBubbleTailDirection.start => EdgeInsets.only(
        right: isRtl ? tailSize : 0,
        left: isRtl ? 0 : tailSize,
      ),
      SpeechBubbleTailDirection.end => EdgeInsets.only(
        left: isRtl ? tailSize : 0,
        right: isRtl ? 0 : tailSize,
      ),
      SpeechBubbleTailDirection.none => EdgeInsets.zero,
    };

    return RepaintBoundary(
      child: CustomPaint(
        painter: _SpeechBubblePainter(
          tailDirection: tailDirection,
          isRtl: isRtl,
          fillColor: backgroundColor,
          borderColor: borderColor,
          tailSize: tailSize,
        ),
        child: Padding(padding: extraInset.add(padding), child: child),
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final SpeechBubbleTailDirection tailDirection;
  final bool isRtl;
  final Color fillColor;
  final Color borderColor;
  final double tailSize;

  const _SpeechBubblePainter({
    required this.tailDirection,
    required this.isRtl,
    required this.fillColor,
    required this.borderColor,
    required this.tailSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    double left = 0;
    double top = 0;
    double right = size.width;
    double bottom = size.height;

    final bool tailOnRight =
        (tailDirection == SpeechBubbleTailDirection.start && isRtl) ||
        (tailDirection == SpeechBubbleTailDirection.end && !isRtl);
    final bool tailOnLeft =
        (tailDirection == SpeechBubbleTailDirection.start && !isRtl) ||
        (tailDirection == SpeechBubbleTailDirection.end && isRtl);

    if (tailDirection == SpeechBubbleTailDirection.top) top += tailSize;
    if (tailDirection == SpeechBubbleTailDirection.bottom) bottom -= tailSize;
    if (tailOnLeft) left += tailSize;
    if (tailOnRight) right -= tailSize;

    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, top, right, bottom),
      const Radius.circular(AppSpacing.radiusL),
    );

    Path bubble = Path()..addRRect(body);

    if (tailDirection == SpeechBubbleTailDirection.top) {
      final double cx = (left + right) * 0.5;
      final Path tail = Path()
        ..moveTo(cx - 11, top + 3)
        ..lineTo(cx, 0)
        ..lineTo(cx + 11, top + 3)
        ..close();
      bubble = Path.combine(PathOperation.union, bubble, tail);
    } else if (tailDirection == SpeechBubbleTailDirection.bottom) {
      final double cx = (left + right) * 0.5;
      final Path tail = Path()
        ..moveTo(cx - 11, bottom - 3)
        ..lineTo(cx, size.height)
        ..lineTo(cx + 11, bottom - 3)
        ..close();
      bubble = Path.combine(PathOperation.union, bubble, tail);
    } else if (tailOnRight) {
      final double cy = (top + bottom) * 0.55;
      final Path tail = Path()
        ..moveTo(right - 3, cy - 9)
        ..lineTo(size.width, cy + 1)
        ..lineTo(right - 3, cy + 9)
        ..close();
      bubble = Path.combine(PathOperation.union, bubble, tail);
    } else if (tailOnLeft) {
      final double cy = (top + bottom) * 0.55;
      final Path tail = Path()
        ..moveTo(left + 3, cy - 9)
        ..lineTo(0, cy + 1)
        ..lineTo(left + 3, cy + 9)
        ..close();
      bubble = Path.combine(PathOperation.union, bubble, tail);
    }

    // Soft ambient warm drop shadow
    canvas.drawShadow(bubble, const Color(0x28273141), 10.0, true);

    // Tactile bottom lip
    canvas.save();
    canvas.translate(0, 2.5);
    canvas.drawPath(bubble, Paint()..color = borderColor);
    canvas.restore();

    // Main fill & crisp border
    canvas.drawPath(bubble, Paint()..color = fillColor);
    canvas.drawPath(
      bubble,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.tailDirection != tailDirection ||
        oldDelegate.isRtl != isRtl ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}
