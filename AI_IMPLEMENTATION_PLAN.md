# LIQAA — AI Speech & Pronunciation Recognition Implementation Plan

## 1. Executive Summary & Objective

**LIQAA (لقاء)** is an offline-first, free, non-commercial interactive speech development and pronunciation training application for Egyptian Arabic-speaking children, guided by its main character **Yasser (ياسر)**.

The objective of this AI subsystem is to establish an on-device, production-quality AI speech and phonetic evaluation pipeline that operates with **zero recurring cloud costs**, **zero paid APIs**, and **complete offline privacy**. The pipeline recognizes children's speech, extracts phoneme sequences with acoustic confidence and frame timings, detects developmental articulation errors (Substitution, Deletion, Insertion, Distortion), and delivers immediate, encouraging pedagogical feedback in Egyptian Arabic.

---

## 2. AI Model Selection & Specifications

| Model Name | Role in Pipeline | Architecture | Quantization / Format | Size | License | Source / Repository |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Silero VAD v4** | Voice Activity Detection (VAD) | Deep Feedforward + LSTM | INT8 / FP32 ONNX | 2.10 MB | MIT (Permissive Open Source) | [snakers4/silero-vad](https://github.com/snakers4/silero-vad) |
| **RNNoise** | Acoustic Noise Suppression | Hybrid GRU + Classical DSP | INT8 / FP32 ONNX | 0.97 MB | BSD-3-Clause (Permissive) | [xiph/rnnoise](https://github.com/xiph/rnnoise) / [niobures/RNNoise](https://huggingface.co/niobures/RNNoise) |
| **Zipformer Arabic V3** | Primary Phoneme Recognition | Streaming Zipformer2 + CTC | INT8 ONNX | 65.5 MB | Quran-Lab No-Profit License 1.3 | [Quran-Lab/zipformer_p-arabic-v3](https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3) |
| **Zipformer Arabic V2** | Benchmark Phoneme Recognition | Streaming Zipformer2 + CTC | INT8 ONNX | 65.0 MB | Free Non-Commercial Research | [Muno459/zipformer_p-arabic-v2](https://huggingface.co/Muno459/zipformer_p-arabic-v2) |
| **Nabra 82M / Moonshine** | Word-Level ASR Validation | Conformer / Transformer | INT8 ONNX | 17.4 – 79.3 MB | Apache 2.0 / MIT | [csukuangfj/nabra-82m-arabic-int8](https://huggingface.co/csukuangfj/nabra-82m-arabic-int8) |

---

## 3. Egyptian Arabic Support & Suitability for Children's Speech

### 3.1 Dialectal Phonetic Adaptation
Egyptian Arabic possesses characteristic phonetic transformations compared to Modern Standard Arabic (MSA):
1. **Qaf (ق) $\rightarrow$ Glottal Stop [ʔ] (ء):** In everyday Egyptian Arabic, /q/ is pronounced as a glottal stop (e.g., قلم is pronounced [ʔalam]). The vocabulary and evaluator recognize both MSA and Egyptian realizations.
2. **Jim (ج) $\rightarrow$ Voiced Velar Plosive [ɡ]:** The Egyptian "Gim" is an un-affricated stop [ɡ] (e.g., جمل [ɡamal]). The phoneme tokenizer specifically registers [ɡ] (`ɡ`, token 32).
3. **Interdentals (ث, ذ, ظ) $\rightarrow$ Dental/Alveolar Plosives or Sibilants:**
   - ث /θ/ $\rightarrow$ ت /t/ or س /s/ (e.g., ثعلب $\rightarrow$ تعلب).
   - ذ /ð/ $\rightarrow$ د /d/ or ز /z/ (e.g., ذئب $\rightarrow$ ديب, ذهب $\rightarrow$ دهب).
   - ظ /ðˤ/ $\rightarrow$ ض /dˤ/ or ز /z/.

### 3.2 Acoustic Adaptation for Pediatric Voices
Children have shorter vocal tracts, higher fundamental frequencies ($F_0 \approx 250\text{--}450\text{ Hz}$ vs. $100\text{--}200\text{ Hz}$ for adults), and less precise motor-speech control. To ensure children's speech is accurately processed:
- **Silero VAD Thresholding:** Lower speech probability threshold ($0.35$ instead of $0.50$) with a minimum speech duration of $150\text{ ms}$ and speech silence padding of $300\text{ ms}$ prevents cutting off quiet phonemes, fricatives, and initial stops.
- **Formant Normalization:** Spectral pre-emphasis and peak normalization ensure that high-frequency children formants ($F_1, F_2, F_3$) are preserved without clipping.
- **Acoustic Margin Tolerance:** The phonetic evaluator incorporates an acoustic margin factor ($\Delta_{margin} \ge 0.15$) to prevent penalizing child phonetic variability that does not constitute an articulation pathology.

---

## 4. Platform Compatibility & Hardware Footprint

### 4.1 Target Platforms
- **Android:** Android 5.0+ (API level 21 minimum, API level 26+ recommended for hardware NN acceleration). Supported ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- **iOS:** iOS 12.0+ (ARM64). Supports CoreML acceleration through ONNX Runtime / Sherpa-ONNX CoreML EP.
- **Desktop / Simulator (Windows/macOS/Linux):** Fully supported via cross-platform ONNX native binaries and DSP fallback engines for seamless CI/CD.

### 4.2 Storage and Memory Budget
| Component | Storage Footprint | RAM Footprint (Active) | CPU Load (Single Core) | Latency (2.0s Audio) |
| :--- | :--- | :--- | :--- | :--- |
| **Silero VAD** | 2.1 MB | ~12 MB | < 2% | 15–25 ms |
| **RNNoise** | 0.97 MB | ~8 MB | < 4% | 20–35 ms |
| **Zipformer V3 (int8)** | 65.5 MB | ~110 MB | 15–28% | 85–140 ms |
| **Dictionary & Logic** | 0.15 MB | ~2 MB | < 0.1% | 2–5 ms |
| **Total Pipeline** | **~68.7 MB** | **~132 MB** | **~25%** | **~130–180 ms** |

---

## 5. Audio Preprocessing Pipeline

```text
Microphone Input (16kHz / 48kHz, PCM 16-bit)
   │
   ▼
[AudioRecorderService] ── Record 16,000 Hz Mono WAV / Buffer
   │
   ▼
[AudioPreprocessor] ──── DC-Offset Removal & Peak Normalization (-1.0 to +1.0)
   │
   ├───> [SileroVadEngine] ──── Detect Speech Segments (Start/End Timestamps, Silence Trim)
   │
   ├───> [RnnoiseDenoiser] ──── (Optional/Toggleable) Background Noise Reduction
   │
   ▼
[PhonemeRecognitionEngine] ── 80-bin Mel Filterbank ──> Streaming Zipformer CTC Head
   │
   ▼
Recognized Phoneme Stream [Tokens, Frame Durations, Posterior Probabilities]
   │
   ▼
[PronunciationEvaluator] ──── Dynamic Time Warping & Weighted Levenshtein Alignment
   │
   ▼
Diagnostic Output (Accuracy %, Substitution/Deletion Classification, Yasser Voice Feedback)
```

---

## 6. Implementation Phases

- **Phase 1: Environment & Dependency Setup (Done):** Storage cache optimization, permission handling (`RECORD_AUDIO`), `audioplayers`, `record`, and `sherpa_onnx` resolution.
- **Phase 2: Model Acquisition & Manifestation (Done):** Direct ONNX retrieval of Silero VAD (2.1 MB) and RNNoise (0.97 MB); tokens and phoneme specification generated; Gated Hugging Face auth documented.
- **Phase 3: Core AI Subsystem (`lib/core/ai/`):** Building recorder, preprocessor, VAD engine, denoiser engine, phoneme recognizer, pronunciation evaluator, and model manager.
- **Phase 4: Yasser AI Lab Developer Suite (`lib/features/ai_lab/`):** 7 dedicated developer screens with live waveform, metrics, raw outputs, and export tools.
- **Phase 5: "Speak With Yasser" Game (`lib/features/pronunciation_game/`):** Child-friendly Arabic RTL interface, 28 vocabulary cards, celebratory animations, Yasser poses, and speech hints.
- **Phase 6: Verification, Testing & Reports:** Unit tests, benchmark generation, limitations documentation, and final validation.

---

## 7. Potential Technical Risks & Fallback Strategies

| Identified Risk | Impact | Mitigation / Fallback Strategy |
| :--- | :--- | :--- |
| **Gated Hugging Face Repositories** | Zipformer V2/V3 require HF Token | `download_models.py` accepts `--hf-token`; complete token mapping provided locally; fallback acoustic CTC evaluator runs seamlessly offline. |
| **RNNoise Attenuating Weak Fricatives** | Denoising might eliminate quiet children sounds (e.g., [s], [f], [ħ]) | RNNoise is toggleable by default; AI Lab screen allows side-by-side SNR and PER comparison; default game mode keeps raw audio if SNR is above 18 dB. |
| **Device Storage Limitations** | Models exceed user disk budget | Modular on-demand downloading via `AiModelManager`; cache models in App Support directory; int8 quantization keeps entire suite under 70 MB. |
| **Microphone Background Noise** | False speech triggers | Silero VAD energy hysteresis + adaptive noise floor calibration before speech start. |

---

## 8. Acceptance Criteria

1. Zero recurring cloud AI fees and zero external API dependencies.
2. Complete local offline execution on both Android and iOS devices.
3. Accurate detection of speech start, end, and duration via Silero VAD.
4. Independent toggle for RNNoise noise suppression with measurable SNR metrics.
5. Accurate phonetic alignment and classification of common Egyptian speech substitutions (e.g., كورة $\rightarrow$ تورة detected as Fronting with target /k/ and substituted /t/).
6. Seven functional developer screens in Yasser AI Lab with exportable benchmark metrics.
7. Polished, child-friendly Arabic game interface featuring Yasser's character poses and encouraging vocal/text prompts.
8. Comprehensive test suite and complete documentation suite matching the architecture.
