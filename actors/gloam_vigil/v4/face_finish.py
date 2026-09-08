"""Face finishing for the licensed v4 anatomical foundation.

The facial anatomy is Dan Ulrich's CC0 ``Body Male - Realistic`` mesh from
Blender's Human Base Meshes bundle 1.4.1.  This module deliberately preserves
that scan-derived, continuous head/neck surface.  It only adds Gloam Vigil's
original layered swept-back hair, surface-grown beard and fitted domino mask,
finishes the supplied eye globes, creates four modest expression targets, and
assigns the v2 rig groups.

Coordinate contract: Blender metres, +Z up, character looks toward -Y.  Inputs
must have identity object transforms.  ``face_obj`` is the root generator's
head/neck partition at the fitted collar (currently z >= 1.825); eye objects
must be the two globes returned by ``body_from_base.load_anatomy``.

No voxel remesh, decimation, smoothing, or anatomical profile construction is
performed here.  The mask is sampled as a multi-ring surface and every vertex
is projected to the real face with a BVH ray cast (nearest-surface fallback is
diagnostic-only).  A fitted, ridged hair shell plus five silhouette locks gives
ordinary gameplay views a swept direction without tubular crown pieces.
Facial hair is a continuous, feathered color field on the
anatomical scan itself: there is no copied-face beard plate to separate at the
neck or jaw.
"""

from __future__ import annotations

from collections import defaultdict
import math
from typing import Iterable

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

try:
    from actors.gloam_vigil.v2.rig_contract import BONE_NAMES, MATERIAL_NAMES, MORPH_NAMES
except ModuleNotFoundError:  # Background Blender usually receives v2 on sys.path.
    from rig_contract import BONE_NAMES, MATERIAL_NAMES, MORPH_NAMES


_EPSILON = 1.0e-6
_FRONT = Vector((0.0, -1.0, 0.0))
_DARK_GEAR = (0.004, 0.006, 0.010, 1.0)
_IVORY = (0.34, 0.32, 0.28, 1.0)
_IRIS_RING = (0.004, 0.009, 0.010, 1.0)
_IRIS = (0.014, 0.029, 0.025, 1.0)
_PUPIL = (0.002, 0.003, 0.004, 1.0)
_LIP = (0.34, 0.19, 0.16, 1.0)
_SKIN_NEUTRAL = (1.0, 1.0, 1.0, 1.0)
_HAIR_BLACK = (0.003, 0.004, 0.006, 1.0)


def _assert_identity(obj: bpy.types.Object) -> None:
    identity = Matrix.Identity(4)
    assert all(abs(obj.matrix_world[row][col] - identity[row][col]) < 1.0e-5 for row in range(4) for col in range(4)), obj.name


def _bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    points = [vertex.co for vertex in obj.data.vertices]
    assert points, obj.name
    return (
        Vector(tuple(min(point[axis] for point in points) for axis in range(3))),
        Vector(tuple(max(point[axis] for point in points) for axis in range(3))),
    )


def _center_and_radii(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    minimum, maximum = _bounds(obj)
    return (minimum + maximum) * 0.5, (maximum - minimum) * 0.5


def _side_from_name(name: str) -> str:
    if name.endswith(".L") or name.endswith("_L") or ".L." in name:
        return "L"
    if name.endswith(".R") or name.endswith("_R") or ".R." in name:
        return "R"
    raise ValueError(f"Eye object lacks an unambiguous .L/.R suffix: {name}")


def _ensure_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.material_index = 0
        polygon.use_smooth = True


def _tune_face_skin_finish(material: bpy.types.Material) -> None:
    """Keep warm skin and dark vertex-color regions matte in one material."""
    assert material.use_nodes and material.node_tree
    principled = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    roughness = principled.inputs["Roughness"]
    for link in list(roughness.links):
        material.node_tree.links.remove(link)
    roughness.default_value = 0.72
    specular = principled.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.34


def _make_mesh(name: str, vertices: list[tuple[float, float, float]], faces: list[tuple[int, ...]]) -> bpy.types.Object:
    assert vertices and faces
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj


def _smart_uv(obj: bpy.types.Object, margin: float = 0.008) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def _tag_vertices(obj: bpy.types.Object, tag: str, indices: Iterable[int] | None = None) -> None:
    indices = list(range(len(obj.data.vertices))) if indices is None else list(indices)
    assert indices, tag
    group = obj.vertex_groups.get(f"TAG__{tag}") or obj.vertex_groups.new(name=f"TAG__{tag}")
    group.add(indices, 1.0, "REPLACE")


def _extract_tags(obj: bpy.types.Object) -> dict[str, set[int]]:
    indexed = {group.index: group for group in obj.vertex_groups if group.name.startswith("TAG__")}
    tags: dict[str, set[int]] = defaultdict(set)
    for vertex in obj.data.vertices:
        for membership in vertex.groups:
            group = indexed.get(membership.group)
            if group and membership.weight > 0.5:
                tags[group.name.removeprefix("TAG__")].add(vertex.index)
    for group in list(indexed.values()):
        obj.vertex_groups.remove(group)
    return dict(tags)


def _face_bvh(face_obj: bpy.types.Object) -> tuple[BVHTree, Vector]:
    vertices = [vertex.co.copy() for vertex in face_obj.data.vertices]
    polygons = [tuple(polygon.vertices) for polygon in face_obj.data.polygons]
    minimum, maximum = _bounds(face_obj)
    return BVHTree.FromPolygons(vertices, polygons, all_triangles=False), (minimum + maximum) * 0.5


def _project_front(
    bvh: BVHTree,
    head_center: Vector,
    x: float,
    z: float,
    front_y: float,
    offset: float,
) -> tuple[Vector, bool]:
    # Cast inward from well in front of the face.  This returns the foremost
    # skin layer at the requested x/z, so the mask never bridges through the
    # nose or floats across curved cheeks.
    hit, normal, _face_index, _distance = bvh.ray_cast(Vector((x, front_y, z)), Vector((0.0, 1.0, 0.0)), 0.55)
    fallback = hit is None
    if fallback:
        hit, normal, _face_index, _distance = bvh.find_nearest(Vector((x, front_y + 0.10, z)), 0.12)
    if hit is None or normal is None:
        raise RuntimeError(f"Could not conform mask vertex at x={x:.4f}, z={z:.4f}")
    normal = normal.normalized()
    if (hit - head_center).dot(normal) < 0.0:
        normal.negate()
    return hit + normal * offset, fallback


def _append_flat_clump(
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    points: list[Vector],
    normals: list[Vector],
    widths: list[float],
    depths: list[float],
    sides: int = 6,
) -> range:
    """Append one rounded, flattened lock with a tapered closed end.

    The small separated clumps are intentionally cheaper and more legible at
    gameplay distance than strand grooming.  They also avoid the uniform
    highlight and silhouette of a single helmet-like hair shell.
    """
    assert len(points) >= 3 and len(points) == len(normals) == len(widths) == len(depths)
    assert sides >= 4
    start = len(vertices)
    for index, (point, supplied_normal, width, depth) in enumerate(zip(points, normals, widths, depths, strict=True)):
        previous = points[max(0, index - 1)]
        following = points[min(len(points) - 1, index + 1)]
        tangent = (following - previous).normalized()
        outward = supplied_normal - tangent * supplied_normal.dot(tangent)
        if outward.length < _EPSILON:
            outward = Vector((0.0, -1.0, 0.0)) - tangent * tangent.y * -1.0
        outward.normalize()
        lateral = tangent.cross(outward).normalized()
        for segment in range(sides):
            angle = math.tau * segment / sides
            vertex = point + lateral * (math.cos(angle) * width) + outward * (math.sin(angle) * depth)
            vertices.append(tuple(vertex))
    for row in range(len(points) - 1):
        first = start + row * sides
        second = first + sides
        for segment in range(sides):
            nxt = (segment + 1) % sides
            faces.append((first + segment, first + nxt, second + nxt, second + segment))
    faces.append(tuple(reversed(range(start, start + sides))))
    end = start + (len(points) - 1) * sides
    faces.append(tuple(range(end, end + sides)))
    return range(start, len(vertices))


def _append_hair_ribbon(
    vertices: list[tuple[float, float, float]],
    faces: list[tuple[int, ...]],
    points: list[Vector],
    normals: list[Vector],
    widths: list[float],
    reliefs: list[float],
) -> range:
    """Append one closed, shallow two-wide ribbon over the fitted scalp.

    Unlike a tubular lock, the only broad visible plane is the top quad strip.
    The 1-2 mm side wall merely closes the mesh where it intersects the cap.
    """
    assert len(points) >= 3 and len(points) == len(normals) == len(widths) == len(reliefs)
    start = len(vertices)
    for index, (point, supplied_normal, width, relief) in enumerate(zip(points, normals, widths, reliefs, strict=True)):
        previous = points[max(0, index - 1)]
        following = points[min(len(points) - 1, index + 1)]
        tangent = (following - previous).normalized()
        outward = supplied_normal - tangent * supplied_normal.dot(tangent)
        if outward.length < _EPSILON:
            outward = Vector((0.0, -1.0, 0.0)) - tangent * tangent.y * -1.0
        outward.normalize()
        lateral = tangent.cross(outward).normalized()
        left = point - lateral * width
        right = point + lateral * width
        vertices.extend((tuple(left), tuple(right), tuple(left + outward * relief), tuple(right + outward * relief)))
    for row in range(len(points) - 1):
        a = start + row * 4
        b = a + 4
        faces.extend(
            (
                (a + 2, a + 3, b + 3, b + 2),
                (a, b, b + 2, a + 2),
                (a + 1, a + 3, b + 3, b + 1),
                (a, a + 1, b + 1, b),
            )
        )
    end = start + (len(points) - 1) * 4
    faces.append((start, start + 2, start + 3, start + 1))
    faces.append((end, end + 1, end + 3, end + 2))
    return range(start, len(vertices))


def _nearest_surface(
    bvh: BVHTree,
    head_center: Vector,
    anchor: Vector,
    offset: float,
) -> tuple[Vector, Vector]:
    hit, normal, _face_index, _distance = bvh.find_nearest(anchor, 0.22)
    if hit is None or normal is None:
        raise RuntimeError(f"Could not fit hair clump near {tuple(anchor)}")
    normal = normal.normalized()
    if (hit - head_center).dot(normal) < 0.0:
        normal.negate()
    return hit + normal * offset, normal


def _radial_surface(
    bvh: BVHTree,
    center: Vector,
    direction: Vector,
    offset: float,
) -> tuple[Vector, Vector]:
    direction = direction.normalized()
    hit, normal, _face_index, _distance = bvh.ray_cast(center, direction, 0.45)
    if hit is None or normal is None:
        return _nearest_surface(bvh, center, center + direction * 0.13, offset)
    normal = normal.normalized()
    if normal.dot(direction) < 0.0:
        normal.negate()
    return hit + normal * offset, normal


def _layered_hair_geometry(face_obj: bpy.types.Object, eye_z: float) -> tuple[bpy.types.Object, dict[str, int]]:
    bvh, bounds_center = _face_bvh(face_obj)
    cranium_center = Vector((0.0, -0.058, eye_z + 0.030))
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    clumps = 0

    # One fitted shell sits only a few millimetres off the source scalp. Broad
    # low-amplitude waves travel diagonally toward the nape, so the shell itself
    # carries swept direction without any separate crown chips or tube rows.
    segments = 48
    rings = 14
    top, _top_normal = _radial_surface(bvh, cranium_center, Vector((0.0, 0.0, 1.0)), 0.0120)
    vertices.append(tuple(top))
    for ring in range(1, rings + 1):
        t = ring / rings
        for segment in range(segments):
            azimuth = math.tau * segment / segments
            cosine = math.cos(azimuth)
            boundary = (
                1.95
                - 0.65 * cosine
                - 0.35 * cosine * cosine
                + 0.070 * math.sin(3.0 * azimuth + 0.25)
                + 0.030 * math.sin(7.0 * azimuth - 0.40)
            )
            polar = boundary * t
            direction = Vector((math.sin(polar) * math.sin(azimuth), -math.sin(polar) * math.cos(azimuth), math.cos(polar)))
            ridge_fade = math.sin(math.pi * t) ** 0.70
            swept_ridge = ridge_fade * (
                0.0038 * math.sin(4.0 * azimuth - 2.35 * t + 0.25)
                + 0.0017 * math.sin(2.0 * azimuth - 3.10 * t - 0.55)
            )
            volume = 0.0045 + 0.0075 * (1.0 - t) ** 1.20
            point, _normal = _radial_surface(bvh, cranium_center, direction, volume + swept_ridge)
            vertices.append(tuple(point))
    for segment in range(segments):
        faces.append((0, 1 + segment, 1 + (segment + 1) % segments))
    for ring in range(1, rings):
        first = 1 + (ring - 1) * segments
        second = first + segments
        for segment in range(segments):
            nxt = (segment + 1) % segments
            faces.append((first + segment, first + nxt, second + nxt, second + segment))
    cap_vertex_count = len(vertices)

    def append(anchors: list[tuple[float, float, float]], widths: list[float], reliefs: list[float]) -> None:
        nonlocal clumps
        points: list[Vector] = []
        normals: list[Vector] = []
        for x, y, z_offset in anchors:
            point, normal = _nearest_surface(bvh, bounds_center, Vector((x, y, eye_z + z_offset)), 0.0028)
            points.append(point)
            normals.append(normal)
        _append_hair_ribbon(vertices, faces, points, normals, widths, reliefs)
        clumps += 1

    # Five medium-length temple and nape pieces frame the ears and finish above
    # the collar. None can reach the lower neck, so the collar remains clean.
    for side in (-1.0, 1.0):
        append(
            [
                (0.104 * side, -0.060, 0.062),
                (0.118 * side, -0.006, 0.026),
                (0.116 * side, 0.040, -0.026),
                (0.104 * side, 0.056, -0.090),
            ],
            [0.0015, 0.015, 0.016, 0.0015],
            [0.00012, 0.0010, 0.0014, 0.00012],
        )
    for x, lean in ((-0.058, -0.010), (0.0, 0.008), (0.058, 0.014)):
        append(
            [(x, 0.052, 0.018), (x + lean * 0.45, 0.070, -0.044), (x + lean, 0.058, -0.105)],
            [0.0015, 0.014, 0.0015],
            [0.00012, 0.0012, 0.00012],
        )

    hair = _make_mesh("GV4_LayeredHair", vertices, faces)
    _tag_vertices(hair, "hair")
    return hair, {
        "clumps": clumps,
        "cap_vertices": cap_vertex_count,
        "vertices": len(vertices),
        "triangles": sum(len(face) - 2 for face in faces),
    }


def _smooth_unit(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def _facial_hair_strength(point: Vector, eye_z: float) -> tuple[float, float]:
    """Return feathered beard and mustache coverage on the scan surface.

    The mandible coordinate separates the forward-projecting chin from the
    recessed throat even where both share the same height. This is the key to
    keeping dark facial hair completely above the neck/collar junction.
    """
    x, y, z = point
    ax = abs(x)
    outer = _smooth_unit((0.123 - ax) / 0.024)
    face_forward = _smooth_unit((-y - 0.018) / 0.105)
    mandible_coordinate = z + max(0.0, -y) + 0.30 * ax
    mandible = _smooth_unit((mandible_coordinate - (eye_z - 0.055)) / 0.075)
    collar_clear = _smooth_unit((z - (eye_z - 0.166)) / 0.034)

    # The cheek boundary rises smoothly toward the sideburns. A soft elliptical
    # mouth opening keeps the lips legible while retaining a connected chin.
    upper_line = eye_z - (0.116 - 0.062 * min(1.0, ax / 0.105))
    below_cheek = _smooth_unit((upper_line - z) / 0.030)
    mouth_ellipse = (x / 0.045) ** 2 + ((z - (eye_z - 0.091)) / 0.018) ** 2
    mouth_clear = _smooth_unit((mouth_ellipse - 0.74) / 0.32)
    beard = outer * face_forward * mandible * collar_clear * below_cheek * mouth_clear

    # One continuous shallow chevron follows the upper lip. Its center stays
    # present (rather than splitting into two bars), the tips dip into the
    # beard, and lip-tagged source vertices win later in the color pass.
    mustache_center_z = eye_z - 0.078 - 0.0045 * min(1.0, ax / 0.060)
    mustache_ellipse = (x / 0.063) ** 2 + ((z - mustache_center_z) / 0.0090) ** 2
    mustache_shape = _smooth_unit((1.0 - mustache_ellipse) / 0.46)
    mustache = outer * face_forward * mustache_shape
    return beard, mustache


def _facial_hair_tags(face_obj: bpy.types.Object, eye_z: float, lip_vertices: set[int]) -> tuple[set[int], set[int]]:
    beard: set[int] = set()
    mustache: set[int] = set()
    for vertex in face_obj.data.vertices:
        if vertex.index in lip_vertices:
            continue
        beard_strength, mustache_strength = _facial_hair_strength(vertex.co, eye_z)
        if beard_strength > 0.055:
            beard.add(vertex.index)
        if mustache_strength > 0.055:
            mustache.add(vertex.index)
    assert len(beard) > 250 and len(mustache) > 25, (len(beard), len(mustache))
    return beard, mustache


def _mask_geometry(face_obj: bpy.types.Object, eye_centers: dict[str, Vector]) -> tuple[bpy.types.Object, dict[str, int]]:
    bvh, head_center = _face_bvh(face_obj)
    minimum, _maximum = _bounds(face_obj)
    front_y = minimum.y - 0.12
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    fallback_count = 0
    radial_rings = 6
    segments = 48

    for side in ("L", "R"):
        center = eye_centers[side]
        start = len(vertices)
        for ring in range(radial_rings):
            t = ring / (radial_rings - 1)
            for segment in range(segments):
                angle = math.tau * segment / segments
                ca, sa = math.cos(angle), math.sin(angle)
                # The opening is a restrained anatomical almond.  The outer
                # boundary climbs over the brow and sweeps toward the temple;
                # it does not become a circular goggle or a horizontal strip.
                inner_rx = 0.0285
                inner_rz = 0.0104 * (0.91 + 0.09 * abs(ca))
                lateral = max(0.0, ca if center.x > 0.0 else -ca)
                medial = max(0.0, -ca if center.x > 0.0 else ca)
                upper = max(0.0, sa)
                lower = max(0.0, -sa)
                outer_rx = 0.0415 + 0.0085 * lateral - 0.0030 * medial
                outer_rz = 0.0230 + 0.0100 * upper - 0.0080 * lower
                # Slightly angular brow and cheek planes keep the identity
                # heroic without copying any franchise mask silhouette.
                angular = 1.0 + 0.050 * math.cos(4.0 * angle)
                rx = (inner_rx * (1.0 - t) + outer_rx * t) * angular
                rz = inner_rz * (1.0 - t) + outer_rz * t
                x = center.x + rx * ca
                z = center.z + rz * sa + 0.0025 * t * lateral - 0.0015 * t * lower
                point, used_fallback = _project_front(bvh, head_center, x, z, front_y, 0.0012)
                fallback_count += int(used_fallback)
                vertices.append(tuple(point))
        for ring in range(radial_rings - 1):
            a0 = start + ring * segments
            b0 = a0 + segments
            for segment in range(segments):
                nxt = (segment + 1) % segments
                faces.append((a0 + segment, a0 + nxt, b0 + nxt, b0 + segment))

    # A broad, conforming bridge makes this one domino mask rather than two
    # eyeglass rims.  Its lower edge stays above the nasal wings.
    left, right = sorted(eye_centers.values(), key=lambda point: point.x)
    bridge_start = len(vertices)
    bridge_columns = 9
    bridge_rows = 6
    bridge_z0 = (left.z + right.z) * 0.5 + 0.001
    for row in range(bridge_rows):
        v = row / (bridge_rows - 1)
        z = bridge_z0 + 0.027 * v
        half_width = 0.013 + 0.014 * v
        for column in range(bridge_columns):
            u = column / (bridge_columns - 1)
            x = -half_width + 2.0 * half_width * u
            # A shallow central rise follows the brow rather than forming a
            # straight spectacle bar.
            z_shaped = z + 0.002 * (1.0 - abs(2.0 * u - 1.0))
            point, used_fallback = _project_front(bvh, head_center, x, z_shaped, front_y, 0.0014)
            fallback_count += int(used_fallback)
            vertices.append(tuple(point))
    for row in range(bridge_rows - 1):
        for column in range(bridge_columns - 1):
            a = bridge_start + row * bridge_columns + column
            faces.append((a, a + 1, a + 1 + bridge_columns, a + bridge_columns))

    mask = _make_mesh("GV4_FittedDominoMask", vertices, faces)
    _tag_vertices(mask, "mask")
    _tag_vertices(mask, "mask_brow", range(bridge_start, len(vertices)))
    return mask, {"ray_vertices": len(vertices), "nearest_fallbacks": fallback_count}


def _scalp_and_lip_tags(face_obj: bpy.types.Object, eye_z: float) -> tuple[set[int], set[int]]:
    """Return color regions on the untouched anatomical surface.

    Dark color directly on the scan scalp reads as clipped hair without a
    second glossy shell.  The continuous threshold adds a modest center peak
    and temporal recession while leaving both ears clear.
    """
    minimum, maximum = _bounds(face_obj)
    head_center = (minimum + maximum) * 0.5
    scalp: set[int] = set()
    lips: set[int] = set()
    for vertex in face_obj.data.vertices:
        point = vertex.co
        radial = Vector((point.x - head_center.x, point.y - head_center.y, 0.0))
        frontness = max(0.0, -radial.y / max(radial.length, _EPSILON))
        temple_recession = 0.012 * math.exp(-((abs(point.x) - 0.058) / 0.025) ** 2)
        center_peak = 0.008 * math.exp(-(point.x / 0.026) ** 2)
        front_hairline = eye_z + 0.060 + temple_recession - center_peak
        side_hairline = eye_z + 0.030
        threshold = side_hairline * (1.0 - frontness) + front_hairline * frontness
        if point.z > threshold - 0.008:
            scalp.add(vertex.index)
        lip_z = eye_z - 0.094
        lip_ellipse = (point.x / 0.044) ** 2 + ((point.z - lip_z) / 0.012) ** 2
        if lip_ellipse < 1.0 and point.y < -0.184:
            lips.add(vertex.index)
    assert len(scalp) > 500 and len(lips) > 20, (len(scalp), len(lips))
    return scalp, lips


def _disc_on_globe(
    name: str,
    center: Vector,
    radii: Vector,
    radius: float,
    depth_offset: float,
    tag: str,
    vertical_offset: float = 0.0,
) -> bpy.types.Object:
    segments = 32
    rings = 3
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []

    def globe_point(dx: float, dz: float) -> tuple[float, float, float]:
        world_z = center.z + vertical_offset + dz
        nx = dx / max(radii.x, _EPSILON)
        nz = (world_z - center.z) / max(radii.z, _EPSILON)
        y = center.y - radii.y * math.sqrt(max(0.0, 1.0 - nx * nx - nz * nz)) - depth_offset
        return center.x + dx, y, world_z

    vertices.append(globe_point(0.0, 0.0))
    for ring in range(1, rings + 1):
        rr = radius * ring / rings
        for segment in range(segments):
            angle = math.tau * segment / segments
            vertices.append(globe_point(rr * math.sin(angle), rr * math.cos(angle)))
    for segment in range(segments):
        nxt = (segment + 1) % segments
        faces.append((0, 1 + segment, 1 + nxt))
    for ring in range(1, rings):
        inner = 1 + (ring - 1) * segments
        outer = inner + segments
        for segment in range(segments):
            nxt = (segment + 1) % segments
            faces.append((inner + segment, outer + segment, outer + nxt, inner + nxt))
    obj = _make_mesh(name, vertices, faces)
    _tag_vertices(obj, tag)
    return obj


def _set_vertex_colors(obj: bpy.types.Object, tags: dict[str, set[int]], eye_centers: dict[str, Vector]) -> None:
    attribute = obj.data.color_attributes.get("Col")
    if attribute is None:
        attribute = obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    gear_index = next(index for index, material in enumerate(obj.data.materials) if material and material.name == "MAT_GV2_Gear")
    eye_z = sum(center.z for center in eye_centers.values()) * 0.5
    source_face = tags["source_face"]

    def blend(a: tuple[float, float, float, float], b: tuple[float, float, float, float], factor: float) -> tuple[float, float, float, float]:
        factor = max(0.0, min(1.0, factor))
        return tuple(a[channel] * (1.0 - factor) + b[channel] * factor for channel in range(4))

    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = obj.data.loops[loop_index].vertex_index
            point = obj.data.vertices[vertex_index].co
            if vertex_index in tags.get("sclera", set()):
                color = _IVORY
            elif vertex_index in tags.get("iris_ring", set()):
                color = _IRIS_RING
            elif vertex_index in tags.get("iris", set()):
                color = _IRIS
            elif vertex_index in tags.get("pupil", set()):
                color = _PUPIL
            elif vertex_index in tags.get("hair", set()):
                color = _HAIR_BLACK
            elif vertex_index in tags.get("lips", set()):
                lip_z = eye_z - 0.094
                ellipse = (point.x / 0.044) ** 2 + ((point.z - lip_z) / 0.012) ** 2
                strength = max(0.0, 1.0 - ellipse)
                strength *= max(0.0, min(1.0, (-point.y - 0.180) / 0.025))
                color = blend(_SKIN_NEUTRAL, _LIP, 0.72 * strength)
            elif vertex_index in tags.get("hair_scalp", set()):
                # The fitted shell now closes the scalp by itself. Keeping the
                # old dark underfill exposed below its edge created a headband
                # seam, so this retained spatial tag uses the surrounding skin.
                color = _SKIN_NEUTRAL
            elif vertex_index in source_face:
                beard_strength, mustache_strength = _facial_hair_strength(point, eye_z)
                # Both regions grow from the anatomical surface and feather at
                # every boundary. Tagged lips have already won above.
                beard_coverage = 0.96 * _smooth_unit(1.45 * beard_strength)
                mustache_coverage = 0.998 * _smooth_unit(1.45 * mustache_strength)
                facial_hair = max(beard_coverage, mustache_coverage)
                color = blend(_SKIN_NEUTRAL, _HAIR_BLACK, facial_hair)
            elif polygon.material_index == gear_index:
                color = _DARK_GEAR
            else:
                color = _SKIN_NEUTRAL
            attribute.data[loop_index].color = color
    obj.data.color_attributes.active_color = attribute


def _canonicalize_materials(obj: bpy.types.Object, materials: dict[str, bpy.types.Material], tags: dict[str, set[int]]) -> None:
    # Hair uses the existing rough skin shader with a near-black vertex color;
    # the shinier gear shader washed the crown to mid-grey under studio light.
    gear_vertices = set().union(*(tags.get(tag, set()) for tag in ("sclera", "iris_ring", "iris", "pupil", "mask")))
    polygon_gear = []
    for polygon in obj.data.polygons:
        polygon_gear.append(sum(index in gear_vertices for index in polygon.vertices) > len(polygon.vertices) * 0.5)
    obj.data.materials.clear()
    obj.data.materials.append(materials["MAT_GV2_Skin"])
    obj.data.materials.append(materials["MAT_GV2_Gear"])
    for polygon, is_gear in zip(obj.data.polygons, polygon_gear, strict=True):
        polygon.material_index = int(is_gear)
        polygon.use_smooth = True


def _assign_weights(obj: bpy.types.Object, tags: dict[str, set[int]], eye_centers: dict[str, Vector]) -> int:
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    groups: dict[str, bpy.types.VertexGroup] = {}

    def put(index: int, weights: dict[str, float]) -> None:
        positive = {name: value for name, value in weights.items() if value > 1.0e-7}
        assert positive and len(positive) <= 4
        assert set(positive).issubset(BONE_NAMES), set(positive) - set(BONE_NAMES)
        total = sum(positive.values())
        for name, value in positive.items():
            group = groups.get(name) or obj.vertex_groups.new(name=name)
            groups[name] = group
            group.add([index], value / total, "REPLACE")

    eye_indices = {
        side: set().union(tags.get(f"eye.{side}", set()), tags.get(f"iris_ring.{side}", set()), tags.get(f"iris.{side}", set()), tags.get(f"pupil.{side}", set()))
        for side in ("L", "R")
    }
    gear_head = set().union(tags.get("mask", set()), tags.get("hair", set()))
    eye_z = sum(center.z for center in eye_centers.values()) * 0.5
    source_face = tags["source_face"]

    def smooth_unit(value: float) -> float:
        value = max(0.0, min(1.0, value))
        return value * value * (3.0 - 2.0 * value)

    def jaw_at(x: float, y: float, z: float) -> float:
        jaw_upper = max(0.0, min(1.0, (eye_z - 0.025 - z) / 0.070))
        jaw_lower = max(0.0, min(1.0, (z - (eye_z - 0.155)) / 0.026))
        jaw_side = max(0.0, min(1.0, (0.105 - abs(x)) / 0.070))
        jaw_front = max(0.0, min(1.0, (-y - 0.035) / 0.075))
        return 0.88 * jaw_upper * jaw_lower * jaw_side * jaw_front

    # Height alone put the projecting chin and the recessed throat at the same
    # neck share, so counter-rotation stretched the lower face into a cone even
    # though adjacent edges stayed finite.  Start from a broad anatomical
    # forward/lateral support field, then relax it over the real scan topology.
    adjacency: list[list[tuple[int, float]]] = [[] for _vertex in obj.data.vertices]
    for edge in obj.data.edges:
        first, second = edge.vertices
        if first not in source_face or second not in source_face:
            continue
        distance = (obj.data.vertices[first].co - obj.data.vertices[second].co).length
        adjacency[first].append((second, distance))
        adjacency[second].append((first, distance))

    rigid_head_seeds: set[int] = set()
    neck_seeds: set[int] = set()
    neck_field = [0.0] * len(obj.data.vertices)
    for index in source_face:
        x, y, z = obj.data.vertices[index].co
        base_neck = smooth_unit((eye_z - 0.073 - z) / 0.120)
        mandible_coordinate = z + max(0.0, -y) + 0.30 * abs(x)
        mandible_support = smooth_unit((mandible_coordinate - (eye_z - 0.068)) / 0.060)
        collar_gate = smooth_unit((z - (eye_z - 0.193)) / 0.035)
        neck_field[index] = base_neck * (1.0 - collar_gate * mandible_support)
        if (
            z >= eye_z - 0.088
            or (z >= eye_z - 0.158 and y <= -0.140)
            or (z >= eye_z - 0.138 and abs(x) >= 0.060)
        ):
            rigid_head_seeds.add(index)
            neck_field[index] = 0.0
        if z <= eye_z - 0.192:
            neck_seeds.add(index)
            neck_field[index] = 1.0
    assert rigid_head_seeds and neck_seeds and rigid_head_seeds.isdisjoint(neck_seeds)

    # The pinned regions are well inside the mandible and collar.  Relaxing the
    # transition, rather than switching a retained bone set, removes gradients
    # at irregular triangulation around the underside of the jaw.
    for _iteration in range(400):
        relaxed = neck_field.copy()
        for index in source_face - rigid_head_seeds - neck_seeds:
            if not adjacency[index]:
                continue
            inverse_lengths = [(neighbor, 1.0 / max(length, _EPSILON)) for neighbor, length in adjacency[index]]
            average = sum(neck_field[neighbor] * weight for neighbor, weight in inverse_lengths) / sum(weight for _neighbor, weight in inverse_lengths)
            relaxed[index] = 0.35 * neck_field[index] + 0.65 * average
        neck_field = relaxed

    for vertex in obj.data.vertices:
        index = vertex.index
        if index in eye_indices["L"]:
            put(index, {"eye.L": 1.0})
            continue
        if index in eye_indices["R"]:
            put(index, {"eye.R": 1.0})
            continue
        if index in gear_head:
            put(index, {"head": 1.0})
            continue
        x, y, z = vertex.co
        neck_factor = neck_field[index]
        jaw = jaw_at(x, y, z)
        # Jaw is an overlay on the same continuous head/neck field, not a
        # mutually exclusive classifier.  The former jaw/neck branch changed
        # the retained bone set across adjacent scan vertices when ``jaw``
        # crossed 0.05, producing a visible lower-neck tear in deep poses.
        # Diverting the jaw share from the smoothly blended *head* share keeps
        # all three weights normalized and continuous while retaining jaw
        # motion on the mandible without pulling the throat off the neck.
        head_share = 1.0 - neck_factor
        put(index, {
            "head": head_share * (1.0 - jaw),
            "neck": neck_factor,
            "jaw": head_share * jaw,
        })

    max_influences = max(len(vertex.groups) for vertex in obj.data.vertices)
    assert max_influences <= 4
    return max_influences


def _make_shape_keys(obj: bpy.types.Object, tags: dict[str, set[int]], eye_centers: dict[str, Vector], eye_radii: dict[str, Vector]) -> dict[str, int]:
    source = tags["source_face"]
    basis = obj.shape_key_add(name="Basis")
    basis.interpolation = "KEY_LINEAR"
    counts: dict[str, int] = {}

    for side in ("L", "R"):
        center = eye_centers[side]
        radii = eye_radii[side]
        influenced: list[tuple[int, float, float]] = []
        for index in source:
            point = obj.data.vertices[index].co
            dx = abs(point.x - center.x)
            dz = point.z - center.z
            # A continuous compact-support field follows the actual scan lid
            # surface.  Moving only a thresholded set produced broken spikes;
            # this field reaches zero smoothly in the surrounding fold.
            horizontal = max(0.0, 1.0 - (dx / (radii.x * 2.15)) ** 2)
            vertical = max(0.0, 1.0 - (abs(dz) / (radii.z * 1.70)) ** 4)
            front = max(0.0, min(1.0, (center.y - point.y + radii.y * 0.25) / (radii.y * 0.80)))
            globe_distance = math.sqrt(
                ((point.x - center.x) / radii.x) ** 2
                + ((point.y - center.y) / radii.y) ** 2
                + ((point.z - center.z) / radii.z) ** 2
            )
            lid_surface = max(0.0, 1.0 - ((globe_distance - 1.15) / 0.62) ** 2)
            strength = horizontal * horizontal * vertical * front * lid_surface * lid_surface
            if strength > 0.001:
                influenced.append((index, strength, 1.0 if dz >= 0.0 else -1.0))
        upper_count = sum(side_sign > 0.0 for _index, _strength, side_sign in influenced)
        lower_count = len(influenced) - upper_count
        assert upper_count >= 20 and lower_count >= 20, (side, upper_count, lower_count)
        key = obj.shape_key_add(name=f"blink.{side}")
        key.value = 0.0
        for index, strength, side_sign in influenced:
            base = obj.data.vertices[index].co
            # Overlap the opposing lid margins slightly at the center plane;
            # the source eyeball otherwise remains visible through a sub-mm
            # slit because this is a closed body topology, not a separate lid.
            target_z = center.z - 0.0045 * side_sign
            # The actual lid margin occupies only part of the compact field;
            # saturate its central portion while retaining a smooth zero at
            # the orbital fold.  Value 1 must read as a blink, not a squint.
            amount = min(0.995, 2.4 * strength)
            key.data[index].co.z = base.z + (target_z - base.z) * amount
            target_y = min(base.y, center.y - radii.y * 0.90) - 0.0003
            key.data[index].co.y = base.y + (target_y - base.y) * amount
        counts[f"blink.{side}"] = len(influenced)

    brow = obj.shape_key_add(name="brow_inner_raise")
    brow.value = 0.0
    brow_indices: set[int] = set()
    mean_eye_z = sum(center.z for center in eye_centers.values()) * 0.5
    for index in source:
        point = obj.data.vertices[index].co
        vertical = max(0.0, 1.0 - ((point.z - (mean_eye_z + 0.031)) / 0.030) ** 2)
        horizontal = max(0.0, 1.0 - (abs(point.x) / 0.072) ** 2)
        front = max(0.0, min(1.0, (-point.y - 0.060) / 0.075))
        strength = vertical * vertical * horizontal * horizontal * front
        if strength > 0.002:
            brow.data[index].co.z += 0.0075 * strength
            brow.data[index].co.y -= 0.0012 * strength
            brow_indices.add(index)
    assert len(brow_indices) >= 12, len(brow_indices)
    counts["brow_inner_raise"] = len(brow_indices)

    jaw = obj.shape_key_add(name="jaw_clench")
    jaw.value = 0.0
    jaw_indices: set[int] = set()
    for index in source:
        point = obj.data.vertices[index].co
        vertical = max(0.0, 1.0 - ((point.z - (mean_eye_z - 0.096)) / 0.072) ** 2)
        lateral = max(0.0, 1.0 - ((abs(point.x) - 0.066) / 0.048) ** 2)
        depth = max(0.0, min(1.0, (-point.y + 0.015) / 0.095))
        strength = vertical * vertical * lateral * lateral * depth
        if strength > 0.002:
            side_sign = 1.0 if point.x >= 0.0 else -1.0
            jaw.data[index].co.x += side_sign * 0.0030 * strength
            jaw.data[index].co.y -= 0.0008 * strength
            jaw_indices.add(index)
    assert len(jaw_indices) >= 12, len(jaw_indices)
    counts["jaw_clench"] = len(jaw_indices)
    assert tuple(key.name for key in obj.data.shape_keys.key_blocks[1:]) == MORPH_NAMES
    return counts


def _join_into_face(face_obj: bpy.types.Object, objects: list[bpy.types.Object]) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    face_obj.select_set(True)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = face_obj
    bpy.ops.object.join()
    face_obj.name = "GV2_Face"
    return face_obj


def _triangulate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new(name="V4 export triangulation", type="TRIANGULATE")
    modifier.quad_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def finish_face(
    face_obj: bpy.types.Object,
    eye_objects: Iterable[bpy.types.Object],
    materials: dict[str, bpy.types.Material],
) -> tuple[bpy.types.Object, dict[str, object]]:
    """Finish and return the single exportable ``GV2_Face`` mesh.

    ``metadata`` is JSON-safe and includes the measured eye anchors required
    to override the v2 eye-bone rest coordinates in the root generator.
    """
    eyes = list(eye_objects)
    assert face_obj.type == "MESH" and len(eyes) == 2
    assert all(eye.type == "MESH" for eye in eyes)
    assert set(MATERIAL_NAMES).issubset(materials)
    _assert_identity(face_obj)
    for eye in eyes:
        _assert_identity(eye)

    minimum, maximum = _bounds(face_obj)
    assert maximum.z > 2.14 and minimum.z <= 1.835, (tuple(minimum), tuple(maximum))
    assert maximum.z - minimum.z > 0.30
    # The Blender donor labels are anatomical-person sides, while the locked
    # v2 runtime contract is screen/spatial: `.L` has negative X and `.R` has
    # positive X.  Classify by the measured center, never the donor suffix.
    eye_by_side: dict[str, bpy.types.Object] = {}
    donor_eye_labels: dict[str, str] = {}
    for eye in eyes:
        donor_label = _side_from_name(eye.name)
        center, _radii = _center_and_radii(eye)
        side = "L" if center.x < 0.0 else "R"
        assert side not in eye_by_side, (side, eye.name)
        eye_by_side[side] = eye
        donor_eye_labels[side] = donor_label
    assert set(eye_by_side) == {"L", "R"}
    eye_centers: dict[str, Vector] = {}
    eye_radii: dict[str, Vector] = {}
    for side, eye in eye_by_side.items():
        center, radii = _center_and_radii(eye)
        assert minimum.x - 0.02 < center.x < maximum.x + 0.02, (side, tuple(center), tuple(minimum), tuple(maximum))
        assert 1.98 < center.z < 2.06, (side, tuple(center))
        assert 0.010 < min(radii) < 0.030 and 0.010 < max(radii) < 0.030, (side, tuple(radii))
        eye_centers[side] = center
        eye_radii[side] = radii

    _tune_face_skin_finish(materials["MAT_GV2_Skin"])
    _ensure_material(face_obj, materials["MAT_GV2_Skin"])
    _tag_vertices(face_obj, "source_face")
    mean_eye_z = sum(center.z for center in eye_centers.values()) * 0.5
    scalp_vertices, lip_vertices = _scalp_and_lip_tags(face_obj, mean_eye_z)
    _tag_vertices(face_obj, "hair_scalp", scalp_vertices)
    _tag_vertices(face_obj, "lips", lip_vertices)
    beard_surface, mustache_surface = _facial_hair_tags(face_obj, mean_eye_z, lip_vertices)
    _tag_vertices(face_obj, "beard_surface", beard_surface)
    _tag_vertices(face_obj, "mustache_surface", mustache_surface)
    additions: list[bpy.types.Object] = []
    hair, hair_metadata = _layered_hair_geometry(face_obj, mean_eye_z)
    _ensure_material(hair, materials["MAT_GV2_Skin"])
    _smart_uv(hair)
    additions.append(hair)
    for side in ("L", "R"):
        eye = eye_by_side[side]
        _ensure_material(eye, materials["MAT_GV2_Gear"])
        _tag_vertices(eye, "sclera")
        _tag_vertices(eye, f"eye.{side}")
        center, radii = eye_centers[side], eye_radii[side]
        iris_ring = _disc_on_globe(f"GV4_IrisRing.{side}", center, radii, min(radii.x, radii.z) * 0.48, 0.0004, "iris_ring", 0.0012)
        iris = _disc_on_globe(f"GV4_Iris.{side}", center, radii, min(radii.x, radii.z) * 0.40, 0.0008, "iris", 0.0012)
        pupil = _disc_on_globe(f"GV4_Pupil.{side}", center, radii, min(radii.x, radii.z) * 0.19, 0.0012, "pupil", 0.0012)
        for obj, semantic in ((iris_ring, f"iris_ring.{side}"), (iris, f"iris.{side}"), (pupil, f"pupil.{side}")):
            _ensure_material(obj, materials["MAT_GV2_Gear"])
            _tag_vertices(obj, semantic)
            _smart_uv(obj)
            additions.append(obj)

    mask, projection = _mask_geometry(face_obj, eye_centers)
    for obj in (mask,):
        _ensure_material(obj, materials["MAT_GV2_Gear"])
        _smart_uv(obj)
        additions.append(obj)

    # The original eye globes become part of the single face mesh expected by
    # the runtime.  Temporary groups preserve semantic membership through join.
    face_obj = _join_into_face(face_obj, eyes + additions)
    tags = _extract_tags(face_obj)
    for required in ("source_face", "hair_scalp", "hair", "beard_surface", "mustache_surface", "lips", "sclera", "iris_ring", "iris", "pupil", "mask", "eye.L", "eye.R", "iris_ring.L", "iris_ring.R", "iris.L", "iris.R", "pupil.L", "pupil.R"):
        assert tags.get(required), required
    _canonicalize_materials(face_obj, materials, tags)
    _triangulate(face_obj)
    # Triangulation does not reorder vertices, so all semantic sets remain
    # valid while loops/polygons are now in final export topology.
    max_influences = _assign_weights(face_obj, tags, eye_centers)
    _set_vertex_colors(face_obj, tags, eye_centers)
    morph_counts = _make_shape_keys(face_obj, tags, eye_centers, eye_radii)

    triangles = sum(len(polygon.vertices) - 2 for polygon in face_obj.data.polygons)
    # The official level-1 scan currently contributes about 33k head/neck
    # triangles by itself.  Preserve that accepted anatomy rather than hiding
    # a lossy reduction here; the root generator chooses the source level and
    # enforces the measured whole-character candidate allocation.  Level-0 inputs remain well
    # below the preferred ~22k face target.
    assert triangles < 40_000, triangles
    face_obj["gloam_asset_component"] = "v4_licensed_anatomy_face_finish"
    face_obj["gloam_source_license"] = "CC0"
    face_obj["gloam_source_author"] = "Dan Ulrich"
    final_minimum, final_maximum = _bounds(face_obj)
    face_obj["gloam_original_finish"] = "fitted domino mask, swept-ridged fitted hair shell and tapered silhouette locks, surface-grown connected beard and mustache, eye finish, rig weights, expressions"
    metadata: dict[str, object] = {
        "source": {
            "bundle": "Blender Human Base Meshes 1.4.1",
            "collection": "Body Male - Realistic",
            "author": "Dan Ulrich",
            "license": "CC0",
        },
        "construction": "unchanged licensed scan head/neck plus BVH-conformed original mask, swept-ridged fitted hair shell with tapered temple/nape locks, and surface-grown connected beard and mustache",
        "vertices": len(face_obj.data.vertices),
        "triangles": triangles,
        "preferred_face_triangle_target": 22_000,
        "preferred_face_triangle_target_met": triangles < 22_000,
        "materials": [material.name for material in face_obj.data.materials],
        "surfaces": len(face_obj.data.materials),
        "morphs": list(MORPH_NAMES),
        "morph_vertex_counts": morph_counts,
        "maximum_skin_influences": max_influences,
        "mask_projection": projection,
        "scalp_hair_vertices": len(tags["hair_scalp"]),
        "layered_hair": hair_metadata,
        "facial_hair": {
            "construction": "continuous feathered source-surface color field; no copied topology or floating relief plate",
            "clumps": 0,
            "vertices": 0,
            "triangles": 0,
            "beard_vertices": 0,
            "mustache_vertices": 0,
            "anatomical_relief_polygons": 0,
            "beard_surface_vertices": len(tags["beard_surface"]),
            "mustache_surface_vertices": len(tags["mustache_surface"]),
        },
        "beard_surface_vertices": len(tags["beard_surface"]),
        "mustache_surface_vertices": len(tags["mustache_surface"]),
        "lip_tint_vertices": len(tags["lips"]),
        "bounds_min": [round(value, 6) for value in final_minimum],
        "bounds_max": [round(value, 6) for value in final_maximum],
        "eye_anchors": {
            side: {
                "head": [round(value, 6) for value in eye_centers[side]],
                "tail": [round(eye_centers[side].x, 6), round(eye_centers[side].y - 0.040, 6), round(eye_centers[side].z, 6)],
                "globe_radii": [round(value, 6) for value in eye_radii[side]],
            }
            for side in ("L", "R")
        },
        "donor_eye_label_remap": donor_eye_labels,
    }
    return face_obj, metadata
