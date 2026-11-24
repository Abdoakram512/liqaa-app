# Rive Integration Specification — Yasser (ياسر)

## Overview
This document specifies the integration contract and architecture for Yasser's interactive 2.5D Rive runtime asset (`assets/rive/yasser.riv`).

The character rig is developed in Rive by the motion and 3D design team. Flutter presentation components must support both static fallback illustrations (current phase) and the live Rive runtime character (subsequent phase) via a unified character presentation abstraction (`YasserAvatar` / `YasserSceneWidget`).

## Expected Asset Path
```text
assets/rive/yasser.riv
```
*(Do NOT create placeholder or dummy `.riv` binary files. The file will be placed here upon final delivery by the Rive animation team).*

## Rig Capabilities & Specifications
Once finalized, the Rive rig will provide state machines and inputs for:
1. **Core Idles & Ambient Motion:**
   - Natural idle breathing loops
   - Micro-eye blinks and eyebrow twitches
   - Head tilting and weight shifts
2. **First-Time UX & Onboarding Behaviors:**
   - Welcoming hand wave (`waving`)
   - Thoughtful / puzzle solving pose (`thinking`, `lightbulb`)
   - Victorious celebration (`celebration`, `fist_pump`)
3. **Authentication Interactive Reactions (Future Phase):**
   - Look at Name field (`look_down_left` / `look_x`, `look_y`)
   - Look at Email field
   - Hands covering eyes for Password entry (`cover_eyes: true`)
   - Peeking when "Show Password" toggle is activated (`peeking: true`)
   - Success dance / smile on authentication verified
   - Confused / encouraging head shake on validation error
4. **Child-Friendly Educational Sessions:**
   - Listening attention pose
   - Prompting selection with pointer gesture
   - Cheering positive reinforcement upon correct answers

## Integration Rules & Security Standards
- **Zero Raw Credential Exposure:** Never pass raw passwords, PINs, or credentials to Rive controllers or listeners. Only pass boolean state flags (e.g., `isPasswordFocused`, `isObscured`).
- **Graceful Fallback:** If `assets/rive/yasser.riv` is absent from runtime bundle, Flutter components must automatically render the high-resolution 2.5D PNG poses (`assets/images/yasser/poses/`) with native Flutter entrance and breathing physics without errors or jank.
- **State Machine Isolation:** Wrap all Rive controllers inside dedicated Cubits/Controllers to prevent animation state leaks into domain or data layers.
