import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/app/dependency_injection/service_locator.dart';
import 'package:liqaa_app/core/ai/pronunciation_repository.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';
import 'package:liqaa_app/core/audio/yasser_audio_coordinator.dart';
import 'package:liqaa_app/core/theme/app_theme.dart';
import 'package:liqaa_app/core/widgets/yasser_avatar.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';
import 'package:liqaa_app/features/activities/presentation/views/complete_story_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/views/discover_word_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/views/hear_difference_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/views/listen_and_choose_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/views/mystery_sound_boxes_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/views/sound_detective_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/widgets/activity_session_scaffold.dart';
import 'package:liqaa_app/features/world/data/child_world_repository.dart';
import 'package:liqaa_app/features/world/data/models/world_models.dart';
import 'package:liqaa_app/features/world/presentation/cubits/child_world_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapGame(ChildWorldCubit cubit, Widget game) {
  return ScreenUtilInit(
    key: ValueKey(game.runtimeType),
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      key: ValueKey('app_${game.runtimeType}'),
      theme: AppTheme.lightTheme,
      builder: (_, child) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
      home: BlocProvider<ChildWorldCubit>.value(value: cubit, child: game),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChildWorldCubit worldCubit;

  setUpAll(() async {
    await loadReviewedDictionaryWords();
  });

  setUp(() async {
    await sl.reset();
    sl.allowReassignment = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    sl.registerLazySingleton<YasserAudioCoordinator>(
      () => YasserAudioCoordinator(
        enablePlatformAudio: false,
        observeAppLifecycle: false,
      ),
    );

    final repo = ChildWorldRepository(prefs);
    worldCubit = ChildWorldCubit(repo);
    sl.registerSingleton<ChildWorldCubit>(worldCubit);

    YasserCharacter.enableRiveRuntime = false;
    YasserAvatar.enableRepeatingAnimations = false;
    YasserInteractionEngine.enableBlinkTimer = false;
  });

  tearDown(() async {
    YasserCharacter.enableRiveRuntime = true;
    YasserAvatar.enableRepeatingAnimations = true;
    YasserInteractionEngine.enableBlinkTimer = true;
    await worldCubit.close();
    await sl.reset();
  });

  group('Phase 0.2 Mini-Games & Zero-AI Guard', () {
    testWidgets(
      'Game 1 (DiscoverWord) completes without PronunciationRepository and plants garden reward',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        expect(sl.isRegistered<PronunciationRepository>(), isFalse);
        await tester.pumpWidget(
          _wrapGame(
            worldCubit,
            const DiscoverWordGameView(
              config: ActivityLaunchConfig(
                gameType: MiniGameType.discoverWord,
                regionId: WorldRegionId.soundGarden,
                adventureId: 'adv_sound_garden',
                stepId: 'sg_step_1',
                targetWordIds: ['word_kora'],
                rewardCollectibleId: 'flower_sun_garden',
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('كورة'), findsOneWidget);
        // Explore card first, then tap finish
        await tester.tap(find.text('إنهاء الاستكشاف'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('إنهاء الاستكشاف'));
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          worldCubit.state.worldState.discoveredWordIds,
          contains('word_kora'),
        );
        expect(
          worldCubit.state.worldState.unlockedCollectibleIds,
          contains('flower_sun_garden'),
        );
        expect(
          worldCubit.state.worldState.plantedFlowerIds,
          contains('flower_sun_garden'),
        );
        expect(worldCubit.state.worldState.pronunciationAttempts, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Games 2, 6, 7, 8 execute ZERO AI inference calls and record non-speaking progress cleanly',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        expect(sl.isRegistered<PronunciationRepository>(), isFalse);

        // Game 2 — Hear the Difference
        await tester.pumpWidget(
          _wrapGame(
            worldCubit,
            const HearDifferenceGameView(
              config: ActivityLaunchConfig(
                gameType: MiniGameType.hearDifference,
                regionId: WorldRegionId.soundGarden,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('متشابهتان'), findsOneWidget);
        expect(find.text('مختلفتان'), findsOneWidget);
        await tester.tap(find.text('مختلفتان'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('التالي'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Game 6 — Mystery Sound Boxes
        await tester.pumpWidget(
          _wrapGame(
            worldCubit,
            const MysterySoundBoxesGameView(
              config: ActivityLaunchConfig(
                gameType: MiniGameType.mysterySoundBoxes,
                regionId: WorldRegionId.wordIsland,
                targetWordIds: ['word_kora', 'word_samaka', 'word_batta'],
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byIcon(Icons.card_giftcard_rounded), findsNWidgets(3));
        await tester.tap(find.byIcon(Icons.card_giftcard_rounded).first);
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byIcon(Icons.volume_up_rounded), findsWidgets);
        expect(tester.takeException(), isNull);

        // Game 7 — Sound Detective
        await tester.pumpWidget(
          _wrapGame(
            worldCubit,
            const SoundDetectiveGameView(
              config: ActivityLaunchConfig(
                gameType: MiniGameType.soundDetective,
                regionId: WorldRegionId.animalForest,
                targetPhonemes: ['ك'],
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('كورة'), findsOneWidget);
        await tester.tap(find.text('كورة'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
        expect(tester.takeException(), isNull);

        // Game 8 — Complete the Story
        await tester.pumpWidget(
          _wrapGame(
            worldCubit,
            const CompleteStoryGameView(
              config: ActivityLaunchConfig(
                gameType: MiniGameType.completeTheStory,
                regionId: WorldRegionId.storyCity,
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(GridView), findsOneWidget);
        await tester.tap(find.byType(InkWell).first);
        await tester.pump(const Duration(milliseconds: 350));
        await sl<YasserAudioCoordinator>().setVoiceEnabled(false);
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isNull);

        expect(sl.isRegistered<PronunciationRepository>(), isFalse);
        expect(worldCubit.state.worldState.pronunciationAttempts, 0);
      },
    );

    testWidgets(
      'Game 3 (ListenAndChoose) loads dictionary without AI inference',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        expect(sl.isRegistered<PronunciationRepository>(), isFalse);
        await tester.pumpWidget(
          _wrapGame(
            worldCubit,
            const ListenAndChooseGameView(
              config: ActivityLaunchConfig(
                gameType: MiniGameType.listenAndChoose,
                regionId: WorldRegionId.wordIsland,
                targetWordIds: ['word_kora'],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.textContaining('اسمع الكلمة:'), findsOneWidget);
        expect(find.byType(GridView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
