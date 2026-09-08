# Visual feedback loop

This is the smallest reliable loop for inspecting the local Godot spike from Codex. It provides discrete screenshots and short captures; it is not a continuous live video feed.

## Start and acquire the window

Refresh the computer-use state first. If Godot is already present, determine whether it is the game or a stale `Godot Engine - Project Manager`; do not broadly stop every Godot process. Then launch the project through the macOS app bundle:

```sh
open -a "/Applications/Godot.app" --args --path /Users/markabraham/dev/batman
```

Immediately refresh the computer-use app/window inventory. Acquire the running app by bundle identity (`org.godotengine.godot`), then capture the `Gloam Courtyard Spike (DEBUG)` window before sending input.

If the launch opens or reuses `Godot Engine - Project Manager` instead of the game, the app bundle has reused a stale process and ignored the project path. Recover deliberately:

1. Inspect the exact Godot processes with `ps ax -o pid=,command= | rg '/Applications/Godot.app|Godot Engine|Godot --'`.
2. Stop only the identified stale Project Manager or debug PID; do not use a broad process kill.
3. Use `cua.getState()` alone to confirm Godot is no longer running.
4. Run the `open -a ... --args --path ...` command again.
5. Use `cua.getState()` to confirm the new app/window state, acquire `org.godotengine.godot`, and verify the window title is `Gloam Courtyard Spike (DEBUG)` before sending input.

Do not call `cua.getApp(...)` merely to check whether Godot has shut down: acquiring an absent app can transparently relaunch Project Manager. Use `cua.getState()` for the shutdown check.

The project now launches the active true-3D scene `main_3d.tscn`; the earlier `main.tscn` 2D spike is preserved for reference and comparison.

If the `godot` CLI is preferred in a terminal, use:

```sh
godot --path /Users/markabraham/dev/batman
```

If a newly installed CLI is not found in an existing zsh session, run `rehash` or start a new shell. The `.app` launch route is the more reliable route for computer-use window discovery.

## Inspect and act

Use a screenshot/action/screenshot rhythm:

1. Capture the current game window.
2. Send one short action or small deterministic burst.
3. Capture again and compare the actual player position, HUD, messages, bars, and enemy state.

The Godot window identity can change after input. If an action reports that the app changed, refresh the inventory and reacquire the Godot window before the next action. Do not reuse a stale window binding.

F12 writes a timestamped PNG into `captures/` and displays the relative filename briefly in the game. These files are project-local and readable by Codex. The directory is created on first capture and is intentionally not `user://`. `captures/.gdignore` keeps diagnostic image sequences out of Godot's runtime asset import scan; captures remain ordinary filesystem PNGs and are not deleted or moved.

## Movement and timing

Human keyboard play holds `WASD` for continuous movement at the single standing
4.80-unit/s run speed; `Shift` does not modify locomotion. Computer-use key taps
do not maintain a held state, and zero-time press/release pairs intentionally add
no displacement. Use a deterministic held-input frame sequence for automated
movement evidence and retain human play for sustained-control feel.

Useful short verification bursts are: move to the gold anchor and press `G`, press `R` to restart, move into contact range and press `E` during the visible counter ring, or press `C` to evade.

The screenshot observation cycle takes roughly 1.1–1.5 seconds on the current desktop-control surface. That is longer than the 0.72-second attack and 0.42-second evade windows, so screenshot-then-react is not an honest automated combat test. Use predetermined input bursts to verify combat state changes and retain human play for timing feel. Screenshots remain reliable for movement, spatial state, prompts, health/Momentum, grapple stages, and success/failure evidence.

The active action-readability pass uses SPACE for one 0.36s swing with contact
at 0.14s, C for a visible-facing forward roll, and T for a 1.10s paired takedown
with contact at 0.34s. Repeat hit inputs cannot restart/stack swings. Controlled
30FPS before/after fixtures and strict 30/60Hz mesh/action checks live in
`work/action-readability/`; invoke explicitly, never through the default scene.
Keep test-position evidence separate from ordinary-input reachability.

The current character controller also supports horizontal movement on the perch and a gravity-driven fall after crossing its footprint. For a deterministic motion inspection, capture a bounded normal-renderer sequence and inspect consecutive frames for on-perch travel, edge departure, descent, and the landing message. Historical one-off harnesses stay outside the project. Repeatable v2 diagnostics now have a stable home in `work/character-quality-benchmark/`; invoke them explicitly with `--script`. Test-only harnesses must never be loaded by the default scene or alter normal launch.

The 3D camera is constrained to a courtyard-centered orbit. `J/L` rotate left/right, `I/K` adjust bounded pitch, `-` zooms out, `=` or shifted `+` zooms in, and `0` restores the default three-quarter angle. Keypad subtract/add are equivalent. Arrow keys are equivalent for human play; the letter-key aliases are the reliable automation path when arrow events are intercepted by the desktop surface. Orbit, pitch, orthographic zoom, reset, and camera-relative movement are live-verified. The zoom actions change `Camera3D.size` between `17.0` and `26.0`; moving an orthographic camera closer or farther does not change visible scale.

## Restart and shutdown

Press `R` for a fast in-game reset. To stop the debug window, close it normally or stop only the exact launched process, then confirm the next `cua.getState()` no longer lists Godot as running before starting a clean pass. Do not acquire the app merely to check shutdown because acquisition can relaunch Project Manager. Avoid accumulating multiple debug windows.

## Capture options and limits

For a single frame, use the in-game `F12` capture and inspect the resulting PNG. Godot 4.7.2 exposes built-in movie writing. Use the normal macOS renderer for this; the headless dummy renderer crashes while trying to read the movie texture on this machine.

```sh
godot --path /Users/markabraham/dev/batman --write-movie captures/gloam-smoke.avi --fixed-fps 12 --quit-after 36 --disable-vsync
```

For the lightest frame sequence, use a `.png` target:

```sh
godot --path /Users/markabraham/dev/batman --write-movie captures/gloam-frames.png --fixed-fps 12 --quit-after 6 --disable-vsync
```

The latest verified feedback-loop sequence used:

```sh
godot --path /Users/markabraham/dev/batman --write-movie captures/gloam-feedback-loop.png --fixed-fps 12 --quit-after 8 --disable-vsync
```

It produced `captures/gloam-feedback-loop00000000.png` through `captures/gloam-feedback-loop00000007.png` plus a `.wav` sidecar: eight valid 960×600 frames at 12 FPS with visibly different first/last guard patrol states. This is sampled frame capture, not continuous live video.

The accepted character fall sequence is `captures/gloam-character-fall-final00000000.png` through `captures/gloam-character-fall-final00000027.png`: 28 normal-renderer frames at 12 FPS and 960×600. It was driven by a temporary external harness, not by a project-default autoplay path. Frames 6–8 show perch travel and edge departure, frames 9–12 show descent, and frame 14 shows the courtyard-floor landing.

Godot uses the `.png` target as a filename prefix and writes zero-indexed numbered frames plus a small `.wav` sidecar. A tested six-frame run produced `gloam-frames00000000.png` through `gloam-frames00000005.png`; the first and last frames had different SHA-256 hashes and visibly showed the guard/vision cone advancing. The tested AVI run produced a valid 36-frame, 3-second, 960×600 Motion-JPEG clip.

The equivalent headless command is not reliable here: `godot --headless --path ... --write-movie ...` enters Movie Maker mode and then crashes in Godot 4.7.2 because the dummy renderer returns a null texture. This is a renderer limitation, separate from the clean headless project/runtime checks.

`--write-movie` is suitable for a short deterministic clip or frame-sequence inspection, and `--quit-after` bounds the capture. The model still receives sampled screenshots or an inspected clip, not a continuous live stream. The best near-live workflow is frequent F12 screenshots for feedback, or a short numbered/movie capture when a motion sequence matters.

## Current verified interaction evidence

The latest grapple pass verified the full range transition and route with project-local captures:

- `captures/courtyard_3d_2026-09-03_20-14-22_99329.png`: one automation step outside the strict 3.5-unit range.
- `captures/courtyard_3d_2026-09-03_20-14-29_106554.png`: next step inside, with the brightened ring and ready prompt.
- `captures/courtyard_3d_2026-09-03_20-14-38_114771.png`: launch/in-transit state.
- `captures/courtyard_3d_2026-09-03_20-14-49_126570.png`: landed/route-complete state.
- `captures/courtyard_3d_2026-09-03_20-17-02_259053.png`: completed courtyard after combat, Momentum, grapple, perch, and exit.

Use a compact end-to-end smoke play at meaningful checkpoints, not only headless checks. Exercise reset, movement, combat or evade, Momentum/health response, grapple, landing, guard defeat, and exit, then record any unreachable route or geometry/state contradiction. `captures/courtyard_3d_2026-09-03_20-17-42_299203.png` preserves the historical pre-repair silent-takedown failure, not a current open defect. The accepted Sep-4 reachable-takedown checkpoint and `captures/courtyard_3d_2026-09-04_00-02-14_43359.png` supersede it with ordinary seven-tap approach and health-100/Momentum-35 success. The former through-perch attack is now rejected by height-aware melee and covered by the character-foundation regression probe.

## Completion and local roadmap handoff

For a gameplay-affecting completion, update `PROJECT_STATE.md`, `UPCOMING_TASKS.md`, `DECISIONS.md`, and `CHECKPOINTS.md` from accepted evidence first. Then update the derived source `work/project-roadmap.html`, regenerate `work/project-roadmap-local.html`, and verify its tabs, area filter, task selection/detail, and responsive widths. Keep it local; do not publish to Sites.

Finish by closing only the stale DEBUG process if one exists, relaunching the accepted default project, reacquiring `org.godotengine.godot`, confirming the title `Gloam Courtyard Spike (DEBUG)`, and leaving that fresh game open for the next playtest.

The project deliberately does not add a video library, editor plugin, browser export, or heavy capture dependency.
