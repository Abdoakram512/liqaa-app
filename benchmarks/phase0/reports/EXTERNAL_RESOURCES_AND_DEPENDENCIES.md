# External Resources, Libraries, Typography & Voice Assets — Phase 0.2

**Branch:** `feature/yasser-world-journey`  
**Audit Date:** `2026-11-27`  

This document records all external open-source packages, bundled offline fonts, character runtime tooling, and ElevenLabs voice casting metadata evaluated and used for Phase 0.2. Zero unapproved paid dependencies or cloud TTS runtime calls were added.

---

## 1. Typography Evaluation & Bundled Offline Fonts

Evaluated three open-source Arabic typefaces against Flutter RTL rendering, child readability, diacritic clarity (`فَتحة / ضَمّة / كَسرة / شدّة`), and offline reliability:

| Font Family | Source & License | Decision | Reason & Role |
| --- | --- | --- | --- |
| **`Baloo Bhaijaan 2`** | Google Fonts (`google/fonts/ofl/baloobhaijaan2`, **OFL-1.1**) — bundled at `assets/fonts/BalooBhaijaan2.ttf` (`OFL.txt` preserved at `assets/fonts/BalooBhaijaan2-OFL.txt`) | **SELECTED (Primary Display & Headings)** | Warm rounded Arabic terminals harmonize with Yasser's playful aesthetic while keeping dots/tooth letters (`ب / ت / ث / ن / ي`) clearly spaced for young learners. |
| **`Tajawal`** | Google Fonts (`google/fonts/ofl/tajawal`, **OFL-1.1**) — bundled `Regular` (`400`), `Medium` (`500`), `Bold` (`700`) at `assets/fonts/` (`Tajawal-OFL.txt` preserved) | **SELECTED (Primary Body, Labels & Specialist UI)** | High legibility in Arabic RTL sentences, clean tabular numerals, and calm editorial rhythm for parent/specialist metadata without visual noise. |
| **`Cairo`** *(previous default via runtime `GoogleFonts.cairo`)* | SIL OFL-1.1 | Replaced as primary online dependency; retained only as fallback name | Offline/headless tests failed when `GoogleFonts.config.allowRuntimeFetching = false` tried to load unbundled `Cairo-Regular.ttf`. Bundling `Baloo Bhaijaan 2` + `Tajawal` locally removes runtime network risk completely. |

---

## 2. Flutter / Dart Dependencies (Verified in `pubspec.yaml`)

No bloated third-party UI kits or redundant game engines were added; all Phase 0.2 rendering uses Flutter's native Canvas (`CustomPainter`, `CustomClipper`, `Path`, `RepaintBoundary`) alongside the existing audited package stack:

| Package | Version in `pubspec.yaml` | License | Purpose & Phase 0.2 Usage |
| --- | --- | --- | --- |
| `flutter_bloc` | `^9.1.0` | MIT | State management (`ChildWorldCubit`, `PronunciationGameCubit`, `SpecialistCubit`, `AuthCubit`, `OnboardingCubit`) |
| `go_router` | `^14.8.1` | BSD-3-Clause | Declarative routing (`/home`, `/profile-setup`, `/adventure/:regionId`, `/activity/:gameType`, `/game`, `/specialist`) |
| `rive` | `0.14.11` | MIT | Live 2.5D skeletal Yasser character runtime (`assets/rive/yasser.riv`) |
| `flutter_animate` | `^4.5.2` | MIT | Declarative UI entrance & microinteraction choreography paired with reduced-motion guards |
| `audioplayers` | `^6.7.1` | MIT | Audio playback under `YasserAudioCoordinator` (`AndroidAudioFocus.none` SFX + prompt mutual exclusion) |
| `record` | `^6.2.1` | Apache-2.0 | Hardware PCM16 audio capture with Phase 0.1 serialized recovery |
| `sherpa_onnx` | `^2.0.3` | Apache-2.0 | On-device Silero VAD, GTCRN, Wav2Vec2-eSpeak & Whisper Tiny diagnostics |
| `confetti` | `^0.8.0` | MIT | Celebration particles on session/adventure milestones (suppressed when reduced-motion is enabled) |
| `shared_preferences` | `^2.5.2` | BSD-3-Clause | Offline per-profile world, collectible, flower garden & specialist assignment persistence |
| `easy_localization` | `^3.0.7` | MIT | Arabic/English locale management (`assets/translations/`) |
| `flutter_screenutil` | `^5.9.3` | MIT | Responsive scaling across compact phones (`360dp`), standard phones (`390dp`), and tablets (`834dp`) |

---

## 3. ElevenLabs MCP Voice Casting Resources (Read-Only Evaluation)

Accessed via authenticated **ElevenLabs Hosted MCP (`https://api.elevenlabs.io/v1/mcp`)** (`creative_list_voices` & `creative_generate_speech` with `estimate_only: true`):

- **Zero Credits Spent (`0.0`):** Only read-only voice discovery and cost estimation were run.
- **Selected Egyptian Arabic Shortlist (`language: "ar"`, `accent: "egyptian"`):**
  - `PmRaqkJ2uk3Y9jrp9UjJ` — *Mawardy - Warm, Natural Egyptian* (Recommended primary voice)
  - `Y65Dz2XsznJl6gZHkXPi` — *Sattar - Warm Egyptian explainer*
  - `IES4nrmZdUBHByLBde0P` — *Haytham - Conversation*
  - `QvNF0qyyt1Tuy1YAmnzH` — *Mostafa - Bold and Spirited*
  - `5REPlS2Ja1VZ7zNA0ykn` — *Ziad - Dynamic and Vibrant*
  - `4mZ0H4Jh5iqmgAWK97eF` — *Omarii - Confident Customer Care Agent*
- **Observed Cost Estimate:** Flow `g2xvPxRggxl4rN1t0ltc` -> `59.0` credits (`$0.0118` USD) per ~59-character clip on `eleven_multilingual_v2`. Bulk generation awaits explicit user sign-off.
