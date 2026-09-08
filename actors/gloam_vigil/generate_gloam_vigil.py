"""Generate the original Gloam Vigil hero as a reproducible skinned GLB.

Run with:
    blender --background --python actors/gloam_vigil/generate_gloam_vigil.py

The model is deliberately project-original.  It uses no downloaded geometry,
textures, rigs, or franchise references.  Blender is the authoring tool; Godot
consumes the emitted GLB while the existing gameplay controller remains the
source of pose timing and movement.
"""

from __future__ import annotations

import math
import os
import random

import bpy
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))
TEXTURE_DIR = os.path.join(ROOT, "textures")
BLEND_PATH = os.path.join(ROOT, "source", "gloam_vigil_player.blend")
GLB_PATH = os.path.join(ROOT, "gloam_vigil_player.glb")
SIDES = 20


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.curves, bpy.data.armatures, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def make_texture(name: str, base: tuple[float, float, float, float], kind: str) -> bpy.types.Image:
    os.makedirs(TEXTURE_DIR, exist_ok=True)
    size = 128
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    rng = random.Random(9187 + sum(ord(c) for c in name))
    pixels: list[float] = []
    for y in range(size):
        for x in range(size):
            if kind == "cloth":
                warp = 0.5 + 0.5 * math.sin(x * math.pi * 0.5)
                weft = 0.5 + 0.5 * math.sin(y * math.pi * 0.5 + 0.7)
                grain = 0.955 + 0.012 * warp + 0.010 * weft + rng.uniform(-0.010, 0.010)
            elif kind == "leather":
                broad = math.sin((x * 0.21) + math.sin(y * 0.11))
                pores = rng.uniform(-1.0, 1.0)
                grain = 0.955 + broad * 0.014 + pores * 0.016
            elif kind == "skin":
                grain = 0.96 + rng.uniform(-0.025, 0.025)
            elif kind == "metal":
                scratch = 0.045 if (x * 13 + y * 7) % 47 == 0 else 0.0
                grain = 0.90 + 0.05 * math.sin(y * 0.43) + scratch
            else:
                grain = 0.94 + rng.uniform(-0.02, 0.02)
            pixels.extend(
                (
                    min(max(base[0] * grain, 0.0), 1.0),
                    min(max(base[1] * grain, 0.0), 1.0),
                    min(max(base[2] * grain, 0.0), 1.0),
                    base[3],
                )
            )
    image.pixels.foreach_set(pixels)
    image.filepath_raw = os.path.join(TEXTURE_DIR, f"{name}.png")
    image.file_format = "PNG"
    image.save()
    return image


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
    metallic: float = 0.0,
    kind: str = "cloth",
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = make_texture(name, color, kind)
    texture.interpolation = "Linear"
    shader.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if "Coat Weight" in shader.inputs:
        shader.inputs["Coat Weight"].default_value = 0.0
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def finish_mesh(name: str, vertices: list[tuple[float, float, float]], faces: list[tuple[int, ...]], material: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj


def add_loft(
    name: str,
    rings: list[tuple[float, float, float, float, float]],
    material: bpy.types.Material,
    weights: list[dict[str, float]],
    sides: int = SIDES,
) -> bpy.types.Object:
    """Build a smooth elliptical loft around Blender's vertical Z axis."""
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    ring_indices: list[list[int]] = []
    for z, radius_x, radius_y, center_x, center_y in rings:
        current: list[int] = []
        for side in range(sides):
            angle = math.tau * side / sides
            current.append(len(vertices))
            vertices.append(
                (
                    center_x + math.cos(angle) * radius_x,
                    center_y + math.sin(angle) * radius_y,
                    z,
                )
            )
        ring_indices.append(current)
    for ring in range(len(ring_indices) - 1):
        lower = ring_indices[ring]
        upper = ring_indices[ring + 1]
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((lower[side], lower[nxt], upper[nxt], upper[side]))
    faces.append(tuple(reversed(ring_indices[0])))
    faces.append(tuple(ring_indices[-1]))
    obj = finish_mesh(name, vertices, faces, material)
    for ring, ring_weights in zip(ring_indices, weights):
        for bone_name, weight in ring_weights.items():
            group = obj.vertex_groups.get(bone_name) or obj.vertex_groups.new(name=bone_name)
            group.add(ring, weight, "REPLACE")
    # Caps inherit their adjacent ring weights because their faces reuse ring verts.
    return obj


def add_anatomical_torso(
    name: str,
    rings: list[tuple[float, float, float, float, float]],
    material: bpy.types.Material,
    weights: list[dict[str, float]],
    sides: int = 48,
) -> bpy.types.Object:
    """Build one fitted torso with pectoral, sternum and lat shape in its skin."""
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    ring_indices: list[list[int]] = []
    for z, radius_x, radius_y, center_x, center_y in rings:
        current: list[int] = []
        chest_factor = math.exp(-(((z - 1.585) / 0.100) ** 2))
        upper_back_factor = math.exp(-(((z - 1.600) / 0.180) ** 2))
        abdomen_factor = math.exp(-(((z - 1.315) / 0.180) ** 2))
        for side in range(sides):
            angle = math.tau * side / sides
            cosine = math.cos(angle)
            sine = math.sin(angle)
            x = center_x + cosine * radius_x
            y = center_y + sine * radius_y
            front = max(0.0, -sine) ** 4
            back = max(0.0, sine) ** 3
            pectoral_lobes = math.exp(-(((abs(cosine) - 0.34) / 0.24) ** 2))
            sternum = math.exp(-((cosine / 0.12) ** 2))
            # Two shallow fitted pectoral planes share one uninterrupted skin;
            # a subtle central relaxation supplies the sternum rather than a gap.
            y -= 0.048 * chest_factor * front * pectoral_lobes
            y += 0.010 * chest_factor * front * sternum
            # Rib/oblique tension is deliberately subtler than the chest.
            y -= 0.005 * abdomen_factor * front * (0.45 + 0.55 * abs(cosine))
            x *= 1.0 + 0.025 * upper_back_factor * back
            current.append(len(vertices))
            vertices.append((x, y, z))
        ring_indices.append(current)
    for ring in range(len(ring_indices) - 1):
        lower = ring_indices[ring]
        upper = ring_indices[ring + 1]
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((lower[side], lower[nxt], upper[nxt], upper[side]))
    faces.append(tuple(reversed(ring_indices[0])))
    faces.append(tuple(ring_indices[-1]))
    obj = finish_mesh(name, vertices, faces, material)
    for ring, ring_weights in zip(ring_indices, weights):
        for bone_name, weight in ring_weights.items():
            group = obj.vertex_groups.get(bone_name) or obj.vertex_groups.new(name=bone_name)
            group.add(ring, weight, "REPLACE")
    return obj


def add_tube(
    name: str,
    points: list[tuple[float, float, float]],
    radii: list[tuple[float, float]],
    material: bpy.types.Material,
    weights: list[dict[str, float]],
    sides: int = SIDES,
) -> bpy.types.Object:
    """Build a curved, continuous limb tube with blended joint rings."""
    centers = [Vector(point) for point in points]
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    ring_indices: list[list[int]] = []
    previous_axis = Vector((1.0, 0.0, 0.0))
    for index, center in enumerate(centers):
        if index == 0:
            tangent = (centers[1] - center).normalized()
        elif index == len(centers) - 1:
            tangent = (center - centers[index - 1]).normalized()
        else:
            tangent = (centers[index + 1] - centers[index - 1]).normalized()
        axis_x = previous_axis - tangent * previous_axis.dot(tangent)
        if axis_x.length < 0.01:
            axis_x = Vector((1.0, 0.0, 0.0)) - tangent * tangent.x
        axis_x.normalize()
        axis_y = tangent.cross(axis_x).normalized()
        previous_axis = axis_x
        current: list[int] = []
        radius_x, radius_y = radii[index]
        for side in range(sides):
            angle = math.tau * side / sides
            point = center + axis_x * (math.cos(angle) * radius_x) + axis_y * (math.sin(angle) * radius_y)
            current.append(len(vertices))
            vertices.append(tuple(point))
        ring_indices.append(current)
    for ring in range(len(ring_indices) - 1):
        lower = ring_indices[ring]
        upper = ring_indices[ring + 1]
        for side in range(sides):
            nxt = (side + 1) % sides
            faces.append((lower[side], lower[nxt], upper[nxt], upper[side]))
    faces.append(tuple(reversed(ring_indices[0])))
    faces.append(tuple(ring_indices[-1]))
    obj = finish_mesh(name, vertices, faces, material)
    for ring, ring_weights in zip(ring_indices, weights):
        for bone_name, weight in ring_weights.items():
            group = obj.vertex_groups.get(bone_name) or obj.vertex_groups.new(name=bone_name)
            group.add(ring, weight, "REPLACE")
    return obj


def assign_all(obj: bpy.types.Object, bone_name: str, weight: float = 1.0) -> None:
    group = obj.vertex_groups.get(bone_name) or obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), weight, "REPLACE")


def add_uv_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    bone_name: str,
    segments: int = 28,
    rings: int = 18,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    assign_all(obj, bone_name)
    return obj


def add_beveled_box(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    bone_name: str,
    bevel: float,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new(name="Soft tailoring", type="BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    assign_all(obj, bone_name)
    return obj


def assign_weights(obj: bpy.types.Object, resolver) -> None:
    """Assign normalized, analytical rest-space weights to generated geometry."""
    while obj.vertex_groups:
        obj.vertex_groups.remove(obj.vertex_groups[0])
    for vertex in obj.data.vertices:
        resolved = {name: weight for name, weight in resolver(vertex.co).items() if weight > 0.0001}
        total = sum(resolved.values()) or 1.0
        for name, weight in resolved.items():
            group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            group.add([vertex.index], weight / total, "REPLACE")


def voxel_union(
    name: str,
    pieces: list[bpy.types.Object],
    material: bpy.types.Material,
    voxel_size: float,
    smooth_iterations: int = 2,
) -> bpy.types.Object:
    """Union overlapping authored volumes into one continuous deforming surface."""
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    if len(pieces) > 1:
        bpy.ops.object.join()
        obj = bpy.context.object
    else:
        obj = pieces[0]
    obj.name = name
    obj.data.remesh_voxel_size = voxel_size
    obj.data.remesh_voxel_adaptivity = 0.0
    if hasattr(obj.data, "use_remesh_preserve_volume"):
        obj.data.use_remesh_preserve_volume = True
    bpy.ops.object.voxel_remesh()
    if smooth_iterations:
        smooth = obj.modifiers.new(name="Anatomical surface relaxation", type="SMOOTH")
        smooth.factor = 0.24
        smooth.iterations = smooth_iterations
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=smooth.name)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_draped_cape_panel(
    name: str,
    side: float,
    material: bpy.types.Material,
    bone_name: str,
) -> bpy.types.Object:
    """Create one thin split cape leaf with gravity arc and authored fold rhythm."""
    rows = 13
    columns = 13
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for row in range(rows):
        v = row / (rows - 1)
        top = 1.735
        bottom = 0.66
        base_z = top * (1.0 - v) + bottom * v
        inner = side * (0.028 + 0.016 * v)
        outer = side * (0.300 + 0.050 * v + 0.018 * math.sin(v * math.pi))
        for column in range(columns):
            u = column / (columns - 1)
            x = inner * (1.0 - u) + outer * u
            fold = math.sin((u * 4.0 + (0.35 if side > 0 else 0.65)) * math.pi)
            y = 0.202 + 0.085 * v + 0.034 * fold * (0.20 + 0.80 * v)
            y += 0.018 * math.sin(v * math.pi)
            shoulder_slope = 0.045 * u * ((1.0 - v) ** 4)
            hem_lift = 0.055 * ((abs(u - 0.48) / 0.52) ** 1.6) * (v ** 6)
            z = base_z - shoulder_slope + hem_lift
            vertices.append((x, y, z))
    for row in range(rows - 1):
        for column in range(columns - 1):
            a = row * columns + column
            b = a + 1
            c = a + columns + 1
            d = a + columns
            faces.append((a, b, c, d))
    obj = finish_mesh(name, vertices, faces, material)
    cape_group = obj.vertex_groups.new(name=bone_name)
    chest_group = obj.vertex_groups.new(name="chest")
    for row in range(rows):
        v = row / (rows - 1)
        indices = list(range(row * columns, (row + 1) * columns))
        cape_weight = 0.35 + 0.65 * min(v / 0.28, 1.0)
        cape_group.add(indices, cape_weight, "REPLACE")
        if cape_weight < 1.0:
            chest_group.add(indices, 1.0 - cape_weight, "REPLACE")
    solidify = obj.modifiers.new(name="Thin tailored cape", type="SOLIDIFY")
    solidify.thickness = 0.009
    solidify.offset = 0.0
    bevel = obj.modifiers.new(name="Soft cloth edge", type="BEVEL")
    bevel.width = 0.004
    bevel.segments = 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_fitted_mask_band(material: bpy.types.Material) -> bpy.types.Object:
    """Build a shallow curved eye band that follows brow, bridge, and temples."""
    segments = 28
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for depth in (0.0, 0.004):
        for row in (0, 1):
            for index in range(segments):
                t = index / (segments - 1)
                x = -0.112 + 0.224 * t
                edge = abs(x) / 0.112
                face_curve = math.sqrt(max(0.12, 1.0 - 0.78 * edge * edge))
                y = -0.108 * face_curve - depth
                center_z = 2.052 + 0.013 * edge - 0.008 * math.exp(-((x / 0.025) ** 2))
                half_height = 0.024 if row else -0.018
                vertices.append((x, y, center_z + half_height))
    stride = segments
    layer_stride = segments * 2
    for layer in range(2):
        base = layer * layer_stride
        for index in range(segments - 1):
            lower = base + index
            upper = base + stride + index
            faces.append((lower, lower + 1, upper + 1, upper))
    for index in range(segments - 1):
        front_low = index
        front_high = stride + index
        back_low = layer_stride + index
        back_high = layer_stride + stride + index
        faces.append((front_low, back_low, back_low + 1, front_low + 1))
        faces.append((front_high, front_high + 1, back_high + 1, back_high))
    faces.extend(
        [
            (0, stride, layer_stride + stride, layer_stride),
            (segments - 1, layer_stride - 1, (2 * layer_stride) - 1, layer_stride + segments - 1),
        ]
    )
    obj = finish_mesh("Fitted original eye band", vertices, faces, material)
    assign_all(obj, "head")
    return obj


def add_hair_cap(material: bpy.types.Material) -> bpy.types.Object:
    """Create a thin offset upper-skull shell with no intersecting scalp volume."""
    rings = 9
    sides = 32
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    for ring in range(rings):
        phi = (math.pi * 0.5) * ((ring + 0.10) / (rings - 0.90))
        radius = math.sin(phi)
        z = 2.064 + 0.117 * math.cos(phi)
        for side in range(sides):
            angle = math.tau * side / sides
            vertices.append((
                math.cos(angle) * 0.108 * radius,
                0.008 + math.sin(angle) * 0.114 * radius,
                z,
            ))
    for ring in range(rings - 1):
        for side in range(sides):
            nxt = (side + 1) % sides
            a = ring * sides + side
            b = ring * sides + nxt
            c = (ring + 1) * sides + nxt
            d = (ring + 1) * sides + side
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(sides))))
    obj = finish_mesh("Close cropped hair cap", vertices, faces, material)
    assign_all(obj, "head")
    solidify = obj.modifiers.new(name="Hair shell thickness", type="SOLIDIFY")
    solidify.thickness = 0.0025
    solidify.offset = -1.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    return obj


def add_curve_seam(material: bpy.types.Material) -> bpy.types.Object:
    curve = bpy.data.curves.new("Asymmetric seam path", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = 0.006
    curve.bevel_resolution = 2
    spline = curve.splines.new(type="BEZIER")
    spline.bezier_points.add(3)
    points = [(-0.085, -0.197, 1.66), (-0.105, -0.205, 1.51), (-0.075, -0.175, 1.34), (-0.040, -0.150, 1.17)]
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new("Asymmetric suit seam", curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    assign_all(obj, "chest")
    return obj


def add_mouth_line(material: bpy.types.Material) -> bpy.types.Object:
    curve = bpy.data.curves.new("Restrained mouth line", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = 0.0023
    curve.bevel_resolution = 2
    spline = curve.splines.new(type="BEZIER")
    spline.bezier_points.add(2)
    points = [(-0.036, -0.090, 1.930), (0.0, -0.101, 1.926), (0.036, -0.090, 1.930)]
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new("Mouth line", curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    assign_all(obj, "head")
    return obj


def create_armature() -> bpy.types.Object:
    armature_data = bpy.data.armatures.new("gloam_vigil_rig")
    armature = bpy.data.objects.new("GloamVigilRig", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    bones: dict[str, bpy.types.EditBone] = {}

    def bone(name: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent: str | None = None) -> None:
        edit_bone = armature_data.edit_bones.new(name)
        edit_bone.head = head
        edit_bone.tail = tail
        if parent:
            edit_bone.parent = bones[parent]
        # Keep rolls predictable so pose deltas stay consistent after glTF export.
        edit_bone.align_roll(Vector((0.0, -1.0, 0.0)))
        bones[name] = edit_bone

    bone("root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.25))
    bone("pelvis", (0.0, 0.0, 1.00), (0.0, 0.0, 1.19), "root")
    bone("spine", (0.0, 0.0, 1.16), (0.0, 0.0, 1.46), "pelvis")
    bone("chest", (0.0, 0.0, 1.43), (0.0, 0.0, 1.72), "spine")
    bone("neck", (0.0, 0.0, 1.70), (0.0, 0.0, 1.88), "chest")
    bone("head", (0.0, 0.0, 1.86), (0.0, 0.0, 2.16), "neck")

    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        x = side * 0.12
        bone(f"thigh.{suffix}", (x, 0.0, 1.08), (x, -0.006, 0.62), "pelvis")
        bone(f"shin.{suffix}", (x, -0.006, 0.62), (x, 0.0, 0.16), f"thigh.{suffix}")
        bone(f"foot.{suffix}", (x, 0.0, 0.16), (x, -0.245, 0.075), f"shin.{suffix}")
        shoulder_x = side * 0.31
        elbow_x = side * 0.39
        bone(f"upper_arm.{suffix}", (shoulder_x, 0.0, 1.68), (elbow_x, -0.006, 1.25), "chest")
        bone(f"forearm.{suffix}", (elbow_x, -0.006, 1.25), (side * 0.38, -0.030, 0.93), f"upper_arm.{suffix}")
        bone(f"hand.{suffix}", (side * 0.38, -0.030, 0.93), (side * 0.38, -0.050, 0.75), f"forearm.{suffix}")
        bone(f"cape.{suffix}", (side * 0.11, 0.10, 1.71), (side * 0.20, 0.22, 0.45), "chest")

    bpy.ops.object.mode_set(mode="OBJECT")
    armature.show_in_front = True
    armature["gloam_original_asset"] = True
    armature["pose_source"] = "Godot gameplay adapter"
    return armature


def build_character(materials: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    objects: list[bpy.types.Object] = []

    placeholder = {"root": 1.0}
    torso_rings = [
        (0.980, 0.205, 0.150, 0.0, 0.020),
        (1.040, 0.228, 0.164, 0.0, 0.020),
        (1.090, 0.242, 0.170, 0.0, 0.018),
        (1.160, 0.228, 0.154, 0.0, 0.010),
        (1.240, 0.210, 0.142, 0.0, 0.000),
        (1.320, 0.208, 0.144, 0.0, -0.004),
        (1.400, 0.225, 0.156, 0.0, -0.006),
        (1.475, 0.260, 0.176, 0.0, -0.006),
        (1.535, 0.292, 0.192, 0.0, -0.004),
        (1.595, 0.322, 0.204, 0.0, 0.000),
        (1.645, 0.326, 0.202, 0.0, 0.006),
        (1.685, 0.304, 0.186, 0.0, 0.010),
        (1.720, 0.238, 0.142, 0.0, 0.012),
        (1.790, 0.112, 0.086, 0.0, 0.012),
    ]
    upper_body_pieces = [add_anatomical_torso(
        "Anatomical trunk volume", torso_rings, materials["suit_dark"],
        [placeholder] * len(torso_rings), 48,
    )]
    semantic_legs: list[bpy.types.Object] = []

    # Deltoid and trapezius volumes are voxel-unioned into the trunk. The chest
    # itself stays within the continuous ribcage loft instead of using spheres.
    for side in (-1.0, 1.0):
        upper_body_pieces.append(add_uv_sphere(
            f"Integrated deltoid {side:+.0f}", (side * 0.318, 0.000, 1.645),
            (0.092, 0.105, 0.108), materials["suit_dark"], "root", 28, 16,
        ))
        upper_body_pieces.append(add_tube(
            f"Integrated trapezius {side:+.0f}",
            [(side * 0.085, 0.012, 1.735), (side * 0.205, 0.005, 1.690), (side * 0.305, 0.000, 1.645)],
            [(0.063, 0.054), (0.078, 0.066), (0.088, 0.080)],
            materials["suit_dark"], [placeholder] * 3, 16,
        ))

    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        leg_points = [
            (side * 0.120, 0.010, 1.085), (side * 0.125, 0.010, 0.970),
            (side * 0.128, 0.004, 0.820), (side * 0.126, -0.002, 0.690),
            (side * 0.124, -0.004, 0.605), (side * 0.124, 0.010, 0.520),
            (side * 0.122, 0.018, 0.400), (side * 0.121, 0.012, 0.290),
            (side * 0.120, 0.006, 0.165),
        ]
        leg_radii = [
            (0.147, 0.139), (0.154, 0.145), (0.142, 0.133), (0.116, 0.109),
            (0.097, 0.096), (0.112, 0.106), (0.124, 0.112), (0.104, 0.094),
            (0.073, 0.072),
        ]
        leg_piece = add_tube(
            f"Integrated leg {suffix}", leg_points, leg_radii,
            materials["suit_dark"], [placeholder] * len(leg_points), 24,
        )
        leg = voxel_union(
            f"Semantic fitted leg {suffix}", [leg_piece],
            materials["suit_dark"], 0.0105, 3,
        )

        def leg_weight_resolver(co: Vector, suffix: str = suffix) -> dict[str, float]:
            z = co.z
            if z > 1.010:
                t = max(0.0, min(1.0, (z - 1.010) / 0.105))
                return {"pelvis": t, f"thigh.{suffix}": 1.0 - t}
            if z > 0.675:
                return {f"thigh.{suffix}": 1.0}
            if z > 0.555:
                t = (z - 0.555) / 0.120
                return {f"thigh.{suffix}": t, f"shin.{suffix}": 1.0 - t}
            if z > 0.205:
                return {f"shin.{suffix}": 1.0}
            t = max(0.0, min(1.0, (z - 0.135) / 0.070))
            return {f"shin.{suffix}": t, f"foot.{suffix}": 1.0 - t}

        assign_weights(leg, leg_weight_resolver)
        leg.data.materials.append(materials["suit_mid"])
        for polygon in leg.data.polygons:
            center = polygon.center
            if 0.70 < center.z < 1.05 and abs(center.x) > 0.105 and center.y < -0.025:
                polygon.material_index = 1
        semantic_legs.append(leg)

        arm_points = [
            (side * 0.305, 0.000, 1.670), (side * 0.340, -0.002, 1.575),
            (side * 0.360, -0.003, 1.490), (side * 0.378, -0.004, 1.390),
            (side * 0.390, -0.006, 1.260), (side * 0.388, -0.012, 1.205),
            (side * 0.382, -0.020, 1.095),
            (side * 0.378, -0.027, 0.975), (side * 0.378, -0.030, 0.910),
        ]
        arm_radii = [
            (0.092, 0.100), (0.097, 0.105), (0.101, 0.108), (0.088, 0.094),
            (0.067, 0.071), (0.068, 0.071), (0.082, 0.078),
            (0.065, 0.062), (0.053, 0.052),
        ]
        upper_body_pieces.append(add_tube(
            f"Integrated arm {suffix}", arm_points, arm_radii,
            materials["suit_dark"], [placeholder] * len(arm_points), 20,
        ))

    upper_body = voxel_union(
        "Continuous fitted upper body", upper_body_pieces,
        materials["suit_dark"], 0.0105, 3,
    )

    def trunk_weight_resolver(co: Vector) -> dict[str, float]:
        x = abs(co.x)
        z = co.z
        if z < 1.155:
            return {"pelvis": 1.0}
        if z < 1.275:
            t = (z - 1.155) / 0.120
            return {"pelvis": 1.0 - t, "spine": t}
        if z < 1.455:
            return {"spine": 1.0}
        if z < 1.555:
            t = (z - 1.455) / 0.100
            return {"spine": 1.0 - t, "chest": t}
        if z < 1.710 or x > 0.155:
            return {"chest": 1.0}
        t = max(0.0, min(1.0, (z - 1.710) / 0.065))
        return {"chest": 1.0 - t, "neck": t}

    def blend_weight_maps(a: dict[str, float], b: dict[str, float], t: float) -> dict[str, float]:
        return {
            name: a.get(name, 0.0) * (1.0 - t) + b.get(name, 0.0) * t
            for name in set(a) | set(b)
        }

    def upper_body_weight_resolver(co: Vector) -> dict[str, float]:
        x = abs(co.x)
        z = co.z
        side = "L" if co.x < 0.0 else "R"
        trunk = trunk_weight_resolver(co)
        if z < 0.840 or z > 1.800:
            return trunk
        if z > 1.630:
            upper_amount = max(0.0, min(1.0, (1.780 - z) / 0.150))
            arm = {"chest": 1.0 - upper_amount, f"upper_arm.{side}": upper_amount}
        elif z > 1.310:
            arm = {f"upper_arm.{side}": 1.0}
        elif z > 1.185:
            t = (z - 1.185) / 0.125
            arm = {f"upper_arm.{side}": t, f"forearm.{side}": 1.0 - t}
        elif z > 0.950:
            arm = {f"forearm.{side}": 1.0}
        else:
            t = max(0.0, min(1.0, (z - 0.875) / 0.075))
            arm = {f"forearm.{side}": t, f"hand.{side}": 1.0 - t}
        if z < 1.200:
            inner, outer = 0.285, 0.315
        elif z < 1.500:
            band_t = (z - 1.200) / 0.300
            inner = 0.285 + (0.200 - 0.285) * band_t
            outer = 0.315 + (0.325 - 0.315) * band_t
        else:
            inner, outer = 0.200, 0.325
        spatial = max(0.0, min(1.0, (x - inner) / (outer - inner)))
        spatial = spatial * spatial * (3.0 - 2.0 * spatial)
        return blend_weight_maps(trunk, arm, spatial)

    assign_weights(upper_body, upper_body_weight_resolver)
    upper_body.data.materials.append(materials["suit_mid"])
    for polygon in upper_body.data.polygons:
        center = polygon.center
        if 1.35 < center.z < 1.70 and abs(center.x) > 0.205 and center.y < 0.08:
            polygon.material_index = 1
    objects.append(upper_body)
    objects.extend(semantic_legs)

    # The skin neck remains visible between fitted collar and proportional head.
    neck_rings = [
        (1.725, 0.120, 0.096, 0.0, 0.010),
        (1.770, 0.102, 0.086, 0.0, 0.008),
        (1.835, 0.076, 0.074, 0.0, 0.004),
        (1.885, 0.074, 0.076, 0.0, 0.000),
        (1.915, 0.070, 0.073, 0.0, -0.002),
    ]
    objects.append(add_loft(
        "Visible neck", neck_rings, materials["skin"],
        [{"chest": 0.45, "neck": 0.55}, {"neck": 1.0}, {"neck": 1.0},
         {"neck": 0.65, "head": 0.35}, {"head": 1.0}], 28,
    ))

    # A 0.30 m head is built from unioned skull, jaw, cheeks, chin, nose and
    # ears so the face owns a readable profile rather than a featureless egg.
    head_pieces = [
        add_uv_sphere("Cranium volume", (0.0, 0.006, 2.055), (0.104, 0.110, 0.123), materials["skin"], "head", 28, 18),
        add_loft(
            "Jaw and lower face volume",
            [(1.880, 0.055, 0.057, 0.0, -0.016), (1.910, 0.068, 0.072, 0.0, -0.013),
             (1.950, 0.083, 0.090, 0.0, -0.008), (1.990, 0.096, 0.101, 0.0, -0.003),
             (2.035, 0.104, 0.108, 0.0, 0.003), (2.080, 0.104, 0.110, 0.0, 0.006),
             (2.115, 0.098, 0.104, 0.0, 0.008)],
            materials["skin"], [{"head": 1.0}] * 7, 32,
        ),
        add_uv_sphere("Chin volume", (0.0, -0.052, 1.902), (0.054, 0.024, 0.025), materials["skin"], "head", 24, 14),
        add_uv_sphere("Left ear", (-0.106, 0.000, 2.015), (0.016, 0.012, 0.031), materials["skin"], "head", 16, 10),
        add_uv_sphere("Right ear", (0.106, 0.000, 2.015), (0.016, 0.012, 0.031), materials["skin"], "head", 16, 10),
    ]
    nose_vertices = [
        (-0.019, -0.092, 2.043), (0.019, -0.092, 2.043),
        (-0.016, -0.096, 1.989), (0.016, -0.096, 1.989),
        (0.000, -0.128, 2.000), (0.000, -0.116, 2.038),
    ]
    nose_faces = [(0, 1, 5), (0, 5, 4, 2), (1, 3, 4, 5), (2, 4, 3), (0, 2, 3, 1)]
    nose = finish_mesh("Nose bridge and tip", nose_vertices, nose_faces, materials["skin"])
    assign_all(nose, "head")
    head_pieces.append(nose)
    head = voxel_union("Anatomical head", head_pieces, materials["skin"], 0.0045, 2)
    assign_all(head, "head")
    objects.append(head)
    objects.append(add_mouth_line(materials["mask"]))

    # Hair cap and tactical eye band are compact, fitted and explicitly free of
    # pointed ears, symbols, or other franchise silhouette language.
    objects.append(add_hair_cap(materials["mask"]))
    objects.append(add_fitted_mask_band(materials["mask"]))
    for side, suffix in ((-1.0, "L"), (1.0, "R")):
        objects.append(add_uv_sphere(
            f"Narrow eye lens {suffix}", (side * 0.044, -0.117, 2.051),
            (0.025, 0.003, 0.008), materials["metal"], "head", 18, 8,
        ))

        # Palm, individual fingers, and angled thumb are remeshed as one glove.
        hand_center = side * 0.380
        hand_pieces = [add_uv_sphere(
            f"Palm {suffix}", (hand_center, -0.035, 0.845),
            (0.060, 0.043, 0.079), materials["glove"], f"hand.{suffix}", 20, 12,
        )]
        for finger_index, offset in enumerate((-0.039, -0.013, 0.013, 0.039)):
            finger_x = hand_center + offset
            hand_pieces.append(add_tube(
                f"Finger {finger_index + 1} {suffix}",
                [(finger_x, -0.046, 0.825), (finger_x, -0.050, 0.785), (finger_x, -0.047, 0.750 + 0.006 * abs(finger_index - 1.5))],
                [(0.014, 0.014), (0.013, 0.013), (0.010, 0.010)],
                materials["glove"], [{f"hand.{suffix}": 1.0}] * 3, 12,
            ))
        hand_pieces.append(add_tube(
            f"Angled thumb {suffix}",
            [(hand_center + side * 0.045, -0.040, 0.875),
             (hand_center + side * 0.069, -0.055, 0.842),
             (hand_center + side * 0.075, -0.057, 0.812)],
            [(0.022, 0.021), (0.019, 0.018), (0.014, 0.014)],
            materials["glove"], [{f"hand.{suffix}": 1.0}] * 3, 12,
        ))
        hand = voxel_union(f"Articulated glove {suffix}", hand_pieces, materials["glove"], 0.006, 1)
        assign_all(hand, f"hand.{suffix}")
        objects.append(hand)

        # Shaped boot volumes establish heel, ankle, instep and tapered toe.
        boot_pieces = [
            add_loft(
                f"Boot shaft volume {suffix}",
                [(0.105, 0.088, 0.078, side * 0.120, 0.000),
                 (0.205, 0.083, 0.080, side * 0.120, 0.008),
                 (0.340, 0.096, 0.088, side * 0.121, 0.014)],
                materials["boot"], [{f"foot.{suffix}": 1.0}, {f"foot.{suffix}": 0.65, f"shin.{suffix}": 0.35}, {f"shin.{suffix}": 1.0}], 20,
            ),
            add_uv_sphere(f"Boot heel {suffix}", (side * 0.120, 0.025, 0.080), (0.087, 0.073, 0.070), materials["boot"], f"foot.{suffix}", 20, 12),
            add_uv_sphere(f"Boot instep {suffix}", (side * 0.120, -0.070, 0.076), (0.092, 0.105, 0.068), materials["boot"], f"foot.{suffix}", 20, 12),
            add_uv_sphere(f"Boot toe {suffix}", (side * 0.120, -0.178, 0.064), (0.096, 0.095, 0.052), materials["boot"], f"foot.{suffix}", 20, 12),
        ]
        boot = voxel_union(f"Shaped tactical boot {suffix}", boot_pieces, materials["boot"], 0.007, 1)
        assign_weights(
            boot,
            lambda co, suffix=suffix: ({f"shin.{suffix}": 1.0} if co.z > 0.27 else
                                      ({f"shin.{suffix}": (co.z - 0.19) / 0.08, f"foot.{suffix}": (0.27 - co.z) / 0.08}
                                       if co.z > 0.19 else {f"foot.{suffix}": 1.0})),
        )
        objects.append(boot)

        objects.append(add_uv_sphere(
            f"Fitted knee shell {suffix}", (side * 0.124, -0.108, 0.605),
            (0.076, 0.018, 0.056), materials["armor"], f"shin.{suffix}", 20, 12,
        ))
        objects.append(add_loft(
            f"Tapered forearm bracer {suffix}",
            [(0.930, 0.065, 0.062, side * 0.378, -0.030),
             (1.050, 0.079, 0.075, side * 0.380, -0.024),
             (1.150, 0.086, 0.080, side * 0.386, -0.016)],
            materials["armor"], [{f"forearm.{suffix}": 0.65, f"hand.{suffix}": 0.35}, {f"forearm.{suffix}": 1.0}, {f"forearm.{suffix}": 1.0}], 20,
        ))
        objects.append(add_draped_cape_panel(
            f"Draped split cape {suffix}", side, materials["cape"], f"cape.{suffix}",
        ))

    objects.append(add_loft(
        "Utility belt band",
        [(1.035, 0.244, 0.170, 0.0, 0.014), (1.085, 0.247, 0.172, 0.0, 0.014)],
        materials["belt"], [{"pelvis": 1.0}, {"pelvis": 0.78, "spine": 0.22}], 30,
    ))
    objects.append(add_beveled_box(
        "Utility belt clasp", (0.0, -0.185, 1.060), (0.047, 0.018, 0.032),
        materials["accent"], "pelvis", 0.012,
    ))
    pouch_layout = [(-0.175, -0.152), (-0.092, -0.178), (0.092, -0.178), (0.175, -0.152)]
    for index, (x, y) in enumerate(pouch_layout):
        pouch = add_beveled_box(
            f"Tailored utility pouch {index + 1}", (x, y, 1.055),
            (0.047, 0.028, 0.045), materials["pouch"], "pelvis", 0.014,
        )
        pouch.rotation_euler.z = math.radians(-7.0 if x > 0 else 7.0)
        objects.append(pouch)

    objects.append(add_curve_seam(materials["accent"]))
    objects.append(add_uv_sphere(
        "Minimal cape clasp", (0.0, -0.190, 1.700), (0.032, 0.014, 0.032),
        materials["metal"], "chest", 18, 10,
    ))

    return objects


def join_and_rig(objects: list[bpy.types.Object], armature: bpy.types.Object) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    model = bpy.context.object
    model.name = "GloamVigilPlayerMesh"
    model.data.name = "gloam_vigil_player_mesh"
    model["asset_role"] = "original_player_visual"
    model["forward_axis"] = "Godot +Z"
    for polygon in model.data.polygons:
        polygon.use_smooth = True
    # One atlas-style unwrap makes the generated weave/leather textures usable
    # across both custom lofts and Blender primitives. Triangulating here also
    # lets the glTF exporter emit stable tangents for future normal maps.
    bpy.context.view_layer.objects.active = model
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62.0), island_margin=0.018)
    bpy.ops.object.mode_set(mode="OBJECT")
    triangulate = model.modifiers.new(name="Export triangulation", type="TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    modifier = model.modifiers.new(name="Gloam Vigil armature", type="ARMATURE")
    modifier.object = armature
    modifier.use_deform_preserve_volume = True
    model.parent = armature
    model.matrix_parent_inverse = armature.matrix_world.inverted()
    return model


def validate_contract(model: bpy.types.Object, armature: bpy.types.Object) -> None:
    expected_bones = {
        "root", "pelvis", "spine", "chest", "neck", "head",
        "thigh.L", "shin.L", "foot.L", "upper_arm.L", "forearm.L", "hand.L", "cape.L",
        "thigh.R", "shin.R", "foot.R", "upper_arm.R", "forearm.R", "hand.R", "cape.R",
    }
    expected_materials = {
        "MAT_Accent", "MAT_Fitted_Armor", "MAT_Glove", "MAT_Metal",
        "MAT_Original_Mask", "MAT_Skin", "MAT_Split_Cape", "MAT_Suit_Contour",
        "MAT_Suit_Dark", "MAT_Tactical_Boot", "MAT_Utility_Belt", "MAT_Utility_Pouches",
    }
    actual_bones = {bone.name for bone in armature.data.bones}
    actual_materials = {material.name for material in model.data.materials if material}
    assert actual_bones == expected_bones, f"Bone contract drift: {sorted(actual_bones ^ expected_bones)}"
    assert actual_materials == expected_materials, f"Material contract drift: {sorted(actual_materials ^ expected_materials)}"

    group_names = {group.index: group.name for group in model.vertex_groups}
    leg_groups = {f"{part}.{side}" for part in ("thigh", "shin", "foot") for side in ("L", "R")}
    low_pelvis: list[int] = []
    ankle_without_leg: list[int] = []
    arm_with_leg: list[int] = []
    invalid_weight_sum: list[int] = []
    excessive_influences: list[int] = []
    vertex_weights: dict[int, dict[str, float]] = {}
    for vertex in model.data.vertices:
        weights = {
            group_names[element.group]: element.weight
            for element in vertex.groups
            if element.weight > 0.0001
        }
        vertex_weights[vertex.index] = weights
        total = sum(weights.values())
        if abs(total - 1.0) > 0.0005:
            invalid_weight_sum.append(vertex.index)
        if len(weights) > 4:
            excessive_influences.append(vertex.index)
        x = abs(vertex.co.x)
        z = vertex.co.z
        if z < 0.900 and weights.get("pelvis", 0.0) > 0.0001:
            low_pelvis.append(vertex.index)
        if z < 0.250 and sum(weights.get(name, 0.0) for name in leg_groups) < 0.999:
            ankle_without_leg.append(vertex.index)
        if x > 0.300 and 0.840 < z < 1.600 and any(weights.get(name, 0.0) > 0.0001 for name in leg_groups):
            arm_with_leg.append(vertex.index)

    arm_leg_edges: list[int] = []
    cross_leg_edges: list[int] = []
    hard_shoulder_edges: list[int] = []
    max_shoulder_l1 = 0.0
    for edge in model.data.edges:
        a, b = edge.vertices
        wa = vertex_weights[a]
        wb = vertex_weights[b]
        arm_a = sum(wa.get(f"{part}.{side}", 0.0) for part in ("upper_arm", "forearm", "hand") for side in ("L", "R"))
        arm_b = sum(wb.get(f"{part}.{side}", 0.0) for part in ("upper_arm", "forearm", "hand") for side in ("L", "R"))
        leg_a = sum(wa.get(name, 0.0) for name in leg_groups)
        leg_b = sum(wb.get(name, 0.0) for name in leg_groups)
        if (arm_a > 0.01 and leg_b > 0.01) or (arm_b > 0.01 and leg_a > 0.01):
            arm_leg_edges.append(edge.index)
        left_a = sum(wa.get(f"{part}.L", 0.0) for part in ("thigh", "shin", "foot"))
        right_a = sum(wa.get(f"{part}.R", 0.0) for part in ("thigh", "shin", "foot"))
        left_b = sum(wb.get(f"{part}.L", 0.0) for part in ("thigh", "shin", "foot"))
        right_b = sum(wb.get(f"{part}.R", 0.0) for part in ("thigh", "shin", "foot"))
        if max(model.data.vertices[a].co.z, model.data.vertices[b].co.z) < 1.0 and (
            (left_a > 0.01 and right_b > 0.01) or (right_a > 0.01 and left_b > 0.01)
        ):
            cross_leg_edges.append(edge.index)
        midpoint_x = abs((model.data.vertices[a].co.x + model.data.vertices[b].co.x) * 0.5)
        midpoint_z = (model.data.vertices[a].co.z + model.data.vertices[b].co.z) * 0.5
        trunk_names = ("root", "pelvis", "spine", "chest", "neck", "head")
        trunk_a = sum(wa.get(name, 0.0) for name in trunk_names)
        trunk_b = sum(wb.get(name, 0.0) for name in trunk_names)
        if midpoint_x > 0.18 and 1.20 < midpoint_z < 1.78 and (
            (arm_a > 0.01 and trunk_b > 0.01) or (arm_b > 0.01 and trunk_a > 0.01)
        ):
            l1 = sum(abs(wa.get(name, 0.0) - wb.get(name, 0.0)) for name in set(wa) | set(wb))
            max_shoulder_l1 = max(max_shoulder_l1, l1)
            if l1 > 0.75:
                hard_shoulder_edges.append(edge.index)
    assert not invalid_weight_sum, f"Non-normalized weights: {invalid_weight_sum[:12]}"
    assert not excessive_influences, f"More than four influences: {excessive_influences[:12]}"
    assert not low_pelvis, f"Low-body vertices bound to pelvis: {low_pelvis[:12]}"
    assert not ankle_without_leg, f"Ankle/sole vertices without leg ownership: {ankle_without_leg[:12]}"
    assert not arm_with_leg, f"Arm/wrist region contaminated by leg groups: {arm_with_leg[:12]}"
    assert not arm_leg_edges, f"Arm and leg semantic components share edges: {arm_leg_edges[:12]}"
    assert not cross_leg_edges, f"Left/right legs share sub-pelvis edges: {cross_leg_edges[:12]}"
    if hard_shoulder_edges:
        details = []
        for edge_index in hard_shoulder_edges[:12]:
            edge = model.data.edges[edge_index]
            a, b = edge.vertices
            details.append({
                "edge": edge_index,
                "a": tuple(round(value, 5) for value in model.data.vertices[a].co),
                "a_weights": {name: round(value, 4) for name, value in vertex_weights[a].items()},
                "b": tuple(round(value, 5) for value in model.data.vertices[b].co),
                "b_weights": {name: round(value, 4) for name, value in vertex_weights[b].items()},
            })
        raise AssertionError(f"Hard shoulder weight discontinuities: {details}")
    print(
        "GLOAM_VIGIL_CONTRACT_OK "
        f"bones={len(actual_bones)} materials={len(actual_materials)} "
        f"vertices={len(model.data.vertices)} max_influences=4 "
        f"low_pelvis={len(low_pelvis)} ankle_without_leg={len(ankle_without_leg)} "
        f"arm_with_leg={len(arm_with_leg)} arm_leg_edges={len(arm_leg_edges)} "
        f"cross_leg_edges={len(cross_leg_edges)} hard_shoulder_edges={len(hard_shoulder_edges)} "
        f"max_shoulder_l1={max_shoulder_l1:.4f}"
    )


def export_asset(model: bpy.types.Object, armature: bpy.types.Object) -> None:
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    model.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
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
        export_morph=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_draco_mesh_compression_enable=False,
        export_meshopt_compression_enable=False,
    )


def main() -> None:
    reset_scene()
    materials = {
        "suit_dark": make_material("MAT_Suit_Dark", (0.042, 0.060, 0.086, 1.0), 0.92, kind="cloth"),
        "suit_mid": make_material("MAT_Suit_Contour", (0.060, 0.082, 0.112, 1.0), 0.90, kind="cloth"),
        "armor": make_material("MAT_Fitted_Armor", (0.062, 0.075, 0.102, 1.0), 0.82, 0.06, kind="leather"),
        "cape": make_material("MAT_Split_Cape", (0.025, 0.023, 0.046, 1.0), 0.95, kind="cloth"),
        "mask": make_material("MAT_Original_Mask", (0.030, 0.045, 0.064, 1.0), 0.84, 0.03, kind="leather"),
        "belt": make_material("MAT_Utility_Belt", (0.145, 0.086, 0.048, 1.0), 0.82, 0.03, kind="leather"),
        "pouch": make_material("MAT_Utility_Pouches", (0.092, 0.058, 0.041, 1.0), 0.84, kind="leather"),
        "boot": make_material("MAT_Tactical_Boot", (0.012, 0.018, 0.030, 1.0), 0.90, kind="leather"),
        "glove": make_material("MAT_Glove", (0.016, 0.022, 0.035, 1.0), 0.90, kind="leather"),
        "skin": make_material("MAT_Skin", (0.43, 0.315, 0.270, 1.0), 0.72, kind="skin"),
        "metal": make_material("MAT_Metal", (0.24, 0.30, 0.39, 1.0), 0.58, 0.48, kind="metal"),
        "accent": make_material("MAT_Accent", (0.56, 0.055, 0.16, 1.0), 0.70, 0.02, kind="cloth"),
    }
    armature = create_armature()
    objects = build_character(materials)
    model = join_and_rig(objects, armature)
    validate_contract(model, armature)
    export_asset(model, armature)
    print(f"GLOAM_VIGIL_EXPORT_OK blend={BLEND_PATH} glb={GLB_PATH} verts={len(model.data.vertices)} polys={len(model.data.polygons)}")


if __name__ == "__main__":
    main()
