/// Classification of character features based on `assets/rive/yasser.riv`.
enum RiveSupportTier {
  /// Verified and controllable through runtime `ViewModel1` bindings in the exported asset.
  verified,

  /// Present in rig / layers / timelines, accessible with testing.
  availableRequiresTesting,

  /// Partially present via bone or timeline, but lacks dedicated state machine input.
  partiallySupported,

  /// Planned for Phase 2, requires additional Rive authoring.
  requiresPhase2Authoring,

  /// Completely unsupported by current asset.
  unsupported,
}

/// Description of a specific character animation capability.
class CharacterCapability {
  final String featureName;
  final String? riveIdentifier;
  final RiveSupportTier tier;
  final String description;
  final String? fallbackPoseAsset;
  final String phase2Requirement;

  const CharacterCapability({
    required this.featureName,
    this.riveIdentifier,
    required this.tier,
    required this.description,
    this.fallbackPoseAsset,
    required this.phase2Requirement,
  });
}

/// Comprehensive Capability Matrix discovered from the production `assets/rive/yasser.riv`.
abstract final class YasserAnimationCapabilities {
  static const String assetPath = 'assets/rive/yasser.riv';
  static const int assetByteSize = 1044056;
  static const String artboardName = 'Yasser_Phase1_Work';
  static const String stateMachineName = 'State Machine 1';

  static const List<CharacterCapability> matrix = [
    CharacterCapability(
      featureName: 'Password Privacy (Cover Eyes)',
      riveIdentifier: 'passwordTyping',
      tier: RiveSupportTier.verified,
      description:
          'Privacy preemption boolean raising clean palms/cuffs over both eyes with downward elbows.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Verified & authored in production State Machine 1.',
    ),
    CharacterCapability(
      featureName: 'Password Peeking',
      riveIdentifier: 'isPeeking',
      tier: RiveSupportTier.verified,
      description:
          'Articulated 4-finger right hand spreads smoothly with playful single-eye peek.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Verified & authored in Layer 1 + Blink_Layer.',
    ),
    CharacterCapability(
      featureName: 'Welcoming Wave',
      riveIdentifier: 'wave',
      tier: RiveSupportTier.verified,
      description:
          'Trigger-driven raised open-palm wave with natural elbow IK orientation and clean wrist swing.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_waving.png',
      phase2Requirement: 'Verified & authored in Anim_Wave.',
    ),
    CharacterCapability(
      featureName: 'Continuous Eye Gaze Tracking',
      riveIdentifier: 'lookX / lookY',
      tier: RiveSupportTier.verified,
      description:
          'Formula-bound normalized inputs (-1.0 to 1.0) driving EyeL/EyeR bones directly in Rive.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_presenting.png',
      phase2Requirement: 'Verified via ViewModel1 formula converters.',
    ),
    CharacterCapability(
      featureName: '9-Shape Native Lip-Sync Mouth Rig',
      riveIdentifier: 'mouthShape (0..8)',
      tier: RiveSupportTier.verified,
      description:
          'Vector Yasser_Mouth_Rig driven by dedicated Mouth_Articulation_Layer across Arabic/English visemes.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_presenting.png',
      phase2Requirement: 'Verified via Mouth_0..Mouth_8 state machine layer.',
    ),
    CharacterCapability(
      featureName: 'Celebration, Jump & Session Complete',
      riveIdentifier: 'celebrate / jump / sessionComplete',
      tier: RiveSupportTier.verified,
      description:
          'Symmetrical dual open-palm cheers with hip bounce and celebratory brow expression.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_celebrating.png',
      phase2Requirement: 'Verified & authored in State Machine 1.',
    ),
    CharacterCapability(
      featureName: 'Thinking, Listening & Speaking Loops',
      riveIdentifier: 'isThinking / isListening / isSpeaking',
      tier: RiveSupportTier.verified,
      description:
          'Sustained boolean-driven states with non-conflicting brow and articulation layers.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Verified in Layer 1 + Expression_Layer.',
    ),
    CharacterCapability(
      featureName: 'Supportive Encourage & Gentle Retry',
      riveIdentifier: 'encourage / retry',
      tier: RiveSupportTier.verified,
      description:
          'Supportive open-palm gesture and empathetic head tilt with calm brow & mouth expressions.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Verified in Anim_Encourage & Anim_GentleRetry.',
    ),
    CharacterCapability(
      featureName: 'Onboarding Story Chapters (1..3)',
      riveIdentifier: 'onboardingScene',
      tier: RiveSupportTier.verified,
      description:
          'Dedicated welcome, sound discovery, and hero-ready state loops indexed 1..3.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_waving.png',
      phase2Requirement: 'Verified in Onboarding_1..3 states.',
    ),
    CharacterCapability(
      featureName: 'Independent Ambient Breathing & Blinking',
      riveIdentifier: 'P2_Idle + Blink_Layer',
      tier: RiveSupportTier.verified,
      description:
          'Natural chest breathing paired with non-overlapping Blink_Layer double-blink loop.',
      fallbackPoseAsset: 'assets/images/yasser/original/yasser_standing.png',
      phase2Requirement: 'Verified across Layer 1 & Blink_Layer.',
    ),
  ];
}
