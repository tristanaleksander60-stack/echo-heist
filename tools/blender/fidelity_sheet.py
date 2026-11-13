"""Studio-fidelity before/after contact sheet (docs/audit/STUDIO_FIDELITY.md).

    python3 tools/blender/fidelity_sheet.py --before <dir with the old FBX files> [--size 420]
                                             [--out docs/audit/studio_fidelity/before_after.png]

One row per representative asset, three columns, the same camera in each:
  1. the OLD preview: turntable.py's Workbench studio light + cavity + outline, on the old FBX (what we judged by)
  2. Roblox-faithful (roblox_look.py) on the OLD FBX: what the engine showed
  3. Roblox-faithful on the CURRENT assets/fbx: what the engine shows after the pipeline fixes
Plus a close-up row pair (2x crop of columns 2 and 3) so the shading change is visible at phone-screenshot size.
"""
import argparse, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import turntable as tt  # noqa: E402
import roblox_look as RL  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
FBX = os.path.join(REPO, "assets", "fbx")

# (label, FBX model, keep: name prefixes or None for all, azimuth, elevation, location atlas, zoom)
ASSETS = [
    ("The Rookie", "Rookie", None, 30, 12, "Bank", 1.0),
    ("Gus", "Gus", None, 30, 12, "Bank", 1.0),
    ("Van", "Van", None, 40, 14, "Bank", 1.0),
    ("Shop front", "Storefront_24x12", None, 25, 10, "CornerShop", 1.0),
    ("Prop: cash register", "CashRegister", None, 35, 20, "CornerShop", 1.0),
    ("Vault door", "VaultDoor", None, 20, 10, "Bank", 1.0),
    ("Hideout: job board", "JobBoard", None, 30, 12, "Bank", 1.0),
    ("Prop: street lamp", "StreetLamp", None, 30, 10, "Bank", 1.0),
]


def _load(path, keep):
    objs = tt.load_file(path)
    if keep:
        for o in list(objs):
            if not o.name.startswith(tuple(keep)):
                bpy.data.objects.remove(o, do_unlink=True)
        objs = tt.mesh_objects()
    return objs


def _studio(path, objs, az, el, size):
    s = bpy.context.scene
    s.view_settings.view_transform = "Standard"
    lo, hi = tt.bounds(objs)
    rig = tt.Rig(s)
    tt._workbench(s, "studio")
    rig.aim(lo, hi, az, el, margin=1.0)
    tt._render(s, path, size)
    rig.remove()
    return path


def _faithful(path, objs, az, el, size, loc):
    s = bpy.context.scene
    made = RL.apply(s, objs, location=loc)
    lo, hi = tt.bounds(objs)
    rig = tt.Rig(s)
    rig.aim(lo, hi, az, el, margin=1.0)
    RL.aim_sun(made, rig.cam.location, (lo + hi) / 2)
    # a ground plane in the street's dark asphalt so the sunlit side and its shadow read like the game
    bpy.ops.mesh.primitive_plane_add(size=(hi - lo).length * 8, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    fl = bpy.context.active_object
    fm = bpy.data.materials.new("RL_Ground")
    fm.use_nodes = True
    b = next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.03, 0.03, 0.045, 1)
    b.inputs["Roughness"].default_value = 0.8
    fl.data.materials.append(fm)
    tt._render(s, path, size)
    rig.remove()
    RL.grade(path)
    return path


def render_row(before_dir, label, model, keep, az, el, loc, size, tmp):
    out = []
    for i, (src, mode) in enumerate(((before_dir, "studio"), (before_dir, "faithful"), (FBX, "faithful"))):
        path = os.path.join(src, model + ".fbx")
        png = os.path.join(tmp, f"{model}_{i}.png")
        objs = _load(path, keep)
        if mode == "studio":
            _studio(png, objs, az, el, size)
        else:
            _faithful(png, objs, az, el, size, loc)
        out.append(png)
    return out


def compose(rows, size, out_path):
    from PIL import Image, ImageDraw, ImageFont
    def font(sz):
        f = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        return ImageFont.truetype(f, sz) if os.path.isfile(f) else ImageFont.load_default()
    head = 64
    lab_w = 150
    crop = size // 2
    W = lab_w + 3 * size + 2 * size
    H = head + len(rows) * size
    sheet = Image.new("RGB", (W, H), (22, 23, 33))
    d = ImageDraw.Draw(sheet)
    d.text((10, 8), "Studio fidelity: the old preview vs what the engine renders, before and after the pipeline fix",
           fill=(240, 242, 255), font=font(20))
    cols = ["OLD preview (Workbench studio,\ncavity + outline), old FBX", "Roblox-faithful preview,\nold FBX (= the game before)",
            "Roblox-faithful preview,\nnew FBX (= the game after)", "close-up 2x: before", "close-up 2x: after"]
    for i, c in enumerate(cols):
        d.text((lab_w + i * size + 6, 34), c.split("\n")[0], fill=(200, 205, 225), font=font(13))
        if "\n" in c:
            d.text((lab_w + i * size + 6, 49), c.split("\n")[1], fill=(200, 205, 225), font=font(13))
    for r, (label, pngs) in enumerate(rows):
        y = head + r * size
        d.text((8, y + 8), label, fill=(240, 242, 255), font=font(15))
        for i, p in enumerate(pngs):
            sheet.paste(Image.open(p).convert("RGB"), (lab_w + i * size, y))
        for j, p in enumerate(pngs[1:]):
            im = Image.open(p).convert("RGB")
            c0 = (size - crop) // 2
            sheet.paste(im.crop((c0, c0, c0 + crop, c0 + crop)).resize((size, size), Image.LANCZOS),
                        (lab_w + (3 + j) * size, y))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path, optimize=True)
    return out_path


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True)
    ap.add_argument("--size", type=int, default=420)
    ap.add_argument("--out", default=os.path.join(REPO, "docs", "audit", "studio_fidelity", "before_after.png"))
    ap.add_argument("--only")
    ap.add_argument("--tiles", help="also keep the single tiles in this folder")
    a = ap.parse_args(argv)
    tmp = tempfile.mkdtemp(prefix="eh_fid_")
    rows = []
    for label, model, keep, az, el, loc, _z in ASSETS:
        if a.only and a.only != model:
            continue
        rows.append((label, render_row(a.before, label, model, keep, az, el, loc, a.size, tmp)))
    compose(rows, a.size, a.out)
    if a.tiles:
        os.makedirs(a.tiles, exist_ok=True)
        for f in os.listdir(tmp):
            shutil.copy(os.path.join(tmp, f), a.tiles)
    shutil.rmtree(tmp, ignore_errors=True)
    print("sheet:", a.out)


if __name__ == "__main__":
    main(sys.argv[1:])
