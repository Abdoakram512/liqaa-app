import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/widgets/primary_button.dart';
import 'package:liqaa_app/core/widgets/secondary_button.dart';
import 'package:liqaa_app/core/widgets/yasser_avatar.dart';

Widget _buildTestApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('Core Reusable Widgets Tests', () {
    testWidgets('PrimaryButton renders label and triggers callback', (
      tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        _buildTestApp(
          PrimaryButton(label: 'يلا نبدأ', onPressed: () => pressed = true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('يلا نبدأ'), findsOneWidget);
      await tester.tap(find.text('يلا نبدأ'));
      expect(pressed, true);
    });

    testWidgets('SecondaryButton renders label and triggers callback', (
      tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        _buildTestApp(
          SecondaryButton(label: 'السابق', onPressed: () => pressed = true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('السابق'), findsOneWidget);
      await tester.tap(find.text('السابق'));
      expect(pressed, true);
    });

    testWidgets('YasserAvatar instantiates cleanly for all character poses', (
      tester,
    ) async {
      for (final pose in YasserPose.values) {
        await tester.pumpWidget(
          _buildTestApp(YasserAvatar(pose: pose, animateBreathing: false)),
        );
        expect(find.byType(YasserAvatar), findsOneWidget);
      }
    });
  });
}
