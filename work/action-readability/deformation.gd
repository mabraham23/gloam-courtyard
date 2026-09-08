extends SceneTree

## Strict CPU-skinned v1 action-readability regression.
##
## Run with:
##   godot --headless --path . --script work/action-readability/deformation.gd
##
## This intentionally samples every actual 30/60 Hz action frame for every
## runtime body preset. It measures the imported v1 mesh through its real Skin
## bind transforms; driver-only assertions never substitute for mesh checks.

const BUILDER := preload("res://actors/character_visual_builder.gd")

const PLAYER_BASE_SCALE := 1.35
const FLOOR_TOLERANCE := 0.03
const RECOVERY_TOLERANCE := 0.004
const MAX_EXTENT_RATIO := 1.50
const MAX_ORIGIN_RATIO := 1.75
const STRIKE_DURATION := 0.36
const STRIKE_CONTACT := 0.14
const TAKEDOWN_DURATION := 1.10
const TAKEDOWN_CONTACT := 0.34
const EVADE_DURATION := 0.42
const BODY_PRESETS := [
	["small", 0.88],
	["medium", 1.0],
	["large", 1.16],
]
const SAMPLE_RATES := [30, 60]
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
	for preset in BODY_PRESETS:
		for fps in SAMPLE_RATES:
			await _run_preset_rate(String(preset[0]), float(preset[1]), int(fps))
	_finish()


func _run_preset_rate(preset_label: String, preset_factor: float, fps: int) -> void:
	var measurement := Node3D.new()
	measurement.name = "ActionReadabilityMeasurement_%s_%dhz" % [preset_label, fps]
	root.add_child(measurement)
	var actor := Node3D.new()
	actor.name = "ActiveV1_%s" % preset_label
	actor.scale = Vector3.ONE * PLAYER_BASE_SCALE * preset_factor
	measurement.add_child(actor)
	var parts: Dictionary = BUILDER.build_player(actor, Color("#ba4f68"), false)
	var rig: Dictionary = parts["authored_rig"]
	var skeleton := rig["skeleton"] as Skeleton3D
	await process_frame

	_check(not bool(rig.get("is_v2", false)), "%s %dhz explicitly uses active v1" % [preset_label, fps])
	_check(skeleton.get_bone_count() == 20, "%s %dhz retains the 20-bone v1 contract" % [preset_label, fps])
	var cache := _cache_surfaces(rig, skeleton)
	_check(bool(cache["valid"]), "%s %dhz every v1 surface has usable skin arrays" % [preset_label, fps])
	_check(int(cache["vertex_count"]) > 0, "%s %dhz cached the full v1 skinned mesh" % [preset_label, fps])

	_settle_grounded(parts, 1.0 / float(fps), fps * 2)
	var bind := _cpu_skin_bounds(measurement, skeleton, cache["surfaces"])
	_check(bool(bind["evaluated"]), "%s %dhz bind pose CPU skinning evaluated" % [preset_label, fps])
	_check(bool(bind["finite"]), "%s %dhz bind pose mesh is finite" % [preset_label, fps])
	_check(int(bind["count"]) == int(cache["vertex_count"]), "%s %dhz bind pose includes every cached vertex" % [preset_label, fps])
	var bind_extent: Vector3 = bind["max"] - bind["min"]
	var bind_diagonal := maxf(bind_extent.length(), 0.001)
	var bind_height := maxf(bind_extent.y, 0.001)
	var actor_reference := actor.transform
	var imported_reference := (rig["imported_root"] as Node3D).transform
	var driver_reference := _capture_driver_transforms(parts)
	print("ACTION_V1_BIND preset=", preset_label,
		" fps=", fps,
		" scale=", actor.scale.x,
		" vertices=", bind["count"],
		" surfaces=", (cache["surfaces"] as Array).size(),
		" min=", bind["min"],
		" max=", bind["max"])

	await _sample_action(
		measurement, actor, parts, rig, skeleton, cache["surfaces"],
		preset_label, fps, &"strike", STRIKE_DURATION, STRIKE_CONTACT,
		int(cache["vertex_count"]), bind_diagonal, bind_height,
		actor_reference, imported_reference, driver_reference)
	await _sample_action(
		measurement, actor, parts, rig, skeleton, cache["surfaces"],
		preset_label, fps, &"takedown", TAKEDOWN_DURATION, TAKEDOWN_CONTACT,
		int(cache["vertex_count"]), bind_diagonal, bind_height,
		actor_reference, imported_reference, driver_reference)
	await _sample_action(
		measurement, actor, parts, rig, skeleton, cache["surfaces"],
		preset_label, fps, &"evade", EVADE_DURATION, -1.0,
		int(cache["vertex_count"]), bind_diagonal, bind_height,
		actor_reference, imported_reference, driver_reference)

	_cleanup_rig(rig)
	measurement.queue_free()
	await process_frame
	await process_frame


func _sample_action(
	measurement: Node3D,
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
	bind_diagonal: float,
	bind_height: float,
	actor_reference: Transform3D,
	imported_reference: Transform3D,
	driver_reference: Dictionary
) -> void:
	var delta := 1.0 / float(fps)
	_settle_grounded(parts, delta, fps * 2)
	var remaining := duration
	var frame := 0
	var sampled_frames := 0
	var minimum_y := INF
	var maximum_y := -INF
	var worst_extent_ratio := 0.0
	var worst_origin_ratio := 0.0
	var minimum_surface := ""
	var contact_sampled := false
	var contact_elapsed := -1.0
	var contact_right_shoulder := INF
	var contact_left_shoulder := INF
	var contact_lunge := -INF
	var minimum_right_shoulder := INF
	var minimum_left_shoulder := INF
	var maximum_lunge := -INF
	var quarter_error := INF
	var quarter_rotation := 0.0
	var quarter_head_forward := -INF
	var quarter_elapsed := -1.0

	# `main_3d.gd` decrements the action timer before selecting its pose. Stop
	# sampling when the timer reaches zero because that exact frame is grounded.
	while true:
		remaining = maxf(remaining - delta, 0.0)
		if remaining <= 0.0:
			break
		frame += 1
		var elapsed := duration - remaining
		var progress := elapsed / duration
		BUILDER.pose_player(parts, 0.0, 0.0, delta, state, progress)
		var bounds := _cpu_skin_bounds(measurement, skeleton, cache)
		sampled_frames += 1
		var extent: Vector3 = bounds["max"] - bounds["min"]
		var extent_ratio := extent.length() / bind_diagonal
		var origin_ratio := maxf((bounds["min"] as Vector3).length(), (bounds["max"] as Vector3).length()) / bind_diagonal
		minimum_y = minf(minimum_y, (bounds["min"] as Vector3).y)
		maximum_y = maxf(maximum_y, (bounds["max"] as Vector3).y)
		worst_extent_ratio = maxf(worst_extent_ratio, extent_ratio)
		worst_origin_ratio = maxf(worst_origin_ratio, origin_ratio)
		if (bounds["min"] as Vector3).y <= minimum_y:
			minimum_surface = String(bounds["min_surface"])

		_check(bool(bounds["evaluated"]), "%s %dhz %s frame %d CPU skinning evaluated" % [preset_label, fps, state, frame])
		_check(bool(bounds["finite"]), "%s %dhz %s frame %d has only finite vertices and normalized weights" % [preset_label, fps, state, frame])
		_check(int(bounds["count"]) == expected_vertices, "%s %dhz %s frame %d includes every v1 vertex" % [preset_label, fps, state, frame])
		_check((bounds["min"] as Vector3).y >= -FLOOR_TOLERANCE,
			"%s %dhz %s frame %d penetrates floor: %.5f" % [preset_label, fps, state, frame, (bounds["min"] as Vector3).y])
		_check(extent_ratio <= MAX_EXTENT_RATIO,
			"%s %dhz %s frame %d extent ratio %.4f exceeds %.2f" % [preset_label, fps, state, frame, extent_ratio, MAX_EXTENT_RATIO])
		_check(origin_ratio <= MAX_ORIGIN_RATIO,
			"%s %dhz %s frame %d leaves bounded actor space: %.4f" % [preset_label, fps, state, frame, origin_ratio])

		var right_shoulder := (parts["right_arm"] as Node3D).rotation.x
		var left_shoulder := (parts["left_arm"] as Node3D).rotation.x
		var lunge := (parts["visual_root"] as Node3D).position.z
		minimum_right_shoulder = minf(minimum_right_shoulder, right_shoulder)
		minimum_left_shoulder = minf(minimum_left_shoulder, left_shoulder)
		maximum_lunge = maxf(maximum_lunge, lunge)
		if contact_time >= 0.0 and not contact_sampled and elapsed + 0.00001 >= contact_time:
			contact_sampled = true
			contact_elapsed = elapsed
			contact_right_shoulder = right_shoulder
			contact_left_shoulder = left_shoulder
			contact_lunge = lunge

		if state == &"evade":
			var action_rotation := (parts["action_root"] as Node3D).rotation.x
			var candidate_error := absf(action_rotation - PI * 0.5)
			if candidate_error < quarter_error:
				quarter_error = candidate_error
				quarter_rotation = action_rotation
				quarter_head_forward = _head_forward_from_pivot(measurement, parts, rig, skeleton)
				quarter_elapsed = elapsed

	print("ACTION_V1_SAMPLE preset=", preset_label,
		" fps=", fps,
		" state=", state,
		" frames=", sampled_frames,
		" min_y=", minimum_y,
		" min_surface=", minimum_surface,
		" max_y=", maximum_y,
		" max_extent_ratio=", worst_extent_ratio,
		" max_origin_ratio=", worst_origin_ratio,
		" min_right_shoulder_x=", minimum_right_shoulder,
		" min_left_shoulder_x=", minimum_left_shoulder,
		" max_lunge_z=", maximum_lunge)

	if state == &"strike":
		print("ACTION_V1_CONTACT preset=", preset_label,
			" fps=", fps,
			" state=strike elapsed=", contact_elapsed,
			" right_shoulder_x=", contact_right_shoulder,
			" lunge_z=", contact_lunge)
		_check(contact_sampled, "%s %dhz strike has an actual contact-frame sample" % [preset_label, fps])
		_check(contact_right_shoulder <= -0.80,
			"%s %dhz strike right shoulder is not extended at contact: %.4f" % [preset_label, fps, contact_right_shoulder])
		_check(contact_lunge >= 0.10,
			"%s %dhz strike lunge is below 0.10 at contact: %.4f" % [preset_label, fps, contact_lunge])
	elif state == &"takedown":
		print("ACTION_V1_CONTACT preset=", preset_label,
			" fps=", fps,
			" state=takedown elapsed=", contact_elapsed,
			" left_shoulder_x=", contact_left_shoulder,
			" right_shoulder_x=", contact_right_shoulder,
			" lunge_z=", contact_lunge)
		_check(contact_sampled, "%s %dhz takedown has an actual contact-frame sample" % [preset_label, fps])
		_check(contact_left_shoulder <= -0.90 and contact_right_shoulder <= -0.90,
			"%s %dhz takedown does not establish a two-arm catch at contact: L %.4f R %.4f" % [preset_label, fps, contact_left_shoulder, contact_right_shoulder])
		_check(contact_lunge >= 0.12,
			"%s %dhz takedown does not visibly close distance at contact: %.4f" % [preset_label, fps, contact_lunge])
	elif state == &"evade":
		print("ACTION_V1_QUARTER preset=", preset_label,
			" fps=", fps,
			" elapsed=", quarter_elapsed,
			" rotation_x=", quarter_rotation,
			" angle_error=", quarter_error,
			" head_forward_z=", quarter_head_forward,
			" required_head_forward=", bind_height * 0.20)
		_check(quarter_rotation > 0.0 and quarter_error <= 0.30,
			"%s %dhz evade has no positive first-quarter forward rotation" % [preset_label, fps])
		_check(quarter_head_forward >= bind_height * 0.20,
			"%s %dhz evade head does not travel forward over the pivot: %.4f" % [preset_label, fps, quarter_head_forward])

	# The controller chooses grounded on the first timer-zero frame. Continue for
	# three seconds at the same sample rate to prove every action leaves the
	# visual/action root, imported root, drivers and mesh in the accepted stance.
	_settle_grounded(parts, delta, fps * 3)
	var recovered := _cpu_skin_bounds(measurement, skeleton, cache)
	var action_root := parts["action_root"] as Node3D
	var action_root_angle := _quat_angle(
		action_root.transform.basis.orthonormalized().get_rotation_quaternion(),
		Quaternion.IDENTITY)
	_check(_transform_close(actor.transform, actor_reference, RECOVERY_TOLERANCE),
		"%s %dhz preserves gameplay actor root and scale" % [preset_label, fps])
	_check(action_root_angle <= RECOVERY_TOLERANCE,
		"%s %dhz %s recovers action root upright: %.6f rad" % [preset_label, fps, state, action_root_angle])
	_check(_transform_close((rig["imported_root"] as Node3D).transform, imported_reference, RECOVERY_TOLERANCE),
		"%s %dhz %s recovers imported root without drift" % [preset_label, fps, state])
	for key: StringName in DRIVER_KEYS:
		_check(_transform_close((parts[key] as Node3D).transform, driver_reference[key], RECOVERY_TOLERANCE),
			"%s %dhz %s recovers driver %s" % [preset_label, fps, state, key])
	for bone in skeleton.get_bone_count():
		_check(skeleton.get_bone_pose_scale(bone).is_finite(),
			"%s %dhz %s bone scale remains finite: %s" % [preset_label, fps, state, skeleton.get_bone_name(bone)])
		_check(skeleton.get_bone_pose_scale(bone).distance_to(Vector3.ONE) <= RECOVERY_TOLERANCE,
			"%s %dhz %s bone scale remains unit: %s" % [preset_label, fps, state, skeleton.get_bone_name(bone)])
	_check(bool(recovered["finite"]), "%s %dhz %s recovery mesh is finite" % [preset_label, fps, state])
	_check((recovered["min"] as Vector3).y >= -FLOOR_TOLERANCE,
		"%s %dhz %s recovery penetrates floor: %.5f" % [preset_label, fps, state, (recovered["min"] as Vector3).y])
	_check((recovered["min"] as Vector3).y <= FLOOR_TOLERANCE,
		"%s %dhz %s recovery floats above floor: %.5f" % [preset_label, fps, state, (recovered["min"] as Vector3).y])
	print("ACTION_V1_RECOVERY preset=", preset_label,
		" fps=", fps,
		" state=", state,
		" action_root_angle=", action_root_angle,
		" min_y=", recovered["min"],
		" imported_root=", (rig["imported_root"] as Node3D).transform.origin)


func _settle_grounded(parts: Dictionary, delta: float, frame_count: int) -> void:
	for frame in frame_count:
		BUILDER.pose_player(parts, 0.0, 0.0, delta, &"grounded", 0.0)


func _capture_driver_transforms(parts: Dictionary) -> Dictionary:
	var result := {}
	for key: StringName in DRIVER_KEYS:
		result[key] = (parts[key] as Node3D).transform
	return result


func _head_forward_from_pivot(measurement: Node3D, parts: Dictionary, rig: Dictionary, skeleton: Skeleton3D) -> float:
	var head_index := skeleton.find_bone("head")
	if head_index < 0:
		return -INF
	skeleton.force_update_all_bone_transforms()
	var to_measurement := measurement.global_transform.affine_inverse()
	var head_world := skeleton.global_transform * skeleton.get_bone_global_pose(head_index).origin
	var pivot_world := (parts["action_root"] as Node3D).global_position
	var head_point := to_measurement * head_world
	var pivot_point := to_measurement * pivot_world
	return head_point.z - pivot_point.z


func _cache_surfaces(rig: Dictionary, skeleton: Skeleton3D) -> Dictionary:
	var result: Array[Dictionary] = []
	var valid := true
	var vertex_count := 0
	for mesh_node_value in rig.get("mesh_instances", [rig["mesh_instance"]]):
		var mesh_node := mesh_node_value as MeshInstance3D
		var skin := mesh_node.skin
		if skin == null or mesh_node.mesh == null:
			valid = false
			continue
		var bind_bones: Array[int] = []
		for bind_index in skin.get_bind_count():
			var bone_index := skin.get_bind_bone(bind_index)
			if bone_index < 0:
				bone_index = skeleton.find_bone(skin.get_bind_name(bind_index))
			if bone_index < 0:
				valid = false
			bind_bones.append(bone_index)
		for surface_index in mesh_node.mesh.get_surface_count():
			var arrays: Array = mesh_node.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences := joints.size() / maxi(vertices.size(), 1)
			if vertices.is_empty() or joints.is_empty() or weights.size() != joints.size() or (influences != 4 and influences != 8):
				valid = false
				continue
			var surface_label := "surface_%d" % surface_index
			var material := mesh_node.mesh.surface_get_material(surface_index)
			if material != null and not material.resource_name.is_empty():
				surface_label = material.resource_name
			result.append({
				"node": mesh_node,
				"skin": skin,
				"bind_bones": bind_bones,
				"vertices": vertices,
				"joints": joints,
				"weights": weights,
				"influences": influences,
				"surface": surface_label,
			})
			vertex_count += vertices.size()
	maximum_vertices = maxi(maximum_vertices, vertex_count)
	return {"surfaces": result, "valid": valid and not result.is_empty(), "vertex_count": vertex_count}


func _cpu_skin_bounds(host: Node3D, skeleton: Skeleton3D, cache: Array) -> Dictionary:
	skeleton.force_update_all_bone_transforms()
	var skeleton_to_host := host.global_transform.affine_inverse() * skeleton.global_transform
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var minimum_surface := ""
	var count := 0
	var finite := true
	var evaluated := not cache.is_empty()
	for data_value in cache:
		var data := data_value as Dictionary
		var mesh_node := data["node"] as MeshInstance3D
		var skin := data["skin"] as Skin
		var bind_bones: Array = data["bind_bones"]
		var vertices: PackedVector3Array = data["vertices"]
		var joints: PackedInt32Array = data["joints"]
		var weights: PackedFloat32Array = data["weights"]
		var influences: int = data["influences"]
		var mesh_to_skeleton := skeleton.global_transform.affine_inverse() * mesh_node.global_transform
		var matrices: Array[Transform3D] = []
		for bind_index in bind_bones.size():
			var bone_index: int = bind_bones[bind_index]
			if bone_index < 0:
				evaluated = false
				matrices.append(Transform3D.IDENTITY)
			else:
				matrices.append(skeleton.get_bone_global_pose(bone_index) * skin.get_bind_pose(bind_index))
		for vertex_index in vertices.size():
			var vertex_in_skeleton := mesh_to_skeleton * vertices[vertex_index]
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
				skinned += (matrices[bind_index] * vertex_in_skeleton) * weight
				total_weight += weight
			if total_weight <= 0.0:
				evaluated = false
				skinned = vertex_in_skeleton
			else:
				skinned /= total_weight
			var point := skeleton_to_host * skinned
			finite = finite and point.is_finite() and absf(total_weight - 1.0) <= 0.001
			if point.y < minimum.y:
				minimum_surface = String(data["surface"])
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			count += 1
	return {
		"evaluated": evaluated and count > 0,
		"finite": finite,
		"min": minimum,
		"max": maximum,
		"min_surface": minimum_surface,
		"count": count,
	}


func _cleanup_rig(rig: Dictionary) -> void:
	# Clear imported material overrides before freeing the scene. This suppresses
	# a known dummy-renderer teardown warning without changing production assets.
	for mesh_value in rig.get("mesh_instances", [rig["mesh_instance"]]):
		var mesh := mesh_value as MeshInstance3D
		mesh.material_override = null
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, null)


func _transform_close(a: Transform3D, b: Transform3D, tolerance: float) -> bool:
	return a.origin.distance_to(b.origin) <= tolerance \
		and a.basis.get_scale().distance_to(b.basis.get_scale()) <= tolerance \
		and _quat_angle(
			a.basis.orthonormalized().get_rotation_quaternion(),
			b.basis.orthonormalized().get_rotation_quaternion()) <= tolerance


func _quat_angle(a: Quaternion, b: Quaternion) -> float:
	var difference := a.normalized().inverse() * b.normalized()
	var sine_half := Vector3(difference.x, difference.y, difference.z).length()
	return 2.0 * atan2(sine_half, absf(difference.w))


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		return
	failures.append(description)
	print("FAIL ", description)


func _finish() -> void:
	print("ACTION_V1_DEFORMATION ", "PASS" if failures.is_empty() else "FAIL",
		" checks=", checks,
		" failures=", failures.size(),
		" max_vertices=", maximum_vertices)
	quit(0 if failures.is_empty() else 1)
