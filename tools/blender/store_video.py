"""The experience-page VIDEO (docs/marketing/final/video/, UPLOAD.md there): one ~29 s 16:9 clip rendered as animation
in Blender from the game's own kit, levels, hideout and town, with every figure walking the game's real paths.

    python3 tools/blender/store_video.py --list
    python3 tools/blender/store_video.py --shot hook [--from 0 --to 20] [--scale 0.6667] [--samples 6]
    python3 tools/blender/store_video.py --render-all          # every shot, in chunks (one Blender process each)
    python3 tools/blender/store_video.py --edit                # ffmpeg: the mp4, the poster, frames.png

Where the motion comes from (nothing hand-animated): `lune run tools/blender/video_paths.luau <level>` plays the
level's solution (tests/sim/Solutions) through the sim harness, the same HeistSim the server runs, and samples every
actor (you and your recorded clones: the echo replays), Gus (patrol, Suspicious), the doors and the loot at 20 Hz.
Here each figure is the kit Rookie (assets/fbx/Rookie*.fbx, a Config.Rookie outfit) re-posed every frame through its
R15 joints: a walk cycle driven by the distance it covered, the carry pose while it holds loot, the clone look
(EchoView: crew-hue fill + outline + floor glow, the solo age ramp), the tape print (Config.Clone.PRINT_SECONDS,
feet first, the scan band). Gus is the kit rig with his torch cone rebuilt each frame from the sim's yaw (level_shots
.cone: the same sight rays). Doors pocket when the sim opens them; plate rings light when held.

What is not the live game: Eevee lighting instead of Roblox Future, the 2D grade (the game's Bloom +
ColorCorrection, as marketing_renders.finish), the stamps and labels drawn in 2D in the game's font (Luckiest Guy) and
colours: RUN n, REWIND, 8 OF ME, CREW VIEW, the numbered pills, Gus's "?" (all real HUD text), and the title card.
"""
import argparse, json, math, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "marketing", "final", "video")
BUILD = os.path.join(REPO, "build", "video")
FRAMES = os.path.join(BUILD, "frames")
FPS = 24
W_FULL, H_FULL = 1920, 1080

CYAN, MAGENTA, INDIGO, WHITE = "#3DE8FF", "#FF4FD8", "#6A5CFF", "#F4F7FF"
INK, GOLD_HI = "#1C1F3B", "#FFE69C"
PRINT_SECONDS = 0.35       # Config.Clone.PRINT_SECONDS
FILL = 0.55                # Config.Heist.CLONE_FILL_TRANSPARENCY as EchoView uses it (golden_plan "fill")

# ------------------------------------------------------------------ the shot list (edit order; times in the video)
# name: (seconds, level number or stage, what it shows)
SHOTS = [
    ("hook", 2.0, "L1 Back Room, run 2, first person: your run-1 clone tape-prints out of you and runs to the plate"),
    ("eight", 3.0, "L5 Clone Party, run 8: seven clones print out of you at once and pour in, 8 OF ME"),
    ("run1", 1.6, "L2 Two Doors, run 1: you step on plate A, the door opens"),
    ("rewind", 1.2, "REWIND: the same run reels backwards (the game's rewind grade), RUN 2"),
    ("crew", 4.6, "L2 Two Doors, run 3, Crew View: both clones hold a door each, you take the safe"),
    ("gus", 3.0, "L4 Night Clerk, run 3: Gus sweeps his torch, '?', you slip past with the deposit"),
    ("town", 2.4, "The story: the toy town under the aurora, Hoardsworth Tower and the Snow Globe"),
    ("hideout", 2.2, "The hideout, first person: the job board and your van"),
    ("party", 3.6, "L5 Clone Party: you and seven clones haul the loot back to the van"),
    ("title", 4.0, "The crew in the snow under the aurora; the HEIST YOURSELF wordmark"),
]
SHOT = {n: (d, txt) for n, d, txt in SHOTS}
# The render budget (measured: L5 with 8 clones ~28 s a frame at 3 samples with the haze pass): the two hook shots get
# 3 samples and the Atmosphere haze; the rest 2 samples and no haze (raised interior views, where the haze over
# 20-40 studs is a 4-7 % tint).
SAMPLES = {"hook": 3, "eight": 3}
HAZED = {"hook", "eight"}


def nframes(name):
    return int(round(SHOT[name][0] * FPS))


def frame_dir(name):
    return os.path.join(FRAMES, name)


# ------------------------------------------------------------------ the sim paths (video_paths.luau)
def sim_paths(num):
    os.makedirs(BUILD, exist_ok=True)
    path = os.path.join(BUILD, f"paths_L{num}.json")
    if not os.path.isfile(path):
        with open(path, "w") as f:
            subprocess.run(["lune", "run", "tools/blender/video_paths.luau", str(num)], cwd=REPO, check=True, stdout=f)
    return json.load(open(path))


class Run:
    """One run of a level's solution: actor / guard / door state at any time t (linear between the 20 Hz ticks)."""

    def __init__(self, data, index):
        self.ticks = data["runs"][index - 1]["ticks"]
        self.hz = data["hz"]

    def _pair(self, t):
        f = max(0.0, t) * self.hz
        i = min(int(f), len(self.ticks) - 1)
        j = min(i + 1, len(self.ticks) - 1)
        return self.ticks[i], self.ticks[j], (f - i if j > i else 0.0)

    def actors(self, t):
        a, b, k = self._pair(t)
        out = []
        for p in (a["actors"] if isinstance(a["actors"], list) else []):
            q = next((x for x in (b["actors"] if isinstance(b["actors"], list) else []) if x["id"] == p["id"]), p)
            dy = (q["yaw"] - p["yaw"] + math.pi) % (2 * math.pi) - math.pi
            out.append(dict(p, x=p["x"] + (q["x"] - p["x"]) * k, z=p["z"] + (q["z"] - p["z"]) * k,
                            yaw=p["yaw"] + dy * k))
        return out

    def guards(self, t):
        a, b, k = self._pair(t)
        ga = a["guards"] if isinstance(a["guards"], list) else []
        gb = b["guards"] if isinstance(b["guards"], list) else ga
        out = []
        for p, q in zip(ga, gb):
            dy = (q["yaw"] - p["yaw"] + math.pi) % (2 * math.pi) - math.pi
            out.append(dict(p, x=p["x"] + (q["x"] - p["x"]) * k, z=p["z"] + (q["z"] - p["z"]) * k,
                            yaw=p["yaw"] + dy * k))
        return out

    def doors(self, t):
        a, _b, _k = self._pair(t)
        return a["doors"] if isinstance(a["doors"], list) else []

    def loot(self, t):
        a, _b, _k = self._pair(t)
        return a["loot"] if isinstance(a["loot"], list) else []

    @property
    def length(self):
        return (len(self.ticks) - 1) / self.hz


# ------------------------------------------------------------------ Blender side
def _bl():
    import bpy  # noqa: F401
    from mathutils import Matrix, Vector  # noqa: F401
    import marketing_renders as MR
    import kit_preview as K
    import intro_shots as IS
    import thumb_shots as T
    return bpy, Matrix, Vector, MR, K, IS, T


WALK_STRIDE = 5.0   # studs per full walk cycle


class Rig:
    """A kit Rookie that can be re-posed every frame: IS.rookie's loader and joint solve, with each part's imported
    frame kept so a new pose is a matrix update, not a re-import."""

    def __init__(self, crew=CYAN, outfit=None, face="smug", clone_hue=None, floor_y=0.0, glow=True):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        self.floor_y = floor_y
        outfit = outfit or T.DEFAULT
        cap, scarf, sweater, gloves = outfit
        pieces, gcol = T.GLOVE_PIECES[gloves]
        want = tuple(T.CAPS[cap] + T.SCARVES[scarf] + T.SWEATERS[sweater] + pieces)
        man = K.MANIFEST

        def load(fbx, keep):
            before = set(bpy.data.objects)
            bpy.ops.import_scene.fbx(filepath=os.path.join(K.FBX, fbx + ".fbx"))
            out = {}
            for o in set(bpy.data.objects) - before:
                base = o.name.split(".")[0]
                if o.type == "MESH" and keep(base):
                    mw = o.matrix_world.copy()
                    o.parent = None
                    o.matrix_world = mw
                    out[base] = o
                else:
                    bpy.data.objects.remove(o, do_unlink=True)
            return out

        body = load("Rookie", lambda n: n != "Rookie_Face_Idle" or face == "idle")
        extra = load("Rookie_Outfits", lambda n: n in want)
        if face != "idle":
            extra.update(load("Rookie_Faces", lambda n: n == "Rookie_Face_" + face.capitalize()))
        self.joints = {n: v for n, v in man.items() if v.get("model") == "Rookie" and v.get("joint")}
        self.parts = []   # (object, joint to follow, extra matrix, origin, rest matrix)
        hue = clone_hue or crew
        self.hue = hue
        for name, o in body.items():
            if name in self.joints:
                self.parts.append((o, name, Matrix.Identity(4), self.joints[name]["origin"], o.matrix_world.copy()))
                K.style(o, IS.LOC, gcol if name.endswith("Hand") else None)
            else:
                self.parts.append((o, "Rookie_Head", Matrix.Identity(4), man[name]["origin"], o.matrix_world.copy()))
                K.style(o, IS.LOC, None)
        for name, o in extra.items():
            v = man[name]
            a = v.get("attach") or {"part": "Head", "offset": [0, 0, 0]}
            tint = gcol if "Gloves" in name else (hue if v.get("tint") else None)
            self.parts.append((o, "Rookie_" + a["part"], Matrix.Translation(tuple(a["offset"])), v["origin"],
                               o.matrix_world.copy()))
            K.style(o, IS.LOC, tint)
        self.objs = [p[0] for p in self.parts]
        self.clone = clone_hue is not None
        self.glow = self.band = None
        if self.clone:
            IS.clone_look(self.objs, clone_hue, FILL)
            if glow:
                gm = MR.mat(clone_hue, 0.5, emit=1.4, alpha=0.4, key=("glow", clone_hue))
                self.glow = MR.cyl("FloorGlow", 1.6, 1.6, 0.02, gm, None, (0, 0, 0), seg=32)
                self.glow.visible_shadow = False
            bm_ = MR.mat(clone_hue, 0.5, emit=6.0, alpha=0.75, key=("band", clone_hue))
            self.band = MR.cyl("PrintBand", 1.6, 1.6, 0.06, bm_, None, (0, 0, 0), seg=32)
            self.band.visible_shadow = False
            self.band.hide_render = True
        for o in self.objs:
            o["eh_group"] = "clone" if self.clone else "hero"
        self.phase = 0.0
        self.last = None
        self.at = (0.0, floor_y, 0.0)

    def set(self, at, yaw_deg, pose):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        place_m = Matrix.Translation(IS.rbv(at)) @ Matrix.Rotation(math.radians(yaw_deg), 4, "Z")
        world = {}

        def solve(name):
            if name in world:
                return world[name]
            v = self.joints[name]
            par = v["joint"].get("parent")
            o = v["origin"]
            po = self.joints[par]["origin"] if par else (0, 0, 0)
            e = pose.get(v["joint"]["name"], (0, 0, 0))
            w = (solve(par) if par else Matrix.Identity(4)) @ Matrix.Translation(
                (o[0] - po[0], o[1] - po[1], o[2] - po[2])) @ IS.r_euler_yxz(*e)
            world[name] = w
            return w

        for o, joint, extra, origin, rest in self.parts:
            Wm = solve(joint) @ extra
            delta = Wm @ Matrix.Translation(origin).inverted()
            o.matrix_world = place_m @ (IS.C4 @ delta @ IS.C4I) @ rest
        self.at = at
        if self.glow is not None:
            self.glow.location = IS.rb(at[0], self.floor_y + 0.07, at[2])

    def visible(self, on):
        for o in self.objs:
            o.hide_render = not on
        if self.glow is not None:
            self.glow.hide_render = not on
        if not on and self.band is not None:
            self.band.hide_render = True

    def tape_print(self, h):
        """The tape print `h` studs up from the feet (None = done): parts above it not printed yet, the scan band."""
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        bpy.context.view_layer.update()
        fb = IS.rb(0, self.floor_y, 0).z
        for o in self.objs:
            zmin = min((o.matrix_world @ Vector(c)).z for c in o.bound_box)
            o.hide_render = h is not None and zmin - fb > h
        if self.band is not None:
            self.band.hide_render = h is None
            if h is not None:
                self.band.location = IS.rb(self.at[0], self.floor_y + h, self.at[2])

    def drive(self, x, z, yaw_rad, carrying=False, extra=None, still=None):
        """Pose from motion: the walk cycle advances with the distance covered since the last frame."""
        moved = 0.0
        if self.last is not None:
            moved = math.hypot(x - self.last[0], z - self.last[1])
        self.last = (x, z)
        self.phase += moved / WALK_STRIDE * 2 * math.pi
        speed = moved * FPS
        amp = min(1.0, speed / 10.0) if still is None else 0.0
        pose = walk_pose(self.phase, amp, carrying)
        if extra:
            pose.update(extra)
        bob = abs(math.sin(self.phase)) * 0.15 * amp
        self.set((x, self.floor_y + bob, z), math.degrees(yaw_rad), pose)


def walk_pose(phase, amp, carrying=False):
    s = math.sin(phase)
    c = math.cos(phase)
    p = {"RightHip": (30 * s * amp, 0, 0), "LeftHip": (-30 * s * amp, 0, 0),
         "RightKnee": (-(8 + 34 * max(0.0, -c)) * amp, 0, 0), "LeftKnee": (-(8 + 34 * max(0.0, c)) * amp, 0, 0),
         "Waist": (-6 * amp, 6 * s * amp, 0), "Neck": (4 * amp, -4 * s * amp, 0)}
    if carrying:
        p.update({"RightShoulder": (62, 0, 14), "RightElbow": (44, 0, 0), "LeftShoulder": (62, 0, -14),
                  "LeftElbow": (44, 0, 0)})
    else:
        p.update({"RightShoulder": (-34 * s * amp, 0, -6), "LeftShoulder": (34 * s * amp, 0, 6),
                  "RightElbow": (30 * amp + 6, 0, 0), "LeftElbow": (30 * amp + 6, 0, 0)})
    return p


def clone_hue(rank, count, base=CYAN):
    import thumb_shots as T
    return T.drift(base, rank, count)


# ------------------------------------------------------------------ level stage helpers
REC = {}


def build_level(level_id, samples):
    """thumb_shots.level with every door closed (the doors pocket per frame) and the kit items recorded so this script
    can find each door leaf, plate ring and loot prop."""
    bpy, Matrix, Vector, MR, K, IS, T = _bl()
    import level_shots as LS
    orig = LS.put

    def put(lib, piece, pivot, scale, extra=None):
        o = orig(lib, piece, pivot, scale, extra)
        if o is not None:
            REC.setdefault(id(pivot), []).append(o)
        return o
    LS.put = put
    LS.HELD = []
    try:
        s, lv, doors, groups = T.level(level_id, samples, held=False)
    finally:
        LS.put = orig
    items = {}
    for it in lv["kit"]:
        if it["role"] in ("door", "plate", "loot", "display") and it.get("index"):
            items.setdefault((it["role"], it["index"]), []).extend(REC.get(id(it["pivot"]), []))
    return s, lv, doors, groups, items


class LevelState:
    """Per frame: door leaves pocketed when open, plate rings lit when held, loot gone once carried."""

    def __init__(self, lv, items):
        import level_shots as LS
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        self.lv, self.items = lv, items
        self.idle = {}
        self.lit = MR.mat(CYAN, 0.6, emit=2.5, key="ring_lit")
        for (role, idx), objs in items.items():
            for o in objs:
                if o.name.startswith("Plate_4x4_Ring") and o.data.materials:
                    self.idle[o.name] = o.data.materials[0]
        self.LS = LS

    def apply(self, doors_open, plates_held=(), loot_taken=()):
        for (role, idx), objs in self.items.items():
            if role == "door":
                op = idx - 1 < len(doors_open) and doors_open[idx - 1]
                for o in objs:
                    o.hide_render = bool(op)
            elif role == "plate":
                for o in objs:
                    if o.name in self.idle:
                        o.data.materials[0] = self.lit if idx in plates_held else self.idle[o.name]
            elif role == "loot":
                for o in objs:
                    o.hide_render = idx in loot_taken


def plates_held(lv, actors):
    held = set()
    for i, p in enumerate(lv["plates"], 1):
        b = p["box"]
        for a in actors:
            if a.get("present", True) and b[0] - 0.3 <= a["x"] <= b[3] + 0.3 and b[2] - 0.3 <= a["z"] <= b[5] + 0.3:
                held.add(i)
    return held


def loot_taken(run, t):
    return {i for i, l in enumerate(run.loot(t), 1) if l.get("state") not in (None, "Home")}


class Gus:
    def __init__(self, lv, g):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        self.lv = lv
        by = MR.gus(tuple(IS.rb(g["x"], lv["floorY"], g["z"])), math.degrees(g["yaw"]), pose="patrol", santa=True,
                    loc=lv["location"])
        for o in by.values():
            o["eh_group"] = "gus"
        lens = by.get("Gus_FlashlightLens")
        if lens:
            LS.tint(lens, LS.PAL["amber"], emit=6.0)
        root = by["Gus_LowerTorso"]
        while root.parent is not None:
            root = root.parent
        self.root, self.by = root, by
        ld = bpy.data.lights.new("torch", "SPOT")
        ld.color = MR.lin("#FFC46B")[:3]
        ld.energy = 2600
        ld.spot_size = math.radians(40)
        ld.spot_blend = 0.5
        self.torch = bpy.data.objects.new("torch", ld)
        bpy.context.scene.collection.objects.link(self.torch)

    def set(self, g, doors_open, t):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        bob = abs(math.sin(t * 7.0)) * 0.12
        self.root.location = IS.rb(g["x"], self.lv["floorY"] + bob, g["z"])
        self.root.rotation_euler = (0, 0, g["yaw"])
        for o in [o for o in bpy.data.objects if o.name.startswith("cone")]:
            bpy.data.objects.remove(o, do_unlink=True)
        LS.cone(self.lv, {i + 1: bool(v) for i, v in enumerate(doors_open)}, g)
        bpy.context.view_layer.update()
        p = self.by["Gus_FlashlightLens"].matrix_world.translation.copy() if "Gus_FlashlightLens" in self.by else \
            self.by["Gus_Head"].matrix_world.translation.copy()
        fx, fz = -math.sin(g["yaw"]), -math.cos(g["yaw"])
        tgt = IS.rb(g["x"] + fx * 14, self.lv["floorY"], g["z"] + fz * 14)
        self.torch.location = p
        self.torch.rotation_euler = (tgt - p).to_track_quat("-Z", "Y").to_euler()

    def head(self):
        return self.by["Gus_Head"].matrix_world.translation.copy()


# ------------------------------------------------------------------ camera, render, finish
def cam_set(cam, pos_r, look_r, fov):
    bpy, Matrix, Vector, MR, K, IS, T = _bl()
    p, l = IS.rb(*pos_r), IS.rb(*look_r)
    cam.location = p
    cam.rotation_euler = (l - p).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle_y = math.radians(fov)


def overhead(focus, pitch_deg, dist, yaw_deg=0.0):
    """The game's raised cameras (CameraMath): from `dist` studs back along yaw (0 = from +Z), `pitch_deg` down."""
    p, y = math.radians(pitch_deg), math.radians(yaw_deg)
    return (focus[0] + math.sin(y) * math.cos(p) * dist, focus[1] + math.sin(p) * dist,
            focus[2] + math.cos(y) * math.cos(p) * dist)


def hide_lamps():
    """Raised views only: the ceiling pendants hang between a high camera and the floor (the game's camera fade,
    Config.Heist.CAMERA.FADE, ghosts whatever covers your crew; here they are simply left out)."""
    import bpy
    for o in bpy.data.objects:
        if o.name.startswith("Lamp_Ceiling") and o.type == "MESH":
            o.hide_render = True


def lerp(a, b, k):
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(len(a)))


def ease(k):
    k = min(1.0, max(0.0, k))
    return k * k * (3 - 2 * k)


def render_frame(s, cam, out, hazed, overlay=None, vignette=0.12, finish_kw=None):
    """Eevee -> (level stage: Roblox tone map + Atmosphere haze from a half-size depth pass) -> the game's Bloom +
    ColorCorrection (marketing_renders.finish) -> the 2D layer (stamps, pills) -> a PNG frame at full 1080p."""
    bpy, Matrix, Vector, MR, K, IS, T = _bl()
    import backdrop_shots as BS
    import numpy as np
    from PIL import Image
    tmp = os.path.join(BUILD, "tmp")
    os.makedirs(tmp, exist_ok=True)
    raw = os.path.join(tmp, f"raw_{os.getpid()}.png")
    s.camera = cam
    s.render.filepath = raw
    s.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    src = raw
    if hazed and not os.environ.get("EH_NOHAZE"):
        depth = os.path.join(tmp, f"depth_{os.getpid()}.png")
        keep = (s.render.resolution_percentage, s.eevee.taa_render_samples)
        s.render.resolution_percentage, s.eevee.taa_render_samples = 50, 1
        BS.depth_pass(s, cam, depth)
        s.render.resolution_percentage, s.eevee.taa_render_samples = keep
        tm = BS.tonemap(raw, os.path.join(tmp, f"tm_{os.getpid()}.png"))
        a = np.asarray(Image.open(tm).convert("RGB"), np.float32)
        dp = np.asarray(Image.open(depth), np.float32)
        full = 65535.0 if dp.max() > 255 else 255.0
        if dp.ndim == 3:
            alpha, dist = dp[..., 3] / full, dp[..., 0] / full * BS.DEPTH_SCALE
        else:
            alpha, dist = np.ones(dp.shape, np.float32), dp / full * BS.DEPTH_SCALE
        f = np.clip(1 - np.exp(-dist / BS.HAZE_LAMBDA), 0, BS.HAZE_MAX) * (alpha > 0.5)
        f = np.asarray(Image.fromarray(f.astype(np.float32), "F").resize((a.shape[1], a.shape[0]), Image.BILINEAR))
        hz = np.array(BS.HAZE, np.float32)
        a = a * (1 - f[..., None]) + hz * f[..., None]
        src = os.path.join(tmp, f"haze_{os.getpid()}.png")
        Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(src)
    fin = os.path.join(tmp, f"fin_{os.getpid()}.png")
    img = MR.finish(src, fin, [], None, vignette=vignette, tag=False, truecolor=True, **(finish_kw or {}))
    img = img.convert("RGBA")
    if img.size != (W_FULL, H_FULL):
        img = img.resize((W_FULL, H_FULL), Image.LANCZOS)
    if overlay:
        img = overlay(img)
    img.convert("RGB").save(out, compress_level=1)


def screen_full(s, cam, p_b):
    """Blender point -> pixel at full 1080p (the overlay draws on the upscaled frame)."""
    bpy, Matrix, Vector, MR, K, IS, T = _bl()
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()
    v = world_to_camera_view(s, cam, Vector(p_b))
    return v.x * W_FULL, (1 - v.y) * H_FULL, v.z


# ------------------------------------------------------------------ 2D: the game's stamps and labels
def _font(px):
    import marketing_renders as MR
    return MR._font(int(px))[0]


def stamp(img, text, k, y=0.2, cap=0.1, fill=WHITE, key=None, key_fill=CYAN):
    """A HUD stamp ("RUN 2", "8 OF ME"): scales 1.25 -> 1.0 with Back Out over the first 0.25 of k (0..1 life), heavy
    caps in the Ink outline; fades over the last 15 %."""
    from PIL import Image, ImageDraw
    if k < 0 or k > 1:
        return img
    x = min(1.0, k / 0.25)
    c1 = 1.70158
    sc = 1.25 - 0.25 * (1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2)
    alpha = 1.0 if k < 0.85 else max(0.0, (1 - k) / 0.15)
    Hh = img.size[1]
    size = int(Hh * cap * sc / 0.72)
    f = _font(size)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    stroke = max(4, int(size * 0.09))
    words = text.split(" ")
    widths = [d.textlength(w, font=f) for w in words]
    space = d.textlength(" ", font=f)
    total = sum(widths) + space * (len(words) - 1)
    xx = img.size[0] / 2 - total / 2
    for w, wd in zip(words, widths):
        col = key_fill if key and w == key else fill
        rgb = tuple(int(col[i:i + 2], 16) for i in (1, 3, 5))
        d.text((xx + stroke * 0.5, y * Hh + stroke), w, font=f, fill=(28, 31, 59, 200), anchor="lm",
               stroke_width=stroke, stroke_fill=(28, 31, 59, 200))
        d.text((xx, y * Hh), w, font=f, fill=rgb + (255,), anchor="lm", stroke_width=stroke,
               stroke_fill=(28, 31, 59, 255))
        xx += wd + space
    if alpha < 1:
        import numpy as np
        a = np.asarray(layer).copy()
        a[..., 3] = (a[..., 3] * alpha).astype(np.uint8)
        layer = Image.fromarray(a)
    return Image.alpha_composite(img, layer)


def pill(img, xy, label, hue, h=0.03):
    from PIL import Image, ImageDraw
    x, y = xy
    Hh = img.size[1]
    rh, rw = Hh * h * 0.66, Hh * h * 0.85
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([x - rw, y - rh, x + rw, y + rh], radius=rh, fill=(28, 31, 59, 230),
                        outline=tuple(int(hue[i:i + 2], 16) for i in (1, 3, 5)) + (255,), width=max(2, int(Hh * 0.003)))
    d.text((x, y), label, font=_font(Hh * h * 1.0), fill=(244, 247, 255, 255), anchor="mm")
    return Image.alpha_composite(img, layer)


def label(img, text, y=0.07, cap=0.028):
    from PIL import ImageDraw
    W, Hh = img.size
    ImageDraw.Draw(img).text((W / 2, Hh * y), text, font=_font(Hh * cap), fill=(244, 247, 255, 230), anchor="mm",
                             stroke_width=max(2, int(Hh * 0.003)), stroke_fill=(28, 31, 59, 230))
    return img


def reticle(img):
    from PIL import ImageDraw
    W, Hh = img.size
    d = ImageDraw.Draw(img)
    r = max(3, int(Hh * 0.006))
    cx, cy = W / 2, Hh / 2
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=(28, 31, 59, 255))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(244, 247, 255, 255))
    return img


def pop(img, xy, glyph="?", r=0.05):
    import thumb_shots as T
    return T.pop(img, xy, glyph, r)


def dim(img, k):
    import numpy as np
    from PIL import Image
    a = np.asarray(img).astype(np.float32)
    a[..., :3] *= (1 - k)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def vignette_crew(img, strength=0.35):
    import numpy as np
    from PIL import Image
    W, Hh = img.size
    a = np.asarray(img).astype(np.float32)
    yy, xx = np.mgrid[0:Hh, 0:W].astype(np.float32)
    r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - Hh / 2) / (Hh / 2)) ** 2) / math.sqrt(2)
    a[..., :3] *= (1 - strength * np.clip((r - 0.55) / 0.45, 0, 1))[..., None]
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


# ------------------------------------------------------------------ the shots
class Shot:
    """Builds its scene once, then `frame(i)` poses it for frame i and returns (hazed, overlay)."""
    hazed = True
    vignette = 0.12

    def __init__(self, W, Hh, samples):
        self.W, self.Hh, self.samples = W, Hh, samples


def _cam(s, W, Hh):
    bpy, Matrix, Vector, MR, K, IS, T = _bl()
    cam = MR.camera(s, (0, 0, 10), (0, 1, 10), 50, W, Hh)
    cam.data.clip_end = 5000
    return cam


def _level_rigs(lv, run, t0):
    """One Rig per actor of the run: clones in the solo age ramp (older runs dimmer, drifting violet), you plain."""
    acts = run.actors(t0)
    clones = [a for a in acts if a["kind"] == "clone"]
    n = len(clones)
    rigs = {}
    for a in acts:
        if a["kind"] == "clone":
            rank = n - a["slot"]       # slot 1 = the oldest run
            rigs[a["id"]] = Rig(clone_hue=clone_hue(rank, n), floor_y=lv["floorY"])
        else:
            rigs[a["id"]] = Rig(floor_y=lv["floorY"])
    return rigs


def _drive(rigs, acts, t, print_from=None, stagger=0.0, hide_live=False):
    """Pose every rig at the sim's positions; clones print over PRINT_SECONDS from `print_from` (run start)."""
    order = sorted([a for a in acts if a["kind"] == "clone"], key=lambda a: a["slot"])
    for a in acts:
        r = rigs[a["id"]]
        if a["kind"] == "live" and hide_live:
            r.visible(False)
            continue
        r.drive(a["x"], a["z"], a["yaw"], carrying=bool(a.get("carrying")))
        r.visible(a.get("present", True))
        if r.clone and print_from is not None:
            k = order.index(a) if a in order else 0
            pt = t - print_from - k * stagger
            if pt < 0:
                r.visible(False)
            elif pt < PRINT_SECONDS:
                r.tape_print(5.4 * pt / PRINT_SECONDS)
            else:
                r.tape_print(None)


def _fp_hands(cam, pose="ready"):
    import level_shots as LS
    return LS.fp_hands(cam, None, pose=pose)


class Hook(Shot):
    """L1, run 2, from your eyes: the clock restarts, your run-1 clone prints out of you (feet first, the scan band)
    and runs to plate A, door A pockets. The first 0.9 s plays at 0.6x so the print reads."""

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        import backdrop_shots as BS
        self.s, self.lv, doors, groups, items = build_level("cs1_back_room", self.samples)
        self.state = LevelState(self.lv, items)
        self.run = Run(sim_paths(1), 2)
        self.rigs = _level_rigs(self.lv, self.run, 0)
        self.cam = _cam(self.s, self.W, self.Hh)
        self.eye = (0.0, 3.8, 16.6)          # a step behind the spawn: the print happens in front of you
        LS.cut(self.lv["tower"], groups, self.eye, [])
        LS._apply_fade(self.eye)
        self.hands = _fp_hands(self.cam)
        self.snow = BS.snowfall((0, 0, 16), self.lv["backdropConfig"], self.eye)

    def t_of(self, i):
        tv = i / FPS
        return tv * 0.6 if tv < 0.9 else 0.54 + (tv - 0.9)

    def frame(self, i):
        t = self.t_of(i)
        acts = self.run.actors(t)
        _drive(self.rigs, acts, t, print_from=0.05, hide_live=True)
        self.state.apply(self.run.doors(t), plates_held(self.lv, acts))
        look_x = 0.0 + 1.5 * ease((t - 0.6) / 1.2)
        cam_set(self.cam, self.eye, (look_x, 3.0, 4.0), 70)
        self.snow.location.z = -2.5 * i / FPS
        tv = i / FPS

        def over(img):
            img = reticle(img)
            return stamp(img, "RUN 2", tv / 0.8, y=0.2, cap=0.085)
        return True, over


class Eight(Shot):
    """L5 Clone Party, run 8: the seven staged clones (the Clone Party solution's runs 1-7) print out of you, 60 ms
    apart (Config.Moments.SWARM.ROLL_STAGGER), the pull-back (Config GOLDEN.G2: pitch 45, FOV 45), the world dims 15 %,
    the numbered pills and the 8 OF ME stamp."""

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        import backdrop_shots as BS
        self.s, self.lv, doors, groups, items = build_level("cs5_clone_party", self.samples)
        self.state = LevelState(self.lv, items)
        self.run = Run(sim_paths(5), 8)
        self.rigs = _level_rigs(self.lv, self.run, 0)
        self.cam = _cam(self.s, self.W, self.Hh)
        self.cut_at = overhead((0.0, 1.5, 4.0), 48, 26, 180)
        LS.cut(self.lv["tower"], groups, self.cut_at, [(0, 2, 13), (0, 2, 0), (0, 2, -14), (6, 2, -8), (-6, 2, -8)])
        LS._apply_fade(self.cut_at)
        hide_lamps()
        self.snow = BS.snowfall((0, 0, 8), self.lv["backdropConfig"], self.cut_at)

    @staticmethod
    def sim_t(tv):
        """0.35x through the print (the moment), then real time while the crew fans out into the aisles."""
        return 0.35 * tv if tv < 1.0 else 0.35 + (tv - 1.0)

    def frame(self, i):
        tv = i / FPS
        t = self.sim_t(tv)
        acts = self.run.actors(t)
        _drive(self.rigs, acts, t, print_from=0.02)
        self.state.apply(self.run.doors(t), plates_held(self.lv, acts))
        k = ease((tv - 0.4) / 2.4)
        focus = (0.0, 1.5, 8.0 - 18.0 * k)
        cam_set(self.cam, overhead(focus, 52 + 18 * k, 20 + 20 * k, 180), focus, 45)
        self.snow.location.z = -2.5 * tv
        clones = sorted([a for a in acts if a["kind"] == "clone"], key=lambda a: a["slot"])
        live = next(a for a in acts if a["kind"] == "live")
        heads = []
        for n_, a in enumerate(clones, 1):
            heads.append((screen_full(self.s, self.cam, IS_rb(a["x"], 6.0, a["z"])), str(n_), self.rigs[a["id"]]))
        heads.append((screen_full(self.s, self.cam, IS_rb(live["x"], 6.0, live["z"])), "8", None))

        def over(img):
            if tv > 1.85:
                img = dim(img, 0.15 * min(1.0, (tv - 1.85) / 0.1))
                for (x, y, _z), lab, rig in heads:
                    hue = CYAN if rig is None else rig.hue
                    img = pill(img, (x, y), lab, hue)
            return stamp(img, "8 OF ME", (tv - 1.85) / 1.3, y=0.15, cap=0.11, fill=GOLD_HI, key="8",
                         key_fill=CYAN)
        return True, over


def IS_rb(x, y, z):
    import intro_shots as IS
    return IS.rb(x, y, z)


def carry(bags, rigs, acts, scale):
    """The loot an actor holds (the sim's `carrying`) between its gloves while it carries; hidden otherwise."""
    bpy, Matrix, Vector, MR, K, IS, T = _bl()
    bpy.context.view_layer.update()
    for a in acts:
        objs = bags[a["id"]]
        on = bool(a.get("carrying"))
        if on:
            r = rigs[a["id"]]
            hl, hr = T.part_pos(r.objs, "Rookie_LeftHand"), T.part_pos(r.objs, "Rookie_RightHand")
            c = (hl + hr) / 2 + Vector((0, 0, 0.35))
        for o in objs:
            o.hide_render = not on
            if on:
                if "rest" not in o:
                    o["rest"] = [list(r_) for r_ in o.matrix_world]
                o.matrix_world = Matrix.Translation(c) @ Matrix.Scale(scale, 4) @ Matrix(o["rest"])


class LevelOverhead(Shot):
    """Shared body for the L2 shots: a run of Two Doors from a raised camera."""
    level_id, num, run_index = "cs2_two_doors", 2, 1

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        self.s, self.lv, doors, groups, items = build_level(self.level_id, self.samples)
        self.state = LevelState(self.lv, items)
        self.run = Run(sim_paths(self.num), self.run_index)
        self.rigs = _level_rigs(self.lv, self.run, 0)
        self.cam = _cam(self.s, self.W, self.Hh)
        self.groups = groups
        self.setup()

    def setup(self):
        pass


class Run1(LevelOverhead):
    """L2 run 1 (the classic follow camera, Config CAMERA.CLASSIC pitch 25): RUN 1, you walk onto plate A, door A
    pockets. These frames are also the REWIND shot's source."""
    run_index = 1

    def setup(self):
        import level_shots as LS
        self.cpos = overhead((-4.0, 1.5, 3.0), 55, 28)
        LS.cut(self.lv["tower"], self.groups, self.cpos, [(0, 2, 13), (0, 2, 3), (-10, 2, -8)])
        LS._apply_fade(self.cpos)
        hide_lamps()

    def frame(self, i):
        t = i / FPS
        acts = self.run.actors(t)
        _drive(self.rigs, acts, t)
        self.state.apply(self.run.doors(t), plates_held(self.lv, acts))
        k = ease(t / 1.6)
        focus = lerp((-1.0, 1.5, 7.0), (-5.0, 1.5, 0.0), k)
        cam_set(self.cam, overhead(focus, 55, 26), focus, 50)

        def over(img):
            return stamp(img, "RUN 1", t / 1.0, y=0.2, cap=0.085)
        return True, over


class Crew(LevelOverhead):
    """L2 run 3 in Crew View (Config CAMERA.CREW: pitch 60, FOV 50): both clones print out of you and run to plates
    A and B, both doors pocket, you go through to the safe and grab it; the pills over every head, CREW VIEW."""
    run_index = 3

    def setup(self):
        import level_shots as LS
        self.cpos = overhead((0.0, 1.5, -17.0), 68, 40)
        LS.cut(self.lv["tower"], self.groups, self.cpos, [(0, 2, -26), (0, 2, 10), (-10, 2, -8), (10, 2, -8),
                                                         (0, 2, -40)])
        LS._apply_fade(self.cpos)
        hide_lamps()
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        self.bags = {aid: K.place("CashBag", (0, 0, 0), 0, (), True, self.lv["location"]) for aid in self.rigs}

    def frame(self, i):
        t = i / FPS * 1.25
        acts = self.run.actors(t)
        _drive(self.rigs, acts, t, print_from=0.05, stagger=0.06)
        self.state.apply(self.run.doors(t), plates_held(self.lv, acts), loot_taken(self.run, t))
        live = next(a for a in acts if a["kind"] == "live")
        # the whole plan in frame: both plates (z -8) at the bottom, the safe room (z -40) at the top; steep enough
        # that the wall between the rooms does not hide you
        carry(self.bags, self.rigs, acts, 0.9)
        fz = max(-26.0, min(-10.0, live["z"] * 0.7 - 6.0))
        focus = (0.0, 1.5, fz)
        cam_set(self.cam, overhead(focus, 68, 34 + 5 * (-10.0 - fz) / 16), focus, 50)
        clones = sorted([a for a in acts if a["kind"] == "clone"], key=lambda a: a["slot"])
        tags = [(screen_full(self.s, self.cam, IS_rb(a["x"], 6.4, a["z"])), str(n_ + 1),
                 clone_hue(len(clones) - a["slot"], len(clones))) for n_, a in enumerate(clones)]
        tags.append((screen_full(self.s, self.cam, IS_rb(live["x"], 6.4, live["z"])), str(len(clones) + 1), CYAN))
        tv = i / FPS

        def over(img):
            img = vignette_crew(img, 0.3)
            for (x, y, _z), lab, hue in tags:
                if tv > 0.3 or lab == str(len(clones) + 1):
                    img = pill(img, (x, y), lab, hue, 0.045)
            img = label(img, "CREW VIEW", 0.075, 0.042)
            return stamp(img, "RUN 3", tv / 0.9, y=0.2, cap=0.085)
        return True, over


class GusShot(Shot):
    """L4 Night Clerk, run 3, 6.6-10.2 s into the run: you cross with the night deposit behind Gus while he patrols
    the back room, his torch cone sweeping (rebuilt from the sim each frame); he turns Suspicious ("?") and gives up."""

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        self.s, self.lv, doors, groups, items = build_level("cs4_night_clerk", self.samples)
        self.state = LevelState(self.lv, items)
        self.run = Run(sim_paths(4), 3)
        self.t0 = 7.0
        self.rigs = _level_rigs(self.lv, self.run, self.t0)
        g0 = self.run.guards(self.t0)[0]
        self.gus = Gus(self.lv, g0)
        self.cam = _cam(self.s, self.W, self.Hh)
        self.cpos = overhead((2.0, 1.5, -24.0), 58, 30, -15)
        LS.cut(self.lv["tower"], groups, self.cpos, [(0, 2, -28), (10, 2, -28), (0, 2, -40), (0, 2, -12)])
        LS._apply_fade(self.cpos)
        hide_lamps()
        # step the walk cycle from a moment earlier so the first frame is mid-stride
        for k in range(8, 0, -1):
            tt = self.t0 - k / FPS
            for a in self.run.actors(tt):
                self.rigs[a["id"]].drive(a["x"], a["z"], a["yaw"], carrying=bool(a.get("carrying")))
        self.bags = {aid: K.place("CashBag", (0, 0, 0), 0, (), True, self.lv["location"]) for aid in self.rigs}

    def frame(self, i):
        t = self.t0 + i / FPS
        acts = self.run.actors(t)
        _drive(self.rigs, acts, t)
        dr = self.run.doors(t)
        self.state.apply(dr, plates_held(self.lv, acts), loot_taken(self.run, t))
        carry(self.bags, self.rigs, acts, 0.9)
        g = self.run.guards(t)[0]
        self.gus.set(g, dr, t)
        k = ease(i / (3.0 * FPS))
        focus = lerp((5.0, 1.5, -27.0), (4.0, 1.5, -23.0), k)
        cam_set(self.cam, overhead(focus, 60, 28 - 3 * k, -12 + 8 * k), focus, 50)
        sus = g["mode"] != "Patrol"
        hx, hy, hz = screen_full(self.s, self.cam, self.gus.head() + _vec((0, 0, 2.0)))

        def over(img):
            if sus:
                img = pop(img, (hx, hy), "?", 0.055)
            return img
        return True, over


def _vec(v):
    from mathutils import Vector
    return Vector(v)


class Town(Shot):
    """The story stage (IntroPlan.STAGE via intro_shots): the toy town under the aurora, the camera craning up from
    the snowy street to Hoardsworth Tower and the Snow Globe Vault full of the town's presents; snow falling."""
    hazed = False

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        self.p0, self.p1 = (14.0, 3.0, 34.0), (10.0, 14.0, 40.0)
        self.s = T.town(self.samples, cam_pos=self.p0, snow_focus=(10, 10, 20))
        self.cam = _cam(self.s, self.W, self.Hh)
        self.snow = [o for o in bpy.data.objects if o.name == "Snow" or o.name.startswith("Snow.")]

    def frame(self, i):
        k = ease(i / (2.4 * FPS))
        pos = lerp(self.p0, self.p1, k)
        look = lerp((2.0, 10.0, -40.0), (-6.0, 60.0, -120.0), k)
        cam_set(self.cam, pos, look, 50)
        for o in self.snow:
            o.location.z = -2.5 * i / FPS
        return False, None


class Hideout(Shot):
    """The hideout (server Heist/Lobby from LobbyPlan, level_shots.garage_scene), first person at GOLDEN.G3's stand:
    a slow turn from the job board to your van, your Rookie hands, the reticle."""

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        import backdrop_shots as BS
        plan = LS.load_plan(True, False)
        g = plan["garage"]
        g["firstJob"] = plan["levels"][0]["name"].upper()
        s = MR.reset(self.samples)
        s.view_settings.exposure = 0.3
        lib = LS.Lib(g["location"])
        groups = LS.garage_scene(g, lib)
        BS.backdrop({"backdrop": g["backdrop"], "backdropConfig": g["backdropConfig"], "kit": [],
                     "location": g["location"], "lighting": g["lighting"]}, lib, LS.put, LS.soft_pool_mat)
        LS.lighting(s)
        BS.world_sky(s, LS.TMP)
        self.s = s
        self.cam = _cam(s, self.W, self.Hh)
        self.eye0 = (22.0, 3.8, -8.0)
        LS.cut(g["tower"], groups, self.eye0, [])
        self.hands = _fp_hands(self.cam)

    def frame(self, i):
        k = ease(i / (2.2 * FPS))
        eye = lerp(self.eye0, (22.5, 3.8, -11.5), k)
        look = lerp((14.0, 4.6, -20.0), (25.0, 3.4, -22.0), k)
        cam_set(self.cam, eye, look, 70)
        return True, reticle


class Party(Shot):
    """L5 Clone Party, run 8, 13.4-17.4 s in: you and seven clones crossing the party floor, most of them hauling loot
    back toward the van, Gus on patrol; a slow orbiting crane (the diorama camera's pitch)."""

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        import level_shots as LS
        import backdrop_shots as BS
        self.s, self.lv, doors, groups, items = build_level("cs5_clone_party", self.samples)
        self.state = LevelState(self.lv, items)
        self.run = Run(sim_paths(5), 8)
        self.t0 = 13.4
        self.rigs = _level_rigs(self.lv, self.run, self.t0)
        gs = self.run.guards(self.t0)
        self.gus = Gus(self.lv, gs[0]) if gs else None
        self.cam = _cam(self.s, self.W, self.Hh)
        self.cpos = overhead((0.0, 1.5, -4.0), 60, 32, 12)
        LS.cut(self.lv["tower"], groups, self.cpos, [(0, 2, 10), (0, 2, -10), (0, 2, -20), (10, 2, -8), (-10, 2, -8)])
        hide_lamps()
        LS._apply_fade(self.cpos)
        self.snow = BS.snowfall((0, 0, 8), self.lv["backdropConfig"], self.cpos)
        self.loot_objs = {}
        for k in range(8, 0, -1):
            tt = self.t0 - k / FPS
            for a in self.run.actors(tt):
                self.rigs[a["id"]].drive(a["x"], a["z"], a["yaw"], carrying=bool(a.get("carrying")))
        self.bags = {aid: K.place("Present", (0, 0, 0), 0, (), True, self.lv["location"]) for aid in self.rigs}

    def frame(self, i):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        t = self.t0 + i / FPS
        acts = self.run.actors(t)
        _drive(self.rigs, acts, t)
        dr = self.run.doors(t)
        self.state.apply(dr, plates_held(self.lv, acts), loot_taken(self.run, t))
        if self.gus:
            self.gus.set(self.run.guards(t)[0], dr, t)
        carry(self.bags, self.rigs, acts, 0.7)
        k = i / (4.0 * FPS)
        focus = (0.0, 1.5, -2.0 - 4 * k)
        cam_set(self.cam, overhead(focus, 60, 33 - 3 * k, 14 - 22 * k), focus, 48)
        self.snow.location.z = -2.5 * i / FPS
        return True, None


class Title(Shot):
    """The end card: the Rookie and three clones of him on the snowy street under the aurora (the town stage), a slow
    push in, then the HEIST YOURSELF wordmark smashes in (Luckiest Guy, the cyan double-exposure copy) with the
    subtitle Rob With Your Clones. No call to action, no claims."""
    hazed = False

    def build(self):
        bpy, Matrix, Vector, MR, K, IS, T = _bl()
        self.p0, self.p1 = (7.0, 3.6, 31.0), (6.4, 3.8, 28.0)
        self.s = T.town(self.samples, cam_pos=self.p0, snow_focus=(4, 8, 18))
        self.cam = _cam(self.s, self.W, self.Hh)
        look_up = {"Neck": (18, 0, 0), "RightShoulder": (6, 0, -10), "LeftShoulder": (6, 0, 10), "Waist": (4, 0, 0)}
        self.hero = Rig()
        self.hero.set((4.6, 0.0, 19.5), 180 + 8, {"Neck": (4, -12, 4), "RightShoulder": (8, 0, -14),
                                                  "LeftShoulder": (8, 0, 14)})
        spots = ((1.2, 17.0, 176), (8.2, 16.6, 190), (-1.6, 14.0, 172))
        self.clones = []
        for k, (x, z, yaw) in enumerate(spots):
            r = Rig(clone_hue=clone_hue(k, 3))
            r.set((x, 0.0, z), yaw, look_up if k == 2 else {"Neck": (4, 10, 0)})
            self.clones.append(r)
        hp = self.hero.objs[0].matrix_world.translation
        T.key_light(IS.rb(4.6, 4.2, 19.5), IS.rb(4.6, 4.2, 19.5) + Vector((-6.0, 6.0, 5.0)), power=1600, spot=26)
        self.snow = [o for o in bpy.data.objects if o.name == "Snow" or o.name.startswith("Snow.")]

    def frame(self, i):
        t = i / FPS
        k = ease(t / 4.0)
        pos = lerp(self.p0, self.p1, k)
        cam_set(self.cam, pos, lerp((3.6, 5.2, 10.0), (3.6, 5.6, 10.0), k), 50)
        for o in self.snow:
            o.location.z = -2.5 * t
        return False, lambda img: wordmark(img, t - 0.5)


def wordmark(img, t):
    """HEIST YOURSELF: drops in at 1.25x and settles (0.3 s), the cyan double-exposure copy offset behind it, the
    subtitle fades in under it; upper-middle (clear of the bottom 20 %)."""
    from PIL import Image, ImageDraw, ImageFilter
    if t < 0:
        return img
    W, Hh = img.size
    x = min(1.0, t / 0.3)
    c1 = 1.70158
    sc = 1.3 - 0.3 * (1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2)
    a = min(1.0, t / 0.12)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    size = int(Hh * 0.15 * sc)
    f = _font(size)
    stroke = max(6, int(size * 0.08))
    cy = Hh * 0.27
    for line, yy in (("HEIST", cy - size * 0.52), ("YOURSELF", cy + size * 0.52)):
        off = Hh * 0.012
        d.text((W / 2 + off, yy + off), line, font=f, fill=(61, 232, 255, int(150 * a)), anchor="mm")
        d.text((W / 2, yy), line, font=f, fill=(244, 247, 255, int(255 * a)), anchor="mm", stroke_width=stroke,
               stroke_fill=(28, 31, 59, int(255 * a)))
    shadow = layer.filter(ImageFilter.GaussianBlur(Hh * 0.01))
    img = Image.alpha_composite(img, Image.eval(shadow, lambda v: v // 3))
    img = Image.alpha_composite(img, layer)
    if t > 0.45:
        sa = min(1.0, (t - 0.45) / 0.3)
        sub = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(sub).text((W / 2, cy + size * 1.32), "ROB WITH YOUR CLONES", font=_font(Hh * 0.05),
                                 fill=(255, 230, 156, int(255 * sa)), anchor="mm", stroke_width=max(3, int(Hh * 0.005)),
                                 stroke_fill=(28, 31, 59, int(255 * sa)))
        img = Image.alpha_composite(img, sub)
    return img


BUILDERS = {"hook": Hook, "eight": Eight, "run1": Run1, "crew": Crew, "gus": GusShot, "town": Town,
            "hideout": Hideout, "party": Party, "title": Title}


def fast(s):
    """The render budget on a CPU-only box (Eevee through software GL): shadow maps only from the sun (the lamps'
    spot shadows cost ~10x a frame), half-res shadow maps, no screen-space ray tracing. Measured on L1: 46 s ->
    6.6 s a frame at 1280 x 720 for a near-identical picture (the lamps still light; their pools lose soft edges)."""
    import bpy
    for o in bpy.data.objects:
        if o.type == "LIGHT" and o.data.type != "SUN":
            o.data.use_shadow = False
    e = s.eevee
    e.shadow_resolution_scale = 0.5
    e.shadow_ray_count = 1
    e.shadow_step_count = 4
    e.use_raytracing = False


def render_shot(name, f0, f1, scale, samples, only=None, out_dir=None):
    out_dir = out_dir or frame_dir(name)
    os.makedirs(out_dir, exist_ok=True)
    n = nframes(name)
    f1 = min(f1, n)
    want = [i for i in range(f0, f1) if only is None or i in only]
    todo = [i for i in want if not os.path.isfile(os.path.join(out_dir, f"{i:04d}.png"))]
    if not todo:
        print("store_video:", name, "frames", f0, f1, "already on disk")
        return
    W, Hh = int(W_FULL * scale), int(H_FULL * scale)
    samples = SAMPLES.get(name, samples)
    sh = BUILDERS[name](W, Hh, samples)
    t0 = time.time()
    sh.build()
    s = sh.s
    s.render.resolution_x, s.render.resolution_y = W, Hh
    s.render.resolution_percentage = 100
    s.eevee.taa_render_samples = samples
    fast(s)
    print(f"store_video: {name} built in {time.time() - t0:.1f} s", flush=True)
    for i in range(0, todo[-1] + 1):    # every earlier frame is posed too (the walk cycle's phase), only todo renders
        hazed, over = sh.frame(i)
        if i not in todo:
            continue
        tf = time.time()
        out = os.path.join(out_dir, f"{i:04d}.png")
        render_frame(s, sh.cam, out, hazed and sh.hazed and name in HAZED, over, sh.vignette)
        print(f"store_video: {name} {i + 1}/{n} {time.time() - tf:.1f} s", flush=True)


def render_chunks(names, scale, samples, chunk):
    """Each shot in chunks of `chunk` frames, one Blender process each (bpy crashes after ~10-20 Eevee renders in one
    process on this box); a crashed chunk is simply run again: frames on disk are skipped."""
    for n in names:
        tries = 0
        while True:
            have = set(os.listdir(frame_dir(n))) if os.path.isdir(frame_dir(n)) else set()
            missing = [i for i in range(nframes(n)) if f"{i:04d}.png" not in have]
            if not missing:
                break
            tries += 1
            if tries > 60:
                raise SystemExit(f"{n}: giving up, {len(missing)} frames missing")
            f0 = missing[0]
            subprocess.run([sys.executable, __file__, "--shot", n, "--from", str(f0), "--to", str(f0 + chunk),
                            "--scale", str(scale), "--samples", str(samples)])


# ------------------------------------------------------------------ the rewind shot (2D, from run1's frames)
def rewind_frames():
    """REWIND as RewindDirector plays it (Standard, compressed to 1.2 s): the white flash, the scrub (run 1's frames
    backwards, saturation -0.8, cyan tint, blur, scanline bands, the VHS tracking line, "REWIND"), the snap back."""
    import numpy as np
    from PIL import Image, ImageFilter
    src = sorted(os.listdir(frame_dir("run1")))
    out_dir = frame_dir("rewind")
    os.makedirs(out_dir, exist_ok=True)
    n = nframes("rewind")
    for i in range(n):
        tv = i / FPS
        k = i / (n - 1)
        j = int(round((1 - min(1.0, k / 0.85)) * (len(src) - 1)))
        img = Image.open(os.path.join(frame_dir("run1"), src[j])).convert("RGB")
        a = np.asarray(img).astype(np.float32) / 255.0
        if k < 0.85:
            g = (a * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(axis=2, keepdims=True)
            a = g + (a - g) * 0.2
            a = a * np.array([0.82, 0.95, 1.08], np.float32)
            im2 = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
            a = np.asarray(im2).astype(np.float32) / 255.0
            Hh, W = a.shape[:2]
            yy = np.arange(Hh, dtype=np.float32)[:, None]
            bands = 0.5 + 0.5 * np.sin((yy / Hh * 9 + tv * 0.35 * 9 * 3) * 2 * math.pi)
            a = a * (1 - 0.14 * bands[..., None])
            a[(np.arange(Hh) % 4 == 0)] *= 0.88
            ty = int((tv / 0.55 % 1) * Hh)
            a[max(0, ty - 5):ty, :] = np.roll(a[max(0, ty - 5):ty, :], 6, axis=1) * 1.15
        if tv < 0.1:
            a = a * 0.75 + 0.25
        img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
        if k < 0.85:
            img = stamp(img, "REWIND", min(0.84, tv / 0.9), y=0.5, cap=0.12, fill=WHITE)
        img = stamp(img, "RUN 2", (k - 0.84) / 0.5, y=0.2, cap=0.085) if k >= 0.84 else img
        img.convert("RGB").save(os.path.join(out_dir, f"{i:04d}.png"), compress_level=1)
    print("store_video: rewind", n, "frames")


# ------------------------------------------------------------------ the edit
def edit():
    """Concatenate the shots (hard cuts) -> H.264 1920x1080 30 fps yuv420p, no audio; the poster frame; frames.png."""
    from PIL import Image, ImageDraw
    os.makedirs(OUT, exist_ok=True)
    seq = os.path.join(BUILD, "seq")
    os.makedirs(seq, exist_ok=True)
    for f in os.listdir(seq):
        os.remove(os.path.join(seq, f))
    k = 0
    for name, _d, _txt in SHOTS:
        files = sorted(os.listdir(frame_dir(name)))[:nframes(name)]
        assert len(files) == nframes(name), f"{name}: {len(files)} of {nframes(name)} frames"
        for f in files:
            os.symlink(os.path.join(frame_dir(name), f), os.path.join(seq, f"{k:05d}.png"))
            k += 1
    mp4 = os.path.join(OUT, "experience_video.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(seq, "%05d.png"),
                    "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-profile:v", "high", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", "-an", "-r", str(FPS), mp4], check=True)
    print("store_video:", os.path.relpath(mp4, REPO), k, "frames", f"{k / FPS:.2f} s",
          f"{os.path.getsize(mp4) / 1e6:.1f} MB")
    # the poster: the 8 OF ME beat
    e0 = sum(nframes(n) for n, _d, _t in SHOTS[:1])
    poster = Image.open(os.path.join(seq, f"{e0 + int(2.7 * FPS):05d}.png")).convert("RGB")
    poster.save(os.path.join(OUT, "poster_1920x1080.png"), optimize=True)
    # the contact sheet: 0, 1, 3, 10, 20, 28 s, each with the 9:16 crop and a 360 px phone view
    times = (0, 1, 3, 10, 20, 28)
    tw, th = 640, 360
    sheet = Image.new("RGB", (tw * 3 + 40, (th + 40) * 2 + 60), (20, 22, 40))
    d = ImageDraw.Draw(sheet)
    d.text((20, 18), "experience_video.mp4: frames at 0 / 1 / 3 / 10 / 20 / 28 s (dashed: the 9:16 centre crop)",
           fill=(244, 247, 255), font=_font(22))
    for n_, ts in enumerate(times):
        fi = min(k - 1, int(ts * FPS))
        im = Image.open(os.path.join(seq, f"{fi:05d}.png")).convert("RGB").resize((tw, th), Image.LANCZOS)
        x0, y0 = 10 + (n_ % 3) * (tw + 10), 60 + (n_ // 3) * (th + 40)
        sheet.paste(im, (x0, y0))
        cx0, cx1 = x0 + int(656 / 1920 * tw), x0 + int(1264 / 1920 * tw)
        for yy in range(y0, y0 + th, 12):
            d.line([(cx0, yy), (cx0, yy + 6)], fill=(255, 79, 216), width=2)
            d.line([(cx1, yy), (cx1, yy + 6)], fill=(255, 79, 216), width=2)
        d.text((x0 + 8, y0 + th + 6), f"{ts} s  ({shot_at(fi)})", fill=(244, 247, 255), font=_font(20))
    sheet.save(os.path.join(OUT, "frames.png"), optimize=True)
    phone = Image.new("RGB", (360 * 3 + 40, 203 * 2 + 30), (20, 22, 40))
    for n_, ts in enumerate(times):
        fi = min(k - 1, int(ts * FPS))
        im = Image.open(os.path.join(seq, f"{fi:05d}.png")).convert("RGB").resize((360, 203), Image.LANCZOS)
        phone.paste(im, (10 + (n_ % 3) * 370, 10 + (n_ // 3) * 213))
    phone.save(os.path.join(BUILD, "phone_360.png"))
    crops = Image.new("RGB", (203 * 6 + 70, 360 + 20), (20, 22, 40))
    for n_, ts in enumerate(times):
        fi = min(k - 1, int(ts * FPS))
        im = Image.open(os.path.join(seq, f"{fi:05d}.png")).convert("RGB").crop((656, 0, 1264, 1080))
        crops.paste(im.resize((203, 360), Image.LANCZOS), (10 + n_ * 213, 10))
    crops.save(os.path.join(BUILD, "crop_9x16.png"))


def shot_at(fi):
    k = 0
    for name, _d, _t in SHOTS:
        if fi < k + nframes(name):
            return name
        k += nframes(name)
    return SHOTS[-1][0]


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot")
    ap.add_argument("--from", dest="f0", type=int, default=0)
    ap.add_argument("--to", dest="f1", type=int, default=10 ** 6)
    ap.add_argument("--scale", type=float, default=2 / 3)
    ap.add_argument("--samples", type=int, default=2, help="Eevee samples (SAMPLES overrides per shot)")
    ap.add_argument("--chunk", type=int, default=8)
    ap.add_argument("--only", help="comma-separated frame numbers (with --shot)")
    ap.add_argument("--out", help="frame directory (with --shot; default build/video/frames/<shot>)")
    ap.add_argument("--preview", help="comma-separated shots: four draft frames each")
    ap.add_argument("--shots", help="comma-separated shots to render in full (chunked)")
    ap.add_argument("--render-all", action="store_true")
    ap.add_argument("--rewind", action="store_true")
    ap.add_argument("--edit", action="store_true")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args(argv)
    if a.list:
        t = 0.0
        for n, d, txt in SHOTS:
            print(f"{t:5.1f}-{t + d:5.1f}  {n:8s} {txt}")
            t += d
        return
    if a.preview:   # a few frames of each named shot at draft quality: build/video/preview/<shot>/
        for n in a.preview.split(","):
            idx = [int(round(k * (nframes(n) - 1))) for k in (0.0, 0.33, 0.66, 1.0)]
            subprocess.run([sys.executable, __file__, "--shot", n, "--only", ",".join(map(str, idx)), "--scale",
                            str(a.scale), "--samples", str(a.samples), "--out", os.path.join(BUILD, "preview", n)])
        return
    if a.shot:
        only = {int(x) for x in a.only.split(",")} if a.only else None
        render_shot(a.shot, a.f0, a.f1, a.scale, a.samples, only, a.out)
    if a.render_all or a.shots:
        render_chunks(a.shots.split(",") if a.shots else [n for n, _d, _t in SHOTS if n != "rewind"], a.scale,
                      a.samples, a.chunk)
    if a.rewind or a.render_all:
        rewind_frames()
    if a.edit:
        edit()


if __name__ == "__main__":
    main(sys.argv[1:])
