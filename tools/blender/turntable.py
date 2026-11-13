"""Turntable contact sheet for self-review of an asset (headless, Workbench; optional Eevee mood tile).

    python3 tools/blender/turntable.py <file.fbx|.glb|.gltf|.blend> [-o out.png] [--angles 8|4] [--size 384]
                                       [--mood] [--title NAME]

Sheet layout (one PNG):
  header   name, tris per object, dimensions in studs, extra info lines (gate result from build_asset)
  rows 1-2 turntable at 20 deg elevation, studio light + cavity + outline (8 angles; 4 angles = row 1 only): a SHAPE
           review only, it flatters (STUDIO_FIDELITY.md); judge the look on the Roblox-faithful tile
  row 3    top view | scale check beside a 5-stud R15-size mannequin (Tape Grey) | wireframe | flat albedo
           (FLAT light = the "reads with shadows off" check for phones at quality 1-3)
  footer   black silhouettes at 64 px from every angle (rubric V1), the same at 2x, and the Eevee mood tile
           replaced by the Roblox-faithful tile (roblox_look.py: the game's Lighting values) when --mood is given

Runs on the pip `bpy` module (Python 3.13) or inside Blender. Needs Mesa EGL on a GPU-less Linux box
(apt-get install libegl1 libegl-mesa0 libgl1-mesa-dri). Uses Pillow for the sheet when available.
"""
import argparse, math, os, shutil, sys, tempfile
import bpy
from mathutils import Vector

BG = (0.105, 0.11, 0.135)          # linear; about #5A5C66, neutral cool mid grey
MANNEQUIN_RGB = (0.258, 0.275, 0.392, 1.0)   # Tape Grey #8A8FA8, linear


def _srgb(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def mesh_objects(objs=None):
    objs = objs or [o for o in bpy.context.scene.objects if o.type == "MESH"]
    return [o for o in objs if o.type == "MESH"]


def tri_count(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    n = sum(len(p.vertices) - 2 for p in me.polygons)
    ob.evaluated_get(dg).to_mesh_clear()
    return n


def bounds(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


class Rig:
    def __init__(self, scene, lens=60.0):
        self.s = scene
        cd = bpy.data.cameras.new("EH_TT_Cam"); cd.lens = lens; cd.sensor_width = 36
        cd.clip_start = 0.01; cd.clip_end = 10000
        self.cam = bpy.data.objects.new("EH_TT_Cam", cd)
        scene.collection.objects.link(self.cam)
        scene.camera = self.cam
        self.fov = 2 * math.atan(18 / lens)

    def aim(self, lo, hi, az_deg, el_deg, margin=1.08):
        ctr = (lo + hi) / 2
        rad = max((hi - lo).length / 2, 1e-3)
        dist = rad / math.sin(self.fov / 2) * margin
        az, el = math.radians(az_deg), math.radians(el_deg)
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
        self.cam.location = ctr + d * dist
        up = "Y" if el_deg < 89 else "Y"
        self.cam.rotation_euler = (ctr - self.cam.location).to_track_quat("-Z", up).to_euler()

    def remove(self):
        bpy.data.objects.remove(self.cam, do_unlink=True)


def _workbench(s, mode):
    s.render.engine = "BLENDER_WORKBENCH"
    sh = s.display.shading
    sh.show_backface_culling = False
    sh.show_xray = False
    if mode == "studio":
        sh.light = "STUDIO"; sh.color_type = "TEXTURE"
        sh.studio_light = "paint.sl"       # truest palette read of the built-in studio lights
        sh.show_cavity = True; sh.cavity_type = "WORLD"
        sh.cavity_ridge_factor = 1.0; sh.cavity_valley_factor = 1.0
        sh.show_object_outline = True; sh.object_outline_color = (0.02, 0.02, 0.03)
        sh.show_specular_highlight = True
        sh.show_shadows = False            # Workbench shadows read as ghosting; the art must read without them
        s.world.color = BG
    elif mode == "flat":
        sh.light = "FLAT"; sh.color_type = "TEXTURE"
        sh.show_cavity = False; sh.show_shadows = False; sh.show_specular_highlight = False
        sh.show_object_outline = True
        s.world.color = BG
    elif mode == "wire":
        sh.light = "STUDIO"; sh.color_type = "OBJECT"
        sh.show_cavity = False; sh.show_shadows = False; sh.show_object_outline = False
        sh.show_specular_highlight = False
        s.world.color = BG
    elif mode == "silhouette":
        sh.light = "FLAT"; sh.color_type = "SINGLE"; sh.single_color = (0, 0, 0)
        sh.show_cavity = False; sh.show_shadows = False; sh.show_object_outline = False
        sh.show_specular_highlight = False
        s.world.color = (1, 1, 1)


def _render(s, path, size):
    s.render.resolution_x = s.render.resolution_y = size
    s.render.resolution_percentage = 100
    s.render.film_transparent = False
    s.render.image_settings.file_format = "PNG"
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def _mannequin(lo, hi):
    """A 5.2-stud R15-size block figure (legs 2, torso 2, head 1.2) left of the asset, Tape Grey."""
    m = bpy.data.materials.new("EH_TT_Mannequin")
    try:
        m.use_nodes = True
    except Exception:
        pass
    m.diffuse_color = MANNEQUIN_RGB
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.node_tree else None
    if b:
        b.inputs["Base Color"].default_value = MANNEQUIN_RGB
    x = lo.x - 1.6
    y = (lo.y + hi.y) / 2
    parts = [((x - 0.5, y, 1.0), (0.45, 0.45, 1.0)), ((x + 0.5, y, 1.0), (0.45, 0.45, 1.0)),
             ((x, y, 3.0), (1.0, 0.5, 1.0)), ((x - 1.5, y, 3.0), (0.45, 0.45, 1.0)),
             ((x + 1.5, y, 3.0), (0.45, 0.45, 1.0)), ((x, y, 4.6), (0.6, 0.6, 0.6))]
    obs = []
    for loc, half in parts:
        bpy.ops.mesh.primitive_cube_add(size=2, location=loc)
        o = bpy.context.active_object
        o.scale = half
        o.data.materials.append(m)
        o.color = MANNEQUIN_RGB
        obs.append(o)
    return obs


def _wire_copies(objs, rad):
    out = []
    for o in objs:
        c = o.copy(); c.data = o.data.copy(); c.name = o.name + "_ttwire"
        bpy.context.scene.collection.objects.link(c)
        w = c.modifiers.new("wire", "WIREFRAME")
        w.thickness = max(rad * 0.004, 0.006); w.use_replace = True; w.use_even_offset = True
        c.color = (0.02, 0.02, 0.04, 1)
        out.append(c)
    return out


def _faithful(s, objs, lo, hi, rig, path, size):
    """The Roblox-faithful tile (roblox_look, docs/audit/STUDIO_FIDELITY.md): the game's Lighting values, the atlas
    with bilinear filtering x MeshPart.Color, SmoothPlastic, the FBX's own normals, no AO / outline / cavity. Runs
    last: it replaces the objects' materials."""
    import roblox_look as RL
    made = RL.apply(s, objs)
    rig.aim(lo, hi, 35, 24)
    RL.aim_sun(made, rig.cam.location, (lo + hi) / 2)
    ctr = (lo + hi) / 2
    rad = max((hi - lo).length / 2, 0.5)
    bpy.ops.mesh.primitive_plane_add(size=rad * 12, location=(ctr.x, ctr.y, lo.z - 0.002))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("EH_TT_Ground")
    try:
        fm.use_nodes = True
    except Exception:
        pass
    fb = next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    fb.inputs["Base Color"].default_value = (0.03, 0.03, 0.045, 1)
    fl.data.materials.append(fm)
    made.append(fl)
    try:
        _render(s, path, size)
        RL.grade(path)
    finally:
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)
        s.view_settings.view_transform = "Standard"
        s.render.engine = "BLENDER_WORKBENCH"
    return path


def _mood(s, objs, lo, hi, rig, path, size):
    """(Old, flattering) Eevee tile approximating the Heist Night recipe: indigo world, warm key, cool rim, dark
    floor. Not used by the sheet any more (STUDIO_FIDELITY: it lied); kept for one-off comparisons."""
    s.render.engine = "BLENDER_EEVEE"
    try:
        s.eevee.taa_render_samples = 16
    except Exception:
        pass
    w = s.world
    w.use_nodes = True
    bgn = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bgn.inputs["Color"].default_value = (_srgb(55 / 255), _srgb(55 / 255), _srgb(95 / 255), 1)
    bgn.inputs["Strength"].default_value = 0.9
    ctr = (lo + hi) / 2
    rad = max((hi - lo).length / 2, 0.5)
    made = []
    for name, col, energy, d in (("key", (1.0, 0.82, 0.63), 900, Vector((-0.6, -0.9, 1.1))),
                                 ("rim", (0.55, 0.6, 1.0), 500, Vector((0.9, 1.0, 0.6)))):
        ld = bpy.data.lights.new("EH_TT_" + name, "AREA"); ld.color = col
        ld.energy = energy * rad * rad / 4; ld.size = rad * 1.5
        lo_ = bpy.data.objects.new("EH_TT_" + name, ld)
        s.collection.objects.link(lo_)
        lo_.location = ctr + d.normalized() * rad * 3.5
        lo_.rotation_euler = (ctr - lo_.location).to_track_quat("-Z", "Y").to_euler()
        made.append(lo_)
    bpy.ops.mesh.primitive_plane_add(size=rad * 12, location=(ctr.x, ctr.y, lo.z - 0.002))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("EH_TT_Floor")
    try:
        fm.use_nodes = True
    except Exception:
        pass
    fb = next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    fb.inputs["Base Color"].default_value = (_srgb(0x1C / 255), _srgb(0x1F / 255), _srgb(0x3B / 255), 1)
    fb.inputs["Roughness"].default_value = 0.8
    fl.data.materials.append(fm)
    made.append(fl)
    rig.aim(lo, hi, 35, 24)
    try:
        _render(s, path, size)
    finally:
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)
        w.use_nodes = False
        s.render.engine = "BLENDER_WORKBENCH"
    return path


def render_contact_sheet(out_path, objs=None, angles=8, size=384, title=None, info=(), mood=False):
    """Renders the sheet for `objs` (default: every mesh in the scene) and returns out_path."""
    s = bpy.context.scene
    if s.world is None:
        s.world = bpy.data.worlds.new("EH_World")
    s.view_settings.view_transform = "Standard"
    objs = mesh_objects(objs)
    if not objs:
        raise SystemExit("turntable: no mesh objects")
    glass = []
    for o in objs:   # glass parts (Studio: Glass material, Transparency 0.6-0.7) draw as their edges, not as solid slabs
        if o.name.endswith(("_Glass", "_Case")):
            m = o.modifiers.new("eh_glass", "WIREFRAME")
            m.thickness = 0.04; m.use_replace = True; m.use_even_offset = True
            glass.append((o, m))
    hidden = [o for o in s.objects if o not in objs and o.type in {"MESH", "CURVE"} and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    tmp = tempfile.mkdtemp(prefix="eh_tt_")
    lo, hi = bounds(objs)
    rad = (hi - lo).length / 2
    rig = Rig(s)
    azs = [i * 360 / angles for i in range(angles)]
    tiles = {}
    try:
        _workbench(s, "studio")
        for az in azs:
            rig.aim(lo, hi, az, 20)
            tiles[f"az{int(az)}"] = _render(s, os.path.join(tmp, f"az{int(az)}.png"), size)
        rig.aim(lo, hi, 0.01, 89.5)
        tiles["top"] = _render(s, os.path.join(tmp, "top.png"), size)
        man = _mannequin(lo, hi)
        mlo, mhi = bounds(objs + man)
        rig.aim(mlo, mhi, 0, 8)
        tiles["scale"] = _render(s, os.path.join(tmp, "scale.png"), size)
        for o in man:
            bpy.data.objects.remove(o, do_unlink=True)
        _workbench(s, "flat")
        rig.aim(lo, hi, 35, 24)
        tiles["flat"] = _render(s, os.path.join(tmp, "flat.png"), size)
        wires = _wire_copies(objs, rad)
        old_cols = [tuple(o.color) for o in objs]
        for o in objs:
            o.color = (0.78, 0.79, 0.84, 1)
        _workbench(s, "wire")
        rig.aim(lo, hi, 35, 24)
        tiles["wire"] = _render(s, os.path.join(tmp, "wire.png"), size)
        for o in wires:
            bpy.data.objects.remove(o, do_unlink=True)
        for o, c in zip(objs, old_cols):
            o.color = c
        _workbench(s, "silhouette")
        sil = []
        for az in (azs if angles == 8 else [i * 45 for i in range(8)]):
            rig.aim(lo, hi, az, 20, margin=1.0)
            sil.append(_render(s, os.path.join(tmp, f"sil{int(az)}.png"), 64))
        tiles["sil"] = sil
        if mood:
            _workbench(s, "studio")
            tiles["mood"] = _faithful(s, objs, lo, hi, rig, os.path.join(tmp, "mood.png"), size)
    finally:
        rig.remove()
        for o in hidden:
            o.hide_render = False
        for o, m in glass:
            o.modifiers.remove(m)
    head = [title or objs[0].name]
    head.append("  |  ".join(f"{o.name}: {tri_count(o)} tris" for o in objs) +
                f"  |  total {sum(tri_count(o) for o in objs)} tris")
    d = hi - lo
    head.append(f"bounds {d.x:.2f} x {d.y:.2f} x {d.z:.2f} studs (X x Y x Z, Blender Z-up; Roblox Y-up)")
    head += list(info)
    _compose(out_path, tiles, angles, size, head)
    shutil.rmtree(tmp, ignore_errors=True)
    return out_path


def _compose(out_path, tiles, angles, T, head):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("turntable: Pillow missing, writing the tiles next to the sheet path instead")
        base = os.path.splitext(out_path)[0]
        for k, v in tiles.items():
            for i, p in enumerate(v if isinstance(v, list) else [v]):
                shutil.copy(p, f"{base}_{k}{i if isinstance(v, list) else ''}.png")
        return
    def font(sz):
        for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/freefont/FreeSans.ttf"):
            if os.path.isfile(f):
                return ImageFont.truetype(f, sz)
        return ImageFont.load_default()
    f_big, f_small = font(20), font(13)
    cols = 4
    rows_tt = 2 if angles == 8 else 1
    head_h = 16 + 22 + 18 * (len(head) - 1)
    foot_h = max(T if "mood" in tiles else 0, 64 + 128 + 48)
    W, H = cols * T, head_h + (rows_tt + 1) * T + foot_h
    sheet = Image.new("RGB", (W, H), (24, 25, 36))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 8), head[0], fill=(244, 247, 255), font=f_big)
    for i, line in enumerate(head[1:]):
        col = (255, 120, 120) if "FAIL" in line else (200, 205, 225)
        dr.text((10, 36 + 18 * i), line, fill=col, font=f_small)
    def put(path, x, y, label):
        im = Image.open(path).convert("RGB")
        sheet.paste(im, (x, y))
        dr.rectangle([x, y, x + 8 + 7 * len(label), y + 18], fill=(24, 25, 36))
        dr.text((x + 4, y + 2), label, fill=(220, 224, 240), font=f_small)
    names = [k for k in tiles if k.startswith("az")]
    for i, k in enumerate(names):
        put(tiles[k], (i % cols) * T, head_h + (i // cols) * T, f"{k[2:]} deg")
    y3 = head_h + rows_tt * T
    for i, (k, lab) in enumerate((("top", "top"), ("scale", "scale: 5-stud R15"), ("wire", "wireframe"),
                                   ("flat", "flat albedo (no shadows)"))):
        put(tiles[k], i * T, y3, lab)
    yf = y3 + T
    dr.text((10, yf + 6), "silhouettes 64 px (V1), then 2x", fill=(200, 205, 225), font=f_small)
    big = max(64, min(128, (W - (T if "mood" in tiles else 0) - 20) // 8 - 6))   # 2x strip fits the sheet
    for i, p in enumerate(tiles["sil"]):
        im = Image.open(p).convert("RGB")
        sheet.paste(im, (10 + i * 70, yf + 26))
        sheet.paste(im.resize((big, big), Image.NEAREST), (10 + i * (big + 6), yf + 26 + 70))
    if "mood" in tiles:
        put(tiles["mood"], W - T, yf, "Roblox-faithful (the game's look)")
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    # 256-colour palette keeps a sheet near 250 KB instead of ~900 KB (repo size); flat colours survive intact.
    sheet.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(out_path, optimize=True)


def load_file(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=path)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        if ext == ".fbx":
            bpy.ops.import_scene.fbx(filepath=path)
        elif ext in (".glb", ".gltf"):
            bpy.ops.import_scene.gltf(filepath=path)
        elif ext == ".obj":
            bpy.ops.wm.obj_import(filepath=path)
        else:
            raise SystemExit(f"turntable: unsupported file {path}")
    s = bpy.context.scene
    if s.world is None:
        s.world = bpy.data.worlds.new("EH_World")
    return mesh_objects()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("input")
    ap.add_argument("-o", "--out")
    ap.add_argument("--angles", type=int, default=8, choices=(4, 8))
    ap.add_argument("--size", type=int, default=384)
    ap.add_argument("--mood", action="store_true")
    ap.add_argument("--title")
    a = ap.parse_args(argv)
    objs = load_file(os.path.abspath(a.input))
    out = a.out or os.path.splitext(a.input)[0] + "_turntable.png"
    render_contact_sheet(out, objs, a.angles, a.size, a.title or os.path.basename(a.input), mood=a.mood)
    print("turntable:", os.path.abspath(out))


if __name__ == "__main__":
    main(sys.argv[1:] if "--" not in sys.argv else sys.argv[sys.argv.index("--") + 1:])
