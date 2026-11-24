import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/yasser_avatar.dart';

enum OnboardingEnvironment { welcomeSound, soundPuzzle, celebrationLaunch }

class OnboardingItemModel extends Equatable {
  final int id;
  final String badgeKey;
  final String titleKey;
  final String subtitleKey;
  final YasserPose pose;
  final Color accentColor;
  final Color badgeBackgroundColor;
  final OnboardingEnvironment environment;

  const OnboardingItemModel({
    required this.id,
    required this.badgeKey,
    required this.titleKey,
    required this.subtitleKey,
    required this.pose,
    required this.accentColor,
    required this.badgeBackgroundColor,
    required this.environment,
  });

  @override
  List<Object?> get props => [
    id,
    badgeKey,
    titleKey,
    subtitleKey,
    pose,
    accentColor,
    badgeBackgroundColor,
    environment,
  ];
}
