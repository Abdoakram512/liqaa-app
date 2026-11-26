import 'package:flutter/material.dart';

/// Centralized color tokens for Yasser's world.
///
/// Built around Yasser's signature golden-amber hoodie (#F69820), star backpack
/// indigo (#6C5CE7), sunlit cream canvas (#FFF7EA), and deep slate ink (#273141).
abstract final class AppColors {
  // 1. Core Brand Palette (Preserved Identity)
  static const Color primary = Color(0xFFF69820);
  static const Color primaryDark = Color(0xFFD67C08);
  static const Color primaryDeep = Color(
    0xFFB46200,
  ); // High-contrast accessible amber text/lip
  static const Color primaryLight = Color(0xFFFFB24D);
  static const Color primaryHighlight = Color(0xFFFFC978);
  static const Color primaryContainer = Color(0xFFFFE8D1);
  static const Color primarySoft = primaryContainer;
  static const Color primaryUltraLight = Color(0xFFFFF4E6);

  static const Color secondary = Color(0xFF6C5CE7);
  static const Color secondaryDark = Color(0xFF5141C9);
  static const Color secondaryDeep = Color(0xFF3E2FA8);
  static const Color secondaryLight = Color(0xFF8E81F0);
  static const Color secondaryContainer = Color(0xFFEFEAFF);
  static const Color secondarySoft = secondaryContainer;
  static const Color secondaryUltraLight = Color(0xFFF6F3FF);

  // 2. Supporting World Accents (Harmonized to Yasser's Clothing & Stage)
  static const Color accentCoral = Color(0xFFE85D3F);
  static const Color accentCoralDark = Color(0xFFC44227);
  static const Color accentCoralSoft = Color(0xFFFFE6DF);
  static const Color accentSky = Color(0xFF2E86DE);
  static const Color accentSkyDark = Color(0xFF1D65B0);
  static const Color accentSkySoft = Color(0xFFE6F2FF);
  static const Color accentMint = Color(0xFF19A98B);
  static const Color accentMintDark = Color(0xFF0E846B);
  static const Color accentMintSoft = Color(0xFFE2F8F3);
  static const Color teal = accentMint;
  static const Color tealSoft = accentMintSoft;
  static const Color accentGold = Color(0xFFF4A900);
  static const Color accentGoldSoft = Color(0xFFFFF4CC);
  static const Color accentRose = Color(0xFFE84393);

  // 3. Surfaces & Canvas Layers
  static const Color background = Color(0xFFFFF7EA);
  static const Color backgroundCream = Color(0xFFFFF7EA);
  static const Color backgroundLight = Color(0xFFFFFDF9);
  static const Color backgroundSpecialist = Color(0xFFFAF6EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFDF9);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceInput = Color(0xFFFFFEFA);
  static const Color surfaceSubtle = Color(0xFFF8EFE0);
  static const Color surfaceVariant = surfaceSubtle;

  // 4. Typography & Ink Hierarchy (WCAG AA Checked on #FFF7EA & #FFFFFF)
  static const Color textPrimary = Color(0xFF273141);
  static const Color textSecondary = Color(0xFF546173);
  static const Color textMuted = Color(0xFF7D899B);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textLink = Color(0xFFD67C08);

  // 5. Borders, Lips & Dividers
  static const Color borderSoft = Color(0xFFF3DEC4);
  static const Color borderSubtle = Color(0xFFEDE1D1);
  static const Color borderStrong = Color(0xFFDCC6AA);
  static const Color borderInput = Color(0xFFE9D7BE);
  static const Color borderCard = Color(0x33F69820);

  // 6. Disabled Tokens
  static const Color disabledSurface = Color(0xFFECE4D8);
  static const Color disabledLip = Color(0xFFD6CBB9);
  static const Color disabledText = Color(0xFF8D97A6);

  // 7. Semantic Feedback (Warm, Non-Harsh Child & Clinical States)
  static const Color success = Color(0xFF14A87A);
  static const Color successDark = Color(0xFF0B815C);
  static const Color successSoft = Color(0xFFE4F8F1);

  static const Color warning = Color(0xFFE8950C);
  static const Color warningDark = Color(0xFFB86F00);
  static const Color warningSoft = Color(0xFFFFF3DA);

  static const Color error = Color(0xFFDE4B3E);
  static const Color errorDark = Color(0xFFB33227);
  static const Color errorSoft = Color(0xFFFDECEB);

  static const Color info = Color(0xFF2E86DE);
  static const Color infoDark = Color(0xFF1D65B0);
  static const Color infoSoft = Color(0xFFE7F2FD);

  // 8. Shadows, Gradients & Scrims
  static const Color shadowWarm = Color(0x14273141);
  static const Color shadowElevated = Color(0x1F273141);
  static const Color shadowAccent = Color(0x3DF69820);
  static const Color shadowPrimary = shadowAccent;
  static const Color scrimModal = Color(0x6B1D2533);

  static const LinearGradient primaryCtaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );
}
