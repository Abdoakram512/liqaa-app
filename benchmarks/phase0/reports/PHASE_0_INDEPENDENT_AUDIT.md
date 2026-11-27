# Phase 0 Final Independent Audit Report

Branch Audited: `feature/phase0-ai-governance`
Audit Date UTC: `2026-11-27`

## 1. Executive Verdict: **CONDITIONAL PASS**

Phase 0 AI Integrity, Dataset Governance, Leakage Detection, Blind Freeze Architecture, and Yasser AI Lab visibility have passed independent adversarial auditing and full regression testing (`11/11` Python governance & adversarial tests, `15/15` anti-cheating checks, `flutter analyze` `0` issues, `115/115` Flutter tests passed).

The verdict is **CONDITIONAL PASS** (not full unconditional Stage B sign-off) because of four real external/data conditions:
1. **Stage B Blind Holdout Not Yet Populated (`stage_b_frozen = false`):** An empty blind dataset cannot be certified as independently validated; Phase 0 proves the *lock/isolation mechanism*, while Stage B data acquisition occurs in Phase 3.
2. **`C:` System Drive Critically Low (`2.08 GB` free):** All ML caches/datasets are isolated on `D:\YasserML` (`270.72 GB` free), but system updates or Windows SDK builds remain at risk until user cleanup on `C:`.
3. **External Candidate Licenses & Contamination Limits:** Five candidate datasets/models have access, license, or documented overlap restrictions (`ASMDD` overlap with `MON3EMPASHA/SmartArabicSpeechTherapy`; `arabic_speech_corpus` overlap with `MostafaMaroof/wav2vec2-arabic-phoneme-asr`; `arabic-egy-cleaned` overlap with `MAdel121/whisper-small-egyptian-arabic` + `null` dataset license; gated `Quran-Lab/zipformer_p-arabic-v3`; restricted `L2-KSU`; 404 HF mirror for `Arabic Little STT`).
4. **Desktop-Only Runtime Verification:** All `115/115` Flutter tests ran cleanly on Windows (`rive_native.dll` + ONNX Runtime CPU FFI); physical Android hardware profiling remains deferred to Phase 11.

---

## 2. Genuine Defects Discovered & Fixed During This Independent Audit

| # | Defect Exposed During Audit | Impact Before Fix | Verified Fix Applied |
| --- | --- | --- | --- |
| 1 | **`SmartArabicSpeechTherapy` Space missed (`MODEL_REGISTRY.json`)** | Registry checked HF org `SmartArabicSpeechTherapy` (`0` models) and wrote `UNKNOWN` license / `UNVERIFIED_EXTERNAL_NOT_PUBLICLY_RELEASED`. | Audited HF Space `MON3EMPASHA/SmartArabicSpeechTherapy/tree/main`: verified **MIT** license, `phoneme_scorer_latest.pth` (`78,004` bytes, sha256 `08c3a03a...`), 46-feature MLP + ASR aligner dependency, AND `dataset_info/ASMDD.csv` (`5,298` rows; `4,235/1,059` split) -> flagged **`DIRECT_OVERLAP`** on `asmdd`. |
| 2 | **`blind_protection.py` skipped unknown `speaker_id` & empty splits** | Unknown/empty `speaker_id` values were ignored and still produced `speaker_disjoint_verified = True`; empty Stage B sets and arbitrary dummy dicts for model/code hashes were accepted. | Rejects empty Stage B splits (`EMPTY_BLIND_DATASET`), rejects ANY speech record with empty/unknown `speaker_id` (`UNKNOWN_SPEAKER_IDENTITY_REJECTED`), and cryptographically hashes real disk `.onnx` weights, `AI_MODELS_MANIFEST.json`, `Stage B` WAV bytes, and `lib/core/ai/*.dart` files. |
| 3 | **`leakage_engine.py` failed silence-padding & trimmed clips + had 33 intra-100 FPs at 0.80** | Adding trailing silence caused `dur_ratio < 0.35` (`1/6` detected); `50%` trimmed tail gave `1/6`; broadband `250-8kHz` inflated short unrelated clip matches (`33` intra-100 FPs at `0.80`). | Replaced with active-speech core trimming, `250-3800Hz` physical-hop sliding trajectory + RMS envelope correlation (`0.82` threshold), plus `missing_speaker_records` tracking. Reduced unrelated human intra-100 matches to `2/4,465` (`0.045%`) while catching `6/6` padded/gain/8kHz copies. |
| 4 | **`anti_cheating_suite.py` used hardcoded phoneme stubs in T04–T06** | `T04`–`T06` verified evaluator math on preset lists rather than real blind acoustic inference. | Upgraded `T01`–`T06` and `T14` to run real `Silero VAD` + real `Wav2Vec2-eSpeak Q4F16` ONNX inference on `silence.wav`, `white_noise.wav`, `word_madrasa.wav`, `error_tora.wav`, `correct_kora.wav`, and `220ms` cut `human_arabic_adult.wav`. |
| 5 | **`run_phase0_audit.py` omitted non-speech fields during scan** | Silence (`S081..S085`) and MUSAN noise (`S086..S090`) lacked `audio_type` in the scan payload, triggering false `missing_speaker` flags. | Forwarded `category`, `audio_type`, and `actual_speech_present`; non-speech fixtures are properly excluded while only `18` speaker-less `MIX_*` controlled clips are flagged. |

---

## 3. Hugging Face Space Investigation (`MON3EMPASHA/SmartArabicSpeechTherapy`)
- **Repo Type:** Public Docker Space (`sha: ef84267fb4da55145b4548d570b3e0d5d463fd38`, `license: mit`, `private: false`, `gated: false`).
- **Artifacts Verified via LFS Resolution:**
  - `models/phoneme_scorer_latest.pth`: `78,004` bytes (`sha256: 08c3a03a56442944bebf560824ea98edc68f90b47a590cdeaec2a7708727e438`) — PyTorch 3-layer MLP (`128 -> 64 -> 32 -> 1 Sigmoid`).
  - `models/model_metadata_latest.json`: `46` features (`duration*`, `confidence*`, `mfcc_0..12_{mean,std}`, `mfcc_delta`, energy/spectral stats); `training_samples: 4235`, `test_samples: 1059`, `dataset: "arabic-speech-wavs"`.
  - `dataset_info/ASMDD.csv`: `5,298` rows mapping Speaker ID, Gender, Word ID, Pronunciation (`Right`/`Wrong`), and `ASMDD/...wav`.
  - **Architectural Limitation:** Depends on heavy server ASR (`FastConformer` / `Whisper-large-v3` / `XLSR-53`) + target-prompt `character_aligner.py` (`requires_target_word_hint: true`). Cannot run blind without prompt words and is contaminated for clean ASMDD benchmarks.
