import 'package:rive/rive.dart' as rive;

import 'yasser_animation_config.dart';
import 'yasser_animation_mapper.dart';

/// Drives the Phase 1 rig and its authored wave on the same artboard.
final class YasserRiveController extends rive.RiveWidgetController {
  static const _waveTimeline = 'P1_Wave_Validation';

  late final rive.ViewModelInstance _viewModel;
  late final rive.ViewModelInstanceBoolean _passwordTyping;
  late final rive.Animation? _wave;
  bool _waving = false;

  YasserRiveController(super.file, YasserAnimationConfig config)
    : super(
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
    } catch (_) {
      super.dispose();
      viewModel?.dispose();
      rethrow;
    }
  }

  void applyMapping(YasserStateMapping mapping) {
    setPasswordTyping(mapping.rivePasswordTyping);
    final wave = _wave;
    if (wave != null && mapping.riveAnimationTrigger == _waveTimeline) {
      wave.time = 0;
      _waving = true;
      scheduleRepaint();
    } else {
      _stopWave();
    }
  }

  void setPasswordTyping(bool value) {
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
    final machineChanged = super.advance(elapsedSeconds);
    if (!_waving) return machineChanged;

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
    _wave?.dispose();
    super.dispose();
    _viewModel.dispose();
  }
}
