# R7 strike, evade, and takedown motion audit

Date: 2026-09-05

Scope: read-only audit of the exact R7 candidate on frozen GLB SHA
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
V1 remains default. This report does not accept or release R7 and does not
change gameplay timing, damage, travel, collision, the GLB, or shared runtime.

## Bottom line

The user's statement that these animations "do not exist" is perceptually
reasonable even though all three states have procedural pose code. There are
no R7-specific skeletal strike, evade, or takedown clips. Non-grounded R7
states still receive the legacy driver-node Euler poses; the expanded adapter
adds finger and toe secondary motion, but it does not replace the main action
with a body-space R7 animation (`gloam_vigil_rig_adapter.gd:216-249,
591-620`). This is materially different from grounded R7 locomotion, which now
uses a captured, body-space retarget (`:494-500`).

The visible evidence supports the user's report:

- **Strike is effectively invisible at the gameplay camera.** In
  `captures/natural-motion-r7-final00000230.png` through `...00000241.png`,
  guard health changes at relative frame 4, but the player's right arm is
  occluded by the guard and never produces a readable fist-leading contact
  silhouette. The clearer studio comparison at
  `captures/gloam-vigil-verified-actions00000248.png` through `...00000260.png`
  exposes the actual result: the arm draws across the chest like a compact
  cover gesture rather than extending toward a target. HP, flash, and guard
  stagger communicate the hit more strongly than the player's body.
- **Evade reads as a high aerial flip.** Frames
  `captures/natural-motion-r7-final00000202.png` through `...00000207.png`
  show the entire body suspended above the floor while rotating, with neither
  shoulder/back contact nor a low forward shoulder path. R7 receives the
  generic action lift and an additional `0.30` visual-height term
  (`character_visual_builder.gd:539, 948-951`), while the whole visual rotates
  around one action pivot (`:969-974`). From a side view this makes the
  direction ambiguous and can read as the backflip the user described. The
  controller does already commit up to 1.96 units along visible facing
  (`main_3d.gd:625-632, 1044-1060`), but the review camera follows the actor and
  visually cancels most of that translation.
- **Takedown exists, but it is not yet a contact-authored pair.** Frames
  `captures/natural-motion-r7-final00000355.png` through `...00000388.png`
  show reach, head/shoulder contact, guard fall, and release. However, the two
  actors use independent procedural curves with no hand/forearm targets. The
  player remains mostly vertical while both hands converge on the helmet, so
  the move initially reads as a front shove. The victim's collapse begins at
  normalized progress `0.24` (0.264 s), before the fixed 0.34 s gameplay
  contact, while the player's pull begins at `0.31` (0.341 s)
  (`character_visual_builder.gd:716-744, 1083-1105`). The temporal causality is
  therefore backwards by up to 76 ms.

## Bounded implementation direction

Keep this as the separate `vigil-authored-motion` pass. Add a narrow R7-only
action layer in the rig adapter (data resource plus sampler), selected only
when `anatomical_profile` is true. Author rotations in the imported skeleton's
body/rest space, following the now-proven gait retarget approach. Do not try to
fix these actions by increasing the old driver Euler amplitudes: that is what
produced the cross-chest strike and does not provide paired contact.

The layer should drive the expanded deform chains deliberately: pelvis,
spine/spine-upper/chest, neck/head, clavicles, upper-arm and forearm twists,
hands/fingers, thigh and shin twists, feet/ball/toes, and restrained cape
follow-through. The player animation must not provide gameplay root motion;
`main_3d.gd` remains authoritative for displacement, facing, damage, and state
duration. Short action clips can be hand-keyed for this character; mocap is not
required, and the takedown will still need target-aware paired constraints.

### Strike: preserve 0.36 s, contact at 0.14 s

Pose phrase:

1. `0.000-0.055`: rear-hip load, compact shoulder coil, off-hand rises to the
   jaw; both soles remain credible.
2. `0.055-0.140`: hip/chest lead the acceleration, punching clavicle
   protracts, elbow follows the fist rather than crossing the sternum.
3. `0.140-0.195`: exact impact plus a short follow-through; guard stagger must
   start on the same gameplay step.
4. `0.195-0.360`: fist recoils through guard position, torso uncoils, feet and
   hands settle into idle or the current locomotion phase.

At contact, the punching fist must be in front of its elbow and shoulder along
the player's facing vector, the off-hand must remain clear of the torso, and a
temporary guard upper-torso contact marker should be within 0.15 m of the
fist. A moving strike must preserve the existing controller policy and still
meet the same contact alignment.

Acceptance frames: 30 Hz relative `0` neutral/start, `2` load, `4` first
post-contact, `6` follow-through, `10-11` recovery; 60 Hz relative `0`, `3`,
`8-9`, `12`, `21-22`. Capture hit, whiff, held/repeated SPACE, and moving hit at
both the default camera and an unobstructed side three-quarter camera.

### Evade: preserve 0.28 s travel and 0.42 s invulnerability

Pose phrase:

1. `0.000-0.050`: lower the center, stagger the feet, bring arms into a safe
   tuck; do not rise into a jump.
2. `0.050-0.120`: head and near shoulder travel forward/down first along
   visible facing; hips follow over the top. This sign is the explicit
   not-a-backflip criterion.
3. `0.120-0.245`: compact shoulder/back roll with boots trailing then passing
   overhead; use the skeleton to shape the tuck rather than rotating a rigid
   standing figure.
4. `0.245-0.310`: feet find the floor as controller travel ends at 0.28 s;
   asymmetric knee/ankle absorption.
5. `0.310-0.420`: facing and action pivot remain stable while the body returns
   to idle or locomotion.

Reduce/remove the R7-only extra aerial lift. During the central roll, maximum
skinned height should not exceed neutral standing height by more than 0.05 m;
grounded/touching geometry must stay above the established -0.03 m floor bar.
At the early launch sample, the head/shoulder must be ahead of the pelvis along
facing and the boots must still trail. At completion, action-pivot rotation is
zero, visible yaw matches launch yaw, and there is no lateral drift.

Acceptance frames: 30 Hz relative `0` load, `1-2` head-forward launch, `4`
shoulder/tuck, `6-7` hips over top, `8-9` travel-end/feet, `12-13` recovered;
60 Hz relative `0`, `3-4`, `8`, `13-14`, `17-18`, `25-26`. Use a static camera
and floor markers for yaw `0`, `+90`, `180`, and `-90` so the existing 1.96 m
unblocked travel is visible. Also cover collision-shortened travel, courtyard
boundary, perch edge, changed camera, held input suppression, damage immunity,
and post-lock recovery.

### Paired takedown: preserve 1.10 s, contact at 0.34 s

Pose phrase:

1. `0.000-0.120`: existing collision-safe approach plus an asymmetric rear
   catch. One hand controls the near shoulder/upper arm; the other secures the
   far shoulder or forearm. Avoid the current symmetric helmet push.
2. `0.120-0.340`: establish contact, step outside the victim's stance, and load
   the player's hips. The victim may brace but must not begin falling.
3. `0.340-0.620`: gameplay contact, player weight transfer, and victim
   off-balance/collapse begin on the same step.
4. `0.620-0.930`: player maintains one visible control point while the victim
   reaches a coherent supported side settle.
5. `0.930-1.100`: release, player recovery, stable victim pose/fade handoff.

Add temporary shoulder/forearm/head markers to the procedural guard fixture.
Through the catch/pull phase, each controlling player hand or forearm should
remain within 0.12 m of its assigned marker without penetrating the helmet or
torso. Victim body rotation must remain below 3 degrees before the 0.34 s
contact step, then change monotonically into the accepted supported fall.
Player soles remain within the -0.03 m floor bar and the final player pose is
finite, upright, and clear of the victim.

Acceptance frames: 30 Hz relative `0`, `3` catch, `9` pre-contact, `10-11`
contact, `15` pull, `21` collapse, `29` settle, `33-34` release; 60 Hz relative
`0`, `6`, `19`, `20-21`, `29`, `41`, `58`, `66-67`. Capture both a paired close
view and the ordinary seven-tap stealth route; helper positioning alone is not
acceptance. Verify front/non-concealed/range/height/lintel rejection and reset
during pre-contact and post-contact phases.

## Required regression and evidence

- Run default V1 and explicit R7 mechanics, focused transitions, rig/runtime
  contract, and complete 30/60 Hz deformation suites. Existing numeric
  contracts remain authoritative: strike `22 + 8% Momentum`, +13; takedown
  +35/defeat; evade +4, 7 units/s for 0.28 s, 0.42 s invulnerability.
- Add R7 action tests that sample named bone/marker positions, not only driver
  angles: fist order/contact gap, evade launch direction/max height/travel,
  takedown pre-contact victim stability/control gaps, action-end identity, and
  finite transforms for small/medium/large at 30/60 Hz.
- Normal-renderer evidence needs dense sequences at native timing, plus a
  half-speed diagnostic that is explicitly labeled non-gameplay timing. Review
  every listed acceptance frame for silhouette, floor, cape, and paired contact.
- Finish with ordinary keyboard play in the exact-title DEBUG build: hit,
  whiff, forward evade in multiple headings, seven-tap takedown, reset, camera
  change, F12, and a fresh handoff. This is internal evidence, not user
  acceptance; R7 and its action task remain Waiting until native re-review.

