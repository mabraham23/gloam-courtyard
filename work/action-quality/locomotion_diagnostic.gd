extends SceneTree

## Read-only held-input locomotion trace for the exact R7 review candidate.
## This intentionally drives the real courtyard controller at 60 Hz, including
## movement blending, authored locomotion, retargeting and the stance solver.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const R7RunReference = preload("res://actors/gloam_vigil/v4/motion/cmu_run_reference.gd")

const TRACE_SECONDS := 1.50
const IDLE_SECONDS := 0.25
const STOP_SECONDS := 0.25

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _run() -> void:
	var reports: Array = []
	for fps in [30, 60]:
		reports.append(_run_rate(fps, false))
		reports.append(_run_rate(fps, true))
		reports.append(_run_controller_case(fps))
	print("GLOAM_LOCOMOTION_DIAGNOSTIC_REPORT ", JSON.stringify(reports))
	print("GLOAM_LOCOMOTION_DIAGNOSTIC_", "OK" if failures.is_empty() else "FAILED", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _run_rate(fps: int, with_shift: bool) -> Dictionary:
	var mode := "shift_held" if with_shift else "plain_wasd"
	var expected_speed := 4.8
	var game := load("res://main_3d.tscn").instantiate() as Node3D
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	game.reset_game()
	# The bounded trace stays clear of world clamps and courtyard blockers.
	game.player_root.position = Vector3(-6.0, 0.0, 4.8)
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)

	var rig: Dictionary = game.player_visual_parts["authored_rig"]
	var left_min := INF
	var left_max := -INF
	var right_min := INF
	var right_max := -INF
	var support_max := {"L": 0.0, "R": 0.0}
	var swing_max := {"L": 0.0, "R": 0.0}
	var blocked_frames := {"L": 0, "R": 0}
	var plant_frames := {"L": 0, "R": 0}
	var support_speed_sum := {"L": 0.0, "R": 0.0}
	var support_speed_count := {"L": 0, "R": 0}
	var swing_speed_sum := {"L": 0.0, "R": 0.0}
	var swing_speed_count := {"L": 0, "R": 0}
	var knee_plane_max := {"L": 0.0, "R": 0.0}
	var previous_feet := {"L": Vector3.ZERO, "R": Vector3.ZERO}
	var feet_valid := false
	var move_speed_sum := 0.0
	var move_speed_count := 0
	var start_phase := -1.0
	var settle_frame := -1
	var idle_frames := int(round(IDLE_SECONDS * fps))
	var move_frames := int(round(TRACE_SECONDS * fps))
	var stop_frames := int(round(STOP_SECONDS * fps))
	var release_frame := idle_frames + move_frames
	var delta := 1.0 / float(fps)
	for frame in idle_frames + move_frames + stop_frames:
		if frame == idle_frames:
			game.held_keys[KEY_D] = true
			if with_shift:
				game.held_keys[KEY_SHIFT] = true
		if frame == release_frame:
			game.held_keys.erase(KEY_D)
			game.held_keys.erase(KEY_SHIFT)
		var before: Vector3 = game.player_root.position
		game._process(delta)
		var frame_speed := before.distance_to(game.player_root.position) / delta
		var measuring := frame >= idle_frames + int(round(0.35 * fps)) and frame < release_frame
		if frame == idle_frames:
			start_phase = fposmod(game.player_step_phase, TAU)
		if measuring:
			move_speed_sum += frame_speed
			move_speed_count += 1
		if frame >= idle_frames and frame < release_frame:
			require(absf(game.player_root.position.x) < 8.85 and absf(game.player_root.position.z) < 4.95, "%d Hz trace remains inside world clamps" % fps)
			require(not game.is_in_low_passage(game.player_root.position), "%d Hz trace avoids low passage" % fps)
			require(not game.is_inside_vault_obstacle(game.player_root.position), "%d Hz trace avoids vault blocker" % fps)
		elif frame >= release_frame and settle_frame < 0 and game.player_move_blend <= 0.001:
			settle_frame = frame - release_frame
		var left_flex := _knee_flex(rig, "L")
		var right_flex := _knee_flex(rig, "R")
		left_min = minf(left_min, left_flex)
		left_max = maxf(left_max, left_flex)
		right_min = minf(right_min, right_flex)
		right_max = maxf(right_max, right_flex)
		var cycle := fposmod(game.player_step_phase, TAU) / TAU
		for side in ["L", "R"]:
			var flex := left_flex if side == "L" else right_flex
			var chain := _chain_positions(rig, game.player_root, side)
			var upper_length: float = (chain["hip"] as Vector3).distance_to(chain["knee"] as Vector3)
			var lower_length: float = (chain["knee"] as Vector3).distance_to(chain["ankle"] as Vector3)
			var chain_amount := upper_length / maxf(upper_length + lower_length, 0.001)
			var expected_knee_x := lerpf((chain["hip"] as Vector3).x, (chain["ankle"] as Vector3).x, chain_amount)
			knee_plane_max[side] = maxf(float(knee_plane_max[side]), absf((chain["knee"] as Vector3).x - expected_knee_x))
			var foot_position := _foot_world(rig, side)
			var foot_speed := foot_position.distance_to(previous_feet[side]) / delta if feet_valid else 0.0
			if measuring and _is_support(cycle, side):
				support_max[side] = maxf(float(support_max[side]), rad_to_deg(flex))
				support_speed_sum[side] = float(support_speed_sum[side]) + foot_speed
				support_speed_count[side] = int(support_speed_count[side]) + 1
			elif measuring:
				swing_max[side] = maxf(float(swing_max[side]), rad_to_deg(flex))
				swing_speed_sum[side] = float(swing_speed_sum[side]) + foot_speed
				swing_speed_count[side] = int(swing_speed_count[side]) + 1
			if bool(rig["foot_plants"][side]["blocked"]):
				blocked_frames[side] = int(blocked_frames[side]) + 1
			if bool(rig["foot_plants"][side]["active"]):
				plant_frames[side] = int(plant_frames[side]) + 1
			previous_feet[side] = foot_position
		feet_valid = true

	var report := {
		"asset_path": Candidate.ASSET_PATH,
		"asset_sha256": FileAccess.get_sha256(Candidate.ASSET_PATH),
		"mode": mode,
		"motion_source_sha256": R7RunReference.source_sha256(),
		"retarget_sha256": R7RunReference.data_sha256(),
		"fps": fps,
		"speed": expected_speed,
		"actual_mean_speed": move_speed_sum / maxf(float(move_speed_count), 1.0),
		"phase_rate": R7RunReference.cycle_rate(),
		"final_run_blend": game.player_run_blend,
		"start_phase_radians": start_phase,
		"stop_settle_frames": settle_frame,
		"left_knee_range_degrees": [rad_to_deg(left_min), rad_to_deg(left_max)],
		"right_knee_range_degrees": [rad_to_deg(right_min), rad_to_deg(right_max)],
		"support_max_degrees": support_max,
		"swing_max_degrees": swing_max,
		"blocked_frames": blocked_frames,
		"plant_frames": plant_frames,
		"knee_plane_max": knee_plane_max,
		"support_mean_foot_speed": {
			"L": float(support_speed_sum["L"]) / maxf(float(support_speed_count["L"]), 1.0),
			"R": float(support_speed_sum["R"]) / maxf(float(support_speed_count["R"]), 1.0),
		},
		"swing_mean_foot_speed": {
			"L": float(swing_speed_sum["L"]) / maxf(float(swing_speed_count["L"]), 1.0),
			"R": float(swing_speed_sum["R"]) / maxf(float(swing_speed_count["R"]), 1.0),
		},
	}
	require(absf(float(report["actual_mean_speed"]) - expected_speed) < 0.04, "%d Hz %s actual mean root speed" % [fps, mode])
	require(start_phase >= 0.0 and start_phase < 0.35, "%d Hz %s starts at captured contact" % [fps, mode])
	require(settle_frame >= 0 and float(settle_frame) / fps <= 0.11, "%d Hz %s pose settles promptly after root stop" % [fps, mode])
	for side in ["L", "R"]:
		var flex_minimum := 70.0
		require(float(swing_max[side]) > flex_minimum, "%d Hz %s %s swing has captured recovery flex" % [fps, mode, side])
		require(float([left_min, right_min][0 if side == "L" else 1]) > deg_to_rad(2.0), "%d Hz %s %s knee avoids hyperextension" % [fps, mode, side])
		require(float(knee_plane_max[side]) < 0.16, "%d Hz %s %s knee stays in a bounded forward plane" % [fps, mode, side])
		require(int(blocked_frames[side]) == 0, "%d Hz %s %s has zero blocked hard-plants" % [fps, mode, side])
		require(int(plant_frames[side]) == 0, "%d Hz %s %s legacy hard-plant remains disabled" % [fps, mode, side])
		require(float(report["support_mean_foot_speed"][side]) < float(report["swing_mean_foot_speed"][side]), "%d Hz %s %s support foot is slower than swing" % [fps, mode, side])
	game.queue_free()
	return report


func _run_controller_case(fps: int) -> Dictionary:
	var delta := 1.0 / float(fps)
	var game := load("res://main_3d.tscn").instantiate() as Node3D
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	game.reset_game()
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)

	# A key-down/key-up pair with no elapsed frame is no longer a hidden
	# teleport. Only integrated held time owns locomotion distance.
	var tap_start: Vector3 = game.player_root.position
	game.held_keys[KEY_D] = true
	game.held_keys.erase(KEY_D)
	game._process(delta)
	var tap_distance := tap_start.distance_to(game.player_root.position)
	require(tap_distance <= 0.0001, "%d Hz press/release without held time adds no locomotion distance" % fps)

	# Normalized diagonal input must not outrun a cardinal run.
	game.player_root.position = Vector3(-6.0, 0.0, 4.8)
	game.held_keys[KEY_D] = true
	game.held_keys[KEY_W] = true
	var diagonal_start: Vector3 = game.player_root.position
	for frame in int(round(0.60 * fps)):
		game._process(delta)
	var diagonal_speed := diagonal_start.distance_to(game.player_root.position) / 0.60
	require(absf(diagonal_speed - game.PLAYER_MOVE_SPEED) < 0.04, "%d Hz diagonal run remains speed-normalized" % fps)

	# Shift is deliberately inert: plain WASD, held Shift, and released Shift all
	# retain the corrected run source, cadence, speed, and advancing phase.
	game.player_root.position = Vector3(-6.0, 0.0, 4.8)
	game.held_keys.clear()
	game.held_keys[KEY_D] = true
	for frame in int(round(0.45 * fps)):
		game._process(delta)
	var no_shift_start: Vector3 = game.player_root.position
	var steady_frames := int(round(0.35 * fps))
	for frame in steady_frames:
		game._process(delta)
	var no_shift_speed := no_shift_start.distance_to(game.player_root.position) / (float(steady_frames) * delta)
	var phase_before_shift: float = game.player_step_phase
	game.held_keys[KEY_SHIFT] = true
	for frame in int(round(0.45 * fps)):
		game._process(delta)
	var shift_start: Vector3 = game.player_root.position
	for frame in steady_frames:
		game._process(delta)
	var shift_speed := shift_start.distance_to(game.player_root.position) / (float(steady_frames) * delta)
	game.held_keys.erase(KEY_SHIFT)
	for frame in int(round(0.45 * fps)):
		game._process(delta)
	var released_start: Vector3 = game.player_root.position
	for frame in steady_frames:
		game._process(delta)
	var released_speed := released_start.distance_to(game.player_root.position) / (float(steady_frames) * delta)
	require(absf(no_shift_speed - game.PLAYER_MOVE_SPEED) < 0.05, "%d Hz plain WASD uses run speed" % fps)
	require(absf(shift_speed - game.PLAYER_MOVE_SPEED) < 0.05, "%d Hz Shift does not change run speed" % fps)
	require(absf(released_speed - game.PLAYER_MOVE_SPEED) < 0.05, "%d Hz releasing Shift does not change run speed" % fps)
	require(game.player_run_blend >= 0.9999, "%d Hz standing locomotion keeps the corrected run pose" % fps)
	require(game.player_step_phase > phase_before_shift, "%d Hz inert Shift preserves advancing gait phase" % fps)

	# Crouch keeps the prior absolute 1.178-unit/s travel rather than inheriting
	# the faster standing speed through the old 0.62 multiplier.
	game.player_root.position = Vector3(-6.0, 0.0, 4.8)
	game.held_keys.clear()
	game.crouching = true
	game.held_keys[KEY_D] = true
	var crouch_start: Vector3 = game.player_root.position
	for frame in int(round(0.50 * fps)):
		game._process(delta)
	var crouch_speed := crouch_start.distance_to(game.player_root.position) / 0.50
	require(absf(crouch_speed - game.CROUCH_MOVE_SPEED) < 0.04, "%d Hz crouch preserves absolute travel speed" % fps)

	# World bounds and focus loss remain authoritative over held movement state.
	game.reset_camera()
	game.camera_yaw = 0.0
	game.update_camera(0.0)
	game.player_root.position = Vector3(9.09, 0.0, 0.0)
	game.held_keys.clear()
	game.held_keys[KEY_D] = true
	game.held_keys[KEY_SHIFT] = true
	for frame in int(round(0.50 * fps)):
		game._process(delta)
	var bounded_x: float = game.player_root.position.x
	require(bounded_x <= 9.1001, "%d Hz held movement respects world collision bound" % fps)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	require(game.held_keys.is_empty() and game.player_run_blend >= 0.9999, "%d Hz focus loss clears held movement without changing the fixed run pose" % fps)

	var report := {
		"mode": "controller",
		"fps": fps,
		"tap_distance": tap_distance,
		"diagonal_speed": diagonal_speed,
		"plain_wasd_speed": no_shift_speed,
		"shift_held_speed": shift_speed,
		"shift_released_speed": released_speed,
		"crouch_speed": crouch_speed,
		"bounded_x": bounded_x,
		"fixed_run_pose": game.player_run_blend,
	}
	game.queue_free()
	return report


func _knee_flex(rig: Dictionary, side: String) -> float:
	var skeleton := rig["skeleton"] as Skeleton3D
	var thigh := int(rig["bone_indices"][StringName("thigh.%s" % side)])
	var shin := int(rig["bone_indices"][StringName("shin.%s" % side)])
	var foot := int(rig["bone_indices"][StringName("foot.%s" % side)])
	skeleton.force_update_all_bone_transforms()
	var hip := skeleton.get_bone_global_pose(thigh).origin
	var knee := skeleton.get_bone_global_pose(shin).origin
	var ankle := skeleton.get_bone_global_pose(foot).origin
	var upper := hip - knee
	var lower := ankle - knee
	return PI - upper.angle_to(lower)


func _plant_state(rig: Dictionary, side: String) -> Dictionary:
	var plant: Dictionary = rig["foot_plants"][side]
	return {
		"active": bool(plant["active"]),
		"blocked": bool(plant["blocked"]),
		"weight": float(plant["weight"]),
	}


func _is_support(cycle: float, side: String) -> bool:
	var window := R7RunReference.contact_window(side)
	return cycle >= window.x and cycle < window.y


func _foot_world(rig: Dictionary, side: String) -> Vector3:
	var skeleton := rig["skeleton"] as Skeleton3D
	var foot := int(rig["bone_indices"][StringName("foot.%s" % side)])
	skeleton.force_update_all_bone_transforms()
	return skeleton.global_transform * skeleton.get_bone_global_pose(foot).origin


func _chain_positions(rig: Dictionary, actor: Node3D, side: String) -> Dictionary:
	var skeleton := rig["skeleton"] as Skeleton3D
	var thigh := int(rig["bone_indices"][StringName("thigh.%s" % side)])
	var shin := int(rig["bone_indices"][StringName("shin.%s" % side)])
	var foot := int(rig["bone_indices"][StringName("foot.%s" % side)])
	skeleton.force_update_all_bone_transforms()
	var to_actor := actor.global_transform.affine_inverse() * skeleton.global_transform
	return {
		"hip": to_actor * skeleton.get_bone_global_pose(thigh).origin,
		"knee": to_actor * skeleton.get_bone_global_pose(shin).origin,
		"ankle": to_actor * skeleton.get_bone_global_pose(foot).origin,
	}
