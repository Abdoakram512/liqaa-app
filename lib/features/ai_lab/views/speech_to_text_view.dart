import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class SpeechToTextView extends StatelessWidget {
  const SpeechToTextView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('5. تحويل الكلام لنص (Speech-to-Text)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final stt = state.lastSttResult;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
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
                      'سجّل جملة أو كلمة للتعرف عليها على مستوى الكلمات',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 12.w,
                      runSpacing: 8.h,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.isRecording ? Colors.red : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                            minimumSize: Size(0, 44.h),
                          ),
                          icon: Icon(state.isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                          label: Text(state.isRecording ? 'إيقاف التسجيل' : 'بدء التسجيل'),
                          onPressed: () {
                            if (state.isRecording) {
                              context.read<AiLabCubit>().stopRecordingAndAnalyze();
                            } else {
                              context.read<AiLabCubit>().startRecording();
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                            minimumSize: Size(0, 44.h),
                          ),
                          icon: const Icon(Icons.transcribe_rounded, size: 18),
                          label: const Text('تشغيل STT'),
                          onPressed: () {
                            context.read<AiLabCubit>().runSttTest();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              Text(
                'نتائج التعرف على الكلام (ASR Results)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 12.h),

              if (stt == null)
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'قم بالتسجيل والضغط على "تشغيل STT" لعرض النص المحول ومعدل RTF',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('النص المكتوب (Transcription):', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                          SizedBox(height: 8.h),
                          Text(
                            stt.text.isNotEmpty ? stt.text : '(لم يتم التقاط نص)',
                            style: AppTextStyles.headlineSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 14.h),

                    _buildMetricRow(
                      'نسبة الثقة (Confidence):',
                      stt.confidence != null ? '${(stt.confidence! * 100).toInt()}%' : 'غير معيرة (Uncalibrated)',
                    ),
                    _buildMetricRow('زمن المعالجة (Latency):', '${stt.latencyMs} ms'),
                    _buildMetricRow('معدل الوقت الحقيقي (RTF):', '${stt.realTimeFactor}x (${stt.realTimeFactor < 1.0 ? "أسرع من الوقت الفعلي" : "أبطأ"})'),
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
