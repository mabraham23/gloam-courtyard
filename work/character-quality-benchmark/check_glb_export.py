#!/usr/bin/env python3
"""Read-only structural/skin/material audit for a binary glTF (GLB) export.

This deliberately does not use Blender, Godot, or third-party modules. It
validates the exported binary accessors that the runtime will consume, rather
than trusting source-scene object counts.
"""

from __future__ import annotations

import argparse
import base64
import collections
import hashlib
import json
import math
import struct
import sys
from pathlib import Path
from typing import Any, Iterable


GLB_MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
COMPONENTS = {
    5120: ("b", 1, True, 127.0),
    5121: ("B", 1, False, 255.0),
    5122: ("h", 2, True, 32767.0),
    5123: ("H", 2, False, 65535.0),
    5125: ("I", 4, False, 4294967295.0),
    5126: ("f", 4, True, 1.0),
}
TYPE_WIDTH = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
    "MAT2": 4,
    "MAT3": 9,
    "MAT4": 16,
}
TRIANGLE_MODE = 4


class Audit:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)


def parse_glb(path: Path, audit: Audit) -> tuple[dict[str, Any], list[bytes]]:
    payload = path.read_bytes()
    audit.require(len(payload) >= 20, "file is too short to be a GLB")
    if len(payload) < 20:
        return {}, []
    magic, version, declared_length = struct.unpack_from("<4sII", payload, 0)
    audit.require(magic == GLB_MAGIC, f"bad GLB magic {magic!r}")
    audit.require(version == 2, f"expected glTF 2, found {version}")
    audit.require(declared_length == len(payload),
                  f"declared length {declared_length} != file size {len(payload)}")

    json_bytes: bytes | None = None
    binary_chunks: list[bytes] = []
    offset = 12
    while offset + 8 <= len(payload):
        chunk_length, chunk_type = struct.unpack_from("<II", payload, offset)
        offset += 8
        chunk = payload[offset:offset + chunk_length]
        audit.require(len(chunk) == chunk_length, "truncated GLB chunk")
        offset += chunk_length
        if chunk_type == JSON_CHUNK:
            audit.require(json_bytes is None, "multiple JSON chunks")
            json_bytes = chunk
        elif chunk_type == BIN_CHUNK:
            binary_chunks.append(chunk)
    audit.require(offset == len(payload), "GLB chunk table does not end at file length")
    audit.require(json_bytes is not None, "missing JSON chunk")
    if json_bytes is None:
        return {}, []
    document = json.loads(json_bytes.rstrip(b"\x00 \t\r\n").decode("utf-8"))
    audit.require(document.get("asset", {}).get("version") == "2.0", "asset.version is not 2.0")

    buffers: list[bytes] = []
    bin_cursor = 0
    for index, descriptor in enumerate(document.get("buffers", [])):
        uri = descriptor.get("uri")
        if uri:
            data = read_uri(path.parent, uri)
        else:
            audit.require(bin_cursor < len(binary_chunks), f"buffer {index} has no BIN chunk")
            data = binary_chunks[bin_cursor] if bin_cursor < len(binary_chunks) else b""
            bin_cursor += 1
        requested = int(descriptor.get("byteLength", len(data)))
        audit.require(len(data) >= requested,
                      f"buffer {index} has {len(data)} bytes, expected at least {requested}")
        buffers.append(data)
    return document, buffers


def read_uri(base: Path, uri: str) -> bytes:
    if uri.startswith("data:"):
        header, encoded = uri.split(",", 1)
        return base64.b64decode(encoded) if ";base64" in header else encoded.encode()
    return (base / uri).read_bytes()


def normalized_component(value: int | float, component_type: int, normalized: bool) -> float:
    if not normalized or component_type == 5126:
        return float(value)
    _, _, signed, divisor = COMPONENTS[component_type]
    if signed:
        return max(float(value) / divisor, -1.0)
    return float(value) / divisor


def view_values(document: dict[str, Any], buffers: list[bytes], view_index: int,
                relative_offset: int, count: int, component_type: int, width: int,
                normalized: bool, audit: Audit, context: str) -> list[tuple[int | float, ...]]:
    views = document.get("bufferViews", [])
    audit.require(0 <= view_index < len(views), f"{context} has invalid bufferView {view_index}")
    if not 0 <= view_index < len(views):
        return []
    audit.require(component_type in COMPONENTS,
                  f"{context} component type {component_type} unsupported")
    if component_type not in COMPONENTS:
        return []
    view = views[view_index]
    fmt, component_bytes, _, _ = COMPONENTS[component_type]
    packed_bytes = component_bytes * width
    stride = int(view.get("byteStride", packed_bytes))
    audit.require(stride >= packed_bytes,
                  f"{context} stride {stride} < packed size {packed_bytes}")
    buffer_index = int(view.get("buffer", 0))
    audit.require(0 <= buffer_index < len(buffers), f"{context} buffer index is invalid")
    if not 0 <= buffer_index < len(buffers):
        return []
    view_start = int(view.get("byteOffset", 0))
    view_end = view_start + int(view.get("byteLength", 0))
    start = view_start + relative_offset
    unpack_format = "<" + fmt * width
    values: list[tuple[int | float, ...]] = []
    for item in range(count):
        item_offset = start + item * stride
        in_bounds = (item_offset >= view_start and
                     item_offset + packed_bytes <= view_end and
                     item_offset + packed_bytes <= len(buffers[buffer_index]))
        audit.require(in_bounds, f"{context} overruns its bufferView at element {item}")
        if not in_bounds:
            break
        raw = struct.unpack_from(unpack_format, buffers[buffer_index], item_offset)
        if normalized:
            values.append(tuple(normalized_component(value, component_type, True) for value in raw))
        else:
            values.append(raw)
    return values


def accessor_values(document: dict[str, Any], buffers: list[bytes], index: int,
                    audit: Audit) -> list[tuple[int | float, ...]]:
    accessors = document.get("accessors", [])
    audit.require(0 <= index < len(accessors), f"invalid accessor {index}")
    if not 0 <= index < len(accessors):
        return []
    accessor = accessors[index]
    component_type = int(accessor.get("componentType", -1))
    value_type = accessor.get("type", "")
    audit.require(component_type in COMPONENTS,
                  f"accessor {index} component type {component_type} unsupported")
    audit.require(value_type in TYPE_WIDTH,
                  f"accessor {index} type {value_type!r} unsupported")
    if component_type not in COMPONENTS or value_type not in TYPE_WIDTH:
        return []
    width = TYPE_WIDTH[value_type]
    count = int(accessor.get("count", 0))
    normalized = bool(accessor.get("normalized", False))
    view_index = accessor.get("bufferView")
    if view_index is None:
        values: list[tuple[int | float, ...]] = [tuple(0.0 for _ in range(width)) for _ in range(count)]
    else:
        values = view_values(
            document, buffers, int(view_index), int(accessor.get("byteOffset", 0)),
            count, component_type, width, normalized, audit, f"accessor {index}")

    sparse = accessor.get("sparse")
    if sparse is not None:
        sparse_count = int(sparse.get("count", 0))
        audit.require(0 <= sparse_count <= count,
                      f"accessor {index} sparse count {sparse_count} exceeds accessor count {count}")
        indices_descriptor = sparse.get("indices", {})
        sparse_index_type = int(indices_descriptor.get("componentType", -1))
        audit.require(sparse_index_type in (5121, 5123, 5125),
                      f"accessor {index} sparse index type {sparse_index_type} is invalid")
        indices = view_values(
            document, buffers, int(indices_descriptor.get("bufferView", -1)),
            int(indices_descriptor.get("byteOffset", 0)), sparse_count,
            sparse_index_type, 1, False, audit, f"accessor {index} sparse indices")
        values_descriptor = sparse.get("values", {})
        replacements = view_values(
            document, buffers, int(values_descriptor.get("bufferView", -1)),
            int(values_descriptor.get("byteOffset", 0)), sparse_count,
            component_type, width, normalized, audit, f"accessor {index} sparse values")
        sparse_indices = [int(row[0]) for row in indices]
        audit.require(sparse_indices == sorted(set(sparse_indices)),
                      f"accessor {index} sparse indices are not unique and increasing")
        audit.require(len(indices) == sparse_count and len(replacements) == sparse_count,
                      f"accessor {index} sparse payload count is incomplete")
        for sparse_index, replacement in zip(sparse_indices, replacements):
            audit.require(0 <= sparse_index < count,
                          f"accessor {index} sparse index {sparse_index} is out of range")
            if 0 <= sparse_index < len(values):
                values[sparse_index] = replacement

    # glTF accessor min/max describe the fully materialized values, including
    # the implicit zero base plus sparse replacements used by morph targets.
    # Validate float bounds here; integer normalized accessors encode their
    # extrema in component space and are intentionally left to slot checks.
    if component_type == 5126 and len(values) == count and values:
        computed_min = [min(float(row[component]) for row in values) for component in range(width)]
        computed_max = [max(float(row[component]) for row in values) for component in range(width)]
        for bound_name, computed in (("min", computed_min), ("max", computed_max)):
            declared = accessor.get(bound_name)
            if declared is None:
                continue
            audit.require(len(declared) == width,
                          f"accessor {index} declared {bound_name} width differs from {value_type}")
            for component, (declared_value, computed_value) in enumerate(zip(declared, computed)):
                tolerance = max(1e-7, abs(float(declared_value)) * 1e-6)
                audit.require(abs(float(declared_value) - computed_value) <= tolerance,
                              f"accessor {index} declared {bound_name}[{component}] {declared_value} != materialized {computed_value}")
    return values


def image_payload(path: Path, document: dict[str, Any], buffers: list[bytes],
                  image: dict[str, Any], audit: Audit) -> bytes:
    if "uri" in image:
        return read_uri(path.parent, image["uri"])
    view_index = image.get("bufferView")
    views = document.get("bufferViews", [])
    audit.require(view_index is not None and 0 <= int(view_index) < len(views),
                  "embedded image has invalid bufferView")
    if view_index is None or not 0 <= int(view_index) < len(views):
        return b""
    view = views[int(view_index)]
    buffer_index = int(view.get("buffer", 0))
    start = int(view.get("byteOffset", 0))
    length = int(view.get("byteLength", 0))
    return buffers[buffer_index][start:start + length]


def image_dimensions(data: bytes) -> tuple[int, int] | None:
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        return struct.unpack_from(">II", data, 16)
    if data.startswith(b"\xff\xd8"):
        offset = 2
        while offset + 9 < len(data):
            if data[offset] != 0xFF:
                offset += 1
                continue
            marker = data[offset + 1]
            offset += 2
            if marker in (0xD8, 0xD9):
                continue
            if offset + 2 > len(data):
                break
            length = struct.unpack_from(">H", data, offset)[0]
            if marker in range(0xC0, 0xC4) and length >= 7:
                height, width = struct.unpack_from(">HH", data, offset + 3)
                return width, height
            offset += length
    return None


def skin_for_mesh(document: dict[str, Any]) -> dict[int, set[int]]:
    result: dict[int, set[int]] = collections.defaultdict(set)
    for node in document.get("nodes", []):
        if "mesh" in node and "skin" in node:
            result[int(node["mesh"])].add(int(node["skin"]))
    return result


def audit_export(path: Path, args: argparse.Namespace) -> tuple[dict[str, Any], Audit]:
    audit = Audit()
    document, buffers = parse_glb(path, audit)
    if not document:
        return {}, audit

    materials = document.get("materials", [])
    material_use: collections.Counter[int] = collections.Counter()
    surface_rows: list[dict[str, Any]] = []
    unique_position_accessors: set[int] = set()
    vertex_references = 0
    triangles = 0
    max_influences = 0
    worst_weight_error = 0.0
    weighted_vertices = 0
    mesh_skins = skin_for_mesh(document)
    used_slots_by_skin: dict[int, set[int]] = collections.defaultdict(set)
    total_morph_target_sets = 0
    maximum_morph_targets = 0
    morph_rows: list[dict[str, Any]] = []
    morph_max_abs_by_name: dict[str, float] = collections.defaultdict(float)

    for mesh_index, mesh in enumerate(document.get("meshes", [])):
        mesh_target_names = mesh.get("extras", {}).get("targetNames", [])
        for primitive_index, primitive in enumerate(mesh.get("primitives", [])):
            attributes = primitive.get("attributes", {})
            position_accessor = attributes.get("POSITION")
            audit.require(position_accessor is not None,
                          f"mesh {mesh_index} primitive {primitive_index} has no POSITION")
            if position_accessor is None:
                continue
            position_accessor = int(position_accessor)
            position_count = int(document["accessors"][position_accessor].get("count", 0))
            unique_position_accessors.add(position_accessor)
            vertex_references += position_count
            mode = int(primitive.get("mode", TRIANGLE_MODE))
            audit.require(mode == TRIANGLE_MODE,
                          f"mesh {mesh_index} primitive {primitive_index} mode {mode} is not TRIANGLES")
            index_accessor = primitive.get("indices")
            primitive_indices = (int(document["accessors"][int(index_accessor)].get("count", 0))
                                 if index_accessor is not None else position_count)
            audit.require(primitive_indices % 3 == 0,
                          f"mesh {mesh_index} primitive {primitive_index} index count is not divisible by 3")
            if mode == TRIANGLE_MODE:
                triangles += primitive_indices // 3

            material_index = int(primitive.get("material", -1))
            if material_index >= 0:
                audit.require(material_index < len(materials),
                              f"mesh {mesh_index} primitive {primitive_index} has invalid material")
                material_use[material_index] += 1
            surface_rows.append({
                "mesh": mesh_index,
                "mesh_name": mesh.get("name", f"mesh_{mesh_index}"),
                "primitive": primitive_index,
                "vertices": position_count,
                "triangles": primitive_indices // 3 if mode == TRIANGLE_MODE else 0,
                "material_index": material_index,
                "material_name": (materials[material_index].get("name", f"material_{material_index}")
                                  if 0 <= material_index < len(materials) else None),
            })

            target_count = len(primitive.get("targets", []))
            total_morph_target_sets += target_count
            maximum_morph_targets = max(maximum_morph_targets, target_count)
            if mesh_target_names:
                audit.require(len(mesh_target_names) == target_count,
                              f"mesh {mesh_index} has {len(mesh_target_names)} target names but primitive {primitive_index} has {target_count} targets")
            for target_index, target in enumerate(primitive.get("targets", [])):
                target_name = (str(mesh_target_names[target_index])
                               if target_index < len(mesh_target_names)
                               else f"target_{target_index}")
                audit.require("POSITION" in target,
                              f"mesh {mesh_index} primitive {primitive_index} morph {target_name} lacks POSITION deltas")
                semantic_rows: dict[str, dict[str, Any]] = {}
                for semantic, accessor_index_value in target.items():
                    audit.require(semantic in ("POSITION", "NORMAL", "TANGENT"),
                                  f"mesh {mesh_index} primitive {primitive_index} morph {target_name} has invalid semantic {semantic}")
                    accessor_index = int(accessor_index_value)
                    accessors = document.get("accessors", [])
                    audit.require(0 <= accessor_index < len(accessors),
                                  f"mesh {mesh_index} primitive {primitive_index} morph {target_name} has invalid accessor {accessor_index}")
                    if not 0 <= accessor_index < len(accessors):
                        continue
                    descriptor = accessors[accessor_index]
                    audit.require(int(descriptor.get("count", 0)) == position_count,
                                  f"mesh {mesh_index} primitive {primitive_index} morph {target_name} {semantic} count differs from POSITION")
                    audit.require(descriptor.get("type") == "VEC3",
                                  f"mesh {mesh_index} primitive {primitive_index} morph {target_name} {semantic} is not VEC3")
                    audit.require(int(descriptor.get("componentType", -1)) == 5126,
                                  f"mesh {mesh_index} primitive {primitive_index} morph {target_name} {semantic} is not FLOAT")
                    values = accessor_values(document, buffers, accessor_index, audit)
                    finite = all(math.isfinite(float(component)) for row in values for component in row)
                    audit.require(finite,
                                  f"mesh {mesh_index} primitive {primitive_index} morph {target_name} {semantic} has non-finite deltas")
                    max_abs = max((abs(float(component)) for row in values for component in row), default=0.0)
                    component_min = [min((float(row[component]) for row in values), default=0.0)
                                     for component in range(3)]
                    component_max = [max((float(row[component]) for row in values), default=0.0)
                                     for component in range(3)]
                    nonzero_rows = sum(
                        1 for row in values
                        if any(abs(float(component)) > args.morph_delta_epsilon for component in row)
                    )
                    semantic_rows[semantic] = {
                        "accessor": accessor_index,
                        "count": len(values),
                        "max_abs_delta": max_abs,
                        "component_min": component_min,
                        "component_max": component_max,
                        "nonzero_rows": nonzero_rows,
                    }
                    if semantic == "POSITION":
                        morph_max_abs_by_name[target_name] = max(morph_max_abs_by_name[target_name], max_abs)
                morph_rows.append({
                    "mesh": mesh_index,
                    "mesh_name": mesh.get("name", f"mesh_{mesh_index}"),
                    "primitive": primitive_index,
                    "target_index": target_index,
                    "target_name": target_name,
                    "semantics": semantic_rows,
                })

            for semantic in ("NORMAL", "TANGENT", "TEXCOORD_0"):
                audit.require(semantic in attributes,
                              f"mesh {mesh_index} primitive {primitive_index} lacks {semantic}")

            is_skinned = mesh_index in mesh_skins
            if not is_skinned:
                continue
            audit.require("JOINTS_0" in attributes and "WEIGHTS_0" in attributes,
                          f"skinned mesh {mesh_index} primitive {primitive_index} lacks JOINTS_0/WEIGHTS_0")
            audit.require("JOINTS_1" not in attributes and "WEIGHTS_1" not in attributes,
                          f"skinned mesh {mesh_index} primitive {primitive_index} exports more than four influence slots")
            if "JOINTS_0" not in attributes or "WEIGHTS_0" not in attributes:
                continue
            joints = accessor_values(document, buffers, int(attributes["JOINTS_0"]), audit)
            weights = accessor_values(document, buffers, int(attributes["WEIGHTS_0"]), audit)
            audit.require(len(joints) == position_count and len(weights) == position_count,
                          f"mesh {mesh_index} primitive {primitive_index} skin accessor counts differ from POSITION")
            for vertex_index, (joint_row, weight_row) in enumerate(zip(joints, weights)):
                positive = [(int(joint), float(weight)) for joint, weight in zip(joint_row, weight_row)
                            if float(weight) > args.weight_epsilon]
                influence_count = len(positive)
                max_influences = max(max_influences, influence_count)
                audit.require(0 < influence_count <= args.max_influences,
                              f"mesh {mesh_index} primitive {primitive_index} vertex {vertex_index} has {influence_count} influences")
                weight_sum = sum(weight for _, weight in positive)
                error = abs(weight_sum - 1.0)
                worst_weight_error = max(worst_weight_error, error)
                audit.require(error <= args.weight_tolerance,
                              f"mesh {mesh_index} primitive {primitive_index} vertex {vertex_index} weight sum {weight_sum:.8f}")
                weighted_vertices += 1
                for skin_index in mesh_skins[mesh_index]:
                    used_slots_by_skin[skin_index].update(joint for joint, _ in positive)

    unique_accessor_vertices = sum(int(document["accessors"][index].get("count", 0))
                                   for index in unique_position_accessors)

    skin_rows: list[dict[str, Any]] = []
    nodes = document.get("nodes", [])
    for skin_index, skin in enumerate(document.get("skins", [])):
        joint_nodes = [int(value) for value in skin.get("joints", [])]
        used_slots = used_slots_by_skin.get(skin_index, set())
        invalid_slots = sorted(slot for slot in used_slots if not 0 <= slot < len(joint_nodes))
        audit.require(not invalid_slots, f"skin {skin_index} references invalid joint slots {invalid_slots}")
        used_names = [nodes[joint_nodes[slot]].get("name", f"node_{joint_nodes[slot]}")
                      for slot in sorted(used_slots) if 0 <= slot < len(joint_nodes)]
        unused_names = [nodes[node_index].get("name", f"node_{node_index}")
                        for slot, node_index in enumerate(joint_nodes) if slot not in used_slots]
        disallowed_unused = [name for name in unused_names if name not in args.allow_unused_bone]
        if disallowed_unused and not args.allow_unused_bones:
            audit.errors.append(f"skin {skin_index} has unused deform joints: {', '.join(disallowed_unused)}")
        skin_rows.append({
            "skin": skin_index,
            "name": skin.get("name", f"skin_{skin_index}"),
            "joint_count": len(joint_nodes),
            "used_joint_count": len(used_names),
            "used_joints": used_names,
            "unused_joints": unused_names,
            "allowed_unweighted_structural_joints": [
                name for name in unused_names if name in args.allow_unused_bone
            ],
        })

    if args.expect_joints is not None:
        audit.require(len(document.get("skins", [])) > 0, "no skins exported")
        for row in skin_rows:
            audit.require(row["joint_count"] == args.expect_joints,
                          f"skin {row['skin']} has {row['joint_count']} joints, expected {args.expect_joints}")

    normal_maps: list[dict[str, Any]] = []
    textures = document.get("textures", [])
    images = document.get("images", [])
    for material_index, material in enumerate(materials):
        normal = material.get("normalTexture")
        if normal is None:
            continue
        texture_index = int(normal.get("index", -1))
        audit.require(0 <= texture_index < len(textures),
                      f"material {material_index} has invalid normal texture")
        if not 0 <= texture_index < len(textures):
            continue
        image_index = int(textures[texture_index].get("source", -1))
        audit.require(0 <= image_index < len(images),
                      f"normal texture {texture_index} has invalid image source")
        if not 0 <= image_index < len(images):
            continue
        data = image_payload(path, document, buffers, images[image_index], audit)
        dimensions = image_dimensions(data)
        audit.require(dimensions is not None,
                      f"normal image {image_index} dimensions are not readable PNG/JPEG")
        if dimensions is None:
            continue
        width, height = dimensions
        audit.require(width >= args.min_normal_map_size and height >= args.min_normal_map_size,
                      f"normal image {image_index} is {width}x{height}, below {args.min_normal_map_size}")
        normal_maps.append({
            "material_index": material_index,
            "material_name": material.get("name", f"material_{material_index}"),
            "texture_index": texture_index,
            "image_index": image_index,
            "dimensions": [width, height],
        })
    if args.require_normal_maps:
        audit.require(bool(normal_maps), "no material normal maps exported")
    if args.expect_normal_maps is not None:
        audit.require(len(normal_maps) == args.expect_normal_maps,
                      f"normal map bindings {len(normal_maps)} != expected {args.expect_normal_maps}")

    audit.require(maximum_morph_targets >= args.min_morph_targets,
                  f"maximum morph targets per primitive {maximum_morph_targets} < required {args.min_morph_targets}")
    for expected_name in args.expect_morph_name:
        audit.require(expected_name in morph_max_abs_by_name,
                      f"expected morph target {expected_name!r} is absent")
        audit.require(morph_max_abs_by_name.get(expected_name, 0.0) > args.morph_delta_epsilon,
                      f"expected morph target {expected_name!r} has no position delta above {args.morph_delta_epsilon}")

    if args.expect_surfaces is not None:
        audit.require(len(surface_rows) == args.expect_surfaces,
                      f"mesh primitives/surfaces {len(surface_rows)} != expected {args.expect_surfaces}")
    if args.expect_materials_used is not None:
        audit.require(len(material_use) == args.expect_materials_used,
                      f"used materials {len(material_use)} != expected {args.expect_materials_used}")

    shared_materials = [
        {"index": index, "name": materials[index].get("name", f"material_{index}"), "surface_uses": uses}
        for index, uses in sorted(material_use.items()) if uses > 1
    ]
    unique_surface_materials = [
        {"index": index, "name": materials[index].get("name", f"material_{index}")}
        for index, uses in sorted(material_use.items()) if uses == 1
    ]

    report = {
        "path": str(path.resolve()),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "file_bytes": path.stat().st_size,
        "meshes": len(document.get("meshes", [])),
        "mesh_primitives": len(surface_rows),
        "vertex_references_across_primitives": vertex_references,
        "unique_position_accessor_vertices": unique_accessor_vertices,
        "triangles": triangles,
        "skins": skin_rows,
        "weighted_vertices_checked": weighted_vertices,
        "maximum_nonzero_influences": max_influences,
        "worst_normalized_weight_sum_error": worst_weight_error,
        "materials_declared": len(materials),
        "materials_used": len(material_use),
        "unique_per_surface_materials": unique_surface_materials,
        "shared_across_surface_materials": shared_materials,
        "surfaces": surface_rows,
        "normal_maps": normal_maps,
        "maximum_morph_targets_per_primitive": maximum_morph_targets,
        "morph_target_sets_across_primitives": total_morph_target_sets,
        "morph_names": sorted(morph_max_abs_by_name),
        "morph_max_abs_position_delta_by_name": dict(sorted(morph_max_abs_by_name.items())),
        "morph_targets": morph_rows,
        "warnings": audit.warnings,
        "errors": audit.errors,
    }
    return report, audit


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("glb", type=Path)
    result.add_argument("--expect-joints", type=int, default=20)
    result.add_argument("--max-influences", type=int, default=4)
    result.add_argument("--weight-epsilon", type=float, default=1e-7)
    result.add_argument("--weight-tolerance", type=float, default=1e-4)
    result.add_argument("--allow-unused-bones", action="store_true")
    result.add_argument("--allow-unused-bone", action="append", default=["root"],
                        help="joint allowed to organize the hierarchy without direct vertex weights; repeatable")
    result.add_argument("--require-normal-maps", action="store_true")
    result.add_argument("--min-normal-map-size", type=int, default=1)
    result.add_argument("--expect-normal-maps", type=int)
    result.add_argument("--expect-surfaces", type=int)
    result.add_argument("--expect-materials-used", type=int)
    result.add_argument("--min-morph-targets", type=int, default=0)
    result.add_argument("--expect-morph-name", action="append", default=[])
    result.add_argument("--morph-delta-epsilon", type=float, default=1e-8)
    return result


def main() -> int:
    args = parser().parse_args()
    if not args.glb.is_file():
        print(f"GLOAM_GLB_EXPORT_CHECK_FAIL missing file: {args.glb}", file=sys.stderr)
        return 2
    report, audit = audit_export(args.glb, args)
    print("GLOAM_GLB_EXPORT_REPORT " + json.dumps(report, sort_keys=True, separators=(",", ":")))
    if audit.errors:
        for error in audit.errors:
            print("FAIL " + error, file=sys.stderr)
        print(f"GLOAM_GLB_EXPORT_CHECK_FAIL errors={len(audit.errors)}", file=sys.stderr)
        return 1
    print("GLOAM_GLB_EXPORT_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
