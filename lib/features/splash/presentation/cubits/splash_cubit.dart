import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../onboarding/data/repos/onboarding_repo.dart';
import 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  final OnboardingRepo _onboardingRepo;

  SplashCubit(this._onboardingRepo) : super(const SplashInitial());

  Future<void> initApp() async {
    emit(const SplashAnimating());

    // Wait for the animated splash choreography to complete
    await Future.delayed(AppConstants.splashDelay);

    final isCompleted = _onboardingRepo.isOnboardingCompleted();
    if (isCompleted) {
      emit(const SplashNavigateToAuth());
    } else {
      emit(const SplashNavigateToOnboarding());
    }
  }
}
