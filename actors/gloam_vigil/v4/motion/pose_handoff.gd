extends RefCounted

## A short bridge between the candidate's captured and procedural poses.
## Only a change of action or start/stop intent enables it; steady clips and
## calibrated contact frames are not low-pass filtered. No root translation.
const AttackCatalog = preload("res://actors/player_attack_catalog.gd")
const MAX_OUTGOING_SPEED := 8.0

static func apply(rig: Dictionary, state: StringName, variant: StringName, movement: float, delta: float) -> void:
	var skeleton: Skeleton3D = rig["skeleton"]
	var target: Array[Quaternion] = []
	for index in skeleton.get_bone_count():
		target.append(skeleton.get_bone_pose_rotation(index))
	var history: Dictionary = rig.get("pose_handoff", {})
	var mode: String = history.get("mode", "idle")
	var old_movement: float = history.get("movement", movement)
	if movement > old_movement + 0.001:
		mode = "moving"
	elif movement < old_movement - 0.001:
		mode = "idle"
	var key := String(state)
	if state == &"grounded": key += ":" + mode
	if state == &"strike": key += ":" + String(variant)
	# Reset and low-clearance crouch deliberately request a direct pose. Do not
	# carry inertia through a teleport or delay the required lintel silhouette.
	if history.is_empty() or delta <= 0.0 or delta >= 0.25:
		rig["pose_handoff"] = {"key":key, "state":state, "mode":mode, "movement":movement,
			"previous":target, "velocity":[], "elapsed":1.0, "duration":0.0}
		return
	var previous: Array = history["previous"]
	if key != String(history["key"]):
		history["from_state"] = history["state"]
		history["start"] = previous.duplicate()
		history["outgoing"] = (history["velocity"] as Array).duplicate()
		history["elapsed"] = 0.0
		history["duration"] = _duration(history["state"], state, variant)
	var duration: float = history["duration"]
	var elapsed: float = float(history["elapsed"]) + delta
	var velocity: Array[Vector3] = []
	for index in target.size():
		var result: Quaternion = target[index]
		if elapsed < duration:
			var bone := String(skeleton.get_bone_name(index))
			# Foot placement settles sooner than the arms; rising out of a deep
			# crouch needs the full interval to avoid straightening in one frame.
			var joint_duration := duration
			if state == &"grounded" and history["from_state"] != &"crouch" and (bone.begins_with("thigh") or bone.begins_with("shin") or bone.begins_with("foot")):
				joint_duration = minf(duration, 0.16)
			var blend := smoothstep(0.0, joint_duration, elapsed)
			var start: Quaternion = history["start"][index]
			var outgoing: Array = history["outgoing"]
			if outgoing.size() == target.size():
				var omega: Vector3 = outgoing[index]
				if omega.length() > 0.0001:
					var carry_time := joint_duration * 0.5 * (1.0 - exp(-2.0 * elapsed / joint_duration))
					start = start * Quaternion(omega.normalized(), omega.length() * carry_time)
			result = start.slerp(result, blend).normalized()
			skeleton.set_bone_pose_rotation(index, result)
		var step: Quaternion = ((previous[index] as Quaternion).inverse() * result).normalized()
		if step.w < 0.0: step = -step
		var angle := step.get_angle()
		velocity.append(step.get_axis() * minf(angle / delta, MAX_OUTGOING_SPEED) if angle > 0.0001 else Vector3.ZERO)
		target[index] = result
	history["key"] = key
	history["state"] = state
	history["mode"] = mode
	history["movement"] = movement
	history["previous"] = target
	history["velocity"] = velocity
	history["elapsed"] = elapsed
	rig["pose_handoff"] = history

static func _duration(previous: StringName, state: StringName, variant: StringName) -> float:
	if state == &"grounded": return 0.24 if previous == &"crouch" else 0.22
	if state == &"strike": return 0.12 if AttackCatalog.kind(variant) == &"kick" else 0.055
	if state == &"jump_prepare": return 0.10
	if previous in [&"jump_prepare", &"jump", &"jump_land"] and state in [&"jump", &"jump_land"]: return 0.0
	if state == &"evade": return 0.04
	if state in [&"grapple", &"vault"]: return 0.07
	if state in [&"counter", &"hurt", &"downed"]: return 0.075
	return 0.14
