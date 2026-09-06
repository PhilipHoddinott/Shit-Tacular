"""Rebuild the first-party cartoon living-room meshes with Blender 4.5.

Run: blender --background --factory-startup --python tools/build_living_room.py
All dimensions and placement below use Godot's metres / Y-up / -Z-front space.
Only meshes export; existing Godot furniture collisions remain authoritative.
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "assets" / "models"
SOURCE = ROOT / "art_source"
QA = ROOT / "artifacts"
for directory in (MODELS, SOURCE, QA):
    directory.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def point(v):
    return (v[0], -v[2], v[1])


def srgb(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def material(name, color, roughness=0.8, metallic=0.0):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    rgb = tuple(srgb(int(color[i:i+2], 16) / 255.0) for i in (0, 2, 4))
    result.diffuse_color = (*rgb, 1.0)
    bsdf = result.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return result


teal = material("Upholstery • deep lagoon", "328F85")
seat_teal = material("Upholstery • softly lit cushions", "4CB1A2")
seam_teal = material("Sewn piping • pale mint", "91D2BE")
dark_teal = material("Recessed seams", "24625F")
coral = material("Throw pillow • guava", "EE867F")
coral_piping = material("Guava pillow seam", "FFD0AF")
mustard = material("Throw pillow • marigold", "E7B34E")
mustard_piping = material("Marigold pillow seam", "FFE3A0")
walnut = material("Walnut edge and tapered feet", "785340", 0.5)
wood_top = material("Honey oak tabletop", "B47E53", 0.48)
wood_light = material("Subtle oak grain light", "BC895D", 0.55)
wood_dark = material("Subtle oak grain dark", "AC774D", 0.55)
brass = material("Brushed brass foot caps", "D6B268", 0.4, 0.35)


def assign(obj, mat):
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def rounded_box(name, center, size, mat, radius=0.04, segments=4):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(center))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Softly tailored roundovers", "BEVEL")
    bevel.width = min(radius, min(size) * 0.49)
    bevel.segments = segments
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    assign(obj, mat)
    normal = obj.modifiers.new("Weighted flat panels", "WEIGHTED_NORMAL")
    normal.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=normal.name)
    return obj


def tube(name, points, radius, mat, cyclic=False):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    polyline = curve.splines.new("POLY")
    polyline.points.add(len(points) - 1)
    for target, source in zip(polyline.points, points):
        target.co = (*point(source), 1)
    polyline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    assign(obj, mat)
    return obj


def outline(name, center, width, height, radius, mat, plane="xz", thickness=0.004):
    points = []
    for cx, cy, start in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for step in range(7):
            angle = math.radians(start + step * 15)
            u = cx * (width / 2 - radius) + radius * math.cos(angle)
            v = cy * (height / 2 - radius) + radius * math.sin(angle)
            points.append((center[0] + u,
                           center[1] + (v if plane == "xy" else 0),
                           center[2] + (v if plane == "xz" else 0)))
    return tube(name, points, thickness, mat, cyclic=True)


def foot(name, start, end, radius_bottom, radius_top, mat):
    a, b = Vector(point(start)), Vector(point(end))
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=radius_bottom,
                                   radius2=radius_top, depth=(b - a).length,
                                   location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    bevel = obj.modifiers.new("Rounded end grain", "BEVEL")
    bevel.width = 0.008
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return assign(obj, mat)


def pillow(name, center, mat, seam_mat, tilt, twist):
    # Squared-off superellipsoid gives stuffed corners and a full, soft centre.
    vertices, faces = [], []
    latitudes, longitudes = 16, 32

    def signed_power(value, power):
        return math.copysign(abs(value) ** power, value)

    for ring in range(latitudes + 1):
        lat = -math.pi / 2 + math.pi * ring / latitudes
        for segment in range(longitudes):
            lon = math.tau * segment / longitudes
            x = 0.205 * signed_power(math.cos(lat), 0.42) * signed_power(math.cos(lon), 0.4)
            y = 0.205 * signed_power(math.sin(lat), 0.42)
            z = 0.08 * signed_power(math.cos(lat), 0.42) * signed_power(math.sin(lon), 0.65)
            vertices.append(point((x, y, z)))
    for ring in range(latitudes):
        for segment in range(longitudes):
            a = ring * longitudes + segment
            b = ring * longitudes + (segment + 1) % longitudes
            faces.append((a, b, b + longitudes, a + longitudes))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    edge = outline(name + "_hand_sewn_edge", (0, 0, 0), 0.400, 0.400, 0.065,
                   seam_mat, "xy", 0.0035)
    edge.parent = obj
    obj.location = point(center)
    obj.rotation_euler = (math.radians(tilt), math.radians(twist), 0)
    return obj


def group_since(name, before):
    objects = [obj for obj in bpy.data.objects if obj.name not in before]
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for obj in objects:
        if obj.parent is None:
            obj.parent = root
    return root


before = set(bpy.data.objects.keys())
rounded_box("Sofa upholstered base", (0, 0.34, 0), (2.22, 0.36, 0.80), teal, 0.075)
rounded_box("Sofa back frame", (0, 0.83, 0.329), (2.23, 0.63, 0.215), teal, 0.085)
rounded_box("Sofa shadow welt below seats", (0, 0.535, -0.07), (1.88, 0.035, 0.66), dark_teal, 0.014)
for side in (-1, 1):
    rounded_box("Sofa rounded arm " + str(side), (side * 1.025, 0.63, 0),
                (0.2, 0.55, 0.81), teal, 0.075)
    outline("Arm stitched top " + str(side), (side * 1.025, 0.901, 0),
            0.12, 0.65, 0.05, seam_teal, thickness=0.003)
for index, x in enumerate((-0.61, 0, 0.61)):
    rounded_box("Seat cushion %d" % (index + 1), (x, 0.598, -0.064),
                (0.593, 0.132, 0.625), seat_teal, 0.052)
    outline("Seat cushion %d sewn perimeter" % (index + 1), (x, 0.614, -0.064),
            0.589, 0.620, 0.046, seam_teal, thickness=0.004)
    back = rounded_box("Back cushion %d" % (index + 1), (x, 0.864, 0.157),
                       (0.594, 0.465, 0.126), seat_teal, 0.057)
    # Front-face seam is inset into the soft edge, not an outline sticker.
    outline("Back cushion %d tailored seam" % (index + 1), (x, 0.864, 0.096),
            0.531, 0.405, 0.055, seam_teal, "xy", 0.0035)
for x in (-0.91, 0.91):
    for z in (-0.28, 0.28):
        foot("Sofa splayed walnut foot", (x * 1.025, 0.018, z * 1.06),
             (x, 0.215, z), 0.033, 0.047, walnut)
        foot("Sofa brass shoe", (x * 1.025, 0.015, z * 1.06),
             (x * 1.021, 0.054, z * 1.047), 0.034, 0.037, brass)
pillow("Guava throw pillow", (-0.69, 0.865, -0.094), coral, coral_piping, 14, -13)
pillow("Marigold throw pillow", (0.69, 0.851, -0.11), mustard, mustard_piping, 20, 14)
sofa = group_since("LivingSofa", before)

before = set(bpy.data.objects.keys())
# Origin is exactly the existing tabletop collider centre (world Y = 0.31).
rounded_box("Coffee table sculpted walnut lip", (0, -0.009, 0),
            (1.35, 0.102, 0.72), walnut, 0.047)
rounded_box("Coffee table honey oak surface", (0, 0.037, 0),
            (1.318, 0.046, 0.688), wood_top, 0.022)
# Actual geometry, not an external bitmap, gives discreet wood variation.
for index in range(7):
    z = -0.246 + index * 0.082
    points = []
    for step in range(17):
        x = -0.59 + step * 1.18 / 16
        wobble = math.sin(x * 7 + index * 2.1) * 0.007
        points.append((x, 0.0625, z + wobble))
    tube("Oak grain %02d" % index, points, 0.0014,
         wood_light if index % 2 else wood_dark)
for x in (-0.48, 0.48):
    for z in (-0.19, 0.19):
        foot("Coffee table splayed leg", (x * 1.14, -0.305, z * 1.28),
             (x, -0.033, z), 0.027, 0.048, walnut)
        foot("Coffee table brass shoe", (x * 1.14, -0.308, z * 1.28),
             (x * 1.116, -0.264, z * 1.23), 0.028, 0.032, brass)
table = group_since("LivingCoffeeTable", before)


def export(root, filename):
    bpy.ops.object.select_all(action="DESELECT")
    descendants = [root, *root.children_recursive]
    for obj in descendants:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(MODELS / filename),
                              export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False)
    triangles = sum(len(obj.data.loop_triangles) for obj in descendants if obj.type == "MESH")
    print("LIVING_ASSET", filename, "triangles", triangles)


export(sofa, "living_sofa.glb")
export(table, "living_coffee_table.glb")

# Source project also contains a non-exported neutral studio for asset review.
table.location = point((0, 0.31, -1.13))
rounded_box("Preview ground (not exported)", (0, -0.03, 0), (200, 0.06, 200),
            material("Studio warm paper", "E7D9C5"), 0.01)
world = bpy.data.worlds.new("Soft studio")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.23, 0.29, 0.32, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
for name, position, energy, size, color in (
    ("Large warm key", (-3, 5, -4), 450, 4, (1, 0.86, 0.70)),
    ("Soft cool fill", (3, 3, -1), 240, 3, (0.71, 0.87, 1)),
    ("Back rim", (1, 3.4, 3), 350, 3, (1, 0.90, 0.74)),
):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = energy, "DISK", size, color
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = point(position)
    obj.rotation_euler = (Vector(point((0, 0.45, -0.4))) - obj.location).to_track_quat("-Z", "Y").to_euler()
camera_data = bpy.data.cameras.new("Living room asset camera")
camera = bpy.data.objects.new("Living room asset camera", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = point((3.0, 2.25, -4.3))
camera.rotation_euler = (Vector(point((0, 0.5, -0.35))) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 3.8
scene = bpy.context.scene
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1400, 1050
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(QA / "living_room_asset_preview.png")
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "living_room.blend"))
if "--no-preview" not in sys.argv:
    bpy.ops.render.render(write_still=True)
