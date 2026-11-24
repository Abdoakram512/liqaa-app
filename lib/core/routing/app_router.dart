import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/views/auth_placeholder_view.dart';
import '../../features/onboarding/presentation/views/onboarding_view.dart';
import '../../features/splash/presentation/views/splash_view.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingView(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthPlaceholderView(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
    ],
  );
}
