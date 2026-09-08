"""Read-only coordinate and kinematic audit for the CMU-to-R7 retarget.

Run with Blender so both the source BVH and frozen target GLB are evaluated in
their native Blender spaces.  This script does not save either asset.
"""

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


args = sys.argv[sys.argv.index("--") + 1 :]
source_path = Path(args[0]).resolve()
target_path = Path(args[1]).resolve()
data_path = Path(args[2]).resolve()

MAPPING = {
    "pelvis": "Hips",
    "spine": "LowerBack",
    "spine_upper": "Spine",
    "chest": "Spine1",
    "neck": "Neck1",
    "head": "Head",
    "clavicle.L": "LeftShoulder",
    "upper_arm.L": "LeftArm",
    "forearm.L": "LeftForeArm",
    "hand.L": "LeftHand",
    "thigh.L": "LeftUpLeg",
    "shin.L": "LeftLeg",
    "foot.L": "LeftFoot",
    "ball.L": "LeftToeBase",
    "toe.L": "LeftToeBase",
    "clavicle.R": "RightShoulder",
    "upper_arm.R": "RightArm",
    "forearm.R": "RightForeArm",
    "hand.R": "RightHand",
    "thigh.R": "RightUpLeg",
    "shin.R": "RightLeg",
    "foot.R": "RightFoot",
    "ball.R": "RightToeBase",
    "toe.R": "RightToeBase",
}


def vec(v: Vector) -> list[float]:
    return [round(float(v.x), 6), round(float(v.y), 6), round(float(v.z), 6)]


def deg(q: Quaternion) -> float:
    normalized = q.normalized()
    if normalized.w < 0.0:
        normalized.negate()
    return round(math.degrees(normalized.angle), 3)


def anatomical_basis(armature, pelvis: str, left_hip: str, right_hip: str, head: str) -> Matrix:
    bones = armature.data.bones
    center = bones[pelvis].head_local
    right = (bones[right_hip].head_local - bones[left_hip].head_local).normalized()
    up = (bones[head].tail_local - center).normalized()
    up = (up - right * up.dot(right)).normalized()
    forward = up.cross(right).normalized()
    return Matrix((right, up, forward)).transposed()


def set_frame(frame: float) -> None:
    whole = math.floor(frame)
    bpy.context.scene.frame_set(whole, subframe=frame - whole)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_anim.bvh(
    filepath=str(source_path),
    global_scale=0.01,
    frame_start=1,
    use_fps_scale=False,
    update_scene_fps=True,
)
source = bpy.context.object
bpy.ops.import_scene.gltf(filepath=str(target_path))
target = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE" and obj != source)

source_basis = anatomical_basis(source, "Hips", "LeftUpLeg", "RightUpLeg", "Head")
target_basis = anatomical_basis(target, "pelvis", "thigh.L", "thigh.R", "head")
alignment = target_basis @ source_basis.inverted()
conversion = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, -1.0, 0.0)))

set_frame(7.0)
start_hip = source.pose.bones["Hips"].head.copy()
set_frame(90.0)
end_hip = source.pose.bones["Hips"].head.copy()
source_travel = end_hip - start_hip
aligned_travel = alignment @ source_travel

print("RETARGET_AUDIT basis")
print(" source_right_up_forward", *(vec(source_basis.col[index]) for index in range(3)))
print(" target_right_up_forward", *(vec(target_basis.col[index]) for index in range(3)))
print(" source_travel", vec(source_travel), "source_forward_dot", round(source_travel.normalized().dot(source_basis.col[2]), 6))
print(" aligned_travel", vec(aligned_travel), "target_forward_dot", round(aligned_travel.normalized().dot(target_basis.col[2]), 6))
print(" source_object", vec(source.location), vec(source.rotation_euler), vec(source.scale))
print(" target_object", vec(target.location), vec(target.rotation_euler), vec(target.scale))
target_pelvis = target.data.bones["pelvis"].head_local
eye_midpoint = (target.data.bones["eye.L"].head_local + target.data.bones["eye.R"].head_local) * 0.5
head_center = target.data.bones["head"].head_local
source_forward = source_travel - source_basis.col[1] * source_travel.dot(source_basis.col[1])
source_forward.normalize()
target_forward = eye_midpoint - head_center
target_forward -= target_basis.col[1] * target_forward.dot(target_basis.col[1])
target_forward -= target_basis.col[0] * target_forward.dot(target_basis.col[0])
target_forward.normalize()
source_motion_basis = Matrix((source_basis.col[0], source_basis.col[1], source_forward)).transposed()
target_motion_basis = Matrix((target_basis.col[0], target_basis.col[1], target_forward)).transposed()
corrected_alignment = target_motion_basis @ source_motion_basis.inverted()
print(
    " target_head_to_eyes_RUF",
    vec(target_basis.inverted() @ (eye_midpoint - head_center)),
    "target_pelvis_to_head_RUF",
    vec(target_basis.inverted() @ (head_center - target_pelvis)),
)
print(
    " corrected_source_forward", vec(source_forward),
    "corrected_target_forward", vec(target_forward),
    "source_frame_det", round(source_motion_basis.determinant(), 6),
    "target_frame_det", round(target_motion_basis.determinant(), 6),
    "alignment_det", round(corrected_alignment.determinant(), 6),
    "mapped_travel", vec(corrected_alignment @ source_travel),
)
for side in ["L", "R"]:
    hip = target.data.bones[f"thigh.{side}"].head_local
    knee = target.data.bones[f"shin.{side}"].head_local
    ankle = target.data.bones[f"foot.{side}"].head_local
    print(
        " target_leg", side,
        "upper", round((knee - hip).length, 6),
        "lower", round((ankle - knee).length, 6),
        "total", round((knee - hip).length + (ankle - knee).length, 6),
        "world_total_at_1.35", round(((knee - hip).length + (ankle - knee).length) * 1.35, 6),
    )

data = json.loads(data_path.read_text())
target_rest_global = {
    bone.name: bone.matrix_local.to_quaternion().normalized()
    for bone in target.data.bones
}
target_rest_local = {}
target_rest_origin = {}
for bone in target.data.bones:
    local_matrix = bone.matrix_local if bone.parent is None else bone.parent.matrix_local.inverted() @ bone.matrix_local
    target_rest_local[bone.name] = local_matrix.to_quaternion().normalized()
    target_rest_origin[bone.name] = local_matrix.translation.copy()


def godot_body_to_blender(values: list[float]) -> Quaternion:
    godot = Quaternion((values[0], values[1], values[2], values[3])).normalized()
    blender_matrix = conversion.inverted() @ godot.to_matrix() @ conversion
    return blender_matrix.to_quaternion().normalized()


def target_pose(sample: dict) -> tuple[dict[str, Quaternion], dict[str, Vector]]:
    body = {name: godot_body_to_blender(values) for name, values in sample["rotations"].items()}
    global_rotation = {}
    global_position = {}
    for bone in target.data.bones:
        name = bone.name
        delta = body.get(name, Quaternion())
        local_delta = target_rest_global[name].inverted() @ delta @ target_rest_global[name]
        pose_local = (target_rest_local[name] @ local_delta).normalized()
        if bone.parent is None:
            global_rotation[name] = pose_local
            global_position[name] = target_rest_origin[name]
        else:
            parent_name = bone.parent.name
            global_rotation[name] = (global_rotation[parent_name] @ pose_local).normalized()
            global_position[name] = global_position[parent_name] + global_rotation[parent_name] @ target_rest_origin[name]
    return global_rotation, global_position


def target_pose_from_blender_body(body: dict[str, Quaternion]) -> tuple[dict[str, Quaternion], dict[str, Vector]]:
    global_rotation = {}
    global_position = {}
    for bone in target.data.bones:
        name = bone.name
        delta = body.get(name, Quaternion())
        local_delta = target_rest_global[name].inverted() @ delta @ target_rest_global[name]
        pose_local = (target_rest_local[name] @ local_delta).normalized()
        if bone.parent is None:
            global_rotation[name] = pose_local
            global_position[name] = target_rest_origin[name]
        else:
            parent_name = bone.parent.name
            global_rotation[name] = (global_rotation[parent_name] @ pose_local).normalized()
            global_position[name] = global_position[parent_name] + global_rotation[parent_name] @ target_rest_origin[name]
    return global_rotation, global_position


set_frame(1.0)
corrected_source_rest = {
    source_name: source.pose.bones[source_name].matrix.to_quaternion().to_matrix()
    for source_name in set(MAPPING.values())
}
corrected_rest_offsets = {}
for target_name, source_name in MAPPING.items():
    aligned_rest = corrected_alignment @ corrected_source_rest[source_name] @ corrected_alignment.inverted()
    corrected_rest_offsets[target_name] = aligned_rest.inverted() @ target_rest_global[target_name].to_matrix()


def corrected_body(frame: float) -> dict[str, Quaternion]:
    set_frame(frame)
    desired = {}
    for bone in target.data.bones:
        name = bone.name
        if name in MAPPING:
            source_name = MAPPING[name]
            source_current = source.pose.bones[source_name].matrix.to_quaternion().to_matrix()
            aligned = corrected_alignment @ source_current @ corrected_alignment.inverted()
            desired[name] = aligned @ corrected_rest_offsets[name]
        elif bone.parent is None:
            desired[name] = target_rest_global[name].to_matrix()
        else:
            desired[name] = desired[bone.parent.name] @ target_rest_local[name].to_matrix()
    result = {}
    for name in MAPPING:
        bone = target.data.bones[name]
        parent_global = Matrix.Identity(3) if bone.parent is None else desired[bone.parent.name]
        local_desired = parent_global.inverted() @ desired[name]
        local_delta = target_rest_local[name].to_matrix().inverted() @ local_desired
        result[name] = (target_rest_global[name].to_matrix() @ local_delta @ target_rest_global[name].to_matrix().inverted()).to_quaternion().normalized()
    return result


def bend(a: Vector, b: Vector, c: Vector) -> float:
    upper = (b - a).normalized()
    lower = (c - b).normalized()
    return math.degrees(upper.angle(lower))


print("RETARGET_AUDIT sampled_target_kinematics")
for index in range(0, len(data["samples"]), 4):
    rotations, positions = target_pose(data["samples"][index])
    pelvis = positions["pelvis"]
    chest_offset = positions["chest"] - pelvis
    basis_components = target_basis.inverted() @ chest_offset
    line = [
        " sample", index,
        "phase", round(index / len(data["samples"]), 4),
        "chest_RUF", vec(basis_components),
    ]
    for side in ["L", "R"]:
        hip = positions[f"thigh.{side}"]
        knee = positions[f"shin.{side}"]
        ankle = positions[f"foot.{side}"]
        foot_ruf = target_basis.inverted() @ (ankle - pelvis)
        line.extend([
            f"knee_{side}", round(bend(hip, knee, ankle), 2),
            f"foot_{side}_RUF", vec(foot_ruf),
        ])
    print(*line)

print("RETARGET_AUDIT body_delta_ranges")
for name in MAPPING:
    angles = [deg(godot_body_to_blender(sample["rotations"][name])) for sample in data["samples"]]
    print(name, min(angles), max(angles))

print("RETARGET_AUDIT current_vs_corrected_actual_forward")
for index in [0, 12, 24, 36]:
    _, current_positions = target_pose(data["samples"][index])
    frame = 7.0 + (90.0 - 7.0) * index / len(data["samples"])
    _, corrected_positions = target_pose_from_blender_body(corrected_body(frame))
    current_chest = target_motion_basis.inverted() @ (current_positions["chest"] - current_positions["pelvis"])
    corrected_chest = target_motion_basis.inverted() @ (corrected_positions["chest"] - corrected_positions["pelvis"])
    print(
        " sample", index,
        "current_chest_RUF", vec(current_chest),
        "corrected_chest_RUF", vec(corrected_chest),
    )

corrected_start = corrected_body(7.0)
corrected_end = corrected_body(90.0)
seam_angles = sorted(
    ((deg(corrected_start[name] @ corrected_end[name].inverted()), name) for name in MAPPING),
    reverse=True,
)
print("RETARGET_AUDIT raw_cycle_seam_degrees", seam_angles)
