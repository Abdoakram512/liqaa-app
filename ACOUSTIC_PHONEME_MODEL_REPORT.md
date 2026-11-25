# Acoustic Phoneme Model Selection & Verification Report

## 1. Why Whisper + G2P Was Replaced
Using Whisper Tiny + Grapheme-to-Phoneme (`textToPhonemes`) fundamentally undermined speech therapy diagnostics:
- Word-level ASR auto-corrects child speech substitutions (or hallucinates unrelated Arabic tokens on short/single-word recordings such as `"أولا"` on `kora` and repeated tokens on silence).
- `textToPhonemes` split letters linearly across audio duration (`isTimestampEstimated: true`) rather than measuring true frame-level acoustic boundaries.

---

## 2. Candidate Acoustic Models Evaluated

| Candidate Model | Size (ONNX) | License | Arabic IPA Coverage | Findings |
| :--- | :--- | :--- | :--- | :--- |
| `allan-valin/allosaurus-onnx` | `42.85` MB | **GPL-3.0** | Incomplete (missing `ħ, ʕ, tˤ, sˤ, dˤ, ðˤ`) | Incompatible copyleft license and lacks core Arabic pharyngeals/emphatics |
| `allan-valin/allophant-onnx` | `340.82` MB | Open research | Incomplete (missing `ħ, ʕ, ʔ, tˤ, sˤ, dˤ, ðˤ`) | Large footprint and missing core Arabic consonants |
| `onnx-community/wav2vec2-base-arabic-without-reused-en-token-ids-v1-ONNX` | `66.4` MB (Q4F16) | Apache-2.0 | 36 Arabic orthographic characters | Good fast secondary Arabic CTC character model, but orthographic rather than IPA phone-level |
| **`onnx-community/wav2vec2-lv-60-espeak-cv-ft-ONNX` (`model_q4f16.onnx`)** | **`187.8` MB** | **Apache-2.0** | **392 IPA units** (`ħ, ʕ, ʔ, χ, ɣ, q, dˤ, θ, ð, ʃ, s, k, t, r, l, ...`) | **Selected Primary Engine:** True multilingual acoustic CTC phoneme recognizer emitting genuine IPA units without target leakage and producing empty output (`[]`) on silence/tones |

---

## 3. On-Device Execution & Calibrated Decoding Architecture
Because `model_q4f16.onnx` uses quantized `MatMulNBits` operators unsupported by older ONNX Runtime builds, `lib/core/ai/ort_dynamic_session.dart` dynamically binds directly to `sherpa_onnx`'s already-bundled ONNX Runtime **v1.28.2** (`OrtGetApiBase()->GetApi(22)`).

In `lib/core/ai/phoneme_recognition_engine.dart`:
1. Input 16kHz mono Float32 samples undergo zero-mean unit-variance normalization (`mean / sqrt(var + 1e-7)`).
2. Output logits `[1, T, 392]` undergo per-frame softmax normalization (`exp(logit - maxLogit) / sumExp`).
3. `<pad>` blanks (`0`) and special boundary tokens (`<s>`, `</s>`, `<unk>`, `|`) are skipped while tracking true frame spans (`startFrame..endFrame`).
4. Each collapsed CTC token records:
   - `confidence`: mean softmax top-1 posterior probability across active frames (`0.0` to `1.0`).
   - `acousticMargin`: mean `top1_prob - top2_prob` across active frames.
   - `startMs` / `endMs`: true frame-derived millisecond spans (`isTimestampEstimated: false`).

---

## 4. Measured Outputs on Verified Audio Fixtures
Using ORT `v1.28.2` Dart FFI on bundled WAV assets:
- **Real Human Adult Arabic Speech (`assets/audio_samples/human_arabic_adult.wav`, `4.87s` from `tunis-ai/arabic_speech_corpus`):**
  Decoded `[i z s a a ħ d u r u l i q aː ʔ a h aː ð a l q aː m i χ a m s u n w a θ a l aː θ uː n aː m i n h u m]` (mean posterior `0.731`), capturing Arabic pharyngeals (`ħ`), glottal stop (`ʔ`), uvulars (`q`, `χ`), interdentals (`θ`, `ð`), and long vowels.
- **Minimal Pair Speech Fixtures (Edge Neural Arabic TTS, 16kHz):**
  - `correct_kora.wav` ("كورة") -> `[k oː r ə]` (PASS against `word_kora`).
  - `error_tora.wav` ("تورة") -> `[t uː r a]` (FAIL against `word_kora` — Fronting substitution).
  - `correct_arnab.wav` ("أرنب") -> `[a r n a b m i]` (PASS against `word_arnab`).
  - `error_anlab.wav` ("أنلب") -> `[ʔ a l l a b]` (FAIL against `word_arnab` — Lateralization substitution).
  - `word_madrasa.wav` ("مدرسة") -> `[m ɛ d r a s]` (FAIL against `word_kora` — unrelated word `< 30%`).
- **Silence (`silence.wav`, `1.50s`):**
  Decoded `[]` (`0` tokens, `0` false hallucinations).

---

## 5. Known Validation Boundaries (Pediatric Speech Limitation)
No real Egyptian pediatric child recordings (aged 3–10) were present in this repository or recorded via a physical device during host verification. Therefore:
- Verification covers **adult Arabic human speech**, **Arabic neural TTS minimal pairs**, **synthetic silence/white noise**, and **additive-noise / low-amplitude stress cases**.
- **Pediatric pronunciation accuracy on real child voices remains clinically unvalidated** and requires prospective testing with real Egyptian Arabic children using the updated pipeline.
