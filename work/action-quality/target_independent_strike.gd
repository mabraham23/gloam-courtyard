extends SceneTree

## Target-independent SPACE-strike regression for the exact R7 review fixture.
##
## Run with:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##     --script work/action-quality/target_independent_strike.gd
##
## This is an isolated desired-behavior harness. It never loads from the default
## scene and does not alter runtime state outside its temporary scene instance.

const SCENE_PATH := "res://main_3d.tscn"
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const AttackCatalog = preload("res://actors/player_attack_catalog.gd")
const EPSILON := 0.003
const FPS := 60
const VISIBLE_BONES: Array[StringName] = [
	&"pelvis", &"chest",
	&"upper_arm.L", &"forearm.L", &"hand.L",
	&"upper_arm.R", &"forearm.R", &"hand.R",
	&"thigh.L", &"shin.L", &"foot.L",
	&"thigh.R", &"shin.R", &"foot.R",
]

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
	_check(Candidate.is_exact_candidate(candidate_parts), "target-independent strike fixture uses exact frozen R7")

	_test_context_visibility(game)
	_test_neutral_variant_variety(game)
	_test_one_whiff_buffer(game)
	_test_interruptions(game)

	Candidate.clear_material_overrides(candidate_parts)
	Candidate.clear_material_overrides(default_parts)
	game.queue_free()
	_finish()


func _test_context_visibility(game) -> void:
	for context in [&"empty_space", &"facing_away", &"post_defeat", &"safe_perch"]:
		game.reset_game()
		game.player_root.position = Vector3.ZERO
		game.player_root.rotation = Vector3.ZERO
		game.player_facing_yaw = 0.0
		game.guard_root.position = Vector3(8.0, 0.0, -5.0)
		_quiet_guard(game)
		match context:
			&"facing_away":
				game.guard_root.position = Vector3(0.0, 0.0, -1.48)
			&"post_defeat":
				game.guard_health = 0.0
				game.guard_defeated = true
			&"safe_perch":
				game.player_root.position = Vector3(6.0, game.PERCH_TOP_Y, -2.4)
				game.player_on_perch = true
				game.player_airborne = false
				game.guard_root.position = Vector3(6.0, 0.0, -2.4)
		var root_start: Vector3 = game.player_root.position
		var guard_health_start: float = game.guard_health
		var neutral_pose := _capture_pose(_skeleton(game))
		_press_and_release(game, KEY_SPACE)
		var started: bool = game.player_strike_timer > 0.0
		_check(started, "%s SPACE starts a visible target-independent strike" % context)
		_check(AttackCatalog.is_valid(game.player_attack_variant), "%s selects a valid neutral attack variant" % context)
		_check(not game.player_attack_target_locked, "%s owns no invalid target contact" % context)
		var duration: float = game.player_attack_duration
		_step(game, duration * 0.32, FPS)
		var pose_delta := _maximum_pose_delta(_skeleton(game), neutral_pose)
		print("TARGET_FREE_STRIKE_VISIBLE context=", context,
			" started=", started,
			" variant=", game.player_attack_variant,
			" pose_delta=", pose_delta,
			" root=", game.player_root.position)
		_check(pose_delta >= 0.10, "%s strike reaches a visibly distinct articulated pose" % context)
		_step(game, duration + 0.02, FPS)
		_check_close(game.guard_health, guard_health_start, "%s strike causes no phantom guard damage" % context)
		_check(not game.player_attack_contact_connected, "%s strike reports no phantom connected contact" % context)
		_check_vec3(game.player_root.position, root_start, "%s strike preserves gameplay root" % context)
		if context == &"safe_perch":
			_check(game.player_on_perch and not game.player_airborne,
				"safe-perch strike remains visibly supported on the perch")


func _test_neutral_variant_variety(game) -> void:
	game.reset_game()
	game.player_root.position = Vector3.ZERO
	game.guard_root.position = Vector3(8.0, 0.0, -5.0)
	game.player_root.rotation = Vector3.ZERO
	game.player_facing_yaw = 0.0
	game.player_attack_rng.seed = 92841
	_quiet_guard(game)
	var counts := {}
	var previous: StringName = &""
	var immediate_repeats := 0
	for sample in 32:
		_press_and_release(game, KEY_SPACE)
		var variant: StringName = game.player_attack_variant
		_check(game.player_strike_timer > 0.0, "neutral SPACE sample %d begins an action" % sample)
		_check(not game.player_attack_target_locked, "neutral SPACE sample %d remains target-free" % sample)
		counts[variant] = int(counts.get(variant, 0)) + 1
		if variant == previous:
			immediate_repeats += 1
		previous = variant
		_step(game, game.player_attack_contact + 0.001, FPS)
		_check_close(game.guard_health, 100.0, "neutral SPACE sample %d applies no phantom damage" % sample)
		_check(not game.player_attack_contact_connected, "neutral SPACE sample %d remains a whiff" % sample)
		_step(game, game.player_strike_timer + 0.001, FPS)
		_check_close(game.player_strike_timer, 0.0, "neutral SPACE sample %d completes" % sample)
	for variant: StringName in AttackCatalog.ORDER:
		_check(int(counts.get(variant, 0)) > 0, "neutral SPACE selection reaches %s" % variant)
	_check(immediate_repeats == 0, "neutral SPACE selection avoids immediate repeats")
	_check_close(game.guard_health, 100.0, "neutral variant sequence causes no phantom damage")
	print("TARGET_FREE_STRIKE_VARIETY seed=92841 counts=", counts,
		" immediate_repeats=", immediate_repeats)


func _test_one_whiff_buffer(game) -> void:
	game.reset_game()
	game.player_root.position = Vector3.ZERO
	game.guard_root.position = Vector3(8.0, 0.0, -5.0)
	game.player_root.rotation = Vector3.ZERO
	game.player_facing_yaw = 0.0
	game.player_attack_rng.seed = 92843
	game.momentum = 30.0
	_quiet_guard(game)
	_press_and_release(game, KEY_SPACE)
	var first_variant: StringName = game.player_attack_variant
	_step(game, game.player_attack_contact + 0.001, FPS)
	_check_close(game.guard_health, 100.0, "first buffered-sequence whiff causes no phantom damage")
	_check_close(game.momentum, 22.0, "first target-free contact applies one whiff cost")
	_step(game, maxf(game.player_strike_timer - 0.07, 0.0), FPS)
	_press_and_release(game, KEY_SPACE)
	_check(game.player_attack_buffered, "one SPACE press buffers during the final recovery tenth of a whiff")
	_press_and_release(game, KEY_SPACE)
	_check(game.player_attack_buffered, "repeated late SPACE cannot stack beyond the one-slot whiff buffer")
	_step(game, 0.071, FPS)
	var followup_started: bool = game.player_strike_timer > 0.0
	var second_variant: StringName = game.player_attack_variant
	print("TARGET_FREE_STRIKE_BUFFER first=", first_variant,
		" second=", second_variant,
		" followup_started=", followup_started,
		" timer=", game.player_strike_timer)
	_check(followup_started, "late whiff buffer starts exactly one target-free follow-up")
	_check(second_variant != first_variant, "buffered target-free follow-up uses a different neutral variant")
	_check(not game.player_attack_target_locked, "buffered target-free follow-up owns no target")
	_check_close(game.guard_health, 100.0, "buffered startup causes no phantom damage")
	if followup_started:
		_step(game, game.player_attack_contact + 0.001, FPS)
	_check_close(game.guard_health, 100.0, "buffered whiff contact causes no phantom damage")
	_check_close(game.momentum, 14.0, "buffered follow-up applies exactly one additional whiff cost")
	_step(game, game.player_strike_timer + 0.02, FPS)
	_check_close(game.player_strike_timer, 0.0, "one-slot whiff buffer cannot start a third action")
	_check(not game.player_attack_buffered and not game.player_attack_target_locked,
		"completed whiff buffer clears queue and target ownership")
	_check_close(game.guard_health, 100.0, "complete buffered whiff sequence causes no phantom damage")


func _test_interruptions(game) -> void:
	# Evade interruption after contact must clear the late whiff queue.
	_prepare_buffered_whiff(game, Vector3.ZERO, Vector3(8.0, 0.0, -5.0), 20.0)
	game.evade()
	_check(game.invulnerable > 0.0, "evade starts while interrupting target-free recovery")
	_assert_attack_cleared(game, "evade interruption")
	var evade_guard_health: float = game.guard_health
	_step(game, 0.55, FPS)
	_check_close(game.guard_health, evade_guard_health, "evade-interrupted whiff cannot deal stale damage")

	# Open-space crouch is a conventional grounded cancellation.
	_prepare_buffered_whiff(game, Vector3.ZERO, Vector3(8.0, 0.0, -5.0), 20.0)
	game.toggle_crouch()
	_check(game.crouching, "crouch starts while interrupting target-free recovery")
	_assert_attack_cleared(game, "crouch interruption")

	# Jump cancels both pending contact and a late queue before leaving ground.
	_prepare_buffered_whiff(game, Vector3.ZERO, Vector3(8.0, 0.0, -5.0), 20.0)
	game.last_travel_direction = Vector3.FORWARD
	game.jump_or_vault()
	_check(game.jump_active and game.player_airborne, "jump starts while interrupting target-free recovery")
	_assert_attack_cleared(game, "jump interruption")

	# Grapple uses its normal in-range route and clears the strike state first.
	_prepare_buffered_whiff(game, game.ANCHOR_POSITION, Vector3(-8.0, 0.0, 5.0), 20.0)
	game.grapple()
	_check(game.grapple_active, "grapple starts while interrupting target-free recovery")
	_assert_attack_cleared(game, "grapple interruption")

	# Eligible takedown should replace a facing-away whiff without stale contact.
	_prepare_buffered_whiff(game, Vector3(-2.6, 0.0, 0.2), Vector3(-4.6, 0.0, 0.2), 20.0, PI * 0.5)
	game.guard_forward = Vector3.LEFT
	game.stealth_takedown()
	_check(game.player_takedown_timer > 0.0, "takedown starts while interrupting target-free recovery")
	_assert_attack_cleared(game, "takedown interruption")

	# Taking a hit is a hard interruption: no buffered or pending attack may
	# survive the hurt state and apply contact later.
	_prepare_buffered_whiff(game, Vector3.ZERO, Vector3(8.0, 0.0, -5.0), 30.0)
	var hurt_guard_health: float = game.guard_health
	game.damage_player(18.0, "TARGET-FREE STRIKE INTERRUPTION PROBE")
	_check(game.player_hurt_timer > 0.0, "hurt presentation starts during target-free recovery")
	_assert_attack_cleared(game, "hurt interruption")
	_step(game, 0.60, FPS)
	_check_close(game.guard_health, hurt_guard_health, "hurt-interrupted whiff cannot deal stale damage")

	# Reset remains the final stale-state negative control.
	_prepare_buffered_whiff(game, Vector3.ZERO, Vector3(8.0, 0.0, -5.0), 20.0)
	game.reset_game()
	_assert_attack_cleared(game, "reset interruption")
	_step(game, 0.60, FPS)
	_check_close(game.guard_health, 100.0, "reset-interrupted whiff cannot deal stale damage")


func _prepare_buffered_whiff(
	game,
	player_position: Vector3,
	guard_position: Vector3,
	momentum: float,
	yaw := 0.0
) -> void:
	game.reset_game()
	game.player_root.position = player_position
	game.guard_root.position = guard_position
	game.player_root.rotation = Vector3(0.0, yaw, 0.0)
	game.player_facing_yaw = yaw
	game.momentum = momentum
	_quiet_guard(game)
	_press_and_release(game, KEY_SPACE)
	_step(game, game.player_attack_contact + 0.001, FPS)
	_step(game, maxf(game.player_strike_timer - 0.07, 0.0), FPS)
	_press_and_release(game, KEY_SPACE)
	_check(game.player_attack_buffered, "interruption fixture owns one late whiff buffer")


func _assert_attack_cleared(game, label: String) -> void:
	_check_close(game.player_strike_timer, 0.0, "%s clears strike timer" % label)
	_check(not game.player_strike_pending, "%s clears pending contact" % label)
	_check(not game.player_attack_buffered, "%s clears buffered follow-up" % label)
	_check(not game.player_attack_target_locked, "%s clears target ownership" % label)


func _capture_pose(skeleton: Skeleton3D) -> Dictionary:
	skeleton.force_update_all_bone_transforms()
	var result := {}
	for bone_name: StringName in VISIBLE_BONES:
		var bone := skeleton.find_bone(bone_name)
		assert(bone >= 0, "target-independent strike test requires bone %s" % bone_name)
		result[bone_name] = skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	return result


func _maximum_pose_delta(skeleton: Skeleton3D, reference: Dictionary) -> float:
	skeleton.force_update_all_bone_transforms()
	var maximum := 0.0
	for bone_name: StringName in VISIBLE_BONES:
		var bone := skeleton.find_bone(bone_name)
		var rotation := skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		maximum = maxf(maximum, rotation.angle_to(reference[bone_name] as Quaternion))
	return maximum


func _skeleton(game) -> Skeleton3D:
	return game.player_visual_parts["authored_rig"]["skeleton"] as Skeleton3D


func _quiet_guard(game) -> void:
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0


func _key_event(game, keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	game._unhandled_input(event)


func _press_and_release(game, keycode: Key) -> void:
	_key_event(game, keycode, true)
	_key_event(game, keycode, false)


func _step(game, duration: float, fps: int) -> void:
	var remaining := duration
	var fixed_delta := 1.0 / float(fps)
	while remaining > 0.000001:
		var delta := minf(fixed_delta, remaining)
		game._process(delta)
		remaining -= delta


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
		return
	failures.append(label)
	push_error("FAIL %s" % label)


func _check_close(actual: float, expected: float, label: String, tolerance := EPSILON) -> void:
	_check(absf(actual - expected) <= tolerance,
		"%s (actual=%.6f expected=%.6f tolerance=%.6f)" % [label, actual, expected, tolerance])


func _check_vec3(actual: Vector3, expected: Vector3, label: String, tolerance := EPSILON) -> void:
	_check(actual.distance_to(expected) <= tolerance,
		"%s (actual=%s expected=%s tolerance=%.6f)" % [label, actual, expected, tolerance])


func _finish() -> void:
	print("TARGET_INDEPENDENT_STRIKE_", "OK" if failures.is_empty() else "FAILED",
		" checks=", checks, " failures=", failures.size())
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)
