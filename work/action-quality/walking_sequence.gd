extends SceneTree

## Focused normal-render gait review for the exact R7 candidate. It drives the
## real 4.8-unit/s controller through collision-free start/stop, default-camera,
## 90-degree turn and 180-degree reversal segments. At this speed the motion is
## intentionally labeled a tactical run/jog rather than a walk.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

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
	label.position = Vector2(180, 525)
	label.size = Vector2(600, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_reset_player(Vector3(-6.0, 0.0, 4.8))
	_set_world_labels(false)
	print("R7_GAIT_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	match frame:
		24:
			game.held_keys[KEY_D] = true
		78:
			game.held_keys.erase(KEY_D)
		102:
			_reset_player(Vector3(-4.0, 0.0, 3.6))
			_set_world_labels(true)
			game.held_keys[KEY_D] = true
		150:
			game.held_keys.erase(KEY_D)
		174:
			_reset_player(Vector3(-4.0, 0.0, -1.0))
			_set_world_labels(false)
			game.held_keys[KEY_D] = true
		198:
			game.held_keys.erase(KEY_D)
			game.held_keys[KEY_W] = true
		222:
			game.held_keys.erase(KEY_W)
		246:
			# Keep the reversal in the same open upper-court strip used by the
			# profile pass. The former center-court position put the actor behind
			# a railing during the very frames this segment exists to review.
			_reset_player(Vector3(-2.5, 0.0, 2.0))
			game.held_keys[KEY_D] = true
		270:
			game.held_keys.erase(KEY_D)
			game.held_keys[KEY_A] = true
		318:
			game.held_keys.erase(KEY_A)
		342:
			print("R7_GAIT_SEQUENCE_OK frames=342")
			quit()
			return false

	game._process(1.0 / 30.0)
	_assert_clear_path()
	_update_review_camera()
	label.text = "%s\nActual 4.8-unit/s controller · %.3f rad/s captured gait · exact R7" % [_segment_name(), TAU / (83.0 / 120.0)]
	if frame % 12 == 0:
		print("R7_GAIT_FRAME frame=", frame, " segment=", _segment_name(), " player=", game.player_root.position, " phase=", game.player_step_phase)
	frame += 1
	return false


func _reset_player(position: Vector3) -> void:
	game.held_keys.clear()
	game.reset_game()
	game.player_root.position = position
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_visual_parts["visual_root"].visible = false
	game.guard_label.visible = false


func _set_world_labels(visible: bool) -> void:
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = visible


func _assert_clear_path() -> void:
	var position: Vector3 = game.player_root.position
	assert(absf(position.x) < 8.85 and absf(position.z) < 4.95, "Gait review path approached a world clamp")
	assert(not game.is_in_low_passage(position), "Gait review path entered the low passage")
	assert(not game.is_inside_vault_obstacle(position), "Gait review path entered the vault blocker")


func _update_review_camera() -> void:
	if frame >= 102 and frame < 174:
		game.reset_camera()
		return
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.05, 0.0)
	var travel: Vector3 = game.last_travel_direction
	# Hold one observer side across the 180-degree reversal. Following the
	# instantaneous travel vector would teleport the review camera through the
	# actor at frame 270 and hide the actual direction-change silhouette.
	if frame >= 246:
		travel = Vector3.RIGHT
	travel.y = 0.0
	if travel.length() < 0.01:
		travel = Vector3(0.771, 0.0, -0.636)
	travel = travel.normalized()
	var side := Vector3(-travel.z, 0.0, travel.x).normalized()
	# The opening view is a true travel-relative profile. Turn and reversal use
	# a mild three-quarter offset so pelvis transfer and cape lag remain visible.
	var offset: Vector3 = side * (6.4 if frame < 102 else 5.6) - travel * (0.0 if frame < 102 else 2.1)
	offset.y = 2.05
	game.camera.position = focus + offset
	game.camera.look_at(focus)
	game.camera.size = 5.05


func _segment_name() -> String:
	if frame < 24: return "PROFILE · IDLE BEFORE INPUT"
	if frame < 78: return "PROFILE · START / CAPTURED RUN-JOG"
	if frame < 102: return "PROFILE · RELEASE / SETTLE"
	if frame < 150: return "DEFAULT CAMERA · SUSTAINED HELD INPUT"
	if frame < 174: return "DEFAULT CAMERA · RELEASE / SETTLE"
	if frame < 198: return "THREE-QUARTER · HELD INPUT"
	if frame < 222: return "THREE-QUARTER · 90° DIRECTION CHANGE"
	if frame < 246: return "THREE-QUARTER · SETTLE"
	if frame < 270: return "REVERSAL · OUTBOUND"
	if frame < 318: return "REVERSAL · 180° RETURN"
	return "REVERSAL · FINAL SETTLE"
