"""Kit furniture (launch kit modules): Floor_8x8, Counter_4x4, Counter_8x4, Shelf_8x2, Lamp_Ceiling (+ bulb),
TellerCounter_8x4 (+ glass). Shared by Corner Shop, Toy Shop and Bank through the atlas swap (wood_* and floor_*
are location cells: pine in the shop, mahogany in the bank).

Build: python3 tools/blender/build_asset.py assets/blender/furniture.py
Rules: 4-stud grid footprints, origin = the footprint's front-bottom-left grid corner (the floor's origin is its
TOP front-left corner, so a floor tile placed at y = 0 has its walking surface on y = 0). Every surface loot may
sit on is dark (STYLE_BIBLE 1.3 display rule): counter tops and shelf boards are wood_lo, never marble.
LevelSpec: counters are `solids` with sight = false (3.5 tall, Gus sees over them: Shop.luau uses 3.5).
"""
import math, random


# ---------------------------------------------------------------- floor

def floor(k):
    mb = k.MB("Floor_8x8")
    for i in range(2):
        for j in range(2):
            col = "floor_a" if (i + j) % 2 == 0 else "floor_b"
            mb.box((4 * i, 4 * j, -0.5), (4 * i + 4, 4 * j + 4, 0.0), col, chamfer=0.07, cham_col="ink",
                   flat=("-z",), part=f"Tile_{i}{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Floor_8x8", [k.Obj(ob, "module", role="env", symmetric="XY", pivot="point", expect_dims=(8, 8, 0.5),
                                       collision="Box", tags=["EH_Floor"], sim="floor (walking surface y = 0)",
                                       notes="origin = TOP front-left corner; the 4-stud checker is the planning grid")],
                   tile_x=8.0, notes="Floor 8x8: four 4x4 tiles (checker floor_a / floor_b), grout chamfers in Ink; top at y = 0.")


# ---------------------------------------------------------------- counters

def counter(k, W):
    name = f"Counter_{int(W)}x4"
    D, Hc = 4.0, 3.5
    mb = k.MB(name)
    mb.box((0.25, 0.3, 0.0), (W - 0.25, D - 0.3, 0.45), "ink", chamfer=0.07, cham_col="ink_hi", flat=("-z", "+z"), part="Kick")
    mb.box((0.0, 0.15, 0.45), (W, D - 0.15, 3.2), "wood", chamfer=0.12, cham_col="wood_hi", flat=("+z",), part="Body")
    for i in range(int(W // 4)):
        cx = 4 * i + 2
        mb.box((cx - 1.45, 0.02, 0.85), (cx + 1.45, 0.2, 2.8), "wood", chamfer=0.07, cham_col="wood_hi", flat=("+y",),
               part=f"Panel_{i}")
        # clerk side: a dark open-shelf read (inset) and a drawer pull per cell
        mb.box((cx - 1.6, D - 0.2, 1.0), (cx + 1.6, D - 0.05, 2.6), "ink_hi", chamfer=0.05, cham_col="ink_hi", flat=("-y",),
               part=f"Recess_{i}")
        mb.box((cx - 0.5, D - 0.18, 2.8), (cx + 0.5, D + 0.02, 2.98), "steel_hi", chamfer=0.04, flat=("-y",), part=f"Pull_{i}")
    mb.box((-0.15, -0.15, 3.2), (W + 0.15, D + 0.15, Hc), "wood_lo", chamfer=0.08, cham_col="wood", flat=("-z",), part="Top")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset(name, [k.Obj(ob, "module", role="env", symmetric="X", pivot="point", expect_dims=(W + 0.3, D + 0.3, Hc),
                                collision="Box", tags=["EH_Counter"], sim="solid, sight = false (Gus sees over), 3.5 tall",
                                notes="front (-Y) = customer side; the dark top is a loot display")],
                   notes=f"Shop counter {int(W)}x4x3.5: raised front panels, dark display top, clerk-side recess and pulls.")


# ---------------------------------------------------------------- shelf

SHELF_Z = (0.45, 2.25, 4.05, 5.85)   # board tops (bottom board sits on the kick)
PRODUCT_COLS = ["marble", "plum_hi", "steel", "steel_hi", "marble_hi", "ink_hi", "wood_hi", "steel_lo"]


def shelf(k):
    W, D, Hs = 8.0, 2.0, 7.6
    mb = k.MB("Shelf_8x2")
    for x0 in (0.0, W - 0.3):
        mb.box((x0, 0.0, 0.0), (x0 + 0.3, D, Hs), "steel_lo", chamfer=0.07, cham_col="steel", flat=("-z",), part="Side")
    mb.box((0.3, D - 0.2, 0.0), (W - 0.3, D, Hs - 0.1), "ink_hi", part="Back")
    mb.box((0.3, 0.05, 0.0), (W - 0.3, D - 0.2, 0.3), "ink", part="Kick")
    mb.box((-0.05, -0.05, Hs - 0.05), (W + 0.05, D + 0.0, Hs + 0.25), "steel_lo", chamfer=0.07, cham_col="steel", part="Cap")
    rnd = random.Random(8)   # fixed seed: the same shelf every build (no generated randomness in the game)
    for zi, zt in enumerate(SHELF_Z):
        mb.box((0.3, 0.0, zt - 0.15), (W - 0.3, D - 0.2, zt), "wood_lo", part=f"Board_{zi}")
        mb.box((0.3, -0.08, zt - 0.32), (W - 0.3, 0.02, zt + 0.06), "marble", part=f"Strip_{zi}")   # price strip
        x = 0.45
        while x < W - 0.8:
            w = rnd.choice((0.55, 0.7, 0.9, 1.1))
            if x + w > W - 0.45:
                break
            h = rnd.choice((0.9, 1.1, 1.3)) if zi < 3 else rnd.choice((0.8, 1.0, 1.2))
            col = rnd.choice(PRODUCT_COLS)
            if rnd.random() < 0.3:   # cans: a short row of cylinders
                r = min(w, 0.7) / 2
                mb.cylinder((x + r, 0.75, zt), (0, 0, 1), r, 0.0, h * 0.8, 6, col, cap_col="steel_hi", part=f"Can_{zi}_{x:.1f}")
                x += 2 * r + 0.12
            else:
                d = rnd.choice((0.9, 1.2, 1.5))
                mb.box((x, 0.2, zt), (x + w, 0.2 + d, zt + h), col, part=f"Box_{zi}_{x:.1f}")
                x += w + 0.1
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Shelf_8x2", [k.Obj(ob, "module", role="env", pivot="point",
                                       collision="Box", tags=["EH_Shelf"], sim="solid (blocks sight: 7.85 tall)",
                                       notes="against a wall, back at y = 2; dark boards are loot displays (Clone Party)")],
                   notes="Wall shelving 8x2x7.85: steel sides, dark boards with marble price strips, fixed-seed products.")


# ---------------------------------------------------------------- lamp

def lamp(k):
    mb = k.MB("Lamp_Ceiling")
    top = 12.0
    mb.cylinder((0, 0, top), (0, 0, 1), 0.55, -0.18, 0.0, 16, "steel_lo", chamfer=0.05, cham_col="steel", part="Canopy")
    mb.cylinder((0, 0, 9.4), (0, 0, 1), 0.08, 0.0, top - 0.17 - 9.4, 6, "ink", part="Cord")
    prof = [(0.3, 9.85), (0.42, 9.55), (1.55, 8.75), (1.6, 8.62), (1.47, 8.62), (0.36, 9.42), (0.22, 9.48)]
    mb.lathe(prof, 20, ["steel_lo", "steel_lo", "steel_hi", "marble_hi", "marble_hi", "marble", "steel_lo"], (0, 0, 0),
             closed=True, part="Shade")
    mb.cylinder((0, 0, 9.4), (0, 0, 1), 0.3, 0.0, 0.5, 12, "steel_lo", chamfer=0.05, cham_col="steel", part="Collar")
    mb.cylinder((0, 0, 9.28), (0, 0, 1), 0.2, 0.0, 0.2, 10, "steel_lo", part="Socket")
    ob = k.finalize(mb, pivot=(0, 0, top))
    mbb = k.MB("Lamp_Ceiling_Bulb")
    mbb.sphere((0, 0, 8.95), 0.42, 12, 6, "white", part="Bulb")
    bb = k.finalize(mbb, pivot=(0, 0, top))
    return k.Asset("Lamp_Ceiling", [
        k.Obj(ob, "small", role="env", symmetric="XY", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
              tags=["EH_Lamp"], sim="none", notes="origin = top centre at the ceiling plane (y 12); hangs to y 8.62"),
        k.Obj(bb, "tiny", role="env", symmetric="XY", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, tint="Lamp warm #FFE2B8 (code); PointLight here, Shadows off",
              notes="Neon bulb; the light pool is a floor decal or disc (STYLE_BIBLE 3), not more lights"),
    ], seats=[("Lamp_Ceiling_Bulb", "Lamp_Ceiling")],
        notes="Pendant lamp: canopy on the cut-away ceiling plane, cord, enamel shade (light inside), Neon bulb part.")


# ---------------------------------------------------------------- teller counter (bank)

def teller(k):
    W, D, Hc = 8.0, 4.0, 4.0
    mb = k.MB("TellerCounter_8x4")
    mb.box((0.25, 0.3, 0.0), (W - 0.25, D - 0.3, 0.45), "ink", chamfer=0.07, cham_col="ink_hi", flat=("-z", "+z"), part="Kick")
    mb.box((0.0, 0.15, 0.45), (W, D - 0.15, 3.65), "wood", chamfer=0.12, cham_col="wood_hi", flat=("+z",), part="Body")
    for cx in (2.0, 6.0):
        mb.box((cx - 1.45, 0.02, 0.85), (cx + 1.45, 0.2, 3.2), "wood", chamfer=0.07, cham_col="wood_hi", flat=("+y",), part="Panel")
    mb.box((-0.15, -0.2, 3.65), (W + 0.15, D + 0.15, Hc), "marble", chamfer=0.08, cham_col="marble_hi", flat=("-z",), part="Top")
    # screen frame: three steel posts and a top rail; the glass is its own part
    for x0 in (0.15, W / 2 - 0.15, W - 0.45):
        mb.box((x0, 1.75, Hc), (x0 + 0.3, 2.05, 8.0), "steel", chamfer=0.06, cham_col="steel_hi", flat=("-z",), part="Post")
    mb.box((0.05, 1.7, 7.9), (W - 0.05, 2.1, 8.25), "steel", chamfer=0.07, cham_col="steel_hi", part="Rail")
    for cx in (2.0, 6.0):   # deal trays: the dark dip where cash passes under the glass
        mb.box((cx - 0.8, 1.2, Hc - 0.12), (cx + 0.8, 2.6, Hc + 0.02), "steel_lo", chamfer=0.04, cham_col="steel_lo", part="Tray")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    mg = k.MB("TellerCounter_8x4_Glass")
    for xa, xb in ((0.45, W / 2 - 0.15), (W / 2 + 0.15, W - 0.45)):
        mg.box((xa, 1.87, Hc + 0.7), (xb, 1.93, 7.9), "steel_hi")   # cell only for previews; Studio clears TextureID
    gl = k.finalize(mg, pivot=(0, 0, 0))
    return k.Asset("TellerCounter_8x4", [
        k.Obj(ob, "module", role="env", symmetric="X", pivot="point", collision="Box", tags=["EH_Counter"],
              sim="solid to 4 tall, sight = false (glass screen: Gus sees through)",
              notes="bank teller counter: marble top, steel screen posts; glass separate"),
        k.Obj(gl, "small", role="env", symmetric="X", pivot="point", collision="Box", material="Glass", can_collide=False,
              cast_shadow=False, atlas=False, transparency=0.6, tint="Vault Steel light #A9B2CC", free_shells=True,
              notes="Glass, Transparency 0.6, TextureID cleared"),
    ], seats=[("TellerCounter_8x4_Glass", "TellerCounter_8x4")],
        notes="Bank teller counter 8x4x8.25: counter to 4, marble top, screen with deal-tray gaps (glass part).")


def build(k):
    return [floor(k), counter(k, 4.0), counter(k, 8.0), shelf(k), lamp(k), teller(k)]
