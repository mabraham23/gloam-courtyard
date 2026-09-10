extends "res://work/character-art-review/deformation.gd"

## Sample every rendered controller frame through gather, flight, touchdown and
## recovery, with the frozen R14 mesh at all sizes/rates and both moving leads.
func _run() -> void:
	print("JUMP_DEFORMATION_SOURCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	var game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, Color.WHITE)
	game.player_accent_material = game.player_visual_parts["accent_material"]
	var parts: Dictionary = game.player_visual_parts
	var rig: Dictionary = parts["authored_rig"]
	var skeleton: Skeleton3D = rig["skeleton"]
	await process_frame
	var cache := _cache_surfaces(rig, skeleton)
	for preset in BODY_PRESETS:
		for fps in SAMPLE_RATES:
			for variant in [0, 1, -1]:
				game.reset_game()
				game.player_root.position = Vector3(-4.0, 0.0, 0.0)
				game.player_scale = float(preset[1])
				game.player_root.scale = Vector3.ONE * PLAYER_BASE_SCALE * float(preset[1])
				game.guard_root.position = Vector3(30.0, 0.0, 30.0)
				game.guard_stun = 999.0
				game.camera_yaw = 0.0
				game.update_camera(0.0)
				var dt := 1.0 / float(fps)
				for settle in fps: game._process(dt)
				if variant != 0:
					game.held_keys[KEY_D] = true
					for stride in 6: game._process(dt)
				game.jump_lead = -float(variant) if variant != 0 else -1.0
				game.jump_or_vault()
				game.held_keys.clear()
				var frame := 0
				var ground_min := INF
				var ground_max := -INF
				while game.jump_active or frame < int(ceil(1.25 * fps)):
					game._process(dt)
					var sample := _bounds(game, skeleton, cache.surfaces)
					var tag := "%s %shz variant%s frame%s" % [preset[0], fps, variant, frame]
					_validate_frame(sample, int(cache.vertex_count), tag, true)
					if not game.player_airborne:
						ground_min = minf(ground_min, float(sample.foot_min))
						ground_max = maxf(ground_max, float(sample.foot_min))
						_check(float(sample.foot_min) <= FOOT_CONTACT_MAX, tag + " grounded soles keep floor contact")
					frame += 1
					if frame > fps * 2:
						_check(false, tag + " timed out")
						break
				print("JUMP_DEFORMATION_CASE preset=", preset[0], " fps=", fps, " variant=", variant, " frames=", frame, " ground_sole_min=", ground_min, " max=", ground_max)
	Candidate.clear_material_overrides(parts)
	game.queue_free()
	_finish()
