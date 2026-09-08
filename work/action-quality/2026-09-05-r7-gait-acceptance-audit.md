# R7 gait acceptance audit after the third native rejection

Date: 2026-09-05

Status: read-only acceptance audit. The frozen R7 appearance remains at GLB
SHA `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
V1 remains the default. The third user rejection supersedes every statement
that the thirteen-pose gait is merely awaiting re-review; that gait and
`captures/r7-walking-final-review*.png` are now rejected evidence.

This audit does not accept the in-progress CMU retarget. It identifies the
minimum honest evidence path for whatever gait implementation survives visual
review.

## Current acceptance defects

### The focused reel is not collision-free

`walking_sequence.gd` starts at `(-3, 0, 3)`, holds `D` for 90 frames at
30 Hz, and labels the whole interval sustained gait. A headless replay of the
current script produced this actual root trace:

| Frame | Root x | Root z | Observation |
| ---: | ---: | ---: | --- |
| 0 | -2.8766 | 2.8982 | Default-camera D motion begins. |
| 60 | 4.5274 | -3.2126 | Still unobstructed, but the close view is already visually cluttered. |
| 75 | 6.3783 | -4.7403 | Approaching the world boundary. |
| 90 | 8.1059 | -5.2000 | Z has hit the exact `move_player_world()` clamp. |

The clamp is reached at roughly frame 81. The last roughly nine held frames
therefore slide along the boundary at only the X component of the requested
4.8-unit/s speed. That is not an honest steady-gait sample. The path does not
hit the low-passage or vault-obstacle blocker and the guard is moved away, so
the contaminant is specifically the world clamp, not guard separation.

The camera override happens after `game._process()`. On the next step,
`update_camera()` restores the controller camera before `move_player()`. As a
result, the actor follows the default-camera diagonal in every segment even
when the rendered caption says profile or three-quarter. This does not create
a one-frame steering discontinuity, but it means the claimed profile view is
not perpendicular to actual travel and the custom view does not exercise
changed-camera input.

Selected old and in-progress frames also put large perch/exit geometry and
world labels across the character. `r7-walking-mocap-b` contains only 120
frames, and its later profile frames are substantially obscured. It is useful
diagnostic evidence only, not a review reel.

### The two gait diagnostics encode the rejected curve

`work/action-quality/locomotion_diagnostic.gd` reports phase rate `9.6` and
classifies support using hard-coded `L 0.25-0.40` / `R 0.75-0.90` windows.
`work/character-art-review/foot_plant_review.gd` advances the same hard-coded
rate and uses the same windows. Neither suite can validate the current CMU
reference, whose generated metadata currently says a 0.691667-second cycle and
`R 0.00-0.44` / `L 0.48-0.94` contact windows.

Passing the old knee-flex thresholds would repeat the exact mistake exposed by
the user: a numerically articulated gait can still look temporally wrong. Knee
range and finite transforms must remain regression guardrails, not the visual
acceptance criterion.

### The words `walk` and `4.8 m/s` describe different motion

At the unchanged controller speed, one current CMU cycle moves the gameplay
root about `4.8 * 0.691667 = 3.32` world units, or about 1.66 units per step.
If world units are described as metres, this is a run/jog, not a natural walk.
The evidence captions should say `gait`, `locomotion`, or `tactical run/jog`.
Calling it walking encourages the wrong visual expectation. Reducing gameplay
speed would be a separate mechanic decision and is not authorized by this pass.

## Clean repeatable review sequence

Use the exact candidate and real `game._process()` controller path at 30 Hz.
Move the guard to `(30, 0, 30)` and hide only the guard presentation as the old
fixture does. Keep world collision active. Before each movement interval call
`reset_game()`, restore the chosen start, and configure the controller camera
before the first processed frame. Print the requested displacement and actual
displacement every frame and fail the fixture if they diverge by more than the
normal integration tolerance.

The following paths stay clear of the low passage, vault obstacle, guard, and
world clamps under the current default-camera basis:

| Segment | Frames | Start | Input | Expected end, approximately | Purpose |
| --- | ---: | --- | --- | --- | --- |
| Profile baseline | 24 idle + 54 held + 24 stop | `(-6, 0, 4.8)` | `D` | `(0.66, 0, -0.70)` | Clean start, 2.6 source cycles, support/swing, release and settle. |
| Actual default camera | 48 held + 24 stop | `(-4, 0, 3.6)` | `D` | `(1.92, 0, -1.29)` | Unmodified gameplay composition and HUD readability. |
| 90-degree change | 24 + 24 + 24 stop | `(-4, 0, -1)` | `D`, then `W` | `(1.41, 0, -0.48)` | Facing recovery, planted-foot release, pelvis and cape continuity. |
| 180-degree reversal | 24 + 48 + 24 stop | `(-1, 0, -1)` | `D`, then `A` | `(-3.96, 0, 1.44)` | Reversal without foot yank, phase restart, or root overshoot. |

Total: 342 frames / 11.4 seconds at 30 Hz. The fixture should assert every
actual root remains at least 0.25 units inside the world clamp and outside the
low-passage/vault blocker regions. Do not infer collision freedom merely from
the chosen coordinates.

For the profile view, derive the horizontal camera offset from actual travel:
`side = Vector3(-travel.z, 0, travel.x).normalized()`. This makes the view truly
perpendicular to the character's trajectory. Track the actor with that offset
after controller stepping. A 5.0-5.5 orthographic size should preserve head,
feet, cape and ground contact. A close diagnostic version may hide `Label3D`
world annotations if that is disclosed; pair it with the unchanged default-
camera segment so the clean view is not mistaken for ordinary gameplay.

For changed-camera movement acceptance, add a separate segment that sets
`camera_yaw` before processing and lets `update_camera()` own both input basis
and render. A post-process review-camera override does not test camera-relative
movement.

Record a shorter 60 Hz version of the sustained/start/stop segment as well.
The 30 Hz sequence is the main human-readable reel; 60 Hz is a cadence and
contact regression, not a duplicate long showcase.

## Required deterministic gates

### Source and retarget integrity

1. Record the selected motion source, official license statement, source URL,
   exact BVH SHA, selected source frames, source FPS, cycle duration, contact
   derivation, retarget script SHA, generated JSON SHA, and frozen target GLB
   SHA in a motion provenance file. The existing V4 `PROVENANCE.md` only covers
   the anatomical foundation.
2. Generate the runtime JSON twice to temporary destinations and require exact
   byte/hash equality with the checked result.
3. Validate the JSON schema, 48 samples, finite normalized quaternions, required
   mapped joints, absence of gameplay-root translation channels, and a measured
   loop-seam angular/positional bound. The source-to-target axis bases and their
   determinants should be logged so a reflected forward axis cannot pass
   silently.
4. Recheck that the BVH/JSON build did not change the frozen GLB or its weights.

### Real controller locomotion

Update `locomotion_diagnostic.gd` so that the live reference supplies cadence
and contact windows; remove the rejected `9.6` and old support intervals. Run
at both 30 and 60 Hz, not only 60. Its report should include:

- exact asset, source-motion and generated-JSON SHAs;
- commanded versus actual root speed/displacement, with explicit collision-
  free assertions;
- movement-blend and phase traces from idle through start, held movement, stop,
  restart, 90-degree turn and 180-degree reversal;
- pelvis, chest and head world trajectories plus their largest frame-to-frame
  angular/vertical changes;
- hip/knee/ankle/ball/toe trajectories for both feet;
- support-window foot speed and height versus swing-window values;
- hard/soft plant activation, weights, release frames and blocked frames;
- root X/Z tilt, imported-root transform and recovery to the exact bind state.

The gait must begin from a deterministic real contact only once per genuine
idle-to-move transition. It must not reset phase during uninterrupted movement,
turns or ordinary direction changes. A stop must not display a full run pose
after actual root speed becomes zero; report the root-stop-to-pose-settle delay
explicitly rather than hiding it inside the 0.16-second latch.

Update `foot_plant_review.gd` to use the same live cadence/contact metadata.
If the final R7 retarget intentionally disables the old hard IK, do not retain
an `active_frames >= 72%` assertion that can only pass the deleted behavior.
Instead measure ankle, ball and toe world velocity/height through the captured
support windows and assert zero blocked/teleport residue. Derive any drift bar
from reviewed motion plus the preserved before case; do not choose a generous
threshold after seeing a failure.

Add locomotion transitions to the exact-R7 transition suite at 30/60 Hz:
idle-to-held, held-to-stop, stop-to-restart, 90-degree change, 180-degree
reversal, and changed-camera travel. Preserve existing action transition checks.

Rerun the full deformation suite on all three body presets. Its existing
grounded samples protect mesh/floor integrity but do not accept temporal gait;
add focused sequential grounded samples if the new retarget reaches poses not
covered by the current phase sampling.

### Rendered and native acceptance

Before asking the user again, review consecutive frame strips, not only spaced
stills. Reject internally for any of the following:

- kick/prance silhouette, knee hyperextension, backward whole-body lean, or
  cadence inconsistent with the unchanged 4.8-unit/s run;
- contact foot skating, floating or floor penetration; missing heel-to-toe
  rollover; planted-knee snapping caused by IK reach correction;
- head/pelvis bob spikes, loop seam, start pop, post-stop running, turn foot
  yank, or reversal phase reset;
- arm/cape intersection, both limbs swinging on the same side, hand noise from
  the source endpoints, or lost R7 bind recovery;
- foreground world geometry or HUD/Label3D text preventing assessment.

The clean reel and green scripts are still not user acceptance. Relaunch the
exact updated build, confirm `Gloam Courtyard Spike (DEBUG)`, and let the user
hold ordinary WASD at the default and one changed camera. Capture a fresh F12
frame for handoff, while treating the user's continuous play judgement as the
gait gate. Only after this gait is accepted should the deferred vault, grapple,
counter, takedown and exit native smoke resume.

Because the runtime now samples a new JSON/quaternion path every grounded R7
frame, the earlier R7/V1 performance pair predates the final gait. Repeat the
same quiet paired 1080p protocol after the implementation stabilizes and before
promotion.

## Exact status/document updates

Until a new reel has passed internal review:

- `PROJECT_STATE.md`: say the thirteen-pose correction received a third native
  rejection; the licensed retarget is in progress and unaccepted.
- `UPCOMING_TASKS.md`: keep one `vigil-authored-motion` task, make it active/Now
  while integration is running, and list the clean reel plus updated temporal
  gates as its immediate acceptance. Do not describe the rejected thirteen-pose
  gait as implemented current truth.
- `CHECKPOINTS.md`: prepend a new rejection/in-progress checkpoint. Preserve the
  second-rejection correction below it as rejected historical evidence.
- `R7_WALKING_CORRECTION.md`: mark it superseded by the third user rejection;
  keep its measurements as the rejected before case.
- `coverage.md`: update only its post-pass disposition/current status; keep the
  pinned pre-change audit historical.
- `DECISIONS.md`: if the CMU retarget is retained, append an Active decision for
  a provenance-recorded licensed motion reference limited to animation data.
  Do not rewrite older decisions.
- `work/project-roadmap.html`: change health/header/phase 6 and the single
  `vigil-authored-motion` card. Use lane `now` while implementation is active,
  then `waiting` only when a reviewed exact-build handoff is genuinely ready
  for the user. Mark the old 390-frame reel rejected, not current evidence.
- `vigil-performance`: mark the previous pair as a baseline that must be rerun
  after the new runtime sampling path stabilizes.

After accepted evidence is recorded in the authoritative docs, regenerate
`work/project-roadmap-local.html`. Recheck one `vigil-authored-motion` task,
unique task/DOM IDs, JavaScript syntax and exact source/wrapper parity. The
recorded local-URL policy still prevents claiming actual board interaction or
responsive-layout acceptance; do not relabel static checks as UI verification.

## Honest completion state

The focused gait may move from Now to Waiting only after the new source and
runtime hashes, updated 30/60 Hz controller/contact gates, collision-free
rendered sequence, internal consecutive-frame review, and fresh exact-title
playtest handoff exist. It becomes Complete only after the user accepts the
continuous gait and the deferred exact-R7 action/native/default/performance
release gates also pass. R7 appearance approval alone is not motion approval.

## Parent resolution after audit

The parent integration pass resolved the audit's immediate evidence defects:

- CMU/BVH permission, attribution, exact source/target/data hashes and the
  target-only retarget boundary are recorded in
  `actors/gloam_vigil/v4/motion/PROVENANCE.md`.
- Two fresh Blender builds are byte-identical to the checked JSON. The validator
  passes 48 samples, 24 required channels, finite normalized quaternions,
  centered millimeter-scale presentation root and frozen target SHA.
- Both locomotion diagnostics now read cadence/contact from the runtime resource,
  run at 30/60 Hz, assert zero hard-IK blocks and compare support/swing velocity.
- `walking_sequence.gd` now emits a collision-asserted 342-frame review at
  `captures/r7-gait-cmu-final*.png`; the 180-degree reversal was relocated and
  the observer side fixed so the actor remains unobstructed.
- Dense consecutive start/stop/turn/reversal review found no release-blocking
  kick, hyperextension, backward lean, arm crossing, floor penetration, phase
  reset or post-stop run. Full mechanics, transition, runtime and deformation
  regressions pass.

This resolution is internal evidence only. The gait remains Waiting for native
user review and post-retarget paired performance; V1 remains default.
