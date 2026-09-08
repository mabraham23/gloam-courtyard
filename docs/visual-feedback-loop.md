# Local visual feedback loop

Use this runbook from the repository root. Current controls and acceptance live in
`PROJECT_STATE.md` and `CHECKPOINTS.md`; old commands/evidence are preserved in
[the previous runbook](history/2026-09-08-5bfd290/visual-feedback-loop.md).

## Small repeatable review

Write one question before editing, then capture the same scenario before and after.
The runner freezes Git source, records source/GLB/fixture SHA-256, engine, seed,
resolution, renderer and helper setup, imports and runs with a bounded frame count,
and produces an animated preview, contact sheet, original keyframes and manifest.

```sh
python3 tools/review.py run locomotion --ref b176305
python3 tools/review.py run locomotion
python3 tools/review.py compare work/review-runs/BEFORE_ID work/review-runs/AFTER_ID \
  --output evidence/DATE-QUESTION
```

`locomotion-front` uses the same held-input fixture from the front; `actions` covers
paired strike, forward evade and takedown. `--expect-asset SHA256` prevents testing
an unintended candidate. `--ref` chooses an existing commit; omission snapshots
current files and rejects changes during copying. This is a fixed-step diagnostic
fixture with disclosed positioning/camera helpers, not native-input evidence.

Godot must be on PATH, or pass `--godot /path/to/Godot`. Preview generation needs a
Python with Pillow; select it with `GLOAM_MEDIA_PYTHON` or the local ignored
`.artifacts/toolchain.json` key `media_python`. The current machine is configured
with the bundled Codex Python. This local dependency path is not committed.

Review the actual movement at gameplay scale before a broad test pass. Check the
whole stride/action and start/stop, not a single attractive frame or larger counts.
Use only relevant regressions after a promising visual change. A failed comparison
or rejected pose is useful history: curate a reason, then revise the next hypothesis.
`PRESERVATION.md` explains curation and raw-run retention.

## Ordinary native handoff with identity

```sh
python3 tools/review.py live --candidate
# Omit --candidate to review the unchanged V1 default.
```

This optional launcher uses a frozen source copy and ordinary controls, attaches a
small build badge and adds F12 PNG/JSON capture into the project `captures/` folder.
It never changes the production default scene or controller. The command remains
running to own the renderer lease until the game closes. `.artifacts/live.json`
records its exact PID, source snapshot and purpose. Direct ordinary Godot launches
still work, but do not get this extra identity/sidecar layer.

Before input, acquire `org.godotengine.godot` through computer control and confirm
`Gloam Courtyard Spike (DEBUG)`. Use screenshot/action/screenshot. Reset with R and
0, then F12; inspect both the image and state JSON. The sidecar records source hash,
asset, camera, positions, health, action timers, input events and image SHA. It also
checks whether source files changed since the frozen launch. Engine key events do
not themselves prove native input; record observed native play separately.

For sub-second counter/evade windows, use predetermined bursts or human timing.
Screenshot latency exceeds those windows. Do not claim continuous held movement
from zero-duration key taps or `_unhandled_input` replay. Space plays four attacks
including whiffs; target ownership still governs damage. User feel and paired
native takedown remain release gates where the current checkpoint says so.

## Shared renderer and recovery

Coordinate a rendering slot with the existing owner. Review commands use a local
exclusive lock and refuse an existing normal Godot renderer, including relative
`--path .` launches. This is cooperative protection: an unmanaged launcher cannot
be forced to respect it. Never run performance sampling alongside review capture.

Stop only the known stale/owned PID after checking its command and window. Confirm
shutdown with `cua.getState()` alone; acquiring an absent app may relaunch Project
Manager. Then launch, reacquire and verify the exact DEBUG title. Do not kill all
Godot processes. Keep one current candidate/default handoff ready for the user.

Headless import/startup checks are useful separately:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 2
python3 -m unittest discover -s tools/feedback -p 'test_*.py'
python3 work/generate_project_roadmap_local.py --check
```

Use the normal renderer for F12/MovieWriter; headless movie capture previously
crashed on a null dummy-renderer texture. Keep script/assertion/resource errors
separate from benign macOS sandbox warnings. MovieWriter timing is not runtime
performance. Final gameplay acceptance needs actual native smoke and a fresh
verified reset/F12 handoff, not only the commands above.

## Record and update

Update current state/checkpoint evidence and the task records first. Append a
stable-ID decision only for a changed rule and name what it supersedes. Run
`python3 work/generate_project_roadmap_local.py` to derive both local board pages.
Its `--check` mode catches drift without writing. Verify rendered interactions and
narrow/wide layouts when permitted; the current Browser Use URL-policy blocker is
tracked once on `board-ui`. Static checks do not close that gate.
