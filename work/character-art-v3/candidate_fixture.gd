extends RefCounted

## Test-only explicit selection for the non-default Gloam Vigil v3 candidate.
## Nothing in the default scene loads this helper.

const Builder = preload("res://actors/character_visual_builder.gd")
const ASSET_PATH := "res://actors/gloam_vigil/v3/gloam_vigil_player_v3.glb"


static func build_player(parent: Node3D, accent: Color) -> Dictionary:
	return Builder.build_player(parent, accent, true, ASSET_PATH)


static func source_path(parts: Dictionary) -> String:
	var rig := parts.get("authored_rig", {}) as Dictionary
	var imported_root := rig.get("imported_root") as Node
	if imported_root != null and not imported_root.scene_file_path.is_empty():
		return imported_root.scene_file_path
	return String(rig.get("asset_path", ""))


static func is_exact_candidate(parts: Dictionary) -> bool:
	var rig := parts.get("authored_rig", {}) as Dictionary
	var skeleton := rig.get("skeleton") as Skeleton3D
	return (
		source_path(parts) == ASSET_PATH
		and bool(rig.get("is_v2", false))
		and skeleton != null
		and skeleton.get_bone_count() == 74
	)


static func clear_material_overrides(parts: Dictionary) -> void:
	var rig := parts.get("authored_rig", {}) as Dictionary
	for mesh_value in rig.get("mesh_instances", []):
		var mesh := mesh_value as MeshInstance3D
		if mesh == null:
			continue
		mesh.material_override = null
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, null)

