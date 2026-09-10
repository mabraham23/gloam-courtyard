# Upcoming tasks

`PROJECT_STATE.md` owns present truth. This file owns execution order and the
structured task records below. The local board is generated from these records;
edit this file, then run `python3 work/generate_project_roadmap_local.py`.

## Immediate review

The new upper-body pass is ready for user movement judgement: try held WASD,
Q crouch and crouch travel, standing/moving V, and repeated Space strikes.
Review the subtle back curve, shoulder following, jump catch and hip-to-chest
punch transfer. Full validation and an enlarged fresh native reset are complete;
source `3e4bb12bca1b`, PID 54186. This remains the R14 candidate, with V1 default.

The rebuilt swept haircut, clean-shaven face, inward crouch arms and earlier
jump elbow correction are technically verified and open for user review. The
second bowl-like cap was rejected; check the broad sweeps/fade from multiple
angles, stationary Q and held crouch movement.
Play stationary V, held WASD then V, repeated moving jumps and landing back into
held movement. R14 appearance, continuous held gait and paired takedown also keep
their existing acceptance gates; V1 remains default.
The next default switch depends on user acceptance, not on more numerical counts.
Further flight/contact polish or hair detailing requires bounded follow-up scope
if the user rejects the corresponding visual result.

Runtime completion, user acceptance and board UI verification are distinct. The
board's policy blocker is tracked once as `board-ui`; it does not turn completed
gameplay fixes back into unfixed bugs. Overall board handoff remains pending.

Riven integration and the intended W/S convention remain explicit future choices.
Do not start them from a historical roadmap row. Active code ownership stays with
the realism task; review tooling and board generation have separate file homes.

## Task records

The generator validates unique IDs, required fields, known lanes and existing
evidence paths. This block is authoritative; generated HTML is not edited by hand.

<!-- roadmap-data:start -->
```json
{
  "schema": 1,
  "summary": "Natural upper-body motion ready for review: subtle back curve, shoulder response and sequenced punches. Native reset open; R14 candidate, V1 default.",
  "tasks": [
    {
      "id": "upper-body-motion",
      "lane": "waiting",
      "area": "Animation",
      "title": "Natural upper-body motion \u00b7 user review",
      "effort": "M",
      "parallel": "Matched 480-frame review and full validation passed",
      "dependency": "User whole-body naturalness and held movement judgement",
      "owner": "Current upper-body refinement task",
      "evidence": "Full mesh 22164, jump 5646, attacks 352, transitions 70, action 198, mechanics 309/311, alignment 10. Seven native image/state pairs; final source 3e4bb12bca1b, PID 54186.",
      "description": "Subtle thoracic curve and stride counter-rotation, shoulder/head following, jump chest response and hip-to-chest punch timing. Fixed large-crouch cape clearance; revised former flat-chest taste bounds explicitly. Fresh native reset open; V1 remains default.",
      "evidence_paths": [
        "evidence/2026-09-10-upper-body-motion/README.md",
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "short-black-hair",
      "lane": "waiting",
      "area": "Characters",
      "title": "Swept haircut and fade \u00b7 user review",
      "effort": "S",
      "parallel": "Matched crouched profile, full motion and native smoke passed",
      "dependency": "User accepts the rebuilt silhouette and clean-shaven face",
      "owner": "Current appearance refinement task",
      "evidence": "Matched 270-frame review including closer crouched profile; rig 456, full mesh 22164 over 50243 vertices. Native Q/V/C and reset/F12, source 6b51a2c0db0c, PID 52046.",
      "description": "Second bowl-like cap rejected. Close-clipped fade with two broad central sweeps and lower side sections; uneven fringe and clean shave retained. Fresh reset game left open; V1 remains default.",
      "evidence_paths": [
        "evidence/2026-09-10-swept-hair-silhouette/README.md",
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "crouch-arms",
      "lane": "waiting",
      "area": "Animation",
      "title": "Relaxed crouch arms \u00b7 user review",
      "effort": "S",
      "parallel": "Rendered and native crouch checks passed",
      "dependency": "User crouch silhouette and movement judgement",
      "owner": "Current crouch refinement task",
      "evidence": "Matched front/profile/gameplay; signed inward geometry; transitions 70, mechanics 311, full-mesh crouch 1083. Native Q/F12/reset, source 0a91576169a3, PID 46972.",
      "description": "Forward-folded elbows and inward hands with relaxed shoulders and small travel counter-swing. Crouch clearance, speed, jump and frozen assets retained. User acceptance pending.",
      "evidence_paths": [
        "evidence/2026-09-10-crouch-arms/README.md",
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "vertical-jump",
      "lane": "waiting",
      "area": "Animation",
      "title": "Jump elbow direction \u00b7 user review",
      "effort": "M",
      "parallel": "Signed direction regression and native smoke passed",
      "dependency": "User corrected running-jump and landing judgement",
      "owner": "Current jump refinement task",
      "evidence": "Old signed elbow check fails 12 moving cases; corrected full-mesh 5646, mechanics 309/311, transitions 67 pass. Native V/Q/F12/reset, source 2dfc70da70c6, PID 46188.",
      "description": "Forearms now fold forward through the jump. Prior backwards elbow pose rejected. Alternating leads and deeper landing catch retained; held moving user review pending.",
      "evidence_paths": [
        "evidence/2026-09-10-jump-elbow-direction/README.md",
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "action-readability",
      "lane": "waiting",
      "area": "Animation",
      "title": "Action presentation \u00b7 user action review",
      "effort": "M",
      "parallel": "Runtime passed; user review pending",
      "dependency": "User movement and paired takedown judgement",
      "owner": "Parent \u00b7 controller/builder/adapter; independent test audit",
      "evidence": "Mechanics200/202, target-free254, four attacks352, action motion198 and deformation21642; historical reels and native limits in CHECKPOINTS.",
      "description": "Four target-free strikes with commit-owned contact, forward evade and paired takedown are technically verified. Close-up fingers and action feel remain review items.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "gloam-vigil-player",
      "lane": "complete",
      "area": "Characters",
      "title": "First Gloam Vigil runtime baseline",
      "effort": "L",
      "parallel": "Complete runtime checkpoint",
      "dependency": "None; board UI tracked separately",
      "owner": "Parent integration owner",
      "evidence": "511 deformation and107 mechanics checks; native customization, stealth, traversal, camera and reset in the preserved checkpoint ledger.",
      "description": "V1 remains the playable default and a recoverable baseline. Its runtime acceptance does not establish the final realism goal.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "vigil-sculpt-quality",
      "lane": "waiting",
      "area": "Characters",
      "title": "R14 face/hair candidate \u00b7 user visual judgement",
      "effort": "L",
      "parallel": "Frozen candidate",
      "dependency": "User accepts gameplay-scale appearance and motion",
      "owner": "Character realism owner",
      "evidence": "R14 GLB30a2c06\u2026; rig451, deformation21642 and imported/studio review. Exact source and acceptance limits in PROJECT_STATE.",
      "description": "Warm skin and clean-shaven face on original costume/CC0 anatomy. Current runtime uses broad swept black hair with faded sides/back; frozen R14 retained. User appearance judgement pending; V1 stays default.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "vigil-authored-motion",
      "lane": "waiting",
      "area": "Animation",
      "title": "R14 corrected gait \u00b7 user held-movement review",
      "effort": "L",
      "parallel": "Technical correction complete",
      "dependency": "User held movement and action feel",
      "owner": "Character realism owner: rig, controller, native handoff",
      "evidence": "Full-cycle six cases, stance365, mechanics200/202, deformation21642; report2026-09-08-r14-leg-tracking.md. Ankle mean/max0.239/0.249 authored units.",
      "description": "Grounded ankle lanes now follow hip span and knees track forward. Root speed remains4.80; Shift is inert; crouch1.178. Standing/moving jump refinement is tracked separately; gait flight, sliding and wider action stance remain polish limits. No new performance certificate after the solver change.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "vigil-performance",
      "lane": "complete",
      "area": "Project",
      "title": "Historical R14 paired performance certificate",
      "effort": "M",
      "parallel": "Technical gate complete",
      "dependency": "Repeat only for a material performance question after changes",
      "owner": "Verification owner \u00b7 work/character-art-review/performance.gd",
      "evidence": "Quiet1080p courtyard R14 mean/p95/p99=5.0999/6.7529/7.1777ms before the leg solver change; exact protocol in the appearance-action-performance report.",
      "description": "Preserved measurement of the earlier exact build. It is not a new certificate for the leg solver, an enemy-count promise or a GPU ceiling.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "vigil-v2-integration",
      "lane": "waiting",
      "area": "Characters",
      "title": "Release R14 after user acceptance",
      "effort": "L",
      "parallel": "Sequential",
      "dependency": "User appearance, held movement and paired takedown acceptance",
      "owner": "Integration owner: narrow default switch",
      "evidence": "Technical candidate gates in CHECKPOINTS; default remains V1.",
      "description": "Preserve rejected and superseded source. After acceptance, switch the default narrowly, regress the actual default and leave fresh exact-title native/F12 evidence.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "guard-hit-label",
      "lane": "complete",
      "area": "Gameplay",
      "title": "Guard health label updates during stun",
      "effort": "S",
      "parallel": "Runtime complete",
      "dependency": "None; board UI tracked separately",
      "owner": "Parent \u00b7 main_3d.gd",
      "evidence": "Contact-time label checks and live GUARD78 evidence in the preserved ledger.",
      "description": "Strike and perfect-counter health text refresh immediately, including while stunned; damage and reset remain unchanged.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "movement-sign-review",
      "lane": "later",
      "area": "Gameplay",
      "title": "Review the intended W/S direction convention",
      "effort": "S",
      "parallel": "Review only \u00b7 no movement change authorized here",
      "dependency": "Confirm desired camera-relative forward/back convention",
      "owner": "Gameplay owner \u00b7 preserve accepted timing and movement metrics",
      "evidence": "Live default-view S taps moved up-screen and W down-screen. Existing held and tap paths both use negative camera basis.z multiplied by input.y. Camera-relative transformation works; intended sign convention was not decided.",
      "description": "Recheck the intended control convention before a bounded fix. This observation predates any new movement change; the character milestone deliberately left controls and gameplay code unchanged.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "animation-polish",
      "lane": "complete",
      "area": "Animation",
      "title": "Animation polish and action variants",
      "effort": "M",
      "parallel": "Complete",
      "dependency": "Verified crouch and jump/vault dimensions",
      "owner": "Actor-visual/pose owner \u00b7 actors/character_visual_builder.gd only",
      "evidence": "204-frame default-camera sequence, complete mechanics regression, fixed-step grapple timing, dedicated finite-transform/silhouette probe, and fresh live crouch/evade/jump/strike/camera/reset/F12 smoke passed",
      "description": "Sharper grapple handoff, evade landing, crouch weight, jump/vault distinction, strike/counter impact, and warden telegraph/reaction were added without controller or mechanic changes.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "riven-lantern",
      "lane": "complete",
      "area": "Level design",
      "title": "Riven Lantern Ward isolated gray-box",
      "effort": "L",
      "parallel": "Complete",
      "dependency": "Verified crouch and jump/vault movement envelope",
      "owner": "New non-default scene/script files only \u00b7 no default or controller edits",
      "evidence": "38 \u00d7 28 measurement validation, headless editor/runtime, two 960x600 normal-renderer overview frames, route layers, collision, and traversal-fit labels passed",
      "description": "A static, controller-free route study now captures ground, covered, elevated, concealment, loopback, and movement-envelope opportunities without claiming playable integration.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "map-integration",
      "lane": "waiting",
      "area": "Project",
      "title": "Choose Riven integration shape",
      "effort": "S",
      "parallel": "No",
      "dependency": "Animation-polish and isolated Riven evidence accepted",
      "owner": "Product/integration owner \u00b7 no default-file changes before the choice",
      "evidence": "Explicitly choose separate playable scene, Lower Court expansion/replacement, or retained static route reference; then define the matching controller, launch, smoke, and evidence scope",
      "description": "Deferred while the player visual milestone runs; no Riven role has been selected. Each integration shape changes the game structure and verification boundary.",
      "evidence_paths": [
        "docs/CHECKPOINTS.md"
      ]
    },
    {
      "id": "feedback-loop",
      "lane": "complete",
      "area": "Project",
      "title": "Reproducible reviews and source preservation",
      "effort": "M",
      "parallel": "Tooling isolated from gameplay",
      "dependency": "Rerun scenario after relevant changes",
      "owner": "tools/review.py, tools/feedback, debug; no controller changes",
      "evidence": "Repeat control210/210 identical frames; clean GitHub clone action277 and mechanics200/202. Native exact-title/F12 image-state handoff verified at PID32337. See FEEDBACK_LOOP_RESULTS.",
      "description": "Private Git, small curated evidence, verified milestone archive, immutable render snapshots and source/asset identity. Technical/visual/native verdicts remain separate.",
      "evidence_paths": [
        "docs/FEEDBACK_LOOP_RESULTS.md",
        "evidence/2026-09-08-github-recovery/recovery.json",
        "evidence/2026-09-08-native-review-handoff/observations.json"
      ]
    },
    {
      "id": "board-ui",
      "lane": "waiting",
      "area": "Project",
      "title": "Local board \u00b7 rendered UI verification",
      "effort": "S",
      "parallel": "Independent of game acceptance",
      "dependency": "Permitted local browser access or user manual review",
      "owner": "Board tooling owner",
      "evidence": "Source schema, generator parity and script syntax can be checked. The current file URL was rejected by Browser Use URL policy.",
      "description": "Verify all tabs, area filter, selected task details and narrow/wide layouts when permitted. Static checks do not prove rendered behavior. Do not bypass the recorded policy denial.",
      "evidence_paths": [
        "docs/FEEDBACK_LOOP_RESULTS.md"
      ]
    }
  ]
}
```
<!-- roadmap-data:end -->

## Completion and preservation

Update current state and checkpoint evidence first. Append a decision only when
its rule or rationale changes, including what it supersedes. Edit task records,
regenerate both local board files, and record rendered UI results separately.
Gameplay handoff still requires exact-title native smoke and a fresh reset/F12.

[Previous execution plans and full milestone history](history/2026-09-08-5bfd290/UPCOMING_TASKS.md)
are retained verbatim. [Preservation policy](PRESERVATION.md) covers raw evidence,
rejected variants, curated reviews, Git and milestone archives.
