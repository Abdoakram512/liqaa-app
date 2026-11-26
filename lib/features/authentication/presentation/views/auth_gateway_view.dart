import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_speech_bubble.dart';
import '../../../../core/widgets/yasser_surface_card.dart';

/// Welcoming interactive Gateway Portal where Yasser invites Children, Parents,
/// and Speech Specialists into their respective experiences.
class AuthGatewayView extends StatelessWidget {
  const AuthGatewayView({super.key});

  @override
  Widget build(BuildContext context) {
    final bool reduced = YasserMotion.isReducedMotion(context);

    return Scaffold(
      body: PhonologicalBackground(
        variant: PhonologicalSceneVariant.sunriseArch,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxFormWidth + 32,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                child: Column(
                  children: [
                    // Top Platform Identity Pill
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: AppColors.surface,
                        shape: YasserShapes.squircle(
                          AppSpacing.radiusM,
                          side: const BorderSide(
                            color: AppColors.borderSoft,
                            width: 1.4,
                          ),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: AppColors.shadowWarm,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.graphic_eq_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8.w),
                            Flexible(
                              child: Text(
                                'منصة لِقَاء للوعي الصوتي والتخاطب',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.primaryDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Hero-Linked Yasser Stage
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 220.w.clamp(180.0, 260.0),
                          height: 205.h.clamp(170.0, 240.0),
                          decoration: ShapeDecoration(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.62,
                            ),
                            shape: YasserShapes.squircle(52),
                          ),
                        ),
                        Hero(
                          tag: 'yasser_primary_stage_hero',
                          child: YasserCharacter(
                            state: YasserAnimationState.greeting,
                            width: 232.w.clamp(185.0, 265.0),
                            height: 280.h.clamp(220.0, 315.0),
                            heroTag: 'yasser_auth_gateway',
                          ),
                        ),
                      ],
                    ).animate(target: reduced ? 0 : 1).fadeIn(duration: 450.ms),

                    SizedBox(height: 10.h),

                    // Hand-Crafted Speech Bubble Greeting
                    YasserSpeechBubble(
                      tailDirection: SpeechBubbleTailDirection.top,
                      child: Column(
                        children: [
                          Text(
                            'أهلاً بك يا بطل في عالم الأصوات!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.primaryDeep,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'اختر حسابك لنبدأ مغامرة نطق الحروف والكلمات أو متابعة تقدم الأبطال في الجلسات.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Primary & Secondary Account Actions
                    PrimaryButton(
                      label: 'تسجيل الدخول',
                      icon: const Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => context.push(AppRoutes.login),
                    ),

                    SizedBox(height: 12.h),

                    SecondaryButton(
                      label: 'إنشاء حساب جديد',
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      onPressed: () => context.push(AppRoutes.register),
                    ),

                    SizedBox(height: 16.h),

                    // Quick Practice Entry Card
                    YasserSurfaceCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      onTap: () => context.push(AppRoutes.home),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: ShapeDecoration(
                              color: AppColors.accentMintSoft,
                              shape: YasserShapes.squircle(14),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.accentMintDark,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تجربة عالم ياسر السريعة',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'ابدأ التدريب الصوتي مباشرة بدون انتظار',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),

                    if (kDebugMode) ...[
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        alignment: WrapAlignment.center,
                        children: [
                          YasserOutlineButton(
                            label: 'مختبر أنيميشن ياسر',
                            width: 170.w,
                            icon: const Icon(Icons.animation_rounded, size: 18),
                            onPressed: () =>
                                context.push(AppRoutes.animationLab),
                          ),
                          YasserOutlineButton(
                            label: 'مختبر الذكاء الاصطناعي',
                            width: 185.w,
                            icon: const Icon(Icons.science_rounded, size: 18),
                            onPressed: () => context.push(AppRoutes.aiLab),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: 12.h),
                    TextButton.icon(
                      onPressed: () => context.go(AppRoutes.onboarding),
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: const Text('إعادة جولة التعرف على ياسر'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
