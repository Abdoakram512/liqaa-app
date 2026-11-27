import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Animated radial bloom burst painter for reward celebrations & flower planting.
class RewardBloomPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;

  const RewardBloomPainter({
    required this.progress,
    this.primaryColor = AppColors.primary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final maxR = math.min(size.width, size.height) * 0.45;

    final haloPaint = Paint()
      ..color = primaryColor.withValues(alpha: (1 - t * 0.45) * 0.18);
    canvas.drawCircle(center, maxR * (0.45 + 0.55 * t), haloPaint);

    for (int i = 0; i < 10; i++) {
      final a = i * (math.pi * 2 / 10) + t * 0.3;
      final dist = maxR * (0.35 + 0.65 * t);
      final dot = Offset(
        center.dx + math.cos(a) * dist,
        center.dy + math.sin(a) * dist,
      );
      canvas.drawCircle(
        dot,
        math.max(2.0, 5.0 * (1.1 - t * 0.4)),
        Paint()
          ..color = (i.isEven ? primaryColor : AppColors.secondary).withValues(
            alpha: (1 - t * 0.35) * 0.85,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RewardBloomPainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.01 ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// Handcrafted scrapbook paper border & subtle stitched margin painter for My Adventure Book.
class ScrapbookPagePainter extends CustomPainter {
  final Color spineColor;

  const ScrapbookPagePainter({this.spineColor = AppColors.primary});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    final pageRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pageRect, const Radius.circular(24)),
      Paint()..color = const Color(0xFFFFFDF7),
    );

    // Subtle ruled paper lines
    final linePaint = Paint()
      ..color = AppColors.borderSoft.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;
    for (double y = 44; y < h - 20; y += 34) {
      canvas.drawLine(Offset(20, y), Offset(w - 20, y), linePaint);
    }

    // Stitched border
    final borderPaint = Paint()
      ..color = spineColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pageRect.deflate(6), const Radius.circular(20)),
      borderPaint,
    );

    // Notebook rings along right edge (RTL spine)
    for (double y = 36; y < h - 30; y += 44) {
      canvas.drawCircle(
        Offset(w - 14, y),
        4.5,
        Paint()..color = spineColor.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScrapbookPagePainter oldDelegate) {
    return oldDelegate.spineColor != spineColor;
  }
}
