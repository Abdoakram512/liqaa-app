import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/ai/models/pronunciation_assessment.dart';
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
        title: const Text('7. فاحص خط الأنابيب المتكامل (Pipeline Inspector)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final audio = state.lastAudioResult;
          final assessment = state.lastAssessment;
          final phonemeRes = state.lastPhonemeResult;
          final sttRes = state.lastSttResult;
          final jsonPretty = context.read<AiLabCubit>().buildDiagnosticJsonReport();

          final String? failedStage = assessment?.pipelineStageFailed ??
              (audio != null && !audio.isValidAudio ? 'AudioPreprocessor / DSP' : null) ??
              (phonemeRes?.hasError == true ? 'PhonemeRecognition' : null);

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Action Trigger + Quick Fixture Tests
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
                      'المسار الفعلي: Mic ➔ RIFF Validator ➔ Silero VAD ➔ GTCRN ➔ Wav2Vec2-eSpeak ➔ DP Evaluator',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 10.h),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('وضع التخطي الخام (Bypass VAD/Denoise)', style: AppTextStyles.bodyMedium),
                      subtitle: Text('لاختبار Wav2Vec2 و Whisper على الموجة الخام مباشرة', style: AppTextStyles.bodySmall),
                      value: state.rawBypassMode,
                      onChanged: (v) => context.read<AiLabCubit>().setRawBypassMode(v),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.isRecording ? Colors.red : AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(state.isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                          label: Text(state.isRecording ? 'إيقاف وتحليل التسجيل' : 'تسجيل من الميكروفون'),
                          onPressed: () {
                            if (state.isRecording) {
                              context.read<AiLabCubit>().stopRecordingAndAnalyze();
                            } else {
                              context.read<AiLabCubit>().startRecording();
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.audiotrack_rounded, size: 18),
                          label: const Text('فحص عينة كورة'),
                          onPressed: () async {
                            final data = await rootBundle.load('assets/audio_samples/correct_kora.wav');
                            if (context.mounted) {
                              await context.read<AiLabCubit>().analyzeWavBytesForAllStages(
                                    data.buffer.asUint8List(),
                                  );
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.volume_off_rounded, size: 18),
                          label: const Text('فحص عينة صمت'),
                          onPressed: () async {
                            final data = await rootBundle.load('assets/audio_samples/silence.wav');
                            if (context.mounted) {
                              await context.read<AiLabCubit>().analyzeWavBytesForAllStages(
                                    data.buffer.asUint8List(),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (failedStage != null || state.errorMessage != null) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    'المرحلة المتعطلة: ${failedStage ?? "System"}\nالتفاصيل: ${assessment?.diagnosticError ?? state.errorMessage}',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade900),
                  ),
                ),
              ],

              SizedBox(height: 16.h),

              Text(
                'فحص المراحل والنتائج الحقيقية (Real Stage Telemetry)',
                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 10.h),

              _buildStageCard(
                step: 1,
                title: '1. التحقق من الصوت و RIFF/WAVE',
                detail: audio != null
                    ? '${audio.sampleRate} Hz • ${audio.channels}ch • ${audio.bitsPerSample}-bit | ${audio.sampleCount} samples (${audio.durationMs}ms) | Clip=${audio.clippingCount}'
                    : 'في الانتظار',
                ok: audio?.isValidAudio ?? true,
                color: Colors.blue,
              ),
              _buildStageCard(
                step: 2,
                title: '2. كشف الكلام (Silero VAD - 512 Window)',
                detail: audio != null
                    ? (audio.speechDetected
                        ? 'مكتشف: ${audio.vadSegments.length} مقاطع (${audio.speechStartMs}-${audio.speechEndMs}ms) | RMS=${audio.averageRms}'
                        : 'لم يتم اكتشاف كلام (RMS=${audio.averageRms})')
                    : 'في الانتظار',
                ok: audio?.errorMessage == null,
                color: Colors.teal,
              ),
              _buildStageCard(
                step: 3,
                title: '3. عزل الضوضاء (${audio?.denoiserFilterType ?? state.denoiserMode.name})',
                detail: audio != null
                    ? (audio.denoisedAudioBytes != null
                        ? 'RMS ${audio.averageRms} -> ${audio.denoisedRms} | SNR Δ=${audio.snrImprovementDb} dB'
                        : 'فشل أو غير متاح: ${audio.errorMessage ?? "لا يوجد خرج"}')
                    : 'في الانتظار',
                ok: audio == null || audio.denoisedAudioBytes != null,
                color: Colors.deepPurpleAccent,
              ),
              _buildStageCard(
                step: 4,
                title: '4. التعرف الصوتي للفونيمات (Wav2Vec2-eSpeak IPA)',
                detail: phonemeRes != null
                    ? (phonemeRes.hasError
                        ? 'فشل: ${phonemeRes.errorMessage}'
                        : 'IPA=[${phonemeRes.tokens.map((t) => t.symbol).join(" ")}] | Conf=${phonemeRes.averageConfidence?.toStringAsFixed(2) ?? "-"} | Margin=${phonemeRes.averageAcousticMargin?.toStringAsFixed(2) ?? "-"} | ${phonemeRes.latencyMs}ms')
                    : 'في الانتظار',
                ok: phonemeRes == null || (!phonemeRes.hasError && phonemeRes.isNativeModel),
                color: Colors.orangeAccent,
              ),
              _buildStageCard(
                step: 5,
                title: '5. مقارنة المسار الخام vs المعالج',
                detail: 'الخام=[${state.lastRawPhonemes.map((t) => t.symbol).join(" ")}]\nالمعالج=[${state.lastBlindPhonemes.map((t) => t.symbol).join(" ")}]',
                ok: true,
                color: Colors.indigo,
              ),
              _buildStageCard(
                step: 6,
                title: '6. تحويل الكلام (Whisper Tiny - تشخيصي فقط)',
                detail: sttRes != null
                    ? (sttRes.hasError
                        ? 'خطأ: ${sttRes.errorMessage}'
                        : 'النص="${sttRes.text}" | Latency=${sttRes.latencyMs}ms | RTF=${sttRes.realTimeFactor}x')
                    : 'في الانتظار',
                ok: sttRes == null || !sttRes.hasError,
                color: Colors.blueGrey,
              ),
              _buildStageCard(
                step: 7,
                title: '7. المحاذاة والتقييم السريري (DP Alignment)',
                detail: assessment != null
                    ? '${assessment.errorType.name} | الدرجة=${assessment.overallScore}% | الزمن=${assessment.latencyMs}ms'
                    : 'في الانتظار',
                ok: assessment == null || !assessment.errorType.isSystemFailure,
                color: Colors.pinkAccent,
              ),

              SizedBox(height: 16.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تقرير JSON التشخيصي القابل للتصدير', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 4.w,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jsonPretty));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ تقرير JSON التشخيصي')),
                          );
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('تصدير'),
                        onPressed: () => context.read<AiLabCubit>().exportDiagnosticReport(),
                      ),
                    ],
                  ),
                ],
              ),

              Container(
                height: 240.h,
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

  Widget _buildStageCard({
    required int step,
    required String title,
    required String detail,
    required bool ok,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: ok ? Colors.white : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? AppColors.borderSoft : Colors.red.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: (ok ? color : Colors.red).withOpacity(0.15),
            child: Text(
              '$step',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: ok ? color : Colors.red,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall.copyWith(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 2.h),
                Text(detail, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
