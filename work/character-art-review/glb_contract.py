#!/usr/bin/env python3
"""Strict static export gate for the non-default Gloam Vigil character-art candidate."""

from __future__ import annotations

import importlib.util
import json
import math
from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = PROJECT_ROOT / "actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"
CHECKER_PATH = PROJECT_ROOT / "work/character-quality-benchmark/check_glb_export.py"
MAX_TRIANGLES = 110_000
FACE_NODE_NAME = "GV2_Face"
FACE_SKIN_MATERIAL = "MAT_GV2_Skin"
DARK_SCALP_MAX_LUMINANCE = 0.12
LIGHT_FACE_MIN_LUMINANCE = 0.85
MIN_FACE_COLOR_LUMINANCE_RANGE = 0.50
SCALP_MIN_Y = 2.065
LIGHT_FACE_MIN_Y = 1.90
LIGHT_FACE_MAX_Y = 2.05


def load_checker():
    spec = importlib.util.spec_from_file_location("gloam_glb_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load checker: {CHECKER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def audit_face_skin_vertex_colors(
    checker,
    audit,
    candidate_path: Path = CANDIDATE,
) -> dict[str, object]:
    """Require the exported face-skin primitive's real COLOR_0 payload.

    Presence alone is insufficient: Blender can emit an all-white fallback when
    material-based vertex-color inference misses the source `Col` attribute.
    The neutral face and close-cropped scalp must both survive in the GLB values.
    """

    document, buffers = checker.parse_glb(candidate_path, audit)
    if not document:
        return {}

    face_nodes = [
        node
        for node in document.get("nodes", [])
        if node.get("name") == FACE_NODE_NAME and "mesh" in node and "skin" in node
    ]
    audit.require(
        len(face_nodes) == 1,
        f"expected exactly one skinned {FACE_NODE_NAME} node, found {len(face_nodes)}",
    )
    if len(face_nodes) != 1:
        return {"face_nodes_found": len(face_nodes)}

    mesh_index = int(face_nodes[0]["mesh"])
    meshes = document.get("meshes", [])
    audit.require(0 <= mesh_index < len(meshes), f"{FACE_NODE_NAME} has invalid mesh {mesh_index}")
    if not 0 <= mesh_index < len(meshes):
        return {"mesh_index": mesh_index}

    materials = document.get("materials", [])
    skin_primitives: list[tuple[int, dict[str, object]]] = []
    for primitive_index, primitive in enumerate(meshes[mesh_index].get("primitives", [])):
        material_index = int(primitive.get("material", -1))
        material_name = (
            materials[material_index].get("name")
            if 0 <= material_index < len(materials)
            else None
        )
        if material_name == FACE_SKIN_MATERIAL:
            skin_primitives.append((primitive_index, primitive))
    audit.require(
        len(skin_primitives) == 1,
        f"expected exactly one {FACE_NODE_NAME} {FACE_SKIN_MATERIAL} primitive, found {len(skin_primitives)}",
    )
    if len(skin_primitives) != 1:
        return {"mesh_index": mesh_index, "skin_primitives_found": len(skin_primitives)}

    primitive_index, primitive = skin_primitives[0]
    attributes = primitive.get("attributes", {})
    color_accessor_value = attributes.get("COLOR_0")
    audit.require(
        color_accessor_value is not None,
        f"{FACE_NODE_NAME} {FACE_SKIN_MATERIAL} primitive lacks COLOR_0",
    )
    if color_accessor_value is None:
        return {"mesh_index": mesh_index, "primitive": primitive_index, "color_accessor": None}

    accessors = document.get("accessors", [])
    color_accessor = int(color_accessor_value)
    audit.require(0 <= color_accessor < len(accessors), f"face COLOR_0 accessor {color_accessor} is invalid")
    if not 0 <= color_accessor < len(accessors):
        return {"mesh_index": mesh_index, "primitive": primitive_index, "color_accessor": color_accessor}

    descriptor = accessors[color_accessor]
    position_accessor = int(attributes.get("POSITION", -1))
    audit.require(
        0 <= position_accessor < len(accessors),
        f"face POSITION accessor {position_accessor} is invalid",
    )
    position_count = (
        int(accessors[position_accessor].get("count", 0))
        if 0 <= position_accessor < len(accessors)
        else 0
    )
    color_count = int(descriptor.get("count", 0))
    color_type = str(descriptor.get("type", ""))
    component_type = int(descriptor.get("componentType", -1))
    normalized = bool(descriptor.get("normalized", False))
    audit.require(color_count == position_count, "face COLOR_0 count differs from POSITION")
    audit.require(color_type in ("VEC3", "VEC4"), f"face COLOR_0 type {color_type!r} is not VEC3/VEC4")
    audit.require(component_type in (5121, 5123, 5126), f"face COLOR_0 component type {component_type} is invalid")
    if component_type in (5121, 5123):
        audit.require(normalized, "integer face COLOR_0 accessor is not normalized")

    positions = (
        checker.accessor_values(document, buffers, position_accessor, audit)
        if 0 <= position_accessor < len(accessors)
        else []
    )
    values = checker.accessor_values(document, buffers, color_accessor, audit)
    xyz_values = [tuple(float(component) for component in row[:3]) for row in positions if len(row) >= 3]
    rgb_values = [tuple(float(component) for component in row[:3]) for row in values if len(row) >= 3]
    positions_finite = all(math.isfinite(component) for row in xyz_values for component in row)
    finite = all(math.isfinite(component) for row in rgb_values for component in row)
    in_range = all(-1.0e-6 <= component <= 1.0 + 1.0e-6 for row in rgb_values for component in row)
    audit.require(len(xyz_values) == position_count and position_count > 0, "face POSITION payload is incomplete")
    audit.require(positions_finite, "face POSITION contains non-finite values")
    audit.require(len(rgb_values) == color_count and color_count > 0, "face COLOR_0 payload is incomplete")
    audit.require(finite, "face COLOR_0 contains non-finite values")
    audit.require(in_range, "face COLOR_0 contains values outside normalized 0..1")

    luminances = [0.2126 * row[0] + 0.7152 * row[1] + 0.0722 * row[2] for row in rgb_values]
    position_min = [min((row[axis] for row in xyz_values), default=0.0) for axis in range(3)]
    position_max = [max((row[axis] for row in xyz_values), default=0.0) for axis in range(3)]
    # This authored GLB is Y-up and the face node has an identity local transform.
    # Keep the anatomical scalp threshold inside the decoded face POSITION bounds
    # so a rotated, rescaled, or unrelated mesh cannot satisfy the color witness.
    face_node_has_identity_transform = not any(
        key in face_nodes[0] for key in ("matrix", "rotation", "scale", "translation")
    )
    audit.require(face_node_has_identity_transform, f"{FACE_NODE_NAME} must retain its identity local transform")
    audit.require(
        position_min[1] < LIGHT_FACE_MIN_Y < LIGHT_FACE_MAX_Y < SCALP_MIN_Y < position_max[1],
        "face POSITION Y bounds do not enclose the expected facial and scalp bands",
    )
    luminance_min = min(luminances, default=0.0)
    luminance_max = max(luminances, default=0.0)
    paired_count = min(len(xyz_values), len(luminances))
    dark_samples = sum(
        luminances[index] <= DARK_SCALP_MAX_LUMINANCE and xyz_values[index][1] >= SCALP_MIN_Y
        for index in range(paired_count)
    )
    light_samples = sum(
        luminances[index] >= LIGHT_FACE_MIN_LUMINANCE
        and LIGHT_FACE_MIN_Y <= xyz_values[index][1] <= LIGHT_FACE_MAX_Y
        for index in range(paired_count)
    )
    unique_rgb_values = len({tuple(round(component, 6) for component in row) for row in rgb_values})
    audit.require(
        dark_samples > 0,
        f"face COLOR_0 has no dark scalp values on POSITION vertices with Y >= {SCALP_MIN_Y:.3f}",
    )
    audit.require(
        light_samples > 0,
        "face COLOR_0 has no light neutral-face values in the expected facial Y band "
        f"{LIGHT_FACE_MIN_Y:.2f}..{LIGHT_FACE_MAX_Y:.2f}",
    )
    audit.require(
        luminance_max - luminance_min >= MIN_FACE_COLOR_LUMINANCE_RANGE,
        f"face COLOR_0 is not meaningfully nonuniform: luminance range {luminance_max - luminance_min:.6f}",
    )
    return {
        "face_node": FACE_NODE_NAME,
        "mesh_index": mesh_index,
        "primitive": primitive_index,
        "material": FACE_SKIN_MATERIAL,
        "color_accessor": color_accessor,
        "position_accessor": position_accessor,
        "count": color_count,
        "type": color_type,
        "component_type": component_type,
        "normalized": normalized,
        "luminance_min": luminance_min,
        "luminance_max": luminance_max,
        "luminance_range": luminance_max - luminance_min,
        "position_min": position_min,
        "position_max": position_max,
        "face_node_identity_transform": face_node_has_identity_transform,
        "scalp_min_y": SCALP_MIN_Y,
        "dark_scalp_spatial_samples": dark_samples,
        "light_face_y_band": [LIGHT_FACE_MIN_Y, LIGHT_FACE_MAX_Y],
        "light_face_spatial_samples": light_samples,
        "unique_rgb_values": unique_rgb_values,
    }


def main() -> int:
    if not CANDIDATE.is_file():
        print(f"GLOAM_CHARACTER_ART_GLB_CONTRACT_FAIL missing file: {CANDIDATE}", file=sys.stderr)
        return 2
    checker = load_checker()
    args = checker.parser().parse_args(
        [
            str(CANDIDATE),
            "--expect-joints=74",
            "--expect-surfaces=7",
            "--expect-materials-used=5",
            "--require-normal-maps",
            "--min-normal-map-size=1024",
            "--expect-normal-maps=5",
            "--min-morph-targets=4",
            "--expect-morph-name=blink.L",
            "--expect-morph-name=blink.R",
            "--expect-morph-name=brow_inner_raise",
            "--expect-morph-name=jaw_clench",
        ]
    )
    report, audit = checker.audit_export(CANDIDATE, args)
    report["face_skin_vertex_colors"] = audit_face_skin_vertex_colors(checker, audit)
    # The approved allocation has an upper bound but deliberately no minimum:
    # topology quality and runtime deformation matter more than spending tris.
    audit.require(
        report["triangles"] <= MAX_TRIANGLES,
        f"triangles {report['triangles']} exceed approved maximum {MAX_TRIANGLES}",
    )
    print("GLOAM_CHARACTER_ART_GLB_CONTRACT_REPORT " + json.dumps(report, sort_keys=True, separators=(",", ":")))
    if audit.errors:
        for error in audit.errors:
            print("FAIL " + error, file=sys.stderr)
        print(f"GLOAM_CHARACTER_ART_GLB_CONTRACT_FAIL errors={len(audit.errors)}", file=sys.stderr)
        return 1
    print("GLOAM_CHARACTER_ART_GLB_CONTRACT_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
