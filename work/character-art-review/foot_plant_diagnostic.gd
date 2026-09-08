extends SceneTree

## Diagnostic-only trace for the fixed 60 Hz stance-lock fixture. It mirrors the
## accepted runtime cadence and never changes adapter state, thresholds, or assets.
## A second, identically posed rig has planting disabled so its hip position shows
## the exact pre-IK reach ratio evaluated by the adapter on each planted frame.

const Builder = preload("res://actors/character_visual_builder.gd")
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

const FPS := 60
const DURATION := 3.0
const MOVE_SPEED := 4.8
const PHASE_RATE := 9.6
const PLANT_MAX_REACH := 1.015
const SUPPORT_START := {"L": 0.25, "R": 0.75}
const SUPPORT_END := {"L": 0.40, "R": 0.90}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _support_side(cycle: float) -> String:
	if cycle >= float(SUPPORT_START["L"]) and cycle < float(SUPPORT_END["L"]):
		return "L"
	if cycle >= float(SUPPORT_START["R"]) and cycle < float(SUPPORT_END["R"]):
		return "R"
	return ""


func _pre_ik_reach_ratio(
	planted_rig: Dictionary,
	baseline_rig: Dictionary,
	side: String,
	plant: Dictionary
) -> float:
	var planted_skeleton := planted_rig["skeleton"] as Skeleton3D
	var baseline_skeleton := baseline_rig["skeleton"] as Skeleton3D
	var thigh: int = baseline_rig["bone_indices"][StringName("thigh.%s" % side)]
	baseline_skeleton.force_update_all_bone_transforms()
	var target := planted_skeleton.global_transform.affine_inverse() * (plant["world_position"] as Vector3)
	var base_hip := baseline_skeleton.get_bone_global_pose(thigh).origin
	var lengths: Dictionary = planted_rig["leg_lengths"][side]
	var total_length := float(lengths["upper"]) + float(lengths["lower"])
	return base_hip.distance_to(target) / total_length


func _new_side_result(rig: Dictionary, side: String) -> Dictionary:
	var lengths: Dictionary = rig["leg_lengths"][side]
	return {
		"upper_length": float(lengths["upper"]),
		"lower_length": float(lengths["lower"]),
		"total_length": float(lengths["upper"]) + float(lengths["lower"]),
		"support_frames": 0,
		"active_frames": 0,
		"blocked_frames": 0,
		"captures": 0,
		"releases": 0,
		"maximum_active_pre_ik_reach_ratio": 0.0,
		"first_blocked_reach_ratio": 0.0,
		"events": [],
	}


func _event(
	result: Dictionary,
	kind: String,
	frame: int,
	cycle: float,
	ratio: float,
	travel_since_capture: float,
	active: bool,
	blocked: bool
) -> void:
	var row := {
		"kind": kind,
		"frame": frame,
		"cycle": cycle,
		"reach_ratio": ratio,
		"reach_margin_ratio": PLANT_MAX_REACH - ratio,
		"travel_since_capture": travel_since_capture,
		"active": active,
		"blocked": blocked,
	}
	(result["events"] as Array).append(row)
	print("GLOAM_CHARACTER_ART_FOOT_PLANT_TRANSITION ", JSON.stringify(row))


func _run() -> void:
	_require(ResourceLoader.exists(Candidate.ASSET_PATH), "explicit character-art candidate resource exists")
	if not failures.is_empty():
		_finish({})
		return

	var planted_actor := Node3D.new()
	var baseline_actor := Node3D.new()
	baseline_actor.position.x = 3.0
	root.add_child(planted_actor)
	root.add_child(baseline_actor)
	var planted_parts := Candidate.build_player(planted_actor, Color.WHITE)
	var baseline_parts := Candidate.build_player(baseline_actor, Color.WHITE)
	_require(Candidate.is_exact_candidate(planted_parts), "planted fixture selects exact character-art candidate")
	_require(Candidate.is_exact_candidate(baseline_parts), "baseline fixture selects exact character-art candidate")
	var planted_rig: Dictionary = planted_parts["authored_rig"]
	var baseline_rig: Dictionary = baseline_parts["authored_rig"]
	var results := {
		"L": _new_side_result(planted_rig, "L"),
		"R": _new_side_result(planted_rig, "R"),
	}
	var previous_support := {"L": false, "R": false}
	var previous_blocked := {"L": false, "R": false}
	var capture_z := {"L": 0.0, "R": 0.0}
	var phase := 0.0
	var delta := 1.0 / float(FPS)

	for frame in int(FPS * DURATION):
		planted_actor.position.z += MOVE_SPEED * delta
		baseline_actor.position.z += MOVE_SPEED * delta
		phase += PHASE_RATE * delta
		# Zero reported travel on the baseline only. It still receives the exact
		# same grounded animation and therefore exposes the pre-IK hip pose.
		baseline_rig["plant_actor_transform"] = baseline_actor.global_transform
		baseline_rig["plant_actor_transform_valid"] = true
		Builder.pose_player(planted_parts, phase, 1.0, delta, &"grounded", 0.0)
		Builder.pose_player(baseline_parts, phase, 1.0, delta, &"grounded", 0.0)
		var cycle := fposmod(phase, TAU) / TAU
		var support_side := _support_side(cycle)
		for side: String in ["L", "R"]:
			var in_support: bool = support_side == side
			var result: Dictionary = results[side]
			var plant: Dictionary = planted_rig["foot_plants"][side]
			var active := bool(plant["active"])
			var blocked := bool(plant["blocked"])
			var ratio := 0.0
			if in_support:
				result["support_frames"] = int(result["support_frames"]) + 1
				ratio = _pre_ik_reach_ratio(planted_rig, baseline_rig, side, plant)
				if active:
					result["active_frames"] = int(result["active_frames"]) + 1
					result["maximum_active_pre_ik_reach_ratio"] = maxf(float(result["maximum_active_pre_ik_reach_ratio"]), ratio)
				if blocked:
					result["blocked_frames"] = int(result["blocked_frames"]) + 1
			if in_support and not bool(previous_support[side]):
				capture_z[side] = planted_actor.position.z
				result["captures"] = int(result["captures"]) + 1
				_event(result, "capture", frame + 1, cycle, ratio, 0.0, active, blocked)
			if in_support and blocked and not bool(previous_blocked[side]):
				result["releases"] = int(result["releases"]) + 1
				if is_zero_approx(float(result["first_blocked_reach_ratio"])):
					result["first_blocked_reach_ratio"] = ratio
				_event(result, "reach_release", frame + 1, cycle, ratio, planted_actor.position.z - float(capture_z[side]), active, blocked)
			if not in_support and bool(previous_support[side]):
				_event(result, "toe_off", frame + 1, cycle, ratio, planted_actor.position.z - float(capture_z[side]), active, blocked)
			previous_support[side] = in_support
			previous_blocked[side] = blocked

	var report := {
		"asset_path": Candidate.ASSET_PATH,
		"asset_sha256": FileAccess.get_sha256(Candidate.ASSET_PATH),
		"fps": FPS,
		"duration": DURATION,
		"movement_speed": MOVE_SPEED,
		"phase_rate": PHASE_RATE,
		"frame_travel": MOVE_SPEED / float(FPS),
		"support_intervals": {"L": [SUPPORT_START["L"], SUPPORT_END["L"]], "R": [SUPPORT_START["R"], SUPPORT_END["R"]]},
		"plant_max_reach_ratio": PLANT_MAX_REACH,
		"sides": results,
	}
	Candidate.clear_material_overrides(planted_parts)
	Candidate.clear_material_overrides(baseline_parts)
	planted_actor.queue_free()
	baseline_actor.queue_free()
	_finish(report)


func _finish(report: Dictionary) -> void:
	print("GLOAM_CHARACTER_ART_FOOT_PLANT_DIAGNOSTIC_REPORT ", JSON.stringify(report))
	print("GLOAM_CHARACTER_ART_FOOT_PLANT_DIAGNOSTIC_", "OK" if failures.is_empty() else "FAILED", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
