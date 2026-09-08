"""Read-only control proving the remaining R7 hand gap is MCP fan.

Uses the unchanged R7 anchors and weights, then adds only a bounded .01-bone
rotation about the measured palmar normal. This is diagnostic evidence for the
go/no-go decision; it is not production integration and never saves/exports.
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
OUTPUT_DIR = HERE / "mcp-adduction-v1"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


MEASURE = load_module("measure_hand_axes_adduction", HERE / "measure_hand_axes.py")
CONTACT = load_module("render_contact_variants_adduction", HERE / "render_contact_variants.py")
PROFILES = {
    "strike": CONTACT.PROFILES["strike-b-compact"],
    "takedown": CONTACT.PROFILES["takedown-b-secure"],
}
ADDUCTION_AMOUNTS = {"strike": 0.70, "takedown": 0.45}


def signed_alignment_angle(direction: Vector, target: Vector, axis: Vector) -> float:
    first = (direction - axis * direction.dot(axis)).normalized()
    second = (target - axis * target.dot(axis)).normalized()
    return math.atan2(axis.dot(first.cross(second)), max(-1.0, min(1.0, first.dot(second))))


def apply_adduction(
    armature: bpy.types.Object,
    profile: dict[str, tuple[int, int, int]],
    flex: dict[str, Vector],
    frames: dict[str, tuple[Vector, Vector, Vector]],
    amount: float,
) -> dict[str, float]:
    angles: dict[str, float] = {}
    for side, _sign in MEASURE.SIDES:
        longitudinal, _across, palm_normal = frames[side]
        for finger in ("index", "middle", "ring", "pinky"):
            name = f"{finger}.01.{side}"
            bone = armature.data.bones[name]
            direction = (bone.tail_local - bone.head_local).normalized()
            adduction = signed_alignment_angle(direction, longitudinal, palm_normal) * amount
            flexion = math.radians(profile[finger][0])
            rest = bone.matrix_local.to_quaternion()
            body_delta = Quaternion(palm_normal, adduction) @ Quaternion(flex[name], flexion)
            armature.pose.bones[name].rotation_quaternion = rest.inverted() @ body_delta @ rest
            angles[name] = round(math.degrees(adduction), 4)
    bpy.context.view_layer.update()
    return angles


def tip_spread(
    armature: bpy.types.Object,
    frames: dict[str, tuple[Vector, Vector, Vector]],
    side: str = "R",
) -> dict[str, float]:
    _longitudinal, across, _palm_normal = frames[side]
    positions = {
        finger: MEASURE.posed_tail(armature, f"{finger}.03.{side}")
        for finger in ("index", "middle", "ring", "pinky")
    }
    across_values = [point.dot(across) for point in positions.values()]
    pair_distances = [
        (positions[first] - positions[second]).length
        for index, first in enumerate(positions)
        for second in list(positions)[index + 1:]
    ]
    return {
        "across_span_mm": round((max(across_values) - min(across_values)) * 1000.0, 3),
        "maximum_pair_distance_mm": round(max(pair_distances) * 1000.0, 3),
        "mean_pair_distance_mm": round(sum(pair_distances) / len(pair_distances) * 1000.0, 3),
    }


def render(
    armature: bpy.types.Object,
    camera: bpy.types.Object,
    flex: dict[str, Vector],
    label: str,
) -> None:
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
        OUTPUT_DIR / f"{variant}-{action}-curl-plane.png"
        for variant in ("flex-only", "mcp-adducted")
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
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.hide_render = obj != body
            for modifier in obj.modifiers:
                if modifier.type == "ARMATURE":
                    modifier.use_deform_preserve_volume = False
    camera = CONTACT.setup_scene()
    flex, opposition, frames = CONTACT.measured_axes(armature)
    metrics: dict[str, object] = {}
    for action, profile in PROFILES.items():
        MEASURE.reset_pose(armature)
        CONTACT.apply_profile(armature, profile, flex, opposition)
        metrics[f"flex_only_{action}"] = tip_spread(armature, frames)
        render(armature, camera, flex, f"flex-only-{action}")
        MEASURE.reset_pose(armature)
        CONTACT.apply_profile(armature, profile, flex, opposition)
        angles = apply_adduction(armature, profile, flex, frames, ADDUCTION_AMOUNTS[action])
        metrics[f"mcp_adducted_{action}"] = {
            **tip_spread(armature, frames),
            "angles_degrees": angles,
        }
        render(armature, camera, flex, f"mcp-adducted-{action}")
    assert MEASURE.sha256(MEASURE.SOURCE) == MEASURE.EXPECTED_SOURCE_SHA256
    assert MEASURE.sha256(MEASURE.GLB) == MEASURE.EXPECTED_GLB_SHA256
    print("MCP_ADDUCTION_METRICS " + json.dumps(metrics, sort_keys=True))
    print(
        "MCP_ADDUCTION_CHECK PASS "
        f"images={len(expected)} source={MEASURE.EXPECTED_SOURCE_SHA256} "
        f"glb={MEASURE.EXPECTED_GLB_SHA256}"
    )


if __name__ == "__main__":
    main()
