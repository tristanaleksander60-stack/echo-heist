"""Kit street fronts (launch kit modules): Storefront_24x12 (+ glass), BankFront_24x12 and the entrance's security
shutter Shutter_8x10. Storefront = the street face of the Corner Shop and (atlas swap) the Toy Shop; BankFront =
Hoardsworth Bank's face (L6 and the bank dailies); Shutter_8x10 = the LOCKDOWN leaf of both 8 x 10 entrances
(L5 "Shutter", L6 "FrontDoors", DV09 "Shutter": LevelSpec door boxes with alarmLock).

Build: python3 tools/blender/build_asset.py assets/blender/storefront.py
Footprint 24 x 2 x 12 (6 grid cells). Front (-Y) = the street; the back (y = 2) is the plain interior wall.
Origin = front-bottom-left grid corner. The entrance is the 8 x 10 opening at Blender x 8-16 (Roblox local X -16..-8):
placed over x -12..12 it is the LevelSpec gap -4..4 of Shop.shell, with a Wall_4x12 on each side to the corners at
+-16 (the bank: a Wall_8x12 each side to +-20). The front (-Y) is the STREET: in a level whose street is at +Z the
module is yawed 180 deg, centred on the wall line (STYLE_BIBLE 5.2): pivot (-12, 0, zLine + 1). The entrance has
no hinged door: Shutter_8x10 drops in the wall's centre plane when the alarm locks it.
Street dressing: two display windows with striped awnings (Ink / Warm Marble: fixed colours, so they read on
every location's walls), and a dark sign board over the door. The shop name is a SurfaceGui on the board's front
face (code), never baked text: one mesh for every location and language.
"""
import _kitlib as L

W, H, D = 24.0, L.H, L.D
ENT = (8.0, 16.0, 10.0)            # entrance x0, x1, top
WINS = ((0.8, 7.2), (16.8, 23.2))   # display windows x ranges (6.4 wide: a real shop window, not a slot)
WZ = (2.2, 8.4)                     # display window z range
T = 0.1                             # reveal liner
CI = 0.32                           # casing depth


def casing(mb, x0, x1, z0, z1, sill=False):
    """Marble casing around an opening on both faces (stiles, head; a sill box or plinth blocks)."""
    for ya, yb in L.both_faces(0.0, CI):
        hid = "+y" if ya < 1 else "-y"
        zs = z0 + (0.05 if sill else 1.1)
        mb.box((x0 - 0.5, ya, zs), (x0, yb, z1), "marble", chamfer=0.07, cham_col="marble_hi", flat=(hid, "-z", "+z"), part="Stile")
        mb.box((x1, ya, zs), (x1 + 0.5, yb, z1), "marble", chamfer=0.07, cham_col="marble_hi", flat=(hid, "-z", "+z"), part="Stile")
        mb.box((x0 - 0.6, ya, z1), (x1 + 0.6, yb, z1 + 0.5), "marble", chamfer=0.08, cham_col="marble_hi", flat=(hid,), part="Head")
        if not sill:
            for xa, xb in ((x0 - 0.6, x0), (x1, x1 + 0.6)):
                mb.box((xa, ya - 0.03 if ya < 1 else ya, 0.0), (xb, yb + 0.03 if yb > 1 else yb, 1.1), "ink",
                       chamfer=0.07, cham_col="ink_hi", flat=("-z", hid), part="Plinth")
    if sill:
        for ya, yb in L.both_faces(-0.3, 0.35):
            mb.box((x0 - 0.45, ya, z0 - 0.3), (x1 + 0.45, yb, z0 + 0.05), "marble", chamfer=0.07, cham_col="marble_hi", part="Sill")


def awning(mb, x0, x1, n=7):
    """Striped awning over a display window: a slab sloping from the wall down to a front valance."""
    sect = [(0.0, 9.75), (-2.4, 8.7), (-2.4, 8.05), (-2.22, 8.05), (-2.22, 8.55), (0.0, 9.52)]   # (y, z)
    for i in range(n):
        xa, xb = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
        col = "marble" if i % 2 == 0 else "ink_hi"
        cols = [col, col, col, col, col, "ink"]    # the strip against the wall is hidden
        mb.prism(sect, "X", xa, xb, cols, col, part=f"Awning_{i}")
    # end caps of the awning frame (dark steel), so the stripes read as fabric on a frame
    for xa, xb in ((x0 - 0.12, x0), (x1, x1 + 0.12)):
        mb.prism([(0.0, 9.8), (-2.45, 8.72), (-2.45, 8.0), (-2.2, 8.0), (-2.2, 8.5), (0.0, 9.47)], "X", xa, xb,
                 "steel_lo", "steel_lo", part="AwningEnd")


# ---------------------------------------------------------------- security shutter (the LOCKDOWN leaf)

SH = dict(w=8.1, h=10.35, d=1.0, pitch=0.9)   # 0.05 into each liner; top hidden 0.35 inside the header; 1 thick =
                                              # the LevelSpec door box (wall line +- 0.5)


def shutter(k):
    mb = k.MB("Shutter_8x10")
    w, h, d, pitch = SH["w"], SH["h"], SH["d"], SH["pitch"]
    # corrugated section (y, z): trapezoid ribs on both faces. Edge colours follow the chamfer rule: faces turned
    # up are light, faces turned down dark, upright faces mid (the polygon runs up the front, down the back: CW)
    front = []
    z = 0.45
    while z + pitch <= h + 1e-6:
        front += [(-0.3, z), (-d / 2, z + 0.15), (-d / 2, z + pitch - 0.3), (-0.3, z + pitch - 0.15)]
        z += pitch
    front.append((-0.3, h))
    poly = front + [(-y, zz) for y, zz in reversed(front)]
    cols = []
    for i in range(len(poly)):
        (y0, z0), (y1, z1) = poly[i], poly[(i + 1) % len(poly)]
        nz = (y1 - y0)                        # CW polygon: outward normal (-dz, dy), so its z part is dy
        cols.append("steel_hi" if nz > 0.05 else ("steel_lo" if nz < -0.05 else "steel"))
    mb.prism(poly, "X", -w / 2, w / 2, cols, "steel_lo", part="Slats")
    # bottom bar with a pull handle on each face and a padlock hasp (street side)
    mb.box((-w / 2, -d / 2 - 0.05, 0.0), (w / 2, d / 2 + 0.05, 0.47), "ink_hi", chamfer=0.06, cham_col="steel_lo", flat=("-z", "-x", "+x"),
           part="BottomBar")
    for sy in (-1, 1):
        for sx in (-1, 1):
            mb.box((sx * 2.2 - 0.1, sy * (d / 2 + 0.04) - 0.06, 0.18), (sx * 2.2 + 0.1, sy * (d / 2 + 0.04) + 0.06, 0.62),
                   "steel_hi", part=f"Post{sx}{sy}")
        mb.box((-2.3, sy * (d / 2 + 0.16) - 0.07, 0.55), (2.3, sy * (d / 2 + 0.16) + 0.07, 0.69), "steel_hi", chamfer=0.03,
               part=f"Handle{sy}")
    mb.box((-0.22, -d / 2 - 0.2, 0.05), (0.22, -d / 2, 0.42), "steel", chamfer=0.04, cham_col="steel_hi", part="Lock")
    ob = k.finalize(mb, pivot=(0, 0, h))
    return k.Asset("Shutter_8x10", [k.Obj(ob, "small", role="env", symmetric="X", pivot="point", collision="Box", tags=["EH_Door"],
                                          sim="door: the 8 x 10 entrance box (wall line +- 0.5), solid when down",
                                          notes="origin = top centre, 0.35 inside the header; rolled up = Size.Y 0.35 with the top pinned "
                                                "(hidden in the header), CanCollide off; drop = tween Size.Y to 10.35")],
                   notes="Security shutter 8.1 x 10.35 x 1.0: steel ribs both faces, ink bottom bar, pull handles, padlock.")


# ---------------------------------------------------------------- bank front

BWIN = ((2.0, 5.0), (19.0, 22.0))   # tall barred windows
BWZ = (2.6, 8.6)
PIL = (0.7, 6.4, 16.4, 22.1)        # pilaster left edges (1.2 wide): two at the ends (inset), two flanking the door


def bank_front(k):
    mb = k.MB("BankFront_24x12")
    ex0, ex1, ez = ENT
    (a0, a1), (b0, b1) = BWIN
    z0, z1 = BWZ
    L.wall_run(mb, 0.0, a0, part="EndL")
    L.wall_run(mb, a1, ex0 - T, part="PostL")
    L.wall_run(mb, ex1 + T, b0, part="PostR")
    L.wall_run(mb, b1, W, part="EndR")
    for xa, xb in BWIN:
        L.wall_run(mb, xa, xb, 0.0, z0, top_col="marble", part="Below")
        L.wall_run(mb, xa, xb, z1, H, bottom_col="marble_lo", part="Above")
        casing(mb, xa, xb, z0, z1, sill=True)
        mb.box((xa, 0.82, z0), (xb, 1.18, z1), "ink_hi", part="DarkPane")          # the dark pane (no glass part)
        for i in range(1, 4):                                                     # security bars, both faces
            x = xa + (xb - xa) * i / 4
            for ya, yb in ((0.25, 0.45), (D - 0.45, D - 0.25)):
                mb.cylinder((x, (ya + yb) / 2, z0), (0, 0, 1), 0.08, -0.02, z1 - z0 + 0.02, 6, "steel", part=f"Bar_{xa}_{i}_{ya}")
    L.wall_run(mb, ex0 - T, ex1 + T, ez + T, H, bottom_col="steel_lo", part="Header")
    mb.box((ex0 - T, CI, 0.0), (ex0, D - CI, ez + T), "steel_lo", part="LinerL")
    mb.box((ex1, CI, 0.0), (ex1 + T, D - CI, ez + T), "steel_lo", part="LinerR")
    mb.box((ex0, CI, ez), (ex1, D - CI, ez + T), "steel_lo", part="LinerTop")
    casing(mb, ex0, ex1, 0.0, ez)
    # four marble pilasters on the street face (plinth on the baseboard line, capital under the crown)
    for x in PIL:
        mb.box((x, -0.42, 0.97), (x + 1.2, 0.05, 10.6), "marble", chamfer=0.1, cham_col="marble_hi", flat=("+y", "-z"), part="Pilaster")
        mb.box((x - 0.12, -0.55, 0.0), (x + 1.32, 0.05, 0.97), "ink", chamfer=0.08, cham_col="ink_hi", flat=("+y", "-z"), part="PilBase")
        mb.box((x - 0.15, -0.6, 10.6), (x + 1.35, 0.05, 11.0), "marble", chamfer=0.08, cham_col="marble_hi", flat=("+y",), part="PilCap")
    # name board in the frieze over the door (SurfaceGui "HOARDSWORTH & CO." by code) and a pediment on top
    mb.box((ex0 - 0.6, -0.5, 10.45), (ex1 + 0.6, 0.0, 11.85), "ink_hi", chamfer=0.06, cham_col="ink_hi", flat=("+y",), part="Board")
    for lo, hi in (((ex0 - 0.75, -0.62, 10.35), (ex1 + 0.75, -0.32, 10.6)), ((ex0 - 0.75, -0.62, 11.7), (ex1 + 0.75, -0.32, 11.95))):
        mb.box(lo, hi, "marble", chamfer=0.06, cham_col="marble_hi", flat=("+y",), part="BoardFrame")
    ped = [(6.2, 12.0), (17.8, 12.0), (12.0, 13.9)]
    mb.prism(ped, "Y", -0.5, 1.4, ["marble_lo", "marble_hi", "marble_hi"], "marble", part="Pediment")
    inner = [(7.4, 12.15), (16.6, 12.15), (12.0, 13.35)]
    mb.prism(inner, "Y", -0.56, -0.48, "plum_hi", "plum_hi", part="Tympanum")
    mb.cylinder((12.0, -0.56, 12.75), (0, -1, 0), 0.35, -0.02, 0.08, 12, "steel_hi", part="Medallion")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("BankFront_24x12", [
        k.Obj(ob, "medium", role="env", symmetric="X", pivot="point", collision="PreciseConvexDecomposition", tags=["EH_Wall"],
              sim="solid except the entrance local X -16..-8, Y 0-10 (8 x 10); pediment to 13.9 above the entrance",
              extra={"opening": {"x": [-16.0, -8.0], "y": [0.0, 10.0]}},
              notes="bank street front; PreciseConvexDecomposition keeps the entrance walkable; name SurfaceGui on the -Z face of the board"),
    ], tile_x=W, notes="Bank front 24x12: 8x10 entrance, marble pilasters, barred windows, name board and a pediment; no awnings.")


def storefront(k):
    mb = k.MB("Storefront_24x12")
    ex0, ex1, ez = ENT
    (a0, a1), (b0, b1) = WINS
    z0, z1 = WZ
    # wall runs around two windows and the entrance
    L.wall_run(mb, 0.0, a0, part="EndL")
    L.wall_run(mb, a1, ex0 - T, part="PostL")
    L.wall_run(mb, ex1 + T, b0, part="PostR")
    L.wall_run(mb, b1, W, part="EndR")
    for xa, xb in WINS:
        L.wall_run(mb, xa, xb, 0.0, z0, top_col="marble", part="Bulkhead")
        L.wall_run(mb, xa, xb, z1, H, bottom_col="marble_lo", part="Transom")
        casing(mb, xa, xb, z0, z1, sill=True)
        mb.box((xa, 0.82, z0), (xb, 1.18, z0 + 0.12), "ink_hi", part="GlassBead")
        mb.box(((xa + xb) / 2 - 0.1, 0.82, z0), ((xa + xb) / 2 + 0.1, 1.18, z1), "ink_hi", part="Mullion")
        awning(mb, xa - 0.45, xb + 0.45)
    L.wall_run(mb, ex0 - T, ex1 + T, ez + T, H, bottom_col="steel_lo", part="Header")
    mb.box((ex0 - T, CI, 0.0), (ex0, D - CI, ez + T), "steel_lo", part="LinerL")
    mb.box((ex1, CI, 0.0), (ex1 + T, D - CI, ez + T), "steel_lo", part="LinerR")
    mb.box((ex0, CI, ez), (ex1, D - CI, ez + T), "steel_lo", part="LinerTop")
    casing(mb, ex0, ex1, 0.0, ez)
    # sign board over the entrance (street face only): dark board, marble frame bars; the name is a SurfaceGui
    mb.box((ex0 - 0.8, -0.45, 10.55), (ex1 + 0.8, 0.0, 11.95), "ink_hi", chamfer=0.06, cham_col="ink_hi", flat=("+y",), part="Sign")
    for lo, hi in (((ex0 - 0.95, -0.6, 10.45), (ex1 + 0.95, -0.3, 10.7)), ((ex0 - 0.95, -0.6, 11.75), (ex1 + 0.95, -0.3, 12.0)),
                   ((ex0 - 0.95, -0.6, 10.7), (ex0 - 0.65, -0.3, 11.75)), ((ex1 + 0.65, -0.6, 10.7), (ex1 + 0.95, -0.3, 11.75))):
        mb.box(lo, hi, "marble", chamfer=0.06, cham_col="marble_hi", flat=("+y",), part="SignFrame")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    mg = k.MB("Storefront_24x12_Glass")
    for xa, xb in WINS:
        mg.box((xa, 0.97, z0 + 0.12), (xb, 1.03, z1), "steel_hi")   # cell only for previews; Studio clears TextureID
    gl = k.finalize(mg, pivot=(0, 0, 0))
    return k.Asset("Storefront_24x12", [
        k.Obj(ob, "medium", role="env", symmetric="X", pivot="point", collision="PreciseConvexDecomposition",
              tags=["EH_Wall"], sim="solid except the entrance local X -16..-8, Y 0-10 (8 x 10); awnings (street side, -Z) above 7.9",
              extra={"opening": {"x": [-16.0, -8.0], "y": [0.0, 10.0]}},
              notes="street front; PreciseConvexDecomposition keeps the entrance walkable; sign SurfaceGui on the -Z face of the board"),
        k.Obj(gl, "small", role="env", symmetric="X", pivot="point", collision="Box", material="Glass",
              can_collide=False, cast_shadow=False, atlas=False, transparency=0.6, tint="Vault Steel light #A9B2CC",
              free_shells=True, notes="Glass, Transparency 0.6, TextureID cleared"),
    ], tile_x=W, seats=[("Storefront_24x12_Glass", "Storefront_24x12")], notes="Storefront 24x12: 8x10 entrance (LevelSpec gap -4..4), 2 display windows with striped awnings, sign board.")


def build(k):
    return [storefront(k), bank_front(k), shutter(k)]
