import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/yasser_character.dart';

/// Premium interactive Gateway Portal where Yasser warmly welcomes users.
class AuthGatewayView extends StatelessWidget {
  const AuthGatewayView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonologicalBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 16.h),

                // Top Header Pill: Platform Branding
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowWarm,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10.r,
                        height: 10.r,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'منصة لِقَاء التعليمية للوعي الصوتي',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                SizedBox(height: 20.h),

                // Yasser Welcoming Avatar with Tap Reaction
                YasserCharacter(
                  width: 250.w,
                  height: 310.h,
                  heroTag: 'yasser_auth_gateway',
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15, end: 0),

                SizedBox(height: 12.h),

                // Title & Welcoming Speech Bubble
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowWarm,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'أهلاً بك يا بطل في عالم الأصوات!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'أنا ياسر رفيقك الذكي.. مستعد نبدأ رحلة التدريب الصوتي الممتعة معاً؟',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

                SizedBox(height: 24.h),

                // Action Buttons
                PrimaryButton(
                  label: 'تسجيل دخول البطل',
                  icon: const Icon(Icons.login_rounded, color: Colors.white),
                  onPressed: () => context.push(AppRoutes.login),
                ).animate().fadeIn(delay: 350.ms),

                SizedBox(height: 12.h),

                SecondaryButton(
                  label: 'إنشاء حساب جديد للبطل',
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                  onPressed: () => context.push(AppRoutes.register),
                ).animate().fadeIn(delay: 450.ms),

                SizedBox(height: 20.h),

                // Developer & Quick Access Lab Pills
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.smart_toy, size: 16, color: AppColors.primary),
                      label: const Text('مختبر أنيميشن ياسر (Lab)'),
                      backgroundColor: Colors.white,
                      elevation: 1,
                      onPressed: () => context.push(AppRoutes.animationLab),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.mic, size: 16, color: Colors.teal),
                      label: const Text('لعبة نطق الأصوات (Game)'),
                      backgroundColor: Colors.white,
                      elevation: 1,
                      onPressed: () => context.push(AppRoutes.game),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.science, size: 16, color: Colors.indigo),
                      label: const Text('مختبر الذكاء الاصطناعي (AI Lab)'),
                      backgroundColor: Colors.white,
                      elevation: 1,
                      onPressed: () => context.push(AppRoutes.aiLab),
                    ),
                  ],
                ).animate().fadeIn(delay: 550.ms),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
