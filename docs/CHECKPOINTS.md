# Checkpoints

## Waiting — R14 narrower leg lanes and forward knee tracking (2026-09-08)

User visual rejection reopened the prior gait acceptance. The old four-frame
unsigned stance test was insufficient. The grounded presentation now solves
ankle lanes relative to posed hip span and rotates the knee bend plane about
the hip-to-ankle chord. It preserves bone lengths, included knee flexion, ankle
fore/aft endpoint and foot attitude; no asset/controller/action changes.

Matched 60 Hz authored-space ankle mean/max: 0.3586/0.4134 before,
0.2393/0.2492 after (about 33%/40% narrower). Knee mean/max is 0.2522/0.2586.
Signed full-cycle gates pass at all three body presets and both 30/60 Hz;
calf/ankle lanes stay on their own side within 0.65–1.08 of hip span. The new
world-space report retains the 1.35 base/preset scale; do not mix its metre
values with authored-space values. Stop blend settles in 3/5 frames at 30/60.

Fresh checks: stance 365, alignment 10, full-cycle six cases, default/candidate
mechanics 200/202, attacks 352, transitions 67, both-rate locomotion and support,
full-mesh deformation 21,642, headless import and default startup pass.
Matched normal-renderer reels `captures/r14-leg-tracking-before*` and
`captures/r14-leg-tracking-final*` cover idle/start/sustain/release in profile,
front, three-quarter and default camera. Independent review confirms straighter
calf tracking without visible new penetration; close crossover frames remain
an occlusion limitation, not exhaustive self-collision proof.

Native review: exact-title `Gloam Courtyard Spike (DEBUG)`, current R14 SHA,
PID30109. C finished at +4 Momentum, Q visibly crouched, body-size/reset/F12
worked. SPACE was exercised but its sub-second contact was not captured.
Continuous held gait evidence is deterministic, not native keyboard holding.
Fresh reset medium/default-camera F12 was opened and verified:
`captures/courtyard_3d_2026-09-08_11-19-40_103804.png`.
Window left ready for user play. Previous PID28090 handoff is superseded.

Full report and limitations:
`work/character-art-review/reports/2026-09-08-r14-leg-tracking.md` plus sibling
JSON. The source flight pose, foot sliding and wider crouch/combat transitions
remain possible polish work. Geometry is unchanged; no new paired performance
certificate is claimed. User movement judgement still gates release; V1 stays
default. The older checkpoint below is preserved historical evidence.

## Preserved checkpoint ledger

The [complete ledger through source checkpoint 5bfd290](history/2026-09-08-5bfd290/CHECKPOINTS.md)
retains every earlier completion bar, accepted/rejected capture, native-input limit,
performance protocol and superseded direction. These linked checkpoints remain
part of the acceptance record; current state supersedes their historical “current”
claims. In particular, old numerical gait passes are not user movement acceptance.

The feedback-loop experiment is recorded in [FEEDBACK_LOOP_RESULTS.md](FEEDBACK_LOOP_RESULTS.md).
New checkpoints append here with the exact source identity and evidence path.

## Verified tooling — reproducible feedback and preservation (2026-09-08)

Private Git source control is established at `mabraham23/gloam-courtyard`.
Two exact-source frozen runs produced210/210 byte-identical frames in21.056 and
19.662seconds. A matched changed-code/same-GLB run distinguishes the rig revision;
the277-frame action fixture also passes. Phase-aware action keyframes correct a
real sampling failure in the initial uniform contact sheet.12 tooling tests,
Godot script import, board schema/syntax/parity, exact archived-document hashes,
all28,553 eligible historic PNG hashes, silent-WAV restoration and a downloaded
13-file private milestone archive restoration pass.

Detailed evidence, measured limits and unresolved board UI gate are in
[FEEDBACK_LOOP_RESULTS.md](FEEDBACK_LOOP_RESULTS.md). This is tooling acceptance;
it does not promote R14, certify user movement judgement or close the board's
rendered interaction/responsive gate. Native managed-launch handoff is recorded
separately after it is observed.

## Verified native managed review and GitHub recovery (2026-09-08)

A fresh private GitHub clone at `d696fd7` rendered the277-frame action fixture in
27.303seconds with a runtime-loaded R14 SHA assertion and the corrected phase
keyframes. Default200 and candidate202 mechanics, committed evidence hashes and
original BVH bytes pass. See `evidence/2026-09-08-github-recovery/`.

The managed native launcher now resolves the actual macOS app executable.
Exact-title PID32337, game/tooling commit `3b570e1`, source `fe12a0046b13` was
acquired and visually inspected. Native C gave4 Momentum and completed1.96units
of forward travel; Q visibly crouched; Space began a target-free strike with no
phantom damage; R/0/F12 restored the initial state. Four saved images match their
sidecars and have no changed source files. The final reset was opened and left
ready: `evidence/2026-09-08-native-review-handoff/reset.png`, JSON and observations.

This bounded tooling smoke does not claim continuous native holding, paired
native takedown, user taste or a new performance certificate. V1 remains default;
R14 and the board UI keep their existing user/policy gates. The live code source
matches the current tree; subsequent evidence/document commits do not require
another gameplay relaunch.

## Waiting — standing/moving jump phrase and native handoff (2026-09-10)

User refinement supersedes unconditional outward free jumping and the intermediate
all-vertical moving-jump policy. A free jump now has grounded0.12s preparation,
0.62s parabolic flight to1.35 units and grounded0.20s impact recovery. Stationary
jumps extend both legs and rise in place; already-moving jumps carry2.2 units in
the takeoff direction with an alternating split-leg pose. Air input remains gentle
and normalized; a held launch direction does not stack extra forward speed.
Vault retains0.48s/1.05 apex/2.2 travel. Root speed and frozen GLB stay unchanged.

Matched240-frame before/after and default-camera runs passed and were inspected.
Default309/candidate311 mechanics, real-controller full-mesh jump5598 (18 cases,
all sizes,30/60Hz,both moving leads), legacy landing1302, transitions67, whiffs254,
headless import/startup and12 tooling checks pass. Floor/contact tolerances are
unchanged. No broader deformation or performance certificate is newly claimed.

Native exact-title PID44250, sourcec9e551cb87cb: V/F12 burst captured on-floor
preparation, rise to observed1.3323 and grounded recovery at unchangedX/Z. Second
jump alternates the lead. C produced1.96 travel/+4 Momentum, Space began a whiff,
Q visibly crouched, and enlarged R/0/F12 reset was inspected and left open with
health100/Momentum0/guard100/default camera. All saved image hashes match sidecars;
no source files differ from the frozen build. Held moving-jump native/user feel
remains pending; fixture input is labelled separately. V1 stays default.

Full identity, selected original frames, logs, bug/quirk review and next user
criteria: [jump review](../evidence/2026-09-10-jump-motion/README.md).
Board regenerated and schema/parity checked; rendered board UI keeps its separate
existing URL-policy blocker. Earlier R14 appearance/held-movement/takedown release
gates remain open.

## Waiting — running-jump bent arms and impact catch (2026-09-10 follow-up)

The user rejected straight-looking flight arms and weak landing knee flexion.
The jump-pose resource now keeps bent elbows, reduces shoulder reach and holds a
deeper loaded impact pose before release. Controller timing/travel and the GLB
are unchanged. This supersedes the earlier jump appearance verdict, not its
preserved mechanics or native-input evidence.

Matched 150-frame profile/default-camera fixtures cover held movement through
landing and the mirrored lead with release. Actual rendered poses were inspected.
Default 309/candidate 311 mechanics, transitions 67 and full-mesh 5646 pass. 18 cases
at 30/60 Hz/all sizes/both moving leads retain floor/contact bounds; actual skeleton
flight-elbow minima 44–45 degrees, knee impact peaks 68–69 degrees and pelvis drop
0.147–0.204 units now supplement mesh safety. Headless import/startup pass; the
sandboxed macOS system-CA warning is benign and separately recorded.

Fresh exact-title PID 45340, source bb51a808e92a: native V/F12 captures airborne rise
and grounded impact/recovery, Q works afterward, and enlarged R/0/F12 reset is
inspected and left open. PNG/state hashes match with no source drift. Native held
running/user visual judgement remain pending; V1 stays default. No new performance
certificate. Board regenerated/schema-checked; its existing rendered UI gate stays
separate. [Evidence and quirks](../evidence/2026-09-10-running-jump-impact/README.md).

## Waiting — correct forward jump elbow flexion (2026-09-10 follow-up)

The user caught backwards elbow bending in the prior pass. Its visual verdict is
superseded; the unsigned angle gate had accepted hyperextension. Jump forearm
body-X drivers now use the forward-flexion sign. All other jump curves, controller
behavior and frozen assets are retained.

The signed actual-skeleton check rejects the old pose in all 12 moving cases
(about -56 degrees); the corrected 18-case full-mesh run passes 5646 checks, with
moving-flight minima 81.39–82.43 degrees. Knee/pelvis/floor gates remain passing.
Default/candidate mechanics 309/311, transitions 67, editor import and default
startup pass. Sandbox system-CA and user-log write errors are recorded separately
from game results, with stdout evidence preserved. Matched
profile frames 26/101 and gameplay-scale sequences were inspected for both leads.

Fresh exact-title native PID 46188, source `2dfc70da70c6`: V/F12 captured stationary
rise at fixed X/Z, Q worked after recovery, and the enlarged R/0/F12 reset image was
inspected and left open. Image hashes match sidecars without source drift. Running
motion evidence is a held-input controller fixture; native held input and user
judgement remain separate. V1 stays default. Board generated/schema checked, with
its existing rendered UI gate open. No new performance certificate.

[Correction evidence and limitations](../evidence/2026-09-10-jump-elbow-direction/README.md).

## Waiting — relaxed inward crouch arms (2026-09-10)

User front/profile screenshots prompted a crouch-specific arm correction. Forward
elbow flexion, inward mirrored yaw, reduced shoulder reach and modest counter-swing
now keep the hands near the lower torso. The final size-compensated block owns the
anatomical targets; earlier overwritten assignments are removed. Torso/leg posture,
clearance, speed, jump curves, V1 default and frozen assets remain unchanged.

Matched 270-frame front/profile/gameplay captures cover entry, idle, held travel,
release and standing recovery. Actual-skeleton full idle/moving cycles give elbow
flexion 65.78–70.37 degrees, minimum inward wrist offset 0.077 and center clearance
0.154 authored units. Both new geometry gates reject the old pose and pass the
correction. Transitions 70, candidate mechanics 311 and full-mesh crouch 1083 pass;
all three sizes retain floor/lintel bounds. Editor import passes. Sandbox CA warning
and the resolved historical-snapshot missing-import failure are documented separately.

Fresh exact-title PID 46972, source `0a91576169a3`, native Q enter/exit, settled
crouch and enlarged R/0/F12 reset were inspected. Images match sidecars with no
changed source. Current runtime matches the final rendered pose. Held movement
in the reel is scripted; user feel remains pending. Earlier jump review and R14
release gates stay open. Boards generated/schema checked; rendered UI gate remains
separate. [Evidence, rejected variants and limitations](../evidence/2026-09-10-crouch-arms/README.md).

## Waiting — short black tousled hair (2026-09-10)

R14 review restores black scalp/beard vertex colors and adds a fitted angular
fringe plus low crown lock. The adapter uses a private material copy and the
new mesh shares the existing head skin bind. Frozen GLB SHA remains `30a2c06be423…`.
The 280-vertex / 436-triangle layer is included in all full-mesh bounds checks.

Matched 270-frame front/quarter/profile/rear and run/jump/crouch renders pass and
were inspected. Rig/material/head binding 454, crouch 1083 and full deformation
22,164 pass with 49,595 vertices, three sizes and both sample rates. Import and
default startup pass; the macOS sandbox CA warning is recorded separately.
Sparse crown spikes were rejected; a rear lock failed lintel clearance and was
removed. Final medium crouch height remains 1.995706 below the 2.0-unit lintel.

Fresh native exact-title PID 48537, source `b8b794c3c1c3` matches the final render.
Q enter/exit, V jump preparation, enlargement, R/0 reset and F12 were observed.
Three saved PNG/state pairs match with zero source drift. Final reset inspected
and left ready; PID 46972 is superseded. Native jump-start evidence is preparation,
not airborne timing; continuous held input and paired takedown remain open.

Evidence and preserved iteration identities: `evidence/2026-09-10-short-black-hair/`.
User hairstyle, earlier crouch and jump preferences remain pending. V1 stays
default, R14 remains a candidate; no new performance certificate. Generated-board
schema/parity verification is separate from the existing rendered UI policy gate.
