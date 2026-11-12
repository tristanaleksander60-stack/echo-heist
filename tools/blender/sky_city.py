"""The "Heist City" night cubemap (PLAN_STEAM_PLUS 3.1 and 4.1 W4, roblox_quality 2.1 L5): a hazy city skyline on the
horizon and ONE landmark, Hoardsworth Tower with the Snow Globe Vault on top (MASTERPLAN 2.2: Sir Hoardsworth, the toy
tycoon, burgundy and gold; he has vacuumed every present in town into the globe). Original design.

    python3 tools/blender/sky_city.py [--size 1024] [--samples 16] [--preview]

Writes assets/sky/EH_SkyCity_{Bk,Dn,Ft,Lf,Rt,Up}.png (the six Sky faces; upload with `python3 tools/kit_upload.py
--sky`) and docs/art/sky_city_preview.png (the four side faces in a strip, the cross below).

How: Blender (Eevee, film transparent) renders only the geometry, the city rings and the tower, with six 90-degree
cameras at the centre; numpy paints the sky behind it per pixel (the night gradient of tools/blender/sky_faces.py,
horizon in the Atmosphere colour (90,80,150), a warm glow band low on the horizon, stars above 14 degrees where no
geometry is) and composites the render over it. Every piece of directional content stays under 22 degrees of
elevation, so the Up and Dn faces hold only the elevation gradient and random stars: their in-plane rotation (the part
of Roblox's face convention that is easy to get wrong) cannot show. Side faces: Ft looks toward Roblox -Z, Bk +Z, Rt +X,
Lf -X (sky_faces.FACES), image up = +Y.

Landmark placement: the tower stands toward Roblox -Z (the Ft face centre: Config.Backdrop.SKY_LANDMARK_YAW = 0). The
spawn views face -Z, past the shop front, so the globe rises over the shop roof line: shop top about 10 degrees from
the classic camera, the skyline rings at most 10.5 degrees (Config.Backdrop / backdrop.py), the globe at 13-19.5.
Materials are flat emission (a painted sky is never lit by the game); the tower's two shades fake a moon on its left.
"""
import argparse
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from PIL import Image  # noqa: E402

import sky_faces as SF  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "assets", "sky")
PREVIEW = os.path.join(REPO, "docs", "art", "sky_city_preview.png")
TMP = os.path.join("/tmp", "eh_sky_city")

HORIZON = np.array((90, 80, 150), float)      # Atmosphere.Color (recipe A): the haze meets the sky without a band
ZENITH = np.array((22, 21, 50), float)
GROUND = np.array((30, 27, 52), float)
GLOW = np.array((150, 96, 138), float)        # a warm plum glow low on the horizon (the city's light in the haze)
HALO = np.array((214, 170, 150), float)      # the globe's floodlit haze
STAR_MIN_ELEV = 14.0

TOWER = dict(dist=1200.0, base_w=96.0, shaft_top=250.0, globe_r=76.0, globe_z=330.0)
BURGUNDY = ("#7E2C4C", "#521C34")             # lit side, shade side (Ribbon Burgundy family)
GOLD = ("#D8AE58", "#9C7834")                 # antique gold: never Heist Gold (loot), and far away in the sky
WINDOW = "#F6C0A2"                            # Bulb Warm, like the backdrop windows


def lin(hexc):
    h = hexc.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


_MATS = {}


def emit(hexc, strength=1.0):
    k = (hexc, strength)
    if k in _MATS:
        return _MATS[k]
    m = bpy.data.materials.new(f"E_{hexc}_{strength}")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = lin(hexc)
    e.inputs["Strength"].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs["Surface"])
    _MATS[k] = m
    return m


def glass():
    """The globe: clear in the middle, a bright icy rim (facing), blended over the sky."""
    m = bpy.data.materials.new("Globe")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value = 0.0
    ramp.inputs["From Max"].default_value = 1.0
    ramp.inputs["To Min"].default_value = 0.06
    ramp.inputs["To Max"].default_value = 0.95
    nt.links.new(lw.outputs["Facing"], ramp.inputs["Value"])
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = lin("#DDE8FF")
    e.inputs["Strength"].default_value = 1.25
    t = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(ramp.outputs[0], mix.inputs[0])
    nt.links.new(t.outputs[0], mix.inputs[1])
    nt.links.new(e.outputs[0], mix.inputs[2])
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(mix.outputs[0], o.inputs["Surface"])
    m.surface_render_method = "BLENDED"
    return m


def mesh(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for m in mats:
        me.materials.append(m)
    return o


def box(bm, lo, hi, mat_of=None):
    """An axis-aligned box into bm; mat_of(normal) -> material index for each face (default 0)."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    vs = [bm.verts.new(v) for v in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                    (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for idx, n in (((0, 3, 2, 1), (0, 0, -1)), ((4, 5, 6, 7), (0, 0, 1)), ((0, 1, 5, 4), (0, -1, 0)),
                   ((1, 2, 6, 5), (1, 0, 0)), ((2, 3, 7, 6), (0, 1, 0)), ((3, 0, 4, 7), (-1, 0, 0))):
        f = bm.faces.new([vs[i] for i in idx])
        f.material_index = mat_of(n) if mat_of else 0
    return vs


def rotate_z(vs, ang, about=(0, 0, 0)):
    m = Matrix.Translation(Vector(about)) @ Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation(-Vector(about))
    for v in vs:
        v.co = m @ v.co


def city(rng):
    """Three rings of building silhouettes on the horizon (1-5.5 degrees), lit windows on the faces that look at
    the centre. Nearer rings are darker; the farthest melts into the haze colour. Blender: the centre at the origin."""
    rings = [(1500.0, "#36325D", 0.09, (1.0, 4.6)), (2300.0, "#433E70", 0.06, (0.8, 3.6)),
             (3300.0, "#4E4881", 0.035, (0.6, 2.8))]
    tower_az = -math.pi / 2   # Blender -Y = Roblox -Z
    for r, col, lit, elev in rings:
        bm = bmesh.new()
        wm = bmesh.new()
        ang = rng.uniform(0, 0.02)
        while ang < 2 * math.pi:
            w = r * math.radians(rng.uniform(0.8, 2.6))
            h = r * math.tan(math.radians(rng.uniform(*elev)))
            if rng.random() < 0.1:
                h *= rng.uniform(1.5, 2.1)   # a few towers
            # keep a lower notch where the landmark stands, so its shaft reads down to the haze
            d_az = math.atan2(math.sin(ang - tower_az), math.cos(ang - tower_az))
            if abs(d_az) < math.radians(4.5):
                h *= 0.55
            vs = box(bm, (-w / 2, 0, -5), (w / 2, w * 0.6, h))
            # windows on the inner face (y = 0 side looks at the centre after the rotation below)
            floor_h = max(6.0, r * 0.0045)
            ww, wh = floor_h * 0.45, floor_h * 0.55
            wv = []
            z = floor_h
            while z + wh < h - floor_h * 0.5:
                x = -w / 2 + ww
                while x + ww < w / 2 - ww * 0.5:
                    if rng.random() < lit:
                        wv += box(wm, (x, -1.0, z), (x + ww, 0.0, z + wh))
                    x += ww * 2.2
                z += floor_h
            for group in (vs, wv):
                if group:
                    rotate_z(group, ang - math.pi / 2)
                    for v in group:
                        v.co += Vector((r * math.cos(ang), r * math.sin(ang), 0))
            ang += math.atan2(w, r) + math.radians(rng.uniform(0.0, 0.5))
        mesh(f"City{int(r)}", bm, [emit(col)])
        mesh(f"CityWin{int(r)}", wm, [emit(WINDOW, 1.0 if r < 2000 else 0.75)])


def tower(rng):
    """Hoardsworth Tower: a slim burgundy art-deco shaft with gold corner fins and warm windows, three setbacks, a gold
    cradle on top holding the Snow Globe Vault (a glass ball full of stolen presents and snow)."""
    T = TOWER
    D = T["dist"]
    cy = -D                                       # Blender -Y = Roblox -Z
    moon = Vector((-0.8, 0.3, 0.5)).normalized()  # the lit side faces the viewer's left

    def shade(n):
        return 0 if Vector(n).dot(moon) > 0.05 or n[1] > 0.5 else 1
    bm = bmesh.new()
    gm = bmesh.new()
    wm = bmesh.new()
    tiers = [(0.0, 110.0, T["base_w"], T["base_w"] * 0.7), (110.0, 190.0, T["base_w"] * 0.78, T["base_w"] * 0.6),
             (190.0, T["shaft_top"], T["base_w"] * 0.58, T["base_w"] * 0.46)]
    for z0, z1, w, d in tiers:
        box(bm, (-w / 2, cy - d / 2, z0), (w / 2, cy + d / 2, z1), shade)
        # gold corner fins and a gold band at the top of each tier
        for sx in (-1, 1):
            box(gm, (sx * w / 2 - 2.5, cy + d / 2 - 2.5, z0), (sx * w / 2 + 2.5, cy + d / 2 + 1.5, z1 + 3.0),
                lambda n: 0 if n[0] * sx <= 0 else 1)
        box(gm, (-w / 2 - 2.0, cy - d / 2 - 2.0, z1 - 4.0), (w / 2 + 2.0, cy + d / 2 + 2.0, z1), shade)
        # warm windows on the face that looks at the city centre, +Y (rows of narrow slots, most of them lit: the tycoon never sleeps)
        cols = max(3, int(w // 9))
        for row in range(int((z1 - z0 - 10) // 9)):
            z = z0 + 6 + row * 9
            for c in range(cols):
                if rng.random() < 0.62:
                    x = -w / 2 + 6 + c * (w - 12) / max(1, cols - 1) - 1.6
                    box(wm, (x, cy + d / 2 - 0.2, z), (x + 3.2, cy + d / 2 + 0.8, z + 5.0))
    # the crown: four gold fins rising into a cup that cradles the globe
    top = T["shaft_top"]
    gz, gr = T["globe_z"], T["globe_r"]
    for sx in (-1, 1):
        for k in range(3):
            x = sx * (6 + k * 8)
            box(gm, (x - 1.6, cy - 6, top), (x + 1.6, cy + 6, gz - gr * 0.55 - k * 4), shade)
    cup = bmesh.new()
    bmesh.ops.create_cone(cup, cap_ends=True, cap_tris=False, segments=32, radius1=gr * 0.42, radius2=gr * 0.7,
                          depth=gr * 0.34)
    for v in cup.verts:
        v.co += Vector((0, cy, gz - gr * 0.9))       # the cup's rim at 0.73 r below the centre: the glass stays clear
    cup_o = mesh("Cradle", cup, [emit(GOLD[0]), emit(GOLD[1])])
    for p in cup_o.data.polygons:
        p.material_index = 0 if p.normal.dot(moon) > 0 else 1
    mesh("Tower", bm, [emit(BURGUNDY[0]), emit(BURGUNDY[1])])
    mesh("TowerGold", gm, [emit(GOLD[0]), emit(GOLD[1])])
    mesh("TowerWin", wm, [emit(WINDOW, 1.8)])
    # the Snow Globe Vault: glass, a heap of presents and snow inside, a gold H plaque on the cradle
    g = bmesh.new()
    bmesh.ops.create_uvsphere(g, u_segments=48, v_segments=24, radius=gr)
    for v in g.verts:
        v.co += Vector((0, cy, gz))
    go = mesh("Globe", g, [glass()])
    for p in go.data.polygons:
        p.use_smooth = True
    pm = bmesh.new()
    colours = ["#2FBF71", "#B0385E", "#E0B860", "#3DA0D0", "#1C7C48", "#D05A7A"]
    mats = [emit(c) for c in colours]
    heap = []
    for i in range(16):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0, gr * 0.55)
        s = rng.uniform(15, 24)
        x, y = rr * math.cos(a), rr * math.sin(a) * 0.5
        zb = gz - gr * 0.66 + (gr * 0.55 - rr) * 0.6 + rng.uniform(0, 6)
        vs = box(pm, (x - s / 2, cy + y - s / 2, zb), (x + s / 2, cy + y + s / 2, zb + s * rng.uniform(0.7, 1.2)),
                 lambda n, i=i: i % len(colours))
        rotate_z(vs, rng.uniform(0, math.pi), (x, cy + y, zb))
        heap.append(vs)
    mesh("Presents", pm, mats)
    sm = bmesh.new()
    for i in range(110):
        u = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        p = Vector((0, cy, gz)) + u * gr * rng.uniform(0.15, 0.9)
        s = rng.uniform(0.7, 1.4)
        box(sm, (p.x - s, p.y - s, p.z - s), (p.x + s, p.y + s, p.z + s))
    mesh("Snow", sm, [emit("#F4F7FF", 1.3)])
    # a gold plaque with the tycoon's monogram as a ring + bar (an "H" in a monocle)
    hm = bmesh.new()
    pz = gz - gr * 0.9
    bmesh.ops.create_circle(hm, cap_ends=True, segments=24, radius=9.0)
    for v in hm.verts:
        v.co = Vector((v.co.x, cy + gr * 0.58, pz + v.co.y))
    mesh("Monocle", hm, [emit("#F0D08A", 1.2)])
    hb = bmesh.new()
    for x0, x1, z0, z1 in ((-5, -3, -6, 6), (3, 5, -6, 6), (-5, 5, -1, 1)):
        box(hb, (x0, cy + gr * 0.58 + 0.4, pz + z0), (x1, cy + gr * 0.58 + 1.0, pz + z1))
    mesh("MonogramH", hb, [emit("#521C34")])


FACES = SF.FACES


def to_blender(v):
    return Vector((-v[0], v[2], v[1]))


def setup(size, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "BLENDER_EEVEE"
    s.eevee.taa_render_samples = samples
    s.render.film_transparent = True
    s.view_settings.view_transform = "Standard"
    s.render.resolution_x = s.render.resolution_y = size
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("W")
    s.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Strength"].default_value = 0.0
    cd = bpy.data.cameras.new("cam")
    cd.sensor_fit = "VERTICAL"
    cd.angle = math.radians(90)
    cd.clip_start = 1.0
    cd.clip_end = 20000
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    s.camera = cam
    return s, cam


def background(name, n, rng_stars):
    f, r, up = (np.array(x, float) for x in FACES[name])
    t = (np.arange(n) + 0.5) / n * 2 - 1
    u, v = np.meshgrid(t, -t)
    d = f[None, None, :] + u[..., None] * r + v[..., None] * up
    d /= np.linalg.norm(d, axis=2, keepdims=True)
    elev = np.arcsin(np.clip(d[..., 1], -1, 1))
    upk = np.clip(elev / np.radians(70), 0, 1)[..., None] ** 0.6
    sky = HORIZON * (1 - upk) + ZENITH * upk
    # the city glow: strongest on the horizon, toward the landmark (Roblox -Z) a little stronger
    az = np.arctan2(d[..., 0], -d[..., 2])
    g = np.exp(-np.clip(elev, 0, None) / np.radians(5.5))[..., None] * (0.42 + 0.18 * np.cos(az))[..., None]
    sky = sky * (1 - g) + GLOW * g
    # a soft warm halo round the Snow Globe (the landmark's floodlights in the haze)
    T = TOWER
    gdir = np.array((0.0, T["globe_z"], -T["dist"]))
    gdir /= np.linalg.norm(gdir)
    ang = np.arccos(np.clip(d @ gdir, -1, 1))
    gr = math.atan2(T["globe_r"], T["dist"])
    halo = (0.5 * np.exp(-np.clip(ang - gr, 0, None) / np.radians(3.2)) * (ang > gr * 0.9))[..., None]
    sky = sky * (1 - halo) + HALO * halo
    down = np.clip(-elev / np.radians(6), 0, 1)[..., None]
    img = sky * (1 - down) + GROUND * down
    return img, d


def stars(img, d, alpha, name, n, sd, sb):
    f, r, up = (np.array(x, float) for x in FACES[name])
    dots = sd @ f
    ok = dots > 1e-6
    for s, b in zip(sd[ok], sb[ok]):
        p = s / (s @ f)
        px, py = int((p @ r + 1) / 2 * n), int((1 - (p @ up)) / 2 * n)
        if 0 <= px < n and 0 <= py < n and alpha[py, px] < 0.01:
            img[py, px] = img[py, px] * (1 - b) + np.array((235, 235, 255)) * b
            if b > 0.6 and px + 1 < n and alpha[py, px + 1] < 0.01:    # a few brighter stars get a second pixel
                img[py, px + 1] = img[py, px + 1] * (1 - b * 0.5) + np.array((235, 235, 255)) * b * 0.5


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--samples", type=int, default=16)
    a = ap.parse_args()
    n = a.size
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    s, cam = setup(n, a.samples)
    rng = random.Random(1225)
    city(rng)
    tower(rng)
    srng = np.random.default_rng(7)
    sd = srng.normal(size=(1600, 3))
    sd /= np.linalg.norm(sd, axis=1, keepdims=True)
    sd = sd[np.degrees(np.arcsin(sd[:, 1])) > STAR_MIN_ELEV]
    sb = srng.uniform(0.2, 0.8, size=len(sd))
    faces = {}
    for name, (f, r, up) in FACES.items():
        fb, rb, ub = to_blender(f), to_blender(r), to_blender(up)
        m = Matrix((rb, ub, -fb)).transposed()       # columns: camera X = right, Y = up, Z = -forward
        cam.matrix_world = m.to_4x4()
        raw = os.path.join(TMP, f"{name}.png")
        s.render.filepath = raw
        bpy.ops.render.render(write_still=True)
        rgba = np.asarray(Image.open(raw).convert("RGBA"), float)
        alpha = rgba[..., 3:4] / 255.0
        bg, d = background(name, n, srng)
        stars(bg, d, alpha[..., 0], name, n, sd, sb)
        img = rgba[..., :3] * alpha + bg * (1 - alpha)
        out = np.clip(img, 0, 255).astype(np.uint8)
        path = os.path.join(OUT, f"EH_SkyCity_{name}.png")
        Image.fromarray(out).save(path, optimize=True)
        faces[name] = out
        print("wrote", os.path.relpath(path, REPO))
    # preview: Lf Ft Rt Bk strip (a 360 pan, Ft in the middle-left), Up above Ft, Dn below
    p = n // 2
    small = {k: Image.fromarray(v).resize((p, p), Image.LANCZOS) for k, v in faces.items()}
    sheet = Image.new("RGB", (p * 4, p * 3), (20, 20, 30))
    for i, k in enumerate(("Lf", "Ft", "Rt", "Bk")):
        sheet.paste(small[k], (i * p, p))
    sheet.paste(small["Up"], (p, 0))
    sheet.paste(small["Dn"], (p, 2 * p))
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    sheet.save(PREVIEW, optimize=True)
    print("wrote", os.path.relpath(PREVIEW, REPO))


if __name__ == "__main__":
    main()
