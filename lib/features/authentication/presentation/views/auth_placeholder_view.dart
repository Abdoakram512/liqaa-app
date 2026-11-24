import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/storage/shared_prefs_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/yasser_avatar.dart';

class AuthPlaceholderView extends StatelessWidget {
  const AuthPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonologicalBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Yasser welcoming avatar
                const YasserAvatar(
                      pose: YasserPose.celebrating,
                      height: 260,
                      animateBreathing: true,
                    )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),

                SizedBox(height: 16.h),

                // Gateway Title
                Text(
                  LocaleKeys.authTitle.tr(),
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                SizedBox(height: 8.h),

                // Subtitle
                Text(
                  LocaleKeys.authSubtitle.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ).animate().fadeIn(delay: 300.ms),

                SizedBox(height: 10.h),

                // Notice Card
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowWarm,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    LocaleKeys.authNotice.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                const Spacer(flex: 2),

                // Role Action Buttons
                PrimaryButton(
                  label: LocaleKeys.authRoleSpecialist.tr(),
                  icon: const Icon(
                    Icons.psychology_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocaleKeys.authNotice.tr()),
                        backgroundColor: AppColors.textPrimary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

                SizedBox(height: 12.h),

                SecondaryButton(
                  label: LocaleKeys.authRoleChild.tr(),
                  icon: const Icon(
                    Icons.child_care_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocaleKeys.authNotice.tr()),
                        backgroundColor: AppColors.textPrimary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

                SizedBox(height: 16.h),

                // Option to reset and replay onboarding
                TextButton.icon(
                  onPressed: () async {
                    await sl<SharedPrefsService>().setOnboardingCompleted(
                      false,
                    );
                    if (context.mounted) {
                      context.go(AppRoutes.onboarding);
                    }
                  },
                  icon: const Icon(
                    Icons.replay_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  label: Text(
                    LocaleKeys.authRestartOnboarding.tr(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms),

                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
