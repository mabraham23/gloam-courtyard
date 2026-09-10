extends "res://work/action-quality/jump_sequence.gd"

## Side-profile review of both moving leads, including held movement through
## impact and a release in flight. Parent supplies only candidate/guard setup.
func _process(_delta: float) -> bool:
	if not started: return false
	var local_frame := frame % 75
	if local_frame == 0:
		_reset()
		game.jump_lead = -1.0 if frame < 75 else 1.0
	if local_frame == 5: game.held_keys[KEY_D] = true
	if local_frame == 13: _jump()
	if (frame >= 75 and local_frame == 22) or local_frame == 49:
		game.held_keys.clear()
	game.camera_yaw = 0.0
	game.update_camera(0.0)
	game._process(DELTA)
	if gameplay_view:
		game.reset_camera()
	else:
		var focus := Vector3(-1.8, 1.5, 0.0)
		game.camera.position = focus + Vector3(0.0, 1.8, 8.0)
		game.camera.look_at(focus)
		game.camera.size = 6.6
	label.text = "RUNNING JUMP · %s\nGather / flight / impact / return to movement" % ("HOLD D THROUGH LANDING" if frame < 75 else "MIRRORED LEAD · RELEASE D IN AIR")
	print("RUNNING_JUMP_FRAME frame=", frame, " position=", game.player_root.position,
		" phase=", game.jump_t, " airborne=", game.player_airborne,
		" knees=", Vector2(game.player_visual_parts.left_knee.rotation.x, game.player_visual_parts.right_knee.rotation.x),
		" elbows=", Vector2(game.player_visual_parts.left_elbow.rotation.x, game.player_visual_parts.right_elbow.rotation.x))
	frame += 1
	if frame >= 150:
		print("RUNNING_JUMP_SEQUENCE_OK frames=", frame)
		quit()
	return false
