# Project state

Last curated: 2026-09-10

## Product vision and constraints

Build an original dark-gothic stealth-action game where correct timing feels overwhelmingly powerful and mistakes cost health and Momentum. The intended prologue is three tutorial-like missions with progressive tools, environmental puzzles, original named villains, fixed-difficulty enemy archetypes that become harder through composition and positioning, and modular body/outfit customization.

No Batman or other franchise names, likenesses, symbols, costumes, architecture, or assets. The current work is a feasibility spike, not the prologue itself.

## Active/default direction

- Godot 4.7.2, GDScript, local desktop-first.
- `project.godot` defaults to `main_3d.tscn`; `main_3d.gd` owns the true-3D courtyard and gameplay loop. `actors/character_visual_builder.gd` owns actor visuals and pose application; the in-progress authored player asset and narrow skeleton adapter live under `actors/gloam_vigil/`.
- The committed presentation is true 3D with real height and a composed orthographic three-quarter camera. Do not reopen 2D versus 3D.
- `main.tscn`/`main.gd` are a completed 2D mechanics and visual-feedback reference. Preserve them and their evidence, but do not resume them as the implementation direction.

## Current milestone

**Waiting — standing/moving jump refinement ready for user movement review
(September 10).** Stationary V gathers on the floor for 0.12s, extends both legs
through a 0.62s/1.35-unit vertical flight, then absorbs on the floor over 0.20s.
V during actual held movement carries 2.2 units along the takeoff direction and
uses a split-leg pose with alternating lead. Gentle WASD air adjustment remains;
standing jumps have no uncommanded outward travel. Contextual vault is unchanged.

Default/candidate mechanics309/311, full-mesh jump5598, legacy landing1302,
transitions67, whiffs254, headless import/startup and 12 tooling checks pass.
Matched normal-renderer close-up/default-camera evidence and native V/F12/C/Space/Q
smoke are in `evidence/2026-09-10-jump-motion/`. User feel is still the acceptance
bar, especially the short gather and landing control lock.

Current managed R14 review: PID44250, exact title `Gloam Courtyard Spike (DEBUG)`,
source `c9e551cb87cb`. The enlarged R/0/F12 reset image and state hashes are
verified in `evidence/2026-09-10-jump-motion/native/reset.png` and JSON. Native
standing jump shows fixed X/Z and airborne rise/recovery. Continuous held moving
jumps are fixture-verified and await user/native held review. V1 stays default.
September 8 and PID33868 handoffs are historical; no new performance certificate.

## Character and acceptance boundary

R14 is the isolated candidate; V1 is still the default. Exact R14 GLB SHA:
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`.
The source has 74 joints and 86,452 triangles. Hair/beard remain stylized procedural
surfaces. The user must accept appearance, held movement and paired takedown before
an integration owner makes a narrow default switch and tests that default.

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
