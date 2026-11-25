# LIQAA — Automated Test Suite Report

**Test Execution Date:** 2026-11-25  
**Test Harness:** Flutter Test Framework (`flutter_test`)  
**Overall Status:** PASSED (65/65 tests passed, 0 failures, 0 analyzer issues)

---

## 1. Test Suite Summary

```
Total Test Files: 12
Total Unit & Integration Tests: 65
Passed: 65
Failed: 0
Skipped: 0
Analyzer Warnings / Errors / Lints: 0
Duration: ~13.8 seconds
```

---

## 2. Detailed Test Coverage Breakdown

### 2.1 AI Subsystem Tests (`test/core/ai/`) — 21 Tests

- **`audio_preprocessor_test.dart` (5 tests):**
  - PCM16 to Float32 and Float32 to PCM16 roundtrip preservation.
  - DC-offset bias subtraction.
  - Peak amplitude normalization with headroom targeting.
  - Root Mean Square (RMS) calculation.
  - RIFF/WAVE 44-byte binary header generation.

- **`silero_vad_test.dart` (2 tests):**
  - Empty/zero-sample audio returns `speechDetected: false`.
  - Synthetic 440 Hz tone burst detects speech boundaries and trims silence margins.

- **`rnnoise_denoiser_test.dart` (2 tests):**
  - Bypass mode returns original samples without alteration.
  - Enabled mode reduces background noise and computes positive SNR improvement in dB.

- **`pronunciation_evaluator_test.dart` (3 tests):**
  - Accurate pronunciation evaluates to passed with 3 stars.
  - Fronting substitution (`كورة` $\to$ `تورة`) triggers clinical substitution feedback.
  - Omission error (dropping terminal or medial consonant) triggers deletion classification.

- **`vocabulary_dictionary_test.dart` (1 test):**
  - Egyptian Arabic dictionary integrity validation (28 curated vocabulary cards with clinical error rules).

- **`real_inference_pipeline_test.dart` (8 tests):**
  - `silence.wav` fixture verification: guarantees 0 stars and `passed: false`.
  - `white_noise.wav` fixture verification: guarantees noise rejection.
  - Blind Fronting error detection on `error_tora.wav`.
  - Blind Interdental Lisp error detection on `error_thamaka.wav`.
  - Blind Lateralization error detection on `error_anlab.wav`.
  - Blind Unrelated word rejection on `word_madrasa.wav`.
  - Blind Clean pronunciation approval with 3 stars on `correct_kora.wav`.
  - Wagner-Fischer DP alignment resistance to insertion desynchronization.

---

### 2.2 Animation & Character Tests (`test/core/animation/`) — 44 Tests

- **`yasser_character_test.dart`:**
  - Rive 0.14+ migration verification: `RiveWidget`, `Factory.rive`, `FileLoader`, and native initialization.
  - Fallback avatar rendering in test environments.
  - Tap reaction callback handling.
- **`yasser_interaction_engine_test.dart`:**
  - Character emotional state transitions.
  - Motion reaction to speech assessment scores.
- **`yasser_animation_mapper_test.dart`:**
  - State machine input mappings (`State`, `Gesture`, `LookX`, `LookY`, `Intensity`).
- **`rive_audit_test.dart`:**
  - Integrity of `.riv` asset file.

---

### 2.3 Authentication, Onboarding & Splash Tests (`test/features/`)

- **`auth_repo_test.dart` & `auth_cubit_test.dart`:** Authentication gateway, credential validation, session storage, error handling.
- **`login_view_test.dart`:** Form input fields, Yasser character rendering, state reactivity.
- **`onboarding_cubit_test.dart` & `onboarding_repo_test.dart`:** Multi-step walkthrough flow, completion flags.
- **`splash_cubit_test.dart`:** Initial routing decision tree (Onboarding vs Auth Gateway).

---

## 3. Analyzer Verification

Command executed:
```powershell
flutter analyze
```
Output:
```
Analyzing liqaa_app...
No issues found! (ran in 7.9s)
```
