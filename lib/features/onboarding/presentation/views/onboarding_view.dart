import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/yasser_design_tokens.dart';
import '../../../../core/widgets/phonological_background.dart';
import '../../data/models/onboarding_item_model.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_navigation_bar.dart';
import '../widgets/onboarding_page_item.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  late final PageController _pageController;
  int? _settledPage = 0;
  double _pageProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      onAttach: (position) =>
          position.isScrollingNotifier.addListener(_updateSettledPage),
      onDetach: (position) =>
          position.isScrollingNotifier.removeListener(_updateSettledPage),
    )..addListener(_handlePageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? 0.0;
    if ((page - _pageProgress).abs() > 0.005 && mounted) {
      setState(() => _pageProgress = page);
    }
  }

  void _updateSettledPage() {
    if (!_pageController.hasClients) return;
    final position = _pageController.position;
    final next = position.isScrollingNotifier.value
        ? null
        : _pageController.page?.round();
    if (next != _settledPage && mounted) {
      setState(() => _settledPage = next);
    }
  }

  void _onNextPressed(BuildContext context, OnboardingState state) {
    if (state.isLastPage) {
      context.read<OnboardingCubit>().completeOnboarding();
    } else {
      final reduced = YasserMotion.isReducedMotion(context);
      if (reduced) {
        _pageController.jumpToPage(state.currentIndex + 1);
      } else {
        _pageController.nextPage(
          duration: YasserMotion.pageTransition,
          curve: YasserMotion.smoothMorph,
        );
      }
    }
  }

  void _onPreviousPressed(BuildContext context, OnboardingState state) {
    if (state.isFirstPage) return;
    final reduced = YasserMotion.isReducedMotion(context);
    if (reduced) {
      _pageController.jumpToPage(state.currentIndex - 1);
    } else {
      _pageController.previousPage(
        duration: YasserMotion.pageTransition,
        curve: YasserMotion.smoothMorph,
      );
    }
  }

  PhonologicalSceneVariant _sceneForEnvironment(OnboardingEnvironment env) {
    return switch (env) {
      OnboardingEnvironment.welcomeSound =>
        PhonologicalSceneVariant.sunriseArch,
      OnboardingEnvironment.soundPuzzle =>
        PhonologicalSceneVariant.soundDiscovery,
      OnboardingEnvironment.celebrationLaunch =>
        PhonologicalSceneVariant.celebrationStage,
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OnboardingCubit>(),
      child: BlocConsumer<OnboardingCubit, OnboardingState>(
        listenWhen: (previous, current) => current.isCompleted,
        listener: (context, state) {
          if (state.isCompleted) {
            context.go(AppRoutes.auth);
          }
        },
        builder: (context, state) {
          final cubit = context.read<OnboardingCubit>();

          return Scaffold(
            body: PhonologicalBackground(
              variant: _sceneForEnvironment(state.currentItem.environment),
              morphProgress: _pageProgress,
              child: SafeArea(
                child: Column(
                  children: [
                    OnboardingHeader(
                      onSkip: cubit.skipOnboarding,
                      showSkip: !state.isLastPage,
                      currentStep: state.currentIndex + 1,
                      totalSteps: state.totalPages,
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: state.totalPages,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: cubit.onPageChanged,
                        itemBuilder: (context, index) {
                          final parallax = (_pageProgress - index).clamp(
                            -1.0,
                            1.0,
                          );
                          return OnboardingPageItem(
                            item: state.items[index],
                            isActive: index == _settledPage,
                            parallaxOffset: parallax,
                          );
                        },
                      ),
                    ),
                    OnboardingNavigationBar(
                      currentIndex: state.currentIndex,
                      totalPages: state.totalPages,
                      isLastPage: state.isLastPage,
                      isFirstPage: state.isFirstPage,
                      activeColor: state.currentItem.accentColor,
                      onNext: () => _onNextPressed(context, state),
                      onPrevious: () => _onPreviousPressed(context, state),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
