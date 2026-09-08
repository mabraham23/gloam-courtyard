extends SceneTree

## Normal-render evidence for target-independent SPACE actions. The reel uses
## the real controller in empty space, queues exactly one late whiff follow-up,
## and then strikes after the guard is defeated. It never owns a target and
## asserts that no phantom damage is applied.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const SEGMENT_FRAMES := 60
const TOTAL_FRAMES := SEGMENT_FRAMES * 3
const DELTA := 1.0 / 30.0

var game: Node3D
var label: Label
var frame := 0
var started := false
var action_count := 0
var first_variant: StringName = &""
var second_variant: StringName = &""
var root_start := Vector3.ZERO


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	label = Label.new()
	label.position = Vector2(120, 500)
	label.size = Vector2(720, 72)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_setup_segment(0)
	print("R14_TARGET_FREE_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	var segment := frame / SEGMENT_FRAMES
	var local_frame := frame % SEGMENT_FRAMES
	if local_frame == 0 and frame > 0:
		_assert_segment(segment - 1)
		_setup_segment(segment)
	if local_frame == 5:
		_start_strike()
	# Exercise the real one-slot late buffer without resetting the live timer.
	if segment == 1 and action_count == 1 and game.player_strike_timer > 0.0 \
		and game.player_strike_timer <= 0.085 and not game.player_attack_buffered:
		game.strike()
		assert(game.player_attack_buffered)

	game._process(DELTA)
	if segment == 1 and action_count == 1 and game.player_strike_timer > 0.12 \
		and first_variant != &"" and game.player_attack_variant != first_variant:
		action_count = 2
		second_variant = game.player_attack_variant
	_update_camera()
	label.text = _label_text(segment, local_frame)
	if frame % 5 == 0:
		print("R14_TARGET_FREE_FRAME frame=", frame,
			" segment=", segment, " variant=", game.player_attack_variant,
			" timer=", snappedf(game.player_strike_timer, 0.001),
			" target_locked=", game.player_attack_target_locked,
			" guard_hp=", game.guard_health, " momentum=", game.momentum)
	frame += 1
	if frame >= TOTAL_FRAMES:
		_assert_segment(2)
		print("R14_TARGET_FREE_SEQUENCE_OK frames=", TOTAL_FRAMES, " segments=3")
		quit()
	return false


func _setup_segment(segment: int) -> void:
	game.held_keys.clear()
	game.reset_game()
	game.player_root.position = Vector3(-1.1, 0.0, 0.0)
	game.player_root.rotation.y = PI / 2.0
	game.player_facing_yaw = PI / 2.0
	game.guard_root.position = Vector3(8.0, 0.0, -5.0)
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0
	game.player_attack_rng.seed = 94100 + segment
	game.momentum = 30.0 if segment == 1 else 0.0
	game.guard_visual_parts["visual_root"].visible = false
	game.guard_label.visible = false
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false
	if segment == 2:
		game.guard_root.position = Vector3(0.55, 0.0, 0.0)
		game.defeat_guard("Guard down; target-free presentation remains available.")
		game.guard_label.visible = false
	root_start = game.player_root.position
	action_count = 0
	first_variant = &""
	second_variant = &""


func _start_strike() -> void:
	game.strike()
	assert(game.player_strike_timer > 0.0)
	assert(not game.player_attack_target_locked)
	action_count = 1
	first_variant = game.player_attack_variant


func _assert_segment(segment: int) -> void:
	assert(action_count >= 1, "Target-free review segment never started")
	assert(not game.player_attack_target_locked)
	assert(not game.player_attack_contact_connected)
	assert(game.player_root.position.is_equal_approx(root_start))
	if segment < 2:
		assert(is_equal_approx(game.guard_health, 100.0), "Target-free action applied phantom damage")
	else:
		assert(is_equal_approx(game.guard_health, 0.0), "Post-defeat action changed defeated guard health")
	if segment == 1:
		assert(action_count == 2, "Late buffer did not start exactly one follow-up")
		assert(second_variant != &"" and second_variant != first_variant,
			"Target-free follow-up did not visibly change variant")


func _update_camera() -> void:
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.05, 0.0)
	game.camera.position = focus + Vector3(0.5, 1.85, 5.8)
	game.camera.look_at(focus)
	game.camera.size = 4.15


func _label_text(segment: int, local_frame: int) -> String:
	var name := "EMPTY SPACE · ONE TARGET-FREE ACTION"
	if segment == 1:
		name = "EMPTY SPACE · ONE-SLOT WHIFF FOLLOW-UP"
	elif segment == 2:
		name = "AFTER GUARD DEFEAT · ACTION STILL AVAILABLE"
	var state := "READY"
	if game.player_strike_timer > 0.0:
		state = "%s · %.2f s remaining" % [game.player_attack_variant, game.player_strike_timer]
	elif local_frame > 5:
		state = "RECOVERED · NO TARGET / NO PHANTOM DAMAGE"
	return "%s\n%s" % [name, state]
