import 'package:flutter/animation.dart';

abstract final class AnimationConstants {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 350);
  static const Duration medium = Duration(milliseconds: 500);
  static const Duration long = Duration(milliseconds: 750);
  static const Duration splash = Duration(milliseconds: 2200);

  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
}
