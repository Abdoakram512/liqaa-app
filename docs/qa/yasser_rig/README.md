# Yasser Production Master Rive Rig — QA & Engineering Evidence

## 1. Source Rig & Artboard
- **Rive Project:** `Yasser Character 2.5D` (`projectId: 1752778`, `fileId: 2745783`)
- **Primary Artboard:** `Yasser_Phase1_Work` (`5-1`, `486x695`)
- **Primary ViewModel:** `ViewModel1` (`1-14`)
- **Primary State Machine:** `State Machine 1` (`5-83`, 4 non-overlapping layers)
- **Exported Binary:** `assets/rive/yasser.riv` (`1,044,056` bytes, Rive format v7.5)
- **Backups:**
  - `tools/rive/yasser/backups/phase0_baseline/yasser_baseline.riv`
  - `tools/rive/yasser/backups/phase0_baseline/yasser_character_2.5d.riv`
  - `tools/rive/yasser/backups/phase0_baseline/scene_baseline.rml`
  - `tools/rive/yasser/backups/production/yasser_master.riv`
  - `tools/rive/yasser/backups/production/yasser_character_2.5d.riv`
  - Note: `.rev` export is gated by the Rive workspace plan (`exportRev` unavailable); `.riv` + Phase 0 `scene_baseline.rml` preserve full backups.

## 2. Reconstructed Rig Parts & Meshes
Generated deterministically via `tools/rive/yasser/build_clean_rig_parts.py` into `tools/rive/yasser/generated_parts/`:
- Crisp contoured left/right yellow sleeves (`Sleeve_ScreenL_Clean`, `Sleeve_ScreenR_Clean`) with rib-knit cuffs rendered over hand tabs, edge alpha hard-zeroed (`alpha < 12 -> 0`), and 2-subdivision deformed meshes bound 100% cleanly via `querySkin`.
- Context-aware anatomical hands attached to `P1_Hand_ScreenL` (`6-6`) & `P1_Hand_ScreenR` (`6-9`):
  - `Hand_L_Relaxed`, `Hand_L_Palm`, `Hand_L_Cover`
  - `Hand_R_Relaxed`, `Hand_R_Palm`, `Hand_R_Cover_Palm` + individual finger layers (`Hand_R_Finger_Index/Middle/Ring/Little` on `11-159..162`)

## 3. ViewModel1 (`1-14`) Schema & Formula Gaze Converters
- **Privacy & Mode Booleans:** `passwordTyping`, `isPeeking`, `isListening`, `isThinking`, `isSpeaking`, `isFollowingInput`
- **Continuous & Discrete Numbers:**
  - `lookX` (`-1..1`) -> formula converters `EyeL_LookX` (`27-1426`) & `EyeR_LookX` (`27-1440`) driving `EyeL.y` (`11-227`) & `EyeR.y` (`11-228`)
  - `lookY` (`-1..1`) -> formula converters `EyeL_LookY` (`27-1454`) & `EyeR_LookY` (`27-1468`) driving `EyeL.x` (`11-227`) & `EyeR.x` (`11-228`)
  - `mouthShape` (`0..8`) -> drives `Mouth_Articulation_Layer` (`27-3220`) over vector `Yasser_Mouth_Rig` (`27-1425`)
  - `onboardingScene` (`0..3`) -> switches Onboarding Welcome / Discovery / Ready states
- **Triggers:** `wave`, `jump`, `nameEntry`, `celebrate`, `encourage`, `retry`, `sessionComplete`, `resetToIdle`

## 4. Visual QA Gallery (`before/` vs `after/`)
- `before/01_neutral_phase1.png` .. `before/04_login_password_peek.png` — Pre-fix baseline captures documenting wrist-twist, shoulder gaps, reversed cover hands, and rigid peek fingers.
- `after/01_after_idle.png` — Clean Idle rest pose (`6-248.174=false`, `6-250.174=true`).
- `after/02_after_wave.png` — Raised open-palm Wave (`6-248.174=true`, natural downward elbow, inward thumb).
- `after/03_after_celebrate.png` — Symmetrical double-arm Celebrate.
- `after/04_after_password_cover.png` — Clean privacy cover with natural elbows and outward thumbs.
- `after/05_after_password_peek.png` — Articulated 4-finger spread PasswordPeek (`11-159..162`).
- `after/06_mouth_open.png`, `after/07_mouth_rounded.png`, `after/08_mouth_closed.png` — Native vector `Yasser_Mouth_Rig` shapes with feathered skin blend.
- `after/09_animation_lab_skeletal_qa.png` — Extended `AnimationLabView` rendering live Rive asset + real-time Skeletal/IK Overlay (`_YasserRigOverlayPainter`).
- `after/10_before_after_comparison.png` — Side-by-side Before vs After visual comparison sheet.

## 5. Verification Commands
```powershell
$env:PATH = "E:\Flutter Projects\liqaa_app\build\rive_native\native\build\windows\bin\lib\release;$env:PATH"
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```
