import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'ai_inference_worker.dart';
import 'audio_preprocessor.dart';
import 'audio_recorder_service.dart';
import 'silero_vad_engine.dart';
import 'rnnoise_denoiser_engine.dart';
import 'phoneme_recognition_engine.dart';
import 'pronunciation_evaluator.dart';
import 'speech_to_text_engine.dart';
import 'ai_model_manager.dart';
import 'models/lab_task_mode.dart';
import 'models/phoneme_token.dart';
import 'models/vocabulary_word.dart';
import 'models/audio_processing_result.dart';
import 'models/pronunciation_assessment.dart';

class TaskAnalysisOutput {
  final AudioProcessingResult audioResult;
  final PhonemeRecognitionResult? phonemeResult;
  final SttResult? sttResult;
  final PronunciationAssessment? assessment;
  final List<PhonemeToken> rawPhonemes;
  final LabExecutionTelemetry telemetry;

  const TaskAnalysisOutput({
    required this.audioResult,
    this.phonemeResult,
    this.sttResult,
    this.assessment,
    this.rawPhonemes = const [],
    required this.telemetry,
  });
}

class PronunciationRepository {
  final AudioRecorderService recorder;
  final AudioPreprocessor preprocessor;
  final SileroVadEngine vadEngine;
  final RnnoiseDenoiserEngine denoiserEngine;
  final PhonemeRecognitionEngine phonemeEngine;
  final PronunciationEvaluator evaluator;
  final SpeechToTextEngine sttEngine;
  final AiModelManager modelManager;
  final AiInferenceWorker? _worker;
  final bool useBackgroundWorker;

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
    AiInferenceWorker? worker,
    this.useBackgroundWorker = false,
  }) : recorder = recorder ?? AudioRecorderService(),
       preprocessor = preprocessor ?? const AudioPreprocessor(),
       vadEngine = vadEngine ?? SileroVadEngine(),
       denoiserEngine = denoiserEngine ?? RnnoiseDenoiserEngine(),
       phonemeEngine = phonemeEngine ?? PhonemeRecognitionEngine(),
       evaluator = evaluator ?? const PronunciationEvaluator(),
       sttEngine = sttEngine ?? SpeechToTextEngine(),
       modelManager = modelManager ?? AiModelManager(),
       _worker = worker ?? (useBackgroundWorker ? AiInferenceWorker() : null);

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

    // Prepare persistent off-UI inference worker if enabled and native paths resolved.
    if (useBackgroundWorker &&
        _worker != null &&
        phonemeEngine.isNativeAvailable &&
        phonemeEngine.modelPath != null &&
        phonemeEngine.vocabPath != null) {
      await _worker.initialize(
        wav2vecModelPath: phonemeEngine.modelPath,
        wav2vecVocabPath: phonemeEngine.vocabPath,
        whisperEncoderPath: sttEngine.encoderPath,
        whisperDecoderPath: sttEngine.decoderPath,
        whisperTokensPath: sttEngine.tokensPath,
      );
    }

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
      return PronunciationAssessment(
        targetWord: targetWord.id,
        targetWordArabic: targetWord.wordArabic,
        recognizedTranscript: '',
        overallScore: 0.0,
        stars: 0,
        errorType: AssessmentErrorType.noSpeech,
        clinicalErrorName:
            'صمت رقمي تام (Digital Silence: peak=${rawPeak.toStringAsFixed(4)})',
        targetPhoneme: targetWord.targetPhoneme,
        alignments: _deletedAlignments(targetWord),
        recognizedPhonemes: const [],
        yasserFeedbackMessage:
            'المايك لم يلتقط أي صوت (إشارة صامتة تماماً).. تأكد من عدم كتم المايك وتحدث بوضوح!',
        yasserPose: 'thinking',
        latencyMs: sw.elapsedMilliseconds,
        passed: false,
        pipelineStageFailed: 'AudioSignalCheck',
        diagnosticError:
            'Raw peak amplitude ${rawPeak.toStringAsFixed(5)} below digital silence gate 0.002.',
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
      return PronunciationAssessment(
        targetWord: targetWord.id,
        targetWordArabic: targetWord.wordArabic,
        recognizedTranscript: '',
        overallScore: 0.0,
        stars: 0,
        errorType: AssessmentErrorType.poorAudioQuality,
        clinicalErrorName:
            'صوت ضعيف جداً (Weak Audio RMS=${speechRms.toStringAsFixed(5)})',
        targetPhoneme: targetWord.targetPhoneme,
        alignments: _deletedAlignments(targetWord),
        recognizedPhonemes: const [],
        yasserFeedbackMessage:
            'الصوت منخفض جداً.. قرّب شوية من المايك وقول الكلمة بصوت أوضح!',
        yasserPose: 'thinking',
        latencyMs: sw.elapsedMilliseconds,
        passed: false,
        pipelineStageFailed: 'WeakSignalCheck',
        diagnosticError:
            'Trimmed speech RMS ${speechRms.toStringAsFixed(5)} below minimum gate 0.0015.',
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

    final PhonemeRecognitionResult phonemeResult =
        await _recognizePhonemesOffUiIfReady(finalSamples);
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

  Future<PhonemeRecognitionResult> _recognizePhonemesOffUiIfReady(
    Float32List samples,
  ) async {
    if (useBackgroundWorker && _worker != null && _worker.isReady) {
      final workerRes = await _worker.recognizePhonemes(samples);
      if (workerRes.isNativeModel || !workerRes.hasError) {
        return workerRes;
      }
    }
    return phonemeEngine.recognizePhonemesDetailed(samples);
  }

  Future<SttResult> _transcribeOffUiIfReady(Float32List samples) async {
    if (useBackgroundWorker && _worker != null && _worker.isReady) {
      final workerRes = await _worker.transcribe(samples);
      if (workerRes.isModelInference || !workerRes.hasError) {
        return workerRes;
      }
    }
    return sttEngine.transcribe(samples);
  }

  double _computeNonZeroRatio(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    int nonZero = 0;
    for (int i = 0; i < samples.length; i++) {
      if (samples[i].abs() > 1e-5) nonZero++;
    }
    return double.parse((nonZero / samples.length).toStringAsFixed(4));
  }

  /// Single-decode task-routed execution eliminating duplicate WAV decodes & redundant model calls.
  Future<TaskAnalysisOutput> runTaskAnalysis({
    required Uint8List rawAudioBytes,
    required LabTaskMode mode,
    VocabularyWord? targetWord,
    bool noiseReductionEnabled = true,
    bool rawBypassMode = false,
    bool runRawComparison = false,
    bool runWhisperInFull = true,
    int attemptId = 0,
  }) async {
    final Stopwatch totalSw = Stopwatch()..start();
    if (!_isInitialized) {
      await initialize();
    }

    int vadCalls = 0;
    int gtcrnCalls = 0;
    int wav2vecCalls = 0;
    int whisperCalls = 0;

    int vadMs = 0;
    int denoiseMs = 0;
    int phonemeMs = 0;
    int sttMs = 0;
    int evalMs = 0;
    String? failedStage;
    String? technicalError;

    if (rawAudioBytes.isEmpty) {
      totalSw.stop();
      const emptyErr = 'ملف الصوت فارغ (0 bytes).';
      return TaskAnalysisOutput(
        audioResult: AudioProcessingResult(
          speechDetected: false,
          speechStartMs: 0,
          speechEndMs: 0,
          durationMs: 0,
          averageRms: 0.0,
          peakAmplitude: 0.0,
          snrDb: 0.0,
          rawAudioBytes: rawAudioBytes,
          waveformPoints: const [],
          isValidAudio: false,
          errorMessage: emptyErr,
        ),
        telemetry: LabExecutionTelemetry(
          attemptId: attemptId,
          taskMode: mode,
          durationMs: 0,
          wavBytesLength: 0,
          sampleRate: 0,
          sampleCount: 0,
          rawRms: 0.0,
          rawPeak: 0.0,
          nonZeroSampleRatio: 0.0,
          vadDetected: false,
          vadSegmentsCount: 0,
          denoisedRms: 0.0,
          denoisedPeak: 0.0,
          vadLatencyMs: 0,
          denoiseLatencyMs: 0,
          phonemeLatencyMs: 0,
          sttLatencyMs: 0,
          evalLatencyMs: 0,
          totalLatencyMs: totalSw.elapsedMilliseconds,
          invocations: const ModelInvocationCounts(),
          failedStage: 'AudioCapture',
          technicalError: emptyErr,
          recorderRecoveryCount: recorder.recoveryCount,
          usedBackgroundWorker: _worker?.isReady ?? false,
        ),
      );
    }

    late final PreprocessedAudio prep;
    try {
      prep = preprocessor.preprocessWav(
        rawAudioBytes,
        targetSampleRate: 16000,
        allowHeaderlessPcm16Fallback: false,
      );
    } on InvalidAudioFormatException catch (e) {
      totalSw.stop();
      return TaskAnalysisOutput(
        audioResult: AudioProcessingResult(
          speechDetected: false,
          speechStartMs: 0,
          speechEndMs: 0,
          durationMs: 0,
          averageRms: 0.0,
          peakAmplitude: 0.0,
          snrDb: 0.0,
          rawAudioBytes: rawAudioBytes,
          waveformPoints: const [],
          isValidAudio: false,
          errorMessage: e.message,
        ),
        telemetry: LabExecutionTelemetry(
          attemptId: attemptId,
          taskMode: mode,
          durationMs: 0,
          wavBytesLength: rawAudioBytes.length,
          sampleRate: 0,
          sampleCount: 0,
          rawRms: 0.0,
          rawPeak: 0.0,
          nonZeroSampleRatio: 0.0,
          vadDetected: false,
          vadSegmentsCount: 0,
          denoisedRms: 0.0,
          denoisedPeak: 0.0,
          vadLatencyMs: 0,
          denoiseLatencyMs: 0,
          phonemeLatencyMs: 0,
          sttLatencyMs: 0,
          evalLatencyMs: 0,
          totalLatencyMs: totalSw.elapsedMilliseconds,
          invocations: const ModelInvocationCounts(),
          failedStage: 'AudioPreprocessor',
          technicalError: e.message,
          recorderRecoveryCount: recorder.recoveryCount,
          usedBackgroundWorker: _worker?.isReady ?? false,
        ),
      );
    }

    final Float32List samples = preprocessor.removeDcOffset(prep.samples);
    final double rms = preprocessor.calculateRms(samples);
    final double peak = preprocessor.calculatePeak(samples);
    final double snr = preprocessor.estimateSnrDb(samples);
    final double nonZeroRatio = _computeNonZeroRatio(samples);
    final List<double> waveform = preprocessor.downsampleForWaveform(
      samples,
      64,
    );

    // 1. Optional Silero VAD (0 calls in recorderOnly or noiseReduction with rawBypass)
    VadAnalysisResult? vad;
    final bool shouldRunVad = switch (mode) {
      LabTaskMode.recorderOnly => false,
      LabTaskMode.noiseReduction => !rawBypassMode,
      LabTaskMode.speechToText => !rawBypassMode,
      LabTaskMode.freePhonemeRecognition => !rawBypassMode,
      LabTaskMode.vadOnly => true,
      LabTaskMode.pronunciationAssessment => true,
      LabTaskMode.fullDiagnostics => !rawBypassMode,
    };

    if (shouldRunVad) {
      if (peak < 0.002) {
        vad = VadAnalysisResult(
          speechDetected: false,
          speechStartMs: 0,
          speechEndMs: 0,
          speechProbabilities: List<double>.filled(
            math.max(1, samples.length ~/ 512),
            0.0,
          ),
          isNativeModel: vadEngine.isNativeAvailable,
        );
      } else {
        final swVad = Stopwatch()..start();
        vad = vadEngine.analyze(samples);
        vadMs = swVad.elapsedMilliseconds;
        vadCalls = 1;
        if (vad.errorMessage != null) {
          failedStage = 'SileroVAD';
          technicalError = vad.errorMessage;
        }
      }
    }

    final Float32List? trimmed = (vad != null && vad.speechDetected)
        ? vad.trimmedSamples
        : null;
    final Float32List activeSamples = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : samples;

    // 2. Conditional or Explicit Noise Suppression (GTCRN)
    final bool shouldRunDenoiser = switch (mode) {
      LabTaskMode.recorderOnly || LabTaskMode.vadOnly => false,
      LabTaskMode.noiseReduction => true,
      LabTaskMode.speechToText ||
      LabTaskMode.freePhonemeRecognition ||
      LabTaskMode.pronunciationAssessment =>
        !rawBypassMode &&
            noiseReductionEnabled &&
            peak >= 0.002 &&
            snr < 14.0 &&
            activeSamples.isNotEmpty,
      LabTaskMode.fullDiagnostics =>
        !rawBypassMode && noiseReductionEnabled && peak >= 0.002,
    };

    DenoiseResult? denoise;
    Float32List finalSamples = activeSamples;
    if (shouldRunDenoiser && activeSamples.isNotEmpty) {
      final swDen = Stopwatch()..start();
      final prevEn = denoiserEngine.enabled;
      denoiserEngine.enabled = true;
      try {
        denoise = denoiserEngine.process(activeSamples);
      } finally {
        denoiserEngine.enabled = prevEn;
      }
      denoiseMs = swDen.elapsedMilliseconds;
      gtcrnCalls = 1;
      if (denoise.hasValidAudio) {
        finalSamples = denoise.processedSamples;
      } else {
        failedStage ??= 'GTCRNDenoiser';
        technicalError ??= denoise.errorMessage;
      }
    }

    // 3. Phoneme Recognition (Wav2Vec2 ONCE, zero duplicate calls)
    PhonemeRecognitionResult? phonemeRes;
    List<PhonemeToken> rawPhonemes = const [];
    final bool skipNeuralBecauseNoSpeech =
        shouldRunVad && peak < 0.002 ||
        (shouldRunVad &&
            vad != null &&
            !vad.speechDetected &&
            mode != LabTaskMode.fullDiagnostics);

    final bool shouldRunWav2Vec =
        !skipNeuralBecauseNoSpeech &&
        (mode == LabTaskMode.freePhonemeRecognition ||
            mode == LabTaskMode.pronunciationAssessment ||
            mode == LabTaskMode.fullDiagnostics);

    if (shouldRunWav2Vec) {
      Float32List wav2vecInput = finalSamples;
      final double spRms = preprocessor.calculateRms(wav2vecInput);
      if (spRms < 0.05 && spRms >= 0.0015) {
        wav2vecInput = preprocessor.normalizePeak(
          wav2vecInput,
          targetPeak: 0.7,
        );
      }
      final swPh = Stopwatch()..start();
      phonemeRes = await _recognizePhonemesOffUiIfReady(wav2vecInput);
      phonemeMs = swPh.elapsedMilliseconds;
      wav2vecCalls++;
      if (phonemeRes.hasError) {
        failedStage ??= 'PhonemeRecognition';
        technicalError ??= phonemeRes.errorMessage;
      }

      if (mode == LabTaskMode.fullDiagnostics &&
          runRawComparison &&
          !rawBypassMode &&
          shouldRunDenoiser) {
        final rawRes = await _recognizePhonemesOffUiIfReady(samples);
        wav2vecCalls++;
        rawPhonemes = rawRes.tokens;
      } else {
        rawPhonemes = phonemeRes.tokens;
      }
    }

    // 4. Speech-to-Text (Whisper Tiny ONLY in speechToText or explicit fullDiagnostics)
    SttResult? sttRes;
    final bool shouldRunWhisper =
        !skipNeuralBecauseNoSpeech &&
        (mode == LabTaskMode.speechToText ||
            (mode == LabTaskMode.fullDiagnostics && runWhisperInFull));

    if (shouldRunWhisper) {
      final swStt = Stopwatch()..start();
      sttRes = await _transcribeOffUiIfReady(finalSamples);
      sttMs = swStt.elapsedMilliseconds;
      whisperCalls++;
      if (sttRes.hasError) {
        failedStage ??= 'SpeechToText';
        technicalError ??= sttRes.errorMessage;
      }
    }

    // 5. Clinical Alignment (reusing already computed Wav2Vec2 tokens — ZERO extra inference!)
    PronunciationAssessment? assessment;
    if (targetWord != null &&
        (mode == LabTaskMode.pronunciationAssessment ||
            mode == LabTaskMode.fullDiagnostics)) {
      final swEval = Stopwatch()..start();
      if (peak < 0.002) {
        assessment = PronunciationAssessment(
          targetWord: targetWord.id,
          targetWordArabic: targetWord.wordArabic,
          recognizedTranscript: '',
          overallScore: 0.0,
          stars: 0,
          errorType: AssessmentErrorType.noSpeech,
          clinicalErrorName:
              'صمت رقمي تام (Digital Silence: peak=${peak.toStringAsFixed(4)})',
          targetPhoneme: targetWord.targetPhoneme,
          alignments: _deletedAlignments(targetWord),
          recognizedPhonemes: const [],
          yasserFeedbackMessage:
              'المايك لم يلتقط أي صوت (إشارة صامتة تماماً).. تأكد من عدم كتم المايك!',
          yasserPose: 'thinking',
          latencyMs: totalSw.elapsedMilliseconds,
          passed: false,
          pipelineStageFailed: 'AudioSignalCheck',
        );
      } else if (shouldRunVad && vad != null && !vad.speechDetected) {
        assessment = evaluator.evaluate(
          word: targetWord,
          recognizedTokens: const [],
          latencyMs: totalSw.elapsedMilliseconds,
        );
      } else if (phonemeRes != null && phonemeRes.hasError) {
        assessment = _systemFailure(
          word: targetWord,
          errorType: AssessmentErrorType.inferenceFailed,
          clinicalName: 'فشل استدلال الفونيمات (Wav2Vec2 Error)',
          stage: 'PhonemeRecognition',
          detail: phonemeRes.errorMessage!,
          userMessage: 'حصل خطأ أثناء استدلال الفونيمات.',
          latencyMs: totalSw.elapsedMilliseconds,
        );
      } else {
        assessment = evaluator.evaluate(
          word: targetWord,
          recognizedTokens: phonemeRes?.tokens ?? const [],
          speechDetected: vad?.speechDetected ?? true,
          latencyMs: phonemeMs + vadMs + denoiseMs,
        );
      }
      evalMs = swEval.elapsedMilliseconds;
    }

    final Uint8List? trimmedWav = trimmed != null && trimmed.isNotEmpty
        ? preprocessor.float32ToWav(trimmed, sampleRate: 16000)
        : null;
    final bool denoiseOk = denoise != null && denoise.hasValidAudio;
    final Uint8List? denoisedWav = denoiseOk
        ? preprocessor.float32ToWav(denoise.processedSamples, sampleRate: 16000)
        : null;

    totalSw.stop();

    final AudioProcessingResult audioRes = AudioProcessingResult(
      speechDetected: vad?.speechDetected ?? (peak >= 0.002),
      speechStartMs: vad?.speechStartMs ?? 0,
      speechEndMs: vad?.speechEndMs ?? prep.durationMs,
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
      denoisedWaveformPoints: denoiseOk
          ? preprocessor.downsampleForWaveform(denoise.processedSamples, 64)
          : const [],
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
      denoiserFilterType:
          denoise?.filterType ??
          (shouldRunDenoiser ? 'gtcrn_error' : 'skipped_or_clean'),
      vadSegments: (vad?.segments ?? const [])
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
      isValidAudio: technicalError == null,
      errorMessage: technicalError,
    );

    final telemetry = LabExecutionTelemetry(
      attemptId: attemptId,
      taskMode: mode,
      durationMs: prep.durationMs,
      wavBytesLength: rawAudioBytes.length,
      sampleRate: prep.sourceMetadata.sampleRate,
      sampleCount: prep.sampleCount,
      rawRms: double.parse(rms.toStringAsFixed(5)),
      rawPeak: double.parse(peak.toStringAsFixed(4)),
      nonZeroSampleRatio: nonZeroRatio,
      vadDetected: audioRes.speechDetected,
      vadSegmentsCount: audioRes.vadSegments.length,
      denoisedRms: audioRes.denoisedRms,
      denoisedPeak: audioRes.denoisedPeakAmplitude,
      vadLatencyMs: vadMs,
      denoiseLatencyMs: denoiseMs,
      phonemeLatencyMs: phonemeMs,
      sttLatencyMs: sttMs,
      evalLatencyMs: evalMs,
      totalLatencyMs: totalSw.elapsedMilliseconds,
      invocations: ModelInvocationCounts(
        vad: vadCalls,
        gtcrn: gtcrnCalls,
        wav2vec2: wav2vecCalls,
        whisper: whisperCalls,
      ),
      failedStage: failedStage ?? assessment?.pipelineStageFailed,
      technicalError: technicalError ?? assessment?.diagnosticError,
      recorderRecoveryCount: recorder.recoveryCount,
      usedBackgroundWorker: _worker?.isReady ?? false,
    );

    return TaskAnalysisOutput(
      audioResult: audioRes,
      phonemeResult: phonemeRes,
      sttResult: sttRes,
      assessment: assessment,
      rawPhonemes: rawPhonemes,
      telemetry: telemetry,
    );
  }

  Future<void> disposeWorker() async {
    await _worker?.dispose();
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
