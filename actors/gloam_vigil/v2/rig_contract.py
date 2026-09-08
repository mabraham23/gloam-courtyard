"""Stable authored-scene contract for the second Gloam Vigil candidate.

Coordinates are Blender metres in the authored bind pose: +Z is up and the
character looks toward -Y.  The twenty legacy names remain present while the
extra deform bones provide twist, hands, face, feet, and a segmented cape.
"""

from __future__ import annotations

from dataclasses import dataclass


ASSET_ID = "gloam_vigil_v2"
ASSET_VERSION = 2
RIG_CONTRACT = "gloam-vigil-v2-rig-1"
FORWARD_AXIS = "-Y"

MATERIAL_NAMES = (
    "MAT_GV2_Suit_Cloth",
    "MAT_GV2_Skin",
    "MAT_GV2_Gear",
    "MAT_GV2_Tactical_Boot",
    "MAT_GV2_Accent",
)

MORPH_NAMES = (
    "blink.L",
    "blink.R",
    "brow_inner_raise",
    "jaw_clench",
)

LEGACY_BONE_NAMES = (
    "root",
    "pelvis",
    "spine",
    "chest",
    "neck",
    "head",
    "thigh.L",
    "shin.L",
    "foot.L",
    "upper_arm.L",
    "forearm.L",
    "hand.L",
    "cape.L",
    "thigh.R",
    "shin.R",
    "foot.R",
    "upper_arm.R",
    "forearm.R",
    "hand.R",
    "cape.R",
)

FOOT_CONTACT_GROUPS = (
    "foot.L",
    "ball.L",
    "toe.L",
    "foot.R",
    "ball.R",
    "toe.R",
)


@dataclass(frozen=True)
class BoneSpec:
    name: str
    head: tuple[float, float, float]
    tail: tuple[float, float, float]
    parent: str | None = None
    semantic: str = "core"


def _finger_specs(side: str, sign: float) -> list[BoneSpec]:
    # The relaxed hand hangs beside the thigh.  Each phalanx is a real deform
    # segment with its own geometry; the thumb angles inward and forward.
    layouts = {
        "thumb": (0.370, -0.068, 0.830, 0.735, -0.014),
        "index": (0.387, -0.072, 0.820, 0.705, -0.004),
        "middle": (0.404, -0.066, 0.818, 0.695, 0.000),
        "ring": (0.421, -0.056, 0.821, 0.710, 0.004),
        "pinky": (0.438, -0.042, 0.828, 0.738, 0.008),
    }
    result: list[BoneSpec] = []
    for finger, (abs_x, y, z_top, z_tip, y_drift) in layouts.items():
        x = sign * abs_x
        zs = (z_top, z_top + (z_tip - z_top) / 3.0, z_top + 2.0 * (z_tip - z_top) / 3.0, z_tip)
        ys = (y, y + y_drift / 3.0, y + 2.0 * y_drift / 3.0, y + y_drift)
        parent = f"hand.{side}"
        for index in range(3):
            name = f"{finger}.{index + 1:02d}.{side}"
            result.append(BoneSpec(name, (x, ys[index], zs[index]), (x, ys[index + 1], zs[index + 1]), parent, "finger"))
            parent = name
    return result


def bone_specs() -> tuple[BoneSpec, ...]:
    specs: list[BoneSpec] = [
        BoneSpec("root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.25), None, "root"),
        BoneSpec("pelvis", (0.0, 0.0, 1.00), (0.0, 0.0, 1.18), "root", "core"),
        BoneSpec("spine", (0.0, 0.0, 1.16), (0.0, 0.0, 1.38), "pelvis", "core"),
        BoneSpec("spine_upper", (0.0, 0.0, 1.36), (0.0, 0.0, 1.56), "spine", "core"),
        BoneSpec("chest", (0.0, 0.0, 1.54), (0.0, 0.0, 1.72), "spine_upper", "core"),
        BoneSpec("neck", (0.0, 0.0, 1.70), (0.0, 0.0, 1.88), "chest", "neck"),
        BoneSpec("head", (0.0, 0.0, 1.86), (0.0, 0.0, 2.16), "neck", "head"),
        BoneSpec("jaw", (0.0, -0.018, 2.015), (0.0, -0.055, 1.920), "head", "face"),
        BoneSpec("eye.L", (-0.039, -0.072, 2.048), (-0.039, -0.112, 2.048), "head", "face"),
        BoneSpec("eye.R", (0.039, -0.072, 2.048), (0.039, -0.112, 2.048), "head", "face"),
    ]

    for side, sign in (("L", -1.0), ("R", 1.0)):
        # Major anchors intentionally retain the accepted v1 hip/knee/ankle
        # and shoulder/elbow/wrist locations.  Twist bones split, rather than
        # move, those spans.
        specs.extend(
            [
                BoneSpec(f"thigh.{side}", (sign * 0.120, 0.0, 1.08), (sign * 0.120, -0.003, 0.84), "pelvis", "leg"),
                BoneSpec(f"thigh_twist.{side}", (sign * 0.120, -0.003, 0.84), (sign * 0.120, -0.006, 0.62), f"thigh.{side}", "leg_twist"),
                BoneSpec(f"shin.{side}", (sign * 0.120, -0.006, 0.62), (sign * 0.120, -0.003, 0.40), f"thigh_twist.{side}", "leg"),
                BoneSpec(f"shin_twist.{side}", (sign * 0.120, -0.003, 0.40), (sign * 0.120, 0.0, 0.16), f"shin.{side}", "leg_twist"),
                BoneSpec(f"foot.{side}", (sign * 0.120, 0.0, 0.16), (sign * 0.120, -0.140, 0.082), f"shin_twist.{side}", "foot"),
                BoneSpec(f"ball.{side}", (sign * 0.120, -0.140, 0.082), (sign * 0.120, -0.245, 0.068), f"foot.{side}", "foot"),
                BoneSpec(f"toe.{side}", (sign * 0.120, -0.245, 0.068), (sign * 0.120, -0.315, 0.060), f"ball.{side}", "foot"),
                BoneSpec(f"clavicle.{side}", (sign * 0.055, 0.0, 1.68), (sign * 0.255, 0.0, 1.68), "chest", "shoulder"),
                BoneSpec(f"upper_arm.{side}", (sign * 0.255, 0.0, 1.68), (sign * 0.345, -0.004, 1.47), f"clavicle.{side}", "arm"),
                BoneSpec(f"upper_arm_twist.{side}", (sign * 0.345, -0.004, 1.47), (sign * 0.390, -0.006, 1.25), f"upper_arm.{side}", "arm_twist"),
                BoneSpec(f"forearm.{side}", (sign * 0.390, -0.006, 1.25), (sign * 0.386, -0.018, 1.08), f"upper_arm_twist.{side}", "arm"),
                BoneSpec(f"forearm_twist.{side}", (sign * 0.386, -0.018, 1.08), (sign * 0.380, -0.030, 0.93), f"forearm.{side}", "arm_twist"),
                BoneSpec(f"hand.{side}", (sign * 0.380, -0.030, 0.93), (sign * 0.404, -0.055, 0.815), f"forearm_twist.{side}", "hand"),
            ]
        )
        specs.extend(_finger_specs(side, sign))
        specs.extend(
            [
                BoneSpec(f"cape.{side}", (sign * 0.105, 0.102, 1.705), (sign * 0.125, 0.155, 1.445), "chest", "cape"),
                BoneSpec(f"cape_mid.{side}", (sign * 0.125, 0.155, 1.445), (sign * 0.155, 0.215, 1.150), f"cape.{side}", "cape"),
                BoneSpec(f"cape_lower.{side}", (sign * 0.155, 0.215, 1.150), (sign * 0.182, 0.258, 0.830), f"cape_mid.{side}", "cape"),
                BoneSpec(f"cape_tip.{side}", (sign * 0.182, 0.258, 0.830), (sign * 0.195, 0.275, 0.535), f"cape_lower.{side}", "cape"),
            ]
        )

    assert len(specs) == 74, len(specs)
    assert len({spec.name for spec in specs}) == len(specs)
    assert set(LEGACY_BONE_NAMES).issubset(spec.name for spec in specs)
    return tuple(specs)


BONE_SPECS = bone_specs()
BONE_NAMES = tuple(spec.name for spec in BONE_SPECS)
BONE_BY_NAME = {spec.name: spec for spec in BONE_SPECS}
