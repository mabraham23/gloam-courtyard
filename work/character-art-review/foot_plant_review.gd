extends SceneTree

## Read-only R7 captured-gait support-foot review at the courtyard's held-input
## speed. R7 deliberately bypasses the legacy hard-lock IK: the frozen leg
## proportions overconstrain that solver and produced visible kicks. This probe
## verifies the replacement contract instead—support feet travel less than swing
## feet, no hard plant blocks occur, and the gameplay root stays untouched.

const Builder = preload("res://actors/character_visual_builder.gd")
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const R7RunReference = preload("res://actors/gloam_vigil/v4/motion/cmu_run_reference.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func support_side(cycle: float) -> String:
	for side in ["L", "R"]:
		var window := R7RunReference.contact_window(side)
		if cycle >= window.x and cycle < window.y:
			return side
	return ""


func ankle_world(rig: Dictionary, side: String) -> Vector3:
	var skeleton: Skeleton3D = rig["skeleton"]
	var foot: int = rig["bone_indices"][StringName("foot.%s" % side)]
	skeleton.force_update_all_bone_transforms()
	return (skeleton.global_transform * skeleton.get_bone_global_pose(foot)).origin


func simulate(fps: int) -> Dictionary:
	var delta := 1.0 / float(fps)
	var actor := Node3D.new()
	root.add_child(actor)
	var parts := Candidate.build_player(actor, Color.WHITE)
	require(Candidate.is_exact_candidate(parts), "support fixture selects exact character-art at %d Hz" % fps)
	var rig: Dictionary = parts["authored_rig"]
	var phase := 0.0
	var previous_feet := {"L": Vector3.ZERO, "R": Vector3.ZERO}
	var feet_valid := false
	var support_speed_sum := {"L": 0.0, "R": 0.0}
	var support_speed_count := {"L": 0, "R": 0}
	var swing_speed_sum := {"L": 0.0, "R": 0.0}
	var swing_speed_count := {"L": 0, "R": 0}
	var active_frames := 0
	var blocked_frames := 0
	for frame in fps * 3:
		actor.position.z += 4.8 * delta
		phase += R7RunReference.cycle_rate() * delta
		Builder.pose_player(parts, phase, 1.0, delta, &"grounded", 0.0)
		var cycle := fposmod(phase, TAU) / TAU
		for side in ["L", "R"]:
			var foot := ankle_world(rig, side)
			if feet_valid:
				var speed := foot.distance_to(previous_feet[side]) / delta
				var window := R7RunReference.contact_window(side)
				if cycle >= window.x and cycle < window.y:
					support_speed_sum[side] = float(support_speed_sum[side]) + speed
					support_speed_count[side] = int(support_speed_count[side]) + 1
				else:
					swing_speed_sum[side] = float(swing_speed_sum[side]) + speed
					swing_speed_count[side] = int(swing_speed_count[side]) + 1
			previous_feet[side] = foot
			var plant: Dictionary = rig["foot_plants"][side]
			active_frames += 1 if bool(plant["active"]) else 0
			blocked_frames += 1 if bool(plant["blocked"]) else 0
		feet_valid = true
	var expected_z := 4.8 * 3.0
	var root_preserved := is_equal_approx(actor.position.z, expected_z) and actor.scale.is_equal_approx(Vector3.ONE)

	actor.rotation.y += 0.20
	actor.position.z += 4.8 * delta
	Builder.pose_player(parts, phase + 0.1, 1.0, delta, &"grounded", 0.0)
	var turn_release := _plants_released(rig)
	actor.position.z += 1.0
	Builder.pose_player(parts, phase + 0.2, 1.0, delta, &"grounded", 0.0)
	var teleport_release := _plants_released(rig)
	actor.position.z += 4.8 * delta
	Builder.pose_player(parts, phase + 0.3, 1.0, delta, &"strike", 0.5)
	var action_release := _plants_released(rig)
	var result := {
		"fps": fps,
		"phase_rate": R7RunReference.cycle_rate(),
		"support_mean_speed": {
			"L": float(support_speed_sum["L"]) / maxf(float(support_speed_count["L"]), 1.0),
			"R": float(support_speed_sum["R"]) / maxf(float(support_speed_count["R"]), 1.0),
		},
		"swing_mean_speed": {
			"L": float(swing_speed_sum["L"]) / maxf(float(swing_speed_count["L"]), 1.0),
			"R": float(swing_speed_sum["R"]) / maxf(float(swing_speed_count["R"]), 1.0),
		},
		"active_frames": active_frames,
		"blocked_frames": blocked_frames,
		"root_preserved": root_preserved,
		"turn_release": turn_release,
		"teleport_release": teleport_release,
		"action_release": action_release,
	}
	Candidate.clear_material_overrides(parts)
	actor.queue_free()
	return result


func _plants_released(rig: Dictionary) -> bool:
	return not bool(rig["foot_plants"]["L"]["active"]) and not bool(rig["foot_plants"]["R"]["active"])


func _run() -> void:
	if not ResourceLoader.exists(Candidate.ASSET_PATH):
		require(false, "explicit character-art candidate resource exists")
		_finish()
		return
	for fps in [60, 30]:
		var result := simulate(fps)
		print("GLOAM_CHARACTER_ART_FOOT_PLANT_RATE ", result)
		for side in ["L", "R"]:
			require(float(result["support_mean_speed"][side]) < float(result["swing_mean_speed"][side]), "%s support foot is slower than swing at %d Hz" % [side, fps])
		require(int(result["active_frames"]) == 0, "legacy hard plants remain disabled at %d Hz" % fps)
		require(int(result["blocked_frames"]) == 0, "no hard-plant reach blocks at %d Hz" % fps)
		require(bool(result["root_preserved"]), "gameplay root preserved %d Hz" % fps)
		require(bool(result["turn_release"]), "turn releases lock %d Hz" % fps)
		require(bool(result["teleport_release"]), "teleport releases lock %d Hz" % fps)
		require(bool(result["action_release"]), "action releases lock %d Hz" % fps)
		await process_frame
	_finish()


func _finish() -> void:
	print("GLOAM_CHARACTER_ART_FOOT_PLANT_", "OK" if failures.is_empty() else "FAILED", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
