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
				var standing_pelvis_y := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin).y
				if variant != 0:
					game.held_keys[KEY_D] = true
					for stride in 6: game._process(dt)
				game.jump_lead = -float(variant) if variant != 0 else -1.0
				game.jump_or_vault()
				game.held_keys.clear()
				var frame := 0
				var ground_min := INF
				var ground_max := -INF
				var flight_elbow_min := INF
				var impact_knee_peak := 0.0
				var impact_pelvis_drop := 0.0
				while game.jump_active or frame < int(ceil(1.25 * fps)):
					game._process(dt)
					var sample := _bounds(game, skeleton, cache.surfaces)
					var tag := "%s %shz variant%s frame%s" % [preset[0], fps, variant, frame]
					_validate_frame(sample, int(cache.vertex_count), tag, true)
					var elapsed: float = game.jump_t * game.jump_duration
					if game.player_airborne and elapsed > 0.30 and elapsed < 0.56:
						for side in ["L", "R"]:
							flight_elbow_min = minf(flight_elbow_min, _joint_bend(skeleton, "upper_arm." + side, "forearm." + side, "hand." + side))
					if game.jump_active and elapsed >= 0.74:
						var both_knees := minf(_joint_bend(skeleton, "thigh.L", "shin.L", "foot.L"), _joint_bend(skeleton, "thigh.R", "shin.R", "foot.R"))
						impact_knee_peak = maxf(impact_knee_peak, both_knees)
						var pelvis_y := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin).y
						impact_pelvis_drop = maxf(impact_pelvis_drop, standing_pelvis_y - pelvis_y)
					if not game.player_airborne:
						ground_min = minf(ground_min, float(sample.foot_min))
						ground_max = maxf(ground_max, float(sample.foot_min))
						_check(float(sample.foot_min) <= FOOT_CONTACT_MAX, tag + " grounded soles keep floor contact")
					frame += 1
					if frame > fps * 2:
						_check(false, tag + " timed out")
						break
				if variant != 0:
					_check(flight_elbow_min >= deg_to_rad(40.0), "%s %shz variant%s keeps both flight elbows bent" % [preset[0], fps, variant])
				_check(impact_knee_peak >= deg_to_rad(48.0), "%s %shz variant%s visibly flexes both impact knees" % [preset[0], fps, variant])
				_check(impact_pelvis_drop >= 0.11, "%s %shz variant%s lowers the pelvis on impact" % [preset[0], fps, variant])
				print("JUMP_DEFORMATION_CASE preset=", preset[0], " fps=", fps, " variant=", variant, " frames=", frame, " ground_sole_min=", ground_min, " max=", ground_max,
					" elbow_min_deg=", rad_to_deg(flight_elbow_min), " knee_peak_deg=", rad_to_deg(impact_knee_peak), " pelvis_drop=", impact_pelvis_drop)
	Candidate.clear_material_overrides(parts)
	game.queue_free()
	_finish()


func _joint_bend(skeleton: Skeleton3D, start: String, joint: String, finish: String) -> float:
	var a := skeleton.get_bone_global_pose(skeleton.find_bone(start)).origin
	var b := skeleton.get_bone_global_pose(skeleton.find_bone(joint)).origin
	var c := skeleton.get_bone_global_pose(skeleton.find_bone(finish)).origin
	return PI - (a - b).angle_to(c - b)
