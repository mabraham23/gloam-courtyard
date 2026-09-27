extends RefCounted

## Candidate-only corporate sentry presentation. It reuses the exact R14
## anatomical/rig base while giving the enemy an original helmeted security
## silhouette. Gameplay, collision, damage and timing remain in main_3d.gd.

const Builder = preload("res://actors/character_visual_builder.gd")
const ASSET_PATH := "res://actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"

const SUIT_RED := Color(1.34, 0.31, 0.36, 1.0)
const ARMOR_RED := Color("#9d2536")
const ARMOR_RED_DARK := Color("#551622")
const CHARCOAL := Color("#171c26")
const GUNMETAL := Color("#2c3440")
const VISOR := Color("#090d14")
const SIGNAL := Color("#ff4b5f")


static func build(parent: Node3D) -> Dictionary:
	var parts := Builder.build_player(parent, SIGNAL, true, ASSET_PATH)
	var visual_root := parts["visual_root"] as Node3D
	visual_root.name = "CrimsonCorporateSentryVisual"
	var rig := parts["authored_rig"] as Dictionary
	var skeleton := rig["skeleton"] as Skeleton3D

	_remove_player_only_silhouette(rig)
	_apply_security_materials(rig)
	var helmet := _build_helmet(skeleton)
	var sidearm := _build_sidearm(skeleton)

	parts["corporate_sentry"] = true
	parts["helmet_attachment"] = helmet
	parts["sidearm_attachment"] = sidearm
	return parts


static func is_exact(parts: Dictionary) -> bool:
	var rig := parts.get("authored_rig", {}) as Dictionary
	var skeleton := rig.get("skeleton") as Skeleton3D
	var helmet := parts.get("helmet_attachment") as BoneAttachment3D
	var sidearm := parts.get("sidearm_attachment") as BoneAttachment3D
	return (
		bool(parts.get("corporate_sentry", false))
		and skeleton != null
		and skeleton.get_bone_count() == 74
		and _source_path(parts) == ASSET_PATH
		and helmet != null
		and helmet.bone_name == &"head"
		and sidearm != null
		and sidearm.bone_name == &"pelvis"
	)


static func _source_path(parts: Dictionary) -> String:
	var rig := parts.get("authored_rig", {}) as Dictionary
	var imported_root := rig.get("imported_root") as Node
	return imported_root.scene_file_path if imported_root != null else ""


static func _remove_player_only_silhouette(rig: Dictionary) -> void:
	var retained: Array[MeshInstance3D] = []
	for value in rig.get("mesh_instances", []):
		var mesh := value as MeshInstance3D
		if mesh == null:
			continue
		if mesh.name == &"ShortBlackHair":
			mesh.free()
			continue
		if mesh.name == &"GV2_Cape":
			mesh.visible = false
		retained.append(mesh)
	rig["mesh_instances"] = retained


static func _apply_security_materials(rig: Dictionary) -> void:
	var configured: Dictionary = {}
	for value in rig.get("mesh_instances", []):
		var mesh := value as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material == null or configured.has(material.get_instance_id()):
				continue
			configured[material.get_instance_id()] = true
			var material_name := String(mesh.mesh.surface_get_name(surface))
			if material_name.is_empty():
				material_name = material.resource_name
			match material_name:
				"MAT_GV2_Suit_Cloth":
					# The source albedo is nearly black, so a tint alone disappears
					# under courtyard light. Retain its authored normal/roughness maps
					# but give the sentry a clear solid crimson uniform response.
					material.albedo_texture = null
					material.albedo_color = Color("#8f2636")
					material.roughness = 0.58
				"MAT_GV2_Gear":
					material.albedo_color = Color(0.30, 0.32, 0.37, 1.0)
					material.metallic = 0.26
					material.roughness = 0.46
				"MAT_GV2_Accent":
					material.albedo_color = SIGNAL
					material.emission_enabled = true
					material.emission = SIGNAL
					material.emission_energy_multiplier = 0.42
				"MAT_GV2_Tactical_Boot":
					material.albedo_color = Color(0.22, 0.23, 0.26, 1.0)
					material.metallic = 0.12
					material.roughness = 0.62


static func _build_helmet(skeleton: Skeleton3D) -> BoneAttachment3D:
	var attachment := _bone_attachment(skeleton, &"head", "CorporateHelmetAttachment")
	var red := _material(ARMOR_RED, 0.42, 0.34)
	var dark_red := _material(ARMOR_RED_DARK, 0.50, 0.24)
	var charcoal := _material(CHARCOAL, 0.34, 0.58)
	var visor := _material(VISOR, 0.18, 0.72)
	var signal_material := _material(SIGNAL, 0.28, 0.20, SIGNAL, 1.7)

	# A close shell, segmented jaw and uninterrupted visor read as industrial
	# protection rather than a hood, mask or franchise cowl.
	_sphere(attachment, "HelmetShell", Vector3(0.0, 0.115, -0.012), 0.205, Vector3(1.06, 1.02, 1.08), red)
	_box(attachment, "HelmetRearPlate", Vector3(0.0, 0.055, -0.175), Vector3(0.31, 0.25, 0.085), dark_red)
	_box(attachment, "HelmetVisor", Vector3(0.0, 0.105, 0.178), Vector3(0.345, 0.105, 0.070), visor)
	_box(attachment, "HelmetVisorGlow", Vector3(0.0, 0.102, 0.216), Vector3(0.275, 0.026, 0.018), signal_material)
	_box(attachment, "HelmetJaw", Vector3(0.0, -0.055, 0.142), Vector3(0.29, 0.145, 0.105), charcoal)
	_box(attachment, "HelmetCrownRail", Vector3(0.0, 0.286, -0.010), Vector3(0.065, 0.055, 0.31), dark_red)
	_box(attachment, "HelmetDivisionStripe", Vector3(0.0, 0.306, 0.040), Vector3(0.024, 0.012, 0.23), signal_material)
	for side in [-1.0, 1.0]:
		var ear := _cylinder(attachment, "HelmetComms", Vector3(side * 0.215, 0.055, -0.010), 0.055, 0.055, charcoal)
		ear.rotation.z = PI * 0.5
	return attachment


static func _build_sidearm(skeleton: Skeleton3D) -> BoneAttachment3D:
	var attachment := _bone_attachment(skeleton, &"pelvis", "CorporateSidearmHolsterAttachment")
	# Keep the weapon visibly issued but holstered. The existing enemy remains a
	# close-range archetype; ranged damage would be a separate gameplay decision.
	# BoneAttachment3D owns its transform each frame, so the authored offset
	# lives on a child alignment node instead of being overwritten at the pelvis.
	var alignment := Node3D.new()
	alignment.name = "RightThighHolsterAlignment"
	alignment.position = Vector3(-0.31, -0.18, 0.10)
	alignment.rotation = Vector3(0.0, 0.0, 0.04)
	attachment.add_child(alignment)
	var gunmetal := _material(GUNMETAL, 0.30, 0.74)
	var grip := _material(CHARCOAL, 0.72, 0.10)
	var red := _material(ARMOR_RED_DARK, 0.48, 0.30)
	var signal_material := _material(SIGNAL, 0.25, 0.15, SIGNAL, 1.4)

	_box(alignment, "SidearmHolster", Vector3(0.0, -0.115, -0.018), Vector3(0.16, 0.38, 0.105), grip)
	_box(alignment, "SidearmReceiver", Vector3(0.0, -0.115, 0.055), Vector3(0.105, 0.29, 0.105), gunmetal)
	_box(alignment, "SidearmSlide", Vector3(0.0, -0.105, 0.116), Vector3(0.090, 0.25, 0.046), red)
	_box(alignment, "SidearmMuzzle", Vector3(0.0, -0.270, 0.070), Vector3(0.092, 0.050, 0.090), grip)
	var handle := _box(alignment, "SidearmGrip", Vector3(0.035, 0.045, 0.045), Vector3(0.105, 0.20, 0.105), grip)
	handle.rotation.z = -0.43
	_box(alignment, "SidearmSight", Vector3(0.0, 0.015, 0.145), Vector3(0.026, 0.050, 0.022), signal_material)
	return attachment


static func _bone_attachment(skeleton: Skeleton3D, bone: StringName, node_name: String) -> BoneAttachment3D:
	assert(skeleton.find_bone(bone) >= 0, "Corporate sentry needs bone %s" % bone)
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment


static func _material(color: Color, roughness: float, metallic := 0.0, emission := Color.TRANSPARENT, emission_energy := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


static func _sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, scale: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var instance := _mesh(parent, node_name, position, mesh, material)
	instance.scale = scale
	return instance


static func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, position, mesh, material)


static func _cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _mesh(parent, node_name, position, mesh, material)


static func _mesh(parent: Node3D, node_name: String, position: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
