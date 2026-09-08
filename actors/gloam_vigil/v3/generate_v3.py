"""Build isolated original-anatomy candidate; never overwrite v1 or frozen v2.

Geometry is code-authored, not hand sculpted or downloaded. Stable 74-bone
source is reused by import, with new connected anatomy modules. Review output
is a candidate until actual Blender/Godot and full-pose checks pass.
"""
from pathlib import Path
import sys
import json
import hashlib
import bpy

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/"v2"))
sys.path.insert(0,str(HERE))
import generate_gloam_vigil_v2 as scaffold
from body_anatomy import build_body


def main():
    scaffold.reset_scene()
    # Redirect artifact paths on the imported module, not its preserved source.
    scaffold.TEXTURE_DIR=HERE/"textures"
    scaffold.SOURCE_DIR=HERE/"source"
    scaffold.BLEND_PATH=HERE/"source"/"gloam_vigil_player_v3.blend"
    scaffold.GLB_PATH=HERE/"gloam_vigil_player_v3.glb"
    scaffold.TEXTURE_DIR.mkdir(parents=True,exist_ok=True)
    scaffold.SOURCE_DIR.mkdir(parents=True,exist_ok=True)
    texture_sets=scaffold.generate_textures()
    texture_sets["MAT_GV2_Suit_Cloth"]=scaffold.generate_texture_set("gv3_suit",2048,(16,20,27),"cloth")
    materials={name:scaffold.make_material(name,textures) for name,textures in texture_sets.items()}
    for name,mat in materials.items():
        principled=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
        if "Skin" in name:
            principled.inputs["Subsurface Weight"].default_value=.045
        if "Gear" in name:
            principled.inputs["Roughness"].default_value=.48
    marker=bpy.data.objects.new("GloamVigilV3Asset",None); bpy.context.collection.objects.link(marker)
    marker["gloam_asset_id"]="gloam_vigil_v3"
    marker["gloam_rig_contract"]="gloam-vigil-v2-rig-1"
    marker["gloam_authoring"]="Original connected parameterized anatomy; no downloaded geometry"
    armature=scaffold.create_armature(marker)
    body=build_body(materials)
    if "--body-study" in sys.argv:
        face,_=scaffold.build_face(materials)
    else:
        from head_anatomy import build_face
        face,_=build_face(materials)
    cape=scaffold.build_cape(materials)
    meshes=[body,face,cape]
    for mesh in meshes:
        scaffold.attach_to_rig(mesh,armature)
        mesh["gloam_asset_id"]="gloam_vigil_v3"
    # Source opens in a useful clean inspection view, not selected armature
    # overlays or the default cube. Bone rest transforms are never changed.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True); bpy.context.view_layer.objects.active=body
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                area.spaces.active.overlay.show_overlays=False
                area.spaces.active.shading.type="MATERIAL"
                region=area.spaces.active.region_3d
                from mathutils import Quaternion
                region.view_location=(0,0,1.08)
                region.view_distance=3.1
                region.view_rotation=Quaternion((0.811,0.568,0.084,0.123)).normalized()
    # Export selections are restored by the shared exporter; hide bones from
    # viewport only (not render/export) after writing an inspection source.
    scaffold.export_asset(marker,meshes,armature)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True); bpy.context.view_layer.objects.active=body
    armature.hide_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(scaffold.BLEND_PATH))
    metrics={"asset_id":"gloam_vigil_v3","status":"candidate-unaccepted","rig_contract":"gloam-vigil-v2-rig-1","bones":len(armature.data.bones),"source_vertices":sum(len(m.data.vertices) for m in meshes),"source_triangles":sum(len(m.data.polygons) for m in meshes),"glb_sha256":hashlib.sha256(scaffold.GLB_PATH.read_bytes()).hexdigest(),"body_study_uses_rejected_head":"--body-study" in sys.argv}
    (HERE/"manifest.json").write_text(json.dumps(metrics,indent=2)+"\n")
    print("GV3_GENERATED "+json.dumps(metrics))


if __name__=="__main__":
    main()
