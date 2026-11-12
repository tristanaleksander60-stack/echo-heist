"""Level readability shots: each launch level rebuilt in Blender the way the server builds it, then rendered from the
player's point of view (docs/audit/LEVELS.md, the level readability and visual quality audit).

    python3 tools/blender/level_shots.py [--only L1|..|L6|DV01..DV12] [--daily] [--plain] [--size 1280]
                                         [--samples 32] [--no-sheet]

What is rebuilt, and from where (nothing is hand-placed):
  * `lune run tools/blender/level_plan.luau` compiles every level with Sim/LevelSpec and runs the server's own pure
    Heist/KitPlan on Kit/KitData, so every kit piece gets the pivot, yaw and per-axis scale KitDresser gives it
    (dressing = the Christmas layer the launch runs with; Clone Party becomes the Toy Shop, as in LevelBuilder).
  * Kit pieces come from assets/fbx exactly as exported, with the location atlas swap (kit_preview.style).
    Roblox (x, y, z) is Blender (-x, z, y) (STYLE_BIBLE 5.2 "Axes"); a Roblox yaw is the same angle about Blender +Z.
    Every placed piece is checked against KitPlan.partFrame's centre and size (printed as the max error).
  * The greybox the kit does not replace stays as LevelBuilder draws it: the plum floor under the whole lot, solids
    the plan does not cover, the floor cables (Vault Steel shade, 0.3 x 0.06), the door lamps (0.8 ball, red shut /
    green open), the loot display stands, the laser beams (red body + white core, one row per 2 studs), the van zone
    and its three WedgePart "chevrons".
  * Client-drawn state, as WorldView / GusView / EchoView draw it: idle plate rings in Vault Steel shade (plastic);
    a held plate's ring and cable in the presser's hue (Neon); open doors slid up by height - 0.4 (the vault door
    swings its skin -175 deg about the hinge); lasers off when their plate is held; Gus (kit rig, Santa hat with the
    dressing) at Sim/Guards.patrol(t = 0) with his Torch Amber floor cone (Transparency 0.75, Neon edge) clipped by a
    12-ray fan against sight solids and shut doors; clones as the stripped clone stand-in (marketing_renders.figure)
    in Clone Cyan with the solo age ramp (12 % dimmer and up to 25 deg toward violet per older run) and a glyph badge.
  * The player: the Rookie stand-in at spawn 1. Clones stand where the placeholder golden solution
    (tests/sim/Solutions.luau) leaves them: on the plates, or (Clone Party) at their shelf items.
  * Heist Night approximation in Eevee: world = OutdoorAmbient (75,80,130) (the levels have no roofs), one dim moon
    tinted by ColorShift_Top, ExposureCompensation 0.2, NO local lights (the game places none: no Lamp_Ceiling, no
    PointLight), then Bloom (threshold 1.0) and ColorCorrection in 2D (marketing_renders.finish).
What is NOT reproduced: Roblox's exact moon direction, ambient occlusion and tone mapping; Highlight outlines are a
solidify shell; the HUD. The Roblox default camera (no zoom is set in src/client: 12.5 studs, FOV 70) with Poppercam
approximated by a ray test against the greybox colliders. These are audit renders, not captures.

Writes docs/audit/levels/<L>_<id>_{1_spawn,1b_spawn_clones,2_objective,3_plan,4_thumb}.png and contact_sheet.png.
"""
import argparse, json, math, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402
import kit_preview as K  # noqa: E402
import marketing_renders as MR  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "audit", "levels")
TMP = os.path.join(tempfile.gettempdir(), "eh_level_shots")
FBX = os.path.join(REPO, "assets", "fbx")

# Heist/Palette (LevelBuilder greybox colours)
PAL = {"ink": "#1C1F3B", "plumDeep": "#2E2A50", "plum": "#3A3560", "plumHi": "#4D4778", "marble": "#D8C8A8",
       "steelLo": "#4E5675", "steel": "#7C86A6", "white": "#FFFFFF", "alarm": "#FF3838", "amber": "#FFD27A",
       "exit": "#F4F7FF", "ok": "#2FBF71", "gold": "#FFC21F"}
CYAN = "#3DE8FF"
VISION = (30.0, 45.0)        # Config.Sim GUARD_VISION_RANGE, GUARD_VISION_HALF_ANGLE
EYE = 1.5                    # Config.Sim GUARD_EYE_HEIGHT above the root
DEFAULT_ZOOM, FOV = 12.5, 70.0   # Roblox default camera (src/client sets no zoom; MASTERPLAN 3.5 wants 16)
BADGE_MAX = 40.0             # glyph badge hidden beyond 40 studs (MASTERPLAN 6.5 #5)

# Where the placeholder golden solutions (tests/sim/Solutions.luau) leave each clone: oldest first.
SOLUTION = {
    "cs1_back_room": {"plates": ["A"]},
    "cs2_two_doors": {"plates": ["A", "B"]},
    "cs3_lights_out": {"plates": ["A", "B"]},
    "cs4_night_clerk": {"plates": ["A", "B"]},
    "cs5_clone_party": {"loot": ["Shelf1W3", "Shelf3E3", "Shelf1E3", "Shelf3W3", "Shelf2W3", "Shelf2E3", "Shelf1W1"]},
    "bk1_big_score": {"plates": ["A", "B", "C", "D"]},
}


def short(level):
    n = level["num"]
    if 100 < n < 200:
        return "L%d" % (n - 100)
    return level["id"][:4].upper()


def rb(x, y, z):
    """Roblox level space -> Blender."""
    return Vector((-x, z, y))


def centre2(b):
    return (b[0] + b[3]) / 2, (b[2] + b[5]) / 2


# ------------------------------------------------------------------ the plan (Lune)
def load_plan(dressing, daily):
    os.makedirs(TMP, exist_ok=True)
    path = os.path.join(TMP, f"plan_{int(dressing)}_{int(daily)}.json")
    args = ["lune", "run", os.path.join("tools", "blender", "level_plan.luau"), "xmas" if dressing else "plain"]
    if daily:
        args.append("daily")
    with open(path, "w") as f:
        subprocess.run(args, cwd=REPO, check=True, stdout=f)
    return json.load(open(path))


# ------------------------------------------------------------------ kit library: one FBX import per model
class Lib:
    def __init__(self, loc):
        self.loc = loc
        self.parts = {}
        self.models = set()
        self.coll = bpy.data.collections.new("lib")
        bpy.context.scene.collection.children.link(self.coll)
        bpy.context.view_layer.layer_collection.children["lib"].exclude = True

    def get(self, model, name):
        if name not in self.parts and model not in self.models:
            self.models.add(model)
            before = set(bpy.data.objects)
            bpy.ops.import_scene.fbx(filepath=os.path.join(FBX, model + ".fbx"))
            for o in set(bpy.data.objects) - before:
                if o.type != "MESH":
                    continue
                base = o.name.split(".")[0]
                mw = o.matrix_world.copy()
                o.parent = None
                o.matrix_world = mw
                for c in list(o.users_collection):
                    c.objects.unlink(o)
                self.coll.objects.link(o)
                K.style(o, self.loc)
                self.parts[base] = o
        return self.parts.get(name)


ERR = [0.0]


def put(lib, piece, pivot, scale, extra=None):
    """A kit piece at KitPlan's pivot (x, y, z, yaw) and per-axis scale; `extra` is a Blender matrix applied after."""
    src = lib.get(piece["model"], piece["name"])
    if src is None:
        print("missing piece", piece["name"])
        return None
    o = src.copy()
    bpy.context.scene.collection.objects.link(o)
    px, py, pz, yaw = pivot
    sx, sy, sz = scale
    M = Matrix.Translation(rb(px, py, pz)) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Diagonal((sx, sz, sy, 1))
    o.matrix_world = (extra or Matrix.Identity(4)) @ M @ src.matrix_world
    if extra is None:   # check against KitPlan.partFrame (Roblox axes)
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        c = (lo + hi) / 2
        cr = (-c.x, c.z, c.y)
        ERR[0] = max(ERR[0], *(abs(cr[i] - piece["c"][i]) for i in range(3)))
    return o


def tint(o, hexc, emit=0.0, rough=0.6):
    m = MR.mat(hexc, rough, emit=emit)
    o.data = o.data.copy()
    o.data.materials.clear()
    o.data.materials.append(m)
    o.color = m.diffuse_color


# ------------------------------------------------------------------ greybox helpers (Roblox boxes)
def gbox(name, b, hexc, emit=0.0, alpha=1.0, shadow=True):
    lo, hi = rb(b[3], b[1], b[2]), rb(b[0], b[4], b[5])   # -x flips min/max on X
    size = (abs(hi.x - lo.x), abs(hi.y - lo.y), abs(hi.z - lo.z))
    o = MR.box(name, size, MR.mat(hexc, 0.6, emit=emit, alpha=alpha), None, tuple((lo + hi) / 2), bevel=0)
    o.visible_shadow = shadow
    return o


def state_for(level, solved):
    """Plates held, doors open, lasers off for the cold open (run 1) or the solved state (clones on their spots)."""
    sol = SOLUTION.get(level["id"], {}) if solved else {}
    held = {i + 1 for i, p in enumerate(level["plates"]) if p["id"] in sol.get("plates", [])}
    doors = {}
    for i, d in enumerate(level["doors"], 1):
        if d["alarmLock"] and not d["openBy"]:
            doors[i] = True                 # front doors / shutter stand open until the alarm
        elif d["openBy"]:
            hit = [p in held for p in d["openBy"]]
            doors[i] = all(hit) if d["need"] == "all" else any(hit)
        else:
            doors[i] = False
    lasers = {i: not any(p in held for p in l["offBy"]) for i, l in enumerate(level["lasers"], 1)}
    return held, doors, lasers


def build(level, solved, lib):
    held, doors, lasers = state_for(level, solved)
    loc = level["location"]
    fy = level["floorY"]
    b = level["bounds"]
    # Floor: the whole lot in Plum Slate deep (LevelBuilder), 2 thick under y = 0
    gbox("Floor", [b[0], fy - 2, b[2], b[3], fy, b[5]], PAL["plumDeep"])
    covered = set(level["covered"])
    for i, s in enumerate(level["solids"], 1):
        if i not in covered:
            gbox(f"Solid{i}", s["box"], PAL["plum"] if s["sight"] else PAL["marble"])

    till_loot = {it.get("index") for it in level["kit"] if it["role"] == "till"}
    for it in level["kit"]:
        role, idx = it["role"], it.get("index")
        extra = None
        if role == "door" and doors.get(idx):
            d = level["doors"][idx - 1]["box"]
            extra = Matrix.Translation((0, 0, (d[4] - d[1]) - 0.4))   # WorldView: slides up height - 0.4
        if role == "vaultSkin" and doors.get(idx):
            spec = K.MANIFEST["VaultDoor_Door"]
            px, py, pz, yaw = it["pivot"]
            ox, oy, oz = (spec["origin"][k] * it["scale"][k] for k in range(3))
            c, s_ = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
            hx, hz = px + ox * c + oz * s_, pz - ox * s_ + oz * c
            h = rb(hx, py, hz)
            extra = Matrix.Translation(h) @ Matrix.Rotation(math.radians(-175), 4, "Z") @ Matrix.Translation(-h)
        for piece in it["pieces"]:
            o = put(lib, piece, it["pivot"], it["scale"], extra)
            if o is None:
                continue
            n = piece["name"]
            if n == "Plate_4x4_Ring":
                if idx in held:
                    tint(o, CYAN, emit=4.0)
                else:
                    tint(o, PAL["steelLo"], 0, 0.6)      # idle: SmoothPlastic, Vault Steel shade
            elif n == "LaserEmitter_Lens":
                tint(o, PAL["alarm"] if lasers.get(idx) else PAL["steelLo"], emit=4.0 if lasers.get(idx) else 0)
            elif n == "Switch_Wall_Lamp":
                tint(o, PAL["steelLo"])
            elif n == "VaultDoor_DialRing":
                tint(o, CYAN if doors.get(idx) else "#A8987A", emit=3.0)
    # cables
    for cb in level["cables"]:
        on = cb["plate"] in held
        for ax, az, bx, bz in cb["legs"]:
            L = math.hypot(bx - ax, bz - az)
            if L < 0.1:
                continue
            cx, cz = (ax + bx) / 2, (az + bz) / 2
            alongX = abs(bx - ax) > abs(bz - az)
            w = (L + 0.3, 0.3) if alongX else (0.3, L + 0.3)
            gbox("Cable", [cx - w[0] / 2, fy + 0.0, cz - w[1] / 2, cx + w[0] / 2, fy + 0.06, cz + w[1] / 2],
                 CYAN if on else PAL["steelLo"], emit=4.0 if on else 0.0, shadow=False)
    # door lamps (LevelBuilder: above the leaf, on its +Z face)
    for i, d in enumerate(level["doors"], 1):
        bx = d["box"]
        cx = (bx[0] + bx[3]) / 2
        o = MR.ball("Lamp", 0.4, MR.mat(PAL["ok"] if doors[i] else PAL["alarm"], 0.4, emit=5.0), None,
                    tuple(rb(cx, bx[4] + 0.8, bx[5] + 0.2)))
        o.visible_shadow = False
        vault = any(k["role"] == "vaultSkin" and k.get("index") == i for k in level["kit"])
        if not any(k["role"] == "door" and k.get("index") == i for k in level["kit"]) and not vault and not doors[i]:
            gbox("Door", bx, PAL["steel"])     # greybox leaf (no kit swap)
    # lasers: greybox beams (posts are the kit's)
    for i, l in enumerate(level["lasers"], 1):
        if not lasers[i]:
            continue
        bx = l["box"]
        cz = (bx[2] + bx[5]) / 2
        h = bx[4] - bx[1]
        rows = max(2, int(h // 2))
        for r in range(rows):
            y = bx[1] + (r + 0.5) * h / rows
            for t, col, em in ((0.25, PAL["alarm"], 5.0), (0.08, PAL["white"], 8.0)):
                gbox("Beam", [bx[0], y - t / 2, cz - t / 2, bx[3], y + t / 2, cz + t / 2], col, emit=em, shadow=False)
    # loot stands (dark display; the till's stand is removed)
    for i, it in enumerate(level["loot"], 1):
        if i in till_loot:
            continue
        hgt = max(it["y"] - fy - 1, 0.2)
        gbox("Stand", [it["x"] - 0.9, fy, it["z"] - 0.9, it["x"] + 0.9, fy + hgt, it["z"] + 0.9], PAL["ink"])
    # van zone + WedgePart chevrons (Getaway White Neon)
    v = level["van"]
    gbox("VanZone", [v[0], fy, v[2], v[3], fy + 0.1, v[5]], PAL["exit"], emit=0.6, alpha=0.4, shadow=False)
    vx = (v[0] + v[3]) / 2
    for k in range(3):
        z = v[2] + 1.5 + k * 2.2
        gbox("Chevron", [vx - 1.2, fy + 0.08, z - 0.6, vx + 1.2, fy + 0.16, z + 0.6], PAL["exit"], emit=2.0,
             shadow=False)
    return held, doors, lasers


# ------------------------------------------------------------------ actors
def gus_and_cone(level, doors, loc, dressing):
    out = []
    for g in level["guards"]:
        pos = rb(g["x"], level["floorY"], g["z"])
        by = MR.gus(tuple(pos), math.degrees(g["yaw"]), pose="patrol", santa=dressing, loc=loc)
        lens = by.get("Gus_FlashlightLens")
        if lens:
            tint(lens, PAL["amber"], emit=6.0)
        out.append(by)
        cone(level, doors, g)
    return out


def blocked(level, doors, x, z, y):
    for s in level["solids"]:
        b = s["box"]
        if s["sight"] and b[0] < x < b[3] and b[2] < z < b[5] and b[1] <= y <= b[4]:
            return True
    for i, d in enumerate(level["doors"], 1):
        b = d["box"]
        if not doors[i] and b[0] < x < b[3] and b[2] < z < b[5]:
            return True
    return False


def cone(level, doors, g):
    rng, half = VISION[0], math.radians(VISION[1])
    gx, gz, yaw = g["x"], g["z"], g["yaw"]
    eye = level["floorY"] + 3 + EYE
    pts = []
    n = 12
    for k in range(n + 1):
        a = yaw - half + 2 * half * k / n
        fx, fz = -math.sin(a), -math.cos(a)
        d = 0.0
        while d < rng:
            d += 0.25
            if blocked(level, doors, gx + fx * d, gz + fz * d, eye):
                break
        pts.append((gx + fx * d, gz + fz * d))
    y = level["floorY"] + 0.07
    bm = bmesh.new()
    c = bm.verts.new(rb(gx, y, gz))
    vs = [bm.verts.new(rb(px, y, pz)) for px, pz in pts]
    for k in range(n):
        bm.faces.new((c, vs[k], vs[k + 1]))
    MR._obj("cone", bm, MR.mat(PAL["amber"], 0.9, emit=0.6, alpha=0.25)).visible_shadow = False
    for px, pz in (pts[0], pts[-1]):
        a, bb = rb(gx, y + 0.02, gz), rb(px, y + 0.02, pz)
        L = (bb - a).length
        ang = math.atan2((bb - a).y, (bb - a).x)
        MR.box("cone_edge", (L, 0.12, 0.04), MR.mat(PAL["amber"], 0.5, emit=3.0), None, tuple((a + bb) / 2),
               (0, 0, math.degrees(ang)), bevel=0).visible_shadow = False


def clones(level):
    sol = SOLUTION.get(level["id"], {})
    spots = []
    for pid in sol.get("plates", []):
        p = next(p for p in level["plates"] if p["id"] == pid)
        x, z = centre2(p["box"])
        i = level["plates"].index(p) + 1
        tx, tz = x, z + 6
        for d in level["doors"]:
            if i in d["openBy"]:
                tx, tz = centre2(d["box"])
                break
        for l in level["lasers"]:
            if i in l["offBy"]:
                tx, tz = centre2(l["box"])
        spots.append((x, z, tx, tz))
    for lid in sol.get("loot", []):
        it = next(it for it in level["loot"] if it["id"] == lid)
        lane = -12.5 if it["x"] < -9 else -4 if it["x"] < -1 else 4 if it["x"] < 7 else 12.5
        spots.append((lane, it["z"], it["x"], it["z"]))
    figs = []
    n = len(spots)
    for k, (x, z, tx, tz) in enumerate(spots):
        age = n - 1 - k                                   # 0 = newest
        pos = rb(x, level["floorY"], z)
        yaw = MR.yaw_to((pos.x, pos.y), tuple(rb(tx, 0, tz))[:2])
        J = MR.figure(f"clone{k + 1}", tuple(pos), yaw, clone=CYAN, dim=min(0.12 * age, 0.6),
                      hue=25.0 * age / max(n - 1, 1) if n > 1 else 0.0)
        figs.append((J, k + 1, MR.hsv_shift(CYAN, min(0.12 * age, 0.6), 25.0 * age / max(n - 1, 1) if n > 1 else 0)))
    return figs


def player(level):
    sp = level["spawns"][0]
    pos = rb(sp["x"], level["floorY"], sp["z"])
    return MR.figure("player", tuple(pos), math.degrees(sp["yaw"]), colors=MR.ROOKIE)


def move(J, level, x, z, yaw):
    J["root"].location = rb(x, level["floorY"], z)
    J["root"].rotation_euler = (0, 0, yaw)


# ------------------------------------------------------------------ light + camera
def lighting(s):
    w = s.world
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = MR.lin("#4B5082")       # OutdoorAmbient (75,80,130): no roofs
    bg.inputs["Strength"].default_value = 1.0
    # What the camera sees past the lot: the night sky through the Atmosphere haze (Color (70,60,120), Decay
    # (35,30,75)), darker than the ambient light it gives.
    nt = w.node_tree
    sky = nt.nodes.new("ShaderNodeBackground")
    sky.inputs["Color"].default_value = MR.lin("#231F45")
    path = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    outn = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
    nt.links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(bg.outputs[0], mix.inputs[1])
    nt.links.new(sky.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], outn.inputs["Surface"])
    ld = bpy.data.lights.new("moon", "SUN")
    ld.color = MR.lin("#FFE3C4")[:3]                            # moonlight warmed by ColorShift_Top (255,210,160)
    ld.energy = 0.9
    ld.angle = math.radians(3)
    o = bpy.data.objects.new("moon", ld)
    s.collection.objects.link(o)
    o.rotation_euler = (math.radians(38), 0, math.radians(-35))


def boxes_for_popper(level, doors):
    out = [s["box"] for s in level["solids"]]
    for i, d in enumerate(level["doors"], 1):
        if not doors[i]:
            out.append(d["box"])
    v = level["van"]                     # the invisible greybox van body (LevelBuilder): the collider
    out.append([v[0] - 0.5, 0.5, v[5] + 0.5, v[3] + 0.5, 7.5, v[5] + 8.5])
    return out


def ray_box(o, d, b):
    tmin, tmax = 0.0, 1.0
    for k, (lo, hi) in enumerate(((b[0], b[3]), (b[1], b[4]), (b[2], b[5]))):
        if abs(d[k]) < 1e-9:
            if o[k] < lo or o[k] > hi:
                return None
        else:
            t1, t2 = (lo - o[k]) / d[k], (hi - o[k]) / d[k]
            t1, t2 = min(t1, t2), max(t1, t2)
            tmin, tmax = max(tmin, t1), min(tmax, t2)
            if tmin > tmax:
                return None
    return tmin


def tp_camera(level, doors, px, pz, yaw, zoom=DEFAULT_ZOOM, pitch=15.0):
    """Roblox Custom camera behind the player: focus at the head, `zoom` back, `pitch` down; Poppercam pulls it in
    in front of the first collider on the way (0.5 stud margin). Returns Blender (pos, target, zoom used)."""
    fy = level["floorY"]
    focus = (px, fy + 4.5, pz)
    fx, fz = -math.sin(yaw), -math.cos(yaw)
    p = math.radians(pitch)
    back = (-fx * math.cos(p), math.sin(p), -fz * math.cos(p))
    d = tuple(back[k] * zoom for k in range(3))
    t = 1.0
    for b in boxes_for_popper(level, doors):
        hit = ray_box(focus, d, b)
        if hit is not None and hit > 1e-3:
            t = min(t, hit)
    used = max(0.5, zoom * t - 0.5) if t < 1.0 else zoom
    cam = tuple(focus[k] + back[k] * used for k in range(3))
    return rb(*cam), rb(*focus), used


def goal_of(level):
    tops = [it for it in level["loot"] if it["top"]]
    return tops[0] if tops else max(level["loot"], key=lambda it: it["value"])


def plan_camera(level):
    b = level["bounds"]
    x0, x1, z0, z1 = b[0], b[3], b[2], b[5]
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    tv = math.tan(math.radians(15))
    need = max((z1 - z0) / 2 / tv, (x1 - x0) / 2 / tv / (16 / 9)) * 1.04
    return rb(cx, need, cz), rb(cx, 0, cz)


def render(s, cam, path):
    s.camera = cam
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


def notes_for(s, cam, figs, gus_list):
    bpy.context.view_layer.update()
    W, Hh = s.render.resolution_x, s.render.resolution_y
    out = []
    cpos = cam.matrix_world.translation
    for J, k, hue in figs:
        top = MR.head_top(J, 0.6)
        if (top - cpos).length > BADGE_MAX:
            continue
        v = world_to_camera_view(s, cam, top)
        out.append({"kind": "badge", "x": v.x * W, "y": (1 - v.y) * Hh, "depth": v.z, "glyph": "●%d" % k, "hue": hue,
                    "h": 0.03})
    return out


def plan_ticks(img_path, s, cam, level):
    """Margin ticks (Roblox x along the bottom, z along the left) so fixes can name positions."""
    from PIL import Image, ImageDraw
    im = Image.open(img_path).convert("RGB")
    d = ImageDraw.Draw(im)
    f, _ = MR._font(14)
    W, Hh = im.size
    b = level["bounds"]
    bpy.context.view_layer.update()
    for x in range(int(math.ceil(b[0] / 8)) * 8, int(b[3]) + 1, 8):
        v = world_to_camera_view(s, cam, rb(x, 0, b[5]))
        px = v.x * W
        d.line([(px, Hh - 10), (px, Hh)], fill=(230, 232, 245), width=2)
        d.text((px + 3, Hh - 26), "x%d" % x, font=f, fill=(230, 232, 245))
    for z in range(int(math.ceil(b[2] / 8)) * 8, int(b[5]) + 1, 8):
        v = world_to_camera_view(s, cam, rb(b[0], 0, z))
        py = (1 - v.y) * Hh
        d.line([(0, py), (10, py)], fill=(230, 232, 245), width=2)
        d.text((12, py - 8), "z%d" % z, font=f, fill=(230, 232, 245))
    im.save(img_path, optimize=True)


# ------------------------------------------------------------------ one level
def shoot(level, W, Hh, samples):
    tag = short(level)
    stem = f"{tag}_{level['id']}"
    loc, dressing = level["location"], level["dressing"]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    made = {}
    for solved in (False, True):
        s = MR.reset(samples)
        s.view_settings.exposure = 0.2
        lib = Lib(loc)
        ERR[0] = 0.0
        held, doors, lasers = build(level, solved, lib)
        print(f"{stem} solved={solved}: kit placement max error vs KitPlan.partFrame {ERR[0]:.4f} studs")
        gl = gus_and_cone(level, doors, loc, dressing)
        figs = clones(level) if solved else []
        me = player(level)
        lighting(s)
        cd = bpy.data.cameras.new("cam")
        cam = bpy.data.objects.new("cam", cd)
        s.collection.objects.link(cam)
        cd.sensor_fit = "VERTICAL"
        cd.clip_start = 0.1
        cd.clip_end = 1000
        s.render.resolution_x, s.render.resolution_y = W, Hh
        s.render.resolution_percentage = 100
        sp = level["spawns"][0]
        shots = []
        # 1 / 1b: third-person at spawn
        pos, tgt, used = tp_camera(level, doors, sp["x"], sp["z"], sp["yaw"])
        shots.append(("1b_spawn_clones" if solved else "1_spawn", pos, tgt, FOV, used, (sp["x"], sp["z"], sp["yaw"])))
        if solved:
            # 2: from just inside the entrance, turned toward the goal loot
            g = goal_of(level)
            ex, ez = 0.0, 5.0
            yaw = math.atan2(-(g["x"] - ex), -(g["z"] - ez))
            pos, tgt, used = tp_camera(level, doors, ex, ez, yaw, zoom=DEFAULT_ZOOM, pitch=20.0)
            shots.append(("2_objective", pos, tgt, FOV, used, (ex, ez, yaw)))
            # 3: top-down plan (B3: FOV 30)
            pos, tgt = plan_camera(level)
            shots.append(("3_plan", pos, tgt, 30.0, None, (sp["x"], sp["z"], sp["yaw"])))
        for name, pos, tgt, fov, used, stand in shots:
            move(me, level, *stand)
            cam.location = pos
            if name == "3_plan":
                cam.rotation_euler = (0, 0, math.pi)
            else:
                cam.rotation_euler = (tgt - pos).to_track_quat("-Z", "Y").to_euler()
            cd.angle_y = math.radians(fov)
            raw = os.path.join(TMP, f"{stem}_{name}_raw.png")
            render(s, cam, raw)
            notes = notes_for(s, cam, figs, gl) if name != "3_plan" else []
            out = os.path.join(OUT, f"{stem}_{name}.png")
            MR.finish(raw, out, notes, tag=False, vignette=0.12)
            if name == "3_plan":
                plan_ticks(out, s, cam, level)
            made[name] = (out, used)
            print("wrote", out, "" if used is None else f"(camera distance {used:.1f} studs)")
    # 4: thumbnail-size view 1
    from PIL import Image
    im = Image.open(made["1_spawn"][0]).convert("RGB")
    th = os.path.join(OUT, f"{stem}_4_thumb.png")
    im.resize((160, 90), Image.LANCZOS).save(th, optimize=True)
    big = im.resize((160, 90), Image.LANCZOS).resize((480, 270), Image.NEAREST)
    big.save(os.path.join(TMP, f"{stem}_4_thumb_x3.png"))
    json.dump({k: {"path": os.path.relpath(v[0], REPO), "camera": v[1]} for k, v in made.items()},
              open(os.path.join(TMP, f"{stem}_meta.json"), "w"), indent=1)
    return made


def contact_sheet(levels):
    from PIL import Image, ImageDraw
    cols = ("1_spawn", "1b_spawn_clones", "2_objective", "3_plan", "4_thumb")
    tw, th = 384, 216
    rows = []
    for lv in levels:
        stem = f"{short(lv)}_{lv['id']}"
        if os.path.isfile(os.path.join(OUT, f"{stem}_1_spawn.png")):
            rows.append((stem, lv["name"]))
    sheet = Image.new("RGB", (tw * len(cols), (th + 24) * len(rows) + 30), (24, 25, 36))
    d = ImageDraw.Draw(sheet)
    f, _ = MR._font(15)
    d.text((8, 7), "Heist Yourself level audit: spawn (run 1) | spawn with the solution's clones | toward the goal | "
           "plan | 160x90 thumbnail (x2.4 nearest)", font=f, fill=(230, 232, 245))
    for r, (stem, name) in enumerate(rows):
        y = 30 + r * (th + 24)
        d.text((8, y + 3), f"{stem}  {name}", font=f, fill=(230, 232, 245))
        for c, col in enumerate(cols):
            p = os.path.join(OUT, f"{stem}_{col}.png")
            if not os.path.isfile(p):
                continue
            im = Image.open(p).convert("RGB")
            im = im.resize((tw, th), Image.NEAREST if col == "4_thumb" else Image.LANCZOS)
            sheet.paste(im, (c * tw, y + 24))
    out = os.path.join(OUT, "contact_sheet.png")
    sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(out, optimize=True)
    print("wrote", out)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--daily", action="store_true", help="also the 12 daily vaults")
    ap.add_argument("--plain", action="store_true", help="Christmas dressing layer off")
    ap.add_argument("--size", type=int, default=1280)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--no-sheet", action="store_true")
    a = ap.parse_args(argv)
    plan = load_plan(not a.plain, a.daily)
    levels = plan["levels"]
    W, Hh = a.size, a.size * 9 // 16
    if a.only:
        lv = next(lv for lv in levels if short(lv).upper() == a.only.upper() or lv["id"] == a.only)
        shoot(lv, W, Hh, a.samples)
        return
    for lv in levels:   # one Blender process per level (factory resets + Eevee renders in one process are flaky)
        cmd = [sys.executable, os.path.abspath(__file__), "--only", lv["id"], "--size", str(a.size),
               "--samples", str(a.samples)] + (["--daily"] if a.daily else []) + (["--plain"] if a.plain else [])
        subprocess.run(cmd, check=True)
    if not a.no_sheet:
        contact_sheet(levels)


if __name__ == "__main__":
    main(sys.argv[1:])
