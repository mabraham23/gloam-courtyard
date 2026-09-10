# Tapered black hair and clean-shaven runtime finish

The September 10 side-profile correction replaces the old round R14 shell and
its long nape strips with a close-fitting scalp that rises around the ears and
feathers into the neck. The earlier four fringe locks and low crown lock remain.
The user's later clean-shaven instruction supersedes the earlier beard/mustache
preference. The supplied reference is hairstyle direction, not a texture asset.

`generate_short_hair.py` reads the licensed R14 head for surface fitting and writes
`short_black_hair.json`: 280 lock vertices plus 1,281 scalp vertices, 2,932 total
hair triangles. Run `python3 actors/gloam_vigil/v4/hair/generate_short_hair.py`.
Coordinates are imported +Y up / +Z forward. Scalp rays exclude the old shell;
UVs come from the hit anatomical triangle to match the skin at the faded edge.

`head_finish.gd` builds a private face mesh, removing the 1,001 tagged hair
vertices / 1,412 triangles and whitening 2,328 facial-hair color samples. Warm lip
colors remain. All surviving attributes, expression targets and LOD triangles
are remapped together. The frozen GLB is untouched. The new cap/fringe shares the
existing named head skin bind and participates in full-mesh checks.

The clean face uses Lambert-wrap diffuse lighting to soften grazing light on the
jaw. Skin normals and shadow reception remain enabled; the hair keeps Burley
lighting. The unlit, no-shadow and no-normal-map diagnostics were not retained
as runtime behavior. Geometry is stylized mesh hair, without a strand groom.

Current runtime totals: 87,972 triangles before LOD and 49,875 evaluated vertices.
Matched evidence is in `evidence/2026-09-10-tapered-hair-clean-shave/`. Appearance
acceptance and the V1-to-R14 default switch remain separate user gates.
