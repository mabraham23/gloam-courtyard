# V4 face/neck weight review

Status: **R5 passes the bounded face/neck LBS and approved-shape review.** R4
passed its bounds and edge gates but was visually rejected because crouch
elongated the chin into a cone. This remains source-deformation evidence, not by
itself Godot runtime acceptance.

## Frozen inputs and outputs

| Revision | Blender source SHA-256 | GLB SHA-256 |
| --- | --- | --- |
| R3 before repair | `b4f30bf91a41ff74170a523d8505b82a9e1709df7a67e25db093b28b61240956` | `242104fcc347652f4d3e83c2da779282b9a2ff76bb4c5ffc943caf6ca09f986e` |
| R4 edge repair, visual negative control | `2211cbb93fc6a16d229994eeb4f7d62bc68ce1f7e4f0bd534ab7f2ddde067c7c` | `ea4f64e4919640f53099dd8876170adb401b9b6e9e272abdcd692dff061723ef` |
| R5 corrected lower-face shape | `b7eb3ebcc28271770a80a792767ae6aed7f678211175ce99fd66b95fea12123f` | `d4ae722cd39d1d2897f1d177b10f2410ce264c540839bb686a38b6ddc70c9b00` |

The repaired `actors/gloam_vigil/v4/face_finish.py` SHA-256 is
`f1cdf87052f56d386210fd1cbe27cf3db77ceb69820cf0321905cf301be32eac`.
The change is weight-only: neutral geometry, topology, materials, vertex colors,
eye treatment, four morph targets and their deltas are unchanged.

## Cause and bounded repair

R3 used mutually exclusive branches at the lower face: vertices with
`jaw > 0.05` retained `head + jaw` and dropped `neck`, while an adjacent vertex
could retain `head + neck` and drop `jaw`. The branch split neighboring vertices
between materially different bone sets.

R4 used one continuous normalized field with at most three influences. Its
120 mm Z-only collar-to-mandible field removed the branch tear, but it also
assigned substantial neck weight through the projecting chin and cheeks. The
edge metrics passed while the crouched lower face visibly stretched.

R5 keeps the continuous normalized three-way mix but separates the projecting
mandible from the true throat/back of neck with a forward/lateral anatomical
support field relaxed across the real scan topology. `Jaw` still draws only
from the available head share. The lower face follows neutral `head`/`jaw`
motion, the throat retains a smooth neck transition, and the collar cut remains
exactly `neck: 1.0`.

## Facial-shape regression

The R4 crouch is the required negative control. Relative to a rigid-head
reference with neutral jaw, its chin-bottom error was `0.052225536` m. The
nose-tip-to-chin distance became `1.367861x` its rest length, and the
lower-lip-to-chin distance became `1.558053x`. These changes match the rejected
elongated/conical chin visible in `r4-posed/r4-crouch-neck-close.png` despite
the passing edge table below.

In the corrected R5 field, chin-bottom and lower-lip rigid-head error measured
zero; chin-front error was `1.192092896e-07` m and each lateral-jaw error was
`5.960464478e-08` m. Nose-tip-to-chin was `0.999999799x` its rest length and
lower-lip-to-chin was `0.999999066x`. The same-camera crouch image preserves the
approved jaw/lip silhouette. The pre-master numerical/image proof is
`work/character-art-v4-rig/face-weight-draft-r1/report.json`; the exact R5
master replay is `work/character-art-v4-rig/r5-posed/source_pose_review.json`.

## Exact internal-face edge evidence

All distances are linear-blend-skinning world-space measurements in metres.
Blender preserve-volume deformation was disabled. Pose samples match the
durable action samples: crouch at progress 1.0, grapple at 15/29, and strike at
13/29.

| Pose and source edge | R3 rest -> posed (ratio) | R4 rest -> posed (ratio) |
| --- | --- | --- |
| Crouch `[8852, 3149]` | 0.003420155 -> 0.038982519 (`11.397882x`) | 0.003420195 -> 0.003426543 (`1.001856x`) |
| Crouch `[982, 7531]` | 0.004768987 -> 0.040651011 (`8.524035x`) | 0.004769087 -> 0.006556913 (`1.374878x`) |
| Grapple `[1034, 8866]` | 0.003435094 -> 0.008377019 (`2.438658x`) | 0.003435129 -> 0.003415242 (`0.994211x`) |
| Strike `[2682, 5026]` | 0.003387690 -> 0.006955194 (`2.053079x`) | 0.003387735 -> 0.003430348 (`1.012579x`) |

Across all 50,653 face edges in R4, the worst ratios were `2.133854x` in
crouch (a 2.250 mm rest edge became 4.800 mm), `1.046460x` in grapple and
`1.126738x` in strike. The longest stretched crouch edge was 9.530 mm at rest
and 14.488 mm posed (`1.520265x`). R4 reports no edge over ratio 6 and no tether
edge in any of the three poses.

The corrected pre-master R5 proof retained zero ratio-over-6 edges and zero
tether edges. Its crouch worst ratio was `2.005787x` (3.970 mm rest to 7.962 mm
posed), and its longest stretched crouch edge was `1.810734x` (8.107 mm to
14.680 mm). Facial-shape preservation, not merely the passing edge bound, is
the decisive improvement over R4.

## Bind recovery and cut-ring evidence

- Reassigning the new weights in memory on the frozen R3 face recovered the
  zero pose within `2.3889104820542146e-07` m (0.239 micrometres). Reapplying the
  same function to the already-repaired exact R4 source produced zero measured
  change.
- The face-only proof selected 138 vertices at `z <= 1.825001`; every selected
  vertex was exactly `neck: 1.0`, and the maximum face influence count was 3.
- R3 also had a separate body-side cut-ring mismatch. One coincident pair was
  face `neck: 1.0` versus body `neck: 0.850930`, `upper_arm.R: 0.103656`,
  `clavicle.R: 0.045414`; maximum separation reached 20.724 mm in grapple,
  16.212 mm in strike and 3.233 mm in crouch.
- The R4 rig validation compares 142 body cut-ring vertices with coincident
  virtual `neck: 1.0` face vertices. Maximum separation is now
  `1.309692549053352e-07` m in grapple, `1.2457462107543622e-07` m in strike and
  `1.3328003749250113e-07` m in crouch.

Durable replay evidence is in
`work/character-art-v4-rig/r3-posed/source_pose_review.json`,
`work/character-art-v4-rig/r3-posed/source_pose_review_findings.json`,
`work/character-art-v4-rig/r4-posed/source_pose_review.json`,
`work/character-art-v4-rig/face-weight-draft-r1/report.json`,
`work/character-art-v4-rig/r5-posed/source_pose_review.json`, and
`work/character-art-v4-rig/rig_validation.json`.
