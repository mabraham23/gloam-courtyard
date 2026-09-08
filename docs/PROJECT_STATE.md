# Project state

Last curated: 2026-09-08

## Product vision and constraints

Build an original dark-gothic stealth-action game where correct timing feels overwhelmingly powerful and mistakes cost health and Momentum. The intended prologue is three tutorial-like missions with progressive tools, environmental puzzles, original named villains, fixed-difficulty enemy archetypes that become harder through composition and positioning, and modular body/outfit customization.

No Batman or other franchise names, likenesses, symbols, costumes, architecture, or assets. The current work is a feasibility spike, not the prologue itself.

## Active/default direction

- Godot 4.7.2, GDScript, local desktop-first.
- `project.godot` defaults to `main_3d.tscn`; `main_3d.gd` owns the true-3D courtyard and gameplay loop. `actors/character_visual_builder.gd` owns actor visuals and pose application; the in-progress authored player asset and narrow skeleton adapter live under `actors/gloam_vigil/`.
- The committed presentation is true 3D with real height and a composed orthographic three-quarter camera. Do not reopen 2D versus 3D.
- `main.tscn`/`main.gd` are a completed 2D mechanics and visual-feedback reference. Preserve them and their evidence, but do not resume them as the implementation direction.

## Current milestone

**Waiting — the frozen R14 appearance/action candidate is technically accepted
and live-smoked; user visual judgement still gates release.** R14 uses the same
licensed anatomical foundation and 74-joint articulated rig with warmer light
skin, a readable mouth, connected dark beard/mustache treatment, a single
swept dark hair mass, a fitted original costume, seven draw surfaces, five
materials and four facial morphs. It contains 86,452 triangles (34,998 face),
43,757 authoring vertices and 49,315 exported GLB vertex references; Godot
imports 51,170 skinned references. Exact GLB SHA:
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`.
The exact GLB, source blend, manifest and five studio renders are archived in
`actors/gloam_vigil/v4/revisions/r14`; current review views are in
`actors/gloam_vigil/v4/renders/r14`. R12 remains archived as rejected evidence.
The hair/beard are the best bounded procedural result, but close review still
reads them as stylized surface treatment rather than strand grooming; do not
call this film-quality or release it without the user's gameplay-scale review.
V1 remains the playable default.

R14 passes the GLB contract with zero errors/warnings, 37 imported LOD index
buffers, rig `451/451`, runtime articulation/recovery, default mechanics
`200/200`, candidate mechanics `202/202`, target-independent strike `254/254`,
four-attack `352/352`, action motion `198/198`, transitions `67/67`, alignment
`10/10`, lower-leg stance `13/13`, both-rate foot planting, both-source retarget
validation and full deformation `21,642/21,642`. The full-mesh run covers every
action at all three body sizes and both 30/60 Hz, including the 2.0-unit crouch
lintel and -0.03-unit floor tolerance.

The paired quiet 1920x1080 benchmark passes its configuration and sampling
gates. Actual-courtyard R14 versus V1 mean/p95/p99 wall time is
`5.0999/6.7529/7.1777` versus `5.0924/6.6360/7.1421` ms (+0.15% mean); observed
cadence is about 196 FPS for both. The artificial nine-visual-rig fixture is
`18.5597/21.9153/24.8500` versus `17.5528/20.2122/20.9001` ms. GPU timing is
unavailable, the stress fixture is not nine enemy AIs, and reciprocal cadence
is not a GPU ceiling. Exact protocol and caveats are in
`work/character-art-review/reports/2026-09-08-r14-appearance-action-performance.md`.

Native current-code smoke confirms target-free `SPACE` whiffs without phantom
damage and `C` moves 1.96 units along visible facing while awarding 4 Momentum.
It also caught a stale crouch message: runtime speed was already the protected
1.178 units/s, but the text still said 62%; the message now reports the exact
absolute speed and the deterministic controller/mechanics suites remain green.
The final exact-title R14 review window is left open as PID `28090`; reset state
and project-local F12 are verified at
`captures/courtyard_3d_2026-09-08_10-56-51_86082.png` with health 100,
Momentum 0, guard 100 and the initial objective.
The corrected 277-frame normal-renderer reel at
`captures/r14-action-motion-fist-final00000000.png` through `...00000276.png`
covers paired strike, forward over-top evade and paired takedown with no script
errors. The active punch hand now holds its source-tested compact curl through
readable recovery; the expanded `352/352` suite measures real phalanx curl and
distal-row closure rather than treating the wrist origin as a fist. The frozen
straight-finger topology still limits true self-contact, so close-up fingers
remain stylized and are not claimed as a production closed-fist solve.
`captures/r14-target-independent-strike00000000.png` through `...00000179.png`
shows empty-space, one buffered follow-up and post-defeat strikes with no target
lock or phantom damage. Unobstructed matched front idle/run/recovery evidence is
`captures/r14-gait-alignment-final00000090.png` through `...00000179.png`.
Godot-import face comparison frames are under `captures/r14-import-*`.

### Preserved R7-to-R14 implementation history

Native review accepted the appearance direction but rejected three procedural
gaits. The later separate-walk/run design is also superseded at the user's
direction: ordinary standing `WASD` now always uses the corrected CMU subject 16
trial 45 run/jog at 4.80 units/s, and `Shift` has no locomotion effect. The
licensed trial 31 walk source, its generated channel and the 570-frame comparison
remain reproducible superseded material rather than active runtime control.
Zero-time key press/release adds no distance; only elapsed held input owns travel.
The crouched controller preserves its pre-simplification absolute 1.178-unit/s
speed instead of inheriting 62% of the faster standing speed.

The retarget maps the frozen rig by observed spatial side/facing and bridges the
source T-pose to the target rest. Captured local rotations now remain on their
solved major bones instead of being split across different-pivot twist children,
which caused the rejected lateral knee flare. A single `6.195` source-to-target
leg-length ratio scales pelvis bob/sway on every axis. The R7-only run refinement
keeps most captured trunk drive while reducing the source neck/head extension;
the relaxed hand profile now closes the imported finger fan into a light cup.
The exact sources, permission, hashes and build boundary are recorded in
`actors/gloam_vigil/v4/motion/PROVENANCE.md`.

At 30/60 Hz the real controller measures 4.800 units/s for plain `WASD`, held
`Shift+WASD` and released Shift alike; crouch measures 1.178. Normalized
diagonals, advancing gait phase, zero press/release teleport, collision bounds
and focus-loss input clearing pass. Maximum run lateral knee-plane error is 4.7
cm; support feet are slower than swing feet, hard-plant active/blocked counts
remain zero, and stops settle in 2/4 frames. V1, collision, actions and the
frozen GLB/weights are unchanged.

Hands-ahead crouch, asymmetric jump/vault, counter, grapple/recovery, hurt and
supported downed work remain intact. R7 now adds a body-space action layer for
strike, evade and paired takedown across the pelvis/spine/clavicle/twist/hand/
leg chains without owning gameplay root motion. Strike leads with the fist at
the fixed 0.14-second contact, the low forward evade folds through a shoulder-
first tuck while the controller travels exactly 1.96 units along visible
facing, and the takedown holds the victim stable until its fixed 0.34-second
contact before a connected side fall.
Grapple now follows a 1.75-unit eased clearance arc while preserving its 0.32 s
duration and exact `(6, 3.04, -2.4)` landing. The guard and player use coherent
whole-body side falls rather than disconnected/floating defeat poses.

The strike follow-up is now a four-move controller-owned set: mirrored right
and left straights plus mirrored right and left front kicks. Range, target side
and the prior move weight a seeded-capable selector; immediate repeats are
removed whenever another valid option exists. Punches own 2.20-unit reach and
0.36/0.38-second durations with 0.14/0.15-second contact; kicks own 2.38-unit
reach and 0.50/0.48-second durations with 0.22/0.21-second contact. The existing
22-point damage, Momentum scaling and +13 result are unchanged. Target/contact
ownership is fixed on commit, so late range entry, the vault barrier, different
height, perch/air state, a target behind the visible facing or one crossing
behind before contact cannot acquire or retain a hit. One non-stacking
input may buffer only in the final 0.10 seconds after contact; interruption,
reset or a failed contact clears it. Live strikes block locomotion root sliding.
R7 presents explicit weight transfer, torso/clavicle sequencing, mirrored
fist-first centerline reach, a separated cheek/rib guard, support-leg loading
with measured skinned-sole contact and knee-led front-kick extension; V1 receives
the same four controller timings
through its existing presentation boundary.

Current exact-R7 checks pass: static/color/import, 36 LOD buffers, 451/451 rig,
runtime articulation/recovery, 202/202 mechanics, both-source validation,
30/60 Hz single-speed/controller diagnostics, the retained 966/966 all-preset
source sampling, 21,642/21,642 broader deformation/action checks, 352/352
four-attack selection/contact/buffer checks, 198/198 focused R7 action checks
and 67/67 transition checks. The unchanged default V1 passes 200/200 mechanics.
The current 210-frame normal-renderer reel at
`captures/r7-single-speed-final00000000.png` through `...00000209.png` covers
plain WASD, Shift+WASD and start/stop using the real held-input controller. Plain
and Shift cases each travel exactly 7.199999 units across 45 frames; both keep
the corrected run pose at 1.0. Independent dense review found no new blocking
pose defect. The earlier 570-frame separate-walk/run reel is retained as
superseded comparison evidence, not current acceptance. The exact-SHA current
controller is now the sole acquired `Gloam Courtyard Spike (DEBUG)` window;
`captures/courtyard_3d_2026-09-08_08-41-17_63850.png` verifies the new `WASD
run` HUD, health 100, Momentum 0, guard 100 and reset objective. PID 23261 is
left open for user play. Computer control cannot hold movement across elapsed
frames, so the 210-frame reel owns automated held-input evidence and user feel
remains a separate gate.
The final 466-frame normal-renderer reel at
`captures/natural-motion-r7-final00000000.png` through `...00000465.png`
covers actual controller states for jog/stop/crouch/jump/vault/forward evade,
strike/counter/grapple/fall/takedown/hurt/downed. Slow frame review caught and
fixed a floating downed torso, an impossible initial stance-lock interval and a
large-preset landing toe dip before this final result. Environmental Godot
macOS log/certificate warnings are separate from the passing script results.
The later gait rejections supersede that reel's locomotion acceptance and the
390-frame thirteen-pose reel is also retained as rejected evidence. The prior
collision-free reel at `captures/r7-gait-cmu-final00000000.png` through
`...00000341.png` remains the pre-alignment reference. Matched 360-frame
actual-controller profile/front/three-quarter/default sequences now exist at
`captures/r7-gait-alignment-baseline00000000.png` through `...00000359.png`
and `captures/r7-gait-alignment-final00000000.png` through `...00000359.png`.
Dense comparison shows the head/chest returned over the pelvis while the
captured pelvis transfer, stride and natural stance width remain. This is
internal review evidence, not native user acceptance.

The four-attack normal-renderer evidence includes 361 real-time paired frames
at `captures/r7-four-attack-final200000000.png` through `...00000360.png` and
the latest 721-frame disclosed half-speed near-profile review at
`captures/r7-four-attack-slow-final500000000.png` through `...00000720.png`.
The latter records the corrected inward elbow-fold punch recovery and kick
re-chamber before placement for every attack at all three presets. Exact
render-time skinned-sole probes at frames 372/374/376 remain within numerical
noise of world Y=0; the disappearing magenta disc is a contact flash, not a
ground marker. `captures/r7-context-combo-final300000000.png` through
`...00000150.png` records an eight-contact seeded controller sequence: close
range mixes punches/kicks without an immediate repeat, while 2.30-unit range
selects only alternating reach-valid kicks. That reel enters every request as a
SPACE press/release through `_unhandled_input`; helper placement and seeding are
disclosed diagnostic controls, so it is input-path evidence but not native-OS
keyboard evidence.

A fresh post-alignment normal-renderer 1080p technical pair completed in one
session. In the actual courtyard R7 versus V1 mean/p95/p99 wall time is
`4.316169/6.0030/6.6875` versus `4.190361/5.9890/6.5628` ms: +3.00% mean,
+0.23% p95 and +1.90% p99. In the artificial nine-visual-rig fixture the mean
is +2.63%, while R7's p95/p99 tail is about +15.67%/+21.26%. The fixture is not
nine enemy AIs, reciprocal wall cadence is not an FPS guarantee or GPU ceiling,
and GPU timing is unavailable. Full protocol and distributions are in
`work/character-art-review/reports/2026-09-05-locomotion-alignment-performance.md`.

During Sep-5 review the Mac was unlocked. An exact-title native R7 session verified restart and
ordinary tap movement after the alignment refinement. The prior native session
also verified the facing-forward evade (+4 Momentum) and the seven-tap
concealment route into the paired takedown, guard defeat and exit unlock at
health 100/Momentum 35. Project-local evidence is
`captures/courtyard_3d_2026-09-05_17-25-31_33257.png` and
`captures/courtyard_3d_2026-09-05_17-26-22_84202.png`. Automatic SPACE input
was not reliable before the guard defeated the player. The Final3 context reel
and a fresh headless input-path replay prove eight SPACE press/release requests
through `_unhandled_input`, but this is not claimed as native-OS keyboard
evidence. On Sep 7 an exact-SHA R7 DEBUG process launched successfully, but the
locked Mac blocked window acquisition and native input. That blocker is
superseded: the Sep-8 refreshed exact-title session accepts ordinary `space` and
`C`, reports the strike-whiff response, completes the forward evade with 4
Momentum and saves fresh project-local F12 evidence. The clean handoff capture
is `captures/courtyard_3d_2026-09-08_06-49-56_293758.png` at health 100/Momentum
0/guard 100. User-held gait/takedown and visual review remain required before
switching the default.
Local-board browser interaction/responsive verification is separately blocked
by the recorded URL-policy denial; static board checks are not UI acceptance.

**Licensed anatomical foundation, isolated v4 study.** Matched v3/r1
review rejected the terraced face/glasses-like mask and sloped tent-like upper
torso; procedural study remains preserved, not released. The originating request
explicitly clarified that a suitable free licensed generic anatomical base is
authorized. Blender's official CC0 Human Base Meshes v1.4.1 is downloaded and
its selected Dan Ulrich realistic body/head collection metadata verified;
exact archive/source hashes and license boundaries are in `v4/PROVENANCE.md`.
Original fitted suit/mask/cape design remains required; no franchise asset,
purchase or uncredited claim of wholly original base geometry. V1 stays default.

**Preserved v3 construction study.** The new
reference is used only for broad muscular proportions, not franchise identity,
mask/cowl, emblem or costume. Rebuild coherent face/jaw/short neck, connected
shoulders and fitted muscle/suit detail from original local geometry. V1 and
frozen rejected v2 are preserved; no candidate is accepted yet. The 74-bone
contract is retained, while the separately gated animation pass stays separate.
Matched Blender/Godot review, full-pose clearance and regression/performance/live
checks must precede release. The later v4 authorization above supersedes the
earlier external-base choice, not original-IP or purchase boundaries.

**Organization update — separate character-art and animation-quality passes.**
The user approved this split after the action-readability checkpoint. Existing
task `vigil-authored-motion` owns natural locomotion, starts/stops/turns, action
transitions/contact/recovery and rig-supported secondary motion. Its R7
broader implementation and rendered/technical evidence pass, but native review
rejected locomotion three times. The new licensed captured gait has passed
internal rendered/technical review and remains Waiting for user judgement. The
separately authorized strike/evade/takedown phase now also passes its internal
rendered/technical review; neither result releases the gait or R7 default.
Face/anatomy/topology/materials remain the separate appearance pass; no further
source-art change was made during motion work.

**Runtime verified — action readability; board UI handoff pending.** The latest
user feedback is implemented on playable v1. SPACE completes one visible 0.36s
swing with contact at 0.14s; repeated inputs no longer restart/stack damage.
C somersaults forward along the current visible facing, with collision-safe
1.96-unit travel over 0.28s, unchanged 0.42s invulnerability/+4 Momentum and no
held/tap movement stacking. T catches, pulls and releases over 1.10s, reserving
the guard and awarding defeat/+35 once at 0.34s. Health text updates on contact.
196 mechanics, 4,176 dense full-v1 action checks and legacy 511 deformation
checks pass. Real-time close/default sequences and ordinary stealth→grapple→exit,
combat, customization/crouch/jump/camera/reset smoke pass. Bounded post-change
1080p courtyard p95 is 5.302ms; full protocol/limits/evidence are in
`work/action-readability/README.md`. The following v2 metrics describe its
prior technical checkpoint, not a new v2 release or rerun after these changes.

Latest historical default handoff: `captures/courtyard_3d_2026-09-04_18-32-58_9672.png`,
exact `Gloam Courtyard Spike (DEBUG)`, medium/pink v1, health100/M0/guard100,
default camera and reset objective, left open at that checkpoint. This is not
current window state or a fresh V4 handoff.

**Preserved — rejected v2 technical scaffold; art direction superseded by v4.**
The frozen prototype at GLB SHA `a786d082…` has 83,632 triangles, 50,940
exported/runtime vertices, 74 weighted bones, five PBR materials/seven surfaces,
four morphs, five authored Godot Animation resources and 35 imported LOD buffers.
Its 2,763 full-mesh/morph checks and 30/60 Hz ankle-lock/release tests passed,
but independent source/imported close review rejected the face/neck/shoulders.
This remains technical evidence, not semi-professional art, manual sculpting,
motion capture or a completed high-to-low bake. The later explicit free-base
authorization and selected CC0 V4 foundation supersede its pending art choice;
do not ask for that choice again. No purchase is authorized. Historical paired
performance is below and `work/character-quality-review.md` preserves the
rejected art and technical evidence. V1 stays default and Riven stays deferred.

Final paired normal-renderer measurements (three ≥10-second samples per case, verified 1080p/M4 Pro) support one-player technical feasibility: actual-courtyard p95 is 5.319 ms for v2 versus 5.307 ms for v1; mean wall frame time is only 0.45% higher. In the artificial nine-visual-rig fixture, v2 p95 rises to 18.959 ms versus 17.128 ms and p99 to 21.449 versus 18.557 ms. That is a meaningful stress-tail cost, not a supported enemy count or isolated IK/GPU attribution. GPU timing is unavailable. Full protocol/data are in `work/character-quality-benchmark/README.md`. Default v1 live smoke still passes customization, stealth through grapple/exit at health100/Momentum35, evade/jump/camera and ordinary strike defeat at health100/Momentum100.

The approved starting allocation was 50–90k highest-detail triangles, about 70–100 meaningful bones, 2K body / 1–2K face textures and 3–5 unique materials. These are quality/performance targets, not acceptance by count; draw surfaces are counted separately from shared materials. Current v1 inspection found 172,620 triangles, 97,061 vertices, 20 bones, 12 materials, 128×128 albedo textures, no normal maps and no authored clips. The following paragraph records the accepted v1 runtime baseline, not v2 completion.

Runtime verified; local-board handoff still incomplete: the first Blender-authored, skinned and textured original Gloam Vigil player is integrated behind the existing pose API. The selected muscular anatomy, fitted dark clothing, original mask, utility pouches and cape supersede the hooded player. Rest-aware pose mapping, semantic limb topology, smooth shoulder weights, actual crouch clearance and grounded roll/landing pass 511 strict deformation checks and 107 courtyard mechanics checks. A 360-frame close comparison, 330-frame actual-game sequence, and live customization, stealth-to-exit, combat, movement, camera/reset and F12 smoke are verified. The browser's explicit local-URL policy denial leaves current board interaction/responsive verification incomplete, so the overall task remains in progress. This is a first integrated original-superhero iteration, not production realism; substantially better facial anatomy and fitted-suit detail remain the active visual priority. Riven stays deferred. The following paragraphs preserve the earlier procedural milestones as historical baseline evidence.

The 3D pivot, environment/scale pass, believable-character/movement foundation, substantial procedural character-realism pass, multi-stage grapple pose pass, combat-pose/reaction pass, directional evade roll, crouch/clearance pass, jump/vault foundation, actor-only animation-polish pass, and isolated `Riven Lantern Ward` route study are verified. The courtyard proves that the intended loop and atmosphere can coexist in one readable primitive space.

The player is now an original hooded wayfarer with athletic proportions, layered coat shapes, face framing, shaped boots, readable hands/limbs, and preserved body/accent customization. The courtyard guard is a distinct utilitarian warden with armor/uniform layers, helmet, asymmetry, and an attached watch-blade. Both now use articulated hip-knee-ankle and shoulder-elbow-wrist visual chains, rounded/tapered procedural forms, coherent neck/torso/hip transitions, and named body pivots. Locomotion blends knee flex, foot compensation, elbow bend, pelvis weight shift, torso counter-rotation, head stabilization, idle breathing, and player coat-tail lag. The player turns toward camera-relative travel, the guard visibly patrols with a heavier gait, and grounded actors hold a 1.48-unit personal-space boundary without breaking close combat.

Grapple now reads as a staged action rather than a translated idle: the player coils into launch, reaches asymmetrically overhead, extends through transit, prepares the feet and hips on approach, compresses on landing, then recovers to the grounded stance over 0.32 seconds. Traversal timing remains 0.32 seconds, the landing position is unchanged, and the recovery pose does not block immediate perch movement. Grapple landing still enters a real perch state: horizontal input walks across the platform, crossing its footprint begins a gravity-driven fall, and landing restores grounded movement. Melee range is height-aware, so a guard below the perch cannot strike through it. Deterministic regression evidence also preserves combat reach, exit success, and restart.

Combat now exposes distinct player strike and counter silhouettes plus a warden attack telegraph. Successful hits drive side-aware stagger lean, arm recoil, knee absorption, and clean timed recovery. Defeat cancels active attack/vision state, folds the warden through a grounded collapse, waits before fading, then removes the visual and label after 1.45 seconds. The removed guard no longer leaves an invisible personal-space blocker. Strike damage/Momentum, perfect versus ordinary counter results, the 0.72-second attack window, uncountered damage, success, and reset values are unchanged.

Evade snapshots visible player yaw, not held or remembered travel. Positive-X
center-pivot rotation makes the +Z-facing rig somersault forward. Ordinary
movement cannot steer or add distance during its 0.42s action; clear-space
travel integrates exactly 1.96 units over 0.28s, including the last partial
frame. Collision, +4 Momentum, camera/reset and damage gating pass. The older
remembered-travel direction and negative-X backward rotation are superseded.

Crouch is now a measured gameplay state rather than a cosmetic pose. `Q` enters/exits a low articulated stance, movement is reduced to 62%, and a visible optional passage beside the darkness zone exposes a 2.0-unit clearance bar. Standing entry is blocked, crouched movement passes through, standing and evade are rejected while underneath, and full height returns only after clearing the lintel. The camera and existing movement/action mechanics remain unchanged.

Jump/vault completes the current movement envelope. `V` performs a bounded 0.62-second free jump with a 1.35-unit apex and 2.2-unit landing distance, or selects a contextual 0.48-second, 1.05-unit vault when the projected path crosses the visible low barrier. Walking is blocked by that barrier, vault landing clears it, insufficient landing room and low-passage bypasses are rejected, and the action does not add invulnerability. Both states use distinct articulated takeoff, airborne, and landing silhouettes while preserving camera and grounded recovery.

The advertised silent takedown is now spatially reachable. A visible 1.6-unit ambush shadow overlaps the left patrol turn: seven default-camera `D` taps reach concealment from reset, the warden exposes its back while turning toward the next patrol point, and `T` succeeds inside the existing 2.1-unit range/behind rule. Frontal and out-of-shadow attempts still fail, the original darkness remains valid, and restart restores the guard.

The actor-only polish pass sharpens the existing action language without changing gameplay state or timing. Grapple landing now hands continuously into recovery; evade tucks and spins sooner before a two-leg absorption; crouch has planted asymmetry and slower cloth/core settling; free jump and vault use distinct load, held-flight, and landing curves; strike/counter contact is more decisive; and the warden holds its telegraph before a faster cut and stagger recovery. The pose API and controller constants are unchanged.

`levels/riven_lantern_ward/riven_lantern_ward.tscn` is an accepted isolated, non-default spatial study rather than a playable second level. Its 38 × 28 footprint contains a 14 × 10 combat core, ground/covered/elevated/one-way route ideas, four concealment pockets, a 2.0-unit crouch lintel, a 0.84-unit vault obstacle, 1.80/1.65-unit jump gaps, and 3.40/3.35-unit grapple opportunities sized against the verified movement envelope. It has primitive collision geometry and self-validating measurements but intentionally no controller, encounters, or default-scene wiring.

The constrained camera extension is now verified for `J/L` orbit, bounded `I/K` pitch, `-`/`=` orthographic zoom, shifted `+`, `0` default-view reset, camera-relative movement after rotation, restart, F12, and clean post-change editor/runtime launches. The default remains the proven three-quarter orthographic composition. Zoom now changes `Camera3D.size`; the former implementation only changed camera distance, which cannot visibly zoom an orthographic projection.

The grapple interaction is live-verified from discovery through recovery: an outside step rejects `G`, the next inside step brightens the visible 3.5-unit ring and shows `GRAPPLE READY`, and launch/landing captures show `IN TRANSIT` followed by `ROUTE COMPLETE`. A dotted ascending route replaces the misleading flat yellow bar. A dedicated 28-frame normal-renderer sequence records launch coil, transit reach, approach, landing compression, and recovery at the accepted default camera.

## Verified active-3D baseline

- Camera-relative movement, including automation-friendly WASD taps.
- Constrained left/right orbit, bounded pitch, live orthographic zoom, and reset to the default three-quarter view.
- Guard patrol motion, vision/suspicion/alert presentation, close combat, strike/Momentum feedback, and visible counter timing state.
- Progress-driven player strike/counter, warden attack telegraph, side-aware stagger recovery, grounded defeat collapse, delayed fade/removal, and restart restoration.
- Forward evade using current visible facing, full-body tuck/somersault/recovery, collision-safe travel and no held/tap stacking; unchanged invulnerability and Momentum.
- Toggle crouch with a low articulated gait at an absolute 1.178 units/s, measured 2.0-unit passage, standing collision gate, forced low profile underneath, clean exit, and restart restoration.
- Bounded free jump and contextual low-barrier vault with measured duration, apex, distance, collision clearance, distinct action poses, camera invariance, damage behavior, edge-case rejection, and restart restoration.
- Reachable silent-takedown route with a visible measured ambush shadow, existing behind/range rule, live reset-to-takedown path, failure cases, guard defeat, and restart restoration.
- Actor-only action polish across grapple, evade, crouch, jump, vault, strike, counter, warden telegraph, stagger, and stable recovery, with finite-transform and silhouette checks and no controller changes.
- Isolated non-default Riven Lantern Ward gray-box with measured traversal affordances, route layers, collision geometry, a normal-renderer overview, and a passing self-validation mode; it is not yet playable or integrated.
- End-to-end success through reset, movement, rapid combat, 100% Momentum, guard defeat, grapple, perch landing, and the exit.
- Grapple from the gold anchor to a real-height perch, restart, and project-local F12 capture.
- Visible grapple range, ready prompt, dotted ascending route, distinct transit/landing feedback, and progress-driven launch/transit/approach/landing/recovery poses.
- Primitive original gothic architecture and scale layering; varied wet slabs/puddles; fog, rain, shadows, cool moonlight, and amber practical lights.
- Rounded/tapered original player/guard silhouettes, articulated procedural idle/walk cycles, travel-facing turns, pelvis/torso counter-motion, knee/elbow/foot articulation, preserved body lean, interpolated grapple travel, and brief strike/perfect-counter light flashes.
- Grounded actor separation, height-aware melee, horizontal perch movement, edge fall with gravity, and stable floor landing.
- Normal-renderer numbered PNG capture with changing frames.

The latest deterministic foundation smoke run exercised grounded separation for both movers, combat at the separation boundary, grapple landing, perch walking, edge fall, floor landing, perch-height attack rejection, exit success, and restart. The grapple, combat, evade, crouch, jump/vault, and stealth-route probes retain their exact accepted values; the grapple timing probe is run with a fixed 60 FPS step to avoid wall-clock scheduling noise and measures 0.3167 seconds against the accepted 0.32-second bar. The animation-polish probe passed state continuity, silhouette distinction, telegraph/readability, and finite transforms. Riven's isolated measurement mode passed every declared dimension. Dedicated 40-, 28-, 104-, 48-, 54-, 56-, 58-, and 204-frame sequences cover locomotion, grapple, combat, evade, crouch, jump/vault, stealth, and final action polish.

## Current controls

- `WASD` move; `Q` crouch; `V` jump/vault; `G` grapple; `SPACE` strike; `E` counter; `C` evade; `T` silent takedown.
- `SPACE` always presents one of four nonrepeating attacks, even with no target; only a target owned at commit may take damage. Punches last 0.36/0.38s and kicks 0.50/0.48s. `C` rolls 1.96 units forward along visible facing. `T` reserves movement for its 1.10s paired action; height/low-clearance gates apply.
- `1`/`2`/`3` change body build; `X` changes accent color.
- `R` restarts; `F12` saves a timestamped PNG under `captures/`.
- Camera: `J/L` or left/right arrows orbit, `I/K` or up/down arrows adjust pitch, `-` zooms out, `=` or shifted `+` zooms in, and `0` resets the default view. Keypad subtract/add are equivalent.

## Launch, verify, and evidence

Reliable visible launch:

```sh
open -a "/Applications/Godot.app" --args --path /Users/markabraham/dev/batman
```

Headless editor/runtime checks, when a task is authorized to create new verification evidence:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 2
```

Follow `docs/visual-feedback-loop.md`: refresh/acquire the changing Godot window, then use screenshot/action/screenshot. `F12` writes durable project-local PNGs. Use the normal macOS renderer—not headless movie mode—for short numbered frame sequences. Every milestone should also include an actual smoke play-through and an evidence-backed bug/quirk review; clean headless checks alone are insufficient.

Latest verified bounded sequence command:

```sh
godot --path /Users/markabraham/dev/batman --write-movie captures/gloam-feedback-loop.png --fixed-fps 12 --quit-after 8 --disable-vsync
```

It produced exactly eight 960×600 PNGs plus a WAV sidecar. This is sampled frame capture, not continuous live video.

Most useful accepted evidence:

- First authored-player integration: `captures/gloam-vigil-verified-actions00000020.png` is the equal-scale before/after; `captures/gloam-vigil-verified-gameplay00000025.png` is the actual courtyard view. Final live fresh handoff is `captures/courtyard_3d_2026-09-04_16-49-37_19394.png`, health100/Momentum0/guard100, default medium/pink accent. The full runtime checkpoint and remaining board-only gate are in `CHECKPOINTS.md`.
- 2D visual reference: `captures/courtyard_2026-09-03_17-45-54_18313.png`.
- Verified 3D pivot: `captures/courtyard_3d_2026-09-03_17-58-38_21097.png` and `captures/courtyard_3d_2026-09-03_18-03-28_23470.png`.
- Verified environment/scale pass: `captures/courtyard_3d_2026-09-03_18-11-16_22641.png`.
- Verified motion/perch state: `captures/courtyard_3d_2026-09-03_18-14-43_42433.png`.
- Verified motion sequence: `captures/gloam-3d-motion00000000.png` through `captures/gloam-3d-motion00000011.png`.
- Verified constrained-camera states: `captures/courtyard_3d_2026-09-03_19-58-20_6260138.png` (default/reset), `captures/courtyard_3d_2026-09-03_20-03-56_211521.png` (clockwise), `captures/courtyard_3d_2026-09-03_20-04-28_243665.png` (counterclockwise), and `captures/courtyard_3d_2026-09-03_20-05-46_321489.png` (reset/gameplay). The capture hashes differ.
- Verified orthographic zoom states: `captures/courtyard_3d_2026-09-03_21-38-17_128148.png` (default), `captures/courtyard_3d_2026-09-03_21-38-28_139159.png` (minus/zoom out), and `captures/courtyard_3d_2026-09-03_21-38-44_154293.png` (equal then shifted-plus/zoom in). Live desktop input changed the framing in both directions.
- Grapple baseline/boundary: `captures/courtyard_3d_2026-09-03_20-12-59_16698.png`, `captures/courtyard_3d_2026-09-03_20-14-22_99329.png` (outside), and `captures/courtyard_3d_2026-09-03_20-14-29_106554.png` (ready).
- Grapple transition: `captures/courtyard_3d_2026-09-03_20-14-38_114771.png` (in transit) and `captures/courtyard_3d_2026-09-03_20-14-49_126570.png` (route complete).
- Smoke evidence: `captures/courtyard_3d_2026-09-03_20-16-48_245370.png` (guard down, health/Momentum 100%), `captures/courtyard_3d_2026-09-03_20-17-02_259053.png` (`COURTYARD CLEAR`), `captures/courtyard_3d_2026-09-03_20-17-42_299203.png` (unreachable takedown), and `captures/courtyard_3d_2026-09-03_20-18-27_344248.png` (perch attack/death).
- Latest normal-renderer sequence: `captures/gloam-feedback-loop00000000.png` through `captures/gloam-feedback-loop00000007.png`; eight valid 960×600 frames at 12 FPS with differing first/last hashes.
- Character baseline/final: `captures/courtyard_3d_2026-09-03_21-06-30_3227041.png` and `captures/courtyard_3d_2026-09-03_21-37-13_64195.png`.
- Character customization and locomotion: `captures/courtyard_3d_2026-09-03_21-37-38_88977.png`, `captures/courtyard_3d_2026-09-03_21-37-44_94380.png`, `captures/courtyard_3d_2026-09-03_21-38-17_128148.png`, `captures/courtyard_3d_2026-09-03_21-38-43_153408.png`, and `captures/courtyard_3d_2026-09-03_21-38-44_154293.png`.
- Character spacing and perch states: `captures/courtyard_3d_2026-09-03_21-39-36_207142.png`, `captures/courtyard_3d_2026-09-03_21-40-12_242909.png`, `captures/courtyard_3d_2026-09-03_21-41-13_303358.png`, and `captures/courtyard_3d_2026-09-03_21-41-41_331693.png`.
- Verified perch-walk/fall/land sequence: `captures/gloam-character-fall-final00000000.png` through `captures/gloam-character-fall-final00000027.png`; frames 6–8 show perch travel and edge departure, frames 9–12 show descent, and frame 14 shows floor landing.
- Final fresh DEBUG handoff: `captures/courtyard_3d_2026-09-03_22-01-18_328813.png` shows the reset default state with health 100%, Momentum 0%, guard 100, original actor silhouettes, and the accepted composed camera.
- Procedural-realism baseline/final: `captures/courtyard_3d_2026-09-03_22-11-15_925530.png` and `captures/courtyard_3d_2026-09-03_22-30-18_349987.png`.
- Realism presets/accents: `captures/courtyard_3d_2026-09-03_22-24-42_13396.png` (medium), `captures/courtyard_3d_2026-09-03_22-24-47_18363.png` (small), `captures/courtyard_3d_2026-09-03_22-24-52_23430.png` (large), and `captures/courtyard_3d_2026-09-03_22-24-59_30980.png` (alternate blue accent).
- Realism travel/spacing/traversal/camera: `captures/courtyard_3d_2026-09-03_22-25-23_55179.png`, `captures/courtyard_3d_2026-09-03_22-25-47_78355.png`, `captures/courtyard_3d_2026-09-03_22-28-01_213038.png`, `captures/courtyard_3d_2026-09-03_22-28-58_269320.png`, `captures/courtyard_3d_2026-09-03_22-29-16_288274.png`, and `captures/courtyard_3d_2026-09-03_22-29-54_326207.png`.
- Final natural-motion sequence: `captures/gloam-character-natural-motion-final00000000.png` through `captures/gloam-character-natural-motion-final00000039.png`; 40 valid 960×600 frames at 12 FPS with different first/last hashes. Frames 5–10 show rightward travel, frame 15 shows grounded recovery, and frames 24–30 show the return direction while the guard patrols and alerts.
- Grapple-pose sequence: `captures/gloam-grapple-poses00000000.png` through `captures/gloam-grapple-poses00000027.png`; 28 valid 960×600 frames at 30 FPS. Frames 2–5 show launch and asymmetric transit reach, frame 8 shows approach, frames 11–15 show landing compression/recovery, and frame 20 returns to grounded stance.
- Live grapple states: `captures/courtyard_3d_2026-09-03_22-49-41_71055.png` (ready), `captures/courtyard_3d_2026-09-03_22-49-49_79394.png` (in transit), and `captures/courtyard_3d_2026-09-03_22-49-55_84930.png` (landed). The guard drained health during capture pauses, matching the known automation-timing limitation; deterministic timing and mechanics probes passed.
- Latest fresh DEBUG handoff: `captures/courtyard_3d_2026-09-03_22-50-55_144888.png` shows the reset default state with health 100%, Momentum 0%, guard 100, default camera, and the accepted articulated actors.
- Combat-pose sequence: `captures/gloam-combat-poses00000000.png` through `captures/gloam-combat-poses00000103.png`; 104 valid 960×600 frames at 30 FPS with different first/last hashes. Frames 3–10 show strike and stagger recovery, 24–31 the warden telegraph, 32–42 the perfect-counter/reaction sequence, 54–78 the grounded defeat collapse, 79–97 the delayed fade, and frame 98 the completed removal.
- Live combat evidence: `captures/courtyard_3d_2026-09-03_23-16-40_31074.png` (strike and reaction), `captures/courtyard_3d_2026-09-03_23-17-41_91777.png` (defeat begins), and `captures/courtyard_3d_2026-09-03_23-18-01_111610.png` (delayed removal). Screenshot pauses let the guard drain player health during staged capture, matching the known automation-timing limitation.
- Latest fresh combat-build handoff: `captures/courtyard_3d_2026-09-03_23-18-52_162844.png` shows health 100%, Momentum 0%, guard 100, restored visuals, and the reset default camera.
- Directional-evade sequence: `captures/gloam-evade-roll00000000.png` through `captures/gloam-evade-roll00000047.png`; 48 valid 960x600 frames at 30 FPS with different first/last hashes (`42e91b...` versus `8077b5...`). Frames 2-10 show the first low tuck/somersault/recovery, frames 24-32 show the opposed remembered direction, and frame 47 is a stable neutral recovery.
- Live directional-evade evidence: `captures/courtyard_3d_2026-09-03_23-29-10_15606.png` (remembered rightward travel), `captures/courtyard_3d_2026-09-03_23-29-16_22021.png` (camera-relative travel after orbit), and `captures/courtyard_3d_2026-09-03_23-29-22_27802.png` (stationary reset fallback). `captures/courtyard_3d_2026-09-03_23-30-25_91525.png` also confirms the live grapple still reaches the elevated perch after the change; screenshot pauses allowed combat damage during staging.
- Latest fresh directional-evade-build handoff: `captures/courtyard_3d_2026-09-03_23-35-18_8921.png` shows the accepted default camera, health 100%, Momentum 0%, guard 100, restored actors, and the reset objective; `Gloam Courtyard Spike (DEBUG)` was left open for playtest.
- Crouch/clearance sequence: `captures/gloam-crouch-clearance00000000.png` through `captures/gloam-crouch-clearance00000053.png`; 54 valid 960x600 frames at 30 FPS with different first/last hashes (`c99ec6...` versus `592f81...`). Frames 2-8 show standing approach rejection, frames 14-36 show low entry/travel and rejected standing beneath the lintel, and frames 43-53 show full-height exit. The final route was narrowed and shifted to the far-left darkness edge so it does not occlude the default spawn framing.
- Live crouch evidence: `captures/courtyard_3d_2026-09-03_23-41-02_8894.png` (entered crouch) and `captures/courtyard_3d_2026-09-03_23-41-13_19435.png` (camera-relative low-speed movement).
- Latest fresh crouch-build handoff: `captures/courtyard_3d_2026-09-03_23-47-12_12207.png` shows the unobstructed reset spawn, accepted default camera, visible far-left low passage, health 100%, Momentum 0%, guard 100, and reset objective; `Gloam Courtyard Spike (DEBUG)` was left open for playtest.
- Jump/vault sequence: `captures/gloam-jump-vault00000000.png` through `captures/gloam-jump-vault00000055.png`; 56 valid 960x600 frames at 30 FPS with different first/last hashes (`dd6d19...` versus `810e99...`). Frames 2-22 show free-jump takeoff/apex/landing; frames 27-41 show contextual vault approach, clearance, and landing; frame 55 is stable recovery.
- Live jump evidence: `captures/courtyard_3d_2026-09-03_23-53-39_10331.png` shows the player after the bounded live `V` jump with health/camera preserved and the visible optional barrier available for the contextual route.
- Stealth-route sequence: `captures/gloam-stealth-route00000000.png` through `captures/gloam-stealth-route00000057.png`; 58 valid 960x600 frames at 30 FPS with different first/last hashes (`c9bc87...` versus `b2909d...`). Frames 2-10 establish concealed behind positioning, frame 12 triggers the takedown, frames 16-50 show grounded defeat/fade, and frame 57 shows removal.
- Live silent-takedown evidence: `captures/courtyard_3d_2026-09-04_00-01-42_11671.png` shows the reset-to-shadow approach with the warden's back exposed; `captures/courtyard_3d_2026-09-04_00-02-14_43359.png` shows `GUARD DOWN`, health 100%, Momentum 35%, and the silent-takedown confirmation.
- Animation-polish sequence: `captures/gloam-animation-polish00000000.png` through `captures/gloam-animation-polish00000203.png`; 204 valid 960x600 frames at 30 FPS with different first/last hashes (`51ecbe...` versus `0ab8c1...`). Reviewed frames cover neutral, crouch, jump, vault, evade, grapple, strike, warden telegraph, counter, and stable recovery with no observed clipping or pose pop.
- Riven Lantern Ward overview: `captures/riven-lantern-ward-overview00000000.png` and `captures/riven-lantern-ward-overview00000001.png`; two valid 960x600 normal-renderer frames with the identical expected static-scene hash `b627f7...`. The overview labels route layers and accepted movement dimensions.
- Final polished-build handoff: `captures/courtyard_3d_2026-09-04_00-19-31_116330.png` (`ff9f0f...`) shows the fresh `Gloam Courtyard Spike (DEBUG)` reset with health 100%, Momentum 0%, guard 100, accepted default camera, and restored actors. Live smoke input exercised crouch, travel, directional evade (+4 Momentum), free jump/recovery, strike/guard reaction, changed orbit/pitch, camera reset, restart, and F12; screenshot latency again allowed the guard to drain health during the staged strike, then restart restored the accepted state.

## Known limits and guardrails

- One original authored player now has explicit authority for a richer rig, authored clips and a bounded character-quality pipeline. This supersedes the earlier 20-bone freeze, not the protected mechanics or original-IP constraints. Additional authored characters, general animation frameworks, inventory, story/dialogue, missions, villain content, controller validation, browser export, networking, save/deployment systems, and external/paid assets remain outside this milestone.
- The first imported player has verified runtime/deformation/live evidence, but the full board handoff is pending. Its long/simple neck, faceted face, broad suit bands, mitten-like finger motion and rigid two-bone cape are not production character art. The next quality step is an original anatomy/cloth sculpt with deliberate animation topology and baked detail, not more primitive rounding.
- Riven Lantern Ward is a static, controller-free non-default study. Making it playable requires an explicit integration choice: a separate playable scene, an expansion/replacement of Lower Court, or keeping it as a route reference.
- `main_3d.gd` intentionally centralizes the spike. Do not refactor speculatively; when the next visual/content pass creates distinct reusable concerns or repeated growth, pause for a bounded organization checkpoint and give those concerns stable homes while preserving speed and comprehensibility.
- Real risk: headless movie mode crashes in Godot 4.7.2 because the dummy renderer returns a null movie texture. Normal-renderer F12 and movie/frame capture work.
- Benign environment noise: sandboxed Godot may warn that macOS Application Support, cache, or log directories are unavailable. Report these separately from parse, scene, or gameplay failures.
- Height-aware melee fixes the accepted through-perch attack defect; future multi-level geometry still needs explicit occlusion/line-of-sight policy beyond this courtyard.
- Automation limitation: screenshot observation takes roughly 1.1–1.5 seconds, longer than the 0.72-second attack and 0.42-second evade windows. Use predetermined bursts or human timing for reactive combat; screenshot/action/screenshot remains reliable for spatial and state checks.
- Launch pitfall: a lingering Godot Project Manager can cause the app launch to ignore `--path`. Identify and stop only the exact stale PID, confirm shutdown with `cua.getState()` alone, relaunch, acquire `org.godotengine.godot`, and confirm the debug-window title before input. Calling app acquisition merely to check shutdown can relaunch Project Manager.

## Recommended next milestone

Review R14 at gameplay scale in the fresh exact-title DEBUG handoff, especially
the hair/beard silhouette, the corrected captured run, all four strikes, forward
over-top evade and paired takedown. If the user accepts those visuals, make the
narrow parent-owned default switch and regress the actual new default. If the
surface-grown facial hair or smooth swept hair shell still reads too synthetic,
keep V1 default and treat a future authored groom/texture pass as new scoped art
work rather than silently raising geometry. Do not bypass the board URL-policy
gate or begin Riven integration while this release gate is open.

## Fresh-agent startup checklist

1. Read `AGENTS.md`, this file, `UPCOMING_TASKS.md`, `DECISIONS.md`, `CHECKPOINTS.md`, and `visual-feedback-loop.md` in that order.
2. Confirm `project.godot` still defaults to `main_3d.tscn`; inspect current file changes before editing.
3. Treat the 2D spike as reference; the active character foundation, camera orbit/pitch/zoom/reset, staged grapple, combat reactions/defeat, directional evade, crouch/clearance, jump/vault, and smoke clear are verified.
4. Launch through Godot.app, reacquire the live window after changes, and use screenshot/action/screenshot plus F12.
5. Smoke-play the actual loop, record bugs/quirks and evidence, and keep runtime failures separate from sandbox warnings.
6. Update docs/evidence first, then `work/project-roadmap.html`, regenerate `work/project-roadmap-local.html`, verify the local board, and finish gameplay work with a fresh verified DEBUG relaunch left open.
