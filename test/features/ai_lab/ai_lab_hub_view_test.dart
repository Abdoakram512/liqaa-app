import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/core/ai/models/ai_model_info.dart';
import 'package:liqaa_app/core/ai/models/vocabulary_word.dart';
import 'package:liqaa_app/core/theme/app_theme.dart';
import 'package:liqaa_app/features/ai_lab/cubits/ai_lab_cubit.dart';
import 'package:liqaa_app/features/ai_lab/cubits/ai_lab_state.dart';
import 'package:liqaa_app/features/ai_lab/views/ai_lab_hub_view.dart';
import 'package:mocktail/mocktail.dart';

class MockAiLabCubit extends MockCubit<AiLabState> implements AiLabCubit {}

void main() {
  late MockAiLabCubit mockCubit;

  setUp(() {
    mockCubit = MockAiLabCubit();
  });

  testWidgets('AiLabHubView renders in ready state', (tester) async {
    when(() => mockCubit.initializeLab()).thenAnswer((_) async {});
    when(() => mockCubit.state).thenReturn(
      const AiLabState(
        status: AiLabStatus.ready,
        models: [
          AiModelInfo(
            key: 'silero_vad',
            name: 'Silero VAD',
            description: 'VAD model',
            format: 'ONNX',
            sampleRate: 16000,
            sizeMb: 2.1,
            license: 'MIT',
            status: 'ready',
          ),
        ],
        vocabulary: [
          VocabularyWord(
            id: 'word_kora',
            wordArabic: 'كورة',
            wordTransliteration: 'Koora',
            meaningEn: 'Ball',
            targetPhoneme: 'ك',
            targetPhonemeIpa: 'k',
            phonemeCategory: 'Plosive',
            difficultyLevel: 1,
            expectedPhonemes: ['k', 'uː', 'r', 'a'],
            expectedArabicPhonemes: ['ك', 'و', 'ر', 'ة'],
            yasserTip: 'Tip',
            commonChildErrors: [],
          ),
        ],
        totalRamUsageMb: 28.5,
      ),
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<AiLabCubit>.value(
            value: mockCubit,
            child: const AiLabHubView(),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(AiLabHubView), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Hit test by tapping on the screen
    await tester.tap(find.byType(SingleChildScrollView));
    await tester.pump();
  });
}
