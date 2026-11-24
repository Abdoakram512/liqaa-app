import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/phonological_background.dart';
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed(BuildContext context, OnboardingState state) {
    if (state.isLastPage) {
      context.read<OnboardingCubit>().completeOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPreviousPressed() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
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
              child: SafeArea(
                child: Column(
                  children: [
                    // Top Header with Step Counter & Skip button
                    OnboardingHeader(
                      onSkip: cubit.skipOnboarding,
                      showSkip: !state.isLastPage,
                      currentStep: state.currentIndex + 1,
                      totalSteps: state.totalPages,
                    ),

                    // PageView with 3 unique scene compositions
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: state.totalPages,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          cubit.onPageChanged(index);
                        },
                        itemBuilder: (context, index) {
                          return OnboardingPageItem(item: state.items[index]);
                        },
                      ),
                    ),

                    // Bottom Navigation Bar
                    OnboardingNavigationBar(
                      currentIndex: state.currentIndex,
                      totalPages: state.totalPages,
                      isLastPage: state.isLastPage,
                      isFirstPage: state.isFirstPage,
                      activeColor: state.currentItem.accentColor,
                      onNext: () => _onNextPressed(context, state),
                      onPrevious: _onPreviousPressed,
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
