# Speech-to-Text (`Whisper Tiny INT8`) Accuracy & Limitations Report — Phase 0.1 (Workstream C)

**Working Branch:** `feature/phase0-ai-governance`  
**Model Under Audit:** `sherpa-onnx` bundled Whisper Tiny (`tiny-encoder.int8.onnx` `12.94 MB`, `tiny-decoder.int8.onnx` `82.61 MB`, `~39M` parameters, INT8 quantized).  
**Diagnostic Measurement Date:** `2026-11-27` (`test/core/ai/vad_repeatability_and_stt_diag_test.dart` -> `benchmarks/phase0/metrics_engine.py:compute_stt_metrics`).

---

## 1. Code Fixes Applied in `SpeechToTextEngine` (`lib/core/ai/speech_to_text_engine.dart`)

1. **Native Stream Leak Fixed:** Wrapped `stream.free()` in `try { ... } finally { stream?.free(); }` inside `transcribe()` so decode exceptions never leak native C++ heap memory.
2. **Decoding Limit Adjusted (`max_tokens_per_second = 24`):**
   - Previously defaulted in Sherpa-ONNX to `max_tokens_per_second = 6` (`<= ~34` tokens on a 5.7s Arabic utterance), causing legitimate adult Arabic sentences `S071`, `S073`, and `S074` (`5.3s–6.2s`) to truncate mid-word with C++ stderr warnings.
   - Raising the per-stream option to `max_tokens_per_second = '24'` eliminated premature truncation across `S071..S074` (full sentence completion observed).
3. **Short-Burst Padding (`<950ms` -> `0.95s`):** Single-word child utterances (`545ms–983ms`) are symmetrically padded to `0.95s` before Mel extraction so short plosives are not clipped at the frame window boundary.
4. **Telemetry Exposed:** Exposed `encoderPath`, `decoderPath`, and `tokensPath` getters for `AiInferenceWorker` background isolate reuse.

---

## 2. Quantitative Post-Fix Accuracy Across 30 Local Clips (Original vs VAD-Trimmed vs GTCRN-Denoised)

Computed identically using normalized Arabic text in `benchmarks/phase0/metrics_engine.py`:

| Subset | `n` | Mode | WER | CER | Normalized Exact Match (Wilson 95% CI) | Silence / Noise Hallucination Rate |
| --- | --- | --- | --- | --- | --- | --- |
| **Adult Arabic Speech (`S071..S080`)** | 10 | **Original (Unprocessed)** | **`28.68%`** (`0.286765`) | **`19.00%`** (`0.190045`) | `0 / 10` (`0.0%`, CI `0.0–27.8%`) | N/A |
| **Adult Arabic Speech (`S071..S080`)** | 10 | **VAD-Trimmed Only** | **`29.04%`** (`0.290441`) | **`18.78%`** (`0.187783`) | `0 / 10` (`0.0%`, CI `0.0–27.8%`) | N/A |
| **Adult Arabic Speech (`S071..S080`)** | 10 | **VAD + GTCRN Denoised** | **`45.04%`** (`0.450368`) | **`31.33%`** (`0.313348`) | `0 / 10` (`0.0%`, CI `0.0–27.8%`) | N/A |
| **Pediatric Correct (`S001..S010`, `545ms–983ms`)** | 10 | **Original** | **`151.22%`** (`1.512195`) | **`127.78%`** (`1.277778`) | **`1 / 10` (`10.0%`, CI `1.8–40.4%`)** (`S005` `"أمي"`) | N/A |
| **Pediatric Correct (`S001..S010`)** | 10 | **VAD-Trimmed Only** | **`158.54%`** (`1.585366`) | **`127.78%`** (`1.277778`) | **`1 / 10` (`10.0%`, CI `1.8–40.4%`)** (`S005` `"أمي"`) | N/A |
| **Pediatric Correct (`S001..S010`)** | 10 | **VAD + GTCRN Denoised** | `95.12%` (`0.95122`) | `114.81%` (`1.148148`) | **`0 / 10` (`0.0%`, CI `0.0–27.8%`)** | N/A |
| **Silence (`S081..S085`, `1.5s`)** | 5 | **Un-gated Direct STT** (Orig / Trim / Den) | N/A | N/A | N/A | **`1 / 5` (`20.0%`, `S084` -> `"سأسأسأ..."` / `"سأتعلمون"`)** |
| **Environmental Noise (`S086..S090`, `3.0s`)** | 5 | **Un-gated Direct STT** (Orig / Trim / Den) | N/A | N/A | N/A | **`5 / 5` (`100.0%`, CI `56.6–100.0%`)** (`"[السنق]"`, `"سأتعلموني"`, `"[السرح]"`, `"[مجال]"`) |

> **Note on VAD Gate Protection:** In normal `PronunciationRepository` execution (`speechToText` mode), **Silero VAD** rejects non-speech silence/noise *before* Whisper executes (`S081..S090` are blocked upstream whenever VAD returns `speechDetected == false`). Direct un-gated figures above prove why VAD gating before Whisper is mandatory.

---

## 3. Verbatim Qualitative Evidence (`S071..S074`, `S079`, `S001..S010`, `S084..S090`)

- **Post-Fix Truncation Eliminated (`S071` Egyptian Adult, `5720ms`):**
  - `GT`: `"اهلا بحضرتك يا فندم مع التامينات الاجتماعية احنا تحت امرك محتاج تستفسر عن ايه النهاردة"`
  - `ORIG`: `"أهلا بحضر ذك فندما معتأ منات لكتم عية أحن تحت أمرك معتك تستطفصر عنين نهردة"` (complete end-to-end phonetic capture; subword orthography degraded by Egyptian dialect + 39M INT8 capacity).
- **GTCRN Clean-Speech Degradation Proven Twice:**
  - `S079` (`"احمدك من اجل اني قد امتزت عجبا"`, `3990ms`): `ORIG` = `"أحمدك أن أجل أن تستطيع أجب أن"`, whereas **GTCRN Denoised collapsed into a `95`-token loop**: `"احمرك احمرك احمرك ..."` (hit `max_tokens_per_second=24` limit at `3.98s`).
  - `S072` (`6000ms`): `ORIG` decoded Arabic script cleanly (`"في السيستين"`), while GTCRN injected Latin token hallucinations (`"ATK في System"`).
  - `S009` (`"مرحبا"`, child `681ms`): `ORIG` emitted `"ويحقوا"`, while GTCRN attenuated the clean quiet word down to empty `""`.
  - **Result:** Confirming `GTCRN` gating **strictly to noisy SNR (`<14 dB`)** in `PronunciationRepository` preserves clean speech accuracy (+16.36% WER preservation on adult Arabic).
- **Child Single-Word Loops & Capacity Failure (`S001..S010`, `545ms–983ms`):**
  - Only `S005` (`"أمي"`) matched (`1/10`). Other clean isolated child words hit hallucinated MSA fragments or decoder repetition loops (`S006` `"تعال"` -> `"اي اي اي اي..."`; `S010` `"البيت"` -> `"أم أم أم أم..."`, triggering C++ `22 tokens for 0.95s` warning because repetition loops saturate *any* token-rate ceiling).

---

## 4. Honest Root-Cause Conclusion & Phase 1 / Phase 2 Recommendation

1. **Why Whisper Tiny INT8 Struggles on Child Single Words & Egyptian Arabic:**
   - **Parameter & Quantization Ceiling:** `39M` parameter multilingual `Whisper Tiny` (`INT8`) under-allocates Egyptian colloquial lexicons and short `<1s` child formants (higher pitch / spectral spacing outside adult training priors).
   - **Cross-Entropy Greedy Hallucination Loops:** Isolated noise (`S086..S090`) and brief high-pitch vowels (`S006`, `S010`) cause decoder repetition loops (`"[السنق]"`, `"اي اي..."`) without an acoustic CTC blank constraint.
   - **Pre-fix Noise:** Clean audio must NEVER pass through GTCRN unconditionally.
2. **Product Architecture Verdict (`Workstream C` Section 10):**
   - **Keep `Whisper Tiny` STRICTLY isolated** as an optional diagnostic tool inside AI Lab (`LabTaskMode.speechToText` & `fullDiagnostics` only — **NEVER** used for child gameplay pronunciation scoring or automatic pass/fail gating).
   - **Phase 1 & Phase 2 Candidates to Benchmark Against It:** Compare larger/Egyptian-adapted ASR & CTC phoneme models (`MAdel121/whisper-small-egyptian-arabic`, `openai/whisper-large-v3-turbo` as cloud/offline teacher, `EgypTalk-ASR-v2`, `MostafaMaroof/wav2vec2-arabic-phoneme-asr`, and `Citrinet/Zipformer` candidates) strictly on the **`2,000`-sample Phase 1/2 Egyptian pediatric & adult benchmark** with explicit latency/RAM budgets.
