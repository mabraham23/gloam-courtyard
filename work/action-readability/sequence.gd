extends SceneTree

## Actual default v1 scene, fixed 30 Hz. Positions/timing are test fixtures,
## not evidence of ordinary-keyboard route reachability. --close changes only
## the diagnostic camera. Both before/after runs use this identical sequence.
var game: Node3D
var frame := 0
var started := false

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	started = true

func _process(_delta: float) -> bool:
	if not started:
		return false
	match frame:
		0:
			game.reset_game()
			game.player_root.position = Vector3(-1.65, 0, 0)
			game.player_facing_yaw = PI / 2.0
			game.player_root.rotation.y = PI / 2.0
			game.guard_forward = Vector3.LEFT
			game.guard_root.rotation.y = -PI / 2.0
			game.attack_cooldown = 4.0
		12:
			game.strike()
		42, 44, 46:
			game.strike()
		75:
			game.reset_game()
			game.player_root.position = Vector3(-3, 0, 1)
			game.player_facing_yaw = PI / 2.0
			game.player_root.rotation.y = PI / 2.0
			game.last_travel_direction = Vector3.LEFT
		85:
			game.evade()
		125:
			game.reset_game()
			game.player_root.position = Vector3(-3.65, 0, 0.2)
			game.guard_root.position = Vector3(-2.15, 0, 0.2)
			game.guard_forward = Vector3.RIGHT
			game.guard_root.rotation.y = PI / 2.0
			game.player_facing_yaw = PI / 2.0
			game.player_root.rotation.y = PI / 2.0
			game.guard_stun = 0.35
		135:
			game.stealth_takedown()
		205:
			game.reset_game()
	game._process(1.0 / 30.0)
	if "--close" in OS.get_cmdline_user_args():
		game.camera.position = Vector3(-0.5, 4.4, 10)
		game.camera.look_at(Vector3(-1.5, 1.3, 0.2))
		game.camera.size = 7.8
	if frame % 5 == 0:
		print("ACTION_FRAME ", frame, " hp=", game.guard_health, " M=", game.momentum, " player=", game.player_root.position, " spin=", game.player_visual_parts["action_root"].rotation.x)
	frame += 1
	return false
