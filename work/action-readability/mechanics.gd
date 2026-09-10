extends SceneTree

## Test-only mechanics regression for the active Gloam courtyard scene.
## The real scene is instantiated, automatic processing is disabled, and all
## time-dependent behavior is advanced explicitly through `_process()`.

const SCENE_PATH := "res://main_3d.tscn"
const EPSILON := 0.001
const FIXED_DELTA := 1.0 / 60.0

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "active main_3d scene loads")
	if packed == null:
		_finish()
		return

	var game := packed.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED

	_test_reset_and_customization(game)
	_test_spacing_and_combat(game)
	_test_strike_action_timing(game)
	_test_counters_and_damage(game)
	_test_defeat_fade_and_restart(game)
	_test_grapple_perch_fall_and_height(game)
	_test_evade(game)
	_test_crouch_and_clearance(game)
	_test_jump_and_vault(game)
	_test_takedown_action_timing(game)
	_test_stealth_exit_and_restart(game)

	game.queue_free()
	_finish()


func _test_reset_and_customization(game) -> void:
	game.reset_game()
	_check_vec3(game.player_root.position, Vector3(-6.0, 0.0, 2.5), "reset player spawn")
	_check_vec3(game.guard_root.position, Vector3.ZERO, "reset guard spawn")
	_check_close(game.player_health, 100.0, "reset player health")
	_check_close(game.momentum, 0.0, "reset Momentum")
	_check_close(game.guard_health, 100.0, "reset guard health")
	_check(not game.guard_defeated and not game.success, "reset clears terminal states")

	_press_and_release(game, KEY_1)
	_check_close(game.player_scale, 0.88, "body preset 1 value")
	_check_vec3(game.player_root.scale, Vector3.ONE * 1.35 * 0.88, "body preset 1 scale")
	_press_and_release(game, KEY_2)
	_check_close(game.player_scale, 1.0, "body preset 2 value")
	_check_vec3(game.player_root.scale, Vector3.ONE * 1.35, "body preset 2 scale")
	_press_and_release(game, KEY_3)
	_check_close(game.player_scale, 1.16, "body preset 3 value")
	_check_vec3(game.player_root.scale, Vector3.ONE * 1.35 * 1.16, "body preset 3 scale")
	_press_and_release(game, KEY_2)

	var original_outfit: int = game.outfit_index
	_press_and_release(game, KEY_X)
	_check(game.outfit_index == (original_outfit + 1) % game.outfit_colors.size(), "accent index toggles")
	var expected_accent: Color = game.outfit_colors[game.outfit_index]
	_check((game.player_accent_material as StandardMaterial3D).albedo_color.is_equal_approx(expected_accent), "authored accent material remains customizable")


func _test_spacing_and_combat(game) -> void:
	game.reset_game()
	game.player_root.position = Vector3.ZERO
	game.guard_root.position = Vector3.ZERO
	game.move_player_world(Vector3.ZERO, 0.0)
	_check_close(game.flat_distance(game.player_root.position, game.guard_root.position), 1.48, "player resolves to 1.48 personal space", 0.011)

	game.reset_game()
	game.player_root.position = Vector3.ZERO
	game.guard_root.position = Vector3.ZERO
	game.move_guard_world(Vector3.ZERO, 0.0)
	_check_close(game.flat_distance(game.player_root.position, game.guard_root.position), 1.48, "guard resolves to 1.48 personal space", 0.011)



func _test_strike_action_timing(game) -> void:
	game.reset_game()
	_place_for_combat(game, 1.48)
	game.strike()
	_check_close(game.player_strike_timer, game.player_attack_duration, "strike starts its selected exact action duration")
	_check_close(game.guard_health, 100.0, "strike does not damage on input")
	_check_close(game.momentum, 0.0, "strike does not award Momentum on input")
	_step(game, game.player_attack_contact - 0.001)
	_check_close(game.guard_health, 100.0, "strike remains pending before selected contact")
	_step(game, 0.002)
	_check_close(game.guard_health, 78.0, "strike contact deals 22 damage once")
	_check(game.guard_label.text == "GUARD 78", "strike contact refreshes guard health label immediately")
	_check_close(game.momentum, 13.0, "strike contact grants 13 Momentum once")
	_check_close(game.guard_stun, 0.32, "strike contact starts reaction duration")
	_step(game, 0.30)
	_check_close(game.guard_health, 78.0, "strike recovery never repeats damage")
	_check_close(game.momentum, 13.0, "strike recovery never repeats Momentum")

	game.reset_game()
	_place_for_combat(game, 1.48)
	game.strike()
	_step(game, 0.05)
	var remaining_before_mash: float = game.player_strike_timer
	for repeat in range(4):
		game.strike()
	_check_close(game.player_strike_timer, remaining_before_mash, "strike mash does not reset active timer")
	_step(game, game.player_attack_contact - 0.049)
	_check_close(game.guard_health, 78.0, "strike mash still produces one contact")
	for repeat in range(4):
		game.strike()
	_step(game, 0.30)
	_check_close(game.guard_health, 78.0, "strike mash after contact does not repeat damage")
	_check_close(game.momentum, 13.0, "strike mash grants Momentum once")

	game.reset_game()
	_place_for_combat(game, 1.48)
	game.strike()
	_step(game, 0.05)
	game.attack_timer = 0.40
	game.attack_marker.visible = true
	game.counter()
	_check_close(game.player_strike_timer, 0.0, "counter cancels pending strike")
	_check_close(game.guard_health, 70.0, "counter damage replaces cancelled strike contact")
	_check(game.guard_label.text == "GUARD 70", "counter refreshes guard health label immediately")
	_check_close(game.momentum, 28.0, "counter Momentum replaces cancelled strike contact")
	_step(game, 0.20)
	_check_close(game.guard_health, 70.0, "cancelled strike cannot contact after counter")

	game.reset_game()
	_place_for_combat(game, 1.48)
	game.player_root.rotation.y = PI
	game.strike()
	_step(game, 0.05)
	game.evade()
	_check_close(game.player_strike_timer, 0.0, "evade cancels pending strike")
	_step(game, 0.20)
	_check_close(game.guard_health, 100.0, "cancelled strike cannot contact during evade")
	_check_close(game.momentum, 4.0, "cancelled strike leaves only evade Momentum")

	game.reset_game()
	_place_for_combat(game, 1.48)
	game.strike()
	_step(game, 0.10)
	game.reset_game()
	_check_close(game.player_strike_timer, 0.0, "reset cancels pending strike")
	_step(game, 0.20)
	_check_close(game.guard_health, 100.0, "reset strike never reaches stale contact")
	_check_close(game.momentum, 0.0, "reset strike never awards stale Momentum")

	game.reset_game()
	game.momentum = 20.0
	_place_for_combat(game, 1.48)
	game.strike()
	game.guard_root.position = Vector3(4.0, 0.0, 0.0)
	_step(game, game.player_attack_contact + 0.001)
	_check_close(game.guard_health, 100.0, "strike contact rechecks range instead of using stale input range")
	_check_close(game.momentum, 12.0, "out-of-range contact applies one whiff cost")

	game.reset_game()
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(2.25, 0.0, 0.0)
	_face_player_at_guard(game)
	game.strike()
	game.player_root.position = Vector3(1.48, 0.0, 0.0)
	_step(game, game.player_attack_contact + 0.001)
	_check_close(game.guard_health, 78.0, "range-suitable kick retains its input target through contact")
	_check_close(game.momentum, 13.0, "locked mid-range kick grants normal Momentum")

	game.reset_game()
	game.momentum = 20.0
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(2.50, 0.0, 0.0)
	_face_player_at_guard(game)
	game.strike()
	game.player_root.position = Vector3(1.48, 0.0, 0.0)
	_step(game, game.player_attack_contact + 0.001)
	_check_close(game.guard_health, 100.0, "invalid input range cannot acquire a late target")
	_check_close(game.momentum, 12.0, "unlocked late entry resolves as one whiff")

	game.reset_game()
	game.momentum = 20.0
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(1.48, 3.04, 0.0)
	game.player_on_perch = true
	game.strike()
	_step(game, game.player_attack_contact + 0.001)
	_check_close(game.guard_health, 100.0, "strike contact rejects guard on another height")
	_check_close(game.momentum, 20.0, "elevated player cannot begin a grounded strike")


func _test_counters_and_damage(game) -> void:
	game.reset_game()
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(1.48, 0.0, 0.0)
	game.guard_alert = true
	game.attack_cooldown = 0.0
	game.update_guard(0.0)
	_check_close(game.attack_timer, 0.72, "guard opens exact 0.72-second attack window")
	_check(game.attack_marker.visible, "guard attack window exposes marker")
	game.attack_timer = 0.40
	game.counter()
	_check_close(game.guard_health, 70.0, "perfect counter deals 30 damage")
	_check_close(game.momentum, 28.0, "perfect counter grants 28 Momentum")
	_check_close(game.guard_stun, 0.55, "perfect counter reaction duration")
	_check_close(game.player_counter_timer, 0.44, "player counter duration")

	game.reset_game()
	game.attack_timer = 0.20
	game.counter()
	_check_close(game.guard_health, 100.0, "ordinary counter deals no damage")
	_check_close(game.momentum, 8.0, "ordinary counter grants 8 Momentum")
	_check_close(game.guard_stun, 0.25, "ordinary counter reaction duration")

	game.reset_game()
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(1.48, 0.0, 0.0)
	game.momentum = 50.0
	game.attack_timer = 0.01
	game.attack_countered = false
	game.update_guard(0.02)
	_check_close(game.player_health, 82.0, "uncountered attack deals 18 damage")
	_check_close(game.momentum, 25.0, "uncountered attack breaks 25 Momentum")


func _test_defeat_fade_and_restart(game) -> void:
	game.reset_game()
	game.momentum = 10.0
	game.attack_timer = 0.4
	game.attack_marker.visible = true
	game.guard_alert = true
	game.defeat_guard("probe")
	_check(game.guard_defeated and not game.guard_alert, "defeat enters terminal guard state")
	_check_close(game.guard_health, 0.0, "defeat zeros guard health")
	_check_close(game.momentum, 45.0, "defeat grants 35 Momentum")
	_check(not game.vision_mesh.visible and not game.attack_marker.visible, "defeat clears vision and attack marker")

	_step(game, 0.77)
	_check(game.guard_visual_parts["visual_root"].visible, "guard remains visible before fade delay")
	_check_close(_first_geometry_transparency(game.guard_visual_parts["visual_root"]), 0.0, "guard is opaque before fade delay", 0.002)
	_step(game, 0.02)
	var fade_amount := _first_geometry_transparency(game.guard_visual_parts["visual_root"])
	_check(fade_amount > 0.0 and fade_amount < 1.0, "guard fade begins after 0.78 seconds")
	_step(game, 0.66)
	_check(not game.guard_visual_parts["visual_root"].visible and not game.guard_label.visible, "guard visual and label remove at 1.45 seconds")

	game.player_root.position = Vector3(-2.0, 0.0, 0.0)
	game.move_player_world(Vector3.RIGHT, 4.0)
	_check(game.player_root.position.x > 0.5, "defeated guard leaves no invisible blocker")

	game.reset_game()
	_check(not game.guard_defeated and game.guard_visual_parts["visual_root"].visible, "restart restores guard visual")
	_check(game.guard_label.visible and game.vision_mesh.visible, "restart restores guard label and vision")
	_check_close(game.guard_health, 100.0, "restart restores guard health after defeat")


func _test_grapple_perch_fall_and_height(game) -> void:
	game.reset_game()
	game.grapple()
	_check(not game.grapple_active and game.message.contains("OUT OF RANGE"), "grapple rejects reset spawn outside range")
	game.player_root.position = Vector3(3.0, 0.0, -0.7)
	game.grapple()
	_check(game.grapple_active, "grapple activates inside 3.5-unit ring")
	var elapsed := 0.0
	while game.grapple_active and elapsed < 1.0:
		_step(game, FIXED_DELTA)
		elapsed += FIXED_DELTA
	_check_close(elapsed, 0.32, "grapple traversal duration at fixed 60 FPS", 0.04)
	_check_vec3(game.player_root.position, Vector3(6.0, 3.04, -2.4), "grapple exact perch landing", 0.002)
	_check(game.player_on_perch and not game.player_airborne, "grapple lands in real perch state")
	_check_close(game.grapple_recovery_timer, 0.32, "grapple recovery timer begins")

	var perch_start: Vector3 = game.player_root.position
	game.move_player_world(Vector3.RIGHT, 0.5)
	_check(game.player_on_perch and game.player_root.position.x > perch_start.x, "perch movement works during visual recovery")
	game.move_player_world(Vector3.RIGHT, 1.6)
	_check(not game.player_on_perch and game.player_airborne, "crossing perch footprint begins fall")
	var fall_guard := 0
	while game.player_airborne and fall_guard < 180:
		_step(game, FIXED_DELTA)
		fall_guard += 1
	_check(not game.player_airborne and not game.player_on_perch, "fall restores grounded state")
	_check_close(game.player_root.position.y, 0.0, "fall lands on courtyard floor")

	game.reset_game()
	game.player_root.position = Vector3(6.0, 3.04, -2.4)
	game.player_on_perch = true
	game.guard_root.position = Vector3(6.0, 0.0, -2.4)
	game.attack_timer = 0.01
	game.attack_countered = false
	game.update_guard(0.02)
	_check_close(game.player_health, 100.0, "ground guard cannot hit player through perch")
	_check(game.message.contains("empty air"), "perch-height attack is explicitly rejected")


func _test_evade(game) -> void:
	game.reset_game()
	game.guard_root.position = Vector3(-8.0, 0.0, -5.0)
	game.player_root.position = Vector3(-2.0, 0.0, 1.0)
	game.last_travel_direction = Vector3.RIGHT
	game.player_facing_yaw = PI * 0.5
	game.player_root.rotation.y = PI
	var start: Vector3 = game.player_root.position
	game.evade()
	_check_close(game.evade_timer, 0.28, "evade movement duration")
	_check_close(game.invulnerable, 0.42, "evade invulnerability duration")
	_check_close(game.momentum, 4.0, "evade grants 4 Momentum")
	_check_vec3(game.evade_direction, Vector3.FORWARD, "evade snapshots visible yaw instead of stale travel direction", 0.002)
	game.damage_player(18.0, "probe")
	_check_close(game.player_health, 100.0, "evade rejects damage while invulnerable")

	var before_tap: Vector3 = game.player_root.position
	_key_event(game, KEY_D, true)
	_check_vec3(game.player_root.position, before_tap, "movement tap cannot stack displacement during evade")
	var timer_before_repeat: float = game.evade_timer
	game.evade()
	_check_close(game.evade_timer, timer_before_repeat, "evade input cannot reset active movement timer")
	_check_close(game.momentum, 4.0, "evade repeat cannot stack Momentum")
	_step_exact(game, 0.21)
	var mid_spin: float = (game.player_visual_parts["action_root"] as Node3D).rotation.x
	_check(mid_spin > 0.1 and mid_spin < TAU, "evade shows a positive forward spin during travel")
	_step_exact(game, 0.07)
	_check_close(game.flat_distance(start, game.player_root.position), 1.96, "evade integrates exact 0.28s x 7.0m/s travel", 0.002)
	_check_vec3((game.player_root.position - start).normalized(), Vector3.FORWARD, "held movement cannot bend evade direction", 0.002)
	_check_close(game.evade_timer, 0.0, "evade movement ends at 0.28 seconds")
	_check_close(game.invulnerable, 0.14, "evade retains 0.14-second post-travel invulnerability", 0.002)
	var end_of_travel: Vector3 = game.player_root.position
	game.evade()
	_check_close(game.evade_timer, 0.0, "evade cannot retrigger during post-travel invulnerability")
	_check_close(game.momentum, 4.0, "post-travel retrigger cannot stack Momentum")
	_key_event(game, KEY_D, false)
	_step_exact(game, 0.12)
	_check_close((game.player_visual_parts["action_root"] as Node3D).rotation.x, TAU, "evade completes one full forward spin", 0.08)
	_step_exact(game, 0.02)
	_check_close(game.invulnerable, 0.0, "evade invulnerability expires")
	_check_vec3(game.player_root.position, end_of_travel, "released input adds no post-travel displacement")
	game.damage_player(18.0, "probe")
	_check_close(game.player_health, 82.0, "damage resumes after evade")
	game.evade()
	_check_close(game.evade_timer, 0.28, "evade can retrigger only after invulnerability ends")
	_check_close(game.momentum, 4.0, "new evade after recovery grants Momentum once after prior damage broke Momentum")

	game.reset_game()
	game.player_airborne = true
	game.evade()
	_check_close(game.evade_timer, 0.0, "evade rejects airborne state")
	_check_close(game.invulnerable, 0.0, "airborne evade adds no invulnerability")
	game.player_airborne = false
	game.grapple_active = true
	game.evade()
	_check_close(game.evade_timer, 0.0, "evade rejects grapple state")
	_check_close(game.momentum, 0.0, "rejected traversal evades add no Momentum")

	game.reset_game()
	game.guard_root.position = Vector3(-8.0, 0.0, -5.0)
	game.player_root.position = Vector3(8.95, 0.0, 0.0)
	game.player_root.rotation.y = PI * 0.5
	game.evade()
	_step_exact(game, 0.28)
	_check(game.player_root.position.x <= 9.1 + EPSILON, "evade respects courtyard boundary collision")
	_check(game.player_root.position.x >= 8.95, "boundary evade never rebounds through its start")

	game.reset_game()
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(1.48, 0.0, 0.0)
	game.player_root.rotation.y = -PI * 0.5
	game.evade()
	_step_exact(game, 0.28)
	_check(game.flat_distance(game.player_root.position, game.guard_root.position) >= 1.48 - 0.011, "evade preserves guard collision separation")

	game.reset_game()
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(7.8, game.PERCH_TOP_Y, -2.4)
	game.player_on_perch = true
	game.player_root.rotation.y = PI * 0.5
	game.evade()
	_step_exact(game, 0.10)
	_check(game.player_airborne and game.invulnerable > 0.0, "evade can carry off perch into a fall without cancelling invulnerability")
	_check(absf((game.player_visual_parts["action_root"] as Node3D).rotation.x) > 0.1, "forward-roll pose remains visible after evade leaves perch")


func _test_crouch_and_clearance(game) -> void:
	game.reset_game()
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	var standing_start: Vector3 = game.player_root.position
	_hold_movement(game, KEY_D, 0.50)
	var standing_distance: float = game.flat_distance(standing_start, game.player_root.position)
	game.reset_game()
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.toggle_crouch()
	var crouch_start: Vector3 = game.player_root.position
	_hold_movement(game, KEY_D, 0.50)
	var crouch_distance: float = game.flat_distance(crouch_start, game.player_root.position)
	_check(game.crouching, "crouch toggles on")
	_check_close(standing_distance / 0.50, game.PLAYER_MOVE_SPEED, "standing WASD uses the single run speed", 0.01)
	_check_close(crouch_distance / 0.50, game.CROUCH_MOVE_SPEED, "crouch preserves its prior absolute travel speed", 0.01)
	_check_close(crouch_distance / standing_distance, game.CROUCH_MOVE_SPEED / game.PLAYER_MOVE_SPEED, "crouch ratio reflects preserved absolute speed", 0.002)

	game.reset_game()
	game.player_root.position = Vector3(-6.9, 0.0, 3.8)
	var passage_edge: Vector3 = game.player_root.position
	game.move_player_world(Vector3.LEFT, 0.25)
	_check_vec3(game.player_root.position, passage_edge, "standing entry is blocked by 2.0-unit passage")
	game.toggle_crouch()
	game.move_player_world(Vector3.LEFT, 0.25)
	_check(game.is_in_low_passage(game.player_root.position), "crouched player enters low passage")
	game.toggle_crouch()
	_check(game.crouching, "standing is rejected under lintel")
	game.evade()
	_check_close(game.evade_timer, 0.0, "evade is rejected under lintel")
	game.strike()
	_check_close(game.player_strike_timer, 0.0, "strike is rejected under lintel")
	game.move_player_world(Vector3.RIGHT, 0.35)
	_check(not game.is_in_low_passage(game.player_root.position), "crouched player clears passage")
	game.toggle_crouch()
	_check(not game.crouching, "full height returns after clearing passage")


func _test_jump_and_vault(game) -> void:
	_jump_test_reset(game)
	var start: Vector3 = game.player_root.position
	game.jump_or_vault()
	_check(game.jump_active and not game.jump_is_vault and not game.jump_moving, "stationary input selects standing jump")
	_check(not game.player_airborne, "jump starts with actual grounded preparation")
	_check_close(game.jump_duration, 0.94, "jump includes preparation, flight and landing recovery")
	_step(game, 0.10)
	_check_vec3(game.player_root.position, start, "prepare keeps gameplay root on floor")
	_check(game.player_visual_parts["left_knee"].rotation.x > 0.30, "prepare visibly flexes the knees before takeoff")
	game.evade()
	game.strike()
	game.toggle_crouch()
	game.grapple()
	_check(game.invulnerable == 0.0 and game.player_strike_timer == 0.0 and not game.crouching and not game.grapple_active, "grounded preparation reserves the jump action")
	_step(game, 0.33)
	_check_close(game.player_root.position.y, 1.35, "standing flight reaches the existing 1.35-unit apex", 0.002)
	_check(game.player_airborne, "airborne flag begins after preparation")
	_check(game.player_visual_parts["left_knee"].rotation.x < 0.25, "standing jump extends legs at apex")
	game.damage_player(18.0, "probe")
	_check_close(game.player_health, 82.0, "jump does not add invulnerability")
	_step(game, 0.311)
	_check(not game.player_airborne and game.jump_active, "touchdown is grounded during impact recovery")
	_check_vec3(game.player_root.position, start, "unsteered jump lands at its takeoff point")
	_step(game, 0.055)
	_check(game.player_visual_parts["left_knee"].rotation.x > 0.30, "impact flexes the knees after touchdown")
	_step(game, 0.145)
	_check(not game.jump_active and not game.player_airborne, "jump returns to grounded controls")

	_jump_test_reset(game)
	game.player_root.position = Vector3(4.55, 0.0, 3.9)
	var barrier_start: Vector3 = game.player_root.position
	game.move_player_world(Vector3.RIGHT, 0.20)
	_check_vec3(game.player_root.position, barrier_start, "walking stays blocked by low barrier")
	game.player_root.position = Vector3(3.8, 0.0, 3.9)
	game.last_travel_direction = Vector3.RIGHT
	game.jump_or_vault()
	_check(game.jump_active and game.jump_is_vault and game.player_airborne, "contextual path selects existing vault")
	_check_close(game.jump_duration, 0.48, "vault duration unchanged")
	_key_event(game, KEY_A, true)
	_step(game, 0.24)
	_check_close(game.player_root.position.y, 1.05, "vault midpoint apex unchanged", 0.002)
	_step(game, 0.24)
	_check(not game.jump_active and not game.player_airborne, "vault lands grounded")
	_check_close(game.player_root.position.x, 6.0, "held input cannot redirect committed 2.2-unit vault")

	_jump_test_reset(game)
	game.player_root.position = Vector3(-8.0, 0.0, 3.8)
	game.crouching = true
	game.jump_or_vault()
	_check(not game.jump_active and game.crouching, "jump rejects low-passage bypass")
	_test_jump_air_control(game)


func _jump_test_reset(game) -> void:
	game.reset_game()
	game.player_root.position = Vector3(-3.0, 0.0, 0.0)
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.camera_yaw = 0.0
	game.update_camera(0.0)


func _finish_jump(game, hz: int) -> void:
	var steps := 0
	while game.jump_active and steps < hz * 2:
		_step(game, 1.0 / float(hz))
		steps += 1
	_check(not game.jump_active, "jump completes at %s Hz" % hz)


func _test_jump_air_control(game) -> void:
	for hz in [30, 60]:
		for yaw in [0.0, PI / 2.0]:
			for keys in [[KEY_D], [KEY_D, KEY_W], [KEY_A], [KEY_S]]:
				_jump_test_reset(game)
				game.camera_yaw = yaw
				game.update_camera(0.0)
				var start: Vector3 = game.player_root.position
				game.jump_or_vault()
				for key in keys: _key_event(game, key, true)
				var input: Vector2 = game.get_move_input()
				var direction: Vector3 = game.camera.global_transform.basis.x * input.x - game.camera.global_transform.basis.z * input.y
				direction.y = 0.0
				_finish_jump(game, hz)
				_check_vec3(game.player_root.position, start + direction.normalized() * 0.868,
					"standing jump air control normalized at keys=%s yaw=%.2f Hz=%s" % [keys, yaw, hz], 0.002)

				_jump_test_reset(game)
				game.camera_yaw = yaw
				game.update_camera(0.0)
				for key in keys: _key_event(game, key, true)
				_step(game, 0.10)
				start = game.player_root.position
				game.jump_or_vault()
				_check(game.jump_moving, "actual held movement selects a moving jump")
				_step(game, 0.15)
				game.held_keys.clear()
				_finish_jump(game, hz)
				_check_vec3(game.player_root.position, start + direction.normalized() * 2.2,
					"moving jump carries takeoff direction after release at keys=%s yaw=%.2f Hz=%s" % [keys, yaw, hz], 0.002)

	_jump_test_reset(game)
	game.jump_or_vault()
	_step(game, 0.22)
	var stationary_x: float = game.player_root.position.x
	_press_and_release(game, KEY_D)
	_step(game, 0.05)
	_check_close(game.player_root.position.x, stationary_x, "zero-duration airborne tap gives no travel")
	_key_event(game, KEY_D, true)
	_step(game, 0.15)
	_key_event(game, KEY_D, false)
	var released_x: float = game.player_root.position.x
	_check_close(released_x - stationary_x, 0.21, "midair input begins gentle steering")
	_step(game, 0.10)
	_check_close(game.player_root.position.x, released_x, "release stops standing-jump air adjustment")
	_key_event(game, KEY_A, true)
	_step(game, 0.10)
	_check_close(game.player_root.position.x, released_x - 0.14, "opposing air input reverses adjustment")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_x: float = game.player_root.position.x
	_finish_jump(game, 60)
	_check_close(game.player_root.position.x, focus_x, "focus loss clears air steering")

	_jump_test_reset(game)
	var leads: Array[float] = []
	var thigh_differences: Array[float] = []
	for repeat in 2:
		_key_event(game, KEY_D, true)
		_step(game, 0.10)
		var start: Vector3 = game.player_root.position
		game.jump_or_vault()
		leads.append(game.jump_lead)
		_step(game, 0.43)
		thigh_differences.append(game.player_visual_parts["left_leg"].rotation.x - game.player_visual_parts["right_leg"].rotation.x)
		game.jump_or_vault()
		_check_close(game.jump_lead, leads[-1], "rejected midair jump does not change leading leg")
		_finish_jump(game, 60)
		_check_close(game.flat_distance(start, game.player_root.position), 2.2, "holding launch direction does not stack extra forward speed")
	_check_close(leads[0], -leads[1], "successive jumps alternate their leading leg")
	_check(thigh_differences[0] * thigh_differences[1] < -0.20, "moving jumps visibly mirror the split-leg pose")
	game.reset_game()
	_check_close(game.jump_lead, -1.0, "restart resets deterministic jump variation")

	for obstacle in ["lintel", "barrier", "boundary"]:
		_jump_test_reset(game)
		game.last_travel_direction = Vector3.FORWARD
		if obstacle == "lintel": game.player_root.position = Vector3(-6.95, 0.0, 3.8)
		elif obstacle == "barrier": game.player_root.position = Vector3(4.55, 0.0, 3.9)
		else: game.player_root.position = Vector3(9.0, 0.0, 0.0)
		game.jump_or_vault()
		_step(game, 0.43)
		_key_event(game, KEY_A if obstacle == "lintel" else KEY_D, true)
		_finish_jump(game, 60)
		var landed: Vector3 = game.player_root.position
		_check(not game.is_in_low_passage(landed) and not game.is_inside_vault_obstacle(landed), "safe landing footprint at " + obstacle)
		_check(landed.x <= 9.101 and landed.x >= -9.101, "air steering respects courtyard bounds")
	_jump_test_reset(game)
	game.player_root.position = Vector3(4.55, 0.0, 3.9)
	game.last_travel_direction = Vector3.FORWARD
	game.jump_or_vault()
	_key_event(game, KEY_D, true)
	_step(game, 0.94)
	_check_close(game.player_root.position.x, 4.55, "long air frame cannot skip the vault wall")


func _test_takedown_action_timing(game) -> void:
	game.reset_game()
	game.guard_root.position = Vector3(-4.6, 0.0, 0.2)
	game.player_root.position = Vector3(-2.6, 0.0, 0.2)
	game.guard_forward = Vector3.LEFT
	game.guard_alert = true
	game.attack_cooldown = 0.0
	_check(game.is_concealed(), "takedown action begins from ambush concealment")
	var player_start: Vector3 = game.player_root.position
	var guard_start: Vector3 = game.guard_root.position
	var approach_direction := (guard_start - player_start).normalized()
	game.stealth_takedown()
	_check_close(game.player_takedown_timer, 1.10, "takedown starts exact 1.10-second action")
	_check(not game.guard_defeated, "takedown does not defeat on input")
	_check_close(game.momentum, 0.0, "takedown does not award Momentum on input")
	var timer_before_mash: float = game.player_takedown_timer
	for index in range(4):
		game.stealth_takedown()
	_check_close(game.player_takedown_timer, timer_before_mash, "takedown mash cannot restart its action timer")
	_check(not game.guard_defeated, "takedown mash cannot force early contact")
	_check_close(game.momentum, 0.0, "takedown mash cannot stack Momentum")
	game.strike()
	game.evade()
	game.jump_or_vault()
	game.grapple()
	_check_close(game.player_strike_timer, 0.0, "strike is blocked during takedown")
	_check_close(game.evade_timer, 0.0, "evade is blocked during takedown")
	_check(not game.jump_active and not game.grapple_active, "traversal actions are blocked during takedown")

	var before_tap: Vector3 = game.player_root.position
	_key_event(game, KEY_D, true)
	_check_vec3(game.player_root.position, before_tap, "movement tap is blocked during takedown")
	_step(game, 0.20)
	_check_vec3(game.guard_root.position, guard_start, "reserved takedown guard does not run AI")
	_check_close(game.attack_timer, 0.0, "reserved takedown guard cannot open attack")
	_check(not game.guard_defeated, "takedown remains pending at 0.20 seconds")
	_step(game, 0.139)
	_check(not game.guard_defeated, "takedown remains pending before 0.34-second contact")
	_step(game, 0.002)
	_check(game.guard_defeated, "takedown defeats once at 0.34-second contact")
	_check_close(game.guard_health, 0.0, "takedown contact zeros guard health")
	_check_close(game.momentum, 35.0, "takedown contact grants 35 Momentum once")
	var approach_motion: Vector3 = game.player_root.position - player_start
	approach_motion.y = 0.0
	_check(approach_motion.length() <= 0.62 + 0.002, "takedown auto-approach is capped at 0.62 metres")
	_check(approach_motion.dot(approach_direction) >= -EPSILON, "takedown auto-approach never moves away from guard")
	_check(approach_motion.slide(approach_direction).length() <= 0.002, "held movement cannot add lateral takedown displacement")
	var after_contact_health: float = game.guard_health
	var after_contact_momentum: float = game.momentum
	_step(game, 0.40)
	_check_close(game.guard_health, after_contact_health, "takedown recovery never repeats guard contact")
	_check_close(game.momentum, after_contact_momentum, "takedown recovery never repeats Momentum")
	_check(game.player_takedown_timer > 0.0, "takedown presentation continues after contact")
	_key_event(game, KEY_D, false)
	_step(game, 0.40)
	_check_close(game.player_takedown_timer, 0.0, "takedown action ends after 1.10 seconds")

	game.reset_game()
	game.guard_root.position = Vector3(-4.6, 0.0, 0.2)
	game.player_root.position = Vector3(-3.0, 0.0, 0.2)
	game.guard_forward = Vector3.LEFT
	game.stealth_takedown()
	_step(game, 0.20)
	game.reset_game()
	_check_close(game.player_takedown_timer, 0.0, "reset cancels pending takedown")
	_step(game, 0.20)
	_check(not game.guard_defeated, "reset prevents stale takedown contact")
	_check_close(game.guard_health, 100.0, "reset restores guard before stale contact")
	_check_close(game.momentum, 0.0, "reset prevents stale takedown Momentum")

	game.reset_game()
	game.player_root.position = Vector3(-1.0, 0.0, 0.0)
	game.guard_root.position = Vector3.ZERO
	game.guard_forward = Vector3.RIGHT
	game.stealth_takedown()
	_check_close(game.player_takedown_timer, 0.0, "non-concealed takedown never reserves action")

	game.reset_game()
	game.player_root.position = game.HIDE_POSITION
	game.guard_root.position = game.HIDE_POSITION + Vector3(0.0, 0.0, 2.2)
	game.guard_forward = Vector3.BACK
	game.stealth_takedown()
	_check_close(game.player_takedown_timer, 0.0, "out-of-range takedown never starts")

	game.reset_game()
	game.guard_root.position = Vector3(-4.6, 1.0, 0.2)
	game.player_root.position = Vector3(-3.6, 0.0, 0.2)
	game.guard_forward = Vector3.LEFT
	_check(game.is_concealed(), "height-rejection takedown remains concealed and in flat range")
	game.stealth_takedown()
	_check_close(game.player_takedown_timer, 0.0, "different-height takedown never starts")
	_check(not game.guard_defeated, "height rejection leaves guard active")

	game.reset_game()
	game.player_root.position = Vector3(-8.0, 0.0, 3.8)
	game.crouching = true
	game.guard_root.position = Vector3(-7.0, 0.0, 3.8)
	game.guard_forward = Vector3.RIGHT
	_check(game.is_concealed() and game.is_in_low_passage(game.player_root.position), "low-passage takedown fixture meets concealment and range prerequisites")
	game.stealth_takedown()
	_check_close(game.player_takedown_timer, 0.0, "takedown is rejected under lintel")
	_check(not game.guard_defeated, "low-passage takedown rejection leaves guard active")


func _test_stealth_exit_and_restart(game) -> void:
	game.reset_game()
	game.player_root.position = Vector3(-1.0, 0.0, 0.0)
	game.guard_root.position = Vector3.ZERO
	game.guard_forward = Vector3.RIGHT
	game.stealth_takedown()
	_check(not game.guard_defeated and game.player_takedown_timer <= 0.0, "behind but non-concealed takedown fails")

	game.reset_game()
	game.player_root.position = Vector3(-3.6, 0.0, 0.2)
	game.guard_root.position = Vector3(-4.6, 0.0, 0.2)
	game.guard_forward = Vector3.RIGHT
	_check(game.is_concealed(), "ambush shadow provides concealment")
	game.stealth_takedown()
	_check(not game.guard_defeated and game.player_takedown_timer <= 0.0, "concealed but frontal takedown fails")

	game.reset_game()
	game.player_root.position = game.HIDE_POSITION
	_check(game.is_concealed(), "original darkness remains valid concealment")

	game.reset_game()
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	_hold_movement(game, KEY_D, 0.615)
	_check(game.is_concealed(), "default-camera held D reaches ambush shadow")
	game.guard_root.position = game.PATROL_POINTS[0]
	var to_player: Vector3 = game.player_root.position - game.guard_root.position
	to_player.y = 0.0
	game.guard_forward = -to_player.normalized()
	_check(game.flat_distance(game.player_root.position, game.guard_root.position) < 2.1, "default stealth route reaches takedown range")
	game.stealth_takedown()
	_check(not game.guard_defeated and game.player_takedown_timer > 0.0, "concealed behind takedown begins authored action")
	_step(game, 0.341)
	_check(game.guard_defeated, "concealed behind takedown contacts when warden exposes back")
	_check_close(game.momentum, 35.0, "silent takedown grants 35 Momentum")

	game.player_root.position = game.EXIT_POSITION
	game.check_success()
	_check(game.success and game.objective_label.text == "COURTYARD CLEAR", "defeated guard unlocks exit success")

	game.reset_game()
	_check(not game.success and not game.guard_defeated, "final restart clears success and defeat")
	_check_close(game.player_health, 100.0, "final restart restores health")
	_check_close(game.momentum, 0.0, "final restart clears Momentum")
	_check_close(game.guard_health, 100.0, "final restart restores guard health")
	_check_vec3(game.player_root.position, Vector3(-6.0, 0.0, 2.5), "final restart restores player spawn")
	_check_vec3(game.guard_root.position, Vector3.ZERO, "final restart restores guard spawn")
	_check_close(game.camera_yaw, 0.69, "final restart restores camera yaw")
	_check_close(game.camera_pitch, 0.47, "final restart restores camera pitch")
	_check_close(game.camera.size, 18.5, "final restart restores orthographic size")
	_check(game.objective_label.text == "OBJECTIVE: guard and exit", "final restart restores objective")


func _step(game, delta: float) -> void:
	game._process(delta)


func _step_exact(game, duration: float) -> void:
	var remaining := duration
	while remaining > 0.0000001:
		var delta := minf(FIXED_DELTA, remaining)
		game._process(delta)
		remaining -= delta


func _step_fixed_seconds(game, duration: float) -> void:
	var frames := ceili(duration / FIXED_DELTA)
	for frame in range(frames):
		game._process(FIXED_DELTA)


func _place_for_combat(game, distance: float) -> void:
	game.guard_root.position = Vector3.ZERO
	game.player_root.position = Vector3(distance, 0.0, 0.0)
	_face_player_at_guard(game)
	game.guard_alert = false
	game.attack_cooldown = 2.0


func _face_player_at_guard(game) -> void:
	var to_guard: Vector3 = game.guard_root.position - game.player_root.position
	to_guard.y = 0.0
	game.player_facing_yaw = atan2(to_guard.x, to_guard.z)
	game.player_root.rotation.y = game.player_facing_yaw


func _key_event(game, keycode: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	game._unhandled_input(event)


func _press_and_release(game, keycode: Key) -> void:
	_key_event(game, keycode, true)
	_key_event(game, keycode, false)


func _hold_movement(game, keycode: Key, duration: float) -> void:
	_key_event(game, keycode, true)
	_step_exact(game, duration)
	_key_event(game, keycode, false)


func _first_geometry_transparency(node: Node) -> float:
	var geometries := node.find_children("*", "GeometryInstance3D", true, false)
	if geometries.is_empty():
		return -1.0
	return (geometries[0] as GeometryInstance3D).transparency


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
	if failures.is_empty():
		print("GLOAM_VIGIL_MECHANICS_PROBE_OK checks=", checks)
		quit(0)
		return
	print("GLOAM_VIGIL_MECHANICS_PROBE_FAILED checks=", checks, " failures=", failures.size())
	for failure in failures:
		print("FAILED_CHECK ", failure)
	quit(1)
