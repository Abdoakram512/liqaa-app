# Phase 1 Readiness Report — Post Phase 0.1 Hardening

**Date UTC:** `2026-11-27`  
**Branch:** `feature/phase0-ai-governance`  
**Prepared For Transition:** **Phase 0.1 -> Phase 1 (Model Acquisition & 2,000-Sample Egyptian Pediatric Dev Dataset)**

---

## 1. Readiness Verdict Breakdown

| Readiness Gate | Status | Supporting Verification |
| --- | --- | --- |
| **Codebase Stability & Static Hygiene** | **PASS** | `flutter analyze --no-pub`: **`No issues found!`** |
| **Automated Flutter & Native Desktop Runtime** | **PASS** | `flutter test --reporter compact`: **`120 / 120` PASSED** (0 skipped, 0 failed) |
| **AI Governance, Leakage Firewall (`5,000` LSH) & Blind Protocol (`D1`–`D4`)** | **PASS** | `python -m unittest discover -s benchmarks/phase0/tests -p "test_*.py" -v`: **`12 / 12` PASSED** (`15/15` anti-cheating) |
| **Storage Isolation (`C:` vs `D:\YasserML` vs `E:`)** | **PASS** | Fresh PowerShell `Get-PSDrive`: **`C:` = `31.04 GB` free** (`216.07 GB` used), **`D:` = `271.22 GB` free** (`660.27 GB` used), **`E:` = `101.01 GB` free** (`126.11 GB` used). `D:\YasserML` isolates all ML datasets/caches/blind vault. |
| **Android APK Compilation (`arm64-v8a`)** | **PASS** | `flutter build apk --debug` built `build\app\outputs\flutter-apk\app-debug.apk` in `65.0s` |
| **Physical Android Device Mic & Game Loop Verification** | **NOT VERIFIED** | Connected `vivo V2529` (`10JFAT04A50006C`, Android `16`, `arm64-v8a`) blocked streamed ADB install (`adb install` failed / Vivo security setting `Shell does not have permission to access user 10`). Repeated physical `AudioRecord` captures (`كورة` / `بطة` / `قطة`) could not run live on the device from automation. |
| **Stage B Blind Holdout (`stage_b_frozen`)** | **LOCKED (`false`)** | Intentionally empty until Phase 1 (`Stage A` `2,000`) -> Phase 2 (`13` candidates) -> Phase 3 (freeze) -> Phase 4 (`Stage B` `1,500` clean human blind test). |

**Overall Phase 1 Entry Recommendation:** **CONDITIONAL PASS (Approved for Offline Phase 1 Data Curation & Model Acquisition; Physical Android Verification Required Before Clinical Pilot)**

---

## 2. Mandatory Manual Android Verification Checklist (For `vivo V2529` / Physical Phone)

Because automated `adb install` was denied by Vivo USB security policies and real child/adult voice speaking cannot be synthesized inside an isolated USB test shell without human mic input, execute these 5 checks directly on the phone before declaring physical Android audio `PASS`:

1. **Enable USB Installation & Grant Clean Install:**
   - On `vivo V2529`: enable **Developer Options -> Install via USB** (or uninstall any previous signature-mismatched `com.example.liqaa_app` manually from phone Settings, then run `flutter install --debug -d 10JFAT04A50006C` or `flutter run -d 10JFAT04A50006C`).
2. **Picture Naming Game (`كورة` / `بطة` / `قطة`) Repeated 10x Capture Test:**
   - Tap mic, say `"كورة"`, get evaluation; immediately tap mic again cleanly across 10 consecutive attempts and across card switches (`كورة` -> `بطة` -> `قطة`).
   - Confirm zero persistent `"لم نلتقط صوتاً واضحاً"` wedges, confirm Yasser voice prompt stops immediately upon tapping Record, and confirm silent taps show diagnostic silence guidance without incrementing score attempts.
3. **Interruption Recovery Test:**
   - Press Home/switch apps mid-recording -> return to game -> tap Record again and verify mic re-acquires cleanly without app restart.
4. **AI Lab Task Isolation & Latency Check:**
   - Run *Mic + VAD* only, *Free Phoneme Recognition*, and *Whisper STT* modes separately -> verify card/mode telemetry shows single invocations (zero 3x redundant calls) and smooth UI animation (background `AiInferenceWorker` isolate active).
5. **Whisper STT Expectation Check:**
   - Confirm *Speech-to-Text* stays strictly inside AI Lab diagnostics (`SpeechToTextEngine` `max_tokens_per_second=24`), while Picture Naming Game scoring remains exclusively driven by `Silero VAD` + `Wav2Vec2-eSpeak` + `PronunciationEvaluator`.

---

## 3. Conditions Entering Phase 1

1. Store all `Stage A` (`~2,000` sample target) datasets, raw archives, HuggingFace caches, and training checkpoints strictly under **`D:\YasserML\`** (never `C:` or `E:` Git repository).
2. Quarantine and exclude contaminated model/dataset pairs already logged in `MODEL_DATASET_CONTAMINATION_MATRIX.csv` (e.g., evaluate `MostafaMaroof/wav2vec2-arabic-phoneme-asr` outside `arabic_speech_corpus`, `MAdel121/whisper-small-egyptian-arabic` outside `arabic-egy-cleaned`, and `SmartArabicSpeechTherapy` outside `asmdd`).
3. Do NOT unlock, inspect, or run **Stage B (`1,500` blind)** during Phase 1 or Phase 2 — Stage B execution begins only in **Phase 4** via `verify_and_prepare_blind_scoring` + `BlindFreezeLock`.
