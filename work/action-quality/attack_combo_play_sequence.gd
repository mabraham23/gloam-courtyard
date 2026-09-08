extends SceneTree

## Normal-render proof that ordinary strike requests use the contextual chooser
## and one-slot recovery buffer rather than a diagnostic-only forced cycle.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const AttackCatalog = preload("res://actors/player_attack_catalog.gd")
const STEP := 1.0 / 30.0
const CLOSE_HITS := 4
const MID_HITS := 4

var game: Node3D
var label: Label
var frame := 0
var phase := &"close"
var phase_hits := 0
var total_hits := 0
var recovery_wait := 0
var previous_health := 999.0
var chosen: Array[StringName] = []
var chosen_distances: Array[float] = []
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
	_prepare_stage()
	label = Label.new()
	label.position = Vector2(80, 505)
	label.size = Vector2(800, 88)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	game.reset_game()
	game.guard_health = 999.0
	game.guard_label.text = "GUARD 999"
	game.player_attack_rng.seed = 90427
	_place(1.55)
	previous_health = game.guard_health
	print("R7_CONTEXT_COMBO sha=", FileAccess.get_sha256(Candidate.ASSET_PATH), " seed=90427")
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	if frame == 8:
		_press_space()
	if game.player_strike_timer > 0.0 \
		and game.player_strike_timer <= game.PLAYER_ATTACK_BUFFER_WINDOW \
		and not game.player_strike_pending \
		and not game.player_attack_buffered \
		and phase_hits < _phase_goal():
		_press_space()
	game._process(STEP)
	if game.guard_health < previous_health - 0.001:
		_record_contact()
	previous_health = game.guard_health

	if phase_hits >= _phase_goal() and game.player_strike_timer <= 0.0:
		recovery_wait += 1
		if recovery_wait == 12 and phase == &"close":
			phase = &"mid"
			phase_hits = 0
			recovery_wait = 0
			_place(2.30)
			_press_space()
		elif recovery_wait >= 18 and phase == &"mid":
			_finish()
			return false

	_update_camera()
	label.text = "R7 CONTEXT COMBO | %s RANGE | hit %d/8 | %s\nreal-time 30fps | one-slot recovery buffer | %s" % [
		"CLOSE" if phase == &"close" else "MID",
		total_hits,
		AttackCatalog.label(game.player_attack_variant).to_upper() if game.player_strike_timer > 0.0 else "RECOVERY",
		" → ".join(PackedStringArray(chosen.map(func(value): return _short_name(value)))),
	]
	frame += 1
	if frame >= 360:
		push_error("context combo reel exceeded its bounded timeline")
		quit(1)
	return false


func _record_contact() -> void:
	var variant: StringName = game.player_attack_variant
	assert(chosen.is_empty() or chosen.back() != variant, "context combo cannot repeat immediately")
	if phase == &"mid":
		assert(AttackCatalog.kind(variant) == &"kick", "2.30-unit combo must select reach-valid kicks")
	chosen.append(variant)
	chosen_distances.append(game.player_root.position.distance_to(game.guard_root.position))
	phase_hits += 1
	total_hits += 1
	print("R7_CONTEXT_COMBO_CONTACT index=", total_hits,
		" frame=", frame, " phase=", phase, " distance=", chosen_distances.back(), " variant=", variant,
		" guard_hp=", game.guard_health, " momentum=", game.momentum)


func _phase_goal() -> int:
	return CLOSE_HITS if phase == &"close" else MID_HITS


func _short_name(variant: StringName) -> String:
	match variant:
		AttackCatalog.RIGHT_PUNCH: return "RP"
		AttackCatalog.LEFT_PUNCH: return "LP"
		AttackCatalog.LEFT_KICK: return "LK"
		_: return "RK"


func _press_space() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.physical_keycode = KEY_SPACE
		event.pressed = pressed
		game._unhandled_input(event)


func _place(distance: float) -> void:
	game.player_root.position = Vector3(0.0, 0.0, -distance)
	game.guard_root.position = Vector3.ZERO
	game.player_facing_yaw = 0.0
	game.player_root.rotation = Vector3.ZERO
	game.face_player_toward_guard()


func _update_camera() -> void:
	var midpoint: Vector3 = (game.player_root.position + game.guard_root.position) * 0.5
	var focus := midpoint + Vector3(0.0, 1.08, 0.0)
	game.camera.position = focus + Vector3(4.35, 2.05, 5.2)
	game.camera.look_at(focus)
	game.camera.size = 4.9


func _prepare_stage() -> void:
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if not game.player_root.is_ancestor_of(mesh) and not game.guard_root.is_ancestor_of(mesh):
			(mesh as MeshInstance3D).visible = false
	for canvas in game.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.0, 6.0)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, -0.01, -1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#202938")
	material.roughness = 0.72
	floor_mesh.material_override = material
	game.add_child(floor_mesh)


func _finish() -> void:
	assert(total_hits == CLOSE_HITS + MID_HITS)
	assert(chosen.size() == chosen_distances.size())
	for index in range(CLOSE_HITS, chosen.size()):
		assert(chosen_distances[index] >= 2.29 and AttackCatalog.kind(chosen[index]) == &"kick")
	print("R7_CONTEXT_COMBO_OK hits=", total_hits, " variants=", chosen, " frames=", frame)
	quit()
