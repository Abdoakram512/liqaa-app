import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/yasser_design_tokens.dart';
import '../widgets/world_clippers.dart';

/// Context-aware route transitions creating a cohesive, responsive product feel
/// while strictly respecting system reduced-motion preferences.
abstract final class YasserPageTransitions {
  /// Warm portal transition from Splash into Onboarding, Auth, or Home.
  static CustomTransitionPage<T> warmPortal<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: YasserMotion.pageTransition,
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (YasserMotion.isReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: YasserMotion.gentleDecelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// RTL-aware horizontal shared-axis transition for Authentication & flows.
  static CustomTransitionPage<T> sharedAxis<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (YasserMotion.isReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }
        final bool isRtl = Directionality.of(context) == TextDirection.rtl;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(isRtl ? -0.06 : 0.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Playful upward expansion for launching children's speech training studio.
  static CustomTransitionPage<T> activityLaunch<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (YasserMotion.isReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(slide),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(slide),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Calm, fast, professional transition for Specialist clinical workflows.
  static CustomTransitionPage<T> specialistCalm<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (YasserMotion.isReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuad,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Expanding storybook portal reveal using [CircularPortalRevealClipper].
  static CustomTransitionPage<T> portalReveal<T>({
    required LocalKey key,
    required Widget child,
    Alignment centerAlignment = Alignment.center,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: YasserMotion.sceneMorph,
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (YasserMotion.isReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: YasserMotion.smoothMorph,
        );
        return AnimatedBuilder(
          animation: curved,
          builder: (context, inner) {
            return ClipPath(
              clipper: CircularPortalRevealClipper(
                progress: curved.value,
                centerAlignment: centerAlignment,
              ),
              child: inner,
            );
          },
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  /// RTL-aware storybook page-turn transition for Adventures & Adventure Book.
  static CustomTransitionPage<T> storybookTurn<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: YasserMotion.pageTransition,
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (YasserMotion.isReducedMotion(context)) {
          return FadeTransition(opacity: animation, child: child);
        }
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final curved = CurvedAnimation(
          parent: animation,
          curve: YasserMotion.smoothMorph,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(isRtl ? -0.10 : 0.10, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
