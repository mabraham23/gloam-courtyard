"""Small deterministic mesh-part helpers for the v2 technical candidate.

These helpers emit explicit loft, tube, ribbon, ellipsoid, torus, cape, and UV
data, with a skin-weight map on every source vertex.  The r4 generator later
performs a Blender voxel union/smooth/decimate step on its assembled facial
skin, then reconstructs weights spatially; this module is therefore only the
source-part layer, not a claim that the final candidate avoids remeshing.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import math
from typing import Callable, Iterable, Sequence

import bpy
from mathutils import Vector


Vec3 = tuple[float, float, float]
Weights = dict[str, float]


def normalized(weights: Weights) -> Weights:
    positive = {name: value for name, value in weights.items() if value > 1.0e-7}
    total = sum(positive.values())
    if total <= 1.0e-8:
        raise ValueError("Generated vertex has no deform weight")
    return {name: value / total for name, value in positive.items()}


def blend_weights(a: Weights, b: Weights, factor: float) -> Weights:
    factor = max(0.0, min(1.0, factor))
    names = set(a) | set(b)
    return normalized({name: a.get(name, 0.0) * (1.0 - factor) + b.get(name, 0.0) * factor for name in names})


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return float(value >= edge1)
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


@dataclass
class MeshPart:
    vertices: list[Vec3]
    faces: list[tuple[int, ...]]
    weights: list[Weights]
    material: str
    tags: dict[str, set[int]] = field(default_factory=dict)

    def validate(self) -> None:
        assert len(self.vertices) == len(self.weights)
        assert self.vertices
        assert self.faces
        for face in self.faces:
            assert len(face) >= 3
            assert min(face) >= 0 and max(face) < len(self.vertices)
        for weights in self.weights:
            assert abs(sum(weights.values()) - 1.0) < 1.0e-5


class MeshAssembly:
    def __init__(self) -> None:
        self.vertices: list[Vec3] = []
        self.faces: list[tuple[int, ...]] = []
        self.weights: list[Weights] = []
        self.face_material_names: list[str] = []
        self.tags: dict[str, set[int]] = {}

    def append(self, part: MeshPart) -> None:
        part.validate()
        offset = len(self.vertices)
        self.vertices.extend(part.vertices)
        self.weights.extend(part.weights)
        self.faces.extend(tuple(index + offset for index in face) for face in part.faces)
        self.face_material_names.extend([part.material] * len(part.faces))
        for tag, indices in part.tags.items():
            self.tags.setdefault(tag, set()).update(index + offset for index in indices)

    def build(self, name: str, materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
        if not self.vertices:
            raise ValueError(f"Cannot build empty assembly {name}")
        mesh = bpy.data.meshes.new(f"{name}Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)

        used_materials: list[str] = []
        for material_name in self.face_material_names:
            if material_name not in used_materials:
                used_materials.append(material_name)
        for material_name in used_materials:
            obj.data.materials.append(materials[material_name])
        material_indices = {name: index for index, name in enumerate(used_materials)}
        for polygon, material_name in zip(obj.data.polygons, self.face_material_names, strict=True):
            polygon.material_index = material_indices[material_name]
            polygon.use_smooth = True

        groups: dict[str, bpy.types.VertexGroup] = {}
        for vertex_index, weights in enumerate(self.weights):
            for group_name, value in weights.items():
                group = groups.get(group_name)
                if group is None:
                    group = obj.vertex_groups.new(name=group_name)
                    groups[group_name] = group
                group.add([vertex_index], value, "REPLACE")
        return obj


def horizontal_loft(
    rings: Sequence[tuple[Vec3, float, float, Weights]],
    sides: int,
    material: str,
    deform: Callable[[Vec3, float, int], Vec3] | None = None,
    tagger: Callable[[Vec3, float, int], Iterable[str]] | None = None,
    cap: bool = True,
) -> MeshPart:
    vertices: list[Vec3] = []
    weights: list[Weights] = []
    tags: dict[str, set[int]] = {}
    for ring_index, (center, radius_x, radius_y, ring_weights) in enumerate(rings):
        for side_index in range(sides):
            angle = math.tau * side_index / sides
            position: Vec3 = (
                center[0] + radius_x * math.sin(angle),
                center[1] - radius_y * math.cos(angle),
                center[2],
            )
            if deform:
                position = deform(position, angle, ring_index)
            vertex_index = len(vertices)
            vertices.append(position)
            weights.append(normalized(dict(ring_weights)))
            if tagger:
                for tag in tagger(position, angle, ring_index):
                    tags.setdefault(tag, set()).add(vertex_index)

    faces: list[tuple[int, ...]] = []
    for ring_index in range(len(rings) - 1):
        start = ring_index * sides
        next_start = (ring_index + 1) * sides
        for side_index in range(sides):
            following = (side_index + 1) % sides
            faces.append((start + side_index, start + following, next_start + following, next_start + side_index))

    if cap:
        bottom_index = len(vertices)
        vertices.append(rings[0][0])
        weights.append(normalized(dict(rings[0][3])))
        top_index = len(vertices)
        vertices.append(rings[-1][0])
        weights.append(normalized(dict(rings[-1][3])))
        last_start = (len(rings) - 1) * sides
        for side_index in range(sides):
            following = (side_index + 1) % sides
            faces.append((bottom_index, following, side_index))
            faces.append((top_index, last_start + side_index, last_start + following))

    return MeshPart(vertices, faces, weights, material, tags)


def path_tube(
    points: Sequence[Vec3],
    radii: Sequence[tuple[float, float]],
    ring_weights: Sequence[Weights],
    sides: int,
    material: str,
    tag_names: Sequence[str | None] | None = None,
    cap: bool = True,
) -> MeshPart:
    assert len(points) == len(radii) == len(ring_weights)
    vertices: list[Vec3] = []
    weights: list[Weights] = []
    tags: dict[str, set[int]] = {}
    frames: list[tuple[Vector, Vector]] = []
    for index, point in enumerate(points):
        before = Vector(points[max(index - 1, 0)])
        after = Vector(points[min(index + 1, len(points) - 1)])
        tangent = (after - before).normalized()
        guide = Vector((0.0, -1.0, 0.0))
        if abs(tangent.dot(guide)) > 0.92:
            guide = Vector((0.0, 0.0, 1.0))
        axis_a = tangent.cross(guide).normalized()
        axis_b = axis_a.cross(tangent).normalized()
        if frames and axis_a.dot(frames[-1][0]) < 0.0:
            axis_a.negate()
            axis_b.negate()
        frames.append((axis_a, axis_b))

    for ring_index, point in enumerate(points):
        axis_a, axis_b = frames[ring_index]
        for side_index in range(sides):
            angle = math.tau * side_index / sides
            offset = axis_a * (math.cos(angle) * radii[ring_index][0]) + axis_b * (math.sin(angle) * radii[ring_index][1])
            position = Vector(point) + offset
            vertex_index = len(vertices)
            vertices.append((position.x, position.y, position.z))
            weights.append(normalized(dict(ring_weights[ring_index])))
            if tag_names and tag_names[ring_index]:
                tags.setdefault(tag_names[ring_index] or "", set()).add(vertex_index)

    faces: list[tuple[int, ...]] = []
    for ring_index in range(len(points) - 1):
        start = ring_index * sides
        next_start = (ring_index + 1) * sides
        for side_index in range(sides):
            following = (side_index + 1) % sides
            faces.append((start + side_index, start + following, next_start + following, next_start + side_index))
    if cap:
        start_center = len(vertices)
        vertices.append(points[0])
        weights.append(normalized(dict(ring_weights[0])))
        end_center = len(vertices)
        vertices.append(points[-1])
        weights.append(normalized(dict(ring_weights[-1])))
        last_start = (len(points) - 1) * sides
        for side_index in range(sides):
            following = (side_index + 1) % sides
            faces.append((start_center, side_index, following))
            faces.append((end_center, last_start + following, last_start + side_index))
    return MeshPart(vertices, faces, weights, material, tags)


def ellipsoid(
    center: Vec3,
    scale: Vec3,
    segments: int,
    rings: int,
    material: str,
    weight_fn: Callable[[Vec3], Weights],
    deform: Callable[[Vec3, float, float], Vec3] | None = None,
    tagger: Callable[[Vec3], Iterable[str]] | None = None,
) -> MeshPart:
    vertices: list[Vec3] = []
    weights: list[Weights] = []
    tags: dict[str, set[int]] = {}

    def add(position: Vec3, latitude: float, longitude: float) -> int:
        if deform:
            position = deform(position, latitude, longitude)
        index = len(vertices)
        vertices.append(position)
        weights.append(normalized(weight_fn(position)))
        if tagger:
            for tag in tagger(position):
                tags.setdefault(tag, set()).add(index)
        return index

    bottom = add((center[0], center[1], center[2] - scale[2]), -math.pi / 2.0, 0.0)
    for ring_index in range(1, rings):
        latitude = -math.pi / 2.0 + math.pi * ring_index / rings
        cos_lat = math.cos(latitude)
        for segment in range(segments):
            longitude = math.tau * segment / segments
            position = (
                center[0] + scale[0] * cos_lat * math.sin(longitude),
                center[1] - scale[1] * cos_lat * math.cos(longitude),
                center[2] + scale[2] * math.sin(latitude),
            )
            add(position, latitude, longitude)
    top = add((center[0], center[1], center[2] + scale[2]), math.pi / 2.0, 0.0)

    faces: list[tuple[int, ...]] = []
    first_ring = 1
    for segment in range(segments):
        following = (segment + 1) % segments
        faces.append((bottom, first_ring + following, first_ring + segment))
    for ring_index in range(rings - 2):
        start = 1 + ring_index * segments
        next_start = start + segments
        for segment in range(segments):
            following = (segment + 1) % segments
            faces.append((start + segment, start + following, next_start + following, next_start + segment))
    last_ring = 1 + (rings - 2) * segments
    for segment in range(segments):
        following = (segment + 1) % segments
        faces.append((top, last_ring + segment, last_ring + following))
    return MeshPart(vertices, faces, weights, material, tags)


def torus(
    center: Vec3,
    major: tuple[float, float],
    minor: tuple[float, float],
    major_segments: int,
    minor_segments: int,
    material: str,
    weights: Weights,
) -> MeshPart:
    vertices: list[Vec3] = []
    vertex_weights: list[Weights] = []
    for major_index in range(major_segments):
        a = math.tau * major_index / major_segments
        radial = Vector((math.sin(a), -math.cos(a), 0.0))
        for minor_index in range(minor_segments):
            b = math.tau * minor_index / minor_segments
            position = Vector(center) + Vector((major[0] * math.sin(a), -major[1] * math.cos(a), 0.0))
            position += radial * (minor[0] * math.cos(b)) + Vector((0.0, 0.0, minor[1] * math.sin(b)))
            vertices.append((position.x, position.y, position.z))
            vertex_weights.append(normalized(dict(weights)))
    faces: list[tuple[int, ...]] = []
    for major_index in range(major_segments):
        next_major = (major_index + 1) % major_segments
        for minor_index in range(minor_segments):
            next_minor = (minor_index + 1) % minor_segments
            faces.append((
                major_index * minor_segments + minor_index,
                major_index * minor_segments + next_minor,
                next_major * minor_segments + next_minor,
                next_major * minor_segments + minor_index,
            ))
    return MeshPart(vertices, faces, vertex_weights, material)


def thick_ribbon(
    inner: Sequence[Vec3],
    outer: Sequence[Vec3],
    thickness: float,
    material: str,
    weights: Weights,
    tag: str | None = None,
) -> MeshPart:
    assert len(inner) == len(outer) and len(inner) >= 2
    vertices: list[Vec3] = []
    vertex_weights: list[Weights] = []
    tags: dict[str, set[int]] = {tag: set()} if tag else {}
    for depth in (-thickness * 0.5, thickness * 0.5):
        for curve in (inner, outer):
            for position in curve:
                vertices.append((position[0], position[1] + depth, position[2]))
                vertex_weights.append(normalized(dict(weights)))
                if tag:
                    tags[tag].add(len(vertices) - 1)
    count = len(inner)
    faces: list[tuple[int, ...]] = []
    # Two broad faces.
    for layer in range(2):
        inner_start = layer * count * 2
        outer_start = inner_start + count
        for index in range(count - 1):
            if layer == 0:
                faces.append((inner_start + index, inner_start + index + 1, outer_start + index + 1, outer_start + index))
            else:
                faces.append((inner_start + index, outer_start + index, outer_start + index + 1, inner_start + index + 1))
    # Seal the inner/outer long edges and two ends.
    front_inner, front_outer = 0, count
    back_inner, back_outer = count * 2, count * 3
    for index in range(count - 1):
        faces.append((front_inner + index, back_inner + index, back_inner + index + 1, front_inner + index + 1))
        faces.append((front_outer + index, front_outer + index + 1, back_outer + index + 1, back_outer + index))
    faces.append((front_inner, front_outer, back_outer, back_inner))
    faces.append((front_inner + count - 1, back_inner + count - 1, back_outer + count - 1, front_outer + count - 1))
    return MeshPart(vertices, faces, vertex_weights, material, tags)


def cape_panel(
    side_sign: float,
    columns: int,
    rows: int,
    material: str,
    cape_bones: Sequence[str],
) -> MeshPart:
    vertices: list[Vec3] = []
    weights: list[Weights] = []
    thickness = 0.004

    def position(u: float, v: float, layer: float) -> Vec3:
        # A split, knee-length panel with a shallow gravity arc and restrained
        # longitudinal folds.  The hem stays above the accepted crouch floor.
        inner_x = 0.012 + 0.055 * v
        width = 0.205 + 0.105 * v
        x = side_sign * (inner_x + width * u)
        z = 1.705 - 1.155 * v - 0.020 * u * v + 0.010 * math.cos(math.pi * u) * v
        fold = 0.014 * math.sin(math.tau * (2.4 * u + 0.20 * v)) * (0.25 + 0.75 * v)
        y = 0.108 + 0.150 * v + 0.052 * v * v + fold + layer * thickness
        return (x, y, z)

    for layer in (-0.5, 0.5):
        for row in range(rows + 1):
            v = row / rows
            segment = min(3, int(v * 4.0))
            local = v * 4.0 - segment
            if segment == 3:
                local = min(local, 1.0)
            for column in range(columns + 1):
                u = column / columns
                vertices.append(position(u, v, layer))
                if segment >= 3:
                    weights.append({cape_bones[3]: 1.0})
                else:
                    weights.append(blend_weights({cape_bones[segment]: 1.0}, {cape_bones[segment + 1]: 1.0}, smoothstep(0.25, 0.75, local)))

    stride = columns + 1
    layer_size = stride * (rows + 1)
    faces: list[tuple[int, ...]] = []
    for layer_index in range(2):
        base = layer_index * layer_size
        for row in range(rows):
            for column in range(columns):
                a = base + row * stride + column
                b = a + 1
                c = a + stride + 1
                d = a + stride
                faces.append((a, b, c, d) if layer_index == 0 else (a, d, c, b))
    # Seal four panel boundaries.
    for row in range(rows):
        for column in (0, columns):
            a = row * stride + column
            b = (row + 1) * stride + column
            faces.append((a, b, b + layer_size, a + layer_size))
    for column in range(columns):
        for row in (0, rows):
            a = row * stride + column
            b = a + 1
            faces.append((a, a + layer_size, b + layer_size, b))
    return MeshPart(vertices, faces, [normalized(w) for w in weights], material)


def smart_uv(obj: bpy.types.Object, island_margin: float = 0.012) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=island_margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def triangulate(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new(name="Deterministic export triangulation", type="TRIANGULATE")
    modifier.quad_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)
