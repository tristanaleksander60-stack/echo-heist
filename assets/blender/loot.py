"""Kit loot (launch kit, pass 2): the loot kinds the launch level data uses that had no mesh yet.

Build: python3 tools/blender/build_asset.py assets/blender/loot.py
  Present  LevelSpec kind "Present" (17 in the daily vaults): a carried gift box. Holly paper, Heist Gold ribbon and
           bow: the gold carries the loot read, the paper says Christmas (the GiantPresent family; a [decision] in
           STYLE_BIBLE 13: present loot is the one loot that may use the Holly cells, and it is layer "base").
  Candy    kind "Candy" (L5 window displays, the L6 candy bowl, the dailies): a gold-foil wrapped sweet with twisted
           wrapper ends.
  Toy      kind "Toy" (L5 shelf rows): a wind-up tin robot in Diamond Ice with a gold key.
  Teddy    kind "Teddy" (L5 back rows, the most valuable shelf loot): a sitting golden teddy bear with an ice bow.
Loot uses only loot cells (gold, ice), Ink for eyes and seams and the tint cell: loot reads by colour plus the
sparkle VFX (shape), and never melts into a location (no location cells). Origin = bottom centre; front faces -Y.
Each is small enough to carry (<= 2.6 studs) and sits on a dark display (shelf board, counter top) or the floor.
"""
import math
import _kitlib as L
from mathutils import Matrix


def _obj(k, ob, notes, role="loot", sim="loot point (LevelSpec loot x, y, z)"):
    return k.Obj(ob, "small", role=role, pivot="point", collision="Box", cast_shadow=False, tags=["EH_Loot"],
                 sim=sim, notes=notes)


# ---------------------------------------------------------------- present

def present(k):
    mb = k.MB("Present")
    S, Hb = 1.8, 1.45
    h = S / 2
    mb.box((-h, -h, 0.0), (h, h, Hb), "holly_lo", chamfer=0.08, cham_col="holly", flat=("-z",), part="Box")
    rb = 0.2
    mb.box((-h - 0.05, -rb, 0.0), (h + 0.05, rb, Hb + 0.05), "gold", chamfer=0.04, cham_col="gold_hi", flat=("-z",), part="RibbonX")
    mb.box((-rb, -h - 0.05, 0.0), (rb, h + 0.05, Hb + 0.05), "gold", chamfer=0.04, cham_col="gold_hi", flat=("-z",), part="RibbonY")
    top = Hb + 0.05
    for sgn in (-1, 1):   # two fat loops: the 64 px silhouette of "a present"
        path = [(sgn * (0.12 + 0.42 * (1 - math.cos(math.pi * i / 8))), 0.0, 0.55 * math.sin(math.pi * i / 8)) for i in range(9)]
        loop = L.tube(mb, path, [0.1 + 0.06 * math.sin(math.pi * i / 8) for i in range(9)], 6, "gold",
                      cols=["gold_hi" if i in (3, 4, 5) else "gold" for i in range(9)], cap_col="gold_lo", part="Loop",
                      normal=(0, 1, 0))
        mb.rotate(loop, sgn * 20, "Y")
        mb.move(loop, (0, 0, top + 0.04))
    mb.sphere((0, 0, top + 0.1), 0.2, 8, 5, "gold_hi", part="Knot")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Present", [_obj(k, ob, "carried Present loot (daily vaults); CanCollide off while carried", role="present")],
                   notes="Loot: gift box 1.8 x 1.8 x 1.45 (bow to 2.1): holly paper, gold ribbon and a two-loop gold bow.")


# ---------------------------------------------------------------- candy

def candy(k):
    mb = k.MB("Candy")
    r, half = 0.55, 0.7
    zc = r
    # the sweet: an ellipsoid along X, gold with two light foil bands
    prof = []
    for i in range(9):
        a = math.pi * i / 8
        prof.append((r * math.sin(a), -half * math.cos(a)))
    prof[0] = (0, prof[0][1]); prof[-1] = (0, prof[-1][1])
    cols = ["gold", "gold", "gold_hi", "gold", "gold", "gold_hi", "gold", "gold"]
    mb.lathe(prof, 12, cols, (0, 0, zc), axis=(1, 0, 0), part="Sweet")
    # twisted wrapper ends: a pinched neck then a pleated fan (8 sides, alternating radii)
    for sgn in (-1, 1):
        x0 = sgn * (half - 0.08)
        mb.lathe([(0.0, 0.0), (0.16, 0.0), (0.1, 0.22), (0.12, 0.3), (0.0, 0.3)], 8, ["gold_lo", "gold_lo", "gold_lo", "gold_lo"],
                 (x0, 0, zc), axis=(sgn, 0, 0), part="Neck")
        fan = []
        n = 10
        for j in range(n):
            a = 2 * math.pi * j / n
            rr = 0.5 if j % 2 == 0 else 0.3
            fan.append((rr * math.cos(a), rr * math.sin(a)))
        base = sgn * (half + 0.2)
        vs = mb.prism(fan, "X", 0.0, 0.42, ["gold_hi" if j % 2 == 0 else "gold" for j in range(n)], "gold_lo",
                      origin=(0, 0, zc), part="Fan")
        if sgn < 0:
            mb.xform(vs, Matrix.Scale(-1, 4, (1, 0, 0)))
        mb.move(vs, (base, 0, 0))
        # taper the fan toward the neck: scale the inner cap down
        inner = [v for v in vs if abs(v.co.x - base) < 1e-6]
        for v in inner:
            v.co.y *= 0.35
            v.co.z = zc + (v.co.z - zc) * 0.35
    # sit it on the floor: the fans reach z = zc - 0.5 >= 0.05
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Candy", [_obj(k, ob, "carried Candy loot; lies on its side; CanCollide off while carried")],
                   notes="Loot: gold-foil wrapped sweet (2.6 long), foil bands, pinched necks and pleated wrapper fans.")


# ---------------------------------------------------------------- toy (wind-up robot)

def toy(k):
    mb = k.MB("Toy")
    for sx in (-1, 1):   # legs and feet
        mb.box((sx * 0.3 - 0.17, -0.2, 0.25), (sx * 0.3 + 0.17, 0.2, 0.75), "ice_lo", part=f"Leg{sx}")
        mb.box((sx * 0.3 - 0.24, -0.32, 0.0), (sx * 0.3 + 0.24, 0.28, 0.27), "ice_lo", chamfer=0.06, cham_col="ice", flat=("-z",),
               part=f"Foot{sx}")
    mb.box((-0.6, -0.4, 0.72), (0.6, 0.4, 1.75), "ice", chamfer=0.1, cham_col="ice_hi", part="Body")
    # chest dial and a panel of three lights (gold): the "toy robot" read on the front
    mb.cylinder((0.0, -0.4, 1.38), (0, -1, 0), 0.22, -0.02, 0.07, 8, "gold", cap_col="gold_hi", part="Dial")
    for i, x in enumerate((-0.3, 0.0, 0.3)):
        mb.box((x - 0.07, -0.45, 0.93), (x + 0.07, -0.38, 1.05), "gold_hi" if i == 1 else "gold", part=f"Light{i}")
    mb.box((-0.45, -0.33, 1.72), (0.45, 0.33, 2.33), "ice_hi", chamfer=0.08, cham_col="ice_hi", part="Head")   # sits on the body

    for sx in (-1, 1):
        mb.box((sx * 0.2 - 0.08, -0.36, 2.0), (sx * 0.2 + 0.08, -0.31, 2.14), "ink", part=f"Eye{sx}")
        mb.cylinder((sx * 0.45, 0.0, 2.08), (sx, 0, 0), 0.1, -0.02, 0.1, 6, "ice_lo", part=f"Ear{sx}")
        # arms: raised a little, chunky mitts
        arm = mb.box((-0.12, -0.12, -0.55), (0.12, 0.12, 0.0), "ice_lo", part=f"Arm{sx}")
        arm += mb.box((-0.17, -0.17, -0.8), (0.17, 0.17, -0.52), "ice", chamfer=0.05, cham_col="ice_hi", part=f"Mitt{sx}")
        mb.rotate(arm, sx * 20, "Y")
        mb.move(arm, (sx * 0.68, 0.0, 1.62))
    mb.box((-0.3, -0.35, 2.2), (0.3, -0.3, 2.26), "ink", part="Mouth")
    mb.cylinder((0, 0, 2.33), (0, 0, 1), 0.04, -0.02, 0.3, 6, "ice_lo", part="Antenna")
    mb.sphere((0, 0, 2.7), 0.1, 6, 4, "gold", part="AntennaBall")
    # the wind-up key on its back (gold): two lobes on a stem
    mb.cylinder((0, 0.4, 1.3), (0, 1, 0), 0.06, -0.02, 0.32, 6, "gold_lo", part="KeyStem")
    for sx in (-1, 1):
        mb.cylinder((sx * 0.22, 0.68, 1.3), (0, 1, 0), 0.2, -0.04, 0.04, 6, "gold", cap_col="gold_hi", part=f"KeyLobe{sx}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Toy", [_obj(k, ob, "carried Toy loot (L5 shelves); CanCollide off while carried")],
                   notes="Loot: wind-up tin robot 1.6 x 1.1 x 2.8 in Diamond Ice: chest dial, gold lights, antenna, gold key.")


# ---------------------------------------------------------------- teddy

def teddy(k):
    mb = k.MB("Teddy")
    # sitting body: an egg on the floor
    prof = [(0, 0.0), (0.45, 0.02), (0.68, 0.25), (0.72, 0.6), (0.62, 0.95), (0.4, 1.2), (0, 1.28)]
    mb.lathe(prof, 8, ["gold_lo", "gold", "gold", "gold", "gold", "gold"], (0, 0, 0), part="Body")
    mb.sphere((0, -0.4, 0.62), 0.44, 6, 4, "gold_hi", part="Belly")   # the light tummy patch, 0.1 proud of the body
    mb.sphere((0, 0, 1.68), 0.55, 8, 5, "gold", part="Head")
    mb.sphere((0, -0.48, 1.58), 0.24, 8, 4, "gold_hi", part="Muzzle")
    mb.sphere((0, -0.69, 1.66), 0.08, 6, 4, "ink", part="Nose")
    for sx in (-1, 1):
        mb.sphere((sx * 0.2, -0.47, 1.84), 0.07, 6, 4, "ink", part=f"Eye{sx}")
        mb.cylinder((sx * 0.4, 0.0, 2.1), (sx * 0.4, -0.25, 0.85), 0.2, -0.08, 0.08, 8, "gold_lo", cap_col="gold_hi", part=f"Ear{sx}")
        # legs straight out in front, round foot pads
        mb.cylinder((sx * 0.35, -0.2, 0.25), (0, -1, 0), 0.24, 0.0, 0.62, 6, "gold", cap_col="gold_hi", part=f"Leg{sx}")
        mb.cylinder((sx * 0.35, -0.82, 0.25), (0, -1, 0), 0.24, -0.02, 0.06, 6, "gold_hi", cap_col="gold_lo", part=f"Pad{sx}")
        # arms resting on the belly
        arm = mb.cylinder((0, 0, 0), (0, 0, -1), 0.17, 0.0, 0.62, 6, "gold", cap_col="gold_lo", part=f"Arm{sx}")
        mb.rotate(arm, sx * -35, "Y")
        mb.rotate(arm, sx * 25, "Z")
        mb.move(arm, (sx * 0.58, -0.05, 1.12))
    # ice bow tie: two triangles and a knot
    for sx in (-1, 1):
        mb.prism([(0.0, 0.0), (sx * 0.3, 0.14), (sx * 0.3, -0.14)], "Y", -0.66, -0.58, "ice", "ice_hi", origin=(0, 0, 1.22),
                 part=f"Bow{sx}")
    mb.sphere((0, -0.63, 1.22), 0.07, 6, 4, "ice_hi", part="BowKnot")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Teddy", [_obj(k, ob, "carried Teddy loot (L5 back shelf rows); CanCollide off while carried")],
                   notes="Loot: sitting golden teddy bear (1.6 x 1.6 x 2.4): light belly and muzzle, ink eyes, ice bow tie.")


def build(k):
    return [present(k), candy(k), toy(k), teddy(k)]
