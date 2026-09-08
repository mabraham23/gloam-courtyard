"""Generate the original Gloam Vigil v2 Blender source and skinned GLB.

This is a code-authored, animation-ready technical character study.  The body,
hands, feet, face inputs, and cape start as explicit loft/tube/surface parts.
The current facial skin then uses a 3.2 mm voxel union, three smoothing passes,
and collapse decimation; separate eyes/lids/mask details are joined afterward.
That bounded automatic reduction produced visible nose/mouth tearing in r4, so
this file is not evidence of accepted final anatomy.  The deterministic PBR
maps are procedural signal textures, not a high-to-low sculpt bake.  Nothing
here is a claim of hand sculpting, photogrammetry, or artist retopology.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
import zlib

import bpy
from mathutils import Vector
import numpy as np


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from mesh_tools import (  # noqa: E402
    MeshAssembly,
    MeshPart,
    blend_weights,
    cape_panel,
    ellipsoid,
    horizontal_loft,
    normalized,
    path_tube,
    smart_uv,
    smoothstep,
    thick_ribbon,
    torus,
    triangulate,
)
from rig_contract import (  # noqa: E402
    ASSET_ID,
    ASSET_VERSION,
    BONE_BY_NAME,
    BONE_NAMES,
    BONE_SPECS,
    FOOT_CONTACT_GROUPS,
    FORWARD_AXIS,
    LEGACY_BONE_NAMES,
    MATERIAL_NAMES,
    MORPH_NAMES,
    RIG_CONTRACT,
)


TEXTURE_DIR = SCRIPT_DIR / "textures"
SOURCE_DIR = SCRIPT_DIR / "source"
RENDER_DIR = SCRIPT_DIR / "renders"
BLEND_PATH = SOURCE_DIR / "gloam_vigil_player_v2.blend"
GLB_PATH = SCRIPT_DIR / "gloam_vigil_player_v2.glb"
MANIFEST_PATH = SCRIPT_DIR / "gloam_vigil_player_v2_manifest.json"


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.armatures,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def _png_chunk(tag: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)


def write_png(path: Path, pixels: np.ndarray) -> None:
    assert pixels.dtype == np.uint8 and pixels.ndim == 3 and pixels.shape[2] == 3
    height, width, _ = pixels.shape
    raw = b"".join(b"\x00" + pixels[row].tobytes() for row in range(height))
    payload = b"\x89PNG\r\n\x1a\n"
    payload += _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    payload += _png_chunk(b"IDAT", zlib.compress(raw, level=7))
    payload += _png_chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def _rgb_from_channels(red: np.ndarray, green: np.ndarray, blue: np.ndarray) -> np.ndarray:
    shape = np.broadcast_shapes(red.shape, green.shape, blue.shape)
    image = np.empty((*shape, 3), dtype=np.uint8)
    image[..., 0] = np.clip(np.broadcast_to(red, shape), 0, 255).astype(np.uint8)
    image[..., 1] = np.clip(np.broadcast_to(green, shape), 0, 255).astype(np.uint8)
    image[..., 2] = np.clip(np.broadcast_to(blue, shape), 0, 255).astype(np.uint8)
    return image


def generate_texture_set(prefix: str, size: int, base: tuple[int, int, int], kind: str) -> dict[str, Path]:
    y = np.arange(size, dtype=np.float32)[:, None]
    x = np.arange(size, dtype=np.float32)[None, :]
    if kind == "cloth":
        weave = 0.45 * np.sin(x * math.tau / 19.0) + 0.38 * np.sin(y * math.tau / 23.0)
        broad = 0.55 * np.sin((x + y) * math.tau / 257.0)
        nx = 128.0 + 5.5 * np.cos(x * math.tau / 19.0)
        ny = 128.0 + 5.0 * np.cos(y * math.tau / 23.0)
        rough = 218.0 + 9.0 * np.sin(x * math.tau / 41.0) * np.sin(y * math.tau / 37.0)
    elif kind == "skin":
        weave = 0.35 * np.sin(x * 0.173 + y * 0.119) + 0.25 * np.sin(x * 0.047 - y * 0.071)
        broad = 0.45 * np.sin((x + y) * math.tau / 389.0)
        nx = 128.0 + 2.5 * np.sin(x * 0.29 + y * 0.11)
        ny = 128.0 + 2.5 * np.sin(y * 0.31 - x * 0.09)
        rough = 162.0 + 8.0 * np.sin(x * 0.071) * np.sin(y * 0.059)
    elif kind == "leather":
        weave = 0.55 * np.sin(x * 0.083 + y * 0.127) + 0.40 * np.sin(x * 0.211 - y * 0.057)
        broad = 0.35 * np.sin((x - y) * math.tau / 317.0)
        nx = 128.0 + 4.0 * np.sin(x * 0.14 + y * 0.08)
        ny = 128.0 + 4.0 * np.sin(y * 0.13 - x * 0.06)
        rough = 194.0 + 12.0 * np.sin(x * 0.051) * np.sin(y * 0.067)
    else:
        weave = 1.5 * np.sin((x + y) * math.tau / 101.0)
        broad = 1.0 * np.sin((x - y) * math.tau / 211.0)
        nx = 128.0 + 2.0 * np.sin(x * 0.08)
        ny = 128.0 + 2.0 * np.sin(y * 0.09)
        rough = 176.0 + 6.0 * np.sin(x * 0.041) * np.sin(y * 0.047)

    albedo = _rgb_from_channels(base[0] + weave + broad, base[1] + weave + broad, base[2] + weave + broad)
    nz = np.sqrt(np.maximum(0.0, 127.0 * 127.0 - (nx - 128.0) ** 2 - (ny - 128.0) ** 2)) + 128.0
    normal_map = _rgb_from_channels(nx, ny, nz)
    roughness = _rgb_from_channels(rough, rough, rough)
    paths = {
        "base": TEXTURE_DIR / f"{prefix}_basecolor_{size}.png",
        "normal": TEXTURE_DIR / f"{prefix}_normal_{size}.png",
        "roughness": TEXTURE_DIR / f"{prefix}_roughness_{size}.png",
    }
    write_png(paths["base"], albedo)
    write_png(paths["normal"], normal_map)
    write_png(paths["roughness"], roughness)
    return paths


def generate_textures() -> dict[str, dict[str, Path]]:
    return {
        "MAT_GV2_Suit_Cloth": generate_texture_set("gv2_suit_cloth", 2048, (29, 37, 49), "cloth"),
        "MAT_GV2_Skin": generate_texture_set("gv2_skin_face", 2048, (112, 78, 63), "skin"),
        "MAT_GV2_Gear": generate_texture_set("gv2_gear", 1024, (20, 25, 32), "leather"),
        "MAT_GV2_Tactical_Boot": generate_texture_set("gv2_boot", 1024, (13, 17, 23), "leather"),
        "MAT_GV2_Accent": generate_texture_set("gv2_accent", 1024, (105, 24, 44), "accent"),
    }


def make_material(name: str, textures: dict[str, Path]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (0.25, 0.25, 0.25, 1.0)
    material["gloam_material_semantic"] = name.removeprefix("MAT_GV2_").lower()
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.inputs["Metallic"].default_value = 0.06 if name == "MAT_GV2_Gear" else 0.015
    links.new(principled.outputs["BSDF"], output.inputs["Surface"])

    if name == "MAT_GV2_Gear":
        vertex_color = nodes.new("ShaderNodeVertexColor")
        vertex_color.layer_name = "Col"
        links.new(vertex_color.outputs["Color"], principled.inputs["Base Color"])
    else:
        albedo_image = bpy.data.images.load(str(textures["base"]), check_existing=True)
        albedo = nodes.new("ShaderNodeTexImage")
        albedo.name = f"{name}_BaseColor"
        albedo.image = albedo_image
        if name == "MAT_GV2_Skin":
            vertex_color = nodes.new("ShaderNodeVertexColor")
            vertex_color.layer_name = "Col"
            multiply = nodes.new("ShaderNodeMixRGB")
            multiply.blend_type = "MULTIPLY"
            multiply.inputs["Fac"].default_value = 1.0
            links.new(albedo.outputs["Color"], multiply.inputs[1])
            links.new(vertex_color.outputs["Color"], multiply.inputs[2])
            links.new(multiply.outputs["Color"], principled.inputs["Base Color"])
        else:
            links.new(albedo.outputs["Color"], principled.inputs["Base Color"])

    roughness_image = bpy.data.images.load(str(textures["roughness"]), check_existing=True)
    roughness_image.colorspace_settings.name = "Non-Color"
    roughness = nodes.new("ShaderNodeTexImage")
    roughness.name = f"{name}_Roughness"
    roughness.image = roughness_image
    links.new(roughness.outputs["Color"], principled.inputs["Roughness"])

    normal_image = bpy.data.images.load(str(textures["normal"]), check_existing=True)
    normal_image.colorspace_settings.name = "Non-Color"
    normal_texture = nodes.new("ShaderNodeTexImage")
    normal_texture.name = f"{name}_Normal"
    normal_texture.image = normal_image
    normal_node = nodes.new("ShaderNodeNormalMap")
    normal_node.inputs["Strength"].default_value = 0.14 if name == "MAT_GV2_Suit_Cloth" else 0.10
    links.new(normal_texture.outputs["Color"], normal_node.inputs["Color"])
    links.new(normal_node.outputs["Normal"], principled.inputs["Normal"])
    return material


def create_materials() -> dict[str, bpy.types.Material]:
    texture_sets = generate_textures()
    return {name: make_material(name, texture_sets[name]) for name in MATERIAL_NAMES}


def create_armature(marker: bpy.types.Object) -> bpy.types.Object:
    armature_data = bpy.data.armatures.new("gloam_vigil_v2_rig")
    armature = bpy.data.objects.new("GloamVigilV2Rig", armature_data)
    bpy.context.collection.objects.link(armature)
    armature.parent = marker
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    created: dict[str, bpy.types.EditBone] = {}
    for spec in BONE_SPECS:
        bone = armature_data.edit_bones.new(spec.name)
        bone.head = spec.head
        bone.tail = spec.tail
        if spec.parent:
            bone.parent = created[spec.parent]
        direction = (Vector(spec.tail) - Vector(spec.head)).normalized()
        roll_target = Vector((0.0, -1.0, 0.0))
        if abs(direction.dot(roll_target)) > 0.92:
            roll_target = Vector((0.0, 0.0, 1.0))
        bone.align_roll(roll_target)
        created[spec.name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    armature.show_in_front = True
    armature["gloam_asset_id"] = ASSET_ID
    armature["gloam_asset_version"] = ASSET_VERSION
    armature["gloam_rig_contract"] = RIG_CONTRACT
    armature["gloam_forward_axis"] = FORWARD_AXIS
    armature["gloam_legacy_bones"] = ",".join(LEGACY_BONE_NAMES)
    armature["gloam_foot_contact_groups"] = ",".join(FOOT_CONTACT_GROUPS)
    armature.select_set(False)
    return armature


def interpolate_controls(controls: list[tuple[float, ...]], count: int) -> list[tuple[float, ...]]:
    result: list[tuple[float, ...]] = []
    for sample in range(count):
        t = sample / (count - 1)
        scaled = t * (len(controls) - 1)
        index = min(len(controls) - 2, int(scaled))
        local = smoothstep(0.0, 1.0, scaled - index)
        result.append(tuple(a * (1.0 - local) + b * local for a, b in zip(controls[index], controls[index + 1], strict=True)))
    return result


def weights_at(value: float, anchors: list[tuple[float, str]]) -> dict[str, float]:
    anchors = sorted(anchors)
    if value <= anchors[0][0]:
        return {anchors[0][1]: 1.0}
    if value >= anchors[-1][0]:
        return {anchors[-1][1]: 1.0}
    for (low_value, low_name), (high_value, high_name) in zip(anchors, anchors[1:], strict=False):
        if low_value <= value <= high_value:
            if low_name == high_name:
                return {low_name: 1.0}
            return blend_weights({low_name: 1.0}, {high_name: 1.0}, smoothstep(low_value, high_value, value))
    raise AssertionError(value)


def core_weights(z: float) -> dict[str, float]:
    anchors = [
        (0.98, "root"),
        (1.05, "pelvis"),
        (1.20, "spine"),
        (1.39, "spine_upper"),
        (1.59, "chest"),
        (1.72, "chest"),
    ]
    return weights_at(z, anchors)


def build_torso(body: MeshAssembly) -> None:
    controls = [
        (0.980, 0.220, 0.158, 0.014),
        (1.045, 0.246, 0.174, 0.012),
        (1.105, 0.252, 0.180, 0.004),
        (1.180, 0.226, 0.158, -0.002),
        (1.275, 0.194, 0.143, -0.006),
        (1.365, 0.220, 0.156, -0.004),
        (1.455, 0.265, 0.182, 0.000),
        (1.535, 0.294, 0.197, 0.006),
        (1.610, 0.310, 0.203, 0.010),
        (1.665, 0.305, 0.193, 0.012),
        (1.710, 0.250, 0.158, 0.012),
    ]
    sampled = interpolate_controls(controls, 31)
    rings = [((0.0, center_y, z), radius_x, radius_y, core_weights(z)) for z, radius_x, radius_y, center_y in sampled]

    def deform(position: tuple[float, float, float], angle: float, _ring: int) -> tuple[float, float, float]:
        x, y, z = position
        front = max(0.0, math.cos(angle)) ** 1.8
        pec_lobes = math.exp(-((abs(x) - 0.125) / 0.085) ** 2)
        pec = 0.020 * math.exp(-((z - 1.565) / 0.090) ** 2) * pec_lobes
        sternum = 0.005 * math.exp(-(x / 0.030) ** 2) * math.exp(-((z - 1.55) / 0.14) ** 2)
        abdomen = 0.008 * math.exp(-(x / 0.105) ** 2) * math.exp(-((z - 1.305) / 0.18) ** 2)
        oblique = 0.006 * math.exp(-((abs(x) - 0.155) / 0.065) ** 2) * math.exp(-((z - 1.30) / 0.16) ** 2)
        y -= front * (pec + abdomen + oblique - sternum)
        # Subtle lat sweep at the rear, not a stack of separate volumes.
        rear = max(0.0, -math.cos(angle))
        y += rear * 0.009 * math.exp(-((z - 1.48) / 0.18) ** 2)
        return (x, y, z)

    body.append(horizontal_loft(rings, 96, "MAT_GV2_Suit_Cloth", deform=deform))

    neck_controls = [
        (1.655, 0.225, 0.140, 0.028),
        (1.690, 0.170, 0.118, 0.022),
        (1.725, 0.120, 0.095, 0.014),
        (1.755, 0.096, 0.082, 0.008),
    ]
    sampled_neck = interpolate_controls(neck_controls, 10)
    neck_rings = []
    for z, radius_x, radius_y, center_y in sampled_neck:
        weights = weights_at(z, [(1.655, "chest"), (1.715, "neck"), (1.755, "neck")])
        neck_rings.append(((0.0, center_y, z), radius_x, radius_y, weights))
    body.append(horizontal_loft(neck_rings, 96, "MAT_GV2_Suit_Cloth"))


def build_limbs(body: MeshAssembly) -> None:
    for side, sign in (("L", -1.0), ("R", 1.0)):
        arm_controls = [
            (sign * 0.190, 0.006, 1.675, 0.098, 0.096),
            (sign * 0.260, 0.002, 1.625, 0.115, 0.111),
            (sign * 0.320, -0.001, 1.535, 0.112, 0.106),
            (sign * 0.360, -0.004, 1.410, 0.105, 0.099),
            (sign * 0.390, -0.006, 1.250, 0.081, 0.078),
            (sign * 0.389, -0.013, 1.145, 0.090, 0.078),
            (sign * 0.386, -0.020, 1.060, 0.097, 0.081),
            (sign * 0.380, -0.030, 0.930, 0.064, 0.061),
        ]
        sampled_arm = interpolate_controls(arm_controls, 32)
        arm_anchors = [
            (0.930, f"forearm_twist.{side}"),
            (1.080, f"forearm.{side}"),
            (1.250, f"upper_arm_twist.{side}"),
            (1.470, f"upper_arm.{side}"),
            (1.680, f"clavicle.{side}"),
            (1.700, f"clavicle.{side}"),
        ]
        arm_points = [(x, y, z) for x, y, z, _radius_x, _radius_y in sampled_arm]
        arm_radii = [(radius_x, radius_y) for _x, _y, _z, radius_x, radius_y in sampled_arm]
        arm_weights = [weights_at(z, arm_anchors) for _x, _y, z, _radius_x, _radius_y in sampled_arm]
        body.append(path_tube(arm_points, arm_radii, arm_weights, 64, "MAT_GV2_Suit_Cloth", cap=False))

        leg_controls = [
            (sign * 0.120, 0.006, 1.080, 0.145, 0.151),
            (sign * 0.120, 0.002, 1.010, 0.164, 0.158),
            (sign * 0.120, -0.004, 0.900, 0.154, 0.143),
            (sign * 0.120, -0.006, 0.760, 0.128, 0.123),
            (sign * 0.120, -0.006, 0.620, 0.094, 0.092),
            (sign * 0.120, -0.002, 0.520, 0.106, 0.103),
            (sign * 0.120, 0.002, 0.420, 0.121, 0.108),
            (sign * 0.120, 0.003, 0.300, 0.099, 0.090),
            (sign * 0.120, 0.000, 0.160, 0.073, 0.068),
        ]
        sampled_leg = interpolate_controls(leg_controls, 40)
        leg_anchors = [
            (0.160, f"shin_twist.{side}"),
            (0.400, f"shin.{side}"),
            (0.620, f"thigh_twist.{side}"),
            (0.860, f"thigh.{side}"),
            (1.020, f"thigh.{side}"),
            (1.080, "pelvis"),
        ]
        leg_rings = [((x, y, z), radius_x, radius_y, weights_at(z, leg_anchors)) for x, y, z, radius_x, radius_y in sampled_leg]

        def leg_deform(position: tuple[float, float, float], angle: float, _ring: int) -> tuple[float, float, float]:
            x, y, z = position
            front = max(0.0, math.cos(angle))
            quad = 0.010 * math.exp(-((z - 0.84) / 0.18) ** 2)
            tibia = 0.004 * math.exp(-((z - 0.40) / 0.15) ** 2)
            y -= front * (quad + tibia)
            y += max(0.0, -math.cos(angle)) * 0.010 * math.exp(-((z - 0.43) / 0.12) ** 2)
            return (x, y, z)

        body.append(horizontal_loft(leg_rings, 64, "MAT_GV2_Suit_Cloth", deform=leg_deform))


def build_hands_and_boots(body: MeshAssembly) -> None:
    for side, sign in (("L", -1.0), ("R", 1.0)):
        palm_controls = [
            (0.930, 0.052, 0.041, -0.035),
            (0.875, 0.059, 0.043, -0.043),
            (0.840, 0.062, 0.040, -0.051),
            (0.815, 0.057, 0.035, -0.057),
        ]
        sampled_palm = interpolate_controls(palm_controls, 12)
        palm_rings = []
        for z, radius_x, radius_y, center_y in sampled_palm:
            palm_rings.append(((sign * 0.404, center_y, z), radius_x, radius_y, weights_at(z, [(0.815, f"hand.{side}"), (0.875, f"hand.{side}"), (0.930, f"forearm_twist.{side}")])))
        body.append(horizontal_loft(palm_rings, 32, "MAT_GV2_Gear"))

        for finger in ("thumb", "index", "middle", "ring", "pinky"):
            specs = [BONE_BY_NAME[f"{finger}.{index:02d}.{side}"] for index in range(1, 4)]
            controls = [specs[0].head, specs[0].tail, specs[1].tail, specs[2].tail]
            points: list[tuple[float, float, float]] = []
            radii: list[tuple[float, float]] = []
            weights: list[dict[str, float]] = []
            for sample in range(13):
                t = sample / 12.0
                scaled = t * 3.0
                segment = min(2, int(scaled))
                local = scaled - segment
                a = Vector(controls[segment])
                b = Vector(controls[segment + 1])
                p = a.lerp(b, smoothstep(0.0, 1.0, local))
                points.append((p.x, p.y, p.z))
                base_radius = 0.016 if finger == "thumb" else (0.0145 if finger in ("index", "middle") else 0.013)
                radius = base_radius * (1.0 - 0.24 * t)
                radii.append((radius, radius * 0.86))
                if segment == 2:
                    weights.append({specs[2].name: 1.0})
                else:
                    weights.append(blend_weights({specs[segment].name: 1.0}, {specs[segment + 1].name: 1.0}, smoothstep(0.68, 1.0, local)))
            body.append(path_tube(points, radii, weights, 12, "MAT_GV2_Gear"))

        # The cuff blends shin twist into foot.  The foot volume then follows
        # foot/ball/toe in strong longitudinal zones, including the sole.
        cuff_controls = [
            (0.070, 0.088, 0.076, -0.005),
            (0.160, 0.080, 0.073, 0.000),
            (0.250, 0.086, 0.078, 0.008),
            (0.345, 0.095, 0.082, 0.014),
        ]
        sampled_cuff = interpolate_controls(cuff_controls, 14)
        cuff_rings = []
        for z, radius_x, radius_y, center_y in sampled_cuff:
            cuff_rings.append(((sign * 0.120, center_y, z), radius_x, radius_y, weights_at(z, [(0.070, f"foot.{side}"), (0.180, f"shin_twist.{side}"), (0.345, f"shin_twist.{side}")])))
        body.append(horizontal_loft(cuff_rings, 48, "MAT_GV2_Tactical_Boot"))

        foot_controls = [
            (sign * 0.120, 0.045, 0.093, 0.086, 0.066),
            (sign * 0.120, -0.015, 0.092, 0.092, 0.068),
            (sign * 0.120, -0.090, 0.084, 0.094, 0.063),
            (sign * 0.120, -0.175, 0.071, 0.093, 0.056),
            (sign * 0.120, -0.245, 0.060, 0.089, 0.048),
            (sign * 0.120, -0.285, 0.056, 0.077, 0.038),
        ]
        sampled_foot = interpolate_controls(foot_controls, 22)
        points = [(x, y, z) for x, y, z, _, _ in sampled_foot]
        radii = [(rx, rz) for _, _, _, rx, rz in sampled_foot]
        foot_weights = []
        for index in range(len(points)):
            t = index / (len(points) - 1)
            foot_weights.append(weights_at(t, [(0.0, f"foot.{side}"), (0.42, f"foot.{side}"), (0.66, f"ball.{side}"), (0.86, f"toe.{side}"), (1.0, f"toe.{side}")]))
        body.append(path_tube(points, radii, foot_weights, 48, "MAT_GV2_Tactical_Boot"))
        body.append(ellipsoid((sign * 0.120, -0.273, 0.058), (0.081, 0.050, 0.041), 32, 16, "MAT_GV2_Tactical_Boot", lambda _position, s=side: {f"toe.{s}": 1.0}))


def build_gear(body: MeshAssembly) -> None:
    body.append(torus((0.0, 0.0, 1.075), (0.238, 0.172), (0.017, 0.020), 72, 14, "MAT_GV2_Gear", {"pelvis": 0.72, "spine": 0.28}))
    pouch_layouts = [
        ((-0.170, -0.150, 1.055), (0.055, 0.030, 0.062)),
        ((0.170, -0.150, 1.055), (0.055, 0.030, 0.062)),
        ((-0.220, 0.040, 1.050), (0.043, 0.026, 0.055)),
        ((0.220, 0.040, 1.050), (0.043, 0.026, 0.055)),
    ]
    for center, scale in pouch_layouts:
        def pouch_deform(position: tuple[float, float, float], _latitude: float, _longitude: float, c=center, s=scale) -> tuple[float, float, float]:
            values = []
            for coordinate, origin, radius in zip(position, c, s, strict=True):
                local = max(-1.0, min(1.0, (coordinate - origin) / radius))
                values.append(origin + math.copysign(abs(local) ** 0.68, local) * radius)
            return tuple(values)

        body.append(ellipsoid(center, scale, 28, 14, "MAT_GV2_Gear", lambda _position: {"pelvis": 1.0}, pouch_deform))

    seam_controls = [
        (0.155, -0.197, 1.650),
        (0.120, -0.204, 1.540),
        (0.065, -0.190, 1.420),
        (0.010, -0.170, 1.300),
        (-0.060, -0.165, 1.180),
        (-0.115, -0.168, 1.085),
    ]
    sampled_seam = interpolate_controls(seam_controls, 24)
    seam_weights = [core_weights(point[2]) for point in sampled_seam]
    body.append(path_tube(sampled_seam, [(0.0065, 0.0050)] * len(sampled_seam), seam_weights, 10, "MAT_GV2_Accent"))
    body.append(ellipsoid((0.0, -0.183, 1.695), (0.031, 0.012, 0.026), 28, 14, "MAT_GV2_Accent", lambda _position: {"chest": 1.0}))


def head_deform(position: tuple[float, float, float], angle: float, _ring: int) -> tuple[float, float, float]:
    x, y, z = position
    front = max(0.0, math.cos(angle)) ** 3.0
    if z < 2.010:
        taper = 0.80 + 0.20 * smoothstep(1.900, 2.010, z)
        x *= taper
    cheek = 0.007 * math.exp(-((abs(x) - 0.052) / 0.030) ** 2) * math.exp(-((z - 2.025) / 0.034) ** 2)
    brow = 0.006 * math.exp(-((abs(x) - 0.034) / 0.027) ** 2) * math.exp(-((z - 2.073) / 0.022) ** 2)
    eye_socket = 0.006 * math.exp(-((abs(x) - 0.033) / 0.020) ** 2) * math.exp(-((z - 2.043) / 0.018) ** 2)
    nose_ridge = 0.004 * math.exp(-(x / 0.018) ** 2) * math.exp(-((z - 2.034) / 0.050) ** 2)
    nose_tip = 0.003 * math.exp(-(x / 0.024) ** 2) * math.exp(-((z - 1.998) / 0.023) ** 2)
    nose_alar = 0.002 * math.exp(-((abs(x) - 0.019) / 0.011) ** 2) * math.exp(-((z - 1.994) / 0.014) ** 2)
    upper_lip = 0.0050 * math.exp(-(x / 0.034) ** 2) * math.exp(-((z - 1.976) / 0.008) ** 2)
    lower_lip = 0.0055 * math.exp(-(x / 0.036) ** 2) * math.exp(-((z - 1.964) / 0.009) ** 2)
    mouth_crease = 0.0020 * math.exp(-(x / 0.038) ** 2) * math.exp(-((z - 1.970) / 0.0035) ** 2)
    muzzle = 0.004 * math.exp(-(x / 0.048) ** 2) * math.exp(-((z - 1.980) / 0.027) ** 2)
    chin = 0.008 * math.exp(-(x / 0.039) ** 2) * math.exp(-((z - 1.925) / 0.027) ** 2)
    y += front * eye_socket
    y -= front * (cheek + brow + nose_ridge + nose_tip + nose_alar + upper_lip + lower_lip + muzzle + chin - mouth_crease)
    return (x, y, z)


def face_weights(position: tuple[float, float, float]) -> dict[str, float]:
    x, y, z = position
    if z < 1.915:
        return blend_weights({"neck": 1.0}, {"head": 1.0}, smoothstep(1.900, 1.915, z))
    if z < 2.005 and y < -0.015:
        amount = 0.76 * (1.0 - smoothstep(1.920, 2.005, z)) + 0.18
        return normalized({"jaw": amount, "head": 1.0 - amount})
    return {"head": 1.0}


def assign_surface_vertex_colors(obj: bpy.types.Object, sclera_vertices: set[int], iris_vertices: set[int], lip_vertices: set[int]) -> None:
    """Use one shared Gear material while retaining natural eye coloration.

    glTF exports this active corner color attribute as COLOR_0.  The material
    node reads the same attribute in Blender, so neutral renders and Godot use
    the same ivory sclera, slate iris, dark pupil/mask/utility response.
    """
    attribute = obj.data.color_attributes.get("Col")
    if attribute is None:
        attribute = obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    gear_slots = {index for index, material in enumerate(obj.data.materials) if material and material.name == "MAT_GV2_Gear"}
    skin_slots = {index for index, material in enumerate(obj.data.materials) if material and material.name == "MAT_GV2_Skin"}
    ivory = (0.73, 0.70, 0.62, 1.0)
    slate = (0.16, 0.22, 0.24, 1.0)
    charcoal = (0.028, 0.040, 0.055, 1.0)
    vermilion = (0.78, 0.58, 0.54, 1.0)
    neutral = (1.0, 1.0, 1.0, 1.0)
    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = obj.data.loops[loop_index].vertex_index
            if polygon.material_index in skin_slots and vertex_index in lip_vertices:
                color = vermilion
            elif polygon.material_index not in gear_slots:
                color = neutral
            elif vertex_index in sclera_vertices:
                color = ivory
            elif vertex_index in iris_vertices:
                color = slate
            else:
                color = charcoal
            attribute.data[loop_index].color = color
    obj.data.color_attributes.active_color = attribute


def voxel_relax_skin(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj.data.remesh_voxel_size = 0.0032
    obj.data.remesh_voxel_adaptivity = 0.0
    if hasattr(obj.data, "use_remesh_preserve_volume"):
        obj.data.use_remesh_preserve_volume = True
    bpy.ops.object.voxel_remesh()
    smooth = obj.modifiers.new(name="Continuous facial surface relaxation", type="SMOOTH")
    smooth.factor = 0.22
    smooth.iterations = 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    decimate = obj.modifiers.new(name="Facial game-mesh reduction", type="DECIMATE")
    decimate.decimate_type = "COLLAPSE"
    decimate.ratio = 0.28
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    while obj.vertex_groups:
        obj.vertex_groups.remove(obj.vertex_groups[0])
    groups: dict[str, bpy.types.VertexGroup] = {}
    for vertex in obj.data.vertices:
        for name, value in face_weights(tuple(vertex.co)).items():
            group = groups.get(name) or obj.vertex_groups.new(name=name)
            groups[name] = group
            group.add([vertex.index], value, "REPLACE")
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.select_set(False)


def add_tag_groups(obj: bpy.types.Object, tags: dict[str, set[int]]) -> None:
    for tag, indices in tags.items():
        if not indices:
            continue
        group = obj.vertex_groups.new(name=f"TAG__{tag}")
        group.add(sorted(indices), 1.0, "REPLACE")


def extract_and_remove_tag_groups(obj: bpy.types.Object) -> dict[str, set[int]]:
    result: dict[str, set[int]] = {}
    tag_groups = {group.index: group for group in obj.vertex_groups if group.name.startswith("TAG__")}
    for vertex in obj.data.vertices:
        for membership in vertex.groups:
            group = tag_groups.get(membership.group)
            if group and membership.weight > 0.5:
                result.setdefault(group.name.removeprefix("TAG__"), set()).add(vertex.index)
    for group in list(tag_groups.values()):
        obj.vertex_groups.remove(group)
    return result


def build_face(materials: dict[str, bpy.types.Material]) -> tuple[bpy.types.Object, dict[str, set[int]]]:
    skin = MeshAssembly()
    neck_controls = [
        (1.735, 0.087, 0.075, 0.010),
        (1.785, 0.078, 0.069, 0.005),
        (1.850, 0.073, 0.067, -0.001),
        (1.910, 0.080, 0.073, -0.004),
        (1.930, 0.083, 0.076, -0.003),
    ]
    sampled_neck = interpolate_controls(neck_controls, 14)
    skin.append(horizontal_loft([((0.0, y, z), rx, ry, weights_at(z, [(1.735, "chest"), (1.790, "neck"), (1.900, "neck"), (1.930, "head")])) for z, rx, ry, y in sampled_neck], 64, "MAT_GV2_Skin"))

    # A smooth cranial base with a maintained mandible; the union below turns
    # the overlapping authored volumes into one continuous skin surface.
    skin.append(ellipsoid((0.0, 0.008, 2.035), (0.098, 0.087, 0.126), 72, 48, "MAT_GV2_Skin", face_weights, head_deform))
    jaw_rings = [
        ((0.0, -0.002, 2.005), 0.088, 0.074, {"head": 0.82, "jaw": 0.18}),
        ((0.0, -0.006, 1.975), 0.082, 0.070, {"head": 0.60, "jaw": 0.40}),
        ((0.0, -0.010, 1.945), 0.071, 0.064, {"head": 0.38, "jaw": 0.62}),
        ((0.0, -0.016, 1.920), 0.052, 0.052, {"head": 0.25, "jaw": 0.75}),
    ]
    skin.append(horizontal_loft(jaw_rings, 64, "MAT_GV2_Skin"))
    nose_rings = [
        ((0.0, -0.070, 2.078), 0.006, 0.004, {"head": 1.0}),
        ((0.0, -0.078, 2.047), 0.009, 0.007, {"head": 1.0}),
        ((0.0, -0.090, 2.016), 0.012, 0.010, {"head": 1.0}),
        ((0.0, -0.108, 1.995), 0.020, 0.016, {"head": 0.88, "jaw": 0.12}),
        ((0.0, -0.094, 1.982), 0.017, 0.011, {"head": 0.74, "jaw": 0.26}),
    ]
    skin.append(horizontal_loft(nose_rings, 28, "MAT_GV2_Skin"))

    lip_rows = [(1.985, 0.001), (1.979, 0.006), (1.971, 0.001), (1.964, 0.0065), (1.956, 0.001)]
    lip_vertices: list[tuple[float, float, float]] = []
    lip_weights: list[dict[str, float]] = []
    lip_columns = 33
    for row_index, (z, bulge) in enumerate(lip_rows):
        for column in range(lip_columns):
            x = -0.036 + 0.072 * column / (lip_columns - 1)
            envelope = math.sqrt(max(0.0, 1.0 - (x / 0.036) ** 2))
            lip_vertices.append((x, -0.081 - bulge * envelope, z))
            lip_weights.append(normalized({"head": 0.72 - 0.11 * row_index, "jaw": 0.28 + 0.11 * row_index}))
    lip_faces = []
    for row in range(len(lip_rows) - 1):
        for column in range(lip_columns - 1):
            a = row * lip_columns + column
            lip_faces.append((a, a + 1, a + 1 + lip_columns, a + lip_columns))
    skin.append(MeshPart(lip_vertices, lip_faces, lip_weights, "MAT_GV2_Skin"))
    for sign in (-1.0, 1.0):
        skin.append(ellipsoid((sign * 0.097, 0.006, 2.030), (0.012, 0.008, 0.026), 24, 14, "MAT_GV2_Skin", lambda _position: {"head": 1.0}))

    skin_obj = skin.build("GV2_FaceSkinStudy", materials)
    voxel_relax_skin(skin_obj, materials["MAT_GV2_Skin"])

    detail = MeshAssembly()
    for side, sign in (("L", -1.0), ("R", 1.0)):
        eye_center = (sign * 0.033, -0.071, 2.045)
        detail.append(ellipsoid(eye_center, (0.017, 0.006, 0.0085), 32, 18, "MAT_GV2_Gear", lambda _position, s=side: {f"eye.{s}": 1.0}, tagger=lambda _position: ["eye_sclera"]))
        detail.append(ellipsoid((sign * 0.033, -0.077, 2.045), (0.0038, 0.0014, 0.0038), 22, 12, "MAT_GV2_Gear", lambda _position, s=side: {f"eye.{s}": 1.0}, tagger=lambda _position: ["eye_iris"]))
        detail.append(ellipsoid((sign * 0.033, -0.0785, 2.045), (0.0017, 0.0007, 0.0017), 18, 9, "MAT_GV2_Gear", lambda _position, s=side: {f"eye.{s}": 1.0}))
        count = 23
        xs = [eye_center[0] - 0.020 + 0.040 * index / (count - 1) for index in range(count)]
        upper_inner, upper_outer, lower_inner, lower_outer = [], [], [], []
        for x in xs:
            local = (x - eye_center[0]) / 0.020
            arch = math.sqrt(max(0.0, 1.0 - local * local))
            upper_inner.append((x, -0.0780, eye_center[2] + 0.0050 * arch))
            upper_outer.append((x, -0.0765, eye_center[2] + 0.0080 * arch + 0.0004))
            lower_inner.append((x, -0.0780, eye_center[2] - 0.0045 * arch))
            lower_outer.append((x, -0.0765, eye_center[2] - 0.0075 * arch - 0.0004))
        detail.append(thick_ribbon(upper_inner, upper_outer, 0.0016, "MAT_GV2_Skin", {"head": 1.0}, f"upper_lid.{side}"))
        detail.append(thick_ribbon(lower_outer, lower_inner, 0.0016, "MAT_GV2_Skin", {"head": 1.0}, f"lower_lid.{side}"))

        # A fitted outer socket band only: no floating bridge or eyeglass arm.
        mask_inner, mask_outer = [], []
        for index in range(15):
            t = index / 14.0
            x = eye_center[0] + sign * (0.012 + 0.051 * t)
            y = -0.076 + 0.045 * t
            z = 2.054 + 0.007 * math.sin(math.pi * t)
            mask_inner.append((x, y, z))
            mask_outer.append((x, y + 0.0015, z + 0.004))
        detail.append(thick_ribbon(mask_inner, mask_outer, 0.0016, "MAT_GV2_Gear", {"head": 1.0}, "brow_inner_raise"))
    for sign in (-1.0, 1.0):
        detail.append(ellipsoid((sign * 0.009, -0.113, 1.987), (0.0025, 0.0009, 0.0015), 14, 7, "MAT_GV2_Gear", lambda _position: {"head": 0.70, "jaw": 0.30}))

    detail_obj = detail.build("GV2_FaceDetails", materials)
    add_tag_groups(detail_obj, detail.tags)
    bpy.ops.object.select_all(action="DESELECT")
    skin_obj.select_set(True)
    detail_obj.select_set(True)
    bpy.context.view_layer.objects.active = skin_obj
    bpy.ops.object.join()
    obj = skin_obj
    obj.name = "GV2_Face"
    tags = extract_and_remove_tag_groups(obj)
    tags["jaw_clench"] = {vertex.index for vertex in obj.data.vertices if vertex.co.y < -0.035 and 1.915 < vertex.co.z < 1.995}
    tags["brow_inner_raise"] = tags.get("brow_inner_raise", set()) | {vertex.index for vertex in obj.data.vertices if vertex.co.y < -0.045 and 2.060 < vertex.co.z < 2.100 and abs(vertex.co.x) < 0.055}
    lip_vertices = {vertex.index for vertex in obj.data.vertices if abs(vertex.co.x) < 0.040 and vertex.co.y < -0.078 and 1.950 < vertex.co.z < 1.988}
    smart_uv(obj, 0.008)
    triangulate(obj)
    assign_surface_vertex_colors(obj, tags.get("eye_sclera", set()), tags.get("eye_iris", set()), lip_vertices)
    create_face_shape_keys(obj, tags)
    return obj, tags


def create_face_shape_keys(obj: bpy.types.Object, tags: dict[str, set[int]]) -> None:
    basis = obj.shape_key_add(name="Basis")
    basis.interpolation = "KEY_LINEAR"
    for side in ("L", "R"):
        key = obj.shape_key_add(name=f"blink.{side}")
        key.value = 0.0
        eye_z = 2.044
        for vertex_index in tags[f"upper_lid.{side}"]:
            key.data[vertex_index].co.z = eye_z + 0.0008
            key.data[vertex_index].co.y -= 0.0015
        for vertex_index in tags[f"lower_lid.{side}"]:
            key.data[vertex_index].co.z = eye_z - 0.0008
            key.data[vertex_index].co.y -= 0.0010

    brow = obj.shape_key_add(name="brow_inner_raise")
    brow.value = 0.0
    for vertex_index in tags.get("brow_inner_raise", set()):
        coordinate = brow.data[vertex_index].co
        strength = 1.0 - min(1.0, abs(coordinate.x) / 0.070)
        coordinate.z += 0.012 * strength
        coordinate.y -= 0.002 * strength

    jaw = obj.shape_key_add(name="jaw_clench")
    jaw.value = 0.0
    for vertex_index in tags.get("jaw_clench", set()):
        coordinate = jaw.data[vertex_index].co
        sign = -1.0 if coordinate.x < 0.0 else 1.0
        coordinate.x += sign * 0.005
        coordinate.y -= 0.0025


def build_body(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    body = MeshAssembly()
    build_torso(body)
    build_limbs(body)
    build_hands_and_boots(body)
    build_gear(body)
    obj = body.build("GV2_Body", materials)
    smart_uv(obj)
    triangulate(obj)
    assign_surface_vertex_colors(obj, set(), set(), set())
    return obj


def build_cape(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    cape = MeshAssembly()
    for side, sign in (("L", -1.0), ("R", 1.0)):
        cape.append(cape_panel(sign, 36, 44, "MAT_GV2_Suit_Cloth", [f"cape.{side}", f"cape_mid.{side}", f"cape_lower.{side}", f"cape_tip.{side}"]))
    obj = cape.build("GV2_Cape", materials)
    smart_uv(obj, 0.006)
    triangulate(obj)
    return obj


def attach_to_rig(obj: bpy.types.Object, armature: bpy.types.Object) -> None:
    modifier = obj.modifiers.new(name="Gloam Vigil v2 armature", type="ARMATURE")
    modifier.object = armature
    modifier.use_deform_preserve_volume = True
    obj.parent = armature
    obj.matrix_parent_inverse = armature.matrix_world.inverted()
    obj["gloam_asset_id"] = ASSET_ID
    obj["gloam_asset_version"] = ASSET_VERSION
    obj["gloam_rig_contract"] = RIG_CONTRACT
    obj["gloam_forward_axis"] = FORWARD_AXIS
    obj["gloam_accent_material"] = "MAT_GV2_Accent"
    obj["gloam_boot_material"] = "MAT_GV2_Tactical_Boot"
    obj["gloam_foot_contact_groups"] = ",".join(FOOT_CONTACT_GROUPS)


def validate_contract(meshes: list[bpy.types.Object], armature: bpy.types.Object) -> dict[str, object]:
    actual_bones = tuple(bone.name for bone in armature.data.bones)
    assert set(actual_bones) == set(BONE_NAMES), sorted(set(actual_bones) ^ set(BONE_NAMES))
    assert len(actual_bones) == 74
    assert set(LEGACY_BONE_NAMES).issubset(actual_bones)
    assert {mesh.name for mesh in meshes} == {"GV2_Body", "GV2_Face", "GV2_Cape"}

    material_names = {material.name for mesh in meshes for material in mesh.data.materials if material}
    assert material_names == set(MATERIAL_NAMES), sorted(material_names ^ set(MATERIAL_NAMES))
    surface_slots = sum(len(mesh.data.materials) for mesh in meshes)

    bone_weight_totals = {name: 0.0 for name in BONE_NAMES}
    bone_vertex_counts = {name: 0 for name in BONE_NAMES}
    invalid_sums: list[tuple[str, int, float]] = []
    excessive_influences: list[tuple[str, int, int]] = []
    semantic_failures: list[tuple[str, int, str]] = []
    bottom_contact_vertices = 0
    total_vertices = 0
    total_triangles = 0
    minimum = Vector((1.0e9, 1.0e9, 1.0e9))
    maximum = Vector((-1.0e9, -1.0e9, -1.0e9))

    arm_groups = {f"{part}.{side}" for part in ("clavicle", "upper_arm", "upper_arm_twist", "forearm", "forearm_twist", "hand") for side in ("L", "R")}
    arm_groups |= {f"{finger}.{index:02d}.{side}" for finger in ("thumb", "index", "middle", "ring", "pinky") for index in range(1, 4) for side in ("L", "R")}
    leg_groups = {f"{part}.{side}" for part in ("thigh", "thigh_twist", "shin", "shin_twist", "foot", "ball", "toe") for side in ("L", "R")}
    core_face_cape = set(BONE_NAMES) - arm_groups - leg_groups

    for mesh in meshes:
        assert mesh.get("gloam_rig_contract") == RIG_CONTRACT
        assert mesh.parent == armature
        assert any(modifier.type == "ARMATURE" and modifier.object == armature for modifier in mesh.modifiers)
        group_names = {group.index: group.name for group in mesh.vertex_groups}
        total_vertices += len(mesh.data.vertices)
        total_triangles += len(mesh.data.polygons)
        for vertex in mesh.data.vertices:
            weights = {group_names[element.group]: element.weight for element in vertex.groups if element.weight > 1.0e-5}
            weight_sum = sum(weights.values())
            if abs(weight_sum - 1.0) > 5.0e-4:
                invalid_sums.append((mesh.name, vertex.index, weight_sum))
            if len(weights) > 4:
                excessive_influences.append((mesh.name, vertex.index, len(weights)))
            for name, value in weights.items():
                assert name in bone_weight_totals, f"Unknown deform group {name}"
                bone_weight_totals[name] += value
                bone_vertex_counts[name] += 1
            coordinate = vertex.co
            minimum.x = min(minimum.x, coordinate.x)
            minimum.y = min(minimum.y, coordinate.y)
            minimum.z = min(minimum.z, coordinate.z)
            maximum.x = max(maximum.x, coordinate.x)
            maximum.y = max(maximum.y, coordinate.y)
            maximum.z = max(maximum.z, coordinate.z)
            if mesh.name == "GV2_Body":
                if abs(coordinate.x) > 0.300 and 0.84 < coordinate.z < 1.72 and any(weights.get(name, 0.0) > 0.001 for name in leg_groups):
                    semantic_failures.append((mesh.name, vertex.index, "arm-region leg contamination"))
                if coordinate.z < 0.42 and any(weights.get(name, 0.0) > 0.001 for name in core_face_cape | arm_groups):
                    semantic_failures.append((mesh.name, vertex.index, "low-body non-leg contamination"))
                if coordinate.z < 0.025:
                    contact_weight = sum(weights.get(name, 0.0) for name in FOOT_CONTACT_GROUPS)
                    if contact_weight >= 0.80:
                        bottom_contact_vertices += 1

    assert not invalid_sums, invalid_sums[:12]
    assert not excessive_influences, excessive_influences[:12]
    assert not semantic_failures, semantic_failures[:12]
    weak_bones = {name: (bone_vertex_counts[name], bone_weight_totals[name]) for name in BONE_NAMES if bone_vertex_counts[name] < 12 or bone_weight_totals[name] < 2.0}
    assert not weak_bones, weak_bones
    assert bottom_contact_vertices >= 32, bottom_contact_vertices
    assert 50000 <= total_triangles <= 90000, total_triangles
    assert -0.005 <= minimum.z <= 0.025, minimum.z
    assert 2.14 <= maximum.z <= 2.19, maximum.z

    face = bpy.data.objects["GV2_Face"]
    assert face.data.shape_keys is not None
    actual_morphs = tuple(block.name for block in face.data.shape_keys.key_blocks if block.name != "Basis")
    assert actual_morphs == MORPH_NAMES, actual_morphs

    metrics = {
        "asset_id": ASSET_ID,
        "asset_version": ASSET_VERSION,
        "rig_contract": RIG_CONTRACT,
        "bones": len(actual_bones),
        "legacy_bones": len(LEGACY_BONE_NAMES),
        "weighted_bones": sum(value >= 2.0 for value in bone_weight_totals.values()),
        "morph_targets": list(actual_morphs),
        "mesh_nodes": [mesh.name for mesh in meshes],
        "unique_materials": len(material_names),
        "material_surface_slots": surface_slots,
        "vertices": total_vertices,
        "triangles": total_triangles,
        "bounds_m": [round(maximum.x - minimum.x, 6), round(maximum.y - minimum.y, 6), round(maximum.z - minimum.z, 6)],
        "minimum_z_m": round(minimum.z, 6),
        "maximum_z_m": round(maximum.z, 6),
        "bottom_contact_vertices": bottom_contact_vertices,
        "max_influences": 4,
        "bone_vertex_count_min": min(bone_vertex_counts.values()),
        "bone_weight_total_min": round(min(bone_weight_totals.values()), 6),
    }
    print("GLOAM_VIGIL_V2_CONTRACT_OK " + json.dumps(metrics, sort_keys=True))
    return metrics


def export_asset(marker: bpy.types.Object, meshes: list[bpy.types.Object], armature: bpy.types.Object) -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [marker, armature, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        check_existing=False,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_animations=False,
        export_skins=True,
        export_influence_nb=4,
        export_all_influences=False,
        export_def_bones=True,
        export_rest_position_armature=True,
        export_armature_object_remove=False,
        export_leaf_bone=False,
        export_morph=True,
        export_morph_normal=True,
        export_morph_tangent=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_extras=True,
        export_cameras=False,
        export_lights=False,
        export_draco_mesh_compression_enable=False,
        export_meshopt_compression_enable=False,
    )


def main() -> None:
    reset_scene()
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    RENDER_DIR.mkdir(parents=True, exist_ok=True)
    materials = create_materials()
    marker = bpy.data.objects.new("GloamVigilV2Asset", None)
    bpy.context.collection.objects.link(marker)
    marker["gloam_asset_id"] = ASSET_ID
    marker["gloam_asset_version"] = ASSET_VERSION
    marker["gloam_rig_contract"] = RIG_CONTRACT
    marker["gloam_forward_axis"] = FORWARD_AXIS
    marker["gloam_authoring"] = "original deterministic Blender geometry; no downloaded assets"
    armature = create_armature(marker)
    body = build_body(materials)
    face, _face_tags = build_face(materials)
    cape = build_cape(materials)
    meshes = [body, face, cape]
    for mesh in meshes:
        attach_to_rig(mesh, armature)
    metrics = validate_contract(meshes, armature)
    export_asset(marker, meshes, armature)
    metrics["blend_path"] = str(BLEND_PATH.relative_to(SCRIPT_DIR.parent.parent.parent))
    metrics["glb_path"] = str(GLB_PATH.relative_to(SCRIPT_DIR.parent.parent.parent))
    metrics["glb_sha256"] = hashlib.sha256(GLB_PATH.read_bytes()).hexdigest()
    MANIFEST_PATH.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("GLOAM_VIGIL_V2_EXPORT_OK " + json.dumps(metrics, sort_keys=True))


if __name__ == "__main__":
    main()
