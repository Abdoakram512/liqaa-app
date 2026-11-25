import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;
import 'package:liqaa_app/core/animation/yasser/yasser_animation_config.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_mapper.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_state.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_rive_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exported rig owns privacy targets and returns to idle', () async {
    final file = await rive.File.decode(
      await File('assets/rive/yasser.riv').readAsBytes(),
      riveFactory: rive.Factory.flutter,
    );
    expect(file, isNotNull);
    final controller = YasserRiveController(
      file!,
      const YasserAnimationConfig(),
    );
    final right = controller.artboard.component('P1_HandTarget_ScreenR')!;
    final left = controller.artboard.component('P1_HandTarget_ScreenL')!;
    try {
      controller.applyMapping(
        YasserAnimationMapper.map(YasserAnimationState.coveringEyes),
      );
      for (var frame = 0; frame < 90; frame++) {
        controller.advance(1 / 60);
        expect(right.x.isFinite && right.y.isFinite, isTrue);
        expect(left.x.isFinite && left.y.isFinite, isTrue);
      }
      expect(right.x, closeTo(54, .1));
      expect(right.y, closeTo(-195, .1));
      expect(left.y, closeTo(-197, .1));
      controller.applyMapping(
        YasserAnimationMapper.map(YasserAnimationState.idle),
      );
      for (var frame = 0; frame < 90; frame++) {
        controller.advance(1 / 60);
      }
      expect(right.y, closeTo(-23.710571, .1));
      expect(left.y, closeTo(-17.710571, .1));
    } finally {
      right.dispose();
      left.dispose();
      controller.dispose();
      file.dispose();
    }
  });
}
