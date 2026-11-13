"""Northern-lights previews (PLAN_FIRST_PERSON "SKY"): the client Heist/Aurora approximated in Blender over the
Heist City sky, from the cameras the game uses. Sky-only: no level geometry (the skybox carries the skyline and
Hoardsworth's tower); these are previews, not captures.

    python3 tools/blender/aurora_shots.py [--size 1280] [--samples 16] [--t 0] [--only fp_lookup,...]

Writes docs/art/aurora/<shot>.png and docs/art/aurora/contact_sheet.png.

What is reproduced, from the same data the game uses (nothing hand-placed):
  * `lune run tools/blender/aurora_plan.luau <t>` samples every Beam along the Bezier the engine draws (AuroraPlan
    spine + Catmull-Rom handles, Config.Aurora.SEGMENTS pieces), with its tile, end fades, tint and brightness;
  * each Beam as a camera-facing ribbon (FaceCamera: the width runs along tangent x view), Width0 wide, UV u along
    the Beam (one tile, TextureMode Stretch), v across it (image top = curtain top), the uploaded PNGs
    (assets/sky/EH_Aurora_*.png);
  * additive and unlit (LightEmission 1, LightInfluence 0): added colour = tile RGB x tint x Brightness x tile alpha
    x (1 - Transparency) x the end fade;
  * the layer holders follow the camera (the shot camera stands at the anchor), turned to the landmark (yaw 0: -Z);
  * the sky: the six Heist City faces as an equirectangular world (tools/blender/backdrop_shots.equirect);
  * the post: marketing_renders.finish (Bloom over its threshold, ColorCorrection).
NOT reproduced: Roblox's Atmosphere haze on the Beams (unknown: if it fades far layers, the Glow and the Drape read
weaker in game), its tone mapping and texture compression, the level and its lights.
"""
import argparse
import json
import math
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import backdrop_shots as BS  # noqa: E402
import marketing_renders as MR  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "art", "aurora")
SKY = os.path.join(REPO, "assets", "sky")
CAM = {   # Config.Heist.CAMERA: FP eye ~5 studs, FOV 70; classic FOV 70, zoom 16, pitch 25 down
    "fp_ahead": dict(pos=(0, 5, 0), yaw=0, pitch=14, fov=70, label="First person, looking ahead (the landmark)"),
    "fp_lookup": dict(pos=(0, 5, 0), yaw=0, pitch=45, fov=70, label="First person, looking up"),
    "fp_zenith": dict(pos=(0, 5, 0), yaw=0, pitch=78, fov=70, label="First person, straight up"),
    "yard": dict(pos=(0, 5, 0), yaw=38, pitch=24, fov=70, label="Lobby yard, turned left"),
    "classic": dict(pos=(0, 6.8, 14.5), yaw=0, pitch=-25, fov=70, label="Classic camera (top of frame)"),
    "fp_lookup_t3": dict(pos=(0, 5, 0), yaw=0, pitch=45, fov=70, tier=3, label="Tier 3: two layers"),
    "fp_lookup_t4": dict(pos=(0, 5, 0), yaw=0, pitch=45, fov=70, tier=4, label="Tier 4: one static layer"),
}
TIER_LAYERS = {1: 4, 2: 4, 3: 2, 4: 1}   # Config.Aurora.TIERS (checked against the dump below)


def rb(p):
    return Vector((-p[0], p[2], p[1]))


def load_plan(t):
    with tempfile.NamedTemporaryFile("w+", suffix=".json", delete=False) as f:
        subprocess.run(["lune", "run", os.path.join("tools", "blender", "aurora_plan.luau"), str(t)], cwd=REPO,
                       check=True, stdout=f)
        path = f.name
    with open(path) as f:
        data = json.load(f)
    os.unlink(path)
    for tier, n in TIER_LAYERS.items():
        assert data["tiers"][tier - 1]["layers"] == n, f"tier {tier}: Config.Aurora.TIERS changed"
    return data


def scene(samples, W, Hh, tmp):
    s = bpy.context.scene
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    s.render.engine = "BLENDER_EEVEE"
    s.eevee.taa_render_samples = samples
    s.view_settings.view_transform = "Standard"
    s.view_settings.exposure = 0.3                    # ExposureCompensation 0.3 (recipe A)
    s.render.resolution_x, s.render.resolution_y = W, Hh
    s.render.resolution_percentage = 100
    w = bpy.data.worlds.get("EH_Aurora_World") or bpy.data.worlds.new("EH_Aurora_World")
    s.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(BS.equirect(os.path.join(tmp, "sky_city_equirect.png")))
    nt.links.new(env.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    return s


def material(name, tex_path):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    try:
        m.surface_render_method = "BLENDED"
    except AttributeError:
        m.blend_method = "BLEND"
    m.use_backface_culling = False
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(tex_path, check_existing=True)
    img.interpolation = "Linear"
    img.extension = "REPEAT"
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "aur"
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(img.outputs["Color"], mul.inputs[6])
    nt.links.new(attr.outputs["Color"], mul.inputs[7])
    strength = nt.nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY"
    nt.links.new(img.outputs["Alpha"], strength.inputs[0])
    nt.links.new(attr.outputs["Alpha"], strength.inputs[1])
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(mul.outputs[2], emit.inputs["Color"])
    nt.links.new(strength.outputs[0], emit.inputs["Strength"])
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(clear.outputs[0], add.inputs[0])
    nt.links.new(emit.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    return m


def lerp3(a, b, f):
    return [a[i] + (b[i] - a[i]) * f for i in range(3)]


def ribbons(s, plan, cam_pos, layer_count):
    """Each Beam as a camera-facing ribbon: holder at the camera's ground point (follow 1 for a still camera)."""
    anchor = (cam_pos[0], 0.0, cam_pos[2])
    eye = Vector(cam_pos)
    ta, tb = [c / 255 for c in plan["tintA"]], [c / 255 for c in plan["tintB"]]
    for layer in plan["layers"][:layer_count]:
        alpha_base = 1 - layer["transparency"]
        # tangents over the whole chain, so neighbouring Beams share the width direction at their shared point
        chain = []
        for beam in layer["beams"]:
            chain += [Vector((anchor[0] + p[0], anchor[1] + p[1], anchor[2] - p[2])) for p in beam["samples"]][
                (1 if chain else 0):]
        for bi, beam in enumerate(layer["beams"]):
            n = len(beam["samples"])
            first = bi * (n - 1)
            pts = chain[first:first + n]
            verts, faces, uvs, cols = [], [], [], []
            for j, p in enumerate(pts):
                g = first + j
                tg = (chain[min(g + 1, len(chain) - 1)] - chain[max(g - 1, 0)]).normalized()
                wd = tg.cross(p - eye).normalized()
                if wd.y < 0:                        # image top = the curtain's top
                    wd = -wd
                u = j / (n - 1)
                half = wd * layer["width"] / 2
                verts += [rb(p - half), rb(p + half)]
                uvs += [(u, 0.0), (u, 1.0)]
                tint = lerp3(ta, tb, beam["tint"][0] + (beam["tint"][1] - beam["tint"][0]) * u)
                fade = beam["fade"][0] + (beam["fade"][1] - beam["fade"][0]) * u
                c = [x * layer["brightness"] for x in tint] + [alpha_base * fade]
                cols += [c, c]
                if j < n - 1:
                    faces.append((2 * j, 2 * j + 1, 2 * j + 3, 2 * j + 2))
            me = bpy.data.meshes.new(f"{layer['name']}_{bi}")
            me.from_pydata([tuple(v) for v in verts], [], faces)
            uv = me.uv_layers.new(name="UVMap")
            ca = me.color_attributes.new("aur", "FLOAT_COLOR", "POINT")
            for poly in me.polygons:
                for li in poly.loop_indices:
                    uv.data[li].uv = uvs[me.loops[li].vertex_index]
            for vi, c in enumerate(cols):
                ca.data[vi].color = c
            ob = bpy.data.objects.new(me.name, me)
            name = plan["textures"][beam["texture"] - 1]
            ob.data.materials.append(material(name, os.path.join(SKY, name + ".png")))
            s.collection.objects.link(ob)


def camera(s, shot, W, Hh):
    yaw, pitch = math.radians(shot["yaw"]), math.radians(shot["pitch"])
    look = (-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
    pos = shot["pos"]
    target = [pos[i] + look[i] * 10 for i in range(3)]
    cam = MR.camera(s, tuple(rb(pos)), tuple(rb(target)), shot["fov"], W, Hh)
    cam.data.clip_end = 8000
    return cam


def sheet(names):
    from PIL import Image, ImageDraw
    ims = [Image.open(os.path.join(OUT, n + ".png")).convert("RGB") for n in names]
    w, h = ims[0].size
    tw, th = w // 2, h // 2
    cols = 2
    rows = (len(ims) + cols - 1) // cols
    out = Image.new("RGB", (tw * cols, (th + 28) * rows), (12, 12, 20))
    d = ImageDraw.Draw(out)
    font = MR._font(20)[0]
    for i, (n, im) in enumerate(zip(names, ims)):
        x, y = (i % cols) * tw, (i // cols) * (th + 28)
        out.paste(im.resize((tw, th)), (x, y + 28))
        d.text((x + 8, y + 4), f"{n}: {CAM[n]['label']}", font=font, fill=(230, 232, 245))
    out.save(os.path.join(OUT, "contact_sheet.png"), optimize=True)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=1280)
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--t", type=float, default=6.0, help="motion time (s) of the animated tiers")
    ap.add_argument("--only")
    a = ap.parse_args(argv)
    W, Hh = a.size, a.size * 9 // 16
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="eh_aurora_")
    plans = {a.t: load_plan(a.t), 0.0: load_plan(0.0)}
    names = [n for n in CAM if not a.only or n in a.only.split(",")]
    for name in names:
        shot = CAM[name]
        tier = shot.get("tier", 1)
        s = scene(a.samples, W, Hh, tmp)
        plan = plans[0.0 if tier == 4 else a.t]
        ribbons(s, plan, shot["pos"], TIER_LAYERS[tier])
        camera(s, shot, W, Hh)
        raw = os.path.join(tmp, name + "_raw.png")
        s.render.filepath = raw
        bpy.ops.render.render(write_still=True)
        MR.finish(raw, os.path.join(OUT, name + ".png"), [], tag=False, truecolor=True, vignette=0.12)
        print("wrote", os.path.relpath(os.path.join(OUT, name + ".png"), REPO), flush=True)
    if not a.only:
        sheet(names)
        print("wrote", os.path.relpath(os.path.join(OUT, "contact_sheet.png"), REPO))


if __name__ == "__main__":
    main(sys.argv[1:])
