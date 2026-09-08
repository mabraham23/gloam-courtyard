"""Build a compact loopable body-space retarget reference from a CMU BVH.

The output contains only sampled transforms needed by the runtime adapter. The
frozen Gloam Vigil model and weights are never opened or changed.
"""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


raw_args = sys.argv[sys.argv.index("--") + 1 :]
parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("destination", type=Path)
parser.add_argument("target_glb", type=Path)
parser.add_argument("--cycle-start", type=float, default=7.0)
parser.add_argument("--cycle-end", type=float, default=90.0)
parser.add_argument("--sample-count", type=int, default=48)
parser.add_argument(
    "--source-label",
    default="CMU Graphics Lab 16_45 run/jog, Bruce Hahne BVH conversion",
)
parser.add_argument("--left-contact", type=float, nargs=2, default=(0.0, 0.44))
parser.add_argument("--right-contact", type=float, nargs=2, default=(0.48, 0.94))
options = parser.parse_args(raw_args)

source = options.source.resolve()
destination = options.destination.resolve()
target_glb = options.target_glb.resolve()
CYCLE_START = options.cycle_start
CYCLE_END = options.cycle_end
SAMPLE_COUNT = options.sample_count


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

MAPPING = {
    "pelvis": "Hips",
    "spine": "LowerBack",
    "spine_upper": "Spine",
    "chest": "Spine1",
    "neck": "Neck1",
    "head": "Head",
    # The frozen target's side suffixes are spatially mirrored relative to its
    # -Y face direction. Map by actual limb position so the alignment stays a
    # proper rotation; reflecting the rotations made the arms cross the chest.
    "clavicle.L": "RightShoulder",
    "upper_arm.L": "RightArm",
    "forearm.L": "RightForeArm",
    "hand.L": "RightHand",
    "thigh.L": "RightUpLeg",
    "shin.L": "RightLeg",
    "foot.L": "RightFoot",
    "ball.L": "RightToeBase",
    "toe.L": "RightToeBase",
    "clavicle.R": "LeftShoulder",
    "upper_arm.R": "LeftArm",
    "forearm.R": "LeftForeArm",
    "hand.R": "LeftHand",
    "thigh.R": "LeftUpLeg",
    "shin.R": "LeftLeg",
    "foot.R": "LeftFoot",
    "ball.R": "LeftToeBase",
    "toe.R": "LeftToeBase",
}


def set_frame(value: float) -> None:
    whole = math.floor(value)
    bpy.context.scene.frame_set(whole, subframe=value - whole)


def quat_list(q: Quaternion) -> list[float]:
    q.normalize()
    return [float(q.w), float(q.x), float(q.y), float(q.z)]


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_anim.bvh(
    filepath=str(source),
    global_scale=0.01,
    frame_start=1,
    use_fps_scale=False,
    update_scene_fps=True,
)
source_armature = bpy.context.object
scene = bpy.context.scene

# Bring in the frozen target read-only. Retargeting is evaluated against its
# actual rest axes, then emitted as a separate JSON resource.
bpy.ops.import_scene.gltf(filepath=str(target_glb))
target_armature = next(
    obj for obj in scene.objects if obj.type == "ARMATURE" and obj != source_armature
)


def lateral_up(armature, pelvis: str, left_hip: str, right_hip: str, head: str) -> tuple[Vector, Vector]:
    bones = armature.data.bones
    center = bones[pelvis].head_local
    # Named sides make this independent of the source/target X sign.
    right = (bones[right_hip].head_local - bones[left_hip].head_local).normalized()
    up = (bones[head].tail_local - center).normalized()
    up = (up - right * up.dot(right)).normalized()
    return right, up


source_right, source_up = lateral_up(source_armature, "Hips", "LeftUpLeg", "RightUpLeg", "Head")
set_frame(CYCLE_START)
source_start = source_armature.pose.bones["Hips"].head.copy()
set_frame(CYCLE_END)
source_end = source_armature.pose.bones["Hips"].head.copy()
source_forward = source_end - source_start
source_forward -= source_right * source_forward.dot(source_right)
source_forward -= source_up * source_forward.dot(source_up)
source_forward.normalize()
source_basis = Matrix((source_right, source_up, source_forward)).transposed()

_target_named_right, target_up = lateral_up(target_armature, "pelvis", "thigh.L", "thigh.R", "head")
target_bones = target_armature.data.bones
# Match the source's spatial right side (-X) rather than the target's mirrored
# name suffix. Side-paired channels above are swapped for the same reason.
target_right = (target_bones["thigh.L"].head_local - target_bones["thigh.R"].head_local).normalized()
target_eye_midpoint = (target_bones["eye.L"].head_local + target_bones["eye.R"].head_local) * 0.5
target_forward = target_eye_midpoint - target_bones["head"].head_local
target_forward -= target_right * target_forward.dot(target_right)
target_forward -= target_up * target_forward.dot(target_up)
target_forward.normalize()
target_basis = Matrix((target_right, target_up, target_forward)).transposed()
source_to_target = target_basis @ source_basis.inverted()
print("CMU_RETARGET_SOURCE_BASIS", [[round(v, 6) for v in row] for row in source_basis])
print("CMU_RETARGET_TARGET_BASIS", [[round(v, 6) for v in row] for row in target_basis])
print("CMU_RETARGET_ALIGNMENT", [[round(v, 6) for v in row] for row in source_to_target])
print(
    "CMU_RETARGET_TARGET_LANDMARKS",
    {
        name: [round(float(v), 6) for v in target_armature.data.bones[name].head_local]
        for name in ("pelvis", "head", "thigh.L", "thigh.R", "shin.L", "foot.L")
    },
)

# Blender glTF target space is X-right, Z-up and -Y-forward. Convert the final
# body-space deltas back to Godot's X-right, Y-up and -Z-forward coordinates.
conversion = Matrix(((1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, -1.0, 0.0)))

set_frame(1.0)
baseline_basis = {
    source_name: source_armature.pose.bones[source_name].matrix_basis.to_quaternion().copy()
    for source_name in set(MAPPING.values())
}
baseline_source_global = {
    source_name: source_armature.pose.bones[source_name].matrix.to_quaternion().to_matrix()
    for source_name in set(MAPPING.values())
}

target_rest_global = {
    bone.name: bone.matrix_local.to_quaternion().to_matrix()
    for bone in target_armature.data.bones
}
target_local_rest = {}
for bone in target_armature.data.bones:
    if bone.parent is None:
        target_local_rest[bone.name] = target_rest_global[bone.name]
    else:
        target_local_rest[bone.name] = target_rest_global[bone.parent.name].inverted() @ target_rest_global[bone.name]

rest_offsets = {}
for target_name, source_name in MAPPING.items():
    aligned_source_rest = source_to_target @ baseline_source_global[source_name] @ source_to_target.inverted()
    rest_offsets[target_name] = aligned_source_rest.inverted() @ target_rest_global[target_name]


def body_deltas() -> dict[str, Quaternion]:
    desired_globals = {}
    for bone in target_armature.data.bones:
        target_name = bone.name
        if target_name in ("clavicle.L", "clavicle.R"):
            # Target clavicles are already in a relaxed costume-ready rest,
            # whereas the BVH's added calibration frame is a full T-pose.
            # Follow the animated chest without importing that calibration gap.
            desired_globals[target_name] = desired_globals[bone.parent.name] @ target_local_rest[target_name]
        elif target_name in ("upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"):
            # Retarget arm *directions* in global space. Applying a T-pose delta
            # to this target's already-lowered rest arms rotates them down twice
            # and creates the rejected shoulder-height chest crossing.
            source_bone = source_armature.pose.bones[MAPPING[target_name]]
            source_direction = (source_bone.tail - source_bone.head).normalized()
            desired_direction = (source_to_target @ source_direction).normalized()
            target_direction = (bone.tail_local - bone.head_local).normalized()
            swing = target_direction.rotation_difference(desired_direction).to_matrix()
            desired_globals[target_name] = swing @ target_rest_global[target_name]
        elif target_name in MAPPING:
            source_name = MAPPING[target_name]
            source_current = source_armature.pose.bones[source_name].matrix.to_quaternion().to_matrix()
            aligned_source = source_to_target @ source_current @ source_to_target.inverted()
            desired_globals[target_name] = aligned_source @ rest_offsets[target_name]
        elif bone.parent is None:
            desired_globals[target_name] = target_rest_global[target_name]
        else:
            desired_globals[target_name] = desired_globals[bone.parent.name] @ target_local_rest[target_name]

    result = {}
    for target_name in MAPPING:
        bone = target_armature.data.bones[target_name]
        parent_global = Matrix.Identity(3) if bone.parent is None else desired_globals[bone.parent.name]
        local_desired = parent_global.inverted() @ desired_globals[target_name]
        local_delta = target_local_rest[target_name].inverted() @ local_desired
        delta_blender = target_rest_global[target_name] @ local_delta @ target_rest_global[target_name].inverted()
        delta_godot = conversion @ delta_blender @ conversion.inverted()
        result[target_name] = delta_godot.to_quaternion().normalized()
    return result


def sample_at(frame: float) -> tuple[dict[str, Quaternion], list[float]]:
    set_frame(frame)
    rotations = body_deltas()
    hips = source_armature.pose.bones["Hips"].head
    root_target = source_to_target @ hips
    root = conversion @ root_target
    return rotations, [float(root.x), float(root.y), float(root.z)]


start_rotations, start_root = sample_at(CYCLE_START)
end_rotations, end_root = sample_at(CYCLE_END)
seam = {
    target: start_rotations[target] @ end_rotations[target].inverted()
    for target in MAPPING
}

samples = []
previous = {}
for index in range(SAMPLE_COUNT):
    phase = index / SAMPLE_COUNT
    frame = CYCLE_START + (CYCLE_END - CYCLE_START) * phase
    rotations, root = sample_at(frame)
    encoded = {}
    for target, value in rotations.items():
        correction = Quaternion().slerp(seam[target], phase)
        looped = (correction @ value).normalized()
        if target in previous and previous[target].dot(looped) < 0.0:
            looped.negate()
        previous[target] = looped.copy()
        encoded[target] = quat_list(looped)
    corrected_root = [
        root[axis] - (end_root[axis] - start_root[axis]) * phase
        for axis in range(3)
    ]
    samples.append({"rotations": encoded, "root": corrected_root})

for axis in range(3):
    mean = sum(sample["root"][axis] for sample in samples) / SAMPLE_COUNT
    for sample in samples:
        sample["root"][axis] -= mean

payload = {
    "format": "gloam-cmu-body-delta-v1",
    "source": options.source_label,
    "source_sha256": sha256(source),
    "source_fps": int(round(scene.render.fps)),
    "cycle_source_frames": [CYCLE_START, CYCLE_END],
    "cycle_seconds": (CYCLE_END - CYCLE_START) / scene.render.fps,
    "sample_count": SAMPLE_COUNT,
    # Source R drives target L because the frozen GLB's side suffixes are
    # spatially mirrored; preserve contact ownership after the pair swap.
    "contact_windows": {
        "L": [float(value) for value in options.left_contact],
        "R": [float(value) for value in options.right_contact],
    },
    "samples": samples,
}
destination.write_text(json.dumps(payload, separators=(",", ":")))
print(
    "CMU_RETARGET_BUILD_OK "
    f"samples={SAMPLE_COUNT} cycle_seconds={payload['cycle_seconds']:.6f} output={destination}"
)
