extends SceneTree

## Deterministic visual-review reel for the complete controller presentation.
## Positions and state setup are disclosed test helpers; this is not ordinary-
## input reachability evidence. All actions still advance through main_3d.gd.
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

var game: Node3D
var frame := 0
var started := false
var segment_label: Label


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
	segment_label = Label.new()
	segment_label.position = Vector2(245, 510)
	segment_label.size = Vector2(470, 72)
	segment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	segment_label.add_theme_font_size_override("font_size", 17)
	root.add_child(segment_label)
	_quiet_guard()
	print("ACTION_QUALITY_FULL_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	match frame:
		45:
			game.held_keys[KEY_D] = true
		105:
			game.held_keys.erase(KEY_D)
		135:
			game.held_keys[KEY_A] = true
		180:
			game.held_keys.erase(KEY_A)
		195:
			game.toggle_crouch()
			game.held_keys[KEY_D] = true
		235:
			game.held_keys.erase(KEY_D)
		245:
			game.toggle_crouch()
		255:
			_reset_segment()
			game.last_travel_direction = Vector3(0.0, 0.0, -1.0)
			game.player_facing_yaw = PI
			game.player_root.rotation.y = PI
			game.jump_or_vault()
		300:
			_reset_segment()
			game.player_root.position = Vector3(3.75, 0.0, 3.9)
			game.last_travel_direction = Vector3.RIGHT
			game.player_facing_yaw = PI / 2.0
			game.player_root.rotation.y = PI / 2.0
			game.jump_or_vault()
		345:
			_reset_segment()
			game.player_root.position = Vector3(2.0, 0.0, -0.7)
			game.grapple()
		405:
			_reset_segment()
			game.player_root.position = Vector3(6.0, game.PERCH_TOP_Y, -2.4)
			game.player_on_perch = true
			game.player_airborne = false
			game.move_player_world(Vector3.RIGHT, 2.8)
		465:
			_reset_segment()
			game.player_root.position = Vector3(-3.0, 0.0, -2.7)
			game.player_facing_yaw = PI / 2.0
			game.player_root.rotation.y = PI / 2.0
			game.evade()
		510:
			_reset_segment()
			game.player_root.position = Vector3(-1.65, 0.0, 0.0)
			game.guard_root.position = Vector3(0.0, 0.0, 0.0)
			game.strike()
		555:
			_reset_segment()
			game.player_root.position = Vector3(-1.65, 0.0, 0.0)
			game.guard_root.position = Vector3(0.0, 0.0, 0.0)
			game.attack_timer = 0.45
			game.attack_marker.visible = true
			game.counter()
		600:
			_reset_segment()
			game.player_root.position = Vector3(-3.0, 0.0, -2.7)
			game.momentum = 50.0
			game.damage_player(18.0, "HURT: non-displacing recoil and recovery.")
		645:
			_reset_segment()
			game.player_root.position = Vector3(-3.0, 0.0, -2.7)
			game.damage_player(100.0, "DOWNED: stable terminal pose.")
		690:
			game.reset_game()
			_quiet_guard()
		705:
			_reset_segment()
			game.player_root.position = Vector3(-3.65, 0.0, 0.2)
			game.guard_root.position = Vector3(-2.15, 0.0, 0.2)
			game.guard_forward = Vector3.RIGHT
			game.guard_root.rotation.y = PI / 2.0
			game.player_facing_yaw = PI / 2.0
			game.player_root.rotation.y = PI / 2.0
			game.stealth_takedown()

	game._process(1.0 / 30.0)
	_update_review_camera()
	segment_label.text = _segment_name(frame) + "\nDeterministic helper setup — actual controller timing and state updates"
	if frame % 15 == 0:
		print(
			"ACTION_QUALITY_FRAME frame=", frame,
			" segment=", _segment_name(frame),
			" player=", game.player_root.position,
			" hp=", game.player_health,
			" guard=", game.guard_health,
			" momentum=", game.momentum
		)
	frame += 1
	return false


func _reset_segment() -> void:
	game.held_keys.clear()
	game.reset_game()
	_quiet_guard()


func _quiet_guard() -> void:
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0


func _update_review_camera() -> void:
	if "--courtyard" in OS.get_cmdline_user_args():
		return
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.15, 0.0)
	if (frame >= 510 and frame < 600) or frame >= 705:
		focus = (game.player_root.position + game.guard_root.position) * 0.5 + Vector3(0.0, 1.1, 0.0)
	game.camera.position = focus + Vector3(0.0, 3.8, 9.0)
	game.camera.look_at(focus)
	game.camera.size = 7.2


func _segment_name(value: int) -> String:
	if value < 45: return "IDLE / BREATHING"
	if value < 105: return "LOCOMOTION / START + WALK"
	if value < 135: return "LOCOMOTION / STOP"
	if value < 195: return "LOCOMOTION / REVERSAL"
	if value < 255: return "CROUCH / ENTER + MOVE + EXIT"
	if value < 300: return "JUMP / TAKEOFF + LANDING"
	if value < 345: return "CONTEXTUAL VAULT"
	if value < 405: return "GRAPPLE / RECOVERY"
	if value < 465: return "PERCH FALL / LANDING"
	if value < 510: return "FORWARD EVADE / FACING-DIRECTION TRAVEL"
	if value < 555: return "STRIKE / CONTACT + RECOVERY"
	if value < 600: return "COUNTER / RECOVERY"
	if value < 645: return "HURT / RECOVERY"
	if value < 705: return "DOWNED / RESTART"
	return "PAIRED STEALTH TAKEDOWN"
