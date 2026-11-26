import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../audio/yasser_audio_coordinator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/yasser_design_tokens.dart';
import 'yasser_buttons.dart';
import 'yasser_surface_card.dart';

/// Tactile bottom sheet allowing learners, parents, and specialists to
/// independently control Yasser's voice prompts, UI chimes, and haptics.
Future<void> showYasserAudioSettingsSheet(
  BuildContext context, {
  required YasserAudioCoordinator coordinator,
  VoidCallback? onReplayOnboarding,
  VoidCallback? onLogout,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _YasserAudioSettingsSheet(
        coordinator: coordinator,
        onReplayOnboarding: onReplayOnboarding,
        onLogout: onLogout,
      );
    },
  );
}

class _YasserAudioSettingsSheet extends StatelessWidget {
  final YasserAudioCoordinator coordinator;
  final VoidCallback? onReplayOnboarding;
  final VoidCallback? onLogout;

  const _YasserAudioSettingsSheet({
    required this.coordinator,
    this.onReplayOnboarding,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.background,
        shape: YasserShapes.squircle(
          AppSpacing.radiusXL,
          side: const BorderSide(color: AppColors.borderSoft, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          child: ListenableBuilder(
            listenable: coordinator,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: ShapeDecoration(
                          color: AppColors.primarySoft,
                          shape: YasserShapes.squircle(14),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إعدادات الصوت والتجربة',
                              style: AppTextStyles.headlineSmall,
                            ),
                            Text(
                              'تحكّم في صوت ياسر والمؤثرات الصوتية والاهتزاز',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),

                  _ToggleTile(
                    icon: Icons.record_voice_over_rounded,
                    accent: AppColors.primary,
                    title: 'صوت ياسر الإرشادي',
                    subtitle: 'تشغيل أمثلة نطق الكلمات بصوت ياسر',
                    value: coordinator.voiceEnabled,
                    onChanged: coordinator.setVoiceEnabled,
                  ),
                  SizedBox(height: 10.h),

                  _ToggleTile(
                    icon: Icons.music_note_rounded,
                    accent: AppColors.secondary,
                    title: 'المؤثرات الصوتية اللطيفة',
                    subtitle: 'نغمات هادئة عند التفاعل والفوز بالنجوم',
                    value: coordinator.sfxEnabled,
                    onChanged: coordinator.setSfxEnabled,
                  ),
                  SizedBox(height: 10.h),

                  _ToggleTile(
                    icon: Icons.vibration_rounded,
                    accent: AppColors.teal,
                    title: 'الاستجابة اللمسية (الاهتزاز)',
                    subtitle: 'نبضة لمسية خفيفة عند الضغط على الأزرار',
                    value: coordinator.hapticsEnabled,
                    onChanged: coordinator.setHapticsEnabled,
                  ),

                  if (onReplayOnboarding != null || onLogout != null) ...[
                    SizedBox(height: 18.h),
                    const Divider(color: AppColors.borderSoft),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        if (onReplayOnboarding != null)
                          Expanded(
                            child: YasserOutlineButton(
                              label: 'جولة البداية',
                              icon: const Icon(Icons.auto_stories_rounded),
                              onPressed: () {
                                Navigator.of(context).pop();
                                onReplayOnboarding!();
                              },
                            ),
                          ),
                        if (onReplayOnboarding != null && onLogout != null)
                          SizedBox(width: 10.w),
                        if (onLogout != null)
                          Expanded(
                            child: YasserOutlineButton(
                              label: 'تسجيل الخروج',
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.error,
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                onLogout!();
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return YasserSurfaceCard(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      radius: AppSpacing.radiusM,
      lipDepth: 3.0,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: YasserShapes.squircle(12),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                Text(subtitle, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
