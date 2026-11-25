import 'package:rive/rive.dart' as rive;

import 'yasser_animation_config.dart';
import 'yasser_animation_mapper.dart';
import 'yasser_animation_state.dart';
import 'yasser_arm_motion.dart';
import 'yasser_rig_motion.dart';
import 'yasser_viseme.dart';

/// Drives Yasser’s state machine and poses on the same artboard.
final class YasserRiveController extends rive.RiveWidgetController {
  late final rive.ViewModelInstance _viewModel;
  late final rive.ViewModelInstanceBoolean _passwordTyping;
  late final YasserArmMotion _arms;
  bool reducedMotion = false;
  YasserViseme? _viseme;

  set viseme(YasserViseme? value) {
    if (_viseme == value) return;
    _viseme = value;
    scheduleRepaint();
  }

  late final YasserRigMotion _motion;
  final double _breathingPeriod;
  YasserStateMapping _mapping = YasserAnimationMapper.map(
    YasserAnimationState.idle,
  );

  YasserRiveController(super.file, YasserAnimationConfig config)
    : _breathingPeriod =
          config.breathingDuration.inMicroseconds /
          Duration.microsecondsPerSecond,
      super(
        artboardSelector: rive.ArtboardNamed(config.artboardName),
        stateMachineSelector: rive.StateMachineNamed(config.stateMachineName),
      ) {
    rive.ViewModelInstance? viewModel;
    try {
      viewModel = dataBind(rive.DataBind.auto());
      _passwordTyping =
          viewModel.boolean(config.passwordInputName) ??
          (throw StateError(
            'Missing Rive property: ${config.passwordInputName}',
          ));
      _viewModel = viewModel;
      super.advance(0);
      _arms = YasserArmMotion(artboard);
      _motion = YasserRigMotion(artboard);
    } catch (_) {
      super.dispose();
      viewModel?.dispose();
      rethrow;
    }
  }

  void applyMapping(YasserStateMapping mapping) {
    _mapping = mapping;
    _arms.request(
      state: mapping.semanticState,
      cover: mapping.rivePasswordTyping,
      peek: mapping.semanticState == YasserAnimationState.peeking,
    );
    scheduleRepaint();
  }

  void setPasswordTyping(bool value) => applyMapping(
    YasserAnimationMapper.map(
      value ? YasserAnimationState.coveringEyes : YasserAnimationState.idle,
    ),
  );

  @override
  bool advance(double elapsedSeconds) {
    _arms.restore();
    _motion.restore();
    final armsMoving = _arms.advance(
      elapsedSeconds,
      reducedMotion: reducedMotion,
    );
    if (_passwordTyping.value != _arms.eyesCovered) {
      _passwordTyping.value = _arms.eyesCovered;
    }
    final machineChanged = super.advance(elapsedSeconds);
    final moving = _motion.apply(
      _mapping,
      elapsedSeconds,
      reducedMotion: reducedMotion,
      breathingPeriod: _breathingPeriod,
      armsCovering: _arms.eyesCovered,
      celebration: _arms.celebration,
      viseme: _viseme,
    );
    if (_arms.hasArmPose) _arms.apply();
    // Flush bone edits without applying the state machine again.
    // ignore: invalid_use_of_internal_member
    artboard.updatePass();
    return active && (machineChanged || moving || armsMoving);
  }

  @override
  void dispose() {
    _motion.dispose();
    _arms.dispose();
    super.dispose();
    _viewModel.dispose();
  }
}
