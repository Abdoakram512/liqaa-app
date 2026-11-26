import 'dart:ui';
import 'yasser_animation_state.dart';

/// Mapping contract result specifying both Rive `ViewModel1` inputs
/// and high-resolution 2.5D fallback assets.
class YasserStateMapping {
  final YasserAnimationState semanticState;

  /// Whether the primary Rive `passwordTyping` boolean input should be true.
  final bool rivePasswordTyping;

  /// Whether Rive `isPeeking` boolean input should be true.
  final bool riveIsPeeking;

  /// Whether Rive `isListening` boolean input should be true.
  final bool riveIsListening;

  /// Whether Rive `isThinking` boolean input should be true.
  final bool riveIsThinking;

  /// Whether Rive `isSpeaking` boolean input should be true.
  final bool riveIsSpeaking;

  /// Whether Rive `isFollowingInput` boolean input should be true.
  final bool riveIsFollowingInput;

  /// Onboarding chapter selector (`0` = none, `1..3` = onboarding chapters).
  final double riveOnboardingScene;

  /// ViewModel1 trigger name to fire when entering this mapping (`wave`, `celebrate`, etc.).
  final String? riveViewModelTrigger;

  /// Legacy diagnostic label retained for compatibility with mapper audit tests.
  final String? riveAnimationTrigger;

  /// Default Rive `mouthShape` (`0..8`) when live audio visemes are inactive.
  final int defaultMouthShape;

  /// Normalized eye gaze target (horizontal: -1.0 to 1.0, vertical: -1.0 to 1.0).
  final Offset gazeTarget;

  /// High-resolution 2.5D PNG fallback pose.
  final String fallbackAssetPath;

  /// Display title in Arabic for accessibility and diagnostics.
  final String arabicTitle;

  const YasserStateMapping({
    required this.semanticState,
    required this.rivePasswordTyping,
    this.riveIsPeeking = false,
    this.riveIsListening = false,
    this.riveIsThinking = false,
    this.riveIsSpeaking = false,
    this.riveIsFollowingInput = false,
    this.riveOnboardingScene = 0,
    this.riveViewModelTrigger,
    this.riveAnimationTrigger,
    this.defaultMouthShape = 0,
    required this.gazeTarget,
    required this.fallbackAssetPath,
    required this.arabicTitle,
  });
}

/// Translates Flutter semantic character intents into Rive runtime values
/// and high-fidelity fallback illustrations.
abstract final class YasserAnimationMapper {
  static const String standingPose =
      'assets/images/yasser/original/yasser_standing.png';
  static const String wavingPose =
      'assets/images/yasser/poses/yasser_waving.png';
  static const String thinkingPose =
      'assets/images/yasser/poses/yasser_thinking.png';
  static const String celebratingPose =
      'assets/images/yasser/poses/yasser_celebrating.png';
  static const String presentingPose =
      'assets/images/yasser/poses/yasser_presenting.png';

  static YasserStateMapping map(
    YasserAnimationState state, {
    Offset? customGaze,
  }) {
    switch (state) {
      case YasserAnimationState.idle:
      case YasserAnimationState.breathing:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.idle,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'resetToIdle',
          gazeTarget: Offset.zero,
          fallbackAssetPath: standingPose,
          arabicTitle: 'وضع السكون الطبيعي',
        );

      case YasserAnimationState.blinking:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.blinking,
          rivePasswordTyping: false,
          gazeTarget: Offset.zero,
          fallbackAssetPath: standingPose,
          arabicTitle: 'طرفة عين عفوية',
        );

      case YasserAnimationState.waving:
      case YasserAnimationState.greeting:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.waving,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'wave',
          riveAnimationTrigger: 'P1_Wave_Validation',
          gazeTarget: Offset(0.0, -0.1),
          fallbackAssetPath: wavingPose,
          arabicTitle: 'تحية ولوحة ترحيب',
        );

      case YasserAnimationState.happy:
      case YasserAnimationState.excited:
      case YasserAnimationState.encouraging:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.happy,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'encourage',
          gazeTarget: Offset(0.0, -0.2),
          fallbackAssetPath: celebratingPose,
          arabicTitle: 'ابتسامة وتشجيع',
        );

      case YasserAnimationState.curious:
      case YasserAnimationState.thinking:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.thinking,
          rivePasswordTyping: false,
          riveIsThinking: true,
          riveAnimationTrigger: 'P1_Face_Validation',
          gazeTarget: Offset(0.3, -0.4),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'تفكير وفضول ذكي',
        );

      case YasserAnimationState.confused:
      case YasserAnimationState.sad:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.confused,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'retry',
          defaultMouthShape: 8,
          gazeTarget: Offset(-0.2, 0.2),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'حيرة وتشجيع لطيف',
        );

      case YasserAnimationState.gentleRetry:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.gentleRetry,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'retry',
          defaultMouthShape: 8,
          gazeTarget: Offset(-0.15, 0.15),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'توجيه لطيف وتشجيع',
        );

      case YasserAnimationState.celebrating:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.celebrating,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'celebrate',
          riveAnimationTrigger: 'jump',
          gazeTarget: Offset(0.0, -0.3),
          fallbackAssetPath: celebratingPose,
          arabicTitle: 'احتفال بالنجاح',
        );

      case YasserAnimationState.sessionComplete:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.sessionComplete,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'sessionComplete',
          gazeTarget: Offset(0.0, -0.25),
          fallbackAssetPath: celebratingPose,
          arabicTitle: 'إتمام الجلسة بنجاح',
        );

      case YasserAnimationState.waiting:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.waiting,
          rivePasswordTyping: false,
          gazeTarget: Offset(0.0, 0.25),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'في الانتظار',
        );

      case YasserAnimationState.listening:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.listening,
          rivePasswordTyping: false,
          riveIsListening: true,
          gazeTarget: Offset(0.0, 0.15),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'يستمع',
        );

      case YasserAnimationState.talking:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.talking,
          rivePasswordTyping: false,
          riveIsSpeaking: true,
          gazeTarget: Offset(0.0, 0.1),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'يتحدث',
        );

      case YasserAnimationState.pointing:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.pointing,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'encourage',
          gazeTarget: Offset(0.2, 0.1),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'استماع وتفاعل يقظ',
        );

      case YasserAnimationState.onboardingWelcome:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.onboardingWelcome,
          rivePasswordTyping: false,
          riveOnboardingScene: 1,
          gazeTarget: Offset(0.0, -0.05),
          fallbackAssetPath: wavingPose,
          arabicTitle: 'ترحيب البداية',
        );

      case YasserAnimationState.onboardingDiscovery:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.onboardingDiscovery,
          rivePasswordTyping: false,
          riveOnboardingScene: 2,
          gazeTarget: Offset(0.15, -0.1),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'استكشاف الأصوات',
        );

      case YasserAnimationState.onboardingReady:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.onboardingReady,
          rivePasswordTyping: false,
          riveOnboardingScene: 3,
          gazeTarget: Offset(0.0, -0.15),
          fallbackAssetPath: celebratingPose,
          arabicTitle: 'جاهز للانطلاق',
        );

      case YasserAnimationState.lookingLeft:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingLeft,
          rivePasswordTyping: false,
          riveIsFollowingInput: true,
          gazeTarget: Offset(-0.8, 0.0),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'نظر إلى اليسار',
        );

      case YasserAnimationState.lookingRight:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingRight,
          rivePasswordTyping: false,
          riveIsFollowingInput: true,
          gazeTarget: Offset(0.8, 0.0),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'نظر إلى اليمين',
        );

      case YasserAnimationState.lookingUp:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingUp,
          rivePasswordTyping: false,
          riveIsFollowingInput: true,
          gazeTarget: Offset(0.0, -0.8),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'نظر إلى الأعلى',
        );

      case YasserAnimationState.lookingDown:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingDown,
          rivePasswordTyping: false,
          riveIsFollowingInput: true,
          gazeTarget: Offset(0.0, 0.8),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'نظر إلى الحقل',
        );

      case YasserAnimationState.followingInput:
        return YasserStateMapping(
          semanticState: YasserAnimationState.followingInput,
          rivePasswordTyping: false,
          riveIsFollowingInput: true,
          gazeTarget: customGaze ?? const Offset(0.0, 0.4),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'متابعة الكتابة',
        );

      case YasserAnimationState.coveringEyes:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.coveringEyes,
          rivePasswordTyping: true,
          gazeTarget: Offset.zero,
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'تغطية العينين لحفظ السرية',
        );

      case YasserAnimationState.peeking:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.peeking,
          rivePasswordTyping: true,
          riveIsPeeking: true,
          gazeTarget: Offset(0.1, 0.1),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'استراق النظر بلطف',
        );

      case YasserAnimationState.returningToIdle:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.returningToIdle,
          rivePasswordTyping: false,
          riveViewModelTrigger: 'resetToIdle',
          gazeTarget: Offset.zero,
          fallbackAssetPath: standingPose,
          arabicTitle: 'العودة للوضع الطبيعي',
        );
    }
  }
}
