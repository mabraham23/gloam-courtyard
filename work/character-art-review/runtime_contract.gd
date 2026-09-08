extends SceneTree

## Read-only proof that the explicit character-art asset satisfies and animates the full
## expanded rig/morph contract, then returns every channel to imported bind.

const Builder = preload("res://actors/character_visual_builder.gd")
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func require(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func rotation_error(a: Quaternion, b: Quaternion) -> float:
	var difference := (a.inverse() * b).normalized()
	return 2.0 * atan2(Vector3(difference.x, difference.y, difference.z).length(), absf(difference.w))


func _run() -> void:
	if not ResourceLoader.exists(Candidate.ASSET_PATH):
		require(false, "explicit character-art candidate resource exists")
		_finish()
		return
	var actor := Node3D.new()
	root.add_child(actor)
	var parts := Candidate.build_player(actor, Color("#c55c77"))
	var rig: Dictionary = parts["authored_rig"]
	var skeleton: Skeleton3D = rig["skeleton"]
	require(Candidate.is_exact_candidate(parts), "runtime contract selected exact 74-bone character-art path")
	var rest: Dictionary = {}
	var movement: Dictionary = {}
	var morph_movement := {
		"blink.L": 0.0,
		"blink.R": 0.0,
		"brow_inner_raise": 0.0,
		"jaw_clench": 0.0,
	}
	for bone_name: StringName in rig["bone_indices"]:
		var bone: int = rig["bone_indices"][bone_name]
		rest[bone_name] = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		movement[bone_name] = 0.0
	for frame in 90:
		var cycle := fposmod(float(frame) / 60.0, 1.0)
		# The shipped one-speed controller now drives the authored run gait directly.
		# Sample that exact presentation here so the twist-chain contract follows the
		# live controller rather than the retired walk blend (run_amount = 0.0).
		Builder.pose_player(parts, cycle * TAU, 1.0, 1.0 / 60.0, &"grounded", 0.0, &"right_punch", 1.0)
		for bone_name: StringName in movement:
			var bone: int = rig["bone_indices"][bone_name]
			movement[bone_name] = maxf(
				float(movement[bone_name]),
				rotation_error(rest[bone_name], skeleton.get_bone_pose_rotation(bone))
			)
		var sampled_face: MeshInstance3D = rig["face_mesh"]
		for index in sampled_face.mesh.get_blend_shape_count():
			var sampled_name := String(sampled_face.mesh.get_blend_shape_name(index))
			if morph_movement.has(sampled_name):
				morph_movement[sampled_name] = maxf(
					float(morph_movement[sampled_name]),
					absf(sampled_face.get_blend_shape_value(index))
				)
	for prefix in [
		"clavicle.", "thigh_twist.", "shin_twist.", "upper_arm_twist.",
		"forearm_twist.", "hand.", "index.", "ball.", "toe.", "eye.",
		"jaw", "cape_mid.", "cape_lower.", "cape_tip.",
	]:
		var maximum := 0.0
		for bone_name: StringName in movement:
			if String(bone_name).begins_with(prefix):
				maximum = maxf(maximum, float(movement[bone_name]))
		require(maximum > 0.003, "animated contract channel " + prefix)
	var face: MeshInstance3D = rig["face_mesh"]
	for morph_name in ["blink.L", "blink.R", "brow_inner_raise", "jaw_clench"]:
		var found := false
		for index in face.mesh.get_blend_shape_count():
			if face.mesh.get_blend_shape_name(index) == StringName(morph_name):
				found = true
				break
		require(found, "face morph present " + morph_name)
		require(float(morph_movement[morph_name]) > 0.01, "face morph animated " + morph_name)
	Builder.pose_player(parts, 0.0, 0.0, 0.0, &"bind", 0.0)
	for bone_name: StringName in rest:
		var bone: int = rig["bone_indices"][bone_name]
		require(
			rotation_error(rest[bone_name], skeleton.get_bone_pose_rotation(bone)) < 0.0005,
			"bind recovery " + bone_name
		)
	Candidate.clear_material_overrides(parts)
	_finish()


func _finish() -> void:
	print("GLOAM_CHARACTER_ART_RUNTIME_CONTRACT_", "OK" if failures.is_empty() else "FAILED", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
