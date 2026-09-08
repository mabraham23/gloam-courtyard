"""Read-only inventory of the official bundle; never executes embedded scripts."""
from pathlib import Path
import json
import bpy

HERE=Path(__file__).resolve().parent
source=HERE/"reference/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend"
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
for collection in bpy.data.collections:
    if collection.asset_data and collection.name in {"Body Male - Realistic","Head (Animation) - Realistic","Head (Sculpting) - Realistic"}:
        metadata=collection.asset_data
        print("BASE_COLLECTION "+json.dumps({"name":collection.name,"objects":[o.name for o in collection.all_objects],"author":metadata.author,"license":metadata.license,"copyright":metadata.copyright,"description":metadata.description}))
for obj in bpy.data.objects:
    if obj.type=="MESH" and any(k in obj.name for k in ("body_male_realistic","head_animation_realistic","head_sculpting_realistic")):
        print("BASE_MESH "+json.dumps({"name":obj.name,"vertices":len(obj.data.vertices),"faces":len(obj.data.polygons),"bounds":[list(p) for p in obj.bound_box],"location":list(obj.location),"scale":list(obj.scale),"rotation":list(obj.rotation_euler),"modifiers":[(m.name,m.type,getattr(m,"levels",None),getattr(m,"total_levels",None)) for m in obj.modifiers],"groups":[g.name for g in obj.vertex_groups],"uv":[u.name for u in obj.data.uv_layers],"author":obj.asset_data.author if obj.asset_data else None,"license":obj.asset_data.license if obj.asset_data else None}))
for text in bpy.data.texts:
    print("BASE_TEXT "+text.name+"\n"+text.as_string()[:10000])
