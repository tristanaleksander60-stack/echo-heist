"""Store art CANDIDATES after the first-person pivot: thumbnails, icons and trailer key frames, staged in Blender
from the real game assets (docs/marketing/ICON_THUMBNAILS.md, docs/marketing/TRAILER.md).

    python3 tools/blender/thumb_shots.py --only TH1        # one image per command (one Blender process each)
    python3 tools/blender/thumb_shots.py --only TH1 --scale 0.33 --samples 8   # a quick draft
    python3 tools/blender/thumb_shots.py --sheet           # grades.json + contact_sheet.png from what is on disk
    python3 tools/blender/thumb_shots.py --list            # the image names

Writes docs/marketing/thumbs/<name>.png (thumbnails 1920 x 1080, icons 512 x 512) and docs/marketing/trailer/<name>.png
(trailer key frames, 1920 x 1080, with the caption card the trailer burns in). Every image carries a small
"CONCEPT RENDER, NOT A CAPTURE" tag in its metadata corner: these are direction and stand-ins for the illustrator
brief and the owner's capture session (CAPTURE.md), never uploads (MASTERPLAN 9.4, ICON_THUMBNAILS truth gate G1).

What is real here (nothing hand-modelled):
  * the Rookie and every clone: the CHARACTER track's kit (assets/fbx/Rookie*.fbx) posed through its R15 joints by
    intro_shots.rookie, in a real outfit from Config.Rookie (cap / scarf / sweater / gloves), crew pieces in the seat
    hue; clones drawn as EchoView draws them (intro_shots.clone_look: the crew-hue fill 0.55 + outline, the solo age
    ramp, a floor glow);
  * Gus (kit rig, Santa hat), the loot (CashBag, GoldStack, GiantPresent, Intro_Present_*), the van, street lamps;
  * two stages: the story intro's town (Heist/IntroPlan via intro_plan.luau: Intro_House_A/B, Hoardsworth Tower, the
    Snow Globe Vault, Hoardsworth himself, the Heist City sky, the game's aurora from AuroraPlan) and a real level
    rebuilt by level_shots (KitPlan, BIG facades, the backdrop ring, recipe A, Gus at his patrol spot and his cone).
What is staged for the camera (the owner's capture place does the same with Studio lights): a warm key and a cool
rim on the hero, figures placed by hand (poses from the joint table below), the text and the badge pills in 2D.
"""
import argparse, json, math, os, random, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402

import marketing_renders as MR  # noqa: E402
import kit_preview as K  # noqa: E402
import intro_shots as IS  # noqa: E402
import aurora_shots as AS  # noqa: E402
import backdrop_shots as BS  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
THUMBS = os.path.join(REPO, "docs", "marketing", "thumbs")
TRAILER = os.path.join(REPO, "docs", "marketing", "trailer")
TMP = os.path.join(REPO, "build", "blender", "thumbs")

CYAN, MAGENTA, INDIGO, WHITE = "#3DE8FF", "#FF4FD8", "#6A5CFF", "#F4F7FF"   # Palette seat hues P1-P4
GOLD, INK, EXIT = "#FFC21F", "#1C1F3B", "#F4F7FF"
KNIT, LEATHER = "#2A2D52", "#6E4B3A"                                        # Config.Rookie.GLOVES

# Config.Rookie outfits (slot -> kit pieces). DEFAULT_OUTFIT = Cap_Flat, Scarf_Long, Sweater_Stripes, Gloves_Knit.
CAPS = {"Flat": ["Rookie_Cap_Flat"], "Beanie": ["Rookie_Cap_Beanie"], "Bobble": ["Rookie_Cap_Bobble"],
        "Trapper": ["Rookie_Cap_Trapper"], "None": []}
SCARVES = {"Long": ["Rookie_Scarf_Long", "Rookie_Scarf_Long_Tail1", "Rookie_Scarf_Long_Tail2"],
           "Chunky": ["Rookie_Scarf_Chunky"], "Bandana": ["Rookie_Scarf_Bandana"], "Knot": ["Rookie_Scarf_Knot"]}
SWEATERS = {"Stripes": ["Rookie_Stripes_Torso", "Rookie_Stripes_LeftArm", "Rookie_Stripes_RightArm"],
            "Block": ["Rookie_Block_Torso", "Rookie_Block_LeftCuff", "Rookie_Block_RightCuff"]}
GLOVE_PIECES = {"Knit": (["Rookie_Gloves_Knit_Left", "Rookie_Gloves_Knit_Right"], KNIT),
                "Leather": (["Rookie_Gloves_Leather_Left", "Rookie_Gloves_Leather_Right"], LEATHER)}
DEFAULT = ("Flat", "Long", "Stripes", "Knit")

# Poses: Roblox joint name -> CFrame.fromEulerAnglesYXZ degrees (as IntroPlan.POSES). +X on a shoulder / hip / elbow
# swings the limb forward; a knee bends with -X; +X on the waist or neck tips back.
POSES = {
    "stand": {},
    "grin": {"RightShoulder": (20, 0, -6), "LeftShoulder": (40, 0, 8), "LeftElbow": (40, 0, 0), "Neck": (6, 12, 6)},
    "smug": {"RightShoulder": (8, 0, -14), "LeftShoulder": (8, 0, 14), "Neck": (4, -14, 6), "Waist": (2, 10, 0)},
    "bag": {"RightShoulder": (22, 0, -12), "RightElbow": (38, 0, 0), "LeftShoulder": (6, 0, 10), "Neck": (4, -10, 4)},
    "bag_up": {"RightShoulder": (150, 0, -38), "RightElbow": (25, 0, 0), "LeftShoulder": (10, 0, 12),
               "Neck": (8, -8, 0)},
    "bag_out": {"RightShoulder": (34, 0, -72), "RightElbow": (14, 0, 0), "LeftShoulder": (8, 0, 14),
                "LeftElbow": (20, 0, 0), "Neck": (4, -12, 4)},
    "carry_low": {"RightShoulder": (26, 0, 16), "RightElbow": (34, 0, 0), "LeftShoulder": (26, 0, -16),
                  "LeftElbow": (34, 0, 0), "Neck": (4, 0, 0)},
    "carry": {"RightShoulder": (58, 0, 14), "RightElbow": (42, 0, 0), "LeftShoulder": (58, 0, -14),
              "LeftElbow": (42, 0, 0), "Neck": (2, 0, 0)},
    "walk": {"RightHip": (22, 0, 0), "RightKnee": (-10, 0, 0), "LeftHip": (-18, 0, 0), "LeftKnee": (-28, 0, 0),
             "RightShoulder": (-16, 0, -6), "LeftShoulder": (22, 0, 6), "RightElbow": (16, 0, 0),
             "LeftElbow": (24, 0, 0)},
    "walk_bag": {"RightHip": (-16, 0, 0), "RightKnee": (-26, 0, 0), "LeftHip": (22, 0, 0), "LeftKnee": (-8, 0, 0),
                 "RightShoulder": (24, 0, -12), "RightElbow": (40, 0, 0), "LeftShoulder": (-18, 0, 8),
                 "LeftElbow": (20, 0, 0), "Neck": (2, -8, 0)},
    "sneak": {"Waist": (-16, 0, 0), "Neck": (14, 18, 0), "RightHip": (40, 0, 0), "RightKnee": (-52, 0, 0),
              "LeftHip": (-18, 0, 0), "LeftKnee": (-34, 0, 0), "RightShoulder": (62, 0, -18), "RightElbow": (70, 0, 0),
              "LeftShoulder": (48, 0, 22), "LeftElbow": (84, 0, 0)},
    "cheer": {"RightShoulder": (168, 0, -14), "RightElbow": (12, 0, 0), "LeftShoulder": (40, 0, 20),
              "LeftElbow": (60, 0, 0), "Neck": (10, 0, 0)},
    "point": {"RightShoulder": (96, -24, 0), "LeftShoulder": (4, 0, 14), "Neck": (6, -16, 0), "Waist": (2, -10, 0)},
    "busted": {"RightShoulder": (160, 0, -26), "LeftShoulder": (160, 0, 26), "RightElbow": (20, 0, 0),
               "LeftElbow": (20, 0, 0), "Neck": (10, 0, 0)},
}

PLAN = {}


def iplan():
    if not PLAN:
        PLAN.update(IS.plan())
    return PLAN


# ------------------------------------------------------------------ figures
def tag(objs, prefix):
    for o in objs:
        o["eh_group"] = prefix
    return objs


def rookie(at, yaw, pose="stand", face="smug", crew=CYAN, outfit=DEFAULT, group="hero"):
    """A Rookie in a Config.Rookie outfit at Roblox `at`, facing Roblox yaw (0 = -Z, 180 = +Z, the camera side)."""
    cap, scarf, sweater, gloves = outfit
    pieces, gcol = GLOVE_PIECES[gloves]
    IS.ROOKIE_OUTFIT = tuple(CAPS[cap] + SCARVES[scarf] + SWEATERS[sweater] + pieces)
    IS.GLOVES = gcol
    objs = IS.rookie(at, yaw, POSES[pose] if isinstance(pose, str) else pose, face=face, crew=crew)
    return tag(objs, group)


def drift(hexc, rank, count, drift_deg=25.0, age_dim=0.12):
    """EchoView's solo age ramp: rank 0 = newest clone; older runs dimmer and drifting toward violet."""
    import colorsys
    r, g, b = (int(hexc[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if count > 1:
        h = (h + rank / (count - 1) * drift_deg / 360) % 1
    v = min(1.0, v * max(1 - age_dim * rank, 0.35))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def clone(at, yaw, pose="stand", hue=CYAN, outfit=DEFAULT, face="smug", glow=True):
    objs = rookie(at, yaw, pose, face=face, crew=hue, outfit=outfit, group="clone")
    IS.clone_look(objs, hue, iplan()["clone"]["fill"])
    if glow:
        IS.clone_fx(at, hue, None, iplan())
    return objs


def part_pos(objs, name):
    """World centre (Blender) of the first object whose kit name starts with `name`."""
    for o in objs:
        if o.name.split(".")[0].startswith(name):
            bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
            return sum(bb, Vector()) / 8
    return None


def prop(model, pos_b, yaw=0.0, scale=1.0, loc="Bank", xmas=True, group="loot", flags=()):
    objs = K.place(model, tuple(pos_b), yaw, tuple(flags), xmas, loc)
    if scale != 1.0:
        for o in objs:
            o.matrix_world = Matrix.Translation(pos_b) @ Matrix.Scale(scale, 4) @ Matrix.Translation(-pos_b) @ \
                o.matrix_world
    return tag(objs, group)


def in_hand(fig, model, side="Right", drop=0.9, yaw=0.0, scale=1.0, loc="Bank"):
    """A kit prop hanging from (or held in) a Rookie's hand: its pivot under the glove."""
    h = part_pos(fig, f"Rookie_{side}Hand")
    p = h - Vector((0, 0, drop))
    return prop(model, p, yaw, scale, loc)


def gus(pos_b, yaw, pose="patrol", loc="CornerShop", torch_at=None, cone=False):
    by = MR.gus(tuple(pos_b), yaw, pose=pose, santa=True, loc=loc)
    tag(list(by.values()), "gus")
    lens = by.get("Gus_FlashlightLens")
    if lens:
        lens.data.materials.clear()
        lens.data.materials.append(MR.mat("#FFD27A", 0.4, emit=6.0, key="lens"))
    if torch_at is not None:
        MR.flashlight(by, tuple(torch_at), cone=cone, energy=2600)
    return by


def key_light(target_b, frm_b, hexc="#FFD9B0", power=1600, spot=30, size=1.2):
    return MR.light("SPOT", tuple(frm_b), tuple(target_b), hexc, power, size=size, spot=spot, blend=0.55)


# ------------------------------------------------------------------ stage A: the intro's town (outdoor, the story)
def town(samples, mood="town", aurora_t=6.0, cam_pos=None, lit=True, globe_fill=1.0, snow_focus=None,
         hoardsworth_pose=None, sun=1.0):
    """The story intro's toy town (IntroPlan.STAGE) as intro_shots.build draws it: houses, lamps, the tree, the
    road, Hoardsworth Tower with the vacuum and the Snow Globe Vault (filled), the Heist City sky, the aurora."""
    P_ = iplan()
    st = P_["stage"]
    s = MR.reset(samples)
    IS.world(s, P_["moods"][mood])
    IS.town(st, lit, "thumb")
    IS.tower(st, lit, P_)
    g = st["globe"]
    gc = g["centre"]
    globe = IS.place("Intro_SnowGlobe", (gc[0], st["deckY"], gc[2]), 0)
    for o in globe:
        if o.name.startswith("Intro_SnowGlobe_Glass"):
            o.data.materials.clear()
            o.data.materials.append(MR.mat("#C9D6FF", 0.05, emit=0.25, alpha=0.32, key="globeglass"))
        if o.name.startswith("Intro_SnowGlobe_Presents") and globe_fill != 1.0:
            p = o.matrix_world.translation.copy()
            o.matrix_world = Matrix.Translation(p) @ Matrix.Scale(globe_fill, 4, (0, 0, 1)) @ \
                Matrix.Translation(-p) @ o.matrix_world
    tag(globe, "globe")
    MR.light("POINT", tuple(IS.rb(gc[0], gc[1] - 4, gc[2])), None, "#FFD9B0", 9000, size=6, shadow=False)
    vac = st["vacuum"]
    vobjs = IS.place("Intro_Vacuum", tuple(vac["at"]), vac["yaw"])
    IS.set_neon(vobjs, "Intro_Vacuum_Lights", IS.WARM, 3.0)
    lv = st["lever"]
    IS.place("Intro_Lever", tuple(lv["at"]), lv["yaw"])
    if hoardsworth_pose:
        hw = st["hoardsworth"]
        objs_before = set(bpy.data.objects)
        pose = next(sh["hoardsworth"] for sh in P_["shots"] if sh["id"] == hoardsworth_pose)
        IS.hoardsworth(hw["at"], hw["yaw"], pose, P_["rig"])
        tag([o for o in set(bpy.data.objects) - objs_before if o.type == "MESH"], "villain")
        for vl in st["villainLights"]:
            spec = P_["villainLights"][vl["kind"]]
            power = {"under": 2600, "key": 1500, "rim": 4000, "hand": 260}[vl["kind"]]
            MR.light("SPOT", tuple(IS.rbv(vl["from"])), tuple(IS.rbv(vl["to"])), spec["COLOUR"], power, size=1.5,
                     spot=spec["ANGLE"])
    if cam_pos is not None:
        AS.ribbons(s, AS.load_plan(aurora_t), cam_pos, AS.TIER_LAYERS[1])
    if snow_focus is not None:
        IS.snowfall(snow_focus, (40, 22, 40), n=700, cam=tuple(cam_pos) if cam_pos else None)
    MR.light("SUN", (0, 0, 100), tuple(IS.rb(-60, -100, 80)), "#9AA6FF", 1.6 * P_["moods"][mood]["brightness"] * sun,
             shadow=True)
    return s


# ------------------------------------------------------------------ stage B: a real level (level_shots)
def level(level_id, samples, held=False):
    """A launch level rebuilt by level_shots exactly as the server builds it (dressing on), with the BIG facades,
    the backdrop ring, recipe A and the Heist City sky. Returns (scene, level, doors, groups)."""
    import level_shots as LS
    os.makedirs(LS.TMP, exist_ok=True)
    plan = LS.load_plan(True, False)
    lv = next(x for x in plan["levels"] if x["id"] == level_id)
    LS.POOL_FADE, LS.POOL_FADE_CFG = [], lv["interior"]["POOL_FADE"]
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    lib = LS.Lib(lv["location"])
    _held, doors, _lasers = LS.build(lv, held, lib)
    groups = LS.tower(lv["tower"], lib)
    BS.backdrop(lv, lib, LS.put, LS.soft_pool_mat)
    LS.lighting(s)
    BS.world_sky(s, LS.TMP)
    return s, lv, doors, groups


def level_gus(lv, doors, x, z, yaw_deg, pose="doubletake", torch_at=None):
    """Gus at (x, z) facing Roblox yaw (deg, 0 = -Z), his kit rig in the Santa hat, the floor cone (level_shots)."""
    import level_shots as LS
    pos = IS.rb(x, lv["floorY"], z)
    by = gus(pos, yaw_deg, pose=pose, loc=lv["location"], torch_at=torch_at)
    LS.cone(lv, doors, {"x": x, "z": z, "yaw": math.radians(yaw_deg)})
    return by


# ------------------------------------------------------------------ render + finish
def camera(s, pos_r, look_r, fov, W, Hh):
    cam = MR.camera(s, tuple(IS.rb(*pos_r)), tuple(IS.rb(*look_r)), fov, W, Hh)
    cam.data.clip_end = 3000
    return cam


def screen(s, cam, p_b):
    bpy.context.view_layer.update()
    v = world_to_camera_view(s, cam, Vector(p_b))
    W, Hh = s.render.resolution_x, s.render.resolution_y
    return v.x * W, (1 - v.y) * Hh, v.z


GROUP_COLOURS = {"hero": (255, 0, 0), "clone": (0, 255, 255), "gus": (255, 160, 0), "loot": (0, 255, 0),
                 "villain": (255, 0, 255), "globe": (0, 0, 255), "van": (255, 255, 0)}


def id_pass(s, cam, path):
    """Workbench: each tagged group in its flat colour, everything else black (occlusion kept), for the grades."""
    keep = (s.render.engine, s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure,
            s.view_settings.look)
    cols, hidden = {}, []
    for o in bpy.data.objects:
        if o.type not in ("MESH", "FONT", "CURVE"):
            continue
        cols[o.name] = tuple(o.color)
        g = o.get("eh_group")
        if g is None and o.name.startswith("Van"):
            g = "van"
        if o.name.startswith(("Snow", "Snowfall", "cone", "FloorGlow", "pool", "WindowSpill")) or \
                any(m and m.blend_method == "BLEND" for m in o.data.materials if hasattr(o.data, "materials")) and g is None:
            if not o.hide_render:
                o.hide_render = True
                hidden.append(o)
            continue
        c = GROUP_COLOURS.get(g, (0, 0, 0))
        o.color = (c[0] / 255, c[1] / 255, c[2] / 255, 1.0)
    s.render.engine = "BLENDER_WORKBENCH"
    sh = s.display.shading
    sh.light = "FLAT"
    sh.color_type = "OBJECT"
    s.display.render_aa = "OFF"
    s.render.film_transparent = True
    s.view_settings.view_transform = "Standard"
    s.view_settings.exposure = 0.0
    s.camera = cam
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        if o.name in cols:
            o.color = cols[o.name]
    for o in hidden:
        o.hide_render = False
    (s.render.engine, s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure,
     s.view_settings.look) = keep


def shoot(s, cam, name, out_dir, text=None, notes=(), hazed=False, vignette=0.18, tag_alpha=110, overlay=None,
          is_icon=False):
    """Eevee render -> (level stage: depth + the Roblox tone map + Atmosphere haze, as level_shots) -> bloom +
    ColorCorrection + vignette (marketing_renders.finish) -> 2D overlay (pills, captions) -> text -> the ID pass."""
    from PIL import Image
    if os.environ.get("EH_DRY"):          # framing check: each tagged group's centre on screen, no render
        groups = {}
        for o in bpy.data.objects:
            g = o.get("eh_group")
            if g and o.type == "MESH":
                groups.setdefault(g, []).append(o.matrix_world.translation)
        W, Hh = s.render.resolution_x, s.render.resolution_y
        for g, pts in groups.items():
            c = sum(pts, Vector()) / len(pts)
            x, y, z = screen(s, cam, c)
            print(f"DRY {g:8s} x {x / W:.2f} y {y / Hh:.2f} depth {z:.1f}")
        return os.path.join(out_dir, f"{name}.png")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    raw = os.path.join(TMP, f"{name}_raw.png")
    s.camera = cam
    s.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    src = raw
    if hazed:
        depth = os.path.join(TMP, f"{name}_depth.png")
        BS.depth_pass(s, cam, depth)
        tm = BS.tonemap(raw, os.path.join(TMP, f"{name}_tm.png"))
        src = os.path.join(TMP, f"{name}_haze.png")
        BS.haze(tm, depth, src)
    out = os.path.join(out_dir, f"{name}.png")
    img = MR.finish(src, out, list(notes), None, vignette=vignette, tag=False, truecolor=True).convert("RGBA")
    if overlay:
        img = overlay(img)
    if text:
        img = MR.draw_text(img, text)
    from PIL import ImageDraw
    W, Hh = img.size
    f, _ = MR._font(max(9, int(Hh * (0.022 if is_icon else 0.016))))
    ImageDraw.Draw(img).text((W - Hh * 0.02, Hh - Hh * 0.015), "CONCEPT RENDER, NOT A CAPTURE", font=f,
                             fill=(244, 247, 255, tag_alpha), anchor="rd")
    img = img.convert("RGB")
    img.save(out, optimize=True)
    id_pass(s, cam, os.path.join(TMP, f"{name}_ids.png"))
    print("thumb_shots:", os.path.relpath(out, REPO))
    return out


def pill(img, xy, label, hue, h=0.034):
    """A clone's numbered pill (Hud: ink capsule, crew-hue rim, Getaway White number)."""
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    W, Hh = img.size
    hh = h * Hh
    f, _ = MR._font(int(hh * 0.72))
    tw = d.textlength(label, font=f)
    w = max(hh * 1.5, tw + hh * 0.9)
    x, y = xy
    col = tuple(int(hue[i:i + 2], 16) for i in (1, 3, 5))
    d.rounded_rectangle([x - w / 2, y - hh, x + w / 2, y], radius=hh / 2, fill=(28, 31, 59, 235), outline=col + (255,),
                        width=max(2, int(hh * 0.09)))
    d.text((x, y - hh / 2), label, font=f, fill=(244, 247, 255, 255), anchor="mm")
    return img


def caption(img, words, y=0.86, cap=0.06, hue=EXIT):
    """The trailer's caption card (the intro's style: heavy caps, ink outline, lower third)."""
    return MR.draw_text(img, {"lines": [[(w, c) for w, c in words]] if isinstance(words[0], tuple) else
                              [[(words, hue)]], "cap": cap, "y": y, "align": "c", "x": 0.5})


def sparkle(img, xy, r=0.03):
    from PIL import Image, ImageDraw, ImageFilter
    W, Hh = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    x, y = xy
    for rr, a in ((Hh * r * 1.7, 110), (Hh * r, 220), (Hh * r * 0.45, 255)):
        w = rr * 0.16
        dl.polygon([(x, y - rr), (x + w, y - w), (x + rr, y), (x + w, y + w), (x, y + rr), (x - w, y + w),
                    (x - rr, y), (x - w, y - w)], fill=(255, 240, 190, a))
    return Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(1.2)))


# ------------------------------------------------------------------ the images
IMAGES = {}


def image(name, kind, size, out):
    def deco(fn):
        IMAGES[name] = (fn, kind, size, out)
        return fn
    return deco


# (the compositions follow the grading section, before main)


# ------------------------------------------------------------------ grading
def _pop(v, mask, band_px):
    from PIL import Image, ImageFilter
    import numpy as np
    if mask.sum() < 3:
        return None
    grown = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(band_px * 2 + 1)))
    band = (grown > 0) & ~mask
    if band.sum() < 3:
        return None
    return round(float(np.median(v[mask]) - np.median(v[band])), 3)


def grade(name, kind, path):
    """frame_grade on the full frame, then the read at small sizes: icons at 64 and 150 px square, thumbnails at 64
    and 150 px tall (114 x 64, 267 x 150: a phone tile is ~160 x 90). Per tagged group: its share of the small frame
    and its pop (median HSV value over the surround band, in colour and in greyscale). Text: the cap height in px."""
    import numpy as np
    from PIL import Image
    import frame_grade as FG
    g = FG.grade(path)
    keep = {k: g[k] for k in ("near_black", "dark_share", "median_luma", "value_spread", "warm_share", "glow_share")}
    im = Image.open(path).convert("RGB")
    ids = os.path.join(TMP, f"{name}_ids.png")
    out = {"frame": keep, "sizes": {}}
    for px in (64, 150):
        size = (px, px) if kind == "icon" else (round(px * 16 / 9), px)
        small = np.asarray(im.resize(size, Image.LANCZOS), np.float32)
        v = small.max(axis=-1) / 255.0
        grey = (0.2126 * small[..., 0] + 0.7152 * small[..., 1] + 0.0722 * small[..., 2]) / 255.0
        row = {}
        if os.path.isfile(ids):
            m = np.asarray(Image.open(ids).convert("RGBA"), np.float32)
            for gname, col in GROUP_COLOURS.items():
                full = np.all(np.abs(m[..., :3] - np.array(col)) < 40, axis=-1) & (m[..., 3] > 128)
                if full.sum() < 50:
                    continue
                share = np.asarray(Image.fromarray((full * 255).astype(np.uint8)).resize(size, Image.BOX),
                                   np.float32) / 255.0
                mask = share > 0.5
                row[gname] = {"share": round(float(mask.mean()) * 100, 1),
                              "pop": _pop(v, mask, max(1, px // 32)),
                              "grey_pop": _pop(grey, mask, max(1, px // 32))}
        out["sizes"][str(px)] = row
    return out


def sheet():
    """contact_sheet.png: per candidate the full frame, the 150 px and 64 px reads at 1x, the 64 px at 3x nearest
    and in greyscale, and (thumbnails) the central 9:16 crop that a vertical clip keeps."""
    from PIL import Image, ImageDraw, ImageOps
    grades = {}
    rows = []
    for name, (_fn, kind, _size, out) in IMAGES.items():
        if out != "thumbs":
            continue
        p = os.path.join(THUMBS, f"{name}.png")
        if not os.path.isfile(p):
            continue
        grades[name] = grade(name, kind, p)
        rows.append((name, kind, Image.open(p).convert("RGB")))
    json.dump(grades, open(os.path.join(THUMBS, "grades.json"), "w"), indent=1, sort_keys=True)
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
        gr = ImageOps.grayscale(s64).convert("RGB").resize(big.size, Image.NEAREST)
        parts = [full, s150, s64, big, gr]
        if kind != "icon":
            W, Hh = im.size
            cw = Hh * 9 // 16
            crop = im.crop(((W - cw) // 2, 0, (W + cw) // 2, Hh)).resize((152, 270), Image.LANCZOS)
            parts.append(crop)
        tiles.append((name, parts))
    Wt = 1700
    rowh = 330
    sheet = Image.new("RGB", (Wt, 50 + rowh * len(tiles)), (20, 21, 34))
    d = ImageDraw.Draw(sheet)
    d.text((10, 12), "Heist Yourself store-art candidates (Blender concepts from the real kit, not captures): full, "
           "150 px, 64 px, 64 px x3, 64 px grey x3, 9:16 centre crop", fill=(230, 232, 245), font=f)
    for r, (name, parts) in enumerate(tiles):
        y = 50 + r * rowh
        d.text((10, y), name, fill=(230, 232, 245), font=f)
        x = 10
        for im in parts:
            sheet.paste(im, (x, y + 24))
            x += im.size[0] + 16
    sheet.save(os.path.join(THUMBS, "contact_sheet.png"), optimize=True)
    print(json.dumps(grades, indent=1))


def trailer_sheet():
    from PIL import Image, ImageDraw
    names = [n for n, v in IMAGES.items() if v[3] == "trailer" and os.path.isfile(os.path.join(TRAILER, n + ".png"))]
    if not names:
        return
    tw, th = 480, 270
    cols = 3
    rows = (len(names) + cols - 1) // cols
    out = Image.new("RGB", (cols * (tw + 10) + 10, rows * (th + 30) + 10), (20, 21, 34))
    d = ImageDraw.Draw(out)
    f, _ = MR._font(15)
    for i, n in enumerate(names):
        x, y = 10 + (i % cols) * (tw + 10), 10 + (i // cols) * (th + 30)
        out.paste(Image.open(os.path.join(TRAILER, n + ".png")).convert("RGB").resize((tw, th), Image.LANCZOS),
                  (x, y + 20))
        d.text((x, y), n, fill=(230, 232, 245), font=f)
    out.save(os.path.join(TRAILER, "new_frames_sheet.png"), optimize=True)


# ------------------------------------------------------------------ compositions
def _v_crew(apex, n, spread=2.4, depth=2.6):
    """Seven clone spots in a V behind an apex (Roblox x, z; the V opens away from the camera at +Z)."""
    out = []
    for k in range(1, n + 1):
        side = -1 if k % 2 else 1
        row = (k + 1) // 2
        out.append((apex[0] + side * spread * row, apex[1] - depth * row))
    return out


@image("TH1_8-of-me", "thumb", (1920, 1080), "thumbs")
def th1(W, Hh, samples, name, out_dir):
    """T1 "8 OF ME": you at the apex with a cash bag held up, seven clones of your Rookie in a V behind you (newest
    nearest; older runs dimmer and drifting violet), on the story town's snowy street under the aurora, Hoardsworth
    Tower and the Snow Globe Vault behind (the sky every level shows)."""
    cam_r = (17.0, 2.8, 30.0)
    look_r = (4.0, 15.0, -40.0)
    s = town(samples, cam_pos=cam_r, snow_focus=(10, 8, 10))
    cam = camera(s, cam_r, look_r, 46, W, Hh)
    hero_at = (11.0, 0.0, 16.5)
    hero = rookie(hero_at, 200, "bag_out", face="smug")
    hand = part_pos(hero, "Rookie_RightHand")
    prop("CashBag", hand + Vector((0, 0, -1.25)), 30, 0.9)
    spots = _v_crew((hero_at[0] - 0.4, hero_at[2] - 2.0), 7, spread=2.8, depth=2.6)
    for k, (x, z) in enumerate(spots):
        clone((x, 0.0, z), 196 + (k % 3) * 5, "smug" if k % 2 else "grin", hue=drift(CYAN, k, 7))
    hp = part_pos(hero, "Rookie_Head")
    key_light(hp, hp + Vector((-6.0, 6.0, 5.0)), power=2200, spot=24)
    key_light(hp, hp + Vector((5.0, -6.0, 3.0)), hexc="#9AB4FF", power=1500, spot=30)

    def over(img):
        x, y, _ = screen(s, cam, hand + Vector((0, 0, -0.6)))
        return sparkle(img, (x, y), 0.03)
    shoot(s, cam, name, out_dir, text={"lines": [[("8", CYAN), ("OF", EXIT), ("ME", EXIT)]], "cap": 0.12, "y": 0.2,
                                       "align": "c", "x": 0.5}, overlay=over)


def pop(img, xy, glyph="?", r=0.05, fill=EXIT):
    """Gus's "?" / "!" pop (the game's UI bubble), as marketing_renders.finish draws it."""
    from PIL import ImageDraw
    W, Hh = img.size
    d = ImageDraw.Draw(img)
    x, y = xy
    rr = r * Hh
    fc = tuple(int(fill[i:i + 2], 16) for i in (1, 3, 5))
    d.ellipse([x - rr, y - rr * 2.1, x + rr, y - rr * 0.1], fill=fc + (255,), outline=(28, 31, 59, 255),
              width=max(3, int(rr * 0.12)))
    d.polygon([(x - rr * 0.3, y - rr * 0.32), (x + rr * 0.25, y - rr * 0.3), (x - rr * 0.05, y + rr * 0.35)],
              fill=fc + (255,))
    f, _ = MR._font(int(rr * 1.45))
    d.text((x, y - rr * 1.1), glyph, font=f, fill=(28, 31, 59, 255), anchor="mm")
    return img


def me_ago(img, xy, words, cap=0.045):
    """The clips' hook caption (CLIPS.md 1.2): a Clone Cyan triangle pointing at the clone, then the words in heavy
    caps, Getaway White with the Ink Indigo outline, its tip ~40 px from the head."""
    from PIL import ImageDraw
    W, Hh = img.size
    x, y = xy
    h = cap * Hh
    d = ImageDraw.Draw(img)
    pts = [(x, y - h * 0.45), (x + h * 0.9, y - h * 0.95), (x + h * 0.9, y + h * 0.05)]
    d.polygon(pts, fill=(28, 31, 59, 255))
    inset = [(x + h * 0.18, y - h * 0.45), (x + h * 0.78, y - h * 0.78), (x + h * 0.78, y - h * 0.12)]
    d.polygon(inset, fill=(61, 232, 255, 255))
    return MR.draw_text(img, {"lines": [[(words, EXIT)]], "cap": cap, "y": (y + h * 0.05) / Hh, "align": "l",
                              "x": (x + h * 1.25) / W})


def head_xy(s, cam, objs, up=0.9):
    hp = part_pos(objs, "Rookie_Head")
    x, y, _ = screen(s, cam, hp + Vector((0, 0, up)))
    return x, y


@image("TH2_wrong-one", "thumb", (1920, 1080), "thumbs")
def th2(W, Hh, samples, name, out_dir):
    """T3 "WRONG ONE!" in L4 Night Clerk's back room: Gus (Santa hat) freezes on a clone in his flashlight cone, the
    "?" over his head, while the real you tiptoes past in the foreground with the night deposit bag."""
    s, lv, doors, groups = level("cs4_night_clerk", samples)
    import level_shots as LS
    cam_r = (-10.5, 2.8, -32.6)
    look_r = (9.4, 3.8, -30.9)
    cam = camera(s, cam_r, look_r, 50, W, Hh)
    cl_at = (0.0, 0.0, -33.5)
    by = level_gus(lv, doors, 6.0, -26.5, 41, pose="doubletake", torch_at=IS.rb(cl_at[0], 3.0, cl_at[2]))
    clone(cl_at, 300, "walk", hue=CYAN, face="smug")
    hero = rookie((4.6, 0.0, -22.3), 80, "sneak", face="smug")
    in_hand(hero, "CashBag", "Right", drop=0.75, yaw=10, scale=0.8, loc="CornerShop")
    LS.cut(lv["tower"], groups, cam_r, [])
    LS._apply_fade(cam_r)
    hp = part_pos(hero, "Rookie_Head")
    key_light(hp, hp + Vector((3.0, -5.0, 4.0)), power=900, spot=34)
    key_light(hp, hp + Vector((-3.0, 4.0, 2.5)), hexc="#9AB4FF", power=700, spot=30)
    gh = by["Gus_Head"].matrix_world.translation.copy()
    key_light(gh, gh + Vector((5.0, -6.0, 3.0)), hexc="#FFD9B0", power=1500, spot=30)

    def over(img):
        x, y, _ = screen(s, cam, gh + Vector((0, 0, 2.2)))
        return pop(img, (x, y), "?", 0.06)
    shoot(s, cam, name, out_dir, text={"lines": [[("WRONG", EXIT), ("ONE!", CYAN)]], "cap": 0.12, "y": 0.2,
                                       "align": "l", "x": 0.06}, hazed=True, overlay=over)


@image("TH3_steal-back-xmas", "thumb", (1920, 1080), "thumbs")
def th3(W, Hh, samples, name, out_dir):
    """T5 "STEAL BACK XMAS": you run toward the camera with a stolen-back present, three clones behind you carry
    more, Hoardsworth Tower and the Snow Globe Vault full of the town's presents behind, the aurora overhead."""
    cam_r = (13.5, 2.9, 26.5)
    look_r = (3.0, 26.0, -120.0)
    s = town(samples, cam_pos=cam_r, snow_focus=(8, 8, 8))
    cam = camera(s, cam_r, look_r, 48, W, Hh)
    hero = rookie((9.6, 0.0, 16.0), 200, "carry_low", face="smug")
    hl, hr = part_pos(hero, "Rookie_LeftHand"), part_pos(hero, "Rookie_RightHand")
    prop("Present", (hl + hr) / 2 + Vector((0, 0.55, -0.85)), 18, 0.8)
    for k, (x, z, v) in enumerate(((6.0, 11.5, "Present"), (13.5, 10.5, "Intro_Present_B"), (9.0, 6.5, "Present"))):
        c = clone((x, 0.0, z), 192 + 8 * k, "carry_low", hue=drift(CYAN, k, 3))
        a, b = part_pos(c, "Rookie_LeftHand"), part_pos(c, "Rookie_RightHand")
        prop(v, (a + b) / 2 + Vector((0, 0.55, -0.85)), 30 * k, 0.85 if v == "Present" else 0.5)
    hp = part_pos(hero, "Rookie_Head")
    key_light(hp, hp + Vector((-6.0, 6.0, 5.0)), power=2200, spot=24)
    key_light(hp, hp + Vector((5.0, -6.0, 3.0)), hexc="#9AB4FF", power=1500, spot=30)
    shoot(s, cam, name, out_dir, text={"lines": [[("STEAL", EXIT), ("BACK", EXIT)], [("XMAS", CYAN)]], "cap": 0.11,
                                       "y": 0.17, "align": "l", "x": 0.05})


CREWS = (   # four players: (seat hue, outfit)
    (CYAN, ("Flat", "Long", "Stripes", "Knit")),
    (MAGENTA, ("Bobble", "Chunky", "Block", "Leather")),
    (INDIGO, ("Beanie", "Knot", "Stripes", "Knit")),
    (WHITE, ("Trapper", "Bandana", "Block", "Leather")),
)


@image("TH4_16-robbers", "thumb", (1920, 1080), "thumbs")
def th4(W, Hh, samples, name, out_dir):
    """T4 "16 ROBBERS": four friends' Rookies (four crew colours, four outfits) in front, each with three clones of
    themselves behind in their crew's hue: 4 x (1 + 3) = 16, the town and the tower behind."""
    cam_r = (13.5, 7.0, 32.0)
    look_r = (10.0, 3.2, 6.0)
    s = town(samples, cam_pos=cam_r, snow_focus=(10, 8, 10))
    cam = camera(s, cam_r, look_r, 50, W, Hh)
    for i, (hue, outfit) in enumerate(CREWS):
        x0 = 5.2 + i * 3.6
        z0 = 20.0 - abs(i - 1.5) * 0.9
        p = rookie((x0, 0.0, z0), 190 - i * 6, "grin" if i % 2 else "smug", face="smug", crew=hue, outfit=outfit)
        for k in range(3):
            clone((x0 - 1.6 + (k % 2) * 3.0 + (0.8 if k == 2 else 0.0), 0.0, z0 - 3.2 - k * 2.9), 186 - i * 5,
                  "grin" if k == 1 else "smug", hue=drift(hue, k, 3), outfit=outfit, glow=k == 0)
        hp = part_pos(p, "Rookie_Head")
        key_light(hp, hp + Vector((-5.0, 6.0, 5.0)), power=900, spot=26)
    shoot(s, cam, name, out_dir, text={"lines": [[("16", CYAN), ("ROBBERS", EXIT)]], "cap": 0.12, "y": 0.2,
                                       "align": "c", "x": 0.5})


def fp_hands(cam):
    """Your Rookie hands as Heist/Viewmodel draws them (level_shots.fp_hands at Config.FirstPerson.VIEWMODEL.REST)."""
    import level_shots as LS
    return LS.fp_hands(cam, LS.golden_plan()["hands"])


@image("TH5_thats-me", "thumb", (1920, 1080), "thumbs")
def th5(W, Hh, samples, name, out_dir):
    """The first-person hook: from your eyes (your Rookie gloves, the reticle) on L1's street, your run-1 clone walks
    out of the shop door toward you with the cash it grabbed 20 seconds ago, its pill "1" over its head."""
    s, lv, doors, groups = level("cs1_back_room", samples)
    import level_shots as LS
    eye = (2.5, 3.8, 19.5)
    look = (-0.5, 3.2, 6.0)
    cam = camera(s, eye, look, 70, W, Hh)
    LS.cut(lv["tower"], groups, eye, [])
    LS._apply_fade(eye)
    cl = clone((-0.4, 0.0, 12.6), 172, "walk_bag", hue=CYAN, face="smug")
    in_hand(cl, "CashBag", "Right", drop=0.8, yaw=15, scale=0.95, loc="CornerShop")
    fp_hands(cam)
    AS.ribbons(s, AS.load_plan(4.0), eye, AS.TIER_LAYERS[1])
    BS.snowfall((0, 0, 16), lv["backdropConfig"], eye)
    hp = part_pos(cl, "Rookie_Head")

    def over(img):
        x, y, _ = screen(s, cam, hp + Vector((0, 0, 1.4)))
        return pill(img, (x, y), "1", CYAN, 0.04)
    out = shoot(s, cam, name, out_dir, text={"lines": [[("THAT'S", EXIT), ("ME?!", CYAN)]], "cap": 0.12, "y": 0.2,
                                             "align": "c", "x": 0.5}, hazed=True, overlay=over)
    LS.reticle(out)


@image("TH6_steal-it-back", "thumb", (1920, 1080), "thumbs")
def th6(W, Hh, samples, name, out_dir):
    """Key art for the story (event / finale tile): your Rookie and two clones on the snowy street look up at
    Hoardsworth Tower, the Snow Globe Vault glowing with the town's presents under the aurora."""
    cam_r = (8.5, 4.2, 33.0)
    look_r = (-22.0, 56.0, -150.0)
    s = town(samples, cam_pos=cam_r, snow_focus=(4, 8, 14))
    cam = camera(s, cam_r, look_r, 57, W, Hh)
    look_up = {"Neck": (22, 0, 0), "RightShoulder": (6, 0, -10), "LeftShoulder": (6, 0, 10), "Waist": (4, 0, 0)}
    hero = rookie((2.6, 0.0, 19.0), 2, look_up, face="smug")
    clone((-0.6, 0.0, 17.6), 4, look_up, hue=drift(CYAN, 0, 2))
    clone((5.8, 0.0, 17.2), -2, look_up, hue=drift(CYAN, 1, 2))
    hp = part_pos(hero, "Rookie_Head")
    key_light(hp, hp + Vector((-5.0, -4.0, 4.0)), power=1400, spot=28)
    shoot(s, cam, name, out_dir, text={"lines": [[("STEAL", EXIT), ("IT", EXIT)], [("BACK", CYAN)]], "cap": 0.11,
                                       "y": 0.17, "align": "l", "x": 0.05})


def icon_scene(samples, W, cap, globe=False):
    """The icon: the Rookie's head and shoulders, smug side-eye at you, two cyan copies of him fanned up-left
    behind, a warm background (lit house windows, or the Snow Globe Vault and the tower above him), no text. Framed by
    the head: the camera is turned so the face lands at face_at (ICON_THUMBNAILS 3.1: eyes ~40 % from the top)."""
    if globe:   # low in front, looking up: the tower, the globe and the aurora over his head
        hero_at = (12.0, 0.0, 14.0)
        head = Vector((hero_at[0], 4.2, hero_at[2]))
        g = Vector(iplan()["stage"]["globe"]["centre"])
        cam_r = tuple(head + (head - g) * 0.028 + Vector((-3.0, 0.0, 0.0)))
        fov, face_at, copies = 40, (0.5, 0.6), ((2.3, -1.4), (4.4, -3.0))
    else:       # in front of him, a little above, the lit houses behind
        hero_at = (26.0, 0.0, 9.0)
        head = Vector((hero_at[0], 4.2, hero_at[2]))
        cam_r = (hero_at[0] - 1.6, 5.6, hero_at[2] - 8.4)
        fov, face_at, copies = 30, (0.58, 0.52), ((2.4, 4.6), (5.6, 9.8))
    s = town(samples, cam_pos=cam_r)
    cam = camera(s, cam_r, tuple(head), fov, W, W)
    yaw = math.degrees(math.atan2(-(cam_r[0] - head[0]), -(cam_r[2] - head[2])))
    outfit = (cap, "Long", "Stripes", "Knit")
    hero = rookie(hero_at, yaw + 24, {"Neck": (2, -26, -4), "LeftShoulder": (12, 0, 8)}, face="smug", outfit=outfit)
    for k, (dx, dz) in enumerate(copies):
        clone((hero_at[0] + dx, 0.0, hero_at[2] + dz), yaw + 14, {"Neck": (0, -18, 0)}, hue=drift(CYAN, k, 2),
              outfit=outfit, glow=False)
    hp = part_pos(hero, "Rookie_Head")
    tgt = MR.frame(cam.location, hp, face_at[0], face_at[1], fov, W, W)
    cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
    fwd = (hp - cam.location).normalized()
    side = fwd.cross(Vector((0, 0, 1))).normalized()
    key_light(hp, hp - fwd * 4.0 - side * 3.0 + Vector((0, 0, 3.0)), power=900, spot=28)
    key_light(hp, hp + fwd * 3.0 + side * 2.5 + Vector((0, 0, 1.5)), hexc="#9AB4FF", power=900, spot=30)
    if not globe:   # the warm spill of the windows behind him (the houses' lit windows are Neon in the game)
        MR.light("POINT", tuple(hp + fwd * 2.5 + Vector((0, 0, 0.5))), None, "#FFC98A", 500, size=1.5, shadow=False)
    return s, cam, hp


def _icon(W, samples, name, out_dir, cap, globe=False):
    s, cam, hp = icon_scene(samples, W, cap, globe)
    shoot(s, cam, name, out_dir, vignette=0.28, tag_alpha=60, is_icon=True)


@image("IC1_icon_flatcap", "icon", (512, 512), "thumbs")
def ic1(W, Hh, samples, name, out_dir):
    """Evergreen: the default outfit (flat cap), a warm street-lamp halo, the town at night."""
    _icon(W, samples, name, out_dir, "Flat")


@image("IC2_icon_bobble", "icon", (512, 512), "thumbs")
def ic2(W, Hh, samples, name, out_dir):
    """Winter: the Bobble Hat (the 6-star unlock), the same framing (the Rookie has no Santa hat in the kit)."""
    _icon(W, samples, name, out_dir, "Bobble")


@image("IC3_icon_globe", "icon", (512, 512), "thumbs")
def ic3(W, Hh, samples, name, out_dir):
    """Christmas: the Snow Globe Vault full of the town's presents as the warm halo behind his head."""
    _icon(W, samples, name, out_dir, "Flat", globe=True)


# ------------------------------------------------------------------ trailer key frames (docs/marketing/TRAILER.md)
@image("TR04_first-clone", "trailer", (1920, 1080), "trailer")
def tr04(W, Hh, samples, name, out_dir):
    """Trailer beat: run 2 starts and your first clone tape-prints out of you (the scan band at its chest) and steps
    toward the shop: first person on L1, your gloves, the hook caption burned on the clone."""
    s, lv, doors, groups = level("cs1_back_room", samples)
    import level_shots as LS
    eye = (0.0, 3.8, 15.6)
    look = (0.0, 3.0, 4.0)
    cam = camera(s, eye, look, 70, W, Hh)
    LS.cut(lv["tower"], groups, eye, [])
    LS._apply_fade(eye)
    at = (0.4, 0.0, 8.4)     # 0.8 s into run 2: printed, one step into the doorway
    cl = rookie(at, 4, "walk", face="smug", crew=CYAN, group="clone")
    IS.clone_look(cl, CYAN, iplan()["clone"]["fill"])
    IS.clone_fx(at, CYAN, None, iplan())
    IS.clone_fx((0.0, 0.0, 14.0), CYAN, None, iplan())   # the spawn ring it printed from, under you
    fp_hands(cam)
    BS.snowfall((0, 0, 16), lv["backdropConfig"], eye)

    def over(img):
        x, y, _ = screen(s, cam, IS.rb(at[0] + 1.4, 4.6, at[2]))
        img = me_ago(img, (x, y), "ME, 20 SEC AGO")
        return caption(img, "RUN 2. PRESS PLAY.")
    out = shoot(s, cam, name, out_dir, hazed=True, overlay=over)
    LS.reticle(out)


@image("TR07_crew-view", "trailer", (1920, 1080), "trailer")
def tr07(W, Hh, samples, name, out_dir):
    """Trailer beat: hold CREW VIEW and the camera lifts out of your eyes to the overhead crew shot (pitch 60, FOV 50,
    Config.Heist.CAMERA.CREW): L2 Two Doors, one clone on each plate holding a door, you heading for the safe."""
    s, lv, doors, groups = level("cs2_two_doors", samples, held=True)
    import level_shots as LS
    you = (0.0, 0.0, -26.0)
    pitch, dist = math.radians(60), 40.0
    focus = (0.0, 2.0, -18.0)
    cam_r = (focus[0], focus[1] + math.sin(pitch) * dist, focus[2] + math.cos(pitch) * dist)
    cam = camera(s, cam_r, focus, 50, W, Hh)
    figs = [(rookie(you, 0, "walk", face="smug"), "3")]
    for k, p in enumerate(lv["plates"][:2]):
        b = p["box"]
        x, z = (b[0] + b[3]) / 2, (b[2] + b[5]) / 2
        figs.append((clone((x, 0.0, z), 180, "stand", hue=drift(CYAN, 1 - k, 2)), str(k + 1)))
    LS.cut(lv["tower"], groups, cam_r, [(you[0], 4.5, you[2]), (you[0], 0.8, you[2])])
    LS._apply_fade(cam_r)

    def over(img):
        from PIL import Image, ImageDraw
        import numpy as np
        for objs, lab in figs:
            x, y = head_xy(s, cam, objs, 1.6)
            img = pill(img, (x, y), lab, CYAN, 0.03)
        a = np.asarray(img).astype(np.float32)
        yy, xx = np.mgrid[0:Hh, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - Hh / 2) / (Hh / 2)) ** 2) / math.sqrt(2)
        a[..., :3] *= (1 - 0.35 * np.clip((r - 0.55) / 0.45, 0, 1))[..., None]
        img = Image.fromarray(a.clip(0, 255).astype(np.uint8))
        f, _ = MR._font(int(Hh * 0.03))
        ImageDraw.Draw(img).text((W / 2, Hh * 0.08), "CREW VIEW", font=f, fill=(244, 247, 255, 230), anchor="mm")
        return caption(img, "MY CREW? ALL ME.")
    shoot(s, cam, name, out_dir, hazed=True, overlay=over)


@image("TR09_van-drive", "trailer", (1920, 1080), "trailer")
def tr09(W, Hh, samples, name, out_dir):
    """Trailer beat: GO at the dashboard, the van pulls out through the snowy town (Heist/Drive: your van in its
    paint, headlights, lamp posts, the aurora), Hoardsworth Tower ahead."""
    cam_r = (42.0, 2.2, 19.0)
    look_r = (21.0, 5.0, -1.0)
    s = town(samples, cam_pos=cam_r, snow_focus=(30, 8, 4))
    cam = camera(s, cam_r, look_r, 46, W, Hh)
    van_at = (24.0, 0.0, 3.0)
    tag(IS.place("Van", van_at, 180, ("tint:#3DA0C8",)), "van")
    lens = IS.emissive("#FFF4E0", 6.0, key="vanlens")
    BM = iplan()["garageLight"]["BEAM"]
    for dz in (-2.3, 2.3):
        hp = (van_at[0] + 7.6, 2.6, van_at[2] + dz)
        o = MR.cyl("Headlight", 0.55, 0.55, 0.2, lens, None, tuple(IS.rb(*hp)), (0, 90, 0), seg=16)
        o.visible_shadow = False
        MR.light("SPOT", tuple(IS.rb(*hp)), tuple(IS.rb(hp[0] + 30, 0, hp[2])), "#FFF1D6", 5000, size=0.4, spot=46,
                 blend=0.4)
        for layer in BM["LAYERS"]:
            IS.beam_card("HeadBeam", (hp[0] + 0.3, hp[1], hp[2]), (hp[0] + BM["LENGTH"], hp[1] - BM["DROP"], hp[2]),
                         layer[0], layer[1], layer[2], "#FFF1D8", cam_r)
    shoot(s, cam, name, out_dir, overlay=lambda img: caption(img, "GO!"))


def render_one(name, scale, samples):
    fn, kind, size, out = IMAGES[name]
    W, Hh = int(size[0] * scale), int(size[1] * scale)
    out_dir = THUMBS if out == "thumbs" else TRAILER
    fn(W, Hh, samples, name, out_dir)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="one image (see --list)")
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--sheet", action="store_true", help="grades.json + contact sheets from the files on disk")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args(argv)
    if a.list:
        for n, (_f, kind, size, out) in IMAGES.items():
            print(n, kind, size, out)
        return
    if a.sheet:
        sheet()
        trailer_sheet()
        return
    if not a.only:
        ap.error("render one image per command: --only NAME (the container may restart; see --list)")
    render_one(a.only, a.scale, a.samples)


if __name__ == "__main__":
    main(sys.argv[1:])
