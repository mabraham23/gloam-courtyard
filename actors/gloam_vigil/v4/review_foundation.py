"""Render narrow CC0 source derivative for anatomy review, not a game export."""
from pathlib import Path
import sys
import bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));sys.path.insert(0,str(HERE.parent/"v2"))
from body_from_base import load_anatomy,heroic_proportions,dress_study
import render_v2 as studio

bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
objects=dress_study(heroic_proportions(load_anatomy(1)))
body=objects[0]
print("FOUNDATION_COUNTS",len(body.data.vertices),len(body.data.polygons))
for z in (.15,.6,1.08,1.3,1.6,1.7,1.8,1.9,2.05):
    points=[v.co for v in body.data.vertices if abs(v.co.z-z)<.015]
    print("BODY_SLICE",z,[(min(p[i] for p in points),max(p[i] for p in points)) for i in range(3)] if points else [])
scene=bpy.context.scene;scene.render.engine="BLENDER_EEVEE";scene.render.image_settings.file_format="PNG";scene.view_settings.view_transform="AgX";scene.view_settings.look="AgX - Medium High Contrast"
scene.world.color=(.025,.030,.040)
_,camera=studio.add_studio();studio.RENDER_DIR=HERE/"renders/foundation";studio.RENDER_DIR.mkdir(parents=True,exist_ok=True)
studio.render_view(camera,"body-front.png",(0,-5.3,1.10),(0,0,1.08),70,(720,960))
studio.render_view(camera,"body-threequarter.png",(3.65,-4.55,1.26),(0,0,1.10),76,(720,960))
studio.render_view(camera,"head-threequarter.png",(.74,-1.42,2.055),(0,-.015,2.02),92,(960,960))
print("FOUNDATION_REVIEW_COMPLETE")
