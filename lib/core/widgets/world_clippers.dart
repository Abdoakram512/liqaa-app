import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Organic cubic-Bezier rolling horizon clip for layered meadow & sky banners.
class OrganicHillClipper extends CustomClipper<Path> {
  final double depthFactor;
  final bool flip;

  const OrganicHillClipper({this.depthFactor = 0.22, this.flip = false});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final cut = (h * depthFactor.clamp(0.05, 0.45));

    if (!flip) {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h - cut)
        ..cubicTo(
          w * 0.72,
          h + cut * 0.35,
          w * 0.28,
          h - cut * 1.45,
          0,
          h - cut * 0.35,
        )
        ..close();
    }

    return Path()
      ..moveTo(0, cut)
      ..cubicTo(w * 0.3, -cut * 0.3, w * 0.7, cut * 1.4, w, cut * 0.4)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant OrganicHillClipper oldClipper) {
    return oldClipper.depthFactor != depthFactor || oldClipper.flip != flip;
  }
}

/// Storybook arch doorway frame used for Splash continuity, Yasser's house
/// doorway, and illustrated activity portals.
class ArchPortalClipper extends CustomClipper<Path> {
  final double bottomCornerRadius;

  const ArchPortalClipper({this.bottomCornerRadius = 28});

  @override
  Path getClip(Size size) {
    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: Radius.circular(size.width * 0.52),
      topRight: Radius.circular(size.width * 0.52),
      bottomLeft: Radius.circular(bottomCornerRadius),
      bottomRight: Radius.circular(bottomCornerRadius),
    );
    return Path()..addRRect(rrect);
  }

  @override
  bool shouldReclip(covariant ArchPortalClipper oldClipper) {
    return oldClipper.bottomCornerRadius != bottomCornerRadius;
  }
}

/// Animated expanding circular portal reveal for storybook/world navigation.
class CircularPortalRevealClipper extends CustomClipper<Path> {
  final double progress;
  final Alignment centerAlignment;

  const CircularPortalRevealClipper({
    required this.progress,
    this.centerAlignment = Alignment.center,
  });

  @override
  Path getClip(Size size) {
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped >= 0.999) {
      return Path()..addRect(Offset.zero & size);
    }
    final center = centerAlignment.alongSize(size);
    final maxRadius = math.sqrt(
      math.pow(math.max(center.dx, size.width - center.dx), 2) +
          math.pow(math.max(center.dy, size.height - center.dy), 2),
    );
    final radius = math.max(1.0, maxRadius * clamped);
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant CircularPortalRevealClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.centerAlignment != centerAlignment;
  }
}

/// Soft wave-bottom header clip giving world region and game headers a gentle
/// crafted storybook edge.
class StoryHeaderWaveClipper extends CustomClipper<Path> {
  final double waveHeight;

  const StoryHeaderWaveClipper({this.waveHeight = 18});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final d = math.min(waveHeight, h * 0.35);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - d * 0.65)
      ..quadraticBezierTo(w * 0.75, h + d * 0.45, w * 0.5, h - d * 0.35)
      ..quadraticBezierTo(w * 0.25, h - d * 1.1, 0, h - d * 0.3)
      ..close();
  }

  @override
  bool shouldReclip(covariant StoryHeaderWaveClipper oldClipper) {
    return oldClipper.waveHeight != waveHeight;
  }
}

/// Domed chest lid silhouette for Mystery Sound Boxes and My Home Treasure Chest.
class TreasureLidClipper extends CustomClipper<Path> {
  const TreasureLidClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.06, h * 0.36)
      ..quadraticBezierTo(w * 0.5, -h * 0.14, w * 0.94, h * 0.36)
      ..lineTo(w, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant TreasureLidClipper oldClipper) => false;
}
