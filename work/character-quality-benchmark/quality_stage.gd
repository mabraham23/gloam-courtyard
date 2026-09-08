extends SceneTree

## Diagnostic-only, equal-light/equal-scale v1/v2 visual review. Not a performance
## benchmark. Movie mode deliberately stretches the action poses for inspection.
const Builder = preload("res://actors/character_visual_builder.gd")
var stage: Node3D
var actors: Array[Node3D] = []
var parts: Array[Dictionary] = []
var caption: Label
var frame := 0
var view := "actions"
var ready_for_frames := false
var poses := ["neutral", "walk", "crouch", "jump", "vault", "grapple", "grapple_recover", "evade", "strike", "counter", "fall", "neutral"]

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--view="):
			view = argument.trim_prefix("--view=")
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#202733")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d1d4de")
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	for setting in [[Vector3(-35, -30, 0), 1.7, Color.WHITE], [Vector3(-15, 150, 0), 0.9, Color("#91a9ce")]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = setting[0]
		light.light_energy = setting[1]
		light.light_color = setting[2]
		stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#313945")
	material.roughness = 0.9
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var face_view := view.begins_with("face")
	for version in range(2):
		var actor := Node3D.new()
		actor.position.x = (-1.0 if version == 0 else 1.0) * (0.43 if face_view else 0.82)
		if view.ends_with("profile"):
			actor.rotation.y = PI * 0.5
		elif view.ends_with("three-quarter"):
			actor.rotation.y = -PI * 0.23
		stage.add_child(actor)
		actors.append(actor)
		parts.append(Builder.build_player(actor, Color("#c55c77"), version == 1))
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0 if face_view else 3.35
	var focus := Vector3(0, 1.94, 0) if face_view else Vector3(0, 1.08, 0)
	camera.position = focus + Vector3(0, 0.015 if face_view else 0.3, 7)
	camera.look_at_from_position(camera.position, focus)
	camera.current = true
	caption = Label.new()
	caption.position = Vector2(22, 16)
	caption.add_theme_font_size_override("font_size", 20)
	root.add_child(caption)
	var legend := Label.new()
	legend.position = Vector2(22, 552)
	legend.add_theme_font_size_override("font_size", 16)
	legend.text = "LEFT: accepted v1     RIGHT: v2 candidate\nSame lighting / same scale / inspection sequence, not gameplay timing"
	root.add_child(legend)
	print("QUALITY_STAGE view=", view, " render_size=", root.get_visible_rect().size)
	ready_for_frames = true

func _process(delta: float) -> bool:
	if not ready_for_frames:
		return false
	var state_index := mini(frame / 30, poses.size() - 1)
	var pose: String = poses[state_index] if view == "actions" else "neutral"
	var state := &"grounded" if pose in ["neutral", "walk"] else StringName(pose)
	var movement := 1.0 if pose == "walk" else 0.0
	var progress := float(frame % 30) / 29.0
	caption.text = "GLOAM / CHARACTER QUALITY / " + (pose if view == "actions" else view).to_upper()
	for character in parts:
		Builder.pose_player(character, float(frame) * 0.22, movement, delta, state, progress)
	frame += 1
	return false
