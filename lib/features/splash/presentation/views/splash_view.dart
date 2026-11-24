import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../cubits/splash_cubit.dart';
import '../cubits/splash_state.dart';
import '../widgets/splash_content.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SplashCubit>()..initApp(),
      child: BlocListener<SplashCubit, SplashState>(
        listener: (context, state) {
          if (state is SplashNavigateToOnboarding) {
            context.go(AppRoutes.onboarding);
          } else if (state is SplashNavigateToAuth) {
            context.go(AppRoutes.auth);
          }
        },
        child: const Scaffold(
          body: PhonologicalBackground(child: SafeArea(child: SplashContent())),
        ),
      ),
    );
  }
}
