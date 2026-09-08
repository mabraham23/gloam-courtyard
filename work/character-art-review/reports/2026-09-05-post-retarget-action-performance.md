# Post-retarget R7 action performance pair

Date: 2026-09-05

Status: **technical pair complete; release still waits on user review.** These
runs compare the unchanged V1 default with the exact frozen R7 candidate after
the captured gait and R7-only strike/evade/takedown layer were integrated.

## Protocol

- Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility/OpenGL3 on Apple M4
  Pro, exact `1920x1080`, reported VSync off and no engine frame cap.
- Each model/fixture used a 3-second/120-frame warmup followed by three samples
  of at least 10 seconds and 600 frames.
- `ACTUAL_COURTYARD` is the real player/guard scene.
- `STRESS_9_PLAYER_RIGS` adds eight visual-only animated player rigs. It is not
  nine enemy AIs and does not establish a supported crowd size.
- V1 asset SHA:
  `deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`.
- R7 asset SHA:
  `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`.
- Benchmark labels: `2026-09-05-post-retarget-action-v1` and
  `2026-09-05-post-retarget-action-r7`.

## Aggregate results

| Fixture | Model | Frames | Wall seconds | Mean ms | Median ms | p95 ms | p99 ms | Max ms | Viewport CPU mean / p95 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Actual courtyard | V1 | 7,277 | 30.007075 | 4.123550 | 3.992 | 5.4394 | 6.26324 | 7.141 | 2.732400 / 2.946 |
| Actual courtyard | R7 | 7,052 | 30.004170 | 4.254704 | 4.135 | 5.53845 | 6.27043 | 7.657 | 2.607969 / 3.08045 |
| Nine visual rigs | V1 | 1,802 | 30.033068 | 16.666519 | 16.653 | 17.1299 | 17.53295 | 20.613 | 14.559140 / 15.00695 |
| Nine visual rigs | R7 | 1,800 | 30.413566 | 16.896426 | 16.6825 | 19.36385 | 21.21908 | 22.954 | 13.645923 / 15.44685 |

In the actual courtyard, R7 is **3.18%** above V1 mean wall time, **1.82%**
above p95 and **0.11%** above p99. This is a comparable one-player result for
the current prototype. In the artificial nine-rig fixture, R7 is **1.38%**
above mean but has a heavier tail: p95 is about **13.0%** higher and p99 about
**21.0%** higher. That tail remains a stress warning, not evidence about enemy
AI, gameplay load, or a production crowd budget.

Average draw objects/primitives were about `401/585/182,722` for V1 courtyard
and `391/575/179,205` for R7 courtyard; stress was about
`601.1/788.8/343,159` for V1 and `511.1/699.1/310,322` for R7. The lower R7
counts reflect its current surface/material configuration and do not isolate
animation cost.

Reciprocal wall cadence is descriptive only, not a guaranteed FPS or GPU
ceiling. Compatibility rendering returned no usable positive GPU timer, so GPU
timing is **unavailable**, not zero. Promotion still requires the user's visual
and ordinary-input acceptance of this exact R7 build.
