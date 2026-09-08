extends SceneTree

## Independent candidate audit. Run only after importing the exact candidate. All skinned meshes and active relative morph
## deltas are evaluated; probes do not substitute for rendered anatomy review.
const Builder = preload("res://actors/character_visual_builder.gd")
var checks := 0
var failures: Array[String] = []
var maximum_vertices := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)

func _run() -> void:
	print("V2_SOURCE_SHA256 ", FileAccess.get_sha256("res://actors/gloam_vigil/v2/gloam_vigil_player_v2.glb"))
	for scale_value in [0.88, 1.0, 1.16]:
		var measurement := Node3D.new()
		root.add_child(measurement)
		var actor := Node3D.new()
		actor.scale = Vector3.ONE * 1.35 * scale_value
		measurement.add_child(actor)
		var parts: Dictionary = Builder.build_player(actor, Color("#c55c77"), true)
		var rig: Dictionary = parts["authored_rig"]
		var skeleton: Skeleton3D = rig["skeleton"]
		await process_frame
		check(bool(rig.get("is_v2", skeleton.get_bone_count() > 20)), "candidate rig actually selected")
		var rest_error := 0.0
		for bone in skeleton.get_bone_count():
			var a := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
			var b := skeleton.get_bone_pose_rotation(bone)
			# acos(dot) has a float32 precision floor near identity: even
			# rest.angle_to(rest) can report 0.00069rad. Quaternion difference
			# plus atan2 preserves the original angular tolerance without that
			# cancellation error; it does not relax the acceptance threshold.
			var difference := a.normalized().inverse() * b.normalized()
			var sine_half := Vector3(difference.x, difference.y, difference.z).length()
			rest_error = maxf(rest_error, 2.0 * atan2(sine_half, absf(difference.w)))
			check(skeleton.get_bone_global_rest(bone).origin.distance_to(skeleton.get_bone_global_pose(bone).origin) < 0.0001, "bind joint origin " + skeleton.get_bone_name(bone))
		check(rest_error < 0.0005, "bind rotations preserve imported rest %.8f rad" % rest_error)
		var initial_transform := actor.transform
		var cache := cache_surfaces(rig)
		check(cache.size() >= 3, "all candidate mesh surfaces cached")
		var bind := bounds(measurement, skeleton, cache)
		check(bind.finite and bind.count > 0, "bind full mesh and morph values finite")
		print("V2_BIND scale=", scale_value, " bones=", skeleton.get_bone_count(), " vertices=", bind.count, " min=", bind.min, " max=", bind.max)
		for step in 12:
			var phase := float(step) * TAU / 12.0
			for warm in 8:
				Builder.pose_player(parts, phase, 1.0, 1.0 / 60.0, &"grounded", 0.0)
			var sample := bounds(measurement, skeleton, cache)
			check(sample.finite, "walk finite scale %.2f step%d" % [scale_value, step])
			check(sample.min.y >= -0.03, "walk floor scale %.2f step%d min %.5f" % [scale_value, step, sample.min.y])
			check(sample.foot_min <= 0.055, "walk planted contact scale %.2f step%d foot %.5f" % [scale_value, step, sample.foot_min])
		for step in 8:
			Builder.pose_player(parts, float(step) * TAU / 8.0, 1.0, 1.0, &"crouch", 1.0)
			var sample := bounds(measurement, skeleton, cache)
			check(sample.finite, "crouch finite")
			check(sample.min.y >= -0.03, "crouch floor scale %.2f step%d min %.5f" % [scale_value, step, sample.min.y])
			check(sample.max.y <= 2.0, "crouch lintel scale %.2f step%d max %.5f" % [scale_value, step, sample.max.y])
		var actions := {"evade": 0.42, "grapple": 0.32, "grapple_recover": 0.32, "jump": 0.62, "vault": 0.48, "strike": 0.32, "counter": 0.55, "fall": 0.5}
		for state: String in actions:
			for reset_step in 90:
				Builder.pose_player(parts, 0.0, 0.0, 1.0 / 60.0, &"grounded", 0.0)
			var steps := maxi(1, ceili(float(actions[state]) * 60.0))
			var minimum_y := INF
			var maximum_y := -INF
			for step in range(steps + 1):
				Builder.pose_player(parts, 0.0, 0.0, 1.0 / 60.0, StringName(state), float(step) / steps)
				if step % 3 == 0 or step == steps:
					var sample := bounds(measurement, skeleton, cache)
					check(sample.finite, "%s finite scale %.2f step%d" % [state, scale_value, step])
					check((sample.max - sample.min).length() < 7.0, "%s bounded scale %.2f step%d" % [state, scale_value, step])
					minimum_y = minf(minimum_y, sample.min.y)
					maximum_y = maxf(maximum_y, sample.max.y)
			if state == "evade":
				check(minimum_y >= -0.03, "evade all-mesh floor scale %.2f min %.5f" % [scale_value, minimum_y])
			print("V2_ACTION scale=", scale_value, " state=", state, " min_y=", minimum_y, " max_y=", maximum_y)
			for reset_step in 180:
				Builder.pose_player(parts, 0.0, 0.0, 1.0 / 60.0, &"grounded", 0.0)
			var recovered := bounds(measurement, skeleton, cache)
			check(actor.transform.is_equal_approx(initial_transform), state + " preserves gameplay actor transform")
			check(recovered.finite and recovered.min.y >= -0.03 and recovered.foot_min <= 0.055, state + " recovers to grounded contact")
			for bone in skeleton.get_bone_count():
				check(skeleton.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE), state + " keeps bone scale " + skeleton.get_bone_name(bone))
		# Material null cleanup only suppresses a known dummy-renderer teardown
		# issue. It occurs after every measured pose and never modifies resources.
		for mesh in rig.get("mesh_instances", [rig["mesh_instance"]]):
			(mesh as MeshInstance3D).material_override = null
			for surface in (mesh as MeshInstance3D).mesh.get_surface_count():
				(mesh as MeshInstance3D).set_surface_override_material(surface, null)
		measurement.queue_free()
		await process_frame
	print("V2_DEFORMATION_REVIEW ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size(), " max_vertices=", maximum_vertices)
	quit(0 if failures.is_empty() else 1)

func cache_surfaces(rig: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var skeleton: Skeleton3D = rig["skeleton"]
	for mesh_node: MeshInstance3D in rig.get("mesh_instances", [rig["mesh_instance"]]):
		var skin: Skin = mesh_node.skin
		check(skin != null, "mesh has skin " + mesh_node.name)
		if skin == null:
			continue
		var binds: Array[int] = []
		for index in skin.get_bind_count():
			var bone := skin.get_bind_bone(index)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(index))
			binds.append(bone)
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			check(not joints.is_empty() and weights.size() == joints.size(), "skinned arrays " + mesh_node.name)
			var shapes: Array = []
			if mesh_node.mesh is ArrayMesh:
				shapes = (mesh_node.mesh as ArrayMesh).surface_get_blend_shape_arrays(surface)
			result.append({"node": mesh_node, "skin": skin, "binds": binds, "vertices": vertices, "joints": joints, "weights": weights, "influences": joints.size() / maxi(vertices.size(), 1), "shapes": shapes})
	return result

func bounds(host: Node3D, skeleton: Skeleton3D, cache: Array[Dictionary]) -> Dictionary:
	skeleton.force_update_all_bone_transforms()
	var to_host := host.global_transform.affine_inverse() * skeleton.global_transform
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var foot_min := INF
	var count := 0
	var finite := true
	for data in cache:
		var mesh_node: MeshInstance3D = data.node
		var mesh_to_skeleton := skeleton.global_transform.affine_inverse() * mesh_node.global_transform
		var skin: Skin = data.skin
		var matrices: Array[Transform3D] = []
		for bind in data.binds.size():
			matrices.append(skeleton.get_bone_global_pose(data.binds[bind]) * skin.get_bind_pose(bind))
		var morph_weights: Array[float] = []
		for shape in data.shapes.size():
			morph_weights.append(mesh_node.get_blend_shape_value(shape))
		for index in data.vertices.size():
			var vertex: Vector3 = data.vertices[index]
			for shape in data.shapes.size():
				if absf(morph_weights[shape]) > 0.00001:
					var shape_vertices: PackedVector3Array = data.shapes[shape][Mesh.ARRAY_VERTEX]
					if not shape_vertices.is_empty():
						var shape_vertex := shape_vertices[index]
						if (mesh_node.mesh as ArrayMesh).blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
							shape_vertex -= data.vertices[index]
						vertex += shape_vertex * morph_weights[shape]
			vertex = mesh_to_skeleton * vertex
			var skinned := Vector3.ZERO
			var sum := 0.0
			var foot_weight := 0.0
			for influence in data.influences:
				var offset: int = index * data.influences + influence
				var weight: float = data.weights[offset]
				if weight <= 0.0:
					continue
				var bind: int = data.joints[offset]
				skinned += (matrices[bind] * vertex) * weight
				sum += weight
				var bone_name: String = skeleton.get_bone_name(data.binds[bind])
				if bone_name.begins_with("foot.") or bone_name.begins_with("ball.") or bone_name.begins_with("toe."):
					foot_weight += weight
			var point := to_host * (skinned / maxf(sum, 0.00001))
			finite = finite and point.is_finite() and absf(sum - 1.0) < 0.001
			minimum = minimum.min(point)
			maximum = maximum.max(point)
			if foot_weight > 0.5:
				foot_min = minf(foot_min, point.y)
			count += 1
	maximum_vertices = maxi(maximum_vertices, count)
	return {"min": minimum, "max": maximum, "foot_min": foot_min, "count": count, "finite": finite}

