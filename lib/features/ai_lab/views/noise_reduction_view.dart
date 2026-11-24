import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class NoiseReductionView extends StatefulWidget {
  const NoiseReductionView({super.key});

  @override
  State<NoiseReductionView> createState() => _NoiseReductionViewState();
}

class _NoiseReductionViewState extends State<NoiseReductionView> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('3. عزل الضوضاء (RNNoise Suppression)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final audio = state.lastAudioResult;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Settings Toggle Card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفعيل عزل الضوضاء (RNNoise Toggle)',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'يقوم بتخفيف الضجيج البيئي الثابت مثل صوت المروحة والمكيف',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: state.noiseReductionEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        context.read<AiLabCubit>().toggleNoiseReduction(val);
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Recording Action
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  children: [
                    Text(
                      'سجّل مقطع صوتي في بيئة بها ضوضاء للمقارنة',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isRecording ? Colors.red : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      ),
                      icon: Icon(state.isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                      label: Text(state.isRecording ? 'إيقاف التسجيل والتحليل' : 'بدء تسجيل تجريبي'),
                      onPressed: () {
                        if (state.isRecording) {
                          context.read<AiLabCubit>().stopRecordingAndAnalyze();
                        } else {
                          context.read<AiLabCubit>().startRecording();
                        }
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              Text(
                'نتائج المقارنة الصوتية (Raw vs Denoised)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 12.h),

              if (audio == null)
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'قم بالتسجيل للاستماع إلى الصوت قبل وبعد عزل الضوضاء',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                Column(
                  children: [
                    // Dual comparison players
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.mic_none_rounded, color: Colors.orange, size: 28),
                                SizedBox(height: 6.h),
                                Text('الصوت الأصلي (Raw)', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4.h),
                                Text('SNR: ${audio.snrDb} dB', style: AppTextStyles.bodySmall),
                                SizedBox(height: 10.h),
                                IconButton(
                                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.orange, size: 40),
                                  onPressed: () async {
                                    if (audio.rawAudioBytes.isNotEmpty) {
                                      await _audioPlayer.play(BytesSource(audio.rawAudioBytes));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.auto_fix_high_rounded, color: Colors.deepPurpleAccent, size: 28),
                                SizedBox(height: 6.h),
                                Text('المعالج (RNNoise)', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                                SizedBox(height: 4.h),
                                Text('تحسن: +${audio.snrImprovementDb} dB', style: AppTextStyles.bodySmall.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                SizedBox(height: 10.h),
                                IconButton(
                                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.deepPurpleAccent, size: 40),
                                  onPressed: () async {
                                    final denoised = audio.denoisedAudioBytes ?? audio.rawAudioBytes;
                                    if (denoised.isNotEmpty) {
                                      await _audioPlayer.play(BytesSource(denoised));
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Acoustic Note Card
                    Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 20),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'تنبيه صوتي سريري: عزل الضوضاء القوي قد يخفف أصوات الاحتكاك الضعيفة مثل السين والفاء والشين عند الأطفال. يُنصح بإلغاء التفعيل في الغرف الهادئة للحفاظ على دقة النطق.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
