# Project state

Last curated: 2026-09-27

## Product vision and constraints

Build an original dark-gothic stealth-action game where correct timing feels overwhelmingly powerful and mistakes cost health and Momentum. The intended prologue is three tutorial-like missions with progressive tools, environmental puzzles, original named villains, fixed-difficulty enemy archetypes that become harder through composition and positioning, and modular body/outfit customization.

No Batman or other franchise names, likenesses, symbols, costumes, architecture, or assets. The current work is a feasibility spike, not the prologue itself.

## Active/default direction

- Godot 4.7.2, GDScript, local desktop-first.
- `project.godot` defaults to `main_3d.tscn`; `main_3d.gd` owns the true-3D courtyard and gameplay loop. `actors/character_visual_builder.gd` owns actor visuals and pose application; the in-progress authored player asset and narrow skeleton adapter live under `actors/gloam_vigil/`.
- The committed presentation is true 3D with real height and a composed orthographic three-quarter camera. Do not reopen 2D versus 3D.
- `main.tscn`/`main.gd` are a completed 2D mechanics and visual-feedback reference. Preserve them and their evidence, but do not resume them as the implementation direction.

## Current milestone

**Waiting — R14 corporate sentry candidate ready for live review (September 27).**
After preferring the R14 player to the older V1 presentation, the user requested
an enemy on the same high-quality base with a red corporate-guard identity,
helmet and gun. Candidate review mode now gives the guard the exact frozen R14
74-joint body/rig while preserving the production V1/procedural default pair.

The sentry removes the player cape and hairstyle, retains the authored suit
normal/roughness response under a crimson albedo, and adds charcoal equipment,
an original segmented helmet with visor/comms details, plus a pelvis-following
thigh holster and compact sidearm. The sidearm is visual equipment; the existing
close-range archetype, timing, damage, AI, collision and takedown remain unchanged.

A fixed 210-frame same-light/scale comparison covers idle, patrol, strike,
reaction and defeat. Source `36805cdb75a9`, exact R14 asset SHA and all rendered
frames passed. The candidate also passes a 14-check guard contract, 312 mechanics
checks and all 12 feedback-tool tests. Visual inspection confirms a clear red
enemy silhouette and stable helmet/holster attachment. Fresh exact-title native
handoff PID 77731 is open from managed run `20260927T225539Z-live-f57781`.
F12 image/state `review_36805cdb75a9_77731_47235777` confirms health 100,
Momentum 0, guard 100 and no source drift. Native combat/takedown input and user
gameplay-scale taste remain the acceptance gate.
Evidence: `evidence/2026-09-27-corporate-sentry/`.

## Character and acceptance boundary

R14 is the isolated candidate; V1 is still the default. Exact R14 GLB SHA:
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`.
The frozen source has 74 joints and 86,452 triangles. Current runtime removes
1,412 old hair triangles and adds 3,520 replacement triangles (88,560 before LOD).
The face is clean-shaven; hair remains stylized mesh geometry. The user must accept appearance, held movement and paired takedown before
an integration owner makes a narrow default switch and tests that default.

The corporate sentry is a separate candidate-only use of the same R14 anatomical
foundation. It does not promote R14 as the production player and does not replace
the procedural default guard until user acceptance and a separate narrow switch.

## Current controls and protected values

- Held `WASD`: 4.80 units/s; `Shift` has no locomotion effect. A zero-time press/release adds no distance. `Q`: crouch at exactly 1.178 units/s and the 2.0-unit lintel gate.
- `SPACE`: four nonrepeating strikes, including target-free whiffs; contact requires a target owned at commit. `E`: counter. `C`: 1.96-unit visible-facing evade over 0.28s, with a 0.42s action/invulnerability window.
- `T`: silent takedown, 0.34s contact in a 1.10s paired action. `V`: standing/moving jump or contextual vault; 0.12s gather + 0.62s flight + 0.20s recovery for free jumps. `G`: grapple to the real-height perch.
- Free jump: stationary lift in place; actual held movement selects a 2.2-unit directional leap. Both have 1.35-unit apex and alternating leg emphasis; held WASD permits gentle 1.40-unit/s air adjustment.
- `1/2/3`: body build; `X`: accent; `R`: restart; `F12`: project-local image. The managed review launcher adds a state/identity sidecar.
- `J/L` or arrows: orbit; `I/K` or arrows: pitch; `-`/`=` or shifted `+`: orthographic zoom; `0`: camera reset.

## Verified foundation and known limits

The 3D courtyard has accepted camera, height-aware combat, crouch clearance,
jump/vault, grapple/perch/fall, takedown route, guard defeat and smoke-clear evidence.
Historical exact checks and images remain in [CHECKPOINTS.md](CHECKPOINTS.md).
Old tap-count routes and old 62%-of-standing crouch descriptions are historical;
the current held-input/absolute-speed controls above govern.

The source flight pose, foot sliding, wider action stances and close-up hair/fingers
remain visual limitations. Current native held movement/takedown and user taste
are not replaced by scripted reels or numerical checks. Riven is an accepted
static, non-default gray-box; its playable integration shape remains undecided.
The W/S direction convention remains a separate product question, not a new bug fix.
The sentry sidearm currently has no ranged-fire behavior; adding gun combat would
require an explicit mechanics/readability/encounter-design task.

## Workflow and ownership

[visual-feedback-loop.md](visual-feedback-loop.md) is the operational runbook.
Private source control: https://github.com/mabraham23/gloam-courtyard.
[Preservation](PRESERVATION.md) defines what belongs in Git, milestone archives and
local scratch. [Decision index](DECISIONS.md) identifies current rules and reversals.

The realism owner owns the controller/rig/default direction. Review tooling is in
`tools/review.py`, `tools/feedback/` and the optional `debug/` launcher; it does not
change the default scene. Inspect Git changes and active ownership before edits.
Use the renderer lease and exact-title native handoff; no broad process killing.

The board is derived from the structured task data in `UPCOMING_TASKS.md`.
Runtime, user visual acceptance and board UI verification have separate statuses.
Board interaction/responsive verification remains Browser Use URL-policy-blocked;
source validation never implies that it was visually tested.

## History

[Complete pre-migration state](history/2026-09-08-5bfd290/PROJECT_STATE.md) retains
all implementation narrative and old handoffs. Read it when investigating a past
choice; do not reload the entire history for every small iteration.
