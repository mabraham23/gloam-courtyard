"""Generate a review candidate from credited CC0 anatomy + original costume.

The game's v1 and every rejected v2/v3 source stay untouched. This generator
does not decide visual/runtime acceptance or alter the default scene.
"""
from pathlib import Path
import sys
import json
import hashlib
import bpy

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/"v2"));sys.path.insert(0,str(HERE))
import generate_gloam_vigil_v2 as scaffold
from body_from_base import load_anatomy,heroic_proportions
from costume import split_anatomy,set_body_materials,build_details,build_cape


def export_candidate(marker,meshes,rig):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [marker,rig,*meshes]:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    scaffold.SOURCE_DIR.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(scaffold.BLEND_PATH))
    # Blender's MATERIAL inference misses the Skin texture-times-Col node
    # chain. Explicit named COLOR_0 preserves the actual scalp/lip treatment
    # in Godot; non-tinted costume surfaces carry white Col, not dark gear Col.
    bpy.ops.export_scene.gltf(filepath=str(scaffold.GLB_PATH),check_existing=False,
        export_format="GLB",use_selection=True,export_yup=True,export_apply=True,
        export_texcoords=True,export_normals=True,export_tangents=True,
        export_animations=False,export_skins=True,export_influence_nb=4,
        export_all_influences=False,export_def_bones=True,
        export_rest_position_armature=True,export_armature_object_remove=False,
        export_leaf_bone=False,export_morph=True,export_morph_normal=True,
        export_morph_tangent=False,export_materials="EXPORT",export_image_format="AUTO",
        export_vertex_color="NAME",export_vertex_color_name="Col",
        export_extras=True,export_cameras=False,export_lights=False,
        export_draco_mesh_compression_enable=False,export_meshopt_compression_enable=False)


def main():
    from face_finish import finish_face
    from rig_from_base import create_rig,assign_body_weights
    scaffold.reset_scene()
    textures=HERE/"textures";textures.mkdir(parents=True,exist_ok=True)
    scaffold.TEXTURE_DIR=textures;scaffold.SOURCE_DIR=HERE/"source"
    scaffold.BLEND_PATH=scaffold.SOURCE_DIR/"gloam_vigil_player_v4.blend"
    scaffold.GLB_PATH=HERE/"gloam_vigil_player_v4.glb"
    texture_sets=scaffold.generate_textures()
    # R8 appearance pass: a light, warm complexion that remains readable in
    # the courtyard's cool night lighting. The generic CC0 anatomy and its UVs
    # are unchanged; this only replaces the procedural skin albedo/roughness.
    texture_sets["MAT_GV2_Skin"]=scaffold.generate_texture_set("gv4_skin_warm",2048,(190,139,112),"skin")
    texture_sets["MAT_GV2_Suit_Cloth"]=scaffold.generate_texture_set("gv4_suit",2048,(15,19,26),"cloth")
    materials={name:scaffold.make_material(name,paths) for name,paths in texture_sets.items()}
    originals=heroic_proportions(load_anatomy(1))
    body,head=split_anatomy(originals[0])
    set_body_materials(body,materials)
    face,face_metadata=finish_face(head,originals[1:],materials)
    marker=bpy.data.objects.new("GloamVigilV4Asset",None);bpy.context.collection.objects.link(marker)
    marker["gloam_rig_contract"]="gloam-vigil-v2-rig-1"
    marker["source_author"]="Dan Ulrich / Blender Human Base Meshes v1.4.1"
    marker["source_license"]="CC0"
    marker["original_design"]="Gloam Vigil fitted costume, mask, cape and rig adaptation"
    rig=create_rig(marker,body,face_metadata)
    weight_metadata=assign_body_weights(body,rig)
    details=build_details(body,face,rig,materials)
    # Preserve the source anatomical UVs; new separate costume pieces have
    # their own packed UVs and reuse the same five material identities.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True);details.select_set(True);bpy.context.view_layer.objects.active=body
    bpy.ops.object.join()
    from mesh_tools import triangulate
    triangulate(body)
    cape=build_cape(materials,body)
    meshes=[body,face,cape]
    for obj in meshes:
        scaffold.attach_to_rig(obj,rig)
        # Match the exported Godot linear-blend skinning in Blender previews;
        # preserve-volume dual-quaternion deformation is not exported by glTF.
        for modifier in obj.modifiers:
            if modifier.type=="ARMATURE":modifier.use_deform_preserve_volume=False
        obj["gloam_asset_id"]="gloam_vigil_v4"
        obj["gloam_asset_version"]=4
    # Stable skeleton names remain necessary, even for structural root links.
    for bone in rig.data.bones:bone.use_deform=True
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                from mathutils import Quaternion
                space=area.spaces.active;space.overlay.show_overlays=False;space.shading.type="MATERIAL"
                space.region_3d.view_location=(0,0,1.08);space.region_3d.view_distance=3.1
                space.region_3d.view_rotation=Quaternion((.811,.568,.084,.123)).normalized()
    export_candidate(marker,meshes,rig)
    bpy.ops.object.select_all(action="DESELECT");body.select_set(True);bpy.context.view_layer.objects.active=body
    rig.hide_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(scaffold.BLEND_PATH))
    metrics={"asset_id":"gloam_vigil_v4","status":"candidate-not-yet-accepted","source_collection":"Body Male - Realistic","source_author":"Dan Ulrich","source_license":"CC0","source_bundle":"1.4.1","source_multires_level":1,"bones":len(rig.data.bones),"vertices":sum(len(o.data.vertices) for o in meshes),"triangles":sum(len(o.data.polygons) for o in meshes),"surface_slots":sum(len(o.data.materials) for o in meshes),"unique_materials":len({m.name for o in meshes for m in o.data.materials}),"glb_sha256":hashlib.sha256(scaffold.GLB_PATH.read_bytes()).hexdigest(),"face":face_metadata,"body_weights":weight_metadata}
    (HERE/"manifest.json").write_text(json.dumps(metrics,indent=2,default=str)+"\n")
    print("GV4_GENERATED "+json.dumps(metrics,default=str))


if __name__=="__main__":main()
