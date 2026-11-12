"""Kit hiding spots (launch kit props, `EH_Hide`): Hide_Crate, Hide_Plant, Hide_Curtain, Hide_CoatRack.

Build: python3 tools/blender/build_asset.py assets/blender/hides.py
An actor inside a hide volume is invisible to Gus unless he is within 3 studs (MASTERPLAN 3.1,
HIDE_REVEAL_RADIUS). So every hide prop is walk-in: CanCollide OFF, and its shape says "there is room for one
of you in here" (an open crate, a big leafy plant, a curtain off the wall, long coats on a rack).
Footprints match the L4 hide boxes: Crate 4 x 3 x 6 (LevelSpec Crate span 3.5..7.5 x -35.5..-32.5), CoatRack
6 wide (CoatRack span -15..-9). Origin = bottom centre for free-standing props; the curtain's origin is the
bottom centre of its wall line (y = 0 is the wall face, the drape hangs toward -Y).
Colours avoid every signal colour and the wall colours (the curtain is green velvet, so it never melts into a
plum or brick wall); the crate's interior is Ink, so an actor inside reads "in the shadows".
"""
import math
import _kitlib as L


# ---------------------------------------------------------------- crate

def _plank_panel(mb, lo, hi, ends, n, col, part):
    """A panel of n planks stacked along z, with 0.06 chamfers: the gaps read as plank seams. `ends` are the
    faces hidden under the corner battens (kept flat: no chamfer tris there)."""
    z0, z1 = lo[2], hi[2]
    out = []
    for i in range(n):
        a, b = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
        out += mb.box((lo[0], lo[1], a), (hi[0], hi[1], b), col, chamfer=0.06, cham_col="wood_hi", flat=ends, part=f"{part}_{i}")
    return out


def crate(k):
    mb = k.MB("Hide_Crate")
    W, Dp, Hc, t = 4.0, 3.0, 5.8, 0.25     # 5.8 tall: a 5.2-stud avatar fits inside (L4 box is 6 tall)
    x0, x1, y0, y1 = -W / 2, W / 2, -Dp / 2, Dp / 2
    mb.box((x0 + t, y0, 0.0), (x1 - t, y1 - t, 0.3), "ink", part="Floor")                       # dark interior floor
    mb.box((x0 + t, y1 - t - 0.05, 0.3), (x1 - t, y1 - t + 0.01, Hc - t), "ink_hi", part="InnerBack")
    _plank_panel(mb, (x0 + t, y1 - t, 0.0), (x1 - t, y1, Hc - t), ("-x", "+x", "-y"), 3, "wood", "Back")
    for xa, xb, inner in ((x0, x0 + t, "+x"), (x1 - t, x1, "-x")):
        _plank_panel(mb, (xa, y0, 0.0), (xb, y1, Hc - t), ("-y", "+y", inner), 3, "wood", "Side")
    mb.box((x0, y0, Hc - t), (x1, y1, Hc), "wood", chamfer=0.06, cham_col="wood_hi", part="Top")
    for xa, xb in ((x0 + t, x0 + t + 0.06), (x1 - t - 0.06, x1 - t)):   # dark inner faces of the side walls
        mb.box((xa, y0 + 0.1, 0.3), (xb, y1 - t, Hc - t), "ink_hi", part="InnerSide")
    mb.box((x0 + t, y0 + 0.1, Hc - t - 0.06), (x1 - t, y1 - t, Hc - t), "ink_hi", part="InnerTop")
    # corner battens (darker wood) on the front edges and the back corners: the "crate" read
    for xa, xb in ((x0 - 0.12, x0 + 0.3), (x1 - 0.3, x1 + 0.12)):
        for ya, yb in ((y0 - 0.12, y0 + 0.3), (y1 - 0.3, y1 + 0.12)):
            mb.box((xa, ya, 0.0), (xb, yb, Hc + 0.05), "wood_lo", chamfer=0.07, cham_col="wood", flat=("-z", "+z"), part="Batten")
    # stencil: an "up" arrow on each side (marble, proud 0.04)
    arrow = [(-0.35, 1.2), (0.35, 1.2), (0.35, 2.3), (0.75, 2.3), (0.0, 3.2), (-0.75, 2.3), (-0.35, 2.3)]
    for sx in (-1, 1):
        xs = sx * (W / 2 + 0.04)
        mb.prism([(y, z) for y, z in arrow], "X", xs - 0.06 if sx > 0 else xs, xs if sx > 0 else xs + 0.06,
                 "marble", "marble", part="Stencil")
    # the lid, taken off and leaned against the left side: the crate is open, and there is room inside
    lx = x0 - 0.12
    lid = _plank_panel(mb, (lx - 0.22, -1.35, 0.0), (lx, 1.35, Hc - 0.3), ("-x",), 3, "wood", "Lid")
    mb.rotate(lid, 13, "Y", (lx, 0.0, Hc - 0.3))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_Crate", [k.Obj(ob, "small", role="env", pivot="point", collision="Box", can_collide=False,
                                        tags=["EH_Hide"], sim="hide volume 4 x 3 x 6 (L4 Crate)",
                                        notes="origin = crate footprint centre on the floor; walk-in: CanCollide off; open side faces -Y")],
                   notes="Hide spot: open wardrobe crate (4x3x5.85), plank sides, dark interior, lid leaned on its left side.")


# ---------------------------------------------------------------- plant

LEAF = [(0.0, 0.0), (0.5, 0.32), (1.4, 0.52), (2.3, 0.36), (2.9, 0.0), (2.3, -0.36), (1.4, -0.52), (0.5, -0.32)]


def plant(k):
    from mathutils import Matrix, Vector
    mb = k.MB("Hide_Plant")
    mb.lathe([(0, 0.0), (0.9, 0.0), (1.0, 0.12), (1.25, 1.55), (1.42, 1.62), (1.42, 1.85), (1.2, 1.85), (1.15, 1.7), (0, 1.7)],
             12, ["marble_lo", "marble_lo", "marble", "marble_hi", "marble", "marble_hi", "marble_lo", "ink"], (0, 0, 0),
             part="Pot")
    leaves = [  # (azimuth, elevation, base height, length scale, colour)
        (10, 55, 2.3, 1.05, "leaf_hi"), (80, 40, 2.0, 1.0, "leaf"), (150, 60, 2.6, 1.0, "leaf_hi"), (215, 38, 1.9, 1.05, "leaf"),
        (280, 52, 2.4, 1.0, "leaf_hi"), (330, 34, 1.9, 0.95, "leaf"), (45, 72, 3.2, 0.9, "leaf"), (190, 75, 3.4, 0.85, "leaf_hi"),
        (260, 20, 1.8, 0.9, "leaf_lo"), (115, 22, 1.8, 0.95, "leaf_lo"),
    ]
    for i, (az, el, bz, sc, col) in enumerate(leaves):
        stem_top = Vector((0.3 * math.cos(math.radians(az)), 0.3 * math.sin(math.radians(az)), bz))
        mb.cylinder((0, 0, 1.6), tuple((stem_top - Vector((0, 0, 1.6))).normalized()), 0.07, 0.0,
                    (stem_top - Vector((0, 0, 1.6))).length + 0.1, 3, "leaf_lo", part=f"Stem_{i}")
        vs = mb.prism([(x * sc, y * sc) for x, y in LEAF], "Z", -0.05, 0.05, [col] * len(LEAF), col, part=f"Leaf_{i}")
        m = (Matrix.Translation(stem_top) @ Matrix.Rotation(math.radians(az), 4, "Z") @ Matrix.Rotation(math.radians(-el), 4, "Y")
             @ Matrix.Rotation(math.radians(12 if i % 2 else -12), 4, "X"))
        mb.xform(vs, m)
    # 1.35x: big enough to hide a 5.2-stud avatar (props are 1.5-2x real size, STYLE_BIBLE 5)
    mb.xform(list(mb.bm.verts), Matrix.Scale(1.35, 4))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_Plant", [k.Obj(ob, "small", role="env", pivot="point", collision="Box", can_collide=False,
                                        tags=["EH_Hide"], sim="hide volume about 4 x 4 x 6",
                                        notes="origin = pot centre on the floor; walk-in: CanCollide off; stand among the leaves")],
                   notes="Hide spot: big leafy potted plant (cream pot, 10 blade leaves in three greens), 7.8 tall.")


# ---------------------------------------------------------------- curtain

def curtain(k):
    mb = k.MB("Hide_Curtain")
    rows = [  # (z, half width, pleat amplitude): gathered at the rod, flaring to the floor
        (10.45, 2.1, 0.4), (7.0, 2.2, 0.5), (3.5, 2.35, 0.6), (0.6, 2.48, 0.66), (0.12, 2.5, 0.66)]
    n, yc, th = 10, -1.45, 0.12
    front, back = [], []
    for z, hw, amp in rows:
        f, b = [], []
        for j in range(n + 1):
            x = -hw + 2 * hw * j / n
            y = yc - amp * (1 if j % 2 else -1) * 0.5
            f.append(mb.v((x, y - th / 2, z)))
            b.append(mb.v((x, y + th / 2, z)))
        front.append(f); back.append(b)
    for r in range(len(rows) - 1):
        hem = r == len(rows) - 2    # the bottom band is the cream hem: the read of "heavy velvet"
        for j in range(n):
            fc = "marble" if hem else ("leaf" if j % 2 == 0 else "leaf_lo")   # lit and shaded pleat faces
            mb.f([front[r][j], front[r][j + 1], front[r + 1][j + 1], front[r + 1][j]], fc)
            mb.f([back[r][j + 1], back[r][j], back[r + 1][j], back[r + 1][j + 1]], "marble_lo" if hem else "leaf_lo")
        for j, side in ((0, -1), (n, 1)):
            q = [front[r][j], back[r][j], back[r + 1][j], front[r + 1][j]]
            mb.f(q if side < 0 else list(reversed(q)), "marble" if hem else "leaf_lo")
    for r, col in ((0, "leaf_lo"), (len(rows) - 1, "marble_lo")):   # top and bottom strips
        for j in range(n):
            q = [front[r][j], back[r][j], back[r][j + 1], front[r][j + 1]]
            mb.f(q if r == 0 else list(reversed(q)), col)
    # rod with finials and two wall brackets
    mb.cylinder((-2.85, yc, 10.55), (1, 0, 0), 0.12, 0.0, 5.7, 8, "steel", part="Rod")
    for sx in (-1, 1):
        mb.sphere((sx * 2.95, yc, 10.55), 0.24, 6, 4, "steel_hi", part="Finial")
        mb.box((sx * 2.3 - 0.1, yc - 0.1, 10.45), (sx * 2.3 + 0.1, 0.0, 10.65), "steel_lo", part="Bracket")
        mb.box((sx * 2.3 - 0.3, -0.08, 10.2), (sx * 2.3 + 0.3, 0.0, 10.9), "steel_lo", part="Plate")
    for j in range(1, n, 2):   # rings on the rod (one per front pleat)
        x = -2.1 + 4.2 * j / n
        mb.cylinder((x, yc, 10.55), (1, 0, 0), 0.2, -0.04, 0.04, 5, "steel_hi", part=f"Ring_{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_Curtain", [k.Obj(ob, "small", role="env", symmetric="X", pivot="point", collision="Box",
                                          can_collide=False, tags=["EH_Hide"], sim="hide volume 5 x 1.9 x 10 against a wall",
                                          notes="origin = bottom centre on the wall face; the drape hangs 1.45 off the wall")],
                   notes="Hide spot: deep-pleated green velvet drape on a steel rod, cream hem, 1.9 deep off the wall.")


# ---------------------------------------------------------------- coat rack

COAT = [(-0.85, 0.0), (0.85, 0.0), (0.72, 3.4), (0.55, 4.25), (0.2, 4.55), (-0.2, 4.55), (-0.55, 4.25), (-0.72, 3.4)]


def coat_rack(k):
    mb = k.MB("Hide_CoatRack")
    W = 6.0
    for sx in (-1, 1):
        mb.box((sx * W / 2 - 0.2, -0.2, 0.0), (sx * W / 2 + 0.2, 0.2, 7.0), "wood_lo", chamfer=0.07, cham_col="wood", part="Post")
        mb.box((sx * W / 2 - 0.45, -0.9, 0.0), (sx * W / 2 + 0.45, 0.9, 0.3), "wood_lo", chamfer=0.07, cham_col="wood",
               flat=("-z",), part="Foot")
        mb.sphere((sx * W / 2, 0, 7.15), 0.28, 6, 4, "wood", part="Knob")
    mb.cylinder((-W / 2, 0, 6.5), (1, 0, 0), 0.12, 0.0, W, 8, "steel", part="Rail")
    mb.box((-W / 2, -0.55, 6.85), (W / 2, 0.55, 7.0), "wood_lo", chamfer=0.05, cham_col="wood", part="HatShelf")
    coats = ((-1.85, "steel_lo", "steel"), (0.0, "wood", "wood_hi"), (1.85, "ink_hi", "steel_lo"))
    for i, (cx, col, collar) in enumerate(coats):
        poly = [(x + cx, z + 1.55) for x, z in COAT]
        mb.prism(poly, "Y", -0.35, 0.35, [col, col, col, collar, collar, collar, collar, col], col, part=f"Coat_{i}")
        mb.box((cx - 0.08, -0.32, 6.05), (cx + 0.08, 0.32, 6.62), "steel_hi", part=f"Hook_{i}")      # hanger hook
        mb.box((cx - 0.12, -0.45, 2.6), (cx + 0.12, -0.32, 5.0), collar, part=f"Placket_{i}")         # button line
    # two hats on the shelf
    for cx, col in ((-1.6, "ink_hi"), (1.3, "wood")):
        mb.lathe([(0, 7.0), (0.75, 7.0), (0.78, 7.08), (0.45, 7.12), (0.42, 7.55), (0, 7.6)], 8,
                 [col, "steel_lo", col, col, col], (cx, 0, 0), part="Hat")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_CoatRack", [k.Obj(ob, "small", role="env", pivot="bottom", collision="Box", can_collide=False,
                                           tags=["EH_Hide"], sim="hide volume 6 x 5.5 x 7 (L4 CoatRack)",
                                           notes="walk-in: CanCollide off; stand behind the coats")],
                   notes="Hide spot: free-standing coat rack (6 wide) with three long coats and two hats.")


def build(k):
    return [crate(k), plant(k), curtain(k), coat_rack(k)]
