"""Original explicit-topology head and short neck for Gloam Vigil v3.

The visible skin is one connected parameterized quad surface from the collar
line through the throat, mandible, face, cranium, and crown.  Eye sockets,
eyelid rims, nasal bridge/tip/wings/nostril recesses, philtrum, lips, chin, and
jaw planes are displacements of that surface: there are no pasted nose or lip
objects, voxel remeshes, or decimation passes.  Separate geometry is limited to
anatomically separate eyes and pinnae plus a thin fitted original domino mask.

This remains deterministic code-authored modeling rather than a hand sculpt or
manual retopology.  The v2 74-bone rest contract and five material names are
consumed unchanged.  Blender-space convention is metres, +Z up, forward -Y.
"""

from __future__ import annotations

import math

import bpy

from mesh_tools import MeshAssembly, MeshPart, ellipsoid, normalized, smart_uv, thick_ribbon, triangulate
from rig_contract import BONE_BY_NAME, BONE_NAMES, MATERIAL_NAMES, MORPH_NAMES


SKIN = "MAT_GV2_Skin"
GEAR = "MAT_GV2_Gear"
HEAD_TRIANGLE_BUDGET = 20_000
# r2 spends fewer uniform circumference samples than r1 and moves that budget
# into conforming mask/scalp surfaces and local feature rows.
SIDES = 96

EYE_X = abs(BONE_BY_NAME["eye.R"].head[0])
EYE_Y = BONE_BY_NAME["eye.R"].head[1]
EYE_Z = BONE_BY_NAME["eye.R"].head[2]
HEAD_TOP = BONE_BY_NAME["head"].tail[2]

assert (EYE_X, EYE_Y, EYE_Z) == (0.039, -0.072, 2.048)
assert HEAD_TOP == 2.16


def _clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def _smoothstep(low: float, high: float, value: float) -> float:
    if low == high:
        return float(value >= high)
    t = _clamp((value - low) / (high - low))
    return t * t * (3.0 - 2.0 * t)


def _gauss(value: float, center: float, width: float) -> float:
    return math.exp(-((value - center) / width) ** 2)


# z, half-width, half-depth, rearward center, front chin drop.  The first ring
# sits inside the body's fitted collar at z=1.825, while the rapid widening at
# the mandible makes the visible throat short rather than a cylinder.
_PROFILE = (
    (1.805, 0.090, 0.073, 0.014, 0.000),
    (1.825, 0.086, 0.069, 0.012, 0.000),
    (1.850, 0.079, 0.065, 0.009, 0.000),
    (1.875, 0.074, 0.062, 0.006, 0.000),
    (1.900, 0.060, 0.052, 0.004, 0.030),
    (1.914, 0.082, 0.061, 0.003, 0.027),
    (1.930, 0.101, 0.071, 0.004, 0.013),
    (1.950, 0.108, 0.078, 0.005, 0.004),
    (1.975, 0.111, 0.083, 0.006, 0.000),
    (2.005, 0.109, 0.087, 0.007, 0.000),
    (2.033, 0.107, 0.090, 0.008, 0.000),
    (2.060, 0.108, 0.089, 0.009, 0.000),
    (2.090, 0.105, 0.085, 0.011, 0.000),
    (2.118, 0.098, 0.079, 0.012, 0.000),
    (2.142, 0.075, 0.063, 0.012, 0.000),
    (2.151, 0.054, 0.050, 0.012, 0.000),
    (2.157, 0.025, 0.024, 0.012, 0.000),
)


def _pchip_slopes(column: int) -> tuple[float, ...]:
    """Shape-preserving C1 slopes for one authored profile coordinate."""
    xs = [entry[0] for entry in _PROFILE]
    ys = [entry[column] for entry in _PROFILE]
    delta = [(ys[index + 1] - ys[index]) / (xs[index + 1] - xs[index]) for index in range(len(xs) - 1)]
    slopes = [delta[0]]
    for index in range(1, len(xs) - 1):
        previous = delta[index - 1]
        following = delta[index]
        if previous == 0.0 or following == 0.0 or previous * following <= 0.0:
            slopes.append(0.0)
            continue
        before_span = xs[index] - xs[index - 1]
        after_span = xs[index + 1] - xs[index]
        weight_a = 2.0 * after_span + before_span
        weight_b = after_span + 2.0 * before_span
        slopes.append((weight_a + weight_b) / (weight_a / previous + weight_b / following))
    slopes.append(delta[-1])
    return tuple(slopes)


_PROFILE_SLOPES = tuple(_pchip_slopes(column) for column in range(1, 5))


def _profile_at(z: float) -> tuple[float, float, float, float]:
    """C1 shape-preserving Hermite interpolation; no flat tangent per knot."""
    if z <= _PROFILE[0][0]:
        return _PROFILE[0][1:]
    if z >= _PROFILE[-1][0]:
        return _PROFILE[-1][1:]
    for segment, (lower, upper) in enumerate(zip(_PROFILE, _PROFILE[1:], strict=True)):
        if lower[0] <= z <= upper[0]:
            span = upper[0] - lower[0]
            t = (z - lower[0]) / span
            t2 = t * t
            t3 = t2 * t
            h00 = 2.0 * t3 - 3.0 * t2 + 1.0
            h10 = t3 - 2.0 * t2 + t
            h01 = -2.0 * t3 + 3.0 * t2
            h11 = t3 - t2
            return tuple(
                h00 * lower[column]
                + h10 * span * _PROFILE_SLOPES[column - 1][segment]
                + h01 * upper[column]
                + h11 * span * _PROFILE_SLOPES[column - 1][segment + 1]
                for column in range(1, 5)
            )  # type: ignore[return-value]
    raise AssertionError(z)


def _feature_rows() -> tuple[float, ...]:
    # Roughly 7 mm global spacing, with closed feature-aligned rows around the
    # lips, alae, lids, and brow.  These retain editable quad flow and give the
    # four morph targets local support without inflating the whole cranium.
    rows = {round(1.805 + index * 0.008, 6) for index in range(45)}
    rows.update(
        {
            1.805,
            1.875,
            1.884,
            1.894,
            1.905,
            1.914,
            1.924,
            1.936,
            1.947,
            1.953,
            1.959,
            1.965,
            1.971,
            1.977,
            1.983,
            1.989,
            1.996,
            2.004,
            2.014,
            2.025,
            2.034,
            2.040,
            2.046,
            2.052,
            2.058,
            2.064,
            2.071,
            2.080,
            2.090,
            2.118,
            2.142,
            2.151,
            2.157,
        }
    )
    return tuple(sorted(value for value in rows if 1.805 <= value <= 2.157))


def _feature_depth(x: float, z: float) -> float:
    """Signed Y offset on the forward facial plane; negative projects forward."""
    # Orbital bowl is recessed; its continuous annular ridge supplies eyelid
    # thickness and a readable socket edge rather than a floating lid tube.
    socket = 0.0
    lid_rim = 0.0
    brow = 0.0
    cheek = 0.0
    for sign in (-1.0, 1.0):
        ex = sign * EYE_X
        radial = math.sqrt(((x - ex) / 0.025) ** 2 + ((z - EYE_Z) / 0.0135) ** 2)
        socket += 0.0080 * math.exp(-(radial / 0.94) ** 4)
        lid_rim += 0.0028 * math.exp(-((radial - 1.02) / 0.19) ** 2)
        brow += 0.0050 * _gauss(x, ex, 0.028) * _gauss(z, 2.078, 0.017)
        cheek += 0.0070 * _gauss(x, sign * 0.064, 0.033) * _gauss(z, 2.014, 0.032)

    # One continuous nasal hierarchy: bridge -> dorsum -> tip and paired alae.
    bridge = 0.0110 * _gauss(x, 0.0, 0.010) * _gauss(z, 2.045, 0.049)
    dorsum = 0.0150 * _gauss(x, 0.0, 0.012) * _gauss(z, 2.018, 0.034)
    tip = 0.0300 * _gauss(x, 0.0, 0.014) * _gauss(z, 1.998, 0.015)
    alae = sum(0.0130 * _gauss(x, sign * 0.012, 0.008) * _gauss(z, 1.990, 0.010) for sign in (-1.0, 1.0))
    nostrils = sum(0.0050 * _gauss(x, sign * 0.009, 0.0048) * _gauss(z, 1.986, 0.0048) for sign in (-1.0, 1.0))

    muzzle = 0.0025 * _gauss(x, 0.0, 0.043) * _gauss(z, 1.975, 0.022)
    philtrum = 0.0020 * _gauss(x, 0.0, 0.0065) * _gauss(z, 1.976, 0.011)
    upper_lip = 0.0040 * _gauss(x, 0.0, 0.032) * _gauss(z, 1.969, 0.0045)
    lower_lip = 0.0048 * _gauss(x, 0.0, 0.034) * _gauss(z, 1.958, 0.0050)
    mouth_crease = 0.0030 * _gauss(x, 0.0, 0.037) * _gauss(z, 1.963, 0.0024)
    chin_pad = 0.0120 * _gauss(x, 0.0, 0.042) * _gauss(z, 1.923, 0.024)
    labiomental = 0.0030 * _gauss(x, 0.0, 0.037) * _gauss(z, 1.942, 0.005)
    jaw_plane = sum(0.0045 * _gauss(x, sign * 0.075, 0.029) * _gauss(z, 1.932, 0.038) for sign in (-1.0, 1.0))

    return (
        socket
        + nostrils
        + mouth_crease
        + labiomental
        - lid_rim
        - brow
        - cheek
        - bridge
        - dorsum
        - tip
        - alae
        - muzzle
        - philtrum
        - upper_lip
        - lower_lip
        - chin_pad
        - jaw_plane
    )


def _skin_weights(z: float, front: float) -> dict[str, float]:
    if z <= 1.825:
        t = _smoothstep(1.805, 1.825, z)
        return normalized({"chest": 0.22 * (1.0 - t), "neck": 0.78 + 0.22 * t})
    if z < 1.885:
        return {"neck": 1.0}
    if z < 1.925 and front < 0.42:
        t = _smoothstep(1.885, 1.925, z)
        return normalized({"neck": 1.0 - t, "head": t})
    if z < 2.005 and front > 0.18:
        lower = 1.0 - _smoothstep(1.905, 2.005, z)
        jaw = _clamp((0.32 + 0.56 * lower) * _smoothstep(0.18, 0.78, front), 0.0, 0.88)
        return normalized({"head": 1.0 - jaw, "jaw": jaw})
    return {"head": 1.0}


def _neck_depth(x: float, z: float, front: float) -> float:
    """Subtle sternomastoid V and throat plane break the cylinder silhouette."""
    if not 1.805 <= z <= 1.915 or front <= 0.0:
        return 0.0
    level = _smoothstep(1.805, 1.900, z)
    muscle_x = 0.057 - 0.024 * level
    muscle = sum(0.0045 * _gauss(x, sign * muscle_x, 0.014) for sign in (-1.0, 1.0))
    throat = 0.0035 * _gauss(x, 0.0, 0.020) * _gauss(z, 1.860, 0.050)
    return front**1.25 * (throat - muscle)


def _tag_skin(tags: dict[str, set[int]], index: int, x: float, y: float, z: float, front: float) -> None:
    if front > 0.68:
        for side, sign in (("L", -1.0), ("R", 1.0)):
            dx = abs(x - sign * EYE_X)
            dz = z - EYE_Z
            if dx < 0.027 and 0.001 < dz < 0.018:
                tags.setdefault(f"upper_lid.{side}", set()).add(index)
            if dx < 0.027 and -0.018 < dz <= 0.001:
                tags.setdefault(f"lower_lid.{side}", set()).add(index)
        if abs(x) < 0.056 and 2.063 < z < 2.096:
            tags.setdefault("brow_inner_raise", set()).add(index)
        if abs(x) < 0.039 and y < -0.060 and 1.952 < z < 1.974:
            tags.setdefault("lip", set()).add(index)
    if front > 0.20 and 1.895 < z < 1.998 and 0.026 < abs(x) < 0.105:
        tags.setdefault("jaw_clench", set()).add(index)


def _skin_surface() -> MeshPart:
    rows = _feature_rows()
    vertices: list[tuple[float, float, float]] = []
    weights: list[dict[str, float]] = []
    tags: dict[str, set[int]] = {}

    for base_z in rows:
        radius_x, radius_y, center_y, chin_drop = _profile_at(base_z)
        for side_index in range(SIDES):
            angle = math.tau * side_index / SIDES
            sine = math.sin(angle)
            cosine = math.cos(angle)
            front = max(0.0, cosine)
            x = radius_x * sine
            z = base_z - chin_drop * front**3

            # A controlled superelliptic widening at the lower side-front makes
            # a square heroic mandible without creating separate jaw blocks.
            jaw_corner = 0.0065 * _gauss(abs(x), 0.070, 0.030) * _gauss(z, 1.928, 0.037) * front**0.65
            if abs(x) > 1.0e-8:
                x += math.copysign(jaw_corner, x)
            y = center_y - radius_y * cosine
            if front > 0.0:
                y += _feature_depth(x, z) * front**1.55
                y += _neck_depth(x, z, front)

            index = len(vertices)
            vertices.append((x, y, z))
            weights.append(_skin_weights(z, front))
            _tag_skin(tags, index, x, y, z, front)

    faces: list[tuple[int, ...]] = []
    for row_index in range(len(rows) - 1):
        current = row_index * SIDES
        following_row = current + SIDES
        for side_index in range(SIDES):
            following = (side_index + 1) % SIDES
            faces.append((current + side_index, current + following, following_row + following, following_row + side_index))

    # The bottom disk is hidden inside the fitted collar.  The crown fan closes
    # onto the exact inherited head-bone tail height.
    bottom_index = len(vertices)
    vertices.append((0.0, _PROFILE[0][3], _PROFILE[0][0]))
    weights.append({"neck": 1.0})
    top_index = len(vertices)
    vertices.append((0.0, _PROFILE[-1][3], HEAD_TOP))
    weights.append({"head": 1.0})
    last = (len(rows) - 1) * SIDES
    for side_index in range(SIDES):
        following = (side_index + 1) % SIDES
        faces.append((bottom_index, following, side_index))
        faces.append((top_index, last + side_index, last + following))

    return MeshPart(vertices, faces, weights, SKIN, tags)


def _surface_y(x: float, z: float) -> float:
    """Evaluate the forward facial shell for fitted eye-mask placement."""
    radius_x, radius_y, center_y, _chin_drop = _profile_at(_clamp(z, _PROFILE[0][0], _PROFILE[-1][0]))
    horizontal = _clamp(abs(x) / max(radius_x, 1.0e-5))
    forward_cosine = math.sqrt(max(0.0, 1.0 - horizontal * horizontal))
    return center_y - radius_y * forward_cosine + _feature_depth(x, z) * forward_cosine**1.55


def _disc(
    center: tuple[float, float, float],
    radius_x: float,
    radius_z: float,
    segments: int,
    material: str,
    weights: dict[str, float],
    tag: str,
) -> MeshPart:
    vertices = [center]
    vertex_weights = [normalized(dict(weights))]
    tags = {tag: {0}}
    rings = (0.55, 1.0)
    for radius in rings:
        for index in range(segments):
            angle = math.tau * index / segments
            x = center[0] + radius_x * radius * math.cos(angle)
            z = center[2] + radius_z * radius * math.sin(angle)
            # Shallow convexity reads as iris/cornea, not a flat decal.
            y = center[1] - 0.0008 * (1.0 - radius)
            vertices.append((x, y, z))
            vertex_weights.append(normalized(dict(weights)))
            tags[tag].add(len(vertices) - 1)
    faces: list[tuple[int, ...]] = []
    for index in range(segments):
        following = (index + 1) % segments
        faces.append((0, 1 + index, 1 + following))
        first = 1 + index
        second = 1 + following
        outer_first = 1 + segments + index
        outer_second = 1 + segments + following
        faces.append((first, outer_first, outer_second, second))
    return MeshPart(vertices, faces, vertex_weights, material, tags)


def _append_eyes(assembly: MeshAssembly) -> None:
    for side, sign in (("L", -1.0), ("R", 1.0)):
        # Narrow vertical radius and near-flush front plane create an alert
        # squint instead of a round protruding globe.
        eye_center = (sign * EYE_X, EYE_Y + 0.002, EYE_Z)
        eye_weight = {f"eye.{side}": 1.0}
        assembly.append(
            ellipsoid(
                eye_center,
                (0.0195, 0.0078, 0.0076),
                22,
                10,
                GEAR,
                lambda _position, w=eye_weight: w,
                tagger=lambda _position: ("eye_sclera",),
            )
        )
        assembly.append(_disc((sign * EYE_X, EYE_Y - 0.0062, EYE_Z), 0.0050, 0.0046, 20, GEAR, eye_weight, "eye_iris"))
        assembly.append(_disc((sign * EYE_X, EYE_Y - 0.0070, EYE_Z), 0.0021, 0.0020, 16, GEAR, eye_weight, "eye_pupil"))


def _ear(side: str, sign: float) -> MeshPart:
    center_y = 0.007
    center_z = 2.020
    segments = 28
    radial_levels = (0.16, 0.42, 0.70, 1.0)
    vertices: list[tuple[float, float, float]] = []
    weights: list[dict[str, float]] = []
    for layer in (-0.5, 0.5):
        for radial in radial_levels:
            for index in range(segments):
                angle = math.tau * index / segments
                # Four concentric anatomical bands establish concha,
                # antihelix, and helix relief in a single pinna surface.
                relief = 0.0040 * _gauss(radial, 0.70, 0.18) - 0.0025 * _gauss(radial, 0.30, 0.13)
                x = sign * (0.106 + relief + layer * 0.0012)
                y = center_y - 0.020 * radial * math.cos(angle)
                z = center_z + 0.035 * radial * math.sin(angle) * (0.93 + 0.07 * math.cos(angle))
                vertices.append((x, y, z))
                weights.append({"head": 1.0})
    faces: list[tuple[int, ...]] = []
    layer_size = len(radial_levels) * segments
    for layer_index in range(2):
        layer_base = layer_index * layer_size
        for radial_index in range(len(radial_levels) - 1):
            inner = layer_base + radial_index * segments
            outer = inner + segments
            for index in range(segments):
                following = (index + 1) % segments
                face = (inner + index, outer + index, outer + following, inner + following)
                faces.append(face if layer_index == 0 else tuple(reversed(face)))
    # Seal only the outer helix; the inner edge lies inside the skull surface.
    outer_front = (len(radial_levels) - 1) * segments
    outer_back = layer_size + outer_front
    for index in range(segments):
        following = (index + 1) % segments
        faces.append((outer_front + index, outer_back + index, outer_back + following, outer_front + following))
    return MeshPart(vertices, faces, weights, SKIN, {f"ear.{side}": set(range(len(vertices)))})


def _scalp() -> MeshPart:
    """Close-cropped original hair cap with a natural, non-costume hairline."""
    row_count = 9
    vertices: list[tuple[float, float, float]] = []
    weights: list[dict[str, float]] = []
    tags: dict[str, set[int]] = {"hair": set()}
    for row in range(row_count):
        t = row / (row_count - 1)
        eased = _smoothstep(0.0, 1.0, t)
        for side_index in range(SIDES):
            angle = math.tau * side_index / SIDES
            sine = math.sin(angle)
            cosine = math.cos(angle)
            # Higher center-front line, modest temple recession, lower rear.
            hairline = 2.111 - 0.014 * abs(sine) ** 1.5 - 0.020 * max(0.0, -cosine)
            z = hairline * (1.0 - eased) + 2.157 * eased
            radius_x, radius_y, center_y, _drop = _profile_at(z)
            x = radius_x * sine * 1.010
            y = center_y + (center_y - radius_y * cosine - center_y) * 1.010
            z += 0.0012
            index = len(vertices)
            vertices.append((x, y, z))
            weights.append({"head": 1.0})
            tags["hair"].add(index)

    faces: list[tuple[int, ...]] = []
    for row in range(row_count - 1):
        current = row * SIDES
        following_row = current + SIDES
        for side_index in range(SIDES):
            following = (side_index + 1) % SIDES
            faces.append((current + side_index, current + following, following_row + following, following_row + side_index))
    top = len(vertices)
    vertices.append((0.0, _PROFILE[-1][3], HEAD_TOP + 0.0012))
    weights.append({"head": 1.0})
    tags["hair"].add(top)
    last = (row_count - 1) * SIDES
    for side_index in range(SIDES):
        following = (side_index + 1) % SIDES
        faces.append((top, last + side_index, last + following))
    return MeshPart(vertices, faces, weights, GEAR, tags)


def _mask_eye(side: str, sign: float) -> MeshPart:
    segments = 32
    center_x = sign * EYE_X
    outer: list[tuple[float, float]] = []
    inner: list[tuple[float, float]] = []
    for index in range(segments):
        angle = math.tau * index / segments
        cosine = math.cos(angle)
        sine = math.sin(angle)
        temple_bias = max(0.0, sign * cosine)
        arch_sign = -1.0 if sine < 0.0 else 1.0
        almond = arch_sign * (1.0 - abs(cosine)) ** 0.62
        inner_height = 0.0068 if sine < 0.0 else 0.0087
        outer_height = 0.0205 if sine < 0.0 else 0.0270
        inner.append((center_x + 0.0210 * cosine, EYE_Z + inner_height * almond))
        outer.append(
            (
                center_x + (0.0430 + 0.0035 * temple_bias) * cosine,
                EYE_Z + outer_height * almond + 0.0020 * temple_bias,
            )
        )

    vertices: list[tuple[float, float, float]] = []
    weights: list[dict[str, float]] = []
    tags: dict[str, set[int]] = {"mask": set(), "brow_inner_raise": set()}
    radial_levels = (0.0, 0.20, 0.40, 0.60, 0.80, 1.0)
    # Every radial sample is evaluated on the face, so broad quads follow brow
    # and cheek curvature instead of cutting through them like the r1 annulus.
    for depth in (0.0012, 0.0030):
        for radial in radial_levels:
            for (inner_x, inner_z), (outer_x, outer_z) in zip(inner, outer, strict=True):
                x = inner_x * (1.0 - radial) + outer_x * radial
                z = inner_z * (1.0 - radial) + outer_z * radial
                vertex_index = len(vertices)
                vertices.append((x, _surface_y(x, z) - depth, z))
                weights.append({"head": 1.0})
                tags["mask"].add(vertex_index)
                if abs(x) < 0.055 and z > EYE_Z + 0.008:
                    tags["brow_inner_raise"].add(vertex_index)

    faces: list[tuple[int, ...]] = []
    count = segments
    layer_size = len(radial_levels) * count
    for layer_index in range(2):
        layer_base = layer_index * layer_size
        for radial_index in range(len(radial_levels) - 1):
            inside = layer_base + radial_index * count
            outside = inside + count
            for index in range(count):
                following = (index + 1) % count
                face = (inside + index, outside + index, outside + following, inside + following)
                faces.append(face if layer_index == 1 else tuple(reversed(face)))
    inner_back = 0
    inner_front = layer_size
    outer_back = (len(radial_levels) - 1) * count
    outer_front = layer_size + outer_back
    for index in range(count):
        following = (index + 1) % count
        faces.append((inner_back + index, inner_back + following, inner_front + following, inner_front + index))
        faces.append((outer_back + index, outer_front + index, outer_front + following, outer_back + following))
    return MeshPart(vertices, faces, weights, GEAR, tags)


def _append_mask(assembly: MeshAssembly) -> None:
    for side, sign in (("L", -1.0), ("R", 1.0)):
        assembly.append(_mask_eye(side, sign))
        inner: list[tuple[float, float, float]] = []
        outer: list[tuple[float, float, float]] = []
        for index in range(12):
            t = index / 11.0
            x = sign * (0.078 + 0.027 * t)
            lower_z = EYE_Z - 0.017 + 0.010 * t
            upper_z = EYE_Z + 0.027 - 0.012 * t
            inner.append((x, _surface_y(x, lower_z) - 0.0021, lower_z))
            outer.append((x, _surface_y(x, upper_z) - 0.0021, upper_z))
        assembly.append(thick_ribbon(inner, outer, 0.0018, GEAR, {"head": 1.0}, "mask"))

    # Narrow raised bridge preserves two open eye shapes and avoids a helmet or
    # cowl silhouette.  It sits above the nasal bridge rather than covering it.
    bridge_vertices: list[tuple[float, float, float]] = []
    bridge_weights: list[dict[str, float]] = []
    bridge_tags: dict[str, set[int]] = {"mask": set(), "brow_inner_raise": set()}
    xs = (-0.020, -0.010, 0.0, 0.010, 0.020)
    for depth in (0.0012, 0.0030):
        for z in (EYE_Z + 0.004, EYE_Z + 0.022):
            for x in xs:
                index = len(bridge_vertices)
                bridge_vertices.append((x, _surface_y(x, z) - depth, z))
                bridge_weights.append({"head": 1.0})
                bridge_tags["mask"].add(index)
                bridge_tags["brow_inner_raise"].add(index)
    faces: list[tuple[int, ...]] = []
    row = len(xs)
    layer = row * 2
    for layer_index in range(2):
        base = layer_index * layer
        for index in range(row - 1):
            face = (base + index, base + index + 1, base + row + index + 1, base + row + index)
            faces.append(face if layer_index == 0 else tuple(reversed(face)))
    for index in range(row - 1):
        faces.append((index, layer + index, layer + index + 1, index + 1))
        faces.append((row + index, row + index + 1, layer + row + index + 1, layer + row + index))
    assembly.append(MeshPart(bridge_vertices, faces, bridge_weights, GEAR, bridge_tags))


def _assign_colors(obj: bpy.types.Object, tags: dict[str, set[int]]) -> None:
    """Populate COLOR_0-compatible values while retaining the five materials."""
    color = obj.data.color_attributes.get("Col")
    if color is None:
        color = obj.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    skin_slots = {index for index, material in enumerate(obj.data.materials) if material and material.name == SKIN}
    gear_slots = {index for index, material in enumerate(obj.data.materials) if material and material.name == GEAR}
    lip = tags.get("lip", set())
    sclera = tags.get("eye_sclera", set())
    iris = tags.get("eye_iris", set())
    pupil = tags.get("eye_pupil", set())
    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = obj.data.loops[loop_index].vertex_index
            if polygon.material_index in skin_slots:
                value = (0.95, 0.78, 0.74, 1.0) if vertex_index in lip else (1.0, 1.0, 1.0, 1.0)
            elif polygon.material_index in gear_slots and vertex_index in sclera:
                value = (0.80, 0.78, 0.70, 1.0)
            elif polygon.material_index in gear_slots and vertex_index in iris:
                value = (0.12, 0.20, 0.18, 1.0)
            elif polygon.material_index in gear_slots and vertex_index in pupil:
                value = (0.002, 0.003, 0.005, 1.0)
            elif polygon.material_index in gear_slots:
                value = (0.004, 0.006, 0.010, 1.0)
            else:
                value = (1.0, 1.0, 1.0, 1.0)
            color.data[loop_index].color = value
    obj.data.color_attributes.active_color = color


def _create_morphs(obj: bpy.types.Object, tags: dict[str, set[int]]) -> None:
    basis = obj.shape_key_add(name="Basis")
    basis.interpolation = "KEY_LINEAR"

    for side, sign in (("L", -1.0), ("R", 1.0)):
        key = obj.shape_key_add(name=f"blink.{side}")
        key.value = 0.0
        upper = tags[f"upper_lid.{side}"]
        lower = tags[f"lower_lid.{side}"]
        assert len(upper) >= 12 and len(lower) >= 12, (side, len(upper), len(lower))
        for indices, target_z in ((upper, EYE_Z + 0.0006), (lower, EYE_Z - 0.0006)):
            for vertex_index in indices:
                coordinate = key.data[vertex_index].co
                horizontal = _clamp(1.0 - abs(coordinate.x - sign * EYE_X) / 0.029)
                coordinate.z += (target_z - coordinate.z) * (0.72 + 0.28 * horizontal)
                coordinate.x += (sign * EYE_X - coordinate.x) * 0.025 * horizontal
                coordinate.y -= 0.0080 * horizontal

    brow = obj.shape_key_add(name="brow_inner_raise")
    brow.value = 0.0
    for vertex_index in tags.get("brow_inner_raise", set()):
        coordinate = brow.data[vertex_index].co
        strength = _clamp(1.0 - abs(coordinate.x) / 0.070)
        coordinate.z += 0.0090 * strength
        coordinate.y -= 0.0015 * strength

    jaw = obj.shape_key_add(name="jaw_clench")
    jaw.value = 0.0
    for vertex_index in tags.get("jaw_clench", set()):
        coordinate = jaw.data[vertex_index].co
        side_sign = -1.0 if coordinate.x < 0.0 else 1.0
        masseter = _gauss(abs(coordinate.x), 0.071, 0.035) * _gauss(coordinate.z, 1.940, 0.055)
        coordinate.x += side_sign * 0.0045 * masseter
        coordinate.y -= 0.0020 * masseter

    actual = tuple(block.name for block in obj.data.shape_keys.key_blocks if block.name != "Basis")
    assert actual == MORPH_NAMES, actual


def build_face(materials: dict[str, bpy.types.Material]) -> tuple[bpy.types.Object, dict[str, set[int]]]:
    """Build the export-ready `GV2_Face` object and semantic vertex tags."""
    assert set(MATERIAL_NAMES).issubset(materials), sorted(set(MATERIAL_NAMES) - set(materials))
    assert {"chest", "neck", "head", "jaw", "eye.L", "eye.R"}.issubset(BONE_NAMES)

    assembly = MeshAssembly()
    assembly.append(_skin_surface())
    _append_eyes(assembly)
    assembly.append(_ear("L", -1.0))
    assembly.append(_ear("R", 1.0))
    assembly.append(_scalp())
    _append_mask(assembly)

    obj = assembly.build("GV2_Face", materials)
    tags = {name: set(indices) for name, indices in assembly.tags.items()}
    smart_uv(obj, 0.006)
    triangulate(obj)
    _assign_colors(obj, tags)
    _create_morphs(obj, tags)

    triangle_count = len(obj.data.polygons)
    assert triangle_count < HEAD_TRIANGLE_BUDGET, triangle_count
    assert {material.name for material in obj.data.materials if material} == {SKIN, GEAR}
    obj["gloam_authoring"] = "v3 explicit connected face/neck quad surface; integrated features; no voxel or decimation"
    obj["gloam_head_triangles"] = triangle_count
    obj["gloam_head_contract"] = "v3-head-anatomy-1"
    return obj, tags
