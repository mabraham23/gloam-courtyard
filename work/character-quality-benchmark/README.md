# Character quality performance benchmark

This is a read-only comparison protocol for the current authored player and a
later character-quality candidate. It does not alter gameplay, assets, project
settings, evidence status, or the roadmap.

The benchmark harness is preserved with the evidence tools:

`work/character-quality-benchmark/benchmark.gd`

The current working session also keeps the original external copy at
`/private/tmp/gloam-vigil-performance-benchmark.gd`; the project-local copy is
the durable reproduction source.

## Claim boundary

- `ACTUAL_COURTYARD` is the real `main_3d.tscn` with its normal player, guard,
  world, HUD, and scene logic.
- `STRESS_9_PLAYER_RIGS` is the same courtyard plus eight visual-only animated
  copies of the player rig. The copies are not enemies, do not run AI, and do
  not represent a planned encounter.
- The harness drives the real courtyard scene once per rendered frame with a
  deterministic 60 Hz simulation delta. It does not claim native-input feel.
- This is normal rendering, not headless rendering and not movie writing.

## Reproduction

Close the accepted DEBUG game and pause Blender rendering/export or other heavy
workloads before each run. Use the same machine, power state, Godot build, asset
state, and exact command for both candidates:

```sh
godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility \
  --rendering-driver opengl3 \
  --resolution 1920x1080 \
  --disable-vsync \
  --script /private/tmp/gloam-vigil-performance-benchmark.gd \
  -- --benchmark-label=current-v1-deb5bab
```

That command and the recorded table below preserve the original one-repetition
v1 baseline. Do not relabel it as a long-run result.

After the builder exposes explicit `build_player(..., use_v2=false/true)`
selection, run the final paired comparison with both models selected explicitly:

```sh
# v1, even after the project default changes
godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1920x1080 --disable-vsync \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/benchmark.gd \
  -- --benchmark-label=final-v1 --model=v1 --measured-seconds=10 --repetitions=3

# v2, with every other setting unchanged
godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1920x1080 --disable-vsync \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/benchmark.gd \
  -- --benchmark-label=final-v2 --model=v2 --measured-seconds=10 --repetitions=3
```

Each final repetition measures at least ten seconds and 600 frames after its
own warmup. A valid run must print `GLOAM_PERF_CONFIG_OK`, one case result per
repetition, an aggregate for each case, and `GLOAM_PERF_BENCHMARK_OK`.
For an explicit `v1` or `v2` run, the configuration also verifies the adapter
actually returned that rig generation and records the selected GLB path plus
its SHA-256, so a later default change cannot silently relabel either side.

The project uses a 960×600 `canvas_items` design size, and macOS reports window
sizes in logical points. The first guarded launch proved that `--resolution`
alone produced a 3111×1944 HiDPI render texture. The harness therefore sets a
fixed root-viewport content scale and rejects the run unless the window, root
viewport, visible rectangle, and viewport texture all report exactly
1920×1080. It also rejects a renderer other than `gl_compatibility`, a headless
display, nonzero `Engine.max_fps`, or enabled vsync.

The original baseline warms each case for at least three seconds and 120 frames,
then collects 600 frames. The final protocol repeats each case three times and
requires at least ten measured seconds per repetition after warmup. Frame time
comes from monotonic wall-clock deltas. Godot's performance
monitors provide process time, physics time, draw calls, objects, and
primitives; the measured root viewport supplies CPU render time. Values are
reported as minimum, mean, median, p95, p99, and maximum. The compatibility
backend did not return a positive viewport GPU timer for at least 95% of either
sample, so GPU timing is explicitly unavailable rather than inferred.

## GLB export audit

`check_glb_export.py` parses the GLB JSON and binary accessors directly with the
Python standard library. It does not start Blender, Godot, or a renderer:

```sh
python3 work/character-quality-benchmark/check_glb_export.py \
  path/to/candidate.glb --expect-joints 20
```

It reports vertex references and unique position-accessor vertices, indexed
triangles, skin/joint usage, maximum nonzero influences, normalized weight-sum
error, one-use versus shared material surfaces, normal-map image dimensions,
and morph-target counts and deltas. Dense and sparse morph accessors are fully
materialized; sparse index ordering/ranges, buffer-view bounds, accessor
counts/types, declared float min/max, finite combined values, and actual
nonzero position deltas are checked. More than four influence slots,
unnormalized or empty weights, invalid joint slots, missing
normals/tangents/UV0, or unused deform bones fail. The hierarchy-only `root`
joint is allowed to have no direct vertex weights and remains explicitly
reported. Candidate contracts can also pin normal-map, surface, material, and
named-morph expectations; absence is otherwise reported without inventing a
requirement. For example:

```sh
python3 work/character-quality-benchmark/check_glb_export.py candidate.glb \
  --expect-joints 74 --expect-surfaces 7 --expect-materials-used 5 \
  --require-normal-maps --min-normal-map-size 1024 --expect-normal-maps 5 \
  --min-morph-targets 4 --expect-morph-name blink.L \
  --expect-morph-name blink.R --expect-morph-name brow_inner_raise \
  --expect-morph-name jaw_clench
```

The checker passes current v1 and reproduces its export facts: 97,061 vertices,
172,620 triangles, one skin with 20 joints (19 weighted plus structural root),
12 one-use material surfaces, maximum three nonzero influences, normalized
weight error below `9e-8`, no normal maps, and no morph targets.

The stable r3 candidate at SHA-256
`a786d082fb1b9aea0d383dd0a06e0c43826b20bf35b4edb4b60ea50b2882ee3b`
passes the strict command above: 83,632 triangles, seven draw primitives,
50,940 exported position-accessor vertices (42,024 authoring vertices before
material/attribute splits), five materials, and 74 joints with all 74 actually
weighted. Its actual maximum is two nonzero influences and its worst weight
sum error is below `3e-8`. Five normal-map bindings resolve at 2048×2048 for
suit/skin and 1024×1024 for gear/boots/accent. All four named sparse morphs
materialize to finite nonzero position shapes with valid counts, bounds, and
declared min/max; left and right blink arrays are distinct.

## Imported LOD audit

`inspect_imported_lods.gd` interrogates each live imported `ArrayMesh` RID with
`RenderingServer.mesh_get_surface()`. It validates and reports the actual base
and alternate index buffers, index stride/ranges, triangle counts, and raw
`edge_length` thresholds. This is stronger evidence than
`meshes/generate_lods=true` in the import file:

```sh
godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/inspect_imported_lods.gd \
  -- --label=final-v2 --asset=res://actors/gloam_vigil/v2/gloam_vigil_player_v2.glb
```

The thresholds are not camera distances; effective selection also depends on
projection, viewport, mesh scale, and LOD bias. Godot's generated mesh LODs
reuse each surface's full vertex and blend-shape buffers and substitute only a
simplified index buffer. A morph-bearing face surface can therefore reduce
triangles, but it does not get independently simplified morph-delta data or a
smaller vertex/blend-shape buffer.

For the stable r3 import above, the runtime probe found 35 real LOD buffers and
no malformed indices:

| Surface | Base triangles | LOD triangles | Raw `edge_length` thresholds |
|---|---:|---|---|
| Body / suit | 26,048 | 13,024; 6,512; 3,256; 1,628; 814; 396 | .004540; .008080; .013930; .028459; .084091; .919257 |
| Body / gear | 9,584 | 4,792; 2,396; 1,198; 598; 56 | .004363; .007757; .017763; .092198; .845599 |
| Boots | 8,832 | 4,416; 2,208; 1,104; 552 | .003660; .007501; .013699; .060364 |
| Accent | 1,208 | 604; 302; 150; 74 | .002647; .006657; .012641; .072195 |
| Cape | 13,312 | 6,656; 3,328; 1,664; 832 | .004009; .009778; .020623; .086127 |
| Face / skin | 20,360 | 10,180; 5,090; 2,544; 1,272; 636 | .001583; .002821; .005389; .012542; .052784 |
| Face / gear | 4,288 | 2,144; 1,072; 536; 268; 134; 66; 20 | .000468; .000837; .001352; .003339; .005009; .017095; .068847 |

## Deformation and equal-light review harnesses

The full-mesh CPU deformation probe exercises the exact v2 adapter at three
scales across walking and every action state. It checks imported-rest parity,
all skinned vertices and active relative morph deltas, floor/foot contact,
bounds, scale stability, and recovery:

```sh
godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/deformation_review.gd
```

`quality_stage.gd` is a normal-renderer, equal-light/equal-scale visual stage,
not a performance benchmark or gameplay proof. Valid `--view` values include
`actions`, `face`, `face-profile`, and `face-three-quarter`:

```sh
godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1920x1080 \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/quality_stage.gd \
  -- --view=actions
```

## Expanded rig and stance-lock probes

`runtime_contract.gd` proves that the explicit v2 path drives nonzero motion in
the added clavicle, twist, wrist, finger, toe, eye, jaw, and cape groups, drives
all four facial morphs, and returns exactly to bind:

```sh
godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/runtime_contract.gd
```

The stable a786 import reports
`GLOAM_V2_RUNTIME_CONTRACT_OK failures=0`.

`foot_plant_review.gd` compares the same held 4.8 m/s movement and 7.2 rad/s
turning with and without v2 stance locking at both 60 Hz and 30 Hz. It also
checks turn, teleport, action release, and gameplay-root preservation:

```sh
godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/foot_plant_review.gd
```

It reports `GLOAM_V2_FOOT_PLANT_OK failures=0`. Maximum ankle-origin drift fell
from 0.59842 m to 0.02408 m at 60 Hz and from 0.59836 m to 0.02129 m at 30 Hz.
The lock was active for 63 of 73 support frames at 60 Hz and 35 of 38 at 30 Hz;
unreachable tail frames are deliberately released rather than forced. This
measures one ankle origin during designated stance intervals, not whole-sole
contact area, traction physics, rendered quality, native input, or visual-art
acceptance.

## Current v1 baseline

Hardware: Apple M4 Pro, 14 CPU cores, 20 GPU cores, 24 GB memory. Godot reports
OpenGL 4.1 over Metal through the compatibility renderer. Asset SHA-256:
`deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`.

| Metric | Actual courtyard | Courtyard + 8 visual rigs |
|---|---:|---:|
| Mean FPS from wall frame time | 237.62 | 60.00 |
| Frame median / p95 / p99 (ms) | 4.130 / 5.340 / 5.617 | 16.664 / 17.036 / 17.292 |
| CPU process median / p95 / p99 (ms) | 5.633 / 5.999 / 5.999 | 17.243 / 18.378 / 18.378 |
| CPU physics median / p95 / p99 (ms) | 0.011 / 0.012 / 0.012 | 0.011 / 0.018 / 0.018 |
| Viewport CPU render median / p95 / p99 (ms) | 2.668 / 2.884 / 3.185 | 14.352 / 14.706 / 14.991 |
| Draw calls median / p95 | 401 / 401 | 601 / 602 |
| Objects drawn median / p95 | 577 / 577 | 777 / 815 |
| Primitives drawn median / p95 | 182,706 / 182,706 | 342,964 / 343,748 |
| GPU frame time | Unavailable | Unavailable |

Wall-clock frame-time distributions are the primary smoothness comparison.
Godot's process monitor is retained as an engine-reported CPU diagnostic and
should be compared only against the same monitor in the identical harness.
Compare the later candidate against both cases and report absolute values and
percentage change; do not turn the artificial stress fixture into a gameplay or
enemy-count claim.

The exact 60.00 FPS stress cadence is an observed presentation cadence, not a
measured GPU ceiling. A compositor, swap path, or backend pacing can still
produce that cadence when `Engine.max_fps` is zero and Godot reports vsync off.
Likewise, `Performance.TIME_PROCESS` can describe the preceding engine frame or
another monitor-update interval, so a process value slightly above a wall-frame
delta is not proof of impossible timing and should not be subtracted from it.
The fixed 60 Hz simulation step keeps animation and AI state comparable but is
not the measured render cadence. Only the courtyard guard is real AI; all eight
added stress rigs are visual/pose copies with no enemy logic.

## Final paired authoring-r4 result

Both explicit runs completed cleanly on the same frozen production state. Each
case contains three independent warmups and at least ten measured seconds per
repetition. The v1 run fingerprints
`deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`;
the v2 run fingerprints
`a786d082fb1b9aea0d383dd0a06e0c43826b20bf35b4edb4b60ea50b2882ee3b`.
Both verified a 1920×1080 window, viewport, visible rectangle, and render
texture with `gl_compatibility`, OpenGL 3, vsync disabled, and no FPS cap.

| Actual-courtyard metric | Explicit v1 | Explicit v2 |
|---|---:|---:|
| Total frames / measured wall time | 7,187 / 30.010 s | 7,154 / 30.008 s |
| Observed FPS from mean wall delta | 239.49 | 238.40 |
| Frame median / p95 / p99 (ms) | 4.052 / 5.307 / 5.681 | 4.089 / 5.319 / 5.737 |
| CPU process median / p95 / p99 (ms) | 5.785 / 7.970 / 8.709 | 6.140 / 7.678 / 8.632 |
| CPU physics median / p95 / p99 (ms) | 0.012 / 0.016 / 0.017 | 0.010 / 0.015 / 0.015 |
| Viewport CPU render median / p95 / p99 (ms) | 2.644 / 2.825 / 2.983 | 2.506 / 2.984 / 3.276 |
| Draw calls median / p95 | 401 / 401 | 391 / 391 |
| Objects drawn median / p95 | 577 / 577 | 567 / 567 |
| Primitives drawn median / p95 | 182,706 / 182,706 | 182,804 / 182,804 |

In the real one-player courtyard, v2 changes mean frame time by +0.45%, median
by +0.90%, p95 by +0.22%, and p99 by +0.99%. Its engine-reported process
median is 6.14% higher, while its render median is 5.22% lower. This supports
smooth one-player technical feasibility on the measured M4 Pro; it does not
accept the candidate's appearance or make v2 the default.

| Artificial nine-player-rig stress metric | Explicit v1 | Explicit v2 |
|---|---:|---:|
| Total frames / measured wall time | 1,801 / 30.066 s | 1,800 / 30.334 s |
| Observed FPS from mean wall delta | 59.90 | 59.34 |
| Frame median / p95 / p99 (ms) | 16.656 / 17.128 / 18.557 | 16.665 / 18.959 / 21.449 |
| CPU process median / p95 / p99 (ms) | 17.271 / 20.143 / 21.751 | 19.702 / 23.423 / 23.493 |
| CPU physics median / p95 / p99 (ms) | 0.011 / 0.016 / 0.027 | 0.011 / 0.016 / 0.017 |
| Viewport CPU render median / p95 / p99 (ms) | 14.502 / 15.022 / 15.868 | 13.391 / 15.520 / 17.628 |
| Draw calls median / p95 | 601 / 602 | 511 / 512 |
| Objects drawn median / p95 | 777 / 815 | 687 / 725 |
| Primitives drawn median / p95 | 342,830 / 343,748 | 342,852 / 342,928 |

The stress median is essentially unchanged (+0.05%), but v2's frame p95 and
p99 are 10.69% and 15.59% higher, and its process median is 14.08% higher.
That is consistent with broader v2 rig, animation, morph, and contact-update
CPU overhead worth monitoring if future scenes add many fully animated rigs;
it is not a profiler attribution to any one subsystem. In particular, the
eight added copies have static actor roots, so stance lock deliberately
early-outs and does not solve foot-lock IK for them. Only the moving gameplay
actor can engage that lock in this fixture. The same run reduces median draw
calls by 90 and objects by 90. It is still a visual-copy stress fixture, not
evidence for nine AI enemies, and its near-60 cadence remains presentation
pacing rather than a measured GPU ceiling. The compatibility backend returned
no usable GPU timer for either model.
