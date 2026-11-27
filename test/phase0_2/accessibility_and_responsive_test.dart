import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/app/dependency_injection/service_locator.dart';
import 'package:liqaa_app/core/ai/models/phoneme_token.dart';
import 'package:liqaa_app/core/ai/models/pronunciation_assessment.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/animation/yasser/yasser_interaction_engine.dart';
import 'package:liqaa_app/core/audio/yasser_audio_coordinator.dart';
import 'package:liqaa_app/core/theme/app_theme.dart';
import 'package:liqaa_app/core/widgets/yasser_avatar.dart';
import 'package:liqaa_app/core/widgets/yasser_character.dart';
import 'package:liqaa_app/features/specialist/data/repos/specialist_repository.dart';
import 'package:liqaa_app/features/specialist/presentation/cubits/specialist_cubit.dart';
import 'package:liqaa_app/features/specialist/presentation/views/case_detail_view.dart';
import 'package:liqaa_app/features/world/data/child_world_repository.dart';
import 'package:liqaa_app/features/world/presentation/cubits/child_world_cubit.dart';
import 'package:liqaa_app/features/world/presentation/views/adventure_book_view.dart';
import 'package:liqaa_app/features/world/presentation/views/mini_games_hub_view.dart';
import 'package:liqaa_app/features/world/presentation/views/my_personal_home_view.dart';
import 'package:liqaa_app/features/world/presentation/views/profile_setup_view.dart';
import 'package:liqaa_app/features/world/presentation/views/world_map_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpResponsive(
  WidgetTester tester,
  Size surfaceSize,
  ChildWorldCubit worldCubit,
  Widget child, {
  SpecialistCubit? specialistCubit,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = surfaceSize;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (_, inner) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
              disableAnimations: disableAnimations,
            ),
            child: inner!,
          ),
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ChildWorldCubit>.value(value: worldCubit),
            if (specialistCubit != null)
              BlocProvider<SpecialistCubit>.value(value: specialistCubit),
          ],
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChildWorldCubit worldCubit;
  late SpecialistCubit specialistCubit;
  late YasserAudioCoordinator audioCoordinator;

  setUp(() async {
    await sl.reset();
    sl.allowReassignment = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    audioCoordinator = YasserAudioCoordinator(
      enablePlatformAudio: false,
      observeAppLifecycle: false,
    );
    await audioCoordinator.setVoiceEnabled(false);
    await audioCoordinator.setSfxEnabled(false);
    sl.registerSingleton<YasserAudioCoordinator>(audioCoordinator);

    worldCubit = ChildWorldCubit(ChildWorldRepository(prefs));
    sl.registerSingleton<ChildWorldCubit>(worldCubit);

    specialistCubit = SpecialistCubit(SpecialistLocalRepository(prefs));
    await specialistCubit.loadWorkspace();
    sl.registerSingleton<SpecialistCubit>(specialistCubit);

    YasserCharacter.enableRiveRuntime = false;
    YasserAvatar.enableRepeatingAnimations = false;
    YasserInteractionEngine.enableBlinkTimer = false;
  });

  tearDown(() async {
    YasserCharacter.enableRiveRuntime = true;
    YasserAvatar.enableRepeatingAnimations = true;
    YasserInteractionEngine.enableBlinkTimer = true;
    await worldCubit.close();
    await specialistCubit.close();
    await audioCoordinator.dispose();
    await sl.reset();
  });

  group('Phase 0.2 Responsive, Accessibility & Specialist UI', () {
    const viewports = [
      Size(360, 640), // Compact Android phone
      Size(390, 844), // Standard phone
      Size(834, 1194), // Tablet
    ];

    testWidgets(
      'MyPersonalHomeView, WorldMapView, MiniGamesHubView, AdventureBookView, and ProfileSetupView render without overflow across phones & tablets with animations disabled and audio muted',
      (tester) async {
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        for (final size in viewports) {
          await _pumpResponsive(
            tester,
            size,
            worldCubit,
            MyPersonalHomeView(onOpenMap: () {}, onOpenGames: () {}),
            disableAnimations: true,
          );
          expect(tester.takeException(), isNull);

          await _pumpResponsive(
            tester,
            size,
            worldCubit,
            const WorldMapView(),
            disableAnimations: true,
          );
          expect(tester.takeException(), isNull);

          // Toggle Accessible List Mode on WorldMapView
          await tester.tap(find.text('قائمة'));
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.text('حديقة الأصوات'), findsWidgets);
          await tester.dragUntilVisible(
            find.text('قلعة الأبطال'),
            find.byType(ListView),
            const Offset(0, -200),
          );
          expect(find.text('قلعة الأبطال'), findsWidgets);
          expect(tester.takeException(), isNull);

          await _pumpResponsive(
            tester,
            size,
            worldCubit,
            const MiniGamesHubView(),
            disableAnimations: true,
          );
          expect(find.text('ألعاب الأصوات الثمانية'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await _pumpResponsive(
            tester,
            size,
            worldCubit,
            const AdventureBookView(),
            disableAnimations: true,
          );
          expect(tester.takeException(), isNull);

          await _pumpResponsive(
            tester,
            size,
            worldCubit,
            const ProfileSetupView(),
            disableAnimations: true,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'CaseDetailView separates scored vs inconclusive attempts and creates persistent specialist adventure assignments',
      (tester) async {
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final created = await specialistCubit.createCase(
          childName: 'يوسف كريم',
          ageYears: 6,
          targetPhonemes: const ['س', 'ر'],
        );
        final session = await specialistCubit.startGuidedSession(
          caseId: created.id,
        );
        const word = VocabularyWord(
          id: 'word_samaka',
          wordArabic: 'سمكة',
          wordTransliteration: 'Samaka',
          meaningEn: 'Fish',
          targetPhoneme: 'س',
          targetPhonemeIpa: 's',
          phonemeCategory: 'fricatives',
          expectedPhonemes: ['s', 'a', 'm', 'a', 'k', 'a'],
          expectedArabicPhonemes: ['س', 'م', 'ك'],
          difficultyLevel: 1,
          yasserTip: 'ابتسم بلطف وقل سسس!',
        );

        await specialistCubit.recordEvaluatedAttempt(
          caseId: created.id,
          sessionId: session.id,
          word: word,
          assessment: const PronunciationAssessment(
            targetWord: 'Samaka',
            targetWordArabic: 'سمكة',
            recognizedTranscript: '',
            overallScore: 0,
            stars: 0,
            errorType: AssessmentErrorType.noSpeech,
            alignments: [],
            recognizedPhonemes: [],
            yasserFeedbackMessage: 'لم نلتقط صوتاً',
            passed: false,
          ),
        );
        await specialistCubit.recordEvaluatedAttempt(
          caseId: created.id,
          sessionId: session.id,
          word: word,
          assessment: const PronunciationAssessment(
            targetWord: 'Samaka',
            targetWordArabic: 'سمكة',
            recognizedTranscript: 'samaka',
            overallScore: 90,
            stars: 3,
            errorType: AssessmentErrorType.correct,
            alignments: [],
            recognizedPhonemes: [
              PhonemeToken(
                symbol: 's',
                arabicSymbol: 'س',
                confidence: 0.95,
                startFrame: 0,
                endFrame: 4,
              ),
            ],
            yasserFeedbackMessage: 'رائع',
            passed: true,
          ),
        );

        await _pumpResponsive(
          tester,
          const Size(412, 915),
          worldCubit,
          CaseDetailView(caseId: created.id),
          specialistCubit: specialistCubit,
        );

        await tester.dragUntilVisible(
          find.text('ملخص الأداء المفصّل'),
          find.byType(CustomScrollView),
          const Offset(0, -300),
        );
        expect(find.text('ملخص الأداء المفصّل'), findsOneWidget);

        await tester.dragUntilVisible(
          find.text('تعيين مغامرة مخصصة للطفل'),
          find.byType(CustomScrollView),
          const Offset(0, -300),
        );
        expect(find.text('تخصيص مسار المغامرة (الأخصائي)'), findsOneWidget);

        await tester.tap(find.text('تعيين مغامرة مخصصة للطفل'));
        await tester.pump(const Duration(milliseconds: 250));

        expect(specialistCubit.state.assignmentsForCase(created.id).length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
