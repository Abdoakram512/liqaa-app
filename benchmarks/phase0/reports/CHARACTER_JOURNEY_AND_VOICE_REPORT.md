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

## 3. ElevenLabs Voice Casting & Approved Selection (`0` Generation Credits Spent Yet)

All voice casting discovery and cost estimation used authenticated **ElevenLabs Hosted MCP (`https://api.elevenlabs.io/v1/mcp`)** tools (`creative_list_voices`, `account_get_usage`, and `creative_generate_speech` with `estimate_only: true`).

- **Approved Primary Voice (`status: voice_approved_by_user_awaiting_batch_scope`):**
  - **Voice ID:** `QfMIySsRuJWjZPZCnDQp`
  - **Name:** `Ashraf - Warm and Genial` (Egyptian Arabic)
- **Workspace Quota Verified (`account_get_usage`):**
  - **Tier:** `starter` (`active`)
  - **Used:** `4,164` / `40,000` characters (`35,836` remaining)

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

## 4. Script Library & Exact Cost Estimate (Awaiting Batch Scope Approval)

- **Generated Script Library:** `assets/pronunciation/yasser_voice_script_library.json`
  - **Total Scripts:** `150` child-friendly Egyptian Arabic lines (greetings, 6 region intros, 8 mini-game instructions, encouragement, gentle retry hints, adventure milestones, and reviewed word prompts).
  - **Total Characters:** `6,574` characters.
- **Verified Cost Estimate for Approved Voice `QfMIySsRuJWjZPZCnDQp` (`estimate_only: true`, Flow `MwnSpDXo6QYU7nbfpSRX` on `eleven_multilingual_v2`):**
  - Sample prompt length: `64` characters
  - Estimated cost per `64`-char sample (`generations_count: 1`): **`64.0` credits** (`1.28` cents / **`$0.0128` USD**, `1.0` credit/char)
  - Projected total for pilot batch (15–20 core greetings/game prompts): **~`900` credits** (`~2.5%` of remaining `35,836` credits)
  - Projected total for full `150`-script batch (`6,574` chars): **`~6,574` credits** (`~18.3%` of remaining `35,836` credits)
- **Speech Credits Spent So Far:** **`0.0` credits** on `QfMIySsRuJWjZPZCnDQp` (`estimate_only: true`).

### Next Step Requiring Batch Scope Confirmation
Voice `QfMIySsRuJWjZPZCnDQp` (*Ashraf - Warm and Genial*) is now locked in `yasser_voice_manifest.json`. Confirm whether to run:
1. A **pilot batch** (e.g., 15–20 core greetings & game instructions, ~`900` credits), OR
2. The **full `150`-script batch** (`6,574` characters ≈ `6,574` credits out of `35,836` remaining).
