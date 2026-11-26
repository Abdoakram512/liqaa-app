import 'package:flutter/animation.dart';
import 'yasser_animation_capabilities.dart';
import 'yasser_animation_state.dart';

/// Configuration for Yasser's dynamic character behaviors.
class YasserAnimationConfig {
  /// Default duration for ambient breathing loop.
  final Duration breathingDuration;

  /// Minimum time between randomized blinks.
  final Duration minBlinkInterval;

  /// Maximum time between randomized blinks.
  final Duration maxBlinkInterval;

  /// Duration to hold a transient celebration or confusion reaction before returning to idle.
  final Duration transientHoldDuration;

  /// Minimum duration between consecutive user tap reactions to prevent animation thrashing.
  final Duration tapCooldown;

  /// Curve used for smooth eye/gaze tracking interpolation.
  final Curve gazeSmoothingCurve;

  /// Default character artboard name in Rive.
  final String artboardName;

  /// Default character state machine name in Rive.
  final String stateMachineName;

  /// Primary boolean input for password privacy.
  final String passwordInputName;

  const YasserAnimationConfig({
    this.breathingDuration = const Duration(milliseconds: 2400),
    this.minBlinkInterval = const Duration(seconds: 3),
    this.maxBlinkInterval = const Duration(seconds: 7),
    this.transientHoldDuration = const Duration(milliseconds: 2000),
    this.tapCooldown = const Duration(milliseconds: 600),
    this.gazeSmoothingCurve = Curves.easeInOutCubic,
    this.artboardName = YasserAnimationCapabilities.artboardName,
    this.stateMachineName = YasserAnimationCapabilities.stateMachineName,
    this.passwordInputName = 'passwordTyping',
  });

  /// Map each semantic state to its inherent priority.
  static YasserAnimationPriority getPriority(YasserAnimationState state) {
    switch (state) {
      case YasserAnimationState.idle:
      case YasserAnimationState.breathing:
      case YasserAnimationState.blinking:
        return YasserAnimationPriority.ambient;

      case YasserAnimationState.lookingLeft:
      case YasserAnimationState.lookingRight:
      case YasserAnimationState.lookingUp:
      case YasserAnimationState.lookingDown:
      case YasserAnimationState.followingInput:
      case YasserAnimationState.waiting:
      case YasserAnimationState.curious:
      case YasserAnimationState.onboardingWelcome:
      case YasserAnimationState.onboardingDiscovery:
      case YasserAnimationState.onboardingReady:
        return YasserAnimationPriority.attentive;

      case YasserAnimationState.waving:
      case YasserAnimationState.greeting:
      case YasserAnimationState.pointing:
      case YasserAnimationState.thinking:
      case YasserAnimationState.listening:
      case YasserAnimationState.talking:
        return YasserAnimationPriority.gesture;

      case YasserAnimationState.happy:
      case YasserAnimationState.excited:
      case YasserAnimationState.confused:
      case YasserAnimationState.gentleRetry:
      case YasserAnimationState.sad:
      case YasserAnimationState.encouraging:
      case YasserAnimationState.celebrating:
      case YasserAnimationState.sessionComplete:
      case YasserAnimationState.returningToIdle:
        return YasserAnimationPriority.transient;

      case YasserAnimationState.coveringEyes:
      case YasserAnimationState.peeking:
        return YasserAnimationPriority.critical;
    }
  }
}
