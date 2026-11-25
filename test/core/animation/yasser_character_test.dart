import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_state.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_controller.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    YasserCharacter.enableRiveRuntime = false;
  });

  tearDown(() {
    YasserCharacter.enableRiveRuntime = true;
  });

  group('YasserCharacter & Rive 0.14+ Integration Tests', () {
    testWidgets('switching controllers uses the replacement immediately', (
      tester,
    ) async {
      final first = YasserController();
      final replacement = YasserController();
      Widget scene(YasserController controller) =>
          MaterialApp(home: YasserCharacter(controller: controller));
      await tester.pumpWidget(scene(first));
      await tester.pumpWidget(scene(replacement));
      replacement.coverEyes();
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.endsWith(
                'yasser_thinking.png',
              ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(YasserCharacter));
      expect(first.eventHistory, isEmpty);
      expect(replacement.eventHistory.length, greaterThan(1));
      await tester.pumpWidget(const SizedBox());
      first.dispose();
      replacement.dispose();
    });
    testWidgets(
      'YasserCharacter initializes and renders fallback seamlessly in test environment',
      (tester) async {
        final controller = YasserController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: YasserCharacter(controller: controller)),
          ),
        );

        // Verify the widget mounts
        expect(find.byType(YasserCharacter), findsOneWidget);
        expect(controller.currentState, equals(YasserAnimationState.idle));

        // Trigger state change
        controller.coverEyes();
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          controller.currentState,
          equals(YasserAnimationState.coveringEyes),
        );

        controller.peek();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.currentState, equals(YasserAnimationState.peeking));

        controller.uncoverEyes();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.currentState, equals(YasserAnimationState.idle));

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets('YasserCharacter handles tap reaction callback', (
      tester,
    ) async {
      bool tapped = false;
      final controller = YasserController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YasserCharacter(
              controller: controller,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(YasserCharacter));
      await tester.pump();

      expect(tapped, isTrue);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
