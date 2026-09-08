# Character quality v2 review

In progress, 2026-09-04. This is an acceptance checklist, not completed evidence.

## Comparison conditions

Keep v1 source/export and diagnostic history. Compare v1 and v2 at equal scale,
light and camera, first in neutral front/profile/three-quarter views, then in
close face/hand views, then through all accepted action states and recovery.
Use the actual courtyard camera and ordinary visible input as a separate gate.
Studio/movie sequences are not FPS benchmarks or ordinary-input playtests.

## Visible bar

- Face: shaped eyelids and sockets, nasal bridge/tip/nostrils, lip volume, cheek
  and jaw structure; no horizontal faceted bands or featureless mannequin head.
- Neck/body: neck blends into trapezius/collar, shoulders connect naturally to
  chest/arms, anatomical torso taper and suit tension replace tubes/spheres.
- Hands/feet: separate fingers flex at useful joints; thumb opposition, fist
  and reaching do not fold into the palm; toe roll supports ground contact.
- Materials: coherent fitted cloth/leather/skin and controlled roughness, with
  useful surface detail rather than decorative high-frequency noise. Report
  procedural textures separately from any actual high/low sculpt bake.
- Motion: readable stance/swing phases, weight transfer, believable upper-body
  counter-motion, useful clavicle/twist/facial/cape articulation, stable starts,
  stops and action recovery; no added bones that never deform anything.
- Mechanics: unchanged combat/traversal/crouch/timing/collider/camera contracts,
  all presets/accent variants, and measured full-mesh floor/lintel clearance.
- Performance: matched uncapped 1080p normal-renderer baseline/candidate tests,
  warmup, frame-time distributions and honest stress-fixture scope; target 60
  FPS with headroom, not an unmeasured guarantee on all desktop hardware.

## Initial observations

V1 neutral `captures/gloam-vigil-semantic-components-neutral.png` visibly has a
long column-like neck, horizontal face/chest faceting, simple nasal/lip forms,
tubular torso and disconnected shoulder caps. Fresh in-game reset baseline is
`captures/courtyard_3d_2026-09-04_17-04-13_895408.png`. Current inventory:
172,620 triangles / 97,061 vertices / 20 bones / 12 materials / 128px albedo-only
textures; no authored animation clips or morphs. These explain a quality gap,
not a measured runtime bottleneck. Candidate review/evidence will be appended.

Initial measured v1 baseline is now recorded separately in
`work/character-quality-benchmark/README.md`: actual 1080p courtyard p95 5.340 ms,
plus eight animated visual copies p95 17.036 ms. This is a normal-renderer
comparison, not a GPU timer or enemy-AI capacity claim. Final acceptance needs
the matched candidate measurement and longer paired sampling.

## Rejected model reviews (not completion evidence)

### Revision 1 — 2026-09-04

Preserved source/export and studio captures are under the v2 source directory
and `actors/gloam_vigil/v2/renders/r1/`. The first candidate export SHA-256 was
`3c15037c2b6a51fabfe71627cfb3eda64de24d2ad160f6be37c3681b73eefd17`.
It had 87,684 triangles, 51,571 exported/runtime vertices, 74 weighted bones,
five unique materials and eight draw surfaces. The binary GLB audit passed,
but that does not establish appearance quality.

Independent front and close three-quarter review rejected the egg-shaped
head, protruding oversized eyes, separate tube-like lips, neck column, raised
shoulder caps, coarse cloth pattern, ball-like pouches and open boot ends.
These are anatomy/material construction defects, not a triangle-budget issue.

The first all-mesh deformation probe evaluated all three skinned meshes and
their active morph deltas: 2,766 checks, 13 failures. Three were a diagnosed
float32 `Quaternion.angle_to` cancellation artifact at identical imported
rest rotations; the probe now uses a relative quaternion and `atan2` with the
same angular tolerance. Ten were real crouch clearance misses of roughly
2–28 mm against the 2 m lintel across medium/large presets. They remain open
until the revised anatomy is measured. Other sampled walk/evade floor,
finite-action and grounded-recovery assertions passed for that snapshot.

### Revision 2 — 2026-09-04

Preserved studio evidence is in `actors/gloam_vigil/v2/renders/r2/` and source
in `source/gloam_vigil_player_v2_r2.blend`. Root independently viewed the
neutral front and close three-quarter face renders. Smaller eyes, closed
boots and restrained cloth detail improved parts of the image, but this
revision was also rejected: weak jaw/nose/lip planes, an exposed conical neck
with a flat rim, proud eyes, detached brow strips and raised sleeve crowns
still produce a mannequin appearance. No r2 gameplay or performance acceptance
is claimed. The next revision changes the underlying head profile and
neck/shoulder construction instead of only increasing density or texture size.

V1 remains the default playable asset during these reviews. The candidate
selector, richer rig and new motion paths are not acceptance by themselves.

### Frozen revision 4 — technical prototype only, 2026-09-04

Exact exported SHA-256:
`a786d082fb1b9aea0d383dd0a06e0c43826b20bf35b4edb4b60ea50b2882ee3b`.
This is authoring revision 4. The root's first Godot face capture filenames
mistakenly say `r3`; they render this exact r4 asset, not the earlier r3 model.
See the asset owner's preservation manifest for the earlier source history.

Independent normal-GL face evidence:
`captures/gloam-v2-r3-face-front-reviewed00000004.png` (v1 left, r4 right).
The candidate is rejected: visible tearing at the nose/mouth, shallow sockets,
abrupt jaw-to-neck attachment, long column-like neck, disconnected shoulder
crowns and primitive chest/suit forms. The close comparison does not meet the
user's requested improvement. No default-asset switch is justified.

The retained technical scaffold has 83,632 triangles, 50,940 exported/runtime
vertices (42,024 authored vertices), 74 actually weighted joints, five unique
PBR materials across seven draw surfaces, four facial morphs and five explicit
Godot Animation resources. Normal maps are 2K for skin/suit and 1K for the other
materials. These are procedural textures, not a successful sculpt-detail bake.
Actual imported-mesh inspection found 35 valid LOD index buffers; those reduce
triangle indices, not the full skinned vertex or facial morph storage. Full
counts, raw thresholds, limitations and reproduction commands are in the
benchmark README. Neither density nor LOD proves a convincing face.

Technical checks on this frozen snapshot:

- Full-mesh/active-morph deformation: 2,763/2,763 after an additional 0.035 rad
  visual-only torso fold at the large preset. The first r4 run had five genuine
  large-preset crouch misses, maximum 10.35 mm; those are fixed. V1's fold and
  all gameplay transforms/timing/collision rules are unchanged.
- World-space ankle lock at gameplay speed: at 60 Hz, maximum full-lock drift
  0.02408 m versus 0.59842 m without the lock; at 30 Hz, 0.02129 versus 0.59836 m.
  Reach limits safely rejected 10/73 and 3/38 stance frames respectively.
  Turn, teleport and action release plus exact actor-root preservation passed.
  This measures the ankle constraint, not a production foot-contact solution
  on slopes or stairs. Toe-off and swing intentionally release it.
- Required bone categories and all four morphs animate, bind recovery passes,
  and all five authored clip resources pass the runtime contract. Legacy v1
  deformation remains 511/511 and courtyard mechanics remain 107/107.

Normal-renderer technical evidence, not appearance acceptance or FPS evidence:

- `captures/gloam-v2-r4-technical-actions00000000.png` through `...00000359.png`:
  360 frames at 960×600/30 FPS. Reviewed walking43, crouch78, roll223 and strike253.
  Same scale/light, deliberately stretched action phases; first/last SHA
  prefixes `db5b4a13` / `4e1ce50a`. Motion and recovery run, but the model still
  looks primitive and its face/neck remain visibly wrong.
- `captures/gloam-v2-r4-technical-gameplay-clean00000000.png` through
  `...00000329.png`: 330 frames using the actual courtyard with diagnostic
  helper positions and prepared counter timing. Reviewed movement25,
  grapple156 and counter243; recorded evade Momentum4, strike13, counter41,
  takedown35 and reset0. First/last SHA prefixes `72dbd098` / `e0358e1a`.
  This is not ordinary-input evidence. The known guard health-label lag
  remains visible during counter stun and is still a separate Later task.

The initial face-stage attempt constructed actors before tree entry; it is not
accepted. Deferring stage construction fixed its transform errors. The first
actual-game diagnostic directly freed material overrides during replacement,
causing GL material dependency errors; clearing overrides before freeing the
old visual fixed the replacement capture. These were real diagnostic defects,
not benign macOS log/CA warnings, and the earlier captures remain preserved.

Next art direction needs an explicit choice: continue fully original local
anatomical modeling/retopology, or approve research into a vetted commercially
usable realistic human base mesh and customize it into original IP. No external
geometry has been downloaded or purchased. Keep the useful rig/clip/test work;
do not relabel the rejected procedural art as a completed realism milestone.
