# Gloam Vigil v2 authored-character candidate

## Status

This folder contains a code-authored Blender/GLB **technical character candidate**, not accepted final character art.  It establishes a higher-detail mesh, articulated hands and feet, a 74-bone deformation contract, facial morph targets, shared PBR materials, and reproducible validation.  The current `r4` appearance still falls short of the requested semi-professional anatomical bar: the procedural face has visible nose/mouth reduction artifacts, shallow eye sockets, an abrupt jaw/neck transition, and the torso/shoulder silhouette remains too primitive.

Do not replace the accepted v1 asset based on triangle or bone counts alone.  Use this candidate for runtime import, motion, deformation, and foot-contact evaluation while the visible head/neck/torso receives an artist-guided sculpt and manual retopology pass.

No downloaded, paid, or franchise-derived assets are used.  The identity, costume, geometry, textures, rig, and cape are original to this project.

## Stable paths

- Runtime candidate: `res://actors/gloam_vigil/v2/gloam_vigil_player_v2.glb`
- Blender source: `actors/gloam_vigil/v2/source/gloam_vigil_player_v2.blend`
- Reproducible generator: `actors/gloam_vigil/v2/generate_gloam_vigil_v2.py`
- Render driver: `actors/gloam_vigil/v2/render_v2.py`
- Rig contract: `actors/gloam_vigil/v2/rig_contract.py`
- Machine-readable metrics: `actors/gloam_vigil/v2/gloam_vigil_player_v2_manifest.json`

The current stable export is also frozen as `gloam_vigil_player_v2_r4.glb`, `source/gloam_vigil_player_v2_r4.blend`, `gloam_vigil_player_v2_manifest_r4.json`, and `renders/r4/`.  Earlier rejected visual studies remain under the `r1`, `r2`, and `r3` names.  All revision-suffixed GLBs in the v2 root are historical evidence only and must never be selected as runtime defaults; the sole candidate runtime path remains the unsuffixed GLB listed above.  `revision_manifest.json` is the authoritative byte-hash map.

The original r3 GLB hash was observed as `ec086c7870be1c93a2c830b144a7fa541ab23dae8b90c5e3448ad0c14e9b37f2`, but that byte stream was overwritten before archival.  The exact r3 Blender source was recovered from its immediate `.blend1` backup; `source/gloam_vigil_player_v2_r3_recovered.glb` and `renders/r3/` were regenerated from that source and are clearly marked as reconstructions rather than falsely claimed as byte-identical originals.  Some Godot captures initially called a786 `r3`; the authoring revision map calls a786 **r4**.

## Current r4 metrics

- GLB SHA-256: `a786d082fb1b9aea0d383dd0a06e0c43826b20bf35b4edb4b60ea50b2882ee3b`
- 83,632 authored triangles and 42,024 authored vertices
- 3 skinned mesh nodes: `GV2_Body`, `GV2_Face`, `GV2_Cape`
- 74 deform bones, all meaningfully weighted; all 20 v1 legacy names retained
- 2 actual nonzero skin influences per vertex maximum in the audited GLB; 4 is the configured authoring/export limit and available glTF slot count
- 5 unique materials across 7 exported surface slots
- 4 face morphs: `blink.L`, `blink.R`, `brow_inner_raise`, `jaw_clench`
- 472 bottom-contact vertices strongly assigned to foot/ball/toe groups
- Bounds: 0.966 m wide, 0.649 m deep, 2.149 m tall; sole minimum 0.012 m, crown 2.161 m

The generated meshes and GLB can contain additional vertices after glTF splits for UVs, normals, colors, materials, or skin attributes.  The manifest reports Blender authored-scene counts, not an engine draw-call or GPU-memory measurement.

## Rig contract

Coordinates are Blender metres, +Z up, with the bind-pose character facing -Y.  `gloam-vigil-v2-rig-1` contains:

- Core: root, pelvis, spine, spine_upper, chest, neck, head, jaw, and two eyes
- Per side: thigh/shin twist chain, foot/ball/toe, clavicle plus upper-arm/forearm twist chain, hand, five three-segment fingers, and four cape segments
- Stable foot-contact groups: `foot.L`, `ball.L`, `toe.L`, `foot.R`, `ball.R`, `toe.R`

The exact names, parents, bind heads/tails, legacy subset, materials, and morph names are defined in `rig_contract.py`; runtime code should consume that file/manifest contract rather than infer it from geometry proportions.

## Materials and textures

The five shared material semantics are:

1. `MAT_GV2_Suit_Cloth`
2. `MAT_GV2_Skin`
3. `MAT_GV2_Gear`
4. `MAT_GV2_Tactical_Boot`
5. `MAT_GV2_Accent`

Body cloth and face maps are 2048 px; gear, boot, and accent maps are 1024 px.  The maps are procedural authored textures, **not** high-to-low sculpt bakes.  Gear/skin vertex colors carry eye and subtle lip coloration so the eyes are not coupled to the user-selectable accent.  The same materials may be reused by separate meshes with overlapping UV space; do not bake unique per-mesh relief into those shared maps without first creating an atlas or distinct material/texture set.

## Build and render

From the repository root, with Blender 5.2 available at `/opt/homebrew/bin/blender`:

```sh
/opt/homebrew/bin/blender --background --python actors/gloam_vigil/v2/generate_gloam_vigil_v2.py
/opt/homebrew/bin/blender --background actors/gloam_vigil/v2/source/gloam_vigil_player_v2.blend --python actors/gloam_vigil/v2/render_v2.py
```

The generator validates the exact mesh/material/morph contract, triangle budget, normalized four-weight upper limit, every deform bone's vertex participation, semantic limb-weight exclusions, and strong sole-region weights before saving or exporting.  It exports GLB with UVs, normals, tangents, rest-position armature, skinning, morphs and morph normals, materials, custom extras, and four available influence slots; current r4 vertices use no more than two nonzero influences.  It omits clips, cameras, lights, Draco, and meshopt compression.

## Required next art pass

The practical path to the requested visible quality is to keep the current rig/metadata and replace the final visible anatomy through a human-guided Blender workflow:

1. Sculpt an original high-detail head, neck, trapezius, shoulders, chest, and limb anatomy in coherent volumes, checking neutral front/profile/three-quarter silhouettes before surface detail.
2. Manually retopologize deformation loops around eyelids, mouth, jaw, shoulders, elbows, hips, knees, fingers, and toes.
3. UV the new low mesh deliberately, then bake true high-to-low normal/AO/curvature maps and author restrained cloth/skin roughness.
4. Transfer/refine weights on the existing 74-bone contract, rebuild the four facial morph targets, and validate both neutral and action poses in Blender and Godot.
5. Accept only after close face/anatomy review, full-skin deformation probes, foot-lock checks, a normal-renderer performance comparison, and an in-game smoke play-through.

The procedural generator remains useful for rig construction, metadata, hands, cape, weighting tests, PBR templates, and repeatable exports.  Further parameter-only changes or voxel remesh/decimation are unlikely to deliver the required facial quality and should not be presented as a finished sculpt.  The visible source-quality task is intentionally waiting on the next modeling direction; no external human base mesh is authorized or present in this folder.
