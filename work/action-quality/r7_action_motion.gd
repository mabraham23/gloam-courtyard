extends SceneTree

## Focused R7 action-motion contract on the current R14 appearance asset.
##
## Run with:
##   godot --headless --path . --script work/action-quality/r7_action_motion.gd
##
## This complements the broad mechanics/deformation suites with real-controller
## sampling at the authored action beats.  It measures skeleton/world markers,
## gameplay-root travel and paired victim timing; driver angles alone are not
## accepted as evidence that the expanded R7 rig presents the action.

const SCENE_PATH := "res://main_3d.tscn"
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const AttackCatalog = preload("res://actors/player_attack_catalog.gd")
const EXPECTED_SHA := "30a2c06be42351252dada7f791619499c28e160af59455c7fa332bfad1070b0b"
const SAMPLE_RATES := [30, 60]
const EPSILON := 0.0025

var checks := 0
var failures: Array[String] = []
var skin_cache: Array = []
var expected_skin_vertices := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "active courtyard scene loads")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var default_parts: Dictionary = game.player_visual_parts
	(default_parts["visual_root"] as Node3D).visible = false
	var candidate_parts := Candidate.build_player(game.player_root, game.outfit_colors[game.outfit_index])
	game.player_visual_parts = candidate_parts
	game.player_accent_material = candidate_parts["accent_material"]
	_check(Candidate.is_exact_candidate(candidate_parts), "action sampling uses the exact expanded R7 candidate")
	_check(FileAccess.get_sha256(Candidate.ASSET_PATH) == EXPECTED_SHA, "action sampling uses current R14 appearance GLB SHA")
	_check(bool(candidate_parts["authored_rig"].get("anatomical_profile", false)), "R7 anatomical action layer is selected")
	var rig := candidate_parts["authored_rig"] as Dictionary
	var cached := _cache_surfaces(rig, rig["skeleton"] as Skeleton3D)
	skin_cache = cached["surfaces"] as Array
	expected_skin_vertices = int(cached["vertex_count"])
	_check(bool(cached["valid"]), "exact R7 action sampler caches every skinned surface")
	# The September 10 face compaction and replacement swept hair are applied
	# at runtime over the frozen GLB. Include that current rendered geometry;
	# 51,170 was the pre-hair imported surface count, not today's complete mesh.
	_check(expected_skin_vertices == 50243, "exact action sampler includes all 50,243 current R14 skinned vertex references")

	for fps in SAMPLE_RATES:
		_test_strike(game, fps)
		_test_evade(game, fps)
		_test_takedown(game, fps)

	Candidate.clear_material_overrides(candidate_parts)
	Candidate.clear_material_overrides(default_parts)
	game.queue_free()
	_finish()


func _test_strike(game, fps: int) -> void:
	game.reset_game()
	game.player_root.position = Vector3(0.0, 0.0, -1.55)
	game.guard_root.position = Vector3.ZERO
	_quiet_guard(game)
	var start_root: Vector3 = game.player_root.position
	game._commit_strike_variant(AttackCatalog.RIGHT_PUNCH, true)
	_check_close(game.player_strike_timer, AttackCatalog.duration(AttackCatalog.RIGHT_PUNCH), "%dhz right-punch strike begins with exact duration" % fps)
	_step(game, AttackCatalog.contact_time(AttackCatalog.RIGHT_PUNCH) - 0.001, fps)
	_check_close(game.guard_health, 100.0, "%dhz strike cannot resolve before contact" % fps)
	_check_close(game.momentum, 0.0, "%dhz strike cannot award Momentum before contact" % fps)
	_step(game, 0.002, fps)
	_check_close(game.guard_health, 78.0, "%dhz strike resolves damage on first contact step" % fps)
	_check_close(game.momentum, 13.0, "%dhz strike awards Momentum once at contact" % fps)
	_check_vec3(game.player_root.position, start_root, "%dhz strike animation never writes gameplay root" % fps)

	var skeleton := _skeleton(game)
	var forward := _player_forward(game)
	# The frozen R7 suffixes are spatially mirrored; the visible right arm is .L.
	var shoulder := _bone_world(skeleton, &"upper_arm.L")
	var elbow := _bone_world(skeleton, &"forearm.L")
	var hand := _bone_world(skeleton, &"hand.L")
	var shoulder_forward := shoulder.dot(forward)
	var elbow_forward := elbow.dot(forward)
	var hand_forward := hand.dot(forward)
	print("R7_ACTION_STRIKE fps=", fps,
		" shoulder_forward=", shoulder_forward,
		" elbow_forward=", elbow_forward,
		" hand_forward=", hand_forward,
		" hand_lead=", hand_forward - elbow_forward)
	_check(elbow_forward > shoulder_forward + 0.02,
		"%dhz strike contact puts elbow ahead of shoulder along facing" % fps)
	_check(hand_forward > elbow_forward + 0.02,
		"%dhz strike contact is fist-leading instead of cross-chest" % fps)
	_check(_skeleton_finite(skeleton), "%dhz strike contact skeleton is finite" % fps)

	_step(game, AttackCatalog.duration(AttackCatalog.RIGHT_PUNCH), fps)
	_check_close(game.player_strike_timer, 0.0, "%dhz strike presentation ends" % fps)
	_check_close(game.guard_health, 78.0, "%dhz strike recovery cannot repeat damage" % fps)
	_check_close(game.momentum, 13.0, "%dhz strike recovery cannot repeat Momentum" % fps)
	_check(_action_root_identity(game), "%dhz strike recovers a neutral action pivot" % fps)


func _test_evade(game, fps: int) -> void:
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		game.reset_game()
		game.guard_defeated = true
		game.player_root.position = Vector3.ZERO
		game.player_root.rotation = Vector3(0.0, yaw, 0.0)
		game.player_facing_yaw = yaw
		var start: Vector3 = game.player_root.position
		var forward := Vector3(sin(yaw), 0.0, cos(yaw))
		var skeleton := _skeleton(game)
		var neutral_bone_top_sample := _skeleton_bone_top_sample(skeleton, game.player_root.global_position.y)
		var neutral_bone_top := float(neutral_bone_top_sample["height"])
		var neutral_skin_top := -INF
		if absf(yaw) <= 0.0001:
			var neutral_bounds := _skin_bounds(game as Node3D, skeleton, skin_cache)
			_check(bool(neutral_bounds["evaluated"]), "%dhz evade neutral CPU skinning evaluates" % fps)
			_check(int(neutral_bounds["count"]) == expected_skin_vertices, "%dhz evade neutral CPU skinning includes full R7 mesh" % fps)
			neutral_skin_top = (neutral_bounds["max"] as Vector3).y
		game.evade()
		_check_close(game.evade_timer, game.EVADE_MOVE_DURATION, "%dhz yaw %.0f evade starts exact travel timer" % [fps, rad_to_deg(yaw)])
		_check_close(game.invulnerable, game.EVADE_INVULNERABILITY_DURATION, "%dhz yaw %.0f evade starts exact lock timer" % [fps, rad_to_deg(yaw)])
		_check_close(game.momentum, 4.0, "%dhz yaw %.0f evade awards Momentum once" % [fps, rad_to_deg(yaw)])

		# This is inside the authored 0.050-0.120 s forward/down launch beat.
		_step(game, 0.085, fps)
		var pelvis := _bone_world(skeleton, &"pelvis").dot(forward)
		var head := _bone_world(skeleton, &"head").dot(forward)
		var shoulders := (_bone_world(skeleton, &"upper_arm.L") + _bone_world(skeleton, &"upper_arm.R")) * 0.5
		var feet := (_bone_world(skeleton, &"foot.L") + _bone_world(skeleton, &"foot.R")) * 0.5
		var upper_lead := maxf(head, shoulders.dot(forward)) - pelvis
		var boot_trail := pelvis - feet.dot(forward)
		print("R7_ACTION_EVADE_LAUNCH fps=", fps,
			" yaw_deg=", rad_to_deg(yaw),
			" upper_lead=", upper_lead,
			" boot_trail=", boot_trail,
			" action_height=", (game.player_visual_parts["action_root"] as Node3D).position.y)
		_check(upper_lead > 0.025,
			"%dhz yaw %.0f evade sends head/shoulder ahead of pelvis" % [fps, rad_to_deg(yaw)])
		_check(boot_trail > 0.015,
			"%dhz yaw %.0f evade launch keeps boots trailing the hips" % [fps, rad_to_deg(yaw)])
		_check((game.player_visual_parts["action_root"] as Node3D).position.y <= 1.05,
			"%dhz yaw %.0f evade launch does not add early aerial lift" % [fps, rad_to_deg(yaw)])

		var maximum_sample := _skeleton_bone_top_sample(skeleton, game.player_root.global_position.y)
		var maximum_bone_top := float(maximum_sample["height"])
		var maximum_bone_name := String(maximum_sample["bone"])
		var maximum_bone_progress: float = 1.0 - float(game.invulnerable) / float(game.EVADE_INVULNERABILITY_DURATION)
		var maximum_bone_pivot_y: float = (game.player_visual_parts["action_root"] as Node3D).position.y
		var skin_maximum := -INF
		var skin_minimum := INF
		var skin_maximum_progress := -1.0
		var skin_maximum_pivot_y := -INF
		var skin_minimum_progress := -1.0
		var skin_minimum_pivot_y := -INF
		var skin_minimum_debug := {}
		if absf(yaw) <= 0.0001:
			var launch_bounds := _skin_bounds(game as Node3D, skeleton, skin_cache)
			skin_maximum = (launch_bounds["max"] as Vector3).y
			skin_minimum = (launch_bounds["min"] as Vector3).y
			skin_maximum_progress = maximum_bone_progress
			skin_maximum_pivot_y = maximum_bone_pivot_y
			skin_minimum_progress = maximum_bone_progress
			skin_minimum_pivot_y = maximum_bone_pivot_y
			skin_minimum_debug = launch_bounds["min_debug"] as Dictionary
		var evade_sample_remaining: float = game.EVADE_MOVE_DURATION - 0.085
		var fixed_delta := 1.0 / float(fps)
		while evade_sample_remaining > 0.000001:
			var delta := minf(fixed_delta, evade_sample_remaining)
			game._process(delta)
			evade_sample_remaining -= delta
			var top_sample := _skeleton_bone_top_sample(skeleton, game.player_root.global_position.y)
			if float(top_sample["height"]) > maximum_bone_top:
				maximum_bone_top = float(top_sample["height"])
				maximum_bone_name = String(top_sample["bone"])
				maximum_bone_progress = 1.0 - float(game.invulnerable) / game.EVADE_INVULNERABILITY_DURATION
				maximum_bone_pivot_y = (game.player_visual_parts["action_root"] as Node3D).position.y
			if absf(yaw) <= 0.0001:
				var bounds := _skin_bounds(game as Node3D, skeleton, skin_cache)
				if (bounds["min"] as Vector3).y < skin_minimum:
					skin_minimum = (bounds["min"] as Vector3).y
					skin_minimum_progress = 1.0 - float(game.invulnerable) / game.EVADE_INVULNERABILITY_DURATION
					skin_minimum_pivot_y = (game.player_visual_parts["action_root"] as Node3D).position.y
					skin_minimum_debug = bounds["min_debug"] as Dictionary
				if (bounds["max"] as Vector3).y > skin_maximum:
					skin_maximum = (bounds["max"] as Vector3).y
					skin_maximum_progress = 1.0 - float(game.invulnerable) / game.EVADE_INVULNERABILITY_DURATION
					skin_maximum_pivot_y = (game.player_visual_parts["action_root"] as Node3D).position.y
		var travel: Vector3 = game.player_root.position - start
		var forward_travel := travel.dot(forward)
		var lateral_travel := (travel - forward * forward_travel).length()
		print("R7_ACTION_EVADE_TRAVEL fps=", fps,
			" yaw_deg=", rad_to_deg(yaw),
			" travel=", travel,
			" forward=", forward_travel,
			" lateral=", lateral_travel)
		_check_close(forward_travel, 1.96, "%dhz yaw %.0f evade preserves exact facing-direction travel" % [fps, rad_to_deg(yaw)], 0.004)
		_check(lateral_travel <= 0.003, "%dhz yaw %.0f evade has no lateral drift" % [fps, rad_to_deg(yaw)])
		_check_close(game.evade_timer, 0.0, "%dhz yaw %.0f evade travel ends at 0.28 seconds" % [fps, rad_to_deg(yaw)])
		var travel_end: Vector3 = game.player_root.position
		# Continue sampling through the non-travelling landing/recovery beat. The
		# visual state remains evade until invulnerability ends at 0.42 seconds.
		var lock_sample_remaining: float = game.invulnerable
		while lock_sample_remaining > 0.000001:
			var delta := minf(fixed_delta, lock_sample_remaining)
			game._process(delta)
			lock_sample_remaining -= delta
			var top_sample := _skeleton_bone_top_sample(skeleton, game.player_root.global_position.y)
			if float(top_sample["height"]) > maximum_bone_top:
				maximum_bone_top = float(top_sample["height"])
				maximum_bone_name = String(top_sample["bone"])
				maximum_bone_progress = 1.0 - float(game.invulnerable) / game.EVADE_INVULNERABILITY_DURATION
				maximum_bone_pivot_y = (game.player_visual_parts["action_root"] as Node3D).position.y
			if absf(yaw) <= 0.0001:
				var bounds := _skin_bounds(game as Node3D, skeleton, skin_cache)
				if (bounds["min"] as Vector3).y < skin_minimum:
					skin_minimum = (bounds["min"] as Vector3).y
					skin_minimum_progress = 1.0 - float(game.invulnerable) / game.EVADE_INVULNERABILITY_DURATION
					skin_minimum_pivot_y = (game.player_visual_parts["action_root"] as Node3D).position.y
					skin_minimum_debug = bounds["min_debug"] as Dictionary
				if (bounds["max"] as Vector3).y > skin_maximum:
					skin_maximum = (bounds["max"] as Vector3).y
					skin_maximum_progress = 1.0 - float(game.invulnerable) / game.EVADE_INVULNERABILITY_DURATION
					skin_maximum_pivot_y = (game.player_visual_parts["action_root"] as Node3D).position.y
		print("R7_ACTION_EVADE_HEIGHT fps=", fps,
			" yaw_deg=", rad_to_deg(yaw),
			" neutral_bone_top=", neutral_bone_top,
			" neutral_top_bone=", neutral_bone_top_sample["bone"],
			" maximum_bone_top=", maximum_bone_top,
			" maximum_top_bone=", maximum_bone_name,
			" maximum_progress=", maximum_bone_progress,
			" maximum_pivot_y=", maximum_bone_pivot_y)
		# Structural `root` and eye-bone origins can briefly become the highest
		# joint while the whole rig rotates. Keep this as a broad sanity bound;
		# the full skinned surface below is the authoritative height criterion.
		_check(maximum_bone_top <= neutral_bone_top + 0.10,
			"%dhz yaw %.0f evade joint envelope stays below standing bone-top plus 0.10 m" % [fps, rad_to_deg(yaw)])
		if absf(yaw) <= 0.0001:
			print("R7_ACTION_EVADE_SKIN fps=", fps,
				" neutral_max_y=", neutral_skin_top,
				" action_max_y=", skin_maximum,
				" action_min_y=", skin_minimum,
				" maximum_progress=", skin_maximum_progress,
				" maximum_pivot_y=", skin_maximum_pivot_y,
				" minimum_progress=", skin_minimum_progress,
				" minimum_pivot_y=", skin_minimum_pivot_y,
				" minimum_debug=", skin_minimum_debug)
			_check(skin_minimum >= -0.03, "%dhz evade full R7 mesh stays above the -0.03 m floor bar" % fps)
			_check(skin_maximum <= neutral_skin_top + 0.05,
				"%dhz evade full R7 mesh stays below standing height plus 0.05 m" % fps)
		_check_vec3(game.player_root.position, travel_end, "%dhz yaw %.0f post-travel evade lock adds no distance" % [fps, rad_to_deg(yaw)])
		_check_close(game.invulnerable, 0.0, "%dhz yaw %.0f evade lock ends at 0.42 seconds" % [fps, rad_to_deg(yaw)])
		_check(absf(wrapf(game.player_root.rotation.y - yaw, -PI, PI)) <= 0.003,
			"%dhz yaw %.0f evade preserves launch-facing yaw" % [fps, rad_to_deg(yaw)])
		# Give both sample rates the same 40 ms of actual grounded presentation
		# time. This reflects the controller transition without comparing a 33 ms
		# 30 Hz frame to a 17 ms 60 Hz frame.
		_step(game, 0.04, fps)
		var recovery_error := _action_root_error(game)
		print("R7_ACTION_EVADE_RECOVERY fps=", fps,
			" yaw_deg=", rad_to_deg(yaw),
			" angle_error=", recovery_error["angle"],
			" position_error=", recovery_error["position"])
		_check(float(recovery_error["angle"]) <= 0.004 and float(recovery_error["position"]) <= 0.004,
			"%dhz yaw %.0f evade recovers upright action pivot" % [fps, rad_to_deg(yaw)])
		_check(_skeleton_finite(skeleton), "%dhz yaw %.0f evade skeleton remains finite" % [fps, rad_to_deg(yaw)])


func _test_takedown(game, fps: int) -> void:
	game.reset_game()
	game.guard_root.position = Vector3(-4.6, 0.0, 0.2)
	game.player_root.position = Vector3(-2.6, 0.0, 0.2)
	game.guard_forward = Vector3.LEFT
	game.guard_alert = true
	game.attack_cooldown = 0.0
	var player_start: Vector3 = game.player_root.position
	var guard_start: Vector3 = game.guard_root.position
	game.stealth_takedown()
	_check_close(game.player_takedown_timer, game.PLAYER_TAKEDOWN_DURATION, "%dhz takedown begins with exact duration" % fps)
	_check(not game.guard_defeated, "%dhz takedown does not defeat on input" % fps)
	_step(game, game.PLAYER_TAKEDOWN_CONTACT - 0.001, fps)
	var guard_body := game.guard_visual_parts["body_root"] as Node3D
	var precontact_body_rotation := absf(guard_body.rotation.z)
	print("R7_ACTION_TAKEDOWN_PRECONTACT fps=", fps,
		" victim_body_z=", precontact_body_rotation,
		" player_approach=", game.player_root.position.distance_to(player_start))
	_check(not game.guard_defeated, "%dhz takedown victim remains active before contact" % fps)
	_check_close(game.guard_health, 100.0, "%dhz takedown cannot damage before contact" % fps)
	_check_close(game.momentum, 0.0, "%dhz takedown cannot award Momentum before contact" % fps)
	_check(precontact_body_rotation <= deg_to_rad(3.0),
		"%dhz takedown victim does not begin falling before 0.34-second contact" % fps)
	_check_vec3(game.guard_root.position, guard_start, "%dhz reserved takedown guard cannot move before contact" % fps)

	# Procedural guard joints serve as deterministic temporary contact markers.
	var skeleton := _skeleton(game)
	var left_hand := _bone_world(skeleton, &"hand.L")
	var right_hand := _bone_world(skeleton, &"hand.R")
	var left_shoulder := (game.guard_visual_parts["left_arm"] as Node3D).global_position
	var right_shoulder := (game.guard_visual_parts["right_arm"] as Node3D).global_position
	var best_pair_gap := minf(
		maxf(left_hand.distance_to(left_shoulder), right_hand.distance_to(right_shoulder)),
		maxf(left_hand.distance_to(right_shoulder), right_hand.distance_to(left_shoulder)))
	print("R7_ACTION_TAKEDOWN_CONTROL fps=", fps, " max_assigned_shoulder_gap=", best_pair_gap)
	_check(best_pair_gap <= 0.62,
		"%dhz takedown establishes two asymmetric shoulder control points before contact" % fps)
	_check(_skeleton_finite(skeleton), "%dhz takedown pre-contact skeleton is finite" % fps)

	_step(game, 0.002, fps)
	_check(game.guard_defeated, "%dhz takedown defeats on first contact step" % fps)
	_check_close(game.guard_health, 0.0, "%dhz takedown contact zeros guard health" % fps)
	_check_close(game.momentum, 35.0, "%dhz takedown contact awards Momentum once" % fps)
	var approach: Vector3 = game.player_root.position - player_start
	var approach_direction := (guard_start - player_start).normalized()
	_check(approach.length() <= 0.522, "%dhz takedown collision-safe approach remains capped" % fps)
	_check((approach - approach_direction * approach.dot(approach_direction)).length() <= 0.003,
		"%dhz takedown approach has no lateral drift" % fps)

	var previous_fall := absf(guard_body.rotation.z)
	var monotonic := true
	var remaining: float = game.player_takedown_timer
	var fixed_delta := 1.0 / float(fps)
	while remaining > 0.17:
		var delta := minf(fixed_delta, remaining - 0.17)
		game._process(delta)
		remaining = game.player_takedown_timer
		var fall := absf(guard_body.rotation.z)
		if fall + 0.003 < previous_fall:
			monotonic = false
		previous_fall = fall
	_check(monotonic, "%dhz takedown victim falls monotonically after gameplay contact" % fps)
	_step(game, game.player_takedown_timer + 0.002, fps)
	_check_close(game.player_takedown_timer, 0.0, "%dhz takedown presentation ends at 1.10 seconds" % fps)
	_check_close(game.momentum, 35.0, "%dhz takedown recovery cannot repeat Momentum" % fps)
	_check(_action_root_identity(game), "%dhz takedown leaves the player action pivot upright" % fps)
	_check(_skeleton_finite(skeleton), "%dhz takedown recovery skeleton is finite" % fps)


func _quiet_guard(game) -> void:
	game.guard_stun = 999.0
	game.guard_stun_duration = 999.0
	game.attack_cooldown = 999.0
	game.guard_alert = false
	game.guard_suspicion = 0.0


func _skeleton(game) -> Skeleton3D:
	return game.player_visual_parts["authored_rig"]["skeleton"] as Skeleton3D


func _bone_world(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	var bone := skeleton.find_bone(bone_name)
	assert(bone >= 0, "R7 action test requires bone %s" % bone_name)
	skeleton.force_update_all_bone_transforms()
	return skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)


func _player_forward(game) -> Vector3:
	return Vector3(sin(game.player_root.rotation.y), 0.0, cos(game.player_root.rotation.y)).normalized()


func _skeleton_finite(skeleton: Skeleton3D) -> bool:
	skeleton.force_update_all_bone_transforms()
	for bone in skeleton.get_bone_count():
		var pose := skeleton.get_bone_global_pose(bone)
		if not pose.origin.is_finite() or not pose.basis.is_finite():
			return false
	return true


func _skeleton_bone_top_sample(skeleton: Skeleton3D, root_height: float) -> Dictionary:
	skeleton.force_update_all_bone_transforms()
	var maximum := -INF
	var bone_name := ""
	for bone in skeleton.get_bone_count():
		var height := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin).y - root_height
		if height > maximum:
			maximum = height
			bone_name = String(skeleton.get_bone_name(bone))
	return {"height": maximum, "bone": bone_name}


func _cache_surfaces(rig: Dictionary, skeleton: Skeleton3D) -> Dictionary:
	var result: Array[Dictionary] = []
	var valid := true
	var vertex_count := 0
	for mesh_value in rig.get("mesh_instances", []):
		var mesh_node := mesh_value as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null or mesh_node.skin == null:
			valid = false
			continue
		var bind_bones: Array[int] = []
		for bind_index in mesh_node.skin.get_bind_count():
			var bone_index := mesh_node.skin.get_bind_bone(bind_index)
			if bone_index < 0:
				bone_index = skeleton.find_bone(mesh_node.skin.get_bind_name(bind_index))
			valid = valid and bone_index >= 0
			bind_bones.append(bone_index)
		for surface_index in mesh_node.mesh.get_surface_count():
			var arrays: Array = mesh_node.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var joints := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
			var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
			var influences := joints.size() / maxi(vertices.size(), 1)
			if vertices.is_empty() or weights.size() != joints.size() or influences not in [4, 8]:
				valid = false
				continue
			var shapes: Array = []
			if mesh_node.mesh is ArrayMesh:
				shapes = (mesh_node.mesh as ArrayMesh).surface_get_blend_shape_arrays(surface_index)
			result.append({
				"node": mesh_node,
				"surface": surface_index,
				"skin": mesh_node.skin,
				"bind_bones": bind_bones,
				"vertices": vertices,
				"joints": joints,
				"weights": weights,
				"influences": influences,
				"shapes": shapes,
			})
			vertex_count += vertices.size()
	return {"surfaces": result, "valid": valid and not result.is_empty(), "vertex_count": vertex_count}


func _skin_bounds(host: Node3D, skeleton: Skeleton3D, cache: Array) -> Dictionary:
	skeleton.force_update_transform()
	skeleton.force_update_all_bone_transforms()
	var skeleton_to_host := host.global_transform.affine_inverse() * skeleton.global_transform
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var count := 0
	var evaluated := not cache.is_empty()
	var finite := true
	var min_debug := {}
	for value in cache:
		var data := value as Dictionary
		var mesh_node := data["node"] as MeshInstance3D
		mesh_node.force_update_transform()
		var skin := data["skin"] as Skin
		var vertices := data["vertices"] as PackedVector3Array
		var joints := data["joints"] as PackedInt32Array
		var weights := data["weights"] as PackedFloat32Array
		var bind_bones := data["bind_bones"] as Array
		var influences := int(data["influences"])
		var shapes := data["shapes"] as Array
		var mesh_to_skeleton := skeleton.global_transform.affine_inverse() * mesh_node.global_transform
		var matrices: Array[Transform3D] = []
		for bind_index in bind_bones.size():
			var bone_index := int(bind_bones[bind_index])
			if bone_index < 0:
				evaluated = false
				matrices.append(Transform3D.IDENTITY)
			else:
				matrices.append(skeleton.get_bone_global_pose(bone_index) * skin.get_bind_pose(bind_index))
		var morph_weights: Array[float] = []
		for shape_index in shapes.size():
			morph_weights.append(mesh_node.get_blend_shape_value(shape_index))
		for vertex_index in vertices.size():
			var vertex := vertices[vertex_index]
			for shape_index in shapes.size():
				if absf(morph_weights[shape_index]) <= 0.00001:
					continue
				var shape_vertices := (shapes[shape_index] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array
				if shape_vertices.is_empty():
					continue
				var shape_vertex := shape_vertices[vertex_index]
				if (mesh_node.mesh as ArrayMesh).blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
					shape_vertex -= vertices[vertex_index]
				vertex += shape_vertex * morph_weights[shape_index]
			vertex = mesh_to_skeleton * vertex
			var skinned := Vector3.ZERO
			var total_weight := 0.0
			for influence in influences:
				var packed_index := vertex_index * influences + influence
				var weight := weights[packed_index]
				if weight <= 0.0:
					continue
				var bind_index := joints[packed_index]
				if bind_index < 0 or bind_index >= matrices.size():
					evaluated = false
					continue
				skinned += (matrices[bind_index] * vertex) * weight
				total_weight += weight
			if total_weight <= 0.0:
				evaluated = false
				skinned = vertex
			else:
				skinned /= total_weight
			var point := skeleton_to_host * skinned
			finite = finite and point.is_finite() and absf(total_weight - 1.0) <= 0.001
			if point.y < minimum.y:
				var owners: Array[String] = []
				for influence in influences:
					var packed_index := vertex_index * influences + influence
					if weights[packed_index] <= 0.05:
						continue
					var bind_index := joints[packed_index]
					if bind_index >= 0 and bind_index < bind_bones.size():
						owners.append("%s:%.2f" % [skeleton.get_bone_name(int(bind_bones[bind_index])), weights[packed_index]])
				min_debug = {
					"mesh": mesh_node.name,
					"surface": mesh_node.mesh.surface_get_name(int(data["surface"])),
					"vertex": vertex_index,
					"point": point,
					"owners": owners,
				}
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			count += 1
	return {
		"evaluated": evaluated and count > 0,
		"finite": finite,
		"min": minimum,
		"max": maximum,
		"count": count,
		"min_debug": min_debug,
	}


func _action_root_identity(game) -> bool:
	var error := _action_root_error(game)
	return float(error["angle"]) <= 0.004 and float(error["position"]) <= 0.004


func _action_root_error(game) -> Dictionary:
	var action_root := game.player_visual_parts["action_root"] as Node3D
	var rotation := action_root.transform.basis.orthonormalized().get_rotation_quaternion()
	return {
		"angle": rotation.angle_to(Quaternion.IDENTITY),
		"position": action_root.position.distance_to(Vector3(0.0, 0.95, 0.0)),
	}


func _step(game, duration: float, fps: int) -> void:
	var remaining := duration
	var fixed_delta := 1.0 / float(fps)
	while remaining > 0.000001:
		var delta := minf(fixed_delta, remaining)
		game._process(delta)
		remaining -= delta


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
		return
	failures.append(label)
	push_error("FAIL %s" % label)


func _check_close(actual: float, expected: float, label: String, tolerance := EPSILON) -> void:
	_check(absf(actual - expected) <= tolerance,
		"%s (actual=%.6f expected=%.6f tolerance=%.6f)" % [label, actual, expected, tolerance])


func _check_vec3(actual: Vector3, expected: Vector3, label: String, tolerance := EPSILON) -> void:
	_check(actual.distance_to(expected) <= tolerance,
		"%s (actual=%s expected=%s tolerance=%.6f)" % [label, actual, expected, tolerance])


func _finish() -> void:
	print("R7_ACTION_MOTION_", "OK" if failures.is_empty() else "FAILED",
		" checks=", checks, " failures=", failures.size())
	for failure in failures:
		print(" - ", failure)
	quit(0 if failures.is_empty() else 1)
