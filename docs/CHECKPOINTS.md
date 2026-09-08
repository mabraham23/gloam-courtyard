# Checkpoints

## Waiting — R14 appearance and action candidate technically accepted (2026-09-08)

The user requested the highest feasible real-time character detail, especially
in the face, hair, beard, joint count and natural movement, plus distinct hit,
evade and takedown animation. The bounded R14 candidate is frozen at GLB SHA
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`;
the source blend SHA is
`14e162eb70b59b83bfdcb1cccf2934fd9f0c6bf6fbc90ee6ace108460ed50c29`.
The active GLB/source/manifest exactly match `revisions/r14`. R12 remains an
archived rejection.

R14 contains 86,452 triangles, 34,998 face triangles, 43,757 authoring
vertices, 49,315 exported GLB references, 51,170 Godot-imported skinned
references, 74 joints/73 used, seven surfaces, five materials and four facial
morphs. It uses warmer light skin, a clear mouth, connected dark beard/mustache,
a single swept dark hair mass, fitted original costume and the established
continuous anatomical weighting. Five final Blender views are in
`actors/gloam_vigil/v4/renders/r14`; matched Godot-import views are under
`captures/r14-import-*`. The model is visibly less blocky than V1 and removes
R12's headband/chip geometry, but close-up hair/beard still read as stylized
procedural surfaces rather than strand grooming. This remains Waiting for user
visual judgement and is not called semi-professional or production-ready.

Exact current tests pass: GLB contract (zero errors/warnings), 37 imported LOD
index buffers, rig `451/451`, runtime recovery, default mechanics `200/200`,
candidate mechanics `202/202`, target-independent strike `254/254`, four-attack
`352/352`, action motion `198/198`, transitions `67/67`, locomotion alignment
`10/10`, lower-leg stance `13/13`, both-rate locomotion/foot planting, retarget
validation, and full deformation `21,642/21,642`. The latter evaluates all
51,170 imported skinned references through every action, three body sizes and
30/60 Hz; crouch clears the 2.0-unit lintel and the unchanged floor tolerance.
The headless editor/runtime certificate, editor-settings and `user://` log
messages are known macOS sandbox noise, not script or gameplay failures.

The corrected 277-frame normal-renderer reel at
`captures/r14-action-motion-fist-final00000000.png` through `...00000276.png`
covers paired strike, the facing-forward over-top evade and paired takedown.
The reel explicitly faces its paired strike target under the new target-
independent input policy and passes without script errors. Reviewed frames show
anticipation/contact/recovery, a tucked forward somersault over 1.96 units, and
a takedown that holds the victim until 0.34-second contact before a connected
floor fall. Punch recovery now retains the active compact hand until 86% of the
action; new checks measure all active long-finger phalanges and distal-row
closure at contact and recovery. This removes the misleading late open-hand
read without increasing the source-tested curl into known loop/intersection
failure. The straight-finger source topology still leaves separated fingertips
in close-up and is an explicit visual limitation.

The 179-frame normal-render target-free reel at
`captures/r14-target-independent-strike00000000.png` through `...00000179.png`
proves empty-space, one-slot buffered follow-up and post-defeat presentation.
Every segment preserves the player root, owns no target, applies no phantom
damage and retains the protected Momentum result. The unobstructed matched
front gait frames at `captures/r14-gait-alignment-final00000090.png` through
`...00000179.png` show the narrower idle, sustained 4.80-unit/s run and release.
Native current-code `space` produced a target-free whiff without
guard damage; native `C` completed at +4 Momentum. The live pass also caught
and fixed a stale message: crouch already traveled at 1.178 units/s, but the
message still advertised the superseded 62% ratio. It now prints the exact
absolute speed; default/candidate mechanics, locomotion and strike suites pass
after that change.

Final native handoff: the sole acquired window has exact title
`Gloam Courtyard Spike (DEBUG)` and runs the exact R14 candidate as PID `28090`.
Native `space`, `C`, `Q`, reset and `F12` were exercised in screenshot/action/
screenshot rhythm. The target-free whiff kept guard health unchanged; evade
finished with +4 Momentum; crouch reported `1.178 units/s`; reset restored
health 100, Momentum 0 and guard 100. Fresh project-local capture
`captures/courtyard_3d_2026-09-08_10-56-51_86082.png` was opened and verified.
The window remains ready for user play. Computer control cannot synthesize the
held movement needed for an honest native takedown route, so that user gate
remains Waiting rather than being replaced by the deterministic paired reel.

The paired 1920x1080 benchmark passes every configuration/sample gate. R14
versus V1 actual-courtyard mean/p95/p99 wall time is
`5.0999/6.7529/7.1777` versus `5.0924/6.6360/7.1421` ms (+0.15% mean), with
about 196 observed FPS for both. The artificial nine-visual-rig case is
`18.5597/21.9153/24.8500` versus `17.5528/20.2122/20.9001` ms. GPU timing is
unavailable; the stress fixture is not nine enemy AIs and reciprocal cadence
is not a GPU ceiling. Full report:
`work/character-art-review/reports/2026-09-08-r14-appearance-action-performance.md`.
V1 remains default until user appearance/motion judgement, a native takedown
review and the narrow default-switch regression.

## Waiting — R7 one-speed captured run internally accepted (2026-09-08)

The user superseded the separate walk/run choice after review. Standing `WASD`
now always uses the corrected licensed CMU subject 16 trial 45 run/jog at 4.80
units/s; `Shift` has no locomotion effect. Crouch preserves its prior absolute
1.178-unit/s speed. Trial 31 walk data and the 570-frame comparison remain
reproducible superseded evidence, not active controller behavior.

The concrete lateral-knee cause was full captured-quaternion redistribution
across target twist bones with different pivots. Removing that split preserves
the retargeted major-bone endpoints; a uniform `6.195` source/target leg ratio
replaces unrelated pelvis root gains. R7-only refinement retains most run trunk
drive while reducing source neck/head extension. A more adducted, flexed relaxed
finger profile removes the imported fan. The frozen GLB/weights, V1, collision,
actions, damage and Momentum are unchanged.

Fresh results: default mechanics `200/200`, R7 mechanics `202/202`, R7 action
motion `198/198`, transitions `67/67`, and revised locomotion/controller
diagnostics at both 30/60 Hz. Plain, held-Shift and released-Shift travel all
measure 4.800 units/s; crouch measures 1.178. Normalized diagonal, phase
continuity, zero-time tap rejection, world-bound and focus-loss checks pass.
Maximum run knee-plane error is 4.7 cm; support feet remain slower than swing
feet, hard-plant active/blocked counts stay zero, and stops settle in 2/4 frames.

Current normal-render evidence is
`captures/r7-single-speed-final00000000.png` through `...00000209.png` (210
frames, 960×600/30 fps). It drives the real held-input controller through plain
WASD, Shift+WASD and start/stop. Plain and Shift cases each cover exactly
7.199999 units in 45 frames with run pose 1.0; the standing silhouette is the
same corrected captured run in both. Independent dense review found no new
blocking pose defect. The prior 570-frame walk/run reel remains superseded.

The full R7 1920×1080 three-repetition benchmark passes. Actual courtyard
mean/p95/p99 is `5.9551/8.3391/9.2061` ms (167.9 FPS observed); artificial
nine-visual-rig stress is `22.9759/31.7079/34.7766` ms (43.5 FPS observed).
GPU timing is unavailable; the stress fixture is not nine enemy AIs and wall
cadence is not a GPU ceiling. Exact protocol/distributions are in
`work/character-art-review/reports/2026-09-08-separate-walk-run-performance.md`.

The preceding native C/space evidence predates this controller reversal. The
new revision now has a fresh exact-title handoff:
`captures/courtyard_3d_2026-09-08_08-41-17_63850.png` verifies `WASD run`, health
100, Momentum 0, guard 100 and reset objective in the sole acquired R7 DEBUG
window, left open as PID 23261. Computer control cannot synthesize a held-key
interval, so this checkpoint remains **Waiting** for user-held native movement,
position-dependent takedown and visual judgement. It does not release R7; V1
remains default. The derived board must reuse `vigil-authored-motion`.

## Waiting — four-attack contextual combat pass internally accepted (2026-09-07)

The user requested a separate, substantial attack-animation pass with four
natural options rather than a repeated single swing. `main_3d.gd` now selects
right/left straight punches or right/left front kicks using target range and
lateral side plus the preceding move. The choice is semi-random, seedable for
diagnosis, and excludes the previous move whenever another reach-valid choice
exists. Punches use 2.20-unit reach; kicks use 2.38. Their individual duration
and contact beats live in `actors/player_attack_catalog.gd`.

Controller ownership is explicit. A target is acquired once at commit and
revalidated at contact; out-of-range, late-entry, vault-blocked, different-level,
perched, airborne, behind-facing and cross-behind cases cannot gain or retain a
hit. One non-stacking press may buffer
only in the final 0.10 seconds after a connected contact. Whiff, target loss,
interruption and reset clear contact, buffer and combo history. Held locomotion
cannot move the player root during a live strike. Existing 22 damage plus
Momentum scaling, +13 connected Momentum and -8 whiff cost are unchanged.

The exact frozen R7 SHA remains
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
Its four locally authored body-space moves use mirrored centerline punches,
compact source-tested fist/guard profiles, pelvis/chest/heel sequencing and
knee-led front kicks over a loaded support foot. The active punch hand stays at
least 0.18 m ahead of the nonstriking cheek/rib guard, and weighted skinned-sole
samples keep the kick support foot at floor contact throughout the active phase
at 30/60 Hz and every preset. Measured medium-preset punch
contact is 0.872 m forward from shoulder to fist with effectively no lateral
flare. These curves were informed by the documented CMU subject 144 catalog,
Animation Mentor body-mechanics guidance and a slow-motion punch reference;
no external combat asset is bundled or copied.

Fresh deterministic results: default mechanics `198/198`, exact-R7 mechanics
`200/200`, four-attack controller/pose suite `316/316`, R7 action motion
`198/198`, transitions `67/67`, and full 48,314-vertex/morph deformation
`21,642/21,642` across every action, all three presets and both 30/60 Hz. The
one-slot buffer, target ownership, no root slide, one damage event, nonrepeat
selection and reach-only midrange kicks are directly asserted. The added 48
recovery assertions require punches to withdraw through a raised elbow fold and
kicks to withdraw through a held knee chamber at both rates and every preset.

Normal-renderer evidence covers every move/preset from neutral through load,
contact and recovery: a 361-frame real-time paired baseline at
`captures/r7-four-attack-final200000000.png` through `...00000360.png`, and the
latest 721 half-speed near-profile frames at
`captures/r7-four-attack-slow-final500000000.png` through `...00000720.png`.
The latest slow reel visibly confirms the corrected inward elbow-fold punch
recovery and kick re-chamber before placement. It steps gameplay at 60 Hz per
two movie frames and is review timing, not slowed gameplay. Exact render-time
weighted-sole diagnostics at its frames 372/374/376 report world Y within
`4.1e-8` of zero while the review plane is Y=-0.01; the apparent gap is camera/
shadow perspective, and the disappearing magenta disc is the hit flash. A
seeded eight-hit contextual run at
`captures/r7-context-combo-final300000000.png` through `...00000150.png` mixes
close-range moves without repeats and uses only alternating kicks at 2.30 units.
Every request is a SPACE press/release routed through `_unhandled_input`;
placement/seeding are disclosed helpers, so native-OS input remains a separate
gate. The passing 2026-09-05 V1/R7 matched performance pair remains
the applicable mesh/render budget evidence because this pass changes no asset,
surface, material, LOD or draw-call count; it does not establish an FPS guarantee.

The Sep-7 locked-session blocker is superseded. On Sep 8 the refreshed exact-SHA
`Gloam Courtyard Spike (DEBUG)` accepted ordinary native `space`, produced the
visible strike-whiff response and saved current F12 evidence. This checkpoint
remains **Waiting** for a current-code visible connected/buffered combo,
position-dependent takedown and user visual judgement. It does not promote R7
or relabel the appearance milestone complete; V1 remains default.

The derived local board reuses `vigil-authored-motion` in Waiting, refreshes the
related R7/default evidence counts and creates no duplicate. The regenerated
standalone wrapper has exact source parity, 11 unique task IDs, valid lane IDs
and JavaScript syntax. The previously recorded local-file URL-policy denial
still blocks rendered interaction/responsive acceptance; no workaround was
attempted.

## Waiting — R7 captured-gait alignment refined after native review (2026-09-05)

The user judged the captured R7 movement much better and more natural than the
rejected procedural versions, while reporting two specific remaining defects:
the legs flared outward during travel and the chest/upper body sat too far
forward. This is a bounded continuation of `vigil-authored-motion`, not a new
task, source-art pass or default release. Frozen R7 GLB SHA remains
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`;
V1 remains default.

Read-only source/target diagnostics found that full source hip abduction/twist
transfer was too wide on the target proportions and that captured pelvis,
lower-spine and chest pitch accumulated through the upper silhouette. The
correction in `actors/gloam_vigil/v4/motion/r7_locomotion_refinement.gd`
preserves pelvis motion and sagittal thigh flexion, while attenuating only
thigh lateral/twist axes, modest foot yaw and lower-spine pitch. It does not
clamp the legs together, globally counter-rotate the actor, rewrite the CMU
capture/retarget data, or change gameplay root, 4.8-unit/s speed, collision,
actions, GLB/weights or V1.

The real 60 Hz controller diagnostic records the intended change. Moving chest
rotation pitch falls from `15.77155` degrees mean/`18.27142` maximum to
`6.22787`/`9.08702`; left/right knee flare over neutral falls from
`8.14266`/`10.60355` degrees to `2.57056`/`6.31894`. Knee separation remains
`0.339237–0.372559` m against a `0.33780` m neutral stance, ankle separation
remains `0.407579–0.510009` m against `0.43103` m neutral, and mean gameplay
root speed remains `4.7999985`. All ten alignment assertions pass. A stronger
leg-axis attenuation was rejected because it worsened right-knee tracking;
the chosen values preserve more natural asymmetry.

Matched normal-renderer evidence uses the actual controller at 960x600/30 fps:
`captures/r7-gait-alignment-baseline00000000.png` through `...00000359.png`
and `captures/r7-gait-alignment-final00000000.png` through `...00000359.png`.
The 360-frame sequences cover profile, travel-front, three-quarter and default
views. Matched frame review shows the chest/head returned over the pelvis while
pelvis transfer, stride, foot clearance and a natural stance width remain.

Fresh deterministic results remain green: retarget/source validation; both-rate
controller and support-foot diagnostics; default mechanics `196/196`; exact-R7
mechanics `198/198`; R7 action motion `198/198`; focused transitions `67/67`;
rig `451/451`; runtime contract PASS; and full R7 deformation/action
`17,652/17,652` across all 48,314 exported references. The correction affects
only R7 grounded captured locomotion; crouch, jump, vault, strike, counter,
evade, grapple, takedown, hurt and downed remain unchanged.

The fresh native normal-renderer 1080p pair also passes. Actual-courtyard R7
versus V1 mean/p95/p99 wall ms are `4.316169/6.0030/6.6875` versus
`4.190361/5.9890/6.5628`, or +3.00%/+0.23%/+1.90%. The artificial nine-visual-
rig fixture is +2.63% mean with heavier R7 p95/p99 tails (+15.67%/+21.26%). It
is not nine enemy AIs, reciprocal cadence is not an FPS guarantee or GPU
ceiling, and GPU timing is unavailable. Exact protocol and caveats are in
`work/character-art-review/reports/2026-09-05-locomotion-alignment-performance.md`.
One pre-sampling launch was excluded after a stale live-review process caused
macOS to leave an idle wrapper; the accepted pair ran after exact stale project
processes were stopped and absence-confirmed.

Native ordinary D taps move the corrected exact-R7 build; R reset returns health
100/Momentum 0/guard 100. F12 created
`captures/courtyard_3d_2026-09-05_18-43-38_33856.png`, and that exact-title
`Gloam Courtyard Spike (DEBUG)` session is left open for playtest. This
checkpoint remains **Waiting** for the user's sustained-motion judgement and
the existing ordinary-key strike gate; it does not switch the default.

## Waiting — exact R7 action pass is internally accepted; user review remains (2026-09-05)

The user asked to keep animation separate from character appearance and called
out three missing-looking states: hit, evade and takedown. A read-only baseline
audit confirmed that the legacy R7 strike crossed the chest, the evade rotated
a comparatively rigid body through stacked lift, and the takedown victim began
falling up to 76 ms before its 0.34-second gameplay contact.

The frozen R7 GLB remains SHA
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
`actors/gloam_vigil/v4/motion/r7_action_reference.gd` now supplies R7-only
body-space strike, evade and takedown channels through the pelvis, spine,
clavicles, twist chains, hands and legs. The rig adapter layers them over the
unchanged controller-owned timing/root/collision/damage state. The visual
builder removes the former R7 evade lift stack and delays victim collapse until
contact. No V1, GLB, weights, damage, Momentum, duration or travel constant was
changed.

The result has readable phase structure:

- strike loads through the hips/torso, extends fist ahead of elbow and shoulder
  at the fixed 0.14-second contact, then follows through and recovers;
- evade sends head and shoulder forward first, folds hips/knees over top in a
  compact roll, travels exactly 1.96 units along captured facing by 0.28 seconds
  and absorbs the landing before its 0.42-second lock ends;
- takedown establishes two asymmetric shoulder controls, holds the victim
  stable before the fixed 0.34-second contact, then follows the connected guard
  side fall with one arm before release at 1.10 seconds.

Fresh deterministic results are default V1 mechanics `196/196`, exact R7
mechanics `198/198`, R7 action-motion `198/198`, broader focused transitions
`67/67`, full R7 deformation/action `17,652/17,652`, rig `451/451`, runtime
recovery PASS and both-rate gait/support diagnostics PASS. Godot's macOS
certificate/log-path warnings are environmental and separate from these
passing results.

Normal-renderer review covers two angles for every action. The native-timing
reel is `captures/r7-action-motion-final300000000.png` through
`...00000275.png` (276 frames at 30 fps). Strike contact is at frames 3–4 and
45–46, evade launch/tuck/travel/land at 84–96 and 126–138, and takedown contact/
follow/release at 177–201 and 231–255. The explicitly diagnostic half-speed reel
is `captures/r7-action-motion-slow-final00000000.png` through `...00000551.png`
(552 frames at 30 fps with gameplay stepped at 60 Hz); it is review evidence,
not changed gameplay timing. Dense sampled review found no action pop, backward
arch, lateral drift, pre-contact victim fall or disconnected takedown release.

The same-session post-retarget/action 1080p pair passes its protocol. Actual-
courtyard R7 versus V1 mean/p95/p99 wall ms are
`4.254704/5.53845/6.27043` versus `4.123550/5.4394/6.26324`, or +3.18% mean,
+1.82% p95 and +0.11% p99. The artificial nine-rig fixture has a comparable
+1.38% mean but heavier R7 p95/p99 tails (+13.0%/+21.0%). It is not nine enemy
AIs; GPU timing is unavailable. Exact protocol and caveats are in
`work/character-art-review/reports/2026-09-05-post-retarget-action-performance.md`.

Ordinary native input on the exact R7 candidate verifies facing-forward C with
+4 Momentum and the seven-tap stealth route into T, guard defeat and exit unlock
at health 100/Momentum 35. F12 evidence:
`captures/courtyard_3d_2026-09-05_17-25-31_33257.png` and
`captures/courtyard_3d_2026-09-05_17-26-22_84202.png`. Automated SPACE input was
not reliable before the guard defeated the player, so ordinary-key strike is
not claimed even though its deterministic mechanics and dense render evidence
pass. User gait/action judgement and that remaining strike check gate the narrow
default switch. V1 remains default. The prior action-quality checkpoint below
is superseded where its lock/performance/action status differs. Docs were
updated before the derived board; its source/wrapper parity, one valid inline
script, 13 unique DOM IDs, 11 unique task IDs, three responsive media rules and
44 px coarse-pointer control minimum pass static verification. The recorded
local-URL policy still blocks browser interaction/responsive acceptance, and no
UI bypass was attempted.

Final handoff: reacquired exact `Gloam Courtyard Spike (DEBUG)`, reset the exact
R7 review candidate, captured project-local F12 evidence at
`captures/courtyard_3d_2026-09-05_17-42-17_22329.png`, and left the game open at
health 100/Momentum 0/guard 100 for the user's playtest. This is a review
handoff, not user acceptance or an R7 default release.

## Waiting — captured R7 gait passes internal review; user re-review remains (2026-09-05)

The user rejected three exact-R7 procedural gait versions as still unnatural.
The thirteen-pose correction and its 390-frame reel are now rejected historical
evidence, not a pending acceptance. Frozen appearance/weights remain unchanged
at GLB SHA
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`;
V1 remains default.

R7 grounded locomotion now uses licensed CMU Graphics Lab subject 16 trial 45,
source frames 7–90 at 120 Hz: an 83-frame/0.691667-second run/jog resampled to
48 runtime poses. Facing comes from measured source travel and the target face;
mirrored target suffixes map by spatial side; arm direction bridges the BVH
T-pose to the target's lowered rest; captured motion is distributed through
clavicle, arm/leg twist and toe chains. Gameplay/root speed remains 4.8 units/s.
Only centered millimeter-scale bob/sway is sampled. Full permission, attribution
and exact hashes are in `actors/gloam_vigil/v4/motion/PROVENANCE.md`.

The rejected hard foot solver is disabled only for R7 because its captured
stance traveled beyond the frozen chain's reach and created kicks/blocks. At
30/60 Hz, the live controller reports actual mean speed 4.799997/4.800000,
idle-start phase 0.144/0.046 rad, 2/4-frame neutral settle, knee ranges of
6.84–99.81/100.15 and 6.91–93.14/93.17 degrees, support feet slower than swing
feet and zero active/blocked hard plants. The direct builder fixture independently
passes the same support/swing and zero-block contract. This is not a claim of
perfectly stationary planted feet or production foot IK.

The source/data validator passes 48 samples, 24 channels, finite normalized
quaternions, centered 0.007121-unit maximum presentation root and exact source,
target and generated-data hashes. Two clean Blender builds are byte-identical
to checked JSON SHA
`d38ee01e6a0622259afa19694528f680b53ad2eb89973a1b11c5ea53a2f11513`.
Frozen GLB SHA remains unchanged.

Current normal-renderer evidence is
`captures/r7-gait-cmu-final00000000.png` through `...00000341.png`, 342 frames
at 960x600/30 Hz. It uses the actual controller and asserts every frame remains
inside clamps and outside the low-passage/vault blockers. Frames 0–101 cover
profile idle/start/sustain/stop; 102–173 the actual default camera; 174–245 a
90-degree turn and settle; 246–341 an unobstructed 180-degree reversal and final
settle. Consecutive-frame strips were reviewed for kick/prance, hyperextension,
backward lean, start/stop/phase pop, arm crossing, floor/cape intersection and
obstruction; no release-blocking defect was observed. Mean movie CPU render was
3.09 ms/frame, which is visual-capture telemetry rather than a performance bar.

Post-change deterministic results pass: source/retarget validation and two-build
determinism; 30/60 Hz controller/support diagnostics; 196/196 default mechanics;
198/198 exact-R7 mechanics; 67/67 focused transitions; runtime rig recovery;
and 17,652/17,652 full-vertex/morph/action deformation checks. Sandboxed Godot
log/certificate/editor-settings warnings remain environmental and separate.

This checkpoint is **Waiting**, not Complete. Its paired benchmark and exact-
title handoff were completed by later checkpoints, and the user subsequently
identified the leg-flare and upper-body-alignment defects corrected above.
Sustained native user review still remains. The separately authorized R7
strike/evade/takedown phase does not accept this gait or switch the default.

## Rejected historical — second native walk rejection correction (2026-09-05)

The user subsequently rejected this thirteen-pose version; its measurements,
reel and live handoff are preserved below only as historical evidence.

The user liked the frozen R7 appearance but rejected movement twice. The first
native review found walk/jump/general motion awkward and crouch hands behind the
body. After the broader correction, a newly launched exact-candidate build still
made walking look unbending and exposed a questionable rigid forward lean. The
user explicitly narrowed the next milestone to walking. Existing task
`vigil-authored-motion` remains Waiting; no duplicate or character-source edit
was made. Exact GLB SHA remains
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.

The new read-only 60 Hz held-input diagnostic reproduced the cause in the real
courtyard controller. The rejected five-pose curve ranged only about
20.46–43.59 degrees at the knees and placed its strongest bend on the planted
leg while the traveling leg stayed comparatively straight. R7 now selects a
separate thirteen-key contact/load/toe-off/early-swing/maximum-flex/pre-contact
cycle. Gameplay speed remains 4.8 units/s; visual cadence is 9.6 rather than
11.6 rad/s. The gameplay root stays upright, restrained pitch is articulated
through the spine, the pelvis settles into contact rather than rising there,
and the arms use compact bent-elbow contralateral balance.

The corrected sustained trace measures left/right stance maxima
34.37/34.90 degrees, swing maxima 73.59/73.70 degrees and zero blocked plant
frames. The independent 60/30 Hz fixture locks 53/53 and 27/27 measured support
frames with zero blocks; full-lock ankle maxima are 0.01694/0.02450 m under the
unchanged 0.035 m bar. The focused 390-frame normal-renderer reel is
`captures/r7-walking-final-review00000000.png` through `...00000389.png`:
frames 0–89 sustained profile gait, 90–119 stop/settle, 120–179 actual default
camera, 180–239 three-quarter restart/gait, 240–269 stop, 270–329 direction
change and 330–389 settle. The earlier all-action reel's walk frames remain the
before case.

After this walking change, exact results remain 196/196 default mechanics,
198/198 R7 mechanics, 67/67 focused transitions, 451/451 rig, runtime
articulation/bind recovery and 17,652/17,652 full-vertex/morph/action
deformation. The broader hands-ahead crouch, jump/vault, forward evade,
strike/counter/takedown/grapple/hurt/downed corrections remain implemented but
are not promoted by this checkpoint. Native user review of sustained walking is
the immediate gate. Only after it passes should ordinary vault/grapple/counter/
takedown/exit review resume; V1 remains default.

The exact-SHA walking correction was freshly relaunched in a verified
`Gloam Courtyard Spike (DEBUG)`, reset, captured with project-local F12 and left
open for native play. `captures/courtyard_3d_2026-09-05_16-14-06_9933.png`
records health 100, Momentum 0, guard 100 and the reset objective. This proves
the current handoff state, not user acceptance of the gait.

## Superseded — earlier R7 action-quality implementation; native release was blocked (2026-09-05)

The separate `vigil-authored-motion` pass is implemented on frozen R7 GLB SHA
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`;
the model source/GLB and appearance decision did not change. R7 now has
naturalized locomotion blending, stronger jump/vault silhouettes, a facing-
locked forward somersault, distinct strike/counter/takedown/grapple/hurt/downed
poses, measured finger flex/MCP adduction profiles, facial response and restrained
cape follow-through. The grapple world path gains a 1.75-unit eased clearance
arc but retains its accepted 0.32-second duration and exact `(6, 3.04, -2.4)`
landing. Player downed and guard defeat/takedown now use connected whole-body
side-fall pivots with supported floor settles instead of floating/folding parts.
Gameplay damage, Momentum, travel, collision and cancellation contracts remain
unchanged.

Final deterministic evidence passes:

- default V1 mechanics `196/196`; exact-candidate R7 mechanics `198/198`;
- focused controller/action transitions `57/57`, including grapple lip
  clearance, hurt/downed locks/restart and paired guard whole-body fall;
- R7 rig `451/451`, runtime articulation/bind recovery and 30/60 Hz foot-plant
  release contracts;
- R7 strict deformation `17,652/17,652`, all 48,314 exported references, every
  action frame at 30/60 Hz and small/medium/large presets. Final downed minima
  are -0.00837/-0.00908/-0.00988 m; the established floor bar still passes.

Normal-renderer evidence was reviewed rather than accepted from status output
alone. The broad 780-frame close/gameplay reel is
`captures/action-quality-r7-full-final-close00000000.png` through
`...00000779.png`; it covers idle, locomotion/stop/reversal, crouch, free jump,
vault, grapple/recovery, fall, evade, strike, counter, hurt/downed/restart and
paired takedown. Review of that reel found three real defects: the grapple body
crossed the perch lip, player downed floated, and the segmented guard folded at
its helmet. The reel is therefore coverage evidence, not final evidence for
those states.

Corrected focused evidence is
`captures/action-quality-r7-defects-supported200000000.png` through
`...00000169.png`: frames 3–15 show the stronger asymmetric jump load/flight,
55–65 show the full mesh clearing the perch lip and converging on the exact
landing, and 118–160 show the player connected side fall and stable supported
settle. Corrected paired-takedown evidence is
`captures/action-quality-r7-after6-close00000000.png` through
`...00000224.png`: frames 135–150 cover catch/contact/pull, 155–180 the coherent
guard body fall, and 190 the completed fade. The guard remains deliberately
segmented/stylized; this is not a claim of production ragdoll simulation.
Finger-profile close evidence and the rejected source-weight-only R8 diagnosis
are under `work/action-quality/hand-study/`; the latter worsened maximum LBS
deformation, so only the runtime per-digit MCP solution was retained.

The same-session normal-renderer performance pair used exact 1920x1080,
Compatibility/OpenGL3, reported VSync off, no engine cap, three >=3-second
warmups and three >=10-second/600-frame samples per case. Actual-courtyard V1
versus R7 mean/median/p95/p99 wall ms are
`3.212387/3.184/3.325/3.936` versus
`3.338700/3.249/3.8957/4.95328`; R7 mean cost is about 3.9%. The artificial
nine-visual-rig fixture is `14.259754/14.198/14.84875/15.21935` versus
`15.384599/15.188/17.098/19.1525`; R7 mean cost is about 7.8%. All six
repetitions met their duration/sample gates and emitted config/benchmark OK.
The stress copies are not enemy AIs, reciprocal cadence is not an FPS guarantee,
and GPU timing is unavailable. Exact protocol, samples and caveats:
`work/character-art-review/reports/2026-09-05-action-performance.md`.

This historical checkpoint was **Waiting**, not Complete. CUA reported the Mac locked and
automatic unlock is unavailable. The display-unlocked state of the technical
performance pair could not be independently confirmed. No UI bypass or duplicate
unlock prompt is permitted. After unlock, ordinary native input must cover the
full action list on this exact SHA; only then may the parent change the default,
rerun it, capture F12 and leave a fresh exact-title DEBUG handoff. V1 remains
default. Local-board interaction/responsive acceptance remains independently
blocked by the recorded local-URL policy denial; static checks are separate.
Docs were updated before the derived board. `vigil-authored-motion`,
`vigil-sculpt-quality`, paired performance and R7 integration all truthfully
remain Waiting on native acceptance; no task is falsely shown Now. The local
wrapper was regenerated. Static verification passes exact source/wrapper parity,
one valid inline script, 13 unique DOM IDs, 11 unique tasks, desktop/tablet/
mobile media rules and the coarse-pointer 44 px control minimum. This is not a
browser interaction or responsive-layout acceptance claim.

## Background complete — frozen V4/R7 source and strict checks pass; live release blocked (2026-09-05)

Final candidate GLB SHA:
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
Source SHA: `40b4fca657e3ab91783ddeca2e2f02c87619f1daf89d245921397fc6f0669fdc`.
Both and the manifest are archived in `actors/gloam_vigil/v4/revisions/r7`;
R1–R6 negative controls are preserved. This is source/technical acceptance,
**not a default release or a completed live-play milestone**.

Matched before/after source images use the same native Blender review setup:
`actors/gloam_vigil/v4/renders/r1/v1-{front,threequarter,profile,head-front,head-threequarter}.png`
versus `actors/gloam_vigil/v4/renders/r7/v4-*`. Root and the originating art task
independently confirm the substantial anatomy/detail improvement. Fully dressed
grapple/strike/crouch full and neck images, plus exact-source checks, live under
`work/character-art-v4-rig/r7-posed/`. The independent source-pose reviewer found
no collar gaps, arm tethers or pointed-chin regression. Every mesh in all three
poses has zero edges over 6x and zero tethers. Worst face edge is 2.006x;
body/face cut-ring mismatch stays at its geometric pairing baseline, mean
6.104 micrometres/max 0.2373 mm rather than growing with pose. Source hash is
unchanged before/after the read-only review.

The R5 anatomical mandible/throat weights restore head-following chin/lips
(landmark errors at most 1.33e-7 m) while preserving neck continuity. R6 exact
hit-triangle collar weights remove the larger wedge but leave a 0.997 mm posed
rear overlap below the neckline. R7 adds only a smoothly faded 2.5 mm rear
middle cloth-row lift with 0.5 mm adjacent-row blend; sampled weights, frozen
face/rig and front/top neckline stay unchanged. Matched negative controls:
`r4-posed/r4-crouch-neck-close.png`, `r6-posed/r6-crouch-neck-close.png` versus
`r7-posed/r7-crouch-neck-close.png`. No further art scope is open in this pass.

Exact R7 headless results: static GLB/color/import PASS; 85,040 triangles,
43,016 source vertices, 48,314 exported/runtime vertex references, 74 joints
(73 meaningful plus structural root), seven surfaces, five materials, four
morphs and maximum four influences. Spatial scalp/face COLOR_0 passes with
272 colors and 1,430 dark scalp samples. Imported LOD probe finds 36 actual
index buffers (R5's 37 is historical, not the R7 count). Rig 451/451,
runtime channels/bind recovery, candidate mechanics 198/198, 30/60 Hz foot
planting and strict all-preset/full-vertex/morph deformation 14,730/14,730 pass.
60 Hz planting is 53/73 support frames with 0.0341517 m maximum full-lock drift
under the unchanged 0.035 m bar; 30 Hz is 28/38 and 0.00711168 m. Large final
jump minimum is -0.023451 m against the unchanged -0.030 m floor bar. Crouch
maxima remain 1.701680/1.933727/1.906637 m under the 2.0 m lintel. Exact raw
evidence: `work/character-art-review/reports/2026-09-05-v4-r7-faafa629-raw.log`.
The companion `2026-09-05-v4-r7-faafa629.md` records each finished command,
exact fingerprints, source comparisons and remaining live/performance limits.
Godot macOS CA/editor-settings/user-log permission warnings are environmental;
there are no script failures. Root also reran actual default V1 mechanics:
196/196, exit 0. V1 GLB remains SHA `deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`.

At this source-only checkpoint the remaining release gates were: the Mac was
locked and automatic unlock
is unavailable; the user unlock request is pending. No further UI polling or
bypass. After unlock, normal-renderer close/default/action review and ordinary
input smoke must pass on this exact SHA. Rerun **both** V1 and R7 in the same
quiet 1080p benchmark window, because display-lock state in the preliminary
V1-only run is unverified. No final V4 FPS, GPU ceiling or supported crowd-size
claim exists. Only then may the parent switch the default, regress it and leave
one fresh exact-title DEBUG window with F12 evidence. The subsequent top action-
quality checkpoint records the completed technical pair and current native-only
release gate. The separate local-board URL-policy denial still blocks browser
interactions/responsive acceptance.

Known source limitations: stylized procedural skin/suit detail, close-cropped
color hair rather than grooming, a tiny full-blink iris sliver and no cloth or
ragdoll simulation. These are not photorealism or motion capture. At this
source-only checkpoint, broader natural motion/contact/follow-through was still
queued; the subsequent top checkpoint supersedes that queue status. Resume
steps and performance limitations are in `work/character-art-review/README.md`
and its performance report.

Docs/source metadata were refreshed before the derived local board. Existing
art, performance and integration tasks now read Waiting/blocked; animation
remains Next and no duplicate tasks were created. `project-roadmap-local.html`
was regenerated. Static verification passes: 11 unique tasks, 13 unique DOM
IDs, one syntactically valid inline script and exact source/wrapper parity.
The export warns that optional `window.openai` handoff requires its host;
this is not a completed browser interaction or responsive-layout check.

## Diagnostic — r3/r4 pass bounds but source-pose review catches neck defects (2026-09-05)

R3 SHA `242104fcc347652f4d3e83c2da779282b9a2ff76bb4c5ffc943caf6ca09f986e`
and R4 SHA `ea4f64e4919640f53099dd8876170adb401b9b6e9e272abdcd692dff061723ef`
are archived with source/manifest in `v4/revisions/r3` and `r4`. Both have
85,040 triangles, 48,316 exported vertices, 74 joints, five materials/seven
surfaces and four morphs. Both pass static color/export, 36 imported LODs,
451 rig checks, runtime channels/recovery, 198 mechanics, 30/60Hz planting and
14,730 full-vertex/morph deformation checks. The final-jump floor correction
passes unchanged -.03m bars, worst large minY -.023451m. Technical reports
are `work/character-art-review/reports/2026-09-05-v4-r3-242104fc.md` and
`2026-09-05-v4-r4-ea4f64e4.md`.

R3 fixes the long hand/forearm/shoulder tethers, named scalp color export and
floating neutral collar. Source neutral art review passes. The full-body LBS
rig check now evaluates 215,406 adjacent edges across grapple/strike/crouch/
evade/asymmetric walking. Actual fully dressed source poses under
`work/character-art-v4-rig/r3-posed/` expose two further neck defects: an
internal jaw threshold drops neck ownership across a 3.42mm edge, stretching it
to38.98mm in crouch; coincident head/body cut-ring points separate20.72mm during
grapple because the body retains arm/clavicle influence at the neck.

R4 replaces the threshold with a continuous head/neck/jaw mix and returns the
body upper-neck ring to neck1 through a smooth1.72–1.81m band. Ring motion now
matches at sub-micrometre numerical precision, and all source meshes have zero
edges over6x. Nevertheless, **R4 is visually rejected**: its Z-only neck field
pulls the projecting chin downward in deep crouch. Independent review confirms
the pointed lower face in `r4-posed/r4-crouch-neck-close.png` and full-body view.
Rigid-head reference measurements find52.23mm chin-bottom displacement,
nose-to-chin length1.368x and lower-lip-to-chin length1.558x. Bounds and edge
ratios alone do not establish anatomical shape preservation. A bounded spatial
mandible/throat falloff repair is required, with neutral geometry/materials/
morphs unchanged and the exact collar match retained.

No r3/r4 runtime visual, ordinary-input or final performance acceptance exists.
The Mac is locked and automatic unlock is unavailable; no lock bypass is
permitted. The earlier recorded V1 performance run has unverified display-lock
state, so it is preliminary: rerun both V1 and final V4 after confirmed unlock.
The separate browser local-board URL-policy gate remains open. V1 stays default.

## In progress — v4/r2 visual direction approved; runtime repair required (2026-09-05)

R2 SHA `5791674278e1d337f38784f2fa1b568e5e40c90fb56ab4ad9cd655f7dccf4399`
is archived with source/manifest in `v4/revisions/r2`. Native matched renders
in `v4/renders/r2` show a substantive facial/anatomical improvement, fitted
cape attachment and reshaped boots. Independent review approved proceeding to
runtime acceptance with a bounded collar-fit correction. Skin/iris/hair and
the procedural suit pattern remain art limitations, not photorealistic finish.

R2 has 84,804 triangles, 48,214 exported vertex references, 74 joints,
five materials/seven surfaces and four facial morphs. It passes import,
36 actual LOD buffers, 451 rig checks, runtime channels/recovery, 198 mechanics
and both-rate ankle planting. Full deformation fails only three of 14,730
checks: final active 60Hz jump minY -.0366783/-.0447890/-.0556033 versus -.03.
Technical report: `work/character-art-review/reports/2026-09-05-v4-r2-57916742.md`.
The subsequent v4-only visual landing compression correction passes 960 focused
full-vertex/morph checks, minY -.0122867/-.0170714/-.0234511; it is not a full
final-asset acceptance result.

The 360-frame normal-renderer sequence `captures/gloam-v4-r2-quality-actions...`
(indices00000000–00000359), particularly165/253, still exposes narrow raised-arm
body streaks. A 12.422mm source edge expands to1.04567m under grapple because
adjacent vertices cross a hard forearm/core ownership gate; shoulder seams are
also affected. `work/character-art-v4-rig/r2_action_spike_diagnosis.json` records
the real source anatomy defects. Continuous whole-limb weighting is required;
finite bounds and relaxed tolerances would not repair this visible failure.

R2 Skin COLOR_0 exists but is uniformly white: scalp/lip color is not preserved.
An isolated named-Col export probe SHA `471a7a46c0733d0eebbff7e07aa8ba3ceffcf312f1d04d58be332ba2a1d83bc3`
preserves all272 source Skin colors within U16 quantization. The strengthened
spatial dark-scalp/light-face static gate rejects r2 and accepts that probe.
No default switch or final v4 performance claim follows. Full final-asset
validation, rendered ordinary play, paired performance and fresh DEBUG handoff
remain open, as does the separate explicit local-board URL-policy gate.

## In progress — v4 dressed anatomical candidate, r1 rejected (2026-09-05)

Source is the explicitly authorized free CC0 Dan Ulrich realistic anatomical
base from Blender Human Base Meshes v1.4.1, with our original costume and rig
adaptation. Exact provenance and source hashes are recorded in
`actors/gloam_vigil/v4/PROVENANCE.md`. No franchise geometry, costume or purchase
is used; the base must not be described as wholly authored here.

R1 SHA `8d46f24c5eccb72964e71c602ac7d0d620e31f0eed15e1c492a581f4c976bcc1`
is preserved with its source/manifest under `v4/revisions/r1`. It exports 87,268
triangles, 50,007 runtime vertices, 74 bones, five materials/seven surfaces and
four morphs. Static GLB, import, 38 actual LOD index buffers, 451 rig checks,
runtime articulation/recovery and 198 mechanics checks pass. Full deformation
fails 3 of 14,730 unchanged checks: the final active 60Hz jump frame reaches
minY -.04028/-.04888/-.06035 across small/medium/large versus the -.03 floor
bar. The 60Hz ankle-plant coverage is 50/73 frames (68.49%), below 72%, although
drift suppression, 30Hz coverage and all release/root checks pass. No v4
performance result or ordinary-input acceptance exists yet.

Matched native Blender front/three-quarter/head/profile evidence lives in
`v4/renders/r1/` for v1 and v4. The new anatomy is materially better, but the
cape root is visibly detached, boots have balloon-like toes/heels, and face
and crotch tailoring need refinement. Native Godot captures include 225 actual
30Hz game-action frames `captures/gloam-v4-r1-actions-close00000000.png` through
`...00000224.png`, and 300 deliberately stretched equal-light pose frames
`captures/gloam-v4-r1-quality-actions00000000.png` through `...00000299.png`.
Actual-game frames18/90/140/153 and comparison165 reveal narrow hand streaks.
This is a hard visual failure despite finite/bounded numerical results.

The rig diagnosis identifies 389 left/390 right distal hand vertices that fell
outside the arm distance gate and were assigned to leg bones. One adjacent
edge stretches from 5.49mm to 184.28mm under grapple. The exact diagnostic is
`work/character-art-v4-rig/r1_spike_diagnosis.json`; technical results are in
`work/character-art-review/reports/2026-09-05-v4-r1-8d46f24c.md`. Corrective work
must use connected hand ownership, not merely wider numerical tolerances.

Next acceptance requires corrected dressed/rigged visual review, full strict
deformation and foot planting, gameplay regression, normal-renderer paired
performance, ordinary-input playthrough, updated board and fresh DEBUG handoff.
V1 remains the playable default. The separate board URL-policy gate remains
open; static board checks do not establish responsive/interaction acceptance.

## Organization recorded — separate animation pass (2026-09-04)

User approved separating animation from the face/model-detail pass. The existing
`vigil-authored-motion` task is now the queued animation-quality pass, with the
runtime-verified action-readability checkpoint below as its starting point.
`UPCOMING_TASKS.md` defines scope, rig coordination, ownership and acceptance.
No code/assets/gameplay changed and no new runtime results are claimed. The
last verified default handoff remains `18-32-58_9672`; existing face-art rejection
and browser board-verification gate remain unchanged. This records organization,
not completion of the queued animation pass.

Derived-board organization checks pass: the same 11 unique tasks remain, with
exactly one `vigil-authored-motion` task, one valid inline script, 13 unique DOM
IDs and exact regenerated source/wrapper parity. The motion task remains Next;
no new animation completion or browser interaction/responsive result is claimed.

## Runtime verified — action readability; board UI gate open (2026-09-04)

Latest user request: visible hit/takedown and forward-over-the-top evade along
visible facing. Default v1 remains selected. SPACE now authors a full extension
at its 0.14s contact in a 0.36s swing; repeated input cannot restart it or stack
damage. Counter/evade cancel pending hits. T reserves both actors for a 1.10s
reach/pull/release, approaches through existing collision and defeats/+35 once
at 0.34s. Darkness/behind/range/height/low-lintel gates pass. C uses positive-X
rotation and visible-yaw direction, exact 1.96-unit/0.28s collision-checked
travel, unchanged 0.42s invulnerability/+4 and no held/tap stacking. The old
remembered-travel direction and backward spin are superseded. Guard health
text updates on contact/counter, including during stun.

Accepted checks: 196 mechanics (`work/action-readability/mechanics.gd`), 4,176
full-v1 mesh action checks (`deformation.gd`, all 97,061 vertices/12 surfaces,
every actual 30/60Hz action frame and three presets), and legacy 511 deformation.
Worst action floor minimum -0.007363 world units, within unchanged -0.03 limit;
strike contact shoulder X=-1.605rad/local lunge0.170. All actions recover upright
without root/scale/driver drift. Headless editor and120-frame runtime exit0 with
no script errors. CA/editor-settings sandbox warnings are separate environment
messages. The historical107 mechanics assumptions are intentionally superseded
by the196 timing/direction contract, not claimed as unchanged/passing.

Before/final normal-renderer sequences: 225 actual 30FPS frames at960×600 each,
`captures/action-before-close...`, `action-final-close...`, and
`action-final-courtyard...` (indices00000000–00000224). Reviewed windup13,
hit16–17, forward-roll85–97, catch142, pull150, release158. The first revision
`action-after-r1-close...` is preserved: positive spin exposed a3.79cm mask/floor
miss, corrected by visual-only arc clearance before final acceptance. No test
tolerances or collider dimensions were relaxed. Fixtures use test positions,
not ordinary-input reachability; movie encoding time is not a performance result.

Ordinary-input smoke passes: shadow/T → grapple → exit at health100/M35
(`captures/courtyard_3d_2026-09-04_18-22-25_28234.png`,
`...18-22-47_50043.png`, `...18-22-53_56568.png`); single SPACE gives guard78/M13
(`...18-23-12_75608.png`); bounded combat burst defeats guard at health82/M75
after one normal hit (`...18-23-41_104301.png`). Large/accent forward evade
(`...18-23-58_120786.png`), small crouch/travel (`...18-24-08_130952.png`),
jump and camera/orbit/pitch/zoom/travel/reset (`...18-24-17_140357.png`) pass.
Long observation pauses after the single hit allowed the guard to down the
player; that capture is not successful combat or failed-invulnerability evidence.
Reactive timing remains owned by deterministic tests because screen latency is
longer than action windows. W/S convention and post-downed input handling remain
pre-existing spike quirks, not changes made in this action pass.

Post-change bounded1080p/M4Pro performance smoke: one≥3s warmup/one≥10s sample
per case, explicitv1 and GLCompatibility, no movie/headless timing. Courtyard
2399frames median/p95/p99=4.031/5.302/5.675ms; artificial nine-visual-rig fixture
601frames=16.660/17.074/17.207ms. Consistent with the prior baseline, not a new
paired statistical study, GPU ceiling or supported enemy count. GPU timer is
unavailable; stress copies include strike/evade but not takedown. Exact output
is `work/action-readability/performance.log`; reproduction/limits are in README.

Next completion bar: current-board interaction/responsive verification remains
blocked by the existing explicit URL-policy denial; do not bypass it. Docs and
derived local-board source/wrapper can be kept current and statically validated.
The broader face/anatomy realism milestone remains open with v2 rejected/off.

Final fresh handoff: the smoke run was closed normally and absent-app inventory
confirmed. After all production edits/tests, default launch was reacquired as
exact `Gloam Courtyard Spike (DEBUG)` and left open. F12 capture
`captures/courtyard_3d_2026-09-04_18-32-58_9672.png` verifies v1/default medium,
pink accent, health100/Momentum0/guard100, reset objective and default camera.
No gameplay source changed after launch. Derived board now has 11 unique tasks
(6 waiting, 2 next, 1 later, 2 historical complete), one valid inline script,
13 unique DOM IDs and exact source/wrapper parity. Browser interaction and
responsive checks remain explicitly unverified/policy-blocked.

## Complete — initial 2D mechanics spike (2026-09-03)

Evidence: `main.tscn`, `main.gd`, and the README. The code-drawn courtyard validated movement/depth read, grapple/perch, concealment/takedown, patrol and vision, suspicion/alert/attack, strike/counter/perfect timing, evade, health, Momentum, restart, exit success, and minimal customization.

## Complete — computer-control exposure (2026-09-03)

Evidence: Godot became visible to Computer Use after a clean instance reset and macOS permission grant. The Godot.app route exposed `Gloam Courtyard Spike (DEBUG)` for screenshot and key control.

## Complete — capture-loop upgrade (2026-09-03)

Evidence: F12 created readable project-local 960×600 PNGs with on-screen confirmation. Godot 4.7.2 normal-renderer movie writing produced a 36-frame AVI and numbered PNG frames; headless movie mode hit a dummy-renderer null-texture crash.

## Complete — 2D visual polish (2026-09-03)

Evidence: `captures/courtyard_2026-09-03_17-45-54_18313.png`. Added procedural skyline, rain, fog, wet highlights, warm practical lights, a parapet rail, stronger silhouettes, and a cleaner HUD while preserving the loop.

## Complete — 3D gray-box pivot (2026-09-03)

Evidence: `captures/courtyard_3d_2026-09-03_17-58-38_21097.png` (initial) and `captures/courtyard_3d_2026-09-03_18-03-28_23470.png` (final). `main_3d.tscn`/`main_3d.gd` are the default scene and use a fixed orthographic-style Camera3D, primitive 3D courtyard architecture, real-height perch, fog/rain/lights/shadows, readable original placeholder silhouettes, clean HUD, and the preserved mechanics loop. The targeted visual adjustment enlarged/brightened actors and lowered the camera into a stronger three-quarter view.

Verification evidence: live Computer Use captured the 3D window, moved the player to the anchor, grappled to the elevated perch, restarted, entered close combat, raised Momentum, and showed the counter-window state. F12 created a readable project-local 3D PNG. A six-frame Godot normal-renderer PNG sequence exists as `captures/gloam-3d-frames00000000.png` through `captures/gloam-3d-frames00000005.png`; first/last hashes differ and inspection shows the guard moving. Final headless scene/editor/runtime checks report no parse or script errors.

At this checkpoint the remaining question was a taste/authored-asset decision, not more systems breadth. The later direction checkpoint below commits to 3D.

## Complete — 3D environment and scale polish (2026-09-03)

Evidence: `captures/courtyard_3d_2026-09-03_18-11-16_22641.png`. Added abstract gothic arch/window forms, near parapet posts, varied wet slabs/puddles, stronger cool/amber contrast, and additional scale layering. The pass remained primitive, original, and navigable.

## Complete — 3D motion feedback polish (2026-09-03)

Evidence: `captures/courtyard_3d_2026-09-03_18-14-43_42433.png` and `captures/gloam-3d-motion00000000.png` through `captures/gloam-3d-motion00000011.png`. Added camera-relative lean, interpolated grapple travel, and brief strike/perfect-counter light flashes. The latest sequence produced twelve valid 960×600 PNGs with differing first/last hashes and visibly changing patrol frames.

## Complete — authored 3D direction decision (2026-09-03)

The composed three-quarter true-3D approach is now the committed implementation direction. The preserved 2D spike remains comparison evidence, but it is no longer an alternative awaiting selection. The later constrained-camera extension preserves this default composition.

## Complete — constrained camera orbit, pitch, and reset (2026-09-03)

Evidence: `captures/courtyard_3d_2026-09-03_19-58-20_6260138.png` (default/reset), `captures/courtyard_3d_2026-09-03_20-03-56_211521.png` (clockwise), `captures/courtyard_3d_2026-09-03_20-04-28_243665.png` (counterclockwise), and `captures/courtyard_3d_2026-09-03_20-05-46_321489.png` (reset/gameplay). The capture hashes differ.

Live testing verified `J/L` left/right orbit, bounded `I` pitch while retaining the courtyard, `0` restoration of the default three-quarter view, `R` gameplay reset, camera-relative `D` movement after rotation, and F12 capture. Post-change headless editor/runtime checks were clean apart from the known macOS sandbox path warnings.

## Complete — live camera zoom input (2026-09-03)

The original handlers changed camera distance while the active camera used an orthographic projection, so both keys executed without changing visible scale. Zoom now changes `Camera3D.size` through `camera_zoom_out` and `camera_zoom_in` InputMap actions. Main-row minus zooms out; equal and shifted plus zoom in; keypad subtract/add are equivalent. The existing `17.0` near, `26.0` far, `18.5` default, and `5.0`-units-per-second behavior are preserved as orthographic-size limits and smoothing.

Live desktop input visibly verified minus zoom-out, equal zoom-in, and shifted-plus zoom-in in `Gloam Courtyard Spike (DEBUG)`. Evidence: `captures/courtyard_3d_2026-09-03_21-38-17_128148.png` (default), `captures/courtyard_3d_2026-09-03_21-38-28_139159.png` (minus/zoom out), and `captures/courtyard_3d_2026-09-03_21-38-44_154293.png` (equal followed by shifted-plus/zoom in).

An actual InputMap integration probe loaded two zoom-out bindings and three zoom-in bindings, then passed main minus, main equal, shifted plus, keypad subtract, and keypad add through `InputEventKey.is_action_pressed` and the scene's input handler with the correct size direction. A second action-path probe verified a `0.1`-second hold changes size by `0.5`, clamps to `17.0`/`26.0`, and resets to `18.5`. Headless editor and two-second runtime checks exited cleanly; only the known macOS sandbox path/certificate warnings appeared.

## Complete — grapple discovery and state feedback interaction (2026-09-03)

The authorized localized change in `main_3d.gd` replaces the always-on `G GRAPPLE` prompt and detached flat yellow route with a 3.5-unit segmented gold boundary, dotted ascending route, state-aware prompt, and ready/transit/complete light-emission changes.

Live evidence confirms that one outside step rejects `G`, the next inside step brightens the ring and shows `G // GRAPPLE READY`, launch shows `GRAPPLE // IN TRANSIT`, and landing shows `ROUTE COMPLETE`. This verifies discovery, activation threshold, travel state, and destination feedback.

Evidence: `captures/courtyard_3d_2026-09-03_20-12-59_16698.png` (post-fix baseline), `captures/courtyard_3d_2026-09-03_20-14-22_99329.png` (outside), `captures/courtyard_3d_2026-09-03_20-14-29_106554.png` (ready), `captures/courtyard_3d_2026-09-03_20-14-38_114771.png` (in transit), and `captures/courtyard_3d_2026-09-03_20-14-49_126570.png` (route complete).

## Complete — end-to-end smoke clear and issue discovery (2026-09-03)

The runtime task reached `COURTYARD CLEAR` through reset, movement, rapid combat, 100% Momentum, guard defeat, grapple, perch landing, and exit. This verifies that the active loop remains completable after the camera and grapple-feedback changes.

Evidence: `captures/courtyard_3d_2026-09-03_20-16-14_211587.png` (evade/Momentum), `captures/courtyard_3d_2026-09-03_20-16-48_245370.png` (guard down, health/Momentum 100%), `captures/courtyard_3d_2026-09-03_20-16-55_251987.png` (grapple launched), and `captures/courtyard_3d_2026-09-03_20-17-02_259053.png` (`COURTYARD CLEAR`). `captures/gloam-feedback-loop00000000.png` through `captures/gloam-feedback-loop00000007.png` are eight valid 960×600 normal-renderer frames at 12 FPS with different first/last hashes. Post-change headless editor/runtime checks exited cleanly with no parse/script errors; only the known macOS sandbox warnings appeared.

The same run visibly reproduced two unresolved issues:

- Silent takedown is advertised, but the current courtyard provides no reachable setup that satisfies darkness, close range, and behind-the-guard positioning. Evidence: `captures/courtyard_3d_2026-09-03_20-17-42_299203.png`.
- A still-active guard can attack through the elevated perch, including until the player dies. Evidence: `captures/courtyard_3d_2026-09-03_20-18-27_344248.png`.
- Screenshot observation takes roughly 1.1–1.5 seconds, longer than the 0.72-second attack and 0.42-second evade windows. Predetermined bursts work for automation; human timing remains the honest reactive test.

## Complete — believable character and movement foundation (2026-09-03)

The player and guard are now distinct original stylized humanoids at gameplay distance. The player reads as an athletic hooded wayfarer with layered clothing, shaped boots, readable limbs/hands, and preserved body/accent variants. The guard reads as a utilitarian courtyard warden with layered armor/uniform pieces, helmet, asymmetry, and an attached watch-blade. No franchise names, likenesses, symbols, costumes, architecture, or external assets were introduced.

`actors/character_visual_builder.gd` is the stable visual boundary for procedural geometry, named arm/leg pivots, and pose application. `main_3d.gd` retains gameplay decisions. Procedural idle/walk blending moves opposite arms and legs; the player turns toward camera-relative travel and the guard walks through its patrol rather than gliding.

Movement correctness is accepted: both actors enforce a 1.48-unit grounded separation while close combat remains reachable; grapple lands on the 3.04-unit perch top; horizontal input walks on the perch; crossing its footprint begins gravity-driven descent; landing restores the courtyard floor state; and height-aware melee prevents the ground guard from hitting through the elevated perch.

Live before/after evidence: `captures/courtyard_3d_2026-09-03_21-06-30_3227041.png` and `captures/courtyard_3d_2026-09-03_21-37-13_64195.png`. Preset/accent, opposite gait/facing, spacing, and grapple/perch evidence: `captures/courtyard_3d_2026-09-03_21-37-38_88977.png`, `captures/courtyard_3d_2026-09-03_21-37-44_94380.png`, `captures/courtyard_3d_2026-09-03_21-38-17_128148.png`, `captures/courtyard_3d_2026-09-03_21-38-43_153408.png`, `captures/courtyard_3d_2026-09-03_21-38-44_154293.png`, `captures/courtyard_3d_2026-09-03_21-39-36_207142.png`, `captures/courtyard_3d_2026-09-03_21-40-12_242909.png`, `captures/courtyard_3d_2026-09-03_21-41-13_303358.png`, and `captures/courtyard_3d_2026-09-03_21-41-41_331693.png`.

The normal-renderer sequence `captures/gloam-character-fall-final00000000.png` through `captures/gloam-character-fall-final00000027.png` is 28 frames at 12 FPS and 960×600. Frames 6–8 show perch traversal and edge departure, 9–12 show the falling silhouette, and frame 14 shows `LANDED: courtyard floor`.

The deterministic regression probe passed player and guard separation, combat at the separation boundary, grapple/perch landing, perch walk, edge fall, ground landing, perch-height attack rejection, exit success, restart state cleanup, and spawn restoration. Headless editor and two-second runtime checks exited 0 with no parse/script failure; only the benign macOS log/certificate/editor-settings sandbox warnings appeared. A fresh Godot.app launch was reacquired as `Gloam Courtyard Spike (DEBUG)`, reset to the 100-health/0-Momentum/guard-100 default state, visually verified in `captures/courtyard_3d_2026-09-03_22-01-18_328813.png`, and left open for playtest.

## Complete — procedural character realism and natural locomotion (2026-09-03)

The user-prioritized pass substantially reduces the actors' blocky read while remaining honest procedural gray-box art. Both actors now use tapered upper/lower limbs, rounded torso/armor/garment layers, shaped feet and hands, coherent pelvis/waist/ribcage/neck/head transitions, and articulated hip-knee-ankle plus shoulder-elbow-wrist hierarchies. The original hooded wayfarer, utilitarian warden, three body presets, two accent colors, and asymmetric watch-blade identity remain intact; the blade now follows the guard's articulated wrist.

Locomotion now blends knee flex, foot counter-rotation, relaxed elbow bend, lateral weight transfer, pelvis yaw/roll, torso counter-yaw, head compensation, smoother double-step rise, idle breathing, asymmetry, and player coat-tail lag. The guard retains a shorter, heavier planted gait and reduced weapon-arm swing. Grapple and fall retain refined single-state silhouettes; this checkpoint does not claim the separate multi-stage grapple-pose milestone.

Accepted default-camera evidence: pre-pass `captures/courtyard_3d_2026-09-03_22-11-15_925530.png`; final reset `captures/courtyard_3d_2026-09-03_22-30-18_349987.png`; medium/small/large presets `captures/courtyard_3d_2026-09-03_22-24-42_13396.png`, `captures/courtyard_3d_2026-09-03_22-24-47_18363.png`, and `captures/courtyard_3d_2026-09-03_22-24-52_23430.png`; alternate accent `captures/courtyard_3d_2026-09-03_22-24-59_30980.png`; travel-facing `captures/courtyard_3d_2026-09-03_22-25-23_55179.png`; close spacing `captures/courtyard_3d_2026-09-03_22-25-47_78355.png`; grapple-ready `captures/courtyard_3d_2026-09-03_22-28-01_213038.png`; perch walk `captures/courtyard_3d_2026-09-03_22-28-58_269320.png`; edge fall `captures/courtyard_3d_2026-09-03_22-29-16_288274.png`; and changed camera plus camera-relative travel `captures/courtyard_3d_2026-09-03_22-29-54_326207.png`.

`captures/gloam-character-natural-motion-final00000000.png` through `captures/gloam-character-natural-motion-final00000039.png` are 40 valid 960×600 normal-renderer frames at 12 FPS. Frames 5–10 show the player traveling with articulated opposite gait; frame 15 shows smooth grounded recovery; frames 24–30 show the return direction, while the guard patrols, turns, and alerts. First/last SHA-256 values differ (`eab555…` versus `16ded7…`).

The existing deterministic regression probe again passed 1.48-unit separation for both movers, combat reach at the boundary, grapple/perch landing, perch walking, edge fall, floor landing, perch-height attack rejection, exit success, restart cleanup, and spawn restoration. Headless editor/runtime checks exited 0 without parse or scene failure. The macOS Application Support/log/certificate messages remained benign sandbox warnings. Live smoke interaction exercised movement, close combat, guard defeat, grapple readiness/landing, perch travel/fall, restart, orbit/pitch/zoom/reset, and camera-relative travel. Screenshot pauses again exceeded the combat window and allowed guard damage during staged inspection; that is the existing automation-timing limitation rather than a changed gameplay defect. Silent takedown remains spatially unreachable.

## Complete — multi-stage grapple pose states (2026-09-03)

The player grapple now uses the accepted articulated pose interface as a progress-driven action. It begins with a crouched launch coil, extends an asymmetric lead arm overhead, lengthens the legs and hips through transit, prepares the feet and hips on approach, compresses knees/ankles/torso/arms on landing, and eases back to the grounded stance over a separate 0.32-second recovery. The recovery is visual only and does not block immediate perch movement. Existing body presets, accent colors, travel-facing, collision, route feedback, and camera behavior remain unchanged.

The deterministic grapple probe passed: activation inside the ring, traversal duration `0.32 ± 0.04` seconds, exact perch landing position, perched/grounded landing flags, recovery timer activation, movement during recovery, and restart cleanup. The full character-foundation regression also passed again, including both separation directions, close-combat reach, perch walk/fall/land, height-aware attack rejection, exit success, and restart. Headless editor/runtime checks exited 0 without parse or scene failure; only the known macOS log/certificate/editor-settings sandbox warnings appeared.

Accepted sequence evidence: `captures/gloam-grapple-poses00000000.png` through `captures/gloam-grapple-poses00000027.png`, 28 valid 960×600 normal-renderer frames at 30 FPS. Frames 2–5 show launch and asymmetric transit reach; frame 8 shows the approach silhouette; frames 11–15 show landing compression and recovery; frame 20 is the restored grounded stance. Live default-camera evidence: `captures/courtyard_3d_2026-09-03_22-49-41_71055.png` (`GRAPPLE READY`), `captures/courtyard_3d_2026-09-03_22-49-49_79394.png` (`IN TRANSIT`), and `captures/courtyard_3d_2026-09-03_22-49-55_84930.png` (landed on the perch). Live smoke also exercised perch walking, edge fall and floor landing, restart, changed-camera camera-relative movement, rapid combat/guard defeat, default reset, and F12.

Screenshot pauses again exceeded the combat window and let the guard drain health while staging the grapple captures. This is the accepted automation-timing limitation, not a mechanics regression. `captures/courtyard_3d_2026-09-03_22-50-55_144888.png` is the final fresh 100-health/0-Momentum/guard-100 default-state handoff left open for playtest.

## Complete — combat poses, reactions, and guard defeat (2026-09-03)

Combat now uses explicit visual states without changing the validated mechanic values. A player strike turns toward the guard, loads through the legs/torso, lunges visually, and recovers; counter braces and redirects across the body. The warden exposes a watch-blade windup/cut telegraph, receives a hit-side-aware full-body stagger, and returns cleanly as the existing stun expires. Defeat cancels attack and vision state, folds the warden into a grounded side collapse, delays the fade until the body settles, then removes the visual and label at 1.45 seconds. The defeated actor is excluded from personal-space resolution so the removed visual cannot leave an invisible blocker. Restart restores opacity, visibility, labels, timers, pose, and spawn state.

The combat-specific deterministic probe passed all completion bars: strike remains 22 damage/13 Momentum/0.32-second reaction; hit-side changes reverse the stagger; perfect counter remains 30 damage/28 Momentum/0.55-second reaction; ordinary counter remains non-damaging with 8 Momentum/0.25-second reaction; an uncountered guard hit remains 18 damage; defeat clears vision and the attack marker; fade begins only after the collapse delay; removal completes at 1.45 seconds; post-removal movement crosses the former guard position; and restart restores the complete guard and clears all new timers. The full character-foundation and grapple probes also passed again, including 1.48-unit separation, close-combat reach, exact 0.32-second grapple, perch walk/fall/land, height-aware attack rejection, exit success, and restart.

Accepted sequence evidence: `captures/gloam-combat-poses00000000.png` through `captures/gloam-combat-poses00000103.png`, 104 valid 960×600 normal-renderer frames at 30 FPS with different first/last hashes (`42e91b…` versus `850237…`). Frames 3–10 show strike and stagger recovery; 24–31 show the warden telegraph; 32–42 show perfect counter and reaction; 54–78 show the grounded collapse; 79–97 show delayed fade; frame 98 shows complete removal. Live evidence: `captures/courtyard_3d_2026-09-03_23-16-40_31074.png` (strike/reaction), `captures/courtyard_3d_2026-09-03_23-17-41_91777.png` (defeat begins), and `captures/courtyard_3d_2026-09-03_23-18-01_111610.png` (removed). Live movement crossed the former guard position, and restart/camera-relative movement/default reset passed.

Headless editor/runtime checks exited 0 with no parse or scene failure. The macOS Application Support/log/certificate output remained benign sandbox noise. Screenshot pauses again exceeded the combat windows and allowed player health to drain during staged inspection; the deterministic timing probe and runtime sequence covered counter correctness. `captures/courtyard_3d_2026-09-03_23-18-52_162844.png` is the final fresh health-100/Momentum-0/guard-100 default-camera handoff left open for playtest.

## Complete — directional evade roll (2026-09-03)

`C` now chooses current held camera-relative movement when available, otherwise the last meaningful camera-relative travel direction, with a forward-facing fallback after restart. Movement updates the remembered direction only after a real camera-relative step. The player faces the evade path and performs a low articulated tuck, head cover, full forward somersault, untuck, and grounded recovery around a player-local center pivot; the gameplay root and floor footprint do not rotate.

The evade-specific deterministic probe passed all completion bars: stationary fallback, remembered camera-relative direction after orbit, facing, exact 0.28-second movement, exact 0.42-second invulnerability, +4 Momentum, unchanged slide displacement, unchanged camera state, damage rejection during invulnerability and resumption afterward, full-body mid-roll rotation, low floor clearance, stable action-pivot recovery, and restart cleanup. The character-foundation, grapple, and combat probes all passed again, including separation, combat reach, exact grapple landing/timing, perch travel/fall/land, damage/Momentum values, defeat/removal, exit, and restart. Headless editor checks exited 0 with no parse or scene failure; the macOS Application Support/log/certificate output remained benign sandbox noise.

Accepted sequence evidence: `captures/gloam-evade-roll00000000.png` through `captures/gloam-evade-roll00000047.png`, 48 valid 960x600 normal-renderer frames at 30 FPS with different first/last SHA-256 values (`42e91b...` versus `8077b5...`). Frames 2-10 show the first tuck/somersault/recovery, frames 24-32 show the opposed remembered direction, and frame 47 is neutral. Live evidence: `captures/courtyard_3d_2026-09-03_23-29-10_15606.png` (remembered travel), `captures/courtyard_3d_2026-09-03_23-29-16_22021.png` (camera-relative travel after orbit), and `captures/courtyard_3d_2026-09-03_23-29-22_27802.png` (stationary restart fallback). Live combat input still drives the strike pose, and `captures/courtyard_3d_2026-09-03_23-30-25_91525.png` confirms the grapple still reaches the elevated perch. Screenshot pauses again exceeded the combat/evade windows, so deterministic probes remain the timing authority. A clean final relaunch was reacquired as `Gloam Courtyard Spike (DEBUG)`; `captures/courtyard_3d_2026-09-03_23-35-18_8921.png` verifies health 100%, Momentum 0%, guard 100, reset objective, and default camera, and the build was left open for playtest.

## Complete — crouch mechanic and clearance (2026-09-03)

`Q` now toggles a low articulated stance with bent hips/knees/ankles, forward-balanced torso, head compensation, compact arms, coat-tail lift, and a reduced gait. Crouch movement is exactly 62% of standing movement. A visible optional passage beside the darkness zone has a measured 2.0-unit lintel: standing entry is blocked, crouched travel enters, standing and evade are rejected while underneath, and normal height returns after clearing it. Restart clears crouch and restores spawn; the camera is unchanged.

The crouch-specific probe passed all completion bars: standing reset, crouch entry, action pivot below 0.61 while upright, standing passage blockage, crouched entry, forced low profile, evade rejection under the lintel, clean exit, exact 62% tap movement, camera invariance, and restart. The foundation, grapple, combat, and directional-evade probes all passed again with their exact accepted movement, timing, damage, Momentum, landing, fade/removal, camera, success, and restart values. Headless editor checks exited 0; only the known macOS sandbox warnings appeared.

Accepted sequence evidence: `captures/gloam-crouch-clearance00000000.png` through `captures/gloam-crouch-clearance00000053.png`, 54 valid 960x600 normal-renderer frames at 30 FPS with different first/last hashes (`c99ec6...` versus `592f81...`). Frames 2-8 show blocked standing approach, frames 14-36 show low entry/travel and rejected standing underneath, and frames 43-53 show full-height exit. The final route was narrowed and shifted to the far-left darkness edge after the reset review exposed partial spawn occlusion; the replacement sequence verifies the same mechanics without compromising the default composition. Live evidence: `captures/courtyard_3d_2026-09-03_23-41-02_8894.png` (entry) and `captures/courtyard_3d_2026-09-03_23-41-13_19435.png` (low-speed camera-relative travel). A clean final relaunch was reacquired as `Gloam Courtyard Spike (DEBUG)`; `captures/courtyard_3d_2026-09-03_23-47-12_12207.png` verifies the unobstructed reset spawn, visible far-left passage, health 100%, Momentum 0%, guard 100, and default camera, and the build was left open.

## Complete — jump/vault foundation (2026-09-03)

`V` now performs a bounded free jump or contextual vault using the last meaningful travel direction. Free jump is exactly 0.62 seconds with a 1.35-unit apex and 2.2-unit landing distance. A projected path through the visible low barrier instead selects a 0.48-second vault with a 1.05-unit apex. Walking is blocked by the barrier; the vault clears it and restores grounded state. Both actions use progress-driven takeoff, airborne, and landing poses. Low-passage bypass, active traversal, and insufficient landing room are rejected; ordinary damage remains active and the camera is unchanged.

The jump/vault probe passed barrier collision, contextual selection, exact vault/jump metrics, midpoint apexes, forward vault silhouette, obstacle clearance, grounded landing, exact free-jump distance, ordinary airborne damage, camera invariance, low-passage rejection, boundary rejection, and restart. Crouch, directional evade, foundation, grapple, and combat probes all passed again. The optional barrier was moved to the front-right edge after its first placement intersected the accepted evade regression; the final placement preserves exact evade displacement. Headless editor checks exited 0 apart from known macOS sandbox warnings.

Accepted sequence evidence: `captures/gloam-jump-vault00000000.png` through `captures/gloam-jump-vault00000055.png`, 56 valid 960x600 normal-renderer frames at 30 FPS with different first/last hashes (`dd6d19...` versus `810e99...`). Frames 2-22 cover free-jump takeoff/apex/landing; frames 27-41 cover contextual vault approach/clearance/landing; frame 55 is stable. Live evidence: `captures/courtyard_3d_2026-09-03_23-53-39_10331.png` after the bounded live `V` jump.

## Complete — reachable courtyard silent-takedown route (2026-09-04)

A visible 1.6-unit ambush shadow now overlaps the warden's left patrol turn. From reset, seven default-camera `D` taps enter concealment; the warden turns toward the next patrol point and exposes its back inside the existing 2.1-unit takedown range, so `T` succeeds without helper positioning or rule changes. The original darkness remains valid. Outside-shadow and frontal attempts still fail, defeat uses the accepted collapse/fade/removal timeline, and restart restores the guard.

The stealth-route probe passed concealment, range, behind direction, successful guard defeat, measured shadow boundary, original darkness preservation, frontal rejection, and restart. The normal-renderer sequence `captures/gloam-stealth-route00000000.png` through `captures/gloam-stealth-route00000057.png` contains 58 valid 960x600 frames at 30 FPS with different first/last hashes (`c9bc87...` versus `b2909d...`); frames 2-10 establish the route, frame 12 triggers, frames 16-50 show defeat/fade, and frame 57 shows removal. Live evidence `captures/courtyard_3d_2026-09-04_00-01-42_11671.png` and `captures/courtyard_3d_2026-09-04_00-02-14_43359.png` verifies the seven-tap approach and `GUARD DOWN` result with health 100% and Momentum 35%.

## Complete — actor-only animation polish (2026-09-04)

`actors/character_visual_builder.gd` now gives the verified action states sharper state-local response without changing the pose API, controller, mechanic constants, scene, or project configuration. Grapple landing/recovery is continuous; evade plants through a two-leg absorption; crouch has planted asymmetry and slower core/cloth settling; jump and vault use distinct load/flight/landing curves; strike and counter make contact/redirect earlier; and the warden holds its telegraph before a decisive cut and timed stagger recovery.

The complete foundation, grapple, combat, evade, crouch, jump/vault, and stealth probes passed against the final shared file. The fixed-60-FPS grapple timing check measured `0.3167` seconds against the accepted `0.32 ± 0.04` bar; the uncontrolled wall-clock probe can undersample under process scheduling, so the deterministic fixed step remains timing authority. The dedicated animation-polish probe passed grapple handoff continuity, evade landing, crouch profile/gait, jump/vault distinction, strike/counter silhouettes, warden telegraph, and finite transforms. Headless editor/runtime checks had no parse or scene failure; only known macOS sandbox warnings appeared.

Accepted normal-renderer evidence: `captures/gloam-animation-polish00000000.png` through `captures/gloam-animation-polish00000203.png`, 204 valid 960x600 frames at 30 FPS with different first/last hashes (`51ecbe...` versus `0ab8c1...`). Reviewed frames 5, 25, 53, 78, 100, 120, 149, 166, 183, and 203 cover neutral, crouch, jump, vault, evade, grapple, strike, warden telegraph, counter, and stable recovery without observed clipping or pose pop.

Live smoke input on a freshly reacquired `Gloam Courtyard Spike (DEBUG)` exercised crouch, camera-relative travel, directional evade (+4 Momentum), free jump/recovery, strike/warden reaction, orbit/pitch change, `0` camera reset, restart, and F12. Screenshot observation again exceeded the combat window and allowed the warden to drain health during the staged strike; restart restored the full accepted state. `captures/courtyard_3d_2026-09-04_00-19-31_116330.png` (`ff9f0f...`) is the final 100-health/0-Momentum/guard-100 default-camera handoff left open for playtest.

## Complete — isolated Riven Lantern Ward gray-box (2026-09-04)

The new `levels/riven_lantern_ward/riven_lantern_ward.tscn` and `.gd` form a non-default, controller-free spatial study. The measured 38 × 28 ward contains a 14 × 10 combat core; ground, covered, elevated, and one-way loopback route ideas; four concealment pockets; an exact 2.0-unit crouch lintel; a 0.84-unit obstacle below the 1.05 vault apex; 1.80/1.65-unit gaps below the 2.2 jump reach; and 3.40/3.35-unit horizontal opportunities inside the 3.5 grapple range. Primitive collision and measurement metadata are present, but the scene does not claim gameplay integration.

Headless editor parse and isolated runtime exited 0. `RIVEN_LANTERN_WARD_VALIDATION PASS` confirmed every declared measurement. `captures/riven-lantern-ward-overview00000000.png` and `captures/riven-lantern-ward-overview00000001.png` are two valid 960x600 normal-renderer frames with the identical expected static hash `b627f7...`; visual review confirms the route legend, spatial layers, boundaries, and affordance labels are legible.

## Deferred — choose the integration shape

Both previously parallel evidence packages are accepted. Before any default-file integration, choose whether Riven becomes a separate playable scene, expands/replaces Lower Court, or remains a static route reference. That choice materially changes controller ownership, project launch flow, and smoke/evidence scope. After it is explicit, implementation is sequential and single-owner.

## In progress — authored Gloam Vigil player (2026-09-04)

Initial review was rejected: `captures/courtyard_3d_2026-09-04_15-41-30_25898.png` and `captures/gloam-vigil-rig-defect-framed00000002.png` exposed an actual folded-limb defect from replacing imported local rest rotations with identity-relative driver rotations. The rest-space adapter correction was visible in `captures/gloam-vigil-rest-corrected00000002.png`, but source anatomy still looked too toy-like in `captures/gloam-vigil-neutral-blender.png`; this prompted the substantial anatomy pass verified later below. These remain diagnostic images, not completed appearance evidence.

Completion requires: clean import/editor/runtime; neutral bind-pose preservation and meaningful deformation checks; courtyard mechanics regression; clear neutral/front-three-quarter and default-camera before/after views; normal-renderer neutral/walk/crouch/jump/vault/evade/grapple/strike/counter/fall/recovery evidence; live body/accent customization and smoke play; a candid bug/quirk review; docs and regenerated/verified local board; then a fresh exact-title DEBUG handoff. The initial finite-transform probe passed but cannot establish anatomical correctness. Its dummy-renderer material-null shutdown output is a separate diagnostic issue from macOS sandbox certificate/log noise.

### Integration review and rejected deformation evidence (2026-09-04, afternoon)

`captures/gloam-vigil-muscular-final.png` records the stronger connected shoulder/arm/thigh source revision. It is a neutral-source appearance review, not an action or final-realism acceptance image. The long/simple neck, faceted face/torso, coarse fitted-suit detail, and non-physical cape remain explicit quality limits. The source is original script-authored geometry/textures with an editable Blender file, 20 bones and 12 standard PBR materials. No downloaded or paid assets were used.

The 107-check mechanics probe passed with no script error. Import/editor and headless default runtime exited 0; unrelated macOS log, CA-certificate, and editor-settings sandbox output was not a gameplay failure. Full CPU skinning caught two failures missed by finite-transform checks: ankle vertices assigned to pelvis and lower sleeves assigned to legs. The first correction restored sole contact, but `captures/gloam-vigil-weight-corrected-motion00000162.png` still exposed thin sleeve/leg ribbons from physically welded semantic limb regions. The earlier `captures/gloam-vigil-muscular-motion00000162.png` showed the gross sleeve stretch. Both sequences are retained as rejected deformation evidence and prompted the later semantic-component topology repair.

After the first weight correction and a deeper anatomical core fold, a 499-check strict probe passed rest preservation, joint direction, finite CPU-skinned vertices, ±0.03-model-unit grounded contact, stable recovery/root/scale, and six medium/large static/full-stride clearance tests. Medium static top was 1.958843 world units; large static top was 1.940750, both below the 2.0-unit lintel. Moving extrema were lower. This snapshot did not excuse the ribbon defect; it was later rerun and expanded to 511 strict checks after the final export and sequential-pose fixes. `captures/courtyard_3d_2026-09-04_16-26-56_111535.png` verifies an interim live reset/crouch/movement/F12 result; the subsequent interrupted stealth attempt is not accepted because unexpected input/window state contaminated it, without a confirmed cause.

Local board verification has a separate tool-level blocker. At 21:51:47 UTC, `cua_repl.js` calling `cua.createBrowserTab("iab", "file:///Users/markabraham/dev/batman/work/project-roadmap-local.html", {visible:true})` was rejected by Browser Use URL policy, explicitly prohibiting achieving the same outcome through workarounds, alternate browser surfaces, or indirect execution. This was not a shell auto-approval rejection. No bypass was attempted. Source JavaScript syntax/unique IDs and source-to-wrapper parity passed separately; current rendered interactions/responsive widths remain unverified and require permitted browser access or user verification. Keep the board task in progress until its full contract is met.

## Verified runtime — first original Gloam Vigil integration (2026-09-04; board handoff pending)

The authored player is runtime-verified as a first original-superhero iteration, not as the user's final realism objective. The stable GLB SHA-256 is `deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`. It has one skinned mesh, 20 unchanged rig joints, 12 material surfaces, UVs/normals/tangents and normalized weights; Godot evaluates 97,061 vertices. Native bounds remain 0.944 × 0.593 × 2.175 m. The semantic repair above is complete: export gates report zero arm-leg edges, zero cross-leg edges below the pelvis, zero hard shoulder edges, and maximum shoulder weight L1 difference 0.3995. Historical rejected sources/captures are preserved.

Final verification passes: 107/107 courtyard mechanics checks and 511/511 strict deformation checks. Zero-driver local-rest rotation error is zero; maximum joint-origin error is 2.98e-8. Full CPU-skinned grounded contact is within ±0.03 model units; all sampled actions/recoveries remain finite, bounded and free of root/scale drift. Medium static crouch top is 1.958843 world units, large is 1.940750, with moving poses lower. Actual scene instances clear the 2.0-unit lintel on the first crouch frame inside the passage. In sequential 60-Hz evade samples, the former inverted-mask penetration is corrected to +0.046044 m (medium) and +0.053411 m (large), and upright landing soles remain above the floor. The roll arc/contact and in-passage pose constraint are visual-only; gameplay displacement, timing, collision and invulnerability remain unchanged. Editor/import/default headless runs exit 0 with no script/scene error; macOS log/CA/editor-settings sandbox warnings remain separate benign output.

Verified normal-renderer evidence, all 960×600 at 30 FPS:

- `captures/gloam-vigil-semantic-components-neutral.png`: unchanged neutral anatomy after semantic topology repair.
- `captures/gloam-vigil-verified-actions00000000.png` through `...00000359.png`: 360-frame equal-scale old/new studio comparison. Reviewed neutral20, walk43, crouch78, jump112, grapple162, evade223 and strike253, plus the actual-game views below. Old remains neutral as a silhouette reference; new action phases are deliberately stretched for inspection, not gameplay timing. First/last hashes are `7713fcc0…` / `aeacd5ae…`.
- `captures/gloam-vigil-verified-gameplay00000000.png` through `...00000329.png`: 330-frame actual default-scene action sequence. Movement/crouch, jump/vault, evade, grapple/recovery/perch fall, strike, perfect counter, takedown and reset execute real gameplay methods. Selected helper positions and a prepared counter window make this deterministic; it is not ordinary-input evidence. Frames108/130/156/188/243 show vault/roll/grapple/fall/counter. Logged Momentum is 4 after evade, 13 after strike, 41 after counter and 35 after takedown, with reset to 0. First/last hashes are `145b2617…` / `4de4511c…`.

Fresh live DEBUG smoke used only visible keyboard input: body1/X (`captures/courtyard_3d_2026-09-04_16-39-34_26760.png`), body3/X/crouch/travel (`...16-40-00_52476.png`), reset/body2 and seven D taps plus a bounded T burst (`...16-40-37_89416.png`, guard removed, health100/Momentum35). Ordinary movement reached the ready ring (`...16-41-52_164570.png`); G landed on the perch (`...16-42-02_174509.png`); three D taps completed the courtyard (`...16-42-14_186625.png`) with health100/Momentum35. Separate reset/evade/jump gave +4 Momentum and a landed message (`...16-42-37_209638.png`). Reset/seven D taps/rapid strikes defeated the guard at health100/Momentum100 (`...16-43-53_285496.png`). Orbit/pitch/travel changed the view (`...16-44-01_294205.png`), and zoom-key dispatch/default reset/restart restored the scene (`...16-44-11_303899.png`). The interrupted earlier camera/stealth attempts are not used as success evidence. F12 still writes project-local PNGs with `captures/.gdignore` present.

Quirk/quality review: no old folded limbs, sleeve ribbons, cross-leg web, measured crouch-ceiling overlap or roll-head floor clip remains in the accepted samples. The face/neck still have simple proportions and faceting; broad suit bands lack sculpted anatomy/cloth detail; fingers do not articulate; the two-bone cape is not simulated and remains stiff in the roll. Guard health-label text can lag its actual damage during stun in deterministic captures; mechanics values pass. Screenshot/control latency can outlast reactive windows and permit damage while staging, so fixed-step timing evidence remains authoritative. The next substantive character task is the original facial/fitted-suit sculpt, deliberate retopology and baked-detail comparison described in the asset README; Riven is still deferred.

The overall task is **not Complete**: current browser board interaction/responsive verification remains blocked by the exact URL-policy denial above. Docs, six current board tasks/lanes (including the newly logged Later health-label quirk), source syntax/13 unique DOM IDs, and source-wrapper parity are kept current separately.

Final fresh handoff: the prior DEBUG run was closed normally, shutdown confirmed by inventory alone, and the default project relaunched. It was reacquired as exact `Gloam Courtyard Spike (DEBUG)` and left open at the default medium/pink-accent state with health100/Momentum0/guard100 and the reset objective. `captures/courtyard_3d_2026-09-04_16-49-37_19394.png` records that verified handoff. No gameplay source changed after this relaunch.

## In progress — character quality v2 (2026-09-04)

User approved the richer character/animation plan after the feasibility review. Read-only GLB inspection confirms the v1 baseline: 172,620 triangles, 97,061 vertices, 20 rig joints, 12 surfaces/materials, twelve 128×128 albedo textures, zero normal maps, zero morph targets and zero authored animation clips. Local hardware reports M4 Pro (14 CPU / 20 GPU cores), 24 GB memory; the active project uses GL Compatibility. These are inventory facts, not a performance result.

Live pre-change reset/F12 evidence: `captures/courtyard_3d_2026-09-04_17-04-13_895408.png`, health100/Momentum0/guard100 and default camera. The accepted DEBUG was then closed normally and absent state confirmed before isolated baseline measurements. New candidate authoring, motion and benchmark tracks remain in progress; no v2 quality or FPS acceptance is claimed.

V1 performance baseline (normal renderer, not movie/headless): `/private/tmp/gloam-vigil-performance-benchmark.gd` verified GL Compatibility/OpenGL3, disabled vsync, no engine FPS cap and exact 1920×1080 window/root/visible/texture sizes. An initial Retina/stretched 3111×1944 mismatch was rejected before sampling; the valid harness locks the root render texture explicitly. After independent ≥3-second/120-frame warmups, 600 samples per case measured courtyard median/p95/p99 wall frame times 4.130/5.340/5.617 ms, versus 16.664/17.036/17.292 ms with eight additional animated visual-only player copies. The latter is not eight enemy AIs and does not establish a supported encounter count. GPU timings are unavailable; engine CPU monitors are retained separately and have different reporting cadence. Exact 60-Hz-like stress pacing may include presentation behavior despite requested uncapping and is not proof of a GPU ceiling. Full initial protocol/results are in `work/character-quality-benchmark/README.md`; longer paired v1/v2 sampling remains required before final acceptance.

V2 revisions 1 and 2 were rejected in independent studio anatomy review; neither is the playable default or accepted completion. Revision 1 passed the GLB structure audit, but an all-mesh/morph deformation audit found ten real medium/large moving-crouch lintel misses (approximately 2–28 mm), plus three diagnosed numerical false positives in the old quaternion-angle comparison. The numerical comparison was corrected without widening its tolerance; revised geometry still needs a fresh full run. Revision 2 improved eye color, boot closure and cloth restraint but retained mannequin head/neck proportions and disconnected shoulder/brow shapes. Preserved before/rejected captures and specific defects are recorded in `work/character-quality-review.md`. The next candidate changes the head profile and neck/shoulder construction; triangle/bone counts are not a substitute for this visual gate.

### Technical prototype verified; r4 art rejected (2026-09-04)

Frozen candidate SHA-256 `a786d082fb1b9aea0d383dd0a06e0c43826b20bf35b4edb4b60ea50b2882ee3b` is authoring revision 4. The first root Godot capture names mistakenly say r3; `captures/gloam-v2-r3-face-front-reviewed00000004.png` actually compares v1 against this r4. Independent review rejects nose/mouth tearing, shallow sockets, abrupt jaw/neck, long column-like neck and disconnected shoulder/chest shapes. **V1 stays default; the realism milestone is not complete.** Source/renders/GLBs and exact preservation/reconstruction limitations are recorded in `actors/gloam_vigil/v2/revision_manifest.json` and the v2 README. No purchased/downloaded geometry, manual sculpt/retopology, motion capture or completed high-to-low texture bake is claimed.

Structure/import facts: 83,632 triangles, 50,940 exported/runtime vertices (42,024 authoring vertices), 74/74 weighted bones, five unique PBR materials across seven draw surfaces, four real morph targets, five explicit authored Godot Animation resources. Full sparse-accessor GLB validation passes, including UV/normals/tangents, influence normalization, morph values and index/buffer bounds. Actual imported RenderingServer inspection finds 35 valid LOD index buffers across all seven surfaces. These reduce triangle indices but reuse full vertex/morph data; they are not skinned-vertex/morph-memory LODs. Normal maps are 2K for skin/suit, 1K for gear/boot/accent. The shader detail is procedural, not an anatomical sculpt bake.

Final technical checks pass: 2,763/2,763 full-mesh/active-morph deformation checks across three body presets, sampled walking/crouch/action/recovery states and bind/root/scale preservation; v1 remains 511/511, courtyard mechanics 107/107, five authored clips and the v2 runtime articulation/morph contract pass. Five r4 large-preset crouch misses (up to 10.35 mm) were corrected by an additional 0.035 rad visual-only torso fold multiplied by large-preset weight. It does not touch the v1 pose, actor root, collider, crouch speed or timing. The ankle-lock fixture at gameplay speed measures 0.02408 m maximum full-lock drift at 60 Hz versus 0.59842 m unlocked, and 0.02129 versus 0.59836 m at 30 Hz. Reach-limit rejection, swing/turn/action/teleport release and exact gameplay-root preservation pass. This is not slope/stair IK or a guarantee of production-quality gait.

Normal-renderer technical evidence: 360 frames `captures/gloam-v2-r4-technical-actions00000000.png` through `...00000359.png` at 960×600/30 FPS (first/last hash prefixes `db5b4a13` / `4e1ce50a`), reviewed walk43/crouch78/roll223/strike253. Both models use the same light/scale and deliberately stretched action phases. Actual-courtyard fixture: 330 frames `captures/gloam-v2-r4-technical-gameplay-clean00000000.png` through `...00000329.png` (hashes `72dbd098` / `e0358e1a`), reviewed move25/grapple156/counter243. Recorded Momentum is 4 after evade, 13 after strike, 41 after counter, 35 after takedown and 0 after reset. Helper positions/prepared timing mean this is not ordinary-input evidence, and movie timing is not a performance benchmark. Guard label lag during stun remains the known Later quirk.

Diagnostic fixes are recorded separately from benign macOS warnings: the initial face fixture entered before SceneTree readiness and was corrected to defer construction; the first actual-scene replacement freed live material overrides and emitted real GL dependency errors. Clearing overrides before freeing fixed the clean replacement capture. Failed captures remain preserved. All final diagnostic script/scene checks are clean; sandboxed user-log/CA/editor-settings messages are still reported as environment noise, not gameplay failures.

Technical reproduction scripts now have a stable, explicitly invoked home in `work/character-quality-benchmark/`, never referenced by the default scene. Paired performance and fresh default live smoke remain the final evidence to record for this technical checkpoint; v2 art/integration still waits for an acceptable model and scoped next-art direction.

Final paired performance completed cleanly on the frozen asset/adapter state: three independent ≥3-second/120-frame warmups and three ≥10-second/600-frame samples per case, exact 1920×1080 window/root/render texture, GL Compatibility/OpenGL3, requested vsync off and no FPS cap. Actual courtyard v1/v2 median/p95/p99 are 4.052/5.307/5.681 ms versus 4.089/5.319/5.737 ms; mean frame time increases 0.45%. Artificial real-courtyard-plus-eight-visual-copies median/p95/p99 are 16.656/17.128/18.557 versus 16.665/18.959/21.449 ms. V2 reduces draw calls but increases stress tails; the eight static-root copies do not solve stance-lock IK, so do not attribute that change to IK alone. No usable GPU timer was returned; near-60 stress pacing is not a GPU-ceiling or nine-enemy claim. One early sandbox launch stalled before the engine/renderer banner, was excluded, and the managed normal-permission relaunch supplied the clean runs. Full sample counts, CPU monitor data, limitations and exact reproduction commands are in the benchmark README.

Fresh accepted-default v1 live smoke after the shared adapter changes used only ordinary keyboard input, never helper positions: large/accent/crouch/travel (`captures/courtyard_3d_2026-09-04_17-55-42_43760.png`); shadow approach, then successful silent takedown after one further D step beyond the initial seven-tap attempt (`...17-58-12_194074.png`, health100/Momentum35); ordinary travel including a visible out-of-range grapple rejection, then ring entry and successful landing (`...18-00-21_323021.png`); three D taps reach `COURTYARD CLEAR` (`...18-00-41_342821.png`, health100/Momentum35). Small/accent/crouch/evade recovers with Momentum4 (`...18-00-51_352957.png`); free jump lands with changed orbit/pitch and camera-relative travel (`...18-01-18_379882.png`). Default-camera reset/restart, movement and a bounded close-range Space burst defeat the guard at health100/Momentum100 (`...18-03-50_532225.png`). Earlier takedown/strike bursts outside their valid windows/ranges are not success evidence. W/S screen-direction convention was observed and logged for a separate review, with movement code unchanged. F12 continues to write project-local PNGs. The smoke run was then closed normally and absent-app inventory confirmed before final fresh handoff.

Final fresh handoff: reacquired exact `Gloam Courtyard Spike (DEBUG)` after normal relaunch; `captures/courtyard_3d_2026-09-04_18-06-18_18228.png` verifies v1/default medium/pink accent, health100/Momentum0/guard100, reset objective and default camera. The game is left open. No gameplay source changed after launch. Current docs and ten board tasks retain the art-direction and board-UI gates; one valid inline script, 13 unique DOM IDs and source/wrapper parity are checked separately from the still-policy-blocked browser interactions and responsive review. No v2 art release or overall completed realism milestone is claimed.
