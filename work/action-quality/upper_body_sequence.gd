extends SceneTree

## Matched whole-body review. Scripted controller input and diagnostic placement
## are explicit helpers; this sequence is not native held-input evidence.
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
var game: Node3D
var label: Label
var frame := 0
var started := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player_attack_rng.seed = 9102026
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	label = Label.new()
	label.position = Vector2(170, 530)
	label.size = Vector2(620, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_reset()
	started = true

func _reset() -> void:
	game.held_keys.clear()
	game.reset_game()
	game.player_root.position = Vector3(-4.5, 0, -2.5)
	game.player_facing_yaw = PI / 2
	game.player_root.rotation.y = PI / 2
	game.guard_root.position = Vector3(7, 0, 5)
	game.guard_stun = 999
	game.guard_stun_duration = 999
	game.attack_cooldown = 999
	for node in game.find_children("*", "Label3D", true, false):
		node.visible = false

func _process(_delta: float) -> bool:
	if not started: return false
	match frame:
		10: game.held_keys[KEY_D] = true
		50: game.held_keys.clear()
		65:
			_reset()
			game.toggle_crouch()
		85: game.held_keys[KEY_D] = true
		113: game.held_keys.clear()
		120: game.toggle_crouch()
		125:
			_reset()
			game.jump_or_vault()
		150:
			_reset()
			game.held_keys[KEY_D] = true
		157: game.jump_or_vault()
		185:
			_reset()
			game._commit_strike_variant(&"right_punch", false)
		205: game._commit_strike_variant(&"left_punch", false)
		225: game._commit_strike_variant(&"right_kick", false)
		245: game._commit_strike_variant(&"left_kick", false)
		267:
			_reset()
			game.guard_root.position = game.player_root.position + Vector3(1.5, 0, 0)
			game.attack_timer = 0.4
			game.counter()
		290:
			_reset()
			game.evade()
		315:
			_reset()
			game.player_root.position = Vector3(-3.65, 0, 0.2)
			game.guard_root.position = Vector3(-2.15, 0, 0.2)
			game.guard_forward = Vector3.RIGHT
			game.guard_root.rotation.y = PI / 2
			game.stealth_takedown()
		355:
			_reset()
			game.player_root.position = game.ANCHOR_POSITION
			game.grapple()
		395:
			_reset()
			game.held_keys[KEY_D] = true
		420: game.jump_or_vault()
		455:
			game.held_keys.clear()
			game.strike()
		479:
			print("UPPER_BODY_SEQUENCE_OK frames=", frame + 1)
			quit()
	game._process(1.0 / 30.0)
	if frame < 395:
		var focus: Vector3 = game.player_root.position + Vector3(0, 1.2, 0)
		var quarter := frame >= 185
		game.camera.position = focus + (Vector3(4.5, 1.8, 6) if quarter else Vector3(0, 1.1, 7))
		game.camera.look_at(focus)
		game.camera.size = 4.0 if not quarter else 4.6
	label.text = "%s · frame %d\nScripted controller review · 30 Hz" % [_name(), frame]
	frame += 1
	return false

func _name() -> String:
	if frame < 65: return "GAIT / STOP"
	if frame < 125: return "CROUCH / MOVE / RISE"
	if frame < 150: return "STANDING JUMP"
	if frame < 185: return "MOVING JUMP / LAND"
	if frame < 267: return "FOUR STRIKES / RECOVERY"
	if frame < 290: return "COUNTER"
	if frame < 315: return "EVADE"
	if frame < 355: return "TAKEDOWN"
	if frame < 395: return "GRAPPLE / RECEIVE"
	return "DEFAULT GAMEPLAY SCALE"
