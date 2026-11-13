"""WORLD 2.0 town kit (docs/audit/LEVELS.md section 10, PLAN_STEAM_PLUS 3.1): Roof_Gable, Car_Parked (+ paint), Snowman.

Build: python3 tools/blender/build_asset.py assets/blender/town.py
Placed only by the client backdrop (Shared/Heist/TownPlan via Heist/Backdrop; templates published by server
Heist/BackdropKit): never colliders, never queried, no shadows, outside every playable lot (unit spec).

Roof_Gable: a snow-covered gable roof for the town's houses and workshops, authored at 10 x 8 (ridge along X) and
scaled per house by MeshPart.Size (one mesh, instanced across the town). Dark tile underside and eaves, a Warm
Marble shade gable end (a Tudor gable), and a thick snow blanket with a lip over both slopes: from the diorama camera
the town's roofs are what you see most, so they are bright snow. Origin bottom centre, front -Y.

Car_Parked: a toy-town hatchback parked at the kerb with snow on its roof and bonnet: wheels, dark glass, lamps on the
atlas; the body panels are Car_Parked_Paint (the tint cell, MeshPart.Color set by the plan: mid-value paints, never a
clone hue or a signal colour). Origin bottom centre, front -Y (it parks along the road).

Snowman: three snowballs, a coal-black top hat, a burgundy scarf, stick arms, coal eyes and buttons and a stubby
nose: the town's storytelling prop (role story). Origin bottom centre, front -Y.
"""
import math

ROOF_W, ROOF_D, ROOF_RISE = 10.0, 8.0, 3.2
SNOW_T = 0.42


def roof(k):
    mb = k.MB("Roof_Gable")
    hd = ROOF_D / 2
    # the roof body: a gable prism along X (dark tiles below, a marble-shade gable end)
    mb.prism([(-hd, 0.0), (hd, 0.0), (0.0, ROOF_RISE)], "X", -ROOF_W / 2, ROOF_W / 2,
             ["ink", "steel_lo", "steel_lo"], "marble_lo", part="Roof")
    # the snow blanket: a chevron over both slopes, its inner edge on the tiles, a lip past the eaves and the ends
    c = ROOF_RISE * (1 - (hd - 0.35) / hd)
    left = [(-hd - 0.3, 0.0), (-hd + 0.35, c), (0.0, ROOF_RISE), (0.0, ROOF_RISE + SNOW_T)]
    right = [(-y, z) for y, z in reversed(left)]
    for name, poly in (("SnowL", left), ("SnowR", right)):
        mb.prism(poly, "X", -ROOF_W / 2 - 0.2, ROOF_W / 2 + 0.2, "snow", "snow", part=name)
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("Roof_Gable", [
        k.Obj(ob, "small", role="xmas", symmetric="X", pivot="bottom", collision="Box", can_collide=False,
              cast_shadow=False, sim="none",
              notes="town backdrop roof, scaled per house by MeshPart.Size (10 x 8 authored); visual only"),
    ], notes="Gable roof 10.4 x 8.6 x 3.6 under a snow blanket (WORLD 2.0 town, client backdrop only).")


CAR_L, CAR_W = 9.0, 4.2


def car(k):
    hl, hw = CAR_L / 2, CAR_W / 2
    mp = k.MB("Car_Parked_Paint")
    # lower body and the cabin (front -Y: the bonnet is the low part at -Y)
    mp.box((-hw, -hl, 0.75), (hw, hl, 2.05), "white", chamfer=0.32, cham_col="white", part="Body")
    mp.box((-hw + 0.25, -1.7, 2.05), (hw - 0.25, 2.6, 3.35), "white", chamfer=0.28, cham_col="white",
           taper=(0.86, 0.82), part="Cabin")
    paint = k.finalize(mp, pivot=(0, 0, 0))

    mb = k.MB("Car_Parked")
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.cylinder((sx * (hw - 0.35), sy * (hl - 1.75), 0.75), (1, 0, 0), 0.75, -0.3, 0.3, 10, "ink",
                        cap_col="steel_lo", part="Wheel")
    # dark glass on the cabin's four sides (a hair proud of the paint)
    mb.box((-hw + 0.48, -1.55, 2.2), (hw - 0.48, -1.35, 3.1), "steel_lo", part="Windscreen")
    mb.box((-hw + 0.5, 2.3, 2.2), (hw - 0.5, 2.5, 3.05), "steel_lo", part="RearWindow")
    for sx in (-1, 1):
        mb.box((sx * (hw - 0.27) - 0.1, -1.2, 2.25), (sx * (hw - 0.27) + 0.1, 2.15, 3.0), "steel_lo", part="SideWindow")
    # lamps and bumpers
    for sx in (-1, 1):
        mb.box((sx * (hw - 0.75) - 0.42, -hl - 0.06, 1.35), (sx * (hw - 0.75) + 0.42, -hl + 0.2, 1.75), "marble_hi",
               part="Headlamp")
        mb.box((sx * (hw - 0.6) - 0.35, hl - 0.2, 1.4), (sx * (hw - 0.6) + 0.35, hl + 0.06, 1.7), "ribbon",
               part="TailLamp")
    for sy in (-1, 1):
        mb.box((-hw + 0.1, sy * hl - 0.22, 0.6), (hw - 0.1, sy * hl + 0.22, 1.05), "steel", chamfer=0.1,
               cham_col="steel_hi", part="Bumper")
    # snow: a cushion on the roof, a drift on the bonnet and the boot
    mb.box((-hw + 0.55, -1.45, 3.33), (hw - 0.55, 2.35, 3.78), "snow", chamfer=0.18, cham_col="snow", part="RoofSnow")
    mb.box((-hw + 0.3, -hl + 0.3, 2.03), (hw - 0.3, -1.9, 2.3), "snow", chamfer=0.1, cham_col="snow", part="BonnetSnow")
    mb.box((-hw + 0.3, 2.75, 2.03), (hw - 0.3, hl - 0.3, 2.25), "snow", chamfer=0.08, cham_col="snow", part="BootSnow")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Car_Parked", [
        k.Obj(ob, "small", role="story", symmetric="X", pivot="point", collision="Box", can_collide=False,
              cast_shadow=False, sim="none", free_shells=True,
              notes="parked car: wheels, glass, lamps, bumpers and the snow on it; the paint is Car_Parked_Paint"),
        k.Obj(paint, "small", role="env", symmetric="X", pivot="point", collision="Box", can_collide=False,
              cast_shadow=False, atlas=False, free_shells=True, extra={"tintable": True},
              tint="car paint: a mid value by MeshPart.Color (Config.Backdrop.TOWN.CAR.colors)",
              notes="the body and cabin as one runtime-coloured part (no atlas)"),
    ], seats=[("Car_Parked_Paint", "Car_Parked"), ("Car_Parked", "Car_Parked_Paint")],
        notes="Parked hatchback 4.2 x 9 x 3.8 with snow on the roof, bonnet and boot (WORLD 2.0 town).")


def snowman(k):
    mb = k.MB("Snowman")
    balls = ((0.0, 1.36, 1.35), (0.0, 3.2, 1.0), (0.0, 4.75, 0.72))   # (x, z centre, r)
    for i, (x, z, r) in enumerate(balls):
        mb.sphere((x, 0.0, z), r, 10, 6, "snow", part=f"Ball{i}")
    hz = balls[2][1]
    # coal eyes and buttons, a stubby nose
    for sx in (-1, 1):
        mb.sphere((sx * 0.24, -0.64, hz + 0.18), 0.08, 6, 3, "ink", part="Eye")
    for i, z in enumerate((2.75, 3.2, 3.65)):
        mb.sphere((0.0, -math.sqrt(max(1.0 - (z - 3.2) ** 2, 0.0)) + 0.04, z), 0.1, 6, 3, "ink", part=f"Button{i}")
    mb.lathe([(0.0, 0.0), (0.14, 0.0), (0.0, 0.55)], 6, "wood_hi", (0.0, -0.66, hz - 0.02), axis=(0, -1, 0), part="Nose")
    # a top hat
    mb.cylinder((0, 0, hz + 0.55), (0, 0, 1), 0.68, 0.0, 0.1, 12, "ink", cap_col="ink_hi", part="Brim")
    mb.cylinder((0, 0, hz + 0.55), (0, 0, 1), 0.46, 0.1, 0.95, 12, "ink", cap_col="ink_hi", part="Crown")
    mb.cylinder((0, 0, hz + 0.55), (0, 0, 1), 0.475, 0.12, 0.3, 12, "ribbon", part="HatBand")
    # a burgundy scarf at the neck with one tail
    mb.lathe([(0.66, 4.0), (0.78, 4.1), (0.78, 4.32), (0.62, 4.4)], 12, "ribbon", (0, 0, 0), closed=True,
             part="Scarf")
    mb.box((0.25, -0.86, 3.35), (0.6, -0.68, 4.1), "ribbon_hi", part="ScarfTail")
    # stick arms
    for sx in (-1, 1):
        mb.cylinder((sx * 0.85, 0.0, 3.4), (sx * 0.8, 0.0, 0.6), 0.06, 0.0, 1.4, 5, "wood", part="Arm")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Snowman", [
        k.Obj(ob, "small", role="story", pivot="point", collision="Box", can_collide=False,
              cast_shadow=False, sim="none",
              notes="the town's snowman (storytelling prop, client backdrop only); visual only"),
    ], notes="Snowman 2.7 x 2.7 x 6.2: three snowballs, top hat, burgundy scarf, stick arms (WORLD 2.0 town).")


def build(k):
    return [roof(k), car(k), snowman(k)]
