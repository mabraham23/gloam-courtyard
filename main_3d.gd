extends Node3D

## True-3D courtyard spike with an original skinned player and primitive world.

const CharacterVisualBuilder = preload("res://actors/character_visual_builder.gd")
const R7RunReference = preload("res://actors/gloam_vigil/v4/motion/cmu_run_reference.gd")
const PlayerAttackCatalog = preload("res://actors/player_attack_catalog.gd")

const WORLD_SIZE := Vector2(20.0, 12.0)
const PLAYER_START := Vector3(-6.0, 0.0, 2.5)
const GUARD_START := Vector3(0.0, 0.0, 0.0)
const ANCHOR_POSITION := Vector3(3.0, 0.38, -0.7)
const PERCH_POSITION := Vector3(6.0, 2.85, -2.4)
const PERCH_TOP_Y := 3.04
const PERCH_HALF_EXTENTS := Vector2(2.1, 1.45)
const EXIT_POSITION := Vector3(8.4, 0.0, -4.7)
const HIDE_POSITION := Vector3(-6.8, 0.04, 3.8)
const TAKEDOWN_SHADOW_POSITION := Vector3(-3.6, 0.04, 0.2)
const TAKEDOWN_SHADOW_RADIUS := 1.6
const GRAPPLE_RANGE := 3.5
const PATROL_POINTS := [Vector3(-2.8, 0.0, -1.0), Vector3(2.1, 0.0, 1.2)]
const CAMERA_TARGET := Vector3(0.0, 0.7, -0.7)
const CAMERA_DEFAULT_YAW := 0.69
const CAMERA_DEFAULT_PITCH := 0.47
const CAMERA_DEFAULT_DISTANCE := 22.0
const CAMERA_DEFAULT_SIZE := 18.5
const CAMERA_MIN_SIZE := 17.0
const CAMERA_MAX_SIZE := 26.0
const CAMERA_ZOOM_SPEED := 5.0
const CAMERA_ORBIT_SPEED := 1.45
const PLAYER_BASE_SCALE := 1.35
const GUARD_BASE_SCALE := 1.25
const PLAYER_BODY_RADIUS := 0.50
const GUARD_BODY_RADIUS := 0.54
const ACTOR_PERSONAL_SPACE := 1.48
const ACTOR_LEVEL_TOLERANCE := 0.78
const FALL_GRAVITY := 17.5
const PLAYER_STRIKE_DURATION := 0.36
const PLAYER_STRIKE_CONTACT := 0.14
const PLAYER_ATTACK_BUFFER_WINDOW := 0.10
const PLAYER_ATTACK_MIN_FACING_DOT := 0.62
const PLAYER_TAKEDOWN_DURATION := 1.10
const PLAYER_TAKEDOWN_CONTACT := 0.34
const PLAYER_COUNTER_DURATION := 0.44
const PLAYER_HURT_DURATION := 0.38
const PLAYER_DOWNED_DURATION := 0.72
const GUARD_DEFEAT_DURATION := 1.45
const GUARD_FADE_DELAY := 0.78
const EVADE_MOVE_DURATION := 0.28
const EVADE_INVULNERABILITY_DURATION := 0.42
const PLAYER_MOVE_SPEED := 4.80
# Preserve the accepted pre-simplification crouch travel exactly: 1.90 * 0.62.
const CROUCH_MOVE_SPEED := 1.178
const LOW_PASSAGE_MIN := Vector2(-9.0, 3.15)
const LOW_PASSAGE_MAX := Vector2(-7.0, 4.45)
const LOW_PASSAGE_CLEARANCE := 2.0
const JUMP_DURATION := 0.62
const JUMP_HEIGHT := 1.35
const JUMP_DISTANCE := 2.2
const VAULT_DURATION := 0.48
const VAULT_HEIGHT := 1.05
const VAULT_OBSTACLE_CENTER := Vector3(5.0, 0.42, 3.9)
const VAULT_OBSTACLE_HALF_EXTENTS := Vector2(0.34, 1.25)

var camera: Camera3D
var player_root: Node3D
var guard_root: Node3D
var player_visual_parts: Dictionary
var guard_visual_parts: Dictionary
var vision_mesh: MeshInstance3D
var attack_marker: Label3D
var guard_label: Label3D
var player_health := 100.0
var momentum := 0.0
var guard_health := 100.0
var guard_suspicion := 0.0
var guard_alert := false
var guard_defeated := false
var guard_patrol_index := 0
var guard_forward := Vector3(1.0, 0.0, 0.0)
var attack_timer := 0.0
var attack_cooldown := 0.0
var guard_stun := 0.0
var guard_stun_duration := 0.0
var guard_reaction_side := 1.0
var attack_countered := false
var player_strike_timer := 0.0
var player_strike_pending := false
var player_attack_variant: StringName = PlayerAttackCatalog.RIGHT_PUNCH
var player_attack_duration := PLAYER_STRIKE_DURATION
var player_attack_contact := PLAYER_STRIKE_CONTACT
var player_attack_reach := 2.20
var player_attack_target_locked := false
var player_attack_contact_connected := false
var player_attack_presentation_only := false
var player_attack_buffered := false
var player_attack_last_variant: StringName = &""
var player_attack_rng := RandomNumberGenerator.new()
var player_takedown_timer := 0.0
var player_takedown_pending := false
var player_counter_timer := 0.0
var player_hurt_timer := 0.0
var player_downed_elapsed := 0.0
var guard_defeat_elapsed := 0.0
var invulnerable := 0.0
var evade_timer := 0.0
var evade_direction := Vector3.ZERO
var last_travel_direction := Vector3(0.0, 0.0, 1.0)
var crouching := false
var jump_active := false
var jump_is_vault := false
var jump_t := 0.0
var jump_duration := JUMP_DURATION
var jump_height := JUMP_HEIGHT
var jump_start := Vector3.ZERO
var jump_end := Vector3.ZERO
var success := false
var player_scale := 1.0
var outfit_index := 0
var outfit_colors := [Color("#ba4f68"), Color("#5c99cb")]
var player_accent_material: StandardMaterial3D
var camera_yaw := CAMERA_DEFAULT_YAW
var camera_pitch := CAMERA_DEFAULT_PITCH
var camera_distance := CAMERA_DEFAULT_DISTANCE
var held_keys := {}
var message := "Slip through the dark. Reach the violet gate."
var message_timer := 4.0
var health_bar: ProgressBar
var momentum_bar: ProgressBar
var objective_label: Label
var message_label: Label
var impact_light: OmniLight3D
var counter_light: OmniLight3D
var grapple_active := false
var grapple_t := 0.0
var grapple_start := Vector3.ZERO
var grapple_recovery_timer := 0.0
var grapple_prompt: Label3D
var grapple_range_root: Node3D
var grapple_ring_material: StandardMaterial3D
var grapple_route_material: StandardMaterial3D
var grapple_anchor_light: OmniLight3D
var impact_flash_timer := 0.0
var counter_flash_timer := 0.0
var player_on_perch := false
var player_airborne := false
var vertical_velocity := 0.0
var player_facing_yaw := 0.0
var player_step_phase := 0.0
var guard_step_phase := 0.0
var player_move_timer := 0.0
var player_moved_this_frame := false
var player_move_blend := 0.0
# The retained field is the pose-resource selector. Standing locomotion always
# uses the corrected run source; Shift no longer changes speed or animation.
var player_run_blend := 1.0
var guard_move_blend := 0.0
var guard_is_moving := false

func _ready() -> void:
	player_attack_rng.randomize()
	build_environment()
	build_world()
	build_player()
	build_guard()
	build_hud()
	reset_game()

func build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#050914")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#657795")
	environment.ambient_light_energy = 0.34
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.fog_enabled = true
	environment.fog_light_color = Color("#52627b")
	environment.fog_light_energy = 0.42
	environment.fog_density = 0.018
	world_environment.environment = environment
	add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-56.0, -32.0, 0.0)
	moon.light_color = Color("#7890b3")
	moon.light_energy = 1.3
	moon.shadow_enabled = true
	add_child(moon)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_DEFAULT_SIZE
	add_child(camera)
	camera.current = true
	reset_camera()

func build_world() -> void:
	var stone := make_material(Color("#1a2435"), 0.62, 0.05)
	var wet_stone := make_material(Color("#26354c"), 0.2, 0.2)
	make_box(self, Vector3(0.0, -0.28, 0.0), Vector3(22.0, 0.5, 14.0), stone)
	# Subtle wet slabs make the camera angle legible without cluttering navigation.
	for slab in [Vector3(-4.8, 0.015, 1.8), Vector3(-1.3, 0.015, 2.6), Vector3(2.8, 0.015, 1.4), Vector3(5.0, 0.015, 3.0), Vector3(0.0, 0.015, -2.8)]:
		var highlight := make_box(self, slab, Vector3(2.3, 0.025, 0.08), wet_stone)
		highlight.rotation.y = -0.3
	var puddle_mat := make_material(Color("#314b65"), 0.12, 0.35)
	for puddle in [Vector3(-3.5, 0.02, 3.5), Vector3(1.0, 0.02, 3.0), Vector3(4.4, 0.02, 0.7), Vector3(6.2, 0.02, 3.8)]:
		var puddle_piece := make_box(self, puddle, Vector3(1.8, 0.018, 0.42), puddle_mat)
		puddle_piece.rotation.y = 0.25
	# Low perimeter walls and a rear parapet.
	make_box(self, Vector3(-10.1, 1.2, 0.0), Vector3(0.55, 2.4, 12.0), make_material(Color("#303d53"), 0.78))
	make_box(self, Vector3(10.1, 1.2, 0.0), Vector3(0.55, 2.4, 12.0), make_material(Color("#303d53"), 0.78))
	make_box(self, Vector3(0.0, 0.85, -6.0), Vector3(19.5, 1.7, 0.45), make_material(Color("#202b40"), 0.72))
	make_gothic_backdrop()
	make_parapet_rail()
	make_perch()
	make_anchor()
	make_hide_spot()
	make_low_passage()
	make_vault_obstacle()
	make_exit()
	make_lamps()
	make_rain()

func make_gothic_backdrop() -> void:
	var tower_mat := make_material(Color("#101827"), 0.88)
	var window_mat := make_material(Color("#8d3c54"), 0.28, 0.05, Color("#8d3c54"))
	for tower in [Vector3(-8.2, 3.0, -6.7), Vector3(-3.2, 3.6, -6.8), Vector3(3.0, 3.1, -6.7), Vector3(8.0, 3.8, -6.8)]:
		make_box(self, tower, Vector3(2.1, tower.y * 2.0, 1.2), tower_mat)
		make_cone(self, tower + Vector3(0.0, tower.y + 1.1, 0.0), 0.95, 2.5, tower_mat)
		make_box(self, tower + Vector3(0.0, 0.4, 0.65), Vector3(0.42, 1.7, 0.035), window_mat)
	# A larger central rose-window-like accent, kept abstract and original.
	make_box(self, Vector3(0.0, 4.4, -6.55), Vector3(1.15, 2.0, 0.04), window_mat)
	make_cylinder(self, Vector3(0.0, 5.25, -6.5), 0.55, 0.05, Color("#b94b5f"))
	make_arch(Vector3(-6.0, 0.0, -5.25), 2.6, 3.8, tower_mat, Color("#a44a61"))
	make_arch(Vector3(6.0, 0.0, -5.25), 2.6, 4.2, tower_mat, Color("#8750a6"))

func make_arch(position: Vector3, width: float, height: float, material: Material, window_color: Color) -> void:
	make_box(self, position + Vector3(-width * 0.5, height * 0.5, 0.0), Vector3(0.35, height, 0.55), material)
	make_box(self, position + Vector3(width * 0.5, height * 0.5, 0.0), Vector3(0.35, height, 0.55), material)
	make_box(self, position + Vector3(0.0, height, 0.0), Vector3(width + 0.35, 0.35, 0.55), material)
	make_box(self, position + Vector3(0.0, height * 0.52, 0.29), Vector3(width * 0.42, height * 0.62, 0.035), make_material(window_color, 0.32, 0.05, window_color))
	make_cone(self, position + Vector3(0.0, height + 0.75, 0.0), width * 0.28, 1.5, material)

func make_parapet_rail() -> void:
	var rail_mat := make_material(Color("#536681"), 0.55, 0.25)
	for i in range(8):
		var x := -7.5 + float(i) * 1.8
		make_box(self, Vector3(x, 1.55, -3.8), Vector3(0.12, 1.25, 0.12), rail_mat)
	make_box(self, Vector3(-1.2, 2.12, -3.8), Vector3(14.6, 0.12, 0.12), rail_mat)
	make_box(self, Vector3(-1.2, 1.45, -3.8), Vector3(14.6, 0.08, 0.08), rail_mat)

func make_perch() -> void:
	var perch_mat := make_material(Color("#554361"), 0.7, 0.05)
	var face_mat := make_material(Color("#30283f"), 0.86)
	make_box(self, PERCH_POSITION, Vector3(4.2, 0.35, 2.9), perch_mat)
	make_box(self, PERCH_POSITION + Vector3(0.0, -0.9, 0.0), Vector3(3.1, 1.5, 0.35), face_mat)
	make_box(self, PERCH_POSITION + Vector3(-1.6, -1.0, 0.0), Vector3(0.25, 2.0, 0.25), face_mat)
	make_box(self, PERCH_POSITION + Vector3(1.6, -1.0, 0.0), Vector3(0.25, 2.0, 0.25), face_mat)
	make_label("ELEVATED PERCH", PERCH_POSITION + Vector3(-1.1, 1.25, 0.0), Color("#c49ad2"))

func make_anchor() -> void:
	var gold := make_material(Color("#d7a34f"), 0.25, 0.1, Color("#d7a34f"))
	make_cylinder(self, ANCHOR_POSITION, 0.3, 0.12, gold)
	make_sphere(self, ANCHOR_POSITION + Vector3(0.0, 0.35, 0.0), 0.17, gold)
	grapple_anchor_light = OmniLight3D.new()
	grapple_anchor_light.position = ANCHOR_POSITION + Vector3(0.0, 0.7, 0.0)
	grapple_anchor_light.light_color = Color("#e6b968")
	grapple_anchor_light.light_energy = 2.2
	grapple_anchor_light.omni_range = 4.5
	add_child(grapple_anchor_light)
	grapple_prompt = make_label("ENTER GOLD RING", ANCHOR_POSITION + Vector3(0.35, 0.55, 0.0), Color("#b99d67"))

	# The dashed ring exposes the exact activation rule without adding a HUD meter.
	grapple_range_root = Node3D.new()
	grapple_range_root.position = Vector3(ANCHOR_POSITION.x, 0.035, ANCHOR_POSITION.z)
	add_child(grapple_range_root)
	grapple_ring_material = make_material(Color("#806a3e"), 0.45, 0.05, Color("#806a3e"))
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		var segment := make_box(
			grapple_range_root,
			Vector3(cos(angle) * GRAPPLE_RANGE, 0.0, sin(angle) * GRAPPLE_RANGE),
			Vector3(0.46, 0.025, 0.075),
			grapple_ring_material
		)
		segment.rotation.y = PI * 0.5 - angle

	# Beads make the real-height destination legible from the fixed camera.
	grapple_route_material = make_material(Color("#caa659"), 0.3, 0.05, Color("#caa659"))
	for index in range(1, 9):
		var route_t := float(index) / 9.0
		make_sphere(self, ANCHOR_POSITION.lerp(PERCH_POSITION, route_t) + Vector3(0.0, 0.09, 0.0), 0.075, grapple_route_material)

func make_hide_spot() -> void:
	var dark := make_material(Color("#0b1220", 0.9), 0.92)
	make_cylinder(self, HIDE_POSITION, 2.0, 0.06, dark)
	make_label("DARKNESS", HIDE_POSITION + Vector3(-0.7, 0.1, 0.0), Color("#9eafd0"))
	make_cylinder(self, TAKEDOWN_SHADOW_POSITION, TAKEDOWN_SHADOW_RADIUS, 0.055, dark)
	make_label("AMBUSH SHADOW // T BEHIND PATROL", TAKEDOWN_SHADOW_POSITION + Vector3(-1.2, 0.1, 0.0), Color("#9eafd0"))

func make_low_passage() -> void:
	var passage_stone := make_material(Color("#222d40"), 0.78)
	var lintel := make_material(Color("#3c4d65"), 0.62, 0.08)
	var center := Vector3(
		(LOW_PASSAGE_MIN.x + LOW_PASSAGE_MAX.x) * 0.5,
		0.0,
		(LOW_PASSAGE_MIN.y + LOW_PASSAGE_MAX.y) * 0.5
	)
	var half_width := (LOW_PASSAGE_MAX.x - LOW_PASSAGE_MIN.x) * 0.5
	make_box(self, center + Vector3(-half_width - 0.12, 1.0, 0.0), Vector3(0.24, 2.0, 1.55), passage_stone)
	make_box(self, center + Vector3(half_width + 0.12, 1.0, 0.0), Vector3(0.24, 2.0, 1.55), passage_stone)
	make_box(self, center + Vector3(0.0, LOW_PASSAGE_CLEARANCE + 0.12, 0.0), Vector3(half_width * 2.0 + 0.48, 0.24, 1.55), lintel)
	make_label("Q CROUCH // LOW PASSAGE", center + Vector3(-0.95, 2.58, 0.0), Color("#9eb4cf"))

func make_vault_obstacle() -> void:
	var stone := make_material(Color("#39475c"), 0.66, 0.12)
	var cap := make_material(Color("#60708a"), 0.46, 0.24)
	make_box(self, VAULT_OBSTACLE_CENTER, Vector3(VAULT_OBSTACLE_HALF_EXTENTS.x * 2.0, 0.84, VAULT_OBSTACLE_HALF_EXTENTS.y * 2.0), stone)
	make_box(self, VAULT_OBSTACLE_CENTER + Vector3(0.0, 0.47, 0.0), Vector3(VAULT_OBSTACLE_HALF_EXTENTS.x * 2.0 + 0.10, 0.10, VAULT_OBSTACLE_HALF_EXTENTS.y * 2.0 + 0.10), cap)
	make_label("V JUMP / VAULT", VAULT_OBSTACLE_CENTER + Vector3(-0.75, 1.15, 0.0), Color("#aebed4"))

func make_exit() -> void:
	var violet := make_material(Color("#8256b6"), 0.4, 0.1, Color("#6f4a9e"))
	var gate := make_material(Color("#17182a"), 0.75)
	make_box(self, EXIT_POSITION + Vector3(-1.2, 1.6, 0.0), Vector3(0.22, 3.2, 0.35), violet)
	make_box(self, EXIT_POSITION + Vector3(1.2, 1.6, 0.0), Vector3(0.22, 3.2, 0.35), violet)
	make_box(self, EXIT_POSITION + Vector3(0.0, 3.1, 0.0), Vector3(2.6, 0.22, 0.35), violet)
	for x in [-0.7, -0.25, 0.25, 0.7]:
		make_box(self, EXIT_POSITION + Vector3(x, 1.5, 0.0), Vector3(0.09, 2.7, 0.38), gate)
	make_label("EXIT", EXIT_POSITION + Vector3(-0.35, 3.65, 0.0), Color("#c49bea"))
	# Two near parapet posts create a foreground frame without blocking the route.
	for post_x in [-8.7, 8.7]:
		make_box(self, Vector3(post_x, 1.1, 4.7), Vector3(0.45, 2.2, 0.45), make_material(Color("#29374c"), 0.8))
		make_cone(self, Vector3(post_x, 2.65, 4.7), 0.52, 1.1, make_material(Color("#3d4d65"), 0.72))

func make_lamps() -> void:
	for lamp_position in [Vector3(-8.7, 2.5, 1.0), Vector3(7.7, 2.5, 2.9)]:
		var warm := make_material(Color("#dca55b"), 0.3, 0.0, Color("#dca55b"))
		make_box(self, lamp_position - Vector3(0.0, 1.3, 0.0), Vector3(0.12, 2.6, 0.12), make_material(Color("#262c3b"), 0.8))
		make_sphere(self, lamp_position, 0.19, warm)
		var light := OmniLight3D.new()
		light.position = lamp_position
		light.light_color = Color("#e7b866")
		light.light_energy = 3.0
		light.omni_range = 5.0
		add_child(light)

func make_rain() -> void:
	var rain_mat := make_material(Color("#8ca8c8", 0.32), 0.4)
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(34):
		var x := -10.0 + fmod(float(i * 37), 20.0)
		var z := -5.5 + fmod(float(i * 23), 11.0)
		var y := 2.0 + fmod(float(i * 19), 6.0)
		var drop := make_box(self, Vector3(x, y, z), Vector3(0.018, 0.8, 0.018), rain_mat)
		drop.rotation_degrees.z = -12.0

func build_player() -> void:
	player_root = Node3D.new()
	player_root.name = "OriginalGloamVigil"
	add_child(player_root)
	player_visual_parts = CharacterVisualBuilder.build_player(player_root, outfit_colors[outfit_index])
	player_accent_material = player_visual_parts["accent_material"]
	make_label("YOU", Vector3(0.0, 2.55, 0.0), Color("#e2e6f2"), player_root)
	impact_light = OmniLight3D.new()
	impact_light.position = Vector3(0.0, 1.2, 0.0)
	impact_light.light_color = Color("#d75b68")
	impact_light.light_energy = 0.0
	impact_light.omni_range = 3.0
	player_root.add_child(impact_light)
	counter_light = OmniLight3D.new()
	counter_light.position = Vector3(0.0, 1.7, 0.0)
	counter_light.light_color = Color("#f2d276")
	counter_light.light_energy = 0.0
	counter_light.omni_range = 3.5
	player_root.add_child(counter_light)

func build_guard() -> void:
	guard_root = Node3D.new()
	guard_root.name = "PatrollingCourtyardWarden"
	add_child(guard_root)
	guard_visual_parts = CharacterVisualBuilder.build_guard(guard_root)
	guard_label = make_label("GUARD 100", Vector3(-0.65, 2.85, 0.0), Color("#f07a72"), guard_root)
	attack_marker = make_label("", Vector3(-0.7, 3.25, 0.0), Color("#f2db83"), guard_root)
	attack_marker.visible = false
	var guard_glow := OmniLight3D.new()
	guard_glow.position = Vector3(0.0, 1.4, 0.0)
	guard_glow.light_color = Color("#a94552")
	guard_glow.light_energy = 0.35
	guard_glow.omni_range = 2.8
	guard_root.add_child(guard_glow)
	vision_mesh = make_vision_wedge(guard_root)

func make_vision_wedge(parent: Node3D) -> MeshInstance3D:
	var immediate := ImmediateMesh.new()
	var mat := make_material(Color("#d5a35b", 0.16), 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	immediate.surface_add_vertex(Vector3(0.0, 0.06, 0.0))
	immediate.surface_add_vertex(Vector3(-2.7, 0.06, 5.7))
	immediate.surface_add_vertex(Vector3(2.7, 0.06, 5.7))
	immediate.surface_end()
	var instance := MeshInstance3D.new()
	instance.name = "VisibleVisionRegion"
	instance.mesh = immediate
	parent.add_child(instance)
	return instance

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.size = Vector2(960.0, 600.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 16.0)
	panel.size = Vector2(390.0, 134.0)
	panel.color = Color("#0a101d", 0.78)
	root.add_child(panel)
	var accent_line := ColorRect.new()
	accent_line.position = Vector2(18.0, 16.0)
	accent_line.size = Vector2(2.0, 134.0)
	accent_line.color = Color("#b26a62", 0.8)
	root.add_child(accent_line)
	add_ui_label(root, "GLOAM // LOWER COURT", Vector2(32.0, 25.0), Vector2(350.0, 24.0), 18, Color("#e5e8f1"))
	add_ui_label(root, "WASD run   Q crouch   V jump/vault", Vector2(32.0, 50.0), Vector2(380.0, 18.0), 10, Color("#c1cade"))
	add_ui_label(root, "SPACE hit   C evade   E counter   T takedown   R restart", Vector2(32.0, 69.0), Vector2(400.0, 18.0), 10, Color("#c1cade"))
	add_ui_label(root, "1/2/3 body build   X accent color", Vector2(32.0, 88.0), Vector2(360.0, 18.0), 12, Color("#99a8c5"))
	add_ui_label(root, "F12 capture   J/L orbit  I/K pitch  -/= zoom  0 reset", Vector2(32.0, 107.0), Vector2(360.0, 18.0), 10, Color("#99a8c5"))
	var status_panel := ColorRect.new()
	status_panel.position = Vector2(648.0, 14.0)
	status_panel.size = Vector2(292.0, 88.0)
	status_panel.color = Color("#0a101d", 0.78)
	root.add_child(status_panel)
	add_ui_label(root, "HEALTH", Vector2(672.0, 24.0), Vector2(65.0, 20.0), 12, Color("#c8d1e2"))
	health_bar = make_bar(root, Vector2(742.0, 22.0), Color("#63c391"))
	add_ui_label(root, "MOMENTUM", Vector2(672.0, 56.0), Vector2(70.0, 20.0), 12, Color("#c8d1e2"))
	momentum_bar = make_bar(root, Vector2(742.0, 54.0), Color("#d7a752"))
	objective_label = add_ui_label(root, "OBJECTIVE: guard and exit", Vector2(672.0, 82.0), Vector2(250.0, 18.0), 11, Color("#b48bd2"))
	var message_panel := ColorRect.new()
	message_panel.position = Vector2(240.0, 540.0)
	message_panel.size = Vector2(480.0, 40.0)
	message_panel.color = Color("#101728", 0.9)
	root.add_child(message_panel)
	message_label = add_ui_label(root, message, Vector2(258.0, 551.0), Vector2(445.0, 20.0), 14, Color("#eef0f8"))

func add_ui_label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func make_bar(parent: Control, position: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = position
	bar.size = Vector2(174.0, 16.0)
	bar.max_value = 100.0
	bar.show_percentage = true
	bar.add_theme_color_override("font_color", Color("#dce3f0"))
	bar.add_theme_color_override("font_outline_color", Color("#080b13"))
	bar.add_theme_constant_override("outline_size", 4)
	parent.add_child(bar)
	return bar

func reset_game() -> void:
	held_keys.clear()
	player_root.position = PLAYER_START
	player_root.scale = Vector3.ONE * (PLAYER_BASE_SCALE * player_scale)
	guard_root.position = GUARD_START
	guard_root.scale = Vector3.ONE * GUARD_BASE_SCALE
	guard_forward = Vector3(1.0, 0.0, 0.0)
	guard_root.rotation.y = atan2(guard_forward.x, guard_forward.z)
	player_health = 100.0
	momentum = 0.0
	guard_health = 100.0
	guard_suspicion = 0.0
	guard_alert = false
	guard_defeated = false
	guard_patrol_index = 0
	attack_timer = 0.0
	attack_cooldown = 0.0
	guard_stun = 0.0
	guard_stun_duration = 0.0
	guard_reaction_side = 1.0
	attack_countered = false
	player_strike_timer = 0.0
	player_strike_pending = false
	player_attack_variant = PlayerAttackCatalog.RIGHT_PUNCH
	player_attack_duration = PLAYER_STRIKE_DURATION
	player_attack_contact = PLAYER_STRIKE_CONTACT
	player_attack_reach = 2.20
	player_attack_target_locked = false
	player_attack_contact_connected = false
	player_attack_presentation_only = false
	player_attack_buffered = false
	player_attack_last_variant = &""
	player_takedown_timer = 0.0
	player_takedown_pending = false
	player_counter_timer = 0.0
	player_hurt_timer = 0.0
	player_downed_elapsed = 0.0
	guard_defeat_elapsed = 0.0
	grapple_active = false
	grapple_t = 0.0
	grapple_recovery_timer = 0.0
	player_on_perch = false
	player_airborne = false
	vertical_velocity = 0.0
	player_facing_yaw = 0.0
	player_step_phase = 0.0
	guard_step_phase = 0.0
	player_move_timer = 0.0
	player_moved_this_frame = false
	player_move_blend = 0.0
	player_run_blend = 1.0
	guard_move_blend = 0.0
	guard_is_moving = false
	invulnerable = 0.0
	evade_timer = 0.0
	evade_direction = Vector3.ZERO
	last_travel_direction = Vector3(0.0, 0.0, 1.0)
	crouching = false
	jump_active = false
	jump_is_vault = false
	jump_t = 0.0
	jump_duration = JUMP_DURATION
	jump_height = JUMP_HEIGHT
	jump_start = Vector3.ZERO
	jump_end = Vector3.ZERO
	impact_flash_timer = 0.0
	counter_flash_timer = 0.0
	player_root.rotation = Vector3.ZERO
	reset_camera()
	success = false
	message = "Slip through the dark. Reach the violet gate."
	message_timer = 4.0
	attack_marker.visible = false
	vision_mesh.visible = true
	guard_visual_parts["visual_root"].visible = true
	guard_label.visible = true
	set_guard_visual_fade(0.0)
	CharacterVisualBuilder.pose_player(player_visual_parts, 0.0, 0.0, 1.0)
	CharacterVisualBuilder.pose_guard(guard_visual_parts, 0.0, 0.0, 1.0)
	update_hud()

func _process(delta: float) -> void:
	if success:
		update_camera(delta)
		update_hud()
		return
	message_timer = maxf(message_timer - delta, 0.0)
	invulnerable = maxf(invulnerable - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	guard_stun = maxf(guard_stun - delta, 0.0)
	player_counter_timer = maxf(player_counter_timer - delta, 0.0)
	player_hurt_timer = maxf(player_hurt_timer - delta, 0.0)
	if player_health <= 0.0:
		player_downed_elapsed = minf(player_downed_elapsed + delta, PLAYER_DOWNED_DURATION)
	impact_flash_timer = maxf(impact_flash_timer - delta, 0.0)
	counter_flash_timer = maxf(counter_flash_timer - delta, 0.0)
	if player_health <= 0.0:
		update_feedback()
		update_camera(delta)
		update_character_poses(delta)
		update_hud()
		return
	player_move_timer = maxf(player_move_timer - delta, 0.0)
	grapple_recovery_timer = maxf(grapple_recovery_timer - delta, 0.0)
	update_feedback()
	update_grapple_feedback()
	update_camera(delta)
	player_moved_this_frame = false
	move_player(delta)
	update_player_actions(delta)
	update_guard(delta)
	update_guard_defeat(delta)
	update_character_poses(delta)
	check_success()
	update_hud()

func update_camera(delta: float) -> void:
	var orbit_right := 1.0 if held_keys.get(KEY_RIGHT, false) or held_keys.get(KEY_L, false) else 0.0
	var orbit_left := 1.0 if held_keys.get(KEY_LEFT, false) or held_keys.get(KEY_J, false) else 0.0
	var pitch_down := 1.0 if held_keys.get(KEY_DOWN, false) or held_keys.get(KEY_K, false) else 0.0
	var pitch_up := 1.0 if held_keys.get(KEY_UP, false) or held_keys.get(KEY_I, false) else 0.0
	var zoom_direction := Input.get_axis("camera_zoom_in", "camera_zoom_out")
	camera_yaw += (orbit_right - orbit_left) * CAMERA_ORBIT_SPEED * delta
	camera_pitch = clampf(camera_pitch + (pitch_down - pitch_up) * 0.8 * delta, 0.30, 0.64)
	camera.size = clampf(camera.size + zoom_direction * CAMERA_ZOOM_SPEED * delta, CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)
	var horizontal := Vector2(sin(camera_yaw), cos(camera_yaw)) * camera_distance
	camera.position = CAMERA_TARGET + Vector3(horizontal.x, tan(camera_pitch) * camera_distance, horizontal.y)
	camera.look_at(CAMERA_TARGET, Vector3.UP)

func reset_camera() -> void:
	camera_yaw = CAMERA_DEFAULT_YAW
	camera_pitch = CAMERA_DEFAULT_PITCH
	camera_distance = CAMERA_DEFAULT_DISTANCE
	if camera != null:
		camera.size = CAMERA_DEFAULT_SIZE
		var horizontal := Vector2(sin(camera_yaw), cos(camera_yaw)) * camera_distance
		camera.position = CAMERA_TARGET + Vector3(horizontal.x, tan(camera_pitch) * camera_distance, horizontal.y)
		camera.look_at(CAMERA_TARGET, Vector3.UP)

func move_player(delta: float) -> void:
	if player_takedown_timer > 0.0:
		# A short real approach, through the usual blockers and personal space;
		# never teleport either actor into a staged takedown position.
		if player_takedown_pending:
			var to_guard := guard_root.position - player_root.position
			to_guard.y = 0.0
			var approach := maxf(to_guard.length() - minimum_actor_separation(), 0.0)
			if approach > 0.001:
				move_player_world(to_guard.normalized(), minf(approach, delta * 2.8))
		face_player_toward_guard()
		return
	if grapple_active:
		grapple_t = minf(grapple_t + delta / 0.32, 1.0)
		var perch_landing := Vector3(PERCH_POSITION.x, PERCH_TOP_Y, PERCH_POSITION.z)
		var grapple_progress := grappler_ease(grapple_t)
		player_root.position = grapple_start.lerp(perch_landing, grapple_progress)
		# Lift the actor above the near lip before converging on the exact landing.
		# A straight interpolation put the visible body through the platform even
		# though the accepted duration and destination were mechanically correct.
		player_root.position.y += sin(grapple_t * PI) * 1.75
		if grapple_t >= 1.0:
			grapple_active = false
			grapple_recovery_timer = 0.32
			player_on_perch = true
			player_airborne = false
			vertical_velocity = 0.0
			set_message("LANDED: elevated perch.", 1.6)
		return
	if jump_active:
		jump_t = minf(jump_t + delta / jump_duration, 1.0)
		var horizontal_progress := smoothstep(0.0, 1.0, jump_t)
		player_root.position = jump_start.lerp(jump_end, horizontal_progress)
		player_root.position.y = lerpf(jump_start.y, jump_end.y, horizontal_progress) + sin(jump_t * PI) * jump_height
		if jump_t >= 1.0:
			jump_active = false
			player_airborne = false
			player_root.position = jump_end
			if not guard_defeated and actors_share_level(player_root.position.y, guard_root.position.y):
				player_root.position = resolve_actor_separation(player_root.position, jump_start, guard_root.position, minimum_actor_separation())
			set_message("VAULT LANDED: route cleared." if jump_is_vault else "JUMP LANDED: footing recovered.", 1.0)
		return
	if invulnerable > 0.0 or evade_timer > 0.0:
		# Integrate the last partial movement frame too. Held/tap locomotion
		# cannot add a second displacement or steer the committed roll.
		var roll_step := minf(delta, evade_timer)
		evade_timer = maxf(evade_timer - delta, 0.0)
		move_player_world(evade_direction, 7.0 * roll_step)
		player_facing_yaw = atan2(evade_direction.x, evade_direction.z)
		player_root.rotation = Vector3(0.0, player_facing_yaw, 0.0)
		update_player_vertical(delta)
		return
	if player_strike_timer > 0.0:
		# The attack curves author weight transfer around planted feet. Held and
		# tap locomotion cannot translate the gameplay root until recovery ends.
		update_player_vertical(delta)
		return
	var input := get_move_input()
	# One standing locomotion policy: ordinary WASD uses the accepted captured
	# run at its native controller speed. Shift is intentionally ignored.
	player_run_blend = 1.0
	if input.length() > 0.01:
		var direction := camera.global_transform.basis.x * input.x - camera.global_transform.basis.z * input.y
		direction.y = 0.0
		if direction.length() > 0.01:
			var move_speed := CROUCH_MOVE_SPEED if crouching else PLAYER_MOVE_SPEED
			move_player_world(direction.normalized(), move_speed * delta)
		var anatomical_motion := player_visual_parts.has("authored_rig") \
			and bool(player_visual_parts["authored_rig"].get("anatomical_profile", false))
		if anatomical_motion:
			# Keep the gameplay root upright. The R7 clip now carries its small running
			# pitch through the articulated spine, so the old whole-body tilt no longer
			# makes starts or camera-relative turns look like a rigid forward lean.
			player_root.rotation.x = lerpf(player_root.rotation.x, 0.0, minf(delta * 10.0, 1.0))
			player_root.rotation.z = lerpf(player_root.rotation.z, 0.0, minf(delta * 10.0, 1.0))
		else:
			player_root.rotation.x = lerpf(player_root.rotation.x, -input.y * 0.07, minf(delta * 10.0, 1.0))
			player_root.rotation.z = lerpf(player_root.rotation.z, -input.x * 0.09, minf(delta * 10.0, 1.0))
	else:
		player_root.rotation.x = lerpf(player_root.rotation.x, 0.0, minf(delta * 8.0, 1.0))
		player_root.rotation.z = lerpf(player_root.rotation.z, 0.0, minf(delta * 8.0, 1.0))
	update_player_vertical(delta)

func get_move_input() -> Vector2:
	var right := 1.0 if held_keys.get(KEY_D, false) else 0.0
	var left := 1.0 if held_keys.get(KEY_A, false) else 0.0
	var down := 1.0 if held_keys.get(KEY_S, false) else 0.0
	var up := 1.0 if held_keys.get(KEY_W, false) else 0.0
	return Vector2(right - left, down - up).limit_length(1.0)

func move_player_world(direction: Vector3, distance: float) -> void:
	var previous_position := player_root.position
	var candidate := player_root.position + direction * distance
	candidate.x = clampf(candidate.x, -9.1, 9.1)
	candidate.z = clampf(candidate.z, -5.2, 5.2)
	if not crouching and is_in_low_passage(candidate) and not is_in_low_passage(previous_position):
		candidate = previous_position
		set_message("LOW CLEARANCE: Q to crouch before entering.", 1.2)
	if not jump_active and is_inside_vault_obstacle(candidate) and not is_inside_vault_obstacle(previous_position):
		candidate = previous_position
		set_message("LOW BARRIER: V to vault or route around.", 1.2)
	if not guard_defeated and actors_share_level(candidate.y, guard_root.position.y):
		candidate = resolve_actor_separation(
			candidate,
			player_root.position,
			guard_root.position,
			minimum_actor_separation()
		)
	player_root.position.x = candidate.x
	player_root.position.z = candidate.z
	var actual_motion := player_root.position - previous_position
	actual_motion.y = 0.0
	if actual_motion.length() > 0.002:
		player_moved_this_frame = true
		last_travel_direction = actual_motion.normalized()
		player_facing_yaw = atan2(last_travel_direction.x, last_travel_direction.z)
		player_move_timer = 0.16
	if player_on_perch and not is_over_perch(player_root.position, 0.20):
		player_on_perch = false
		player_airborne = true
		vertical_velocity = 0.0
		set_message("FALLING: the Vigil clears the perch edge.", 1.0)

func is_in_low_passage(position: Vector3) -> bool:
	return position.y < 0.5 \
		and position.x >= LOW_PASSAGE_MIN.x and position.x <= LOW_PASSAGE_MAX.x \
		and position.z >= LOW_PASSAGE_MIN.y and position.z <= LOW_PASSAGE_MAX.y

func is_inside_vault_obstacle(position: Vector3) -> bool:
	return position.y < 0.9 \
		and absf(position.x - VAULT_OBSTACLE_CENTER.x) <= VAULT_OBSTACLE_HALF_EXTENTS.x \
		and absf(position.z - VAULT_OBSTACLE_CENTER.z) <= VAULT_OBSTACLE_HALF_EXTENTS.y

func path_intersects_vault_obstacle(start: Vector3, finish: Vector3) -> bool:
	for index in range(1, 21):
		var sample := start.lerp(finish, float(index) / 20.0)
		if is_inside_vault_obstacle(sample):
			return true
	return false


func update_player_vertical(delta: float) -> void:
	if jump_active:
		return
	if player_on_perch:
		player_root.position.y = PERCH_TOP_Y
		return
	if not player_airborne:
		return
	var previous_y := player_root.position.y
	vertical_velocity -= FALL_GRAVITY * delta
	player_root.position.y += vertical_velocity * delta
	if vertical_velocity <= 0.0 and is_over_perch(player_root.position, 0.12) and previous_y >= PERCH_TOP_Y and player_root.position.y <= PERCH_TOP_Y:
		player_root.position.y = PERCH_TOP_Y
		player_on_perch = true
		player_airborne = false
		vertical_velocity = 0.0
		set_message("LANDED: footing recovered on the perch.", 1.0)
	elif player_root.position.y <= 0.0:
		player_root.position.y = 0.0
		player_airborne = false
		vertical_velocity = 0.0
		if actors_share_level(player_root.position.y, guard_root.position.y):
			player_root.position = resolve_actor_separation(
				player_root.position,
				player_root.position,
				guard_root.position,
				minimum_actor_separation()
			)
		set_message("LANDED: courtyard floor.", 1.0)

func update_guard(delta: float) -> void:
	guard_is_moving = false
	if guard_defeated:
		return
	guard_label.text = "GUARD %d" % int(maxf(guard_health, 0.0))
	if player_takedown_timer > 0.0:
		return
	if attack_timer > 0.0:
		attack_timer = maxf(attack_timer - delta, 0.0)
		attack_marker.text = "PERFECT" if attack_timer > 0.30 and attack_timer < 0.56 else "BLOCK"
		if attack_timer == 0.0 and not attack_countered:
			if actors_share_level(player_root.position.y, guard_root.position.y) and flat_distance(player_root.position, guard_root.position) < 2.2:
				damage_player(18.0, "The guard's blade breaks your momentum.")
			else:
				set_message("The guard's blade cuts through empty air.", 0.9)
			attack_cooldown = 1.0
			attack_countered = false
		attack_marker.visible = false
		return
	if guard_stun > 0.0:
		return
	var to_player := player_root.position - guard_root.position
	to_player.y = 0.0
	var distance := to_player.length()
	var forward := Vector3(sin(guard_root.rotation.y), 0.0, cos(guard_root.rotation.y))
	var sees_player := actors_share_level(player_root.position.y, guard_root.position.y) and distance > 0.01 and distance < 7.0 and forward.dot(to_player.normalized()) > 0.38 and not is_concealed()
	if sees_player:
		guard_suspicion = minf(guard_suspicion + delta * 45.0, 100.0)
	else:
		guard_suspicion = maxf(guard_suspicion - delta * 16.0, 0.0)
	if guard_suspicion >= 100.0:
		guard_alert = true
		set_message("ALERT: close distance, evade or counter.", 2.0)
	var target: Vector3 = player_root.position if guard_alert else PATROL_POINTS[guard_patrol_index]
	var to_target := target - guard_root.position
	to_target.y = 0.0
	if actors_share_level(player_root.position.y, guard_root.position.y) and distance < 1.8 and guard_alert and attack_cooldown <= 0.0:
		attack_timer = 0.72
		attack_countered = false
		attack_marker.visible = true
		set_message("COUNTER WINDOW: E. Perfect is the narrow center flash.", 1.3)
		return
	if to_target.length() > 0.15:
		guard_forward = guard_forward.lerp(to_target.normalized(), minf(delta * 5.0, 1.0)).normalized()
		guard_root.rotation.y = atan2(guard_forward.x, guard_forward.z)
		move_guard_world(guard_forward, (2.5 if guard_alert else 1.35) * delta)
	elif not guard_alert:
		guard_patrol_index = (guard_patrol_index + 1) % PATROL_POINTS.size()
	guard_label.text = "GUARD %d" % int(maxf(guard_health, 0.0))


func move_guard_world(direction: Vector3, distance: float) -> void:
	var previous_position := guard_root.position
	var candidate := guard_root.position + direction * distance
	candidate.x = clampf(candidate.x, -9.1, 9.1)
	candidate.z = clampf(candidate.z, -5.2, 5.2)
	if actors_share_level(candidate.y, player_root.position.y):
		candidate = resolve_actor_separation(
			candidate,
			guard_root.position,
			player_root.position,
			minimum_actor_separation()
		)
	guard_root.position = candidate
	guard_is_moving = flat_distance(previous_position, guard_root.position) > 0.002


func update_character_poses(delta: float) -> void:
	player_root.rotation.y = lerp_angle(player_root.rotation.y, player_facing_yaw, minf(delta * 14.0, 1.0))
	var anatomical_motion := player_visual_parts.has("authored_rig") \
		and bool(player_visual_parts["authored_rig"].get("anatomical_profile", false))
	# The legacy timer intentionally cushions V1/V2's procedural step. For R7 it
	# left a full run pose playing after the gameplay root had stopped. Drive the
	# captured gait from actual displacement in this frame instead.
	var has_locomotion := player_moved_this_frame if anatomical_motion else player_move_timer > 0.0
	var player_target := 1.0 if has_locomotion and not grapple_active and not player_airborne else 0.0
	var player_was_stationary := player_move_blend <= 0.001
	var blend_rate := 12.0 if anatomical_motion else 7.5
	player_move_blend = move_toward(player_move_blend, player_target, delta * blend_rate)
	# Start the captured stride at a real right-foot contact instead of whichever
	# arbitrary idle phase happened to be running when input began.
	if anatomical_motion and player_target > 0.5 and player_was_stationary:
		player_step_phase = 0.0
	# Standing movement uses the corrected captured run cadence. The walk source
	# remains archived/provenanced, but no longer participates in runtime control.
	var player_walk_rate := 9.0 if evade_timer > 0.0 else (9.4 if crouching and anatomical_motion else (R7RunReference.cycle_rate() if anatomical_motion else 7.2))
	player_step_phase += delta * lerpf(1.15, player_walk_rate, player_move_blend)
	var player_pose: StringName = &"grounded"
	var player_pose_progress := 0.0
	if player_health <= 0.0:
		player_pose = &"downed"
		player_pose_progress = player_downed_elapsed / PLAYER_DOWNED_DURATION
	elif player_takedown_timer > 0.0:
		player_pose = &"takedown"
		player_pose_progress = 1.0 - player_takedown_timer / PLAYER_TAKEDOWN_DURATION
	elif grapple_active:
		player_pose = &"grapple"
		player_pose_progress = grapple_t
	elif grapple_recovery_timer > 0.0:
		player_pose = &"grapple_recover"
		player_pose_progress = 1.0 - grapple_recovery_timer / 0.32
	elif jump_active:
		player_pose = &"vault" if jump_is_vault else &"jump"
		player_pose_progress = jump_t
	elif invulnerable > 0.0:
		player_pose = &"evade"
		player_pose_progress = 1.0 - invulnerable / EVADE_INVULNERABILITY_DURATION
	elif player_airborne:
		player_pose = &"fall"
	elif player_hurt_timer > 0.0:
		player_pose = &"hurt"
		player_pose_progress = 1.0 - player_hurt_timer / PLAYER_HURT_DURATION
	elif player_counter_timer > 0.0:
		player_pose = &"counter"
		player_pose_progress = 1.0 - player_counter_timer / PLAYER_COUNTER_DURATION
	elif player_strike_timer > 0.0:
		player_pose = &"strike"
		player_pose_progress = 1.0 - player_strike_timer / player_attack_duration
	elif crouching:
		player_pose = &"crouch"
		player_pose_progress = player_move_blend
	var player_pose_delta := delta
	if player_pose == &"crouch" and player_visual_parts.has("authored_rig") and is_in_low_passage(player_root.position):
		# Collision grants low clearance immediately. Constrain the visual to the
		# measured low pose inside the lintel; retain natural easing in open space.
		player_pose_delta = 1.0
	CharacterVisualBuilder.pose_player(player_visual_parts, player_step_phase, player_move_blend, player_pose_delta, player_pose, player_pose_progress, player_attack_variant, player_run_blend)

	var guard_target := 1.0 if guard_is_moving else 0.0
	guard_move_blend = move_toward(guard_move_blend, guard_target, delta * 6.5)
	var guard_walk_rate := 7.4 if guard_alert else 5.8
	guard_step_phase += delta * lerpf(0.9, guard_walk_rate, guard_move_blend)
	var guard_pose: StringName = &"grounded"
	var guard_pose_progress := 0.0
	if player_takedown_timer > 0.0:
		guard_pose = &"takedown_victim"
		guard_pose_progress = 1.0 - player_takedown_timer / PLAYER_TAKEDOWN_DURATION
	elif guard_defeated:
		guard_pose = &"defeated"
		guard_pose_progress = minf(guard_defeat_elapsed / GUARD_DEFEAT_DURATION, 1.0)
	elif guard_stun > 0.0:
		guard_pose = &"stagger"
		guard_pose_progress = 1.0 - guard_stun / maxf(guard_stun_duration, 0.001)
	elif attack_timer > 0.0:
		guard_pose = &"attack"
		guard_pose_progress = 1.0 - attack_timer / 0.72
	CharacterVisualBuilder.pose_guard(
		guard_visual_parts,
		guard_step_phase,
		guard_move_blend,
		delta,
		guard_pose,
		guard_pose_progress,
		guard_reaction_side
	)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed:
		held_keys[key.keycode] = true
		if key.echo:
			return
		if event.is_action_pressed("camera_zoom_out"):
			camera.size = minf(camera.size + 1.0, CAMERA_MAX_SIZE)
		elif event.is_action_pressed("camera_zoom_in"):
			camera.size = maxf(camera.size - 1.0, CAMERA_MIN_SIZE)
		var terminal_key_allowed := key.keycode in [
			KEY_R, KEY_F12, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
			KEY_I, KEY_J, KEY_K, KEY_L, KEY_0,
		]
		if (success or player_health <= 0.0) and not terminal_key_allowed:
			return
		match key.keycode:
			KEY_W, KEY_A, KEY_S, KEY_D:
				# Held input is integrated by move_player. The former 0.42-unit press
				# teleport made the first walk frame cover a quarter second of travel.
				pass
			KEY_R:
				reset_game()
			KEY_SPACE:
				strike()
			KEY_E:
				counter()
			KEY_C:
				evade()
			KEY_Q:
				toggle_crouch()
			KEY_V:
				jump_or_vault()
			KEY_T:
				stealth_takedown()
			KEY_G:
				grapple()
			KEY_F12:
				capture_screenshot()
			KEY_LEFT, KEY_J:
				camera_yaw -= deg_to_rad(12.0)
			KEY_RIGHT, KEY_L:
				camera_yaw += deg_to_rad(12.0)
			KEY_UP, KEY_I:
				camera_pitch = clampf(camera_pitch - deg_to_rad(5.0), 0.30, 0.64)
			KEY_DOWN, KEY_K:
				camera_pitch = clampf(camera_pitch + deg_to_rad(5.0), 0.30, 0.64)
			KEY_0:
				reset_camera()
			KEY_1:
				player_scale = 0.88
				player_root.scale = Vector3.ONE * (PLAYER_BASE_SCALE * player_scale)
			KEY_2:
				player_scale = 1.0
				player_root.scale = Vector3.ONE * (PLAYER_BASE_SCALE * player_scale)
			KEY_3:
				player_scale = 1.16
				player_root.scale = Vector3.ONE * (PLAYER_BASE_SCALE * player_scale)
			KEY_X:
				outfit_index = (outfit_index + 1) % outfit_colors.size()
				player_accent_material.albedo_color = outfit_colors[outfit_index]
				player_accent_material.emission = outfit_colors[outfit_index]
	else:
		held_keys[key.keycode] = false


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		held_keys.clear()
		player_run_blend = 1.0

func strike() -> void:
	if player_strike_timer > 0.0:
		# One non-repeating press may queue only in the final recovery tenth.
		# Key echo is already rejected by _unhandled_input; earlier mash input is
		# ignored and can neither reset the timer nor stack a second contact.
		if player_strike_timer <= PLAYER_ATTACK_BUFFER_WINDOW and not player_strike_pending:
			player_attack_buffered = true
		return
	if success or player_health <= 0.0 or player_takedown_timer > 0.0 or invulnerable > 0.0 or grapple_active or player_airborne or player_counter_timer > 0.0 or player_hurt_timer > 0.0:
		return
	if crouching and is_in_low_passage(player_root.position):
		set_message("LOW CLEARANCE: leave the passage before striking.", 1.2)
		return
	_begin_strike()

func _begin_strike() -> void:
	var target_context_valid := _attack_target_context_valid(PlayerAttackCatalog.maximum_reach())
	player_attack_presentation_only = guard_defeated or player_on_perch
	var target_distance := 0.0
	var target_lateral := 0.0
	if target_context_valid:
		var to_guard := guard_root.position - player_root.position
		to_guard.y = 0.0
		target_distance = to_guard.length()
		# Selection and target ownership follow the heading the player can actually
		# see, not a desired yaw that may still be interpolating toward the guard.
		if target_distance > 0.001:
			var visible_yaw := player_root.rotation.y
			var facing_right := Vector3(cos(visible_yaw), 0.0, -sin(visible_yaw))
			target_lateral = facing_right.dot(to_guard / target_distance)
	else:
		# Freeze target-free attacks to the heading actually on screen. This
		# prevents a stale locomotion target or remote guard from steering them.
		player_facing_yaw = player_root.rotation.y
	var selected_variant := select_attack_variant(target_distance, target_lateral, target_context_valid)
	_commit_strike_variant(selected_variant, target_context_valid and target_distance <= PlayerAttackCatalog.reach(selected_variant))

func _commit_strike_variant(variant: StringName, target_locked: bool) -> void:
	player_attack_variant = variant if PlayerAttackCatalog.is_valid(variant) else PlayerAttackCatalog.RIGHT_PUNCH
	player_attack_duration = PlayerAttackCatalog.duration(player_attack_variant)
	player_attack_contact = PlayerAttackCatalog.contact_time(player_attack_variant)
	player_attack_reach = PlayerAttackCatalog.reach(player_attack_variant)
	player_strike_timer = player_attack_duration
	player_strike_pending = true
	player_attack_target_locked = target_locked
	player_attack_contact_connected = false
	player_attack_buffered = false
	player_attack_last_variant = player_attack_variant
	player_counter_timer = 0.0
	# Open-space crouch exits into a stable fighting base. Low-clearance crouch is
	# rejected above, so a kick never begins with the support leg folded under it.
	crouching = false
	# Presentation is target-independent. A valid owned target may turn the
	# actor toward contact, but empty space, a defeated guard, and a safe perch
	# preserve the direction the player chose.
	if target_locked:
		face_player_toward_guard()
	set_message("STRIKE: %s." % PlayerAttackCatalog.label(player_attack_variant), 0.6)

func select_attack_variant(target_distance: float, target_lateral: float, target_context_valid: bool) -> StringName:
	var candidates: Array[StringName] = []
	for variant: StringName in PlayerAttackCatalog.ORDER:
		if not target_context_valid or target_distance <= PlayerAttackCatalog.reach(variant):
			candidates.append(variant)
	if candidates.is_empty():
		candidates.assign(PlayerAttackCatalog.ORDER)
	if candidates.size() > 1 and candidates.has(player_attack_last_variant):
		candidates.erase(player_attack_last_variant)

	var weights: Array[float] = []
	var weight_total := 0.0
	var wants_kick := target_distance >= 1.78
	for variant: StringName in candidates:
		var variant_kind := PlayerAttackCatalog.kind(variant)
		# A real target can bias the appropriate reach. With no owned target all
		# four authored motions start neutral, so a remote/dead guard cannot bias
		# the player's empty-space shadowboxing.
		var weight := (2.35 if (variant_kind == &"kick") == wants_kick else 0.72) if target_context_valid else 1.0
		var variant_side := PlayerAttackCatalog.side(variant)
		if absf(target_lateral) > 0.12:
			weight *= 1.55 if signf(target_lateral) == signf(variant_side) else 0.78
		if PlayerAttackCatalog.is_valid(player_attack_last_variant):
			if variant_side != PlayerAttackCatalog.side(player_attack_last_variant):
				weight *= 1.75
			if variant_kind != PlayerAttackCatalog.kind(player_attack_last_variant):
				weight *= 1.18
		weights.append(weight)
		weight_total += weight

	var roll := player_attack_rng.randf() * weight_total
	for index in range(candidates.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()

func update_player_actions(delta: float) -> void:
	var strike_was_active := player_strike_timer > 0.0
	player_strike_timer = maxf(player_strike_timer - delta, 0.0)
	if player_strike_pending and player_strike_timer <= player_attack_duration - player_attack_contact:
		player_strike_pending = false
		resolve_strike_contact()
	if strike_was_active and player_strike_timer <= 0.0:
		var chain_requested := player_attack_buffered
		player_attack_buffered = false
		player_attack_target_locked = false
		if chain_requested and not success and player_health > 0.0 and player_takedown_timer <= 0.0 and invulnerable <= 0.0 and not grapple_active and not player_airborne and player_counter_timer <= 0.0 and player_hurt_timer <= 0.0:
			_begin_strike()
	player_takedown_timer = maxf(player_takedown_timer - delta, 0.0)
	if player_takedown_pending and player_takedown_timer <= PLAYER_TAKEDOWN_DURATION - PLAYER_TAKEDOWN_CONTACT:
		player_takedown_pending = false
		defeat_guard("SILENT TAKEDOWN. Darkness turns positioning into power.")

func cancel_strike() -> void:
	player_strike_timer = 0.0
	player_strike_pending = false
	player_attack_target_locked = false
	player_attack_contact_connected = false
	player_attack_presentation_only = false
	player_attack_buffered = false
	player_attack_last_variant = &""

func resolve_strike_contact() -> void:
	if guard_defeated:
		player_attack_target_locked = false
		player_attack_contact_connected = false
		return
	var distance := flat_distance(player_root.position, guard_root.position)
	var valid_contact := player_attack_target_locked \
		and _attack_target_context_valid(player_attack_reach) \
		and distance <= player_attack_reach
	player_attack_target_locked = false
	if valid_contact:
		guard_health -= 22.0 + momentum * 0.08
		guard_label.text = "GUARD %d" % int(maxf(guard_health, 0.0))
		impact_flash_timer = 0.2
		begin_guard_reaction(0.32)
		guard_alert = true
		momentum = minf(momentum + 13.0, 100.0)
		player_attack_contact_connected = true
		set_message("%s connects. Momentum builds." % PlayerAttackCatalog.label(player_attack_variant).capitalize(), 1.0)
		if guard_health <= 0.0:
			defeat_guard("Guard down. Reach the violet gate.")
	else:
		player_attack_contact_connected = false
		if not player_attack_presentation_only:
			momentum = maxf(momentum - 8.0, 0.0)
			set_message("Strike whiffs. Momentum lost.", 0.8)

func _attack_target_context_valid(maximum_range: float) -> bool:
	if guard_defeated or player_on_perch or player_airborne:
		return false
	if not actors_share_level(player_root.position.y, guard_root.position.y):
		return false
	var to_guard := guard_root.position - player_root.position
	to_guard.y = 0.0
	var distance := to_guard.length()
	if distance > maximum_range:
		return false
	if distance > 0.001:
		var visible_yaw := player_root.rotation.y
		var visible_forward := Vector3(sin(visible_yaw), 0.0, cos(visible_yaw))
		if visible_forward.dot(to_guard / distance) < PLAYER_ATTACK_MIN_FACING_DOT:
			return false
	return not path_intersects_vault_obstacle(player_root.position, guard_root.position)

func counter() -> void:
	if success or player_health <= 0.0 or attack_timer <= 0.0 or guard_defeated or player_takedown_timer > 0.0 or invulnerable > 0.0 or grapple_active or player_airborne:
		return
	player_counter_timer = PLAYER_COUNTER_DURATION
	cancel_strike()
	face_player_toward_guard()
	var perfect := attack_timer > 0.30 and attack_timer < 0.56
	attack_countered = true
	attack_timer = 0.0
	attack_marker.visible = false
	attack_cooldown = 0.8
	begin_guard_reaction(0.55 if perfect else 0.25)
	if perfect:
		guard_health -= 30.0
		guard_label.text = "GUARD %d" % int(maxf(guard_health, 0.0))
		counter_flash_timer = 0.35
		momentum = minf(momentum + 28.0, 100.0)
		set_message("PERFECT COUNTER. The guard is wide open.", 1.5)
	else:
		momentum = minf(momentum + 8.0, 100.0)
		set_message("COUNTER BLOCK. Try the narrow center window.", 1.5)
	if guard_health <= 0.0:
		defeat_guard("Guard down. Reach the violet gate.")

func evade() -> void:
	if success or player_health <= 0.0 or invulnerable > 0.0 or player_takedown_timer > 0.0 or grapple_active or player_airborne:
		return
	if crouching and is_in_low_passage(player_root.position):
		set_message("LOW CLEARANCE: leave the passage before evading.", 1.2)
		return
	crouching = false
	cancel_strike()
	player_counter_timer = 0.0
	# +Z is this original rig's forward. Use the visible heading, not an old
	# travel vector or a camera-relative input that has not turned him yet.
	evade_direction = Vector3(sin(player_root.rotation.y), 0.0, cos(player_root.rotation.y))
	player_facing_yaw = atan2(evade_direction.x, evade_direction.z)
	evade_timer = EVADE_MOVE_DURATION
	invulnerable = EVADE_INVULNERABILITY_DURATION
	momentum = minf(momentum + 4.0, 100.0)
	set_message("FORWARD ROLL: short travel along your facing.", 0.8)

func toggle_crouch() -> void:
	if success or player_health <= 0.0 or player_takedown_timer > 0.0 or invulnerable > 0.0:
		return
	if player_counter_timer > 0.0:
		set_message("CROUCH UNAVAILABLE during counter recovery.", 1.0)
		return
	if crouching:
		if is_in_low_passage(player_root.position):
			set_message("LOW CLEARANCE: stay crouched until clear.", 1.2)
			return
		crouching = false
		set_message("CROUCH EXIT: full height restored.", 0.9)
		return
	if grapple_active or player_airborne or evade_timer > 0.0:
		set_message("CROUCH UNAVAILABLE during traversal.", 1.0)
		return
	crouching = true
	cancel_strike()
	set_message("CROUCH: %.3f units/s, %.1f-unit clearance." % [CROUCH_MOVE_SPEED, LOW_PASSAGE_CLEARANCE], 1.2)

func jump_or_vault() -> void:
	if success or player_health <= 0.0:
		return
	if player_counter_timer > 0.0:
		set_message("JUMP UNAVAILABLE during counter recovery.", 1.0)
		return
	if jump_active or grapple_active or player_airborne or player_on_perch or invulnerable > 0.0 or player_takedown_timer > 0.0:
		set_message("JUMP UNAVAILABLE during traversal.", 1.0)
		return
	if crouching and is_in_low_passage(player_root.position):
		set_message("LOW CLEARANCE: leave the passage before jumping.", 1.2)
		return
	crouching = false
	var direction := last_travel_direction
	direction.y = 0.0
	if direction.length() <= 0.01:
		direction = Vector3(sin(player_facing_yaw), 0.0, cos(player_facing_yaw))
	direction = direction.normalized()
	var candidate_end := player_root.position + direction * JUMP_DISTANCE
	candidate_end.x = clampf(candidate_end.x, -9.1, 9.1)
	candidate_end.z = clampf(candidate_end.z, -5.2, 5.2)
	if is_in_low_passage(candidate_end):
		set_message("LOW CLEARANCE: jump route is obstructed.", 1.2)
		return
	if candidate_end.distance_to(player_root.position) < 0.75:
		set_message("JUMP BLOCKED: not enough landing room.", 1.0)
		return
	jump_start = player_root.position
	cancel_strike()
	jump_end = candidate_end
	jump_end.y = 0.0
	jump_is_vault = path_intersects_vault_obstacle(jump_start, jump_end)
	jump_duration = VAULT_DURATION if jump_is_vault else JUMP_DURATION
	jump_height = VAULT_HEIGHT if jump_is_vault else JUMP_HEIGHT
	jump_t = 0.0
	jump_active = true
	player_airborne = true
	player_facing_yaw = atan2(direction.x, direction.z)
	set_message("VAULT: %.2fs, %.2f-unit apex." % [jump_duration, jump_height] if jump_is_vault else "JUMP: %.2fs, %.2f-unit apex." % [jump_duration, jump_height], 1.2)

func stealth_takedown() -> void:
	if success or player_health <= 0.0 or guard_defeated or player_takedown_timer > 0.0 or invulnerable > 0.0 or grapple_active or player_airborne:
		return
	var to_player := player_root.position - guard_root.position
	to_player.y = 0.0
	var behind := guard_forward.dot(to_player.normalized()) < -0.15
	if is_concealed() and to_player.length() < 2.1 and behind and actors_share_level(player_root.position.y, guard_root.position.y) and not is_in_low_passage(player_root.position):
		cancel_strike()
		player_counter_timer = 0.0
		crouching = false
		player_takedown_timer = PLAYER_TAKEDOWN_DURATION
		player_takedown_pending = true
		attack_timer = 0.0
		attack_marker.visible = false
		guard_is_moving = false
		player_move_timer = 0.0
		face_player_toward_guard()
		set_message("TAKEDOWN: catch, pull down, release.", 1.1)
	else:
		set_message("Takedown needs darkness, close range, and the guard's back.", 1.5)

func grapple() -> void:
	if success or player_health <= 0.0:
		return
	if jump_active or player_airborne:
		set_message("GRAPPLE UNAVAILABLE during jump or fall.", 1.0)
		return
	if player_counter_timer > 0.0:
		set_message("GRAPPLE UNAVAILABLE during counter recovery.", 1.0)
		return
	if grapple_active or player_takedown_timer > 0.0 or invulnerable > 0.0:
		return
	if player_root.position.y > 0.5:
		set_message("GRAPPLE ROUTE COMPLETE: already on the elevated perch.", 1.2)
		return
	if flat_distance(player_root.position, ANCHOR_POSITION) < GRAPPLE_RANGE:
		crouching = false
		cancel_strike()
		grapple_start = player_root.position
		grapple_t = 0.0
		grapple_recovery_timer = 0.0
		var grapple_direction := PERCH_POSITION - grapple_start
		grapple_direction.y = 0.0
		if grapple_direction.length() > 0.01:
			player_facing_yaw = atan2(grapple_direction.x, grapple_direction.z)
		grapple_active = true
		set_message("GRAPPLE LAUNCHED: follow the gold route.", 1.0)
	else:
		set_message("OUT OF RANGE: enter the dashed gold ring.", 1.4)

func damage_player(amount: float, why: String) -> void:
	if invulnerable > 0.0:
		set_message("EVADE SUCCESS: the attack passes through empty air.", 1.0)
		return
	cancel_strike()
	player_health = maxf(player_health - amount, 0.0)
	player_hurt_timer = PLAYER_HURT_DURATION
	momentum = maxf(momentum - 25.0, 0.0)
	set_message(why, 1.5)
	if player_health <= 0.0:
		player_downed_elapsed = 0.0
		set_message("DOWNED. Press R to restart the courtyard.", 999.0)

func defeat_guard(text: String) -> void:
	guard_defeated = true
	guard_alert = false
	guard_health = 0.0
	attack_timer = 0.0
	attack_marker.visible = false
	guard_stun = 0.0
	guard_stun_duration = 0.0
	guard_defeat_elapsed = 0.0
	guard_visual_parts["visual_root"].visible = true
	guard_label.visible = true
	set_guard_visual_fade(0.0)
	vision_mesh.visible = false
	guard_label.text = "GUARD DOWN"
	momentum = minf(momentum + 35.0, 100.0)
	set_message(text, 2.8)

func face_player_toward_guard() -> void:
	var to_guard := guard_root.position - player_root.position
	to_guard.y = 0.0
	if to_guard.length() > 0.01:
		player_facing_yaw = atan2(to_guard.x, to_guard.z)

func begin_guard_reaction(duration: float) -> void:
	guard_stun = duration
	guard_stun_duration = duration
	var away_from_player := guard_root.position - player_root.position
	away_from_player.y = 0.0
	var guard_right := guard_root.global_transform.basis.x
	guard_right.y = 0.0
	if guard_right.length() > 0.01 and away_from_player.length() > 0.01:
		var lateral := guard_right.normalized().dot(away_from_player.normalized())
		if absf(lateral) > 0.08:
			guard_reaction_side = signf(lateral)

func update_guard_defeat(delta: float) -> void:
	if not guard_defeated:
		return
	guard_defeat_elapsed = minf(guard_defeat_elapsed + delta, GUARD_DEFEAT_DURATION)
	var fade := smoothstep(GUARD_FADE_DELAY, GUARD_DEFEAT_DURATION, guard_defeat_elapsed)
	set_guard_visual_fade(fade)
	if guard_defeat_elapsed >= GUARD_DEFEAT_DURATION:
		guard_visual_parts["visual_root"].visible = false
		guard_label.visible = false

func set_guard_visual_fade(amount: float) -> void:
	var visual_root := guard_visual_parts.get("visual_root") as Node3D
	if visual_root == null:
		return
	for node in visual_root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry != null:
			geometry.transparency = clampf(amount, 0.0, 1.0)

func check_success() -> void:
	if guard_defeated and flat_distance(player_root.position, EXIT_POSITION) < 2.3:
		success = true
		objective_label.text = "COURTYARD CLEAR"
		set_message("COURTYARD CLEAR. Press R to run the loop again.", 999.0)

func is_concealed() -> bool:
	var inside_darkness := flat_distance(player_root.position, HIDE_POSITION) < 2.0
	var inside_ambush_shadow := flat_distance(player_root.position, TAKEDOWN_SHADOW_POSITION) < TAKEDOWN_SHADOW_RADIUS
	return player_root.position.y < 0.5 and (inside_darkness or inside_ambush_shadow) and evade_timer <= 0.0

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func actors_share_level(first_y: float, second_y: float) -> bool:
	return absf(first_y - second_y) <= ACTOR_LEVEL_TOLERANCE and not grapple_active


func player_collision_radius() -> float:
	return PLAYER_BODY_RADIUS * PLAYER_BASE_SCALE * player_scale


func guard_collision_radius() -> float:
	return GUARD_BODY_RADIUS * GUARD_BASE_SCALE


func minimum_actor_separation() -> float:
	return maxf(ACTOR_PERSONAL_SPACE, player_collision_radius() + guard_collision_radius())


func is_over_perch(position: Vector3, inset := 0.0) -> bool:
	return (
		absf(position.x - PERCH_POSITION.x) <= PERCH_HALF_EXTENTS.x - inset
		and absf(position.z - PERCH_POSITION.z) <= PERCH_HALF_EXTENTS.y - inset
	)


func resolve_actor_separation(candidate: Vector3, current: Vector3, other: Vector3, minimum_distance: float) -> Vector3:
	var candidate_flat := Vector2(candidate.x, candidate.z)
	var other_flat := Vector2(other.x, other.z)
	if candidate_flat.distance_to(other_flat) >= minimum_distance:
		return candidate
	var away := candidate_flat - other_flat
	if away.length() < 0.001:
		away = Vector2(current.x - other.x, current.z - other.z)
	if away.length() < 0.001:
		away = Vector2.RIGHT
	var resolved_flat := other_flat + away.normalized() * minimum_distance
	resolved_flat.x = clampf(resolved_flat.x, -9.1, 9.1)
	resolved_flat.y = clampf(resolved_flat.y, -5.2, 5.2)
	if resolved_flat.distance_to(other_flat) < minimum_distance - 0.01:
		return current
	candidate.x = resolved_flat.x
	candidate.z = resolved_flat.y
	return candidate

func set_message(text: String, duration: float) -> void:
	message = text
	message_timer = duration

func update_hud() -> void:
	if health_bar == null:
		return
	health_bar.value = player_health
	momentum_bar.value = momentum
	message_label.text = message if message_timer > 0.0 else ""
	if success:
		objective_label.text = "COURTYARD CLEAR"
	elif guard_defeated:
		objective_label.text = "OBJECTIVE: reach EXIT"
	else:
		objective_label.text = "OBJECTIVE: guard and exit"

func update_feedback() -> void:
	if impact_light != null:
		impact_light.light_energy = 7.0 if impact_flash_timer > 0.0 else 0.0
		counter_light.light_energy = 8.0 if counter_flash_timer > 0.0 else 0.0
	if grapple_active:
		player_root.rotation.z = sin(grapple_t * PI) * 0.12

func update_grapple_feedback() -> void:
	if grapple_prompt == null or grapple_range_root == null:
		return
	var distance := flat_distance(player_root.position, ANCHOR_POSITION)
	var ready := player_root.position.y < 0.5 and distance < GRAPPLE_RANGE
	var pulse := (sin(Time.get_ticks_msec() * 0.009) + 1.0) * 0.5
	grapple_range_root.visible = player_root.position.y < 0.5
	grapple_range_root.scale = Vector3.ONE * (1.0 + (0.012 * pulse if ready else 0.0))
	if grapple_active:
		grapple_prompt.text = "GRAPPLE // IN TRANSIT"
		grapple_prompt.modulate = Color("#fff0a8")
		grapple_anchor_light.light_energy = 5.5
		grapple_route_material.emission_energy_multiplier = 3.0
	elif player_root.position.y > 0.5:
		grapple_prompt.text = "ROUTE COMPLETE"
		grapple_prompt.modulate = Color("#b99d67")
		grapple_anchor_light.light_energy = 2.2
		grapple_route_material.emission_energy_multiplier = 1.2
	elif ready:
		grapple_prompt.text = "G // GRAPPLE READY"
		grapple_prompt.modulate = Color("#fff0a8")
		grapple_anchor_light.light_energy = 3.8 + pulse * 1.5
		grapple_ring_material.albedo_color = Color("#e6bd5c")
		grapple_ring_material.emission = Color("#e6bd5c")
		grapple_route_material.emission_energy_multiplier = 2.0
	else:
		grapple_prompt.text = "ENTER GOLD RING"
		grapple_prompt.modulate = Color("#b99d67")
		grapple_anchor_light.light_energy = 2.2
		grapple_ring_material.albedo_color = Color("#806a3e")
		grapple_ring_material.emission = Color("#806a3e")
		grapple_route_material.emission_energy_multiplier = 1.2

func grappler_ease(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

func capture_screenshot() -> void:
	await get_tree().process_frame
	var capture_dir := ProjectSettings.globalize_path("res://captures")
	var dir_error := DirAccess.make_dir_recursive_absolute(capture_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		set_message("Capture failed: could not create captures directory.", 2.0)
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var filename := "courtyard_3d_%s_%s.png" % [stamp, str(Time.get_ticks_msec())]
	var path := capture_dir.path_join(filename)
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(path)
	if save_error == OK:
		set_message("CAPTURED: captures/%s" % filename, 2.5)
	else:
		set_message("Capture failed with error %s." % save_error, 2.0)

func make_material(color: Color, roughness: float, metallic := 0.0, emission := Color.TRANSPARENT) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.2
	return material

func make_box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance

func make_cylinder(parent: Node3D, position: Vector3, radius: float, height: float, color_or_material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return make_mesh_instance(parent, position, mesh, color_or_material)

func make_tapered(parent: Node3D, position: Vector3, top_radius: float, bottom_radius: float, height: float, color_or_material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return make_mesh_instance(parent, position, mesh, color_or_material)

func make_cone(parent: Node3D, position: Vector3, radius: float, height: float, color_or_material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	return make_mesh_instance(parent, position, mesh, color_or_material)

func make_sphere(parent: Node3D, position: Vector3, radius: float, color_or_material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return make_mesh_instance(parent, position, mesh, color_or_material)

func make_mesh_instance(parent: Node3D, position: Vector3, mesh: Mesh, color_or_material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	if color_or_material is Material:
		instance.material_override = color_or_material
	else:
		instance.material_override = make_material(color_or_material, 0.75)
	parent.add_child(instance)
	return instance

func make_label(text: String, position: Vector3, color: Color, parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 64
	label.pixel_size = 0.0055
	label.outline_size = 8
	label.outline_modulate = Color("#080b13")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label
