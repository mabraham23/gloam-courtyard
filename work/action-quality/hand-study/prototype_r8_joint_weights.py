"""In-memory R8 joint/weight prototype against the frozen R7 source.

This is not an exporter. It compares the selected compact strike and secure
takedown profiles under runtime-equivalent linear blend skinning before and
after a narrow hypothetical correction:

* replace equal-third digit bones with 46/30/24 percent phalanx spans;
* localize MCP/PIP/DIP weight transitions to their adjacent bones;
* eliminate retained hand weight on the distal shaft.

Only diagnostic PNGs and stdout metrics are produced. The blend and GLB are
hash-checked before and after and are never saved.
"""

from __future__ import annotations

import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


HERE = Path(__file__).resolve().parent
OUTPUT_DIR = HERE / "r8-joint-weight-prototype"
MEASURE_PATH = HERE / "measure_hand_axes.py"
CONTACT_PATH = HERE / "render_contact_variants.py"
V4_DIR = HERE.parents[2] / "actors" / "gloam_vigil" / "v4"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


MEASURE = load_module("measure_hand_axes", MEASURE_PATH)
CONTACT = load_module("render_contact_variants", CONTACT_PATH)
sys.path.insert(0, str(V4_DIR))
RIG = load_module("rig_from_base_diagnostic", V4_DIR / "rig_from_base.py")

PROFILES = {
    "strike": CONTACT.PROFILES["strike-b-compact"],
    "takedown": CONTACT.PROFILES["takedown-b-secure"],
}
PROPOSED_FRACTIONS = (0.0, 0.46, 0.76, 1.0)
PIP_HALF_WIDTH = 0.045
DIP_HALF_WIDTH = 0.040


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    amount = max(0.0, min(1.0, (value - edge0) / max(edge1 - edge0, 1.0e-9)))
    return amount * amount * (3.0 - 2.0 * amount)


def configure_lbs() -> None:
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE":
                modifier.use_deform_preserve_volume = False


def segments(armature: bpy.types.Object) -> dict[str, tuple[Vector, Vector]]:
    return {
        bone.name: (bone.head_local.copy(), bone.tail_local.copy())
        for bone in armature.data.bones
    }


def apply_anchor_prototype(armature: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for side, _sign in MEASURE.SIDES:
        for finger in MEASURE.FINGERS:
            names = [f"{finger}.{segment:02d}.{side}" for segment in range(1, 4)]
            edit_bones = [armature.data.edit_bones[name] for name in names]
            base = edit_bones[0].head.copy()
            tip = edit_bones[-1].tail.copy()
            anchors = [base.lerp(tip, fraction) for fraction in PROPOSED_FRACTIONS]
            for index, bone in enumerate(edit_bones):
                bone.head = anchors[index]
                bone.tail = anchors[index + 1]
    bpy.ops.object.mode_set(mode="OBJECT")
    armature.select_set(False)
    bpy.context.view_layer.update()


def chain_weights(s: float) -> tuple[float, float, float]:
    pip = PROPOSED_FRACTIONS[1]
    dip = PROPOSED_FRACTIONS[2]
    if s < pip - PIP_HALF_WIDTH:
        return (1.0, 0.0, 0.0)
    if s <= pip + PIP_HALF_WIDTH:
        amount = smoothstep(pip - PIP_HALF_WIDTH, pip + PIP_HALF_WIDTH, s)
        return (1.0 - amount, amount, 0.0)
    if s < dip - DIP_HALF_WIDTH:
        return (0.0, 1.0, 0.0)
    if s <= dip + DIP_HALF_WIDTH:
        amount = smoothstep(dip - DIP_HALF_WIDTH, dip + DIP_HALF_WIDTH, s)
        return (0.0, 1.0 - amount, amount)
    return (0.0, 0.0, 1.0)


def apply_weight_prototype(
    body: bpy.types.Object,
    armature: bpy.types.Object,
) -> tuple[dict[int, str], dict[str, object]]:
    points = [vertex.co.copy() for vertex in body.data.vertices]
    current_segments = segments(armature)
    ownership = RIG._hand_region_vertices(body, points, current_segments)
    semantics = RIG._hand_skin_semantics(body, points, current_segments, ownership)
    family_names = {
        f"hand.{side}" for side, _sign in MEASURE.SIDES
    } | {
        f"forearm_twist.{side}" for side, _sign in MEASURE.SIDES
    } | {
        f"{finger}.{segment:02d}.{side}"
        for side, _sign in MEASURE.SIDES
        for finger in MEASURE.FINGERS
        for segment in range(1, 4)
    }
    groups = {name: body.vertex_groups.get(name) for name in family_names}
    assert all(group is not None for group in groups.values())
    indices = sorted(semantics)
    for group in groups.values():
        group.remove(indices)
    maximum_influences = 0
    distal_hand_max = 0.0
    transition_widths_mm: list[float] = []
    for index in indices:
        side, finger, original_digit_amount, wrist_amount = semantics[index]
        names = [f"{finger}.{segment:02d}.{side}" for segment in range(1, 4)]
        base = current_segments[names[0]][0]
        tip = current_segments[names[-1]][1]
        axis = tip - base
        s = (points[index] - base).dot(axis) / max(axis.length_squared, 1.0e-9)
        # Keep the original geodesic ownership in the palm/webbing, but make
        # the actual shaft fully digit-owned by 20% of chain length. This is
        # the narrow correction under test, not a universal spatial gate.
        shaft_amount = smoothstep(0.02, 0.20, s)
        finger_factor = max(float(original_digit_amount), shaft_amount)
        available = 1.0 - float(wrist_amount)
        digit_amount = finger_factor * available
        local = chain_weights(s)
        assigned: dict[str, float] = {
            name: value * digit_amount
            for name, value in zip(names, local, strict=True)
            if value * digit_amount > 1.0e-7
        }
        hand_amount = (1.0 - finger_factor) * available
        if hand_amount > 1.0e-7:
            assigned[f"hand.{side}"] = hand_amount
        if wrist_amount > 1.0e-7:
            assigned[f"forearm_twist.{side}"] = float(wrist_amount)
        total = sum(assigned.values())
        assert total > 0.99999 and total < 1.00001, (index, assigned, total)
        for name, value in assigned.items():
            groups[name].add([index], value / total, "REPLACE")
        maximum_influences = max(maximum_influences, len(assigned))
        if s >= 0.70:
            distal_hand_max = max(distal_hand_max, hand_amount)
        transition_widths_mm.extend(
            [2.0 * PIP_HALF_WIDTH * axis.length * 1000.0, 2.0 * DIP_HALF_WIDTH * axis.length * 1000.0]
        )
    bpy.context.view_layer.update()
    return ownership, {
        "vertices_reweighted": len(indices),
        "maximum_influences": maximum_influences,
        "maximum_distal_hand_weight": round(distal_hand_max, 8),
        "transition_width_mm_range": [
            round(min(transition_widths_mm), 3),
            round(max(transition_widths_mm), 3),
        ],
        "anchor_fractions": PROPOSED_FRACTIONS,
    }


def evaluated_points(body: bpy.types.Object) -> list[Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = body.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
    try:
        return [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
    finally:
        evaluated.to_mesh_clear()


def edge_metrics(
    body: bpy.types.Object,
    ownership: dict[int, str],
    posed: list[Vector],
) -> dict[str, float]:
    ratios: list[float] = []
    deltas: list[float] = []
    for edge in body.data.edges:
        first, second = edge.vertices
        if ownership.get(first) != ownership.get(second) or first not in ownership:
            continue
        rest_length = (body.data.vertices[first].co - body.data.vertices[second].co).length
        if rest_length <= 1.0e-8:
            continue
        posed_length = (posed[first] - posed[second]).length
        ratios.append(posed_length / rest_length)
        deltas.append(abs(posed_length - rest_length))
    ratios.sort()
    deltas.sort()
    return {
        "edges": float(len(ratios)),
        "ratio_p99": round(ratios[int((len(ratios) - 1) * 0.99)], 6),
        "ratio_max": round(ratios[-1], 6),
        "absolute_delta_p99_mm": round(deltas[int((len(deltas) - 1) * 0.99)] * 1000.0, 4),
        "absolute_delta_max_mm": round(deltas[-1] * 1000.0, 4),
    }


def setup_render_body(body: bpy.types.Object) -> bpy.types.Object:
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.hide_render = obj != body
    return CONTACT.setup_scene()


def render_pose(
    armature: bpy.types.Object,
    camera: bpy.types.Object,
    flex: dict[str, Vector],
    opposition: dict[str, Vector],
    frames: dict[str, tuple[Vector, Vector, Vector]],
    label: str,
    profile: dict[str, tuple[int, int, int]],
) -> None:
    MEASURE.reset_pose(armature)
    CONTACT.apply_profile(armature, profile, flex, opposition)
    side = "R"
    hand = armature.data.bones[f"hand.{side}"]
    target = (hand.head_local + hand.tail_local) * 0.5 + Vector((0.0, 0.0, -0.035))
    view = flex[f"middle.01.{side}"].copy()
    if view.y > 0.0:
        view.negate()
    camera.location = target + view.normalized() * 2.0
    CONTACT.look_at(camera, target)
    bpy.context.scene.render.filepath = str(OUTPUT_DIR / f"{label}-curl-plane.png")
    bpy.ops.render.render(write_still=True)


def main() -> None:
    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    expected = [
        OUTPUT_DIR / f"{revision}-{action}-curl-plane.png"
        for revision in ("r7", "r8-prototype")
        for action in PROFILES
    ]
    existing = [path for path in expected if path.exists()]
    if existing:
        raise RuntimeError(f"Preserve prior evidence; refusing to overwrite {existing}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(MEASURE.SOURCE), load_ui=False, use_scripts=False)
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = bpy.data.objects.get("GV2_Body")
    assert body is not None and body.type == "MESH"
    configure_lbs()
    flex, opposition, frames = CONTACT.measured_axes(armature)
    camera = setup_render_body(body)
    current_segments = segments(armature)
    ownership = RIG._hand_region_vertices(body, [vertex.co.copy() for vertex in body.data.vertices], current_segments)
    metrics: dict[str, object] = {"lbs": True, "r7": {}, "r8_prototype": {}}
    for action, profile in PROFILES.items():
        render_pose(armature, camera, flex, opposition, frames, f"r7-{action}", profile)
        metrics["r7"][action] = edge_metrics(body, ownership, evaluated_points(body))

    MEASURE.reset_pose(armature)
    apply_anchor_prototype(armature)
    ownership, correction = apply_weight_prototype(body, armature)
    flex, opposition, _candidate_frames = CONTACT.measured_axes(armature)
    metrics["r8_prototype"]["correction"] = correction
    for action, profile in PROFILES.items():
        render_pose(armature, camera, flex, opposition, frames, f"r8-prototype-{action}", profile)
        metrics["r8_prototype"][action] = edge_metrics(body, ownership, evaluated_points(body))

    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    print("R8_JOINT_WEIGHT_METRICS " + json.dumps(metrics, sort_keys=True))
    print(
        "R8_JOINT_WEIGHT_PROTOTYPE PASS "
        f"images={len(expected)} source={MEASURE.EXPECTED_SOURCE_SHA256} "
        f"glb={MEASURE.EXPECTED_GLB_SHA256}"
    )


if __name__ == "__main__":
    main()
