import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'audio_preprocessor.dart';
import 'audio_recorder_service.dart';
import 'silero_vad_engine.dart';
import 'rnnoise_denoiser_engine.dart';
import 'phoneme_recognition_engine.dart';
import 'pronunciation_evaluator.dart';
import 'speech_to_text_engine.dart';
import 'ai_model_manager.dart';
import 'models/vocabulary_word.dart';
import 'models/audio_processing_result.dart';
import 'models/pronunciation_assessment.dart';

class PronunciationRepository {
  final AudioRecorderService recorder;
  final AudioPreprocessor preprocessor;
  final SileroVadEngine vadEngine;
  final RnnoiseDenoiserEngine denoiserEngine;
  final PhonemeRecognitionEngine phonemeEngine;
  final PronunciationEvaluator evaluator;
  final SpeechToTextEngine sttEngine;
  final AiModelManager modelManager;

  List<VocabularyWord> _vocabulary = [];
  bool _isInitialized = false;

  PronunciationRepository({
    AudioRecorderService? recorder,
    AudioPreprocessor? preprocessor,
    SileroVadEngine? vadEngine,
    RnnoiseDenoiserEngine? denoiserEngine,
    PhonemeRecognitionEngine? phonemeEngine,
    PronunciationEvaluator? evaluator,
    SpeechToTextEngine? sttEngine,
    AiModelManager? modelManager,
  }) : recorder = recorder ?? AudioRecorderService(),
       preprocessor = preprocessor ?? const AudioPreprocessor(),
       vadEngine = vadEngine ?? SileroVadEngine(),
       denoiserEngine = denoiserEngine ?? RnnoiseDenoiserEngine(),
       phonemeEngine = phonemeEngine ?? PhonemeRecognitionEngine(),
       evaluator = evaluator ?? const PronunciationEvaluator(),
       sttEngine = sttEngine ?? SpeechToTextEngine(),
       modelManager = modelManager ?? AiModelManager();

  bool get isInitialized => _isInitialized;
  List<VocabularyWord> get vocabulary => _vocabulary;

  /// Loads vocabulary dictionary and initializes real ONNX engines, syncing real model health.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await modelManager.initialize();
    await vadEngine.initialize();
    await denoiserEngine.initialize();
    await phonemeEngine.initialize();
    await sttEngine.initialize();

    modelManager.syncEngineStatus(
      vad: vadEngine,
      denoiser: denoiserEngine,
      phoneme: phonemeEngine,
      stt: sttEngine,
    );

    try {
      final String jsonStr = await rootBundle.loadString(
        'assets/pronunciation/egyptian_arabic_dictionary.json',
      );
      final Map<String, dynamic> data = json.decode(jsonStr);
      final List<dynamic> wordsList = data['words'] as List<dynamic>? ?? [];
      _vocabulary = wordsList
          .map((w) => VocabularyWord.fromJson(w as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PronunciationRepository] Dictionary load error: $e');
      _vocabulary = _getFallbackVocabulary();
    }

    _isInitialized = true;
    debugPrint(
      '[PronunciationRepository] Initialized with ${_vocabulary.length} words',
    );
  }

  /// Processes recorded WAV bytes through the blind on-device AI pipeline.
  /// Strictly distinguishes recording/format/model/inference failures from genuine silence.
  Future<PronunciationAssessment> evaluateAudio({
    required Uint8List rawAudioBytes,
    required VocabularyWord targetWord,
    bool? overrideDenoise,
  }) async {
    final Stopwatch sw = Stopwatch()..start();

    if (!_isInitialized) {
      await initialize();
    }

    if (rawAudioBytes.isEmpty) {
      sw.stop();
      return _systemFailure(
        word: targetWord,
        errorType: AssessmentErrorType.recordingFailed,
        clinicalName: 'ملف الصوت فارغ (Empty Recording Buffer)',
        stage: 'AudioCapture',
        detail: 'Stop recording returned 0 bytes.',
        userMessage: 'ملف التسجيل فارغ.. تأكد من إذن الميكروفون وجرب تاني.',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    // 1. Unified WAV validation, chunk parsing, downmix, & resampling to 16kHz mono Float32
    late final PreprocessedAudio audio;
    try {
      audio = preprocessor.preprocessWav(
        rawAudioBytes,
        targetSampleRate: 16000,
      );
    } on InvalidAudioFormatException catch (e) {
      sw.stop();
      return _systemFailure(
        word: targetWord,
        errorType: AssessmentErrorType.invalidAudioFormat,
        clinicalName: 'صيغة الصوت غير صالحة (Invalid WAV Format)',
        stage: 'AudioPreprocessor',
        detail: e.message,
        userMessage: 'تنسيق الصوت المسجّل غير سليم (${e.message}).',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    Float32List samples = preprocessor.removeDcOffset(audio.samples);
    final double rawRms = preprocessor.calculateRms(samples);
    final double rawPeak = preprocessor.calculatePeak(samples);
    final double rawSnr = preprocessor.estimateSnrDb(samples);

    // Extreme distortion / constant high-energy noise check
    if (rawSnr < 2.0 && rawRms > 0.08) {
      sw.stop();
      return PronunciationAssessment(
        targetWord: targetWord.id,
        targetWordArabic: targetWord.wordArabic,
        recognizedTranscript: '',
        overallScore: 0.0,
        stars: 0,
        errorType: AssessmentErrorType.poorAudioQuality,
        clinicalErrorName: 'جودة صوت منخفضة (Poor SNR / High Noise)',
        targetPhoneme: targetWord.targetPhoneme,
        alignments: _deletedAlignments(targetWord),
        recognizedPhonemes: const [],
        yasserFeedbackMessage:
            'في دوشة حواليك يا بطل! روح لمكان هادي وقول تاني.',
        yasserPose: 'thinking',
        latencyMs: sw.elapsedMilliseconds,
        passed: false,
      );
    }

    // Reject only dead digital silence before VAD; allow quiet padded recordings into Silero VAD
    if (rawPeak < 0.002) {
      sw.stop();
      return evaluator.evaluate(
        word: targetWord,
        recognizedTokens: const [],
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    // 2. Silero VAD on unscaled DC-removed signal (prevents gain-shifted VAD boundary clips)
    if (!vadEngine.isNativeAvailable) {
      sw.stop();
      return _systemFailure(
        word: targetWord,
        errorType: AssessmentErrorType.modelInitFailed,
        clinicalName: 'فشل تهيئة نموذج كشف الصوت (Silero VAD Unavailable)',
        stage: 'SileroVAD',
        detail: vadEngine.lastError ?? 'Native Silero VAD not loaded.',
        userMessage:
            'تعذّر تشغيل نموذج كشف الصوت (Silero VAD). راجع مختبر النماذج.',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    final VadAnalysisResult vad = vadEngine.analyze(samples);
    if (vad.errorMessage != null) {
      sw.stop();
      return _systemFailure(
        word: targetWord,
        errorType: AssessmentErrorType.inferenceFailed,
        clinicalName: 'فشل استدلال كشف الصوت (Silero VAD Error)',
        stage: 'SileroVAD',
        detail: vad.errorMessage!,
        userMessage: 'حصل خطأ أثناء تحليل نشاط الصوت (${vad.errorMessage}).',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    if (!vad.speechDetected ||
        vad.trimmedSamples == null ||
        vad.trimmedSamples!.isEmpty) {
      sw.stop();
      return evaluator.evaluate(
        word: targetWord,
        recognizedTokens: const [],
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    Float32List speechSamples = vad.trimmedSamples!;
    final double speechRms = preprocessor.calculateRms(speechSamples);
    if (speechRms < 0.0015) {
      sw.stop();
      return evaluator.evaluate(
        word: targetWord,
        recognizedTokens: const [],
        latencyMs: sw.elapsedMilliseconds,
      );
    }
    if (speechRms < 0.05) {
      speechSamples = preprocessor.normalizePeak(
        speechSamples,
        targetPeak: 0.7,
      );
    }

    // 3. Neural Speech Enhancement (GTCRN) or explicit/clean bypass
    // Ablation proved GTCRN improves heavy noise (SNR <= 14 dB) while attenuating clean consonants above 15 dB.
    final bool prevDenoiseEnabled = denoiserEngine.enabled;
    final bool enableDenoise =
        overrideDenoise ?? (prevDenoiseEnabled && rawSnr < 14.0);
    denoiserEngine.enabled = enableDenoise;
    late final DenoiseResult denoise;
    try {
      denoise = denoiserEngine.process(speechSamples);
    } finally {
      denoiserEngine.enabled = prevDenoiseEnabled;
    }
    if (!denoise.hasValidAudio) {
      sw.stop();
      return _systemFailure(
        word: targetWord,
        errorType: denoiserEngine.isNativeAvailable
            ? AssessmentErrorType.inferenceFailed
            : AssessmentErrorType.modelInitFailed,
        clinicalName: 'فشل عزل الضوضاء العصبي (GTCRN Error)',
        stage: 'GTCRNDenoiser',
        detail: denoise.errorMessage ?? 'GTCRN failed without details.',
        userMessage: 'تعذّر معالجة عزل الضوضاء: ${denoise.errorMessage}',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    final Float32List finalSamples = denoise.processedSamples;

    // 4. Genuine Blind Acoustic Phoneme Recognition (Wav2Vec2-eSpeak, ZERO TARGET LEAKAGE)
    if (!phonemeEngine.isNativeAvailable) {
      sw.stop();
      return _systemFailure(
        word: targetWord,
        errorType: AssessmentErrorType.modelInitFailed,
        clinicalName: 'نموذج الفونيمات غير مهيأ (Wav2Vec2-eSpeak Unavailable)',
        stage: 'PhonemeRecognition',
        detail:
            phonemeEngine.lastError ??
            'Wav2Vec2-eSpeak ONNX session not ready.',
        userMessage: 'تعذّر تشغيل نموذج تحليل الفونيمات الصوتي على الجهاز.',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    final PhonemeRecognitionResult phonemeResult = await phonemeEngine
        .recognizePhonemesDetailed(finalSamples);
    sw.stop();

    if (phonemeResult.hasError) {
      return _systemFailure(
        word: targetWord,
        errorType: AssessmentErrorType.inferenceFailed,
        clinicalName:
            'فشل استدلال الفونيمات الصوتي (Wav2Vec2 Inference Failed)',
        stage: 'PhonemeRecognition',
        detail: phonemeResult.errorMessage!,
        userMessage:
            'حصل خطأ أثناء استدلال الفونيمات: ${phonemeResult.errorMessage}',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    // 5. Clinical Alignment & Dynamic Programming Assessment
    return evaluator.evaluate(
      word: targetWord,
      recognizedTokens: phonemeResult.tokens,
      speechDetected: true,
      latencyMs: sw.elapsedMilliseconds,
    );
  }

  /// Detailed audio diagnostics for AI Lab views.
  /// Always stores valid RIFF/WAVE bytes in [trimmedAudioBytes] & [denoisedAudioBytes] for playback,
  /// and sets [denoisedAudioBytes] = null if denoising fails (NEVER substitutes original audio silently).
  AudioProcessingResult analyzeAudioForLab(Uint8List rawBytes) {
    if (rawBytes.isEmpty) {
      return AudioProcessingResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        durationMs: 0,
        averageRms: 0.0,
        peakAmplitude: 0.0,
        snrDb: 0.0,
        rawAudioBytes: rawBytes,
        waveformPoints: const [],
        isValidAudio: false,
        errorMessage: 'ملف الصوت فارغ (0 bytes).',
      );
    }

    late final PreprocessedAudio prep;
    try {
      prep = preprocessor.preprocessWav(
        rawBytes,
        targetSampleRate: 16000,
        allowHeaderlessPcm16Fallback: false,
      );
    } on InvalidAudioFormatException catch (e) {
      return AudioProcessingResult(
        speechDetected: false,
        speechStartMs: 0,
        speechEndMs: 0,
        durationMs: 0,
        averageRms: 0.0,
        peakAmplitude: 0.0,
        snrDb: 0.0,
        rawAudioBytes: rawBytes,
        waveformPoints: const [],
        isValidAudio: false,
        errorMessage: e.message,
      );
    }

    final Float32List samples = preprocessor.removeDcOffset(prep.samples);
    final double rms = preprocessor.calculateRms(samples);
    final double peak = preprocessor.calculatePeak(samples);
    final double snr = preprocessor.estimateSnrDb(samples);
    final List<double> waveform = preprocessor.downsampleForWaveform(
      samples,
      64,
    );

    // Match the game: only reject dead digital silence before Silero VAD.
    // Quiet recordings with short consonant peaks must reach the VAD.
    final VadAnalysisResult vad = peak < 0.002
        ? VadAnalysisResult(
            speechDetected: false,
            speechStartMs: 0,
            speechEndMs: 0,
            speechProbabilities: List<double>.filled(
              math.max(1, samples.length ~/ 512),
              0.0,
            ),
            isNativeModel: vadEngine.isNativeAvailable,
          )
        : vadEngine.analyze(samples);

    final Float32List? trimmed = vad.speechDetected ? vad.trimmedSamples : null;
    final Float32List denoiseInput = trimmed ?? samples;

    final DenoiseResult denoise = denoiserEngine.process(denoiseInput);
    final bool denoiseOk = denoise.hasValidAudio;

    final Uint8List? trimmedWav = trimmed != null && trimmed.isNotEmpty
        ? preprocessor.float32ToWav(trimmed, sampleRate: 16000)
        : null;
    final Uint8List? denoisedWav = denoiseOk
        ? preprocessor.float32ToWav(denoise.processedSamples, sampleRate: 16000)
        : null;

    final List<double> denoisedWave = denoiseOk
        ? preprocessor.downsampleForWaveform(denoise.processedSamples, 64)
        : const [];

    final String? stageErr = vad.errorMessage ?? denoise.errorMessage;

    return AudioProcessingResult(
      speechDetected: vad.speechDetected,
      speechStartMs: vad.speechStartMs,
      speechEndMs: vad.speechEndMs,
      durationMs: prep.durationMs,
      averageRms: double.parse(rms.toStringAsFixed(4)),
      peakAmplitude: double.parse(peak.toStringAsFixed(3)),
      snrDb: double.parse(snr.toStringAsFixed(1)),
      snrImprovementDb: denoiseOk
          ? double.parse(denoise.snrImprovementDb.toStringAsFixed(1))
          : 0.0,
      rawAudioBytes: prep.wavBytes,
      trimmedAudioBytes: trimmedWav,
      denoisedAudioBytes: denoisedWav,
      waveformPoints: waveform,
      denoisedWaveformPoints: denoisedWave,
      sampleRate: prep.sourceMetadata.sampleRate,
      channels: prep.sourceMetadata.channels,
      bitsPerSample: prep.sourceMetadata.bitsPerSample,
      sampleCount: prep.sampleCount,
      clippingCount: prep.clippingCount,
      denoisedRms: denoiseOk
          ? double.parse(denoise.rmsAfter.toStringAsFixed(4))
          : 0.0,
      denoisedPeakAmplitude: denoiseOk
          ? double.parse(denoise.peakAfter.toStringAsFixed(3))
          : 0.0,
      denoiserFilterType: denoise.filterType,
      vadSegments: vad.segments
          .asMap()
          .entries
          .map(
            (e) => VadSegmentSummary(
              index: e.key,
              startMs: e.value.startMs,
              endMs: e.value.endMs,
              startSample: e.value.startSample,
              sampleCount: e.value.sampleCount,
              rms: double.parse(e.value.rms.toStringAsFixed(4)),
            ),
          )
          .toList(),
      isValidAudio: stageErr == null,
      errorMessage: stageErr,
    );
  }

  PronunciationAssessment _systemFailure({
    required VocabularyWord word,
    required AssessmentErrorType errorType,
    required String clinicalName,
    required String stage,
    required String detail,
    required String userMessage,
    required int latencyMs,
  }) {
    return PronunciationAssessment(
      targetWord: word.id,
      targetWordArabic: word.wordArabic,
      recognizedTranscript: '',
      overallScore: 0.0,
      stars: 0,
      errorType: errorType,
      clinicalErrorName: clinicalName,
      targetPhoneme: word.targetPhoneme,
      alignments: const [],
      recognizedPhonemes: const [],
      yasserFeedbackMessage: userMessage,
      yasserPose: 'thinking',
      latencyMs: latencyMs,
      passed: false,
      pipelineStageFailed: stage,
      diagnosticError: detail,
    );
  }

  List<PhonemeAlignment> _deletedAlignments(VocabularyWord word) {
    return word.expectedPhonemes.asMap().entries.map((e) {
      final int idx = e.key;
      final String exp = e.value;
      final String expAr = idx < word.expectedArabicPhonemes.length
          ? word.expectedArabicPhonemes[idx]
          : exp;
      return PhonemeAlignment(
        expectedPhoneme: exp,
        expectedArabic: expAr,
        recognizedToken: null,
        isMatch: false,
        status: 'deleted',
      );
    }).toList();
  }

  List<VocabularyWord> _getFallbackVocabulary() {
    return const [
      VocabularyWord(
        id: 'word_kora',
        wordArabic: 'كورة',
        wordTransliteration: 'Koora',
        meaningEn: 'Ball',
        targetPhoneme: 'ك',
        targetPhonemeIpa: 'k',
        phonemeCategory: 'صوت طبقي انفجاري (Velar Plosive)',
        difficultyLevel: 1,
        expectedPhonemes: ['k', 'uː', 'r', 'a'],
        expectedArabicPhonemes: ['ك', 'و', 'ر', 'ة'],
        yasserTip: 'افتح بؤك وخلّي صوت الكاف يطلع من ورا: كـ كـ كورة!',
        commonChildErrors: [
          ChildErrorRule(
            pronouncedWord: 'تورة',
            errorType: 'substitution',
            substitutedPhoneme: 'ت',
            targetPhoneme: 'ك',
            clinicalName: 'Fronting (إبدال أمامي)',
            feedbackAr:
                'شاطر جداً! بس بدّلنا صوت الـ ك بالـ ت.. يلا نطلع الكاف: كـ كورة!',
            yasserPose: 'thinking',
          ),
        ],
      ),
      VocabularyWord(
        id: 'word_samaka',
        wordArabic: 'سمكة',
        wordTransliteration: 'Samaka',
        meaningEn: 'Fish',
        targetPhoneme: 'س',
        targetPhonemeIpa: 's',
        phonemeCategory: 'صوت لثوي احتكاكي مهموس (Alveolar Fricative)',
        difficultyLevel: 1,
        expectedPhonemes: ['s', 'm', 'k', 'a'],
        expectedArabicPhonemes: ['س', 'م', 'ك', 'ة'],
        yasserTip: 'اقفل سنانك بالراحة وطلع هواء زي الصفارة: سسسـ سمكة!',
        commonChildErrors: [
          ChildErrorRule(
            pronouncedWord: 'ثمكة',
            errorType: 'substitution',
            substitutedPhoneme: 'ث',
            targetPhoneme: 'س',
            clinicalName: 'Interdental Lisp (لدغة بين الأسنان)',
            feedbackAr:
                'ممتاز! بس لسانك طلع برة سنانك.. خلّي لسانك جوة واصفر: سسسـ سمكة!',
            yasserPose: 'thinking',
          ),
        ],
      ),
      VocabularyWord(
        id: 'word_arnab',
        wordArabic: 'أرنب',
        wordTransliteration: 'Arnab',
        meaningEn: 'Rabbit',
        targetPhoneme: 'ر',
        targetPhonemeIpa: 'r',
        phonemeCategory: 'صوت لثوي تكراري (Alveolar Trill)',
        difficultyLevel: 2,
        expectedPhonemes: ['ʔ', 'r', 'n', 'b'],
        expectedArabicPhonemes: ['أ', 'ر', 'ن', 'ب'],
        yasserTip: 'خلّي طرف لسانك يرفرف ورا سنانك: رررـ أرنب!',
        commonChildErrors: [
          ChildErrorRule(
            pronouncedWord: 'أنلب',
            errorType: 'substitution',
            substitutedPhoneme: 'ل',
            targetPhoneme: 'ر',
            clinicalName: 'Lateralization (لدغة الراء إلى لام)',
            feedbackAr:
                'برافو يا بطل! بدّلنا صوت الـ ر بالـ ل.. يلا نخلّي لساننا يهتز: أرررنب!',
            yasserPose: 'thinking',
          ),
        ],
      ),
    ];
  }
}
