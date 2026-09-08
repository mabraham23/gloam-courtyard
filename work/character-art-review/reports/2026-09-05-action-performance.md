# R7 action-quality paired performance

Status: **comparable technical pair complete; live-release acceptance still
waiting for confirmed Mac unlock.** Both runs completed consecutively in the
same work session and used the same scene, host, normal renderer, resolution,
warmup, deterministic workload, sample duration and repetition count. The
display-unlocked state could not be independently confirmed, so these results
do not replace the required unlocked ordinary-input review or justify changing
the default player.

## Protocol

- Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility/OpenGL3 on Apple M4 Pro.
- Exact `1920x1080` window, root viewport, visible rect, viewport texture and
  content-scale render size; VSync reported disabled; `Engine.max_fps = 0`.
- Each case used at least 3 seconds/120 frames of warmup followed by three
  independent samples of at least 10 seconds and 600 frames.
- `ACTUAL_COURTYARD` is the real courtyard/player/guard fixture.
- `STRESS_9_PLAYER_RIGS` is the same courtyard plus eight visual-only animated
  player-rig copies. It is not nine enemy AIs, a supported encounter count or a
  one-feature profiler attribution.
- V1 asset SHA: `deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`.
- R7 asset SHA: `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.

Reproduction:

```sh
godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility --resolution 1920x1080 --disable-vsync \
  --script /Users/markabraham/dev/batman/work/character-art-review/performance.gd \
  -- --benchmark-label=2026-09-05-action-v1 --model=v1 \
  --measured-seconds=10 --repetitions=3

godot --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility --resolution 1920x1080 --disable-vsync \
  --script /Users/markabraham/dev/batman/work/character-art-review/performance.gd \
  -- --benchmark-label=2026-09-05-action-r7 --model=v4 \
  --measured-seconds=10 --repetitions=3
```

## Aggregate results

| Fixture | Model | Samples | Mean ms | Median ms | p95 ms | p99 ms | Max ms | Reciprocal mean cadence |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Actual courtyard | V1 | 9,340 | 3.212387 | 3.184 | 3.325 | 3.936 | 5.545 | 311.295/s |
| Actual courtyard | R7 | 8,987 | 3.338700 | 3.249 | 3.8957 | 4.95328 | 5.742 | 299.518/s |
| Nine visual rigs | V1 | 2,106 | 14.259754 | 14.198 | 14.84875 | 15.21935 | 16.158 | 70.127/s |
| Nine visual rigs | R7 | 1,951 | 15.384599 | 15.188 | 17.098 | 19.1525 | 20.243 | 65.000/s |

Relative to V1, R7 increases mean wall time by about **3.9%** in the real
courtyard and **7.8%** in the artificial nine-rig stress fixture. R7 also uses
fewer draw calls/objects/primitives in these fixtures: 391/575/about 179,206 in
the courtyard versus V1's 401/585/182,722; 511/about 698/about 310,318 in stress
versus V1's 601/about 787/about 343,113.

The reciprocal mean cadence is descriptive only. Presentation, swap and
compositor behavior can remain even with VSync reported disabled, so it is not
an FPS guarantee or GPU ceiling. Compatibility rendering returned no usable
positive viewport GPU timer; GPU timing is **unavailable**, not zero. Godot's
process/render monitors may describe the preceding frame, so only the identical
paired wall-time results above are compared.

Both commands emitted `GLOAM_PERF_CONFIG_OK` and
`GLOAM_PERF_BENCHMARK_OK`, with all six repetitions meeting the time/sample
floor and no renderer or script error.
