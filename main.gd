extends Node2D

## Gloam Courtyard: deliberately tiny, code-drawn Godot 4 feasibility spike.
## There are no imported art assets or gameplay dependencies outside this file.

const WORLD_SIZE := Vector2(960, 600)
const PLAYER_START := Vector2(190, 360)
const ENEMY_START := Vector2(440, 330)
const PERCH := Vector2(720, 205)
const ANCHOR := Vector2(620, 260)
const HIDE_SPOT := Vector2(160, 470)
const EXIT := Vector2(855, 180)
const PATROL_POINTS := [Vector2(335, 315), Vector2(555, 350)]

var font: Font
var player_pos := PLAYER_START
var player_height := 0.0
var player_health := 100.0
var player_momentum := 0.0
var enemy_pos := ENEMY_START
var enemy_health := 100.0
var enemy_dir := Vector2.LEFT
var patrol_index := 0
var enemy_alert := false
var enemy_suspicion := 0.0
var enemy_attack_timer := 0.0
var enemy_attack_cooldown := 0.0
var enemy_stun := 0.0
var enemy_defeated := false
var countered_attack := false
var invulnerable := 0.0
var evade_timer := 0.0
var evade_dir := Vector2.ZERO
var message := "Slip through the dark. Reach the gate."
var message_timer := 4.0
var success := false
var player_scale := 1.0
var outfit_index := 0
var outfit_colors := [Color("#c84b5d"), Color("#5a9bd5")]
var last_move_dir := Vector2.RIGHT

func _ready() -> void:
	font = ThemeDB.fallback_font
	reset_game()
	queue_redraw()

func reset_game() -> void:
	player_pos = PLAYER_START
	player_height = 0.0
	player_health = 100.0
	player_momentum = 0.0
	enemy_pos = ENEMY_START
	enemy_health = 100.0
	enemy_dir = Vector2.LEFT
	patrol_index = 0
	enemy_alert = false
	enemy_suspicion = 0.0
	enemy_attack_timer = 0.0
	enemy_attack_cooldown = 0.0
	enemy_stun = 0.0
	enemy_defeated = false
	countered_attack = false
	invulnerable = 0.0
	evade_timer = 0.0
	success = false
	message = "Slip through the dark. Reach the gate."
	message_timer = 4.0

func _process(delta: float) -> void:
	if success:
		queue_redraw()
		return

	message_timer = maxf(message_timer - delta, 0.0)
	invulnerable = maxf(invulnerable - delta, 0.0)
	evade_timer = maxf(evade_timer - delta, 0.0)
	enemy_attack_cooldown = maxf(enemy_attack_cooldown - delta, 0.0)
	enemy_stun = maxf(enemy_stun - delta, 0.0)

	move_player(delta)
	update_enemy(delta)
	check_success()
	queue_redraw()

func move_player(delta: float) -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input.length() > 0.1:
		last_move_dir = move_input.normalized()
		if evade_timer <= 0.0:
			player_pos += move_input.normalized() * 180.0 * delta
			player_height = 0.0
			if player_pos.distance_to(PERCH) < 85.0:
				player_height = 22.0
	if evade_timer > 0.0:
		player_pos += evade_dir * 300.0 * delta
	player_pos.x = clampf(player_pos.x, 70.0, WORLD_SIZE.x - 65.0)
	player_pos.y = clampf(player_pos.y, 145.0, WORLD_SIZE.y - 60.0)

func update_enemy(delta: float) -> void:
	if enemy_defeated:
		return
	if enemy_attack_timer > 0.0:
		enemy_attack_timer = maxf(enemy_attack_timer - delta, 0.0)
		if enemy_attack_timer == 0.0 and not countered_attack:
			damage_player(18.0, "The guard's blade breaks your momentum.")
			enemy_attack_cooldown = 1.0
		countered_attack = false
		return
	if enemy_stun > 0.0:
		return

	var to_player := player_pos - enemy_pos
	var distance := to_player.length()
	var concealed := is_concealed()
	var facing_angle := absf(enemy_dir.angle_to(to_player.normalized())) if distance > 0.1 else 0.0
	var sees_player := distance < 235.0 and facing_angle < 0.62 and not concealed
	if sees_player:
		enemy_suspicion = minf(enemy_suspicion + delta * 42.0, 100.0)
	else:
		enemy_suspicion = maxf(enemy_suspicion - delta * 15.0, 0.0)
	if enemy_suspicion >= 100.0:
		enemy_alert = true
		message = "ALERT: close distance, evade or counter."
		message_timer = 2.0

	var target: Vector2 = PATROL_POINTS[patrol_index]
	if enemy_alert:
		target = player_pos
	if distance < 62.0 and enemy_alert and enemy_attack_cooldown <= 0.0:
		enemy_attack_timer = 0.72
		countered_attack = false
		message = "COUNTER WINDOW: press E. Perfect is the narrow center flash."
		message_timer = 1.2
		return
	var to_target := target - enemy_pos
	if to_target.length() > 8.0:
		enemy_dir = enemy_dir.lerp(to_target.normalized(), minf(delta * 5.0, 1.0)).normalized()
		enemy_pos += enemy_dir * (95.0 if enemy_alert else 58.0) * delta
	elif not enemy_alert:
		patrol_index = (patrol_index + 1) % PATROL_POINTS.size()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_W:
			player_pos += Vector2.UP * 24.0
			last_move_dir = Vector2.UP
		KEY_S:
			player_pos += Vector2.DOWN * 24.0
			last_move_dir = Vector2.DOWN
		KEY_A:
			player_pos += Vector2.LEFT * 24.0
			last_move_dir = Vector2.LEFT
		KEY_D:
			player_pos += Vector2.RIGHT * 24.0
			last_move_dir = Vector2.RIGHT
		KEY_R:
			reset_game()
		KEY_SPACE:
			strike()
		KEY_E:
			counter()
		KEY_C:
			evade()
		KEY_T:
			stealth_takedown()
		KEY_G:
			grapple()
		KEY_F12:
			capture_screenshot()
		KEY_1:
			player_scale = 0.88
			message = "Build: lean"
			message_timer = 1.3
		KEY_2:
			player_scale = 1.0
			message = "Build: standard"
			message_timer = 1.3
		KEY_3:
			player_scale = 1.16
			message = "Build: broad"
			message_timer = 1.3
		KEY_X:
			outfit_index = (outfit_index + 1) % outfit_colors.size()
			message = "Accent color swapped"
			message_timer = 1.3

func strike() -> void:
	if success or enemy_defeated:
		return
	if enemy_pos.distance_to(player_pos) < 76.0:
		enemy_health -= 22.0 + player_momentum * 0.08
		enemy_stun = 0.32
		enemy_alert = true
		player_momentum = minf(player_momentum + 13.0, 100.0)
		message = "STRIKE connects. Momentum builds."
		message_timer = 1.0
		if enemy_health <= 0.0:
			enemy_defeated = true
			message = "Guard down. Reach the violet gate."
			message_timer = 3.0
	else:
		player_momentum = maxf(player_momentum - 8.0, 0.0)
		message = "Strike whiffs. Momentum lost."
		message_timer = 0.8

func counter() -> void:
	if enemy_attack_timer <= 0.0 or enemy_defeated:
		return
	var perfect := enemy_attack_timer > 0.30 and enemy_attack_timer < 0.56
	countered_attack = true
	enemy_attack_timer = 0.0
	enemy_attack_cooldown = 0.8
	enemy_stun = 0.55 if perfect else 0.25
	if perfect:
		enemy_health -= 30.0
		player_momentum = minf(player_momentum + 28.0, 100.0)
		message = "PERFECT COUNTER. The guard is wide open."
	else:
		player_momentum = minf(player_momentum + 8.0, 100.0)
		message = "COUNTER BLOCK. Try the narrow center window."
	message_timer = 1.5
	if enemy_health <= 0.0:
		enemy_defeated = true
		message = "Guard down. Reach the violet gate."

func evade() -> void:
	if evade_timer > 0.0:
		return
	evade_dir = last_move_dir if last_move_dir.length() > 0.1 else Vector2.RIGHT
	evade_timer = 0.28
	invulnerable = 0.42
	player_momentum = minf(player_momentum + 4.0, 100.0)
	message = "EVADE: invulnerable during the slide."
	message_timer = 0.7

func stealth_takedown() -> void:
	if enemy_defeated:
		return
	var behind := enemy_dir.dot((player_pos - enemy_pos).normalized()) < -0.15
	if is_concealed() and enemy_pos.distance_to(player_pos) < 78.0 and behind:
		enemy_defeated = true
		enemy_alert = false
		player_momentum = minf(player_momentum + 35.0, 100.0)
		message = "SILENT TAKEDOWN. Darkness turns positioning into power."
		message_timer = 2.4
	else:
		message = "Takedown needs darkness, close range, and the guard's back."
		message_timer = 1.5

func grapple() -> void:
	if player_pos.distance_to(ANCHOR) < 270.0:
		player_pos = PERCH
		player_height = 26.0
		message = "GRAPPLE: elevated perch reached."
		message_timer = 1.4
	else:
		message = "Move closer to the lit anchor to grapple."
		message_timer = 1.2

func capture_screenshot() -> void:
	# Let the current input/state change render before sampling the viewport texture.
	await get_tree().process_frame
	var capture_dir := ProjectSettings.globalize_path("res://captures")
	var dir_error := DirAccess.make_dir_recursive_absolute(capture_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		message = "Capture failed: could not create captures directory."
		message_timer = 2.0
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var filename := "courtyard_%s_%s.png" % [stamp, str(Time.get_ticks_msec())]
	var file_path := capture_dir.path_join(filename)
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		message = "Capture failed: viewport texture unavailable."
		message_timer = 2.0
		return
	var image := viewport_texture.get_image()
	var save_error := image.save_png(file_path)
	if save_error == OK:
		message = "CAPTURED: captures/%s" % filename
	else:
		message = "Capture failed with error %s." % save_error
	message_timer = 2.5

func damage_player(amount: float, why: String) -> void:
	if invulnerable > 0.0:
		message = "EVADE SUCCESS: the attack passes through empty air."
		message_timer = 1.0
		return
	player_health = maxf(player_health - amount, 0.0)
	player_momentum = maxf(player_momentum - 25.0, 0.0)
	message = why
	message_timer = 1.5
	if player_health <= 0.0:
		message = "DOWNED. Press R to restart the courtyard."

func is_concealed() -> bool:
	return player_pos.distance_to(HIDE_SPOT) < 84.0 and evade_timer <= 0.0

func check_success() -> void:
	if enemy_defeated and player_pos.distance_to(EXIT) < 58.0:
		success = true
		message = "COURTYARD CLEAR. Press R to run the loop again."
		message_timer = 999.0

func _draw() -> void:
	draw_background()
	draw_world_props()
	draw_vision()
	# Y-sort the two actors manually: this is the whole depth-ordering proof.
	if not enemy_defeated and enemy_pos.y < player_pos.y:
		draw_enemy()
		draw_player()
	elif not enemy_defeated:
		draw_player()
		draw_enemy()
	else:
		draw_player()
	draw_hud()

func draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#090d18"))
	# A distant skyline gives the small courtyard a larger, gothic world around it.
	draw_rect(Rect2(0, 190, 960, 120), Color("#111827"))
	draw_rect(Rect2(34, 142, 116, 138), Color("#151c2c"))
	draw_colored_polygon(PackedVector2Array([Vector2(28, 142), Vector2(92, 83), Vector2(158, 142)]), Color("#121a2a"))
	draw_line(Vector2(92, 83), Vector2(92, 57), Color("#252f46"), 4.0)
	draw_rect(Rect2(215, 126, 150, 154), Color("#131b2b"))
	draw_colored_polygon(PackedVector2Array([Vector2(203, 126), Vector2(290, 60), Vector2(377, 126)]), Color("#101827"))
	draw_line(Vector2(290, 60), Vector2(290, 35), Color("#252f46"), 4.0)
	draw_rect(Rect2(455, 153, 112, 127), Color("#151d2e"))
	draw_colored_polygon(PackedVector2Array([Vector2(446, 153), Vector2(511, 93), Vector2(576, 153)]), Color("#121a2a"))
	draw_line(Vector2(511, 93), Vector2(511, 66), Color("#252f46"), 3.0)
	draw_rect(Rect2(680, 135, 205, 145), Color("#111927"))
	draw_colored_polygon(PackedVector2Array([Vector2(665, 135), Vector2(782, 72), Vector2(900, 135)]), Color("#101724"))
	draw_line(Vector2(782, 72), Vector2(782, 44), Color("#252f46"), 4.0)
	# Narrow window slits and a restrained stained-glass red in the distance.
	for window_pos in [Vector2(64, 173), Vector2(106, 157), Vector2(247, 158), Vector2(331, 158), Vector2(480, 178), Vector2(520, 164), Vector2(725, 164), Vector2(804, 151), Vector2(846, 166)]:
		draw_rect(Rect2(window_pos, Vector2(9, 29)), Color("#c38554", 0.35))
	draw_rect(Rect2(275, 96, 30, 65), Color("#9c3f58", 0.45))
	draw_arc(Vector2(290, 97), 15.0, PI, TAU, 12, Color("#d16b61", 0.5), 2.0)
	draw_line(Vector2(290, 100), Vector2(290, 158), Color("#e2a05e", 0.4), 2.0)
	var floor_poly := PackedVector2Array([Vector2(55, 250), Vector2(455, 115), Vector2(910, 260), Vector2(505, 555)])
	draw_colored_polygon(floor_poly, Color("#202a3d"))
	# Oblique paving lines reinforce the angled 2D read.
	for i in range(7):
		var y := 235.0 + i * 45.0
		draw_line(Vector2(95, y), Vector2(830, y + 225.0), Color("#3a4860", 0.48), 1.0)
	for i in range(8):
		var x := 110.0 + i * 105.0
		draw_line(Vector2(x, 235), Vector2(x + 300.0, 505), Color("#39475f", 0.32), 1.0)
	# Wet stone catches sparse blue and amber reflections.
	for reflection in [Vector2(265, 365), Vector2(350, 407), Vector2(455, 448), Vector2(570, 386), Vector2(675, 335), Vector2(755, 422)]:
		draw_line(reflection, reflection + Vector2(34, 13), Color("#8ca0bc", 0.28), 2.0)
		draw_line(reflection + Vector2(7, 7), reflection + Vector2(23, 13), Color("#d2a269", 0.18), 1.0)
	# Low fog is a veil, not a wall: the actor silhouettes remain unobscured.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 295), Vector2(245, 273), Vector2(480, 306), Vector2(735, 276), Vector2(960, 304), Vector2(960, 343), Vector2(0, 337)]), Color("#70809a", 0.055))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 215), Vector2(180, 204), Vector2(360, 226), Vector2(560, 205), Vector2(760, 224), Vector2(960, 210), Vector2(960, 252), Vector2(0, 248)]), Color("#94a4ba", 0.045))
	draw_line(Vector2(0, 249), Vector2(960, 249), Color("#95a4bb", 0.12), 2.0)
	# A deterministic rain pattern keeps the atmosphere stable between captures.
	for i in range(34):
		var rain_x := fmod(float(i * 137 + 41), 960.0)
		var rain_y := fmod(float(i * 83 + 17), 470.0)
		draw_line(Vector2(rain_x, rain_y), Vector2(rain_x - 5.0, rain_y + 15.0), Color("#9aabc3", 0.18), 1.0)
	draw_string(font, Vector2(75, 210), "THE LOWER COURT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#71819e"))

func draw_world_props() -> void:
	# Concealment pool.
	draw_circle(HIDE_SPOT, 84.0, Color("#11182a"))
	draw_arc(HIDE_SPOT, 84.0, 0.0, TAU, 40, Color("#4a5e82", 0.8), 2.0)
	draw_string(font, HIDE_SPOT + Vector2(-55, 5), "DARKNESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8b9ac0"))
	# Low walls / faux-height blocks.
	draw_rect(Rect2(90, 275, 32, 100), Color("#39465d"))
	draw_line(Vector2(90, 275), Vector2(122, 275), Color("#a2aec1", 0.7), 3.0)
	draw_line(Vector2(98, 294), Vector2(114, 289), Color("#61718b", 0.7), 1.0)
	draw_line(Vector2(98, 329), Vector2(114, 324), Color("#61718b", 0.7), 1.0)
	draw_rect(Rect2(770, 330, 42, 90), Color("#39465d"))
	draw_line(Vector2(770, 330), Vector2(812, 330), Color("#a2aec1", 0.7), 3.0)
	draw_line(Vector2(778, 353), Vector2(801, 347), Color("#61718b", 0.7), 1.0)
	# Warm practical lights soften the cold palette and mark navigable edges.
	draw_circle(Vector2(141, 257), 42.0, Color("#d59a4e", 0.055))
	draw_rect(Rect2(137, 240, 8, 36), Color("#262b3a"))
	draw_circle(Vector2(141, 239), 7.0, Color("#e5b866"))
	draw_circle(Vector2(141, 239), 12.0, Color("#e5b866", 0.12))
	draw_circle(Vector2(744, 310), 48.0, Color("#d59a4e", 0.045))
	draw_rect(Rect2(740, 291, 8, 38), Color("#262b3a"))
	draw_circle(Vector2(744, 290), 7.0, Color("#e5b866"))
	# Elevated ledge with a visible vertical face.
	var ledge_top := PackedVector2Array([Vector2(650, 170), Vector2(785, 125), Vector2(845, 155), Vector2(710, 204)])
	draw_colored_polygon(ledge_top, Color("#594764"))
	draw_colored_polygon(PackedVector2Array([Vector2(710, 204), Vector2(845, 155), Vector2(845, 183), Vector2(710, 232)]), Color("#30283f"))
	draw_line(Vector2(710, 204), Vector2(845, 155), Color("#b18bbc", 0.65), 2.0)
	draw_line(Vector2(739, 193), Vector2(777, 181), Color("#776080", 0.65), 1.0)
	draw_line(Vector2(800, 172), Vector2(830, 162), Color("#776080", 0.65), 1.0)
	draw_string(font, Vector2(700, 115), "ELEVATED PERCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#bd99d1"))
	# Grapple route and anchor.
	draw_dashed_line(ANCHOR, PERCH, Color("#d6ad63", 0.72), 2.0, 7.0)
	draw_circle(ANCHOR, 10.0, Color("#d6ad63"))
	draw_circle(ANCHOR, 16.0, Color("#d6ad63", 0.18))
	draw_arc(ANCHOR, 22.0, 0.0, TAU, 24, Color("#d6ad63", 0.45), 1.0)
	draw_string(font, ANCHOR + Vector2(18, 5), "G  GRAPPLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e5c67d"))
	# Exit gate.
	draw_rect(Rect2(EXIT - Vector2(25, 34), Vector2(50, 68)), Color("#241f3b"), true)
	draw_rect(Rect2(EXIT - Vector2(25, 34), Vector2(50, 68)), Color("#9568d6"), false, 3.0)
	for bar_x in [EXIT.x - 16.0, EXIT.x - 5.0, EXIT.x + 6.0, EXIT.x + 17.0]:
		draw_line(Vector2(bar_x, EXIT.y - 30), Vector2(bar_x, EXIT.y + 29), Color("#7554a5", 0.9), 2.0)
	draw_string(font, EXIT + Vector2(-28, 52), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#bb9be9"))
	# Dark foreground wedges frame the playable court like a rooftop parapet.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 514), Vector2(118, 548), Vector2(182, 600), Vector2(0, 600)]), Color("#0b101c", 0.82))
	draw_line(Vector2(0, 514), Vector2(118, 548), Color("#53627b", 0.6), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(828, 520), Vector2(960, 478), Vector2(960, 600), Vector2(785, 600)]), Color("#0b101c", 0.82))
	draw_line(Vector2(828, 520), Vector2(960, 478), Color("#53627b", 0.6), 2.0)
	# Far parapet rail: a repeated scale cue that separates the skyline from the court.
	var rail_start := Vector2(188, 236)
	var rail_end := Vector2(500, 142)
	draw_line(rail_start, rail_end, Color("#111a29"), 7.0)
	draw_line(rail_start + Vector2(0, 10), rail_end + Vector2(0, 10), Color("#687994", 0.6), 2.0)
	for i in range(7):
		var rail_t := float(i) / 6.0
		var rail_post := rail_start.lerp(rail_end, rail_t)
		draw_line(rail_post, rail_post + Vector2(0, 21), Color("#182235"), 4.0)
		if i < 6:
			var next_post := rail_start.lerp(rail_end, float(i + 1) / 6.0)
			draw_line(rail_post + Vector2(0, 9), next_post + Vector2(0, 9), Color("#4f6079", 0.7), 1.0)

func draw_vision() -> void:
	if enemy_defeated:
		return
	var left := enemy_dir.rotated(-0.62) * 235.0
	var right := enemy_dir.rotated(0.62) * 235.0
	var vision_color := Color("#e25c68", 0.22) if enemy_alert else Color("#e2b35c", 0.13)
	draw_colored_polygon(PackedVector2Array([enemy_pos, enemy_pos + left, enemy_pos + right]), vision_color)
	draw_arc(enemy_pos, 235.0, enemy_dir.angle() - 0.62, enemy_dir.angle() + 0.62, 24, Color("#d88961", 0.75), 1.5)

func draw_player() -> void:
	var body_color: Color = outfit_colors[outfit_index]
	var shadow_pos := player_pos + Vector2(0, 13)
	draw_ellipse_shape(shadow_pos, Vector2(18, 8) * player_scale, Color("#000000", 0.42))
	if evade_timer > 0.0:
		draw_line(player_pos - evade_dir * 28.0, player_pos + evade_dir * 20.0, Color(body_color, 0.5), 8.0)
	var center := player_pos - Vector2(0, player_height)
	var cloak_color := Color("#111927")
	# Hood and split cloak: readable as an original vigilante silhouette without a logo or ears.
	draw_colored_polygon(PackedVector2Array([center + Vector2(-17, 4), center + Vector2(-12, -12), center + Vector2(0, -18), center + Vector2(13, -11), center + Vector2(19, 34), center + Vector2(8, 46), center + Vector2(0, 31), center + Vector2(-9, 46), center + Vector2(-20, 34)]), cloak_color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 5), center + Vector2(0, -10), center + Vector2(14, 5), center + Vector2(8, 35), center + Vector2(-7, 35)]), body_color.darkened(0.15))
	draw_circle(center + Vector2(0, -9), 12.0 * player_scale, Color("#101725"))
	draw_circle(center + Vector2(0, -6), 7.0 * player_scale, Color("#d2c1b2"))
	draw_rect(Rect2(center + Vector2(-7, -8), Vector2(14, 5)), Color("#263047"))
	draw_line(center + Vector2(-14, 7), center + Vector2(-30, 20), body_color.lightened(0.25), 4.0)
	draw_line(center + Vector2(14, 8), center + Vector2(29, 17), body_color.lightened(0.25), 4.0)
	draw_line(center + Vector2(-10, 42), center + Vector2(-5, 51), Color("#141827"), 5.0)
	draw_line(center + Vector2(10, 42), center + Vector2(5, 51), Color("#141827"), 5.0)
	draw_line(center + Vector2(-12, 14), center + Vector2(-3, 38), body_color.lightened(0.18), 2.0)
	if is_concealed():
		draw_arc(center, 29.0, 0.0, TAU, 28, Color("#8ba5d2", 0.8), 2.0)
		draw_string(font, center + Vector2(-25, -38), "HIDDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#9cb3dc"))

func draw_enemy() -> void:
	draw_ellipse_shape(enemy_pos + Vector2(0, 14), Vector2(19, 8), Color("#000000", 0.45))
	var enemy_color := Color("#9e394d") if enemy_alert else Color("#a8754d")
	draw_colored_polygon(PackedVector2Array([enemy_pos + Vector2(-18, -13), enemy_pos + Vector2(17, -13), enemy_pos + Vector2(20, 23), enemy_pos + Vector2(10, 31), enemy_pos + Vector2(-15, 26)]), Color("#242b3c"))
	draw_colored_polygon(PackedVector2Array([enemy_pos + Vector2(-14, -11), enemy_pos + Vector2(14, -11), enemy_pos + Vector2(18, 22), enemy_pos + Vector2(-18, 22)]), enemy_color)
	draw_circle(enemy_pos - Vector2(0, 24), 11.0, Color("#cbb39a"))
	draw_rect(Rect2(enemy_pos + Vector2(-13, -36), Vector2(26, 7)), Color("#282c3c"))
	draw_line(enemy_pos + Vector2(12, -4), enemy_pos + Vector2(41, -21), Color("#d6d8df"), 4.0)
	draw_circle(enemy_pos + Vector2(17, -7), 3.0, Color("#e5c67d"))
	draw_line(enemy_pos + Vector2(-13, 24), enemy_pos + Vector2(-5, 40), Color("#161a28"), 5.0)
	draw_line(enemy_pos + Vector2(13, 24), enemy_pos + Vector2(5, 40), Color("#161a28"), 5.0)
	var hp_width := maxf(enemy_health, 0.0) * 0.42
	draw_rect(Rect2(enemy_pos + Vector2(-24, -54), Vector2(48, 5)), Color("#171927"))
	draw_rect(Rect2(enemy_pos + Vector2(-24, -54), Vector2(hp_width, 5)), Color("#d35357"))
	if enemy_attack_timer > 0.0:
		draw_arc(enemy_pos - Vector2(0, 22), 30.0, 0.0, TAU, 28, Color("#f2df82"), 4.0)
		var timing := "PERFECT" if enemy_attack_timer > 0.30 and enemy_attack_timer < 0.56 else "BLOCK"
		draw_string(font, enemy_pos + Vector2(-28, -67), timing, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f2df82"))
	if enemy_alert:
		draw_string(font, enemy_pos + Vector2(-20, -73), "ALERT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ef6f71"))

func draw_hud() -> void:
	draw_rect(Rect2(18, 16, 360, 130), Color("#0b1120", 0.78))
	draw_line(Vector2(18, 16), Vector2(18, 146), Color("#b26a62", 0.65), 2.0)
	draw_string(font, Vector2(32, 40), "GLOAM // LOWER COURT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e3e8f5"))
	draw_string(font, Vector2(32, 61), "WASD move   SPACE strike   E counter", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b7c2db"))
	draw_string(font, Vector2(32, 79), "C evade   T silent takedown   R restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#b7c2db"))
	draw_string(font, Vector2(32, 97), "1/2/3 body build   X accent color", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8f9dbd"))
	draw_string(font, Vector2(32, 115), "F12 capture screenshot   Find back, then reach EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8f9dbd"))
	draw_rect(Rect2(650, 14, 290, 72), Color("#0b1120", 0.78))
	draw_line(Vector2(650, 14), Vector2(940, 14), Color("#6d7892", 0.45), 1.0)
	draw_string(font, Vector2(675, 34), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c7d0e1"))
	draw_rect(Rect2(740, 22, 165, 14), Color("#171c2a"))
	draw_rect(Rect2(740, 22, 165 * player_health / 100.0, 14), Color("#63c391"))
	draw_string(font, Vector2(914, 34), "%03d" % int(player_health), HORIZONTAL_ALIGNMENT_RIGHT, 28, 12, Color("#c7d0e1"))
	draw_string(font, Vector2(675, 61), "MOMENTUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#c7d0e1"))
	draw_rect(Rect2(740, 49, 165, 14), Color("#171c2a"))
	draw_rect(Rect2(740, 49, 165 * player_momentum / 100.0, 14), Color("#d7a752"))
	draw_string(font, Vector2(914, 61), "%03d" % int(player_momentum), HORIZONTAL_ALIGNMENT_RIGHT, 28, 12, Color("#c7d0e1"))
	draw_string(font, Vector2(32, 575), "VISION  cone = danger   amber = suspicion   violet = exit", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#7784a0"))
	if message_timer > 0.0:
		draw_rect(Rect2(250, 530, 460, 38), Color("#101729", 0.92))
		draw_string(font, Vector2(270, 555), message, HORIZONTAL_ALIGNMENT_LEFT, 420, 14, Color("#edf0fa"))
	if enemy_defeated and not success:
		draw_string(font, Vector2(710, 95), "OBJECTIVE: EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d7a8e6"))
	if success:
		draw_rect(Rect2(255, 220, 450, 125), Color("#151c31", 0.96))
		draw_string(font, Vector2(315, 268), "COURTYARD CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#d8b4ec"))
		draw_string(font, Vector2(324, 298), "The timing-and-stealth loop is playable.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e4e8f4"))
		draw_string(font, Vector2(398, 324), "Press R to restart.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#9facc8"))

func draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
