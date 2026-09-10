extends RefCounted

## Presentation-only jump phrase. The controller owns grounded preparation,
## airborne translation and grounded recovery; these curves only pose the body.
static func sample(state: StringName, progress: float, moving: bool, lead: float) -> Dictionary:
	var p := clampf(progress, 0.0, 1.0)
	var compression := 0.0
	var split := 0.0
	var lift := 0.0
	var landing_ready := 0.0
	if state == &"jump_prepare":
		compression = smoothstep(0.0, 0.85, p)
	elif state == &"jump_land":
		# Flex after touchdown, then recover through the legs rather than dropping
		# the body before it reaches the floor and snapping straight on contact.
		# Stay in the loaded pose long enough for the smoothed rig to receive
		# the impact. The old narrow peak was mostly filtered out at runtime.
		compression = lerpf(0.32, 1.70, smoothstep(0.0, 0.24, p)) * (1.0 - smoothstep(0.58, 1.0, p))
	else:
		compression = 1.0 - smoothstep(0.0, 0.24, p)
		lift = smoothstep(0.02, 0.24, p) * (1.0 - smoothstep(0.62, 0.94, p))
		split = lift if moving else 0.0
		landing_ready = smoothstep(0.76, 1.0, p) * 0.32
	compression += landing_ready
	var side := clampf(lead, -1.0, 1.0)
	var thigh_base := -0.32 * compression + 0.02 * split - 0.025 * lift
	var thigh_split := (0.40 * split + 0.025 * lift * (1.0 - float(moving))) * side
	var knee_base := 0.055 + 0.64 * compression + 0.59 * split + 0.045 * lift
	var knee_split := 0.11 * split * side
	return {
		"thigh": Vector2(thigh_base - thigh_split, thigh_base + thigh_split),
		"knee": Vector2(knee_base + knee_split, knee_base - knee_split),
		"ankle": -0.30 * compression - 0.05 * lift,
		"arm": Vector2(-0.26 * compression - 0.36 * lift + 0.48 * split * side,
			-0.26 * compression - 0.36 * lift - 0.48 * split * side),
		# Carry the bent running arms through the leap instead of reaching out
		# with almost locked elbows. Subtle opposite variation mirrors the lead.
		"elbow": Vector2(0.35 + 0.16 * lift + 0.72 * split + 0.25 * compression + 0.08 * split * side,
			0.35 + 0.16 * lift + 0.72 * split + 0.25 * compression - 0.08 * split * side),
		"arm_spread": 0.055 + 0.07 * lift,
		"rise": -0.12 * compression,
		"pelvis": 0.10 * compression + 0.04 * split,
		"torso": 0.14 * compression + 0.065 * split,
		"head": -0.08 * compression - 0.03 * split,
		"tail": 0.22 * lift + 0.08 * compression,
	}
