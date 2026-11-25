import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class BlindPhonemeRecognitionView extends StatelessWidget {
  const BlindPhonemeRecognitionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(
          'مختبر 9: التعرف الحر والفونيمات غير المقيدة',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final isProcessing = state.status == AiLabStatus.processing;
          final isRecording = state.isRecording;
          final transcript = state.lastBlindTranscript ?? '';
          final phonemes = state.lastBlindPhonemes;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scientific Proof Banner
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_rounded, color: Colors.blue.shade800, size: 24),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'برهان عدم تسريب الإجابة (Zero Target Leakage)',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'في هذا الاختبار، لا يتم تمرير أي كلمة مستهدفة أو فونيمات متوقعة للنموذج. محرك الذكاء الاصطناعي يستمع بشكل أعمى (Blind ASR) ويحلل الفونيمات الصوتية بحرية تامة لإثبات الاستدلال الحقيقي.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Live Audio Recording Section
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowWarm,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isRecording ? 'ياسر يستمع إليك الآن...' : 'سجّل صوتاً حراً من الميكروفون',
                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 12.h),

                      // Animated Mic Button
                      GestureDetector(
                        onTap: () {
                          if (isRecording) {
                            context.read<AiLabCubit>().stopRecordingAndAnalyze();
                          } else {
                            context.read<AiLabCubit>().startRecording();
                          }
                        },
                        child: Container(
                          width: 72.w,
                          height: 72.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRecording ? Colors.red : AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: (isRecording ? Colors.red : AppColors.primary).withOpacity(0.4),
                                blurRadius: isRecording ? 20 : 10,
                                spreadRadius: isRecording ? 4 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),

                      if (isRecording) ...[
                        SizedBox(height: 10.h),
                        Text(
                          'تحدث بأي كلمة أو جملة باللهجة المصرية...',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Test Presets Section (Real WAV Audio Fixtures)
                Text(
                  'عينات صوتية حقيقية للتحقق الفوري (WAV Audio Fixtures):',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildFixtureChip(context, label: 'كورة (صوت حقيقي)', fixturePath: 'assets/audio_samples/correct_kora.wav'),
                    _buildFixtureChip(context, label: 'تورة (إبدال كـ إلى تـ)', fixturePath: 'assets/audio_samples/error_tora.wav'),
                    _buildFixtureChip(context, label: 'سمكة (صوت حقيقي)', fixturePath: 'assets/audio_samples/correct_samaka.wav'),
                    _buildFixtureChip(context, label: 'ثمكة (لدغة ثـ)', fixturePath: 'assets/audio_samples/error_thamaka.wav'),
                    _buildFixtureChip(context, label: 'مدرسة (كلمة حرة)', fixturePath: 'assets/audio_samples/word_madrasa.wav'),
                    _buildFixtureChip(context, label: 'صوت صمت (Silence)', fixturePath: 'assets/audio_samples/silence.wav', isSilence: true),
                  ],
                ),

                SizedBox(height: 20.h),

                // Results Card
                if (isProcessing)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ))
                else ...[
                  // Recognized Transcript Display
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'النص العربي المكتشف عشوائياً (Blind ASR):',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: transcript.isNotEmpty ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: transcript.isNotEmpty ? Colors.green.shade300 : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                transcript.isNotEmpty ? 'تم التعرف' : 'صمت / لا يوجد كلام',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: transcript.isNotEmpty ? Colors.green.shade800 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          transcript.isNotEmpty ? transcript : '—',
                          style: AppTextStyles.displaySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: transcript.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Recognized Phonemic Units breakdown
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سلسلة الفونيمات الصوتية المستخرجة (${phonemes.length} Phonemes):',
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12.h),

                        if (phonemes.isEmpty)
                          Text(
                            'لم يتم استخراج فونيمات (الصوت كان صمتاً أو لم يبدأ بعد).',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                          )
                        else
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 10.h,
                            children: phonemes.map((token) {
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      token.arabicSymbol,
                                      style: TextStyle(
                                        fontSize: 22.sp,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    Text(
                                      '/${token.symbol}/',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '${(token.confidence * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    Text(
                                      '${token.startMs}-${token.endMs}ms',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFixtureChip(
    BuildContext context, {
    required String label,
    required String fixturePath,
    bool isSilence = false,
  }) {
    return ActionChip(
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.borderSoft),
      label: Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
      avatar: Icon(
        isSilence ? Icons.volume_off_rounded : Icons.play_arrow_rounded,
        size: 16,
        color: isSilence ? Colors.red : AppColors.primary,
      ),
      onPressed: () async {
        try {
          final data = await rootBundle.load(fixturePath);
          final bytes = data.buffer.asUint8List();
          if (context.mounted) {
            context.read<AiLabCubit>().runBlindPhonemeTest(audioBytes: bytes);
          }
        } catch (e) {
          debugPrint('[BlindPhonemeRecognitionView] Error loading fixture $fixturePath: $e');
        }
      },
    );
  }
}
