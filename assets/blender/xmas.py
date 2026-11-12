"""Christmas dressing layer (MASTERPLAN 4.3 "Steal Back Christmas", Dec 3 - Jan 4): Xmas_Garland_8, Xmas_Lights_8
(+ bulbs), Xmas_Wreath, Xmas_SnowCap_8, Xmas_SnowPile, Xmas_Tree (+ lights). Every piece is manifest layer "xmas":
the server clones them only while the dressing is on (by server date), so switching the layer off is "do not
clone", never a republish. LaserEmitter_CandyCane (mechanisms.py), Gus_SantaHat (gus.py) and the ornaments
(ornaments.py) belong to the same layer.

Build: python3 tools/blender/build_asset.py assets/blender/xmas.py
Placement: the wall pieces (Garland, Lights, SnowCap) are authored in WALL MODULE coordinates: give them the same
CFrame as the Wall_8x12 (or Wall_Window / Wall_Door / Storefront cell) they dress, and they hang under its crown
on the front face (the snow cap sits on its cut-away top: exterior walls only). The wreath's origin is its back
centre (on a wall face or a door leaf). Tree and snow pile: bottom centre.
Colours: Holly Green / Ribbon Burgundy / Snow only here; fairy lights are warm white Neon (never Alarm Red,
STYLE_BIBLE 1.3); the tree's ornaments are the advent trophies (ornaments.py), hung on the 22 `hooks`.
"""
import math, random
import _kitlib as L
from mathutils import Matrix, Vector

CROWN_UNDER = 10.95    # wall crown underside (the pin line for garlands and lights)


def _bow(mb, at, scale=1.0, part="Bow"):
    """A chunky ribbon bow (two fat loops, a knot, two short tails) facing -Y at point `at`."""
    x, y, z = at
    out = []
    for sgn in (-1, 1):
        path = [(x + sgn * (0.1 + 0.34 * scale * (1 - math.cos(math.pi * i / 5))), y - 0.05, z + 0.3 * scale * math.sin(math.pi * i / 5))
                for i in range(6)]
        out += L.tube(mb, path, 0.16 * scale, 5, "ribbon", cols=["ribbon_hi" if i in (2, 3) else "ribbon" for i in range(6)],
                      part=part, normal=(0, 1, 0))
        tail = [(x + sgn * 0.08, y - 0.1, z - 0.05), (x + sgn * 0.3 * scale, y - 0.12, z - 0.5 * scale)]
        out += L.tube(mb, tail, [0.14 * scale, 0.1 * scale], 4, "ribbon", part=part)
    out += mb.sphere((x, y - 0.12, z), 0.2 * scale, 6, 4, "ribbon_hi", part=part)
    return out


def _puffs(mb, path, part):
    """Fluffy foliage: a chain of overlapping low-poly puffs along a path (big dark, small light, alternating)."""
    out = []
    for i, (x, y, z) in enumerate(path):
        big = i % 2 == 0
        out += mb.sphere((x, y - (0.0 if big else 0.12), z + (0.0 if big else 0.06)), 0.4 if big else 0.3, 5, 3,
                         "holly_lo" if big else "holly", part=f"{part}_{i}")
    return out


# ---------------------------------------------------------------- garland

def garland(k):
    mb = k.MB("Xmas_Garland_8")
    y = 0.3 - 0.36       # the puffs touch the upper wall face (core face y = 0.3)
    for x0 in (0.0, 4.0):   # one swag of overlapping puffs per 4 studs; bows hide the pins
        path = [(x, y, z) for x, z in L.catenary(x0, x0 + 4.0, CROWN_UNDER - 0.25, 0.95, 9)][:-1]
        _puffs(mb, path, f"Swag_{x0:.0f}")
    for x in (0.0, 4.0):   # no bow at x = 8: the next module's x = 0 bow covers that pin (no doubled bows in a run)
        _bow(mb, (x, y - 0.3, CROWN_UNDER - 0.35), 1.0, part=f"Bow_{x:.0f}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Xmas_Garland_8", [k.Obj(ob, "module", role="xmas", pivot="point", collision="Box", can_collide=False,
                                            cast_shadow=False, layer="xmas", tags=["EH_Xmas"], sim="none",
                                            notes="wall-module coordinates: same CFrame as the Wall_8x12 it dresses")],
                   notes="Christmas garland for an 8-stud wall: two puffy swags under the crown, Ribbon bows at x 0 and 4.")


# ---------------------------------------------------------------- string lights

def lights(k):
    mw = k.MB("Xmas_Lights_8")
    y = 0.3 - 0.12
    pts = []
    for x0 in (0.0, 4.0):
        sw = L.catenary(x0, x0 + 4.0, CROWN_UNDER - 0.08, 0.7, 12)
        pts += sw if not pts else sw[1:]
    path = [(x, y, z) for x, z in pts]
    L.tube(mw, path, 0.07, 5, "ink", part="Wire")
    for x in (0.0, 4.0, 8.0):   # clips on the crown underside
        mw.box((x - 0.12, y - 0.12, CROWN_UNDER - 0.2), (x + 0.12, 0.31, CROWN_UNDER + 0.02), "ink_hi", part="Clip")
    ob = k.finalize(mw, pivot=(0, 0, 0))
    mbulb = k.MB("Xmas_Lights_8_Bulbs")
    # 12 bulbs hanging from the wire: socket nub at the wire, bulb below (a short capsule)
    n = 10
    for i in range(n):
        t = (i + 0.5) / n
        x = 8.0 * t
        sw = 4.0 if x >= 4.0 else 0.0
        u = (x - sw) / 4.0
        z = CROWN_UNDER - 0.08 - 0.7 * 4 * u * (1 - u)
        mbulb.sphere((x, y, z - 0.3), 0.19, 6, 3, "white", part=f"Bulb_{i}")
        mbulb.cylinder((x, y, z - 0.3), (0, 0, 1), 0.1, 0.0, 0.32, 4, "white", part=f"Neck_{i}")
    bl = k.finalize(mbulb, pivot=(0, 0, 0))
    return k.Asset("Xmas_Lights_8", [
        k.Obj(ob, "small", role="xmas", pivot="point", collision="Box", can_collide=False, cast_shadow=False, layer="xmas",
              tags=["EH_Xmas"], sim="none", notes="wire + clips; wall-module coordinates"),
        k.Obj(bl, "small", role="xmas", pivot="point", collision="Box", material="Neon", can_collide=False, cast_shadow=False,
              atlas=False, layer="xmas", free_shells=True, tint="Bulb Warm #F6C0A2 (eh_palette.NEON; a slow 2-step twinkle by brightness only)",
              notes="10 Neon bulbs; never Alarm Red"),
    ], seats=[("Xmas_Lights_8_Bulbs", "Xmas_Lights_8")],
        notes="Fairy lights for an 8-stud wall: two swags of dark wire, 10 warm-white Neon bulbs (own part).")


# ---------------------------------------------------------------- wreath

def wreath(k):
    mb = k.MB("Xmas_Wreath")
    R, n = 1.05, 18
    cz = 0.0
    # an open ring from -75 to 255 degrees: the gap at the bottom sits under the bow (no overlapping end caps)
    path = [(R * math.cos(math.radians(-75 + 330 * i / n)), -0.38, cz + R * math.sin(math.radians(-75 + 330 * i / n))) for i in range(n + 1)]
    radii = [0.42 if i % 2 == 0 else 0.33 for i in range(n + 1)]
    L.tube(mb, path, radii, 6, "holly_lo", cols=["holly" if i % 2 == 0 else "holly_lo" for i in range(n + 1)],
           cap_col="holly_lo", part="Ring", normal=(0, 1, 0))
    rnd = random.Random(12)
    for i in range(6):   # berries (Ribbon Burgundy: never Alarm Red)
        a = math.radians(20 + 300 * i / 6 + rnd.uniform(-8, 8))
        mb.sphere((R * 1.02 * math.cos(a), -0.72, cz + R * 1.02 * math.sin(a)), 0.14, 5, 3, "ribbon_hi", part=f"Berry_{i}")
    _bow(mb, (0.0, -0.75, cz - R - 0.1), 1.3, part="Bow")
    mb.box((-0.12, -0.1, cz + R + 0.1), (0.12, 0.0, cz + R + 0.65), "steel_lo", part="Hanger")   # nail strap to the wall
    ob = k.finalize(mb, pivot=(0, 0, cz))
    return k.Asset("Xmas_Wreath", [k.Obj(ob, "small", role="xmas", pivot="point", collision="Box", can_collide=False,
                                         cast_shadow=False, layer="xmas", tags=["EH_Xmas"], sim="none",
                                         notes="origin = back centre on the wall / door face; front faces -Y")],
                   notes="Wreath 3.3 across: puffy holly ring, Ribbon berries, a big Ribbon bow at the bottom.")


# ---------------------------------------------------------------- snow

def _blob(mb, cx, cy, sx, sy, h, seed, segs=12, rings=4, col="snow", part="Blob", z0=0.0):
    """A lumpy snow mound: a dome with deterministic radial jitter, flat bottom on z = z0."""
    rnd = random.Random(seed)
    jit = [rnd.uniform(0.85, 1.12) for _ in range(segs)]
    verts = []
    for r in range(rings):
        t = r / rings
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            k = math.cos(t * math.pi / 2)
            ring.append(mb.v((cx + sx * k * jit[j] * math.cos(a), cy + sy * k * jit[j] * math.sin(a), z0 + h * math.sin(t * math.pi / 2) * (0.92 + 0.08 * jit[(j + r) % segs]))))
        verts.append(ring)
    top = mb.v((cx, cy, z0 + h))
    bot = mb.v((cx, cy, z0))
    for r in range(rings - 1):
        for j in range(segs):
            q = (j + 1) % segs
            mb.f([verts[r][j], verts[r][q], verts[r + 1][q], verts[r + 1][j]], col)
    for j in range(segs):
        q = (j + 1) % segs
        mb.f([verts[rings - 1][j], verts[rings - 1][q], top], col)
        mb.f([bot, verts[0][q], verts[0][j]], "snow")
    return [v for R in verts for v in R] + [top, bot]


def snow_pile(k):
    mb = k.MB("Xmas_SnowPile")
    # pass 2: a long, low shovelled drift (the first three round mounds read as a lying animal at 64 px), a snow shovel
    # stuck in it and the crew's snowball stash: "somebody cleared the kerb"
    _blob(mb, 0.0, 0.0, 2.4, 1.2, 1.0, 3, segs=16, part="Main")
    _blob(mb, -0.9, 0.55, 1.3, 0.7, 1.25, 5, segs=10, part="Back")      # the heaped back of the drift (no "head" lumps)
    for i, (x, y, z) in enumerate(((1.5, 0.95, 0.3), (2.15, 0.95, 0.3), (1.82, 1.5, 0.3), (1.82, 1.13, 0.82))):
        mb.sphere((x, y, z), 0.33, 8, 5, "snow", part=f"Snowball_{i}")   # the crew's snowball stash (story detail)
    shovel = mb.cylinder((0, 0, 0.0), (0, 0, 1), 0.07, 0.0, 2.6, 6, "wood", part="Shaft")
    shovel += mb.box((-0.32, -0.06, 2.55), (0.32, 0.06, 2.72), "ink_hi", chamfer=0.03, part="Grip")
    shovel += mb.box((-0.5, -0.04, -0.75), (0.5, 0.04, 0.05), "steel", chamfer=0.03, cham_col="steel_hi", part="Blade")
    mb.rotate(shovel, 18, "Y")
    mb.move(shovel, (-0.75, 0.15, 0.55))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Xmas_SnowPile", [k.Obj(ob, "small", role="xmas", pivot="point", collision="Box", can_collide=False,
                                           cast_shadow=False, layer="xmas", tags=["EH_Xmas"], sim="none",
                                           notes="kerb / street dressing; walk-through (CanCollide off)")],
                   notes="Snow drift (about 5.5 x 3.3 x 1): a long shovelled drift, a snow shovel stuck in it, a snowball stash; never a floor field.")


def snow_cap(k):
    """Snow lying on the cut-away top of an exterior wall: a lumpy heightfield slab z 12 .. 12.5."""
    mb = k.MB("Xmas_SnowCap_8")
    nx, ny = 17, 5
    y0, y1 = -0.15, 2.15
    rnd = random.Random(21)
    top = [[None] * ny for _ in range(nx)]
    bot = [[None] * ny for _ in range(nx)]
    for i in range(nx):
        x = 8.0 * i / (nx - 1)
        for j in range(ny):
            y = y0 + (y1 - y0) * j / (ny - 1)
            edge = j in (0, ny - 1)
            end = i in (0, nx - 1)
            h = 0.06 if edge else (0.3 if end else 0.32 + 0.16 * math.sin(i * 1.3 + j) * rnd.uniform(0.5, 1.0))
            top[i][j] = mb.v((x, y, 12.0 + h))
            bot[i][j] = mb.v((x, y, 11.98))
    for i in range(nx - 1):
        for j in range(ny - 1):
            mb.f([top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]], "snow")
            mb.f([bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j], bot[i][j]], "snow")
    for i in range(nx - 1):   # front and back skirts
        mb.f([bot[i][0], bot[i + 1][0], top[i + 1][0], top[i][0]], "snow")
        mb.f([top[i][ny - 1], top[i + 1][ny - 1], bot[i + 1][ny - 1], bot[i][ny - 1]], "snow")
    for j in range(ny - 1):   # flat ends (tile along X like the walls)
        mb.f([bot[0][j + 1], bot[0][j], top[0][j], top[0][j + 1]], "snow")
        mb.f([top[nx - 1][j + 1], top[nx - 1][j], bot[nx - 1][j], bot[nx - 1][j + 1]], "snow")
    # a rounded lip drooping over the crown on the front face, and three drifts on top (big / medium / small)
    L.tube(mb, [(0.0, -0.18, 12.02), (8.0, -0.18, 12.02)], 0.17, 8, "snow", part="Lip")
    for cx, cy, sx, sy, h, sd in ((1.7, 1.0, 1.2, 0.7, 0.32, 31), (4.6, 0.8, 0.8, 0.55, 0.24, 37), (6.7, 1.2, 0.6, 0.45, 0.2, 41)):
        _blob(mb, cx, cy, sx, sy, h, sd, segs=8, rings=3, part="Drift", z0=12.2)
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset("Xmas_SnowCap_8", [k.Obj(ob, "small", role="xmas", pivot="point", collision="Box", can_collide=False,
                                            cast_shadow=False, layer="xmas", tags=["EH_Xmas"], sim="none",
                                            notes="wall-module coordinates; exterior shell walls only (the diorama's top edge)")],
                   tile_x=8.0, notes="Snow on an 8-stud wall top: lumpy slab, a drooping front lip, three drifts; flat ends so it tiles.")


# ---------------------------------------------------------------- tree

TIERS = [  # (base z, top z, radius, hooks on this tier)
    (1.35, 3.7, 2.05, 10), (2.75, 4.95, 1.6, 8), (4.0, 6.0, 1.12, 4)]


def tree(k):
    mb = k.MB("Xmas_Tree")
    # stand: a Ribbon pot with a cream rim, wood trunk
    mb.lathe([(0, 0.0), (1.0, 0.0), (1.15, 1.0), (1.3, 1.05), (1.3, 1.25), (1.05, 1.25), (0, 1.15)], 10,
             ["ribbon", "ribbon", "marble_hi", "marble", "marble", "wood_lo"], (0, 0, 0), part="Pot")
    mb.cylinder((0, 0, 1.1), (0, 0, 1), 0.3, 0.0, 0.5, 8, "wood", part="Trunk")
    hooks = []
    for ti, (z0, z1, r, nh) in enumerate(TIERS):
        prof = [(0, z1), (r, z0 + 0.15), (r - 0.18, z0), (0.3, z0 + 0.2), (0, z0 + 0.2)]
        mb.lathe(prof, 10, ["holly_lo", "holly", "holly_lo", "holly_lo"], (0, 0, 0), phase=ti * 0.3, part=f"Tier_{ti}")
        for h in range(nh):
            a = 2 * math.pi * (h + 0.5 * (ti % 2)) / nh
            rr = r * 0.92
            hooks.append(k.roblox_point((rr * math.cos(a), rr * math.sin(a), z0 + 0.12)))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    ml = k.MB("Xmas_Tree_Lights")
    star = []
    for i in range(10):
        a = math.pi / 2 + math.pi * i / 5
        rr = 0.62 if i % 2 == 0 else 0.27
        star.append((rr * math.cos(a), 6.35 + rr * math.sin(a)))
    ml.prism(star, "Y", -0.12, 0.12, "white", "white", part="Star")
    ml.cylinder((0, 0, 5.85), (0, 0, 1), 0.08, 0.0, 0.3, 6, "white", part="StarStem")
    for ti, (z0, z1, r, nh) in enumerate(TIERS):   # a few bulbs on each tier's rim, between the ornament hooks
        nb = nh // 2 + 2
        for b in range(nb):
            a = 2 * math.pi * (b + 0.25) / nb + ti
            ml.sphere(((r - 0.05) * math.cos(a), (r - 0.05) * math.sin(a), z0 + 0.12), 0.14, 5, 3, "white", part=f"Bulb_{ti}_{b}")
    lt = k.finalize(ml, pivot=(0, 0, 0))
    return k.Asset("Xmas_Tree", [
        k.Obj(ob, "small", role="xmas", pivot="bottom", collision="Box", can_collide=False, layer="xmas",
              tags=["EH_Xmas", "EH_OrnamentTree"], sim="none", extra={"hooks": hooks, "ornamentScale": 0.65},
              notes="van / garage tree: 22 hooks for the advent ornaments (Dec 3-24); ornaments hang at 0.65 size here "
                    "(Size * 0.65, then PivotTo the hook: full size they reach the floor and crowd the tiers)"),
        k.Obj(lt, "small", role="xmas", pivot="point", collision="Box", material="Neon", can_collide=False, cast_shadow=False,
              atlas=False, layer="xmas", free_shells=True, tint="Bulb Warm #F6C0A2 (eh_palette.NEON)", notes="star + rim bulbs, Neon"),
    ], seats=[("Xmas_Tree_Lights", "Xmas_Tree")],
        notes="Small Christmas tree (6.97 tall): three holly tiers, Ribbon pot; Neon star and bulbs; 22 ornament hooks.")


def build(k):
    return [garland(k), lights(k), wreath(k), snow_cap(k), snow_pile(k), tree(k)]
