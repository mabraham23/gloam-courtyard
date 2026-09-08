# Source and artifact preservation

The private repository is [mabraham23/gloam-courtyard](https://github.com/mabraham23/gloam-courtyard).
`main` is the recoverable checkpoint branch. Commit one coherent change with its
evidence and remaining acceptance gates; push after validation. Inspect other
owners' edits before staging. Never use `git add -f` to bypass artifact exclusions
without deliberately revising this policy.

| Tier | Preserve | Location / lifetime |
|---|---|---|
| Current source | Runtime scripts/scenes/assets, current editable source, licenses, exact motion sources, tests, docs and small curated evidence | Git; meaningful commits, no rewritten history |
| Selected milestone | Accepted baseline or rejected direction whose source explains a decision; model/source/renders plus per-file SHA manifest | Private GitHub milestone archive, listed in `evidence/archive-catalog.json` |
| Curated review | Question, before/after identity, fixture/engine/seed/camera, preview, original keyframes, logs, technical result and human verdict/reason | `evidence/`; aim for <=10 MB per ordinary review and <=50 MB total before reviewing growth |
| Raw managed run | Numbered lossless frames, movie sidecar, frozen source and import cache | Ignored raw frames in `work/review-runs/`; retain latest 3 and at least14 days. Clean source checkouts/import caches are disposable after capture because the exact Git commit is retained. |
| Legacy history | Unique old captures, rejected spikes and intermediate source not selected for remote preservation | Local; no automatic unique-image deletion. Historical PNG paths still resolve |

Do not commit `.godot`, raw captures, downloaded reference bundles, studio scratch,
generated movie audio or redundant model exports. BVH and original log bytes are
not line-ending-normalized because provenance may depend on their exact hashes.
GitHub is a backup for the tracked source and selected archive, **not the entire
local capture history**. `.artifacts/compaction.json` and silent-audio archives are
local recovery data and should travel with a full machine backup.

## Capture selection

Before a change, state one visual question and preserve the last accepted or
rejected baseline relevant to that question. Use the same scenario for before and
after. Curate one compact review with a reason; avoid keeping every near-identical
preview as another Git revision. Preserve original keyframes for close inspection:
the animated WebP is a lossy, fixed-step review aid, not performance evidence.

```sh
python3 tools/review.py curate work/review-runs/RUN_ID \
  --output evidence/DATE-QUESTION --verdict diagnostic \
  --reason 'Describe the observation and what still needs user judgement'
python3 tools/feedback/retention.py
```

Retention is dry-run-first. `--apply` removes old raw frames only after the curated
manifest and every preserved file pass their recorded hashes. Uncurated evidence,
the latest three runs and pinned runs are retained. Set `"pinned": true` in a run
manifest to protect an active investigation. Completed diagnostic import caches are removed. Clean source snapshots are recreated from their immutable Git commit. Dirty source snapshots are never
automatically removed; commit or deliberately preserve their unique source first.
Metadata, logs and curated reviews survive raw-frame expiry. Retention does not
touch legacy `captures/`, original actors or production files.

## Lossless legacy compaction

The completed experiment shared only byte-identical PNGs using immutable hard
links, retaining every old name and exact bytes. Silent PCM WAVs were gzip archived,
verified and recorded before removing the raw copy. Unique PNGs were not removed.
Never overwrite an archived capture prefix; managed runs have unique IDs.

```sh
python3 tools/feedback/artifacts.py inventory
python3 tools/feedback/artifacts.py compact --plan .artifacts/capture-inventory.json
python3 tools/feedback/artifacts.py restore-audio captures/OLD_NAME.wav
```

Compaction needs an explicitly reviewed inventory and `--apply`; run it only after
the capture owner finishes. The initial experiment excluded captures newer than
one hour and verified all eligible PNG hashes afterward. A changed file causes
validation to fail instead of silently deleting newer evidence.

## Milestone recovery

The selected R7/R12 archive is 23.18 MB and includes 13 files. It was downloaded
back from the private release, fully verified and restored; both GLBs match their
original local hashes. The archive does not reconstruct missing historic code or
claim that an old candidate was accepted as a complete game.

```sh
gh release download preservation-2026-09-08 --repo mabraham23/gloam-courtyard \
  --pattern gloam-history-r7-r12.zip --dir /path/to/download-directory
python3 tools/feedback/archive.py verify /path/to/download-directory/gloam-history-r7-r12.zip \
  --restore-to /path/to/new-restore-directory
```

Restoration validates all names, sizes and SHA-256 hashes before writing, requires
a new destination and never overwrites production source. Other historical unique
assets remain local. Add an archive only for a documented milestone, not every
intermediate export; `evidence/archive-selection.json` records the current choice.
