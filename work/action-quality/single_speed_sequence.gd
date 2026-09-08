extends SceneTree

## Short normal-renderer review for the simplified standing controller. Plain
## WASD and Shift+WASD must produce the same corrected run, while the final beat
## makes start/stop recovery visible. Only camera/guard placement are fixtures.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

const TOTAL_FRAMES := 210
const DELTA := 1.0 / 30.0

var game: Node3D
var label: Label
var frame := 0
var started := false
var segment_start := Vector3.ZERO
var plain_distance := -1.0
var shifted_distance := -1.0
var front_review := false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	front_review = "--front" in OS.get_cmdline_user_args()
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	label = Label.new()
	label.position = Vector2(130, 470)
	label.size = Vector2(700, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_reset_segment()
	print("R14_SINGLE_SPEED_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH),
		" front_review=", front_review)
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	match frame:
		15:
			segment_start = game.player_root.position
			game.held_keys[KEY_D] = true
		60:
			plain_distance = segment_start.distance_to(game.player_root.position)
			game.held_keys.clear()
		75:
			_reset_segment()
		90:
			segment_start = game.player_root.position
			game.held_keys[KEY_SHIFT] = true
			game.held_keys[KEY_D] = true
		135:
			shifted_distance = segment_start.distance_to(game.player_root.position)
			game.held_keys.clear()
		150:
			_reset_segment()
		165:
			game.held_keys[KEY_D] = true
		180:
			game.held_keys.clear()
		190:
			game.held_keys[KEY_D] = true
		205:
			game.held_keys.clear()

	_prepare_input_camera()
	game._process(DELTA)
	_update_camera()
	label.text = "%s\nWASD %.2f u/s · Shift has no locomotion effect · run pose %.2f" % [
		_segment_name(), game.PLAYER_MOVE_SPEED, game.player_run_blend,
	]
	if frame % 10 == 0:
		print("R14_SINGLE_SPEED_FRAME frame=", frame, " segment=", _segment_name(), " position=", game.player_root.position, " run_pose=", game.player_run_blend)
	frame += 1
	if frame >= TOTAL_FRAMES:
		assert(absf(plain_distance - shifted_distance) <= 0.001)
		assert(absf(plain_distance - 7.2) <= 0.01)
		print("R14_SINGLE_SPEED_SEQUENCE_OK frames=", TOTAL_FRAMES, " plain_distance=", plain_distance, " shifted_distance=", shifted_distance)
		quit()
	return false


func _reset_segment() -> void:
	game.held_keys.clear()
	game.reset_game()
	game.player_root.position = Vector3(-5.3, 0.0, 4.3)
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_visual_parts["visual_root"].visible = false
	game.guard_label.visible = false
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false


func _prepare_input_camera() -> void:
	game.camera_yaw = 0.0
	game.update_camera(0.0)


func _update_camera() -> void:
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.08, 0.0)
	var travel := Vector3(sin(game.player_facing_yaw), 0.0, cos(game.player_facing_yaw)).normalized()
	var side := Vector3(travel.z, 0.0, -travel.x)
	# The optional front view is a matched silhouette check for the narrower
	# lower-leg stance. It preserves the exact controller path and timing.
	var view_axis := -travel if front_review else side
	game.camera.position = focus + view_axis * 6.7 + Vector3(0.0, 2.1, 0.0)
	game.camera.look_at(focus)
	game.camera.size = 5.2


func _segment_name() -> String:
	if frame < 15: return "PLAIN WASD · IDLE"
	if frame < 60: return "PLAIN WASD · CORRECTED RUN"
	if frame < 75: return "PLAIN WASD · STOP"
	if frame < 90: return "SHIFT COMPARISON · IDLE"
	if frame < 135: return "SHIFT + WASD · SAME RUN"
	if frame < 150: return "SHIFT COMPARISON · STOP"
	if frame < 165: return "START / STOP · IDLE"
	if frame < 180: return "START / STOP · FIRST RUN"
	if frame < 190: return "START / STOP · SETTLE"
	if frame < 205: return "START / STOP · SECOND RUN"
	return "START / STOP · FINAL SETTLE"
