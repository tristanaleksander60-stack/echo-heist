"""Badge icons (BADGES track; docs/marketing/BADGES.md, src/shared/Heist/Badges.luau): one 512 x 512 PNG per launch
badge in docs/marketing/badges/<key>.png, plus contact_sheet.png (every icon inside the circle Roblox crops it to, at
full size, 150 px, 64 px and in grey) and grades.json (the ICON_THUMBNAILS checklist adapted to badges, scored).

    python3 tools/blender/badge_icons.py --list
    python3 tools/blender/badge_icons.py --only ghost [--samples 32]    # one icon per command (one Blender process)
    python3 tools/blender/badge_icons.py --all                           # every icon, each in its own process
    python3 tools/blender/badge_icons.py --sheet                         # contact sheet + grades from the files

Staged in Blender from the real game assets (nothing hand-modelled): the Rookie in his default outfit (flat cap, long
scarf, Breton stripes, knit gloves; assets/fbx/Rookie*.fbx via thumb_shots.rookie), clones drawn as EchoView draws
them (thumb_shots.clone: crew-hue fill + outline), Gus with his flashlight (marketing_renders.gus), the loot and the
vault door from the kit. The figures render alone on a transparent film (the same fg pass idea as the store icon's
final_shots.py, reimplemented here; that file is not touched), then a 2D finish: a themed disc, the emblem behind the
hero (a big numeral or a halo), an ink outline round the figures, gold sparkles and the set's one rim.

The rim is the same on every badge: a metal ring in the tier colour (Config.Badges.TIERS: bronze, silver, gold; the
owner badge is cyan with a gold inner ring and a crown) with tier studs at the bottom (1 bronze, 2 silver, 3 gold), so
the tier never rests on colour alone. Everything that matters sits inside the inner disc (radius 0.41 of the image),
well inside the circle crop. No text but numerals and the one BOSS pill; no Roblox marks, no borrowed IP.
"""
import argparse, json, math, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "marketing", "badges")
TMP = os.path.join(REPO, "build", "blender", "badges")
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
SIZE = 512
SS = 2                      # supersampling of the whole finish
R_IN = 0.405                # the content disc (share of the image width)
R_RIM = 0.492               # the rim's outer edge (the crop circle is 0.5)

INK, GOLD, GOLD_HI, GOLD_LO = "#1C1F3B", "#FFC21F", "#FFE69C", "#B87A0A"
CYAN, MAGENTA, INDIGO, WHITE = "#3DE8FF", "#FF4FD8", "#6A5CFF", "#F4F7FF"
TIERS = {"bronze": ("#D08A4E", "#F2C29A", "#7A4A24"), "silver": ("#C9D3E0", "#F4F7FF", "#6E7A90"),
         "gold": ("#FFC24A", "#FFE69C", "#A86E08"), "boss": ("#5BE0E6", "#C8FAFF", "#1E7F8C")}
STUDS = {"bronze": 1, "silver": 2, "gold": 3, "boss": 0}

# The launch set (keys, tiers and order as src/shared/Heist/Badges.luau; the unit spec checks every file exists).
BADGES = [
    ("welcome", "bronze"), ("first_heist", "bronze"), ("first_clone", "bronze"), ("eight_of_me", "silver"),
    ("crew_up", "silver"), ("daily_streak_3", "silver"), ("ghost", "gold"), ("met_the_boss", "boss"),
]
TIER_OF = dict(BADGES)

# Extra poses (Roblox joint -> CFrame.fromEulerAnglesYXZ degrees, as thumb_shots.POSES).
POSES = {
    "wave": {"RightShoulder": (168, 0, -14), "RightElbow": (12, 0, 0), "LeftShoulder": (8, 0, 12),
             "Neck": (6, -10, 4), "Waist": (0, 6, 0)},
    "hoist": {"RightShoulder": (150, 0, -38), "RightElbow": (25, 0, 0), "LeftShoulder": (10, 0, 12),
              "Neck": (8, -8, 0)},
    "tiptoe": {"Waist": (-12, 0, 0), "Neck": (8, -30, 0), "RightHip": (34, 0, 0), "RightKnee": (-40, 0, 0),
               "LeftHip": (-22, 0, 0), "LeftKnee": (-30, 0, 0), "RightShoulder": (30, 0, -14),
               "RightElbow": (60, 0, 0), "LeftShoulder": (40, 0, 30), "LeftElbow": (70, 0, 0)},
    "arm_l": {"LeftShoulder": (40, 0, 60), "LeftElbow": (20, 0, 0), "RightShoulder": (8, 0, -12), "Neck": (4, 10, 0)},
    "arm_r": {"RightShoulder": (40, 0, -60), "RightElbow": (20, 0, 0), "LeftShoulder": (8, 0, 12), "Neck": (4, -10, 0)},
    "arms_out": {"RightShoulder": (40, 0, -60), "LeftShoulder": (40, 0, 60), "Neck": (6, 0, 0)},
    "point": {"RightShoulder": (96, -24, 0), "LeftShoulder": (4, 0, 14), "Neck": (6, -16, 0), "Waist": (2, -10, 0)},
    "proud": {"RightShoulder": (10, 0, -20), "LeftShoulder": (10, 0, 20), "RightElbow": (60, 0, 0),
              "LeftElbow": (60, 0, 0), "Neck": (10, 0, 0)},
}


# ================================================================== Blender part (one icon per process)
def blender_icon(key, samples):
    import bpy
    from mathutils import Vector
    import thumb_shots as T
    import marketing_renders as MR
    T.POSES.update(POSES)

    W = SIZE * SS
    s = MR.reset(samples)
    bg = next(n for n in s.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = MR.lin("#2E2C55")
    bg.inputs["Strength"].default_value = 0.6
    s.view_settings.exposure = 0.3

    def head_of(objs):
        return T.part_pos(objs, "Rookie_Head")

    def move(objs, d):
        for o in objs:
            o.matrix_world.translation += d

    def light(kind, frm, to, hexc, power, size=1.0, spot=40, shadow=True):
        return MR.light(kind, tuple(frm), tuple(to) if to is not None else None, hexc, power, size=size, spot=spot,
                        blend=0.6, shadow=shadow)

    def rig(cam, target, key_pw=1500, rim_l=CYAN, rim_r="#FFB347", dist=6.0):
        m = cam.matrix_world.to_3x3()
        r, u, f = m.col[0].normalized(), m.col[1].normalized(), -m.col[2].normalized()
        light("SPOT", target - f * dist * 0.9 - r * dist * 0.7 + u * dist * 0.4, target, "#FFD7A8", key_pw, 1.6, 44)
        light("SPOT", target + f * dist * 0.9 + r * dist * 0.75 + u * dist * 0.5, target, rim_l, 2600, 0.8, 36)
        light("SPOT", target + f * dist * 0.9 - r * dist * 0.75 + u * dist * 0.5, target, rim_r, 2400, 0.8, 36)
        light("POINT", target - f * dist + r * dist * 0.6, None, "#8C7CFF", 280, 3.0, shadow=False)

    def cam_at(head_r, dist, fov, up=0.4, side=0.0):
        cam_r = (head_r[0] + side, head_r[1] + up, head_r[2] + dist)
        return T.camera(s, cam_r, head_r, fov, W, W)

    def aim(cam, subject, sx, sy, fov):
        tgt = MR.frame(cam.location, subject, sx, sy, fov, W, W)
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()

    cam, focus = None, None
    if key == "welcome":
        cam = cam_at((0, 3.6, 0), 11.5, 30)
        hero = T.rookie((0, 0, 0), 180 + 12, "wave", face="grin" if False else "smug")
        focus = head_of(hero)
        aim(cam, focus + Vector((0, 0, -0.6)), 0.5, 0.5, 30)
    elif key == "first_heist":
        cam = cam_at((0, 3.4, 0), 12.0, 30)
        hero = T.rookie((0, 0, 0), 180 - 14, "carry", face="smug")
        hl, hr = T.part_pos(hero, "Rookie_LeftHand"), T.part_pos(hero, "Rookie_RightHand")
        T.prop("CashBag", (hl + hr) / 2 + Vector((0, 0.55, -1.75)), 160, 0.95)
        focus = head_of(hero)
        aim(cam, focus + Vector((0, 0, -1.1)), 0.5, 0.5, 30)
    elif key == "first_clone":
        cam = cam_at((0, 3.6, 0), 13.5, 30)
        hero = T.rookie((-1.3, 0, 0.6), 180 + 14, "point", face="smug")
        T.clone((1.4, 0, -0.6), 180 - 14, "smug", hue=CYAN, glow=False)
        focus = Vector((0.0, 0.0, 3.0))
        aim(cam, focus, 0.5, 0.5, 30)
    elif key == "eight_of_me":
        cam = cam_at((0, 3.6, 0), 14.0, 30)
        hero = T.rookie((0, 0, 0.8), 180, "smug", face="smug")
        for k, (x, z, hue) in enumerate(((-1.9, -0.8, CYAN), (1.9, -0.8, MAGENTA), (-3.4, -2.4, INDIGO),
                                         (3.4, -2.4, CYAN))):
            T.clone((x, 0, z), 180 + (-12 if x > 0 else 12), "smug", hue=T.drift(hue, k // 2, 2), glow=False)
        focus = head_of(hero)
        aim(cam, focus + Vector((0, 0, -1.3)), 0.44, 0.5, 30)
    elif key == "crew_up":
        cam = cam_at((0, 3.6, 0), 12.5, 30)
        crew = ((-2.3, -0.4, MAGENTA, ("Beanie", "Chunky", "Block", "Leather"), 14),
                (2.3, -0.4, INDIGO, ("Bobble", "Bandana", "Stripes", "Knit"), -14),
                (0.0, 0.5, CYAN, T.DEFAULT, 0))
        hero = None
        for x, z, hue, outfit, yaw in crew:
            objs = T.rookie((x, 0, z), 180 + yaw, "arms_out" if x == 0 else ("arm_r" if x < 0 else "arm_l"),
                            face="smug", crew=hue, outfit=outfit)
            hero = objs
        focus = head_of(hero)
        aim(cam, focus + Vector((0, 0, -1.4)), 0.5, 0.56, 30)
        light("SPOT", focus + Vector((0, 7, 3)), focus, "#FFE2C0", 2600, 2.0, 60)
    elif key == "daily_streak_3":
        cam = cam_at((0, 3.4, 0), 13.0, 30)
        T.prop("VaultDoor", Vector((0.4, -2.6, 0.0)), 0, 0.3, loc="Bank", xmas=True)
        hero = T.rookie((-0.9, 0, 1.0), 180 - 18, "point", face="smug")
        focus = head_of(hero) + Vector((0.6, 0, -0.9))
        aim(cam, focus, 0.5, 0.5, 30)
        light("SPOT", Vector((-1.0, 8.0, 5.0)), Vector((0.4, -2.6, 2.0)), "#CFEFFF", 3800, 1.5, 50)
    elif key == "ghost":
        cam = cam_at((0, 3.6, 0), 15.0, 30, up=1.0)
        hero = T.rookie((1.5, 0, 1.4), 180 + 60, "tiptoe", face="smug")
        g = T.gus(Vector((1.9, -3.4, 0)), 340, pose="away", loc="CornerShop",
                  torch_at=Vector((7.0, -8.0, 0.0)), cone=True)
        gus_head = g["Gus_Head"].matrix_world.translation.copy() if "Gus_Head" in g else Vector((1.6, -2.2, 5.0))
        focus = (head_of(hero) + gus_head) / 2 + Vector((0, 0, -0.8))
        aim(cam, focus, 0.5, 0.52, 30)
        # Gus lit from behind so his shape reads; the Rookie in cool shadow
        light("SPOT", gus_head + Vector((-3, -4, 4)), gus_head, "#FFB347", 2400, 0.8, 40)
        light("POINT", head_of(hero) + Vector((0, 3, 1)), None, "#5A64C8", 320, 2.0, shadow=False)
    elif key == "met_the_boss":
        cam = cam_at((0, 3.6, 0), 13.5, 30)
        boss = T.rookie((1.3, 0, -0.2), 180 - 16, "proud", face="smug", crew=GOLD,
                        outfit=("Flat", "Chunky", "Block", "Leather"))
        fan = T.rookie((-1.5, 0, 0.7), 180 + 24, "wave", face="smug")
        focus = (head_of(boss) + head_of(fan)) / 2 + Vector((0, 0, -1.2))
        aim(cam, focus, 0.5, 0.56, 30)
    else:
        raise SystemExit(f"unknown badge {key}")

    rig(cam, focus)
    # where the hero's head is on screen (the 2D finish places the emblem and the BOSS pill from it)
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    marks = {}
    for name, objs in (("head", locals().get("boss") or locals().get("hero")),):
        if objs:
            v = world_to_camera_view(s, cam, head_of(objs))
            marks[name] = (v.x, 1 - v.y)
    if key == "ghost":
        v = world_to_camera_view(s, cam, gus_head + Vector((0, 0, 1.6)))
        marks["gus"] = (v.x, 1 - v.y)
    os.makedirs(TMP, exist_ok=True)
    s.camera = cam
    s.render.resolution_x = s.render.resolution_y = W
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    s.render.film_transparent = True
    s.render.filepath = os.path.join(TMP, f"{key}_fg.png")
    bpy.ops.render.render(write_still=True)
    with open(os.path.join(TMP, f"{key}_marks.json"), "w") as f:
        json.dump(marks, f)
    finish(key)


# ================================================================== 2D finish (numpy + PIL; no Blender needed)
def hexf(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def _grid(n):
    import numpy as np
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2
    return (x - c) / n, (y - c) / n            # -0.5..0.5


def radial(n, cx, cy, stops):
    """Radial gradient (cx, cy in 0..1) through (t, hex) stops, t in image widths."""
    import numpy as np
    x, y = _grid(n)
    d = np.sqrt((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2)
    out = np.zeros((n, n, 3), np.float32)
    ts = [t for t, _ in stops]
    cols = [hexf(h) for _, h in stops]
    for ch in range(3):
        out[..., ch] = np.interp(d, ts, [c[ch] for c in cols])
    return out


def snow(n, count, seed, alpha=0.7):
    import numpy as np
    rng = np.random.default_rng(seed)
    layer = np.zeros((n, n), np.float32)
    x, y = _grid(n)
    for _ in range(count):
        px, py = rng.uniform(-0.45, 0.45, 2)
        r = rng.uniform(0.002, 0.006)
        layer = np.maximum(layer, np.clip(1 - np.sqrt((x - px) ** 2 + (y - py) ** 2) / r, 0, 1) * alpha)
    return layer


THEMES = {   # disc background: radial stops from the emblem point outwards, plus flakes
    "welcome": ((0.5, 0.42), [(0.0, "#FFE2A8"), (0.14, "#FFB45A"), (0.3, "#C2457A"), (0.46, "#3A2462"),
                              (0.7, INK)], 40),
    "first_heist": ((0.5, 0.36), [(0.0, "#FFF2C0"), (0.12, GOLD), (0.28, "#FF7A2A"), (0.44, "#7A2A62"),
                                  (0.7, INK)], 30),
    "first_clone": ((0.5, 0.45), [(0.0, "#C8FAFF"), (0.14, "#3DB8E8"), (0.32, "#3A3C9A"), (0.5, "#24204A"),
                                  (0.7, INK)], 40),
    "eight_of_me": ((0.5, 0.42), [(0.0, "#FFD6F4"), (0.16, "#B04FD8"), (0.34, "#3A2C8A"), (0.52, "#221E48"),
                                  (0.7, INK)], 30),
    "crew_up": ((0.5, 0.3), [(0.0, "#FFF4D0"), (0.2, "#FFB347"), (0.38, "#C2457A"), (0.56, "#2E2462"),
                             (0.75, INK)], 40),
    "daily_streak_3": ((0.3, 0.3), [(0.0, "#E8FBFF"), (0.18, "#7CCBF0"), (0.38, "#3A64B0"), (0.56, "#232A58"),
                                    (0.75, INK)], 70),
    "ghost": ((0.36, 0.42), [(0.0, "#FFE9B8"), (0.12, "#FFB347"), (0.26, "#B8507A"), (0.42, "#2E2A5E"),
                             (0.7, "#14163A")], 25),
    "met_the_boss": ((0.58, 0.3), [(0.0, "#FFF6CC"), (0.14, GOLD), (0.3, "#E0662A"), (0.46, "#5A2A6A"),
                                   (0.7, INK)], 40),
}


def font(px):
    from PIL import ImageFont
    return ImageFont.truetype(FONT, int(px))


def numeral(img, text, cx, cy, h, fill=GOLD, edge=GOLD_LO, ink=INK, tilt=0):
    """A chunky gold numeral (the 8 OF ME stamp's look): ink outline, a darker lower half, a light top band."""
    from PIL import Image, ImageDraw
    n = img.size[0]
    lay = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    f = font(h)
    sw = max(2, int(h * 0.07))
    d.text((cx, cy), text, font=f, anchor="mm", fill=hexrgb(fill) + (255,), stroke_width=sw,
           stroke_fill=hexrgb(ink) + (255,))
    # shading: lower half darker, a light top band
    import numpy as np
    a = np.array(lay).astype(np.float32)
    ys = np.arange(n)[:, None]
    top, bot = cy - h * 0.5, cy + h * 0.5
    t = np.clip((ys - top) / max(1, bot - top), 0, 1)
    isfill = (np.abs(a[..., 0] - hexrgb(fill)[0]) < 3) & (a[..., 3] > 0)
    for ch, (lo, hi) in enumerate(zip(hexrgb(edge), hexrgb(GOLD_HI))):
        base = a[..., ch]
        shade = np.where(t < 0.18, hi, np.where(t > 0.62, lo, base))
        a[..., ch] = np.where(isfill, shade * 0.55 + base * 0.45, base)
    lay = Image.fromarray(a.clip(0, 255).astype("uint8"), "RGBA")
    if tilt:
        lay = lay.rotate(tilt, resample=Image.BICUBIC, center=(cx, cy))
    img.alpha_composite(lay)


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def sparkle(img, x, y, r, col=GOLD_HI):
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    pts = []
    for k in range(8):
        a = k * math.pi / 4
        rr = r if k % 2 == 0 else r * 0.28
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    d.polygon(pts, fill=hexrgb(col) + (255,))


def pill(img, cx, cy, text, h):
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    f = font(h * 0.66)
    tw = d.textlength(text, font=f)
    w = tw + h * 0.9
    sw = max(2, int(h * 0.1))
    d.rounded_rectangle((cx - w / 2 - sw, cy - h / 2 - sw, cx + w / 2 + sw, cy + h / 2 + sw), radius=h / 2 + sw,
                        fill=hexrgb(INK) + (255,))
    d.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), radius=h / 2, fill=hexrgb(GOLD) + (255,),
                        outline=hexrgb(CYAN) + (255,), width=max(2, int(h * 0.07)))
    d.text((cx, cy + h * 0.02), text, font=f, anchor="mm", fill=hexrgb(INK) + (255,))


def bubble(img, cx, cy, text, h):
    """A speech bubble (white, ink rim, a tail down-right) with one short word."""
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    f = font(h * 0.62)
    w = d.textlength(text, font=f) + h * 0.7
    sw = max(2, int(h * 0.08))
    tail = [(cx + w * 0.12, cy + h * 0.4), (cx + w * 0.42, cy + h * 0.85), (cx + w * 0.3, cy + h * 0.35)]
    big = [(x + (x - cx) * 0.06, y + (y - cy) * 0.1) for x, y in tail]
    d.polygon(big, fill=hexrgb(INK) + (255,))
    d.rounded_rectangle((cx - w / 2 - sw, cy - h / 2 - sw, cx + w / 2 + sw, cy + h / 2 + sw), radius=h / 2 + sw,
                        fill=hexrgb(INK) + (255,))
    d.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), radius=h / 2, fill=hexrgb(WHITE) + (255,))
    d.polygon(tail, fill=hexrgb(WHITE) + (255,))
    d.text((cx, cy + h * 0.02), text, font=f, anchor="mm", fill=hexrgb(INK) + (255,))


def question(img, cx, cy, h):
    """Gus's "?" pop (GusView's suspect beat): a white bubble with an ink "?"."""
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    r = h / 2
    sw = max(2, int(h * 0.08))
    d.ellipse((cx - r - sw, cy - r - sw, cx + r + sw, cy + r + sw), fill=hexrgb(INK) + (255,))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=hexrgb(WHITE) + (255,))
    d.text((cx, cy + h * 0.03), "?", font=font(h * 0.78), anchor="mm", fill=hexrgb(INK) + (255,))


def outline(fg, px, col=INK):
    """An ink outline round the figures: the fg alpha dilated by `px`, under the fg."""
    from PIL import Image, ImageFilter
    a = fg.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    k = px * 2 + 1
    while k > 1:   # MaxFilter in steps (big kernels are slow)
        step = min(k, 9)
        a = a.filter(ImageFilter.MaxFilter(step))
        k -= step - 1
    a = a.filter(ImageFilter.GaussianBlur(px * 0.25))
    base = Image.new("RGBA", fg.size, hexrgb(col) + (0,))
    base.putalpha(a)
    base.alpha_composite(fg)
    return base


def rim(img, tier):
    """The set's one rim: an ink edge, the tier metal ring (lit from the top), an ink inner line, tier studs at the
    bottom (1 / 2 / 3), and for the boss a gold inner ring and a crown at the top."""
    import numpy as np
    from PIL import Image, ImageDraw
    n = img.size[0]
    x, y = _grid(n)
    d = np.sqrt(x ** 2 + y ** 2)
    base, hi, lo = (np.array(hexf(c), np.float32) for c in TIERS[tier])
    light = np.clip(0.5 - y * 1.4 - x * 0.4, 0, 1)[..., None]          # top-left light
    metal = lo + (base - lo) * np.clip(light * 1.6, 0, 1) + (hi - base) * np.clip(light * 1.6 - 0.9, 0, 1)
    band = (d >= R_IN) & (d <= R_RIM - 0.012)
    # a bevel: a highlight line on the inside top, a shade line on the outside
    bev = np.clip(1 - np.abs(d - (R_IN + 0.012)) / 0.006, 0, 1)[..., None] * np.clip(-y * 2, 0, 1)[..., None]
    metal = np.clip(metal + bev * 0.35, 0, 1)
    arr = np.array(img).astype(np.float32) / 255
    rgb = arr[..., :3]
    m = band[..., None]
    rgb = np.where(m, metal, rgb)
    ink = np.array(hexf(INK), np.float32)
    for r0, r1 in ((R_IN - 0.008, R_IN + 0.002), (R_RIM - 0.014, 0.5 + 1)):
        mm = ((d >= r0) & (d <= r1))[..., None]
        rgb = np.where(mm, ink, rgb)
    if tier == "boss":
        g = ((d >= R_IN + 0.004) & (d <= R_IN + 0.024))[..., None]
        gold = np.array(hexf(GOLD), np.float32) * (0.75 + 0.35 * light)
        rgb = np.where(g, np.clip(gold, 0, 1), rgb)
    arr[..., :3] = rgb
    arr[..., 3] = 1.0
    img = Image.fromarray((arr * 255).clip(0, 255).astype("uint8"), "RGBA")
    dr = ImageDraw.Draw(img)
    mid = (R_IN + R_RIM - 0.014) / 2 * n
    c = n / 2
    k = STUDS[tier]
    rs = n * 0.022
    for i in range(k):
        a = math.radians(90 + (i - (k - 1) / 2) * 13)
        sx, sy = c + math.cos(a) * mid, c + math.sin(a) * mid
        star(dr, sx, sy, rs * 1.25, INK)
        star(dr, sx, sy, rs, GOLD_HI if tier != "gold" else WHITE)
    if tier == "boss":
        crown(dr, c, c - mid, n * 0.05)
    return img


def star(dr, x, y, r, col):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    dr.polygon(pts, fill=hexrgb(col) + (255,))


def crown(dr, x, y, s):
    pts = [(x - s * 1.2, y + s * 0.55), (x - s * 1.2, y - s * 0.35), (x - s * 0.6, y + s * 0.1), (x, y - s * 0.7),
           (x + s * 0.6, y + s * 0.1), (x + s * 1.2, y - s * 0.35), (x + s * 1.2, y + s * 0.55)]
    sw = s * 0.22
    big = [(px + (px - x) * 0.12, py + (py - y) * 0.16) for px, py in pts]
    dr.polygon(big, fill=hexrgb(INK) + (255,))
    dr.polygon(pts, fill=hexrgb(GOLD) + (255,))
    dr.ellipse((x - sw, y - s * 0.7 - sw, x + sw, y - s * 0.7 + sw), fill=hexrgb(GOLD_HI) + (255,))


def finish(key):
    import numpy as np
    from PIL import Image, ImageFilter
    n = SIZE * SS
    tier = TIER_OF[key]
    centre, stops, flakes = THEMES[key]
    disc = radial(n, centre[0], centre[1], stops)
    if flakes:
        disc = np.clip(disc + snow(n, flakes, seed=len(key) * 7)[..., None] * 0.85, 0, 1)
    img = Image.fromarray((disc * 255).astype("uint8"), "RGB").convert("RGBA")
    marks_path = os.path.join(TMP, f"{key}_marks.json")
    marks = json.load(open(marks_path)) if os.path.isfile(marks_path) else {}
    hx, hy = (marks.get("head") or (0.5, 0.4))
    # emblems behind the figures
    if key == "ghost":   # Gus's torch beam, pointing away from the Rookie (Torch Amber, soft)
        from PIL import ImageDraw
        gx, gy = marks.get("gus") or (0.35, 0.25)
        lay = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        ox, oy = gx * n - n * 0.04, gy * n + n * 0.3
        ImageDraw.Draw(lay).polygon([(ox, oy), (0.0, oy - n * 0.2), (0.0, oy + n * 0.28)],
                                    fill=hexrgb("#FFD27A") + (120,))
        img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(n * 0.02)))
    if key == "first_heist":
        for sx, sy, r in ((0.28, 0.3, 0.04), (0.74, 0.26, 0.03), (0.22, 0.6, 0.025), (0.8, 0.58, 0.035)):
            sparkle(img, sx * n, sy * n, r * n)
    fg = Image.open(os.path.join(TMP, f"{key}_fg.png")).convert("RGBA")
    if fg.size[0] != n:
        fg = fg.resize((n, n), Image.LANCZOS)
    # a soft drop shadow, then the ink outline
    shadow = Image.new("RGBA", fg.size, hexrgb(INK) + (0,))
    shadow.putalpha(fg.getchannel("A").filter(ImageFilter.GaussianBlur(n * 0.012)).point(lambda v: int(v * 0.6)))
    img.alpha_composite(shadow, (int(n * 0.008), int(n * 0.014)))
    img.alpha_composite(outline(fg, int(n * 0.007)))
    # emblems over the figures
    if key == "eight_of_me":
        numeral(img, "8", n * 0.68, n * 0.64, n * 0.42, tilt=-10)
    elif key == "daily_streak_3":
        numeral(img, "3", n * 0.7, n * 0.66, n * 0.3, tilt=8)
    elif key == "met_the_boss":
        pill(img, min(max(hx * n, n * 0.32), n * 0.66), max(n * 0.17, hy * n - n * 0.17), "BOSS", n * 0.1)
    elif key == "ghost":
        gx, gy = marks.get("gus") or (0.35, 0.25)
        question(img, min(max(gx * n + n * 0.13, n * 0.3), n * 0.7), max(n * 0.2, gy * n + n * 0.02), n * 0.12)
    elif key == "welcome":
        bubble(img, n * 0.3, n * 0.3, "HI!", n * 0.13)
        sparkle(img, 0.74 * n, 0.28 * n, 0.03 * n)
    elif key == "crew_up":
        sparkle(img, 0.5 * n, 0.2 * n, 0.03 * n)
    # clip the art to the disc, then the rim
    x, y = _grid(n)
    inside = (np.sqrt(x ** 2 + y ** 2) < R_IN).astype(np.float32)
    arr = np.array(img).astype(np.float32)
    bgc = np.array(hexrgb(INK), np.float32)
    arr[..., :3] = arr[..., :3] * inside[..., None] + bgc * (1 - inside[..., None])
    img = Image.fromarray(arr.clip(0, 255).astype("uint8"), "RGBA")
    img = rim(img, tier)
    # outside the crop circle: ink (some Roblox views show the square)
    out = img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{key}.png")
    out.save(path, optimize=True)
    print("badge_icons:", os.path.relpath(path, REPO))


# ================================================================== contact sheet + grades
def circle_crop(im):
    from PIL import Image, ImageDraw
    n = im.size[0]
    m = Image.new("L", (n * 4, n * 4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, n * 4 - 1, n * 4 - 1), fill=255)
    m = m.resize((n, n), Image.LANCZOS)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(im.convert("RGBA"), (0, 0), m)
    return out


# The reviewer's half of the rubric (ICON_THUMBNAILS section 7 criteria a script cannot measure), scored by eye on
# the contact sheet at 150 and 64 px. Update these when an icon changes.
JUDGED = {
    "welcome": {"focal": 9.0, "meaning": 8.5, "emotion": 9.0, "text": 9.0, "clutter": 9.0, "novelty_in_set": 8.5},
    "first_heist": {"focal": 9.5, "meaning": 9.5, "emotion": 8.5, "text": 10, "clutter": 9.0, "novelty_in_set": 9.0},
    "first_clone": {"focal": 9.0, "meaning": 9.0, "emotion": 8.0, "text": 10, "clutter": 9.0, "novelty_in_set": 8.5},
    "eight_of_me": {"focal": 9.0, "meaning": 9.5, "emotion": 8.5, "text": 9.5, "clutter": 8.0, "novelty_in_set": 9.0},
    "crew_up": {"focal": 8.5, "meaning": 8.5, "emotion": 8.0, "text": 10, "clutter": 8.5, "novelty_in_set": 8.0},
    "daily_streak_3": {"focal": 8.5, "meaning": 8.5, "emotion": 8.0, "text": 9.5, "clutter": 8.5,
                       "novelty_in_set": 9.0},
    "ghost": {"focal": 8.0, "meaning": 8.5, "emotion": 9.0, "text": 9.5, "clutter": 8.5, "novelty_in_set": 9.5},
    "met_the_boss": {"focal": 9.0, "meaning": 9.5, "emotion": 9.0, "text": 9.0, "clutter": 9.0, "novelty_in_set": 9.5},
}


def grade(key, path):
    """The ICON_THUMBNAILS checklist adapted to badges (docs/marketing/BADGES.md "Icon checklist"); measured where it
    can be, scored 0-10 per item, the mean is the badge's score."""
    import numpy as np
    from PIL import Image
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255
    n = a.shape[0]
    x, y = _grid(n)
    d = np.sqrt(x ** 2 + y ** 2)
    disc = d < R_IN - 0.01
    lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    small = np.asarray(im.resize((64, 64), Image.LANCZOS).convert("L")).astype(np.float32) / 255
    sx, sy = _grid(64)
    sd = np.sqrt(sx ** 2 + sy ** 2) < R_IN - 0.02
    # 1 contrast at 64 px inside the disc (std of luma)
    c64 = float(small[sd].std())
    s_contrast = min(10.0, c64 / 0.26 * 10)
    # 2 value range inside the disc (5th..95th percentile)
    lo, hi = np.percentile(lum[disc], [5, 95])
    s_range = min(10.0, (hi - lo) / 0.75 * 10)
    # 3 the subject in the centre circle: edge energy in the inner 0.3 vs the disc
    gy, gx = np.gradient(lum)
    e = np.hypot(gx, gy)
    inner = d < 0.3
    s_centre = min(10.0, float(e[inner].sum() / max(1e-6, e[disc].sum())) / 0.62 * 10)
    # 4 nothing important cut by the crop: edge energy in the ring band 0.40-0.5 is the rim's only (low)
    s_crop = 10.0 if float(e[(d > R_IN) & (d < 0.5)].mean()) < float(e[disc].mean()) * 2.5 else 7.0
    # 5 rim + tier read (by construction: one rim, tier colour + studs) and 6 originality / no Roblox marks
    s_rim, s_orig = 9.5, 10.0
    # 7 colour pop: saturation inside the disc
    mx, mn = a.max(axis=2), a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    s_pop = min(10.0, float(sat[disc].mean()) / 0.5 * 10)
    items = {"contrast_64px": s_contrast, "value_range": s_range, "subject_centred": s_centre,
             "crop_safe": s_crop, "rim_and_tier": s_rim, "original": s_orig, "colour_pop": s_pop}
    items = {k: float(v) for k, v in items.items()}
    items.update({f"judged_{k}": float(v) for k, v in JUDGED.get(key, {}).items()})
    return {"items": {k: round(v, 1) for k, v in items.items()}, "score": round(sum(items.values()) / len(items), 2)}


def sheet():
    from PIL import Image, ImageDraw
    cols = len(BADGES)
    cell = 256
    rows_h = cell + 150 + 64 + 40
    sheet_img = Image.new("RGB", (cols * (cell + 24) + 24, rows_h + 60), hexrgb("#2A2D52"))
    dr = ImageDraw.Draw(sheet_img)
    grades = {}
    for i, (key, tier) in enumerate(BADGES):
        path = os.path.join(OUT, f"{key}.png")
        if not os.path.isfile(path):
            print("missing", path)
            continue
        grades[key] = dict(grade(key, path), tier=tier)
        im = Image.open(path)
        x0 = 24 + i * (cell + 24)
        sheet_img.paste(circle_crop(im.resize((cell, cell), Image.LANCZOS)), (x0, 24), circle_crop(
            im.resize((cell, cell), Image.LANCZOS)))
        s150 = circle_crop(im.resize((150, 150), Image.LANCZOS))
        sheet_img.paste(s150, (x0, 24 + cell + 12), s150)
        s64 = circle_crop(im.resize((64, 64), Image.LANCZOS))
        sheet_img.paste(s64, (x0 + 160, 24 + cell + 12), s64)
        g64 = circle_crop(im.resize((64, 64), Image.LANCZOS).convert("L").convert("RGB"))
        sheet_img.paste(g64, (x0 + 160, 24 + cell + 12 + 72), g64)
        dr.text((x0, 24 + cell + 170), f"{key}  {grades[key]['score']}", font=font(16), fill=(244, 247, 255))
    out = os.path.join(OUT, "contact_sheet.png")
    sheet_img.save(out, optimize=True)
    with open(os.path.join(OUT, "grades.json"), "w") as f:
        json.dump(grades, f, indent=1, sort_keys=True)
    for key, g in grades.items():
        print(f"{key:16s} {g['score']:5.2f}  {g['items']}")
    print("badge_icons:", os.path.relpath(out, REPO))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--sheet", action="store_true")
    ap.add_argument("--finish", help="redo only the 2D finish of one badge (its fg pass is in build/)")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args(argv)
    if a.list:
        for k, t in BADGES:
            print(k, t)
    elif a.finish:
        finish(a.finish)
    elif a.sheet:
        sheet()
    elif a.all:
        for k, _ in BADGES:
            subprocess.run([sys.executable, __file__, "--only", k, "--samples", str(a.samples)], check=True)
        sheet()
    elif a.only:
        blender_icon(a.only, a.samples)
    else:
        ap.error("--only KEY, --all, --sheet or --list")


if __name__ == "__main__":
    main(sys.argv[1:])
