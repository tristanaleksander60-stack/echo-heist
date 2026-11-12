"""Golden asset (hero, golden pass 2026-11-12): the round Vault Door, as 5 MeshParts in one Model "VaultDoor".

Build: python3 tools/blender/build_asset.py assets/blender/vault_door.py
Brief: hero (assembly target 10,000 / ceiling 20,000; golden pass 8-10k). Separate pieces because code moves them:
the door swings on its hinge, the wheel spins, the ring glows in the opener's hue, the combination face spins with
the wheel and its numbers glow (emissive mask: the one hero SurfaceAppearance of this asset).

  VaultDoor_Frame    16 x 12 module in the wall line (4 grid cells). Origin = the wall grid corner (0, 0, 0), the
                     same rule as the walls; the frame overhangs the wall faces by 0.25 to cap the trims. Opening: a
                     9-stud circle cut flat by the floor (5.4-stud threshold, no lip). Stepped two-tier bezel, a
                     9-rivet arc, a keystone, a name plaque (SurfaceGui "HOARDSWORTH & CO." by code), raised panels.
  VaultDoor_Door     4.4-radius stepped door: a 24-bolt face ring, a groove ring, 8 locking bolts, a 3-knuckle hinge.
                     The back (seen when it swings open) shows the bolt mechanism: 8 bars from a gear hub.
                     Origin = the hinge axis at floor level, so `PivotTo` + a yaw tween opens it.
  VaultDoor_Dial     4-spoke wheel on a drum hub. Origin = wheel axis on the door face (spin about the door normal).
  VaultDoor_DialFace combination face on the hub (0-90 numbers, 100 ticks). Hero SurfaceAppearance: ColorMap +
                     RoughnessMap + EmissiveMask (assets/textures/VaultDoor_DialFace_*.png, 1024); EmissiveTint follows
                     the ring colour. Same origin as the Dial (it spins with it).
  VaultDoor_DialRing glow ring under the wheel. Studio: Neon, Color set by code (Warm Marble idle, the opener's
                     clone hue while opening, Alarm Red on alarm). TextureID cleared.
Palette (value ladder, dark to light): Ink Indigo frame face -> Vault Steel door -> light steel bezel, bolts and
chamfers -> glowing ring (focal). Marble cornice / pilasters and Ink plinths continue the wall trim lines.
"""
import math, os

W, H = 16.0, 12.0
Y_FRONT, Y_BACK = -0.25, 2.25
C = (8.0, 3.6)            # opening centre (x, z)
RH = 4.5                  # opening radius
SEG = 64                  # circle segments for the big round parts (r >= 4: 48+)
FWD = (0, -1, 0)          # door normal (front faces -Y)
HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.normpath(os.path.join(HERE, "..", "textures"))


def centre(h):
    """Point on the door axis, h studs in front of the frame's front face."""
    return (C[0], Y_FRONT - h, C[1])


def on_face(r, a_deg, h):
    """Point at radius r and angle a (0 = +X, 90 = up) on the door axis plane h studs in front of the frame face."""
    a = math.radians(a_deg)
    return (C[0] + r * math.cos(a), Y_FRONT - h, C[1] + r * math.sin(a))


# ---------------------------------------------------------------- frame

def frame(k):
    mb = k.MB("VaultDoor_Frame")
    a0 = math.degrees(math.atan2(-C[1], -math.sqrt(RH ** 2 - C[1] ** 2)))   # left chord end (negative angle)
    a1 = math.degrees(math.atan2(-C[1], math.sqrt(RH ** 2 - C[1] ** 2)))    # right chord end
    start, end = a0 % 360, a1
    n = max(8, round((start - end) / (360 / SEG)))
    arc = [(C[0] + RH * math.cos(math.radians(start - (start - end) * i / n)),
            C[1] + RH * math.sin(math.radians(start - (start - end) * i / n))) for i in range(n + 1)]
    poly = [(0.0, 0.0)] + arc + [(W, 0.0), (W, H), (0.0, H)]
    cols = ["ink"] + ["steel_lo"] * n + ["ink", "ink_hi", "plum_hi", "ink_hi"]   # top = cut-away cap, as the walls
    m = len(poly)
    mb.prism(poly, "Y", Y_FRONT, Y_BACK, cols, "ink_hi", chamfer=0.25, cham_col="plum_hi",
             cham_edges=[m - 3, m - 2, m - 1], part="Block")
    # two-tier bezel: a broad outer ring and a stepped inner lip (light steel catches the light around the door)
    bez = mb.lathe([(RH, -0.1), (RH, 0.3), (RH + 0.1, 0.42), (RH + 0.45, 0.42), (RH + 0.5, 0.55), (RH + 0.95, 0.55),
                    (RH + 1.05, 0.45), (RH + 1.25, 0.45), (RH + 1.32, 0.35), (RH + 1.32, -0.1)],
                   SEG, ["steel", "steel_hi", "steel_hi", "steel_hi", "steel_hi", "steel_hi", "steel", "steel_hi", "steel", "steel_lo"],
                   centre(0), FWD, closed=True, part="Bezel")
    mb.clip((0, 0, 0), (0, 0, 1), "steel_lo", part_verts=bez)
    for i in range(9):   # rivet arc over the bezel
        a = 18 + 18 * i
        p = on_face(6.25, a, 0.0)
        mb.cylinder(p, FWD, 0.27, -0.05, 0.28, 10, "steel_hi", chamfer=0.07, cham_col="steel_hi", part=f"Rivet_{a}")
    # keystone at the top of the bezel (marble): the "bank architecture" focal accent above the door
    ks = [(C[0] - 0.75, C[1] + RH + 1.15), (C[0] + 0.75, C[1] + RH + 1.15), (C[0] + 0.55, C[1] + RH + 0.2),
          (C[0] - 0.55, C[1] + RH + 0.2)]
    mb.prism([(x, z) for x, z in ks], "Y", Y_FRONT - 0.5, Y_FRONT + 0.1, ["marble_hi", "marble", "marble_lo", "marble"],
             "marble", chamfer=0.08, cham_col="marble_hi", cham_edges=[0, 1, 3], part="Keystone")
    # name plaque between the keystone and the cornice (SurfaceGui by code)
    mb.box((C[0] - 2.6, Y_FRONT - 0.32, 9.95), (C[0] + 2.6, Y_FRONT + 0.1, 10.75), "marble", chamfer=0.08, cham_col="marble_hi",
           flat=("+y",), part="PlaqueFrame")
    mb.box((C[0] - 2.4, Y_FRONT - 0.4, 10.05), (C[0] + 2.4, Y_FRONT - 0.3, 10.65), "ink", part="Plaque")
    # raised panels on the frame face, framing the portal low on both sides
    for x0, x1 in ((1.55, 2.95), (W - 2.95, W - 1.55)):
        mb.box((x0, Y_FRONT - 0.12, 1.3), (x1, Y_FRONT + 0.05, 4.2), "ink_hi", chamfer=0.06, cham_col="steel_lo", flat=("+y",), part="Panel")
    # Bank-kit trims on both faces: the cornice continues the wall crown line, the plinths continue the
    # baseboard, marble pilasters frame the portal (STYLE_BIBLE: one focal feature, framed by the kit).
    def both(y0, y1):
        return ((y0, y1), (Y_BACK - (y1 - Y_FRONT), Y_BACK + (Y_FRONT - y0)))
    for ya, yb in both(Y_FRONT - 0.45, Y_FRONT + 0.1):
        mb.box((0, ya, 10.8), (W, yb, H), "marble", chamfer=0.15, cham_col="marble_hi", flat=("-x", "+x"), part="Cornice")
    for ya, yb in both(Y_FRONT - 0.5, Y_FRONT + 0.1):
        for x0, x1 in ((0.0, 1.2), (W - 1.2, W)):
            mb.box((x0, ya, 0.0), (x1, yb, 10.85), "marble", chamfer=0.12, cham_col="marble_hi", flat=("-x", "+x", "-z"),
                   part="Pilaster")
            mb.box((x0 - 0.0, ya - 0.1, 4.35), (x1, yb + 0.1 if yb > 1 else yb, 4.85), "marble", chamfer=0.07,
                   cham_col="marble_hi", flat=("-x", "+x"), part="PilasterBand")
    for ya, yb in both(Y_FRONT - 0.3, Y_FRONT + 0.1):
        for x0, x1 in ((0.0, 3.0), (W - 3.0, W)):
            mb.box((x0, ya, 0.0), (x1, yb, 0.97), "ink", chamfer=0.12, cham_col="ink_hi", flat=("-x", "+x", "-z"), part="Plinth")
    return k.finalize(mb, pivot=(0, 0, 0))


# ---------------------------------------------------------------- door

DOOR_R = RH - 0.1
HINGE = (1.75, -0.95)     # hinge axis (x, y)


def door(k):
    mb = k.MB("VaultDoor_Door")
    prof = [(0, -1.75), (DOOR_R - 0.25, -1.75), (DOOR_R, -1.5), (DOOR_R, 0.15), (DOOR_R - 0.15, 0.3),
            (3.75, 0.3), (3.7, 0.24), (3.55, 0.24), (3.5, 0.3),             # groove ring
            (3.45, 0.3), (3.45, 0.42), (3.3, 0.57), (2.25, 0.57), (2.1, 0.42), (0, 0.42)]
    cols = ["steel_lo", "steel_lo", "steel_lo", "steel_hi", "steel", "steel_lo", "steel_lo", "steel_lo", "steel",
            "steel", "steel_hi", "steel", "steel", "steel_lo"]
    body = mb.lathe(prof, SEG, cols, centre(0), FWD, part="Body")
    mb.clip((0, 0, 0), (0, 0, 1), "steel_lo", part_verts=body)
    for i in range(24):   # bolt heads ring on the outer face band
        a = 7.5 + 15 * i
        p = on_face(4.02, a, 0.3)
        if p[2] < 0.35:
            continue
        mb.cylinder(p, FWD, 0.16, -0.04, 0.1, 6, "steel_hi", part=f"BoltHead_{i}")
    for a in (-30, 0, 30, 60, 90, 120, 150):   # locking bolts out of the latch side and top (none on the hinge side)
        d = (math.cos(math.radians(a)), 0, math.sin(math.radians(a)))
        mb.cylinder(centre(-0.75), d, 0.32, DOOR_R - 0.4, DOOR_R + 0.65, 10, "steel_hi", chamfer=0.07, cham_col="steel_hi",
                    part=f"Bolt_{a:.0f}")
    # back of the door: gear hub and 8 bars to the bolts (visible when it swings open)
    back = centre(-1.75)
    mb.cylinder(back, FWD, 1.1, -0.35, 0.02, 16, "steel", chamfer=0.08, cham_col="steel_hi", part="GearHub")
    for i in range(8):
        a = 22.5 + 45 * i
        bar = mb.box((0.9, -0.18, -0.2), (3.7, 0.18, 0.2), "steel_lo", chamfer=0.05, cham_col="steel", part=f"Bar_{i}")
        from mathutils import Matrix, Vector
        mb.xform(bar, Matrix.Translation(Vector(back) + Vector((0, 0.17, 0))) @ Matrix.Rotation(math.radians(-a), 4, "Y"))
    # hinge: barrel with 3 knuckles, two arms bolted to the door
    hx, hy = HINGE
    mb.cylinder((hx, hy, 0.0), (0, 0, 1), 0.48, 0.8, 6.6, 12, "steel", chamfer=0.08, cham_col="steel_hi", part="Barrel")
    for z0 in (0.75, 3.35, 5.95):
        mb.cylinder((hx, hy, z0), (0, 0, 1), 0.66, 0.0, 0.7, 12, "steel_hi", chamfer=0.08, cham_col="steel_hi", part="Knuckle")
    for z0 in (C[1] - 2.2, C[1] + 1.4):
        mb.box((hx, -1.35, z0), (4.6, -0.75, z0 + 0.8), "steel", chamfer=0.07, cham_col="steel_hi", part="Arm")
        mb.box((4.2, -1.4, z0 - 0.1), (5.0, -0.5, z0 + 0.9), "steel", chamfer=0.07, cham_col="steel_hi", part="Mount")
        for bx in (2.6, 3.6):
            mb.cylinder((bx, -1.35, z0 + 0.4), FWD, 0.15, -0.03, 0.08, 8, "steel_hi", part="ArmBolt")
    return k.finalize(mb, pivot=(hx, hy, 0.0))


# ---------------------------------------------------------------- wheel, combination face, ring

DIAL_H = 0.42             # door recess face, in front of the frame face
FACE = (0.45, 1.08)       # combination face annulus radii (on the hub drum's front)


def dial(k):
    mb = k.MB("VaultDoor_Dial")
    c0 = centre(DIAL_H)
    mb.lathe([(0, -0.07), (1.2, -0.07), (1.2, 0.3), (1.12, 0.42), (0, 0.42)], 32,
             ["steel_lo", "steel", "steel_hi", "steel_lo"], c0, FWD, part="Hub")
    mb.lathe([(0, 0.4), (0.44, 0.4), (0.44, 0.62), (0.36, 0.72), (0.12, 0.8), (0, 0.8)], 24,
             ["steel", "steel_hi", "steel_hi", "steel_hi", "steel_hi"], c0, FWD, part="Knob")
    for a in (45, 135, 225, 315):
        d = (math.cos(math.radians(a)), 0, math.sin(math.radians(a)))
        hub = centre(DIAL_H + 0.18)
        mb.cylinder(hub, d, 0.15, 1.1, 2.6, 10, "steel", part=f"Spoke_{a}")
        mb.cylinder(hub, d, 0.21, 1.1, 1.35, 10, "steel_hi", part=f"Collar_{a}")
        kc = (hub[0] + 2.78 * d[0], hub[1], hub[2] + 2.78 * d[2])
        mb.sphere(kc, 0.32, 10, 6, "steel_hi", axis=d, part=f"Knob_{a}")
    return k.finalize(mb, pivot=c0)


def dial_face_textures():
    """VaultDoor_DialFace_Color / _Roughness / _Emissive (1024): numbers 0-90 and 100 ticks on a steel annulus.
    Planar UV over the square [-1.1, 1.1]^2 around the wheel axis (u right, v up as seen from the front)."""
    from PIL import Image, ImageDraw, ImageFont
    S, R = 1024, 1.1
    def px(r):
        return r / R * S / 2
    col = Image.new("RGB", (S, S), (0x4E, 0x56, 0x75))          # steel_lo outside the face (never seen)
    rough = Image.new("L", (S, S), 140)
    emis = Image.new("L", (S, S), 0)
    dc, dr, de = ImageDraw.Draw(col), ImageDraw.Draw(rough), ImageDraw.Draw(emis)
    c = S / 2
    def disc(d, r, fill):
        d.ellipse([c - px(r), c - px(r), c + px(r), c + px(r)], fill=fill)
    disc(dc, FACE[1], (0x7C, 0x86, 0xA6)); disc(dc, 0.98, (0x2A, 0x2D, 0x52)); disc(dc, 0.62, (0x7C, 0x86, 0xA6))
    disc(dr, FACE[1], 110); disc(dr, 0.98, 170); disc(dr, 0.62, 110)
    font = None
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.isfile(f):
            font = ImageFont.truetype(f, int(px(0.13)))
            break
    font = font or ImageFont.load_default()
    for i in range(100):   # ticks: long every 10, mid every 5
        a = math.radians(90 - 3.6 * i)
        r0 = 0.9 if i % 10 == 0 else (0.93 if i % 5 == 0 else 0.95)
        p0 = (c + px(r0) * math.cos(a), c - px(r0) * math.sin(a))
        p1 = (c + px(0.98) * math.cos(a), c - px(0.98) * math.sin(a))
        w = 7 if i % 10 == 0 else 4
        for d, fill in ((dc, (0xED, 0xE2, 0xC8)), (dr, 200), (de, 255)):
            d.line([p0, p1], fill=fill, width=w)
    for i in range(10):
        a = math.radians(90 - 36 * i)
        txt = str(i * 10)
        x, y = c + px(0.76) * math.cos(a), c - px(0.76) * math.sin(a)
        for d, fill in ((dc, (0xED, 0xE2, 0xC8)), (dr, 200), (de, 255)):
            d.text((x, y), txt, fill=fill, font=font, anchor="mm")
    # index mark at 12 o'clock on the inner ring (glows too)
    for d, fill in ((dc, (0xED, 0xE2, 0xC8)), (de, 255)):
        d.polygon([(c, c - px(0.6)), (c - px(0.05), c - px(0.5)), (c + px(0.05), c - px(0.5))], fill=fill)
    os.makedirs(TEX, exist_ok=True)
    out = {}
    for name, im in (("Color", col), ("Roughness", rough), ("Emissive", emis)):
        p = os.path.join(TEX, f"VaultDoor_DialFace_{name}.png")
        im.save(p, optimize=True)
        out[name] = p
    return out


def dial_face(k):
    tex = dial_face_textures()
    mb = k.MB("VaultDoor_DialFace")
    c0 = centre(DIAL_H)
    mb.lathe([(FACE[0], 0.4), (FACE[1], 0.4), (FACE[1], 0.46), (FACE[0], 0.46)], 48, "white", c0, FWD, closed=True, part="Face")
    R = 1.1
    return k.finalize(mb, pivot=c0, planar=("X", "Z", C[0] - R, C[0] + R, C[1] - R, C[1] + R),
                      material=("EH_VaultDialFace", tex["Color"]))


def dial_ring(k):
    mb = k.MB("VaultDoor_DialRing")
    c0 = centre(DIAL_H)
    mb.lathe([(1.25, -0.04), (1.75, -0.04), (1.75, 0.10), (1.65, 0.20), (1.35, 0.20), (1.25, 0.10)], 32,
             ["marble", "marble", "marble_hi", "marble_hi", "marble_hi", "marble"], c0, FWD, closed=True, part="Ring")
    return k.finalize(mb, pivot=c0)


def build(k):
    fr, dr, di, df, ri = frame(k), door(k), dial(k), dial_face(k), dial_ring(k)
    return k.Asset("VaultDoor", [
        k.Obj(fr, "medium", role="hero", symmetric="X", pivot="point", collision="PreciseConvexDecomposition",
              tags=["EH_Wall"], sim="solid except the round opening (9-stud circle at local X -8, Y 3.6; 5.4 threshold); door box = the opening",
              extra={"opening": {"x": [-10.7, -5.3], "y": [0.0, 8.1], "shape": "circle r 4.5 at (X -8, Y 3.6), cut flat by the floor"}},
              notes="origin = wall grid corner; needs the round opening in its collision (or invisible Box colliders)"),
        k.Obj(dr, "medium", role="hero", pivot="point", collision="Hull", tags=["EH_Door"],
              sim="door: the 6 x 10 door box, solid only while SHUT; open = visual only (CanCollide off from the first "
                  "frame of the swing until it is shut again)",
              extra={"open": {"yawDeg": -175, "about": "this part's pivot (the hinge)", "swing": "outward (toward -Z), onto "
                              "the wall face on the viewer's left (+X)", "footprintMin": [-2.7, 0.0, -4.75],
                              "footprintMax": [9.6, 8.65, -0.2], "sweepRadius": 11.4,
                              "follow": ["VaultDoor_Dial", "VaultDoor_DialFace", "VaultDoor_DialRing"]}},
              notes="origin = hinge axis at floor level; open = PivotTo(hinge * CFrame.Angles(0, rad(-175), 0)), outward "
                    "(back shows the bolt mechanism); the dial parts follow with the same hinge transform"),
        k.Obj(di, "small", role="hero", symmetric="XZ", pivot="point", collision="Box", can_collide=False,
              notes="origin = wheel axis; spin about the door normal"),
        k.Obj(df, "small", role="hero", symmetric="XZ", pivot="point", collision="Box", can_collide=False,
              cast_shadow=False, texture="VaultDoor_DialFace",
              tint="SurfaceAppearance: ColorMap + RoughnessMap + EmissiveMaskContent; EmissiveTint = the ring colour (code)",
              notes="hero SurfaceAppearance (1 of <= 3 per level); spins with the wheel; numbers + ticks glow"),
        k.Obj(ri, "small", role="hero", symmetric="XZ", pivot="point", collision="Box", material="Neon",
              can_collide=False, cast_shadow=False, tint="Warm Marble shade #A8987A idle; opener's clone hue; Alarm Red (eh_palette.NEON)",
              notes="Neon, TextureID cleared, Color driven by code"),
    ], budget_cls="hero",
        seats=[("VaultDoor_Door", "VaultDoor_Frame"), ("VaultDoor_Dial", "VaultDoor_Door"),
               ("VaultDoor_DialFace", "VaultDoor_Dial"), ("VaultDoor_DialRing", "VaultDoor_Door")],
        align=[("VaultDoor_Dial", "VaultDoor_Door", "XZ", centre(DIAL_H)),
               ("VaultDoor_DialFace", "VaultDoor_Door", "XZ", centre(DIAL_H)),
               ("VaultDoor_DialRing", "VaultDoor_Door", "XZ", centre(DIAL_H)),
               ("VaultDoor_Frame:Bezel", "VaultDoor_Frame", "X", centre(0))],
        notes="Golden pass: stepped bezel, rivets, keystone + plaque, 24-bolt door face, bolt mechanism on the back, emissive combination face.")
