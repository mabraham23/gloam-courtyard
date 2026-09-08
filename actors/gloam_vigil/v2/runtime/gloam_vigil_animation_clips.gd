extends RefCounted

## Hand-authored candidate animation clips. These are real Godot Animation
## resources sampled by the v2 rig adapter, rather than procedural sine aliases.
## Track paths are semantic channel names because the adapter must convert each
## body-space delta through the imported bone's rest axes before applying it.

const IDLE := &"idle"
const LOCOMOTION := &"locomotion"
const LOCOMOTION_R7 := &"locomotion_r7"
const START := &"start"
const STOP := &"stop"
const FACE_ALIVE := &"face_alive"


static func create_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	library.add_animation(IDLE, _idle_clip())
	library.add_animation(LOCOMOTION, _locomotion_clip())
	library.add_animation(LOCOMOTION_R7, _locomotion_r7_clip())
	library.add_animation(START, _start_clip())
	library.add_animation(STOP, _stop_clip())
	library.add_animation(FACE_ALIVE, _face_clip())
	return library


static func sample(library: AnimationLibrary, clip_name: StringName, time: float) -> Dictionary:
	var result: Dictionary = {}
	if library == null or not library.has_animation(clip_name):
		return result
	var clip := library.get_animation(clip_name)
	var sample_time := time
	if clip.loop_mode != Animation.LOOP_NONE:
		sample_time = fposmod(sample_time, clip.length)
	else:
		sample_time = clampf(sample_time, 0.0, clip.length)
	for track in clip.get_track_count():
		result[StringName(String(clip.track_get_path(track)))] = clip.value_track_interpolate(track, sample_time)
	return result


static func blend(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result := a.duplicate()
	var amount := clampf(weight, 0.0, 1.0)
	for channel in b:
		if not result.has(channel):
			# Animation channels are additive deltas from the imported rest pose.
			# A channel that exists only in locomotion must therefore fade in from
			# zero; copying it outright made the idle character march in place.
			var to_value: Variant = b[channel]
			if to_value is Vector3:
				result[channel] = Vector3.ZERO.lerp(to_value as Vector3, amount)
			elif to_value is float:
				result[channel] = lerpf(0.0, float(to_value), amount)
			else:
				result[channel] = to_value if amount >= 0.5 else null
			continue
		var from_value: Variant = result[channel]
		var to_value: Variant = b[channel]
		if from_value is Vector3 and to_value is Vector3:
			result[channel] = (from_value as Vector3).lerp(to_value as Vector3, amount)
		elif from_value is float and to_value is float:
			result[channel] = lerpf(from_value, to_value, amount)
	return result


static func add(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result := base.duplicate()
	for channel in overlay:
		if not result.has(channel):
			result[channel] = overlay[channel]
		elif result[channel] is Vector3 and overlay[channel] is Vector3:
			result[channel] = result[channel] + overlay[channel]
		elif result[channel] is float and overlay[channel] is float:
			result[channel] = result[channel] + overlay[channel]
	return result


static func _idle_clip() -> Animation:
	var clip := _new_clip(3.2, true)
	_add_keys(clip, &"pelvis", [[0.0, _v(0.0, -0.010, -0.010)], [0.72, _v(-0.010, 0.014, 0.008)], [1.63, _v(0.012, 0.006, -0.006)], [2.46, _v(-0.006, -0.016, 0.010)], [3.2, _v(0.0, -0.010, -0.010)]])
	_add_keys(clip, &"spine", [[0.0, _v(-0.010, 0.004, 0.0)], [0.92, _v(0.014, -0.006, 0.003)], [2.12, _v(-0.004, 0.005, -0.003)], [3.2, _v(-0.010, 0.004, 0.0)]])
	_add_keys(clip, &"spine_upper", [[0.0, _v(-0.006, 0.0, 0.0)], [0.92, _v(0.018, 0.004, -0.002)], [2.12, _v(-0.003, -0.004, 0.003)], [3.2, _v(-0.006, 0.0, 0.0)]])
	_add_keys(clip, &"chest", [[0.0, _v(-0.012, 0.0, 0.0)], [0.92, _v(0.022, 0.0, 0.0)], [2.12, _v(-0.006, 0.0, 0.0)], [3.2, _v(-0.012, 0.0, 0.0)]])
	_add_keys(clip, &"neck", [[0.0, _v(0.006, -0.012, 0.0)], [1.18, _v(-0.009, 0.015, 0.004)], [2.37, _v(0.004, -0.006, -0.003)], [3.2, _v(0.006, -0.012, 0.0)]])
	_add_keys(clip, &"head", [[0.0, _v(0.004, -0.014, 0.0)], [1.18, _v(-0.012, 0.018, 0.004)], [2.37, _v(0.006, -0.008, -0.004)], [3.2, _v(0.004, -0.014, 0.0)]])
	_add_keys(clip, &"clavicle.L", [[0.0, _v(0.0, 0.0, -0.012)], [0.92, _v(0.006, 0.0, -0.020)], [2.12, _v(-0.004, 0.0, -0.010)], [3.2, _v(0.0, 0.0, -0.012)]])
	_add_keys(clip, &"clavicle.R", [[0.0, _v(0.0, 0.0, 0.012)], [0.92, _v(0.004, 0.0, 0.020)], [2.12, _v(-0.006, 0.0, 0.010)], [3.2, _v(0.0, 0.0, 0.012)]])
	_add_keys(clip, &"upper_arm.L", [[0.0, _v(-0.045, 0.0, -0.025)], [1.41, _v(-0.026, 0.012, -0.018)], [3.2, _v(-0.045, 0.0, -0.025)]])
	_add_keys(clip, &"upper_arm.R", [[0.0, _v(0.050, 0.0, 0.025)], [1.41, _v(0.030, -0.010, 0.018)], [3.2, _v(0.050, 0.0, 0.025)]])
	_add_keys(clip, &"forearm.L", [[0.0, _v(0.16, 0.0, 0.0)], [1.55, _v(0.19, 0.0, 0.0)], [3.2, _v(0.16, 0.0, 0.0)]])
	_add_keys(clip, &"forearm.R", [[0.0, _v(0.19, 0.0, 0.0)], [1.55, _v(0.16, 0.0, 0.0)], [3.2, _v(0.19, 0.0, 0.0)]])
	_add_keys(clip, &"upper_arm_twist.L", [[0.0, _v(0.0, -0.018, 0.0)], [1.55, _v(0.0, 0.012, 0.0)], [3.2, _v(0.0, -0.018, 0.0)]])
	_add_keys(clip, &"upper_arm_twist.R", [[0.0, _v(0.0, 0.016, 0.0)], [1.55, _v(0.0, -0.010, 0.0)], [3.2, _v(0.0, 0.016, 0.0)]])
	_add_keys(clip, &"forearm_twist.L", [[0.0, _v(0.0, 0.028, 0.0)], [1.55, _v(0.0, -0.018, 0.0)], [3.2, _v(0.0, 0.028, 0.0)]])
	_add_keys(clip, &"forearm_twist.R", [[0.0, _v(0.0, -0.024, 0.0)], [1.55, _v(0.0, 0.020, 0.0)], [3.2, _v(0.0, -0.024, 0.0)]])
	_add_keys(clip, &"hand.L", [[0.0, _v(0.015, 0.018, -0.020)], [1.55, _v(-0.010, -0.016, -0.008)], [3.2, _v(0.015, 0.018, -0.020)]])
	_add_keys(clip, &"hand.R", [[0.0, _v(-0.012, -0.016, 0.018)], [1.55, _v(0.014, 0.014, 0.010)], [3.2, _v(-0.012, -0.016, 0.018)]])
	_add_finger_curl(clip, "L", 0.16, 0.21, 3.2)
	_add_finger_curl(clip, "R", 0.19, 0.15, 3.2)
	_add_cape_idle(clip, "L", -1.0)
	_add_cape_idle(clip, "R", 1.0)
	return clip


static func _locomotion_clip() -> Animation:
	var clip := _new_clip(1.0, true)
	# Five authored support poses: left contact, left toe-off, passing, right
	# toe-off, and return. The ball/toe keys create an actual heel-to-toe roll.
	var times := [0.0, 0.22, 0.50, 0.72, 1.0]
	# R7 moves at 4.8 m/s, so the cycle reads as a controlled tactical jog rather
	# than a slow runway walk. Keep the mass slightly forward over the support
	# foot and let the thorax counter-rotate instead of arching backward.
	_add_pose_keys(clip, &"pelvis", times, [_v(0.028, -0.035, -0.025), _v(0.042, 0.010, 0.032), _v(0.026, 0.035, 0.024), _v(0.044, -0.012, -0.034), _v(0.028, -0.035, -0.025)])
	_add_pose_keys(clip, &"spine", times, [_v(0.018, 0.018, 0.008), _v(0.030, -0.014, -0.010), _v(0.020, -0.018, -0.008), _v(0.028, 0.016, 0.010), _v(0.018, 0.018, 0.008)])
	_add_pose_keys(clip, &"spine_upper", times, [_v(0.018, 0.028, 0.010), _v(0.034, -0.020, -0.012), _v(0.020, -0.028, -0.010), _v(0.032, 0.022, 0.012), _v(0.018, 0.028, 0.010)])
	_add_pose_keys(clip, &"chest", times, [_v(0.026, 0.044, 0.012), _v(0.044, -0.034, -0.014), _v(0.028, -0.044, -0.012), _v(0.042, 0.036, 0.014), _v(0.026, 0.044, 0.012)])
	_add_pose_keys(clip, &"neck", times, [_v(-0.010, -0.016, -0.005), _v(-0.018, 0.010, 0.006), _v(-0.010, 0.016, 0.005), _v(-0.016, -0.012, -0.006), _v(-0.010, -0.016, -0.005)])
	_add_pose_keys(clip, &"head", times, [_v(-0.016, -0.026, -0.008), _v(-0.024, 0.018, 0.008), _v(-0.014, 0.026, 0.008), _v(-0.022, -0.020, -0.008), _v(-0.016, -0.026, -0.008)])
	# Each stance thigh sweeps rearward across its 0.22-cycle support interval.
	# At the gameplay's 4.8 m/s top speed this cancels most root travel before
	# the bounded stance solver makes the small remaining world-space correction.
	_add_pose_keys(clip, &"thigh.L", times, [_v(0.46, 0.0, -0.012), _v(-0.46, 0.0, 0.008), _v(-0.22, 0.0, 0.012), _v(0.10, 0.0, -0.008), _v(0.46, 0.0, -0.012)])
	_add_pose_keys(clip, &"thigh.R", times, [_v(-0.22, 0.0, -0.012), _v(0.10, 0.0, 0.008), _v(0.46, 0.0, 0.012), _v(-0.46, 0.0, -0.008), _v(-0.22, 0.0, -0.012)])
	_add_pose_keys(clip, &"shin.L", times, [_v(0.18, 0.0, 0.0), _v(0.42, 0.0, 0.0), _v(0.55, 0.0, 0.0), _v(0.25, 0.0, 0.0), _v(0.18, 0.0, 0.0)])
	_add_pose_keys(clip, &"shin.R", times, [_v(0.55, 0.0, 0.0), _v(0.25, 0.0, 0.0), _v(0.18, 0.0, 0.0), _v(0.42, 0.0, 0.0), _v(0.55, 0.0, 0.0)])
	_add_pose_keys(clip, &"foot.L", times, [_v(-0.08, 0.0, 0.0), _v(-0.22, 0.0, 0.0), _v(0.12, 0.0, 0.0), _v(0.04, 0.0, 0.0), _v(-0.08, 0.0, 0.0)])
	_add_pose_keys(clip, &"foot.R", times, [_v(0.10, 0.0, 0.0), _v(0.02, 0.0, 0.0), _v(-0.08, 0.0, 0.0), _v(-0.24, 0.0, 0.0), _v(0.10, 0.0, 0.0)])
	_add_pose_keys(clip, &"ball.L", times, [_v(0.02, 0.0, 0.0), _v(0.24, 0.0, 0.0), _v(-0.08, 0.0, 0.0), _v(0.0, 0.0, 0.0), _v(0.02, 0.0, 0.0)])
	_add_pose_keys(clip, &"ball.R", times, [_v(-0.08, 0.0, 0.0), _v(0.0, 0.0, 0.0), _v(0.02, 0.0, 0.0), _v(0.26, 0.0, 0.0), _v(-0.08, 0.0, 0.0)])
	_add_pose_keys(clip, &"toe.L", times, [_v(-0.03, 0.0, 0.0), _v(0.18, 0.0, 0.0), _v(-0.05, 0.0, 0.0), _v(0.0, 0.0, 0.0), _v(-0.03, 0.0, 0.0)])
	_add_pose_keys(clip, &"toe.R", times, [_v(-0.05, 0.0, 0.0), _v(0.0, 0.0, 0.0), _v(-0.03, 0.0, 0.0), _v(0.20, 0.0, 0.0), _v(-0.05, 0.0, 0.0)])
	_add_pose_keys(clip, &"clavicle.L", times, [_v(-0.02, 0.0, -0.04), _v(0.01, 0.0, -0.02), _v(0.03, 0.0, -0.01), _v(0.0, 0.0, -0.03), _v(-0.02, 0.0, -0.04)])
	_add_pose_keys(clip, &"clavicle.R", times, [_v(0.03, 0.0, 0.01), _v(0.0, 0.0, 0.03), _v(-0.02, 0.0, 0.04), _v(0.01, 0.0, 0.02), _v(0.03, 0.0, 0.01)])
	# Arms counter-swing their opposite legs. The prior ipsilateral pairing was
	# mechanically valid but read immediately as an unnatural march.
	_add_pose_keys(clip, &"upper_arm.L", times, [_v(0.30, -0.015, -0.035), _v(0.12, -0.008, -0.025), _v(-0.30, 0.015, -0.020), _v(-0.10, 0.008, -0.028), _v(0.30, -0.015, -0.035)])
	_add_pose_keys(clip, &"upper_arm.R", times, [_v(-0.30, 0.015, 0.020), _v(-0.10, 0.008, 0.028), _v(0.30, -0.015, 0.035), _v(0.12, -0.008, 0.025), _v(-0.30, 0.015, 0.020)])
	_add_pose_keys(clip, &"forearm.L", times, [_v(0.18, 0.0, 0.0), _v(0.22, 0.0, 0.0), _v(0.34, 0.0, 0.0), _v(0.26, 0.0, 0.0), _v(0.18, 0.0, 0.0)])
	_add_pose_keys(clip, &"forearm.R", times, [_v(0.34, 0.0, 0.0), _v(0.26, 0.0, 0.0), _v(0.18, 0.0, 0.0), _v(0.22, 0.0, 0.0), _v(0.34, 0.0, 0.0)])
	_add_pose_keys(clip, &"thigh_twist.L", times, [_v(0.0, -0.035, 0.0), _v(0.0, 0.026, 0.0), _v(0.0, 0.018, 0.0), _v(0.0, -0.014, 0.0), _v(0.0, -0.035, 0.0)])
	_add_pose_keys(clip, &"thigh_twist.R", times, [_v(0.0, -0.018, 0.0), _v(0.0, 0.014, 0.0), _v(0.0, 0.035, 0.0), _v(0.0, -0.026, 0.0), _v(0.0, -0.018, 0.0)])
	_add_pose_keys(clip, &"shin_twist.L", times, [_v(0.0, 0.018, 0.0), _v(0.0, -0.030, 0.0), _v(0.0, -0.016, 0.0), _v(0.0, 0.012, 0.0), _v(0.0, 0.018, 0.0)])
	_add_pose_keys(clip, &"shin_twist.R", times, [_v(0.0, 0.016, 0.0), _v(0.0, -0.012, 0.0), _v(0.0, -0.018, 0.0), _v(0.0, 0.030, 0.0), _v(0.0, 0.016, 0.0)])
	_add_pose_keys(clip, &"upper_arm_twist.L", times, [_v(0.0, -0.08, 0.0), _v(0.0, -0.03, 0.0), _v(0.0, 0.08, 0.0), _v(0.0, 0.03, 0.0), _v(0.0, -0.08, 0.0)])
	_add_pose_keys(clip, &"upper_arm_twist.R", times, [_v(0.0, 0.08, 0.0), _v(0.0, 0.03, 0.0), _v(0.0, -0.08, 0.0), _v(0.0, -0.03, 0.0), _v(0.0, 0.08, 0.0)])
	_add_pose_keys(clip, &"forearm_twist.L", times, [_v(0.0, 0.10, 0.0), _v(0.0, 0.04, 0.0), _v(0.0, -0.09, 0.0), _v(0.0, -0.03, 0.0), _v(0.0, 0.10, 0.0)])
	_add_pose_keys(clip, &"forearm_twist.R", times, [_v(0.0, -0.10, 0.0), _v(0.0, -0.04, 0.0), _v(0.0, 0.09, 0.0), _v(0.0, 0.03, 0.0), _v(0.0, -0.10, 0.0)])
	_add_pose_keys(clip, &"hand.L", times, [_v(0.02, 0.045, -0.035), _v(-0.01, 0.020, -0.020), _v(-0.025, -0.040, -0.012), _v(0.0, -0.015, -0.025), _v(0.02, 0.045, -0.035)])
	_add_pose_keys(clip, &"hand.R", times, [_v(-0.025, -0.040, 0.012), _v(0.0, -0.015, 0.025), _v(0.02, 0.045, 0.035), _v(-0.01, 0.020, 0.020), _v(-0.025, -0.040, 0.012)])
	_add_finger_curl(clip, "L", 0.20, 0.28, 1.0)
	_add_finger_curl(clip, "R", 0.28, 0.20, 1.0)
	_add_cape_walk(clip, "L", -1.0)
	_add_cape_walk(clip, "R", 1.0)
	return clip


static func _locomotion_r7_clip() -> Animation:
	var clip := _new_clip(1.0, true)
	# R7's longer anatomical legs need a real running gait rather than the v2
	# scaffold's five broad pendulum poses. These thirteen keys describe heel
	# contact, load, toe-off, early swing, maximum swing flex and pre-contact.
	# Left support is 0.25-0.40; right support is the half-cycle mirror at
	# 0.75-0.90. The prior curve did the opposite: it flexed the stance knee most
	# and left the swing leg nearly straight, which read as gliding in live play.
	var times := [0.0, 0.08, 0.20, 0.25, 0.35, 0.45, 0.50, 0.58, 0.70, 0.75, 0.85, 0.95, 1.0]

	_add_pose_keys(clip, &"pelvis", times, [
		_v(0.012, -0.018, 0.0), _v(0.014, -0.030, -0.012), _v(0.018, -0.024, -0.030),
		_v(0.020, -0.010, -0.038), _v(0.018, 0.018, -0.022), _v(0.012, 0.030, -0.006),
		_v(0.012, 0.018, 0.0), _v(0.014, 0.030, 0.012), _v(0.018, 0.024, 0.030),
		_v(0.020, 0.010, 0.038), _v(0.018, -0.018, 0.022), _v(0.012, -0.030, 0.006),
		_v(0.012, -0.018, 0.0),
	])
	_add_pose_keys(clip, &"spine", times, _alternating_core(times, 0.010, 0.016, -0.014))
	_add_pose_keys(clip, &"spine_upper", times, _alternating_core(times, 0.014, 0.024, -0.020))
	_add_pose_keys(clip, &"chest", times, _alternating_core(times, 0.018, 0.034, -0.028))
	_add_pose_keys(clip, &"neck", times, _alternating_core(times, -0.010, -0.014, 0.012))
	_add_pose_keys(clip, &"head", times, _alternating_core(times, -0.014, -0.020, 0.016))

	# Positive thigh X carries the foot behind the body; negative X brings it
	# forward. Knee flex peaks only after toe-off, then opens before heel strike.
	_add_pose_keys(clip, &"thigh.L", times, [
		_v(-0.34, 0.0, -0.010), _v(-0.42, 0.0, -0.010), _v(-0.46, 0.0, -0.008),
		_v(-0.42, 0.0, -0.006), _v(-0.06, 0.0, 0.004), _v(0.34, 0.0, 0.010),
		_v(0.42, 0.0, 0.012), _v(0.46, 0.0, 0.012), _v(0.28, 0.0, 0.008),
		_v(0.18, 0.0, 0.004), _v(-0.10, 0.0, -0.002), _v(-0.28, 0.0, -0.008),
		_v(-0.34, 0.0, -0.010),
	])
	_add_pose_keys(clip, &"thigh.R", times, [
		_v(0.42, 0.0, -0.012), _v(0.46, 0.0, -0.012), _v(0.28, 0.0, -0.008),
		_v(0.18, 0.0, -0.004), _v(-0.10, 0.0, 0.002), _v(-0.28, 0.0, 0.008),
		_v(-0.34, 0.0, 0.010), _v(-0.42, 0.0, 0.010), _v(-0.46, 0.0, 0.008),
		_v(-0.42, 0.0, 0.006), _v(-0.06, 0.0, -0.004), _v(0.34, 0.0, -0.010),
		_v(0.42, 0.0, -0.012),
	])
	_add_pose_keys(clip, &"shin.L", times, [
		_v(0.55, 0.0, 0.0), _v(0.38, 0.0, 0.0), _v(0.22, 0.0, 0.0),
		_v(0.18, 0.0, 0.0), _v(0.24, 0.0, 0.0), _v(0.42, 0.0, 0.0),
		_v(0.82, 0.0, 0.0), _v(1.08, 0.0, 0.0), _v(0.95, 0.0, 0.0),
		_v(0.88, 0.0, 0.0), _v(0.70, 0.0, 0.0), _v(0.58, 0.0, 0.0),
		_v(0.55, 0.0, 0.0),
	])
	_add_pose_keys(clip, &"shin.R", times, [
		_v(0.82, 0.0, 0.0), _v(1.08, 0.0, 0.0), _v(0.95, 0.0, 0.0),
		_v(0.88, 0.0, 0.0), _v(0.70, 0.0, 0.0), _v(0.58, 0.0, 0.0),
		_v(0.55, 0.0, 0.0), _v(0.38, 0.0, 0.0), _v(0.22, 0.0, 0.0),
		_v(0.18, 0.0, 0.0), _v(0.24, 0.0, 0.0), _v(0.42, 0.0, 0.0),
		_v(0.82, 0.0, 0.0),
	])
	_add_pose_keys(clip, &"foot.L", times, [
		_v(0.06, 0.0, 0.0), _v(0.01, 0.0, 0.0), _v(-0.10, 0.0, 0.0),
		_v(-0.12, 0.0, 0.0), _v(0.02, 0.0, 0.0), _v(-0.24, 0.0, 0.0),
		_v(-0.10, 0.0, 0.0), _v(0.18, 0.0, 0.0), _v(0.16, 0.0, 0.0),
		_v(0.12, 0.0, 0.0), _v(0.08, 0.0, 0.0), _v(0.08, 0.0, 0.0),
		_v(0.06, 0.0, 0.0),
	])
	_add_pose_keys(clip, &"foot.R", times, [
		_v(-0.10, 0.0, 0.0), _v(0.18, 0.0, 0.0), _v(0.16, 0.0, 0.0),
		_v(0.12, 0.0, 0.0), _v(0.08, 0.0, 0.0), _v(0.08, 0.0, 0.0),
		_v(0.06, 0.0, 0.0), _v(0.01, 0.0, 0.0), _v(-0.10, 0.0, 0.0),
		_v(-0.12, 0.0, 0.0), _v(0.02, 0.0, 0.0), _v(-0.24, 0.0, 0.0),
		_v(-0.10, 0.0, 0.0),
	])

	# Heel-to-toe articulation and a compact, contralateral arm carriage make
	# the speed read as a tactical run without a permanent exaggerated lean.
	_add_pose_keys(clip, &"ball.L", times, _r7_toe_curve(times, false, 1.0))
	_add_pose_keys(clip, &"toe.L", times, _r7_toe_curve(times, false, 0.68))
	_add_pose_keys(clip, &"ball.R", times, _r7_toe_curve(times, true, 1.0))
	_add_pose_keys(clip, &"toe.R", times, _r7_toe_curve(times, true, 0.68))
	_add_pose_keys(clip, &"upper_arm.L", times, _r7_arm_curve(times, false))
	_add_pose_keys(clip, &"upper_arm.R", times, _r7_arm_curve(times, true))
	_add_pose_keys(clip, &"forearm.L", times, _r7_forearm_curve(times, false))
	_add_pose_keys(clip, &"forearm.R", times, _r7_forearm_curve(times, true))
	_add_pose_keys(clip, &"thigh_twist.L", times, _r7_twist_curve(times, false, 0.040))
	_add_pose_keys(clip, &"thigh_twist.R", times, _r7_twist_curve(times, true, -0.040))
	_add_pose_keys(clip, &"shin_twist.L", times, _r7_twist_curve(times, false, -0.028))
	_add_pose_keys(clip, &"shin_twist.R", times, _r7_twist_curve(times, true, 0.028))
	_add_finger_curl(clip, "L", 0.18, 0.26, 1.0)
	_add_finger_curl(clip, "R", 0.26, 0.18, 1.0)
	_add_cape_walk(clip, "L", -1.0)
	_add_cape_walk(clip, "R", 1.0)
	return clip


static func _alternating_core(times: Array, pitch: float, yaw: float, roll: float) -> Array:
	var result: Array = []
	for time_value in times:
		var phase := float(time_value) * TAU
		result.append(_v(pitch, cos(phase) * yaw, sin(phase) * roll))
	return result


static func _r7_toe_curve(times: Array, mirrored: bool, scale: float) -> Array:
	var result: Array = []
	for time_value in times:
		var cycle := fposmod(float(time_value) + (0.5 if mirrored else 0.0), 1.0)
		var roll := 0.0
		if cycle >= 0.25 and cycle < 0.35:
			roll = lerpf(-0.04, 0.06, inverse_lerp(0.25, 0.35, cycle))
		elif cycle >= 0.35 and cycle < 0.45:
			roll = lerpf(0.06, 0.30, inverse_lerp(0.35, 0.45, cycle))
		elif cycle >= 0.45 and cycle < 0.58:
			roll = lerpf(0.30, -0.08, inverse_lerp(0.45, 0.58, cycle))
		result.append(_v(roll * scale, 0.0, 0.0))
	return result


static func _r7_arm_curve(times: Array, mirrored: bool) -> Array:
	var result: Array = []
	for time_value in times:
		var phase := float(time_value) * TAU + (PI if mirrored else 0.0)
		var swing := cos(phase) * 0.40
		result.append(_v(swing, -sin(phase) * 0.025, 0.030 if mirrored else -0.030))
	return result


static func _r7_forearm_curve(times: Array, mirrored: bool) -> Array:
	var result: Array = []
	for time_value in times:
		var phase := float(time_value) * TAU + (PI if mirrored else 0.0)
		result.append(_v(0.92 + maxf(cos(phase), 0.0) * 0.20, 0.0, 0.0))
	return result


static func _r7_twist_curve(times: Array, mirrored: bool, amount: float) -> Array:
	var result: Array = []
	for time_value in times:
		var phase := float(time_value) * TAU + (PI if mirrored else 0.0)
		result.append(_v(0.0, sin(phase) * amount, 0.0))
	return result


static func _start_clip() -> Animation:
	var clip := _new_clip(0.42, false)
	_add_keys(clip, &"pelvis", [[0.0, Vector3.ZERO], [0.13, _v(0.07, -0.035, -0.030)], [0.27, _v(-0.025, 0.020, 0.018)], [0.42, Vector3.ZERO]])
	_add_keys(clip, &"spine_upper", [[0.0, Vector3.ZERO], [0.13, _v(0.045, 0.018, 0.012)], [0.30, _v(-0.018, -0.012, -0.008)], [0.42, Vector3.ZERO]])
	_add_keys(clip, &"clavicle.L", [[0.0, Vector3.ZERO], [0.18, _v(0.025, 0.0, -0.025)], [0.42, Vector3.ZERO]])
	_add_keys(clip, &"clavicle.R", [[0.0, Vector3.ZERO], [0.18, _v(-0.020, 0.0, 0.020)], [0.42, Vector3.ZERO]])
	return clip


static func _stop_clip() -> Animation:
	var clip := _new_clip(0.34, false)
	_add_keys(clip, &"pelvis", [[0.0, Vector3.ZERO], [0.10, _v(0.08, 0.025, 0.025)], [0.23, _v(-0.035, -0.012, -0.012)], [0.34, Vector3.ZERO]])
	_add_keys(clip, &"spine_upper", [[0.0, Vector3.ZERO], [0.10, _v(0.055, -0.018, -0.010)], [0.24, _v(-0.020, 0.010, 0.006)], [0.34, Vector3.ZERO]])
	_add_keys(clip, &"shin.L", [[0.0, Vector3.ZERO], [0.11, _v(0.10, 0.0, 0.0)], [0.34, Vector3.ZERO]])
	_add_keys(clip, &"shin.R", [[0.0, Vector3.ZERO], [0.11, _v(0.12, 0.0, 0.0)], [0.34, Vector3.ZERO]])
	return clip


static func _face_clip() -> Animation:
	var clip := _new_clip(5.2, true)
	_add_keys(clip, &"eye.L", [[0.0, _v(0.0, -0.018, 0.0)], [1.35, _v(0.012, 0.022, 0.0)], [3.05, _v(-0.008, -0.012, 0.0)], [4.18, _v(0.006, 0.008, 0.0)], [5.2, _v(0.0, -0.018, 0.0)]])
	_add_keys(clip, &"eye.R", [[0.0, _v(0.0, -0.014, 0.0)], [1.35, _v(0.010, 0.018, 0.0)], [3.05, _v(-0.006, -0.016, 0.0)], [4.18, _v(0.005, 0.012, 0.0)], [5.2, _v(0.0, -0.014, 0.0)]])
	_add_keys(clip, &"jaw", [[0.0, Vector3.ZERO], [1.80, _v(0.008, 0.0, 0.0)], [3.60, _v(-0.004, 0.0, 0.0)], [5.2, Vector3.ZERO]])
	_add_keys(clip, &"morph_blink_L", [[0.0, 0.0], [0.76, 0.0], [0.82, 1.0], [0.89, 0.0], [3.37, 0.0], [3.43, 0.86], [3.51, 0.0], [5.2, 0.0]], Animation.INTERPOLATION_LINEAR)
	_add_keys(clip, &"morph_blink_R", [[0.0, 0.0], [0.77, 0.0], [0.83, 1.0], [0.90, 0.0], [3.39, 0.0], [3.45, 0.92], [3.52, 0.0], [5.2, 0.0]], Animation.INTERPOLATION_LINEAR)
	_add_keys(clip, &"morph_brow_inner_raise", [[0.0, 0.04], [1.20, 0.10], [2.75, 0.02], [4.10, 0.08], [5.2, 0.04]])
	_add_keys(clip, &"morph_jaw_clench", [[0.0, 0.08], [1.80, 0.13], [3.60, 0.06], [5.2, 0.08]])
	return clip


static func _new_clip(length: float, looped: bool) -> Animation:
	var clip := Animation.new()
	clip.length = length
	clip.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	return clip


static func _add_pose_keys(clip: Animation, channel: StringName, times: Array, values: Array) -> void:
	var keys: Array = []
	for index in times.size():
		keys.append([times[index], values[index]])
	_add_keys(clip, channel, keys)


static func _add_keys(clip: Animation, channel: StringName, keys: Array, interpolation := Animation.INTERPOLATION_CUBIC) -> void:
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath(String(channel)))
	clip.track_set_interpolation_type(track, interpolation)
	for key in keys:
		clip.track_insert_key(track, key[0], key[1])


static func _add_finger_curl(clip: Animation, side: String, first: float, second: float, length: float) -> void:
	for finger in ["thumb", "index", "middle", "ring", "pinky"]:
		var character := 0.72 if finger == "thumb" else (0.88 if finger == "pinky" else 1.0)
		for segment in range(1, 4):
			var segment_scale := character * (0.72 + float(segment) * 0.12)
			var channel := StringName("%s.%02d.%s" % [finger, segment, side])
			_add_keys(clip, channel, [
				[0.0, _v(first * segment_scale, 0.0, 0.0)],
				[length * 0.48, _v(second * segment_scale, 0.0, 0.0)],
				[length, _v(first * segment_scale, 0.0, 0.0)],
			])


static func _add_cape_idle(clip: Animation, side: String, sign: float) -> void:
	var channels := ["cape.%s" % side, "cape_mid.%s" % side, "cape_lower.%s" % side, "cape_tip.%s" % side]
	for index in channels.size():
		var amount := 0.018 + float(index) * 0.018
		_add_keys(clip, StringName(channels[index]), [
			[0.0, _v(-0.025 - amount, 0.0, sign * amount * 0.30)],
			[1.05, _v(-0.010 + amount, sign * amount * 0.18, -sign * amount * 0.24)],
			[2.28, _v(-0.035, -sign * amount * 0.12, sign * amount * 0.18)],
			[3.2, _v(-0.025 - amount, 0.0, sign * amount * 0.30)],
		])


static func _add_cape_walk(clip: Animation, side: String, sign: float) -> void:
	var channels := ["cape.%s" % side, "cape_mid.%s" % side, "cape_lower.%s" % side, "cape_tip.%s" % side]
	for index in channels.size():
		var lag := float(index) * 0.035
		var amount := 0.055 + float(index) * 0.055
		_add_keys(clip, StringName(channels[index]), [
			[0.0, _v(-0.04, sign * amount * 0.16, sign * amount * 0.32)],
			[0.22 + lag, _v(amount * 0.50, -sign * amount * 0.24, -sign * amount * 0.62)],
			[0.50, _v(-0.03, -sign * amount * 0.12, -sign * amount * 0.28)],
			[minf(0.72 + lag, 0.94), _v(amount * 0.45, sign * amount * 0.22, sign * amount * 0.60)],
			[1.0, _v(-0.04, sign * amount * 0.16, sign * amount * 0.32)],
		])


static func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)
