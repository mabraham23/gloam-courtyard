extends RefCounted

## Original fringe and tapered scalp on a private clean-shaven R14 derivative.
## The frozen GLB is retained; all replacement hair shares the face's head bind.
const GEOMETRY := "res://actors/gloam_vigil/v4/hair/short_black_hair.json"

static func attach(face: MeshInstance3D) -> MeshInstance3D:
	preload("res://actors/gloam_vigil/v4/hair/head_finish.gd").apply(face)
	# Wrap grazing light around exposed skin so the clean jaw does not fall
	# into the abrupt dark diffuse cutoff previously hidden by the beard.
	var face_material := face.get_active_material(0).duplicate() as StandardMaterial3D
	face_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	face.set_surface_override_material(0, face_material)
	var head_bind := -1
	for index in face.skin.get_bind_count():
		if face.skin.get_bind_name(index) == &"head": head_bind = index
	assert(head_bind >= 0, "Short hair needs the existing named head skin bind")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in data.triangles:
		# Godot's visible front winding is clockwise. Shared smooth groups keep
		# the fitted locks soft without rounding their tapered outline away.
		for corner in [0, 2, 1]:
			var p: Array = data.vertices[triangle[corner]]
			surface.set_bones(PackedInt32Array([head_bind, 0, 0, 0]))
			surface.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			surface.add_vertex(Vector3(p[0], p[1], p[2]))
	surface.generate_normals()
	surface.index()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.resource_name = "MAT_Short_Black_Hair"
	material.albedo_color = Color("#11141b")
	material.roughness = 0.88
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in data.scalp.triangles:
		for corner in [0, 2, 1]:
			var index: int = triangle[corner]
			var p: Array = data.scalp.vertices[index]
			var n: Array = data.scalp.normals[index]
			var uv: Array = data.scalp.uvs[index]
			var color: Array = data.scalp.colors[index]
			cap.set_bones(PackedInt32Array([head_bind, 0, 0, 0]))
			cap.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			cap.set_normal(Vector3(n[0], n[1], n[2]))
			cap.set_uv(Vector2(uv[0], uv[1]))
			cap.set_color(Color(color[0], color[1], color[2]))
			cap.add_vertex(Vector3(p[0], p[1], p[2]))
	cap.generate_normals()
	cap.index()
	cap.commit(mesh)
	var scalp_material := face.get_active_material(0).duplicate() as StandardMaterial3D
	scalp_material.resource_name = "MAT_Tapered_Scalp"
	scalp_material.normal_enabled = false
	scalp_material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	scalp_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(1, scalp_material)
	var instance := MeshInstance3D.new()
	instance.name = "ShortBlackHair"
	instance.mesh = mesh
	instance.skin = face.skin
	instance.skeleton = face.skeleton
	instance.extra_cull_margin = 2.5
	face.get_parent().add_child(instance)
	return instance
