"""Read-only review and adaptation plan for the official Blender base head.

Default execution appends the exact `Head (Animation) - Realistic` collection
from Blender's Human Base Meshes v1.4.1 into an empty unsaved scene, inventories
its untouched geometry/UV/multires/asset metadata, and renders neutral clay
front/profile/three-quarter views.  It does not alter the source library or
produce a game asset.  Run Blender with `--disable-autoexec` so embedded scripts
cannot execute.

The base anatomy is CC0 work by Dan Ulrich from the official Blender bundle; it
must not be described as wholly original project geometry.  Future project
contributions are the original character design, muscular reshaping, fitted
suit/mask/cape, rig adaptation, facial shapes, and authored surface treatment.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
SOURCE_BLEND = HERE / "reference" / "human-base-meshes-bundle-v1.4.1" / "human_base_meshes_bundle.blend"
REVIEW_DIR = HERE / "renders" / "base-head-review"
REVIEW_JSON = HERE / "base_head_review.json"

ARCHIVE_SHA256 = "811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515"
SOURCE_BLEND_SHA256 = "3c121505651140ceb4d69fd1d8923f7788ffadd81672f5be14845a5f2c75c137"
SOURCE_COLLECTION = "Head (Animation) - Realistic"
SOURCE_AUTHOR = "Dan Ulrich"
SOURCE_LICENSE = "CC0"
SOURCE_LISTING = "https://www.blender.org/download/demo-files/"
SOURCE_DOWNLOAD = "https://download.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip"

EXPECTED_HEAD_OBJECT = "GEO-head_animation_realistic"
EXPECTED_EYE_OBJECT_TOKENS = ("iris.L", "iris.R", "sclera.L", "sclera.R")
TARGET_MORPHS = ("blink.L", "blink.R", "brow_inner_raise", "jaw_clench")
TARGET_MATERIALS = (
    "MAT_GV2_Suit_Cloth",
    "MAT_GV2_Skin",
    "MAT_GV2_Gear",
    "MAT_GV2_Tactical_Boot",
    "MAT_GV2_Accent",
)
TARGET_SKULL_TOP_M = 2.16
TARGET_CHIN_RANGE_M = (1.88, 1.90)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _assert_source() -> None:
    assert SOURCE_BLEND.is_file(), SOURCE_BLEND
    assert _sha256(SOURCE_BLEND) == SOURCE_BLEND_SHA256
    archive = SOURCE_BLEND.parent.parent / "human-base-meshes-bundle-v1.4.1.zip"
    assert archive.is_file(), archive
    assert _sha256(archive) == ARCHIVE_SHA256


def append_source_collection() -> bpy.types.Collection:
    """Append only the named asset collection; never open/execute its scene."""
    _assert_source()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(SOURCE_BLEND), link=False, assets_only=False) as (available, requested):
        assert SOURCE_COLLECTION in available.collections, SOURCE_COLLECTION
        requested.collections = [SOURCE_COLLECTION]
    collection = bpy.data.collections.get(SOURCE_COLLECTION)
    assert collection is not None
    bpy.context.scene.collection.children.link(collection)
    object_names = {obj.name for obj in collection.all_objects}
    assert EXPECTED_HEAD_OBJECT in object_names, sorted(object_names)
    for token in EXPECTED_EYE_OBJECT_TOKENS:
        assert any(token in name for name in object_names), (token, sorted(object_names))
    return collection


def _world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                minimum[axis] = min(minimum[axis], point[axis])
                maximum[axis] = max(maximum[axis], point[axis])
    return minimum, maximum


def _boundary_edge_count(mesh: bpy.types.Mesh) -> int:
    uses: dict[tuple[int, int], int] = {}
    for polygon in mesh.polygons:
        indices = polygon.vertices
        for index in range(len(indices)):
            edge = tuple(sorted((indices[index], indices[(index + 1) % len(indices)])))
            uses[edge] = uses.get(edge, 0) + 1
    return sum(count == 1 for count in uses.values())


def _mesh_record(obj: bpy.types.Object, depsgraph: bpy.types.Depsgraph) -> dict[str, object]:
    mesh = obj.data
    polygons_by_sides: dict[str, int] = {}
    for polygon in mesh.polygons:
        key = str(len(polygon.vertices))
        polygons_by_sides[key] = polygons_by_sides.get(key, 0) + 1
    evaluated = obj.evaluated_get(depsgraph)
    evaluated_mesh = evaluated.to_mesh()
    evaluated_record = {
        "vertices": len(evaluated_mesh.vertices),
        "polygons": len(evaluated_mesh.polygons),
        "triangles_after_loop_calc": 0,
    }
    evaluated_mesh.calc_loop_triangles()
    evaluated_record["triangles_after_loop_calc"] = len(evaluated_mesh.loop_triangles)
    evaluated.to_mesh_clear()

    world_vertices = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    minimum_z = min((point.z for point in world_vertices), default=0.0)
    low_vertices = [point for point in world_vertices if point.z <= minimum_z + 0.0005]
    return {
        "name": obj.name,
        "base_vertices": len(mesh.vertices),
        "base_edges": len(mesh.edges),
        "base_polygons": len(mesh.polygons),
        "base_triangles": sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons),
        "polygons_by_sides": polygons_by_sides,
        "boundary_edges": _boundary_edge_count(mesh),
        "lowest_vertex_z_m": minimum_z,
        "lowest_ring_vertex_count_0_5mm": len(low_vertices),
        "uv_layers": [layer.name for layer in mesh.uv_layers],
        "active_uv": mesh.uv_layers.active.name if mesh.uv_layers.active else None,
        "color_attributes": [attribute.name for attribute in mesh.color_attributes],
        "mesh_attributes": [attribute.name for attribute in mesh.attributes],
        "shape_keys": [block.name for block in mesh.shape_keys.key_blocks] if mesh.shape_keys else [],
        "vertex_groups": [group.name for group in obj.vertex_groups],
        "modifiers": [
            {
                "name": modifier.name,
                "type": modifier.type,
                "levels": getattr(modifier, "levels", None),
                "sculpt_levels": getattr(modifier, "sculpt_levels", None),
                "render_levels": getattr(modifier, "render_levels", None),
                "total_levels": getattr(modifier, "total_levels", None),
            }
            for modifier in obj.modifiers
        ],
        "evaluated": evaluated_record,
    }


def _asset_metadata(collection: bpy.types.Collection) -> dict[str, object]:
    asset = collection.asset_data
    assert asset is not None, f"{SOURCE_COLLECTION} is missing asset metadata"
    record = {
        "name": collection.name,
        "author": asset.author,
        "license": asset.license,
        "copyright": asset.copyright,
        "description": asset.description,
        "catalog_id": str(asset.catalog_id),
    }
    assert SOURCE_AUTHOR.lower() in asset.author.lower(), record
    assert asset.license.upper().replace("-", "") == SOURCE_LICENSE, record
    return record


def inspect_collection(collection: bpy.types.Collection) -> dict[str, object]:
    objects = list(collection.all_objects)
    meshes = [obj for obj in objects if obj.type == "MESH"]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    minimum, maximum = _world_bounds(meshes)
    head = bpy.data.objects[EXPECTED_HEAD_OBJECT]
    head_minimum, head_maximum = _world_bounds([head])

    eye_centers: dict[str, list[float]] = {}
    for obj in meshes:
        if any(token in obj.name for token in EXPECTED_EYE_OBJECT_TOKENS):
            eye_minimum, eye_maximum = _world_bounds([obj])
            center = (eye_minimum + eye_maximum) * 0.5
            eye_centers[obj.name] = [round(value, 6) for value in center]
    assert len(eye_centers) >= 4, eye_centers

    average_eye_y = sum(center[1] for center in eye_centers.values()) / len(eye_centers)
    head_center_y = (head_minimum.y + head_maximum.y) * 0.5
    detected_forward = "-Y" if average_eye_y < head_center_y else "+Y"
    report = {
        "review_status": "untouched_source_review_not_game_asset",
        "source": {
            "listing": SOURCE_LISTING,
            "download": SOURCE_DOWNLOAD,
            "archive_sha256": ARCHIVE_SHA256,
            "blend_sha256": SOURCE_BLEND_SHA256,
            "collection": SOURCE_COLLECTION,
            "asset_metadata": _asset_metadata(collection),
        },
        "scene_units": {
            "system": bpy.context.scene.unit_settings.system,
            "scale_length": bpy.context.scene.unit_settings.scale_length,
            "length_unit": bpy.context.scene.unit_settings.length_unit,
        },
        "object_names": [obj.name for obj in objects],
        "mesh_records": [_mesh_record(obj, depsgraph) for obj in meshes],
        "collection_bounds_m": {
            "minimum": [round(value, 6) for value in minimum],
            "maximum": [round(value, 6) for value in maximum],
            "size": [round(value, 6) for value in maximum - minimum],
        },
        "head_bounds_m": {
            "minimum": [round(value, 6) for value in head_minimum],
            "maximum": [round(value, 6) for value in head_maximum],
            "size": [round(value, 6) for value in head_maximum - head_minimum],
        },
        "actual_eye_centers_m": eye_centers,
        "detected_forward_axis": detected_forward,
    }
    report["adaptation_plan"] = build_adaptation_plan(report)
    return report


def build_adaptation_plan(review: dict[str, object]) -> dict[str, object]:
    """Record a decision-gated plan; intentionally performs no mesh edits."""
    head_records = [record for record in review["mesh_records"] if record["name"] == EXPECTED_HEAD_OBJECT]  # type: ignore[index]
    assert len(head_records) == 1
    head_record = head_records[0]
    return {
        "decision_gate": "Compare Body Male - Realistic as one-piece anatomy before choosing head swap; do not adapt this head independently until that review.",
        "preferred_if_head_swap": EXPECTED_HEAD_OBJECT,
        "reason": "Animation head has deliberate deformation topology and existing UVs at a light base cage; it is preferable to the sculpt head as the game deformation mesh.",
        "target_landmarks_m": {
            "skull_top_z": TARGET_SKULL_TOP_M,
            "chin_z_range": list(TARGET_CHIN_RANGE_M),
            "eye_centers": "Measure from appended iris/sclera objects after final uniform scale; do not force legacy +/-0.039 anchors.",
        },
        "topology_budget": {
            "base_triangles": head_record["base_triangles"],
            "evaluated_triangles": head_record["evaluated"]["triangles_after_loop_calc"],  # type: ignore[index]
            "recommendation": "Keep the animation base cage for deformation; use the existing Multires detail as a normal-bake source instead of exporting subdivided head density by default.",
        },
        "attachment": "Preserve the lowest open neck loop and UVs; align by measured crown/chin/eye landmarks, then bridge or surface-deform into the selected body neck. Do not cap or hide an unmatched cylinder inside the collar.",
        "rig": "Retain the 74 names and hierarchy, but place eye/head/jaw rest transforms from final measured landmarks. Transfer weights by surface and explicitly refine eyelid, lips, jaw hinge, neck, and ear regions.",
        "morphs": list(TARGET_MORPHS),
        "morph_method": "Author true basis-relative eyelid and facial cage deltas on the final low mesh; blink must close the lid surfaces over the measured sclera, while jaw_clench must preserve mouth closure.",
        "mask_and_hair": "Design original patterns, ray-cast every vertex to the evaluated final head surface, and offset about 3 mm along interpolated outward normals. Preserve eye holes and ears; no cowl ears, emblem, or franchise silhouette.",
        "materials": list(TARGET_MATERIALS),
        "uv_and_bake": "Retain the source UV set if distortion review passes. Bake Multires/source detail into the project's face normal map after reshaping; record this as a genuine derived bake, not wholly original sculpt detail.",
        "provenance_label": f"Adapted from Blender Human Base Meshes v1.4.1, {SOURCE_COLLECTION}, {SOURCE_AUTHOR}, {SOURCE_LICENSE}.",
    }


def _look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def _area_light(name: str, location: Vector, target: Vector, energy: float, size: float, color: tuple[float, float, float]) -> None:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = location
    _look_at(light, target)


def _setup_studio(center: Vector, span: Vector) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = -0.7
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Base head review world")
    scene.world.color = (0.018, 0.022, 0.030)

    clay = bpy.data.materials.new("Untouched base neutral clay override")
    clay.diffuse_color = (0.36, 0.19, 0.13, 1.0)
    clay.use_nodes = True
    principled = clay.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = clay.diffuse_color
    principled.inputs["Roughness"].default_value = 0.72
    bpy.context.view_layer.material_override = clay

    scale = max(span)
    _area_light("Neutral key", center + Vector((-1.8, -2.4, 2.2)) * scale, center, 120.0, scale * 2.1, (1.0, 0.86, 0.76))
    _area_light("Neutral fill", center + Vector((2.0, -1.2, 0.7)) * scale, center, 55.0, scale * 1.8, (0.68, 0.80, 1.0))
    _area_light("Neutral rim", center + Vector((0.8, 2.2, 1.6)) * scale, center, 95.0, scale * 1.6, (0.72, 0.82, 1.0))

    camera_data = bpy.data.cameras.new("BaseHeadReviewCamera")
    camera_data.lens = 78.0
    camera_data.sensor_width = 36.0
    camera = bpy.data.objects.new("BaseHeadReviewCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    return camera


def render_review(report: dict[str, object]) -> list[str]:
    bounds = report["collection_bounds_m"]  # type: ignore[assignment]
    minimum = Vector(bounds["minimum"])
    maximum = Vector(bounds["maximum"])
    center = (minimum + maximum) * 0.5
    span = maximum - minimum
    camera = _setup_studio(center, span)
    distance = max(span) * 2.65
    forward_sign = -1.0 if report["detected_forward_axis"] == "-Y" else 1.0
    views = {
        "base-head-neutral-front.png": Vector((0.0, forward_sign, 0.0)),
        "base-head-neutral-profile.png": Vector((1.0, 0.0, 0.0)),
        "base-head-neutral-threequarter.png": Vector((0.67, forward_sign, 0.10)).normalized(),
    }
    REVIEW_DIR.mkdir(parents=True, exist_ok=True)
    outputs: list[str] = []
    for filename, direction in views.items():
        camera.location = center + direction * distance
        _look_at(camera, center)
        path = REVIEW_DIR / filename
        bpy.context.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        outputs.append(str(path.relative_to(HERE)))
    return outputs


def main() -> None:
    collection = append_source_collection()
    report = inspect_collection(collection)
    report["renders"] = render_review(report)
    REVIEW_JSON.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("GLOAM_VIGIL_V4_BASE_HEAD_REVIEW_OK " + json.dumps({
        "collection": SOURCE_COLLECTION,
        "author": SOURCE_AUTHOR,
        "license": SOURCE_LICENSE,
        "review_json": str(REVIEW_JSON),
        "renders": report["renders"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
