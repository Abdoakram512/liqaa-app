import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_capabilities.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_config.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_mapper.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_state.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_rive_controller.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_viseme.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';
import 'package:liqaa_app/features/animation_lab/presentation/views/animation_lab_view.dart';
import 'package:liqaa_app/features/pronunciation_game/models/yasser_prompt.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Yasser Master Rive Rig Integration', () {
    test(
      'loads ViewModel1 properties, sweeps all states/visemes, drives eye gaze & survives stress',
      () async {
        final file = await rive.File.decode(
          await File(YasserAnimationCapabilities.assetPath).readAsBytes(),
          riveFactory: rive.Factory.flutter,
        );
        expect(file, isNotNull);

        final controller = YasserRiveController(
          file!,
          const YasserAnimationConfig(),
        );

        try {
          final vm = controller.liveViewModelValues;
          expect(vm['hasTriggers'], equals(8));
          expect(vm.containsKey('passwordTyping'), isTrue);
          expect(vm.containsKey('isPeeking'), isTrue);
          expect(vm.containsKey('isListening'), isTrue);
          expect(vm.containsKey('isThinking'), isTrue);
          expect(vm.containsKey('isSpeaking'), isTrue);
          expect(vm.containsKey('isFollowingInput'), isTrue);
          expect(vm.containsKey('lookX'), isTrue);
          expect(vm.containsKey('lookY'), isTrue);
          expect(vm.containsKey('mouthShape'), isTrue);
          expect(vm.containsKey('onboardingScene'), isTrue);

          const statesToTest = [
            YasserAnimationState.idle,
            YasserAnimationState.waving,
            YasserAnimationState.coveringEyes,
            YasserAnimationState.peeking,
            YasserAnimationState.returningToIdle,
            YasserAnimationState.followingInput,
            YasserAnimationState.listening,
            YasserAnimationState.thinking,
            YasserAnimationState.talking,
            YasserAnimationState.encouraging,
            YasserAnimationState.gentleRetry,
            YasserAnimationState.celebrating,
            YasserAnimationState.sessionComplete,
            YasserAnimationState.onboardingWelcome,
            YasserAnimationState.onboardingDiscovery,
            YasserAnimationState.onboardingReady,
          ];

          for (final state in statesToTest) {
            controller.applyMapping(YasserAnimationMapper.map(state));
            for (var f = 0; f < 20; f++) {
              controller.advance(1 / 60);
            }
            final snap = controller.readRigSnapshot();
            expect(snap.bones.length, equals(10));
            expect(snap.targets.length, equals(4));
            for (final seg in snap.bones) {
              expect(seg.start.dx.isFinite && seg.start.dy.isFinite, isTrue);
              expect(seg.end.dx.isFinite && seg.end.dy.isFinite, isTrue);
            }
            for (final pt in snap.targets.values) {
              expect(pt.dx.isFinite && pt.dy.isFinite, isTrue);
            }
          }

          // Verify 9-shape mouth sweep (0..8)
          for (var shape = 0; shape <= 8; shape++) {
            controller.setDirectMouthShape(shape);
            controller.advance(1 / 60);
            expect(controller.liveViewModelValues['mouthShape'], equals(shape));
          }
          controller.setDirectMouthShape(null);

          // Verify continuous lookX / lookY moves eye transforms
          controller.reducedMotion = true;
          controller.applyMapping(
            YasserAnimationMapper.map(YasserAnimationState.lookingLeft),
          );
          controller.advance(1 / 60);
          final eyeLeftLookingLeft = controller
              .readRigSnapshot()
              .facialAnchors['P1_Neck_Head_Face_EyeL']!;

          controller.applyMapping(
            YasserAnimationMapper.map(YasserAnimationState.lookingRight),
          );
          controller.advance(1 / 60);
          final eyeLeftLookingRight = controller
              .readRigSnapshot()
              .facialAnchors['P1_Neck_Head_Face_EyeL']!;
          expect(eyeLeftLookingRight.dx, greaterThan(eyeLeftLookingLeft.dx));

          controller.applyMapping(
            YasserAnimationMapper.map(YasserAnimationState.lookingUp),
          );
          controller.advance(1 / 60);
          final eyeLeftLookingUp = controller
              .readRigSnapshot()
              .facialAnchors['P1_Neck_Head_Face_EyeL']!;

          controller.applyMapping(
            YasserAnimationMapper.map(YasserAnimationState.lookingDown),
          );
          controller.advance(1 / 60);
          final eyeLeftLookingDown = controller
              .readRigSnapshot()
              .facialAnchors['P1_Neck_Head_Face_EyeL']!;
          expect(eyeLeftLookingDown.dy, greaterThan(eyeLeftLookingUp.dy));
          controller.reducedMotion = false;

          // Verify pause & +1 frame step
          controller.isPaused = true;
          expect(controller.advance(1 / 60), isFalse);
          controller.stepOneFrame();
          controller.advance(1 / 60);
          controller.isPaused = false;

          // Verify 50-step rapid interruption stress test settles cleanly at idle
          for (var i = 0; i < 50; i++) {
            final s = statesToTest[i % statesToTest.length];
            controller.applyMapping(YasserAnimationMapper.map(s));
            controller.advance(1 / 60);
          }
          controller.applyMapping(
            YasserAnimationMapper.map(YasserAnimationState.idle),
          );
          for (var f = 0; f < 90; f++) {
            controller.advance(1 / 60);
          }
          final settledSnap = controller.readRigSnapshot();
          expect(
            settledSnap.targets['P1_HandTarget_ScreenR']!.dy.isFinite,
            isTrue,
          );
        } finally {
          controller.dispose();
          file.dispose();
        }
      },
    );

    test('YasserPrompt.cuesForWord produces valid Arabic viseme cues', () {
      final samaka = YasserPrompt.cuesForWord(
        wordId: 'word_samaka',
        arabicWord: 'سمكة',
      );
      expect(samaka.first.pose, equals(YasserViseme.teeth));
      expect(samaka.last.pose, equals(YasserViseme.rest));

      final farawla = YasserPrompt.cuesForWord(arabicWord: 'فراولة');
      expect(farawla.first.pose, equals(YasserViseme.labiodental));
      expect(farawla.any((c) => c.pose == YasserViseme.wideOpen), isTrue);
      expect(farawla.any((c) => c.pose == YasserViseme.rounded), isTrue);
      expect(farawla.last.pose, equals(YasserViseme.rest));
    });

    testWidgets(
      'AnimationLabView renders transport controls, Skeletal QA & all 4 tabs',
      (tester) async {
        final prevRuntime = YasserCharacter.enableRiveRuntime;
        final prevBlink = YasserInteractionEngine.enableBlinkTimer;
        YasserCharacter.enableRiveRuntime = false;
        YasserInteractionEngine.enableBlinkTimer = false;
        addTearDown(() {
          YasserCharacter.enableRiveRuntime = prevRuntime;
          YasserInteractionEngine.enableBlinkTimer = prevBlink;
        });

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(520, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => const MaterialApp(home: AnimationLabView()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('Skeletal QA'), findsOneWidget);
        expect(find.text('+1 Frame'), findsOneWidget);
        expect(find.text('Cover Eyes'), findsOneWidget);

        await tester.drag(find.byType(ListView).first, const Offset(0, -420));
        await tester.pump();
        expect(find.text('Onboarding 1: Welcome'), findsOneWidget);

        await tester.ensureVisible(find.text('Skeletal QA'));
        await tester.tap(find.text('Skeletal QA'));
        await tester.ensureVisible(find.text('+1 Frame'));
        await tester.tap(find.text('+1 Frame'));
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Gaze tab
        await tester.ensureVisible(find.text('الدخول والنظر'));
        await tester.pump();
        await tester.tap(find.text('الدخول والنظر'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('محاكاة حقول الدخول'), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pump();
        expect(find.textContaining('lookX:'), findsOneWidget);

        // Switch to Mouth & Lip-Sync tab
        await tester.ensureVisible(find.text('الفم ومزامنة الصوت'));
        await tester.pump();
        await tester.tap(find.text('الفم ومزامنة الصوت'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('أوضاع الفم التسعة'), findsOneWidget);

        // Switch to Diagnostics tab
        await tester.ensureVisible(find.text('التشخيص والإجهاد'));
        await tester.pump();
        await tester.tap(find.text('التشخيص والإجهاد'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.textContaining('Single-Owner Rive Authority'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
      },
    );
  });
}
