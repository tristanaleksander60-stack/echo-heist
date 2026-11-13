"""Hideout van styles (LOBBY 2 track, Config.Hideout.VAN.STYLES): three more getaway van bodies a crew leader cycles
at their van: VanBakery (a boxy bakery van), VanCamper (a rounded vintage camper), VanSecurity (a long, low armoured
"security" van). Each is a frame object (dark parts, glass, trims, wheels, its props) plus <Name>_Paint (the body
panels as ONE runtime-coloured MeshPart, like Van_Paint: a mid value by MeshPart.Color, never Getaway White).

Build: python3 tools/blender/build_asset.py assets/blender/van_styles.py

Every style keeps the kit Van's contract (assets/blender/van.py; server Heist/Vans and Config.Hideout.VAN rely on it):
  * the same footprint: 14 long (X, cab at +X = Roblox local -X) x 6.4 wide, inside the Van's bounds
    (-7.45..7.45, -3.74..3.34), origin = bottom centre, so a style swap reuses the bay's pivot;
  * the open sliding side door on -Y (Roblox local -Z) at x -2.6..2.4, z 1.8..6.7, with the slid-back door panel
    behind it (the runtime door leaf of Heist/Vans slides over that place);
  * a hollow cargo bay x -7..2.6 (the seat anchors: the cargo bench at x -5.4 / -3.4 / -1.4, y 2.1, z 2.4 and the
    driver at x 4.3, y 1.2, z 2.3 in the cab), its floor at z 1.85;
  * the look points on the door side (cab x 4.6, door x 0.1, paint / style at the rear x -5) stay on panels.
Original designs: no real make, no badge, no lettering.
"""
import math

X0, X1 = -7.0, 7.0
W_ = 6.4
Y0, Y1 = -W_ / 2, W_ / 2
Z0 = 1.55                          # body floor
T = 0.3                            # shell thickness
DOOR = (-2.6, 2.4, Z0 + 0.25, 6.7)  # side opening x0, x1, z0, z1 (the Van's)


def cargo_shell(mb, mp, xc, h, roof=True, roof_col="steel_lo"):
    """The hollow cargo bay with the open side door (the Van's layout): paint panels on mp, floor / roof / lining /
    trims on mb. xc = the bulkhead (cab side), h = the cargo roof height."""
    dx0, dx1, dz0, dz1 = DOOR
    mb.box((X0, Y0, Z0), (xc, Y1, Z0 + T), "steel_lo", chamfer=0.1, cham_col="steel", part="Floor")
    if roof:
        mb.box((X0, Y0, h - T), (xc, Y1, h), roof_col, chamfer=0.22, cham_col=roof_col, flat=("+x",), part="Roof")
    mp.box((X0, Y1 - T, Z0 + T), (xc, Y1, h - T), "white", chamfer=0.2, cham_col="white", flat=("+x", "-z", "+z"), part="FarSide")
    mp.box((X0, Y0, Z0 + T), (X0 + T, Y1 - T, h - T), "white", chamfer=0.2, cham_col="white", flat=("-z", "+z", "+y"), part="Rear")
    mp.box((X0 + T, Y0, Z0 + T), (dx0, Y0 + T, h - T), "white", flat=("-z", "+z", "-x"), part="NearRear")
    mp.box((dx1, Y0, Z0 + T), (xc, Y0 + T, h - T), "white", flat=("-z", "+z", "+x"), part="NearFront")
    mp.box((dx0, Y0, dz1), (dx1, Y0 + T, h - T), "white", flat=("-x", "+x", "+z"), part="NearHeader")
    mb.box((dx0, Y0, Z0 + T), (dx1, Y0 + T, dz0), "steel", chamfer=0.06, cham_col="steel_hi", part="Step")
    # dark lining: what you see through the door
    mb.box((X0 + T, Y1 - T - 0.04, Z0 + T), (xc - 0.01, Y1 - T, h - T), "ink_hi", part="InFar")
    mb.box((X0 + T, Y0 + T, h - T - 0.04), (xc - 0.01, Y1 - T, h - T), "ink_hi", part="InRoof")
    mb.box((X0 + T, Y0 + T, Z0 + T), (xc - 0.01, Y1 - T, Z0 + T + 0.04), "ink", part="InFloor")
    mb.box((X0 + T, Y0 + T, Z0 + T), (X0 + T + 0.04, Y1 - T, h - T), "ink_hi", part="InRear")
    mb.box((xc - 0.3, Y0 + T, Z0 + T), (xc, Y1 - T, h - T), "ink_hi", part="Bulkhead")
    # door frame trim and the slid-back door panel with its rail
    for lo, hi in (((dx0 - 0.2, Y0 - 0.12, dz0), (dx0, Y0 + 0.05, dz1 + 0.2)),
                   ((dx1, Y0 - 0.12, dz0), (dx1 + 0.2, Y0 + 0.05, dz1 + 0.2)),
                   ((dx0, Y0 - 0.12, dz1), (dx1, Y0 + 0.05, dz1 + 0.2))):
        mb.box(lo, hi, "steel", chamfer=0.05, cham_col="steel_hi", flat=("+y",), part="DoorTrim")
    mp.box((X0 + 0.25, Y0 - 0.4, dz0 + 0.1), (dx0 - 0.25, Y0 - 0.12, dz1 - 0.05), "white", chamfer=0.1,
           cham_col="white", part="SlidDoor")
    mb.box((X0 + 0.4, Y0 - 0.48, dz0 + 2.0), (X0 + 0.7, Y0 - 0.38, dz0 + 2.8), "steel_lo", part="DoorHandle")
    mb.box((X0 + 0.1, Y0 - 0.2, dz1 + 0.25), (dx1 + 0.2, Y0 + 0.02, dz1 + 0.45), "steel_lo", part="Rail")


def wheels(mb, xs=(-4.6, 4.5), r=1.25, hub="steel_hi", wall=None):
    """Tyres, hubs and dark arches (toy proportions: half hidden under the body). wall = a whitewall ring colour."""
    for wx in xs:
        for sy in (-1, 1):
            c = (wx, sy * (W_ / 2 - 0.5), r)
            mb.cylinder(c, (0, sy, 0), r, -0.45, 0.45, 10, "ink", chamfer=0.15, cham_col="ink_hi", part="Tyre")
            if wall:
                mb.cylinder(c, (0, sy, 0), r * 0.72, 0.4, 0.5, 10, wall, part="Whitewall")
            mb.cylinder(c, (0, sy, 0), r * 0.48, 0.4, 0.54, 8, hub, part="Hub")
        for sy in (-1, 1):
            mb.box((wx - 1.55, sy * (W_ / 2) - 0.1, Z0 - 0.05), (wx + 1.55, sy * (W_ / 2) + 0.1, Z0 + 0.25), "steel_lo",
                   chamfer=0.06, cham_col="steel", part="Arch")


def slope_glass(mb, a, b, y0, y1, inset=0.25, col="ink_hi"):
    """A dark glass plate on a cab slope from a=(x, z) to b=(x, z), 0.01 off the slope, across y0..y1."""
    ex, ez = b[0] - a[0], b[1] - a[1]
    el = math.hypot(ex, ez)
    tx, tz = ex / el, ez / el
    nx, nz = tz, -tx
    if nx < 0:
        nx, nz = -nx, -nz
    p = (a[0] + tx * inset, a[1] + tz * inset)
    q = (b[0] - tx * inset, b[1] - tz * inset)
    ws = [(p[0] + nx * 0.01, p[1] + nz * 0.01), (p[0] + nx * 0.07, p[1] + nz * 0.07),
          (q[0] + nx * 0.07, q[1] + nz * 0.07), (q[0] + nx * 0.01, q[1] + nz * 0.01)]
    if (ws[1][0] - ws[0][0]) * (ws[2][1] - ws[0][1]) - (ws[1][1] - ws[0][1]) * (ws[2][0] - ws[0][0]) < 0:
        ws.reverse()
    mb.prism(ws, "Y", y0, y1, col, col, part="Windscreen")


def side_windows(mb, poly):
    """Dark side windows on both cab sides (poly in (x, z), convex)."""
    for ya, yb in ((Y0 + 0.08, Y0 + 0.2), (Y1 - 0.2, Y1 - 0.08)):
        mb.prism(poly, "Y", ya, yb, "ink_hi", "ink_hi", part="SideWindow")


def door_band(mb, xc, z=(2.55, 3.35)):
    """The exit band on the door side: a dark stripe on the slid door and the cab with Getaway White chevrons that
    point at the open door (the Van's signal, kept on every style)."""
    dx0, dx1 = DOOR[0], DOOR[1]
    yd = Y0 - 0.4
    yc0 = Y0 + 0.15
    za, zb = z
    zm = (za + zb) / 2
    for xa, xb, yi, yo, chev in ((X0 + 0.4, dx0 - 0.4, yd + 0.02, yd - 0.1, [(X0 + 1.3, 1), (X0 + 2.3, 1), (X0 + 3.3, 1)]),
                                 (xc, xc + 3.0, yc0 + 0.02, yc0 - 0.1, [(xc + 1.0, -1), (xc + 2.0, -1)])):
        mb.box((xa, min(yi, yo), za), (xb, max(yi, yo), zb), "ink", part="Band")
        for cx, d in chev:
            pts = [(cx - 0.35 * d, za + 0.1), (cx + 0.05 * d, zm), (cx - 0.35 * d, zb - 0.1), (cx - 0.05 * d, zb - 0.1),
                   (cx + 0.35 * d, zm), (cx - 0.05 * d, za + 0.1)]
            if d < 0:
                pts = list(reversed(pts))
            mb.prism(pts, "Y", yo - 0.04, yo + 0.01, "exit", "exit", part="Chevron")


def nose(mb, lamp_z=3.0, grille=(2.3, 3.6), lamp_col="marble_hi", lamp_r=0.5, square=False):
    """Grille, headlights, bumpers, tail lights."""
    g0, g1 = grille
    mb.box((X1 - 0.05, -1.7, g0), (X1 + 0.12, 1.7, g1), "steel_lo", chamfer=0.05, cham_col="steel", flat=("-x",), part="Grille")
    n = max(2, int((g1 - g0) / 0.3))
    for i in range(n):
        zz = g0 + 0.2 + (g1 - g0 - 0.3) * i / max(1, n - 1)
        mb.box((X1 + 0.1, -1.55, zz), (X1 + 0.18, 1.55, zz + 0.1), "ink", part=f"GrilleBar_{i}")
    for sy in (-1, 1):
        if square:
            mb.box((X1 - 0.05, sy * 2.35 - 0.45, lamp_z - 0.3), (X1 + 0.14, sy * 2.35 + 0.45, lamp_z + 0.3), lamp_col,
                   chamfer=0.05, cham_col="steel_hi", part="Headlight")
        else:
            mb.cylinder((X1, sy * 2.35, lamp_z), (1, 0, 0), lamp_r, -0.05, 0.16, 10, lamp_col, part="Headlight")
        mb.box((X0 - 0.15, sy * 2.2 - 0.45, 3.4), (X0 + 0.02, sy * 2.2 + 0.45, 4.6), "ink_hi", chamfer=0.05,
               cham_col="ink_hi", flat=("+x",), part="TailLight")


def bumpers(mb, col="steel_lo", cham="steel", z=(1.05, 1.75)):
    mb.box((X1 - 0.1, Y0 + 0.2, z[0]), (X1 + 0.45, Y1 - 0.2, z[1]), col, chamfer=0.12, cham_col=cham, part="BumperF")
    mb.box((X0 - 0.45, Y0 + 0.2, z[0]), (X0 + 0.1, Y1 - 0.2, z[1]), col, chamfer=0.12, cham_col=cham, part="BumperR")


def asset(k, name, mb, mp, notes, frame_notes, paint_notes):
    ob = k.finalize(mb, pivot=(0, 0, 0))
    paint = k.finalize(mp, pivot=(0, 0, 0))
    return k.Asset(name, [
        k.Obj(ob, "medium", role="exit", pivot="point", collision="Box", can_collide=False, free_shells=True,
              tags=["EH_VanStyle"], notes=frame_notes),
        k.Obj(paint, "small", role="exit", pivot="point", collision="Box", can_collide=False, atlas=False,
              free_shells=True, extra={"tintable": True},
              tint="van paint: a mid value by MeshPart.Color (the bay's or the crew's pick in the hideout and the "
                   "drive); never Getaway White",
              notes=paint_notes),
    ], seats=[(name + "_Paint", name), (name, name + "_Paint")], notes=notes)


# ---------------------------------------------------------------- the bakery van (boxy, a box over the cab)

def bakery(k):
    mb = k.MB("VanBakery")
    mp = k.MB("VanBakery_Paint")
    XC, H = 3.2, 7.4
    cargo_shell(mb, mp, XC, H)
    dx0, dx1, dz0, dz1 = DOOR
    # the box runs on over the cab (a baker's box van): a paint block above the cab, its nose rounded off
    mp.box((XC, Y0 + 0.05, 5.75), (5.6, Y1 - 0.05, H), "white", chamfer=0.35, cham_col="white", flat=("-x",), part="Overcab")
    # the cab under it: short and upright, a sloped nose
    cab = [(XC, Z0), (X1, Z0), (X1, 3.75), (6.55, 4.15), (5.55, 5.75), (XC, 5.75)]
    mp.prism(cab, "Y", Y0 + 0.15, Y1 - 0.15, ["white"] * 6, "white", chamfer=0.2, cham_col="white",
             cham_edges=[1, 2, 3], part="Cab")
    slope_glass(mb, (6.55, 4.15), (5.55, 5.75), Y0 + 0.45, Y1 - 0.45)
    side_windows(mb, [(XC + 0.35, 4.3), (5.85, 4.3), (5.45, 5.5), (XC + 0.35, 5.5)])
    nose(mb, lamp_z=2.95, grille=(2.25, 3.45))
    bumpers(mb)
    wheels(mb)
    door_band(mb, XC)
    # the awning over the side door: cream and tan stripes on a slope (above the door leaf's top at 6.7)
    n = 8
    w = (dx1 - dx0 + 0.8) / n
    for i in range(n):
        xa = dx0 - 0.4 + i * w
        col = "marble_hi" if i % 2 == 0 else "marble_lo"
        mb.prism([(Y0 + 0.02, 7.2), (Y0 + 0.02, 7.0), (Y0 - 0.46, 6.86), (Y0 - 0.46, 6.98)], "X", xa, xa + w,
                 col, col, part="Awning")
    mb.box((dx0 - 0.45, Y0 - 0.52, 6.78), (dx1 + 0.45, Y0 - 0.44, 6.98), "marble", part="AwningLip")
    # the big loaf on the roof over the cab (a baked sign, no letters): a crust with a lighter top and score marks
    mb.box((3.55, -1.7, H), (6.0, 1.7, H + 0.5), "marble_lo", chamfer=0.22, cham_col="marble", flat=("-z",), part="Loaf")
    mb.box((3.8, -1.4, H + 0.42), (5.75, 1.4, H + 0.62), "marble", chamfer=0.12, cham_col="marble_hi", part="LoafTop")
    for sx in (4.2, 4.8, 5.4):
        mb.box((sx - 0.06, -1.1, H + 0.6), (sx + 0.06, 1.1, H + 0.66), "marble_lo", part="Score")
    # a cream belt line round the box (the baker's two-tone), and a serving shelf under the door's rear jamb
    for ya, yb in ((Y1 - 0.02, Y1 + 0.08), ):
        mb.box((X0 + 0.15, ya, 5.1), (XC - 0.05, yb, 5.35), "marble_hi", part="Belt")
    mb.box((X0 + 0.15, Y0 - 0.5, 5.1), (dx0 - 0.3, Y0 - 0.4, 5.35), "marble_hi", part="BeltDoor")
    mb.box((X0 - 0.04, -2.6, 5.1), (X0 + 0.02, 2.6, 5.35), "marble_hi", part="BeltRear")
    return asset(k, "VanBakery", mb, mp,
                 "Bakery van 14x6.4x7.9: a tall box over the cab, striped awning over the open side door (-Y), a loaf "
                 "on the roof, the exit band; the Van's footprint, door, cargo bay and seat anchors.",
                 "frame: floor, roof, lining, trims, glass, wheels, awning, loaf, belt line and the exit band",
                 "the box panels, sliding door, over-cab box and cab as one runtime-coloured part (no atlas)")


# ---------------------------------------------------------------- the vintage camper (rounded, two-tone)

def camper(k):
    mb = k.MB("VanCamper")
    mp = k.MB("VanCamper_Paint")
    XC, H = 2.8, 6.95
    cargo_shell(mb, mp, XC, H, roof=False)
    # the cream roof: a rounded cap over the cargo and the cab (two-tone: paint below, cream above)
    prof = [(Y0, H - T), (Y1, H - T), (Y1, H + 0.15), (Y1 - 0.45, H + 0.55), (Y1 - 1.3, H + 0.75),
            (Y0 + 1.3, H + 0.75), (Y0 + 0.45, H + 0.55), (Y0, H + 0.15)]
    mb.prism(prof, "X", X0, 4.6, "marble_hi", "marble_hi", part="Roof")
    # the rounded bus nose under it: one prism across the width
    nose_poly = [(XC, Z0), (X1, Z0), (X1, 3.5), (6.9, 4.4), (6.45, 5.6), (5.7, 6.45), (4.6, H - T), (XC, H - T)]
    mp.prism(nose_poly, "Y", Y0 + 0.15, Y1 - 0.15, ["white"] * 8, "white", chamfer=0.2, cham_col="white",
             cham_edges=[1, 2, 3, 4, 5], part="Cab")
    # the cream V on the nose and the split windscreen (two panes) on the upper slope
    mb.prism([(6.93, 3.3), (7.04, 3.3), (6.6, 4.9), (6.48, 4.9)], "Y", -0.35, 0.35, "marble_hi", "marble_hi", part="NoseV")
    for ya, yb in ((Y0 + 0.4, -0.12), (0.12, Y1 - 0.4)):
        slope_glass(mb, (6.45, 5.6), (5.7, 6.45), ya, yb, inset=0.15)
    side_windows(mb, [(XC + 0.3, 4.6), (6.2, 4.6), (5.55, 6.1), (XC + 0.3, 6.1)])
    # round headlights in chrome rims, chrome bumpers, whitewall tyres
    for sy in (-1, 1):
        mb.cylinder((X1, sy * 2.3, 3.05), (1, 0, 0), 0.62, -0.05, 0.08, 12, "steel_hi", part="LampRim")
        mb.cylinder((X1, sy * 2.3, 3.05), (1, 0, 0), 0.48, -0.05, 0.16, 12, "marble_hi", part="Headlight")
        mb.cylinder((X0, sy * 2.2, 4.1), (-1, 0, 0), 0.4, -0.02, 0.14, 10, "ink_hi", part="TailLight")
    mb.box((X1 - 0.05, -1.3, 2.05), (X1 + 0.12, 1.3, 2.6), "steel_lo", chamfer=0.05, cham_col="steel", flat=("-x",), part="Grille")
    bumpers(mb, col="steel_hi", cham="steel")
    wheels(mb, r=1.2, wall="marble_hi")
    door_band(mb, XC)
    # portholes on the far side and the rear (the near side's are under the slid door)
    for px in (-5.6, -3.6, -1.6):
        mb.cylinder((px, Y1, 5.2), (0, 1, 0), 0.55, -0.02, 0.1, 12, "steel_hi", part="PortRim")
        mb.cylinder((px, Y1, 5.2), (0, 1, 0), 0.42, -0.02, 0.14, 12, "ink_hi", part="Porthole")
    # the spare wheel on the rear, a ladder up to the roof rack, and the rack with a striped board on it
    mb.cylinder((X0, 0.0, 3.2), (-1, 0, 0), 1.0, -0.05, 0.4, 10, "ink", chamfer=0.1, cham_col="ink_hi", part="Spare")
    mb.cylinder((X0, 0.0, 3.2), (-1, 0, 0), 0.5, 0.3, 0.45, 8, "marble_hi", part="SpareHub")
    for sy in (-1, 1):
        mb.box((X0 - 0.3, sy * 1.6 - 0.07, 4.4), (X0 - 0.16, sy * 1.6 + 0.07, H + 0.35), "steel", part="LadderRail")
        mb.box((X0 + 0.6, sy * 1.9 - 0.1, H + 0.6), (2.2, sy * 1.9 + 0.1, H + 0.95), "steel", part="RackRail")
    for i in range(4):
        z = 4.7 + i * 0.55
        mb.box((X0 - 0.3, -1.6, z), (X0 - 0.16, 1.6, z + 0.1), "steel", part="LadderRung")
    for x in (X0 + 0.9, -3.0, 0.0, 1.9):
        mb.box((x - 0.1, -2.0, H + 0.6), (x + 0.1, 2.0, H + 0.8), "steel", part="RackBar")
    mb.box((X0 + 0.4, -1.0, H + 0.8), (1.6, 1.0, H + 0.98), "marble_hi", chamfer=0.08, cham_col="marble", part="Board")
    mb.box((-4.1, -1.02, H + 0.8), (-3.4, 1.02, H + 1.0), "marble_lo", part="BoardStripe")
    return asset(k, "VanCamper", mb, mp,
                 "Vintage camper 14x6.4x8.0: a rounded cream roof, a bus nose with a split windscreen and a cream V, "
                 "round chrome lamps, whitewalls, portholes, a ladder and a rack; the Van's footprint, door, cargo bay "
                 "and seat anchors.",
                 "frame: floor, cream roof cap, lining, trims, glass, chrome, wheels, portholes, ladder, rack, board "
                 "and the exit band",
                 "the lower body, sliding door and the rounded nose as one runtime-coloured part (no atlas)")


# ---------------------------------------------------------------- the security van (long, low, armoured)

def security(k):
    mb = k.MB("VanSecurity")
    mp = k.MB("VanSecurity_Paint")
    XC, H = 2.6, 7.15
    cargo_shell(mb, mp, XC, H, roof_col="ink_hi")
    # a long, low bonnet and a short raked screen: the long-van read in the same 14 studs
    cab = [(XC, Z0), (X1, Z0), (X1, 3.55), (6.85, 4.05), (5.0, 4.45), (4.1, 6.15), (XC, 6.4)]
    mp.prism(cab, "Y", Y0 + 0.15, Y1 - 0.15, ["white"] * 7, "white", chamfer=0.18, cham_col="white",
             cham_edges=[1, 2, 4, 5], part="Cab")
    slope_glass(mb, (5.0, 4.45), (4.1, 6.15), Y0 + 0.5, Y1 - 0.5)
    side_windows(mb, [(XC + 0.3, 4.95), (4.65, 4.95), (4.2, 5.95), (XC + 0.3, 5.95)])
    # armour: the window bars, a riveted plate band along both sides, a dark skirt the whole length, a bull bar
    for ya, yb in ((Y0 - 0.02, Y0 + 0.09), (Y1 - 0.09, Y1 + 0.02)):
        for bx in (XC + 0.75, XC + 1.25, XC + 1.75):
            mb.box((bx - 0.05, ya, 4.95), (bx + 0.05, yb, 5.95), "steel", part="Bar")
    for ya, yb in ((Y1 - 0.02, Y1 + 0.07),):
        mb.box((X0 + 0.15, ya, 3.7), (XC - 0.05, yb, 4.6), "steel_lo", chamfer=0.05, cham_col="steel", part="ArmourFar")
    mb.box((X0 + 0.45, Y0 - 0.47, 3.7), (DOOR[0] - 0.45, Y0 - 0.38, 4.6), "steel_lo", chamfer=0.05, cham_col="steel", part="ArmourDoor")
    rivets_far = [(-6.4 + 0.9 * i) for i in range(10)]
    for rx in rivets_far:
        mb.box((rx - 0.08, Y1 + 0.06, 4.07), (rx + 0.08, Y1 + 0.12, 4.23), "steel_hi", part="Rivet")
    for rx in (-6.2, -5.4, -4.6, -3.8):
        mb.box((rx - 0.08, Y0 - 0.52, 4.07), (rx + 0.08, Y0 - 0.46, 4.23), "steel_hi", part="Rivet")
    mb.box((X0 + 0.05, Y1 - 0.02, Z0 + 0.05), (X1 - 0.3, Y1 + 0.12, Z0 + 0.75), "ink", chamfer=0.05, cham_col="ink_hi", part="SkirtFar")
    mb.box((DOOR[1] + 0.25, Y0 - 0.12, Z0 + 0.05), (X1 - 0.3, Y0 + 0.02, Z0 + 0.75), "ink", chamfer=0.05, cham_col="ink_hi", part="SkirtCab")
    nose(mb, lamp_z=3.05, grille=(2.3, 3.4), lamp_col="marble_hi", square=True)
    bumpers(mb, col="ink_hi", cham="steel_lo")
    for sy in (-1, 1):
        mb.box((X1 + 0.3, sy * 1.4 - 0.12, 1.75), (X1 + 0.45, sy * 1.4 + 0.12, 3.7), "steel_lo", chamfer=0.04, cham_col="steel", part="BullBar")
    mb.box((X1 + 0.29, -1.6, 3.4), (X1 + 0.45, 1.6, 3.62), "steel_lo", chamfer=0.04, cham_col="steel", part="BullBarTop")
    wheels(mb, r=1.3, hub="steel")
    door_band(mb, XC, z=(2.45, 3.25))
    # the rear: a big vault-wheel handle on the doors (it is a getaway van in disguise)
    mb.box((X0 - 0.08, -0.04, Z0 + 0.5), (X0 + 0.02, 0.04, H - 0.5), "steel_lo", part="RearSeam")
    mb.cylinder((X0, 0.0, 4.3), (-1, 0, 0), 0.75, -0.02, 0.12, 12, "steel", part="VaultWheel")
    for a in (0, 60, 120):
        vs = mb.prism([(-0.07, -0.85), (0.07, -0.85), (0.07, 0.85), (-0.07, 0.85)], "X", X0 - 0.22, X0 - 0.08,
                      "steel_hi", "steel_hi", origin=(0, 0, 4.3), part="Spoke")
        mb.rotate(vs, a, axis="X", centre=(X0, 0, 4.3))
    # the roof: a low light bar (unlit lamps) and two antenna stubs: the "security" silhouette
    mb.box((3.0, -1.9, H), (4.2, 1.9, H + 0.32), "steel_lo", chamfer=0.08, cham_col="steel", flat=("-z",), part="LightBar")
    for sy in (-1, 1):
        mb.box((3.15, sy * 1.15 - 0.6, H + 0.3), (4.05, sy * 1.15 + 0.6, H + 0.5), "steel_hi", chamfer=0.06,
               cham_col="marble_hi", part="BarLamp")
    for ax in (-6.2, -5.4):
        mb.cylinder((ax, 2.4, H), (0, 0, 1), 0.08, 0.0, 0.7, 6, "steel_lo", part="Antenna")
    return asset(k, "VanSecurity", mb, mp,
                 "Armoured 'security' van 14x6.4x7.5: a long low bonnet and raked screen, barred windows, a riveted "
                 "armour band, a dark skirt, a bull bar, a vault-wheel on the rear doors and a roof light bar; the "
                 "Van's footprint, door, cargo bay and seat anchors.",
                 "frame: floor, roof, lining, trims, glass, bars, armour, rivets, skirt, bull bar, wheels, vault "
                 "wheel, light bar and the exit band",
                 "the body panels, sliding door and the long cab as one runtime-coloured part (no atlas)")


def build(k):
    return [bakery(k), camper(k), security(k)]
