extends SceneTree

## Focused real-controller contract for the action-quality pass. This protects
## conventional transition decisions that were previously implicit while the
## established combat/travel numbers remain owned by the 196/198-check suites.

const SCENE_PATH := "res://main_3d.tscn"
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const Builder = preload("res://actors/character_visual_builder.gd")
const EPSILON := 0.002

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "active courtyard scene loads")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var default_parts: Dictionary = game.player_visual_parts
	(default_parts["visual_root"] as Node3D).visible = false
	var candidate_parts := Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_visual_parts = candidate_parts
	game.player_accent_material = candidate_parts["accent_material"]
	_check(Candidate.is_exact_candidate(candidate_parts), "focused transitions use exact frozen R7")

	_test_traversal_exclusion(game)
	_test_counter_exclusion(game)
	_test_hurt_and_downed(game)
	_test_paired_takedown_fall(game)
	_test_r7_motion_semantics(game)
	_test_success_stability(game)

	Candidate.clear_material_overrides(candidate_parts)
	Candidate.clear_material_overrides(default_parts)
	game.queue_free()
	_finish()


func _test_traversal_exclusion(game) -> void:
	game.reset_game()
	game.player_root.position = game.ANCHOR_POSITION
	game.last_travel_direction = Vector3.RIGHT
	game.jump_or_vault()
	_check(game.jump_active and not game.player_airborne, "jump begins before overlap probe")
	game.grapple()
	_check(not game.grapple_active, "grapple rejects an active jump instead of parking stale jump state")
	_check(game.jump_active and not game.player_airborne, "rejected grapple leaves the active jump coherent")
	_step(game, game.jump_duration + 0.05, 60)
	_check(not game.jump_active and not game.player_airborne, "jump completes normally after rejected grapple")

	game.reset_game()
	game.player_root.position = game.ANCHOR_POSITION
	game.crouching = true
	game.grapple()
	_check(game.grapple_active, "in-range grapple begins from an open-space crouch")
	_check(not game.crouching, "grapple exits open-space crouch before traversal")
	_step(game, 0.16, 60)
	_check(game.player_root.position.y > game.PERCH_TOP_Y + 0.15, "grapple midpoint clears the perch lip instead of crossing its mesh")

	game.reset_game()
	game.player_root.position = game.ANCHOR_POSITION
	game.guard_root.position = game.player_root.position + Vector3(1.6, 0.0, 0.0)
	game.strike()
	_check(game.player_strike_timer > 0.0, "strike begins before traversal cancellation probe")
	game.grapple()
	_check(game.grapple_active, "grapple may conventionally replace a grounded strike")
	_check(game.player_strike_timer <= 0.0 and not game.player_strike_pending, "grapple clears pending strike contact")


func _test_counter_exclusion(game) -> void:
	game.reset_game()
	game.player_root.position = game.ANCHOR_POSITION
	game.guard_root.position = game.player_root.position + Vector3(1.5, 0.0, 0.0)
	game.attack_timer = 0.40
	game.counter()
	var remaining: float = game.player_counter_timer
	_check(remaining > 0.0, "counter begins before overlap probes")
	game.toggle_crouch()
	game.jump_or_vault()
	game.grapple()
	_check(not game.crouching, "crouch rejects counter recovery")
	_check(not game.jump_active and not game.player_airborne, "jump rejects counter recovery")
	_check(not game.grapple_active, "grapple rejects counter recovery")
	_check_close(game.player_counter_timer, remaining, "rejected overlaps do not cancel counter presentation")


func _test_hurt_and_downed(game) -> void:
	for fps in [30, 60]:
		game.reset_game()
		game.momentum = 50.0
		game.guard_root.position = Vector3(7.0, 0.0, -4.5)
		var actor_start: Vector3 = game.player_root.position
		game.damage_player(18.0, "HURT PROBE")
		_check_close(game.player_health, 82.0, "%dhz hurt preserves 18 damage" % fps)
		_check_close(game.momentum, 25.0, "%dhz hurt preserves 25 Momentum loss" % fps)
		_check_close(game.player_hurt_timer, game.PLAYER_HURT_DURATION, "%dhz hurt starts presentation timer" % fps)
		_step(game, 0.16, fps)
		var torso := game.player_visual_parts["torso_root"] as Node3D
		_check(torso.rotation.length() > 0.04, "%dhz hurt produces a visible non-displacing recoil" % fps)
		_check_vec3(game.player_root.position, actor_start, "%dhz hurt pose does not displace gameplay root" % fps)
		_step(game, game.PLAYER_HURT_DURATION, fps)
		_check_close(game.player_hurt_timer, 0.0, "%dhz hurt presentation recovers" % fps)

		game.damage_player(1000.0, "DOWN PROBE")
		_check_close(game.player_health, 0.0, "%dhz health clamps to zero" % fps)
		var guard_start: Vector3 = game.guard_root.position
		var downed_root: Vector3 = game.player_root.position
		_press_and_release(game, KEY_D)
		game.strike()
		game.evade()
		game.jump_or_vault()
		game.grapple()
		_check_vec3(game.player_root.position, downed_root, "%dhz downed input cannot move player" % fps)
		_check(game.player_strike_timer <= 0.0 and game.evade_timer <= 0.0 and not game.jump_active and not game.grapple_active, "%dhz downed input cannot start actions" % fps)
		_step(game, game.PLAYER_DOWNED_DURATION + 0.05, fps)
		_check_vec3(game.player_root.position, downed_root, "%dhz downed presentation preserves gameplay root" % fps)
		_check_vec3(game.guard_root.position, guard_start, "%dhz downed state freezes hostile simulation" % fps)
		var action_root := game.player_visual_parts["action_root"] as Node3D
		_check(absf(action_root.rotation.z) > 1.20, "%dhz downed pose uses a coherent whole-body side collapse" % fps)
		var camera_yaw: float = game.camera_yaw
		_press_and_release(game, KEY_L)
		_check(game.camera_yaw > camera_yaw, "%dhz camera remains available while downed" % fps)
		_press_and_release(game, KEY_R)
		_check_close(game.player_health, 100.0, "%dhz restart restores downed player" % fps)
		_check_close(game.player_downed_elapsed, 0.0, "%dhz restart clears downed presentation" % fps)


func _test_success_stability(game) -> void:
	game.reset_game()
	game.success = true
	var player_start: Vector3 = game.player_root.position
	var camera_yaw: float = game.camera_yaw
	_press_and_release(game, KEY_D)
	_press_and_release(game, KEY_SPACE)
	_press_and_release(game, KEY_C)
	_check_vec3(game.player_root.position, player_start, "success state rejects movement input")
	_check(game.player_strike_timer <= 0.0 and game.evade_timer <= 0.0, "success state rejects action input")
	_press_and_release(game, KEY_L)
	_check(game.camera_yaw > camera_yaw, "camera remains available after success")
	_press_and_release(game, KEY_R)
	_check(not game.success, "restart remains available after success")


func _test_paired_takedown_fall(game) -> void:
	game.reset_game()
	game.guard_root.position = Vector3(-4.6, 0.0, 0.2)
	game.player_root.position = Vector3(-2.6, 0.0, 0.2)
	game.guard_forward = Vector3.LEFT
	game.guard_alert = true
	game.attack_cooldown = 0.0
	game.stealth_takedown()
	_check(game.player_takedown_timer > 0.0, "paired-pose fixture begins a real eligible takedown")
	_step(game, 0.80, 60)
	_check(game.guard_defeated, "paired-pose fixture reaches the real takedown contact")
	var guard_body := game.guard_visual_parts["body_root"] as Node3D
	_check(absf(guard_body.rotation.z) > 1.10, "takedown victim falls as one connected body instead of folding at the helmet")
	_check(guard_body.position.y > 0.10 and guard_body.position.y < 0.50, "takedown victim settles at supported floor height")
	_step(game, 0.40, 60)
	_check_close(game.player_takedown_timer, 0.0, "paired takedown completes without leaving its action pose active")
	_check(absf(guard_body.rotation.z) > 1.10, "defeated guard preserves the coherent side-fall silhouette")


func _test_r7_motion_semantics(game) -> void:
	game.reset_game()
	var parts: Dictionary = game.player_visual_parts
	var rig: Dictionary = parts["authored_rig"]
	var skeleton := rig["skeleton"] as Skeleton3D
	Builder.pose_player(parts, 0.0, 0.0, 1.0, &"crouch", 0.0)
	skeleton.force_update_all_bone_transforms()
	var left_hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand.L")).origin
	var right_hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand.R")).origin
	var chest := skeleton.get_bone_global_pose(skeleton.find_bone("chest")).origin
	var hand_forward := (left_hand.z + right_hand.z) * 0.5 - chest.z
	_check(hand_forward > 0.08, "R7 crouch keeps both hands visibly ahead of the folded chest: %.4f" % hand_forward)
	_test_crouch_arm_geometry(parts, skeleton)

	Builder.pose_player(parts, 0.0, 0.0, 1.0, &"jump", 0.50, &"right_punch", 0.0, 1.0, true)
	var torso := parts["torso_root"] as Node3D
	var left_leg := parts["left_leg"] as Node3D
	var right_leg := parts["right_leg"] as Node3D
	var left_arm := parts["left_arm"] as Node3D
	var right_arm := parts["right_arm"] as Node3D
	_check(torso.rotation.x > 0.03, "R7 jump keeps mass slightly forward instead of arching backward")
	_check(left_leg.rotation.x * right_leg.rotation.x < 0.0, "R7 jump separates lead and trailing legs")
	_check(left_arm.rotation.x * right_arm.rotation.x < 0.0, "R7 jump uses a contralateral arm silhouette")

	Builder.pose_player(parts, 0.0, 0.0, 1.0, &"jump_land", 1.0)
	_check((parts["left_knee"] as Node3D).rotation.x < 0.08 and (parts["right_knee"] as Node3D).rotation.x < 0.08, "R7 landing recovery releases compression before returning to grounded")

	for frame in 45:
		Builder.pose_player(parts, 0.0, 0.0, 1.0 / 60.0, &"downed", minf(float(frame + 1) / 36.0, 1.0))
	skeleton.force_update_all_bone_transforms()
	var downed_chest_y := _bone_height_from_root(game, skeleton, "chest")
	var downed_head_y := _bone_height_from_root(game, skeleton, "head")
	var downed_support_hand_y := _bone_height_from_root(game, skeleton, "hand.L")
	var downed_support_toe_y := _bone_height_from_root(game, skeleton, "toe.L")
	_check(downed_chest_y > 0.30 and downed_chest_y < 0.65, "R7 downed chest settles near the floor instead of hovering: %.4f" % downed_chest_y)
	_check(downed_head_y > 0.25 and downed_head_y < 0.60, "R7 downed head remains supported near the fallen chest: %.4f" % downed_head_y)
	_check(absf(downed_head_y - downed_chest_y) < 0.15, "R7 downed head and chest preserve a connected side-fall silhouette")
	_check(downed_support_hand_y > 0.10 and downed_support_hand_y < 0.45, "R7 downed lower hand braces near the floor: %.4f" % downed_support_hand_y)
	_check(downed_support_toe_y > -0.03 and downed_support_toe_y < 0.18, "R7 downed lower toe supplies grounded support: %.4f" % downed_support_toe_y)


func _test_crouch_arm_geometry(parts: Dictionary, skeleton: Skeleton3D) -> void:
	var min_flex := INF
	var max_flex := -INF
	var min_inward := INF
	var min_center_clearance := INF
	# Cover the full idle and moving crouch cycle on actual bone positions.
	# Positive flexion and inward wrists are independent of driver magnitudes.
	for moving in [0.0, 1.0]:
		for frame in 32:
			Builder.pose_player(parts, TAU * frame / 32.0, moving, 1.0, &"crouch", moving)
			var chest := skeleton.get_bone_global_pose(skeleton.find_bone("chest")).origin
			for side in ["L", "R"]:
				var index := skeleton.find_bone("upper_arm." + side)
				var shoulder := skeleton.get_bone_global_pose(index).origin
				var elbow := skeleton.get_bone_global_pose(skeleton.find_bone("forearm." + side)).origin
				var wrist := skeleton.get_bone_global_pose(skeleton.find_bone("hand." + side)).origin
				var transport := skeleton.get_bone_global_pose(index).basis * skeleton.get_bone_global_rest(index).basis.inverse()
				var flex := (PI - (shoulder - elbow).angle_to(wrist - elbow)) * signf((elbow - shoulder).cross(wrist - elbow).dot(transport * Vector3.LEFT))
				min_flex = minf(min_flex, flex)
				max_flex = maxf(max_flex, flex)
				min_inward = minf(min_inward, absf(elbow.x - chest.x) - absf(wrist.x - chest.x))
				min_center_clearance = minf(min_center_clearance, (wrist.x - chest.x) * signf(shoulder.x - chest.x))
	_check(min_flex >= deg_to_rad(40.0) and max_flex <= deg_to_rad(110.0), "crouch elbows keep a relaxed forward fold through idle and travel")
	_check(min_inward >= 0.03, "crouch wrists stay inward of their elbows through the full cycle")
	_check(min_center_clearance >= 0.06, "crouch hands keep their own side of the body center")
	print("CROUCH_ARMS flex_deg=", Vector2(rad_to_deg(min_flex), rad_to_deg(max_flex)), " min_inward=", min_inward, " center_clearance=", min_center_clearance)


func _bone_height_from_root(game, skeleton: Skeleton3D, bone_name: String) -> float:
	var bone := skeleton.find_bone(bone_name)
	var world_position := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
	return world_position.y - game.player_root.global_position.y


func _step(game, duration: float, fps: int) -> void:
	var remaining := duration
	var fixed_delta := 1.0 / float(fps)
	while remaining > 0.000001:
		var delta := minf(fixed_delta, remaining)
		game._process(delta)
		remaining -= delta


func _key_event(game, keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	game._unhandled_input(event)


func _press_and_release(game, keycode: Key) -> void:
	_key_event(game, keycode, true)
	_key_event(game, keycode, false)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
		return
	failures.append(label)
	push_error("FAIL %s" % label)


func _check_close(actual: float, expected: float, label: String, tolerance := EPSILON) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (actual=%.5f expected=%.5f tolerance=%.5f)" % [label, actual, expected, tolerance])


func _check_vec3(actual: Vector3, expected: Vector3, label: String, tolerance := EPSILON) -> void:
	_check(actual.distance_to(expected) <= tolerance, "%s (actual=%s expected=%s tolerance=%.5f)" % [label, actual, expected, tolerance])


func _finish() -> void:
	print("GLOAM_ACTION_QUALITY_TRANSITIONS_", "OK" if failures.is_empty() else "FAILED", " checks=", checks, " failures=", failures.size())
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)
