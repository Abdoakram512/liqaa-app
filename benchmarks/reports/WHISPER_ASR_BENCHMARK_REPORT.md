# WHISPER TINY INT8 ASR BENCHMARK REPORT (`tiny-encoder/decoder.int8.onnx`)

**Model Assets:** [tiny-encoder.int8.onnx](file:///e:/Flutter%20Projects/liqaa_app/assets/ai_models/whisper_tiny/tiny-encoder.int8.onnx) (`12.34 MB`) + [tiny-decoder.int8.onnx](file:///e:/Flutter%20Projects/liqaa_app/assets/ai_models/whisper_tiny/tiny-decoder.int8.onnx) (`85.69 MB`) + [tiny-tokens.txt](file:///e:/Flutter%20Projects/liqaa_app/assets/ai_models/whisper_tiny/tiny-tokens.txt) (`0.78 MB`)  
**Engine Implementation:** [speech_to_text_engine.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/speech_to_text_engine.dart)  
**Architectural Role in LIQAA:** Strictly diagnostic / optional ASR transcript in AI Labs — **NOT** used to gate or drive clinical phoneme evaluation.

---

## 1. Benchmark Metrics Across `80` Audited Utterances

| Metric | Measured Result | Scope |
| :--- | :---: | :--- |
| **Word Error Rate (WER)** | **86.60%** | `70` spoken utterances (`60` pediatric words/letters + `10` adult Arabic utterances) |
| **Character Error Rate (CER)** | **41.19%** | Same `70` spoken utterances |
| **Non-Speech Hallucination Rate** | **50.0% (`5 / 10`)** | `0 / 5` on digital silence; **`5 / 5 (100%)`** on MUSAN environmental noise |
| **Latency (`p50` / `mean` / `p95` / `max`)** | **`242 ms` / `394.5 ms` / `1326–1367 ms` / `3271 ms`** | Desktop Windows ONNX FFI (`OfflineWhisperModelConfig`) |

---

## 2. Empirical Error Modes Observed

### A. Hallucinations on Pure Environmental Noise (`5 / 5`)
When fed unvoiced MUSAN non-speech recordings (`S086..S090`), Whisper Tiny INT8 invented fluent-looking Arabic boilerplate and bracketed hallucinations:
- `S086` (`fan_appliance_noise`): `"[السنق] [السنق] [السنق]"`
- `S087` (`ambient_street_traffic`): `"سأتعلموني"` *(also seen on faint pediatric speech `S017 كتاب` -> `"سأتعلم"`)*
- `S088` (`household_television_babble`): `"[السرح] [السرح] [السرح]"`
- `S089` (`classroom_crowd_ambience`): `"[مجال] [مجال] [مجال] [مج"`
- `S090` (`mic_handling_environmental`): `"[لوك] [لوك] [لوك] [لو"`

### B. Semantic Auto-Correction Destroys Therapy Signals
Because Whisper's sequence decoder uses an Arabic language model prior, it either **auto-corrects** mispronounced speech or **substitutes higher-frequency dictionary neighbors** instead of reflecting child phonetics:
- `S011` (`كورة`): transcribed **`"برأس"`** (completely wrong word, even though child acoustic phonemes passed at `94.4%`!).
- `S012` (`كلب`): transcribed **`"هل"`**.
- `S014` (`فراشة`): transcribed **`"فلاشة"`**.
- `S091` (`كاف`): repeated hallucination loop **`"سأسأسأس"`** despite valid acoustic emission `[k a f]`.
- Conversely, on longer Adult MSA (`S075–S077`) Whisper is far more coherent (e.g., `S075`: `"اتاحت للباء المتجابل أن يكون جاتبا للمواطن الأقل لدخلن"`), proving the failure on single-word therapy clips stems from short isolated context (`0.44–2.0 s`) + child pitch + `tiny` multilingual capacity.

### C. Sherpa-ONNX C++ Runtime Warning (`max_tokens_per_second`)
Running `Whisper` on short audio emits Sherpa-ONNX's internal warning:  
`Consider increasing max_tokens_per_second ... if decoding truncates on short utterances`.  
Auditing [offline_recognizer.dart](file:///C:/Users/pc/AppData/Local/Pub/Cache/hosted/pub.dev/sherpa_onnx-2.0.3/lib/src/offline_recognizer.dart#L1-L60) confirmed `sherpa_onnx 2.0.3` Dart `OfflineWhisperModelConfig` does **not** expose `maxTokensPerSecond` at the Dart FFI boundary.

**Architectural Verdict:** This independent evaluation vindicates LIQAA's decision to strip Whisper from pronunciation scoring — relying on Whisper would simultaneously miss clinical phoneme substitutions (`ت -> ك` auto-corrected to real words), suffer `86.6%` WER on children, and hallucinate Arabic words over household fan/TV noise.
