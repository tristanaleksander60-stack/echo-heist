"""Kit props (launch kit): Safe (+ door), CashBag (loot "Cash").

Build: python3 tools/blender/build_asset.py assets/blender/props.py
Safe: the L4 night deposit (LevelSpec loot "NightDeposit"): a squat floor safe with a dark interior and a
door on its own hinge pivot, so code swings it open when the loot is grabbed. Dial and handle are on the door.
CashBag: the carried "Cash" loot (L1-L4 loot kind "Cash"): a cinched sack in Heist Gold with a raised "$"
badge. It is the only gold thing in the Corner Shop, so loot reads by colour plus the sparkle VFX (shape).
Origins: bottom centre (floor props); the safe door's origin is its hinge axis at the door's bottom.
"""
import math
import _kitlib as L


# ---------------------------------------------------------------- safe

def safe(k):
    W, Dp, Hs, t = 3.2, 3.0, 3.6, 0.3
    x0, x1, y0, y1 = -W / 2, W / 2, -Dp / 2, Dp / 2
    z0 = 0.35   # body sits on 4 feet
    mb = k.MB("Safe")
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.box((sx * 1.25 - 0.25, sy * 1.1 - 0.25, 0.0), (sx * 1.25 + 0.25, sy * 1.1 + 0.25, z0 + 0.05), "ink",
                   chamfer=0.06, cham_col="ink_hi", flat=("-z", "+z"), part="Foot")
    mb.box((x0, y0 + 0.2, z0), (x1, y1, z0 + t), "steel_lo", chamfer=0.12, cham_col="steel", flat=("-y",), part="Bottom")
    mb.box((x0, y0 + 0.2, z0 + Hs - t), (x1, y1, z0 + Hs), "steel_lo", chamfer=0.15, cham_col="steel", flat=("-y",), part="Top")
    for xa, xb in ((x0, x0 + t), (x1 - t, x1)):
        mb.box((xa, y0 + 0.2, z0 + t), (xb, y1, z0 + Hs - t), "steel_lo", chamfer=0.12, cham_col="steel", flat=("-y", "-z", "+z"), part="Side")
    mb.box((x0 + t, y1 - t, z0 + t), (x1 - t, y1, z0 + Hs - t), "steel_lo", part="Back")
    # dark interior and a shelf: the loot sits inside on a dark surface (display rule)
    mb.box((x0 + t, y1 - t - 0.04, z0 + t), (x1 - t, y1 - t, z0 + Hs - t), "ink", part="InBack")
    mb.box((x0 + t, y0 + 0.25, z0 + t), (x1 - t, y1 - t, z0 + t + 0.04), "ink", part="InFloor")
    mb.box((x0 + t, y0 + 0.25, z0 + Hs - t - 0.04), (x1 - t, y1 - t, z0 + Hs - t), "ink", part="InTop")
    for xa, xb in ((x0 + t, x0 + t + 0.04), (x1 - t - 0.04, x1 - t)):
        mb.box((xa, y0 + 0.25, z0 + t), (xb, y1 - t, z0 + Hs - t), "ink", part="InSide")
    mb.box((x0 + t, y0 + 0.3, z0 + 1.75), (x1 - t, y1 - t, z0 + 1.87), "ink_hi", part="Shelf")
    # front frame lip around the door (steel light): the door seats against it
    for lo, hi in (((x0, y0 + 0.08, z0), (x1, y0 + 0.2, z0 + t)), ((x0, y0 + 0.08, z0 + Hs - t), (x1, y0 + 0.2, z0 + Hs)),
                   ((x0, y0 + 0.08, z0 + t), (x0 + t, y0 + 0.2, z0 + Hs - t)), ((x1 - t, y0 + 0.08, z0 + t), (x1, y0 + 0.2, z0 + Hs - t))):
        mb.box(lo, hi, "steel", chamfer=0.05, cham_col="steel_hi", flat=("+y",), part="Lip")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    md = k.MB("Safe_Door")
    hx, hy = x0 + t, y0 + 0.08     # hinge on the left, at the front of the lip
    dz0, dz1 = z0 + t + 0.03, z0 + Hs - t - 0.03
    md.box((x0 + t + 0.03, y0 - 0.22, dz0), (x1 - t - 0.03, y0 + 0.08, dz1), "steel", chamfer=0.1, cham_col="steel_hi", part="Slab")
    md.box((x0 + t + 0.35, y0 - 0.3, dz0 + 0.32), (x1 - t - 0.35, y0 - 0.2, dz1 - 0.32), "steel_lo", chamfer=0.05,
           cham_col="steel", flat=("+y",), part="Panel")
    dc = (0.15, y0 - 0.3, z0 + Hs * 0.58)
    md.cylinder(dc, (0, -1, 0), 0.62, -0.02, 0.12, 20, "steel_hi", chamfer=0.04, cham_col="steel_hi", part="DialRing")
    md.cylinder(dc, (0, -1, 0), 0.42, 0.1, 0.24, 16, "ink_hi", chamfer=0.04, cham_col="steel_lo", part="Dial")
    md.box((dc[0] - 0.05, dc[1] - 0.26, dc[2] + 0.18), (dc[0] + 0.05, dc[1] - 0.2, dc[2] + 0.4), "marble", part="Tick")
    hc = (0.15, y0 - 0.3, z0 + Hs * 0.3)
    md.cylinder(hc, (0, -1, 0), 0.16, -0.02, 0.32, 8, "steel_hi", part="Hub")
    for a in (90, 210, 330):
        d = (math.cos(math.radians(a)), 0, math.sin(math.radians(a)))
        md.cylinder((hc[0], hc[1] - 0.24, hc[2]), d, 0.07, 0.1, 0.62, 6, "steel_hi", part=f"Spoke_{a}")
    for zz in (dz0 + 0.45, dz1 - 0.45):   # hinge knuckles on the left edge
        md.cylinder((hx - 0.02, hy - 0.12, zz), (0, 0, 1), 0.12, -0.25, 0.25, 8, "steel_hi", part="Knuckle")
    dr = k.finalize(md, pivot=(hx, hy, dz0))
    return k.Asset("Safe", [
        k.Obj(ob, "small", role="env", symmetric="X", pivot="point", collision="Box", tags=["EH_Safe"],
              sim="solid: footprint 3.2 x 3, 3.95 tall (Gus sees over it)", notes="floor safe body; loot sits inside on the dark shelf or floor"),
        k.Obj(dr, "small", role="env", pivot="point", collision="Box", tags=["EH_SafeDoor"],
              notes="origin = hinge axis (left) at the door bottom; open = rotate about Roblox Y by -100 deg"),
    ], seats=[("Safe_Door", "Safe")],
        notes="Floor safe 3.2x3x3.95: hollow steel body (dark interior, shelf), front lip, hinged door with dial and 3-spoke handle.")


# ---------------------------------------------------------------- cash bag

def cash_bag(k):
    mb = k.MB("CashBag")
    prof = [(0, 0.0), (0.55, 0.0), (0.82, 0.12), (0.95, 0.5), (0.9, 1.0), (0.62, 1.35), (0.3, 1.5), (0.26, 1.62),
            (0.42, 1.78), (0.5, 1.95), (0.32, 2.02), (0, 1.9)]
    cols = ["gold_lo", "gold", "gold", "gold", "gold", "gold_hi", "gold_lo", "gold", "gold_hi", "gold_hi", "gold"]
    mb.lathe(prof, 16, cols, (0, 0, 0), part="Sack")
    mb.cylinder((0, 0, 1.47), (0, 0, 1), 0.36, 0.0, 0.16, 12, "gold_lo", part="Tie")          # the cinch cord
    # "$" badge: a gold_hi disc pushed into the sack front, with the glyph raised on it
    bc = (0.0, -0.84, 0.72)
    mb.cylinder(bc, (0, -1, 0), 0.42, -0.15, 0.12, 16, "gold_lo", part="Badge")
    face_y = bc[1] - 0.12
    pts = []
    for i in range(7):                                    # upper bowl, right to the middle (counter-clockwise)
        a = math.radians(30 + 210 * i / 6)
        pts.append((0.19 * math.cos(a), face_y, bc[2] + 0.15 + 0.15 * math.sin(a)))
    for i in range(1, 7):                                 # lower bowl, middle to lower left (clockwise)
        a = math.radians(90 - 210 * i / 6)
        pts.append((0.19 * math.cos(a), face_y, bc[2] - 0.15 + 0.15 * math.sin(a)))
    L.tube(mb, pts, 0.06, 6, "gold_hi", cap_col="gold_hi", part="S", normal=(0, 1, 0))
    mb.box((-0.04, face_y - 0.06, bc[2] - 0.38), (0.04, face_y + 0.02, bc[2] + 0.38), "gold_hi", part="Bar")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("CashBag", [k.Obj(ob, "small", role="loot", pivot="point", collision="Box", cast_shadow=False,
                                     tags=["EH_Loot"], notes="carried Cash loot; CanCollide off while carried")],
                   notes="Loot: cash sack (1.9 x 2.02), cinched neck and a raised $ badge; Heist Gold only.")


def build(k):
    return [safe(k), cash_bag(k)]
