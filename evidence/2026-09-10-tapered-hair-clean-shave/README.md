# Tapered haircut and clean-shaven face — 2026-09-10

The user rejected the first short-hair side profile as bowl-like, then asked to
remove the beard and mustache. The previous fringe and low crown remain. A new
scalp follows the anatomical head more closely, rises around the ears and fades
into the nape; the old shell and long nape strips are removed from a private
runtime face mesh. The frozen R14 GLB remains unchanged (`30a2c06be423…`).

The finish removes 1,001 old hair vertices / 1,412 triangles, adds 1,561 replacement
hair vertices / 2,932 triangles, and restores 2,328 facial-hair color samples to
skin. Warm lips remain. Current totals are 49,875 evaluated vertices and 87,972
triangles before LOD. New hair uses the existing head skin bind.

## Visual diagnosis

`index.html` reuses the earlier tracked review as the before view and pairs it
with the final 270-frame review. Engine, seed, renderer, fixture, fixed 30 Hz and
cameras match. Front, quarter, side, rear and running/jumping/crouching frames were
inspected. The contour is closer around ears/nape and the lower face reads as
clean-shaven. User taste remains pending.

The first cap needed clockwise winding and regenerated surface normals. Removing
beard color also exposed a harsh diffuse cutoff on the jaw. Disabling hair shadow
casting, skin shadow reception or skin normal mapping did not resolve that cutoff.
An unlit diagnostic showed the facial-hair color was gone. Final skin uses
Lambert-wrap diffuse lighting to soften grazing light; normal maps and shadows
remain enabled. The hair retains Burley lighting. These temporary diagnostic
variants are identified by immutable local snapshot/source hashes in
`iterations.json`; none is mistaken for the final implementation.

## Verification

Rig/material/clean-shave/head binding checks pass 456/456. The independent
`checks/head-integrity.gd` comparator verifies all 17,767 surviving face/gear
vertices, their vertex attributes, all four expression targets and eleven face
LOD levels against the original asset (tolerance 0.0002 for attribute encoding).
Full deformation passes 22,164/22,164 at three body sizes and both 30/60 Hz,
including the replacement hair. Medium crouch reaches 1.991893 beneath the
2.0-unit lintel. Default startup and editor import pass. The familiar sandbox
macOS system-CA warning is recorded separately from game results.

The integrity comparator first had a reserved-word parse error; after renaming
the local variable it ran successfully. The passing footer, not that first exit
code, is the evidence. Reproduce from the repo with
`godot --headless --path . --script evidence/2026-09-10-tapered-hair-clean-shave/checks/head-integrity.gd`.

## Native handoff and remaining gates

Fresh exact-title `Gloam Courtyard Spike (DEBUG)`, PID 50365, source
`0f0db98db221460d84741e8b5cb848abcda065bf3cb0279c618227bd93a35d06`,
matching the final rendered source. A premature app acquisition opened Project
Manager during the first launch; only its identified PID 50250 was stopped,
shutdown was confirmed by state refresh, and the managed game was relaunched.

The enlarged game and native Q crouch were inspected and F12 saved a matching
PNG/state pair with zero source drift. The run already had user play activity
(64 health, 62 Momentum); that combat progress is not attributed to this agent.
A reset attempt was blocked by the computer-control user-interaction notice.
After refreshing the state, the current user run was left open without forcing
a reset or further input. Thus this is a fresh verified live appearance handoff,
with an active-play capture, not a final reset capture.

Hair/face preference, earlier jump/crouch preference, native held movement and
paired takedown remain separate user gates. V1 stays default and R14 remains a
candidate. No new performance certificate is claimed. Board schema/parity checks
are separate from the existing rendered board URL-policy gate.

This review reuses prior before images instead of duplicating them. Its selected
files add about 3.4 MB and bring curated evidence to roughly 50 MB; this growth was
reviewed and no unique historical evidence was deleted.
