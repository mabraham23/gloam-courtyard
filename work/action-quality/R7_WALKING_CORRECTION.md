# R7 captured-gait correction

Date: 2026-09-05

Status: **Internally reviewed; waiting for native user review.** The user
rejected the original scaffold, the broad procedural correction, and the later
thirteen-pose correction as still unnatural. Those reels remain rejected
evidence. This pass does not convert deterministic/rendered evidence into user
acceptance, and V1 remains the default.

Exact frozen R7 GLB SHA:
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
The model, weights, appearance, gameplay speed, collision, damage, Momentum,
action travel and action timings are unchanged.

## Reproduced causes

- The five-pose scaffold and thirteen-pose replacement were procedural
  approximations. Both could satisfy knee-angle checks while still putting
  weight transfer and leg recovery at visibly wrong times.
- The first retarget attempt used an incorrect facing basis, then an inherited
  hard foot-lock interval that traveled farther than the frozen leg chains
  could reach. This produced the rejected backward posture, kicks, and solver
  blocks.
- Applying a T-pose rotation delta to the target's already lowered rest arms
  rotated them down twice and crossed the hands at shoulder height.
- The old 390-frame evidence path reached the world clamp and its reversal was
  partly hidden by foreground architecture. It is not current acceptance
  evidence.

## Current correction

- R7 now samples CMU Graphics Lab subject 16 trial 45, a licensed captured
  run/jog. Source frames 7–90 form an 83-frame cycle at 120 Hz (0.691667 s),
  resampled to 48 compact runtime poses. Exact provenance and permission are in
  `actors/gloam_vigil/v4/motion/PROVENANCE.md`.
- Retargeting derives source forward from measured travel and target forward
  from the face/eye direction. It maps limbs by spatial side because the frozen
  target's `.L`/`.R` suffixes are mirrored, and retargets arm direction in
  global space to bridge the BVH T-pose and the target's relaxed arm rest.
- Captured motion is distributed through clavicle, upper-arm/forearm twist,
  thigh/shin twist and toe chains. Fingers keep the existing relaxed profiles
  because the CMU source did not capture finger motion.
- Cadence comes from the source metadata (`9.084123` rad/s) at the unchanged
  4.8-unit/s controller speed. The gait is therefore labeled tactical run/jog,
  not walk.
- The gameplay root remains authoritative. Only centered millimeter-scale
  presentation bob/sway is sampled from the motion; source forward translation
  is removed at the loop seam.
- R7 begins a genuine idle-to-move transition at captured contact and stops
  from actual per-frame displacement instead of the legacy 0.16-second movement
  latch. V1/V2 timing is unchanged.
- The legacy hard foot-lock solver is disabled only for R7. A bounded soft-IK
  experiment barely reduced support speed and reintroduced reach blocks, so it
  was rejected rather than hidden behind a generous threshold.

## Measured result

| Metric | 30 Hz | 60 Hz |
| --- | ---: | ---: |
| Actual mean gameplay speed | 4.799997 | 4.800000 |
| Idle-to-move start phase | 0.144 rad | 0.046 rad |
| Stop-to-neutral settle | 2 frames | 4 frames |
| Left knee range | 6.84–99.81 deg | 6.84–100.15 deg |
| Right knee range | 6.91–93.14 deg | 6.91–93.17 deg |
| Left support / swing foot mean speed | 4.056 / 7.784 | 4.165 / 8.107 |
| Right support / swing foot mean speed | 2.683 / 8.734 | 2.460 / 8.706 |
| Hard-plant active / blocked frames | 0 / 0 | 0 / 0 |

The direct builder fixture independently reports support/swing means of
2.50/7.01 and 2.89/6.92 at 30 Hz, and 2.37/7.11 and 2.79/6.99 at 60 Hz, with
zero hard plants or blocks. These figures show a support/swing distinction;
they do not claim perfectly stationary feet or production foot IK.

The retarget validator confirms 48 samples, 24 required rotation channels,
finite normalized quaternions, exact source/target/data hashes, centered root
and a 0.007121-unit maximum presentation-root radius. Two clean Blender builds
are byte-identical with checked JSON SHA
`d38ee01e6a0622259afa19694528f680b53ad2eb89973a1b11c5ea53a2f11513`.

## Rendered review

`captures/r7-gait-cmu-final00000000.png` through `...00000341.png` is a
342-frame, 960x600, 30 Hz normal-render sequence using the actual controller:

- 0–23: profile idle before input;
- 24–77: profile start and sustained captured gait;
- 78–101: release and settle;
- 102–149: sustained input at the actual default camera;
- 150–173: default-camera release and settle;
- 174–197: three-quarter held input;
- 198–221: 90-degree direction change;
- 222–245: settle;
- 246–269: reversal outbound;
- 270–317: 180-degree return;
- 318–341: final settle.

The fixture asserts every frame remains inside world clamps and outside the low
passage/vault blocker. A fixed observer side keeps the 180-degree turn visible.
Consecutive start, stop, turn and reversal strips were reviewed for kick/prance,
hyperextension, backward lean, phase reset, pose pop, arm crossing, floor
penetration, cape/body collision and obstructed framing. No release-blocking
defect was observed. The render reported 3.09 ms mean CPU render time; movie
capture timing is visual evidence, not a performance claim.

## Regression result

- editor/import parse: exit 0;
- source/retarget validation and two-build determinism: pass;
- 30/60 Hz actual-controller locomotion diagnostic: pass;
- 30/60 Hz support-foot contract: pass;
- runtime articulation/bind recovery: pass;
- rig: 451/451;
- focused transitions: 67/67;
- default mechanics: 196/196;
- exact-R7 mechanics: 198/198;
- full R7 deformation: 17,652/17,652.

Normal macOS Godot log/certificate/editor-settings warnings are environmental
and remain separate from the zero-exit script results.

## Acceptance boundary

The next gait check is sustained ordinary-input movement in a freshly launched
exact R7 review window. Judge continuous stride, stop, turn, reversal, profile
and default-camera feel—not a selected still. User acceptance and a new paired
1080p performance result are still required before promoting R7. The separately
authorized strike/evade/takedown animation pass may proceed as its own review
phase, but it does not silently accept this gait or switch the default.
