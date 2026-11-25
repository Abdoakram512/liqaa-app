/// Classification of character features based on the Phase 1 audit of `assets/rive/yasser.riv`.
enum RiveSupportTier {
  /// Verified and controllable through runtime input in the exported asset.
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

/// Comprehensive Capability Matrix discovered from `assets/rive/yasser.riv`.
abstract final class YasserAnimationCapabilities {
  static const String assetPath = 'assets/rive/yasser.riv';
  static const int assetByteSize = 1616813;
  static const String artboardName = 'Yasser_Phase1_Work';
  static const String stateMachineName = 'State Machine 1';

  static const List<CharacterCapability> matrix = [
    CharacterCapability(
      featureName: 'Password Privacy (Cover Eyes)',
      riveIdentifier: 'passwordTyping',
      tier: RiveSupportTier.verified,
      description: 'Boolean input raising privacy arms over eyes during password entry.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Verified in Phase 1 rig. Needs smooth easing curve and finger separation.',
    ),
    CharacterCapability(
      featureName: 'Password Peeking',
      riveIdentifier: 'Yasser_Privacy_Arm / Yasser_TwoHand_Cover',
      tier: RiveSupportTier.partiallySupported,
      description: 'Arm/hand cover layers exist in binary; state machine currently maps to boolean passwordTyping.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Add dedicated `isPasswordVisible` or `isPeeking` boolean input in State Machine 1.',
    ),
    CharacterCapability(
      featureName: 'Welcoming Wave',
      riveIdentifier: 'P1_Wave_Validation / wave / Arm_Wave',
      tier: RiveSupportTier.availableRequiresTesting,
      description: 'Authored wave animations and IK validation timelines found in rig.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_waving.png',
      phase2Requirement: 'Expose a dedicated `isWaving` boolean or `waveTrigger` in State Machine 1.',
    ),
    CharacterCapability(
      featureName: 'Name / Field Focus Gaze',
      riveIdentifier: 'nameEntry',
      tier: RiveSupportTier.partiallySupported,
      description: 'State nameEntry is present in the binary; maps attention to user identity field.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_presenting.png',
      phase2Requirement: 'Add continuous `lookX` and `lookY` number inputs (-1.0 to 1.0) bound to eye bones.',
    ),
    CharacterCapability(
      featureName: 'Continuous Eye Tracking',
      riveIdentifier: 'P1_Neck_Head_Face_EyeL / EyeR',
      tier: RiveSupportTier.requiresPhase2Authoring,
      description: 'Rig bones and eye groups exist, but continuous runtime number inputs are not bound to State Machine 1.',
      fallbackPoseAsset: null,
      phase2Requirement: 'Expose normalized `lookX` and `lookY` inputs for continuous caret tracking.',
    ),
    CharacterCapability(
      featureName: 'Celebration / Victory Pose',
      riveIdentifier: 'jump / celebration',
      tier: RiveSupportTier.partiallySupported,
      description: 'Rig supports jumping and arm elevation.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_celebrating.png',
      phase2Requirement: 'Add `loginSuccess` or `celebrateTrigger` in State Machine 1 with confetti/cheering action.',
    ),
    CharacterCapability(
      featureName: 'Thinking / Puzzle Solving',
      riveIdentifier: 'P1_Face_Validation',
      tier: RiveSupportTier.partiallySupported,
      description: 'Face validation and eyebrow bones support thoughtful expression.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Add `isThinking` boolean state machine input.',
    ),
    CharacterCapability(
      featureName: 'Gentle Confusion / Error Feedback',
      riveIdentifier: 'P1_Neck_Head / BrowL / BrowR',
      tier: RiveSupportTier.requiresPhase2Authoring,
      description: 'Eyebrow and neck joints can tilt, but needs authored timeline in state machine.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_thinking.png',
      phase2Requirement: 'Add `validationError` trigger providing an encouraging, supportive head tilt.',
    ),
    CharacterCapability(
      featureName: 'Speech Listening & Talking',
      riveIdentifier: 'P1_Neck_Head_Face_Mouth',
      tier: RiveSupportTier.requiresPhase2Authoring,
      description: 'Mouth geometry and neck joints are rigged; timeline for active listening loop pending Phase 2.',
      fallbackPoseAsset: 'assets/images/yasser/poses/yasser_presenting.png',
      phase2Requirement: 'Add `isListening` and `isTalking` states for speech development sessions.',
    ),
    CharacterCapability(
      featureName: 'Ambient Breathing & Blinking',
      riveIdentifier: 'P1_RigRoot / EyeL / EyeR',
      tier: RiveSupportTier.availableRequiresTesting,
      description: 'Rig root and eye geometries allow continuous subtle breathing and randomized blinking.',
      fallbackPoseAsset: 'assets/images/yasser/original/yasser_standing.png',
      phase2Requirement: 'Ensure idle state machine layer runs ambient blinking without overriding active gestures.',
    ),
  ];
}
