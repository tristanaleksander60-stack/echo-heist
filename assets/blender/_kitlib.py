"""Shared helpers for the kit spec scripts (not a spec: build_asset.py skips files that start with "_").

The wall section (STYLE_BIBLE 5.1 "Kit grid") lives here so every wall-line module (Wall, Wall_Window, Wall_Door,
Storefront, VaultDoor frame trims, Pillar) continues the same trim lines.

Section (front half, y = 0 is the front plane, the core is y 0.3 - 1.7):
  baseboard  0 - 0.97 high, proud 0.30, 0.12 chamfer     Ink Indigo
  wainscot   0.97 - 4.35, raised panels 3.0 x 2.35         Plum Slate deep, panels Plum Slate
  dado rail  4.35 - 4.85, proud 0.20, 0.07 chamfers        Warm Marble
  upper wall 4.85 - 10.95                                  Plum Slate (calm field for signs and props)
  crown      45-degree cove 10.95 - 11.25, face to 11.80, 0.2 chamfer, proud 0.30   Warm Marble
  top cap    the cut-away top seen by the diorama camera   Plum Slate light
"""
import math

H, D = 12.0, 2.0
CORE_F, CORE_B = 0.30, D - 0.30
DADO = (4.35, 4.85)
CROWN_Z = 10.95

FRONT = [  # (y, z) up the front face, with the colour of the edge that starts at that point
    ((0.00, 0.00), "ink"),        # baseboard face
    ((0.00, 0.85), "ink_hi"),     # baseboard chamfer (faces up)
    ((0.12, 0.97), "ink"),        # baseboard top ledge
    ((0.30, 0.97), "plum_deep"),  # wainscot
    ((0.30, 4.35), "marble_lo"),  # dado underside (faces down)
    ((0.17, 4.35), "marble"),     # dado lower chamfer (faces down: base colour)
    ((0.10, 4.42), "marble"),     # dado face (0.2 proud: >= d/170 at 35 studs)
    ((0.10, 4.78), "marble_hi"),  # dado upper chamfer
    ((0.17, 4.85), "marble"),     # dado top ledge
    ((0.30, 4.85), "plum"),       # upper wall
    ((0.30, 10.95), "marble_lo"), # crown cove (faces down)
    ((0.00, 11.25), "marble"),    # crown face
    ((0.00, 11.80), "marble_hi"), # crown chamfer
    ((0.20, 12.00), "plum_hi"),   # top cap (cut-away)
]
PANEL = dict(w=3.0, z0=1.50, z1=3.85, proud=0.12, bury=0.05, chamfer=0.06)


def section():
    """The full closed wall section: up the front, then down the back. Returns (points, edge colours)."""
    pts, cols = [], []
    for (y, z), c in FRONT:
        pts.append((y, z)); cols.append(c)
    back = [((D - y, z), c) for (y, z), c in FRONT]
    bpts = [p for p, _c in reversed(back)]
    bcols = [c for _p, c in reversed(back)][1:] + ["ink"]   # last edge = bottom (floor contact)
    return pts + bpts, cols + bcols


def _clip(pts, cols, z, keep_above, clip_col):
    """Sutherland-Hodgman against the horizontal line q = z (polygon points are (p, q)); edges along the cut
    get clip_col. The section is z-monotone on both sides, so the result stays a simple polygon."""
    def inside(p):
        return p[1] >= z - 1e-9 if keep_above else p[1] <= z + 1e-9
    def cut(a, b):
        t = (z - a[1]) / (b[1] - a[1])
        return (a[0] + t * (b[0] - a[0]), z)
    out_p, out_c = [], []
    n = len(pts)
    for i in range(n):
        a, c, b = pts[i], cols[i], pts[(i + 1) % n]
        ia, ib = inside(a), inside(b)
        if ia:
            out_p.append(a); out_c.append(c)
            if not ib:
                out_p.append(cut(a, b)); out_c.append(clip_col)
        elif ib:
            out_p.append(cut(a, b)); out_c.append(c)
    # drop zero-length edges (a point exactly on the cut line appears twice): keep the later point's colour
    P, C = [], []
    for p, c in zip(out_p, out_c):
        if P and abs(P[-1][0] - p[0]) < 1e-7 and abs(P[-1][1] - p[1]) < 1e-7:
            P[-1], C[-1] = p, c
        else:
            P.append(p); C.append(c)
    if len(P) > 1 and abs(P[0][0] - P[-1][0]) < 1e-7 and abs(P[0][1] - P[-1][1]) < 1e-7:
        P.pop(); C.pop()
    # merge collinear runs of the same colour (fewer n-gon fan triangles)
    return P, C


def section_band(z0=0.0, z1=H, top_col="plum_hi", bottom_col="ink"):
    """The wall section clipped to z0 <= z <= z1 (window sills, door headers)."""
    pts, cols = section()
    if z1 < H - 1e-9:
        pts, cols = _clip(pts, cols, z1, False, top_col)
    if z0 > 1e-9:
        pts, cols = _clip(pts, cols, z0, True, bottom_col)
    return pts, cols


def wall_run(mb, x0, x1, z0=0.0, z1=H, top_col="plum_hi", bottom_col="ink", cap_col="plum_deep", part=None):
    """Extrudes the (clipped) wall section along X from x0 to x1."""
    pts, cols = section_band(z0, z1, top_col, bottom_col)
    return mb.prism(pts, "X", x0, x1, cols, cap_col, part=part)


def panels(mb, x0, x1, step=4.0, part="Panel"):
    """Raised wainscot panels (both faces), one per 4-stud cell between x0 and x1."""
    n = int(round((x1 - x0) / step))
    for i in range(n):
        cx = x0 + step * i + step / 2
        a, b = cx - PANEL["w"] / 2, cx + PANEL["w"] / 2
        for y0, y1 in ((CORE_F - PANEL["proud"], CORE_F + PANEL["bury"]),
                       (CORE_B - PANEL["bury"], CORE_B + PANEL["proud"])):
            mb.box((a, y0, PANEL["z0"]), (b, y1, PANEL["z1"]), "plum", chamfer=PANEL["chamfer"],
                   cham_col="plum_hi", part=f"{part}_{i}")


def both_faces(y0, y1):
    """A trim on the front face spanning y0..y1 (y0 < y1, near y = 0) and its mirror on the back face."""
    return ((y0, y1), (D - y1, D - y0))


def arc(cx, cz, r, a0, a1, n):
    """Points on a circle in the (x, z) plane from angle a0 to a1 (degrees), n segments."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def catenary(x0, x1, z_top, sag, n):
    """A hanging swag from (x0, z_top) to (x1, z_top) that sags `sag` studs at the middle (parabola)."""
    out = []
    for i in range(n + 1):
        t = i / n
        out.append((x0 + (x1 - x0) * t, z_top - sag * 4 * t * (1 - t)))
    return out


def tube(mb, path, r, segs, col, cols=None, cap_col=None, part=None, normal=None):
    """A tube of radius r along a 3D polyline (list of (x, y, z)); cols[i] colours ring i's band (puffy
    garlands alternate colours). Caps are fans (no n-gons). normal: for a path in one plane, that plane's normal
    (a fixed ring frame: no twist). Returns the verts."""
    from mathutils import Vector
    pts = [Vector(p) for p in path]
    rings = []
    prev_u = None
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
        if normal is not None:
            ref = Vector(normal)
        elif prev_u is not None:
            ref = prev_u                      # parallel transport: no twist between rings
        else:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = (ref - t * ref.dot(t)).normalized()
        prev_u = u
        w = t.cross(u)
        rr = r[i] if isinstance(r, (list, tuple)) else r
        rings.append([mb.v(p + rr * (math.cos(2 * math.pi * j / segs) * u + math.sin(2 * math.pi * j / segs) * w))
                      for j in range(segs)])
    for i in range(len(rings) - 1):
        c = cols[i] if cols else col
        for j in range(segs):
            k = (j + 1) % segs
            mb.f([rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]], c)
    a, b = mb.v(pts[0]), mb.v(pts[-1])
    for j in range(segs):
        k = (j + 1) % segs
        mb.f([a, rings[0][k], rings[0][j]], cap_col or col)
        mb.f([b, rings[-1][j], rings[-1][k]], cap_col or col)
    if segs >= 6 and hasattr(mb, "soften"):
        # round tube: around the circumference and across gentle path bends shade smooth (eh_kit.SOFT_MAX_DEG keeps
        # the 90-degree cap rims hard)
        for i in range(len(rings)):
            for j in range(segs):
                mb.soften(rings[i][j], rings[i][(j + 1) % segs])
                if i + 1 < len(rings):
                    mb.soften(rings[i][j], rings[i + 1][j])
    vs = [v for R in rings for v in R] + [a, b]
    mb._part(part, vs)
    return vs
