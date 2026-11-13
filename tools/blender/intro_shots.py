"""Key frames of the story intro (docs/art/intro/STORYBOARD.md): one still per shot, staged in Blender from the SAME
plan the client plays (Shared/Heist/IntroPlan via tools/blender/intro_plan.luau: stage, camera, poses, props,
effects, captions) with the uploaded intro kit (assets/fbx: Hoardsworth, Intro_*) and the launch kit (Van,
StreetLamp, Xmas_Tree), lit with the shot's mood in Eevee.

    python3 tools/blender/intro_shots.py [--only N] [--scale 0.6667] [--samples 24]

Writes docs/art/intro/shot_N.png (1920 x 1080 x scale; 256 colours + dither, like the marketing concepts) and
docs/art/intro/contact_sheet.png. Each shot renders in its own Blender process. What is a stand-in here: the
Rookie is the CHARACTER track's (assets/fbx/Rookie*.fbx, posed by the plan's joint angles, default outfit); the aurora
curtains, suction beams, headlight beams and snow are code effects in the game (Heist/Cinematic) drawn here as
emissive meshes; the caption card, the letterbox and the title wordmark are 2D, as in the game.
"""
import argparse, json, math, os, random, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import marketing_renders as MR  # noqa: E402
import kit_preview as K  # noqa: E402
import backdrop_shots as BS  # noqa: E402
import eh_palette as P  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "art", "intro")
H = P.HEX
WARM = P.WARM_BULB
LOC = "Bank"


def rb(x, y, z):
    return Vector((-x, z, y))


def rbv(v):
    return rb(v[0], v[1], v[2])


# Roblox -> Blender axes as a 4x4 (x, y, z) -> (-x, z, y)
C4 = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C4I = C4.inverted()


def r_euler_yxz(rx, ry, rz):
    """CFrame.fromEulerAnglesYXZ(rx, ry, rz) (degrees) as a 4x4 in Roblox axes."""
    return (Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X")
            @ Matrix.Rotation(math.radians(rz), 4, "Z"))


def plan():
    out = subprocess.run(["lune", "run", "tools/blender/intro_plan.luau"], cwd=REPO, capture_output=True, text=True,
                         check=True).stdout
    return json.loads(out)


# ------------------------------------------------------------------ materials
def emissive(hexc, strength, alpha=1.0, key=None):
    return MR.mat(hexc, 0.5, emit=strength, alpha=alpha, key=key)


def gradient_mat(name, bottom, top, strength, alpha_bottom, alpha_top):
    """Emission along the mesh's UV v (0 bottom -> 1 top): colour and alpha ramps; additive-looking."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    uv = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = MR.lin(bottom)
    ramp.color_ramp.elements[1].color = MR.lin(top)
    aramp = nt.nodes.new("ShaderNodeMapRange")
    aramp.inputs["To Min"].default_value = alpha_bottom
    aramp.inputs["To Max"].default_value = alpha_top
    nt.links.new(sep.outputs["Y"], ramp.inputs["Fac"])
    nt.links.new(sep.outputs["Y"], aramp.inputs["Value"])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = strength
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(aramp.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    m.surface_render_method = "BLENDED"
    m.use_backface_culling = False
    return m


def ribbon(name, pts, height, mat, wave=0.0, seed=1):
    """A vertical curtain along pts (Roblox points at the curtain's foot), UV v 0 -> 1 up."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    cols = []
    for i, p in enumerate(pts):
        hgt = height * (0.75 + 0.5 * rng.random())
        top = (p[0] + wave * math.sin(i * 0.7), p[1] + hgt, p[2] + wave * math.cos(i * 0.5))
        cols.append((bm.verts.new(rb(*p)), bm.verts.new(rb(*top)), i / max(1, len(pts) - 1)))
    for (a0, a1, u0), (b0, b1, u1) in zip(cols, cols[1:]):
        f = bm.faces.new((a0, b0, b1, a1))
        for lp, (u, v) in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))):
            lp[uv].uv = (u, v)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    o.visible_shadow = False
    return o


def cone(name, apex, base_c, r0, r1, mat, segs=24):
    """A truncated cone from apex (radius r0) to base_c (radius r1), Roblox points; UV v 0 at the apex."""
    a, b = rbv(apex), rbv(base_c)
    d = (b - a)
    n = d.normalized()
    u = n.orthogonal().normalized()
    w = n.cross(u)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    ring0 = [bm.verts.new(a + r0 * (math.cos(t) * u + math.sin(t) * w)) for t in (2 * math.pi * j / segs for j in range(segs))]
    ring1 = [bm.verts.new(b + r1 * (math.cos(t) * u + math.sin(t) * w)) for t in (2 * math.pi * j / segs for j in range(segs))]
    for j in range(segs):
        k = (j + 1) % segs
        f = bm.faces.new((ring0[j], ring0[k], ring1[k], ring1[j]))
        for lp, (uu, vv) in zip(f.loops, ((j / segs, 0), ((j + 1) / segs, 0), ((j + 1) / segs, 1), (j / segs, 1))):
            lp[uvl].uv = (uu, vv)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    o.visible_shadow = False
    return o


def box(name, lo, hi, mat, shadow=True):
    a, b = rb(*lo), rb(*hi)
    size = (abs(b.x - a.x), abs(b.y - a.y), abs(b.z - a.z))
    o = MR.box(name, size, mat, None, tuple((a + b) / 2), bevel=0.0)
    o.visible_shadow = shadow
    return o


# ------------------------------------------------------------------ world
def world(s, mood):
    """Camera rays see the Heist City sky (turned 180 deg: Heist/Cinematic turns Sky.SkyboxOrientation so the
    painted landmark never doubles the 3D tower); lighting sees the mood's outdoor ambient."""
    tmp = os.path.join(REPO, "build", "blender")
    os.makedirs(tmp, exist_ok=True)
    path = BS.equirect(os.path.join(tmp, "sky_city_equirect.png"))
    nt = s.world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    lp = nt.nodes.new("ShaderNodeLightPath")
    amb = nt.nodes.new("ShaderNodeBackground")
    o = mood["outdoor"]
    amb.inputs["Color"].default_value = MR.lin("#%02X%02X%02X" % tuple(int(v) for v in o))
    amb.inputs["Strength"].default_value = 0.55 * mood["brightness"]
    sky = nt.nodes.new("ShaderNodeBackground")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(path)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0, 0, math.pi)
    nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], env.inputs["Vector"])
    nt.links.new(env.outputs["Color"], sky.inputs["Color"])
    sky.inputs["Strength"].default_value = 1.15
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(amb.outputs[0], mix.inputs[1])
    nt.links.new(sky.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    s.view_settings.exposure = 0.2 + mood["exposure"]


# ------------------------------------------------------------------ the stage
def place(model, pos_r, yaw=0.0, flags=()):
    return K.place(model, tuple(rbv(pos_r)), yaw, tuple(flags), False, LOC)


def set_neon(objs, name_part, hexc, strength):
    for o in objs:
        if name_part in o.name:
            m = emissive(hexc, strength, key=("neon", name_part, hexc, strength))
            o.data.materials.clear()
            o.data.materials.append(m)


def tower(st, lit):
    T = st["tower"]
    bx, _by, bz = T["base"]
    y = 0.0
    body, trim, dark = MR.mat(H["ribbon"], 0.55), MR.mat(H["marble_lo"], 0.35), MR.mat(H["ink_hi"], 0.6)
    win = emissive(WARM if lit else H["steel_lo"], 2.2 if lit else 0.2, key=("twin", lit))
    for i, (w, h) in enumerate(T["tiers"]):
        box(f"Tier{i}", (bx - w / 2, y, bz - w / 2), (bx + w / 2, y + h, bz + w / 2), body)
        box(f"Cornice{i}", (bx - w / 2 - 1, y + h - 1.6, bz - w / 2 - 1), (bx + w / 2 + 1, y + h, bz + w / 2 + 1), trim)
        # columns of lit windows on the front (+Z) and the sides
        rows = int((h - 6) // 7)
        cols = int((w - 6) // 6)
        for r in range(rows):
            for c in range(cols):
                x = bx - (cols - 1) * 3 + c * 6
                yy = y + 4 + r * 7
                box(f"W{i}_{r}_{c}", (x - 1.3, yy, bz + w / 2 - 0.2), (x + 1.3, yy + 4, bz + w / 2 + 0.25), win, False)
                box(f"WS{i}_{r}_{c}", (bx + w / 2 - 0.2, yy, bz - (cols - 1) * 3 + c * 6 - 1.3),
                    (bx + w / 2 + 0.25, yy + 4, bz - (cols - 1) * 3 + c * 6 + 1.3), win, False)
        # gold fins up the corners
        for sx in (-1, 1):
            box(f"Fin{i}_{sx}", (bx + sx * w / 2 - 1.2, y, bz + w / 2 - 1.2), (bx + sx * w / 2 + 1.2, y + h - 1.6,
                                                                             bz + w / 2 + 1.2), trim)
        y += h
    dy = st["deckY"]
    dw, dh, dd = T["deck"]
    box("Deck", (bx - dw / 2, dy - dh, bz - dd / 2), (bx + dw / 2, dy, bz + dd / 2), dark)
    box("DeckTrim", (bx - dw / 2 - 0.4, dy - dh - 0.6, bz - dd / 2 - 0.4), (bx + dw / 2 + 0.4, dy - dh + 0.4,
                                                                           bz + dd / 2 + 0.4), trim)
    for sx in (-1, 1):   # railing posts on the front edge
        box(f"Rail{sx}", (bx + sx * dw / 2 - 0.3, dy, bz + dd / 2 - 0.6), (bx + sx * dw / 2 + 0.3, dy + 3.2,
                                                                          bz + dd / 2), trim)


def town(st, lit, shot_id):
    snow = MR.mat(H["snow"], 0.9, key="ground")
    snow_dim = MR.mat("#8E92AC", 0.95, key="ground2")
    g = st["ground"]
    c, sz = g["centre"], g["size"]
    box("Ground", (c[0] - sz[0] / 2, -1, c[2] - sz[2] / 2), (c[0] + sz[0] / 2, 0, c[2] + sz[2] / 2), snow_dim)
    r = st["road"]
    box("Road", (r["centre"][0] - r["size"][0] / 2, 0, -r["size"][2] / 2), (r["centre"][0] + r["size"][0] / 2, 0.15,
                                                                            r["size"][2] / 2), MR.mat(H["ink_hi"], 0.8))
    del snow
    objs = []
    for x, z, yaw, variant, wlit in st["houses"]:
        name = "Intro_House_" + ("A" if variant == 1 else "B")
        os_ = place(name, (x, 0, z), yaw)
        on = lit and wlit == 1
        set_neon(os_, "_Windows", WARM if on else H["steel_lo"], 2.6 if on else 0.15)
        objs += os_
    for x, z in st["lamps"]:
        place("StreetLamp", (x, 0, z), 0)
        if lit:
            MR.light("POINT", tuple(rb(x, 10.4, z)), None, WARM, 900, size=0.6, shadow=False)
    tree = place("Xmas_Tree", tuple(st["tree"]), 0)
    for o in tree:
        o.matrix_world = Matrix.Scale(2.6, 4) @ o.matrix_world
    set_neon(tree, "Xmas_Tree_Lights", WARM, 4.0)
    if lit:
        for x, z, yaw, variant, wlit in st["houses"][:12]:
            if wlit:
                MR.light("POINT", tuple(rb(x, 4.0, z + (-7 if yaw == 0 else 7))), None, WARM, 380, size=2, shadow=False)
    return objs


def hoardsworth(at, yaw, pose, rig):
    """The rig posed like Heist/Cinematic: world[i] = world[parent] * C0 * pose (Roblox CFrames)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(K.FBX, "Hoardsworth.fbx"))
    objs = {o.name.split(".")[0]: o for o in set(bpy.data.objects) - before if o.type == "MESH"}
    place_m = Matrix.Translation(rbv(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    world = {}
    origin = {p["name"]: p["origin"] for p in rig}
    for p in rig:
        jo = p["origin"]
        par = p.get("parent")
        po = origin[par] if par else (0, 0, 0)
        c0 = Matrix.Translation((jo[0] - po[0], jo[1] - po[1], jo[2] - po[2]))
        e = pose.get(p["joint"], (0, 0, 0))
        w = (world[par] if par else Matrix.Identity(4)) @ c0 @ r_euler_yxz(*e)
        world[p["name"]] = w
        delta = w @ Matrix.Translation(jo).inverted()
        o = objs.get(p["name"])
        if o:
            o.matrix_world = place_m @ (C4 @ delta @ C4I) @ o.matrix_world
            K.style(o, LOC)
    mono = world["Hoardsworth_Monocle"].translation
    return place_m @ (C4 @ Vector((mono.x, mono.y, mono.z, 1.0))).to_3d() if False else \
        (place_m @ (C4 @ Matrix.Translation(mono))).translation



ROOKIE_OUTFIT = ("Rookie_Cap_Flat", "Rookie_Scarf_Long", "Rookie_Stripes_Torso", "Rookie_Stripes_LeftArm",
                 "Rookie_Stripes_RightArm", "Rookie_Gloves_Knit_Left", "Rookie_Gloves_Knit_Right")
CREW_HUE = "#3DE8FF"     # the template's seat-1 hue (server Heist/Rookie)
GLOVES = "#2A2D52"       # Config.Rookie.GLOVES.Gloves_Knit


def rookie(at, yaw, pose, face="idle", clone=None, dim=0.0):
    """The CHARACTER track's Rookie (assets/fbx/Rookie*.fbx, the kit manifest's joints and attach points) posed like
    Heist/Cinematic poses the CharacterKit template: Motor6D.Transform = the IntroPlan joint angles; default outfit
    (flat cap, long scarf, stripes, knit gloves) in the seat hue; `clone` = a clone's hue (emissive copy)."""
    man = K.MANIFEST

    def load(fbx, keep):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(K.FBX, fbx + ".fbx"))
        out = {}
        for o in set(bpy.data.objects) - before:
            base = o.name.split(".")[0]
            if o.type == "MESH" and keep(base):
                out[base] = o
            else:
                bpy.data.objects.remove(o, do_unlink=True)
        return out

    body = load("Rookie", lambda n: n != "Rookie_Face_Idle" or face == "idle")
    extra = load("Rookie_Outfits", lambda n: n in ROOKIE_OUTFIT)
    if face != "idle" and not clone:
        extra.update(load("Rookie_Faces", lambda n: n == "Rookie_Face_" + face.capitalize()))
    place_m = Matrix.Translation(rbv(at)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    joints = {n: v for n, v in man.items() if v.get("model") == "Rookie" and v.get("joint")}
    world = {}

    def solve(name):
        if name in world:
            return world[name]
        v = joints[name]
        par = v["joint"].get("parent")
        o = v["origin"]
        po = joints[par]["origin"] if par else (0, 0, 0)
        e = pose.get(v["joint"]["name"], (0, 0, 0))
        w = (solve(par) if par else Matrix.Identity(4)) @ Matrix.Translation(
            (o[0] - po[0], o[1] - po[1], o[2] - po[2])) @ r_euler_yxz(*e)
        world[name] = w
        return w

    def put(o, W, origin, tint=None):
        delta = W @ Matrix.Translation(origin).inverted()
        o.matrix_world = place_m @ (C4 @ delta @ C4I) @ o.matrix_world
        if clone:
            m = MR.mat(clone, 0.45, emit=1.1, key=("rkclone", clone, dim))
            m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = MR.lin(clone, 0.4 * (1 - dim))
            o.data.materials.clear()
            o.data.materials.append(m)
            o.visible_shadow = False
        else:
            K.style(o, LOC, tint)

    for name, o in body.items():
        if name in joints:
            put(o, solve(name), joints[name]["origin"])
        else:   # the idle face: rigid with the head
            put(o, solve("Rookie_Head"), man[name]["origin"])
    for name, o in extra.items():
        v = man[name]
        a = v.get("attach") or {"part": "Head", "offset": [0, 0, 0]}
        W = solve("Rookie_" + a["part"]) @ Matrix.Translation(tuple(a["offset"]))
        tint = GLOVES if "Gloves" in name else (CREW_HUE if v.get("tint") else None)
        put(o, W, v["origin"], tint)


FIG_JOINT = {"RightShoulder": "shR", "RightElbow": "elR", "LeftShoulder": "shL", "LeftElbow": "elL", "Neck": "neck",
             "Waist": "waist", "RightHip": "hipR", "RightKnee": "knR", "LeftHip": "hipL", "LeftKnee": "knL"}


def fig_pose(pose):
    out = {}
    for j, key in FIG_JOINT.items():
        e = pose.get(j)
        if e and any(abs(v) > 1e-6 for v in e):
            m = (C4 @ r_euler_yxz(*e) @ C4I).to_euler("XYZ")
            out[key] = tuple(math.degrees(a) for a in m)
    return out


def garage(st, lights_on):
    g = st["garage"]
    cx, _cy, cz = g["centre"]
    w, h, d = g["size"]
    brick, brick_hi = MR.mat("#573429", 0.85), MR.mat("#704B3E", 0.8)
    floor = MR.mat(H["floor_a"], 0.7)
    x0, x1, z0, z1 = cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2
    box("GFloor", (x0, -0.05, z0), (x1, 0.05, z1 + 2), floor)
    box("GBack", (x0, 0, z0 - 1), (x1, h, z0), brick)
    box("GLeft", (x0 - 1, 0, z0 - 1), (x0, h, z1), brick)
    box("GRight", (x1, 0, z0 - 1), (x1 + 1, h, z1), brick)
    box("GRoof", (x0 - 1.5, h, z0 - 1.5), (x1 + 1.5, h + 1.2, z1 + 1.5), MR.mat(H["ink_hi"], 0.7))
    box("GHeader", (x0 - 1, h - 2.5, z1 - 1), (x1 + 1, h, z1), brick_hi)
    box("GPostL", (x0 - 1, 0, z1 - 1), (x0 + 2, h, z1), brick_hi)
    box("GPostR", (x1 - 2, 0, z1 - 1), (x1 + 1, h, z1), brick_hi)
    box("GSnow", (x0 - 1.6, h + 1.2, z0 - 1.6), (x1 + 1.6, h + 1.7, z1 + 1.6), MR.mat(H["snow"], 0.9))
    # a workbench and pegboard on the back wall: it is the crew's hideout
    box("Bench", (x0 + 2, 0, z0), (x0 + 10, 3.2, z0 + 2.4), MR.mat(H["wood"], 0.7))
    box("Peg", (x0 + 2, 4.5, z0), (x0 + 10, 9, z0 + 0.3), MR.mat(H["wood_lo"], 0.8))
    box("Shelf", (x1 - 9, 0, z0), (x1 - 2, 7, z0 + 2), MR.mat(H["steel_lo"], 0.6))
    place("Van", tuple(st["van"]["at"]), st["van"]["yaw"], ("tint:#8C6448",))
    lens = emissive("#FFF4E0" if lights_on else H["steel_lo"], 6.0 if lights_on else 0.1, key=("lens", lights_on))
    for hp in st["headlights"]:
        o = MR.cyl("Headlight", 0.55, 0.55, 0.2, lens, None, tuple(rbv(hp) + Vector((0, 0.05, 0))), (90, 0, 0), seg=16)
        o.visible_shadow = False
        if lights_on:
            MR.light("SPOT", tuple(rbv(hp) + Vector((0, 0.3, 0))), tuple(rb(hp[0], 1.5, hp[2] + 30)), "#FFF1D8", 9000,
                     size=0.4, spot=46, blend=0.35)
            # the beams themselves are camera-facing Beams in the game; a still shows their pool on the floor
            pool = MR.mat("#FFF1D8", 0.9, emit=0.35, alpha=0.35, key="pool")
            o = MR.cyl("Pool", 3.2, 3.2, 0.02, pool, None, tuple(rb(hp[0], 0.08, hp[2] + 9)), seg=24, scale=(1, 2.2, 1))
            o.visible_shadow = False
    if lights_on:   # the work lamp over the Rookie comes on with the headlights (Heist/Cinematic)
        MR.light("POINT", tuple(rb(cx, 6.5, cz + 11.5)), None, "#FFC890", 2200, size=1.2, shadow=True)


# ------------------------------------------------------------------ effects
def aurora(layers=3):
    cols = (("#46D88A", "#7A5CC8"), ("#38B878", "#5E4AB0"), ("#62E09A", "#8A6AD8"))
    for k in range(layers):
        z = -420 - 120 * k
        pts = []
        for i in range(40):
            x = -460 + i * 24
            pts.append((x, 150 + 40 * k + 18 * math.sin(i * 0.33 + k), z + 60 * math.sin(i * 0.21 + k * 1.7)))
        bottom, top = cols[k % 3]
        m = gradient_mat(f"Aurora{k}", bottom, top, 1.5 - 0.3 * k, 0.42 - 0.1 * k, 0.0)
        ribbon(f"Aurora{k}", pts, 150, m, wave=8, seed=k + 3)


def snowfall(centre, size, n=900, seed=5, cam=None):
    rng = random.Random(seed)
    m = MR.mat("#E6E9F7", 0.9, emit=0.5, key="snowflake")
    bm = bmesh.new()
    for _ in range(n):
        p = (centre[0] + rng.uniform(-size[0], size[0]), centre[1] + rng.uniform(-size[1], size[1]),
             centre[2] + rng.uniform(-size[2], size[2]))
        if cam is not None and math.dist(p, cam) < 9:
            continue
        g = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=rng.uniform(0.05, 0.13))
        for v in g["verts"]:
            v.co += rb(*p)
    o = MR._obj("Snow", bm, m)
    o.visible_shadow = False
    return o


def suction(st):
    """The vacuum's pull: pale beams from the mouth down to the town, and streaks spiralling up."""
    nz = st["nozzle"]
    m = gradient_mat("Suction", "#F6C0A2", "#E8ECFF", 0.8, 0.07, 0.0)
    del m   # the game's suction Beams are thin camera-facing ribbons; the streaks carry the read in a still
    streak = gradient_mat("Streak", "#F6C0A2", "#FFF4E0", 2.2, 0.0, 0.45)
    rng = random.Random(9)
    for i in range(14):
        a0 = rng.uniform(0, 2 * math.pi)
        r0 = rng.uniform(14, 40)
        pts = []
        for j in range(16):
            s = j / 15
            a = a0 + s * 3.2
            r = r0 * (1 - s) + 3
            base = (nz[0] * s + (r0 * math.cos(a0)) * (1 - s) * 0.4, 8 + (nz[1] - 8) * s, nz[2] * s)
            pts.append((base[0] + math.cos(a) * r, base[1], base[2] + math.sin(a) * r))
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        prev = None
        for j, p in enumerate(pts):
            v0 = bm.verts.new(rb(*p))
            v1 = bm.verts.new(rb(p[0], p[1] + 0.3, p[2]))
            if prev:
                f = bm.faces.new((prev[0], v0, v1, prev[1]))
                for lp, uv in zip(f.loops, ((0, (j - 1) / 15), (0, j / 15), (1, j / 15), (1, (j - 1) / 15))):
                    lp[uvl].uv = (uv[1], uv[0])
            prev = (v0, v1)
        me = bpy.data.meshes.new("streak")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("streak", me)
        bpy.context.scene.collection.objects.link(o)
        me.materials.append(streak)
        o.visible_shadow = False


# ------------------------------------------------------------------ one shot
def build(shot, P_):
    st = P_["stage"]
    mood = P_["moods"][shot["mood"]]
    s = bpy.context.scene
    world(s, mood)
    live, fx = set(shot["live"]), set(shot["fx"])
    lit = "windowsOut" not in fx
    town(st, lit, shot["id"])
    tower(st, lit)
    g = st["globe"]
    gc = g["centre"]
    globe = place("Intro_SnowGlobe", (gc[0], st["deckY"], gc[2]), 0)
    for o in globe:   # Roblox Glass catches the sky: a brighter, less transparent glass than kit_preview's
        if o.name.startswith("Intro_SnowGlobe_Glass"):
            gm = MR.mat("#C9D6FF", 0.05, emit=0.25, alpha=0.32, key="globeglass")
            o.data.materials.clear()
            o.data.materials.append(gm)
    for o in globe:
        if o.name.startswith("Intro_SnowGlobe_Presents"):
            p = o.matrix_world.translation.copy()
            f = shot["globeFill"]
            o.matrix_world = Matrix.Translation(p) @ Matrix.Scale(f, 4, (0, 0, 1)) @ Matrix.Translation(-p) @ o.matrix_world
    MR.light("POINT", tuple(rb(gc[0], gc[1] - 4, gc[2])), None, "#FFD9B0", 9000 if shot["globeFill"] > 0.5 else 3000,
             size=6, shadow=False)
    vac = st["vacuum"]
    vobjs = place("Intro_Vacuum", tuple(vac["at"]), 180)
    on = "vacuum" in fx
    set_neon(vobjs, "Intro_Vacuum_Lights", WARM if on else H["steel_lo"], 5.0 if on else 0.2)
    if on:
        suction(st)
    lv = st["lever"]
    lobjs = place("Intro_Lever", tuple(lv["at"]), lv["yaw"])
    pulled = shot["lever"] in ("pull", "point") or shot["t"] > 10.2
    for o in lobjs:
        if o.name.startswith("Intro_Lever_Handle") and pulled:
            p = o.matrix_world.translation.copy()
            axis = (Matrix.Rotation(math.radians(lv["yaw"]), 4, "Z") @ Vector((1, 0, 0, 0))).to_3d()
            o.matrix_world = Matrix.Translation(p) @ Matrix.Rotation(math.radians(-70), 4, axis) @ \
                Matrix.Translation(-p) @ o.matrix_world
    glint = None
    if "hoardsworth" in live:
        hw = st["hoardsworth"]
        glint = hoardsworth(hw["at"], hw["yaw"], shot["hoardsworth"], P_["rig"])
    for pr in shot["presents"]:
        o = place("Intro_Present_" + "ABC"[pr["variant"] - 1], tuple(pr["pos"]), math.degrees(pr["spin"]))
        for x in o:
            x.matrix_world = Matrix.Translation(x.matrix_world.translation) @ Matrix.Rotation(pr["spin"] * 0.7, 4, "X") @ \
                Matrix.Scale(1.6, 4) @ Matrix.Translation(-x.matrix_world.translation) @ x.matrix_world
    if "garage" in live or shot["id"] in ("one", "more", "title"):
        garage(st, "headlights" in fx)
    if shot["letter"]["visible"] and "letter" in live:
        lo = place("Intro_Letter", tuple(shot["letter"]["pos"]), 200)
        for x in lo:
            p = x.matrix_world.translation.copy()
            x.matrix_world = Matrix.Translation(p) @ Matrix.Scale(P_["letterScale"], 4) @ Matrix.Translation(-p) @ \
                x.matrix_world
        for x in lo:
            x.matrix_world = Matrix.Translation(x.matrix_world.translation) @ \
                Matrix.Rotation(shot["letter"]["tilt"] + 0.5, 4, "Y") @ Matrix.Translation(-x.matrix_world.translation) \
                @ x.matrix_world
    if shot["id"] in ("one", "more", "title"):
        rk = st["rookie"]["at"]
        grin = shot["t"] >= 29.0
        rookie(rk, st["rookie"]["yaw"], shot["rookie"], face="smug" if grin else "idle")
        for k, c in enumerate(st["clones"]):
            if shot["clones"][k] > 0.5:
                rookie(c, st["rookie"]["yaw"] + (8 if c[0] < 130 else -8), shot["rookie"],
                       clone=MR.hsv_shift(MR.CLONE["P1"], 0.12 * k, 6 * k), dim=0.12 * k)
    if "aurora" in fx:
        aurora(3)
    if "snow" in fx:
        cp = shot["cam"]["pos"]
        lk = shot["cam"]["look"]
        d = Vector(lk) - Vector(cp)
        d.normalize()
        c = Vector(cp) + d * 30
        snowfall((c.x, c.y, c.z), (40, 22, 40), n=700, cam=tuple(cp))
    # lights per mood
    MR.light("SUN", (0, 0, 100), tuple(rb(-60, -100, 80)), "#9AA6FF", 1.6 * mood["brightness"], shadow=True)
    if shot["mood"] == "tower":
        hw = st["hoardsworth"]["at"]
        MR.light("SPOT", tuple(rb(hw[0] + 2, hw[1] - 2, hw[2] + 9)), tuple(rb(hw[0], hw[1] + 6, hw[2])), "#FF9C6A",
                 2600, size=1.5, spot=40)
        MR.light("SPOT", tuple(rb(hw[0] + 5, hw[1] + 9, hw[2] + 7)), tuple(rb(hw[0], hw[1] + 7, hw[2])), "#FFE2C0",
                 1500, size=2.0, spot=30)   # the face key
        MR.light("SPOT", tuple(rb(hw[0] - 6, hw[1] + 12, hw[2] - 10)), tuple(rb(hw[0], hw[1] + 5, hw[2])), "#9C8CFF",
                 4000, size=1.0, spot=30)
    cam_p = rbv(shot["cam"]["pos"])
    cam_t = rbv(shot["cam"]["look"])
    return cam_p, cam_t, shot["cam"]["fov"], glint


def finish(raw, out, shot, glint_px):
    """Bloom + grade (MR.finish), then the game's 2D layer: letterbox, caption card or the wordmark, SKIP, glint."""
    from PIL import Image, ImageDraw, ImageFilter
    img = MR.finish(raw, out, [], None, vignette=0.24, tag=False, truecolor=True).convert("RGBA")
    W, Hh = img.size
    d = ImageDraw.Draw(img)
    if glint_px:
        x, y = glint_px
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        for rr, a in ((Hh * 0.06, 90), (Hh * 0.035, 200), (Hh * 0.016, 255)):
            w = rr * 0.12
            dl.polygon([(x, y - rr), (x + w, y - w), (x + rr, y), (x + w, y + w), (x, y + rr), (x - w, y + w),
                        (x - rr, y), (x - w, y - w)], fill=(255, 250, 235, a))
        img = Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(1.2)))
        d = ImageDraw.Draw(img)
    bar = int(Hh * 0.11)
    if not shot["wordmark"]:
        d.rectangle([0, 0, W, bar], fill=(12, 13, 26, 255))
        d.rectangle([0, Hh - bar, W, Hh], fill=(12, 13, 26, 255))
    cap = shot.get("caption")
    if cap and not shot["wordmark"]:
        img = MR.draw_text(img, {"lines": [[(cap, P.HEX["exit"])]], "cap": 0.066, "y": 0.83, "align": "c", "x": 0.5})
    elif shot["wordmark"]:
        dark = Image.new("RGBA", img.size, (14, 15, 30, 150))
        img = Image.alpha_composite(img, dark)
        hues = ["#3DE8FF", "#FF4FD8", "#6A5CFF"]
        for k in (3, 2, 1):
            off = 0.011 * k
            img = MR.draw_text(img, {"lines": [[("HEIST YOURSELF", hues[k - 1])]], "cap": 0.13, "y": 0.52 + off * 0.75,
                                     "x": 0.5 + off, "align": "c"})
        img = MR.draw_text(img, {"lines": [[("HEIST YOURSELF", P.HEX["exit"])]], "cap": 0.13, "y": 0.52, "x": 0.5,
                                 "align": "c"})
        f, _ = MR._font(int(Hh * 0.04))
        ImageDraw.Draw(img).text((W / 2, Hh * 0.63), "Rob With Your Clones", font=f, fill=(169, 178, 204, 255),
                                 anchor="mm")
    # SKIP, top right (visible from the first frame in the game)
    d = ImageDraw.Draw(img)
    f, _ = MR._font(int(Hh * 0.026))
    bw, bh = Hh * 0.13, Hh * 0.05
    x1, y0 = W - Hh * 0.03, (bar - bh) / 2 if not shot["wordmark"] else Hh * 0.03
    d.rounded_rectangle([x1 - bw, y0, x1, y0 + bh], radius=bh / 2, fill=(28, 31, 59, 220), outline=(77, 71, 120, 255),
                        width=2)
    d.text((x1 - bw / 2, y0 + bh / 2), "SKIP", font=f, fill=(244, 247, 255, 255), anchor="mm")
    f2, _ = MR._font(max(12, int(Hh * 0.016)))
    d.text((W - Hh * 0.02, Hh - Hh * 0.015), "KEY FRAME RENDER, NOT A CAPTURE", font=f2, fill=(244, 247, 255, 90),
           anchor="rd")
    img = img.convert("RGB")
    img.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(out, optimize=True)


def render_one(n, scale, samples):
    from bpy_extras.object_utils import world_to_camera_view
    P_ = plan()
    shot = P_["shots"][n - 1]
    W, Hh = int(1920 * scale), int(1080 * scale)
    s = MR.reset(samples)
    cam_p, cam_t, fov, glint = build(shot, P_)
    cam = MR.camera(s, tuple(cam_p), tuple(cam_t), fov, W, Hh)
    cam.data.clip_end = 2000
    s.eevee.use_shadows = True
    gp = None
    if glint is not None and shot["id"] == "hoard":
        bpy.context.view_layer.update()
        v = world_to_camera_view(s, cam, glint)
        if v.z > 0:
            gp = (v.x * W, (1 - v.y) * Hh)
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, f".shot_{n}_raw.png")
    s.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    out = os.path.join(OUT, f"shot_{n}.png")
    finish(tmp, out, shot, gp)
    os.remove(tmp)
    print("intro:", out)


def sheet(n):
    from PIL import Image, ImageDraw
    tiles = [Image.open(os.path.join(OUT, f"shot_{i}.png")).convert("RGB") for i in range(1, n + 1)
             if os.path.isfile(os.path.join(OUT, f"shot_{i}.png"))]
    if not tiles:
        return
    tw, th = 640, 360
    cols = 2
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * tw + 30, rows * (th + 26) + 10), (20, 21, 34))
    d = ImageDraw.Draw(out)
    for i, im in enumerate(tiles):
        x, y = 10 + (i % cols) * (tw + 10), 10 + (i // cols) * (th + 26)
        out.paste(im.resize((tw, th)), (x, y + 18))
        d.text((x, y), f"shot {i + 1}", fill=(230, 232, 245))
    out.save(os.path.join(OUT, "contact_sheet.png"), optimize=True)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", type=int)
    ap.add_argument("--scale", type=float, default=2 / 3)
    ap.add_argument("--samples", type=int, default=24)
    a = ap.parse_args(argv)
    if a.only:
        render_one(a.only, a.scale, a.samples)
        return
    n = len(plan()["shots"])
    for i in range(1, n + 1):
        subprocess.run([sys.executable, os.path.abspath(__file__), "--only", str(i), "--scale", str(a.scale),
                        "--samples", str(a.samples)], check=True)
    sheet(n)


if __name__ == "__main__":
    main(sys.argv[1:])
