"""Background-only v4 rest/weight/pose diagnostic.

Run from the repository root with Blender 5.2 LTS::

    Blender --background --disable-autoexec --python \
      work/character-art-v4-rig/validate_rig.py -- --render

It reconstructs the exact frozen level-1 anatomy, performs the production
collar/foot partition, remaps donor eye labels to the project's L=-X contract,
creates the armature, assigns body weights, checks a zero-pose round trip, and
samples a deliberately asymmetric limb bend. Optional renders are diagnostic
only; they are not an art-acceptance or runtime-deformation substitute.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Euler, Vector


REPO = Path(__file__).resolve().parents[2]
V4 = REPO / "actors/gloam_vigil/v4"
V2 = REPO / "actors/gloam_vigil/v2"
OUT = REPO / "work/character-art-v4-rig"
for path in (V4, V2, OUT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from body_from_base import heroic_proportions, load_anatomy  # noqa: E402
from costume import split_anatomy  # noqa: E402
from rig_contract import BONE_NAMES, BONE_BY_NAME  # noqa: E402
from rig_from_base import (  # noqa: E402
    _hand_region_vertices,
    _hand_skin_semantics,
    assign_body_weights,
    create_rig,
)
from diagnose_r2_action_spikes import apply_sample, family  # noqa: E402


def parse_arguments() -> argparse.Namespace:
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    return parser.parse_args(arguments)


def bounds(points: list[Vector]) -> list[list[float]]:
    return [
        [min(point[axis] for point in points), max(point[axis] for point in points)]
        for axis in range(3)
    ]


def evaluated_points(obj: bpy.types.Object) -> list[Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    result = [vertex.co.copy() for vertex in mesh.vertices]
    evaluated.to_mesh_clear()
    return result


def eye_metadata(eyes: list[bpy.types.Object], crown: float) -> dict[str, object]:
    anchors: dict[str, object] = {}
    for eye in eyes:
        points = [eye.matrix_world @ vertex.co for vertex in eye.data.vertices]
        minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
        maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
        center = (minimum + maximum) * 0.5
        # Donor .L/.R is opposite the established runtime X convention.
        side = "L" if center.x < 0.0 else "R"
        anchors[side] = {
            "head": list(center),
            "tail": [center.x, center.y - 0.040, center.z],
        }
    assert set(anchors) == {"L", "R"}
    return {"eye_anchors": anchors, "bounds_max": [0.0, 0.0, crown]}


def set_pose(armature: bpy.types.Object, enabled: bool) -> None:
    for bone in armature.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion.identity()
        bone.location.zero()
        bone.scale = (1.0, 1.0, 1.0)
    if not enabled:
        bpy.context.view_layer.update()
        return
    samples = {
        "upper_arm.L": (0.42, -0.08, -0.18),
        "upper_arm_twist.L": (0.05, -0.13, 0.0),
        "forearm.L": (-1.03, 0.02, 0.0),
        "upper_arm.R": (-0.18, 0.06, 0.12),
        "thigh.R": (0.36, 0.0, 0.05),
        "shin.R": (-0.72, 0.0, 0.0),
        "index.01.L": (0.45, 0.0, 0.0),
        "index.02.L": (0.58, 0.0, 0.0),
        "middle.01.L": (0.35, 0.0, 0.0),
    }
    for name, euler in samples.items():
        # Match the runtime adapter: body/world-aligned driver delta converted
        # into each imported rest basis. Blender pose channels are rest-relative,
        # so unlike Godot we assign only the converted local delta here.
        global_rest = armature.data.bones[name].matrix_local.to_quaternion()
        global_delta = Euler(euler, "XYZ").to_quaternion()
        armature.pose.bones[name].rotation_quaternion = global_rest.inverted() @ global_delta @ global_rest
    bpy.context.view_layer.update()


def set_grapple_finger_pose(armature: bpy.types.Object) -> None:
    set_pose(armature, False)
    curl = 1.14
    for side in ("L", "R"):
        for finger in ("thumb", "index", "middle", "ring", "pinky"):
            character = 0.72 if finger == "thumb" else (0.88 if finger == "pinky" else 1.0)
            for segment in range(1, 4):
                scale = character * (0.72 + float(segment) * 0.12)
                name = f"{finger}.{segment:02d}.{side}"
                rest = armature.data.bones[name].matrix_local.to_quaternion()
                delta = Euler((curl * scale, 0.0, 0.0), "XYZ").to_quaternion()
                armature.pose.bones[name].rotation_quaternion = rest.inverted() @ delta @ rest
    bpy.context.view_layer.update()


def body_vertex_weights(body: bpy.types.Object, index: int) -> dict[str, float]:
    return {
        body.vertex_groups[item.group].name: item.weight
        for item in body.data.vertices[index].groups
        if item.weight > 1.0e-7
    }


def full_body_action_edge_report(
    body: bpy.types.Object,
    armature: bpy.types.Object,
    original: list[Vector],
    state: str,
    progress: float,
) -> dict[str, object]:
    """Strictly reject topology tears over every licensed-body source edge."""
    pose = apply_sample(armature, state, progress)
    deformed = evaluated_points(body)
    rows = []
    for edge in body.data.edges:
        first, second = edge.vertices
        before = (original[first] - original[second]).length
        after = (deformed[first] - deformed[second]).length
        endpoint_weights = [body_vertex_weights(body, index) for index in (first, second)]
        rows.append({
            "indices": [first, second],
            "before_m": before,
            "after_m": after,
            "ratio": after / max(before, 1.0e-9),
            "positions": [[round(value, 6) for value in original[index]] for index in (first, second)],
            "weights": [
                {name: round(value, 6) for name, value in values.items()}
                for values in endpoint_weights
            ],
            "families": [sorted({family(name) for name in values}) for values in endpoint_weights],
        })
    worst_ratio = max(rows, key=lambda row: row["ratio"])
    stretched = [row for row in rows if row["ratio"] >= 1.35]
    worst_stretched_length = max(stretched, key=lambda row: row["after_m"]) if stretched else None
    cross_family = [row for row in rows if row["families"][0] != row["families"][1]]
    worst_cross_family = max(cross_family, key=lambda row: row["after_m"]) if cross_family else None
    assert worst_ratio["ratio"] < 6.0, (state, worst_ratio)
    assert worst_stretched_length is None or worst_stretched_length["after_m"] < 0.045, (
        state, worst_stretched_length,
    )
    if worst_cross_family is not None:
        assert worst_cross_family["ratio"] < 6.0, (state, worst_cross_family)
        if worst_cross_family["ratio"] >= 1.35:
            assert worst_cross_family["after_m"] < 0.045, (state, worst_cross_family)
    return {
        "pose": pose,
        "edges_checked": len(rows),
        "worst_ratio": worst_ratio,
        "worst_stretched_length": worst_stretched_length,
        "worst_cross_family": worst_cross_family,
    }


def cut_ring_separation_report(
    body: bpy.types.Object,
    armature: bpy.types.Object,
    original: list[Vector],
    state: str,
    progress: float,
) -> dict[str, object]:
    """Require the body cut ring to follow the face's neck-only contract.

    The body and face originate from the same bisected surface.  Rather than
    hide a dynamic split with collar geometry, compare every body cut-ring
    vertex against an exactly coincident virtual face vertex weighted neck=1.
    """
    ring = [
        vertex.index for vertex in body.data.vertices
        if abs(vertex.co.z - 1.825) <= 0.0002
    ]
    assert 100 <= len(ring) <= 180, len(ring)
    for index in ring:
        observed = body_vertex_weights(body, index)
        assert set(observed) == {"neck"}, (index, tuple(original[index]), observed)
        assert abs(observed["neck"] - 1.0) < 1.0e-6, (index, observed)

    pose = apply_sample(armature, state, progress)
    deformed = evaluated_points(body)
    neck_deform = (
        armature.pose.bones["neck"].matrix
        @ armature.data.bones["neck"].matrix_local.inverted()
    )
    rows = [
        ((deformed[index] - (neck_deform @ original[index])).length, index)
        for index in ring
    ]
    maximum, worst_index = max(rows)
    mean = sum(distance for distance, _index in rows) / len(rows)
    assert maximum < 1.0e-5, (state, maximum, worst_index)
    return {
        "pose": pose,
        "vertices": len(ring),
        "mean_separation_m": mean,
        "maximum_separation_m": maximum,
        "worst_index": worst_index,
        "weights": body_vertex_weights(body, worst_index),
        "comparison": "body ring versus coincident virtual face vertex weighted neck=1",
    }


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = ((target - obj.location).to_track_quat("-Z", "Y")).to_euler()


def render(body: bpy.types.Object, armature: bpy.types.Object, name: str) -> None:
    material = bpy.data.materials.get("V4RigDiagnosticClay") or bpy.data.materials.new("V4RigDiagnosticClay")
    material.diffuse_color = (0.11, 0.14, 0.19, 1.0)
    material.metallic = 0.0
    material.roughness = 0.58
    if not body.data.materials:
        body.data.materials.append(material)
    else:
        for index in range(len(body.data.materials)):
            body.data.materials[index] = material
    camera_data = bpy.data.cameras.new(f"{name}Camera")
    camera = bpy.data.objects.new(f"{name}Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (3.55, -4.75, 1.25)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.38
    look_at(camera, Vector((0.0, 0.0, 1.10)))
    light_data = bpy.data.lights.get("V4RigKeyData") or bpy.data.lights.new("V4RigKeyData", "AREA")
    light_data.energy = 900.0
    light_data.shape = "DISK"
    light_data.size = 3.0
    light = bpy.data.objects.get("V4RigKey") or bpy.data.objects.new("V4RigKey", light_data)
    if light.name not in bpy.context.collection.objects:
        bpy.context.collection.objects.link(light)
    light.location = (-2.0, -3.0, 4.5)
    look_at(light, Vector((0.0, 0.0, 1.1)))
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUT / f"{name}.png")
    scene.view_settings.view_transform = "AgX"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("V4RigDiagnosticWorld")
    scene.world.color = (0.018, 0.022, 0.032)
    armature.hide_render = True
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)


def main() -> None:
    arguments = parse_arguments()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    loaded = heroic_proportions(load_anatomy(1))
    source_body, eyes = loaded[0], loaded[1:]
    source_crown = max(vertex.co.z for vertex in source_body.data.vertices)
    body, _face = split_anatomy(source_body)
    marker = bpy.data.objects.new("V4RigMarker", None)
    bpy.context.collection.objects.link(marker)
    rig = create_rig(marker, body, eye_metadata(eyes, source_crown))
    weight_report = assign_body_weights(body, rig)
    # The production generator performs this once for all three skinned mesh
    # nodes after body details are joined. Reproduce the effect locally without
    # giving the weight function attachment side effects.
    modifier = body.modifiers.new(name="V4 rig diagnostic armature", type="ARMATURE")
    modifier.object = rig
    # Godot evaluates imported skins with linear blend skinning. Blender's
    # preserve-volume/DQ preview can hide classification tears, so every strict
    # edge metric below deliberately uses the runtime-equivalent LBS path.
    modifier.use_deform_preserve_volume = False
    body.parent = rig
    body.matrix_parent_inverse = rig.matrix_world.inverted()

    actual_names = {bone.name for bone in rig.data.bones}
    assert actual_names == set(BONE_NAMES) and len(actual_names) == 74
    hierarchy_mismatches = []
    non_identity_rest = 0
    for name in BONE_NAMES:
        expected_parent = BONE_BY_NAME[name].parent
        actual_parent = rig.data.bones[name].parent.name if rig.data.bones[name].parent else None
        if expected_parent != actual_parent:
            hierarchy_mismatches.append([name, expected_parent, actual_parent])
        if not rig.data.bones[name].matrix_local.to_3x3().is_identity:
            non_identity_rest += 1
    assert not hierarchy_mismatches
    assert non_identity_rest > 60, non_identity_rest

    original = [vertex.co.copy() for vertex in body.data.vertices]
    segments = {
        name: (rig.data.bones[name].head_local.copy(), rig.data.bones[name].tail_local.copy())
        for name in BONE_NAMES
    }
    hand_regions = _hand_region_vertices(body, original, segments)
    hand_semantics = _hand_skin_semantics(body, original, segments, hand_regions)
    set_pose(rig, False)
    neutral = evaluated_points(body)
    assert len(neutral) == len(original)
    zero_pose_max_error = max((first - second).length for first, second in zip(original, neutral, strict=True))
    assert zero_pose_max_error < 1.0e-5, zero_pose_max_error
    if arguments.render:
        render(body, rig, "neutral-weight-check")

    # Reproduce the r1 failure's actual grapple curl. Restrict the geometric
    # assertion to edges inside the connected wrist/hand components: ordinary
    # linear-blend finger skinning can exceed 1.5x locally, but the prior
    # classification tear reached 33.56x and 184 mm on a 5.49 mm source edge.
    set_grapple_finger_pose(rig)
    grapple = evaluated_points(body)
    worst_grapple_edge = None
    for edge in body.data.edges:
        first, second = edge.vertices
        if hand_regions.get(first) is None or hand_regions.get(first) != hand_regions.get(second):
            continue
        before = (original[first] - original[second]).length
        after = (grapple[first] - grapple[second]).length
        row = {
            "indices": [first, second],
            "before_m": before,
            "after_m": after,
            "ratio": after / max(before, 1.0e-9),
            "positions": [[round(value, 6) for value in original[index]] for index in (first, second)],
            "weights": [
                {
                    body.vertex_groups[item.group].name: round(item.weight, 6)
                    for item in body.data.vertices[index].groups if item.weight > 1.0e-7
                }
                for index in (first, second)
            ],
            "hand_semantics": [
                {
                    "side": hand_semantics[index][0],
                    "finger": hand_semantics[index][1],
                    "finger_amount": hand_semantics[index][2],
                    "wrist_amount": hand_semantics[index][3],
                }
                for index in (first, second)
            ],
        }
        if worst_grapple_edge is None or row["ratio"] > worst_grapple_edge["ratio"]:
            worst_grapple_edge = row
    assert worst_grapple_edge is not None
    assert worst_grapple_edge["ratio"] < 6.0, worst_grapple_edge
    assert worst_grapple_edge["after_m"] < 0.045, worst_grapple_edge

    # Keep the same non-negotiable tear bounds across the strongest whole-body
    # driver poses.  This covers every licensed-anatomy source edge, not only
    # vertices already labelled as hands or limbs, so a coordinate classifier
    # cannot hide a new shoulder or hip boundary from the regression.
    full_body_action_edges = {}
    for state, progress in (
        ("grapple", 15.0 / 29.0),
        ("strike", 13.0 / 29.0),
        ("crouch", 1.0),
        ("evade", 13.0 / 29.0),
        ("walk_left_contact", 0.0),
        ("walk_right_contact", 0.5),
    ):
        full_body_action_edges[state] = full_body_action_edge_report(
            body, rig, original, state, progress,
        )

    cut_ring_separation = {}
    for state, progress in (
        ("grapple", 15.0 / 29.0),
        ("strike", 13.0 / 29.0),
        ("crouch", 1.0),
    ):
        cut_ring_separation[state] = cut_ring_separation_report(
            body, rig, original, state, progress,
        )

    marker_transform = marker.matrix_world.copy()
    rig_transform = rig.matrix_world.copy()
    set_pose(rig, True)
    posed = evaluated_points(body)
    assert len(posed) == len(original)
    assert all(all(math.isfinite(component) for component in point) for point in posed)
    pose_displacements = [(first - second).length for first, second in zip(original, posed, strict=True)]
    assert max(pose_displacements) < 1.25
    assert sum(value > 0.01 for value in pose_displacements) > len(pose_displacements) * 0.08
    assert marker.matrix_world == marker_transform and rig.matrix_world == rig_transform
    assert rig.pose.bones["root"].matrix_basis.is_identity
    if arguments.render:
        render(body, rig, "asymmetric-bend-weight-check")

    set_pose(rig, False)
    recovered = evaluated_points(body)
    recovery_max_error = max((first - second).length for first, second in zip(original, recovered, strict=True))
    assert recovery_max_error < 1.0e-5, recovery_max_error

    report = {
        "status": "PASS",
        "source": "Dan Ulrich CC0 Body Male - Realistic level 1 plus frozen v4 reshape",
        "strict_skinning_mode": "linear_blend_runtime_equivalent",
        "bone_count": len(actual_names),
        "legacy_names_present": all(name in actual_names for name in BONE_NAMES if name in BONE_BY_NAME),
        "hierarchy_mismatches": hierarchy_mismatches,
        "non_identity_local_rest_bones": non_identity_rest,
        "zero_pose_max_vertex_error_m": zero_pose_max_error,
        "recovery_max_vertex_error_m": recovery_max_error,
        "posed_bounds": bounds(posed),
        "maximum_pose_displacement_m": max(pose_displacements),
        "vertices_moved_over_1cm": sum(value > 0.01 for value in pose_displacements),
        "r1_grapple_hand_edge_before_fix": {
            "indices": [6690, 8726],
            "before_m": 0.005491712911642735,
            "after_m": 0.18428480865773836,
            "ratio": 33.556890468007595,
        },
        "grapple_hand_edge_after_fix": worst_grapple_edge,
        "full_body_action_edges": full_body_action_edges,
        "body_face_cut_ring_separation": cut_ring_separation,
        "weight_report": weight_report,
        "landmarks": json.loads(rig["gloam_landmarks_json"]),
        "renders": ["neutral-weight-check.png", "asymmetric-bend-weight-check.png"] if arguments.render else [],
        "scope_note": "Blender deform sanity only; Godot runtime pose volume, floor, lintel, actions and recovery remain required.",
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "rig_validation.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("V4_RIG_VALIDATION PASS", json.dumps({
        "bones": report["bone_count"],
        "verts": weight_report["body_vertices"],
        "max_influences": weight_report["maximum_influences"],
        "zero_error": zero_pose_max_error,
        "recovery_error": recovery_max_error,
        "max_pose_displacement": max(pose_displacements),
        "action_edge_checks": sum(item["edges_checked"] for item in full_body_action_edges.values()),
    }, sort_keys=True))


main()
