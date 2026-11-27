import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ai/models/lab_task_mode.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../cubits/ai_lab_cubit.dart';
import '../cubits/ai_lab_state.dart';

class PhonemeRecognitionView extends StatelessWidget {
  const PhonemeRecognitionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('4. التعرف على الفونيمات (Wav2Vec2-eSpeak IPA)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: BlocBuilder<AiLabCubit, AiLabState>(
        builder: (context, state) {
          final word = state.selectedWord;
          final assessment = state.lastAssessment;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              // Word Selection Dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختر الكلمة المستهدفة للاختبار:',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    DropdownButtonFormField<VocabularyWord>(
                      initialValue: word,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: state.vocabulary.map((w) {
                        return DropdownMenuItem<VocabularyWord>(
                          value: w,
                          child: Text(
                            '${w.wordArabic} (${w.meaningEn}) - صوت [${w.targetPhoneme}]',
                          ),
                        );
                      }).toList(),
                      onChanged: (selected) {
                        if (selected != null) {
                          context.read<AiLabCubit>().selectVocabularyWord(
                            selected,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Recording & Trigger Card
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isRecording
                                ? 'جاري التسجيل...'
                                : 'انطق الكلمة الآن (أو تظاهر بالخطأ مثل "تورة")',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: state.isRecording
                                  ? Colors.red
                                  : AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'المحرك الصوتي: Wav2Vec2-LV60-eSpeak-CV-FT (392 IPA Tokens)',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Switch.adaptive(
                                value: state.rawBypassMode,
                                onChanged: (v) => context
                                    .read<AiLabCubit>()
                                    .setRawBypassMode(v),
                              ),
                              Expanded(
                                child: Text(
                                  state.rawBypassMode
                                      ? 'الوضع: استدلال خام مباشر (بدون VAD/GTCRN)'
                                      : 'الوضع: VAD + GTCRN + Wav2Vec2',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isRecording
                            ? Colors.red
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        state.isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                      ),
                      label: Text(state.isRecording ? 'إيقاف' : 'تسجيل'),
                      onPressed: () {
                        if (state.isRecording) {
                          context.read<AiLabCubit>().stopRecordingAndRunTask(
                            LabTaskMode.pronunciationAssessment,
                          );
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
                'مصفوفة المحاذاة الفونيمية (Phonetic Alignment)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 12.h),

              if (assessment == null)
                Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'سجّل نطق الكلمة لمشاهدة التسلسل الفونيمي ومقارنة الأصوات',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    // Result Overview Card
                    Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: assessment.passed
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: assessment.passed
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الدرجة: ${assessment.overallScore}% (${assessment.passed ? "اجتياز" : "بحاجة لتدريب"})',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: assessment.passed
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                                ),
                              ),
                              if (assessment.clinicalErrorName != null) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  'النوع الإكلينيكي: ${assessment.clinicalErrorName}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.red.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: List.generate(3, (i) {
                              return Icon(
                                i < assessment.stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 24,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // Phoneme alignment list
                    ...assessment.alignments.map((a) {
                      Color statusColor = Colors.green;
                      String statusText = 'صحيح (Match)';
                      if (a.status == 'substituted') {
                        statusColor = Colors.red;
                        statusText = 'إبدال (Substitution)';
                      } else if (a.status == 'deleted') {
                        statusColor = Colors.orange;
                        statusText = 'حذف (Deletion)';
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المتوقع: [${a.expectedPhoneme}] (${a.expectedArabic})',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'المنطوق: ${a.recognizedToken != null ? "[${a.recognizedToken!.symbol}] (${a.recognizedToken!.arabicSymbol})" : "مفقود"}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  statusText,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (a.recognizedToken != null) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    'الثقة: ${(a.recognizedToken!.confidence * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
