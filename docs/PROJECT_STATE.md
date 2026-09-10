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

**Waiting — jump elbow direction corrected, ready for user review (September 10).**
The user identified backwards elbow bending in the last running-jump pass. That
visual verdict is superseded. The jump elbow driver now flexes forward; shoulder
motion, alternating split legs, landing catch, controller timing and travel remain.

The elbow check now measures signed flexion on the actual skeleton. It rejects
all 12 moving cases on the old pose (about -56 degrees), then passes on the
correction (moving-flight minima 81–82 degrees). Full-mesh 5646, default/candidate
mechanics 309/311 and transitions 67 pass. Matched profile and gameplay captures
show both leads with forward-folding forearms. User movement judgement is pending.

Current managed R14 review: PID 46188, exact title `Gloam Courtyard Spike (DEBUG)`,
source `2dfc70da70c6`. Native V/F12/Q smoke and enlarged R/0/F12 reset were inspected;
PNG/state hashes match, with no changed source. Evidence:
`evidence/2026-09-10-jump-elbow-direction/`. PID 45340 is the rejected historical
handoff. V1 remains default; native held running and earlier R14 release gates stay
open. The known sandboxed macOS system-CA warning is separate from passing checks.

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
