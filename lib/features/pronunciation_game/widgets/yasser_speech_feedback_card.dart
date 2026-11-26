import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../core/animation/yasser/yasser_viseme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/yasser_design_tokens.dart';
import '../../../core/widgets/yasser_character.dart';
import '../../../core/widgets/yasser_speech_bubble.dart';

/// Interactive Yasser companion feedback block with custom-tailed speech bubble
/// and state-driven Rive / 2.5D character motion.
class YasserSpeechFeedbackCard extends StatelessWidget {
  final String message;
  final String poseString;
  final bool isListening;
  final bool isPlayingAudioPrompt;
  final YasserViseme promptViseme;

  const YasserSpeechFeedbackCard({
    super.key,
    required this.message,
    required this.poseString,
    this.isListening = false,
    this.isPlayingAudioPrompt = false,
    this.promptViseme = YasserViseme.rest,
  });

  YasserAnimationState get _animation {
    if (isListening) return YasserAnimationState.listening;
    if (isPlayingAudioPrompt) return YasserAnimationState.talking;
    return switch (poseString) {
      'celebrating' => YasserAnimationState.celebrating,
      'encouraging' => YasserAnimationState.encouraging,
      'retry' ||
      'gentle_retry' ||
      'try_again' => YasserAnimationState.gentleRetry,
      'thinking' => YasserAnimationState.thinking,
      'pointing' || 'presenting' => YasserAnimationState.pointing,
      _ => YasserAnimationState.greeting,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = YasserMotion.isReducedMotion(context);
    final Color accent = isListening
        ? AppColors.accentCoral
        : isPlayingAudioPrompt
        ? AppColors.secondary
        : poseString == 'celebrating'
        ? AppColors.success
        : AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Prominent Yasser Companion
        YasserCharacter(
          state: _animation,
          viseme: isPlayingAudioPrompt ? promptViseme : null,
          width: 108.w.clamp(94.0, 124.0),
          height: 152.h.clamp(132.0, 170.0),
          enableTapReaction: !isListening && !isPlayingAudioPrompt,
          showShadow: true,
        ),

        SizedBox(width: 8.w),

        // Custom-Painted Speech Bubble Pointing Directly to Yasser
        Expanded(
          child: YasserSpeechBubble(
            tailDirection: SpeechBubbleTailDirection.start,
            borderColor: accent.withValues(alpha: 0.35),
            lipColor: accent.withValues(alpha: 0.25),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'ياسر',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    if (isListening)
                      _StatusChip(
                        label: 'يستمع إليك الآن',
                        color: AppColors.accentCoralDark,
                        bg: AppColors.accentCoralSoft,
                        icon: Icons.hearing_rounded,
                      )
                    else if (isPlayingAudioPrompt)
                      _StatusChip(
                        label: 'ينطق المثال',
                        color: AppColors.secondaryDark,
                        bg: AppColors.secondarySoft,
                        icon: Icons.volume_up_rounded,
                      ),
                  ],
                ),
                SizedBox(height: 5.h),
                AnimatedSwitcher(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(target: reduced ? 0 : 1).fadeIn(duration: 260.ms),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: bg, shape: YasserShapes.squircle(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4.w),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10.sp,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
