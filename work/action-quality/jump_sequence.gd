extends SceneTree

## Matched fixed-step jump review. Real controller, scripted V/held input,
## guard moved away, static review camera. This is not native input evidence.
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const TOTAL_FRAMES := 240
const DELTA := 1.0 / 30.0
var game: Node3D
var label: Label
var frame := 0
var started := false
var gameplay_view := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	gameplay_view = "--gameplay" in OS.get_cmdline_user_args()
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[0])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	label = Label.new()
	label.position = Vector2(130, 470)
	label.size = Vector2(700, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_reset()
	started = true

func _process(_delta: float) -> bool:
	if not started: return false
	match frame:
		15, 55: _jump()
		95:
			_reset()
			_jump()
		100: game.held_keys[KEY_D] = true
		109: game.held_keys.clear()
		135:
			_reset()
			game.player_root.position = Vector3(3.8, 0.0, 3.9)
			game.last_travel_direction = Vector3.RIGHT
			game.player_facing_yaw = PI / 2.0
			game.player_root.rotation.y = PI / 2.0
		145: _jump()
		180:
			_reset()
			game.held_keys[KEY_D] = true
		187: _jump()
		194: game.held_keys.clear()
	game.camera_yaw = 0.0
	game.update_camera(0.0)
	game._process(DELTA)
	if gameplay_view:
		game.reset_camera()
	else:
		var focus := Vector3(4.8, 1.3, 3.9) if frame >= 135 and frame < 180 else Vector3(-2.8, 1.3, 0.0)
		game.camera.position = focus + Vector3(5.8, 2.5, 6.7)
		game.camera.look_at(focus)
		game.camera.size = 6.7
	label.text = _segment() + "\nV jump · hold WASD in air · release to stop steering"
	print("JUMP_FRAME frame=", frame, " position=", game.player_root.position, " phase=", game.jump_t, " vault=", game.jump_is_vault)
	frame += 1
	if frame >= TOTAL_FRAMES:
		print("JUMP_SEQUENCE_OK frames=", TOTAL_FRAMES)
		quit()
	return false

func _jump() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_V
	event.pressed = true
	game._unhandled_input(event)
	event.pressed = false
	game._unhandled_input(event)

func _reset() -> void:
	game.reset_game()
	game.player_root.position = Vector3(-4.0, 0.0, 0.0)
	game.last_travel_direction = Vector3.RIGHT
	game.player_facing_yaw = PI / 2.0
	game.player_root.rotation.y = PI / 2.0
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_visual_parts["visual_root"].visible = false
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false

func _segment() -> String:
	if frame < 55: return "FIRST JUMP · NO DIRECTION"
	if frame < 95: return "SECOND JUMP · NO DIRECTION"
	if frame < 135: return "JUMP · PRESS D IN AIR, THEN RELEASE"
	if frame < 180: return "CONTEXTUAL BARRIER VAULT"
	return "RUN INTO JUMP · RELEASE D IN AIR"
