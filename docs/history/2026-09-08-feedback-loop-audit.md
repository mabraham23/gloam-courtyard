# Gloam feedback-loop review — 8 September 2026

The best opportunity is to shorten the path from a reported visual problem to a trustworthy comparison, while making each reviewed build recoverable. The project already has substantial testing and evidence preservation. More validation volume alone will not solve the repeated mismatch between technical success and the user's visual judgement.

This is a read-only project audit for discussion. No game source, assets, project docs, board, memory, processes, automations, or other tasks were changed. This report is stored outside the game folder. The realism task was active during inspection, so file counts and status are a snapshot. Gameplay was not relaunched or independently retested.

I reviewed the five core project documents, relevant runtime and verification code, archive layout, evidence reports, the five main user-facing project histories, and related implementation-session outcomes. I indexed the September project session logs and sampled relevant tool failures and audits. I did not inspect every captured frame or every historical tool result. Historical runtime results below are attributed to their recorded evidence.

**Observed baseline**

| Observation | Evidence and qualification |
| --- | --- |
| No Git repository in this checkout | `git status --short` returned “not a git repository”; the project has no `.git`, `.gitignore`, or `.gitattributes`. Other backups were not assessed. |
| Five core docs total 2,133 lines | PROJECT_STATE 435, UPCOMING_TASKS 277, DECISIONS 280, CHECKPOINTS 1,019, feedback-loop guide 122; approximately 208 KB altogether. |
| Capture preservation is extensive | At inventory: 29,730 PNGs; the whole captures folder was approximately 4.69 GB. It also contains 108 WAVs and one AVI. This is a storage/retrieval observation, not evidence of an FPS problem. |
| Current status is more recent than memory | Current docs describe R14 awaiting user judgement with V1 default. The saved memory summary described R7. Current docs governed this audit. |
| Historical appearance and motion evidence can disagree with technical gates | V2/r4 art was rejected despite 2,763 passing checks; three procedural gait revisions were rejected despite numerical gates. [rejected scaffold](/Users/markabraham/dev/batman/docs/UPCOMING_TASKS.md:185), [gait decision](/Users/markabraham/dev/batman/docs/DECISIONS.md:172). |
| Context retrieval is substantial | The Character Realism Roadmap session contained 35 recorded compactions when inspected. That demonstrates a long working history; it does not establish how much time compaction itself cost. |

**1. Preserve complete playable revisions — highest priority for history and safe iteration**

The R7 archive contains a GLB, a Blend file, and a manifest. It contains no historical controller, rig adapter, motion code, or fixture snapshot. Those runtime components subsequently changed while the same R7 GLB hash remained fixed. Some audits thoughtfully recorded controller hashes, but a hash identifies content; it cannot restore the content by itself. [Archive](/Users/markabraham/dev/batman/actors/gloam_vigil/v4/revisions/r7/manifest.json), [historical code fingerprints](/Users/markabraham/dev/batman/work/action-quality/coverage.md:13).

Recommendation: introduce local Git for source, scene/config files, authoring recipes, tests, and docs, with meaningful checkpoint commits. Pair commits with the existing hashed binary asset archives and an explicit evidence manifest. Decide how the binary archives and captures are backed up; Git on the same drive is not a separate backup. Preserve existing files and rejected revisions. Do not attempt to invent historical commits from today's files.

Each review should record code revision, local modifications if any, asset hash, motion-data hash, fixture version, and engine/render configuration. A frozen review should use a stable snapshot even if the working folder continues changing.

This enables actual comparisons and rollback instead of reconstruction from session patches. Version recall and change comparison are standard version-control capabilities. [Git documentation](https://git-scm.com/book/en/v2/Getting-Started-About-Version-Control).

Acceptance for this improvement: restore one newly recorded checkpoint into an isolated folder and reproduce its named scenario and evidence fingerprint.

**2. Put a short visual rejection screen near the start of each iteration — highest priority for quality**

There is direct evidence that the review setup sometimes concealed the reported defect. The September 5 gait audit found that a supposedly sustained sequence reached the world clamp around frame 81, and that its “profile” view was not perpendicular to actual travel. It also found diagnostics still encoding the rejected gait's cadence/contact windows. Those issues were subsequently addressed; they are evidence for keeping fixture validity explicit, not claims that today's fixture still has those defects. [Gait audit](/Users/markabraham/dev/batman/work/action-quality/2026-09-05-r7-gait-acceptance-audit.md:17).

Your feedback repeatedly returned to walking on September 5 and again on September 8. The later investigation identified rotation redistribution across bones with different pivots, a more specific cause than simply excessive sideways motion. [Current checkpoint](/Users/markabraham/dev/batman/docs/CHECKPOINTS.md:69).

Recommendation: before broad polish and release testing, make one short comparison for one stated visual question. Use the same camera, lighting, input sequence, timing, and body preset for baseline and candidate. Include ordinary gameplay scale and a true front/profile diagnostic angle. For movement, review continuous motion at normal speed before using slow motion to diagnose it.

State observable rejection criteria: knee tracking, planted-foot movement, torso balance, hand shape, contact timing, readable recovery. Keep numerical checks as guardrails. If successive variations fail the same criterion, revisit source motion, retargeting, or reference choice before another parameter pass.

This is an internal early screen and can run unattended. It does not require interrupting the user for approval after every adjustment. User judgement remains a final gate for the surviving candidate.

Acceptance: the next pass produces a baseline/candidate comparison and a documented keep/reject reason before its broad release suite.

**3. Make the existing review machinery callable through one small runner**

The checkout already contains real-controller movement sequences, four-attack sequences, target-free strike checks, transition checks, and dense deformation gates. The opportunity is to package them, rather than build another framework. The command catalog is spread across the candidate README, action coverage audit, and individual scripts. [Candidate runbook](/Users/markabraham/dev/batman/work/character-art-review/README.md:18), [suite catalog](/Users/markabraham/dev/batman/work/action-quality/coverage.md:206).

Recommendation: a thin project-local runner with named scenarios such as run/start/stop, attack/whiff/recovery, evade, and paired takedown. It should select a frozen revision, perform necessary import/setup, run the existing fixture, collect exit codes and script errors, and return a compact comparison plus result metadata. Treat the command shape as a proposal, not an existing feature.

Separate quick iteration checks from the existing final acceptance gates. Select focused checks from changed dependencies; run the required broad regression and live review before completion. Preserve the paired performance protocol when performance validation is needed. Significant animation processing changes can affect CPU cost even if mesh counts stay constant.

Godot already supports bounded movie output and fixed recording FPS. Its documentation distinguishes that output from real-time gameplay recording and notes that PNG sequences cost storage and encoding time. Keep those modes clearly labelled. [Godot movie documentation](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html).

Acceptance: one invocation produces a valid, correctly labelled comparison and a readable failure when camera/path/candidate checks fail. Measure edit-to-first-review time over several iterations before claiming a speedup.

**4. Attach player feedback to the exact run, and give the live window one owner**

The September 5 conversation explicitly included uncertainty about whether the user was playing the newest build. Earlier user feedback also asked why multiple Blender/Godot windows kept opening. The existing launch runbook documents stale Project Manager recovery, and the candidate launcher prints only the asset hash while loading current runtime code. [Live launcher](/Users/markabraham/dev/batman/work/character-art-review/live_review.gd:10), [launch protocol](/Users/markabraham/dev/batman/docs/visual-feedback-loop.md:5).

Recommendation: show a small debug-only build identifier and default/candidate label, and add an F12 sidecar containing code/asset identity, camera, body preset, action/phase, position, health, Momentum, and relevant random seed. A later optional feedback marker could retain a short input/state history. First prove replay reliability; input history alone does not guarantee deterministic reproduction.

Have one declared owner of the visible game and serialize capture/performance jobs against it. A small ownership record can state task, PID, project, build, and purpose. Validate a process before acting on an old PID. The existing exact-title and fresh-handoff checks should remain.

The runbook records 1.1–1.5-second screenshot latency against a 0.42-second evade window. That is a historical measurement, not a new latency test. Automated scenarios can cover timing; native keyboard review and human feel remain separate. [Timing limitations](/Users/markabraham/dev/batman/docs/visual-feedback-loop.md:47).

Acceptance: a reported bad pose can be associated with the exact build and action frame without another “which version is open?” exchange.

**5. Make current truth short, and history explicitly linked**

PROJECT_STATE includes more than 240 lines under preserved R7-to-R14 history. UPCOMING_TASKS includes several preserved plans. Some older wording is still operationally misleading: PROJECT_STATE advertises automation-friendly WASD taps while the current runbook says zero-time taps add no displacement; the runbook still describes one 0.36-second SPACE swing even though the current attack set contains four timings. [State wording](/Users/markabraham/dev/batman/docs/PROJECT_STATE.md:309), [runbook wording](/Users/markabraham/dev/batman/docs/visual-feedback-loop.md:59), [attack catalog](/Users/markabraham/dev/batman/actors/player_attack_catalog.gd).

Recommendation: keep PROJECT_STATE to a short current-state page and UPCOMING_TASKS to the active queue/dependencies. Move preserved narratives into dated history documents with an index and links, preserving all content. Keep checkpoint evidence authoritative.

Give decisions stable IDs and explicit partial-supersession links. For example, the separate walk/run decision and the one-speed decision are both titled Active, although the latter supersedes only the former's control policy. Preserve the still-valid held-input rule separately. [Decision pair](/Users/markabraham/dev/batman/docs/DECISIONS.md:235).

Record a compact decision unit: user request and source task/date, reason, scope, what it supersedes, acceptance criterion, and relevant evidence/build. For rejected visual approaches, record what was visibly wrong and what would justify revisiting them. This preserves useful learning without forcing every new agent to replay the entire conversation. Keep project history in the project; assistant memory should be a discovery aid, not its authority or only copy.

Acceptance: a fresh reviewer can identify current controls, candidate/default, last user rejection, owner, and next gate from a short starting page, then follow links for detail.

**6. Index evidence and generate board facts once**

Capture files are preserved, but the capture directory has no central manifest or index. Names include several long “final” sequences and suffixes such as “final5”; current/rejected status lives elsewhere. Some historical scripts now import the shared current candidate fixture, so a retained script name alone does not recreate the historical run. [Example fixture selection](/Users/markabraham/dev/batman/work/action-quality/attack_combo_sequence.gd:9).

Recommendation: give each new run a unique directory with metadata, raw evidence, a short review clip/contact sheet, and status: diagnostic, rejected, superseded, technically passed, or user accepted. Index old captures in place; do not rename or discard them as part of the first step. Keep raw images for accepted evidence and defect diagnosis.

The board is currently another manually authored statement of task facts. Its Python generator escapes the HTML source into a wrapper; it does not derive status from authoritative docs. [Task data](/Users/markabraham/dev/batman/work/project-roadmap.html:453), [generator](/Users/markabraham/dev/batman/work/generate_project_roadmap_local.py:6).

Keep task metadata in one authoritative location, preferably structured fields within the existing upcoming-task document, and generate the board from those fields. Let checkpoints supply linked evidence instead of copying test counts into several narratives.

The historical browser-policy blocker has kept gameplay milestones entangled with board UI acceptance. Propose separate gameplay, evidence, and board-delivery status fields; changing that completion rule would be an explicit project-agreement decision. Continue reporting an unverified board honestly. Do not rerun responsive-layout QA for an unchanged layout merely because a gameplay checkpoint changed; retain full UI checks for relevant board changes under the revised agreement.

Acceptance: one status update produces a consistent board, missing evidence links are reported, and rejected runs cannot appear as the accepted baseline.

**Suggested first experiment**

Start with one narrow package: a recoverable source checkpoint, one existing movement scenario exposed through a runner, and a small baseline/candidate comparison manifest. Include a build label in the review output. Avoid a large game-code reorganization while realism work is active.

Track edit-to-first-review time, repeated setup attempts, time spent reconciling docs/board, and whether the same visual defect returns at user review. No percentage speed improvement is established by this audit. Those measurements would tell us which proposed changes actually help.

The existing strengths should survive: source provenance, preserved rejections, fixed gameplay contracts, real renderer evidence, explicit helper/native distinctions, independent visual review, and a fresh verified game left ready for play.


**Session evidence used for the review**

- [Gothic Game Visual Direction: request for a tighter capture loop and a durable project spine](/Users/markabraham/.codex/sessions/2026/09/03/rollout-2026-09-03T16-47-06-01a06974-531c-70b3-af7c-a894f68850e2.jsonl:1069).
- [Gloam project board and playtest: user asks the agent to relaunch finished work](/Users/markabraham/.codex/sessions/2026/09/03/rollout-2026-09-03T20-01-57-01a06a26-b855-7e40-b621-b19b6343f33e.jsonl:2001).
- [New voice chat: repeated Blender/Godot windows reported](/Users/markabraham/.codex/sessions/2026/09/04/rollout-2026-09-04T15-07-58-01a06e3f-ebfc-7d51-a811-9e74d47f0627.jsonl:1241).
- [Natural Movement Pass: uncertainty about which version was being played and repeated gait rejection](/Users/markabraham/.codex/sessions/2026/09/05/rollout-2026-09-05T11-41-46-01a072a9-81ad-70a1-826e-418d384a13d2.jsonl:398).
- [Natural Movement Pass: September 8 follow-up on lateral leg flare](/Users/markabraham/.codex/sessions/2026/09/05/rollout-2026-09-05T11-41-46-01a072a9-81ad-70a1-826e-418d384a13d2.jsonl:1488).
- [Natural Movement Pass: explicit one-speed design reversal](/Users/markabraham/.codex/sessions/2026/09/05/rollout-2026-09-05T11-41-46-01a072a9-81ad-70a1-826e-418d384a13d2.jsonl:2258). This is a user preference change, not evidence that implementing the earlier requested walk/run split was an error.

Session links are local raw JSONL histories. The relevant entries are linked by line; the full files can be large.
