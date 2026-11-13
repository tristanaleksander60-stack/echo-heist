"""Rookie_FPHands: the skinned first-person arms (FP HANDS v2, docs/art/fp_hands_v2, docs/research/fp_hands.md §9).

The owner on v125: "the hands also look like trash" (15+ rigid capsules per hand: seams, gaps, facets, splayed
fingers). These replace them with ONE CONTINUOUS SKINNED GLOVE per hand:

  Rookie_FPH_<Side>_Glove        palm, four fingers, the thumb and a wrist tube as one smooth shell (an SDF of round
                                 cones and a rounded box, smooth-unioned, meshed with Surface Nets, projected onto the
                                 surface, decimated, analytic normals), skinned to 23 bones: Root, Forearm, Hand,
                                 Index/Middle/Ring/Pinky 1-3 + a leaf Tip, Thumb 1-3 + ThumbTip (bone heads = the hinges,
                                 <= 4 weights a vertex, normalised). Greyscale vertex shading (soft occlusion between the
                                 fingers and under the thumb, a darker palm side) multiplies the runtime glove colour.
  Rookie_FPH_<Side>_CuffKnit     the knit glove's ribbed cuff (longitudinal ribs), rigid on the forearm
  Rookie_FPH_<Side>_CuffLeather  the leather gauntlet (a flare, a strap ridge, a stitch line)
  Rookie_FPH_<Side>_Sleeve       the cream sweater sleeve with a ribbed cuff, slim, leaving the bottom of the screen
  Rookie_FPH_<Side>_Stripes      two Breton bands (crew colour)
  Rookie_FPH_<Side>_Block        the colour-block rib cuff (crew colour)
  Rookie_FPH_Left_Watch          the REWIND watch (vertex colours: indigo strap, gold bezel, cream dial, ink hands)

Authored in each hand's GRIP SPACE (Roblox axes, full size: fingers -Z, the back of the hand +Y, the right thumb on
-X, the wrist hinge at z 0.2) and exported at MESH_SCALE (the size the game draws them: a skinned mesh's bones do not
follow MeshPart.Size, measured, so the game never resizes these). Every forearm piece and the glove MeshPart ride the
forearm frame; the Bone transforms bend the wrist and the fingers (Heist/FpRig + Heist/Viewmodel).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.normpath(os.path.join(HERE, "..", "..", "tools", "blender"))
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
import sdf_mesh as S  # noqa: E402

MESH_SCALE = 0.2            # exported size / authored size (RookieData.fpHands.scale)
GRIP_X = 0.9                # Blender x of each grip, authored size (right hand at -X: Roblox +X)
WRIST_Z = 0.2               # the wrist hinge, grip space
STEP = 0.0062               # the SDF grid (authored studs)
GLOVE_TRIS = 2600           # decimation target per glove
TAU = 0.011                 # weight falloff (authored studs): how soft a joint's blend is

# name, MCP hinge (grip space, right hand), segment lengths, base radius, bind fan (deg, + toward the thumb),
# bind pitch per joint (deg, + toward the palm): a relaxed, slightly open bind pose (good for skinning)
FINGERS = [
    ("Index", (-0.150, 0.010, -0.170), (0.126, 0.090, 0.072), 0.0525, 5.0, (2, 5, 5)),
    ("Middle", (-0.050, 0.014, -0.186), (0.138, 0.098, 0.078), 0.0545, 1.5, (2, 5, 5)),
    ("Ring", (0.050, 0.010, -0.178), (0.130, 0.092, 0.074), 0.0515, -2.5, (2, 5, 5)),
    ("Pinky", (0.142, -0.002, -0.156), (0.100, 0.074, 0.064), 0.0465, -7.0, (3, 6, 6)),
]
TAPER = (1.0, 0.94, 0.89, 0.85)       # radius at the MCP, PIP, DIP and the tip, shares of the base
KNUCKLE_SWELL = 1.035                 # a hint of a knuckle at each joint
# the thumb: base (CMC, grip space), then per segment: length, radius base -> end, direction
THUMB_BASE = (-0.128, -0.030, 0.060)
THUMB = [
    ("Thumb1", 0.122, (0.066, 0.061), (-0.55, -0.28, -0.79)),
    ("Thumb2", 0.092, (0.060, 0.056), (-0.34, -0.20, -0.92)),
    ("Thumb3", 0.078, (0.056, 0.050), (-0.24, -0.16, -0.96)),
]
THUMB_UP = (-0.62, 0.78, 0.0)          # the thumbnail side (right hand)
PALM = dict(centre=(0.0, 0.0, -0.006), half=(0.198, 0.074, 0.188), rad=0.062)
WRIST = dict(a=(0.0, -0.004, 0.09), b=(0.0, -0.004, 0.52), ra=0.128, rb=0.13, flat=0.86)
# forearm pieces (grip space z from the hand toward the elbow)
CUFF_KNIT = dict(z0=0.150, z1=0.335, r_in=0.118, r=0.168, flare=0.010, ribs=14, rib=0.0055)
CUFF_LEATHER = dict(z0=0.145, z1=0.360, r_in=0.118, r0=0.166, r1=0.204, strap=(0.262, 0.298), stitch=0.175)
SLEEVE = [(0.300, 0.152), (0.47, 0.158), (0.56, 0.165), (0.9, 0.172), (1.6, 0.188), (2.3, 0.202), (2.9, 0.21)]
SLEEVE_RIB = (0.300, 0.470, 10, 0.0045)   # z0, z1, ribs, depth (the sweater's own rib cuff)
STRIPES = (0.70, 0.92)                    # Breton bands (crew), z centres
STRIPE_W = 0.08
WATCH_Z = 0.60
FLAT = 0.9                                # a forearm is wider than deep (y squash on every forearm piece)

SEG_NAMES = [f"{f[0]}{i}" for f in FINGERS for i in (1, 2, 3)] + ["Thumb1", "Thumb2", "Thumb3"]


# ---------------------------------------------------------------- grip-space geometry (right hand, authored size)

def _rot_dir(fan, pitch):
    a, p = math.radians(fan), math.radians(pitch)
    return np.array([-math.sin(a) * math.cos(p), -math.sin(p), -math.cos(a) * math.cos(p)])


def _up_for(d, up=(0.0, 1.0, 0.0)):
    u = np.array(up, float)
    u = u - (u @ d) * d
    return u / np.linalg.norm(u)


def skeleton():
    """The bones in grip space (right hand): [(name, parent, head, dir, up, length)] in chain order, plus the
    per-segment capsules [(bone, a, b, ra, rb)]."""
    w = np.array((0.0, 0.0, WRIST_Z))
    bones = [("Root", None, w, np.array((0.0, 0.0, 1.0)), np.array((0.0, 1.0, 0.0)), 0.08),
             ("Forearm", "Root", w, np.array((0.0, 0.0, 1.0)), np.array((0.0, 1.0, 0.0)), 0.25),
             ("Hand", "Root", w, np.array((0.0, 0.0, -1.0)), np.array((0.0, 1.0, 0.0)), 0.30)]
    caps = []
    for name, hinge, lens, r, fan, pitch in FINGERS:
        p = np.array(hinge, float)
        parent = "Hand"
        acc = 0.0
        for i, ln in enumerate(lens):
            acc += pitch[i]
            d = _rot_dir(fan, acc)
            joint = f"{name}{i + 1}"
            bones.append((joint, parent, p.copy(), d, _up_for(d), ln))
            ra = r * TAPER[i] * (KNUCKLE_SWELL if i > 0 else 1.0)
            caps.append((joint, p - d * (0.035 if i == 0 else 0.0), p + d * ln, ra, r * TAPER[i + 1]))
            parent, p = joint, p + d * ln
        bones.append((f"{name}Tip", parent, p.copy(), d, _up_for(d), 0.04))
    p = np.array(THUMB_BASE, float)
    parent = "Hand"
    for joint, ln, (r0, r1), dd in THUMB:
        d = np.array(dd, float)
        d /= np.linalg.norm(d)
        bones.append((joint, parent, p.copy(), d, _up_for(d, THUMB_UP), ln))
        caps.append((joint, p, p + d * ln, r0, r1))
        parent, p = joint, p + d * ln
    bones.append(("ThumbTip", parent, p.copy(), d, _up_for(d, THUMB_UP), 0.04))
    return bones, caps


def _palm_warp(Q):
    Q = Q.copy()
    t = np.clip(Q[:, 2] / PALM["half"][2], 0.0, 1.0)
    Q[:, 0] = Q[:, 0] / (1.0 - 0.10 * t)                      # narrower toward the wrist
    back = Q[:, 1] > 0
    dome = 0.014 * (1.0 - np.clip((Q[:, 0] / PALM["half"][0]) ** 2, 0, 1))
    Q[:, 1] = np.where(back, (Q[:, 1] - dome) / 1.12, Q[:, 1] / 0.96)   # a domed back, a flatter palm
    return Q


def _flat(field, k):
    """Squashes a field along y by k (k < 1: flatter)."""
    def f(P):
        Q = P.copy()
        Q[:, 1] /= k
        return field(Q) * k
    return f


def glove_fields():
    """(the whole glove's field, {bone: its own field}) in grip space (right hand)."""
    _bones, caps = skeleton()
    palm = S.rounded_box(PALM["centre"], PALM["half"], PALM["rad"], warp=_palm_warp)
    wrist = _flat(S.round_cone(WRIST["a"], WRIST["b"], WRIST["ra"], WRIST["rb"]), WRIST["flat"])
    knuckles = []
    for name, hinge, _l, r, _f, _p in FINGERS:
        knuckles.append(S.ellipsoid((hinge[0], hinge[1] + 0.034, hinge[2] + 0.012), (r * 0.9, r * 0.62, r * 0.85)))
    seg = {j: S.round_cone(a, b, ra, rb) for j, a, b, ra, rb in caps}
    hand = S.union([(palm, 0)] + [(kn, 0.028) for kn in knuckles])

    def chain(names, k):
        return S.union([(seg[n], k if i else 0) for i, n in enumerate(names)])
    fingers = [chain([f"{f[0]}{i}" for i in (1, 2, 3)], 0.012) for f in FINGERS]
    thumb = chain(["Thumb1", "Thumb2", "Thumb3"], 0.012)
    whole = S.union([(hand, 0), (wrist, 0.075)] + [(fg, 0.022) for fg in fingers] + [(thumb, 0.05)])
    own = {"Forearm": wrist, "Hand": hand}
    own.update(seg)
    return whole, own


def _neighbours():
    bones, _c = skeleton()
    parent = {b[0]: b[1] for b in bones}
    kids = {}
    for b in bones:
        kids.setdefault(b[1], []).append(b[0])
    near = {}
    for name in ["Forearm", "Hand"] + SEG_NAMES:
        n = {name}
        if parent.get(name) in ("Hand", "Forearm") or name in ("Hand", "Forearm"):
            n |= {"Hand"}
        if parent.get(name) and parent[name] not in ("Root",):
            n.add(parent[name])
        n |= {c for c in kids.get(name, []) if not c.endswith("Tip")}
        if name == "Hand":
            n |= {"Forearm"}
        if name == "Forearm":
            n |= {"Hand"}
        near[name] = sorted(n)
    return near


def glove_mesh():
    """The right glove in grip space (authored size): verts, tris, normals, shade, weights {bone: (N,) array}."""
    whole, own = glove_fields()
    lo, hi = (-0.36, -0.20, -0.76), (0.30, 0.18, 0.56)
    V, Q = S.surface_nets(whole, lo, hi, STEP)
    V = S.project(whole, V)
    T = np.concatenate([Q[:, [0, 1, 2]], Q[:, [0, 2, 3]]])
    return whole, own, V, T


def shade_and_weights(whole, own, V):
    N = S.normals(whole, V)
    ao = S.occlusion(whole, V, N, 0.022, samples=5, strength=0.55)
    under = np.clip(-N[:, 1], 0, 1)                    # the palm side reads a step darker
    shade = np.clip(0.30 + 0.70 * ao, 0, 1) * (1.0 - 0.10 * under)
    shade = np.clip(shade, 0.52, 1.0)
    names = ["Forearm", "Hand"] + SEG_NAMES
    D = np.stack([own[n](V) for n in names], axis=1)      # (N, B)
    near = _neighbours()
    owner = np.argmin(D, axis=1)
    W = np.zeros_like(D)
    for i in range(len(V)):
        o = names[owner[i]]
        cand = [names.index(n) for n in near[o]]
        d = D[i, cand]
        w = np.exp(-(d - d.min()) / TAU)
        top = np.argsort(-w)[:4]
        w2 = np.zeros_like(w)
        w2[top] = w[top]
        w2 /= w2.sum()
        W[i, cand] = w2
    W[W < 0.01] = 0.0
    W /= W.sum(1, keepdims=True)
    return N, shade, {n: W[:, j] for j, n in enumerate(names)}


# ---------------------------------------------------------------- Blender plumbing

def to_blender(P, side):
    """Points in a hand's OWN grip space (the left hand's x already mirrored) -> Blender, exported size. The plain
    Roblox -> Blender axes (x -> -x, y -> z, z -> y) about each hand's grip (Blender x -GRIP_X right, +GRIP_X left)."""
    P = np.asarray(P, float)
    gx = -GRIP_X if side < 0 else GRIP_X
    return np.stack([gx - P[..., 0], P[..., 2], P[..., 1]], axis=-1) * MESH_SCALE


def dir_blender(d):
    d = np.asarray(d, float)
    v = np.array([-d[0], d[2], d[1]])
    return v / np.linalg.norm(v)


MIRROR = np.array([-1.0, 1.0, 1.0])


def own(P, side):
    """Right-hand grip-space numbers -> the side's own grip space."""
    return np.asarray(P, float) * (MIRROR if side > 0 else 1.0)


def material(name, rough=0.85):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    return m


def make_object(name, verts, tris, cols, uvs=None, normals=None, origin=(0, 0, 0), mat="EH_FPHands"):
    """A smooth-shaded mesh object from Blender-space verts (N, 3), triangles, per-vertex sRGB colours (N, 3)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v - np.asarray(origin)) for v in verts], [], [tuple(int(i) for i in t) for t in tris])
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ca = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for li, lp in enumerate(me.loops):
        c = cols[lp.vertex_index]
        ca.data[li].color_srgb = (float(c[0]), float(c[1]), float(c[2]), 1.0)
    me.color_attributes.active_color = ca
    uvl = me.uv_layers.new(name="UVMap")
    if uvs is not None:
        for li, lp in enumerate(me.loops):
            uvl.data[li].uv = tuple(float(x) for x in uvs[lp.vertex_index])
    if normals is not None:
        cn = [tuple(float(x) for x in normals[lp.vertex_index]) for lp in me.loops]
        try:
            me.normals_split_custom_set(cn)
        except Exception:
            pass
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector(origin)
    me.materials.append(material(mat))
    return ob


def decimate(ob, target):
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris <= target:
        return
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.ratio = target / tris
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.view_layer.objects:
        o.select_set(o == ob)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def cyl_uv(P, z0, z1):
    """Cylindrical UVs about the grip's z axis (Fabric's knit follows them), inside 0-1."""
    u = (np.arctan2(P[:, 1], P[:, 0]) / (2 * math.pi)) % 1.0
    v = np.clip((P[:, 2] - z0) / (z1 - z0), 0, 1)
    return np.stack([u * 0.999, v * 0.999], axis=1)


# ---------------------------------------------------------------- the skinned glove

def build_glove(k, side, cache):
    s = "Left" if side > 0 else "Right"
    pre = "L_" if side > 0 else "R_"
    if "glove" not in cache:
        cache["glove"] = glove_mesh()
    whole, own_f, V, T = cache["glove"]
    # build, decimate in Blender, then re-project onto the surface and recompute everything on the final verts
    tmp = make_object("tmp_glove", to_blender(V, -1), T, np.ones((len(V), 3)))
    decimate(tmp, GLOVE_TRIS)
    me = tmp.data
    Vb = np.array([tuple(v.co) for v in me.vertices]) + np.array(tuple(tmp.location))
    tris = np.array([tuple(p.vertices) for p in me.polygons])
    bpy.data.objects.remove(tmp, do_unlink=True)
    # back to grip space (right hand): Blender (bx, by, bz) / scale -> (x = -GRIP_X - bx, y = bz, z = by)
    Vg = np.stack([-GRIP_X - Vb[:, 0] / MESH_SCALE, Vb[:, 2] / MESH_SCALE, Vb[:, 1] / MESH_SCALE], axis=1)
    Vg = S.project(whole, Vg, iters=2)
    N, shade, W = shade_and_weights(whole, own_f, Vg)
    if side > 0:          # the left glove: the right one mirrored (winding reversed)
        tris = tris[:, ::-1]
    Pb = to_blender(own(Vg, side), side)
    Nb = np.stack([dir_blender(n) for n in own(N, side)])
    cols = np.repeat(shade[:, None], 3, axis=1)
    uvs = cyl_uv(Vg, -0.75, 0.55)
    wrist = to_blender(np.array([0.0, 0.0, WRIST_Z]), side)
    ob = make_object(f"Rookie_FPH_{s}_Glove", Pb, tris, cols, uvs=uvs, normals=Nb, origin=tuple(wrist))
    # the armature: bone heads at the hinges, tails along each segment, roll toward its up
    bones, _caps = skeleton()
    arm = bpy.data.armatures.new(f"Rookie_FPH_{s}_Rig")
    ao = bpy.data.objects.new(f"Rookie_FPH_{s}_Rig", arm)
    bpy.context.scene.collection.objects.link(ao)
    bpy.context.view_layer.objects.active = ao
    for o in bpy.context.view_layer.objects:
        o.select_set(o == ao)
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, parent, head, d, up, ln in bones:
        eb = arm.edit_bones.new(pre + name)
        h = to_blender(own(head, side), side)
        eb.head = tuple(h)
        eb.tail = tuple(h + dir_blender(own(d, side)) * ln * MESH_SCALE)
        eb.align_roll(Vector(tuple(dir_blender(own(up, side)))))
        if parent:
            eb.parent = made[parent]
        made[name] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    for name, w in W.items():
        g = ob.vertex_groups.new(name=pre + name)
        for i in np.nonzero(w > 0)[0]:
            g.add([int(i)], float(w[i]), "REPLACE")
    ob.parent = ao
    ob.matrix_parent_inverse = ao.matrix_world.inverted()
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = ao
    info = {"bones": [], "scale": MESH_SCALE}
    for name, parent, head, d, up, ln in bones:
        info["bones"].append({"name": name, "bone": pre + name, "parent": parent,
                              "hinge": [round(float(x), 4) + 0.0 for x in own(head, side)],
                              "look": [round(float(x), 4) + 0.0 for x in own(d, side)],
                              "up": [round(float(x), 4) + 0.0 for x in own(up, side)]})
    return ob, ao, info


# ---------------------------------------------------------------- rigid forearm pieces (revolved about the grip z)

def revolve(profile, segs, loop=False, ribs=None, flat=FLAT, axis="z", centre=(0.0, 0.0, 0.0)):
    """Revolves a profile [(h, r, outer)] (h along the axis, r the radius, outer = the outside wall: ribs apply)
    `segs` times. loop=True: a closed cross-section (a ring: watertight with no poles); else r = 0 at both ends make
    single pole vertices (a solid). ribs (h0, h1, n, depth): longitudinal ribbing on the outer wall. axis "z": the
    forearm (y squashed by flat); "y": a watch case. Returns (verts, tris)."""
    verts, rows = [], []
    for h, r, outer in profile:
        if r <= 1e-9:
            rows.append([len(verts)])
            verts.append(_at(axis, centre, h, 0.0, 0.0, flat))
            continue
        row = []
        for i in range(segs):
            t = 2 * math.pi * i / segs
            rr = r
            if ribs and outer and ribs[0] - 1e-6 <= h <= ribs[1] + 1e-6:
                rr = r + ribs[3] * math.cos(ribs[2] * t)
            row.append(len(verts))
            verts.append(_at(axis, centre, h, rr, t, flat))
        rows.append(row)
    tris = []
    pairs = list(zip(rows, rows[1:])) + ([(rows[-1], rows[0])] if loop else [])
    for A, B in pairs:
        if len(A) == 1 and len(B) == 1:
            continue
        if len(A) == 1:
            tris += [(A[0], B[(i + 1) % segs], B[i]) for i in range(segs)]
        elif len(B) == 1:
            tris += [(A[i], A[(i + 1) % segs], B[0]) for i in range(segs)]
        else:
            for i in range(segs):
                j = (i + 1) % segs
                tris += [(A[i], A[j], B[j]), (A[i], B[j], B[i])]
    return np.array(verts), np.array(tris)


def _at(axis, c, h, r, t, flat):
    if axis == "z":
        return (c[0] + r * math.cos(t), c[1] + r * math.sin(t) * flat, c[2] + h)
    return (c[0] + r * math.cos(t), c[1] + h, c[2] + r * math.sin(t))


def ring_section(z0, z1, r_in, r_out, lip, steps, n=2):
    """A closed rounded-rectangle cross-section: the outer wall r_out(z) z0 -> z1, a rounded rim, the inner wall
    r_in(z) back, the other rim. [(z, r, outer)] for revolve(loop=True)."""
    prof = []
    for i in range(steps + 1):
        z = z0 + lip + (z1 - z0 - 2 * lip) * i / steps
        prof.append((z, r_out(z), True))

    def arc(cz, cr, a0, a1):
        return [(cz + lip * math.cos(a0 + (a1 - a0) * (j + 1) / (n + 1)),
                 cr + lip * math.sin(a0 + (a1 - a0) * (j + 1) / (n + 1)), False) for j in range(n)]
    # rim at z1: outer corner, end face, inner corner (angles in the (z, r) plane)
    prof += arc(z1 - lip, r_out(z1) - lip, math.pi / 2, 0.0)
    prof += arc(z1 - lip, r_in(z1) + lip, 0.0, -math.pi / 2)
    for z in (z1 - lip, z0 + lip):          # the inner wall is never seen: two rows
        prof.append((z, r_in(z), False))
    prof += arc(z0 + lip, r_in(z0) + lip, -math.pi / 2, -math.pi)
    prof += arc(z0 + lip, r_out(z0) - lip, math.pi, math.pi / 2)
    return prof


def rigid_object(name, side, V, T, cols, origin_z=WRIST_Z, z0=0.0, z1=3.0, mat="EH_FPHands"):
    """A forearm piece from right-hand grip-space geometry (mirrored for the left), pivot at the wrist hinge."""
    tris = T[:, ::-1] if side > 0 else T
    origin = to_blender(np.array([0.0, 0.0, origin_z]), side)
    return make_object(name, to_blender(own(V, side), side), tris, cols, uvs=cyl_uv(V, z0, z1), origin=tuple(origin),
                       mat=mat)


def grey(v, n):
    return np.repeat(np.full((n, 1), float(v)), 3, axis=1)


def sleeve_r(z):
    if z <= SLEEVE[0][0]:
        return SLEEVE[0][1]
    for (z0, r0), (z1, r1) in zip(SLEEVE, SLEEVE[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return SLEEVE[-1][1]


def _radial(V):
    return np.hypot(V[:, 0], V[:, 1] / FLAT), np.arctan2(V[:, 1] / FLAT, V[:, 0])


def cuff_knit():
    c = CUFF_KNIT
    prof = ring_section(c["z0"], c["z1"], lambda z: c["r_in"],
                        lambda z: c["r"] + c["flare"] * (z - c["z0"]) / (c["z1"] - c["z0"]), 0.016, 3)
    V, T = revolve(prof, 28, loop=True, ribs=(c["z0"] + 0.012, c["z1"] - 0.012, c["ribs"], c["rib"]))
    r, t = _radial(V)
    rib = 0.5 + 0.5 * np.cos(c["ribs"] * t)
    shade = np.where(r < c["r_in"] + 0.004, 0.45, 0.78 + 0.22 * rib)       # rib valleys a step darker
    return V, T, np.repeat(shade[:, None], 3, axis=1)


def cuff_leather():
    c = CUFF_LEATHER

    def rf(z):
        t = (z - c["z0"]) / (c["z1"] - c["z0"])
        r = c["r0"] + (c["r1"] - c["r0"]) * max(t, 0.0) ** 1.4
        if c["strap"][0] <= z <= c["strap"][1]:
            r += 0.007
        return r
    prof = ring_section(c["z0"], c["z1"], lambda z: c["r_in"], rf, 0.014, 6)
    V, T = revolve(prof, 24, loop=True)
    r, _t = _radial(V)
    z = V[:, 2]
    shade = np.full(len(V), 0.95)
    shade = np.where((z >= c["strap"][0]) & (z <= c["strap"][1]), 0.80, shade)        # the strap
    shade = np.where(np.abs(z - c["stitch"]) < 0.012, 0.66, shade)                    # the stitch line
    shade = np.where(r < c["r_in"] + 0.004, 0.45, shade)
    return V, T, np.repeat(shade[:, None], 3, axis=1)


def sleeve():
    z0, z1, n, dep = SLEEVE_RIB
    zs = [SLEEVE[0][0], 2.9]
    prof = ring_section(zs[0], zs[1], lambda z: sleeve_r(z) - 0.022, sleeve_r, 0.014, 1)
    # outer wall rows: dense over the rib, sparse up the arm
    outer = [(float(z), sleeve_r(z), True) for z in list(np.linspace(z0 + 0.014, z1, 4)) +
             [0.56, 0.7, 0.9, 1.3, 1.8, 2.4, 2.886]]
    prof = outer + [p for p in prof if not p[2]]
    V, T = revolve(prof, 20, loop=True, ribs=(z0, z1, n, dep))
    r, t = _radial(V)
    z = V[:, 2]
    rib = 0.5 + 0.5 * np.cos(n * t)
    in_rib = (z >= z0) & (z <= z1) & (r > sleeve_r(0.4) - 0.01)
    shade = np.where(in_rib, 0.80 + 0.14 * rib, 0.96)
    shade = np.where(r < sleeve_r(0.4) - 0.015, 0.55, shade)
    return V, T, np.repeat(shade[:, None], 3, axis=1)


def band(z_a, z_b, lift=0.004, depth=0.008, ribs=None, segs=20, steps=1):
    prof = ring_section(z_a, z_b, lambda z: sleeve_r(z) - depth, lambda z: sleeve_r(z) + lift, 0.003, steps, n=1)
    return revolve(prof, segs, loop=True, ribs=ribs)


def stripes():
    Vs, Ts = [], []
    for zc in STRIPES:
        V, T = band(zc - STRIPE_W / 2, zc + STRIPE_W / 2)
        Ts.append(T + sum(len(v) for v in Vs))
        Vs.append(V)
    V = np.concatenate(Vs)
    return V, np.concatenate(Ts), grey(1.0, len(V))


def block():
    z0, z1, n, dep = SLEEVE_RIB
    V, T = band(z0 + 0.006, z1 + 0.012, lift=0.003, ribs=(z0, z1 + 0.02, n, dep), segs=20, steps=2)
    r, t = _radial(V)
    shade = 0.84 + 0.16 * (0.5 + 0.5 * np.cos(n * t))
    return V, T, np.repeat(shade[:, None], 3, axis=1)


def watch():
    """The REWIND watch on the left wrist (right-hand numbers, mirrored with the left forearm): a strap ring round
    the sleeve, a case with a gold bezel and a cream dial, two ink hands. Vertex colours (Color white)."""
    INK, GOLD, DIAL, STRAP = (0.11, 0.12, 0.23), (1.0, 0.82, 0.35), (0.93, 0.89, 0.80), (0.17, 0.18, 0.32)
    Vs, Ts, Cs = [], [], []

    def add(V, T, C):
        Ts.append(np.asarray(T) + sum(len(v) for v in Vs))
        Vs.append(np.asarray(V, float))
        Cs.append(np.tile(np.array(C), (len(V), 1)) if len(np.shape(C)) == 1 else np.asarray(C))
    V, T = band(WATCH_Z - 0.032, WATCH_Z + 0.032, lift=0.009, depth=0.006, segs=24)
    add(V, T, STRAP)
    top = sleeve_r(WATCH_Z) * FLAT + 0.004
    case = [(0.0, 0.0, False), (0.0, 0.062, False), (0.010, 0.070, False), (0.024, 0.071, False),
            (0.032, 0.064, False), (0.034, 0.056, False), (0.034, 0.0, False)]
    V, T = revolve(case, 24, axis="y", centre=(0.0, top, WATCH_Z))
    dial = (V[:, 1] - top > 0.033) & (np.hypot(V[:, 0], V[:, 2] - WATCH_Z) < 0.06)
    add(V, T, np.where(dial[:, None], np.array(DIAL), np.array(GOLD)))
    for (x0, x1, z0, z1) in ((-0.005, 0.005, -0.044, 0.004), (-0.004, 0.030, -0.004, 0.004)):
        y0, y1 = top + 0.0335, top + 0.040
        bx = [(x, y, WATCH_Z + zz) for x in (x0, x1) for y in (y0, y1) for zz in (z0, z1)]
        bt = [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6), (0, 2, 6),
              (0, 6, 4), (1, 5, 7), (1, 7, 3)]
        add(bx, bt, INK)
    return np.concatenate(Vs), np.concatenate(Ts), np.concatenate(Cs)


# ---------------------------------------------------------------- the asset

def build(k):
    k.reset_scene()
    objs = []
    cache = {}
    glove_tint = "glove colour (Config.Rookie.GLOVES / the knit tone), lifted for first person"
    crew = "crew colour (Palette seat hue)"
    for side in (-1, 1):
        s = "Left" if side > 0 else "Right"
        ob, rig, info = build_glove(k, side, cache)
        hinge = [0.0, 0.0, WRIST_Z]

        def fp(joint, **kw):
            d = {"side": s, "joint": joint, "frame": "arm", "hinge": hinge, "centre": None, "v2": True}
            d.update(kw)
            return d
        g = fp("Glove", skinned=True, bones=info["bones"], scale=MESH_SCALE)
        objs.append(k.Obj(ob, "medium", role="char", pivot="point", collision="Box", can_collide=False,
                          cast_shadow=False, atlas=False, tint=glove_tint, tags=["EH_Rookie", "EH_FPArm"],
                          extra={"fp2": g}, notes=f"skinned first-person {s.lower()} glove (one shell, 23 bones)"))
        pieces = [("CuffKnit", cuff_knit(), {"slot": "gloves", "variant": "Knit"}, glove_tint, False),
                  ("CuffLeather", cuff_leather(), {"slot": "gloves", "variant": "Leather"}, glove_tint, False),
                  ("Sleeve", sleeve(), {}, None, False),
                  ("Stripes", stripes(), {"slot": "sweater", "variant": "Stripes"}, crew, True),
                  ("Block", block(), {"slot": "sweater", "variant": "Block"}, crew, False)]
        if side > 0:
            pieces.append(("Watch", watch(), {}, None, False))
        for joint, (V, T, C), kw, tint, free in pieces:
            o = rigid_object(f"Rookie_FPH_{s}_{joint}", side, V, T, C)
            objs.append(k.Obj(o, "small", role="char", pivot="point", collision="Box", can_collide=False,
                              cast_shadow=False, atlas=False, tint=tint, free_shells=free,
                              tags=["EH_Rookie", "EH_FPArm"], extra={"fp2": fp(joint, **kw)},
                              notes=f"first-person {s.lower()} forearm: {joint}"))
    # the centres (MeshPart CFrame = the bbox centre) from the wrist hinge (every piece's pivot), authored size
    bpy.context.view_layer.update()
    for o in objs:
        f = o.extra["fp2"]
        side = 1 if f["side"] == "Left" else -1
        pts = [o.ob.matrix_world @ Vector(c) for c in o.ob.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        c = (lo + hi) / 2
        gx = -GRIP_X if side < 0 else GRIP_X
        f["centre"] = [round(gx - c.x / MESH_SCALE, 4) + 0.0, round(c.z / MESH_SCALE, 4) + 0.0,
                       round(c.y / MESH_SCALE - WRIST_Z, 4) + 0.0]
    # One FBX per skinned glove: with several meshes in a file the Roblox importer moves every Bone under a generated
    # RootPart and welds the meshes to it (measured), so a cloned glove would lose its Bones; a single skinned mesh
    # keeps them under its MeshPart (measured).
    gloves = [o for o in objs if o.extra["fp2"].get("skinned")]
    rigid = [o for o in objs if not o.extra["fp2"].get("skinned")]
    out = [k.Asset("Rookie_FPHands", rigid, budget_cls="hero",
                   notes="FP HANDS v2 forearm pieces: knit / leather cuffs, a ribbed cream sleeve, crew stripes or block, "
                         f"the REWIND watch (vertex-shaded). Grip space, exported at {MESH_SCALE} (the in-game size).")]
    for o in gloves:
        side = "R" if "_Right_" in o.ob.name else "L"
        out.append(k.Asset(f"Rookie_FPHands_{side}", [o], budget_cls="medium",
                           notes="FP HANDS v2: one continuous skinned glove (23 bones, smooth, vertex-shaded), "
                                 f"exported at {MESH_SCALE} (the in-game size)."))
    return out
