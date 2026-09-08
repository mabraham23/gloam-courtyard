extends SceneTree

## Read-only verification of the exact imported R7 Skeleton3D hand bases.
## This prints the engine-side rest origins/basis columns and never attaches the
## candidate to the default scene or changes a resource.

const PLAYER_PATH := "res://actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"
const EXPECTED_SHA256 := "faafa6290160bef7a5dc3aa8c4ba02d9a395e40679e124c49869f239f12dd66a"
const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(FileAccess.get_sha256(PLAYER_PATH) == EXPECTED_SHA256)
	var scene := load(PLAYER_PATH) as PackedScene
	assert(scene != null)
	var instance := scene.instantiate()
	root.add_child(instance)
	var skeleton := _find_skeleton(instance)
	assert(skeleton != null and skeleton.get_bone_count() == 74)
	var report := {
		"status": "READ_ONLY_IMPORTED_DIAGNOSTIC",
		"sha256": FileAccess.get_sha256(PLAYER_PATH),
		"skeleton_transform": _transform_record(skeleton.transform),
		"sides": {},
	}
	for side in ["L", "R"]:
		var rows := {}
		var hand_name := "hand.%s" % side
		var hand_index := skeleton.find_bone(hand_name)
		assert(hand_index >= 0)
		rows[hand_name] = {
			"local": _transform_record(skeleton.get_bone_rest(hand_index)),
			"global": _transform_record(skeleton.get_bone_global_rest(hand_index)),
		}
		for finger in FINGERS:
			for segment in range(1, 4):
				var name := "%s.%02d.%s" % [finger, segment, side]
				var index := skeleton.find_bone(name)
				assert(index >= 0)
				var rest := skeleton.get_bone_rest(index)
				var global_rest := skeleton.get_bone_global_rest(index)
				var child_origin = null
				if segment < 3:
					var child := skeleton.find_bone("%s.%02d.%s" % [finger, segment + 1, side])
					child_origin = _vector(skeleton.get_bone_global_rest(child).origin)
				rows[name] = {
					"local": _transform_record(rest),
					"global": _transform_record(global_rest),
					"next_joint_origin": child_origin,
				}
		report["sides"][side] = rows
	print("IMPORTED_HAND_AXES %s" % JSON.stringify(report))
	instance.queue_free()
	await process_frame
	quit(0)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _vector(value: Vector3) -> Array:
	return [snappedf(value.x, 0.00000001), snappedf(value.y, 0.00000001), snappedf(value.z, 0.00000001)]


func _transform_record(value: Transform3D) -> Dictionary:
	return {
		"origin": _vector(value.origin),
		"basis_x": _vector(value.basis.x),
		"basis_y": _vector(value.basis.y),
		"basis_z": _vector(value.basis.z),
	}
