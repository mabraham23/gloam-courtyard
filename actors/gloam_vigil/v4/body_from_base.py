"""Narrow licensed anatomy import and original character proportion study.

Dan Ulrich's CC0 Body Male - Realistic, official Blender bundle v1.4.1.
Only three named anatomical objects are appended. No rig, driver, animation,
text script, material or unrelated character is adopted into the game.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Matrix

HERE=Path(__file__).resolve().parent
SOURCE=HERE/"reference/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend"
OBJECTS=("GEO-body_male_realistic","GEO-body_male_realistic.eye.L","GEO-body_male_realistic.eye.R")


def load_anatomy(level=1):
    with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
        assert all(name in src.objects for name in OBJECTS)
        dst.objects=list(OBJECTS)
    loaded=list(dst.objects)
    center=next(o.location.x for o in loaded if o.name==OBJECTS[0])
    height=1.6844427585601807-(-.005640706513077021)
    scale=2.16/height
    for obj in loaded:
        bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.update()
    # Child eyes reference the donor body. Snapshot every world matrix before
    # centering its parent, otherwise the eye coordinates shift by that edit.
    source_world={obj:obj.matrix_world.copy() for obj in loaded}
    for obj in loaded:
        obj.animation_data_clear()
        for modifier in list(obj.modifiers):
            if modifier.type=="MULTIRES":
                modifier.levels=level; modifier.sculpt_levels=level; modifier.render_levels=level
            else:
                obj.modifiers.remove(modifier)
        bpy.context.view_layer.update()
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
        transform=Matrix.Scale(scale,4) @ Matrix.Translation((-center,0,.005640706513077021)) @ source_world[obj]
        mesh.transform(transform)
        obj.modifiers.clear(); obj.data=mesh; obj.parent=None; obj.matrix_world=Matrix.Identity(4)
        obj.data.materials.clear(); obj.vertex_groups.clear()
        if obj.data.shape_keys:
            obj.shape_key_clear()
        for poly in mesh.polygons:
            poly.use_smooth=True
        obj["source_collection"]="Body Male - Realistic"
        obj["source_author"]="Dan Ulrich"
        obj["source_license"]="CC0"
        obj["source_bundle"]="human-base-meshes-bundle-v1.4.1"
    return loaded


def g(v,c,w):
    return math.exp(-((v-c)/w)**2)


def heroic_proportions(objects):
    body=objects[0]
    # Shape edits are continuous spatial fields on anatomical topology. They
    # broaden existing muscle groups without manufacturing a conical torso.
    for vertex in body.data.vertices:
        x,y,z=vertex.co
        ax=abs(x)
        torso=math.exp(-(ax/.30)**8)
        chest=g(z,1.64,.15)*torso
        waist=g(z,1.30,.13)*torso
        x*=1.+.16*chest-.025*waist
        y*=1.+.19*chest+.055*g(z,1.43,.28)*torso
        # Existing pectoral planes carry the fitted suit; preserve insertions.
        front=max(0.,min(1.,-y/.1))
        y-=.014*g(abs(x),.13,.10)*g(z,1.63,.095)*front*torso
        # Broaden natural quadriceps/calves about each leg's own center.
        if z<1.18:
            sign=-1. if x<0 else 1.
            legcenter=sign*.133
            strength=.11*g(z,.92,.18)+.10*g(z,.47,.13)
            x=legcenter+(x-legcenter)*(1.+strength)
            y*=1.+strength
        # Full deltoid/biceps volume follows the existing arm centerline rather
        # than widening the whole shoulder into a triangular sheet.
        if ax>.25 and 1.22<z<1.77:
            arm_center=.29+(1.73-z)*.30
            strength=.17*g(z,1.61,.13)+.16*g(z,1.44,.12)
            lateral=max(0.,min(1.,(ax-.25)/.055))
            x=math.copysign(arm_center+(abs(x)-arm_center)*(1.+strength*lateral),x)
            y*=1.+strength*lateral
        # Bring the donor's relaxed A-pose nearer the game's neutral arms-down
        # stance. A smooth shoulder blend keeps its anatomical junction intact.
        lateral=max(0.,min(1.,(abs(x)-.225)/.11))
        upper=max(0.,min(1.,(1.84-z)/.13))
        blend=lateral*lateral*(3.-2.*lateral)*upper
        theta=math.radians(12.)*blend
        if z>.87:
            sign=-1. if x<0 else 1.
            dx=abs(x)-.29; dz=z-1.73
            x=sign*(.29+math.cos(theta)*dx+math.sin(theta)*dz)
            z=1.73-math.sin(theta)*dx+math.cos(theta)*dz
        vertex.co=(x,y,z)
    body.data.update()
    return objects


def study_material(name,color,rough=.65):
    mat=bpy.data.materials.new(name); mat.use_nodes=True; mat.diffuse_color=(*color,1)
    node=mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value=(*color,1); node.inputs["Roughness"].default_value=rough
    return mat


def dress_study(objects):
    # Preliminary plain coverage only, not final costume/material acceptance.
    mats=[study_material("Study fitted graphite",(.016,.020,.028)),study_material("Study skin",(.32,.20,.14),.58),study_material("Study gloves",(.007,.009,.012),.48)]
    body=objects[0]
    for mat in mats: body.data.materials.append(mat)
    for poly in body.data.polygons:
        c=sum((body.data.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
        poly.material_index=1 if c.z>1.83 else (2 if (c.z<.27 or (abs(c.x)>.38 and c.z<1.20)) else 0)
    eye_mat=study_material("Study sclera",(.58,.57,.53),.27)
    for obj in objects[1:]:obj.data.materials.append(eye_mat)
    return objects
