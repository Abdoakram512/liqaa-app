import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependency_injection/service_locator.dart';
import '../../features/ai_lab/cubits/ai_lab_cubit.dart';
import '../../features/ai_lab/views/ai_lab_hub_view.dart';
import '../../features/ai_lab/views/full_pipeline_view.dart';
import '../../features/ai_lab/views/mic_vad_view.dart';
import '../../features/ai_lab/views/model_comparison_view.dart';
import '../../features/ai_lab/views/model_manager_view.dart';
import '../../features/ai_lab/views/noise_reduction_view.dart';
import '../../features/ai_lab/views/phoneme_recognition_view.dart';
import '../../features/ai_lab/views/speech_to_text_view.dart';
import '../../features/ai_lab/views/clinical_benchmark_view.dart';
import '../../features/ai_lab/views/blind_phoneme_recognition_view.dart';
import '../../features/ai_lab/views/diagnostic_negative_testing_view.dart';
import '../../features/animation_lab/presentation/views/animation_lab_view.dart';
import '../../features/animation_lab/presentation/views/rive_diagnostic_view.dart';
import '../../features/authentication/presentation/cubits/auth_cubit.dart';
import '../../features/authentication/presentation/views/auth_gateway_view.dart';
import '../../features/authentication/presentation/views/forgot_password_view.dart';
import '../../features/authentication/presentation/views/login_view.dart';
import '../../features/authentication/presentation/views/otp_verification_view.dart';
import '../../features/authentication/presentation/views/register_view.dart';
import '../../features/authentication/presentation/views/reset_password_view.dart';
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

      // Authentication Portal & Routes
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: BlocProvider<AuthCubit>(
            create: (_) => sl<AuthCubit>(),
            child: const AuthGatewayView(),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeIn).animate(animation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => BlocProvider<AuthCubit>(
          create: (_) => sl<AuthCubit>(),
          child: const LoginView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => BlocProvider<AuthCubit>(
          create: (_) => sl<AuthCubit>(),
          child: const RegisterView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => BlocProvider<AuthCubit>(
          create: (_) => sl<AuthCubit>(),
          child: const ForgotPasswordView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        name: 'otpVerification',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return BlocProvider<AuthCubit>(
            create: (_) => sl<AuthCubit>(),
            child: OtpVerificationView(email: email),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: 'resetPassword',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return BlocProvider<AuthCubit>(
            create: (_) => sl<AuthCubit>(),
            child: ResetPasswordView(email: email),
          );
        },
      ),

      // Developer Animation Lab Route
      GoRoute(
        path: AppRoutes.animationLab,
        name: 'animationLab',
        builder: (context, state) => const AnimationLabView(),
      ),
      GoRoute(
        path: AppRoutes.riveDiagnostic,
        name: 'riveDiagnostic',
        builder: (context, state) => const RiveDiagnosticView(),
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
          GoRoute(
            path: 'benchmark',
            name: 'aiLabBenchmark',
            builder: (context, state) => const ClinicalBenchmarkView(),
          ),
          GoRoute(
            path: 'blind',
            name: 'aiLabBlind',
            builder: (context, state) => BlocProvider.value(
              value: sl<AiLabCubit>(),
              child: const BlindPhonemeRecognitionView(),
            ),
          ),
          GoRoute(
            path: 'negative',
            name: 'aiLabNegative',
            builder: (context, state) => const DiagnosticNegativeTestingView(),
          ),
        ],
      ),
    ],
  );
}
