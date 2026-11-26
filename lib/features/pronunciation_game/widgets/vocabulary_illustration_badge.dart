import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/yasser_design_tokens.dart';

/// Custom vector + painted vocabulary illustration medallion (zero emojis).
/// Maps the word's English meaning / Arabic ID to a clean thematic icon inside
/// an illustrated organic squircle vignette.
class VocabularyIllustrationBadge extends StatelessWidget {
  final VocabularyWord word;

  const VocabularyIllustrationBadge({super.key, required this.word});

  (IconData, Color, Color) _visualForWord() {
    final meaning = word.meaningEn.toLowerCase();
    final id = word.id.toLowerCase();

    if (id.contains('kora') || meaning.contains('ball')) {
      return (
        Icons.sports_soccer_rounded,
        AppColors.primary,
        AppColors.primarySoft,
      );
    }
    if (id.contains('samaka') || meaning.contains('fish')) {
      return (Icons.water_rounded, AppColors.teal, AppColors.tealSoft);
    }
    if (meaning.contains('dog') ||
        meaning.contains('cat') ||
        meaning.contains('rabbit') ||
        meaning.contains('camel') ||
        meaning.contains('lion') ||
        meaning.contains('bird') ||
        meaning.contains('bear')) {
      return (
        Icons.pets_rounded,
        AppColors.primaryDark,
        AppColors.accentGoldSoft,
      );
    }
    if (meaning.contains('sun') ||
        meaning.contains('moon') ||
        meaning.contains('star') ||
        meaning.contains('sky') ||
        meaning.contains('tree') ||
        meaning.contains('flower')) {
      return (
        Icons.wb_sunny_rounded,
        AppColors.accentCoral,
        AppColors.accentCoralSoft,
      );
    }
    if (meaning.contains('apple') ||
        meaning.contains('banana') ||
        meaning.contains('bread') ||
        meaning.contains('milk') ||
        meaning.contains('water')) {
      return (
        Icons.lunch_dining_rounded,
        AppColors.success,
        AppColors.successSoft,
      );
    }
    if (meaning.contains('book') ||
        meaning.contains('pen') ||
        meaning.contains('school')) {
      return (
        Icons.menu_book_rounded,
        AppColors.secondary,
        AppColors.secondarySoft,
      );
    }
    if (meaning.contains('car') ||
        meaning.contains('train') ||
        meaning.contains('plane')) {
      return (Icons.directions_car_rounded, AppColors.info, AppColors.infoSoft);
    }
    if (meaning.contains('house') ||
        meaning.contains('door') ||
        meaning.contains('chair')) {
      return (Icons.home_rounded, AppColors.secondary, AppColors.secondarySoft);
    }

    return (
      Icons.auto_awesome_rounded,
      AppColors.primary,
      AppColors.primarySoft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (icon, accent, softBg) = _visualForWord();

    return SizedBox(
      width: 78.r,
      height: 78.r,
      child: CustomPaint(
        painter: _VignetteHaloPainter(accent: accent, fill: softBg),
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: YasserShapes.squircle(20),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.r),
              child: Icon(icon, size: 32.r, color: accent),
            ),
          ),
        ),
      ),
    );
  }
}

class _VignetteHaloPainter extends CustomPainter {
  final Color accent;
  final Color fill;

  const _VignetteHaloPainter({required this.accent, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(26),
    );
    canvas.drawRRect(outer, Paint()..color = fill);
    canvas.drawRRect(
      outer,
      Paint()
        ..color = accent.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _VignetteHaloPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.fill != fill;
  }
}
