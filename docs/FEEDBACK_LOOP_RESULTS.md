# Feedback-loop experiment — 2026-09-08

This implements the user-approved source control, preservation and iteration
improvements. Character art and motion acceptance remain with the user; the
realism owner's leg-tracking checkpoint was preserved separately as `5bfd290`.
The prior source baseline is `b176305`.

| Experiment | Observed result | Limit |
|---|---|---|
| Same-build locomotion control | Two frozen `b176305` runs produced 210/210 byte-identical PNG frames. Total time 21.056 and 19.662 seconds, including fresh import and preview generation | Two local runs demonstrate repeatability here, not a universal speedup or visual acceptance |
| Different code, same GLB | `b176305` versus `5bfd290`: 210/210 frames changed with the same asset SHA and matched fixture; comparison source hashes differ | This demonstrates sensitivity to rig-code changes, not user acceptance |
| Action keyframe experiment | Uniform sampling missed the evade; phase selection now visibly includes strike contact, inverted tuck and paired takedown. The first and corrected contact sheets are retained | Phase selections belong to this fixture; revisit them if timings change |
| Review identity and F12 | Normal-renderer smoke saved PNG plus code/asset identity, camera, state and recent-input JSON; image hash matched; no changed source files | Automated capture is explicitly not native-input acceptance |
| Existing-renderer refusal | Corrected a bug that missed relative `--path .` launches; the lease then refused PID30109 without stopping it | Other agents must cooperate with the lease; an unmanaged process can still start later |
| Legacy compaction | 28,553 eligible PNG paths verified against their original hashes. 4,308 duplicate aliases shared. 104 silent WAVs archived; one restored exactly. Net redundant bytes removed: 1,068,264,400 | Unique historic images remain local; this is not a full-cloud backup or net disk-space measurement after adding new review runs |
| Private milestone recovery | Downloaded the 23,179,636-byte R7/R12 archive from GitHub; verified/restored all13 files; both GLBs match their local originals | Source history archive, not a game release |
| Current-state reading | `PROJECT_STATE.md` reduced from471 to92 lines at migration; exact original text and hashes retained | Reading reduction is measured; agent reasoning-time savings are not yet measured |
| Local board | One task data block generates both board pages; current decision index generates its decision view | Rendered interactions and responsive layouts remain URL-policy-blocked |

Control evidence: `evidence/2026-09-08-feedback-loop-control/experiment.json`,
paired previews and full manifests in the same directory. Preservation evidence:
`evidence/2026-09-08-preservation-experiment.json` and `evidence/archive-catalog.json`.
The local F12 smoke is `captures/review_87d1bee6a418_30344_2491396.png` plus JSON.

The12 tooling tests pass, including bad logs, relative-path renderer detection, changed preservation plans, unsafe paths, retention safety, missing evidence and duplicate task IDs. Godot imports the optional debug scripts cleanly. The277-frame action runner completed in27.696seconds with the expected success marker. Board scripts compile, IDs are unique and generated source/wrapper parity passes.

The workflow now fails on script errors even if Godot returns exit0, missing
completion markers, unexpected frame counts, candidate hash mismatch, mismatched
comparison setup, changed artifact plans or damaged preserved evidence. Negative
tests exercise these failure classes where implemented; actual captured and
restored output supports the successful paths.

## Operational decision

Use the small matched visual review first, then inspect actual motion at gameplay
scale. Expand to the relevant mechanical/deformation tests after that direction
looks better. Record the rejected outcome as well as the accepted one. A technical
pass leaves `visual_verdict` unreviewed; only an explicit review records acceptance.
Use ordinary native smoke and user judgement for release, and quiet sequential
normal-renderer measurement for performance. Do not interpret MovieWriter cadence
or headless checks as those gates.

The board browser attempt in this session was explicitly rejected by Browser Use
URL policy for the local file. No workaround was attempted. Static generation and
syntax checks are recorded separately; `board-ui` remains Waiting.
