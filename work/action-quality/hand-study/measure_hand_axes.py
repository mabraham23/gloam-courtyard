"""Read-only R7 hand-axis diagnostic for the frozen v4 character source.

Loads the exact Blender source with embedded scripts disabled, measures the
actual palm plane and every phalanx chain, and compares the current runtime's
body-space +X curl with a palm-directed anatomical hinge.  It never saves the
source or exports an asset; JSON is printed to stdout for review.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Euler, Quaternion, Vector


REPO = Path("/Users/markabraham/dev/batman")
SOURCE = REPO / "actors/gloam_vigil/v4/source/gloam_vigil_player_v4.blend"
GLB = REPO / "actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"
EXPECTED_SOURCE_SHA256 = "40b4fca657e3ab91783ddeca2e2f02c87619f1daf89d245921397fc6f0669fdc"
EXPECTED_GLB_SHA256 = "faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a"
SIDES = (("L", -1.0), ("R", 1.0))
FINGERS = ("thumb", "index", "middle", "ring", "pinky")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def values(vector: Vector) -> list[float]:
    return [round(float(value), 8) for value in vector]


def godot_vector(blender: Vector) -> Vector:
    """Blender +Z-up/-Y-forward to exported Godot +Y-up/+Z-forward."""
    return Vector((blender.x, blender.z, -blender.y))


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
    euler: tuple[float, float, float],
) -> None:
    """Match the adapter's Godot body-axis YXZ Euler/rest conjugation."""
    rest = armature.data.bones[name].matrix_local.to_quaternion()
    delta = Euler(euler, "YXZ").to_quaternion()
    armature.pose.bones[name].rotation_quaternion = rest.inverted() @ delta @ rest


def anatomical_axis_angle(
    armature: bpy.types.Object,
    name: str,
    axis: Vector,
    angle: float,
) -> None:
    """Apply a measured Blender body-space hinge through imported rest axes."""
    rest = armature.data.bones[name].matrix_local.to_quaternion()
    delta = Quaternion(axis.normalized(), angle)
    armature.pose.bones[name].rotation_quaternion = rest.inverted() @ delta @ rest


def posed_tail(armature: bpy.types.Object, name: str) -> Vector:
    pose_bone = armature.pose.bones[name]
    return pose_bone.matrix @ Vector((0.0, pose_bone.length, 0.0))


def palm_frame(
    armature: bpy.types.Object,
    side: str,
    sign: float,
) -> tuple[Vector, Vector, Vector, Vector]:
    bones = armature.data.bones
    wrist = bones[f"hand.{side}"].head_local.copy()
    bases = {finger: bones[f"{finger}.01.{side}"].head_local.copy() for finger in FINGERS}
    long_bases = [bases[name] for name in ("index", "middle", "ring", "pinky")]
    knuckle_center = sum(long_bases, Vector()) / len(long_bases)
    longitudinal = (knuckle_center - wrist).normalized()
    across = bases["index"] - bases["pinky"]
    across = (across - longitudinal * across.dot(longitudinal)).normalized()
    palm_normal = longitudinal.cross(across).normalized()
    medial = Vector((-sign, 0.0, 0.0))
    if palm_normal.dot(medial) < 0.0:
        palm_normal.negate()
        across.negate()
    # Re-orthogonalize so axis comparisons are not contaminated by the slight
    # non-planarity of the measured MCP row.
    across = palm_normal.cross(longitudinal).normalized()
    return wrist, longitudinal, across, palm_normal


def current_curl(armature: bpy.types.Object, curl: float) -> None:
    for side, _sign in SIDES:
        for finger in FINGERS:
            character = 0.72 if finger == "thumb" else (0.88 if finger == "pinky" else 1.0)
            for segment in range(1, 4):
                scale = character * (0.72 + float(segment) * 0.12)
                anatomical_rotation(
                    armature,
                    f"{finger}.{segment:02d}.{side}",
                    (curl * scale, 0.0, 0.0),
                )
    bpy.context.view_layer.update()


def proposed_fist(
    armature: bpy.types.Object,
    flex_axes: dict[str, Vector],
    opposition_axes: dict[str, Vector],
) -> None:
    """Diagnostic fist only; values are evidence candidates, not production."""
    angles = {
        "index": (math.radians(58), math.radians(82), math.radians(56)),
        "middle": (math.radians(64), math.radians(88), math.radians(60)),
        "ring": (math.radians(68), math.radians(92), math.radians(64)),
        "pinky": (math.radians(72), math.radians(94), math.radians(66)),
    }
    for side, _sign in SIDES:
        for finger, segment_angles in angles.items():
            for segment, angle in enumerate(segment_angles, start=1):
                name = f"{finger}.{segment:02d}.{side}"
                anatomical_axis_angle(armature, name, flex_axes[name], angle)
        for segment, (opp, flex) in enumerate(
            zip((30.0, 18.0, 7.0), (16.0, 34.0, 24.0), strict=True),
            start=1,
        ):
            name = f"thumb.{segment:02d}.{side}"
            rest = armature.data.bones[name].matrix_local.to_quaternion()
            body_delta = (
                Quaternion(opposition_axes[name], math.radians(opp))
                @ Quaternion(flex_axes[name], math.radians(flex))
            )
            armature.pose.bones[name].rotation_quaternion = rest.inverted() @ body_delta @ rest
    bpy.context.view_layer.update()


def tip_motion(
    armature: bpy.types.Object,
    rest_tips: dict[str, Vector],
    frames: dict[str, tuple[Vector, Vector, Vector]],
) -> dict[str, dict[str, float]]:
    result: dict[str, dict[str, float]] = {}
    for side, _sign in SIDES:
        longitudinal, across, palm_normal = frames[side]
        for finger in FINGERS:
            name = f"{finger}.03.{side}"
            displacement = posed_tail(armature, name) - rest_tips[name]
            result[f"{finger}.{side}"] = {
                "displacement_m": round(displacement.length, 8),
                "toward_palm_m": round(displacement.dot(palm_normal), 8),
                "across_palm_m": round(displacement.dot(across), 8),
                "along_digit_m": round(displacement.dot(longitudinal), 8),
            }
    return result


def main() -> None:
    assert sha256(SOURCE) == EXPECTED_SOURCE_SHA256
    assert sha256(GLB) == EXPECTED_GLB_SHA256
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    assert len(armature.data.bones) == 74
    reset_pose(armature)

    frames: dict[str, tuple[Vector, Vector, Vector]] = {}
    rest_tips: dict[str, Vector] = {}
    flex_axes: dict[str, Vector] = {}
    opposition_axes: dict[str, Vector] = {}
    report: dict[str, object] = {
        "status": "READ_ONLY_DIAGNOSTIC",
        "source_sha256": EXPECTED_SOURCE_SHA256,
        "glb_sha256": EXPECTED_GLB_SHA256,
        "coordinate_mapping": "Blender(x,y,z)->Godot(x,z,-y)",
        "current_runtime_axis_godot": [1.0, 0.0, 0.0],
        "sides": {},
    }

    for side, sign in SIDES:
        wrist, longitudinal, across, palm_normal = palm_frame(armature, side, sign)
        frames[side] = (longitudinal, across, palm_normal)
        side_report: dict[str, object] = {
            "wrist_blender": values(wrist),
            "wrist_godot": values(godot_vector(wrist)),
            "palm_longitudinal_blender": values(longitudinal),
            "palm_longitudinal_godot": values(godot_vector(longitudinal)),
            "palm_across_index_to_pinky_blender": values(across),
            "palm_across_index_to_pinky_godot": values(godot_vector(across)),
            "palmar_normal_medial_blender": values(palm_normal),
            "palmar_normal_medial_godot": values(godot_vector(palm_normal)),
            "bones": {},
        }
        report["sides"][side] = side_report
        hand = armature.data.bones[f"hand.{side}"]
        hand_basis = hand.matrix_local.to_3x3()
        side_report["hand_bone"] = {
            "head_blender": values(hand.head_local),
            "tail_blender": values(hand.tail_local),
            "head_godot": values(godot_vector(hand.head_local)),
            "tail_godot": values(godot_vector(hand.tail_local)),
            "rest_local_x_in_body_godot": values(godot_vector(Vector(hand_basis.col[0]))),
            "rest_local_y_in_body_godot": values(godot_vector(Vector(hand_basis.col[1]))),
            "rest_local_z_in_body_godot": values(godot_vector(Vector(hand_basis.col[2]))),
        }
        bases = {
            finger: armature.data.bones[f"{finger}.01.{side}"].head_local.copy()
            for finger in FINGERS
        }
        palm_target = sum((bases[name] for name in ("index", "middle", "ring")), Vector()) / 3.0
        for finger in FINGERS:
            for segment in range(1, 4):
                name = f"{finger}.{segment:02d}.{side}"
                bone = armature.data.bones[name]
                direction = (bone.tail_local - bone.head_local).normalized()
                flex_axis = direction.cross(palm_normal).normalized()
                flex_axes[name] = flex_axis
                target = palm_target - bone.head_local
                target -= direction * target.dot(direction)
                if target.length < 1.0e-6:
                    target = palm_normal.copy()
                opposition_axis = direction.cross(target.normalized()).normalized()
                opposition_axes[name] = opposition_axis
                basis = bone.matrix_local.to_3x3()
                side_report["bones"][name] = {
                    "head_blender": values(bone.head_local),
                    "tail_blender": values(bone.tail_local),
                    "head_godot": values(godot_vector(bone.head_local)),
                    "tail_godot": values(godot_vector(bone.tail_local)),
                    "direction_blender": values(direction),
                    "direction_godot": values(godot_vector(direction)),
                    "rest_local_x_in_body_blender": values(Vector(basis.col[0])),
                    "rest_local_y_in_body_blender": values(Vector(basis.col[1])),
                    "rest_local_z_in_body_blender": values(Vector(basis.col[2])),
                    "flex_axis_body_blender": values(flex_axis),
                    "flex_axis_body_godot": values(godot_vector(flex_axis)),
                    "thumb_opposition_axis_body_blender": values(opposition_axis) if finger == "thumb" else None,
                    "thumb_opposition_axis_body_godot": values(godot_vector(opposition_axis)) if finger == "thumb" else None,
                    "current_plus_x_alignment_abs": round(abs(flex_axis.x), 8),
                }
                if segment == 3:
                    rest_tips[name] = bone.tail_local.copy()

    reset_pose(armature)
    current_curl(armature, 1.02)
    report["current_strike_tip_motion"] = tip_motion(armature, rest_tips, frames)
    reset_pose(armature)
    proposed_fist(armature, flex_axes, opposition_axes)
    report["candidate_fist_tip_motion"] = tip_motion(armature, rest_tips, frames)
    report["source_sha256_after"] = sha256(SOURCE)
    report["glb_sha256_after"] = sha256(GLB)
    assert report["source_sha256_after"] == EXPECTED_SOURCE_SHA256
    assert report["glb_sha256_after"] == EXPECTED_GLB_SHA256
    summary: dict[str, object] = {
        "palms": {
            side: {
                "longitudinal_godot": report["sides"][side]["palm_longitudinal_godot"],
                "across_godot": report["sides"][side]["palm_across_index_to_pinky_godot"],
                "palmar_normal_godot": report["sides"][side]["palmar_normal_medial_godot"],
                "hand_bone": report["sides"][side]["hand_bone"],
            }
            for side, _sign in SIDES
        },
        "digit_axes_godot": {
            side: {
                finger: {
                    "flex": report["sides"][side]["bones"][f"{finger}.01.{side}"]["flex_axis_body_godot"],
                    "thumb_opposition": report["sides"][side]["bones"][f"{finger}.01.{side}"]["thumb_opposition_axis_body_godot"],
                    "plus_x_alignment_abs": report["sides"][side]["bones"][f"{finger}.01.{side}"]["current_plus_x_alignment_abs"],
                }
                for finger in FINGERS
            }
            for side, _sign in SIDES
        },
        "current_strike_tip_motion": report["current_strike_tip_motion"],
        "candidate_fist_tip_motion": report["candidate_fist_tip_motion"],
    }
    print("HAND_AXIS_SUMMARY " + json.dumps(summary, sort_keys=True))
    print("HAND_AXIS_REPORT " + json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
