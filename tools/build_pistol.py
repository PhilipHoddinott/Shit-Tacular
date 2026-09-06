"""Build the original cartoon pistol viewmodel with Blender 4.5+.

Run from any directory:
  blender --background --factory-startup --python tools/build_pistol.py

All design coordinates below are Godot coordinates: X right, Y up, -Z muzzle.
The converter maps these into Blender's Z-up space; glTF's Y-up export maps
them back, so Godot can use the asset at unit scale without axis corrections.
No downloaded assets, fonts, textures, add-ons, or external packages are used.
"""

from pathlib import Path
import math

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "assets" / "models" / "pistol_viewmodel.glb"
SOURCE_PATH = ROOT / "art_source" / "pistol_viewmodel.blend"
CONVERT = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def point(value):
    return CONVERT @ Vector(value)


def material(name, rgb, roughness=0.42, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


def finish(obj, name, mat, parent, bevel=0.0):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    if bevel:
        edge = obj.modifiers.new("Soft toy edges", "BEVEL")
        edge.width = bevel
        edge.segments = 3
        edge.limit_method = "ANGLE"
        normals = obj.modifiers.new("Weighted highlights", "WEIGHTED_NORMAL")
        normals.keep_sharp = True
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def empty(name, location=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = point(location)
    obj.parent = parent
    obj.empty_display_size = 0.025
    return obj


def box(name, center, size, mat, parent, bevel=0.006, rotation=0.0):
    """A rounded box, optionally tilted about Godot's X axis."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(center))
    obj = bpy.context.object
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.x = rotation
    return finish(obj, name, mat, parent, bevel)


def ellipsoid(name, center, size, mat, parent, rotation=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16, ring_count=10, radius=1, location=point(center)
    )
    obj = bpy.context.object
    obj.scale = (size[0] / 2, size[2] / 2, size[1] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.x = rotation
    return finish(obj, name, mat, parent)


def cylinder(name, center, radius, depth, mat, parent, axis=(0, 0, -1), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=point(center)
    )
    obj = bpy.context.object
    obj.rotation_euler = point(axis).to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, mat, parent, min(0.0025, depth / 4))


def tube(name, points, radius, mat, parent, cyclic=False):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 5
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for handle, position in zip(spline.bezier_points, points):
        handle.co = point(position)
        handle.handle_left_type = "AUTO"
        handle.handle_right_type = "AUTO"
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def sleeve(name, start, end, radius, mat, cuff_mat, parent):
    delta = Vector(end) - Vector(start)
    center = (Vector(start) + Vector(end)) / 2
    cylinder(name, center, radius, delta.length, mat, parent, delta, vertices=16)
    cylinder(name + "Cuff", start, radius * 1.035, 0.045, cuff_mat, parent, delta)


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0

    navy = material("Pistol_GraphiteNavy", (0.042, 0.083, 0.13), 0.34, 0.24)
    coral = material("Pistol_Coral", (0.88, 0.22, 0.095), 0.4, 0.08)
    orange = material("Pistol_OrangeEdge", (1.0, 0.47, 0.10), 0.38)
    brass = material("Pistol_Brass", (0.91, 0.64, 0.14), 0.3, 0.45)
    black = material("Pistol_BoreAndGrip", (0.012, 0.025, 0.042), 0.63)
    cream = material("Glove_CreamPadding", (0.91, 0.84, 0.63), 0.75)
    teal = material("Glove_Teal", (0.015, 0.42, 0.40), 0.65)
    teal_dark = material("Glove_Seams", (0.012, 0.18, 0.23), 0.68)
    sleeve_mat = material("Sleeve_Midnight", (0.045, 0.09, 0.19), 0.8)
    sight_mat = material("Pistol_MintSight", (0.28, 0.94, 0.64), 0.42)

    root = empty("PistolModel")
    root["design"] = "Original FLUSH-24 cartoon pistol with two padded utility gloves"
    root["coordinate_system"] = "Godot X right, Y up, -Z forward; metres"
    slide = empty("Slide", parent=root)
    hands = empty("Hands", parent=root)

    # Compact rounded upper. Slide is a separate node for procedural recoil.
    box("SlideBody", (0, 0.055, -0.253), (0.148, 0.108, 0.556), navy, slide, 0.013)
    box("SlideTopRidge", (0, 0.111, -0.263), (0.092, 0.012, 0.414), navy, slide, 0.003)
    box("CoralChassis", (0, -0.015, -0.239), (0.133, 0.053, 0.488), coral, root, 0.009)
    box("UnderBarrelAccent", (0, -0.044, -0.377), (0.099, 0.012, 0.185), orange, root, 0.004)
    cylinder("BrassBarrel", (0, 0.035, -0.575), 0.032, 0.09, brass, root)
    cylinder("DarkBore", (0, 0.035, -0.621), 0.021, 0.003, black, root)
    cylinder("BoreCore", (0, 0.035, -0.623), 0.011, 0.002, navy, root)

    # Raised rear U-notch and slim mint front blade line up at y = 0.13.
    box("RearSightBase", (0, 0.118, -0.006), (0.10, 0.013, 0.033), black, slide, 0.002)
    for side in (-1, 1):
        box("RearSightEar" + str(side), (side * 0.039, 0.129, -0.006), (0.022, 0.024, 0.032), navy, slide, 0.002)
        box("RearSightDot" + str(side), (side * 0.039, 0.13, 0.0108), (0.009, 0.008, 0.002), sight_mat, slide, 0.001)
    box("FrontSightBase", (0, 0.119, -0.49), (0.034, 0.010, 0.041), black, slide, 0.002)
    box("FrontSightBlade", (0, 0.129, -0.49), (0.013, 0.020, 0.031), sight_mat, slide, 0.002)

    # Grippable rear serrations and fun three-bolt brass badges on either side.
    for side in (-1, 1):
        for number in range(5):
            box("SlideSerration_%s_%s" % (side, number), (side * 0.075, 0.059, -0.034 - number * 0.023), (0.004, 0.066, 0.007), black, slide, 0.001)
        box("SideBadge" + str(side), (side * 0.0755, 0.056, -0.297), (0.006, 0.046, 0.105), brass, slide, 0.006)
        for number in range(3):
            cylinder("FlushDot_%s_%s" % (side, number), (side * 0.079, 0.055, -0.268 - number * 0.025), 0.006, 0.003, navy, slide, (side, 0, 0), 12)
        box("ChassisStripe" + str(side), (side * 0.0678, -0.008, -0.284), (0.003, 0.010, 0.225), cream, root, 0.002)
    box("EjectionPort", (0.024, 0.1107, -0.175), (0.052, 0.003, 0.071), black, slide, 0.006)
    box("EjectionBrass", (0.024, 0.1125, -0.178), (0.027, 0.002, 0.039), brass, slide, 0.004)

    # Tilt the handle rearward. Its lowest point is framed by the cream glove cuff.
    box("GripFrame", (0, -0.139, 0.005), (0.108, 0.245, 0.117), coral, root, 0.014, -0.21)
    box("GripInset", (0, -0.148, 0.035), (0.112, 0.176, 0.072), black, root, 0.013, -0.21)
    box("MagazineHeel", (0, -0.264, 0.032), (0.12, 0.025, 0.136), brass, root, 0.007, -0.21)
    tube("TriggerGuard", [(0, -0.038, -0.178), (0, -0.088, -0.20), (0, -0.122, -0.167), (0, -0.122, -0.047), (0, -0.044, -0.052)], 0.010, coral, root, True)
    tube("Trigger", [(0, -0.040, -0.133), (0, -0.074, -0.146), (0, -0.094, -0.126)], 0.006, brass, root)

    # Right shooting glove: organic palm, padded back, distinct wrapped fingers.
    ellipsoid("RightGlovePalm", (0.077, -0.169, 0.017), (0.125, 0.179, 0.151), teal, hands, -0.22)
    ellipsoid("RightBackPadding", (0.124, -0.17, 0.040), (0.034, 0.127, 0.098), cream, hands, -0.22)
    for index in range(3):
        y = -0.132 - index * 0.036
        z = -0.052 + index * 0.007
        tube("RightWrappedFinger" + str(index), [(0.104, y, z + 0.04), (0.066, y, z - 0.025), (0.004, y, z - 0.031), (-0.036, y, z - 0.006)], 0.019, teal, hands)
    tube("RightIndexFinger", [(0.094, -0.098, -0.044), (0.086, -0.081, -0.099), (0.043, -0.077, -0.137), (0.008, -0.080, -0.138)], 0.017, teal, hands)
    tube("RightThumb", [(0.051, -0.16, 0.092), (0.036, -0.092, 0.082), (0.020, -0.065, 0.018)], 0.024, teal, hands)

    # Supporting hand sits lower and on the opposite side, safely below sights.
    ellipsoid("LeftGlovePalm", (-0.081, -0.19, -0.030), (0.121, 0.147, 0.16), teal, hands, 0.19)
    ellipsoid("LeftBackPadding", (-0.126, -0.193, -0.006), (0.035, 0.109, 0.111), cream, hands, 0.19)
    for index in range(3):
        y = -0.15 - index * 0.031
        z = -0.078 + index * 0.005
        tube("LeftSupportFinger" + str(index), [(-0.110, y, z + 0.052), (-0.073, y, z - 0.015), (-0.014, y, z - 0.027), (0.036, y, z - 0.010)], 0.017, teal, hands)
    tube("LeftThumb", [(-0.080, -0.14, 0.024), (-0.069, -0.087, -0.036), (-0.072, -0.067, -0.117)], 0.020, teal, hands)

    # Slightly splayed cuffs and short sleeves disappear below the viewport.
    sleeve("RightSleeve", (0.09, -0.228, 0.105), (0.19, -0.317, 0.345), 0.058, sleeve_mat, cream, hands)
    sleeve("LeftSleeve", (-0.098, -0.235, 0.056), (-0.22, -0.345, 0.316), 0.056, sleeve_mat, cream, hands)
    for side in (-1, 1):
        cylinder("CuffButton" + str(side), (side * 0.147, -0.23, 0.089 if side > 0 else 0.042), 0.012, 0.005, teal_dark, hands, (side, 0, 0), 12)

    # Named reference nodes are exported; root uses their exact Godot positions.
    empty("Muzzle", (0, 0.035, -0.627), root)
    empty("SightFront", (0, 0.13, -0.49), slide)
    empty("SightRear", (0, 0.13, 0.011), slide)
    empty("GripAnchor", (0, -0.19, 0.01), root)

    # Save an editable source with modifiers. The GLB receives evaluated meshes.
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    bpy.context.scene.world.color = (0.10, 0.10, 0.10)
    bpy.context.scene.view_settings.view_transform = "AgX"
    bpy.context.scene["asset_notes"] = "Edit this source or rerun tools/build_pistol.py. Runtime imports GLB only."
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_PATH),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )

    depsgraph = bpy.context.evaluated_depsgraph_get()
    vertices = []
    triangles = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        vertices.extend(CONVERT.inverted() @ (evaluated.matrix_world @ vertex.co) for vertex in mesh.vertices)
        evaluated.to_mesh_clear()
    bounds = [(round(min(v[i] for v in vertices), 4), round(max(v[i] for v in vertices), 4)) for i in range(3)]
    print("PISTOL_BUILD_OK GLB=" + str(MODEL_PATH))
    print("GODOT_BOUNDS_XYZ=" + str(bounds))
    print("TRIANGLES=" + str(triangles))
    print("MUZZLE=(0, 0.035, -0.627) SIGHT_HEIGHT=0.13")
    if triangles > 20000:
        raise RuntimeError("Pistol viewmodel exceeds the 20k triangle budget")


if __name__ == "__main__":
    build()
