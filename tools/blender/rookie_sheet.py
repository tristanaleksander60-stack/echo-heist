"""The Rookie outfit sheet: whole Rookies assembled from the exported FBX files (assets/fbx/Rookie*.fbx, exactly as
the game loads them) the way Heist/Rookie assembles them (outfit pieces placed by their manifest `attach` point), in
the four crew colours, rendered in Blender.

    python3 tools/blender/rookie_sheet.py [--size 300] [--samples 16]

Writes docs/art/rookie_sheet.png:
  row 1  four looks (one per crew seat, every outfit variant used at least once) + the back of look 1 (the scarf tail)
  row 2  the same frames with the Rookie 48 px tall, shown 3x with nearest-neighbour (PLAN_STEAM_PLUS A4: 48 px read)
  row 3  the four faces (idle, smug, shocked, busted) close up
Lights are kit_preview's Heist Night approximation, the floor the runtime floor colour. Evidence rung R0 (offline
render of the real meshes), not a Studio capture. Colours: crew = Palette.CLONE_HUES, gloves = Config.Rookie.GLOVES.
"""
import argparse, json, os, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import kit_preview as K  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "art", "rookie_sheet.png")
MAN = json.load(open(os.path.join(REPO, "assets", "fbx", "kit_manifest.json")))["parts"]

CREW = ["#3DE8FF", "#FF4FD8", "#6A5CFF", "#F4F7FF"]           # Palette.CLONE_HUES (seats 1-4)
GLOVES = {"Knit": "#2A2D52", "Leather": "#6E4B3A"}             # Config.Rookie.GLOVES colours
LOOKS = [
    {"cap": "Flat", "scarf": "Long", "sweater": "Stripes", "gloves": "Knit", "mask": None, "face": "Idle"},
    {"cap": "Beanie", "scarf": "Chunky", "sweater": "Block", "gloves": "Leather", "mask": "Eye", "face": "Smug"},
    {"cap": "Bobble", "scarf": "Bandana", "sweater": "Stripes", "gloves": "Knit", "mask": None, "face": "Shocked"},
    {"cap": "Trapper", "scarf": "Knot", "sweater": "Block", "gloves": "Leather", "mask": "Eye", "face": "Busted"},
]
SWEATER = {"Stripes": ["Rookie_Stripes_Torso", "Rookie_Stripes_RightArm", "Rookie_Stripes_LeftArm"],
           "Block": ["Rookie_Block_Torso", "Rookie_Block_RightCuff", "Rookie_Block_LeftCuff"]}


def blender_point(name):
    """Where a piece's pivot goes on the rest body (Blender coordinates): its body part's pivot + the attach offset."""
    a = MAN[name]["attach"]
    o = MAN["Rookie_" + a["part"]]["origin"]
    x, y, z = (o[i] + a["offset"][i] for i in range(3))
    return Vector((-x, z, y))     # Roblox (x, y, z) -> Blender (-x, z, y)


def put(model, name, at, tint=None):
    flags = ["only:" + name, "origin"] + (["tint:" + tint] if tint else [])
    return K.place(model, tuple(at), 0, flags, False, "CornerShop")


def rookie(look, crew, at):
    at = Vector(at)
    hide = ["hide:Rookie_LeftHand", "hide:Rookie_RightHand"] + ([] if look["face"] == "Idle" else ["hide:Rookie_Face_Idle"])
    objs = K.place("Rookie", tuple(at), 0, hide, False, "CornerShop")
    glove = GLOVES[look["gloves"]]
    for side in ("Left", "Right"):
        objs += K.place("Rookie", tuple(at), 0, ["only:Rookie_" + side + "Hand", "tint:" + glove], False, "CornerShop")
        cuff = f"Rookie_Gloves_{look['gloves']}_{side}"
        objs += put("Rookie_Outfits", cuff, at + blender_point(cuff), glove)
    if look["face"] != "Idle":
        n = "Rookie_Face_" + look["face"]
        objs += put("Rookie_Faces", n, at + blender_point(n))
    cap = "Rookie_Cap_" + look["cap"]
    objs += put("Rookie_Outfits", cap, at + blender_point(cap))
    sc = "Rookie_Scarf_" + look["scarf"]
    objs += put("Rookie_Outfits", sc, at + blender_point(sc), crew)
    for n in SWEATER[look["sweater"]]:
        objs += put("Rookie_Outfits", n, at + blender_point(n), crew)
    if look["mask"]:
        n = "Rookie_Mask_" + look["mask"]
        objs += put("Rookie_Outfits", n, at + blender_point(n))
    return objs


def render(path, size, samples, build, target, az, el, dist, vfov):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    K._ATLAS.clear()
    s = bpy.context.scene
    s.world = bpy.data.worlds.new("EH_World")
    s.view_settings.view_transform = "Standard"
    s.render.engine = "BLENDER_EEVEE"
    s.eevee.taa_render_samples = samples
    s.render.resolution_x = s.render.resolution_y = size
    build()
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    fl = bpy.context.active_object
    fl.data.materials.append(K._mat("EH_Floor", K._lin("#3A365C")))
    K.lights(s, target, False)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    s.camera = cam
    K.aim(cam, target, az, el, dist, vfov)
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


def sheet(rows, size, path):
    from PIL import Image, ImageDraw, ImageFont
    fp = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font = ImageFont.truetype(fp, 14) if os.path.isfile(fp) else ImageFont.load_default()
    looks, faces = rows
    cols = max(len(looks), len(faces))
    # the Rookie spans about 66 % of a look tile's height: scale so he is 48 px tall, then show 3x
    small = max(8, round(48 / 0.66))
    big = small * 3
    head = 30
    W = cols * size
    H = head + size + 22 + big + 22 + size
    img = Image.new("RGB", (W, H), (24, 25, 36))
    dr = ImageDraw.Draw(img)
    dr.text((8, 7), "The Rookie: crew seats 1-4 (scarf + sweater stripes), outfit slots, faces. Row 2: 48 px, shown 3x",
            fill=(230, 232, 245), font=font)
    for i, (p, label) in enumerate(looks):
        im = Image.open(p).convert("RGB")
        x = i * size
        img.paste(im.resize((size, size)), (x, head))
        dr.rectangle([x, head, x + 8 + 7 * len(label), head + 20], fill=(24, 25, 36))
        dr.text((x + 4, head + 2), label, fill=(230, 232, 245), font=font)
        lo = im.resize((small, small), Image.Resampling.LANCZOS).resize((big, big), Image.Resampling.NEAREST)
        img.paste(lo, (x + (size - big) // 2, head + size + 22))
    dr.text((8, head + size + 3), "at 48 px (one look per column)", fill=(200, 204, 225), font=font)
    y3 = head + size + 22 + big + 22
    dr.text((8, y3 - 19), "faces (one shows at a time; swapped by state)", fill=(200, 204, 225), font=font)
    for i, (p, label) in enumerate(faces):
        im = Image.open(p).convert("RGB")
        x = i * size
        img.paste(im.resize((size, size)), (x, y3))
        dr.rectangle([x, y3, x + 8 + 7 * len(label), y3 + 20], fill=(24, 25, 36))
        dr.text((x + 4, y3 + 2), label, fill=(230, 232, 245), font=font)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)
    return path


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=300)
    ap.add_argument("--samples", type=int, default=16)
    a = ap.parse_args(argv)
    tmp = os.path.join(tempfile.gettempdir(), "eh_rookie_sheet")
    os.makedirs(tmp, exist_ok=True)
    looks = []
    for i, look in enumerate(LOOKS):
        p = os.path.join(tmp, f"look_{i}.png")
        render(p, a.size, a.samples, lambda look=look, i=i: rookie(look, CREW[i], (0, 0, 0)), (0, 0, 2.5), -28, 14, 9.5, 34)
        label = f"P{i + 1} {look['cap']} / {look['scarf']} / {look['sweater']}"
        looks.append((p, label))
    p = os.path.join(tmp, "look_back.png")
    render(p, a.size, a.samples, lambda: rookie(LOOKS[0], CREW[0], (0, 0, 0)), (0, 0, 2.5), 150, 14, 9.5, 34)
    looks.append((p, "P1 from behind"))
    faces = []
    for i, f in enumerate(("Idle", "Smug", "Shocked", "Busted")):
        p = os.path.join(tmp, f"face_{i}.png")
        look = dict(LOOKS[0], face=f)
        render(p, a.size, a.samples, lambda look=look: rookie(look, CREW[0], (0, 0, 0)), (0, -0.6, 3.75), -12, 6, 5.5, 30)
        faces.append((p, f.lower()))
    print(sheet((looks, faces), a.size, OUT))


if __name__ == "__main__":
    main(sys.argv[1:])
