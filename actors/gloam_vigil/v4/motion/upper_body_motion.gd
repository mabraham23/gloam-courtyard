extends RefCounted

## Small body-space offsets over the existing pose. The spine bends at several
## joints, the shoulder girdle follows the ribs, and the head steadies the gaze.
## No pelvis/leg/root channels: contact, travel and action timing stay owned by
## their existing solvers. The adapter eases this layer across action changes.
const CHANNELS := [&"spine", &"spine_upper", &"chest", &"neck", &"head", &"clavicle.L", &"clavicle.R", &"cape.L", &"cape.R"]

static func sample(state: StringName, progress: float, phase: float, movement: float) -> Dictionary:
	var p := clampf(progress, 0.0, 1.0)
	var flex := 0.0
	var turn := 0.0
	var sway := 0.0
	var shoulder := 0.0
	var shoulder_swing := 0.0
	var cape := Vector3.ZERO
	var breath := sin(phase * 0.62 + 0.7)
	match state:
		&"grounded":
			var travel := smoothstep(0.04, 0.82, clampf(movement, 0.0, 1.0))
			# A relaxed thoracic curve, not a waist hinge. The small twice-stride
			# yield is delayed from footfall; rotation counters the pelvis transfer.
			flex = 0.016 + 0.075 * travel + 0.010 * sin(phase * 2.0 - 0.55) * travel + 0.006 * breath * (1.0 - travel)
			turn = -0.055 * sin(phase - 0.28) * travel
			sway = 0.012 * sin(phase - 0.55) * travel
			shoulder = 0.015 + 0.022 * travel
			shoulder_swing = 0.045 * sin(phase - 0.48) * travel
		&"crouch":
			var travel := smoothstep(0.08, 0.92, p)
			# The torso is already low. Only deepen its curve slightly and let
			# each shoulder follow the quiet crouch step without lifting the head.
			flex = 0.024 + 0.003 * breath * (1.0 - travel)
			turn = -0.022 * sin(phase - 0.25) * travel
			sway = 0.006 * sin(phase - 0.45) * travel
			shoulder = 0.020
			shoulder_swing = 0.030 * sin(phase - 0.40) * travel
			# Keep the hanging cloth's direction as the ribs move beneath it.
			# Letting the extra thoracic fold rotate the entire long cape upward
			# clipped the large build into the lintel despite improved head room.
			cape = -Vector3(flex, turn, sway)
		&"jump_prepare":
			flex = 0.075 * smoothstep(0.0, 0.95, p)
			shoulder = -0.035 * smoothstep(0.0, 0.9, p)
		&"jump":
			var release := 1.0 - smoothstep(0.0, 0.32, p)
			var rise := smoothstep(0.05, 0.32, p) * (1.0 - smoothstep(0.55, 0.88, p))
			flex = 0.075 * release - 0.035 * rise + 0.030 * smoothstep(0.76, 1.0, p)
			shoulder = -0.035 * release + 0.045 * rise
		&"jump_land":
			var catch := smoothstep(0.0, 0.28, p) * (1.0 - smoothstep(0.56, 1.0, p))
			flex = 0.030 * (1.0 - p) + 0.10 * catch
			shoulder = -0.055 * catch
		&"vault", &"grapple":
			var reach := sin(p * PI)
			flex = -0.035 * reach
			turn = 0.025 * reach
			shoulder = 0.055 * reach
			shoulder_swing = 0.025 * reach
		&"grapple_recover":
			flex = 0.060 * sin(p * PI)
			shoulder = -0.025 * sin(p * PI)
		&"counter":
			flex = 0.045 * sin(p * PI)
			shoulder_swing = 0.055 * sin(p * PI)
		&"fall":
			flex = 0.025
			shoulder = 0.030
		&"hurt":
			flex = -0.035 * sin(p * PI)
			shoulder = -0.035 * sin(p * PI)
	# Strikes, the compact roll, takedown and downed already have large authored
	# core curves. They fade this small layer out; their own channels retain sole
	# ownership of contact poses. Punch sequencing lives in r7_action_reference.
	return {
		&"spine": Vector3(flex * 0.16, turn * 0.20, sway * 0.16),
		&"spine_upper": Vector3(flex * 0.36, turn * 0.34, sway * 0.34),
		&"chest": Vector3(flex * 0.48, turn * 0.46, sway * 0.50),
		&"neck": Vector3(-flex * 0.24, -turn * 0.28, -sway * 0.25),
		&"head": Vector3(-flex * 0.32, -turn * 0.36, -sway * 0.35),
		&"clavicle.L": Vector3(-shoulder - shoulder_swing * 0.35, shoulder * 0.65 + shoulder_swing, -shoulder * 0.30),
		&"clavicle.R": Vector3(-shoulder + shoulder_swing * 0.35, -shoulder * 0.65 + shoulder_swing, shoulder * 0.30),
		&"cape.L": cape,
		&"cape.R": cape,
	}
