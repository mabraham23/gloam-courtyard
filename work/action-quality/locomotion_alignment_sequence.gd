extends SceneTree

## Matched current-R14 locomotion review: profile, travel-front, three-quarter and
## actual default camera at the unchanged 4.8-unit/s controller speed.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

const SEGMENT_FRAMES := 90
const TOTAL_FRAMES := SEGMENT_FRAMES * 4

var game: Node3D
var label: Label
var frame := 0
var started := false
var review_label := "candidate"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-label="):
			review_label = argument.trim_prefix("--review-label=")
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
	_prepare_review_stage()
	label = Label.new()
	label.position = Vector2(150, 514)
	label.size = Vector2(660, 72)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_reset_segment(0)
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	var local_frame := frame % SEGMENT_FRAMES
	if local_frame == 0 and frame > 0:
		_reset_segment(frame / SEGMENT_FRAMES)
	elif local_frame == 12:
		game.held_keys[KEY_D] = true
	elif local_frame == 72:
		game.held_keys.erase(KEY_D)

	game._process(1.0 / 30.0)
	_update_camera(frame / SEGMENT_FRAMES)
	label.text = "%s · %s\nActual 4.8-unit/s controller · current R14 · idle/start/sustain/release" % [review_label, _view_name(frame / SEGMENT_FRAMES)]
	frame += 1
	if frame >= TOTAL_FRAMES:
		print("R14_LOCOMOTION_ALIGNMENT_SEQUENCE_OK label=", review_label, " frames=", TOTAL_FRAMES)
		quit()
	return false


func _reset_segment(index: int) -> void:
	game.held_keys.clear()
	game.reset_game()
	game.player_root.position = Vector3(-5.5 + index * 0.35, 0.0, 4.6 - index * 0.15)
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_stun = 999.0
	game.attack_cooldown = 999.0
	game.guard_visual_parts["visual_root"].visible = false
	game.guard_label.visible = false
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false


func _update_camera(view: int) -> void:
	if view == 3:
		game.reset_camera()
		return
	var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.05, 0.0)
	var travel: Vector3 = game.last_travel_direction
	travel.y = 0.0
	if travel.length() < 0.01:
		travel = Vector3(0.771, 0.0, -0.636)
	travel = travel.normalized()
	var side := Vector3(-travel.z, 0.0, travel.x).normalized()
	var offset: Vector3 = Vector3.ZERO
	match view:
		0:
			offset = side * 6.4
		1:
			offset = travel * 6.4
		_:
			offset = side * 4.7 + travel * 3.7
	offset.y = 2.05
	game.camera.position = focus + offset
	game.camera.look_at(focus)
	game.camera.size = 5.05


func _view_name(view: int) -> String:
	return ["PROFILE", "TRAVEL-FRONT", "THREE-QUARTER", "DEFAULT CAMERA"][view]


func _prepare_review_stage() -> void:
	# Remove courtyard foreground occluders from the matched silhouette views;
	# the controller, character, lighting and camera path remain unchanged.
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if not game.player_root.is_ancestor_of(mesh) and not game.guard_root.is_ancestor_of(mesh):
			(mesh as MeshInstance3D).visible = false
	for canvas in game.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, -0.01, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#202938")
	floor_material.roughness = 0.72
	floor_mesh.material_override = floor_material
	game.add_child(floor_mesh)
