"""Read-only full-mesh v4 R2 action-spike diagnosis.

Loads the saved R2 Blender source with embedded scripts disabled, recreates the
quality-stage grapple/strike samples in the adapter's rest-aware bone axes, and
reports stretched *source topology edges* for every skinned mesh.  The source
file is never saved or exported.
"""

from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Euler, Vector


REPO = Path("/Users/markabraham/dev/batman")
BLEND = REPO / "actors/gloam_vigil/v4/source/gloam_vigil_player_v4.blend"
OUT = REPO / "work/character-art-v4-rig/r2_action_spike_diagnosis.json"
ANATOMY_BODY_VERTEX_COUNT = 18_003
FINGERS = ("thumb", "index", "middle", "ring", "pinky")


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    amount = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return amount * amount * (3.0 - 2.0 * amount)


def lerp(first: float, second: float, amount: float) -> float:
    return first + (second - first) * amount


def reset_pose(armature: bpy.types.Object) -> None:
    for bone in armature.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion.identity()
        bone.location.zero()
        bone.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()


def anatomical_rotation(
    armature: bpy.types.Object,
    name: str,
    euler: tuple[float, float, float] | Vector,
) -> None:
    """Match Quaternion.from_euler's YXZ body-axis driver conversion."""
    rest = armature.data.bones[name].matrix_local.to_quaternion()
    delta = Euler(tuple(euler), "YXZ").to_quaternion()
    armature.pose.bones[name].rotation_quaternion = rest.inverted() @ delta @ rest


def apply_core(
    armature: bpy.types.Object,
    pelvis: tuple[float, float, float],
    torso: tuple[float, float, float],
    head: tuple[float, float, float],
) -> None:
    anatomical_rotation(armature, "pelvis", pelvis)
    for name, share in (("spine", 0.22), ("spine_upper", 0.31), ("chest", 0.53)):
        anatomical_rotation(armature, name, tuple(value * share for value in torso))
    anatomical_rotation(armature, "neck", tuple(value * 0.32 for value in head))
    anatomical_rotation(armature, "head", tuple(value * 0.76 for value in head))


def apply_arm(
    armature: bpy.types.Object,
    side: str,
    shoulder: tuple[float, float, float],
    elbow: tuple[float, float, float],
) -> None:
    clavicle = (shoulder[0] * 0.18, shoulder[1] * 0.16, shoulder[2] * 0.22)
    upper = [shoulder[index] - clavicle[index] for index in range(3)]
    upper_twist = upper[1] * 0.24
    upper[1] -= upper_twist
    lower = list(elbow)
    lower_twist = lower[1] * 0.30
    lower[1] -= lower_twist
    anatomical_rotation(armature, f"clavicle.{side}", clavicle)
    anatomical_rotation(armature, f"upper_arm.{side}", upper)
    anatomical_rotation(armature, f"upper_arm_twist.{side}", (0.0, upper_twist, 0.0))
    anatomical_rotation(armature, f"forearm.{side}", lower)
    anatomical_rotation(armature, f"forearm_twist.{side}", (0.0, lower_twist, 0.0))


def apply_fingers(armature: bpy.types.Object, curl: float) -> None:
    for side in ("L", "R"):
        for finger in FINGERS:
            character = 0.72 if finger == "thumb" else (0.88 if finger == "pinky" else 1.0)
            for segment in range(1, 4):
                scale = character * (0.72 + float(segment) * 0.12)
                anatomical_rotation(
                    armature,
                    f"{finger}.{segment:02d}.{side}",
                    (curl * scale, 0.0, 0.0),
                )


def apply_leg(
    armature: bpy.types.Object,
    side: str,
    thigh: tuple[float, float, float],
    shin: tuple[float, float, float],
    foot: tuple[float, float, float],
) -> None:
    upper = list(thigh)
    upper_twist = upper[1] * 0.24
    upper[1] -= upper_twist
    lower = list(shin)
    lower_twist = lower[1] * 0.18
    lower[1] -= lower_twist
    anatomical_rotation(armature, f"thigh.{side}", upper)
    anatomical_rotation(armature, f"thigh_twist.{side}", (0.0, upper_twist, 0.0))
    anatomical_rotation(armature, f"shin.{side}", lower)
    anatomical_rotation(armature, f"shin_twist.{side}", (0.0, lower_twist, 0.0))
    anatomical_rotation(armature, f"foot.{side}", foot)


def apply_sample(armature: bpy.types.Object, state: str, progress: float) -> dict[str, object]:
    reset_pose(armature)
    if state == "grapple":
        launch = smoothstep(0.06, 0.30, progress)
        approach = smoothstep(0.62, 0.88, progress)
        landing = smoothstep(0.84, 1.0, progress)
        left_arm = lerp(lerp(0.18, -1.90, launch), -0.48, approach)
        right_arm = lerp(lerp(0.26, -2.45, launch), -0.62, approach)
        left_elbow = lerp(lerp(0.38, 0.25, launch), 0.34, approach)
        right_elbow = lerp(lerp(0.32, 0.18, launch), 0.38, approach)
        pelvis = (
            lerp(lerp(0.10, -0.08, launch), 0.14, landing),
            lerp(lerp(-0.10, 0.05, launch), 0.0, landing),
            lerp(lerp(-0.07, 0.02, launch), -0.04, landing),
        )
        torso = (
            lerp(lerp(0.14, -0.18, launch), 0.18, landing),
            lerp(lerp(0.08, -0.04, approach), 0.0, landing),
            lerp(lerp(0.04, -0.025, approach), 0.05, landing),
        )
        head = (
            lerp(lerp(-0.10, 0.14, launch), -0.16, landing),
            lerp(-0.03, 0.0, landing),
            0.0,
        )
        finger_curl = lerp(0.38, 0.76, smoothstep(0.12, 0.58, progress))
        apply_core(armature, pelvis, torso, head)
        apply_arm(armature, "L", (left_arm, 0.0, -0.055), (left_elbow, 0.0, 0.0))
        apply_arm(armature, "R", (right_arm, 0.0, 0.055), (right_elbow, 0.0, 0.0))
    elif state == "strike":
        windup = smoothstep(0.0, 0.20, progress)
        contact = smoothstep(0.20, 0.39, progress)
        recover = smoothstep(0.52, 1.0, progress)
        coil = windup * (1.0 - contact)
        extend = contact * (1.0 - recover)
        guard = windup * (1.0 - recover)
        right_arm = (0.045 + 0.60 * coil - 1.65 * extend, 0.30 * coil - 0.08 * extend, 0.055 + 0.18 * coil - 0.10 * extend)
        left_arm = (-0.035 - 0.95 * guard, 0.10 * guard, -0.055 - 0.10 * guard)
        pelvis = (0.0, -0.10 * coil + 0.12 * extend, 0.0)
        torso = (0.04 * coil + 0.12 * extend, -0.32 * coil + 0.26 * extend, 0.0)
        head = (-0.06 * extend, 0.12 * coil - 0.15 * extend, 0.0)
        finger_curl = 1.02
        apply_core(armature, pelvis, torso, head)
        apply_arm(armature, "L", left_arm, (0.14 + 0.90 * guard, 0.0, 0.0))
        apply_arm(armature, "R", right_arm, (0.18 + 0.86 * coil - 0.13 * extend, 0.0, 0.0))
    elif state == "crouch":
        pelvis = (0.20, 0.0, 0.0)
        torso = (0.86, 0.0, 0.0)
        head = (-0.66, 0.0, 0.0)
        left_thigh, right_thigh = -1.23, -1.17
        left_shin, right_shin = 2.15, 2.07
        apply_core(armature, pelvis, torso, head)
        apply_leg(armature, "L", (left_thigh, 0.0, 0.0), (left_shin, 0.0, 0.0), (-pelvis[0] - left_thigh - left_shin, 0.0, 0.0))
        apply_leg(armature, "R", (right_thigh, 0.0, 0.0), (right_shin, 0.0, 0.0), (-pelvis[0] - right_thigh - right_shin, 0.0, 0.0))
        apply_arm(armature, "L", (-0.18, 0.0, -0.055), (0.38, 0.0, 0.0))
        apply_arm(armature, "R", (-0.12, 0.0, 0.055), (0.42, 0.0, 0.0))
        finger_curl = 0.42
    elif state == "evade":
        pelvis = (0.18, 0.0, -0.06)
        torso = (0.30, 0.0, 0.08)
        head = (-0.34, 0.0, -0.04)
        apply_core(armature, pelvis, torso, head)
        apply_leg(armature, "L", (-0.66, 0.0, 0.0), (1.22, 0.0, 0.0), (-0.36, 0.0, 0.0))
        apply_leg(armature, "R", (-0.50, 0.0, 0.0), (1.08, 0.0, 0.0), (-0.30, 0.0, 0.0))
        apply_arm(armature, "L", (-0.92, -0.20, -0.36), (0.82, 0.0, 0.0))
        apply_arm(armature, "R", (-1.02, 0.24, 0.40), (0.76, 0.0, 0.0))
        finger_curl = 0.88
    elif state in {"walk_left_contact", "walk_right_contact"}:
        right_contact = state == "walk_right_contact"
        # Exact authored locomotion keys at normalized phase 0.0/0.5. At full
        # movement the adapter's anatomical-profile flex offsets are already
        # included here; animation channels replace the initial driver pose.
        channels = {
            "pelvis": (-0.018, 0.035, 0.024) if right_contact else (-0.025, -0.035, -0.025),
            "spine": (-0.020, -0.018, -0.008) if right_contact else (-0.018, 0.018, 0.008),
            "spine_upper": (-0.016, -0.028, -0.010) if right_contact else (-0.014, 0.028, 0.010),
            "chest": (-0.024, -0.044, -0.012) if right_contact else (-0.022, 0.044, 0.012),
            "neck": (0.010, 0.016, 0.005) if right_contact else (0.012, -0.016, -0.005),
            "head": (0.016, 0.026, 0.008) if right_contact else (0.018, -0.026, -0.008),
            "thigh.L": (-0.263, 0.0, 0.012) if right_contact else (0.417, 0.0, -0.012),
            "thigh.R": (0.417, 0.0, 0.012) if right_contact else (-0.263, 0.0, -0.012),
            "shin.L": (0.636, 0.0, 0.0) if right_contact else (0.266, 0.0, 0.0),
            "shin.R": (0.266, 0.0, 0.0) if right_contact else (0.636, 0.0, 0.0),
            "foot.L": (0.077, 0.0, 0.0) if right_contact else (-0.123, 0.0, 0.0),
            "foot.R": (-0.123, 0.0, 0.0) if right_contact else (0.057, 0.0, 0.0),
            "thigh_twist.L": (0.0, 0.018, 0.0) if right_contact else (0.0, -0.035, 0.0),
            "thigh_twist.R": (0.0, 0.035, 0.0) if right_contact else (0.0, -0.018, 0.0),
            "shin_twist.L": (0.0, -0.016, 0.0) if right_contact else (0.0, 0.018, 0.0),
            "shin_twist.R": (0.0, -0.018, 0.0) if right_contact else (0.0, 0.016, 0.0),
            "clavicle.L": (0.03, 0.0, -0.01) if right_contact else (-0.02, 0.0, -0.04),
            "clavicle.R": (-0.02, 0.0, 0.04) if right_contact else (0.03, 0.0, 0.01),
            "upper_arm.L": (0.28, 0.0, -0.02) if right_contact else (-0.26, 0.0, -0.04),
            "upper_arm.R": (-0.26, 0.0, 0.04) if right_contact else (0.28, 0.0, 0.02),
            "forearm.L": (0.28, 0.0, 0.0) if right_contact else (0.22, 0.0, 0.0),
            "forearm.R": (0.22, 0.0, 0.0) if right_contact else (0.28, 0.0, 0.0),
        }
        for name, euler in channels.items():
            anatomical_rotation(armature, name, euler)
        finger_curl = 0.24
    else:
        raise AssertionError(state)
    apply_fingers(armature, finger_curl)
    bpy.context.view_layer.update()
    return {
        "state": state,
        "progress": progress,
        "finger_curl": finger_curl,
    }


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


def family(name: str) -> str:
    prefix = name.split(".")[0]
    if prefix in {"clavicle", "upper_arm", "upper_arm_twist", "forearm", "forearm_twist", "hand", *FINGERS}:
        return f"arm.{name.rsplit('.', 1)[-1]}"
    if prefix in {"thigh", "thigh_twist", "shin", "shin_twist", "foot", "ball", "toe"}:
        return f"leg.{name.rsplit('.', 1)[-1]}"
    if prefix.startswith("cape"):
        return "cape"
    if prefix in {"jaw", "eye"}:
        return "face"
    return "core"


def edge_source(obj: bpy.types.Object, indices: tuple[int, int]) -> list[str]:
    if obj.name != "GV2_Body":
        return [obj.name, obj.name]
    return [
        "licensed_anatomy" if index < ANATOMY_BODY_VERTEX_COUNT else "original_costume_detail"
        for index in indices
    ]


def analyze_mesh(obj: bpy.types.Object, rest: list[Vector], posed: list[Vector]) -> dict[str, object]:
    materials = vertex_materials(obj)
    rows: list[dict[str, object]] = []
    for edge in obj.data.edges:
        first, second = edge.vertices
        before = (rest[first] - rest[second]).length
        after = (posed[first] - posed[second]).length
        ratio = after / max(before, 1.0e-9)
        if ratio < 1.35 and after < 0.030:
            continue
        endpoint_weights = [weights(obj, index) for index in (first, second)]
        rows.append({
            "indices": [first, second],
            "before_m": before,
            "after_m": after,
            "ratio": ratio,
            "sources": edge_source(obj, (first, second)),
            "positions": [[round(value, 6) for value in rest[index]] for index in (first, second)],
            "posed": [[round(value, 6) for value in posed[index]] for index in (first, second)],
            "materials": [sorted(materials[index]) for index in (first, second)],
            "weights": endpoint_weights,
            "families": [sorted({family(name) for name in values}) for values in endpoint_weights],
        })
    by_length = sorted(rows, key=lambda row: (row["after_m"], row["ratio"]), reverse=True)
    by_ratio = sorted(rows, key=lambda row: (row["ratio"], row["after_m"]), reverse=True)
    cross_family = [row for row in by_length if row["families"][0] != row["families"][1]]
    cross_family_counts: dict[str, int] = {}
    cross_source_counts: dict[str, int] = {}
    for row in cross_family:
        family_key = " -> ".join("+".join(values) for values in row["families"])
        source_key = " -> ".join(row["sources"])
        cross_family_counts[family_key] = cross_family_counts.get(family_key, 0) + 1
        cross_source_counts[source_key] = cross_source_counts.get(source_key, 0) + 1
    top_cross_by_side_and_height = {}
    for side, predicate in (
        ("L_lower", lambda midpoint: midpoint.x < 0.0 and midpoint.z < 1.25),
        ("L_upper", lambda midpoint: midpoint.x < 0.0 and midpoint.z >= 1.25),
        ("R_lower", lambda midpoint: midpoint.x >= 0.0 and midpoint.z < 1.25),
        ("R_upper", lambda midpoint: midpoint.x >= 0.0 and midpoint.z >= 1.25),
    ):
        selected = []
        for row in cross_family:
            midpoint = sum((rest[index] for index in row["indices"]), Vector()) * 0.5
            if predicate(midpoint):
                selected.append(row)
        top_cross_by_side_and_height[side] = selected[:12]
    return {
        "vertices": len(obj.data.vertices),
        "edges": len(obj.data.edges),
        "materials": [item.name if item else "<null>" for item in obj.data.materials],
        "candidate_edges": len(rows),
        "top_by_after_length": by_length[:40],
        "top_by_ratio": by_ratio[:40],
        "top_cross_family_by_after_length": cross_family[:40],
        "cross_family_counts": dict(sorted(cross_family_counts.items())),
        "cross_source_counts": dict(sorted(cross_source_counts.items())),
        "top_cross_by_side_and_height": top_cross_by_side_and_height,
    }


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND), load_ui=False, use_scripts=False)
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    meshes = [
        obj for obj in bpy.data.objects
        if obj.type == "MESH" and any(modifier.type == "ARMATURE" and modifier.object == armature for modifier in obj.modifiers)
    ]
    assert {obj.name for obj in meshes} == {"GV2_Body", "GV2_Face", "GV2_Cape"}, [obj.name for obj in meshes]
    reset_pose(armature)
    source = {obj.name: [vertex.co.copy() for vertex in obj.data.vertices] for obj in meshes}
    neutral = {obj.name: evaluated_points(obj) for obj in meshes}
    neutral_error = {
        obj.name: max((first - second).length for first, second in zip(source[obj.name], neutral[obj.name], strict=True))
        for obj in meshes
    }
    assert max(neutral_error.values()) < 1.0e-5, neutral_error

    samples = {}
    for state, progress in (
        ("grapple", 15.0 / 29.0),
        ("strike", 13.0 / 29.0),
        ("crouch", 1.0),
        ("evade", 13.0 / 29.0),
        ("walk_left_contact", 0.0),
        ("walk_right_contact", 0.5),
    ):
        metadata = apply_sample(armature, state, progress)
        mesh_reports = {}
        for obj in meshes:
            mesh_reports[obj.name] = analyze_mesh(obj, source[obj.name], evaluated_points(obj))
        samples[state] = {"pose": metadata, "meshes": mesh_reports}

    report = {
        "status": "PASS_DIAGNOSTIC",
        "blend": str(BLEND.relative_to(REPO)),
        "blend_pose_note": "Direct target-equivalent sample in Godot YXZ/rest-aware axes; capture has preceding-frame easing, so numeric severity is diagnostic rather than pixel-exact.",
        "neutral_max_error_m": neutral_error,
        "samples": samples,
    }
    OUT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    summary = {}
    for state, sample in samples.items():
        summary[state] = {
            name: values["top_by_after_length"][0] if values["top_by_after_length"] else None
            for name, values in sample["meshes"].items()
        }
    print("V4_R2_ACTION_SPIKE_DIAGNOSIS", json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
