import 'dart:math' as math;
import 'dart:ui';

import 'package:rive/rive.dart' as rive;

import 'yasser_animation_state.dart';

/// Moves each wrist around its shoulder so the existing IK chains bend
/// continuously. The hand bone adds only a small rotation at the wrist.
final class YasserArmMotion {
  static const waveDuration = 1.9;
  static const _privacyDuration = .65;
  static const _celebrationDuration = 1.25;
  static const _thinkingDuration = 1.7;

  final _Arm? _left;
  final _Arm? _right;
  double _waveTime = waveDuration;
  double _waveWeight = 0;
  double _privacy = 0;
  double _peek = 0;
  YasserAnimationState _gesture = YasserAnimationState.idle;
  double _gestureSeconds = 0;
  bool _waveRequested = false;
  bool _coverRequested = false;
  bool _peekRequested = false;

  YasserArmMotion(rive.Artboard artboard)
    : _left = _Arm.fromArtboard(artboard, 'L'),
      _right = _Arm.fromArtboard(artboard, 'R');

  void request({
    required YasserAnimationState state,
    required bool cover,
    required bool peek,
  }) {
    final wave = state == YasserAnimationState.waving;
    if (state != _gesture) {
      _gesture = state;
      _gestureSeconds = 0;
    }
    if (wave && !_waveRequested) _waveTime = 0;
    _waveRequested = wave;
    _coverRequested = cover;
    _peekRequested = peek;
  }

  void restore() {
    _left?.restore();
    _right?.restore();
  }

  bool advance(double elapsed, {required bool reducedMotion}) {
    final duration = switch (_gesture) {
      YasserAnimationState.thinking => _thinkingDuration,
      YasserAnimationState.celebrating => _celebrationDuration,
      _ => 0.0,
    };
    _gestureSeconds = reducedMotion
        ? duration
        : math.min(duration, _gestureSeconds + elapsed);
    final privacyTarget = _coverRequested ? 1.0 : 0.0;
    _privacy = reducedMotion
        ? privacyTarget
        : _approach(_privacy, privacyTarget, elapsed / _privacyDuration);

    final peekTarget = _peekRequested ? 1.0 : 0.0;
    _peek = reducedMotion
        ? peekTarget
        : _approach(_peek, peekTarget, elapsed / .22);

    if (_waveRequested && !reducedMotion && _waveTime < waveDuration) {
      _waveTime = math.min(waveDuration, _waveTime + elapsed);
      _waveWeight = 1;
    } else {
      _waveWeight = _approach(_waveWeight, 0, elapsed / .23);
    }
    if (reducedMotion) _waveWeight = 0;
    return _gestureSeconds < duration ||
        _privacy != privacyTarget ||
        _peek != peekTarget ||
        _waveWeight > 0;
  }

  bool get eyesCovered => _privacy > (_coverRequested ? .72 : .9);

  double get _thinking => _gesture == YasserAnimationState.thinking
      ? _envelope(_gestureSeconds, .42, 1.12, _thinkingDuration)
      : 0;

  double get celebration => _gesture == YasserAnimationState.celebrating
      ? _envelope(_gestureSeconds, .45, .59, _celebrationDuration)
      : 0;

  bool get hasArmPose =>
      _privacy > 0 || _waveWeight > 0 || _thinking > 0 || celebration > 0;

  static double _envelope(
    double seconds,
    double rise,
    double release,
    double end,
  ) =>
      _ease(seconds / rise) *
      (1 - _ease((seconds - release) / (end - release)));

  void apply() {
    final privacy = _ease(_privacy);
    final raise = _waveTime < .55
        ? _ease(_waveTime / .55)
        : 1 - _ease((_waveTime - 1.25) / (waveDuration - 1.25));
    final swayProgress = ((_waveTime - .55) / .7).clamp(0.0, 1.0);
    final sway =
        math.sin(2 * math.pi * swayProgress) * math.sin(math.pi * swayProgress);
    final wave = _waveWeight * raise;
    final bend = 22 * math.sin(math.pi * privacy);
    final thought = _thinking;
    final cheer = celebration;
    _left?.apply(
      angleOffset: _mix(
        wave * (2.45 + .14 * sway) + 2.59 * cheer,
        3.26,
        privacy,
      ),
      radius:
          _mix(_mix(_left.restRadius, 82, wave + cheer), 90, privacy) - bend,
      wristOffset: _mix(wave * (.22 + .07 * sway) + .17 * cheer, .05, privacy),
    );
    _right?.apply(
      angleOffset: _mix(
        .63 * thought - 2.54 * cheer,
        _mix(-3.31, -3.08, _ease(_peek)),
        privacy,
      ),
      radius:
          _mix(_right.restRadius - 24 * thought - 12 * cheer, 89, privacy) -
          bend,
      wristOffset: _mix(-.06 * thought - .20 * cheer, -.06, privacy),
    );
  }

  static double _approach(double value, double target, double step) =>
      value < target
      ? math.min(target, value + step)
      : math.max(target, value - step);

  static double _mix(double start, double finish, double t) =>
      start + (finish - start) * t;

  static double _ease(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void dispose() {
    _left?.dispose();
    _right?.dispose();
  }
}

final class _Arm {
  final rive.Component _target;
  final rive.Component _hand;
  final Offset _shoulder;
  final Offset _targetOrigin;
  final double _restAngle;
  final double restRadius;
  final double _restWristRotation;
  (double, double, double)? _original;

  _Arm(
    this._target,
    this._hand,
    this._shoulder,
    Offset rest,
    this._targetOrigin,
  ) : _restAngle = (rest - _shoulder).direction,
      restRadius = (rest - _shoulder).distance,
      _restWristRotation = _hand.rotation;

  static _Arm? fromArtboard(rive.Artboard artboard, String side) {
    final target = artboard.component('P1_HandTarget_Screen$side');
    final hand = artboard.component('P1_Hand_Screen$side');
    final upper = artboard.component('P1_UpperArm_Screen$side');
    if (target == null || hand == null || upper == null) {
      target?.dispose();
      hand?.dispose();
      upper?.dispose();
      return null;
    }
    final rest = _position(target);
    final shoulder = _position(upper);
    upper.dispose();
    // The exported hand targets share an unrotated rig-space parent.
    return _Arm(
      target,
      hand,
      shoulder,
      rest,
      rest - Offset(target.x, target.y),
    );
  }

  static Offset _position(rive.Component component) {
    final transform = component.worldTransform;
    return Offset(transform[4], transform[5]);
  }

  void apply({
    required double angleOffset,
    required double radius,
    required double wristOffset,
  }) {
    _original = (_target.x, _target.y, _hand.rotation);
    final wrist =
        _shoulder + Offset.fromDirection(_restAngle + angleOffset, radius);
    _target
      ..x = wrist.dx - _targetOrigin.dx
      ..y = wrist.dy - _targetOrigin.dy;
    _hand.rotation = _restWristRotation + wristOffset;
  }

  void restore() {
    if (_original case (final x, final y, final rotation)) {
      _target
        ..x = x
        ..y = y;
      _hand.rotation = rotation;
      _original = null;
    }
  }

  void dispose() {
    _target.dispose();
    _hand.dispose();
  }
}
