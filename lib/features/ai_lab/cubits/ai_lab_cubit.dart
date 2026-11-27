import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/ai/audio_recorder_service.dart';
import '../../../../core/ai/models/audio_processing_result.dart';
import '../../../../core/ai/models/lab_task_mode.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/pronunciation_repository.dart';
import '../../../../core/ai/rnnoise_denoiser_engine.dart';
import 'ai_lab_state.dart';

class AiLabCubit extends Cubit<AiLabState> {
  static const String _recorderOwner = 'ai_lab';

  final PronunciationRepository _repository;
  StreamSubscription<double>? _amplitudeSubscription;
  int _taskSeq = 0;
  bool _closed = false;

  AiLabCubit(this._repository) : super(const AiLabState()) {
    _amplitudeSubscription = _repository.recorder.amplitudeStream.listen((amp) {
      if (!_closed && state.isRecording) {
        emit(state.copyWith(currentLiveAmplitude: amp));
      }
    });
  }

  /// Initializes the AI Lab repository and syncs real verified model status.
  Future<void> initializeLab() async {
    emit(state.copyWith(status: AiLabStatus.loading, clearError: true));
    try {
      await _repository.initialize();
      if (_closed) return;
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
      if (_closed) return;
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

  /// Starts live microphone capture under dedicated AI Lab ownership.
  Future<void> startRecording() async {
    if (_closed || state.isRecording) return;
    try {
      await _repository.recorder.startOwnedRecording(_recorderOwner);
      if (_closed) {
        await _repository.recorder.cancelOwnedRecording(_recorderOwner);
        return;
      }
      emit(
        state.copyWith(
          isRecording: true,
          status: AiLabStatus.recording,
          clearError: true,
        ),
      );
    } catch (e) {
      if (_closed) return;
      emit(
        state.copyWith(
          isRecording: false,
          status: AiLabStatus.error,
          errorMessage: 'Recording failed: $e',
        ),
      );
    }
  }

  /// Explicitly resets and recreates the native AudioRecorder backend cleanly.
  Future<void> resetRecorderSafe() async {
    await _repository.recorder.resetRecorder();
    if (_closed) return;
    emit(
      state.copyWith(
        isRecording: false,
        status: AiLabStatus.ready,
        clearError: true,
      ),
    );
  }

  /// Stops recording and executes ONLY the requested [LabTaskMode] pipeline.
  Future<AudioProcessingResult?> stopRecordingAndRunTask(
    LabTaskMode mode,
  ) async {
    final int seq = ++_taskSeq;
    emit(
      state.copyWith(
        isRecording: false,
        status: AiLabStatus.processing,
        clearError: true,
      ),
    );
    try {
      final Uint8List rawBytes = await _repository.recorder.stopOwnedRecording(
        _recorderOwner,
      );
      if (_closed || seq != _taskSeq) return null;
      final int attemptId =
          _repository.recorder.lastCaptureInfo?.attemptId ?? 0;
      return await runTaskOnWavBytes(
        rawBytes,
        mode: mode,
        attemptId: attemptId,
      );
    } on AudioRecordingException catch (e) {
      if (_closed || seq != _taskSeq) return null;
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: '${e.kind.name}: ${e.message}',
        ),
      );
      return null;
    } catch (e) {
      if (_closed || seq != _taskSeq) return null;
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: 'Recording or pipeline analysis error: $e',
        ),
      );
      return null;
    }
  }

  /// Runs a single-decode, task-routed pipeline on WAV bytes with stale-result cancellation.
  Future<AudioProcessingResult?> runTaskOnWavBytes(
    Uint8List rawBytes, {
    required LabTaskMode mode,
    VocabularyWord? wordOverride,
    bool runRawComparison = false,
    int attemptId = 0,
  }) async {
    final int seq = ++_taskSeq;
    emit(state.copyWith(status: AiLabStatus.processing, clearError: true));
    try {
      await _repository.initialize();
      final out = await _repository.runTaskAnalysis(
        rawAudioBytes: rawBytes,
        mode: mode,
        targetWord: wordOverride ?? state.selectedWord,
        noiseReductionEnabled: state.noiseReductionEnabled,
        rawBypassMode: state.rawBypassMode,
        runRawComparison: runRawComparison,
        runWhisperInFull: mode == LabTaskMode.fullDiagnostics,
        attemptId: attemptId,
      );

      if (_closed || seq != _taskSeq) return out.audioResult;

      emit(
        state.copyWith(
          status:
              out.telemetry.failedStage != null &&
                  out.telemetry.failedStage != 'AudioSignalCheck'
              ? AiLabStatus.error
              : AiLabStatus.ready,
          selectedWord: wordOverride ?? state.selectedWord,
          lastAudioResult: out.audioResult,
          lastAssessment: out.assessment ?? state.lastAssessment,
          lastRecognizedPhonemes:
              out.assessment?.recognizedPhonemes ??
              out.phonemeResult?.tokens ??
              state.lastRecognizedPhonemes,
          lastPhonemeResult: out.phonemeResult ?? state.lastPhonemeResult,
          lastSttResult: out.sttResult ?? state.lastSttResult,
          lastBlindTranscript: out.sttResult?.text ?? state.lastBlindTranscript,
          lastBlindPhonemes:
              out.phonemeResult?.tokens ?? state.lastBlindPhonemes,
          lastRawPhonemes: out.rawPhonemes.isNotEmpty
              ? out.rawPhonemes
              : state.lastRawPhonemes,
          lastTelemetry: out.telemetry,
          errorMessage: out.telemetry.technicalError,
        ),
      );
      return out.audioResult;
    } catch (e) {
      if (_closed || seq != _taskSeq) return null;
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: 'Task ${mode.name} failed: $e',
        ),
      );
      return null;
    }
  }

  /// Preserved explicit full-diagnostics entrypoint for FullPipelineView only.
  Future<AudioProcessingResult?> stopRecordingAndAnalyze() =>
      stopRecordingAndRunTask(LabTaskMode.fullDiagnostics);

  /// Preserved explicit full-diagnostics entrypoint on raw WAV bytes (runs single-pass reuse).
  Future<AudioProcessingResult?> analyzeWavBytesForAllStages(
    Uint8List rawBytes,
  ) => runTaskOnWavBytes(
    rawBytes,
    mode: LabTaskMode.fullDiagnostics,
    runRawComparison: !state.rawBypassMode,
  );

  /// Runs blind acoustic phoneme recognition ONLY (zero Whisper, zero target hint).
  Future<void> runBlindPhonemeTest({Uint8List? audioBytes}) async {
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
    await runTaskOnWavBytes(raw, mode: LabTaskMode.freePhonemeRecognition);
  }

  /// Runs phoneme recognition & clinical alignment against selected word (zero Whisper).
  Future<void> runPhonemeTest({
    required VocabularyWord word,
    Uint8List? audioBytes,
  }) async {
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
    await runTaskOnWavBytes(
      bytes,
      mode: LabTaskMode.pronunciationAssessment,
      wordOverride: word,
    );
  }

  /// Runs Whisper Tiny Arabic Speech-to-Text ONLY (zero Wav2Vec2).
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
    await runTaskOnWavBytes(bytes, mode: LabTaskMode.speechToText);
  }

  /// Replays same local temporary buffer through Free Phoneme and Picture Naming Assessment pipelines.
  Future<void> replayDualPipelineComparison([Uint8List? audioBytes]) async {
    final bytes = audioBytes ?? state.lastAudioResult?.rawAudioBytes;
    if (bytes == null || bytes.isEmpty) {
      emit(
        state.copyWith(
          status: AiLabStatus.error,
          errorMessage: 'No temporary audio recorded for dual replay.',
        ),
      );
      return;
    }
    final freeOut = await _repository.runTaskAnalysis(
      rawAudioBytes: bytes,
      mode: LabTaskMode.freePhonemeRecognition,
      noiseReductionEnabled: state.noiseReductionEnabled,
      rawBypassMode: state.rawBypassMode,
    );
    final gameOut = await _repository.runTaskAnalysis(
      rawAudioBytes: bytes,
      mode: LabTaskMode.pronunciationAssessment,
      targetWord: state.selectedWord ?? _repository.vocabulary.firstOrNull,
      noiseReductionEnabled: state.noiseReductionEnabled,
      rawBypassMode: state.rawBypassMode,
    );
    if (_closed) return;
    final freeIpa =
        freeOut.phonemeResult?.tokens.map((t) => t.symbol).join(' ') ?? '';
    final gameIpa =
        gameOut.phonemeResult?.tokens.map((t) => t.symbol).join(' ') ?? '';
    final summary =
        'FreePhoneme: vad=${freeOut.audioResult.speechDetected} '
        'calls=${freeOut.telemetry.invocations.toJson()} ipa=[$freeIpa] '
        '(${freeOut.telemetry.totalLatencyMs}ms)\n'
        'GamePipeline: vad=${gameOut.audioResult.speechDetected} '
        'calls=${gameOut.telemetry.invocations.toJson()} '
        'ipa=[$gameIpa] score=${gameOut.assessment?.overallScore ?? 0}% '
        '(${gameOut.assessment?.errorType.name}, ${gameOut.telemetry.totalLatencyMs}ms)';

    emit(
      state.copyWith(
        status: AiLabStatus.ready,
        lastAudioResult: gameOut.audioResult,
        lastPhonemeResult: freeOut.phonemeResult,
        lastBlindPhonemes: freeOut.phonemeResult?.tokens ?? const [],
        lastAssessment: gameOut.assessment,
        lastTelemetry: gameOut.telemetry,
        dualReplaySummary: summary,
      ),
    );
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
      'last_telemetry': state.lastTelemetry?.toJson(),
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
      'dual_replay_summary': state.dualReplaySummary,
      'last_error': state.errorMessage,
    };

    return const JsonEncoder.withIndent('  ').convert(report);
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _amplitudeSubscription?.cancel();
    await _repository.recorder.cancelOwnedRecording(_recorderOwner);
    return super.close();
  }
}
