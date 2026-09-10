# Whole-body fluidity review — September 10, 2026

The user found the previous upper-body pass still stiff. That pass remains
preserved as the baseline; its technical passes did not establish natural motion.
This review asks whether actions flow into and out of each other without abrupt
changes in the arms, spine or legs.

## Cause and changes

The adapter rebuilt each skeleton pose, then overwrote smoothed driver rotations
with captured gait or procedural action channels. Entering an action or returning
to grounded movement could therefore discard the preceding visible pose. The
controller's fast movement blend also exposed this when releasing movement.
Small additive chest/shoulder offsets could not correct those discontinuities.

The anatomical candidate now bridges the final composed poses on action changes
and start/stop intent. It carries a bounded amount of the outgoing rotation and
settles arms and legs over short, action-specific intervals. Steady clips retain
their authored motion; brief punch entries finish before contact. Resets and
low-clearance crouch requests remain direct, so blending cannot delay the lintel
silhouette. The bridge does not translate the gameplay root.

Punch guard rises across the windup and remains up through recovery. The returning
fist folds once, then relaxes through the transition instead of folding and dropping
inside the last tenth of a second. Jump limbs continue gathering through the apex
instead of holding a split pose. Grounded jump preparation/landing releases stale
gait foot-height compensation immediately. Speeds, damage, contact times, jump
trajectory and controls retain their existing controller values. V1 stays default.

## Matched visual evidence

[Before/after reel](comparison/index.html): 480 frames each, 30 Hz, 960×600,
Godot 4.7.2 / GL compatibility, seed 1729. The existing actual-controller fixture
is unchanged: SHA `b2860a6e20e75556e1f5e07538c2351878c42c1cc3710525073a888bfe521c32`.
It uses explicit input/placement helpers and four specified strikes. It is
scripted movement evidence, not native held-input or performance certification.

- Before: `20260910T201912Z-upper-body-94418e`, source `3e4bb12bca1b`.
- Final: `20260910T211726Z-upper-body-c14329`, source
  `9134ed3156787e01e533cae8841a6fb2524ac4823d02a583cfebe4653f4fed72`.
- Original selected frames, manifests, full previews, and dense stop/rise/punch
  strips accompany this report. Raw frames and frozen sources remain pinned.

Agent review: stopping now settles the arms while the legs finish their change
of pose; crouch exit unfolds across several frames instead of straightening in
one. Punch recovery retains a raised guard and releases gradually. The moving
jump gathers the trailing limbs towards landing. Kick, counter, evade, takedown
and grapple exits now pass through the same bounded continuity layer. At normal
gameplay zoom these changes are subtler than in the close profile/quarter views.

## Temporal regression and protected checks

`work/action-quality/motion_continuity.gd` measures the actual parent-local bone
rotations through the same controller sequence, excluding diagnostic reset frames.
It checks action boundaries, the entire stop interval, and the largest step
anywhere in the sequence so a snap cannot simply be displaced to the next frame.
The three checks fail on the preserved baseline and pass on the final source.

| Measured rotation change per 30 Hz frame | Before | After |
|---|---:|---:|
| Largest action-boundary step | 111.65° | 25.38° |
| Largest step during movement release | 109.23° | 30.38° |
| Crouch exit boundary | 111.65° | 5.86° |
| Right punch exit boundary | 85.99° | 10.07° |
| Largest step anywhere, including fast attacks | 111.65° | 59.97° |

These are regression bounds on this fixture, not biological targets or proof
that every animation now looks natural. Fast strikes and the compact roll still
have rapid arcs. Full-rate human feel review and paired takedown remain pending.

| Final check | Result |
|---|---|
| Full mesh, three sizes, 30/60 Hz | 22,164 / 22,164; 50,243 vertices |
| Actual controller jump, both leads and all sizes/rates | 5,646 / 5,646 |
| Four-attack contact, recovery and support sole | 352 / 352 |
| Action transitions | 70 / 70 |
| Strike/evade/takedown action motion | 198 / 198 |
| Default / candidate gameplay mechanics | 309 / 311 |
| Existing posture and leg alignment | 10 / 10 |
| New continuity regression | 3 / 3; baseline fails |
| Editor import and default startup | Passed |

No contact, clearance, posture or floor tolerances were relaxed in this pass.
The unchanged 2.0 lintel clears at all sizes. Final all-mesh checks include the
new transition layer and foot-height correction. Headless system-CA, user-log
and editor-settings write warnings are preserved separately from game assertions;
there are no final script/resource errors.

## Iteration findings and remaining limits

An early bridge merely shifted a large guard movement later in windup. That was
rejected and the guard curve was revised. Reducing the guard's contact fold failed
the existing fist-separation check, so its calibrated contact fold was restored.
The earlier rendered source `20260910T211101Z-upper-body-4312ab` remains pinned.
`20260910T211413Z-upper-body-2f854f` is the intermediate reviewed motion; the final
capture includes the completed regression script and source comments.

The first jump check found six 60 Hz preparation samples with hovering soles,
up to 0.08654 units. Releasing the previous gait's contact lift during grounded
jump phases fixes that regression; the final check passes without changing its
limit. The original failure log is retained as `logs/jump.log`.

Existing stride foot sliding, stylized hands/hair, quick attack timing and the
primitive guard remain visible limitations. Hurt/downed/vault have mesh/mechanics
coverage but are not separately featured in this matched reel. The earlier
upper-body-only visual verdict is superseded by this broader review; user
acceptance of fluidity is still pending.

## Native handoff

Managed live run `20260910T211830Z-live-d9c704`, PID **55861**, was acquired as
`org.godotengine.godot` with exact title **Gloam Courtyard Spike (DEBUG)**.
Its source matches the final rendered source and current tree. The prior exact
window was closed and absence confirmed before the managed renderer was started.

Native Q enter/exit, V, Space, C and R/0/F12 were exercised. Six original
image/state pairs have verified image hashes and no source drift. The V sidecar
captures preparation (`jump_t=0.01773`, still grounded), Space captures a left-punch
startup, and C captures evade with +4 Momentum. These are honest startup/smoke
observations; the dense reel supplies motion detail. The final reset has 100 health,
0 Momentum, guard 100, no active action, and the default camera. It is left open.

The local board is regenerated from the task records. Its existing rendered UI
policy gate remains separate from source checks, runtime checks and user acceptance.

Both generated boards pass `ROADMAP_CHECK_OK tasks=17`; all 12 tooling tests pass.
Curated evidence is approximately 12.6 MB, retaining six native originals and
selected matched motion frames alongside the compact animated previews.
