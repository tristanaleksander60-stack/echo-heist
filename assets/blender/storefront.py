"""Kit storefront (launch kit module): Storefront_24x12 (+ glass). The street face of the Corner Shop (and, through
the atlas swap, the Toy Shop and the bank lobby front).

Build: python3 tools/blender/build_asset.py assets/blender/storefront.py
Footprint 24 x 2 x 12 (6 grid cells). Front (-Y) = the street; the back (y = 2) is the plain interior wall.
Origin = front-bottom-left grid corner. The entrance is the 8 x 10 opening at x 8-16: placed at x -12..12 it is
the LevelSpec gap -4..4 of Shop.shell (no door leaf: the shop is open at night, the plates guard the back), with
a Wall_4x12 on each side to the corners at +-16.
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


def build(k):
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
              tags=["EH_Wall"], sim="solid except the entrance x 8-16, z 0-10 (8 x 10); awnings and sign above 7.9",
              notes="street front; PreciseConvexDecomposition keeps the entrance walkable; sign SurfaceGui on the -Z face of the board"),
        k.Obj(gl, "small", role="env", symmetric="X", pivot="point", collision="Box", material="Glass",
              can_collide=False, cast_shadow=False, atlas=False, transparency=0.6, tint="Vault Steel light #A9B2CC",
              free_shells=True, notes="Glass, Transparency 0.6, TextureID cleared"),
    ], tile_x=W, seats=[("Storefront_24x12_Glass", "Storefront_24x12")], notes="Storefront 24x12: 8x10 entrance (LevelSpec gap -4..4), 2 display windows with striped awnings, sign board.")
