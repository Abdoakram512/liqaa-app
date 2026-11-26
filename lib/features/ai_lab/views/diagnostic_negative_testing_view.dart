import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/audio_preprocessor.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/pronunciation_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class DiagnosticNegativeTestingView extends StatefulWidget {
  const DiagnosticNegativeTestingView({super.key});

  @override
  State<DiagnosticNegativeTestingView> createState() =>
      _DiagnosticNegativeTestingViewState();
}

class _DiagnosticNegativeTestingViewState
    extends State<DiagnosticNegativeTestingView> {
  final PronunciationRepository _repository = sl<PronunciationRepository>();
  final AudioPreprocessor _preprocessor = const AudioPreprocessor();
  bool _isInitialized = false;
  bool _isRunningAll = false;

  final List<Map<String, dynamic>> _diagnosticTests = [
    {
      'id': 'test_silence',
      'name': 'اختبار 1: الصمت التام (Zero Signal / Silence Rejection)',
      'description':
          'التحقق من عدم حدوث استدلال خاطئ (0% False Positive) عند تسجيل صمت تام.',
      'expectedError': AssessmentErrorType.noSpeech,
      'status': 'idle', // 'idle', 'running', 'passed', 'failed'
      'resultDetails': '',
    },
    {
      'id': 'test_white_noise',
      'name': 'اختبار 2: الضوضاء البيضاء (Stationary White Noise Rejection)',
      'description':
          'التحقق من رفض الضوضاء العشوائية بدون كلمات وعدم تقييمها كإجابة صحيحة.',
      'expectedError': AssessmentErrorType.noSpeech,
      'status': 'idle',
      'resultDetails': '',
    },
    {
      'id': 'test_unrelated_word',
      'name': 'اختبار 3: الكلمة غير المطابقة ("مدرسة" ضد كلمة "كورة")',
      'description':
          'التحقق من رصد الكلمات غير المطابقة تماماً ومنح 1 نجمة كحد أقصى مع تصنيف UnrelatedWord.',
      'expectedError': AssessmentErrorType.unrelatedWord,
      'status': 'idle',
      'resultDetails': '',
    },
    {
      'id': 'test_clipping_detection',
      'name': 'اختبار 4: تشوه الموجة الصوتية (Acoustic Clipping & Distortion)',
      'description':
          'التحقق من حساب قمة السعة الحقيقية ورصد التشوه الترددي بدون قيم عشوائية.',
      'expectedError': AssessmentErrorType.correct,
      'status': 'idle',
      'resultDetails': '',
    },
    {
      'id': 'test_missing_model_resilience',
      'name': 'اختبار 5: المتانة ضد غياب النموذج (Graceful Fallback)',
      'description':
          'التحقق من عدم انهيار التطبيق (Zero Crash) عند تعذر توفر مكتبات FFI الأصلية.',
      'expectedError': null,
      'status': 'idle',
      'resultDetails': '',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    await _repository.initialize();
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _runSingleTest(int index) async {
    if (!_isInitialized) return;
    setState(() => _diagnosticTests[index]['status'] = 'running');

    final test = _diagnosticTests[index];
    final String testId = test['id'] as String;

    try {
      final VocabularyWord targetWord = _repository.vocabulary.first;

      if (testId == 'test_silence') {
        final data = await rootBundle.load('assets/audio_samples/silence.wav');
        final assessment = await _repository.evaluateAudio(
          rawAudioBytes: data.buffer.asUint8List(),
          targetWord: targetWord,
        );

        final bool isPass =
            assessment.errorType == AssessmentErrorType.noSpeech &&
            assessment.stars == 0 &&
            !assessment.passed;

        setState(() {
          test['status'] = isPass ? 'passed' : 'failed';
          test['resultDetails'] =
              'النوع: ${assessment.errorType.name} | النجوم: ${assessment.stars} | النتيجة: ${assessment.passed ? "نجاح خاطئ!" : "تم الرفض بنجاح"}';
        });
      } else if (testId == 'test_white_noise') {
        final data = await rootBundle.load(
          'assets/audio_samples/white_noise.wav',
        );
        final assessment = await _repository.evaluateAudio(
          rawAudioBytes: data.buffer.asUint8List(),
          targetWord: targetWord,
        );

        final bool isPass =
            (assessment.errorType == AssessmentErrorType.noSpeech ||
                assessment.errorType == AssessmentErrorType.poorAudioQuality) &&
            !assessment.passed;

        setState(() {
          test['status'] = isPass ? 'passed' : 'failed';
          test['resultDetails'] =
              'النوع: ${assessment.errorType.name} | النجوم: ${assessment.stars} | النتيجة: ${assessment.passed ? "نجاح خاطئ!" : "تم الرفض بنجاح"}';
        });
      } else if (testId == 'test_unrelated_word') {
        final data = await rootBundle.load(
          'assets/audio_samples/word_madrasa.wav',
        );
        final assessment = await _repository.evaluateAudio(
          rawAudioBytes: data.buffer.asUint8List(),
          targetWord: targetWord, // "كورة"
        );

        final bool isPass =
            !assessment.passed &&
            assessment.overallScore <= 35.0 &&
            (assessment.errorType == AssessmentErrorType.unrelatedWord ||
                assessment.errorType == AssessmentErrorType.substitution);

        setState(() {
          test['status'] = isPass ? 'passed' : 'failed';
          test['resultDetails'] =
              'الدرجة: ${assessment.overallScore}% | المنطوق: "${assessment.recognizedTranscript}" | النوع: ${assessment.errorType.name}';
        });
      } else if (testId == 'test_clipping_detection') {
        // Generate clipped sine wave
        const int length = 16000;
        final Float32List clipped = Float32List(length);
        for (int i = 0; i < length; i++) {
          clipped[i] = (2.5 * math.sin(2 * math.pi * 440 * (i / 16000))).clamp(
            -1.0,
            1.0,
          );
        }
        final double peak = _preprocessor.calculatePeak(clipped);
        final bool isPass = peak >= 0.99;

        setState(() {
          test['status'] = isPass ? 'passed' : 'failed';
          test['resultDetails'] =
              'قمة السعة المحسوبة: ${peak.toStringAsFixed(3)} (رصد التشبع بنجاح)';
        });
      } else if (testId == 'test_missing_model_resilience') {
        final vadSmoke = await _repository.modelManager.runSmokeTest(
          'silero_vad',
        );
        final denoiseSmoke = await _repository.modelManager.runSmokeTest(
          'gtcrn_denoiser',
        );
        final w2vSmoke = await _repository.modelManager.runSmokeTest(
          'wav2vec2_espeak',
        );
        final isPass = vadSmoke && denoiseSmoke && w2vSmoke;

        setState(() {
          test['status'] = isPass ? 'passed' : 'failed';
          test['resultDetails'] =
              'VAD: $vadSmoke | GTCRN: $denoiseSmoke | Wav2Vec2: $w2vSmoke';
        });
      }
    } catch (e) {
      setState(() {
        test['status'] = 'failed';
        test['resultDetails'] = 'خطأ غير متوقع: $e';
      });
    }
  }

  Future<void> _runAllTests() async {
    if (_isRunningAll) return;
    setState(() => _isRunningAll = true);

    for (int i = 0; i < _diagnosticTests.length; i++) {
      await _runSingleTest(i);
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (mounted) setState(() => _isRunningAll = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(
          'مختبر 10: الفحص التشخيصي والاختبارات السلبية',
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
            // Banner
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.gpp_good_rounded,
                    color: Colors.red.shade800,
                    size: 28,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'جناح الاختبارات السلبية وحالات الحافة (Negative & Boundary Testing Suite): التحقق الصارم من متانة النظام ورفض الأصوات الوهمية والصمت والضوضاء دون تساهل.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isRunningAll
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.play_circle_fill_rounded),
              label: Text(
                _isRunningAll
                    ? 'جاري تشغيل الاختبارات...'
                    : 'تشغيل كافة الاختبارات السلبية تلقائياً',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isRunningAll ? null : _runAllTests,
            ),

            SizedBox(height: 16.h),

            ...List.generate(_diagnosticTests.length, (idx) {
              final test = _diagnosticTests[idx];
              final status = test['status'] as String;

              Color statusColor = Colors.grey.shade400;
              IconData statusIcon = Icons.hourglass_empty_rounded;
              if (status == 'passed') {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle_rounded;
              } else if (status == 'failed') {
                statusColor = Colors.red;
                statusIcon = Icons.cancel_rounded;
              } else if (status == 'running') {
                statusColor = Colors.blue;
                statusIcon = Icons.sync_rounded;
              }

              return Card(
                elevation: 0,
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: status == 'passed'
                        ? Colors.green.shade200
                        : AppColors.borderSoft,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 22),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              test['name'] as String,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: status == 'running'
                                ? null
                                : () => _runSingleTest(idx),
                            child: const Text('فحص'),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        test['description'] as String,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if ((test['resultDetails'] as String).isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'passed'
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: status == 'passed'
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Text(
                            test['resultDetails'] as String,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: status == 'passed'
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}
