import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/yasser_avatar.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_speech_bubble.dart';

/// Cinematic yet lightweight startup stage seamlessly bridging native #FFF7EA
/// splash into Onboarding, Auth, or Home without flashes or character jumps.
class SplashContent extends StatelessWidget {
  const SplashContent({super.key});

  @override
  Widget build(BuildContext context) {
    final bool reduced = YasserMotion.isReducedMotion(context);
    final bool animateLoops =
        YasserAvatar.enableRepeatingAnimations && !reduced;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Organic Acoustic Stage + Yasser Entrance
          SizedBox(
            height: 350.h.clamp(270.0, 390.0),
            width: 330.w.clamp(260.0, 360.0),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Custom-painted warm stage arch & harmonic rings
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _SplashStageArchPainter()),
                  ),
                ),

                // Vector acoustic pill (top-left, no emojis)
                Positioned(
                  top: 32.h,
                  left: 10.w,
                  child: _SplashFloatingChip(
                    icon: Icons.graphic_eq_rounded,
                    label: 'عالم الأصوات',
                    accent: AppColors.primaryDark,
                    animate: !reduced,
                    delayMs: 320,
                  ),
                ),

                // Vector star pill (top-right, no emojis)
                Positioned(
                  top: 16.h,
                  right: 12.w,
                  child: _SplashFloatingChip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'تعلّم باللعب',
                    accent: AppColors.secondary,
                    animate: !reduced,
                    delayMs: 460,
                  ),
                ),

                // Yasser Character (Shared Hero Anchor)
                Positioned(
                  bottom: 6.h,
                  child:
                      Hero(
                            tag: 'yasser_primary_stage_hero',
                            child: YasserCharacter(
                              state: YasserAnimationState.greeting,
                              height: 300.h.clamp(220.0, 330.0),
                              width: 218.w.clamp(170.0, 244.0),
                              showShadow: true,
                              enableTapReaction: false,
                            ),
                          )
                          .animate(target: reduced ? 0 : 1)
                          .fadeIn(duration: 450.ms)
                          .scale(
                            begin: const Offset(0.92, 0.92),
                            end: const Offset(1.0, 1.0),
                            duration: 580.ms,
                            curve: YasserMotion.springOut,
                          ),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          // Brand Title: "لِقَاء"
          Text(
                LocaleKeys.appName.tr(),
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 38.sp,
                ),
              )
              .animate(target: reduced ? 0 : 1)
              .fadeIn(delay: 180.ms, duration: 420.ms),

          SizedBox(height: 6.h),

          Text(
                LocaleKeys.appTagline.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              )
              .animate(target: reduced ? 0 : 1)
              .fadeIn(delay: 260.ms, duration: 420.ms),

          const Spacer(flex: 2),

          // Warm Speech Bubble Welcome Status
          YasserSpeechBubble(
            tailDirection: SpeechBubbleTailDirection.top,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (animateLoops) ...[
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                ] else ...[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8.w),
                ],
                Flexible(
                  child: Text(
                    LocaleKeys.splashWelcome.tr(),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _SplashFloatingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool animate;
  final int delayMs;

  const _SplashFloatingChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.animate,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    final pill = DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: YasserShapes.squircle(
          AppSpacing.radiusM,
          side: BorderSide(color: accent.withValues(alpha: 0.28), width: 1.4),
        ),
        shadows: const [
          BoxShadow(
            color: AppColors.shadowWarm,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accent),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    if (!animate) return pill;
    return pill
        .animate()
        .fadeIn(delay: delayMs.ms, duration: 380.ms)
        .slideY(begin: 0.25, end: 0, curve: YasserMotion.springOut);
  }
}

class _SplashStageArchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.54);
    final double archW = size.width * 0.76;
    final double archH = size.height * 0.78;

    final Rect archRect = Rect.fromCenter(
      center: center,
      width: archW,
      height: archH,
    );
    final RRect arch = RRect.fromRectAndCorners(
      archRect,
      topLeft: Radius.circular(archW * 0.52),
      topRight: Radius.circular(archW * 0.52),
      bottomLeft: const Radius.circular(36),
      bottomRight: const Radius.circular(36),
    );

    canvas.drawRRect(
      arch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.85),
            AppColors.surface.withValues(alpha: 0.55),
          ],
        ).createShader(archRect),
    );

    canvas.drawRRect(
      arch.inflate(12),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
