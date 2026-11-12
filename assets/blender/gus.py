"""Gus the night guard, v0 (MASTERPLAN 3.1, 6.5, 6.7): a rigid-part rig with R15 proportions, built for a code pose
player (no skinning, no armature). Plus Gus_DonutBox, his storytelling prop (one per room he guards).

Build: python3 tools/blender/build_asset.py assets/blender/gus.py
Character (original): a stout, sleepy night guard who takes his job far too seriously. Read at 64 px: the tall
peaked cap with a big visor, the round head with a huge dark handlebar moustache, a barrel belly in a light
blue-grey shirt (his main value, luma 0.55 against 0.2 walls), short dark legs, big shoes and an oversized
flashlight in his right hand. The cone of Torch Amber light is drawn by code (MASTERPLAN 6.5), never baked here.

Parts (15 R15 body parts + Cap, Flashlight, FlashlightLens; Gus_SantaHat is its own model in the Christmas layer):
every part's ORIGIN IS ITS JOINT with the
parent (manifest `joint` = {name, parent}; R15 joint names where they exist). A pose player sets
part:PivotTo(parent:GetPivot() * C0 * pose) with C0 = CFrame.new(origin[child] - origin[parent]) (manifest `origin`,
both at rest), never part.CFrame (a MeshPart's CFrame is its bounding-box centre; the joint is its PivotOffset;
docs/art/KIT_IMPORT.md "Gus"). Rest pose: arms hang 6 degrees out, the flashlight points forward.
Gus_Cap and Gus_SantaHat share the head's top (code shows one: SantaHat while the Christmas layer is on).
Tris: <= 5,000 for the whole rig (MASTERPLAN 6.7). Colours: char cells (skin, hair, shirt) + Ink / Steel / Marble;
never location cells (rule P3), so Gus looks the same in every location.
Coordinates: front -Y (he faces -Y), Z up, origin of the Model = between the feet on the floor. His RIGHT hand is at
Blender -X (Roblox +X after the export: the RightVector side of a -Z-facing character).
"""
import math
import _kitlib as L
from mathutils import Matrix, Vector

# joint positions (Blender coordinates). Right side = -X.
J = {
    "Root": (0.0, 0.0, 2.1), "Waist": (0.0, 0.0, 2.62), "Neck": (0.0, 0.0, 4.5),
    "RightShoulder": (-1.42, 0.0, 4.12), "RightElbow": (-1.52, 0.0, 3.28), "RightWrist": (-1.6, 0.0, 2.5),
    "LeftShoulder": (1.42, 0.0, 4.12), "LeftElbow": (1.52, 0.0, 3.28), "LeftWrist": (1.6, 0.0, 2.5),
    "RightHip": (-0.52, 0.0, 1.95), "RightKnee": (-0.52, 0.0, 1.15), "RightAnkle": (-0.52, 0.0, 0.42),
    "LeftHip": (0.52, 0.0, 1.95), "LeftKnee": (0.52, 0.0, 1.15), "LeftAnkle": (0.52, 0.0, 0.42),
    "HatAttach": (0.0, 0.0, 5.78),
}


def torso_front_y(z):
    """Front surface (y) of the belly barrel at height z (matches upper_torso's profile, squash and bump)."""
    prof = [(2.55, 1.05), (2.9, 1.3), (3.35, 1.36), (3.9, 1.25), (4.3, 1.05), (4.5, 0.55)]
    for (z0, r0), (z1, r1) in zip(prof, prof[1:]):
        if z0 <= z <= z1:
            r = r0 + (r1 - r0) * (z - z0) / (z1 - z0)
            break
    else:
        r = 0.5
    return -(r * 0.8 + belly_bump(z))


def belly_bump(z):
    return 0.22 * max(0.0, math.sin(math.pi * (z - 2.6) / 1.5)) if 2.6 <= z <= 4.1 else 0.0


# ---------------------------------------------------------------- body

def upper_torso(k):
    mb = k.MB("Gus_UpperTorso")
    prof = [(0, 2.55), (1.05, 2.55), (1.3, 2.9), (1.36, 3.35), (1.25, 3.9), (1.05, 4.3), (0.55, 4.5), (0, 4.55)]
    body = mb.lathe([(r, z) for r, z in prof], 16, ["shirt_lo", "shirt", "shirt", "shirt", "shirt", "shirt_lo", "shirt_lo"],
                    (0, 0, 0), part="Barrel")
    for v in body:   # squash front-back, then push the belly forward
        v.co.y *= 0.8
        if v.co.y < 0:
            v.co.y -= belly_bump(v.co.z) * min(1.0, -v.co.y / 0.6)
    # tie: three tapering boxes following the belly front
    for z0, z1, w in ((4.0, 4.38, 0.16), (3.45, 4.0, 0.2), (3.0, 3.45, 0.17)):
        zc = (z0 + z1) / 2
        yf = torso_front_y(zc)
        mb.box((-w, yf - 0.06, z0), (w, yf + 0.12, z1), "ink_hi", chamfer=0.04, cham_col="ink_hi", part="Tie")
    mb.box((-0.12, torso_front_y(4.42) - 0.08, 4.3), (0.12, torso_front_y(4.42) + 0.16, 4.5), "ink_hi", part="Knot")
    # collar and epaulettes (uniform read), badge on his left chest (+X)
    mb.lathe([(0.42, 4.42), (0.66, 4.42), (0.62, 4.62), (0.44, 4.62)], 12, "shirt_lo", (0, 0, 0), closed=True, part="Collar")
    for sx in (-1, 1):
        mb.box((sx * 0.78 - 0.36, -0.38, 4.2), (sx * 0.78 + 0.36, 0.38, 4.36), "ink_hi",
               chamfer=0.05, cham_col="steel_lo", part="Epaulette")
    bz = 3.95
    badge = [(0.42, bz + 0.22), (0.72, bz + 0.22), (0.72, bz - 0.05), (0.57, bz - 0.22), (0.42, bz - 0.05)]
    yf = torso_front_y(bz) + 0.12
    mb.prism(badge, "Y", yf - 0.1, yf + 0.06, ["marble", "marble_hi", "marble", "marble", "marble_hi"], "marble_hi", part="Badge")
    # pockets with flaps (shirt_lo) either side of the tie
    for sx in (-1, 1):
        z = 3.62
        y = torso_front_y(z)
        mb.box((sx * 0.45 - 0.22, y - 0.02, z - 0.1), (sx * 0.45 + 0.22, y + 0.2, z + 0.06), "shirt_lo", chamfer=0.03,
               cham_col="shirt", part="Pocket")
    return k.finalize(mb, pivot=J["Waist"])


def lower_torso(k):
    mb = k.MB("Gus_LowerTorso")
    body = mb.lathe([(0, 1.72), (0.85, 1.72), (1.08, 1.95), (1.12, 2.4), (1.05, 2.68), (0, 2.68)], 16,
                    ["ink_hi", "ink_hi", "ink_hi", "ink_hi", "ink_hi"], (0, 0, 0), part="Hips")
    for v in body:
        v.co.y *= 0.78
    belt = mb.lathe([(1.08, 2.36), (1.17, 2.38), (1.17, 2.6), (1.08, 2.62)], 16, ["ink", "ink", "ink", "ink"], (0, 0, 0),
                    closed=True, part="Belt")
    for v in belt:
        v.co.y *= 0.8
    mb.box((-0.24, -0.98, 2.33), (0.24, -0.86, 2.65), "steel_hi", chamfer=0.04, cham_col="steel_hi", part="Buckle")
    # key ring and two keys on his left hip (+X): a little jingle detail at 64 px it is a bright dot
    ring = [(1.1 + 0.16 * math.cos(math.radians(a)), -0.25, 2.2 + 0.16 * math.sin(math.radians(a))) for a in range(-60, 241, 30)]
    L.tube(mb, ring, 0.035, 4, "steel_hi", part="KeyRing", normal=(0, 1, 0))
    mb.box((1.06, -0.32, 2.3), (1.14, -0.12, 2.46), "steel_hi", part="KeyClip")
    for dx, rot in ((-0.06, 15), (0.08, -20)):
        key = mb.box((-0.035, -0.02, -0.34), (0.035, 0.02, 0.02), "steel_hi", part="Key")
        mb.xform(key, Matrix.Translation(Vector((1.1 + dx, -0.25, 2.06))) @ Matrix.Rotation(math.radians(rot), 4, "Y"))
    return k.finalize(mb, pivot=J["Root"])


def head(k):
    mb = k.MB("Gus_Head")
    prof = [(0, 4.4), (0.48, 4.45), (0.8, 4.82), (0.87, 5.22), (0.82, 5.62), (0.58, 5.92), (0, 6.0)]
    skull = mb.lathe(prof, 16, ["skin_lo", "skin_lo", "skin", "skin", "skin", "skin"], (0, 0, 0), part="Skull")
    for v in skull:
        v.co.y *= 0.92
    mb.sphere((0, -0.86, 5.18), 0.3, 8, 5, "skin", part="Nose")                      # the big round nose
    for sx in (-1, 1):
        ear = mb.sphere((sx * 0.84, 0.0, 5.2), 0.2, 6, 4, "skin_lo", part="Ear")
        for v in ear:
            v.co.y = v.co.y * 0.6
        mb.sphere((sx * 0.3, -0.74, 5.44), 0.1, 6, 4, "ink", part="Eye")             # beady eyes
        brow = mb.box((-0.24, -0.1, -0.06), (0.24, 0.1, 0.07), "hair", chamfer=0.04, cham_col="hair", part="Brow")
        mb.xform(brow, Matrix.Translation(Vector((sx * 0.31, -0.74, 5.6))) @ Matrix.Rotation(math.radians(-14 * sx), 4, "Y"))
    # the handlebar moustache: a thick outline bent around the face (ends sweep back and up)
    mo = [(-1.0, 5.14), (-0.8, 5.0), (-0.5, 5.1), (-0.15, 5.12), (0.0, 5.06), (0.15, 5.12), (0.5, 5.1), (0.8, 5.0), (1.0, 5.14),
          (0.92, 4.98), (0.7, 4.84), (0.35, 4.8), (0.0, 4.86), (-0.35, 4.8), (-0.7, 4.84), (-0.92, 4.98)]
    vs = mb.prism(mo, "Y", -0.2, 0.12, "hair", "hair", part="Moustache")
    for v in vs:
        v.co.y += -0.8 + 0.42 * (v.co.x / 1.0) ** 2
    mb.box((-0.3, -0.72, 4.62), (0.3, -0.6, 4.72), "skin_lo", chamfer=0.04, cham_col="skin_lo", part="Mouth")
    return k.finalize(mb, pivot=J["Neck"])


def cap(k):
    mb = k.MB("Gus_Cap")
    crown = mb.lathe([(0, 5.72), (0.86, 5.72), (0.9, 5.92), (1.02, 6.32), (0.98, 6.46), (0, 6.5)], 16,
                     ["ink_hi", "ink", "ink_hi", "steel_lo", "ink_hi"], (0, 0, 0), part="Crown")
    for v in crown:
        v.co.y *= 0.95
    v2 = mb.prism([(x, y) for x, y in [(0.82, -0.45)] + [(0.82 * math.cos(math.radians(a)), -0.45 - 0.95 * math.sin(math.radians(a))) for a in range(10, 171, 20)] + [(-0.82, -0.45)]],
                  "Z", 5.7, 5.8, "ink", "ink", part="Visor")
    mb.rotate(v2, -12, "X", (0, -0.45, 5.75))
    shield = [(-0.2, 6.32), (0.2, 6.32), (0.2, 6.08), (0.0, 5.94), (-0.2, 6.08)]
    mb.prism(shield, "Y", -0.98, -0.86, "marble", "marble_hi", part="CapBadge")
    return k.finalize(mb, pivot=J["HatAttach"])


def santa_hat(k):
    mb = k.MB("Gus_SantaHat")
    path = [(0, 0.0, 5.7), (0, 0.05, 6.15), (0, 0.22, 6.6), (0, 0.5, 6.95), (0, 0.85, 7.05), (0, 1.15, 6.85), (0, 1.3, 6.5)]
    L.tube(mb, path, [0.95, 0.88, 0.7, 0.5, 0.33, 0.2, 0.12], 12, "ribbon",
           cols=["ribbon", "ribbon", "ribbon_hi", "ribbon", "ribbon_hi", "ribbon"], cap_col="ribbon", part="Cone", normal=(1, 0, 0))
    mb.lathe([(0.82, 5.62), (1.1, 5.62), (1.12, 5.95), (0.84, 5.95)], 16, ["snow", "snow", "snow", "snow"], (0, 0, 0), closed=True, part="Fur")
    mb.sphere((0, 1.35, 6.35), 0.28, 8, 5, "snow", part="Pompom")
    return k.finalize(mb, pivot=J["HatAttach"])


def limb(mb, a, b, r0, r1, col, segs=10, part="Limb"):
    """A tapered limb from joint a to joint b with chamfered ends (a capsule-ish block)."""
    a, b = Vector(a), Vector(b)
    d = (b - a)
    n = d.normalized()
    L_ = d.length
    prof = [(0, -0.08), (r0 * 0.75, -0.08), (r0, 0.06), (r1, L_ - 0.06), (r1 * 0.75, L_ + 0.06), (0, L_ + 0.06)]
    return mb.lathe(prof, segs, col if isinstance(col, list) else [col] * 5, tuple(a), tuple(n), part=part)


def arm_parts(k, side):
    s = "Right" if side < 0 else "Left"
    sh, el, wr = J[f"{s}Shoulder"], J[f"{s}Elbow"], J[f"{s}Wrist"]
    mu = k.MB(f"Gus_{s}UpperArm")
    mu.sphere(sh, 0.42, 10, 6, "shirt", part="Shoulder")
    limb(mu, sh, el, 0.36, 0.32, ["shirt", "shirt", "shirt", "shirt_lo", "shirt_lo"], part="Upper")
    ua = k.finalize(mu, pivot=sh)
    ml = k.MB(f"Gus_{s}LowerArm")
    limb(ml, el, wr, 0.32, 0.29, ["shirt", "shirt", "shirt", "shirt", "shirt"], part="Fore")
    cuff = Vector(wr) + (Vector(el) - Vector(wr)).normalized() * 0.2
    ml.cylinder(tuple(cuff), tuple((Vector(wr) - Vector(el)).normalized()), 0.33, -0.12, 0.12, 10, "shirt_lo", part="Cuff")
    la = k.finalize(ml, pivot=el)
    mh = k.MB(f"Gus_{s}Hand")
    hc = Vector(wr) + Vector((0, -0.05, -0.25))
    hand = mh.sphere(tuple(hc), 0.32, 8, 6, "skin", part="Fist")
    for v in hand:
        v.co.z = hc.z + (v.co.z - hc.z) * 1.1
        v.co.x = hc.x + (v.co.x - hc.x) * 0.9
    mh.sphere((hc.x - side * 0.22, hc.y - 0.18, hc.z + 0.08), 0.13, 6, 4, "skin_lo", part="Thumb")
    hd = k.finalize(mh, pivot=wr)
    return ua, la, hd, tuple(hc)


def leg_parts(k, side):
    s = "Right" if side < 0 else "Left"
    hp, kn, an = J[f"{s}Hip"], J[f"{s}Knee"], J[f"{s}Ankle"]
    mu = k.MB(f"Gus_{s}UpperLeg")
    limb(mu, hp, kn, 0.42, 0.36, "ink_hi", part="Thigh")
    ul = k.finalize(mu, pivot=hp)
    ml = k.MB(f"Gus_{s}LowerLeg")
    limb(ml, kn, an, 0.36, 0.33, "ink_hi", part="Shin")
    ll = k.finalize(ml, pivot=kn)
    mf = k.MB(f"Gus_{s}Foot")
    x = an[0]
    mf.box((x - 0.4, -0.95, 0.0), (x + 0.4, 0.38, 0.5), "ink", chamfer=0.18, cham_col="ink_hi", flat=("-z",), part="Shoe")
    mf.box((x - 0.42, -0.97, 0.0), (x + 0.42, 0.4, 0.12), "steel_lo", part="Sole")
    mf.cylinder((x, 0.0, 0.4), (0, 0, 1), 0.3, 0.0, 0.25, 8, "ink_hi", part="Sock")
    ft = k.finalize(mf, pivot=an)
    return ul, ll, ft


def flashlight(k, hc):
    """The oversized torch, gripped in the right fist and pointing forward (-Y)."""
    mb = k.MB("Gus_Flashlight")
    c = Vector(hc)
    fwd = (0, -1, 0)
    mb.cylinder(tuple(c + Vector((0, 0.45, 0))), fwd, 0.23, 0.0, 1.6, 10, "ink", part="Body")
    for t in (0.22, 0.44, 0.66, 1.2):
        mb.cylinder(tuple(c + Vector((0, 0.45, 0))), fwd, 0.255, t, t + 0.09, 10, "steel", part="Grip")
    head_c = c + Vector((0, -1.15, 0))
    mb.lathe([(0, 0.0), (0.23, 0.0), (0.46, 0.48), (0.49, 0.62), (0.39, 0.62), (0, 0.62)], 12,
             ["steel", "steel", "steel_hi", "steel_hi", "ink"], tuple(head_c), fwd, part="Head")
    mb.cylinder(tuple(c + Vector((0, 0.45, 0))), fwd, 0.23, -0.07, 0.0, 10, "steel_hi", part="Tail")
    fl = k.finalize(mb, pivot=hc)
    ml = k.MB("Gus_FlashlightLens")
    lens_c = head_c + Vector((0, -0.6, 0))
    ml.cylinder(tuple(lens_c), fwd, 0.4, 0.0, 0.05, 12, "white", part="Lens")
    ln = k.finalize(ml, pivot=tuple(lens_c))
    return fl, ln


# ---------------------------------------------------------------- donut box (storytelling prop)

def donut_box(k):
    mb = k.MB("Gus_DonutBox")
    W, Dp, Hb = 2.6, 1.9, 0.55
    x0, x1, y0, y1 = -W / 2, W / 2, -Dp / 2, Dp / 2
    mb.box((x0, y0, 0.0), (x1, y1, 0.08), "marble", part="Bottom")
    for lo, hi in (((x0, y0, 0.0), (x1, y0 + 0.06, Hb)), ((x0, y1 - 0.06, 0.0), (x1, y1, Hb)),
                   ((x0, y0, 0.0), (x0 + 0.06, y1, Hb)), ((x1 - 0.06, y0, 0.0), (x1, y1, Hb))):
        mb.box(lo, hi, "marble", part="Wall")
    mb.box((x0 + 0.06, y0 + 0.06, 0.08), (x1 - 0.06, y1 - 0.06, 0.1), "marble_lo", part="Paper")
    lid = mb.box((x0, 0.0, -0.06), (x1, Dp, 0.0), "marble", part="Lid")
    lid += mb.box((-0.5, 0.5, 0.0), (0.5, 1.3, 0.02), "plum_hi", part="Label")   # bakery label: faces the viewer when open
    mb.rotate(lid, 75, "X", (0, 0, 0))                                              # opened 105 degrees, leaning back
    mb.move(lid, (0, y1, Hb))
    # four donuts (two eaten): dough ring + vanilla or chocolate icing, sprinkles
    spots = ((-0.62, -0.42, "marble_hi"), (0.62, -0.42, "wood_lo"), (-0.62, 0.45, None), (0.62, 0.45, "marble_hi"))
    for i, (dx, dy, icing) in enumerate(spots):
        if icing is None:   # an empty paper crumb ring: someone ate this one
            mb.cylinder((dx, dy, 0.1), (0, 0, 1), 0.3, 0.0, 0.03, 8, "wood_hi", part=f"Crumbs_{i}")
            continue
        mb.lathe([(0.16, 0.1), (0.4, 0.1), (0.46, 0.22), (0.4, 0.34), (0.16, 0.34), (0.12, 0.22)], 10,
                 ["wood_hi", "wood_hi", icing, icing, icing, "wood_hi"], (dx, dy, 0.0), closed=True, part=f"Donut_{i}")
        for j, col in enumerate(("ink_hi", "steel_hi", "plum_hi")):
            a = 2 * math.pi * (j + 0.4 * i) / 3
            mb.box((dx + 0.28 * math.cos(a) - 0.04, dy + 0.28 * math.sin(a) - 0.015, 0.33), (dx + 0.28 * math.cos(a) + 0.04,
                   dy + 0.28 * math.sin(a) + 0.015, 0.37), col, part=f"Sprinkle_{i}{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Gus_DonutBox", [k.Obj(ob, "small", role="env", pivot="point", collision="Box", can_collide=False,
                                          tags=["EH_Story"], sim="none", notes="storytelling prop: one per room Gus guards (a desk, a crate)")],
                   notes="Gus's donut box: open pastry box, two donuts left (vanilla and chocolate), one eaten, crumbs.")


def build(k):
    ut, lt, hd, cp, sh = upper_torso(k), lower_torso(k), head(k), cap(k), santa_hat(k)
    rua, rla, rh, rhc = arm_parts(k, -1)
    lua, lla, lh, _lhc = arm_parts(k, 1)
    rul, rll, rf = leg_parts(k, -1)
    lul, lll, lf_ = leg_parts(k, 1)
    fl, ln = flashlight(k, rhc)
    def part(ob, joint, parent, **kw):
        return k.Obj(ob, kw.pop("cls", "small"), role=kw.pop("role", "char"), pivot="point", collision="Box",
                     can_collide=False, joint={"name": joint, "parent": parent}, tags=["EH_Guard"], **kw)
    objs = [
        part(lt, "Root", None, notes="the root: place the Model by this part's pivot (hip centre, 2.1 above the floor)"),
        part(ut, "Waist", "Gus_LowerTorso"), part(hd, "Neck", "Gus_UpperTorso", symmetric="X"),
        part(cp, "HatAttach", "Gus_Head", symmetric="X", notes="hidden while the Christmas layer shows the Santa hat"),
        part(rua, "RightShoulder", "Gus_UpperTorso"), part(rla, "RightElbow", "Gus_RightUpperArm"), part(rh, "RightWrist", "Gus_RightLowerArm"),
        part(lua, "LeftShoulder", "Gus_UpperTorso"), part(lla, "LeftElbow", "Gus_LeftUpperArm"), part(lh, "LeftWrist", "Gus_LeftLowerArm"),
        part(rul, "RightHip", "Gus_LowerTorso"), part(rll, "RightKnee", "Gus_RightUpperLeg"), part(rf, "RightAnkle", "Gus_RightLowerLeg"),
        part(lul, "LeftHip", "Gus_LowerTorso"), part(lll, "LeftKnee", "Gus_LeftUpperLeg"), part(lf_, "LeftAnkle", "Gus_LeftLowerLeg"),
        part(fl, "FlashlightGrip", "Gus_RightHand", notes="points along -Z (Roblox); the amber cone starts at the lens"),
        k.Obj(ln, "tiny", role="char", pivot="point", collision="Box", material="Neon", can_collide=False, cast_shadow=False,
              atlas=False, joint={"name": "Lens", "parent": "Gus_Flashlight"}, tags=["EH_Guard"],
              tint="Torch Amber #FFD27A when the cone is on; Vault Steel shade #4E5675 off (code)",
              notes="Neon lens; the Torch Amber cone is a code-drawn floor cone (MASTERPLAN 6.5)"),
    ]
    seats = [("Gus_UpperTorso", "Gus_LowerTorso"), ("Gus_Head", "Gus_UpperTorso"), ("Gus_Cap", "Gus_Head"),
             ("Gus_RightUpperArm", "Gus_UpperTorso"), ("Gus_RightLowerArm", "Gus_RightUpperArm"), ("Gus_RightHand", "Gus_RightLowerArm"),
             ("Gus_LeftUpperArm", "Gus_UpperTorso"), ("Gus_LeftLowerArm", "Gus_LeftUpperArm"), ("Gus_LeftHand", "Gus_LeftLowerArm"),
             ("Gus_RightUpperLeg", "Gus_LowerTorso"), ("Gus_RightLowerLeg", "Gus_RightUpperLeg"), ("Gus_RightFoot", "Gus_RightLowerLeg"),
             ("Gus_LeftUpperLeg", "Gus_LowerTorso"), ("Gus_LeftLowerLeg", "Gus_LeftUpperLeg"), ("Gus_LeftFoot", "Gus_LeftLowerLeg"),
             ("Gus_Flashlight", "Gus_RightHand"), ("Gus_FlashlightLens", "Gus_Flashlight")]
    gus = k.Asset("Gus", objs, budget_cls="creature", seats=seats,
                  notes="Gus v0: rigid R15-style rig (18 parts), joint pivots for the code pose player; cap, torch, Neon lens.")
    hat = k.Asset("Gus_SantaHat", [k.Obj(sh, "small", role="xmas", pivot="point", collision="Box", can_collide=False, layer="xmas",
                                         symmetric="X", joint={"name": "HatAttach", "parent": "Gus_Head"}, tags=["EH_Guard", "EH_Xmas"],
                                         notes="Christmas layer: weld to Gus_Head at the HatAttach point and hide Gus_Cap")],
                  notes="Gus's Santa hat (Christmas layer): Ribbon cone flopping back, snow fur band and pompom; same pivot as Gus_Cap.")
    return [gus, hat, donut_box(k)]
