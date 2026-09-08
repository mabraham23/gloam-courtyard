# R7 locomotion-alignment performance pair

Date: 2026-09-05

Status: **technical pair complete; release still waits on user visual review.**
These runs compare the unchanged V1 default with the exact frozen R7 candidate
after the bounded grounded-locomotion alignment correction. The correction
attenuates only target-sensitive thigh lateral/twist rotation, foot yaw and
lower-spine pitch; it does not change the captured source data, gameplay root,
speed, collision, actions, asset or default selection.

## Protocol

- Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility/OpenGL3 on Apple M4
  Pro, exact `1920x1080`, reported VSync off and no engine frame cap.
- Each model/fixture used a three-second/120-frame warmup followed by three
  samples of at least ten seconds and 600 frames.
- `ACTUAL_COURTYARD` is the real player/guard scene.
- `STRESS_9_PLAYER_RIGS` adds eight visual-only animated player rigs. It is not
  nine enemy AIs and does not establish a supported crowd size.
- V1 asset SHA:
  `deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`.
- R7 asset SHA:
  `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
- Benchmark labels: `2026-09-05-locomotion-alignment-v1` and
  `2026-09-05-locomotion-alignment-r7`.

One initial normal launch was excluded before sampling: a stale live-review
process caused macOS to hand the command to an existing Godot window and leave
an idle wrapper. All exact stale project validation/review processes were
identified, stopped, and absence-confirmed before the native-permission pair
below. Both accepted runs emitted the renderer banner, configuration gate, all
six case samples and the final benchmark marker.

## Aggregate results

| Fixture | Model | Frames | Wall seconds | Mean ms | Median ms | p95 ms | p99 ms | Max ms | Viewport CPU mean / p95 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Actual courtyard | V1 | 7,161 | 30.007176 | 4.190361 | 3.8680 | 5.9890 | 6.5628 | 7.496 | 2.767107 / 3.0280 |
| Actual courtyard | R7 | 6,951 | 30.001688 | 4.316169 | 4.0520 | 6.0030 | 6.6875 | 8.009 | 2.631547 / 3.1650 |
| Nine visual rigs | V1 | 1,801 | 30.024645 | 16.671097 | 16.6480 | 17.3890 | 17.7230 | 19.481 | 14.626176 / 15.0770 |
| Nine visual rigs | R7 | 1,800 | 30.795846 | 17.108803 | 16.8115 | 20.1144 | 21.49069 | 24.193 | 13.836639 / 15.5404 |

In the actual courtyard, R7 is **3.00%** above V1 mean wall time, **0.23%**
above p95 and **1.90%** above p99. This is a comparable one-player result for
the current prototype. In the artificial nine-rig fixture, R7 is **2.63%**
above mean with a heavier tail: p95 is about **15.67%** higher and p99 about
**21.26%** higher. That tail remains a stress warning, not evidence about enemy
AI, gameplay load, or a production crowd budget.

Average draw calls/objects/primitives were `401/585/182,722` for V1 courtyard
and `391/575/179,205` for R7 courtyard; stress was about
`601.1/788.8/343,159` for V1 and `511.1/699.1/310,322` for R7. The lower R7
counts reflect its current surface/material configuration and do not isolate
animation cost.

Reciprocal wall cadence is descriptive only, not a guaranteed FPS or GPU
ceiling. Compatibility rendering returned no usable positive GPU timer, so GPU
timing is **unavailable**, not zero. Promotion still requires the user's visual
and ordinary-input acceptance of this exact R7 build.
