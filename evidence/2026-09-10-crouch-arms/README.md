# Relaxed inward crouch arms — 2026-09-10

The user's front/profile screenshots showed extended arms hanging outside the
body. The R14 crouch now has forward elbow flexion, less shoulder reach, and
mirrored inward shoulder yaw. Hands remain separate in front of the lower torso,
with a small counter-swing during crouch travel.

The size-dependent crouch block had been overriding earlier shoulder/elbow
assignments. Those redundant anatomical assignments were removed, and the final
size-compensated block now owns the arm pose. Legs, torso clearance, movement
speed, jump curves, V1 default and the frozen GLB are unchanged.

## Rendered and numerical evidence

`index.html` is a matched 270-frame front/profile/gameplay comparison. It includes
crouch entry, idle, held travel, release and standing recovery. The fixture, seed,
engine and renderer match. The final front/profile keyframes and moving-cycle
contact sheet were inspected. Scripted Q/held D, follow cameras, hidden labels and
guard placement are disclosed helpers; this is not native held-input evidence.

Actual-skeleton geometry across 32 phases each of idle and moving crouch gives
65.78–70.37 degrees of forward elbow flexion, at least 0.077 authored units of
inward wrist offset relative to the elbow, and 0.154 units of center clearance.
The new direction/inward checks fail on the original snapshot, then pass on the
correction. Transitions pass 70/70; candidate mechanics pass 311/311. Focused
full-mesh crouch checks pass 1083/1083, sampling all 49,315 vertices at 60 Hz for
all three builds. Floor and 2.0-unit lintel clearance remain valid. Editor import
passes. The known sandbox macOS system-CA warning is separate from game results.

The first historical-snapshot regression attempt lacked its disposable import
cache and did not test behavior; its failure log is retained. Reimporting that
snapshot allowed the intended old-pose regression to run and fail only the two
new geometry gates. Rejected intermediate patches are relative to the original
snapshot: `overridden-targets` changed assignments that were later overwritten;
`outward-yaw` corrected flexion but still flared the hands. These are preserved,
not accepted variants.

## Native handoff and remaining judgement

Fresh exact-title `Gloam Courtyard Spike (DEBUG)`, PID 46972, source
`0a91576169a301fd34ec34cb18a1a200933cffe466c632435e872483103bd180`.
Native Q enter/exit, settled crouch, and enlarged R/0/F12 reset were inspected.
Selected PNGs match their sidecar hashes with no changed source. The final live
source adds the geometry checks to rendered source `00d55b5bd627`; the runtime
builder is identical. The game is left open for user playtest.

User preference for the crouch and earlier corrected jump remains pending.
V1 is still the default, R14 still a candidate, and no performance certificate or
exhaustive body self-collision claim is made. Boards are generated/schema checked;
the existing rendered board URL-policy gate remains separate.
