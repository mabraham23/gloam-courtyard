extends SceneTree

## Measures the exact R14 hip/knee/ankle chain in imported rest, runtime idle,
## corrected run, crouch, and kick contact. This is diagnostic evidence only;
## gameplay root motion and the GLB are never modified here.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

var game: Node3D
var rig: Dictionary
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = load("res://main_3d.tscn").instantiate() as Node3D
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	rig = game.player_visual_parts["authored_rig"]

	print("R14_LOWER_LEG_STANCE asset_sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	var rest := _measure(true)
	print("R14_LOWER_LEG_STANCE rest=", JSON.stringify(rest))
	game.reset_game()
	game._process(1.0 / 60.0)
	var idle := _measure(false)
	print("R14_LOWER_LEG_STANCE idle=", JSON.stringify(idle))
	require(float(idle["foot_separation"]) <= float(rest["foot_separation"]) * 0.78, "idle ankle stance narrows at least 22 percent")
	require(float(idle["calf_mid_separation"]) <= float(rest["calf_mid_separation"]) * 0.80, "idle calf stance narrows at least 20 percent")
	require(absf(float(idle["thigh_separation"]) - float(rest["thigh_separation"])) < 0.005, "hip width remains anatomically anchored")

	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.camera_yaw = 0.0
	game.update_camera(0.0)
	game.held_keys[KEY_D] = true
	var run_samples: Array = []
	for frame in 90:
		game._process(1.0 / 60.0)
		var sample := _measure(false)
		# Signed spatial .R-minus-.L lanes cannot hide crossing behind abs().
		# Every frame is checked; sparse samples below are output only.
		require(float(sample["calf_mid_separation"]) > 0.20, "run calves keep signed ordering frame %d" % frame)
		require(float(sample["foot_separation"]) > 0.20, "run ankles keep signed ordering frame %d" % frame)
		require(float(sample["calf_mid_separation"]) < 0.29, "run calves stay beneath hip-width envelope frame %d" % frame)
		require(float(sample["foot_separation"]) < 0.29, "run ankles do not flare beyond idle envelope frame %d" % frame)
		if frame in [14, 29, 44, 59]:
			run_samples.append(sample)
	game.held_keys.clear()
	print("R14_LOWER_LEG_STANCE run=", JSON.stringify(run_samples))

	game.reset_game()
	game.crouching = true
	game._process(1.0)
	var crouch := _measure(false)
	print("R14_LOWER_LEG_STANCE crouch=", JSON.stringify(crouch))
	require(float(crouch["calf_mid_separation"]) < float(rest["calf_mid_separation"]) * 0.90, "crouch calf stance remains narrowed")

	game.reset_game()
	game.player_attack_variant = &"right_kick"
	game.player_strike_timer = 0.50
	game.player_attack_duration = 0.50
	game._process(0.22)
	var kick_contact := _measure(false)
	print("R14_LOWER_LEG_STANCE kick_contact=", JSON.stringify(kick_contact))
	require(float(kick_contact["foot_separation"]) > 0.20, "kick contact retains readable support separation")
	print("R14_LOWER_LEG_STANCE_", "OK" if failures.is_empty() else "FAILED", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func require(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _measure(use_rest: bool) -> Dictionary:
	var skeleton := rig["skeleton"] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var result := {}
	for joint in ["thigh", "shin", "foot"]:
		var left := skeleton.find_bone("%s.L" % joint)
		var right := skeleton.find_bone("%s.R" % joint)
		var left_position := skeleton.get_bone_global_rest(left).origin if use_rest else skeleton.get_bone_global_pose(left).origin
		var right_position := skeleton.get_bone_global_rest(right).origin if use_rest else skeleton.get_bone_global_pose(right).origin
		result["%s_separation" % joint] = right_position.x - left_position.x
		result["%s_left" % joint] = left_position
		result["%s_right" % joint] = right_position
	var left_knee: Vector3 = result["shin_left"]
	var right_knee: Vector3 = result["shin_right"]
	var left_ankle: Vector3 = result["foot_left"]
	var right_ankle: Vector3 = result["foot_right"]
	result["calf_mid_separation"] = lerpf(right_knee.x, right_ankle.x, 0.55) - lerpf(left_knee.x, left_ankle.x, 0.55)
	result["ankle_height_delta"] = absf(left_ankle.y - right_ankle.y)
	return result
