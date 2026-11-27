import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Handcrafted Arabic typography system pairing bundled offline fonts:
/// - **Baloo Bhaijaan 2** (Display, Headlines, Titles, Badges, Buttons): warm,
///   rounded letterforms with clear Arabic dot/diacritic separation for children.
/// - **Tajawal** (Body, Labels, Clinical & Specialist Text): crisp geometric
///   Arabic legibility at all reading sizes and tabular numbers.
abstract final class AppTextStyles {
  static const String displayFontFamily = 'BalooBhaijaan2';
  static const String bodyFontFamily = 'Tajawal';
  static const List<String> arabicFallbacks = <String>[
    bodyFontFamily,
    displayFontFamily,
    'Cairo',
    'sans-serif',
  ];

  static TextStyle get _baseDisplay => const TextStyle(
    fontFamily: displayFontFamily,
    fontFamilyFallback: arabicFallbacks,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
  );

  static TextStyle get _baseBody => const TextStyle(
    fontFamily: bodyFontFamily,
    fontFamilyFallback: arabicFallbacks,
    color: AppColors.textPrimary,
  );

  // Display Styles (Hero titles, target Arabic words)
  static TextStyle get displayLarge => _baseDisplay.copyWith(
    fontSize: 34.sp,
    fontWeight: FontWeight.w800,
    height: 1.28,
  );

  static TextStyle get displayMedium => _baseDisplay.copyWith(
    fontSize: 28.sp,
    fontWeight: FontWeight.w800,
    height: 1.32,
  );

  static TextStyle get displaySmall => _baseDisplay.copyWith(
    fontSize: 24.sp,
    fontWeight: FontWeight.w700,
    height: 1.34,
  );

  // Headline Styles
  static TextStyle get headlineLarge => _baseDisplay.copyWith(
    fontSize: 23.sp,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static TextStyle get headlineMedium => _baseDisplay.copyWith(
    fontSize: 20.sp,
    fontWeight: FontWeight.w700,
    height: 1.38,
  );

  static TextStyle get headlineSmall => _baseDisplay.copyWith(
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  // Title Styles
  static TextStyle get titleLarge => _baseDisplay.copyWith(
    fontSize: 20.sp,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static TextStyle get titleMedium => _baseDisplay.copyWith(
    fontSize: 16.sp,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  static TextStyle get titleSmall => _baseBody.copyWith(
    fontSize: 14.sp,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  // Label Styles
  static TextStyle get labelLarge => _baseBody.copyWith(
    fontSize: 14.sp,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static TextStyle get labelMedium => _baseBody.copyWith(
    fontSize: 12.sp,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static TextStyle get labelSmall => _baseBody.copyWith(
    fontSize: 11.sp,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // Body Styles
  static TextStyle get bodyLarge => _baseBody.copyWith(
    fontSize: 16.sp,
    fontWeight: FontWeight.w500,
    height: 1.58,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodyMedium => _baseBody.copyWith(
    fontSize: 14.sp,
    fontWeight: FontWeight.w500,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => _baseBody.copyWith(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMuted,
  );

  // Component Specific
  static TextStyle get buttonLabel => _baseDisplay.copyWith(
    fontSize: 16.sp,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textInverse,
  );

  static TextStyle get badgeLabel => _baseDisplay.copyWith(
    fontSize: 13.sp,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.primaryDeep,
  );

  static TextStyle get numericMetric => _baseDisplay.copyWith(
    fontSize: 22.sp,
    fontWeight: FontWeight.w800,
    height: 1.2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
