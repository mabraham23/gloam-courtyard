extends Node3D

## Isolated, non-default spatial gray-box for a future Riven Lantern Ward integration.
## Primitive geometry only. This scene intentionally contains no gameplay controller.

const WARD_SIZE := Vector2(38.0, 28.0)
const HALF_WARD := WARD_SIZE * 0.5
const COMBAT_CORE_SIZE := Vector2(14.0, 10.0)
const COMBAT_CORE_CENTER := Vector3(2.0, 0.0, 1.0)

const CROUCH_CLEARANCE := 2.0
const JUMP_DISTANCE := 2.2
const JUMP_APEX := 1.35
const VAULT_APEX := 1.05
const VAULT_OBSTACLE_HEIGHT := 0.84
const GRAPPLE_RANGE := 3.5
const ELEVATED_TOP := 3.04

const ENTRY_POSITION := Vector3(-16.5, 0.0, 10.0)
const RETURN_POSITION := Vector3(-16.5, 0.0, 2.2)
const LOW_PASSAGE_CENTER := Vector3(-11.8, 0.0, 1.9)
const VAULT_CENTER := Vector3(4.5, 0.0, 3.0)

const GRAPPLE_A_ANCHOR := Vector3(-10.0, 0.0, -2.0)
const GRAPPLE_A_LANDING := Vector3(-7.0, ELEVATED_TOP, -3.6)
const GRAPPLE_B_ANCHOR := Vector3(8.84, 0.0, -0.8)
const GRAPPLE_B_LANDING := Vector3(7.0, ELEVATED_TOP, -3.6)

const DECK_A_CENTER := Vector3(-5.7, ELEVATED_TOP, -4.0)
const DECK_A_SIZE := Vector2(4.5, 3.0)
const DECK_B_CENTER := Vector3(0.6, ELEVATED_TOP, -4.0)
const DECK_B_SIZE := Vector2(4.5, 3.0)
const DECK_C_CENTER := Vector3(6.45, ELEVATED_TOP, -4.0)
const DECK_C_SIZE := Vector2(3.9, 3.0)
const JUMP_GAP_A := 1.8
const JUMP_GAP_B := 1.65

var geometry_root: Node3D
var routes_root: Node3D
var affordances_root: Node3D
var labels_root: Node3D

var stone_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var ground_route_material: StandardMaterial3D
var covered_route_material: StandardMaterial3D
var elevated_route_material: StandardMaterial3D
var shortcut_route_material: StandardMaterial3D
var concealment_material: StandardMaterial3D
var measure_material: StandardMaterial3D


func _ready() -> void:
	get_window().title = "Riven Lantern Ward Gray-box (NON-DEFAULT)"
	make_roots()
	make_materials()
	build_environment()
	build_shell()
	build_combat_core()
	build_ground_route()
	build_covered_route()
	build_elevated_route()
	build_concealment_pockets()
	build_loopback_shortcut()
	build_route_legend()
	var issues := validate_measurements()
	print_measurements(issues)
	if "--validate-riven" in OS.get_cmdline_user_args():
		get_tree().quit.call_deferred(0 if issues.is_empty() else 2)


func make_roots() -> void:
	geometry_root = Node3D.new()
	geometry_root.name = "Geometry"
	add_child(geometry_root)
	routes_root = Node3D.new()
	routes_root.name = "RouteIdeas"
	add_child(routes_root)
	affordances_root = Node3D.new()
	affordances_root.name = "MeasuredAffordances"
	affordances_root.set_meta("crouch_clearance", CROUCH_CLEARANCE)
	affordances_root.set_meta("jump_distance", JUMP_DISTANCE)
	affordances_root.set_meta("jump_apex", JUMP_APEX)
	affordances_root.set_meta("vault_apex", VAULT_APEX)
	affordances_root.set_meta("grapple_range", GRAPPLE_RANGE)
	add_child(affordances_root)
	labels_root = Node3D.new()
	labels_root.name = "SpatialLabels"
	add_child(labels_root)


func make_materials() -> void:
	stone_material = make_material(Color("#222b38"), 0.82)
	wall_material = make_material(Color("#303a49"), 0.76)
	metal_material = make_material(Color("#4d5c6e"), 0.48, 0.26)
	ground_route_material = make_material(Color("#c16f3d"), 0.46, 0.0, Color("#6f321b"))
	covered_route_material = make_material(Color("#3c9ba4"), 0.42, 0.0, Color("#174e59"))
	elevated_route_material = make_material(Color("#9a6fd0"), 0.38, 0.0, Color("#4b2d72"))
	shortcut_route_material = make_material(Color("#6cad72"), 0.46, 0.0, Color("#285d32"))
	concealment_material = make_material(Color("#09111c", 0.92), 0.96)
	measure_material = make_material(Color("#e7c45a"), 0.34, 0.04, Color("#92742d"))


func build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WardEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#050914")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#74859d")
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.fog_enabled = true
	environment.fog_light_color = Color("#526375")
	environment.fog_light_energy = 0.34
	environment.fog_density = 0.006
	world_environment.environment = environment
	add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.name = "ColdWardLight"
	moon.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	moon.light_color = Color("#88a0c0")
	moon.light_energy = 1.32
	moon.shadow_enabled = true
	add_child(moon)

	for lamp_position in [Vector3(-15.5, 3.2, 7.0), Vector3(10.5, 3.2, 6.8), Vector3(13.5, 3.2, -8.0)]:
		var lamp := OmniLight3D.new()
		lamp.position = lamp_position
		lamp.light_color = Color("#e6a85c")
		lamp.light_energy = 4.2
		lamp.omni_range = 7.0
		add_child(lamp)
		make_sphere(geometry_root, "LanternGlow", lamp_position, 0.24, make_material(Color("#e6a85c"), 0.25, 0.0, Color("#e6a85c")))

	var camera := Camera3D.new()
	camera.name = "OverviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 37.0
	camera.position = Vector3(32.0, 32.0, 39.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, -0.5), Vector3.UP)
	camera.current = true


func build_shell() -> void:
	make_block(geometry_root, "WardFloor", Vector3(0.0, -0.28, 0.0), Vector3(WARD_SIZE.x, 0.5, WARD_SIZE.y), stone_material)

	# The broken perimeter communicates a bounded ward without implying a final facade.
	make_block(geometry_root, "WestWall", Vector3(-18.75, 1.25, -3.0), Vector3(0.5, 2.5, 21.5), wall_material)
	make_block(geometry_root, "EastWall", Vector3(18.75, 1.25, 0.0), Vector3(0.5, 2.5, 27.0), wall_material)
	make_block(geometry_root, "NorthWall", Vector3(0.0, 1.25, -13.75), Vector3(37.0, 2.5, 0.5), wall_material)
	make_block(geometry_root, "SouthWallA", Vector3(-9.5, 1.25, 13.75), Vector3(17.0, 2.5, 0.5), wall_material)
	make_block(geometry_root, "SouthWallB", Vector3(10.5, 1.25, 13.75), Vector3(16.0, 2.5, 0.5), wall_material)

	for pylon_position in [Vector3(-18.0, 2.8, -12.8), Vector3(18.0, 3.5, -12.8), Vector3(18.0, 2.8, 12.8), Vector3(-18.0, 3.2, 12.8)]:
		make_block(geometry_root, "WardPylon", pylon_position, Vector3(1.4, pylon_position.y * 2.0, 1.4), wall_material)
		make_cone(geometry_root, "PylonCap", pylon_position + Vector3(0.0, pylon_position.y + 1.0, 0.0), 0.82, 2.0, wall_material)

	make_label("ENTRY", ENTRY_POSITION + Vector3(-0.8, 1.1, 0.0), Color("#efb27a"))
	make_scale_marker(ENTRY_POSITION + Vector3(1.2, 0.0, -0.8))


func build_combat_core() -> void:
	var core_root := Node3D.new()
	core_root.name = "OpenCombatCore_14x10"
	core_root.set_meta("size", COMBAT_CORE_SIZE)
	routes_root.add_child(core_root)
	make_outline(core_root, COMBAT_CORE_CENTER + Vector3(0.0, 0.025, 0.0), COMBAT_CORE_SIZE, ground_route_material, 0.16)
	make_label("OPEN COMBAT CORE // 14 x 10", COMBAT_CORE_CENTER + Vector3(-2.4, 0.18, 0.0), Color("#efaf78"))

	# Cover remains peripheral, preserving a legible multi-opponent interior.
	for cover_position in [Vector3(-4.2, 0.55, -2.8), Vector3(8.2, 0.55, -2.8), Vector3(-4.2, 0.55, 4.8), Vector3(8.2, 0.55, 4.8)]:
		make_block(core_root, "PeripheralCombatCover", cover_position, Vector3(1.6, 1.1, 0.75), wall_material)
	for marker_position in [Vector3(-0.5, 0.0, 1.0), Vector3(2.0, 0.0, 1.0), Vector3(4.5, 0.0, 1.0)]:
		make_actor_marker(core_root, marker_position)


func build_ground_route() -> void:
	var route := Node3D.new()
	route.name = "GroundRoute_Amber"
	routes_root.add_child(route)
	var points: Array[Vector3] = [
		ENTRY_POSITION + Vector3(0.0, 0.035, 0.0),
		Vector3(-10.0, 0.035, 8.0),
		Vector3(-5.0, 0.035, 4.0),
		Vector3(0.0, 0.035, 3.0),
		Vector3(7.5, 0.035, 3.0),
		Vector3(14.0, 0.035, 6.5),
		Vector3(16.0, 0.035, -1.5),
		Vector3(13.0, 0.035, -8.5),
		Vector3(4.5, 0.035, -10.0),
		Vector3(-6.0, 0.035, -8.0),
		RETURN_POSITION + Vector3(0.0, 0.035, 0.0),
	]
	make_route_ribbon(route, points, 0.72, ground_route_material)
	make_label("GROUND ROUTE", Vector3(11.5, 0.18, 7.0), Color("#e99a67"))

	var vault_root := Node3D.new()
	vault_root.name = "Vault_0p84_High"
	vault_root.set_meta("obstacle_height", VAULT_OBSTACLE_HEIGHT)
	vault_root.set_meta("accepted_apex", VAULT_APEX)
	affordances_root.add_child(vault_root)
	make_block(vault_root, "VaultObstacle", VAULT_CENTER + Vector3(0.0, VAULT_OBSTACLE_HEIGHT * 0.5, 0.0), Vector3(0.70, VAULT_OBSTACLE_HEIGHT, 3.0), wall_material)
	make_block(vault_root, "VaultCap", VAULT_CENTER + Vector3(0.0, VAULT_OBSTACLE_HEIGHT + 0.05, 0.0), Vector3(0.82, 0.10, 3.12), measure_material, false)
	make_label("V // 0.84 HIGH // 1.05 APEX", VAULT_CENTER + Vector3(-2.0, 1.25, 0.0), Color("#f1cf6b"))


func build_covered_route() -> void:
	var route := Node3D.new()
	route.name = "CoveredRoute_Cyan"
	routes_root.add_child(route)
	var points: Array[Vector3] = [
		Vector3(-14.5, 0.055, 8.6),
		Vector3(-13.2, 0.055, 5.3),
		Vector3(-11.8, 0.055, 1.9),
		Vector3(-12.8, 0.055, -1.0),
		GRAPPLE_A_ANCHOR + Vector3(0.0, 0.055, 0.0),
	]
	make_route_ribbon(route, points, 0.78, covered_route_material)

	# Broken canopy sections keep the route readable from the overview camera.
	for canopy_position in [Vector3(-14.0, 3.35, 6.8), Vector3(-12.7, 3.35, -0.4)]:
		make_block(route, "ArcadeCanopy", canopy_position, Vector3(3.6, 0.28, 3.2), metal_material)
		for offset_x in [-1.45, 1.45]:
			make_block(route, "ArcadeColumn", canopy_position + Vector3(offset_x, -1.68, -1.20), Vector3(0.28, 3.35, 0.28), metal_material)
	make_label("COVERED ROUTE", Vector3(-15.2, 3.85, 5.7), Color("#77d0d4"))

	var passage_root := Node3D.new()
	passage_root.name = "CrouchPassage_2p0_Clearance"
	passage_root.set_meta("clearance", CROUCH_CLEARANCE)
	affordances_root.add_child(passage_root)
	make_block(passage_root, "PassageLeftPier", LOW_PASSAGE_CENTER + Vector3(-1.35, 1.0, 0.0), Vector3(0.35, 2.0, 2.4), wall_material)
	make_block(passage_root, "PassageRightPier", LOW_PASSAGE_CENTER + Vector3(1.35, 1.0, 0.0), Vector3(0.35, 2.0, 2.4), wall_material)
	make_block(passage_root, "PassageLintel", LOW_PASSAGE_CENTER + Vector3(0.0, CROUCH_CLEARANCE + 0.16, 0.0), Vector3(3.05, 0.32, 2.4), metal_material)
	make_dimension_line(passage_root, LOW_PASSAGE_CENTER + Vector3(0.0, 0.0, 1.45), LOW_PASSAGE_CENTER + Vector3(0.0, CROUCH_CLEARANCE, 1.45))
	make_label("Q // 2.0 CLEAR", LOW_PASSAGE_CENTER + Vector3(-1.0, 2.7, 0.0), Color("#83dce0"))


func build_elevated_route() -> void:
	var route := Node3D.new()
	route.name = "ElevatedRoute_Violet"
	routes_root.add_child(route)
	make_elevated_deck(route, "WestDeck", DECK_A_CENTER, DECK_A_SIZE)
	make_elevated_deck(route, "MiddleDeck", DECK_B_CENTER, DECK_B_SIZE)
	make_elevated_deck(route, "EastDeck", DECK_C_CENTER, DECK_C_SIZE)
	make_label("ELEVATED ROUTE // TOP 3.04", Vector3(-1.8, 4.25, -4.0), Color("#caa4ee"))

	var elevated_points: Array[Vector3] = [
		GRAPPLE_A_LANDING + Vector3(0.0, 0.035, 0.0),
		Vector3(-3.2, ELEVATED_TOP + 0.035, -4.0),
		Vector3(-0.8, ELEVATED_TOP + 0.035, -4.0),
		Vector3(2.8, ELEVATED_TOP + 0.035, -4.0),
		Vector3(5.2, ELEVATED_TOP + 0.035, -4.0),
		GRAPPLE_B_LANDING + Vector3(0.0, 0.035, 0.0),
	]
	make_route_ribbon(route, elevated_points, 0.52, elevated_route_material)

	make_jump_gap(route, "JumpGapA_1p80", Vector3(-2.05, ELEVATED_TOP + 0.14, -4.0), JUMP_GAP_A)
	make_jump_gap(route, "JumpGapB_1p65", Vector3(4.18, ELEVATED_TOP + 0.14, -4.0), JUMP_GAP_B)
	make_grapple_opportunity(route, "GrappleA_3p40", GRAPPLE_A_ANCHOR, GRAPPLE_A_LANDING)
	make_grapple_opportunity(route, "GrappleB_3p35", GRAPPLE_B_ANCHOR, GRAPPLE_B_LANDING)


func build_concealment_pockets() -> void:
	var concealment_root := Node3D.new()
	concealment_root.name = "ConcealmentPockets"
	affordances_root.add_child(concealment_root)
	var pockets: Array[Vector3] = [
		Vector3(-14.4, 0.035, -3.2),
		Vector3(-4.0, 0.035, 8.8),
		Vector3(11.0, 0.035, 8.8),
		Vector3(12.8, 0.035, -9.4),
	]
	for index in range(pockets.size()):
		var pocket := pockets[index]
		make_cylinder(concealment_root, "ShadowPocket%02d" % index, pocket, 1.65, 0.06, concealment_material)
		make_block(concealment_root, "ShadowScreen%02d" % index, pocket + Vector3(0.0, 1.2, -1.05), Vector3(2.7, 2.4, 0.32), wall_material)
	make_label("CONCEALMENT POCKETS", Vector3(9.8, 2.8, 9.0), Color("#96a9c7"))


func build_loopback_shortcut() -> void:
	var shortcut := Node3D.new()
	shortcut.name = "LoopbackShortcut_Green"
	shortcut.set_meta("opens_from", "return_side")
	routes_root.add_child(shortcut)
	var points: Array[Vector3] = [
		RETURN_POSITION + Vector3(0.0, 0.075, 0.0),
		Vector3(-16.3, 0.075, 5.8),
		ENTRY_POSITION + Vector3(0.0, 0.075, 0.0),
	]
	make_route_ribbon(shortcut, points, 0.58, shortcut_route_material)
	make_block(shortcut, "OneWayShortcutGate", Vector3(-16.3, 1.4, 5.8), Vector3(0.24, 2.8, 2.5), metal_material)
	for bar_offset in [-0.75, -0.25, 0.25, 0.75]:
		make_block(shortcut, "ShortcutGateBar", Vector3(-16.1, 1.4, 5.8 + bar_offset), Vector3(0.18, 2.5, 0.10), shortcut_route_material, false)
	make_label("LOOPBACK // OPEN FROM RETURN", Vector3(-17.3, 3.45, 5.8), Color("#90d895"))


func build_route_legend() -> void:
	var layer := CanvasLayer.new()
	layer.name = "OverviewLegend"
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 16.0)
	panel.size = Vector2(540.0, 82.0)
	panel.color = Color("#07101ddd")
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(16.0, 9.0)
	title.size = Vector2(510.0, 28.0)
	title.text = "RIVEN LANTERN WARD // ISOLATED NON-DEFAULT GRAY-BOX"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#e7edf7"))
	panel.add_child(title)
	var legend := Label.new()
	legend.position = Vector2(16.0, 36.0)
	legend.size = Vector2(510.0, 42.0)
	legend.text = "38 x 28  |  AMBER ground  |  CYAN covered  |  VIOLET elevated  |  GREEN loopback\n2.0 crouch  |  2.2 jump / 1.35 apex  |  1.05 vault apex  |  3.5 grapple range"
	legend.add_theme_font_size_override("font_size", 14)
	legend.add_theme_color_override("font_color", Color("#bac8dc"))
	panel.add_child(legend)


func validate_measurements() -> Array[String]:
	var issues: Array[String] = []
	if not is_equal_approx(WARD_SIZE.x, 38.0) or not is_equal_approx(WARD_SIZE.y, 28.0):
		issues.append("ward footprint drifted from 38 x 28")
	if not is_equal_approx(CROUCH_CLEARANCE, 2.0):
		issues.append("crouch clearance is not 2.0")
	if VAULT_OBSTACLE_HEIGHT > VAULT_APEX:
		issues.append("vault obstacle exceeds the 1.05 apex")
	if JUMP_GAP_A > JUMP_DISTANCE or JUMP_GAP_B > JUMP_DISTANCE:
		issues.append("an elevated gap exceeds the 2.2 jump distance")
	var grapple_a_flat := flat_distance(GRAPPLE_A_ANCHOR, GRAPPLE_A_LANDING)
	var grapple_b_flat := flat_distance(GRAPPLE_B_ANCHOR, GRAPPLE_B_LANDING)
	if grapple_a_flat > GRAPPLE_RANGE or grapple_b_flat > GRAPPLE_RANGE:
		issues.append("a grapple landing exceeds the 3.5 horizontal range")
	for point in [ENTRY_POSITION, RETURN_POSITION, LOW_PASSAGE_CENTER, VAULT_CENTER, GRAPPLE_A_ANCHOR, GRAPPLE_A_LANDING, GRAPPLE_B_ANCHOR, GRAPPLE_B_LANDING]:
		if absf(point.x) > HALF_WARD.x or absf(point.z) > HALF_WARD.y:
			issues.append("a key affordance falls outside the ward boundary")
	return issues


func print_measurements(issues: Array[String]) -> void:
	print("RIVEN_LANTERN_WARD footprint=%.1fx%.1f combat_core=%.1fx%.1f" % [WARD_SIZE.x, WARD_SIZE.y, COMBAT_CORE_SIZE.x, COMBAT_CORE_SIZE.y])
	print("RIVEN_LANTERN_WARD crouch_clearance=%.2f vault_height=%.2f vault_apex=%.2f" % [CROUCH_CLEARANCE, VAULT_OBSTACLE_HEIGHT, VAULT_APEX])
	print("RIVEN_LANTERN_WARD jump_distance=%.2f jump_apex=%.2f gaps=%.2f,%.2f" % [JUMP_DISTANCE, JUMP_APEX, JUMP_GAP_A, JUMP_GAP_B])
	print("RIVEN_LANTERN_WARD grapple_range=%.2f opportunities=%.2f,%.2f" % [GRAPPLE_RANGE, flat_distance(GRAPPLE_A_ANCHOR, GRAPPLE_A_LANDING), flat_distance(GRAPPLE_B_ANCHOR, GRAPPLE_B_LANDING)])
	if issues.is_empty():
		print("RIVEN_LANTERN_WARD_VALIDATION PASS")
	else:
		for issue in issues:
			push_error("RIVEN_LANTERN_WARD_VALIDATION %s" % issue)


func make_elevated_deck(parent: Node3D, name: String, center: Vector3, size: Vector2) -> void:
	var thickness := 0.36
	make_block(parent, name, Vector3(center.x, ELEVATED_TOP - thickness * 0.5, center.z), Vector3(size.x, thickness, size.y), wall_material)
	for support_x in [-size.x * 0.36, size.x * 0.36]:
		make_block(parent, "%sSupport" % name, Vector3(center.x + support_x, ELEVATED_TOP * 0.5, center.z), Vector3(0.34, ELEVATED_TOP, 0.34), metal_material)


func make_jump_gap(parent: Node3D, name: String, center: Vector3, distance: float) -> void:
	var gap_root := Node3D.new()
	gap_root.name = name
	gap_root.set_meta("gap_distance", distance)
	gap_root.set_meta("accepted_jump_distance", JUMP_DISTANCE)
	gap_root.set_meta("accepted_apex", JUMP_APEX)
	affordances_root.add_child(gap_root)
	make_dimension_line(gap_root, center + Vector3(-distance * 0.5, 0.0, 0.0), center + Vector3(distance * 0.5, 0.0, 0.0))
	make_label("%.2f GAP <= 2.20" % distance, center + Vector3(-0.9, 0.65, 0.0), Color("#f1cf6b"))


func make_grapple_opportunity(parent: Node3D, name: String, anchor: Vector3, landing: Vector3) -> void:
	var grapple_root := Node3D.new()
	grapple_root.name = name
	var horizontal_distance := flat_distance(anchor, landing)
	grapple_root.set_meta("horizontal_distance", horizontal_distance)
	grapple_root.set_meta("accepted_range", GRAPPLE_RANGE)
	affordances_root.add_child(grapple_root)
	make_dashed_ring(grapple_root, anchor + Vector3(0.0, 0.045, 0.0), GRAPPLE_RANGE, measure_material)
	make_cylinder(grapple_root, "Anchor", anchor + Vector3(0.0, 0.10, 0.0), 0.24, 0.20, measure_material)
	for index in range(1, 9):
		var t := float(index) / 9.0
		make_sphere(grapple_root, "RouteBead", anchor.lerp(landing, t) + Vector3(0.0, 0.12, 0.0), 0.09, measure_material)
	make_label("G // %.2f <= 3.50" % horizontal_distance, anchor + Vector3(-1.0, 0.7, 0.0), Color("#f1cf6b"))


func make_route_ribbon(parent: Node3D, points: Array[Vector3], width: float, material: Material) -> void:
	for index in range(points.size() - 1):
		make_band(parent, "RouteBand%02d" % index, points[index], points[index + 1], width, material)


func make_band(parent: Node3D, name: String, start: Vector3, finish: Vector3, width: float, material: Material) -> void:
	var delta := finish - start
	var band := make_block(parent, name, (start + finish) * 0.5, Vector3(delta.length(), 0.035, width), material, false)
	band.rotation.y = atan2(-delta.z, delta.x)


func make_outline(parent: Node3D, center: Vector3, size: Vector2, material: Material, width: float) -> void:
	make_block(parent, "OutlineNorth", center + Vector3(0.0, 0.0, -size.y * 0.5), Vector3(size.x, 0.035, width), material, false)
	make_block(parent, "OutlineSouth", center + Vector3(0.0, 0.0, size.y * 0.5), Vector3(size.x, 0.035, width), material, false)
	make_block(parent, "OutlineWest", center + Vector3(-size.x * 0.5, 0.0, 0.0), Vector3(width, 0.035, size.y), material, false)
	make_block(parent, "OutlineEast", center + Vector3(size.x * 0.5, 0.0, 0.0), Vector3(width, 0.035, size.y), material, false)


func make_dashed_ring(parent: Node3D, center: Vector3, radius: float, material: Material) -> void:
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		var segment := make_block(parent, "RangeSegment%02d" % index, center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3(0.46, 0.025, 0.08), material, false)
		segment.rotation.y = PI * 0.5 - angle


func make_dimension_line(parent: Node3D, start: Vector3, finish: Vector3) -> void:
	var delta := finish - start
	var line := make_cylinder(parent, "DimensionLine", (start + finish) * 0.5, 0.035, delta.length(), measure_material)
	line.quaternion = Quaternion(Vector3.UP, delta.normalized())
	make_sphere(parent, "DimensionStart", start, 0.10, measure_material)
	make_sphere(parent, "DimensionEnd", finish, 0.10, measure_material)


func make_actor_marker(parent: Node3D, position: Vector3) -> void:
	make_cylinder(parent, "EncounterMarker", position + Vector3(0.0, 0.82, 0.0), 0.33, 1.25, make_material(Color("#a64e56"), 0.58))
	make_sphere(parent, "EncounterMarkerHead", position + Vector3(0.0, 1.65, 0.0), 0.28, make_material(Color("#bd6870"), 0.58))


func make_scale_marker(position: Vector3) -> void:
	make_cylinder(geometry_root, "WayfarerScaleMarker", position + Vector3(0.0, 0.85, 0.0), 0.32, 1.35, make_material(Color("#687fb5"), 0.62))
	make_sphere(geometry_root, "WayfarerScaleHead", position + Vector3(0.0, 1.75, 0.0), 0.30, make_material(Color("#8298c8"), 0.62))
	make_cone(geometry_root, "WayfarerScaleHood", position + Vector3(0.0, 1.98, 0.0), 0.42, 0.70, make_material(Color("#465878"), 0.72))


func make_material(color: Color, roughness: float, metallic := 0.0, emission := Color.TRANSPARENT) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.1
	return material


func make_block(parent: Node3D, name: String, position: Vector3, size: Vector3, material: Material, collision := true) -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.position = position
	parent.add_child(root)
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = box
	instance.material_override = material
	root.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "StaticBody"
		root.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape"
		collision_shape.shape = shape
		body.add_child(collision_shape)
	return root


func make_cylinder(parent: Node3D, name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return make_mesh(parent, name, position, mesh, material)


func make_cone(parent: Node3D, name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	return make_mesh(parent, name, position, mesh, material)


func make_sphere(parent: Node3D, name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return make_mesh(parent, name, position, mesh, material)


func make_mesh(parent: Node3D, name: String, position: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.position = position
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func make_label(text: String, position: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = "Label_%s" % text.replace(" ", "_").replace("/", "_")
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 64
	label.pixel_size = 0.006
	label.outline_size = 9
	label.outline_modulate = Color("#050812")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	labels_root.add_child(label)
	return label


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
