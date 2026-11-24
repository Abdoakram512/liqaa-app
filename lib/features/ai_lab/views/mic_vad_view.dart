import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class MicVadView extends StatefulWidget {
  const MicVadView({super.key});

  @override
  State<MicVadView> createState() => _MicVadViewState();
}

class _MicVadViewState extends State<MicVadView> {
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
        title: const Text('2. الميكروفون ومحدد الصوت (Silero VAD)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final audio = state.lastAudioResult;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Live Recording & Waveform Card
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowWarm,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      state.isRecording ? 'ياسر يستمع الآن...' : 'اضغط للتسجيل الصوتي واختبار VAD',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: state.isRecording ? Colors.red : AppColors.textPrimary,
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Waveform visualizer simulation
                    Container(
                      height: 80.h,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      alignment: Alignment.center,
                      child: state.isRecording
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(24, (i) {
                                final h = (20.0 + (state.currentLiveAmplitude * 60.0 * ((i % 5) + 1) / 5.0)).clamp(10.0, 70.0);
                                return Container(
                                  width: 4.w,
                                  height: h,
                                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            )
                          : Text(
                              'اضغط على الميكروفون لبدء التسجيل',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                    ),

                    SizedBox(height: 20.h),

                    // Mic Action Button
                    GestureDetector(
                      onTap: () {
                        if (state.isRecording) {
                          context.read<AiLabCubit>().stopRecordingAndAnalyze();
                        } else {
                          context.read<AiLabCubit>().startRecording();
                        }
                      },
                      child: Container(
                        width: 72.w,
                        height: 72.w,
                        decoration: BoxDecoration(
                          color: state.isRecording ? Colors.red : AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (state.isRecording ? Colors.red : AppColors.primary).withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          state.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              Text(
                'نتائج تحليل نشاط الصوت (Silero VAD Metrics)',
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
                    'قم بتسجيل مقطع صوتي لعرض نتائج كشف الصوت واقتطاع الصمت',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                Column(
                  children: [
                    _buildMetricRow('وجود صوت بشري (Speech Detected):', audio.speechDetected ? 'نعم (صحيح)' : 'لا (صمت فقط)'),
                    _buildMetricRow('بداية الكلام (Speech Start):', '${audio.speechStartMs} ms'),
                    _buildMetricRow('نهاية الكلام (Speech End):', '${audio.speechEndMs} ms'),
                    _buildMetricRow('مدة المقطع المفيد (Duration):', '${audio.durationMs} ms'),
                    _buildMetricRow('متوسط الطاقة الصوتية (RMS):', '${audio.averageRms}'),
                    _buildMetricRow('نسبة الإشارة للضوضاء (SNR):', '${audio.snrDb} dB'),

                    SizedBox(height: 16.h),

                    // Audio play buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: AppColors.primaryDark,
                            ),
                            icon: const Icon(Icons.volume_up_rounded, size: 18),
                            label: const Text('تشغيل الصوت الخام'),
                            onPressed: () async {
                              if (audio.rawAudioBytes.isNotEmpty) {
                                await _audioPlayer.play(BytesSource(audio.rawAudioBytes));
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade50,
                              foregroundColor: Colors.teal.shade800,
                            ),
                            icon: const Icon(Icons.content_cut_rounded, size: 18),
                            label: const Text('تشغيل المقتطع (Trimmed)'),
                            onPressed: () async {
                              final trimmed = audio.trimmedAudioBytes ?? audio.rawAudioBytes;
                              if (trimmed.isNotEmpty) {
                                await _audioPlayer.play(BytesSource(trimmed));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
