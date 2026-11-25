import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/widgets/yasser_avatar.dart';
import '../../../../core/widgets/yasser_character.dart';

class SplashContent extends StatelessWidget {
  const SplashContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Central Visual Scene: Concentric Sound Rings + Yasser Waving
          SizedBox(
            height: 380.h,
            width: 340.w,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Animated soundwave halo rings in brand amber
                Builder(
                  builder: (context) {
                    final halo = Container(
                      width: 290.r,
                      height: 290.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryLight.withAlpha(50),
                          width: 2,
                        ),
                      ),
                    );
                    if (YasserAvatar.enableRepeatingAnimations) {
                      return halo
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(0.92, 0.92),
                            end: const Offset(1.06, 1.06),
                            duration: 1800.ms,
                            curve: Curves.easeInOutSine,
                          );
                    }
                    return halo;
                  },
                ),

                // Secondary inner halo
                Container(
                      width: 220.r,
                      height: 220.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryContainer.withAlpha(90),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1.0, 1.0),
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    ),

                // Floating phoneme sparkle accents
                Positioned(
                  top: 20.h,
                  right: 25.w,
                  child:
                      Image.asset(
                            AssetPaths.phonemeStar,
                            width: 32.r,
                            height: 32.r,
                          )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 400.ms)
                          .scale(
                            begin: const Offset(0, 0),
                            end: const Offset(1, 1),
                            curve: Curves.easeOutBack,
                          ),
                ),

                Positioned(
                  top: 60.h,
                  left: 20.w,
                  child:
                      Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusPill,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowWarm,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '🎵 أصوات',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 650.ms, duration: 400.ms)
                          .slideY(
                            begin: 0.3,
                            end: 0,
                            curve: Curves.easeOutBack,
                          ),
                ),

                // Yasser entering the scene with spring physics
                Positioned(
                  bottom: 0,
                  child:
                      YasserCharacter(
                            state: YasserAnimationState.greeting,
                            height: 320.h,
                            width: 224.w,
                            showShadow: false,
                            enableTapReaction: false,
                          )
                          .animate()
                          .fadeIn(duration: 700.ms)
                          .slideY(
                            begin: 0.35,
                            end: 0,
                            duration: 850.ms,
                            curve: Curves.easeOutBack,
                          )
                          .scale(
                            begin: const Offset(0.85, 0.85),
                            end: const Offset(1.0, 1.0),
                            duration: 850.ms,
                            curve: Curves.easeOutBack,
                          ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Brand Title: "لِقَاء"
          Text(
                LocaleKeys.appName.tr(),
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 38.sp,
                  letterSpacing: 0.5,
                ),
              )
              .animate()
              .fadeIn(delay: 350.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

          SizedBox(height: 6.h),

          // Subtitle / Tagline
          Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Text(
                  LocaleKeys.appTagline.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 500.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

          const Spacer(flex: 3),

          // Welcome greeting banner at bottom
          Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(210),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (YasserAvatar.enableRepeatingAnimations) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                    ],
                    Text(
                      LocaleKeys.splashWelcome.tr(),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: 700.ms, duration: 500.ms)
              .slideY(begin: 0.3, end: 0),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
