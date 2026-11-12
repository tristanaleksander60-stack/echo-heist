"""Advent ornaments (Christmas layer trophies, MASTERPLAN 4.3): each daily-vault first clear hangs a named ornament on
the van's tree (Xmas_Tree hooks) or stands on the van shelf (Ornament_Stand). Six original shapes. Bauble, Bell and
Star are TINTABLE: drawn on the tint cell (white) with Snow / light-steel shade bands, so MeshPart.Color sets their
colour family; VaultDoor, Donut and Van keep fixed atlas colours. eh_palette.ORNAMENT_DAYS gives every advent day
(Dec 3-24) its own (mesh, Color) look: 22 days, 22 distinct ornaments (manifest `ornamentDays`).

Build: python3 tools/blender/build_asset.py assets/blender/ornaments.py
Each ornament's origin is its HANG POINT (the top of its loop): place it on a tree hook or on the stand's arm.
They are authored side by side along X only so the turntable shows them apart; code clones them by name.
Shapes: Bauble, Star, Bell, VaultDoor (the bank's vault in miniature), Donut (Gus's Donut, the running joke),
Van (the crew's van). No gold: gold is loot only, and ornaments are trophies.
"""
import math
import _kitlib as L
from mathutils import Matrix, Vector

SPACING = 1.8


def _loop(mb, x, part="Loop"):
    """Hanging loop: a small steel ring whose top is the hang point (x, 0, 0)."""
    path = [(x + 0.13 * math.cos(math.radians(-65 + 310 * i / 10)), 0.0, -0.13 + 0.13 * math.sin(math.radians(-65 + 310 * i / 10)))
            for i in range(11)]   # open at the bottom: the ends sink into the ornament's cap (no overlapping end caps)
    return L.tube(mb, path, 0.035, 4, "steel_hi", part=part, normal=(0, 1, 0))


def _cap(mb, x, z_top, part="Cap"):
    return mb.cylinder((x, 0, z_top - 0.16), (0, 0, 1), 0.13, 0.0, 0.16, 8, "steel_hi", part=part)


def bauble(k, x):
    mb = k.MB("Ornament_Bauble")
    _loop(mb, x); _cap(mb, x, -0.22)
    r, cz = 0.48, -0.22 - 0.16 - 0.46
    prof = [(r * math.sin(math.pi * i / 8), -r * math.cos(math.pi * i / 8)) for i in range(9)]
    prof[0] = (0, prof[0][1]); prof[-1] = (0, prof[-1][1])
    cols = ["snow", "snow", "white", "steel_hi", "steel_hi", "white", "white", "white"]   # tinted by Color
    mb.lathe(prof, 12, cols, (x, 0, cz), part="Ball")
    return k.finalize(mb, pivot=(x, 0, 0))


def star(k, x):
    mb = k.MB("Ornament_Star")
    _loop(mb, x)
    pts = []
    for i in range(10):
        a = math.pi / 2 + math.pi * i / 5
        rr = 0.55 if i % 2 == 0 else 0.24
        pts.append((x + rr * math.cos(a), -0.16 - 0.55 + rr * math.sin(a)))
    mb.prism(pts, "Y", -0.1, 0.1, ["white"] * 10, "white", chamfer=0.04, cham_col="snow", cham_edges=list(range(10)), part="Star")
    return k.finalize(mb, pivot=(x, 0, 0))


def bell(k, x):
    mb = k.MB("Ornament_Bell")
    _loop(mb, x)
    top = -0.2
    prof = [(0, top), (0.16, top), (0.22, top - 0.12), (0.26, top - 0.45), (0.36, top - 0.72), (0.52, top - 0.86), (0.52, top - 0.94),
            (0.4, top - 0.94), (0, top - 0.94)]
    mb.lathe(prof, 12, ["white", "white", "white", "white", "white", "snow", "snow", "snow"], (x, 0, 0), part="Bell")
    mb.sphere((x, 0, top - 0.98), 0.13, 6, 4, "steel_hi", part="Clapper")
    mb.sphere((x, -0.18, top - 0.08), 0.12, 6, 4, "snow", part="Knot")
    return k.finalize(mb, pivot=(x, 0, 0))


def vault(k, x):
    mb = k.MB("Ornament_VaultDoor")
    _loop(mb, x); _cap(mb, x, -0.22)
    c = (x, 0, -0.22 - 0.16 - 0.5)
    mb.cylinder(c, (0, -1, 0), 0.52, -0.1, 0.1, 16, "steel", chamfer=0.04, cham_col="steel_hi", part="Disc")
    mb.lathe([(0.38, 0.08), (0.48, 0.08), (0.48, 0.15), (0.38, 0.15)], 16, "steel_hi", c, (0, -1, 0), closed=True, part="Rim")
    for a in (45, 135, 225, 315):
        d = (math.cos(math.radians(a)), 0, math.sin(math.radians(a)))
        mb.cylinder((c[0], c[1] - 0.16, c[2]), d, 0.035, 0.0, 0.32, 4, "steel_hi", part=f"Spoke_{a}")
    mb.cylinder(c, (0, -1, 0), 0.1, 0.08, 0.2, 8, "ink_hi", part="Hub")
    return k.finalize(mb, pivot=(x, 0, 0))


def donut(k, x):
    """Gus's Donut: icing on the front half, dough at the back and rim, sprinkles on the icing."""
    mb = k.MB("Ornament_Donut")
    _loop(mb, x)
    c = (x, 0, -0.2 - 0.12 - 0.46)
    R, r, n, m = 0.33, 0.17, 14, 8
    rings = []
    for i in range(n):
        a = 2 * math.pi * i / n
        ring = []
        for j in range(m):
            b = 2 * math.pi * j / m
            d = Vector((math.cos(a), 0, math.sin(a)))
            p = Vector(c) + d * (R + r * math.cos(b)) + Vector((0, -1, 0)) * (r * math.sin(b))
            ring.append(mb.v(tuple(p)))
        rings.append(ring)
    for i in range(n):
        for j in range(m):
            b = 2 * math.pi * (j + 0.5) / m
            col = "marble_hi" if math.sin(b) > -0.2 else "wood_hi"   # icing faces -Y (front) and the outer rim top
            mb.f([rings[i][j], rings[i][(j + 1) % m], rings[(i + 1) % n][(j + 1) % m], rings[(i + 1) % n][j]], col)
    for i, col in enumerate(("ribbon", "holly", "ribbon_hi", "holly", "ribbon", "holly")):
        a = 2 * math.pi * (i + 0.3) / 6
        p = Vector(c) + Vector((math.cos(a), 0, math.sin(a))) * R + Vector((0, -r - 0.01, 0))
        mb.box((p.x - 0.05, p.y - 0.03, p.z - 0.02), (p.x + 0.05, p.y + 0.03, p.z + 0.02), col, part=f"Sprinkle_{i}")
    mb.cylinder((x, 0, c[2] + R + r - 0.04), (0, 0, 1), 0.04, 0.0, 0.14, 4, "steel_hi", part="Wire")   # loop to donut
    return k.finalize(mb, pivot=(x, 0, 0))


def van(k, x):
    mb = k.MB("Ornament_Van")
    _loop(mb, x)
    z1 = -0.2 - 0.06
    mb.box((x - 0.55, -0.25, z1 - 0.55), (x + 0.3, 0.25, z1), "snow", chamfer=0.05, cham_col="snow", part="Box")
    mb.box((x + 0.3, -0.25, z1 - 0.55), (x + 0.6, 0.25, z1 - 0.2), "snow", chamfer=0.05, cham_col="snow", part="Cab")
    mb.box((x + 0.32, -0.27, z1 - 0.38), (x + 0.5, 0.27, z1 - 0.22), "ink_hi", part="Window")
    mb.box((x - 0.55, -0.27, z1 - 0.38), (x + 0.3, -0.24, z1 - 0.3), "ink", part="Band")
    for wx in (x - 0.35, x + 0.35):
        mb.cylinder((wx, 0, z1 - 0.58), (0, 1, 0), 0.12, -0.27, 0.27, 8, "ink", part="Wheels")
    mb.cylinder((x, 0, z1 - 0.02), (0, 0, 1), 0.04, 0.0, 0.1, 4, "steel_hi", part="Wire")
    return k.finalize(mb, pivot=(x, 0, 0))


def stand(k, x):
    mb = k.MB("Ornament_Stand")
    mb.cylinder((x, 0, 0), (0, 0, 1), 0.45, 0.0, 0.12, 12, "wood_lo", chamfer=0.04, cham_col="wood", part="Base")
    mb.cylinder((x, 0, 0.1), (0, 0, 1), 0.05, 0.0, 1.95, 6, "steel", part="Post")
    mb.cylinder((x, 0, 2.0), (1, 0, 0), 0.045, -0.04, 0.5, 6, "steel", part="Arm")
    mb.sphere((x, 0, 2.05), 0.08, 6, 4, "steel_hi", part="Finial")
    return k.finalize(mb, pivot=(x, 0, 0))


def build(k):
    xs = [SPACING * i for i in range(7)]
    makers = [bauble, star, bell, vault, donut, van]
    tintable = {"Ornament_Bauble", "Ornament_Star", "Ornament_Bell"}
    objs = []
    for f, x in zip(makers, xs):
        ob = f(k, x)
        tinted = ob.name in tintable
        objs.append(k.Obj(ob, "small", role="xmas", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
                          layer="xmas", tags=["EH_Ornament"], extra={"tintable": True} if tinted else None,
                          tint="MeshPart.Color = the day's ornament colour (manifest ornamentDays)" if tinted else None,
                          notes="origin = hang point (top of the loop)" + ("; tintable (atlas tint cell)" if tinted else "")))
    objs.append(k.Obj(stand(k, xs[6]), "small", role="xmas", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
                      layer="xmas", tags=["EH_Ornament"], extra={"hangPoint": k.roblox_point((0.46, 0.0, 1.96))},
                      notes="shelf stand; an ornament's origin goes on the arm's hang point"))
    return k.Asset("Ornaments", objs,
                   notes="Advent ornaments: Bauble, Star, Bell, VaultDoor, Donut (Gus's), Van, plus a shelf stand. Origin = hang point.")
