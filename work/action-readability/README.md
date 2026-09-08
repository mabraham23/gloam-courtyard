# Action readability — 2026-09-04

Playable v1/default only; no model replacement or new rendering assets.

## Behavior

- SPACE: 0.36s windup/contact/recovery. Damage/range/height evaluated once at
  0.14s, with full visible arm extension. Repeated inputs cannot restart/stack
  hits. Counter/evade can cancel pending contact. Damage/Momentum unchanged.
- C: positive-X forward somersault along visible yaw at input, independent of
  remembered travel/camera/held keys. Collision-safe 1.96 units in 0.28s;
  invulnerability and movement/retrigger lock last 0.42s. Still +4 Momentum.
- T: 1.10s reach/pull/release; guard reserved while approaching. Defeat/+35 at
  0.34s, once. Short approach uses normal blockers/personal space, not teleport.
  Darkness/behind/strict2.1 range/same-level/low-lintel gates apply.
- Guard health text updates on strike/counter contact, including during stun.

## Tests and captures

`mechanics.gd`: **196 pass**, retaining earlier gameplay regression plus delayed
contact/once/repeat/cancel/reset/range/height, facing lock, exact roll distance,
tap/held suppression, collision/perch, takedown reservation/approach and locks.
`deformation.gd`: **4,176 pass**, every actual 30/60Hz action frame, three presets,
all97,061 vertices/12 surfaces. Worst floor minimum -0.007363 world (large
takedown), within unchanged -0.03 tolerance. Contact shoulder X=-1.605rad and
local lunge0.170; every action recovers upright without root/scale/driver drift.
Historical `/private/tmp/gloam-vigil-deformation-probe.gd`: **511 pass**.
The old107 mechanics probe assumes immediate damage/old direction; the durable
196 version replaces those intentional contracts, not a claim that old107 passes.
Headless editor and120-frame runtime exit0, no script errors. Known macOS
CA/editor-settings sandbox messages are reported separately.

Normal-renderer960×600/30FPS, actual action timings,225frames per sequence:

- Before: `captures/action-before-close00000000.png` through `...00000224.png`.
- First revision: `captures/action-after-r1-close...` preserved. Its forward
  roll exposed a3.79cm head/floor miss; the visual arc was corrected, without
  changing collider or test tolerances.
- Final close: `captures/action-final-close...`; inspect13 windup,16–17 punch
  contact,85–97 forward roll,142 paired catch,150 pull,158 release.
- Final gameplay camera: `captures/action-final-courtyard...`, identical fixture.
  Three rapid inputs yield one completed swing, not three instant hits.

These sequences use test-only positions/timing, not ordinary-keyboard evidence.
Movie encode speed is not a performance result.

Ordinary-input smoke, no helper positions: shadow/T → grapple → exit passes at
health100/M35 (`18-22-25_28234`, `18-22-47_50043`, `18-22-53_56568` capture suffixes).
One SPACE yields guard78/M13 (`18-23-12_75608`). A bounded combat burst defeats
the guard at health82/M75 after one normal18-damage attack (`18-23-41_104301`).
Large/accent roll recovery (`18-23-58_120786`), small crouch/travel
(`18-24-08_130952`), jump/camera/orbit/pitch/zoom/travel (`18-24-17_140357`) pass.
All are `captures/courtyard_3d_2026-09-04_<suffix>.png`. Long observation pauses
after the single hit let the guard down the player; `18-23-21_83994` is not
successful combat or failed-invulnerability evidence. Reactive windows remain
shorter than screenshot latency; deterministic tests own exact timing.

Post-change performance smoke: existing benchmark, explicitv1,1920×1080,
GLCompatibility/M4Pro, one≥3s warmup + one≥10s sample per case. Courtyard2399
frames: median/p95/p99=4.031/5.302/5.675ms. Nine visual rigs601frames:
16.660/17.074/17.207ms. `performance.log` preserves full data. This is a bounded
smoke, not a new paired study/GPU ceiling/enemy-count guarantee. The courtyard
fixture exercises movement; static-root stress copies include strike/evade but
not the new takedown. GPU timing unavailable. No overall FPS guarantee.

## Reproduce

```sh
godot --headless --path . --script res://work/action-readability/mechanics.gd
godot --headless --path . --script res://work/action-readability/deformation.gd
godot --path . --script res://work/action-readability/sequence.gd --write-movie captures/action-review.png --fixed-fps 30 --quit-after 225 --disable-vsync -- --close
```

Omit `-- --close` for gameplay camera. Use managed normal-renderer permission,
never headless movie mode. No default scene loads these harnesses. No mocap,
physical cloth, professional animation or face-art acceptance implied; v2 stays
rejected/off. Current board browser interaction/responsive verification remains
blocked by the recorded URL-policy denial; static checks are separate.

Fresh exact-title DEBUG handoff left open:
`captures/courtyard_3d_2026-09-04_18-32-58_9672.png`, default medium/pink v1,
health100/M0/guard100, default camera and reset objective. No production source
changed afterward. Board: 11 unique tasks, one valid inline script, 13 unique
DOM IDs and exact source/wrapper parity; browser verification remains blocked.
