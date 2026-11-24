import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/asset_paths.dart';

enum YasserPose {
  standing,
  waving,
  thinking,
  celebrating,
  walking,
  presenting,
}

/// A unified character presentation widget for Yasser.
/// Currently displays high-resolution, transparent 2.5D poses with organic spring motion.
/// Architecturally prepared to toggle to Rive runtime (`assets/rive/yasser.riv`)
/// without altering parent layouts or cubits.
class YasserAvatar extends StatelessWidget {
  static bool enableRepeatingAnimations = true;

  final YasserPose pose;
  final double? height;
  final double? width;
  final BoxFit fit;
  final bool animateBreathing;
  final String? semanticLabel;

  const YasserAvatar({
    super.key,
    this.pose = YasserPose.standing,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.animateBreathing = true,
    this.semanticLabel = 'ياسر - البطل الرفيق',
  });

  String get _assetPath {
    switch (pose) {
      case YasserPose.standing:
        return AssetPaths.yasserStanding;
      case YasserPose.waving:
        return AssetPaths.yasserWaving;
      case YasserPose.thinking:
        return AssetPaths.yasserThinking;
      case YasserPose.celebrating:
        return AssetPaths.yasserCelebrating;
      case YasserPose.walking:
        return AssetPaths.yasserWalking;
      case YasserPose.presenting:
        return AssetPaths.yasserPresenting;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      _assetPath,
      height: height,
      width: width,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          height: height ?? 200,
          width: width ?? 200,
          child: const Center(
            child: Icon(Icons.person, size: 64, color: Colors.orange),
          ),
        );
      },
    );

    if (animateBreathing && enableRepeatingAnimations) {
      // Subtle organic idle breathing micro-motion
      image = image
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(
            begin: 0,
            end: -6,
            duration: const Duration(milliseconds: 2200),
            curve: Curves.easeInOutSine,
          );
    }

    return image;
  }
}
