"""The Rookie (PLAN_FIRST_PERSON "CH", MASTERPLAN 2.2): the player character. An original, chunky robber with a flat
cap, a long scarf and a smug side-eye. Every player is a Rookie in their crew colour with outfit slots; clones are
copies of your Rookie.

Build: python3 tools/blender/build_asset.py assets/blender/rookie.py
Read at 48 px (STYLE_BIBLE 12, Gus is the quality reference): a big round head with a cap on top, a cream Breton
sweater with crew-colour stripes, a crew-colour scarf whose long tail flies behind, dark trousers, chunky boots and
chunky gloves. Gus is the grown-up (6.5 studs, light blue shirt, peaked cap); the Rookie is a kid-sized 4.9 studs.

R15-compatible: the 15 body parts carry the R15 names after a "Rookie_" prefix (the server strips it: Head,
UpperTorso, LowerTorso, LeftUpperArm ... RightFoot) and every part's ORIGIN IS ITS R15 JOINT with its parent
(manifest `joint` = {name, parent}), so Heist/Rookie builds the Motor6Ds and the R15 rig attachments from the pivots.
The default Animate clips, the uploaded CloneClips and Roblox emotes key these joints. The HumanoidRootPart is made in
code: 2 x 2 x 1, its centre 3 studs above the floor (Config.Rookie.HIP_HEIGHT 2, the sim's root height), joined to
the hip centre (Root, 1.62) below it.

Four groups (FBX files):
  Rookie            the body (15 parts) + Rookie_Face_Idle (the default face, welded to the head)
  Rookie_Faces      Smug, Shocked, Busted: swapped with Idle by state (only one face shows)
  Rookie_Outfits    the outfit slots: cap x4, scarf x4, sweater x2 (overlays), gloves x2 (cuffs), mask x1 (+ none)
  Rookie_Viewmodel  the first-person forearms + gloved hands (LeftArm, RightArm; grips GripL / GripR)
Outfit pieces and faces are authored on the body and seat-checked against it (A16 below), then moved apart for the
turntable; their pivot is their attach point (manifest `attach`: body part + offset from that part's pivot, Roblox
axes), so the game welds them by pivot, never by scene position.

Colours: the body is atlas (char cells + ink, steel, marble; rule P3: no location cells). Parts marked `tint` use the
Tint White cell with no atlas and take MeshPart.Color at runtime: the scarf and the sweater stripes in the crew
colour (Palette seat hue), the gloves and glove cuffs in the glove colour (Config.Rookie.GLOVE_COLOURS).
Coordinates: front -Y, Z up, origin = between the feet on the floor. The Rookie's RIGHT is Blender -X (Roblox +X).
"""
import math
import _kitlib as L
from mathutils import Matrix, Vector

# Joints (Blender coordinates). Right side = -X.
J = {
    "Root": (0.0, 0.0, 1.62), "Waist": (0.0, 0.0, 1.95), "Neck": (0.0, 0.0, 3.0),
    "RightShoulder": (-1.0, 0.0, 2.76), "RightElbow": (-1.1, 0.0, 2.16), "RightWrist": (-1.18, 0.0, 1.6),
    "LeftShoulder": (1.0, 0.0, 2.76), "LeftElbow": (1.1, 0.0, 2.16), "LeftWrist": (1.18, 0.0, 1.6),
    "RightHip": (-0.4, 0.0, 1.48), "RightKnee": (-0.42, 0.0, 0.98), "RightAnkle": (-0.44, 0.0, 0.5),
    "LeftHip": (0.4, 0.0, 1.48), "LeftKnee": (0.42, 0.0, 0.98), "LeftAnkle": (0.44, 0.0, 0.5),
    "HatAttach": (0.0, 0.0, 4.2), "FaceFront": (0.0, -0.84, 3.72),
}
HIP_HEIGHT = 2.0       # Humanoid.HipHeight (code): root part centre at 3.0, the sim's rootHeight
HEAD_SQ = 0.86         # head depth squash
EYE_Z = 3.8
TORSO_SQ = 0.76

HEAD_PROF = [(0, 2.96), (0.4, 2.98), (0.78, 3.18), (0.94, 3.5), (0.97, 3.8), (0.92, 4.1), (0.76, 4.36), (0.46, 4.52),
             (0, 4.56)]
TORSO_PROF = [(0, 1.78), (0.8, 1.78), (0.86, 1.86), (0.88, 2.05), (0.96, 2.4), (1.0, 2.62), (0.94, 2.84), (0.7, 2.98),
              (0.34, 3.04), (0, 3.05)]


def prof_r(prof, z):
    """Radius of a lathe profile at height z (linear between the profile points)."""
    for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
        if z0 <= z <= z1 and z1 > z0:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return 0.0


def head_front_y(x, z):
    r = prof_r(HEAD_PROF, z)
    return -math.sqrt(max(0.0, r * r - x * x)) * HEAD_SQ


def squash(vs, sy, y0=0.0):
    for v in vs:
        if v.is_valid:
            v.co.y = y0 + (v.co.y - y0) * sy
    return vs


def ellipsoid(mb, c, r, sx, sy, sz, col, segs=8, rings=5, part=None, rot=None):
    """A sphere scaled about its centre (eye whites, mitts, bobbles)."""
    vs = mb.sphere((0, 0, 0), r, segs, rings, col, part=part)
    m = Matrix.Diagonal((sx, sy, sz, 1.0))
    if rot:
        m = rot @ m
    mb.xform(vs, Matrix.Translation(Vector(c)) @ m)
    return vs


def ring(mb, c, r_in, r_out, z0, z1, col, sy=1.0, segs=16, part=None, axis=(0, 0, 1)):
    """A closed band (a lathe of a rectangle): sweater stripes, cuffs, scarf loops. sy squashes it like the torso."""
    vs = mb.lathe([(r_in, z0), (r_out, z0), (r_out, z1), (r_in, z1)], segs, col, c, axis, closed=True, part=part)
    if sy != 1.0:
        squash(vs, sy, c[1])
    return vs


def strip(mb, path, w, t, col, normal=(1, 0, 0), part=None, taper=None):
    """A flat ribbon of width w (along `normal` x tangent) and thickness t along a 3D polyline: scarf tails.
    Closed, end caps included. taper: per-point width factors."""
    pts = [Vector(p) for p in path]
    n = Vector(normal).normalized()
    rings_ = []
    for i, p in enumerate(pts):
        if i == 0:
            tg = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            tg = (pts[-1] - pts[-2]).normalized()
        else:
            tg = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
        thick = (n - tg * n.dot(tg)).normalized()          # thickness direction: the normal, made perpendicular
        wide = tg.cross(thick).normalized()
        ww = w * (taper[i] if taper else 1.0) / 2
        rings_.append([mb.v(p + wide * ww + thick * t / 2), mb.v(p - wide * ww + thick * t / 2),
                       mb.v(p - wide * ww - thick * t / 2), mb.v(p + wide * ww - thick * t / 2)])
    for i in range(len(rings_) - 1):
        a, b = rings_[i], rings_[i + 1]
        for j in range(4):
            k = (j + 1) % 4
            mb.f([a[j], a[k], b[k], b[j]], col)
    mb.f(list(reversed(rings_[0])), col)
    mb.f(rings_[-1], col)
    vs = [v for R in rings_ for v in R]
    mb._part(part, vs)
    return vs


def limb(mb, a, b, r0, r1, col, segs=10, part="Limb"):
    """A tapered limb from joint a to joint b with chamfered ends (a capsule-ish block), as Gus's."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    n = d.normalized()
    L_ = d.length
    prof = [(0, -0.08), (r0 * 0.75, -0.08), (r0, 0.06), (r1, L_ - 0.06), (r1 * 0.75, L_ + 0.06), (0, L_ + 0.06)]
    return mb.lathe(prof, segs, col if isinstance(col, list) else [col] * 5, tuple(a), tuple(n), part=part)


def along(a, b, t):
    a, b = Vector(a), Vector(b)
    return a + (b - a) * t


# ---------------------------------------------------------------- body

def head(k):
    mb = k.MB("Rookie_Head")
    # hair first (the clips cut every face in the builder): a shell over the top and the back, cut along the
    # hairline (front) and above the ears (sides, a plane tilted down to the nape)
    hair = mb.lathe([(0, 3.4), (0.86, 3.4), (1.0, 3.6), (1.02, 3.85), (0.97, 4.12), (0.81, 4.4), (0.5, 4.58), (0, 4.62)],
                    16, "hair", (0, 0, 0), part="Hair")
    squash(hair, HEAD_SQ + 0.04)
    mb.clip((0, -0.32, 0), (0, 1, 0), "hair")
    mb.clip((0, 0, 3.98), (0, 0.55, 1), "hair")
    skull = mb.lathe(HEAD_PROF, 16, ["skin_lo", "skin_lo", "skin", "skin", "skin", "skin", "skin", "skin"], (0, 0, 0),
                     part="Skull")
    squash(skull, HEAD_SQ)
    mb.sphere((0, -0.82, 3.6), 0.16, 8, 5, "skin", part="Nose")                     # button nose
    for sx in (-1, 1):
        ear = ellipsoid(mb, (sx * 0.94, -0.04, 3.68), 0.19, 0.6, 1.0, 1.0, "skin_lo", part="Ear")
        mb.box((sx * 0.9 - 0.09, -0.22, 3.72), (sx * 0.9 + 0.09, 0.05, 4.08), "hair", chamfer=0.04,
               cham_col="hair", part="Sideburn")
    return k.finalize(mb, pivot=J["Neck"])


def face(k, name, mood):
    """Eyes, brows and mouth on the head's front (one face shows at a time; Heist/Rookie swaps them by state).
    Readable at 48 px: two light eye shapes and one dark brow line each, as Gus's beady eyes."""
    mb = k.MB(name)
    ez = EYE_Z
    for sx in (-1, 1):
        ex = sx * 0.31
        yf = head_front_y(ex, ez)
        if mood == "busted":
            # squeezed shut: a chevron per eye (> <), Ink on the skin
            for s in (1, -1):
                bar = mb.box((-0.15, -0.035, -0.035), (0.15, 0.035, 0.035), "ink", part="Squint")
                mb.xform(bar, Matrix.Translation(Vector((ex, yf - 0.01, ez + s * 0.06))) @
                         Matrix.Rotation(math.radians(s * sx * 24), 4, "Y"))
            continue
        big = mood == "shocked"
        rw, rh = (0.2, 0.26) if big else (0.18, 0.22)
        ellipsoid(mb, (ex, yf + 0.04, ez), 1.0, rw, 0.11, rh, "marble_hi", part="EyeWhite")
        if mood == "shocked":
            px, pz, pr = ex, ez, 0.07                           # pinprick pupils, centred
        elif mood == "smug":
            px, pz, pr = ex + 0.09, ez - 0.05, 0.095            # hard side-eye, low under the lid
        else:
            px, pz, pr = ex + 0.06, ez - 0.01, 0.1              # idle: the relaxed side-eye
        ellipsoid(mb, (px, yf - 0.06, pz), 1.0, pr, 0.05, pr * 1.1, "ink", part="Pupil")
        if mood == "smug":                                       # half-lidded: a skin lid over the top half
            ellipsoid(mb, (ex, yf + 0.04, ez + 0.08), 1.0, rw + 0.03, 0.15, rh * 0.62, "skin_lo", part="Lid")
        # brows: idle level and cocky, smug one raised, shocked both high
        if mood == "shocked":
            bz, tilt = ez + 0.36, -10 * sx
        elif mood == "smug":
            bz, tilt = (ez + 0.3, -14) if sx > 0 else (ez + 0.2, 10)
        else:
            bz, tilt = ez + 0.27, 8 * sx
        byf = head_front_y(ex, bz)
        brow = mb.box((-0.2, -0.06, -0.055), (0.2, 0.06, 0.055), "hair", chamfer=0.03, cham_col="hair", part="Brow")
        mb.xform(brow, Matrix.Translation(Vector((ex, byf - 0.01, bz))) @ Matrix.Rotation(math.radians(tilt), 4, "Y"))
    # mouth
    mz = 3.4
    myf = head_front_y(0.0, mz)
    if mood == "shocked":
        ellipsoid(mb, (0.0, myf + 0.02, mz - 0.02), 1.0, 0.11, 0.07, 0.14, "ink_hi", part="Mouth")
    elif mood == "busted":
        for i, x in enumerate((-0.2, -0.07, 0.07, 0.2)):         # a wobbly grimace: four tilted dashes
            dash = mb.box((-0.075, -0.03, -0.03), (0.075, 0.03, 0.03), "ink_hi", part=f"Grimace{i}")
            mb.xform(dash, Matrix.Translation(Vector((x, head_front_y(x, mz) - 0.015, mz + (0.03 if i % 2 else -0.03)))) @
                     Matrix.Rotation(math.radians(30 if i % 2 else -30), 4, "Y"))
    else:
        # the smirk: a short bar, one corner pulled up (the Rookie's right side for idle, deeper for smug)
        up = 22 if mood == "smug" else 12
        bar = mb.box((-0.2, -0.04, -0.045), (0.16, 0.04, 0.045), "ink_hi", part="Mouth")
        mb.xform(bar, Matrix.Translation(Vector((0.02, myf - 0.01, mz))) @ Matrix.Rotation(math.radians(-up), 4, "Y"))
        dimple = mb.box((-0.035, -0.035, -0.06), (0.035, 0.035, 0.06), "ink_hi", part="Corner")
        mb.xform(dimple, Matrix.Translation(Vector((-0.15, head_front_y(-0.15, mz + 0.06) - 0.01, mz + 0.07))) @
                 Matrix.Rotation(math.radians(20), 4, "Y"))
    return k.finalize(mb, pivot=J["FaceFront"])


def upper_torso(k):
    mb = k.MB("Rookie_UpperTorso")
    body = mb.lathe(TORSO_PROF, 16, ["marble_lo", "marble_lo", "marble", "marble", "marble", "marble", "marble",
                                     "marble_hi", "marble_hi"], (0, 0, 0), part="Sweater")
    squash(body, TORSO_SQ)
    # ribbed hem: three shallow ribs read as knit at 64 px (the bands in the crew colour are the overlay)
    for z in (1.84, 1.92):
        ring(mb, (0, 0, 0), prof_r(TORSO_PROF, z + 0.03) - 0.03, prof_r(TORSO_PROF, z + 0.03) + 0.025, z, z + 0.05,
             "marble_lo", sy=TORSO_SQ, part="Rib")
    # the swag-bag strap: a dark leather band across the chest from the left shoulder to the right hip
    for sgn in (-1, 1):
        path = []
        for i in range(6):
            t = i / 5
            x, z = 0.62 + (-0.66 - 0.62) * t, 2.86 + (2.0 - 2.86) * t
            r = prof_r(TORSO_PROF, z)
            path.append((x, sgn * (math.sqrt(max(0.0, r * r - x * x)) * TORSO_SQ + 0.01), z))
        strip(mb, path, 0.2, 0.08, "hair", normal=(0, sgn, 0), part="Strap" if sgn < 0 else "StrapBack")
    bz = 2.43
    bx = 0.62 + (-0.66 - 0.62) * (2.86 - bz) / 0.86
    by = -math.sqrt(prof_r(TORSO_PROF, bz) ** 2 - bx * bx) * TORSO_SQ
    mb.box((bx - 0.09, by - 0.1, bz - 0.08), (bx + 0.09, by + 0.02, bz + 0.08), "steel_hi", chamfer=0.03,
           cham_col="steel_hi", part="Buckle")
    return k.finalize(mb, pivot=J["Waist"])


def lower_torso(k):
    mb = k.MB("Rookie_LowerTorso")
    hips = mb.lathe([(0, 1.3), (0.66, 1.3), (0.8, 1.42), (0.84, 1.66), (0.82, 1.98), (0, 1.98)], 16,
                    ["steel_lo", "steel_lo", "steel_lo", "steel_lo", "steel_lo"], (0, 0, 0), part="Hips")
    squash(hips, 0.74)
    # the lockpick roll on the right hip (storytelling): a leather pouch with a steel snap
    mb.box((-0.98, -0.28, 1.36), (-0.74, 0.22, 1.74), "hair", chamfer=0.06, cham_col="hair", part="Pouch")
    mb.box((-1.0, -0.12, 1.6), (-0.95, 0.06, 1.7), "steel_hi", part="Snap")
    return k.finalize(mb, pivot=J["Root"])


def arm_parts(k, side):
    s = "Right" if side < 0 else "Left"
    sh, el, wr = J[f"{s}Shoulder"], J[f"{s}Elbow"], J[f"{s}Wrist"]
    mu = k.MB(f"Rookie_{s}UpperArm")
    mu.sphere(sh, 0.34, 10, 6, "marble", part="Shoulder")
    limb(mu, sh, el, 0.3, 0.27, ["marble", "marble", "marble", "marble_lo", "marble_lo"], part="Upper")
    ua = k.finalize(mu, pivot=sh)
    ml = k.MB(f"Rookie_{s}LowerArm")
    limb(ml, el, wr, 0.27, 0.25, ["marble", "marble", "marble", "marble", "marble"], part="Fore")
    d = (Vector(wr) - Vector(el)).normalized()
    ml.cylinder(tuple(Vector(wr) - d * 0.12), tuple(d), 0.28, -0.07, 0.07, 10, "marble_lo", part="Cuff")
    la = k.finalize(ml, pivot=el)
    hd, hc = glove(k, f"Rookie_{s}Hand", side, wr, "white")
    return ua, la, hd, hc


def glove(k, name, side, wr, col):
    """A chunky mitt: a fat palm, three finger bumps folded forward and a thumb (the hands read at 48 px)."""
    mh = k.MB(name)
    hc = Vector(wr) + Vector((side * 0.03, -0.04, -0.27))
    ellipsoid(mh, tuple(hc), 1.0, 0.27, 0.3, 0.32, col, segs=10, rings=6, part="Palm")
    for i, dx in enumerate((-0.12, 0.0, 0.12)):
        ellipsoid(mh, (hc.x + dx, hc.y - 0.17, hc.z - 0.2), 1.0, 0.085, 0.11, 0.1, col, segs=6, rings=4,
                  part=f"Finger{i}")
    ellipsoid(mh, (hc.x - side * 0.25, hc.y - 0.12, hc.z + 0.06), 1.0, 0.1, 0.11, 0.14, col, segs=6, rings=4,
              part="Thumb")
    return k.finalize(mh, pivot=wr), tuple(hc)


def leg_parts(k, side):
    s = "Right" if side < 0 else "Left"
    hp, kn, an = J[f"{s}Hip"], J[f"{s}Knee"], J[f"{s}Ankle"]
    mu = k.MB(f"Rookie_{s}UpperLeg")
    limb(mu, hp, kn, 0.37, 0.33, "steel_lo", part="Thigh")
    ul = k.finalize(mu, pivot=hp)
    ml = k.MB(f"Rookie_{s}LowerLeg")
    limb(ml, kn, an, 0.33, 0.31, "steel_lo", part="Shin")
    ml.cylinder((an[0], an[1], an[2] + 0.14), (0, 0, 1), 0.35, 0.0, 0.14, 10, "steel", part="Turnup")  # rolled cuff
    ll = k.finalize(ml, pivot=kn)
    mf = k.MB(f"Rookie_{s}Foot")
    x = an[0]
    # chunky boot: a round-toed block, a thick sole, a shaft up the ankle, two laces
    mf.box((x - 0.36, -0.86, 0.1), (x + 0.36, 0.36, 0.5), "hair", chamfer=0.16, cham_col="hair", part="Boot")
    mf.box((x - 0.38, -0.9, 0.0), (x + 0.38, 0.4, 0.13), "ink_hi", chamfer=0.04, cham_col="ink_hi", part="Sole")
    mf.cylinder((x, 0.0, 0.36), (0, 0, 1), 0.3, 0.0, 0.3, 10, "hair", part="Shaft")
    for i, y in enumerate((-0.42, -0.6)):
        mf.box((x - 0.17, y - 0.04, 0.47), (x + 0.17, y + 0.04, 0.55), "marble_lo", part=f"Lace{i}")
    ft = k.finalize(mf, pivot=an)
    return ul, ll, ft


# ---------------------------------------------------------------- outfits (pivot = the attach point)

def cap_flat(k):
    """The signature flat cap (MASTERPLAN 2.2): a low tweed crown pulled forward over a short brim, a button on top."""
    mb = k.MB("Rookie_Cap_Flat")
    crown = mb.lathe([(0, 4.12), (0.99, 4.12), (1.06, 4.26), (1.03, 4.48), (0.82, 4.64), (0, 4.7)], 16,
                     ["hair", "hair", "hair", "hair", "hair"], (0, 0, 0), part="Crown")
    for v in crown:
        v.co.y *= 0.95
        if v.co.y < 0:                       # the crown is pulled forward and down over the peak
            f = -v.co.y / 1.0
            v.co.y -= 0.22 * f
            v.co.z -= 0.2 * f * max(0.0, (v.co.z - 4.12) / 0.58)
    ring(mb, (0, 0, 0), 0.94, 1.02, 4.1, 4.2, "ink_hi", sy=0.95, part="Band")
    # the peak: a stiff half-moon sticking out past the crown, tipped down over the eyes' line
    brim = [(0.84, -0.5)] + [(0.88 * math.cos(math.radians(a)), -0.5 - 0.86 * math.sin(math.radians(a)))
                             for a in range(15, 166, 25)] + [(-0.84, -0.5)]
    vb = mb.prism(brim, "Z", 4.06, 4.14, "ink_hi", "ink_hi", part="Brim")
    mb.rotate(vb, -14, "X", (0, -0.5, 4.1))
    mb.sphere((0, -0.1, 4.66), 0.08, 8, 4, "ink_hi", part="Button")
    return k.finalize(mb, pivot=J["HatAttach"])


def cap_beanie(k):
    mb = k.MB("Rookie_Cap_Beanie")
    mb.lathe([(0, 4.0), (1.0, 4.0), (1.02, 4.3), (0.94, 4.6), (0.66, 4.86), (0.3, 4.96), (0, 4.98)], 16,
             ["steel", "steel", "steel", "steel", "steel", "steel"], (0, 0, 0), part="Dome")
    ring(mb, (0, 0, 0), 0.98, 1.08, 3.96, 4.24, "steel_hi", part="Fold")
    for a in range(0, 360, 45):                     # knit ribs on the fold
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        mb.box((c * 1.06 - 0.03, s_ * 1.06 - 0.03, 3.98), (c * 1.06 + 0.03, s_ * 1.06 + 0.03, 4.22), "steel",
               part=f"Rib{a}")
    return k.finalize(mb, pivot=J["HatAttach"])


def cap_bobble(k):
    mb = k.MB("Rookie_Cap_Bobble")
    mb.lathe([(0, 4.0), (1.0, 4.0), (1.0, 4.34), (0.88, 4.72), (0.52, 5.0), (0, 5.06)], 16,
             ["shirt_lo", "shirt_lo", "shirt_lo", "shirt_lo", "shirt_lo"], (0, 0, 0), part="Dome")
    ring(mb, (0, 0, 0), 0.98, 1.07, 3.96, 4.22, "marble", part="Fold")
    ring(mb, (0, 0, 0), 0.9, 0.99, 4.5, 4.62, "marble", part="Band")
    mb.sphere((0, 0, 5.18), 0.26, 10, 6, "marble_hi", part="Bobble")
    return k.finalize(mb, pivot=J["HatAttach"])


def cap_trapper(k):
    mb = k.MB("Rookie_Cap_Trapper")
    mb.lathe([(0, 4.02), (1.0, 4.02), (1.04, 4.32), (0.92, 4.68), (0.5, 4.86), (0, 4.9)], 16,
             ["hair", "hair", "hair", "hair", "hair"], (0, 0, 0), part="Dome")
    mb.box((-0.78, -1.06, 4.1), (0.78, -0.7, 4.46), "marble_hi", chamfer=0.1, cham_col="marble_hi", part="FurFront")
    for sx in (-1, 1):                              # ear flaps over the ears, fur lined
        mb.box((sx * 0.98 - 0.12, -0.36, 3.42), (sx * 0.98 + 0.12, 0.3, 4.12), "hair", chamfer=0.08, cham_col="hair",
               part="Flap")
        mb.box((sx * 1.08 - 0.05, -0.3, 3.46), (sx * 1.08 + 0.05, 0.24, 3.66), "marble_hi", part="FlapFur")
    return k.finalize(mb, pivot=J["HatAttach"])


SCARF_Z0, SCARF_Z1 = 2.9, 3.2


def scarf_loop(mb, r_in=0.5, r_out=0.86, z0=SCARF_Z0, z1=SCARF_Z1, part="Loop"):
    """The wrap around the neck: a soft band between the head and the sweater."""
    vs = mb.lathe([(r_in, z0), (r_out - 0.06, z0), (r_out, (z0 + z1) / 2), (r_out - 0.06, z1), (r_in, z1)], 16,
                  "white", (0, 0, 0), closed=True, part=part)
    squash(vs, 0.86)
    return vs


def scarf_long(k):
    """The signature long scarf: the wrap, a short end on the chest and a LONG end that flies out behind (it reads
    as speed when the Rookie runs, and gives the 48 px silhouette its tail)."""
    mb = k.MB("Rookie_Scarf_Long")
    scarf_loop(mb)
    strip(mb, [(-0.34, -0.66, 3.08), (-0.4, -0.86, 2.82), (-0.42, -0.9, 2.5), (-0.4, -0.88, 2.2)], 0.36, 0.1, "white",
          normal=(0, 1, 0), part="FrontEnd", taper=[1.0, 1.0, 0.95, 0.9])
    strip(mb, [(0.3, 0.6, 3.1), (0.42, 0.86, 2.92), (0.62, 1.12, 2.62), (0.9, 1.44, 2.42), (1.2, 1.78, 2.34),
               (1.5, 2.06, 2.4)], 0.38, 0.1, "white", normal=(0, -0.6, 1), part="BackEnd",
          taper=[1.0, 1.0, 0.96, 0.92, 0.9, 0.88])
    for i, dx in enumerate((-0.12, 0.0, 0.12)):     # fringe on the chest end
        mb.box((-0.4 + dx - 0.035, -0.92, 2.04), (-0.4 + dx + 0.035, -0.84, 2.2), "white", part=f"Fringe{i}")
    return k.finalize(mb, pivot=J["Neck"])


def scarf_chunky(k):
    mb = k.MB("Rookie_Scarf_Chunky")
    scarf_loop(mb, 0.48, 0.98, 2.86, 3.14, part="Lower")
    scarf_loop(mb, 0.46, 0.9, 3.06, 3.34, part="Upper")
    return k.finalize(mb, pivot=J["Neck"])


def scarf_bandana(k):
    mb = k.MB("Rookie_Scarf_Bandana")
    scarf_loop(mb, 0.5, 0.8, 2.94, 3.14)
    tri = [(-0.62, 3.1), (0.62, 3.1), (0.0, 2.42)]
    vs = mb.prism(tri, "Y", -0.6, -0.5, "white", "white", part="Point")
    for v in vs:                                        # follow the chest: it bulges out lower down
        v.co.y -= 0.3 * (3.1 - v.co.z) / 0.68
    mb.sphere((0, 0.72, 3.04), 0.16, 8, 5, "white", part="Knot")
    for sx in (-1, 1):
        t = mb.box((-0.07, -0.03, -0.24), (0.07, 0.03, 0.0), "white", part="Tie")
        mb.xform(t, Matrix.Translation(Vector((sx * 0.1, 0.78, 3.0))) @ Matrix.Rotation(math.radians(sx * 22), 4, "Y"))
    return k.finalize(mb, pivot=J["Neck"])


def scarf_knot(k):
    mb = k.MB("Rookie_Scarf_Knot")
    scarf_loop(mb)
    mb.sphere((0.3, -0.78, 3.0), 0.2, 10, 6, "white", part="Knot")
    for i, (dx, rot) in enumerate(((0.2, 8), (0.42, -10))):
        t = mb.box((-0.11, -0.04, -0.5), (0.11, 0.04, 0.0), "white", part=f"End{i}")
        mb.xform(t, Matrix.Translation(Vector((dx, -0.86, 2.92))) @ Matrix.Rotation(math.radians(rot), 4, "Y"))
    return k.finalize(mb, pivot=J["Neck"])


def sweater_stripes(k):
    """Breton stripes in the crew colour: three bands round the sweater and two on each upper arm."""
    mt = k.MB("Rookie_Stripes_Torso")
    for z in (2.16, 2.42, 2.66):
        r = max(prof_r(TORSO_PROF, z), prof_r(TORSO_PROF, z + 0.12))
        ring(mt, (0, 0, 0), r - 0.05, r + 0.025, z, z + 0.12, "white", sy=TORSO_SQ, part=f"Band{z}")
    torso = k.finalize(mt, pivot=J["Waist"])
    arms = []
    for side in (-1, 1):
        s = "Right" if side < 0 else "Left"
        sh, el = J[f"{s}Shoulder"], J[f"{s}Elbow"]
        ma = k.MB(f"Rookie_Stripes_{s}Arm")
        d = (Vector(el) - Vector(sh)).normalized()
        for t in (0.42, 0.78):
            c = along(sh, el, t)
            r = 0.3 + (0.27 - 0.3) * t
            ring(ma, tuple(c), r - 0.04, r + 0.025, -0.05, 0.05, "white", segs=10, part=f"Band{t}", axis=tuple(d))
        arms.append(k.finalize(ma, pivot=sh))
    return torso, arms


def sweater_block(k):
    """Colour block: one wide crew band across the chest, and crew cuffs."""
    mt = k.MB("Rookie_Block_Torso")
    z0, z1 = 2.3, 2.66
    r0, r1 = prof_r(TORSO_PROF, z0), prof_r(TORSO_PROF, z1)
    mt.lathe([(r0 - 0.05, z0), (r0 + 0.025, z0), (max(r0, 1.0) + 0.025, 2.5), (r1 + 0.025, z1), (r1 - 0.05, z1),
              (min(r0, r1) - 0.05, 2.5)], 16, "white", (0, 0, 0), closed=True, part="Block")
    squash([v for v in mt.bm.verts], TORSO_SQ)
    torso = k.finalize(mt, pivot=J["Waist"])
    cuffs = []
    for side in (-1, 1):
        s = "Right" if side < 0 else "Left"
        el, wr = J[f"{s}Elbow"], J[f"{s}Wrist"]
        mc = k.MB(f"Rookie_Block_{s}Cuff")
        d = (Vector(wr) - Vector(el)).normalized()
        ring(mc, tuple(along(el, wr, 0.55)), 0.22, 0.285, -0.08, 0.08, "white", segs=10, part="Cuff", axis=tuple(d))
        cuffs.append(k.finalize(mc, pivot=el))
    return torso, cuffs


def glove_cuffs(k, style):
    out = []
    for side in (-1, 1):
        s = "Right" if side < 0 else "Left"
        el, wr = J[f"{s}Elbow"], J[f"{s}Wrist"]
        mc = k.MB(f"Rookie_Gloves_{style}_{s}")
        d = (Vector(wr) - Vector(el)).normalized()
        c = Vector(wr) + d * 0.02
        if style == "Knit":   # a fat ribbed cuff rolled over the sleeve
            ring(mc, tuple(c), 0.12, 0.31, -0.13, 0.04, "white", segs=12, part="Cuff", axis=tuple(d))
            for a in range(0, 360, 60):
                u = d.orthogonal().normalized()
                w = d.cross(u)
                p = c + (u * math.cos(math.radians(a)) + w * math.sin(math.radians(a))) * 0.3
                rib = mc.box((-0.025, -0.025, -0.08), (0.025, 0.025, 0.08), "white", part=f"Rib{a}")
                mc.xform(rib, Matrix.Translation(p - d * 0.045) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4())
        else:                 # leather: a flared gauntlet and a strap with a stud
            mc.lathe([(0.12, -0.16), (0.3, -0.16), (0.36, 0.0), (0.36, 0.05), (0.12, 0.05)], 12, "white", tuple(c),
                     tuple(d), closed=True, part="Gauntlet")
            stud = c - d * 0.08 + Vector((0, -1, 0)) * 0.32
            mc.box(tuple(stud - Vector((0.05, 0.05, 0.05))), tuple(stud + Vector((0.05, 0.05, 0.05))), "white",
                   part="Stud")
        out.append(k.finalize(mc, pivot=wr))
    return out


def mask_eye(k):
    """The robber's domino mask: two rims round the eyes, a bridge and a band round the head."""
    mb = k.MB("Rookie_Mask_Eye")
    ez = EYE_Z
    for sx in (-1, 1):
        ex = sx * 0.31
        yf = head_front_y(ex, ez)
        rim = mb.lathe([(0.2, -0.05), (0.31, -0.05), (0.31, 0.05), (0.2, 0.05)], 12, "ink", (ex, yf + 0.0, ez),
                       (0, -1, 0), closed=True, part="Rim")
        for v in rim:
            v.co.z = ez + (v.co.z - ez) * 1.15
    mb.box((-0.14, head_front_y(0, ez) - 0.06, ez - 0.05), (0.14, head_front_y(0, ez) + 0.06, ez + 0.07), "ink",
           part="Bridge")
    band = ring(mb, (0, 0, 0), prof_r(HEAD_PROF, ez) - 0.04, prof_r(HEAD_PROF, ez) + 0.04, ez - 0.07, ez + 0.07,
                "ink", sy=HEAD_SQ, part="Band")
    mb.clip((0, -0.45, 0), (0, 1, 0), "ink", part_verts=band)
    for sx in (-1, 1):   # side straps from each rim's outer edge back to the band
        a = Vector((sx * 0.56, head_front_y(0.56, ez) + 0.02, ez))
        rb = prof_r(HEAD_PROF, ez)
        bxx = math.sqrt(max(0.0, rb * rb - (0.4 / HEAD_SQ) ** 2))
        b = Vector((sx * bxx, -0.4, ez))
        t = (b - a).normalized()
        strip(mb, [tuple(a), tuple(b)], 0.12, 0.07, "ink", normal=(-t.y, t.x, 0), part="Strap")
    return k.finalize(mb, pivot=J["FaceFront"])


# ---------------------------------------------------------------- first-person viewmodel

def viewmodel_arm(k, side):
    """The first-person forearm: the cream sleeve with its cuff and the knit glove (Ink Indigo light), one mesh.
    Pivot = the elbow; manifest grips = the palm centre (GripL / GripR)."""
    s = "Right" if side < 0 else "Left"
    el, wr = J[f"{s}Elbow"], J[f"{s}Wrist"]
    mb = k.MB(f"Rookie_VM_{s}Arm")
    limb(mb, el, wr, 0.27, 0.25, ["marble", "marble", "marble", "marble", "marble"], part="Fore")
    d = (Vector(wr) - Vector(el)).normalized()
    mb.cylinder(tuple(Vector(wr) - d * 0.12), tuple(d), 0.28, -0.07, 0.07, 10, "marble_lo", part="Cuff")
    ring(mb, tuple(Vector(wr) + d * 0.02), 0.2, 0.31, -0.13, 0.04, "ink", segs=12, part="GloveCuff", axis=tuple(d))
    hc = Vector(wr) + Vector((side * 0.03, -0.04, -0.27))
    ellipsoid(mb, tuple(hc), 1.0, 0.27, 0.3, 0.32, "ink_hi", segs=10, rings=6, part="Palm")
    for i, dx in enumerate((-0.12, 0.0, 0.12)):
        ellipsoid(mb, (hc.x + dx, hc.y - 0.17, hc.z - 0.2), 1.0, 0.085, 0.11, 0.1, "ink_hi", segs=6, rings=4,
                  part=f"Finger{i}")
    ellipsoid(mb, (hc.x - side * 0.25, hc.y - 0.12, hc.z + 0.06), 1.0, 0.1, 0.11, 0.14, "ink_hi", segs=6, rings=4,
              part="Thumb")
    return k.finalize(mb, pivot=el), tuple(hc)


# ---------------------------------------------------------------- assembly

R15_JOINTS = [
    # (part, joint, parent)
    ("LowerTorso", "Root", None), ("UpperTorso", "Waist", "LowerTorso"), ("Head", "Neck", "UpperTorso"),
    ("RightUpperArm", "RightShoulder", "UpperTorso"), ("RightLowerArm", "RightElbow", "RightUpperArm"),
    ("RightHand", "RightWrist", "RightLowerArm"),
    ("LeftUpperArm", "LeftShoulder", "UpperTorso"), ("LeftLowerArm", "LeftElbow", "LeftUpperArm"),
    ("LeftHand", "LeftWrist", "LeftLowerArm"),
    ("RightUpperLeg", "RightHip", "LowerTorso"), ("RightLowerLeg", "RightKnee", "RightUpperLeg"),
    ("RightFoot", "RightAnkle", "RightLowerLeg"),
    ("LeftUpperLeg", "LeftHip", "LowerTorso"), ("LeftLowerLeg", "LeftKnee", "LeftUpperLeg"),
    ("LeftFoot", "LeftAnkle", "LeftLowerLeg"),
]
JOINT_OF = {p: j for p, j, _ in R15_JOINTS}


def attach(k, part, point):
    """Manifest `attach`: the body part an outfit piece welds to and its pivot's offset from that part's pivot
    (Roblox axes)."""
    o = J[JOINT_OF[part]]
    return {"attach": {"part": part, "offset": k.roblox_point(point, o)}}


def check_seats(lf, pairs):
    bad = []
    for feat, surf in pairs:
        s = lf.seated(feat, surf)
        if not s["seated"]:
            bad.append(f"{feat.name} floats {s['gap']} off {surf.name}")
    if bad:
        raise AssertionError("A16 outfit seating: " + "; ".join(bad))


def build(k):
    lf = k.lf
    body = {}
    body["Head"], body["UpperTorso"], body["LowerTorso"] = head(k), upper_torso(k), lower_torso(k)
    hands = {}
    for side in (-1, 1):
        s = "Right" if side < 0 else "Left"
        ua, la, hd, hc = arm_parts(k, side)
        body[f"{s}UpperArm"], body[f"{s}LowerArm"], body[f"{s}Hand"] = ua, la, hd
        hands[s] = hc
        ul, ll, ft = leg_parts(k, side)
        body[f"{s}UpperLeg"], body[f"{s}LowerLeg"], body[f"{s}Foot"] = ul, ll, ft
    faces = {m: face(k, f"Rookie_Face_{m.capitalize()}", m) for m in ("idle", "smug", "shocked", "busted")}

    def part(name, **kw):
        joint, parent = next((j, par) for p, j, par in R15_JOINTS if p == name)
        ob = body[name]
        tint = name.endswith("Hand")
        return k.Obj(ob, "small", role="char", pivot="point", collision="Box", can_collide=False,
                     joint={"name": joint, "parent": ("Rookie_" + parent) if parent else None}, tags=["EH_Rookie"],
                     atlas=False if tint else None,
                     tint="glove colour (Config.Rookie.GLOVE_COLOURS, by the gloves slot)" if tint else None, **kw)

    objs = [part("LowerTorso", notes="the R15 root: hip centre 1.62 above the floor; HumanoidRootPart centre 3.0 (code)"),
            part("UpperTorso"), part("Head", symmetric="X")]
    for s in ("Right", "Left"):
        objs += [part(f"{s}UpperArm"), part(f"{s}LowerArm"), part(f"{s}Hand"), part(f"{s}UpperLeg"),
                 part(f"{s}LowerLeg"), part(f"{s}Foot")]

    def face_obj(m, ob):
        return k.Obj(ob, "small", role="char", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
                     free_shells=True, tags=["EH_Rookie", "EH_Face"], notes=f"face '{m}': one face shows at a time",
                     extra={**attach(k, "Head", J["FaceFront"]), "face": m})

    seats = [("Rookie_UpperTorso", "Rookie_LowerTorso"), ("Rookie_Head", "Rookie_UpperTorso"),
             ("Rookie_Face_Idle", "Rookie_Head")]
    for s in ("Right", "Left"):
        seats += [(f"Rookie_{s}UpperArm", "Rookie_UpperTorso"), (f"Rookie_{s}LowerArm", f"Rookie_{s}UpperArm"),
                  (f"Rookie_{s}Hand", f"Rookie_{s}LowerArm"), (f"Rookie_{s}UpperLeg", "Rookie_LowerTorso"),
                  (f"Rookie_{s}LowerLeg", f"Rookie_{s}UpperLeg"), (f"Rookie_{s}Foot", f"Rookie_{s}LowerLeg")]
    rookie = k.Asset("Rookie", objs + [face_obj("idle", faces["idle"])], budget_cls="creature", seats=seats,
                     notes="The Rookie: R15-compatible rigid body (15 parts, R15 joint pivots) + the idle face. "
                           "Scarf and stripes are outfit parts (crew colour).")

    # ---- outfits: built on the body, seat-checked against it, then laid out for the turntable
    caps = [cap_flat(k), cap_beanie(k), cap_bobble(k), cap_trapper(k)]
    scarves = [scarf_long(k), scarf_chunky(k), scarf_bandana(k), scarf_knot(k)]
    st_torso, st_arms = sweater_stripes(k)
    bl_torso, bl_cuffs = sweater_block(k)
    knit = glove_cuffs(k, "Knit")
    leather = glove_cuffs(k, "Leather")
    mask = mask_eye(k)
    pairs = [(c, body["Head"]) for c in caps] + [(s, body["UpperTorso"]) for s in scarves]
    pairs += [(st_torso, body["UpperTorso"]), (bl_torso, body["UpperTorso"]), (mask, body["Head"])]
    pairs += [(st_arms[0], body["RightUpperArm"]), (st_arms[1], body["LeftUpperArm"])]
    pairs += [(bl_cuffs[0], body["RightLowerArm"]), (bl_cuffs[1], body["LeftLowerArm"])]
    pairs += [(knit[0], body["RightHand"]), (knit[1], body["LeftHand"]), (leather[0], body["RightHand"]),
              (leather[1], body["LeftHand"])]
    pairs += [(faces[m], body["Head"]) for m in ("smug", "shocked", "busted")]
    check_seats(lf, pairs)

    def outfit(ob, slot, variant, part_, point, tint=None, sym=None, cls="small", bands=False):
        ex = {**attach(k, part_, point), "slot": slot, "variant": variant}
        # bands: separate rings held by the body part (seat-checked against it above), like glass panes in a frame
        return k.Obj(ob, cls, role="char", pivot="point", collision="Box", can_collide=False, symmetric=sym,
                     free_shells=bands,
                     atlas=False if tint else None, tint=tint, tags=["EH_Rookie", "EH_Outfit"], extra=ex,
                     notes=f"outfit {slot}: {variant}")

    crew = "crew colour (Palette seat hue)"
    glove = "glove colour (Config.Rookie.GLOVE_COLOURS)"
    o = []
    for ob, v in zip(caps, ("Flat", "Beanie", "Bobble", "Trapper")):
        o.append(outfit(ob, "cap", v, "Head", J["HatAttach"], sym="X"))
    for ob, v in zip(scarves, ("Long", "Chunky", "Bandana", "Knot")):
        o.append(outfit(ob, "scarf", v, "UpperTorso", J["Neck"], tint=crew))
    o.append(outfit(st_torso, "sweater", "Stripes", "UpperTorso", J["Waist"], tint=crew, sym="X", bands=True))
    o.append(outfit(st_arms[0], "sweater", "Stripes", "RightUpperArm", J["RightShoulder"], tint=crew, bands=True))
    o.append(outfit(st_arms[1], "sweater", "Stripes", "LeftUpperArm", J["LeftShoulder"], tint=crew, bands=True))
    o.append(outfit(bl_torso, "sweater", "Block", "UpperTorso", J["Waist"], tint=crew, sym="X"))
    o.append(outfit(bl_cuffs[0], "sweater", "Block", "RightLowerArm", J["RightElbow"], tint=crew))
    o.append(outfit(bl_cuffs[1], "sweater", "Block", "LeftLowerArm", J["LeftElbow"], tint=crew))
    o.append(outfit(knit[0], "gloves", "Knit", "RightHand", J["RightWrist"], tint=glove))
    o.append(outfit(knit[1], "gloves", "Knit", "LeftHand", J["LeftWrist"], tint=glove))
    o.append(outfit(leather[0], "gloves", "Leather", "RightHand", J["RightWrist"], tint=glove))
    o.append(outfit(leather[1], "gloves", "Leather", "LeftHand", J["LeftWrist"], tint=glove))
    o.append(outfit(mask, "mask", "Eye", "Head", J["FaceFront"], sym="X"))
    # turntable layout: a sticker sheet (rows by slot), far from the body (the body is not in this FBX)
    rows = {"cap": 0, "scarf": 1, "sweater": 2, "gloves": 3, "mask": 3}
    col_n = {}
    for ob in o:
        slot = ob.extra["slot"]
        i = col_n.get(slot, 0) + (4 if slot == "mask" else 0)
        col_n[slot] = col_n.get(slot, 0) + 1
        ob.ob.location += Vector((i * 2.6 - 4.0, 0.0, -rows[slot] * 2.6))
    outfits = k.Asset("Rookie_Outfits", o, notes="Outfit slots: cap x4 (atlas), scarf x4 + sweater x2 (crew colour), "
                                                  "gloves x2 (glove colour), mask x1 (+ none). Pivot = attach point.")
    fo = [face_obj(m, faces[m]) for m in ("smug", "shocked", "busted")]
    for i, ob in enumerate(fo):
        ob.ob.location += Vector(((i - 1) * 2.0, 0.0, 0.0))
    faces_asset = k.Asset("Rookie_Faces", fo, notes="Faces swapped with the idle face by state: smug (banked, "
                                                     "side-eye), shocked (zapped, seen), busted (caught).")

    # ---- the first-person viewmodel
    vm = []
    for side in (-1, 1):
        s = "Right" if side < 0 else "Left"
        ob, hc = viewmodel_arm(k, side)
        grip = k.roblox_point((hc[0], hc[1] - 0.05, hc[2]), J[f"{s}Elbow"])
        vm.append(k.Obj(ob, "small", role="char", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
                        tags=["EH_Rookie", "EH_Viewmodel"],
                        extra={"grip": {"name": "Grip" + s[0], "offset": grip}},
                        notes=f"first-person {s.lower()} forearm + knit glove; Grip{s[0]} = palm centre"))
    viewmodel = k.Asset("Rookie_Viewmodel", vm, notes="First-person arms (FP track): LeftArm / RightArm, pivot = elbow, "
                                                      "GripL / GripR at the palms; sleeve + knit glove, one mesh each.")
    return [rookie, faces_asset, outfits, viewmodel]
