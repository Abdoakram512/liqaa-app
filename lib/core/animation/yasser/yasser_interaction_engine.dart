import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'yasser_animation_config.dart';
import 'yasser_animation_mapper.dart';
import 'yasser_animation_state.dart';

/// Interaction history entry for debugging and lab inspection.
class CharacterEventLog {
  final DateTime timestamp;
  final YasserAnimationState state;
  final YasserAnimationPriority priority;
  final String description;

  const CharacterEventLog({
    required this.timestamp,
    required this.state,
    required this.priority,
    required this.description,
  });
}

/// Centralized arbitration engine that manages Yasser's character reactions,
/// ambient life cycle, state priorities, and conflict prevention.
class YasserInteractionEngine {
  /// Global toggle to enable or disable background blink timer in testing.
  static bool enableBlinkTimer = true;

  final YasserAnimationConfig config;
  final Random _random = Random();

  YasserAnimationState _currentState = YasserAnimationState.idle;
  YasserAnimationPriority _currentPriority = YasserAnimationPriority.ambient;

  Timer? _transientTimer;
  Timer? _blinkTimer;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  final ValueNotifier<YasserStateMapping> stateNotifier;
  final List<CharacterEventLog> eventHistory = [];

  YasserInteractionEngine({this.config = const YasserAnimationConfig()})
      : stateNotifier = ValueNotifier<YasserStateMapping>(
          YasserAnimationMapper.map(YasserAnimationState.idle),
        ) {
    _scheduleNextBlink();
  }

  YasserAnimationState get currentState => _currentState;
  YasserAnimationPriority get currentPriority => _currentPriority;
  YasserStateMapping get currentMapping => stateNotifier.value;

  /// Trigger a new semantic state with priority arbitration.
  ///
  /// Returns `true` if the state was accepted, or `false` if rejected
  /// due to an active higher-priority state or active cooldown.
  bool triggerState(
    YasserAnimationState requestedState, {
    Duration? customHoldDuration,
    Offset? gazeTarget,
    String? reason,
  }) {
    final requestedPriority = YasserAnimationConfig.getPriority(requestedState);

    // Prevent lower-priority states from interrupting critical or transient states
    if (!requestedPriority.canOverride(_currentPriority)) {
      _logEvent(
        requestedState,
        requestedPriority,
        'Rejected: Lower priority than active ${_currentState.name} (${_currentPriority.name})',
      );
      return false;
    }

    _cancelTransientTimer();

    _currentState = requestedState;
    _currentPriority = requestedPriority;

    final newMapping = YasserAnimationMapper.map(
      requestedState,
      customGaze: gazeTarget,
    );
    stateNotifier.value = newMapping;

    _logEvent(
      requestedState,
      requestedPriority,
      reason ?? 'Accepted and active: ${newMapping.arabicTitle}',
    );

    // If this is a transient state (e.g. waving, celebration, confusion), schedule return to idle
    if ((requestedPriority == YasserAnimationPriority.transient ||
        requestedPriority == YasserAnimationPriority.gesture) &&
        requestedState != YasserAnimationState.listening &&
        requestedState != YasserAnimationState.talking) {
      final hold = customHoldDuration ?? config.transientHoldDuration;
      _transientTimer = Timer(hold, () {
        returnToIdle();
      });
    }

    return true;
  }

  /// Interactive character tap response.
  bool handleTap() {
    final now = DateTime.now();
    if (now.difference(_lastTapTime) < config.tapCooldown) {
      return false;
    }
    _lastTapTime = now;

    return triggerState(
      YasserAnimationState.waving,
      customHoldDuration: const Duration(milliseconds: 2000),
      reason: 'User tapped Yasser',
    );
  }

  /// Smoothly transition Yasser back to ambient resting idle.
  void returnToIdle() {
    _cancelTransientTimer();
    _currentState = YasserAnimationState.idle;
    _currentPriority = YasserAnimationPriority.ambient;
    stateNotifier.value = YasserAnimationMapper.map(YasserAnimationState.idle);

    _logEvent(
      YasserAnimationState.idle,
      YasserAnimationPriority.ambient,
      'Returned to natural idle state',
    );
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    if (!enableBlinkTimer) return;
    if (_currentPriority == YasserAnimationPriority.critical) {
      return; // Do not blink while covering eyes
    }

    final minSec = config.minBlinkInterval.inSeconds;
    final maxSec = config.maxBlinkInterval.inSeconds;
    final delay = Duration(
      seconds: minSec + _random.nextInt(max(1, maxSec - minSec + 1)),
    );

    _blinkTimer = Timer(delay, () {
      if (_currentState == YasserAnimationState.idle) {
        stateNotifier.value = YasserAnimationMapper.map(YasserAnimationState.blinking);
        _blinkTimer = Timer(const Duration(milliseconds: 180), () {
          if (_currentState == YasserAnimationState.idle) {
            stateNotifier.value = YasserAnimationMapper.map(YasserAnimationState.idle);
          }
          _scheduleNextBlink();
        });
      } else {
        _scheduleNextBlink();
      }
    });
  }

  void _cancelTransientTimer() {
    _transientTimer?.cancel();
    _transientTimer = null;
  }

  void _logEvent(
    YasserAnimationState state,
    YasserAnimationPriority priority,
    String desc,
  ) {
    if (eventHistory.length > 50) {
      eventHistory.removeAt(0);
    }
    eventHistory.add(
      CharacterEventLog(
        timestamp: DateTime.now(),
        state: state,
        priority: priority,
        description: desc,
      ),
    );
  }

  void dispose() {
    _cancelTransientTimer();
    _blinkTimer?.cancel();
    stateNotifier.dispose();
  }
}
