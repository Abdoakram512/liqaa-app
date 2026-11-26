import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Visual scene preset for Yasser's organic illustrated world.
enum PhonologicalSceneVariant {
  playfulHills,
  sunriseArch,
  soundDiscovery,
  celebrationStage,
  calmForm,
  specialistClean,
  calmClinical,
}

/// Organic custom-rendered backdrop unifying every screen in Yasser's world.
///
/// Uses [CustomPainter] wrapped in a [RepaintBoundary] to render warm sunlit
/// hills, subtle acoustic wave ribbons, and soft stage arches without heavy
/// runtime overdraw or generic rectangular containers.
class PhonologicalBackground extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final PhonologicalSceneVariant variant;
  final double morphProgress;

  const PhonologicalBackground({
    super.key,
    required this.child,
    this.backgroundColor,
    this.variant = PhonologicalSceneVariant.playfulHills,
    this.morphProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        backgroundColor ??
        ((variant == PhonologicalSceneVariant.specialistClean ||
                variant == PhonologicalSceneVariant.calmClinical)
            ? AppColors.backgroundSpecialist
            : AppColors.background);

    return ColoredBox(
      color: bg,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _YasserWorldBackdropPainter(
                  variant: variant,
                  morphProgress: morphProgress,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _YasserWorldBackdropPainter extends CustomPainter {
  final PhonologicalSceneVariant variant;
  final double morphProgress;

  const _YasserWorldBackdropPainter({
    required this.variant,
    required this.morphProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double w = size.width;
    final double h = size.height;
    final double shift = (morphProgress.clamp(0.0, 2.0)) * 0.5;

    if (variant == PhonologicalSceneVariant.specialistClean ||
        variant == PhonologicalSceneVariant.calmClinical) {
      _paintSpecialistAtmosphere(canvas, w, h);
      return;
    }

    // 1. Top sunlit organic canopy / arch
    final Color topTint = switch (variant) {
      PhonologicalSceneVariant.soundDiscovery =>
        AppColors.secondaryContainer.withValues(alpha: 0.62),
      PhonologicalSceneVariant.celebrationStage =>
        AppColors.accentGoldSoft.withValues(alpha: 0.72),
      PhonologicalSceneVariant.calmForm =>
        AppColors.primaryContainer.withValues(alpha: 0.42),
      _ => AppColors.primaryContainer.withValues(alpha: 0.58),
    };

    final topCanopy = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * (0.24 - 0.03 * shift))
      ..cubicTo(
        w * (0.72 - 0.08 * shift),
        h * (0.31 + 0.04 * shift),
        w * (0.28 + 0.08 * shift),
        h * (0.17 - 0.03 * shift),
        0,
        h * (0.27 + 0.02 * shift),
      )
      ..close();

    canvas.drawPath(
      topCanopy,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topTint, topTint.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.34)),
    );

    // 2. Gentle acoustic contour ribbon across mid-upper sky
    final Color ribbonColor = switch (variant) {
      PhonologicalSceneVariant.soundDiscovery => AppColors.secondary.withValues(
        alpha: 0.09,
      ),
      PhonologicalSceneVariant.celebrationStage => AppColors.primary.withValues(
        alpha: 0.12,
      ),
      _ => AppColors.primary.withValues(alpha: 0.08),
    };

    final ribbonPaint = Paint()
      ..color = ribbonColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final wavePath = Path()..moveTo(-10, h * 0.18);
    for (double x = 0; x <= w + 20; x += 24) {
      final double norm = x / math.max(1.0, w);
      final double y =
          h * 0.18 +
          math.sin(norm * math.pi * 2.2 + morphProgress * 1.6) * 14.0;
      wavePath.lineTo(x, y);
    }
    canvas.drawPath(wavePath, ribbonPaint);

    // 3. Soft rolling bottom hill anchoring Yasser's feet / cards
    final Color hillTint = switch (variant) {
      PhonologicalSceneVariant.soundDiscovery =>
        AppColors.secondaryContainer.withValues(alpha: 0.45),
      PhonologicalSceneVariant.calmForm =>
        AppColors.primaryUltraLight.withValues(alpha: 0.85),
      _ => AppColors.primaryContainer.withValues(alpha: 0.44),
    };

    final bottomHill = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * (0.82 + 0.02 * shift))
      ..quadraticBezierTo(
        w * (0.48 + 0.12 * (shift - 0.5)),
        h * (0.74 - 0.02 * shift),
        w,
        h * (0.84 - 0.02 * shift),
      )
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(bottomHill, Paint()..color = hillTint);
  }

  void _paintSpecialistAtmosphere(Canvas canvas, double w, double h) {
    final topSweep = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.19)
      ..quadraticBezierTo(w * 0.55, h * 0.24, 0, h * 0.16)
      ..close();

    canvas.drawPath(
      topSweep,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.secondaryContainer.withValues(alpha: 0.55),
            AppColors.primaryContainer.withValues(alpha: 0.30),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.25)),
    );
  }

  @override
  bool shouldRepaint(covariant _YasserWorldBackdropPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        (oldDelegate.morphProgress - morphProgress).abs() > 0.002;
  }
}
