import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/yasser_design_tokens.dart';

/// Custom-painted harmonic microphone activity visualizer.
///
/// Explicitly labeled as live microphone input level — never misrepresented
/// as pronunciation accuracy.
class SoundWaveformWave extends StatefulWidget {
  final double amplitude;
  final bool isListening;

  const SoundWaveformWave({
    super.key,
    required this.amplitude,
    required this.isListening,
  });

  @override
  State<SoundWaveformWave> createState() => _SoundWaveformWaveState();
}

class _SoundWaveformWaveState extends State<SoundWaveformWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phaseController;

  @override
  void initState() {
    super.initState();
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _syncPhase();
  }

  @override
  void didUpdateWidget(covariant SoundWaveformWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isListening != widget.isListening) {
      _syncPhase();
    }
  }

  void _syncPhase() {
    if (widget.isListening) {
      if (!_phaseController.isAnimating) _phaseController.repeat();
    } else {
      _phaseController.stop();
    }
  }

  @override
  void dispose() {
    _phaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isListening) {
      return const SizedBox.shrink();
    }
    final bool reduced = YasserMotion.isReducedMotion(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: YasserShapes.squircle(
          18,
          side: BorderSide(
            color: AppColors.accentCoral.withValues(alpha: 0.35),
            width: 1.4,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentCoral,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'نشاط الميكروفون المباشر',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accentCoralDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            SizedBox(
              height: 36.h,
              width: 240.w,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _phaseController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _HarmonicBarsPainter(
                        amplitude: widget.amplitude,
                        phase: reduced ? 0.25 : _phaseController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HarmonicBarsPainter extends CustomPainter {
  final double amplitude;
  final double phase;

  const _HarmonicBarsPainter({required this.amplitude, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 19;
    final double spacing = size.width / barCount;
    final double barWidth = (spacing * 0.56).clamp(3.5, 7.0);
    final double clampedAmp = amplitude.clamp(0.05, 1.0);

    for (int i = 0; i < barCount; i++) {
      final double centerWeight =
          1.0 - ((i - (barCount - 1) / 2).abs() / ((barCount - 1) / 2)) * 0.55;
      final double wave =
          0.55 + 0.45 * math.sin((phase * 2 * math.pi) + i * 0.65);
      final double normHeight = (0.18 + clampedAmp * 0.82 * centerWeight * wave)
          .clamp(0.16, 1.0);
      final double h = size.height * normHeight;

      final RRect rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(spacing * (i + 0.5), size.height * 0.5),
          width: barWidth,
          height: h,
        ),
        Radius.circular(barWidth * 0.5),
      );

      final Color color = Color.lerp(
        AppColors.primary,
        AppColors.accentCoral,
        (normHeight - 0.2).clamp(0.0, 1.0),
      )!;
      canvas.drawRRect(rrect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _HarmonicBarsPainter oldDelegate) {
    return (oldDelegate.amplitude - amplitude).abs() > 0.015 ||
        (oldDelegate.phase - phase).abs() > 0.02;
  }
}
