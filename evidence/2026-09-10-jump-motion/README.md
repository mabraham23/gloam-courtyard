# Standing and moving jump review — 2026-09-10

Technical pass; user movement/visual judgement pending. R14 remains a review
candidate and V1 remains the project default.

## Final requested behavior

A stationary V press starts a 0.12 s grounded gather, a 0.62 s flight with a
1.35-unit parabolic apex, then a 0.20 s grounded impact/recovery. Both legs extend
in standing flight. Actual held movement before V selects a moving jump carrying
2.2 units along the takeoff direction, with a mirrored split-leg/contralateral-arm
pose. The lead alternates on successful free jumps. A held key without prior
movement does not manufacture a moving jump.

Held WASD retains gentle camera-relative air adjustment at 1.40 units/s. Same-
direction input does not add a second forward impulse to moving jumps; release
preserves their committed travel. Standing jumps have no drift without input.
Normalized diagonals, release/reverse/focus-loss clearing, safe floor footprints,
courtyard bounds and partial-frame launch/touchdown integration are checked.
Contextual V barrier vault remains 0.48 s / 1.05-unit apex / 2.2-unit travel.

The controller owns the phases, translation, collision and action lock. The bounded
pose curves have a stable home in `actors/player_jump_motion.gd`; the builder
applies them and the rig adapter maintains grounded preparation/landing sole
contact. Assets, ground speed and the production character selection are unchanged.

## Matched rendered evidence

`index.html` compares the original unconditional running leap with the final motion,
using exactly the same 240-frame fixture, engine, seed 1729, 30 Hz, 960x600 and
OpenGL compatibility renderer. Both source snapshots and all hashes are in
`comparison.json`. Before source: `6b354cf47ffc`; after: `903bedff58ed`.
Fixture SHA: `282c47c71d905f61264341201d981482216edff072e597f094e2d6ca8d6a7ef9`.
The chosen contact-sheet frames differ to expose the new preparation/landing beats;
the original full-rate frame sequences and animated previews use identical inputs.

The fixture covers two stationary jumps, air-input press/release, the preserved
vault, and a run into a moving jump followed by input release. `gameplay.webp`
and `gameplay.jpg` show the same sequence with the default camera. The fixtures
place actors, hide labels and select review cameras explicitly; they are not
ordinary native-input evidence. Original PNGs are under `keyframes/`.

Viewed phase frames show grounded knee flexion, extended standing flight, a visible
moving split, and grounded absorption/recovery. At default scale the crouch is
subtle but the standing versus moving root paths remain distinct. The original
running-leap and the superseded all-vertical interim runs are retained locally.

## Verification

- Default mechanics: 309 checks; R14 mechanics: 311 checks. Both include new
  standing/moving direction, timing, actual movement selection, both-rate diagonal
  normalization, jump lead, air control, landing clearance and action-lock checks.
- Real-controller full-mesh jump gate: 5,598 checks / 18 cases, all 49,315 evaluated
  vertices at every frame, small/medium/large at 30/60 Hz, standing plus both moving
  leads. Grounded sole min/max across cases: approximately -0.000139 / 0.029828
  world units, within the existing 0.03 floor and 0.055 contact tolerances.
- Updated legacy landing/recovery gate: 1,302 checks. Its jump timeline now matches
  the controller; no historical full-action deformation count is claimed as fresh.
- Action transitions: 67; target-independent strikes: 254. Import and default
  startup pass. Twelve review/preservation/board tests pass. No script/resource
  errors or Godot warnings in the retained headless logs.
- Both local board files regenerated from task records; schema/parity check passed.
  Rendered board interactions remain the pre-existing Browser Use URL-policy gate.

## Ordinary native handoff

Exact window `Gloam Courtyard Spike (DEBUG)`, PID44250, source
`c9e551cb87cb203fe0b963aa3a29e658cb71e3a345910acea91faaf91f84a4bc`.
This source differs from the close-up capture only in subsequently updated test
files; the gameplay/default-camera capture uses this final source. Frozen R14 GLB
SHA is `30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`.

Native V and a predetermined F12 burst captured grounded preparation, airborne
positions through an observed Y=1.3323 apex, and grounded recovery, with X/Z fixed
at (-6, 2.5). The second successful jump records lead -1 versus the first's +1.
C completed 1.96 units with +4 Momentum; Space started a target-free strike; Q
visibly crouched. R/0/F12 restored health100, Momentum0, guard100 and camera18.5.
The enlarged reset window was visually inspected and left open. Every curated PNG
matches its sidecar image hash and every capture reports no changed source files.

`native/observations.json` separates actual native keys from fixture input. Moving
jump/held-air-control evidence is deterministic normal-renderer/controller evidence;
continuous native key holding and user judgement remain pending. No new paired
performance certificate is claimed, and F12 capture timing is not frame-performance
evidence.

## Quirks and next acceptance

The brief gather pauses travel and the impact phase holds action control for its
0.20 s recovery. These are intentional readable beats for this review; the user
should judge their responsiveness during continuous movement. The dedicated vault
still takes priority near its barrier. The small actor marker follows airborne
height as before. Existing hair, gait foot sliding and unrelated action acceptance
remain separate R14 limitations.

Next: user plays standing V, held WASD then V, repeated moving jumps, and landing
back into held movement. Refine the gather/split/absorption only from that feedback;
this checkpoint does not promote R14 or close earlier held-movement/takedown gates.
