# R7 digit-anchor and local-weight diagnosis

Status: read-only diagnosis and in-memory prototype against the frozen R7
source. No Blender source, GLB, production rig generator, adapter, controller,
or material was saved or edited.

## Decision

**NO-GO for a narrow R8 anchor/weight-only source revision as the closed-hand
fix.** The source does contain two legitimate technical weaknesses—equal-third
digit anchors and excessively broad nonlocal weights—but correcting both in a
bounded runtime-equivalent prototype did not close the fingers. It introduced
a sharp palm/MCP crease and made the worst local LBS edge deformation larger.

The remaining separated silhouette is primarily kinematic: the licensed rest
hand has a large digit fan, while the current action helper supplies flexion
and thumb opposition but no long-finger MCP adduction/contact target. A source
reweight cannot move the bone endpoints together.

## Exact source diagnosis

The generator currently creates every digit from one straight wrist-to-tip
line and divides the post-MCP span into exact thirds:

```python
base_fraction = 0.42 if finger == "thumb" else 0.46
base = wrist.lerp(tip, base_fraction)
chain = [base.lerp(tip, segment / 3.0) for segment in range(4)]
```

Consequently the MCP/PIP/DIP positions are not measured from joint loops.
Every phalanx is exactly one third of the chain:

| Digit | R7 chain | Each R7 segment |
| --- | ---: | ---: |
| index | 123.94 mm | 41.31 mm |
| middle | 131.04 mm | 43.68 mm |
| ring | 125.61 mm | 41.87 mm |
| pinky | 112.02 mm | 37.34 mm |
| thumb | 95.52 mm | 31.84 mm |

The local weight field then calls `_normalized_envelopes` across all three
whole segments and multiplies that result by a broad geodesic digit/hand fade.
This is smooth, but it is not a joint-local skin field.

Measured R7 LBS weight behavior:

| Digit | 01/02 effective center offset from anchor | 01/02 strong span | 02/03 center offset | 02/03 strong span | Max retained hand weight beyond 70% |
| --- | ---: | ---: | ---: | ---: | ---: |
| index | +20.0 to +20.1 mm | 42.2–42.8 mm | +8.2 to +8.3 mm | 62.2–62.3 mm | 21.4–22.3% |
| middle | +29.5 to +29.7 mm | 25.1–31.5 mm | +11.9 to +12.0 mm | 61.5–61.6 mm | 22.9–23.5% |
| ring | +33.8 to +33.9 mm | 7.8 mm | +11.1 to +13.1 mm | 51.7–56.4 mm | 30.8–32.8% |
| pinky | +7.7 to +8.8 mm | 37.6–42.4 mm | +11.0 to +11.8 mm | 55.0–60.3 mm | 36.9–44.4% |
| thumb | +4.0 to +4.3 mm | 32.3 mm | +8.2 to +8.3 mm | 53.2–53.5 mm | 27.1–27.5% |

The worst distal examples are real mixed vertices, not rounding noise. For
example, R7 right-pinky vertex `10139` is at chain fraction `0.727047` yet is
`36.94% hand.R`, `2.98% pinky.01.R`, `28.08% pinky.02.R`, and `32.00%
pinky.03.R`. Right-ring vertex `17075` at fraction `0.701385` retains `30.83%
hand.R`. These patches stay partly tied to the palm while neighboring shaft
vertices follow the digit, producing a rubbery open arc under large curl.

## Exact rejected R8 prototype

The in-memory prototype made the smallest plausible mechanical correction:

1. Keep every MCP base and fingertip fixed.
2. Change chain fractions from `[0, 1/3, 2/3, 1]` to
   `[0, 0.46, 0.76, 1]`, producing 46/30/24% segments.
3. Replace all-segment envelopes with adjacent-only smooth transitions:
   PIP half-width `0.045` of digit length and DIP half-width `0.040`.
4. Reach full digit ownership by 20% of the chain and force maximum distal
   hand weight to zero.
5. Use linear blend skinning, matching Godot rather than Blender DQ.

This reweighted 6,000 connected-hand vertices with at most three influences.
Transition widths were 7.64–11.80 mm. Exact proposed joint coordinates for
both sides are emitted deterministically by
`diagnose_finger_anchors_weights.py`; representative right-hand values in
Blender coordinates are:

| Digit | MCP/base | proposed PIP | proposed DIP | tip |
| --- | --- | --- | --- | --- |
| index.R | `(0.380387,-0.162330,1.015338)` | `(0.391696,-0.197997,0.972320)` | `(0.399071,-0.221259,0.944265)` | `(0.404971,-0.239868,0.921822)` |
| middle.R | `(0.388050,-0.141494,0.997034)` | `(0.403496,-0.165910,0.944132)` | `(0.413570,-0.181833,0.909631)` | `(0.421629,-0.194572,0.882030)` |
| ring.R | `(0.385053,-0.122670,0.994516)` | `(0.398880,-0.136920,0.940255)` | `(0.407898,-0.146214,0.904867)` | `(0.415113,-0.153649,0.876557)` |
| pinky.R | `(0.382720,-0.090069,1.002667)` | `(0.395288,-0.086716,0.952807)` | `(0.403485,-0.084529,0.920289)` | `(0.410042,-0.082779,0.894276)` |
| thumb.R | `(0.352778,-0.154906,1.058912)` | `(0.348542,-0.192149,1.035987)` | `(0.345779,-0.216437,1.021036)` | `(0.343569,-0.235868,1.009075)` |

It failed the deformation comparison:

| LBS pose | R7 max edge ratio / delta | prototype max edge ratio / delta | R7 p99 ratio / delta | prototype p99 ratio / delta |
| --- | --- | --- | --- | --- |
| compact strike | `3.223x / 19.31 mm` | `5.052x / 23.76 mm` | `2.559x / 11.25 mm` | `2.559x / 11.61 mm` |
| takedown grip | `2.733x / 13.37 mm` | `4.402x / 17.54 mm` | `2.183x / 8.23 mm` | `2.195x / 8.75 mm` |

The source renders in `r8-joint-weight-prototype/` show the corresponding
sharp web/MCP fold, while the long fingers remain separated. This rejects the
specific 46/30/24 plus narrow-transition edit; it must not be copied into the
production generator merely because its anchor ratios are more anatomical.

## Kinematic control

The right hand's long-digit fan is already large in rest space: index-to-pinky
tip depth spans about `157.1 mm`, while their MCP bases span only `72.3 mm`.
The extra `84.8 mm` is divergent digit direction, not skin weighting.

Exact MCP rotations required to align each digit direction with the measured
palm longitudinal axis are:

| Digit | Left | Right |
| --- | ---: | ---: |
| index | `+20.07°` | `-19.79°` |
| middle | `+5.24°` | `-4.99°` |
| ring | `-5.35°` | `+4.66°` |
| pinky | `-22.19°` | `+22.67°` |

A bounded control on unchanged R7 used 70% of those values for strike and 45%
for takedown. It reduced strike fingertip across-span from `88.11` to
`77.30 mm` and takedown from `116.63` to `97.17 mm`. Maximum pair distance
fell from `95.17` to `85.74 mm` for strike and `125.52` to `108.06 mm` for
takedown. The visual change is real but modest: MCP adduction is necessary,
not sufficient, for a closed fist.

## Recommended path

Do not cut an R8 asset only for the tested anchor/weight revision. Keep R7
source/weights frozen and finish the V4-only runtime hand helper first:

- combine per-digit MCP adduction about the measured palmar normal with the
  already corrected flex axes;
- tune against an explicit palm/contact target in the actual strike pose;
- keep thumb opposition primarily on `.01`, with much smaller `.02` and `.03`;
- accept only normal-render contact frames, not the source close-up alone.

Consider a later R8 source rig pass only if normal-render action frames still
show rubbery joint deformation after the kinematic pose is correct. That pass
must derive real digit surface coordinates/geodesic joint bands, preserve the
hand/web continuity, and meet all of these non-negotiable gates:

- neutral bind/rest remains unchanged within existing tolerance;
- no cross-digit, palm, or forearm contamination;
- at most four normalized influences;
- distal hand weight below 5% after 70% chain fraction;
- adjacent-only joint transition spans 8–14 mm, centered within 3 mm of the
  chosen anatomical anchors;
- LBS max and p99 edge metrics do not exceed the R7 baselines above;
- actual strike fingertip spread materially improves, with no web crease,
  U-loop, intersection, or new tear.

That is a bounded weight-quality milestone, but it is not a substitute for the
missing contact-hand kinematics.

## Reproduction

- `diagnose_finger_anchors_weights.py`: exact bilateral anchors, crossfades,
  distal weights, and MCP alignment angles.
- `prototype_r8_joint_weights.py`: rejected in-memory anchor/weight candidate,
  runtime-equivalent LBS metrics, and four refusal-to-overwrite renders.
- `render_mcp_adduction_check.py`: unchanged-R7 kinematic control and four
  refusal-to-overwrite renders.

Frozen hashes before and after all runs:

- source:
  `40b4fca657e3ab91783ddeca2e2f02c87619f1daf89d245921397fc6f0669fdc`
- GLB:
  `faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`
