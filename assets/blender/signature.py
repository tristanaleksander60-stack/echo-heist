"""Signature silhouettes per location (PLAN_STEAM_PLUS 3.1, 4.1 W5): ToySoldier (Toy Shop), Column_2x12 and
BankersLamp (Bank). The Corner Shop's striped awning is part of Storefront_24x12 (storefront.py).

Build: python3 tools/blender/build_asset.py assets/blender/signature.py
Placed by the visual-only level dressing (src/server/Heist/LevelDress.luau `props`, Heist/KitPlan role
"signature"): never colliders, never on a sim box, a plate, a loot point or a nav point (unit spec).

ToySoldier (original design): a giant painted wooden drummer, 11.3 studs tall (2.2 players), on a round toy plinth.
Read at 64 px: the tall black bearskin hat, the burgundy coat with a white cross-belt X, white gloves on a snare drum,
navy trousers with a white stripe, round porcelain face with rosy cheeks. Burgundy echoes Sir Hoardsworth (the toy
tycoon who owns the shop). Role "toy": the Christmas reds and greens are a toy's own paint, allowed here; never
loot gold (a gold soldier would read as loot) and never Alarm Red. Front -Y, origin bottom centre.

Column_2x12: a round marble column for the Bank's halls (2 x 2 footprint, 12 tall: base plinth, shaft, capital,
abacus), one per side of the vault frame and the staff door. Fixed marble cells: the same in every location.

BankersLamp: the green banker's desk lamp on the teller counters: brass base and stem, an emerald glass shade
(Leaf cells: calm, never Holly, which stays the Christmas layer's), no light of its own (the Bank's room lamps take
the green, Config.Lighting.LOCATION.Bank).
"""
import math
import _kitlib as L


# ---------------------------------------------------------------- toy soldier

def toy_soldier(k):
    mb = k.MB("ToySoldier")
    # round toy plinth (wood: the location's light pine in the Toy Shop atlas), a marble_lo band
    mb.cylinder((0, 0, 0), (0, 0, 1), 1.75, 0.0, 0.5, 32, "wood", cap_col="wood_hi", chamfer=0.08, cham_col="wood_hi",
                part="Plinth")
    mb.cylinder((0, 0, 0), (0, 0, 1), 1.6, 0.46, 0.62, 32, "marble_lo", part="PlinthBand")
    # boots and legs: navy trousers with a white stripe on the outside of each leg
    for sx in (-1, 1):
        x = sx * 0.5
        mb.box((x - 0.4, -0.75, 0.6), (x + 0.4, 0.45, 1.35), "ink", chamfer=0.1, cham_col="ink_hi", flat=("-z",), part="Boot")
        mb.box((x - 0.36, -0.36, 1.3), (x + 0.36, 0.36, 4.45), "steel_lo", chamfer=0.08, cham_col="steel", part="Leg")
        sxo = x + sx * 0.36
        mb.box((min(sxo, sxo + sx * 0.06), -0.12, 1.4), (max(sxo, sxo + sx * 0.06), 0.12, 4.35), "marble_hi", part="Stripe")
    # coat: a flared skirt and a tapered chest (burgundy), a dark belt with a marble buckle
    coat = [(0, 4.1), (1.25, 4.1), (1.1, 5.0), (1.0, 5.3), (1.12, 6.4), (1.22, 7.3), (0.75, 7.75), (0, 7.8)]
    vs = mb.lathe(coat, 16, ["ribbon", "ribbon", "ribbon", "ribbon", "ribbon", "ribbon_hi", "ribbon_hi"], (0, 0, 0),
                  part="Coat")
    for v in vs:
        v.co.y *= 0.72          # a flat chest, not a barrel
    mb.lathe([(0.0, 5.0), (1.06, 5.0), (1.06, 5.38), (0.0, 5.38)], 16, ["ink", "ink", "ink"], (0, 0, 0), part="Belt")
    for v in mb.parts["Belt"]:
        v.co.y *= 0.78
    mb.box((-0.28, -0.88, 4.98), (0.28, -0.74, 5.4), "marble_lo", chamfer=0.04, cham_col="marble_hi", part="Buckle")
    # cross-belts: a white X on the chest, the second one 0.03 proud so the two never share a plane
    for i, sgn in enumerate((-1, 1)):
        bv = mb.box((-0.17, -0.06 - 0.03 * i, -1.25), (0.17, 0.06 - 0.03 * i, 1.25), "marble_hi", part=f"CrossBelt{i}")
        mb.rotate(bv, sgn * 32, "Y")
        mb.move(bv, (0, -0.86, 6.45))
    # shoulders: marble_lo epaulettes; the collar
    for sx in (-1, 1):
        mb.box((sx * 0.95 - 0.38, -0.42, 7.38), (sx * 0.95 + 0.38, 0.42, 7.62), "marble_lo", chamfer=0.06,
               cham_col="marble_hi", part="Epaulette")
    mb.cylinder((0, 0, 7.7), (0, 0, 1), 0.52, 0.0, 0.32, 16, "marble_lo", part="Collar")
    # arms (burgundy tubes) bent forward to the drum, white cuffs, white gloves holding sticks
    for sx in (-1, 1):
        sh = (sx * 1.18, 0.0, 7.25)
        el = (sx * 1.3, -0.35, 5.95)
        wr = (sx * 0.78, -1.1, 5.25)
        L.tube(mb, [sh, el, wr], 0.33, 8, "ribbon", cap_col="ribbon", part=f"Arm{sx}")
        mb.cylinder(wr, (-sx * 0.52, -0.75, -0.7), 0.36, -0.16, 0.06, 10, "marble_hi", part=f"Cuff{sx}")
        mb.sphere((sx * 0.7, -1.2, 5.15), 0.3, 10, 6, "marble_hi", part=f"Glove{sx}")
        # drumstick from the glove down to the drum head
        L.tube(mb, [(sx * 0.66, -1.24, 5.2), (sx * 0.22, -1.6, 4.62)], 0.065, 6, "wood_hi", cap_col="marble", part=f"Stick{sx}")
    # snare drum at the waist: steel shell, white heads, dark rims, a burgundy zigzag would be noise: plain bands
    dc = (0.0, -1.45, 3.75)
    mb.cylinder(dc, (0, 0, 1), 0.78, 0.0, 0.8, 24, "marble_hi", cap_col="marble_hi", part="Drum")
    mb.cylinder(dc, (0, 0, 1), 0.82, -0.02, 0.12, 24, "ink", part="RimLow")
    mb.cylinder(dc, (0, 0, 1), 0.82, 0.68, 0.82, 24, "ink", part="RimHigh")
    mb.cylinder(dc, (0, 0, 1), 0.8, 0.3, 0.5, 24, "ribbon", part="DrumBand")
    # head: a porcelain ball, rosy cheeks, dark eyes, a little moustache, a round nose
    hc = (0.0, 0.0, 8.75)
    mb.sphere(hc, 0.82, 16, 10, "marble_hi", part="Head")
    for sx in (-1, 1):
        mb.cylinder((sx * 0.42, -0.62, 8.55), (sx * 0.35, -0.94, 0.0), 0.2, -0.05, 0.08, 12, "ribbon_hi", part=f"Cheek{sx}")
        mb.cylinder((sx * 0.27, -0.7, 8.98), (0, -1, 0), 0.09, -0.05, 0.08, 8, "ink", part=f"Eye{sx}")
        mb.box((sx * 0.02 - (0.32 if sx < 0 else 0), -0.86, 8.42), (sx * 0.02 + (0.32 if sx > 0 else 0), -0.7, 8.56), "ink",
               chamfer=0.04, cham_col="ink_hi", part=f"Moustache{sx}")
    mb.sphere((0.0, -0.84, 8.68), 0.14, 8, 5, "marble", part="Nose")
    # chin strap (dark) from ear to ear under the chin
    L.tube(mb, [(-0.78, 0.0, 8.95), (-0.5, -0.5, 8.12), (0.0, -0.66, 7.98), (0.5, -0.5, 8.12), (0.78, 0.0, 8.95)], 0.05, 6,
           "ink_hi", cap_col="ink_hi", part="ChinStrap")
    # the bearskin: a tall, slightly bulging black hat with a marble_lo plate and a burgundy plume on the left
    hat = [(0.0, 9.15), (0.86, 9.15), (0.98, 9.8), (1.02, 10.5), (0.92, 11.0), (0.55, 11.28), (0.0, 11.32)]
    mb.lathe(hat, 16, ["ink", "ink", "ink", "ink", "ink_hi", "ink_hi"], (0, 0, 0), part="Bearskin")
    plate = [(-0.3, 9.45), (0.3, 9.45), (0.38, 9.95), (0.0, 10.25), (-0.38, 9.95)]
    mb.prism(plate, "Y", -1.04, -0.9, "marble_lo", "marble_hi", part="HatPlate")
    L.tube(mb, [(0.92, -0.05, 9.6), (1.02, -0.1, 10.4), (0.92, -0.2, 11.05)], [0.11, 0.16, 0.08], 8, "ribbon_hi",
           cap_col="ribbon_hi", part="Plume")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("ToySoldier", [k.Obj(
        ob, "medium", role="toy", pivot="point", collision="Box", can_collide=False, cast_shadow=True, on_floor=True,
        notes="Toy Shop signature silhouette (L5): origin = the plinth centre on the floor (the drum overhangs the "
              "plinth toward -Y); visual only, in the front corner, facing the street")],
        notes="Giant toy drummer 11.3 tall on a 3.5 round plinth: bearskin, burgundy coat, white X belts, snare drum.")


# ---------------------------------------------------------------- bank column

def column(k):
    mb = k.MB("Column_2x12")
    # square plinth (flat bottom), a round torus-like base, the shaft with a slight taper, a capital and an abacus
    mb.box((-1.0, -1.0, 0.0), (1.0, 1.0, 0.8), "ink", chamfer=0.1, cham_col="ink_hi", flat=("-z",), part="Plinth")
    base = [(0.0, 0.78), (0.92, 0.78), (0.95, 0.98), (0.86, 1.18), (0.8, 1.3), (0.0, 1.3)]
    mb.lathe(base, 24, ["marble_lo", "marble", "marble_hi", "marble", "marble"], (0, 0, 0), part="Base")
    shaft = [(0.0, 1.28), (0.72, 1.28), (0.7, 6.0), (0.64, 10.45), (0.0, 10.45)]
    mb.lathe(shaft, 24, ["marble", "marble", "marble", "marble"], (0, 0, 0), part="Shaft")
    cap = [(0.0, 10.4), (0.66, 10.4), (0.7, 10.55), (0.92, 10.95), (0.96, 11.15), (0.0, 11.15)]
    mb.lathe(cap, 24, ["marble_lo", "marble", "marble_hi", "marble_hi", "marble_hi"], (0, 0, 0), part="Capital")
    mb.box((-1.0, -1.0, 11.12), (1.0, 1.0, 12.0), "marble", chamfer=0.1, cham_col="marble_hi", flat=("+z",), part="Abacus")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Column_2x12", [k.Obj(
        ob, "module", role="env", symmetric="X", pivot="bottom", collision="Box", can_collide=False, cast_shadow=True,
        notes="Bank signature silhouette: visual only; stands in corners and beside the vault frame / staff door")],
        notes="Round marble column 2x2x12: square plinth, torus base, tapered shaft, capital and abacus.")


# ---------------------------------------------------------------- banker's lamp

def bankers_lamp(k):
    mb = k.MB("BankersLamp")
    # brass (marble_lo) oval base, a stem, a cross arm, an emerald half-tube shade with brass end caps
    mb.cylinder((0, 0, 0), (0, 0, 1), 0.55, 0.0, 0.16, 16, "marble_lo", chamfer=0.04, cham_col="marble", part="Base")
    for v in mb.parts["Base"]:
        v.co.y *= 0.7
    mb.cylinder((0, 0.12, 0.14), (0, 0, 1), 0.07, 0.0, 1.0, 8, "marble_lo", part="Stem")
    mb.box((-0.08, -0.05, 1.05), (0.08, 0.2, 1.14), "marble_lo", part="Neck")   # 0.06 into the shade's underside
    # the shade: a solid half-cylinder (a convex D section, so its caps triangulate cleanly), dark underside
    n = 8
    shade = [(0.42 * math.cos(math.pi * i / n), 1.08 + 0.36 * math.sin(math.pi * i / n)) for i in range(n + 1)]
    cols = ["leaf_hi"] * (n // 2) + ["leaf"] * (n // 2) + ["leaf_lo"]
    mb.prism(shade, "X", -0.6, 0.6, cols, "leaf", part="Shade")
    for x0, x1 in ((-0.66, -0.6), (0.6, 0.66)):
        mb.prism([(0.43 * math.cos(math.pi * i / n), 1.07 + 0.37 * math.sin(math.pi * i / n)) for i in range(n + 1)],
                 "X", x0, x1, "marble_lo", "marble", part="ShadeCap")
    mb.cylinder((0.0, -0.3, 1.1), (0, 0, -1), 0.03, 0.0, 0.5, 6, "marble_lo", part="PullChain")
    mb.sphere((0.0, -0.3, 0.6), 0.06, 6, 4, "marble", part="Pull")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("BankersLamp", [k.Obj(
        ob, "small", role="env", pivot="bottom", collision="Box", can_collide=False, cast_shadow=False,
        notes="Bank signature prop on the teller counters: visual only, no light (the room lamps carry the green)")],
        notes="Green banker's desk lamp 1.3 x 0.9 x 1.45: brass base and stem, emerald glass half-tube shade.")


def build(k):
    return [toy_soldier(k), column(k), bankers_lamp(k)]
