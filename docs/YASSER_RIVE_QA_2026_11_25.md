# Yasser animation test build — 2026-11-25

Base: main 912d236. Editable source was pulled from Rive file 2745783 before editing. Source correction was uploaded as revision 50377522.

## Changes

- Moved the screen-right password IK target from y=-201 to -195. Its original position exceeded the two-bone arm's reach after accounting for the master-root translation. No character artwork or skin weights were changed.
- Exported the updated source into assets/rive/yasser.riv (1,616,813 bytes). Retained the Yasser_Phase1_Work artboard and State Machine 1.
- Privacy targets now have one driver: the authored state machine. Flutter no longer delays its boolean until a procedural pose threshold, or overwrites its targets during cover/peek. Procedural fingers remain for peeking.
- Kept the previous wave-release repaint fix.
- Updated stale onboarding tests to expect listening/presenting instead of thinking, matching merged main.
- Editable RML and source artwork are preserved under tools/rive/yasser.

## Executed checks

- Rive verify: zero errors and warnings. Resolved scene inspection: no reported problems; Phase1 has 34 bones, 4 IK constraints, 4 skins and 223 weights.
- Real Flutter Rive runtime test decoded this exported asset, instantiated its controller and sampled cover and return over 180 frames. Checked finite target coordinates, the authored cover endpoints and the restored idle endpoints. Passed.
- flutter test --no-pub --no-test-assets test/core/animation: 20 passed.
- dart analyze lib/core/animation/yasser test/core/animation: no issues.

On Windows the test command required the installed rive_native release DLL directory on PATH. Compiler temporary files were redirected to D because C had insufficient free space. --no-test-assets avoids copying unrelated large AI assets; these tests use fallbacks or read the Rive file directly.

## Limits and device review

This is a partial fix for testing, not a visual approval of the full rig. CLI screenshots rendered a uniform blank image, so they provide no visual evidence. Android was not connected. The native test establishes decoding and target behavior, not hand anatomy, mesh deformation, layering or pixel appearance. No claim is made that wave/listening/celebration, facial expressions, legs, fingers or all screenshot/video defects visually pass.

The Rive export service reported a Rive splash screen required by the current workspace plan. Inspect startup as well as onboarding pages 1/2/3, early/middle/late wave frames, cover/peek/uncover, and interrupted transitions on device. Onboarding listening still has no newly authored hand-to-ear gesture in this change. Other gestures still use existing procedural controls.
