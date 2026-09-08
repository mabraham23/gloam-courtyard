extends SceneTree

## Ordinary controls; only the candidate visual and diagnostic overlay are added.
const Identity = preload("res://debug/review_identity.gd")
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	var game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	if "--candidate" in OS.get_cmdline_user_args():
		Candidate.clear_material_overrides(game.player_visual_parts)
		game.player_visual_parts["visual_root"].free()
		game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
		game.player_accent_material = game.player_visual_parts["accent_material"]
		assert(Candidate.is_exact_candidate(game.player_visual_parts))
	game.reset_game()
	game.reset_camera()
	var identity := Identity.new()
	root.add_child(identity)
	identity.configure(game)
	if "--capture-smoke" in OS.get_cmdline_user_args():
		await create_timer(0.5).timeout
		await identity.capture()
		print("REVIEW_CAPTURE_SMOKE_OK")
		quit()
