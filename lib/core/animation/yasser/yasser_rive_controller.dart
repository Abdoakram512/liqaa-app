import 'dart:math' as math;
import 'dart:ui';

import 'package:rive/rive.dart' as rive;

import 'yasser_animation_config.dart';
import 'yasser_animation_mapper.dart';
import 'yasser_animation_state.dart';
import 'yasser_viseme.dart';

/// Read-only snapshot of a bone or chain segment in Rive artboard coordinates (`486x695`).
class YasserRigBoneSegment {
  final String label;
  final Offset start;
  final Offset end;

  const YasserRigBoneSegment({
    required this.label,
    required this.start,
    required this.end,
  });
}

/// Read-only rig telemetry extracted from Rive `worldTransform` for Yasser Lab overlays.
class YasserRigDebugSnapshot {
  final double artboardWidth;
  final double artboardHeight;
  final List<YasserRigBoneSegment> bones;
  final Map<String, Offset> targets;
  final Map<String, Offset> facialAnchors;

  const YasserRigDebugSnapshot({
    required this.artboardWidth,
    required this.artboardHeight,
    required this.bones,
    required this.targets,
    required this.facialAnchors,
  });
}

/// Single-owner Rive controller driving Yasser's 4-layer `State Machine 1`
/// and `ViewModel1` bindings on `Yasser_Phase1_Work`.
final class YasserRiveController extends rive.RiveWidgetController {
  late final rive.ViewModelInstance _viewModel;
  late final rive.ViewModelInstanceBoolean _passwordTyping;
  late final rive.ViewModelInstanceBoolean? _isPeeking;
  late final rive.ViewModelInstanceBoolean? _isListening;
  late final rive.ViewModelInstanceBoolean? _isThinking;
  late final rive.ViewModelInstanceBoolean? _isSpeaking;
  late final rive.ViewModelInstanceBoolean? _isFollowingInput;
  late final rive.ViewModelInstanceNumber? _lookX;
  late final rive.ViewModelInstanceNumber? _lookY;
  late final rive.ViewModelInstanceNumber? _mouthShape;
  late final rive.ViewModelInstanceNumber? _onboardingScene;
  late final Map<String, rive.ViewModelInstanceTrigger?> _triggers;

  final Map<String, rive.Component?> _cachedComponents = {};

  bool reducedMotion = false;
  double playbackSpeed = 1.0;
  bool _isPaused = false;
  int _pendingStepFrames = 0;

  YasserViseme? _viseme;
  int? _directMouthShapeOverride;
  double _currentGazeX = 0.0;
  double _currentGazeY = 0.0;

  YasserStateMapping _mapping = YasserAnimationMapper.map(
    YasserAnimationState.idle,
  );

  /// Optional notifier fired whenever rig state or ViewModel values update for QA UI.
  final VoidCallback? onTelemetryTick;

  YasserRiveController(
    super.file,
    YasserAnimationConfig config, {
    this.onTelemetryTick,
  }) : super(
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
      _isPeeking = viewModel.boolean('isPeeking');
      _isListening = viewModel.boolean('isListening');
      _isThinking = viewModel.boolean('isThinking');
      _isSpeaking = viewModel.boolean('isSpeaking');
      _isFollowingInput = viewModel.boolean('isFollowingInput');
      _lookX = viewModel.number('lookX');
      _lookY = viewModel.number('lookY');
      _mouthShape = viewModel.number('mouthShape');
      _onboardingScene = viewModel.number('onboardingScene');

      _triggers = {
        'wave': viewModel.trigger('wave'),
        'jump': viewModel.trigger('jump'),
        'nameEntry': viewModel.trigger('nameEntry'),
        'celebrate': viewModel.trigger('celebrate'),
        'encourage': viewModel.trigger('encourage'),
        'retry': viewModel.trigger('retry'),
        'sessionComplete': viewModel.trigger('sessionComplete'),
        'resetToIdle': viewModel.trigger('resetToIdle'),
      };

      _viewModel = viewModel;
      _cacheDebugComponents();
      super.advance(0);
    } catch (_) {
      _disposeCachedComponents();
      super.dispose();
      viewModel?.dispose();
      rethrow;
    }
  }

  void _cacheDebugComponents() {
    const names = [
      'P1_MasterRoot',
      'P1_Pelvis_Spine',
      'P1_Chest',
      'P1_Neck_Head',
      'P1_UpperArm_ScreenL',
      'P1_Forearm_ScreenL',
      'P1_Hand_ScreenL',
      'P1_UpperArm_ScreenR',
      'P1_Forearm_ScreenR',
      'P1_Hand_ScreenR',
      'P1_Thigh_ScreenL',
      'P1_Shin_ScreenL',
      'P1_Ankle_ScreenL',
      'P1_Thigh_ScreenR',
      'P1_Shin_ScreenR',
      'P1_Ankle_ScreenR',
      'P1_HandTarget_ScreenL',
      'P1_HandTarget_ScreenR',
      'P1_FootTarget_ScreenL',
      'P1_FootTarget_ScreenR',
      'P1_Neck_Head_Face_EyeL',
      'P1_Neck_Head_Face_EyeR',
      'P1_Neck_Head_Face_BrowL',
      'P1_Neck_Head_Face_BrowR',
      'P1_Neck_Head_Face_Mouth',
    ];
    for (final name in names) {
      _cachedComponents[name] = artboard.component(name);
    }
  }

  void _disposeCachedComponents() {
    for (final comp in _cachedComponents.values) {
      comp?.dispose();
    }
    _cachedComponents.clear();
  }

  bool get isPaused => _isPaused;
  set isPaused(bool value) {
    if (_isPaused == value) return;
    _isPaused = value;
    scheduleRepaint();
  }

  set viseme(YasserViseme? value) {
    if (_viseme == value) return;
    _viseme = value;
    _syncMouthShape();
    scheduleRepaint();
  }

  /// Overrides `mouthShape` directly from Yasser Lab controls (`null` returns control to visemes/state).
  void setDirectMouthShape(int? shapeIndex) {
    _directMouthShapeOverride = shapeIndex?.clamp(0, 8);
    _syncMouthShape();
    scheduleRepaint();
  }

  /// Advances a single 60fps frame even while playback is paused (for Lab frame stepping).
  void stepOneFrame() {
    _pendingStepFrames++;
    scheduleRepaint();
  }

  /// Fires a ViewModel1 trigger directly by name.
  bool fireTrigger(String triggerName) {
    final trig = _triggers[triggerName];
    if (trig == null) return false;
    trig.trigger();
    scheduleRepaint();
    return true;
  }

  void applyMapping(YasserStateMapping mapping) {
    final prevState = _mapping.semanticState;
    _mapping = mapping;
    _syncBooleanAndNumberInputs();

    final triggerName = mapping.riveViewModelTrigger;
    if (triggerName != null) {
      final isRedundantReset =
          triggerName == 'resetToIdle' &&
          (prevState == YasserAnimationState.idle ||
              prevState == YasserAnimationState.returningToIdle ||
              prevState == YasserAnimationState.blinking);
      if (!isRedundantReset) {
        _triggers[triggerName]?.trigger();
      }
    }

    if (reducedMotion) {
      _snapGaze();
    }
    scheduleRepaint();
  }

  void setPasswordTyping(bool value) => applyMapping(
    YasserAnimationMapper.map(
      value ? YasserAnimationState.coveringEyes : YasserAnimationState.idle,
    ),
  );

  void _syncBooleanAndNumberInputs() {
    if (_passwordTyping.value != _mapping.rivePasswordTyping) {
      _passwordTyping.value = _mapping.rivePasswordTyping;
    }
    if (_isPeeking != null && _isPeeking.value != _mapping.riveIsPeeking) {
      _isPeeking.value = _mapping.riveIsPeeking;
    }
    if (_isListening != null &&
        _isListening.value != _mapping.riveIsListening) {
      _isListening.value = _mapping.riveIsListening;
    }
    if (_isThinking != null && _isThinking.value != _mapping.riveIsThinking) {
      _isThinking.value = _mapping.riveIsThinking;
    }
    if (_isSpeaking != null && _isSpeaking.value != _mapping.riveIsSpeaking) {
      _isSpeaking.value = _mapping.riveIsSpeaking;
    }
    if (_isFollowingInput != null &&
        _isFollowingInput.value != _mapping.riveIsFollowingInput) {
      _isFollowingInput.value = _mapping.riveIsFollowingInput;
    }
    if (_onboardingScene != null &&
        _onboardingScene.value != _mapping.riveOnboardingScene) {
      _onboardingScene.value = _mapping.riveOnboardingScene;
    }
    _syncMouthShape();
  }

  void _syncMouthShape() {
    final mouthProp = _mouthShape;
    if (mouthProp == null) return;
    final desired =
        (_directMouthShapeOverride ??
                _viseme?.mouthShapeIndex ??
                _mapping.defaultMouthShape)
            .clamp(0, 8)
            .toDouble();
    if (mouthProp.value != desired) {
      mouthProp.value = desired;
    }
  }

  Offset _effectiveGazeTarget() {
    if (_mapping.rivePasswordTyping && !_mapping.riveIsPeeking) {
      return Offset.zero;
    }
    return Offset(
      _mapping.gazeTarget.dx.clamp(-1.0, 1.0),
      _mapping.gazeTarget.dy.clamp(-1.0, 1.0),
    );
  }

  void _snapGaze() {
    final target = _effectiveGazeTarget();
    _currentGazeX = target.dx;
    _currentGazeY = target.dy;
    if (_lookX != null) _lookX.value = _currentGazeX;
    if (_lookY != null) _lookY.value = _currentGazeY;
  }

  bool _advanceGaze(double dt) {
    final target = _effectiveGazeTarget();
    if (reducedMotion || dt <= 0) {
      final changed =
          (_currentGazeX - target.dx).abs() > 1e-4 ||
          (_currentGazeY - target.dy).abs() > 1e-4;
      _snapGaze();
      return changed;
    }
    final dx = target.dx - _currentGazeX;
    final dy = target.dy - _currentGazeY;
    if (dx.abs() < 0.001 && dy.abs() < 0.001) {
      if (_currentGazeX != target.dx || _currentGazeY != target.dy) {
        _snapGaze();
        return true;
      }
      return false;
    }
    final alpha = (1.0 - math.exp(-14.0 * dt)).clamp(0.0, 1.0);
    _currentGazeX += dx * alpha;
    _currentGazeY += dy * alpha;
    if (_lookX != null) _lookX.value = _currentGazeX;
    if (_lookY != null) _lookY.value = _currentGazeY;
    return true;
  }

  /// Snapshot of live `ViewModel1` property values for Yasser Lab & integration tests.
  Map<String, dynamic> get liveViewModelValues => {
    'passwordTyping': _passwordTyping.value,
    'isPeeking': _isPeeking?.value,
    'isListening': _isListening?.value,
    'isThinking': _isThinking?.value,
    'isSpeaking': _isSpeaking?.value,
    'isFollowingInput': _isFollowingInput?.value,
    'lookX': double.parse((_lookX?.value ?? 0.0).toStringAsFixed(3)),
    'lookY': double.parse((_lookY?.value ?? 0.0).toStringAsFixed(3)),
    'mouthShape': (_mouthShape?.value ?? 0).round(),
    'onboardingScene': (_onboardingScene?.value ?? 0).round(),
    'hasTriggers': _triggers.values.where((t) => t != null).length,
  };

  Offset? _worldPos(String name) {
    final comp = _cachedComponents[name];
    if (comp == null) return null;
    final vals = comp.worldTransform.values;
    final tx = vals[4];
    final ty = vals[5];
    if (!tx.isFinite || !ty.isFinite) return null;
    return Offset(tx, ty);
  }

  /// Reads current bone segments and IK target positions in artboard coordinates.
  YasserRigDebugSnapshot readRigSnapshot() {
    final bones = <YasserRigBoneSegment>[];
    void addSeg(String label, String from, String to) {
      final a = _worldPos(from);
      final b = _worldPos(to);
      if (a != null && b != null) {
        bones.add(YasserRigBoneSegment(label: label, start: a, end: b));
      }
    }

    addSeg('Spine', 'P1_Pelvis_Spine', 'P1_Chest');
    addSeg('Neck', 'P1_Chest', 'P1_Neck_Head');
    addSeg('L_Upper', 'P1_UpperArm_ScreenL', 'P1_Forearm_ScreenL');
    addSeg('L_Lower', 'P1_Forearm_ScreenL', 'P1_Hand_ScreenL');
    addSeg('R_Upper', 'P1_UpperArm_ScreenR', 'P1_Forearm_ScreenR');
    addSeg('R_Lower', 'P1_Forearm_ScreenR', 'P1_Hand_ScreenR');
    addSeg('L_Thigh', 'P1_Thigh_ScreenL', 'P1_Shin_ScreenL');
    addSeg('L_Shin', 'P1_Shin_ScreenL', 'P1_Ankle_ScreenL');
    addSeg('R_Thigh', 'P1_Thigh_ScreenR', 'P1_Shin_ScreenR');
    addSeg('R_Shin', 'P1_Shin_ScreenR', 'P1_Ankle_ScreenR');

    final targets = <String, Offset>{};
    for (final name in const [
      'P1_HandTarget_ScreenL',
      'P1_HandTarget_ScreenR',
      'P1_FootTarget_ScreenL',
      'P1_FootTarget_ScreenR',
    ]) {
      final p = _worldPos(name);
      if (p != null) targets[name] = p;
    }

    final facialAnchors = <String, Offset>{};
    for (final name in const [
      'P1_Neck_Head_Face_EyeL',
      'P1_Neck_Head_Face_EyeR',
      'P1_Neck_Head_Face_BrowL',
      'P1_Neck_Head_Face_BrowR',
      'P1_Neck_Head_Face_Mouth',
    ]) {
      final p = _worldPos(name);
      if (p != null) facialAnchors[name] = p;
    }

    return YasserRigDebugSnapshot(
      artboardWidth: artboard.width,
      artboardHeight: artboard.height,
      bones: bones,
      targets: targets,
      facialAnchors: facialAnchors,
    );
  }

  @override
  bool advance(double elapsedSeconds) {
    if (_isPaused && _pendingStepFrames <= 0) {
      _syncBooleanAndNumberInputs();
      return false;
    }

    final double dt;
    if (_isPaused && _pendingStepFrames > 0) {
      _pendingStepFrames--;
      dt = 1 / 60;
    } else {
      dt = elapsedSeconds * playbackSpeed.clamp(0.05, 2.0);
    }

    _syncBooleanAndNumberInputs();
    final gazeChanged = _advanceGaze(dt);
    final machineChanged = super.advance(dt);
    onTelemetryTick?.call();
    return active && (machineChanged || gazeChanged);
  }

  @override
  void dispose() {
    _disposeCachedComponents();
    super.dispose();
    _viewModel.dispose();
  }
}
