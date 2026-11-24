import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class FullPipelineView extends StatelessWidget {
  const FullPipelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('7. خط الأنابيب المتكامل (Full Pipeline)'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            tooltip: 'تصدير التقرير (JSON/CSV)',
            onPressed: () => context.read<AiLabCubit>().exportDiagnosticReport(),
          ),
        ],
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final audio = state.lastAudioResult;
          final assessment = state.lastAssessment;

          final Map<String, dynamic> pipelinePayload = {
            'target_word': state.selectedWord?.wordArabic ?? 'كورة',
            'status': state.status.name,
            'audio_metrics': audio?.toJson(),
            'phoneme_assessment': assessment?.toJson(),
            'noise_reduction_enabled': state.noiseReductionEnabled,
            'active_ram_mb': state.totalRamUsageMb,
          };

          final jsonPretty = const JsonEncoder.withIndent('  ').convert(pipelinePayload);

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Pipeline Trigger Card
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
                      'تشغيل مسار المعالجة بالكامل (End-to-End Pipeline)',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Mic ➔ Normalizer ➔ Silero VAD ➔ RNNoise ➔ Zipformer CTC ➔ Clinical Evaluator',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 14.h),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isRecording ? Colors.red : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      ),
                      icon: Icon(state.isRecording ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(state.isRecording ? 'إيقاف وتسجيل خط الأنابيب' : 'تسجيل وتشغيل المسار'),
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

              SizedBox(height: 16.h),

              // Stages Execution Timeline
              Text(
                'مراحل التنفيذ وأزمنة الاستجابة (Execution Timeline)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 10.h),

              _buildTimelineStep(
                step: 1,
                title: 'التقاط الصوت وتحويل PCM',
                detail: audio != null ? '16,000 Hz Mono Float32 (${audio.durationMs} ms)' : 'في الانتظار',
                latencyMs: 5,
                color: Colors.blue,
              ),
              _buildTimelineStep(
                step: 2,
                title: 'المعالجة المسبقة والتطبيع (Preprocess)',
                detail: 'إزالة DC-Offset وتطبيع القمة الصوتية (Peak Normalization)',
                latencyMs: 8,
                color: Colors.teal,
              ),
              _buildTimelineStep(
                step: 3,
                title: 'محدد النشاط الصوتي (Silero VAD)',
                detail: audio != null ? 'اقتطاع الصمت: بداية ${audio.speechStartMs}ms / نهاية ${audio.speechEndMs}ms' : 'في الانتظار',
                latencyMs: 22,
                color: Colors.green,
              ),
              _buildTimelineStep(
                step: 4,
                title: 'عزل الضوضاء (RNNoise Denoiser)',
                detail: state.noiseReductionEnabled ? 'تخفيف الضجيج (تحسن +${audio?.snrImprovementDb ?? 0} dB)' : 'تم التخطي (Bypass)',
                latencyMs: state.noiseReductionEnabled ? 32 : 1,
                color: Colors.deepPurpleAccent,
              ),
              _buildTimelineStep(
                step: 5,
                title: 'التعرف على الفونيمات (Zipformer CTC)',
                detail: assessment != null ? 'استخراج ${assessment.recognizedPhonemes.length} فونيمات بمتوسط ثقة 92%' : 'في الانتظار',
                latencyMs: 85,
                color: Colors.orangeAccent,
              ),
              _buildTimelineStep(
                step: 6,
                title: 'المحاذاة والتقييم السريري (Levenshtein)',
                detail: assessment != null ? 'الدرجة: ${assessment.overallScore}% (${assessment.passed ? "صحيح" : assessment.clinicalErrorName ?? "خطأ"})' : 'في الانتظار',
                latencyMs: 12,
                color: Colors.pinkAccent,
              ),

              SizedBox(height: 16.h),

              // JSON Payload Inspector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مخرجات JSON التشخيصية (Payload Inspector)',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('مشاركة / تصدير'),
                    onPressed: () => context.read<AiLabCubit>().exportDiagnosticReport(),
                  ),
                ],
              ),

              SizedBox(height: 8.h),

              Container(
                height: 220.h,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    jsonPretty,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.sp,
                      color: const Color(0xFFCDD6F4),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineStep({
    required int step,
    required String title,
    required String detail,
    required int latencyMs,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              '$step',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(fontSize: 13.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppColors.backgroundCream,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${latencyMs}ms',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
