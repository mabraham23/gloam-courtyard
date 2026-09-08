extends "res://work/character-art-review/deformation.gd"

## Focused reproduction of the exact late-jump regression. Reuses the same
## all-vertex/morph evaluator, actor arc, recovery and unmodified floor bars.
func _run() -> void:
	print("GLOAM_CHARACTER_ART_LANDING_SOURCE sha256=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	for preset in BODY_PRESETS:
		var host := Node3D.new()
		root.add_child(host)
		var actor := Node3D.new()
		actor.scale = Vector3.ONE * PLAYER_BASE_SCALE * float(preset[1])
		host.add_child(actor)
		var parts := Candidate.build_player(actor, Color.WHITE)
		var rig: Dictionary = parts["authored_rig"]
		var skeleton: Skeleton3D = rig["skeleton"]
		await process_frame
		var cache := _cache_surfaces(rig, skeleton)
		_sample_action(host, actor, parts, rig, skeleton, cache["surfaces"], String(preset[0]), 60,
			&"jump", 0.62, -1.0, int(cache["vertex_count"]), actor.transform, {"hands": 0.0, "cape": 0.0})
		Candidate.clear_material_overrides(parts)
		host.queue_free()
		await process_frame
		await process_frame
	_finish()
