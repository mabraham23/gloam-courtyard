# Short black hair — 2026-09-10

The user requested short black hair like the supplied angular, tousled hairstyle.
The R14 review now has an uneven four-lock fringe and a low swept crown lock.
The existing original outfit and face remain in place. The reference image was
used for hairstyle direction only and is not embedded as an asset.

## Cause and change

The R14 scalp and beard already had black vertex colors, but the imported skin
material had vertex-color albedo disabled. The adapter now enables those colors
on its private R14 material copy. The fitted fringe/crown companion shares the
existing named head skin bind, uses a matte black material, and participates in
full-mesh audits. The frozen GLB SHA remains
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`.
The new layer adds 280 vertices / 436 triangles; regeneration is byte-identical.

## Rendered review and checks

`index.html` compares matched 270-frame before/final runs, with the same engine,
seed, fixed 30 Hz, camera fixture and helper inputs. Front, quarter, profile and
rear close-ups are followed by held travel, running jump, landing and crouch at
the default camera. The keyframes and action sequence were inspected: the fringe
clears the eyes, stays attached to the head, and reads black in courtyard light.
These scripted holds and close-up cameras are not native held-input evidence.

Rig/material/head binding: 454/454. Focused crouch: 1083/1083, maximum medium
height 1.995706 under the 2.0-unit lintel. Full action/deformation: 22,164/22,164,
all 49,595 evaluated vertices, three body sizes at both 30/60 Hz. Import and
default startup pass. The macOS sandbox system-CA warning is separate from the
passing game results. Logs are under `checks/`.

Four sparse crown spikes were rejected visually and exceeded crouch clearance.
A second version with two lower locks still exceeded clearance at the rear. The
rear lock was removed; the final version keeps the prior clearance without
changing crouch posture. The earlier surface-fitting failure was a construction
error, not a valid render. `iterations.json` identifies each preserved local
snapshot, source hash and reason; rejected work has not been overwritten.

## Native handoff and remaining judgement

Fresh exact-title `Gloam Courtyard Spike (DEBUG)`, PID 48537, source
`b8b794c3c1c3596eb9bc9f88a3cc1f6adc225984f759e1f72811af4a65aa64bd`.
The normal-renderer final and live build have identical source fingerprints.
Native Q enter/exit, V jump start, window enlargement, R/0 reset and F12 were
observed. The saved jump-start sidecar records grounded preparation; it is not
an airborne timing capture. Three PNG/state pairs match hashes with no changed
source. The final medium/default-camera reset was opened and the game left ready.

This remains stylized mesh hair, with smooth sides/nape and no strand groom.
Appearance preference, native held movement and paired takedown remain user
gates. V1 is still the default and R14 remains a candidate; this adds no new
performance certificate or exhaustive self-collision claim. The generated board
has a separate pre-existing URL-policy blocker for rendered interaction review.
