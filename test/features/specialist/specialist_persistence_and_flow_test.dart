import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/models/phoneme_token.dart';
import 'package:liqaa_app/core/ai/models/pronunciation_assessment.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/theme/app_theme.dart';
import 'package:liqaa_app/features/specialist/data/models/specialist_models.dart';
import 'package:liqaa_app/features/specialist/data/repos/specialist_repository.dart';
import 'package:liqaa_app/features/specialist/presentation/cubits/specialist_cubit.dart';
import 'package:liqaa_app/features/specialist/presentation/views/case_detail_view.dart';
import 'package:liqaa_app/features/specialist/presentation/views/specialist_dashboard_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sampleWord = VocabularyWord(
    id: 'word_samaka',
    wordArabic: 'سمكة',
    wordTransliteration: 'Samaka',
    meaningEn: 'Fish',
    targetPhoneme: 'س',
    targetPhonemeIpa: 's',
    phonemeCategory: 'fricatives',
    difficultyLevel: 1,
    expectedPhonemes: ['s', 'a', 'm', 'a', 'k', 'a'],
    expectedArabicPhonemes: ['س', 'م', 'ك', 'ة'],
    yasserTip: 'ابتسم بلطف لخروج صوت السين',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Specialist Persistence, Case Isolation & Honest Metrics', () {
    test(
      'starts empty, isolates attempts per case, ignores system failures, and survives restart',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo1 = SpecialistLocalRepository(prefs);
        final cubit1 = SpecialistCubit(repo1);

        await cubit1.loadWorkspace();
        expect(cubit1.state.allCases, isEmpty);
        expect(cubit1.state.allSessions, isEmpty);
        expect(cubit1.state.allAttempts, isEmpty);

        // Create two independent child cases
        final caseA = await cubit1.createCase(
          childName: 'يوسف محمود',
          ageYears: 6,
          guardianPhone: '01099887766',
          targetPhonemes: const ['س', 'ر'],
          clinicalNotes: 'يحتاج لتدريب تدريجي على صوت السين في أول الكلمة.',
        );
        final caseB = await cubit1.createCase(
          childName: 'ليلى حسن',
          ageYears: 5,
          targetPhonemes: const ['ك'],
        );

        // Newly created case has null average indicator (zero fabricated scores)
        expect(
          cubit1.state.summaryForCase(caseA.id).averageScoreIndicator,
          isNull,
        );

        final sessionA = await cubit1.startGuidedSession(caseId: caseA.id);

        // 1. Hardware/model failure must NEVER be recorded into clinical attempt history
        await cubit1.recordEvaluatedAttempt(
          caseId: caseA.id,
          sessionId: sessionA.id,
          word: sampleWord,
          assessment: const PronunciationAssessment(
            targetWord: 'Samaka',
            targetWordArabic: 'سمكة',
            recognizedTranscript: '',
            overallScore: 0,
            stars: 0,
            errorType: AssessmentErrorType.inferenceFailed,
            alignments: [],
            recognizedPhonemes: [],
            yasserFeedbackMessage: 'Error',
            passed: false,
          ),
        );
        expect(cubit1.state.attemptsForCase(caseA.id), isEmpty);

        // 2. Silence attempt is logged honestly with null scoreIndicator
        await cubit1.recordEvaluatedAttempt(
          caseId: caseA.id,
          sessionId: sessionA.id,
          word: sampleWord,
          assessment: const PronunciationAssessment(
            targetWord: 'Samaka',
            targetWordArabic: 'سمكة',
            recognizedTranscript: '',
            overallScore: 0,
            stars: 0,
            errorType: AssessmentErrorType.noSpeech,
            alignments: [],
            recognizedPhonemes: [],
            yasserFeedbackMessage: 'Silence',
            passed: false,
          ),
        );
        expect(cubit1.state.attemptsForCase(caseA.id).length, equals(1));
        expect(
          cubit1.state.summaryForCase(caseA.id).averageScoreIndicator,
          isNull,
        );

        // 3. Genuine scored pronunciation attempt updates trajectory for caseA only
        await cubit1.recordEvaluatedAttempt(
          caseId: caseA.id,
          sessionId: sessionA.id,
          word: sampleWord,
          assessment: const PronunciationAssessment(
            targetWord: 'Samaka',
            targetWordArabic: 'سمكة',
            recognizedTranscript: 'samaka',
            overallScore: 88.0,
            stars: 3,
            errorType: AssessmentErrorType.correct,
            alignments: [],
            recognizedPhonemes: [
              PhonemeToken(
                symbol: 's',
                arabicSymbol: 'س',
                confidence: 0.94,
                startFrame: 0,
                endFrame: 5,
              ),
            ],
            yasserFeedbackMessage: 'Bravo',
            passed: true,
          ),
        );

        expect(cubit1.state.attemptsForCase(caseA.id).length, equals(2));
        expect(cubit1.state.attemptsForCase(caseB.id), isEmpty);
        expect(
          cubit1.state.summaryForCase(caseA.id).averageScoreIndicator,
          equals(88.0),
        );
        await cubit1.close();

        // Simulate full app restart by instantiating fresh Repository & Cubit
        final repo2 = SpecialistLocalRepository(prefs);
        final cubit2 = SpecialistCubit(repo2);
        await cubit2.loadWorkspace();

        expect(cubit2.state.allCases.length, equals(2));
        expect(cubit2.state.sessionsForCase(caseA.id).length, equals(1));
        expect(cubit2.state.attemptsForCase(caseA.id).length, equals(2));
        expect(cubit2.state.notesForCase(caseA.id).length, equals(1));
        expect(
          cubit2.state.summaryForCase(caseA.id).averageScoreIndicator,
          equals(88.0),
        );

        // Search filter works
        cubit2.setSearchQuery('ليلى');
        expect(cubit2.state.filteredCases.length, equals(1));
        expect(cubit2.state.filteredCases.first.id, equals(caseB.id));
        await cubit2.close();
      },
    );

    testWidgets(
      'SpecialistDashboardView and CaseDetailView render persisted cases, chart, and disclaimer',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(412, 915);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final prefs = await SharedPreferences.getInstance();
        final repo = SpecialistLocalRepository(prefs);
        final cubit = SpecialistCubit(repo);
        addTearDown(cubit.close);

        final created = await cubit.createCase(
          childName: 'فريدة طارق',
          ageYears: 7,
          targetPhonemes: const ['ر', 'س'],
          clinicalNotes: 'متابعة أسبوعية لمخارج الراء.',
          status: CaseStatus.active,
        );
        final session = await cubit.startGuidedSession(caseId: created.id);
        await cubit.recordEvaluatedAttempt(
          caseId: created.id,
          sessionId: session.id,
          word: sampleWord,
          assessment: const PronunciationAssessment(
            targetWord: 'Samaka',
            targetWordArabic: 'سمكة',
            recognizedTranscript: 'samaka',
            overallScore: 92.0,
            stars: 3,
            errorType: AssessmentErrorType.correct,
            alignments: [],
            recognizedPhonemes: [
              PhonemeToken(
                symbol: 's',
                arabicSymbol: 'س',
                confidence: 0.96,
                startFrame: 0,
                endFrame: 5,
              ),
            ],
            yasserFeedbackMessage: 'ممتاز',
            passed: true,
          ),
        );

        // 1. Render Specialist Dashboard
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              ),
              home: BlocProvider<SpecialistCubit>.value(
                value: cubit,
                child: const SpecialistDashboardView(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('فريدة طارق'), findsOneWidget);
        expect(find.textContaining('تشخيصاً طبياً'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Render Case Detail View with real Progress Chart & Attempt History
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              ),
              home: BlocProvider<SpecialistCubit>.value(
                value: cubit,
                child: CaseDetailView(caseId: created.id),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('فريدة طارق'), findsOneWidget);
        expect(find.text('بدء جلسة تدريب نطق موجهة'), findsOneWidget);
        expect(find.textContaining('سمكة'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
