# Anatomical foundation provenance

The originating character-art request explicitly clarified on 2026-09-04 that
a suitable free, licensed generic human base is authorized beneath the project's
original suit, mask and cape. No franchise model/costume or purchase is allowed.
This supersedes the earlier pending external-base choice; it is not permission
to import unrelated third-party assets.

Selected from Blender Studio and community **Human Base Meshes v1.4.1**:

- Official listing: https://www.blender.org/download/demo-files/
- Official directory: https://download.blender.org/demo/asset-bundles/human-base-meshes/
- Exact archive: https://download.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip
- Official listing license: CC0, corroborated by the selected collection and
  archive metadata recorded below before authoring the exported candidate.
- Directory read on 2026-09-04 local: 50,643,039 bytes, timestamp 20-Jan-2026.

The selected anatomical foundation and subsequent dressed neutral source
direction are approved. Runtime release is still a separate gate. The archive,
license metadata and exact source remain preserved; generic third-party anatomy
is credited as such, not called wholly locally authored geometry. Original
clothing/design/rig adaptation are separate.

## Verified archive and selected-source metadata

- Archive SHA-256: `811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`
- Original blend SHA-256: `3c121505651140ceb4d69fd1d8923f7788ffadd81672f5be14845a5f2c75c137`
- Collection `Body Male - Realistic`: author **Dan Ulrich**, asset metadata
  license **CC0**, description: realistic scan data with multiresolution detail.
- Narrow initial body objects: `GEO-body_male_realistic` and its `.eye.L` / `.eye.R`.
- `Head (Animation) - Realistic`, also author **Dan Ulrich**, CC0, was inspected
  as an alternative but is **not used**. The derivative's head/neck are the
  continuous selected full-body anatomy, not a swapped separate head asset.
- Bundle README states all provided assets are public domain under CC0.
- The blend also retains an unrelated `License` text mentioning the CC-BY Rain
  Rig. That rig/stylized character is **not selected or imported**. The specific
  selected realistic collections and bundle README independently say CC0;
  do not misattribute or silently import unrelated content.
- Bundle inspection used `--disable-autoexec` / `use_scripts=False`. Narrow
  imports append named mesh objects only; donor animations/drivers/materials are
  stripped. Archive/source remain intact under the ignored `reference/` folder.

`review_foundation.py` preserves the earlier unrigged anatomical study with
plain clothing-color coverage. `generate_v4.py` is the dressed candidate's
entry point. It imports only the selected body and two eye meshes, applies
bounded original proportions/clothing treatment, and builds our own rig and
costume; no donor animation or unrelated rig is exported. Acceptance evidence
and remaining limits belong to `README.md` and the project checkpoints.
