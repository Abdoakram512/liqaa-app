import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Handcrafted Personal Home & Evolving Garden CustomPainter.
/// Renders sunlit sky tint (customizable by child theme), Yasser's warm treehouse/cottage,
/// stone path, garden plot beds, and dynamically blooming flowers matching persisted
/// `plantedFlowerIds`.
class PersonalHomeScenePainter extends CustomPainter {
  final Color themeSkyTop;
  final Color themeGardenGrass;
  final List<String> plantedFlowerIds;
  final List<String> placedDecorationIds;
  final double breezePhase;

  const PersonalHomeScenePainter({
    this.themeSkyTop = const Color(0xFFFFEFC7),
    this.themeGardenGrass = const Color(0xFFD5F2C9),
    this.plantedFlowerIds = const [],
    this.placedDecorationIds = const [],
    this.breezePhase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    // 1. Custom theme sunlit sky gradient
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [themeSkyTop, AppColors.surface],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.72)),
    );

    // 2. Distant rolling hill + lush garden grass foreground
    final farHill = Path()
      ..moveTo(0, h * 0.64)
      ..quadraticBezierTo(w * 0.35, h * 0.50, w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      farHill,
      Paint()..color = themeGardenGrass.withValues(alpha: 0.65),
    );

    final lawn = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.54, h * 0.64, w, h * 0.74)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(lawn, Paint()..color = themeGardenGrass);

    // 3. Cozy cottage / treehouse on right side (RTL start-friendly staging)
    final houseX = w * 0.64;
    final houseY = h * 0.44;
    final houseW = math.min(92.0, w * 0.26);
    final houseH = math.min(68.0, h * 0.28);

    // Cottage walls
    final wallRect = Rect.fromLTWH(houseX, houseY, houseW, houseH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(wallRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFFFFF8E8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(wallRect, const Radius.circular(10)),
      Paint()
        ..color = AppColors.primaryDark.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Warm arched roof
    final roof = Path()
      ..moveTo(houseX - 10, houseY + 4)
      ..lineTo(houseX + houseW / 2, houseY - 26)
      ..lineTo(houseX + houseW + 10, houseY + 4)
      ..close();
    canvas.drawPath(roof, Paint()..color = AppColors.accentCoral);
    canvas.drawPath(
      roof,
      Paint()
        ..color = const Color(0xFF9F351F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Round wooden door
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          houseX + houseW * 0.34,
          houseY + houseH * 0.42,
          houseW * 0.32,
          houseH * 0.58,
        ),
        topLeft: const Radius.circular(14),
        topRight: const Radius.circular(14),
      ),
      Paint()..color = AppColors.primary,
    );

    // Optional decorations: lantern / rainbow / banner
    if (placedDecorationIds.contains('deco_rainbow')) {
      for (int idx = 0; idx < 3; idx++) {
        final col = [
          AppColors.accentCoral.withValues(alpha: 0.42),
          AppColors.primary.withValues(alpha: 0.42),
          AppColors.accentSky.withValues(alpha: 0.42),
        ][idx];
        canvas.drawArc(
          Rect.fromLTWH(
            w * 0.08 + idx * 5,
            h * 0.08 + idx * 5,
            110 - idx * 10,
            74 - idx * 8,
          ),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5,
        );
      }
    }
    if (placedDecorationIds.contains('deco_lantern')) {
      final sway = math.sin(breezePhase * math.pi * 2) * 3;
      canvas.drawLine(
        Offset(houseX - 8, houseY + 6),
        Offset(houseX - 8 + sway, houseY + 18),
        Paint()
          ..color = AppColors.textPrimary
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(
        Offset(houseX - 8 + sway, houseY + 21),
        6,
        Paint()..color = const Color(0xFFFFD44D),
      );
    }

    // 4. Planted evolving flowers across soil spots
    final soilSpots = [
      Offset(w * 0.14, h * 0.84),
      Offset(w * 0.28, h * 0.87),
      Offset(w * 0.44, h * 0.86),
      Offset(w * 0.56, h * 0.89),
    ];
    for (int i = 0; i < soilSpots.length; i++) {
      final spot = soilSpots[i];
      canvas.drawOval(
        Rect.fromCenter(center: spot, width: 28, height: 9),
        Paint()..color = const Color(0xFFA47551).withValues(alpha: 0.55),
      );
      if (i < plantedFlowerIds.length) {
        final flowerColor = [
          AppColors.primary,
          AppColors.accentCoral,
          AppColors.secondary,
          AppColors.accentMint,
        ][i % 4];
        final sway = math.sin(breezePhase * math.pi * 2 + i) * 2.5;
        canvas.drawLine(
          spot,
          Offset(spot.dx + sway, spot.dy - 22),
          Paint()
            ..color = AppColors.accentMintDark
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
        final head = Offset(spot.dx + sway, spot.dy - 24);
        for (int p = 0; p < 5; p++) {
          final a = p * (2 * math.pi / 5);
          canvas.drawCircle(
            head.translate(math.cos(a) * 6, math.sin(a) * 6),
            4.2,
            Paint()..color = flowerColor,
          );
        }
        canvas.drawCircle(head, 4.2, Paint()..color = const Color(0xFFFFDF5D));
      }
    }
  }

  @override
  bool shouldRepaint(covariant PersonalHomeScenePainter oldDelegate) {
    return oldDelegate.themeSkyTop != themeSkyTop ||
        oldDelegate.themeGardenGrass != themeGardenGrass ||
        oldDelegate.plantedFlowerIds.length != plantedFlowerIds.length ||
        oldDelegate.placedDecorationIds.length != placedDecorationIds.length ||
        (oldDelegate.breezePhase - breezePhase).abs() > 0.03;
  }
}
