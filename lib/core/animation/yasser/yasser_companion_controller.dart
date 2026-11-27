import 'package:flutter/foundation.dart';

import '../../audio/yasser_audio_coordinator.dart';
import 'yasser_animation_state.dart';
import 'yasser_controller.dart';
import 'yasser_viseme.dart';

/// Shared single-owner character continuity coordinator connecting application
/// state (world location, audio playback, microphone recording, and feedback)
/// to a unified [YasserController] so screens do not fight for animation control.
class YasserCompanionController extends ChangeNotifier {
  final YasserController characterController;
  final YasserAudioCoordinator? _audioCoordinator;

  String _currentLocationId = 'yasser_home';
  String _currentLineArabic =
      'أهلاً يا بطل! أنا ياسر صاحبك، يلا نبدأ مغامرتنا!';
  YasserAnimationState _contextualState = YasserAnimationState.greeting;

  YasserCompanionController({
    YasserController? characterController,
    YasserAudioCoordinator? audioCoordinator,
  }) : characterController = characterController ?? YasserController(),
       _audioCoordinator = audioCoordinator {
    _audioCoordinator?.addListener(_syncFromAudio);
  }

  String get currentLocationId => _currentLocationId;
  String get currentLineArabic => _currentLineArabic;
  YasserAnimationState get currentState => _contextualState;
  ValueListenable<YasserViseme>? get visemeListenable =>
      _audioCoordinator?.visemeNotifier;

  void _syncFromAudio() {
    final coord = _audioCoordinator;
    if (coord == null) return;
    if (coord.isRecordingActive) {
      if (characterController.currentState != YasserAnimationState.listening) {
        _contextualState = YasserAnimationState.listening;
        characterController.engine.triggerState(
          YasserAnimationState.listening,
          reason: 'Companion listening silently while child speaks',
        );
        notifyListeners();
      }
      return;
    }
    if (coord.isPlayingVoice &&
        characterController.currentState != YasserAnimationState.talking) {
      _contextualState = YasserAnimationState.talking;
      characterController.engine.triggerState(
        YasserAnimationState.talking,
        reason: 'Companion speaking prompt audio',
      );
      notifyListeners();
    }
  }

  /// Updates Yasser's contextual presence as the child moves across scenes,
  /// activities, rewards, or home interactions.
  void setContext({
    String? locationId,
    required YasserAnimationState state,
    required String messageArabic,
    Duration? duration,
  }) {
    if (locationId != null) {
      _currentLocationId = locationId;
    }
    _contextualState = state;
    _currentLineArabic = messageArabic;
    characterController.engine.triggerState(
      state,
      customHoldDuration: duration,
      reason: 'World context transition -> ${locationId ?? _currentLocationId}',
    );
    notifyListeners();
  }

  /// Speaks a line using prerecorded/bundled audio when available or gentle
  /// fallback feedback with honest approximate Arabic visemes, strictly
  /// respecting muted mode and active mic recording exclusion.
  Future<void> speakLine({
    required String scriptId,
    required String arabicText,
    String? bundledAssetPath,
    YasserAnimationState speakingState = YasserAnimationState.talking,
  }) async {
    _currentLineArabic = arabicText;
    final coord = _audioCoordinator;
    if (coord != null && coord.isRecordingActive) {
      return;
    }
    _contextualState = speakingState;
    characterController.engine.triggerState(
      speakingState,
      customHoldDuration: const Duration(milliseconds: 1600),
      reason: 'Speaking line $scriptId',
    );
    notifyListeners();
    await coord?.playLineOrFallback(
      scriptId: scriptId,
      arabicText: arabicText,
      assetPath: bundledAssetPath,
    );
  }

  void guideTowardLocation(String regionId, String regionTitleArabic) {
    setContext(
      locationId: regionId,
      state: YasserAnimationState.pointing,
      messageArabic: 'يلا نستكشف $regionTitleArabic سوا يا بطل!',
      duration: const Duration(milliseconds: 1800),
    );
  }

  void celebrateAchievement(String messageArabic) {
    setContext(
      state: YasserAnimationState.celebrating,
      messageArabic: messageArabic,
      duration: const Duration(milliseconds: 2400),
    );
  }

  void offerFarewell(String messageArabic) {
    setContext(
      state: YasserAnimationState.sessionComplete,
      messageArabic: messageArabic,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _audioCoordinator?.removeListener(_syncFromAudio);
    characterController.dispose();
    super.dispose();
  }
}
