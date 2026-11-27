import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/ai/models/vocabulary_word.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/yasser_design_tokens.dart';
import '../../../core/widgets/world_painters/illustrated_object_painter.dart';

/// Custom vector-painted vocabulary illustration medallion (zero emojis).
/// Uses [IllustratedVocabularyWidget] inside an organic squircle vignette.
class VocabularyIllustrationBadge extends StatelessWidget {
  final VocabularyWord word;

  const VocabularyIllustrationBadge({super.key, required this.word});

  (Color, Color) _paletteForWord() {
    final meaning = word.meaningEn.toLowerCase();
    final id = word.id.toLowerCase();

    if (id.contains('kora') || meaning.contains('ball')) {
      return (AppColors.primary, AppColors.primarySoft);
    }
    if (id.contains('samaka') || meaning.contains('fish')) {
      return (AppColors.teal, AppColors.tealSoft);
    }
    if (meaning.contains('dog') ||
        meaning.contains('cat') ||
        meaning.contains('rabbit') ||
        meaning.contains('camel') ||
        meaning.contains('horse') ||
        meaning.contains('duck') ||
        meaning.contains('fox') ||
        meaning.contains('elephant')) {
      return (AppColors.primaryDark, AppColors.accentGoldSoft);
    }
    if (meaning.contains('sun') || meaning.contains('butterfly')) {
      return (AppColors.accentCoral, AppColors.accentCoralSoft);
    }
    if (meaning.contains('apple') || meaning.contains('banana')) {
      return (AppColors.success, AppColors.successSoft);
    }
    if (meaning.contains('book') || meaning.contains('pen')) {
      return (AppColors.secondary, AppColors.secondarySoft);
    }
    if (meaning.contains('car') || meaning.contains('plane')) {
      return (AppColors.info, AppColors.infoSoft);
    }
    if (meaning.contains('house') || meaning.contains('door')) {
      return (AppColors.secondary, AppColors.secondarySoft);
    }

    return (AppColors.primary, AppColors.primarySoft);
  }

  @override
  Widget build(BuildContext context) {
    final (accent, softBg) = _paletteForWord();

    return SizedBox(
      width: 82.r,
      height: 82.r,
      child: CustomPaint(
        painter: _VignetteHaloPainter(accent: accent, fill: softBg),
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: YasserShapes.squircle(22),
            ),
            child: Padding(
              padding: EdgeInsets.all(6.r),
              child: IllustratedVocabularyWidget(
                objectKey: '${word.id}_${word.meaningEn}',
                semanticLabel: word.wordArabic,
                size: 56.r,
                accentColor: accent,
              ),
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
