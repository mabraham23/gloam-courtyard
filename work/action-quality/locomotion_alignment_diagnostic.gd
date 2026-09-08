extends SceneTree

## Measures the two user-reported exact-R7 locomotion defects through the real
## controller: frontal-plane leg flare and cumulative upper-body forward lean.
## This is a read-only diagnostic and never owns gameplay root motion.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const RunReference = preload("res://actors/gloam_vigil/v4/motion/cmu_run_reference.gd")

const SAMPLE_FPS := 60
const WARMUP_FRAMES := 18
const SAMPLE_FRAMES := 84

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := load("res://main_3d.tscn").instantiate() as Node3D
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	game.reset_game()
	game.player_root.position = Vector3(-6.0, 0.0, 4.8)
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.attack_cooldown = 999.0

	var rig: Dictionary = game.player_visual_parts["authored_rig"]
	var neutral := _measure_pose(rig, game.player_root)
	var aggregate := {
		"left_knee_flare_deg": [], "right_knee_flare_deg": [],
		"knee_separation_m": [], "ankle_separation_m": [],
		"torso_position_pitch_deg": [], "chest_rotation_pitch_deg": [],
		"foot_yaw_left_deg": [], "foot_yaw_right_deg": [],
		"root_speed_mps": [],
	}
	game.held_keys[KEY_D] = true
	for frame in WARMUP_FRAMES + SAMPLE_FRAMES:
		var root_before: Vector3 = game.player_root.position
		game._process(1.0 / SAMPLE_FPS)
		if frame >= WARMUP_FRAMES:
			var current := _measure_pose(rig, game.player_root)
			_append(aggregate, "left_knee_flare_deg", float(current["left_knee_flare_deg"]) - float(neutral["left_knee_flare_deg"]))
			_append(aggregate, "right_knee_flare_deg", float(current["right_knee_flare_deg"]) - float(neutral["right_knee_flare_deg"]))
			_append(aggregate, "knee_separation_m", float(current["knee_separation_m"]))
			_append(aggregate, "ankle_separation_m", float(current["ankle_separation_m"]))
			_append(aggregate, "torso_position_pitch_deg", _angle_delta(float(neutral["torso_position_pitch_deg"]), float(current["torso_position_pitch_deg"])))
			_append(aggregate, "chest_rotation_pitch_deg", _angle_delta(float(neutral["chest_rotation_pitch_deg"]), float(current["chest_rotation_pitch_deg"])))
			_append(aggregate, "foot_yaw_left_deg", _angle_delta(float(neutral["foot_yaw_left_deg"]), float(current["foot_yaw_left_deg"])))
			_append(aggregate, "foot_yaw_right_deg", _angle_delta(float(neutral["foot_yaw_right_deg"]), float(current["foot_yaw_right_deg"])))
			_append(aggregate, "root_speed_mps", root_before.distance_to(game.player_root.position) * SAMPLE_FPS)
	game.held_keys.erase(KEY_D)

	var source := _source_ranges()
	var moving: Dictionary = _summaries(aggregate, WARMUP_FRAMES)
	_require(absf(float(moving["root_speed_mps"]["mean"]) - 4.8) < 0.03, "gameplay root speed remains 4.8")
	_require(float(moving["chest_rotation_pitch_deg"]["mean"]) < 8.0, "mean chest pitch is below 8 degrees")
	_require(float(moving["chest_rotation_pitch_deg"]["max"]) < 11.0, "peak chest pitch is below 11 degrees")
	_require(float(moving["torso_position_pitch_deg"]["mean"]) < 12.0, "mean pelvis-to-chest lean is below 12 degrees")
	_require(float(moving["left_knee_flare_deg"]["max"]) < 5.0, "left captured knee flare is below 5 degrees over neutral")
	_require(float(moving["right_knee_flare_deg"]["max"]) < 8.0, "right captured knee flare is below 8 degrees over neutral")
	_require(float(moving["knee_separation_m"]["max"]) < float(neutral["knee_separation_m"]) + 0.05, "peak knee separation stays within 5 cm of neutral width")
	_require(float(moving["knee_separation_m"]["min"]) > float(neutral["knee_separation_m"]) - 0.02, "legs retain a natural uncrossed stance width")
	_require(float(moving["ankle_separation_m"]["max"]) < float(neutral["ankle_separation_m"]) + 0.10, "ankle swing width remains bounded")
	_require(maxf(absf(float(moving["foot_yaw_left_deg"]["min"])), absf(float(moving["foot_yaw_right_deg"]["min"]))) < 23.0, "foot progression stays below 23 degrees from neutral")
	var report := {
		"asset_sha256": FileAccess.get_sha256(Candidate.ASSET_PATH),
		"retarget_sha256": RunReference.data_sha256(),
		"fps": SAMPLE_FPS,
		"neutral": neutral,
		"moving": moving,
		"retarget_channel_euler_ranges_deg": source,
	}
	print("R7_LOCOMOTION_ALIGNMENT_REPORT ", JSON.stringify(report))
	for label in failures:
		print("FAIL ", label)
	print("R7_LOCOMOTION_ALIGNMENT_", "OK" if failures.is_empty() else "FAILED", " checks=10 failures=", failures.size())
	game.queue_free()
	quit(0 if failures.is_empty() else 1)


func _measure_pose(rig: Dictionary, actor: Node3D) -> Dictionary:
	var skeleton := rig["skeleton"] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var to_actor := actor.global_transform.affine_inverse() * skeleton.global_transform
	var pelvis := _position(skeleton, to_actor, &"pelvis")
	var chest := _position(skeleton, to_actor, &"chest")
	var hip_l := _position(skeleton, to_actor, &"thigh.L")
	var hip_r := _position(skeleton, to_actor, &"thigh.R")
	var knee_l := _position(skeleton, to_actor, &"shin.L")
	var knee_r := _position(skeleton, to_actor, &"shin.R")
	var ankle_l := _position(skeleton, to_actor, &"foot.L")
	var ankle_r := _position(skeleton, to_actor, &"foot.R")
	return {
		"left_knee_flare_deg": _frontal_angle(hip_l, knee_l),
		"right_knee_flare_deg": _frontal_angle(hip_r, knee_r),
		"knee_separation_m": absf(knee_l.x - knee_r.x),
		"ankle_separation_m": absf(ankle_l.x - ankle_r.x),
		"torso_position_pitch_deg": rad_to_deg(atan2(chest.z - pelvis.z, maxf(chest.y - pelvis.y, 0.0001))),
		"chest_rotation_pitch_deg": rad_to_deg(_basis(skeleton, to_actor, &"chest").get_euler().x),
		"foot_yaw_left_deg": rad_to_deg(_basis(skeleton, to_actor, &"foot.L").get_euler().y),
		"foot_yaw_right_deg": rad_to_deg(_basis(skeleton, to_actor, &"foot.R").get_euler().y),
	}


func _position(skeleton: Skeleton3D, to_actor: Transform3D, bone_name: StringName) -> Vector3:
	var index := skeleton.find_bone(bone_name)
	assert(index >= 0)
	return to_actor * skeleton.get_bone_global_pose(index).origin


func _basis(skeleton: Skeleton3D, to_actor: Transform3D, bone_name: StringName) -> Basis:
	var index := skeleton.find_bone(bone_name)
	assert(index >= 0)
	return (to_actor.basis * skeleton.get_bone_global_pose(index).basis).orthonormalized()


func _frontal_angle(hip: Vector3, knee: Vector3) -> float:
	return rad_to_deg(atan2(absf(knee.x - hip.x), maxf(absf(knee.y - hip.y), 0.0001)))


func _append(values: Dictionary, key: String, value: float) -> void:
	(values[key] as Array).append(value)


func _summaries(values: Dictionary, frame_offset: int = 0) -> Dictionary:
	var result := {}
	for key: String in values:
		var samples: Array = values[key]
		var minimum := INF
		var maximum := -INF
		var minimum_index := -1
		var maximum_index := -1
		var total := 0.0
		for index in samples.size():
			var value: float = samples[index]
			if value < minimum:
				minimum = value
				minimum_index = index
			if value > maximum:
				maximum = value
				maximum_index = index
			total += value
		result[key] = {
			"min": minimum, "min_frame": minimum_index + frame_offset,
			"mean": total / samples.size(),
			"max": maximum, "max_frame": maximum_index + frame_offset,
		}
	return result


func _source_ranges() -> Dictionary:
	var values := {}
	for channel in [&"pelvis", &"spine", &"spine_upper", &"chest", &"thigh.L", &"thigh.R", &"shin.L", &"shin.R", &"foot.L", &"foot.R"]:
		values[String(channel)] = {"x": [], "y": [], "z": []}
	for index in 96:
		var reference: Dictionary = RunReference.sample(TAU * float(index) / 96.0)
		for channel: StringName in reference["rotations"]:
			if not values.has(String(channel)):
				continue
			var euler := (reference["rotations"][channel] as Quaternion).get_euler()
			(values[String(channel)]["x"] as Array).append(rad_to_deg(euler.x))
			(values[String(channel)]["y"] as Array).append(rad_to_deg(euler.y))
			(values[String(channel)]["z"] as Array).append(rad_to_deg(euler.z))
	var result := {}
	for channel: String in values:
		result[channel] = _summaries(values[channel])
	return result


func _angle_delta(neutral: float, current: float) -> float:
	return rad_to_deg(wrapf(deg_to_rad(current - neutral), -PI, PI))


func _require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
