# Short black hair companion

The September 10 runtime hairstyle uses four fitted fringe locks and one low
crown lock over the preserved R14 scalp. The generic short, angular silhouette
follows the user's hairstyle reference. The existing character design remains
original. The source image is not embedded or used as a texture.

`generate_short_hair.py` reads the existing licensed R14 head only for surface
fitting and writes `short_black_hair.json` (280 vertices, 436 triangles).
Run `python3 actors/gloam_vigil/v4/hair/generate_short_hair.py` to regenerate it.
Coordinates are the imported model's +Y up / +Z forward space. The lightweight
runtime mesh shares the face's named head skin bind and is included in the
same full-mesh deformation audits. No Blender export is required.

The adapter also enables the existing vertex colors on its private R14 skin
material copy. Those colors already contain the black scalp, beard and mustache;
Godot had imported the textured material with vertex color albedo disabled.

The frozen R14 GLB remains byte-identical. Its 86,452 triangles plus this layer
give 86,888 runtime triangles before LOD selection. Appearance acceptance and
the V1-to-R14 default switch remain separate user gates.
