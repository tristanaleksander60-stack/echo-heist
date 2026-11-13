"""BIG buildings kit (PLAN_FIRST_PERSON 5 "BIG", 2026-11-13): the cheap shells that turn every heist building into a
3-5 storey block, the ceilings over the playable rooms, and the rooftop details.

Build: python3 tools/blender/build_asset.py assets/blender/tower.py
Placed by server Heist/TowerPlan via Heist/Overhead (the level's "Overhead" model) and by Heist/LobbyPlan (the
warehouse garage). Every piece is visual only: CanCollide, CanTouch and CanQuery off, CastShadow off (the ground
floor keeps today's light; a 50-stud facade casting the moon's shadow over the street would put the lot in the
filmic toe). Shells only: no interiors behind the windows (the glass is a plain Part: Neon Bulb Warm when lit, a dark
blue pane when not).

Facade_8x10 (wall-module convention, STYLE_BIBLE 5.1: x 0..8 along the face, y 0 the outer plane, +y inward, z up;
front -Y; origin the front-bottom-left corner): one storey bay. Facade_8x10_Body is the tintable wall slab (1.0 thick,
its outer face at y 0.3) with a 3.6 x 5.6 window opening; the runtime colour makes it brick, cream or stone per
location (Config.Big.STYLES). Facade_8x10 is the atlas trim: a string course at the floor line, a sill with snow, the
casings, a lintel with a keystone, a dark reveal round the opening and a white mullion cross. Facade_Curtain sits in
the same frame (same pivot): two drapes and a valance in front of a lit pane (role story: comfort reds).
Cornice_8: a crown cornice with dentils under thick snow (tiles along X). FireEscape_8x10: one storey of a fire
escape (a grated landing on brackets, railings, a stair to the landing above). Roof_WaterTank, Roof_Chimney,
Roof_Antenna: the roofline (origin bottom centre). Pediment_24: the Bank's temple front (origin bottom centre, front
-Y). Clock_6: the Bank's clock (a disc facing -Y, origin its back centre). Ceiling_8x8: a pressed-tin coffer tile
whose underside is the ceiling plane at the wall tops (origin its top front left corner like Floor_8x8; the visible
face is the bottom). Truss_8 and Railing_8: the warehouse garage's roof trusses and mezzanine railing (tile along X).
"""
import math

W, H = 8.0, 10.0                    # one facade bay
OPEN = dict(x0=2.2, x1=5.8, z0=2.6, z1=8.2)
FACE = 0.3                          # the body's outer face (trims project in front of it, toward -y)
BACK = 1.3


def facade(k):
    x0, x1, z0, z1 = OPEN["x0"], OPEN["x1"], OPEN["z0"], OPEN["z1"]
    mb = k.MB("Facade_8x10_Body")
    mb.box((0.0, FACE, 0.0), (x0, BACK, H), "white", part="JambL")
    mb.box((x1, FACE, 0.0), (W, BACK, H), "white", part="JambR")
    mb.box((x0, FACE, 0.0), (x1, BACK, z0), "white", part="Below")
    mb.box((x0, FACE, z1), (x1, BACK, H), "white", part="Above")
    body = k.finalize(mb, shading="flat", pivot=(0, 0, 0))

    mt = k.MB("Facade_8x10")
    # the string course at the floor line (tiles: flat ends)
    mt.box((0.0, -0.12, 0.0), (W, FACE + 0.05, 0.5), "marble_lo", chamfer=0.06, cham_col="marble", flat=("-x", "+x"),
           part="Course")
    # sill with a line of snow on it
    mt.box((x0 - 0.45, -0.35, z0 - 0.42), (x1 + 0.45, FACE + 0.05, z0), "marble", chamfer=0.07, cham_col="marble_hi",
           part="Sill")
    mt.box((x0 - 0.35, -0.3, z0), (x1 + 0.35, FACE - 0.05, z0 + 0.2), "snow", chamfer=0.06, cham_col="snow",
           part="SillSnow")
    # casings and the lintel with its keystone
    for xa, xb, nm in ((x0 - 0.42, x0 + 0.05, "CasingL"), (x1 - 0.05, x1 + 0.42, "CasingR")):
        mt.box((xa, 0.02, z0 + 0.2), (xb, FACE + 0.05, z1), "marble", chamfer=0.05, cham_col="marble_hi",
               flat=("+y",), part=nm)
    mt.box((x0 - 0.55, -0.12, z1 - 0.05), (x1 + 0.55, FACE + 0.05, z1 + 0.7), "marble", chamfer=0.07,
           cham_col="marble_hi", part="Lintel")
    mt.box((3.55, -0.25, z1 - 0.1), (4.45, FACE + 0.05, z1 + 0.95), "marble_hi", chamfer=0.07, cham_col="marble",
           part="Keystone")
    # the dark reveal round the opening (the depth read from the street and from first person)
    mt.box((x0, FACE, z0), (x0 + 0.14, 1.05, z1), "ink_hi", part="RevealL")
    mt.box((x1 - 0.14, FACE, z0), (x1, 1.05, z1), "ink_hi", part="RevealR")
    mt.box((x0 + 0.14, FACE, z0), (x1 - 0.14, 1.05, z0 + 0.14), "ink_hi", part="RevealB")
    mt.box((x0 + 0.14, FACE, z1 - 0.14), (x1 - 0.14, 1.05, z1), "ink_hi", part="RevealT")
    # the window frame: a mullion cross just in front of the pane (the pane is a Part at y 1.0)
    mt.box((3.92, 0.86, z0 + 0.14), (4.08, 1.0, z1 - 0.14), "marble_lo", part="Mullion")
    mt.box((x0 + 0.14, 0.86, 6.3), (3.92, 1.0, 6.46), "marble_lo", part="TransomL")
    mt.box((4.08, 0.86, 6.3), (x1 - 0.14, 1.0, 6.46), "marble_lo", part="TransomR")
    trim = k.finalize(mt, shading="flat", pivot=(0, 0, 0))

    mc = k.MB("Facade_Curtain")
    for s in (-1, 1):
        cx = 4.0 + s * 1.2          # each drape covers a third of the pane at its side
        a, b = (x0 + 0.14, 3.22) if s < 0 else (4.78, x1 - 0.14)
        mc.box((a, 0.74, z0 + 0.2), (b, 0.84, z1 - 0.5), "ribbon", part="Drape%d" % (s + 1))
        for f in range(3):           # folds: raised pleats
            fx = a + (b - a) * (f + 0.5) / 3
            mc.box((fx - 0.1, 0.68, z0 + 0.25), (fx + 0.1, 0.74, z1 - 0.55), "ribbon_hi", part="Fold%d_%d" % (s + 1, f))
        mc.box((cx - 0.5, 0.66, 4.5), (cx + 0.5, 0.74, 4.75), "marble", part="Tieback%d" % (s + 1))
    mc.box((x0 + 0.14, 0.64, z1 - 0.62), (x1 - 0.14, 0.84, z1 - 0.14), "ribbon_hi", part="Valance")
    curtain = k.finalize(mc, shading="flat", pivot=(0, 0, 0))
    return [
        k.Asset("Facade_8x10", [
            k.Obj(body, "module", role="env", symmetric="X", pivot="point", collision="Box", can_collide=False,
                  cast_shadow=False, atlas=False, sim="none", extra={"tintable": True},
                  tint="facade body: Config.Big.STYLES[location].body (runtime colour, a mid-to-high value)",
                  notes="one storey bay of an upper-floor shell: the tintable wall slab with its window opening"),
            k.Obj(trim, "module", role="xmas", symmetric="X", pivot="point", collision="Box", can_collide=False,
                  cast_shadow=False, sim="none", free_shells=True,
                  notes="the bay's trim: string course, sill + snow, casings, lintel + keystone, reveal, mullions"),
        ], seats=[("Facade_8x10", "Facade_8x10_Body")], tile_x=W,
            notes="Upper-floor facade bay 8 x 10 (shell, no interior); window 3.6 x 5.6; tiles along X."),
        k.Asset("Facade_Curtain", [
            k.Obj(curtain, "small", role="story", symmetric="X", pivot="point", collision="Box", can_collide=False,
                  cast_shadow=False, sim="none", free_shells=True,
                  notes="curtains in a lit window (Facade_8x10 frame, same pivot): drapes, pleats, tiebacks, valance"),
        ], notes="Window curtains for the facade bay (role story: the comfort reds)."),
    ]


def cornice(k):
    mb = k.MB("Cornice_8")
    # profile (y, z): outward is -y. Fascia, bed mould, corona with a drip, the top running back into the wall.
    prof = [(BACK, 0.0), (BACK, 1.6), (-1.45, 1.6), (-1.45, 1.42), (-1.3, 1.32), (-1.3, 0.86), (-0.5, 0.74),
            (-0.5, 0.52), (-0.12, 0.34), (-0.12, 0.0)]
    cols = ["marble_lo", "marble", "marble_hi", "marble", "marble", "marble_lo", "marble", "marble_lo", "marble",
            "marble_lo"]
    mb.prism(prof, "X", 0.0, W, cols, "marble_lo", part="Profile")
    for i in range(8):
        mb.box((i + 0.25, -0.98, 0.56), (i + 0.75, -0.48, 0.86), "marble_hi", part="Dentil%d" % i)
    mb.box((0.0, -1.5, 1.58), (W, BACK, 1.98), "snow", chamfer=0.1, cham_col="snow", flat=("-x", "+x", "-z"),
           part="Snow")
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("Cornice_8", [
        k.Obj(ob, "module", role="xmas", symmetric="X", pivot="point", collision="Box", can_collide=False,
              cast_shadow=False, sim="none",
              notes="crown cornice with dentils under thick snow; tiles along X on the facade's top"),
    ], tile_x=W, notes="Cornice 8 long, 1.45 proud, 2 tall with its snow (BIG buildings).")


def fire_escape(k):
    mb = k.MB("FireEscape_8x10")
    out = -3.0
    # the landing: a grate on two brackets
    mb.box((0.3, out, 0.0), (7.7, 0.0, 0.25), "steel_lo", chamfer=0.05, cham_col="steel", part="Landing")
    for bx in (1.0, 7.0):
        mb.box((bx - 0.12, out + 0.3, -1.4), (bx + 0.12, 0.0, 0.0), "ink_hi", part="Bracket%d" % int(bx))
    # railings: posts, a top rail and a mid rail on the three open sides
    posts = [(0.3, out), (2.8, out), (5.2, out), (7.7, out), (0.3, -1.5), (7.7, -1.5)]
    for i, (px, py) in enumerate(posts):
        xa = px if px < 4 else px - 0.2
        ya = py if py < -0.1 else py - 0.2
        mb.box((xa, ya, 0.25), (xa + 0.2, ya + 0.2, 3.2), "ink_hi", part="Post%d" % i)
    mb.box((0.3, out, 3.2), (7.7, out + 0.22, 3.42), "ink_hi", part="RailFront")
    mb.box((0.3, out, 1.8), (7.7, out + 0.16, 1.96), "ink_hi", part="MidFront")
    for xa in (0.3, 7.48):
        mb.box((xa, out + 0.22, 3.2), (xa + 0.22, 0.0, 3.42), "ink_hi", part="RailSide%d" % int(xa))
    # the stair to the next landing: two stringers and treads, rising toward -x inside the landing's depth
    run, rise = 5.4, 9.75
    L = math.hypot(run, rise)
    ang = math.degrees(math.atan2(rise, run))
    for y0 in (-2.7, -1.15):
        vs = mb.box((0.0, y0, -0.15), (L, y0 + 0.16, 0.15), "steel_lo", part="Stringer")
        mb.rotate(vs, ang, axis="Y")                       # descends toward +x from the top end
        mb.move(vs, (6.9 - run, 0.0, 0.25 + rise))
    for t in range(1, 8):
        u = t / 8
        tx = 6.9 - run * u
        tz = 0.25 + rise * u
        mb.box((tx - 0.32, -2.66, tz - 0.08), (tx + 0.32, -1.02, tz + 0.06), "steel", part="Tread%d" % t)
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("FireEscape_8x10", [
        k.Obj(ob, "module", role="env", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
              sim="none", free_shells=True,
              notes="one storey of a fire escape on the facade: landing, brackets, railings, a stair up"),
    ], notes="Fire escape storey 8 x 3 x 10 (BIG buildings, the Corner Shop tenement).")


def water_tank(k):
    mb = k.MB("Roof_WaterTank")
    r, z0, z1 = 2.8, 3.6, 9.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.box((sx * 1.9 - 0.25, sy * 1.9 - 0.25, 0.0), (sx * 1.9 + 0.25, sy * 1.9 + 0.25, z0 + 0.05), "ink_hi",
                   part="Leg")
    mb.box((-2.4, -2.4, z0 - 0.35), (2.4, 2.4, z0), "steel_lo", part="Deck")
    mb.cylinder((0, 0, 0), (0, 0, 1), r, z0, z1, 16, "wood", cap_col="wood_lo", part="Tank")
    for hz in (z0 + 1.2, z0 + 3.4, z0 + 5.4):
        mb.cylinder((0, 0, 0), (0, 0, 1), r + 0.08, hz, hz + 0.22, 16, "steel_lo", part="Hoop")
    mb.lathe([(0.0, z1 + 2.0), (r + 0.35, z1 - 0.05), (0.0, z1 - 0.05)], 16, ["steel_lo", "steel_lo"], (0, 0, 0),
             part="Roof")
    mb.lathe([(0.0, z1 + 2.2), (r * 0.9, z1 + 0.35), (r * 0.75, z1 + 0.25), (0.0, z1 + 0.6)], 16,
             ["snow", "snow", "snow"], (0, 0, 0), part="Snow")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Roof_WaterTank", [
        k.Obj(ob, "small", role="xmas", symmetric="XY", pivot="bottom", collision="Box", can_collide=False,
              cast_shadow=False, sim="none",
              notes="rooftop water tank on legs with a snowy conical roof (the tenement roofline)"),
    ], notes="Water tank 6.4 x 6.4 x 11.8 (BIG buildings rooftop).")


def chimney(k):
    mb = k.MB("Roof_Chimney")
    mb.box((-1.2, -1.2, 0.0), (1.2, 1.2, 4.6), "plum_hi", chamfer=0.08, cham_col="plum_hi", flat=("-z",), part="Stack")
    mb.box((-1.45, -1.45, 4.6), (1.45, 1.45, 5.1), "marble_lo", chamfer=0.08, cham_col="marble", part="Cap")
    mb.box((-1.35, -1.35, 5.1), (1.35, 1.35, 5.45), "snow", chamfer=0.1, cham_col="snow", part="Snow")
    for sx in (-0.55, 0.55):
        mb.cylinder((sx, 0, 0), (0, 0, 1), 0.32, 5.1, 6.2, 10, "steel", cap_col="ink", part="Pot")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Roof_Chimney", [
        k.Obj(ob, "small", role="xmas", symmetric="X", pivot="bottom", collision="Box", can_collide=False,
              cast_shadow=False, sim="none", notes="brick chimney stack with a marble cap, snow and two pots"),
    ], notes="Chimney 2.9 x 2.9 x 6.2 (BIG buildings rooftop; brick = the location's light wall cell).")


def antenna(k):
    mb = k.MB("Roof_Antenna")
    mb.box((-0.5, -0.5, 0.0), (0.5, 0.5, 0.3), "ink_hi", part="Foot")
    mb.cylinder((0, 0, 0), (0, 0, 1), 0.16, 0.3, 9.0, 6, "steel_lo", part="Mast")
    for z, half in ((5.6, 2.2), (6.8, 1.8), (8.0, 1.3)):
        mb.box((-half, -0.1, z), (half, 0.1, z + 0.2), "steel_lo", part="Bar%d" % int(z))
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("Roof_Antenna", [
        k.Obj(ob, "tiny", role="env", symmetric="X", pivot="bottom", collision="Box", can_collide=False,
              cast_shadow=False, sim="none", notes="a rooftop TV antenna"),
    ], notes="Antenna 4.4 x 1 x 9 (BIG buildings rooftop).")


def pediment(k):
    mb = k.MB("Pediment_24")
    hw, rise, d = 12.0, 5.2, 1.6
    # the tympanum (set back) and the raking cornices round it
    mb.prism([(-hw + 1.0, 0.6), (hw - 1.0, 0.6), (0.0, rise - 0.5)], "Y", -0.1, d, "marble_lo", "marble_lo",
             part="Tympanum")
    mb.box((-hw - 0.4, -0.7, 0.0), (hw + 0.4, d, 0.6), "marble", chamfer=0.08, cham_col="marble_hi", part="Base")
    L = math.hypot(hw, rise) + 0.3
    ang = math.degrees(math.atan2(rise, hw))
    for s in (-1, 1):
        # a mirror pair: the left rake rises toward +x from the left eave, the right one is its mirror image
        lo, hi = ((0.0, -0.75, 0.0), (L, d, 0.7)) if s < 0 else ((-L, -0.75, 0.0), (0.0, d, 0.7))
        vs = mb.box(lo, hi, "marble", chamfer=0.08, cham_col="marble_hi", part="Rake%d" % (s + 1))
        mb.rotate(vs, -ang if s < 0 else ang, axis="Y")
        mb.move(vs, (s * (hw + 0.2), 0.0, 0.25))
        lo, hi = ((0.0, -0.8, 0.0), (L, d + 0.05, 0.32)) if s < 0 else ((-L, -0.8, 0.0), (0.0, d + 0.05, 0.32))
        vs = mb.box(lo, hi, "snow", chamfer=0.08, cham_col="snow", part="Snow%d" % (s + 1))
        mb.rotate(vs, -ang if s < 0 else ang, axis="Y")
        mb.move(vs, (s * (hw + 0.2), 0.0, 0.95))
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("Pediment_24", [
        k.Obj(ob, "module", role="xmas", symmetric="X", pivot="point", collision="Box", can_collide=False,
              cast_shadow=False, sim="none", free_shells=True,
              notes="the Bank's temple-front pediment with raking cornices under snow; the clock sits in it"),
    ], notes="Pediment 24.8 x 2.4 x 6.3 (BIG buildings: the Bank).")


def clock(k):
    mb = k.MB("Clock_6")
    r = 3.0
    mb.cylinder((0, 0, 0), (0, -1, 0), r + 0.35, 0.0, 0.5, 24, "marble", cap_col="marble_lo", part="Rim")
    mb.cylinder((0, 0, 0), (0, -1, 0), r, 0.5, 0.62, 24, "marble_hi", part="Face")
    for i in range(12):
        a = 2 * math.pi * i / 12
        big = i % 3 == 0
        x, z = math.sin(a) * (r - 0.45), math.cos(a) * (r - 0.45)
        hs = 0.22 if big else 0.12
        vs = mb.box((x - hs, -0.72, z - (0.42 if big else 0.25)), (x + hs, -0.6, z + (0.42 if big else 0.25)), "ink",
                    part="Tick%d" % i)
        mb.rotate(vs, -math.degrees(a), axis="Y", centre=(x, 0, z))
    for ln, ang, w in ((1.7, -60.0, 0.24), (2.4, 10.0, 0.16)):   # ten past ten
        vs = mb.box((-w / 2, -0.82, -0.3), (w / 2, -0.62, ln), "ink", part="Hand")
        mb.rotate(vs, ang, axis="Y")
    mb.cylinder((0, 0, 0), (0, -1, 0), 0.3, 0.62, 0.86, 10, "steel", part="Boss")
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("Clock_6", [
        k.Obj(ob, "small", role="env", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
              sim="none", free_shells=True, notes="the Bank's clock: marble face, ink ticks and hands at ten past ten"),
    ], notes="Clock 6.7 across, facing -Y, origin the back centre (BIG buildings: the Bank).")


def ceiling(k):
    mb = k.MB("Ceiling_8x8")
    # Blender: x 0..8, y 0..8, the underside z = 0 is the ceiling plane at the wall tops; coffers recess 0.25
    mb.box((0.0, 0.0, 0.25), (8.0, 8.0, 0.55), "marble_lo", flat=("-x", "+x", "-y", "+y"), part="Plate")
    for i, (a, b) in enumerate(((0.0, 0.35), (3.82, 4.18), (7.65, 8.0))):
        mb.box((a, 0.0, 0.0), (b, 8.0, 0.25), "marble", flat=("-y", "+y", "+z"), part="BeamX%d" % i)
    for i, (a, b) in enumerate(((0.0, 0.35), (3.82, 4.18), (7.65, 8.0))):
        for j, (c, d) in enumerate(((0.35, 3.82), (4.18, 7.65))):
            mb.box((c, a, 0.04), (d, b, 0.25), "marble", flat=("-x", "+x", "+z"), part="BeamY%d_%d" % (i, j))
    for cx in (2.09, 5.91):
        for cy in (2.09, 5.91):
            mb.box((cx - 0.7, cy - 0.7, 0.13), (cx + 0.7, cy + 0.7, 0.25), "marble_hi", chamfer=0.04,
                   cham_col="marble", flat=("+z",), part="Boss")
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0.55))
    return k.Asset("Ceiling_8x8", [
        k.Obj(ob, "module", role="env", symmetric="XY", pivot="point", collision="Box", can_collide=False,
              cast_shadow=False, sim="none", free_shells=True,
              notes="pressed-tin ceiling tile: the underside is the ceiling plane on the wall tops (y 12)"),
    ], notes="Ceiling tile 8 x 8 x 0.55, coffered underside (BIG buildings: first person never sees sky indoors).")


def truss(k):
    mb = k.MB("Truss_8")
    h, t = 4.0, 0.35
    mb.box((0.0, -t, 0.0), (8.0, t, 0.4), "steel_lo", flat=("-x", "+x"), part="Bottom")
    mb.box((0.0, -t, h - 0.4), (8.0, t, h), "steel_lo", flat=("-x", "+x"), part="Top")
    Ld = math.hypot(4.0, h - 0.8)
    a = math.degrees(math.atan2(h - 0.8, 4.0))
    for s, lo, hi in ((-1, (0.0, -0.18, -0.15), (Ld, 0.18, 0.15)), (1, (-Ld, -0.18, -0.15), (0.0, 0.18, 0.15))):
        vs = mb.box(lo, hi, "steel", part="Diag%d" % (s + 1))
        mb.rotate(vs, -a if s < 0 else a, axis="Y")
        mb.move(vs, (0.0 if s < 0 else 8.0, 0.0, 0.4))
    mb.box((3.82, -0.2, 0.4), (4.18, 0.2, h - 0.4), "steel", part="Post")
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("Truss_8", [
        k.Obj(ob, "module", role="env", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
              sim="none", free_shells=True, notes="a Warren roof truss segment for the warehouse garage; tiles along X"),
    ], notes="Truss segment 8 x 0.7 x 4 (the warehouse garage's roof).")


def railing(k):
    mb = k.MB("Railing_8")
    mb.box((0.0, -0.12, 3.3), (8.0, 0.12, 3.6), "steel_lo", flat=("-x", "+x"), part="Rail")
    mb.box((0.0, -0.08, 1.7), (8.0, 0.08, 1.86), "steel_lo", flat=("-x", "+x"), part="Mid")
    mb.box((0.0, -0.1, 0.0), (8.0, 0.1, 0.3), "ink_hi", flat=("-x", "+x"), part="Kick")
    for x in (0.0, 4.0):
        mb.box((x, -0.12, 0.3), (x + 0.24, 0.12, 3.3), "steel_lo", part="Post%d" % int(x))
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Asset("Railing_8", [
        k.Obj(ob, "module", role="env", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
              sim="none", free_shells=True, notes="mezzanine railing for the warehouse garage; tiles along X"),
    ], notes="Railing 8 x 0.24 x 3.6 (the warehouse garage's mezzanine).")


def build(k):
    return facade(k) + [cornice(k), fire_escape(k), water_tank(k), chimney(k), antenna(k), pediment(k), clock(k),
                        ceiling(k), truss(k), railing(k)]
