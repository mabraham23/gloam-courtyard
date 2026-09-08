# R7 contact-hand variant review

Status: bounded read-only follow-up to the hand-axis study. Five profiles were
rendered from the exact frozen R7 Blender source, from both the curl plane and
the palmar-normal view. No source, GLB, production adapter, rig, or controller
file was saved or changed.

## Frozen inputs

- Source SHA-256:
  `40b4fca657e3ab91783ddeca2e2f02c87619f1daf89d245921397fc6f0669fdc`
- GLB SHA-256:
  `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`
- Render result: `CONTACT_VARIANT_RENDERS PASS profiles=5 images=10`

## Visual result

All five variants remove the long U/loop silhouette seen in the earlier
`tuned-v3` fist and grip. Each keeps `.03` flex at or below 11 degrees and
puts most closure at the MCP/proximal joint.

- `strike-a-soft` is loop-free but remains too open and reads more like a
  reaching hand than a compact impact hand.
- `strike-b-compact` gives the clearest compact silhouette without distal
  looping. The four fingertips remain separated and the thumb stays outside
  the finger arc.
- `strike-c-thumb-wrap` moves the thumb tip closer to the palm target
  (69.08 mm versus 74.93 mm on the right hand) but gives little silhouette
  improvement and reduces clearance. It is not the safer default.
- `takedown-a-reach` is a useful early reach phase but too open for the hold.
- `takedown-b-secure` gives a readable controlled grip without turning the
  fingers into a fist or U-loop. Its right thumb tip is 78.93 mm from the
  measured palm target versus 85.97 mm for `takedown-a-reach`.

The curl-plane renders are the decisive silhouette evidence. Palmar renders
also include the opposite hand/body in the background because the licensed
body is a single connected mesh; they remain useful for thumb clearance but
are not isolated beauty shots.

## Recommended exact profiles

Angles are positive degrees about the measured palm-closing body axes from
`REPORT.md`, listed as `.01 / .02 / .03`.

### Strike: `strike-b-compact`

| Digit | Flex | Opposition |
| --- | --- | --- |
| index | `52 / 28 / 6` | - |
| middle | `54 / 30 / 7` | - |
| ring | `56 / 32 / 8` | - |
| pinky | `58 / 34 / 10` | - |
| thumb | `9 / 9 / 3` | `24 / 10 / 2` |

This limits total flex to 86/91/96/102 degrees from index through pinky while
keeping the distal joint nearly straight. Close it with eased action amount,
reaching full value at strike contact, then return toward `relaxed` during
recovery.

### Takedown hold: `takedown-b-secure`

| Digit | Flex | Opposition |
| --- | --- | --- |
| index | `32 / 22 / 5` | - |
| middle | `36 / 24 / 6` | - |
| ring | `40 / 26 / 7` | - |
| pinky | `44 / 28 / 8` | - |
| thumb | `7 / 7 / 2` | `20 / 8 / 2` |

This limits total flex to 59/66/73/80 degrees from index through pinky. Blend
from the more open `takedown-a-reach` values during approach if desired, then
hold this profile through contact/pull and release it during recovery:

- reach: index `24/16/4`, middle `28/18/4`, ring `32/20/5`, pinky
  `36/22/6`, thumb flex `5/5/2`, opposition `14/6/1`
- hold: the `takedown-b-secure` table above

## Limits and acceptance boundary

These are safer source-tested starting values, not a closed-fist or object
contact solve. There is no self-contact, target surface, or action wrist pose
in this source-only test. The current straight phalanx topology still leaves a
stylized separated-finger silhouette. Normal-render action frames must confirm
that the strike reads compact at contact and the takedown fingers visibly wrap
the guard rather than intersecting or hovering.

## Evidence and command

The ten images are in `contact-v1/`, including:

- `strike-b-compact-curl-plane.png`
- `strike-b-compact-palm.png`
- `takedown-b-secure-curl-plane.png`
- `takedown-b-secure-palm.png`

Reproduction:

```text
/Applications/Blender.app/Contents/MacOS/Blender --background --disable-autoexec \
  --python /Users/markabraham/dev/batman/work/action-quality/hand-study/render_contact_variants.py
```

The renderer refuses to overwrite existing evidence. Use a new diagnostic
output directory for any later profile comparison.
