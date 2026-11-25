import 'package:rive/rive.dart' as rive;

import 'yasser_animation_config.dart';
import 'yasser_animation_mapper.dart';
import 'yasser_animation_state.dart';
import 'yasser_rig_motion.dart';
import 'yasser_viseme.dart';

/// Drives the Phase 1 rig and its authored wave on the same artboard.
final class YasserRiveController extends rive.RiveWidgetController {
  static const _waveTimeline = 'P1_Wave_Validation';

  late final rive.ViewModelInstance _viewModel;
  late final rive.ViewModelInstanceBoolean _passwordTyping;
  late final rive.Animation? _wave;
  bool _waving = false;
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
      _wave = artboard.animationNamed(_waveTimeline);
      _motion = YasserRigMotion(artboard);
    } catch (_) {
      super.dispose();
      viewModel?.dispose();
      rethrow;
    }
  }

  void applyMapping(YasserStateMapping mapping) {
    _mapping = mapping;
    _setPasswordTyping(mapping.rivePasswordTyping);
    scheduleRepaint();
    final wave = _wave;
    if (wave != null &&
        !reducedMotion &&
        mapping.riveAnimationTrigger == _waveTimeline) {
      wave.time = 0;
      _waving = true;
      scheduleRepaint();
    } else {
      _stopWave();
    }
  }

  void setPasswordTyping(bool value) => applyMapping(
    YasserAnimationMapper.map(
      value ? YasserAnimationState.coveringEyes : YasserAnimationState.idle,
    ),
  );

  void _setPasswordTyping(bool value) {
    if (_passwordTyping.value == value) return;
    if (value) _stopWave();
    _passwordTyping.value = value;
    scheduleRepaint();
  }

  void _stopWave() {
    if (!_waving) return;
    _waving = false;
    _wave!
      ..time = 0
      ..advanceAndApply(0);
    scheduleRepaint();
  }

  @override
  bool advance(double elapsedSeconds) {
    _motion.restore();
    final machineChanged = super.advance(elapsedSeconds);
    if (!_waving) {
      final moving = _motion.apply(
        _mapping,
        elapsedSeconds,
        reducedMotion: reducedMotion,
        breathingPeriod: _breathingPeriod,
        viseme: _viseme,
      );
      // Flush bone edits without applying the state machine again.
      // ignore: invalid_use_of_internal_member
      artboard.updatePass();
      return active && (machineChanged || moving);
    }

    final wave = _wave!;
    if (wave.time + elapsedSeconds >= wave.duration) {
      _stopWave();
      return true;
    }
    wave.advanceAndApply(elapsedSeconds);
    return active;
  }

  @override
  void dispose() {
    _motion.dispose();
    _wave?.dispose();
    super.dispose();
    _viewModel.dispose();
  }
}
