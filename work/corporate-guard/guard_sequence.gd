extends SceneTree

## Side-by-side rendered review of the preserved procedural warden and the
## candidate corporate sentry. Fixed positioning/camera and scripted poses are
## diagnostic helpers, not native gameplay evidence.

const Builder = preload("res://actors/character_visual_builder.gd")
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

var game: Node3D
var legacy_parts: Dictionary
var sentry_parts: Dictionary
var sentry_root: Node3D
var label: Label
var frame := 0
var started := false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	legacy_parts = game.guard_visual_parts
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	game.player_visual_parts["visual_root"].visible = false
	game.player_root.position = Vector3(0.0, -20.0, 0.0)
	game.guard_root.position = Vector3(-1.15, 0.0, 0.0)
	game.guard_root.rotation = Vector3.ZERO
	game.guard_root.scale = Vector3.ONE * game.GUARD_BASE_SCALE
	sentry_root = Node3D.new()
	sentry_root.name = "CorporateSentryReviewRoot"
	game.add_child(sentry_root)
	sentry_root.position = Vector3(1.15, 0.0, 0.0)
	sentry_root.scale = Vector3.ONE * game.GUARD_BASE_SCALE
	sentry_parts = Candidate.build_guard(sentry_root)
	assert(Candidate.is_exact_guard(sentry_parts))
	for node in game.find_children("*", "Label3D", true, false):
		node.visible = false
	for child in game.get_children():
		if child is CanvasLayer:
			child.visible = false
	game.vision_mesh.visible = false

	label = Label.new()
	label.position = Vector2(110, 515)
	label.size = Vector2(740, 70)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	var pose := &"grounded"
	var progress := 0.0
	var movement := 0.0
	var phase := frame * 0.18
	if frame < 45:
		movement = 0.0
	elif frame < 90:
		movement = 1.0
	elif frame < 125:
		pose = &"attack"
		progress = float(frame - 90) / 34.0
	elif frame < 160:
		pose = &"stagger"
		progress = float(frame - 125) / 34.0
	else:
		pose = &"defeated"
		progress = float(frame - 160) / 49.0

	Builder.pose_guard(legacy_parts, phase, movement, 1.0 / 30.0, pose, progress, 1.0)
	Builder.pose_guard(sentry_parts, phase, movement, 1.0 / 30.0, pose, progress, 1.0)
	var focus := Vector3(0.0, 1.25, 0.0)
	game.camera.position = focus + (Vector3(3.8, 1.55, 6.0) if frame >= 90 else Vector3(0.0, 1.2, 6.4))
	game.camera.look_at(focus)
	game.camera.size = 4.25
	label.text = "OLD PROCEDURAL WARDEN     |     R14 CORPORATE SENTRY\n%s · red security uniform / helmet / sidearm" % _phase_name()
	frame += 1
	if frame >= 210:
		print("CORPORATE_GUARD_SEQUENCE_OK frames=", frame)
		quit()
	return false


func _phase_name() -> String:
	if frame < 45:
		return "IDLE"
	if frame < 90:
		return "PATROL"
	if frame < 125:
		return "CLOSE-RANGE STRIKE / HOLSTERED SIDEARM"
	if frame < 160:
		return "HIT REACTION"
	return "DEFEAT"
