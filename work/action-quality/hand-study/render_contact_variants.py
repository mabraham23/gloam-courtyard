"""Render five bounded R7 contact-hand variants from the frozen source.

The comparison deliberately favors proximal/MCP flexion and limits PIP/DIP
curl so a contact pose cannot form the long U/loop silhouette seen in the
earlier tuned-v3 fist.  Each right-hand profile is rendered from the finger
curl plane and from the palmar-normal view.  The source and GLB are never
saved or exported, and existing evidence is never overwritten.
"""

from __future__ import annotations

import importlib.util
import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


HERE = Path(__file__).resolve().parent
OUTPUT_DIR = HERE / "contact-v1"
MEASURE_PATH = HERE / "measure_hand_axes.py"
spec = importlib.util.spec_from_file_location("measure_hand_axes", MEASURE_PATH)
assert spec is not None and spec.loader is not None
MEASURE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(MEASURE)

# Degrees for .01/.02/.03.  These are diagnostic candidates, not production
# constants.  The intentionally low distal values are the variable under test.
PROFILES = {
    "strike-a-soft": {
        "index": (44, 24, 6), "middle": (46, 26, 6),
        "ring": (48, 28, 8), "pinky": (50, 30, 10),
        "thumb_flex": (7, 7, 2), "thumb_opp": (20, 8, 2),
    },
    "strike-b-compact": {
        "index": (52, 28, 6), "middle": (54, 30, 7),
        "ring": (56, 32, 8), "pinky": (58, 34, 10),
        "thumb_flex": (9, 9, 3), "thumb_opp": (24, 10, 2),
    },
    "strike-c-thumb-wrap": {
        "index": (50, 28, 7), "middle": (52, 30, 8),
        "ring": (54, 32, 9), "pinky": (56, 34, 11),
        "thumb_flex": (12, 10, 4), "thumb_opp": (30, 12, 3),
    },
    "takedown-a-reach": {
        "index": (24, 16, 4), "middle": (28, 18, 4),
        "ring": (32, 20, 5), "pinky": (36, 22, 6),
        "thumb_flex": (5, 5, 2), "thumb_opp": (14, 6, 1),
    },
    "takedown-b-secure": {
        "index": (32, 22, 5), "middle": (36, 24, 6),
        "ring": (40, 26, 7), "pinky": (44, 28, 8),
        "thumb_flex": (7, 7, 2), "thumb_opp": (20, 8, 2),
    },
}


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_scene() -> bpy.types.Object:
    for obj in list(bpy.data.objects):
        if obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    world = bpy.context.scene.world or bpy.data.worlds.new("ContactStudyWorld")
    bpy.context.scene.world = world
    world.color = (0.022, 0.027, 0.038)
    for name, location, energy, size in (
        ("ContactKey", (-2.0, -3.0, 3.2), 800.0, 2.0),
        ("ContactFill", (2.3, -2.0, 2.5), 650.0, 1.8),
        ("ContactRim", (0.0, 2.0, 2.7), 700.0, 1.6),
    ):
        data = bpy.data.lights.new(f"{name}Data", "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = location
        look_at(light, Vector((0.0, 0.0, 1.0)))
    camera_data = bpy.data.cameras.new("ContactStudyCameraData")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 0.37
    camera = bpy.data.objects.new("ContactStudyCamera", camera_data)
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


def measured_axes(
    armature: bpy.types.Object,
) -> tuple[dict[str, Vector], dict[str, Vector], dict[str, tuple[Vector, Vector, Vector]]]:
    flex: dict[str, Vector] = {}
    opposition: dict[str, Vector] = {}
    frames: dict[str, tuple[Vector, Vector, Vector]] = {}
    for side, sign in MEASURE.SIDES:
        _wrist, longitudinal, across, palm_normal = MEASURE.palm_frame(armature, side, sign)
        frames[side] = (longitudinal, across, palm_normal)
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
    return flex, opposition, frames


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
                MEASURE.anatomical_axis_angle(
                    armature,
                    name,
                    flex[name],
                    math.radians(degrees),
                )
        for segment, (flex_degrees, opposition_degrees) in enumerate(
            zip(profile["thumb_flex"], profile["thumb_opp"], strict=True),
            start=1,
        ):
            name = f"thumb.{segment:02d}.{side}"
            rest = armature.data.bones[name].matrix_local.to_quaternion()
            body_delta = (
                Quaternion(opposition[name], math.radians(opposition_degrees))
                @ Quaternion(flex[name], math.radians(flex_degrees))
            )
            armature.pose.bones[name].rotation_quaternion = rest.inverted() @ body_delta @ rest
    bpy.context.view_layer.update()


def posed_point(armature: bpy.types.Object, bone_name: str, local_y: float) -> Vector:
    return armature.pose.bones[bone_name].matrix @ Vector((0.0, local_y, 0.0))


def profile_metrics(
    armature: bpy.types.Object,
    frames: dict[str, tuple[Vector, Vector, Vector]],
) -> dict[str, object]:
    result: dict[str, object] = {}
    for side, _sign in MEASURE.SIDES:
        _longitudinal, _across, palm_normal = frames[side]
        palm_target = sum(
            (
                armature.pose.bones[f"{finger}.01.{side}"].matrix.translation
                for finger in ("index", "middle", "ring")
            ),
            Vector(),
        ) / 3.0
        rows: dict[str, object] = {}
        for finger in MEASURE.FINGERS:
            name = f"{finger}.03.{side}"
            tip = posed_point(armature, name, armature.pose.bones[name].length)
            rows[finger] = {
                "tip_to_palm_target_mm": round((tip - palm_target).length * 1000.0, 3),
                "tip_palmar_offset_mm": round((tip - palm_target).dot(palm_normal) * 1000.0, 3),
            }
        result[side] = rows
    return result


def main() -> None:
    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    expected = [
        OUTPUT_DIR / f"{profile}-{view}.png"
        for profile in PROFILES
        for view in ("curl-plane", "palm")
    ]
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
    flex, opposition, frames = measured_axes(armature)
    side = "R"
    hand = armature.data.bones[f"hand.{side}"]
    target = (hand.head_local + hand.tail_local) * 0.5 + Vector((0.0, 0.0, -0.035))
    metrics: dict[str, object] = {}
    for profile_name, profile in PROFILES.items():
        MEASURE.reset_pose(armature)
        apply_profile(armature, profile, flex, opposition)
        metrics[profile_name] = profile_metrics(armature, frames)
        views = {
            "curl-plane": flex[f"middle.01.{side}"].copy(),
            "palm": frames[side][2].copy(),
        }
        for view_name, view in views.items():
            if view.y > 0.0:
                view.negate()
            camera.location = target + view.normalized() * 2.0
            look_at(camera, target)
            bpy.context.scene.render.filepath = str(OUTPUT_DIR / f"{profile_name}-{view_name}.png")
            bpy.ops.render.render(write_still=True)
    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    print("CONTACT_VARIANT_METRICS " + json.dumps(metrics, sort_keys=True))
    print(
        "CONTACT_VARIANT_RENDERS PASS "
        f"profiles={len(PROFILES)} images={len(expected)} "
        f"source={MEASURE.EXPECTED_SOURCE_SHA256} glb={MEASURE.EXPECTED_GLB_SHA256}"
    )


if __name__ == "__main__":
    main()
