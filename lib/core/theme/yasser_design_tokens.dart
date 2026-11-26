import 'dart:ui';

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Squircle & organic shape helpers giving Yasser's UI a cohesive soft-tactile look.
abstract final class YasserShapes {
  /// Returns a mathematical superellipse (`ContinuousRectangleBorder`) matching
  /// high-craft educational products (Lingokids / Pok Pok / iOS squircles).
  static ShapeBorder squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius * 1.55),
      side: side,
    );
  }

  static BorderRadius rounded(double radius) => BorderRadius.circular(radius);
}

/// Centralized motion tokens and reduced-motion utilities.
abstract final class YasserMotion {
  static const Duration pressIn = Duration(milliseconds: 95);
  static const Duration pressRelease = Duration(milliseconds: 220);
  static const Duration fieldFocus = Duration(milliseconds: 200);
  static const Duration microState = Duration(milliseconds: 240);
  static const Duration pageTransition = Duration(milliseconds: 420);
  static const Duration calmSpecialistTransition = Duration(milliseconds: 280);
  static const Duration sceneMorph = Duration(milliseconds: 520);
  static const Duration celebrationReveal = Duration(milliseconds: 650);

  static const Curve pressCurve = Curves.easeOutQuart;
  static const Curve springOut = Cubic(0.22, 1.24, 0.36, 1.0);
  static const Curve gentleBounce = Curves.easeOutBack;
  static const Curve smoothMorph = Curves.easeInOutCubicEmphasized;
  static const Curve calmCurve = Curves.easeOutCubic;
  static const Curve gentleDecelerate = Curves.easeOutCubic;

  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration effective(BuildContext context, Duration normal) {
    return isReducedMotion(context) ? Duration.zero : normal;
  }
}

/// ThemeExtension housing Yasser's semantic surfaces, tactile lip elevations,
/// and elevation presets.
@immutable
class YasserDesignTokens extends ThemeExtension<YasserDesignTokens> {
  final Color canvasWarm;
  final Color cardSurface;
  final Color primaryFill;
  final Color primaryLip;
  final Color secondaryFill;
  final Color secondaryLip;
  final Color outlineSurface;
  final Color outlineBorder;
  final Color outlineLip;
  final double defaultSquircleRadius;
  final double buttonLipDepth;
  final List<BoxShadow> softCardShadows;
  final List<BoxShadow> stageFloatingShadows;

  const YasserDesignTokens({
    required this.canvasWarm,
    required this.cardSurface,
    required this.primaryFill,
    required this.primaryLip,
    required this.secondaryFill,
    required this.secondaryLip,
    required this.outlineSurface,
    required this.outlineBorder,
    required this.outlineLip,
    required this.defaultSquircleRadius,
    required this.buttonLipDepth,
    required this.softCardShadows,
    required this.stageFloatingShadows,
  });

  static const YasserDesignTokens light = YasserDesignTokens(
    canvasWarm: AppColors.background,
    cardSurface: AppColors.surface,
    primaryFill: AppColors.primary,
    primaryLip: AppColors.primaryDark,
    secondaryFill: AppColors.secondary,
    secondaryLip: AppColors.secondaryDark,
    outlineSurface: AppColors.surface,
    outlineBorder: AppColors.borderSoft,
    outlineLip: AppColors.borderStrong,
    defaultSquircleRadius: AppSpacing.radiusL,
    buttonLipDepth: AppSpacing.lipMd,
    softCardShadows: [
      BoxShadow(
        color: AppColors.shadowWarm,
        blurRadius: 18,
        spreadRadius: 0,
        offset: Offset(0, 6),
      ),
    ],
    stageFloatingShadows: [
      BoxShadow(
        color: AppColors.shadowElevated,
        blurRadius: 26,
        spreadRadius: 1,
        offset: Offset(0, 10),
      ),
    ],
  );

  static YasserDesignTokens of(BuildContext context) {
    return Theme.of(context).extension<YasserDesignTokens>() ?? light;
  }

  @override
  YasserDesignTokens copyWith({
    Color? canvasWarm,
    Color? cardSurface,
    Color? primaryFill,
    Color? primaryLip,
    Color? secondaryFill,
    Color? secondaryLip,
    Color? outlineSurface,
    Color? outlineBorder,
    Color? outlineLip,
    double? defaultSquircleRadius,
    double? buttonLipDepth,
    List<BoxShadow>? softCardShadows,
    List<BoxShadow>? stageFloatingShadows,
  }) {
    return YasserDesignTokens(
      canvasWarm: canvasWarm ?? this.canvasWarm,
      cardSurface: cardSurface ?? this.cardSurface,
      primaryFill: primaryFill ?? this.primaryFill,
      primaryLip: primaryLip ?? this.primaryLip,
      secondaryFill: secondaryFill ?? this.secondaryFill,
      secondaryLip: secondaryLip ?? this.secondaryLip,
      outlineSurface: outlineSurface ?? this.outlineSurface,
      outlineBorder: outlineBorder ?? this.outlineBorder,
      outlineLip: outlineLip ?? this.outlineLip,
      defaultSquircleRadius:
          defaultSquircleRadius ?? this.defaultSquircleRadius,
      buttonLipDepth: buttonLipDepth ?? this.buttonLipDepth,
      softCardShadows: softCardShadows ?? this.softCardShadows,
      stageFloatingShadows: stageFloatingShadows ?? this.stageFloatingShadows,
    );
  }

  @override
  YasserDesignTokens lerp(ThemeExtension<YasserDesignTokens>? other, double t) {
    if (other is! YasserDesignTokens) return this;
    return YasserDesignTokens(
      canvasWarm: Color.lerp(canvasWarm, other.canvasWarm, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      primaryFill: Color.lerp(primaryFill, other.primaryFill, t)!,
      primaryLip: Color.lerp(primaryLip, other.primaryLip, t)!,
      secondaryFill: Color.lerp(secondaryFill, other.secondaryFill, t)!,
      secondaryLip: Color.lerp(secondaryLip, other.secondaryLip, t)!,
      outlineSurface: Color.lerp(outlineSurface, other.outlineSurface, t)!,
      outlineBorder: Color.lerp(outlineBorder, other.outlineBorder, t)!,
      outlineLip: Color.lerp(outlineLip, other.outlineLip, t)!,
      defaultSquircleRadius: lerpDouble(
        defaultSquircleRadius,
        other.defaultSquircleRadius,
        t,
      )!,
      buttonLipDepth: lerpDouble(buttonLipDepth, other.buttonLipDepth, t)!,
      softCardShadows: BoxShadow.lerpList(
        softCardShadows,
        other.softCardShadows,
        t,
      )!,
      stageFloatingShadows: BoxShadow.lerpList(
        stageFloatingShadows,
        other.stageFloatingShadows,
        t,
      )!,
    );
  }
}
