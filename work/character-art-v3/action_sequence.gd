extends "res://work/action-readability/sequence.gd"

## Same actual-game timing and positions as the accepted action fixture.
## Diagnostic positioning is not evidence of ordinary-input reachability.
const Candidate = preload("res://work/character-art-v3/candidate_fixture.gd")

func _start() -> void:
	super._start()
	if "--v1" not in OS.get_cmdline_user_args():
		Candidate.clear_material_overrides(game.player_visual_parts)
		game.player_visual_parts["visual_root"].free()
		game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
		game.player_accent_material = game.player_visual_parts["accent_material"]
		assert(Candidate.is_exact_candidate(game.player_visual_parts))
	print("V3_ACTION_SEQUENCE candidate=", "--v1" not in OS.get_cmdline_user_args())
