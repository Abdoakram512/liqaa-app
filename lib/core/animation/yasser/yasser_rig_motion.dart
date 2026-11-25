import 'dart:math' as math;
import 'dart:ui';

import 'package:rive/rive.dart' as rive;

import 'yasser_animation_mapper.dart';
import 'yasser_animation_state.dart';
import 'yasser_viseme.dart';

/// Applies small procedural poses to the exported Phase 1 bones after Rive
/// advances its authored animation. Every adjustment is restored before the
/// next state machine tick so the offsets never accumulate.
final class YasserRigMotion {
  final Map<String, rive.Component?> _bones;
  final List<VoidCallback> _restore = [];
  Offset _gaze = Offset.zero;
  double _elapsedInState = 0;
  double _breathTime = 0;
  YasserAnimationState? _previousState;

  YasserRigMotion(rive.Artboard artboard)
    : _bones = {
        for (final name in [
          'P1_MasterRoot',
          'P1_Neck_Head',
          'P1_Neck_Head_Face_EyeL',
          'P1_Neck_Head_Face_EyeR',
          'P1_Neck_Head_Face_BrowL',
          'P1_Neck_Head_Face_BrowR',
          'P1_Neck_Head_Face_Mouth',
          'P1_HandTarget_ScreenR',
          'P1_Hand_ScreenR_Index',
          'P1_Hand_ScreenR_Middle',
        ])
          name: artboard.component(name),
      };

  void restore() {
    for (var i = _restore.length - 1; i >= 0; i--) {
      _restore[i]();
    }
    _restore.clear();
  }

  bool apply(
    YasserStateMapping mapping,
    double elapsed, {
    required bool reducedMotion,
    required double breathingPeriod,
    YasserViseme? viseme,
  }) {
    final state = mapping.semanticState;
    if (_previousState != state) {
      _previousState = state;
      _elapsedInState = 0;
    }
    _elapsedInState += elapsed;
    if (mapping.rivePasswordTyping) {
      _gaze = Offset.zero;
      if (state == YasserAnimationState.peeking) {
        final spread = reducedMotion
            ? 1.0
            : (_elapsedInState / .22).clamp(0.0, 1.0);
        _rotate('P1_Hand_ScreenR_Index', -.16 * spread);
        _rotate('P1_Hand_ScreenR_Middle', .13 * spread);
        _slide('P1_HandTarget_ScreenR', dx: 14 * spread, dy: -2 * spread);
        final eye = _bones['P1_Neck_Head_Face_EyeR'];
        if (eye != null) {
          final base = eye.scaleY;
          eye.scaleY = base + (.55 - base) * spread;
          _restore.add(() => eye.scaleY = base);
        }
        return spread < 1;
      }
      return false;
    }

    if (state == YasserAnimationState.waving) {
      _gaze = Offset.zero;
      return false;
    }

    final gazeTarget = mapping.gazeTarget;
    final blend = reducedMotion ? 1.0 : 1 - math.exp(-16 * elapsed);
    _gaze = (gazeTarget - _gaze).distance < .005
        ? gazeTarget
        : Offset.lerp(_gaze, gazeTarget, blend)!;

    if (!reducedMotion && breathingPeriod > 0) {
      _breathTime = (_breathTime + elapsed) % breathingPeriod;
      final breath = math.sin(_breathTime * 2 * math.pi / breathingPeriod);
      _stretch('P1_MasterRoot', y: 1 + .004 * breath);
      _slide('P1_MasterRoot', dy: -2.4 * breath);
    }

    var tilt = .025 * _gaze.dx;
    var lift = 0.0;
    var brow = _gaze.dy * 1.2;
    var mouth = 1.0;
    var mouthWidth = 1.0;
    switch (state) {
      case YasserAnimationState.thinking:
        tilt -= .07;
        brow -= 4;
        final raise = reducedMotion
            ? 1.0
            : (_elapsedInState / .3).clamp(0.0, 1.0);
        _slide('P1_HandTarget_ScreenR', dx: -40 * raise, dy: -144 * raise);
      case YasserAnimationState.confused:
        tilt += .055;
        brow -= 2;
      case YasserAnimationState.listening:
        tilt += .055;
        brow += 4;
      case YasserAnimationState.talking:
        if (viseme != null) {
          mouth = viseme.height;
          mouthWidth = viseme.width;
        } else {
          mouth += reducedMotion
              ? .12
              : .21 * (1 + math.sin(_elapsedInState * 2 * math.pi * 4));
        }
      case YasserAnimationState.happy:
        brow += 4;
        mouth += .18;
      case YasserAnimationState.celebrating:
        brow += 5;
        mouth += .25;
        final progress = (_elapsedInState / .72).clamp(0.0, 1.0);
        if (!reducedMotion) {
          final jump = math.sin(math.pi * progress);
          lift = -24 * jump;
          _slide('P1_HandTarget_ScreenR', dx: 13 * jump, dy: -92 * jump);
        }
      default:
        break;
    }
    _rotate('P1_Neck_Head', tilt);
    _slide('P1_MasterRoot', dy: lift);
    // The face bones are rotated a quarter turn relative to the artboard.
    for (final side in ['L', 'R']) {
      _slide('P1_Neck_Head_Face_Eye$side', dx: -4 * _gaze.dy, dy: 4 * _gaze.dx);
      _slide('P1_Neck_Head_Face_Brow$side', dx: brow);
      if (state == YasserAnimationState.blinking && !reducedMotion) {
        _stretch('P1_Neck_Head_Face_Eye$side', y: .12);
      }
    }
    _stretch('P1_Neck_Head_Face_Mouth', x: mouthWidth, y: mouth);
    return (!reducedMotion && breathingPeriod > 0) ||
        _gaze != gazeTarget ||
        (!reducedMotion &&
            state == YasserAnimationState.talking &&
            viseme == null) ||
        (!reducedMotion &&
            state == YasserAnimationState.thinking &&
            _elapsedInState < .3) ||
        (!reducedMotion &&
            state == YasserAnimationState.celebrating &&
            _elapsedInState < .72);
  }

  void _slide(String name, {double dx = 0, double dy = 0}) {
    final bone = _bones[name];
    if (bone == null) return;
    if (dx != 0) {
      final base = bone.x;
      bone.x = base + dx;
      _restore.add(() => bone.x = base);
    }
    if (dy != 0) {
      final base = bone.y;
      bone.y = base + dy;
      _restore.add(() => bone.y = base);
    }
  }

  void _rotate(String name, double amount) {
    final bone = _bones[name];
    if (bone == null || amount == 0) return;
    final base = bone.rotation;
    bone.rotation = base + amount;
    _restore.add(() => bone.rotation = base);
  }

  void _stretch(String name, {double x = 1, double y = 1}) {
    final bone = _bones[name];
    if (bone == null) return;
    if (x != 1) {
      final base = bone.scaleX;
      bone.scaleX = base * x;
      _restore.add(() => bone.scaleX = base);
    }
    if (y != 1) {
      final base = bone.scaleY;
      bone.scaleY = base * y;
      _restore.add(() => bone.scaleY = base);
    }
  }

  void dispose() {
    _restore.clear();
    for (final bone in _bones.values) {
      bone?.dispose();
    }
  }
}
