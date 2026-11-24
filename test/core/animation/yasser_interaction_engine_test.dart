import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_config.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_state.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';

void main() {
  group('YasserInteractionEngine Tests', () {
    late YasserInteractionEngine engine;

    setUp(() {
      engine = YasserInteractionEngine(
        config: const YasserAnimationConfig(
          transientHoldDuration: Duration(milliseconds: 100),
          tapCooldown: Duration(milliseconds: 150),
        ),
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('starts in natural idle state with ambient priority', () {
      expect(engine.currentState, equals(YasserAnimationState.idle));
      expect(engine.currentPriority, equals(YasserAnimationPriority.ambient));
    });

    test('critical state (coveringEyes) overrides ambient idle', () {
      final accepted = engine.triggerState(YasserAnimationState.coveringEyes);
      expect(accepted, isTrue);
      expect(engine.currentState, equals(YasserAnimationState.coveringEyes));
      expect(engine.currentPriority, equals(YasserAnimationPriority.critical));
    });

    test('ambient state cannot override active critical state', () {
      engine.triggerState(YasserAnimationState.coveringEyes);
      final accepted = engine.triggerState(YasserAnimationState.idle);

      expect(accepted, isFalse);
      expect(engine.currentState, equals(YasserAnimationState.coveringEyes));
      expect(engine.currentPriority, equals(YasserAnimationPriority.critical));
    });

    test('transient state automatically returns to idle after hold duration', () async {
      engine.triggerState(
        YasserAnimationState.waving,
        customHoldDuration: const Duration(milliseconds: 50),
      );
      expect(engine.currentState, equals(YasserAnimationState.waving));

      await Future.delayed(const Duration(milliseconds: 80));
      expect(engine.currentState, equals(YasserAnimationState.idle));
    });

    test('tap cooldown prevents spamming', () {
      final firstTap = engine.handleTap();
      expect(firstTap, isTrue);

      final immediateSecondTap = engine.handleTap();
      expect(immediateSecondTap, isFalse);
    });

    test('event history tracks triggers and priorities', () {
      engine.triggerState(YasserAnimationState.waving, reason: 'Test Wave');
      engine.triggerState(YasserAnimationState.coveringEyes, reason: 'Test Cover');

      expect(engine.eventHistory.length, greaterThanOrEqualTo(2));
      final lastLog = engine.eventHistory.last;
      expect(lastLog.state, equals(YasserAnimationState.coveringEyes));
      expect(lastLog.priority, equals(YasserAnimationPriority.critical));
    });
  });
}
