import 'package:equatable/equatable.dart';
import '../../../authentication/data/models/user_model.dart';

sealed class SplashState extends Equatable {
  const SplashState();

  @override
  List<Object?> get props => [];
}

final class SplashInitial extends SplashState {
  const SplashInitial();
}

final class SplashAnimating extends SplashState {
  const SplashAnimating();
}

final class SplashNavigateToOnboarding extends SplashState {
  const SplashNavigateToOnboarding();
}

final class SplashNavigateToAuth extends SplashState {
  const SplashNavigateToAuth();
}

final class SplashNavigateToChildHome extends SplashState {
  final UserModel user;
  const SplashNavigateToChildHome(this.user);

  @override
  List<Object?> get props => [user];
}

final class SplashNavigateToSpecialist extends SplashState {
  final UserModel user;
  const SplashNavigateToSpecialist(this.user);

  @override
  List<Object?> get props => [user];
}
