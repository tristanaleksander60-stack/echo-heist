"""The Rookie's animation contact sheet (REVIEW_STEAM_PLUS #6 and #10): key poses of the locomotion clips and the
first-person hand poses, rendered from the data the game plays.

    lune run tools/rookie_clips.luau build/rookie_clips            # the clip samples (poses.json, forward kinematics)
    lune run tools/hand_poses.luau build/hand_poses.json           # the viewmodel hand poses (Heist/ViewmodelMath)
    python3 tools/blender/rookie_anim.py [--size 260] [--samples 16]

Writes docs/art/rookie_anim.png:
  row 1  walk (side): right contact, passing, left contact, passing; + 3/4 front at passing (arms wide, chest turn)
  row 2  run (side): contact, mid-stance, toe-off, flight; + 3/4 front (pumps, lean)
  row 3  idle, look (the idle variant), jump, fall, land (squash)
  row 4  first-person hands: open, grip, push, point, press, hands-up (the kit hand pieces, posed by the same table)
Each body part of the real kit FBX (assets/fbx/Rookie*.fbx, dressed like rookie_sheet.py's look 1) is moved by its
forward-kinematics transform from poses.json (Shared/Heist/RookieMoves via tools/rookie_clips.luau): the same numbers
the baked KeyframeSequences carry. A thin line marks the floor. Evidence rung R0 (offline render), not a Studio capture.
"""
import argparse, json, math, os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import kit_preview as K  # noqa: E402
import rookie_sheet as RS  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "art", "rookie_anim.png")
POSES = os.path.join(REPO, "build", "rookie_clips", "poses.json")
HANDS = os.path.join(REPO, "build", "hand_poses.json")
MAN = RS.MAN
BODY = ["LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm",
        "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg",
        "LeftFoot"]
# Roblox (x, y, z) -> Blender (-x, z, y)
P = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def part_of(obj_name):
    base = obj_name.split(".")[0]
    if base.startswith("Rookie_") and base[7:] in BODY:
        return base[7:]
    a = MAN.get(base, {}).get("attach")
    if a:
        return a["part"]
    if base == "Stripe":
        return None
    return None


def frame_at(clip, t, data):
    frames = data[clip]["frames"]
    return min(frames, key=lambda f: abs(f["t"] - t))


def posed_rookie(clip, t, data, crew="#3DE8FF"):
    objs = RS.rookie(RS.LOOKS[0], crew, (0, 0, 0))
    fk = frame_at(clip, t, data)["fk"]
    for o in objs:
        part = part_of(o.name)
        x = fk.get(part) if part else None
        if not x:
            continue
        m = x["m"]
        R = Matrix(((m[0], m[1], m[2]), (m[3], m[4], m[5]), (m[6], m[7], m[8])))
        Rb = P @ R @ P.transposed()
        tb = P @ Vector(x["t"])
        M = Matrix.Translation(tb) @ Rb.to_4x4()
        o.matrix_world = M @ o.matrix_world
    floor_line()
    return objs


def floor_line():
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.004))
    o = bpy.context.active_object
    o.scale = (0.02, 8, 0.008)
    o.data.materials.append(K._mat("EH_FloorLine", K._lin("#8C96FF")))


def render(path, size, samples, build, target, az, el, dist, vfov):
    RS.render(path, size, samples, build, target, az, el, dist, vfov)


def hand_tile(name, hands):
    """Both first-person hands in a pose, built from the kit hand pieces (Rookie_Hands) by their hinges."""
    spec = hands[name]
    for side, s in (("Right", "R"), ("Left", "L")):
        for piece in spec[side]:
            m = piece["cf"]                 # grip-space CFrame of the piece (Roblox), from ViewmodelMath
            R = Matrix(((m[3], m[4], m[5]), (m[6], m[7], m[8]), (m[9], m[10], m[11])))
            M = Matrix.Translation(P @ Vector(m[0:3])) @ (P @ R @ P.transposed()).to_4x4()
            objs = K.place("Rookie_Hands", (0, 0, 0), 0, ["only:" + piece["name"], "origin",
                                                          "tint:" + piece.get("tint", "#2A2D52")], False, "CornerShop")
            for o in objs:
                o.matrix_world = M @ o.matrix_world


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=260)
    ap.add_argument("--samples", type=int, default=16)
    a = ap.parse_args(argv)
    data = json.load(open(POSES))
    tmp = os.path.join(tempfile.gettempdir(), "eh_rookie_anim")
    os.makedirs(tmp, exist_ok=True)
    L = data["walk"]["length"]
    side = (0, 0, 2.2), -90, 6, 9.0, 34
    front = (0, 0, 2.2), -32, 10, 9.0, 34
    rows = []

    def shots(spec):
        out = []
        for i, (label, clip, t, view) in enumerate(spec):
            p = os.path.join(tmp, f"{clip}_{i}_{len(rows)}.png")
            render(p, a.size, a.samples, lambda c=clip, tt=t: posed_rookie(c, tt, data), *view)
            out.append((p, label))
        return out

    run_d = 0.27   # Config.Rookie.ANIM.RUN.duty
    rows.append(("walk: the caper (side, then 3/4 front)", shots([
        ("walk: R contact", "walk", 0.0, side), ("walk: passing", "walk", 0.25 * L, side),
        ("walk: L contact", "walk", 0.5 * L, side), ("walk: toe roll", "walk", 0.4 * L, side),
        ("walk 3/4", "walk", 0.25 * L, front)])))
    rows.append(("run: the funny sprint (side, then 3/4 front)", shots([
        ("run: contact", "run", 0.0, side), ("run: mid-stance", "run", run_d / 2 * L, side),
        ("run: toe-off", "run", run_d * L, side), ("run: flight", "run", 0.38 * L, side),
        ("run 3/4", "run", 0.62 * L, front)])))
    rows.append(("idle, look, jump, fall, land", shots([
        ("idle", "idle", 0.8, front), ("look (idle variant)", "look", 1.2, front),
        ("jump", "jump", 0.3, front), ("fall", "fall", 0.12, front), ("land: squash", "land", 0.08, front)])))
    if os.path.isfile(HANDS):
        hands = json.load(open(HANDS))
        out = []
        for i, name in enumerate(hands["order"]):
            p = os.path.join(tmp, f"hand_{i}.png")
            render(p, a.size, a.samples, lambda n=name: hand_tile(n, hands), (0, -1.6, 0.0), 0, 0, 3.4, 40)
            out.append((p, "hands: " + name))
        rows.append(("first-person hands (Rookie_Hands kit pieces, posed by Config.FirstPerson.VIEWMODEL.HANDS)", out))
    print(sheet(rows, a.size, OUT))


def sheet(rows, size, path):
    from PIL import Image, ImageDraw, ImageFont
    fp = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font = ImageFont.truetype(fp, 13) if os.path.isfile(fp) else ImageFont.load_default()
    cols = max(len(r[1]) for r in rows)
    head, gap = 28, 20
    W = cols * size
    H = head + len(rows) * (gap + size)
    img = Image.new("RGB", (W, H), (24, 25, 36))
    dr = ImageDraw.Draw(img)
    dr.text((8, 7), "The Rookie in motion: rendered from the baked clip data (RookieMoves) and the hand-pose table",
            fill=(230, 232, 245), font=font)
    y = head
    for title, tiles in rows:
        dr.text((8, y + 3), title, fill=(200, 204, 225), font=font)
        y += gap
        for i, (p, label) in enumerate(tiles):
            im = Image.open(p).convert("RGB")
            x = i * size
            img.paste(im.resize((size, size)), (x, y))
            dr.rectangle([x, y, x + 8 + 7 * len(label), y + 19], fill=(24, 25, 36))
            dr.text((x + 4, y + 2), label, fill=(230, 232, 245), font=font)
        y += size
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)
    return path


if __name__ == "__main__":
    main(sys.argv[1:])
