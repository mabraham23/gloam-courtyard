extends CanvasLayer

## Only attached by tools/review.py live; the default game is unchanged.
var game: Node3D
var build: Dictionary
var recent_inputs: Array[Dictionary] = []
var badge: Label
var busy := false

func configure(subject: Node3D) -> void:
	game = subject
	var file := FileAccess.open("res://.review-build.json", FileAccess.READ)
	assert(file != null, "Managed review requires a build manifest")
	build = JSON.parse_string(file.get_as_text())
	assert(build is Dictionary and build.has("source"))
	layer = 100
	badge = Label.new()
	badge.position = Vector2(12, 577)
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color("c8d5d9"))
	add_child(badge)
	var asset := str(build.get("visual", "V1"))
	badge.text = "REVIEW %s | code %s | %s | F12: image + state" % [asset, str(build.source.sha256).left(12), "dirty snapshot" if build.dirty else str(build.commit).left(7)]
	print("REVIEW_IDENTITY_READY source=", build.source.sha256, " visual=", asset)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		recent_inputs.append({"ms": Time.get_ticks_msec(), "key": event.as_text_keycode(), "pressed": event.pressed})
		if recent_inputs.size() > 120:
			recent_inputs.pop_front()
		if event.keycode == KEY_F12 and event.pressed:
			get_viewport().set_input_as_handled()
			capture()

func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func capture() -> void:
	if busy:
		return
	busy = true
	# Capture state immediately after this viewport has actually drawn.
	await RenderingServer.frame_post_draw
	var state := {
		"schema": 1, "build": build, "created_utc": Time.get_datetime_string_from_system(true),
		"pid": OS.get_process_id(), "project": ProjectSettings.globalize_path("res://"),
		"render_frame": Engine.get_frames_drawn(), "native_input_verified": false,
		"input_note": "Engine key events alone do not prove native input; record observed native review separately.",
		"recent_inputs": recent_inputs.duplicate(true), "held_keys": game.held_keys.keys(),
		"player": vector(game.player_root.position), "guard": vector(game.guard_root.position),
		"health": game.player_health, "momentum": game.momentum, "guard_health": game.guard_health,
		"jump_active": game.jump_active, "jump_t": game.jump_t, "jump_moving": game.jump_moving,
		"jump_lead": game.jump_lead, "airborne": game.player_airborne, "vault": game.jump_is_vault,
		"crouching": game.crouching, "attack": str(game.player_attack_variant),
		"strike_timer": game.player_strike_timer, "evade_timer": game.evade_timer,
		"takedown_timer": game.player_takedown_timer, "target_locked": game.player_attack_target_locked,
		"camera": {"position": vector(game.camera.position), "yaw": game.camera_yaw,
			"pitch": game.camera_pitch, "size": game.camera.size},
		"attack_rng_state": str(game.player_attack_rng.state), "changed_source_files": []
	}
	var picture := get_viewport().get_texture().get_image()
	for relative in build.source.files:
		if FileAccess.get_sha256("res://" + relative) != build.source.files[relative]:
			state.changed_source_files.append(relative)
	var directory := OS.get_environment("GLOAM_CAPTURE_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(directory)
	var stem := directory.path_join("review_%s_%d_%d" % [str(build.source.sha256).left(12), OS.get_process_id(), Time.get_ticks_usec()])
	assert(picture.save_png(stem + ".png") == OK)
	state["image_sha256"] = FileAccess.get_sha256(stem + ".png")
	var output := FileAccess.open(stem + ".json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(state, "\t") + "\n")
	output.close()
	print("REVIEW_CAPTURE_OK path=", stem, " changed=", state.changed_source_files.size())
	busy = false
