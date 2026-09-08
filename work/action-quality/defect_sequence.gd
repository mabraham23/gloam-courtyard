extends SceneTree

## Short normal-renderer review for the three defects found in the full reel:
## jump silhouette, grapple lip clearance, and coherent downed support.
## State setup is disclosed and this is not native-input evidence.
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

var game: Node3D
var frame := 0
var started := false
var label: Label


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
	label.position = Vector2(220, 515)
	label.size = Vector2(520, 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_quiet_guard()
	_begin_jump()
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	match frame:
		55:
			_begin_grapple()
		110:
			_begin_downed()
		170:
			game.reset_game()
			_quiet_guard()
	game._process(1.0 / 30.0)
	_update_camera()
	label.text = _segment_name() + "\nFocused helper setup — inspect silhouette and world contact"
	if frame % 5 == 0:
		print("ACTION_QUALITY_DEFECT_FRAME frame=", frame, " segment=", _segment_name(), " player=", game.player_root.position)
	frame += 1
	return false


func _begin_jump() -> void:
	game.reset_game()
	_quiet_guard()
	game.player_root.position = Vector3(-4.0, 0.0, -2.7)
	game.last_travel_direction = Vector3.RIGHT
	game.player_facing_yaw = PI / 2.0
	game.player_root.rotation.y = PI / 2.0
	game.jump_or_vault()


func _begin_grapple() -> void:
	game.reset_game()
	_quiet_guard()
	game.player_root.position = Vector3(2.0, 0.0, -0.7)
	game.grapple()


func _begin_downed() -> void:
	game.reset_game()
	_quiet_guard()
	game.player_root.position = Vector3(-3.0, 0.0, -2.7)
	game.damage_player(100.0, "DOWNED: whole-body support review.")


func _quiet_guard() -> void:
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0


func _update_camera() -> void:
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.15, 0.0)
	game.camera.position = focus + Vector3(4.6, 2.8, 7.2)
	game.camera.look_at(focus)
	game.camera.size = 6.4


func _segment_name() -> String:
	if frame < 55:
		return "FREE JUMP — TAKEOFF / FLIGHT / LANDING"
	if frame < 110:
		return "GRAPPLE — CLEAR OF PERCH LIP / EXACT LANDING"
	if frame < 170:
		return "DOWNED — CONNECTED SIDE FALL / FLOOR SUPPORT"
	return "RESTART — STANDING RECOVERY"
