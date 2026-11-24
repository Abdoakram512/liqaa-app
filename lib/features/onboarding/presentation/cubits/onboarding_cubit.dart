import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repos/onboarding_repo.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingRepo _onboardingRepo;

  OnboardingCubit(this._onboardingRepo)
    : super(OnboardingState(items: _onboardingRepo.getOnboardingPages()));

  void onPageChanged(int index) {
    if (index >= 0 && index < state.totalPages) {
      emit(state.copyWith(currentIndex: index));
    }
  }

  void nextPage() {
    if (state.isLastPage) {
      completeOnboarding();
    } else {
      emit(state.copyWith(currentIndex: state.currentIndex + 1));
    }
  }

  void previousPage() {
    if (!state.isFirstPage) {
      emit(state.copyWith(currentIndex: state.currentIndex - 1));
    }
  }

  Future<void> skipOnboarding() async {
    await completeOnboarding();
  }

  Future<void> completeOnboarding() async {
    await _onboardingRepo.completeOnboarding();
    emit(state.copyWith(isCompleted: true));
  }
}
