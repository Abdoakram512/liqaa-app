import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/yasser/yasser_animation_state.dart';
import '../../../../core/animation/yasser/yasser_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../../../core/widgets/yasser_buttons.dart';
import '../../../../core/widgets/yasser_character.dart';
import '../../../../core/widgets/yasser_speech_bubble.dart';

/// Shared responsive, keyboard-adaptive shell for all Authentication screens.
///
/// Preserves the exact same [YasserCharacter] instance across keyboard open/close
/// transitions so Rive rig state (gaze, privacy cover, peek) stays seamless.
class AuthStageShell extends StatelessWidget {
  final String title;
  final String speechTitle;
  final String? speechSubtitle;
  final YasserController? yasserController;
  final YasserAnimationState? fallbackState;
  final String heroTag;
  final Widget formChild;
  final Widget? footerChild;
  final bool showBack;
  final bool showLocalModeNote;

  const AuthStageShell({
    super.key,
    required this.title,
    required this.speechTitle,
    this.speechSubtitle,
    this.yasserController,
    this.fallbackState,
    required this.heroTag,
    required this.formChild,
    this.footerChild,
    this.showBack = true,
    this.showLocalModeNote = true,
  });

  @override
  Widget build(BuildContext context) {
    final double viewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardOpen = viewInsetBottom > 80;
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    final bool reduced = YasserMotion.isReducedMotion(context);

    return PhonologicalBackground(
      variant: PhonologicalSceneVariant.calmForm,
      child: SafeArea(
        child: Column(
          children: [
            // Top Navigation Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Row(
                children: [
                  if (showBack && Navigator.of(context).canPop())
                    YasserIconButton(
                      icon: isRtl
                          ? Icons.arrow_back_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      tooltip: 'رجوع',
                      onPressed: () => context.pop(),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),

            // Scrollable Adaptive Stage + Form Card
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxFormWidth + 32,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(22.w, 4.h, 22.w, 24.h),
                    child: Column(
                      children: [
                        // Adaptive Character Stage (Compacts smoothly when keyboard opens)
                        AnimatedContainer(
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.only(
                            bottom: keyboardOpen ? 8.h : 14.h,
                          ),
                          child: keyboardOpen
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 92.w.clamp(80.0, 108.0),
                                      height: 108.h.clamp(92.0, 124.0),
                                      child: YasserCharacter(
                                        controller: yasserController,
                                        state: fallbackState,
                                        width: 92.w.clamp(80.0, 108.0),
                                        height: 108.h.clamp(92.0, 124.0),
                                        heroTag: heroTag,
                                        showShadow: false,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: YasserSpeechBubble(
                                        tailDirection:
                                            SpeechBubbleTailDirection.start,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 10.h,
                                        ),
                                        child: Text(
                                          speechTitle,
                                          style: AppTextStyles.labelLarge
                                              .copyWith(
                                                color: AppColors.primaryDeep,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        Container(
                                          width: 190.w.clamp(160.0, 220.0),
                                          height: 164.h.clamp(140.0, 195.0),
                                          decoration: ShapeDecoration(
                                            color: AppColors.primaryContainer
                                                .withValues(alpha: 0.58),
                                            shape: YasserShapes.squircle(44),
                                          ),
                                        ),
                                        YasserCharacter(
                                          controller: yasserController,
                                          state: fallbackState,
                                          width: 196.w.clamp(165.0, 226.0),
                                          height: 218.h.clamp(185.0, 248.0),
                                          heroTag: heroTag,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),
                                    YasserSpeechBubble(
                                      tailDirection:
                                          SpeechBubbleTailDirection.top,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 11.h,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            speechTitle,
                                            textAlign: TextAlign.center,
                                            style: AppTextStyles.titleSmall
                                                .copyWith(
                                                  color: AppColors.primaryDeep,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          if (speechSubtitle != null &&
                                              speechSubtitle!.isNotEmpty) ...[
                                            SizedBox(height: 3.h),
                                            Text(
                                              speechSubtitle!,
                                              textAlign: TextAlign.center,
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        // Main Tactile Form Surface Card
                        DecoratedBox(
                          decoration: ShapeDecoration(
                            color: AppColors.surface,
                            shape: YasserShapes.squircle(
                              AppSpacing.radiusXL,
                              side: const BorderSide(
                                color: AppColors.borderSoft,
                                width: 1.5,
                              ),
                            ),
                            shadows: YasserDesignTokens.of(
                              context,
                            ).softCardShadows,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 20.h,
                            ),
                            child: formChild,
                          ),
                        ),

                        if (footerChild != null) ...[
                          SizedBox(height: 16.h),
                          footerChild!,
                        ],

                        if (showLocalModeNote && !keyboardOpen) ...[
                          SizedBox(height: 14.h),
                          DecoratedBox(
                            decoration: ShapeDecoration(
                              color: AppColors.surfaceSubtle,
                              shape: YasserShapes.squircle(14),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 6.w),
                                  Flexible(
                                    child: Text(
                                      'بيئة عمل محلية على الجهاز — البيانات محفوظة محلياً',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
