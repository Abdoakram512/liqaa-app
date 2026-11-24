# Yasser — Rive asset handoff

Status: **runtime export pending**. This directory is prepared for the real character export. No placeholder .riv is included.

## Required files

- `yasser.riv`: runtime export of the current master character from Rive, with images/fonts embedded when appropriate.
- Any referenced external images, fonts or audio not embedded in the runtime export; retain their actual asset identifiers and resolve them using the Rive runtime asset loader.
- Original onboarding PNGs, if needed, belong under `assets/images/yasser/onboarding/`, not in the authentication animation state machine.
- Keep the editable Rive project/source backup separately from the Flutter runtime. Do not publish private editor links or licensed source material without permission.

## Editor-side identifiers recorded in the Phase 1 report (not verified against an exported binary)

| Identifier | Role |
| --- | --- |
| `Yasser_Phase1_Work` | Working artboard |
| `State Machine 1` | Recorded state machine |
| `passwordTyping` | Password transition input, expected boolean; verify type on export |
| `NameEntry` | Recorded animation/state name; inspect actual runtime role |
| `PasswordCovered` | Recorded animation/state name; inspect actual runtime role |
| `P1_Wave_Validation` | Rig validation |
| `P1_IK_Validation` | Rig validation |

Phase 1 is not certified complete. Do not assume all facial, finger or joint deformation work is final.

## Flutter integration

1. Export the current working character as a runtime .riv with its selected dependencies. Verify that the file opens in the runtime.
2. Save it as `assets/rive/yasser.riv`.
3. In the Flutter project, run `flutter pub add rive` and select a runtime version compatible with the export, platform requirements and project SDK. Initialize it as required by the selected version.
4. Under the existing `flutter:` key in pubspec.yaml, add an `assets:` entry for `assets/rive/yasser.riv` and actual external assets. Do not register the missing file before export.
5. Load the artboard and state machine using the exact exported names and verify all input types. Keep one mounted character through focus changes; never swap separate character images for authentication.
6. Bind password focus to the verified password input; on blur, reset it. Handle show/hide separately only when the exported state machine supports it. Never send password contents to Rive.
7. Keep the Flutter form independent of the animation; dispose focus nodes and Rive controllers and test on Android and iOS.

## Proposed Phase 2 contract (not yet verified or implemented in the runtime)

- Name/email focus: `isNameFocused` (bool)
- Password focus: `passwordTyping` (bool, verify existing)
- Show password: `isPasswordVisible` (bool)
- Typing: `isTyping` (bool)
- Gaze: `lookX`, `lookY` (numbers)
- Success/error: `loginSuccess`, `loginError` (triggers)
- Idle, smooth transitions and natural hand positioning remain animation-side work.

Use only inputs confirmed in the actual export. A static image may be a fallback, but is not a substitute for the master rig.

## Acceptance checks

- [ ] Real .riv exported and committed.
- [ ] Embedded/external assets validated.
- [ ] Artboard, state machine and inputs verified against runtime.
- [ ] Flutter asset registration and dependency resolved.
- [ ] Name/password focus transitions tested without replacing the character.
- [ ] Password coverage and return-to-idle tested.
- [ ] Remaining Phase 2 reactions implemented and tested.
