extends RefCounted

## Narrow adapter between the accepted gameplay-owned pose curves and the
## Blender-authored Gloam Vigil skeleton. The imported GLB stays data-only:
## there are no colliders, root-motion tracks, or autonomous animations here.

const PLAYER_SCENE: PackedScene = preload("res://actors/gloam_vigil/gloam_vigil_player.glb")
const V2_PLAYER_SCENE_PATH := "res://actors/gloam_vigil/v2/gloam_vigil_player_v2.glb"
const V2_CLIPS := preload("res://actors/gloam_vigil/v2/runtime/gloam_vigil_animation_clips.gd")
const R7_WALK := preload("res://actors/gloam_vigil/v4/motion/cmu_walk_reference.gd")
const R7_RUN := preload("res://actors/gloam_vigil/v4/motion/cmu_run_reference.gd")
const R7_ACTION := preload("res://actors/gloam_vigil/v4/motion/r7_action_reference.gd")
const R7_LOCOMOTION := preload("res://actors/gloam_vigil/v4/motion/r7_locomotion_refinement.gd")

const REQUIRED_BONES := [
	&"root", &"pelvis", &"spine", &"chest", &"neck", &"head",
	&"upper_arm.L", &"forearm.L", &"hand.L",
	&"upper_arm.R", &"forearm.R", &"hand.R",
	&"thigh.L", &"shin.L", &"foot.L",
	&"thigh.R", &"shin.R", &"foot.R",
	&"cape.L", &"cape.R",
]

const V2_REQUIRED_BONES := [
	&"root", &"pelvis", &"spine", &"spine_upper", &"chest", &"neck", &"head", &"jaw", &"eye.L", &"eye.R",
	&"thigh.L", &"thigh_twist.L", &"shin.L", &"shin_twist.L", &"foot.L", &"ball.L", &"toe.L",
	&"clavicle.L", &"upper_arm.L", &"upper_arm_twist.L", &"forearm.L", &"forearm_twist.L", &"hand.L",
	&"thumb.01.L", &"thumb.02.L", &"thumb.03.L", &"index.01.L", &"index.02.L", &"index.03.L",
	&"middle.01.L", &"middle.02.L", &"middle.03.L", &"ring.01.L", &"ring.02.L", &"ring.03.L",
	&"pinky.01.L", &"pinky.02.L", &"pinky.03.L", &"cape.L", &"cape_mid.L", &"cape_lower.L", &"cape_tip.L",
	&"thigh.R", &"thigh_twist.R", &"shin.R", &"shin_twist.R", &"foot.R", &"ball.R", &"toe.R",
	&"clavicle.R", &"upper_arm.R", &"upper_arm_twist.R", &"forearm.R", &"forearm_twist.R", &"hand.R",
	&"thumb.01.R", &"thumb.02.R", &"thumb.03.R", &"index.01.R", &"index.02.R", &"index.03.R",
	&"middle.01.R", &"middle.02.R", &"middle.03.R", &"ring.01.R", &"ring.02.R", &"ring.03.R",
	&"pinky.01.R", &"pinky.02.R", &"pinky.03.R", &"cape.R", &"cape_mid.R", &"cape_lower.R", &"cape_tip.R",
]

const V2_MORPHS := [&"blink.L", &"blink.R", &"brow_inner_raise", &"jaw_clench"]
const V2_ACCENT_MATERIAL := "MAT_GV2_Accent"
const V1_ACCENT_MATERIAL := "MAT_Accent"
const START_DURATION := 0.42
const STOP_DURATION := 0.34
const PLANT_MAX_FRAME_TRAVEL := 0.22
const PLANT_MAX_TURN := 0.16
const PLANT_MAX_REACH := 1.015
const PLANT_MAX_JOINT_STEP := 0.65
# The imported R7 rest chain flares from 0.279 m at the hips to 0.431 m at the
# ankles. A small symmetric body-space hip adduction brings the calves/boots
# under the pelvis while an opposite ankle correction preserves foot attitude.
const R7_LOWER_LEG_ADDUCTION := 0.064
const R7_GROUNDED_MOTION_ADDUCTION := 0.0045


static func attach(parent: Node3D, accent_color: Color, prefer_v2 := false, candidate_scene_path: String = "") -> Dictionary:
	var player_scene := PLAYER_SCENE
	if not candidate_scene_path.is_empty():
		# Explicit review-only asset selection leaves both frozen baselines intact.
		assert(prefer_v2 and candidate_scene_path.begins_with("res://actors/gloam_vigil/"), "Candidate review requires the expanded Gloam Vigil contract")
		assert(ResourceLoader.exists(candidate_scene_path), "Candidate scene is not imported: %s" % candidate_scene_path)
		player_scene = load(candidate_scene_path) as PackedScene
	elif prefer_v2:
		assert(ResourceLoader.exists(V2_PLAYER_SCENE_PATH), "Requested Gloam Vigil v2 candidate is not imported: %s" % V2_PLAYER_SCENE_PATH)
		player_scene = load(V2_PLAYER_SCENE_PATH) as PackedScene
	var imported_root := player_scene.instantiate()
	imported_root.name = "AuthoredGloamVigil"
	parent.add_child(imported_root)

	var skeleton := _find_first_skeleton(imported_root)
	var mesh_instances: Array[MeshInstance3D] = []
	_find_meshes(imported_root, mesh_instances)
	assert(skeleton != null, "Gloam Vigil GLB must contain a Skeleton3D")
	assert(not mesh_instances.is_empty(), "Gloam Vigil GLB must contain at least one MeshInstance3D")
	var is_v2 := skeleton.find_bone(&"spine_upper") >= 0
	assert(not prefer_v2 or is_v2, "Requested Gloam Vigil v2 scene does not expose the v2 rig contract")
	var required_bones: Array = V2_REQUIRED_BONES if is_v2 else REQUIRED_BONES

	var bone_indices: Dictionary = {}
	var local_rest_rotations: Dictionary = {}
	var global_rest_rotations: Dictionary = {}
	for bone_name: StringName in required_bones:
		var bone_index := skeleton.find_bone(bone_name)
		assert(bone_index >= 0, "Gloam Vigil GLB is missing required bone: %s" % bone_name)
		bone_indices[bone_name] = bone_index
		local_rest_rotations[bone_name] = skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
		global_rest_rotations[bone_name] = skeleton.get_bone_global_rest(bone_index).basis.get_rotation_quaternion()

	var material_instances: Dictionary = {}
	var accent_material: StandardMaterial3D
	var accent_name := V2_ACCENT_MATERIAL if is_v2 else V1_ACCENT_MATERIAL
	for mesh_instance in mesh_instances:
		mesh_instance.extra_cull_margin = 2.5
		for surface in mesh_instance.mesh.get_surface_count():
			var imported_material := mesh_instance.mesh.surface_get_material(surface)
			if not imported_material is StandardMaterial3D:
				continue
			var material_name: String = String(mesh_instance.mesh.surface_get_name(surface))
			if material_name.is_empty():
				material_name = imported_material.resource_name
			var instance_material: StandardMaterial3D
			if material_instances.has(material_name):
				instance_material = material_instances[material_name]
			else:
				instance_material = imported_material.duplicate() as StandardMaterial3D
				instance_material.resource_local_to_scene = true
				# The authored albedo textures carry weave/leather variation. A slight
				# neutral lift keeps those dark PBR values readable in the moonlit GL
				# compatibility renderer without flattening the material response.
				instance_material.albedo_color = Color(1.10, 1.10, 1.10, 1.0)
				material_instances[material_name] = instance_material
			mesh_instance.set_surface_override_material(surface, instance_material)
			if material_name == accent_name:
				accent_material = instance_material

	assert(accent_material != null, "Gloam Vigil GLB must expose %s" % accent_name)
	accent_material.albedo_color = accent_color
	accent_material.emission_enabled = true
	accent_material.emission = accent_color
	accent_material.emission_energy_multiplier = 0.28

	var face_mesh: MeshInstance3D
	if is_v2:
		face_mesh = _find_morph_mesh(mesh_instances, V2_MORPHS)
		assert(face_mesh != null, "Gloam Vigil v2 face mesh must expose all facial morph targets")

	return {
		"imported_root": imported_root,
		"skeleton": skeleton,
		"mesh_instance": mesh_instances[0],
		"mesh_instances": mesh_instances,
		"face_mesh": face_mesh,
		"is_v2": is_v2,
		"anatomical_profile": candidate_scene_path == "res://actors/gloam_vigil/v4/gloam_vigil_player_v4.glb",
		"bone_indices": bone_indices,
		"local_rest_rotations": local_rest_rotations,
		"global_rest_rotations": global_rest_rotations,
		"foot_contacts": _foot_contacts(mesh_instances, skeleton),
		"contact_lift": 0.0,
		"accent_material": accent_material,
		"animation_library": V2_CLIPS.create_library() if is_v2 else null,
		"face_time": 0.0,
		"previous_movement": 0.0,
		"transition": &"",
		"transition_time": 0.0,
		"plant_actor_transform": Transform3D.IDENTITY,
		"plant_actor_transform_valid": false,
		"leg_lengths": _leg_lengths(skeleton) if is_v2 else {},
		"foot_plants": {
			"L": _empty_foot_plant(),
			"R": _empty_foot_plant(),
		},
	}


static func sync_pose(
	rig: Dictionary,
	drivers: Dictionary,
	pose_state: StringName = &"bind",
	delta := 0.0,
	phase := 0.0,
	movement := 0.0,
	pose_progress := 0.0,
	attack_variant: StringName = &"right_punch",
	run_amount := 0.0
) -> void:
	if rig.get("is_v2", false):
		_sync_v2_pose(rig, drivers, pose_state, delta, phase, movement, pose_progress, attack_variant, run_amount)
		if bool(rig.get("anatomical_profile", false)):
			# The measured gait already owns stance and swing. Both the legacy full
			# lock and a bounded 48%-weight central-stance experiment caused reach
			# blocks without materially reducing foot speed, so R7 keeps no IK residue.
			_clear_foot_plants(rig)
		else:
			_update_v2_foot_plants(rig, drivers, pose_state, delta, phase, movement)
	else:
		_sync_v1_pose(rig, drivers)
	_update_foot_contact(rig, drivers, pose_state, delta, attack_variant)


static func _sync_v1_pose(rig: Dictionary, drivers: Dictionary) -> void:
	var pelvis_euler := (drivers["pelvis_root"] as Node3D).rotation
	var torso_euler := (drivers["torso_root"] as Node3D).rotation
	var head_euler := (drivers["head_root"] as Node3D).rotation
	_set_anatomical_rotation(rig, &"pelvis", pelvis_euler)
	# Share core motion across the spine/chest and neck/head chains. This avoids
	# rigid mid-torso hinges while preserving the accepted pose targets.
	_set_anatomical_rotation(rig, &"spine", torso_euler * 0.38)
	_set_anatomical_rotation(rig, &"chest", torso_euler * 0.68)
	_set_anatomical_rotation(rig, &"neck", head_euler * 0.32)
	_set_anatomical_rotation(rig, &"head", head_euler * 0.76)

	_set_anatomical_rotation(rig, &"thigh.L", drivers["left_leg"].rotation)
	_set_anatomical_rotation(rig, &"thigh.R", drivers["right_leg"].rotation)
	_set_anatomical_rotation(rig, &"shin.L", drivers["left_knee"].rotation)
	_set_anatomical_rotation(rig, &"shin.R", drivers["right_knee"].rotation)
	_set_anatomical_rotation(rig, &"foot.L", drivers["left_ankle"].rotation)
	_set_anatomical_rotation(rig, &"foot.R", drivers["right_ankle"].rotation)
	_set_anatomical_rotation(rig, &"upper_arm.L", drivers["left_arm"].rotation)
	_set_anatomical_rotation(rig, &"upper_arm.R", drivers["right_arm"].rotation)
	_set_anatomical_rotation(rig, &"forearm.L", drivers["left_elbow"].rotation)
	_set_anatomical_rotation(rig, &"forearm.R", drivers["right_elbow"].rotation)

	var left_cape := (drivers["left_tail"] as Node3D).rotation
	var right_cape := (drivers["right_tail"] as Node3D).rotation
	_set_anatomical_rotation(rig, &"cape.L", Vector3(left_cape.x * 0.58, left_cape.y * 0.25, left_cape.z * 0.30))
	_set_anatomical_rotation(rig, &"cape.R", Vector3(right_cape.x * 0.58, right_cape.y * 0.25, right_cape.z * 0.30))


static func _sync_v2_pose(
	rig: Dictionary,
	drivers: Dictionary,
	pose_state: StringName,
	delta: float,
	phase: float,
	movement: float,
	pose_progress: float,
	attack_variant: StringName,
	run_amount: float
) -> void:
	# Reset every deform channel to its imported rest before composing this frame.
	# This guarantees bind/zero-driver identity and prevents stale finger, face, or
	# cape-chain values when returning from an action.
	for bone_name: StringName in V2_REQUIRED_BONES:
		_set_anatomical_rotation(rig, bone_name, Vector3.ZERO)
	_reset_morphs(rig)
	if pose_state == &"bind":
		return

	var pelvis_euler := (drivers["pelvis_root"] as Node3D).rotation
	var torso_euler := (drivers["torso_root"] as Node3D).rotation
	var head_euler := (drivers["head_root"] as Node3D).rotation
	_set_anatomical_rotation(rig, &"pelvis", pelvis_euler)
	# The inserted spine_upper distributes the same 1.06 total core response used
	# by v1; it does not add a second torso rotation on top of the legacy chain.
	_set_anatomical_rotation(rig, &"spine", torso_euler * 0.22)
	_set_anatomical_rotation(rig, &"spine_upper", torso_euler * 0.31)
	_set_anatomical_rotation(rig, &"chest", torso_euler * 0.53)
	_set_anatomical_rotation(rig, &"neck", head_euler * 0.32)
	_set_anatomical_rotation(rig, &"head", head_euler * 0.76)

	_apply_twist_chain(rig, &"thigh.L", &"thigh_twist.L", (drivers["left_leg"] as Node3D).rotation, 0.24)
	_apply_twist_chain(rig, &"thigh.R", &"thigh_twist.R", (drivers["right_leg"] as Node3D).rotation, 0.24)
	_apply_twist_chain(rig, &"shin.L", &"shin_twist.L", (drivers["left_knee"] as Node3D).rotation, 0.18)
	_apply_twist_chain(rig, &"shin.R", &"shin_twist.R", (drivers["right_knee"] as Node3D).rotation, 0.18)
	_set_anatomical_rotation(rig, &"foot.L", (drivers["left_ankle"] as Node3D).rotation)
	_set_anatomical_rotation(rig, &"foot.R", (drivers["right_ankle"] as Node3D).rotation)

	_apply_v2_arm(rig, "L", (drivers["left_arm"] as Node3D).rotation, (drivers["left_elbow"] as Node3D).rotation)
	_apply_v2_arm(rig, "R", (drivers["right_arm"] as Node3D).rotation, (drivers["right_elbow"] as Node3D).rotation)
	_apply_v2_cape(rig, "L", (drivers["left_tail"] as Node3D).rotation)
	_apply_v2_cape(rig, "R", (drivers["right_tail"] as Node3D).rotation)

	if pose_state == &"grounded":
		_apply_grounded_animation(rig, phase, movement, delta, run_amount)
	else:
		_apply_action_secondary(rig, pose_state, pose_progress)
	if bool(rig.get("anatomical_profile", false)):
		# Exact-R7 actions need body-space deformation on the expanded twist,
		# clavicle, spine and hand chains. The legacy drivers still animate every
		# other candidate, and gameplay/root motion remains controller-owned.
		_apply_animation_channels(rig, R7_ACTION.sample(pose_state, pose_progress, attack_variant))
		# The source rig's phalanges do not hinge around body-space X. Override
		# the legacy clip/action curls with measured mirrored flex axes so R7 hands
		# close into their palms instead of opening into a claw.
		_apply_v4_hand_animation(rig, pose_state, pose_progress, attack_variant)
		_apply_r7_lower_leg_stance(rig, pose_state, pose_progress, attack_variant)
	_apply_face_animation(rig, pose_state, delta, pose_progress)


static func _update_v2_foot_plants(
	rig: Dictionary,
	drivers: Dictionary,
	pose_state: StringName,
	delta: float,
	phase: float,
	movement: float
) -> void:
	# This is a presentation-only stance constraint. The gameplay actor has
	# already moved when this runs; the target stays in world space while the
	# thigh/shin chain follows it. It never writes the actor, collider, visual
	# root, or imported root transforms.
	var actor := (drivers["visual_root"] as Node3D).get_parent() as Node3D
	var actor_transform := actor.global_transform
	if not bool(rig["plant_actor_transform_valid"]):
		rig["plant_actor_transform"] = actor_transform
		rig["plant_actor_transform_valid"] = true
		return
	var previous: Transform3D = rig["plant_actor_transform"]
	rig["plant_actor_transform"] = actor_transform
	var frame_travel := actor_transform.origin.distance_to(previous.origin)
	var frame_turn := _basis_rotation(actor_transform.basis).angle_to(_basis_rotation(previous.basis))
	var can_plant := (
		pose_state == &"grounded"
		and movement > 0.18
		and delta > 0.0
		and frame_travel > 0.0004
		and frame_travel <= PLANT_MAX_FRAME_TRAVEL
		and frame_turn <= PLANT_MAX_TURN
	)
	if not can_plant:
		_clear_foot_plants(rig)
		return

	var normalized_phase := fposmod(phase, TAU) / TAU
	var support := {
		"L": normalized_phase >= 0.25 and normalized_phase < 0.40,
		"R": normalized_phase >= 0.75 and normalized_phase < 0.90,
	}
	for side in ["L", "R"]:
		var plant: Dictionary = rig["foot_plants"][side]
		if support[side]:
			if bool(plant["blocked"]):
				continue
			if not bool(plant["active"]):
				_capture_foot_plant(rig, side, actor_transform)
				plant = rig["foot_plants"][side]
			plant["weight"] = minf(float(plant["weight"]) + delta * 30.0, 1.0)
			if _plant_is_reachable(rig, side, plant, actor_transform):
				_solve_foot_plant(rig, side, plant)
			else:
				plant["active"] = false
				plant["weight"] = 0.0
				plant["blocked"] = true
		else:
			plant["blocked"] = false
			# Fade the final constraint over a few swing frames. This avoids a
			# one-frame pop without dragging the foot after toe-off.
			plant["weight"] = maxf(float(plant["weight"]) - delta * 18.0, 0.0)
			if bool(plant["active"]) and float(plant["weight"]) > 0.0:
				_solve_foot_plant(rig, side, plant)
			else:
				plant["active"] = false


static func _empty_foot_plant() -> Dictionary:
	return {
		"active": false,
		"blocked": false,
		"weight": 0.0,
		"world_position": Vector3.ZERO,
		"world_rotation": Quaternion.IDENTITY,
		"actor_rotation": Quaternion.IDENTITY,
	}


static func _leg_lengths(skeleton: Skeleton3D) -> Dictionary:
	var result: Dictionary = {}
	for side in ["L", "R"]:
		var thigh := skeleton.find_bone("thigh.%s" % side)
		var shin := skeleton.find_bone("shin.%s" % side)
		var foot := skeleton.find_bone("foot.%s" % side)
		assert(thigh >= 0 and shin >= 0 and foot >= 0, "Gloam Vigil v2 leg chain is incomplete")
		var hip_position := skeleton.get_bone_global_rest(thigh).origin
		var knee_position := skeleton.get_bone_global_rest(shin).origin
		var ankle_position := skeleton.get_bone_global_rest(foot).origin
		result[side] = {
			"upper": hip_position.distance_to(knee_position),
			"lower": knee_position.distance_to(ankle_position),
		}
	return result


static func _capture_foot_plant(rig: Dictionary, side: String, actor_transform: Transform3D) -> void:
	var skeleton := rig["skeleton"] as Skeleton3D
	var foot: int = rig["bone_indices"][StringName("foot.%s" % side)]
	skeleton.force_update_all_bone_transforms()
	var foot_world := skeleton.global_transform * skeleton.get_bone_global_pose(foot)
	var plant: Dictionary = rig["foot_plants"][side]
	plant["active"] = true
	plant["weight"] = 0.0
	plant["world_position"] = foot_world.origin
	plant["world_rotation"] = _basis_rotation(foot_world.basis)
	plant["actor_rotation"] = _basis_rotation(actor_transform.basis)


static func _plant_is_reachable(rig: Dictionary, side: String, plant: Dictionary, actor_transform: Transform3D) -> bool:
	var captured_actor_rotation: Quaternion = plant["actor_rotation"]
	if captured_actor_rotation.angle_to(_basis_rotation(actor_transform.basis)) > PLANT_MAX_TURN:
		return false
	var skeleton := rig["skeleton"] as Skeleton3D
	var thigh: int = rig["bone_indices"][StringName("thigh.%s" % side)]
	skeleton.force_update_all_bone_transforms()
	var target := skeleton.global_transform.affine_inverse() * (plant["world_position"] as Vector3)
	var hip := skeleton.get_bone_global_pose(thigh).origin
	var lengths: Dictionary = rig["leg_lengths"][side]
	var total_length := float(lengths["upper"]) + float(lengths["lower"])
	return hip.distance_to(target) <= total_length * PLANT_MAX_REACH


static func _solve_foot_plant(rig: Dictionary, side: String, plant: Dictionary) -> void:
	var skeleton := rig["skeleton"] as Skeleton3D
	var thigh: int = rig["bone_indices"][StringName("thigh.%s" % side)]
	var shin: int = rig["bone_indices"][StringName("shin.%s" % side)]
	var foot: int = rig["bone_indices"][StringName("foot.%s" % side)]
	var target := skeleton.global_transform.affine_inverse() * (plant["world_position"] as Vector3)
	var weight := smoothstep(0.0, 1.0, clampf(float(plant["weight"]), 0.0, 1.0))
	# Analytic two-bone target keeps the knee on its authored bend side. Twist
	# bones lie inside each measured span, so rotating the legacy thigh/shin
	# anchors also moves the complete expanded chain without an iterative solver.
	skeleton.force_update_all_bone_transforms()
	var hip_position := skeleton.get_bone_global_pose(thigh).origin
	var knee_position := skeleton.get_bone_global_pose(shin).origin
	var ankle_position := skeleton.get_bone_global_pose(foot).origin
	var upper_length := hip_position.distance_to(knee_position)
	var lower_length := knee_position.distance_to(ankle_position)
	var target_vector := target - hip_position
	var target_distance := target_vector.length()
	if upper_length > 0.0001 and lower_length > 0.0001 and target_distance > 0.0001:
		var target_direction := target_vector / target_distance
		var solved_distance := minf(target_distance, (upper_length + lower_length) * 0.9995)
		var upper_projection := (
			upper_length * upper_length + solved_distance * solved_distance - lower_length * lower_length
		) / (2.0 * solved_distance)
		var bend_height := sqrt(maxf(upper_length * upper_length - upper_projection * upper_projection, 0.0))
		var authored_upper := knee_position - hip_position
		var bend_direction := authored_upper - target_direction * authored_upper.dot(target_direction)
		if bend_direction.length_squared() < 0.000001:
			bend_direction = target_direction.cross(Vector3.RIGHT)
			if bend_direction.length_squared() < 0.000001:
				bend_direction = target_direction.cross(Vector3.FORWARD)
		bend_direction = bend_direction.normalized()
		var desired_knee := hip_position + target_direction * upper_projection + bend_direction * bend_height
		var hip_delta := Quaternion(authored_upper.normalized(), (desired_knee - hip_position).normalized())
		hip_delta = Quaternion.IDENTITY.slerp(hip_delta, weight)
		_apply_bone_global_delta(skeleton, thigh, _clamp_rotation(hip_delta, PLANT_MAX_JOINT_STEP))
		skeleton.force_update_all_bone_transforms()
		knee_position = skeleton.get_bone_global_pose(shin).origin
		ankle_position = skeleton.get_bone_global_pose(foot).origin
		var lower_vector := ankle_position - knee_position
		var final_vector := target - knee_position
		if lower_vector.length_squared() > 0.000001 and final_vector.length_squared() > 0.000001:
			var shin_delta := Quaternion(lower_vector.normalized(), final_vector.normalized())
			shin_delta = Quaternion.IDENTITY.slerp(shin_delta, weight)
			_apply_bone_global_delta(skeleton, shin, _clamp_rotation(shin_delta, PLANT_MAX_JOINT_STEP))

	# Preserve the captured foot attitude after the upper chain reaches. The
	# ball/toe keys remain free to articulate beyond this ankle orientation.
	skeleton.force_update_all_bone_transforms()
	var desired_world: Quaternion = plant["world_rotation"]
	var skeleton_world := _basis_rotation(skeleton.global_transform.basis)
	var desired_skeleton := skeleton_world.inverse() * desired_world
	var current_skeleton := skeleton.get_bone_global_pose(foot).basis.get_rotation_quaternion()
	var foot_delta := desired_skeleton * current_skeleton.inverse()
	foot_delta = Quaternion.IDENTITY.slerp(foot_delta, weight)
	_apply_bone_global_delta(skeleton, foot, _clamp_rotation(foot_delta, 0.38))


static func _apply_bone_global_delta(skeleton: Skeleton3D, bone: int, global_delta: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_rotation := Quaternion.IDENTITY
	if parent >= 0:
		parent_rotation = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local_delta := parent_rotation.inverse() * global_delta * parent_rotation
	var current_local := skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (local_delta * current_local).normalized())


static func _apply_r7_lower_leg_stance(rig: Dictionary, pose_state: StringName, pose_progress: float, attack_variant: StringName) -> void:
	# Calibrate presentation only. The gameplay root/collider and imported rest
	# transforms remain unchanged, and dynamic traversal/fall poses keep their
	# authored envelopes. Grounded, crouch and combat contacts share the narrower
	# base so the silhouette does not pop back outward on an attack transition.
	var weights := {"L": 0.0, "R": 0.0}
	match pose_state:
		&"grounded", &"crouch", &"counter", &"hurt":
			weights["L"] = 1.0
			weights["R"] = 1.0
		&"strike":
			weights["L"] = 1.0
			weights["R"] = 1.0
			if attack_variant == &"left_kick" or attack_variant == &"right_kick":
				# R7's logical right uses its spatially x-negative .L chain.
				var attacking_side := "L" if attack_variant == &"right_kick" else "R"
				var contact_release := sin(clampf(pose_progress, 0.0, 1.0) * PI)
				weights[attacking_side] = lerpf(1.0, 0.28, contact_release)
		_:
			return

	var skeleton := rig["skeleton"] as Skeleton3D
	var stance_angle := R7_LOWER_LEG_ADDUCTION
	if pose_state == &"grounded":
		# The captured swing briefly opens wider than the calibrated idle base.
		# A sub-degree motion-only correction keeps the feet under the hips while
		# preserving the source cadence, flexion, and planted-foot orientation.
		stance_angle += R7_GROUNDED_MOTION_ADDUCTION * clampf(float(rig.get("previous_movement", 0.0)), 0.0, 1.0)
	for side in ["L", "R"]:
		var weight: float = weights[side]
		if weight <= 0.0001:
			continue
		var signed_angle := stance_angle if side == "L" else -stance_angle
		_apply_bone_global_delta(
			skeleton,
			rig["bone_indices"][StringName("thigh.%s" % side)],
			Quaternion(Vector3.BACK, signed_angle * weight)
		)
		skeleton.force_update_all_bone_transforms()
		_apply_bone_global_delta(
			skeleton,
			rig["bone_indices"][StringName("foot.%s" % side)],
			Quaternion(Vector3.BACK, -signed_angle * weight)
		)


static func _clamp_rotation(rotation: Quaternion, maximum_angle: float) -> Quaternion:
	var normalized := rotation.normalized()
	if normalized.w < 0.0:
		normalized = -normalized
	var angle := normalized.get_angle()
	if angle <= maximum_angle:
		return normalized
	return Quaternion.IDENTITY.slerp(normalized, maximum_angle / maxf(angle, 0.000001))


static func _basis_rotation(basis: Basis) -> Quaternion:
	return basis.orthonormalized().get_rotation_quaternion()


static func _clear_foot_plants(rig: Dictionary) -> void:
	for side in ["L", "R"]:
		var plant: Dictionary = rig["foot_plants"][side]
		plant["active"] = false
		plant["blocked"] = false
		plant["weight"] = 0.0


static func _apply_twist_chain(rig: Dictionary, major_name: StringName, twist_name: StringName, euler: Vector3, twist_share: float) -> void:
	# Body-space Y is the useful axial component for the predominantly vertical
	# bind limbs. Split it instead of applying the same rotation twice.
	var major := euler
	major.y *= 1.0 - twist_share
	_set_anatomical_rotation(rig, major_name, major)
	_set_anatomical_rotation(rig, twist_name, Vector3(0.0, euler.y * twist_share, 0.0))


static func _apply_v2_arm(rig: Dictionary, side: String, shoulder: Vector3, elbow: Vector3) -> void:
	var clavicle_share := Vector3(shoulder.x * 0.18, shoulder.y * 0.16, shoulder.z * 0.22)
	var upper := shoulder - clavicle_share
	var upper_twist := upper.y * 0.24
	upper.y -= upper_twist
	var lower := elbow
	var lower_twist := lower.y * 0.30
	lower.y -= lower_twist
	_set_anatomical_rotation(rig, StringName("clavicle.%s" % side), clavicle_share)
	_set_anatomical_rotation(rig, StringName("upper_arm.%s" % side), upper)
	_set_anatomical_rotation(rig, StringName("upper_arm_twist.%s" % side), Vector3(0.0, upper_twist, 0.0))
	_set_anatomical_rotation(rig, StringName("forearm.%s" % side), lower)
	_set_anatomical_rotation(rig, StringName("forearm_twist.%s" % side), Vector3(0.0, lower_twist, 0.0))


static func _apply_v2_cape(rig: Dictionary, side: String, driver: Vector3) -> void:
	var names := ["cape.%s" % side, "cape_mid.%s" % side, "cape_lower.%s" % side, "cape_tip.%s" % side]
	var shares := [0.27, 0.16, 0.10, 0.06]
	for index in names.size():
		var share: float = shares[index]
		_set_anatomical_rotation(rig, StringName(names[index]), Vector3(driver.x * share, driver.y * share * 0.55, driver.z * share * 0.70))


static func _apply_grounded_animation(rig: Dictionary, phase: float, movement: float, delta: float, run_amount: float) -> void:
	var library := rig["animation_library"] as AnimationLibrary
	var normalized_phase := fposmod(phase, TAU) / TAU
	var idle := V2_CLIPS.sample(library, V2_CLIPS.IDLE, normalized_phase * library.get_animation(V2_CLIPS.IDLE).length)
	if bool(rig.get("anatomical_profile", false)):
		_apply_r7_mocap_animation(rig, idle, phase, movement, run_amount)
		# The old generic start/stop overlays changed the torso after gameplay had
		# already started/stopped. Phase-locked motion blending now owns this seam.
		rig["previous_movement"] = movement
		rig["transition"] = &""
		rig["transition_time"] = 0.0
		return
	var locomotion_clip: StringName = V2_CLIPS.LOCOMOTION_R7 if bool(rig.get("anatomical_profile", false)) else V2_CLIPS.LOCOMOTION
	var walk_animation := library.get_animation(locomotion_clip)
	var walk := V2_CLIPS.sample(library, locomotion_clip, normalized_phase * walk_animation.length)
	var motion := smoothstep(0.06, 0.94, clampf(movement, 0.0, 1.0))
	var authored: Dictionary = V2_CLIPS.blend(idle, walk, motion)
	var previous: float = rig["previous_movement"]
	var transition: StringName = rig["transition"]
	if movement > previous + 0.015 and previous < 0.25 and transition != V2_CLIPS.START:
		transition = V2_CLIPS.START
		rig["transition_time"] = 0.0
	elif movement < previous - 0.015 and previous > 0.25 and transition != V2_CLIPS.STOP:
		transition = V2_CLIPS.STOP
		rig["transition_time"] = 0.0
	rig["previous_movement"] = movement
	if transition != &"":
		var duration := START_DURATION if transition == V2_CLIPS.START else STOP_DURATION
		var transition_time: float = minf(float(rig["transition_time"]) + delta, duration)
		rig["transition_time"] = transition_time
		authored = V2_CLIPS.add(authored, V2_CLIPS.sample(library, transition, transition_time))
		if transition_time >= duration:
			transition = &""
	rig["transition"] = transition
	if bool(rig.get("anatomical_profile", false)):
		# Retarget the technical scaffold's stance to the measured anatomical
		# leg rest: modest paired flex leaves knee reserve without widening the
		# reach guard, moving the gameplay root, or changing support intervals.
		for side in ["L", "R"]:
			for joint in ["thigh", "shin", "foot"]:
				var channel := StringName("%s.%s" % [joint, side])
				var value: Vector3 = authored.get(channel, Vector3.ZERO)
				value.x += (0.084 if joint == "shin" else -0.042) * motion
				authored[channel] = value
	_apply_animation_channels(rig, authored)


static func _apply_r7_mocap_animation(rig: Dictionary, idle: Dictionary, phase: float, movement: float, run_amount: float) -> void:
	var motion := smoothstep(0.04, 0.82, clampf(movement, 0.0, 1.0))
	var gait_mix := smoothstep(0.06, 0.94, clampf(run_amount, 0.0, 1.0))
	var walk_reference: Dictionary = R7_WALK.sample(phase)
	var run_reference: Dictionary = R7_RUN.sample(phase)
	var walk_rotations: Dictionary = R7_LOCOMOTION.refine_walk(walk_reference["rotations"] as Dictionary)
	var run_rotations: Dictionary = R7_LOCOMOTION.refine_run(run_reference["rotations"] as Dictionary)
	var rotations: Dictionary = {}
	for channel: StringName in walk_rotations:
		rotations[channel] = (walk_rotations[channel] as Quaternion).slerp(run_rotations[channel] as Quaternion, gait_mix).normalized()
	var authored := idle.duplicate()
	for channel: StringName in rotations:
		# CMU notes that its hand/toe endpoints can be noisy. The 48-sample source
		# is smoothed by quaternion interpolation, but wrists remain on the stable
		# forearm chain and the existing measured finger profiles remain authoritative.
		if channel == &"hand.L" or channel == &"hand.R":
			continue
		var idle_value: Variant = idle.get(channel, Vector3.ZERO)
		var idle_rotation := Quaternion.IDENTITY
		if idle_value is Vector3:
			idle_rotation = Quaternion.from_euler(idle_value as Vector3)
		authored[channel] = idle_rotation.slerp(rotations[channel] as Quaternion, motion).normalized()
	# The retarget already solves local deltas against the exact target skeleton.
	# Do not split its main rotations across child pivots because that would change
	# the solved knee, ankle and wrist paths. A separate, deliberately small layer
	# below animates the otherwise-unused twist/clavicle joints without moving the
	# captured endpoints.
	for side in ["L", "R"]:
		# CMU has a single toe-base endpoint. Add only a small phase-locked target
		# toe roll near push-off; the captured ball channel owns the main foot arc.
		var walk_window := R7_WALK.contact_window(side)
		var run_window := R7_RUN.contact_window(side)
		var window := walk_window.lerp(run_window, gait_mix)
		var normalized_phase := fposmod(phase, TAU) / TAU
		var lift := smoothstep(window.y - 0.15, window.y - 0.025, normalized_phase)
		lift *= 1.0 - smoothstep(window.y - 0.025, window.y + 0.035, normalized_phase)
		authored[StringName("toe.%s" % side)] = Quaternion(Vector3.RIGHT, 0.16 * lift * motion)
	# Keep the authored cape follow-through, which is presentation-specific and
	# absent from the human capture skeleton.
	var old_walk := V2_CLIPS.sample(rig["animation_library"], V2_CLIPS.LOCOMOTION_R7, fposmod(phase, TAU) / TAU)
	for channel: StringName in old_walk:
		if String(channel).begins_with("cape"):
			authored[channel] = old_walk[channel]
	_apply_animation_channels(rig, authored)
	_apply_r7_grounded_secondary(rig, phase, motion, gait_mix)


static func _apply_r7_grounded_secondary(rig: Dictionary, phase: float, motion: float, gait_mix: float) -> void:
	# CMU's source skeleton has no useful target clavicle or limb-twist motion.
	# Keep these secondary deltas small and phase locked: the shoulder girdle
	# counters the stride, while the long-limb twist bones absorb a few degrees of
	# axial turn. This adds visible joint participation without changing gameplay,
	# foot contacts, or the captured major-joint endpoints.
	var amplitude := lerpf(0.78, 1.0, gait_mix) * motion
	var stride := sin(phase) * amplitude
	var follow := sin(phase + 0.58) * amplitude
	_set_anatomical_rotation(rig, &"clavicle.L", Vector3(0.010 * amplitude, 0.010 * stride, -0.014 * stride))
	_set_anatomical_rotation(rig, &"clavicle.R", Vector3(0.010 * amplitude, -0.010 * stride, -0.014 * stride))
	_set_anatomical_rotation(rig, &"thigh_twist.L", Vector3(0.0, 0.042 * stride, 0.0))
	_set_anatomical_rotation(rig, &"thigh_twist.R", Vector3(0.0, -0.042 * stride, 0.0))
	_set_anatomical_rotation(rig, &"shin_twist.L", Vector3(0.0, -0.030 * follow, 0.0))
	_set_anatomical_rotation(rig, &"shin_twist.R", Vector3(0.0, 0.030 * follow, 0.0))


static func _apply_action_secondary(rig: Dictionary, pose_state: StringName, pose_progress: float) -> void:
	var progress := clampf(pose_progress, 0.0, 1.0)
	var finger_curl := 0.28
	var toe_roll := 0.0
	match pose_state:
		&"strike":
			finger_curl = 1.02
			toe_roll = 0.14 * sin(progress * PI)
		&"counter":
			finger_curl = 0.82
			toe_roll = 0.08
		&"grapple":
			finger_curl = lerpf(0.38, 0.76, smoothstep(0.12, 0.58, progress))
		&"grapple_recover":
			finger_curl = lerpf(0.72, 0.26, progress)
		&"crouch":
			finger_curl = 0.42
			toe_roll = 0.10
		&"jump", &"vault":
			finger_curl = 0.46
			toe_roll = 0.12 * sin(progress * PI)
		&"evade":
			finger_curl = 0.88
			toe_roll = 0.18 * sin(progress * PI)
		&"fall":
			finger_curl = 0.54
	for side in ["L", "R"]:
		_set_finger_curl(rig, side, finger_curl)
		_set_anatomical_rotation(rig, StringName("ball.%s" % side), Vector3(toe_roll, 0.0, 0.0))
		_set_anatomical_rotation(rig, StringName("toe.%s" % side), Vector3(toe_roll * 0.65, 0.0, 0.0))


static func _apply_v4_hand_animation(rig: Dictionary, pose_state: StringName, pose_progress: float, attack_variant: StringName = &"right_punch") -> void:
	var progress := clampf(pose_progress, 0.0, 1.0)
	var left_profile := &"relaxed"
	var right_profile := &"relaxed"
	var intensity := 0.0
	var left_intensity := -1.0
	var right_intensity := -1.0
	match pose_state:
		&"strike":
			var logical_right := attack_variant == &"right_punch" or attack_variant == &"right_kick"
			var is_kick := attack_variant == &"left_kick" or attack_variant == &"right_kick"
			if is_kick:
				# A guarded front kick keeps both hands compact; the previous open
				# brace read as a surrender pose at gameplay scale.
				left_profile = &"fist"
				right_profile = &"fist"
			elif logical_right:
				# Frozen suffixes are spatially mirrored; visible right is .L.
				left_profile = &"fist"
				right_profile = &"fist"
			else:
				left_profile = &"fist"
				right_profile = &"fist"
			var close := smoothstep(0.0, 0.28, progress)
			var ordinary_release := 1.0 - smoothstep(0.66, 1.0, progress)
			var active_release := 1.0 - smoothstep(0.86, 1.0, progress)
			intensity = close * ordinary_release
			if not is_kick:
				# Keep the contacting hand compact through the readable recovery.
				# Releasing both hands at 66% made the extended hand look open and
				# down-curved in late contact frames even though contact itself used
				# the source-tested compact profile. The guard hand still relaxes on
				# the original curve, preserving a natural asymmetric recovery.
				if logical_right:
					left_intensity = close * active_release
				else:
					right_intensity = close * active_release
		&"takedown":
			left_profile = &"grip"
			right_profile = &"grip"
			intensity = smoothstep(0.02, 0.24, progress) * (1.0 - smoothstep(0.76, 1.0, progress))
		&"grapple":
			left_profile = &"grip"
			right_profile = &"grip"
			intensity = smoothstep(0.08, 0.42, progress)
		&"grapple_recover":
			left_profile = &"grip"
			right_profile = &"grip"
			intensity = 1.0 - smoothstep(0.05, 0.86, progress)
		&"counter", &"evade", &"hurt":
			left_profile = &"brace"
			right_profile = &"brace"
			intensity = sin(progress * PI)
		&"jump", &"vault", &"fall":
			left_profile = &"grip"
			right_profile = &"grip"
			intensity = 0.24 * sin(progress * PI) if pose_state != &"fall" else 0.18
	_apply_v4_hand_profile(rig, "L", left_profile, left_intensity if left_intensity >= 0.0 else intensity)
	_apply_v4_hand_profile(rig, "R", right_profile, right_intensity if right_intensity >= 0.0 else intensity)


static func _apply_v4_hand_profile(rig: Dictionary, side: String, profile: StringName, amount: float) -> void:
	var blend := smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))
	var palm_normal := _v4_palm_normal(rig, side)
	# R7's imported rest fingers form an exaggerated fan. A modest baseline
	# adduction makes the zero-action hand read as relaxed and cupped; actions
	# still blend toward their distinct grip, fist, or brace silhouettes.
	var adduction_amount := lerpf(0.55, _v4_profile_adduction_amount(profile), blend)
	for finger in ["index", "middle", "ring", "pinky"]:
		var relaxed := _v4_hand_angles(&"relaxed", finger)
		var target := _v4_hand_angles(profile, finger)
		var axis := _v4_flex_axis(side, finger)
		for segment in range(1, 4):
			var degrees := lerpf(relaxed[segment - 1], target[segment - 1], blend)
			var body_delta := Quaternion(axis, deg_to_rad(degrees))
			if segment == 1 and adduction_amount > 0.0:
				# The imported rest hand fans its fingertips much wider than its
				# knuckle row. Bring only the MCPs toward the measured palm axis;
				# this preserves the frozen R7 weights and avoids rubbery web folds.
				var adduction := deg_to_rad(_v4_mcp_adduction_degrees(side, finger)) * adduction_amount
				body_delta = Quaternion(palm_normal, adduction) * body_delta
			_set_anatomical_body_delta(rig, StringName("%s.%02d.%s" % [finger, segment, side]), body_delta)
	var thumb_relaxed := _v4_hand_angles(&"relaxed", "thumb")
	var thumb_target := _v4_hand_angles(profile, "thumb")
	var opposition_relaxed := _v4_thumb_opposition_angles(&"relaxed")
	var opposition_target := _v4_thumb_opposition_angles(profile)
	var flex_axis := _v4_flex_axis(side, "thumb")
	var opposition_axis := _v4_thumb_opposition_axis(side)
	for segment in range(1, 4):
		var flex := deg_to_rad(lerpf(thumb_relaxed[segment - 1], thumb_target[segment - 1], blend))
		var opposition := deg_to_rad(lerpf(opposition_relaxed[segment - 1], opposition_target[segment - 1], blend))
		var body_delta := Quaternion(opposition_axis, opposition) * Quaternion(flex_axis, flex)
		_set_anatomical_body_delta(rig, StringName("thumb.%02d.%s" % [segment, side]), body_delta)


static func _v4_hand_angles(profile: StringName, finger: String) -> Array[float]:
	if finger == "thumb":
		match profile:
			&"grip": return [7.0, 7.0, 2.0]
			&"fist": return [9.0, 9.0, 3.0]
			&"brace": return [0.0, 1.0, 0.0]
			_: return [10.0, 10.0, 4.0]
	match profile:
		&"grip":
			match finger:
				"index": return [32.0, 22.0, 5.0]
				"middle": return [36.0, 24.0, 6.0]
				"ring": return [40.0, 26.0, 7.0]
				_: return [44.0, 28.0, 8.0]
		&"fist":
			match finger:
				"index": return [52.0, 28.0, 6.0]
				"middle": return [54.0, 30.0, 7.0]
				"ring": return [56.0, 32.0, 8.0]
				_: return [58.0, 34.0, 10.0]
		&"brace":
			match finger:
				"index": return [0.0, 1.0, 0.0]
				"middle": return [0.0, 0.0, 0.0]
				"ring": return [1.0, 2.0, 1.0]
				_: return [2.0, 3.0, 2.0]
		_:
			match finger:
				"index": return [14.0, 22.0, 8.0]
				"middle": return [16.0, 24.0, 10.0]
				"ring": return [18.0, 26.0, 12.0]
				_: return [20.0, 28.0, 14.0]


static func _v4_thumb_opposition_angles(profile: StringName) -> Array[float]:
	match profile:
		&"grip": return [20.0, 8.0, 2.0]
		&"fist": return [24.0, 10.0, 2.0]
		&"brace": return [0.0, 0.0, 0.0]
		_: return [16.0, 7.0, 2.0]


static func _v4_profile_adduction_amount(profile: StringName) -> float:
	match profile:
		&"fist": return 0.70
		&"grip": return 0.45
		&"brace": return 0.10
		_: return 0.0


static func _v4_mcp_adduction_degrees(side: String, finger: String) -> float:
	if side == "L":
		match finger:
			"index": return 20.07
			"middle": return 5.24
			"ring": return -5.35
			_: return -22.19
	match finger:
		"index": return -19.79
		"middle": return -4.99
		"ring": return 4.66
		_: return 22.67


static func _v4_palm_normal(rig: Dictionary, side: String) -> Vector3:
	var skeleton := rig["skeleton"] as Skeleton3D
	var wrist := skeleton.get_bone_global_rest(rig["bone_indices"][StringName("hand.%s" % side)]).origin
	var bases: Array[Vector3] = []
	for finger in ["index", "middle", "ring", "pinky"]:
		bases.append(skeleton.get_bone_global_rest(rig["bone_indices"][StringName("%s.01.%s" % [finger, side])]).origin)
	var knuckle_center := Vector3.ZERO
	for point in bases:
		knuckle_center += point
	knuckle_center /= float(bases.size())
	var longitudinal := (knuckle_center - wrist).normalized()
	var across := bases[0] - bases[3]
	across = (across - longitudinal * across.dot(longitudinal)).normalized()
	var normal := longitudinal.cross(across).normalized()
	var medial := Vector3.RIGHT if side == "L" else Vector3.LEFT
	if normal.dot(medial) < 0.0:
		normal = -normal
	return normal


static func _v4_flex_axis(side: String, finger: String) -> Vector3:
	if side == "L":
		match finger:
			"thumb": return Vector3(0.2207, 0.8409, 0.4941).normalized()
			"index": return Vector3(0.1553, 0.6055, 0.7806).normalized()
			"middle": return Vector3(0.0972, 0.3927, 0.9145).normalized()
			"ring": return Vector3(0.0515, 0.2239, 0.9733).normalized()
			_: return Vector3(-0.0242, -0.0580, 0.9980).normalized()
	match finger:
		"thumb": return Vector3(0.2132, -0.8427, -0.4945).normalized()
		"index": return Vector3(0.1481, -0.6079, -0.7801).normalized()
		"middle": return Vector3(0.0908, -0.3953, -0.9140).normalized()
		"ring": return Vector3(0.0500, -0.2418, -0.9690).normalized()
		_: return Vector3(-0.0290, 0.0598, -0.9978).normalized()


static func _v4_thumb_opposition_axis(side: String) -> Vector3:
	return (Vector3(0.8508, -0.3999, -0.3409) if side == "L" else Vector3(0.8504, 0.3993, 0.3425)).normalized()


static func _set_anatomical_axis_rotation(rig: Dictionary, bone_name: StringName, axis: Vector3, angle: float) -> void:
	_set_anatomical_body_delta(rig, bone_name, Quaternion(axis, angle))


static func _set_anatomical_body_delta(rig: Dictionary, bone_name: StringName, body_delta: Quaternion) -> void:
	var skeleton := rig["skeleton"] as Skeleton3D
	var local_rest: Quaternion = rig["local_rest_rotations"][bone_name]
	var global_rest: Quaternion = rig["global_rest_rotations"][bone_name]
	var local_delta := global_rest.inverse() * body_delta * global_rest
	skeleton.set_bone_pose_rotation(rig["bone_indices"][bone_name], (local_rest * local_delta).normalized())


static func _set_finger_curl(rig: Dictionary, side: String, curl: float) -> void:
	for finger in ["thumb", "index", "middle", "ring", "pinky"]:
		var character := 0.72 if finger == "thumb" else (0.88 if finger == "pinky" else 1.0)
		for segment in range(1, 4):
			var segment_scale := character * (0.72 + float(segment) * 0.12)
			_set_anatomical_rotation(rig, StringName("%s.%02d.%s" % [finger, segment, side]), Vector3(curl * segment_scale, 0.0, 0.0))


static func _apply_face_animation(rig: Dictionary, pose_state: StringName, delta: float, pose_progress: float) -> void:
	var library := rig["animation_library"] as AnimationLibrary
	var face_time: float = fposmod(float(rig["face_time"]) + maxf(delta, 0.0), library.get_animation(V2_CLIPS.FACE_ALIVE).length)
	rig["face_time"] = face_time
	_apply_animation_channels(rig, V2_CLIPS.sample(library, V2_CLIPS.FACE_ALIVE, face_time))
	var clench := 0.0
	var brow := 0.0
	var jaw_pitch := 0.0
	if pose_state == &"strike" or pose_state == &"counter" or pose_state == &"takedown":
		clench = 0.62 + 0.24 * sin(clampf(pose_progress, 0.0, 1.0) * PI)
		brow = 0.16
		jaw_pitch = -0.025
	elif pose_state == &"grapple" or pose_state == &"evade":
		clench = 0.42
		brow = 0.12
		jaw_pitch = -0.012
	elif pose_state == &"hurt":
		clench = 0.78 * sin(clampf(pose_progress, 0.0, 1.0) * PI)
		brow = 0.34
		jaw_pitch = -0.035
	elif pose_state == &"downed":
		clench = 0.18 * (1.0 - clampf(pose_progress, 0.0, 1.0))
		brow = 0.20
		jaw_pitch = 0.045
	elif pose_state == &"fall":
		clench = 0.18
		brow = 0.28
		jaw_pitch = 0.055
	if clench > 0.0:
		_set_morph(rig, &"jaw_clench", clench)
	if brow > 0.0:
		_set_morph(rig, &"brow_inner_raise", brow)
	if jaw_pitch != 0.0:
		_set_anatomical_rotation(rig, &"jaw", Vector3(jaw_pitch, 0.0, 0.0))


static func _apply_animation_channels(rig: Dictionary, channels: Dictionary) -> void:
	for channel: StringName in channels:
		var value: Variant = channels[channel]
		var channel_text := String(channel)
		if channel_text.begins_with("morph_"):
			var morph_name := channel_text.trim_prefix("morph_").replace("_L", ".L").replace("_R", ".R")
			_set_morph(rig, StringName(morph_name), clampf(float(value), 0.0, 1.0))
		elif value is Vector3 and rig["bone_indices"].has(channel):
			_set_anatomical_rotation(rig, channel, value)
		elif value is Quaternion and rig["bone_indices"].has(channel):
			_set_anatomical_body_delta(rig, channel, value as Quaternion)


static func _reset_morphs(rig: Dictionary) -> void:
	for morph_name: StringName in V2_MORPHS:
		_set_morph(rig, morph_name, 0.0)


static func _set_morph(rig: Dictionary, morph_name: StringName, value: float) -> void:
	var face_mesh := rig.get("face_mesh") as MeshInstance3D
	if face_mesh == null:
		return
	for index in face_mesh.mesh.get_blend_shape_count():
		if face_mesh.mesh.get_blend_shape_name(index) == morph_name:
			face_mesh.set_blend_shape_value(index, clampf(value, 0.0, 1.0))
			return


static func _foot_contacts(mesh_instances: Array[MeshInstance3D], skeleton: Skeleton3D) -> Array:
	# Contact ownership comes from real skin weights, not a surface/material name.
	# Each retained sample keeps all of its influences so ball/toe roll is measured
	# from the same deformed geometry the renderer uses.
	var contact_owner: Dictionary = {}
	for side in ["L", "R"]:
		for prefix in ["foot", "ball", "toe"]:
			var bone := skeleton.find_bone("%s.%s" % [prefix, side])
			if bone >= 0:
				contact_owner[bone] = side
	var candidates := {"L": [], "R": []}
	for mesh_instance in mesh_instances:
		var skin := mesh_instance.skin
		if skin == null:
			continue
		var bind_bones: Array[int] = []
		for bind_index in skin.get_bind_count():
			var bone_index := skin.get_bind_bone(bind_index)
			if bone_index < 0:
				bone_index = skeleton.find_bone(skin.get_bind_name(bind_index))
			bind_bones.append(bone_index)
		var mesh_to_skeleton := skeleton.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bone_indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bone_indices.is_empty() or weights.is_empty():
				continue
			var influence_count := bone_indices.size() / vertices.size()
			if influence_count != 4 and influence_count != 8:
				continue
			for vertex_index in vertices.size():
				var side_weights := {"L": 0.0, "R": 0.0}
				var influences: Array = []
				var total_weight := 0.0
				for influence in influence_count:
					var packed_index := vertex_index * influence_count + influence
					var weight := weights[packed_index]
					if weight <= 0.0:
						continue
					var bind_index := bone_indices[packed_index]
					if bind_index < 0 or bind_index >= bind_bones.size():
						continue
					var bone_index := bind_bones[bind_index]
					if bone_index < 0:
						continue
					influences.append({
						"bone": bone_index,
						"bind_pose": skin.get_bind_pose(bind_index),
						"weight": weight,
					})
					total_weight += weight
					if contact_owner.has(bone_index):
						var owner: String = contact_owner[bone_index]
						side_weights[owner] += weight
				var side := "L" if side_weights["L"] >= side_weights["R"] else "R"
				if side_weights[side] < 0.45 or total_weight <= 0.0:
					continue
				candidates[side].append({
					"id": "%s:%d:%d" % [mesh_instance.get_instance_id(), surface, vertex_index],
					"point": mesh_to_skeleton * vertices[vertex_index],
					"influences": influences,
					"total_weight": total_weight,
					"side": side,
				})
	var contacts: Array = []
	for side in ["L", "R"]:
		var selected := _select_low_contact_samples(candidates[side])
		assert(not selected.is_empty(), "Gloam Vigil skin must provide weighted %s foot contacts" % side)
		contacts.append_array(selected)
	return contacts


static func _select_low_contact_samples(candidates: Array) -> Array:
	if candidates.is_empty():
		return []
	var sole_y := INF
	for candidate: Dictionary in candidates:
		sole_y = minf(sole_y, candidate["point"].y)
	var low_band: Array = []
	for candidate: Dictionary in candidates:
		if candidate["point"].y <= sole_y + 0.018:
			low_band.append(candidate)
	var directions := [
		Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, 1.0),
		Vector3(-0.7, 0.0, -0.7), Vector3(-0.7, 0.0, 0.7),
		Vector3(0.7, 0.0, -0.7), Vector3(0.7, 0.0, 0.7),
	]
	var selected: Array = []
	var selected_ids: Dictionary = {}
	for direction: Vector3 in directions:
		var best: Dictionary = low_band[0]
		var best_score := -INF
		for candidate: Dictionary in low_band:
			var point: Vector3 = candidate["point"]
			var score := point.dot(direction) - (point.y - sole_y) * 3.0
			if score > best_score:
				best = candidate
				best_score = score
		if not selected_ids.has(best["id"]):
			selected_ids[best["id"]] = true
			selected.append(best)
	return selected


static func _update_foot_contact(
	rig: Dictionary,
	drivers: Dictionary,
	pose_state: StringName,
	delta: float,
	attack_variant: StringName = &"right_punch"
) -> void:
	if pose_state == &"bind":
		return
	var imported_root := rig["imported_root"] as Node3D
	var skeleton := rig["skeleton"] as Skeleton3D
	var grounded := pose_state in [&"grounded", &"crouch", &"strike", &"counter", &"takedown", &"grapple_recover"]
	if pose_state == &"evade":
		# Sole contact applies at takeoff/landing, never while the roll is inverted.
		var roll: float = (drivers["action_root"] as Node3D).rotation.x
		grounded = absf(wrapf(roll, -PI, PI)) < 0.15
	var target_lift := 0.0
	var planted_side := ""
	if pose_state == &"strike" and attack_variant in [&"left_kick", &"right_kick"]:
		# Frozen R7 suffixes are spatially mirrored: logical right uses .L.
		planted_side = "R" if attack_variant == &"right_kick" else "L"
	imported_root.position.y = 0.0
	if grounded:
		# Compose local transforms so this also works during scene construction.
		# The floor is player-local y=0; never move the gameplay root or collider.
		var to_actor := Transform3D.IDENTITY
		var node: Node3D = skeleton
		var actor := (drivers["visual_root"] as Node3D).get_parent()
		while node != actor:
			to_actor = node.transform * to_actor
			node = node.get_parent() as Node3D
		skeleton.force_update_all_bone_transforms()
		var minimum_y := INF
		var planted_minimum_y := INF
		for contact: Dictionary in rig["foot_contacts"]:
			var skinned := Vector3.ZERO
			for influence: Dictionary in contact["influences"]:
				skinned += (skeleton.get_bone_global_pose(influence["bone"]) * influence["bind_pose"] * contact["point"]) * float(influence["weight"])
			var total_weight: float = contact["total_weight"]
			if total_weight > 0.0:
				skinned /= total_weight
			var point := to_actor * skinned
			minimum_y = minf(minimum_y, point.y)
			if contact["side"] == planted_side:
				planted_minimum_y = minf(planted_minimum_y, point.y)
		if is_finite(minimum_y):
			if planted_side != "" and is_finite(planted_minimum_y):
				# Prefer the support sole, but retain 1.5 cm of safety against the
				# free toe during its earliest lift so no rendered shoe enters the floor.
				var requested_support_lift := -planted_minimum_y
				var floor_safe_lift := -minimum_y - 0.015
				target_lift = clampf(maxf(requested_support_lift, floor_safe_lift), -0.06, 0.28)
			else:
				target_lift = clampf(-minimum_y, 0.0, 0.28)
	var response := 1.0 - exp(-24.0 * delta)
	# Resolve downward contact immediately; ease the release back into free motion.
	var previous_lift: float = rig["contact_lift"]
	var lift := target_lift if planted_side != "" or target_lift > previous_lift else lerpf(previous_lift, target_lift, response)
	rig["contact_lift"] = lift
	imported_root.position.y = lift


static func _set_anatomical_rotation(rig: Dictionary, bone_name: StringName, euler: Vector3) -> void:
	var skeleton := rig["skeleton"] as Skeleton3D
	var local_rest: Quaternion = rig["local_rest_rotations"][bone_name]
	var global_rest: Quaternion = rig["global_rest_rotations"][bone_name]
	# Godot stores an absolute parent-local bone pose, not a delta from rest.
	# Convert the body-axis driver delta into this bone's rest axes, then compose
	# it with the imported local rest. Zero input must reproduce the bind pose.
	var local_delta := global_rest.inverse() * Quaternion.from_euler(euler) * global_rest
	skeleton.set_bone_pose_rotation(rig["bone_indices"][bone_name], (local_rest * local_delta).normalized())


static func _find_first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_first_skeleton(child)
		if found != null:
			return found
	return null


static func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null


static func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, result)


static func _find_morph_mesh(mesh_instances: Array[MeshInstance3D], required_morphs: Array) -> MeshInstance3D:
	for mesh_instance in mesh_instances:
		var available: Dictionary = {}
		for index in mesh_instance.mesh.get_blend_shape_count():
			available[mesh_instance.mesh.get_blend_shape_name(index)] = true
		var complete := true
		for morph_name: StringName in required_morphs:
			if not available.has(morph_name):
				complete = false
				break
		if complete:
			return mesh_instance
	return null
