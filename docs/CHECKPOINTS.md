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
