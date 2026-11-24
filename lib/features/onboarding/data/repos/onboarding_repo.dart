import 'package:flutter/material.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/yasser_avatar.dart';
import '../models/onboarding_item_model.dart';
import '../src/onboarding_local_data_source.dart';

class OnboardingRepo {
  final OnboardingLocalDataSource _localDataSource;

  OnboardingRepo(this._localDataSource);

  bool isOnboardingCompleted() {
    return _localDataSource.isOnboardingCompleted();
  }

  Future<bool> completeOnboarding() async {
    return await _localDataSource.setOnboardingCompleted(true);
  }

  Future<bool> resetOnboarding() async {
    return await _localDataSource.setOnboardingCompleted(false);
  }

  List<OnboardingItemModel> getOnboardingPages() {
    return const [
      // Screen 1: Welcome & Emotional Introduction
      OnboardingItemModel(
        id: 1,
        badgeKey: LocaleKeys.onboardingScreen1Badge,
        titleKey: LocaleKeys.onboardingScreen1Title,
        subtitleKey: LocaleKeys.onboardingScreen1Subtitle,
        pose: YasserPose.waving,
        accentColor: AppColors.primary,
        badgeBackgroundColor: AppColors.primaryContainer,
        environment: OnboardingEnvironment.welcomeSound,
      ),
      // Screen 2: Interactive Discovery (Phonological Skills & 103 Cards)
      OnboardingItemModel(
        id: 2,
        badgeKey: LocaleKeys.onboardingScreen2Badge,
        titleKey: LocaleKeys.onboardingScreen2Title,
        subtitleKey: LocaleKeys.onboardingScreen2Subtitle,
        pose: YasserPose.thinking,
        accentColor: AppColors.secondary,
        badgeBackgroundColor: AppColors.secondaryContainer,
        environment: OnboardingEnvironment.soundPuzzle,
      ),
      // Screen 3: Begin Journey & Launch ("يلا نبدأ")
      OnboardingItemModel(
        id: 3,
        badgeKey: LocaleKeys.onboardingScreen3Badge,
        titleKey: LocaleKeys.onboardingScreen3Title,
        subtitleKey: LocaleKeys.onboardingScreen3Subtitle,
        pose: YasserPose.celebrating,
        accentColor: AppColors.accentCoral,
        badgeBackgroundColor: Color(0xFFFFE0D4),
        environment: OnboardingEnvironment.celebrationLaunch,
      ),
    ];
  }
}
