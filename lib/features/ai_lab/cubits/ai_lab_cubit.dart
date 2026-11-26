import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/ai/audio_preprocessor.dart';
import '../../../../core/ai/models/audio_processing_result.dart';
import '../../../../core/ai/models/phoneme_token.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/phoneme_recognition_engine.dart';
import '../../../../core/ai/pronunciation_repository.dart';
import '../../../../core/ai/rnnoise_denoiser_engine.dart';
import '../../../../core/ai/speech_to_text_engine.dart';
import 'ai_lab_state.dart';

class AiLabCubit extends Cubit<AiLabState> {
  final PronunciationRepository _repository;
  StreamSubscription<double>? _amplitudeSubscription;

  AiLabCubit(this._repository) : super(const AiLabState()) {
    _amplitudeSubscription = _repository.recorder.amplitudeStream.listen((amp) {
      if (state.isRecording) {
        emit(state.copyWith(currentLiveAmplitude: amp));
      }
    });
  }

  /// Initializes the AI Lab repository and syncs real verified model status.
  Future<void> initializeLab() async {
    emit(state.copyWith(status: AiLabStatus.loading, clearError: true));
    try {
      await _repository.initialize();
      final models = _repository.modelManager.models;
      final ram = _repository.modelManager.getTotalRamUsageMb();
      final vocab = _repository.vocabulary;
      final selected = vocab.isNotEmpty ? vocab.first : null;

      emit(
        state.copyWith(
          status: AiLabStatus.ready,
          models: models,
          totalRamUsageMb: ram,
          vocabulary: vocab,
          selectedWord: selected,
          noiseReductionEnabled: _repository.denoiserEngine.enabled,
          denoiserMode: _repository.denoiserEngine.mode,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: 'Failed to initialize AI Lab: $e',
        ),
      );
    }
  }

  void selectVocabularyWord(VocabularyWord word) {
    emit(state.copyWith(selectedWord: word));
  }

  void toggleNoiseReduction(bool enabled) {
    _repository.denoiserEngine.enabled = enabled;
    emit(state.copyWith(noiseReductionEnabled: enabled));
  }

  void setDenoiserMode(DenoiserMode mode) {
    _repository.denoiserEngine.mode = mode;
    _repository.denoiserEngine.enabled = mode != DenoiserMode.bypass;
    emit(
      state.copyWith(
        denoiserMode: mode,
        noiseReductionEnabled: mode != DenoiserMode.bypass,
      ),
    );
  }

  void setRawBypassMode(bool bypass) {
    emit(state.copyWith(rawBypassMode: bypass));
  }

  /// Starts live microphone recording session.
  Future<void> startRecording() async {
    try {
      await _repository.recorder.startRecording();
      emit(
        state.copyWith(
          isRecording: true,
          status: AiLabStatus.recording,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isRecording: false,
          status: AiLabStatus.error,
          errorMessage: 'Recording failed: $e',
        ),
      );
    }
  }

  /// Stops recording and runs unified diagnostics across VAD, GTCRN, Wav2Vec2-eSpeak, Whisper & Evaluator.
  Future<AudioProcessingResult?> stopRecordingAndAnalyze() async {
    emit(
      state.copyWith(
        isRecording: false,
        status: AiLabStatus.processing,
        clearError: true,
      ),
    );
    try {
      final Uint8List rawBytes = await _repository.recorder.stopRecording();
      return await analyzeWavBytesForAllStages(rawBytes);
    } catch (e) {
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: 'Recording or pipeline analysis error: $e',
        ),
      );
      return null;
    }
  }

  /// Runs every diagnostic stage on a single WAV sample (recorded or bundled) with unified preprocessing.
  Future<AudioProcessingResult?> analyzeWavBytesForAllStages(
    Uint8List rawBytes,
  ) async {
    emit(state.copyWith(status: AiLabStatus.processing, clearError: true));
    try {
      await _repository.initialize();

      final AudioProcessingResult audioResult = _repository.analyzeAudioForLab(
        rawBytes,
      );
      if (!audioResult.isValidAudio && audioResult.rawAudioBytes.isEmpty) {
        emit(
          state.copyWith(
            status: AiLabStatus.error,
            lastAudioResult: audioResult,
            errorMessage:
                audioResult.errorMessage ?? 'Invalid or empty audio payload.',
          ),
        );
        return audioResult;
      }

      // Unified WAV decode/resample to 16kHz Float32
      final PreprocessedAudio prep = _repository.preprocessor.preprocessWav(
        rawBytes,
        targetSampleRate: 16000,
      );

      // Determine active samples based on raw bypass toggle vs processed audio
      Float32List processedSamples = prep.samples;
      if (!state.rawBypassMode) {
        if (audioResult.denoisedAudioBytes != null &&
            audioResult.denoisedAudioBytes!.isNotEmpty) {
          processedSamples = _repository.preprocessor
              .preprocessWav(
                audioResult.denoisedAudioBytes!,
                targetSampleRate: 16000,
              )
              .samples;
        } else if (audioResult.trimmedAudioBytes != null &&
            audioResult.trimmedAudioBytes!.isNotEmpty) {
          processedSamples = _repository.preprocessor
              .preprocessWav(
                audioResult.trimmedAudioBytes!,
                targetSampleRate: 16000,
              )
              .samples;
        }
      }

      // Run blind Wav2Vec2-eSpeak phonemes & Whisper STT on active samples
      final PhonemeRecognitionResult phonemeRes = await _repository
          .phonemeEngine
          .recognizePhonemesDetailed(processedSamples);
      final SttResult sttRes = await _repository.sttEngine.transcribe(
        processedSamples,
      );

      // Also capture raw-audio phonemes when bypass is disabled for honest side-by-side comparison
      List<PhonemeToken> rawPhonemes = const [];
      if (!state.rawBypassMode) {
        rawPhonemes = await _repository.phonemeEngine.recognizePhonemes(
          prep.samples,
        );
      } else {
        rawPhonemes = phonemeRes.tokens;
      }

      // Evaluate against selected vocabulary word if one is active
      PronunciationAssessment? assessment;
      if (state.selectedWord != null) {
        assessment = await _repository.evaluateAudio(
          rawAudioBytes: rawBytes,
          targetWord: state.selectedWord!,
          overrideDenoise: state.noiseReductionEnabled,
        );
      }

      final String? surfaceErr =
          audioResult.errorMessage ??
          phonemeRes.errorMessage ??
          sttRes.errorMessage;

      emit(
        state.copyWith(
          status: AiLabStatus.ready,
          lastAudioResult: audioResult,
          lastAssessment: assessment,
          lastRecognizedPhonemes:
              assessment?.recognizedPhonemes ?? phonemeRes.tokens,
          lastPhonemeResult: phonemeRes,
          lastSttResult: sttRes,
          lastBlindTranscript: sttRes.text,
          lastBlindPhonemes: phonemeRes.tokens,
          lastRawPhonemes: rawPhonemes,
          errorMessage: surfaceErr,
        ),
      );
      return audioResult;
    } catch (e) {
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: 'Analysis pipeline failure: $e',
        ),
      );
      return null;
    }
  }

  /// Runs blind acoustic phoneme recognition + optional STT on arbitrary WAV audio without target hint.
  Future<void> runBlindPhonemeTest({Uint8List? audioBytes}) async {
    emit(state.copyWith(status: AiLabStatus.processing, clearError: true));
    try {
      await _repository.initialize();
      final Uint8List raw =
          audioBytes ?? state.lastAudioResult?.rawAudioBytes ?? Uint8List(0);
      if (raw.isEmpty) {
        emit(
          state.copyWith(
            status: AiLabStatus.error,
            errorMessage: 'No audio buffer available to analyze.',
            lastBlindTranscript: '',
            lastBlindPhonemes: const [],
          ),
        );
        return;
      }

      final PreprocessedAudio prep = _repository.preprocessor.preprocessWav(
        raw,
        targetSampleRate: 16000,
      );
      final Float32List samples = _repository.preprocessor.removeDcOffset(
        prep.samples,
      );

      Float32List inferenceSamples = samples;
      if (!state.rawBypassMode && _repository.vadEngine.isNativeAvailable) {
        final vad = _repository.vadEngine.analyze(samples);
        if (!vad.speechDetected ||
            vad.trimmedSamples == null ||
            vad.trimmedSamples!.isEmpty) {
          emit(
            state.copyWith(
              status: AiLabStatus.ready,
              lastBlindTranscript: '',
              lastBlindPhonemes: const [],
              lastPhonemeResult: const PhonemeRecognitionResult(
                tokens: [],
                latencyMs: 0,
                frameCount: 0,
                audioDurationMs: 0,
                isNativeModel: true,
              ),
              errorMessage: vad.errorMessage,
            ),
          );
          return;
        }
        inferenceSamples = vad.trimmedSamples!;
      }

      final stt = await _repository.sttEngine.transcribe(inferenceSamples);
      final phonemeRes = await _repository.phonemeEngine
          .recognizePhonemesDetailed(inferenceSamples);

      emit(
        state.copyWith(
          status: AiLabStatus.ready,
          lastBlindTranscript: stt.text,
          lastBlindPhonemes: phonemeRes.tokens,
          lastPhonemeResult: phonemeRes,
          lastSttResult: stt,
          errorMessage: phonemeRes.errorMessage ?? stt.errorMessage,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: AiLabStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Runs phoneme recognition & clinical alignment against selected word.
  Future<void> runPhonemeTest({
    required VocabularyWord word,
    Uint8List? audioBytes,
  }) async {
    emit(state.copyWith(status: AiLabStatus.processing, clearError: true));
    try {
      await _repository.initialize();
      final Uint8List bytes =
          audioBytes ?? state.lastAudioResult?.rawAudioBytes ?? Uint8List(0);
      if (bytes.isEmpty) {
        emit(
          state.copyWith(
            status: AiLabStatus.error,
            errorMessage: 'No audio buffer recorded or selected.',
          ),
        );
        return;
      }

      final PreprocessedAudio prep = _repository.preprocessor.preprocessWav(
        bytes,
        targetSampleRate: 16000,
      );
      final PhonemeRecognitionResult blindPhonemes = await _repository
          .phonemeEngine
          .recognizePhonemesDetailed(prep.samples);

      final assessment = await _repository.evaluateAudio(
        rawAudioBytes: bytes,
        targetWord: word,
        overrideDenoise: state.noiseReductionEnabled,
      );

      emit(
        state.copyWith(
          status: assessment.errorType.isSystemFailure
              ? AiLabStatus.error
              : AiLabStatus.ready,
          selectedWord: word,
          lastAssessment: assessment,
          lastRecognizedPhonemes: assessment.recognizedPhonemes,
          lastBlindPhonemes: blindPhonemes.tokens,
          lastPhonemeResult: blindPhonemes,
          errorMessage:
              assessment.diagnosticError ?? blindPhonemes.errorMessage,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: AiLabStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Runs word-level Speech-to-Text transcription (unified WAV decoding).
  Future<void> runSttTest({Uint8List? audioBytes}) async {
    final bytes = audioBytes ?? state.lastAudioResult?.rawAudioBytes;
    if (bytes == null || bytes.isEmpty) {
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: 'Record or select an audio clip before running STT.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: AiLabStatus.processing, clearError: true));
    try {
      await _repository.initialize();
      final PreprocessedAudio prep = _repository.preprocessor.preprocessWav(
        bytes,
        targetSampleRate: 16000,
      );
      Float32List samples = prep.samples;

      if (!state.rawBypassMode && _repository.vadEngine.isNativeAvailable) {
        final vad = _repository.vadEngine.analyze(samples);
        if (vad.speechDetected && vad.trimmedSamples != null) {
          samples = vad.trimmedSamples!;
        }
      }

      final stt = await _repository.sttEngine.transcribe(samples);
      emit(
        state.copyWith(
          status: stt.hasError ? AiLabStatus.error : AiLabStatus.ready,
          lastSttResult: stt,
          errorMessage: stt.errorMessage,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: AiLabStatus.error, errorMessage: e.toString()),
      );
    }
  }

  /// Toggles model memory allocation (Load/Unload) and syncs real RSS & status.
  Future<void> toggleModelMemory(String key) async {
    final model = state.models.firstWhere((m) => m.key == key);
    if (model.isLoadedInMemory) {
      await _repository.modelManager.unloadModelFromMemory(key);
    } else {
      await _repository.modelManager.loadModelIntoMemory(key);
    }
    final updatedModels = _repository.modelManager.models;
    final totalRam = _repository.modelManager.getTotalRamUsageMb();
    emit(state.copyWith(models: updatedModels, totalRamUsageMb: totalRam));
  }

  /// Runs real ONNX smoke test for a specific model key.
  Future<bool> smokeTestModel(String key) async {
    return _repository.modelManager.runSmokeTest(key);
  }

  /// Exports complete structured JSON diagnostic report via platform share sheet.
  Future<void> exportDiagnosticReport() async {
    final jsonString = buildDiagnosticJsonReport();
    // ignore: deprecated_member_use
    await Share.share(
      jsonString,
      subject: 'LIQAA AI Lab Diagnostic Report (${DateTime.now().toLocal()})',
    );
  }

  String buildDiagnosticJsonReport() {
    final Map<String, dynamic> report = {
      'timestamp': DateTime.now().toIso8601String(),
      'noise_reduction_enabled': state.noiseReductionEnabled,
      'denoiser_mode': state.denoiserMode.name,
      'raw_bypass_mode': state.rawBypassMode,
      'models': state.models.map((m) => m.toJson()).toList(),
      'total_ram_mb': state.totalRamUsageMb,
      'last_audio_metrics': state.lastAudioResult?.toJson(),
      'last_phoneme_result': state.lastPhonemeResult == null
          ? null
          : {
              'model_name': state.lastPhonemeResult!.modelName,
              'is_native': state.lastPhonemeResult!.isNativeModel,
              'latency_ms': state.lastPhonemeResult!.latencyMs,
              'frame_count': state.lastPhonemeResult!.frameCount,
              'avg_confidence': state.lastPhonemeResult!.averageConfidence,
              'avg_margin': state.lastPhonemeResult!.averageAcousticMargin,
              'error_message': state.lastPhonemeResult!.errorMessage,
              'tokens': state.lastPhonemeResult!.tokens
                  .map((t) => t.toJson())
                  .toList(),
            },
      'last_stt_result': state.lastSttResult != null
          ? {
              'text': state.lastSttResult!.text,
              'confidence': state.lastSttResult!.confidence,
              'latency_ms': state.lastSttResult!.latencyMs,
              'rtf': state.lastSttResult!.realTimeFactor,
              'is_native': state.lastSttResult!.isModelInference,
              'error_message': state.lastSttResult!.errorMessage,
            }
          : null,
      'last_assessment': state.lastAssessment?.toJson(),
      'last_blind_transcript': state.lastBlindTranscript,
      'last_blind_phonemes': state.lastBlindPhonemes
          .map((t) => t.toJson())
          .toList(),
      'last_raw_phonemes': state.lastRawPhonemes
          .map((t) => t.toJson())
          .toList(),
      'last_error': state.errorMessage,
    };

    return const JsonEncoder.withIndent('  ').convert(report);
  }

  @override
  Future<void> close() {
    _amplitudeSubscription?.cancel();
    return super.close();
  }
}
