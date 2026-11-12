"""Garage v1 pieces (PLAN_STEAM_PLUS 4.1 W6, docs/GOLDEN_FRAMES.md G3): GarageDoor_16x12 and JobBoard.

Build: python3 tools/blender/build_asset.py assets/blender/garage.py
Placed by src/server/Heist/Lobby.luau from the pure plan src/server/Heist/LobbyPlan.luau (visual only: the garage's
colliders are its own greybox walls and floor). The walls, floor, work lamps, vans and shelves are the kit's existing
pieces in the Corner Shop atlas (warm brick).

GarageDoor_16x12: a wall module 16 wide on the 2-deep wall band: brick jambs (plum cells: brick in the Corner Shop
atlas) with a marble lintel, the roll-up curtain of Vault Steel slats half open (bottom bar at 4.75, the street and
its snow under it) and the roll housing. Origin bottom centre; front -Y (Roblox -Z).

JobBoard: the crew's job board on two legs beside your van: a wood-framed cork board, five pinned photos (the
targets), red string between the pins and an empty dark slot where Heist/Lobby mounts the NEXT job card (a Part with
a glowing SurfaceGui; manifest `card`: centre and size in Roblox axes). Role "story" (the red string is Ribbon).
Origin bottom centre; the board faces -Y (Roblox -Z).
"""
import _kitlib as L

# JobBoard: board face plane and the NEXT card slot (Blender axes: x, y = depth (-y is the front), z up)
BOARD = (-2.6, 2.6, 3.3, 7.0)        # x0, x1, z0, z1 of the frame
CORK_Y = (-0.22, -0.14)
SLOT = (0.0, 2.35, 3.55, 5.5)        # x0, x1, z0, z1 of the dark card slot (lower right): the NEXT card reads at 48 px
SLOT_Y = -0.26                       # slot front face


def garage_door(k):
    mb = k.MB("GarageDoor_16x12")
    # brick jambs and the lintel as one U-shaped prism through the wall band (y -1..1): no shared planes
    u = [(-8.0, 0.0), (-7.0, 0.0), (-7.0, 10.0), (7.0, 10.0), (7.0, 0.0), (8.0, 0.0), (8.0, 12.0), (-8.0, 12.0)]
    cols = ["ink", "plum_hi", "plum_hi", "plum_hi", "ink", "plum", "plum_hi", "plum"]
    mb.prism(u, "Y", -1.0, 1.0, cols, "plum", part="Frame")
    for y0, y1 in ((-1.18, -0.98), (0.98, 1.18)):
        mb.box((-7.25, y0, 9.7), (7.25, y1, 10.15), "marble", chamfer=0.05, cham_col="marble_hi", part="LintelTrim")
    # roll housing under the lintel (a drum along X), inside the band
    mb.cylinder((-6.95, 0.35, 9.45), (1, 0, 0), 0.5, 0.0, 13.9, 12, "steel_lo", cap_col="steel_lo", part="Housing")
    # the curtain: slats from the housing down to the half-open bottom bar; alternate depths so no two slats share
    # a plane (they overlap a little in height)
    z = 9.2
    i = 0
    while z > 5.0 + 1e-6:
        z0 = max(5.0, z - 0.45)
        col, ya, yb = ("steel", 0.1, 0.42) if i % 2 == 0 else ("steel_hi", 0.14, 0.38)
        mb.box((-6.9, ya, z0), (6.9, yb, z), col, part=f"Slat{i}")
        z = z0 + 0.03 if z0 > 5.0 else z0
        i += 1
    mb.box((-6.9, 0.04, 4.75), (6.9, 0.5, 5.01), "ink", chamfer=0.04, cham_col="ink_hi", part="BottomBar")
    mb.box((-0.6, -0.02, 4.82), (0.6, 0.06, 4.95), "steel_hi", part="Handle")
    # guide rails against the jambs' inner faces (0.01 off them)
    for x0, x1 in ((-6.99, -6.81), (6.81, 6.99)):
        mb.box((x0, 0.0, 0.02), (x1, 0.52, 9.95), "steel_lo", part="Rail")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("GarageDoor_16x12", [k.Obj(
        ob, "module", role="env", symmetric="X", pivot="bottom", collision="Box", can_collide=False,
        cast_shadow=True, sim="none",
        notes="garage roll-up door module: brick jambs + lintel (location cells), steel curtain half open (bottom "
              "bar at 4.75); visual only, the garage keeps its own colliders")],
        notes="Roll-up garage door 16 x 2 x 12: brick jambs, marble lintel trim, steel slats half open, roll housing.")


def job_board(k):
    mb = k.MB("JobBoard")
    x0, x1, z0, z1 = BOARD
    # legs and feet
    for sx in (-1, 1):
        x = sx * 2.25
        mb.box((x - 0.14, -0.1, 0.1), (x + 0.14, 0.12, z0 + 0.05), "wood_lo", part="Leg")
        mb.box((x - 0.2, -0.5, 0.0), (x + 0.2, 0.5, 0.16), "ink", chamfer=0.04, cham_col="ink_hi", part="Foot")
    # frame (wood) and the cork face (Warm Marble shade: cork)
    mb.box((x0, -0.15, z0), (x1, 0.15, z1), "wood", chamfer=0.06, cham_col="wood_hi", part="Frame")
    mb.box((x0 + 0.22, CORK_Y[0], z0 + 0.22), (x1 - 0.22, CORK_Y[1], z1 - 0.22), "marble_lo", part="Cork")
    # header plank
    mb.box((x0 - 0.1, -0.2, z1 - 0.02), (x1 + 0.1, 0.2, z1 + 0.32), "wood_lo", chamfer=0.05, cham_col="wood", part="Header")
    # the NEXT card slot: a dark recess the card part covers
    sx0, sx1, sz0, sz1 = SLOT
    mb.box((sx0, SLOT_Y, sz0), (sx1, CORK_Y[0] + 0.01, sz1), "ink", part="Slot")
    # pinned photos: (centre x, centre z, w, h, tilt degrees, picture colour)
    photos = [(-1.75, 6.05, 1.05, 0.8, -6, "steel"), (-0.45, 6.2, 0.95, 0.75, 4, "plum_hi"),
              (0.95, 6.0, 1.1, 0.82, -3, "leaf"), (-1.55, 4.55, 1.1, 0.85, 5, "wood_hi"),
              (-0.62, 4.35, 0.8, 1.0, -4, "steel_lo")]
    pins = []
    for i, (cx, cz, w, h, tilt, pic) in enumerate(photos):
        y_back = CORK_Y[0] + 0.01
        vs = mb.box((cx - w / 2, y_back - 0.035, cz - h / 2), (cx + w / 2, y_back, cz + h / 2), "marble_hi",
                    part=f"Photo{i}")
        ps = mb.box((cx - w / 2 + 0.09, y_back - 0.05, cz - h / 2 + 0.09), (cx + w / 2 - 0.09, y_back - 0.03,
                    cz + h / 2 - 0.2), pic, part=f"Picture{i}")
        mb.rotate(vs + ps, tilt, "Y", (cx, 0, cz))
        pz = cz + h / 2 - 0.1
        mb.sphere((cx, y_back - 0.1, pz), 0.07, 8, 4, "ribbon_hi", part=f"Pin{i}")
        mb.box((cx - 0.015, y_back - 0.1, pz - 0.015), (cx + 0.015, y_back + 0.005, pz + 0.015), "steel_hi",
               part=f"PinNeedle{i}")
        pins.append((cx, y_back - 0.12, pz))
    # the red string from pin to pin (and down to the card slot's corner pin)
    slot_pin = (sx0 + 0.15, CORK_Y[0] - 0.1, sz1 - 0.12)
    mb.sphere(slot_pin, 0.08, 8, 4, "ribbon_hi", part="SlotPin")
    mb.box((slot_pin[0] - 0.015, slot_pin[1], slot_pin[2] - 0.015), (slot_pin[0] + 0.015, CORK_Y[0] + 0.005,
           slot_pin[2] + 0.015), "steel_hi", part="SlotNeedle")
    order = [0, 1, 2, 4, 3, 0]
    for a, b in zip(order, order[1:]):
        L.tube(mb, [pins[a], pins[b]], 0.025, 5, "ribbon", cap_col="ribbon", part=f"String{a}{b}")
    for a in (2, 4):
        L.tube(mb, [pins[a], (slot_pin[0], slot_pin[1] - 0.02, slot_pin[2])], 0.025, 5, "ribbon", cap_col="ribbon",
               part=f"StringSlot{a}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    card_c = [-(sx0 + sx1) / 2, (sz0 + sz1) / 2, SLOT_Y]           # Roblox (x, y, z) = Blender (-x, z, y)
    card_s = [sx1 - sx0, sz1 - sz0]
    return k.Asset("JobBoard", [k.Obj(
        ob, "small", role="story", pivot="bottom", collision="Box", can_collide=False, cast_shadow=True,
        sim="none", tags=["EH_JobBoard"], extra={"card": {"centre": card_c, "size": card_s}},
        notes="garage job board on legs: cork, five pinned target photos, red string, the NEXT card slot (lower "
              "right; manifest card = centre + size in Roblox axes, the front is -Z)")],
        notes="Job board 5.4 x 1 x 7.3 on legs: wood frame, cork, pinned photos, red string, NEXT card slot.")


def build(k):
    return [garage_door(k), job_board(k)]
