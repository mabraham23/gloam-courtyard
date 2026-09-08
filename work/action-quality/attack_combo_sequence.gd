extends SceneTree

## Normal-render review reel for all four attacks at all three body presets.
##
## Each one-second segment includes neutral setup, the complete controller-owned
## action/contact/recovery, and a returned stance. `--slow-motion` doubles movie
## frames while retaining 1/60 gameplay stepping for a disclosed half-speed pass.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const AttackCatalog = preload("res://actors/player_attack_catalog.gd")
const PRESETS := [0.88, 1.0, 1.16]
const SEGMENT_BEATS := 30

var game: Node3D
var label: Label
var frame := 0
var frame_scale := 1
var step_delta := 1.0 / 30.0
var started := false
var segment_index := 0
var attack_started := false
var isolated_review := false


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	frame_scale = 2 if "--slow-motion" in OS.get_cmdline_user_args() else 1
	isolated_review = "--isolated" in OS.get_cmdline_user_args()
	step_delta = 1.0 / 60.0 if frame_scale == 2 else 1.0 / 30.0
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
	label.position = Vector2(105, 505)
	label.size = Vector2(750, 88)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_setup_segment()
	print("R7_ATTACK_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH),
		" half_speed=", frame_scale == 2)
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	var beat := frame / frame_scale
	var local_beat := beat % SEGMENT_BEATS
	if frame % frame_scale == 0:
		if local_beat == 4 and not attack_started:
			_start_attack()
		if local_beat == 0 and beat > 0:
			_assert_segment()
			segment_index += 1
			if segment_index >= PRESETS.size() * AttackCatalog.ORDER.size():
				print("R7_ATTACK_SEQUENCE_OK frames=", frame)
				quit()
				return false
			_setup_segment()

	game._process(step_delta)
	if frame_scale == 2 and is_equal_approx(_preset(), 1.0) \
		and _variant() == AttackCatalog.LEFT_KICK and frame in [372, 374, 376]:
		var support_y := _support_sole_y("L")
		print("R7_RENDERED_SUPPORT frame=", frame, " support_sole_y=", support_y,
			" floor_y=-0.01 imported_root_y=", game.player_visual_parts["authored_rig"]["imported_root"].position.y)
		assert(support_y >= -0.008 and support_y <= 0.020,
			"Rendered support sole must remain within two centimetres of world floor")
	_update_camera()
	label.text = _label_text(local_beat)
	if frame % (3 * frame_scale) == 0:
		print("R7_ATTACK_FRAME frame=", frame,
			" preset=", _preset(),
			" variant=", _variant(),
			" local_beat=", local_beat,
			" progress=", snappedf(_attack_progress(), 0.001),
			" guard_hp=", game.guard_health)
	frame += 1
	return false


func _setup_segment() -> void:
	attack_started = false
	game.player_scale = _preset()
	game.reset_game()
	game.guard_stun = 0.0
	game.guard_stun_duration = 0.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	var distance := 1.55 if AttackCatalog.kind(_variant()) == &"punch" else 2.18
	game.player_root.position = Vector3(0.0, 0.0, -distance)
	game.guard_root.position = Vector3.ZERO
	game.player_facing_yaw = 0.0
	game.player_root.rotation = Vector3.ZERO
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = false
	if isolated_review:
		game.guard_visual_parts["visual_root"].visible = false


func _start_attack() -> void:
	attack_started = true
	game._commit_strike_variant(_variant(), true)
	game.face_player_toward_guard()


func _assert_segment() -> void:
	assert(attack_started, "Attack review segment never started")
	assert(is_equal_approx(game.guard_health, 78.0), "%s did not apply one protected 22-point hit" % _variant())
	assert(is_equal_approx(game.momentum, 13.0), "%s did not apply one protected Momentum result" % _variant())
	assert(game.player_strike_timer <= 0.0 and not game.player_strike_pending, "%s did not recover" % _variant())


func _variant() -> StringName:
	return AttackCatalog.ORDER[segment_index % AttackCatalog.ORDER.size()]


func _preset() -> float:
	return float(PRESETS[floori(float(segment_index) / float(AttackCatalog.ORDER.size()))])


func _attack_progress() -> float:
	if not attack_started:
		return 0.0
	if game.player_strike_timer <= 0.0:
		return 1.0
	return 1.0 - game.player_strike_timer / game.player_attack_duration


func _label_text(local_beat: int) -> String:
	var state := "NEUTRAL"
	if attack_started and game.player_strike_timer > 0.0:
		state = "CONTACT" if _attack_progress() >= AttackCatalog.contact_progress(_variant()) else "LOAD"
	elif attack_started:
		state = "RECOVERED"
	return "R7 FOUR-ATTACK REVIEW | preset %.2f | %s | %s\n%s %s | authored motion, unchanged damage/Momentum" % [
		_preset(), AttackCatalog.label(_variant()).to_upper(), state,
		"HALF-SPEED (1/60 gameplay per 30fps movie frame)" if frame_scale == 2 else "REAL-TIME 30fps",
		"| ISOLATED SILHOUETTE" if isolated_review else "| PAIRED CONTACT",
	]


func _update_camera() -> void:
	var midpoint: Vector3 = (game.player_root.position + game.guard_root.position) * 0.5
	var focus: Vector3 = midpoint + Vector3(0.0, 1.10, 0.0)
	var camera_side := -1.0 if AttackCatalog.side(_variant()) > 0.0 else 1.0
	if isolated_review:
		# A near-profile lens keeps forward reach in the image plane. The earlier
		# front three-quarter diagnostic foreshortened a valid straight into an
		# ambiguous cross-chest silhouette.
		game.camera.position = focus + Vector3(6.15 * camera_side, 1.72, 0.28)
		game.camera.size = 4.65
	else:
		game.camera.position = focus + Vector3(4.35, 2.10, 5.35)
		game.camera.size = 4.9
	game.camera.look_at(focus)


func _support_sole_y(support_suffix: String) -> float:
	var rig: Dictionary = game.player_visual_parts["authored_rig"]
	var skeleton := rig["skeleton"] as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var to_actor := Transform3D.IDENTITY
	var node: Node3D = skeleton
	var actor := (game.player_visual_parts["visual_root"] as Node3D).get_parent() as Node3D
	while node != actor:
		to_actor = node.transform * to_actor
		node = node.get_parent() as Node3D
	var minimum_y := INF
	for contact: Dictionary in rig["foot_contacts"]:
		if contact["side"] != support_suffix:
			continue
		var skinned := Vector3.ZERO
		for influence: Dictionary in contact["influences"]:
			skinned += (
				skeleton.get_bone_global_pose(influence["bone"])
				* influence["bind_pose"]
				* contact["point"]
			) * float(influence["weight"])
		if float(contact["total_weight"]) > 0.0:
			skinned /= float(contact["total_weight"])
		minimum_y = minf(minimum_y, (actor.global_transform * (to_actor * skinned)).y)
	return minimum_y


func _prepare_review_stage() -> void:
	# Preserve the real controller, rigs, materials, lighting and camera while
	# removing courtyard foreground occluders from this evidence-only reel.
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if not game.player_root.is_ancestor_of(mesh) and not game.guard_root.is_ancestor_of(mesh):
			(mesh as MeshInstance3D).visible = false
	for canvas in game.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.0, 6.0)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, -0.01, -1.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#202938")
	floor_material.roughness = 0.72
	floor_mesh.material_override = floor_material
	game.add_child(floor_mesh)
