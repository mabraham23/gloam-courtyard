"""Original fitted anatomy: continuous trunk-to-arm quad skin, no voxel union.

Broad volumes are authored in the silhouette and fitted surface. The shoulder
holes are bridged into real arm rings, not covered with overlapping spheres.
Legs remain separate semantic trouser panels so thighs cannot weld together.
Uses the frozen 74-bone rig; this module deliberately does not move joints.
"""
from __future__ import annotations

import math
import bpy
from mathutils import Vector
from mesh_tools import MeshAssembly, MeshPart, horizontal_loft, path_tube, torus, normalized, blend_weights, smart_uv, triangulate
import generate_gloam_vigil_v2 as scaffold

SUIT = "MAT_GV2_Suit_Cloth"
GEAR = "MAT_GV2_Gear"
ACCENT = "MAT_GV2_Accent"


def gauss(value, center, width):
    return math.exp(-((value - center) / width) ** 2)


def sample(controls, count):
    """Cubic interpolation retains authored sections without linear banding."""
    result = []
    for step in range(count):
        t = step * (len(controls) - 1) / (count - 1)
        i = min(int(t), len(controls) - 2)
        u = t - i
        p0, p1, p2, p3 = [controls[max(0, min(j, len(controls) - 1))] for j in (i-1, i, i+1, i+2)]
        result.append(tuple(0.5*((2*b)+(-a+c)*u+(2*a-5*b+4*c-d)*u*u+(-a+3*b-3*c+d)*u*u*u) for a,b,c,d in zip(p0,p1,p2,p3)))
    return result


TRUNK = [
    (0.98,.215,.151,.008), (1.04,.239,.166,.010),
    (1.12,.230,.154,.001), (1.22,.202,.140,-.004),
    (1.32,.211,.151,-.004), (1.42,.253,.171,.003),
    (1.51,.293,.187,.008), (1.60,.316,.191,.012),
    (1.68,.310,.171,.014), (1.73,.254,.142,.018),
    (1.78,.155,.104,.018), (1.825,.101,.083,.014),
]


def trunk_shape(z, rx, ry, cy, angle):
    x, y = rx*math.sin(angle), cy-ry*math.cos(angle)
    front = max(0., math.cos(angle)) ** 2
    rear = max(0., -math.cos(angle)) ** 2
    # Pectoral belly, its lower insertion, sternum and clavicle are part of
    # the same skin, with broad planes rather than separate armour balls.
    pec = .037*gauss(abs(x),.136,.098)*gauss(z,1.575,.076)
    pec_fold = .006*gauss(z,1.477+abs(x)*.10,.014)*gauss(abs(x),.14,.12)
    sternum = .007*gauss(x,0,.024)*gauss(z,1.55,.15)
    abs_belly = sum(.008*gauss(z,h,.032)*gauss(abs(x),.061,.045) for h in (1.235,1.313,1.387))
    oblique = .009*gauss(abs(x),.15-(z-1.25)*.24,.04)*gauss(z,1.31,.13)
    clavicle = .006*gauss(z,1.697-.13*abs(x),.012)*gauss(abs(x),.14,.10)
    y -= front*(pec-pec_fold-sternum+abs_belly+oblique+clavicle)
    y += rear*(.013*gauss(z,1.58,.13)*gauss(abs(x),.12,.11)-.004*gauss(x,0,.025))
    return x,y,z


def trunk_weights(z, angle):
    base = scaffold.core_weights(z) if z < 1.71 else scaffold.weights_at(z,[(1.71,"chest"),(1.825,"neck")])
    # Shoulder opening border gets the same weights as its sewn arm edge.
    lateral = abs(math.sin(angle))**10*gauss(z,1.63,.14)*.66
    side = "R" if math.sin(angle)>0 else "L"
    return blend_weights(base,{f"clavicle.{side}":1.},lateral)


def torso_and_arms(assembly, materials):
    sides, rows = 32, 33
    sections = sample(TRUNK, rows)
    vertices, weights, faces = [], [], []
    for z,rx,ry,cy in sections:
        for s in range(sides):
            angle = math.tau*s/sides
            vertices.append(trunk_shape(z,rx,ry,cy,angle))
            weights.append(trunk_weights(z,angle))
    r0 = min(range(rows),key=lambda r:abs(sections[r][0]-1.505))
    r1 = min(range(rows),key=lambda r:abs(sections[r][0]-1.716))
    holes = [(5,11,"R",1.),(21,27,"L",-1.)]
    for r in range(rows-1):
        for s in range(sides):
            if r0<=r<r1 and any(lo<=s<hi for lo,hi,_,_ in holes):
                continue
            faces.append((r*sides+s,r*sides+(s+1)%sides,(r+1)*sides+(s+1)%sides,(r+1)*sides+s))
    faces.append(tuple(reversed(range(sides))))
    # Top stays open underneath the neck; it is not capped across skin.
    for lo,hi,side,sign in holes:
        boundary = [r0*sides+s for s in range(lo,hi+1)]
        boundary += [r*sides+hi for r in range(r0+1,r1+1)]
        boundary += [r1*sides+s for s in range(hi-1,lo-1,-1)]
        boundary += [r*sides+lo for r in range(r1-1,r0,-1)]
        center = Vector((sign*.292,0.,1.610))
        axis = Vector((sign*.91,0.,.41))
        phis = [math.atan2((Vector(vertices[i])-center).dot(axis),(Vector(vertices[i])-center).y) for i in boundary]
        arm_controls = [
            (sign*.324,-.001,1.603,.124,.129),
            (sign*.346,-.002,1.529,.117,.121),
            (sign*.361,-.005,1.444,.114,.113),
            (sign*.380,-.006,1.350,.098,.097),
            (sign*.390,-.006,1.250,.076,.075),
            (sign*.389,-.011,1.183,.089,.084),
            (sign*.387,-.017,1.098,.096,.085),
            (sign*.384,-.023,1.016,.078,.070),
            (sign*.380,-.030,.930,.059,.057),
        ]
        arm_sections=sample(arm_controls,25)
        anchors=[(.93,f"forearm_twist.{side}"),(1.08,f"forearm.{side}"),(1.25,f"upper_arm_twist.{side}"),(1.47,f"upper_arm.{side}"),(1.68,f"clavicle.{side}")]
        previous=boundary
        for r,(x,y,z,rx,ry) in enumerate(arm_sections):
            before=Vector(arm_sections[max(0,r-1)][:3]); after=Vector(arm_sections[min(len(arm_sections)-1,r+1)][:3])
            tangent=(after-before).normalized()
            ax=Vector((-tangent.z*sign,0,tangent.x*sign)).normalized()
            ax.x=abs(ax.x)*sign
            current=[]
            for phi in phis:
                # Biceps and triceps ride the underlying sleeve surface.
                bulge=.010*gauss(z,1.455,.100)*max(0.,-math.cos(phi))**3
                radius_y=ry+bulge
                pos=Vector((x,y,z))+ax*(math.sin(phi)*rx)+Vector((0,math.cos(phi)*radius_y,0))
                current.append(len(vertices)); vertices.append(tuple(pos)); weights.append(scaffold.weights_at(z,anchors))
            for j in range(len(current)):
                k=(j+1)%len(current)
                faces.append((previous[j],previous[k],current[k],current[j]))
            previous=current
        faces.append(tuple(reversed(previous)))
    # One Catmull-Clark pass rounds the shared shoulder boundary itself,
    # including quad junctions; it cannot hide a disconnected cap or voxel tear.
    used=sorted({i for face in faces for i in face}); remap={old:new for new,old in enumerate(used)}
    part=MeshPart([vertices[i] for i in used],[tuple(remap[i] for i in face) for face in faces],[weights[i] for i in used],SUIT)
    temporary=MeshAssembly(); temporary.append(part)
    obj=temporary.build("GV3_ConnectedSuitControl",materials)
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    sub=obj.modifiers.new("Connected shoulder surface","SUBSURF"); sub.levels=1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    groups={g.index:g.name for g in obj.vertex_groups}
    evaluated_weights=[]
    for vertex in obj.data.vertices:
        values={groups[g.group]:g.weight for g in vertex.groups if g.weight>1e-7}
        # Limit influence count deterministically after subdivision blending.
        evaluated_weights.append(normalized(dict(sorted(values.items(),key=lambda p:p[1],reverse=True)[:4])))
    assembly.append(MeshPart([tuple(v.co) for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],evaluated_weights,SUIT))
    bpy.data.objects.remove(obj,do_unlink=True)


def legs(assembly):
    for side,sign in (("L",-1.),("R",1.)):
        controls=[
            (1.079,.145,.141,.007),(1.015,.152,.157,.002),
            (.910,.145,.158,-.001),(.815,.132,.143,-.004),
            (.715,.108,.114,-.005),(.620,.088,.084,-.006),
            (.548,.097,.100,.005),(.464,.106,.117,.013),
            (.376,.098,.104,.010),(.282,.080,.082,.004),(.160,.067,.064,0.),
        ]
        anchors=[(.16,f"shin_twist.{side}"),(.4,f"shin.{side}"),(.62,f"thigh_twist.{side}"),(.86,f"thigh.{side}"),(1.04,f"thigh.{side}"),(1.08,"pelvis")]
        rings=[((sign*.12,cy,z),rx,ry,scaffold.weights_at(z,anchors)) for z,rx,ry,cy in sample(controls,43)]
        def shape(pos,angle,_r):
            x,y,z=pos
            front=max(0.,math.cos(angle))**2
            # Vastus medialis near the knee, long lateral quad and shin ridge.
            q=.013*gauss(z,.84,.17)*(0.75+0.25*math.sin(angle*sign))
            knee=.005*gauss(z,.63,.028)
            y-=front*(q+knee+.003*gauss(z,.34,.16))
            return x,y,z
        assembly.append(horizontal_loft(rings,64,SUIT,deform=shape))


def seam(assembly,points,material=GEAR,radius=.0022,weightfn=None):
    points=sample(points,max(12,len(points)*5))
    sections=sample(TRUNK,401)
    fitted=[]
    for x,y,z in points:
        a=min(range(len(sections)),key=lambda i:abs(sections[i][0]-z))
        _,rx,ry,cy=sections[a]
        angle=math.asin(max(-.99,min(.99,x/rx)))
        _,surface_y,_=trunk_shape(z,rx,ry,cy,angle)
        fitted.append((x,surface_y-radius*.8,z))
    points=fitted
    weights=[(weightfn(p) if weightfn else scaffold.core_weights(p[2])) for p in points]
    assembly.append(path_tube(points,[(radius,radius)]*len(points),weights,6,material))


def bevel_box(assembly,center,size,material=GEAR,bevel=.007,tag="pouch"):
    bpy.ops.mesh.primitive_cube_add(size=1.,location=center)
    obj=bpy.context.object
    obj.scale=size
    bpy.ops.object.transform_apply(location=True,rotation=False,scale=True)
    mod=obj.modifiers.new("Leather folded edges","BEVEL"); mod.width=bevel; mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    assembly.append(MeshPart([tuple(v.co) for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],[{"pelvis":1.} for _ in obj.data.vertices],material,{tag:set(range(len(obj.data.vertices)))}))
    bpy.data.objects.remove(obj,do_unlink=True)


def build_body(materials):
    assembly=MeshAssembly()
    torso_and_arms(assembly,materials)
    legs(assembly)
    scaffold.build_hands_and_boots(assembly)
    # Reuse only the fitted belt, replace bulbous pouches with folded leather
    # panels and offset closure flaps with bevelled thickness.
    assembly.append(torus((0.,0.,1.075),(.238,.172),(.014,.020),72,14,GEAR,{"pelvis":.72,"spine":.28}))
    for sign in (-1.,1.):
        bevel_box(assembly,(sign*.169,-.143,1.052),(.104,.060,.126))
        bevel_box(assembly,(sign*.169,-.178,1.088),(.100,.012,.048),bevel=.005)
        bevel_box(assembly,(sign*.169,-.187,1.064),(.014,.007,.032),bevel=.002,tag="clasp")
        bevel_box(assembly,(sign*.226,.038,1.049),(.070,.064,.112),bevel=.009)
    bevel_box(assembly,(0.,-.178,1.071),(.057,.015,.043),ACCENT,.004,"accent")
    for sign in (-1.,1.):
        seam(assembly,[(sign*.030,-.207,1.490),(sign*.10,-.192,1.483),(sign*.178,-.158,1.492),(sign*.230,-.111,1.512)])
        seam(assembly,[(sign*.178,-.096,1.180),(sign*.186,-.113,1.277),(sign*.215,-.104,1.378),(sign*.247,-.087,1.455)],radius=.0022)
    seam(assembly,[(.13,-.211,1.625),(.105,-.218,1.555),(.06,-.186,1.43),(.018,-.166,1.32),(-.03,-.151,1.218),(-.07,-.162,1.108)],ACCENT,.0031)
    obj=assembly.build("GV2_Body",materials)
    bpy.ops.object.select_all(action="DESELECT"); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    # Recalculate connected quad normals before UVs and export triangulation.
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    smart_uv(obj)
    triangulate(obj)
    scaffold.assign_surface_vertex_colors(obj,set(),set(),set())
    colors=obj.data.color_attributes["Col"]
    for poly in obj.data.polygons:
        if obj.data.materials[poly.material_index].name!=GEAR:
            continue
        for index in poly.loop_indices:
            vertex=obj.data.loops[index].vertex_index
            colors.data[index].color=(.018,.011,.008,1.) if vertex in assembly.tags.get("pouch",set()) else (.006,.009,.013,1.)
    obj["gloam_authoring"]="Original connected trunk/arm quad skin; explicit muscle planes; semantic separate legs; no voxel union"
    return obj
