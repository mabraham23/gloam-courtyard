extends SceneTree

## Ordinary-input candidate playtest without changing the accepted project
## default. No movement, health, collision or combat helpers run in this file.
const Builder = preload("res://actors/character_visual_builder.gd")

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
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
	print("CANDIDATE_LIVE_REVIEW v2=", game.player_visual_parts["authored_rig"].get("is_v2", false))
