# Real ONNX Model Verification & Inventory Report

## 1. Audited Legacy Issues Fixed
1. `assets/ai_models/zipformer_v2/` and `assets/ai_models/zipformer_v3/` contained **zero `.onnx` files** (only `tokens.txt` and `phoneme_units.json`), yet `AiModelManager` marked `zipformer_v3` as `'ready'` / `isLoadedInMemory: true`, and AI Lab UI views claimed `Zipformer2 CTC Head (92%)` and fabricated benchmark metrics (`16.8% PER`, `94.2%`).
2. `AiModelManager.loadModelIntoMemory()` caught initialization exceptions and set `isLoadedInMemory: true` unconditionally.
3. `PhonemeRecognitionEngine` ran `Whisper Tiny -> Arabic text -> Grapheme-to-Phoneme (textToPhonemes)` with synthetic equal timestamps (`isTimestampEstimated: true`), rather than acoustic phoneme recognition.
4. `SpeechToTextEngine` fabricated `confidence: 1.0` even though Sherpa-ONNX `OfflineRecognizerResult` does not expose a normalized confidence scalar.
5. `AiModelManager.smokeTestModel('whisper_tiny')` only asserted `latencyMs >= 0` on zero-filled audio, and `ModelManagerView` showed a green success snackbar regardless of the boolean return value of `smokeTestModel()`.

---

## 2. Current Verified Production Models

| Key | Model & Architecture | Asset Files & Verified Size | License | Runtime Path | Status & Smoke Test Behavior |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `silero_vad` | Silero VAD v4 | `assets/ai_models/silero/silero_vad.onnx` (`2,204,103` B / `2.10` MB) | MIT | `sherpa_onnx.VoiceActivityDetector` (512-sample chunks) | Verified native init; rejects `silence.wav` & `white_noise.wav`; segments speech on `kora.wav`, `samaka.wav`, and `human_arabic_adult.wav` |
| `gtcrn_denoiser` | GTCRN Simple (16kHz Speech Enhancement) | `assets/ai_models/gtcrn/gtcrn_simple.onnx` (`535,638` B / `0.51` MB) | MIT | `sherpa_onnx.OfflineSpeechDenoiser` | Verified native init; produces finite non-silent 16kHz waveforms; rejects missing model path with explicit error |
| `wav2vec2_espeak` | `onnx-community/wav2vec2-lv-60-espeak-cv-ft-ONNX` (Quantized Q4F16) | `assets/ai_models/wav2vec2_espeak/model_q4f16.onnx` (`196,911,845` B / `187.8` MB) + `vocab.json` (`4,637` B, 392 IPA units) | Apache-2.0 | Direct Dart FFI (`OrtDynamicSession` over Sherpa-bundled ORT `v1.28.2`, API 22) | Verified native inference; outputs empty IPA on `silence.wav`; outputs frame-aligned IPA tokens with calibrated softmax posteriors & `top1 - top2` margins |
| `whisper_tiny` | Whisper Tiny Arabic INT8 | `tiny-encoder.int8.onnx` (`12,937,772` B), `tiny-decoder.int8.onnx` (`89,855,401` B), `tiny-tokens.txt` (`816,730` B) | MIT | `sherpa_onnx.OfflineRecognizer` (Arabic ASR) | Diagnostic telemetry only (`confidence: null` honestly); excluded from clinical phoneme scoring |

### Deprecated / Unused Legacy Assets Documented
- `assets/ai_models/rnnoise/rnnoise.onnx` (`1,020,606` B): Feature-domain BFCC 48kHz network (`main_input:0` `[batch, 100, 42]`); incompatible with 16kHz raw PCM pipelines and replaced by `gtcrn_simple.onnx`.
- `assets/ai_models/zipformer_v2/` & `assets/ai_models/zipformer_v3/`: Contain only lexicon text/JSON files without ONNX model weights; removed from active `AiModelManager` inference registry.

---

## 3. Native Test & Verification Summary (Host Windows x64)
- `OrtRuntimeLoader.ensureWindowsPreloaded()` configures `SetDllDirectoryW` and preloads `sherpa_onnx`'s bundled `onnxruntime_providers_shared.dll`, `onnxruntime.dll` (`v1.28.2`), `sherpa-onnx-cxx-api.dll`, and `sherpa-onnx-c-api.dll` so real ONNX inference runs inside `flutter test`.
- `flutter analyze`: **0 issues found**.
- `flutter test`: **87 tests passed, 0 failed**, including real native ONNX tests in:
  - `test/core/ai/audio_preprocessor_test.dart`
  - `test/core/ai/rnnoise_denoiser_test.dart`
  - `test/core/ai/silero_vad_test.dart`
  - `test/core/ai/real_inference_pipeline_test.dart`
  - `test/core/ai/real_onnx_end_to_end_test.dart`
  - `test/core/ai/pronunciation_evaluator_test.dart`
  - `test/features/pronunciation_game/yasser_prompt_playback_test.dart`
  - `test/features/ai_lab/ai_lab_hub_view_test.dart`
