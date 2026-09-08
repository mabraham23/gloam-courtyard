"""Read-only R3 source-pose render review for the fully dressed v4 candidate.

The script opens the saved Blender source with embedded scripts disabled,
applies the same rest-aware action samples as the durable deformation gate,
and writes three consistently lit studio renders plus numeric mesh evidence.
It deliberately never saves the temporary posed/studio scene.

Run from the repository root with Blender 5.2 LTS::

    /Applications/Blender.app/Contents/MacOS/Blender \
      --background --disable-autoexec \
      --python work/character-art-v4-rig/r3-posed/source_pose_review.py
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector


REPO = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SOURCE = REPO / "actors/gloam_vigil/v4/source/gloam_vigil_player_v4.blend"
GLB = REPO / "actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"
DIAGNOSTICS = REPO / "work/character-art-v4-rig"
if str(DIAGNOSTICS) not in sys.path:
    sys.path.insert(0, str(DIAGNOSTICS))

from diagnose_r2_action_spikes import apply_sample, reset_pose  # noqa: E402


EXPECTED_GLB_SHA256 = "242104fcc347652f4d3e83c2da779282b9a2ff76bb4c5ffc943caf6ca09f986e"
SAMPLES = (
    ("grapple", 15.0 / 29.0),
    ("strike", 13.0 / 29.0),
    ("crouch", 1.0),
)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    principled = result.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
    return result


def remove_saved_studio() -> None:
    for obj in list(bpy.data.objects):
        lowered = obj.name.lower()
        if obj.type in {"LIGHT", "CAMERA"} or lowered.startswith(("review floor", "floor", "ground")):
            bpy.data.objects.remove(obj, do_unlink=True)


def area_light(
    name: str,
    location: tuple[float, float, float],
    energy: float,
    color: tuple[float, float, float],
    size: float,
) -> bpy.types.Object:
    data = bpy.data.lights.new(f"{name}Data", "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = location
    look_at(light, Vector((0.0, 0.0, 1.05)))
    return light


def add_studio() -> tuple[bpy.types.Object, bpy.types.Object]:
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "R3 pose review floor"
    floor.data.materials.append(material("R3 pose review floor material", (0.047, 0.052, 0.062, 1.0), 0.82))

    # Broad, balanced sources keep both underarms readable without flattening
    # the original materials. The identical rig is retained for every pose.
    area_light("R3 warm key", (-3.4, -4.5, 4.8), 1050.0, (1.0, 0.90, 0.80), 3.2)
    area_light("R3 cool fill", (3.5, -3.0, 3.7), 850.0, (0.72, 0.82, 1.0), 3.0)
    area_light("R3 cape rim", (1.1, 3.6, 4.1), 1000.0, (0.70, 0.82, 1.0), 2.7)
    area_light("R3 top softbox", (-0.5, -0.8, 5.0), 420.0, (1.0, 0.96, 0.91), 2.3)

    data = bpy.data.cameras.new("R3PoseReviewCameraData")
    data.type = "ORTHO"
    data.dof.use_dof = False
    camera = bpy.data.objects.new("R3PoseReviewCamera", data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    return floor, camera


def evaluated_points(obj: bpy.types.Object) -> list[Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    result = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
    evaluated.to_mesh_clear()
    return result


def bounds(meshes: list[bpy.types.Object]) -> tuple[Vector, Vector, dict[str, list[list[float]]]]:
    all_points: list[Vector] = []
    per_mesh: dict[str, list[list[float]]] = {}
    for obj in meshes:
        points = evaluated_points(obj)
        assert points and all(math.isfinite(value) for point in points for value in point), obj.name
        minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
        maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
        per_mesh[obj.name] = [list(minimum), list(maximum)]
        all_points.extend(points)
    minimum = Vector(tuple(min(point[axis] for point in all_points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in all_points) for axis in range(3)))
    return minimum, maximum, per_mesh


def edge_evidence(
    obj: bpy.types.Object,
    rest: list[Vector],
    posed: list[Vector],
) -> dict[str, object]:
    assert len(rest) == len(posed) == len(obj.data.vertices), obj.name
    rows = []
    for edge in obj.data.edges:
        first, second = edge.vertices
        before = (rest[first] - rest[second]).length
        after = (posed[first] - posed[second]).length
        rows.append((after / max(before, 1.0e-9), after, before, first, second))
    worst_ratio = max(rows, key=lambda row: row[0])
    stretched = [row for row in rows if row[0] >= 1.35]
    worst_length = max(stretched, key=lambda row: row[1]) if stretched else None

    def record(row: tuple[float, float, float, int, int] | None) -> dict[str, object] | None:
        if row is None:
            return None
        ratio, after, before, first, second = row
        return {
            "indices": [first, second],
            "before_m": before,
            "after_m": after,
            "ratio": ratio,
        }

    return {
        "edges": len(rows),
        "worst_ratio": record(worst_ratio),
        "worst_stretched_length": record(worst_length),
        "edges_over_ratio_6": sum(1 for ratio, _after, _before, _first, _second in rows if ratio >= 6.0),
        "tether_edges": sum(1 for ratio, after, _before, _first, _second in rows if ratio >= 6.0 and after >= 0.045),
    }


def frame(camera: bpy.types.Object, minimum: Vector, maximum: Vector) -> None:
    center = (minimum + maximum) * 0.5
    center.z = max(center.z, 0.82)
    span = maximum - minimum
    camera.data.ortho_scale = max(2.05, span.z * 1.16, span.x * 1.48, span.y * 1.20)
    direction = Vector((3.75, -5.25, 0.20)).normalized()
    camera.location = center + direction * 6.0
    look_at(camera, center)


def main() -> None:
    assert SOURCE.exists() and GLB.exists()
    source_sha_before = file_sha256(SOURCE)
    glb_sha = file_sha256(GLB)
    assert glb_sha == EXPECTED_GLB_SHA256, glb_sha
    for name, _progress in SAMPLES:
        path = OUT / f"r3-{name}-threequarter.png"
        if path.exists():
            raise RuntimeError(f"Preserve prior evidence; refusing to overwrite {path}")
    report_path = OUT / "source_pose_review.json"
    if report_path.exists():
        raise RuntimeError(f"Preserve prior evidence; refusing to overwrite {report_path}")

    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
    remove_saved_studio()
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

    reset_pose(armature)
    rest = {obj.name: evaluated_points(obj) for obj in meshes}
    remove_saved_studio()
    floor, camera = add_studio()

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("R3PoseReviewWorld")
    scene.world.color = (0.022, 0.027, 0.038)

    results: dict[str, object] = {}
    for state, progress in SAMPLES:
        pose = apply_sample(armature, state, progress)
        minimum, maximum, per_mesh_bounds = bounds(meshes)
        # Preserve every posed vertex in view; move only the temporary studio
        # floor below the geometry rather than disguising penetration by moving
        # the character or its armature.
        floor.location.z = min(0.0, minimum.z - 0.008)
        frame(camera, minimum, maximum)
        output = OUT / f"r3-{state}-threequarter.png"
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
        posed = {obj.name: evaluated_points(obj) for obj in meshes}
        results[state] = {
            "pose": pose,
            "image": str(output.relative_to(REPO)),
            "world_bounds": [list(minimum), list(maximum)],
            "mesh_bounds": per_mesh_bounds,
            "floor_z": floor.location.z,
            "edge_evidence": {
                obj.name: edge_evidence(obj, rest[obj.name], posed[obj.name])
                for obj in meshes
            },
        }

    # The background session must not mutate the authored source on disk.
    source_sha_after = file_sha256(SOURCE)
    assert source_sha_after == source_sha_before
    report = {
        "status": "SOURCE_RENDER_DIAGNOSTIC_COMPLETE_REQUIRES_PIXEL_REVIEW",
        "scope": "Background Blender source poses only; not Godot runtime acceptance.",
        "source": str(SOURCE.relative_to(REPO)),
        "source_sha256_before": source_sha_before,
        "source_sha256_after": source_sha_after,
        "glb_sha256": glb_sha,
        "skinning": "linear blend; Blender preserve-volume disabled on all three skinned meshes",
        "meshes": [obj.name for obj in meshes],
        "samples": results,
    }
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
    print("V4_R3_SOURCE_POSE_REVIEW COMPLETE", json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
