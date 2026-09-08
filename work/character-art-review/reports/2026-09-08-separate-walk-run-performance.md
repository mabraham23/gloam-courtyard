# R7 separate walk/run performance — 2026-09-08

Status: passed technical benchmark; not user acceptance or an FPS guarantee.

Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --path /Users/markabraham/dev/batman \
  --rendering-method gl_compatibility \
  --resolution 1920x1080 \
  --disable-vsync \
  --script res://work/character-art-review/performance.gd \
  -- --benchmark-label=r7-separate-walk-run --model=v4 \
  --measured-seconds=10 --repetitions=3
```

Configuration validated the exact frozen R7 GLB SHA
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`,
Godot 4.7.2 compatibility renderer, OpenGL3/Metal, 1920×1080 viewport, disabled
vsync, 60 Hz deterministic simulation, at least 600 samples and at least ten
wall-clock seconds per repetition. GPU viewport timing was unavailable.

| Case | Mean wall ms | p95 | p99 | Observed FPS | Viewport render CPU mean |
| --- | ---: | ---: | ---: | ---: | ---: |
| Actual courtyard, 3 repetitions / 30.008 s / 5,039 frames | 5.9551 | 8.3391 | 9.2061 | 167.92 | 3.4741 ms |
| Courtyard + 8 visual-only R7 copies, 3 repetitions / 41.357 s / 1,800 frames | 22.9759 | 31.7079 | 34.7766 | 43.52 | 18.0447 ms |

The stress case is nine animated player visuals, not nine enemy AIs or a
supported crowd count. Observed reciprocal wall cadence can include compositor
or swap pacing and is not a GPU ceiling. The locomotion pass changes animation
sampling/controller math, not the 85,040-triangle mesh, seven surfaces, five
materials, 74-bone rig or 36 imported LOD buffers.
