# FAILURE ANALYSIS & CLINICAL REMEDIATION PLAN

## 1. Summary of Verified Engineering Fixes Applied in This Audit

All code fixes were verified with `flutter analyze` (`No issues found!`), `flutter test` (including new regression tests in [real_onnx_end_to_end_test.dart](file:///e:/Flutter%20Projects/liqaa_app/test/core/ai/real_onnx_end_to_end_test.dart)), and a full post-fix re-run of the 100-sample ONNX benchmark:

1. **VAD-Before-Normalization Sequencing ([pronunciation_repository.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/pronunciation_repository.dart)):**
   - *Bug:* Running `normalizePeak` before `SileroVAD` amplified quiet trailing noise floors and caused VAD clipping of initial voiceless stops (`S012 كلب`), while `rawRms < 0.002` falsely aborted quiet-padded recordings (`S018 قلم`) before VAD inspected the peak burst.
   - *Fix:* Switched silence check to `rawPeak < 0.002` and ran `SileroVAD` on raw unnormalized audio prior to `normalizePeak`. Result: `S018` recovered speech detection (`654 ms`), `correct_pediatric` `noSpeech` dropped `2 -> 1`.
2. **GTCRN Conditional Gating Threshold Lowered `22.0 dB -> 14.0 dB` ([pronunciation_repository.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/pronunciation_repository.dart)):**
   - *Bug:* High threshold (`22 dB`) ran GTCRN on nearly all real recordings, erasing clean child `/k/` (`83.3% -> 50.0%`) and `/f/` (`75.0% -> 41.7%`).
   - *Fix:* Gated automatic denoising to `rawSnr < 14.0 dB` while preserving GTCRN's `+7.0` to `+9.4 dB` SI-SDR rescue on `-5..+10 dB` noisy clips. Result: `S011 كورة` and `S091 كاف` both preserved `/k/` and passed (`94.4%` & `91.0%`).
3. **VAD Segment Merge Gap Widened `100 ms -> 350 ms` ([silero_vad_engine.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/silero_vad_engine.dart)):**
   - Prevents artificial frame splices during short intra-word stop closures (`adult_arabic_speech` mean retained duration rose `8057.0 ms -> 8068.4 ms`).
4. **eSpeak Vowel Allophone `[ʉ]` & Tone-Digit Handling ([pronunciation_evaluator.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/pronunciation_evaluator.dart)):**
   - Added rounded close-central `'ʉ'` (emitted for child `/uː/` in `S011 [k ʉ r aː]`), plus `'aɪ'`, `'ɑu'`, `'y'` equivalences and trailing eSpeak tone-digit stripping (`'5'`, `'.'`). Lifting `S011` from `74.8% -> 94.4%` and raising `correct_pediatric` mean score `30.2 -> 35.5` (`quiet_weak` `28.0 -> 32.7`).
5. **Phoneme Engine Silence Floor Fix ([phoneme_recognition_engine.dart](file:///e:/Flutter%20Projects/liqaa_app/lib/core/ai/phoneme_recognition_engine.dart)):**
   - Changed low-energy skip from `rms < 0.002` alone to `rms < 0.0005 && peak < 0.003` so quiet isolated consonants are not silently zeroed out.

---

## 2. Prioritized Root-Cause Backlog (Why Pediatric Acceptance Is Still `1/20 = 5.0%`)

Despite zero leakage and rock-solid DSP hygiene, the core acoustic model + scoring contract remains **unready for real young children**:

| Priority | Failure Mode | Quantitative Evidence | Concrete Engineering Solution |
| :---: | :--- | :--- | :--- |
| **P0 (Critical)** | **Wav2Vec2-eSpeak Adult/Cross-Lingual Domain Gap** | `14.79%` PER on Adult MSA vs **`71.88%` Clean Child PER** (`ASMDD 80.0%`); emits Mandarin tones (`ɑu5`, `yɜ`, `s.`) on child vowels (`S009`, `S037`) | Fine-tune / LoRA-adapt a compact Arabic Wav2Vec2/HuBERT-CTC phoneme encoder (`wav2vec2-large-xlsr-53` or `HuBERT-Arabic` distilled to ONNX INT8) on **ASMDD + Abjad-Kids** with pitch perturbation + Arabic IPA head (`36` Arabic phonemes only — eliminates non-Arabic `yɜ/ɬ/5` emissions) |
| **P1 (High)** | **Whole-Word Dictionary Template & Prefix Rigidity** | `S069 المدرسة` scored `67.9%` (`[m a d ɾ a s a]`) & rejected because static template expects `'الـ'` `[aː l]`; `S014 فراشة` scored `78.1%` (missed `80%` bar by `1.9 pts`); `11` `/l/` deletions + `10` `/ʔ/` deletions | Support optional definite-article `'الـ'` `[aː l]` prefix variants & weak initial `/ʔ/` tolerance in `egyptian_arabic_dictionary.json`, and score **target therapy phoneme + syllable nucleus** (e.g. target consonant `/f/` or `/k/` acoustic posterior) separately from unstressed coda/vowel noise |
| **P1 (High)** | **Emphatic & Pharyngeal Collapse (`/dˤ, tˤ, ʕ, ħ, ɣ/`)** | `0.000` F1 on `/dˤ, tˤ, ɣ/`, `0.308` F1 on `/ʕ/`, `0.500` F1 on `/ħ/` | Either train an Arabic phoneme inventory model (eliminating IPA collapse) or expose target-specific articulation modes where plain `[t]` isn't falsely treated as full `/tˤ/` confusion unless explicitly training emphasis |
| **P2 (Medium)** | **3 VAD False Negatives on Ultra-Quiet/Noisy Clips** | `S017` (`rms 0.0026`), `S059` (`4.89 dB`), `S063` (classroom chatter) missed by Silero VAD (`96.67%` recall) | If VAD returns empty on a recording with `rawPeak >= 0.015`, automatically run **GTCRN first and retry Silero VAD** (`controlled S013 -5 dB` proved GTCRN unlocks missed noisy speech!) |
| **P2 (Medium)** | **APK Bundle Weight & Physical Android Profiling** | `289 MB` of ONNX models on disk; no Android hardware measurement yet | Measure ARM64 inference latency + RSS via on-device **AI Benchmark Lab** (`/ai-lab/suite`) and exclude `Whisper Tiny` (`98.8 MB`) from child release builds |
