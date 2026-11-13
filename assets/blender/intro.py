"""The story intro's stage (docs/art/intro/STORYBOARD.md, PLAN_FIRST_PERSON 5 "INTRO", MASTERPLAN 2.2 + 4.3):
Sir Hoardsworth, his lever, the giant vacuum, the hero Snow Globe Vault, three flying presents, the kid's letter and
two toy-town houses. Client-only set pieces (Heist/Cinematic builds the stage from ReplicatedStorage/EH_IntroKit);
none of them is ever in a level, simulated, collided with or queried.

Build: python3 tools/blender/build_asset.py assets/blender/intro.py

Sir Hoardsworth (original): a tall, thin toy tycoon (8.7 studs to the hat top; Gus 6.5, players 5.2) in a burgundy
velvet tailcoat with antique-gold trim, a cream waistcoat, white gloves, a top hat with a burgundy band, a curled
cream moustache and a monocle. Never green or furry (MASTERPLAN 2.2). Read at 64 px: the stovepipe hat, the thin
legs and long coat tails, the burgundy coat (luma 0.27 under a hot key) against cream gloves and moustache.
Rig: rigid parts like Gus (STYLE_BIBLE 12): R15 names, each part's ORIGIN IS ITS JOINT with the parent; the
cinematic poses them with part:PivotTo(parent * C0 * pose), C0 = origin[child] - origin[parent]
(Shared/Heist/IntroRig). The monocle's pivot is the lens centre: the code glint sits there.
Colours: role "villain" = env + char (skin) + xmas (Ribbon velvet, Snow gloves) + tint; antique gold is Warm Marble
shade (never Heist Gold: he is not loot); no location cells (rule P3), so he looks the same on any atlas.
Coordinates: front -Y (Roblox -Z), Z up; right side = Blender -X (Roblox +X).
"""
import math
import _kitlib as L
from mathutils import Matrix, Vector

# ------------------------------------------------------------------ Sir Hoardsworth
J = {
    "Root": (0.0, 0.0, 3.55), "Waist": (0.0, 0.0, 4.0), "Neck": (0.0, 0.0, 6.1),
    "RightShoulder": (-0.92, 0.0, 5.8), "RightElbow": (-1.04, 0.0, 4.8), "RightWrist": (-1.1, 0.0, 3.9),
    "LeftShoulder": (0.92, 0.0, 5.8), "LeftElbow": (1.04, 0.0, 4.8), "LeftWrist": (1.1, 0.0, 3.9),
    "RightHip": (-0.36, 0.0, 3.42), "RightKnee": (-0.36, 0.0, 1.92), "RightAnkle": (-0.36, 0.0, 0.42),
    "LeftHip": (0.36, 0.0, 3.42), "LeftKnee": (0.36, 0.0, 1.92), "LeftAnkle": (0.36, 0.0, 0.42),
    "HatAttach": (0.0, 0.0, 7.36),
    "Monocle": (-0.2, -0.47, 6.92),
}
SQ = 0.72   # front-back squash of the torso: he is thin side-on


def limb(mb, a, b, r0, r1, col, segs=10, part="Limb"):
    a, b = Vector(a), Vector(b)
    d = b - a
    n = d.normalized()
    ln = d.length
    prof = [(0, -0.06), (r0 * 0.75, -0.06), (r0, 0.06), (r1, ln - 0.05), (r1 * 0.75, ln + 0.06), (0, ln + 0.06)]
    return mb.lathe(prof, segs, col if isinstance(col, list) else [col] * 5, tuple(a), tuple(n), part=part)


def coat_front_y(z):
    """The coat's front surface (y) at height z (upper_torso's lathe, squashed)."""
    prof = [(3.95, 0.5), (4.4, 0.6), (5.2, 0.68), (5.65, 0.8), (6.0, 0.55)]
    for (z0, r0), (z1, r1) in zip(prof, prof[1:]):
        if z0 <= z <= z1:
            return -(r0 + (r1 - r0) * (z - z0) / (z1 - z0)) * SQ
    return -0.4


def h_upper_torso(k):
    mb = k.MB("Hoardsworth_UpperTorso")
    prof = [(0, 3.92), (0.5, 3.92), (0.6, 4.4), (0.68, 5.2), (0.8, 5.65), (0.55, 6.0), (0.24, 6.12), (0, 6.14)]
    body = mb.lathe(prof, 16, ["ribbon", "ribbon", "ribbon", "ribbon_hi", "ribbon", "ribbon", "ribbon"], (0, 0, 0),
                    part="Coat")
    for v in body:
        v.co.y *= SQ
    # cream waistcoat in the coat's open front: a tapered panel
    wy = coat_front_y(4.8)
    mb.prism([(-0.3, 3.95), (0.3, 3.95), (0.36, 5.55), (0.0, 5.75), (-0.36, 5.55)], "Y", wy - 0.12, wy + 0.25,
             "marble", "marble_hi", part="Waistcoat")
    # gold lapels: two long slanted strips framing the waistcoat
    for sx in (-1, 1):
        lap = [(sx * 0.32, 4.1), (sx * 0.5, 4.1), (sx * 0.62, 5.5), (sx * 0.42, 5.95), (sx * 0.3, 5.7)]
        if sx < 0:
            lap = list(reversed(lap))
        y = coat_front_y(5.0)
        mb.prism(lap, "Y", y - 0.08, y + 0.2, "marble_lo", "marble_lo", part="Lapel")
    # three gold buttons down the waistcoat, a white cravat bow at the throat, a pocket square
    for i, z in enumerate((4.3, 4.7, 5.1)):
        mb.sphere((0.0, coat_front_y(z) - 0.15, z), 0.075, 6, 4, "marble_lo", part=f"Button{i}")
    cy = coat_front_y(5.85)
    mb.sphere((0.0, cy - 0.12, 5.86), 0.13, 8, 5, "snow", part="CravatKnot")
    for sx in (-1, 1):
        wing = [(0.0, 5.92), (sx * 0.34, 6.02), (sx * 0.3, 5.7)]
        if sx < 0:
            wing = list(reversed(wing))
        mb.prism(wing, "Y", cy - 0.18, cy + 0.06, "snow", "snow", part="Cravat")
    pocket = [(0.42, 5.12), (0.62, 5.12), (0.58, 5.32), (0.52, 5.24), (0.46, 5.34)]
    py = coat_front_y(5.2)
    mb.prism(pocket, "Y", py - 0.06, py + 0.1, "snow", "snow", part="PocketSquare")
    # the high villain collar standing up behind the head (velvet, gold-edged)
    collar = [(-0.5, 5.7), (0.5, 5.7), (0.74, 6.62), (0.4, 6.48), (-0.4, 6.48), (-0.74, 6.62)]
    cv = mb.prism(collar, "Y", 0.2, 0.34, ["ribbon", "ribbon_hi", "marble_lo", "marble_lo", "marble_lo", "ribbon_hi"],
                  "ribbon_hi", part="Collar")
    for v in cv:
        v.co.y += (v.co.z - 5.7) * 0.35   # leaning back
    # gold epaulette bars on the shoulders
    for sx in (-1, 1):
        mb.box((sx * 0.72 - 0.22, -0.22, 5.86), (sx * 0.72 + 0.22, 0.22, 5.98), "marble_lo", chamfer=0.04,
               cham_col="marble", part="Epaulette")
    return k.finalize(mb, pivot=J["Waist"])


def h_lower_torso(k):
    mb = k.MB("Hoardsworth_LowerTorso")
    hips = mb.lathe([(0, 3.15), (0.48, 3.15), (0.6, 3.4), (0.58, 4.05), (0, 4.1)], 14,
                    ["ink_hi", "ink_hi", "ink_hi", "ink_hi"], (0, 0, 0), part="Hips")
    for v in hips:
        v.co.y *= 0.8
    # gold waistband
    band = mb.lathe([(0.56, 3.88), (0.63, 3.9), (0.63, 4.06), (0.56, 4.08)], 14, ["marble_lo"] * 4, (0, 0, 0),
                    closed=True, part="Band")
    for v in band:
        v.co.y *= 0.8
    # the long velvet tails: two tapered panels behind, split at the centre, flaring out to knee height
    for sx in (-1, 1):
        tail = [(0.04, 4.05), (0.62, 4.05), (0.7, 2.7), (0.44, 2.15), (0.08, 2.4)]
        tail = [(sx * x, z) for x, z in tail]
        if sx < 0:
            tail = list(reversed(tail))
        vs = mb.prism(tail, "Y", 0.3, 0.46, "ribbon_hi", "ribbon", part="Tail")
        for v in vs:   # lean the tails out behind as they fall
            v.co.y += (4.05 - v.co.z) * 0.12
        # gold trim at the tail's bottom edge
        trim = [(sx * 0.1, 2.38), (sx * 0.46, 2.12), (sx * 0.72, 2.66), (sx * 0.7, 2.8), (sx * 0.46, 2.3),
                (sx * 0.1, 2.52)]
        if sx < 0:
            trim = list(reversed(trim))
        tv = mb.prism(trim, "Y", 0.27, 0.49, "marble_lo", "marble_lo", part="TailTrim")
        for v in tv:
            v.co.y += (4.05 - v.co.z) * 0.12
    # a gold watch chain looping across the front
    chain = [(-0.42, -0.44, 3.98), (-0.2, -0.5, 3.8), (0.05, -0.5, 3.74), (0.3, -0.48, 3.82), (0.46, -0.42, 3.96)]
    L.tube(mb, chain, 0.035, 4, "marble_lo", part="Chain")
    return k.finalize(mb, pivot=J["Root"])


def h_head(k):
    mb = k.MB("Hoardsworth_Head")
    prof = [(0, 6.02), (0.2, 6.04), (0.34, 6.25), (0.44, 6.7), (0.45, 7.05), (0.38, 7.32), (0.2, 7.44), (0, 7.46)]
    skull = mb.lathe(prof, 14, ["skin_lo", "skin_lo", "skin", "skin", "skin", "skin", "skin"], (0, 0, 0), part="Skull")
    for v in skull:
        v.co.y *= 0.9
        if v.co.z < 6.4:   # a long pointed chin, pushed forward
            v.co.y -= (6.4 - v.co.z) * 0.35
    # the long sharp nose, tipping down
    L.tube(mb, [(0, -0.3, 6.98), (0, -0.62, 6.86), (0, -0.78, 6.72)], [0.12, 0.08, 0.035], 6, "skin", part="Nose",
           normal=(1, 0, 0))
    for sx in (-1, 1):
        ear = mb.sphere((sx * 0.44, 0.02, 6.86), 0.13, 6, 4, "skin_lo", part="Ear")
        for v in ear:
            v.co.y *= 0.6
        # eyes: his left (+X) narrowed in a sneer, his right wide behind the monocle
        mb.sphere((sx * 0.19, -0.38, 6.95), 0.07 if sx > 0 else 0.085, 6, 4, "ink", part="Eye")
        # brows: sharp, inner ends down (sinister); cream like the moustache
        brow = mb.box((-0.17, -0.06, -0.04), (0.17, 0.06, 0.05), "marble_hi", chamfer=0.02, cham_col="marble_hi",
                      part="Brow")
        mb.xform(brow, Matrix.Translation(Vector((sx * 0.2, -0.38, 7.1))) @ Matrix.Rotation(math.radians(22 * sx), 4, "Y"))
        # slicked cream sideburns
        mb.box((sx * 0.39 - 0.05, -0.1, 6.66), (sx * 0.39 + 0.05, 0.12, 6.98), "marble_hi", chamfer=0.03,
               cham_col="marble_hi", part="Sideburn")
    # the curled moustache: a bar under the nose, ends swept out and up into curls
    mo = [(-0.5, 6.72), (-0.3, 6.68), (-0.1, 6.74), (0.0, 6.7), (0.1, 6.74), (0.3, 6.68), (0.5, 6.72),
          (0.44, 6.62), (0.24, 6.57), (0.0, 6.62), (-0.24, 6.57), (-0.44, 6.62)]
    vs = mb.prism(mo, "Y", -0.1, 0.08, "marble_hi", "marble_hi", part="Moustache")
    for v in vs:
        v.co.y += -0.4 + 0.3 * (v.co.x / 0.5) ** 2
    for sx in (-1, 1):
        curl = [(sx * (0.48 + 0.12 * math.sin(a)), -0.32 + 0.0 * a, 6.78 + 0.12 * (1 - math.cos(a)) * 0.9)
                for a in (0.0, 0.9, 1.8, 2.7, 3.6)]
        curl = [(sx * 0.46, -0.3, 6.7)] + curl
        L.tube(mb, curl, [0.06, 0.055, 0.05, 0.045, 0.04, 0.03], 6, "marble_hi", part="Curl", normal=(0, 1, 0))
    mb.box((-0.14, -0.4, 6.42), (0.18, -0.3, 6.47), "skin_lo", chamfer=0.02, cham_col="skin_lo", part="Smirk")
    return k.finalize(mb, pivot=J["Neck"])


def h_hat(k):
    mb = k.MB("Hoardsworth_Hat")
    z0 = J["HatAttach"][2]
    brim = mb.lathe([(0, z0 - 0.02), (0.72, z0 - 0.02), (0.8, z0 + 0.06), (0.72, z0 + 0.1), (0, z0 + 0.1)], 16,
                    ["ink", "ink_hi", "ink", "ink"], (0, 0, 0), part="Brim")
    for v in brim:
        v.co.y *= 0.9
        v.co.z += 0.08 * (v.co.x / 0.8) ** 2   # curled up at the sides
    crown = mb.lathe([(0, z0 + 0.06), (0.47, z0 + 0.06), (0.47, z0 + 0.32), (0.49, z0 + 0.36), (0.49, z0 + 0.5),
                      (0.47, z0 + 0.54), (0.53, z0 + 1.32), (0.5, z0 + 1.38), (0, z0 + 1.4)], 16,
                     ["ink_hi", "ribbon", "ribbon_hi", "ribbon", "ink_hi", "ink_hi", "ink_hi", "ink_hi"], (0, 0, 0),
                     part="Crown")
    for v in crown:
        v.co.y *= 0.9
    mb.box((-0.12, -0.5, z0 + 0.32), (0.12, -0.4, z0 + 0.52), "marble_lo", chamfer=0.03, cham_col="marble",
           part="Buckle")
    return k.finalize(mb, pivot=J["HatAttach"])


def h_monocle(k):
    mb = k.MB("Hoardsworth_Monocle")
    c = Vector(J["Monocle"])
    mb.lathe([(0.16, -0.03), (0.21, -0.03), (0.21, 0.03), (0.16, 0.03)], 14, ["marble_lo", "marble", "marble_lo",
             "marble_lo"], tuple(c), (0, 1, 0), closed=True, part="Rim")
    mb.cylinder(tuple(c), (0, 1, 0), 0.17, -0.012, 0.012, 14, "steel_hi", part="Lens")
    # the chain drops from the rim to the jaw
    L.tube(mb, [tuple(c + Vector((-0.2, 0.0, -0.04))), tuple(c + Vector((-0.24, 0.12, -0.3))),
                tuple(c + Vector((-0.22, 0.3, -0.5)))], 0.025, 4, "marble_lo", part="Chain", normal=(1, 0, 0))
    return k.finalize(mb, pivot=J["Monocle"])


def h_arm(k, side):
    s = "Right" if side < 0 else "Left"
    sh, el, wr = J[f"{s}Shoulder"], J[f"{s}Elbow"], J[f"{s}Wrist"]
    mu = k.MB(f"Hoardsworth_{s}UpperArm")
    mu.sphere(sh, 0.3, 10, 6, "ribbon", part="Shoulder")
    limb(mu, sh, el, 0.26, 0.22, ["ribbon", "ribbon", "ribbon", "ribbon_hi", "ribbon_hi"], part="Upper")
    ua = k.finalize(mu, pivot=sh)
    ml = k.MB(f"Hoardsworth_{s}LowerArm")
    limb(ml, el, wr, 0.22, 0.2, "ribbon", part="Fore")
    d = (Vector(wr) - Vector(el)).normalized()
    cuff = Vector(wr) - d * 0.18
    ml.cylinder(tuple(cuff), tuple(d), 0.25, -0.1, 0.08, 10, "marble_lo", part="Cuff")
    ml.cylinder(tuple(Vector(wr) - d * 0.04), tuple(d), 0.2, -0.02, 0.1, 10, "snow", part="Ruffle")
    la = k.finalize(ml, pivot=el)
    mh = k.MB(f"Hoardsworth_{s}Hand")
    hc = Vector(wr) + Vector((0, -0.02, -0.24))
    hand = mh.sphere(tuple(hc), 0.21, 8, 6, "snow", part="Glove")
    for v in hand:
        v.co.z = hc.z + (v.co.z - hc.z) * 1.25
        v.co.x = hc.x + (v.co.x - hc.x) * 0.8
    mh.sphere((hc.x - side * 0.16, hc.y - 0.12, hc.z + 0.06), 0.09, 6, 4, "snow", part="Thumb")
    hd = k.finalize(mh, pivot=wr)
    return ua, la, hd


def h_leg(k, side):
    s = "Right" if side < 0 else "Left"
    hp, kn, an = J[f"{s}Hip"], J[f"{s}Knee"], J[f"{s}Ankle"]
    mu = k.MB(f"Hoardsworth_{s}UpperLeg")
    limb(mu, hp, kn, 0.22, 0.18, "ink_hi", part="Thigh")
    ul = k.finalize(mu, pivot=hp)
    ml = k.MB(f"Hoardsworth_{s}LowerLeg")
    limb(ml, kn, an, 0.18, 0.15, "ink_hi", part="Shin")
    ll = k.finalize(ml, pivot=kn)
    mf = k.MB(f"Hoardsworth_{s}Foot")
    x = an[0]
    shoe = mf.box((x - 0.2, -0.3, 0.0), (x + 0.2, 0.3, 0.34), "ink", chamfer=0.1, cham_col="ink_hi", flat=("-z",),
                  part="Shoe")
    # the long pointed toe
    mf.prism([(-0.3, 0.0), (-0.95, 0.0), (-0.9, 0.12), (-0.3, 0.3)], "X", x - 0.15, x + 0.15, "ink", "ink_hi",
             part="Toe")
    mf.lathe([(0.12, 0.3), (0.21, 0.3), (0.21, 0.62), (0.12, 0.62)], 10, ["marble_lo"] * 4, (x, 0.0, 0.0),
             closed=True, part="Spat")
    mf.box((x - 0.08, -0.36, 0.14), (x + 0.08, -0.28, 0.26), "marble_lo", part="ShoeBuckle")
    del shoe
    ft = k.finalize(mf, pivot=an)
    return ul, ll, ft


def hoardsworth(k):
    ut, lt, hd, hat, mono = h_upper_torso(k), h_lower_torso(k), h_head(k), h_hat(k), h_monocle(k)
    rua, rla, rh = h_arm(k, -1)
    lua, lla, lh = h_arm(k, 1)
    rul, rll, rf = h_leg(k, -1)
    lul, lll, lf_ = h_leg(k, 1)

    def part(ob, joint, parent, **kw):
        return k.Obj(ob, kw.pop("cls", "small"), role="villain", pivot="point", collision="Box", can_collide=False,
                     joint={"name": joint, "parent": parent}, tags=["EH_Intro"], sim="none", **kw)

    objs = [
        part(lt, "Root", None, notes="the root: place the Model by this part's pivot (hip centre, 3.55 above the floor)"),
        part(ut, "Waist", "Hoardsworth_LowerTorso"), part(hd, "Neck", "Hoardsworth_UpperTorso"),
        part(hat, "HatAttach", "Hoardsworth_Head", symmetric="X"),
        part(mono, "Monocle", "Hoardsworth_Head", cls="tiny", notes="pivot = the lens centre: the code glint sits here"),
        part(rua, "RightShoulder", "Hoardsworth_UpperTorso"), part(rla, "RightElbow", "Hoardsworth_RightUpperArm"),
        part(rh, "RightWrist", "Hoardsworth_RightLowerArm"),
        part(lua, "LeftShoulder", "Hoardsworth_UpperTorso"), part(lla, "LeftElbow", "Hoardsworth_LeftUpperArm"),
        part(lh, "LeftWrist", "Hoardsworth_LeftLowerArm"),
        part(rul, "RightHip", "Hoardsworth_LowerTorso"), part(rll, "RightKnee", "Hoardsworth_RightUpperLeg"),
        part(rf, "RightAnkle", "Hoardsworth_RightLowerLeg"),
        part(lul, "LeftHip", "Hoardsworth_LowerTorso"), part(lll, "LeftKnee", "Hoardsworth_LeftUpperLeg"),
        part(lf_, "LeftAnkle", "Hoardsworth_LeftLowerLeg"),
    ]
    seats = [("Hoardsworth_UpperTorso", "Hoardsworth_LowerTorso"), ("Hoardsworth_Head", "Hoardsworth_UpperTorso"),
             ("Hoardsworth_Hat", "Hoardsworth_Head"), ("Hoardsworth_Monocle", "Hoardsworth_Head"),
             ("Hoardsworth_RightUpperArm", "Hoardsworth_UpperTorso"),
             ("Hoardsworth_RightLowerArm", "Hoardsworth_RightUpperArm"),
             ("Hoardsworth_RightHand", "Hoardsworth_RightLowerArm"),
             ("Hoardsworth_LeftUpperArm", "Hoardsworth_UpperTorso"),
             ("Hoardsworth_LeftLowerArm", "Hoardsworth_LeftUpperArm"),
             ("Hoardsworth_LeftHand", "Hoardsworth_LeftLowerArm"),
             ("Hoardsworth_RightUpperLeg", "Hoardsworth_LowerTorso"),
             ("Hoardsworth_RightLowerLeg", "Hoardsworth_RightUpperLeg"),
             ("Hoardsworth_RightFoot", "Hoardsworth_RightLowerLeg"),
             ("Hoardsworth_LeftUpperLeg", "Hoardsworth_LowerTorso"),
             ("Hoardsworth_LeftLowerLeg", "Hoardsworth_LeftUpperLeg"),
             ("Hoardsworth_LeftFoot", "Hoardsworth_LeftLowerLeg")]
    return k.Asset("Hoardsworth", objs, budget_cls="creature", seats=seats,
                   notes="Sir Hoardsworth: rigid R15-style rig (17 parts), joint pivots for the code pose player; "
                         "top hat, monocle (glint at its pivot), velvet tails.")


# ------------------------------------------------------------------ his lever (the switch on the roof)
def lever(k):
    mb = k.MB("Intro_Lever")
    mb.box((-0.9, -0.6, 0.0), (0.9, 0.6, 2.6), "ribbon", chamfer=0.12, cham_col="ribbon_hi", flat=("-z",), part="Body")
    mb.box((-1.0, -0.7, 0.0), (1.0, 0.7, 0.3), "ink", chamfer=0.06, cham_col="ink_hi", flat=("-z",), part="Plinth")
    top = mb.box((-0.95, -0.65, 2.55), (0.95, 0.65, 2.85), "marble_lo", chamfer=0.06, cham_col="marble", part="Top")
    del top
    mb.box((-0.5, -0.66, 1.2), (0.5, -0.56, 2.1), "marble", chamfer=0.03, cham_col="marble_lo", part="Plaque")
    mb.cylinder((0.0, 0.0, 2.85), (1, 0, 0), 0.22, -0.4, 0.4, 10, "steel_lo", part="Hinge")
    base = k.finalize(mb, pivot=(0, 0, 0))
    mh = k.MB("Intro_Lever_Handle")
    hinge = Vector((0.0, 0.0, 2.85))
    L.tube(mh, [tuple(hinge), tuple(hinge + Vector((0, -0.35, 1.0))), tuple(hinge + Vector((0, -0.6, 2.0)))],
           [0.09, 0.08, 0.08], 8, "steel_hi", part="Rod", normal=(1, 0, 0))
    mh.sphere(tuple(hinge + Vector((0, -0.65, 2.15))), 0.28, 10, 6, "ribbon", part="Knob")
    mh.cylinder(tuple(hinge), (1, 0, 0), 0.16, -0.3, 0.3, 10, "steel_hi", part="Boss")
    handle = k.finalize(mh, pivot=tuple(hinge))
    return k.Asset("Intro_Lever", [
        k.Obj(base, "small", role="villain", pivot="bottom", collision="Box", can_collide=False, tags=["EH_Intro"],
              sim="none", notes="Hoardsworth's switch: burgundy pillar, gold top, steel hinge"),
        k.Obj(handle, "small", role="villain", pivot="point", collision="Box", can_collide=False, tags=["EH_Intro"],
              joint={"name": "LeverHinge", "parent": "Intro_Lever"}, sim="none",
              notes="pivot = the hinge (axis X): the cinematic rotates it 0 (up, back) -> 70 deg (pulled)"),
    ], seats=[("Intro_Lever_Handle", "Intro_Lever")],
        notes="The vacuum's switch: a brass-topped burgundy pillar with a ball-knob lever.")


# ------------------------------------------------------------------ the giant vacuum (on the tower's gantry)
# Asset space: origin = the motor's bottom centre on the gantry; front -Y faces the town (the cinematic turns it
# 180 deg: Shared/Heist/IntroPlan.STAGE.vacuum). The machine is authored at unit size and scaled by VAC_S (it has to
# read as GIANT next to Hoardsworth); the outlet pipe is routed after the scaling to INLET, the Snow Globe's cap.
# NOZZLE: where the intake mouth sits (IntroPlan.STAGE.nozzle = vacuum.at + the turned NOZZLE).
VAC_S = 1.4
NOZZLE0 = Vector((23.0, -24.0, 16.0))
NOZZLE = NOZZLE0 * VAC_S
AIM = Vector((-0.15, -0.74, -0.65)).normalized()   # the mouth looks down at the town
INLET = Vector((-23.0, 17.0, 36.0))                 # the Snow Globe's top (its cap) in vacuum space


def vacuum(k):
    mb = k.MB("Intro_Vacuum")
    # the motor: a big burgundy canister drum lying along X on four steel wheels, gold end caps, steel bands, a
    # control box with two gauges on its front, an exhaust stack behind
    DZ, DR = 7.6, 7.0
    mb.lathe([(0, -9.4), (5.6, -9.4), (6.6, -8.8), (DR, -7.9), (DR, 7.9), (6.6, 8.8), (5.6, 9.4), (0, 9.4)], 28,
             ["marble_lo", "marble", "ribbon_hi", "ribbon", "ribbon_hi", "marble", "marble_lo"], (0, 0, DZ), (1, 0, 0),
             part="Drum")
    for x in (-4.6, 4.6):
        mb.lathe([(DR - 0.2, x - 0.5), (DR + 0.22, x - 0.4), (DR + 0.22, x + 0.4), (DR - 0.2, x + 0.5)], 28,
                 ["steel", "steel_hi", "steel", "steel"], (0, 0, DZ), (1, 0, 0), closed=True, part="Band")
    for x in (-6.6, 6.6):
        for y in (-5.0, 5.0):
            mb.cylinder((x, y, 2.4), (1, 0, 0), 2.4, -0.8, 0.8, 16, "steel_lo", cap_col="ink_hi", chamfer=0.2,
                        cham_col="steel", part="Wheel")
    mb.box((-4.4, -7.7, 4.4), (4.4, -4.2, 11.2), "ribbon_hi", chamfer=0.35, cham_col="marble_lo", part="Panel")
    for i, x in enumerate((-2.1, 2.1)):
        mb.cylinder((x, -7.7, 8.2), (0, -1, 0), 1.6, -0.05, 0.45, 20, "marble_lo", chamfer=0.12, cham_col="marble",
                    part=f"GaugeRim{i}")
        mb.cylinder((x, -7.7, 8.2), (0, -1, 0), 1.3, 0.3, 0.55, 20, "marble_hi", part=f"GaugeFace{i}")
        needle = mb.box((-0.08, -0.06, 0.0), (0.08, 0.06, 1.1), "ink", part=f"Needle{i}")
        mb.xform(needle, Matrix.Translation(Vector((x, -8.32, 8.2))) @ Matrix.Rotation(math.radians(-55 + 110 * i), 4, "Y"))
    mb.box((-1.4, -7.9, 5.0), (1.4, -7.5, 6.0), "marble_lo", chamfer=0.06, cham_col="marble", part="Crest")
    mb.cylinder((5.4, 3.6, DZ + 5.0), (0, 0, 1), 1.2, 0.0, 6.0, 12, "steel_lo", part="Stack")
    mb.cylinder((5.4, 3.6, DZ + 5.0), (0, 0, 1), 1.5, 5.7, 6.4, 12, "steel", chamfer=0.1, cham_col="steel_hi",
                part="StackCap")
    # the hose: ribbed, from the motor top, arching up and over to the intake
    hose = [(1.5, -2.5, 13.8), (3.0, -6.0, 18.5), (8.0, -11.5, 22.5), (14.0, -16.5, 23.0), (18.5, -20.5, 20.5),
            (NOZZLE0.x - AIM.x * 5.4, NOZZLE0.y - AIM.y * 5.4, NOZZLE0.z - AIM.z * 5.4)]
    pts = []
    for a, b in zip(hose, hose[1:]):
        for s in (0.0, 0.25, 0.5, 0.75):
            pts.append(tuple(Vector(a).lerp(Vector(b), s)))
    pts.append(hose[-1])
    L.tube(mb, pts, 2.1, 16, "steel", cols=["steel" if i % 2 else "steel_lo" for i in range(len(pts))],
           cap_col="steel_lo", part="Hose")
    mb.cylinder((1.5, -2.5, 13.0), (0, 0, 1), 2.7, 0.0, 1.6, 16, "steel", chamfer=0.15, cham_col="steel_hi",
                part="HoseCollar")
    # the intake: a huge flared mouth, a closed shell (outer flare, rim, dark throat back to the neck)
    back = NOZZLE0 - AIM * 5.6
    mb.lathe([(2.2, 0.0), (2.5, 1.6), (3.2, 3.2), (5.0, 4.6), (6.6, 5.4), (6.9, 5.75), (6.4, 5.9), (4.8, 5.0),
              (3.0, 3.9), (1.6, 2.4), (1.2, 0.4)], 24,
             ["steel", "steel", "steel", "steel_hi", "marble_lo", "marble", "ink_hi", "ink", "ink", "ink", "steel_lo"],
             tuple(back), tuple(AIM), closed=True, part="Mouth")
    mb.cylinder(tuple(back), tuple(AIM), 2.6, -0.6, 0.6, 16, "marble_lo", chamfer=0.12, cham_col="marble",
                part="MouthCollar")
    mb.cylinder((-1.5, 3.0, 13.0), (0, 0, 1), 2.1, 0.0, 1.6, 12, "steel", chamfer=0.12, cham_col="steel_hi",
                part="OutletCollar")
    mb.xform(list(mb.bm.verts), Matrix.Scale(VAC_S, 4))
    # the outlet into the Snow Globe (routed at full size): up from the motor's back, over, and down into the cap
    s = VAC_S
    out = [(-1.5 * s, 3.0 * s, 13.8 * s), (-1.8 * s, 3.6 * s, 24.0), (-6.0, 7.0, 36.0), (-12.0, 11.0, 41.0),
           (-18.5, 14.6, 41.4), (INLET.x, INLET.y, INLET.z + 2.6), (INLET.x, INLET.y, INLET.z - 0.4)]
    L.tube(mb, out, 1.5 * s, 12, "marble_lo", cols=["steel_lo", "marble_lo", "steel_lo", "marble_lo", "steel_lo",
                                                    "marble_lo", "steel_lo"], cap_col="steel_lo", part="Outlet")
    body = k.finalize(mb, pivot=(0, 0, 0))

    ml = k.MB("Intro_Vacuum_Lights")
    rim = NOZZLE0 - AIM * 0.0
    ml.lathe([(6.25, 0.0), (6.55, 0.0), (6.55, 0.3), (6.25, 0.3)], 32, ["white"] * 4, tuple(rim - AIM * 0.05),
             tuple(AIM), closed=True, part="RimLight")
    for x in (-6.0, 6.0):
        ml.sphere((x, -1.5, 14.45), 0.6, 10, 6, "white", part="Lamp")
    for x in (-3.4, 3.4):
        ml.sphere((x, -7.75, 10.4), 0.4, 8, 5, "white", part="PanelLamp")
    ml.xform(list(ml.bm.verts), Matrix.Scale(VAC_S, 4))
    lights = k.finalize(ml, pivot=(0, 0, 0))
    return k.Asset("Intro_Vacuum", [
        k.Obj(body, "hero", role="villain", pivot="point", collision="Box", can_collide=False, cast_shadow=True,
              tags=["EH_Intro"], sim="none",
              notes="the giant vacuum: motor, ribbed hose, flared intake (mouth at NOZZLE, aiming down at the town), "
                    "outlet pipe into the Snow Globe's cap"),
        k.Obj(lights, "small", role="villain", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, free_shells=True, tags=["EH_Intro"], sim="none",
              tint="Vault Steel shade #4E5675 off; Bulb Warm #F6C0A2 while it runs (eh_palette.NEON)",
              notes="the intake's rim ring and three lamps on the motor"),
    ], seats=[("Intro_Vacuum_Lights", "Intro_Vacuum")],
        notes="Hoardsworth's giant vacuum on the tower roof: motor, hose and intake; the outlet fills the Snow Globe.")


# ------------------------------------------------------------------ Hoardsworth Tower (the landmark)
# Asset space: origin = the tower's foot centre on the ground; front -Y faces the town (the cinematic turns it 180
# deg: Shared/Heist/IntroPlan.STAGE.tower). The roof terrace's top is at DECK_Z (IntroPlan.STAGE.deckY): Hoardsworth,
# the lever and the Snow Globe stand on it; the vacuum stands on the steel gantry off its +X side (Blender +X =
# Roblox -X before the turn, the stage's +X after it).
DECK_Z = 130.0
DECK_HALF = 24.0
GANTRY = (24.0, 41.0, -25.0, 1.0)     # x0, x1, y0, y1 of the vacuum's gantry (top at DECK_Z)
# (z0, z1, half width) of the stacked shafts: a podium, two setbacks, the crown block under the terrace
TIERS = [(0.0, 14.0, 26.0), (14.0, 64.0, 19.0), (64.0, 100.0, 15.0), (100.0, 118.0, 11.0)]
SIGN = (84.0, 20.0, 16.0)             # the giant H on the front of shaft 2: centre z, width, height


def tower(k):
    """Hoardsworth Tower: an art-deco toy-tycoon skyscraper. A burgundy podium with a gold-framed portal, two
    setbacks with gold cornices, corner piers that rise past every setback into stepped gold caps, pilasters between
    columns of lit windows, a giant gold-framed "H" sign on the second shaft, a flared crown of gold corbels and
    sunburst fins under the roof terrace, a low balustrade, and a steel gantry for the vacuum. The Snow Globe Vault
    (Intro_SnowGlobe) stands on the terrace. Windows and the H are separate Neon objects (code colours them)."""
    mb = k.MB("Intro_Tower")

    def bx(lo, hi, col, ch=0.0, chc=None, part="Box", flat=()):
        return mb.box(lo, hi, col, chamfer=ch, cham_col=chc or col, part=part, flat=flat)

    # the ground plinth and the stepped base
    bx((-27.5, -27.5, -0.5), (27.5, 27.5, 1.6), "ink_hi", 0.3, "ink", part="Plinth")
    for i, (z0, z1, h) in enumerate(TIERS):
        body = "ribbon" if i else "ribbon_hi"
        bx((-h, -h, z0 - 0.2), (h, h, z1 + 0.2), body, 0.4, "ribbon_hi", part=f"Shaft{i}")
        # the gold cornice on top of each tier (a step out, a fillet in)
        bx((-h - 1.2, -h - 1.2, z1 - 0.4), (h + 1.2, h + 1.2, z1 + 1.4), "marble_lo", 0.3, "marble", part=f"Cornice{i}")
        bx((-h - 0.5, -h - 0.5, z1 - 1.6), (h + 0.5, h + 0.5, z1 - 0.3), "ribbon_hi", 0.15, "marble_lo",
           part=f"Fillet{i}")
        if i == 0:
            continue
        # corner piers: rise 5 studs past the tier, each topped with a stepped gold cap (a little ziggurat)
        for sx in (-1, 1):
            for sy in (-1, 1):
                cx, cy = sx * (h - 0.4), sy * (h - 0.4)
                bx((cx - 2.2, cy - 2.2, z0 + 0.6), (cx + 2.2, cy + 2.2, z1 + 4.0), "ribbon_hi", 0.3, "ribbon",
                   part="Pier")
                for j, (r, dz) in enumerate(((2.6, 0.9), (1.8, 0.9), (1.0, 1.2))):
                    zz = z1 + 4.0 + sum(d for _r, d in ((2.6, 0.9), (1.8, 0.9), (1.0, 1.2))[:j])
                    bx((cx - r, cy - r, zz - 0.1), (cx + r, cy + r, zz + dz), "marble_lo" if j != 1 else "marble",
                       0.15, "marble", part="PierCap")
                # a gold strip up the pier's outer corner
                bx((cx + sx * 1.6 - 0.35, cy + sy * 1.6 - 0.35, z0 + 2.0), (cx + sx * 1.6 + 0.35, cy + sy * 1.6 + 0.35,
                                                                            z1 + 3.0), "marble_lo", part="PierStrip")
        # pilasters between the window columns on every face (the sign face keeps only its outer ones)
        cols = WIN_COLS[i]
        for face in range(4):
            for c in range(len(cols) + 1):
                if c == 0 or c == len(cols):
                    continue
                x = (cols[c - 1] + cols[c]) / 2
                if i == 2 and face == 0 and abs(x) < SIGN[1] / 2 + 1:
                    continue
                lo, hi = (x - 0.45, -h - 0.5, z0 + 1.0), (x + 0.45, -h + 0.3, z1 - 1.8)
                v = bx(lo, hi, "ribbon_hi", 0.12, "marble_lo", part="Pilaster")
                mb.rotate(v, 90 * face, "Z")
    # the portal: a stepped gold frame, dark doors with a gold H transom, two lamps
    bx((-8.0, -26.6, 1.0), (8.0, -25.6, 12.6), "marble_lo", 0.3, "marble", part="PortalFrame")
    bx((-6.6, -26.9, 1.0), (6.6, -26.2, 11.2), "marble", 0.15, "marble_hi", part="PortalStep")
    bx((-5.0, -27.2, 1.5), (5.0, -26.6, 9.6), "ink", 0.1, "ink_hi", part="Doors")
    bx((-0.12, -27.35, 1.5), (0.12, -27.0, 8.2), "marble_lo", part="DoorSplit")
    bx((-5.0, -27.3, 8.2), (5.0, -26.8, 9.6), "marble_lo", part="Transom")
    bx((-3.6, -28.2, 0.0), (3.6, -26.4, 0.9), "marble_lo", 0.1, "marble", part="DoorStep")
    # the giant H sign on the front of shaft 2: a gold frame round a dark board, rays fanning out above it
    zc, sw, sh = SIGN
    h2 = TIERS[2][2]
    bx((-sw / 2 - 1.0, -h2 - 1.6, zc - sh / 2 - 1.0), (sw / 2 + 1.0, -h2 + 0.3, zc + sh / 2 + 1.0), "marble_lo", 0.4,
       "marble", part="SignFrame")
    bx((-sw / 2, -h2 - 2.0, zc - sh / 2), (sw / 2, -h2 - 1.2, zc + sh / 2), "ink", 0.15, "ink_hi", part="SignBoard")
    for j in range(7):   # the sunburst over the sign: gold rays
        a = math.radians(-60 + 20 * j)
        base = Vector((0.0, -h2 - 0.2, zc + sh / 2 + 1.0))
        tip = base + Vector((math.sin(a) * 8.0, 0.0, math.cos(a) * 7.0))
        side = Vector((math.cos(a), 0.0, -math.sin(a))) * 0.7
        vs = mb.prism([(base.x - side.x, base.z - side.z), (base.x + side.x, base.z + side.z), (tip.x, tip.z)], "Y",
                      -h2 - 0.6, -h2 + 0.2, "marble_lo", "marble", part=f"Ray{j}")
        del vs
    # the crown: three gold-banded corbel steps flaring out to the terrace, sunburst fins on each face
    z = TIERS[-1][1]
    for j, (h, dz) in enumerate(((13.5, 3.0), (17.5, 3.0), (21.5, 3.0))):
        bx((-h, -h, z - 0.2), (h, h, z + dz), "ribbon" if j % 2 == 0 else "ribbon_hi", 0.3, "ribbon_hi",
           part=f"Corbel{j}")
        bx((-h - 0.4, -h - 0.4, z + dz - 0.9), (h + 0.4, h + 0.4, z + dz + 0.1), "marble_lo", 0.15, "marble",
           part=f"CorbelBand{j}")
        z += dz
    for face in range(4):
        for j in range(5):
            x = -9.0 + 4.5 * j
            fin = [(x - 1.0, TIERS[-1][1] - 6.0), (x + 1.0, TIERS[-1][1] - 6.0), (x * 2.2 + 1.2, z - 0.4),
                   (x * 2.2 - 1.2, z - 0.4)]
            vs = mb.prism(fin, "Y", -TIERS[-1][2] - 0.8 - (j % 2) * 0.0, -TIERS[-1][2] + 0.4, "marble_lo", "marble",
                          part=f"Fin{face}_{j}")
            # lean the fin's top out with the corbels
            for v in vs:
                if v.co.z > TIERS[-1][1] - 0.5:
                    v.co.y -= (v.co.z - TIERS[-1][1]) * 0.9
            mb.rotate(vs, 90 * face, "Z")
    # the roof terrace: a slab with a gold edge, a dark deck with a gold inlay border
    bx((-DECK_HALF, -DECK_HALF, DECK_Z - 2.8), (DECK_HALF, DECK_HALF, DECK_Z - 0.6), "ribbon_hi", 0.3, "marble_lo",
       part="Terrace")
    bx((-DECK_HALF - 0.5, -DECK_HALF - 0.5, DECK_Z - 1.6), (DECK_HALF + 0.5, DECK_HALF + 0.5, DECK_Z - 0.5),
       "marble_lo", 0.2, "marble", part="TerraceBand")
    bx((-DECK_HALF + 0.6, -DECK_HALF + 0.6, DECK_Z - 0.9), (DECK_HALF - 0.6, DECK_HALF - 0.6, DECK_Z), "ink_hi",
       0.1, "ink", part="Deck")
    for sx in (-1, 1):   # the gold inlay: a border band just proud of the deck
        bx((sx * (DECK_HALF - 2.4) - 0.4, -DECK_HALF + 2.0, DECK_Z - 0.2), (sx * (DECK_HALF - 2.4) + 0.4,
                                                                         DECK_HALF - 2.0, DECK_Z + 0.06),
           "marble_lo", part="Inlay")
        bx((-DECK_HALF + 2.0, sx * (DECK_HALF - 2.4) - 0.4, DECK_Z - 0.2), (DECK_HALF - 2.0,
                                                                         sx * (DECK_HALF - 2.4) + 0.4, DECK_Z + 0.06),
           "marble_lo", part="Inlay")
    # a low balustrade on the back and the -X side (the front and the gantry side stay open for the shots)
    for side in ("back", "left"):
        for j in range(9):
            t = -DECK_HALF + 3.0 + j * (2 * DECK_HALF - 6.0) / 8
            x, y = (t, DECK_HALF - 1.0) if side == "back" else (-DECK_HALF + 1.0, t)
            bx((x - 0.35, y - 0.35, DECK_Z - 0.2), (x + 0.35, y + 0.35, DECK_Z + 1.6), "marble", 0.1, "marble_hi",
               part="Baluster")
        if side == "back":
            bx((-DECK_HALF + 1.6, DECK_HALF - 1.6, DECK_Z + 1.5), (DECK_HALF - 1.6, DECK_HALF - 0.4, DECK_Z + 2.1),
               "marble_lo", 0.15, "marble", part="Rail")
        else:
            bx((-DECK_HALF + 0.4, -DECK_HALF + 1.6, DECK_Z + 1.5), (-DECK_HALF + 1.6, DECK_HALF - 1.6, DECK_Z + 2.1),
               "marble_lo", 0.15, "marble", part="Rail")
    # the vacuum's gantry: steel grating on two girders, two braces down to the crown
    x0, x1, y0, y1 = GANTRY
    bx((x0 - 1.0, y0, DECK_Z - 1.2), (x1, y1, DECK_Z), "steel_lo", 0.12, "steel", part="Grating")
    for y in (y0 + 1.0, y1 - 1.0):
        bx((x0 - 1.0, y - 0.6, DECK_Z - 3.2), (x1, y + 0.6, DECK_Z - 1.1), "steel", 0.12, "steel_hi", part="Girder")
        L.tube(mb, [(x1 - 1.0, y, DECK_Z - 2.6), (TIERS[-1][2] + 0.6, y * 0.5, TIERS[-1][1] - 12.0)], 0.6, 6,
               "steel", part="Brace")
    for j in range(5):   # rivets of bolts on the girder fronts
        x = x0 + 1.0 + j * (x1 - x0 - 2.0) / 4
        bx((x - 0.25, y0 - 0.15, DECK_Z - 2.4), (x + 0.25, y0 + 0.5, DECK_Z - 1.9), "steel_hi", part="Bolt")
    body = k.finalize(mb, pivot=(0, 0, 0))

    # lit windows (Neon): tall deco slots in columns on every face, rows per tier; the sign face of shaft 2 keeps
    # its two outer columns
    mw = k.MB("Intro_Tower_Windows")
    for i, (z0, z1, h) in enumerate(TIERS):
        if i == 0:
            continue
        rows = WIN_ROWS[i]
        for face in range(4):
            for x in WIN_COLS[i]:
                if i == 2 and face == 0 and abs(x) < SIGN[1] / 2 + 1:
                    continue
                for zr in rows:
                    v = mw.box((x - 0.95, -h - 0.25, zr), (x + 0.95, -h + 0.3, zr + 4.4), "white", part="Win")
                    mw.rotate(v, 90 * face, "Z")
    for x in (-3.0, 3.0):   # the podium's two tall lobby windows beside the portal
        mw.box((x * 3.0 - 1.4, -26.25, 3.0), (x * 3.0 + 1.4, -25.7, 11.0), "white", part="Lobby")
    windows = k.finalize(mw, pivot=(0, 0, 0))

    # the giant H (Neon): two uprights and the bar, on the sign board
    ms = k.MB("Intro_Tower_Sign")
    lo_y, hi_y = -h2 - 2.45, -h2 - 1.8
    for sx in (-1, 1):
        ms.box((sx * 5.0 - 1.6, lo_y, zc - 6.0), (sx * 5.0 + 1.6, hi_y, zc + 6.0), "white", part="Upright")
    ms.box((-3.6, lo_y, zc - 1.3), (3.6, hi_y, zc + 1.3), "white", part="Bar")
    sign = k.finalize(ms, pivot=(0, 0, 0))
    return k.Asset("Intro_Tower", [
        k.Obj(body, "hero", role="villain", pivot="point", collision="Box", can_collide=False, tags=["EH_Intro"],
              sim="none",
              notes="Hoardsworth Tower: art-deco setbacks, corner piers with gold caps, pilasters, the crown's corbels "
                    "and sunburst fins, the roof terrace (top at the origin + 130) and the vacuum's steel gantry"),
        k.Obj(windows, "medium", role="villain", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, free_shells=True, tags=["EH_Intro"], sim="none",
              tint="Bulb Warm #F6C0A2; Vault Steel shade #4E5675 once the presents are gone (eh_palette.NEON)",
              notes="lit windows (Neon), out on '...GONE.' with the town's"),
        k.Obj(sign, "small", role="villain", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, free_shells=True, tags=["EH_Intro"], sim="none",
              tint="Sign Gold #FFB85C (eh_palette.NEON); it stays lit all night",
              notes="the giant H on the sign board (Neon)"),
    ], seats=[("Intro_Tower_Windows", "Intro_Tower"), ("Intro_Tower_Sign", "Intro_Tower")],
        notes="Hoardsworth Tower: art-deco toy-tycoon landmark, setbacks, gold crown, lit windows, the giant H.")


# window columns (x across a face) and row bottoms (z) per tier (tier 0, the podium, has the lobby windows)
WIN_COLS = {1: [-13.5, -9.0, -4.5, 0.0, 4.5, 9.0, 13.5], 2: [-11.0, -5.5, 0.0, 5.5, 11.0],
            3: [-6.0, -2.0, 2.0, 6.0]}
WIN_ROWS = {1: [17.5, 24.5, 31.5, 38.5, 45.5, 52.5], 2: [68.5, 75.5, 82.5, 89.5], 3: [104.5, 110.5]}


# ------------------------------------------------------------------ the Snow Globe Vault (hero)
R_GLOBE = 16.0
GLOBE_Z = 20.0


def snow_globe(k):
    mb = k.MB("Intro_SnowGlobe")
    # a stepped round plinth: burgundy drum with gold rims, a gold cradle ring the glass sits in
    mb.lathe([(0, 0.0), (12.5, 0.0), (12.5, 1.0), (11.8, 1.4), (11.8, 4.2), (12.2, 4.6), (12.2, 5.2), (10.0, 6.4),
              (6.0, 6.6), (0, 6.6)], 48,
             ["ink", "ink_hi", "marble_lo", "ribbon", "marble_lo", "marble", "marble_lo", "ribbon_hi", "ink"],
             (0, 0, 0), part="Plinth")
    # eight gold fins climbing the glass (the cradle claws)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        fin = [(9.4, 5.6), (12.6, 5.6), (13.4, 9.5), (11.9, 12.5), (11.2, 11.4), (11.6, 9.0)]
        vs = mb.prism(fin, "Y", -0.35, 0.35, "marble_lo", "marble", part=f"Fin{i}")
        mb.xform(vs, Matrix.Rotation(a, 4, "Z"))
    # a gold "H" crest on the front of the drum
    mb.box((-2.2, -12.0, 1.7), (2.2, -11.6, 4.0), "marble_lo", chamfer=0.08, cham_col="marble", part="Crest")
    mb.box((-1.3, -12.12, 2.0), (-0.8, -11.9, 3.7), "ribbon", part="CrestH1")
    mb.box((0.8, -12.12, 2.0), (1.3, -11.9, 3.7), "ribbon", part="CrestH2")
    mb.box((-0.8, -12.12, 2.65), (0.8, -11.9, 3.05), "ribbon", part="CrestH3")
    base = k.finalize(mb, pivot=(0, 0, 0))

    mg = k.MB("Intro_SnowGlobe_Glass")
    mg.sphere((0, 0, GLOBE_Z), R_GLOBE, 32, 16, "white", part="Glass")
    glass = k.finalize(mg, pivot=(0, 0, 0))

    mc = k.MB("Intro_SnowGlobe_Cap")
    top = GLOBE_Z + R_GLOBE
    mc.lathe([(0, top - 0.6), (3.4, top - 0.6), (3.8, top + 0.2), (3.0, top + 1.0), (2.0, top + 1.2), (2.0, top + 2.0),
              (0, top + 2.0)], 24, ["marble_lo", "marble", "marble_lo", "ribbon", "marble_lo", "ink"], (0, 0, 0),
             part="Cap")
    cap = k.finalize(mc, pivot=(0, 0, 0))

    mp = k.MB("Intro_SnowGlobe_Presents")
    pile_presents(mp)
    pile = k.finalize(mp, pivot=(0, 0, 5.4))
    return k.Asset("Intro_SnowGlobe", [
        k.Obj(base, "hero", role="villain", pivot="bottom", collision="Box", can_collide=False, tags=["EH_Intro"],
              sim="none", symmetric="X", notes="the Snow Globe Vault's plinth and gold cradle (hero, near the tower top)"),
        k.Obj(glass, "medium", role="env", pivot="point", collision="Box", material="Glass", transparency=0.55,
              can_collide=False, cast_shadow=False, tags=["EH_Intro"], sim="none", symmetric="X",
              notes="Glass, Transparency 0.55, TextureID cleared; radius 16 about (0, 20, 0) (Roblox)"),
        k.Obj(cap, "small", role="villain", pivot="point", collision="Box", can_collide=False, tags=["EH_Intro"],
              sim="none", symmetric="X", notes="the inlet cap on the globe's top (the vacuum's outlet ends here)"),
        k.Obj(pile, "hero", role="present", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
              tags=["EH_Intro"], sim="none",
              notes="the stolen presents inside: pivot = the pile's floor; the cinematic grows it (Size.Y) as it fills"),
    ], seats=[("Intro_SnowGlobe_Glass", "Intro_SnowGlobe"), ("Intro_SnowGlobe_Cap", "Intro_SnowGlobe_Glass")],
        notes="Hero Snow Globe Vault: burgundy and gold plinth, glass dome (r 16), inlet cap, a heap of stolen presents.")


PAPERS = [("holly", "gold"), ("ribbon", "snow"), ("snow", "ribbon"), ("holly_lo", "marble_hi"), ("ribbon_hi", "gold_hi"),
          ("marble_hi", "holly")]


def present(mb, c, size, paper, ribbon, yaw=0.0, tilt=0.0, part="P", bow=True):
    """A wrapped box centred at c: paper, two ribbon bands proud by 0.06, an optional two-loop bow."""
    sx, sy, sz = size
    x, y, z = c
    vs = mb.box((x - sx / 2, y - sy / 2, z - sz / 2), (x + sx / 2, y + sy / 2, z + sz / 2), paper,
                chamfer=min(sx, sy, sz) * 0.06, cham_col=paper, part=part)
    w = min(sx, sy) * 0.16
    vs += mb.box((x - w / 2, y - sy / 2 - 0.06, z - sz / 2 - 0.06), (x + w / 2, y + sy / 2 + 0.06, z + sz / 2 + 0.06),
                 ribbon, part=part + "R1")
    vs += mb.box((x - sx / 2 - 0.06, y - w / 2, z - sz / 2 - 0.05), (x + sx / 2 + 0.06, y + w / 2, z + sz / 2 + 0.05),
                 ribbon, part=part + "R2")
    if bow:
        for s in (-1, 1):
            loop = mb.sphere((x + s * w * 1.2, y, z + sz / 2 + w * 0.7), w * 1.15, 8, 5, ribbon, part=part + "Bow")
            for v in loop:
                v.co.y = y + (v.co.y - y) * 0.45
            vs += loop
    pivot = Vector(c)
    mb.xform(vs, Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
             @ Matrix.Rotation(math.radians(tilt), 4, "X") @ Matrix.Translation(-pivot))
    return vs


def pile_presents(mp):
    """A heap of presents on the globe's floor (z 5.4), inside r <= 10, rising to z ~19: overlapping, so one cluster."""
    import random
    rng = random.Random(7)
    spots = []
    for ring, (r, n, z) in enumerate(((0.0, 1, 7.6), (4.2, 6, 6.8), (7.6, 9, 6.4), (2.8, 5, 10.6), (5.6, 6, 9.8),
                                      (1.4, 3, 14.0), (3.6, 4, 13.2), (0.0, 1, 17.4))):
        for i in range(n):
            a = 2 * math.pi * (i + 0.5 * ring) / n
            spots.append((r * math.cos(a), r * math.sin(a), z))
    for i, (x, y, z) in enumerate(spots):
        s = rng.uniform(2.4, 3.6)
        size = (s * rng.uniform(0.9, 1.3), s * rng.uniform(0.9, 1.2), s * rng.uniform(0.8, 1.2))
        paper, ribbon = PAPERS[i % len(PAPERS)]
        present(mp, (x, y, z), size, paper, ribbon, yaw=rng.uniform(-35, 35), tilt=rng.uniform(-14, 14),
                part=f"P{i}", bow=i % 3 == 0)
    # the floor disc the heap sits on (snow), ties every shell together
    mp.cylinder((0, 0, 5.4), (0, 0, 1), 10.4, 0.0, 1.4, 32, "snow", part="Floor")


# ------------------------------------------------------------------ flying presents (3 variants)
def flying(k, name, size, paper, ribbon, notes):
    mb = k.MB(name)
    present(mb, (0, 0, size[2] / 2), size, paper, ribbon, part="Box")
    ob = k.finalize(mb, pivot=(0, 0, size[2] / 2))
    return k.Asset(name, [k.Obj(ob, "small", role="present", pivot="point", collision="Box", can_collide=False,
                                cast_shadow=False, tags=["EH_Intro"], sim="none", notes=notes)],
                   notes=notes)


# ------------------------------------------------------------------ the kid's letter
def letter(k):
    mb = k.MB("Intro_Letter")
    W, Hh, T = 2.4, 1.6, 0.08
    mb.box((-W / 2, -T / 2, 0.0), (W / 2, T / 2, Hh), "marble_hi", chamfer=0.02, cham_col="marble", part="Envelope")
    # the flap (back, +Y): a V of a slightly darker paper, proud
    mb.prism([(-W / 2 + 0.04, Hh - 0.04), (W / 2 - 0.04, Hh - 0.04), (0.0, Hh * 0.38)], "Y", T / 2 - 0.01, T / 2 + 0.04,
             "marble", "marble", part="Flap")
    mb.cylinder((0.0, T / 2 + 0.02, Hh * 0.42), (0, 1, 0), 0.2, 0.0, 0.07, 12, "ribbon", part="Seal")
    # the front: a crayon star and two address lines (tells the story at the close-up)
    star = []
    for i in range(10):
        r = 0.22 if i % 2 == 0 else 0.1
        a = math.pi / 2 + i * math.pi / 5
        star.append((0.78 + r * math.cos(a), Hh * 0.72 + r * math.sin(a)))
    mb.prism(star, "Y", -T / 2 - 0.03, -T / 2 + 0.01, "holly", "holly", part="Star")
    for i, (x0, x1) in enumerate(((-0.8, 0.3), (-0.8, 0.0))):
        z = Hh * (0.42 - 0.16 * i)
        mb.box((x0, -T / 2 - 0.025, z), (x1, -T / 2 + 0.01, z + 0.07), "ink_hi", part=f"Line{i}")
    ob = k.finalize(mb, pivot=(0, 0, Hh / 2))
    return k.Asset("Intro_Letter", [k.Obj(ob, "tiny", role="story", pivot="point", collision="Box", can_collide=False,
                                          cast_shadow=False, tags=["EH_Intro"], sim="none",
                                          notes="pivot = the envelope's centre; front (-Z) shows the crayon star")],
                   notes="A kid's letter to Santa: cream envelope, burgundy seal, a crayon star and two lines.")


# ------------------------------------------------------------------ toy-town houses (2 variants)
def house(k, name, W, D, Hw, wall, wall_hi, door_x):
    mb = k.MB(name)
    mb.box((-W / 2, -D / 2, 0.0), (W / 2, D / 2, Hw), wall, chamfer=0.25, cham_col=wall_hi, flat=("-z",), part="Walls")
    mb.box((-W / 2 - 0.15, -D / 2 - 0.15, 0.0), (W / 2 + 0.15, D / 2 + 0.15, 1.0), "ink_hi", chamfer=0.1,
           cham_col="ink", flat=("-z",), part="Plinth")
    # the gable roof (along X), eaves out 0.8, with a snow layer on the upper slopes
    e = 0.8
    rh = W * 0.42
    roof = [(-D / 2 - e, Hw - 0.3), (D / 2 + e, Hw - 0.3), (D / 2 + e, Hw + 0.2), (0.0, Hw + rh), (-D / 2 - e, Hw + 0.2)]
    mb.prism([(y, z) for y, z in roof], "X", -W / 2 - e, W / 2 + e, ["ink", "ink_hi", "ink_hi", "ink_hi", "ink_hi"],
             "ink_hi", part="Roof")
    s = 0.35
    cap = [(-D * 0.3, Hw + rh * 0.55), (0.0, Hw + rh + s), (D * 0.3, Hw + rh * 0.55), (D * 0.3, Hw + rh * 0.55 - s * 0.2)]
    snow = [(-D * 0.32, Hw + rh * 0.52 + 0.12), (D * 0.32, Hw + rh * 0.52 + 0.12), (0.0, Hw + rh + 0.42)]
    del cap
    mb.prism(snow, "X", -W / 2 - e + 0.1, W / 2 + e - 0.1, "snow", "snow", part="RoofSnow")
    # chimney with a snow cap
    cx = W * 0.26
    mb.box((cx - 0.8, 0.6, Hw + 1.0), (cx + 0.8, 2.2, Hw + rh + 1.4), "ink_hi", chamfer=0.1, cham_col="ink",
           part="Chimney")
    mb.box((cx - 0.95, 0.45, Hw + rh + 1.4), (cx + 0.95, 2.35, Hw + rh + 1.75), "snow", chamfer=0.1, cham_col="snow",
           part="ChimneySnow")
    # door with a marble frame and a holly wreath, step
    fy = -D / 2
    mb.box((door_x - 1.3, fy - 0.12, 1.0), (door_x + 1.3, fy + 0.2, 5.6), "marble", chamfer=0.06, cham_col="marble_hi",
           part="DoorFrame")
    mb.box((door_x - 1.0, fy - 0.22, 1.0), (door_x + 1.0, fy + 0.1, 5.2), "wood_lo", chamfer=0.05, cham_col="wood",
           part="Door")
    mb.lathe([(0.32, 0.0), (0.55, 0.0), (0.55, 0.12), (0.32, 0.12)], 12, ["holly"] * 4, (door_x, fy - 0.2, 4.2), (0, -1, 0),
             closed=True, part="Wreath")
    mb.box((door_x - 1.5, fy - 1.0, 0.0), (door_x + 1.5, fy + 0.1, 0.6), "marble_lo", chamfer=0.06, cham_col="marble",
           flat=("-z",), part="Step")
    wins = []
    for row, z in enumerate((2.0, Hw - 3.6)):
        for x in (-W * 0.32, 0.0, W * 0.32):
            if row == 0 and abs(x - door_x) < 2.4:
                continue
            wins.append((x, z))
    for i, (x, z) in enumerate(wins):   # marble frames round each pane, a proud sill, an ink cross mullion
        for lo, hi in (((x - 1.15, fy - 0.14, z - 0.25), (x - 0.9, fy + 0.1, z + 2.15)),
                       ((x + 0.9, fy - 0.14, z - 0.25), (x + 1.15, fy + 0.1, z + 2.15)),
                       ((x - 0.9, fy - 0.14, z + 1.9), (x + 0.9, fy + 0.1, z + 2.15))):
            mb.box(lo, hi, "marble", part=f"Frame{i}")
        mb.box((x - 1.35, fy - 0.45, z - 0.35), (x + 1.35, fy + 0.1, z - 0.02), "marble", chamfer=0.05,
               cham_col="marble_hi", part=f"Sill{i}")
        mb.box((x - 1.3, fy - 0.5, z - 0.02), (x + 1.3, fy - 0.2, z + 0.12), "snow", part=f"SillSnow{i}")
        mb.box((x - 0.06, fy - 0.15, z), (x + 0.06, fy + 0.1, z + 1.9), "ink_hi", part=f"MullionV{i}")
        mb.box((x - 0.9, fy - 0.15, z + 0.9), (x + 0.9, fy + 0.1, z + 1.02), "ink_hi", part=f"MullionH{i}")
    walls = k.finalize(mb, pivot=(0, 0, 0))

    mw = k.MB(name + "_Windows")
    for x, z in wins:   # front panes (warm Neon), seated 0.05 into the wall
        mw.box((x - 0.9, -D / 2 - 0.08, z), (x + 0.9, -D / 2 + 0.05, z + 1.9), "white", part="Pane")
    for z in (2.0, Hw - 3.6):   # one pane on each side wall
        for sx in (-1, 1):
            mw.box((sx * W / 2 - 0.05 if sx > 0 else -W / 2 - 0.08, -0.9, z), (sx * W / 2 + 0.08 if sx > 0 else -W / 2 + 0.05, 0.9, z + 1.9),
                   "white", part="Side")
    wo = k.finalize(mw, pivot=(0, 0, 0))
    # marble window frames on the walls object (outline boxes around each front pane): proud sills
    return walls, wo, wins


def houses(k):
    out = []
    for name, W, D, Hw, wall, wall_hi, door_x in (("Intro_House_A", 12.0, 11.0, 11.0, "marble_lo", "marble", -2.6),
                                                  ("Intro_House_B", 15.0, 11.0, 9.0, "steel_lo", "steel", 3.4)):
        walls, wo, _wins = house(k, name, W, D, Hw, wall, wall_hi, door_x)
        out.append(k.Asset(name, [
            k.Obj(walls, "medium", role="xmas", pivot="point", collision="Box", can_collide=False, tags=["EH_Intro"],
                  sim="none", notes="toy-town house: walls, gable roof with a snow layer, chimney, door + wreath"),
            k.Obj(wo, "small", role="xmas", pivot="point", collision="Box", material="Neon", can_collide=False,
                  cast_shadow=False, atlas=False, free_shells=True, tags=["EH_Intro"], sim="none",
                  tint="Bulb Warm #F6C0A2; Vault Steel shade #4E5675 once the presents are gone (eh_palette.NEON)",
                  notes="lit windows (Neon): the town's warmth, switched off on '...GONE.'"),
        ], seats=[(name + "_Windows", name)], notes=f"{name}: a cosy toy-town house for the intro's town."))
    return out


def build(k):
    return [
        hoardsworth(k), lever(k), vacuum(k), snow_globe(k), tower(k),
        flying(k, "Intro_Present_A", (2.4, 2.4, 3.2), "ribbon", "snow", "flying present A: tall, burgundy paper, snow ribbon"),
        flying(k, "Intro_Present_B", (3.6, 2.6, 1.8), "holly", "gold", "flying present B: wide, holly paper, gold ribbon"),
        flying(k, "Intro_Present_C", (2.6, 2.6, 2.6), "snow", "holly_lo", "flying present C: cube, snow paper, holly ribbon"),
        letter(k),
    ] + houses(k)
