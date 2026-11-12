"""Kit preview: the exported FBX kit pieces side by side in a small golden-room vignette (V8 "matches the kit").

    python3 tools/blender/kit_preview.py [-o docs/art/turntables/KitPreview.png]

Imports assets/fbx/*.fbx at the LAYOUT positions, adds placeholder dark displays (loot never sits on Warm Marble:
STYLE_BIBLE display rule), a 5-stud mannequin and Heist Night lights, then renders the STYLE_BIBLE camera
bookmarks B1 (diorama 3/4) and B2 (player eye) in Eevee plus B1 as flat albedo in Workbench (no-shadow read).
Placeholder boxes are drawn in Tape Grey / Ink and are not kit pieces.
"""
import argparse, math, os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import turntable as tt  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
FBX = os.path.join(REPO, "assets", "fbx")

# (fbx name, offset in studs, Blender Z-up). Wall line on y 0..2, room in front (y < 0).
LAYOUT = [
    ("Bank_Wall_8x12", (-8, 0, 0)), ("Bank_Wall_4x12", (0, 0, 0)), ("VaultDoor_Greybox", (4, 0, 0)),
    ("Bank_Wall_4x12", (20, 0, 0)), ("Bank_Wall_8x12", (24, 0, 0)),
    ("GoldStack", (5, -8, 3.0)), ("GoldBar", (2.2, -8.6, 3.0)), ("Diamond", (20, -8, 4.4)),
]
DISPLAYS = [((0.5, -10.5, 0), (8.5, -6.0, 3.0), "#2A2D52"),      # table under the gold (Ink Indigo light)
            ((18.6, -9.4, 0), (21.4, -6.6, 3.2), "#4E5675")]     # pedestal under the diamond (Vault Steel shade)
BOOKMARKS = {  # name: (target, azimuth deg, elevation deg, distance, vertical FOV deg)
    "B1 diorama 3/4": ((12, -4, 3.5), 28, 38, 46, 40),
    "B2 player eye": ((12, -2, 4.5), 8, 14, 24, 70),
}


def _lin(h):
    h = h.lstrip("#")
    return tuple(tt._srgb(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def _mat(name, rgba):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Roughness"].default_value = 0.8
    m.diffuse_color = rgba
    return m


def _box(lo, hi, mat):
    lo, hi = Vector(lo), Vector(hi)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(lo + hi) / 2)
    o = bpy.context.active_object
    o.scale = hi - lo
    o.data.materials.append(mat)
    o.color = mat.diffuse_color
    return o


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.world = bpy.data.worlds.new("EH_World")
    s.view_settings.view_transform = "Standard"
    kit = []
    for name, off in LAYOUT:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(FBX, name + ".fbx"))
        for o in set(bpy.data.objects) - before:
            o.location += Vector(off)
            kit.append(o)
    floor = _box((-10, -24, -0.2), (34, 2, 0), _mat("Floor", _lin("#2E2A50")))
    props = [_box(lo, hi, _mat("Display", _lin(c))) for lo, hi, c in DISPLAYS]
    man = tt._mannequin(Vector((12.5, -5, 0)), Vector((12.5, -5, 0)))
    return s, kit, [floor] + props + man


def lights(s):
    w = s.world
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = _lin("#373760")
    bg.inputs["Strength"].default_value = 0.8
    made = []
    for name, kind, loc, col, energy, size in (
            ("vault_spot", "SPOT", (12, -9, 15), "#FFD2A0", 9000, 0),
            ("pool_gold", "POINT", (5, -8, 9), "#FFD2A0", 2500, 0),
            ("pool_diamond", "POINT", (20, -8, 9), "#FFE6C8", 1800, 0),
            ("fill", "AREA", (-6, -20, 14), "#8C96FF", 3000, 12)):
        ld = bpy.data.lights.new(name, kind)
        ld.color = _lin(col)[:3]; ld.energy = energy
        if kind == "SPOT":
            ld.spot_size = math.radians(70); ld.spot_blend = 0.6
        if kind == "AREA":
            ld.size = size
        o = bpy.data.objects.new(name, ld)
        s.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector((12, -3, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        made.append(o)
    return made


def aim(cam, target, az, el, dist, vfov, W, H):
    t = Vector(target)
    a, e = math.radians(az), math.radians(el)
    cam.location = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(vfov)


def render(out, W=1280, H=720):
    s, kit, extra = build_scene()
    cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam); s.camera = cam
    s.render.resolution_x, s.render.resolution_y = W, H
    tmp = tempfile.mkdtemp(prefix="eh_kit_")
    shots = []
    made = lights(s)
    s.render.engine = "BLENDER_EEVEE"
    try:
        s.eevee.taa_render_samples = 24
    except Exception:
        pass
    for name, (t, az, el, d, fov) in BOOKMARKS.items():
        aim(cam, t, az, el, d, fov, W, H)
        p = os.path.join(tmp, name[:2] + ".png")
        s.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append((p, name + " (Eevee, Heist Night approximation)"))
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
    s.world.use_nodes = False
    tt._workbench(s, "flat")
    t, az, el, d, fov = BOOKMARKS["B1 diorama 3/4"]
    aim(cam, t, az, el, d, fov, W, H)
    p = os.path.join(tmp, "flat.png"); s.render.filepath = p
    bpy.ops.render.render(write_still=True)
    shots.append((p, "B1 flat albedo (Workbench): the no-shadow phone read"))
    from PIL import Image, ImageDraw, ImageFont
    fp = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font = ImageFont.truetype(fp, 15) if os.path.isfile(fp) else ImageFont.load_default()
    sheet = Image.new("RGB", (W, H * 2 + H // 2 + 40), (24, 25, 36))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 10), "Echo Heist kit preview: golden assets side by side (placeholders: grey mannequin, dark display boxes)",
            fill=(230, 232, 245), font=font)
    y = 40
    for i, (p, label) in enumerate(shots):
        im = Image.open(p).convert("RGB")
        if i == 2:
            im = im.resize((W // 2, H // 2))
        sheet.paste(im, (0, y)); dr.rectangle([0, y, 10 + 8 * len(label), y + 22], fill=(24, 25, 36))
        dr.text((4, y + 3), label, fill=(230, 232, 245), font=font)
        y += im.size[1]
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(out, optimize=True)
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", default=os.path.join(REPO, "docs", "art", "turntables", "KitPreview.png"))
    a = ap.parse_args()
    print("kit preview:", render(a.out))
