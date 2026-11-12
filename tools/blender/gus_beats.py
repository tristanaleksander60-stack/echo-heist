"""Gus beat contact sheet: the 18-part kit Gus (assets/fbx/Gus.fbx, exactly as exported) posed by the GAME's own beat
code (Shared/Heist/GusBeats + the Heist/GusRig FK, via tools/blender/gus_poses.luau), rendered in Blender.

    python3 tools/blender/gus_beats.py [--size 300] [--samples 16]

Writes docs/art/gus_beats.png: row 1 each key pose at review size from the diorama camera (STYLE_BIBLE 7 B1-like, 3/4
from the front-left, 40 deg down); row 2 the same frames with Gus 48 px tall (PLAN_STEAM_PLUS A4: every beat must read
at 48 px on a 360 dp phone), shown 3x with nearest-neighbour so the pixels are visible. Not drawn (2D / code effects
in game): the "?" / "!" / "zz" bubbles, the cone, boot prints, dust. The floor is the runtime floor colour; lights
are kit_preview's Heist Night approximation. Evidence rung R0 (offline render of the real mesh and the real pose code),
not a Studio capture.
"""
import argparse, json, math, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import kit_preview as K  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "art", "gus_beats.png")
# Roblox (x, y, z), Y up, facing -Z  ->  Blender (-x, z, y), Z up, facing -Y (assets/blender/gus.py). Its own inverse.
C = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def poses():
    res = subprocess.run(["lune", "run", "tools/blender/gus_poses.luau"], cwd=REPO, capture_output=True, text=True, check=True)
    return json.loads(res.stdout)


def roblox_matrix(c):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
    return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def render_tile(shot, size, samples, path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    K._ATLAS.clear()
    s = bpy.context.scene
    s.world = bpy.data.worlds.new("EH_World")
    s.view_settings.view_transform = "Standard"
    s.render.engine = "BLENDER_EEVEE"
    s.eevee.taa_render_samples = samples
    s.render.resolution_x = s.render.resolution_y = size
    objs = K.place("Gus", (0, 0, 0), 0, (), False, "CornerShop")
    rest = {o.name.split(".")[0]: o.matrix_world.copy() for o in objs}
    for o in objs:
        mv = shot["moves"].get(o.name.split(".")[0])
        if mv:
            o.matrix_world = C @ roblox_matrix(mv) @ C @ rest[o.name.split(".")[0]]
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    fl = bpy.context.active_object
    m = K._mat("EH_Floor", K._lin("#3A365C"))
    fl.data.materials.append(m)
    target = (0, 0, 3.0)
    K.lights(s, target, False)
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    s.camera = cam
    K.aim(cam, target, -30, 32, 15, 34)
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


def sheet(tiles, size, path):
    from PIL import Image, ImageDraw, ImageFont
    fp = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font = ImageFont.truetype(fp, 14) if os.path.isfile(fp) else ImageFont.load_default()
    cols = len(tiles)
    # Gus spans about 62 % of the tile height in this framing: scale so he is 48 px tall, then show 3x.
    small = max(8, round(size * 48 / (size * 0.62)))
    big = small * 3
    head = 30
    W = cols * size
    H = head + size + 22 + big
    img = Image.new("RGB", (W, H), (24, 25, 36))
    dr = ImageDraw.Draw(img)
    dr.text((8, 7), "Gus beats (kit mesh posed by GusBeats + GusRig FK). Row 2: Gus at 48 px, shown 3x", fill=(230, 232, 245), font=font)
    for i, (p, label) in enumerate(tiles):
        im = Image.open(p).convert("RGB")
        x = i * size
        img.paste(im.resize((size, size)), (x, head))
        dr.rectangle([x, head, x + 8 + 8 * len(label), head + 20], fill=(24, 25, 36))
        dr.text((x + 4, head + 2), label, fill=(230, 232, 245), font=font)
        lo = im.resize((small, small), Image.Resampling.LANCZOS).resize((big, big), Image.Resampling.NEAREST)
        img.paste(lo, (x + (size - big) // 2, head + size + 22))
    dr.text((8, head + size + 3), "at 48 px (one beat per column)", fill=(200, 204, 225), font=font)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)
    return path


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=300)
    ap.add_argument("--samples", type=int, default=16)
    a = ap.parse_args(argv)
    tmp = os.path.join(tempfile.gettempdir(), "eh_gus_beats")
    os.makedirs(tmp, exist_ok=True)
    tiles = []
    for i, shot in enumerate(poses()):
        p = os.path.join(tmp, f"gus_{i:02d}.png")
        render_tile(shot, a.size, a.samples, p)
        tiles.append((p, shot["label"]))
    print(sheet(tiles, a.size, OUT))


if __name__ == "__main__":
    main(sys.argv[1:])
