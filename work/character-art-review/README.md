# Character-art candidate verification

These reusable checks select only
`res://actors/gloam_vigil/v4/gloam_vigil_player_v4.glb` through the builder's
explicit candidate-path argument. The default game remains playable v1, and
the frozen rejected v2 and v3 studies are never overwritten or relabelled.

The frozen V4/R14 master is SHA
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`.
Its exact GLB/source/manifest archive, five studio views, Godot import review,
full technical suite and paired performance gate pass, but it is not an
accepted release until the user judges its appearance and motion in play.
Its realistic generic anatomical base is CC0 source geometry underneath a new
original costume and character treatment; provenance must remain recorded by
the asset owner. Passing these technical gates does not establish visual,
gameplay, or performance acceptance.

## Static/import gates

```sh
python3 work/character-art-review/glb_contract.py

godot --headless --path /Users/markabraham/dev/batman --editor --quit

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/inspect_imported_lods.gd \
  -- --label=character-art-candidate --asset=res://actors/gloam_vigil/v4/gloam_vigil_player_v4.glb

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-review/rig_contract.gd
```

`glb_contract.py` reuses the established GLB accessor parser. It requires 74
joints, at most four nonzero influences, normalized nonempty weights, all
deform bones used except an allowed structural root, seven surfaces, five used
materials, five normal maps of at least 1024px, and the four named finite,
nonzero morphs. The revised provisional ceiling is 110,000 triangles, with no
minimum. This ceiling intentionally protects the 34,998-triangle
multires-1 anatomical face instead of forcing it back under the old 90k target;
it remains substantially below v1's 172,620 triangles and 12 surfaces. Count is
not an FPS guarantee, so a final paired normal-renderer benchmark remains
mandatory before acceptance.

The LOD command inspects actual imported index buffers through
`RenderingServer`, not only import settings. `rig_contract.gd` checks the exact
semantic hierarchy, finite/non-collapsed retargeted rests, left-negative-X and
right-positive-X eye/hand/foot/clavicle meaning, forward eye axes, and at least
12 weighted vertices plus total weight 2.0 for every non-root bone. It derives
the actual imported positions rather than pinning old procedural anchors.

## Runtime gates

```sh
godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-review/runtime_contract.gd

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-review/deformation.gd

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-review/foot_plant_review.gd

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-review/mechanics.gd
```

The runtime contract proves nonzero motion in spine/twist/clavicle,
hand/finger/toe, eye/jaw, cape-chain and facial-morph channels, then exact bind
recovery. The deformation gate evaluates every imported body and the
34,998-triangle face plus active morph deltas on every actual 30/60Hz
action frame at small, medium and large body presets. It covers crouch, strike,
forward roll, takedown, grapple, grapple recovery, jump, vault, counter, hurt,
downed and fall, including explicit hand/finger and cape-chain motion. The existing
-0.03m floor tolerance, 0.055m grounded foot-contact maximum and 2.0m crouch
lintel are unchanged and are not widened for the new anatomy. Root, scale,
driver, imported-root and bind recovery are also checked.

The stance review repeats the accepted 30/60Hz held-4.8m/s ankle-lock and
turn/teleport/action-release tests using the retargeted rest anchors. It
measures ankle-origin drift, not whole-sole area, traction, or visible quality.
The mechanics wrapper runs the current durable 200-check courtyard behavior
with the explicit candidate attached to the real player root; it does not
reuse obsolete immediate-hit or remembered-evade assumptions.

Before accepting a result, require the printed explicit asset path and SHA-256,
the expected `GLOAM_CHARACTER_ART_*_OK` footer, exit code 0, and no
`SCRIPT ERROR`. Report macOS sandbox log/certificate warnings separately. Do
not run candidate-heavy or performance checks until the asset owner announces
a stable SHA and import; run final paired normal-renderer performance only in a
quiet window coordinated by the root task.

## Finish the live release gate

The Mac is now unlocked; the separate browser local-board URL-policy gate is
still independent. Refresh `cua.getState()` and verify the exact DEBUG title
before any game input.
Keep only one owned visible game; do not close unknown or unsaved user work.

1. Confirm exact R14 SHA
   `30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`
   against `revisions/r14` and the latest report. Rejected revisions stay off.
2. Review `renders/r14`, `captures/r14-import-*` and the corrected 277-frame
   `captures/r14-action-motion-fist-final*`,
   `captures/r14-target-independent-strike*`, and matched front
   `captures/r14-gait-alignment-final*` reels. These are helper-driven evidence;
   they do not establish ordinary-input reachability or user art acceptance.
3. Run `live_review.gd` for actual controls with only the candidate visuals
   replaced. Smoke idle/walk/start/stop/turn, all body/accent presets,
   crouch/clearance, jump/vault, grapple/perch/fall, facing-locked forward evade,
   strike/whiff/counter/hurt/downed, paired takedown/fade, exit, camera/reset and
   F12. Record health/Momentum/objective and real screenshots; report quirks.
4. Review `reports/2026-09-08-r14-appearance-action-performance.md`. The exact
   V1/R14 pair passes its quiet 1920x1080 configuration/sample gates. Never infer
   a guaranteed FPS, supported enemy count or GPU ceiling from reciprocal wall
   cadence; the nine-rig fixture contains visual-only copies and GPU timing is
   unavailable.
5. Only after visual, input and performance acceptance, switch the main scene
   through a narrow default-player wrapper. Preserve explicit
   `build_player(..., false)` V1 and `build_player(..., true)` frozen V2 semantics
   so historical tests/benchmarks remain reproducible. Do not overwrite either
   asset or repurpose `DEFAULT_PLAYER_V2` into an unrelated V4 flag.
6. Regress the actual new default, refresh authoritative docs/evidence, then
   derived board/wrapper. Browser interaction/responsive acceptance still
   requires permitted access or manual user verification; static parity is not
   a substitute. Finish with a fresh exact-title DEBUG launch and reset/default
   camera F12 capture, left open. No production changes afterward without a new
   handoff.

The Sep-8 R14 current-code smoke covers native target-free `space`, native
facing-forward `C`, body/accent/crouch input and the exact-title window. It also
caught the stale crouch percentage message, which now reports the protected
1.178 units/s and passes post-fix regressions. CUA latency still exceeds the
sub-second contact/counter windows. Finish the position-dependent native
takedown and user movement/appearance judgement before promotion.

The broader natural-animation implementation now has rendered and technical
evidence, but remains Waiting on this same native input gate. Source-pose and
helper-driven diagnostics are not motion-capture clips, final facial animation,
or live movement-feel approval.
