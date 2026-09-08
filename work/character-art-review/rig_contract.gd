extends SceneTree

## Imported-data audit for a retargeted anatomical base. This validates the
## stable semantic hierarchy and meaningful skin ownership without pinning the
## old procedural joint coordinates.

const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
const MIN_WEIGHTED_VERTICES := 12
const MIN_TOTAL_WEIGHT := 2.0

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(Candidate.ASSET_PATH):
		_check(false, "explicit character-art candidate resource exists")
		_finish()
		return
	var actor := Node3D.new()
	root.add_child(actor)
	var parts := Candidate.build_player(actor, Color("#c55c77"))
	var rig: Dictionary = parts["authored_rig"]
	var skeleton: Skeleton3D = rig["skeleton"]
	_check(Candidate.is_exact_candidate(parts), "rig audit selected exact 74-bone character-art path")
	_check(skeleton.get_bone_count() == 74, "candidate has exactly 74 imported bones")

	var expected_parents := _expected_parents()
	_check(expected_parents.size() == 74, "expected semantic hierarchy enumerates all 74 bones")
	for bone_name: StringName in expected_parents:
		var bone := skeleton.find_bone(bone_name)
		_check(bone >= 0, "required bone exists: " + bone_name)
		if bone < 0:
			continue
		var expected_parent: StringName = expected_parents[bone_name]
		var actual_parent := skeleton.get_bone_parent(bone)
		if expected_parent == &"":
			_check(actual_parent < 0, "%s remains the hierarchy root" % bone_name)
		else:
			_check(actual_parent >= 0 and skeleton.get_bone_name(actual_parent) == expected_parent, "%s parent remains %s" % [bone_name, expected_parent])
		var rest := skeleton.get_bone_rest(bone)
		_check(rest.origin.is_finite() and rest.basis.is_finite(), "finite local rest transform: " + bone_name)
		if bone_name != &"root":
			var global_rest := skeleton.get_bone_global_rest(bone)
			var parent_global := skeleton.get_bone_global_rest(actual_parent)
			_check(global_rest.origin.distance_to(parent_global.origin) > 0.005, "non-collapsed anatomical anchor: " + bone_name)

	for pair in [[&"eye.L", &"eye.R"], [&"hand.L", &"hand.R"], [&"foot.L", &"foot.R"], [&"clavicle.L", &"clavicle.R"]]:
		var left := skeleton.get_bone_global_rest(skeleton.find_bone(pair[0])).origin
		var right := skeleton.get_bone_global_rest(skeleton.find_bone(pair[1])).origin
		_check(left.x < -0.001 and right.x > 0.001 and left.x < right.x, "%s/%s preserve left-negative-X right-positive-X semantics" % [pair[0], pair[1]])
	var left_eye := skeleton.find_bone(&"eye.L")
	var right_eye := skeleton.find_bone(&"eye.R")
	for eye in [left_eye, right_eye]:
		var direction := skeleton.get_bone_global_rest(eye).basis.y.normalized()
		_check(direction.dot(Vector3.BACK) > 0.80, "%s points along the character's +Z runtime forward axis" % skeleton.get_bone_name(eye))

	var ownership := _weight_ownership(rig, skeleton)
	_check(bool(ownership["valid"]), "all imported skin arrays and bind references are valid")
	var counts := ownership["counts"] as Dictionary
	var totals := ownership["totals"] as Dictionary
	var weakest_count := INF
	var weakest_total := INF
	var weakest_count_name := ""
	var weakest_total_name := ""
	for bone_name: StringName in rig["bone_indices"]:
		if bone_name == &"root":
			continue
		var count := int(counts.get(bone_name, 0))
		var total := float(totals.get(bone_name, 0.0))
		if count < weakest_count:
			weakest_count = count
			weakest_count_name = bone_name
		if total < weakest_total:
			weakest_total = total
			weakest_total_name = bone_name
		_check(count >= MIN_WEIGHTED_VERTICES, "%s has at least %d meaningfully weighted vertices (actual %d)" % [bone_name, MIN_WEIGHTED_VERTICES, count])
		_check(total >= MIN_TOTAL_WEIGHT, "%s has total skin weight at least %.1f (actual %.5f)" % [bone_name, MIN_TOTAL_WEIGHT, total])
	print(
		"GLOAM_CHARACTER_ART_RIG_REPORT path=", Candidate.source_path(parts),
		" sha256=", FileAccess.get_sha256(Candidate.ASSET_PATH),
		" weighted_vertices=", ownership["weighted_vertices"],
		" weakest_count=", weakest_count_name, ":", weakest_count,
		" weakest_total=", weakest_total_name, ":", weakest_total,
		" eye_left=", skeleton.get_bone_global_rest(left_eye).origin,
		" eye_right=", skeleton.get_bone_global_rest(right_eye).origin,
		" foot_left=", skeleton.get_bone_global_rest(skeleton.find_bone(&"foot.L")).origin,
		" foot_right=", skeleton.get_bone_global_rest(skeleton.find_bone(&"foot.R")).origin
	)
	Candidate.clear_material_overrides(parts)
	_finish()


func _expected_parents() -> Dictionary:
	var result := {
		&"root": &"",
		&"pelvis": &"root",
		&"spine": &"pelvis",
		&"spine_upper": &"spine",
		&"chest": &"spine_upper",
		&"neck": &"chest",
		&"head": &"neck",
		&"jaw": &"head",
		&"eye.L": &"head",
		&"eye.R": &"head",
	}
	for side in ["L", "R"]:
		result[StringName("thigh.%s" % side)] = &"pelvis"
		result[StringName("thigh_twist.%s" % side)] = StringName("thigh.%s" % side)
		result[StringName("shin.%s" % side)] = StringName("thigh_twist.%s" % side)
		result[StringName("shin_twist.%s" % side)] = StringName("shin.%s" % side)
		result[StringName("foot.%s" % side)] = StringName("shin_twist.%s" % side)
		result[StringName("ball.%s" % side)] = StringName("foot.%s" % side)
		result[StringName("toe.%s" % side)] = StringName("ball.%s" % side)
		result[StringName("clavicle.%s" % side)] = &"chest"
		result[StringName("upper_arm.%s" % side)] = StringName("clavicle.%s" % side)
		result[StringName("upper_arm_twist.%s" % side)] = StringName("upper_arm.%s" % side)
		result[StringName("forearm.%s" % side)] = StringName("upper_arm_twist.%s" % side)
		result[StringName("forearm_twist.%s" % side)] = StringName("forearm.%s" % side)
		result[StringName("hand.%s" % side)] = StringName("forearm_twist.%s" % side)
		for finger in ["thumb", "index", "middle", "ring", "pinky"]:
			var parent := StringName("hand.%s" % side)
			for segment in range(1, 4):
				var name := StringName("%s.%02d.%s" % [finger, segment, side])
				result[name] = parent
				parent = name
		result[StringName("cape.%s" % side)] = &"chest"
		result[StringName("cape_mid.%s" % side)] = StringName("cape.%s" % side)
		result[StringName("cape_lower.%s" % side)] = StringName("cape_mid.%s" % side)
		result[StringName("cape_tip.%s" % side)] = StringName("cape_lower.%s" % side)
	return result


func _weight_ownership(rig: Dictionary, skeleton: Skeleton3D) -> Dictionary:
	var counts := {}
	var totals := {}
	var valid := true
	var weighted_vertices := 0
	for bone_name: StringName in rig["bone_indices"]:
		counts[bone_name] = 0
		totals[bone_name] = 0.0
	for mesh_value in rig.get("mesh_instances", []):
		var mesh := mesh_value as MeshInstance3D
		if mesh == null or mesh.mesh == null or mesh.skin == null:
			valid = false
			continue
		var bind_bones: Array[int] = []
		for bind_index in mesh.skin.get_bind_count():
			var bone := mesh.skin.get_bind_bone(bind_index)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(bind_index))
			valid = valid and bone >= 0
			bind_bones.append(bone)
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var joints := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
			var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
			var influences := joints.size() / maxi(vertices.size(), 1)
			valid = valid and not vertices.is_empty() and weights.size() == joints.size() and influences in [4, 8]
			if vertices.is_empty() or weights.size() != joints.size() or influences not in [4, 8]:
				continue
			for vertex in vertices.size():
				var owns_weight := false
				for influence in influences:
					var packed_index := vertex * influences + influence
					var weight := weights[packed_index]
					if weight <= 0.00001:
						continue
					var bind := joints[packed_index]
					if bind < 0 or bind >= bind_bones.size() or bind_bones[bind] < 0:
						valid = false
						continue
					var bone_name := skeleton.get_bone_name(bind_bones[bind])
					counts[bone_name] = int(counts.get(bone_name, 0)) + 1
					totals[bone_name] = float(totals.get(bone_name, 0.0)) + weight
					owns_weight = true
				if owns_weight:
					weighted_vertices += 1
	return {"valid": valid, "counts": counts, "totals": totals, "weighted_vertices": weighted_vertices}


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _finish() -> void:
	print("GLOAM_CHARACTER_ART_RIG_", "OK" if failures.is_empty() else "FAILED", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

