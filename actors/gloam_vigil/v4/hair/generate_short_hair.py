"""Original short tousled locks fitted over the preserved R14 scalp.

Uses the existing licensed head only for surface fitting. No reference image,
franchise asset, Blender session, or base GLB modification is involved.
Run with Python 3 from any directory; output is consumed by short_black_hair.gd.
"""
from pathlib import Path
import json
import math
import struct

ROOT = Path(__file__).resolve().parent
raw = (ROOT.parent / 'gloam_vigil_player_v4.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
gltf = json.loads(raw[20:20 + length])
binary = raw[28 + length:]


def accessor(index):
    a = gltf['accessors'][index]
    view = gltf['bufferViews'][a['bufferView']]
    code = {5126: 'f', 5125: 'I', 5123: 'H'}[a['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    size = struct.calcsize(code) * width
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from('<' + code * width, binary, start + i * view.get('byteStride', size)) for i in range(a['count'])]


face = gltf['meshes'][2]['primitives'][0]
points = accessor(face['attributes']['POSITION'])
indices = [x[0] for x in accessor(face['indices'])]
triangles = [tuple(points[i] for i in indices[n:n + 3]) for n in range(0, len(indices), 3)]
triangles = [t for t in triangles if max(p[1] for p in t) > 2.06]

# Fit the replacement to the anatomical head, excluding the old black shell.
source_colors = accessor(face['attributes']['COLOR_0'])
source_uvs = accessor(face['attributes']['TEXCOORD_0'])
source_normals = accessor(face['attributes']['NORMAL'])
head_triangles = [indices[n:n+3] for n in range(0, len(indices), 3)
                  if max(points[i][1] for i in indices[n:n+3]) > 1.98
                  and all(source_colors[i][0] > 265 for i in indices[n:n+3])]


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x-y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def scalp_hit(direction):
    center = (0.0, 2.049, 0.058)
    best = None
    for ids in head_triangles:
        a, b, c = (points[i] for i in ids)
        e1, e2 = sub(b, a), sub(c, a)
        h = cross(direction, e2)
        det = dot(e1, h)
        if abs(det) < 1e-10: continue
        origin = sub(center, a)
        u = dot(origin, h)/det
        if u < -1e-6 or u > 1.000001: continue
        q = cross(origin, e1)
        v = dot(direction, q)/det
        distance = dot(e2, q)/det
        if v < -1e-6 or u+v > 1.000001 or distance <= 0: continue
        if best is None or distance < best[0]: best = (distance, ids, (1-u-v, u, v))
    if best is None: raise ValueError(f'No anatomical scalp hit along {direction}')
    distance, ids, weights = best
    point = tuple(center[i]+direction[i]*distance for i in range(3))
    normal = tuple(sum(source_normals[idx][i]*w for idx,w in zip(ids,weights)) for i in range(3))
    magnitude = math.sqrt(dot(normal, normal))
    normal = tuple(x/magnitude for x in normal)
    uv = tuple(sum(source_uvs[idx][i]*w for idx,w in zip(ids,weights)) for i in range(2))
    return point, normal, uv


def tapered_scalp():
    result = {key: [] for key in ['vertices', 'normals', 'uvs', 'colors', 'triangles']}
    segments, rings = 64, 20
    for ring in range(rings+1):
        t = ring/rings
        for segment in range(1 if ring == 0 else segments):
            azimuth = math.tau*segment/segments
            front = math.cos(azimuth)
            # Raise the back as well as the sides. The clipped foundation
            # never extends into the old low, continuous dark nape rim.
            boundary = 1.48 - 0.30*front - 0.10*front*front
            boundary += 0.035*math.sin(5*azimuth+0.4) + 0.020*math.sin(9*azimuth)
            polar = t*boundary
            direction = (math.sin(polar)*math.sin(azimuth), math.cos(polar), math.sin(polar)*front)
            point, normal, uv = scalp_hit(direction)
            # This is only the closely clipped foundation. Long hair is built
            # as overlapping locks below, not as volume on a spherical cap.
            volume = 0.00055
            # A broad graduated fade makes the ear/back region visibly short.
            # The old narrow fade left a continuous dark bowl-shaped rim.
            fade_start = 0.78 if front > 0.65 else 0.43
            fade = max(0.0, (t-fade_start)/(1.0-fade_start))
            fade = fade*fade*(3-2*fade)
            result['vertices'].append([round(point[i]+normal[i]*volume,7) for i in range(3)])
            result['normals'].append([round(x,7) for x in normal])
            result['uvs'].append([round(x,7) for x in uv])
            result['colors'].append([round(x+(1-x)*fade,7) for x in (0.003,0.004,0.006)])
    for segment in range(segments):
        result['triangles'].append([0,1+segment,1+(segment+1)%segments])
    for ring in range(1,rings):
        a=1+(ring-1)*segments; b=a+segments
        for segment in range(segments):
            nxt=(segment+1)%segments
            result['triangles'].extend([[a+segment,b+segment,a+nxt],[a+nxt,b+segment,b+nxt]])
    return result


def front_surface(x, y):
    hits = []
    for a, b, c in triangles:
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-10:
            continue
        u = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / den
        v = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / den
        if min(u, v, 1 - u - v) >= -1e-6:
            hits.append(u * a[2] + v * b[2] + (1 - u - v) * c[2])
    if not hits:
        raise ValueError(f'Fringe point missed the head: {x}, {y}')
    return max(hits)


vertices, faces = [], []


def top_surface(x, z):
    """Highest anatomical head point at X/Z; old hair is never a fit surface."""
    hits = []
    for ids in head_triangles:
        a, b, c = (points[i] for i in ids)
        den = (b[2]-c[2])*(a[0]-c[0]) + (c[0]-b[0])*(a[2]-c[2])
        if abs(den) < 1e-10: continue
        u = ((b[2]-c[2])*(x-c[0]) + (c[0]-b[0])*(z-c[2]))/den
        v = ((c[2]-a[2])*(x-c[0]) + (a[0]-c[0])*(z-c[2]))/den
        if min(u,v,1-u-v) >= -1e-6:
            hits.append(u*a[1]+v*b[1]+(1-u-v)*c[1])
    if not hits: raise ValueError(f'Top lock missed the head: {x}, {z}')
    return max(hits)


def swept_lock(root, middle, tip, width, lift):
    """Broad rooted sheet, folded ridge and pointed end following the skull.

    Curves run across the crown rather than standing up as isolated spikes.
    The narrow ridge and overlapping ends break the smooth dome silhouette.
    """
    start = len(vertices)
    rows, columns = 11, 9
    dx, dz = tip[0]-root[0], tip[1]-root[1]
    length = math.hypot(dx,dz)
    lateral = (dz/length,-dx/length)
    for row in range(rows):
        t = row/(rows-1)
        center = [(1-t)**2*root[i]+2*t*(1-t)*middle[i]+t*t*tip[i] for i in range(2)]
        half_width = width*(0.60+0.40*math.sin(math.pi*t))*(1-t)**0.62 + 0.0003
        rise = lift*math.sin(math.pi*t)**0.72 + 0.003*t
        for column in range(columns):
            q = 2*column/(columns-1)-1
            x,z = [center[i]+lateral[i]*half_width*q for i in range(2)]
            # Keep the back of the crown short: it becomes the highest point
            # when the head pitches into crouch. Length grows toward the front.
            rear_taper = min(1.0,max(0.0,(z+0.035)/0.085))
            # Round each folded cross-section while retaining the asymmetric
            # pointed end; a triangular ridge read as teeth from the rear.
            ridge = max(0.0,math.cos(q*math.pi*0.5))**1.2
            y = top_surface(x,z) + 0.0014 + rise*rear_taper*ridge
            vertices.append((x,y,z))
    for row in range(rows-1):
        for col in range(columns-1):
            a = start+row*columns+col
            # +Y outward in source space; the runtime reverses for Godot.
            faces.extend([(a,a+columns,a+1),(a+1,a+columns,a+columns+1)])


def fringe(root_x, root_y, tip_x, tip_y, width, relief):
    """A broad attached root, swept ridge, and fine asymmetric tapered tip."""
    start = len(vertices)
    rows, columns = 9, 7
    for row in range(rows):
        t = row / (rows - 1)
        cx = root_x * (1 - t) + tip_x * t + 0.008 * math.sin(math.pi * t)
        y = root_y * (1 - t) + tip_y * t
        half_width = width * (1 - t) ** 0.65 + 0.0004
        for column in range(columns):
            q = 2 * column / (columns - 1) - 1
            x = cx + q * half_width
            z = front_surface(x, y) + 0.0025 + relief * (1 - abs(q)) * math.sin(math.pi * t) ** 0.65
            vertices.append((x, y, z))
    for row in range(rows - 1):
        for col in range(columns - 1):
            a = start + row * columns + col
            faces.extend([(a, a + columns, a + 1), (a + 1, a + columns, a + columns + 1)])


# Uneven fringe with an offset part: broad locks, clear forehead breaks, clear eyes.
fringe(-0.040, 2.146, -0.071, 2.068, 0.024, 0.008)
fringe(0.004, 2.161, -0.030, 2.091, 0.026, 0.013)
fringe(0.041, 2.151, 0.025, 2.080, 0.027, 0.010)
fringe(0.073, 2.126, 0.073, 2.075, 0.015, 0.006)
# Layered diagonal sweeps have separate roots and uneven lengths. The outer
# locks sit lower, exposing the fade instead of extending a helmet over it.
swept_lock((-0.060,-0.012),(-0.078,0.040),(-0.068,0.105),0.022,0.006)
swept_lock((-0.039,-0.028),(-0.026,0.035),(-0.051,0.126),0.048,0.018)
swept_lock((0.010,-0.046),(0.032,0.040),(0.017,0.132),0.047,0.021)
swept_lock((0.057,-0.015),(0.077,0.038),(0.074,0.107),0.022,0.008)

result = {'schema': 1, 'description': 'Original overlapping swept top locks, angular fringe and broadly faded close-clipped sides; model coordinates, head skin binding.',
          'vertices': [[round(x,7) for x in p] for p in vertices], 'triangles': faces,
          'scalp': tapered_scalp()}
(ROOT/'short_black_hair.json').write_text(json.dumps(result, separators=(',', ':')) + '\n')
print(f'SHORT_HAIR_GENERATED locks={len(vertices)} scalp={len(result["scalp"]["vertices"])} triangles={len(faces)+len(result["scalp"]["triangles"])}')
