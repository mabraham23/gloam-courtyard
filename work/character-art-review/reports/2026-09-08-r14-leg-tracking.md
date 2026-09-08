# R14 leg tracking correction — 2026-09-08

Status: implementation and internal visual review pass; user movement judgement
remains Waiting. This supersedes the prior sparse lower-leg/alignment acceptance,
which the user correctly rejected as still too wide and flared. V1 stays default;
the ordinary-input R14 review is the current playtest, not a released replacement.

## Cause and correction

The imported rest chain widens from 0.279 authored units at the hips to 0.431
at the ankles. A fixed hip adduction narrowed idle but reopened as captured knee
flexion changed. The previous motion correction was only 0.0045 radians. The old
test sampled four run frames, used unsigned separation, and had no moving upper
bound: it could neither catch persistent wide tracking nor reliably catch crossing.

`gloam_vigil_rig_adapter.gd` now solves grounded ankle lanes relative to the posed
hip span: 0.96 of hip width at idle, smoothly narrowing to 0.86 while moving.
Rotation is bounded to 0.34 radians. A second rigid hip rotation around the
hip-to-ankle chord directs the knee bend forward instead of sideways, with a
near-extension fade and 0.75-radian bound. Exact pre-correction foot attitude is
restored afterward. These rotations preserve hip position, chain lengths, knee
flexion and the ankle's fore/aft endpoint; knee fore/aft position may change as
its bend plane is corrected. No bone positions, imported rest, mesh, root motion,
controller, speed or combat parameters changed. Wider crouch/combat poses retain
their existing action-specific stance; this is a grounded-gait correction.

## Matched measurements

The table uses the existing 60 Hz alignment fixture's authored-space units,
with the actor scale removed. The new full-cycle report uses actor-oriented world
metres and retains `1.35 * body_preset`; divide by that factor to compare them.

| Measurement | Before | Corrected |
| --- | ---: | ---: |
| Idle ankle separation | 0.3143 | 0.2679 |
| Run ankle mean / maximum | 0.3586 / 0.4134 | 0.2393 / 0.2492 |
| Run knee mean / maximum | 0.2982 / 0.3170 | 0.2522 / 0.2586 |
| Left knee lateral-angle mean / maximum | 1.77 / 4.02 degrees | 0.79 / 1.73 degrees |
| Right knee lateral-angle mean / maximum | 2.60 / 5.25 degrees | 0.66 / 1.44 degrees |

Mean moving ankle spread is about 33% lower; maximum spread is about 40% lower.
Full-cycle normalized calf minimum/mean/maximum is 0.2413/0.2452/0.2534.
Across all six preset/rate cases, ankle/hip ratios are 0.8600–0.8978 and calf/hip
ratios are 0.8690–0.9130. Signed ordering is retained. Root speed remains
4.799998–4.800000 units/s; at least two gait cycles are sampled per case. Stop
blend settles in three frames at 30 Hz and five at 60 Hz. The new report is
`2026-09-08-r14-leg-tracking.json` beside this file.

The repeat-application probe is sensitivity evidence, not a reconstructed
first-call baseline or an idempotence assertion. A second application can move
the capped 30 Hz endpoint another 8.77 mm. In that probe hip delta is zero,
ankle-Z/length deltas are below 6e-8 authored units, foot basis-axis error is
below 1e-7, and knee-flex error below 6.9e-6 degrees. Production resets imported
poses each frame and applies the solver once, so the repeated correction does
not accumulate during play.

## Rendered and runtime evidence

- Matched 360-frame normal-renderer before/final reels:
  `captures/r14-leg-tracking-before00000000.png` … `...00000359.png` and
  `captures/r14-leg-tracking-final00000000.png` … `...00000359.png`.
  Both use the real 4.8-unit/s held-input controller. Review staging hides
  courtyard occluders and enlarges the diagnostic floor to cover the whole path;
  this is explicitly not an unmodified courtyard camera capture.
- Front 112/130/147/158, profile 25/46/65 and three-quarter 200/230 were compared.
  Independent visual review agrees the calves/boots track beneath the thighs,
  the outward bow is reduced, and the original profile stride is retained.
  Neighboring three-quarter 227/229/230/232/235 show brief projected boot overlap
  around crossover, without obvious mesh penetration. Occluded screenshots are
  not an exhaustive self-collision proof.
- Native ordinary-input review: exact title `Gloam Courtyard Spike (DEBUG)`,
  current R14 SHA, PID 30109. C completed with +4 Momentum; Q visibly crouched;
  SPACE, body-size selection, reset and F12 were exercised. Discrete input did
  not capture the sub-second strike contact or provide native held-walking
  evidence; the deterministic reels supply the continuous motion evidence.
  Final reset medium/default-camera capture:
  `captures/courtyard_3d_2026-09-08_11-19-40_103804.png` (health 100/Momentum 0,
  guard 100), opened and verified. The review window is left open.

Fresh checks pass: import/editor and default startup; default/candidate mechanics
200/202; attacks 352; transitions 67; lower-leg stance 365; alignment 10;
full-cycle leg tracking six cases; 30/60 Hz locomotion and foot-support checks;
full-mesh action deformation 21,642 checks over all 51,170 imported references.
The new stance gate checks all 90 frames with signed ordering and a 0.20–0.29
authored-unit calf/ankle envelope. The full-cycle fixture independently checks
anatomy-scaled lanes at all body sizes and both rates.

## Remaining limits and next bar

This is a narrower, straighter gait, not final animation polish. The source has
a straight/parallel airborne pose, some stance-foot sliding, and wider crouch/
combat transitions that may merit a separate timing/contact pass. Do not widen
the ankle lanes merely to separate silhouettes in one oblique camera frame.
User-held movement and gameplay-scale judgement remain the release bar.

Geometry, joints and surfaces are unchanged. Normal-reel CPU render averages
were 2.41 ms before and 2.35 ms after; movie encoding dominates wall time, so this
is only a sanity observation, not a new paired performance certificate. The
previous quiet 1080p R14/V1 benchmark remains historical evidence; it was not
rerun after this solver change. No new performance ceiling is claimed.

The local board's source and wrapper are refreshed. Static structure/script/
wrapper checks are separate from browser interaction/responsive acceptance,
which remains blocked by the already-recorded browser URL policy.
