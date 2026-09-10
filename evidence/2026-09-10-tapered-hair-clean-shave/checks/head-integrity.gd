extends SceneTree
const Candidate = preload("res://work/character-art-review/candidate_fixture.gd")
var errors := 0
var verified := 0
func _initialize():
 call_deferred("run")
func run():
 var original = load(Candidate.ASSET_PATH).instantiate()
 root.add_child(original)
 var old: ArrayMesh
 for node in original.find_children("*", "MeshInstance3D", true, false):
  if node.mesh.get_blend_shape_count()>0: old=node.mesh
 var actor=Node3D.new()
 root.add_child(actor)
 var parts=Candidate.build_player(actor,Color.WHITE)
 var current: ArrayMesh=parts.authored_rig.face_mesh.mesh
 check(current.blend_shape_mode==old.blend_shape_mode,"expression mode")
 check(current.get_blend_shape_count()==old.get_blend_shape_count(),"expression count")
 var lod_count=0
 for surface in old.get_surface_count():
  var before=old.surface_get_arrays(surface)
  var after=current.surface_get_arrays(surface)
  var lookup={}
  for i in before[0].size():
   var p: Vector3=before[0][i]
   if not lookup.has(p): lookup[p]=[]
   lookup[p].append(i)
  var before_shapes=old.surface_get_blend_shape_arrays(surface)
  var after_shapes=current.surface_get_blend_shape_arrays(surface)
  for i in after[0].size():
   var source_index=-1
   for j in lookup.get(after[0][i],[]):
    if channels_match(before,after,j,i): source_index=j;break
   check(source_index>=0,"anatomical channels unchanged")
   if source_index<0: continue
   for shape in before_shapes.size():
    check(channels_match(before_shapes[shape],after_shapes[shape],source_index,i),"expression channels unchanged")
   verified+=1
  var old_surface=RenderingServer.mesh_get_surface(old.get_rid(),surface)
  var new_surface=RenderingServer.mesh_get_surface(current.get_rid(),surface)
  check(old_surface.get("lods",[]).size()==new_surface.get("lods",[]).size(),"LOD levels retained")
  for lod in new_surface.get("lods",[]):
   var matching=[]
   for previous in old_surface.lods:
    if previous.edge_length==lod.edge_length: matching.append(previous)
   check(matching.size()==1,"LOD threshold retained")
   if matching.size()!=1: continue
   var old_triangles=triangles(old_surface,matching[0].index_data,before[0])
   var new_triangles=triangles(new_surface,lod.index_data,after[0])
   for tri in new_triangles: check(old_triangles.has(tri),"LOD anatomical triangle unchanged")
   lod_count+=1
 print("HEAD_INTEGRITY ","OK" if errors==0 else "FAILED"," vertices=",verified," morphs=",current.get_blend_shape_count()," face_lods=",lod_count," errors=",errors)
 Candidate.clear_material_overrides(parts)
 quit(0 if errors==0 else 1)
func channels_match(a:Array,b:Array,old_i:int,new_i:int)->bool:
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
  if a[channel]==null or a[channel].is_empty():
   if b[channel]!=null and not b[channel].is_empty(): return false
   continue
  var stride:int=a[channel].size()/a[0].size()
  for j in stride:
   var x=a[channel][old_i*stride+j];var y=b[channel][new_i*stride+j]
   if typeof(x) in [TYPE_VECTOR2,TYPE_VECTOR3]:
    if x.distance_to(y)>0.0002: return false
   elif abs(x-y)>0.0002: return false
 return true
func triangles(surface:Dictionary,bytes:PackedByteArray,vertices:PackedVector3Array)->Dictionary:
 var result={}
 var stride:int=surface.index_data.size()/surface.index_count
 for i in range(0,bytes.size(),stride*3):
  var key=[]
  for j in 3:
   var k=i+j*stride
   key.append(vertices[bytes.decode_u16(k) if stride==2 else bytes.decode_u32(k)])
  result[key]=true
 return result
func check(value:bool,label:String):
 if not value:
  errors+=1
  if errors<8: print("FAIL ",label)
