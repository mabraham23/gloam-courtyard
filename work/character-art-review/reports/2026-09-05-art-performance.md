# Character-art paired performance evidence

Status: **V1 preliminary baseline complete; acceptance-paired V1 and final V4
reruns PENDING.** This document does not establish a frame-rate guarantee, GPU
ceiling, visual-art acceptance, or candidate release readiness.

## Locked comparison protocol

Use `work/character-art-review/performance.gd` in a quiet window with the
normal renderer. Never add `--headless` or `--write-movie`. Run each model
explicitly so a project-default change cannot alter either side:

```sh
godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility --resolution 1920x1080 \
  --disable-vsync \
  --script /Users/markabraham/dev/batman/work/character-art-review/performance.gd \
  -- --benchmark-label=2026-09-05-art-v1 --model=v1 \
  --measured-seconds=10 --repetitions=3

godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility --resolution 1920x1080 \
  --disable-vsync \
  --script /Users/markabraham/dev/batman/work/character-art-review/performance.gd \
  -- --benchmark-label=2026-09-05-art-v4-final --model=v4 \
  --measured-seconds=10 --repetitions=3
```

The harness instantiates the real `main_3d.tscn`, disables its automatic
process callbacks, and advances it exactly once per rendered frame using a
deterministic 60 Hz simulation delta. Each case gets at least three seconds
and 120 rendered frames of warmup, then three repetitions of at least 600
samples and 10 measured wall-clock seconds each.

`ACTUAL_COURTYARD` is the real courtyard, player, and guard, with deterministic
alternating movement. `STRESS_9_PLAYER_RIGS` keeps that scene and adds eight
visual-only animated player-rig copies. Those copies are not enemy AI, and
their actor roots remain static; expanded-rig foot locking therefore early
outs on the copies instead of solving eight additional contact locks. The
stress result is a repeatable visual-rig fixture, not a gameplay population or
a profiler attribution to any one animation feature.

Before accepting either side, the emitted configuration must confirm:

- `gl_compatibility` on a non-headless display and `opengl3` driver;
- window, root viewport, visible rectangle, viewport texture, and fixed
  content-scale render size all exactly `1920x1080`;
- `Engine.max_fps = 0`, reported VSync mode `0`/disabled, fixed simulation
  rate 60 Hz, minimum measured time 10 seconds, and three repetitions;
- explicit model, runtime scene path, expanded-rig flag, and SHA-256 all match
  the intended asset;
- six case rows, two aggregates, `GLOAM_PERF_CONFIG_OK`, and
  `GLOAM_PERF_BENCHMARK_OK`, with no renderer or script errors.

## V1 preliminary baseline — complete raw result

Raw evidence:
`work/character-art-review/reports/2026-09-05-v1-performance.log`.

The run used Godot `4.7.2.stable.official.ed1daf0bf`, the Compatibility
renderer (`OpenGL API 4.1 Metal`, Apple M4 Pro), macOS display driver, and the
verified `1920x1080` render configuration above. The selected runtime asset was
`res://actors/gloam_vigil/gloam_vigil_player.glb`, SHA-256
`deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`,
with `selected_rig_is_v2=false`; the runtime scene path matched exactly.

Per-repetition duration/sample verification:

| Case | Repetition 1 | Repetition 2 | Repetition 3 | Aggregate |
| --- | ---: | ---: | ---: | ---: |
| Actual courtyard | 10.000169 s / 3,670 | 10.002432 s / 3,668 | 10.000043 s / 3,609 | 30.002644 s / 10,947 |
| Stress: nine visual rigs | 10.010305 s / 679 | 10.006903 s / 670 | 10.006730 s / 676 | 30.023938 s / 2,025 |

Actual-courtyard aggregate distributions, in milliseconds for timing rows:

| Metric | Mean | Median | p95 | p99 | Max |
| --- | ---: | ---: | ---: | ---: | ---: |
| Wall frame | 2.740718 | 2.712 | 3.0327 | 3.321 | 5.702 |
| CPU process monitor | 3.496313 | 3.241 | 5.120 | 5.681 | 5.681 |
| CPU physics monitor | 0.008234 | 0.008 | 0.014 | 0.014 | 0.014 |
| Viewport render CPU | 2.011934 | 1.995 | 2.2320 | 2.5530 | 3.582 |
| Draw calls | 401.000 | 401 | 401 | 401 | 401 |
| Objects drawn | 585.000 | 585 | 585 | 585 | 585 |
| Primitives drawn | 182,722.000 | 182,722 | 182,722 | 182,722 | 182,722 |

Stress-fixture aggregate distributions, in milliseconds for timing rows:

| Metric | Mean | Median | p95 | p99 | Max |
| --- | ---: | ---: | ---: | ---: | ---: |
| Wall frame | 14.826636 | 14.782 | 15.9608 | 16.95568 | 18.580 |
| CPU process monitor | 16.640220 | 16.430 | 18.492 | 18.555 | 18.555 |
| CPU physics monitor | 0.009751 | 0.009 | 0.015 | 0.021 | 0.021 |
| Viewport render CPU | 13.634353 | 13.599 | 14.7418 | 15.02576 | 16.495 |
| Draw calls | 601.054815 | 601 | 602 | 602 | 602 |
| Objects drawn | 787.082963 | 785 | 823 | 823 | 823 |
| Primitives drawn | 343,130.900741 | 342,846 | 343,764 | 344,222 | 344,432 |

The mean wall deltas correspond to observed cadences of approximately 364.87
frames/s for the courtyard and 67.45 frames/s for the stress fixture. These
are descriptive wall-cadence values only. Even with uncapped engine timing and
reported VSync disabled, presentation/swap/compositor pacing may remain; these
numbers are not a true GPU ceiling or an FPS guarantee. The Godot process and
render monitors may describe the preceding frame, which can produce values
greater than the current wall-frame delta, so only identical paired runs are
meaningful.

Compatibility rendering did not provide a positive viewport GPU timer for at
least 95% of samples. GPU timing is therefore **unavailable**, not zero.

## Final paired comparison — PENDING

No acceptance comparison belongs here until a visually reviewed, stable V4
asset SHA is imported and the user unlocks the Mac. The first post-baseline CUA
inventory reported the Mac locked, but the lock onset relative to the V1 run
was not independently timestamped; display-lock state during the preliminary
V1 result is therefore unverified. To exclude sleep/lock/compositor state as a
confound, the root task must rerun **both** explicit V1 and final V4 commands in
the same new quiet window after confirming unlock. Automatic unlock is
unavailable and no UI bypass is permitted.

Both acceptance runs must use the same hardware, renderer, exact render size,
scene, warmup, deterministic action sequence, stress fixture, duration,
repetition count, and reporting code. Triangle and surface counts alone do not
predict the paired result.
