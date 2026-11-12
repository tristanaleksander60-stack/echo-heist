"""Kit hiding spots (launch kit props, `EH_Hide`): Hide_Crate, Hide_Plant, Hide_Curtain, Hide_CoatRack,
Hide_CoatStand, Hide_DepositStack.

Build: python3 tools/blender/build_asset.py assets/blender/hides.py
An actor inside a hide volume is invisible to Gus unless he is within 3 studs (MASTERPLAN 3.1,
HIDE_REVEAL_RADIUS). So every hide prop is walk-in: CanCollide OFF (the sim box decides, the mesh only shows it),
and its shape says "there is room for one of you in here". Pass 2 (2026-11-12): most launch hide boxes have a
pressure plate under them (L4 CoatRack / plate B, L6 Fern / B, WestStack / C, EastStack / D, DV09 CoatRack / A),
so the plate hides keep a 4 x 4 OPEN FLOOR NICHE at their centre: the plate ring stays visible from above and
from the open side, and the hidden avatar stands on it, not inside a prop. Footprints follow the LevelSpec boxes
(docs/art/KIT_IMPORT.md fit table, generated from the level data):
  Hide_Plant        6 x 6: two planter troughs flanking the niche, fronds arching over its open ends (Fern 6.5 x 6.5)
  Hide_CoatRack     6.0 x 4.5: a double garment rack, coats on both rails, the niche between them (6 x 5.5, 6 x 6)
  Hide_DepositStack 6 x 6: a U of deposit-box towers, open on the front (-Y), dark inside (6 x 6 stacks)
  Hide_CoatStand    4.7 round: coats on a ring rail on three legs, open at the front (CoatStand 5 x 5)
  Hide_Crate        4.4 x 2.7: an open wardrobe crate (L4 Crate 4 x 3, its back 0.5 inside the partition)
  Hide_Curtain      6.4 x 1.9: a drape off a wall (5 x 1.9 against a wall)
Origin = bottom centre (the niche centre = the plate centre); the curtain's origin is the bottom centre of its wall
line (y = 0 is the wall face, the drape hangs toward -Y). Colours: leaf / leaf_hi, wood, steel and marble faces
(palette rule R1: they read against every location's walls and floors); leaf_lo only on stems and back faces.
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
    # 5.8 tall: a 5.2-stud avatar fits inside (L4 box is 6 tall). 2.5 deep (pass 2, was 3): the L4 box is 3 deep but
    # its back 0.5 lies inside the 2-thick partition, so the crate's back sits on the partition face
    W, Dp, Hc, t = 3.6, 2.5, 5.8, 0.25     # 3.6 wide: with the battens and the leaned lid the crate is 4.4 (box: 4)
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
    # the lid, taken off and leaned (nearly upright, 4 deg) against the left side: the crate is open, there is
    # room inside, and the lid adds only 0.6 to the footprint (pass 2: at 13 deg it added 1.6)
    lx = x0 - 0.12
    lid = _plank_panel(mb, (lx - 0.22, -1.1, 0.0), (lx, 1.1, Hc - 0.3), ("-x",), 3, "wood", "Lid")
    mb.rotate(lid, 4, "Y", (lx, 0.0, Hc - 0.3))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_Crate", [k.Obj(ob, "small", role="env", pivot="point", collision="Box", can_collide=False,
                                        tags=["EH_Hide"], sim="hide: L4 Crate box (footprint 4 x 3, 6 tall; its back 0.5 inside the partition): crate back on the partition face; open side -Z",
                                        notes="origin = crate footprint centre on the floor; walk-in: CanCollide off; open side faces -Z (Roblox)")],
                   notes="Hide spot: open wardrobe crate (3.6 x 2.5 x 5.85), plank sides, dark interior, lid leaned upright on its left side.")


# ---------------------------------------------------------------- plant (planter niche)

LEAF = [(0.0, 0.0), (0.5, 0.32), (1.4, 0.52), (2.3, 0.36), (2.9, 0.0), (2.3, -0.36), (1.4, -0.52), (0.5, -0.32)]
TROUGH = dict(x=2.5, w=0.8, len=5.4, h=1.5)    # trough centre x, width, length (along y), height: the whole plant stays
                                               # within 3 of the plate centre (the Fern box minus the wall)


def _blade(mb, base, az, el, length, twist, col, part, width=0.85):
    """One flat leaf blade from `base`, pointing along azimuth az (deg, in the x-y plane) at elevation el. Returns
    the verts."""
    from mathutils import Matrix, Vector
    sc = length / 2.9
    vs = mb.prism([(x * sc, y * sc * width) for x, y in LEAF], "Z", -0.05, 0.05, [col] * len(LEAF), col, part=part)
    m = (Matrix.Translation(Vector(base)) @ Matrix.Rotation(math.radians(az), 4, "Z") @ Matrix.Rotation(math.radians(-el), 4, "Y")
         @ Matrix.Rotation(math.radians(twist), 4, "X"))
    mb.xform(vs, m)
    return vs


def plant(k):
    mb = k.MB("Hide_Plant")
    tx, tw, tl, th = TROUGH["x"], TROUGH["w"], TROUGH["len"], TROUGH["h"]
    for sx in (-1, 1):
        x0, x1 = sx * tx - tw / 2, sx * tx + tw / 2
        mb.box((x0, -tl / 2, 0.0), (x1, tl / 2, th), "marble", chamfer=0.1, cham_col="marble_hi", flat=("-z",), part=f"Trough{sx}")
        mb.box((x0 - 0.05, -tl / 2 - 0.05, 0.0), (x1 + 0.05, tl / 2 + 0.05, 0.3), "marble_lo", part=f"Plinth{sx}")
        mb.box((x0 + 0.12, -tl / 2 + 0.12, th - 0.12), (x1 - 0.12, tl / 2 - 0.12, th + 0.04), "ink_hi", part=f"Soil{sx}")
    # fronds per trough: (y along the trough, azimuth offset from "inward", elevation, length, colour, width).
    # Two narrow blades per trough arch over the niche's open ends and cross above head height (z 5.5-6.2): an
    # arbour over the hidden avatar that leaves the middle open, so the plate ring shows from above (B3). The
    # others stand up along the troughs. Everything stays inside the 6.5-stud Fern box (steep outer blades).
    fronds = [(-0.6, 0, 74, 4.9, "leaf", 0.85), (-1.9, 0, 51, 5.7, "leaf_hi", 0.55), (1.9, 0, 53, 5.6, "leaf", 0.55),
              (0.6, 0, 73, 4.8, "leaf_hi", 0.85), (-1.2, 180, 80, 4.6, "leaf_hi", 0.85), (1.2, 180, 82, 4.4, "leaf", 0.85),
              (-2.2, 100, 80, 4.3, "leaf", 0.85), (2.2, -100, 80, 4.3, "leaf_hi", 0.85)]
    for sx in (-1, 1):
        for i, (y, daz, el, ln, col, wd) in enumerate(fronds):
            inward = 180.0 if sx > 0 else 0.0           # azimuth pointing at the niche (toward x = 0)
            az = inward + (daz if sx > 0 else -daz)
            base = (sx * tx + (-0.2 if sx > 0 else 0.2), y, th - 0.05)
            _blade(mb, base, az, el, ln, sx * (14 if i % 2 else -14), col, f"Leaf{sx}_{i}", wd)   # blades rise from the soil
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_Plant", [k.Obj(ob, "small", role="env", symmetric="X", pivot="point", collision="Box", can_collide=False,
                                        tags=["EH_Hide"], extra={"niche": {"x": [-2.1, 2.1], "z": [-2.8, 2.8]}},
                                        sim="hide: Fern 6.5 x 6.5 (L6, DV10, DV12); niche X -2.1..2.1 open on -Z and +Z, centre = plate centre",
                                        notes="origin = niche centre on the floor (= the plate centre); walk-in: CanCollide off; "
                                              "the open ends face -Z and +Z (Roblox)"),],
                   notes="Hide spot: two cream planter troughs flanking a 4.2-wide open floor niche (the plate shows), "
                         "big fronds arching over it.")


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
            fc = "marble" if hem else ("leaf_hi" if j % 2 == 0 else "leaf")   # lit and shaded pleat faces
            mb.f([front[r][j], front[r][j + 1], front[r + 1][j + 1], front[r + 1][j]], fc)
            mb.f([back[r][j + 1], back[r][j], back[r + 1][j], back[r + 1][j + 1]], "marble_lo" if hem else "leaf_lo")
        for j, side in ((0, -1), (n, 1)):
            q = [front[r][j], back[r][j], back[r + 1][j], front[r + 1][j]]
            mb.f(q if side < 0 else list(reversed(q)), "marble" if hem else "leaf")
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
                                          can_collide=False, tags=["EH_Hide"], sim="hide: footprint 5 x 1.9, 10 tall, against a wall (drape 1.45 off the wall face, -Z)",
                                          notes="origin = bottom centre on the wall face; the drape hangs 1.45 off the wall")],
                   notes="Hide spot: deep-pleated green velvet drape on a steel rod, cream hem, 1.9 deep off the wall.")


# ---------------------------------------------------------------- coat rack (double garment rack)

COAT = [(-0.85, 0.0), (0.85, 0.0), (0.72, 3.4), (0.55, 4.25), (0.2, 4.55), (-0.2, 4.55), (-0.55, 4.25), (-0.72, 3.4)]
# Coat colours: (body, collar). No ink coats: an ink coat on a dark wall is invisible (palette rule R1).
COATS = [("marble_lo", "marble"), ("steel_lo", "steel"), ("wood", "wood_hi"), ("steel", "steel_hi")]


def _coat(mb, cx, cy, depth, cols, part, z0=1.55):
    col, collar = cols
    poly = [(x + cx, z + z0) for x, z in COAT]
    vs = mb.prism(poly, "Y", cy - depth / 2, cy + depth / 2, [col, col, col, collar, collar, collar, collar, col], col, part=part)
    return vs


def coat_rack(k):
    mb = k.MB("Hide_CoatRack")
    W, RY, RZ = 5.5, 2.0, 6.5      # post centres at x = +-W/2, rails at y = +-RY, rail height
    for sx in (-1, 1):
        x = sx * W / 2
        for sy in (-1, 1):
            mb.box((x - 0.17, sy * RY - 0.17, 0.3), (x + 0.17, sy * RY + 0.17, RZ + 0.35), "wood_lo", chamfer=0.06, cham_col="wood",
                   flat=("-z",), part=f"Post{sx}{sy}")
        mb.box((x - 0.25, -RY - 0.25, 0.0), (x + 0.25, RY + 0.25, 0.3), "wood_lo", chamfer=0.07, cham_col="wood", flat=("-z",), part=f"Foot{sx}")
        mb.box((x - 0.12, -RY, RZ + 0.1), (x + 0.12, RY, RZ + 0.3), "wood", part=f"TopBar{sx}")
    for sy in (-1, 1):
        mb.cylinder((-W / 2, sy * RY, RZ), (1, 0, 0), 0.11, 0.0, W, 8, "steel", part=f"Rail{sy}")
    order = (COATS[0], COATS[1], COATS[2], COATS[3], COATS[2], COATS[0])
    for i, cx in enumerate((-1.75, 0.0, 1.75)):
        for j, sy in enumerate((-1, 1)):
            cols = order[i + 3 * j]
            _coat(mb, cx, sy * RY, 0.7, cols, f"Coat_{i}{j}")   # the coat's shoulders touch the rail (no hook: tris)
            face = sy * (RY + 0.40)
            mb.box((cx - 0.12, min(face, face - sy * 0.13), 2.6), (cx + 0.12, max(face, face - sy * 0.13), 5.0), cols[1],
                   part=f"Placket_{i}{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_CoatRack", [k.Obj(ob, "small", role="env", symmetric="Y", pivot="bottom", collision="Box", can_collide=False,
                                           tags=["EH_Hide"], extra={"niche": {"x": [-2.75, 2.75], "z": [-1.65, 1.65]}},
                                           sim="hide: L4 CoatRack 6 x 5.5, DV09 CoatRack 6 x 6; niche between the rails Z -1.65..1.65, "
                                               "open at both X ends, centre = plate centre",
                                           notes="walk-in: CanCollide off; stand between the two rows of coats (on the plate)")],
                   notes="Hide spot: double garment rack (6 x 4.5), three long coats on each rail, the plate niche between them.")


def coat_stand(k):
    mb = k.MB("Hide_CoatStand")
    R, RZ = 1.95, 6.5
    mb.lathe([(R - 0.12, RZ - 0.1), (R + 0.12, RZ - 0.1), (R + 0.12, RZ + 0.1), (R - 0.12, RZ + 0.1)], 16, "steel", (0, 0, 0),
             closed=True, part="Ring")
    for a in (90, 210, 330):        # three legs: the back and the two jambs of the front opening
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        top, foot = (R * ca, R * sa, RZ), ((R + 0.15) * ca, (R + 0.15) * sa, 0.15)
        d = tuple(t - f for t, f in zip(top, foot))
        n = math.sqrt(sum(c * c for c in d))
        mb.cylinder(foot, tuple(c / n for c in d), 0.1, -0.05, n + 0.05, 6, "steel_lo", part=f"Leg_{a}")
        mb.box((foot[0] - 0.3, foot[1] - 0.3, 0.0), (foot[0] + 0.3, foot[1] + 0.3, 0.18), "ink", chamfer=0.05, cham_col="ink_hi",
               flat=("-z",), part=f"Foot_{a}")
    # five coats hung tangentially; the 120-degree gap at the front (-Y) is the way in
    cols = (COATS[0], COATS[1], COATS[2], COATS[3], COATS[1])
    for i, a in enumerate((330 - 360, 30, 90, 150, 210)):
        vs = _coat(mb, 0.0, 0.0, 0.6, cols[i], f"Coat_{i}")
        vs += mb.box((-0.08, -0.08, 6.05), (0.08, 0.08, RZ - 0.08), "steel_hi", part=f"Hook_{i}")
        mb.rotate(vs, a + 90, "Z")
        mb.move(vs, (R * math.cos(math.radians(a)), R * math.sin(math.radians(a)), 0.0))
    # a bowler hat left on the ring at the back
    mb.lathe([(0, RZ + 0.1), (0.62, RZ + 0.1), (0.65, RZ + 0.17), (0.38, RZ + 0.2), (0.36, RZ + 0.58), (0, RZ + 0.63)], 8,
             ["steel_lo", "steel", "steel_lo", "steel_lo", "steel_lo"], (0.0, R, 0.0), part="Hat")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_CoatStand", [k.Obj(ob, "small", role="env", symmetric="X", pivot="point", collision="Box", can_collide=False,
                                            tags=["EH_Hide"], sim="hide: L6 CoatStand 5 x 5, DV12 CoatStand 6.5 x 6.5; open side -Z",
                                            notes="origin = ring centre on the floor; walk-in: CanCollide off; stand inside the ring of coats")],
                   notes="Hide spot: round coat stand (4.7 across), five coats on a ring rail on three legs, open at the front.")


# ---------------------------------------------------------------- deposit-box stack

def deposit_stack(k):
    mb = k.MB("Hide_DepositStack")
    S, T, Hs = 3.0, 0.95, 7.0           # half size, tower thickness, height
    inner = S - T                       # 2.05: the niche is 4.1 x 4.1 (plate 4 x 4)
    towers = [((-S, -S, 0.0), (-inner, inner, Hs)), ((inner, -S, 0.0), (S, inner, Hs)), ((-S, inner, 0.0), (S, S, Hs))]
    for i, (lo, hi) in enumerate(towers):
        mb.box((lo[0], lo[1], 0.6), (hi[0], hi[1], Hs - 0.4), "steel_lo", chamfer=0.08, cham_col="steel", flat=("-z", "+z"), part=f"Tower_{i}")
        mb.box((lo[0] - 0.06, lo[1] - 0.06, 0.0), (hi[0] + 0.06, hi[1] + 0.06, 0.6), "ink", chamfer=0.07, cham_col="ink_hi",
               flat=("-z",), part=f"Plinth_{i}")
        mb.box((lo[0] - 0.12, lo[1] - 0.12, Hs - 0.4), (hi[0] + 0.12, hi[1] + 0.12, Hs), "steel", chamfer=0.1, cham_col="steel_hi",
               part=f"Cornice_{i}")
    # dark niche lining (the "in the shadows" read, like the crate)
    for lo, hi in (((-inner, -S + 0.1, 0.6), (-inner + 0.04, inner - 0.04, Hs - 0.4)),
                   ((inner - 0.04, -S + 0.1, 0.6), (inner, inner - 0.04, Hs - 0.4)),
                   ((-inner + 0.04, inner - 0.04, 0.6), (inner - 0.04, inner, Hs - 0.4))):   # proud of the tower faces
        mb.box(lo, hi, "ink_hi", part="Lining")
    # deposit-box door grid on the three outer faces: raised steel_hi lines (one shell each), 1.25 x 1.0 cells
    rows = [0.6 + 1.05 * r for r in range(7)]                        # 6 rows of doors, z 0.6 .. 6.9
    def grid(axis, fixed, a0, a1, out):
        n = max(1, round((a1 - a0) / 1.25))
        cols = [a0 + (a1 - a0) * c / n for c in range(n + 1)]
        f0, f1 = (fixed - 0.02, fixed + 0.04) if out > 0 else (fixed - 0.04, fixed + 0.02)   # 0.02 buried in the face
        for c in cols[1:-1]:
            lo = (f0, c - 0.04, rows[0]) if axis == "x" else (c - 0.04, f0, rows[0])
            hi = (f1, c + 0.04, rows[-1] - 0.4) if axis == "x" else (c + 0.04, f1, rows[-1] - 0.4)
            mb.box(lo, hi, "steel_hi", part="GridV")
        for z in rows[1:-1]:
            lo = (f0, a0 + 0.1, z - 0.04) if axis == "x" else (a0 + 0.1, f0, z - 0.04)
            hi = (f1, a1 - 0.1, z + 0.04) if axis == "x" else (a1 - 0.1, f1, z + 0.04)
            mb.box(lo, hi, "steel_hi", part="GridH")
        return cols
    grid("x", -S, -S, inner, -1)
    grid("x", S, -S, inner, 1)
    grid("y", S, -S, S, 1)
    # three little doors hanging open on the front edges of the towers: someone has been here
    for x0, z0 in ((-S + 0.12, 3.75), (inner + 0.1, 2.7), (inner + 0.1, 5.85)):
        d = mb.box((x0, -S - 0.05, z0), (x0 + 0.72, -S + 0.01, z0 + 0.78), "steel", part="OpenDoor")
        mb.rotate(d, -15 if x0 < 0 else 15, "Z", (x0 if x0 < 0 else x0 + 0.72, -S, z0))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Hide_DepositStack", [k.Obj(ob, "module", role="env", pivot="point", collision="Box", can_collide=False,
                                               tags=["EH_Hide"], extra={"niche": {"x": [-2.05, 2.05], "z": [-3.0, 2.05]}},
                                               sim="hide: L6 WestStack / EastStack 6 x 6; niche X -2.05..2.05, Z -3..2.05, open on -Z, "
                                                   "centre = plate centre",
                                               notes="origin = niche centre on the floor; walk-in: CanCollide off; open side faces -Z (Roblox)")],
                   notes="Hide spot: a U of steel deposit-box towers (6 x 6 x 7), dark lined niche over the plate, three doors left open.")


def build(k):
    return [crate(k), plant(k), curtain(k), coat_rack(k), coat_stand(k), deposit_stack(k)]
