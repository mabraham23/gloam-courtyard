# Decision log

Append-only. Status is `Active` unless explicitly marked `Superseded`.

## 2026-09-03 — Original dark-gothic IP (Active)

The project uses original characters, names, visuals, symbols, costumes, architecture, and assets rather than Batman or any recognizable franchise likenesses. This keeps the prototype creatively and legally distinct while preserving only broad genre intent.

## 2026-09-03 — Godot 4 local desktop-first (Active)

Use Godot 4 with GDScript and target local desktop first. Browser export, networking, and deployment breadth are out of scope for the feasibility spike.

## 2026-09-03 — Angled presentation (Superseded as implementation)

The initial implementation used ordinary 2D with oblique floors, depth sorting, and fake height to test readability quickly. It remains a validated reference, but the active implementation is now a true 3D world with a fixed angled/orthographic-style camera.

## 2026-09-03 — True 3D pivot (Active)

Build a separate minimal 3D courtyard and make it the default only after verification. The pivot tests whether real height, fixed-angle composition, primitive architecture, lighting, and shadows support the intended game better than the preserved 2D spike.

## 2026-09-03 — Speed-first gray-boxing (Active)

Use primitive or code-drawn placeholder geometry and the smallest honest playable loop. Do not add final models, paid tooling, external assets, or broad systems before the core route proves promising.

## 2026-09-03 — Three-mission tutorial/prologue arc (Active)

The long-term shape is three tutorial-like missions with progressive tools, named villains, environmental puzzles, and increasing encounter composition. This spike proves none of that content; it only protects the interaction risks.

## 2026-09-03 — Timing combat and Momentum (Active)

Combat is fast and timing-based: correct sequences should feel extremely powerful, while missed counters deal meaningful damage and break Momentum. A narrower perfect-counter window is required.

## 2026-09-03 — Fixed enemy archetype difficulty (Active)

Enemy archetypes keep fixed difficulty and later challenge comes from composition, positioning, and encounter design rather than stat inflation.

## 2026-09-03 — Modular character/outfit direction (Active)

Characters should support modular body silhouettes, proportions, outfits, and accent colors. The spike only needs a tiny placeholder proof of three body presets and two accent colors.

## 2026-09-03 — Screenshot/action/screenshot feedback loop (Active)

Use the proven Godot.app launch route, refresh/acquire the changing Godot window, capture before/after actions, and use F12 project-local PNGs for durable inspection. Godot's normal-renderer movie/frame writer is the lightweight short-sequence option; continuous live video is unavailable to the model.

## 2026-09-03 — 3D pivot verified (Active)

The separate true-3D courtyard is now the default after headless and live checks. The fixed angled camera, real-height grapple/perch, primitive gothic scale cues, and preserved interaction loop are sufficiently proven for a comparison milestone. The main remaining gap is authored/painterly art and richer motion feel, so further work should wait for a taste or asset decision rather than expanding systems.

## 2026-09-03 — Procedural polish boundary (Active)

Two bounded polish passes are enough to test the 3D direction: environment/scale layering, then lightweight movement and impact feedback. Continue only with authored silhouettes/materials or a deliberate taste decision; do not grow systems breadth inside this feasibility spike.

## 2026-09-03 — Fixed-angle 3D direction selected (Active)

Commit to the verified fixed-angle true-3D implementation rather than returning to the preserved 2D reference. Keep the 2D spike as evidence and a visual/mechanics reference, but direct subsequent readability, interaction-feedback, silhouette, and material work toward the 3D courtyard.

## 2026-09-03 — Constrained camera extension (Active)

Extend the proven three-quarter orthographic composition with bounded courtyard-centered orbit and pitch plus a default-view reset; do not turn it into a free camera. Live evidence verifies left/right orbit, bounded pitch, reset, camera-relative movement, restart, and F12 after the change. Zoom handlers and bounds are implemented and headless-clean, but live equals-key input remains a documented partial-verification limitation.

## 2026-09-03 — Higher-caliber original visual refinement next (Active)

The next product phase should refine the simplistic placeholder characters and setting toward a more authored, higher-caliber original dark-gothic presentation. Begin with grapple readability and the highest-impact silhouettes/materials, use the verified visual feedback loop continuously, and do not expand systems breadth. Each milestone must include an actual smoke play-through and evidence-backed bug/quirk review rather than headless checks alone.

## 2026-09-03 — Bounded organization threshold (Active)

Keeping world construction, actors, HUD, controls, combat, grapple logic, and capture support together in `main_3d.gd` was acceptable for the feasibility spike. Do not perform a speculative architecture rewrite. When visual/content growth creates distinct reusable concerns or repeated sprawl, pause for a deliberate organization checkpoint and define stable homes for those concerns while preserving speed and comprehensibility.

## 2026-09-03 — Character visual and pose boundary (Active)

The believable-character pass crossed the bounded organization threshold. `actors/character_visual_builder.gd` owns procedural actor geometry, named limb pivots, and visual pose application; `main_3d.gd` continues to own gameplay state, movement, combat, grapple, and animation-state decisions. This is a narrow stable boundary, not a general entity framework.

## 2026-09-03 — Sequential movement core, parallel outskirts (Active)

Grapple, combat, evade, crouch, and jump/vault pose or movement work stays sequential under one owner while it changes shared dimensions and state. Animation polish and a non-default map gray-box become parallel-safe only after crouch/jump metrics stabilize. Default-scene integration remains a single-owner task.

## 2026-09-03 — Local roadmap board is derived (Active)

`PROJECT_STATE.md` and `UPCOMING_TASKS.md` remain authoritative. `work/project-roadmap.html` is the editable board source and `work/project-roadmap-local.html` is its regenerated standalone local view; neither replaces the docs or goes to Sites. Update evidence/docs first, then the source board, regenerate and verify the local page, and retain a compact recent-complete lane until its history is safely recorded in checkpoints.

## 2026-09-03 — Camera zoom partial-verification limit (Superseded)

The earlier constrained-camera entry accurately recorded the desktop-control limitation at that time. A later repair moved zoom to orthographic `Camera3D.size`, added main and keypad InputMap aliases, and live-verified main minus, equal, and shifted plus, so zoom is now fully accepted under the existing constrained-camera decision.

## 2026-09-03 — Explicit procedural character-realism priority insertion (Active)

Honor the user's request for a substantial immediate reduction in blockiness and robotic motion before continuing the queued grapple-pose milestone. Keep the work inside `actors/character_visual_builder.gd` plus the existing pose-clock calls in `main_3d.gd`: articulated visual joints, rounded/tapered primitives, coherent body transitions, weight shift, counter-rotation, and smoother idle/walk blending are in scope, while authored models, a production animation system, mechanic/timing changes, and a general entity framework remain out of scope. Completion returns the queue to grapple pose states; the later animation-polish lane still waits for crouch and jump/vault metrics.

## 2026-09-04 — One authored Gloam Vigil player before Riven (Active)

Explicit user direction creates a bounded exception to the earlier authored-model exclusion for one original muscular superhero player. Broad anatomical shoulders/chest, fitted dark clothing, a fitted original mask, functional utility pouches, and a cape supersede the hooded traveler appearance for this player. The work includes Blender-authored connected geometry, materials, skinning, and a narrow rest-aware pose adapter while preserving gameplay, controls, timing, collision, and customization. The model must visibly improve anatomy and joint deformation; a pipeline conversion of toy-like shapes is insufficient. Preserve superseded source models and evidence. No paid/franchise assets, general animation framework, guard replacement, or Riven integration is included. Riven's separate integration choice stays deferred.

## 2026-09-04 — Richer one-player art, rig and authored motion (Active)

After reviewing the simplistic face and 20-joint model, the user approved the proposed art/animation plan. Expand this one original player to a deliberately built face/anatomy/suit, animation-ready topology, meaningful shoulder/twist/finger/toe/face/cape articulation, authored clips/blending, and surface-detail textures. This supersedes the earlier instruction to freeze the 20-bone rig for the next comparison; it does not authorize new characters, external/paid/franchise assets or a general animation framework. Keep the accepted v1 separately reproducible and integrate a v2 candidate only with visual/runtime evidence. Introduce stable asset-authoring and narrow animation resource homes as a bounded organization checkpoint. Use proposed geometry/texture/bone budgets as starting targets and measure real normal-renderer 1080p courtyard/stress frame times, not headless/movie speed, before any 60-FPS claim. The pre-existing browser board policy gate remains recorded; no circumvention is authorized.

## 2026-09-04 — Retain v2 technical scaffold, reject its current art (Active)

Independent Blender and equal-light Godot review rejects the procedural a786d082/r4 face, neck and shoulder construction. Valid rig/export/deformation tests do not compensate for a worse visible character. Keep v1 as the default and preserve the new 74-bone rig, authored clips, contact solver, textures, LOD and repeatable diagnostic work as a non-default technical prototype. Freeze this export while measuring its cost; do not call it semi-professional art or continue density-only revisions. Further visible-model work needs a better anatomical modeling foundation. A vetted commercially usable human base could be researched only after the user's scoped approval; no external asset or purchase is authorized by this technical checkpoint. Riven and unrelated game changes remain deferred.

The v2 deformation, rig-contract, foot-lock, export/LOD and matched-performance checks have become reusable evidence, so preserve them under `work/character-quality-benchmark/` rather than relying only on temporary-file lifetime. This is the bounded diagnostic organization checkpoint; historical external scripts remain preserved, and no diagnostic is referenced by the default scene or changes normal launch behavior.

## 2026-09-04 — Readable contact and forward-facing evade (Active)

Latest user feedback authorizes action timing on accepted v1 while rejected v2
art stays off. Keep the fast 0.36s strike but resolve damage once at 0.14s with
visible extension; ignore repeat input until recovery rather than resetting
windup/stacking instant damage. Counter/evade may cancel pending hits. Add a
1.10s paired takedown with contact at 0.34s, preserving +35 and eligibility,
reserving actors and approaching through normal collision. Guard health-label
refresh belongs to this bounded contact pass.

Superseded: held/remembered-travel evade direction and negative-X backward spin.
C snapshots visible yaw, rotates forward over the top, and admits only its own
collision-checked 1.96-unit travel. Keep 0.28s movement/0.42s invulnerability/+4;
prevent held/tap stacking and retrigger during the whole action. No asset
replacement, general animation framework, camera/W/S change or Riven integration.

## 2026-09-04 — Separate character-art and animation-quality passes (Active)

The user approved a separate animation pass for clearer organization. Expand
the existing `vigil-authored-motion` task rather than creating a duplicate or
reopening historical accepted work. The latest action-readability checkpoint
is its stable baseline. Animation owns locomotion, transitions, contact/recovery
and rig-supported follow-through; character art owns face/anatomy/topology and
surface detail. V1 motion can improve independently of finished face art.

The shared boundary is the rig/rest/weight/pose contract, not simultaneous edits
to default files. Keep one integration owner, coordinate rig changes, and retest
motion after an accepted model replacement. Rejected v2 remains off. This split
does not authorize external assets, a general animation framework, new combat
mechanics, a separate Codex task, or an automatic release of technical art.

## 2026-09-04 — Original anatomical v3 rebuild before release (Active)

The user requested another substantial art round with a muscular reference.
Use broad anatomy/proportions only; retain original fitted dark suit, mask,
cape and utility gear. Rebuild face/short neck and connected shoulder anatomy
in isolated v3 source on the unchanged 74-bone contract. No external base or
purchase is implied. Preserve v1/default and rejected v2/r4 until matched actual
Blender and Godot images visibly improve, then rerun changed-volume validation.
The separate animation-quality pass remains queued, not folded into this art
pass. Keep one visible inspection Blender and one game, with tracked bounded
background jobs and no closure of unknown or unsaved user work.

## 2026-09-04 — Use verified CC0 anatomical foundation (Active)

Independent matched review rejected v3/r1's terraced/glasses-like face and
tent-like upper torso. The originating request clarified that a suitable free
licensed generic anatomical base is authorized within this realism pass. The
official Blender Human Base Meshes v1.4.1 realistic body/head collections by
Dan Ulrich carry CC0 metadata, consistent with the bundle README and official
listing. Exact archive/source hashes and narrow import boundaries are retained
in `actors/gloam_vigil/v4/PROVENANCE.md`. The unrelated Rain/stylized rig and its
license text are not imported.

The actual unrigged foundation images visibly improve facial and clavicle/
deltoid anatomy and were independently accepted as a useful intermediate
foundation, not a finished costume or runtime release. Adapt original fitted
clothing, mask, cape, utility gear and rig; do not copy franchise appearance,
purchase anything, or call third-party anatomy wholly authored here. Preserve
v1 and rejected v2/v3. This supersedes the previous pending free-base choice.

## 2026-09-05 — Licensed captured reference for the R7 gait (Active)

Three procedural gait revisions remained visibly unnatural even when their
joint-angle and deformation gates passed. Replace only R7 grounded locomotion
with the Carnegie Mellon Graphics Lab subject 16 trial 45 run/jog reference,
using Bruce Hahne's unrestricted BVH conversion and recording exact permission,
attribution, hashes, source frames, retargeting and runtime boundaries. This is
licensed captured animation data, not CC0, franchise content or internally
authored motion.

Retarget into a compact separate runtime resource without modifying the frozen
R7 GLB/weights or gameplay root. Keep the unchanged 4.8-unit/s controller,
collision, actions, V1 default and original-IP design. R7 may bypass the legacy
hard foot lock when its plant duration exceeds the frozen chain's reach; report
support velocity and solver limits honestly instead of calling sliding a lock.
Normal-rendered consecutive-frame review, exact-source determinism, 30/60 Hz
controller checks, post-change paired performance and native user judgement are
required before release. The separately authorized action-animation phase may
continue without implying gait acceptance.

## 2026-09-05 — R7 actions use a presentation-only body-space layer (Active)

Strike, evade and takedown need deliberate deformation across the frozen R7
skeleton rather than larger versions of the legacy driver-node Euler poses.
Keep their normalized R7-only curves in
`actors/gloam_vigil/v4/motion/r7_action_reference.gd` and apply them through the
existing rig adapter. The controller remains the sole owner of gameplay root
motion, facing, collision, timing, damage, Momentum, invulnerability and action
cancellation; V1 and the frozen R7 GLB/weights remain unchanged.

The visual builder may still provide action-pivot presentation and the paired
guard fall, but the R7 body layer owns readable anticipation, contact,
follow-through and recovery. User visual/ordinary-input acceptance, paired
performance and full regressions remain release gates; passing procedural tests
does not promote R7 to the default.

## 2026-09-05 — Calibrate captured gait to target proportions (Active)

The licensed source motion is reference data, not a requirement to transfer
every source joint axis at full amplitude to a differently proportioned target.
After native review found outward leg flare and excessive upper-body lean,
retain the captured pelvis transfer, cadence and sagittal hip flexion while
applying a compact R7-only target-space calibration to thigh lateral/twist,
foot yaw and lower-spine pitch. Do not clamp the legs together, globally
counter-rotate the actor, rewrite the source/retarget JSON or alter gameplay
root motion to improve the silhouette.

Keep this calibration separate from action animation and the frozen GLB/weights,
and justify its bounds with real-controller neutral/moving measurements plus
matched profile/front/three-quarter/default renders. V1 remains default; user
visual acceptance, full regressions, paired performance and a fresh exact-title
handoff remain release gates.

## 2026-09-07 — Contextual four-attack set with commit-owned contact (Active)

Replace the single repeated strike presentation with four bounded actions:
mirrored right/left straight punches and right/left front kicks. Select among
reach-valid options using distance, target side and the preceding move, with
seeded randomness for reproducible diagnosis and no immediate repeat when an
alternative exists. This is a compact controller policy, not a combo-tree or
general combat framework.

Lock the chosen action and target eligibility at commit, apply damage at that
action's single contact beat, and revalidate range/height/blocking without
allowing late acquisition. Permit one follow-up only in the final 0.10-second
recovery window after contact; never reset or stack the live action from held or
mash input. Interruption, reset, whiff and target loss clear the buffer. Preserve
existing damage/Momentum and block gameplay-root movement during the committed
strike. R7 owns the detailed body-space pose while V1 remains the playable
default until the existing release gate is accepted.

## 2026-09-08 — Separate captured walk and run with held-input ownership (Active)

The user rejected the prior single captured gait as an unnatural walk/run alias.
Keep that evidence as rejected history. R7 now uses a distinct licensed relaxed
walk and run/jog, each with its own source cadence, contact windows and runtime
channel; blend them only across the held-Shift transition at shared contact
phase. `WASD` walks at 1.90 units/s and `Shift+WASD` runs at 4.80 units/s.

Remove zero-time key-press displacement so elapsed held input is the sole owner
of ordinary locomotion distance. Preserve controller collision/action locks and
V1. Retargeted major-bone deltas must remain on their solved bones rather than
being redistributed across different-pivot twist children. Scale presentation
root motion by one source/target leg-length ratio. Bounded target-specific
trunk/gaze and relaxed-hand refinements are allowed, but source data, frozen
GLB/weights and action mechanics remain unchanged. Native user review still
gates release.

## 2026-09-08 — One standing speed using the corrected captured run (Active)

The user superseded the separate walk/run control design after reviewing it.
Ordinary standing `WASD` now uses the corrected CMU trial 45 run at 4.80 units/s;
`Shift` has no locomotion speed or gait effect. Preserve the pre-simplification
crouch travel as an absolute 1.178 units/s rather than applying its old 0.62
ratio to the faster standing speed.

Keep the licensed walk source, generated channel, provenance and comparison reel
as superseded evidence. Preserve zero-time tap rejection, held-input ownership,
normalized diagonals, collision/action locks, focus-loss clearing, accepted
retarget/knee/trunk/hand corrections, four attacks, frozen R7 and V1 default.
This supersedes only the active controller portion of the separate-walk/run
decision above; native user judgement still gates release.

## 2026-09-08 — Target-independent strike presentation with owned contact (Active)

`SPACE` must always present a complete authored attack when the player is in a
valid action state, even when no guard is in range, the guard is behind the
visible facing, the player is safely perched, or the guard is already defeated.
Empty-space presentation preserves the visible yaw and chooses among the same
four nonrepeating punches/kicks. This is an input/readability change, not a
change to damage, Momentum or target reach.

Only a target that satisfies the facing/range/height/blocking context at commit
may be owned, and it must still pass contact-time validation. A whiff cannot
acquire a target late or deal phantom damage. The existing one-slot final-
recovery buffer also works for whiffs, while evade, crouch, jump, grapple,
takedown, hurt and reset clear the queued action and target ownership.

## 2026-09-08 — Pose-dependent grounded leg tracking (Active)

User rejection of the still-wide calves supersedes fixed-angle-only grounded
stance calibration and the old sparse/unsigned gait acceptance. Solve a narrow
ankle lane from posed hip width, then direct the knee forward by rotating the
whole leg about its hip-to-ankle chord. Preserve imported anatomy, segment
lengths, knee flexion, foot attitude and ankle fore/aft travel; never translate
bones or the gameplay root to disguise gait defects. Near-extension fading and
bounded rotations guard singular or unexpected poses. Action-specific stances
remain separate; this is not an unreviewed retarget/source rewrite.

Signed full-cycle geometry, matched normal-renderer front/profile evidence and
user gameplay-scale judgement govern acceptance. Numerical narrowing alone
cannot establish natural motion. Preserve all prior assets, captures and V1
default, and keep source flight/contact polish as explicit follow-up scope.
