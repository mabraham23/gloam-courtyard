"""Matched before/candidate Blender cameras, scale, light and color management.

No image manipulation or relighting between models. No review pose or studio
is saved to either source. Use -- --asset=v1|v3 --revision=r1 --view=front|...
"""
from pathlib import Path
import sys
import bpy

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/"v2"))
import render_v2 as studio


def main():
    args={s[2:].split("=",1)[0]:s.split("=",1)[1] for s in sys.argv if s.startswith("--") and "=" in s}
    asset=args.get("asset","v3"); revision=args.get("revision","r1"); view=args.get("view","threequarter")
    source=HERE.parent/"source"/"gloam_vigil_player.blend" if asset=="v1" else HERE/"source"/"gloam_vigil_player_v3.blend"
    bpy.ops.wm.open_mainfile(filepath=str(source))
    # Authoring source may contain old review lights/camera/floor. Remove only
    # from this temporary render session, never from the saved baseline file.
    for obj in list(bpy.data.objects):
        if obj.type in {"LIGHT","CAMERA"} or obj.name.lower().startswith(("review floor","floor","ground")):
            bpy.data.objects.remove(obj,do_unlink=True)
    for obj in bpy.data.objects:
        if obj.type=="ARMATURE":
            obj.hide_set(False)
            for bone in obj.pose.bones:
                bone.rotation_mode="QUATERNION"; bone.rotation_quaternion.identity(); bone.location=(0,0,0); bone.scale=(1,1,1)
    scene=bpy.context.scene
    scene.render.engine="BLENDER_EEVEE"
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.film_transparent=False
    scene.view_settings.view_transform="AgX"
    scene.view_settings.look="AgX - Medium High Contrast"
    scene.world.color=(.025,.030,.040)
    _,camera=studio.add_studio()
    studio.RENDER_DIR=HERE/"renders"/revision
    studio.RENDER_DIR.mkdir(parents=True,exist_ok=True)
    views={
      "front":((0.,-5.3,1.10),(0.,0.,1.08),70.,(720,960)),
      "threequarter":((3.65,-4.55,1.26),(0.,0.,1.10),76.,(720,960)),
      "head-front":((0.,-1.62,2.00),(0.,-.005,1.98),85.,(960,960)),
      "head-threequarter":((.74,-1.42,2.055),(0.,-.015,2.020),92.,(960,960)),
      "profile":((5.3,0.,1.10),(0.,0.,1.08),70.,(720,960)),
    }
    for selected in views if view=="all" else [view]:
        location,target,lens,resolution=views[selected]
        studio.render_view(camera,f"{asset}-{selected}.png",location,target,lens,resolution)
    print(f"GV3_REVIEW_RENDER {asset} {view} {revision}")


if __name__=="__main__":
    main()
