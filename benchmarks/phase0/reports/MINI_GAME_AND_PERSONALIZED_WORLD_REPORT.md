# MINI-GAME AND PERSONALIZED WORLD REPORT — PHASE 0.2

**Branch:** `feature/yasser-world-journey`  
**Report Date:** `2026-11-27`

---

## 1. Six Connected World Destinations

Defined in `lib/features/world/data/models/world_models.dart` (`WorldRegionId`) and populated in `lib/features/world/data/world_catalog.dart` (`WorldCatalog`):
1. **`بيت ياسر` (`yasser_home`)** — Personal garden & cottage space where rewards bloom visually and children customize flowers, avatar, theme, and decorations.
2. **`حديقة الأصوات` (`sound_garden`)** — 5-step opening adventure pairing exploration, auditory discrimination, listening choice, repetition, and independent picture naming; rewards `flower_sun_garden`.
3. **`غابة الحيوانات` (`animal_forest`)** — 3-step animal sound adventure featuring *Sound Detective* (`محقق الأصوات`).
4. **`جزيرة الكلمات` (`word_island`)** — Crossing the wooden bridge with *Mystery Sound Boxes* (`صناديق الأصوات السرية`).
5. **`مدينة الحكايات` (`story_city`)** — Interactive narrative chapter starring *Complete the Story* (`أكمل الحكاية`).
6. **`قلعة الأبطال` (`hero_castle`)** — Encouraging courage challenges celebrating effort safely without punitive scoring.

All 6 regions are openly browsable and playable (no frustrating paywall or harsh gating), accessible both on the custom-painted `WorldMapView` canvas AND via its one-tap **Accessible List Toggle (`قائمة` / `خريطة`)**.

---

## 2. Navigation Shell, Personal World & Multi-Profile Privacy

- **`ChildWorldShellView` (`lib/features/world/presentation/views/child_world_shell_view.dart`) + `yasser_world_nav_bar.dart`:** Replaces isolated exercise screens inside `ChildHomeView` with a unified 4-tab child experience:
  1. `عالمي` (`MyPersonalHomeView`) — interactive cottage/garden (`PersonalHomePainter`), tap-reactive Yasser + flowers + companion animals, treasure chest modal, garden/home decoration customization sheet, contextual daily greeting (`WorldContentAdapter.buildDailyGreeting`), specialist suggestion card, and shortcuts to AI/Yasser lab routes preserved at the bottom.
  2. `مغامرتي` (`WorldMapView`) — interactive illustrated map (`WorldMapPainter`) + accessible list toggle + route to `AdventureDetailView`.
  3. `ألعابي` (`MiniGamesHubView`) — launches all 8 mini-games cleanly, honoring active specialist target phonemes when assigned.
  4. `كنوزي` (`AdventureBookView`) — 4-chapter scrapbook (`كلماتي`, `الزهور والحيوانات`, `ملصقات وأوسمة`, `رحلتي`) displaying authentic Arabic word cards (`كورة`, `سمكة`, `بطة`, ...), collectibles, and milestone progress without exposing clinical diagnostics to the child.
- **Privacy-Conscious Personalization (`ProfileSetupView`, `ChildWorldRepository`, `ChildWorldCubit`):**
  - Stores **only** optional display nicknames, avatar IDs, theme IDs, favorite companion animal, and curated interests in `SharedPreferences` (zero photos, zero real full names required, zero PII).
  - Strictly isolates gardens, planted flowers, home decorations, discovered words, and outcomes per `ChildProfile.id` across app reloads (verified by `test/phase0_2/world_persistence_and_profiles_test.dart`).

---

## 3. All 8 Mini-Games & Zero-AI Execution Separation

Every activity shares `ActivitySessionScaffold` (`lib/features/activities/presentation/widgets/activity_session_scaffold.dart`) with cached reviewed vocabulary loading (`egyptian_arabic_dictionary.json`), round progress indicator, Yasser companion prompt, gentle non-punitive celebration (`ConfettiCelebrationOverlay`), and persistent reward auto-planting (`flower_*` auto-planted in garden on reward unlock).

| # | Game Key (`MiniGameType`) | Arabic Title | Interaction Style | Microphone / AI Inference? |
| --- | --- | --- | --- | --- |
| 1 | `discoverWord` | اكتشف الكلمة | Tap card to inspect word, letters, illustration & listen | **ZERO AI** |
| 2 | `hearDifference` | اسمع الفرق | Minimal pairs discrimination (`متشابهتان` / `مختلفتان`, non-color-only) | **ZERO AI** |
| 3 | `listenAndChoose` | اسمع واختار | Randomized 4-picture auditory selection | **ZERO AI** |
| 4 | `repeatAfterYasser` | ردّد وراء ياسر | Hear Yasser first -> safe ONNX recording + feedback | **Uses Phase 0.1 ONNX Pipeline** |
| 5 | `nameThePicture` | سمّي الصورة | Independent picture naming (`PronunciationGameView`) | **Uses Phase 0.1 ONNX Pipeline** |
| 6 | `mysterySoundBoxes` | صناديق الأصوات السرية | Tap or drag-and-drop matching onto `TreasureLidClipper` boxes | **ZERO AI** |
| 7 | `soundDetective` | محقق الأصوات | Find target-phoneme illustrations (tap or drag to basket) | **ZERO AI** |
| 8 | `completeTheStory` | أكمل الحكاية | Narrative fill-in-the-blank with optional speaking practice link | **ZERO AI** (story play) |

Verified by `test/phase0_2/mini_games_and_zero_ai_test.dart`: Games 1, 2, 3, 6, 7, and 8 render and run cleanly even when `PronunciationRepository` is **not registered** in `GetIt` (`sl`), guaranteeing zero accidental Silero VAD, GTCRN, Wav2Vec2, or Whisper execution during non-speaking play.

---

## 4. Strict Metric Separation & Specialist Workspace Integration

- **`ActivityOutcomeRecord` (`world_models.dart`)** tracks engagement/listening (`listeningCorrect`, `listeningTotal`), auditory discrimination (`discriminationCorrect`, `discriminationTotal`), genuine pronunciation outcomes (`pronunciationPassed`), and inconclusive technical attempts (`inconclusiveTechnicalCount`) as separate counters — completion badges never inflate pronunciation metrics.
- **Specialist Case Detail (`lib/features/specialist/presentation/views/case_detail_view.dart`):**
  - **`_DetailedOutcomeSummaryCard` (`ملخص الأداء المفصّل`)** explicitly splits total sessions, successful scored attempts, needs-practice attempts, and inconclusive technical attempts (`scoreIndicator == null`).
  - **`_SpecialistAssignmentsCard` (`تخصيص مسار المغامرة (الأخصائي)`)** lets specialists assign target region, phonemes, and difficulty level via `SpecialistCubit.assignPersonalizedAdventure(...)` (and delete via `removeAssignment(...)`) while persisting locally in `SpecialistLocalRepository`. Child UIs consume `activeAssignmentForProfile` purely as playful guidance without exposing clinical terminology.
