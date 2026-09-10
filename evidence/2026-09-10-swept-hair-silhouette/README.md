# Swept hair silhouette — 2026-09-10

The user rejected the second haircut as still bowl-like, especially while
crouched. The old rounded cap is now a 0.55 mm clipped foundation with a broad
fade above the ears and at the back. Two wide central sweeps and two lower side
sections carry the top volume; the earlier uneven fringe remains. The clean
face, anatomy, frozen R14 GLB and previous movement fixes are unchanged.

## Matched rendered review

Open `index.html` for before/after sequences and the closer crouched profile.
Both runs use the same updated fixture, engine, seed, 30 Hz, renderer, resolution
and cameras. The added raised crouched camera keeps the head clear of the HUD.
The fixture is helper-driven; it includes held movement and a moving jump, not
native reachability or user acceptance evidence.

- Before: `20260910T193114Z-hair-bfcc46`, pre-edit hair from commit `55706da`
  with the updated review camera.
- After: `20260910T194429Z-hair-88afb3`, source
  `6b51a2c0db0c32cd86586f15b804599a318dd8386533a1de17f8156339cd830c`.
- Fixture SHA: `0f470387c0ef7cca7859ebdf572db5ad5a504e1cf52e85ff67d782d20e29544b`.
- Godot `4.7.2.stable.official.ed1daf0bf`, compatibility renderer, 960 × 600.

Front, quarter, profile, rear, gameplay and crouched keyframes were inspected.
The dark continuous rim is replaced by a visible fade; the top now shows broad
sweeps. The result remains stylized mesh hair, with graphic pointed fringe and
visible clump boundaries in close-up. User hairstyle preference is still open.

## Corrections and quirks

`iterations/` retains rejected source identities, selected images and failure
logs. The first new fade used different lighting from the face and showed a
skin-colored seam. Matching Lambert-wrap diffuse lighting and retaining the
interpolated anatomical normals resolved it. The first two crown arrangements
exceeded the crouch lintel by 6.39 mm and 3.80 mm; length now grows toward the
front while the back stays short. Several narrow ridges read as repeated spikes
from the rear; rounding alone was insufficient, so the final top uses fewer,
wider overlapping sections. A wide-root fit miss was caught before writing the
asset and resolved with narrower attached roots.

The temporary normal diagnostic initially ran before the tree was ready; a
deferred run confirmed outward top normals. No diagnostic script, relaxed
clearance threshold, controller change or altered face anatomy was retained.

## Technical verification

Final rig/appearance checks pass **456/456**. Full deformation passes
**22,164/22,164** over all **50,243** vertices at three body sizes and 30/60 Hz,
including jumping, crouching, rolling and downed poses. Medium crouch max is
**1.994088**, under the unchanged 2.0-unit lintel. Replacement hair has 1,929
vertices / 3,520 triangles; runtime total is 88,560 triangles before LOD.

Full regeneration reproduces JSON SHA
`f7d753f91a1806f087473431653bab6769bea683864e2a506474761934186eae`.
The final render and live snapshot imports pass, and default startup passes.
Headless checks report the familiar macOS system-CA sandbox warning. A separate
sandboxed editor invocation could not save global editor settings; the final
managed imports have no such failure. These are separate from game-script results.
The private face compaction code is unchanged; its prior attribute/expression/LOD
integrity proof remains in the preceding clean-shave review.

## Native handoff and remaining gates

Fresh `Gloam Courtyard Spike (DEBUG)` PID **52046**, run
`20260910T194554Z-live-70926c`, matches the final rendered source. Exact title was
verified before controls. The enlarged game received Q/F12, Q/V, C/F12, then R/0
and a final F12 after a rendered reset. Live crouch and settled action states
were inspected. Motion timing is covered by the fixed-step reel and full-mesh
checks; the native taps do not certify held movement or the airborne silhouette.

All three original PNG/state pairs in `native/` have matching image hashes and
zero changed source files. Final reset is 100 health, 0 Momentum, standing and
grounded. The refreshed game is left open. PID 50365 is historical.

User hair/motion preference, native held movement and paired takedown remain
separate gates. V1 remains the default; no new performance certificate is claimed.
The local board's source/schema parity gate is separate from its existing
Browser Use URL-policy blocker for rendered interaction/responsive verification.

This compact matched review adds about 7.9 MB, bringing curated evidence to about
59 MB. Growth was reviewed: retain this before/after because the previous two
silhouettes were explicitly rejected; preserve original keyframes and native
identity evidence. No unique historical evidence was deleted.
