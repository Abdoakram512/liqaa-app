import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/yasser_avatar.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_speech_bubble.dart';
import '../../data/models/onboarding_item_model.dart';

/// Expressive organic character stage for each chapter of Yasser's onboarding story.
class OnboardingCharacterScene extends StatelessWidget {
  final OnboardingItemModel item;
  final bool isActive;
  final double parallaxOffset;

  const OnboardingCharacterScene({
    super.key,
    required this.item,
    this.isActive = true,
    this.parallaxOffset = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool reduced = YasserMotion.isReducedMotion(context);
    final double px = reduced ? 0.0 : parallaxOffset * 26.0;

    return switch (item.environment) {
      OnboardingEnvironment.welcomeSound => _buildWelcomeScene(
        context,
        px,
        reduced,
      ),
      OnboardingEnvironment.soundPuzzle => _buildSoundPuzzleScene(
        context,
        px,
        reduced,
      ),
      OnboardingEnvironment.celebrationLaunch => _buildCelebrationScene(
        context,
        px,
        reduced,
      ),
    };
  }

  /// Chapter 1: Warm Companion Stage
  Widget _buildWelcomeScene(BuildContext context, double px, bool reduced) {
    return SizedBox(
      height: 360.h,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OnboardingStagePainter(
                  primaryTint: AppColors.primaryContainer,
                  accentBorder: AppColors.primary,
                  styleIndex: 0,
                ),
              ),
            ),
          ),
          Positioned(
            top: 22.h,
            right: 26.w - px * 0.7,
            child: _buildPhonemeTile('أ', AppColors.primary, 1, reduced),
          ),
          Positioned(
            top: 74.h,
            left: 24.w + px * 0.7,
            child: _buildPhonemeTile('ب', AppColors.secondary, 2, reduced),
          ),
          Positioned(
            bottom: 42.h,
            right: 20.w - px * 0.4,
            child:
                YasserSpeechBubble(
                      tailDirection: SpeechBubbleTailDirection.start,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 7.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.waving_hand_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            'أهلاً يا بطل!',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(target: (!reduced && isActive) ? 1 : 0)
                    .fadeIn(delay: 260.ms),
          ),
          Positioned(
            bottom: 4,
            child: _character(YasserAnimationState.onboardingWelcome),
          ),
        ],
      ),
    );
  }

  /// Chapter 2: Interactive Sound Discovery & 103 Illustrated Cards
  Widget _buildSoundPuzzleScene(BuildContext context, double px, bool reduced) {
    return SizedBox(
      height: 360.h,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OnboardingStagePainter(
                  primaryTint: AppColors.secondaryContainer,
                  accentBorder: AppColors.secondary,
                  styleIndex: 1,
                ),
              ),
            ),
          ),
          Positioned(
            top: 18.h,
            left: 22.w + px * 0.6,
            child: Builder(
              builder: (context) {
                final wave = Image.asset(AssetPaths.soundWave, width: 106.w);
                if (YasserAvatar.enableRepeatingAnimations && !reduced) {
                  return wave
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.96, 0.96),
                        end: const Offset(1.04, 1.04),
                        duration: 1500.ms,
                      );
                }
                return wave;
              },
            ),
          ),
          Positioned(
            top: 26.h,
            right: 22.w - px * 0.8,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: YasserShapes.squircle(
                  AppSpacing.radiusM,
                  side: BorderSide(
                    color: AppColors.secondary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                shadows: const [
                  BoxShadow(
                    color: AppColors.shadowWarm,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '103',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'بطاقة صوتية',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 46.h,
            left: 22.w + px * 0.5,
            child: _buildPhonemeTile('س', AppColors.accentMint, 2, reduced),
          ),
          Positioned(
            bottom: 4,
            child: _character(YasserAnimationState.onboardingDiscovery),
          ),
        ],
      ),
    );
  }

  /// Chapter 3: Celebration & Launchpad (Vector badge kept clear of Yasser's feet)
  Widget _buildCelebrationScene(BuildContext context, double px, bool reduced) {
    return SizedBox(
      height: 360.h,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OnboardingStagePainter(
                  primaryTint: AppColors.accentGoldSoft,
                  accentBorder: AppColors.primary,
                  styleIndex: 2,
                ),
              ),
            ),
          ),
          Positioned(
            top: 26.h,
            right: 34.w - px * 0.7,
            child: Image.asset(
              AssetPaths.phonemeStar,
              width: 34.r,
              height: 34.r,
            ),
          ),
          Positioned(
            top: 64.h,
            left: 30.w + px * 0.7,
            child: Image.asset(
              AssetPaths.phonemeStar,
              width: 26.r,
              height: 26.r,
            ),
          ),
          // Vector Hero Badge above Yasser (no emoji, zero overlap with feet)
          Positioned(
            top: 0,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: YasserShapes.squircle(
                  AppSpacing.radiusM,
                  side: const BorderSide(
                    color: AppColors.borderSoft,
                    width: 1.5,
                  ),
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
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'بطل الوعي الصوتي',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            child: _character(YasserAnimationState.onboardingReady),
          ),
        ],
      ),
    );
  }

  Widget _character(YasserAnimationState pose) => YasserCharacter(
    state: isActive ? pose : YasserAnimationState.idle,
    poseStartDelay: const Duration(milliseconds: 160),
    height: 326.h,
    width: 230.w,
    showShadow: true,
    enableTapReaction: false,
  );

  Widget _buildPhonemeTile(
    String letter,
    Color color,
    int delayIndex,
    bool reduced,
  ) {
    final tile = DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: YasserShapes.squircle(
          15,
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.6),
        ),
        shadows: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 0,
            offset: const Offset(0, 3),
          ),
          const BoxShadow(
            color: AppColors.shadowWarm,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: 48.r,
        height: 50.r,
        child: Center(
          child: Text(
            letter,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ),
    );

    if (reduced) return tile;
    return tile
        .animate(target: isActive ? 1 : 0)
        .fadeIn(delay: (160 * delayIndex).ms)
        .slideY(begin: -0.22, end: 0, curve: YasserMotion.springOut);
  }
}

class _OnboardingStagePainter extends CustomPainter {
  final Color primaryTint;
  final Color accentBorder;
  final int styleIndex;

  const _OnboardingStagePainter({
    required this.primaryTint,
    required this.accentBorder,
    required this.styleIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.5, h * 0.54);

    if (styleIndex == 0) {
      // Warm Sunrise Portal Arch
      final Rect rect = Rect.fromCenter(
        center: center,
        width: w * 0.76,
        height: h * 0.76,
      );
      final RRect arch = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(w * 0.4),
        topRight: Radius.circular(w * 0.4),
        bottomLeft: const Radius.circular(34),
        bottomRight: const Radius.circular(34),
      );
      canvas.drawRRect(
        arch,
        Paint()..color = primaryTint.withValues(alpha: 0.65),
      );
      canvas.drawRRect(
        arch,
        Paint()
          ..color = accentBorder.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    } else if (styleIndex == 1) {
      // Organic Tilted Squircle Sound Stage
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.045);
      final RRect stage = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.78, height: h * 0.72),
        const Radius.circular(56),
      );
      canvas.drawRRect(
        stage,
        Paint()..color = primaryTint.withValues(alpha: 0.72),
      );
      canvas.drawRRect(
        stage,
        Paint()
          ..color = accentBorder.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.restore();
    } else {
      // Radiant Celebration Crest
      final Rect crest = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.56),
        width: w * 0.80,
        height: h * 0.74,
      );
      final RRect outer = RRect.fromRectAndRadius(
        crest,
        const Radius.circular(64),
      );
      canvas.drawRRect(
        outer,
        Paint()..color = primaryTint.withValues(alpha: 0.68),
      );
      canvas.drawRRect(
        outer.deflate(14),
        Paint()
          ..color = accentBorder.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingStagePainter oldDelegate) {
    return oldDelegate.styleIndex != styleIndex ||
        oldDelegate.primaryTint != primaryTint;
  }
}
