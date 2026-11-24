# Yasser (ياسر) — Flutter Character Integration Architecture

## 1. Architectural Philosophy

In LIQAA, Yasser is designed as an active, living educational companion rather than a static mascot or passive decorative banner.

To achieve this without tightly coupling animation logic to business rules, the architecture implements a **Centralized Character Interaction System**:

```text
┌─────────────────────────────────────────────────────────────┐
│                    Application Features                     │
│  (Splash, Onboarding, Login, Register, AI Lab, Games)       │
└──────────────────────────────┬──────────────────────────────┘
                               │ Dispatches Semantic Events
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 YasserInteractionEngine                     │
│  - Priority Arbitration (Critical > Transient > Ambient)    │
│  - Conflict Prevention (No blinking while covering eyes)    │
│  - Randomized Ambient Life (3-7s blinking cycle)            │
│  - Tap Cooldowns & Return-To-Idle Schedulers               │
└──────────────────────────────┬──────────────────────────────┘
                               │ Emits YasserStateMapping
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   YasserAnimationMapper                     │
│  - Maps Semantic State -> Rive Inputs (passwordTyping, etc.) │
│  - Maps Semantic State -> High-Res 2.5D Fallback Poses      │
│  - Maps Input Position -> Normalized Gaze Offset (X, Y)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ Drives
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      YasserCharacter                        │
│  - Attempts Live Rive Rendering (State Machine 1)           │
│  - Graceful Fallback with Native Breathing Scale & Floats   │
│  - Zero Raw Credential Exposure (Only Booleans / Offsets)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Zero-Credential Exposure Rule

Under no circumstance is an actual password, secret token, or OTP transmitted into the animation pipeline.

- Form fields dispatch **only semantic focus flags**:
  ```dart
  onFocusChanged: (hasFocus) {
    if (hasFocus) {
      controller.coverEyes(); // Dispatches YasserAnimationState.coveringEyes
    } else {
      controller.uncoverEyes(); // Dispatches YasserAnimationState.returningToIdle
    }
  }
  ```
- Visibility toggles dispatch **only boolean visibility flags**:
  ```dart
  onPasswordVisibilityChanged: (isVisible) {
    if (isVisible) controller.peek();
    else controller.coverEyes();
  }
  ```
- Diagnostics panels display only semantic states, priorities, and timestamps—never keystrokes or input text.

---

## 3. Graceful Fallback Presentation

To ensure production stability on all devices and test runners:
1. **Live Rive Runtime:** When supported by the platform, `YasserCharacter` initializes `assets/rive/yasser.riv` with `State Machine 1` and binds inputs.
2. **High-Fidelity 2.5D Fallback:** If Rive runtime fails or is disabled (e.g. in headless unit tests), `YasserCharacter` renders the corresponding 2.5D pose from `assets/images/yasser/poses/` with:
   - Native Flutter continuous breathing scale (0.985 to 1.015).
   - AnimatedSwitcher cross-fading (300ms easeOutBack).
   - Organic soft drop shadow.
   - Interactive tap reactions.

---

## 4. Future Application-Wide Character Integration

The character engine is engineered to seamlessly integrate with future LIQAA modules:

### 4.1 Speech & Pronunciation AI Integration
When the speech recognition pipeline (`AudioRecorderService`, `SileroVadEngine`, `PhonemeRecognitionEngine`) is active:
- `listeningStarted` -> `controller.engine.triggerState(YasserAnimationState.listening);`
- `speechDetected` -> Yasser leans in with attentive ear cupping.
- `correctPronunciation` (score >= 80%) -> `controller.celebrate();`
- `phonemeError` (e.g. fronting /k/ -> /t/) -> `controller.reactToValidation(false);`
- `sessionCompleted` -> Yasser waves and confetti triggers.

### 4.2 Home Screen & Milestones
- First launch of the day -> Morning greeting wave.
- Milestone achieved (e.g. 5 sound cards mastered) -> Celebratory dance.
- Inactive user (idle > 15s) -> Yasser scratches head or looks around curiously.
