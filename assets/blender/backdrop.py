"""Backdrop kit (PLAN_STEAM_PLUS 4.1 W4, roblox_quality 2.1 L2/L3): the skyline rings round every heist and the garage.

Build: python3 tools/blender/build_asset.py assets/blender/backdrop.py
Skyline_Near (radius 300, heights 30-58) and Skyline_Far (radius 600, heights 56-104, bluer, sparser windows): one
QUARTER arc each (Blender angles 0-90 deg about the origin), so the client places four rotated copies of one mesh
(instanced: one draw call per mesh). Each building is one closed stepped prism whose broad face looks at the ring
centre (the only face a player ever sees); the lit windows are a second object (Neon, Bulb Warm #F6C0A2: the
PLAN 3.1 "windows away from the play floor" exception to "nothing glows"), seated 0.05 into the facades.
Origin = the ring centre on the ground (a "point" pivot): Model:PivotTo(CFrame(centre) * yaw) places a quarter.
Deterministic (seeded random), so a rebuild without a change keeps the FBX byte for byte.
"""
import math
import random

RINGS = {
    # name: radius of the inner faces, building widths / depths / heights (studs), floor height and window column
    # pitch, window size, share of lit windows, colours (facade = the inner face, sides, roof)
    "Near": dict(r=300.0, widths=(22, 40), depth=(18, 28), heights=(30, 58), floor=8.0, pitch=6.0, win=(3.2, 4.4),
                 lit=0.2, gap=(3, 9), face="ink_hi", side="ink", roof="steel_lo", seed=11, cls="medium",
                 wcls="hero"),
    "Far": dict(r=600.0, widths=(34, 62), depth=(26, 40), heights=(56, 104), floor=10.0, pitch=8.0, win=(4.4, 6.0),
                lit=0.11, gap=(4, 14), face="steel_lo", side="ink_hi", roof="steel", seed=23, cls="medium",
                wcls="hero"),
}


def profile(rng, w, h):
    """A stepped skyline profile in the (x, z) plane, x from -w/2 to w/2, counter-clockwise from bottom left.
    Returns (points, edge colour keys: 'side' | 'roof' | 'base') and the roof height at each x (for windows)."""
    kind = rng.choice(("flat", "setback", "setback", "twin", "slim"))
    a, b = -w / 2, w / 2
    if kind == "flat":
        pts = [(a, 0), (b, 0), (b, h), (a, h)]
        cols = ["base", "side", "roof", "side"]
    elif kind == "setback":
        s = rng.uniform(0.22, 0.34) * w
        h1 = h * rng.uniform(0.62, 0.78)
        if rng.random() < 0.5:   # setback on the right
            pts = [(a, 0), (b, 0), (b, h1), (b - s, h1), (b - s, h), (a, h)]
        else:
            pts = [(a, 0), (b, 0), (b, h), (a + s, h), (a + s, h1), (a, h1)]
        cols = ["base", "side", "roof", "side", "roof", "side"]
    elif kind == "twin":
        s = rng.uniform(0.18, 0.26) * w
        h1 = h * rng.uniform(0.7, 0.85)
        pts = [(a, 0), (b, 0), (b, h1), (b - s, h1), (b - s, h), (a + s, h), (a + s, h1), (a, h1)]
        cols = ["base", "side", "roof", "side", "roof", "side", "roof", "side"]
    else:   # slim tower with a stepped crown
        c = w * 0.18
        pts = [(a, 0), (b, 0), (b, h * 0.9), (b - c, h * 0.9), (b - c, h), (a + c, h), (a + c, h * 0.9), (a, h * 0.9)]
        cols = ["base", "side", "roof", "side", "roof", "side", "roof", "side"]

    def roof_at(x):
        top = 0.0
        n = len(pts)
        for i in range(n):
            (x0, z0), (x1, z1) = pts[i], pts[(i + 1) % n]
            if abs(z0 - z1) < 1e-9 and z0 > 0 and min(x0, x1) - 1e-9 <= x <= max(x0, x1) + 1e-9:
                top = max(top, z0)
        return top
    return pts, cols, roof_at


def ring(k, name):
    c = RINGS[name]
    rng = random.Random(c["seed"])
    body = k.MB(f"Skyline_{name}")
    wins = k.MB(f"Skyline_{name}_Windows")
    col = {"base": c["side"], "side": c["side"], "roof": c["roof"]}
    ang = 0.0
    end = math.pi / 2
    count = 0
    while True:
        w = rng.uniform(*c["widths"])
        d = rng.uniform(*c["depth"])
        h = rng.uniform(*c["heights"])
        r = c["r"] + rng.uniform(-6, 6)
        half = math.atan2(w / 2, r)
        theta = ang + half
        if theta + half > end - 1e-6:
            break
        pts, cols, roof_at = profile(rng, w, h)
        # the prism: x along the facade, extruded along +y (away from the centre) from y = 0 (the facade) to d
        vs = body.prism(pts, "Y", 0.0, d, [col[x] for x in cols], c["face"], part=f"B{count}")
        # lit windows on the facade (y < 0 side), a grid by floors and columns; a few rows dark, a few lit
        nx = max(1, int((w - 2.0) // c["pitch"]))
        x0 = -(nx - 1) * c["pitch"] / 2
        wv = []
        floors = int((h - 4.0) // c["floor"])
        for f in range(floors):
            z = 3.0 + f * c["floor"]
            if rng.random() < 0.25:
                continue   # a whole dark floor (offices closed)
            for i in range(nx):
                x = x0 + i * c["pitch"]
                if rng.random() > c["lit"] * 2.2:
                    continue
                ww, wh = c["win"]
                if z + wh > roof_at(x - ww / 2) - 1.0 or z + wh > roof_at(x + ww / 2) - 1.0:
                    continue
                wv += wins.box((x - ww / 2, -0.25, z), (x + ww / 2, 0.05, z + wh), "white")
        phi = math.degrees(theta) - 90.0     # local +y (outward) -> the radial direction at theta
        for verts in (vs, wv):
            if verts:
                wins.rotate(verts, phi) if verts is wv else body.rotate(verts, phi)
                (wins if verts is wv else body).move(verts, (r * math.cos(theta), r * math.sin(theta), 0.0))
        ang = theta + half + math.atan2(rng.uniform(*c["gap"]), r)
        count += 1
    ob = k.finalize(body, shading="flat", pivot=(0, 0, 0))
    wo = k.finalize(wins, shading="flat", pivot=(0, 0, 0))
    return k.Asset(f"Skyline_{name}", [
        k.Obj(ob, c["cls"], role="env", pivot="point", collision="Box", can_collide=False, cast_shadow=False, on_floor=True,
              notes=f"backdrop skyline quarter arc, facades at radius {c['r']:.0f} facing the centre; client places "
                    "4 copies (yaw 0/90/180/270 + the ring's yaw0); visual only"),
        k.Obj(wo, c["wcls"], role="env", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, tint="Bulb Warm #F6C0A2", free_shells=True,
              notes="lit windows (Neon, Bulb Warm; fixed). The only glow of the backdrop (PLAN 3.1 exception)"),
    ], seats=[(f"Skyline_{name}_Windows", f"Skyline_{name}")],
        notes=f"Skyline {name}: {count} buildings on a quarter arc, radius {c['r']:.0f}; windows {c['win'][0]}x{c['win'][1]}.")


def build(k):
    return [ring(k, "Near"), ring(k, "Far")]
