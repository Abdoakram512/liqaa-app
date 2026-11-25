# LIQAA — Comprehensive AI & Inference Realism Audit

**Audit Date:** 2026-11-25  
**Auditor:** Senior AI/ML Engineer, Speech Recognition Specialist & Flutter Architect  
**Subject:** Full Source-Code Audit of AI Subsystem, Speech Recognition, and Pronunciation Assessment Pipeline

---

## 1. Executive Summary

A rigorous audit of the LIQAA (`لقاء`) Flutter codebase was conducted to identify all instances of simulated inference, fabricated metrics, target leakage, heuristic approximations masquerading as neural networks, and vulnerabilities in pedagogical evaluation.

The audit revealed critical architectural deficiencies where the user interface displayed seemingly sophisticated AI metrics that were actually hardcoded random numbers or ground-truth echoes. In the pronunciation game, the system consistently reported successful pronunciation and awarded stars even when tested with complete silence, background noise, or deliberately mispronounced words.

This document details every audited file, line-by-line evidence of fake inference, architectural root causes, and the corrective actions implemented.

---

## 2. File-by-File Audit & Evidence of Simulation

### 2.1 `lib/core/ai/silero_vad_engine.dart`

- **Claimed Functionality:** Silero Voice Activity Detector (VAD v4) running on-device neural ONNX inference to segment speech from silence.
- **Actual Implementation:**
  - `initialize()` contains:
    ```dart
    // In production, loads assets/ai_models/silero/silero_vad.onnx via ONNX runtime
    _isInitialized = true;
    ```
    The ONNX model was never loaded or executed.
  - `analyze()` implements a hand-crafted energy and zero-crossing heuristic in Dart:
    ```dart
    final double energyRatio = frameEnergy / noiseFloor;
    double prob = (1.0 / (1.0 + math.exp(-0.75 * (energyRatio - 2.0)))).clamp(0.0, 1.0);
    ```
- **Consequence:** In noisy environments or with soft pediatric consonants, the heuristic failed or produced arbitrary probabilities. Furthermore, when silence was detected, `trimmedSamples: samples` was returned, allowing downstream engines to process pure silence as valid speech.

---

### 2.2 `lib/core/ai/rnnoise_denoiser_engine.dart`

- **Claimed Functionality:** Recurrent Neural Network (RNNoise) noise suppression running via ONNX.
- **Actual Implementation:**
  - `initialize()` contains:
    ```dart
    // In production, loads assets/ai_models/rnnoise/rnnoise.onnx via ONNX runtime
    _isInitialized = true;
    ```
  - `process()` implements a basic energy-gain scalar attenuator in Dart:
    ```dart
    // RNNoise neural attenuation simulation:
    final double snrLinear = frameEnergy / math.max(1e-6, runningNoiseEnergy);
    double gain = (snrLinear / 3.0).clamp(0.12, 1.0);
    ```
- **Consequence:** The neural weights in `assets/ai_models/rnnoise/rnnoise.onnx` were completely bypassed. Audio dynamics were distorted without true spectral gating.

---

### 2.3 `lib/core/ai/phoneme_recognition_engine.dart`

- **Claimed Functionality:** On-device streaming Zipformer/CTC acoustic phoneme recognition for Egyptian Arabic.
- **Actual Implementation:**
  - `recognizePhonemes()` directly leaked the target ground truth:
    ```dart
    // If expected phonemes are provided (guided testing), simulate realistic acoustic posteriors
    final List<String> targets = expectedPhonemes != null && expectedPhonemes.isNotEmpty
        ? expectedPhonemes
        : ['k', 'uː', 'r', 'a'];
    ```
  - Fabricated confidence calculation based on scalar amplitude:
    ```dart
    final double baseConf = 0.85 + 0.12 * math.min(1.0, avgAmp * 3.0);
    final double confidence = baseConf.clamp(0.65, 0.98);
    final double margin = (confidence * 0.35).clamp(0.15, 0.40);
    ```
  - Every token was unconditionally stamped:
    ```dart
    isAccurate: true
    ```
- **Consequence:** The recognition engine never listened to the audio content. It echoed the expected word's phonemes back to the evaluator. Blind speech recognition was completely impossible.

---

### 2.4 `lib/core/ai/speech_to_text_engine.dart`

- **Claimed Functionality:** On-device Automatic Speech Recognition (ASR) for Arabic.
- **Actual Implementation:**
  - `transcribe()` contained simulated latency and returned the target hint:
    ```dart
    await Future.delayed(const Duration(milliseconds: 60));
    final String resultText = targetHint ?? 'كورة';
    final double confidence = (0.82 + math.min(0.16, rms * 2.0)).clamp(0.60, 0.98);
    ```
- **Consequence:** The ASR engine never performed acoustic modeling or language decoding; it echoed `targetHint` or default string `'كورة'`.

---

### 2.5 `lib/core/ai/pronunciation_evaluator.dart`

- **Claimed Functionality:** Dynamic Programming (DP) Levenshtein sequence alignment between expected and recognized phonemes with clinical error detection.
- **Actual Implementation:**
  - `_alignPhonemes()` used a naive sequential index counter rather than dynamic programming:
    ```dart
    while (i < m || j < n) {
      if (i < m && j < n) {
        if (match) { ...; i++; j++; }
        else { ...; i++; j++; } // Advance both on mismatch!
      }
    }
    ```
- **Consequence:** If a child inserted or deleted a single phoneme, the entire remainder of the word became desynchronized and misaligned. It was mathematically incapable of optimal sequence alignment.

---

### 2.6 `lib/core/ai/ai_model_manager.dart`

- **Claimed Functionality:** Hardware-accelerated neural model lifecycle management, memory allocation tracking, and integrity smoke tests.
- **Actual Implementation:**
  - Hardcoded readiness status for non-existent models:
    ```dart
    _models['nabra_82m'] = const AiModelInfo(..., status: 'ready');
    _models['moonshine_tiny'] = const AiModelInfo(..., status: 'ready');
    ```
  - Fabricated smoke test:
    ```dart
    Future<bool> runSmokeTest(String key) async {
      await Future.delayed(const Duration(milliseconds: 150));
      return true; // Always unconditional success!
    }
    ```
  - Hardcoded RAM metrics (`12.4 MB`, `8.2 MB`, `110.0 MB`).

---

### 2.7 `lib/core/ai/pronunciation_repository.dart`

- **Claimed Functionality:** Central orchestrator of audio preprocessing, VAD, denoising, phoneme recognition, and evaluation.
- **Actual Implementation:**
  - Leaked expected phonemes directly into the recognizer:
    ```dart
    final List<PhonemeToken> recognizedTokens = phonemeEngine.recognizePhonemes(
      finalSamples,
      expectedPhonemes: targetWord.expectedPhonemes,
    );
    ```
  - Allowed execution to proceed even when VAD detected zero speech.

---

### 2.8 `lib/features/pronunciation_game/cubits/pronunciation_game_cubit.dart`

- **Vulnerability:**
  - Because `PhonemeRecognitionEngine` echoed the target phonemes with 0.85+ confidence, `assessment.passed` was always true.
  - The game awarded stars and incremented `wordsMasteredCount` on silence, screaming, noise, or wrong words.

---

## 3. Root Cause Classification Matrix

| Category | Component | Root Cause | Impact | Severity |
| :--- | :--- | :--- | :--- | :--- |
| **Ground-Truth Leakage** | `PhonemeRecognitionEngine`, `PronunciationRepository` | `expectedPhonemes` passed into acoustic inference | Recognizer only echoed target phonemes | **Critical** |
| **Simulated Inference** | `SpeechToTextEngine` | `targetHint ?? 'كورة'` returned with fake delay | ASR was completely non-functional | **Critical** |
| **Unconditional Scoring** | `PronunciationGameCubit` | Silence/noise evaluated as passed | Pedagogical and clinical validity destroyed | **Critical** |
| **Algorithm Defect** | `PronunciationEvaluator` | Naive index increment instead of DP alignment matrix | Misalignment on any omission/addition | **High** |
| **Unrealized Bindings** | `SileroVadEngine`, `RnnoiseDenoiserEngine` | Dart heuristics replacing ONNX weights | Inaccurate speech detection | **High** |
| **Fake Readiness** | `AiModelManager` | Hardcoded RAM, fake smoke tests, ghost models | Misleading diagnostics in AI Lab | **Medium** |

---

## 4. Corrective Action Plan

1. **Native On-Device Inference via `sherpa_onnx`:**
   - Integrate `sherpa_onnx.VoiceActivityDetector` utilizing `assets/ai_models/silero/silero_vad.onnx`.
   - Provide true file asset resolution from Flutter bundle to local disk for native C++ bindings.
   - Cleanly handle silence: if no speech is detected, abort evaluation with `NoSpeech` assessment (0 stars, polite prompt).
2. **Blind Acoustic Recognition (Zero Target Leakage):**
   - Eliminate all `expectedPhonemes` and `targetHint` parameters from recognition signatures.
   - The recognizer receives strictly raw audio samples and sample rate.
   - Implement real multilingual/Arabic offline inference with acoustic tokenization and phoneme mapping.
3. **True Dynamic Programming Alignment (Levenshtein DP Matrix):**
   - Implement full $(m+1) \times (n+1)$ Wagner-Fischer sequence alignment.
   - Support exact matches, phonetic substitutions, clinical error rule matching, insertions, deletions, and repetitions.
   - Ensure target phonemes (e.g., the focal consonant being trained) have appropriate clinical weighting.
4. **Pedagogical Safety in Pronunciation Game:**
   - Disallow star awards or progress on failed attempts.
   - Real supportive feedback with targeted Yasser poses and tips.
5. **AI Lab Overhaul & Lab 9 Addition:**
   - Update Labs 1–8 with real live diagnostics.
   - Add **Lab 9: Free Speech and Blind Phoneme Recognition** (`blind_phoneme_recognition_view.dart`) proving arbitrary vocabulary recognition without target bias.
6. **Automated Verification:**
   - Create real WAV audio fixtures for correct pronunciations, clinical substitutions, silence, and noise.
   - Unit tests verifying DP alignment matrix, silence rejection, and blind recognition.
