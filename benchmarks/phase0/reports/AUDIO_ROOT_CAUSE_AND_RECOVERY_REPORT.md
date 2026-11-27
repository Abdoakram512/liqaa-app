# Audio Root Cause & Recovery Report — Phase 0.1 (Workstream A)

**Working Branch:** `feature/phase0-ai-governance`  
**Scope:** Picture Naming Game (`PronunciationGameCubit`), `AudioRecorderService`, `YasserAudioCoordinator`, `PronunciationRepository`, `PronunciationEvaluator`, and `AiLabCubit` lifecycle hardening.

---

## 1. Exact Root Causes of User-Reported Failures (`P0-A`)

Before Phase 0.1, the Picture Naming Game (كورة / بطة / قطة) intermittently captured Attempt 1 and repeatedly failed subsequent attempts (`"لم نلتقط صوتاً واضحاً"` / silent hang / wedge):

| Layer | Observed Root Cause Before Fix | Failure Symptom |
| --- | --- | --- |
| **`AudioRecorderService` (`lib/core/ai/audio_recorder_service.dart`)** | 1. Shared unserialized `AudioRecorder` instance without an async mutex (`start` / `stop` / `cancel` could overlap).<br>2. Fixed temp WAV overwrite risk and no native `isRecording()` reconciliation when an interrupted session left Android `MediaRecorder` / `AudioRecord` wedged.<br>3. Unthrottled amplitude polling timer overlapped async platform channel calls.<br>4. Zero automatic disposal/recreation of `AudioRecorder` on native failure (`stop()` returning `null`, empty/corrupt `<44`-byte WAV, or state wedge). | Attempt 2+ inherited wedged native recorder state, returned empty/4-byte WAV buffers, or overwrote/raced file handles. |
| **`YasserAudioCoordinator` (`lib/core/audio/yasser_audio_coordinator.dart`)** | `SFX` `AudioPlayer` and voice prompt playback did not enforce `AndroidAudioFocus.none` on UI chimes or wait/hook-stop external prompt players before opening Android `AudioRecord`. | Android audio focus / speaker output collided with mic capture start or contaminated early speech frames. |
| **`PronunciationGameCubit` (`lib/features/pronunciation_game/cubits/pronunciation_game_cubit.dart`)** | 1. No `WidgetsBindingObserver` cleanup on app backgrounding (`paused`/`inactive`/`detached`), leaving native mic open.<br>2. No sequence guard (`_evalSeq`) against stale async evaluations completing after card navigation/cancel.<br>3. Technical/inconclusive failures (silent mic, weak RMS, empty buffer) incremented clinical `attemptsCount` and persisted failed attempts via `_progressService` / `onAttemptEvaluated`. | Switching tabs/apps or re-trying after silent/failed captures wedged state and penalized the child's score. |
| **`PronunciationRepository` (`lib/core/ai/pronunciation_repository.dart`)** | Digital silence (`rawPeak < 0.002`) vs weak mic signal (`speechRms < 0.0015`) vs VAD non-detection were insufficiently surfaced in diagnostics. | Users saw generic `"لم نلتقط صوتاً"` without knowing whether the mic captured zero signal, noise, or quiet speech. |
| **`AiLabCubit` (`lib/features/ai_lab/cubits/ai_lab_cubit.dart`)** | Closing AI Lab could leave an owned recording active without owner-scoped cancellation. | Leaving AI Lab and entering the game could leave the shared recorder busy. |

---

## 2. Implemented Engineering Fixes

1. **Serialized State Machine & Fault Recovery (`lib/core/ai/audio_recorder_service.dart`):**
   - Extracted injectable `RecorderBackend` interface + `AudioRecorderService` FIFO operation serialization (`_runSerialized`).
   - Added monotonic `activeAttemptId` and unique per-attempt temp file paths (`yasser_rec_<attemptId>_<ts>.wav`) cleaned up on error/cancel.
   - Added native state verification (`isRecording()`), native-wedge detection, automatic backend recreation (`dispose()` -> new `AudioRecorder` via `backendFactory`) on start/stop errors or corrupt `<= 44`-byte WAV outputs, and re-entrant async amplitude poll guard (`_amplitudePollInFlight`).
   - Added structured `AudioRecordingException` with `AudioRecordingErrorKind` (`permissionDenied`, `micBusy`, `corruptOrEmptyWav`, etc.).
   - Preserved zero-arg `startRecording()` / `stopRecording()` / `cancelRecording()` compatibility alongside owner-scoped `startOwnedRecording(owner)` / `stopOwnedRecording(owner)` / `cancelOwnedRecording(owner)` + `resetRecorder()`.
2. **Audio Focus & Playback Exclusion (`lib/core/audio/yasser_audio_coordinator.dart`):**
   - Configured `_sfxPlayer` with `AndroidAudioFocus.none` (`AndroidContentType.sonification`) so UI feedback chimes never steal Android `AudioFocus` from `AudioRecord`.
   - Configured `_voicePlayer` with `AndroidAudioFocus.gainTransientMayDuck` and explicit `enterRecordingSession()` / `exitRecordingSession()` + external stop hooks.
   - Guarded nullable players cleanly when `enablePlatformAudio == false` in headless tests.
3. **Game Lifecycle, Progress Protection & Error Attribution (`lib/features/pronunciation_game/cubits/pronunciation_game_cubit.dart` & `lib/core/ai/models/pronunciation_assessment.dart`):**
   - Registered `WidgetsBindingObserver` + external prompt-stop hook on `YasserAudioCoordinator` and `_evalSeq` stale-completion guards.
   - Added `AssessmentErrorType.isInconclusiveOrTechnical` so empty buffers, digital silence (`rawPeak < 0.002`), weak RMS (`speechRms < 0.0015`), and system failures NEVER increment `attemptsCount` or persist failed child progress.
   - Added `AiLabCubit.close()` cleanup calling `cancelOwnedRecording('ai_lab')`.

---

## 3. Repeatability & Verification Results

| Check | Scope / Execution | Result | Verdict |
| --- | --- | --- | --- |
| **50x Consecutive Silero VAD Repeatability** (`test/core/ai/vad_repeatability_and_stt_diag_test.dart`) | Real `silero_vad.onnx` across `human_arabic_adult.wav`, `silence.wav`, `white_noise.wav`, `noisy_speech.wav`, `word_madrasa.wav` (50 iterations) | `freshRef=[true, false, false, false, true]`, **`mismatches=0`**, `0` errors | **PASS (Desktop ONNX)** |
| **105-Cycle Serialized Lifecycle & Fault Injection** (`test/core/ai/recorder_lifecycle_and_routing_test.dart`) | 105 sequential capture cycles injecting native start failure, stop failure, 4-byte corrupt WAV, cross-owner cancel isolation, `micBusy` rejection, permission denial/re-grant | Unique paths/IDs across all valid cycles, `recoveryCount > 10`, zero wedges | **PASS (Injected Fault Harness)** |
| **Game Multi-Attempt Recovery & Progress Isolation** (`recorder_lifecycle_and_routing_test.dart`) | Attempt 1 native start failure -> Attempt 2 VAD silence (`supportiveHint`, `attemptsCount=0`, `persistedProgressCount=0`) -> Attempt 3 speech -> Attempt 4 card switch (`كورة`/`بطة`/`سمكة`) | All 4 sequential state transitions & progress counters exact (`attemptsCount=2`, `persistedProgressCount=2`) | **PASS (Widget/Unit Harness)** |
| **Prompt Playback Mutual Exclusion** (`test/features/pronunciation_game/yasser_prompt_playback_test.dart`) | Existing prompt playback + mic mutual exclusion widget/cubit tests | All passed inside full `120/120` Flutter suite | **PASS** |
| **Physical Android Continuous Mic Capture (`AudioRecord`)** | Live child/adult repeated speaking ("كورة" / "بطة" / "قطة") on `vivo V2529` (`10JFAT04A50006C`, Android `16`) | See `PHASE_1_READINESS_REPORT.md` for device APK & live speaking verification status | **See Readiness Report** |
