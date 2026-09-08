extends SceneTree

## Focused exact-R7 review reel for strike, forward evade, and paired takedown.
##
## Every segment invokes the real main_3d controller action and advances its
## unchanged timers through main_3d.gd. Positions are disclosed deterministic
## review setup, not ordinary-input reachability evidence. Each action repeats
## from two complementary angles so limb silhouette, direction and paired
## contact can be judged without relying on one potentially occluded shot.
## Pass --slow-motion after `--` to advance gameplay at 1/60 s per 30 fps movie
## frame; segment labels and logged times explicitly disclose the half-speed view.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

const STRIKE_CONTACT := 0.14
const STRIKE_DURATION := 0.36
const EVADE_TRAVEL_DURATION := 0.28
const EVADE_ACTION_DURATION := 0.42
const TAKEDOWN_CONTACT := 0.34
const TAKEDOWN_DURATION := 1.10

const STRIKE_PLAYER := Vector3(-1.65, 0.0, 0.0)
const STRIKE_GUARD := Vector3(0.0, 0.0, 0.0)
const EVADE_PLAYER := Vector3(-4.0, 0.0, 1.5)
const EVADE_DIRECTION := Vector3.RIGHT
const TAKEDOWN_PLAYER := Vector3(-3.65, 0.0, 0.2)
const TAKEDOWN_GUARD := Vector3(-2.15, 0.0, 0.2)

var game: Node3D
var label: Label
var frame := 0
var scale_frames := 1
var step_delta := 1.0 / 30.0
var started := false
var action_start_frame := 0
var camera_focus := Vector3.ZERO
var camera_offset := Vector3.ZERO
var camera_size := 4.8


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	scale_frames = 2 if "--slow-motion" in OS.get_cmdline_user_args() else 1
	step_delta = 1.0 / 60.0 if scale_frames == 2 else 1.0 / 30.0
	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	Candidate.clear_material_overrides(game.player_visual_parts)
	game.player_visual_parts["visual_root"].free()
	game.player_visual_parts = Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_accent_material = game.player_visual_parts["accent_material"]
	assert(Candidate.is_exact_candidate(game.player_visual_parts))
	label = Label.new()
	label.position = Vector2(155, 510)
	label.size = Vector2(650, 78)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	root.add_child(label)
	_begin_strike(false)
	print(
		"R7_ACTION_MOTION_SEQUENCE sha=", FileAccess.get_sha256(Candidate.ASSET_PATH),
		" half_speed=", scale_frames == 2
	)
	started = true


func _process(_delta: float) -> bool:
	if not started:
		return false
	var beat := frame / scale_frames
	if frame % scale_frames == 0:
		match beat:
			42:
				_assert_strike_result()
				_begin_strike(true)
			84:
				_assert_strike_result()
				_begin_evade(false)
			126:
				_assert_evade_result()
				_begin_evade(true)
			168:
				_assert_evade_result()
				_begin_takedown(false)
			222:
				_assert_takedown_result()
				_begin_takedown(true)
			276:
				_assert_takedown_result()
				print("R7_ACTION_MOTION_SEQUENCE_OK frames=", frame)
				quit()
				return false

	game._process(step_delta)
	_update_camera()
	label.text = _label_text(beat)
	if frame % (3 * scale_frames) == 0:
		print(
			"R7_ACTION_FRAME frame=", frame,
			" beat=", beat,
			" segment=", _segment_name(beat),
			" elapsed=", snappedf(_action_elapsed(), 0.0001),
			" player=", game.player_root.position,
			" pose=", _player_pose_name(),
			" progress=", snappedf(_player_pose_progress(), 0.0001),
			" guard_hp=", game.guard_health,
			" guard_pose=", _guard_pose_name()
		)
	frame += 1
	return false


func _begin_strike(three_quarter: bool) -> void:
	_reset_pair(STRIKE_PLAYER, STRIKE_GUARD)
	# Target-independent strikes no longer auto-turn toward a remote guard before
	# acquisition. Put the deterministic review fixture visibly on the +X contact
	# line so this paired reel still exercises the real target-owning strike path.
	game.player_facing_yaw = PI / 2.0
	game.player_root.rotation.y = PI / 2.0
	game.player_attack_rng.seed = 90421 if three_quarter else 90417
	game.strike()
	assert(game.player_attack_target_locked, "Deterministic strike setup did not acquire the visible paired target")
	action_start_frame = frame
	camera_focus = (STRIKE_PLAYER + STRIKE_GUARD) * 0.5 + Vector3(0.0, 1.04, 0.0)
	# The second strike pass uses the opposite profile so the striking arm is not
	# hidden by the torso or cape at the short 0.14 s contact.
	camera_offset = Vector3(0.0, 2.15, -6.4) if three_quarter else Vector3(0.0, 2.15, 6.4)
	camera_size = 4.65


func _begin_evade(three_quarter: bool) -> void:
	_reset_solo(EVADE_PLAYER)
	game.last_travel_direction = EVADE_DIRECTION
	game.player_facing_yaw = PI / 2.0
	game.player_root.rotation.y = PI / 2.0
	game.evade()
	action_start_frame = frame
	# The focus is intentionally locked to the midpoint of the unchanged 1.96 m
	# root path. Following the actor would conceal the direction and distance.
	camera_focus = EVADE_PLAYER + EVADE_DIRECTION * 0.98 + Vector3(0.0, 1.02, 0.0)
	camera_offset = Vector3(-3.4, 2.25, 5.4) if three_quarter else Vector3(0.0, 2.10, 6.5)
	camera_size = 5.0


func _begin_takedown(three_quarter: bool) -> void:
	_reset_pair(TAKEDOWN_PLAYER, TAKEDOWN_GUARD)
	game.guard_forward = Vector3.RIGHT
	game.guard_root.rotation.y = PI / 2.0
	game.player_facing_yaw = PI / 2.0
	game.player_root.rotation.y = PI / 2.0
	game.stealth_takedown()
	assert(game.player_takedown_timer > 0.0, "Deterministic takedown setup did not enter the action")
	action_start_frame = frame
	camera_focus = (TAKEDOWN_PLAYER + TAKEDOWN_GUARD) * 0.5 + Vector3(0.0, 1.02, 0.0)
	camera_offset = Vector3(-3.8, 2.30, 5.7) if three_quarter else Vector3(0.0, 2.12, 6.25)
	camera_size = 4.75


func _reset_pair(player_position: Vector3, guard_position: Vector3) -> void:
	game.held_keys.clear()
	game.reset_game()
	_quiet_guard()
	game.player_root.position = player_position
	game.guard_root.position = guard_position
	_set_world_labels(false)


func _reset_solo(player_position: Vector3) -> void:
	game.held_keys.clear()
	game.reset_game()
	_quiet_guard()
	game.player_root.position = player_position
	game.guard_root.position = Vector3(30.0, 0.0, 30.0)
	game.guard_visual_parts["visual_root"].visible = false
	game.guard_label.visible = false
	_set_world_labels(false)


func _quiet_guard() -> void:
	# Keep the target in its ordinary grounded pose before impact. A large stun
	# timer is a convenient AI freeze, but it also forces a visible stagger pose
	# and would make the strike read falsely before contact.
	game.guard_stun = 0.0
	game.guard_stun_duration = 0.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0


func _set_world_labels(visible: bool) -> void:
	for node in game.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = visible


func _update_camera() -> void:
	game.camera.position = camera_focus + camera_offset
	game.camera.look_at(camera_focus)
	game.camera.size = camera_size


func _assert_strike_result() -> void:
	assert(is_equal_approx(game.guard_health, 78.0), "Strike review did not apply exactly one 22-point hit")
	assert(is_equal_approx(game.momentum, 13.0), "Strike review Momentum changed from the protected result")
	assert(game.player_strike_timer <= 0.0 and not game.player_strike_pending, "Strike did not recover before the next view")


func _assert_evade_result() -> void:
	var traveled: float = float(game.player_root.position.x) - EVADE_PLAYER.x
	assert(absf(traveled - 1.96) <= 0.001, "Evade review did not preserve the 1.96-unit facing-direction travel")
	assert(is_equal_approx(game.player_root.position.z, EVADE_PLAYER.z), "Evade review drifted off its facing axis")
	assert(is_equal_approx(game.momentum, 4.0), "Evade review Momentum changed from the protected result")
	assert(game.evade_timer <= 0.0 and game.invulnerable <= 0.0, "Evade did not recover before the next view")


func _assert_takedown_result() -> void:
	assert(game.guard_defeated and is_equal_approx(game.guard_health, 0.0), "Takedown review did not defeat the paired guard")
	assert(is_equal_approx(game.momentum, 35.0), "Takedown review Momentum changed from the protected result")
	assert(game.player_takedown_timer <= 0.0 and not game.player_takedown_pending, "Takedown did not release before the next view")


func _action_elapsed() -> float:
	return float(frame - action_start_frame + 1) * step_delta


func _player_pose_name() -> StringName:
	if game.player_takedown_timer > 0.0:
		return &"takedown"
	if game.invulnerable > 0.0:
		return &"evade"
	if game.player_strike_timer > 0.0:
		return &"strike"
	return &"grounded"


func _player_pose_progress() -> float:
	if game.player_takedown_timer > 0.0:
		return 1.0 - game.player_takedown_timer / TAKEDOWN_DURATION
	if game.invulnerable > 0.0:
		return 1.0 - game.invulnerable / EVADE_ACTION_DURATION
	if game.player_strike_timer > 0.0:
		return 1.0 - game.player_strike_timer / game.player_attack_duration
	return 1.0


func _guard_pose_name() -> StringName:
	if game.player_takedown_timer > 0.0:
		return &"takedown_victim"
	if game.guard_defeated:
		return &"defeated"
	if game.guard_stun > 0.0:
		return &"stagger"
	if game.attack_timer > 0.0:
		return &"attack"
	return &"grounded"


func _label_text(beat: int) -> String:
	var elapsed := _action_elapsed()
	var timing := "t %.2f s" % elapsed
	if beat < 84:
		timing += " · %s · contact %.2f s / end %.2f s" % [game.player_attack_variant, game.player_attack_contact, game.player_attack_duration]
	elif beat < 168:
		timing += " · travel %.2f s / evade end %.2f s · %.2f m +X" % [EVADE_TRAVEL_DURATION, EVADE_ACTION_DURATION, game.player_root.position.x - EVADE_PLAYER.x]
	else:
		timing += " · contact %.2f s / end %.2f s" % [TAKEDOWN_CONTACT, TAKEDOWN_DURATION]
	return "%s%s\n%s · real controller state/timing" % [
		_segment_name(beat),
		" · HALF-SPEED REVIEW" if scale_frames == 2 else "",
		timing
	]


func _segment_name(beat: int) -> String:
	if beat < 42: return "STRIKE · PROFILE · WINDUP / CONTACT / RECOVER"
	if beat < 84: return "STRIKE · OPPOSITE PROFILE · STRIKING ARM / TORSO"
	if beat < 126: return "FORWARD EVADE · LOCKED PROFILE · DIRECTION / TRAVEL / LAND"
	if beat < 168: return "FORWARD EVADE · LOCKED THREE-QUARTER · TUCK / ROTATION"
	if beat < 222: return "TAKEDOWN · PROFILE · CATCH / CONTACT / PULL / RELEASE"
	return "TAKEDOWN · REAR THREE-QUARTER · HAND / TORSO / VICTIM PAIRING"
