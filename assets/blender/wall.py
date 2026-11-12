"""Kit walls (launch kit, golden module): Wall_4x12, Wall_8x12, Wall_Window_8x12, Wall_Door_8x12 (+ leaf),
Pillar_2x12. One mesh set for every location: Corner Shop, Toy Shop and Bank differ only by the atlas swap
(STYLE_BIBLE 1.1, location cells plum_*, floor_*, wood_*).

Build: python3 tools/blender/build_asset.py assets/blender/wall.py
Kit rules (STYLE_BIBLE 5.1): footprint W x 2 x 12 studs, W a multiple of 4. Origin = the grid corner at
front-bottom-left (x = 0, y = 0, z = 0); the module fills [0, W] x [0, 2] x [0, 12]; front faces -Y; both faces
are dressed. End faces at x = 0 and x = W are flat and identical, so modules tile (tile check).

Placement (STYLE_BIBLE 5.2, pass 2): EVERY wall module, shell or partition, is centred on its grid line (y = 1 on
the line), so the 2-thick kit wall covers the 1-thick LevelSpec wall box (line +- 0.5) on both faces; modules run
grid point to grid point and a 2 x 2 Pillar centred on each outside corner hides the joint. In Roblox axes a module
spans X [-W, 0] from its pivot (KIT_IMPORT pivot formulas). Doorways: Wall_Door_8x12 has a 6 x 10 opening (Blender
x 1-7, Roblox local X -7..-1), the LevelSpec door box of Shop.doorAt(z, -3, 3) when the module spans x -4..4. Its leaf is a pocket door: it slides 6 studs along -X into
the wall beside it (the leaf is 0.5 thick, inside the 1.4 core), so an open door never blocks the room.
"""
import _kitlib as L

H, D = L.H, L.D


def wall(k, W):
    name = f"Wall_{int(W)}x{int(H)}"
    mb = k.MB(name)
    L.wall_run(mb, 0.0, W, part="Section")
    L.panels(mb, 0.0, W)
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset(name, [k.Obj(ob, "module", role="env", symmetric="XY", pivot="corner", expect_dims=(W, D, H),
                                collision="Box", tags=["EH_Wall"], sim="solid",
                                notes="kit wall; Anchored")],
                   grid=(W, D, H, 4), tile_x=W,
                   notes=f"Kit wall {int(W)}x{int(D)}x{int(H)} on the 4-stud grid; origin = front-bottom-left grid corner; tiles along X.")


# ---------------------------------------------------------------- window

WIN = dict(x0=1.5, x1=6.5, z0=L.DADO[1], z1=9.85)   # glass opening (5 x 5), sill = the dado line


def window(k):
    W = 8.0
    mb = k.MB("Wall_Window_8x12")
    x0, x1, z0, z1 = WIN["x0"], WIN["x1"], WIN["z0"], WIN["z1"]
    L.wall_run(mb, 0.0, x0, part="JambL")
    L.wall_run(mb, x1, W, part="JambR")
    L.wall_run(mb, x0, x1, 0.0, z0, top_col="marble", part="Below")
    L.wall_run(mb, x0, x1, z1, H, bottom_col="marble_lo", part="Above")
    L.panels(mb, 0.0, W)
    for ya, yb in L.both_faces(-0.25, 0.35):
        # sill: deeper than the dado, it catches the light pool from the window (focal line)
        mb.box((x0 - 0.45, ya, z0 - 0.3), (x1 + 0.45, yb, z0 + 0.05), "marble", chamfer=0.07, cham_col="marble_hi",
               part="Sill")
    for ya, yb in L.both_faces(0.05, 0.35):
        hid = "+y" if ya < 1 else "-y"   # the face against the wall core is hidden: no chamfer there
        mb.box((x0 - 0.4, ya, z0 + 0.05), (x0 + 0.05, yb, z1), "marble", chamfer=0.06, cham_col="marble_hi",
               flat=(hid, "-z", "+z"), part="CasingL")
        mb.box((x1 - 0.05, ya, z0 + 0.05), (x1 + 0.4, yb, z1), "marble", chamfer=0.06, cham_col="marble_hi",
               flat=(hid, "-z", "+z"), part="CasingR")
        mb.box((x0 - 0.4, ya, z1 - 0.05), (x1 + 0.4, yb, z1 + 0.4), "marble", chamfer=0.06, cham_col="marble_hi",
               flat=(hid,), part="Head")
    # mullion cross (dark) and the two muntins: the "window" read at 64 px
    mb.box((3.9, 0.82, z0), (4.1, 1.18, z1), "ink_hi", part="Mullion")
    mb.box((x0, 0.82, 7.25), (x1, 1.18, 7.45), "ink_hi", part="Transom")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    mg = k.MB("Wall_Window_8x12_Glass")
    mg.box((x0, 0.97, z0), (x1, 1.03, z1), "steel_hi")   # cell only for previews; Studio clears TextureID
    gl = k.finalize(mg, pivot=(0, 0, 0))
    return k.Asset("Wall_Window_8x12", [
        k.Obj(ob, "module", role="env", symmetric="XY", pivot="point", expect_dims=(W, D + 0.5, H),
              collision="Box", tags=["EH_Wall"], sim="solid; Gus sees through the glass band Y 4.85-9.85",
              notes="window wall: blocks movement; glass is see-through for Gus (LevelSpec: no occluder there)"),
        k.Obj(gl, "small", role="env", symmetric="XY", pivot="point", collision="Box", material="Glass",
              can_collide=False, cast_shadow=False, atlas=False, transparency=0.6,
              tint="Vault Steel light #A9B2CC", notes="Glass, Transparency 0.6, TextureID cleared"),
    ], grid=None, tile_x=W,
        notes="Window wall 8x12: 5x5 opening on the dado line, marble sill and casing, glass as its own part.")


# ---------------------------------------------------------------- door frame + pocket leaf

DOOR = dict(x0=1.0, x1=7.0, z1=10.0, liner=0.1)


def door(k):
    W = 8.0
    mb = k.MB("Wall_Door_8x12")
    x0, x1, z1, t = DOOR["x0"], DOOR["x1"], DOOR["z1"], DOOR["liner"]
    L.wall_run(mb, 0.0, x0 - t, part="JambL")
    L.wall_run(mb, x1 + t, W, part="JambR")
    L.wall_run(mb, x0 - t, x1 + t, z1 + t, H, bottom_col="steel_lo", part="Header")
    # reveal liners (behind the casings): the opening is exactly 6 x 10 (LevelSpec door box), lined in dark steel
    ci = 0.32   # casing depth from each face
    mb.box((x0 - t, ci, 0.0), (x0, D - ci, z1 + t), "steel_lo", part="LinerL")
    mb.box((x1, ci, 0.0), (x1 + t, D - ci, z1 + t), "steel_lo", part="LinerR")
    mb.box((x0, ci, z1), (x1, D - ci, z1 + t), "steel_lo", part="LinerTop")
    for ya, yb in L.both_faces(0.0, 0.32):
        # casing: stiles, head and plinth blocks that continue the baseboard line
        mb.box((x0 - 0.55, ya, 1.1), (x0, yb, z1), "marble", chamfer=0.07, cham_col="marble_hi", flat=("-z",), part="CasingL")
        mb.box((x1, ya, 1.1), (x1 + 0.55, yb, z1), "marble", chamfer=0.07, cham_col="marble_hi", flat=("-z",), part="CasingR")
        mb.box((x0 - 0.7, ya, z1), (x1 + 0.7, yb, z1 + 0.6), "marble", chamfer=0.08, cham_col="marble_hi", part="Head")
        for xa, xb in ((x0 - 0.65, x0), (x1, x1 + 0.65)):
            mb.box((xa, ya - 0.03 if ya < 1 else ya, 0.0), (xb, yb + 0.03 if yb > 1 else yb, 1.1), "ink", chamfer=0.07,
                   cham_col="ink_hi", flat=("-z",), part="Plinth")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    # The leaf: wood slab, two raised panels per face, steel kick plate and push plate, lever handles.
    ml = k.MB("Wall_Door_8x12_Leaf")
    ly0, ly1 = 0.75, 1.25
    ml.box((x0, ly0, 0.02), (x1, ly1, z1 - 0.02), "wood", chamfer=0.07, cham_col="wood_hi", part="Slab")
    for ya, yb in ((ly0 - 0.1, ly0 + 0.05), (ly1 - 0.05, ly1 + 0.1)):
        hid = "+y" if ya < 1 else "-y"
        ml.box((x0 + 0.7, ya, 5.2), (x1 - 0.7, yb, 9.2), "wood", chamfer=0.06, cham_col="wood_hi", flat=(hid,), part="PanelHi")
        ml.box((x0 + 0.7, ya, 1.9), (x1 - 0.7, yb, 4.5), "wood", chamfer=0.06, cham_col="wood_hi", flat=(hid,), part="PanelLo")
        ml.box((x0 + 0.25, ya - 0.02 if ya < 1 else ya, 0.25), (x1 - 0.25, yb + 0.02 if yb > 1 else yb, 1.45),
               "steel", chamfer=0.05, cham_col="steel_hi", flat=(hid,), part="Kick")
    for side, y in ((-1, ly0), (1, ly1)):
        # lever handle on both faces: a rose plate and a bar pointing toward the hinge-free edge
        hz = 4.9
        ml.cylinder((x1 - 0.8, y, hz), (0, side, 0), 0.28, -0.02, 0.1, 12, "steel_hi", part="Rose")
        ml.cylinder((x1 - 0.8, y, hz), (0, side, 0), 0.09, 0.08, 0.4, 8, "steel_hi", part="Neck")
        ml.box((x1 - 1.6, y + side * 0.34 - 0.08, hz - 0.08), (x1 - 0.72, y + side * 0.34 + 0.08, hz + 0.08), "steel_hi",
               chamfer=0.03, part="Lever")
    lf = k.finalize(ml, pivot=(x0, (ly0 + ly1) / 2, 0.0))
    return k.Asset("Wall_Door_8x12", [
        k.Obj(ob, "module", role="env", symmetric="XY", pivot="point", expect_dims=(W, D + 0.06, H),
              collision="PreciseConvexDecomposition", tags=["EH_Wall"],
              sim="solid except the opening local X -7..-1, Y 0-10 (6 x 10)", extra={"opening": {"x": [-7.0, -1.0], "y": [0.0, 10.0]}},
              notes="door frame; PreciseConvexDecomposition so the 6 x 10 opening stays walkable"),
        k.Obj(lf, "small", role="env", symmetric="Y", pivot="point", collision="Box",
              tags=["EH_Door"], sim="door: solid when shut (LevelSpec door box)",
              notes="pocket leaf: origin = bottom of the hinge-side edge on the wall centre plane; open = slide 6 studs along -X"),
    ], grid=None, tile_x=W,
        notes="Door wall 8x12: 6x10 opening (LevelSpec door box), marble casing, plinth blocks on the baseboard line, pocket leaf.")


# ---------------------------------------------------------------- pillar (outside corners, exposed wall ends)

def pillar(k):
    S = 2.0
    mb = k.MB("Pillar_2x12")
    mb.box((0, 0, 0), (S, S, 0.97), "ink", chamfer=0.12, cham_col="ink_hi", flat=("-z",), part="Plinth")
    mb.box((0, 0, 0.97), (S, S, L.CROWN_Z), "plum", chamfer=0.25, cham_col="plum_hi", flat=("-z", "+z"), part="Shaft")
    mb.box((-0.1, -0.1, L.DADO[0]), (S + 0.1, S + 0.1, L.DADO[1]), "marble", chamfer=0.07, cham_col="marble_hi", part="Band")
    for side in ("-x", "+x", "-y", "+y"):   # raised panels on the upper shaft: the wall-panel language, vertical
        a, b = 0.4, S - 0.4
        lo = {"-x": (-0.08, a, 5.6), "+x": (S - 0.02, a, 5.6), "-y": (a, -0.08, 5.6), "+y": (a, S - 0.02, 5.6)}[side]
        hi = {"-x": (0.02, b, 10.2), "+x": (S + 0.08, b, 10.2), "-y": (b, 0.02, 10.2), "+y": (b, S + 0.08, 10.2)}[side]
        inner = {"-x": "+x", "+x": "-x", "-y": "+y", "+y": "-y"}[side]
        mb.box(lo, hi, "plum", chamfer=0.05, cham_col="plum_hi", flat=(inner,), part=f"Flute{side}")
    mb.box((-0.15, -0.15, L.CROWN_Z), (S + 0.15, S + 0.15, 11.8), "marble", chamfer=0.15, cham_col="marble_hi",
           flat=("+z",), part="Capital")
    mb.box((0.0, 0.0, 11.8), (S, S, H), "plum_hi", chamfer=0.12, cham_col="plum_hi", flat=("-z",), part="Cap")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Pillar_2x12", [
        k.Obj(ob, "module", role="env", symmetric="XY", pivot="point", collision="Box", tags=["EH_Wall"], sim="solid",
              notes="corner / end cap: outside corners of the shell; the band and capital overhang 0.1-0.15 to cap the trims")],
        notes="Pillar 2x2x12: fills the outside corner where two shell walls meet; continues baseboard, dado and crown lines.")


def build(k):
    return [wall(k, 4.0), wall(k, 8.0), window(k), door(k), pillar(k)]
