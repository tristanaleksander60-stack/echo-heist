"""Hero props (launch kit): CashRegister (+ drawer), Pedestal_Diamond (+ glass case), GiantPresent.

Build: python3 tools/blender/build_asset.py assets/blender/hero_props.py
CashRegister: the Corner Shop's top loot ("Register" in L3, the Alarm Run trigger in Clone Party). A chunky retro
register in chrome steel (never brass: gold is loot only), crank handle on the right, pop-up "sale" tab on top.
The drawer is its own part: it shoots out along -Y when grabbed, showing gold bills (the loot read).
Pedestal_Diamond: the Bank's diamond display: a Vault Steel shade column (STYLE_BIBLE display rule: pedestals
steel_lo, never marble), dark cushion, glass case as its own part (lifts when the diamond is taken). The Diamond
hovers and spins 1.25 studs above the cushion (PEDESTAL_TOP + 1.25 = the Diamond's centre).
GiantPresent: the Snow Globe Vault's heavy loot (MASTERPLAN 4.3: 2 grips required, faster with 3-4). Holly
paper, Heist Gold ribbon and bow (it IS loot), 4 dark strap handles = the grip points (manifest `grips`).
Origins: bottom centre.
"""
import math
import _kitlib as L
from mathutils import Matrix, Vector


# ---------------------------------------------------------------- cash register

def register(k):
    mb = k.MB("CashRegister")
    W, Dp = 3.2, 3.0
    x0, x1, y0, y1 = -W / 2, W / 2, -Dp / 2, Dp / 2
    # base: the drawer housing (dark slot at the front where the drawer sits)
    mb.box((x0, y0, 0.0), (x1, y1, 0.95), "steel", chamfer=0.1, cham_col="steel_hi", flat=("-z",), part="Base")
    mb.box((x0 + 0.15, y0 - 0.02, 0.12), (x1 - 0.15, y0 + 0.2, 0.86), "ink", part="Slot")
    mb.box((x0 - 0.1, y0 - 0.1, 0.0), (x1 + 0.1, y1 + 0.1, 0.18), "steel_lo", chamfer=0.06, cham_col="steel", flat=("-z",), part="Foot")
    # keyboard: a slope rising to the back, with a 4 x 4 grid of marble keys
    slope = [(y0 + 0.1, 0.95), (y1 - 0.2, 0.95), (y1 - 0.2, 2.3), (y0 + 1.0, 2.3), (y0 + 0.1, 1.45)]
    mb.prism(slope, "X", x0 + 0.1, x1 - 0.1, ["steel", "steel_lo", "steel", "steel_hi", "steel_hi"], "steel", chamfer=0.08,
             cham_col="steel_hi", cham_edges=[2, 3, 4], part="Body")
    for i in range(4):
        for j in range(4):
            t = (i + 0.5) / 4
            p = Vector((-0.93 + j * 0.62, y0 + 0.1 + t * 0.9, 1.45 + t * (2.3 - 1.45) - 0.04))
            key = mb.box((-0.2, -0.17, 0.0), (0.2, 0.17, 0.2), "marble" if (i + j) % 3 else "marble_hi", chamfer=0.05,
                         cham_col="marble_hi", flat=("-z",), part=f"Key_{i}{j}")
            ang = math.atan2(2.3 - 1.45, 0.9)
            mb.xform(key, Matrix.Translation(p) @ Matrix.Rotation(ang, 4, "X"))
    # display hood with the amount window (SurfaceGui by code) and a pop-up "sale" tab
    mb.box((x0 + 0.25, y1 - 1.6, 2.3), (x1 - 0.25, y1 - 0.2, 3.25), "steel", chamfer=0.1, cham_col="steel_hi", part="Hood")
    mb.box((x0 + 0.5, y1 - 1.68, 2.5), (x1 - 0.5, y1 - 1.55, 3.05), "ink", part="Window")
    mb.box((-0.65, y1 - 1.05, 3.2), (0.65, y1 - 0.85, 3.95), "marble_hi", chamfer=0.05, cham_col="marble_hi", part="SaleTab")
    mb.box((-0.08, y1 - 1.0, 3.15), (0.08, y1 - 0.9, 3.25), "steel_lo", part="TabStem")
    # side panels with a raised medallion, and the crank on the right: the "cash register" silhouette
    for sx in (-1, 1):
        xs = sx * (W / 2 - 0.1)
        mb.box((xs - 0.08 if sx > 0 else xs - 0.04, y0 + 0.5, 1.15), (xs + 0.04 if sx > 0 else xs + 0.08, y1 - 0.5, 2.05),
               "steel_hi", chamfer=0.04, cham_col="steel_hi", part="SidePanel")
    hub = (x1 + 0.02, 0.2, 1.55)
    mb.cylinder(hub, (1, 0, 0), 0.32, 0.0, 0.25, 12, "steel_hi", chamfer=0.05, cham_col="steel_hi", part="CrankHub")
    arm = mb.box((-0.08, -0.08, 0.0), (0.08, 0.08, 1.15), "steel_hi", part="CrankArm")
    mb.xform(arm, Matrix.Translation(Vector((hub[0] + 0.32, hub[1], hub[2]))) @ Matrix.Rotation(math.radians(-35), 4, "X"))
    tip = Vector((hub[0] + 0.32, hub[1], hub[2])) + Matrix.Rotation(math.radians(-35), 3, "X") @ Vector((0, 0, 1.15))
    mb.cylinder(tuple(tip), (1, 0, 0), 0.13, -0.05, 0.5, 8, "ink_hi", part="CrankGrip")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    md = k.MB("CashRegister_Drawer")
    dx0, dx1, dy0, dy1, dz0, dz1 = x0 + 0.2, x1 - 0.2, y0 - 0.05, y1 - 0.4, 0.15, 0.82
    md.box((dx0, dy0, dz0), (dx1, dy0 + 0.18, dz1), "steel", chamfer=0.05, cham_col="steel_hi", part="Front")
    md.box((-0.45, dy0 - 0.12, 0.42), (0.45, dy0 + 0.02, 0.55), "steel_hi", chamfer=0.03, part="Pull")
    md.box((dx0, dy0 + 0.18, dz0), (dx1, dy1, dz0 + 0.08), "ink", part="Floor")
    for xa, xb in ((dx0, dx0 + 0.08), (dx1 - 0.08, dx1)):
        md.box((xa, dy0 + 0.18, dz0), (xb, dy1, dz1 - 0.1), "steel_lo", part="Side")
    md.box((dx0, dy1 - 0.08, dz0), (dx1, dy1, dz1 - 0.1), "steel_lo", part="Back")
    for i in range(4):   # bill stacks in four slots: the loot (Heist Gold)
        xa = dx0 + 0.15 + i * 0.68
        md.box((xa, dy0 + 0.35, dz0 + 0.08), (xa + 0.55, dy1 - 0.9, dz0 + 0.42), "gold", chamfer=0.04, cham_col="gold_hi",
               flat=("-z",), part=f"Bills_{i}")
        md.box((xa + 0.2, dy0 + 0.33, dz0 + 0.08), (xa + 0.35, dy1 - 0.88, dz0 + 0.44), "gold_lo", part=f"Band_{i}")
    for i in range(5):   # coin cups at the back
        md.cylinder((dx0 + 0.35 + i * 0.6, dy1 - 0.45, dz0 + 0.08), (0, 0, 1), 0.22, 0.0, 0.16, 8, "gold_hi", part=f"Coins_{i}")
    dr = k.finalize(md, pivot=(0, dy0, dz0))
    return k.Asset("CashRegister", [
        k.Obj(ob, "small", role="hero", pivot="point", collision="Box", can_collide=False, tags=["EH_LootDisplay"],
              notes="register body on a counter top (origin = bottom centre); drawer slides out along -Y when grabbed"),
        k.Obj(dr, "small", role="loot", pivot="point", collision="Box", can_collide=False, cast_shadow=False, tags=["EH_Loot"],
              notes="origin = drawer front-bottom centre; open = move 1.6 studs along -Z (Roblox)"),
    ], budget_cls="hero", seats=[("CashRegister_Drawer", "CashRegister")],
        notes="Hero prop: chrome retro register (3.4x3.2x3.95), 16 keys, crank, sale tab; drawer of gold bills as its own part.")


# ---------------------------------------------------------------- diamond pedestal

PEDESTAL_TOP = 3.4


def pedestal(k):
    mb = k.MB("Pedestal_Diamond")
    mb.box((-1.6, -1.6, 0.0), (1.6, 1.6, 0.5), "ink", chamfer=0.12, cham_col="ink_hi", flat=("-z",), part="Plinth")
    mb.box((-1.35, -1.35, 0.5), (1.35, 1.35, 0.8), "steel_lo", chamfer=0.1, cham_col="steel", part="Step")
    mb.box((-1.05, -1.05, 0.8), (1.05, 1.05, 2.9), "steel_lo", chamfer=0.2, cham_col="steel", flat=("-z", "+z"), part="Column")
    for side in range(4):   # fluting: two raised strips per face (bank architecture, catches the light)
        for off in (-0.45, 0.45):
            strip = mb.box((off - 0.1, -1.12, 1.05), (off + 0.1, -1.0, 2.65), "steel", chamfer=0.03, cham_col="steel_hi",
                           flat=("+y",), part=f"Flute_{side}")
            mb.rotate(strip, 90 * side, "Z")
    mb.box((-1.45, -1.45, 2.9), (1.45, 1.45, PEDESTAL_TOP - 0.15), "steel", chamfer=0.1, cham_col="steel_hi", part="Cap")
    mb.box((-1.15, -1.15, PEDESTAL_TOP - 0.15), (1.15, 1.15, PEDESTAL_TOP), "ink_hi", chamfer=0.06, cham_col="ink_hi", part="Cushion")
    mb.box((-0.7, -1.68, 0.12), (0.7, -1.55, 0.4), "marble", chamfer=0.04, cham_col="marble_hi", part="Plaque")   # name plate
    ob = k.finalize(mb, pivot=(0, 0, 0))
    mg = k.MB("Pedestal_Diamond_Case")
    g0, g1, gt = -1.3, 1.3, 2.7
    for lo, hi in (((g0, g0, 0.0), (g1, g0 + 0.06, gt)), ((g0, g1 - 0.06, 0.0), (g1, g1, gt)), ((g0, g0 + 0.06, 0.0), (g0 + 0.06, g1 - 0.06, gt)),
                   ((g1 - 0.06, g0 + 0.06, 0.0), (g1, g1 - 0.06, gt)), ((g0 + 0.06, g0 + 0.06, gt - 0.06), (g1 - 0.06, g1 - 0.06, gt))):
        mg.box((lo[0], lo[1], lo[2] + PEDESTAL_TOP - 0.15), (hi[0], hi[1], hi[2] + PEDESTAL_TOP - 0.15), "steel_hi", part="Pane")
    gc = k.finalize(mg, pivot=(0, 0, PEDESTAL_TOP - 0.15))
    return k.Asset("Pedestal_Diamond", [
        k.Obj(ob, "small", role="env", symmetric="X", pivot="point", collision="Box", tags=["EH_LootDisplay"],
              sim="solid: footprint 3.2 x 3.2, 3.4 tall", notes="Diamond centre = 1.25 above the cushion (y 4.65); hover + spin by code"),
        k.Obj(gc, "small", role="env", symmetric="XY", pivot="point", collision="Box", material="Glass", can_collide=False,
              cast_shadow=False, atlas=False, transparency=0.7, tint="Vault Steel light #A9B2CC",
              notes="glass case; origin = its bottom centre on the cap; lifts 3 studs when the diamond is taken"),
    ], seats=[("Pedestal_Diamond_Case", "Pedestal_Diamond")],
        notes="Hero display: fluted Vault Steel shade column, dark cushion, marble name plate; glass case as its own part.")


# ---------------------------------------------------------------- giant present

def present(k):
    mb = k.MB("GiantPresent")
    S, Hb = 6.0, 5.0
    h = S / 2
    mb.box((-h, -h, 0.0), (h, h, Hb), "holly_lo", chamfer=0.18, cham_col="holly", flat=("-z",), part="Box")
    rb = 0.45   # ribbon half width
    for ax in ("x", "y"):   # ribbon bands over the top and down all four sides (proud 0.08)
        if ax == "x":
            mb.box((-h - 0.08, -rb, 0.0), (h + 0.08, rb, Hb + 0.08), "gold", chamfer=0.06, cham_col="gold_hi", flat=("-z",), part="RibbonX")
        else:
            mb.box((-rb, -h - 0.08, 0.0), (rb, h + 0.08, Hb + 0.08), "gold", chamfer=0.06, cham_col="gold_hi", flat=("-z",), part="RibbonY")
    top = Hb + 0.08
    # bow: four loops (two big along X, two smaller along Y, tilted outward), a knot and two tails: the bow is
    # the present's silhouette at 64 px
    for axis_deg, span, rise, tilt in ((0, 1.25, 1.75, 18), (90, 0.95, 1.3, 26)):
        for sgn in (-1, 1):
            path = []
            for i in range(11):
                a = math.pi * i / 10
                path.append((sgn * (0.3 + span * (1 - math.cos(a))), 0.0, rise * math.sin(a)))
            loop = L.tube(mb, path, [0.24 + 0.14 * math.sin(math.pi * i / 10) for i in range(11)], 8, "gold",
                          cols=["gold_hi" if i in (3, 4, 5, 6) else "gold" for i in range(11)], cap_col="gold_lo",
                          part="Loop", normal=(0, 1, 0))
            mb.rotate(loop, sgn * tilt, "Y")
            mb.rotate(loop, axis_deg, "Z")
            mb.move(loop, (0, 0, top + 0.12))
    for sgn in (-1, 1):
        tail = [(sgn * 0.3, -0.2, top + 0.05), (sgn * 1.0, -1.1, top + 0.02), (sgn * 1.45, -2.2, top + 0.02)]
        L.tube(mb, tail, [0.22, 0.18, 0.13], 6, "gold", cap_col="gold_lo", part="Tail")
    mb.sphere((0, 0, top + 0.3), 0.5, 10, 6, "gold_hi", part="Knot")
    # gift tag on a string, hanging from the knot down the front ribbon
    mb.box((-0.04, -h - 0.16, Hb - 1.0), (0.04, -h + 0.05, top + 0.05), "marble_lo", part="String")
    tag = [(-0.55, Hb - 2.4), (0.55, Hb - 2.4), (0.55, Hb - 1.3), (0.0, Hb - 0.95), (-0.55, Hb - 1.3)]
    mb.prism(tag, "Y", -h - 0.24, -h - 0.12, "marble", "marble_hi", part="Tag")
    # grip straps: 4 dark handles at mid height, one per side (the heavy-loot grip points)
    for side in range(4):
        strap = []
        strap += mb.box((-1.2, -h - 0.12, 2.0), (-0.9, -h + 0.02, 3.3), "ink_hi", part=f"StrapL_{side}")
        strap += mb.box((0.9, -h - 0.12, 2.0), (1.2, -h + 0.02, 3.3), "ink_hi", part=f"StrapR_{side}")
        strap += mb.box((-1.2, -h - 0.6, 3.05), (1.2, -h - 0.1, 3.3), "ink_hi", chamfer=0.05, cham_col="steel_lo", part=f"Handle_{side}")
        strap += mb.box((-1.2, -h - 0.6, 2.75), (-0.95, -h - 0.1, 3.05), "ink_hi", part=f"HandleL_{side}")
        strap += mb.box((0.95, -h - 0.6, 2.75), (1.2, -h - 0.1, 3.05), "ink_hi", part=f"HandleR_{side}")
        mb.rotate(strap, 90 * side, "Z")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    grips = [k.roblox_point(p) for p in ((0.0, -h - 0.35, 3.2), (h + 0.35, 0.0, 3.2), (0.0, h + 0.35, 3.2), (-h - 0.35, 0.0, 3.2))]
    return k.Asset("GiantPresent", [k.Obj(ob, "hero", role="present", pivot="point", collision="Box", tags=["EH_HeavyLoot"],
                                         sim="heavy loot: footprint 6 x 6, 5 tall (bow to 6.8)", extra={"grips": grips},
                                         notes="2 grips required, 4 max (Config); origin = bottom centre")],
                   notes="Hero loot: Giant Present 6x6x5 (bow to 6.8): holly paper, gold ribbon + bow, tag, 4 grip straps.")


def build(k):
    return [register(k), pedestal(k), present(k)]
