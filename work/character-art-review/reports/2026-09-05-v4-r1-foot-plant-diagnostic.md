# Gloam Vigil v4 r1 foot-plant reach diagnostic

Candidate SHA-256: `8d46f24c5eccb72964e71c602ac7d0d620e31f0eed15e1c492a581f4c976bcc1`

Command:

```sh
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/character-art-review/foot_plant_diagnostic.gd
```

The diagnostic passed its own fixture integrity checks. It reproduces the fixed
60 Hz, 4.8 m/s, 7.2 rad/s cadence and uses an identically posed no-plant rig to
measure the pre-IK hip-to-captured-target reach ratio. It does not change the
adapter, asset, support intervals, or `1.015` reach limit.

## Cause

Every release is the reach guard working as designed. Frame travel is `0.08 m`,
well below the adapter's `0.22 m` discontinuity limit; turn is zero; state is
grounded; movement is one; and delta is positive. On failure the plant becomes
`blocked=true` while its support interval remains active. No state, movement,
turn, teleport, or input gate causes the coverage loss.

- Both legs are anatomically symmetric: left chain `0.9181705 m`, right chain
  `0.9181287 m`.
- Left: 29 active and 12 blocked frames across 41 support frames.
- Right: 21 active and 11 blocked frames across 32 support frames.
- Steady left captures occur at cycle `0.2536-0.2659`, then release at
  `0.3873-0.3995` after `0.56 m` of actor travel. Release ratios are
  `1.018664-1.020835`, exceeding the fixed reach distance by `3.36-5.36 mm`.
- Steady right captures occur at cycle `0.7502-0.7639`, then release at
  `0.8839-0.8976` after `0.56 m`. Release ratios are `1.020866-1.021656`,
  exceeding reach by `5.39-6.11 mm`.
- The first left stance overlaps the 0.42-second locomotion-start overlay. It
  captures at cycle `0.26738`, releases at `0.42017` after `0.64 m`, and reaches
  ratio `1.051295`, or `33.32 mm` beyond the allowed distance. This explains the
  single larger transient; later releases are tightly clustered and symmetric.
- The maximum still-active pre-IK ratio reaches `1.013821`, proving the solver
  stops before an unreachable extension rather than allowing it.

## Smallest legitimate correction

Retarget the candidate-specific locomotion and start-animation leg/pelvis keys to
the v4 anatomical chain. Preserve the support intervals and the `1.015` reach
guard. At support capture, add paired thigh/shin flex that preserves ankle/sole
height and forward contact while leaving at least `7 mm` more steady-state reach
reserve; retarget the start overlay to provide about `35 mm` reserve through its
first left stance. This changes the authored gait to fit the actual leg, instead
of lengthening bones, widening IK reach, or accepting an unreachable plant.

The correction should be candidate-specific so the accepted v1/v2 clips are not
silently changed. Re-run both the diagnostic and the unchanged acceptance review;
the next candidate must gain coverage through ratios at or below `1.015`, with no
new blocked interval or increased ankle drift. Merely raising the reach limit or
relabeling blocked frames would conceal the anatomical mismatch and is not an
acceptable fix.
