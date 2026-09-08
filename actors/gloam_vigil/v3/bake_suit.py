"""Optional Cycles normal bake for the original v3 fitted suit and cape.

This module is deliberately not invoked by :mod:`generate_v3`.  The generator
owner can opt in after the body and cape exist and before export::

    metadata = bake_suit(body, cape, materials, HERE / "textures")

Only suit-material UV loops on the low body/cape are changed.  Low positions,
topology, vertex groups, shape keys, object transforms, armature data, and the
five export material identities are preserved and asserted.  The retained
high sources are generated geometry: one Simple subdivision followed by
sub-millimetre analytic cloth-fold and woven micro-relief displacement.  This
is not represented as a manual sculpt or motion-capture/high-to-low asset.
"""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path
import hashlib
import json
import math
import struct

import bpy
from mathutils import Vector


SUIT_MATERIAL = "MAT_GV2_Suit_Cloth"
EXPORT_MATERIALS = {
    "MAT_GV2_Suit_Cloth",
    "MAT_GV2_Skin",
    "MAT_GV2_Gear",
    "MAT_GV2_Tactical_Boot",
    "MAT_GV2_Accent",
}
ATLAS_SIZE = 2048
UV_MARGIN_PIXELS = 20
BAKE_MARGIN_PIXELS = 8
CYCLES_SAMPLES = 16
CAGE_EXTRUSION_METERS = 0.002
MAX_RAY_DISTANCE_METERS = 0.004
MAX_DISPLACEMENT_METERS = 0.00095
NORMAL_STRENGTH = 0.65
UV_LAYER_NAME = "GV3_SuitBakeUV"
SOURCE_COLLECTION_NAME = "GV3_NormalBakeSources_NOEXPORT"
TEMP_COLLECTION_NAME = "GV3_NormalBakeTemporary"
ATLAS_FILENAME = "gv3_suit_cloth_normal_2048.png"


def bake_suit(
    body: bpy.types.Object,
    cape: bpy.types.Object,
    materials: Mapping[str, bpy.types.Material],
    output_dir: str | Path,
) -> dict[str, object]:
    """Jointly pack suit UVs and bake one shared tangent-space normal atlas.

    The active low target is baked twice into non-overlapping regions of one
    image (body first with clear, cape second without clear).  Each source is a
    retained, hidden high copy made from the exact matching suit-only low
    topology, which bounds projection to a 2 mm cage and 4 mm ray distance.

    Returns JSON-serialisable provenance and measurements.  On failure, low UV
    loops and suit-material node state are restored and generated temporary or
    high objects from this call are removed before the exception is re-raised.
    """

    _validate_inputs(body, cape, materials)
    output_path = Path(output_dir).expanduser().resolve() / ATLAS_FILENAME
    output_path.parent.mkdir(parents=True, exist_ok=True)

    originals = (body, cape)
    geometry_before = {obj.name: _low_mesh_fingerprint(obj) for obj in originals}
    uv_before = {obj.name: _snapshot_active_uv(obj) for obj in originals}
    selection_state = _capture_selection_state()
    material_state = _capture_suit_normal_state(materials[SUIT_MATERIAL])

    temp_collection = _fresh_collection(TEMP_COLLECTION_NAME, remove_existing=True)
    source_collection = _fresh_collection(SOURCE_COLLECTION_NAME, remove_existing=True)
    generated_high: list[bpy.types.Object] = []
    low_targets: list[bpy.types.Object] = []
    target_material: bpy.types.Material | None = None
    atlas_image: bpy.types.Image | None = None
    committed = False
    render_state: dict[str, object] | None = None

    try:
        pack_metadata = _joint_pack_suit_uvs(body, cape, temp_collection)

        target_material = _make_bake_target_material()
        atlas_image = bpy.data.images.new(
            "GV3_SuitCloth_NormalBake",
            width=ATLAS_SIZE,
            height=ATLAS_SIZE,
            alpha=False,
            float_buffer=False,
            is_data=True,
        )
        atlas_image.generated_color = (0.5, 0.5, 1.0, 1.0)
        atlas_image.colorspace_settings.name = "Non-Color"
        _set_bake_target_image(target_material, atlas_image)

        sources: list[tuple[bpy.types.Object, bpy.types.Object, str]] = []
        displacement_metadata: dict[str, dict[str, float | int]] = {}
        for original, semantic in ((body, "body"), (cape, "cape")):
            low_target = _make_suit_only_copy(
                original,
                f"GV3_{semantic.title()}_SuitBakeTarget",
                temp_collection,
                target_material,
            )
            high = _make_high_source(
                low_target,
                f"GV3_{semantic.title()}_SuitBakeHigh",
                source_collection,
                materials[SUIT_MATERIAL],
                semantic,
            )
            low_targets.append(low_target)
            generated_high.append(high)
            sources.append((high, low_target, semantic))
            displacement_metadata[semantic] = {
                "vertices": len(high.data.vertices),
                "polygons": len(high.data.polygons),
                "maximum_abs_displacement_m": float(high["gloam_max_displacement_m"]),
                "rms_displacement_m": float(high["gloam_rms_displacement_m"]),
            }

        render_state = _configure_cycles_cpu()
        for index, (high, low_target, _semantic) in enumerate(sources):
            _bake_selected_to_active(high, low_target, clear=index == 0)

        atlas_image.filepath_raw = str(output_path)
        atlas_image.file_format = "PNG"
        atlas_image.save()
        if not output_path.is_file() or output_path.stat().st_size <= 0:
            raise RuntimeError(f"Cycles bake did not create {output_path}")

        _connect_suit_normal(materials[SUIT_MATERIAL], atlas_image)
        for obj in originals:
            after = _low_mesh_fingerprint(obj)
            if after != geometry_before[obj.name]:
                raise RuntimeError(f"Normal bake mutated low geometry/weights/morphs: {obj.name}")

        for high in generated_high:
            high.hide_render = True
            high.hide_set(True)
            high.select_set(False)
        source_collection.hide_render = True
        source_collection.hide_viewport = True
        source_collection["gloam_no_export"] = True
        source_collection["gloam_generated_source"] = "procedural-high-normal-bake"

        metadata: dict[str, object] = {
            "status": "baked",
            "atlas": str(output_path),
            "atlas_sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
            "resolution": [ATLAS_SIZE, ATLAS_SIZE],
            "normal_space": "TANGENT",
            "normal_swizzle": ["POS_X", "POS_Y", "POS_Z"],
            "renderer": "CYCLES",
            "device": "CPU",
            "cycles_samples": CYCLES_SAMPLES,
            "selected_to_active": True,
            "cage_extrusion_m": CAGE_EXTRUSION_METERS,
            "max_ray_distance_m": MAX_RAY_DISTANCE_METERS,
            "bake_margin_pixels": BAKE_MARGIN_PIXELS,
            "joint_uv_pack": pack_metadata,
            "material": SUIT_MATERIAL,
            "normal_strength": NORMAL_STRENGTH,
            "export_materials": sorted(EXPORT_MATERIALS),
            "export_material_count": len(EXPORT_MATERIALS),
            "high_source_collection": SOURCE_COLLECTION_NAME,
            "high_sources": [obj.name for obj in generated_high],
            "high_source_generation": {
                "authorship": "generated-high-mesh",
                "manual_sculpt": False,
                "subdivision": "SIMPLE",
                "subdivision_levels": 1,
                "maximum_allowed_displacement_m": MAX_DISPLACEMENT_METERS,
                "fields": [
                    "localized Gaussian elbow compression folds",
                    "localized Gaussian knee tension/compression folds",
                    "diagonal armpit tension folds",
                    "longitudinal cape drape ridges",
                    "band-limited woven micro-relief displaced on geometry",
                ],
                "measurements": displacement_metadata,
            },
            "low_preservation": {
                "positions": True,
                "topology": True,
                "vertex_groups_and_weights": True,
                "shape_keys": True,
                "object_transforms": True,
                "armature_rest_data_touched": False,
                "only_suit_uv_loops_changed": True,
            },
            "limitations": [
                "The high source is deterministic generated geometry, not a manual sculpt.",
                "One Simple subdivision band-limits weave detail to the generated high-mesh density.",
                "Only tangent normals are baked; no displacement, cavity, AO, or color maps are produced.",
                "A 2 mm cage and 4 mm ray limit reduce cross-limb projection but still require visual seam review.",
                "The shared suit atlas intentionally repacks suit loops; non-suit material UV loops are unchanged.",
            ],
        }
        materials[SUIT_MATERIAL]["gloam_normal_bake"] = json.dumps(metadata, sort_keys=True)
        committed = True
        return metadata
    except Exception:
        for obj in originals:
            _restore_active_uv(obj, uv_before[obj.name])
        _restore_suit_normal_state(materials[SUIT_MATERIAL], material_state)
        raise
    finally:
        if render_state is not None:
            _restore_cycles_state(render_state)
        for low_target in low_targets:
            _remove_object_and_unused_mesh(low_target)
        # Also catches a joint UV carrier or partially constructed target when
        # an operator raises before it is added to the tracked target list.
        for temporary in list(temp_collection.objects):
            _remove_object_and_unused_mesh(temporary)
        _remove_collection_if_empty(temp_collection)
        if not committed:
            for high in generated_high:
                _remove_object_and_unused_mesh(high)
            _remove_collection_if_empty(source_collection)
        if target_material is not None and target_material.users == 0:
            bpy.data.materials.remove(target_material)
        if not committed and atlas_image is not None and atlas_image.users == 0:
            bpy.data.images.remove(atlas_image)
        _restore_selection_state(selection_state)


def _validate_inputs(
    body: bpy.types.Object,
    cape: bpy.types.Object,
    materials: Mapping[str, bpy.types.Material],
) -> None:
    for obj, label in ((body, "body"), (cape, "cape")):
        if obj is None or obj.type != "MESH":
            raise TypeError(f"{label} must be a Blender mesh object")
        if obj.mode != "OBJECT":
            raise ValueError(f"{label} must be in Object mode before baking")
        if obj.data.uv_layers.active is None:
            raise ValueError(f"{label} has no active UV layer")
        if not _suit_material_indices(obj):
            raise ValueError(f"{label} has no {SUIT_MATERIAL} faces")
        if any(component <= 0.0 for component in obj.scale):
            raise ValueError(f"{label} must not use zero or negative object scale")
    missing = EXPORT_MATERIALS - set(materials)
    if missing:
        raise ValueError(f"Missing required export materials: {sorted(missing)}")
    if materials[SUIT_MATERIAL].name != SUIT_MATERIAL:
        raise ValueError("Shared suit material name changed")


def _joint_pack_suit_uvs(
    body: bpy.types.Object,
    cape: bpy.types.Object,
    collection: bpy.types.Collection,
) -> dict[str, object]:
    """Pack body/cape suit islands on one temporary carrier and transfer UVs."""

    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    mapping: list[tuple[bpy.types.Object, tuple[int, ...]]] = []
    initial_uvs: list[list[tuple[float, float]]] = []
    object_face_counts: dict[str, int] = {}

    for obj in (body, cape):
        suit_indices = _suit_material_indices(obj)
        source_uv = obj.data.uv_layers.active.data
        vertex_offset = len(vertices)
        matrix = obj.matrix_world
        vertices.extend(tuple(matrix @ vertex.co) for vertex in obj.data.vertices)
        count = 0
        for polygon in obj.data.polygons:
            if polygon.material_index not in suit_indices:
                continue
            faces.append(tuple(vertex_offset + index for index in polygon.vertices))
            loop_indices = tuple(polygon.loop_indices)
            mapping.append((obj, loop_indices))
            initial_uvs.append([tuple(source_uv[index].uv) for index in loop_indices])
            count += 1
        object_face_counts[obj.name] = count

    carrier_mesh = bpy.data.meshes.new("GV3_JointSuitUVCarrierMesh")
    carrier_mesh.from_pydata(vertices, [], faces)
    carrier_mesh.update()
    carrier = bpy.data.objects.new("GV3_JointSuitUVCarrier", carrier_mesh)
    collection.objects.link(carrier)
    carrier_uv = carrier_mesh.uv_layers.new(name=UV_LAYER_NAME)
    for polygon, source_values in zip(carrier_mesh.polygons, initial_uvs, strict=True):
        if len(polygon.loop_indices) != len(source_values):
            raise RuntimeError("Temporary joint UV carrier changed polygon loop order")
        for loop_index, uv in zip(polygon.loop_indices, source_values, strict=True):
            carrier_uv.data[loop_index].uv = uv

    _select_only(carrier)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    scale_result = bpy.ops.uv.average_islands_scale(scale_uv=False, shear=False)
    if "FINISHED" not in scale_result:
        bpy.ops.object.mode_set(mode="OBJECT")
        raise RuntimeError(f"Joint suit UV texel-density normalization failed: {sorted(scale_result)}")
    result = bpy.ops.uv.pack_islands(
        rotate=True,
        rotate_method="CARDINAL",
        scale=True,
        merge_overlap=False,
        margin_method="FRACTION",
        margin=UV_MARGIN_PIXELS / ATLAS_SIZE,
        shape_method="CONCAVE",
    )
    bpy.ops.object.mode_set(mode="OBJECT")
    if "FINISHED" not in result:
        raise RuntimeError(f"Joint suit UV pack failed: {sorted(result)}")

    for polygon, (target, target_loop_indices) in zip(carrier_mesh.polygons, mapping, strict=True):
        target_uv = target.data.uv_layers.active.data
        for packed_loop, target_loop in zip(polygon.loop_indices, target_loop_indices, strict=True):
            target_uv[target_loop].uv = carrier_uv.data[packed_loop].uv
        target.data.update()

    minimum = Vector((math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf))
    for value in carrier_uv.data:
        minimum.x = min(minimum.x, value.uv.x)
        minimum.y = min(minimum.y, value.uv.y)
        maximum.x = max(maximum.x, value.uv.x)
        maximum.y = max(maximum.y, value.uv.y)
    if minimum.x < -1.0e-6 or minimum.y < -1.0e-6 or maximum.x > 1.0 + 1.0e-6 or maximum.y > 1.0 + 1.0e-6:
        raise RuntimeError(f"Joint suit UV pack escaped 0-1: {tuple(minimum)} to {tuple(maximum)}")

    metadata = {
        "method": "single temporary body+cape suit carrier",
        "carrier_uv_layer": UV_LAYER_NAME,
        "target_uv_layers": {
            body.name: body.data.uv_layers.active.name,
            cape.name: cape.data.uv_layers.active.name,
        },
        "resolution": [ATLAS_SIZE, ATLAS_SIZE],
        "average_islands_scale": True,
        "margin_method": "FRACTION",
        "margin_pixels": UV_MARGIN_PIXELS,
        "rotate_method": "CARDINAL",
        "packed_face_count": len(faces),
        "object_face_counts": object_face_counts,
        "bounds": [list(minimum), list(maximum)],
        "non_suit_uv_loops_changed": False,
    }
    _remove_object_and_unused_mesh(carrier)
    return metadata


def _make_suit_only_copy(
    original: bpy.types.Object,
    name: str,
    collection: bpy.types.Collection,
    target_material: bpy.types.Material,
) -> bpy.types.Object:
    duplicate = original.copy()
    duplicate.data = original.data.copy()
    duplicate.name = name
    duplicate.data.name = f"{name}Mesh"
    collection.objects.link(duplicate)
    duplicate.parent = None
    duplicate.matrix_world = original.matrix_world.copy()
    duplicate.animation_data_clear()
    _clear_shape_keys(duplicate)
    duplicate.modifiers.clear()

    suit_indices = _suit_material_indices(duplicate)
    import bmesh

    mesh = duplicate.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    remove_faces = [face for face in bm.faces if face.material_index not in suit_indices]
    if remove_faces:
        bmesh.ops.delete(bm, geom=remove_faces, context="FACES")
    used_vertices = {vertex for face in bm.faces for vertex in face.verts}
    loose_vertices = [vertex for vertex in bm.verts if vertex not in used_vertices]
    if loose_vertices:
        bmesh.ops.delete(bm, geom=loose_vertices, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    if not mesh.polygons:
        raise RuntimeError(f"Suit-only bake target is empty: {original.name}")

    mesh.materials.clear()
    mesh.materials.append(target_material)
    for polygon in mesh.polygons:
        polygon.material_index = 0
        polygon.use_smooth = True
    duplicate["gloam_no_export"] = True
    duplicate["gloam_bake_target"] = True
    return duplicate


def _make_high_source(
    low_target: bpy.types.Object,
    name: str,
    collection: bpy.types.Collection,
    suit_material: bpy.types.Material,
    semantic: str,
) -> bpy.types.Object:
    high = low_target.copy()
    high.data = low_target.data.copy()
    high.name = name
    high.data.name = f"{name}Mesh"
    collection.objects.link(high)
    high.parent = None
    high.matrix_world = low_target.matrix_world.copy()
    high.animation_data_clear()
    _clear_shape_keys(high)
    high.modifiers.clear()
    high.data.materials.clear()
    high.data.materials.append(suit_material)

    _select_only(high)
    subdivision = high.modifiers.new("GV3 Bake Simple Subdivision", "SUBSURF")
    subdivision.subdivision_type = "SIMPLE"
    subdivision.levels = 1
    subdivision.render_levels = 1
    result = bpy.ops.object.modifier_apply(modifier=subdivision.name)
    if "FINISHED" not in result:
        raise RuntimeError(f"Could not apply Simple subdivision to {name}: {sorted(result)}")

    maximum, rms = _displace_high_mesh(high, semantic)
    high["gloam_no_export"] = True
    high["gloam_generated_high_mesh"] = True
    high["gloam_high_source_method"] = "simple-subdivision-1 plus analytic cloth relief"
    high["gloam_manual_sculpt"] = False
    high["gloam_max_displacement_m"] = maximum
    high["gloam_rms_displacement_m"] = rms
    high["gloam_projection_cage_m"] = CAGE_EXTRUSION_METERS
    high["gloam_projection_max_ray_m"] = MAX_RAY_DISTANCE_METERS
    return high


def _displace_high_mesh(obj: bpy.types.Object, semantic: str) -> tuple[float, float]:
    mesh = obj.data
    mesh.update()
    normals = [vertex.normal.copy() for vertex in mesh.vertices]
    squared_sum = 0.0
    maximum = 0.0
    for vertex, normal in zip(mesh.vertices, normals, strict=True):
        point = vertex.co.copy()
        if semantic == "body":
            displacement = _body_relief(point)
        elif semantic == "cape":
            displacement = _cape_relief(point)
        else:
            raise ValueError(f"Unknown suit bake semantic: {semantic}")
        displacement = max(-MAX_DISPLACEMENT_METERS, min(MAX_DISPLACEMENT_METERS, displacement))
        vertex.co += normal * displacement
        maximum = max(maximum, abs(displacement))
        squared_sum += displacement * displacement
    mesh.update()
    rms = math.sqrt(squared_sum / max(len(mesh.vertices), 1))
    if maximum > MAX_DISPLACEMENT_METERS + 1.0e-9:
        raise RuntimeError(f"High-source displacement exceeded {MAX_DISPLACEMENT_METERS} m")
    return maximum, rms


def _body_relief(point: Vector) -> float:
    x, y, z = point
    displacement = 0.0
    absolute_x = abs(x)

    # Elbow compression: asymmetric nested ridges across the nearly vertical
    # arm axis, restricted to the sleeve rather than the adjacent torso.
    elbow_envelope = _gauss(absolute_x - 0.390, 0.095) * _gauss(z - 1.250, 0.115)
    elbow_front = 0.32 + 0.68 * _smooth01((-y + 0.090) / 0.180)
    elbow_profile = (
        0.78 * _crease(z - 1.222, 0.010)
        - 0.62 * _crease(z - 1.250, 0.008)
        + 0.46 * _crease(z - 1.278, 0.012)
    )
    displacement += 0.00058 * elbow_envelope * elbow_front * elbow_profile

    # Knee cloth alternates a shallow front tension ridge with compressed folds
    # above/below the joint.  The tight X envelope prevents thigh cross-talk.
    knee_envelope = _gauss(absolute_x - 0.120, 0.125) * _gauss(z - 0.620, 0.135)
    knee_front = 0.38 + 0.62 * _smooth01((-y + 0.120) / 0.240)
    knee_profile = (
        0.56 * _crease(z - 0.576, 0.014)
        - 0.82 * _crease(z - 0.618, 0.011)
        + 0.64 * _crease(z - 0.660, 0.016)
    )
    displacement += 0.00062 * knee_envelope * knee_front * knee_profile

    # Diagonal tension runs from the underarm toward the ribs.  Gaussian ridge
    # pairs create an actual high-mesh crease and shoulder, not an image mask.
    underarm_envelope = _gauss(absolute_x - 0.275, 0.095) * _gauss(z - 1.565, 0.155)
    underarm_front = 0.25 + 0.75 * _smooth01((-y + 0.105) / 0.210)
    diagonal = (z - 1.565) + 0.72 * (absolute_x - 0.275)
    underarm_profile = _crease(diagonal + 0.026, 0.011) - 0.72 * _crease(diagonal - 0.026, 0.014)
    displacement += 0.00050 * underarm_envelope * underarm_front * underarm_profile

    # Woven micro-relief is physically applied to the generated high mesh.  Its
    # deliberately low amplitude preserves the authored silhouette and avoids a
    # noisy embossed look after normal-map filtering.
    warp = math.sin(math.tau * (z / 0.018 + x / 0.071))
    weft = math.sin(math.tau * ((x + 0.31 * y) / 0.016))
    diagonal_weave = math.sin(math.tau * ((z + 0.43 * x) / 0.027))
    displacement += 0.000075 * (0.62 * warp * weft + 0.18 * diagonal_weave)
    return displacement


def _cape_relief(point: Vector) -> float:
    x, y, z = point
    v = _smooth01((1.705 - z) / 1.175)
    width = 0.205 + 0.105 * v
    inner = 0.012 + 0.055 * v
    u = _smooth01((abs(x) - inner) / max(width, 0.001))

    # Long gravity folds widen gently toward the hem.  Shoulder tension is a
    # separate diagonal field so the cape does not read as a periodic curtain.
    drape = (
        0.58 * _crease(u - 0.20, 0.075)
        - 0.46 * _crease(u - 0.44, 0.090)
        + 0.52 * _crease(u - 0.73, 0.080)
    )
    displacement = 0.00052 * (0.30 + 0.70 * v) * drape
    shoulder_tension = _gauss(v - 0.18, 0.23) * (
        _crease((u - 0.52) + 0.34 * (v - 0.18), 0.050)
        - 0.55 * _crease((u - 0.52) - 0.29 * (v - 0.18), 0.065)
    )
    displacement += 0.00034 * shoulder_tension

    warp = math.sin(math.tau * (z / 0.019 + x / 0.083))
    weft = math.sin(math.tau * ((x + 0.24 * y) / 0.017))
    displacement += 0.000070 * (0.58 * warp * weft)
    return displacement


def _crease(value: float, width: float) -> float:
    core = _gauss(value, width)
    shoulder = _gauss(value, width * 2.35)
    return core - 0.43 * shoulder


def _gauss(value: float, width: float) -> float:
    return math.exp(-((value / max(width, 1.0e-9)) ** 2))


def _smooth01(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def _bake_selected_to_active(
    high: bpy.types.Object,
    low: bpy.types.Object,
    *,
    clear: bool,
) -> None:
    high.hide_set(False)
    low.hide_set(False)
    _select_only(high, low, active=low)
    result = bpy.ops.object.bake(
        type="NORMAL",
        use_selected_to_active=True,
        normal_space="TANGENT",
        normal_r="POS_X",
        normal_g="POS_Y",
        normal_b="POS_Z",
        target="IMAGE_TEXTURES",
        save_mode="INTERNAL",
        use_clear=clear,
        use_cage=False,
        cage_extrusion=CAGE_EXTRUSION_METERS,
        max_ray_distance=MAX_RAY_DISTANCE_METERS,
        margin=BAKE_MARGIN_PIXELS,
        margin_type="EXTEND",
        uv_layer=low.data.uv_layers.active.name,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"Cycles selected-to-active bake failed for {low.name}: {sorted(result)}")


def _configure_cycles_cpu() -> dict[str, object]:
    scene = bpy.context.scene
    state = {
        "engine": scene.render.engine,
        "device": scene.cycles.device,
        "samples": scene.cycles.samples,
    }
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = CYCLES_SAMPLES
    return state


def _restore_cycles_state(state: Mapping[str, object]) -> None:
    scene = bpy.context.scene
    scene.cycles.device = str(state["device"])
    scene.cycles.samples = int(state["samples"])
    scene.render.engine = str(state["engine"])


def _make_bake_target_material() -> bpy.types.Material:
    material = bpy.data.materials.new("GV3_SuitBakeTargetMaterial")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    image = nodes.new("ShaderNodeTexImage")
    image.name = "GV3_SuitBakeTargetImage"
    material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
    nodes.active = image
    image.select = True
    return material


def _set_bake_target_image(material: bpy.types.Material, image: bpy.types.Image) -> None:
    node = material.node_tree.nodes.get("GV3_SuitBakeTargetImage")
    if node is None or node.type != "TEX_IMAGE":
        raise RuntimeError("Bake target material lost its active image node")
    node.image = image
    material.node_tree.nodes.active = node
    node.select = True


def _connect_suit_normal(material: bpy.types.Material, image: bpy.types.Image) -> None:
    if not material.use_nodes or material.node_tree is None:
        raise ValueError(f"{SUIT_MATERIAL} must use nodes")
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    normal_map = next((node for node in nodes if node.type == "NORMAL_MAP"), None)
    if normal_map is None:
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.name = f"{SUIT_MATERIAL}_NormalMap"
        principled = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            raise ValueError(f"{SUIT_MATERIAL} has no Principled BSDF")
        links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    texture = next(
        (
            link.from_node
            for link in normal_map.inputs["Color"].links
            if link.from_node.type == "TEX_IMAGE"
        ),
        None,
    )
    if texture is None:
        texture = nodes.new("ShaderNodeTexImage")
        texture.name = f"{SUIT_MATERIAL}_BakedNormal"
        links.new(texture.outputs["Color"], normal_map.inputs["Color"])
    texture.image = image
    image.colorspace_settings.name = "Non-Color"
    normal_map.space = "TANGENT"
    normal_map.inputs["Strength"].default_value = NORMAL_STRENGTH


def _capture_suit_normal_state(material: bpy.types.Material) -> dict[str, object]:
    if not material.use_nodes or material.node_tree is None:
        return {"normal_map": None, "texture": None, "image": None, "strength": None}
    normal_map = next((node for node in material.node_tree.nodes if node.type == "NORMAL_MAP"), None)
    texture = None
    if normal_map is not None:
        texture = next(
            (
                link.from_node
                for link in normal_map.inputs["Color"].links
                if link.from_node.type == "TEX_IMAGE"
            ),
            None,
        )
    return {
        "normal_map": normal_map,
        "texture": texture,
        "image": texture.image if texture is not None else None,
        "strength": normal_map.inputs["Strength"].default_value if normal_map is not None else None,
    }


def _restore_suit_normal_state(material: bpy.types.Material, state: Mapping[str, object]) -> None:
    normal_map = state.get("normal_map")
    texture = state.get("texture")
    if texture is not None:
        texture.image = state.get("image")
    if normal_map is not None and state.get("strength") is not None:
        normal_map.inputs["Strength"].default_value = float(state["strength"])


def _suit_material_indices(obj: bpy.types.Object) -> set[int]:
    return {
        index
        for index, material in enumerate(obj.data.materials)
        if material is not None and material.name == SUIT_MATERIAL
    }


def _snapshot_active_uv(obj: bpy.types.Object) -> dict[str, object]:
    layer = obj.data.uv_layers.active
    if layer is None:
        raise ValueError(f"{obj.name} has no active UV layer")
    return {
        "name": layer.name,
        "active_index": obj.data.uv_layers.active_index,
        "values": [tuple(item.uv) for item in layer.data],
    }


def _restore_active_uv(obj: bpy.types.Object, snapshot: Mapping[str, object]) -> None:
    layer = obj.data.uv_layers.get(str(snapshot["name"]))
    if layer is None:
        return
    values = snapshot["values"]
    if len(values) != len(layer.data):
        raise RuntimeError(f"Cannot restore UVs after topology changed: {obj.name}")
    for item, value in zip(layer.data, values, strict=True):
        item.uv = value
    obj.data.uv_layers.active_index = int(snapshot["active_index"])
    obj.data.update()


def _low_mesh_fingerprint(obj: bpy.types.Object) -> str:
    """Hash low geometry, materials, vertex weights, and all shape-key points."""

    digest = hashlib.sha256()
    digest.update(obj.name.encode())
    for vertex in obj.data.vertices:
        digest.update(struct.pack("<3d", *vertex.co))
        for assignment in sorted(vertex.groups, key=lambda item: item.group):
            digest.update(struct.pack("<Id", assignment.group, assignment.weight))
    for polygon in obj.data.polygons:
        digest.update(struct.pack("<II", len(polygon.vertices), polygon.material_index))
        for vertex_index in polygon.vertices:
            digest.update(struct.pack("<I", vertex_index))
    for material in obj.data.materials:
        digest.update((material.name if material else "<none>").encode())
    if obj.data.shape_keys is not None:
        for key in obj.data.shape_keys.key_blocks:
            digest.update(key.name.encode())
            for point in key.data:
                digest.update(struct.pack("<3d", *point.co))
    digest.update(struct.pack("<16d", *(component for row in obj.matrix_world for component in row)))
    digest.update((obj.parent.name if obj.parent else "<none>").encode())
    return digest.hexdigest()


def _clear_shape_keys(obj: bpy.types.Object) -> None:
    if obj.data.shape_keys is None:
        return
    for key in list(obj.data.shape_keys.key_blocks)[::-1]:
        obj.shape_key_remove(key)


def _fresh_collection(name: str, *, remove_existing: bool) -> bpy.types.Collection:
    existing = bpy.data.collections.get(name)
    if existing is not None and remove_existing:
        for obj in list(existing.objects):
            if bool(obj.get("gloam_no_export", False)) or obj.name.startswith("GV3_"):
                _remove_object_and_unused_mesh(obj)
            else:
                raise RuntimeError(f"Refusing to replace unowned object {obj.name} in {name}")
        _unlink_collection_recursive(bpy.context.scene.collection, existing)
        if existing.users == 0:
            bpy.data.collections.remove(existing)
        if existing.name in bpy.data.collections:
            raise RuntimeError(f"Could not unlink prior generated collection {name}")
        existing = None
    if existing is None:
        existing = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(existing)
    existing.hide_viewport = False
    existing.hide_render = False
    return existing


def _remove_object_and_unused_mesh(obj: bpy.types.Object) -> None:
    mesh = obj.data if obj.type == "MESH" else None
    if obj.name in bpy.data.objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def _remove_collection_if_empty(collection: bpy.types.Collection) -> None:
    if collection is None or collection.objects:
        return
    _unlink_collection_recursive(bpy.context.scene.collection, collection)
    if collection.users == 0 and collection.name in bpy.data.collections:
        bpy.data.collections.remove(collection)


def _unlink_collection_recursive(
    parent: bpy.types.Collection,
    target: bpy.types.Collection,
) -> None:
    for child in list(parent.children):
        if child == target:
            parent.children.unlink(child)
        else:
            _unlink_collection_recursive(child, target)


def _capture_selection_state() -> dict[str, object]:
    active = bpy.context.view_layer.objects.active
    return {
        "active": active,
        "selected": [obj for obj in bpy.context.selected_objects],
        "mode": active.mode if active is not None else "OBJECT",
        "hidden": {obj.name: obj.hide_get() for obj in bpy.context.view_layer.objects},
    }


def _restore_selection_state(state: Mapping[str, object]) -> None:
    active_now = bpy.context.view_layer.objects.active
    if active_now is not None and active_now.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in state["selected"]:
        if obj.name in bpy.context.view_layer.objects:
            obj.hide_set(False)
            obj.select_set(True)
    active = state["active"]
    if active is not None and active.name in bpy.context.view_layer.objects:
        bpy.context.view_layer.objects.active = active
        mode = str(state["mode"])
        if mode != "OBJECT":
            bpy.ops.object.mode_set(mode=mode)
    hidden = state["hidden"]
    for obj in bpy.context.view_layer.objects:
        if obj.name in hidden:
            obj.hide_set(bool(hidden[obj.name]))


def _select_only(
    *objects: bpy.types.Object,
    active: bpy.types.Object | None = None,
) -> None:
    current = bpy.context.view_layer.objects.active
    if current is not None and current.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active or objects[-1]
