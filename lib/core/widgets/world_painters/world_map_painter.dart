import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Normalized anchor positions for the 6 connected locations on the interactive
/// adventure map (responsive across phones and tablets).
class WorldMapAnchor {
  final String regionId;
  final Offset normalized;

  const WorldMapAnchor(this.regionId, this.normalized);
}

const List<WorldMapAnchor> kWorldMapAnchors = [
  WorldMapAnchor('yasser_home', Offset(0.50, 0.84)),
  WorldMapAnchor('sound_garden', Offset(0.24, 0.67)),
  WorldMapAnchor('animal_forest', Offset(0.75, 0.54)),
  WorldMapAnchor('word_island', Offset(0.28, 0.40)),
  WorldMapAnchor('story_city', Offset(0.74, 0.27)),
  WorldMapAnchor('hero_castle', Offset(0.49, 0.13)),
];

/// Hand-illustrated interactive adventure map terrain with sunlit hills,
/// winding river, bridges, curved connecting paths, stepping stones, and an
/// animated golden progress trail.
class WorldMapTerrainPainter extends CustomPainter {
  final double shimmerPhase;
  final Set<String> completedRegions;
  final String? selectedRegionId;

  const WorldMapTerrainPainter({
    this.shimmerPhase = 0.0,
    this.completedRegions = const {},
    this.selectedRegionId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    // 1. Warm sky-to-meadow parchment backdrop
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF4DC), Color(0xFFF6FBE9), Color(0xFFEAF7E4)],
        ).createShader(Offset.zero & size),
    );

    // 2. Rolling illustrated terrain zones
    final castleHill = Path()
      ..moveTo(0, h * 0.22)
      ..quadraticBezierTo(w * 0.5, h * 0.07, w, h * 0.24)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      castleHill,
      Paint()..color = AppColors.worldCastleSoft.withValues(alpha: 0.7),
    );

    final meadowHill = Path()
      ..moveTo(0, h * 0.60)
      ..cubicTo(w * 0.32, h * 0.50, w * 0.66, h * 0.68, w, h * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      meadowHill,
      Paint()..color = const Color(0xFFDCF2D5).withValues(alpha: 0.85),
    );

    // 3. Winding turquoise stream around Word Island & Sound Garden
    final riverPath = Path()
      ..moveTo(-20, h * 0.48)
      ..cubicTo(w * 0.30, h * 0.54, w * 0.58, h * 0.36, w + 20, h * 0.44);
    canvas.drawPath(
      riverPath,
      Paint()
        ..color = AppColors.accentSky.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      riverPath,
      Paint()
        ..color = Colors.white.withValues(
          alpha: 0.35 + 0.15 * math.sin(shimmerPhase * math.pi * 2),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // 4. Illustrated wooden bridge spanning river near Word Island
    final bridgeCenter = Offset(w * 0.48, h * 0.45);
    final bridgeRect = Rect.fromCenter(
      center: bridgeCenter,
      width: 44,
      height: 22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bridgeRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFFD69A56),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bridgeRect, const Radius.circular(6)),
      Paint()
        ..color = const Color(0xFF8C5824)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // 5. Curved adventure path connecting all 6 regions
    final pts = kWorldMapAnchors
        .map((a) => Offset(a.normalized.dx * w, a.normalized.dy * h))
        .toList(growable: false);

    for (int i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final ctrl = Offset(
        (a.dx + b.dx) / 2 + (i.isEven ? -34 : 34),
        (a.dy + b.dy) / 2,
      );
      final seg = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

      final isLit =
          completedRegions.contains(kWorldMapAnchors[i].regionId) ||
          selectedRegionId == kWorldMapAnchors[i + 1].regionId;

      // Soft warm path base
      canvas.drawPath(
        seg,
        Paint()
          ..color = const Color(0xFFE7D6BD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round,
      );

      // Stepping stones along quadratic Bezier curve
      const int stones = 8;
      for (int s = 1; s < stones; s++) {
        final t = s / stones;
        final pos = _quadPoint(a, ctrl, b, t);
        canvas.drawCircle(
          pos,
          isLit ? 4.2 : 3.2,
          Paint()..color = isLit ? AppColors.primary : const Color(0xFFCBB495),
        );
      }
    }

    // 6. Lightweight trees & flowers scenery clusters
    _drawMiniTree(canvas, Offset(w * 0.14, h * 0.80));
    _drawMiniTree(canvas, Offset(w * 0.86, h * 0.72));
    _drawMiniTree(canvas, Offset(w * 0.88, h * 0.48));
    _drawMiniTree(canvas, Offset(w * 0.13, h * 0.28));
  }

  Offset _quadPoint(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  void _drawMiniTree(Canvas canvas, Offset base) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: base.translate(0, 8), width: 6, height: 14),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF9C6B43),
    );
    canvas.drawCircle(
      base.translate(0, -4),
      13,
      Paint()..color = const Color(0xFF77C98A),
    );
    canvas.drawCircle(
      base.translate(0, -4),
      13,
      Paint()
        ..color = const Color(0xFF4F9D63)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant WorldMapTerrainPainter oldDelegate) {
    return (oldDelegate.shimmerPhase - shimmerPhase).abs() > 0.02 ||
        oldDelegate.selectedRegionId != selectedRegionId ||
        oldDelegate.completedRegions.length != completedRegions.length;
  }
}
