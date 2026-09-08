# R7 hand-axis and profile study

Status: read-only diagnostic for the frozen V4/R7 source. This study did not
save or export the Blender source, change the GLB, or alter production runtime
code.

## Frozen inputs

- Blender source SHA-256:
  `40b4fca657e3ab91783ddeca2e2f02c87619f1daf89d245921397fc6f0669fdc`
- Godot GLB SHA-256:
  `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`
- Rig: 74 bones; the imported `Skeleton3D` transform is identity.
- Coordinate conversion used by the source diagnostic:
  Blender `(x, y, z)` to Godot `(x, z, -y)`.

The source and GLB hashes matched before and after every diagnostic render.
`imported_hand_axes.gd` independently confirmed the actual imported bone
origins and bases; Blender-to-Godot joint origins agree within approximately
0.2 micrometres.

## Finding

The clawed hands are an axis defect, not insufficient curl. The current
runtime rotates every thumb and phalanx around body-space `+X` on both sides.
The measured long-finger hinge axes are 77-89 degrees away from `+X`, and the
proper axes mirror between the hands.

At the current strike curl of `1.02` radians, the fingertip displacement along
the measured direction into the palm is negative for every long digit:

| Digit | Left | Right |
| --- | ---: | ---: |
| index | -17.33 mm | -17.66 mm |
| middle | -27.93 mm | -27.91 mm |
| ring | -32.33 mm | -32.05 mm |
| pinky | -31.91 mm | -31.17 mm |
| thumb | +5.31 mm | +4.69 mm |

Thus the current strike drives the four long fingers away from the palm while
moving only the thumb weakly inward. The same incorrect channels are authored
in the grounded idle/walk clips, so a V4 correction must be the final override
after grounded clip sampling as well as after action-secondary selection.
`takedown` has no dedicated action-secondary branch and currently inherits the
generic curl `0.28`, which explains the open claw during that hold.

## Measured body-space axes in Godot coordinates

Positive rotation about each flex axis below closes the digit into its palm.
Negative rotation opens it. The axis is constructed from actual R7 rest
geometry as `digit_direction.cross(palmar_normal)`; it is not a guessed local
Euler component.

| Digit | Left flex axis | Right flex axis |
| --- | --- | --- |
| index | `(0.155261, 0.605481, 0.780568)` | `(0.148098, -0.607876, -0.780099)` |
| middle | `(0.097154, 0.392672, 0.914533)` | `(0.090837, -0.395333, -0.914035)` |
| ring | `(0.051479, 0.223885, 0.973255)` | `(0.050024, -0.241754, -0.969047)` |
| pinky | `(-0.024162, -0.057981, 0.998025)` | `(-0.029042, 0.059787, -0.997789)` |
| thumb flex | `(0.220740, 0.840902, 0.494122)` | `(0.213203, -0.842652, -0.494451)` |
| thumb opposition | `(0.850809, -0.399891, -0.340898)` | `(0.850403, 0.399348, 0.342543)` |

The first axis in each row is valid for all three nearly collinear joints of
that digit within about `2e-6`. Positive thumb opposition moves the thumb
toward the measured index/middle MCP target. Compose thumb opposition before
flexion.

Palm frames, also in Godot coordinates:

| Frame vector | Left | Right |
| --- | --- | --- |
| longitudinal | `(-0.247553, -0.914770, 0.319238)` | `(0.242904, -0.914205, 0.324388)` |
| palmar normal, medial | `(0.965977, -0.258491, 0.008369)` | `(-0.967523, -0.252446, 0.013034)` |

## Source-tested profile starting points

Angles are degrees for `.01 / .02 / .03`, multiplied by an eased profile
amount from zero to one.

| Profile | index | middle | ring | pinky | thumb flex | thumb opposition |
| --- | --- | --- | --- | --- | --- | --- |
| relaxed | `2/4/2` | `3/6/3` | `4/8/4` | `6/10/6` | `2/4/3` | `4/2/0` |
| grip | `30/42/28` | `34/46/30` | `38/50/32` | `42/54/34` | `8/16/12` | `24/12/4` |
| fist | `55/75/30` | `58/80/32` | `60/82/34` | `62/84/36` | `15/28/16` | `40/20/6` |
| brace | `0/1/0` | `0/0/0` | `1/2/1` | `2/3/2` | `0/1/0` | `0/0/0` |

The latest diagnostic images are under `tuned-v3/`. `current-strike` shows the
wrong-plane collapse; `relaxed` and `brace` are clean; `grip` is a useful open
hook. The proposed fist is materially better than the claw, but still reads as
a cupped/hooked hand rather than a fully contact-closed fist. The straight
three-bone rest chains, present weight field, and lack of self-contact limit
closure. These angles are safe integration starting points, not a final visual
acceptance claim. Earlier more aggressive renders are intentionally retained
as negative evidence: larger uniform distal curl caused visible looping and
interpenetration.

## Minimal V4-only runtime boundary

Suggested isolated helper:

```gdscript
static func apply_profile(
	rig: Dictionary,
	side: String,
	profile: StringName,
	amount: float
) -> void
```

Gate the call on the V4 anatomical profile and leave V1/V2 behavior unchanged.
The helper should replace only the 30 phalanx channels; existing wrist and hand
bone channels remain authored by the adapter. For each bone, convert an exact
body-axis quaternion through imported global rest:

```gdscript
var body_delta := Quaternion(axis.normalized(), angle)
var local_delta := global_rest.inverse() * body_delta * global_rest
var pose := (local_rest * local_delta).normalized()
```

For the thumb:

```gdscript
var body_delta := Quaternion(opposition_axis, opposition_angle) \
	* Quaternion(flex_axis, flex_angle)
```

Apply it after grounded animation sampling and as the final action hand
override. A bounded initial mapping is:

- grounded and recovery: `relaxed`
- strike: striking hand `fist`, guarding hand `brace`
- takedown and grapple: `grip` (takedown must be explicit)
- counter and evade: `brace` or a light `grip`/`brace` asymmetry
- crouch, jump, vault, and fall: `relaxed` or `brace` according to silhouette

Drive `amount` with contact/hold/release timing. For example, close strike by
contact and relax during recovery; close takedown through reach/pull then
release. A state-constant hand pose will still look mechanical.

## Reproduction

```text
/Applications/Blender.app/Contents/MacOS/Blender --background --disable-autoexec \
  --python work/action-quality/hand-study/measure_hand_axes.py

/opt/homebrew/bin/godot --headless --path /Users/markabraham/dev/batman \
  --script res://work/action-quality/hand-study/imported_hand_axes.gd \
  --log-file /Users/markabraham/dev/batman/work/action-quality/hand-study/imported_hand_axes.log
```

`render_hand_profiles.py` is intentionally refusal-to-overwrite. Change its
diagnostic output directory before producing a new evidence set. The Godot
import probe passes with exit `0`; the macOS system CA warning is unrelated to
the rig result.
