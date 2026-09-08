extends "res://work/character-quality-benchmark/quality_stage.gd"

## Reuses identical baseline lighting/camera/pose timing. Explicitly replace
## only the right-hand diagnostic actor before the first rendered frame.
const Candidate = preload("res://work/character-art-v3/candidate_fixture.gd")

func _start() -> void:
	super._start()
	Candidate.clear_material_overrides(parts[1])
	parts[1]["visual_root"].free()
	parts[1] = Candidate.build_player(actors[1], Color("#c55c77"))
	assert(Candidate.is_exact_candidate(parts[1]))
	for node in root.get_children():
		if node is Label and node.text.begins_with("LEFT:"):
			node.text = "LEFT: playable v1     RIGHT: original v3 candidate\nSame light / scale / camera — visual review, not performance"
	print("V3_REVIEW_STAGE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
