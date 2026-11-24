import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependency_injection/service_locator.dart';
import '../../features/ai_lab/cubits/ai_lab_cubit.dart';
import '../../features/ai_lab/views/ai_lab_hub_view.dart';
import '../../features/ai_lab/views/model_manager_view.dart';
import '../../features/ai_lab/views/mic_vad_view.dart';
import '../../features/ai_lab/views/noise_reduction_view.dart';
import '../../features/ai_lab/views/phoneme_recognition_view.dart';
import '../../features/ai_lab/views/speech_to_text_view.dart';
import '../../features/ai_lab/views/model_comparison_view.dart';
import '../../features/ai_lab/views/full_pipeline_view.dart';
import '../../features/authentication/presentation/views/auth_placeholder_view.dart';
import '../../features/onboarding/presentation/views/onboarding_view.dart';
import '../../features/pronunciation_game/cubits/pronunciation_game_cubit.dart';
import '../../features/pronunciation_game/views/pronunciation_game_view.dart';
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
      // Speak With Yasser Game
      GoRoute(
        path: AppRoutes.game,
        name: 'game',
        builder: (context, state) => BlocProvider<PronunciationGameCubit>(
          create: (_) => sl<PronunciationGameCubit>(),
          child: const PronunciationGameView(),
        ),
      ),
      // AI Lab Hub & Developer Screens
      GoRoute(
        path: AppRoutes.aiLab,
        name: 'aiLab',
        builder: (context, state) => BlocProvider<AiLabCubit>(
          create: (_) => sl<AiLabCubit>(),
          child: const AiLabHubView(),
        ),
        routes: [
          GoRoute(
            path: 'models',
            name: 'aiLabModels',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const ModelManagerView(),
            ),
          ),
          GoRoute(
            path: 'vad',
            name: 'aiLabVad',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const MicVadView(),
            ),
          ),
          GoRoute(
            path: 'noise',
            name: 'aiLabNoise',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const NoiseReductionView(),
            ),
          ),
          GoRoute(
            path: 'phonemes',
            name: 'aiLabPhonemes',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const PhonemeRecognitionView(),
            ),
          ),
          GoRoute(
            path: 'stt',
            name: 'aiLabStt',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const SpeechToTextView(),
            ),
          ),
          GoRoute(
            path: 'compare',
            name: 'aiLabCompare',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const ModelComparisonView(),
            ),
          ),
          GoRoute(
            path: 'pipeline',
            name: 'aiLabPipeline',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const FullPipelineView(),
            ),
          ),
        ],
      ),
    ],
  );
}
