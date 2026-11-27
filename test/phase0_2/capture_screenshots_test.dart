import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/app/dependency_injection/service_locator.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';
import 'package:liqaa_app/core/audio/yasser_audio_coordinator.dart';
import 'package:liqaa_app/core/theme/app_theme.dart';
import 'package:liqaa_app/core/widgets/yasser_avatar.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';
import 'package:liqaa_app/features/activities/presentation/views/discover_word_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/views/mystery_sound_boxes_game_view.dart';
import 'package:liqaa_app/features/activities/presentation/widgets/activity_session_scaffold.dart';
import 'package:liqaa_app/features/onboarding/presentation/views/onboarding_view.dart';
import 'package:liqaa_app/features/specialist/data/models/specialist_models.dart';
import 'package:liqaa_app/features/specialist/presentation/cubits/specialist_cubit.dart';
import 'package:liqaa_app/features/specialist/presentation/views/case_detail_view.dart';
import 'package:liqaa_app/features/splash/presentation/widgets/splash_content.dart';
import 'package:liqaa_app/features/world/data/models/world_models.dart';
import 'package:liqaa_app/features/world/presentation/cubits/child_world_cubit.dart';
import 'package:liqaa_app/features/world/presentation/views/adventure_book_view.dart';
import 'package:liqaa_app/features/world/presentation/views/adventure_detail_view.dart';
import 'package:liqaa_app/features/world/presentation/views/mini_games_hub_view.dart';
import 'package:liqaa_app/features/world/presentation/views/my_personal_home_view.dart';
import 'package:liqaa_app/features/world/presentation/views/profile_setup_view.dart';
import 'package:liqaa_app/features/world/presentation/views/world_map_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadBundledFonts() async {
  Future<ByteData> loadFile(String path) async {
    final bytes = File(path).readAsBytesSync();
    return ByteData.sublistView(bytes);
  }

  final balooLoader = FontLoader('BalooBhaijaan2')
    ..addFont(loadFile('assets/fonts/BalooBhaijaan2.ttf'));
  await balooLoader.load();

  final tajawalLoader = FontLoader('Tajawal')
    ..addFont(loadFile('assets/fonts/Tajawal-Regular.ttf'))
    ..addFont(loadFile('assets/fonts/Tajawal-Medium.ttf'))
    ..addFont(loadFile('assets/fonts/Tajawal-Bold.ttf'));
  await tajawalLoader.load();

  // Best-effort local MaterialIcons load so screenshots render crisp vector icons
  const candidates = [
    r'E:\Flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    r'C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')..addFont(loadFile(path));
      await iconLoader.load();
      break;
    }
  }
}

Future<void> _captureAfterScreen({
  required WidgetTester tester,
  required String outputPath,
  required Widget child,
  ChildWorldCubit? worldCubit,
  SpecialistCubit? specialistCubit,
}) async {
  final sw = Stopwatch()..start();
  final boundaryKey = GlobalKey();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (_, inner) =>
            Directionality(textDirection: ui.TextDirection.rtl, child: inner!),
        home: () {
          final providers = [
            if (worldCubit != null)
              BlocProvider<ChildWorldCubit>.value(value: worldCubit),
            if (specialistCubit != null)
              BlocProvider<SpecialistCubit>.value(value: specialistCubit),
          ];
          final content = RepaintBoundary(key: boundaryKey, child: child);
          return providers.isEmpty
              ? content
              : MultiBlocProvider(providers: providers, child: content);
        }(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 250));

  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final file = File(outputPath);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(byteData.buffer.asUint8List());
    }
  });
  sw.stop();
  debugPrint(
    '[Phase 0.2 Screenshot] $outputPath captured in ${sw.elapsedMilliseconds}ms',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadBundledFonts();
    await sl.reset();
    sl.allowReassignment = true;
    await setupServiceLocator();
    sl.registerLazySingleton<YasserAudioCoordinator>(
      () => YasserAudioCoordinator(
        enablePlatformAudio: false,
        observeAppLifecycle: false,
      ),
    );
    YasserCharacter.enableRiveRuntime = false;
    YasserAvatar.enableRepeatingAnimations = false;
    YasserInteractionEngine.enableBlinkTimer = false;
  });

  tearDownAll(() async {
    YasserCharacter.enableRiveRuntime = true;
    YasserAvatar.enableRepeatingAnimations = true;
    YasserInteractionEngine.enableBlinkTimer = true;
    await sl.reset();
  });

  testWidgets(
    'Capture Phase 0.2 redesigned After screenshots with bundled Arabic fonts',
    (tester) async {
      const outDir = 'benchmarks/phase0/reports/phase0_2_screenshots/after';
      final worldCubit = sl<ChildWorldCubit>();
      await worldCubit.updateActiveProfile(displayName: 'بطل');
      await worldCubit.unlockAndPlantCollectible('flower_sun_garden');
      await worldCubit.markWordDiscovered('word_kora');
      await worldCubit.markWordDiscovered('word_samaka');
      await worldCubit.markWordDiscovered('word_batta');

      final specialistCubit = sl<SpecialistCubit>();
      await specialistCubit.loadWorkspace();
      final sampleCase = await specialistCubit.createCase(
        childName: 'عمر طارق',
        ageYears: 6,
        targetPhonemes: const ['س', 'ر'],
        clinicalNotes: 'تركيز على تمييز السين والراء عبر حديقة الأصوات.',
        status: CaseStatus.active,
      );
      await specialistCubit.assignPersonalizedAdventure(
        caseId: sampleCase.id,
        childProfileId: worldCubit.state.activeProfileId,
        title: 'مغامرة حديقة الأصوات',
        targetPhonemes: const ['س', 'ر'],
        assignedRegionId: 'sound_garden',
      );

      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/01_splash_after.png',
        child: const Scaffold(body: SafeArea(child: SplashContent())),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/02_onboarding_after.png',
        child: const OnboardingView(),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/03_my_home_after.png',
        worldCubit: worldCubit,
        specialistCubit: specialistCubit,
        child: Scaffold(
          body: MyPersonalHomeView(onOpenMap: () {}, onOpenGames: () {}),
        ),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/04_world_map_after.png',
        worldCubit: worldCubit,
        child: const Scaffold(body: WorldMapView()),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/05_garden_adventure_after.png',
        worldCubit: worldCubit,
        child: const AdventureDetailView(regionId: WorldRegionId.soundGarden),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/06_mini_games_hub_after.png',
        worldCubit: worldCubit,
        specialistCubit: specialistCubit,
        child: const Scaffold(body: MiniGamesHubView()),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/07_adventure_book_after.png',
        worldCubit: worldCubit,
        child: const Scaffold(body: AdventureBookView()),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/08_discover_word_game.png',
        worldCubit: worldCubit,
        child: const DiscoverWordGameView(
          config: ActivityLaunchConfig(
            gameType: MiniGameType.discoverWord,
            regionId: WorldRegionId.soundGarden,
            targetWordIds: ['word_kora', 'word_samaka'],
          ),
        ),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/09_mystery_boxes_game.png',
        worldCubit: worldCubit,
        child: const MysterySoundBoxesGameView(
          config: ActivityLaunchConfig(
            gameType: MiniGameType.mysterySoundBoxes,
            regionId: WorldRegionId.wordIsland,
            targetWordIds: ['word_kora', 'word_samaka', 'word_batta'],
          ),
        ),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/10_profile_setup.png',
        worldCubit: worldCubit,
        child: const ProfileSetupView(),
      );
      await _captureAfterScreen(
        tester: tester,
        outputPath: '$outDir/11_specialist_case_detail.png',
        worldCubit: worldCubit,
        specialistCubit: specialistCubit,
        child: CaseDetailView(caseId: sampleCase.id),
      );

      expect(File('$outDir/03_my_home_after.png').existsSync(), isTrue);
      expect(
        File('$outDir/11_specialist_case_detail.png').existsSync(),
        isTrue,
      );
    },
  );
}
