import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/yasser_avatar.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../data/models/onboarding_item_model.dart';

class OnboardingCharacterScene extends StatelessWidget {
  final OnboardingItemModel item;
  final bool isActive;

  const OnboardingCharacterScene({
    super.key,
    required this.item,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (item.environment) {
      case OnboardingEnvironment.welcomeSound:
        return _buildWelcomeScene();
      case OnboardingEnvironment.soundPuzzle:
        return _buildSoundPuzzleScene();
      case OnboardingEnvironment.celebrationLaunch:
        return _buildCelebrationScene();
    }
  }

  /// Screen 1: Welcome Companion Scene
  Widget _buildWelcomeScene() {
    return SizedBox(
      height: 360.h,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Background soft warm circle
          Positioned(
            bottom: 20.h,
            child: Container(
              width: 280.r,
              height: 280.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer.withAlpha(110),
              ),
            ),
          ),

          // Floating letter card 1 (أ)
          Positioned(
            top: 25.h,
            right: 32.w,
            child: _buildFloatingCard('أ', AppColors.primary, 1),
          ),

          // Floating letter card 2 (ب)
          Positioned(
            top: 80.h,
            left: 28.w,
            child: _buildFloatingCard('ب', AppColors.secondary, 2),
          ),

          // Floating audio badge
          Positioned(
            bottom: 50.h,
            right: 30.w,
            child:
                Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusPill,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowWarm,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.waving_hand_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'مرحباً!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
          ),

          // Yasser Avatar (Waving)
          Positioned(
            bottom: 0,
            child:
                YasserCharacter(
                      state: isActive
                          ? YasserAnimationState.greeting
                          : YasserAnimationState.idle,
                      height: 330.h,
                      width: 232.w,
                      showShadow: false,
                    )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  /// Screen 2: Interactive Sound & 103 Cards Scene
  Widget _buildSoundPuzzleScene() {
    return SizedBox(
      height: 360.h,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Background soft purple/lavender circle
          Positioned(
            bottom: 20.h,
            child: Container(
              width: 280.r,
              height: 280.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryContainer.withAlpha(120),
              ),
            ),
          ),

          // Sound wave banner at top
          Positioned(
            top: 15.h,
            left: 30.w,
            child: Builder(
              builder: (context) {
                final wave = Image.asset(AssetPaths.soundWave, width: 110.w);
                if (YasserAvatar.enableRepeatingAnimations) {
                  return wave
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        duration: 1500.ms,
                      );
                }
                return wave;
              },
            ),
          ),

          // 103 Cards Badge
          Positioned(
            top: 30.h,
            right: 28.w,
            child:
                Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                        border: Border.all(
                          color: AppColors.secondary.withAlpha(60),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowWarm,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          Text(
                            '103',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondary,
                            ),
                          ),
                          Text(
                            'بطاقة مصورة',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 350.ms)
                    .slideX(begin: 0.3, end: 0, curve: Curves.easeOutBack),
          ),

          // Yasser Avatar (Thinking with lightbulb)
          Positioned(
            bottom: 0,
            child:
                YasserCharacter(
                      state: isActive
                          ? YasserAnimationState.thinking
                          : YasserAnimationState.idle,
                      height: 330.h,
                      width: 232.w,
                      showShadow: false,
                    )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideX(begin: -0.2, end: 0, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  /// Screen 3: Celebration & Hero's Launch Scene
  Widget _buildCelebrationScene() {
    return SizedBox(
      height: 360.h,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Background soft radiant coral circle
          Positioned(
            bottom: 20.h,
            child: Container(
              width: 290.r,
              height: 290.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFE0D4).withAlpha(140),
              ),
            ),
          ),

          // Floating Sparkle 1
          Positioned(
            top: 20.h,
            right: 40.w,
            child:
                Image.asset(AssetPaths.phonemeStar, width: 36.r, height: 36.r)
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .scale(
                      begin: const Offset(0.2, 0.2),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
          ),

          // Floating Sparkle 2
          Positioned(
            top: 60.h,
            left: 35.w,
            child:
                Image.asset(AssetPaths.phonemeStar, width: 28.r, height: 28.r)
                    .animate()
                    .fadeIn(delay: 450.ms)
                    .scale(
                      begin: const Offset(0.2, 0.2),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
          ),

          // Hero Badge
          Positioned(
            bottom: 40.h,
            left: 24.w,
            child:
                Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusPill,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowWarm,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '⭐ بطل الوعي الصوتي',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accentCoral,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
          ),

          // Yasser Avatar (Celebrating / Fist pump)
          Positioned(
            bottom: 0,
            child:
                YasserCharacter(
                      state: isActive
                          ? YasserAnimationState.celebrating
                          : YasserAnimationState.idle,
                      height: 330.h,
                      width: 232.w,
                      showShadow: false,
                    )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCard(String letter, Color color, int delayIndex) {
    return Container(
          width: 44.r,
          height: 48.r,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusM),
            border: Border.all(color: color.withAlpha(50)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowWarm,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (200 * delayIndex).ms)
        .slideY(begin: -0.3, end: 0, curve: Curves.easeOutBack);
  }
}
