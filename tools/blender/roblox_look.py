"""Roblox-faithful Blender preview (docs/audit/STUDIO_FIDELITY.md, suspect 8: "the Blender preview isn't honest").

    import roblox_look as RL
    RL.apply(scene, objs, location="Bank")        # materials + lights + colour management like the engine
    ... render ...
    RL.grade(png_path)                            # the game's ColorCorrectionEffect, applied to the PNG

What the old previews did that the engine does not (and what this mode does instead):
  turntable.py      Workbench "paint.sl" studio light + cavity + black object outline: cavity shades every hard
                    edge like a bevel and the outline draws the silhouette, so flat facets read as crafted edges.
  level / marketing Eevee with area lights placed per shot, AO, bloom, exposure and emission tuned per frame.
  roblox_look       the engine path only: colour = the atlas texture (bilinear, no vertex colour) x MeshPart.Color
                    from kit_manifest.json; SmoothPlastic = a dielectric BSDF (roughness SMOOTHPLASTIC_ROUGHNESS),
                    Neon = emission, Glass = transparent; the split normals exactly as the FBX carries them (the
                    importer keeps custom normals, the engine renders the same ones: measured with EditableMesh);
                    one sun from Lighting.ClockTime / GeographicLatitude with Lighting.Brightness tinted by
                    ColorShift_Top, a uniform world of Lighting.OutdoorAmbient (or Ambient for an interior), no AO,
                    no outline, no cavity, no bloom below Bloom.Threshold, and the ColorCorrectionEffect applied
                    after the render (grade). Every number is read from default.project.json, so a lighting change
                    on main shows up here without editing this file.
Approximations (stated, not hidden): the engine's tone curve is approximated with Blender's "ACES 1.3" view
transform; Future's sky/environment diffuse (EnvironmentDiffuseScale) is folded into the uniform ambient; shadows
are Eevee's, softer than the engine's at ShadowSoftness 0.3.
"""
import json, math, os, sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import eh_palette as P  # noqa: E402
from kit_docs import idle_colour  # noqa: E402  (KitService's MeshPart.Color rule, via KitData)

PROJECT = os.path.join(REPO, "default.project.json")
MANIFEST = os.path.join(REPO, "assets", "fbx", "kit_manifest.json")

# Material response per Roblox material (MeshPart with a TextureID: the texture replaces the material's colour map,
# the material keeps its surface response). Roughness values are an eyeball match of the 2022 material set.
SMOOTHPLASTIC_ROUGHNESS = 0.42
ROUGHNESS = {"SmoothPlastic": SMOOTHPLASTIC_ROUGHNESS, "Plastic": 0.62, "Metal": 0.35, "Glass": 0.05,
             "Wood": 0.7, "Fabric": 0.9, "Neon": 1.0, "Foil": 0.25, "DiamondPlate": 0.4}
NEON_STRENGTH = 2.2        # emission strength for Neon (the engine draws Neon above 1.0, Bloom picks it up)
TONE = "ACES 1.3"          # closest Blender view transform to the engine's default tone curve [approximation]


def _srgb_to_lin(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def lighting():
    """The Lighting service values Rojo writes (default.project.json), plus ColorCorrection and Bloom."""
    with open(PROJECT) as f:
        tree = json.load(f)["tree"]
    lt = tree["Lighting"]
    p = dict(lt["$properties"])
    out = {"lighting": p}
    for name, node in lt.items():
        if isinstance(node, dict) and node.get("$className") in ("ColorCorrectionEffect", "BloomEffect", "Atmosphere"):
            out[node["$className"]] = node.get("$properties", {})
    return out


def _sun_direction(clock, lat_deg):
    """Unit vector toward the sun in Blender axes (Z up, -Y = front). Simple equinox model: hour angle from noon,
    elevation from the latitude; the engine's exact sun path differs by a few degrees."""
    h = math.radians((clock - 12.0) * 15.0)
    lat = math.radians(lat_deg)
    # east = -X in Blender after the kit's export (Roblox +X = Blender -X); the exact azimuth matters little here
    x = -math.sin(h) * -1.0
    y = -math.cos(h) * math.sin(lat)
    z = math.cos(h) * math.cos(lat)
    v = Vector((x, y, z))
    if v.z < 0.15:
        v.z = 0.15
    return v.normalized()


def _manifest():
    try:
        with open(MANIFEST) as f:
            return json.load(f)["parts"]
    except (OSError, ValueError):
        return {}


def _hex_lin(h):
    h = h.lstrip("#")
    return tuple(_srgb_to_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))


def part_material(name, spec, atlas_img):
    """The engine's surface for one MeshPart: atlas x Color, the material's response, Neon / Glass."""
    m = bpy.data.materials.new("RL_" + name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    mat = (spec or {}).get("material", "SmoothPlastic")
    col = idle_colour(name, spec) if spec else None
    rgb = _hex_lin(col) if isinstance(col, str) and col.startswith("#") else (1.0, 1.0, 1.0)
    b.inputs["Roughness"].default_value = ROUGHNESS.get(mat, SMOOTHPLASTIC_ROUGHNESS)
    b.inputs["Metallic"].default_value = 1.0 if mat in ("Metal", "Foil", "DiamondPlate") else 0.0
    if mat == "Neon":
        b.inputs["Base Color"].default_value = (*rgb, 1)
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = NEON_STRENGTH
        return m
    textured = atlas_img is not None and (spec is None or spec.get("atlas", True))
    if textured:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = atlas_img
        tex.interpolation = "Linear"          # the engine filters bilinearly (the old previews used Closest)
        if rgb != (1.0, 1.0, 1.0):
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            nt.links.new(tex.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*rgb, 1)
            nt.links.new(mix.outputs[2], b.inputs["Base Color"])
        else:
            nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    else:
        b.inputs["Base Color"].default_value = (*rgb, 1)
    tr = (spec or {}).get("transparency") or (0.6 if mat == "Glass" else 0.0)
    if tr:
        b.inputs["Alpha"].default_value = 1.0 - tr
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    return m


def apply(scene, objs, location="Bank", interior=False, manifest=None):
    """Turns `scene` into the engine's look for `objs` (imported kit FBX meshes, named as in the manifest).
    Returns the lights and helper objects it added (remove them to undo)."""
    L = lighting()
    lp = L["lighting"]
    man = manifest if manifest is not None else _manifest()
    path = P.atlas_path(location)
    if not os.path.isfile(path):
        P.write_atlases()
    img = bpy.data.images.load(path, check_existing=True)
    for o in objs:
        base = o.name.split(".")[0]
        spec = man.get(base)
        o.data.materials.clear()
        o.data.materials.append(part_material(base, spec, img))
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 32
        scene.eevee.use_gtao = False            # no ambient occlusion: the engine has none
    except Exception:
        pass
    try:
        scene.eevee.use_shadows = True
    except Exception:
        pass
    vs = scene.view_settings
    vs.view_transform = TONE
    vs.look = "None"
    vs.exposure = float(lp.get("ExposureCompensation", 0.0))
    vs.gamma = 1.0
    if scene.world is None:
        scene.world = bpy.data.worlds.new("RL_World")
    w = scene.world
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    amb = lp.get("Ambient" if interior else "OutdoorAmbient", [0.5, 0.5, 0.5])
    # Roblox colours in the project file are sRGB 0..1; the ambient term is applied to albedo in linear
    amb_lin = [_srgb_to_lin(c) for c in amb]
    k = 1.0 + float(lp.get("EnvironmentDiffuseScale", 0.0)) * 0.5
    bg.inputs["Color"].default_value = (*[c * k for c in amb_lin], 1)
    bg.inputs["Strength"].default_value = 1.0
    made = []
    if not interior:
        sd = bpy.data.lights.new("RL_Sun", "SUN")
        top = lp.get("ColorShift_Top", [1, 1, 1])
        sd.color = tuple(0.5 + 0.5 * c for c in top)       # ColorShift_Top tints the sunlit side
        sd.energy = float(lp.get("Brightness", 1.0))
        sd.angle = math.radians(2.0 + 10.0 * float(lp.get("ShadowSoftness", 0.2)))
        so = bpy.data.objects.new("RL_Sun", sd)
        scene.collection.objects.link(so)
        d = _sun_direction(float(lp.get("ClockTime", 14)), float(lp.get("GeographicLatitude", 20)))
        so.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        made.append(so)
    else:
        pd = bpy.data.lights.new("RL_Lamp", "POINT")
        pd.color = (1.0, 0.86, 0.68)
        pd.energy = 400.0
        pd.shadow_soft_size = 0.3
        po = bpy.data.objects.new("RL_Lamp", pd)
        scene.collection.objects.link(po)
        made.append(po)
    return made


def aim_sun(made, cam_loc, target):
    """Optional: swing the sun's azimuth to light the camera side at the engine's elevation (a preview of an
    asset should show its lit face; the elevation, colour and strength stay the engine's)."""
    for o in made:
        if o.type == "LIGHT" and o.data.type == "SUN":
            L = lighting()["lighting"]
            d = _sun_direction(float(L.get("ClockTime", 14)), float(L.get("GeographicLatitude", 20)))
            el = math.asin(max(-1.0, min(1.0, d.z)))
            v = Vector(cam_loc) - Vector(target)
            az = math.atan2(v.y, v.x) + math.radians(40)
            s = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
            o.rotation_euler = (-s).to_track_quat("-Z", "Y").to_euler()
        if o.type == "LIGHT" and o.data.type == "POINT":
            v = Vector(cam_loc) - Vector(target)
            o.location = Vector(target) + v.normalized() * 6 + Vector((0, 0, 7))


def grade(png_path):
    """The game's ColorCorrectionEffect (Brightness, Contrast, Saturation, TintColor) on a rendered sRGB PNG."""
    from PIL import Image, ImageEnhance
    cc = lighting().get("ColorCorrectionEffect", {})
    im = Image.open(png_path).convert("RGB")
    if cc.get("Brightness"):
        im = ImageEnhance.Brightness(im).enhance(1.0 + float(cc["Brightness"]))
    if cc.get("Contrast"):
        im = ImageEnhance.Contrast(im).enhance(1.0 + float(cc["Contrast"]))
    if cc.get("Saturation"):
        im = ImageEnhance.Color(im).enhance(1.0 + float(cc["Saturation"]))
    t = cc.get("TintColor")
    if t:
        r, g, b = im.split()
        r = r.point(lambda v: v * t[0]); g = g.point(lambda v: v * t[1]); b = b.point(lambda v: v * t[2])
        im = Image.merge("RGB", (r, g, b))
    im.save(png_path)
    return png_path
