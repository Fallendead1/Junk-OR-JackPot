"""
fix_for_roblox.py

Cleans up a model that just came out of Rodin (or any AI mesh generator)
so it's safe to hand to the Roblox Blender plugin or Studio's importer.
AI-generated meshes commonly have: un-applied scale/rotation, flipped
normals, duplicate/overlapping vertices, an origin sitting in empty
space instead of on the mesh, and n-gons. This script fixes all of that
in one pass.

HOW TO RUN
----------
Option A - inside Blender (recommended while you're learning it):
    1. Open the Scripting tab in Blender.
    2. Open this file (Text > Open).
    3. Select the object(s) you want fixed in the 3D viewport.
    4. Press "Run Script" (the play button).

Option B - from a terminal, no Blender window needed:
    blender --background your_model.blend --python fix_for_roblox.py

Either way, it only touches objects that are currently selected. If
nothing is selected when run headless, it falls back to every mesh
object in the scene.

WHAT IT DOES, IN ORDER
-----------------------
1. Applies location/rotation/scale so each object reports (0,0,0) location
   is real, rotation is 0, and scale is 1,1,1. Roblox's importer and the
   Blender plugin both trust these values - an un-applied scale is the
   #1 cause of a model coming into Studio the wrong size.
2. Merges duplicate/overlapping vertices (common seam artifact from
   AI generators).
3. Recalculates normals so they all point outward (fixes the "model
   looks inside-out from some angles" bug).
4. Triangulates the mesh (Roblox triangulates on import anyway; doing
   it here means what you see in Blender is what you get in Studio).
5. Sets the origin to the base-center of the mesh's bounding box, so the
   object sits flush on the ground instead of floating or clipping when
   you place it in Studio. Set ORIGIN_TO_BASE = False below if a
   particular model should keep its own origin instead (e.g. it's meant
   to be attached by its center, like a coin or a gear).

Decimation (reducing polycount) is deliberately NOT automatic. AI-generated
meshes can be dense in ways a blanket decimate ratio will visibly wreck,
and nobody is here to eyeball the result before it ships. If a specific
model needs its poly count cut down, do it by hand with Blender's Decimate
modifier so you can watch the result as you drag the ratio.
"""

import bpy
import bmesh

# Flip to False for objects that should keep their existing origin
# (things meant to attach by their center rather than sit on the ground).
ORIGIN_TO_BASE = True


def get_target_objects():
    selected_meshes = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if selected_meshes:
        return selected_meshes
    return [obj for obj in bpy.data.objects if obj.type == "MESH"]


def apply_transforms(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def clean_mesh_data(obj):
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)

    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)

    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def set_origin_to_base(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    # Move the 3D cursor to the horizontal center / lowest point of the
    # object's bounding box, then snap the origin to the cursor.
    bbox_corners = [obj.matrix_world @ __import__("mathutils").Vector(corner) for corner in obj.bound_box]
    min_z = min(corner.z for corner in bbox_corners)
    center_x = sum(corner.x for corner in bbox_corners) / 8
    center_y = sum(corner.y for corner in bbox_corners) / 8

    cursor = bpy.context.scene.cursor
    original_cursor_location = cursor.location.copy()
    cursor.location = (center_x, center_y, min_z)

    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")

    cursor.location = original_cursor_location


def main():
    targets = get_target_objects()
    if not targets:
        print("fix_for_roblox: no mesh objects found (select something, or run in a scene with meshes).")
        return

    for obj in targets:
        apply_transforms(obj)
        clean_mesh_data(obj)
        if ORIGIN_TO_BASE:
            set_origin_to_base(obj)
        print(f"fix_for_roblox: cleaned '{obj.name}'")

    print(f"fix_for_roblox: done, {len(targets)} object(s) cleaned. Ready for the Roblox Blender plugin.")


if __name__ == "__main__":
    main()
