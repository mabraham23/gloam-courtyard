"""Revision-aware, read-only Blender source-pose review.

This is the reusable successor to the frozen R3 snapshot harness. It requires
both a revision label and the exact expected GLB hash, writes into a new
``work/character-art-v4-rig/<revision>-posed`` directory, and refuses to
overwrite any prior image or report. Full-body and lower-neck images are
rendered independently by the Blender camera; no image crop/edit is used.

Example::

    Blender --background --disable-autoexec \
      --python work/character-art-v4-rig/source_pose_review.py -- \
      --revision r4 --expected-glb-sha256 <64-hex-sha>
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
from pathlib import Path
import re
import sys

import bpy
from mathutils import Vector


REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "actors/gloam_vigil/v4/source/gloam_vigil_player_v4.blend"
GLB = REPO / "actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"
SNAPSHOT_SCRIPT = REPO / "work/character-art-v4-rig/r3-posed/source_pose_review.py"
SAMPLES = (
    ("grapple", 15.0 / 29.0),
    ("strike", 13.0 / 29.0),
    ("crouch", 1.0),
)


def arguments() -> argparse.Namespace:
    values = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--revision", required=True)
    parser.add_argument("--expected-glb-sha256", required=True)
    result = parser.parse_args(values)
    if re.fullmatch(r"r[1-9][0-9]*", result.revision) is None:
        parser.error("--revision must be r followed by a positive integer")
    if re.fullmatch(r"[0-9a-f]{64}", result.expected_glb_sha256) is None:
        parser.error("--expected-glb-sha256 must be 64 lowercase hex characters")
    return result


def load_snapshot_helpers():
    specification = importlib.util.spec_from_file_location("v4_r3_pose_review_helpers", SNAPSHOT_SCRIPT)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def neck_review_points(
    meshes: list[bpy.types.Object],
    rest: dict[str, list[Vector]],
) -> list[Vector]:
    """Return current posed points from the real lower-neck/collar region."""
    result: list[Vector] = []
    for obj in meshes:
        posed = HELPERS.evaluated_points(obj)
        for index, source in enumerate(rest[obj.name]):
            if obj.name == "GV2_Face":
                include = 1.8245 <= source.z <= 1.925 and abs(source.x) <= 0.19
            elif obj.name == "GV2_Body":
                include = 1.755 <= source.z <= 1.840 and abs(source.x) <= 0.34
            else:
                include = 1.70 <= source.z <= 1.80 and abs(source.x) <= 0.34
            if include:
                result.append(posed[index])
    assert len(result) > 300, len(result)
    return result


def frame_neck(camera: bpy.types.Object, points: list[Vector]) -> list[list[float]]:
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    center = (minimum + maximum) * 0.5
    direction = Vector((2.55, -4.25, 0.16)).normalized()
    camera.data.ortho_scale = max(0.50, (maximum.z - minimum.z) * 2.2, (maximum.x - minimum.x) * 1.55)
    camera.location = center + direction * 4.0
    HELPERS.look_at(camera, center)
    return [list(minimum), list(maximum)]


def preflight(output_dir: Path, revision: str) -> list[Path]:
    files = [output_dir / "source_pose_review.json"]
    for state, _progress in SAMPLES:
        files.extend((
            output_dir / f"{revision}-{state}-threequarter.png",
            output_dir / f"{revision}-{state}-neck-close.png",
        ))
    existing = [path for path in files if path.exists()]
    if existing:
        raise RuntimeError(f"Preserve prior evidence; refusing to overwrite {existing}")
    output_dir.mkdir(parents=True, exist_ok=True)
    return files


def main() -> None:
    options = arguments()
    output_dir = REPO / "work/character-art-v4-rig" / f"{options.revision}-posed"
    preflight(output_dir, options.revision)
    assert SOURCE.exists() and GLB.exists()
    glb_sha = HELPERS.file_sha256(GLB)
    assert glb_sha == options.expected_glb_sha256, (glb_sha, options.expected_glb_sha256)
    source_sha_before = HELPERS.file_sha256(SOURCE)

    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
    HELPERS.remove_saved_studio()
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    meshes = [
        obj for obj in bpy.data.objects
        if obj.type == "MESH"
        and any(modifier.type == "ARMATURE" and modifier.object == armature for modifier in obj.modifiers)
    ]
    assert {obj.name for obj in meshes} == {"GV2_Body", "GV2_Face", "GV2_Cape"}, [obj.name for obj in meshes]
    for obj in meshes:
        obj.hide_render = False
        obj.hide_set(False)
        modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
        assert modifiers and all(not modifier.use_deform_preserve_volume for modifier in modifiers), obj.name
    armature.hide_render = True
    armature.hide_set(True)

    HELPERS.reset_pose(armature)
    rest = {obj.name: HELPERS.evaluated_points(obj) for obj in meshes}
    HELPERS.remove_saved_studio()
    floor, camera = HELPERS.add_studio()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("V4RevisionPoseReviewWorld")
    scene.world.color = (0.022, 0.027, 0.038)

    results: dict[str, object] = {}
    for state, progress in SAMPLES:
        pose = HELPERS.apply_sample(armature, state, progress)
        minimum, maximum, per_mesh_bounds = HELPERS.bounds(meshes)
        floor.location.z = min(0.0, minimum.z - 0.008)

        scene.render.resolution_x = 900
        scene.render.resolution_y = 1080
        HELPERS.frame(camera, minimum, maximum)
        full_image = output_dir / f"{options.revision}-{state}-threequarter.png"
        scene.render.filepath = str(full_image)
        bpy.ops.render.render(write_still=True)

        scene.render.resolution_x = 960
        scene.render.resolution_y = 960
        neck_bounds = frame_neck(camera, neck_review_points(meshes, rest))
        neck_image = output_dir / f"{options.revision}-{state}-neck-close.png"
        scene.render.filepath = str(neck_image)
        bpy.ops.render.render(write_still=True)

        posed = {obj.name: HELPERS.evaluated_points(obj) for obj in meshes}
        results[state] = {
            "pose": pose,
            "full_image": str(full_image.relative_to(REPO)),
            "neck_image": str(neck_image.relative_to(REPO)),
            "world_bounds": [list(minimum), list(maximum)],
            "mesh_bounds": per_mesh_bounds,
            "neck_review_bounds": neck_bounds,
            "floor_z": floor.location.z,
            "edge_evidence": {
                obj.name: HELPERS.edge_evidence(obj, rest[obj.name], posed[obj.name])
                for obj in meshes
            },
        }

    source_sha_after = HELPERS.file_sha256(SOURCE)
    assert source_sha_after == source_sha_before
    report = {
        "status": "SOURCE_RENDER_DIAGNOSTIC_COMPLETE_REQUIRES_PIXEL_REVIEW",
        "scope": "Background Blender source poses only; not Godot runtime acceptance.",
        "revision": options.revision,
        "source": str(SOURCE.relative_to(REPO)),
        "source_sha256_before": source_sha_before,
        "source_sha256_after": source_sha_after,
        "glb_sha256": glb_sha,
        "skinning": "linear blend; Blender preserve-volume disabled on all three skinned meshes",
        "meshes": [obj.name for obj in meshes],
        "samples": results,
    }
    report_path = output_dir / "source_pose_review.json"
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = {
        state: {
            name: {
                "edges_over_ratio_6": values["edges_over_ratio_6"],
                "tether_edges": values["tether_edges"],
            }
            for name, values in result["edge_evidence"].items()
        }
        for state, result in results.items()
    }
    print("V4_SOURCE_POSE_REVIEW COMPLETE", json.dumps(summary, sort_keys=True))


HELPERS = load_snapshot_helpers()


if __name__ == "__main__":
    main()
