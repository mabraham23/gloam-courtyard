extends SceneTree

## Read-only v3 stance-lock comparison at the courtyard's held-input speed and
## phase rate. It measures ankle-origin locking, not whole-sole contact.

const Builder = preload("res://actors/character_visual_builder.gd")
const Candidate = preload("res://work/character-art-v3/candidate_fixture.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func support_side(cycle: float) -> String:
	if cycle >= 0.25 and cycle < 0.45:
		return "L"
	if cycle >= 0.75 and cycle < 0.95:
		return "R"
	return ""


func ankle_world(rig: Dictionary, side: String) -> Vector3:
	var skeleton: Skeleton3D = rig["skeleton"]
	var foot: int = rig["bone_indices"][StringName("foot.%s" % side)]
	skeleton.force_update_all_bone_transforms()
	return (skeleton.global_transform * skeleton.get_bone_global_pose(foot)).origin


func simulate(fps: int) -> Dictionary:
	var delta := 1.0 / float(fps)
	var planted_actor := Node3D.new()
	var baseline_actor := Node3D.new()
	baseline_actor.position.x = 3.0
	root.add_child(planted_actor)
	root.add_child(baseline_actor)
	var planted_parts := Candidate.build_player(planted_actor, Color.WHITE)
	var baseline_parts := Candidate.build_player(baseline_actor, Color.WHITE)
	require(Candidate.is_exact_candidate(planted_parts), "planted fixture selects exact v3 at %d Hz" % fps)
	require(Candidate.is_exact_candidate(baseline_parts), "baseline fixture selects exact v3 at %d Hz" % fps)
	var planted_rig: Dictionary = planted_parts["authored_rig"]
	var baseline_rig: Dictionary = baseline_parts["authored_rig"]
	var phase := 0.0
	var current_side := ""
	var baseline_target := Vector3.ZERO
	var baseline_max := 0.0
	var planted_max := 0.0
	var planted_full_max := 0.0
	var support_frames := 0
	var active_frames := 0
	var blocked_frames := 0
	for frame in fps * 3:
		planted_actor.position.z += 4.8 * delta
		baseline_actor.position.z += 4.8 * delta
		phase += 7.2 * delta
		# The baseline receives identical keys while reporting no displacement to
		# the presentation-only stance layer, so it does not solve foot lock.
		baseline_rig["plant_actor_transform"] = baseline_actor.global_transform
		baseline_rig["plant_actor_transform_valid"] = true
		Builder.pose_player(planted_parts, phase, 1.0, delta, &"grounded", 0.0)
		Builder.pose_player(baseline_parts, phase, 1.0, delta, &"grounded", 0.0)
		var side := support_side(fposmod(phase, TAU) / TAU)
		if not side.is_empty():
			support_frames += 1
			if side != current_side:
				baseline_target = ankle_world(baseline_rig, side)
				current_side = side
			baseline_max = maxf(baseline_max, ankle_world(baseline_rig, side).distance_to(baseline_target))
			var plant: Dictionary = planted_rig["foot_plants"][side]
			if bool(plant["active"]):
				active_frames += 1
				var error := ankle_world(planted_rig, side).distance_to(plant["world_position"])
				planted_max = maxf(planted_max, error)
				if float(plant["weight"]) >= 0.999:
					planted_full_max = maxf(planted_full_max, error)
			elif bool(plant["blocked"]):
				blocked_frames += 1
		else:
			current_side = ""
	var expected_z := 4.8 * 3.0
	var root_preserved := is_equal_approx(planted_actor.position.z, expected_z) and planted_actor.scale.is_equal_approx(Vector3.ONE)

	planted_actor.rotation.y += 0.20
	planted_actor.position.z += 4.8 * delta
	Builder.pose_player(planted_parts, phase + 0.1, 1.0, delta, &"grounded", 0.0)
	var turn_release := _plants_released(planted_rig)
	planted_actor.position.z += 1.0
	Builder.pose_player(planted_parts, phase + 0.2, 1.0, delta, &"grounded", 0.0)
	var teleport_release := _plants_released(planted_rig)
	planted_actor.position.z += 4.8 * delta
	Builder.pose_player(planted_parts, phase + 0.3, 1.0, delta, &"strike", 0.5)
	var action_release := _plants_released(planted_rig)
	var result := {
		"fps": fps,
		"baseline_max": baseline_max,
		"planted_max": planted_max,
		"planted_full_max": planted_full_max,
		"support_frames": support_frames,
		"active_frames": active_frames,
		"blocked_frames": blocked_frames,
		"root_preserved": root_preserved,
		"turn_release": turn_release,
		"teleport_release": teleport_release,
		"action_release": action_release,
	}
	Candidate.clear_material_overrides(planted_parts)
	Candidate.clear_material_overrides(baseline_parts)
	planted_actor.queue_free()
	baseline_actor.queue_free()
	return result


func _plants_released(rig: Dictionary) -> bool:
	return not bool(rig["foot_plants"]["L"]["active"]) and not bool(rig["foot_plants"]["R"]["active"])


func _run() -> void:
	if not ResourceLoader.exists(Candidate.ASSET_PATH):
		require(false, "explicit v3 candidate resource exists")
		_finish()
		return
	for fps in [60, 30]:
		var result := simulate(fps)
		print("GLOAM_V3_FOOT_PLANT_RATE ", result)
		require(float(result["planted_full_max"]) <= 0.035, "full-weight ankle lock %d Hz" % fps)
		require(float(result["planted_max"]) < float(result["baseline_max"]) * 0.35, "lock materially reduces slip %d Hz" % fps)
		require(float(result["active_frames"]) >= float(result["support_frames"]) * 0.72, "lock covers stance %d Hz" % fps)
		require(bool(result["root_preserved"]), "gameplay root preserved %d Hz" % fps)
		require(bool(result["turn_release"]), "turn releases lock %d Hz" % fps)
		require(bool(result["teleport_release"]), "teleport releases lock %d Hz" % fps)
		require(bool(result["action_release"]), "action releases lock %d Hz" % fps)
		await process_frame
	_finish()


func _finish() -> void:
	print("GLOAM_V3_FOOT_PLANT_", "OK" if failures.is_empty() else "FAILED", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

