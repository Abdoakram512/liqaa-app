import 'dart:convert';
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
import 'models/phoneme_token.dart';

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
  })  : recorder = recorder ?? AudioRecorderService(),
        preprocessor = preprocessor ?? const AudioPreprocessor(),
        vadEngine = vadEngine ?? SileroVadEngine(),
        denoiserEngine = denoiserEngine ?? RnnoiseDenoiserEngine(),
        phonemeEngine = phonemeEngine ?? PhonemeRecognitionEngine(),
        evaluator = evaluator ?? const PronunciationEvaluator(),
        sttEngine = sttEngine ?? SpeechToTextEngine(),
        modelManager = modelManager ?? AiModelManager();

  bool get isInitialized => _isInitialized;
  List<VocabularyWord> get vocabulary => _vocabulary;

  /// Loads vocabulary dictionary from assets and initializes AI engines
  Future<void> initialize() async {
    if (_isInitialized) return;

    await modelManager.initialize();
    await vadEngine.initialize();
    await denoiserEngine.initialize();
    await sttEngine.initialize();
    await phonemeEngine.initialize();

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
    debugPrint('[PronunciationRepository] Initialized with ${_vocabulary.length} words');
  }

  /// Processes raw audio bytes through the end-to-end AI pipeline.
  /// Strictly prevents target answer leakage to the recognition engines!
  Future<PronunciationAssessment> evaluateAudio({
    required Uint8List rawAudioBytes,
    required VocabularyWord targetWord,
    bool? overrideDenoise,
  }) async {
    final Stopwatch sw = Stopwatch()..start();

    if (rawAudioBytes.isEmpty) {
      sw.stop();
      return evaluator.evaluate(
        word: targetWord,
        recognizedTokens: const [],
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    // 1. Convert to Float32 PCM (handling RIFF/WAVE header if present)
    final Uint8List pcmBytes = preprocessor.parseWavPcm(rawAudioBytes);
    Float32List samples = preprocessor.pcm16ToFloat32(pcmBytes);

    if (samples.isEmpty) {
      sw.stop();
      return evaluator.evaluate(
        word: targetWord,
        recognizedTokens: const [],
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    // 2. Preprocessing: DC-offset removal & Peak Normalization
    samples = preprocessor.removeDcOffset(samples);
    final double rawRms = preprocessor.calculateRms(samples);
    final double rawSnr = preprocessor.estimateSnrDb(samples);

    // Severe noise / distortion check (high noise floor, SNR < 2.0 dB)
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
        alignments: targetWord.expectedPhonemes.asMap().entries.map((e) {
          final int idx = e.key;
          final String exp = e.value;
          final String expAr = idx < targetWord.expectedArabicPhonemes.length
              ? targetWord.expectedArabicPhonemes[idx]
              : exp;
          return PhonemeAlignment(
            expectedPhoneme: exp,
            expectedArabic: expAr,
            recognizedToken: null,
            isMatch: false,
            status: 'deleted',
          );
        }).toList(),
        recognizedPhonemes: const [],
        yasserFeedbackMessage: 'في دوشة حواليك يا بطل! روح لمكان هادي وقول تاني.',
        yasserPose: 'thinking',
        latencyMs: sw.elapsedMilliseconds,
        passed: false,
      );
    }

    samples = preprocessor.normalizePeak(samples);

    // 3. Silero VAD analysis & silence detection
    final VadAnalysisResult vad = vadEngine.analyze(samples);

    // If silence or no speech detected -> abort immediately with NoSpeech assessment!
    if (!vad.speechDetected || vad.trimmedSamples == null || vad.trimmedSamples!.isEmpty) {
      sw.stop();
      return evaluator.evaluate(
        word: targetWord,
        recognizedTokens: const [],
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    final Float32List speechSamples = vad.trimmedSamples!;

    // 4. RNNoise Noise Reduction
    final bool enableDenoise = overrideDenoise ?? denoiserEngine.enabled;
    denoiserEngine.enabled = enableDenoise;
    final DenoiseResult denoise = denoiserEngine.process(speechSamples);
    final Float32List finalSamples = denoise.processedSamples;

    // 5. Blind Phoneme Recognition (ZERO TARGET LEAKAGE)
    final List<PhonemeToken> recognizedTokens = await phonemeEngine.recognizePhonemes(
      finalSamples,
    );

    sw.stop();
    final int latencyMs = sw.elapsedMilliseconds;

    // 6. Clinical Alignment & Dynamic Programming Assessment
    return evaluator.evaluate(
      word: targetWord,
      recognizedTokens: recognizedTokens,
      latencyMs: latencyMs,
    );
  }

  /// Detailed audio analysis result for Yasser AI Lab
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
      );
    }

    final Uint8List pcmBytes = preprocessor.parseWavPcm(rawBytes);
    Float32List samples = preprocessor.pcm16ToFloat32(pcmBytes);
    samples = preprocessor.removeDcOffset(samples);

    final VadAnalysisResult vad = vadEngine.analyze(samples);
    final Float32List trimmed = vad.trimmedSamples ?? samples;

    final DenoiseResult denoise = denoiserEngine.process(trimmed);

    final double rms = preprocessor.calculateRms(samples);
    final double peak = preprocessor.calculatePeak(samples);
    final double snr = preprocessor.estimateSnrDb(samples);
    final List<double> waveform = preprocessor.downsampleForWaveform(samples, 64);

    return AudioProcessingResult(
      speechDetected: vad.speechDetected,
      speechStartMs: vad.speechStartMs,
      speechEndMs: vad.speechEndMs,
      durationMs: vad.durationMs,
      averageRms: double.parse(rms.toStringAsFixed(3)),
      peakAmplitude: double.parse(peak.toStringAsFixed(2)),
      snrDb: double.parse(snr.toStringAsFixed(1)),
      snrImprovementDb: double.parse(denoise.snrImprovementDb.toStringAsFixed(1)),
      rawAudioBytes: rawBytes,
      trimmedAudioBytes: preprocessor.float32ToPcm16(trimmed),
      denoisedAudioBytes: preprocessor.float32ToPcm16(denoise.processedSamples),
      waveformPoints: waveform,
    );
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
            feedbackAr: 'شاطر جداً! بس بدّلنا صوت الـ ك بالـ ت.. يلا نطلع الكاف: كـ كورة!',
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
            feedbackAr: 'ممتاز! بس لسانك طلع برة سنانك.. خلّي لسانك جوة واصفر: سسسـ سمكة!',
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
            feedbackAr: 'برافو يا بطل! بدّلنا صوت الـ ر بالـ ل.. يلا نخلّي لساننا يهتز: أرررنب!',
            yasserPose: 'thinking',
          ),
        ],
      ),
    ];
  }
}
