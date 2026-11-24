import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand Primary & Secondary
  static const Color primary = Color(0xFFF69820);
  static const Color primaryDark = Color(0xFFD67C08);
  static const Color primaryLight = Color(0xFFFFAE43);
  static const Color primaryContainer = Color(0xFFFFE8D1);
  static const Color primaryUltraLight = Color(0xFFFFF3E6);

  static const Color secondary = Color(0xFF6C5CE7);
  static const Color secondaryDark = Color(0xFF5344C2);
  static const Color secondaryLight = Color(0xFF8E81F0);
  static const Color secondaryContainer = Color(0xFFEFEAFF);

  // Accents & Badges
  static const Color accentCoral = Color(0xFFFD4F0A);
  static const Color accentSky = Color(0xFF3A86FF);
  static const Color accentMint = Color(0xFF2EC4B6);
  static const Color accentGold = Color(0xFFFFB703);
  static const Color accentRose = Color(0xFFE84393);

  // Backgrounds & Surface
  static const Color background = Color(0xFFFFF7EA); // Website primary canvas
  static const Color backgroundLight = Color(0xFFFFFDF9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFDF9);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Typography & Text
  static const Color textPrimary = Color(0xFF273141); // Deep slate navy
  static const Color textSecondary = Color(0xFF637083); // Mid slate
  static const Color textMuted = Color(0xFF9AA4B2); // Muted subtle text
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textLink = Color(0xFFF69820);

  // Borders & Dividers
  static const Color borderSoft = Color(0xFFFFE8D1);
  static const Color borderSubtle = Color(0xFFF1E5D5);
  static const Color borderCard = Color(0x33F69820);

  // Semantic Feedback
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFFB703);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3A86FF);

  // Shadow Colors
  static const Color shadowWarm = Color(0x14273141);
  static const Color shadowAccent = Color(0x3DF69820);
}
