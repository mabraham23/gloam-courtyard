"""Original fitted costume on licensed anatomy, kept separate from its source.

No franchise costume geometry is used. Tailored graphite panels, an asymmetric
accent seam, folded utility pouches, fitted gloves, structured boots and a split
cape retain the project's own design. Does not add collision or simulation.
"""
from pathlib import Path
import math
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from mesh_tools import MeshAssembly, MeshPart, horizontal_loft, path_tube, torus, cape_panel, normalized, smart_uv, triangulate
import generate_gloam_vigil_v2 as scaffold

SUIT="MAT_GV2_Suit_Cloth"; GEAR="MAT_GV2_Gear"; BOOT="MAT_GV2_Tactical_Boot"; ACCENT="MAT_GV2_Accent"
COLLAR=1.825


def cut_at(obj,z,keep_above):
    mesh=bmesh.new(); mesh.from_mesh(obj.data)
    bmesh.ops.bisect_plane(mesh,geom=list(mesh.verts)+list(mesh.edges)+list(mesh.faces),dist=1e-6,plane_co=(0,0,z),plane_no=(0,0,1),clear_inner=keep_above,clear_outer=not keep_above)
    mesh.to_mesh(obj.data);mesh.free();obj.data.update()


def split_anatomy(body):
    head=body.copy();head.data=body.data.copy();bpy.context.collection.objects.link(head)
    head.name="GV2_Face";body.name="GV2_Body"
    cut_at(head,COLLAR,True);cut_at(body,COLLAR,False);cut_at(body,.205,True)
    # Fabric bridges the intimate anatomical detail; it is not just nude skin
    # with a dark material. A fitted front panel is also laid over this zone.
    for vertex in body.data.vertices:
        x,y,z=vertex.co
        blend=math.exp(-(x/.085)**4)*math.exp(-((z-1.055)/.115)**4)
        if y<-.125:
            vertex.co.y=y+(max(y,-.125)-y)*blend
        # The generic nude base includes projecting intimate anatomy. Bring
        # that small central feature into the garment's crotch, then relax
        # the local cloth envelope; retain the connected source topology.
        center=math.exp(-(x/.044)**4)*math.exp(-((z-.982)/.054)**4)
        forward=max(0.,min(1.,(-y-.035)/.035))
        vertex.co.z += max(0.,1.038-z)*center*forward
        vertex.co.y += max(0.,-.095-vertex.co.y)*center*forward
    neighbors=[set() for _ in body.data.vertices]
    for edge in body.data.edges:
        a,b=edge.vertices;neighbors[a].add(b);neighbors[b].add(a)
    for _ in range(18):
        positions=[v.co.copy() for v in body.data.vertices]
        for vertex in body.data.vertices:
            x,y,z=vertex.co
            mask=math.exp(-(x/.060)**4)*math.exp(-((z-1.018)/.064)**4)*max(0.,min(1.,(-y-.02)/.05))
            if mask>.015 and neighbors[vertex.index]:
                average=sum((positions[i] for i in neighbors[vertex.index]),Vector())/len(neighbors[vertex.index])
                vertex.co=vertex.co.lerp(average,.36*mask)
    body.data.update()
    return body,head


def set_body_materials(body,materials):
    body.data.materials.clear()
    for name in (SUIT,GEAR):body.data.materials.append(materials[name])
    for poly in body.data.polygons:
        center=sum((body.data.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
        poly.material_index=1 if abs(center.x)>.30 and center.z<1.165 else 0
        poly.use_smooth=True
    attr=body.data.color_attributes.get("Col") or body.data.color_attributes.new(name="Col",type="BYTE_COLOR",domain="CORNER")
    body.data.color_attributes.active_color=attr
    for poly in body.data.polygons:
        for loop in poly.loop_indices:attr.data[loop].color=(.007,.009,.013,1) if poly.material_index==1 else (1,1,1,1)


def box(assembly,center,size,material=GEAR,bevel=.007,tag="leather"):
    bpy.ops.mesh.primitive_cube_add(size=1.,location=center);obj=bpy.context.object;obj.scale=size
    bpy.ops.object.transform_apply(location=True,rotation=False,scale=True)
    mod=obj.modifiers.new("Folded edge","BEVEL");mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    assembly.append(MeshPart([tuple(v.co) for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],[{"pelvis":1.} for _ in obj.data.vertices],material,{tag:set(range(len(obj.data.vertices)))}))
    bpy.data.objects.remove(obj,do_unlink=True)


def build_boots(assembly,armature):
    for side,sign in (("L",-1.),("R",1.)):
        anchor=armature.data.bones[f"foot.{side}"].head_local
        x,y=anchor.x,anchor.y
        # One closed leather upper flows from a low toe box into the ankle.
        # This avoids intersecting balloon toes and an open-looking rear heel.
        controls=[(.028,.077,.181,y-.111),(.055,.079,.177,y-.110),(.078,.078,.163,y-.097),(.103,.075,.137,y-.069),(.137,.071,.094,y-.027),(.174,.070,.064,y),(.245,.076,.060,y-.012),(.330,.079,.064,y-.012)]
        rings=[((x,cy,z),rx,ry,{f"foot.{side}":1.}) for z,rx,ry,cy in scaffold.interpolate_controls(controls,28)]
        upper=horizontal_loft(rings,40,BOOT)
        def shoe_weight(point):
            _,cy,z=point
            sole=scaffold.weights_at(cy,[(y-.30,f"toe.{side}"),(y-.21,f"toe.{side}"),(y-.145,f"ball.{side}"),(y-.06,f"foot.{side}"),(y+.08,f"foot.{side}")])
            blend=max(0.,min(1.,(z-.13)/.09))
            return normalized({**{name:weight*(1.-blend) for name,weight in sole.items()},f"shin_twist.{side}":blend})
        upper.weights=[shoe_weight(point) for point in upper.vertices]
        assembly.append(upper)
        sole=horizontal_loft([((x,y-.111,z),.079,.183,{f"foot.{side}":1.}) for z in (.012,.019,.029)],40,GEAR)
        sole.weights=[shoe_weight(point) for point in sole.vertices]
        assembly.append(sole)
        assembly.append(torus((x,y-.012,.329),(.079,.064),(.002,.003),40,8,GEAR,{f"shin_twist.{side}":1.}))


def build_details(body,face,armature,materials):
    assembly=MeshAssembly()
    # Garment trim inherits the anatomical skin field at the actual surface,
    # not an obsolete height-only envelope from the procedural body.
    sources=[];fit_vertices=[];fit_faces=[]
    for mesh_obj in (body,face):
        offset=len(fit_vertices)
        fit_vertices.extend(v.co.copy() for v in mesh_obj.data.vertices)
        for polygon in mesh_obj.data.polygons:
            ids=[offset+i for i in polygon.vertices]
            fit_faces.extend((ids[0],ids[i],ids[i+1]) for i in range(1,len(ids)-1))
        sources.extend((mesh_obj,v) for v in mesh_obj.data.vertices)
    fit_tree=BVHTree.FromPolygons(fit_vertices,fit_faces,all_triangles=True)
    skin_tree=KDTree(len(sources))
    for index,point in enumerate(fit_vertices):skin_tree.insert(point,index)
    skin_tree.balance()
    def surface_weights(point,triangle=-1):
        weights={}
        if triangle>=0:
            # The collar must follow the actual hit surface, not nearby
            # vertices across the body/head partition. KD averaging mixed
            # different neck fields and exposed skin during deep crouch.
            ids=fit_faces[triangle]
            a,b,c=(fit_vertices[i] for i in ids)
            ab,ac,ap=b-a,c-a,point-a
            d00,d01,d11=ab.dot(ab),ab.dot(ac),ac.dot(ac)
            denominator=d00*d11-d01*d01
            assert abs(denominator)>1e-16,(triangle,denominator)
            v=(d11*ap.dot(ab)-d01*ap.dot(ac))/denominator
            w=(d00*ap.dot(ac)-d01*ap.dot(ab))/denominator
            samples=list(zip(ids,(max(0.,1.-v-w),max(0.,v),max(0.,w))))
        else:
            samples=[(index,1./max(distance,.0005)**2) for _,index,distance in skin_tree.find_n(point,4)]
        for index,falloff in samples:
            obj,vertex=sources[index]
            for group in vertex.groups:
                name=obj.vertex_groups[group.group].name
                if name in armature.data.bones:
                    weights[name]=weights.get(name,0.)+group.weight*falloff
        return normalized(dict(sorted(weights.items(),key=lambda p:p[1],reverse=True)[:4]))
    assembly.append(torus((0,0,1.13),(.231,.166),(.014,.020),64,12,GEAR,{"pelvis":.75,"spine":.25}))
    for sign in (-1.,1.):
        box(assembly,(sign*.153,-.143,1.101),(.095,.056,.127))
        box(assembly,(sign*.153,-.177,1.139),(.094,.010,.045),bevel=.004)
        box(assembly,(sign*.153,-.184,1.116),(.016,.008,.025),bevel=.002,tag="clasp")
        box(assembly,(sign*.215,.032,1.09),(.075,.072,.119),bevel=.007)
    box(assembly,(0,-.175,1.128),(.058,.020,.043),ACCENT,.004,"accent")
    build_boots(assembly,armature)
    # Fit each row to the neck/shoulder transition, with a sealed thin rim.
    # Reusing one cut-ring at every height made the old band visibly float.
    verts=[];faces=[];weights=[];n=64
    for height,extra,lift in ((1.802,.003,0.),(1.814,.003,.0005),(1.828,.003,.0025),(1.838,.003,0.),(1.838,.001,0.)):
        center=Vector((0,-.025,height))
        for i in range(n):
            angle=math.tau*i/n;radial=Vector((math.sin(angle),math.cos(angle),0))
            hit,normal,triangle,_=fit_tree.ray_cast(center+radial*.45,-radial,.8)
            assert hit is not None,(height,i)
            point=hit+radial*extra
            # Deep crouch puts the rear middle band just behind the throat.
            # Tailor a 2.5 mm local clearance into that row, retaining the
            # sampled skin weights and the unchanged front/top neckline.
            rear=max(0.,min(1.,(radial.y-.2)/.4))
            point.z += lift*rear*rear*(3.-2.*rear)
            verts.append(tuple(point));weights.append(surface_weights(hit,triangle))
    for row in range(4):
        for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
    assembly.append(MeshPart(verts,faces,weights,GEAR))
    # Tailoring seams are projected to the actual licensed derivative surface.
    tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[p.vertices for p in body.data.polygons],all_triangles=False)
    def seam(path,material=GEAR,radius=.002):
        points=[];weights=[]
        for x,z in scaffold.interpolate_controls(path,30):
            hit,normal,_,_=tree.ray_cast(Vector((x,-1,z)),Vector((0,1,0)),2.)
            if hit is None:continue
            points.append(tuple(hit+normal*radius*.7));weights.append(surface_weights(hit))
        if len(points)>2:assembly.append(path_tube(points,[(radius,radius)]*len(points),weights,6,material))
    for sign in(-1.,1.):
        seam([(sign*.025,1.505),(sign*.10,1.503),(sign*.19,1.529),(sign*.245,1.569)])
        seam([(sign*.20,1.184),(sign*.177,1.29),(sign*.195,1.42),(sign*.244,1.49)])
    seam([(.16,1.687),(.12,1.603),(.058,1.467),(.017,1.351),(-.05,1.235),(-.10,1.156)],ACCENT,.003)
    obj=assembly.build("GV4_CostumeDetails",materials)
    smart_uv(obj);triangulate(obj)
    attr=obj.data.color_attributes.new(name="Col",type="BYTE_COLOR",domain="CORNER");obj.data.color_attributes.active_color=attr
    for poly in obj.data.polygons:
        for loop in poly.loop_indices:
            index=obj.data.loops[loop].vertex_index
            gear=obj.data.materials[poly.material_index].name==GEAR
            attr.data[loop].color=((.019,.012,.009,1) if index in assembly.tags.get("leather",set()) else (.007,.009,.012,1)) if gear else (1,1,1,1)
    return obj


def build_cape(materials,body):
    assembly=MeshAssembly()
    tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[p.vertices for p in body.data.polygons],all_triangles=False)
    for side,sign in(("L",-1.),("R",1.)):
        part=cape_panel(sign,20,24,SUIT,[f"cape.{side}",f"cape_mid.{side}",f"cape_lower.{side}",f"cape_tip.{side}"])
        vertices=[]
        for x,y,z in part.vertices:
            row=max(0.,min(1.,(1.705-z)/1.155))
            root_x=x/(1.+.75*row)
            hit,_,_,_=tree.ray_cast(Vector((root_x,1.,1.755)),Vector((0,-1,0)),2.)
            offset=(hit.y+.006-.193) if hit is not None else -.06
            fade=max(0.,1.-row/.5)**2
            vertices.append((x,y+.085+offset*fade,z+.05))
        part.vertices=vertices
        assembly.append(part)
    obj=assembly.build("GV2_Cape",materials);smart_uv(obj);triangulate(obj)
    return obj
