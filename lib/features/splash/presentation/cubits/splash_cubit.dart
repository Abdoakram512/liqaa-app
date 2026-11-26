import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../authentication/data/models/user_model.dart';
import '../../../authentication/data/repos/auth_repo.dart';
import '../../../onboarding/data/repos/onboarding_repo.dart';
import 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  final OnboardingRepo _onboardingRepo;
  final AuthRepo? _authRepo;
  final Duration _splashDelay;

  SplashCubit(this._onboardingRepo, [this._authRepo, Duration? splashDelay])
    : _splashDelay = splashDelay ?? AppConstants.splashDelay,
      super(const SplashInitial());

  Future<void> initApp() async {
    emit(const SplashAnimating());

    // Coordinate lightweight splash entrance in parallel with local session lookup
    final results = await Future.wait<Object?>([
      Future<void>.delayed(_splashDelay),
      _authRepo != null
          ? _authRepo.getCurrentUser()
          : Future<UserModel?>.value(null),
    ]);

    if (isClosed) return;

    final isCompleted = _onboardingRepo.isOnboardingCompleted();
    if (!isCompleted) {
      emit(const SplashNavigateToOnboarding());
      return;
    }

    final persistedUser = results[1] as UserModel?;
    if (persistedUser != null) {
      if (persistedUser.role == UserRole.specialist) {
        emit(SplashNavigateToSpecialist(persistedUser));
      } else {
        emit(SplashNavigateToChildHome(persistedUser));
      }
      return;
    }

    emit(const SplashNavigateToAuth());
  }
}
