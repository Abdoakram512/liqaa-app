import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_animation_state.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';
import 'package:liqaa_app/core/widgets/yasser_avatar.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';
import 'package:liqaa_app/features/onboarding/data/models/onboarding_item_model.dart';
import 'package:liqaa_app/features/onboarding/presentation/widgets/onboarding_character_scene.dart';
import 'package:liqaa_app/features/pronunciation_game/widgets/yasser_speech_feedback_card.dart';
import 'package:liqaa_app/features/splash/presentation/widgets/splash_content.dart';

void main() {
  Widget app(Widget child) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
  );

  setUp(() {
    YasserCharacter.enableRiveRuntime = false;
    YasserAvatar.enableRepeatingAnimations = false;
    YasserInteractionEngine.enableBlinkTimer = false;
  });

  tearDown(() {
    YasserCharacter.enableRiveRuntime = true;
    YasserAvatar.enableRepeatingAnimations = true;
    YasserInteractionEngine.enableBlinkTimer = true;
  });

  testWidgets('splash greets with the live character widget', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(app(const SplashContent()));
    final character = tester.widget<YasserCharacter>(
      find.byType(YasserCharacter),
    );
    expect(character.state, YasserAnimationState.greeting);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('onboarding plays the scene reaction on the active page', (
    tester,
  ) async {
    const moods = {
      OnboardingEnvironment.welcomeSound: YasserAnimationState.greeting,
      OnboardingEnvironment.soundPuzzle: YasserAnimationState.thinking,
      OnboardingEnvironment.celebrationLaunch: YasserAnimationState.celebrating,
    };
    for (final mood in moods.entries) {
      final item = OnboardingItemModel(
        id: mood.key.index,
        badgeKey: '',
        titleKey: '',
        subtitleKey: '',
        pose: YasserPose.standing,
        accentColor: Colors.orange,
        badgeBackgroundColor: Colors.white,
        environment: mood.key,
      );
      await tester.pumpWidget(
        app(OnboardingCharacterScene(item: item, isActive: false)),
      );
      expect(
        tester.widget<YasserCharacter>(find.byType(YasserCharacter)).state,
        YasserAnimationState.idle,
      );
      await tester.pumpWidget(app(OnboardingCharacterScene(item: item)));
      expect(
        tester.widget<YasserCharacter>(find.byType(YasserCharacter)).state,
        mood.value,
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('pronunciation feedback follows the audio and evaluation state', (
    tester,
  ) async {
    Widget feedback({
      bool speaking = false,
      bool listening = false,
      String pose = 'waving',
    }) => app(
      YasserSpeechFeedbackCard(
        message: 'Hello',
        poseString: pose,
        isListening: listening,
        isPlayingAudioPrompt: speaking,
      ),
    );
    YasserAnimationState? motion() =>
        tester.widget<YasserCharacter>(find.byType(YasserCharacter)).state;

    await tester.pumpWidget(feedback(speaking: true));
    expect(motion(), YasserAnimationState.talking);
    await tester.pumpWidget(feedback(speaking: true, listening: true));
    expect(motion(), YasserAnimationState.listening);
    await tester.pumpWidget(feedback(pose: 'celebrating'));
    expect(motion(), YasserAnimationState.celebrating);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
