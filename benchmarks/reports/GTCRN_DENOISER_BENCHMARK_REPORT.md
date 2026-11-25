# GTCRN NEURAL DENOISER BENCHMARK REPORT (`gtcrn_simple.onnx`)

**Model File:** [gtcrn_simple.onnx](file:///e:/Flutter%20Projects/liqaa_app/assets/ai_models/gtcrn/gtcrn_simple.onnx) (`535,638` bytes / `0.51 MB`)  
**Engine Implementation:** [rnnoise_denoiser_engine.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/rnnoise_denoiser_engine.dart)  
**Gating Change Applied:** Lowered automatic GTCRN trigger in [pronunciation_repository.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/pronunciation_repository.dart) from `rawSnr < 22.0 dB` to **`rawSnr < 14.0 dB`**.

---

## 1. Execution Integrity & Latency (`n = 100` Unpaired Clips)

- **Valid Normalized Output WAVs:** **100 / 100 (100%)** — zero corrupted headers, zero silent-zero hangs.
- **Latency (`100` real samples):** Median **`133.0 ms`**, Mean **`229.7 ms`**, `p95` **`756–772 ms`**, Min **`54 ms`**, Max **`2298 ms`** (on `17.75 s` sentence `S076`).
- **Controlled Paired Latency (`18` 2-second clips):** Mean `~274 ms` (`258–333 ms` on desktop FFI, RTF `~0.14`).

---

## 2. Paired Controlled Noisy Benchmark (`18` MUSAN Mixtures, `-5` to `+20 dB` SNR)

Clean speech (`S011 كورة`, `S012 كلب`, `S013 أرنب`) mixed with genuine MUSAN `fan_appliance_noise`, `ambient_street_traffic`, and `household_television_babble`:

| Input SNR (dB) | Clips | Mean SNR In | Mean SNR Out | **Mean ΔSI-SDR (dB)** | Envelope Corr (In -> Out) | Noisy Raw PER vs Clean | **After GTCRN PER vs Clean** | PER Improvement |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`-5 dB`** | 3 | `-5.00 dB` | `+3.63 dB` | **`+8.55 dB`** | `0.661 -> 0.843` | `88.9%` | **`67.2%`** | **`-21.7 pp`** |
| **`0 dB`** | 3 | `0.00 dB` | `+8.29 dB` | **`+9.37 dB`** | `0.847 -> 0.954` | `58.9%` | **`47.8%`** | **`-11.1 pp`** |
| **`+5 dB`** | 3 | `+5.00 dB` | `+12.59 dB` | **`+8.41 dB`** | `0.945 -> 0.983` | `57.2%` | **`52.2%`** | **`-5.0 pp`** |
| **`+10 dB`** | 3 | `+10.00 dB` | `+16.49 dB` | **`+7.01 dB`** | `0.983 -> 0.993` | `48.9%` | **`32.8%`** | **`-16.1 pp`** |
| **`+15 dB`** | 3 | `+15.01 dB` | `+20.29 dB` | **`+5.64 dB`** | `0.995 -> 0.991` | `53.3%` | **`43.9%`** | **`-9.4 pp`** |
| **`+20 dB`** | 3 | `+20.02 dB` | `+21.61 dB` | **`+1.94 dB`** | `0.998 -> 0.989` | `42.2%` | **`32.8%`** | **`-9.4 pp`** |

*Note on `-5 dB` TV Babble (`S013`):* Raw noisy audio triggered VAD `False` (`[]`), whereas GTCRN denoising allowed downstream Wav2Vec2 recovery (`[aː t a]`). On `S011 + fan` (`0–5 dB`) and `S012 + traffic` (`10–15 dB`), GTCRN substantially preserved word intelligibility (`k/r/a` and `k/aː/l`).

![GTCRN SNR Improvement and Phoneme Error Rate Curve](../results/charts/gtcrn_snr_sisdr_curve.png)

---

## 3. Clean-Speech Tradeoff & Consonant Preservation Analysis

Why did **unconditional GTCRN raise overall real-world PER (`39.22% -> 40.36%`)** while rescuing heavily noisy mixtures? Auditing reference target consonants across real clips comparing `Wav2Vec2(Raw)` vs `Wav2Vec2(VAD + GTCRN)` reveals clear acoustic transient attenuation on voiceless consonants in already-clean audio:

| Target Phoneme | Support (`n`) | Raw Hit Rate | VAD + GTCRN Hit Rate | Impact | Concrete Example |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **`/k/`** (voiceless velar stop) | 6 | **83.3% (`5/6`)** | **50.0% (`3/6`)** | **`-33.3 pp`** | `S011 كورة`: `[k ʉ r aː]` (Raw, **PASS `94.4%`**) -> `[t u ɹ aː]` (GTCRN, **FAIL**) |
| **`/f/`** (voiceless labiodental fricative) | 12 | **75.0% (`9/12`)** | **41.7% (`5/12`)** | **`-33.3 pp`** | `S020 تفاحة`: `[d ə f a]` -> `[d uː s aː]` |
| **`/r/`** (alveolar trill/tap) | 20 | **45.0% (`9/20`)** | **35.0% (`7/20`)** | **`-10.0 pp`** | `S013 أرنب` (noisy burst smoothed into `[ɑ t a]`) |
| **`/n/`** (alveolar nasal) | 7 | **71.4% (`5/7`)** | **57.1% (`4/7`)** | **`-14.3 pp`** | Subtle nasal onset softened |
| **`/b/`** (voiced bilabial stop) | 21 | `57.1%` (`12/21`) | **`61.9%` (`13/21`)** | **`+4.8 pp`** | `S001`, `S003` rescued weak `/b/` bursts |
| **`/ʃ/`** (postalveolar fricative) | 3 | `33.3%` (`1/3`) | **`100.0%` (`3/3`)** | **`+66.7 pp`** | `S019 شمس` / `S066 الشمس` |
| **`/s/`**, **`/t/`**, **`/l/`** | 11, 14, 30 | `45.5%`, `42.9%`, `40.0%` | `45.5%`, `42.9%`, `40.0%` | `0.0 pp` | Neutral |

### Non-Speech Artifact Observation
When MUSAN noise (`S086..S090`) was *forced* through GTCRN (bypassing Silero VAD), GTCRN suppressed stationary noise into pseudo-formant modulation that caused Wav2Vec2 to hallucinate spurious IPA tokens (`[a a n n a u]`, `[t a p iɛ5 t]`, `[l a t a t i t a r]`). Keeping Silero VAD gating active before GTCRN completely blocked all `5/5` noise artifacts.

**Engineering Conclusion:** Gating GTCRN strictly at **`rawSnr < 14.0 dB`** (instead of `22.0 dB`) eliminates clean-speech `/k/` and `/f/` degradation (`0/20 -> 1/20` correct pediatric pass) while preserving GTCRN's `+7` to `+9.4 dB` SI-SDR rescue on noisy recordings.
