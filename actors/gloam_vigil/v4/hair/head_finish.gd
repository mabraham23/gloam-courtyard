extends RefCounted

## Private runtime derivative: remove the old shell and facial-hair color field.
## Compact every vertex channel, expression target and LOD with the same map.
static func apply(face: MeshInstance3D) -> void:
	var source := face.mesh as ArrayMesh
	var result := ArrayMesh.new()
	result.blend_shape_mode = source.blend_shape_mode
	for i in source.get_blend_shape_count(): result.add_blend_shape(source.get_blend_shape_name(i))
	var overrides: Array[Material] = []
	var removed := 0
	var shaved := 0
	for surface in source.get_surface_count():
		overrides.append(face.get_surface_override_material(surface))
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var skin := source.surface_get_material(surface).resource_name == "MAT_GV2_Skin"
		var keep: Array[int] = []
		var remap := PackedInt32Array()
		remap.resize(vertices.size())
		remap.fill(-1)
		for i in vertices.size():
			var c := colors[i]
			# The shell has an exact near-black tag. Even the darkest mustache
			# sample is lighter; lips are warm (R > G), facial hair is cool.
			if skin and c.r < 0.004 and c.g < 0.005 and c.b < 0.007:
				removed += 1
				continue
			if skin and c.r < 0.999 and c.r <= c.g and c.g <= c.b:
				colors[i] = Color.WHITE
				shaved += 1
			remap[i] = keep.size()
			keep.append(i)
		arrays[Mesh.ARRAY_COLOR] = colors
		var compact := _compact(arrays, keep, remap, vertices.size())
		var shapes: Array[Array] = []
		for shape in source.surface_get_blend_shape_arrays(surface):
			shapes.append(_compact(shape, keep, remap, vertices.size()))
		var raw := RenderingServer.mesh_get_surface(source.get_rid(), surface)
		var stride: int = raw.index_data.size() / raw.index_count
		var lods := {}
		for lod in raw.get("lods", []):
			var bytes: PackedByteArray = lod.index_data
			var indices := PackedInt32Array()
			for offset in range(0, bytes.size(), stride):
				indices.append(bytes.decode_u16(offset) if stride == 2 else bytes.decode_u32(offset))
			var mapped := _indices(indices, remap)
			if not mapped.is_empty(): lods[lod.edge_length] = mapped
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), compact, shapes, lods,
			source.surface_get_format(surface) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		result.surface_set_name(surface, source.surface_get_name(surface))
		result.surface_set_material(surface, source.surface_get_material(surface))
	assert(removed > 500 and shaved > 250, "R14 shell and facial-hair regions must both be found")
	face.mesh = result
	for surface in overrides.size(): face.set_surface_override_material(surface, overrides[surface])
	face.set_meta("removed_hair_vertices", removed)
	face.set_meta("shaved_vertices", shaved)


static func _compact(arrays: Array, keep: Array[int], remap: PackedInt32Array, count: int) -> Array:
	var result := arrays.duplicate()
	for channel in Mesh.ARRAY_MAX:
		if arrays[channel] == null: continue
		if channel == Mesh.ARRAY_INDEX:
			result[channel] = _indices(arrays[channel], remap)
			continue
		var source = arrays[channel]
		if source.is_empty(): continue
		assert(source.size() % count == 0, "Vertex channel stride must remain whole")
		var stride: int = source.size() / count
		var target = source.duplicate()
		target.resize(keep.size() * stride)
		for i in keep.size():
			for offset in stride: target[i * stride + offset] = source[keep[i] * stride + offset]
		result[channel] = target
	return result


static func _indices(source: PackedInt32Array, remap: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in range(0, source.size(), 3):
		var a := remap[source[i]]
		var b := remap[source[i + 1]]
		var c := remap[source[i + 2]]
		if mini(a, mini(b, c)) < 0:
			assert(maxi(a, maxi(b, c)) < 0, "Hair shell must remain separate from the anatomical face")
			continue
		result.append_array(PackedInt32Array([a, b, c]))
	return result
