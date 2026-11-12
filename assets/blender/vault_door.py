"""Golden asset (W1, greybox pass 1): the round Vault Door, as 4 MeshParts in one Model.

Build: python3 tools/blender/build_asset.py assets/blender/vault_door.py
Brief: hero (assembly target 10,000 / ceiling 20,000; the golden pass adds the emissive dial mask and detail up to
8-10k). Separate pieces because code moves them: the door swings on its hinge, the wheel spins, the ring glows in
the opener's hue.

  VaultDoor_Frame    16 x 12 module in the wall line (4 grid cells). Origin = the wall grid corner (0, 0, 0), the
                     same rule as Bank_Wall; the frame overhangs the wall faces by 0.25 to cap the trims. The opening
                     is a 9-stud circle whose bottom is cut by the floor: a 5.4-stud flat threshold, so crews and
                     clones walk through without a lip.
  VaultDoor_Door     4.4-radius stepped door with 6 locking bolts and a hinge on the left. Origin = the hinge axis at
                     floor level, so `PivotTo` + a yaw tween opens it.
  VaultDoor_Dial     spoked wheel. Origin = wheel axis on the door face (spin about the door normal).
  VaultDoor_DialRing glow ring under the wheel. Studio: Neon, Color set by code (Warm Marble idle, the opener's
                     clone hue while opening, Alarm Red on alarm). TextureID cleared.
Palette (value ladder, dark to light): Ink Indigo frame face -> Vault Steel door -> light steel bezel, bolts and
chamfers -> glowing ring (focal). Marble cornice / pilasters and Ink plinths continue the Bank_Wall trim lines.
"""
import math

W, H = 16.0, 12.0
Y_FRONT, Y_BACK = -0.25, 2.25
C = (8.0, 3.6)            # opening centre (x, z)
RH = 4.5                  # opening radius
SEG = 48                  # circle segments for the big round parts
FWD = (0, -1, 0)          # door normal (front faces -Y)


def centre(h):
    """Point on the door axis, h studs in front of the frame's front face."""
    return (C[0], Y_FRONT - h, C[1])


def frame(k):
    mb = k.MB("VaultDoor_Frame")
    a0 = math.degrees(math.atan2(-C[1], -math.sqrt(RH ** 2 - C[1] ** 2)))   # left chord end (negative angle)
    a1 = math.degrees(math.atan2(-C[1], math.sqrt(RH ** 2 - C[1] ** 2)))    # right chord end
    start, end = a0 % 360, a1
    n = max(8, round((start - end) / (360 / SEG)))
    arc = [(C[0] + RH * math.cos(math.radians(start - (start - end) * i / n)),
            C[1] + RH * math.sin(math.radians(start - (start - end) * i / n))) for i in range(n + 1)]
    poly = [(0.0, 0.0)] + arc + [(W, 0.0), (W, H), (0.0, H)]
    cols = ["ink"] + ["steel_lo"] * n + ["ink", "ink_hi", "plum_hi", "ink_hi"]   # top = cut-away cap, as Bank_Wall
    m = len(poly)
    mb.prism(poly, "Y", Y_FRONT, Y_BACK, cols, "ink_hi", chamfer=0.25, cham_col="plum_hi",
             cham_edges=[m - 3, m - 2, m - 1], part="Block")
    bez = mb.lathe([(RH, -0.1), (RH, 0.35), (RH + 0.12, 0.47), (RH + 0.88, 0.47), (RH + 1.0, 0.35), (RH + 1.0, -0.1)],
                   SEG, ["steel", "steel_hi", "steel_hi", "steel_hi", "steel", "steel_lo"], centre(0), FWD,
                   closed=True, part="Bezel")
    mb.clip((0, 0, 0), (0, 0, 1), "steel_lo", part_verts=bez)
    for a in (30, 60, 90, 120, 150):
        x = C[0] + 6.2 * math.cos(math.radians(a)); z = C[1] + 6.2 * math.sin(math.radians(a))
        mb.cylinder((x, Y_FRONT, z), FWD, 0.32, -0.05, 0.3, 8, "steel_hi", chamfer=0.07, cham_col="steel_hi",
                    part=f"Rivet_{a}")
    # Bank-kit trims on both faces: the cornice continues the wall crown line, the plinths continue the
    # baseboard, marble pilasters frame the portal (STYLE_BIBLE: one focal feature, framed by the kit).
    def both(y0, y1):
        return ((y0, y1), (Y_BACK - (y1 - Y_FRONT), Y_BACK + (Y_FRONT - y0)))
    for ya, yb in both(Y_FRONT - 0.45, Y_FRONT + 0.1):
        mb.box((0, ya, 10.8), (W, yb, H), "marble", chamfer=0.15, cham_col="marble_hi", flat=("-x", "+x"),
               part="Cornice")
    for ya, yb in both(Y_FRONT - 0.5, Y_FRONT + 0.1):
        for x0, x1 in ((0.0, 1.2), (W - 1.2, W)):
            mb.box((x0, ya, 0.0), (x1, yb, 10.85), "marble", chamfer=0.12, cham_col="marble_hi",
                   flat=("-x", "+x", "-z"), part="Pilaster")
    for ya, yb in both(Y_FRONT - 0.3, Y_FRONT + 0.1):
        for x0, x1 in ((0.0, 3.0), (W - 3.0, W)):
            mb.box((x0, ya, 0.0), (x1, yb, 0.97), "ink", chamfer=0.12, cham_col="ink_hi",
                   flat=("-x", "+x", "-z"), part="Plinth")
    return k.finalize(mb, pivot=(0, 0, 0))


DOOR_R = RH - 0.1
HINGE = (1.9, -0.75)      # hinge axis (x, y)


def door(k):
    mb = k.MB("VaultDoor_Door")
    prof = [(0, -1.75), (DOOR_R - 0.25, -1.75), (DOOR_R, -1.5), (DOOR_R, 0.15), (DOOR_R - 0.15, 0.3),
            (3.45, 0.3), (3.45, 0.42), (3.3, 0.57), (2.25, 0.57), (2.1, 0.42), (0, 0.42)]
    cols = ["steel_lo", "steel_lo", "steel_lo", "steel_hi", "steel", "steel", "steel_hi", "steel", "steel", "steel_lo"]
    body = mb.lathe(prof, SEG, cols, centre(0), FWD, part="Body")
    mb.clip((0, 0, 0), (0, 0, 1), "steel_lo", part_verts=body)
    for a in (0, 45, 90, 135, 210, 330):
        d = (math.cos(math.radians(a)), 0, math.sin(math.radians(a)))
        mb.cylinder(centre(-0.7), d, 0.3, DOOR_R - 0.4, DOOR_R + 0.6, 8, "steel_hi", chamfer=0.06,
                    cham_col="steel_hi", part=f"Bolt_{a}")
    hx, hy = HINGE
    mb.cylinder((hx, hy, 0.0), (0, 0, 1), 0.5, 1.05, 6.3, 12, "steel", chamfer=0.08, cham_col="steel_hi", part="Barrel")
    for z0 in (C[1] - 1.9, C[1] + 1.1):
        mb.box((hx, -1.25, z0), (4.4, -0.8, z0 + 0.8), "steel", chamfer=0.07, cham_col="steel_hi", part="Arm")
        mb.box((4.1, -1.25, z0), (4.8, -0.5, z0 + 0.8), "steel", chamfer=0.07, cham_col="steel_hi", part="Mount")
    return k.finalize(mb, pivot=(hx, hy, 0.0))


DIAL_H = 0.42             # door recess face, in front of the frame face


def dial(k):
    mb = k.MB("VaultDoor_Dial")
    c0 = centre(DIAL_H)
    mb.lathe([(0, -0.07), (1.0, -0.07), (1.0, 0.30), (0.85, 0.45), (0.45, 0.45), (0.45, 0.58), (0.35, 0.68), (0, 0.68)],
             32, ["steel_lo", "steel", "steel_hi", "steel", "steel", "steel_hi", "steel_hi"], c0, FWD, part="Hub")
    for a in (45, 135, 225, 315):
        d = (math.cos(math.radians(a)), 0, math.sin(math.radians(a)))
        hub = centre(DIAL_H + 0.53)
        mb.cylinder(hub, d, 0.15, 0.7, 2.6, 8, "steel", part=f"Spoke_{a}")
        kc = (hub[0] + 2.75 * d[0], hub[1], hub[2] + 2.75 * d[2])
        mb.sphere(kc, 0.3, 8, 5, "steel_hi", axis=d, part=f"Knob_{a}")
    return k.finalize(mb, pivot=c0)


def dial_ring(k):
    mb = k.MB("VaultDoor_DialRing")
    c0 = centre(DIAL_H)
    mb.lathe([(1.25, -0.04), (1.75, -0.04), (1.75, 0.10), (1.65, 0.20), (1.35, 0.20), (1.25, 0.10)], 24,
             ["marble", "marble", "marble_hi", "marble_hi", "marble_hi", "marble"], c0, FWD, closed=True, part="Ring")
    return k.finalize(mb, pivot=c0)


def build(k):
    fr, dr, di, ri = frame(k), door(k), dial(k), dial_ring(k)
    return k.Asset("VaultDoor_Greybox", [
        k.Obj(fr, "medium", role="hero", symmetric="X", pivot="point", collision="PreciseConvexDecomposition",
              notes="origin = wall grid corner; needs the round opening in its collision (or invisible Box colliders)"),
        k.Obj(dr, "medium", role="hero", pivot="point", collision="Hull",
              notes="origin = hinge axis at floor level; rotate about Roblox Y to open"),
        k.Obj(di, "small", role="hero", symmetric="XZ", pivot="point", collision="Box", can_collide=False,
              notes="origin = wheel axis; spin about the door normal"),
        k.Obj(ri, "small", role="hero", symmetric="XZ", pivot="point", collision="Box", material="Neon",
              can_collide=False, cast_shadow=False, tint="Warm Marble #D8C8A8 idle; opener's clone hue; Alarm Red",
              notes="Neon, TextureID cleared, Color driven by code"),
    ], budget_cls="hero",
        seats=[("VaultDoor_Door", "VaultDoor_Frame"), ("VaultDoor_Dial", "VaultDoor_Door"),
               ("VaultDoor_DialRing", "VaultDoor_Door")],
        align=[("VaultDoor_Dial", "VaultDoor_Door", "XZ", centre(DIAL_H)),
               ("VaultDoor_DialRing", "VaultDoor_Door", "XZ", centre(DIAL_H)),
               ("VaultDoor_Frame:Bezel", "VaultDoor_Frame", "X", centre(0))],
        notes="Greybox pass 1 toward the golden vault door. Import as one Model; keep the 4 pivots.")
