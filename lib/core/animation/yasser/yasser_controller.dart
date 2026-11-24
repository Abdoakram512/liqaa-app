import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import 'yasser_animation_config.dart';
import 'yasser_animation_mapper.dart';
import 'yasser_animation_state.dart';
import 'yasser_interaction_engine.dart';

/// Central controller for the Yasser character.
///
/// Orchestrates the Rive state machine when available, or drives
/// the fallback high-resolution 2.5D presentation seamlessly.
class YasserController extends ChangeNotifier {
  final YasserInteractionEngine engine;
  final YasserAnimationConfig config;

  // Rive runtime bindings
  Artboard? _artboard;
  StateMachineController? _stateMachineController;
  SMIBool? _passwordTypingInput;
  bool _isRiveInitialized = false;

  YasserController({
    YasserInteractionEngine? engine,
    this.config = const YasserAnimationConfig(),
  }) : engine = engine ?? YasserInteractionEngine(config: config) {
    this.engine.stateNotifier.addListener(_onEngineStateChanged);
  }

  bool get isRiveInitialized => _isRiveInitialized;
  Artboard? get artboard => _artboard;
  StateMachineController? get stateMachineController => _stateMachineController;
  YasserAnimationState get currentState => engine.currentState;
  YasserStateMapping get currentMapping => engine.currentMapping;
  ValueNotifier<YasserStateMapping> get stateNotifier => engine.stateNotifier;
  List<CharacterEventLog> get eventHistory => engine.eventHistory;

  /// Attach the Rive artboard and locate state machine inputs.
  void attachArtboard(Artboard artboard) {
    try {
      _artboard = artboard;
      _stateMachineController = StateMachineController.fromArtboard(
        artboard,
        config.stateMachineName,
      );

      if (_stateMachineController != null) {
        artboard.addController(_stateMachineController!);
        _passwordTypingInput = _stateMachineController!.findInput<bool>(
          config.passwordInputName,
        ) as SMIBool?;

        _isRiveInitialized = true;
        _syncRiveInputs(engine.currentMapping);
        notifyListeners();
      }
    } catch (e) {
      // Graceful fallback: If Rive initialization fails, mark false and use 2.5D poses
      _isRiveInitialized = false;
      notifyListeners();
    }
  }

  void _onEngineStateChanged() {
    _syncRiveInputs(engine.currentMapping);
    notifyListeners();
  }

  void _syncRiveInputs(YasserStateMapping mapping) {
    if (_passwordTypingInput != null) {
      _passwordTypingInput!.value = mapping.rivePasswordTyping;
    }
  }

  // --- High-Level Semantic Actions ---

  /// Password field focused: cover eyes for privacy.
  void coverEyes() {
    engine.triggerState(
      YasserAnimationState.coveringEyes,
      reason: 'Password field focused: privacy cover eyes',
    );
  }

  /// Password show toggle enabled: playfully peek.
  void peek() {
    engine.triggerState(
      YasserAnimationState.peeking,
      reason: 'Password visibility toggled on: peek through fingers',
    );
  }

  /// Password field blurred: lower hands back to natural resting pose.
  void uncoverEyes() {
    engine.returnToIdle();
  }

  /// Welcoming wave gesture.
  void wave({Duration? duration}) {
    engine.triggerState(
      YasserAnimationState.waving,
      customHoldDuration: duration ?? const Duration(milliseconds: 2200),
      reason: 'Greeting wave gesture',
    );
  }

  /// Gaze follows input field or caret progression.
  void lookAtInput({double normalizedX = 0.0, double normalizedY = 0.4}) {
    engine.triggerState(
      YasserAnimationState.followingInput,
      gazeTarget: Offset(normalizedX, normalizedY),
      reason: 'Attentive focus following user input',
    );
  }

  /// Celebration reaction on successful login, registration, or completed quiz.
  void celebrate({Duration? duration}) {
    engine.triggerState(
      YasserAnimationState.celebrating,
      customHoldDuration: duration ?? const Duration(milliseconds: 2500),
      reason: 'Victory celebration reaction',
    );
  }

  /// Thoughtful puzzle-solving pose.
  void think({Duration? duration}) {
    engine.triggerState(
      YasserAnimationState.thinking,
      customHoldDuration: duration ?? const Duration(milliseconds: 2000),
      reason: 'Thoughtful reflection pose',
    );
  }

  /// Validation feedback reaction.
  void reactToValidation(bool isValid) {
    if (isValid) {
      engine.triggerState(
        YasserAnimationState.happy,
        customHoldDuration: const Duration(milliseconds: 1400),
        reason: 'Form input validated successfully',
      );
    } else {
      engine.triggerState(
        YasserAnimationState.confused,
        customHoldDuration: const Duration(milliseconds: 1800),
        reason: 'Validation hint: gentle supportive confusion',
      );
    }
  }

  /// Tap reaction when user taps directly on Yasser.
  void handleTap() {
    engine.handleTap();
  }

  /// Return to resting idle.
  void returnToIdle() {
    engine.returnToIdle();
  }

  @override
  void dispose() {
    engine.stateNotifier.removeListener(_onEngineStateChanged);
    _stateMachineController?.dispose();
    engine.dispose();
    super.dispose();
  }
}
