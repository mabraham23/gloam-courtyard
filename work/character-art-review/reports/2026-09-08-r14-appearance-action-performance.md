# R14 appearance/action performance — 2026-09-08

Status: passed paired technical benchmark; not user art acceptance or an FPS
guarantee.

The two runs were executed sequentially in one quiet session with Godot 4.7.2,
the macOS compatibility renderer (`opengl3` over Metal), a 1920x1080 render
viewport, vsync disabled, fixed 60 Hz simulation, three repetitions per case,
at least ten measured wall seconds and at least 600 frames per repetition.
Viewport GPU timing was unavailable.

Exact assets:

- V1 baseline SHA: `deb5ba98af80a92fc27b7a6a8ee958a9aa9e71a2edeb5dadf2ab97aacc1f08eb`
- Frozen R14 SHA: `30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`

| Case | Model | Frames / measured seconds | Mean wall ms | p95 | p99 | Observed FPS | Viewport render CPU mean |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Actual courtyard | V1 | 5,893 / 30.010 | 5.0924 | 6.6360 | 7.1421 | 196.37 | 3.0995 ms |
| Actual courtyard | R14 | 5,883 / 30.003 | 5.0999 | 6.7529 | 7.1777 | 196.08 | 2.8698 ms |
| Courtyard + 8 visual-only copies | V1 | 1,800 / 31.595 | 17.5528 | 20.2122 | 20.9001 | 56.97 | 15.1458 ms |
| Courtyard + 8 visual-only copies | R14 | 1,800 / 33.408 | 18.5597 | 21.9153 | 24.8500 | 53.88 | 14.2687 ms |

R14 versus V1 in the actual courtyard is +0.15% mean wall time, +1.76% p95
and +0.50% p99. In the artificial nine-visual-rig fixture it is +5.74% mean,
+8.43% p95 and +18.90% p99. R14 uses 390 draw calls and 574 objects in the
actual fixture versus V1's 400/584; the measured wall difference therefore
must not be reduced to triangle count alone.

The stress fixture is one real courtyard plus eight animated visual-only player
rigs. It is not nine enemy AIs, a supported crowd count or a production scene.
Observed reciprocal wall cadence can include compositor/swap pacing even with
vsync disabled and is not a GPU ceiling. These measurements apply only to the
exact SHA and protocol above; rerun both sides after an asset, default-player or
rendering change.
