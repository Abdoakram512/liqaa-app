# LIQAA — Real Model Integration & Runtime Architecture Report

## 1. Runtime Architecture Overview

The LIQAA on-device AI subsystem is built on a layered, modular architecture isolating hardware interaction, native inference runtimes, signal processing, and linguistic evaluation.

```
┌─────────────────────────────────────────────────────────────┐
│                 Presentation & Game Layer                   │
│   (PronunciationGameCubit / AiLabCubit / 10 Lab Views)      │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                  PronunciationRepository                    │
│    (Audio I/O, Pipeline Orchestration, Zero Target Leak)    │
└──────┬───────────────────────┼───────────────────────┬──────┘
       │                       │                       │
┌──────▼──────┐         ┌──────▼──────┐         ┌──────▼──────┐
│  Silero VAD │         │ DSP Wiener  │         │ Whisper ASR │
│   Engine    │         │  Denoiser   │         │ & G2P Engine│
│(sherpa_onnx)│         │ (16kHz PCM) │         │ (INT8 ONNX) │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │
┌──────▼───────────────────────▼───────────────────────▼──────┐
│                  Native Runtimes & FFI                      │
│   (libdynamic sherpa-onnx-c-api.dll / .so, Asset Cache)     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Asset Extraction & Native File System Management

Mobile operating systems package Flutter assets inside read-only APK (Android) or IPA (iOS) archives. Native ONNX runtimes require absolute file system paths to memory-map model graphs.

The `AiAssetHelper` module manages transparent, deterministic asset extraction:
1. Checks the application's persistent documents directory for existing unpacked models.
2. Compares byte lengths and precomputed SHA-256 hashes against bundled assets.
3. Streams bytes chunk-by-chunk to the local storage target only when missing or corrupt.
4. Returns the validated absolute system path to native loaders (`sherpa_onnx.OfflineModelConfig`).

```dart
final encoderPath = await AiAssetHelper.getLocalAssetPath(
  'assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx',
);
```

---

## 3. Elimination of Fabricated Metrics

Prior audit versions contained heuristic estimations that compromised technical veracity. The remediation completely purged these fabrications:

### 3.1 Speech-to-Text Confidence
- **Audit Finding:** Whisper Tiny calculated confidence from audio energy: `(0.75 + rms * 1.5).clamp(0.60, 0.98)`.
- **Remediation:** Removed completely. `SttResult.confidence` is now a nullable `double?`. When uncalibrated decoder posteriors are not exposed by the native Sherpa wrapper, confidence is represented honestly as `null` or nominal `1.0` on successful decoding, with explicit documentation that acoustic logits were not fabricated.

### 3.2 VAD Frame Probabilities
- **Audit Finding:** `_computeFrameProbabilities` synthesized heuristic sigmoid probabilities from scalar energy while claiming they originated from the Silero neural network.
- **Remediation:** In native Silero mode, `VadAnalysisResult.speechProbabilities` represents the exact binary speech mask (1.0 for detected speech intervals, 0.0 for silence) derived from `VoiceActivityDetector.front()`. Frame energy is isolated in `energyEnvelope` for UI rendering and never conflated with neural probabilities.

### 3.3 Dynamic RAM Measurement
- **Audit Finding:** `AiModelManager` reported hardcoded RAM values (`14.2 MB`, `8.5 MB`, `115.0 MB`).
- **Remediation:** Implemented genuine process resident memory tracking via `ProcessInfo.currentRss`. The manager samples system RSS before and after model initialization to compute the real Resident Set Size delta in MB:
```dart
final double rssBefore = ProcessInfo.currentRss / (1024 * 1024);
await _activeStt!.initialize();
final double rssAfter = ProcessInfo.currentRss / (1024 * 1024);
final double measuredRssDelta = (rssAfter - rssBefore).clamp(0.1, 500.0);
```

### 3.4 True Native Lifecycle (Load / Unload)
- Model toggle actions in the AI Lab now instantiate real engine sessions on load and invoke native `.free()` / `.dispose()` on unload, genuinely freeing native heap memory.

---

## 4. End-to-End Pipeline Execution

The complete evaluation sequence for an utterance:
1. **Raw Audio Intake:** 16-bit little-endian PCM at 16,000 Hz mono.
2. **Preprocessing:** Header stripping (`parseWavPcm`), DC-bias cancellation (`removeDcOffset`), and peak amplitude measurement (`calculatePeak`).
3. **Voice Activity Detection:** Silero VAD analysis. If no speech is detected (`rms < 0.003` or `!vad.speechDetected`), inference aborts immediately returning `AssessmentErrorType.noSpeech`.
4. **Noise Filtering:** DSP Wiener filter calculates SNR before and after, applying suppression if beneficial.
5. **Acoustic Transcription:** Whisper Tiny decodes speech into Arabic text without target hints.
6. **G2P Transduction:** Egyptian Arabic phonological transducer decomposes words into phoneme tokens.
7. **Sequence Alignment:** Wagner-Fischer Dynamic Programming computes the minimum edit distance matrix against the target word, applying strict clinical substitution rules and insertion penalties.
