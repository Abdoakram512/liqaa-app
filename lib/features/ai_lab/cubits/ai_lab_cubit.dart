import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/ai/pronunciation_repository.dart';
import '../../../../core/ai/models/vocabulary_word.dart';
import '../../../../core/ai/models/audio_processing_result.dart';
import '../../../../core/ai/models/pronunciation_assessment.dart';
import '../../../../core/ai/models/phoneme_token.dart';
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

  /// Initializes the AI Lab repository and loads models & vocabulary
  Future<void> initializeLab() async {
    emit(state.copyWith(status: AiLabStatus.loading));
    try {
      await _repository.initialize();
      final models = _repository.modelManager.models;
      final ram = _repository.modelManager.getTotalRamUsageMb();
      final vocab = _repository.vocabulary;
      final selected = vocab.isNotEmpty ? vocab.first : null;

      emit(state.copyWith(
        status: AiLabStatus.ready,
        models: models,
        totalRamUsageMb: ram,
        vocabulary: vocab,
        selectedWord: selected,
        noiseReductionEnabled: _repository.denoiserEngine.enabled,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AiLabStatus.error,
        errorMessage: 'Failed to initialize AI Lab: $e',
      ));
    }
  }

  void selectVocabularyWord(VocabularyWord word) {
    emit(state.copyWith(selectedWord: word));
  }

  void toggleNoiseReduction(bool enabled) {
    _repository.denoiserEngine.enabled = enabled;
    emit(state.copyWith(noiseReductionEnabled: enabled));
  }

  /// Starts live microphone recording session
  Future<void> startRecording() async {
    try {
      await _repository.recorder.startRecording();
      emit(state.copyWith(
        isRecording: true,
        status: AiLabStatus.recording,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isRecording: false,
        status: AiLabStatus.error,
        errorMessage: 'Recording failed: $e',
      ));
    }
  }

  /// Stops recording and runs analysis based on active test screen
  Future<AudioProcessingResult?> stopRecordingAndAnalyze() async {
    emit(state.copyWith(isRecording: false, status: AiLabStatus.processing));
    try {
      final Uint8List rawBytes = await _repository.recorder.stopRecording();

      // Lab audio analysis
      final AudioProcessingResult audioResult =
          _repository.analyzeAudioForLab(rawBytes);

      // Evaluate pronunciation against selected word
      PronunciationAssessment? assessment;
      List<PhonemeToken> phonemes = const [];

      if (state.selectedWord != null && rawBytes.isNotEmpty) {
        assessment = await _repository.evaluateAudio(
          rawAudioBytes: rawBytes,
          targetWord: state.selectedWord!,
          overrideDenoise: state.noiseReductionEnabled,
        );
        phonemes = assessment.recognizedPhonemes;
      }

      // Also run blind transcription for Lab 9 telemetry
      String? blindText;
      List<PhonemeToken> blindPhonemes = const [];
      if (rawBytes.isNotEmpty) {
        final samples = _repository.preprocessor.pcm16ToFloat32(rawBytes);
        final vad = _repository.vadEngine.analyze(samples);
        if (vad.speechDetected && vad.trimmedSamples != null) {
          final stt = await _repository.sttEngine.transcribe(vad.trimmedSamples!);
          blindText = stt.text;
          blindPhonemes = await _repository.phonemeEngine.recognizePhonemes(vad.trimmedSamples!);
        }
      }

      emit(state.copyWith(
        status: AiLabStatus.ready,
        lastAudioResult: audioResult,
        lastAssessment: assessment,
        lastRecognizedPhonemes: phonemes,
        lastBlindTranscript: blindText,
        lastBlindPhonemes: blindPhonemes,
      ));
      return audioResult;
    } catch (e) {
      emit(state.copyWith(
        status: AiLabStatus.error,
        errorMessage: 'Analysis error: $e',
      ));
      return null;
    }
  }

  /// Runs blind phoneme recognition on arbitrary audio without any expected word target (Lab 9)
  Future<void> runBlindPhonemeTest({Uint8List? audioBytes}) async {
    emit(state.copyWith(status: AiLabStatus.processing));
    try {
      final Uint8List raw = audioBytes ?? state.lastAudioResult?.rawAudioBytes ?? Uint8List(0);
      if (raw.isEmpty) {
        emit(state.copyWith(
          status: AiLabStatus.ready,
          lastBlindTranscript: '',
          lastBlindPhonemes: const [],
        ));
        return;
      }

      final Uint8List pcmBytes = _repository.preprocessor.parseWavPcm(raw);
      final samples = _repository.preprocessor.pcm16ToFloat32(pcmBytes);
      final vad = _repository.vadEngine.analyze(samples);

      if (!vad.speechDetected || vad.trimmedSamples == null || vad.trimmedSamples!.isEmpty) {
        emit(state.copyWith(
          status: AiLabStatus.ready,
          lastBlindTranscript: '',
          lastBlindPhonemes: const [],
        ));
        return;
      }

      final stt = await _repository.sttEngine.transcribe(vad.trimmedSamples!);
      final tokens = await _repository.phonemeEngine.recognizePhonemes(vad.trimmedSamples!);

      emit(state.copyWith(
        status: AiLabStatus.ready,
        lastBlindTranscript: stt.text,
        lastBlindPhonemes: tokens,
      ));
    } catch (e) {
      emit(state.copyWith(status: AiLabStatus.error, errorMessage: e.toString()));
    }
  }

  /// Runs phoneme recognition on sample or custom audio
  Future<void> runPhonemeTest({required VocabularyWord word, Uint8List? audioBytes}) async {
    emit(state.copyWith(status: AiLabStatus.processing));
    try {
      final Uint8List bytes = audioBytes ?? state.lastAudioResult?.rawAudioBytes ?? Uint8List(0);
      final assessment = await _repository.evaluateAudio(
        rawAudioBytes: bytes,
        targetWord: word,
        overrideDenoise: state.noiseReductionEnabled,
      );

      emit(state.copyWith(
        status: AiLabStatus.ready,
        selectedWord: word,
        lastAssessment: assessment,
        lastRecognizedPhonemes: assessment.recognizedPhonemes,
      ));
    } catch (e) {
      emit(state.copyWith(status: AiLabStatus.error, errorMessage: e.toString()));
    }
  }

  /// Runs word-level Speech-to-Text transcription (ZERO TARGET HINT)
  Future<void> runSttTest() async {
    final bytes = state.lastAudioResult?.rawAudioBytes;
    if (bytes == null || bytes.isEmpty) return;

    emit(state.copyWith(status: AiLabStatus.processing));
    try {
      final samples = _repository.preprocessor.pcm16ToFloat32(bytes);
      final stt = await _repository.sttEngine.transcribe(samples);

      emit(state.copyWith(status: AiLabStatus.ready, lastSttResult: stt));
    } catch (e) {
      emit(state.copyWith(status: AiLabStatus.error, errorMessage: e.toString()));
    }
  }

  /// Toggles model memory allocation (Load/Unload)
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

  /// Runs model smoke test
  Future<bool> smokeTestModel(String key) async {
    return await _repository.modelManager.runSmokeTest(key);
  }

  /// Shares benchmark and diagnostic results as JSON
  Future<void> exportDiagnosticReport() async {
    final Map<String, dynamic> report = {
      'timestamp': DateTime.now().toIso8601String(),
      'models': state.models.map((m) => m.toJson()).toList(),
      'total_ram_mb': state.totalRamUsageMb,
      'last_audio_metrics': state.lastAudioResult?.toJson(),
      'last_assessment': state.lastAssessment?.toJson(),
      'last_stt_result': state.lastSttResult != null
          ? {
              'text': state.lastSttResult!.text,
              'confidence': state.lastSttResult!.confidence,
              'latency_ms': state.lastSttResult!.latencyMs,
              'rtf': state.lastSttResult!.realTimeFactor,
            }
          : null,
      'last_blind_transcript': state.lastBlindTranscript,
      'last_blind_phonemes': state.lastBlindPhonemes.map((t) => t.toJson()).toList(),
      'noise_reduction_enabled': state.noiseReductionEnabled,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(report);
    // ignore: deprecated_member_use
    await Share.share(
      jsonString,
      subject: 'LIQAA AI Lab Diagnostic Report (${DateTime.now().toLocal()})',
    );
  }

  @override
  Future<void> close() {
    _amplitudeSubscription?.cancel();
    return super.close();
  }
}
