# LIQAA — AI Lab Suite Verification Report

## 1. Overview of the 10 Developer Labs

The LIQAA AI Lab is an on-device diagnostic and verification hub providing visual inspection, model benchmarking, and automated regression testing across all 10 speech and AI subsystems.

```
┌─────────────────────────────────────────────────────────────┐
│                    LIQAA AI Lab Hub                         │
├──────────────────────────────┬──────────────────────────────┤
│ 1. Model Manager             │ 6. Model Comparison          │
│ 2. Mic & Silero VAD          │ 7. Full E2E Pipeline         │
│ 3. RNNoise Denoiser (DSP)    │ 8. Clinical Benchmark (WAV)  │
│ 4. Phoneme Recognition       │ 9. Free / Blind Recognition  │
│ 5. Speech-to-Text (ASR)      │ 10. Negative & Fault Testing │
└──────────────────────────────┴──────────────────────────────┘
```

---

## 2. Lab Details & Remediation Verification

### Lab 1: Model Manager (`ModelManagerView`)
- **Capabilities:** Lists all 4 AI assets (`silero_vad`, `rnnoise`, `whisper_tiny`, `zipformer_v3`).
- **Remediation Verified:**
  - Removed hardcoded RAM strings (`14.2`, `8.5`, `115.0`).
  - Added dynamic process RSS delta tracking via `ProcessInfo.currentRss`.
  - Reclassified `zipformer_v3` honestly as `Lexicon (Tokens/JSON)` rather than a neural inference model.
  - True memory load/unload with engine lifecycle management and native garbage collection.
  - Multi-input smoke tests that assert speech detection on non-zero signals and rejection of digital silence.

### Lab 2: Microphone & Silero VAD (`MicVadView`)
- **Capabilities:** Real-time microphone audio stream, waveform display, speech start/end boundary markers.
- **Remediation Verified:**
  - Segregated binary neural VAD speech masks from scalar energy envelopes.
  - Displays actual detected speech start and end timestamps in milliseconds.

### Lab 3: Noise Reduction (`NoiseReductionView`)
- **Capabilities:** Before-and-after waveform visualizer, SNR estimation, SNR improvement metric.
- **Remediation Verified:**
  - Clarified runtime filter mechanism: High-Resolution DSP Wiener Spectral Subtraction on 16 kHz PCM.
  - Guaranteed zero-latency transparent bypass when disabled (`wasSuppressionApplied: false`, $0.0$ dB SNR alteration).

### Lab 4: Phoneme Recognition & G2P (`PhonemeRecognitionView`)
- **Capabilities:** Decomposes target words into Arabic and IPA phonemes with interactive audio review.
- **Remediation Verified:**
  - Removed fabricated acoustic margins (`acousticMargin: null`).
  - Labeled segmented time boundaries as estimated (`isTimestampEstimated: true`).

### Lab 5: Word-Level Speech-to-Text (`SpeechToTextView`)
- **Capabilities:** Blind transcription of microphone audio into Arabic text.
- **Remediation Verified:**
  - Eliminated `(0.75 + rms * 1.5)` confidence formula.
  - Added display of genuine tokens and timestamps from Whisper decoder.

### Lab 6: Model Comparison (`ModelComparisonView`)
- **Capabilities:** Compares latency, memory, and RTF metrics across different subsystem stages.

### Lab 7: Full E2E Pipeline (`FullPipelineView`)
- **Capabilities:** End-to-end verification of an audio clip through Preprocessing -> VAD -> Denoiser -> ASR -> Alignment -> Scoring.

### Lab 8: Clinical Diagnostic Benchmark (`ClinicalBenchmarkView`)
- **Audit Finding 10:** Lab 8 previously passed predefined text strings (`spokenText: 'كورة'`) into G2P, bypassing audio processing.
- **Remediation Verified:**
  - Completely rewritten to evaluate **Real WAV Audio Fixtures** from `assets/audio_samples/`.
  - Tapping an item loads the WAV bytes via `rootBundle.load()`, passes raw audio into `PronunciationRepository.evaluateAudio()`, and displays actual model outputs, dynamic programming alignment, and clinical feedback.

### Lab 9: Blind Phoneme Recognition (`BlindPhonemeRecognitionView`)
- **Audit Finding 11:** Lab 9 previously contained `simulatedText` shortcuts in preset chips.
- **Remediation Verified:**
  - Completely purged `simulatedText` from UI and `AiLabCubit`.
  - Preset chips now load real WAV audio files (`correct_kora.wav`, `error_tora.wav`, `silence.wav`, etc.) and feed genuine PCM bytes through the blind recognition pipeline.

### Lab 10: Diagnostic & Negative Testing Suite (`DiagnosticNegativeTestingView`)
- **New Feature Added:** Comprehensive fault-injection and boundary testing suite:
  1. *Silence Rejection:* Verifies 0% false positives on digital silence (`AssessmentErrorType.noSpeech`).
  2. *White Noise Rejection:* Verifies stationary white noise is rejected without crashing.
  3. *Unrelated Word:* Verifies unrelated words (*مدرسة* against *كورة*) receive $\le 30\%$ score and 1 star.
  4. *Clipping Detection:* Verifies real peak amplitude calculation on saturated waveforms.
  5. *Model Fallback:* Verifies system stability when native libraries are missing.
