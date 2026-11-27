# Inference Performance Before & After Report — Phase 0.1 (Workstream B)

**Working Branch:** `feature/phase0-ai-governance`  
**Hardware Benchmarked:** Windows Desktop CPU (`flutter test` / ONNX Runtime `1.28.2`, Windows x64, sequential execution). Physical Android thermal/NNAPI timings remain hardware-dependent.

---

## 1. Root Cause of Sluggish Multi-Second Delays (`P0-B`)

Before Phase 0.1:
1. **3x Redundant Wav2Vec2 / Full Pipeline Execution:** Every AI Lab view passed `"كورة"` through `AiLabCubit` without explicit task separation, running redundant pipeline passes and unnecessary models (e.g., running `Wav2Vec2-eSpeak` when only `VAD` or `Whisper` STT was requested).
2. **Repeated WAV Decoding:** `AudioPreprocessor.preprocessWav(...)` ran repeatedly across stages for a single user submission.
3. **UI-Isolate Blocking:** Synchronous ONNX FFI execution blocked the Flutter UI isolate during Wav2Vec2 and Whisper inference.

---

## 2. Implemented Architectural Optimization

1. **Explicit `LabTaskMode` Routing (`lib/core/ai/models/lab_task_mode.dart`, `lib/core/ai/pronunciation_repository.dart`):**
   - `recorderOnly`: Audio signal stats ONLY (**0** neural model calls).
   - `vadOnly`: Single WAV decode + Silero VAD ONLY (**1** VAD, **0** GTCRN, **0** Wav2Vec2, **0** Whisper).
   - `denoiseOnly`: Single WAV decode + Silero VAD + GTCRN (**1** VAD, **1** GTCRN, **0** Wav2Vec2, **0** Whisper).
   - `speechToText`: Single WAV decode + Silero VAD + conditional GTCRN (if `<14 dB SNR`) + Whisper Tiny (**0** Wav2Vec2, **1** Whisper).
   - `freePhonemeRecognition`: Single WAV decode + Silero VAD + conditional GTCRN + **1** Wav2Vec2 (**0** Whisper).
   - `pronunciationAssessment`: Single WAV decode + Silero VAD + conditional GTCRN + **1** Wav2Vec2 + Wagner-Fischer clinical evaluator (**0** Whisper).
   - `fullDiagnostics`: Explicitly runs **1** VAD + explicit GTCRN + **1** Wav2Vec2 + **1** Whisper (**never 3x Wav2Vec2**).
2. **Single WAV Decode & Telemetry (`TaskAnalysisOutput`, `LabExecutionTelemetry`):**
   - `PronunciationRepository.runTaskAnalysis(...)` decodes/resamples the WAV buffer once and records exact per-model stage latencies & invocation counts.
3. **Persistent Background Isolate (`lib/core/ai/ai_inference_worker.dart`):**
   - Keeps persistent native ONNX sessions (`Wav2Vec2-eSpeak` + `Whisper Tiny`) in a dedicated long-lived background Isolate (`useBackgroundWorker: true` in `service_locator.dart`), avoiding UI jank and cold-reload overhead.

---

## 3. Verified Model Invocation Matrix (`recorder_lifecycle_and_routing_test.dart`)

| `LabTaskMode` | VAD Calls | GTCRN Calls | Wav2Vec2 Calls | Whisper Calls | Verified Status |
| --- | --- | --- | --- | --- | --- |
| `recorderOnly` | `0` | `0` | `0` | `0` | **EXACT MATCH** |
| `vadOnly` | `1` | `0` | `0` | `0` | **EXACT MATCH** |
| `speechToText` | `1` | conditional | `0` | `1` | **EXACT MATCH** |
| `freePhonemeRecognition` | `1` | conditional | `1` | `0` | **EXACT MATCH** |
| `pronunciationAssessment` | `1` | conditional | `1` | `0` | **EXACT MATCH** |
| `fullDiagnostics` | `1` | `1` | `1` | `1` | **EXACT MATCH (Zero 3x)** |
| Empty audio (`Uint8List(0)`) | `0` | `0` | `0` | `0` | **EXACT MATCH** |

---

## 4. Observed Latency Measurements (Windows Desktop Real ONNX)

Measured in `test/core/ai/vad_repeatability_and_stt_diag_test.dart`:

| Measurement Stage | Pre-Fix Baseline (from prior session check `vad_repeatability`) | Post-Fix Measured (`task-5874`, single pass) | Observed Change / Cause |
| --- | --- | --- | --- |
| **Wav2Vec2 Standalone / Cold Full** | `wav2vec2=1458ms`, `labCold=466ms` | `freeCold=1596ms` (`human_arabic_adult.wav`, `~3.2s`) | Single decode + `vad:1, wav2vec2:1, gtcrn:0, whisper:0` |
| **Free Phoneme Warm (`word_madrasa.wav`, `<1s`)** | Legacy multi-pass re-evaluated 3x across UI flows | **`freeWarm=373ms`** (`calls={vad:1, gtcrn:0, wav2vec2:1, whisper:0}`) | Eliminated 2 redundant Wav2Vec2 + unnecessary Whisper passes |
| **Game Pronunciation Warm (`word_madrasa.wav`)** | Multiple repeated UI-thread decode + redundant passes | **`gameWarm=368ms`** (`calls={vad:1, gtcrn:0, wav2vec2:1, whisper:0}`) | Single decode + 1x Wav2Vec2 |
| **STT Only (`human_arabic_adult.wav`)** | `sttOrig=712ms`, `sttTrim=654ms`, `sttDen=630ms` | **`sttWarm=701ms`** (`calls={vad:1, gtcrn:0, wav2vec2:0, whisper:1}`) | Zero Wav2Vec2 calls executed |
| **Explicit Full Diagnostics** | `—` | **`fullWarm=2437ms`** (`calls={vad:1, gtcrn:1, wav2vec2:1, whisper:1}`) | Bounded 1x each; opt-in only |
| **Persistent `AiInferenceWorker` Isolate** | Blocked UI isolate | Init OK; `wPh=1398ms` (47 tokens), `wStt=671ms` off-UI (`human_arabic_adult.wav`) | Zero UI-thread blocking |

> **Honest Hardware Caveat:** Desktop ONNX CPU execution times (`~368ms–701ms` warm on x64 CPU) establish task-routing efficiency and elimination of redundant calls; mid-tier ARM64 Android CPU latencies must be measured directly on device.
