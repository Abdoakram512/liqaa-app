import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

class SoundWaveformWave extends StatelessWidget {
  final double amplitude;
  final bool isListening;

  const SoundWaveformWave({
    super.key,
    required this.amplitude,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    if (!isListening) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 36.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(15, (index) {
          final factor = ((index % 4) + 1) / 4.0;
          final height = (8.0 + (amplitude * 28.0 * factor)).clamp(6.0, 32.0);
          return Container(
            width: 4.w,
            height: height.h,
            margin: EdgeInsets.symmetric(horizontal: 2.w),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
