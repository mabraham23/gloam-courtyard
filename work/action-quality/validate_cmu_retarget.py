#!/usr/bin/env python3
"""Validate the frozen R7 CMU walk/run retarget resources without Blender."""

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MOTION = ROOT / "actors/gloam_vigil/v4/motion"
SOURCE = MOTION / "cmu_16_45_run_jog.bvh"
WALK_SOURCE = MOTION / "cmu_16_31_walk.bvh"
TARGET = ROOT / "actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"
DATA = MOTION / "cmu_16_45_run_jog_retarget.json"
WALK_DATA = MOTION / "cmu_16_31_walk_retarget.json"

EXPECTED = {
    SOURCE: "6c179f799f3b2f766ce41cf962caaae08d9342ce73fc32fbc15648bf6589e872",
    WALK_SOURCE: "a655ee2e91ee516ccd91523f1537276e39e0b0abaa5cfc7f531c4f2f567d5088",
    TARGET: "30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b",
    DATA: "d38ee01e6a0622259afa19694528f680b53ad2eb89973a1b11c5ea53a2f11513",
    WALK_DATA: "9991be7a95615312d98a0b0d7468529177425214484d9c42efdb37ee67ba29a7",
}
REQUIRED_CHANNELS = {
    "pelvis", "spine", "spine_upper", "chest", "neck", "head",
    "clavicle.L", "clavicle.R", "upper_arm.L", "upper_arm.R",
    "forearm.L", "forearm.R", "hand.L", "hand.R",
    "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
    "ball.L", "ball.R", "toe.L", "toe.R",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require(ok: bool, label: str) -> None:
    if not ok:
        raise AssertionError(label)


def validate_data(
    data_path: Path,
    source_path: Path,
    cycle_frames: list[float],
    cycle_seconds: float,
    contact_windows: dict[str, list[float]],
) -> tuple[float, int]:
    data = json.loads(data_path.read_text())
    require(data["format"] == "gloam-cmu-body-delta-v1", "format")
    require(data["source_sha256"] == EXPECTED[source_path], "embedded source hash")
    require(data["source_fps"] == 120, "source rate")
    require(data["cycle_source_frames"] == cycle_frames, "cycle frames")
    require(math.isclose(data["cycle_seconds"], cycle_seconds), "cycle seconds")
    require(data["sample_count"] == 48 == len(data["samples"]), "sample count")
    require(data["contact_windows"] == contact_windows, "contact windows")

    root_mean = [0.0, 0.0, 0.0]
    root_radius = 0.0
    for index, sample in enumerate(data["samples"]):
        rotations = sample["rotations"]
        require(set(rotations) == REQUIRED_CHANNELS, f"channels at sample {index}")
        for channel, values in rotations.items():
            require(len(values) == 4 and all(math.isfinite(v) for v in values), f"finite quaternion {channel}/{index}")
            norm = math.sqrt(sum(v * v for v in values))
            require(abs(norm - 1.0) < 1e-5, f"normalized quaternion {channel}/{index}")
        root = sample["root"]
        require(len(root) == 3 and all(math.isfinite(v) for v in root), f"finite root {index}")
        root_radius = max(root_radius, math.sqrt(sum(v * v for v in root)))
        for axis in range(3):
            root_mean[axis] += root[axis] / len(data["samples"])

    require(max(abs(value) for value in root_mean) < 1e-9, "centered presentation root")
    require(root_radius < 0.01, "presentation root remains millimeter scale")
    return root_radius, len(data["samples"])


def main() -> None:
    for path, expected in EXPECTED.items():
        require(sha256(path) == expected, f"unexpected hash: {path.name}")

    run_radius, run_samples = validate_data(
        DATA,
        SOURCE,
        [7.0, 90.0],
        83.0 / 120.0,
        {"L": [0.0, 0.44], "R": [0.48, 0.94]},
    )
    walk_radius, walk_samples = validate_data(
        WALK_DATA,
        WALK_SOURCE,
        [190.0, 325.0],
        135.0 / 120.0,
        {"L": [0.0, 0.48], "R": [0.56, 0.94]},
    )
    print(
        "CMU_RETARGET_VALIDATION_OK",
        f"walk_samples={walk_samples}",
        f"run_samples={run_samples}",
        f"channels={len(REQUIRED_CHANNELS)}",
        f"walk_cycle_seconds={135.0 / 120.0:.6f}",
        f"run_cycle_seconds={83.0 / 120.0:.6f}",
        f"walk_root_radius={walk_radius:.6f}",
        f"run_root_radius={run_radius:.6f}",
    )


if __name__ == "__main__":
    main()
