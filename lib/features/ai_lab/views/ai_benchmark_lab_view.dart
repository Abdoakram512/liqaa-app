import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../../../core/ai/models/audio_processing_result.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/pronunciation_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

class _BenchmarkFixture {
  final String id;
  final String title;
  final String category;
  final String sourcePath;
  final bool isAsset;
  final String targetWordArabic;
  final String expectedOutcome; // 'pass', 'fail', 'reject_silence'
  final String expectedIpa;

  const _BenchmarkFixture({
    required this.id,
    required this.title,
    required this.category,
    required this.sourcePath,
    required this.isAsset,
    required this.targetWordArabic,
    required this.expectedOutcome,
    this.expectedIpa = '',
  });
}

class _ExecutedBenchmarkItem {
  final _BenchmarkFixture fixture;
  final AudioProcessingResult? audioResult;
  final PronunciationAssessment? assessment;
  final List<String> recognizedIpa;
  final String whisperText;
  final int vadLatencyMs;
  final int denoiseLatencyMs;
  final int phonemeLatencyMs;
  final int totalLatencyMs;
  final bool matchedExpectation;
  final String? failedStage;

  const _ExecutedBenchmarkItem({
    required this.fixture,
    this.audioResult,
    this.assessment,
    required this.recognizedIpa,
    required this.whisperText,
    required this.vadLatencyMs,
    required this.denoiseLatencyMs,
    required this.phonemeLatencyMs,
    required this.totalLatencyMs,
    required this.matchedExpectation,
    this.failedStage,
  });

  Map<String, dynamic> toJson() => {
        'id': fixture.id,
        'category': fixture.category,
        'target_word': fixture.targetWordArabic,
        'expected_outcome': fixture.expectedOutcome,
        'expected_ipa': fixture.expectedIpa,
        'recognized_ipa': recognizedIpa,
        'whisper_text': whisperText,
        'vad_detected': audioResult?.speechDetected,
        'denoiser_filter': audioResult?.denoiserFilterType,
        'score': assessment?.overallScore,
        'passed': assessment?.passed,
        'error_type': assessment?.errorType.name,
        'matched_expectation': matchedExpectation,
        'failed_stage': failedStage,
        'latency_ms': totalLatencyMs,
      };
}

enum _EngineRunMode { fullPipeline, vadOnly, denoiserOnly, phonemeOnly, sttOnly }

class AiBenchmarkLabView extends StatefulWidget {
  const AiBenchmarkLabView({super.key});

  @override
  State<AiBenchmarkLabView> createState() => _AiBenchmarkLabViewState();
}

class _AiBenchmarkLabViewState extends State<AiBenchmarkLabView> {
  final PronunciationRepository _repository = sl<PronunciationRepository>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isInitialized = false;
  bool _isRunning = false;
  bool _onlyShowFailures = false;
  String _selectedCategory = 'all';
  _EngineRunMode _runMode = _EngineRunMode.fullPipeline;

  int _progressDone = 0;
  int _progressTotal = 0;
  double _currentRssMb = 0.0;

  List<_BenchmarkFixture> _fixtures = const [];
  final List<_ExecutedBenchmarkItem> _executed = [];

  @override
  void initState() {
    super.initState();
    _initLab();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initLab() async {
    await _repository.initialize();
    final loaded = await _discoverFixtures();
    if (!mounted) return;
    setState(() {
      _fixtures = loaded;
      _currentRssMb = _readRssMb();
      _isInitialized = true;
    });
  }

  double _readRssMb() {
    try {
      return double.parse((ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(1));
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<_BenchmarkFixture>> _discoverFixtures() async {
    final list = <_BenchmarkFixture>[];

    // Prefer on-disk frozen 100-sample benchmark manifest when running on desktop/dev environment
    final manifestFile = File('benchmarks/audio/manifest.jsonl');
    if (manifestFile.existsSync()) {
      for (final line in manifestFile.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final j = jsonDecode(line) as Map<String, dynamic>;
        final path = j['file_path'] as String;
        if (!File(path).existsSync()) continue;
        final exp = j['expected_outcome'] as String? ?? '';
        final mappedOutcome = (exp == 'pass' || exp == 'detect_speech_and_evaluate' || exp == 'detect_speech_and_denoise' || exp == 'preprocess_and_evaluate' || exp == 'transcribe_and_phonemes' || exp == 'detect_speech_and_phonemes')
            ? 'pass'
            : ((exp.startsWith('reject_')) ? 'reject_silence' : 'fail');
        list.add(_BenchmarkFixture(
          id: j['sample_id'] as String,
          title: '${j['sample_id']}: ${j['actual_spoken_word']}',
          category: j['category'] as String,
          sourcePath: path,
          isAsset: false,
          targetWordArabic: (j['target_word'] as String? ?? '').isNotEmpty
              ? j['target_word'] as String
              : 'كورة',
          expectedOutcome: mappedOutcome,
          expectedIpa: j['reference_ipa'] as String? ?? '',
        ));
      }
      if (list.isNotEmpty) return list;
    }

    // Mobile/bundled asset fixtures (always available offline in APK)
    list.addAll(const [
      _BenchmarkFixture(
        id: 'ASSET_KORA',
        title: 'كورة (عينة سليمة)',
        category: 'speech_correct',
        sourcePath: 'assets/audio_samples/correct_kora.wav',
        isAsset: true,
        targetWordArabic: 'كورة',
        expectedOutcome: 'pass',
        expectedIpa: 'k uː r a',
      ),
      _BenchmarkFixture(
        id: 'ASSET_TORA',
        title: 'تورة ضد كورة (Fronting)',
        category: 'speech_error',
        sourcePath: 'assets/audio_samples/error_tora.wav',
        isAsset: true,
        targetWordArabic: 'كورة',
        expectedOutcome: 'fail',
        expectedIpa: 't uː r a',
      ),
      _BenchmarkFixture(
        id: 'ASSET_ARNAB',
        title: 'أرنب (عينة سليمة)',
        category: 'speech_correct',
        sourcePath: 'assets/audio_samples/correct_arnab.wav',
        isAsset: true,
        targetWordArabic: 'أرنب',
        expectedOutcome: 'pass',
        expectedIpa: 'ʔ r n b',
      ),
      _BenchmarkFixture(
        id: 'ASSET_ANLAB',
        title: 'أنلب ضد أرنب (Lateralization)',
        category: 'speech_error',
        sourcePath: 'assets/audio_samples/error_anlab.wav',
        isAsset: true,
        targetWordArabic: 'أرنب',
        expectedOutcome: 'fail',
        expectedIpa: 'ʔ l b',
      ),
      _BenchmarkFixture(
        id: 'ASSET_MADRASA',
        title: 'مدرسة ضد كورة (Unrelated)',
        category: 'unrelated_word',
        sourcePath: 'assets/audio_samples/word_madrasa.wav',
        isAsset: true,
        targetWordArabic: 'كورة',
        expectedOutcome: 'fail',
      ),
      _BenchmarkFixture(
        id: 'ASSET_ADULT_AR',
        title: 'عينة كلام عربي بشري (Adult)',
        category: 'adult_arabic',
        sourcePath: 'assets/audio_samples/human_arabic_adult.wav',
        isAsset: true,
        targetWordArabic: 'كورة',
        expectedOutcome: 'fail',
      ),
      _BenchmarkFixture(
        id: 'ASSET_SILENCE',
        title: 'صمت تام (Silence)',
        category: 'silence_noise',
        sourcePath: 'assets/audio_samples/silence.wav',
        isAsset: true,
        targetWordArabic: 'كورة',
        expectedOutcome: 'reject_silence',
      ),
      _BenchmarkFixture(
        id: 'ASSET_WHITE_NOISE',
        title: 'ضوضاء بيضاء (White Noise)',
        category: 'silence_noise',
        sourcePath: 'assets/audio_samples/white_noise.wav',
        isAsset: true,
        targetWordArabic: 'كورة',
        expectedOutcome: 'reject_silence',
      ),
    ]);
    return list;
  }

  Future<Uint8List> _readFixtureBytes(_BenchmarkFixture f) async {
    if (f.isAsset) {
      final bd = await rootBundle.load(f.sourcePath);
      return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    }
    return File(f.sourcePath).readAsBytes();
  }

  VocabularyWord _findTargetWord(String arabic) {
    for (final w in _repository.vocabulary) {
      if (w.wordArabic == arabic || w.wordArabic.replaceFirst('ال', '') == arabic.replaceFirst('ال', '')) {
        return w;
      }
    }
    final clean = arabic.split('');
    return VocabularyWord(
      id: 'bench_$arabic',
      wordArabic: arabic,
      wordTransliteration: arabic,
      meaningEn: arabic,
      targetPhoneme: clean.isNotEmpty ? clean.first : 'ك',
      targetPhonemeIpa: _repository.phonemeEngine.mapArToIpa(clean.isNotEmpty ? clean.first : 'ك'),
      phonemeCategory: 'Benchmark',
      difficultyLevel: 1,
      expectedPhonemes: clean.map(_repository.phonemeEngine.mapArToIpa).toList(),
      expectedArabicPhonemes: clean,
      yasserTip: '',
    );
  }

  Future<void> _runBenchmark() async {
    if (!_isInitialized || _isRunning) return;
    final selected = _selectedCategory == 'all'
        ? _fixtures
        : _fixtures.where((f) => f.category == _selectedCategory).toList();
    if (selected.isEmpty) return;

    setState(() {
      _isRunning = true;
      _executed.clear();
      _progressDone = 0;
      _progressTotal = selected.length;
    });

    for (final fx in selected) {
      if (!mounted) break;
      final swTotal = Stopwatch()..start();
      try {
        final rawBytes = await _readFixtureBytes(fx);
        final prep = _repository.preprocessor.preprocessWav(rawBytes, targetSampleRate: 16000);
        final audioRes = _repository.analyzeAudioForLab(rawBytes);

        int vadMs = 0;
        int denMs = 0;
        int phMs = 0;
        List<String> recIpa = const [];
        String sttText = '';
        PronunciationAssessment? assess;
        String? failedStage = audioRes.errorMessage != null ? 'Audio/VAD/Denoiser' : null;

        if (_runMode == _EngineRunMode.vadOnly) {
          final sw = Stopwatch()..start();
          final v = _repository.vadEngine.analyze(prep.samples);
          sw.stop();
          vadMs = sw.elapsedMilliseconds;
          if (v.errorMessage != null) failedStage = 'SileroVAD';
        } else if (_runMode == _EngineRunMode.denoiserOnly) {
          final sw = Stopwatch()..start();
          final d = _repository.denoiserEngine.process(prep.samples);
          sw.stop();
          denMs = sw.elapsedMilliseconds;
          if (!d.hasValidAudio) failedStage = 'GTCRN';
        } else if (_runMode == _EngineRunMode.phonemeOnly) {
          final ph = await _repository.phonemeEngine.recognizePhonemesDetailed(prep.samples);
          phMs = ph.latencyMs;
          recIpa = ph.tokens.map((t) => t.symbol).toList();
          if (ph.hasError) failedStage = 'Wav2Vec2-eSpeak';
        } else if (_runMode == _EngineRunMode.sttOnly) {
          final stt = await _repository.sttEngine.transcribe(prep.samples);
          sttText = stt.text;
          phMs = stt.latencyMs;
          if (stt.hasError) failedStage = 'WhisperTiny';
        } else {
          final target = _findTargetWord(fx.targetWordArabic);
          assess = await _repository.evaluateAudio(rawAudioBytes: rawBytes, targetWord: target);
          recIpa = assess.recognizedPhonemes.map((t) => t.symbol).toList();
          failedStage = assess.pipelineStageFailed ?? failedStage;
        }

        swTotal.stop();

        bool matched = true;
        if (assess != null) {
          if (fx.expectedOutcome == 'pass') {
            matched = assess.passed;
          } else if (fx.expectedOutcome == 'reject_silence') {
            matched = !assess.passed &&
                (assess.errorType == AssessmentErrorType.noSpeech ||
                    assess.errorType == AssessmentErrorType.poorAudioQuality);
          } else {
            matched = !assess.passed && !assess.errorType.isSystemFailure;
          }
        } else if (audioRes.errorMessage != null) {
          matched = false;
        }

        _executed.add(_ExecutedBenchmarkItem(
          fixture: fx,
          audioResult: audioRes,
          assessment: assess,
          recognizedIpa: recIpa,
          whisperText: sttText,
          vadLatencyMs: vadMs,
          denoiseLatencyMs: denMs,
          phonemeLatencyMs: phMs,
          totalLatencyMs: swTotal.elapsedMilliseconds,
          matchedExpectation: matched,
          failedStage: failedStage,
        ));
      } catch (e) {
        swTotal.stop();
        _executed.add(_ExecutedBenchmarkItem(
          fixture: fx,
          recognizedIpa: const [],
          whisperText: '',
          vadLatencyMs: 0,
          denoiseLatencyMs: 0,
          phonemeLatencyMs: 0,
          totalLatencyMs: swTotal.elapsedMilliseconds,
          matchedExpectation: false,
          failedStage: 'Exception: $e',
        ));
      }

      if (mounted) {
        setState(() {
          _progressDone++;
          _currentRssMb = _readRssMb();
        });
      }
      await Future.delayed(Duration.zero);
    }

    if (mounted) {
      setState(() => _isRunning = false);
    }
  }

  Map<String, int> _computeConfusionCounts() {
    final counts = <String, int>{};
    for (final item in _executed) {
      final assess = item.assessment;
      if (assess == null) continue;
      for (final a in assess.alignments) {
        if (a.status == 'substituted' && a.recognizedToken != null) {
          final k = '${a.expectedPhoneme} -> ${a.recognizedToken!.symbol}';
          counts[k] = (counts[k] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  String _buildCsvExport() {
    final buf = StringBuffer('id,category,target,expected_outcome,error_type,score,passed,matched,failed_stage,latency_ms,recognized_ipa\n');
    for (final e in _executed) {
      buf.writeln(
        '${e.fixture.id},${e.fixture.category},${e.fixture.targetWordArabic},${e.fixture.expectedOutcome},'
        '${e.assessment?.errorType.name ?? "-"},${e.assessment?.overallScore ?? "-"},${e.assessment?.passed ?? "-"},'
        '${e.matchedExpectation},"${e.failedStage ?? ""}",${e.totalLatencyMs},"${e.recognizedIpa.join(" ")}"',
      );
    }
    return buf.toString();
  }

  String _buildJsonExport() {
    return const JsonEncoder.withIndent('  ').convert({
      'timestamp': DateTime.now().toIso8601String(),
      'run_mode': _runMode.name,
      'category_filter': _selectedCategory,
      'rss_mb': _currentRssMb,
      'total_executed': _executed.length,
      'matched_expectation': _executed.where((e) => e.matchedExpectation).length,
      'confusion_pairs': _computeConfusionCounts(),
      'items': _executed.map((e) => e.toJson()).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['all', ..._fixtures.map((f) => f.category).toSet()];
    final displayed = _onlyShowFailures ? _executed.where((e) => !e.matchedExpectation).toList() : _executed;
    final confPairs = _computeConfusionCounts();
    final matchedCount = _executed.where((e) => e.matchedExpectation).length;
    final latencies = _executed.map((e) => e.totalLatencyMs).toList()..sort();
    final meanLat = latencies.isEmpty ? 0 : (latencies.reduce((a, b) => a + b) / latencies.length).round();
    final p95Lat = latencies.isEmpty ? 0 : latencies[((latencies.length - 1) * 0.95).round()];

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('11. لوحة معايير الأداء الشاملة (Benchmark Lab)'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                // Controls card
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تشغيل نماذج الذكاء الاصطناعي الحقيقية (بيانات حية غير مخزنة مسبقاً)',
                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                      SizedBox(height: 10.h),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'تصفية الفئة (Category)', border: OutlineInputBorder()),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: _isRunning ? null : (v) => setState(() => _selectedCategory = v ?? 'all'),
                      ),
                      SizedBox(height: 10.h),
                      DropdownButtonFormField<_EngineRunMode>(
                        initialValue: _runMode,
                        decoration: const InputDecoration(labelText: 'نطاق التشغيل (Engine / Pipeline)', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: _EngineRunMode.fullPipeline, child: Text('Full Pipeline (VAD + GTCRN + Wav2Vec2 + DP)')),
                          DropdownMenuItem(value: _EngineRunMode.vadOnly, child: Text('Silero VAD Only')),
                          DropdownMenuItem(value: _EngineRunMode.denoiserOnly, child: Text('GTCRN Denoiser Only')),
                          DropdownMenuItem(value: _EngineRunMode.phonemeOnly, child: Text('Wav2Vec2-eSpeak Phoneme Only')),
                          DropdownMenuItem(value: _EngineRunMode.sttOnly, child: Text('Whisper Tiny STT Only')),
                        ],
                        onChanged: _isRunning ? null : (v) => setState(() => _runMode = v ?? _EngineRunMode.fullPipeline),
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isRunning ? null : _runBenchmark,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(_isRunning ? 'جاري التنفيذ ($_progressDone/$_progressTotal)...' : 'تشغيل الاختبار الفعلي'),
                            ),
                          ),
                        ],
                      ),
                      if (_isRunning || _progressTotal > 0) ...[
                        SizedBox(height: 8.h),
                        LinearProgressIndicator(value: _progressTotal > 0 ? _progressDone / _progressTotal : 0),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // Live Stats Card
                if (_executed.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نتائج التنفيذ الفعلي: $matchedCount / ${_executed.length} مطابق '
                          '(${(_executed.isEmpty ? 0 : matchedCount * 100 / _executed.length).toStringAsFixed(1)}%)',
                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'متوسط الزمن: ${meanLat}ms | P95: ${p95Lat}ms | Process RSS: $_currentRssMb MB',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        if (confPairs.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Text('أكثر إبدالات الفونيمات المرصودة:', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                          Wrap(
                            spacing: 6.w,
                            children: (confPairs.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                                .take(8)
                                .map((e) => Chip(label: Text('${e.key}: ${e.value}', style: TextStyle(fontSize: 11.sp))))
                                .toList(),
                          ),
                        ],
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text('عرض الإخفاقات والأخطاء فقط (${_executed.length - matchedCount})', style: AppTextStyles.bodySmall),
                          value: _onlyShowFailures,
                          onChanged: (v) => setState(() => _onlyShowFailures = v),
                        ),
                        Wrap(
                          spacing: 8.w,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.table_chart_rounded, size: 16),
                              label: const Text('تصدير CSV'),
                              onPressed: () {
                                // ignore: deprecated_member_use
                                Share.share(_buildCsvExport(), subject: 'LIQAA Benchmark CSV');
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.code_rounded, size: 16),
                              label: const Text('تصدير JSON'),
                              onPressed: () {
                                // ignore: deprecated_member_use
                                Share.share(_buildJsonExport(), subject: 'LIQAA Benchmark JSON');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],

                // Per-sample items
                ...displayed.map((item) {
                  final assess = item.assessment;
                  final audio = item.audioResult;
                  return Card(
                    margin: EdgeInsets.only(bottom: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: item.matchedExpectation ? Colors.green.shade300 : Colors.red.shade300),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(item.fixture.title, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              Text('${item.totalLatencyMs}ms', style: AppTextStyles.bodySmall),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'الفئة: ${item.fixture.category} | الهدف: ${item.fixture.targetWordArabic} | المتوقع: ${item.fixture.expectedOutcome}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                          if (item.fixture.expectedIpa.isNotEmpty || item.recognizedIpa.isNotEmpty)
                            Text(
                              'IPA متوقع: [${item.fixture.expectedIpa}] -> فعلي: [${item.recognizedIpa.join(" ")}]',
                              style: AppTextStyles.bodySmall,
                            ),
                          if (item.whisperText.isNotEmpty)
                            Text('Whisper STT: "${item.whisperText}"', style: AppTextStyles.bodySmall),
                          if (assess != null)
                            Text(
                              'النتيجة: ${assess.errorType.name} | الدرجة: ${assess.overallScore}% | اجتاز: ${assess.passed}',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: item.matchedExpectation ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          if (item.failedStage != null)
                            Text('المرحلة المتعطلة: ${item.failedStage}', style: AppTextStyles.bodySmall.copyWith(color: Colors.red.shade900)),
                          SizedBox(height: 6.h),
                          Wrap(
                            spacing: 8.w,
                            children: [
                              if (audio != null && audio.rawAudioBytes.isNotEmpty)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.volume_up_rounded, size: 16),
                                  label: const Text('الأصلي'),
                                  onPressed: () => _audioPlayer.play(BytesSource(audio.rawAudioBytes)),
                                ),
                              if (audio?.denoisedAudioBytes != null && audio!.denoisedAudioBytes!.isNotEmpty)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                                  label: const Text('المعالج'),
                                  onPressed: () => _audioPlayer.play(BytesSource(audio.denoisedAudioBytes!)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
