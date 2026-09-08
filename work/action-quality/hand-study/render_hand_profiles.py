"""Render bounded, read-only R7 hand-pose studies from the frozen source.

The output is diagnostic only.  It compares the exact current strike curl with
four palm-directed profiles without saving/exporting the Blender source.
"""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


HERE = Path(__file__).resolve().parent
OUTPUT_DIR = HERE / "tuned-v3"
MEASURE_PATH = HERE / "measure_hand_axes.py"
spec = importlib.util.spec_from_file_location("measure_hand_axes", MEASURE_PATH)
assert spec is not None and spec.loader is not None
MEASURE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(MEASURE)

PROFILES = {
    "relaxed": {
        "index": (2, 4, 2), "middle": (3, 6, 3),
        "ring": (4, 8, 4), "pinky": (6, 10, 6),
        "thumb_flex": (2, 4, 3), "thumb_opp": (4, 2, 0),
    },
    "fist": {
        "index": (55, 75, 30), "middle": (58, 80, 32),
        "ring": (60, 82, 34), "pinky": (62, 84, 36),
        "thumb_flex": (15, 28, 16), "thumb_opp": (40, 20, 6),
    },
    "grip": {
        "index": (30, 42, 28), "middle": (34, 46, 30),
        "ring": (38, 50, 32), "pinky": (42, 54, 34),
        "thumb_flex": (8, 16, 12), "thumb_opp": (24, 12, 4),
    },
    "brace": {
        "index": (0, 1, 0), "middle": (0, 0, 0),
        "ring": (1, 2, 1), "pinky": (2, 3, 2),
        "thumb_flex": (0, 1, 0), "thumb_opp": (0, 0, 0),
    },
}


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_scene() -> bpy.types.Object:
    for obj in list(bpy.data.objects):
        if obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    world = bpy.context.scene.world or bpy.data.worlds.new("HandStudyWorld")
    bpy.context.scene.world = world
    world.color = (0.022, 0.027, 0.038)
    for name, location, energy, size in (
        ("HandStudyKey", (-2.0, -3.0, 3.2), 800.0, 2.0),
        ("HandStudyFill", (2.3, -2.0, 2.5), 650.0, 1.8),
        ("HandStudyRim", (0.0, 2.0, 2.7), 700.0, 1.6),
    ):
        data = bpy.data.lights.new(f"{name}Data", "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = location
        look_at(light, Vector((0.0, 0.0, 1.0)))
    camera_data = bpy.data.cameras.new("HandStudyCameraData")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 0.42
    camera = bpy.data.objects.new("HandStudyCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.film_transparent = False
    return camera


def axes(armature: bpy.types.Object) -> tuple[dict[str, Vector], dict[str, Vector]]:
    flex: dict[str, Vector] = {}
    opposition: dict[str, Vector] = {}
    for side, sign in MEASURE.SIDES:
        _wrist, _longitudinal, _across, palm_normal = MEASURE.palm_frame(armature, side, sign)
        bases = {
            finger: armature.data.bones[f"{finger}.01.{side}"].head_local.copy()
            for finger in MEASURE.FINGERS
        }
        palm_target = sum((bases[name] for name in ("index", "middle", "ring")), Vector()) / 3.0
        for finger in MEASURE.FINGERS:
            for segment in range(1, 4):
                name = f"{finger}.{segment:02d}.{side}"
                bone = armature.data.bones[name]
                direction = (bone.tail_local - bone.head_local).normalized()
                flex[name] = direction.cross(palm_normal).normalized()
                target = palm_target - bone.head_local
                target -= direction * target.dot(direction)
                opposition[name] = direction.cross(target.normalized()).normalized()
    return flex, opposition


def apply_profile(
    armature: bpy.types.Object,
    profile: dict[str, tuple[int, int, int]],
    flex: dict[str, Vector],
    opposition: dict[str, Vector],
) -> None:
    for side, _sign in MEASURE.SIDES:
        for finger in ("index", "middle", "ring", "pinky"):
            for segment, degrees in enumerate(profile[finger], start=1):
                name = f"{finger}.{segment:02d}.{side}"
                MEASURE.anatomical_axis_angle(armature, name, flex[name], math.radians(degrees))
        for segment, (flex_degrees, opposition_degrees) in enumerate(
            zip(profile["thumb_flex"], profile["thumb_opp"], strict=True),
            start=1,
        ):
            name = f"thumb.{segment:02d}.{side}"
            rest = armature.data.bones[name].matrix_local.to_quaternion()
            delta = (
                Quaternion(opposition[name], math.radians(opposition_degrees))
                @ Quaternion(flex[name], math.radians(flex_degrees))
            )
            armature.pose.bones[name].rotation_quaternion = rest.inverted() @ delta @ rest
    bpy.context.view_layer.update()


def main() -> None:
    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    expected = [OUTPUT_DIR / f"{profile}-{side}.png" for profile in ("current-strike", *PROFILES) for side, _sign in MEASURE.SIDES]
    existing = [path for path in expected if path.exists()]
    if existing:
        raise RuntimeError(f"Preserve prior evidence; refusing to overwrite {existing}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(MEASURE.SOURCE), load_ui=False, use_scripts=False)
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.hide_render = obj.name != "GV2_Body"
    camera = setup_scene()
    flex, opposition = axes(armature)
    for profile_name in ("current-strike", *PROFILES):
        MEASURE.reset_pose(armature)
        if profile_name == "current-strike":
            MEASURE.current_curl(armature, 1.02)
        else:
            apply_profile(armature, PROFILES[profile_name], flex, opposition)
        for side, sign in MEASURE.SIDES:
            hand = armature.data.bones[f"hand.{side}"]
            target = (hand.head_local + hand.tail_local) * 0.5 + Vector((0.0, 0.0, -0.035))
            middle_axis = flex[f"middle.01.{side}"]
            view = middle_axis.copy()
            if view.y > 0.0:
                view.negate()
            camera.location = target + view.normalized() * 2.0
            look_at(camera, target)
            bpy.context.scene.render.filepath = str(OUTPUT_DIR / f"{profile_name}-{side}.png")
            bpy.ops.render.render(write_still=True)
    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    print(f"HAND_PROFILE_RENDERS PASS count={len(expected)} source={MEASURE.EXPECTED_SOURCE_SHA256} glb={MEASURE.EXPECTED_GLB_SHA256}")


if __name__ == "__main__":
    main()
