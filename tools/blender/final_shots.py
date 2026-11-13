"""The FINAL store art (docs/marketing/final/, UPLOAD.md): 3 icons (512 x 512) and 4 thumbnails (1920 x 1080), staged
in Blender from the real game assets and finished in 2D the way top Roblox store art is (ICON_THUMBNAILS.md 0.1).

    python3 tools/blender/final_shots.py --list
    python3 tools/blender/final_shots.py --only icon_1 [--scale 0.5] [--samples 24]   # one image per command
    python3 tools/blender/final_shots.py --grade          # grades.json + readability.png (64 / 150 px, grey)

What is real (nothing hand-modelled): the Rookie and his outfit pieces from the kit (assets/fbx/Rookie*.fbx, the
Santa cap is Rookie_Cap_Santa, Config.Rookie.OUTFIT.Cap_Santa), clones drawn as EchoView draws them (thumb_shots.clone
-> intro_shots.clone_look: crew-hue fill + outline), Gus in his Santa hat with his flashlight cone, the loot (CashBag,
GoldStack, Present, Intro_Present_*), the story town with Hoardsworth Tower, the Snow Globe Vault and the game's
aurora, and level L4 rebuilt by level_shots. Poses are the R15 joint table in thumb_shots.POSES (+ a few here).

What is store-art finish (the "key art" rule, ICON_THUMBNAILS 0.4): hero lighting (key + rim + colour gels), the
background rendered as its own pass and blurred (depth of field), colour gels and a radial glow behind the hero, an
ink outline round the characters, the clones' own-hue glow, gold sparkles, and the Luckiest Guy wordmark text (the
game's display face, Brand.FACE; Apache-2.0, assets/fonts) with the wordmark's cyan double-exposure copy.

Each image renders three passes in one Blender process: bg (characters hidden), fg (characters only, everything else a
holdout, transparent film: occlusion kept) and the ID pass (thumb_shots.id_pass, for the outline and the grades).
"""
import argparse, json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import thumb_shots as T  # noqa: E402
import marketing_renders as MR  # noqa: E402
import intro_shots as IS  # noqa: E402

REPO = T.REPO
FINAL = os.path.join(REPO, "docs", "marketing", "final")
TMP = os.path.join(REPO, "build", "blender", "final")
FONT = os.path.join(REPO, "assets", "fonts", "LuckiestGuy-Regular.woff")
AURORA = os.path.join(REPO, "assets", "sky", "EH_Aurora_A.png")

CYAN, MAGENTA, INDIGO = T.CYAN, T.MAGENTA, T.INDIGO
GOLD, GOLD_HI, INK, WHITE = "#FFC21F", "#FFE69C", "#1C1F3B", "#FFFFFF"
T.CAPS["Santa"] = ["Rookie_Cap_Santa"]          # Config.Rookie.OUTFIT.Cap_Santa (the Christmas unlock)
SANTA = ("Santa", "Long", "Stripes", "Knit")
FG_GROUPS = ("hero", "clone", "loot", "gus")

T.POSES.update({
    # the icon: shoulders square to the camera, head turned, the bag hoisted over the right shoulder
    "icon_bag": {"LeftShoulder": (75, 0, 30), "LeftElbow": (70, 0, 0), "RightShoulder": (10, 0, -12),
                 "Neck": (4, -16, 5), "Waist": (0, 8, 0)},
    "icon_bag_r": {"RightShoulder": (75, 0, -30), "RightElbow": (70, 0, 0), "LeftShoulder": (10, 0, 12),
                   "Neck": (4, 16, -5), "Waist": (0, -8, 0)},
    "icon_gift": {"RightShoulder": (62, 0, 18), "RightElbow": (60, 0, 0), "LeftShoulder": (62, 0, -18),
                  "LeftElbow": (60, 0, 0), "Neck": (4, -16, 5)},
    "fan": {"RightShoulder": (150, 0, -30), "RightElbow": (20, 0, 0), "LeftShoulder": (18, 0, 16),
            "LeftElbow": (30, 0, 0), "Neck": (6, -8, 0)},
    "grab": {"RightShoulder": (70, 10, -10), "RightElbow": (50, 0, 0), "LeftShoulder": (60, -10, 10),
             "LeftElbow": (50, 0, 0), "Neck": (-12, 0, 0), "Waist": (-6, 0, 0)},
    "caught": {"RightShoulder": (160, 0, -26), "LeftShoulder": (160, 0, 26), "RightElbow": (20, 0, 0),
               "LeftElbow": (20, 0, 0), "Neck": (12, 0, 0), "RightHip": (10, 0, 0), "LeftHip": (-6, 0, 0)},
    "tiptoe": {"Waist": (-12, 0, 0), "Neck": (8, -30, 0), "RightHip": (34, 0, 0), "RightKnee": (-40, 0, 0),
               "LeftHip": (-22, 0, 0), "LeftKnee": (-30, 0, 0), "RightShoulder": (30, 0, -14),
               "RightElbow": (60, 0, 0), "LeftShoulder": (40, 0, 30), "LeftElbow": (70, 0, 0)},
})


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


# ------------------------------------------------------------------ staging helpers
def cam_basis(cam):
    bpy.context.view_layer.update()
    m = cam.matrix_world.to_3x3()
    return m.col[0].normalized(), m.col[1].normalized(), -m.col[2].normalized()


def screen_point(cam, sx, sy, depth, W, Hh):
    """The world point at screen (sx, sy) (0..1 from the top-left), `depth` studs down the view axis."""
    r, u, f = cam_basis(cam)
    tv = math.tan(cam.data.angle_y / 2)
    X = (2 * sx - 1) * depth * tv * W / Hh
    Y = (1 - 2 * sy) * depth * tv
    return cam.location + f * depth + r * X + u * Y


def move(objs, delta):
    for o in objs:
        o.matrix_world.translation += delta


def head_to(objs, target):
    """Slide a figure so its head centre lands on `target` (Blender coordinates). Returns the delta."""
    d = target - T.part_pos(objs, "Rookie_Head")
    move(objs, d)
    return d


def to_roblox(b):
    """Blender -> Roblox (intro_shots.rb is Roblox -> Blender: (-x, z, y))."""
    return (-b.x, b.z, b.y)


def figure_at(build, head_b, floor_y=0.0):
    """Build a figure (and whatever props `build` adds) and slide everything it made so its head sits over the
    screen point `head_b` horizontally, feet on the floor. Returns (objects, head position)."""
    before = set(bpy.data.objects)
    objs = build()
    new = [o for o in set(bpy.data.objects) - before]
    hp = T.part_pos(objs, "Rookie_Head")
    d = Vector((head_b.x - hp.x, head_b.y - hp.y, 0.0))
    move(new, d)
    return objs, T.part_pos(objs, "Rookie_Head")


def aim(cam, target):
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()


def light(kind, frm, to, hexc, power, size=1.0, spot=40, shadow=True):
    return MR.light(kind, tuple(frm), tuple(to) if to is not None else None, hexc, power, size=size, spot=spot,
                    blend=0.6, shadow=shadow)


def hero_rig(hp, cam, key=(-0.8, 0.35, 0.9), key_col="#FFD7A8", key_pw=1400, rims=(("#5FE6FF", 1.0, 2600),
             ("#FFB347", -1.0, 2600)), fill_col="#8C7CFF", fill_pw=250, dist=5.0, scale=1.0):
    """Key (warm, front and to one side, above), two rims from behind (colour gels, one per side) and a soft
    violet fill: the hero lighting of top Roblox art. Powers in W at `dist` studs; `scale` for a bigger set."""
    r, u, f = cam_basis(cam)
    k = Vector(key)
    frm = hp - f * dist * k.z + r * dist * k.x + u * dist * k.y
    light("SPOT", frm, hp, key_col, key_pw * scale, size=1.6, spot=40)
    for col, side, pw in rims:
        frm = hp + f * dist * 0.9 + r * dist * 0.7 * side + u * dist * 0.55
        light("SPOT", frm, hp, col, pw * scale, size=0.8, spot=34)
    light("POINT", hp - f * dist + u * 0.2 - r * dist * 0.6, None, fill_col, fill_pw * scale, size=3.0, shadow=False)


def empty_stage(samples, ambient="#2E2C55", strength=0.55):
    """No set: the figures alone under an indigo ambient (the icon's background is made in 2D)."""
    s = MR.reset(samples)
    bg = next(n for n in s.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = MR.lin(ambient)
    bg.inputs["Strength"].default_value = strength
    s.view_settings.exposure = 0.25
    return s


# ------------------------------------------------------------------ passes
def render_passes(s, cam, name, bg=True):
    os.makedirs(TMP, exist_ok=True)
    s.camera = cam
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    fg = [o for o in bpy.data.objects if o.get("eh_group") in FG_GROUPS]
    if bg:
        for o in fg:
            o.hide_render = True
        s.render.film_transparent = False
        s.render.filepath = os.path.join(TMP, f"{name}_bg.png")
        bpy.ops.render.render(write_still=True)
        for o in fg:
            o.hide_render = False
    others = [o for o in bpy.data.objects if o.type in ("MESH", "CURVE", "FONT") and o not in fg]
    for o in others:
        o.is_holdout = True
    s.render.film_transparent = True
    s.render.filepath = os.path.join(TMP, f"{name}_fg.png")
    bpy.ops.render.render(write_still=True)
    for o in others:
        o.is_holdout = False
    T.id_pass(s, cam, os.path.join(TMP, f"{name}_ids.png"))


# ------------------------------------------------------------------ 2D finish
def _np():
    import numpy as np
    return np


def blur(a, r):
    """Near-Gaussian blur of a float array (H, W[, C]) with sigma ~r px: three separable box passes (cumsum)."""
    np = _np()
    if r < 0.5:
        return a
    a = a.astype(np.float32)
    k = max(1, int(round(r * 0.9)))      # 3 boxes of half-width k ~ sigma r
    for _ in range(3):
        for ax in (0, 1):
            pad = [(0, 0)] * a.ndim
            pad[ax] = (k + 1, k)
            p = np.pad(a, pad, mode="edge")
            c = np.cumsum(p, axis=ax)
            n = a.shape[ax]
            hi = np.take(c, np.arange(2 * k + 1, 2 * k + 1 + n), axis=ax)
            lo = np.take(c, np.arange(0, n), axis=ax)
            a = (hi - lo) / (2 * k + 1)
    return a


def dilate(mask, r):
    from PIL import Image, ImageFilter
    np = _np()
    if r < 1:
        return mask
    im = Image.fromarray((mask * 255).astype(np.uint8))
    # a round-ish dilation: two passes of a smaller max filter
    k = int(r) | 1
    im = im.filter(ImageFilter.MaxFilter(k if k >= 3 else 3))
    if r > 3:
        im = im.filter(ImageFilter.MaxFilter(k if k >= 3 else 3))
    return np.asarray(im).astype(np.float32) / 255.0


def group_masks(name, size):
    from PIL import Image
    np = _np()
    m = np.asarray(Image.open(os.path.join(TMP, f"{name}_ids.png")).convert("RGBA").resize(size, Image.NEAREST),
                   np.int32)
    out = {}
    for g, col in T.GROUP_COLOURS.items():
        out[g] = (np.all(np.abs(m[..., :3] - np.array(col)) < 40, axis=-1) & (m[..., 3] > 128)).astype(np.float32)
    return out


def radial(W, Hh, cx, cy, r, hexc, power=1.6):
    np = _np()
    yy, xx = np.mgrid[0:Hh, 0:W].astype(np.float32)
    d = np.sqrt(((xx - cx * W) / Hh) ** 2 + ((yy - cy * Hh) / Hh) ** 2) / r
    w = np.clip(1 - d, 0, 1) ** power
    return w[..., None] * (np.array(hexrgb(hexc), np.float32) / 255.0)


def radial_stops(W, Hh, cx, cy, stops, sx=1.0, sy=1.0):
    """A multi-stop radial gradient: stops = [(distance as a share of the height, hex), ...]."""
    np = _np()
    yy, xx = np.mgrid[0:Hh, 0:W].astype(np.float32)
    d = np.sqrt(((xx - cx * W) / (Hh * sx)) ** 2 + ((yy - cy * Hh) / (Hh * sy)) ** 2)
    xs = [t for t, _h in stops]
    out = np.zeros((Hh, W, 3), np.float32)
    for c in range(3):
        out[..., c] = np.interp(d, xs, [hexrgb(h)[c] / 255 for _t, h in stops])
    return out


def vgrad(W, Hh, top, bottom, mid=None):
    np = _np()
    t = np.linspace(0, 1, Hh, dtype=np.float32)[:, None, None]
    a, b = np.array(hexrgb(top), np.float32) / 255, np.array(hexrgb(bottom), np.float32) / 255
    if mid is None:
        g = a * (1 - t) + b * t
    else:
        m = np.array(hexrgb(mid), np.float32) / 255
        g = np.where(t < 0.5, a * (1 - t * 2) + m * t * 2, m * (2 - t * 2) + b * (t * 2 - 1))
    return np.broadcast_to(g, (Hh, W, 3)).copy()


def screen_add(a, b):
    return 1 - (1 - a) * (1 - np_clip(b))


def np_clip(a):
    return _np().clip(a, 0, 1)


def aurora_layer(W, Hh, y0=0.0, h=0.55, alpha=0.6, seed_shift=0.0):
    """The game's aurora curtain texture (assets/sky/EH_Aurora_A.png) stretched across the top, as a gel."""
    from PIL import Image
    np = _np()
    im = Image.open(AURORA).convert("RGBA")
    if seed_shift:
        w0 = im.size[0]
        im = im.crop((int(seed_shift * w0), 0, w0, im.size[1]))
    im = im.resize((W, max(2, int(Hh * h))), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255
    out = np.zeros((Hh, W, 4), np.float32)
    y = int(Hh * y0)
    hh = min(a.shape[0], Hh - y)
    out[y:y + hh] = a[:hh]
    out[..., 3] *= alpha
    return out


def over(dst, rgba):
    """Alpha-over of a straight-alpha float RGBA layer on an RGB float image."""
    a = rgba[..., 3:4]
    return dst * (1 - a) + rgba[..., :3] * a


def snow(W, Hh, n=160, seed=3, size=0.004, alpha=0.75, region=(0, 0, 1, 1)):
    from PIL import Image, ImageDraw, ImageFilter
    import random
    np = _np()
    rnd = random.Random(seed)
    im = Image.new("L", (W, Hh), 0)
    d = ImageDraw.Draw(im)
    for _ in range(n):
        x = rnd.uniform(region[0], region[2]) * W
        y = rnd.uniform(region[1], region[3]) * Hh
        r = rnd.uniform(0.4, 1.0) * size * Hh
        d.ellipse([x - r, y - r, x + r, y + r], fill=int(255 * rnd.uniform(0.5, 1.0)))
    im = im.filter(ImageFilter.GaussianBlur(size * Hh * 0.4))
    return np.asarray(im).astype(np.float32)[..., None] / 255 * alpha


def sparkles(img, pts, Hh):
    """The loot sparkle (gold = sparkle, STYLE_BIBLE 1.3): four-point stars with a soft gold halo."""
    from PIL import Image, ImageDraw, ImageFilter
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d, dh = ImageDraw.Draw(layer), ImageDraw.Draw(halo)
    for x, y, r in pts:
        rr = r * Hh
        dh.ellipse([x - rr * 0.9, y - rr * 0.9, x + rr * 0.9, y + rr * 0.9], fill=hexrgb(GOLD) + (150,))
        for k, rad, col in ((d, rr, hexrgb(GOLD_HI) + (255,)), (d, rr * 0.45, (255, 255, 255, 255))):
            w = rad * 0.2
            k.polygon([(x, y - rad), (x + w, y - w), (x + rad, y), (x + w, y + w), (x, y + rad), (x - w, y + w),
                       (x - rad, y), (x - w, y - w)], fill=col)
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(Hh * 0.012)))
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(0.6)))


def wordmark(img, lines, cap, y, x=0.5, align="c", copy=CYAN, tilt=0.0):
    """Text in the game's wordmark style (src/first/Wordmark: Luckiest Guy, ink stroke, a cyan copy offset behind
    it, Brand.WORDMARK_OFFSET 5,4 at 55 px), plus a soft drop shadow. lines = [[(word, hex), ...], ...]; cap =
    cap height as a share of the image height; y = the first baseline (share of the height)."""
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    W, Hh = img.size
    probe = ImageFont.truetype(FONT, 100)
    bb = probe.getbbox("H", anchor="ls")
    size = int(100 * cap * Hh / max(1, -bb[1]))
    f = ImageFont.truetype(FONT, size)
    stroke = max(4, int(size * 0.085))
    off = (size * 5 / 55 * 1.4, size * 4 / 55 * 1.4)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    copyl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d, dc, ds = ImageDraw.Draw(layer), ImageDraw.Draw(copyl), ImageDraw.Draw(shadow)
    lh = cap * Hh * 1.22
    space = d.textlength(" ", font=f) * 0.75
    boxes = []
    for i, line in enumerate(lines):
        widths = [d.textlength(w, font=f) for w, _c in line]
        total = sum(widths) + space * (len(line) - 1)
        ax = x * W
        cx = {"l": ax, "c": ax - total / 2, "r": ax - total}[align]
        cy = y * Hh + i * lh
        boxes.append((cx, cy - cap * Hh, cx + total, cy))
        for (word, col), w in zip(line, widths):
            ds.text((cx + off[0] * 1.6, cy + off[1] * 2.2), word, font=f, fill=(10, 10, 30, 200), anchor="ls",
                    stroke_width=stroke, stroke_fill=(10, 10, 30, 200))
            if copy:
                dc.text((cx + off[0], cy + off[1]), word, font=f, fill=hexrgb(copy) + (255,), anchor="ls",
                        stroke_width=stroke, stroke_fill=hexrgb(INK) + (255,))
            d.text((cx, cy), word, font=f, fill=hexrgb(col) + (255,), anchor="ls", stroke_width=stroke,
                   stroke_fill=hexrgb(INK) + (255,))
            cx += w + space
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(stroke * 1.2)))
    img = Image.alpha_composite(img, copyl)
    return Image.alpha_composite(img, layer), boxes


def compose(name, out, *, bg_fn, bg_blur=0.0, bg_dim=1.0, bg_sat=1.0, glows=(), gel=None, outline=0.006, hero_outline=None,
            clone_glow=0.03, clone_glow_k=1.0, hero_glow=None, hero_gain=1.0, under=None, hero_halo=None, fg_sat=1.12, drop=0.012, vignette=0.22, post=None,
            supersample=1):
    """bg pass (or a 2D background) -> blur (DOF), grade, glows -> the characters' drop shadow -> clone glow in
    their own hue -> ink outline -> fg -> global grade + vignette -> post(img) (text, sparkles) -> save."""
    from PIL import Image
    np = _np()
    fg = Image.open(os.path.join(TMP, f"{name}_fg.png")).convert("RGBA")
    W, Hh = fg.size
    f = np.asarray(fg).astype(np.float32) / 255
    rgb, alpha = f[..., :3], f[..., 3]
    masks = group_masks(name, (W, Hh))
    bg = bg_fn(W, Hh)
    if bg_blur:
        bg = blur(bg, bg_blur * Hh)
    g = (bg * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(-1, keepdims=True)
    bg = np.clip((g + (bg - g) * bg_sat) * bg_dim, 0, 1)
    if gel:                     # colour gel: (top hex, bottom hex, strength) multiplied in (x2, so mid-grey = neutral)
        gr = vgrad(W, Hh, gel[0], gel[1])
        bg = np.clip(bg * (1 - gel[2]) + np.clip(bg * gr * 2.0, 0, 1) * gel[2], 0, 1)
    for gl in glows:            # (cx, cy, r, hex, strength)
        bg = 1 - (1 - bg) * (1 - np.clip(radial(W, Hh, gl[0], gl[1], gl[2], gl[3]) * gl[4], 0, 1))
    if under:                   # 2D light under the characters (Gus's flashlight beam)
        bg = under(bg)
    # drop shadow: the characters' alpha, blurred and nudged down-right
    if drop:
        sh = blur(alpha, drop * Hh)
        sh = np.roll(np.roll(sh, int(drop * Hh * 0.5), 0), int(drop * Hh * 0.3), 1)
        bg = bg * (1 - 0.55 * sh[..., None])
    # clone glow: the clones' own colours, blurred and added (EchoView's hue, bloom in its own hue)
    cm = masks["clone"] * alpha
    if clone_glow and cm.sum() > 0:
        src = rgb * cm[..., None]
        gl = blur(src, clone_glow * Hh) * 2.2 * clone_glow_k + blur(src, clone_glow * Hh * 0.35) * 1.2 * clone_glow_k
        bg = 1 - (1 - bg) * (1 - np.clip(gl, 0, 1))
    # the hero's warm glow (a gold aura round his silhouette: the "gold glow" of the brief)
    if hero_glow:
        col, rad, k = hero_glow
        hmask = masks["hero"] * alpha
        if hmask.sum() > 0:
            gl = blur(hmask, rad * Hh)[..., None] * (np.array(hexrgb(col), np.float32) / 255) * k
            bg = 1 - (1 - bg) * (1 - np.clip(gl, 0, 1))
    # a dark halo round the hero (value separation: light subject on a darker ring, ICON_THUMBNAILS 0.1 rule 5)
    if hero_halo:
        rad, k = hero_halo
        hmask = masks["hero"] * alpha
        if hmask.sum() > 0:
            ring = np.clip(blur(dilate(hmask, rad * Hh * 0.6), rad * Hh * 0.5) * 1.3, 0, 1)[..., None]
            bg = bg * (1 - k * ring)
    # hero grade (exposure gain on the hero group only) and fg saturation
    hm = masks["hero"][..., None]
    rgb = np.clip(rgb * (1 + (hero_gain - 1) * hm), 0, 1)
    gg = (rgb * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(-1, keepdims=True)
    rgb = np.clip(gg + (rgb - gg) * fg_sat, 0, 1)
    # ink outline round every character (thicker round the hero)
    ink = np.array(hexrgb(INK), np.float32) / 255
    a = alpha > 0.5
    ring = np.clip(dilate(a.astype(np.float32), outline * Hh * 2) - a, 0, 1)
    if hero_outline:
        ha = (masks["hero"] > 0) & a
        ring = np.maximum(ring, np.clip(dilate(ha.astype(np.float32), hero_outline * Hh * 2) - a, 0, 1))
    ring = blur(ring, 0.6)
    img = bg * (1 - ring[..., None]) + ink * ring[..., None]
    img = img * (1 - alpha[..., None]) + rgb * alpha[..., None]
    # global: a little contrast, vignette
    img = np.clip((img - 0.5) * 1.06 + 0.5, 0, 1)
    if vignette:
        yy, xx = np.mgrid[0:Hh, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - Hh / 2) / (Hh / 2)) ** 2) / math.sqrt(2)
        img = img * (1 - vignette * np.clip((r - 0.4) / 0.6, 0, 1) ** 1.5)[..., None]
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    if post:
        im = post(im)
    im = im.convert("RGB")
    if supersample > 1:
        im = im.resize((W // supersample, Hh // supersample), Image.LANCZOS)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out, optimize=True)
    # the grade's masks at the final size
    ids = Image.open(os.path.join(TMP, f"{name}_ids.png"))
    if supersample > 1:
        ids = ids.resize(im.size, Image.NEAREST)
    ids.save(os.path.join(TMP, f"{name}_final_ids.png"))
    print("final_shots:", os.path.relpath(out, REPO), im.size, f"{os.path.getsize(out) / 1e6:.2f} MB")
    return out


def file_bg(name):
    np = _np()
    from PIL import Image

    def fn(W, Hh):
        return np.asarray(Image.open(os.path.join(TMP, f"{name}_bg.png")).convert("RGB").resize((W, Hh)),
                          np.float32) / 255
    return fn


IMAGES = {}


def image(name, kind, size, out):
    def deco(fn):
        IMAGES[name] = (fn, kind, size, out)
        return fn
    return deco


# ------------------------------------------------------------------ icons
def icon_stage(samples, W, copies, pose="icon_bag", carry="CashBag", face_at=(0.6, 0.47), fov=30.0, yaw_off=22,
               dist=8.2, cam_up=0.5, cam_side=-0.15):
    """The Rookie's head and shoulders in his Santa cap, copies of him behind (the wordmark's double-exposure
    offset), each a step further back so they read smaller; no set (the background is 2D)."""
    s = empty_stage(samples)
    hero_at = (0.0, 0.0, 0.0)
    head_r = (0.0, 4.0, 0.0)
    cam_r = (head_r[0] + dist * math.sin(math.radians(cam_side * 60)), head_r[1] + cam_up, head_r[2] + dist)
    cam = T.camera(s, cam_r, head_r, fov, W, W)
    hero = T.rookie(hero_at, 180 + yaw_off, pose, face="smug", outfit=SANTA)
    if carry == "CashBag":
        side = "Right" if pose.endswith("_r") else "Left"
        T.in_hand(hero, "CashBag", side, drop=0.8, yaw=20 if side == "Right" else -20, scale=0.8)
    elif carry:
        hl, hr = T.part_pos(hero, "Rookie_LeftHand"), T.part_pos(hero, "Rookie_RightHand")
        drop, sc = (0.55, 0.45) if carry == "GoldStack" else (0.75, 0.75)
        T.prop(carry, (hl + hr) / 2 + Vector((0, -0.35, -drop)), 20, sc)
    hp = T.part_pos(hero, "Rookie_Head")
    tgt = MR.frame(cam.location, hp, face_at[0], face_at[1], fov, W, W)
    aim(cam, tgt)
    depth0 = (hp - cam.location).length
    for k, (sx, sy, back, hue) in enumerate(copies):
        c = T.clone(hero_at, 180 + yaw_off, pose, hue=hue, outfit=SANTA, glow=False)
        head_to(c, screen_point(cam, sx, sy, depth0 + back, W, W))
    hero_rig(hp, cam, key_pw=1500, rims=(("#5FE6FF", 1.0, 2800), ("#FFB347", -1.0, 3000)))
    return s, cam, hp


def icon_post(sparks):
    def fn(im):
        W, Hh = im.size
        return sparkles(im, [(x * W, y * Hh, r) for x, y, r in sparks], Hh)
    return fn


WARM_STOPS = [(0.0, "#FFE7A0"), (0.16, "#FFC21F"), (0.36, "#FF7A2A"), (0.6, "#B2306E"), (0.85, "#3A2462"),
              (1.2, "#1C1F3B")]


def icon_stops_bg(cx, cy, stops=WARM_STOPS, aurora=0.0, flakes=True, scale=1.0):
    np = _np()

    def fn(W, Hh):
        img = radial_stops(W, Hh, cx, cy, [(t * scale, h) for t, h in stops])
        if aurora:
            a = aurora_layer(W, Hh, 0.0, 0.5, aurora)
            img = 1 - (1 - img) * (1 - a[..., :3] * a[..., 3:4])
        if flakes:
            img = np.clip(img + snow(W, Hh, n=70, seed=11, size=0.006, alpha=0.7), 0, 1)
        return img
    return fn


def icon_bg(base_top, base_bottom, halo_at, halo_col="#FFB23F", halo_r=0.62, aurora=0.0, flakes=True,
            second=None):
    np = _np()

    def fn(W, Hh):
        img = vgrad(W, Hh, base_top, base_bottom)
        if aurora:
            img = over(img, aurora_layer(W, Hh, 0.0, 0.6, aurora))
        img = 1 - (1 - img) * (1 - np.clip(radial(W, Hh, halo_at[0], halo_at[1], halo_r, halo_col, 1.1), 0, 1))
        if second:
            img = 1 - (1 - img) * (1 - np.clip(radial(W, Hh, *second[:4], 1.6) * second[4], 0, 1))
        if flakes:
            img = np.clip(img + snow(W, Hh, n=90, seed=11, size=0.006, alpha=0.8), 0, 1)
        return img
    return fn


def _icon(W, Hh, samples, name, out, copies, bg, sparks, pose="icon_bag", carry="CashBag", face_at=(0.6, 0.47),
          glow=("#FFC21F", 0.05, 3.2), **kw):
    ss = 2
    s, cam, hp = icon_stage(samples, W * ss, copies, pose=pose, carry=carry, face_at=face_at, **kw)
    render_passes(s, cam, name, bg=False)
    compose(name, out, bg_fn=bg, outline=0.007, hero_outline=0.011, clone_glow=0.035, hero_gain=1.12,
            hero_glow=glow,
            fg_sat=1.15, drop=0.014, vignette=0.3, post=icon_post(sparks), supersample=ss)


@image("icon_1_santa-crew", "icon", (512, 512), "final")
def icon_1(W, Hh, samples, name, out):
    """The Rookie in his Santa cap with a cyan and a magenta copy behind (the wordmark's copy hues), the cash bag
    over his shoulder, a gold halo behind his head on Ink Indigo, gold sparkles."""
    copies = ((0.36, 0.3, 3.2, CYAN), (0.16, 0.2, 6.8, MAGENTA))
    _icon(W, Hh, samples, name, out, copies,
          icon_stops_bg(0.7, 0.22, aurora=0.0, scale=1.0),
          [(0.9, 0.5, 0.045), (0.95, 0.4, 0.022)], face_at=(0.56, 0.5))


@image("icon_2_santa-solo", "icon", (512, 512), "final")
def icon_2(W, Hh, samples, name, out):
    """Solo: three cyan copies with the age ramp (dimmer, drifting violet), a present in his arms, a gold halo with
    the game's aurora over it."""
    copies = ((0.37, 0.33, 3.0, T.drift(CYAN, 0, 3)), (0.22, 0.25, 6.0, T.drift(CYAN, 1, 3)),
              (0.09, 0.18, 9.5, T.drift(CYAN, 2, 3)))
    _icon(W, Hh, samples, name, out, copies, icon_stops_bg(0.4, 0.28, aurora=0.5, scale=1.0),
          [(0.85, 0.8, 0.045), (0.93, 0.7, 0.022)], pose="icon_gift", carry="Present", face_at=(0.58, 0.44))


@image("icon_3_santa-twins", "icon", (512, 512), "final")
def icon_3(W, Hh, samples, name, out):
    """Symmetric: the Rookie square to the camera, smug, a cyan copy over one shoulder and a magenta copy over the
    other (the wordmark's copies split out, as the title beat does), a gold stack in his hands, the gold halo
    behind his head."""
    copies = ((0.2, 0.36, 3.4, CYAN), (0.8, 0.36, 3.4, MAGENTA))
    _icon(W, Hh, samples, name, out, copies, icon_stops_bg(0.5, 0.2, scale=1.0),
          [(0.64, 0.8, 0.04), (0.36, 0.84, 0.02)], pose="carry_low", carry="GoldStack", face_at=(0.5, 0.42),
          yaw_off=0, cam_side=0.0, glow=("#FFE08A", 0.06, 4.5), dist=10.0)


# ------------------------------------------------------------------ thumbnails
def town_set(samples, cam_r, snow_focus=None, aurora_t=6.0):
    return T.town(samples, cam_pos=cam_r, snow_focus=snow_focus, aurora_t=aurora_t)


def thumb_finish(name, out, bg_blur, glows, post, hero_gain=1.15, outline=0.0045, hero_outline=0.007,
                 clone_glow=0.02, bg_dim=0.9, bg_sat=1.15, vignette=0.24, ss=1, fn=None, gel=None, hero_glow=None,
                 under=None, hero_halo=(0.03, 0.55)):
    compose(name, out, bg_fn=fn or file_bg(name), bg_blur=bg_blur, bg_dim=bg_dim, bg_sat=bg_sat, glows=glows,
            gel=gel, hero_glow=hero_glow, under=under, hero_halo=hero_halo,
            outline=outline, hero_outline=hero_outline, clone_glow=clone_glow, hero_gain=hero_gain, fg_sat=1.15,
            drop=0.008, vignette=vignette, post=post, supersample=ss)


RECOMPOSE = False     # --recompose: redo the 2D finish from the saved passes and anchors (no Blender scene)


def anchors(name, build):
    """The scene's screen points the 2D finish needs, as shares of the frame (x / W, y / H). Rendering runs
    `build()` (the scene, the passes) and saves them; --recompose loads them instead of building anything."""
    path = os.path.join(TMP, f"{name}_anchors.json")
    if RECOMPOSE:
        return json.load(open(path))
    A = build()
    json.dump(A, open(path, "w"), indent=1)
    return A


def sfrac(s, cam, p):
    x, y, z = T.screen(s, cam, p)
    return [x / s.render.resolution_x, y / s.render.resolution_y, z]


@image("thumb_1_8-of-me", "thumb", (1920, 1080), "final")
def thumb_1(W, Hh, samples, name, out):
    """8 OF ME: you in front with the cash bag held out, seven glowing copies of you fanned behind in a V (newest
    nearest, the solo age ramp), the story town's street blurred behind, gold rain."""
    def build():
        cam_r = (11.0, 7.2, 32.0)
        s = town_set(samples, cam_r, snow_focus=(10, 8, 10))
        cam = T.camera(s, cam_r, (11.0, 4.0, 0.0), 38, W, Hh)
        hero_at = (11.0, 0.0, 20.5)
        hero = T.rookie(hero_at, 186, "bag_out", face="smug")
        T.in_hand(hero, "CashBag", "Right", drop=0.95, yaw=20, scale=1.0)
        hp = T.part_pos(hero, "Rookie_Head")
        aim(cam, MR.frame(cam.location, hp, 0.5, 0.55, 38, W, Hh))
        poses = ("cheer", "cheer", "grin", "fan", "smug", "cheer", "cheer")
        heads = []
        for k in range(7):
            row = k // 2 + 1
            side = -1 if k % 2 == 0 else 1
            if k == 6:
                x, z = hero_at[0] + 0.6, hero_at[2] - 12.5
            else:
                x, z = hero_at[0] + side * (1.6 + row * 2.0), hero_at[2] - 1.8 - row * 3.0
            c = T.clone((x, 0.0, z), 180 - side * 8, poses[k], hue=T.drift(CYAN, k, 7))
            heads.append(T.part_pos(c, "Rookie_Head"))
            if k < 2:
                T.in_hand(c, "CashBag", "Left" if side < 0 else "Right", drop=0.95, scale=0.85)
        hero_rig(hp, cam, key_pw=2600, rims=(("#5FE6FF", 1.0, 3800), ("#FFB347", -1.0, 4200)), dist=6.0)
        hand = T.part_pos(hero, "Rookie_RightHand")
        render_passes(s, cam, name)
        return {"bag": sfrac(s, cam, hand + Vector((0, 0, -0.9))),
                "heads": [sfrac(s, cam, p) for p in [hp] + heads]}
    A = anchors(name, build)

    def post(im):
        W_, H_ = im.size
        rain = [(A["bag"][0] * W_, A["bag"][1] * H_, 0.03)]
        import random
        rnd = random.Random(8)
        while len(rain) < 20:       # gold rain, never on a face
            x, y = rnd.uniform(0.05, 0.95), rnd.uniform(0.3, 0.86)
            if all(abs(x - hx) * 16 / 9 > 0.09 or abs(y - hy) > 0.1 for hx, hy, _z in A["heads"]):
                rain.append((x * W_, y * H_, rnd.uniform(0.007, 0.016)))
        im = sparkles(im, rain, H_)
        return wordmark(im, [[("8", CYAN), ("OF", WHITE), ("ME", WHITE)]], 0.15, 0.22, 0.5, "c")[0]
    thumb_finish(name, out, 0.006, [(0.5, 0.62, 0.6, "#FF9A2A", 0.45)], post, gel=("#4048B0", "#9A3A7A", 0.8),
                 bg_dim=0.85, hero_halo=(0.045, 0.8))


@image("thumb_2_rob-with-clones", "thumb", (1920, 1080), "final")
def thumb_2(W, Hh, samples, name, out):
    """ROB WITH (YOUR) CLONES, first person in L4 Night Clerk's shop floor (rebuilt by level_shots): your gloves
    hold the tip-jar cash they just grabbed, your clone stands on plate A holding the back-room door open, and
    through that door Gus in his Santa hat looks your way with his flashlight."""
    def build():
        import level_shots as LS
        s, lv, doors, groups = T.level("cs4_night_clerk", samples, held=True)
        eye = (2.0, 3.8, -0.5)
        look = (8.0, 3.6, -18.0)
        cam = T.camera(s, eye, look, 62, W, Hh)
        LS.cut(lv["tower"], groups, eye, [])
        LS._apply_fade(eye)
        T.tag(T.fp_hands(cam), "hero")
        r, u, f = cam_basis(cam)
        bag_at = cam.location + f * 2.9 - u * 1.5 - r * 0.15
        T.prop("CashBag", bag_at, 120, 0.6, loc="CornerShop")
        cl_at = (10.0, 0.0, -8.0)            # plate A: holds the BackRoom door open (openBy 1)
        c = T.clone(cl_at, 200, "smug", hue=CYAN, face="smug")
        T.level_gus(lv, doors, -1.0, -29.0, 195, pose="patrol", torch_at=IS.rb(0.0, 0.2, -16.0))
        hp = T.part_pos(c, "Rookie_Head")
        light("SPOT", hp + Vector((3, 3, 4)), hp, "#FFD7A8", 900, spot=40)
        light("SPOT", cam.location + u * 1.0, bag_at, "#FFE2B0", 300, spot=40)
        render_passes(s, cam, name)
        return {"pill": sfrac(s, cam, hp + Vector((0, 0, 1.6))), "bag": sfrac(s, cam, bag_at + u * 0.3)}
    A = anchors(name, build)

    def post(im):
        W_, H_ = im.size
        im = T.pill(im, (A["pill"][0] * W_, A["pill"][1] * H_), "1", CYAN, 0.055)
        bx, by = A["bag"][0] * W_, A["bag"][1] * H_
        im = sparkles(im, [(bx, by, 0.03), (bx + 0.05 * H_, by - 0.06 * H_, 0.014)], H_)
        # the subtitle has 4 words; the store-art rule is <= 3 (ICON_THUMBNAILS 0.1 rule 8): "ROB WITH CLONES"
        return wordmark(im, [[("ROB", WHITE), ("WITH", WHITE), ("CLONES", CYAN)]], 0.13, 0.2, 0.5, "c")[0]
    thumb_finish(name, out, 0.003, [], post, hero_gain=1.0, clone_glow=0.03, outline=0.004, hero_outline=0.004)


@image("thumb_3_steal-back-christmas", "thumb", (1920, 1080), "final")
def thumb_3(W, Hh, samples, name, out):
    """STEAL BACK CHRISTMAS: low on the snowy street, looking up: you in the Santa cap with a present and three
    copies of you carrying more, Hoardsworth Tower with the Snow Globe Vault full of the town's presents on top, the
    aurora over it."""
    def build():
        cam_r = (-5.0, 2.4, 36.0)
        s = town_set(samples, cam_r, snow_focus=(-2, 8, 22))
        fov = 52
        cam = T.camera(s, cam_r, (0, 60, -200), fov, W, Hh)
        globe = IS.rbv(T.iplan()["stage"]["globe"]["centre"])
        aim(cam, MR.frame(cam.location, globe, 0.7, 0.25, fov, W, Hh))

        def crew(sx, sy, d, hue, gift, gscale, pose="carry_low", outfit=SANTA, yaw=200):
            target = screen_point(cam, sx, sy, d, W, Hh)
            rx, _ry, rz = to_roblox(target)

            def make():
                if hue is None:
                    f = T.rookie((rx, 0.0, rz), yaw, pose, face="smug", outfit=outfit)
                else:
                    f = T.clone((rx, 0.0, rz), yaw, pose, hue=hue, outfit=outfit, face="smug")
                a, b = T.part_pos(f, "Rookie_LeftHand"), T.part_pos(f, "Rookie_RightHand")
                T.prop(gift, (a + b) / 2 + Vector((0, 0.55, -0.85)), 25, gscale)
                return f
            return figure_at(make, target)

        for k, (sx, sy, d, gift, gs) in enumerate(((0.13, 0.6, 14.0, "Intro_Present_A", 0.5),
                                                    (0.6, 0.62, 13.5, "Intro_Present_B", 0.5),
                                                    (0.86, 0.64, 12.0, "Present", 0.85))):
            crew(sx, sy, d, T.drift(CYAN, k, 3), gift, gs, yaw=196 + 6 * k)
        _hero, hp = crew(0.37, 0.56, 9.5, None, "Present", 0.9)
        hero_rig(hp, cam, key_pw=2600, rims=(("#5FE6FF", 1.0, 3800), ("#FFB347", -1.0, 3800)), dist=6.0)
        render_passes(s, cam, name)
        return {"globe": sfrac(s, cam, globe)}
    A = anchors(name, build)
    gx, gy = A["globe"][0], A["globe"][1]

    def post(im):
        return wordmark(im, [[("STEAL", WHITE), ("BACK", WHITE)], [("CHRISTMAS", "#FF5A5A")]], 0.11, 0.165, 0.04,
                        "l")[0]
    thumb_finish(name, out, 0.0015, [(gx, gy, 0.16, "#FFD9A0", 0.85), (gx, gy, 0.4, "#FF9A3A", 0.35)], post,
                 gel=("#3A50C0", "#6A3A8A", 0.5), hero_halo=(0.04, 0.7))


def beam(p0, p1, w0, w1, hexc, alpha):
    """A soft flashlight beam from screen point p0 (width w0) to p1 (width w1), additive, as a function of the bg."""
    def fn(bg):
        from PIL import Image, ImageDraw
        np = _np()
        Hh, W = bg.shape[:2]
        im = Image.new("L", (W, Hh), 0)
        d = ImageDraw.Draw(im)
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        d.polygon([(p0[0] + nx * w0, p0[1] + ny * w0), (p1[0] + nx * w1, p1[1] + ny * w1),
                   (p1[0] - nx * w1, p1[1] - ny * w1), (p0[0] - nx * w0, p0[1] - ny * w0)], fill=255)
        m = blur(np.asarray(im).astype(np.float32) / 255, Hh * 0.012)[..., None]
        col = np.array(hexrgb(hexc), np.float32) / 255
        return 1 - (1 - bg) * (1 - np.clip(m * col * alpha, 0, 1))
    return fn


def yaw_to(frm, to):
    """Roblox yaw (deg, 0 = -Z) that faces from Roblox (x, z) `frm` toward `to`."""
    return math.degrees(math.atan2(-(to[0] - frm[0]), -(to[1] - frm[1])))


@image("thumb_4_wrong-one", "thumb", (1920, 1080), "final")
def thumb_4(W, Hh, samples, name, out):
    """WRONG ONE!: in L4 Night Clerk's back room Gus (Santa hat) does his double-take on your clone, caught in his
    flashlight with its hands up, while the real you tiptoes past in the foreground with the cash bag, smug."""
    def build():
        import level_shots as LS
        s, lv, doors, groups = T.level("cs4_night_clerk", samples)
        cam_r = (-7.0, 5.6, -20.9)
        fov = 50
        cam = T.camera(s, cam_r, (10.0, 2.4, -33.0), fov, W, Hh)
        LS.cut(lv["tower"], groups, cam_r, [])
        LS._apply_fade(cam_r)

        def floor_at(sx, sy, d):
            b = screen_point(cam, sx, sy, d, W, Hh)
            x, _y, z = to_roblox(b)
            return x, z
        cx, cz = floor_at(0.25, 0.66, 11.0)
        gx, gz = floor_at(0.5, 0.64, 16.0)
        hx, hz = floor_at(0.74, 0.68, 8.0)
        to_cam = yaw_to((cx, cz), (cam_r[0], cam_r[2]))
        clone = T.clone((cx, 0.0, cz), to_cam - 35, "busted", hue=CYAN, face="shocked")
        chest = T.part_pos(clone, "Rookie_UpperTorso")
        by = T.level_gus(lv, doors, gx, gz, yaw_to((gx, gz), (cx, cz)), pose="doubletake", torch_at=chest)
        hero = T.rookie((hx, 0.0, hz), yaw_to((hx, hz), (cam_r[0], cam_r[2])) + 30, "tiptoe", face="smug")
        T.in_hand(hero, "CashBag", "Right", drop=0.8, yaw=10, scale=0.85, loc="CornerShop")
        hp = T.part_pos(hero, "Rookie_Head")
        hero_rig(hp, cam, key_pw=1800, rims=(("#5FE6FF", 1.0, 2400), ("#FFB347", -1.0, 2400)), dist=5.0)
        gh = by["Gus_Head"].matrix_world.translation.copy()
        light("SPOT", gh + Vector((0, 0, 4)) + (cam.location - gh).normalized() * 4, gh, "#FFD9B0", 1600, spot=36)
        lens = by.get("Gus_FlashlightLens")
        lp = lens.matrix_world.translation.copy() if lens else gh
        render_passes(s, cam, name)
        return {"lens": sfrac(s, cam, lp), "chest": sfrac(s, cam, chest), "gus": sfrac(s, cam, gh)}
    A = anchors(name, build)

    def post(im):
        W_, H_ = im.size
        import numpy as np
        from PIL import Image
        a = np.asarray(im.convert("RGB")).astype(np.float32) / 255
        a = beam((A["lens"][0] * W_, A["lens"][1] * H_), (A["chest"][0] * W_, A["chest"][1] * H_), H_ * 0.012,
                 H_ * 0.2, "#FFD27A", 0.45)(a)
        im = Image.fromarray((a * 255).astype(np.uint8)).convert("RGBA")
        im = wordmark(im, [[("WRONG", WHITE), ("ONE!", CYAN)]], 0.14, 0.2, 0.5, "c")[0]
        return T.pop(im, (A["gus"][0] * W_ - 0.11 * H_, A["gus"][1] * H_ + 0.02 * H_), "?", 0.06)
    thumb_finish(name, out, 0.004, [], post, gel=("#4A3A9A", "#7A3A5A", 0.35), hero_halo=(0.04, 0.7),
                 under=beam((A["lens"][0] * W, A["lens"][1] * Hh), (A["chest"][0] * W, A["chest"][1] * Hh),
                            Hh * 0.012, Hh * 0.2, "#FFD27A", 0.6))


# ------------------------------------------------------------------ grading
def grade_one(name, kind, path):
    """thumb_shots-style grade: frame_grade on the full frame, then per group at 64 and 150 px its share and its
    value pop over the surround (colour and greyscale); text boxes count as their own group."""
    import numpy as np
    from PIL import Image
    import frame_grade as FG
    g = FG.grade(path)
    keep = {k: g[k] for k in ("near_black", "dark_share", "median_luma", "value_spread", "warm_share", "glow_share",
                              "rms_contrast")}
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32) / 255
    import colorsys  # noqa: F401
    mx, mn = a.max(-1), a.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    keep["mean_saturation"] = round(float(sat.mean()), 3)
    keep["saturated_share"] = round(float(((sat > 0.5) & (mx > 0.35)).mean()) * 100, 1)
    ids = os.path.join(TMP, f"{name}_final_ids.png")
    out = {"frame": keep, "sizes": {}}
    for px in (64, 150):
        size = (px, px) if kind == "icon" else (round(px * 16 / 9), px)
        small = np.asarray(im.resize(size, Image.LANCZOS), np.float32)
        v = small.max(axis=-1) / 255.0
        grey = (0.2126 * small[..., 0] + 0.7152 * small[..., 1] + 0.0722 * small[..., 2]) / 255.0
        row = {}
        if os.path.isfile(ids):
            m = np.asarray(Image.open(ids).convert("RGBA").resize(im.size, Image.NEAREST), np.float32)
            for gname, col in T.GROUP_COLOURS.items():
                full = np.all(np.abs(m[..., :3] - np.array(col)) < 40, axis=-1) & (m[..., 3] > 128)
                if full.sum() < 50:
                    continue
                share = np.asarray(Image.fromarray((full * 255).astype(np.uint8)).resize(size, Image.BOX),
                                   np.float32) / 255.0
                mask = share > 0.5
                row[gname] = {"share": round(float(mask.mean()) * 100, 1),
                              "pop": T._pop(v, mask, max(1, px // 32)),
                              "grey_pop": T._pop(grey, mask, max(1, px // 32))}
        out["sizes"][str(px)] = row
    return out


def grade_all():
    from PIL import Image, ImageDraw, ImageOps
    grades, rows = {}, []
    for name, (_fn, kind, _size, _out) in IMAGES.items():
        p = out_path(name)
        if not os.path.isfile(p):
            continue
        grades[os.path.basename(p)] = grade_one(name, kind, p)
        rows.append((name, kind, Image.open(p).convert("RGB")))
    json.dump(grades, open(os.path.join(FINAL, "grades.json"), "w"), indent=1, sort_keys=True)
    f, _ = MR._font(16)
    tiles = []
    for name, kind, im in rows:
        if kind == "icon":
            full = im.resize((300, 300), Image.LANCZOS)
            s150, s64 = im.resize((150, 150), Image.LANCZOS), im.resize((64, 64), Image.LANCZOS)
        else:
            full = im.resize((480, 270), Image.LANCZOS)
            s150, s64 = im.resize((267, 150), Image.LANCZOS), im.resize((114, 64), Image.LANCZOS)
        big = s64.resize((s64.size[0] * 3, s64.size[1] * 3), Image.NEAREST)
        gr = ImageOps.grayscale(s150).convert("RGB")
        tiles.append((name, [full, s150, s64, big, gr]))
    rowh = 330
    sheet = Image.new("RGB", (1840, 50 + rowh * len(tiles)), (20, 21, 34))
    d = ImageDraw.Draw(sheet)
    d.text((10, 12), "Heist Yourself final store art: full, 150 px, 64 px (1x), 64 px x3, 150 px greyscale",
           fill=(230, 232, 245), font=f)
    for r, (name, parts) in enumerate(tiles):
        y = 50 + r * rowh
        d.text((10, y), name, fill=(230, 232, 245), font=f)
        x = 10
        for im in parts:
            sheet.paste(im, (x, y + 24))
            x += im.size[0] + 16
    sheet.save(os.path.join(FINAL, "readability.png"), optimize=True)
    grid_test(rows)
    print(json.dumps(grades, indent=1))


def grid_test(rows):
    """The discover-grid mock: our icons and thumbnails at phone size (150 px icons, 267 x 150 tiles) on Roblox's
    dark and light app backgrounds, next to flat stand-in tiles in the colours of the current top-game art."""
    from PIL import Image, ImageDraw
    W = 1200
    out = Image.new("RGB", (W, 760), (25, 27, 31))
    d = ImageDraw.Draw(out)
    f, _ = MR._font(14)
    icons = [im for n, k, im in rows if k == "icon"]
    thumbs = [im for n, k, im in rows if k != "icon"]
    for half, (bgc, txt) in enumerate((((25, 27, 31), (220, 220, 225)), ((242, 244, 245), (40, 40, 45)))):
        y0 = half * 380
        d.rectangle([0, y0, W, y0 + 380], fill=bgc)
        d.text((10, y0 + 8), ("dark" if half == 0 else "light") + " app theme, phone size", fill=txt, font=f)
        x = 10
        for im in icons:
            out.paste(im.resize((150, 150), Image.LANCZOS), (x, y0 + 30))
            x += 162
        for col in ((90, 170, 70), (230, 120, 40), (40, 40, 60)):     # stand-ins: garden green, orange, dark horror
            d.rounded_rectangle([x, y0 + 30, x + 150, y0 + 180], 12, fill=col)
            x += 162
        x = 10
        for im in thumbs:
            out.paste(im.resize((267, 150), Image.LANCZOS), (x, y0 + 200))
            x += 280
    out.save(os.path.join(FINAL, "grid_test.png"), optimize=True)


def out_path(name):
    """docs/marketing/final/icon_512_<n>_<slug>.png, thumb_1920x1080_<n>_<slug>.png."""
    kind, rest = name.split("_", 1)
    size = IMAGES[name][2]
    return os.path.join(FINAL, f"{kind}_{size[0]}{'x' + str(size[1]) if kind == 'thumb' else ''}_{rest}.png")


def render_one(name, scale, samples):
    fn, kind, size, out = IMAGES[name]
    if RECOMPOSE:
        from PIL import Image
        if kind == "icon":
            raise SystemExit("icons render in a minute: re-render them instead of --recompose")
        W, Hh = Image.open(os.path.join(TMP, f"{name}_fg.png")).size
    else:
        W, Hh = int(size[0] * scale), int(size[1] * scale)
    fn(W, Hh, samples, name, out_path(name))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--grade", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--recompose", action="store_true", help="thumbnails: redo the 2D finish from the saved passes")
    a = ap.parse_args(argv)
    global RECOMPOSE
    RECOMPOSE = a.recompose
    if a.list:
        for n, (_f, kind, size, _o) in IMAGES.items():
            print(n, kind, size)
        return
    if a.grade:
        grade_all()
        return
    if not a.only:
        ap.error("render one image per command: --only NAME (see --list)")
    render_one(a.only, a.scale, a.samples)


if __name__ == "__main__":
    main(sys.argv[1:])
