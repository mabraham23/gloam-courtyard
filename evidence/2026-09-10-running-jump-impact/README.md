# Running-jump arms and impact correction — 2026-09-10

Technical and rendered review passed; user visual judgement remains pending.
This follow-up addresses the user's rejection of the straight-looking running-jump
arms and barely visible landing knee bend in the earlier jump checkpoint.

## Change and cause

The old elbow target was only 0.38 rad at the moving-flight peak. The landing curve
had a narrow compression peak which the rig's normal response smoothing reduced
further. Numerical floor safety had not established convincing impact absorption.

Only `actors/player_jump_motion.gd` changes runtime behavior: preserve a bent-elbow
running silhouette, reduce shoulder reach, begin preparing the knees for landing
slightly earlier, and deepen/hold the loaded impact pose before release. The
controller, 0.12/0.62/0.20 phase durations, standing/moving selection, 2.2-unit moving
travel, air control, vault and frozen character asset are unchanged.

## Rendered evidence

`index.html` is the matched 150-frame before/after profile comparison. The fixture
holds D through the first jump and landing, then mirrors the lead and releases D
in flight. Both use the same fixture hash, seed 1729, 30 Hz, 960x600 and compatibility
renderer. `comparison.json` records exact identities. `gameplay.webp`/`gameplay.jpg`
show this fixture at the default camera with final source `bb51a808e92a`.

Viewed frames 26/101 show distinctly bent flight arms. Frames 35–38/111 show a deeper
knee/hip catch and continued recovery before returning to the run. Selected original
PNGs and full render logs are retained alongside previews. Camera/guard placement,
scripted key events and held input are disclosed helpers, not native-input proof.

## Verification and limitations

- Default 309/candidate 311 mechanics and 67 transition checks pass.
- Full-mesh jump 5646 checks pass: 18 cases across three body sizes, 30/60 Hz, standing
  and both moving leads. All 49,315 vertices are evaluated each frame, with the
  existing floor/contact tolerances. Additional checks use actual skeleton joint
  positions rather than only target angles: minimum moving-flight elbow flexion
  across cases 44.13–45.17 degrees; both-knee impact peak 67.74–69.16 degrees; impact
  pelvis drop 0.147–0.204 world units. Detailed values are in `measurements.json`.
- Headless import/startup pass. Sandboxed Godot logged its known macOS system-CA
  lookup warning (`get_system_ca_certificates`); no script/resource failures or
  failed assertions occurred. This warning is separate from passing game checks.
- Both boards regenerated and schema/parity checked. The existing rendered board
  URL-policy blocker remains separate. No new performance certificate is claimed.

Native exact-title `Gloam Courtyard Spike (DEBUG)`, PID 45340, source
`bb51a808e92ae78f2510805687389ce353cb3b3f520b660beae9622e21c0381e`.
V/F12 captured airborne rise and on-floor impact/recovery at unchanged X/Z; Q
crouched after the jump. Enlarged R/0/F12 reset was inspected and left open with
health 100/Momentum 0/guard 100/default camera. Curated images match sidecar hashes,
with no changed source files. Native continuous held running remains a user-review
gate; the running evidence here is a normal-renderer controller fixture.

The landing catch remains a brief 0.20-second action. Numerical flexion and the
rendered improvement do not establish the user's preferred feel. Earlier jump
captures remain preserved as the rejected baseline; R14 stays a candidate and
V1 remains the default. Next: user reviews repeated moving jumps, especially the
elbow silhouette and the catch while continuing to hold movement.
