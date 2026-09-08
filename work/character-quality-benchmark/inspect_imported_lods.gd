extends SceneTree

## Read-only audit of the mesh surfaces Godot actually imported from a GLB.
## This reports generated LOD index buffers from the live RenderingServer mesh
## RID; it does not infer LOD generation from the .import checkbox.

const DEFAULT_ASSET := "res://actors/gloam_vigil/gloam_vigil_player.glb"

var asset_path := DEFAULT_ASSET
var label := "unlabelled"
var errors: Array[String] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--asset="):
			asset_path = argument.trim_prefix("--asset=")
		elif argument.begins_with("--label="):
			label = argument.trim_prefix("--label=")
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(asset_path):
		_fail("resource does not exist: " + asset_path)
		_finish()
		return
	var resource := load(asset_path)
	if not resource is PackedScene:
		_fail("resource is not a PackedScene: " + asset_path)
		_finish()
		return
	var scene := (resource as PackedScene).instantiate()
	root.add_child(scene)
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(scene, mesh_instances)
	if mesh_instances.is_empty():
		_fail("imported scene has no MeshInstance3D nodes")

	var mesh_rows: Array[Dictionary] = []
	var total_surfaces := 0
	var total_lod_index_buffers := 0
	for instance in mesh_instances:
		var mesh := instance.mesh
		if mesh == null:
			_fail("mesh instance has no mesh: " + str(instance.get_path()))
			continue
		var blend_shape_names: Array[String] = []
		for blend_index in mesh.get_blend_shape_count():
			blend_shape_names.append(str(mesh.get_blend_shape_name(blend_index)))
		var blend_shape_mode := (mesh as ArrayMesh).blend_shape_mode if mesh is ArrayMesh else Mesh.BLEND_SHAPE_MODE_NORMALIZED
		var surface_rows: Array[Dictionary] = []
		for surface_index in mesh.get_surface_count():
			total_surfaces += 1
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var base_indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var primitive: Mesh.PrimitiveType = mesh.surface_get_primitive_type(surface_index)
			var base_index_count := base_indices.size()
			var base_element_count := base_index_count if base_index_count > 0 else vertices.size()
			if primitive == Mesh.PRIMITIVE_TRIANGLES and base_element_count % 3 != 0:
				_fail("triangle surface base element count is not divisible by 3: %s surface %d" % [instance.name, surface_index])

			# ArrayMesh does not expose public surface_get_lods() in this Godot
			# build. Query the actual RenderingServer mesh RID; mesh_get_surface()
			# returns the live imported surface and its raw LOD index buffers.
			var runtime_surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface_index)
			var runtime_base_index_data := runtime_surface.get("index_data", PackedByteArray()) as PackedByteArray
			var runtime_base_index_count := int(runtime_surface.get("index_count", 0))
			if runtime_base_index_count != base_index_count:
				_fail("ArrayMesh and RenderingServer base index counts differ: %s surface %d" % [instance.name, surface_index])
			var index_stride := 0
			if runtime_base_index_count > 0:
				if runtime_base_index_data.size() % runtime_base_index_count != 0:
					_fail("RenderingServer base index byte length is not divisible by index count: %s surface %d" % [instance.name, surface_index])
				else:
					index_stride = runtime_base_index_data.size() / runtime_base_index_count
					if index_stride not in [2, 4]:
						_fail("unsupported runtime index stride %d: %s surface %d" % [index_stride, instance.name, surface_index])

			var lod_rows: Array[Dictionary] = []
			var lods := runtime_surface.get("lods", []) as Array
			var previous_threshold := -INF
			for lod_index in lods.size():
				var lod: Dictionary = lods[lod_index]
				var threshold := float(lod.get("edge_length", NAN))
				var lod_index_data := lod.get("index_data", PackedByteArray()) as PackedByteArray
				total_lod_index_buffers += 1
				if not is_finite(threshold) or threshold <= 0.0 or threshold <= previous_threshold:
					_fail("invalid/non-increasing LOD threshold on %s surface %d" % [instance.name, surface_index])
				previous_threshold = threshold
				if index_stride <= 0 or lod_index_data.size() % index_stride != 0:
					_fail("LOD index byte length is invalid: %s surface %d LOD %d" % [instance.name, surface_index, lod_index])
					continue
				var lod_index_count := lod_index_data.size() / index_stride
				if primitive == Mesh.PRIMITIVE_TRIANGLES and lod_index_count % 3 != 0:
					_fail("LOD triangle index count is not divisible by 3: %s surface %d" % [instance.name, surface_index])
				var min_index := -1
				var max_index := -1
				var unique_indices: Dictionary = {}
				for index_offset in range(0, lod_index_data.size(), index_stride):
					var vertex_index := (lod_index_data.decode_u16(index_offset)
						if index_stride == 2 else lod_index_data.decode_u32(index_offset))
					if vertex_index < 0 or vertex_index >= vertices.size():
						_fail("LOD index out of vertex range: %s surface %d" % [instance.name, surface_index])
					min_index = vertex_index if min_index < 0 else mini(min_index, vertex_index)
					max_index = maxi(max_index, vertex_index)
					unique_indices[vertex_index] = true
				lod_rows.append({
					"lod": lod_index,
					"edge_length_threshold": threshold,
					"index_count": lod_index_count,
					"triangle_count": lod_index_count / 3 if primitive == Mesh.PRIMITIVE_TRIANGLES else null,
					"index_reduction_fraction_vs_base": 1.0 - float(lod_index_count) / maxf(float(base_element_count), 1.0),
					"unique_vertex_indices": unique_indices.size(),
					"min_index": min_index,
					"max_index": max_index,
				})

			var blend_shape_rows: Array[Dictionary] = []
			var surface_blend_shapes := mesh.surface_get_blend_shape_arrays(surface_index)
			if not surface_blend_shapes.is_empty() and surface_blend_shapes.size() != blend_shape_names.size():
				_fail("surface blend-shape array count differs from mesh blend-shape count: %s surface %d" % [instance.name, surface_index])
			for blend_index in surface_blend_shapes.size():
				var blend_arrays: Array = surface_blend_shapes[blend_index]
				var position_deltas := blend_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				if position_deltas.size() != vertices.size():
					_fail("blend-shape position count differs from base vertex count: %s surface %d blend %d" % [instance.name, surface_index, blend_index])
				var nonzero_positions := 0
				var max_position_delta := 0.0
				for position_index in position_deltas.size():
					var delta := position_deltas[position_index]
					# Godot returns absolute target positions for NORMALIZED mode and
					# relative deltas for RELATIVE mode. Normalize both to a delta.
					if blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
						delta -= vertices[position_index]
					var magnitude := delta.length()
					if magnitude > 0.00000001:
						nonzero_positions += 1
					max_position_delta = maxf(max_position_delta, magnitude)
				blend_shape_rows.append({
					"name": blend_shape_names[blend_index] if blend_index < blend_shape_names.size() else "blend_%d" % blend_index,
					"position_delta_count": position_deltas.size(),
					"nonzero_position_deltas": nonzero_positions,
					"max_position_delta_length": max_position_delta,
				})

			surface_rows.append({
				"surface": surface_index,
				"primitive": _primitive_name(primitive),
				"vertices": vertices.size(),
				"base_index_count": base_index_count,
				"runtime_index_stride_bytes": index_stride,
				"base_triangle_count": base_element_count / 3 if primitive == Mesh.PRIMITIVE_TRIANGLES else null,
				"material": _material_name(mesh.surface_get_material(surface_index)),
				"lod_index_buffers": lod_rows,
				"blend_shapes": blend_shape_rows,
				"morph_lod_limitation": (
					"Generated LODs reuse the surface vertex/blend-shape buffers and only replace triangle indices; there are no separately simplified morph-delta buffers per LOD."
					if not blend_shape_rows.is_empty() and not lod_rows.is_empty()
					else "No morph-bearing generated LOD on this surface."
				),
			})
		mesh_rows.append({
			"node_path": str(instance.get_path()),
			"mesh_resource_path": mesh.resource_path,
			"mesh_class": mesh.get_class(),
			"blend_shape_mode": "normalized_absolute_targets" if blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else "relative_deltas",
			"blend_shape_count": mesh.get_blend_shape_count(),
			"blend_shape_names": blend_shape_names,
			"surfaces": surface_rows,
		})

	var report := {
		"label": label,
		"asset_path": asset_path,
		"asset_sha256": FileAccess.get_sha256(asset_path),
		"mesh_instances": mesh_rows.size(),
		"total_surfaces": total_surfaces,
		"total_generated_lod_index_buffers": total_lod_index_buffers,
		"threshold_semantics": "Raw RenderingServer surface LOD edge_length thresholds reported by Godot. They are not camera distances; effective switches also depend on projection, viewport, mesh scale, and LOD bias.",
		"meshes": mesh_rows,
		"errors": errors,
	}
	print("GLOAM_LOD_REPORT ", JSON.stringify(report))
	_finish()


func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, result)


func _material_name(material: Material) -> String:
	if material == null:
		return "<none>"
	if not material.resource_name.is_empty():
		return material.resource_name
	return material.resource_path


func _primitive_name(primitive: Mesh.PrimitiveType) -> String:
	match primitive:
		Mesh.PRIMITIVE_POINTS:
			return "points"
		Mesh.PRIMITIVE_LINES:
			return "lines"
		Mesh.PRIMITIVE_LINE_STRIP:
			return "line_strip"
		Mesh.PRIMITIVE_TRIANGLES:
			return "triangles"
		Mesh.PRIMITIVE_TRIANGLE_STRIP:
			return "triangle_strip"
	return "unknown_%d" % primitive


func _fail(message: String) -> void:
	errors.append(message)
	push_error("GLOAM_LOD_FAIL " + message)


func _finish() -> void:
	if errors.is_empty():
		print("GLOAM_LOD_PROBE_OK")
		quit(0)
	else:
		print("GLOAM_LOD_PROBE_FAIL errors=", errors.size())
		quit(1)
