"""Warm-pass street and floor dressing (golden-frame pass, PLAN_STEAM_PLUS 3.1 and 4.1 W5, docs/GOLDEN_FRAMES.md G1):
StreetLamp (+ StreetLamp_Bulb) and Rug_8x6.

Build: python3 tools/blender/build_asset.py assets/blender/street.py
Placed by the visual-only level dressing (src/server/Heist/LevelDress.luau `street` and `rugs`, Heist/KitPlan roles
"lamp" and "rug"): never colliders, clear of every plate, door, laser, hide, the van zone and low solids (unit spec).

StreetLamp (original design): a toy-town lamp post, 11 studs tall: a round ink plinth, a slim Vault Steel shade post
with a ladder bar, and a square lantern whose four open sides show the Bulb Warm Neon bulb. The bulb is the light's
home (Heist/LevelBuilder hangs a warm PointLight at the lantern and lays an unlit pool on the pavement): the warm
pools on the street that GOLDEN G1 asks for. Front -Y (Roblox -Z), origin bottom centre.

Rug_8x6: a burgundy rug with a cream border, a cream diamond and tasselled short ends, laid flat inside the warm light
pools (the warm floor patches of PLAN 3.1 W3). 0.03 thick, so the lamp pools (lift 0.06) still draw over it. Role
"story": comfort and storytelling props may use the Christmas reds (Ribbon), never loot gold or a signal colour.
"""
import math

LAMP_H = 11.0
LANTERN = (8.75, 10.35)        # lantern frame z range
BULB = (8.93, 9.93)            # Neon bulb z range (the light sits at its middle, Config.Lighting.LAMP.street.lightY)


def street_lamp(k):
    mb = k.MB("StreetLamp")
    # plinth, a waisted foot, the post, a collar under the lantern
    foot = [(0.0, 0.0), (0.62, 0.0), (0.62, 0.28), (0.5, 0.42), (0.34, 0.78), (0.24, 1.25), (0.0, 1.25)]
    mb.lathe(foot, 12, ["ink", "ink", "ink_hi", "ink", "ink", "ink"], (0, 0, 0), part="Foot")
    mb.cylinder((0, 0, 0), (0, 0, 1), 0.17, 1.2, 8.45, 10, "steel_lo", part="Post")
    collar = [(0.0, 8.4), (0.3, 8.4), (0.42, 8.6), (0.42, 8.75), (0.0, 8.75)]
    mb.lathe(collar, 12, ["steel_lo", "steel", "steel_lo", "steel_lo"], (0, 0, 0), part="Collar")
    # ladder bar (the lamplighter's rest): a thin bar through the post
    mb.box((-0.75, -0.07, 7.55), (0.75, 0.07, 7.7), "steel_lo", chamfer=0.03, cham_col="steel", part="LadderBar")
    # lantern: a floor plate, four corner posts, a roof plate, a pyramid cap and a ball finial
    z0, z1 = LANTERN
    mb.box((-0.62, -0.62, z0), (0.62, 0.62, z0 + 0.18), "ink_hi", chamfer=0.05, cham_col="steel_lo", part="LanternFloor")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * 0.5, sy * 0.5
            mb.box((x - 0.08, y - 0.08, z0 + 0.16), (x + 0.08, y + 0.08, z1 - 0.16), "ink_hi", part="LanternPost")
    mb.box((-0.7, -0.7, z1 - 0.18), (0.7, 0.7, z1), "ink_hi", chamfer=0.05, cham_col="steel_lo", part="LanternRoof")
    mb.lathe([(0.0, z1 - 0.01), (0.78, z1 - 0.01), (0.0, z1 + 0.5)], 4, ["steel_lo", "steel_lo"], (0, 0, 0),
             phase=math.pi / 4, part="Cap")
    mb.sphere((0, 0, z1 + 0.58), 0.12, 8, 4, "steel", part="Finial")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    mbb = k.MB("StreetLamp_Bulb")
    b0, b1 = BULB
    prof = [(0.0, b0), (0.2, b0), (0.3, b0 + 0.25), (0.3, b1 - 0.3), (0.16, b1 - 0.05), (0.0, b1)]
    mbb.lathe(prof, 10, "white", (0, 0, 0), part="Bulb")
    bulb = k.finalize(mbb, pivot=(0, 0, 0))
    return k.Asset("StreetLamp", [
        k.Obj(ob, "small", role="env", symmetric="X", pivot="bottom", collision="Box", can_collide=False,
              cast_shadow=True, tags=["EH_StreetLamp"], sim="none",
              extra={"light": [0, (BULB[0] + BULB[1]) / 2, 0]},
              notes="toy-town lamp post; visual only on the pavement; the light hangs at the lantern (manifest light)"),
        k.Obj(bulb, "tiny", role="env", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, tint="Bulb Warm #F6C0A2 (eh_palette.NEON); PointLight here, same colour, Shadows off",
              notes="the lantern's bulb: Neon Bulb Warm, seen through the four open sides"),
    ], seats=[("StreetLamp_Bulb", "StreetLamp")],
        notes="Street lamp 1.56 x 1.56 x 11: ink plinth, slim post, ladder bar, open lantern with a warm Neon bulb.")


def rug(k):
    mb = k.MB("Rug_8x6")
    W, D = 4.0, 3.0      # half sizes
    B = 0.55             # border width
    mb.box((-W, -D, 0.0), (W, D, 0.012), "marble_lo", part="Border")
    mb.box((-W + B, -D + B, 0.014), (W - B, D - B, 0.022), "ribbon", part="Field")
    # a cream diamond and an inner ribbon-light lozenge, each a hair above the last (no shared planes)
    dia = [(0.0, -1.55), (2.2, 0.0), (0.0, 1.55), (-2.2, 0.0)]
    mb.prism(dia, "Z", 0.024, 0.03, "marble", "marble", part="Diamond")
    inner = [(0.0, -0.8), (1.1, 0.0), (0.0, 0.8), (-1.1, 0.0)]
    mb.prism(inner, "Z", 0.032, 0.036, "ribbon_hi", "ribbon_hi", part="Lozenge")
    # tassels on the short ends (on the floor)
    n = 9
    for sx in (-1, 1):
        for i in range(n):
            y = -D + 0.35 + i * (2 * D - 0.7) / (n - 1)
            x0, x1 = (W, W + 0.32) if sx > 0 else (-W - 0.32, -W)
            mb.box((x0, y - 0.07, 0.0), (x1, y + 0.07, 0.01), "marble_hi", part=f"Tassel{sx}_{i}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Rug_8x6", [
        k.Obj(ob, "small", role="story", symmetric="X", pivot="bottom", collision="Box", can_collide=False,
              cast_shadow=False, sim="none", on_floor=True,
              notes="warm rug for the light pools: visual only, 0.036 thick (the pools at lift 0.06 draw over it)"),
    ], notes="Burgundy rug 8.64 x 6 with a cream border, diamond and tassels.")


def build(k):
    return [street_lamp(k), rug(k)]
