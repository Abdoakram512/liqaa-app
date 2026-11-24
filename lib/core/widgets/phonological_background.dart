import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PhonologicalBackground extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const PhonologicalBackground({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(color: backgroundColor ?? AppColors.background),
      child: Stack(
        children: [
          // Ambient soft radial warmth at top
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryContainer.withAlpha(140),
                    AppColors.primaryContainer.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          // Ambient soft glow at bottom left
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondaryContainer.withAlpha(120),
                    AppColors.secondaryContainer.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
