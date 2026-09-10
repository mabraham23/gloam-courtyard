extends "res://work/action-quality/upper_body_sequence.gd"

## Actual posed skeleton audit through the same rendered controller fixture.
## Reposition/reset frames are excluded. Angles are parent-local, so camera,
## world travel and the intentional somersault cannot disguise a pose snap.
const JOINTS := [&"pelvis", &"spine", &"spine_upper", &"chest", &"neck", &"head",
	&"clavicle.L", &"clavicle.R", &"upper_arm.L", &"upper_arm.R", &"forearm.L", &"forearm.R",
	&"thigh.L", &"thigh.R", &"shin.L", &"shin.R", &"foot.L", &"foot.R"]
var previous: Dictionary = {}
var previous_state := ""
var seams: Array[Dictionary] = []
var worst: Array[Dictionary] = []
var peak_step := 0.0
var peak_seam := 0.0
var stop_peak := 0.0

func _reset() -> void:
	super._reset()
	previous.clear()
	previous_state = ""

func _process(delta: float) -> bool:
	if not started: return false
	var sample_frame := frame
	super._process(delta)
	var skeleton: Skeleton3D = game.player_visual_parts["authored_rig"]["skeleton"]
	var state := _pose_name()
	var step := 0.0
	var joint := ""
	for bone: StringName in JOINTS:
		var q := skeleton.get_bone_pose_rotation(skeleton.find_bone(bone))
		if previous.has(bone):
			var angle := rad_to_deg((previous[bone] as Quaternion).angle_to(q))
			if angle > step:
				step = angle
				joint = String(bone)
		previous[bone] = q
	var sample := {"frame": sample_frame, "from": previous_state, "to": state, "joint": joint, "step_deg": step}
	if previous_state != "" and previous_state != state:
		seams.append(sample)
		peak_seam = maxf(peak_seam, step)
	peak_step = maxf(peak_step, step)
	if sample_frame >= 50 and sample_frame <= 60:
		stop_peak = maxf(stop_peak, step)
	if step > 25.0:
		worst.append(sample)
	previous_state = state
	if sample_frame == 479:
		print("MOTION_CONTINUITY_REPORT ", JSON.stringify({"fps":30,"seams":seams,"steps_above_25_deg":worst,
			"peak_step_deg":peak_step,"peak_seam_deg":peak_seam,"stop_peak_deg":stop_peak}))
		# These detect the previously observed 86-112 degree discontinuities in
		# actual controller output, including snaps displaced inside a transition.
		# Fast strike/roll arcs have more allowance than a released walk or seam.
		var passed := peak_seam <= 35.0 and stop_peak <= 40.0 and peak_step <= 65.0
		print("MOTION_CONTINUITY_", "OK" if passed else "FAILED", " checks=3 fps=30")
		quit(0 if passed else 1)
	return false

func _pose_name() -> String:
	if game.player_takedown_timer > 0: return "takedown"
	if game.grapple_active: return "grapple"
	if game.grapple_recovery_timer > 0: return "grapple_recover"
	if game.jump_active:
		if game.jump_is_vault: return "vault"
		var elapsed: float = game.jump_t * game.jump_duration
		if elapsed < game.JUMP_PREPARE_DURATION: return "jump_prepare"
		if elapsed < game.JUMP_PREPARE_DURATION + game.JUMP_FLIGHT_DURATION: return "jump"
		return "jump_land"
	if game.invulnerable > 0: return "evade"
	if game.player_airborne: return "fall"
	if game.player_counter_timer > 0: return "counter"
	if game.player_strike_timer > 0: return "strike:" + String(game.player_attack_variant)
	if game.crouching: return "crouch"
	return "grounded"
