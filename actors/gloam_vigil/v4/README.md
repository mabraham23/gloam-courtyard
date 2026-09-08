# Gloam Vigil anatomical character candidate

This is an isolated **unaccepted candidate**, not the default player. The
playable v1 and rejected v2/v3 studies remain preserved. Broader animation
quality is a separate task; this pass owns anatomy, original costume, material
treatment, meaningful rig deformation and compatibility with current actions.

## Source and ownership

The realistic anatomical foundation is Dan Ulrich's CC0 `Body Male - Realistic`
from Blender's official Human Base Meshes bundle v1.4.1. See
[PROVENANCE.md](PROVENANCE.md) for exact source URLs, hashes and the distinction
from unrelated assets/licenses in that bundle. It must not be called entirely
authored here. Our derivative uses original fitted clothing, a domino mask,
split cape, utility pouches, proportion changes and a retargeted rig. No
franchise geometry, emblem, cowl or costume is included.

## Reproducible construction

`generate_v4.py` is the single export entry point. `body_from_base.py` appends
only three named source objects with donor scripts disabled; `costume.py`
partitions and dresses the anatomical mesh; `face_finish.py` creates the mask,
eye treatment, vertex-colored short hair and four expressions;
`rig_from_base.py` derives the 74 semantic joints and normalized weights.
Gameplay state and timing remain in the established controller.

```sh
blender --background --disable-autoexec --python actors/gloam_vigil/v4/generate_v4.py
blender --background --disable-autoexec --python actors/gloam_vigil/v4/render_review.py -- --asset=v4 --revision=NEW_REVISION --view=all
```

Choose a new render revision; the renderer refuses to overwrite an existing
capture. Preserve the old GLB, source and manifest under `revisions/` before a
new export. Native Blender rendering on this Mac needs normal app permissions;
the pre-Python sandbox Metal failure is not an asset failure.

## Evidence and current limits

Current frozen candidate is R14, SHA
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`;
source SHA `14e162eb70b59b83bfdcb1cccf2934fd9f0c6bf6fbc90ee6ace108460ed50c29`.
It is archived in `revisions/r14` with source, manifest and five renders. Actual
metrics are 86,452 triangles (34,998 face), 43,757 source vertices, 49,315
exported GLB references, 51,170 Godot-imported skinned references, 74 joints
(73 meaningfully weighted plus structural root), seven surfaces, five
materials, four facial morphs and no more than four influences per vertex.

Matched final neutral views are in `renders/r14`; the same five files accompany
the immutable archive in `revisions/r14/renders`. They are native Blender review
renders, not Godot captures. R14 retains the accepted R7 anatomy/weight/collar
foundation while adding warmer light skin, a readable mouth, connected dark
beard/mustache treatment and a single fitted swept hair shell with bounded nape
tips. R12's forehead underfill and later detached chip/bar experiments remain
preserved rejected evidence. The final result is deliberately described as a
stylized real-time candidate: its hair/beard are surface treatment, not strand
grooming, and still require gameplay-scale user judgement.

Final R14 GLB/import, 37 actual LOD buffers, 451 rig, runtime recovery,
200/202 default/candidate mechanics, both-rate planting, target-free strike
254, four-attack 316, action motion 198, transitions 67 and 21,642 strict
full-deformation checks pass. The paired quiet 1080p V1/R14 benchmark also
passes; exact results and limitations are in
`work/character-art-review/reports/2026-09-08-r14-appearance-action-performance.md`.
Native current-code smoke confirms a target-free SPACE whiff and forward C
evade. User visual judgement, a native position-dependent takedown and the
default switch/regression remain open. Do not treat source or technical evidence
as live release acceptance. See the exact resume checklist in
`work/character-art-review/README.md`.

R1 is archived at `revisions/r1`, SHA `8d46f24c5eccb72964e71c602ac7d0d620e31f0eed15e1c492a581f4c976bcc1`.
Matched full/head/profile images are in `renders/r1`. It was rejected for
visible hand streaking and costume/face fit defects, plus the unchanged
foot-plant/final-jump clearance gates. See `docs/CHECKPOINTS.md` and
`work/character-art-review/reports/2026-09-05-v4-r1-8d46f24c.md`.

The material maps are restrained procedural signals, **not** a sculpt bake or
painted production character texture set. A genuine level1/level3 source-detail
comparison found no meaningful extra relief worth baking; preserved images and
the source's six-tile head UV limitation are in
`renders/multires-detail-study/REPORT.md`. R14 hair is a fitted, swept-ridged
shell and facial hair is a feathered source-surface color field; neither is
strand grooming. Blink has a tiny residual iris sliver at full closure; facial
animation and cape motion remain limited. Technical bone/mesh counts do not
establish semi-professional art quality.

## Acceptance

Use the explicit scripts documented in `work/character-art-review/README.md`.
Require actual matched source/imported/gameplay visual improvement, strict
30/60Hz all-preset skin/morph clearance and recovery, meaningful hand ownership,
foot planting, gameplay regression, paired 1080p normal-renderer performance,
ordinary-input playthrough and a fresh exact-title DEBUG handoff. Imported
triangle-index LODs do not reduce full skinned vertex/morph memory. No current
v4 FPS result or supported enemy-count claim exists yet.
