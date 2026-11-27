# CHARACTER JOURNEY AND VOICE REPORT — PHASE 0.2

**Branch:** `feature/yasser-world-journey`  
**Character:** Yasser (`ياسر`) — Egyptian Arabic Child Companion  
**Report Date:** `2026-11-27`

---

## 1. Visual Identity & Animation Continuity

- **Character Preservation:** Yasser's original appearance, warm orange hoodie, proportions, backpack, and `assets/rive/yasser.riv` rig remain intact across all new world destinations, onboarding mini-demo (`lib/features/onboarding/presentation/widgets/onboarding_page_item.dart`), Personal Home, Adventure Detail, and all 8 mini-games.
- **Coordinated Companion Behavior (`lib/core/animation/yasser/yasser_companion_controller.dart`):**
  - Registered in `lib/app/dependency_injection/service_locator.dart`.
  - Unifies `YasserRiveController`, `YasserAudioCoordinator`, viseme driving, non-overlapping reactions (`waving`, `happy`, `curious`, `talking`, `celebrating`, `gentleRetry`), and interactive speech bubbles without competing animation timers.
  - Respects `YasserCharacter.enableRiveRuntime` and `MediaQuery.disableAnimations` (`YasserMotion.isReducedMotion`).

---

## 2. Audio Coordination & Strict Microphone Protection

- Extended `lib/core/audio/yasser_audio_coordinator.dart` with `playLineOrFallback(...)`:
  - Plays bundled local WAV assets when verified, or falls back gracefully to silent/timed viseme progression paired with Yasser's visual speech bubble when a scripted prompt WAV is not yet generated.
  - **Strict Runtime Cloud TTS Prohibition:** The Flutter runtime **never** calls ElevenLabs APIs at runtime. Zero runtime network keys, zero runtime TTS charges, and offline-first execution.
  - **Recording Mutual Exclusion Preserved:** `_isRecordingActive` strictly halts voice lines and viseme loops during child microphone recording (`enterRecordingSession()` / `exitRecordingSession()`), preserving 100% of Phase 0.1's `AudioRecorderService` serialization guarantees.

---

## 3. ElevenLabs Voice Synthesis, Diacritization & Offline Bundle (`150/150` Verified WAVs)

All voice casting discovery, cost estimation, and final batch generation used authenticated **ElevenLabs Hosted MCP (`https://api.elevenlabs.io/v1/mcp`)** tools (`creative_list_voices`, `account_get_usage`, `creative_generate_speech`, and `creative_get_flow_run_status`).

- **Approved Primary Voice (`status: bundled_150_verified_v4`):**
  - **Voice ID:** `QfMIySsRuJWjZPZCnDQp`
  - **Name:** `Ashraf - Warm and Genial` (Egyptian Arabic)
  - **Model:** `eleven_v4` (selected over `eleven_multilingual_v2` and `eleven_v3` after A/B user QA listening)
  - **Flow ID:** `MwnSpDXo6QYU7nbfpSRX`
- **Linguistic Cleanup & Phonetic Conditioning:**
  - Removed disjointed letter-by-letter tatweel segmentation (e.g., `كـ كـ كورة`, `أ ر ن ب`) and normalized ellipsis hesitations across all `150` scripts.
  - Corrected lexical/grammar defects (`st06`, `rp03`, `fw08`, `ev03`) and added full Egyptian Arabic diacritization (*tashkeel*) + `eleven_v4` expression tags (`[warmly]`, `[happy]`, `[excited]`, `[curious]`, `[slowly]`, `[short pause]`).
- **Workspace Quota Verified (`account_get_usage`):**
  - **Tier:** `starter` (`active`)
  - **Used (cumulative after all QA + final `eleven_v4` bundle):** `22,593` / `40,000` characters (`17,407` remaining)
  - **Exact `eleven_v4` Bundle Flow Credits (`150` scripts):** `11,782` credits (including `4` reused QA samples `g01`, `ev01`, `ev23`, `us02` totaling `332` credits).

### Egyptian Arabic Shortlist (`assets/pronunciation/yasser_voice_manifest.json`)

| Rank | Voice ID | Voice Name | Dialect / Profile | Suitability Notes |
| --- | --- | --- | --- | --- |
| **Approved Primary** | `QfMIySsRuJWjZPZCnDQp` | **Ashraf - Warm and Genial** | `egyptian` / `male` | **Approved by user:** friendly, warm, easygoing Egyptian Arabic delivery. |
| **Alternative 1** | `PmRaqkJ2uk3Y9jrp9UjJ` | **Mawardy - Warm, Natural Egyptian** | `egyptian` / `young` / `male` | Warm conversational Egyptian Masri with clear child-friendly diction. |
| **Alternative 2** | `Y65Dz2XsznJl6gZHkXPi` | **Sattar - Warm Egyptian explainer** | `egyptian` / `young` / `male` | Friendly older-brother explainer delivery suited to instructions and game hints. |
| **Alternative 3** | `IES4nrmZdUBHByLBde0P` | **Haytham - Conversation** | `egyptian` / `middle_aged` / `male` | Crisp Egyptian storytelling cadence; optional fit for `مدينة الحكايات` narration. |
| **Alternative 4** | `QvNF0qyyt1Tuy1YAmnzH` | **Mostafa - Bold and Spirited** | `egyptian` / `young` / `male` | Bright celebratory energy for achievement fanfare lines. |
| **Alternative 5** | `5REPlS2Ja1VZ7zNA0ykn` | **Ziad - Dynamic and Vibrant** | `egyptian` / `young` / `male` | Dynamic pacing for game intros. |
| **Alternative 6** | `4mZ0H4Jh5iqmgAWK97eF` | **Omarii - Confident Customer Care Agent** | `egyptian` / `young` / `male` | Clear formal-supportive Egyptian cadence. |

---

## 4. Bundled Script Library & Runtime Wiring Verification

- **Script Library & Manifests (`status: BATCH_150_SYNTHESIZED_AND_BUNDLED_V4`):**
  - `assets/pronunciation/yasser_voice_script_library.json` (`150` scripts across greetings, onboarding, world intros, explorations, activity instructions, 28 vocabulary explanations, encouragement, gentle retry hints, rewards, session endings, returning greetings, farewells, and stories).
  - `assets/pronunciation/yasser_voice_manifest.json`
- **Audio Normalization & Verification (`assets/pronunciation/prompts/<id>.wav`):**
  - Normalized every clip to **RIFF WAVE PCM 16-bit Mono `24,000 Hz`** (`loudnorm=I=-16:TP=-1.5:LRA=11` + tail silence trim `>= 0.08 s` below `-50 dBFS`).
  - **Total Bundled WAVs Verified (`150/150` + existing `kora.wav`, `samaka.wav`):**
    - Total duration (`g01`–`st08`): **`506,150 ms`** (~`8.44` minutes)
    - Total disk size (`g01`–`st08`): **`24,306,934` bytes** (`~23.18 MB`)
- **Runtime Playback Wiring:**
  - `lib/features/pronunciation_game/models/yasser_prompt.dart`: preserves studio word cues (`word_kora`, `word_samaka`), embeds exact verified durations for all `150` scripts (`bundledScriptDurationsMs`), maps vocabulary IDs (`word_*`) to `ev01`–`ev28`, and provides `YasserPrompt.resolvePrompt(...)`.
  - `lib/core/audio/yasser_audio_coordinator.dart`: `playLineOrFallback(...)` resolves all `150` scripts and vocabulary words offline from bundled WAV assets with synchronized viseme playback, strict `_isRecordingActive` microphone exclusion, and `0` runtime cloud TTS calls.
  - Automated RIFF WAVE & resolver verification test added in `test/phase0_2/world_persistence_and_profiles_test.dart` (`150/150` verified passing).
