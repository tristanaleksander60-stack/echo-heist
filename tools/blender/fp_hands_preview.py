"""First-person hands preview: what the player sees, rendered in Blender (docs/research/fp_hands.md; the FP hands pass).

    python3 tools/blender/fp_hands_preview.py --pose idle [--mode after|before] [--aspect 16x9|19.5x9]
                                              [--spot front|back|lamp] [--bg l1|plain] [--samples 24] [--height 720]
    python3 tools/blender/fp_hands_preview.py --all [--mode ...]      # every pose and aspect, one process each
    python3 tools/blender/fp_hands_preview.py --sheet                 # docs/art/fp_hands/contact_sheet.png
    python3 tools/blender/fp_hands_preview.py --mode v2|v125 --light roblox --outfit tone=Tone_Mustard \
        --out docs/art/fp_hands_v2 --pose ready                       # FP HANDS v2 (skinned) vs v125 (rigid)
    python3 tools/blender/fp_hands_preview.py --sheet-v2 [--capture owner.png]   # docs/art/fp_hands_v2 sheet

The hands come from `lune run tools/fp_hands_plan.luau <mode> <fov>`: AFTER runs the game's own Heist/ViewmodelMath
and Heist/FpRig on RookieData.fpArms (the dedicated arms, the viewmodel projection, the per-axis part sizes);
BEFORE replays v101 (the body-piece arms, extracted from git af24400 into build/fp_before/). Each part is the kit
mesh from assets/fbx exactly as exported, placed at its camera-space CENTRE frame (a MeshPart's CFrame) with its
per-axis size; parented to the camera, so the frame is exactly the game's. The camera is the game's first-person
camera: the Rookie's eye 3.8 studs over the floor (FpMath.eye), FOV 70 vertical (Config.Heist.CAMERA.FP), no roll,
at 16:9 or 19.5:9. The background is the real L1 interior (tools/blender/level_shots.py builds it from KitPlan, the
same way the interiors audit does), lit by its lamps (Eevee), plus the client fill light (Config VIEWMODEL.FILL).
Lighting is an approximation (Eevee, not Roblox Future); geometry and framing are exact.

Writes docs/art/fp_hands/<mode>_<pose>_<aspect>[_<spot>].png (+ the reticle, + the screen-safe rect on --guides).
"""
import argparse, json, math, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import kit_preview as K  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "art", "fp_hands")
BUILD = os.path.join(REPO, "build")
FBX = os.path.join(REPO, "assets", "fbx")
MAN = json.load(open(os.path.join(FBX, "kit_manifest.json")))["parts"]
POSES = ["idle", "ready", "walkUp", "walkDown", "reach", "carry", "push", "point", "watch", "handsUp"]
ASPECTS = {"16x9": 16 / 9, "19.5x9": 19.5 / 9}
FOV = 70.0                      # Config.Heist.CAMERA.FP.FOV
CREW = "#3DE8FF"                # Palette.CLONE_HUES[1] (seat 1)
MARBLE = "#D8C8A8"              # Palette.marble (the glove lift target)
PALETTE = {"marble": MARBLE, "marbleLo": "#A8987A", "marbleHi": "#EDE2C8"}
BEFORE_REV = "af24400"          # v101 (the owner's last capture)
V125_REV = "e8ed654"            # v125 Published (FP HANDS v2's BEFORE: the owner's capture)
SAFE = (0.97, 0.85, -1.1)       # Config VIEWMODEL.SAFE: |x| <= X, y <= Y_TOP (drawn on --guides)
# the contact sheet's extra row (rendered with --spot / --outfit): the light check and the other outfit
EXTRAS = [("after_ready_16x9_back.png", "dim back room (ready)"), ("after_ready_16x9_lamp.png", "under a lamp (ready)"),
          ("after_carry_16x9_lamp.png", "under a lamp (carry)"),
          ("after_ready_16x9_gloves-Gloves_Leather_sweater-Sweater_Block.png", "leather gloves, block sweater"),
          ("after_watch_16x9_gloves-Gloves_Leather_sweater-Sweater_Block.png", "leather: REWIND watch")]


def lune_plan(mode, fov=FOV, outfit=None):
    if mode == "before":
        for src, dst in (("src/shared/Config.luau", "fp_before/shared/Config.luau"),
                         ("src/shared/Heist/RookieData.luau", "fp_before/shared/Heist/RookieData.luau"),
                         ("src/client/Heist/ViewmodelMath.luau", "fp_before/client/Heist/ViewmodelMath.luau")):
            path = os.path.join(BUILD, dst)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            txt = subprocess.run(["git", "show", f"{BEFORE_REV}:{src}"], cwd=REPO, capture_output=True, text=True,
                                 check=True).stdout
            open(path, "w").write(txt)
    if mode == "v125":       # the live v125 modules (main at V125_REV), so BEFORE is what the owner saw
        for src in ("src/shared/Config.luau", "src/shared/Heist/RookieData.luau", "src/client/Heist/ViewmodelMath.luau",
                    "src/client/Heist/FpRig.luau"):
            path = os.path.join(BUILD, "fp_v125", src[4:])
            os.makedirs(os.path.dirname(path), exist_ok=True)
            txt = subprocess.run(["git", "show", f"{V125_REV}:{src}"], cwd=REPO, capture_output=True, text=True,
                                 check=True).stdout
            open(path, "w").write(txt)
    plan_mode = mode
    args = ["lune", "run", "tools/fp_hands_plan.luau", plan_mode, str(fov)] + ([outfit] if outfit else [])
    out = subprocess.run(args, cwd=REPO, capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def srgb_lerp(a, b, t):
    a, b = a.lstrip("#"), b.lstrip("#")
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "#%02X%02X%02X" % tuple(round(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))


# Roblox (camera space, part local) <- Blender authoring axes: (x, y, z) -> (-x, z, y)
C = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

_LIB = {}


def library(model):
    """Imports one kit FBX once; returns {piece name: object} (left where it was authored, hidden until placed).
    Armatures (the v2 skinned gloves) stay, under their own name."""
    if model not in _LIB:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(FBX, model + ".fbx"))
        got = {}
        for o in set(bpy.data.objects) - before:
            if o.type == "MESH":
                got[o.name.split(".")[0]] = o
                o.hide_render = True
            elif o.type == "ARMATURE":
                got[o.name.split(".")[0]] = o
            else:
                bpy.data.objects.remove(o, do_unlink=True)
        _LIB[model] = got
    return _LIB[model]


def cf_matrix(c):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
    return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def place_piece(cam, piece, cf, scale, tint=None, rough=None):
    """A kit piece at a camera-space part frame (the MeshPart CFrame = the box centre) with per-axis size factors."""
    spec = MAN[piece]
    o = library(spec["model"]).get(piece)
    if o is None:
        raise KeyError(piece)
    lo, hi = spec["boundsMin"], spec["boundsMax"]
    centre = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
    W0 = o.matrix_world.copy()
    pivot = W0.translation.copy()
    D = Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    M = cf_matrix(cf) @ D @ Matrix.Translation(-centre) @ C @ Matrix.Translation(-pivot) @ W0
    o.parent = cam
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.matrix_basis = M
    o.hide_render = False
    o.visible_shadow = False
    K.style(o, "CornerShop", tint)
    if rough is not None:
        for slot in o.material_slots:
            m = slot.material
            if m and m.node_tree:
                b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if b:
                    b.inputs["Roughness"].default_value = rough
    o.name = "hand_" + piece
    return o


def v2_material(o, hexc, rough):
    """FP HANDS v2 pieces: MeshPart.Color (hexc) times the mesh's vertex shading, matte (Fabric) or a soft sheen."""
    m = bpy.data.materials.new("EH_V2_" + o.name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    nt.links.new(vc.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = K._lin(hexc)
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if "Sheen Weight" in b.inputs and rough > 0.9:
        b.inputs["Sheen Weight"].default_value = 0.35       # a knit's soft fuzz at grazing angles
    o.data.materials.clear()
    o.data.materials.append(m)


def place_v2(cam, plan, pose, p, hexc, rough):
    """A v2 piece at its final camera-space frame (never resized). The skinned glove: its armature placed so the mesh
    lands where the MeshPart does, then every pose bone set from the plan's hinge frames (the game's maths)."""
    spec = MAN[p["piece"]]
    lib = library(spec["model"])
    o = lib[p["piece"]]
    lo, hi = spec["boundsMin"], spec["boundsMax"]
    centre = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
    v2_material(o, hexc, rough)
    o.hide_render = False
    o.visible_shadow = False
    if not p.get("skinned"):
        W0 = o.matrix_world.copy()
        o.parent = cam
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.matrix_basis = cf_matrix(p["cf"]) @ Matrix.Translation(-centre) @ C @ Matrix.Translation(-W0.translation) @ W0
        return o
    arm = o.parent
    W0 = o.matrix_world.copy()
    A0 = arm.matrix_world.copy()
    L = Matrix.Translation(-centre) @ C @ Matrix.Translation(-W0.translation) @ A0     # armature space -> part space
    arm.parent = cam
    arm.matrix_parent_inverse = Matrix.Identity(4)
    arm.matrix_basis = cf_matrix(p["cf"]) @ L
    side = "Left" if "_Left_" in p["piece"] else "Right"
    rest, posed = plan["rest"][side], pose["skins"][p["piece"]]
    Li = L.inverted()
    bpy.context.view_layer.update()
    for b in arm.data.bones:            # parents come first in Blender's bone list order of creation
        if b.name not in posed:
            continue
        B0 = L @ b.matrix_local
        O = cf_matrix(rest[b.name]).inverted() @ B0
        arm.pose.bones[b.name].matrix = Li @ cf_matrix(posed[b.name]) @ O
        bpy.context.view_layer.update()
    return o


def place_cylinder(cam, cf, size, hexc):
    """A code-built Cylinder Part (the old sleeve stripes): axis along its local X."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.5, depth=1.0)
    o = bpy.context.active_object
    rot = Matrix.Rotation(math.radians(90), 4, "Y")       # Blender cylinder axis Z -> X
    o.parent = cam
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.matrix_basis = cf_matrix(cf) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)) @ rot
    o.data.materials.append(K._mat("EH_HandStripe", K._lin(hexc)))
    o.visible_shadow = False
    o.name = "hand_stripe"
    return o


def hands(cam, plan, pose_name):
    pose = plan["poses"][pose_name]
    glove = plan["glove"]
    if plan.get("gloveLift"):
        t, key = plan["gloveLift"]
        glove = srgb_lerp(glove, MARBLE if key == "marble" else glove, t)
    mats = plan.get("materials") or {}
    gloves_id = (plan.get("outfit") or {}).get("gloves", "Gloves_Knit")
    rough = {"Fabric": 0.95, "Leather": 0.55, "SmoothPlastic": 0.4}
    objs = []
    if plan.get("v2"):
        for p in pose["parts"]:
            if p.get("tint") == "gloves":
                hexc, r = glove, rough.get(mats.get(gloves_id), 0.9)
            elif p.get("tint") == "crew":
                hexc, r = CREW, rough["Fabric"]
            elif p.get("joint") == "Sleeve":
                hexc, r = PALETTE.get(plan.get("sleeveColour"), MARBLE), rough["Fabric"]
            else:
                hexc, r = "#FFFFFF", rough["SmoothPlastic"]
            objs.append(place_v2(cam, plan, pose, p, hexc, r))
        if pose.get("loot"):
            spec = MAN["CashBag"]
            k = plan["lootSize"] / max(spec["size"])
            objs.append(place_piece(cam, "CashBag", pose["loot"]["cf"], [k * f for f in pose["loot"]["scale"]]))
        return objs
    for p in pose["parts"]:
        tint = glove if p.get("tint") == "gloves" else CREW if p.get("tint") == "crew" else None
        r = None
        if p.get("tint") == "gloves":
            r = rough.get(mats.get(gloves_id))
        elif p.get("joint") == "Sleeve" or p.get("tint") == "crew":
            r = rough.get(mats.get("sleeve"))
        objs.append(place_piece(cam, p["piece"], p["cf"], p["scale"], tint, r))
    for pr in pose.get("prims") or []:
        objs.append(place_cylinder(cam, pr["cf"], pr["size"], CREW))
    if pose.get("loot"):
        spec = MAN["CashBag"]
        longest = max(spec["size"])
        k = plan["lootSize"] / longest
        sc = [k * f for f in pose["loot"]["scale"]]
        objs.append(place_piece(cam, "CashBag", pose["loot"]["cf"], sc))
    return objs


def fill_light(cam, plan):
    """The client fill (Config VIEWMODEL.FILL): a Roblox PointLight at the eye. Eevee's falloff is inverse-square, so
    the energy is matched to Roblox's at the hands' distance (about 0.45 studs): the same light on the hands, nothing
    claimed for the walls."""
    import level_shots as LS
    F = plan.get("fill")
    if not F or not F.get("ENABLED"):
        return None
    d_hand, d_lamp, r_lamp = 0.45, 6.0, 16.0
    rob = lambda d, R: max(0.0, 1 - d / R) ** 2          # noqa: E731 (Roblox-like falloff, approximate)
    energy = F["BRIGHTNESS"] * LS.LAMP_W * (rob(d_hand, F["RANGE"]) / rob(d_lamp, r_lamp)) * (d_hand / d_lamp) ** 2
    ld = bpy.data.lights.new("fill", "POINT")
    ld.color = K._lin(F["COLOUR"])[:3]
    ld.energy = energy
    ld.use_shadow = False
    ld.shadow_soft_size = 0.05
    ld.use_custom_distance = True
    ld.cutoff_distance = F["RANGE"]
    o = bpy.data.objects.new("fill", ld)
    bpy.context.scene.collection.objects.link(o)
    o.parent = cam
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.location = tuple(F["OFFSET"])
    return o


def l1_scene(samples, W, Hh, spot):
    """The real L1 interior (level_shots: KitPlan pieces, the tower's ceiling, lamps, backdrop), the first-person eye
    at one of the interiors audit's spots."""
    import level_shots as LS
    import backdrop_shots as BS
    import marketing_renders as MR
    plan = LS.load_plan(True, False)
    level = next(lv for lv in plan["levels"] if lv["id"] == "cs1_back_room")
    LS.POOL_FADE, LS.POOL_FADE_CFG = [], level["interior"]["POOL_FADE"]
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    lib = LS.Lib(level["location"])
    _held, doors, _lasers = LS.build(level, False, lib)
    LS.gus_and_cone(level, doors, level["location"], level["dressing"])
    groups = LS.tower(level["tower"], lib)
    BS.backdrop(level, lib, LS.put, LS.soft_pool_mat)
    LS.lighting(s)
    BS.world_sky(s, LS.TMP)
    cam = LS._w2_camera(s, W, Hh)
    J = LS.player(level)
    fy = level["floorY"]
    lines = LS._bands(level)
    fz1, fz0 = lines[0], lines[1]
    g = LS.goal_of(level)
    if spot == "back":       # in the back room by the cash, looking across it (dimmer, away from the lamps)
        side = 1.0 if g["x"] >= 0 else -1.0    # beside the cash, looking across its room (the interiors fp_loot_round)
        x, z, yaw, pitch = g["x"] - 2.0 * side, g["z"], side * math.pi / 2, 2.0
    elif spot == "lamp":     # under the front room's ceiling lamp, looking down the shop
        lp = min(level["lamps"], key=lambda l: abs(l["z"] - (fz1 - 6.0)) + abs(l["x"]))
        x, z, yaw, pitch = lp["x"], lp["z"] + 0.5, math.pi, -2.0
    else:                    # the shop floor looking at the back partition (the interiors audit's fp_front)
        x, z, yaw, pitch = 0.0, fz1 - 3.0, 0.0, 0.0
    pos, tgt = LS._fp(x, z, fy, yaw, pitch)
    LS.move(J, level, x, z + 40.0, 0.0)          # first person hides your body
    LS.cut(level["tower"], groups, pos, [])      # first person never cuts
    LS._apply_fade(pos)
    bp, bt = LS.rb(*pos), LS.rb(*tgt)
    cam.location = bp
    cam.rotation_euler = (bt - bp).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle_y = math.radians(FOV)
    cam.data.clip_start = 0.1                    # Roblox's near plane
    return s, cam


def roblox_light(s, cam):
    """Closer to the engine's read of the near hands (the owner's v125 capture): Roblox gives a part no ambient bounce
    or occlusion, only the flat Lighting.Ambient plus the local lamps, so the shadow side of a glove is far darker than
    Eevee's world light makes it, and the lamp side warmer. Approximation: the world (ambient) light at 40 %, a warm
    key from the shop's ceiling lamps over the hands. Same for BEFORE and AFTER."""
    w = s.world
    for n in w.node_tree.nodes:
        if n.type == "BACKGROUND":
            n.inputs["Strength"].default_value *= 0.4
    ld = bpy.data.lights.new("lampkey", "POINT")
    ld.color = K._lin("#FFD2A0")[:3]
    ld.energy = 3.0
    ld.use_shadow = False
    ld.shadow_soft_size = 0.3
    o = bpy.data.objects.new("lampkey", ld)
    s.collection.objects.link(o)
    o.parent = cam
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.location = (0.0, 0.9, -0.4)


def plain_scene(samples, W, Hh):
    """A quick neutral stage (iteration only): a dim plum room light + a warm key, like an L1 interior."""
    import marketing_renders as MR
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    cd.sensor_fit = "VERTICAL"
    cd.angle_y = math.radians(FOV)
    cd.clip_start = 0.1
    s.render.resolution_x, s.render.resolution_y = W, Hh
    cam.location = (0, 0, 3.8)
    cam.rotation_euler = (math.radians(90), 0, 0)
    w = s.world
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = K._lin("#3A3560")
    bg.inputs[1].default_value = 0.6
    MR.light("SUN", (2, -2, 8), (0, 0, 0), "#FFE2C0", 2.2, size=2.0, shadow=False)
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 20, 0))
    bpy.context.active_object.data.materials.append(K._mat("floor", K._lin("#36314D")))
    return s, cam


def guides(path):
    """The screen-safe rect (Config VIEWMODEL.SAFE) and the centre third, drawn over a finished frame."""
    from PIL import Image, ImageDraw
    im = Image.open(path).convert("RGB")
    W, Hh = im.size
    d = ImageDraw.Draw(im)
    X, YT, _YB = SAFE
    x0, x1 = W / 2 - X * W / 2, W / 2 + X * W / 2
    y0 = Hh / 2 - YT * Hh / 2
    d.line([(x0, Hh), (x0, y0), (x1, y0), (x1, Hh)], fill=(255, 210, 122), width=2)
    for fx in (1 / 3, 2 / 3):
        d.line([(W * fx, 0), (W * fx, Hh)], fill=(120, 120, 160), width=1)
    im.save(path, optimize=True)


def render_one(a):
    W = int(round(a.height * ASPECTS[a.aspect]))
    Hh = a.height
    if a.bg == "l1":
        s, cam = l1_scene(a.samples, W, Hh, a.spot)
    else:
        s, cam = plain_scene(a.samples, W, Hh)
    plan = lune_plan(a.mode, FOV, a.outfit)
    hands(cam, plan, a.pose)
    if a.mode in ("after", "v125", "v2"):
        fill_light(cam, plan)
    if a.light == "roblox":
        roblox_light(s, cam)
    os.makedirs(OUT, exist_ok=True)
    tag = f"{a.mode}_{a.pose}_{a.aspect}" + ("" if a.spot == "front" else "_" + a.spot) + \
        ("" if a.light == "eevee" else "_" + a.light) + \
        ("" if a.bg == "l1" else "_plain") + (("_" + a.outfit.replace("=", "-").replace(",", "_")) if a.outfit else "")
    raw = os.path.join(BUILD, "fp_hands_raw", tag + ".png")
    os.makedirs(os.path.dirname(raw), exist_ok=True)
    s.render.filepath = raw
    s.camera = cam
    bpy.ops.render.render(write_still=True)
    out = os.path.join(OUT if not a.out else a.out, tag + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    import level_shots as LS
    import backdrop_shots as BS
    import marketing_renders as MR
    tm = BS.tonemap(raw, raw.replace(".png", "_tm.png"))
    MR.finish(tm, out, [], tag=False, vignette=0.12, truecolor=True)
    LS.reticle(out)
    if a.guides:
        guides(out)
    print("wrote", os.path.relpath(out, REPO))


def sheet(out_path, aspect_rows=("16x9", "19.5x9")):
    """Before / after contact sheet: per aspect, a BEFORE row and an AFTER row, one column per pose."""
    from PIL import Image, ImageDraw, ImageFont
    cols = POSES
    tw = 300
    rows = []
    for asp in aspect_rows:
        for mode in ("before", "after"):
            rows.append((asp, mode))
    th = {a: int(round(tw / ASPECTS[a])) for a in aspect_rows}
    pad, head, lab = 6, 46, 18
    # an extra row: the light check (a dim back-room spot, right under a lamp) and the other outfit
    extras = [(f, t) for f, t in EXTRAS if os.path.isfile(os.path.join(OUT, f))]
    H = head + sum(th[a] + lab + pad for a, _m in rows) + pad + ((th["16x9"] + lab + pad) if extras else 0)
    Wd = pad + 90 + len(cols) * (tw + pad)
    sheet_im = Image.new("RGB", (Wd, H), (24, 26, 46))
    d = ImageDraw.Draw(sheet_im)
    try:
        f = ImageFont.truetype("DejaVuSans.ttf", 14)
        fb = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
    except OSError:
        f = fb = ImageFont.load_default()
    d.text((pad, 10), "First-person hands: BEFORE (v101, body-piece arms) vs AFTER (dedicated FP arms), L1 interior, "
                      "FOV 70, the game's camera and transforms", fill=(244, 247, 255), font=fb)
    y = head
    for asp, mode in rows:
        d.text((pad, y + th[asp] // 2), f"{mode.upper()}\n{asp}", fill=(255, 210, 122) if mode == "after" else
               (169, 178, 204), font=f)
        for i, pose in enumerate(cols):
            x = pad + 90 + i * (tw + pad)
            p = os.path.join(OUT, f"{mode}_{pose}_{asp}.png")
            if os.path.isfile(p):
                im = Image.open(p).convert("RGB").resize((tw, th[asp]), Image.LANCZOS)
                sheet_im.paste(im, (x, y + lab))
            else:
                d.rectangle([x, y + lab, x + tw, y + lab + th[asp]], outline=(80, 80, 110))
            d.text((x + 2, y + 1), pose, fill=(220, 224, 240), font=f)
        y += th[asp] + lab + pad
    if extras:
        d.text((pad, y + th["16x9"] // 2), "AFTER\nlight +\noutfit", fill=(255, 210, 122), font=f)
        for i, (fname, title) in enumerate(extras):
            x = pad + 90 + i * (tw + pad)
            im = Image.open(os.path.join(OUT, fname)).convert("RGB").resize((tw, th["16x9"]), Image.LANCZOS)
            sheet_im.paste(im, (x, y + lab))
            d.text((x + 2, y + 1), title, fill=(220, 224, 240), font=f)
    sheet_im.save(out_path, optimize=True)
    print("wrote", os.path.relpath(out_path, REPO))


V2_POSES = ["idle", "ready", "reach", "carry", "point", "watch", "handsUp", "push"]
V2_TAG = "_16x9_roblox_tone-Tone_Mustard"
V2_EXTRAS = [("v2_ready_16x9_roblox.png", "AFTER: indigo knit (default)"),
             ("v2_watch_16x9_roblox_gloves-Gloves_Leather_sweater-Sweater_Block.png", "AFTER: leather, block"),
             ("v2_ready_19.5x9_roblox_tone-Tone_Mustard.png", "AFTER: 19.5:9 phone"),
             ("v125_ready_16x9_back_roblox_tone-Tone_Mustard.png", "BEFORE: dim back room"),
             ("v2_ready_16x9_back_roblox_tone-Tone_Mustard.png", "AFTER: dim back room")]


def sheet_v2(out_dir, capture=None):
    """FP HANDS v2 before / after (docs/art/fp_hands_v2/contact_sheet.png): the owner's v125 capture, BEFORE (v125,
    the rigid capsule arms) and AFTER (v2, the skinned gloves) per pose in the owner's outfit (Mustard knit) under the
    Roblox-like light, hand close-ups, and the extras (other outfits, the phone aspect, a dim room)."""
    from PIL import Image, ImageDraw, ImageFont
    tw, th = 300, 169
    pad, lab = 6, 18
    cols = V2_POSES
    Wd = pad + 90 + len(cols) * (tw + pad)
    rows_h = [th * 2 + lab, th + lab, th + lab, th * 2 + lab, th + lab]
    H = 50 + sum(h + pad for h in rows_h)
    im = Image.new("RGB", (Wd, H), (24, 26, 46))
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype("DejaVuSans.ttf", 14)
        fb = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
    except OSError:
        f = fb = ImageFont.load_default()
    d.text((pad, 10), "FP HANDS v2: BEFORE (v125 rigid capsule arms) vs AFTER (one skinned glove a hand). Owner's "
                      "outfit (Mustard knit), L1, FOV 70, the game's own maths, Roblox-like light (flat ambient, warm "
                      "lamp key)", fill=(244, 247, 255), font=fb)
    y = 50
    d.text((pad, y + 40), "OWNER\nv125\ncapture", fill=(255, 140, 140), font=f)
    if capture and os.path.isfile(capture):
        cap = Image.open(capture).convert("RGB")
        w = int(cap.width * (th * 2) / cap.height)
        im.paste(cap.resize((w, th * 2), Image.LANCZOS), (pad + 90, y + lab))
        d.text((pad + 92, y), "the owner's live v125 screenshot (reference)", fill=(220, 224, 240), font=f)
    y += rows_h[0] + pad
    for mode, label, colr in (("v125", "BEFORE\nv125", (169, 178, 204)), ("v2", "AFTER\nv2", (255, 210, 122))):
        d.text((pad, y + th // 2), label, fill=colr, font=f)
        for i, pose in enumerate(cols):
            x = pad + 90 + i * (tw + pad)
            path = os.path.join(out_dir, f"{mode}_{pose}{V2_TAG}.png")
            if os.path.isfile(path):
                im.paste(Image.open(path).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y + lab))
            else:
                d.rectangle([x, y + lab, x + tw, y + lab + th], outline=(80, 80, 110))
            d.text((x + 2, y + 1), pose, fill=(220, 224, 240), font=f)
        y += th + lab + pad
    # close-ups: one hand of a few poses, BEFORE then AFTER, 2x
    d.text((pad, y + th), "CLOSE\n2x", fill=(255, 210, 122), font=f)
    x = pad + 90
    for pose in ("ready", "point", "watch", "handsUp"):
        for mode in ("v125", "v2"):
            path = os.path.join(out_dir, f"{mode}_{pose}{V2_TAG}.png")
            if not os.path.isfile(path):
                continue
            src = Image.open(path).convert("RGB")
            W0, H0 = src.size
            box = (int(W0 * 0.56), int(H0 * 0.52), int(W0 * 0.98), int(H0 * 1.0)) if pose != "watch" else \
                (int(W0 * 0.10), int(H0 * 0.40), int(W0 * 0.62), int(H0 * 0.98))
            crop = src.crop(box)
            cw = int(crop.width * (th * 2) / crop.height)
            if x + cw > Wd:
                break
            im.paste(crop.resize((cw, th * 2), Image.LANCZOS), (x, y + lab))
            d.text((x + 2, y + 1), f"{'BEFORE' if mode == 'v125' else 'AFTER'} {pose}", fill=(220, 224, 240), font=f)
            x += cw + pad
    y += rows_h[3] + pad
    d.text((pad, y + th // 2), "EXTRAS", fill=(255, 210, 122), font=f)
    for i, (fname, title) in enumerate(V2_EXTRAS):
        x = pad + 90 + i * (tw + pad)
        path = os.path.join(out_dir, fname)
        if os.path.isfile(path):
            src = Image.open(path).convert("RGB")
            im.paste(src.resize((tw, int(tw * src.height / src.width)), Image.LANCZOS), (x, y + lab))
        d.text((x + 2, y + 1), title, fill=(220, 224, 240), font=f)
    out = os.path.join(out_dir, "contact_sheet.png")
    im.save(out, optimize=True)
    print("wrote", os.path.relpath(out, REPO))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--pose", default="idle", choices=POSES)
    ap.add_argument("--mode", default="after", choices=("after", "before", "v125", "v2"))
    ap.add_argument("--light", default="eevee", choices=("eevee", "roblox"),
                    help="roblox: the in-game read (flat lavender Ambient, no ambient occlusion on the hands)")
    ap.add_argument("--aspect", default="16x9", choices=tuple(ASPECTS))
    ap.add_argument("--spot", default="front", choices=("front", "back", "lamp"))
    ap.add_argument("--bg", default="l1", choices=("l1", "plain"))
    ap.add_argument("--outfit", help="slot=id,... (AFTER only), e.g. gloves=Gloves_Leather,sweater=Sweater_Block")
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--height", type=int, default=720)
    ap.add_argument("--guides", action="store_true", help="draw the screen-safe rect")
    ap.add_argument("--out", help="output folder (default docs/art/fp_hands)")
    ap.add_argument("--all", action="store_true", help="every pose x aspect, one Blender process each")
    ap.add_argument("--sheet", action="store_true")
    ap.add_argument("--sheet-v2", action="store_true", help="docs/art/fp_hands_v2/contact_sheet.png")
    ap.add_argument("--capture", help="--sheet-v2: the owner's capture to show as the reference row")
    a = ap.parse_args(argv)
    if a.sheet:
        sheet(os.path.join(OUT, "contact_sheet.png"))
        return
    if a.sheet_v2:
        sheet_v2(a.out or os.path.join(REPO, "docs", "art", "fp_hands_v2"), a.capture)
        return
    if a.all:
        for asp in ASPECTS:
            for pose in POSES:
                cmd = [sys.executable, os.path.abspath(__file__), "--pose", pose, "--mode", a.mode, "--aspect", asp,
                       "--spot", a.spot, "--bg", a.bg, "--samples", str(a.samples), "--height", str(a.height),
                       "--light", a.light] + (["--outfit", a.outfit] if a.outfit else [])
                subprocess.run(cmd + (["--out", a.out] if a.out else []), check=False)
        return
    render_one(a)


if __name__ == "__main__":
    main(sys.argv[1:])
