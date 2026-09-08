#!/usr/bin/env python3
"""Strict static export gate for the non-default Gloam Vigil v3 candidate."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = PROJECT_ROOT / "actors/gloam_vigil/v3/gloam_vigil_player_v3.glb"
CHECKER_PATH = PROJECT_ROOT / "work/character-quality-benchmark/check_glb_export.py"
MAX_TRIANGLES = 90_000


def load_checker():
    spec = importlib.util.spec_from_file_location("gloam_glb_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load checker: {CHECKER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    if not CANDIDATE.is_file():
        print(f"GLOAM_V3_GLB_CONTRACT_FAIL missing file: {CANDIDATE}", file=sys.stderr)
        return 2
    checker = load_checker()
    args = checker.parser().parse_args(
        [
            str(CANDIDATE),
            "--expect-joints=74",
            "--expect-surfaces=7",
            "--expect-materials-used=5",
            "--require-normal-maps",
            "--min-normal-map-size=1024",
            "--expect-normal-maps=5",
            "--min-morph-targets=4",
            "--expect-morph-name=blink.L",
            "--expect-morph-name=blink.R",
            "--expect-morph-name=brow_inner_raise",
            "--expect-morph-name=jaw_clench",
        ]
    )
    report, audit = checker.audit_export(CANDIDATE, args)
    # The approved allocation has an upper bound but deliberately no minimum:
    # topology quality and runtime deformation matter more than spending tris.
    audit.require(
        report["triangles"] <= MAX_TRIANGLES,
        f"triangles {report['triangles']} exceed approved maximum {MAX_TRIANGLES}",
    )
    print("GLOAM_V3_GLB_CONTRACT_REPORT " + json.dumps(report, sort_keys=True, separators=(",", ":")))
    if audit.errors:
        for error in audit.errors:
            print("FAIL " + error, file=sys.stderr)
        print(f"GLOAM_V3_GLB_CONTRACT_FAIL errors={len(audit.errors)}", file=sys.stderr)
        return 1
    print("GLOAM_V3_GLB_CONTRACT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

