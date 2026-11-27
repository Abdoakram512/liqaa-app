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

## 3. ElevenLabs Voice Casting Audit (Read-Only, `0` Credits Spent)

All voice casting discovery and cost estimation used authenticated **ElevenLabs Hosted MCP (`https://api.elevenlabs.io/v1/mcp`)** tools (`creative_list_voices` and `creative_generate_speech` with `estimate_only: true`).

### Egyptian Arabic Shortlist (`assets/pronunciation/yasser_voice_manifest.json`)

| Rank | Voice ID | Voice Name | Dialect / Profile | Suitability Notes |
| --- | --- | --- | --- | --- |
| **1 (Recommended)** | `PmRaqkJ2uk3Y9jrp9UjJ` | **Mawardy - Warm, Natural Egyptian** | `egyptian` / `young` / `male` | Warm conversational Egyptian Masri with clear child-friendly diction; best fit for Yasser. |
| **2** | `Y65Dz2XsznJl6gZHkXPi` | **Sattar - Warm Egyptian explainer** | `egyptian` / `young` / `male` | Friendly older-brother explainer delivery suited to instructions and game hints. |
| **3** | `IES4nrmZdUBHByLBde0P` | **Haytham - Conversation** | `egyptian` / `middle_aged` / `male` | Crisp Egyptian storytelling cadence; optional fit for `مدينة الحكايات` narration. |
| **4** | `QvNF0qyyt1Tuy1YAmnzH` | **Mostafa - Bold and Spirited** | `egyptian` / `young` / `male` | Bright celebratory energy for achievement fanfare lines. |
| **5** | `5REPlS2Ja1VZ7zNA0ykn` | **Ziad - Dynamic and Vibrant** | `egyptian` / `young` / `male` | Dynamic pacing for game intros. |
| **6** | `4mZ0H4Jh5iqmgAWK97eF` | **Omarii - Confident Customer Care Agent** | `egyptian` / `young` / `male` | Clear formal-supportive Egyptian cadence. |

---

## 4. Script Library & Exact Cost Estimate (Awaiting User Approval)

- **Generated Script Library:** `assets/pronunciation/yasser_voice_script_library.json`
  - **Total Scripts:** `150` child-friendly Egyptian Arabic lines (greetings, 6 region intros, 8 mini-game instructions, encouragement, gentle retry hints, adventure milestones, and reviewed word prompts).
  - **Total Characters:** `6,574` characters.
- **Verified Cost Estimate (`estimate_only: true`, Flow `g2xvPxRggxl4rN1t0ltc` on `eleven_multilingual_v2`):**
  - Sample prompt length: `59` characters
  - Estimated cost per `59`-char sample: **`59.0` credits** (`1.18` cents / **`$0.0118` USD**)
  - Projected total for full `150`-script batch (`6,574` chars): **~`6,574`–`7,800` credits** (provisional linear estimate around ~$1.30–$1.56 USD depending on batch rounding)
- **Credits Spent So Far:** **`0.0` credits** (`status: preview_shortlist_ready_zero_credits_spent`).

### Next Step Requiring Explicit User Approval
Before generating paid WAV files with ElevenLabs:
1. Confirm your preferred voice from the Egyptian Arabic shortlist (`PmRaqkJ2uk3Y9jrp9UjJ` *Mawardy* recommended, or specify another candidate ID).
2. Approve whether to synthesize an initial pilot batch (e.g., 15–30 core greetings & game instructions) or the full `150`-script batch (`~6,574` chars).
