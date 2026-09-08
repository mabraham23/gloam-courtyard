extends SceneTree

## Superseded Sep-8 review harness for the rejected separate walk/run policy.
## Preserve it with the historical 570-frame evidence; current controller review
## lives in single_speed_sequence.gd and must not relabel this older reel.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

const TOTAL_FRAMES := 570
const DELTA := 1.0 / 30.0

var game: Node3D
var label: Label
var frame := 0
var started := false


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
	label.position = Vector2(130, 468)
	label.size = Vector2(700, 58)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_reset_segment(Vector3(-5.3, 0.0, 4.3))
	print("R7_WALK_RUN_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	match frame:
		15:
			game.held_keys[KEY_D] = true
		75:
			game.held_keys.erase(KEY_D)
		90:
			_reset_segment(Vector3(-5.3, 0.0, 4.3))
		105:
			game.held_keys[KEY_SHIFT] = true
			game.held_keys[KEY_D] = true
		165:
			game.held_keys.clear()
		180:
			_reset_segment(Vector3(-5.3, 0.0, 4.3))
		195:
			game.held_keys[KEY_D] = true
		255:
			game.held_keys.clear()
		270:
			_reset_segment(Vector3(-5.3, 0.0, 4.3))
		285:
			game.held_keys[KEY_SHIFT] = true
			game.held_keys[KEY_D] = true
		345:
			game.held_keys.clear()
		360:
			_reset_segment(Vector3(-6.0, 0.0, 4.3))
		375:
			game.held_keys[KEY_D] = true
		405:
			game.held_keys[KEY_SHIFT] = true
		445:
			game.held_keys.erase(KEY_SHIFT)
		470:
			game.held_keys.erase(KEY_D)
		485:
			_reset_segment(Vector3(-4.6, 0.0, -1.6))
		495:
			game.held_keys[KEY_D] = true
		515:
			game.held_keys[KEY_SHIFT] = true
		535:
			game.held_keys.erase(KEY_D)
			game.held_keys[KEY_W] = true
		555:
			game.held_keys.clear()

	_prepare_input_camera()
	game._process(DELTA)
	_update_camera()
	label.text = "%s\nWASD walk %.2f · Shift+WASD run %.2f · blend %.2f" % [
		_segment_name(), game.PLAYER_WALK_SPEED, game.PLAYER_RUN_SPEED, game.player_run_blend,
	]
	if frame % 10 == 0:
		print("R7_WALK_RUN_FRAME frame=", frame, " segment=", _segment_name(), " position=", game.player_root.position, " run_blend=", game.player_run_blend)
	frame += 1
	if frame >= TOTAL_FRAMES:
		print("R7_WALK_RUN_SEQUENCE_OK frames=", TOTAL_FRAMES)
		quit()
	return false


func _reset_segment(position: Vector3) -> void:
	game.held_keys.clear()
	game.reset_game()
	game.player_root.position = position
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_visual_parts["visual_root"].visible = false
	game.guard_label.visible = false
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false


func _update_camera() -> void:
	if frame >= 485:
		game.reset_camera()
		return
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.08, 0.0)
	var travel := Vector3(sin(game.player_facing_yaw), 0.0, cos(game.player_facing_yaw)).normalized()
	var side := Vector3(travel.z, 0.0, -travel.x)
	var offset := side * 6.7
	if frame >= 180 and frame < 360:
		# Camera sits downrange and looks back at the character: a true front
		# view that exposes palms, knees and left/right symmetry.
		offset = travel * 6.7
	elif frame >= 360:
		offset = side * 5.7 + travel * 2.8
	offset.y = 2.1
	game.camera.position = focus + offset
	game.camera.look_at(focus)
	game.camera.size = 5.2


func _prepare_input_camera() -> void:
	if frame >= 485:
		return
	# Feed a stable +X camera-relative direction to the real held-key controller
	# before installing the review camera. This keeps motion straight while the
	# post-step evidence camera changes between true profile/front/three-quarter.
	game.camera_yaw = 0.0
	game.update_camera(0.0)


func _segment_name() -> String:
	if frame < 15: return "PROFILE · WALK IDLE"
	if frame < 75: return "TRUE PROFILE · SEPARATE CAPTURED WALK"
	if frame < 90: return "PROFILE · WALK STOP"
	if frame < 105: return "PROFILE · RUN IDLE"
	if frame < 165: return "TRUE PROFILE · SEPARATE CAPTURED RUN"
	if frame < 180: return "PROFILE · RUN STOP"
	if frame < 195: return "FRONT · WALK IDLE"
	if frame < 255: return "TRUE FRONT · SEPARATE CAPTURED WALK"
	if frame < 270: return "FRONT · WALK STOP"
	if frame < 285: return "FRONT · RUN IDLE"
	if frame < 345: return "TRUE FRONT · SEPARATE CAPTURED RUN"
	if frame < 360: return "FRONT · RUN STOP"
	if frame < 375: return "THREE-QUARTER · TRANSITION IDLE"
	if frame < 405: return "THREE-QUARTER · WALK"
	if frame < 445: return "THREE-QUARTER · WALK TO RUN"
	if frame < 470: return "THREE-QUARTER · RUN TO WALK"
	if frame < 485: return "THREE-QUARTER · STOP"
	if frame < 495: return "DEFAULT CAMERA · IDLE"
	if frame < 515: return "DEFAULT CAMERA · WALK"
	if frame < 535: return "DEFAULT CAMERA · RUN"
	if frame < 555: return "DEFAULT CAMERA · RUNNING 90 DEGREE TURN"
	return "DEFAULT CAMERA · FINAL STOP"
