"""The world backdrop and golden-frame staging for tools/blender/level_shots.py (PLAN_STEAM_PLUS 3.3 and 4.1 W4,
docs/GOLDEN_FRAMES.md G1 and G2). Imported by level_shots; not run on its own.

What it draws, from the same data the game uses (nothing hand-placed):
  * the backdrop plan (Shared/Heist/BackdropPlan via level_plan.luau): ground plane + kerb, the facade ring with its
    cornice, snow and Neon windows, the Skyline_Near / Skyline_Far kit meshes (assets/fbx) at their four yaws;
  * the client's snow caps on the storefront awnings and sills and the warm window spill (Heist/Backdrop.luau,
    same local offsets);
  * the Heist City sky: the six uploaded faces (assets/sky/EH_SkyCity_*) turned into an equirectangular world
    texture for camera rays (Roblox -Z = Blender -Y), so Hoardsworth's tower stands where the game draws it;
  * falling snow: Config.Backdrop.SNOW.maxAlive flakes in the camera-following volume (exterior views only);
  * the Atmosphere haze (Density 0.28): a depth pass (material override = view distance) and an exponential blend
    toward the haze colour (90,80,150) on geometry; the sky keeps its own horizon haze.
"""
import math
import os
import random

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import marketing_renders as MR  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
SKY = os.path.join(REPO, "assets", "sky")
HAZE_MAX = 0.9
DEPTH_SCALE = 3000.0      # the depth pass stores view distance / DEPTH_SCALE


def _recipe():
    """Recipe A as the game ships it: the Lighting and Atmosphere values of default.project.json (0-1 colours)."""
    import json
    tree = json.load(open(os.path.join(REPO, "default.project.json")))["tree"]["Lighting"]
    lt, at = dict(tree["$properties"]), dict(tree["Atmosphere"]["$properties"])
    # EH_RECIPE='{"OutdoorAmbient": [r, g, b], "Density": 0.2, ...}' (0-255 colours): try a retune before writing it
    over = json.loads(os.environ.get("EH_RECIPE", "{}"))
    for k, v in over.items():
        v = [c / 255 for c in v] if isinstance(v, list) else v
        (at if k in at else lt)[k] = v
    return lt, at


LIGHTING, ATMOSPHERE = _recipe()
HAZE = tuple(round(c * 255) for c in ATMOSPHERE["Color"])
# studs: 1 - exp(-d / L). Calibrated as 520 at Density 0.28 (18 % at 100, 44 % at 300, 69 % at 600), inversely
# proportional to the density
HAZE_LAMBDA = 520.0 * 0.28 / max(ATMOSPHERE["Density"], 1e-3)

# The "Roblox tone map" proxy (WORLD 2.0, LEVELS.md section 10): Blender's Standard view transform has no toe, but the
# engine's Default tone mapper is a filmic curve that crushes dark values (assumption: the ACES fit below; a dark
# albedo lit only by the night ambient lands in the toe and reads black in Studio, while Standard shows dark navy).
TONEMAP = os.environ.get("EH_TONEMAP", "roblox")


def _aces(x):
    return (x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14)


def tonemap(raw, out):
    """sRGB (Standard) -> linear -> the ACES fit -> sRGB. Returns `out` (or `raw` untouched with EH_TONEMAP=standard)."""
    if TONEMAP != "roblox":
        return raw
    import numpy as np
    from PIL import Image
    a = np.asarray(Image.open(raw).convert("RGB"), np.float32) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    t = np.clip(_aces(lin), 0, 1)
    s = np.where(t <= 0.0031308, t * 12.92, 1.055 * np.power(t, 1 / 2.4) - 0.055)
    Image.fromarray(np.clip(s * 255 + 0.5, 0, 255).astype(np.uint8)).save(out)
    return out

# Heist/Backdrop.luau (Roblox local frame of a kit front: X along the front, Y up, -Z the street)
AWNINGS = ((-7.65, -0.35), (-23.65, -16.35))
AWNING_TOP = (9.75, 8.7, 2.4)
SILLS = {"Storefront_24x12": (2.25, ((-7.65, -0.35), (-23.65, -16.35))),
         "BankFront_24x12": (2.65, ((-5.45, -1.55), (-22.45, -18.55)))}
SPILL_DEPTH = 5.0                 # Config.Backdrop.SPILL_DEPTH
NEAR_CAMERA = 6.0
NEON_EMIT = 1.25          # Neon Bulb Warm: keeps its warm colour in Eevee; 2+ clips to white before the 2D bloom

FACES = {   # Roblox face -> (forward, right, up), as tools/blender/sky_faces.py
    "Ft": ((0, 0, -1), (1, 0, 0), (0, 1, 0)), "Bk": ((0, 0, 1), (-1, 0, 0), (0, 1, 0)),
    "Rt": ((1, 0, 0), (0, 0, 1), (0, 1, 0)), "Lf": ((-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    "Up": ((0, 1, 0), (1, 0, 0), (0, 0, 1)), "Dn": ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
}


def rb(x, y, z):
    return Vector((-x, z, y))


def hexc(t):
    return "#%02X%02X%02X" % tuple(int(v) for v in t[:3])


# ------------------------------------------------------------------ sky
def equirect(path, w=2048):
    """The six Heist City faces resampled to a Blender equirectangular image (u = 0.5 - atan2(y, x) / 2pi)."""
    import numpy as np
    from PIL import Image
    if os.path.isfile(path):
        return path
    faces = {k: np.asarray(Image.open(os.path.join(SKY, f"EH_SkyCity_{k}.png")).convert("RGB"), np.float32)
             for k in FACES}
    n = next(iter(faces.values())).shape[0]
    h = w // 2
    u = (np.arange(w) + 0.5) / w
    v = 1 - (np.arange(h) + 0.5) / h
    uu, vv = np.meshgrid(u, v)
    phi = (0.5 - uu) * 2 * math.pi
    el = (vv - 0.5) * math.pi
    bx, by, bz = np.cos(el) * np.cos(phi), np.cos(el) * np.sin(phi), np.sin(el)
    d = np.stack((-bx, bz, by), axis=-1)            # Roblox direction
    out = np.zeros((h, w, 3), np.float32)
    best = np.full((h, w), -2.0, np.float32)
    for k, (f, r, up) in FACES.items():
        f, r, up = (np.array(x, np.float32) for x in (f, r, up))
        dot = d @ f
        m = dot > best
        best = np.where(m, dot, best)
        p = d / np.maximum(dot, 1e-6)[..., None]
        px = np.clip(((p @ r + 1) / 2 * n).astype(int), 0, n - 1)
        py = np.clip(((1 - p @ up) / 2 * n).astype(int), 0, n - 1)
        out[m] = faces[k][py[m], px[m]]
    Image.fromarray(out.astype(np.uint8)).save(path)
    return path


def world_sky(s, tmp):
    """Camera rays see the Heist City sky; everything else keeps level_shots' recipe-A ambient."""
    nt = s.world.node_tree
    bgs = [n for n in nt.nodes if n.type == "BACKGROUND"]
    sky = bgs[-1]                                  # level_shots.lighting adds the camera-ray background last
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(equirect(os.path.join(tmp, "sky_city_equirect.png")))
    nt.links.new(env.outputs["Color"], sky.inputs["Color"])
    sky.inputs["Strength"].default_value = 1.0


# ------------------------------------------------------------------ geometry
_SKIN_MATS = {}
WINDOWS_PNG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "ui", "EH_FX_Windows.png")


def skin_mat(col, skin, size):
    """The town's window grid (Heist/Backdrop: a Texture on the skin's outward face, tiled tileU x tileV studs from the
    face's top-left seen from the front) over the wall colour. size = the skin part's Roblox size."""
    n = skin["normal"]
    key = (tuple(col), tuple(n), tuple(round(s, 3) for s in size), skin["tileU"], skin["tileV"])
    if key in _SKIN_MATS:
        return _SKIN_MATS[key]
    m = bpy.data.materials.new("Skin")
    m.use_nodes = True
    nt = m.node_tree
    b = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.7
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    # the viewer's right in Blender axes (Roblox normal (nx, nz) -> Blender (-nx, nz, 0); right = -(N x Z))
    bx, by = -n[0], n[1]
    rx, ry = -by, bx
    width = size[2] if abs(n[0]) > 0.5 else size[0]

    def node(op, a, bval=None):
        x = nt.nodes.new("ShaderNodeMath")
        x.operation = op
        for i, v in enumerate((a, bval)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                x.inputs[i].default_value = v
            else:
                nt.links.new(v, x.inputs[i])
        return x.outputs[0]
    u = node("ADD", node("MULTIPLY", sep.outputs["X"], rx), node("MULTIPLY", sep.outputs["Y"], ry))
    u = node("DIVIDE", node("ADD", u, width / 2), skin["tileU"])
    v = node("ADD", node("DIVIDE", node("SUBTRACT", sep.outputs["Z"], size[1] / 2), skin["tileV"]), 1.0)
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(u, comb.inputs[0])
    nt.links.new(v, comb.inputs[1])
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(os.path.normpath(WINDOWS_PNG), check_existing=True)
    img.extension = "REPEAT"
    img.interpolation = "Closest"
    nt.links.new(comb.outputs[0], img.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = MR.lin(hexc(col))
    nt.links.new(img.outputs["Alpha"], mix.inputs["Factor"])
    nt.links.new(img.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    m.diffuse_color = MR.lin(hexc(col))
    _SKIN_MATS[key] = m
    return m


def _box(name, lo, hi, mat, shadow=False):
    """An axis-aligned Roblox box (lo, hi corners) as a Blender cube."""
    a, b = rb(*lo), rb(*hi)
    size = (abs(b.x - a.x), abs(b.y - a.y), abs(b.z - a.z))
    o = MR.box(name, size, mat, None, tuple((a + b) / 2), bevel=0)
    o.visible_shadow = shadow
    return o


def _hexa(name, pts, mat):
    """A box from 8 Roblox points (bottom 4 then top 4, same winding)."""
    bm = bmesh.new()
    vs = [bm.verts.new(rb(*p)) for p in pts]
    for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([vs[i] for i in f])
    o = MR._obj(name, bm, mat)
    o.visible_shadow = False
    return o


def _local(pivot, x, y, z):
    """A point in a kit front's local frame -> level space (KitPlan pivot (x, y, z, yaw), CFrame.Angles(0, yaw, 0))."""
    px, py, pz, yaw = pivot
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return (px + x * c + z * s, py + y, pz - x * s + z * c)


def backdrop(level, lib, put, pool_mat=None):
    """Draws the plan BackdropPlan made for this level (the snowfield, the town's parts, kit pieces and unlit pools,
    the rings in their flat haze colour) and the client's front dressing. pool_mat(hex, peak, exponent, radius,
    emit): level_shots.soft_pool_mat (the engine's soft pool image)."""
    import kit_preview as K
    bp = level["backdrop"]
    cfg = level["backdropConfig"]
    mats = {}

    def mat(col, emit=0.0):
        k = (tuple(col), emit)
        if k not in mats:
            mats[k] = MR.mat(hexc(col), 0.7, emit=emit)
        return mats[k]

    def part(p):
        (sx, sy, sz), (cx, cy, cz) = p["size"], p["pos"]
        m = skin_mat(p["color"], p["skin"], p["size"]) if p.get("skin") else \
            mat(p["color"], NEON_EMIT if p.get("neon") else 0.0)
        o = _box(p["name"], (cx - sx / 2, cy - sy / 2, cz - sz / 2), (cx + sx / 2, cy + sy / 2, cz + sz / 2),
                 m, shadow=p["layer"] == "building")
        o["eh_src"] = p.get("src") or ("ground" if p["layer"] == "ground" else "building")
        return o
    for p in bp["parts"]:
        if p["layer"] == "fence":
            continue   # invisible colliders
        part(p)
    # the town's kit pieces (Heist/Backdrop.kitPiece: the pivot, a yaw, a uniform scale or a target size)
    for k in bp.get("kit") or []:
        spec = K.MANIFEST.get(k["piece"])
        o = None
        if spec is not None:
            if k.get("size"):
                sc = tuple(k["size"][i] / spec["size"][i] for i in range(3))
            else:
                sc = (k.get("scale") or 1.0,) * 3
            o = put(lib, {"model": spec["model"], "name": k["piece"], "c": None},
                    (k["pos"][0], k["pos"][1], k["pos"][2], k["yaw"]), sc, Matrix.Identity(4))
        if o is None:
            if k.get("fallback"):
                part(k["fallback"])
            continue
        o.visible_shadow = False
        o["eh_src"] = k["src"]
        if spec["material"] == "Neon":
            o.data = o.data.copy()
            o.data.materials.clear()
            o.data.materials.append(MR.mat(hexc(cfg["WINDOW_COLOR"]), 0.4, emit=NEON_EMIT))
        elif k.get("color"):
            o.data = o.data.copy()
            o.data.materials.clear()
            o.data.materials.append(MR.mat(hexc(k["color"]), 0.5))
    # the unlit warm pools (SurfaceGui, LightInfluence 0: the soft pool image at ImageTransparency 1 - alpha)
    for pl in bp.get("pools") or []:
        r = pl["size"] / 2
        if pool_mat is not None:
            m = pool_mat(hexc(pl["color"]), pl["alpha"], 1.0, r, 0.8)
        else:
            m = MR.mat(hexc(pl["color"]), 0.9, emit=0.8, alpha=pl["alpha"] * 0.5)
        d = MR.cyl("TownPool", r, r, 0.01, m, None, tuple(rb(*pl["pos"])), seg=48)
        d.visible_shadow = False
    for ring in bp["rings"]:
        for piece in (ring["piece"], ring["windows"]):
            for yaw in ring["yaws"]:
                o = put(lib, {"model": ring["piece"], "name": piece, "c": None},
                        (ring["centre"][0], ring["centre"][1], ring["centre"][2], yaw), (1, 1, 1), Matrix.Identity(4))
                if o is None:
                    continue
                o.visible_shadow = False
                o["eh_src"] = "ring"
                if piece == ring["windows"]:
                    o.data = o.data.copy()
                    o.data.materials.clear()
                    o.data.materials.append(MR.mat(hexc(cfg["WINDOW_COLOR"]), 0.4, emit=NEON_EMIT))
                elif ring.get("color"):   # Heist/Backdrop: TextureID cleared, the flat haze colour
                    o.data = o.data.copy()
                    o.data.materials.clear()
                    o.data.materials.append(mat(ring["color"]))
    # the kit fronts: snow on the awnings' upper share and the sills, warm window spill on the pavement
    snow = mat(cfg["SNOW_COLOR"], 0.15)
    t = cfg["SNOW_CAPS"]["thickness"]
    share = cfg["SNOW_CAPS"]["awningShare"]
    loc = level["location"]
    spill_col = level["lighting"]["LOCATION"][loc]["room"][0]
    for it in level["kit"]:
        if it["role"] != "front":
            continue
        name = it["pieces"][0]["name"]
        pv = it["pivot"]
        if name == "Storefront_24x12":
            y0, y1, depth = AWNING_TOP
            ln = math.hypot(depth, y0 - y1)
            dy, dz = -(y0 - y1) / ln, -depth / ln            # down the slope
            ny, nz = depth / ln, -(y0 - y1) / ln             # the slope's normal
            for xa, xb in AWNINGS:
                pts = []
                for off in (0.0, t):
                    for (x, s_) in ((xa + 0.05, 0.0), (xb - 0.05, 0.0), (xb - 0.05, ln * share), (xa + 0.05, ln * share)):
                        pts.append(_local(pv, x, y0 + dy * s_ + ny * (off + 0.01), dz * s_ + nz * (off + 0.01)))
                _hexa("AwningSnow", pts, snow)
        sill = SILLS.get(name)
        if not sill:
            continue
        y, xs = sill
        for xa, xb in xs:
            pts = [_local(pv, x, yy, z) for yy in (y, y + t) for (x, z) in ((xa, -0.3), (xb, -0.3), (xb, 0.3), (xa, 0.3))]
            _hexa("SillSnow", pts, snow)
            # spill: bands fading toward the kerb (Backdrop's UIGradient over SPILL_ALPHA), unlit
            bands = 6
            for k in range(bands):
                z0, z1 = -0.5 - SPILL_DEPTH * k / bands, -0.5 - SPILL_DEPTH * (k + 1) / bands
                pts = [_local(pv, x, yy, z) for yy in (0.06 + 0.001 * k, 0.065 + 0.001 * k)
                       for (x, z) in ((xa, z0), (xb, z0), (xb, z1), (xa, z1))]
                a = cfg["SPILL_ALPHA"] * (1 - (k + 0.5) / bands)
                m = MR.mat(hexc(spill_col), 0.9, emit=0.5, alpha=a)
                _hexa("WindowSpill", pts, m)


def snowfall(focus, cfg, cam_pos=None, seed=5):
    """Config.Backdrop.SNOW.maxAlive flakes in the volume over the camera focus (Roblox coordinates). Flakes within
    NEAR_CAMERA studs of the lens are dropped: a still frame cannot show them streaking past."""
    S = cfg["SNOW"]
    rng = random.Random(seed)
    bx, by, bz = S["box"]
    m = MR.mat(hexc(S["color"]), 0.9, emit=0.35)
    bm = bmesh.new()
    for _ in range(int(S["maxAlive"])):
        x = focus[0] + rng.uniform(-bx / 2, bx / 2)
        y = focus[1] + S["above"] + rng.uniform(-by / 2, by / 2)
        z = focus[2] + rng.uniform(-bz / 2, bz / 2)
        r = rng.uniform(*S["size"]) / 2
        if cam_pos is not None and math.dist((x, y, z), cam_pos) < NEAR_CAMERA:
            continue
        g = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
        for v in g["verts"]:
            v.co += rb(x, y, z)
    o = MR._obj("Snowfall", bm, m)
    o.visible_shadow = False
    return o


# ------------------------------------------------------------------ haze
def depth_pass(s, cam, path):
    """Renders view distance / DEPTH_SCALE into a 16-bit grey PNG (alpha 0 where the sky is)."""
    m = bpy.data.materials.new("Depth")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    cd = nt.nodes.new("ShaderNodeCameraData")
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.inputs[1].default_value = DEPTH_SCALE
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(cd.outputs["View Distance"], div.inputs[0])
    nt.links.new(div.outputs[0], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    vl = bpy.context.view_layer
    keep = (s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure,
            s.render.image_settings.color_depth, s.render.image_settings.color_mode)
    s.render.film_transparent = True
    s.view_settings.view_transform = "Raw"
    s.view_settings.exposure = 0.0
    s.render.image_settings.color_depth = "16"
    s.render.image_settings.color_mode = "RGBA"
    hidden = []
    for o in bpy.data.objects:          # lights do not matter; the snowfall would hide depth behind it
        if o.name.startswith("Snowfall") and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    vl.material_override = m
    s.camera = cam
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    vl.material_override = None
    for o in hidden:
        o.hide_render = False
    (s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure,
     s.render.image_settings.color_depth, s.render.image_settings.color_mode) = keep


def haze(raw, depth, out):
    """Blends geometry toward the Atmosphere colour by view distance; the sky (depth alpha 0) is left alone."""
    import numpy as np
    from PIL import Image
    a = np.asarray(Image.open(raw).convert("RGB"), np.float32)
    dimg = Image.open(depth)
    dp = np.asarray(dimg, np.float32)
    if dp.ndim == 3:
        alpha = dp[..., 3] / (65535.0 if dp.max() > 255 else 255.0)
        dist = dp[..., 0] / (65535.0 if dp.max() > 255 else 255.0) * DEPTH_SCALE
    else:
        alpha = np.ones(dp.shape, np.float32)
        dist = dp / 65535.0 * DEPTH_SCALE
    f = np.clip(1 - np.exp(-dist / HAZE_LAMBDA), 0, HAZE_MAX) * (alpha > 0.5)
    hz = np.array(HAZE, np.float32)
    a = a * (1 - f[..., None]) + hz * f[..., None]
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(out)
