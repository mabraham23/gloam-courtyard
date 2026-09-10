extends "res://work/action-quality/jump_sequence.gd"

## Same actor/materials in front, quarter, profile, rear and moving gameplay.
func _process(_delta: float) -> bool:
	if not started: return false
	if frame == 0 or frame == 180: _reset()
	if frame == 185: game.held_keys[KEY_D] = true
	if frame == 193: _jump()
	if frame == 222: game.held_keys.clear()
	if frame == 240: game.toggle_crouch()
	game.camera_yaw = 0.0
	game.update_camera(0.0)
	game._process(DELTA)
	if frame >= 180:
		game.reset_camera()
		label.text = "BLACK HAIR · GAMEPLAY\nRun / jump / crouch with the same attached hairstyle"
	else:
		var view := floori(frame / 45.0)
		var skeleton: Skeleton3D = game.player_visual_parts.authored_rig.skeleton
		var head := skeleton.get_bone_global_pose(skeleton.find_bone("head"))
		var focus := skeleton.to_global(head.origin) + Vector3(0.0, 0.25, 0.0)
		var offsets := [Vector3(4.0, 0.24, 0.0), Vector3(3.0, 0.24, 3.0), Vector3(0.0, 0.24, 4.0), Vector3(-4.0, 0.24, 0.0)]
		game.camera.position = focus + offsets[view]
		game.camera.look_at(focus)
		game.camera.size = 1.15
		label.text = "BLACK HAIR · %s\nSame candidate, materials and courtyard lighting" % ["FRONT", "THREE-QUARTER", "PROFILE", "REAR"][view]
	frame += 1
	if frame >= 270:
		print("HAIR_SEQUENCE_OK frames=", frame)
		quit()
	return false
