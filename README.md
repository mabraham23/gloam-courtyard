# Gloam Courtyard — Godot 4 feasibility spike

Gloam Courtyard is an original dark-gothic stealth-action prototype. Its long-term product vision is a three-mission tutorial/prologue: timing-based combat that feels dominant when read correctly and costly when mistimed, fixed-difficulty enemy archetypes combined into harder encounters, progressive tools and environmental puzzles, original named villains, and modular character/outfit customization.

The repository currently proves only one small courtyard loop with runtime-created GDScript primitives. It must not use Batman or other franchise names, likenesses, symbols, costumes, architecture, or assets.

## Handoff spine

A fresh task should read these in order:

1. [AGENTS.md](AGENTS.md)
2. [docs/PROJECT_STATE.md](docs/PROJECT_STATE.md)
3. [docs/UPCOMING_TASKS.md](docs/UPCOMING_TASKS.md)
4. [docs/DECISIONS.md](docs/DECISIONS.md)
5. [docs/CHECKPOINTS.md](docs/CHECKPOINTS.md)
6. [docs/visual-feedback-loop.md](docs/visual-feedback-loop.md)

`PROJECT_STATE.md` is current truth; `CHECKPOINTS.md` decides what is actually verified. The active/default direction is local desktop-first true 3D. The completed 2D `main.tscn`/`main.gd` spike is preserved only as mechanics and visual reference.

## Entry points and launch

- `project.godot` launches `main_3d.tscn`.
- `main_3d.tscn` attaches `main_3d.gd`, which procedurally builds the active 3D scene, HUD, and gameplay loop.
- `actors/character_visual_builder.gd` builds the original player/guard geometry, named limb pivots, and reusable visual poses.
- `main.tscn`/`main.gd` are the preserved 2D reference.
- `work/project-roadmap.html` is the editable derived board; `work/project-roadmap-local.html` is its regenerated standalone local view.
- The verified local engine is Godot 4.7.2.

From this directory:

```sh
godot --path .
```

For the most reliable computer-control window on macOS:

```sh
open -a "/Applications/Godot.app" --args --path /Users/markabraham/dev/batman
```

Use the screenshot/action/screenshot workflow in [docs/visual-feedback-loop.md](docs/visual-feedback-loop.md). `F12` saves a timestamped viewport PNG under `captures/`; the normal renderer can also write short numbered PNG sequences. Do not use headless movie mode on this machine.

If the launch command opens or reuses Godot Project Manager instead of the game, inspect the exact Godot process, stop only that stale PID, confirm shutdown with a state refresh, relaunch, acquire `org.godotengine.godot`, and verify the window title is `Gloam Courtyard Spike (DEBUG)` before input. Do not acquire the app merely to check whether it stopped; acquisition can relaunch Project Manager.

## Current control map

- `WASD`: camera-relative run at 4.80 units/s using the corrected captured gait.
- `Shift`: no locomotion modifier; movement intentionally has one standing speed.
- `G`: grapple near the gold anchor to the real-height perch.
- `SPACE`: close-range strike.
- `E`: counter during the attack window; the narrow `PERFECT` band deals more damage and builds more Momentum.
- `C`: evade with temporary invulnerability; the richer directional roll is a planned follow-up.
- `T`: silent takedown while concealed, close, and behind the guard.
- `1` / `2` / `3`: lean, standard, or broad body proportions.
- `X`: swap between the two placeholder accent colors.
- `R`: restart the courtyard.
- `F12`: save a project-local screenshot.

The verified 3D checks cover original stylized actor silhouettes, all body/accent variants, player and guard walk cycles, travel-facing turns, grounded separation, combat reach, grapple/perch walking, edge fall and landing, height-aware melee, restart, evade activation, rapid combat, guard defeat, exit success, F12 capture, and patrol motion. Silent takedown is currently unreachable in this courtyard layout.

### Camera verification status

`J/L` bounded orbit, `I/K` bounded pitch, `-`/`=` orthographic zoom, and `0` default-view reset are live-verified. The checks also covered shifted `+`, camera-relative movement after rotation, gameplay restart, F12 capture, and clean post-change editor/runtime launches. Arrow-key equivalents are implemented for human play; keypad add/subtract are also mapped through Godot's InputMap.

## What to test

The guard patrols, projects a 3D vision wedge, accumulates suspicion, becomes alert, closes distance, and attacks. The verified completion path uses timing-based combat and then the violet `EXIT` gate. The intended stealth-takedown path is currently unreachable and is a next-fix criterion. Health and Momentum make misses costly and correct sequences powerful.

## Scope and art boundary

Verified 3D presentation includes primitive gothic scale layering, varied wet slabs and puddles, cool moonlight against amber practical lights, readable stylized humanoids, idle/walk blending, travel-facing turns, movement lean, interpolated grapple travel, and short strike/perfect-counter flashes. It does not yet prove authored/painterly art, production skeletal animation, controller feel, mission structure, villain content, puzzles, progressive tools, inventory, story/dialogue, performance at scale, browser export, networking, or save/deployment systems.

Do not broaden systems next. The grapple-readability change is live-verified: a visible 3.5-unit activation ring, dotted ascending route, state-aware prompt, and separate ready/transit/complete feedback replace the misleading flat yellow bar. Evidence includes `captures/courtyard_3d_2026-09-03_20-14-29_106554.png` (ready), `captures/courtyard_3d_2026-09-03_20-14-38_114771.png` (launch), `captures/courtyard_3d_2026-09-03_20-14-49_126570.png` (landed), and `captures/courtyard_3d_2026-09-03_20-17-02_259053.png` (`COURTYARD CLEAR`).

The character foundation fixes the former through-perch attack with height-aware melee. The remaining courtyard issue is the advertised silent-takedown setup, which is still unreachable. Follow [docs/UPCOMING_TASKS.md](docs/UPCOMING_TASKS.md) for the sequential grapple/combat/evade/crouch/jump work and the later parallel map lane. Screenshot observation takes roughly 1.1–1.5 seconds, longer than the 0.72-second attack and 0.42-second evade windows, so use predetermined input bursts or human timing for reactive combat checks.

`main_3d.gd` is intentionally centralized for the feasibility spike. Do not refactor speculatively; if this refinement creates distinct reusable concerns or repeated growth, pause for a bounded organization checkpoint and define stable homes before sprawl continues.
