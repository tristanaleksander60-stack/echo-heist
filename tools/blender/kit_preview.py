"""Kit preview: the exported FBX kit assembled into small diorama rooms, one per location, with the Christmas dressing
layer off and on (V8 "matches the kit"; the owner's daily screenshot slot stand-in, STYLE_BIBLE 7).

    python3 tools/blender/kit_preview.py [--only CornerShop|Bank|ToyShop|Street|BankStreet|Tree] [--size 960]

Writes docs/art/turntables/KitPreview_<Scene>.png (CornerShop, Bank, ToyShop, Street, BankStreet, Tree: the decorated
advent tree) and the index KitPreview.png (the B1 tiles). Single renders go to a temp folder (never committed). Every piece is imported from assets/fbx/*.fbx exactly as exported;
the location look is the ATLAS SWAP the game does (the kit material's image is replaced by
assets/textures/EH_Palette_<Location>.png). Runtime-tinted parts get their code colour from kit_manifest.json:
Neon parts glow (Eevee emission; Studio bloom does this in game), glass is see-through.
Placeholders (not kit pieces, drawn in Tape Grey or as thin emissive bars): the 5-stud mannequin and the laser
beams (code draws those). Cameras: B1 diorama 3/4 and B2 player eye (STYLE_BIBLE 7), plus flat albedo in Workbench
from B1 (the no-shadow phone read) and from B3 (the top-down planning view, where counters must read on the floor).
"""
import argparse, json, math, os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import turntable as tt  # noqa: E402
import eh_palette as P  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
FBX = os.path.join(REPO, "assets", "fbx")
OUT = os.path.join(REPO, "docs", "art", "turntables")
MANIFEST = json.load(open(os.path.join(FBX, "kit_manifest.json")))["parts"]

# Code colours for runtime-tinted parts in the preview: the idle colours of eh_palette.NEON (the prepare script's), with
# a P1 clone holding the plate and the switch so the clone hue shows, and Gus's torch on.
TINT = {part: idle for part, (idle, _what, _fixed) in P.NEON.items()}
TINT.update({"Plate_4x4_Ring": "#3DE8FF", "Switch_Wall_Lamp": "#3DE8FF", "Gus_FlashlightLens": "#FFD27A"})

# ------------------------------------------------------------------ scenes
# Each entry: (model, (x, y, z), rot_z_deg, flags). Blender axes (front -Y). flags: "xmas" = only with the dressing on,
# "base" = only off, "hide:<Part>" hides one part, "only:<Part>" keeps one part, "origin" puts the part's own origin
# at the position (ornaments on tree hooks), "scale:<f>" scales it there, "tint:#RRGGBB" multiplies a tintable part's
# atlas colour (MeshPart.Color).
# Walls follow STYLE_BIBLE 5.2: every wall module is CENTRED on its grid line (a back wall on y = 0 spans y -1..1, a
# side wall on x = 0 spans x -1..1) and a Pillar_2x12 is centred on each outside corner.

def _room(back, left_n=3):
    """Shell of a cut-away room: floor x 0..32, y -24..0, back wall centred on y = 0, left wall centred on x = 0."""
    out = [("Floor_8x8", (x, y, 0), 0, ()) for x in (0, 8, 16, 24) for y in (-24, -16, -8)]
    x = 0
    for name, w in back:
        out.append((name, (x, -1, 0), 0, ()))
        x += w
    out.append(("Pillar_2x12", (x - 1, -1, 0), 0, ()))
    out.append(("Pillar_2x12", (-1, -1, 0), 0, ()))
    for i in range(left_n):
        out.append(("Wall_8x12", (1, -8 * (i + 1), 0), 90, ()))
    out.append(("Pillar_2x12", (-1, -8 * left_n - 1, 0), 0, ()))
    return out


def _dress_walls(cells):
    """Christmas dressing on wall cells (same placement as the module it dresses): garland + lights under the crown,
    snow on the cut-away tops."""
    out = []
    for name, pos, rot, kind in cells:
        if "garland" in kind:
            out.append(("Xmas_Garland_8", pos, rot, ("xmas",)))
        if "lights" in kind:
            out.append(("Xmas_Lights_8", pos, rot, ("xmas",)))
        if "snow" in kind:
            out.append(("Xmas_SnowCap_8", pos, rot, ("xmas",)))
    return out


BACK = lambda x: (x, -1, 0)                        # noqa: E731  a back-wall module's placement
LEFT = lambda i: (1, -8 * (i + 1), 0)              # noqa: E731  a left-wall module's placement

SHOP = _room([("Wall_Window_8x12", 8), ("Wall_8x12", 8), ("Wall_Door_8x12", 8), ("Wall_8x12", 8)]) + [
    ("Shelf_8x2", (3, -18, 0), 90, ()), ("Counter_8x4", (20, -15, 0), 0, ()), ("Counter_4x4", (28, -15, 0), 0, ()),
    ("CashRegister", (24.5, -13, 3.5), 0, ()), ("Gus_DonutBox", (29.9, -13, 3.5), 0, ()),
    ("Plate_4x4", (9, -14, 0), 0, ()), ("Switch_Wall", (12, -0.7, 0), 0, ()),
    ("Lamp_Ceiling", (10, -10, 0), 0, ()), ("Lamp_Ceiling", (24, -9, 0), 0, ()),
    ("Hide_Plant", (27, -4.6, 0), 0, ()), ("Plate_4x4", (27, -4.6, 0), 0, ()), ("Hide_Crate", (5.5, -3.6, 0), 0, ()),
    ("Safe", (29.5, -20.5, 0), -20, ()),
    ("LaserEmitter", (16.5, -6.5, 0), -90, ("base",)), ("LaserEmitter", (32.0, -6.5, 0), 90, ("base",)),
    ("LaserEmitter_CandyCane", (16.5, -6.5, 0), -90, ("xmas",)), ("LaserEmitter_CandyCane", (32.0, -6.5, 0), 90, ("xmas",)),
    ("LaserEmitter", (16.5, -6.5, 0), -90, ("xmas", "only:LaserEmitter_Lens")), ("LaserEmitter", (32.0, -6.5, 0), 90, ("xmas", "only:LaserEmitter_Lens")),
    ("CashBag", (11, -4, 0), 20, ()), ("Gus", (14, -9, 0), -25, ("hide:Gus_Cap@xmas",)),
    ("Gus_SantaHat", (14, -9, 0), -25, ("xmas", "attach:Gus")),
    ("Xmas_Tree", (21, -4.5, 0), 0, ("xmas",)), ("Xmas_Wreath", (20, -0.38, 7.0), 0, ("xmas",)),
] + _dress_walls([("w", BACK(0), 0, "garland snow"), ("w", BACK(8), 0, "garland snow"), ("w", BACK(16), 0, "snow"),
                  ("w", BACK(24), 0, "lights snow")] + [("w", LEFT(i), 90, "snow lights" if i == 1 else "snow") for i in range(3)])
SHOP_BEAMS = ((16.5 + 1.15, 32.0 - 1.15, -6.5), )   # placeholder laser beams between the facing lenses

BANK = _room([("Wall_8x12", 8), ("VaultDoor", 16), ("Wall_8x12", 8)]) + [
    ("TellerCounter_8x4", (3, -20, 0), 0, ()), ("Counter_4x4", (12, -15, 0), 0, ()),
    ("GoldStack", (14, -13, 3.5), 0, ()), ("GoldBar", (13.2, -14.2, 3.5), 25, ()),
    ("Pedestal_Diamond", (25, -11, 0), 0, ()), ("Diamond", (25, -11, 4.65), 0, ()),
    ("Hide_DepositStack", (27, -19.5, 0), 0, ()), ("Plate_4x4", (27, -19.5, 0), 0, ()), ("Plate_4x4", (16, -6, 0), 0, ()),
    ("Lamp_Ceiling", (9, -11, 0), 0, ()), ("Lamp_Ceiling", (24, -11, 0), 0, ()),
    ("Hide_Curtain", (0.7, -12, 0), 90, ()), ("Hide_CoatRack", (6.5, -4.4, 0), 0, ()), ("Plate_4x4", (6.5, -4.4, 0), 0, ()),
    ("Gus", (19, -16, 0), 20, ("hide:Gus_Cap@xmas",)), ("Gus_SantaHat", (19, -16, 0), 20, ("xmas", "attach:Gus")),
    ("GiantPresent", (8, -12, 0), 15, ("xmas",)), ("Xmas_Tree", (29, -4, 0), 0, ("xmas",)),
    ("Xmas_Wreath", (0.7, -4, 7.5), 90, ("xmas",)),
] + _dress_walls([("w", BACK(0), 0, "garland lights snow"), ("w", BACK(24), 0, "garland lights snow")] +
                 [("w", LEFT(i), 90, "snow lights" if i == 1 else "snow") for i in range(3)])

# The Toy Shop (Drop 1) on its own atlas: Clone Party's aisle units (Shelf_Gondola_8x2, two per row), the new loot on
# the dark boards, the coat stand, the plant niche over a plate.
TOYS = [("Toy", 0.45), ("Teddy", 2.25), ("Candy", 4.05)]   # on the board tops (Shelf_Gondola SHELF_Z), east faces
TOY_SHOP = _room([("Wall_8x12", 8), ("Wall_Window_8x12", 8), ("Wall_8x12", 8), ("Wall_8x12", 8)]) + [
    ("Shelf_Gondola_8x2", (12, -21, 0), 90, ()), ("Shelf_Gondola_8x2", (12, -13, 0), 90, ()),
    ("Shelf_Gondola_8x2", (22, -21, 0), 90, ()), ("Shelf_Gondola_8x2", (22, -13, 0), 90, ()),
    ("Counter_8x4", (2, -22, 0), 0, ()), ("CashRegister", (6, -20, 3.5), 0, ()),
    ("Hide_CoatStand", (29, -19, 0), 0, ()), ("Hide_Plant", (5, -6, 0), 0, ()), ("Plate_4x4", (5, -6, 0), 0, ()),
    ("Present", (16, -4, 0), 20, ()), ("Present", (17.8, -3.2, 0), -10, ()), ("Candy", (28, -6, 0), 30, ()),
    ("Lamp_Ceiling", (16, -10, 0), 0, ()), ("Gus", (27, -11, 0), -40, ("hide:Gus_Cap@xmas",)),
    ("Gus_SantaHat", (27, -11, 0), -40, ("xmas", "attach:Gus")), ("Xmas_Tree", (30, -4, 0), 0, ("xmas",)),
] + [(name, (x - 0.65, y, z), 90, ()) for x in (12, 22) for (name, z), y in zip(TOYS, (-15.5, -11.5, -18.5))] + _dress_walls(
    [("w", BACK(0), 0, "garland lights snow"), ("w", BACK(8), 0, "garland snow"), ("w", BACK(16), 0, "garland lights snow")] +
    [("w", LEFT(i), 90, "snow") for i in range(3)])

STREET = [("Floor_8x8", (x, y, 0), 0, ()) for x in (-16, -8, 0, 8) for y in (-24, -16, -8)] + [
    ("Wall_4x12", (-16, -1, 0), 0, ()), ("Storefront_24x12", (-12, -1, 0), 0, ()), ("Wall_4x12", (12, -1, 0), 0, ()),
    ("Pillar_2x12", (-17, -1, 0), 0, ()), ("Pillar_2x12", (15, -1, 0), 0, ()),
    ("Shutter_8x10", (0, 0, 10.35), 0, ("xmas",)),          # LOCKDOWN: the shutter is down in the second tile
    ("Van", (-1, -17, 0), 180, ()), ("CashBag", (6, -9, 0), -30, ()), ("Present", (-5, -8, 0), 15, ("xmas",)),
    ("Xmas_SnowPile", (-12, -6, 0), 10, ("xmas",)), ("Xmas_SnowPile", (11, -5, 0), -20, ("xmas",)),
    ("Xmas_Wreath", (-14, -0.7, 7.0), 0, ("xmas",)), ("Xmas_Wreath", (14, -0.7, 7.0), 0, ("xmas",)),
    ("Xmas_Lights_8", (-12, -1, 0), 0, ("xmas",)), ("Xmas_Lights_8", (4, -1, 0), 0, ("xmas",)),
    ("Xmas_SnowCap_8", (-16, -1, 0), 0, ("xmas",)), ("Xmas_SnowCap_8", (-8, -1, 0), 0, ("xmas",)), ("Xmas_SnowCap_8", (0, -1, 0), 0, ("xmas",)),
    ("Xmas_SnowCap_8", (8, -1, 0), 0, ("xmas",)),
]

BANK_STREET = [("Floor_8x8", (x, y, 0), 0, ()) for x in (-20, -12, -4, 4, 12) for y in (-24, -16, -8)] + [
    ("Wall_8x12", (-20, -1, 0), 0, ()), ("BankFront_24x12", (-12, -1, 0), 0, ()), ("Wall_8x12", (12, -1, 0), 0, ()),
    ("Pillar_2x12", (-21, -1, 0), 0, ()), ("Pillar_2x12", (19, -1, 0), 0, ()),
    ("Shutter_8x10", (0, 0, 10.35), 0, ("xmas",)),
    ("Van", (-1, -17, 0), 180, ()), ("GoldBar", (6, -9, 0), -30, ()),
    ("Xmas_SnowPile", (-14, -6, 0), 10, ("xmas",)), ("Xmas_Wreath", (-16, -0.7, 7.0), 0, ("xmas",)),
    ("Xmas_Wreath", (16, -0.7, 7.0), 0, ("xmas",)), ("Xmas_SnowCap_8", (-20, -1, 0), 0, ("xmas",)),
    ("Xmas_SnowCap_8", (12, -1, 0), 0, ("xmas",)), ("Xmas_Garland_8", (-20, -1, 0), 0, ("xmas",)),
    ("Xmas_Garland_8", (12, -1, 0), 0, ("xmas",)),
]


def _tree_layout():
    """The van's advent tree with all 22 ornaments on its hooks, each with its day's mesh and colour (ORNAMENT_DAYS)."""
    hooks = MANIFEST["Xmas_Tree"]["hooks"]
    out = [("Xmas_Tree", (0, 0, 0), 0, ()), ("Floor_8x8", (-4, -4, 0), 0, ())]
    scale = MANIFEST["Xmas_Tree"].get("ornamentScale", 1.0)
    for (day, mesh, tint), (rx, ry, rz) in zip(P.ORNAMENT_DAYS, hooks):
        flags = ["only:" + mesh, "origin", f"scale:{scale}"] + ([f"tint:{P.ORNAMENT_TINTS[tint]}"] if tint else [])
        out.append(("Ornaments", (-rx, rz, ry), 0, tuple(flags)))   # Roblox (x, y, z) -> Blender (-x, z, y)
    return out


SCENES = {   # name: (layout, atlas, beams, camera target, mannequin position, Christmas variants, shots, cameras)
    "CornerShop": (SHOP, "CornerShop", SHOP_BEAMS, (16, -10, 3.5), (6.5, -13), (False, True), None, None),
    "Bank": (BANK, "Bank", (), (16, -10, 3.6), (12.5, -6), (False, True), None, None),
    "ToyShop": (TOY_SHOP, "ToyShop", (), (16, -11, 3.5), (8.5, -10), (False, True), None, None),
    "Street": (STREET, "CornerShop", (), (0, -8, 4.0), (5, -13), (False, True), ["B1"], None),
    "BankStreet": (BANK_STREET, "Bank", (), (0, -8, 4.5), (5, -13), (False, True), ["B1"], None),
    "Tree": (None, "Bank", (), (0, 0, 3.2), None, (True,), ["T1", "T2"], None),
}
BOOKMARKS = {  # name: (azimuth deg, elevation deg, distance, vertical FOV deg)
    "B1": (28, 38, 50, 40), "B2": (8, 14, 26, 70), "B3": (0, 89.5, 72, 30),
    "T1": (20, 12, 11, 40), "T2": (200, 18, 11, 40)}


def _lin(h):
    h = h.lstrip("#")
    return tuple(tt._srgb(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def _mat(name, rgba, emit=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Roughness"].default_value = 0.6
    if emit:
        b.inputs["Emission Color"].default_value = rgba
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    m.diffuse_color = rgba
    return m


_ATLAS = {}


def atlas_image(loc):
    if loc not in _ATLAS:
        path = P.atlas_path(loc)
        if not os.path.isfile(path):
            P.write_atlases()
        img = bpy.data.images.load(path, check_existing=True)
        img.name = f"EH_Palette_{loc}"
        _ATLAS[loc] = img
    return _ATLAS[loc]


def _multiply(m, rgba):
    """MeshPart.Color on an atlas part: the texture times the colour."""
    nt = m.node_tree
    tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not (tex and bsdf):
        return
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = rgba
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])


def style(o, loc, tint=None):
    """Atlas swap for kit pieces; code colours for Neon parts; glass for glass parts (from the manifest); `tint`
    multiplies a tintable part's atlas colour (MeshPart.Color)."""
    spec = MANIFEST.get(o.name.split(".")[0], {})
    mat = spec.get("material")
    if mat == "Neon":
        m = _mat("EH_Neon_" + o.name, _lin(TINT.get(o.name.split(".")[0], "#F4F7FF")), emit=4.0)
        o.data.materials.clear(); o.data.materials.append(m)
        o.color = m.diffuse_color
        return
    if mat == "Glass":
        m = _mat("EH_Glass_" + o.name, _lin("#A9B2CC"), alpha=0.25)
        o.data.materials.clear(); o.data.materials.append(m)
        o.color = (0.66, 0.70, 0.80, 0.3)
        return
    if spec.get("texture"):
        return   # hero SurfaceAppearance part: keep its own colour map
    for slot in o.material_slots:
        m = slot.material
        if m and m.node_tree:
            if tint:
                m = m.copy()
                slot.material = m
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE":
                    n.image = atlas_image(loc)
                    n.interpolation = "Closest"
            if tint:
                _multiply(m, _lin(tint))


_CACHE = {}


def place(model, pos, rot, flags, xmas, loc):
    if "xmas" in flags and not xmas:
        return []
    if "base" in flags and xmas:
        return []
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(FBX, model + ".fbx"))
    objs = [o for o in set(bpy.data.objects) - before if o.type == "MESH"]
    m = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(rot), 4, "Z")
    tint = next((f[5:] for f in flags if f.startswith("tint:")), None)
    keep = []
    for o in objs:
        base = o.name.split(".")[0]
        hide = any(f == f"hide:{base}" or (f == f"hide:{base}@xmas" and xmas) for f in flags)
        only = [f[5:] for f in flags if f.startswith("only:")]
        if hide or (only and base not in only):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        sc = next((float(f[6:]) for f in flags if f.startswith("scale:")), 1.0)
        if "origin" in flags:     # the part's own origin goes to `pos` (its authored offset in the Model is dropped)
            o.matrix_world = m @ Matrix.Scale(sc, 4) @ Matrix.Translation(-o.matrix_world.translation) @ o.matrix_world
        else:
            o.matrix_world = m @ o.matrix_world
        style(o, loc, tint)
        keep.append(o)
    return keep


def beams(spans):
    """Placeholder laser beams (code draws these in game): red body + white-hot core, every 2 studs."""
    out = []
    red, core = _mat("EH_Beam", _lin("#FF3838"), emit=6.0), _mat("EH_BeamCore", _lin("#FFFFFF"), emit=8.0)
    for x0, x1, y in spans:
        for z in (1, 3, 5, 7, 9):
            for r, m in ((0.07, red), (0.025, core)):
                bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=x1 - x0, location=((x0 + x1) / 2, y - 1.08, z),
                                                    rotation=(0, math.radians(90), 0))
                o = bpy.context.active_object
                o.data.materials.append(m); o.color = m.diffuse_color
                out.append(o)
    return out


def build_scene(name, xmas):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.world = bpy.data.worlds.new("EH_World")
    s.view_settings.view_transform = "Standard"
    _ATLAS.clear()
    layout, loc, spans, target, man, _variants, _shots, _cams = SCENES[name]
    layout = layout if layout is not None else _tree_layout()
    objs = []
    for model, pos, rot, flags in layout:
        objs += place(model, pos, rot, flags, xmas, loc)
    objs += beams(spans)
    table = tt.bounds(objs)
    lo, hi = table
    bpy.ops.mesh.primitive_plane_add(size=1, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, -0.55))
    t = bpy.context.active_object
    t.scale = ((hi.x - lo.x) + 30, (hi.y - lo.y) + 30, 1)
    tm = _mat("EH_Table", _lin("#1C1F3B"))
    t.data.materials.append(tm); t.color = tm.diffuse_color
    if man:
        objs += tt._mannequin(Vector((man[0], man[1], 0)), Vector((man[0], man[1], 0)))
    return s, objs, target


def lights(s, target, xmas):
    w = s.world
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = _lin("#373760")
    bg.inputs["Strength"].default_value = 0.9 if not xmas else 1.0   # Christmas Eve: ambient +10 % (STYLE_BIBLE 3)
    t = Vector(target)
    made = []
    for name, kind, off, col, energy, size in (
            ("key", "SPOT", (-4, -10, 16), "#FFD2A0", 14000, 0),
            ("pool_a", "POINT", (-6, -2, 6), "#FFD2A0", 2500, 0),
            ("pool_b", "POINT", (8, 1, 6), "#FFE6C8", 2500, 0),
            ("fill", "AREA", (-20, -24, 16), "#8C96FF", 4500, 16)):
        ld = bpy.data.lights.new(name, kind)
        ld.color = _lin(col)[:3]; ld.energy = energy
        if kind == "SPOT":
            ld.spot_size = math.radians(80); ld.spot_blend = 0.6
        if kind == "AREA":
            ld.size = size
        o = bpy.data.objects.new(name, ld)
        s.collection.objects.link(o)
        o.location = t + Vector(off)
        o.rotation_euler = (t - o.location).to_track_quat("-Z", "Y").to_euler()
        made.append(o)
    return made


def aim(cam, target, az, el, dist, vfov):
    t = Vector(target)
    a, e = math.radians(az), math.radians(el)
    cam.location = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(vfov)
    cam.data.clip_end = 1000


def shoot(name, xmas, shots, W, H, tmp):
    """Renders the requested shots of one scene; returns [(png, label)]. Shots: a BOOKMARKS name (Eevee), or
    "flat" / "flatB3" (Workbench flat albedo from B1 / the B3 top-down planning view: the no-shadow read)."""
    s, objs, target = build_scene(name, xmas)
    cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam); s.camera = cam
    s.render.resolution_x, s.render.resolution_y = W, H
    s.render.resolution_percentage = 100
    out = []
    made = lights(s, target, xmas)
    s.render.engine = "BLENDER_EEVEE"
    try:
        s.eevee.taa_render_samples = 24
        s.eevee.use_bloom = True
    except Exception:
        pass
    tag = "Christmas on" if xmas else "Christmas off"
    for b in [x for x in shots if not x.startswith("flat")]:
        aim(cam, target, *BOOKMARKS[b])
        p = os.path.join(tmp, f"{name}_{int(xmas)}_{b}.png")
        s.render.filepath = p
        bpy.ops.render.render(write_still=True)
        out.append((p, f"{name} {b} ({tag}, Eevee Heist Night approximation)"))
    flats = [x for x in shots if x.startswith("flat")]
    if flats:
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)
        s.world.use_nodes = False
        tt._workbench(s, "flat")
        for f in flats:
            b = f[4:] or "B1"
            aim(cam, target, *BOOKMARKS[b])
            p = os.path.join(tmp, f"{name}_{int(xmas)}_{f}.png")
            s.render.filepath = p
            bpy.ops.render.render(write_still=True)
            out.append((p, f"{name} {b} flat albedo ({tag}): the no-shadow " + ("planning view" if b == "B3" else "phone read")))
    return out


def compose(path, title, tiles, cols, W, H):
    from PIL import Image, ImageDraw, ImageFont
    fp = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font = ImageFont.truetype(fp, 15) if os.path.isfile(fp) else ImageFont.load_default()
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (W * cols, H * rows + 34), (24, 25, 36))
    dr = ImageDraw.Draw(sheet)
    dr.text((10, 9), title, fill=(230, 232, 245), font=font)
    for i, (p, label) in enumerate(tiles):
        im = Image.open(p).convert("RGB").resize((W, H))
        x, y = (i % cols) * W, 34 + (i // cols) * H
        sheet.paste(im, (x, y))
        dr.rectangle([x, y, x + 10 + 8 * len(label), y + 22], fill=(24, 25, 36))
        dr.text((x + 4, y + 3), label, fill=(230, 232, 245), font=font)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)
    return path


TILES = os.path.join(tempfile.gettempdir(), "eh_kit_preview")   # the single renders (outside the repo), read by index()


def index(W, H):
    """KitPreview.png: the B1 Christmas-off and -on tiles of every scene side by side (from the TILES temp folder, so
    each scene can render in its own Blender process)."""
    tiles = []
    for name in SCENES:
        for xmas in (0, 1):
            for shot in ("B1", "T1"):
                q = os.path.join(TILES, f"{name}_{xmas}_{shot}.png")
                if os.path.isfile(q):
                    tiles.append((q, f"{name} {shot}, Christmas {'on' if xmas else 'off'}"))
    return compose(os.path.join(OUT, "KitPreview.png"), "Echo Heist launch kit: B1 diorama per scene, Christmas dressing "
                   "off / on (details: KitPreview_<Scene>.png)", tiles, 4, W // 2, H // 2)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=list(SCENES))
    ap.add_argument("--size", type=int, default=960)
    a = ap.parse_args(argv)
    W, H = a.size, a.size * 9 // 16
    if not a.only:
        # one Blender process per scene: many factory resets + Eevee renders in one process are not reliable headless
        import subprocess
        for name in SCENES:
            subprocess.run([sys.executable, os.path.abspath(__file__), "--only", name, "--size", str(a.size)], check=True)
        print("kit preview:", index(W, H))
        return
    os.makedirs(TILES, exist_ok=True)
    plan = {"CornerShop": [(False, ["B1", "flat", "flatB3"]), (True, ["B1", "B2"])],
            "Bank": [(False, ["B1", "flat", "flatB3"]), (True, ["B1", "B2"])],
            "ToyShop": [(False, ["B1", "flatB3"]), (True, ["B1", "B2"])],
            "Street": [(False, ["B1"]), (True, ["B1"])],
            "BankStreet": [(False, ["B1"]), (True, ["B1"])],
            "Tree": [(True, ["T1", "T2"])]}
    tiles = []
    for xmas, shots in plan[a.only]:
        tiles += shoot(a.only, xmas, shots, W, H, TILES)
    title = (f"Echo Heist kit preview: {a.only} (atlas EH_Palette_{SCENES[a.only][1]}); Christmas dressing layer off / on. "
             "Placeholders: grey mannequin, laser beams.") if a.only != "Tree" else (
             "Echo Heist advent tree: the 22 ornaments on Xmas_Tree's hooks, each with its day's mesh and MeshPart.Color "
             "(eh_palette.ORNAMENT_DAYS)")
    out = compose(os.path.join(OUT, f"KitPreview_{a.only}.png"), title, tiles, 2, W, H)
    print("kit preview:", out)


if __name__ == "__main__":
    main(sys.argv[1:])
