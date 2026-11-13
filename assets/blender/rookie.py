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
  Rookie_Hands      the first-person gloves with fingers: palm + index / finger block / thumb, two segments each
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


def brow_path(ex, sx, pts):
    """A brow along the head's front: pts = (u, dz) pairs, u from the inner end (0) to the outer end (1) across the
    eye, dz above EYE_Z. Returns 3D points just proud of the face."""
    out = []
    for u, dz in pts:
        x = ex + sx * (-0.2 + 0.42 * u)
        z = EYE_Z + dz
        out.append((x, head_front_y(x, z) - 0.08, z))     # proud of the eye whites where they overlap
    return out


# Brow shapes per expression: (u, dz) inner -> outer; the width tapers to the tail (a brush stroke, thick inner end).
# sx = -1 is the Rookie's right (Blender -X).
BROWS = {
    "idle": {1: [(0, 0.21), (0.35, 0.25), (0.7, 0.255), (1, 0.21)], -1: [(0, 0.2), (0.35, 0.24), (0.7, 0.245), (1, 0.2)]},
    # smug: the right brow cocked high in an arch, the left one low and flat on the lid over the side-eye
    "smug": {-1: [(0, 0.24), (0.3, 0.31), (0.65, 0.335), (1, 0.27)], 1: [(0, 0.15), (0.35, 0.165), (0.7, 0.17), (1, 0.15)]},
    "shocked": {1: [(0, 0.3), (0.3, 0.36), (0.65, 0.37), (1, 0.31)], -1: [(0, 0.3), (0.3, 0.36), (0.65, 0.37), (1, 0.31)]},
    # busted: worried, the inner ends pushed up over the squeezed eyes
    "busted": {1: [(0, 0.27), (0.35, 0.22), (0.7, 0.16), (1, 0.11)], -1: [(0, 0.27), (0.35, 0.22), (0.7, 0.16), (1, 0.11)]},
}
BROW_TAPER = [1.0, 0.95, 0.8, 0.55]


def face(k, name, mood):
    """Eyes, brows, cheeks and mouth on the head's front (one face shows at a time; Heist/Rookie swaps them by state).
    Readable at 48 px: two light eye shapes with a shine, a dark brush-stroke brow over each (its shape is the
    expression), a light cheek highlight under each eye, and one dark mouth line."""
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
        else:
            big = mood == "shocked"
            rw, rh = (0.2, 0.26) if big else (0.18, 0.22)
            ellipsoid(mb, (ex, yf + 0.04, ez), 1.0, rw, 0.11, rh, "marble_hi", part="EyeWhite")
            if mood == "shocked":
                px, pz, pr = ex, ez, 0.075                          # small pupils, centred
            elif mood == "smug":
                px, pz, pr = ex + 0.09, ez - 0.05, 0.095            # hard side-eye, low under the lid
            else:
                px, pz, pr = ex + 0.06, ez - 0.01, 0.1              # idle: the relaxed side-eye
            ellipsoid(mb, (px, yf - 0.06, pz), 1.0, pr, 0.05, pr * 1.1, "ink", part="Pupil")
            # the shine: one light fleck high on the pupil, the same side on both eyes (one key light)
            ellipsoid(mb, (px - 0.035, yf - 0.1, pz + 0.045), 1.0, 0.032, 0.02, 0.036, "marble_hi", segs=6, rings=4,
                      part="Shine")
            if mood == "smug":                                       # half-lidded: a skin lid over the top half
                ellipsoid(mb, (ex, yf + 0.04, ez + 0.08), 1.0, rw + 0.03, 0.15, rh * 0.62, "skin_lo", part="Lid")
        # the brow: a tapered brush stroke along the face; its shape carries the expression
        strip(mb, brow_path(ex, sx, BROWS[mood][sx]), 0.13, 0.08, "hair", normal=(0, 1, 0), part="Brow",
              taper=BROW_TAPER)
        # the cheek highlight: a soft light oval on the cheekbone, under and outside the eye (the face's roundness)
        cx, cz = sx * 0.47, ez - 0.29
        cyf = head_front_y(cx, cz)
        cheek = ellipsoid(mb, (0, 0, 0), 1.0, 0.1, 0.025, 0.045, "marble_hi", segs=8, rings=4, part="Cheek")
        n = Vector((cx, cyf / HEAD_SQ ** 2, 0)).normalized()          # the head's outward normal there (squashed)
        yaw = math.atan2(n.x, -n.y)
        mb.xform(cheek, Matrix.Translation(Vector((cx, cyf + 0.005, cz))) @ Matrix.Rotation(yaw, 4, "Z"))
    # mouth
    mz = 3.4
    myf = head_front_y(0.0, mz)

    def arc(pts, w, t, col, part, taper=None):
        path = [(x, head_front_y(x, z) - 0.02, z) for x, z in pts]
        return strip(mb, path, w, t, col, normal=(0, 1, 0), part=part, taper=taper)

    if mood == "shocked":
        ellipsoid(mb, (0.0, myf + 0.02, mz - 0.02), 1.0, 0.11, 0.07, 0.14, "ink_hi", part="Mouth")
    elif mood == "busted":
        for i, x in enumerate((-0.2, -0.07, 0.07, 0.2)):         # a wobbly grimace: four tilted dashes
            dash = mb.box((-0.075, -0.03, -0.03), (0.075, 0.03, 0.03), "ink_hi", part=f"Grimace{i}")
            mb.xform(dash, Matrix.Translation(Vector((x, head_front_y(x, mz) - 0.015, mz + (0.03 if i % 2 else -0.03)))) @
                     Matrix.Rotation(math.radians(30 if i % 2 else -30), 4, "Y"))
    elif mood == "smug":
        # the smug smirk: flat on the left, hooking up on the Rookie's right (Blender -X), a dimple at that corner
        arc([(0.15, mz + 0.0), (0.04, mz - 0.02), (-0.08, mz - 0.012), (-0.17, mz + 0.045), (-0.22, mz + 0.1)], 0.08,
            0.08, "ink_hi", "Mouth", taper=[0.6, 1.0, 1.0, 0.95, 0.6])
        mb.sphere((-0.25, head_front_y(-0.25, mz + 0.12) - 0.01, mz + 0.12), 0.035, 6, 4, "ink_hi", part="Corner")
    else:
        # idle: a relaxed half smile, the right corner up a little
        arc([(0.16, mz + 0.0), (0.05, mz - 0.025), (-0.07, mz - 0.02), (-0.18, mz + 0.05)], 0.075, 0.08, "ink_hi",
            "Mouth", taper=[0.6, 1.0, 1.0, 0.65])
        mb.sphere((-0.2, head_front_y(-0.2, mz + 0.07) - 0.01, mz + 0.07), 0.03, 6, 4, "ink_hi", part="Corner")
    return k.finalize(mb, pivot=J["FaceFront"])


def upper_torso(k):
    mb = k.MB("Rookie_UpperTorso")
    # REVIEW_STEAM_PLUS #14: the sweater is Warm Marble light (luma 0.89) so it sits a clear value step above the
    # skin (0.63) under warm light too, and a dark knit collar (Ink Indigo light) cuts the head off the body at 48 px
    body = mb.lathe(TORSO_PROF, 16, ["marble", "marble", "marble_hi", "marble_hi", "marble_hi", "marble_hi",
                                     "marble_hi", "marble_hi", "ink_hi"], (0, 0, 0), part="Sweater")
    squash(body, TORSO_SQ)
    # ribbed hem: three shallow ribs read as knit at 64 px (the bands in the crew colour are the overlay)
    for z in (1.84, 1.92):
        ring(mb, (0, 0, 0), prof_r(TORSO_PROF, z + 0.03) - 0.03, prof_r(TORSO_PROF, z + 0.03) + 0.025, z, z + 0.05,
             "marble", sy=TORSO_SQ, part="Rib")
    # the collar: a raised dark rib round the neckline
    rc = prof_r(TORSO_PROF, 2.95)
    ring(mb, (0, 0, 0), rc - 0.05, rc + 0.04, 2.88, 3.0, "ink_hi", sy=TORSO_SQ, part="Collar")
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
    mu.sphere(sh, 0.34, 10, 6, "marble_hi", part="Shoulder")
    limb(mu, sh, el, 0.3, 0.27, ["marble_hi", "marble_hi", "marble_hi", "marble", "marble"], part="Upper")
    ua = k.finalize(mu, pivot=sh)
    ml = k.MB(f"Rookie_{s}LowerArm")
    limb(ml, el, wr, 0.27, 0.25, ["marble_hi", "marble_hi", "marble_hi", "marble_hi", "marble_hi"], part="Fore")
    d = (Vector(wr) - Vector(el)).normalized()
    ml.cylinder(tuple(Vector(wr) - d * 0.12), tuple(d), 0.28, -0.07, 0.07, 10, "marble", part="Cuff")
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
    """The signature long scarf: the wrap and a short end on the chest. Its LONG end that flies out behind (it reads
    as speed when the Rookie runs, and gives the 48 px silhouette its tail) is two separate pieces, scarf_tail()."""
    mb = k.MB("Rookie_Scarf_Long")
    scarf_loop(mb)
    strip(mb, [(-0.34, -0.66, 3.08), (-0.4, -0.86, 2.82), (-0.42, -0.9, 2.5), (-0.4, -0.88, 2.2)], 0.36, 0.1, "white",
          normal=(0, 1, 0), part="FrontEnd", taper=[1.0, 1.0, 0.95, 0.9])
    for i, dx in enumerate((-0.12, 0.0, 0.12)):     # fringe on the chest end
        mb.box((-0.4 + dx - 0.035, -0.92, 2.04), (-0.4 + dx + 0.035, -0.84, 2.2), "white", part=f"Fringe{i}")
    return k.finalize(mb, pivot=J["Neck"])


# The long scarf's tail: two segments, each pivoting at its hinge (Heist/ScarfSway bends them with your movement:
# it hangs when you stand, streams out as modelled when you run). Blender coordinates; the tail leaves the wrap at
# the back of the neck (TAIL_HINGE[0]) and bends at TAIL_HINGE[1].
TAIL_HINGE = [(0.3, 0.58, 3.08), (0.66, 1.16, 2.6)]


def scarf_tail(k):
    """Rookie_Scarf_Long_Tail1 (wrap -> the bend) and _Tail2 (the bend -> the fringed end). Each overlaps the next
    a little past its hinge so the bend never opens a gap."""
    m1 = k.MB("Rookie_Scarf_Long_Tail1")
    strip(m1, [(0.24, 0.48, 3.16), (0.3, 0.58, 3.08), (0.44, 0.86, 2.9), (0.66, 1.16, 2.6), (0.74, 1.26, 2.54)], 0.38,
          0.1, "white", normal=(0, -0.6, 1), part="Tail1", taper=[1.0, 1.0, 1.0, 0.96, 0.95])
    t1 = k.finalize(m1, pivot=TAIL_HINGE[0])
    m2 = k.MB("Rookie_Scarf_Long_Tail2")
    end = [(0.58, 1.06, 2.66), (0.66, 1.16, 2.6), (0.92, 1.46, 2.42), (1.2, 1.78, 2.34), (1.48, 2.04, 2.38)]
    strip(m2, end, 0.37, 0.1, "white", normal=(0, -0.6, 1), part="Tail2", taper=[0.97, 0.96, 0.93, 0.9, 0.88])
    d = (Vector(end[-1]) - Vector(end[-2])).normalized()
    side = d.cross(Vector((0, -0.6, 1)).normalized()).normalized()
    for i, s in enumerate((-0.11, 0.0, 0.11)):      # fringe on the flying end
        c = Vector(end[-1]) + side * s + d * 0.08
        strip(m2, [tuple(c - d * 0.06), tuple(c + d * 0.1)], 0.07, 0.07, "white", normal=(0, -0.6, 1),
              part=f"TailFringe{i}")
    t2 = k.finalize(m2, pivot=TAIL_HINGE[1])
    return t1, t2


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
    limb(mb, el, wr, 0.27, 0.25, ["marble_hi", "marble_hi", "marble_hi", "marble_hi", "marble_hi"], part="Fore")
    d = (Vector(wr) - Vector(el)).normalized()
    mb.cylinder(tuple(Vector(wr) - d * 0.12), tuple(d), 0.28, -0.07, 0.07, 10, "marble", part="Cuff")
    ring(mb, tuple(Vector(wr) + d * 0.02), 0.2, 0.31, -0.13, 0.04, "ink", segs=12, part="GloveCuff", axis=tuple(d))
    hc = Vector(wr) + Vector((side * 0.03, -0.04, -0.27))
    ellipsoid(mb, tuple(hc), 1.0, 0.27, 0.3, 0.32, "ink_hi", segs=10, rings=6, part="Palm")
    for i, dx in enumerate((-0.12, 0.0, 0.12)):
        ellipsoid(mb, (hc.x + dx, hc.y - 0.17, hc.z - 0.2), 1.0, 0.085, 0.11, 0.1, "ink_hi", segs=6, rings=4,
                  part=f"Finger{i}")
    ellipsoid(mb, (hc.x - side * 0.25, hc.y - 0.12, hc.z + 0.06), 1.0, 0.1, 0.11, 0.14, "ink_hi", segs=6, rings=4,
              part="Thumb")
    return k.finalize(mb, pivot=el), tuple(hc)


# ---------------------------------------------------------------- first-person hands with fingers (REVIEW #10)

# Segments of one gloved hand, built straight down from the body's wrist (the arm hanging, palm forward, the back of
# the hand behind): (name, parent, hinge offset from the wrist (inner x, forward y, up z; Blender units, inner = toward
# the body), radius, [(finger x offset from the hinge, length)]). The game turns each segment about its hinge
# (Heist/Viewmodel, Config.FirstPerson.VIEWMODEL.HANDS): open, grip, push, point, press, hands-up.
KNUCKLE_Z = -0.47
HAND_SEGS = [
    ("Index1", "Palm", (0.155, 0.0, KNUCKLE_Z), 0.07, [(0.0, 0.2)]),
    ("Index2", "Index1", (0.155, 0.0, KNUCKLE_Z - 0.2), 0.066, [(0.0, 0.16)]),
    ("Fingers1", "Palm", (-0.065, 0.0, KNUCKLE_Z), 0.066, [(0.11, 0.21), (0.0, 0.2), (-0.11, 0.17)]),
    ("Fingers2", "Fingers1", (-0.065, 0.0, KNUCKLE_Z - 0.2), 0.062, [(0.11, 0.15), (0.0, 0.14), (-0.11, 0.12)]),
    ("Thumb1", "Palm", (0.25, -0.05, -0.2), 0.078, [(0.0, 0.17)]),
    ("Thumb2", "Thumb1", (0.25, -0.05, -0.37), 0.072, [(0.0, 0.14)]),
]


def hand_pieces(k, side):
    """One first-person glove as hinged segments: the palm (pivot = the wrist) + index, the other three fingers as
    one block, and the thumb, two segments each (pivot = their hinge). Tint White: the glove colour at runtime."""
    s = "Right" if side < 0 else "Left"
    inn = -side
    wr = Vector(J[f"{s}Wrist"])
    out = []
    mp = k.MB(f"Rookie_Hand_{s}_Palm")
    ellipsoid(mp, tuple(wr + Vector((0.0, 0.0, -0.25))), 1.0, 0.28, 0.17, 0.26, "white", segs=10, rings=6, part="Palm")
    ellipsoid(mp, tuple(wr + Vector((0.0, 0.0, KNUCKLE_Z + 0.04))), 1.0, 0.28, 0.15, 0.08, "white", segs=10, rings=4,
              part="Knuckles")
    out.append((k.finalize(mp, pivot=tuple(wr)), "Palm", None, tuple(wr)))
    for name, parent, (hx, hy, hz), r, fingers in HAND_SEGS:
        hinge = wr + Vector((inn * hx, hy, hz))
        mb = k.MB(f"Rookie_Hand_{s}_{name}")
        if name.startswith("Thumb"):
            d = Vector((0.0, -0.25, -1.0)).normalized()
        else:
            d = Vector((0.0, 0.0, -1.0))
        for fx, length in fingers:
            a = hinge + Vector((inn * fx, 0.0, 0.0))
            b = a + d * length
            limb(mb, tuple(a), tuple(b), r, r * 0.95, ["white"] * 5, segs=8, part="Seg")
            if name.endswith("2"):
                mb.sphere(tuple(b), r * 0.98, 8, 5, "white", part="Tip")
        out.append((k.finalize(mb, pivot=tuple(hinge)), name, parent, tuple(hinge)))
    return out


# ---------------------------------------------------------------- dedicated first-person arms (FP hands pass)
#
# docs/research/fp_hands.md: premium games never reuse the body arm as the viewmodel. These arms are modelled for the
# eye: a slim sweater sleeve (radius 0.135 at the cuff, was 0.27 on the body), a gloved hand with a palm that has
# thickness, four fingers of three segments each with knuckles, a three-segment thumb, rounded and smooth-shaded.
# Authored in the GRIP SPACE of each hand (Roblox axes, full size, origin = the palm centre): fingers along -Z, the
# back of the hand +Y, the forearm along +Z; the right hand's thumb is on -X. One piece per finger segment (pivot =
# its hinge), the palm and the glove cuffs on the hand frame, the sleeve, its crew stripes or colour-block cuff and
# the REWIND watch on the forearm frame (pivot = the wrist hinge). The game (Heist/FpRig, Heist/Viewmodel) bends the
# fingers about their hinges, the wrist about its hinge, and aims the forearm at an off-screen elbow.
FP_GRIP_X = 0.9             # Blender x of each hand's grip in the asset (right hand at -X: Roblox +X)
FP_WRIST_Z = 0.2            # the wrist hinge, grip space
FP_FINGERS = [
    # name, MCP hinge (grip space, right hand), segment lengths, base radius, fan (rest splay, toward the thumb +)
    ("Index", (-0.150, 0.004, -0.180), (0.150, 0.110, 0.088), 0.051, 1.0),
    ("Middle", (-0.050, 0.010, -0.196), (0.164, 0.120, 0.094), 0.053, 0.25),
    ("Ring", (0.049, 0.004, -0.188), (0.154, 0.114, 0.090), 0.050, -0.5),
    ("Pinky", (0.142, -0.008, -0.162), (0.120, 0.090, 0.076), 0.045, -1.0),
]
FP_TAPER = (1.0, 0.94, 0.88, 0.83)   # radius at each joint along a finger (base, PIP, DIP, tip) as shares of the base
FP_THUMB = [
    # name, length, radius base -> end, direction (grip space, right hand)
    ("Thumb1", 0.150, (0.066, 0.060), (-0.52, -0.30, -0.80)),
    ("Thumb2", 0.112, (0.058, 0.054), (-0.30, -0.22, -0.93)),
    ("Thumb3", 0.094, (0.054, 0.047), (-0.22, -0.18, -0.96)),
]
FP_THUMB_BASE = (-0.130, -0.040, 0.075)
FP_THUMB_UP = (-0.62, 0.78, 0.0)     # the thumbnail side (right hand)
# sleeve profile along +Z from the wrist side (grip space z, radius): ribbed cuff, slim forearm, widening to the edge
FP_SLEEVE = [(0.25, 0.128), (0.26, 0.142), (0.29, 0.147), (0.31, 0.140), (0.33, 0.147), (0.35, 0.140), (0.37, 0.147),
             (0.39, 0.140), (0.41, 0.136), (0.9, 0.146), (1.6, 0.160), (2.3, 0.170), (2.9, 0.176)]
FP_SLEEVE_RIB = 9           # profile edges before this index are the rib cuff (one value step darker)
FP_STRIPES = (0.66, 0.88)   # Breton stripes (crew), grip-space z centres
FP_STRIPE_W = 0.075
FP_BLOCK = (0.42, 0.6)      # the colour-block cuff (crew), z from / to
FP_WATCH_Z = 0.47


def fp_sleeve_r(z):
    for (z0, r0), (z1, r1) in zip(FP_SLEEVE, FP_SLEEVE[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return FP_SLEEVE[-1][1]


def fp_point(p, side):
    """A grip-space point (Roblox axes, right-hand numbers mirrored for the left) -> Blender coordinates."""
    x, y, z = p
    x *= -side          # side -1 = right (Roblox +X is Blender -X), +1 = left (mirrored)
    gx = -FP_GRIP_X if side < 0 else FP_GRIP_X
    return Vector((gx - x, z, y))


def fp_dir(d, side):
    x, y, z = d
    x *= -side
    return Vector((-x, z, y)).normalized()


def capsule(mb, a, b, r0, r1, col, segs=8, cap=2, part=None):
    """A tapered capsule from a to b with hemispherical ends (finger segments: the overlapping ends read as knuckles
    and stay closed when the joint bends)."""
    a, b = Vector(a), Vector(b)
    L_ = (b - a).length
    prof = [(0.0, -r0)]
    for i in range(1, cap + 1):
        t = math.pi / 2 * i / (cap + 1)
        prof.append((r0 * math.sin(t), -r0 * math.cos(t)))
    prof += [(r0, 0.0), (r1, L_)]
    for i in range(cap, 0, -1):
        t = math.pi / 2 * i / (cap + 1)
        prof.append((r1 * math.sin(t), L_ + r1 * math.cos(t)))
    prof.append((0.0, L_ + r1))
    return mb.lathe(prof, segs, col, tuple(a), tuple((b - a).normalized()), phase=math.pi / segs, part=part)


def fp_palm(k, side, name):
    """The glove's palm: a rounded box (a superellipsoid) with thickness, narrower at the wrist, the back domed, and
    four knuckle bumps along the MCP line."""
    mb = k.MB(name)
    c = fp_point((0.0, 0.0, -0.005), side)
    vs = mb.sphere(tuple(c), 1.0, 12, 8, "white", axis=(0, 1, 0), part="Palm")
    e = 0.55
    for v in vs:
        n = v.co - c
        if n.length < 1e-9:
            continue
        n.normalize()
        # n.y runs along the hand (Blender +Y = Roblox +Z: toward the wrist), n.z is up (the back of the hand)
        along = math.copysign(abs(n.y) ** e, n.y)
        hw = 0.212 - 0.03 * max(0.0, along)                          # narrower toward the wrist
        up = math.copysign(abs(n.z) ** 0.75, n.z)
        th = 0.092 if up > 0 else 0.078                              # a domed back, a flatter palm side
        v.co = c + Vector((math.copysign(abs(n.x) ** e, n.x) * hw, along * 0.205, up * th))
        v.co.z += 0.012 * (1 - abs(along)) * (1 if up > 0 else 0.4)   # the back arches over the knuckles
    for fname, hinge, _lens, r, _fan in FP_FINGERS:
        h = fp_point((hinge[0], hinge[1] + 0.03, hinge[2] + 0.03), side)
        ellipsoid(mb, tuple(h), 1.0, r * 0.95, r * 0.95, r * 0.75, "white", segs=6, rings=3, part="Knuckle" + fname)
    return k.finalize(mb, shading="angle", angle=70, pivot=tuple(fp_point((0, 0, 0), side)))


def fp_hand_pieces(k, side):
    """One first-person glove: (ob, joint, parent, hinge (grip space), look, up) per piece."""
    s = "Left" if side > 0 else "Right"
    out = [(fp_palm(k, side, f"Rookie_FP_{s}_Palm"), "Palm", None, (0.0, 0.0, 0.0), (0, 0, -1), (0, 1, 0))]
    up = (0.0, 1.0, 0.0)
    for fname, hinge, lens, r, fan in FP_FINGERS:
        d = Vector((-fan * 0.07, 0.0, -1.0)).normalized()     # grip space (right hand): the rest splay
        p = Vector(hinge)
        parent = "Palm"
        for i, ln in enumerate(lens):
            joint = f"{fname}{i + 1}"
            mb = k.MB(f"Rookie_FP_{s}_{joint}")
            a, b = p, p + d * ln
            capsule(mb, fp_point(a, side), fp_point(b, side), r * FP_TAPER[i], r * FP_TAPER[i + 1], "white",
                    part="Seg")
            ob = k.finalize(mb, shading="angle", angle=70, pivot=tuple(fp_point(a, side)))
            out.append((ob, joint, parent, tuple(a), tuple(d), up))
            parent, p = joint, b
    p = Vector(FP_THUMB_BASE)
    parent = "Palm"
    for joint, ln, (r0, r1), dd in FP_THUMB:
        d = Vector(dd).normalized()
        mb = k.MB(f"Rookie_FP_{s}_{joint}")
        capsule(mb, fp_point(p, side), fp_point(p + d * ln, side), r0, r1, "white", part="Seg")
        ob = k.finalize(mb, shading="angle", angle=70, pivot=tuple(fp_point(p, side)))
        out.append((ob, joint, parent, tuple(p), tuple(d), FP_THUMB_UP))
        parent, p = joint, p + d * ln
    return out


def fp_cuffs(k, side):
    """The gloves slot's cuff on the first-person wrist (glove colour): the knit roll (three ridges) or the leather
    gauntlet (a flare, a strap and a stud). Hand frame, pivot = the grip."""
    s = "Left" if side > 0 else "Right"
    axis = tuple(fp_dir((0, 0, 1), side))
    c = fp_point((0, 0, 0), side)
    out = []
    mk = k.MB(f"Rookie_FP_{s}_CuffKnit")
    prof = [(0.118, 0.13), (0.160, 0.13), (0.176, 0.15), (0.168, 0.175), (0.178, 0.20), (0.168, 0.225), (0.178, 0.25),
            (0.162, 0.275), (0.118, 0.275)]
    mk.lathe(prof, 14, "white", tuple(c), axis, closed=True, part="Roll")
    out.append((k.finalize(mk, shading="angle", angle=50, pivot=tuple(c)), "CuffKnit", "Knit"))
    ml = k.MB(f"Rookie_FP_{s}_CuffLeather")
    prof = [(0.118, 0.12), (0.166, 0.12), (0.180, 0.16), (0.200, 0.27), (0.206, 0.31), (0.196, 0.325), (0.118, 0.325)]
    ml.lathe(prof, 14, "white", tuple(c), axis, closed=True, part="Gauntlet")
    a = fp_point((-0.075, 0.0, 0.215), side)
    b = fp_point((0.075, 0.0, 0.215), side)
    lo = Vector((min(a.x, b.x), min(a.y, b.y) - 0.025, 0.0))
    top = fp_point((0, 0.188, 0.215), side).z
    ml.box((lo.x, lo.y, top - 0.02), (max(a.x, b.x), lo.y + 0.05, top + 0.014), "white", chamfer=0.006, part="Strap")
    st = fp_point((0, 0.204, 0.215), side)
    ml.sphere(tuple(st), 0.02, 6, 3, "white", part="Stud")
    out.append((k.finalize(ml, shading="angle", angle=50, pivot=tuple(c)), "CuffLeather", "Leather"))
    return out


def fp_arm_pieces(k, side):
    """The forearm frame (pivot = the wrist hinge): the cream sleeve with its ribbed cuff, the Breton stripes and the
    colour-block cuff (crew colour), and on the left the REWIND watch."""
    s = "Left" if side > 0 else "Right"
    axis = fp_dir((0, 0, 1), side)
    wrist = fp_point((0, 0, FP_WRIST_Z), side)
    c = fp_point((0, 0, 0), side)
    out = []
    ms = k.MB(f"Rookie_FP_{s}_Sleeve")
    prof = [(0.0, FP_SLEEVE[0][0])] + [(r, z) for z, r in FP_SLEEVE] + [(0.0, FP_SLEEVE[-1][0])]
    cols = ["marble_lo"] + ["marble_lo" if i < FP_SLEEVE_RIB else "marble" for i in range(len(FP_SLEEVE) - 1)] + \
        ["marble_lo"]
    vs = ms.lathe(prof, 12, cols, tuple(c), tuple(axis), part="Sleeve")
    for v in vs:     # a forearm is wider than deep
        v.co.z = c.z + (v.co.z - c.z) * 0.9
    out.append((k.finalize(ms, shading="angle", angle=50, pivot=tuple(wrist)), "Sleeve", None, None))
    mt = k.MB(f"Rookie_FP_{s}_Stripes")
    for z in FP_STRIPES:
        r = fp_sleeve_r(z)
        ring(mt, tuple(c), r - 0.012, r + 0.011, z - FP_STRIPE_W / 2, z + FP_STRIPE_W / 2, "white", segs=12,
             part=f"Band{z}", axis=tuple(axis))
    for v in mt.bm.verts:
        v.co.z = c.z + (v.co.z - c.z) * 0.9
    out.append((k.finalize(mt, shading="angle", angle=50, pivot=tuple(wrist)), "Stripes", "sweater", "Stripes"))
    mbk = k.MB(f"Rookie_FP_{s}_Block")
    z0, z1 = FP_BLOCK
    mbk.lathe([(fp_sleeve_r(z0) - 0.012, z0), (fp_sleeve_r(z0) + 0.012, z0), (fp_sleeve_r(z0) + 0.016, z0 + 0.02),
               (fp_sleeve_r(z1) + 0.016, z1 - 0.02), (fp_sleeve_r(z1) + 0.012, z1), (fp_sleeve_r(z1) - 0.012, z1)],
              12, "white", tuple(c), tuple(axis), closed=True, part="Block")
    for v in mbk.bm.verts:
        v.co.z = c.z + (v.co.z - c.z) * 0.9
    out.append((k.finalize(mbk, shading="angle", angle=50, pivot=tuple(wrist)), "Block", "sweater", "Block"))
    if side > 0:
        mw = k.MB("Rookie_FP_Left_Watch")
        r = fp_sleeve_r(FP_WATCH_Z)
        ring(mw, tuple(c), r - 0.014, r + 0.014, FP_WATCH_Z - 0.032, FP_WATCH_Z + 0.032, "ink_hi", segs=12,
             part="Band", axis=tuple(axis))
        for v in mw.bm.verts:
            v.co.z = c.z + (v.co.z - c.z) * 0.9
        top = fp_point((0, r * 0.9 + 0.008, FP_WATCH_Z), side)
        mw.cylinder(tuple(top), (0, 0, 1), 0.07, 0.0, 0.03, 12, "steel_hi", cap_col="marble_hi", chamfer=0.008,
                    cham_col="steel", part="Face")
        hz = top.z + 0.031
        mw.box((top.x - 0.006, top.y - 0.045, hz - 0.004), (top.x + 0.006, top.y + 0.004, hz + 0.004), "ink", part="Min")
        mw.box((top.x - 0.004, top.y - 0.004, hz - 0.004), (top.x + 0.032, top.y + 0.004, hz + 0.004), "ink", part="Hr")
        out.append((k.finalize(mw, shading="angle", angle=40, pivot=tuple(wrist)), "Watch", None, None))
    return out


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
    tail = scarf_tail(k)
    st_torso, st_arms = sweater_stripes(k)
    bl_torso, bl_cuffs = sweater_block(k)
    knit = glove_cuffs(k, "Knit")
    leather = glove_cuffs(k, "Leather")
    mask = mask_eye(k)
    pairs = [(c, body["Head"]) for c in caps] + [(s, body["UpperTorso"]) for s in scarves]
    pairs += [(tail[0], scarves[0]), (tail[1], tail[0])]
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
    for i, ob in enumerate(tail):   # the long scarf's swaying tail (Heist/ScarfSway): pivot = its hinge
        o.append(outfit(ob, "scarf", "Long", "UpperTorso", TAIL_HINGE[i], tint=crew, bands=i == 1))
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
    # ---- the first-person hands with fingers (Viewmodel.fromOutfit swaps them in for the mitts)
    hand_objs = []
    for side in (-1, 1):
        s = "Right" if side < 0 else "Left"
        built = hand_pieces(k, side)
        by = {n: ob for ob, n, _, _ in built}
        check_seats(lf, [(by[n], by[par]) for _, n, par, _ in built if par])
        for ob, name, parent, hinge in built:
            hand_objs.append(k.Obj(ob, "small", role="char", pivot="point", collision="Box", can_collide=False,
                                   cast_shadow=False, atlas=False, tint=glove, tags=["EH_Rookie", "EH_Hand"],
                                   extra={**attach(k, f"{s}Hand", hinge),
                                          "finger": {"name": name, "parent": parent, "side": s}},
                                   notes=f"first-person {s.lower()} glove: {name} (pivot = its hinge)"))
    hands_asset = k.Asset("Rookie_Hands", hand_objs, notes="First-person gloves with fingers (REVIEW #10): palm + "
                                                           "index, finger block and thumb in two segments each, "
                                                           "pivots at the hinges; glove colour at runtime.")
    # ---- the dedicated first-person arms (FP hands pass, docs/research/fp_hands.md): new pieces, a new group
    fp_objs = []
    for side in (-1, 1):
        s = "Left" if side > 0 else "Right"
        grip = fp_point((0, 0, 0), side)

        def rdir(d):
            b = fp_dir(d, side)
            return [round(-b.x, 4) + 0.0, round(b.z, 4) + 0.0, round(b.y, 4) + 0.0]

        hand = fp_hand_pieces(k, side)
        by = {j: ob for ob, j, *_r in hand}
        check_seats(lf, [(ob, by[par]) for ob, _j, par, *_r in hand if par])
        for ob, joint, parent, hinge, look, up in hand:
            fp = {"side": s, "joint": joint, "parent": parent, "frame": "hand",
                  "hinge": k.roblox_point(fp_point(hinge, side), grip), "look": rdir(look), "up": rdir(up)}
            fp_objs.append(k.Obj(ob, "small", role="char", pivot="point", collision="Box", can_collide=False,
                                 cast_shadow=False, atlas=False, tint=glove, tags=["EH_Rookie", "EH_FPArm"],
                                 extra={"fp": fp}, notes=f"first-person {s.lower()} glove: {joint} (pivot = its hinge)"))
        cuffs = fp_cuffs(k, side)
        for ob, joint, variant in cuffs:
            fp = {"side": s, "joint": joint, "parent": None, "frame": "hand", "hinge": [0.0, 0.0, 0.0],
                  "slot": "gloves", "variant": variant}
            fp_objs.append(k.Obj(ob, "small", role="char", pivot="point", collision="Box", can_collide=False,
                                 cast_shadow=False, atlas=False, tint=glove, tags=["EH_Rookie", "EH_FPArm"],
                                 extra={"fp": fp}, notes=f"first-person {s.lower()} {variant.lower()} glove cuff"))
        arm = fp_arm_pieces(k, side)
        sleeve = arm[0][0]
        check_seats(lf, [(ob, sleeve) for ob, *_r in arm[1:]] + [(sleeve, cuffs[0][0]), (sleeve, cuffs[1][0])])
        for ob, joint, slot, variant in arm:
            fp = {"side": s, "joint": joint, "parent": None, "frame": "arm",
                  "hinge": k.roblox_point(fp_point((0, 0, FP_WRIST_Z), side), grip)}
            if slot:
                fp["slot"], fp["variant"] = slot, variant
            tinted = slot == "sweater"
            fp_objs.append(k.Obj(ob, "small", role="char", pivot="point", collision="Box", can_collide=False,
                                 cast_shadow=False, atlas=False if tinted else None, tint=crew if tinted else None,
                                 free_shells=joint == "Stripes", tags=["EH_Rookie", "EH_FPArm"], extra={"fp": fp},
                                 notes=f"first-person {s.lower()} forearm: {joint} (pivot = the wrist hinge)"))
    fp_asset = k.Asset("Rookie_FPArms", fp_objs, budget_cls="creature",
                       notes="Dedicated first-person arms: slim sleeve (ribbed cuff, crew stripes or block), gloved "
                             "hands with a palm, 4 fingers x 3 segments, a 3-segment thumb, knit / leather cuffs, the "
                             "REWIND watch. Grip space: fingers -Z, back of the hand +Y; pivots at the hinges.")
    return [rookie, faces_asset, outfits, viewmodel, hands_asset, fp_asset]
