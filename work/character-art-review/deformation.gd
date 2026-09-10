extends SceneTree

## Full-mesh character-art deformation gate. It samples every actual 30/60 Hz action
## frame at all three runtime body presets and evaluates active morph targets
## before CPU skinning. Driver checks never substitute for mesh checks.

const Builder = preload("res://actors/character_visual_builder.gd")
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const AttackCatalog = preload("res://actors/player_attack_catalog.gd")

const PLAYER_BASE_SCALE := 1.35
const FLOOR_TOLERANCE := 0.03
const FOOT_CONTACT_MAX := 0.055
const LINTEL_HEIGHT := 2.0
const RECOVERY_TOLERANCE := 0.004
const PERCH_TOP_Y := 3.04
const FALL_GRAVITY := 17.5
const BODY_PRESETS := [["small", 0.88], ["medium", 1.0], ["large", 1.16]]
const SAMPLE_RATES := [30, 60]
const ACTIONS := [
	{"state": &"strike", "variant": AttackCatalog.RIGHT_PUNCH, "duration": 0.36, "contact": 0.14},
	{"state": &"strike", "variant": AttackCatalog.LEFT_PUNCH, "duration": 0.38, "contact": 0.15},
	{"state": &"strike", "variant": AttackCatalog.LEFT_KICK, "duration": 0.50, "contact": 0.22},
	{"state": &"strike", "variant": AttackCatalog.RIGHT_KICK, "duration": 0.48, "contact": 0.21},
	{"state": &"takedown", "duration": 1.10, "contact": 0.34},
	{"state": &"evade", "duration": 0.42, "contact": -1.0},
	{"state": &"grapple", "duration": 0.32, "contact": -1.0},
	{"state": &"grapple_recover", "duration": 0.32, "contact": -1.0},
	{"state": &"jump", "duration": 0.94, "contact": -1.0},
	{"state": &"vault", "duration": 0.48, "contact": -1.0},
	{"state": &"counter", "duration": 0.44, "contact": -1.0},
	{"state": &"fall", "duration": 0.50, "contact": -1.0},
	{"state": &"hurt", "duration": 0.38, "contact": -1.0},
	{"state": &"downed", "duration": 0.72, "contact": -1.0},
]
const DRIVER_KEYS := [
	&"pelvis_root", &"torso_root", &"head_root",
	&"left_leg", &"right_leg", &"left_knee", &"right_knee",
	&"left_ankle", &"right_ankle", &"left_arm", &"right_arm",
	&"left_elbow", &"right_elbow", &"left_tail", &"right_tail",
]

var checks := 0
var failures: Array[String] = []
var maximum_vertices := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(Candidate.ASSET_PATH):
		_check(false, "explicit character-art candidate resource exists")
		_finish()
		return
	print("GLOAM_CHARACTER_ART_SOURCE path=", Candidate.ASSET_PATH, " sha256=", FileAccess.get_sha256(Candidate.ASSET_PATH))
	if "--crouch-only" in OS.get_cmdline_user_args():
		# Fast iteration mode for the live-rejected motion pass. The default command
		# still executes the complete full-mesh action suite.
		for preset in BODY_PRESETS:
			await _run_crouch_case(String(preset[0]), float(preset[1]), 60)
		_finish()
		return
	if "--downed-only" in OS.get_cmdline_user_args():
		# Fast full-mesh support check for the final side-lying settle. The default
		# command continues to run every action at both sample rates.
		for preset in BODY_PRESETS:
			await _run_action_case(String(preset[0]), float(preset[1]), 60, &"downed", 0.72)
		_finish()
		return
	if "--jump-only" in OS.get_cmdline_user_args():
		# Fast full-mesh landing-clearance check while tuning the flight phrase.
		# The default command still covers every action at both sample rates.
		for preset in BODY_PRESETS:
			await _run_action_case(String(preset[0]), float(preset[1]), 60, &"jump", 0.94)
		_finish()
		return
	if "--locomotion-only" in OS.get_cmdline_user_args():
		# Focused full-mesh walk/run gate at every runtime build and sample rate.
		# The default command remains the complete action and deformation suite.
		for preset in BODY_PRESETS:
			for fps in SAMPLE_RATES:
				await _run_locomotion_case(String(preset[0]), float(preset[1]), int(fps))
		_finish()
		return
	for preset in BODY_PRESETS:
		for fps in SAMPLE_RATES:
			await _run_case(String(preset[0]), float(preset[1]), int(fps))
	_finish()


func _run_locomotion_case(preset_label: String, preset_factor: float, fps: int) -> void:
	var measurement := Node3D.new()
	measurement.name = "CharacterArtLocomotion_%s_%dhz" % [preset_label, fps]
	root.add_child(measurement)
	var actor := Node3D.new()
	actor.scale = Vector3.ONE * PLAYER_BASE_SCALE * preset_factor
	measurement.add_child(actor)
	var parts := Candidate.build_player(actor, Color("#c55c77"))
	var rig: Dictionary = parts["authored_rig"]
	var skeleton: Skeleton3D = rig["skeleton"]
	await process_frame
	var cache := _cache_surfaces(rig, skeleton)
	_check(bool(cache["valid"]), "%s %dhz locomotion has valid full-mesh cache" % [preset_label, fps])
	for running in [false, true]:
		var mode := "run" if running else "walk"
		var minimum_y := INF
		var maximum_y := -INF
		for sample_index in 16:
			var phase := TAU * float(sample_index) / 16.0
			Builder.pose_player(parts, phase, 1.0, 1.0, &"grounded", 0.0, &"right_punch", 1.0 if running else 0.0)
			var sample := _bounds(measurement, skeleton, cache["surfaces"])
			_validate_frame(sample, int(cache["vertex_count"]), "%s %dhz %s sample %d" % [preset_label, fps, mode, sample_index], true)
			minimum_y = minf(minimum_y, (sample["min"] as Vector3).y)
			maximum_y = maxf(maximum_y, (sample["max"] as Vector3).y)
		print("GLOAM_CHARACTER_ART_LOCOMOTION preset=", preset_label, " fps=", fps, " mode=", mode, " min_y=", minimum_y, " max_y=", maximum_y)
	Candidate.clear_material_overrides(parts)
	measurement.queue_free()
	await process_frame


func _run_crouch_case(preset_label: String, preset_factor: float, fps: int) -> void:
	var measurement := Node3D.new()
	measurement.name = "CharacterArtCrouch_%s" % preset_label
	root.add_child(measurement)
	var actor := Node3D.new()
	actor.scale = Vector3.ONE * PLAYER_BASE_SCALE * preset_factor
	measurement.add_child(actor)
	var parts := Candidate.build_player(actor, Color("#c55c77"))
	var rig: Dictionary = parts["authored_rig"]
	var skeleton: Skeleton3D = rig["skeleton"]
	await process_frame
	var cache := _cache_surfaces(rig, skeleton)
	_check(bool(cache["valid"]), "%s quick crouch has valid full-mesh cache" % preset_label)
	_sample_crouch(
		measurement, parts, rig, skeleton, cache["surfaces"], preset_label, fps,
		int(cache["vertex_count"]), {"hands": 0.0, "cape": 0.0}
	)
	Candidate.clear_material_overrides(parts)
	measurement.queue_free()
	await process_frame


func _run_action_case(preset_label: String, preset_factor: float, fps: int, state: StringName, duration: float) -> void:
	var measurement := Node3D.new()
	measurement.name = "CharacterArtAction_%s_%s" % [state, preset_label]
	root.add_child(measurement)
	var actor := Node3D.new()
	actor.scale = Vector3.ONE * PLAYER_BASE_SCALE * preset_factor
	measurement.add_child(actor)
	var parts := Candidate.build_player(actor, Color("#c55c77"))
	var rig: Dictionary = parts["authored_rig"]
	var skeleton: Skeleton3D = rig["skeleton"]
	await process_frame
	var cache := _cache_surfaces(rig, skeleton)
	_check(bool(cache["valid"]), "%s quick %s has valid full-mesh cache" % [preset_label, state])
	_sample_action(
		measurement, actor, parts, rig, skeleton, cache["surfaces"], preset_label, fps,
		state, duration, -1.0, int(cache["vertex_count"]), actor.transform,
		{"hands": 0.0, "cape": 0.0}
	)
	Candidate.clear_material_overrides(parts)
	measurement.queue_free()
	await process_frame


func _run_case(preset_label: String, preset_factor: float, fps: int) -> void:
	var measurement := Node3D.new()
	measurement.name = "CharacterArtDeformation_%s_%dhz" % [preset_label, fps]
	root.add_child(measurement)
	var actor := Node3D.new()
	actor.scale = Vector3.ONE * PLAYER_BASE_SCALE * preset_factor
	measurement.add_child(actor)
	var parts := Candidate.build_player(actor, Color("#c55c77"))
	var rig: Dictionary = parts["authored_rig"]
	var skeleton: Skeleton3D = rig["skeleton"]
	await process_frame

	_check(Candidate.is_exact_candidate(parts), "%s %dhz selected exact 74-bone character-art path" % [preset_label, fps])
	_check(skeleton.get_bone_count() == 74, "%s %dhz retains expanded 74-bone contract" % [preset_label, fps])
	_check(_has_expected_morphs(rig), "%s %dhz exposes all four named facial morphs" % [preset_label, fps])
	Builder.pose_player(parts, 0.0, 0.0, 0.0, &"bind", 0.0)
	var rest_error := 0.0
	for bone in skeleton.get_bone_count():
		var rest_rotation := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var pose_rotation := skeleton.get_bone_pose_rotation(bone)
		rest_error = maxf(rest_error, _quat_angle(rest_rotation, pose_rotation))
		_check(
			skeleton.get_bone_global_rest(bone).origin.distance_to(skeleton.get_bone_global_pose(bone).origin) < 0.0001,
			"%s %dhz bind joint origin %s" % [preset_label, fps, skeleton.get_bone_name(bone)]
		)
	_check(rest_error < 0.0005, "%s %dhz preserves imported bind rotations: %.8f rad" % [preset_label, fps, rest_error])

	var cache := _cache_surfaces(rig, skeleton)
	_check(bool(cache["valid"]), "%s %dhz every candidate surface has valid skin/morph arrays" % [preset_label, fps])
	_check(int(cache["vertex_count"]) > 0, "%s %dhz caches the full candidate mesh" % [preset_label, fps])
	var bind := _bounds(measurement, skeleton, cache["surfaces"])
	_check(bool(bind["finite"]), "%s %dhz bind mesh and morph values are finite" % [preset_label, fps])
	_check(int(bind["count"]) == int(cache["vertex_count"]), "%s %dhz bind includes every candidate vertex" % [preset_label, fps])
	_check((bind["min"] as Vector3).y >= -FLOOR_TOLERANCE, "%s %dhz bind clears floor" % [preset_label, fps])
	_check((bind["foot_min"] as float) <= FOOT_CONTACT_MAX, "%s %dhz bind retains foot contact" % [preset_label, fps])
	var actor_reference := actor.transform
	var semantic_motion := {"hands": 0.0, "cape": 0.0}

	_sample_crouch(
		measurement, parts, rig, skeleton, cache["surfaces"], preset_label, fps,
		int(cache["vertex_count"]), semantic_motion
	)
	for action in ACTIONS:
		_sample_action(
			measurement, actor, parts, rig, skeleton, cache["surfaces"], preset_label, fps,
			StringName(action["state"]), float(action["duration"]), float(action["contact"]),
			int(cache["vertex_count"]), actor_reference, semantic_motion,
			StringName(action.get("variant", AttackCatalog.RIGHT_PUNCH))
		)
	_check(float(semantic_motion["hands"]) > 0.05, "%s %dhz action set drives hand/finger chains" % [preset_label, fps])
	_check(float(semantic_motion["cape"]) > 0.02, "%s %dhz action set drives full cape chains" % [preset_label, fps])

	print(
		"GLOAM_CHARACTER_ART_CASE preset=", preset_label,
		" fps=", fps,
		" vertices=", cache["vertex_count"],
		" surfaces=", (cache["surfaces"] as Array).size(),
		" hand_motion=", semantic_motion["hands"],
		" cape_motion=", semantic_motion["cape"]
	)
	Candidate.clear_material_overrides(parts)
	measurement.queue_free()
	await process_frame
	await process_frame


func _sample_crouch(
	host: Node3D,
	parts: Dictionary,
	rig: Dictionary,
	skeleton: Skeleton3D,
	cache: Array,
	preset_label: String,
	fps: int,
	expected_vertices: int,
	semantic_motion: Dictionary
) -> void:
	_settle_grounded(parts, 1.0 / float(fps), fps * 2)
	var minimum_y := INF
	var maximum_y := -INF
	var minimum_debug := {}
	for frame in fps:
		var phase := TAU * float(frame) / float(fps)
		# In the real low passage the controller deliberately supplies delta=1.0,
		# snapping the presentation to its measured clearance pose on entry. Using
		# the open-courtyard easing delta here would report transition frames the
		# runtime never presents beneath the lintel.
		Builder.pose_player(parts, phase, 1.0, 1.0, &"crouch", 1.0)
		var sample := _bounds(host, skeleton, cache)
		_validate_frame(sample, expected_vertices, "%s %dhz crouch frame %d" % [preset_label, fps, frame], true)
		if (sample["min"] as Vector3).y < minimum_y:
			minimum_y = (sample["min"] as Vector3).y
			minimum_debug = sample.get("min_debug", {})
		maximum_y = maxf(maximum_y, (sample["max"] as Vector3).y)
		_check((sample["max"] as Vector3).y <= LINTEL_HEIGHT, "%s %dhz crouch frame %d exceeds 2.0m lintel: %.5f" % [preset_label, fps, frame, (sample["max"] as Vector3).y])
		_update_semantic_motion(rig, skeleton, semantic_motion)
	var diagnostic := _bounds(host, skeleton, cache)
	print("GLOAM_CHARACTER_ART_CROUCH preset=", preset_label, " fps=", fps, " min_y=", minimum_y, " max_y=", maximum_y, " highest=", diagnostic.get("max_debug", {}))


func _sample_action(
	host: Node3D,
	actor: Node3D,
	parts: Dictionary,
	rig: Dictionary,
	skeleton: Skeleton3D,
	cache: Array,
	preset_label: String,
	fps: int,
	state: StringName,
	duration: float,
	contact_time: float,
	expected_vertices: int,
	actor_reference: Transform3D,
	semantic_motion: Dictionary,
	attack_variant: StringName = AttackCatalog.RIGHT_PUNCH
) -> void:
	var delta := 1.0 / float(fps)
	actor.transform = actor_reference
	_settle_grounded(parts, delta, fps * 2)
	# Grounded recovery is the runtime baseline. Bind is checked separately;
	# comparing action recovery against the pre-transition bind drivers produces
	# false failures for the intentionally animated grounded layer.
	var imported_reference := (rig["imported_root"] as Node3D).transform
	var driver_reference := _capture_driver_transforms(parts)
	var remaining := duration
	var frame := 0
	var minimum_y := INF
	var maximum_y := -INF
	var minimum_debug := {}
	var contact_sampled := false
	var contact_right_shoulder := INF
	var contact_left_shoulder := INF
	var contact_lunge := -INF
	var contact_attack_lead := -INF
	var quarter_error := INF
	var quarter_rotation := 0.0
	var quarter_head_forward := -INF
	var fall_height := PERCH_TOP_Y
	var fall_velocity := 0.0
	while true:
		remaining = maxf(remaining - delta, 0.0)
		if remaining <= 0.0:
			break
		frame += 1
		var elapsed := duration - remaining
		var progress := elapsed / duration
		# Traverse the same vertical actor path as main_3d.gd. Pose-only sampling at
		# floor height incorrectly classifies airborne feet/cape as floor strikes.
		var pose_progress := progress
		var frame_state := state
		match state:
			&"jump":
				var flight_t := clampf((elapsed - 0.12) / 0.62, 0.0, 1.0)
				actor.position.y = actor_reference.origin.y + 4.0 * flight_t * (1.0 - flight_t) * 1.35
				if elapsed < 0.12:
					frame_state = &"jump_prepare"
					pose_progress = elapsed / 0.12
				elif elapsed < 0.74:
					pose_progress = flight_t
				else:
					frame_state = &"jump_land"
					pose_progress = (elapsed - 0.74) / 0.20
			&"vault":
				actor.position.y = actor_reference.origin.y + sin(progress * PI) * 1.05
			&"grapple":
				actor.position.y = actor_reference.origin.y + PERCH_TOP_Y * _smoothstep01(progress) + sin(progress * PI) * 1.75
			&"grapple_recover":
				actor.position.y = actor_reference.origin.y + PERCH_TOP_Y
			&"fall":
				fall_velocity -= FALL_GRAVITY * delta
				fall_height = maxf(fall_height + fall_velocity * delta, 0.0)
				actor.position.y = actor_reference.origin.y + fall_height
				pose_progress = 0.0
			_:
				actor.position.y = actor_reference.origin.y
		var expected_actor_transform := actor.transform
		Builder.pose_player(parts, 0.0, 0.0, delta, frame_state, pose_progress, attack_variant)
		_check(_transform_close(actor.transform, expected_actor_transform), "%s %dhz %s frame %d leaves gameplay actor to controller" % [preset_label, fps, state, frame])
		var sample := _bounds(host, skeleton, cache)
		_validate_frame(sample, expected_vertices, "%s %dhz %s frame %d" % [preset_label, fps, state, frame], true)
		if (sample["min"] as Vector3).y < minimum_y:
			minimum_y = (sample["min"] as Vector3).y
			minimum_debug = sample.get("min_debug", {})
		maximum_y = maxf(maximum_y, (sample["max"] as Vector3).y)
		_update_semantic_motion(rig, skeleton, semantic_motion)
		if contact_time >= 0.0 and not contact_sampled and elapsed + 0.00001 >= contact_time:
			contact_sampled = true
			contact_right_shoulder = (parts["right_arm"] as Node3D).rotation.x
			contact_left_shoulder = (parts["left_arm"] as Node3D).rotation.x
			contact_lunge = (parts["visual_root"] as Node3D).position.z
			if state == &"strike":
				var suffix := "L" if AttackCatalog.side(attack_variant) > 0.0 else "R"
				var lead_bone := StringName("foot.%s" % suffix) if AttackCatalog.kind(attack_variant) == &"kick" else StringName("hand.%s" % suffix)
				var lead_index := skeleton.find_bone(lead_bone)
				var pelvis_index := skeleton.find_bone(&"pelvis")
				var skeleton_to_host := host.global_transform.affine_inverse() * skeleton.global_transform
				contact_attack_lead = (skeleton_to_host * skeleton.get_bone_global_pose(lead_index).origin).z - (skeleton_to_host * skeleton.get_bone_global_pose(pelvis_index).origin).z
		if state == &"evade":
			var action_rotation := (parts["action_root"] as Node3D).rotation.x
			var candidate_error := absf(action_rotation - PI * 0.5)
			if candidate_error < quarter_error:
				quarter_error = candidate_error
				quarter_rotation = action_rotation
				quarter_head_forward = _head_forward_from_pivot(host, parts, rig, skeleton)

	if state == &"strike":
		_check(contact_sampled, "%s %dhz %s samples its %.2fs contact" % [preset_label, fps, attack_variant, contact_time])
		if AttackCatalog.kind(attack_variant) == &"punch":
			var contact_shoulder := contact_left_shoulder if AttackCatalog.side(attack_variant) > 0.0 else contact_right_shoulder
			_check(contact_shoulder <= -0.80, "%s %dhz %s extends its shoulder at contact: %.4f" % [preset_label, fps, attack_variant, contact_shoulder])
		_check(contact_attack_lead >= 0.18, "%s %dhz %s leads from pelvis toward target: %.4f" % [preset_label, fps, attack_variant, contact_attack_lead])
		_check(contact_lunge >= 0.08, "%s %dhz %s closes distance at contact: %.4f" % [preset_label, fps, attack_variant, contact_lunge])
	elif state == &"takedown":
		_check(contact_sampled, "%s %dhz takedown samples the 0.34s contact" % [preset_label, fps])
		_check(contact_left_shoulder <= -0.90 and contact_right_shoulder <= -0.90, "%s %dhz takedown establishes two-arm catch: L %.4f R %.4f" % [preset_label, fps, contact_left_shoulder, contact_right_shoulder])
		_check(contact_lunge >= 0.12, "%s %dhz takedown visibly closes distance: %.4f" % [preset_label, fps, contact_lunge])
	elif state == &"evade":
		_check(quarter_rotation > 0.0 and quarter_error <= 0.30, "%s %dhz evade has positive first-quarter forward rotation" % [preset_label, fps])
		_check(quarter_head_forward > 0.20, "%s %dhz evade carries head forward over pivot: %.4f" % [preset_label, fps, quarter_head_forward])
	elif state == &"downed" and "--downed-only" in OS.get_cmdline_user_args():
		var skeleton_to_host := host.global_transform.affine_inverse() * skeleton.global_transform
		print("GLOAM_DOWNED_ROOT preset=", preset_label, " action_rotation=", (parts["action_root"] as Node3D).rotation, " action_position=", (parts["action_root"] as Node3D).position, " skeleton_basis=", skeleton_to_host.basis.get_euler())
		for bone_name in ["pelvis", "chest", "head", "hand.L", "hand.R", "foot.L", "foot.R", "toe.R"]:
			var bone := skeleton.find_bone(bone_name)
			print("GLOAM_DOWNED_SUPPORT preset=", preset_label, " bone=", bone_name, " point=", skeleton_to_host * skeleton.get_bone_global_pose(bone).origin)

	actor.transform = actor_reference
	_settle_grounded(parts, delta, fps * 3)
	var recovered := _bounds(host, skeleton, cache)
	_check(_transform_close(actor.transform, actor_reference), "%s %dhz %s preserves gameplay actor transform" % [preset_label, fps, state])
	_check(_quat_angle((parts["action_root"] as Node3D).transform.basis.orthonormalized().get_rotation_quaternion(), Quaternion.IDENTITY) <= RECOVERY_TOLERANCE, "%s %dhz %s recovers action pivot" % [preset_label, fps, state])
	_check(_transform_close((rig["imported_root"] as Node3D).transform, imported_reference), "%s %dhz %s preserves imported root" % [preset_label, fps, state])
	for key: StringName in DRIVER_KEYS:
		_check(_transform_close((parts[key] as Node3D).transform, driver_reference[key]), "%s %dhz %s recovers driver %s" % [preset_label, fps, state, key])
	for bone in skeleton.get_bone_count():
		_check(skeleton.get_bone_pose_scale(bone).is_finite() and skeleton.get_bone_pose_scale(bone).distance_to(Vector3.ONE) <= RECOVERY_TOLERANCE, "%s %dhz %s keeps unit bone scale %s" % [preset_label, fps, state, skeleton.get_bone_name(bone)])
	_validate_frame(recovered, expected_vertices, "%s %dhz %s recovery" % [preset_label, fps, state], true)
	_check((recovered["foot_min"] as float) <= FOOT_CONTACT_MAX, "%s %dhz %s recovers grounded foot contact" % [preset_label, fps, state])
	print("GLOAM_CHARACTER_ART_ACTION preset=", preset_label, " fps=", fps, " state=", state,
		" variant=", attack_variant if state == &"strike" else &"",
		" frames=", frame, " min_y=", minimum_y, " max_y=", maximum_y, " lowest=", minimum_debug)


func _smoothstep01(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _validate_frame(sample: Dictionary, expected_vertices: int, label: String, enforce_floor: bool) -> void:
	_check(bool(sample["evaluated"]), label + " CPU skinning evaluated")
	_check(bool(sample["finite"]), label + " has finite vertices, morphs and normalized weights")
	_check(int(sample["count"]) == expected_vertices, label + " includes every candidate vertex")
	_check(((sample["max"] as Vector3) - (sample["min"] as Vector3)).length() < 7.0, label + " remains in bounded actor space")
	if enforce_floor:
		_check((sample["min"] as Vector3).y >= -FLOOR_TOLERANCE, "%s penetrates floor: %.5f" % [label, (sample["min"] as Vector3).y])


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
				for shape in shapes:
					var shape_vertices := (shape as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array
					valid = valid and (shape_vertices.is_empty() or shape_vertices.size() == vertices.size())
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
	maximum_vertices = maxi(maximum_vertices, vertex_count)
	return {"surfaces": result, "valid": valid and not result.is_empty(), "vertex_count": vertex_count}


func _bounds(host: Node3D, skeleton: Skeleton3D, cache: Array) -> Dictionary:
	# Pose loops update driver Node3Ds and immediately sample them in the same
	# frame. Refresh the inherited action/body transform before building CPU skin
	# matrices; otherwise whole-body rotations (evade/downed) are accidentally
	# measured in the previous global transform while individual bones are current.
	skeleton.force_update_transform()
	skeleton.force_update_all_bone_transforms()
	var skeleton_to_host := host.global_transform.affine_inverse() * skeleton.global_transform
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var foot_min := INF
	var min_debug := {}
	var max_debug := {}
	var count := 0
	var finite := true
	var evaluated := not cache.is_empty()
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
			var morph_weight := mesh_node.get_blend_shape_value(shape_index)
			morph_weights.append(morph_weight)
			finite = finite and is_finite(morph_weight)
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
			var foot_weight := 0.0
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
				var bone_name := String(skeleton.get_bone_name(int(bind_bones[bind_index])))
				if bone_name.begins_with("foot.") or bone_name.begins_with("ball.") or bone_name.begins_with("toe."):
					foot_weight += weight
			if total_weight <= 0.0:
				evaluated = false
				skinned = vertex
			else:
				skinned /= total_weight
			var point := skeleton_to_host * skinned
			finite = finite and point.is_finite() and absf(total_weight - 1.0) <= 0.001
			if point.y < minimum.y:
				var min_owners: Array[String] = []
				for influence in influences:
					var packed_index := vertex_index * influences + influence
					if weights[packed_index] <= 0.05:
						continue
					var bind_index := joints[packed_index]
					if bind_index >= 0 and bind_index < bind_bones.size():
						min_owners.append("%s:%.2f" % [skeleton.get_bone_name(int(bind_bones[bind_index])), weights[packed_index]])
				min_debug = {"mesh": mesh_node.name, "surface": mesh_node.mesh.surface_get_name(int(data.get("surface", -1))), "vertex": vertex_index, "point": point, "source": vertex, "skinned": skinned, "owners": min_owners}
			minimum = minimum.min(point)
			if point.y > maximum.y:
				var owners: Array[String] = []
				for influence in influences:
					var packed_index := vertex_index * influences + influence
					if weights[packed_index] <= 0.05:
						continue
					var bind_index := joints[packed_index]
					if bind_index >= 0 and bind_index < bind_bones.size():
						owners.append("%s:%.2f" % [skeleton.get_bone_name(int(bind_bones[bind_index])), weights[packed_index]])
				max_debug = {"mesh": mesh_node.name, "surface": mesh_node.mesh.surface_get_name(int(data.get("surface", -1))), "vertex": vertex_index, "owners": owners}
			maximum = maximum.max(point)
			if foot_weight > 0.5:
				foot_min = minf(foot_min, point.y)
			count += 1
	return {"evaluated": evaluated and count > 0, "finite": finite, "min": minimum, "max": maximum, "foot_min": foot_min, "count": count, "min_debug": min_debug, "max_debug": max_debug}


func _has_expected_morphs(rig: Dictionary) -> bool:
	var face := rig.get("face_mesh") as MeshInstance3D
	if face == null or face.mesh == null:
		return false
	var names: Array[StringName] = []
	for index in face.mesh.get_blend_shape_count():
		names.append(face.mesh.get_blend_shape_name(index))
	for expected in [&"blink.L", &"blink.R", &"brow_inner_raise", &"jaw_clench"]:
		if expected not in names:
			return false
	return true


func _update_semantic_motion(rig: Dictionary, skeleton: Skeleton3D, totals: Dictionary) -> void:
	for bone_name: StringName in rig["bone_indices"]:
		var text := String(bone_name)
		var key := ""
		if text.begins_with("hand.") or text.begins_with("thumb.") or text.begins_with("index.") or text.begins_with("middle.") or text.begins_with("ring.") or text.begins_with("pinky."):
			key = "hands"
		elif text.begins_with("cape.") or text.begins_with("cape_mid.") or text.begins_with("cape_lower.") or text.begins_with("cape_tip."):
			key = "cape"
		if key.is_empty():
			continue
		var bone := int(rig["bone_indices"][bone_name])
		var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		totals[key] = maxf(float(totals[key]), _quat_angle(rest, skeleton.get_bone_pose_rotation(bone)))


func _head_forward_from_pivot(host: Node3D, parts: Dictionary, rig: Dictionary, skeleton: Skeleton3D) -> float:
	var head_index := skeleton.find_bone("head")
	if head_index < 0:
		return -INF
	skeleton.force_update_all_bone_transforms()
	var to_host := host.global_transform.affine_inverse()
	var head_world := skeleton.global_transform * skeleton.get_bone_global_pose(head_index).origin
	var pivot_world := (parts["action_root"] as Node3D).global_position
	return (to_host * head_world).z - (to_host * pivot_world).z


func _settle_grounded(parts: Dictionary, delta: float, frames: int) -> void:
	for frame in frames:
		Builder.pose_player(parts, 0.0, 0.0, delta, &"grounded", 0.0)


func _capture_driver_transforms(parts: Dictionary) -> Dictionary:
	var result := {}
	for key: StringName in DRIVER_KEYS:
		result[key] = (parts[key] as Node3D).transform
	return result


func _transform_close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) <= RECOVERY_TOLERANCE \
		and a.basis.get_scale().distance_to(b.basis.get_scale()) <= RECOVERY_TOLERANCE \
		and _quat_angle(a.basis.orthonormalized().get_rotation_quaternion(), b.basis.orthonormalized().get_rotation_quaternion()) <= RECOVERY_TOLERANCE


func _quat_angle(a: Quaternion, b: Quaternion) -> float:
	var difference := a.normalized().inverse() * b.normalized()
	return 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _finish() -> void:
	print("GLOAM_CHARACTER_ART_DEFORMATION_", "OK" if failures.is_empty() else "FAILED", " checks=", checks, " failures=", failures.size(), " max_vertices=", maximum_vertices)
	quit(0 if failures.is_empty() else 1)
