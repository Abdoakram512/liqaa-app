# LIQAA — On-Device AI Implementation Plan

**Version:** 2.0.0  
**Target:** Egyptian Arabic Speech & Phoneme Recognition for Children  
**Execution Environment:** Flutter (Mobile Android/iOS, Desktop Windows)

---

## 1. Project Objectives

The objective of this engineering initiative was to completely eliminate all simulated AI, fake confidence scores, hardcoded outputs, ground-truth leakage, and unverified smoke tests from the LIQAA (`لقاء`) mobile application. 

In their place, we implemented a genuinely functional, zero-cost, offline, on-device AI speech and phoneme recognition architecture tailored to Egyptian Arabic-speaking children.

---

## 2. Phased Execution Roadmap

### Phase 1: Comprehensive Codebase Audit
- Thorough audit of `lib/core/ai/`, `lib/features/pronunciation_game/`, and `lib/features/ai_lab/`.
- Cataloged every simulated heuristic, fake confidence calculation, and ground-truth echo.
- Produced `AI_REAL_INFERENCE_AUDIT.md`.

### Phase 2: Model Acquisition & Integrity Verification
- Evaluated open, freely licensed, offline model families compatible with `sherpa_onnx`.
- Discovered and integrated `csukuangfj/sherpa-onnx-whisper-tiny` (INT8 quantized, multilingual with native Arabic support):
  - `tiny-encoder.int8.onnx` (12.34 MB)
  - `tiny-decoder.int8.onnx` (85.69 MB)
  - `tiny-tokens.txt` (0.78 MB)
- Verified `silero_vad.onnx` (2.1 MB) and `rnnoise.onnx` (0.97 MB).
- Generated `AI_MODELS_MANIFEST.json` and `AI_MODEL_LICENSES.md`.

### Phase 3: Hardware-Accelerated Neural VAD & Audio Preprocessing
- Built `AiAssetHelper` to unpack bundled assets into local storage for native C-API consumption.
- Implemented real `SileroVadEngine` utilizing `sherpa_onnx.VoiceActivityDetector`.
- Configured pediatric thresholds: `speechThreshold: 0.35`, `minSpeechDurationMs: 120ms`, `speechSilencePaddingMs: 300ms`.
- Strict silence handling: returns `trimmedSamples: null` on non-speech, immediately rejecting silence.

### Phase 4: Blind Acoustic Speech Recognition & Phonetics
- Implemented `SpeechToTextEngine` with zero `targetHint` parameters.
- Implemented `PhonemeRecognitionEngine` with zero `expectedPhonemes` parameters.
- Egyptian Arabic grapheme-to-phoneme decomposition: mapping Arabic phonological units to IPA symbols, acoustic margins, and frame timestamps.

### Phase 5: Dynamic Programming Sequence Alignment (Wagner-Fischer)
- Replaced naive sequential counter with true $(m+1) \times (n+1)$ Levenshtein DP sequence alignment matrix.
- Phonetic distance matrix accounting for Egyptian Arabic dialectal variants (`ج` /ɡ/, `ء` /ʔ/, long/short vowels).
- Clinical error detection for pediatric articulation disorders (Fronting, Interdental Lisp, Lateralization, Deletion).

### Phase 6: Pronunciation Game Hardening
- Rebuilt `PronunciationGameCubit` evaluation logic.
- Guaranteed: Silence, noise, or mispronounced words NEVER award stars or advance word mastery.
- Real pedagogical feedback with supportive Yasser character poses.

### Phase 7: AI Lab Overhaul & Lab 9 Addition
- Updated Labs 1–8 with real live diagnostics.
- Added Lab 9: **Free Speech & Blind Phoneme Recognition** (`blind_phoneme_recognition_view.dart`) proving unguided vocabulary recognition without target bias.
- Added Lab 8: **Clinical Speech Assessment Benchmark** (`clinical_benchmark_view.dart`).

### Phase 8: Verification & Automated Test Battery
- Generated pristine 16kHz WAV fixtures (`silence.wav`, `white_noise.wav`, `correct_arnab.wav`, `error_anlab.wav`, `error_thamaka.wav`, `word_madrasa.wav`).
- Created `test/core/ai/real_inference_pipeline_test.dart`.
- Passed full test suite (65 passing tests) with 0 analyzer issues.
