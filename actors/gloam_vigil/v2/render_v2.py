"""Render neutral and action review views from the generated v2 Blender file.

The script does not save pose or lighting changes back into the authored source.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


SCRIPT_DIR = Path(__file__).resolve().parent
BLEND_PATH = SCRIPT_DIR / "source" / "gloam_vigil_player_v2.blend"
RENDER_DIR = SCRIPT_DIR / "renders"


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def make_material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    return material


def add_studio() -> tuple[bpy.types.Object, bpy.types.Object]:
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "Review floor"
    floor.data.materials.append(make_material("Review floor material", (0.055, 0.060, 0.070, 1.0), 0.88))

    def area(name: str, location: tuple[float, float, float], energy: float, color: tuple[float, float, float], size: float) -> None:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.color = color
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = location
        look_at(light, (0.0, 0.0, 1.10))

    area("Neutral key", (-3.2, -4.2, 4.8), 1050.0, (1.0, 0.89, 0.78), 3.2)
    area("Cool fill", (3.6, -2.0, 3.2), 720.0, (0.64, 0.76, 1.0), 2.8)
    area("Cape rim", (1.3, 3.4, 4.0), 1050.0, (0.70, 0.80, 1.0), 2.4)
    area("Head softbox", (-0.8, -1.5, 4.8), 470.0, (1.0, 0.96, 0.91), 2.0)

    camera_data = bpy.data.cameras.new("ReviewCamera")
    camera_data.lens = 70.0
    camera_data.sensor_width = 36.0
    camera_data.dof.use_dof = False
    camera = bpy.data.objects.new("ReviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    return floor, camera


def reset_pose() -> None:
    armature = bpy.data.objects["GloamVigilV2Rig"]
    for bone in armature.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion.identity()
        bone.location = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)
    face = bpy.data.objects["GV2_Face"]
    for key in face.data.shape_keys.key_blocks:
        if key.name != "Basis":
            key.value = 0.0
    bpy.context.view_layer.update()


def set_local_euler(name: str, xyz: tuple[float, float, float]) -> None:
    bone = bpy.data.objects["GloamVigilV2Rig"].pose.bones[name]
    bone.rotation_mode = "XYZ"
    bone.rotation_euler = xyz


def set_action_pose() -> None:
    reset_pose()
    set_local_euler("pelvis", (math.radians(-7.0), math.radians(2.0), math.radians(-8.0)))
    set_local_euler("spine", (math.radians(8.0), math.radians(-3.0), math.radians(5.0)))
    set_local_euler("spine_upper", (math.radians(6.0), math.radians(4.0), math.radians(7.0)))
    set_local_euler("chest", (math.radians(-4.0), math.radians(5.0), math.radians(9.0)))
    set_local_euler("neck", (math.radians(2.0), math.radians(-4.0), math.radians(-8.0)))
    set_local_euler("head", (math.radians(-2.0), math.radians(2.0), math.radians(-5.0)))

    set_local_euler("thigh.L", (math.radians(-24.0), math.radians(5.0), math.radians(2.0)))
    set_local_euler("thigh_twist.L", (math.radians(5.0), 0.0, math.radians(-4.0)))
    set_local_euler("shin.L", (math.radians(43.0), 0.0, 0.0))
    set_local_euler("foot.L", (math.radians(-12.0), 0.0, 0.0))
    set_local_euler("thigh.R", (math.radians(17.0), math.radians(-4.0), math.radians(-4.0)))
    set_local_euler("shin.R", (math.radians(20.0), 0.0, 0.0))
    set_local_euler("foot.R", (math.radians(-8.0), 0.0, 0.0))

    set_local_euler("clavicle.L", (math.radians(-10.0), math.radians(-9.0), math.radians(-23.0)))
    set_local_euler("upper_arm.L", (math.radians(-14.0), math.radians(9.0), math.radians(-58.0)))
    set_local_euler("upper_arm_twist.L", (math.radians(18.0), 0.0, 0.0))
    set_local_euler("forearm.L", (math.radians(64.0), math.radians(-8.0), math.radians(-4.0)))
    set_local_euler("clavicle.R", (math.radians(6.0), math.radians(8.0), math.radians(19.0)))
    set_local_euler("upper_arm.R", (math.radians(18.0), math.radians(-5.0), math.radians(62.0)))
    set_local_euler("upper_arm_twist.R", (math.radians(-12.0), 0.0, 0.0))
    set_local_euler("forearm.R", (math.radians(42.0), math.radians(6.0), math.radians(7.0)))
    for side, direction in (("L", 1.0), ("R", -1.0)):
        for finger in ("index", "middle", "ring", "pinky"):
            set_local_euler(f"{finger}.01.{side}", (math.radians(18.0), 0.0, 0.0))
            set_local_euler(f"{finger}.02.{side}", (math.radians(24.0), 0.0, 0.0))
            set_local_euler(f"{finger}.03.{side}", (math.radians(18.0), 0.0, 0.0))
        set_local_euler(f"thumb.01.{side}", (math.radians(10.0), math.radians(12.0 * direction), 0.0))
        set_local_euler(f"cape.{side}", (math.radians(9.0), 0.0, math.radians(4.0 * direction)))
        set_local_euler(f"cape_mid.{side}", (math.radians(12.0), 0.0, math.radians(3.0 * direction)))
        set_local_euler(f"cape_lower.{side}", (math.radians(8.0), 0.0, math.radians(2.0 * direction)))
    face = bpy.data.objects["GV2_Face"]
    face.data.shape_keys.key_blocks["brow_inner_raise"].value = 0.18
    face.data.shape_keys.key_blocks["jaw_clench"].value = 0.28
    bpy.context.view_layer.update()


def render_view(camera: bpy.types.Object, filename: str, location: tuple[float, float, float], target: tuple[float, float, float], lens: float, resolution: tuple[int, int]) -> None:
    camera.location = location
    camera.data.lens = lens
    look_at(camera, target)
    scene = bpy.context.scene
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(RENDER_DIR / filename)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND_PATH))
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.render.resolution_percentage = 100
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.025, 0.030, 0.040)
    floor, camera = add_studio()
    reset_pose()
    render_view(camera, "gloam-vigil-v2-neutral-front.png", (0.0, -5.3, 1.10), (0.0, 0.0, 1.08), 70.0, (720, 960))
    render_view(camera, "gloam-vigil-v2-neutral-profile.png", (5.3, 0.0, 1.10), (0.0, 0.0, 1.08), 70.0, (720, 960))
    render_view(camera, "gloam-vigil-v2-neutral-threequarter.png", (3.65, -4.55, 1.26), (0.0, 0.0, 1.10), 76.0, (720, 960))
    render_view(camera, "gloam-vigil-v2-head-threequarter.png", (0.74, -1.42, 2.055), (0.0, -0.015, 2.020), 92.0, (960, 960))
    set_action_pose()
    render_view(camera, "gloam-vigil-v2-action.png", (3.85, -4.85, 1.34), (0.0, 0.0, 1.08), 74.0, (840, 960))
    # Never save the temporary pose, studio, or camera into source.
    print(f"GLOAM_VIGIL_V2_RENDER_OK dir={RENDER_DIR}")


if __name__ == "__main__":
    main()

