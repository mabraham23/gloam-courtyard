"""Read-only R7 MCP/PIP/DIP anchor and local skin-weight diagnostic.

The script measures the frozen source bone chains against their influenced
surface vertices.  It reports equal-segment anchor placement, effective
weight-transition centers/widths, retained hand weight, and a coarse palmar
surface profile for joint-location evidence.  It never saves or exports.
"""

from __future__ import annotations

import importlib.util
import json
import math
from pathlib import Path
from statistics import fmean, median

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
MEASURE_PATH = HERE / "measure_hand_axes.py"
spec = importlib.util.spec_from_file_location("measure_hand_axes", MEASURE_PATH)
assert spec is not None and spec.loader is not None
MEASURE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(MEASURE)


def percentile(values: list[float], amount: float) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    position = (len(ordered) - 1) * amount
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] * (upper - position) + ordered[upper] * (position - lower)


def weights_for(body: bpy.types.Object, vertex: bpy.types.MeshVertex) -> dict[str, float]:
    return {
        body.vertex_groups[item.group].name: float(item.weight)
        for item in vertex.groups
        if item.group < len(body.vertex_groups) and item.weight > 1.0e-7
    }


def joint_crossfade(
    records: list[dict[str, object]],
    first: str,
    second: str,
    digit_length: float,
    current_anchor_fraction: float,
) -> dict[str, object]:
    shared = []
    for record in records:
        weights = record["weights"]
        first_weight = weights.get(first, 0.0)
        second_weight = weights.get(second, 0.0)
        if first_weight > 0.02 and second_weight > 0.02:
            shared.append((float(record["s"]), min(first_weight, second_weight)))
    if not shared:
        return {"vertices": 0}
    weight_sum = sum(weight for _s, weight in shared)
    center = sum(s * weight for s, weight in shared) / weight_sum
    strong = [s for s, weight in shared if weight >= 0.10]
    return {
        "vertices": len(shared),
        "weighted_center_fraction": round(center, 6),
        "center_offset_from_rest_anchor_mm": round(
            (center - current_anchor_fraction) * digit_length * 1000.0,
            3,
        ),
        "strong_span_fraction": [round(min(strong), 6), round(max(strong), 6)] if strong else None,
        "strong_span_percent_of_digit": round((max(strong) - min(strong)) * 100.0, 3) if strong else None,
        "strong_span_mm": round((max(strong) - min(strong)) * digit_length * 1000.0, 3) if strong else None,
    }


def palmar_profile(
    records: list[dict[str, object]],
    palm_normal: Vector,
) -> tuple[list[dict[str, object]], dict[str, float]]:
    bins: list[dict[str, object]] = []
    for index in range(32):
        low = index / 32.0
        high = (index + 1) / 32.0
        values = [
            float(record["palmar_offset"])
            for record in records
            if low <= float(record["s"]) < high
            and float(record["digit_weight"]) >= 0.20
        ]
        if len(values) < 3:
            continue
        bins.append({
            "center": round((low + high) * 0.5, 6),
            "vertices": len(values),
            "palmar_p90_mm": round(percentile(values, 0.90) * 1000.0, 4),
            "palmar_median_mm": round(median(values) * 1000.0, 4),
        })
    # A full ring minimum is only supporting evidence: the licensed surface's
    # crease is strongest on one side, and coarse topology makes this noisy.
    minima: dict[str, float] = {}
    for name, low, high in (("pip", 0.32, 0.60), ("dip", 0.60, 0.88)):
        candidates = [row for row in bins if low <= row["center"] <= high]
        if candidates:
            best = min(candidates, key=lambda row: row["palmar_p90_mm"])
            minima[name] = float(best["center"])
    return bins, minima


def main() -> None:
    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    bpy.ops.wm.open_mainfile(filepath=str(MEASURE.SOURCE), load_ui=False, use_scripts=False)
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = bpy.data.objects.get("GV2_Body")
    assert body is not None and body.type == "MESH"
    report: dict[str, object] = {
        "status": "READ_ONLY_DIAGNOSTIC",
        "source_sha256": MEASURE.EXPECTED_SOURCE_SHA256,
        "glb_sha256": MEASURE.EXPECTED_GLB_SHA256,
        "body_vertices": len(body.data.vertices),
        "digits": {},
    }
    for side, sign in MEASURE.SIDES:
        _wrist, _longitudinal, _across, palm_normal = MEASURE.palm_frame(armature, side, sign)
        for finger in MEASURE.FINGERS:
            names = [f"{finger}.{segment:02d}.{side}" for segment in range(1, 4)]
            bones = [armature.data.bones[name] for name in names]
            base = bones[0].head_local.copy()
            tip = bones[-1].tail_local.copy()
            axis = tip - base
            length = axis.length
            unit = axis.normalized()
            planar_digit = (unit - palm_normal * unit.dot(palm_normal)).normalized()
            planar_palm = (_longitudinal - palm_normal * _longitudinal.dot(palm_normal)).normalized()
            adduction_to_palm = math.degrees(math.atan2(
                palm_normal.dot(planar_digit.cross(planar_palm)),
                max(-1.0, min(1.0, planar_digit.dot(planar_palm))),
            ))
            anchors = [base, bones[0].tail_local.copy(), bones[1].tail_local.copy(), tip]
            anchor_fractions = [round((point - base).dot(unit) / length, 6) for point in anchors]
            proposed_anchor_fractions = (0.0, 0.46, 0.76, 1.0)
            proposed_anchors = [base + axis * fraction for fraction in proposed_anchor_fractions]
            segment_lengths = [(anchors[index + 1] - anchors[index]).length for index in range(3)]
            records: list[dict[str, object]] = []
            for vertex in body.data.vertices:
                weights = weights_for(body, vertex)
                digit_weight = sum(weights.get(name, 0.0) for name in names)
                if digit_weight <= 0.01:
                    continue
                offset = vertex.co - base
                s = offset.dot(unit) / length
                center = base + axis * s
                records.append({
                    "index": vertex.index,
                    "s": s,
                    "radial": (vertex.co - center).length,
                    "palmar_offset": (vertex.co - center).dot(palm_normal),
                    "digit_weight": digit_weight,
                    "hand_weight": weights.get(f"hand.{side}", 0.0),
                    "weights": weights,
                })
            assert records, (side, finger)
            palmar_bins, surface_minima = palmar_profile(records, palm_normal)
            distal = [record for record in records if float(record["s"]) >= 0.70]
            worst_distal_hand = max(distal, key=lambda record: float(record["hand_weight"])) if distal else None
            report["digits"][f"{finger}.{side}"] = {
                "bone_anchor_fractions": anchor_fractions,
                "bone_anchor_coordinates_blender": [
                    [round(float(value), 7) for value in point]
                    for point in anchors
                ],
                "proposed_anchor_fractions": proposed_anchor_fractions,
                "proposed_anchor_coordinates_blender": [
                    [round(float(value), 7) for value in point]
                    for point in proposed_anchors
                ],
                "segment_lengths_mm": [round(value * 1000.0, 4) for value in segment_lengths],
                "segment_length_ratios": [round(value / length, 6) for value in segment_lengths],
                "digit_chain_length_mm": round(length * 1000.0, 4),
                "mcp_adduction_to_palm_longitudinal_degrees": round(adduction_to_palm, 4),
                "influenced_vertices": len(records),
                "projection_fraction_range": [
                    round(min(float(record["s"]) for record in records), 6),
                    round(max(float(record["s"]) for record in records), 6),
                ],
                "max_radial_distance_mm": round(max(float(record["radial"]) for record in records) * 1000.0, 4),
                "effective_01_02_crossfade": joint_crossfade(records, names[0], names[1], length, 1.0 / 3.0),
                "effective_02_03_crossfade": joint_crossfade(records, names[1], names[2], length, 2.0 / 3.0),
                "distal_hand_weight_mean": round(fmean(float(record["hand_weight"]) for record in distal), 6) if distal else None,
                "distal_hand_weight_max": round(max(float(record["hand_weight"]) for record in distal), 6) if distal else None,
                "worst_distal_hand_vertex": {
                    "index": int(worst_distal_hand["index"]),
                    "projection_fraction": round(float(worst_distal_hand["s"]), 6),
                    "coordinate_blender": [
                        round(float(value), 7)
                        for value in body.data.vertices[int(worst_distal_hand["index"])].co
                    ],
                    "weights": {
                        name: round(float(value), 7)
                        for name, value in worst_distal_hand["weights"].items()
                    },
                } if worst_distal_hand is not None else None,
                "surface_profile_minima_fraction": surface_minima,
                "surface_profile_bins_measured": len(palmar_bins),
            }
    report["source_sha256_after"] = MEASURE.sha256(MEASURE.SOURCE)
    report["glb_sha256_after"] = MEASURE.sha256(MEASURE.GLB)
    assert report["source_sha256_after"] == MEASURE.EXPECTED_SOURCE_SHA256
    assert report["glb_sha256_after"] == MEASURE.EXPECTED_GLB_SHA256
    print("FINGER_ADDUCTION_SUMMARY " + json.dumps({
        name: values["mcp_adduction_to_palm_longitudinal_degrees"]
        for name, values in report["digits"].items()
    }, sort_keys=True))
    print("FINGER_ANCHOR_WEIGHT_REPORT " + json.dumps(report, sort_keys=True))
    print(
        "FINGER_ANCHOR_WEIGHT_DIAGNOSTIC PASS "
        f"digits={len(report['digits'])} source={MEASURE.EXPECTED_SOURCE_SHA256} "
        f"glb={MEASURE.EXPECTED_GLB_SHA256}"
    )


if __name__ == "__main__":
    main()
