"""BLENDER LOOK frames (docs/audit/BLENDER_LOOK.md): the first-person L1 spawn and the hideout, Roblox-faithful.

    python3 tools/blender/look_frames.py --frame G1|G3 --mode before|after [--before <dir>] [--samples 16]
                                         [--out docs/audit/blender_look]
    python3 tools/blender/look_frames.py --sheet [--out docs/audit/blender_look]

The same scenes as the golden first-person frames (level_shots.golden_fp_g1 / golden_fp_g3: the level and the hideout
as the server builds them, the town, the aurora, your Rookie hands), but drawn the way the engine draws them instead of
the golden frames' flattering finish:
  * kit materials from roblox_look.part_material (atlas x the FBX vertex colours x MeshPart.Color, SmoothPlastic);
  * the `<Piece>_Outline` hulls placed with their pieces (after only), unlit ink, back faces culled;
  * the Lighting from a project file: ColorShift_Top / Brightness as the key, OutdoorAmbient (G1, the street) or
    Ambient (G3, the warehouse) as the fill, ExposureCompensation, the ColorCorrectionEffect after the render; the
    level's own lamps (KitPlan.lamps) as level_shots places them; the Atmosphere haze from the depth pass;
  * no golden-frame vignette, lavender tint or 0.86 bloom.
before = main's FBX (no AO, no hulls) and main's default.project.json (--before: a folder holding assets/fbx and
default.project.json from main); after = this branch. Each frame is graded with frame_grade.py into grades.json.
"""
import argparse, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
import level_shots as LS  # noqa: E402
import roblox_look as RL  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "audit", "blender_look")
STATE = {"mode": "after", "manifest": {}, "hulls": {}, "interior": False, "atlas": {}}


def _manifest(fbx_dir):
    with open(os.path.join(fbx_dir, "kit_manifest.json")) as f:
        return json.load(f)["parts"]


def _atlas(loc):
    if loc not in STATE["atlas"]:
        import eh_palette as P
        path = P.atlas_path(loc)
        if not os.path.isfile(path):
            P.write_atlases()
        STATE["atlas"][loc] = bpy.data.images.load(path, check_existing=True)
    return STATE["atlas"][loc]


class FaithfulLib(LS.Lib):
    """level_shots.Lib with the engine's surfaces (no kit_preview styling) and, after, the outline hulls."""

    def get(self, model, name):
        if name not in self.parts and model not in self.models:
            self.models.add(model)
            for m in [model] + self._hull_groups(model):
                self._import(m)
        return self.parts.get(name)

    def _hull_groups(self, model):
        if STATE["mode"] != "after":
            return []
        man = STATE["manifest"]
        pieces = [n for n, p in man.items() if p["model"] == model]
        groups = sorted({man[STATE["hulls"][n]]["model"] for n in pieces if n in STATE["hulls"]})
        return [g for g in groups if g not in self.models and not self.models.add(g)]

    def _import(self, model):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=os.path.join(LS.FBX, model + ".fbx"))
        man = STATE["manifest"]
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
            o.data.materials.clear()
            spec = man.get(base)
            if spec and spec.get("outlineOf"):
                o.data.materials.append(RL.outline_material())
                o.visible_shadow = False
            else:
                vc = o.data.color_attributes[0].name if len(o.data.color_attributes) else None
                o.data.materials.append(RL.part_material(base, spec, _atlas(self.loc), vc))
            self.parts[base] = o


_put = LS.put


def faithful_put(lib, piece, pivot, scale, extra=None):
    o = _put(lib, piece, pivot, scale, extra)
    hull = STATE["hulls"].get(piece["name"])
    if o is not None and hull and STATE["mode"] == "after":
        src = lib.get(piece["model"], piece["name"])
        h = lib.parts.get(hull)
        if h is not None and src is not None:
            ho = h.copy()
            bpy.context.scene.collection.objects.link(ho)
            # the hull shares its piece's kit point: same transform as the placed piece, relative to the sources
            ho.matrix_world = o.matrix_world @ src.matrix_world.inverted() @ h.matrix_world
    return o


def faithful_lighting(s):
    """The project file's Lighting: key = the ClockTime sun at Brightness tinted by ColorShift_Top, fill = the
    (Outdoor)Ambient world (+ EnvironmentDiffuseScale), camera rays see the sky (BS.world_sky links it)."""
    L = RL.lighting()["lighting"]
    s.view_settings.view_transform = RL.TONE
    s.view_settings.look = "None"
    s.view_settings.exposure = float(L.get("ExposureCompensation", 0.0))
    w = s.world
    w.use_nodes = True
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    amb = L.get("Ambient" if STATE["interior"] else "OutdoorAmbient")
    k = 1.0 + float(L.get("EnvironmentDiffuseScale", 0.0)) * 0.5
    bg.inputs["Color"].default_value = (*[RL._srgb_to_lin(c) * k for c in amb], 1)
    bg.inputs["Strength"].default_value = 1.0
    sky = nt.nodes.new("ShaderNodeBackground")
    sky.inputs["Color"].default_value = (0.03, 0.03, 0.06, 1)
    path = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    outn = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
    nt.links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(bg.outputs[0], mix.inputs[1])
    nt.links.new(sky.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], outn.inputs["Surface"])
    sd = bpy.data.lights.new("RL_Sun", "SUN")
    top = L.get("ColorShift_Top", [1, 1, 1])
    sd.color = tuple(0.5 + 0.5 * c for c in top)
    sd.energy = float(L.get("Brightness", 1.0))
    sd.angle = math.radians(2.0 + 10.0 * float(L.get("ShadowSoftness", 0.2)))
    so = bpy.data.objects.new("RL_Sun", sd)
    s.collection.objects.link(so)
    d = RL._sun_direction(float(L.get("ClockTime", 14)), float(L.get("GeographicLatitude", 20)))
    so.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


def faithful_finish(s, cam, name, gdir, pos, tgt, fov, snow_at, cfg, level=None, fp=True, glint=None):
    import backdrop_shots as BS
    import frame_grade as FG
    flakes = BS.snowfall(snow_at, cfg, pos) if snow_at is not None else None
    bp, bt = LS.rb(*pos), LS.rb(*tgt)
    cam.location = bp
    cam.rotation_euler = (bt - bp).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle_y = math.radians(fov)
    raw = os.path.join(LS.TMP, f"look_{name}_{STATE['mode']}_raw.png")
    LS.render(s, cam, raw)
    depth = os.path.join(LS.TMP, f"look_{name}_{STATE['mode']}_depth.png")
    BS.depth_pass(s, cam, depth)
    out = os.path.join(gdir, f"{name}_{STATE['mode']}.png")
    BS.haze(raw, depth, out)                       # the Atmosphere (Density / Haze) is in the game too
    RL.grade(out)                                  # the game's ColorCorrectionEffect
    if fp:
        LS.reticle(out)
    if flakes is not None:
        bpy.data.objects.remove(flakes, do_unlink=True)
    g = FG.grade(out)
    rec = {k: g[k] for k in ("near_black", "dark_share", "clipped", "clipped_ok", "warm_share", "median_luma")
           if k in g}
    path = os.path.join(gdir, "grades.json")
    allg = json.load(open(path)) if os.path.isfile(path) else {}
    allg[f"{name}_{STATE['mode']}"] = rec
    with open(path, "w") as f:
        json.dump(allg, f, indent=1, sort_keys=True)
    print("wrote", os.path.relpath(out, REPO), rec)


def run(frame, mode, before, samples, out):
    STATE["mode"] = mode
    if mode == "before":
        LS.FBX = os.path.join(before, "assets", "fbx")
        RL.PROJECT = os.path.join(before, "default.project.json")
    man = _manifest(LS.FBX)
    STATE["manifest"] = man
    STATE["hulls"] = {p["outlineOf"]: n for n, p in man.items() if p.get("outlineOf")}
    STATE["interior"] = frame == "G3"
    LS.Lib = FaithfulLib
    LS.put = faithful_put
    LS.lighting = faithful_lighting
    LS._gfp_finish = faithful_finish
    import fp_hands_preview as FP
    FP.FBX = LS.FBX                                # the gloves of the same kit (main's have no ink hull)
    FP.MAN = _manifest(LS.FBX)
    os.makedirs(out, exist_ok=True)
    os.makedirs(LS.TMP, exist_ok=True)
    gp = LS.golden_plan()
    plan = LS.load_plan(True, False)
    if frame == "G3":
        plan["garage"]["firstJob"] = plan["levels"][0]["name"].upper()
        LS.golden_fp_g3(plan["garage"], gp, samples, out)
    else:
        lv = next(lv for lv in plan["levels"] if lv["id"] == "cs1_back_room")
        LS.golden_fp_g1(lv, gp, samples, out)


def sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    f = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    font = (lambda sz: ImageFont.truetype(f, sz)) if os.path.isfile(f) else (lambda sz: ImageFont.load_default())
    g = json.load(open(os.path.join(out, "grades.json")))
    gold = os.path.join(REPO, "docs", "audit", "levels", "golden_fp")
    rows = [("G1_fp_spawn", "L1, first person"), ("G3_fp_hideout", "the hideout, first person")]
    W, H = 640, 360
    head, foot = 56, 20
    im = Image.new("RGB", (3 * W + 20, head + len(rows) * (H + foot)), (22, 23, 33))
    d = ImageDraw.Draw(im)
    d.text((10, 8), "BLENDER LOOK frames: the golden Blender render vs the game before and after (Roblox-faithful)",
           fill=(240, 242, 255), font=font(18))
    for i, c in enumerate(("golden frame (Blender finish)", "the game BEFORE (main)", "the game AFTER (this branch)")):
        d.text((10 + i * W, 34), c, fill=(200, 205, 225), font=font(13))
    for r, (name, label) in enumerate(rows):
        y = head + r * (H + foot)
        tiles = [os.path.join(gold, name + ".png"), os.path.join(out, name + "_before.png"),
                 os.path.join(out, name + "_after.png")]
        for i, t in enumerate(tiles):
            if os.path.isfile(t):
                im.paste(Image.open(t).convert("RGB").resize((W, H), Image.LANCZOS), (10 + i * W, y))
            if i:
                k = name + ("_before" if i == 1 else "_after")
                gg = g.get(k, {})
                d.text((14 + i * W, y + H + 2), f"{label}: black {gg.get('near_black', 0):.1f}%  clipped "
                       f"{gg.get('clipped', 0):.1f}%  warm {gg.get('warm_share', 0):.1f}%  luma "
                       f"{gg.get('median_luma', 0):.2f}", fill=(170, 176, 200), font=font(11))
    im.save(os.path.join(out, "frames.png"), optimize=True)
    print("sheet:", os.path.join(out, "frames.png"))


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--frame", choices=("G1", "G3"))
    ap.add_argument("--mode", choices=("before", "after"), default="after")
    ap.add_argument("--before")
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--sheet", action="store_true")
    a = ap.parse_args(argv)
    if a.sheet:
        sheet(os.path.abspath(a.out))
        return
    if a.mode == "before" and not a.before:
        ap.error("--mode before needs --before <dir with main's assets/fbx and default.project.json>")
    run(a.frame, a.mode, os.path.abspath(a.before) if a.before else None, a.samples, os.path.abspath(a.out))


if __name__ == "__main__":
    main(sys.argv[1:])
