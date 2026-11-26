import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/yasser_surface_card.dart';
import '../../data/models/specialist_models.dart';

/// Real data-driven CustomPainter progress trajectory chart for a child case.
///
/// Renders only verified recorded attempts; shows an honest empty state when
/// no scored attempts exist yet.
class CaseProgressChart extends StatelessWidget {
  final List<PronunciationAttemptRecord> scoredAttempts;

  const CaseProgressChart({super.key, required this.scoredAttempts});

  @override
  Widget build(BuildContext context) {
    if (scoredAttempts.isEmpty) {
      return YasserSurfaceCard(
        backgroundColor: AppColors.surfaceVariant,
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
        radius: AppSpacing.radiusL,
        lipDepth: 2.5,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: ShapeDecoration(
                color: AppColors.secondarySoft,
                shape: YasserShapes.squircle(16),
              ),
              child: const Icon(
                Icons.timeline_rounded,
                color: AppColors.secondary,
                size: 26,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'لا توجد محاولات صوتية مقاسة بعد',
              style: AppTextStyles.titleSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              'ابدأ جلسة تدريب نطق موجهة مع الطفل ليظهر منحنى التقدم الحقيقي للمحاولات المسجلة هنا.',
              style: AppTextStyles.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show up to the latest 10 scored attempts in chronological order
    final visible = scoredAttempts.length > 10
        ? scoredAttempts.sublist(scoredAttempts.length - 10)
        : scoredAttempts;

    return YasserSurfaceCard(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
      radius: AppSpacing.radiusL,
      lipDepth: 3.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'منحنى مؤشر وضوح النطق (آخر ${visible.length} محاولات)',
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '0% – 100%',
                textDirection: TextDirection.ltr,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          SizedBox(
            height: 150.h.clamp(132.0, 176.0),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ProgressTrajectoryPainter(attempts: visible),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: [
              for (int i = 0; i < visible.length; i++)
                Text(
                  '#${i + 1}: ${visible[i].wordArabic} (${visible[i].scoreIndicator!.round()}%)',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: visible[i].passed
                        ? AppColors.successDark
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressTrajectoryPainter extends CustomPainter {
  final List<PronunciationAttemptRecord> attempts;

  const _ProgressTrajectoryPainter({required this.attempts});

  @override
  void paint(Canvas canvas, Size size) {
    const double padTop = 12.0;
    const double padBottom = 14.0;
    const double padX = 14.0;
    final double chartW = math.max(1.0, size.width - padX * 2);
    final double chartH = math.max(1.0, size.height - padTop - padBottom);

    final gridPaint = Paint()
      ..color = AppColors.borderSoft
      ..strokeWidth = 1.0;

    // Horizontal reference grid lines (0%, 50%, 100%)
    for (final level in [0.0, 0.5, 1.0]) {
      final y = padTop + chartH * (1.0 - level);
      canvas.drawLine(Offset(padX, y), Offset(size.width - padX, y), gridPaint);
    }

    final List<Offset> points = [];
    for (int i = 0; i < attempts.length; i++) {
      final double x = attempts.length == 1
          ? size.width * 0.5
          : padX + (chartW * i / (attempts.length - 1));
      final double normY = ((attempts[i].scoreIndicator ?? 0.0) / 100.0).clamp(
        0.0,
        1.0,
      );
      final double y = padTop + chartH * (1.0 - normY);
      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final Path linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final midX = (prev.dx + curr.dx) * 0.5;
        linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }

      final Path areaPath = Path.from(linePath)
        ..lineTo(points.last.dx, padTop + chartH)
        ..lineTo(points.first.dx, padTop + chartH)
        ..close();

      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.secondary.withValues(alpha: 0.24),
              AppColors.primary.withValues(alpha: 0.03),
            ],
          ).createShader(Offset.zero & size),
      );

      canvas.drawPath(
        linePath,
        Paint()
          ..color = AppColors.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Crisp attempt data points
    for (int i = 0; i < points.length; i++) {
      final bool passed = attempts[i].passed;
      final Color nodeColor = passed ? AppColors.success : AppColors.primary;
      canvas.drawCircle(points[i], 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(points[i], 4.8, Paint()..color = nodeColor);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressTrajectoryPainter oldDelegate) {
    return oldDelegate.attempts != attempts;
  }
}
