# Action-quality coverage audit

Original audit date: 2026-09-05; current addendum: 2026-09-08

This is the pre-change coverage map for the user-approved full action-quality
round. It is an audit, not a completion record. The frozen character-art R7
asset remains the exact candidate at
`faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a`;
V1 remains the project default. R7's static, import, rig, runtime-contract,
mechanics, foot-plant, and strict-deformation gates are accepted technical
evidence. They are not native R7 play or action-quality acceptance.

The controller/test snapshot audited here is pinned by these hashes:

| File | SHA-256 |
| --- | --- |
| `project.godot` | `d6427304c78fad05aa0787f937218a812b21a4271d4639e3239bc4c8de3b4a7e` |
| `main_3d.gd` | `b6dda6bc26adf6be1efd8286795012b92cba4bdccd137bd8f8b2b393f27670e8` |
| `actors/character_visual_builder.gd` | `bca65aa413a989bbf82f187340be76cfef9347f73408f0d91cd1a70b53d18b` |
| `actors/gloam_vigil/gloam_vigil_rig_adapter.gd` | `f8bcddc6b778b7286d3704057f23a451d3c93291eb115964da4adf67a797ba7a` |
| `work/action-readability/mechanics.gd` | `6eecda8156f24aabe181ee18a82c413c03802d62bb0ffa1a15bd254e130fe8b4` |
| `work/action-readability/deformation.gd` | `b985c6d80a46be707bfd02dcd264901499fb45dbb9f7c7688a929f102555d461` |
| `work/character-art-review/mechanics.gd` | `cce617265fffa4061ffc8b00d42c7b99c42426b788c715f22717de60b95febe5` |
| `work/character-art-review/deformation.gd` | `cd96176c9cc2905a02285b9740dfe3d2408bd0f99b2b2275a6e1426354da85b1` |

## Post-pass disposition

The implementation following this pinned audit closes the high-priority
grapple overlap, crouch-to-grapple, hurt/downed and connected guard-fall gaps,
adds the full rendered action reel and focused correction sequences, and expands
the strict R7 deformation suite from 14,730 to 21,642 checks. Current results are
198/198 default mechanics, 200/200 exact-R7 mechanics, 67/67 focused transitions,
451/451 rig, runtime/planting PASS and 21,642/21,642 strict action/deformation.
After the user's first native pass liked the appearance but rejected awkward
motion, the same task corrected crouch hand placement, jump/vault silhouette/
landing, forward-roll clearance and the supported downed settle. A second exact-
build native review rejected walking as unnatural/unbending, and the user later
rejected the thirteen-pose correction as well. Those 466- and 390-frame reels
remain historical rejected evidence.

The current R7-only replacement retargets licensed CMU 16_45 captured run/jog
frames 7–90 into 48 looped runtime poses. Exact provenance/hashes, spatial-side
mapping, T-pose/rest-arm correction and centered presentation-root boundary are
recorded under `actors/gloam_vigil/v4/motion/`. Both 30/60 Hz controller and
direct-builder diagnostics pass source cadence/contact, unchanged 4.8-unit/s
root speed, 2/4-frame stop settle, 93–100-degree swing-knee flex, support slower
than swing and zero hard-plant blocks. Two Blender builds are byte-identical.
The collision-free internally reviewed 342-frame gait reel is
`captures/r7-gait-cmu-final00000000.png` through `...00000341.png`. User gait
review remains before release.

### Current R14 addendum

The matrix below remains the dated pre-change audit. Current release evidence
is pinned to frozen R14 SHA
`30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b`.
Standing `WASD` now always uses the corrected captured run at 4.80 units/s;
`Shift` is inert and crouch is an absolute 1.178 units/s. `SPACE` presents one
of four nonrepeating punches/kicks even without a target, while commit-owned
contact prevents phantom damage. The target-independent suite passes 254/254,
four-attack suite 352/352, action motion 198/198, transitions 67/67, alignment
10/10, lower-leg stance 13/13, default/candidate mechanics 200/202 and full
R14 deformation 21,642/21,642. Native `space` and `C` smoke passed; the
position-dependent takedown and user visual/movement judgement remain.

The corrected 277-frame current reel is
`captures/r14-action-motion-fist-final00000000.png` through `...00000276.png`.
Its paired-strike setup explicitly faces the visible target because empty-space
attacks no longer auto-turn. It contains no script errors. The behavior rows
below that mention tap displacement, 62% crouch, movement during strike or a
single 0.36-second attack are superseded by this addendum and the authoritative
current project/checkpoint docs. Its active punch hand stays compact through
recovery and the expanded attack suite measures phalanx curl and distal-row
closure. The topology still leaves separated fingertips at close range.
Target-independent rendered evidence is
`captures/r14-target-independent-strike00000000.png` through `...00000179.png`;
matched front gait evidence is
`captures/r14-gait-alignment-final00000090.png` through `...00000179.png`.

The subsequent native review found that motion substantially better, while
flagging target-proportion artifacts: outward leg flare and excessive chest
pitch. A bounded R7-only target-space refinement now preserves pelvis transfer
and sagittal hip flexion while attenuating only thigh lateral/twist, modest
foot yaw and lower-spine pitch. Its real-controller ten-check diagnostic keeps
root speed at 4.8, reduces chest rotation pitch from 15.77/18.27 degrees
mean/max to 6.23/9.09, and reduces left/right knee flare from 8.14/10.60 to
2.57/6.32 degrees without collapsing neutral stance width. Matched pre/post
360-frame reels are `captures/r7-gait-alignment-baseline00000000.png` through
`...00000359.png` and `captures/r7-gait-alignment-final00000000.png` through
`...00000359.png`. The fresh paired performance report is
`work/character-art-review/reports/2026-09-05-locomotion-alignment-performance.md`.
User sustained-motion review still remains before release.

The separately authorized strike/evade/takedown phase is also now implemented
through the exact-R7 body-space action resource and narrow rig-adapter layer.
The 198/198 action-motion suite protects fist-leading 0.14-second contact,
four-heading 1.96-unit forward evade travel/height/floor recovery, and stable
pre-contact victim state with synchronized 0.34-second takedown fall. Dense
native-timing and labeled half-speed reels are
`captures/r7-action-motion-final300000000.png` through `...00000275.png` and
`captures/r7-action-motion-slow-final00000000.png` through `...00000551.png`.
The fresh paired 1080p performance run is recorded at
`work/character-art-review/reports/2026-09-05-post-retarget-action-performance.md`.
Ordinary C and the seven-tap T route pass on exact R7; ordinary-key SPACE and
user visual acceptance remain before release. This does not imply gait or R7
default acceptance.

The Sep-7 attack extension adds mirrored right/left straights and front kicks
with context-weighted nonrepeating selection, visible-facing target ownership,
one late one-slot buffer and unchanged damage/Momentum. Its 316/316 suite covers
30/60 Hz and all three presets, including behind/cross-behind rejection, active-
fist/guard separation, explicit punch/kick recovery and weighted skinned
support-sole floor contact. The Final2 paired baseline and Final5 slow-profile
reel cover all four moves; the Final3 eight-hit reel plus a current headless
replay route every request through the actual SPACE input handler. Exact render-
time weighted-sole probes resolve the apparent frame-374 float as perspective,
not lost contact. The Mac was locked for the final current-code render/native
attempt, so visible buffered-combo, native-OS SPACE, fresh DEBUG handoff and user
review remain honest release gates.
Treat every Pending/Gap row below as the pre-change audit record; current
acceptance truth and exact evidence are in `docs/CHECKPOINTS.md`.

## Evidence labels

- **Protected**: a durable deterministic test asserts the stated gameplay or
  deformation contract.
- **Historical V1**: accepted native or normal-renderer evidence exists, but it
  predates the frozen R7 candidate and cannot accept this pass.
- **Pending R7**: must be re-observed with the exact R7 asset after the new
  animation work, in the real scene and at the documented gameplay timing.
- **Gap**: no current test asserts the behavior, or the implementation leaves a
  transition policy undefined.

## Input and update-path truth

`project.godot` declares only `move_up`, `move_down`, `move_left`, `move_right`,
`camera_zoom_in`, and `camera_zoom_out`. The four movement actions are not read
by `main_3d.gd`; movement instead reads raw W/A/S/D keycodes from `held_keys`.
Zoom is the only continuous action read through `Input.get_axis()`.

All other controls are raw keycode dispatches in `_unhandled_input()`:
SPACE/E/C/Q/V/T/G/R/F12; camera arrows or J/L/I/K; camera reset 0; body presets
1/2/3; and accent X. A press also produces a fixed 0.42-unit movement tap before
held movement begins. This is a keyboard-only implementation contract today,
not a generalized InputMap/controller contract.

The runtime order is material to transition tests: timers and camera update,
then `move_player()`, action contact resolution, guard AI, defeat/fade,
presentation pose selection, success, and HUD. Player pose priority is:
takedown, grapple, grapple recovery, jump/vault, evade, fall, counter, strike,
crouch, grounded. Guard pose priority is defeat, restrained, stagger, attack,
grounded.

## Complete behavior matrix

| Behavior | Actual implementation and preserved contract | Existing evidence | New action-quality acceptance or gap |
| --- | --- | --- | --- |
| Idle | Grounded pose advances a low-rate procedural phase even at zero movement. Expanded rigs blend the authored idle loop and face loop. | R7 runtime contract proves nonzero expanded channels/morphs and exact bind recovery. Historical V1 40- and 204-frame sequences include neutral frames. | **Pending R7:** long hold from reset and after every action; breathing, gaze, hands, cape, feet, and silhouette must remain alive without sliding, chatter, visible loop snap, or accumulating drift. |
| Walk: held | W/A/S/D is camera-relative, 4.8 units/s; crouched speed is 62%. Actual movement updates last travel direction, facing, and a 0.16-second movement latch. Yaw eases at `delta * 14`; movement blend eases at `delta * 7.5`. | Mechanics protects collision/separation and crouch ratio. Foot-plant review protects ankle-origin slip reduction at held 4.8 units/s at 30/60 Hz, plus turn/teleport/action release. Historical V1 natural-motion sequence and live smoke show camera-relative travel. | **Pending R7:** ordinary held walk at default and changed camera, all three body presets, 30/60 Hz capture. Review whole-sole contact, pelvis transfer, arm swing, cape lag, and foot-plant releases. The foot fixture externally moves the actor; it is not a controller or whole-sole test. |
| Walk: tap | Each non-echo W/A/S/D press moves 0.42 units through normal blockers and personal space; crouched tap is scaled to 62%. Held state then continues through `move_player()`. | Mechanics protects the 0.42 route assumptions, takedown/evade tap suppression, low-passage collision, vault barrier, and separation. The seven-tap stealth route is deterministic and has historical V1 live evidence. | **Pending R7:** tap-only cadence must not restart authored starts every tap, double-step when a key is briefly held, or pop the feet/root. Add displacement and clip-state assertions for press/release timing. |
| Walk start | Expanded rigs select a 0.42-second authored start when movement crosses the prior amount by more than 0.015 and the transition gate permits. | Runtime contract proves channels move, but no durable test checks start selection, duration, root continuity, or visual quality. Historical V1 evidence is not this authored R7 start. | **Gap / Pending R7:** test rest-to-tap, rest-to-held, diagonal start, action-to-walk, crouch-to-walk, and immediate reversal at 30/60 Hz. Require no first-frame foot teleport, knee snap, root offset, or double acceleration. |
| Walk stop | Expanded rigs select a 0.34-second authored stop on the inverse movement crossing. Grounded blend decays separately at 7.5/s. | Historical V1 sequences show grounded recovery; no durable test proves the R7 authored stop or its interaction with the controller latch. | **Gap / Pending R7:** held release and short-tap release at multiple gait phases; stop-to-idle and stop-to-action continuity; no planted-foot skate or stop-loop retrigger. |
| Turns and reversals | Travel sets target yaw from actual displacement and root yaw interpolates. There is no dedicated authored turn clip. The foot layer releases on excessive frame turn. | Foot fixture asserts one synthetic turn releases lock. Historical V1 travel/orbit smoke shows basic camera-relative direction. | **Gap / Pending R7:** stationary 90/180-degree facing changes, moving 90-degree turn, W-to-S reversal, camera orbit while held, and action-facing handoff. Measure root-yaw continuity and stance-release/reacquisition; visually reject foot pivots or cape snaps. |
| Q enter crouch | Q enters crouch unless takedown, invulnerability, grapple, airborne, or evade blocks it. Entry cancels a pending strike. | Mechanics protects toggle, 62% tap movement, traversal rejection, and strike cancellation under the lintel. R7 full deformation samples the complete crouch pose at 30/60 Hz and all presets. Historical V1 crouch sequence/live smoke exists. | **Pending R7:** open-space settle, moving entry, action-to-crouch, asymmetric limb balance, hands/cape, and silhouette at all presets. Direct-pose deformation is not a controller transition test. |
| Q crouched movement | Same controller path at 62% speed; low-passage collision permits the route. Inside the lintel, visual pose delta is forced to 1.0 to grant measured clearance immediately. | Mechanics protects ratio and route. R7 deformation protects full-vertex floor/lintel bounds for direct crouch samples. Historical V1 live smoke shows low-speed movement. | **Pending R7:** enter and traverse with ordinary held and tap input; reject head/collar clipping, knee/boot penetration, rapid forced-pose pop, and foot sliding. |
| Q exit and lintel | Q exits in open space; under the 2.0-unit passage it is rejected. Standing entry from outside is blocked. Strike, evade, jump route, and takedown have lintel gates. | Mechanics explicitly protects standing-entry block, crouched entry, rejected stand, rejected strike/evade/jump/takedown, exit, and restored height. | **Pending R7:** exact approach, forced low pose, blocked exit feedback, boundary exit, and stand recovery with all presets. Check collar/head clearance at both passage edges. |
| V free jump | 0.62 seconds, 2.2 units, 1.35-unit apex. Direction uses last travel direction, falling back to facing. It is not invulnerable; landing resolves guard separation. | Mechanics protects selection, constants, apex, damage, boundary/low-route rejection, and landing. R7 full deformation samples all vertices at every 30/60 Hz jump frame and recovery. Historical V1 56-frame sequence and one live V jump exist. | **Pending R7:** actual controller takeoff, apex, landing compression, motion handoff, and stop/turn/action entry after landing. Validate all presets against real floor, not only modeled actor paths. |
| V contextual vault | A 20-sample horizontal path selects vault over the low obstacle: 0.48 seconds, 2.2 units, 1.05-unit apex. | Mechanics protects barrier block, contextual selection, constants, clearance, and landing. R7 full deformation covers every direct-pose frame at 30/60 Hz/all presets. Historical V1 sequence exists. | **Pending R7:** ordinary approach at different gait phases and camera angles; hands/feet should read as a vault rather than a shorter jump, clear geometry, and return without root or cape pop. |
| C forward evade | Uses visible root yaw at input, commits 1.96 units over 0.28 seconds at 7 units/s, rotates +TAU, and keeps invulnerability/retrigger lock to 0.42 seconds. It cancels strike/counter/crouch and rejects air, grapple, takedown, repeat, and lintel use. Collision remains active. | Mechanics strongly protects facing, exact travel/spin/timers, once-only Momentum, damage rejection/resumption, tap/held suppression, collision/boundary, rejection, perch edge, and post-travel lock. R7 deformation samples all frames/presets/rates. Historical V1 48-frame evidence used a superseded remembered-direction contract; later V1 action-readability footage reflects current timing. | **Pending R7:** exact visible-yaw launch, tuck, contact-free forward roll, landing absorption, cape lag, and recovery into idle/walk/strike. Do not reuse the old remembered-direction sequence as acceptance. |
| SPACE strike | 0.36-second action; one contact at 0.14 seconds. Range and height are rechecked at contact. Hit deals 22 plus 8% Momentum and grants 13; whiff costs 8. Mash cannot restart or repeat contact. Counter, evade, crouch, jump, takedown, grapple, and reset can cancel the pending strike through code paths. Movement is not blocked during strike. | Mechanics protects timing, once/mash, counter/evade/reset cancellation, contact range/height, late range entry, whiff, label update, and reaction. R7 deformation protects every direct strike frame/all presets/rates. Historical V1 225-frame and ordinary single-SPACE evidence exist. | **Pending R7:** ordinary stationary and moving strike, contact alignment at exactly 0.14 seconds, whiff, repeated input, hit reaction pairing, and recovery into movement/counter/evade. Add tests for the code-permitted Q/V/T/G cancellations; current suite proves only counter/evade/reset explicitly. Decide whether locomotion during the strike is intended before treating it as a bug. |
| E ordinary counter | E only acts while `attack_timer > 0`. Outside the strict perfect interval, it cancels the attack, grants 8 Momentum, triggers a 0.25-second guard reaction, and plays a 0.44-second player counter; it deals no guard damage. | Mechanics protects damage/Momentum/reaction/duration. Historical V1 combat/action-readability capture exists. | **Pending R7:** early/late ordinary blocks need distinct anticipation, impact, guard reaction, and clean return. Add exact boundary tests at 0.30 and 0.56 because comparisons are strict. |
| E perfect counter | Strict `attack_timer > 0.30 && < 0.56`; cancels attack, deals 30, grants 28, triggers 0.55-second guard reaction, and refreshes label immediately. | Mechanics protects the nominal perfect result and one ordinary result. Historical V1 104-frame combat sequence and live evidence exist. | **Pending R7:** predetermined input bursts at the true window; contact pairing, direction, hand/weapon spacing, impact beat, and return. Test both strict boundaries plus one sample just inside/outside each boundary at 30/60 Hz. |
| T paired takedown | Eligibility requires darkness, strict range below 2.1, behind dot below -0.15, same level, no lintel, and available traversal state. It reserves the guard, blocks ordinary movement/actions, approaches collision-safely by at most 0.62, contacts once at 0.34 seconds, defeats/grants 35, and completes at 1.10 seconds. | Mechanics strongly protects eligibility, timer/contact, mash, locks, reservation, auto-approach, once-only reward, reset, height/lintel, seven-tap route, defeat/exit/restart. R7 deformation protects player full mesh, not paired guard mesh alignment. Historical V1 stealth and 225-frame paired sequences exist; the latter uses helper placement. | **Pending R7:** ordinary seven-tap route and exact two-actor catch/pull/fall/release at contact; hand-to-guard and floor alignment, no interpenetration, guard restraint/defeat continuity, and stable player recovery. The guard is procedural and still requires its own visual review. |
| G grapple transit | Inside the 3.5-unit anchor range, the player eases to the exact 3.04-high perch over 0.32 seconds; range and already-elevated gates apply. | Mechanics protects range, duration tolerance, landing position/state, height safety, and attack rejection by level. R7 deformation samples direct grapple frames at both rates/all presets. Historical V1 28-frame and live ready/transit/landed evidence exists. | **Pending R7:** ordinary G from multiple headings, takeoff/reach/rope-line readability, hand alignment, cape drag, and collision-free arrival. |
| Grapple recovery and perch movement | On arrival, grapple ends, player becomes perched, and a 0.32-second visual recovery starts. Perch walking is allowed during recovery. | Mechanics protects recovery timer, perch walking, edge departure, and floor landing. R7 deformation samples direct recovery. Historical V1 live perch walk/fall exists. | **Pending R7:** transit-to-land compression, moving during recovery, idle on perch, camera-relative movement, and recovery interruption must remain smooth. |
| Perch fall and landing | Leaving the perch footprint sets airborne/fall; evade may carry off the edge while preserving its higher-priority roll pose. Gravity lands on perch or courtyard floor and restores grounded state. | Mechanics protects edge fall, floor/perch landing, level-gated guard damage, and evade-off-perch pose priority. R7 deformation directly samples fall and recovery at 30/60 Hz/all presets. | **Pending R7:** ordinary walk-off and roll-off; edge anticipation, continuous roll-to-fall or walk-to-fall, cape response, foot-first landing, compression, and clean locomotion reacquisition. |
| Guard patrol, turn, suspicion, and alert | Guard targets patrol points until sight builds suspicion at 45/s; it decays at 16/s. At 100 the guard alerts, chases at 2.5 vs patrol 1.35, and may attack inside 1.8. | Historical V1 natural-motion/live evidence shows patrol, turn, and alert. Mechanics usually sets alert/positions directly and does not protect the full perception-to-attack timeline. | **Gap / Pending:** deterministic real-scene test from patrol through sight gain/loss, alert, chase, turn, separation, and attack opening. Visual review needs patrol foot contact, alert transition, and readable facing. |
| Guard attack | Alert, same level, distance below 1.8, and cooldown zero opens a 0.72-second attack. Marker reads PERFECT while timer is strictly between 0.30 and 0.56; unresolved expiry checks distance below 2.2. | Mechanics protects opening timer/marker, one resolved hit, and level rejection. Historical V1 combat sequence shows telegraph. | **Pending R7 scene:** guard remains the existing procedural actor, but timing must still pair cleanly with the R7 player's ordinary/perfect counter and evade. Add full AI-entry and whiff-on-range-exit tests. |
| Guard hit/stagger | Strike starts a 0.32-second reaction; ordinary/perfect counter use 0.25/0.55 seconds and a remembered reaction side. Stagger outranks attack pose. | Mechanics protects durations, health/Momentum, and immediate label. R7 player deformation does not inspect the guard. Historical V1 combat/action-readability frames show reactions. | **Pending:** paired contact at correct side/distance, no attack-pose residue, leg/root stability, recovery to alert locomotion, and repeated alternating hit sides. |
| Guard defeat/fade | Defeat clears attack/alert/vision, grants 35, holds the visual through a 0.78-second delay, fades to 1.45 seconds, then hides visual/label and removes the invisible blocker. Reset restores it. | Mechanics protects every listed state, timing, transparency, removal, pass-through, and reset. Historical V1 combat/stealth sequences and live evidence exist. | **Pending:** paired strike/counter/takedown sources, grounded collapse and contact, fade readability from gameplay camera, player movement through the former position, and reset without pose/material residue. |
| Player hurt | Uncountered guard hit removes 18 health and 25 Momentum; invulnerability rejects damage. `damage_player()` only changes values/message. There is no hurt timer or hurt pose in the audited controller. | Mechanics protects numeric damage/Momentum and evade immunity/resumption. Historical ordinary combat smoke observed one hit. | **Implementation/acceptance gap:** define and add a non-displacing hurt reaction or explicitly accept HUD-only feedback. Test attack contact, invulnerable miss, recovery, interruption policy, camera/HUD feedback, and repeated hits. Preserve 18/-25. |
| Player death/downed | Health clamps to zero and message changes to DOWNED. `_process()` continues, and `_unhandled_input()` has no downed gate; movement and actions therefore remain code-permitted. | Reset tests restore health, but no durable test asserts downed input behavior or a death pose. Docs record post-downed input as a pre-existing quirk. | **Implementation/acceptance gap:** define terminal behavior. At minimum test movement/action/camera/F12/reset after zero health, guard AI continuation, stable downed pose, and R recovery. Do not silently change this policy inside animation work. |
| R reset/restart | Restores spawn, health, Momentum, guard, terminal states, timers, player/guard poses, visibility, objective, and camera defaults. It preserves the currently selected body preset and accent; it does not restore customization defaults. | Mechanics protects reset before/after pending strike and takedown, after defeat/success, spawns, health/Momentum/guard, camera, objective, and stale-contact cancellation. Historical V1 live smoke exists. | **Pending R7:** reset during every visible transition and after downed/success; exact idle recovery, preserved accent/preset, and no one-frame stale pose, planted foot, morph, cape, or timer. |
| 1/2/3 body presets | Set runtime player scales 0.88/1.0/1.16 over the 1.35 base scale. | Mechanics protects exact values/scales. R7 deformation covers every action at all three presets. | **Pending R7:** live silhouettes, contact pairing, floor/lintel/perch clearance, and camera framing for all presets. Full-deformation evidence remains technical, not visual acceptance. |
| X accent | Cycles outfit accent material and emission. | Mechanics protects index and authored material compatibility. R7 technical asset/material contract passes. Historical V1 live customization smoke exists. | **Pending R7:** cycle during idle/action and after reset; no shared-material contamination, missing surface, flash, or change to non-accent surfaces. |
| Camera orbit/pitch/zoom/reset | Arrows/J/L orbit, I/K or arrows pitch, `-`/`=` and keypad variants zoom; 0 restores constrained defaults. Movement remains camera-relative. | Existing checkpoints accept orbit, pitch, orthographic zoom, reset, and camera-relative movement. Mechanics protects reset values. Historical live smoke and F12 evidence exist. | **Pending R7:** repeat changed-camera locomotion and every large action silhouette; no occlusion or misleading action direction. This is regression evidence, not a request to change accepted camera mechanics. |
| Exit/success | Once the guard is defeated, entering within 2.3 of the exit sets success. `_process()` then only updates HUD. R resets. | Mechanics protects defeat-gated success and restart. Historical V1 ordinary stealth route reached exit. | **Pending R7:** ordinary complete route with exact candidate. Also test post-success raw inputs: the process freeze prevents motion, but input handlers can still mutate some state; expected policy is not explicitly protected. |
| F12 capture | After one frame, creates `captures/`, reads the viewport image, and saves a timestamped PNG. | Many historical accepted V1 captures prove the path. Headless tests do not exercise a meaningful native viewport. | **Pending R7:** parent-owned native run must acquire exact DEBUG title, press F12, and verify a new project-local PNG with correct content. |

## Transition-policy audit

The following are implementation facts at this snapshot. “Permitted” means the
static call path allows the combination; it does not mean that combination is
intentional or visually accepted.

| Transition | Current path | Evidence and remaining question |
| --- | --- | --- |
| Strike to counter | Counter cancels pending strike and becomes the higher-priority pose. | **Protected.** Recheck visual contact/recovery on R7. |
| Strike to evade | Evade cancels strike and counter, snapshots visible yaw, and commits the roll. | **Protected.** Recheck visual handoff on R7. |
| Strike to Q/V/T/G | Each successful entry calls `cancel_strike()`; lintel/range/eligibility rejection leaves the strike path otherwise intact. | **Gap:** add exact before-contact and after-contact tests for each input. |
| Counter to evade | Evade clears `player_counter_timer`. | Static contract is clear, but no focused deterministic/visual transition test exists. |
| Counter to Q/V/G | Q and V do not explicitly reject or cancel a counter; G only cancels strike. Pose priority may hide the counter behind traversal, or let its timer expire underneath. | **Gap:** define intended priority and test it; do not infer quality from pose priority alone. |
| Strike while moving | Ground movement remains enabled and can update facing while strike has already faced toward the guard; strike pose then outranks grounded pose. | **Gap:** decide whether locomotion is intended. Test contact alignment and root motion before changing it. |
| V then G in the same frame | `grapple()` does not reject or clear `jump_active`. Grapple wins movement/pose priority, but the stale jump can resume after grapple finishes. | **High-priority gap:** reproduce at the real anchor, define rejection/cancellation, and protect whichever behavior is chosen. |
| Crouch then G | Grapple does not clear `crouching`; grapple pose hides crouch, which can remain set on the perch. | **High-priority gap:** reproduce and define whether G exits crouch or rejects. |
| Air/grapple to counter | `counter()` does not explicitly reject airborne/grapple/low-passage state if an attack timer exists. Normal level/range flow makes this uncommon, but helper or same-frame timing can expose it. | **Gap:** test real reachable paths and add explicit policy only if necessary. |
| Evade off perch | Roll pose outranks fall until invulnerability ends; fall then appears and lands normally. | **Protected mechanically.** R7 continuity remains visual pending. |
| Takedown active | Player movement and other action inputs are blocked; guard AI is reserved; contact happens once and presentation continues. | **Protected strongly.** Paired R7 visual alignment pending. |
| Downed or success | Downed has no global control lock. Success returns early from `_process()`, but raw input dispatch is still active. | **Policy gap:** explicitly specify/test terminal-state input behavior before animation completion. |

## Current durable suites and their limits

| Suite | Accepted result | What it protects | What it does not accept |
| --- | --- | --- | --- |
| `work/action-readability/mechanics.gd` | 198 checks, V1 default | Real scene with processing disabled and deterministic stepping; mechanics listed above. | Most locomotion transitions, full guard perception timeline, hurt/downed presentation, native input/rendering, or R7 appearance. Many scenarios use test placement. |
| `work/action-readability/deformation.gd` | 4,176 checks, all 97,061 V1 vertices | Strike, takedown, evade, and recovery at 30/60 Hz and three presets. | Current R7, controller transitions, remaining actions, native appearance. |
| `work/character-art-review/mechanics.gd` | 200 checks, exact R7 | Inherited 198 mechanics while the exact candidate is attached, plus exact-path/fingerprint selection. | Subjective animation quality or native input. |
| `work/character-art-review/deformation.gd` | 21,642 checks, all 48,314 R7 exported references | Crouch plus four strikes, takedown, evade, grapple, recovery, jump, vault, counter, fall, recovery; 30/60 Hz; three presets; full morph/skinning/floor/lintel/driver/root checks. | Native rendering, subjective action quality, or real OS input. Actor paths are modeled by the harness. |
| `work/action-quality/attack_combo.gd` | 316 checks, exact R7 | Four-attack selection/contact/buffer ownership, 30/60 Hz poses, presets, guard separation, mid-recovery punch/kick withdrawal, support-sole contact and invalid targets. | User judgement or native-OS input. |
| `work/character-art-review/runtime_contract.gd` | PASS | Expanded rig channels and four morphs genuinely animate; bind recovers exactly. | Natural timing, contact pairing, transitions, or native visual quality. |
| `work/character-art-review/foot_plant_review.gd` | PASS at 30/60 Hz | Ankle-origin drift reduction at held 4.8 units/s, support coverage, root preservation, and turn/teleport/action release. | Whole-sole contact, starts/stops, player controller, traction, or visual acceptance. The fixture externally advances the actor. |
| Historical normal-renderer/live records | Accepted V1 sequences: 40 locomotion, 28 grapple, 104 combat, 48 old-direction evade, 54 crouch, 56 jump/vault, 58 stealth, 204 polish, and 225 action-readability frames, plus documented smokes. | Historical design and presentation baselines. | Frozen R7 or the new action-quality pass. Helper-driven sequences are not ordinary input. |

The old `/private/tmp/gloam-vigil-mechanics-probe.gd` and game-sequence helpers
must not be treated as current authority: old copies encode immediate-hit and
remembered-evade assumptions that the durable 196-check suite intentionally
superseded. The historical actor-polish probe is also not a durable current R7
test merely because its 204-frame V1 result remains accepted.

## Focused regression work for real gaps

### 1. Controller transition harness

Add a new real-scene, explicit-R7 harness that disables automatic processing,
sends the same key events as `_unhandled_input()`, and steps `_process()` at both
30 and 60 Hz. It should preserve every current numeric gameplay contract while
covering:

- idle to tap/held walk, walk to stop, stop to idle, 90/180-degree turns,
  W-to-S reversal, diagonal movement, and camera-relative travel;
- Q open-space entry/move/exit, forced lintel pose, blocked exit, and boundary
  recovery;
- every action entered from idle and movement, plus action-to-idle,
  action-to-walk, and action-to-action cancellation/rejection;
- explicit strike-to-Q/V/T/G before and after the 0.14-second contact;
- counter-to-evade/Q/V/G, V-to-G same-frame, crouch-to-G, and real reachable
  air/grapple counter attempts;
- grapple transit/recovery/perch walk/walk-off, evade-off-perch, fall, floor and
  perch landing;
- guard patrol to suspicion gain/loss, alert/chase/attack, player range exit
  before attack resolution, hit, each counter window boundary, stagger, defeat,
  fade, blocker removal, and reset;
- damage to hurt/downed, all gameplay keys while downed/success, and reset;
- presets/accent/camera reset state and stale timer/pose cancellation.

Assertions should read actual positions, timers, health/Momentum, flags, selected
pose/clip state, root/bone continuity, and guard state. Finite transforms alone
are insufficient. Any transition-policy change must be decided by the
integration owner first; the harness must not make an accidental behavior look
canonical.

### 2. Full-scene transition deformation harness

Extend the existing all-vertex method rather than replacing it. Drive the real
controller through all transitions at 30/60 Hz and all three presets, sampling
every R7 surface/morph. Keep the established floor/lintel/contact tolerances and
actor-root ownership checks. Add frame-to-frame continuity reporting for head,
hands, feet, shoulders, pelvis, cape tips, facial bounds, and full-mesh bounds.
Derive discontinuity review thresholds from the unchanged pre-pass sequence and
inspect outliers visually; do not invent a generous threshold merely to pass.

This harness must include paired player/guard bounds for strike, ordinary and
perfect counter, guard hit/stagger, takedown, and defeat. The current strict R7
deformation suite only owns the player mesh.

### 3. Deterministic rendered comparison

After deterministic tests pass, record normal-renderer sequences at actual
timings with both gameplay and close review cameras. Include:

- idle, tap and held starts/stops, 90/180 turns, reversals;
- crouch entry/travel/blocked exit/recovery;
- free jump, contextual vault, evade, grapple/recovery, perch walk/fall/land;
- moving and stationary strike hit/whiff, ordinary/perfect counter, guard
  attack/hit/stagger/defeat, paired takedown, player hurt/downed/reset;
- interruptions and rejection cases from the transition harness.

Capture before/after frames from the exact same controller sequence. A movie
fixture may set initial scenario positions, but it must call the real action
methods and disclose every helper placement. It cannot substitute for the
ordinary-input smoke.

### 4. Native ordinary-input acceptance

The integration owner must acquire `org.godotengine.godot`, confirm the exact
`Gloam Courtyard Spike (DEBUG)` title, and play the unchanged scene using normal
keys. Exercise a complete stealth route, combat with ordinary/perfect counter,
evade, crouch/lintel, jump/vault, grapple/perch/fall, hurt/downed/reset,
customization, changed-camera movement, exit, and F12. Predetermined bursts or
human timing must own sub-second reactive windows; screenshot latency cannot.
Inspect the newly saved PNGs and record quirks honestly.

### 5. Performance and default isolation

After animation integration stabilizes, rerun the existing quiet, paired V1/R7
1920x1080 protocol in one confirmed-unlocked session. Animation quality must not
claim an FPS guarantee from triangle count or a headless result. Separately
rerun default V1 mechanics/deformation and verify the default asset/path did not
change unless promotion is explicitly accepted.

## Acceptance bar for this round

This round is not complete until all of the following are true:

1. The exact frozen R7 SHA is used, or a newly authorized asset SHA is recorded;
   no silent model substitution occurs.
2. The 198 default mechanics, 200 R7 mechanics, runtime contract, support-foot,
   268 four-attack and 21,642 strict R7 deformation gates remain green at
   unchanged thresholds.
3. A controller-transition suite covers all matrix rows at 30/60 Hz, including
   the undefined overlaps and terminal-state gaps above.
4. Actual rendered before/after sequences show natural starts, stops, turns,
   contact, follow-through, landing, interruption, and recovery without visible
   mesh collapse, clipping, foot skate, pose pop, cape snap, or root drift.
5. Guard and player paired actions read at their unchanged contact/window times;
   player hurt/downed behavior is either implemented and protected or explicitly
   accepted as a scoped gap.
6. An ordinary-input native smoke and new F12 capture pass in the exact DEBUG
   window. Current R7 source and headless evidence cannot satisfy this item.
7. Paired performance/default-isolation evidence passes before any R7 promotion.
8. Only then may project checkpoints and the derived task board claim the
   action-quality milestone complete.

## Existing reproduction commands

These reproduce current technical baselines; they do not by themselves accept
the new action-quality round:

```sh
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/action-readability/mechanics.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/action-readability/deformation.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/character-art-review/mechanics.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/character-art-review/runtime_contract.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/character-art-review/foot_plant_review.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/character-art-review/deformation.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/action-quality/attack_combo.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/action-quality/r7_action_motion.gd
godot --headless --path /Users/markabraham/dev/batman --script /Users/markabraham/dev/batman/work/action-quality/transitions.gd
```

The consolidated exact-R7 raw evidence is
`work/character-art-review/reports/2026-09-05-v4-r7-faafa629-raw.log`.
