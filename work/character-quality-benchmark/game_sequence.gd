extends SceneTree

## Actual-scene diagnostic sequence with helper positions and a prepared counter.
## This is rendering/mechanics evidence, not ordinary-input play or FPS evidence.
const Builder = preload("res://actors/character_visual_builder.gd")

var game: Node3D
var frame := 0
var ready_for_frames := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var old_visual: Node3D = game.player_visual_parts["visual_root"]
	# Release duplicated overrides while the mesh instances still exist. Direct
	# teardown otherwise leaves GL dependency updates referencing freed materials.
	for mesh: MeshInstance3D in game.player_visual_parts["authored_rig"]["mesh_instances"]:
		mesh.material_override = null
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, null)
	old_visual.free()
	game.player_visual_parts = Builder.build_player(game.player_root, game.outfit_colors[game.outfit_index], true)
	game.player_accent_material = game.player_visual_parts["accent_material"]
	game.reset_game()
	print("V2_SOURCE_SHA256 ", FileAccess.get_sha256("res://actors/gloam_vigil/v2/gloam_vigil_player_v2.glb"))
	print("CANDIDATE_GAME_SEQUENCE v2=", game.player_visual_parts["authored_rig"].get("is_v2", false))
	ready_for_frames = true

func _process(_delta: float) -> bool:
	if not ready_for_frames:
		return false
	match frame:
		5:
			game.held_keys[KEY_D] = true
		24:
			game.held_keys.clear()
		35:
			game.reset_game()
			game.toggle_crouch()
		45:
			game.held_keys[KEY_D] = true
		60:
			game.held_keys.clear()
		70:
			game.reset_game()
			game.last_travel_direction = Vector3.RIGHT
			game.jump_or_vault()
		100:
			game.reset_game()
			game.player_root.position = Vector3(4.0, 0.0, 3.9)
			game.last_travel_direction = Vector3.RIGHT
			game.jump_or_vault()
		125:
			game.reset_game()
			game.last_travel_direction = Vector3.RIGHT
			game.evade()
		150:
			game.reset_game()
			game.player_root.position = Vector3(3.0, 0.0, -0.7)
			game.grapple()
		178:
			game.move_player_world(Vector3.RIGHT, 2.0)
		215:
			game.reset_game()
			game.player_root.position = Vector3(-1.48, 0, 0)
			game.strike()
		235:
			game.attack_timer = 0.44
			game.counter()
		260:
			game.reset_game()
			game.player_root.position = Vector3(-3.5, 0, 0.2)
			game.guard_root.position = Vector3(-2.8, 0, -1)
			var to_player: Vector3 = game.player_root.position - game.guard_root.position
			to_player.y = 0.0
			game.guard_forward = -to_player.normalized()
			game.guard_root.rotation.y = atan2(game.guard_forward.x, game.guard_forward.z)
			game.stealth_takedown()
		312:
			game.reset_game()
	game._process(1.0 / 30.0)
	if frame % 25 == 0:
		print("GAME_SEQUENCE frame=", frame, " health=", game.player_health, " momentum=", game.momentum, " player=", game.player_root.position)
	frame += 1
	return false
