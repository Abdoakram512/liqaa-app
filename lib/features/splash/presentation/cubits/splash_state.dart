import 'package:equatable/equatable.dart';

abstract class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

class SplashInitial extends SplashState {
  const SplashInitial();
}

class SplashAnimating extends SplashState {
  const SplashAnimating();
}

class SplashNavigateToOnboarding extends SplashState {
  const SplashNavigateToOnboarding();
}

class SplashNavigateToAuth extends SplashState {
  const SplashNavigateToAuth();
}
