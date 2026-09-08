"""Extract a compact, inspectable trace from the licensed CMU 127_03 BVH.

Run with Blender so BVH channel ordering and hierarchy evaluation are handled by
the importer rather than approximated in the gameplay code. This is an analysis
and asset-build helper; it never edits the frozen Gloam Vigil source asset.
"""

import json
import math
import sys
from pathlib import Path

import bpy


def repo_arg(index: int) -> Path:
    args = sys.argv[sys.argv.index("--") + 1 :]
    return Path(args[index]).resolve()


source = repo_arg(0)
destination = repo_arg(1)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_anim.bvh(
    filepath=str(source),
    global_scale=0.01,
    frame_start=1,
    use_fps_scale=False,
    update_scene_fps=True,
)
armature = bpy.context.object
scene = bpy.context.scene
scene.frame_start = int(armature.animation_data.action.frame_range[0])
scene.frame_end = int(armature.animation_data.action.frame_range[1])

tracked = [
    "Hips",
    "LeftUpLeg",
    "LeftLeg",
    "LeftFoot",
    "LeftToeBase",
    "RightUpLeg",
    "RightLeg",
    "RightFoot",
    "RightToeBase",
    "LowerBack",
    "Spine",
    "Spine1",
    "Neck",
    "Head",
    "LeftArm",
    "LeftForeArm",
    "RightArm",
    "RightForeArm",
]

rows = []
for frame in range(scene.frame_start, scene.frame_end + 1):
    scene.frame_set(frame)
    bones = {}
    for name in tracked:
        bone = armature.pose.bones[name]
        matrix = armature.matrix_world @ bone.matrix
        rotation = matrix.to_quaternion()
        bones[name] = {
            "head": [float(v) for v in (armature.matrix_world @ bone.head)],
            "tail": [float(v) for v in (armature.matrix_world @ bone.tail)],
            "quaternion_wxyz": [rotation.w, rotation.x, rotation.y, rotation.z],
        }
    rows.append({"frame": frame, "time": (frame - 1) / scene.render.fps, "bones": bones})

payload = {
    "source": str(source),
    "fps": scene.render.fps,
    "frames": rows,
}
destination.write_text(json.dumps(payload, separators=(",", ":")))
print(f"CMU_RUN_EXTRACT_OK frames={len(rows)} fps={scene.render.fps} output={destination}")
