extends SceneTree

## Structural/pose contract for the candidate corporate sentry. This does not
## claim user visual acceptance or firearm gameplay.

const Builder = preload("res://actors/character_visual_builder.gd")
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var parts := Candidate.build_guard(actor)
	var rig := parts["authored_rig"] as Dictionary
	var skeleton := rig["skeleton"] as Skeleton3D
	_check(Candidate.is_exact_guard(parts), "guard selects the exact R14 74-joint base")
	_check((parts["visual_root"] as Node3D).name == &"CrimsonCorporateSentryVisual", "guard has a distinct original visual root")
	_check((parts["helmet_attachment"] as BoneAttachment3D).bone_name == &"head", "helmet follows the head bone")
	_check((parts["sidearm_attachment"] as BoneAttachment3D).bone_name == &"pelvis", "sidearm holster follows the pelvis")
	_check((parts["helmet_attachment"] as BoneAttachment3D).find_children("*", "MeshInstance3D", true, false).size() >= 9, "helmet has layered shell visor jaw and comms geometry")
	_check((parts["sidearm_attachment"] as BoneAttachment3D).find_children("*", "MeshInstance3D", true, false).size() == 6, "sidearm has holster receiver slide muzzle grip and sight")

	var cape_hidden := false
	var hair_absent := true
	var red_suit := false
	for value in rig["mesh_instances"]:
		var mesh := value as MeshInstance3D
		if mesh.name == &"GV2_Cape":
			cape_hidden = not mesh.visible
		if mesh.name == &"ShortBlackHair":
			hair_absent = false
		for surface in mesh.mesh.get_surface_count():
			if String(mesh.mesh.surface_get_name(surface)) == "MAT_GV2_Suit_Cloth":
				var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
				red_suit = material != null and material.albedo_color.r > material.albedo_color.g * 2.5
	_check(cape_hidden, "player cape is removed from the corporate silhouette")
	_check(hair_absent, "player hairstyle is removed beneath the enclosed helmet")
	_check(red_suit, "textured suit material is visibly red dominant")

	var states := [&"grounded", &"attack", &"stagger", &"takedown_victim", &"defeated"]
	for state: StringName in states:
		for frame in 20:
			Builder.pose_guard(parts, frame * 0.18, 1.0 if state == &"grounded" else 0.0, 1.0 / 60.0, state, float(frame) / 19.0)
		var finite := true
		for bone in skeleton.get_bone_count():
			finite = finite and skeleton.get_bone_global_pose(bone).is_finite()
		_check(finite, "%s pose keeps all 74 joints finite" % state)

	print("CORPORATE_GUARD_CONTRACT_", "OK" if failures.is_empty() else "FAILED", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
