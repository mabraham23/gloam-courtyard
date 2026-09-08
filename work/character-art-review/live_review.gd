extends SceneTree

## Ordinary game controls and state; explicit candidate visuals only.
## No helper positioning, invincibility, timing or collision overrides.
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	game.reset_game()
	game.reset_camera()
	print("CHARACTER_ART_ORDINARY_INPUT sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
