extends SceneTree

## Measurement-first leg tracking diagnostic for the current candidate.
##
## The harness samples every rendered gait step in actor-oriented world metres
## over two complete captured-run cycles at 30/60 Hz and all three supported
## body presets. It reports the observed envelope; it intentionally does not
## turn aesthetic widths, flexion, or ankle travel into invented pass/fail bars.
## Only data integrity, the protected 4.8-unit/s gameplay speed, completion of
## the requested cycles, safe-path ownership, and bounded stop observation are
## assertions.
##
## Optional compact report output:
##   -- --report-path=res://work/action-quality/leg-tracking-report.json

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const RunReference = preload("res://actors/gloam_vigil/v4/motion/cmu_run_reference.gd")
const RigAdapter = preload("res://actors/gloam_vigil/gloam_vigil_rig_adapter.gd")

const PRESETS := [0.88, 1.0, 1.16]
const SAMPLE_RATES := [30, 60]
const CYCLES_PER_CASE := 2.0
const MAX_CASE_SECONDS := 2.0
const SPEED_TOLERANCE := 0.04
const CALF_CHAIN_AMOUNT := 0.55
const SIDES := ["L", "R"]
const POSITION_TRACKING_KEYS := [
	"hip_lateral_L_m", "hip_lateral_R_m",
	"knee_lateral_L_m", "knee_lateral_R_m",
	"calf_lateral_L_m", "calf_lateral_R_m",
	"ankle_lateral_L_m", "ankle_lateral_R_m",
	"hip_separation_R_minus_L_m", "knee_separation_R_minus_L_m",
	"calf_separation_R_minus_L_m", "ankle_separation_R_minus_L_m",
	"ankle_vertical_L_m", "ankle_vertical_R_m",
	"ankle_longitudinal_L_m", "ankle_longitudinal_R_m",
]
const FLEX_TRACKING_KEYS := ["knee_flex_L_deg", "knee_flex_R_deg"]
const LENGTH_TRACKING_KEYS := [
	"upper_leg_length_L_m", "upper_leg_length_R_m",
	"lower_leg_length_L_m", "lower_leg_length_R_m",
]
const LANE_RATIO_KEYS := ["ankle_to_hip_ratio", "calf_to_hip_ratio"]
const ALL_METRIC_KEYS := POSITION_TRACKING_KEYS + FLEX_TRACKING_KEYS + LENGTH_TRACKING_KEYS + LANE_RATIO_KEYS

var failures: Array[String] = []
var report_path := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-path="):
			report_path = argument.trim_prefix("--report-path=")
	call_deferred("_run")


func _run() -> void:
	var cases: Array = []
	for preset in PRESETS:
		for fps in SAMPLE_RATES:
			cases.append(_run_case(float(preset), int(fps)))
	var report := {
		"format": "gloam-leg-tracking-summary-v1",
		"asset_path": Candidate.ASSET_PATH,
		"asset_sha256": FileAccess.get_sha256(Candidate.ASSET_PATH),
		"motion_source_sha256": RunReference.source_sha256(),
		"retarget_sha256": RunReference.data_sha256(),
		"actor_local_definition": "World-metre bone points rotated into player axes; player translation removed while the 1.35 player base scale and body preset are retained. Divide metre lengths by 1.35 times preset for skeleton-normalized values.",
		"separation_sign_definition": "right_x_minus_left_x in actor axes",
		"calf_sample_definition": "55 percent from knee to ankle",
		"cycles_requested_per_case": CYCLES_PER_CASE,
		"cases": cases,
		"failures": failures,
	}
	var compact_json := JSON.stringify(report)
	print("GLOAM_LEG_TRACKING_REPORT ", compact_json)
	if not report_path.is_empty():
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		_require(output != null, "optional report path opens for writing: %s" % report_path)
		if output != null:
			# Re-serialize after the path check so a write failure is represented in
			# the saved report as well as the process exit code.
			report["failures"] = failures
			output.store_string(JSON.stringify(report) + "\n")
			output.close()
			print("GLOAM_LEG_TRACKING_REPORT_PATH ", report_path)
	print(
		"GLOAM_LEG_TRACKING_", "OK" if failures.is_empty() else "FAILED",
		" cases=", cases.size(), " failures=", failures.size()
	)
	for failure in failures:
		print("FAIL ", failure)
	quit(0 if failures.is_empty() else 1)


func _run_case(preset: float, fps: int) -> Dictionary:
	var delta := 1.0 / float(fps)
	var game := load("res://main_3d.tscn").instantiate() as Node3D
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(
		game.player_root, game.outfit_colors[game.outfit_index]
	)
	game.player_accent_material = game.player_visual_parts["accent_material"]
	_require(Candidate.is_exact_candidate(game.player_visual_parts), "%d Hz preset %.2f uses current exact candidate" % [fps, preset])
	var rig: Dictionary = game.player_visual_parts["authored_rig"]
	_require_required_bones(rig, fps, preset)

	# Each case owns a fresh reset and less than two seconds of simulated time.
	# The fixed yaw is established before any held input so movement cannot feed
	# back through a diagnostic camera that follows the actor.
	game.player_scale = preset
	game.reset_game()
	game.player_root.position = Vector3(-6.0, 0.0, 4.8)
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.reset_camera()
	game.camera_yaw = 0.0
	game.update_camera(0.0)

	var simulated_seconds := 0.0
	game._process(delta)
	simulated_seconds += delta
	var baseline := _measure_frame(game, rig)
	_require_finite_metrics(baseline, "%d Hz preset %.2f baseline" % [fps, preset])

	game.held_keys[KEY_D] = true
	var warmup_frames := 0
	while game.player_move_blend < 0.999 and simulated_seconds + delta <= MAX_CASE_SECONDS:
		game._process(delta)
		simulated_seconds += delta
		warmup_frames += 1
		_require_safe_path(game, fps, preset, "warmup")
	var sample_start_phase: float = game.player_step_phase
	var samples: Array = []
	while game.player_step_phase - sample_start_phase < TAU * CYCLES_PER_CASE \
		and simulated_seconds + delta <= MAX_CASE_SECONDS:
		var root_before: Vector3 = game.player_root.global_position
		game._process(delta)
		simulated_seconds += delta
		var sample := _measure_frame(game, rig)
		sample["sample_frame"] = samples.size()
		sample["phase_cycles"] = (game.player_step_phase - sample_start_phase) / TAU
		sample["world_root_speed_mps"] = _horizontal_distance(root_before, game.player_root.global_position) / delta
		_require_finite_metrics(sample, "%d Hz preset %.2f moving frame %d" % [fps, preset, samples.size()])
		_require_safe_path(game, fps, preset, "moving frame %d" % samples.size())
		samples.append(sample)
	var sampled_cycles: float = (game.player_step_phase - sample_start_phase) / TAU
	_require(sampled_cycles >= CYCLES_PER_CASE, "%d Hz preset %.2f samples at least two complete gait cycles" % [fps, preset])
	_require(not samples.is_empty(), "%d Hz preset %.2f produces moving samples" % [fps, preset])
	# The production pose has already passed through the grounded solver. Apply
	# that solver once more to the actual last sampled pose and disclose the
	# measured repeat-application sensitivity. This does not establish first-call
	# preservation and is not a reconstructed historical before/after comparison.
	var repeat_application_probe := _repeat_application_probe(rig)
	_require_finite_metrics(repeat_application_probe, "%d Hz preset %.2f repeat-application probe" % [fps, preset])

	game.held_keys.erase(KEY_D)
	var stop_samples: Array = []
	var settle_frame := -1
	while simulated_seconds + delta <= MAX_CASE_SECONDS:
		game._process(delta)
		simulated_seconds += delta
		var stop_pose := _measure_frame(game, rig)
		var stop_sample := {
			"sample_frame": stop_samples.size(),
			"move_blend": game.player_move_blend,
			"position_error_m": _maximum_delta(stop_pose, baseline, POSITION_TRACKING_KEYS),
			"knee_flex_error_deg": _maximum_delta(stop_pose, baseline, FLEX_TRACKING_KEYS),
			"segment_length_delta_m": _maximum_delta(stop_pose, baseline, LENGTH_TRACKING_KEYS),
		}
		_require_finite_metrics(stop_sample, "%d Hz preset %.2f stop frame %d" % [fps, preset, stop_samples.size()])
		stop_samples.append(stop_sample)
		if game.player_move_blend <= 0.001:
			settle_frame = stop_samples.size()
			break
	_require(settle_frame >= 0, "%d Hz preset %.2f stop recovery is observed inside the bounded case" % [fps, preset])
	_require(simulated_seconds <= MAX_CASE_SECONDS + 0.00001, "%d Hz preset %.2f resets before two simulated seconds" % [fps, preset])

	var moving_summary := _summarize_samples(samples, ALL_METRIC_KEYS)
	var root_speed := _summarize_samples(samples, ["world_root_speed_mps"])["world_root_speed_mps"] as Dictionary
	_require(
		absf(float(root_speed.get("mean", 0.0)) - float(game.PLAYER_MOVE_SPEED)) <= SPEED_TOLERANCE,
		"%d Hz preset %.2f world root mean speed remains %.2f" % [fps, preset, game.PLAYER_MOVE_SPEED]
	)
	var ankle_ratio: Dictionary = moving_summary["ankle_to_hip_ratio"]
	var calf_ratio: Dictionary = moving_summary["calf_to_hip_ratio"]
	_require(float(ankle_ratio["min"]) > 0.0, "%d Hz preset %.2f signed ankle ordering remains positive" % [fps, preset])
	_require(float(calf_ratio["min"]) > 0.0, "%d Hz preset %.2f signed calf ordering remains positive" % [fps, preset])
	_require(float(ankle_ratio["max"]) <= 1.08, "%d Hz preset %.2f ankle lane stays at or below 1.08 hip span" % [fps, preset])
	_require(float(calf_ratio["max"]) <= 1.08, "%d Hz preset %.2f calf lane stays at or below 1.08 hip span" % [fps, preset])
	_require(float(ankle_ratio["min"]) >= 0.65, "%d Hz preset %.2f ankle lane retains at least 0.65 hip span" % [fps, preset])
	_require(float(calf_ratio["min"]) >= 0.65, "%d Hz preset %.2f calf lane retains at least 0.65 hip span" % [fps, preset])
	var stop_summary := _summarize_samples(
		stop_samples,
		["move_blend", "position_error_m", "knee_flex_error_deg", "segment_length_delta_m"]
	)
	var maxima := _sampled_maxima(moving_summary)
	var result := {
		"preset": preset,
		"fps": fps,
		"simulated_seconds": simulated_seconds,
		"warmup_frames": warmup_frames,
		"sample_frames": samples.size(),
		"sampled_cycles": sampled_cycles,
		"baseline": _group_metrics(baseline),
		"moving": _group_summaries(moving_summary),
		"world_root_speed_mps": root_speed,
		"sampled_maxima": maxima,
		"grounded_solver_repeat_application": repeat_application_probe,
		"stop_recovery": {
			"settle_frames": settle_frame,
			"settle_seconds": float(settle_frame) / float(fps) if settle_frame >= 0 else -1.0,
			"summary": stop_summary,
			"final": stop_samples.back() if not stop_samples.is_empty() else {},
		},
	}
	game.queue_free()
	return result


func _measure_frame(game: Node3D, rig: Dictionary) -> Dictionary:
	var skeleton := rig["skeleton"] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var pelvis := _actor_oriented_world_point(game.player_root, skeleton, &"pelvis")
	var hip_l := _actor_oriented_world_point(game.player_root, skeleton, &"thigh.L")
	var hip_r := _actor_oriented_world_point(game.player_root, skeleton, &"thigh.R")
	var knee_l := _actor_oriented_world_point(game.player_root, skeleton, &"shin.L")
	var knee_r := _actor_oriented_world_point(game.player_root, skeleton, &"shin.R")
	var ankle_l := _actor_oriented_world_point(game.player_root, skeleton, &"foot.L")
	var ankle_r := _actor_oriented_world_point(game.player_root, skeleton, &"foot.R")
	var calf_l := knee_l.lerp(ankle_l, CALF_CHAIN_AMOUNT)
	var calf_r := knee_r.lerp(ankle_r, CALF_CHAIN_AMOUNT)
	var hip_separation := hip_r.x - hip_l.x
	var calf_separation := calf_r.x - calf_l.x
	var ankle_separation := ankle_r.x - ankle_l.x
	return {
		"hip_lateral_L_m": hip_l.x - pelvis.x,
		"hip_lateral_R_m": hip_r.x - pelvis.x,
		"knee_lateral_L_m": knee_l.x - pelvis.x,
		"knee_lateral_R_m": knee_r.x - pelvis.x,
		"calf_lateral_L_m": calf_l.x - pelvis.x,
		"calf_lateral_R_m": calf_r.x - pelvis.x,
		"ankle_lateral_L_m": ankle_l.x - pelvis.x,
		"ankle_lateral_R_m": ankle_r.x - pelvis.x,
		"knee_separation_R_minus_L_m": knee_r.x - knee_l.x,
		"hip_separation_R_minus_L_m": hip_separation,
		"ankle_separation_R_minus_L_m": ankle_separation,
		"calf_separation_R_minus_L_m": calf_separation,
		"ankle_to_hip_ratio": ankle_separation / hip_separation if absf(hip_separation) > 0.000001 else NAN,
		"calf_to_hip_ratio": calf_separation / hip_separation if absf(hip_separation) > 0.000001 else NAN,
		"knee_flex_L_deg": _knee_flex_degrees(hip_l, knee_l, ankle_l),
		"knee_flex_R_deg": _knee_flex_degrees(hip_r, knee_r, ankle_r),
		"ankle_vertical_L_m": ankle_l.y - pelvis.y,
		"ankle_vertical_R_m": ankle_r.y - pelvis.y,
		"ankle_longitudinal_L_m": ankle_l.z - pelvis.z,
		"ankle_longitudinal_R_m": ankle_r.z - pelvis.z,
		"upper_leg_length_L_m": hip_l.distance_to(knee_l),
		"upper_leg_length_R_m": hip_r.distance_to(knee_r),
		"lower_leg_length_L_m": knee_l.distance_to(ankle_l),
		"lower_leg_length_R_m": knee_r.distance_to(ankle_r),
	}


func _actor_oriented_world_point(actor: Node3D, skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	var bone := skeleton.find_bone(bone_name)
	assert(bone >= 0, "Missing required leg-tracking bone %s" % bone_name)
	var world_point := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	var actor_rotation := actor.global_transform.basis.orthonormalized()
	return actor_rotation.inverse() * (world_point - actor.global_position)


func _knee_flex_degrees(hip: Vector3, knee: Vector3, ankle: Vector3) -> float:
	var upper := hip - knee
	var lower := ankle - knee
	if upper.length_squared() <= 0.0000001 or lower.length_squared() <= 0.0000001:
		return NAN
	return rad_to_deg(PI - upper.angle_to(lower))


func _summarize_samples(samples: Array, keys: Array) -> Dictionary:
	var result := {}
	for key_value in keys:
		var key := String(key_value)
		var minimum := INF
		var maximum := -INF
		var minimum_frame := -1
		var maximum_frame := -1
		var maximum_absolute := -INF
		var maximum_absolute_value := 0.0
		var maximum_absolute_frame := -1
		var total := 0.0
		for index in samples.size():
			var value := float((samples[index] as Dictionary)[key])
			if value < minimum:
				minimum = value
				minimum_frame = index
			if value > maximum:
				maximum = value
				maximum_frame = index
			if absf(value) > maximum_absolute:
				maximum_absolute = absf(value)
				maximum_absolute_value = value
				maximum_absolute_frame = index
			total += value
		result[key] = {
			"min": minimum,
			"min_frame": minimum_frame,
			"max": maximum,
			"max_frame": maximum_frame,
			"max_abs": maximum_absolute,
			"max_abs_signed": maximum_absolute_value,
			"max_abs_frame": maximum_absolute_frame,
			"mean": total / maxf(float(samples.size()), 1.0),
			"span": maximum - minimum,
		}
	return result


func _sampled_maxima(summary: Dictionary) -> Dictionary:
	return {
		"hip_lateral_abs_m": _largest_side_maximum(summary, "hip_lateral_%s_m"),
		"knee_lateral_abs_m": _largest_side_maximum(summary, "knee_lateral_%s_m"),
		"calf_lateral_abs_m": _largest_side_maximum(summary, "calf_lateral_%s_m"),
		"ankle_lateral_abs_m": _largest_side_maximum(summary, "ankle_lateral_%s_m"),
		"knee_flex_deg": _largest_positive_side_maximum(summary, "knee_flex_%s_deg"),
		"ankle_vertical_span_m": _largest_side_span(summary, "ankle_vertical_%s_m"),
		"ankle_longitudinal_span_m": _largest_side_span(summary, "ankle_longitudinal_%s_m"),
		"knee_separation_abs_m": _maximum_entry(summary, "knee_separation_R_minus_L_m"),
		"calf_separation_abs_m": _maximum_entry(summary, "calf_separation_R_minus_L_m"),
		"ankle_separation_abs_m": _maximum_entry(summary, "ankle_separation_R_minus_L_m"),
	}


func _largest_side_maximum(summary: Dictionary, pattern: String) -> Dictionary:
	var best := {"side": "", "value": -INF, "signed_value": 0.0, "frame": -1}
	for side in SIDES:
		var entry: Dictionary = summary[pattern % side]
		if float(entry["max_abs"]) > float(best["value"]):
			best = {
				"side": side,
				"value": entry["max_abs"],
				"signed_value": entry["max_abs_signed"],
				"frame": entry["max_abs_frame"],
			}
	return best


func _largest_positive_side_maximum(summary: Dictionary, pattern: String) -> Dictionary:
	var best := {"side": "", "value": -INF, "frame": -1}
	for side in SIDES:
		var entry: Dictionary = summary[pattern % side]
		if float(entry["max"]) > float(best["value"]):
			best = {"side": side, "value": entry["max"], "frame": entry["max_frame"]}
	return best


func _largest_side_span(summary: Dictionary, pattern: String) -> Dictionary:
	var best := {"side": "", "value": -INF, "min": 0.0, "max": 0.0}
	for side in SIDES:
		var entry: Dictionary = summary[pattern % side]
		if float(entry["span"]) > float(best["value"]):
			best = {"side": side, "value": entry["span"], "min": entry["min"], "max": entry["max"]}
	return best


func _maximum_entry(summary: Dictionary, key: String) -> Dictionary:
	var entry: Dictionary = summary[key]
	return {
		"value": entry["max_abs"],
		"signed_value": entry["max_abs_signed"],
		"frame": entry["max_abs_frame"],
	}


func _group_metrics(values: Dictionary) -> Dictionary:
	return {
		"lateral_from_pelvis_m": {
			"hip": {"L": values["hip_lateral_L_m"], "R": values["hip_lateral_R_m"]},
			"knee": {"L": values["knee_lateral_L_m"], "R": values["knee_lateral_R_m"]},
			"calf": {"L": values["calf_lateral_L_m"], "R": values["calf_lateral_R_m"]},
			"ankle": {"L": values["ankle_lateral_L_m"], "R": values["ankle_lateral_R_m"]},
		},
		"signed_separation_right_minus_left_m": {
			"hip": values["hip_separation_R_minus_L_m"],
			"knee": values["knee_separation_R_minus_L_m"],
			"calf": values["calf_separation_R_minus_L_m"],
			"ankle": values["ankle_separation_R_minus_L_m"],
		},
		"knee_flex_deg": {"L": values["knee_flex_L_deg"], "R": values["knee_flex_R_deg"]},
		"ankle_vertical_from_pelvis_m": {"L": values["ankle_vertical_L_m"], "R": values["ankle_vertical_R_m"]},
		"ankle_longitudinal_from_pelvis_m": {"L": values["ankle_longitudinal_L_m"], "R": values["ankle_longitudinal_R_m"]},
		"bone_segment_length_m": {
			"upper_leg": {"L": values["upper_leg_length_L_m"], "R": values["upper_leg_length_R_m"]},
			"lower_leg": {"L": values["lower_leg_length_L_m"], "R": values["lower_leg_length_R_m"]},
		},
		"anatomy_scaled_lane_ratio": {
			"ankle_to_hip": values["ankle_to_hip_ratio"],
			"calf_to_hip": values["calf_to_hip_ratio"],
		},
	}


func _group_summaries(values: Dictionary) -> Dictionary:
	return _group_metrics(values)


func _maximum_delta(current: Dictionary, baseline: Dictionary, keys: Array) -> float:
	var maximum := 0.0
	for key_value in keys:
		var key := String(key_value)
		maximum = maxf(maximum, absf(float(current[key]) - float(baseline[key])))
	return maximum


func _repeat_application_probe(rig: Dictionary) -> Dictionary:
	var before := _skeleton_chain_snapshot(rig)
	RigAdapter._apply_r7_grounded_leg_tracking(rig)
	var after := _skeleton_chain_snapshot(rig)
	var result := {
		"definition": "deltas after applying the grounded solver once more to an already solved moving pose",
		"hip_position_delta_m": 0.0,
		"ankle_position_delta_m": 0.0,
		"ankle_z_delta_m": 0.0,
		"segment_length_delta_m": 0.0,
		"knee_flex_delta_deg": 0.0,
		"foot_basis_axis_delta": 0.0,
	}
	for side in SIDES:
		var before_side: Dictionary = before[side]
		var after_side: Dictionary = after[side]
		result["hip_position_delta_m"] = maxf(
			float(result["hip_position_delta_m"]),
			(before_side["hip"] as Vector3).distance_to(after_side["hip"] as Vector3)
		)
		result["ankle_position_delta_m"] = maxf(
			float(result["ankle_position_delta_m"]),
			(before_side["ankle"] as Vector3).distance_to(after_side["ankle"] as Vector3)
		)
		result["ankle_z_delta_m"] = maxf(
			float(result["ankle_z_delta_m"]),
			absf((before_side["ankle"] as Vector3).z - (after_side["ankle"] as Vector3).z)
		)
		result["segment_length_delta_m"] = maxf(
			float(result["segment_length_delta_m"]),
			maxf(
				absf(float(before_side["upper_length"]) - float(after_side["upper_length"])),
				absf(float(before_side["lower_length"]) - float(after_side["lower_length"]))
			)
		)
		result["knee_flex_delta_deg"] = maxf(
			float(result["knee_flex_delta_deg"]),
			absf(float(before_side["knee_flex_deg"]) - float(after_side["knee_flex_deg"]))
		)
		var before_basis := before_side["foot_basis"] as Basis
		var after_basis := after_side["foot_basis"] as Basis
		result["foot_basis_axis_delta"] = maxf(
			float(result["foot_basis_axis_delta"]),
			maxf(
				before_basis.x.distance_to(after_basis.x),
				maxf(before_basis.y.distance_to(after_basis.y), before_basis.z.distance_to(after_basis.z))
			)
		)
	return result


func _skeleton_chain_snapshot(rig: Dictionary) -> Dictionary:
	var skeleton := rig["skeleton"] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var result := {}
	for side in SIDES:
		var hip := skeleton.get_bone_global_pose(skeleton.find_bone(StringName("thigh.%s" % side))).origin
		var knee := skeleton.get_bone_global_pose(skeleton.find_bone(StringName("shin.%s" % side))).origin
		var foot_pose := skeleton.get_bone_global_pose(skeleton.find_bone(StringName("foot.%s" % side)))
		var ankle := foot_pose.origin
		result[side] = {
			"hip": hip,
			"knee": knee,
			"ankle": ankle,
			"upper_length": hip.distance_to(knee),
			"lower_length": knee.distance_to(ankle),
			"knee_flex_deg": _knee_flex_degrees(hip, knee, ankle),
			"foot_basis": foot_pose.basis.orthonormalized(),
		}
	return result


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _require_required_bones(rig: Dictionary, fps: int, preset: float) -> void:
	var skeleton := rig["skeleton"] as Skeleton3D
	for bone_name in [&"pelvis", &"thigh.L", &"thigh.R", &"shin.L", &"shin.R", &"foot.L", &"foot.R"]:
		_require(skeleton.find_bone(bone_name) >= 0, "%d Hz preset %.2f has bone %s" % [fps, preset, bone_name])


func _require_finite_metrics(values: Dictionary, label: String) -> void:
	for key_value in values:
		var value: Variant = values[key_value]
		if value is float:
			_require(is_finite(value), "%s finite %s" % [label, key_value])
		elif value is int:
			continue


func _require_safe_path(game: Node3D, fps: int, preset: float, label: String) -> void:
	var position: Vector3 = game.player_root.position
	_require(absf(position.x) < 8.85 and absf(position.z) < 4.95, "%d Hz preset %.2f %s remains clear of world clamps" % [fps, preset, label])
	_require(not game.is_in_low_passage(position), "%d Hz preset %.2f %s avoids low passage" % [fps, preset, label])
	_require(not game.is_inside_vault_obstacle(position), "%d Hz preset %.2f %s avoids vault obstacle" % [fps, preset, label])


func _require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
