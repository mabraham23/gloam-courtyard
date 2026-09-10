extends "res://work/action-quality/jump_sequence.gd"

## Matched front/profile/gameplay crouch, including entry, held travel and exit.
func _process(_delta: float) -> bool:
	if not started: return false
	var local_frame := frame % 90
	var view := floori(frame / 90.0)
	if local_frame == 0: _reset()
	if local_frame == 8 or local_frame == 76:
		var event := InputEventKey.new()
		event.keycode = KEY_Q
		event.pressed = true
		game._unhandled_input(event)
		event.pressed = false
		game._unhandled_input(event)
	if local_frame == 30: game.held_keys[KEY_D] = true
	if local_frame == 65: game.held_keys.clear()
	game.camera_yaw = 0.0
	game.update_camera(0.0)
	game._process(DELTA)
	if view == 2:
		game.reset_camera()
	else:
		var focus: Vector3 = game.player_root.position + Vector3(0.0, 1.35, 0.0)
		game.camera.position = focus + (Vector3(8.0, 1.2, 0.0) if view == 0 else Vector3(0.0, 1.2, 8.0))
		game.camera.look_at(focus)
		game.camera.size = 5.2
	label.text = "CROUCH · %s\nEnter / relaxed hold / held movement / stand" % ["FRONT", "PROFILE", "GAMEPLAY"][view]
	print("CROUCH_FRAME frame=", frame, " crouching=", game.crouching,
		" position=", game.player_root.position)
	frame += 1
	if frame >= 270:
		print("CROUCH_SEQUENCE_OK frames=", frame)
		quit()
	return false
