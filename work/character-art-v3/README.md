# Gloam Vigil v3 candidate verification

These checks select only
`res://actors/gloam_vigil/v3/gloam_vigil_player_v3.glb` through the builder's
explicit candidate-path argument. The default game remains playable v1, and
the frozen rejected v2 file is never overwritten or relabelled.

No visual, gameplay, or performance acceptance is implied by these probes.
They should run only after the exact candidate has finished export and Godot
import. Normal-renderer review and live input remain owned by the root task.

## Static/import gates

```sh
python3 work/character-art-v3/glb_contract.py

godot --headless --path /Users/markabraham/dev/batman --editor --quit

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-quality-benchmark/inspect_imported_lods.gd \
  -- --label=v3-candidate --asset=res://actors/gloam_vigil/v3/gloam_vigil_player_v3.glb
```

`glb_contract.py` reuses the established standard-library GLB parser. It
requires 74 joints, no more than four nonzero influences, normalized nonempty
weights, all deform bones used except the structural root, seven surfaces,
five used materials, five normal maps of at least 1024px, and the four named
finite/nonzero sparse morphs. It rejects more than 90,000 triangles but has no
minimum triangle count. The LOD command inspects actual imported index buffers
through `RenderingServer`, not only the import checkbox.

## Runtime gates

```sh
godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-v3/runtime_contract.gd

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-v3/deformation.gd

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-v3/foot_plant_review.gd

godot --headless --path /Users/markabraham/dev/batman \
  --script /Users/markabraham/dev/batman/work/character-art-v3/mechanics.gd
```

The runtime contract proves nonzero motion in added spine/twist/clavicle,
hand/finger/toe, eye/jaw, cape-chain and facial-morph channels, then exact bind
recovery. The deformation gate evaluates every imported skinned vertex plus
active morph deltas on every real 30/60Hz action frame at small, medium and
large body presets. It covers crouch, strike, forward roll, takedown, grapple,
grapple recovery, jump, vault, counter and fall, with explicit hand/finger and
cape-chain movement evidence. Runtime bars are the existing -0.03m floor
tolerance, 0.055m grounded foot-contact maximum and 2.0m crouch lintel; these
are not widened for v3. It also checks action contact silhouettes and full
root/scale/driver recovery.

The stance check repeats the accepted 30/60Hz held-4.8m/s comparison and
turn/teleport/action release conditions. It measures ankle-origin drift, not
whole-sole contact, traction physics, or visible animation quality. The
mechanics wrapper runs the current durable 196-check courtyard contract with
v3 attached to the real player root; it includes delayed single contacts,
visible-facing roll/travel/collision, takedown reservation and approach,
traversal, crouch/lintel, stealth, success and restart. It does not reuse the
obsolete immediate-hit or remembered-travel assumptions.

Before accepting any result, require the printed candidate path and SHA-256,
the expected `GLOAM_V3_*_OK` footer, exit code 0, and no `SCRIPT ERROR`. Report
macOS sandbox log/certificate warnings separately. Performance is deliberately
absent here and must wait for a quiet, paired normal-renderer window.

