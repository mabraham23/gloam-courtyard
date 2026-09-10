extends RefCounted

## Small original hair detail layer on the unchanged R14 scalp. Uses the same
## head skin bind as the face, so motion and full-mesh checks share one skeleton.
const GEOMETRY := "res://actors/gloam_vigil/v4/hair/short_black_hair.json"

static func attach(face: MeshInstance3D) -> MeshInstance3D:
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
	var instance := MeshInstance3D.new()
	instance.name = "ShortBlackHair"
	instance.mesh = mesh
	instance.skin = face.skin
	instance.skeleton = face.skeleton
	instance.extra_cull_margin = 2.5
	face.get_parent().add_child(instance)
	return instance
