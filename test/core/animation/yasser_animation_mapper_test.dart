import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_mapper.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_state.dart';

void main() {
  group('YasserAnimationMapper Tests', () {
    test('idle maps to standing pose with false passwordTyping', () {
      final mapping = YasserAnimationMapper.map(YasserAnimationState.idle);
      expect(mapping.semanticState, equals(YasserAnimationState.idle));
      expect(mapping.rivePasswordTyping, isFalse);
      expect(mapping.fallbackAssetPath, contains('yasser_standing.png'));
      expect(mapping.gazeTarget, equals(Offset.zero));
    });

    test('coveringEyes maps to true passwordTyping and thinking pose', () {
      final mapping = YasserAnimationMapper.map(
        YasserAnimationState.coveringEyes,
      );
      expect(mapping.semanticState, equals(YasserAnimationState.coveringEyes));
      expect(mapping.rivePasswordTyping, isTrue);
      expect(mapping.fallbackAssetPath, contains('yasser_thinking.png'));
    });

    test('peeking maintains true passwordTyping with offset gaze', () {
      final mapping = YasserAnimationMapper.map(YasserAnimationState.peeking);
      expect(mapping.semanticState, equals(YasserAnimationState.peeking));
      expect(mapping.rivePasswordTyping, isTrue);
      expect(mapping.gazeTarget, equals(const Offset(0.1, 0.1)));
    });

    test('waving maps to waving pose and triggers wave validation', () {
      final mapping = YasserAnimationMapper.map(YasserAnimationState.waving);
      expect(mapping.semanticState, equals(YasserAnimationState.waving));
      expect(mapping.rivePasswordTyping, isFalse);
      expect(mapping.fallbackAssetPath, contains('yasser_waving.png'));
      expect(mapping.riveAnimationTrigger, equals('P1_Wave_Validation'));
    });

    test('celebrating maps to celebrating pose and jump trigger', () {
      final mapping = YasserAnimationMapper.map(
        YasserAnimationState.celebrating,
      );
      expect(mapping.semanticState, equals(YasserAnimationState.celebrating));
      expect(mapping.fallbackAssetPath, contains('yasser_celebrating.png'));
      expect(mapping.riveAnimationTrigger, equals('jump'));
    });

    test('followingInput preserves custom gaze coordinates', () {
      const customGaze = Offset(0.45, -0.2);
      final mapping = YasserAnimationMapper.map(
        YasserAnimationState.followingInput,
        customGaze: customGaze,
      );
      expect(
        mapping.semanticState,
        equals(YasserAnimationState.followingInput),
      );
      expect(mapping.gazeTarget, equals(customGaze));
    });
  });
}
