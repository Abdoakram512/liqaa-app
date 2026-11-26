import 'package:flutter_test/flutter_test.dart';
import 'package:liqaa_app/features/authentication/data/models/user_model.dart';
import 'package:liqaa_app/features/authentication/data/repos/auth_repo.dart';
import 'package:liqaa_app/features/onboarding/data/repos/onboarding_repo.dart';
import 'package:liqaa_app/features/splash/presentation/cubits/splash_cubit.dart';
import 'package:liqaa_app/features/splash/presentation/cubits/splash_state.dart';
import 'package:mocktail/mocktail.dart';

class MockOnboardingRepo extends Mock implements OnboardingRepo {}

class MockAuthRepo extends Mock implements AuthRepo {}

void main() {
  late MockOnboardingRepo mockOnboardingRepo;
  late MockAuthRepo mockAuthRepo;

  setUp(() {
    mockOnboardingRepo = MockOnboardingRepo();
    mockAuthRepo = MockAuthRepo();
  });

  group('SplashCubit Role-Aware Navigation Tests', () {
    test('routes to Onboarding on first launch', () async {
      when(() => mockOnboardingRepo.isOnboardingCompleted()).thenReturn(false);
      when(() => mockAuthRepo.getCurrentUser()).thenAnswer((_) async => null);
      final cubit = SplashCubit(
        mockOnboardingRepo,
        mockAuthRepo,
        const Duration(milliseconds: 10),
      );
      addTearDown(cubit.close);

      expect(cubit.state, const SplashInitial());
      final future = cubit.initApp();
      expect(cubit.state, const SplashAnimating());

      await future;
      expect(cubit.state, const SplashNavigateToOnboarding());
    });

    test(
      'routes to Auth when onboarding completed and no active session',
      () async {
        when(() => mockOnboardingRepo.isOnboardingCompleted()).thenReturn(true);
        when(() => mockAuthRepo.getCurrentUser()).thenAnswer((_) async => null);
        final cubit = SplashCubit(
          mockOnboardingRepo,
          mockAuthRepo,
          const Duration(milliseconds: 10),
        );
        addTearDown(cubit.close);

        await cubit.initApp();
        expect(cubit.state, const SplashNavigateToAuth());
      },
    );

    test(
      'routes directly to Child Home when child session is persisted',
      () async {
        final childUser = UserModel(
          id: 'u1',
          name: 'آدم',
          email: 'adam@liqaa.app',
          role: UserRole.child,
          createdAt: DateTime(2026, 11, 26),
        );
        when(() => mockOnboardingRepo.isOnboardingCompleted()).thenReturn(true);
        when(
          () => mockAuthRepo.getCurrentUser(),
        ).thenAnswer((_) async => childUser);
        final cubit = SplashCubit(
          mockOnboardingRepo,
          mockAuthRepo,
          const Duration(milliseconds: 10),
        );
        addTearDown(cubit.close);

        await cubit.initApp();
        expect(cubit.state, SplashNavigateToChildHome(childUser));
      },
    );

    test(
      'routes directly to Specialist Dashboard when specialist session is persisted',
      () async {
        final specialist = UserModel(
          id: 's1',
          name: 'د. نورهان',
          email: 'nourhan@clinic.eg',
          role: UserRole.specialist,
          organization: 'مركز بيان للتخاطب',
          createdAt: DateTime(2026, 11, 26),
        );
        when(() => mockOnboardingRepo.isOnboardingCompleted()).thenReturn(true);
        when(
          () => mockAuthRepo.getCurrentUser(),
        ).thenAnswer((_) async => specialist);
        final cubit = SplashCubit(
          mockOnboardingRepo,
          mockAuthRepo,
          const Duration(milliseconds: 10),
        );
        addTearDown(cubit.close);

        await cubit.initApp();
        expect(cubit.state, SplashNavigateToSpecialist(specialist));
      },
    );
  });
}
