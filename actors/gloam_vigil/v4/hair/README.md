# Swept black hair and clean-shaven runtime finish

The second September 10 bowl-cut rejection prompted a silhouette rebuild. The
rounded cap is now only a 0.55 mm close-clipped foundation, with a broad fade
above the ears and at the back. Four overlapping top sections carry the volume;
two broad central sweeps and two lower side sections give unequal lengths
and softly rounded cross-sections. Four angular fringe locks retain the forehead breaks. The back
of the crown stays short so forward head pitch still fits the crouch lintel.

`generate_short_hair.py` fits the locks and foundation to the licensed R14 head,
excluding the original merged hair shell. Run
`python3 actors/gloam_vigil/v4/hair/generate_short_hair.py` to regenerate
`short_black_hair.json`. Coordinates are imported +Y up / +Z forward. Scalp UVs
and smooth normals come from the anatomical head. The clipped foundation uses
the same Lambert-wrap diffuse lighting as the face to hide its faded boundary;
long locks use a subdued sheen to make their shape readable in courtyard light.

The supplied reference is generic hairstyle direction, not a texture or source
asset. The user's clean-shaven request remains active. `head_finish.gd` removes
1,001 original hair vertices / 1,412 triangles and whitens 2,328 facial-hair color
samples on a private mesh. Warm lips, anatomy, surviving vertex channels, four
expressions and eleven face LODs stay intact. The frozen R14 GLB is untouched.
All replacement hair shares the named head skin bind and full-mesh validation.

This remains stylized mesh hair. The earlier rounded-shell and sharp-ridge
iterations are preserved in Git and the evidence history. Matched before/after
front, quarter, profile, rear, running/jumping and closer crouched review lives
in `evidence/2026-09-10-swept-hair-silhouette/`. User appearance acceptance and the
V1-to-R14 default switch remain separate gates.
