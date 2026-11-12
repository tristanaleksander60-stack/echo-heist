"""Marketing CONCEPT renders: the icon and the T1-T5 thumbnail briefs of docs/marketing/ICON_THUMBNAILS.md, staged in
Blender from the exported kit, Gus v0 and stand-in figures, lit with the Eevee "Heist Night" approximation.

    python3 tools/blender/marketing_renders.py [--only icon|icon_evergreen|T1|T2|T3|T4|T5] [--scale 1.0]
                                               [--samples 32] [--no-sheet] [--truecolor]

Writes docs/marketing/concepts/<name>_concept.png (icon 1024 x 1024, thumbnails 1920 x 1080; 256 colours + dither to
keep git small, --truecolor for 24-bit), a downscaled preview
next to each (<name>_concept_64.png for the icon, <name>_concept_160x90.png for thumbnails) and review_sheet.png
(every preview at real size, 3x nearest, greyscale and a 1 %-width blur: the ICON_THUMBNAILS section 7 size tests).

These are DIRECTION concepts only. Every image that ships is a real in-game capture (MASTERPLAN 9.4, ICON_THUMBNAILS
section 1 "Truth gate"), so nothing here is ever uploaded. What is a stand-in:
  * the Rookie: a blocky R15-proportioned stand-in (flat cap, long striped scarf, smug side-eye) in place of the
    catalog avatar of CLIPS.md 3.1; the friends of T4 are the same stand-in in other jacket colours;
  * clones: the same figure stripped the way Avatars.luau strips a rig (no face, no scarf, hair + hat only) in the
    owner hue with an outline (bench candidate B, MASTERPLAN 6.5) and the age ramp (12 % dimmer per older run, solo
    drift toward violet); glyph badges, the loot sparkle, the "?" pop and the text are drawn in 2D after the render;
  * code-drawn effects: Gus's floor cone and flashlight light, the busted clone's glitch slices and tape ribbons,
    the T2 alarm beacon (no beacon exists in src/ yet: placeholder, like kit_preview's laser beams);
  * Heist Night: kit_preview's indigo world + warm key + cool rim in Eevee, then Bloom (threshold) and
    ColorCorrection (tint 235,230,255, contrast 0.12, saturation 0.1) applied in 2D. Studio captures decide.
Kit pieces come from assets/fbx exactly as exported, with the location atlas swap (kit_preview.place / style).
Each image renders in its own Blender process (pip bpy, Python 3.13), like kit_preview. Figures are staged by where
they land in the frame (frame / at_screen); EH_DRY=1 prints every head's screen position without rendering.
"""
import argparse, math, os, random, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402
import kit_preview as K  # noqa: E402
import eh_palette as P  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "docs", "marketing", "concepts")
CONFIG_CONE = (30.0, 45.0)   # Config.Heist GUARD_VISION_RANGE (studs), GUARD_VISION_HALF_ANGLE (deg)
FONTS = ("/usr/share/fonts/truetype/lilita/LilitaOne-Regular.ttf",          # the proposed OFL face, if installed
         "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf",           # OFL fallback: heavy caps
         "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")

H = P.HEX
CLONE = {k[-2:].upper(): h for k, h, _n, _g in P.CLONES}         # P1..P4
GLYPH = {k[-2:].upper(): g for k, _h, _n, g in P.CLONES}         # "●1" ...
INK, EXIT, GOLD, GOLD_HI, AMBER = H["ink"], H["exit"], H["gold"], H["gold_hi"], H["amber"]

# The Rookie stand-in: catalog-avatar colours, none in a reserved clone hue (STYLE_BIBLE 1.3). Checked with
# eh_palette: skin vs Heist Gold Oklab 0.155 and vs Torch Amber 0.162 (characters never read as loot, >= 0.15); scarf
# vs Alarm Red 0.208 (>= 0.20); skin luma 0.64 and jacket 0.48 vs the ground (<= 0.22): step >= 0.15. The Santa hat
# is Ribbon Burgundy with a snow trim (the trim carries the 64 px read, ICON_THUMBNAILS 3.1).
ROOKIE = {"skin": "#D69A78", "skin_lo": "#AC7458", "hair": "#4A372C", "cap": "#6E5A4A", "cap_hi": "#8A7462",
          "jacket": "#4F8A5B", "jacket_lo": "#3C6B46", "pants": "#4A5374", "shoe": "#2A2D3F",
          "scarf": "#963A3A", "scarf2": "#EDE2C8", "eye": "#F4F7FF", "pupil": "#1C1F3B", "brow": "#3A2A22",
          "mouth": "#6B2E2E", "santa": "#8C2F4B", "trim": "#EEF1FB"}
FRIENDS = {"P2": dict(ROOKIE, jacket="#B07A43", jacket_lo="#8C5F33", cap="#3B4A6B", scarf="#C0C3D5", scarf2="#3B4A6B"),
           "P3": dict(ROOKIE, jacket="#8A4E3C", jacket_lo="#6B3C2E", skin="#A8724F", skin_lo="#86593D",
                      cap="#2E2A50", scarf="#D8C8A8", scarf2="#1C7C48"),
           "P4": dict(ROOKIE, jacket="#5C6F8A", jacket_lo="#47566B", skin="#F0C4A0", hair="#C89A52",
                      cap="#7B5244", scarf="#2FBF71", scarf2="#EDE2C8")}


# ------------------------------------------------------------------ colour and materials
def lin(hexc, mul=1.0):
    return tuple(K._lin(hexc)[:3][i] * mul for i in range(3)) + (1.0,)


def hsv_shift(hexc, dim=0.0, hue_deg=0.0):
    """Age ramp: `dim` 0..1 darker, hue rotated by `hue_deg` (toward violet = +)."""
    import colorsys
    r, g, b = (int(hexc.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    r, g, b = colorsys.hsv_to_rgb((h + hue_deg / 360.0) % 1.0, s, v * (1.0 - dim))
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


_MATS = {}


def mat(hexc, rough=0.55, emit=0.0, alpha=1.0, cull=False, key=None):
    k = key or (hexc, rough, emit, alpha, cull)
    if k in _MATS:
        return _MATS[k]
    m = bpy.data.materials.new("MR_%s_%s" % (hexc, len(_MATS)))
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = lin(hexc)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = lin(hexc)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    m.use_backface_culling = cull
    m.diffuse_color = lin(hexc)
    _MATS[k] = m
    return m


# ------------------------------------------------------------------ mesh helpers (bmesh, so no operator context)
def _obj(name, bm, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, seg=1, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(material)
    o.parent = parent
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    if bevel:
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = seg
        m.limit_method = "ANGLE"
    return o


def box(name, size, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.08, seg=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return _obj(name, bm, material, parent, loc, rot, bevel, seg)


def cyl(name, r1, r2, depth, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), seg=16, bevel=0.0, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    return _obj(name, bm, material, parent, loc, rot, bevel, 2)


def ball(name, r, material, parent=None, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), seg=(12, 8)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg[0], v_segments=seg[1], radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    return _obj(name, bm, material, parent, loc, rot, smooth=True)


def ring(name, major, minor, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), seg=(16, 8)):
    bm = bmesh.new()
    rings = []
    for i in range(seg[0]):
        a = 2 * math.pi * i / seg[0]
        rr = []
        for j in range(seg[1]):
            b = 2 * math.pi * j / seg[1]
            p = Vector(((major + minor * math.cos(b)) * math.cos(a), (major + minor * math.cos(b)) * math.sin(a),
                        minor * math.sin(b)))
            rr.append(bm.verts.new(Vector((p.x * scale[0], p.y * scale[1], p.z * scale[2]))))
        rings.append(rr)
    for i in range(seg[0]):
        for j in range(seg[1]):
            a, b = rings[i], rings[(i + 1) % seg[0]]
            bm.faces.new((a[j], b[j], b[(j + 1) % seg[1]], a[(j + 1) % seg[1]]))
    return _obj(name, bm, material, parent, loc, rot, smooth=True)


def empty(name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    e.rotation_euler = [math.radians(a) for a in rot]
    return e


def yaw_to(src, dst):
    """Blender Z rotation (deg) that turns a model whose front is -Y at `src` to face `dst`."""
    dx, dy = dst[0] - src[0], dst[1] - src[1]
    return math.degrees(math.atan2(dx, -dy))


# ------------------------------------------------------------------ figures: the Rookie stand-in and clone mannequins
POSES = {   # joint: (rx, ry, rz) degrees. Figure faces -Y; its right side is -X. -rx raises a limb forward.
    "stand": {},
    "smug_icon": {"neck": (-6, 4, 18), "shL": (-12, -96, 0), "elL": (0, -100, 0), "shR": (4, 8, 0)},
    "carry": {"shR": (-28, -14, 0), "elR": (-46, 0, 0), "shL": (-28, 14, 0), "elL": (-46, 0, 0)},
    "carry_walk": {"shR": (-26, -14, 0), "elR": (-46, 0, 0), "shL": (-26, 14, 0), "elL": (-46, 0, 0),
                   "hipR": (-22, 0, 0), "knR": (14, 0, 0), "hipL": (16, 0, 0), "knL": (22, 0, 0), "waist": (6, 0, 0)},
    "bag_up": {"shL": (-30, -62, 0), "elL": (-95, 0, 0), "shR": (6, 10, 0), "neck": (4, 0, 14), "waist": (0, 0, -6)},
    "bag_out": {"shL": (-30, -46, 0), "elL": (-34, 0, 0), "shR": (4, 8, 0), "neck": (2, 0, -16), "waist": (0, 0, 6)},
    "shock": {"shR": (-38, 52, 0), "elR": (-118, 0, 0), "shL": (-38, -52, 0), "elL": (-118, 0, 0),
              "neck": (-10, 0, 0), "waist": (-6, 0, 0)},
    "victory": {"shR": (0, 152, 0), "elR": (0, 18, 0), "shL": (0, -152, 0), "elL": (0, -18, 0), "neck": (-10, 0, 0)},
    "fist": {"shR": (-4, 176, 0), "elR": (0, 0, 0), "shL": (0, -10, 0), "neck": (-12, 0, 0)},
    "tiptoe": {"hipR": (-34, 0, 0), "knR": (48, 0, 0), "hipL": (8, 0, 0), "shR": (-20, 10, 0), "elR": (-70, 0, 0),
               "shL": (30, -14, 0), "elL": (-20, 0, 0), "waist": (10, 0, 6), "neck": (-4, 0, -22)},
    "busted": {"shR": (-20, 70, 0), "elR": (-60, 0, 0), "shL": (-10, -80, 0), "elL": (-50, 0, 0), "waist": (-10, 0, 8),
               "neck": (-14, 0, 10), "hipR": (-12, 0, 0), "hipL": (10, 0, 0)},
}


def _face(head, R, expr, look=1):
    """Simple stand-in face on the cylinder head (front -Y, radius 0.62). expr: smug | shock."""
    eye, pupil, brow, mouth = mat(R["eye"], 0.3), mat(R["pupil"], 0.3), mat(R["brow"]), mat(R["mouth"])
    for side in (-1, 1):                       # -1 = the figure's right (-X)
        ex = 0.235 * side
        ez = 0.06
        if expr == "shock":
            ball("eye", 0.165, eye, head, (ex, -0.565, ez), (1.0, 0.35, 1.18))
            ball("pupil", 0.06, pupil, head, (ex, -0.63, ez - 0.01), (1, 0.4, 1))
            box("brow", (0.30, 0.07, 0.075), mat(R["brow"]), head, (ex, -0.6, ez + 0.3), (0, 18 * side, 0), 0.02)
        else:                                  # smug side-eye: pupils hard to the figure's left, heavy lids
            ball("eye", 0.15, eye, head, (ex, -0.57, ez), (1.0, 0.35, 0.9))
            ball("pupil", 0.085, pupil, head, (ex + 0.075 * look, -0.625, ez - 0.035), (1, 0.4, 1))
            box("lid", (0.36, 0.1, 0.12), mat(R["skin"]), head, (ex, -0.595, ez + 0.09), (0, -6 * side, 0), 0.03)
            box("lash", (0.36, 0.1, 0.035), brow, head, (ex, -0.605, ez + 0.03), (0, -6 * side, 0), 0.0)
            up = side != look                  # one brow raised (inner end up), the other low and flat
            box("brow", (0.32, 0.08, 0.08), brow, head, (ex, -0.61, ez + (0.33 if up else 0.2)),
                (0, (10 if up else -4) * side, 0), 0.02)
    if expr == "shock":
        ball("mouth", 0.13, mouth, head, (0.0, -0.585, -0.29), (0.85, 0.35, 1.05))
    else:                                      # smirk: a line rising to the figure's left
        box("mouth", (0.34, 0.07, 0.08), mouth, head, (-0.03 * look, -0.6, -0.28), (0, 8 * look, 0), 0.02)
        box("mouth2", (0.15, 0.07, 0.08), mouth, head, (-0.22 * look, -0.575, -0.225), (0, 40 * look, 0), 0.02)


def figure(name, pos, yaw, pose="stand", clone=None, dim=0.0, hue=0.0, colors=None, expr="smug", hat="cap",
           scarf=True, outline=True, shadow=True, look=1):
    """A 5.2-stud R15-proportioned figure. clone=<hex> makes the stripped clone look (no face, no scarf, hair + hat
    in the hue, glow + outline); else the Rookie stand-in with `colors`. Returns {joint/part name: object}."""
    R = colors or ROOKIE
    pose = POSES[pose] if isinstance(pose, str) else pose
    hue_hex = hsv_shift(clone, dim, hue) if clone else None
    if clone:
        white = clone == CLONE["P4"]          # Ghost White is a glow only: keep its form readable, don't clip it
        body = mat(hue_hex, 0.45, emit=0.45 if white else 1.0, key=("body", hue_hex))
        body.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin(hue_hex, 0.4)
        M = {k: body for k in ("skin", "skin_lo", "hair", "cap", "cap_hi", "jacket", "jacket_lo", "pants", "shoe",
                               "santa", "trim")}
    else:
        M = {k: mat(v) for k, v in R.items()}
    J = {}
    root = empty(name, None, pos, (0, 0, yaw))
    J["root"] = root

    def joint(key, parent, loc):
        J[key] = empty(f"{name}_{key}", parent, loc, pose.get(key, (0, 0, 0)))
        return J[key]

    pelvis = joint("pelvis", root, (0, 0, 2.0))
    waist = joint("waist", pelvis, (0, 0, 0))
    parts = []
    parts.append(box("torso", (2.0, 1.0, 2.0), M["jacket"], waist, (0, 0, 1.0), bevel=0.12))
    if not clone:
        parts.append(box("hem", (2.04, 1.04, 0.3), M["jacket_lo"], waist, (0, 0, 0.15), bevel=0.06))
        parts.append(box("zip", (0.08, 0.06, 1.6), M["jacket_lo"], waist, (0.0, -0.51, 1.05), bevel=0.0))
    neck = joint("neck", waist, (0, 0, 2.0))
    head = cyl("head", 0.62, 0.62, 1.18, M["skin"], neck, (0, 0, 0.62), bevel=0.16)
    parts.append(head)
    parts.append(box("hair", (1.22, 0.5, 0.72), M["hair"], neck, (0, 0.36, 0.86), bevel=0.14))
    if not clone:
        _face(head, R, expr, look)
    if hat == "cap":
        parts.append(cyl("cap", 0.70, 0.66, 0.30, M["cap"], neck, (0, 0.04, 1.27), (5, 0, 0), bevel=0.08, seg=20,
                         scale=(1.0, 1.08, 1.0)))
        parts.append(box("brim", (1.06, 0.5, 0.1), M["cap_hi"] if not clone else M["cap"], neck, (0, -0.66, 1.13),
                         (-12, 0, 0), bevel=0.04))
    elif hat == "santa":
        parts.append(ring("trim", 0.62, 0.16, M["trim"], neck, (0, 0, 1.2)))
        cone1 = cyl("santa", 0.6, 0.36, 0.62, M["santa"], neck, (0, 0.04, 1.55), (12, 0, 0), seg=14)
        parts.append(cone1)
        cone2 = cyl("santa2", 0.36, 0.1, 0.62, M["santa"], neck, (0.0, 0.32, 2.02), (58, -12, 0), seg=12)
        parts.append(cone2)
        parts.append(ball("pom", 0.2, M["trim"], neck, (0.12, 0.72, 2.12)))
    if scarf and not clone:
        s1, s2 = mat(R["scarf"]), mat(R["scarf2"])
        parts.append(ring("scarf", 0.6, 0.2, s1, neck, (0, 0, 0.06), scale=(1.12, 0.95, 1.0)))
        for i in range(4):   # the long tail down the chest, striped, on the figure's left
            parts.append(box(f"tail{i}", (0.44, 0.16, 0.36), s2 if i % 2 else s1, waist, (0.42, -0.6, 1.72 - 0.37 * i),
                             (0, 0, 0), bevel=0.04))
        for i in range(3):   # the other tail thrown back over the right shoulder
            parts.append(box(f"back{i}", (0.42, 0.36, 0.16), s1 if i % 2 else s2, waist,
                             (-0.55, 0.62 + 0.05 * i, 1.78 - 0.34 * i), (8, 0, 0), bevel=0.04))
    for side, key in ((-1, "R"), (1, "L")):
        sh = joint("sh" + key, waist, (1.5 * side, 0, 1.85))
        parts.append(box("uarm" + key, (0.92, 0.92, 1.0), M["jacket"], sh, (0, 0, -0.43), bevel=0.1))
        el = joint("el" + key, sh, (0, 0, -0.93))
        parts.append(box("larm" + key, (0.9, 0.9, 0.82), M["jacket"], el, (0, 0, -0.36), bevel=0.1))
        parts.append(box("hand" + key, (0.78, 0.78, 0.34), M["skin"], el, (0, 0, -0.9), bevel=0.1))
        J["hand" + key] = empty(f"{name}_hand{key}", el, (0, 0, -1.0))
        hip = joint("hip" + key, pelvis, (0.5 * side, 0, 0))
        parts.append(box("uleg" + key, (0.96, 0.96, 1.02), M["pants"], hip, (0, 0, -0.5), bevel=0.08))
        kn = joint("kn" + key, hip, (0, 0, -1.0))
        parts.append(box("lleg" + key, (0.94, 0.94, 0.74), M["pants"], kn, (0, 0, -0.4), bevel=0.08))
        parts.append(box("shoe" + key, (0.98, 1.16, 0.3), M["shoe"], kn, (0, -0.08, -0.86), bevel=0.08))
    for o in parts:
        o.visible_shadow = shadow and not clone      # clones: CastShadow = false (MASTERPLAN 6.5 #2)
    if clone and outline:
        hull = mat(hsv_shift(clone, dim * 0.6, hue), 0.5, emit=1.6 if white else 3.2, cull=True,
                   key=("hull", clone, dim, hue))
        for o in parts:
            o.data.materials.append(hull)
            sol = o.modifiers.new("hull", "SOLIDIFY")
            sol.thickness = 0.055
            sol.offset = 1.0
            sol.use_flip_normals = True
            sol.material_offset = 1
            sol.use_rim = False
    J["parts"] = parts
    J["head"] = head
    return J


def hold(J, model, hand="L", off=(0, 0, 0), rot=(0, 0, 0), loc="ToyShop", xmas=False, scale=1.0, parent=None,
         hang=False):
    """Kit loot in a figure's hand. hang=True: upright, its top in the hand (a bag held by the neck), `off` in world
    axes; else parented to `parent` (a joint key, e.g. 'waist' for a two-hand carry) or the hand, `off` local."""
    objs = K.place(model, (0, 0, 0), 0, (), xmas, loc)
    if hang:
        bpy.context.view_layer.update()
        top = max((o.matrix_world @ Vector(c)).z for o in objs for c in o.bound_box)
        hp = J["hand" + hand].matrix_world.translation + Vector(off)
        yaw = J["root"].rotation_euler.z + math.radians(rot[2])
        m = Matrix.Translation(hp - Vector((0, 0, top * scale))) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)
        for o in objs:
            o.matrix_world = m @ o.matrix_world
        return objs
    par = J[parent] if parent else J["hand" + hand]
    for o in objs:
        o.parent = par
        o.matrix_parent_inverse = Matrix.Identity(4)
        base = o.matrix_basis.copy()
        o.matrix_basis = (Matrix.Translation(Vector(off)) @ Matrix.Rotation(math.radians(rot[2]), 4, "Z") @
                          Matrix.Rotation(math.radians(rot[0]), 4, "X") @ Matrix.Scale(scale, 4) @ base)
    return objs


# ------------------------------------------------------------------ Gus v0 (kit FBX, rigid parts posed at their joints)
GUS_POSES = {
    "patrol": {"Gus_RightUpperArm": (-55, 0, 0), "Gus_RightHand": (50, 0, 0)},
    "aim": {"Gus_RightUpperArm": (-72, 0, 6), "Gus_RightLowerArm": (-6, 0, 0), "Gus_RightHand": (66, 0, 0)},
    "doubletake": {"Gus_UpperTorso": (-8, 4, 24), "Gus_Head": (-10, 10, 44), "Gus_RightUpperArm": (-62, 0, 10),
                   "Gus_RightHand": (52, 0, 0), "Gus_LeftUpperArm": (-40, 0, -70), "Gus_LeftLowerArm": (-95, 0, 0),
                   "Gus_LeftUpperLeg": (8, 0, 0), "Gus_RightUpperLeg": (-12, 0, 0), "Gus_RightLowerLeg": (10, 0, 0)},
    "away": {"Gus_RightUpperArm": (-60, 0, 0), "Gus_RightHand": (55, 0, 0), "Gus_Head": (0, 0, 10)},
}


def gus(pos, yaw, pose="patrol", santa=False, loc="CornerShop"):
    objs = K.place("Gus", (0, 0, 0), 0, ("hide:Gus_Cap",) if santa else (), santa, loc)
    if santa:
        objs += K.place("Gus_SantaHat", (0, 0, 0), 0, ("xmas",), True, loc)
    by = {o.name.split(".")[0]: o for o in objs}
    root = empty("GusRoot")
    for name, o in by.items():
        spec = K.MANIFEST.get(name, {})
        par = (spec.get("joint") or {}).get("parent")
        p = by.get(par) if par else None
        if name == "Gus_SantaHat":
            p = by["Gus_Head"]
        p = p or root
        o.parent = p
        o.matrix_parent_inverse = p.matrix_world.inverted()
    for name, r in GUS_POSES[pose].items():
        if name in by:
            by[name].rotation_euler = [math.radians(a) for a in r]
    root.location = pos
    root.rotation_euler = (0, 0, math.radians(yaw))
    bpy.context.view_layer.update()
    return by


def flashlight(by, target, length=None, half=None, cone=True, energy=1800):
    """Gus's code-drawn light: a SpotLight from the lens at `target` (the v0.1 guard parents one to the head) and the
    flat Torch Amber floor fan (Transparency 0.75 + Neon edge) along his facing."""
    lens = by["Gus_FlashlightLens"]
    p = lens.matrix_world.translation.copy()
    t = Vector(target)
    ld = bpy.data.lights.new("torch", "SPOT")
    ld.color = lin(AMBER)[:3]
    ld.energy = energy
    ld.spot_size = math.radians(34)
    ld.spot_blend = 0.5
    ld.shadow_soft_size = 0.15
    o = bpy.data.objects.new("torch", ld)
    bpy.context.scene.collection.objects.link(o)
    o.location = p
    o.rotation_euler = (t - p).to_track_quat("-Z", "Y").to_euler()
    if not cone:
        return o
    rng, ha = length or CONFIG_CONE[0], math.radians(half or CONFIG_CONE[1])
    root = by["Gus_LowerTorso"].matrix_world.translation
    base = Vector((root.x, root.y, 0.07))
    d = Vector((t.x - base.x, t.y - base.y, 0)).normalized()
    a0 = math.atan2(d.y, d.x)
    bm = bmesh.new()
    c = bm.verts.new(base)
    n = 24
    angs = [a0 - ha + 2 * ha * i / n for i in range(n + 1)]
    arc = [bm.verts.new(base + Vector((math.cos(a), math.sin(a), 0)) * rng) for a in angs]
    for i in range(n):
        bm.faces.new((c, arc[i], arc[i + 1]))
    _obj("cone", bm, mat(AMBER, 0.9, emit=0.6, alpha=0.25)).visible_shadow = False
    edge = mat(AMBER, 0.5, emit=2.2)
    for a in (a0 - ha, a0 + ha):
        L = rng * 0.98
        box("cone_edge", (L, 0.09, 0.03), edge, None, base + Vector((math.cos(a), math.sin(a), 0)) * L / 2,
            (0, 0, math.degrees(a)), bevel=0).visible_shadow = False
    return o


# ------------------------------------------------------------------ scene, lights, camera
ANN = []   # 2D annotations drawn after the render: (kind, world position, params)


def reset(samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    K._ATLAS.clear()
    _MATS.clear()
    ANN.clear()
    s = bpy.context.scene
    s.world = bpy.data.worlds.new("EH_World")
    s.view_settings.view_transform = "Standard"
    s.view_settings.exposure = 0.2                      # ExposureCompensation 0.2
    s.render.engine = "BLENDER_EEVEE"
    s.eevee.taa_render_samples = samples
    s.eevee.use_shadows = True
    s.render.film_transparent = False
    w = s.world
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = K._lin("#373760")   # Ambient (55,55,95)
    bg.inputs["Strength"].default_value = 0.9
    return s


def kit(model, pos, rot=0, flags=(), xmas=False, loc="CornerShop"):
    return K.place(model, pos, rot, tuple(flags), xmas, loc)


def floor(x0, x1, y0, y1, loc, xmas=False):
    for x in range(x0, x1, 8):
        for y in range(y0, y1, 8):
            kit("Floor_8x8", (x, y, 0), 0, (), xmas, loc)


def table(cx, cy, size=200):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2)
    _obj("table", bm, mat(INK, 0.8), None, (cx, cy, -0.55))


def light(kind, pos, target, hexc, energy, size=0.5, spot=70, blend=0.6, shadow=True):
    ld = bpy.data.lights.new(kind, kind)
    ld.color = lin(hexc)[:3]
    ld.energy = energy
    ld.use_shadow = shadow
    if kind == "SPOT":
        ld.spot_size = math.radians(spot)
        ld.spot_blend = blend
        ld.shadow_soft_size = size
    elif kind == "AREA":
        ld.size = size
    else:
        ld.shadow_soft_size = size
    o = bpy.data.objects.new(kind, ld)
    bpy.context.scene.collection.objects.link(o)
    o.location = pos
    if target is not None:
        o.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    return o


def camera(s, pos, target, vfov, W, Hh, roll=0.0):
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    s.collection.objects.link(cam)
    s.camera = cam
    cam.location = pos
    q = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y")
    cam.rotation_euler = q.to_euler()
    if roll:
        cam.rotation_euler.rotate_axis("Z", math.radians(roll))
    cd.sensor_fit = "VERTICAL"
    cd.angle_y = math.radians(vfov)
    cd.clip_start = 0.1
    cd.clip_end = 600
    s.render.resolution_x, s.render.resolution_y = W, Hh
    s.render.resolution_percentage = 100
    return cam


def frame(pos, subject, sx, sy, vfov, W, Hh):
    """Look-at point that puts `subject` at screen (sx, sy) (0..1 from the top-left) from `pos`, no roll."""
    d = Vector(subject) - Vector(pos)
    head = math.atan2(d.x, d.y)
    pitch = math.atan2(d.z, math.hypot(d.x, d.y))
    tv = math.tan(math.radians(vfov) / 2)
    head -= math.atan((2 * sx - 1) * tv * W / Hh)
    pitch -= math.atan((1 - 2 * sy) * tv)
    return Vector(pos) + Vector((math.sin(head) * math.cos(pitch), math.cos(head) * math.cos(pitch), math.sin(pitch)))


def at_screen(cam, sx, depth, W, Hh, z=4.6):
    """The floor point (x, y) whose figure's head (height z) lands at screen x `sx`, `depth` studs down the view
    axis: staging by the frame."""
    bpy.context.view_layer.update()
    tv = math.tan(cam.data.angle_y / 2)
    R, o = cam.matrix_world.to_3x3(), cam.matrix_world.translation
    X = (2 * sx - 1) * depth * tv * W / Hh
    Y = (z - o.z - R[2][0] * X + R[2][2] * depth) / R[2][1]
    p = o + R @ Vector((X, Y, -depth))
    return (p.x, p.y)


def mark(kind, obj_or_pos, **kw):
    ANN.append((kind, obj_or_pos, kw))


def head_top(J, up=0.35):
    return J["neck"].matrix_world @ Vector((0, 0, 1.55 + up))


def project(s, cam):
    bpy.context.view_layer.update()
    out = []
    W, Hh = s.render.resolution_x, s.render.resolution_y
    for kind, p, kw in ANN:
        if callable(p):
            p = p()
        if hasattr(p, "matrix_world"):
            p = p.matrix_world.translation
        v = world_to_camera_view(s, cam, Vector(p))
        out.append({"kind": kind, "x": v.x * W, "y": (1 - v.y) * Hh, "depth": v.z, **kw})
    return out


# ------------------------------------------------------------------ 2D finish (Bloom, ColorCorrection, overlays, text)
def _font(size):
    from PIL import ImageFont
    for f in FONTS:
        if os.path.isfile(f):
            return ImageFont.truetype(f, size), f
    return ImageFont.load_default(), "default"


def _rgb(h):
    return tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))


def finish(raw, out, notes, text=None, vignette=0.16, tag=True, tag_alpha=110, truecolor=False):
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    im = Image.open(raw).convert("RGB")
    W, Hh = im.size
    a = np.asarray(im).astype(np.float32) / 255.0
    # Bloom (Intensity 0.8, Threshold 1.0): only the clipped glow (Neon, clone outlines) blooms.
    peak = a.max(axis=2, keepdims=True)
    bright = np.clip((peak - 0.86) / 0.14, 0, 1) * a
    bi = Image.fromarray((bright * 255).astype(np.uint8))
    bloom = sum(w * np.asarray(bi.filter(ImageFilter.GaussianBlur(Hh * r))).astype(np.float32) / 255.0
                for w, r in ((0.45, 0.004), (0.4, 0.014), (0.3, 0.04)))
    a = 1 - (1 - a) * (1 - np.clip(bloom * 0.9, 0, 1))
    # ColorCorrection: Tint (235,230,255), Contrast 0.12, Saturation 0.1
    a = a * (np.array([235, 230, 255], np.float32) / 255.0)
    a = np.clip((a - 0.5) * 1.12 + 0.5, 0, 1)
    g = (a * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(axis=2, keepdims=True)
    a = np.clip(g + (a - g) * 1.1, 0, 1)
    if vignette:
        yy, xx = np.mgrid[0:Hh, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - Hh / 2) / (Hh / 2)) ** 2) / math.sqrt(2)
        a = a * (1 - vignette * np.clip((r - 0.45) / 0.55, 0, 1) ** 1.6)[..., None]
    img = Image.fromarray((a * 255).astype(np.uint8)).convert("RGBA")
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d, dg = ImageDraw.Draw(over), ImageDraw.Draw(glow)
    for n in notes:
        if n["depth"] <= 0:
            continue
        x, y = n["x"], n["y"]
        if n["kind"] == "sparkle":          # the loot sparkle shape (gold = sparkle, STYLE_BIBLE 1.3)
            r = n.get("r", 0.03) * Hh
            for k, rr, col in ((dg, r * 1.5, _rgb(GOLD) + (200,)), (d, r, _rgb(GOLD_HI) + (255,)),
                               (d, r * 0.42, (255, 255, 255, 255))):
                w = rr * 0.24
                k.polygon([(x, y - rr), (x + w, y - w), (x + rr, y), (x + w, y + w), (x, y + rr), (x - w, y + w),
                           (x - rr, y), (x - w, y - w)], fill=col)
            if n.get("small"):
                for dx, dy, f in n["small"]:
                    rr = r * f
                    w = rr * 0.26
                    cx, cy = x + dx * Hh, y + dy * Hh
                    d.polygon([(cx, cy - rr), (cx + w, cy - w), (cx + rr, cy), (cx + w, cy + w), (cx, cy + rr),
                               (cx - w, cy + w), (cx - rr, cy), (cx - w, cy - w)], fill=_rgb(GOLD_HI) + (255,))
        elif n["kind"] == "badge":          # glyph + number + hue (STYLE_BIBLE 1.2), 28 px in game: ~36 px at 1080p
            h = n.get("h", 0.034) * Hh
            col = _rgb(n["hue"])
            f, _ = _font(int(h * 0.78))
            num = n["glyph"][1:]
            tw = d.textlength(num, font=f)
            w = h * 1.05 + tw + h * 0.35
            x0, y0 = x - w / 2, y - h
            d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=h / 2, fill=_rgb(INK) + (225,),
                                outline=col + (255,), width=max(2, int(h * 0.08)))
            cx, cy, rr = x0 + h * 0.55, y0 + h / 2, h * 0.27
            shape = n["glyph"][0]
            if shape == "●":
                d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (255,))
            elif shape == "■":
                d.rectangle([cx - rr * 0.9, cy - rr * 0.9, cx + rr * 0.9, cy + rr * 0.9], fill=col + (255,))
            elif shape == "▲":
                d.polygon([(cx, cy - rr * 1.1), (cx + rr * 1.1, cy + rr * 0.85), (cx - rr * 1.1, cy + rr * 0.85)],
                          fill=col + (255,))
            else:
                d.polygon([(cx, cy - rr * 1.2), (cx + rr, cy), (cx, cy + rr * 1.2), (cx - rr, cy)], fill=col + (255,))
            d.text((x0 + h * 0.95, cy), num, font=f, fill=_rgb(EXIT) + (255,), anchor="lm")
        elif n["kind"] == "pop":            # Gus's "?" / "!" pop (real UI)
            r = n.get("r", 0.05) * Hh
            fill = _rgb(n.get("fill", EXIT))
            d.ellipse([x - r, y - r * 2.1, x + r, y - r * 0.1], fill=fill + (255,), outline=_rgb(INK) + (255,),
                      width=max(3, int(r * 0.12)))
            d.polygon([(x - r * 0.3, y - r * 0.32), (x + r * 0.25, y - r * 0.3), (x - r * 0.05, y + r * 0.35)],
                      fill=fill + (255,))
            f, _ = _font(int(r * 1.45))
            d.text((x, y - r * 1.1), n["glyph"], font=f, fill=_rgb(n.get("ink", INK)) + (255,), anchor="mm")
    glow = glow.filter(ImageFilter.GaussianBlur(Hh * 0.006))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, over)
    if text:
        img = draw_text(img, text)
    if tag:                                  # keeps a concept from being uploaded by mistake (corner, metadata zone)
        f, _ = _font(max(12, int(Hh * 0.018)))
        dd = ImageDraw.Draw(img)
        dd.text((W - Hh * 0.02, Hh - Hh * 0.018), "CONCEPT RENDER, NOT A CAPTURE", font=f,
                fill=(244, 247, 255, tag_alpha), anchor="rd")
    img = img.convert("RGB")
    if truecolor:
        img.save(out, optimize=True)
    else:   # 256 colours + dither keeps a 1080p concept near 0.5 MB in git (24-bit is ~1.6 MB)
        img.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(
            out, optimize=True)
    return img


def draw_text(img, spec):
    """<= 3 words, heavy caps, Getaway White fill, Ink Indigo outline 9 px, the key word in Clone Cyan, cap height
    ~110 px at 1080p, in the upper third (ICON_THUMBNAILS 1 and 2)."""
    from PIL import Image, ImageDraw, ImageFilter
    W, Hh = img.size
    cap = spec.get("cap", 0.105) * Hh
    f, path = _font(10)
    probe = ImageDraw.Draw(Image.new("L", (10, 10)))
    bb = probe.textbbox((0, 0), "H", font=f, anchor="ls")
    size = int(10 * cap / max(1, -bb[1]))
    f, path = _font(size)
    stroke = max(6, int(Hh * 0.0085))
    lines = spec["lines"]                     # [[(word, hex), ...], ...]
    lh = cap * 1.32
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ds, do = ImageDraw.Draw(shadow), ImageDraw.Draw(over)
    space = do.textlength(" ", font=f) * 0.9
    for i, line in enumerate(lines):
        widths = [do.textlength(w, font=f) for w, _c in line]
        total = sum(widths) + space * (len(line) - 1)
        ax = spec.get("x", 0.5) * W
        x = {"l": ax, "c": ax - total / 2, "r": ax - total}[spec.get("align", "c")]
        y = spec.get("y", 0.2) * Hh + i * lh
        for (word, col), w in zip(line, widths):
            ds.text((x + stroke * 0.4, y + stroke * 0.9), word, font=f, fill=_rgb(INK) + (210,), anchor="ls",
                    stroke_width=stroke, stroke_fill=_rgb(INK) + (210,))
            do.text((x, y), word, font=f, fill=_rgb(col) + (255,), anchor="ls", stroke_width=stroke,
                    stroke_fill=_rgb(INK) + (255,))
            x += w + space
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(stroke * 0.9)))
    return Image.alpha_composite(img, over)


# ------------------------------------------------------------------ the images
def icon(s, W, xmas=True):
    """ICON_THUMBNAILS 3: the Rookie's face, smug side-eye, two cyan copies of him fanned up-left behind, the vault
    dial ring as a warm halo behind his head, one gold glint, no text. L6 scale room in front of the vault door: the
    camera sits on the line face -> dial, so the ring frames the head (a camera at chin height puts it at his neck)."""
    loc = "Bank"
    hat = "santa" if xmas else "cap"
    face = Vector((0.0, 0.0, 4.62))
    cpos = Vector((0.9, -9.0, 6.6))
    ray = face - cpos
    dial = cpos + ray * ((3.6 - cpos.z) / ray.z)                       # where the face -> dial line meets z = 3.6
    kit("VaultDoor", (dial.x - 8, dial.y + 0.67, 0), 0, (), xmas, loc)
    kit("Wall_8x12", (dial.x - 16, dial.y + 0.67, 0), 0, (), xmas, loc)
    kit("Wall_8x12", (dial.x + 8, dial.y + 0.67, 0), 0, (), xmas, loc)
    floor(-16, 16, -16, 8, loc)
    table(0, 0)
    cam = camera(s, cpos, frame(cpos, face, 0.56, 0.45, 30, W, W), 30, W, W)
    hero = figure("hero", (face.x, face.y, 0), yaw=yaw_to(face, cpos) - 26, pose="smug_icon", hat=hat, look=-1)
    hold(hero, "CashBag", "L", off=(0.0, -0.15, 0.25), rot=(0, 0, -30), loc=loc, scale=0.8, hang=True)
    mark("sparkle", lambda: hero["handL"].matrix_world.translation + Vector((-0.35, -0.7, -0.35)), r=0.05,
         small=[(0.045, 0.05, 0.4)])
    for o in bpy.data.objects:                 # the dial ring idles in Warm Marble shade: keep the glow warm, unclipped
        if o.name.startswith("VaultDoor_DialRing"):
            b = o.active_material.node_tree.nodes["Principled BSDF"]
            b.inputs["Emission Strength"].default_value = 1.6
    for i, (sx, depth) in enumerate(((0.37, 11.4), (0.20, 13.6))):    # newest first; older = dimmer, toward violet
        x, y = at_screen(cam, sx, depth, W, W)
        figure(f"c{i + 1}", (x, y, 0), yaw=yaw_to((x, y), cpos) - 10, clone=CLONE["P1"], dim=0.12 * i, hue=10 * i,
               hat=hat, pose="stand")
    light("SPOT", face + Vector((-4.5, -6.5, 4.5)), face + Vector((0.9, 0, -0.4)), "#FFD2A0", 1700, size=1.0, spot=27,
          blend=0.5)                                                                                 # warm key
    light("SPOT", face + Vector((3.2, 2.2, 2.6)), face + Vector((-0.6, -1.0, -0.6)), "#8C96FF", 900, size=0.8,
          spot=34)                                                                                   # cool rim
    light("POINT", dial + Vector((0.0, -0.9, 0.3)), None, "#FFD9A8", 300, size=1.0, shadow=False)     # dial spill
    light("AREA", cpos + Vector((0, -1, -2)), face, "#5A5C96", 120, size=5, shadow=False)            # indigo fill
    s.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
    return cam, None


def t1(s, W, Hh):
    """T1 "8 OF ME": the Rookie at the left third holding the till's cash bag, at the apex of a V of 7 cyan clones
    that recedes to the right, each holding a toy, candy or teddy; the lit Clone Party aisles behind. Christmas off
    (the single variable vs T5)."""
    loc = "ToyShop"
    floor(-32, 32, -24, 40, loc)
    for x in (-32, -24, -16, -8, 0, 8, 16, 24):
        kit("Wall_Window_8x12" if x in (-8, 16) else "Wall_8x12", (x, 33, 0), 0, (), False, loc)
    for x in (-9.5, 4.5, 18.5):
        for y in (14, 22):
            kit("Shelf_Gondola_8x2", (x, y, 0), 90, (), False, loc)
            for (name, z), dy in zip((("Toy", 0.45), ("Teddy", 2.25), ("Candy", 4.05)), (2.0, 4.5, 6.5)):
                kit(name, (x - 0.65, y + dy, z), 90, (), False, loc)
    for x, y in ((-2.5, 16), (11.5, 16), (-2.5, 26), (11.5, 26)):
        light("POINT", (x, y, 8.6), None, P.WARM_BULB, 1100, size=1.0)
    table(0, 10, 260)
    hpos = (-3.0, -5.0)
    hero = figure("hero", (*hpos, 0), yaw=40, pose="bag_out", look=-1)
    hold(hero, "CashBag", "L", off=(0.0, -0.05, 0.12), rot=(0, 0, -20), loc=loc, hang=True)
    mark("sparkle", lambda: hero["handL"].matrix_world @ Vector((0.0, 0.0, 0.0)) + Vector((0.45, -0.5, -0.45)),
         r=0.036, small=[(0.03, 0.04, 0.4)])
    cpos = (-0.6, -12.8, 4.9)
    face = (hpos[0], hpos[1], 4.6)
    cam = camera(s, cpos, frame(cpos, face, 0.30, 0.37, 40, W, Hh), 40, W, Hh)
    # The V of 7 to the right of the hero, apex nearest (the newest run), placed by where each head lands on screen.
    V = [(0.705, 10.5), (0.59, 13.5), (0.815, 13.5), (0.51, 17.0), (0.895, 17.0), (0.45, 21.0), (0.955, 21.0)]
    items = ["Candy", "Toy", "Teddy", "Teddy", "Toy", "Candy", "Toy"]
    for age, ((sx, sy), it) in enumerate(zip(V, items)):
        x, y = at_screen(cam, sx, sy, W, Hh)
        c = figure(f"c{age}", (x, y, 0), yaw=yaw_to((x, y), (cpos[0], cpos[1])), pose="carry", clone=CLONE["P1"],
                   dim=min(0.07 * age, 0.4), hue=min(25, age * 4.0))
        hold(c, it, parent="waist", off=(0, -1.15, -0.1 if it != "Candy" else 0.5), rot=(0, 0, 180), loc=loc,
             scale=0.8 if it == "Teddy" else 0.9)
    light("SPOT", (-10, -12, 11), (-3, -5, 4), "#FFD2A0", 5600, size=1.5, spot=40)
    light("AREA", (8, 20, 9), (-1, 0, 4), "#8C96FF", 2600, size=10)
    light("AREA", (1, -17, 4), (1, 2, 3), "#5A5C96", 1000, size=12, shadow=False)
    return cam, {"lines": [[("8", CLONE["P1"]), ("OF", EXIT), ("ME", EXIT)]], "x": 0.70, "y": 0.205, "align": "c"}


def t2(s, W, Hh):
    """T2 "BETRAYED!": the Rookie at the right third, shocked, caught in Gus's flashlight; a cyan clone robbing the
    till under the red alarm beacon at the left third; Gus small behind in the aisle."""
    loc = "ToyShop"
    floor(-40, 40, -24, 48, loc)
    table(0, 10, 300)
    cpos = (1.0, -13.0, 3.8)
    hpos = (4.2, -3.6)
    cam = camera(s, cpos, frame(cpos, (hpos[0], hpos[1], 4.6), 0.68, 0.40, 45, W, Hh), 45, W, Hh)
    tx, ty = at_screen(cam, 0.24, 15.0, W, Hh)
    gx, gy = at_screen(cam, 0.45, 20.0, W, Hh, z=5.3)
    back = ty + 9.0
    for x in range(-40, 40, 8):
        kit("Wall_Window_8x12" if x in (8, 24) else "Wall_8x12", (x, back - 1, 0), 0, (), False, loc)
    kit("Counter_8x4", (tx - 9.0, ty + 0.9, 0), 0, (), False, loc)
    kit("CashRegister", (tx - 3.0, ty + 2.9, 3.5), 25, ("hide:CashRegister_Drawer",), False, loc)
    kit("Shelf_8x2", (tx - 12, back - 3.2, 0), 0, (), False, loc)
    for sy in (gy - 6, gy + 2):
        kit("Shelf_Gondola_8x2", (gx + 5.0, sy, 0), 90, (), False, loc)
        kit("Shelf_Gondola_8x2", (gx - 3.6, sy + 4, 0), 90, (), False, loc)
    light("POINT", (gx, gy + 1, 8.5), None, P.WARM_BULB, 900, size=1)
    light("POINT", (tx - 4, ty + 2, 8.5), None, P.WARM_BULB, 500, size=1)
    clone = figure("traitor", (tx, ty, 0), yaw=yaw_to((tx, ty), cpos) + 18, pose="bag_up", clone=CLONE["P1"])
    hold(clone, "CashBag", "L", off=(0.0, -0.1, 0.15), rot=(180, 0, 0), loc=loc)
    mark("sparkle", lambda: clone["handL"].matrix_world @ Vector((0.0, 0.0, -1.85)), r=0.03, small=[(0.03, 0.03, 0.4)])
    # placeholder alarm beacon (code-drawn in game; none in src/ yet): red dome on a steel base + two light fans
    bx, by_, bz = tx - 2.0, back - 1.2, 7.6
    ball("beacon", 0.75, mat(H["alarm"], 0.3, emit=5.0), None, (bx, by_, bz), (1, 0.6, 0.8))
    box("beacon_base", (1.9, 0.5, 0.42), mat(H["steel_lo"]), None, (bx, by_ + 0.2, bz - 0.62))
    for ang in (-28, 208):
        a = math.radians(ang)
        L = 8.0
        beam = box("beacon_beam", (L, 0.05, 1.3), mat(H["alarm"], 0.9, emit=1.4, alpha=0.2), None,
                   (bx + math.cos(a) * L / 2, by_ - 0.3, bz + math.sin(a) * L / 2), (0, -ang, 0), bevel=0)
        beam.visible_shadow = False
    light("POINT", (bx, by_ - 2.0, bz - 1.5), None, H["alarm"], 3200, size=0.6)
    figure("hero", (*hpos, 0), yaw=yaw_to(hpos, cpos) - 12, pose="shock", expr="shock")
    g = gus((gx, gy, 0), yaw_to((gx, gy), hpos), pose="aim", loc=loc)
    flashlight(g, (hpos[0], hpos[1], 3.4), length=(Vector((gx, gy)) - Vector(hpos)).length + 2.5, half=20,
               energy=7000)
    mark("pop", lambda: g["Gus_Head"].matrix_world @ Vector((0, 0, 2.3)), glyph="!", r=0.026, fill=H["alarm"], ink=EXIT)
    light("SPOT", (cpos[0] + 9, cpos[1] + 2, 8), (hpos[0], hpos[1], 4.4), "#FFD2A0", 1500, size=1.2, spot=35)
    light("AREA", (tx - 2, back - 4, 10), (tx, ty, 3), "#8C96FF", 1400, size=10)
    light("AREA", (cpos[0], cpos[1] - 1, 4), (hpos[0], hpos[1], 3), "#5A5C96", 600, size=10, shadow=False)
    return cam, {"lines": [[("BETRAYED!", EXIT)]], "x": 0.07, "y": 0.205, "align": "l"}


def t3(s, W, Hh):
    """T3 "WRONG ONE!": Gus big at the right third, body still on the clone he just busted, head snapped round to us
    ("?" up); his cone on the busted clone (glitch slices + tape ribbons) at the centre; the Rookie small at the left
    third, sneaking out of the safe-room door with the night-deposit bag. L4 Night Clerk back room (Corner Shop)."""
    loc = "CornerShop"
    floor(-40, 40, -24, 48, loc)
    table(0, 10, 300)
    cpos = (0.0, -10.0, 2.6)
    cam = camera(s, cpos, (0.6, 10.0, 4.0), 48, W, Hh)
    gx, gy = at_screen(cam, 0.715, 11.0, W, Hh, z=5.3)
    bx, by_ = at_screen(cam, 0.43, 10.5, W, Hh, z=4.6)
    hx, hy = at_screen(cam, 0.235, 17.5, W, Hh, z=4.6)
    wall = hy + 2.2
    for x in range(-40, 40, 8):
        door = abs(x + 4 - hx) < 4.1 and x + 1 <= hx <= x + 7
        kit("Wall_Door_8x12" if door else "Wall_8x12", (x, wall - 1, 0), 0, ("hide:Wall_Door_8x12_Leaf",), False, loc)
    for x in range(-40, 40, 8):
        kit("Wall_8x12", (x, wall + 15, 0), 0, (), False, loc)          # the safe room behind the door
    kit("Safe", (hx - 1.5, wall + 7, 0), 15, (), False, loc)
    kit("Shelf_8x2", (gx - 1.0, wall - 3.2, 0), 0, (), False, loc)
    kit("Hide_Crate", (gx + 7.5, gy + 3.0, 0), -15, (), False, loc)
    kit("Hide_CoatRack", (hx - 6.5, wall - 3.0, 0), 0, (), False, loc)
    light("POINT", (bx + 2, by_ + 4, 8.6), None, P.WARM_BULB, 900, size=1)
    light("POINT", (hx, wall + 6, 7), None, P.WARM_BULB, 700, size=1)
    light("SPOT", (hx - 2.5, hy - 5.0, 8.5), (hx, hy, 3.4), "#FFD2A0", 1400, size=0.8, spot=30)   # the doorway pool
    hero = figure("hero", (hx, hy, 0), yaw=yaw_to((hx, hy), (hx - 6, hy - 6)), pose="tiptoe", look=-1)
    hold(hero, "CashBag", "R", off=(0.0, 0.0, 0.1), rot=(0, 0, 30), loc=loc, hang=True, scale=0.9)
    mark("sparkle", lambda: hero["handR"].matrix_world.translation + Vector((-0.35, -0.6, -0.55)), r=0.024)
    busted = figure("busted", (bx, by_, 0), yaw=yaw_to((bx, by_), (gx, gy)) - 25, pose="busted", clone=CLONE["P1"])
    glitch(busted)
    g = gus((gx, gy, 0), yaw_to((gx, gy), (bx, by_)) - 8, pose="doubletake", loc=loc)
    flashlight(g, (bx, by_, 2.6), length=(Vector((gx, gy)) - Vector((bx, by_))).length + 3.0, half=24, energy=3000)
    mark("pop", lambda: g["Gus_Head"].matrix_world.translation + Vector((0.5, 0, 2.5)), glyph="?", r=0.058)
    light("SPOT", (cpos[0] + 6, cpos[1] + 1, 9), (gx, gy, 5), "#FFD2A0", 2600, size=1.2, spot=40)
    light("AREA", (gx + 8, gy + 10, 9), (bx, by_, 3), "#8C96FF", 2200, size=10)
    light("AREA", (cpos[0], cpos[1] - 2, 4), (bx, by_, 3), "#5A5C96", 700, size=10, shadow=False)
    return cam, {"lines": [[("WRONG", EXIT), ("ONE!", CLONE["P1"])]], "x": 0.06, "y": 0.205, "align": "l"}


def glitch(J, seed=7):
    """Busted: glitch slices, then a tape-ribbon burst (<= 30 particles, MASTERPLAN 6.5 #6). Concept stand-in."""
    rnd = random.Random(seed)
    hue = CLONE["P1"]
    slice_m = mat(hue, 0.4, emit=2.6)
    tape = mat("#B8F6FF", 0.4, emit=1.8)
    root = J["root"].matrix_world.translation
    for z, dx, w in ((1.3, 0.55, 2.3), (2.9, -0.7, 2.6), (4.4, 0.45, 1.6)):
        box("slice", (w, 1.1, 0.16), slice_m, None, (root.x + dx, root.y, z), (0, 0, rnd.uniform(-30, 30)),
            bevel=0).visible_shadow = False
    for i in range(22):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(1.2, 3.2)
        z = rnd.uniform(0.8, 5.6)
        box("ribbon", (rnd.uniform(0.5, 1.3), 0.05, rnd.uniform(0.1, 0.2)), tape if i % 3 else slice_m, None,
            (root.x + math.cos(a) * r, root.y + math.sin(a) * r * 0.6, z),
            (rnd.uniform(-60, 60), rnd.uniform(-60, 60), math.degrees(a) + 90), bevel=0).visible_shadow = False


def t4(s, W, Hh):
    """T4 "16 ROBBERS": the Crew Line-up at the van, 4 players + 12 clones in 4 hues with glyph badges, one
    synchronized fist-up pose, the crowd read as one mass; the owner's Rookie front-left. Street in front of the
    Corner Shop."""
    loc = "CornerShop"
    floor(-48, 48, -32, 40, loc)
    table(0, 0, 320)
    shop_y = 19.0
    kit("Storefront_24x12", (-12, shop_y - 1, 0), 0, (), False, loc)
    for x in (-36, -28, -20, 12, 20, 28):
        kit("Wall_8x12", (x, shop_y - 1, 0), 0, (), False, loc)
    kit("Pillar_2x12", (-13, shop_y - 1, 0), 0, (), False, loc)
    kit("Pillar_2x12", (11, shop_y - 1, 0), 0, (), False, loc)
    kit("Van", (6.0, 9.5, 0), 180, (), False, loc)
    for x in (-6, 6):
        light("POINT", (x, shop_y - 3, 9), None, P.WARM_BULB, 1500, size=1)
    cpos = (-1.0, -19.0, 4.0)
    hpos = (-5.6, -8.6)
    cam = camera(s, cpos, frame(cpos, (hpos[0], hpos[1], 4.6), 0.21, 0.45, 50, W, Hh), 50, W, Hh)
    figure("hero", (*hpos, 0), yaw=yaw_to(hpos, cpos) + 12, pose="victory")
    # The other 15 in one arc behind him, grouped by crew so the 4 hues read: each friend (live: the stand-in in his
    # own outfit, no glow, no badge) in the middle of his 3 clones; the owner's 3 clones nearest the owner.
    order = [("P1", 0), ("P1", 1), ("P1", 2), ("P2", 0), ("P2", None), ("P2", 1), ("P2", 2), ("P3", 0), ("P3", None),
             ("P3", 1), ("P3", 2), ("P4", 0), ("P4", None), ("P4", 1), ("P4", 2)]
    n = len(order)
    for i, (pl, age) in enumerate(order):
        sx = 0.335 + i * (0.93 - 0.335) / (n - 1)
        u = (sx - 0.63) / 0.3
        x, y = at_screen(cam, sx, 18.8 - 2.6 * u * u, W, Hh)
        yaw = yaw_to((x, y), cpos) + (4 if i % 2 else -4)
        if age is None:
            figure(f"f{pl}", (x, y, 0), yaw, pose="fist", colors=FRIENDS[pl])
        else:
            J = figure(f"{pl}c{age}", (x, y, 0), yaw, pose="fist", clone=CLONE[pl], dim=0.06 * age,
                       hue=(age * 6 if pl == "P1" else 0))
            mark("badge", (lambda J=J: head_top(J, 0.4)), glyph=GLYPH[pl], hue=CLONE[pl], h=0.026)
    light("SPOT", (cpos[0] - 8, cpos[1] + 4, 13), (2, 2, 3), "#FFD2A0", 9000, size=1.5, spot=55)
    light("SPOT", (hpos[0] + 5, hpos[1] - 6, 8), (hpos[0], hpos[1], 3.6), "#FFD2A0", 2600, size=1.0, spot=34)
    light("AREA", (14, 22, 10), (2, 2, 4), "#8C96FF", 3600, size=12)
    light("AREA", (cpos[0], cpos[1] - 2, 5), (0, 0, 3), "#5A5C96", 1200, size=12, shadow=False)
    return cam, {"lines": [[("16", CLONE["P1"]), ("ROBBERS", EXIT)]], "x": 0.6, "y": 0.2, "align": "c"}


def t5(s, W, Hh):
    """T5 "STEAL BACK XMAS" (v1): DV04 Mistletoe Patrol, Christmas layer on. The Rookie in a catalog Santa hat carries
    the big present out of the back-room doorway toward the camera; his clone (hat silhouette) follows with the Ribbon
    present; Gus in his Santa hat small in the back room, facing the east wall. No tree in the shot."""
    loc = "CornerShop"
    xmas = True
    floor(-24, 24, -16, 32, loc, xmas)
    wall_y = 9.0
    for x, name in ((-20, "Wall_8x12"), (-12, "Wall_8x12"), (-4, "Wall_Door_8x12"), (4, "Wall_8x12"),
                    (12, "Wall_8x12")):
        kit(name, (x, wall_y - 1, 0), 0, ("hide:Wall_Door_8x12_Leaf",), xmas, loc)
    for x in (-12, 4, 12):
        kit("Xmas_Garland_8", (x, wall_y - 1, 0), 0, ("xmas",), xmas, loc)
    for x in (-12, 4):
        kit("Xmas_Lights_8", (x, wall_y - 1, 0), 0, ("xmas",), xmas, loc)
    kit("Xmas_Wreath", (8.0, wall_y - 0.38, 7.0), 0, ("xmas",), xmas, loc)
    for x in (-12, -4, 4):
        kit("Wall_8x12", (x, 27, 0), 0, (), xmas, loc)
    kit("Shelf_8x2", (-17, 5.2, 0), 0, (), xmas, loc)
    kit("Counter_8x4", (10, 1.0, 0), -90, (), xmas, loc)
    kit("CashRegister", (11.5, -2.5, 3.5), -90, (), xmas, loc)
    light("POINT", (-1, 2, 8.6), None, P.WARM_BULB, 650, size=1)
    kit("Lamp_Ceiling", (2, 18, 0), 0, (), xmas, loc)
    light("POINT", (2, 18, 8), None, P.WARM_BULB, 900, size=1)
    table(0, 8)
    hero = figure("hero", (-3.0, 0.6, 0), yaw=yaw_to((-3.0, 0.6), (1.6, -10.5)) - 10, pose="carry_walk", hat="santa",
                  look=-1)
    hold(hero, "Present", parent="waist", off=(0, -1.25, -0.3), rot=(0, 0, 8), loc=loc, xmas=xmas, scale=1.0)
    mark("sparkle", lambda: hero["waist"].matrix_world @ Vector((0.75, -1.5, 1.75)), r=0.03,
         small=[(-0.045, 0.03, 0.4)])
    c = figure("clone", (-0.6, 7.6, 0), yaw=yaw_to((-0.6, 7.6), (1, -9)), pose="carry_walk", clone=CLONE["P1"],
               hat="santa")
    hold(c, "Present", parent="waist", off=(0, -1.25, -0.3), rot=(0, 0, -10), loc=loc, xmas=xmas)
    g = gus((2.4, 19.5, 0), 145, pose="away", santa=True, loc=loc)
    flashlight(g, (14, 19.5, 2.0), length=9.0, energy=900)
    cam = camera(s, (1.6, -10.5, 4.3), (-0.4, 8.0, 3.6), 42, W, Hh)
    light("SPOT", (-9, -7, 10), (-3, 2.5, 4.5), "#FFD2A0", 3600, size=1.4, spot=40)
    light("AREA", (6, 16, 9), (-2, 4, 4), "#8C96FF", 1500, size=8)
    light("AREA", (0, -13, 4), (0, 4, 3), "#5A5C96", 800, size=10, shadow=False)
    return cam, {"lines": [[("STEAL", EXIT), ("BACK", EXIT)], [("XMAS", CLONE["P1"])]], "x": 0.93, "y": 0.2,
                 "align": "r"}


IMAGES = {   # name: (builder, kind, file stem)
    "icon": (lambda s, W, Hh: icon(s, W, True), "icon", "icon_xmas"),
    "icon_evergreen": (lambda s, W, Hh: icon(s, W, False), "icon", "icon_evergreen"),
    "T1": (t1, "thumb", "T1_8-of-me"),
    "T2": (t2, "thumb", "T2_betrayed"),
    "T3": (t3, "thumb", "T3_wrong-one"),
    "T4": (t4, "thumb", "T4_16-robbers"),
    "T5": (t5, "thumb", "T5_steal-back-xmas"),
}


def render_one(name, scale, samples, truecolor=False):
    build, kind, stem = IMAGES[name]
    W, Hh = (1024, 1024) if kind == "icon" else (1920, 1080)
    W, Hh = int(W * scale), int(Hh * scale)
    s = reset(samples)
    cam, text = build(s, W, Hh)
    notes = project(s, cam)
    if os.environ.get("EH_DRY"):          # framing check: print every figure head's screen position, no render
        for o in bpy.data.objects:
            if o.name.endswith("_neck"):
                v = world_to_camera_view(s, cam, o.matrix_world @ Vector((0, 0, 0.62)))
                print(f"head {o.name[:-5]:>8}: x {v.x:.2f} y {1 - v.y:.2f} d {v.z:.1f}")
        return
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, f".{stem}_raw.png")
    s.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    out = os.path.join(OUT, f"{stem}_concept.png")
    img = finish(tmp, out, notes, text, vignette=0.26 if kind == "icon" else 0.16,
                 tag_alpha=70 if kind == "icon" else 110, truecolor=truecolor)
    os.remove(tmp)
    from PIL import Image
    small = (64, 64) if kind == "icon" else (160, 90)
    sp = os.path.join(OUT, f"{stem}_concept_{'64' if kind == 'icon' else '160x90'}.png")
    img.resize(small, Image.LANCZOS).save(sp, optimize=True)
    print("marketing:", out, sp)


def sheet():
    """review_sheet.png: every preview at real size, 3x nearest, greyscale, and the 320x180 / 1 %-blur test."""
    from PIL import Image, ImageDraw, ImageFilter, ImageOps
    rows = []
    for name, (_b, kind, stem) in IMAGES.items():
        p = os.path.join(OUT, f"{stem}_concept.png")
        if os.path.isfile(p):
            rows.append((stem, kind, Image.open(p).convert("RGB")))
    f, _ = _font(15)
    tiles = []
    for stem, kind, im in rows:
        small = (64, 64) if kind == "icon" else (160, 90)
        mid = (150, 150) if kind == "icon" else (320, 180)
        a = im.resize(small, Image.LANCZOS)
        b = a.resize((small[0] * 3, small[1] * 3), Image.NEAREST)
        c = ImageOps.grayscale(a).convert("RGB").resize((small[0] * 3, small[1] * 3), Image.NEAREST)
        dd = im.resize(mid, Image.LANCZOS).filter(ImageFilter.GaussianBlur(mid[0] * 0.01))
        tiles.append((stem, [a, b, c, dd]))
    W = 1540
    Hrow = 300
    out = Image.new("RGB", (W, 40 + Hrow * len(tiles)), (24, 25, 36))
    d = ImageDraw.Draw(out)
    d.text((10, 10), "Heist Yourself: icon + thumbnail CONCEPTS at real size (1x), 3x nearest, 3x greyscale, "
           "mid size with a 1 % blur (ICON_THUMBNAILS 3.2 / 7)", fill=(230, 232, 245), font=f)
    for r, (stem, ims) in enumerate(tiles):
        y = 40 + r * Hrow
        d.text((10, y + 4), stem, fill=(230, 232, 245), font=f)
        x = 10
        for im in ims:
            out.paste(im, (x, y + 26))
            x += im.size[0] + 20
    p = os.path.join(OUT, "review_sheet.png")
    out.save(p, optimize=True)
    print("marketing:", p)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=list(IMAGES))
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--no-sheet", action="store_true")
    ap.add_argument("--truecolor", action="store_true", help="24-bit PNGs instead of 256 colours + dither")
    a = ap.parse_args(argv)
    if a.only:
        render_one(a.only, a.scale, a.samples, a.truecolor)
        return
    for name in IMAGES:   # one Blender process per image (factory resets + Eevee renders in one process are flaky)
        subprocess.run([sys.executable, os.path.abspath(__file__), "--only", name, "--scale", str(a.scale),
                        "--samples", str(a.samples)] + (["--truecolor"] if a.truecolor else []), check=True)
    if not a.no_sheet:
        sheet()


if __name__ == "__main__":
    main(sys.argv[1:])
