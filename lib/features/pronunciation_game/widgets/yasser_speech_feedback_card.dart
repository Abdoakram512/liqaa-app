import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../core/animation/yasser/yasser_viseme.dart';
import '../../../core/widgets/yasser_character.dart';

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
      'thinking' => YasserAnimationState.thinking,
      'pointing' || 'presenting' => YasserAnimationState.pointing,
      _ => YasserAnimationState.greeting,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Yasser Character Avatar
        YasserCharacter(
          state: _animation,
          viseme: isPlayingAudioPrompt ? promptViseme : null,
          width: 98.w,
          height: 140.h,
          enableTapReaction: false,
          showShadow: false,
        ),

        SizedBox(width: 10.w),

        // Speech Bubble
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: 24.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusM),
                topRight: Radius.circular(AppSpacing.radiusM),
                bottomLeft: Radius.circular(AppSpacing.radiusM),
                bottomRight: const Radius.circular(4),
              ),
              border: Border.all(color: AppColors.borderSoft),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowWarm,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'ياسر:',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (isListening) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'يستمع الآن...',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
        ),
      ],
    );
  }
}
