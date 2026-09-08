extends SceneTree

## Close normal-renderer reel for the native-rejected R7 motion pass. It uses
## actual controller state/timing and a disclosed deterministic setup. Pass
## --slow-motion to advance gameplay at half speed for transition inspection.
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

var game: Node3D
var label: Label
var frame := 0
var scale_frames := 1
var step_delta := 1.0 / 30.0
var started := false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	scale_frames = 2 if "--slow-motion" in OS.get_cmdline_user_args() else 1
	step_delta = 1.0 / 60.0 if scale_frames == 2 else 1.0 / 30.0
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	label = Label.new()
	label.position = Vector2(205, 520)
	label.size = Vector2(550, 58)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_reset_segment(Vector3(-4.5, 0.0, -2.5))
	game.held_keys[KEY_D] = true
	print("NATURAL_MOTION_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH), " slow=", scale_frames == 2)
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	var beat := frame / scale_frames
	if frame % scale_frames == 0:
		match beat:
			60:
				game.held_keys.erase(KEY_D)
			75:
				_reset_segment(Vector3(-4.5, 0.0, -2.5))
				game.toggle_crouch()
				game.held_keys[KEY_D] = true
			120:
				game.held_keys.erase(KEY_D)
			130:
				game.toggle_crouch()
			135:
				_reset_segment(Vector3(-4.0, 0.0, -2.7))
				game.last_travel_direction = Vector3.RIGHT
				game.player_facing_yaw = PI / 2.0
				game.player_root.rotation.y = PI / 2.0
				game.jump_or_vault()
			170:
				_reset_segment(Vector3(3.75, 0.0, 3.9))
				game.last_travel_direction = Vector3.RIGHT
				game.player_facing_yaw = PI / 2.0
				game.player_root.rotation.y = PI / 2.0
				game.jump_or_vault()
			200:
				_reset_segment(Vector3(-3.8, 0.0, -2.7))
				game.player_facing_yaw = PI / 2.0
				game.player_root.rotation.y = PI / 2.0
				game.evade()
			230:
				_reset_pair()
				game.strike()
			255:
				_reset_pair()
				game.attack_timer = 0.45
				game.attack_marker.visible = true
				game.counter()
			285:
				_reset_segment(Vector3(2.0, 0.0, -0.7))
				game.grapple()
			325:
				_reset_segment(Vector3(6.0, game.PERCH_TOP_Y, -2.4))
				game.player_on_perch = true
				game.player_airborne = false
				game.move_player_world(Vector3.RIGHT, 2.8)
			355:
				_reset_takedown()
				game.stealth_takedown()
			400:
				_reset_segment(Vector3(-3.8, 0.0, -2.7))
				game.momentum = 50.0
				game.damage_player(18.0, "HURT motion review")
			425:
				_reset_segment(Vector3(-3.8, 0.0, -2.7))
				game.damage_player(100.0, "DOWNED motion review")
			465:
				quit()
				return false

	game._process(step_delta)
	_update_camera(beat)
	label.text = "%s%s\nClose deterministic review · actual gameplay state and timing" % [_segment_name(beat), " · HALF SPEED" if scale_frames == 2 else ""]
	if frame % (10 * scale_frames) == 0:
		print("NATURAL_MOTION_FRAME frame=", frame, " beat=", beat, " segment=", _segment_name(beat), " player=", game.player_root.position)
	frame += 1
	return false


func _reset_segment(position: Vector3) -> void:
	game.held_keys.clear()
	game.reset_game()
	game.player_root.position = position
	_quiet_guard()


func _reset_pair() -> void:
	_reset_segment(Vector3(-1.65, 0.0, 0.0))
	game.guard_root.position = Vector3(0.0, 0.0, 0.0)


func _reset_takedown() -> void:
	_reset_segment(Vector3(-3.65, 0.0, 0.2))
	game.guard_root.position = Vector3(-2.15, 0.0, 0.2)
	game.guard_forward = Vector3.RIGHT
	game.guard_root.rotation.y = PI / 2.0
	game.player_facing_yaw = PI / 2.0
	game.player_root.rotation.y = PI / 2.0


func _quiet_guard() -> void:
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0


func _update_camera(beat: int) -> void:
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.08, 0.0)
	if (beat >= 230 and beat < 285) or (beat >= 355 and beat < 400):
		focus = (game.player_root.position + game.guard_root.position) * 0.5 + Vector3(0.0, 1.05, 0.0)
	var side_view := beat < 230 or (beat >= 285 and beat < 355) or beat >= 400
	game.camera.position = focus + (Vector3(0.0, 2.15, 7.2) if side_view else Vector3(4.4, 2.35, 6.6))
	game.camera.look_at(focus)
	game.camera.size = 4.5 if side_view else 5.0


func _segment_name(beat: int) -> String:
	if beat < 60: return "TACTICAL JOG · CONTACT / PASS / TOE-OFF"
	if beat < 75: return "JOG STOP · WEIGHT SETTLE"
	if beat < 135: return "STEALTH CROUCH · ENTER / MOVE / EXIT"
	if beat < 170: return "FREE JUMP · COMPRESS / FLIGHT / ABSORB"
	if beat < 200: return "VAULT · REACH / CLEAR / LAND"
	if beat < 230: return "FORWARD SOMERSAULT · FACING-DIRECTION TRAVEL"
	if beat < 255: return "STRIKE · WINDUP / CONTACT / RECOVER"
	if beat < 285: return "COUNTER · BRACE / REDIRECT / RECOVER"
	if beat < 325: return "GRAPPLE · COIL / REACH / RECEIVE"
	if beat < 355: return "PERCH FALL · AIR / FLOOR RECOVERY"
	if beat < 400: return "TAKEDOWN · CATCH / PULL / RELEASE"
	if beat < 425: return "HURT · RECOIL / RECOVER"
	return "DOWNED · WHOLE-BODY COLLAPSE / SETTLE"
