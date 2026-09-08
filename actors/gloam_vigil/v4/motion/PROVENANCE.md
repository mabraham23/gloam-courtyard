# R7 captured gait provenance

Status: candidate-only motion reference. The accepted V1 character remains the
project default until the exact R7 build receives user approval.

## Source and permission

- Motion: Carnegie Mellon University Graphics Lab Motion Capture Database,
  subject 16, trial 31 (walk) and trial 45 (run/jog).
- Official database: <https://mocap.cs.cmu.edu/>
- Official subject 16 catalog: <https://mocap.cs.cmu.edu/search.php?subjectnumber=16>
- Official run category: <https://mocap.cs.cmu.edu/search.php?maincat=3&subcat=1>
- Local interchange files: `cmu_16_31_walk.bvh` and
  `cmu_16_45_run_jog.bvh`, from Bruce Hahne's 2010 MotionBuilder-friendly BVH
  conversion of the original CMU ASF/AMC data.
- Permission: the accompanying `CMU_READMEFIRST.txt` records that CMU permits
  research and commercial use worldwide and that the BVH conversion adds no
  further restriction. It also records the requested acknowledgment:
  "The data used in this project was obtained from mocap.cs.cmu.edu. The
  database was created with funding from NSF EIA-0196217."
- Finger and thumb motion is intentionally not sourced from these captures; the
  CMU data did not capture those joints. R7 retains its existing relaxed hand
  profiles.

## Frozen inputs and generated output

| Artifact | SHA-256 |
| --- | --- |
| Frozen R7 GLB | `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a` |
| CMU 16_31 walk BVH | `a655ee2e91ee516ccd91523f1537276e39e0b0abaa5cfc7f531c4f2f567d5088` |
| Generated walk runtime JSON | `9991be7a95615312d98a0b0d7468529177425214484d9c42efdb37ee67ba29a7` |
| CMU 16_45 BVH | `6c179f799f3b2f766ce41cf962caaae08d9342ce73fc32fbc15648bf6589e872` |
| CMU conversion readme | `8e6fe2e640b3728ef2e43e722cb5ae9cdf0010028c0517c4226ed165f9037930` |
| Generated run runtime JSON | `d38ee01e6a0622259afa19694528f680b53ad2eb89973a1b11c5ea53a2f11513` |

The walk JSON uses source frames 190–325 at 120 Hz: a 135-frame, 1.125-second
loop resampled to 48 runtime poses. The run JSON uses source frames 7–90: an
83-frame, 0.691667-second loop, also 48 poses. The retarget build
reads both source and target without modifying them, maps by observed spatial
side because the frozen GLB's `.L`/`.R` suffixes are mirrored, compensates for
the BVH T-pose versus the target's lowered arm rest, and removes accumulated
source translation at the seam. The remaining centered `root` values are only
millimeter-scale presentation bob/sway; gameplay translation still comes from
`main_3d.gd` at 1.90 walk or 4.80 run units/second.

Walk target contact windows are L `[0.00, 0.48)` and R `[0.56, 0.94)`; run
windows are L `[0.00, 0.44)` and R `[0.48, 0.94)`. R7 does not
enable the legacy hard foot-lock IK: that solver was rejected after it visibly
overextended the frozen leg chains. Acceptance instead requires zero solver
blocks, support feet moving slower than swing feet, exact gameplay-root speed,
finite transforms, and normal-rendered start/stop/turn/reversal review.

`build_cmu_retarget.py` accepts explicit source/destination/target paths plus
cycle, contact, label and sample-count arguments. Rebuilding the run with its
defaults remains byte-identical; the walk uses the explicit ranges above.
`validate_cmu_retarget.py` verifies both source/data hashes and both contracts.
`cmu_09_11_run.bvh` and `cmu_127_03_run.bvh` remain comparative source evidence;
neither is used at runtime.

## Authored combat-motion reference boundary

The four combat actions in `r7_action_reference.gd` are locally authored
body-space curves; no third-party combat clip or model was downloaded, copied,
or distributed. Their body-mechanics pass was informed by:

- Carnegie Mellon Graphics Lab subject 144's 120 Hz front-kick, left-front-kick,
  punch-sequence and left-punch-sequence catalog entries:
  <https://mocap.cs.cmu.edu/search.php?subjectnumber=144>.
- Animation Mentor's body-mechanics guidance on readable force, weight transfer,
  lead/follow sequencing and recovery:
  <https://www.animationmentor.com/blog/animation-tips-tricks-what-makes-or-breaks-a-good-body-mechanics-shot/>.
- A visually inspected Endless Reference slow-motion female punch preview for
  rear-heel pivot, pelvis/chest sequencing, opposite-hand guard and balanced
  recoil: <https://www.youtube.com/watch?v=_FKqT6J07sw>.

Those references inform timing and mechanics only. The runtime curves, exact
target-rig rotations, contextual selector, contact ownership and recovery
policy are project-authored. The CMU subject 144 clips were catalog research,
not runtime inputs; only the two gait files and generated JSON hashed above are
bundled motion data.
