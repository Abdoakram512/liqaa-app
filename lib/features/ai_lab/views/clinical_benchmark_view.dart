import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ai/models/phoneme_token.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/phoneme_recognition_engine.dart';
import '../../../../core/ai/pronunciation_evaluator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ClinicalBenchmarkView extends StatefulWidget {
  const ClinicalBenchmarkView({super.key});

  @override
  State<ClinicalBenchmarkView> createState() => _ClinicalBenchmarkViewState();
}

class _ClinicalBenchmarkViewState extends State<ClinicalBenchmarkView> {
  final PronunciationEvaluator _evaluator = const PronunciationEvaluator();
  final PhonemeRecognitionEngine _phonemeEngine = PhonemeRecognitionEngine();

  int? _selectedCaseIndex;
  dynamic _lastAssessment;

  final List<Map<String, dynamic>> _testBattery = [
    {
      'title': 'كورة (نطق صحيح ومطابق)',
      'targetWord': 'كورة',
      'targetPhoneme': 'ك',
      'spokenText': 'كورة',
      'expectedResult': 'Pass (3 نجوم)',
      'isPassExpected': true,
    },
    {
      'title': 'تورة (إبدال أمامي - Fronting)',
      'targetWord': 'كورة',
      'targetPhoneme': 'ك',
      'spokenText': 'تورة',
      'expectedResult': 'Fail (كشف الإبدال)',
      'isPassExpected': false,
    },
    {
      'title': 'سمكة (نطق صحيح ومطابق)',
      'targetWord': 'سمكة',
      'targetPhoneme': 'س',
      'spokenText': 'سمكة',
      'expectedResult': 'Pass (3 نجوم)',
      'isPassExpected': true,
    },
    {
      'title': 'ثمكة (لدغة بين الأسنان - Lisp)',
      'targetWord': 'سمكة',
      'targetPhoneme': 'س',
      'spokenText': 'ثمكة',
      'expectedResult': 'Fail (كشف اللدغة)',
      'isPassExpected': false,
    },
    {
      'title': 'أرنب (نطق صحيح ومطابق)',
      'targetWord': 'أرنب',
      'targetPhoneme': 'ر',
      'spokenText': 'أرنب',
      'expectedResult': 'Pass (3 نجوم)',
      'isPassExpected': true,
    },
    {
      'title': 'أنلب (لدغة الراء إلى لام - Lateralization)',
      'targetWord': 'أرنب',
      'targetPhoneme': 'ر',
      'spokenText': 'أنلب',
      'expectedResult': 'Fail (كشف اللدغة)',
      'isPassExpected': false,
    },
    {
      'title': 'مدرسة (نطق كلمة غير مطابقة)',
      'targetWord': 'كورة',
      'targetPhoneme': 'ك',
      'spokenText': 'مدرسة',
      'expectedResult': 'Fail (كلمة غير مطابقة)',
      'isPassExpected': false,
    },
    {
      'title': 'صمت تام (Silence / No Speech)',
      'targetWord': 'كورة',
      'targetPhoneme': 'ك',
      'spokenText': '',
      'expectedResult': 'Fail (0 نجوم - صمت)',
      'isPassExpected': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _phonemeEngine.initialize();
  }

  void _runBenchmarkCase(int index) {
    final item = _testBattery[index];
    final String targetWordStr = item['targetWord'] as String;
    final String spoken = item['spokenText'] as String;

    // Build representative vocabulary word
    VocabularyWord word;
    if (targetWordStr == 'كورة') {
      word = const VocabularyWord(
        id: 'word_kora',
        wordArabic: 'كورة',
        wordTransliteration: 'Koora',
        meaningEn: 'Ball',
        targetPhoneme: 'ك',
        targetPhonemeIpa: 'k',
        phonemeCategory: 'صوت طبقي انفجاري',
        difficultyLevel: 1,
        expectedPhonemes: ['k', 'uː', 'r', 'a'],
        expectedArabicPhonemes: ['ك', 'و', 'ر', 'ة'],
        yasserTip: 'افتح بؤك وخلّي صوت الكاف يطلع من ورا',
        commonChildErrors: [
          ChildErrorRule(
            pronouncedWord: 'تورة',
            errorType: 'substitution',
            substitutedPhoneme: 'ت',
            targetPhoneme: 'ك',
            clinicalName: 'Fronting (إبدال أمامي)',
            feedbackAr: 'شاطر جداً! بس بدّلنا صوت الـ ك بالـ ت.. يلا نطلع الكاف: كـ كورة!',
            yasserPose: 'thinking',
          ),
        ],
      );
    } else if (targetWordStr == 'سمكة') {
      word = const VocabularyWord(
        id: 'word_samaka',
        wordArabic: 'سمكة',
        wordTransliteration: 'Samaka',
        meaningEn: 'Fish',
        targetPhoneme: 'س',
        targetPhonemeIpa: 's',
        phonemeCategory: 'صوت لثوي احتكاكي',
        difficultyLevel: 1,
        expectedPhonemes: ['s', 'a', 'm', 'a', 'k', 'a'],
        expectedArabicPhonemes: ['س', 'م', 'ك', 'ة'],
        yasserTip: 'اقفل سنانك بالراحة وطلع هواء زي الصفارة',
        commonChildErrors: [
          ChildErrorRule(
            pronouncedWord: 'ثمكة',
            errorType: 'substitution',
            substitutedPhoneme: 'ث',
            targetPhoneme: 'س',
            clinicalName: 'Interdental Lisp (لدغة بين الأسنان)',
            feedbackAr: 'ممتاز! بس لسانك طلع برة سنانك.. خلّي لسانك جوة واصفر: سسسـ سمكة!',
            yasserPose: 'thinking',
          ),
        ],
      );
    } else {
      word = const VocabularyWord(
        id: 'word_arnab',
        wordArabic: 'أرنب',
        wordTransliteration: 'Arnab',
        meaningEn: 'Rabbit',
        targetPhoneme: 'ر',
        targetPhonemeIpa: 'r',
        phonemeCategory: 'صوت لثوي تكراري',
        difficultyLevel: 2,
        expectedPhonemes: ['ʔ', 'a', 'r', 'n', 'a', 'b'],
        expectedArabicPhonemes: ['أ', 'ر', 'ن', 'ب'],
        yasserTip: 'خلّي طرف لسانك يرفرف',
        commonChildErrors: [
          ChildErrorRule(
            pronouncedWord: 'أنلب',
            errorType: 'substitution',
            substitutedPhoneme: 'ل',
            targetPhoneme: 'ر',
            clinicalName: 'Lateralization (لدغة الراء إلى لام)',
            feedbackAr: 'برافو يا بطل! بدّلنا الـ ر بالـ ل.. يلا نخلّي لساننا يهتز: أرررنب!',
            yasserPose: 'thinking',
          ),
        ],
      );
    }

    final List<PhonemeToken> tokens = spoken.isNotEmpty
        ? _phonemeEngine.textToPhonemes(spoken)
        : const <PhonemeToken>[];

    final assessment = _evaluator.evaluate(
      word: word,
      recognizedTokens: tokens,
      latencyMs: 42,
    );

    setState(() {
      _selectedCaseIndex = index;
      _lastAssessment = assessment;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(
          'مختبر 8: معيار التقييم الإكلينيكي (Benchmark)',
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
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overview card
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_rounded, color: Colors.purple.shade800, size: 28),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'حزمة الاختبارات الإكلينيكية القياسية المبنية على معايير تشخيص أمراض النطق لدى الأطفال المصريين (ASMDD Dataset Benchmark).',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.purple.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              'حالات الاختبار المرجعية (8 Clinical Scenarios):',
              style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.h),

            // Battery List
            ...List.generate(_testBattery.length, (idx) {
              final item = _testBattery[idx];
              final isSelected = _selectedCaseIndex == idx;

              return Card(
                elevation: 0,
                margin: EdgeInsets.only(bottom: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.borderSoft,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    item['title'] as String,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'الكلمة: ${item['targetWord']} | المنطوق: "${item['spokenText']}" | المتوقع: ${item['expectedResult']}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade200,
                      foregroundColor: isSelected ? Colors.white : AppColors.textPrimary,
                      elevation: 0,
                    ),
                    onPressed: () => _runBenchmarkCase(idx),
                    child: const Text('اختبر الآن'),
                  ),
                ),
              );
            }),

            SizedBox(height: 16.h),

            // Assessment Inspection Area
            if (_lastAssessment != null) ...[
              Text(
                'نتائج خوارزمية المحاذاة الديناميكية (DP Assessment Result):',
                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10.h),

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
                          'النتيجة: ${_lastAssessment.passed ? "اجتاز (PASS)" : "لم يجتز (FAIL)"}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: _lastAssessment.passed ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        Text(
                          'الدرجة: ${_lastAssessment.overallScore}% (${_lastAssessment.stars} نجوم)',
                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_lastAssessment.clinicalErrorName != null) ...[
                      SizedBox(height: 6.h),
                      Text(
                        'التشخيص الإكلينيكي: ${_lastAssessment.clinicalErrorName}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),

                    Text(
                      'مصفوفة المحاذاة الفونيمية (Alignment Matrix):',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 8.h),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: (_lastAssessment.alignments as List).map<Widget>((a) {
                          final status = a.status as String;
                          Color bg = Colors.green.shade50;
                          Color bd = Colors.green.shade400;
                          if (status == 'substituted') {
                            bg = Colors.red.shade50;
                            bd = Colors.red.shade400;
                          } else if (status == 'deleted') {
                            bg = Colors.amber.shade50;
                            bd = Colors.amber.shade400;
                          }

                          return Container(
                            margin: EdgeInsets.only(right: 8.w),
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: bd),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'المتوقع: ${a.expectedArabic.isNotEmpty ? a.expectedArabic : "—"}',
                                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'المنطوق: ${a.recognizedToken?.arabicSymbol ?? "—"}',
                                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.bold,
                                    color: bd,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    SizedBox(height: 14.h),
                    Text(
                      'رسالة ياسر للطفل:',
                      style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _lastAssessment.yasserFeedbackMessage as String,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}
