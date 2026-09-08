extends SceneTree

## Four-attack controller, selection, buffering, and exact-R7 pose contract.
##
## Run with:
##   godot --headless --path . --script work/action-quality/attack_combo.gd

const SCENE_PATH := "res://main_3d.tscn"
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const AttackCatalog = preload("res://actors/player_attack_catalog.gd")
const SAMPLE_RATES := [30, 60]
const BODY_PRESETS := [0.88, 1.0, 1.16]
const EPSILON := 0.003

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
	_check(Candidate.is_exact_candidate(candidate_parts), "four-attack sampling uses exact R7")

	_test_seeded_selection(game)
	_test_contact_ownership(game)
	_test_buffer_and_interruptions(game)
	for fps in SAMPLE_RATES:
		for scale in BODY_PRESETS:
			for variant: StringName in AttackCatalog.ORDER:
				_test_variant_pose(game, variant, scale, fps)

	Candidate.clear_material_overrides(candidate_parts)
	Candidate.clear_material_overrides(default_parts)
	game.queue_free()
	_finish()


func _test_seeded_selection(game) -> void:
	game.reset_game()
	game.player_attack_rng.seed = 7707
	var counts := {}
	var previous: StringName = &""
	var repeats := 0
	for index in range(192):
		var lateral := -0.42 if index % 3 == 0 else (0.42 if index % 3 == 1 else 0.0)
		var variant: StringName = game.select_attack_variant(1.55, lateral, true)
		counts[variant] = int(counts.get(variant, 0)) + 1
		if variant == previous:
			repeats += 1
		game.player_attack_last_variant = variant
		previous = variant
	for variant: StringName in AttackCatalog.ORDER:
		_check(int(counts.get(variant, 0)) > 0, "seeded selector reaches %s" % variant)
	_check(repeats == 0, "seeded selector avoids every immediate repeat when alternatives exist")

	game.player_attack_rng.seed = 7711
	for index in range(32):
		var variant: StringName = game.select_attack_variant(2.30, 0.0, true)
		_check(AttackCatalog.kind(variant) == &"kick", "mid-range selector chooses a reach-valid kick")
		game.player_attack_last_variant = variant

	game.player_attack_rng.seed = 7713
	var right_choices := 0
	var left_choices := 0
	for index in range(160):
		game.player_attack_last_variant = &""
		var variant: StringName = game.select_attack_variant(1.55, 0.75, true)
		if AttackCatalog.side(variant) > 0.0:
			right_choices += 1
		else:
			left_choices += 1
	_check(right_choices > left_choices, "right-side target context measurably favors right-side attacks")
	print("ATTACK_SELECTOR seed=7707 counts=", counts,
		" direction_right=", right_choices, " direction_left=", left_choices)


func _test_contact_ownership(game) -> void:
	game.reset_game()
	_place_for_combat(game, 1.48)
	game._commit_strike_variant(AttackCatalog.LEFT_PUNCH, true)
	var root_start: Vector3 = game.player_root.position
	game.held_keys[KEY_W] = true
	_step(game, game.player_attack_contact + 0.001, 60)
	_check_close(game.guard_health, 78.0, "locked contact applies unchanged 22 damage once")
	_check_close(game.momentum, 13.0, "locked contact applies unchanged 13 Momentum once")
	_check_vec3(game.player_root.position, root_start, "held locomotion cannot slide a live strike")
	_step(game, game.player_attack_duration, 60)
	_check_close(game.guard_health, 78.0, "strike recovery cannot repeat contact")
	game.held_keys.clear()

	game.reset_game()
	game.momentum = 20.0
	game.player_root.position = Vector3(2.55, 0.0, 0.0)
	game.guard_root.position = Vector3.ZERO
	game.strike()
	_check(not game.player_attack_target_locked, "out-of-range input owns no target")
	game.player_root.position = Vector3(1.48, 0.0, 0.0)
	_step(game, game.player_attack_contact + 0.001, 60)
	_check_close(game.guard_health, 100.0, "late range entry cannot acquire a target")
	_check_close(game.momentum, 12.0, "late range entry resolves one whiff cost")

	game.reset_game()
	game.momentum = 20.0
	game.player_root.position = Vector3(4.35, 0.0, 3.9)
	game.guard_root.position = Vector3(5.65, 0.0, 3.9)
	game.strike()
	_check(not game.player_attack_target_locked, "vault barrier blocks target ownership")
	_step(game, game.player_attack_contact + 0.001, 60)
	_check_close(game.guard_health, 100.0, "blocked target cannot take attack damage")

	game.reset_game()
	game.momentum = 20.0
	game.player_root.position = Vector3(0.0, 0.0, -1.48)
	game.guard_root.position = Vector3(0.0, 3.04, 0.0)
	game.strike()
	_check(not game.player_attack_target_locked, "different-height target owns no contact")
	_step(game, game.player_attack_contact + 0.001, 60)
	_check_close(game.guard_health, 100.0, "elevated target cannot take grounded damage")

	game.reset_game()
	game.momentum = 20.0
	game.player_root.position = Vector3.ZERO
	game.guard_root.position = Vector3(0.0, 0.0, -1.48)
	game.player_root.rotation.y = 0.0
	game.player_facing_yaw = 0.0
	game.strike()
	_check(not game.player_attack_target_locked, "target behind visible facing cannot own contact")
	_step(game, game.player_attack_contact + 0.001, 60)
	_check_close(game.guard_health, 100.0, "behind-facing target cannot take attack damage")

	game.reset_game()
	game.momentum = 20.0
	_place_for_combat(game, 1.48)
	game._commit_strike_variant(AttackCatalog.RIGHT_PUNCH, true)
	game.guard_root.position = Vector3(0.0, 0.0, -2.0)
	_step(game, game.player_attack_contact + 0.001, 60)
	_check_close(game.guard_health, 100.0, "target crossing behind before contact invalidates the locked hit")
	_check(not game.player_attack_buffered, "crossing behind clears any pending combo ownership")


func _test_buffer_and_interruptions(game) -> void:
	game.reset_game()
	_place_for_combat(game, 1.48)
	game._commit_strike_variant(AttackCatalog.RIGHT_PUNCH, true)
	_step(game, game.player_attack_contact + 0.001, 60)
	var first_variant: StringName = game.player_attack_variant
	_step(game, game.player_attack_duration - game.player_attack_contact - 0.07, 60)
	game.strike()
	_check(game.player_attack_buffered, "one late recovery press fills the bounded buffer")
	game.strike()
	_check(game.player_attack_buffered, "repeated late presses cannot stack the one-slot buffer")
	_step(game, 0.08, 60)
	_check(game.player_strike_timer > 0.0, "buffer starts exactly one follow-up after recovery")
	_check(game.player_attack_variant != first_variant, "buffered follow-up cannot immediately repeat")
	_check_close(game.guard_health, 78.0, "buffered startup cannot stack contact on the prior hit")

	game.cancel_strike()
	_check_close(game.player_strike_timer, 0.0, "interruption clears live attack timer")
	_check(not game.player_attack_buffered and not game.player_attack_target_locked,
		"interruption clears buffer and target ownership")
	_check(game.player_attack_last_variant == &"", "interruption clears combo history")

	game.reset_game()
	_place_for_combat(game, 1.48)
	game._commit_strike_variant(AttackCatalog.RIGHT_KICK, true)
	game.reset_game()
	_check(not game.player_strike_pending and not game.player_attack_target_locked and not game.player_attack_buffered,
		"reset clears pending contact target and buffer state")


func _test_variant_pose(game, variant: StringName, scale: float, fps: int) -> void:
	game.player_scale = scale
	game.reset_game()
	_place_for_combat(game, 1.55 if AttackCatalog.kind(variant) == &"punch" else 2.18)
	_quiet_guard(game)
	game._process(0.0)
	var rig: Dictionary = game.player_visual_parts["authored_rig"]
	var skeleton := rig["skeleton"] as Skeleton3D
	var suffix := "L" if AttackCatalog.side(variant) > 0.0 else "R"
	var neutral_distal_span := _distal_finger_span(skeleton, suffix)
	if fps == 60 and is_equal_approx(scale, 1.0) and variant == AttackCatalog.RIGHT_PUNCH:
		print("ATTACK_NEUTRAL_GEOMETRY shoulder.L=", _bone_world(skeleton, &"upper_arm.L"),
			" elbow.L=", _bone_world(skeleton, &"forearm.L"),
			" hand.L=", _bone_world(skeleton, &"hand.L"),
			" shoulder.R=", _bone_world(skeleton, &"upper_arm.R"),
			" elbow.R=", _bone_world(skeleton, &"forearm.R"),
			" hand.R=", _bone_world(skeleton, &"hand.R"),
			" active_distal_span=", neutral_distal_span)
	game._commit_strike_variant(variant, true)
	game.face_player_toward_guard()
	var root_start: Vector3 = game.player_root.position
	var support_clearance := Vector2(INF, -INF)
	if AttackCatalog.kind(variant) == &"kick":
		var attack_suffix_for_support := "L" if AttackCatalog.side(variant) > 0.0 else "R"
		var support_suffix := "R" if attack_suffix_for_support == "L" else "L"
		support_clearance = _step_tracking_support(
			game, game.player_attack_contact + 0.001, fps, support_suffix, support_clearance
		)
	else:
		_step(game, game.player_attack_contact + 0.001, fps)
	var forward := _player_forward(game)
	var contact_effector_forward := 0.0
	if AttackCatalog.kind(variant) == &"punch":
		var contact_flex := _minimum_long_finger_pose_delta(rig, suffix)
		var contact_distal_span := _distal_finger_span(skeleton, suffix)
		var shoulder := _bone_world(skeleton, StringName("upper_arm.%s" % suffix))
		var elbow := _bone_world(skeleton, StringName("forearm.%s" % suffix))
		var hand := _bone_world(skeleton, StringName("hand.%s" % suffix))
		var guard_suffix := "R" if suffix == "L" else "L"
		var guard_elbow := _bone_world(skeleton, StringName("forearm.%s" % guard_suffix))
		var guard_hand := _bone_world(skeleton, StringName("hand.%s" % guard_suffix))
		contact_effector_forward = hand.dot(forward)
		if fps == 60 and is_equal_approx(scale, 1.0):
			print("ATTACK_CONTACT_GEOMETRY variant=", variant,
				" shoulder=", shoulder, " elbow=", elbow, " hand=", hand,
				" reach=", hand.distance_to(shoulder),
				" forward_lead=", hand.dot(forward) - shoulder.dot(forward),
				" guard_elbow=", guard_elbow, " guard_hand=", guard_hand)
		_check(elbow.dot(forward) > shoulder.dot(forward) + 0.015,
			"%dhz %.2f %s elbow follows shoulder forward" % [fps, scale, variant])
		_check(hand.dot(forward) > elbow.dot(forward) + 0.015,
			"%dhz %.2f %s fist leads contact" % [fps, scale, variant])
		_check(hand.dot(forward) > guard_hand.dot(forward) + 0.18,
			"%dhz %.2f %s active fist stays separated ahead of guard" % [fps, scale, variant])
		_check(guard_hand.y > guard_elbow.y + 0.10,
			"%dhz %.2f %s guard hand stays above its elbow" % [fps, scale, variant])
		_check(contact_flex >= 1.45,
			"%dhz %.2f %s active fingers hold a compact contact curl" % [fps, scale, variant])
		_check(contact_distal_span <= neutral_distal_span * 0.95,
			"%dhz %.2f %s active distal row closes from neutral" % [fps, scale, variant])
	else:
		var pelvis := _bone_world(skeleton, &"pelvis")
		var knee := _bone_world(skeleton, StringName("shin.%s" % suffix))
		var foot := _bone_world(skeleton, StringName("foot.%s" % suffix))
		contact_effector_forward = foot.dot(forward)
		if fps == 60 and is_equal_approx(scale, 1.0):
			print("ATTACK_KICK_GUARD variant=", variant,
				" hand.L=", _bone_world(skeleton, &"hand.L"),
				" hand.R=", _bone_world(skeleton, &"hand.R"),
				" head=", _bone_world(skeleton, &"head"))
		_check(knee.y > pelvis.y - 0.45,
			"%dhz %.2f %s lifts the free knee" % [fps, scale, variant])
		_check(foot.dot(forward) > pelvis.dot(forward) + 0.18,
			"%dhz %.2f %s foot leads contact" % [fps, scale, variant])
	_check(_skeleton_finite(skeleton), "%dhz %.2f %s skeleton remains finite" % [fps, scale, variant])
	_check_vec3(game.player_root.position, root_start,
		"%dhz %.2f %s never writes gameplay root" % [fps, scale, variant])
	_check_close(game.guard_health, 78.0, "%dhz %.2f %s applies one normal hit" % [fps, scale, variant])
	var recovery_progress := 0.82
	var elapsed: float = game.player_attack_duration - game.player_strike_timer
	var recovery_step: float = maxf(game.player_attack_duration * recovery_progress - elapsed, 0.0)
	if AttackCatalog.kind(variant) == &"kick":
		var attack_suffix_for_recovery := "L" if AttackCatalog.side(variant) > 0.0 else "R"
		var recovery_support_suffix := "R" if attack_suffix_for_recovery == "L" else "L"
		support_clearance = _step_tracking_support(
			game, recovery_step, fps, recovery_support_suffix, support_clearance
		)
		var recovery_pelvis := _bone_world(skeleton, &"pelvis")
		var recovery_knee := _bone_world(skeleton, StringName("shin.%s" % suffix))
		var recovery_foot := _bone_world(skeleton, StringName("foot.%s" % suffix))
		_check(recovery_knee.y > recovery_pelvis.y - 0.55,
			"%dhz %.2f %s recovery re-chambers before lowering" % [fps, scale, variant])
		_check(recovery_foot.dot(forward) < contact_effector_forward - 0.16,
			"%dhz %.2f %s recovery withdraws the striking foot" % [fps, scale, variant])
		support_clearance = _step_tracking_support(
			game, game.player_strike_timer, fps, recovery_support_suffix, support_clearance
		)
		if fps == 60 and is_equal_approx(scale, 1.0):
			print("ATTACK_SUPPORT_SOLE variant=", variant, " clearance_range=", support_clearance)
		_check(support_clearance.x >= -0.008 and support_clearance.y <= 0.020,
			"%dhz %.2f %s skinned support sole stays planted" % [fps, scale, variant])
	else:
		_step(game, recovery_step, fps)
		var recovery_elbow := _bone_world(skeleton, StringName("forearm.%s" % suffix))
		var recovery_hand := _bone_world(skeleton, StringName("hand.%s" % suffix))
		var recovery_flex := _minimum_long_finger_pose_delta(rig, suffix)
		_check(recovery_hand.y > recovery_elbow.y + 0.08,
			"%dhz %.2f %s recovery folds fist above elbow" % [fps, scale, variant])
		_check(recovery_hand.dot(forward) < contact_effector_forward - 0.16,
			"%dhz %.2f %s recovery retracts fist from contact" % [fps, scale, variant])
		_check(recovery_flex >= 1.40,
			"%dhz %.2f %s active fingers stay compact through readable recovery" % [fps, scale, variant])
		_step(game, game.player_strike_timer, fps)
	_check_close(game.player_strike_timer, 0.0, "%dhz %.2f %s completes recovery" % [fps, scale, variant])
	_check_close(game.guard_health, 78.0, "%dhz %.2f %s recovery repeats no damage" % [fps, scale, variant])


func _place_for_combat(game, distance: float) -> void:
	game.player_root.position = Vector3(0.0, 0.0, -distance)
	game.guard_root.position = Vector3.ZERO
	game.player_facing_yaw = 0.0
	game.player_root.rotation = Vector3.ZERO


func _quiet_guard(game) -> void:
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0


func _step(game, duration: float, fps: int) -> void:
	var remaining := duration
	var fixed_delta := 1.0 / float(fps)
	while remaining > 0.000001:
		var delta := minf(fixed_delta, remaining)
		game._process(delta)
		remaining -= delta


func _step_tracking_support(
	game, duration: float, fps: int, support_suffix: String, clearance_range: Vector2
) -> Vector2:
	var remaining := duration
	var fixed_delta := 1.0 / float(fps)
	while remaining > 0.000001:
		var delta := minf(fixed_delta, remaining)
		game._process(delta)
		# The timer is decremented before pose evaluation. Do not attribute the
		# first ordinary-grounded frame after recovery to the kick.
		if game.player_strike_timer > 0.0:
			var clearance := _support_sole_clearance(game, support_suffix)
			clearance_range.x = minf(clearance_range.x, clearance)
			clearance_range.y = maxf(clearance_range.y, clearance)
		remaining -= delta
	return clearance_range


func _support_sole_clearance(game, support_suffix: String) -> float:
	var rig: Dictionary = game.player_visual_parts["authored_rig"]
	var skeleton := rig["skeleton"] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	# Compose the node transforms explicitly. `Skeleton3D.to_global()` can retain
	# the pre-contact-root cache in this same frame, while rendering already sees
	# the newly assigned imported-root lift.
	var to_actor := Transform3D.IDENTITY
	var node: Node3D = skeleton
	var actor := (game.player_visual_parts["visual_root"] as Node3D).get_parent() as Node3D
	while node != actor:
		to_actor = node.transform * to_actor
		node = node.get_parent() as Node3D
	var minimum_y := INF
	for contact: Dictionary in rig["foot_contacts"]:
		if contact["side"] != support_suffix:
			continue
		var skinned := Vector3.ZERO
		for influence: Dictionary in contact["influences"]:
			skinned += (
				skeleton.get_bone_global_pose(influence["bone"])
				* influence["bind_pose"]
				* contact["point"]
			) * float(influence["weight"])
		var total_weight: float = contact["total_weight"]
		if total_weight > 0.0:
			skinned /= total_weight
		minimum_y = minf(minimum_y, (actor.global_transform * (to_actor * skinned)).y)
	return minimum_y


func _bone_world(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	var bone := skeleton.find_bone(bone_name)
	assert(bone >= 0, "four-attack test requires bone %s" % bone_name)
	skeleton.force_update_all_bone_transforms()
	return skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)


func _minimum_long_finger_pose_delta(rig: Dictionary, suffix: String) -> float:
	var skeleton := rig["skeleton"] as Skeleton3D
	var minimum := INF
	for finger in ["index", "middle", "ring", "pinky"]:
		var total := 0.0
		for segment in range(1, 4):
			var name := StringName("%s.%02d.%s" % [finger, segment, suffix])
			var bone: int = rig["bone_indices"][name]
			var rest: Quaternion = rig["local_rest_rotations"][name]
			total += rest.angle_to(skeleton.get_bone_pose_rotation(bone))
		minimum = minf(minimum, total)
	return minimum


func _distal_finger_span(skeleton: Skeleton3D, suffix: String) -> float:
	var points: Array[Vector3] = []
	for finger in ["index", "middle", "ring", "pinky"]:
		points.append(_bone_world(skeleton, StringName("%s.03.%s" % [finger, suffix])))
	var span := 0.0
	for first in points.size():
		for second in range(first + 1, points.size()):
			span = maxf(span, points[first].distance_to(points[second]))
	return span


func _player_forward(game) -> Vector3:
	return Vector3(sin(game.player_root.rotation.y), 0.0, cos(game.player_root.rotation.y)).normalized()


func _skeleton_finite(skeleton: Skeleton3D) -> bool:
	skeleton.force_update_all_bone_transforms()
	for bone in skeleton.get_bone_count():
		var pose := skeleton.get_bone_global_pose(bone)
		if not pose.origin.is_finite() or not pose.basis.is_finite():
			return false
	return true


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
		return
	failures.append(label)
	push_error("FAIL %s" % label)


func _check_close(actual: float, expected: float, label: String, tolerance := EPSILON) -> void:
	_check(absf(actual - expected) <= tolerance,
		"%s (actual=%.5f expected=%.5f tolerance=%.5f)" % [label, actual, expected, tolerance])


func _check_vec3(actual: Vector3, expected: Vector3, label: String, tolerance := EPSILON) -> void:
	_check(actual.distance_to(expected) <= tolerance,
		"%s (actual=%s expected=%s tolerance=%.5f)" % [label, actual, expected, tolerance])


func _finish() -> void:
	var status := "OK" if failures.is_empty() else "FAILED"
	print("R7_ATTACK_COMBO_", status, " checks=", checks, " failures=", failures.size())
	for failure in failures:
		print("FAILED_CHECK ", failure)
	quit(0 if failures.is_empty() else 1)
