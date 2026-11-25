import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'yasser_animation_config.dart';
import 'yasser_animation_mapper.dart';
import 'yasser_animation_state.dart';
import 'yasser_interaction_engine.dart';
import 'yasser_rive_controller.dart';

/// Central controller for the Yasser character.
///
/// Orchestrates the modern Rive 0.14.x state machine when available,
/// or seamlessly drives the fallback high-resolution 2.5D presentation.
class YasserController extends ChangeNotifier {
  final YasserInteractionEngine engine;
  final YasserAnimationConfig config;

  YasserRiveController? _widgetController;

  YasserController({
    YasserInteractionEngine? engine,
    this.config = const YasserAnimationConfig(),
  }) : engine = engine ?? YasserInteractionEngine(config: config) {
    this.engine.stateNotifier.addListener(_onEngineStateChanged);
  }

  bool get isRiveInitialized => _widgetController != null;
  rive.RiveWidgetController? get widgetController => _widgetController;
  rive.StateMachine? get stateMachine => _widgetController?.stateMachine;
  YasserAnimationState get currentState => engine.currentState;
  YasserStateMapping get currentMapping => engine.currentMapping;
  ValueNotifier<YasserStateMapping> get stateNotifier => engine.stateNotifier;
  List<CharacterEventLog> get eventHistory => engine.eventHistory;

  /// The widget owns the live Rive controller.
  void attachWidgetController(YasserRiveController controller) {
    _widgetController = controller;
    controller.applyMapping(engine.currentMapping);
    notifyListeners();
  }

  void detachWidgetController() {
    _widgetController = null;
  }

  void _onEngineStateChanged() {
    _widgetController?.applyMapping(engine.currentMapping);
    notifyListeners();
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

  /// Converts only the caret offset to a gaze coordinate for non-password fields.
  void followCaret(
    int offset, {
    required int textLength,
    required bool rightToLeft,
  }) {
    final span = textLength < 12 ? 12 : textLength;
    final progress = (offset / span).clamp(0.0, 1.0);
    final x = (2 * progress - 1) * (rightToLeft ? -1 : 1);
    lookAtInput(normalizedX: x, normalizedY: .35);
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
    detachWidgetController();
    engine.dispose();
    super.dispose();
  }
}
