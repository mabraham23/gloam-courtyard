# Project working agreement

Before changing this project, read in order:

1. `docs/PROJECT_STATE.md` — current truth, active direction, controls, risks, and next milestone.
2. `docs/UPCOMING_TASKS.md` — current execution order, dependencies, ownership boundaries, and completion evidence.
3. `docs/DECISIONS.md` — append-only rationale and superseded directions.
4. `docs/CHECKPOINTS.md` — accepted evidence and exact completion bars.
5. `docs/visual-feedback-loop.md` — local Godot launch, F12, frame-sequence, and computer-control workflow.

Read the current sections and decision index first; follow linked historical entries when the task needs them. The archived checkpoint ledger remains accepted evidence.

`PROJECT_STATE.md` and `CHECKPOINTS.md` govern status. A control appearing in code, the HUD, README, or the feedback-loop guide is not verified until a checkpoint records runtime evidence. The constrained camera's orbit, pitch, orthographic zoom, default reset, and camera-relative movement are verified.

Follow the committed desktop-first true-3D direction. Preserve `main.tscn`/`main.gd` and their evidence as a 2D reference, not an active alternative. Preserve original-IP constraints: this is an original dark-gothic stealth-action work and must not reuse Batman or other franchise names, likenesses, symbols, costumes, architecture, or assets.

Keep work speed-first and comprehensible. Prefer primitive/code-drawn placeholders and small validated loops over architecture breadth or polish. Do not delete superseded spikes or evidence. At a meaningful checkpoint, refresh `PROJECT_STATE.md`, append a dated `Active` or `Superseded` entry to `DECISIONS.md` only when a decision changes, and add evidence plus next criteria to `CHECKPOINTS.md`.

Use the documented screenshot/action/screenshot rhythm. Before input, acquire `org.godotengine.godot` and confirm the window title is `Gloam Courtyard Spike (DEBUG)`. If launch reuses Project Manager, identify and stop only that stale process, confirm shutdown with state refresh alone, then relaunch; acquiring an absent app can itself relaunch Project Manager. Keep F12 project-local captures working. Every meaningful milestone also needs a smoke play-through and an evidence-backed bug/quirk review; headless checks alone are insufficient. Screenshot latency exceeds the sub-second counter/evade windows, so use predetermined bursts or human timing for reactive combat. Report actual headless/runtime results separately from benign Godot macOS sandbox warnings, and label unverified captures or code paths honestly.

`main_3d.gd` may stay centralized while that keeps the spike fast and readable. Do not refactor speculatively. When visual/content growth creates distinct reusable concerns or repeated sprawl, stop for a bounded organization checkpoint and give those concerns stable homes before continuing.

For every completed task, update docs and accepted evidence first, then edit the structured task records in `docs/UPCOMING_TASKS.md` and run `python3 work/generate_project_roadmap_local.py` to generate both board files. Do not hand-edit generated task/status HTML. Verify board interactions and responsive layouts when permitted, and record that gate separately from runtime and user acceptance. Keep the board local. Gameplay-affecting completion ends with a fresh verified `Gloam Courtyard Spike (DEBUG)` relaunch left open for playtest.

Use `docs/PRESERVATION.md` for source and artifact storage. The optional `tools/review.py` launcher snapshots source and records identity without altering the default game. Check the shared renderer lease and existing exact-title process before a capture or benchmark; coordinate a rendering slot with the current owner.
