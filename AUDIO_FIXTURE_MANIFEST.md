# LIQAA — Audio Fixture Manifest & Specification

## 1. Overview

All automated test suites, clinical benchmarks (Lab 8), and quick reproducible tests (Lab 9) utilize standardized 16 kHz 16-bit mono PCM audio fixtures stored in `assets/audio_samples/`.

These fixtures represent distinct pediatric speech conditions, clinical articulation disorders, and acoustic edge cases.

---

## 2. Audio Fixture Inventory

| File Name | Duration | Sample Rate | Channels | Format | Target Word | Spoken Utterance | Acoustic / Clinical Category | Expected Diagnosis |
|---|---|---|---|---|---|---|---|---|
| `correct_kora.wav` | 1,200 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | كورة | كورة | Clean Pediatric Speech | **Pass (3 Stars)**, `correct` |
| `error_tora.wav` | 1,200 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | كورة | تورة | Velar Fronting [k] -> [t] | **Fail (1 Star)**, `substitution` (Fronting) |
| `correct_samaka.wav` | 1,500 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | سمكة | سمكة | Clean Pediatric Speech | **Pass (3 Stars)**, `correct` |
| `error_thamaka.wav` | 1,300 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | سمكة | ثمكة | Interdental Lisp [s] -> [θ] | **Fail (1 Star)**, `substitution` (Lisp) |
| `correct_arnab.wav` | 1,200 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | أرنب | أرنب | Clean Pediatric Speech | **Pass (3 Stars)**, `correct` |
| `error_anlab.wav` | 1,200 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | أرنب | أنلب | Lateralization [r] -> [l] | **Fail (1 Star)**, `substitution` (Lateralization) |
| `word_madrasa.wav` | 1,400 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | كورة | مدرسة | Unrelated Target Word | **Fail (1 Star)**, `unrelatedWord` (< 30% score) |
| `silence.wav` | 1,500 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | Any | *Digital Silence* | Zero Acoustic Energy (RMS < 0.001) | **Fail (0 Stars)**, `noSpeech` |
| `white_noise.wav` | 1,500 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | Any | *White Noise* | Stationary Noise (SNR < 1 dB) | **Fail (0 Stars)**, `noSpeech` / `poorAudioQuality` |
| `noisy_speech.wav` | 2,000 ms | 16,000 Hz | 1 (Mono) | 16-bit PCM | كورة | كورة + Noise | Low SNR Speech (SNR ~ 6 dB) | **Pass / Sub-optimal**, Denoiser active |

---

## 3. Acoustic Properties & Verification

```
File: correct_kora.wav
├── RIFF/WAVE Header: 44 bytes
├── Format: PCM (1)
├── Channels: 1
├── Sample Rate: 16,000 Hz
├── Byte Rate: 32,000 B/s
├── Block Align: 2 bytes
├── Bits Per Sample: 16
├── Total Data Length: 38,400 bytes (19,200 samples = 1.200s)
└── RMS Energy: ~0.092 (Strong pediatric consonant attack)

File: silence.wav
├── Total Data Length: 48,000 bytes (24,000 samples = 1.500s)
└── RMS Energy: 0.00000 (Exact digital silence, zero falsification)
```

---

## 4. Ground-Truth Leakage Prevention

To ensure absolute scientific validity:
- None of the recognition engines (`SpeechToTextEngine`, `PhonemeRecognitionEngine`) receive the file name, target word ID, expected phonemes, or expected text.
- Recognition engines only receive raw `Float32List` sample buffers.
- Evaluation against the target word occurs strictly downstream in `PronunciationEvaluator.evaluate()` via dynamic programming alignment.
