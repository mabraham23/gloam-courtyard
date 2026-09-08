"""Read-only r1 mesh spike diagnosis against the saved Blender candidate.

Loads the source with embedded scripts disabled, applies the adapter's grounded
finger curl in rest-aware body axes, and reports every grossly stretched edge
with source position, material, weights and bone-distance evidence. It never
saves the blend or GLB.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector


REPO = Path("/Users/markabraham/dev/batman")
BLEND = REPO / "actors/gloam_vigil/v4/source/gloam_vigil_player_v4.blend"
OUT = REPO / "work/character-art-v4-rig/r1_spike_diagnosis.json"
ANATOMY_BODY_VERTEX_COUNT = 18_003
FINGERS = ("thumb", "index", "middle", "ring", "pinky")


def anatomical_rotation(armature: bpy.types.Object, name: str, euler: tuple[float, float, float]) -> None:
    rest = armature.data.bones[name].matrix_local.to_quaternion()
    delta = Euler(euler, "XYZ").to_quaternion()
    pose = armature.pose.bones[name]
    pose.rotation_mode = "QUATERNION"
    pose.rotation_quaternion = rest.inverted() @ delta @ rest


def weights(obj: bpy.types.Object, index: int) -> dict[str, float]:
    return {
        obj.vertex_groups[item.group].name: round(item.weight, 6)
        for item in obj.data.vertices[index].groups
        if item.weight > 1.0e-7
    }


def vertex_materials(obj: bpy.types.Object) -> list[set[str]]:
    result: list[set[str]] = [set() for _vertex in obj.data.vertices]
    for polygon in obj.data.polygons:
        material = obj.data.materials[polygon.material_index]
        name = material.name if material else "<null>"
        for index in polygon.vertices:
            result[index].add(name)
    return result


def evaluated_points(obj: bpy.types.Object) -> list[Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    result = [vertex.co.copy() for vertex in mesh.vertices]
    evaluated.to_mesh_clear()
    return result


def hand_component_misweights(obj: bpy.types.Object, points: list[Vector]) -> dict[str, object]:
    adjacency: list[list[int]] = [[] for _point in points]
    for edge in obj.data.edges:
        first, second = edge.vertices
        adjacency[first].append(second)
        adjacency[second].append(first)
    report: dict[str, object] = {}
    for side, sign in (("L", -1.0), ("R", 1.0)):
        wrist = Vector((sign * 0.35925, -0.09628, 1.095))
        allowed = {
            index for index, point in enumerate(points)
            if sign * point.x > 0.285 and 0.75 < point.z < 1.16
        }
        seeds = sorted(allowed, key=lambda index: (points[index] - wrist).length)[:12]
        connected = set(seeds)
        queue = list(seeds)
        while queue:
            index = queue.pop()
            for neighbor in adjacency[index]:
                if neighbor in allowed and neighbor not in connected:
                    connected.add(neighbor)
                    queue.append(neighbor)
        arm_family = {
            f"clavicle.{side}", f"upper_arm.{side}", f"upper_arm_twist.{side}",
            f"forearm.{side}", f"forearm_twist.{side}", f"hand.{side}",
        } | {
            f"{finger}.{segment:02d}.{side}"
            for finger in FINGERS for segment in range(1, 4)
        }
        wrong = []
        for index in connected:
            actual = weights(obj, index)
            if not set(actual).issubset(arm_family):
                wrong.append(index)
        boundary_edges = []
        wrong_set = set(wrong)
        for edge in obj.data.edges:
            first, second = edge.vertices
            if first in connected and second in connected and ((first in wrong_set) != (second in wrong_set)):
                boundary_edges.append([first, second])
        report[side] = {
            "connected_vertices": len(connected),
            "misweighted_vertices": len(wrong),
            "misweighted_fraction": len(wrong) / max(1, len(connected)),
            "classification_boundary_edges": len(boundary_edges),
            "misweighted_bounds": [
                [min(points[index][axis] for index in wrong), max(points[index][axis] for index in wrong)]
                for axis in range(3)
            ] if wrong else None,
            "sample": [
                {
                    "index": index,
                    "position": [round(value, 6) for value in points[index]],
                    "weights": weights(obj, index),
                }
                for index in sorted(wrong, key=lambda item: points[item].z)[:20]
            ],
        }
    return report


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND), load_ui=False, use_scripts=False)
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = bpy.data.objects["GV2_Body"]
    assert len(body.modifiers) == 1 and body.modifiers[0].type == "ARMATURE", [item.type for item in body.modifiers]
    assert body.modifiers[0].object == armature
    for bone in armature.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion.identity()
        bone.location.zero()
        bone.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()
    rest_points = evaluated_points(body)
    source_points = [vertex.co.copy() for vertex in body.data.vertices]
    rest_error = max((a - b).length for a, b in zip(rest_points, source_points, strict=True))
    assert rest_error < 1.0e-5, rest_error

    # Grapple/takedown action secondary motion drives 1.14 before the per-digit
    # character/segment multiplier; this is the clearest reported live failure.
    curl = 1.14
    for side in ("L", "R"):
        for finger in FINGERS:
            character = 0.72 if finger == "thumb" else (0.88 if finger == "pinky" else 1.0)
            for segment in range(1, 4):
                scale = character * (0.72 + float(segment) * 0.12)
                anatomical_rotation(armature, f"{finger}.{segment:02d}.{side}", (curl * scale, 0.0, 0.0))
    bpy.context.view_layer.update()
    posed_points = evaluated_points(body)
    assert len(posed_points) == len(source_points)
    materials = vertex_materials(body)
    hand_misweights = hand_component_misweights(body, source_points)

    edge_rows = []
    for edge in body.data.edges:
        first, second = edge.vertices
        before = (source_points[first] - source_points[second]).length
        after = (posed_points[first] - posed_points[second]).length
        ratio = after / max(before, 1.0e-9)
        if ratio < 1.5:
            continue
        edge_rows.append({
            "indices": [first, second],
            "before_m": before,
            "after_m": after,
            "ratio": ratio,
            "sources": ["licensed_anatomy" if index < ANATOMY_BODY_VERTEX_COUNT else "original_costume_detail" for index in (first, second)],
            "positions": [[round(value, 6) for value in source_points[index]] for index in (first, second)],
            "posed": [[round(value, 6) for value in posed_points[index]] for index in (first, second)],
            "materials": [sorted(materials[index]) for index in (first, second)],
            "weights": [weights(body, index) for index in (first, second)],
        })
    edge_rows.sort(key=lambda row: (row["after_m"], row["ratio"]), reverse=True)

    displacement_rows = []
    for index, (before, after) in enumerate(zip(source_points, posed_points, strict=True)):
        distance = (after - before).length
        if distance < 0.10:
            continue
        displacement_rows.append({
            "index": index,
            "displacement_m": distance,
            "source": "licensed_anatomy" if index < ANATOMY_BODY_VERTEX_COUNT else "original_costume_detail",
            "position": [round(value, 6) for value in before],
            "posed": [round(value, 6) for value in after],
            "materials": sorted(materials[index]),
            "weights": weights(body, index),
        })
    displacement_rows.sort(key=lambda row: row["displacement_m"], reverse=True)

    report = {
        "blend": str(BLEND.relative_to(REPO)),
        "body_vertices": len(source_points),
        "body_edges": len(body.data.edges),
        "body_modifiers": [item.type for item in body.modifiers],
        "rest_max_error_m": rest_error,
        "sample": "adapter-equivalent grapple curl 1.14 on all 30 finger bones",
        "hand_component_misweights": hand_misweights,
        "gross_edge_count": len(edge_rows),
        "gross_displacement_count": len(displacement_rows),
        "top_edges": edge_rows[:80],
        "top_displacements": displacement_rows[:80],
    }
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("V4_R1_SPIKE_DIAGNOSIS", json.dumps({
        "vertices": report["body_vertices"],
        "gross_edges": report["gross_edge_count"],
        "gross_displacements": report["gross_displacement_count"],
        "top_edge": edge_rows[0] if edge_rows else None,
    }, sort_keys=True))


main()
