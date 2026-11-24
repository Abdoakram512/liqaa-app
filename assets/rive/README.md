# Yasser (ياسر) — Rive Asset & Runtime Integration Specification

## 1. Overview & Current Status

This directory contains the interactive 2.5D Rive runtime asset (`assets/rive/yasser.riv`) for Yasser, the official main character of LIQAA.

- **Asset Path:** `assets/rive/yasser.riv` (Runtime binary present, ~958 KB).
- **Status:** Runtime export received and committed.
- **Architecture Strategy:** The character presentation layer is built to support both static 2.5D high-resolution PNG fallbacks (`assets/images/yasser/poses/`) and live interactive Rive runtime animations through a unified character abstraction (`YasserAvatar` / `YasserSceneWidget`).

---

## 2. Rig Capabilities & Expected Behaviors

The Rive rig delivers interactive states and animation machines for core application experiences:

### 2.1 Core Idles & Ambient Motion
- Natural idle breathing loops
- Micro-eye blinks and eyebrow twitches
- Subtle head tilts and body weight shifts

### 2.2 First-Time UX & Onboarding Behaviors
- **Welcoming hand wave** (`waving`)
- **Thoughtful / puzzle-solving pose** (`thinking`, `lightbulb`)
- **Victorious celebration** (`celebration`, `fist_pump`)

### 2.3 Authentication Interactive Reactions
- **Name/Email field focus:** gaze tracking towards input (`look_down_left` / `lookX`, `lookY` / `isNameFocused`).
- **Password focus:** hands covering eyes (`passwordTyping: true` / `cover_eyes: true`).
- **Show Password toggle:** peek through fingers (`isPasswordVisible: true` / `peeking: true`).
- **Success / Error triggers:** victory dance / encouraging head shake (`loginSuccess`, `loginError`).

### 2.4 Child-Friendly Speech & Pronunciation Sessions
- Active listening pose when microphone is recording.
- Prompting gesture pointing to target word / phoneme cards.
- Cheering and confetti reinforcement upon correct pronunciation.

---

## 3. Editor-Side & Exported Runtime Identifiers

Runtime inspection of the exported binary identified the following symbols and state machine structures:

| Identifier | Type / Context | Description |
| --- | --- | --- |
| `Yasser - Main Character` | Artboard | Main character artboard |
| `State Machine 1` | State Machine | Primary interactive state machine |
| `nameEntry` | Input / State | Triggered during name/username entry |
| `passwordTyping` | Boolean Input | Privacy pose activation during password entry |
| `Yasser_Privacy_Arm` | Layer / Group | Arm movement covering eyes |
| `Yasser_TwoHand_Cover` | Layer / Group | Full two-handed eye cover variation |
| `Yasser_Original_Clean` | Rig Base | Baseline default pose |

> [!NOTE]
> Always verify runtime input names and types against the exported binary before binding in production code.

---

## 4. Flutter Integration & Security Guidelines

1. **Zero Credential Exposure:** Never pass raw passwords, PINs, or credentials to Rive controllers, listeners, or state machines. Pass only boolean state flags (e.g. `isPasswordFocused: true`, `isPasswordVisible: false`).
2. **Graceful Fallback:** If `assets/rive/yasser.riv` fails to load or the platform runtime is unsupported, Flutter components automatically fall back to the high-resolution 2.5D PNG poses (`assets/images/yasser/poses/`) with native Flutter entrance and breathing physics without crashes or jank.
3. **State Machine Isolation:** Wrap all Rive controllers and listeners inside dedicated Cubits or state controllers to avoid leaking animation logic into business or data layers.
4. **Lifecycle & Memory Management:** Properly dispose focus nodes, controllers, and cached artboards when navigating away from animated screens.

---

## 5. Verification Checklist

- [x] Real `.riv` runtime binary present at `assets/rive/yasser.riv`.
- [x] High-resolution static fallback poses verified in `assets/images/yasser/poses/`.
- [x] Zero raw credential exposure rule enforced across input bindings.
- [x] Flutter asset registration configured in `pubspec.yaml`.
- [x] Unit and navigation test suite passes cleanly with character widgets.
