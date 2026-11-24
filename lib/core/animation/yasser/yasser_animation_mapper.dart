import 'dart:ui';
import 'yasser_animation_state.dart';

/// Mapping contract result specifying both Rive input instructions
/// and high-resolution 2.5D fallback assets.
class YasserStateMapping {
  final YasserAnimationState semanticState;

  /// Whether the primary Rive passwordTyping input should be true.
  final bool rivePasswordTyping;

  /// Optional name of an authored animation timeline to trigger.
  final String? riveAnimationTrigger;

  /// Normalized eye gaze target (horizontal: -1.0 to 1.0, vertical: -1.0 to 1.0).
  final Offset gazeTarget;

  /// High-resolution 2.5D PNG fallback pose.
  final String fallbackAssetPath;

  /// Display title in Arabic for accessibility and diagnostics.
  final String arabicTitle;

  const YasserStateMapping({
    required this.semanticState,
    required this.rivePasswordTyping,
    this.riveAnimationTrigger,
    required this.gazeTarget,
    required this.fallbackAssetPath,
    required this.arabicTitle,
  });
}

/// Translates Flutter semantic character intents into Rive runtime values
/// and high-fidelity fallback illustrations.
abstract final class YasserAnimationMapper {
  static const String standingPose = 'assets/images/yasser/original/yasser_standing.png';
  static const String wavingPose = 'assets/images/yasser/poses/yasser_waving.png';
  static const String thinkingPose = 'assets/images/yasser/poses/yasser_thinking.png';
  static const String celebratingPose = 'assets/images/yasser/poses/yasser_celebrating.png';
  static const String presentingPose = 'assets/images/yasser/poses/yasser_presenting.png';

  static YasserStateMapping map(YasserAnimationState state, {Offset? customGaze}) {
    switch (state) {
      case YasserAnimationState.idle:
      case YasserAnimationState.breathing:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.idle,
          rivePasswordTyping: false,
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
          gazeTarget: Offset(0.0, -0.2),
          fallbackAssetPath: celebratingPose,
          arabicTitle: 'ابتسامة وتشجيع',
        );

      case YasserAnimationState.curious:
      case YasserAnimationState.thinking:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.thinking,
          rivePasswordTyping: false,
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
          gazeTarget: Offset(-0.2, 0.2),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'حيرة وتشجيع لطيف',
        );

      case YasserAnimationState.celebrating:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.celebrating,
          rivePasswordTyping: false,
          riveAnimationTrigger: 'jump',
          gazeTarget: Offset(0.0, -0.3),
          fallbackAssetPath: celebratingPose,
          arabicTitle: 'احتفال بالنجاح',
        );

      case YasserAnimationState.waiting:
      case YasserAnimationState.listening:
      case YasserAnimationState.talking:
      case YasserAnimationState.pointing:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.pointing,
          rivePasswordTyping: false,
          gazeTarget: Offset(0.2, 0.1),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'استماع وتفاعل يقظ',
        );

      case YasserAnimationState.lookingLeft:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingLeft,
          rivePasswordTyping: false,
          gazeTarget: Offset(-0.8, 0.0),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'نظر إلى اليمين/اليسار',
        );

      case YasserAnimationState.lookingRight:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingRight,
          rivePasswordTyping: false,
          gazeTarget: Offset(0.8, 0.0),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'نظر إلى اليمين',
        );

      case YasserAnimationState.lookingUp:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingUp,
          rivePasswordTyping: false,
          gazeTarget: Offset(0.0, -0.8),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'نظر إلى الأعلى',
        );

      case YasserAnimationState.lookingDown:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.lookingDown,
          rivePasswordTyping: false,
          gazeTarget: Offset(0.0, 0.8),
          fallbackAssetPath: presentingPose,
          arabicTitle: 'نظر إلى الحقل',
        );

      case YasserAnimationState.followingInput:
        return YasserStateMapping(
          semanticState: YasserAnimationState.followingInput,
          rivePasswordTyping: false,
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
          gazeTarget: Offset(0.1, 0.1),
          fallbackAssetPath: thinkingPose,
          arabicTitle: 'استراق النظر بلطف',
        );

      case YasserAnimationState.returningToIdle:
        return const YasserStateMapping(
          semanticState: YasserAnimationState.returningToIdle,
          rivePasswordTyping: false,
          gazeTarget: Offset.zero,
          fallbackAssetPath: standingPose,
          arabicTitle: 'العودة للوضع الطبيعي',
        );
    }
  }
}
