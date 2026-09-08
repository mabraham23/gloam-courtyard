"""Adapt the locked 74-bone Gloam Vigil contract to the v4 CC0 anatomy.

The source body is Dan Ulrich's CC0 ``Body Male - Realistic`` mesh after the
project's frozen heroic-proportion and 12-degree arm-adduction pass.  This file
does not move the anatomy back to the v2 procedural proportions.  It measures
the surviving body/hand topology, keeps the exact v2 names and hierarchy, and
builds a new rest skeleton in Blender metres (+Z up, character faces -Y).

Public integration contract::

    armature = create_rig(marker, body, face_metadata=None)
    weight_report = assign_body_weights(body, armature)

``body`` may already be the post-costume partition (z .205..1.825).  The cut
ring is enough to place the ankle while ``face_metadata`` supplies the final
eye anchors.  Body weights are deterministic semantic envelopes: no operator
state, heat solver, donor rig, or animation is inherited.  Every vertex has at
most four normalized influences and a side can never borrow the opposite limb.
Face and cape meshes retain their own explicitly authored weights. Attachment
is intentionally left to the root generator's single shared mesh/rig step.
"""

from __future__ import annotations

from dataclasses import dataclass
import heapq
import json
import math
from pathlib import Path
import sys
from typing import Any, Iterable

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree


_V2_DIR = Path(__file__).resolve().parent.parent / "v2"
if str(_V2_DIR) not in sys.path:
    sys.path.insert(0, str(_V2_DIR))
from rig_contract import BONE_NAMES, LEGACY_BONE_NAMES  # noqa: E402


ASSET_ID = "gloam_vigil_v4"
ASSET_VERSION = 4
RUNTIME_RIG_CONTRACT = "gloam-vigil-v2-rig-1"
ANATOMY_RIG_CONTRACT = "gloam-vigil-v4-anatomy-1"
FORWARD_AXIS = "-Y"
FOOT_CONTACT_GROUPS = (
    "foot.L", "ball.L", "toe.L", "foot.R", "ball.R", "toe.R",
)
FINGERS = ("thumb", "index", "middle", "ring", "pinky")
SIDES = (("L", -1.0), ("R", 1.0))
_EPSILON = 1.0e-8
_UPPER_NECK_BLEND_START_Z = 1.720
_UPPER_NECK_BLEND_END_Z = 1.810


@dataclass(frozen=True)
class BoneSpec:
    name: str
    head: Vector
    tail: Vector
    parent: str | None
    semantic: str


def _assert_identity(obj: bpy.types.Object) -> None:
    identity = Matrix.Identity(4)
    assert all(
        abs(obj.matrix_world[row][column] - identity[row][column]) < 1.0e-5
        for row in range(4)
        for column in range(4)
    ), f"{obj.name} must have an applied identity transform"


def _vector(value: Iterable[float]) -> Vector:
    result = Vector(tuple(float(component) for component in value))
    assert len(result) == 3 and all(math.isfinite(component) for component in result)
    return result


def _points(body: bpy.types.Object) -> list[Vector]:
    assert body.type == "MESH" and len(body.data.vertices) > 1_000, body.name
    _assert_identity(body)
    result = [vertex.co.copy() for vertex in body.data.vertices]
    assert all(all(math.isfinite(component) for component in point) for point in result)
    return result


def _axis_bounds(points: list[Vector], axis: int) -> tuple[float, float]:
    return min(point[axis] for point in points), max(point[axis] for point in points)


def _rear_surface_y(tree: BVHTree, x: float, z: float) -> float:
    hit, _normal, _face, _distance = tree.ray_cast(
        Vector((x, 1.0, z)), Vector((0.0, -1.0, 0.0)), 2.0,
    )
    assert hit is not None, (x, z)
    return float(hit.y)


def _slice_center(
    points: list[Vector],
    side_sign: float,
    z: float,
    half_width: float,
    minimum_abs_x: float,
    maximum_abs_x: float,
    inward_bias: float = 0.5,
) -> Vector:
    selected = [
        point for point in points
        if abs(point.z - z) <= half_width
        and minimum_abs_x <= side_sign * point.x <= maximum_abs_x
    ]
    assert len(selected) >= 8, (z, side_sign, len(selected))
    x_min, x_max = _axis_bounds(selected, 0)
    y_min, y_max = _axis_bounds(selected, 1)
    if side_sign < 0.0:
        # The lower absolute-X bound is the anatomical inward surface on L.
        x = x_max + (x_min - x_max) * inward_bias
    else:
        x = x_min + (x_max - x_min) * inward_bias
    return Vector((x, (y_min + y_max) * 0.5, z))


def _mesh_adjacency(body: bpy.types.Object, points: list[Vector]) -> list[list[tuple[int, float]]]:
    adjacency: list[list[tuple[int, float]]] = [[] for _point in points]
    for edge in body.data.edges:
        first, second = edge.vertices
        length = (points[first] - points[second]).length
        adjacency[first].append((second, length))
        adjacency[second].append((first, length))
    return adjacency


def _hand_region_vertices(
    body: bpy.types.Object,
    points: list[Vector],
    segments: dict[str, tuple[Vector, Vector]],
) -> dict[int, str]:
    """Return mesh-connected wrist/hand ownership before spatial weighting.

    The real fingers overlap the thighs in Z and cannot safely fall through a
    coordinate-only arm envelope.  A clipped surface component seeded at each
    measured wrist contains the hand and a short legitimate wrist-blend band,
    while the nearby thigh is a separate topology component.
    """
    adjacency = _mesh_adjacency(body, points)
    ownership: dict[int, str] = {}
    for side, sign in SIDES:
        wrist = segments[f"hand.{side}"][0]
        allowed = {
            index for index, point in enumerate(points)
            if sign * point.x > 0.285 and 0.75 < point.z < 1.16
        }
        seeds = sorted(allowed, key=lambda index: (points[index] - wrist).length)[:12]
        assert len(seeds) == 12
        connected = set(seeds)
        queue = list(seeds)
        while queue:
            index = queue.pop()
            for neighbor, _length in adjacency[index]:
                if neighbor in allowed and neighbor not in connected:
                    connected.add(neighbor)
                    queue.append(neighbor)
        assert 2_500 < len(connected) < 3_500, (side, len(connected))
        for index in connected:
            assert index not in ownership, (index, side, ownership[index])
            ownership[index] = side
    return ownership


def _graph_distances(
    adjacency: list[list[tuple[int, float]]],
    allowed: set[int],
    seeds: Iterable[int],
) -> list[float]:
    distances = [math.inf] * len(adjacency)
    queue: list[tuple[float, int]] = []
    for index in seeds:
        distances[index] = 0.0
        heapq.heappush(queue, (0.0, index))
    while queue:
        distance, index = heapq.heappop(queue)
        if distance != distances[index]:
            continue
        for neighbor, edge_length in adjacency[index]:
            if neighbor not in allowed:
                continue
            candidate = distance + edge_length
            if candidate < distances[neighbor]:
                distances[neighbor] = candidate
                heapq.heappush(queue, (candidate, neighbor))
    return distances


def _hand_skin_semantics(
    body: bpy.types.Object,
    points: list[Vector],
    segments: dict[str, tuple[Vector, Vector]],
    ownership: dict[int, str],
) -> dict[int, tuple[str, str, float, float]]:
    """Map connected hand surfaces to a digit with a smooth geodesic fade."""
    adjacency = _mesh_adjacency(body, points)
    result: dict[int, tuple[str, str, float, float]] = {}
    for side, _sign in SIDES:
        connected = {index for index, owner in ownership.items() if owner == side}
        wrist = segments[f"hand.{side}"][0]
        proximal_axis = (segments[f"forearm_twist.{side}"][0] - wrist).normalized()
        wrist_seeds = sorted(connected, key=lambda index: (points[index] - wrist).length)[:12]
        from_wrist = _graph_distances(adjacency, connected, wrist_seeds)
        from_tips: dict[str, list[float]] = {}
        for finger in FINGERS:
            tip = segments[f"{finger}.03.{side}"][1]
            tip_seeds = sorted(connected, key=lambda index: (points[index] - tip).length)[:4]
            from_tips[finger] = _graph_distances(adjacency, connected, tip_seeds)
        for index in connected:
            ranked = sorted((distances[index], finger) for finger, distances in from_tips.items())
            nearest_distance, finger = ranked[0]
            separation = ranked[1][0] - nearest_distance
            assert math.isfinite(from_wrist[index]) and math.isfinite(nearest_distance)
            # Surface geodesics distinguish fingers that lie millimetres apart
            # in space but are far apart over the hand topology. The wrist-to-
            # MCP fade and broad ambiguity fade are both edge-continuous.
            # Keep the ownership field deliberately broad.  A sharper ramp
            # made adjacent palm vertices differ by almost 30 percentage
            # points under the grapple curl even though they belonged to the
            # same digit.  Both inputs are geodesic distance fields, so these
            # wider spans retain the fingertip maximum while preventing a
            # short mesh edge from crossing a large deformation gradient.
            distal = _smoothstep(0.060, 0.190, from_wrist[index])
            unambiguous = _smoothstep(0.000, 0.160, separation)
            # Surface distance is unsigned, so by itself it cannot distinguish
            # a fingertip path from the proximal forearm side of the wrist.
            # Project onto the measured forearm axis and continuously suppress
            # digit ownership before the clipped hand component meets the arm
            # field. This preserves a real wrist blend without a second hard
            # topology seam at the component boundary.
            proximal_distance = max(0.0, (points[index] - wrist).dot(proximal_axis))
            forearm_amount = _smoothstep(0.020, 0.100, proximal_distance)
            result[index] = (
                side,
                finger,
                distal * unambiguous * (1.0 - forearm_amount),
                forearm_amount,
            )
    return result


def _limb_skin_semantics(
    body: bpy.types.Object,
    points: list[Vector],
    segments: dict[str, tuple[Vector, Vector]],
) -> dict[int, tuple[str, str, float, float]]:
    """Build continuous whole-limb ownership over the licensed body surface.

    The anatomy's relaxed hands lie beside the thighs, so Euclidean gates cut
    directly through both forearms and shoulders.  Surface distance from the
    measured wrist/ankle follows the actual connected limb instead: nearby
    thigh points are far away over topology, and ownership can fade gradually
    into the chest/pelvis without a binary classification edge.
    """
    adjacency = _mesh_adjacency(body, points)
    allowed = set(range(len(points)))
    fields: list[tuple[str, str, float, float, list[float]]] = []
    for side, _sign in SIDES:
        for kind, anchor_name, fade_start, fade_end in (
            ("arm", f"hand.{side}", 0.10, 1.10),
            ("leg", f"foot.{side}", 0.55, 1.00),
        ):
            anchor = segments[anchor_name][0]
            seeds = sorted(allowed, key=lambda index: (points[index] - anchor).length)[:12]
            assert len(seeds) == 12
            fields.append((
                kind,
                side,
                fade_start,
                fade_end,
                _graph_distances(adjacency, allowed, seeds),
            ))

    result: dict[int, tuple[str, str, float, float]] = {}
    for index in range(len(points)):
        candidates: list[tuple[float, str, str, float]] = []
        for kind, side, fade_start, fade_end, distances in fields:
            distance = distances[index]
            if not math.isfinite(distance):
                continue
            amount = 1.0 - _smoothstep(fade_start, fade_end, distance)
            if kind == "leg":
                # Both ankle distance fields legitimately meet through the
                # connected groin topology. Fade either leg to pelvis at the
                # midline before choosing a side, so an asymmetric stride can
                # never flip adjacent crotch vertices between L/R thighs.
                lateral_amount = _smoothstep(0.0, 0.220, abs(points[index].x))
                groin_amount = _smoothstep(0.72, 0.90, distance)
                amount *= 1.0 - groin_amount * (1.0 - lateral_amount)
            if amount > 0.0:
                candidates.append((amount, kind, side, distance))
        if candidates:
            amount, kind, side, distance = max(candidates)
            result[index] = (kind, side, amount, distance)
    return result


def _finger_landmarks(
    body: bpy.types.Object,
    points: list[Vector],
    adjacency: list[list[tuple[int, float]]],
    side: str,
    sign: float,
    wrist: Vector,
) -> tuple[dict[str, list[Vector]], dict[str, list[float]]]:
    """Find the five real fingertip branches by surface geodesic distance.

    The licensed mesh is a connected anatomical surface.  Cutting a bounded
    hand volume at the wrist and finding separated local distance maxima gives
    the actual thumb/fingertips, including the donor's relaxed spread.  It is
    deliberately not the old procedural hand layout.
    """
    allowed = {
        index for index, point in enumerate(points)
        if sign * point.x > 0.285 and 0.75 < point.z < wrist.z + 0.055
    }
    assert len(allowed) > 500, (side, len(allowed))
    seeds = sorted(allowed, key=lambda index: (points[index] - wrist).length)[:12]
    distances = [math.inf] * len(points)
    queue: list[tuple[float, int]] = []
    for index in seeds:
        distances[index] = 0.0
        heapq.heappush(queue, (0.0, index))
    while queue:
        distance, index = heapq.heappop(queue)
        if distance != distances[index]:
            continue
        for neighbor, edge_length in adjacency[index]:
            if neighbor not in allowed:
                continue
            candidate = distance + edge_length
            if candidate < distances[neighbor]:
                distances[neighbor] = candidate
                heapq.heappush(queue, (candidate, neighbor))

    maxima: list[tuple[float, int]] = []
    for index in allowed:
        distance = distances[index]
        if not math.isfinite(distance):
            continue
        if all(distance >= distances[neighbor] - 1.0e-8 for neighbor, _length in adjacency[index]):
            maxima.append((distance, index))
    maxima.sort(reverse=True)
    separated: list[tuple[float, int]] = []
    for distance, index in maxima:
        if distance < 0.085:
            continue
        if any((points[index] - points[other]).length < 0.023 for _d, other in separated):
            continue
        separated.append((distance, index))
        if len(separated) == 16:
            break
    assert len(separated) >= 7, (side, [(distance, tuple(points[index])) for distance, index in separated])

    # The four long fingertip branches are the four most distant maxima. The
    # shorter thumb is the forward/inward high branch; selecting it separately
    # avoids mistaking a local maximum on the index/ring surface for the thumb.
    long_fingers = separated[:4]
    thumb_candidates = [
        item for item in separated[4:]
        if sign * points[item[1]].x < sign * wrist.x + 0.005
        and points[item[1]].y < -0.18
        and points[item[1]].z > 0.95
    ]
    assert thumb_candidates, (side, [(distance, tuple(points[index])) for distance, index in separated])
    thumb = min(thumb_candidates, key=lambda item: points[item[1]].y)
    long_fingers.sort(key=lambda item: points[item[1]].y)
    classified = {"thumb": thumb}
    classified.update(dict(zip(("index", "middle", "ring", "pinky"), long_fingers, strict=True)))

    chains: dict[str, list[Vector]] = {}
    evidence: dict[str, list[float]] = {}
    for finger in FINGERS:
        distance, index = classified[finger]
        surface_tip = points[index]
        direction = surface_tip - wrist
        # The adducted donor thumb is only about 12 cm from this measured
        # wrist center; long fingers remain substantially farther away.
        assert 0.105 < direction.length < 0.34, (side, finger, direction.length)
        # Pull the surface extremum 4 mm into the digit. The base fraction was
        # measured against this exact level-1 body: it lands at the visible MCP
        # row while preserving the relaxed donor spread.
        tip = surface_tip - direction.normalized() * 0.004
        base_fraction = 0.42 if finger == "thumb" else 0.46
        base = wrist.lerp(tip, base_fraction)
        chain = [base.lerp(tip, segment / 3.0) for segment in range(4)]
        assert all((chain[index + 1] - chain[index]).length > 0.018 for index in range(3))
        chains[finger] = chain
        evidence[finger] = [round(component, 6) for component in surface_tip]
        evidence[f"{finger}_geodesic_m"] = [round(distance, 6)]
    return chains, evidence


def _anchor_override(
    face_metadata: dict[str, Any],
    name: str,
    default_head: Vector,
    default_tail: Vector,
) -> tuple[Vector, Vector]:
    anchor: Any = None
    if name.startswith("eye."):
        anchor = face_metadata.get("eye_anchors", {}).get(name.rsplit(".", 1)[1])
    if anchor is None:
        anchor = face_metadata.get("bone_anchors", {}).get(name)
    if anchor is None and name in ("jaw", "head", "neck"):
        anchor = face_metadata.get(f"{name}_anchor") or face_metadata.get(f"{name}_anchors")
    if anchor is None:
        return default_head, default_tail
    if isinstance(anchor, dict):
        return _vector(anchor.get("head", default_head)), _vector(anchor.get("tail", default_tail))
    assert isinstance(anchor, (list, tuple)) and len(anchor) == 2, (name, anchor)
    return _vector(anchor[0]), _vector(anchor[1])


def _derive_specs(
    body: bpy.types.Object,
    face_metadata: dict[str, Any] | None,
) -> tuple[list[BoneSpec], dict[str, Any]]:
    points = _points(body)
    metadata = face_metadata or {}
    minimum_z, maximum_z = _axis_bounds(points, 2)
    assert 0.195 <= minimum_z <= 0.215, minimum_z
    assert 1.815 <= maximum_z <= 1.835, maximum_z

    adjacency = _mesh_adjacency(body, points)
    body_tree = BVHTree.FromPolygons(
        points,
        [tuple(polygon.vertices) for polygon in body.data.polygons],
        all_triangles=False,
    )
    specs: dict[str, BoneSpec] = {}

    def add(name: str, head: Vector, tail: Vector, parent: str | None, semantic: str) -> None:
        assert name not in specs and (tail - head).length > 0.01, (name, tuple(head), tuple(tail))
        assert all(math.isfinite(component) for point in (head, tail) for component in point)
        specs[name] = BoneSpec(name, head, tail, parent, semantic)

    # Core joint heights remain compatible with accepted gameplay, but head
    # and face anchors follow the real face metadata rather than the v2 bust.
    eye_defaults = {
        "L": (Vector((-0.0421, -0.1561, 2.0185)), Vector((-0.0421, -0.1961, 2.0185))),
        "R": (Vector((0.0421, -0.1561, 2.0185)), Vector((0.0421, -0.1961, 2.0185))),
    }
    eye_anchors = {
        side: _anchor_override(metadata, f"eye.{side}", *eye_defaults[side])
        for side, _sign in SIDES
    }
    assert eye_anchors["L"][0].x < 0.0 < eye_anchors["R"][0].x, (
        "face metadata must use contract sides (L is -X, R is +X)",
        tuple(eye_anchors["L"][0]), tuple(eye_anchors["R"][0]),
    )
    eye_z = sum(value[0].z for value in eye_anchors.values()) * 0.5
    crown = float(metadata.get("bounds_max", (0.0, 0.0, 2.16))[2])
    crown = max(2.14, min(2.18, crown))
    neck_default = (Vector((0.0, 0.010, 1.700)), Vector((0.0, 0.000, 1.885)))
    head_default = (Vector((0.0, 0.000, 1.865)), Vector((0.0, -0.004, crown)))
    jaw_default = (
        Vector((0.0, -0.060, eye_z - 0.028)),
        Vector((0.0, -0.095, eye_z - 0.130)),
    )
    neck_head, neck_tail = _anchor_override(metadata, "neck", *neck_default)
    head_head, head_tail = _anchor_override(metadata, "head", *head_default)
    jaw_head, jaw_tail = _anchor_override(metadata, "jaw", *jaw_default)

    add("root", Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.0, 0.25)), None, "root")
    add("pelvis", Vector((0.0, 0.0, 1.00)), Vector((0.0, 0.0, 1.18)), "root", "core")
    add("spine", Vector((0.0, 0.0, 1.16)), Vector((0.0, 0.0, 1.38)), "pelvis", "core")
    add("spine_upper", Vector((0.0, 0.0, 1.36)), Vector((0.0, 0.0, 1.56)), "spine", "core")
    add("chest", Vector((0.0, 0.0, 1.54)), Vector((0.0, 0.0, 1.72)), "spine_upper", "core")
    add("neck", neck_head, neck_tail, "chest", "neck")
    add("head", head_head, head_tail, "neck", "head")
    add("jaw", jaw_head, jaw_tail, "head", "face")
    for side, _sign in SIDES:
        add(f"eye.{side}", *eye_anchors[side], "head", "face")

    landmark_report: dict[str, Any] = {
        "source_body_bounds_z": [round(minimum_z, 6), round(maximum_z, 6)],
        "contract_side_convention": "L=-X,R=+X",
        "eyes": {
            side: {"head": [round(value, 6) for value in anchors[0]], "tail": [round(value, 6) for value in anchors[1]]}
            for side, anchors in eye_anchors.items()
        },
        "limbs": {},
        "surface_fingertips": {},
        "cape_anchors": {},
    }

    for side, sign in SIDES:
        # Each center comes from the actual post-reshape cross section. Hip is
        # biased slightly inward because the superior slice includes gluteal
        # and groin surfaces; knee/ankle use their full section midpoint.
        hip = _slice_center(points, sign, 1.080, 0.012, 0.035, 0.305, 0.56)
        knee = _slice_center(points, sign, 0.600, 0.012, 0.070, 0.275, 0.50)
        ankle_surface = _slice_center(points, sign, max(minimum_z + 0.004, 0.209), 0.007, 0.145, 0.285, 0.50)
        ankle = Vector((ankle_surface.x, ankle_surface.y, 0.170))
        thigh_mid = hip.lerp(knee, 0.52)
        shin_mid = knee.lerp(ankle, 0.50)

        add(f"thigh.{side}", hip, thigh_mid, "pelvis", "leg")
        add(f"thigh_twist.{side}", thigh_mid, knee, f"thigh.{side}", "leg_twist")
        add(f"shin.{side}", knee, shin_mid, f"thigh_twist.{side}", "leg")
        add(f"shin_twist.{side}", shin_mid, ankle, f"shin.{side}", "leg_twist")
        ball = Vector((ankle.x, -0.140, 0.070))
        toe = Vector((ankle.x, -0.245, 0.062))
        toe_end = Vector((ankle.x, -0.300, 0.058))
        add(f"foot.{side}", ankle, ball, f"shin_twist.{side}", "foot")
        add(f"ball.{side}", ball, toe, f"foot.{side}", "foot")
        add(f"toe.{side}", toe, toe_end, f"ball.{side}", "foot")

        shoulder_section = _slice_center(points, sign, 1.730, 0.012, 0.245, 0.330, 0.50)
        shoulder = Vector((sign * 0.290, shoulder_section.y, 1.730))
        elbow = _slice_center(points, sign, 1.365, 0.012, 0.245, 0.405, 0.55)
        wrist = _slice_center(points, sign, 1.095, 0.012, 0.305, 0.410, 0.50)
        finger_chains, finger_evidence = _finger_landmarks(body, points, adjacency, side, sign, wrist)
        finger_bases = [finger_chains[name][0] for name in FINGERS]
        palm = sum(finger_bases, Vector()) / len(finger_bases)
        # Keep the palm endpoint proximal to the MCP row and inside the real
        # volume; finger chains retain their own measured spread from there.
        hand_tail = wrist.lerp(palm, 0.78)
        upper_mid = shoulder.lerp(elbow, 0.52)
        fore_mid = elbow.lerp(wrist, 0.52)
        clavicle_head = Vector((sign * 0.055, 0.010, 1.700))
        add(f"clavicle.{side}", clavicle_head, shoulder, "chest", "shoulder")
        add(f"upper_arm.{side}", shoulder, upper_mid, f"clavicle.{side}", "arm")
        add(f"upper_arm_twist.{side}", upper_mid, elbow, f"upper_arm.{side}", "arm_twist")
        add(f"forearm.{side}", elbow, fore_mid, f"upper_arm_twist.{side}", "arm")
        add(f"forearm_twist.{side}", fore_mid, wrist, f"forearm.{side}", "arm_twist")
        add(f"hand.{side}", wrist, hand_tail, f"forearm_twist.{side}", "hand")
        for finger in FINGERS:
            parent = f"hand.{side}"
            chain = finger_chains[finger]
            for index in range(3):
                name = f"{finger}.{index + 1:02d}.{side}"
                add(name, chain[index], chain[index + 1], parent, "finger")
                parent = name

        # The upper cape is projected onto the real back instead of retaining
        # the translated v2 gap. Match its 6 mm clearance at the root, retain
        # 22% of that correction at the second chain pivot, and leave the
        # accepted lower silhouette unchanged.
        old_cape_root = Vector((sign * 0.130, 0.190, 1.755))
        back_y = _rear_surface_y(body_tree, old_cape_root.x, old_cape_root.z)
        cape_root_y = back_y + 0.006
        root_correction = cape_root_y - old_cape_root.y
        cape_mid_y = 0.250 + root_correction * 0.22
        cape_points = (
            Vector((sign * 0.130, cape_root_y, 1.755)),
            Vector((sign * 0.150, cape_mid_y, 1.450)),
            Vector((sign * 0.200, 0.330, 1.100)),
            Vector((sign * 0.290, 0.380, 0.720)),
            Vector((sign * 0.370, 0.405, 0.550)),
        )
        parent = "chest"
        for index, prefix in enumerate(("cape", "cape_mid", "cape_lower", "cape_tip")):
            name = f"{prefix}.{side}"
            add(name, cape_points[index], cape_points[index + 1], parent, "cape")
            parent = name

        landmark_report["limbs"][side] = {
            "hip": [round(value, 6) for value in hip],
            "knee": [round(value, 6) for value in knee],
            "ankle_surface": [round(value, 6) for value in ankle_surface],
            "ankle_bone": [round(value, 6) for value in ankle],
            "shoulder": [round(value, 6) for value in shoulder],
            "elbow": [round(value, 6) for value in elbow],
            "wrist": [round(value, 6) for value in wrist],
            "hand_tail": [round(value, 6) for value in hand_tail],
        }
        landmark_report["surface_fingertips"][side] = finger_evidence
        landmark_report["cape_anchors"][side] = {
            "body_back_y": round(back_y, 6),
            "old_root": [round(value, 6) for value in old_cape_root],
            "new_root": [round(value, 6) for value in cape_points[0]],
            "old_mid": [round(value, 6) for value in Vector((sign * 0.150, 0.250, 1.450))],
            "new_mid": [round(value, 6) for value in cape_points[1]],
            "root_clearance_m": 0.006,
            "mid_correction_fraction": 0.22,
        }

    missing = set(BONE_NAMES) - set(specs)
    extra = set(specs) - set(BONE_NAMES)
    assert not missing and not extra and len(specs) == 74, (sorted(missing), sorted(extra), len(specs))
    ordered = [specs[name] for name in BONE_NAMES]
    assert set(LEGACY_BONE_NAMES).issubset(specs)
    return ordered, landmark_report


def create_rig(
    marker: bpy.types.Object,
    body: bpy.types.Object,
    face_metadata: dict[str, Any] | None = None,
) -> bpy.types.Object:
    """Create and return the v4 armature; never changes the supplied body."""
    specs, landmarks = _derive_specs(body, face_metadata)
    armature_data = bpy.data.armatures.new("gloam_vigil_v4_rig")
    armature = bpy.data.objects.new("GloamVigilV4Rig", armature_data)
    bpy.context.collection.objects.link(armature)
    if marker is not None:
        armature.parent = marker
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    created: dict[str, bpy.types.EditBone] = {}
    for spec in specs:
        bone = armature_data.edit_bones.new(spec.name)
        bone.head = spec.head
        bone.tail = spec.tail
        if spec.parent is not None:
            bone.parent = created[spec.parent]
        direction = (spec.tail - spec.head).normalized()
        roll_target = Vector((0.0, -1.0, 0.0))
        if abs(direction.dot(roll_target)) > 0.92:
            roll_target = Vector((0.0, 0.0, 1.0))
        bone.align_roll(roll_target)
        created[spec.name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    armature.select_set(False)
    armature.show_in_front = True

    assert len(armature_data.bones) == 74
    for spec in specs:
        bone = armature_data.bones[spec.name]
        assert bone.parent is None if spec.parent is None else bone.parent.name == spec.parent
        assert (bone.tail_local - bone.head_local).length > 0.01
        assert abs(bone.matrix_local.to_3x3().determinant() - 1.0) < 1.0e-4

    armature["gloam_asset_id"] = ASSET_ID
    armature["gloam_asset_version"] = ASSET_VERSION
    armature["gloam_rig_contract"] = RUNTIME_RIG_CONTRACT
    armature["gloam_anatomy_rig_contract"] = ANATOMY_RIG_CONTRACT
    armature["gloam_forward_axis"] = FORWARD_AXIS
    armature["gloam_legacy_bones"] = ",".join(LEGACY_BONE_NAMES)
    armature["gloam_foot_contact_groups"] = ",".join(FOOT_CONTACT_GROUPS)
    armature["gloam_landmarks_json"] = json.dumps(landmarks, sort_keys=True)
    return armature


def _distance_to_segment(point: Vector, head: Vector, tail: Vector) -> float:
    direction = tail - head
    amount = max(0.0, min(1.0, (point - head).dot(direction) / max(direction.length_squared, _EPSILON)))
    return (point - head.lerp(tail, amount)).length


def _normalized_envelopes(
    point: Vector,
    names: Iterable[str],
    segments: dict[str, tuple[Vector, Vector]],
    maximum: int = 4,
) -> dict[str, float]:
    ranked = sorted(
        ((name, _distance_to_segment(point, *segments[name])) for name in names),
        key=lambda item: item[1],
    )[:maximum]
    raw = {name: 1.0 / ((distance + 0.018) ** 4) for name, distance in ranked}
    total = sum(raw.values())
    assert total > _EPSILON
    retained = {name: value / total for name, value in raw.items() if value / total > 1.0e-5}
    retained_total = sum(retained.values())
    return {name: value / retained_total for name, value in retained.items()}


def _smoothstep(edge0: float, edge1: float, value: float) -> float:
    amount = max(0.0, min(1.0, (value - edge0) / max(edge1 - edge0, _EPSILON)))
    return amount * amount * (3.0 - 2.0 * amount)


def _core_weights(point: Vector, segments: dict[str, tuple[Vector, Vector]]) -> dict[str, float]:
    names = ["pelvis", "spine", "spine_upper", "chest", "neck"]
    centers = [
        (name, (segments[name][0].z + segments[name][1].z) * 0.5)
        for name in names
    ]
    return _piecewise_chain_weights(point.z, centers)


def _blend_weight_maps(
    first: dict[str, float],
    second: dict[str, float],
    first_amount: float,
    maximum: int = 4,
) -> dict[str, float]:
    amount = max(0.0, min(1.0, first_amount))
    combined: dict[str, float] = {}
    for name, value in first.items():
        combined[name] = combined.get(name, 0.0) + value * amount
    for name, value in second.items():
        combined[name] = combined.get(name, 0.0) + value * (1.0 - amount)
    ranked = sorted(combined.items(), key=lambda item: item[1], reverse=True)[:maximum]
    retained = {name: value for name, value in ranked if value > 1.0e-6}
    total = sum(retained.values())
    assert total > _EPSILON
    return {name: value / total for name, value in retained.items()}


def _piecewise_chain_weights(
    distance: float,
    centers: list[tuple[str, float]],
) -> dict[str, float]:
    """Blend only adjacent chain members, reaching zero before set changes."""
    assert centers and all(centers[index][1] < centers[index + 1][1] for index in range(len(centers) - 1))
    if distance <= centers[0][1]:
        return {centers[0][0]: 1.0}
    for (first_name, first_distance), (second_name, second_distance) in zip(centers, centers[1:]):
        if distance <= second_distance:
            # Zero endpoint derivatives keep the outgoing weight flat where
            # one adjacent pair hands off to the next; this is especially
            # important at the deeply flexed knee in crouch/roll poses.
            amount = _smoothstep(first_distance, second_distance, distance)
            result = {
                first_name: 1.0 - amount,
                second_name: amount,
            }
            return {name: value for name, value in result.items() if value > 1.0e-6}
    return {centers[-1][0]: 1.0}


def _limb_chain_weights(
    kind: str,
    side: str,
    surface_distance: float,
    segments: dict[str, tuple[Vector, Vector]],
) -> dict[str, float]:
    if kind == "arm":
        distal_to_proximal = [
            f"forearm_twist.{side}",
            f"forearm.{side}",
            f"upper_arm_twist.{side}",
            f"upper_arm.{side}",
            f"clavicle.{side}",
        ]
    else:
        assert kind == "leg", kind
        distal_to_proximal = [
            f"foot.{side}",
            f"shin_twist.{side}",
            f"shin.{side}",
            f"thigh_twist.{side}",
            f"thigh.{side}",
        ]
    centers: list[tuple[str, float]] = []
    cumulative = 0.0
    for index, name in enumerate(distal_to_proximal):
        length = (segments[name][1] - segments[name][0]).length
        if index == 0 and kind == "leg":
            # The retained body starts at the ankle; generated boots own the
            # distal foot volume, so the cut ring can begin on the foot bone.
            center = 0.0
            centers.append((name, center))
            continue
        else:
            # The shoulder needs a much broader upper-arm/clavicle blend than
            # the narrow physical clavicle half-length. Their runtime driver
            # rotations differ substantially during an overhead reach; a
            # compressed interval visibly stretches adjacent axilla vertices.
            center = cumulative + length * (3.0 if kind == "arm" and name.startswith("clavicle") else 0.5)
        centers.append((name, center))
        cumulative += length
    return _piecewise_chain_weights(surface_distance, centers)


def _weights_for_vertex(
    point: Vector,
    segments: dict[str, tuple[Vector, Vector]],
    hand_semantic: tuple[str, str, float, float] | None = None,
    limb_semantic: tuple[str, str, float, float] | None = None,
) -> dict[str, float]:
    side = hand_semantic[0] if hand_semantic is not None else ("L" if point.x < 0.0 else "R")
    if hand_semantic is not None:
        _semantic_side, finger, finger_amount, wrist_amount = hand_semantic
        chain_names = [f"{finger}.{index:02d}.{side}" for index in range(1, 4)]
        if finger_amount <= 1.0e-8:
            proximal = {
                f"forearm_twist.{side}": wrist_amount,
                f"hand.{side}": 1.0 - wrist_amount,
            }
            retained = {name: value for name, value in proximal.items() if value > 1.0e-6}
            total = sum(retained.values())
            assert total > _EPSILON
            return {name: value / total for name, value in retained.items()}
        phalanges = _normalized_envelopes(point, chain_names, segments, maximum=3)
        combined = {name: value * finger_amount for name, value in phalanges.items()}
        combined[f"hand.{side}"] = 1.0 - finger_amount
        if wrist_amount > 0.0:
            combined = {name: value * (1.0 - wrist_amount) for name, value in combined.items()}
            combined[f"forearm_twist.{side}"] = wrist_amount
        total = sum(combined.values())
        ranked = sorted(combined.items(), key=lambda item: item[1], reverse=True)[:4]
        retained = {name: value / total for name, value in ranked if value / total > 1.0e-6}
        retained_total = sum(retained.values())
        return {name: value / retained_total for name, value in retained.items()}
    if limb_semantic is not None:
        kind, side, amount, surface_distance = limb_semantic
        if kind == "arm":
            # The body and face are cut from the same licensed surface at
            # z=1.825, but they are skinned independently.  The face starts
            # neck-only at that ring; allowing the broad shoulder geodesic
            # field to survive to the body side made coincident ring vertices
            # separate by up to 20.7 mm in an overhead reach.  Return the arm
            # field smoothly to the core through the anatomical upper neck:
            # the fade begins just above the chest/clavicle root and reaches
            # zero 15 mm below the partition.  Shoulder/axilla ownership below
            # this band remains unchanged, while the final core result is
            # exactly neck=1 because the neck is the last core-chain member.
            upper_neck = _smoothstep(
                _UPPER_NECK_BLEND_START_Z,
                _UPPER_NECK_BLEND_END_Z,
                point.z,
            )
            amount *= 1.0 - upper_neck
        # Two explicitly adjacent chain members plus two neighbouring core
        # bones form a stable four-influence field.  Unlike a nearest-two
        # selection, each outgoing chain weight reaches zero before the next
        # pair takes over, so retained bone sets cannot flip across an edge.
        limb_weights = _limb_chain_weights(kind, side, surface_distance, segments)
        return _blend_weight_maps(limb_weights, _core_weights(point, segments), amount)
    return _core_weights(point, segments)


def assign_body_weights(body: bpy.types.Object, armature: bpy.types.Object) -> dict[str, Any]:
    """Assign bounded semantic weights; do not add a second rig modifier.

    This intentionally weights only the post-partition body. Face, cape, and
    generated boots/details own their explicit groups in their source modules.
    """
    assert armature.type == "ARMATURE" and body.type == "MESH"
    _assert_identity(body)
    assert set(BONE_NAMES) == {bone.name for bone in armature.data.bones}
    segments = {
        name: (
            armature.data.bones[name].head_local.copy(),
            armature.data.bones[name].tail_local.copy(),
        )
        for name in BONE_NAMES
    }
    body_points = [vertex.co.copy() for vertex in body.data.vertices]
    hand_regions = _hand_region_vertices(body, body_points, segments)
    hand_semantics = _hand_skin_semantics(body, body_points, segments, hand_regions)
    limb_semantics = _limb_skin_semantics(body, body_points, segments)
    for group in list(body.vertex_groups):
        if group.name in BONE_NAMES:
            body.vertex_groups.remove(group)
    groups = {name: body.vertex_groups.new(name=name) for name in BONE_NAMES}
    assignments: list[dict[str, float]] = []
    for vertex in body.data.vertices:
        weights = _weights_for_vertex(
            vertex.co,
            segments,
            hand_semantics.get(vertex.index),
            limb_semantics.get(vertex.index),
        )
        total = sum(weights.values())
        assert 1 <= len(weights) <= 4 and abs(total - 1.0) < 1.0e-6
        normalized = {name: value / total for name, value in weights.items()}
        assignments.append(normalized)
        for name, value in normalized.items():
            groups[name].add([vertex.index], value, "REPLACE")

    bpy.context.view_layer.update()
    maximum_influences = 0
    maximum_sum_error = 0.0
    side_contamination = 0
    arm_leg_contamination = 0
    used: set[str] = set()
    influence_vertex_counts: dict[str, int] = {}
    hand_region_misweights = 0
    for vertex, expected in zip(body.data.vertices, assignments, strict=True):
        observed = {
            body.vertex_groups[element.group].name: element.weight
            for element in vertex.groups
            if body.vertex_groups[element.group].name in BONE_NAMES and element.weight > 1.0e-7
        }
        maximum_influences = max(maximum_influences, len(observed))
        maximum_sum_error = max(maximum_sum_error, abs(sum(observed.values()) - 1.0))
        used.update(observed)
        for name in observed:
            influence_vertex_counts[name] = influence_vertex_counts.get(name, 0) + 1
        opposite = ".R" if vertex.co.x < -0.035 else (".L" if vertex.co.x > 0.035 else "")
        if opposite and any(name.endswith(opposite) for name in observed):
            side_contamination += 1
        if vertex.co.z < 0.72 and any("arm" in name or name.startswith(("hand", "thumb", "index", "middle", "ring", "pinky")) for name in observed):
            arm_leg_contamination += 1
        if vertex.co.z > 1.20 and any(name.startswith(("thigh", "shin", "foot", "ball", "toe")) for name in observed):
            arm_leg_contamination += 1
        if vertex.index in hand_regions:
            hand_side = hand_regions[vertex.index]
            arm_family = {
                f"clavicle.{hand_side}", f"upper_arm.{hand_side}", f"upper_arm_twist.{hand_side}",
                f"forearm.{hand_side}", f"forearm_twist.{hand_side}", f"hand.{hand_side}",
            } | {
                f"{finger}.{segment:02d}.{hand_side}"
                for finger in FINGERS for segment in range(1, 4)
            }
            if not set(observed).issubset(arm_family):
                hand_region_misweights += 1
        assert set(observed) == set(expected), (vertex.index, observed, expected)
    assert maximum_influences <= 4, maximum_influences
    assert maximum_sum_error < 1.0e-5, maximum_sum_error
    assert side_contamination == 0, side_contamination
    assert arm_leg_contamination == 0, arm_leg_contamination
    assert hand_region_misweights == 0, hand_region_misweights

    report: dict[str, Any] = {
        "method": "deterministic semantic segment envelopes",
        "body_vertices": len(body.data.vertices),
        "maximum_influences": maximum_influences,
        "maximum_normalization_error": maximum_sum_error,
        "side_contamination_vertices": side_contamination,
        "arm_leg_contamination_vertices": arm_leg_contamination,
        "connected_hand_region_vertices": {
            side: sum(owner == side for owner in hand_regions.values()) for side, _sign in SIDES
        },
        "connected_hand_region_misweights": hand_region_misweights,
        "geodesic_limb_region_vertices": {
            f"{kind}.{side}": sum(
                semantic[0] == kind and semantic[1] == side
                for semantic in limb_semantics.values()
            )
            for kind in ("arm", "leg") for side, _sign in SIDES
        },
        "geodesic_limb_blend_vertices": {
            f"{kind}.{side}": sum(
                semantic[0] == kind and semantic[1] == side and semantic[2] < 1.0
                for semantic in limb_semantics.values()
            )
            for kind in ("arm", "leg") for side, _sign in SIDES
        },
        "used_body_bones": sorted(used),
        "influence_vertex_counts": dict(sorted(influence_vertex_counts.items())),
        "unweighted_by_body_expected_external": sorted(set(BONE_NAMES) - used),
    }
    body["gloam_body_weight_report"] = json.dumps(report, sort_keys=True)
    body["gloam_skin_weight_method"] = report["method"]
    return report
