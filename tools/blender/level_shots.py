"""Level readability shots: each launch level rebuilt in Blender the way the server builds it, then rendered from the
player's point of view (docs/audit/LEVELS.md, the level readability and visual quality audit).

    python3 tools/blender/level_shots.py [--only L1|..|L6|DV01..DV12] [--daily] [--plain] [--size 1280]
                                         [--samples 32] [--no-sheet] [--out docs/audit/levels/after]

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
  * Recipe A "Moonlit Diorama" approximation in Eevee (default.project.json, roblox_quality 1.2): world =
    OutdoorAmbient (115,110,165) (the levels have no roofs), a moon key at about 50 deg tinted by ColorShift_Top
    (150,175,255), ExposureCompensation 0.3; the night sky colour behind; every lamp of KitPlan.lamps as a real light
    (PointLight / the hero SpotLight with shadows, Config.Lighting) with its unlit floor pool and the kit Lamp_Ceiling;
    then Bloom and ColorCorrection in 2D (marketing_renders.finish).
  * Light-and-levels P0 state (LEVELS.md 4): idle plates glow Bulb Warm with their letter, letter discs on the
    devices, KitPlan.cables (0.5 wide Vault Steel, near jamb), open doors pocketed (hidden) and shutters rolled up,
    the van zone dim with arrows, the goal sparkle (2D, like finish's "sparkle" note), goal displays and L1's
    windows from Heist/LevelDress.
What is NOT reproduced: Roblox's exact moon direction, ambient occlusion and tone mapping; Highlight outlines are a
solidify shell; the HUD. The Roblox default camera (no zoom is set in src/client: 12.5 studs, FOV 70) with Poppercam
approximated by a ray test against the greybox colliders. These are audit renders, not captures.

Writes docs/audit/levels/<L>_<id>_{1_spawn,1b_spawn_clones,1c_spawn_fp,2_objective,3_plan,3b_plan_solved,4_thumb,5_street}.png
(1, 3 and 5: run 1, nothing held; 1b, 2 and 3b: the solution's clones on their spots, their plates held) and
contact_sheet.png. --shots 5_street renders only the named shots; --sheet-only rebuilds the contact sheet.
--golden renders the GOLDEN_FRAMES G1 / G2 approximations with the W4 backdrop (tools/blender/backdrop_shots.py) into
docs/audit/levels/golden/.
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
OUT = os.path.join(REPO, "docs", "audit", "levels")   # --out changes it (after-renders: docs/audit/levels/after)
TMP = os.path.join(tempfile.gettempdir(), "eh_level_shots")
FBX = os.path.join(REPO, "assets", "fbx")

# Heist/Palette (LevelBuilder greybox colours)
PAL = {"ink": "#1C1F3B", "plumDeep": "#2E2A50", "plum": "#3A3560", "plumHi": "#4D4778", "marble": "#D8C8A8",
       "steelLo": "#4E5675", "steel": "#7C86A6", "white": "#FFFFFF", "alarm": "#FF3838", "amber": "#FFD27A",
       "exit": "#F4F7FF", "ok": "#2FBF71", "gold": "#FFC21F", "floor": "#3A365C", "bulb": "#F6C0A2"}
CYAN = "#3DE8FF"
VISION = (30.0, 45.0)        # Config.Sim GUARD_VISION_RANGE, GUARD_VISION_HALF_ANGLE
EYE = 1.5                    # Config.Sim GUARD_EYE_HEIGHT above the root
DEFAULT_ZOOM, FOV = 12.5, 70.0   # Roblox default camera (src/client sets no zoom; MASTERPLAN 3.5 wants 16)
BADGE_MAX = 40.0             # glyph badge hidden beyond 40 studs (MASTERPLAN 6.5 #5)
FP_EYE = 3.8                 # first person: the Rookie's eyes above the floor (CameraDirector "fp", FpMath.eye)

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
    path = os.path.join(TMP, f"plan_{int(dressing)}_{int(daily)}_{os.getpid()}.json")
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


HELD = None   # golden(): a plate-id list held for one frame (L6's vault row at "VAULT 2/4")


def state_for(level, solved):
    """Plates held, doors open, lasers off for the cold open (run 1) or the solved state (clones on their spots)."""
    sol = SOLUTION.get(level["id"], {}) if solved else {}
    ids = HELD if HELD is not None else sol.get("plates", [])
    held = {i + 1 for i, p in enumerate(level["plates"]) if p["id"] in ids}
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
    # Floor: the whole lot in the lit `floor` swatch (LevelBuilder, W3), 2 thick under y = 0
    gbox("Floor", [b[0], fy - 2, b[2], b[3], fy, b[5]], PAL["floor"])
    covered = set(level["covered"])
    for i, s in enumerate(level["solids"], 1):
        if i not in covered:
            gbox(f"Solid{i}", s["box"], PAL["plum"] if s["sight"] else PAL["marble"])

    till_loot = {it.get("index") for it in level["kit"] if it["role"] in ("till", "display")}
    for it in level["kit"]:
        role, idx = it["role"], it.get("index")
        extra = None
        if role == "door" and doors.get(idx):
            d = level["doors"][idx - 1]["box"]
            if it["pieces"][0]["name"] == "Shutter_8x10":    # WorldView: rolled up into the header, top pinned
                top = d[4]
                k = 0.35 / 10.35
                extra = Matrix.Translation((0, 0, top)) @ Matrix.Diagonal((1, 1, k, 1)) @ Matrix.Translation((0, 0, -top))
            else:
                continue                                       # WorldView: pocketed into the wall, hidden
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
                    tint(o, CYAN, emit=2.5)
                else:
                    o.data = o.data.copy()                # idle: Neon Bulb Warm at 50 % (LEVELS P0-1)
                    o.data.materials.clear()
                    o.data.materials.append(MR.mat(PAL["bulb"], 0.4, emit=2.0, alpha=0.5))
            elif n == "LaserEmitter_Lens":
                tint(o, PAL["alarm"] if lasers.get(idx) else PAL["steelLo"], emit=2.2 if lasers.get(idx) else 0)
            elif n == "Switch_Wall_Lamp":
                tint(o, PAL["steelLo"])
            elif n == "VaultDoor_DialRing":
                tint(o, CYAN if doors.get(idx) else "#A8987A", emit=3.0)
            elif n == "Van_Paint":                       # KitDresser: Config.Lighting.VAN.paint (a mid value)
                tint(o, "#%02X%02X%02X" % tuple(level["lighting"]["VAN"]["paint"]), rough=0.5)
    # cables (KitPlan.cables: near jamb, 0.5 wide, idle Vault Steel)
    cw = level["lighting"]["CABLE_WIDTH"]
    for cb in level["cables"]:
        on = cb["plate"] in held
        for ax, az, bx, bz in cb["legs"]:
            L = math.hypot(bx - ax, bz - az)
            if L < 0.1:
                continue
            cx, cz = (ax + bx) / 2, (az + bz) / 2
            alongX = abs(bx - ax) > abs(bz - az)
            w = (L + cw, cw) if alongX else (cw, L + cw)
            gbox("Cable", [cx - w[0] / 2, fy + 0.0, cz - w[1] / 2, cx + w[0] / 2, fy + 0.06, cz + w[1] / 2],
                 CYAN if on else PAL["steel"], emit=2.5 if on else 0.0, shadow=False)
    # plate letters (top face, white) and the letter discs on the devices they drive
    for i, p in enumerate(level["plates"], 1):
        x, z = centre2(p["box"])
        text3(p["letter"], 2.2, PAL["exit"], 1.5, rb(x, fy + 0.4, z), (0, 0, math.pi))
    row_doors = {r["door"] for r in (level.get("vaultRows") or [])}
    for i, d in enumerate(level["doors"], 1):
        if not d.get("letters") or i in row_doors:
            continue
        bx = d["box"]
        if (bx[3] - bx[0]) < (bx[5] - bx[2]):
            continue
        cx, cz = centre2(bx)
        plaque(d["letters"], rb(cx + 2, fy + 10.8, cz), (bx[5] - bx[2]) / 2 + 0.1)
    for i, l in enumerate(level["lasers"], 1):
        if not l.get("letters") or not l["offBy"]:
            continue
        bx = l["box"]
        px, _pz = centre2(level["plates"][l["offBy"][0] - 1]["box"])
        cx, cz = centre2(bx)
        plaque(l["letters"], rb(bx[0] if px < cx else bx[3], fy + 7, cz), 0.5)
    # need-all rows (LevelBuilder: a lettered Neon disc per plate on the door's face, dim Bulb Warm until held,
    # then the presser's hue) and the "VAULT n/4" count over them
    VR = level["lighting"]["VAULT_ROW"]
    for row in level.get("vaultRows") or []:
        n_held = 0
        for rl in row["lamps"]:
            on = rl["plate"] in held
            n_held += 1 if on else 0
            pos = rb(rl["x"], rl["y"], rl["z"])
            disc = MR.cyl("RowLamp", VR["size"] / 2, VR["size"] / 2, VR["depth"],
                          MR.mat(CYAN if on else PAL["bulb"], 0.4, emit=3.0 if on else 1.6,
                                 alpha=1.0 if on else 1 - VR["idleAlpha"]), None, tuple(pos), (90, 0, 0), seg=24)
            disc.visible_shadow = False
            side = 1 if row["nz"] >= 0 else -1
            text3(rl["letter"], VR["size"] * 0.8, PAL["ink"], 0.0, pos + Vector((0, side * (VR["depth"] / 2 + 0.02), 0)),
                  (math.pi / 2, 0, math.pi if side > 0 else 0))
        cx = sum(l["x"] for l in row["lamps"]) / len(row["lamps"])
        cz = sum(l["z"] for l in row["lamps"]) / len(row["lamps"])
        side = 1 if row["nz"] >= 0 else -1
        text3("VAULT %d/%d" % (n_held, len(row["lamps"])), 0.9, PAL["ok"] if n_held == len(row["lamps"]) else PAL["bulb"],
              1.2, rb(cx, row["lamps"][0]["y"] + VR["labelOffset"], cz + side * 0.2),
              (math.pi / 2, 0, math.pi if side > 0 else 0))
    # plates inside hides: their letter on a disc over the hide (LevelBuilder.plaque, read from both sides)
    for hp in level.get("hidePlates") or []:
        plaque(hp["letters"], rb(hp["x"], hp["top"] + level["lighting"]["HIDE_PLAQUE_Y"], hp["z"]), 0.1)
    # lamps: real lights (Config.Lighting) and the unlit floor pools
    for lp in level["lamps"]:
        lamp_light(level, lp)
    # door lamps (LevelBuilder: above the leaf, on its +Z face)
    for i, d in enumerate(level["doors"], 1):
        bx = d["box"]
        cx = (bx[0] + bx[3]) / 2
        o = MR.ball("Lamp", 0.4, MR.mat(PAL["ok"] if doors[i] else PAL["alarm"], 0.4, emit=1.6), None,
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
            ink = level["worldFx"]["LASER_INK"] if level.get("worldFx") else None
            if ink:   # the ink sleeve (LevelBuilder: Palette.ink, Transparency LASER_INK.alpha)
                t = ink["width"]
                gbox("BeamInk", [bx[0], y - t / 2, cz - t / 2, bx[3], y + t / 2, cz + t / 2], PAL["ink"],
                     alpha=1 - ink["alpha"], shadow=False)
            for t, col, em in ((0.25, PAL["alarm"], 2.2), (0.08, PAL["white"], 4.0)):
                gbox("Beam", [bx[0], y - t / 2, cz - t / 2, bx[3], y + t / 2, cz + t / 2], col, emit=em, shadow=False)
    # loot stands (dark display; the till's stand is removed)
    for i, it in enumerate(level["loot"], 1):
        if i in till_loot:
            continue
        hgt = max(it["y"] - fy - 1, 0.2)
        gbox("Stand", [it["x"] - 0.9, fy, it["z"] - 0.9, it["x"] + 0.9, fy + hgt, it["z"] + 0.9], PAL["ink"])
    # van zone: dim (nobody carries loot in these shots) with arrows toward the van (LevelBuilder.arrow)
    v = level["van"]
    LG = level["lighting"]
    gbox("VanZone", [v[0], fy, v[2], v[3], fy + 0.1, v[5]], PAL["exit"], alpha=1 - LG["VAN_IDLE_ALPHA"], shadow=False)
    vx = (v[0] + v[3]) / 2
    hw, hl = LG["ARROW_HEAD"]
    sw, sl = LG["ARROW_SHAFT"]
    n = LG["ARROW_COUNT"]
    z0 = v[2] + ((v[5] - v[2]) - ((n - 1) * LG["ARROW_STEP"] + sl + hl)) / 2
    am = MR.mat(PAL["exit"], 0.5, alpha=1 - LG["ARROW_IDLE_ALPHA"])
    for k in range(n):
        za = z0 + k * LG["ARROW_STEP"]
        gbox("ArrowShaft", [vx - sw / 2, fy + 0.08, za, vx + sw / 2, fy + 0.16, za + sl], PAL["exit"],
             alpha=1 - LG["ARROW_IDLE_ALPHA"], shadow=False)
        bm = bmesh.new()
        y = fy + 0.16
        vs = [bm.verts.new(rb(vx - hw / 2, y, za + sl)), bm.verts.new(rb(vx + hw / 2, y, za + sl)),
              bm.verts.new(rb(vx, y, za + sl + hl))]
        bm.faces.new(vs)
        MR._obj("ArrowHead", bm, am).visible_shadow = False
    return held, doors, lasers


def text3(s, size, hexc, emit, loc, rot):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = s
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = 0.01
    o = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(MR.mat(hexc, 0.5, emit=emit))
    o.location = loc
    o.rotation_euler = rot
    o.visible_shadow = False
    return o


def plaque(letters, c, half):
    """LevelBuilder.plaque: a steel disc with ink letters on both faces of a wall line (Roblox +-Z = Blender +-Y)."""
    w = 1.6 * max(1.0, 0.55 * len(letters) + 0.45)
    for side in (1, -1):
        loc = c + Vector((0, side * half, 0))
        disc = MR.cyl("plaque", 0.8, 0.8, 0.04, MR.mat(PAL["steel"], 0.5, emit=0.6), None, tuple(loc),
                      (90, 0, 0), seg=24, scale=(w / 1.6, 1, 1))
        disc.visible_shadow = False
        text3(letters, 1.1, PAL["ink"], 0.0, loc + Vector((0, side * 0.03, 0)),
              (math.pi / 2, 0, math.pi if side > 0 else 0))


LAMP_W = 520.0   # Eevee watts per unit of Roblox Brightness (calibrated by eye against the pools)
STEPPED = False  # --stepped: draw the pools as the old hard discs (for the before / after comparison)
_SOFT = {}


def soft_pool_mat(hexc, peak, exponent, radius, emit):
    """The soft pool (Config.Lighting.POOL_SOFT, assets/ui/EH_FX_Pool.png): alpha = peak * (1 - u^2)^exponent with
    u = r / radius, on one disc (object space, so it follows the disc's own radius)."""
    key = (hexc, round(peak, 4), exponent, round(radius, 3), emit)
    if key in _SOFT:
        try:
            _SOFT[key].name          # a scene reset (MR.reset) removes the materials
            return _SOFT[key]
        except ReferenceError:
            _SOFT.clear()
    m = bpy.data.materials.new("SoftPool_%d" % len(_SOFT))
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = MR.lin(hexc)
    b.inputs["Roughness"].default_value = 0.9
    b.inputs["Emission Color"].default_value = MR.lin(hexc)
    b.inputs["Emission Strength"].default_value = emit
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    nt.links.new(tc.outputs["Object"], ln.inputs[0])

    def math_node(op, a=None, bval=None, clamp=False):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        if bval is not None:
            n.inputs[1].default_value = bval
        if a is not None:
            nt.links.new(a, n.inputs[0])
        return n

    u = math_node("DIVIDE", ln.outputs["Value"], radius)
    u2 = math_node("MULTIPLY", u.outputs[0], None)
    nt.links.new(u.outputs[0], u2.inputs[1])
    one_minus = math_node("SUBTRACT", None, None, clamp=True)
    one_minus.inputs[0].default_value = 1.0
    nt.links.new(u2.outputs[0], one_minus.inputs[1])
    pw = math_node("POWER", one_minus.outputs[0], exponent)
    a = math_node("MULTIPLY", pw.outputs[0], peak)
    nt.links.new(a.outputs[0], b.inputs["Alpha"])
    m.surface_render_method = "BLENDED"
    m.diffuse_color = MR.lin(hexc)
    _SOFT[key] = m
    return m


def lamp_light(level, lp):
    """A KitPlan lamp: the Light (Config.Lighting; only the hero shadows) and its unlit SurfaceGui pool."""
    fy = level["floorY"]
    LG = level["lighting"]
    col = "#%02X%02X%02X" % tuple(lp["color"])
    pos = rb(lp["x"], fy + lp.get("lightY", LG["LIGHT_Y"]), lp["z"])
    if lp["kind"] == "hero":
        o = MR.light("SPOT", tuple(pos), tuple(rb(lp["x"], fy, lp["z"])), col, lp["brightness"] * LAMP_W,
                     size=0.3, spot=lp["angle"] * 1.6, blend=0.7, shadow=lp["shadows"])
    else:
        o = MR.light("POINT", tuple(pos), None, col, lp["brightness"] * LAMP_W, size=0.3, shadow=lp["shadows"])
    o.data.use_custom_distance = True
    o.data.cutoff_distance = lp["range"]
    P = LG["POOL"]
    if not lp.get("pool"):
        return
    pc = "#%02X%02X%02X" % tuple(lp.get("poolColor") or P["color"])
    if not STEPPED and lp.get("peak"):
        # the engine's soft pool: the radial gradient image (one ImageLabel), ImageTransparency = 1 - peak
        r = lp["pool"] / 2
        soft = LG["POOL_SOFT"]
        m = soft_pool_mat(pc, lp["peak"], soft["exponent"], r, P["brightness"] * 0.6)
        rc = lp.get("rect")
        if rc:   # KitPlan.poolRect: the pool part stops at the walls it would cross; the disc stays on the lamp
            bm = bmesh.new()
            x0, x1, z0, z1 = rc[0] - lp["x"], rc[1] - lp["x"], rc[2] - lp["z"], rc[3] - lp["z"]
            vs = [bm.verts.new((-x, z, 0.0)) for x, z in ((x0, z0), (x1, z0), (x1, z1), (x0, z1))]
            bm.faces.new(vs)
            d = MR._obj("pool", bm, m)
            d.location = tuple(rb(lp["x"], fy + P["lift"], lp["z"]))
        else:
            d = MR.cyl("pool", r, r, 0.01, m, None, tuple(rb(lp["x"], fy + P["lift"], lp["z"])), seg=64)
        d.visible_shadow = False
        return
    for k, rg in enumerate(lp.get("rings") or P["rings"]):
        r = lp["pool"] * rg["size"] / 2
        d = MR.cyl("pool", r, r, 0.01, MR.mat(pc, 0.9, emit=P["brightness"] * 0.6, alpha=1 - rg["alpha"]), None,
                   tuple(rb(lp["x"], fy + P["lift"] + 0.005 * k, lp["z"])), seg=40)
        d.visible_shadow = False


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
def _hex01(c):
    return "#%02X%02X%02X" % tuple(round(v * 255) for v in c[:3])


def lighting(s):
    """Recipe A from default.project.json: OutdoorAmbient as the world light (the levels have no roofs), the
    ClockTime 15 sun as moonlight (ColorShift_Top, Brightness), ExposureCompensation."""
    import backdrop_shots as BS
    LT = BS.LIGHTING
    s.view_settings.exposure = LT["ExposureCompensation"]
    w = s.world
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = MR.lin(_hex01(LT["OutdoorAmbient"]))
    bg.inputs["Strength"].default_value = 1.0
    # What the camera sees past the lot: the plain night sky (assets/sky, horizon in the Atmosphere colour
    # (90,80,150)), darker than the ambient light it gives.
    nt = w.node_tree
    sky = nt.nodes.new("ShaderNodeBackground")
    sky.inputs["Color"].default_value = MR.lin("#3A3470")
    path = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    outn = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
    nt.links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(bg.outputs[0], mix.inputs[1])
    nt.links.new(sky.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], outn.inputs["Surface"])
    ld = bpy.data.lights.new("moon", "SUN")
    ld.color = MR.lin("#B4C6FF")[:3]                            # the ClockTime 15 sun as moonlight: ColorShift_Top
    ld.energy = 2.4 * LT["Brightness"] / 1.4                    # 2.4 calibrated at Brightness 1.4 (was 0.5 at 0.9)
    ld.angle = math.radians(6)                                  # ShadowSoftness 0.3
    o = bpy.data.objects.new("moon", ld)
    s.collection.objects.link(o)
    o.rotation_euler = (math.radians(42), 0, math.radians(-35))   # about 48 deg up, to one side of the spawn view


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


def fp_camera(level, px, pz, yaw):
    """First person (CameraDirector "fp") at a spawn: the Rookie's eyes (FP_EYE), looking along `yaw` at the run
    start's pitch (Config.Heist.CAMERA.FP.START_PITCH). Returns Blender (pos, target)."""
    fy = level["floorY"]
    p = math.radians(level["camera"]["FP"]["START_PITCH"])
    eye = (px, fy + FP_EYE, pz)
    look = (px - math.sin(yaw) * math.cos(p) * 10, fy + FP_EYE - math.sin(p) * 10, pz - math.cos(yaw) * math.cos(p) * 10)
    return rb(*eye), rb(*look)


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


def notes_for(s, cam, figs, gus_list, level=None):
    bpy.context.view_layer.update()
    W, Hh = s.render.resolution_x, s.render.resolution_y
    out = []
    cpos = cam.matrix_world.translation
    dg = bpy.context.evaluated_depsgraph_get()
    # WorldView goal sparkle (LEVELS P0-4): the goal and items worth >= SPARKLE_MIN_VALUE, at home, unoccluded
    if level is not None:
        lo = level["lighting"]["SPARKLE_MIN_VALUE"]
        for it in level["loot"]:
            if not (it["top"] or it["value"] >= lo):
                continue
            p = rb(it["x"], level["floorY"] + it["y"] + 1.2, it["z"])
            d = p - cpos
            hit, _l, _n, _i, obj, _m = s.ray_cast(dg, cpos, d.normalized(), distance=max(d.length - 1.5, 0.1))
            if hit:
                continue
            v = world_to_camera_view(s, cam, p)
            if 0 <= v.x <= 1 and 0 <= v.y <= 1 and v.z > 0:
                out.append({"kind": "sparkle", "x": v.x * W, "y": (1 - v.y) * Hh, "depth": v.z,
                            "r": max(0.008, min(0.03, 0.3 / v.z)), "small": [(0.02, 0.015, 0.45), (-0.015, -0.02, 0.35)]})
    for J, k, hue in figs:
        top = MR.head_top(J, 0.6)
        if (top - cpos).length > BADGE_MAX:
            continue
        # BillboardGui with AlwaysOnTop false (EchoView): hidden when a wall is in front of the head
        head = J["head"].matrix_world.translation
        d = head - cpos
        hit, _loc, _n, _i, obj, _m = s.ray_cast(dg, cpos, d.normalized(), distance=d.length - 0.8)
        if hit and obj not in J["parts"]:
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
def shoot(level, W, Hh, samples, only=None):
    tag = short(level)
    stem = f"{tag}_{level['id']}"
    loc, dressing = level["location"], level["dressing"]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    made = {}
    for solved in (False, True):
        s = MR.reset(samples)
        s.view_settings.exposure = 0.3                           # recipe A ExposureCompensation
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
            pos, tgt = plan_camera(level)
            shots.append(("3b_plan_solved", pos, tgt, 30.0, None, (sp["x"], sp["z"], sp["yaw"])))
        else:
            # 1c: first person at spawn 1 (the default camera): the Rookie's eyes, the run-start pitch, your body hidden
            pos, tgt = fp_camera(level, sp["x"], sp["z"], sp["yaw"])
            shots.append(("1c_spawn_fp", pos, tgt, level["camera"]["FP"]["FOV"], None, (sp["x"], 900.0, sp["yaw"])))
            # 3: top-down plan (B3: FOV 30), run 1 (nothing held, lasers on); 3b: with the solution's clones
            pos, tgt = plan_camera(level)
            shots.append(("3_plan", pos, tgt, 30.0, None, (sp["x"], sp["z"], sp["yaw"])))
            # 5: the building from the street (silhouette, landmark, what the facade says), off the van's axis
            shots.append(("5_street", rb(18, 10, 46), rb(0, 6, 2), 50.0, None, (sp["x"], sp["z"], sp["yaw"])))
        if only:
            shots = [sh for sh in shots if sh[0] in only]
        for name, pos, tgt, fov, used, stand in shots:
            move(me, level, *stand)
            # plan views look down through the ceiling fixtures (a planning camera fades them, P2-4)
            for ob in bpy.data.objects:
                if ob.name.startswith("Lamp_Ceiling"):
                    ob.hide_render = name.startswith("3")
            cam.location = pos
            if name.startswith("3"):
                cam.rotation_euler = (0, 0, math.pi)
            else:
                cam.rotation_euler = (tgt - pos).to_track_quat("-Z", "Y").to_euler()
            cd.angle_y = math.radians(fov)
            raw = os.path.join(TMP, f"{stem}_{name}_raw.png")
            render(s, cam, raw)
            notes = notes_for(s, cam, figs, gl, level if not solved else None) if not name.startswith("3") else []
            out = os.path.join(OUT, f"{stem}_{name}.png")
            MR.finish(raw, out, notes, tag=False, vignette=0.12, truecolor=True)   # 256 colours lose the small lamps
            if name.startswith("3"):
                plan_ticks(out, s, cam, level)
            made[name] = (out, used)
            print("wrote", out, "" if used is None else f"(camera distance {used:.1f} studs)")
    # 4: thumbnail-size view 1
    from PIL import Image
    if "1_spawn" not in made:
        return made
    im = Image.open(made["1_spawn"][0]).convert("RGB")
    th = os.path.join(OUT, f"{stem}_4_thumb.png")
    im.resize((160, 90), Image.LANCZOS).save(th, optimize=True)
    big = im.resize((160, 90), Image.LANCZOS).resize((480, 270), Image.NEAREST)
    big.save(os.path.join(TMP, f"{stem}_4_thumb_x3.png"))
    json.dump({k: {"path": os.path.relpath(v[0], REPO), "camera": v[1]} for k, v in made.items()},
              open(os.path.join(TMP, f"{stem}_meta.json"), "w"), indent=1)
    return made


GOLDEN = os.path.join(REPO, "docs", "audit", "levels", "golden")


def golden(level, W, Hh, samples, out_dir=None):
    """docs/GOLDEN_FRAMES.md approximations with the W4 backdrop, the Heist City sky, snow and haze
    (tools/blender/backdrop_shots.py). L1 -> G1a (diorama: pitch 50, distance 28, FOV 42) and G1b (classic follow:
    16 studs, FOV 70, Poppercam); L5 -> G2 (the 8 OF ME wide shot: 7 clones + you bunched at the entrance, pitch
    about 45, every clone inside the central 32 % of the width)."""
    import backdrop_shots as BS
    import frame_grade as FG
    from PIL import Image, ImageDraw
    global HELD
    # L6's frames show the scale held: all four plates, "VAULT 4/4", the vault door open on the lit gold (the other
    # levels: run 1, nothing held)
    HELD = ["A", "B", "C", "D"] if level["id"] == "bk1_big_score" else None
    gdir = out_dir or GOLDEN
    os.makedirs(gdir, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    loc, dressing = level["location"], level["dressing"]
    lib = Lib(loc)
    held, doors, lasers = build(level, False, lib)
    gl = gus_and_cone(level, doors, loc, dressing)
    BS.backdrop(level, lib, put, soft_pool_mat)
    lighting(s)
    BS.world_sky(s, TMP)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    cd.sensor_fit = "VERTICAL"
    cd.clip_start = 0.1
    cd.clip_end = 5000
    s.render.resolution_x, s.render.resolution_y = W, Hh
    s.render.resolution_percentage = 100
    fy = level["floorY"]
    sp = level["spawns"][0]
    shots = []
    figs = []
    stamp = None
    if level["id"] == "cs5_clone_party":
        # 8 OF ME: the tape-print fan-out at the run start, the crew bunched in the shop's front area (between the
        # front wall and the shelf ends, clear of the counter), facing the camera; you in front
        spots = [(-4.0, -5.0), (0.0, -5.0), (4.0, -5.0), (-6.0, -2.0), (-2.0, -2.0), (2.0, -2.0), (6.0, -2.0)]
        n = len(spots)
        for k, (x, z) in enumerate(spots):
            age = n - 1 - k
            J = MR.figure(f"clone{k + 1}", tuple(rb(x, fy, z)), 180.0, clone=CYAN, dim=min(0.12 * age, 0.6),
                          hue=25.0 * age / (n - 1))
            figs.append((J, k + 1, MR.hsv_shift(CYAN, min(0.12 * age, 0.6), 25.0 * age / (n - 1))))
        MR.figure("player", tuple(rb(0.0, fy, 1.5)), 180.0, colors=MR.ROOKIE)
        # pitch 55, not the spec's "about 45": at 45 the 12-stud front wall hides the crew's legs unless they stand
        # among the shelves (the pull-back camera itself is the camera track's, C0)
        focus = (0.0, fy + 3.0, 2.0)
        p = math.radians(55)
        cpos = (focus[0], focus[1] + 40 * math.sin(p), focus[2] + 40 * math.cos(p))
        shots.append(("G2_party_wide", rb(*cpos), rb(*focus), 50.0, None))
        stamp = "8 OF ME"
    else:
        J = player(level)
        move(J, level, sp["x"], sp["z"], sp["yaw"])
        focus = (sp["x"], fy + 4.5, sp["z"])
        # the game's diorama camera (Config.Heist.CAMERA.DIORAMA, Heist/CameraDirector + CameraMath): the focus
        # leads you by CameraMath.lead so you sit in the lower third, then the orbit at PITCH / DISTANCE / FOV
        D = level["camera"]["DIORAMA"]
        p = math.radians(D["PITCH"])
        t = -D["SUBJECT_SCREEN_Y"] * math.tan(math.radians(D["FOV"]) / 2)
        lead = t * D["DISTANCE"] / (math.sin(p) + t * math.cos(p))
        yaw = sp["yaw"]
        ahead = (focus[0] - math.sin(yaw) * lead, focus[1], focus[2] - math.cos(yaw) * lead)
        dio = (ahead[0] + math.sin(yaw) * math.cos(p) * D["DISTANCE"], ahead[1] + math.sin(p) * D["DISTANCE"],
               ahead[2] + math.cos(yaw) * math.cos(p) * D["DISTANCE"])
        # L1 is GOLDEN_FRAMES G1; the warm pass's other levels get the same two frames under their own names
        pre = {"cs1_back_room": "G1"}.get(level["id"], short(level) + "_")
        shots.append((pre + "a_diorama" if pre == "G1" else pre + "diorama", rb(*dio), rb(*ahead), float(D["FOV"]),
                      focus))
        # classic follow: 16 studs back at 15 degrees (GOLDEN_FRAMES G1b; no Poppercam pull-in: the camera track
        # moves the van collider out of the way, C0)
        # 30 degrees right of the spawn's axis so the van sits at frame left instead of under the lens
        p, yo = math.radians(15), math.radians(30)
        cls = (focus[0] + 16 * math.cos(p) * math.sin(yo), focus[1] + 16 * math.sin(p),
               focus[2] + 16 * math.cos(p) * math.cos(yo))
        if level["id"] in ("cs1_back_room", "bk1_big_score"):
            shots.append((pre + "b_classic" if pre == "G1" else pre + "classic", rb(*cls), rb(*focus), 70.0, focus))
        if level["id"] == "cs3_lights_out":
            # L3's own room (L1-L4 share the street front): plate B under its lamp, its cable to the grid's east
            # post, the three-layer grid, the register on its till behind it (a diorama-height view)
            shots.append(("L3_grid", rb(-2.0, fy + 26.0, -16.0), rb(5.0, fy, -30.0), 55.0, None))
        if level["id"] == "cs4_night_clerk":
            # L4's back room: Gus on his patrol, the coat rack with plate B's letter over it, the rug at his post
            shots.append(("L4_backroom", rb(6.0, fy + 26.0, -18.0), rb(-3.0, fy, -29.0), 55.0, None))
        if level["id"] == "bk1_big_score":
            # the vault from over the scale room's arch (a diorama-height view: from eye height in the classic
            # camera the scale-room lamp hangs in front of the row's middle): the A-D lamp row over the open vault
            # door at "VAULT 4/4", the lit gold and the warm accents behind it, the scale-room rug
            vf = (0.0, fy + 6.0, -50.0)
            vc = (0.0, fy + 15.0, -33.0)
            shots.append(("L6_vault", rb(*vc), rb(*vf), 70.0, None))
    flakes = None
    for name, pos, tgt, fov, snow_at in shots:
        if flakes is not None:
            bpy.data.objects.remove(flakes, do_unlink=True)
            flakes = None
        if snow_at is not None:   # exterior view: the camera-following snow volume over the focus
            cp = (-pos.x, pos.z, pos.y)       # the camera in Roblox axes
            flakes = BS.snowfall(snow_at, level["backdropConfig"], cp)
        cam.location = pos
        cam.rotation_euler = (tgt - pos).to_track_quat("-Z", "Y").to_euler()
        cd.angle_y = math.radians(fov)
        raw = os.path.join(TMP, f"golden_{name}_raw.png")
        render(s, cam, raw)
        depth = os.path.join(TMP, f"golden_{name}_depth.png")
        BS.depth_pass(s, cam, depth)
        hazed = os.path.join(TMP, f"golden_{name}_haze.png")
        BS.haze(raw, depth, hazed)
        notes = notes_for(s, cam, figs, gl, level)
        out = os.path.join(gdir, f"{name}.png")
        img = MR.finish(hazed, out, notes, tag=False, vignette=0.12, truecolor=True)
        if stamp:
            img = img.convert("RGBA")
            f, _ = MR._font(int(Hh * 0.1))
            d = ImageDraw.Draw(img)
            bpy.context.view_layer.update()
            heads = [(1 - world_to_camera_view(s, cam, MR.head_top(J, 0.6)).y) * Hh for J, _k, _h in figs]
            sy = (min(heads) if heads else Hh * 0.45) - Hh * 0.03     # above the crew, covering no face
            d.text((W / 2, sy), stamp, font=f, fill=(255, 230, 156, 255), anchor="mb",
                   stroke_width=max(3, int(Hh * 0.008)), stroke_fill=(28, 31, 59, 255))
            img.convert("RGB").save(out, optimize=True)
        small = Image.open(out).convert("RGB").resize((160, 90), Image.LANCZOS)
        small.save(os.path.join(gdir, f"{name}_160x90.png"))
        ids = os.path.join(TMP, f"golden_{name}_ids.png")
        id_mask(s, cam, ids)
        record_grade(gdir, FG.grade(out, ids))
        print("wrote", os.path.relpath(out, REPO))


def garage(g, W, Hh, samples, out_dir=None):
    """docs/GOLDEN_FRAMES.md G3: the garage v1 (server Heist/Lobby from Heist/LobbyPlan, dumped by level_plan.luau) with
    the kit in the Corner Shop atlas, each van's paint, the work lamps (your bay's shadowed key), the trophies, the job
    board's glowing NEXT card, the roll-up door half open onto the snowy street and the W4 backdrop round the garage
    site; the camera is Config.Heist.CAMERA.GOLDEN.G3 on the part named "Van" (bay 1's collider centre), as
    client Heist/GoldenShots places it. No falling snow: the camera focus is indoors (the client turns it off)."""
    import backdrop_shots as BS
    import frame_grade as FG
    from PIL import Image
    gdir = out_dir or GOLDEN
    os.makedirs(gdir, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    lib = Lib(g["location"])
    garage_scene(g, lib)
    BS.backdrop({"backdrop": g["backdrop"], "backdropConfig": g["backdropConfig"], "kit": [], "location": g["location"],
                 "lighting": g["lighting"]}, lib, put, soft_pool_mat)
    lighting(s)
    BS.world_sky(s, TMP)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    cd.sensor_fit = "VERTICAL"
    cd.clip_start = 0.1
    cd.clip_end = 5000
    s.render.resolution_x, s.render.resolution_y = W, Hh
    s.render.resolution_percentage = 100
    G3 = g["camera"]["GOLDEN"]["G3"]
    v = g["bays"][0]["collider"]
    focus = ((v[0] + v[3]) / 2, (v[1] + v[4]) / 2, (v[2] + v[5]) / 2)
    yw, p = math.radians(G3["YAW"]), math.radians(G3["PITCH"])
    look = (-math.sin(yw) * math.cos(p), -math.sin(p), -math.cos(yw) * math.cos(p))   # CameraMath.look
    pos = tuple(focus[k] - look[k] * G3["DISTANCE"] for k in range(3))
    cam.location = rb(*pos)
    cam.rotation_euler = (rb(*focus) - rb(*pos)).to_track_quat("-Z", "Y").to_euler()
    cd.angle_y = math.radians(G3["FOV"])
    name = "G3_garage"
    raw = os.path.join(TMP, f"golden_{name}_raw.png")
    render(s, cam, raw)
    depth = os.path.join(TMP, f"golden_{name}_depth.png")
    BS.depth_pass(s, cam, depth)
    hazed = os.path.join(TMP, f"golden_{name}_haze.png")
    BS.haze(raw, depth, hazed)
    out = os.path.join(gdir, f"{name}.png")
    MR.finish(hazed, out, [], tag=False, vignette=0.12, truecolor=True)
    Image.open(out).convert("RGB").resize((160, 90), Image.LANCZOS).save(os.path.join(gdir, f"{name}_160x90.png"))
    ids = os.path.join(TMP, f"golden_{name}_ids.png")
    id_mask(s, cam, ids)
    record_grade(gdir, FG.grade(out, ids))
    print("wrote", os.path.relpath(out, REPO))


def garage_scene(g, lib):
    """The garage v1 as server Heist/Lobby builds it (kit, van paints, bay lines and numbers, lamps, the NEXT card)."""
    LG = g["lighting"]
    gbox("Floor", g["floor"], PAL["floor"])
    groups = {}
    for it in g["kit"]:
        for piece in it["pieces"]:
            o = put(lib, piece, it["pivot"], it["scale"])
            if o is None:
                continue
            if piece["name"] in ("Van_Paint", "Facade_8x10_Body") and it.get("color"):
                tint(o, "#%02X%02X%02X" % tuple(it["color"]), rough=0.5)
            if it.get("group"):
                o.visible_shadow = False
                groups.setdefault(it["group"], []).append(o)
    # the warehouse's plain parts (LobbyPlan.warehouse): shell, roof, skylights, mezzanine, the stations' dressing
    for p in g.get("parts") or []:
        if (p.get("alpha") or 0) >= 1:
            continue   # invisible colliders
        s, c = p["size"], p["pos"]
        if abs((p.get("yaw") or 0) % 180 - 90) < 1e-6:
            s = (s[2], s[1], s[0])
        b = [c[0] - s[0] / 2, c[1] - s[1] / 2, c[2] - s[2] / 2, c[0] + s[0] / 2, c[1] + s[1] / 2, c[2] + s[2] / 2]
        mat = p.get("material")
        o = gbox("Ware" + p["name"], b, _hexc(p["color"]), emit=2.2 if mat == "Neon" else 0.0,
                 alpha=1 - (p.get("alpha") or 0), shadow=False)
        gui = p.get("gui")
        if gui:
            face = {"Front": (0, -1), "Back": (0, 1), "Left": (-1, 0), "Right": (1, 0)}[gui["face"]]
            yaw = math.radians(p.get("yaw") or 0)
            fx = face[0] * math.cos(yaw) + face[1] * math.sin(yaw)
            fz = -face[0] * math.sin(yaw) + face[1] * math.cos(yaw)
            half = (s[0] / 2 if abs(fx) > 0.5 else s[2] / 2) + 0.04
            ang = math.atan2(-fx, -fz)   # the text's Roblox facing (0 = toward -Z)
            size = min(s[1] * 0.45, (s[2] if abs(fx) > 0.5 else s[0]) / max(1, len(gui["text"])) * 1.6)
            t = text3(gui["text"], size, _hexc(gui["color"]), 2.2, rb(c[0] + fx * half, c[1], c[2] + fz * half),
                      (math.pi / 2, 0, ang))
            if p.get("group"):
                groups.setdefault(p["group"], []).append(t)
        if p.get("group"):
            groups.setdefault(p["group"], []).append(o)
    L = g["lobby"]
    for b in g["lines"]:
        gbox("BayLine", b, "#%02X%02X%02X" % tuple(L["BAY_LINE"]["color"]), shadow=False)
    for n in g["numbers"]:
        text3(n["text"], L["BAY_NUMBER"]["size"] * 0.8, "#%02X%02X%02X" % tuple(L["BAY_NUMBER"]["color"]), 0.0,
              rb(n["x"], 0.05, n["z"]), (0, 0, math.radians(n["yaw"]) + math.pi))
    rings = {"street": LG["LAMP"]["street"]["poolRings"]}
    for lp in g["lamps"]:
        d = dict(lp)
        d["kind"] = "hero" if lp.get("angle") else "room"
        d["lightY"] = lp["y"]
        d["rings"] = rings.get(lp["kind"], LG["LAMP"]["room"]["poolRings"])
        lamp_light({"floorY": 0, "lighting": LG}, d)
    # the NEXT card: a dark plate, the glowing words (SurfaceGui LightInfluence 0, Brightness 1.6)
    c = g["card"]
    B = L["BOARD"]
    yaw = math.radians(c["yaw"])
    cpos = rb(*c["centre"])
    MR.box("JobCard", (c["size"][0], B["cardDepth"], c["size"][1]), MR.mat("#%02X%02X%02X" % tuple(B["cardColor"]), 0.6),
           None, tuple(cpos), (0, 0, c["yaw"]), bevel=0)
    face = Vector((math.sin(yaw), -math.cos(yaw), 0)) * (B["cardDepth"] / 2 + 0.01)
    tc = "#%02X%02X%02X" % tuple(B["textColor"])
    for txt, dy, size in (("NEXT JOB", 0.42, 0.3), (g["firstJob"], -0.12, 0.5)):
        t = text3(txt, size, tc, 2.2, cpos + face + Vector((0, 0, dy)), (math.pi / 2, 0, yaw))
        t.name = "JobCardText"
        bpy.context.view_layer.update()
        wide = c["size"][0] * 0.88                       # TextScaled: the words fit the card
        if t.dimensions.x > wide:
            k = wide / t.dimensions.x
            t.scale = (k, k, k)
    return groups


# ------------------------------------------------------------------ WORLD 2.0: the full frame, both cameras
WORLD2 = os.path.join(REPO, "docs", "audit", "levels", "world2")
W2_SIZE = (1280, 592)   # 19.5:9, a phone's full frame (Roblox FOV is vertical: a wide frame sees the most backdrop)
W2_SITES = ("L1", "L2", "L3", "L4", "L5", "L6", "DV01", "DV10", "garage")
# Source mask (frame_grade.SRC_COLOURS): which layer of the world each pixel belongs to. Backdrop objects carry the
# custom property eh_src (tools/blender/backdrop_shots.py); clones are named clone*; the rest is the level.
SRC_HIDE = ("Snowfall", "pool", "WindowSpill", "cone", "TownPool")
SIGNALS = ("Plate_4x4_Ring", "LaserEmitter_Lens", "Beam", "RowLamp")   # the world signals (premium A1 pop)


def src_mask(s, cam, path):
    """A Workbench pass with every object in its source colour (sky transparent), for frame_grade's breakdown of
    where the dark pixels come from."""
    import frame_grade as FG
    keep = (s.render.engine, s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure)
    colours, hidden = {}, []
    for o in bpy.data.objects:
        if o.type not in ("MESH", "FONT", "CURVE"):
            continue
        colours[o.name] = tuple(o.color)
        if o.name.startswith(SRC_HIDE) and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
            continue
        src = o.get("eh_src")
        if src is None:
            p, src = o, ("signal" if o.name.startswith(SIGNALS) else "level")
            while p is not None:   # a figure's parts hang under empties named after it (clone1_root ...)
                if p.name.startswith("clone"):
                    src = "clone"
                    break
                p = p.parent
        o.color = (*(c / 255 for c in FG.SRC_COLOURS[src]), 1.0)
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
        if o.name in colours:
            o.color = colours[o.name]
    for o in hidden:
        o.hide_render = False
    s.render.engine, s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure = keep


def _w2_camera(s, W, Hh):
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    cd.sensor_fit = "VERTICAL"
    cd.clip_start = 0.1
    cd.clip_end = 5000
    s.render.resolution_x, s.render.resolution_y = W, Hh
    s.render.resolution_percentage = 100
    return cam


def _diorama(level_cam, x, y, z, yaw):
    """The game's diorama camera on a subject at (x, y, z) facing `yaw` (Config.Heist.CAMERA.DIORAMA, CameraMath):
    returns Roblox (camera, look-at)."""
    D = level_cam["DIORAMA"]
    p = math.radians(D["PITCH"])
    t = -D["SUBJECT_SCREEN_Y"] * math.tan(math.radians(D["FOV"]) / 2)
    lead = t * D["DISTANCE"] / (math.sin(p) + t * math.cos(p))
    ahead = (x - math.sin(yaw) * lead, y, z - math.cos(yaw) * lead)
    pos = (ahead[0] + math.sin(yaw) * math.cos(p) * D["DISTANCE"], ahead[1] + math.sin(p) * D["DISTANCE"],
           ahead[2] + math.cos(yaw) * math.cos(p) * D["DISTANCE"])
    return pos, ahead


def _classic(x, y, z, yaw, zoom, pitch):
    """The classic follow camera behind a subject facing `yaw` (no Poppercam: the camera track fades walls)."""
    p = math.radians(pitch)
    pos = (x + math.sin(yaw) * math.cos(p) * zoom, y + math.sin(p) * zoom, z + math.cos(yaw) * math.cos(p) * zoom)
    return pos, (x, y, z)


def _w2_shoot(s, cam, name, pos, tgt, fov, snow_at, cfg, gdir, figs=(), level=None, gl=()):
    import backdrop_shots as BS
    import frame_grade as FG
    only = os.environ.get("EH_W2_SHOTS")   # e.g. "diorama_mid,classic": render just these shots (experiments)
    if only and not any(name.endswith("_" + k) for k in only.split(",")):
        return
    flakes = None
    if snow_at is not None:
        flakes = BS.snowfall(snow_at, cfg, pos)
    bp, bt = rb(*pos), rb(*tgt)
    cam.location = bp
    cam.rotation_euler = (bt - bp).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle_y = math.radians(fov)
    raw = os.path.join(TMP, f"w2_{name}_raw.png")
    render(s, cam, raw)
    depth = os.path.join(TMP, f"w2_{name}_depth.png")
    BS.depth_pass(s, cam, depth)
    notes = notes_for(s, cam, list(figs), list(gl), level) if level is not None else []
    # the same frame under Blender's Standard view (no toe), graded for comparison only
    std = os.path.join(TMP, f"w2_{name}_std.png")
    BS.haze(raw, depth, std + ".haze.png")
    MR.finish(std + ".haze.png", std, notes, tag=False, vignette=0.12, truecolor=True)
    raw = BS.tonemap(raw, os.path.join(TMP, f"w2_{name}_tm.png"))
    hazed = os.path.join(TMP, f"w2_{name}_haze.png")
    BS.haze(raw, depth, hazed)
    out = os.path.join(gdir, f"{name}.png")
    MR.finish(hazed, out, notes, tag=False, vignette=0.12, truecolor=True)
    ids = os.path.join(TMP, f"w2_{name}_ids.png")
    id_mask(s, cam, ids)
    srcp = os.path.join(TMP, f"w2_{name}_src.png")
    src_mask(s, cam, srcp)
    if flakes is not None:
        bpy.data.objects.remove(flakes, do_unlink=True)
    g = FG.grade(out, ids, srcp)
    gs = FG.grade(std)
    g["standard_view"] = {k: gs[k] for k in ("near_black", "dark_share", "median_luma", "warm_share")}
    record_grade(gdir, g)
    print("wrote", os.path.relpath(out, REPO))


def world2_level(level, samples, out_dir):
    """WORLD 2.0 (LEVELS.md section 10): one site in both cameras at the full phone frame, graded for the share of
    near-black pixels and where they come from. Shots: diorama at the spawn (run 1), diorama mid-run (you in the
    building, the solution's clones on their plates), classic at the spawn toward the building, classic turned
    round in the street (across the street and the sky)."""
    import backdrop_shots as BS
    W, Hh = W2_SIZE
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    tag = short(level)
    fy = level["floorY"]
    sp = level["spawns"][0]
    cfg = level["backdropConfig"]
    CC = level["camera"]["CLASSIC"]
    DF = level["camera"]["DIORAMA"]["FOV"]
    only = os.environ.get("EH_W2_SHOTS")
    for solved in (False, True):
        if only:   # build only the scene the requested shots need (a second factory reset can crash Eevee)
            mine = ("diorama_mid", "diorama_crew") if solved else ("diorama", "classic", "classic_rev")
            if not any(k in mine for k in only.split(",")):
                continue
        s = MR.reset(samples)
        s.view_settings.exposure = 0.3
        lib = Lib(level["location"])
        held, doors, lasers = build(level, solved, lib)
        gl = gus_and_cone(level, doors, level["location"], level["dressing"])
        BS.backdrop(level, lib, put, soft_pool_mat)
        lighting(s)
        BS.world_sky(s, TMP)
        cam = _w2_camera(s, W, Hh)
        J = player(level)
        if not solved:
            at = (sp["x"], fy + 4.5, sp["z"])
            move(J, level, sp["x"], sp["z"], sp["yaw"])
            pos, tgt = _diorama(level["camera"], *at, sp["yaw"])
            _w2_shoot(s, cam, f"{tag}_diorama", pos, tgt, DF, at, cfg, out_dir, level=level, gl=gl)
            pos, tgt = _classic(*at, sp["yaw"], CC["ZOOM"], CC["PITCH"])
            _w2_shoot(s, cam, f"{tag}_classic", pos, tgt, CC["FOV"], at, cfg, out_dir, level=level, gl=gl)
            # turned round in the street beside the van: across the street, the sky over the far row
            rx, rz, ryaw = 12.0, level["bounds"][5] - 1.0, math.pi
            move(J, level, rx, rz, ryaw)
            at = (rx, fy + 4.5, rz)
            pos, tgt = _classic(*at, ryaw, CC["ZOOM"], CC["PITCH"])
            _w2_shoot(s, cam, f"{tag}_classic_rev", pos, tgt, CC["FOV"], at, cfg, out_dir, level=level, gl=gl)
        else:
            figs = clones(level)
            mz = max(level["bounds"][2] + 14.0, -24.0)
            move(J, level, 0.0, mz, 0.0)
            pos, tgt = _diorama(level["camera"], 0.0, fy + 4.5, mz, 0.0)
            _w2_shoot(s, cam, f"{tag}_diorama_mid", pos, tgt, DF, None, cfg, out_dir, figs=figs, level=level, gl=gl)
            # the signal check (premium A1): the diorama on the crew, the solution's clones on their held plates
            if figs:
                pts = [J["root"].matrix_world.translation for J, _k, _h in figs]
                cx = -sum(p.x for p in pts) / len(pts)      # Blender -> Roblox x
                cz = sum(p.y for p in pts) / len(pts)       # Blender y -> Roblox z
                move(J, level, cx + 2.0, cz + 6.0, 0.0)
                pos, tgt = _diorama(level["camera"], cx, fy + 4.5, cz + 6.0, 0.0)
                _w2_shoot(s, cam, f"{tag}_diorama_crew", pos, tgt, DF, None, cfg, out_dir, figs=figs, level=level,
                          gl=gl)


def world2_garage(g, samples, out_dir):
    import backdrop_shots as BS
    W, Hh = W2_SIZE
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    lib = Lib(g["location"])
    garage_scene(g, lib)
    BS.backdrop({"backdrop": g["backdrop"], "backdropConfig": g["backdropConfig"], "kit": [], "location": g["location"],
                 "lighting": g["lighting"]}, lib, put, soft_pool_mat)
    lighting(s)
    BS.world_sky(s, TMP)
    cam = _w2_camera(s, W, Hh)
    cfg = g["backdropConfig"]
    CC = g["camera"]["CLASSIC"]
    DF = g["camera"]["DIORAMA"]["FOV"]
    sx, sz = g["spawn"]
    J = MR.figure("player", tuple(rb(sx, 0, sz)), 180.0, colors=MR.ROOKIE)
    pos, tgt = _diorama(g["camera"], sx, 4.5, sz, 0.0)
    _w2_shoot(s, cam, "GA_diorama", pos, tgt, DF, None, cfg, out_dir)
    # at the half-open roll-up door in the back wall (-Z), looking out over the yard
    dz = -g["lobby"]["HALF_Z"] + 3.0
    J["root"].location = rb(0, 0, dz)
    pos, tgt = _diorama(g["camera"], 0.0, 4.5, dz, 0.0)
    _w2_shoot(s, cam, "GA_diorama_mid", pos, tgt, DF, None, cfg, out_dir)
    J["root"].location = rb(sx, 0, sz)
    pos, tgt = _classic(sx, 4.5, sz, 0.0, CC["ZOOM"], CC["PITCH"])
    _w2_shoot(s, cam, "GA_classic", pos, tgt, CC["FOV"], None, cfg, out_dir)
    # out in the yard, turned round toward the garage's back wall and its door
    yz = -g["lobby"]["HALF_Z"] - g["lobby"]["WALL_T"] - g["lobby"]["STREET_DEPTH"] * 0.55
    J["root"].location = rb(8.0, 0, yz)
    J["root"].rotation_euler = (0, 0, math.pi)
    pos, tgt = _classic(8.0, 4.5, yz, math.pi, CC["ZOOM"], CC["PITCH"])
    _w2_shoot(s, cam, "GA_classic_rev", pos, tgt, CC["FOV"], (8.0, 4.5, yz), cfg, out_dir)


# ------------------------------------------------------------------ BIG buildings (PLAN_FIRST_PERSON 5 "BIG")
BIG = os.path.join(REPO, "docs", "audit", "levels", "big")
BIG_SITES = ("L1", "L5", "L6", "DV10", "garage")
EYE_H = 3.8          # the Rookie's first-person eye over the floor (CameraDirector fp, Config.FirstPerson)
FP_FOV = 70.0


def _hexc(c):
    return "#%02X%02X%02X" % tuple(int(v) for v in c[:3])


def tower(t, lib):
    """Heist/TowerPlan as Heist/Overhead builds it: kit pieces (the facade bodies in their runtime colour), plain
    parts (Neon panes glow), sign text; CastShadow off like the game (the ground floor keeps its moonlight).
    Returns {group: [objects]} for the cut-away."""
    groups = {}

    def file(o, g):
        if o is None:
            return
        o.visible_shadow = False
        o["eh_src"] = "building"
        groups.setdefault(g, []).append(o)

    for it in t["items"]:
        for piece in it["pieces"]:
            o = put(lib, piece, it["pivot"], it["scale"])
            if o is not None and it.get("color") and piece["name"].endswith("_Body"):
                tint(o, _hexc(it["color"]), rough=0.75)
            file(o, it["group"])
    for p in t["parts"]:
        s, c = p["size"], p["pos"]
        b = [c[0] - s[0] / 2, c[1] - s[1] / 2, c[2] - s[2] / 2, c[0] + s[0] / 2, c[1] + s[1] / 2, c[2] + s[2] / 2]
        neon = p["material"] == "Neon"
        o = gbox("Tower" + p["name"], b, _hexc(p["color"]), emit=2.2 if neon else 0.0, shadow=False)
        file(o, p["group"])
        sg = p.get("sign")
        if sg:
            col = _hexc(sg["color"])
            if sg.get("vertical"):
                letters = "\n".join(ch for ch in sg["text"] if ch != " ")
                for side in (1, -1):
                    x = c[0] + side * (s[0] / 2 + 0.03)
                    o2 = text3(letters, 0.95, col, 2.5, rb(x, c[1], c[2]), (math.pi / 2, 0, -side * math.pi / 2))
                    o2.data.space_line = 0.95
                    file(o2, p["group"])
            else:
                size = min(s[1] * 0.62, s[0] / max(1, len(sg["text"])) * 1.7)
                o2 = text3(sg["text"], size, col, 2.5 if col != "#3C3246" else 0.0,
                           rb(c[0], c[1], c[2] + s[2] / 2 + 0.03), (math.pi / 2, 0, math.pi))
                file(o2, p["group"])
    return groups


def cut(t, groups, cam, subjects):
    """Shared/Heist/CutMath.decide on the planned groups (Roblox coordinates): hides what the game hides."""
    C = t["cut"]
    ceil_y = t["ceilY"]
    ox0, ox1, oz0, oz1 = t["outer"]
    above = cam[1] > ceil_y + C["MARGIN"]
    pad = C["INSIDE_PAD"]
    inside = any(s[1] < ceil_y and ox0 - pad < s[0] < ox1 + pad and oz0 - pad < s[2] < oz1 + pad for s in subjects)
    over = ox0 < cam[0] < ox1 and oz0 < cam[2] < oz1
    hidden = set()
    for g in t["groups"]:
        hide = False
        if above and inside:
            if g["kind"] in ("ceiling", "roof"):
                hide = True
            elif g["kind"] == "face":
                n = g["normal"]
                side = (cam[0] - g["plane"]) * n[0] if n[0] != 0 else (cam[2] - g["plane"]) * n[1]
                hide = over or side > 0
        if not hide:
            for sp in subjects:
                d = tuple(sp[k] - cam[k] for k in range(3))
                if ray_box(cam, d, g["box"]) is not None:
                    hide = True
                    break
        if hide:
            hidden.add(g["name"])
    for name, objs in groups.items():
        for o in objs:
            o.hide_render = name in hidden
    return hidden


def _look(pos, tgt, fy):
    """Heist/CutAway's look subject: where the camera's look ray meets the floor + CUT.LOOK_HEIGHT (3)."""
    d = tuple(tgt[k] - pos[k] for k in range(3))
    if d[1] >= -1e-3:
        return []
    t = (fy + 3.0 - pos[1]) / d[1]
    return [tuple(pos[k] + d[k] * t for k in range(3))] if t > 0 else []


def _fp(x, z, fy, yaw, pitch):
    """The first-person eye at (x, z) looking along yaw (0 = -Z) and pitch (up positive): Roblox (pos, target)."""
    p = math.radians(pitch)
    pos = (x, fy + EYE_H, z)
    d = (-math.sin(yaw) * math.cos(p), math.sin(p), -math.cos(yaw) * math.cos(p))
    return pos, tuple(pos[k] + d[k] * 20 for k in range(3))


def big_level(level, samples, out_dir):
    """BIG (LEVELS.md 11): the tall building from the first-person eye (the shop from the street, looking up the
    facade, inside looking up at the ceiling and its lamps, inside looking round) and from the diorama and classic
    cameras with the game's cut-away, graded like WORLD 2.0."""
    import backdrop_shots as BS
    W, Hh = W2_SIZE
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    tag = short(level)
    fy = level["floorY"]
    sp = level["spawns"][0]
    cfg = level["backdropConfig"]
    CC = level["camera"]["CLASSIC"]
    DF = level["camera"]["DIORAMA"]["FOV"]
    t = level["tower"]
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    lib = Lib(level["location"])
    _held, doors, _lasers = build(level, False, lib)
    gus_and_cone(level, doors, level["location"], level["dressing"])
    groups = tower(t, lib)
    BS.backdrop(level, lib, put, soft_pool_mat)
    lighting(s)
    BS.world_sky(s, TMP)
    cam = _w2_camera(s, W, Hh)
    J = player(level)
    ox0, ox1, oz0, oz1 = t["outer"]
    mid_z = max(oz0 + 14.0, -24.0)
    shots = [
        # first person: the shop from the street spawn, up the facade from the van, inside up at the ceiling and round
        ("fp_street", _fp(sp["x"] - 3.0, oz1 + 15.0, fy, -0.12, 16.0), FP_FOV, (sp["x"] - 3.0, oz1 + 15.0), True),
        ("fp_up", _fp(sp["x"] + 14.0, oz1 + 21.0, fy, 0.38, 36.0), FP_FOV, (sp["x"] + 14.0, oz1 + 21.0), True),
        ("fp_ceiling", _fp(0.0, mid_z + 6.0, fy, 0.0, 50.0), FP_FOV, (0.0, mid_z + 6.0), False),
        ("fp_inside", _fp(0.0, oz1 - 6.0, fy, 0.0, 6.0), FP_FOV, (0.0, oz1 - 6.0), False),
        ("fp_corner", _fp(ox1 + 9.0, oz1 + 13.0, fy, math.radians(30), 26.0), FP_FOV, (ox1 + 9.0, oz1 + 13.0), True),
    ]
    for name, (pos, tgt), fov, (px, pz), outdoors in shots:
        move(J, level, px, pz + 30.0, 0.0)          # out of the eye's way (first person hides your body)
        cut(t, groups, pos, [])                     # first person never cuts
        _w2_shoot(s, cam, f"{tag}_{name}", pos, tgt, fov, pos if outdoors else None, cfg, out_dir, level=level)
    # the diorama and classic cameras at the spawn (you on the street: the tall front stands behind you)
    at = (sp["x"], fy + 4.5, sp["z"])
    move(J, level, sp["x"], sp["z"], sp["yaw"])
    you = [(sp["x"], fy + 4.5, sp["z"]), (sp["x"], fy + 0.8, sp["z"])]
    pos, tgt = _diorama(level["camera"], *at, sp["yaw"])
    print("cut", tag, "diorama", sorted(cut(t, groups, pos, you + _look(pos, tgt, fy))))
    _w2_shoot(s, cam, f"{tag}_diorama", pos, tgt, DF, at, cfg, out_dir, level=level)
    pos, tgt = _classic(*at, sp["yaw"], CC["ZOOM"], CC["PITCH"])
    print("cut", tag, "classic", sorted(cut(t, groups, pos, you + _look(pos, tgt, fy))))
    _w2_shoot(s, cam, f"{tag}_classic", pos, tgt, CC["FOV"], at, cfg, out_dir, level=level)
    # the diorama with you inside: the dollhouse opens (ceiling, roof and the storeys on the camera's side)
    move(J, level, 0.0, mid_z, 0.0)
    you = [(0.0, fy + 4.5, mid_z), (0.0, fy + 0.8, mid_z)]
    pos, tgt = _diorama(level["camera"], 0.0, fy + 4.5, mid_z, 0.0)
    print("cut", tag, "diorama_mid", sorted(cut(t, groups, pos, you + _look(pos, tgt, fy))))
    _w2_shoot(s, cam, f"{tag}_diorama_mid", pos, tgt, DF, None, cfg, out_dir, level=level)
    # a high establishing view of the block from across the street (presentation height, nothing cut)
    cut(t, groups, (0, 999, 999), [])
    pos = (ox1 + 40.0, fy + 34.0, oz1 + 70.0)
    tgt = ((ox0 + ox1) / 2, fy + 26.0, (oz0 + oz1) / 2)
    _w2_shoot(s, cam, f"{tag}_street_wide", pos, tgt, 60.0, pos, cfg, out_dir, level=level)


def big_garage(g, samples, out_dir):
    """BIG: the warehouse hideout from the first-person eye (the spawn view down the aisle, up at the trusses and
    skylights, the mezzanine and the stations) and the diorama with the cut-away."""
    import backdrop_shots as BS
    W, Hh = W2_SIZE
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    s = MR.reset(samples)
    s.view_settings.exposure = 0.3
    lib = Lib(g["location"])
    groups = garage_scene(g, lib)
    BS.backdrop({"backdrop": g["backdrop"], "backdropConfig": g["backdropConfig"], "kit": [], "location": g["location"],
                 "lighting": g["lighting"]}, lib, put, soft_pool_mat)
    lighting(s)
    BS.world_sky(s, TMP)
    cam = _w2_camera(s, W, Hh)
    cfg = g["backdropConfig"]
    DF = g["camera"]["DIORAMA"]["FOV"]
    t = g["tower"]
    sx, sz = g["spawn"]
    J = MR.figure("player", tuple(rb(sx, 0, sz + 30)), 180.0, colors=MR.ROOKIE)
    shots = [
        ("GA_fp_spawn", _fp(sx, sz, 0.0, math.radians(-38), 6.0)),          # toward your van, the board, the door
        ("GA_fp_up", _fp(sx, sz - 6, 0.0, math.radians(-30), 48.0)),        # the trusses and the skylights
        ("GA_fp_mezzanine", _fp(-10.0, -8.0, 0.0, math.radians(185), 14.0)),  # the mezzanine, the TV, the stair
        ("GA_fp_stations", _fp(10.0, 2.0, 0.0, math.radians(-56), 4.0)),     # the laptop, the crew sign, the stair
        ("GA_fp_wardrobe", _fp(-20.0, 4.0, 0.0, math.radians(100), 6.0)),    # the wardrobe corner and the tree
    ]
    for name, (pos, tgt) in shots:
        cut(t, groups, pos, [])
        _w2_shoot(s, cam, name, pos, tgt, FP_FOV, None, cfg, out_dir)
    J["root"].location = rb(sx, 0, sz)
    pos, tgt = _diorama(g["camera"], sx, 4.5, sz, 0.0)
    print("cut GA diorama", sorted(cut(t, groups, pos, [(sx, 4.5, sz), (sx, 0.8, sz)] + _look(pos, tgt, 0.0))))
    _w2_shoot(s, cam, "GA_diorama", pos, tgt, DF, None, cfg, out_dir)
    # out in the snowy yard, looking back at the warehouse and its big roll-up door
    yz = -g["lobby"]["HALF_Z"] - g["lobby"]["WALL_T"] - g["lobby"]["STREET_DEPTH"] * 0.8
    pos, tgt = _fp(6.0, yz, 0.0, math.pi, 22.0)
    cut(t, groups, pos, [])
    _w2_shoot(s, cam, "GA_fp_yard", pos, tgt, FP_FOV, pos, cfg, out_dir)


W2_COLS = ("diorama", "classic", "diorama_mid", "classic_rev")


def world2_sheet(before, after, out):
    """Before / after contact sheet: one row per site, each shot as a before | after pair, with the near-black share
    and the median luma under each tile."""
    from PIL import Image, ImageDraw

    def grades(folder):
        p = os.path.join(folder, "grades.json")
        return json.load(open(p)) if os.path.isfile(p) else {}
    gb, ga = grades(before), grades(after)
    tw, th = 320, 148
    tags = [t if t != "garage" else "GA" for t in W2_SITES]
    sheet = Image.new("RGB", (tw * 2 * len(W2_COLS) + 60, (th + 22) * len(tags) + 40), (24, 25, 36))
    d = ImageDraw.Draw(sheet)
    f, _ = MR._font(14)
    for c, col in enumerate(W2_COLS):
        d.text((60 + c * 2 * tw + 6, 12), f"{col}: before | after  (near-black %, median luma)", font=f,
               fill=(230, 232, 245))
    for r, tag in enumerate(tags):
        y = 40 + r * (th + 22)
        d.text((8, y + th // 2), tag, font=f, fill=(230, 232, 245))
        for c, col in enumerate(W2_COLS):
            for k, (folder, gr) in enumerate(((before, gb), (after, ga))):
                p = os.path.join(folder, f"{tag}_{col}.png")
                x = 60 + (2 * c + k) * tw
                if not os.path.isfile(p):
                    continue
                sheet.paste(Image.open(p).convert("RGB").resize((tw - 4, th), Image.LANCZOS), (x, y))
                g = gr.get(f"{tag}_{col}")
                if g:
                    d.text((x + 4, y + th + 3), "%.1f %%  %.3f" % (g["near_black"], g["median_luma"]), font=f,
                           fill=(230, 232, 245))
    sheet.save(out, optimize=True)
    print("wrote", out)


# ------------------------------------------------------------------ grading (tools/blender/frame_grade.py)
ID_GROUPS = (   # (group, object-name prefixes), first match wins: frame_grade.ID_COLOURS gives the mask colours
    ("zone", ("VanZone", "ArrowShaft", "ArrowHead")),
    ("van", ("Van",)),
    ("cash", ("CashBag", "CashRegister", "GoldBar", "GoldStack", "Diamond", "Safe", "Stand", "sparkle")),
    ("plate", ("Plate_4x4",)),
    ("lamp", ("Lamp_Ceiling_Bulb", "StreetLamp_Bulb")),
    ("board", ("JobBoard", "JobCard")),
    ("rug", ("Rug_",)),
)


def id_mask(s, cam, path):
    """A Workbench pass with every mesh in flat black except the ID groups in their mask colours (occlusion
    included, no anti-aliasing), so frame_grade can say which element owns the brightest pixels."""
    import frame_grade as FG
    keep = (s.render.engine, s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure)
    colours = {}
    hidden = []
    for o in bpy.data.objects:
        if o.type not in ("MESH", "FONT", "CURVE"):
            continue
        colours[o.name] = tuple(o.color)
        if o.name.startswith(("Snowfall", "pool", "WindowSpill", "cone")) and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
            continue
        col = (0.0, 0.0, 0.0)
        for g, prefixes in ID_GROUPS:
            if o.name.startswith(prefixes):
                col = tuple(c / 255 for c in FG.ID_COLOURS[g])
                break
        o.color = (*col, 1.0)
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
        if o.name in colours:
            o.color = colours[o.name]
    for o in hidden:
        o.hide_render = False
    s.render.engine, s.render.film_transparent, s.view_settings.view_transform, s.view_settings.exposure = keep


def record_grade(gdir, g):
    path = os.path.join(gdir, "grades.json")
    allg = json.load(open(path)) if os.path.isfile(path) else {}
    allg[os.path.splitext(g["frame"])[0]] = g
    json.dump(allg, open(path, "w"), indent=1, sort_keys=True)
    print("grade", json.dumps(g))


def contact_sheet(levels):
    from PIL import Image, ImageDraw
    cols = ("1_spawn", "1b_spawn_clones", "2_objective", "3_plan", "3b_plan_solved", "5_street", "4_thumb")
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
           "plan (run 1) | plan (solved) | street | 160x90 thumbnail (x2.4 nearest)", font=f, fill=(230, 232, 245))
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
    sheet.save(out, optimize=True)
    print("wrote", out)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--daily", action="store_true", help="also the 12 daily vaults")
    ap.add_argument("--plain", action="store_true", help="Christmas dressing layer off")
    ap.add_argument("--size", type=int, default=1280)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--no-sheet", action="store_true")
    ap.add_argument("--shots", help="comma list of shot names to render (default: all)")
    ap.add_argument("--sheet-only", action="store_true")
    ap.add_argument("--out", help="output folder (default docs/audit/levels)")
    ap.add_argument("--golden", action="store_true",
                    help="GOLDEN_FRAMES G1 (L1) and G2 (L5) with the backdrop, sky, snow and haze into "
                         "docs/audit/levels/golden/ (one process per level; --only L1 or L5)")
    ap.add_argument("--stepped", action="store_true",
                    help="draw the light pools as the old hard stepped discs (before / after comparison)")
    ap.add_argument("--garage", action="store_true",
                    help="GOLDEN_FRAMES G3 (the garage v1, Heist/LobbyPlan) into docs/audit/levels/golden/")
    ap.add_argument("--world2", action="store_true",
                    help="WORLD 2.0 (LEVELS.md 10): every site of W2_SITES (or --only one: L1..L6, DV01, DV10, garage) "
                         "in the diorama and classic cameras at the full phone frame, graded (near-black share and its "
                         "sources) into --out (default docs/audit/levels/world2/after)")
    ap.add_argument("--world2-sheet", nargs=3, metavar=("BEFORE", "AFTER", "OUT"),
                    help="the WORLD 2.0 before / after contact sheet")
    ap.add_argument("--big", action="store_true",
                    help="BIG buildings (LEVELS.md 11): BIG_SITES (or --only one) from the first-person eye and the "
                         "diorama / classic cameras with the cut-away, graded into --out (default docs/audit/levels/big)")
    a = ap.parse_args(argv)
    global OUT, STEPPED
    STEPPED = a.stepped
    if a.out:
        OUT = os.path.abspath(a.out)
    if a.world2_sheet:
        world2_sheet(*(os.path.abspath(p) for p in a.world2_sheet))
        return
    if a.big:
        out = os.path.abspath(a.out) if a.out else BIG
        if not a.only:
            for tag in BIG_SITES:   # one Blender process per site
                subprocess.run([sys.executable, os.path.abspath(__file__), "--big", "--only", tag, "--samples",
                                str(a.samples), "--out", out], check=True)
            return
        plan = load_plan(not a.plain, a.only.upper().startswith("DV"))
        if a.only == "garage":
            plan["garage"]["firstJob"] = plan["levels"][0]["name"].upper()
            big_garage(plan["garage"], a.samples, out)
            return
        lv = next(lv for lv in plan["levels"] if short(lv).upper() == a.only.upper() or lv["id"] == a.only)
        big_level(lv, a.samples, out)
        return
    if a.world2:
        out = os.path.abspath(a.out) if a.out else os.path.join(WORLD2, "after")
        if not a.only:
            for tag in W2_SITES:   # one Blender process per site (factory resets in one process are flaky)
                subprocess.run([sys.executable, os.path.abspath(__file__), "--world2", "--only", tag, "--samples",
                                str(a.samples), "--out", out], check=True)
            return
        plan = load_plan(not a.plain, a.only.upper().startswith("DV"))
        if a.only == "garage":
            plan["garage"]["firstJob"] = plan["levels"][0]["name"].upper()   # Heist/JobCard.first(Catalog)
            world2_garage(plan["garage"], a.samples, out)
            return
        lv = next(lv for lv in plan["levels"] if short(lv).upper() == a.only.upper() or lv["id"] == a.only)
        world2_level(lv, a.samples, out)
        return
    plan = load_plan(not a.plain, a.daily)
    levels = plan["levels"]
    W, Hh = a.size, a.size * 9 // 16
    if a.garage:
        g = plan["garage"]
        g["firstJob"] = levels[0]["name"].upper()        # Heist/JobCard.first(Catalog)
        garage(g, W, Hh, a.samples, os.path.abspath(a.out) if a.out else None)
        return
    if a.golden and not a.only:
        for tag in ("L1", "L5", "L3", "L4", "L6"):
            subprocess.run([sys.executable, os.path.abspath(__file__), "--golden", "--only", tag, "--size",
                            str(a.size), "--samples", str(a.samples)] + (["--out", a.out] if a.out else []) +
                           (["--stepped"] if a.stepped else []), check=True)
        return
    if a.only:
        lv = next(lv for lv in levels if short(lv).upper() == a.only.upper() or lv["id"] == a.only)
        if a.golden:
            golden(lv, W, Hh, a.samples, os.path.abspath(a.out) if a.out else None)
            return
        shoot(lv, W, Hh, a.samples, a.shots.split(",") if a.shots else None)
        return
    if a.sheet_only:
        contact_sheet(levels)
        return
    for lv in levels:   # one Blender process per level (factory resets + Eevee renders in one process are flaky)
        cmd = [sys.executable, os.path.abspath(__file__), "--only", lv["id"], "--size", str(a.size),
               "--samples", str(a.samples)] + (["--daily"] if a.daily else []) + (["--plain"] if a.plain else []) + \
              (["--out", a.out] if a.out else []) + \
              (["--shots", a.shots] if a.shots else []) + (["--stepped"] if a.stepped else [])
        subprocess.run(cmd, check=True)
    if not a.no_sheet:
        contact_sheet(levels)


if __name__ == "__main__":
    main(sys.argv[1:])
