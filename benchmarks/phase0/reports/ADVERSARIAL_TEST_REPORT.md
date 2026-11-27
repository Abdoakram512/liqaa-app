# Independent Adversarial Test Report

Test Suites Executed:
- [test_adversarial_audit.py](file:///E:/Flutter%20Projects/liqaa_app/benchmarks/phase0/tests/test_adversarial_audit.py)
- [test_phase0_governance.py](file:///E:/Flutter%20Projects/liqaa_app/benchmarks/phase0/tests/test_phase0_governance.py)
- [anti_cheating_suite.py](file:///E:/Flutter%20Projects/liqaa_app/benchmarks/phase0/anti_cheating_suite.py)

Note: Synthetic audio perturbations and isolated disk mocks test **pipeline/governance enforcement mechanics only** and are strictly separated from clinical pronunciation accuracy claims.

## 1. Empirical Leakage Detection vs False-Positive Rate (Real Clips)

Tested on real child & adult speech recordings (`benchmarks/audio/clips/S*.wav` and `assets/audio_samples/`):

| Adversarial Perturbation / Attack Vector | Baseline Pre-Fix Hits | Post-Fix Hits (`thr = 0.82`) | Observed Outcome |
| --- | --- | --- | --- |
| Exact file duplicate / renamed copy | `6/6` | **`6/6` (100%)** | Caught by `raw_file_sha256` + `canonical_pcm_sha256` |
| `8 kHz` resampled + 8-bit PCM re-encoded | `6/6` (`0.97-0.99`) | **`6/6` (100%)** | Caught by `250-3800Hz` speech-band fingerprint |
| Gain attenuated (`0.35x`) | `6/6` (`0.99+`) | **`6/6` (100%)** | Caught (`sim = 1.000`) |
| Leading & trailing silence padded (`+1.5s/+2.0s`) | `1/6` (**83% FN bug**) | **`6/6` (100%)** | Fixed via `active_duration_ms` core extraction (`sim = 1.000`) |
| Tail trimmed (`50%` cut) | `1/6` (**83% FN bug**) | **`4/6` (67% real clips)** & pass on `human_arabic_adult.wav` | Caught cleanly via sliding physical trajectory; short `50%` cuts leaving `<16` active frames (`<270ms`) remain a documented boundary |
| Additive noise `+10 dB SNR` | `0/6` (**100% FN bug**) | **`5/6` (83%)** | Fixed; 1 clip at severe distortion relies on `parent_source_id` lineage |
| Additive noise `+5 dB SNR` | `0/6` | **`4/6` (67%)** | Extreme low-SNR boundary documented honestly |
| **False Positives on `4,465` Real Pairs (`manifest.jsonl`)** | `33 / 4,465` at `0.80` | **`2 / 4,465` (`0.045%`) at `0.82`** | Massive FP reduction (`S028/S086=0.824`, `S049/S093=0.873`) |

## 2. Adversarial Security, Identity & Drift Checks (`15` Targets + Independent Suite)
- **Exact & Renamed Duplicates:** Blocked & quarantined.
- **Speaker & Session Cross-Split Overlap:** Caught (`speaker_cross_split_leakage`, `recording_session_cross_split_leakage`).
- **Missing Speaker IDs on Speech:** Caught by `missing_speaker_records` (`18` derived `MIX_*` clips flagged) and blocked by `create_freeze_lock`.
- **Cross-Dataset Overlap:** Caught (`cross_dataset_overlaps = 17` across mixed + `ASMDD`/`ASC`/`arabic-egy-cleaned` matrix flags).
- **Modified Model Weights / Tampered Manifest / Preprocessing Code Change / Altered Stage B WAV / Post-Freeze Threshold Change:** All 5 independently tested in `test_blind_freeze_rejects_empty_and_unknown_speakers_and_tampered_artifacts` -> all raise `BlindAuthorizationError`.
- **Target-Word Leakage:** Blocked by Python `verify_blind_inference_signature` and verified absent in `lib/core/ai/phoneme_recognition_engine.dart`.
- **Random Labels Sanity Check:** Shuffled ground truth collapses balanced accuracy to **`0.49`** (chance level).
- **Missing Model Artifacts:** Missing `zipformer_v3/encoder.onnx` honestly surfaces as unavailable, while all 8 active bundled model/manifest paths match SHA-256 checksums (`0` mismatches).
