import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/features/onboarding/data/repos/onboarding_repo.dart';
import 'package:liqaa_app/features/onboarding/data/src/onboarding_local_data_source.dart';
import 'package:liqaa_app/features/onboarding/presentation/cubits/onboarding_cubit.dart';
import 'package:liqaa_app/features/onboarding/presentation/cubits/onboarding_state.dart';
import 'package:mocktail/mocktail.dart';

class MockOnboardingRepo extends Mock implements OnboardingRepo {}
class MockLocalDataSource extends Mock implements OnboardingLocalDataSource {}

void main() {
  late MockOnboardingRepo mockRepo;

  setUp(() {
    mockRepo = MockOnboardingRepo();
    when(() => mockRepo.getOnboardingPages()).thenReturn(
      OnboardingRepo(MockLocalDataSource()).getOnboardingPages(),
    );
  });

  group('OnboardingCubit Tests', () {
    test('initial state starts at index 0 with 3 items', () {
      final cubit = OnboardingCubit(mockRepo);
      expect(cubit.state.currentIndex, 0);
      expect(cubit.state.totalPages, 3);
      expect(cubit.state.isFirstPage, true);
      expect(cubit.state.isLastPage, false);
      expect(cubit.state.isCompleted, false);
    });

    blocTest<OnboardingCubit, OnboardingState>(
      'nextPage increments currentIndex when not on last page',
      build: () => OnboardingCubit(mockRepo),
      act: (cubit) => cubit.nextPage(),
      expect: () => [
        isA<OnboardingState>()
            .having((s) => s.currentIndex, 'currentIndex', 1)
            .having((s) => s.isFirstPage, 'isFirstPage', false),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'previousPage decrements currentIndex',
      build: () => OnboardingCubit(mockRepo),
      seed: () => OnboardingCubit(mockRepo).state.copyWith(currentIndex: 2),
      act: (cubit) => cubit.previousPage(),
      expect: () => [
        isA<OnboardingState>().having((s) => s.currentIndex, 'currentIndex', 1),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'completeOnboarding calls repo and emits isCompleted = true',
      build: () {
        when(() => mockRepo.completeOnboarding()).thenAnswer((_) async => true);
        return OnboardingCubit(mockRepo);
      },
      act: (cubit) => cubit.completeOnboarding(),
      expect: () => [
        isA<OnboardingState>().having((s) => s.isCompleted, 'isCompleted', true),
      ],
      verify: (_) {
        verify(() => mockRepo.completeOnboarding()).called(1);
      },
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'skipOnboarding calls repo and completes',
      build: () {
        when(() => mockRepo.completeOnboarding()).thenAnswer((_) async => true);
        return OnboardingCubit(mockRepo);
      },
      act: (cubit) => cubit.skipOnboarding(),
      expect: () => [
        isA<OnboardingState>().having((s) => s.isCompleted, 'isCompleted', true),
      ],
      verify: (_) {
        verify(() => mockRepo.completeOnboarding()).called(1);
      },
    );
  });
}
