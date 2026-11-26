import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/pronunciation_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class ClinicalBenchmarkView extends StatefulWidget {
  const ClinicalBenchmarkView({super.key});

  @override
  State<ClinicalBenchmarkView> createState() => _ClinicalBenchmarkViewState();
}

class _ClinicalBenchmarkViewState extends State<ClinicalBenchmarkView> {
  final PronunciationRepository _repository = sl<PronunciationRepository>();
  bool _isInitialized = false;
  bool _isRunning = false;

  int? _selectedCaseIndex;
  PronunciationAssessment? _lastAssessment;

  final List<Map<String, dynamic>> _testBattery = [
    {
      'title': 'كورة (نطق صحيح ومطابق)',
      'fixturePath': 'assets/audio_samples/correct_kora.wav',
      'targetWord': 'كورة',
      'targetWordId': 'word_kora',
      'expectedResult': 'Pass (3 نجوم - نطق سليم)',
      'isPassExpected': true,
    },
    {
      'title': 'تورة (إبدال أمامي - Fronting)',
      'fixturePath': 'assets/audio_samples/error_tora.wav',
      'targetWord': 'كورة',
      'targetWordId': 'word_kora',
      'expectedResult': 'Fail (كشف إبدال الكاف إلى تاء)',
      'isPassExpected': false,
    },
    {
      'title': 'سمكة (نطق صحيح ومطابق)',
      'fixturePath': 'assets/audio_samples/correct_samaka.wav',
      'targetWord': 'سمكة',
      'targetWordId': 'word_samaka',
      'expectedResult': 'Pass (3 نجوم - نطق سليم)',
      'isPassExpected': true,
    },
    {
      'title': 'ثمكة (لدغة بين الأسنان - Lisp)',
      'fixturePath': 'assets/audio_samples/error_thamaka.wav',
      'targetWord': 'سمكة',
      'targetWordId': 'word_samaka',
      'expectedResult': 'Fail (كشف لدغة السين إلى ثاء)',
      'isPassExpected': false,
    },
    {
      'title': 'أرنب (نطق صحيح ومطابق)',
      'fixturePath': 'assets/audio_samples/correct_arnab.wav',
      'targetWord': 'أرنب',
      'targetWordId': 'word_arnab',
      'expectedResult': 'Pass (3 نجوم - نطق سليم)',
      'isPassExpected': true,
    },
    {
      'title': 'أنلب (لدغة الراء إلى لام - Lateralization)',
      'fixturePath': 'assets/audio_samples/error_anlab.wav',
      'targetWord': 'أرنب',
      'targetWordId': 'word_arnab',
      'expectedResult': 'Fail (كشف لدغة الراء إلى لام)',
      'isPassExpected': false,
    },
    {
      'title': 'مدرسة (نطق كلمة غير مطابقة)',
      'fixturePath': 'assets/audio_samples/word_madrasa.wav',
      'targetWord': 'كورة',
      'targetWordId': 'word_kora',
      'expectedResult': 'Fail (كلمة غير مطابقة تماماً)',
      'isPassExpected': false,
    },
    {
      'title': 'صوت صمت (Silence / No Speech)',
      'fixturePath': 'assets/audio_samples/silence.wav',
      'targetWord': 'كورة',
      'targetWordId': 'word_kora',
      'expectedResult': 'Fail (0 نجوم - صمت تام)',
      'isPassExpected': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    await _repository.initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _runBenchmarkCase(int index) async {
    if (!_isInitialized || _isRunning) return;

    setState(() {
      _selectedCaseIndex = index;
      _isRunning = true;
    });

    final item = _testBattery[index];
    final String fixturePath = item['fixturePath'] as String;
    final String targetWordId = item['targetWordId'] as String;

    try {
      // 1. Find target word in repository dictionary
      VocabularyWord? word;
      for (final w in _repository.vocabulary) {
        if (w.id == targetWordId) {
          word = w;
          break;
        }
      }
      word ??= _repository.vocabulary.first;

      // 2. Load REAL audio WAV fixture bytes from assets
      final ByteData data = await rootBundle.load(fixturePath);
      final Uint8List rawAudioBytes = data.buffer.asUint8List();

      // 3. Process through end-to-end real AI pipeline
      final assessment = await _repository.evaluateAudio(
        rawAudioBytes: rawAudioBytes,
        targetWord: word,
      );

      if (mounted) {
        setState(() {
          _lastAssessment = assessment;
          _isRunning = false;
        });
      }
    } catch (e) {
      debugPrint('[ClinicalBenchmarkView] Execution error: $e');
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
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
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
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
                  Icon(
                    Icons.science_rounded,
                    color: Colors.purple.shade800,
                    size: 28,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'معيار الاختبار الإكلينيكي الحقيقي: معالجة ملفات صوتية حقيقية مسجلة مسبقاً (WAV Audio Fixtures) للتحقق الدقيق من اكتشاف اضطرابات النطق بدون محاكاة نصية.',
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
              'حالات الاختبار المرجعية (8 Real Audio Scenarios):',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.borderSoft,
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
                    'الملف: ${(item['fixturePath'] as String).split('/').last} | الهدف: ${item['targetWord']} | المتوقع: ${item['expectedResult']}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      foregroundColor: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      elevation: 0,
                      minimumSize: Size(0, 36.h),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                    ),
                    onPressed: _isRunning ? null : () => _runBenchmarkCase(idx),
                    child: _isRunning && isSelected
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('تشغيل العينة'),
                  ),
                ),
              );
            }),

            SizedBox(height: 16.h),

            // Assessment Inspection Area
            if (_lastAssessment != null) ...[
              Text(
                'نتائج الاستدلال والتقييم الفعلي:',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),

              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(color: AppColors.borderSoft),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowWarm,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الحالة: ${_lastAssessment!.passed ? "اجتاز (Pass)" : "لم يجتز (Fail)"}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: _lastAssessment!.passed
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            3,
                            (i) => Icon(
                              Icons.star_rounded,
                              color: i < _lastAssessment!.stars
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),

                    Text(
                      'الكلمة المستهدفة: ${_lastAssessment!.targetWordArabic}',
                    ),
                    Text(
                      'النص المكتشف عبر الذكاء الاصطناعي: "${_lastAssessment!.recognizedTranscript}"',
                    ),
                    Text(
                      'الدرجة الكلية: ${_lastAssessment!.overallScore}% | زمن الاستدلال: ${_lastAssessment!.latencyMs}ms',
                    ),
                    if (_lastAssessment!.clinicalErrorName != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'التشخيص الإكلينيكي: ${_lastAssessment!.clinicalErrorName}',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    SizedBox(height: 12.h),
                    const Divider(),
                    SizedBox(height: 8.h),

                    Text(
                      'مصفوفة المحاذاة الفونيمية (DP Alignment Matrix):',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),

                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _lastAssessment!.alignments.map((a) {
                        Color chipColor = Colors.green.shade50;
                        Color borderColor = Colors.green.shade300;
                        if (a.status == 'substituted') {
                          chipColor = Colors.orange.shade50;
                          borderColor = Colors.orange.shade300;
                        } else if (a.status == 'deleted') {
                          chipColor = Colors.red.shade50;
                          borderColor = Colors.red.shade300;
                        } else if (a.status == 'inserted') {
                          chipColor = Colors.purple.shade50;
                          borderColor = Colors.purple.shade300;
                        }

                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: chipColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${a.expectedArabic.isNotEmpty ? a.expectedArabic : "Ø"} -> ${a.recognizedToken?.arabicSymbol ?? "Ø"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '/${a.expectedPhoneme.isNotEmpty ? a.expectedPhoneme : "Ø"}/ -> /${a.recognizedToken?.symbol ?? "Ø"}/',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                a.status,
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'رسالة ياسر للطفل: ${_lastAssessment!.yasserFeedbackMessage}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
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
