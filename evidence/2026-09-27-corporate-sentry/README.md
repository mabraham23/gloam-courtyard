# R14 corporate sentry candidate

## Question

Does an enemy built on the same R14 anatomical/rig base as the player read as a
higher-quality original corporate guard when given a crimson uniform, enclosed
helmet and visible sidearm?

## Scope and boundary

- Candidate review mode now replaces both the player and guard visuals. The
  production V1 player and procedural warden remain the unchanged default.
- The sentry reuses the exact frozen R14 GLB
  `30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`
  and its 74-joint pose contract.
- Player-only hair and cape presentation are removed. The suit keeps authored
  normal/roughness response but uses a crimson albedo; charcoal gear, an original
  segmented helmet, visor/comms pieces and a pelvis-following thigh holster create
  a distinct security silhouette.
- The sidearm is visual equipment only. Existing close-range attack timing,
  damage, AI, collision and takedown behavior are unchanged; ranged combat was
  not added or implied by this checkpoint.

## Rendered review

Managed run `20260927T225311Z-corporate-guard-5b6e96`, source
`36805cdb75a9b514d2c63520dad6d075fbd16d41c24f5dadb9d82c8b439a5195`.
The fixed 30 Hz, 210-frame sequence places the preserved procedural warden and
new sentry side by side in the same courtyard light/scale through idle, patrol,
close-range strike, hit reaction and defeat. Nine original keyframes, the contact
sheet, preview, import/render logs and exact manifest are preserved here.

Inspection: the crimson body and helmet remain readable in moonlit gameplay
lighting; the dark visor and red light bar separate the head from the player; the
holstered sidearm stays on the outer thigh through gait, reaction and fall. The
new continuous skinned anatomy is visibly less blocky than the preserved warden.
The result is diagnostic and awaits user taste judgement.

## Checks

- `CORPORATE_GUARD_CONTRACT_OK checks=14 failures=0`
- `GLOAM_CHARACTER_ART_MECHANICS_OK checks=312 failures=0`
- `CORPORATE_GUARD_SEQUENCE_OK frames=210`
- `python3 -m unittest discover -s tools/feedback -p 'test_*.py'` — 12 passed
- R14 asset SHA assertion and managed import/render pass

The first rendered iteration retained a nearly black suit because the source
albedo swallowed the red tint, and its hand-mounted prop read ambiguously. Those
frames remain in the raw review history. The final candidate retains the authored
normal/roughness maps, uses a clear crimson albedo and moves the sidearm into an
honest, readable thigh holster.

## Remaining acceptance

Fresh managed live run `20260927T225539Z-live-f57781` launched the exact-title
`Gloam Courtyard Spike (DEBUG)` candidate at PID 77731 and remains open. F12
capture `review_36805cdb75a9_77731_47235777` records health 100, Momentum 0,
guard 100, an automatic patrol position, the exact R14 asset SHA, source
`36805cdb75a9b514d2c63520dad6d075fbd16d41c24f5dadb9d82c8b439a5195`
and no changed source files. Native input in this capture was F12 only.

User visual judgement at normal gameplay scale and native close-range
attack/reaction, defeat or takedown review remain pending. Promoting the sentry
to the production default or adding ranged firearm mechanics are separate
decisions.
