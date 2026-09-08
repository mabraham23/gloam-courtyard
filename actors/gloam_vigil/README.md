# Gloam Vigil player

An original, script-authored Blender character for the local courtyard. This is
a bounded player-model experiment; acceptance and current limitations live in
`docs/PROJECT_STATE.md` and `docs/CHECKPOINTS.md`.

## Active quality candidate

The accepted v1 remains the default while a separate `v2/` candidate is under
review. The user-approved v2 milestone supersedes the historical 20-bone freeze
below: 74 meaningful joints, articulated hands/feet/cape, four facial morphs,
normal/roughness textures and a small authored Godot animation library are now
in scope. `character_visual_builder.gd` selects it only when `use_v2` is true;
the default switch must not change until the quality/runtime gates pass.

V2 is a code-authored anatomical surface study with deterministic PBR textures,
not a hand-sculpted/photogrammetric asset or a completed high-to-low detail bake.
Two model revisions have already been rejected on visible anatomy despite
valid export structure. Acceptance observations and preserved captures live in
`work/character-quality-review.md`; repeatable full-mesh, studio and performance
diagnostics live in `work/character-quality-benchmark/`. These diagnostic scripts
are not included in the default scene and do not change normal launch behavior.

The narrow adapter still owns imported rest-axis conversion and visual-only
contact. V2's semantic animation tracks are explicit Godot `Animation`
resources sampled by that adapter; they are not motion capture or embedded GLB
clips. Gameplay action timing and root movement remain owned by `main_3d.gd`.

## Ownership

- `generate_gloam_vigil.py`: reproducible original geometry, skin weights,
  materials, texture generation, Blender save, and GLB export.
- `source/gloam_vigil_player.blend`: editable authoring source. The source folder
  is ignored by Godot so its Blender-file importer does not duplicate the GLB.
- `gloam_vigil_player.glb`: runtime mesh, skeleton, and material data.
- `gloam_vigil_rig_adapter.gd`: the narrow bridge from the existing actor pose
  curves to imported bone rest axes, instance accent materials, and sole contact.
- `textures/`: original deterministic albedo textures emitted by the generator.

The preserved procedural player remains in `character_visual_builder.gd`.
Earlier traveler and toy-like Vigil source drafts remain under `source/`.
The guard retains its accepted procedural model. Gameplay state, timing,
movement, collision, and camera ownership remain in `main_3d.gd`.

## Rebuild

Run from the project root with Blender 5.2.1:

```sh
blender --background --python actors/gloam_vigil/generate_gloam_vigil.py
godot --headless --path . --editor --quit
```

Blender background execution requires normal local desktop permissions on this
Mac. Godot imports the GLB through its supported glTF pipeline. The exporter
includes UVs, normals, tangents, standard PBR materials, and up to four skin
influences per vertex. It exports no autonomous animation, camera, lights,
root-motion tracks, or gameplay colliders.

Bone pose rotations in Godot are absolute parent-local rotations. The adapter
converts each body-axis pose delta into the bone's rest axes, then composes the
result with its imported local rest rotation. Identity driver deltas must
reproduce the bind pose. Passing a driver quaternion directly to the skeleton
will fold downward limbs upward and is incorrect.

## Evidence and quality bar

Inspect the full source silhouette with neutral lighting, then the imported
model beside the preserved player at equal scale, then actual action sequences
and live gameplay. Finite transforms alone do not prove correct skinning:
verification also CPU-skins vertices, checks rest preservation, joint direction,
ground contact, low-passage clearance, stable recovery, and gameplay regression.
Historical temporary harnesses stay outside the project. V2 diagnostics have a
stable work-directory home and are never loaded by the default scene.

The final integration repairs retain separate semantic leg meshes beneath the
same exported mesh object. Torso/arms have continuous shoulder weighting; the
legs are not voxel-welded together or to the forearms. Export asserts prohibit
arm-leg edges, cross-leg edges below the pelvis and hard shoulder transitions.
This avoids the valid-but-wrong normalized weights that earlier drafts passed.

The adapter adds visual-only sole contact and a slightly higher roll pivot.
Inside the existing low passage, the controller requests the measured crouch
pose immediately so visual easing cannot overlap the lintel after collision has
already granted entry. Open-space crouch easing and every gameplay timer,
displacement, collision rule and customization control remain unchanged.

No downloaded geometry, texture, rig, motion clip, paid asset, or franchise
reference is used. The design brief is broad muscular anatomy, fitted dark
clothing, an original fitted mask, utility pouches, and a draped cape. This does
not claim motion capture, production facial animation, physical cloth, or final
commercial character art.

## Primary pipeline references

- [Godot 3D import formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- [Godot Skeleton3D pose/rest API](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html)
- [Godot StandardMaterial3D](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)
- [Blender 5.2 glTF exporter](https://docs.blender.org/manual/nl/5.2/addons/scene_gltf2.html)

## Historical v1 next-step brief (scope expanded by approved v2 milestone)

The current voxel-unioned parametric body proves the import/pose connection,
not finished character art. The next appearance task should replace the simple
head/neck and broad fitted-suit surface with an original sculpt study: eyelids,
cheek planes, jaw/neck transitions, anatomical muscle insertions, and cloth
tension/compression around shoulders, elbows, waist, and knees. First compare
the sculpt in neutral front, profile, and three-quarter lighting; do not export
another parameter-only iteration as a completed realism milestone.

Then build an animation-ready lower-resolution mesh with deliberate face and
joint loops over that sculpt, unwrap it, and bake tangent-space normal and
roughness detail into Godot-compatible textures. Blender's automatic remesh
does not itself supply deformation-ready topology; its Poly Build/snapping
tools support the manual retopology stage. Cycles can bake high/low-resolution
surface differences for animated game meshes. These are supported local tools,
but quality still requires anatomical modeling and weight-paint review, not a
claim that subdivision or a larger texture alone solves realism.

The initial brief kept the proven 20-bone adapter for the first comparison.
The subsequent user approval explicitly adds meaningful joints, facial
articulation and authored motion to this one-player milestone. The original
quality bar still applies: accept the model only if it improves close-up anatomy
and the actual courtyard camera, and test every existing action. No external
asset purchase is necessary to start.

- [Blender retopology guidance](https://docs.blender.org/manual/id/5.2/modeling/meshes/retopology.html)
- [Blender Poly Build](https://docs.blender.org/manual/en/5.2/modeling/meshes/tools/poly_build.html)
- [Blender Cycles baking](https://docs.blender.org/manual/sl/5.2/render/cycles/baking.html)
