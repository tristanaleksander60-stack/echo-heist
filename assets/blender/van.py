"""Getaway van (launch kit prop, exit role): Van (+ Van_Shelf: the trophy / ornament shelf inside).

Build: python3 tools/blender/build_asset.py assets/blender/van.py
The van is home: you start at its open side door, you bank loot by reaching it, and in the garage lobby its
cargo bay shows your trophy shelf and the advent ornaments (MASTERPLAN 4.3, 6.6). Getaway White is reserved for
the exit, "always with an arrow" (6.2): the body is Getaway White, and a dark band along each side carries white
chevrons that point at the open door. Original design: a boxy step van, no real make or badge.
Size: 14 long (X, cab at +X) x 6.4 wide x 7.75 tall; the open sliding door is on the -Y side (the "front" for
the layout: it faces the shop). Origin = bottom centre. LevelSpec: Shop.VAN is the bank zone x -5..5, z 16..24
(10 x 8): put the van body just behind the zone with its door facing the shop, so the zone is the kerb in front
of the door (the crew seats in Shop.SPAWNS stand there).
"""
import math

L_, W_, H_ = 14.0, 6.4, 7.3       # body length, width, cargo roof height
X0, X1, XC = -7.0, 7.0, 3.0        # rear, nose, cab / cargo split
Z0 = 1.55                          # body floor (above the wheels' centre line)
DOOR = (-2.6, 2.4, Z0 + 0.25, 6.7)  # side opening x0, x1, z0, z1
T = 0.3                            # shell thickness


def build(k):
    mb = k.MB("Van")
    y0, y1 = -W_ / 2, W_ / 2
    # ---- cargo shell (hollow, open side door): floor, roof, walls; interior faces dark
    mb.box((X0, y0, Z0), (XC, y1, Z0 + T), "steel_lo", chamfer=0.1, cham_col="steel", part="Floor")
    mb.box((X0, y0, H_ - T), (XC, y1, H_), "exit", chamfer=0.25, cham_col="exit", flat=("+x",), part="Roof")
    mb.box((X0, y1 - T, Z0 + T), (XC, y1, H_ - T), "exit", chamfer=0.2, cham_col="exit", flat=("+x", "-z", "+z"), part="FarSide")
    mb.box((X0, y0, Z0 + T), (X0 + T, y1 - T, H_ - T), "exit", chamfer=0.2, cham_col="exit", flat=("-z", "+z", "+y"), part="Rear")
    dx0, dx1, dz0, dz1 = DOOR
    mb.box((X0 + T, y0, Z0 + T), (dx0, y0 + T, H_ - T), "exit", flat=("-z", "+z", "-x"), part="NearRear")
    mb.box((dx1, y0, Z0 + T), (XC, y0 + T, H_ - T), "exit", flat=("-z", "+z", "+x"), part="NearFront")
    mb.box((dx0, y0, dz1), (dx1, y0 + T, H_ - T), "exit", flat=("-x", "+x", "+z"), part="NearHeader")
    mb.box((dx0, y0, Z0 + T), (dx1, y0 + T, dz0), "steel", chamfer=0.06, cham_col="steel_hi", part="Step")
    # dark interior lining (ink_hi): what you see through the door
    mb.box((X0 + T, y1 - T - 0.04, Z0 + T), (XC - 0.01, y1 - T, H_ - T), "ink_hi", part="InFar")
    mb.box((X0 + T, y0 + T, H_ - T - 0.04), (XC - 0.01, y1 - T, H_ - T), "ink_hi", part="InRoof")
    mb.box((X0 + T, y0 + T, Z0 + T), (XC - 0.01, y1 - T, Z0 + T + 0.04), "ink", part="InFloor")
    mb.box((X0 + T, y0 + T, Z0 + T), (X0 + T + 0.04, y1 - T, H_ - T), "ink_hi", part="InRear")
    mb.box((XC - 0.3, y0 + T, Z0 + T), (XC, y1 - T, H_ - T), "ink_hi", part="Bulkhead")
    # door frame trim (steel) around the opening, and the slid-back door panel with its rail
    for lo, hi in (((dx0 - 0.2, y0 - 0.12, dz0), (dx0, y0 + 0.05, dz1 + 0.2)), ((dx1, y0 - 0.12, dz0), (dx1 + 0.2, y0 + 0.05, dz1 + 0.2)),
                   ((dx0, y0 - 0.12, dz1), (dx1, y0 + 0.05, dz1 + 0.2))):
        mb.box(lo, hi, "steel", chamfer=0.05, cham_col="steel_hi", flat=("+y",), part="DoorTrim")
    mb.box((X0 + 0.25, y0 - 0.4, dz0 + 0.1), (dx0 - 0.25, y0 - 0.12, dz1 - 0.05), "exit", chamfer=0.1, cham_col="exit", part="SlidDoor")
    mb.box((X0 + 0.4, y0 - 0.48, dz0 + 2.0), (X0 + 0.7, y0 - 0.38, dz0 + 2.8), "steel_lo", part="DoorHandle")
    mb.box((X0 + 0.1, y0 - 0.2, H_ - 0.75), (dx1 + 0.2, y0 + 0.02, H_ - 0.55), "steel_lo", part="Rail")
    # ---- cab: one prism (side profile extruded across the width), windscreen and side windows dark glass
    cab = [(XC, Z0), (X1, Z0), (X1, 3.9), (6.5, 4.35), (5.15, 6.75), (XC, H_ - 0.05)]
    cols = ["steel_lo", "exit", "exit", "ink_hi", "exit", "exit"]
    mb.prism(cab, "Y", y0 + 0.15, y1 - 0.15, cols, "exit", chamfer=0.22, cham_col="exit", cham_edges=[1, 2, 3, 4, 5], part="Cab")
    for sy, ya, yb in ((-1, y0 + 0.08, y0 + 0.2), (1, y1 - 0.2, y1 - 0.08)):
        win = [(XC + 0.35, 4.55), (5.85, 4.55), (5.05, 6.35), (XC + 0.35, 6.35)]
        mb.prism(win, "Y", ya, yb, "ink_hi", "ink_hi", part="SideWindow")
    # nose: grille, headlights, bumpers
    mb.box((X1 - 0.05, -1.7, 2.3), (X1 + 0.12, 1.7, 3.6), "steel_lo", chamfer=0.05, cham_col="steel", flat=("-x",), part="Grille")
    for i in range(4):
        z = 2.5 + 0.28 * i
        mb.box((X1 + 0.1, -1.55, z), (X1 + 0.18, 1.55, z + 0.1), "ink", part=f"GrilleBar_{i}")
    for sy in (-1, 1):
        mb.cylinder((X1, sy * 2.35, 3.0), (1, 0, 0), 0.5, -0.05, 0.16, 10, "marble_hi", part="Headlight")
        mb.box((X0 - 0.15, sy * 2.2 - 0.45, 3.4), (X0 + 0.02, sy * 2.2 + 0.45, 4.6), "ink_hi", chamfer=0.05, cham_col="ink_hi", flat=("+x",), part="TailLight")
    mb.box((X1 - 0.1, y0 + 0.2, 1.05), (X1 + 0.45, y1 - 0.2, 1.75), "steel_lo", chamfer=0.12, cham_col="steel", part="BumperF")
    mb.box((X0 - 0.45, y0 + 0.2, 1.05), (X0 + 0.1, y1 - 0.2, 1.75), "steel_lo", chamfer=0.12, cham_col="steel", part="BumperR")
    mb.box((X0 - 0.05, -0.04, Z0 + 0.5), (X0 + 0.02, 0.04, H_ - 0.5), "steel_lo", part="RearSeam")
    # ---- the exit band: a dark stripe along both sides with white chevrons. On the door side they point at the
    # open door (from the slid-back door panel and from the cab); on the far side they point forward.
    yd = y0 - 0.4            # outer face of the slid door
    yc0, yc1 = y0 + 0.15, y1 - 0.15   # cab side faces
    bands = [  # (x0, x1, y_inner, y_outer, chevrons [(x, dir)])
        (X0 + 0.4, dx0 - 0.4, yd + 0.02, yd - 0.1, [(X0 + 1.3, 1), (X0 + 2.3, 1), (X0 + 3.3, 1)]),
        (XC, XC + 3.5, yc0 + 0.02, yc0 - 0.1, [(XC + 1.1, -1), (XC + 2.1, -1)]),
        (X0 + 0.1, XC, y1 - 0.02, y1 + 0.1, [(-4.5, 1), (-3.5, 1), (-2.5, 1), (0.5, 1), (1.5, 1)]),
        (XC, XC + 3.5, yc1 - 0.02, yc1 + 0.1, [(XC + 1.1, 1), (XC + 2.1, 1)]),
    ]
    for xa, xb, yi, yo, chev in bands:
        mb.box((xa, min(yi, yo), 2.55), (xb, max(yi, yo), 3.35), "ink", part="Band")
        out = 1 if yo > yi else -1
        for cx, d in chev:   # chevron ">" pointing along +x (d = 1) or -x (d = -1)
            pts = [(cx - 0.35 * d, 2.65), (cx + 0.05 * d, 2.95), (cx - 0.35 * d, 3.25), (cx - 0.05 * d, 3.25),
                   (cx + 0.35 * d, 2.95), (cx - 0.05 * d, 2.65)]
            if d < 0:
                pts = list(reversed(pts))
            mb.prism(pts, "Y", min(yo - out * 0.01, yo + out * 0.04), max(yo - out * 0.01, yo + out * 0.04), "exit", "exit", part="Chevron")
    # ---- wheels: ink tyres, steel hubs (half hidden under the body: toy proportions)
    for wx in (-4.6, 4.5):
        for sy in (-1, 1):
            c = (wx, sy * (W_ / 2 - 0.5), 1.25)
            mb.cylinder(c, (0, sy, 0), 1.25, -0.45, 0.45, 10, "ink", chamfer=0.15, cham_col="ink_hi", part="Tyre")
            mb.cylinder(c, (0, sy, 0), 0.6, 0.4, 0.52, 8, "steel_hi", part="Hub")
    for sy in (-1, 1):   # wheel arches: dark lips over the tyres
        for wx in (-4.6, 4.5):
            mb.box((wx - 1.55, sy * (W_ / 2) - 0.1, Z0 - 0.05), (wx + 1.55, sy * (W_ / 2) + 0.1, Z0 + 0.25), "steel_lo",
                   chamfer=0.06, cham_col="steel", part="Arch")
    # ---- roof rack (silhouette from the diorama camera)
    for sy in (-1, 1):
        mb.box((X0 + 0.5, sy * 2.4 - 0.12, H_), (XC - 0.3, sy * 2.4 + 0.12, H_ + 0.45), "steel_lo", chamfer=0.05, cham_col="steel", part="RackRail")
    for x in (X0 + 1.0, -3.0, -0.5, XC - 0.8):
        mb.box((x - 0.12, -2.4, H_ + 0.2), (x + 0.12, 2.4, H_ + 0.4), "steel_lo", part="RackBar")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    # ---- the shelf inside (its own part, so the garage can show trophies on it and the heist can hide it)
    ms = k.MB("Van_Shelf")
    for z in (Z0 + 2.3, Z0 + 3.9):
        ms.box((dx0 - 0.6, y1 - T - 1.0, z), (dx1 + 0.4, y1 - T - 0.02, z + 0.16), "wood_lo", chamfer=0.05, cham_col="wood", part="Board")
    for x in (dx0 - 0.45, (dx0 + dx1) / 2, dx1 + 0.25):
        ms.box((x - 0.1, y1 - T - 0.25, Z0 + T + 0.04), (x + 0.1, y1 - T - 0.02, Z0 + 4.4), "steel", part="Upright")
    sh = k.finalize(ms, pivot=(0, 0, 0))
    return k.Asset("Van", [
        k.Obj(ob, "medium", role="exit", pivot="point", collision="PreciseConvexDecomposition", tags=["EH_Van"],
              sim="solid body; the bank zone is the kerb in front of the open door (LevelSpec van box)",
              notes="Getaway White body; hollow cargo bay with the sliding door open on -Y; chevrons point at the door"),
        k.Obj(sh, "small", role="env", pivot="point", collision="Box", can_collide=False, tags=["EH_TrophyShelf"],
              notes="trophy / ornament shelf inside the cargo bay: two dark boards (loot display rule)"),
    ], seats=[("Van_Shelf", "Van")],
        notes="Getaway step van 14x6.4x7.75: hollow cargo bay, open sliding door (-Y), exit band with chevrons, roof rack.")
