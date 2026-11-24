/// Semantic animation states for the Yasser character.
///
/// These are application-level semantic intents rather than literal Rive
/// timeline or input names. The [YasserAnimationMapper] translates these
/// semantic intents to the actual verified Rive state machine inputs or
/// fallback presentation poses.
enum YasserAnimationState {
  // Ambient & Resting
  idle,
  breathing,
  blinking,

  // Social & Onboarding
  waving,
  greeting,
  happy,
  excited,

  // Cognitive & Educational
  curious,
  thinking,
  confused,
  sad,
  encouraging,
  celebrating,

  // Interactive Sessions (AI & Listening)
  waiting,
  listening,
  talking,

  // Gaze & Attention
  lookingLeft,
  lookingRight,
  lookingUp,
  lookingDown,
  followingInput,

  // Privacy & Authentication Reactions
  coveringEyes,
  peeking,
  pointing,
  returningToIdle,
}

/// Priority tier determining whether an incoming state can preempt
/// or interrupt the currently playing state.
enum YasserAnimationPriority {
  /// Ambient motions (idle, subtle breathing, background blinking).
  ambient(10),

  /// Field focus attention and gaze tracking.
  attentive(30),

  /// Gestures and emotional reactions (wave, thinking, tap reaction).
  gesture(50),

  /// Transient feedback (validation error, confusion, celebration).
  transient(75),

  /// Mandatory privacy states (password covering eyes, peeking).
  critical(100);

  final int level;
  const YasserAnimationPriority(this.level);

  bool canOverride(YasserAnimationPriority other) => level >= other.level;
}
