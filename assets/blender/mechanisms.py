"""Kit mechanisms (launch kit props): Plate_4x4 (+ ring), Switch_Wall (+ lever, lamp), LaserEmitter (+ lens),
LaserEmitter_CandyCane (Christmas dressing layer: swaps the post, keeps the lens part).

Build: python3 tools/blender/build_asset.py assets/blender/mechanisms.py
Every state a mechanism shows is a runtime-tinted Neon part (TextureID cleared, Color set by code from the
server attribute): the plate ring (white idle, the presser's clone hue when held: MASTERPLAN 6.2 "steel plate
with a white icon that takes the presser's hue and glyph"), the switch lamp, the laser lenses (Alarm Red on,
Vault Steel shade off). The glyph (●1 ■2 ▲3 ◆4) is a Decal/SurfaceGui on the plate's centre disc, set by code.
LevelSpec: Plate_4x4 = Shop.plate(x, z) (4 x 4), the laser posts stand at both ends of a `lasers` box (beams
every 2 studs at y 1, 3, 5, 7, 9 cover the 10-stud box), Switch_Wall = a `switches` point (x, y, z at the lever).
"""
import math

BEAMS = (1.0, 3.0, 5.0, 7.0, 9.0)   # lens heights: beams every 2 studs cover the 10-stud LevelSpec laser box


# ---------------------------------------------------------------- plate

def plate(k):
    mb = k.MB("Plate_4x4")
    mb.box((-2.0, -2.0, 0.0), (2.0, 2.0, 0.3), "steel", chamfer=0.14, cham_col="steel_hi", flat=("-z",), part="Base")
    mb.cylinder((0, 0, 0.3), (0, 0, 1), 1.75, -0.02, 0.04, 32, "steel_lo", part="Groove")      # ring seat (dark)
    mb.cylinder((0, 0, 0.3), (0, 0, 1), 1.05, -0.02, 0.06, 24, "steel_lo", chamfer=0.03, cham_col="steel", part="Disc")
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.cylinder((1.55 * sx, 1.55 * sy, 0.3), (0, 0, 1), 0.14, -0.02, 0.06, 8, "steel_hi", part="Bolt")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    mr = k.MB("Plate_4x4_Ring")
    mr.lathe([(1.25, 0.28), (1.65, 0.28), (1.65, 0.38), (1.58, 0.42), (1.32, 0.42), (1.25, 0.38)], 24,
             "white", (0, 0, 0), closed=True, part="Ring")
    rg = k.finalize(mr, pivot=(0, 0, 0))
    return k.Asset("Plate_4x4", [
        k.Obj(ob, "small", role="env", symmetric="XY", pivot="bottom", expect_dims=(4, 4, 0.36), collision="Box",
              cast_shadow=False, tags=["EH_Plate"], sim="plate: Shop.plate(x, z) 4 x 4 trigger; walkable 0.3 step",
              notes="steel plate; the centre disc carries the presser's glyph (Decal / SurfaceGui by code); sinks 0.1 when held"),
        k.Obj(rg, "small", role="env", symmetric="XY", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, tint="Getaway White #F4F7FF idle; the presser's clone hue when held",
              notes="Neon ring, TextureID cleared, Color by code"),
    ], seats=[("Plate_4x4_Ring", "Plate_4x4")],
        notes="Pressure plate 4x4x0.36: chamfered steel slab (walk-on), dark ring seat, glyph disc; Neon ring part.")


# ---------------------------------------------------------------- wall switch

def switch(k):
    mb = k.MB("Switch_Wall")
    z0, z1 = 3.0, 5.4
    mb.box((-0.8, -0.7, z0), (0.8, 0.0, z1), "steel_lo", chamfer=0.1, cham_col="steel", flat=("+y",), part="Housing")
    mb.box((-0.62, -0.78, z0 + 0.2), (0.62, -0.62, z1 - 0.2), "steel", chamfer=0.05, cham_col="steel_hi", flat=("+y",), part="Face")
    mb.box((-0.14, -0.84, z0 + 0.45), (0.14, -0.74, z1 - 0.45), "ink", part="Slot")
    for sz in (z0 + 0.35, z1 - 0.35):
        for sx in (-0.45, 0.45):
            mb.cylinder((sx, -0.78, sz), (0, -1, 0), 0.07, -0.02, 0.05, 6, "steel_hi", part="Screw")
    mb.box((-0.35, -0.45, z1 - 0.02), (0.35, -0.05, z1 + 0.12), "steel", chamfer=0.04, cham_col="steel_hi", part="LampBase")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    hz = (z0 + z1) / 2
    ml = k.MB("Switch_Wall_Lever")
    ml.cylinder((0, -0.8, hz), (1, 0, 0), 0.16, -0.22, 0.22, 10, "steel", part="Hinge")
    rod = ml.cylinder((0, -0.8, hz), (0, 0, 1), 0.09, 0.0, 1.15, 8, "steel_hi", part="Rod")
    knob = ml.sphere((0, -0.8, hz + 1.3), 0.26, 10, 6, "ink_hi", part="Knob")
    ml.rotate(rod + knob, 35, "X", (0, -0.8, hz))       # "off" pose: tilted up and out; code rotates about X
    lv = k.finalize(ml, pivot=(0, -0.8, hz))
    mlp = k.MB("Switch_Wall_Lamp")
    mlp.sphere((0, -0.25, z1 + 0.12), 0.2, 10, 6, "white", part="Lamp")
    mlp.clip((0, 0, z1 + 0.12), (0, 0, 1), "white")
    lp = k.finalize(mlp, pivot=(0, -0.25, z1 + 0.12))
    return k.Asset("Switch_Wall", [
        k.Obj(ob, "small", role="env", symmetric="X", pivot="point", collision="Box", tags=["EH_Switch"],
              sim="none (a `switches` point at the lever: wall face, y 4.2)",
              notes="origin = floor level on the wall face; mounted 3.0-5.4 high, front faces into the room"),
        k.Obj(lv, "small", role="env", symmetric="X", pivot="point", collision="Box", can_collide=False,
              notes="origin = hinge axis; rotate about Roblox X: -35 deg off (up), +35 deg on (down)"),
        k.Obj(lp, "tiny", role="env", symmetric="XY", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, tint="Vault Steel shade #4E5675 off; the presser's clone hue on",
              notes="Neon state lamp, Color by code"),
    ], seats=[("Switch_Wall_Lever", "Switch_Wall"), ("Switch_Wall_Lamp", "Switch_Wall")],
        notes="Wall switch: steel housing with a lever (own pivot) and a Neon state lamp; mounted at hand height.")


# ---------------------------------------------------------------- laser emitters

def lens_part(k):
    ml = k.MB("LaserEmitter_Lens")
    for z in BEAMS:
        ml.cylinder((0, -1.0, z), (0, -1, 0), 0.2, 0.0, 0.16, 10, "white", part=f"Lens_{z:.0f}")
    return k.finalize(ml, pivot=(0, 0, 0))


def housings(mb):
    for z in BEAMS:
        mb.cylinder((0, -1.0, z), (0, -1, 0), 0.34, -0.05, 0.12, 10, "ink", part=f"Housing_{z:.0f}")


def emitter(k):
    mb = k.MB("LaserEmitter")
    mb.box((-0.7, -1.15, 0.0), (0.7, 0.0, 0.6), "ink", chamfer=0.1, cham_col="ink_hi", flat=("-z", "+y"), part="Plinth")
    mb.box((-0.55, -1.0, 0.6), (0.55, 0.0, 10.0), "steel_lo", chamfer=0.12, cham_col="steel", flat=("-z", "+z", "+y"), part="Post")
    mb.box((-0.7, -1.15, 10.0), (0.7, 0.0, 10.45), "ink", chamfer=0.1, cham_col="ink_hi", flat=("+y",), part="Cap")
    for z in (2.0, 4.0, 6.0, 8.0):   # steel bands between the lenses: rhythm that reads "machine", not "pole"
        mb.box((-0.6, -1.06, z - 0.12), (0.6, 0.0, z + 0.12), "steel", chamfer=0.04, cham_col="steel_hi", flat=("+y",), part="Band")
    housings(mb)
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("LaserEmitter", [
        k.Obj(ob, "small", role="danger", symmetric="X", pivot="point", collision="Box", tags=["EH_Laser"],
              sim="solid post 1.4 x 10.45 at the laser box's end; beams by code between facing lenses",
              notes="origin = floor level on the wall face (back of the post); lenses face -Y (across the room)"),
        k.Obj(lens_part(k), "small", role="danger", symmetric="X", pivot="point", collision="Box", material="Neon",
              can_collide=False, cast_shadow=False, atlas=False, free_shells=True,
              tint="Alarm Red #FF3838 on; Vault Steel shade #4E5675 off; 3 flickers before re-enabling (MASTERPLAN 6.5)",
              notes="5 Neon lenses; shared by LaserEmitter_CandyCane"),
    ], seats=[("LaserEmitter_Lens", "LaserEmitter")],
        notes="Laser emitter post (10.45 tall): ink plinth and cap, steel bands, 5 lens housings at y 1-9; Neon lens part.")


def candy_cane(k):
    """Christmas dressing: the same footprint and lens positions, a striped cane with a hook."""
    mb = k.MB("LaserEmitter_CandyCane")
    mb.box((-0.7, -1.15, 0.0), (0.7, 0.0, 0.6), "ink", chamfer=0.1, cham_col="ink_hi", flat=("-z", "+y"), part="Plinth")
    r, cy, top, segs = 0.52, -0.5, 9.8, 10
    rings = []
    zs = [0.6 + i * 0.4 for i in range(int(round((top - 0.6) / 0.4)) + 1)]
    for i, z in enumerate(zs):
        ph = i * math.pi / segs   # each ring turns half a segment: the faces follow the helix, so stripes are smooth
        rings.append([mb.v((r * math.cos(2 * math.pi * j / segs + ph), cy + r * math.sin(2 * math.pi * j / segs + ph), z))
                      for j in range(segs)])
    for i in range(len(rings) - 1):
        for j in range(segs):
            col = "ribbon" if (j // 2) % 2 == 0 else "marble_hi"   # helical stripes, 2 faces wide
            mb.f([rings[i][j], rings[i][(j + 1) % segs], rings[i + 1][(j + 1) % segs], rings[i + 1][j]], col)
    c0, c1 = mb.v((0, cy, zs[0])), mb.v((0, cy, zs[-1]))
    for j in range(segs):
        mb.f([c0, rings[0][(j + 1) % segs], rings[0][j]], "ribbon")
        mb.f([c1, rings[-1][j], rings[-1][(j + 1) % segs]], "ribbon")
    # hook: a tube along a half circle over the top (x 0 -> 1.9), stripes alternating per segment
    path, n = [], 8
    for i in range(n + 1):
        a = math.pi - math.pi * 1.15 * i / n
        path.append((0.95 + 0.95 * math.cos(a), cy, zs[-1] - 0.1 + 0.95 * math.sin(a)))
    import _kitlib as L
    L.tube(mb, path, r, segs, "ribbon",
                  cols=["ribbon" if i % 2 == 0 else "marble_hi" for i in range(n + 1)], cap_col="ribbon", part="Hook",
                  normal=(0, 1, 0))
    housings(mb)
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("LaserEmitter_CandyCane", [
        k.Obj(ob, "medium", role="xmas", pivot="point", collision="Box", layer="xmas", tags=["EH_Laser"],
              sim="as LaserEmitter (same footprint and lens heights)",
              notes="Christmas swap for the LaserEmitter post; keep the LaserEmitter_Lens part"),
    ], notes="Candy-cane laser post (Christmas layer): helical Ribbon / cream stripes, hook, same lens housings at y 1-9.")


def build(k):
    return [plate(k), switch(k), emitter(k), candy_cane(k)]
