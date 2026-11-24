import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/features/onboarding/data/repos/onboarding_repo.dart';
import 'package:liqaa_app/features/splash/presentation/cubits/splash_cubit.dart';
import 'package:liqaa_app/features/splash/presentation/cubits/splash_state.dart';
import 'package:mocktail/mocktail.dart';

class MockOnboardingRepo extends Mock implements OnboardingRepo {}

void main() {
  late MockOnboardingRepo mockRepo;

  setUp(() {
    mockRepo = MockOnboardingRepo();
  });

  group('SplashCubit Navigation Flow Tests', () {
    test('routes to Onboarding on first launch', () async {
      when(() => mockRepo.isOnboardingCompleted()).thenReturn(false);
      final cubit = SplashCubit(mockRepo);

      expect(cubit.state, const SplashInitial());

      final future = cubit.initApp();
      expect(cubit.state, const SplashAnimating());

      await future;
      expect(cubit.state, const SplashNavigateToOnboarding());
    });

    test(
      'routes to Auth for returning user who completed onboarding',
      () async {
        when(() => mockRepo.isOnboardingCompleted()).thenReturn(true);
        final cubit = SplashCubit(mockRepo);

        expect(cubit.state, const SplashInitial());

        final future = cubit.initApp();
        expect(cubit.state, const SplashAnimating());

        await future;
        expect(cubit.state, const SplashNavigateToAuth());
      },
    );
  });
}
