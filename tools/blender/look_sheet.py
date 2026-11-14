"""BLENDER LOOK before/after sheet (docs/audit/BLENDER_LOOK.md): the Blender preview's tricks, in the game.

    python3 tools/blender/look_sheet.py --before <dir with main's assets/fbx and default.project.json>
                                        [--size 420] [--only Rookie] [--out docs/audit/blender_look/assets.png]

The same 8 assets as docs/audit/studio_fidelity, one row each, the same camera in every column:
  1. the Blender preview the owner liked: Workbench studio light + cavity + black outline (turntable.py), main's FBX
  2. the game BEFORE: Roblox-faithful (roblox_look.py) with main's FBX and main's Lighting (its project file)
  3. the game AFTER: Roblox-faithful with this branch's FBX (baked vertex AO + cavity), the `<Piece>_Outline` hulls
     (back faces culled, Config.Outline.COLOUR) and this branch's Lighting
  4. and 5. 2x close-ups of 2 and 3
Every tile of columns 2 and 3 is graded with frame_grade.py (near-black, clipped, warm share, median luma); the numbers
go to <out>.json and under each tile. The first-person L1 and hideout frames are tools/blender/look_frames.py.
"""
import argparse, json, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import turntable as tt  # noqa: E402
import roblox_look as RL  # noqa: E402
import fidelity_sheet as FS  # noqa: E402
import frame_grade as FG  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
FBX = os.path.join(REPO, "assets", "fbx")
MANIFEST = os.path.join(FBX, "kit_manifest.json")
NOW_PROJECT = RL.PROJECT


def hull_groups():
    """{piece: (hull group, hull piece)} from this branch's manifest."""
    with open(MANIFEST) as f:
        parts = json.load(f)["parts"]
    return {p["outlineOf"]: (p["model"], name) for name, p in parts.items() if p.get("outlineOf")}


def load_with_hulls(model, keep):
    objs = FS._load(os.path.join(FBX, model + ".fbx"), keep)
    names = {o.name.split(".")[0] for o in objs}
    hulls = hull_groups()
    groups = sorted({hulls[n][0] for n in names if n in hulls})
    for g in groups:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(FBX, g + ".fbx"))
        for o in set(bpy.data.objects) - before:
            base = o.name.split(".")[0]
            if o.type != "MESH" or not base.endswith("_Outline") or base[:-8] not in names:
                bpy.data.objects.remove(o, do_unlink=True)
    return tt.mesh_objects()


def grade_tile(png):
    g = FG.grade(png)
    return {k: g[k] for k in ("near_black", "clipped", "warm_share", "median_luma") if k in g}


def render_row(before_dir, model, keep, az, el, loc, size, tmp):
    out = []
    bfbx = os.path.join(before_dir, "assets", "fbx")
    bproj = os.path.join(before_dir, "default.project.json")
    # 1. the old studio preview (main's FBX)
    p = os.path.join(tmp, f"{model}_0.png")
    FS._studio(p, FS._load(os.path.join(bfbx, model + ".fbx"), keep), az, el, size)
    out.append(p)
    # 2. the game before: main's FBX, main's Lighting
    RL.PROJECT = bproj
    p = os.path.join(tmp, f"{model}_1.png")
    FS._faithful(p, FS._load(os.path.join(bfbx, model + ".fbx"), keep), az, el, size, loc)
    out.append(p)
    # 3. the game after: this branch's FBX (AO), the hulls, this branch's Lighting
    RL.PROJECT = NOW_PROJECT
    p = os.path.join(tmp, f"{model}_2.png")
    FS._faithful(p, load_with_hulls(model, keep), az, el, size, loc)
    out.append(p)
    return out


def compose(rows, grades, size, out_path):
    from PIL import Image, ImageDraw, ImageFont

    def font(sz):
        f = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        return ImageFont.truetype(f, sz) if os.path.isfile(f) else ImageFont.load_default()
    head, lab_w, foot = 64, 150, 18
    crop = size // 2
    W = lab_w + 5 * size
    H = head + len(rows) * (size + foot)
    sheet = Image.new("RGB", (W, H), (22, 23, 33))
    d = ImageDraw.Draw(sheet)
    d.text((10, 8), "BLENDER LOOK: the preview's tricks (outlines, AO + cavity, warm key / neutral fill, grade) "
           "in the game", fill=(240, 242, 255), font=font(20))
    cols = ["Blender preview (Workbench:", "the game BEFORE", "the game AFTER", "close-up 2x: before",
            "close-up 2x: after"]
    sub = ["studio light, cavity, outline)", "(faithful, main)", "(faithful, this branch)", "", ""]
    for i, c in enumerate(cols):
        d.text((lab_w + i * size + 6, 34), c, fill=(200, 205, 225), font=font(13))
        d.text((lab_w + i * size + 6, 49), sub[i], fill=(200, 205, 225), font=font(13))
    for r, (label, pngs) in enumerate(rows):
        y = head + r * (size + foot)
        d.text((8, y + 8), label, fill=(240, 242, 255), font=font(15))
        for i, p in enumerate(pngs):
            sheet.paste(Image.open(p).convert("RGB"), (lab_w + i * size, y))
        for j, p in enumerate(pngs[1:]):
            im = Image.open(p).convert("RGB")
            c0 = (size - crop) // 2
            sheet.paste(im.crop((c0, c0, c0 + crop, c0 + crop)).resize((size, size), Image.LANCZOS),
                        (lab_w + (3 + j) * size, y))
        for j, key in enumerate(("before", "after")):
            g = grades[label][key]
            d.text((lab_w + (1 + j) * size + 4, y + size + 2),
                   f"black {g['near_black']:.1f}%  clip {g['clipped']:.1f}%  warm {g['warm_share']:.1f}%  "
                   f"luma {g['median_luma']:.2f}", fill=(170, 176, 200), font=font(11))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path, optimize=True)
    return out_path


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True)
    ap.add_argument("--size", type=int, default=420)
    ap.add_argument("--out", default=os.path.join(REPO, "docs", "audit", "blender_look", "assets.png"))
    ap.add_argument("--only")
    ap.add_argument("--tiles", help="also keep the single tiles in this folder")
    a = ap.parse_args(argv)
    tmp = tempfile.mkdtemp(prefix="eh_look_")
    rows, grades = [], {}
    for label, model, keep, az, el, loc, _z in FS.ASSETS:
        if a.only and a.only != model:
            continue
        pngs = render_row(os.path.abspath(a.before), model, keep, az, el, loc, a.size, tmp)
        rows.append((label, pngs))
        grades[label] = {"blender": grade_tile(pngs[0]), "before": grade_tile(pngs[1]), "after": grade_tile(pngs[2])}
        print(label, json.dumps(grades[label]))
    compose(rows, grades, a.size, a.out)
    with open(os.path.splitext(a.out)[0] + ".json", "w") as f:
        json.dump(grades, f, indent=1)
    if a.tiles:
        os.makedirs(a.tiles, exist_ok=True)
        for f in os.listdir(tmp):
            shutil.copy(os.path.join(tmp, f), a.tiles)
    shutil.rmtree(tmp, ignore_errors=True)
    print("sheet:", a.out)


if __name__ == "__main__":
    main(sys.argv[1:])
