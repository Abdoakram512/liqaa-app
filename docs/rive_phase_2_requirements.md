# Yasser (ياسر) — Rive Phase 2 Character Authoring Requirements

## 1. Overview & Objectives

While Phase 1 delivered the anatomical rig foundation, bone hierarchy, and basic password privacy arm movement (`assets/rive/yasser.riv`), Phase 2 focuses on advanced expressive behaviors, continuous gaze tracking, speech development interactions, and state machine inputs.

This document serves as the formal engineering contract for the Rive animation team.

---

## 2. Required Phase 2 State Machine Inputs

The app loads `State Machine 1` on artboard `Yasser_Phase1_Work`. Password privacy already uses a ViewModel boolean. The remaining rows describe planned authoring.

| Input Name | Type | Allowed Values | Default | Target Rig / Bone Components | Expected Transition Behavior |
| --- | --- | --- | --- | --- | --- |
| `passwordTyping` | ViewModel boolean | `true`, `false` | `false` | `P1_UpperArm_ScreenL/R`, `P1_Forearm_ScreenL/R`, `P1_HandTarget_ScreenL/R` | 250ms easeInOut: arms lift smoothly from sides to cover eyes without clipping through head. |
| `isPeeking` | Boolean | `true`, `false` | `false` | `P1_Hand_ScreenL/R_Fingers` | While `passwordTyping = true`, spreads index and middle fingers slightly to playfully peek. |
| `isNameFocused` | Boolean | `true`, `false` | `false` | `P1_Neck_Head`, `Eyes` | Subtle head turn (5 degrees) towards input with cheerful attentive eyebrow elevation. |
| `lookX` | Number | `-1.0` to `+1.0` | `0.0` | `P1_Neck_Head_Face_EyeL`, `P1_Neck_Head_Face_EyeR` | Normalized horizontal gaze tracking. Smooth cubic hermite interpolation. |
| `lookY` | Number | `-1.0` to `+1.0` | `0.0` | `P1_Neck_Head_Face_EyeL`, `P1_Neck_Head_Face_EyeR` | Normalized vertical gaze tracking (-1.0 up, +1.0 down). |
| `celebrateTrigger`| Trigger | Trigger impulse | N/A | Full Body (`P1_MasterRoot`, Arms, Face) | Upward celebratory jump with thumbs up, lasting ~1800ms before returning to idle. |
| `isThinking` | Boolean | `true`, `false` | `false` | Right Arm (`P1_HandTarget_ScreenR`), Eyebrows | Hand to chin pose, head tilted upward 10 degrees. |
| `validationError` | Trigger | Trigger impulse | N/A | `P1_Neck_Head`, Eyebrows | Gentle supportive head shake (confusion), followed by an encouraging smile. |
| `isListening` | Boolean | `true`, `false` | `false` | Head & Ears | Attentive forward posture with subtle ear-cupping motion when microphone is recording. |
| `isTalking` | Boolean | `true`, `false` | `false` | `P1_Neck_Head_Face_Mouth` | Mouth opening and natural speech cadence loop. |
| `viseme` | Number | `0` to `8` | `0` | Mouth geometry | Viseme shapes corresponding to Arabic vowels (/a/, /u/, /i/) and consonants. |

---

## 3. Rig & Animation Quality Standards

### 3.1 Hand & Arm Anatomical Rules
- **Hand Orientation:** Thumb must always face inward towards the torso in resting position.
- **Elbow Rotation:** Elbow joints must bend naturally backward; avoid unnatural inward dishing.
- **Wrist Articulation:** Hand targets must not twist the forearm beyond 80 degrees of axial rotation.
- **Finger Poses:** Fingers must never overlap into an unnatural single clump; provide distinct silhouette separation.

### 3.2 Eye Tracking & Gaze
- Eye movement must be constrained by an elliptical bounding socket (`P1_EyeLimit`).
- Pupil movement must be accompanied by subtle secondary eyelid tracking (when looking down, upper eyelid drops slightly).

### 3.3 State Machine Layering Architecture
To prevent interactions from interrupting ambient breathing or blinking:
- **Layer 0 (Base Ambient):** Continuous breathing, spine weighting, idle micro-sway.
- **Layer 1 (Eye Ambient):** Randomized blinking loop (fires every 3-6s).
- **Layer 2 (Gaze Tracker):** Continuous additive eye and head orientation (`lookX`, `lookY`).
- **Layer 3 (Gestures):** Waving, thinking, celebrating, pointing.
- **Layer 4 (Privacy Override - Highest Priority):** `passwordTyping` and `isPeeking`. When active, this layer overrides lower-layer arm positions completely.

---

## 4. Acceptance Criteria for Phase 2 Asset Delivery

1. Delivered file must replace `assets/rive/yasser.riv` and retain exact artboard name `Yasser_Phase1_Work` and state machine name `State Machine 1`.
2. Binary size must remain under 2.5 MB.
3. Flutter can bind the exported ViewModel and drive its properties, including `passwordTyping`, through the named state machine.
4. No external texture dependencies; all vector and raster assets must be embedded in the `.riv` file.
5. Zero visual clipping or tearing at 60 FPS on mid-range Android devices.
