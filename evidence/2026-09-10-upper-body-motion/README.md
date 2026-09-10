# Upper-body motion review — September 10, 2026

Question: does the spine and shoulder girdle participate naturally through
locomotion, crouching, jumping and combat, without exaggerating the movement?

The user requested a slight walking hunch and natural back/shoulder involvement
in actions. This pass adds a small thoracic curve, stride counter-rotation,
shoulder following and a steadied head. Jump preparation, release and landing
produce different chest/shoulder responses. Counter, traversal and hurt receive
bounded offsets. Punches transfer rotation from hip through the spine into the
chest, then release in that order; their calibrated contact orientation is retained.
Existing compact evade, kick and takedown poses retain their authored core motion.

The new pose resource is isolated under `actors/gloam_vigil/v4/motion/` and is
applied only to the anatomical candidate. It resets with bind and eases across
action changes. The cape counteracts the added crouch fold so it hangs clear of
the lintel. No new gameplay root motion, damage, timing, speed or controls.
The frozen GLB and current swept hair/clean-shaven appearance are unchanged.
V1 remains default; this is a candidate motion refinement, not a release switch.

## Matched rendered review

The `upper-body` fixture uses 480 normal-rendered frames at 960×600, 30 Hz,
Godot 4.7.2 / GL compatibility. It advances the actual controller with disclosed
held-input/action helpers and explicit four-strike commits. Profile and quarter
cameras expose body motion; the last segment uses the default gameplay camera.
This is not native held-input or timing/performance evidence.

Corrected baseline: `20260910T201155Z-upper-body-3ba571`, source
`c5e1262a1feeee42e959dd63c26d313ba61dc4836790b36ca3ff58aede717a3e`.
The final comparison and original selected frames accompany this report.

Agent review: the torso rounds modestly and shoulders follow the stride. Jump
release and landing have a small chest response. Punch anticipation and recovery
separate the hip and ribcage timing while keeping contact legible. The effect is
subtle at the default zoom. Continuous held movement, overall naturalness and
paired native takedown still require user judgement.

## Rejected iterations and discovered issues

- Initial capture `20260910T200739Z-upper-body-1319e0` rendered all 480 frames,
  but preview generation requested twelve keyframes against a nine-frame limit.
  Preview regenerated from the original frames; the initial error remains in
  its manifest. No runtime failure was involved.
- Initial pair `1319e0` / `20260910T201018Z-upper-body-3fa66f` used the controller's
  randomized strike picker. Combat variants differed, so it is not accepted as
  a matched combat comparison. The fixture now commits all four variants
  explicitly and seeds its remaining random strike.
- Intermediate source `799a28afaad46f22dc341a1d4b366790286e55e8149259b1d0dc8d3a05fe935d`
  (`20260910T201246Z-upper-body-8ec590`) rendered successfully but failed 47
  large-crouch mesh samples. The cape reached 2.014432 against the unchanged
  2.0-unit lintel. A compensating cloth-root rotation fixes the lifted cape;
  the limit was not relaxed. Original source, frames and comparison remain in
  that pinned raw run; its comparison manifest and failure log are curated here.
- The old alignment test expected a flatter chest (mean <8°, peak <11°).
  The requested hunch measures mean 10.506°, peak 13.022°, so that old taste
  gate failed. The deliberate new posture bounds are mean <12°, peak <15°;
  the existing pelvis-to-chest mean <12° and all speed/leg gates are retained.
  Actual pelvis-to-chest mean is 11.558°. These are presentation bounds, not
  anatomical proof or user acceptance. The old failed report is preserved.
- The older action sampler expected 51,170 pre-hair imported vertices. Current
  face compaction and swept hair, already recorded in the preceding checkpoint,
  render 50,243 vertices. The exact expectation is corrected to 50,243; the
  unchanged full-mesh sampler still validates every retained vertex. Its stale
  expectation failure is preserved separately.
- One final capture attempt refused a snapshot while a validation log was being
  written. No renderer was started; capture is repeated after logs settle.

## Validation and limits

Final results and native handoff are recorded below. Headless stdout logs
preserve the actual game assertions. macOS system-CA and sandboxed user-log/
editor-settings write messages are separate environment warnings, not game passes.

Known visual limits: captured gait flight/foot sliding, stylized hair and hands,
and fast action blends remain. The new movement is a subtle refinement. No new
performance certificate or automatic appearance acceptance is claimed.
The generated local board's source checks and pre-existing rendered UI policy
blocker remain distinct from game validation and user visual review.

Passing deterministic results:

| Check | Result |
|---|---|
| Full current mesh, all sizes, 30/60 Hz | 22,164 / 22,164, 50,243 vertices |
| Actual controller jump, both leads, all sizes/rates | 5,646 / 5,646 |
| Four-attack contact/recovery | 352 / 352 |
| Action transitions including signed crouch arms | 70 / 70 |
| Strike/evade/takedown mesh and mechanics | 198 / 198 |
| Default / candidate gameplay mechanics | 309 / 311 |
| Revised posture plus original speed/leg gates | 10 / 10 |
| Focused crouch full mesh | 1,083 / 1,083 |
| Editor import / default startup | Passed |

Final crouch maxima are small 1.945137, medium 1.981129 and large 1.972558,
all below the unchanged 2.0 lintel. Floor/contact tolerances remain unchanged.
Jump and attack tests passed on the same motion curves before the isolated cape
compensation; final full-mesh and action suites include the correction.

Final rendered source is `3e4bb12bca1b178d1e01102241b10c8d65f84b0924c9eafd1beb5af4e4312a73`,
run `20260910T201912Z-upper-body-94418e`. The baseline/final fixture SHA is identical:
`b2860a6e20e75556e1f5e07538c2351878c42c1cc3710525073a888bfe521c32`.

## Native handoff

Managed run `20260910T202033Z-live-ae1dea`, PID **54186**, has the same final source
and exact `Gloam Courtyard Spike (DEBUG)` title. Window enlarged; native Q enter/
exit, V preparation/rise and subsequent landed message, Space left-kick whiff,
C evade/+4 Momentum and R/0/F12 reset were observed. Seven PNG/state pairs verify
against their image hashes with no changed source files. Representative original
crouch/jump/strike/reset pairs and a complete observations index are in `native/`.
The jump image shows airborne rise at 0.492998 at fixed X/Z; the strike image is
a left-kick startup, not a native punch or damage-contact claim. Final reset is
standing/grounded, 100 health, 0 Momentum, guard 100, default camera, left open.

The full-size native images, paired original motion frames and two 16-second
previews make this review about 12 MB, slightly above the ordinary 10 MB target.
Intermediate full captures remain in pinned local raw runs instead of duplicating
their previews here. No superseded source or unique capture was deleted.

Both local board files were regenerated; `ROADMAP_CHECK_OK tasks=17` and all
12 tooling tests pass. Rendered board interactions/responsive layouts keep the
existing policy gate; no browser workaround was attempted. Final source identity
was rechecked against the live snapshot with `CURRENT_TREE_MATCHES_LIVE_CODE`.
