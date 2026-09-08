extends "res://work/action-readability/mechanics.gd"

## Runs the accepted durable courtyard mechanics suite with the explicit character-art
## visual attached to the real player root. The project default remains v1.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")


func _run() -> void:
	if not ResourceLoader.exists(Candidate.ASSET_PATH):
		_check(false, "explicit character-art candidate resource exists")
		_finish()
		return
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "active main_3d scene loads")
	if packed == null:
		_finish()
		return

	var game := packed.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED

	var default_parts: Dictionary = game.player_visual_parts
	(default_parts["visual_root"] as Node3D).visible = false
	var candidate_parts := Candidate.build_player(
		game.player_root,
		game.outfit_colors[game.outfit_index]
	)
	game.player_visual_parts = candidate_parts
	game.player_accent_material = candidate_parts["accent_material"]
	_check(Candidate.is_exact_candidate(candidate_parts), "mechanics fixture selected exact 74-bone character-art path")
	_check(FileAccess.get_sha256(Candidate.ASSET_PATH).length() == 64, "mechanics fixture fingerprints character-art GLB")

	_test_reset_and_customization(game)
	_test_spacing_and_combat(game)
	_test_strike_action_timing(game)
	_test_counters_and_damage(game)
	_test_defeat_fade_and_restart(game)
	_test_grapple_perch_fall_and_height(game)
	_test_evade(game)
	_test_crouch_and_clearance(game)
	_test_jump_and_vault(game)
	_test_takedown_action_timing(game)
	_test_stealth_exit_and_restart(game)

	Candidate.clear_material_overrides(candidate_parts)
	Candidate.clear_material_overrides(default_parts)
	game.queue_free()
	_finish()


func _finish() -> void:
	print("GLOAM_CHARACTER_ART_MECHANICS_", "OK" if failures.is_empty() else "FAILED", " checks=", checks, " failures=", failures.size())
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)

