"""Golden asset (W1): Bank wall modules on the 4-stud grid (Bank_Wall_4x12, Bank_Wall_8x12).

Build: python3 tools/blender/build_asset.py assets/blender/bank_wall.py
Kit rules (STYLE_BIBLE "Kit grid"): footprint W x 2 x 12 studs, W a multiple of 4. Origin = the grid corner at
front-bottom-left (x = 0, y = 0, z = 0); the module fills [0, W] x [0, 2] x [0, 12]; front faces -Y; both faces
are dressed (interior walls are seen from both rooms). The end faces at x = 0 and x = W are flat and identical,
so modules tile seamlessly (tile check). Seams and exposed ends are covered by pillar / corner modules (next).

Section (front half, y = 0 is the front plane, the core is y 0.3 - 1.7):
  baseboard  0 - 0.97 high, proud 0.30, 0.12 chamfer     Ink Indigo
  wainscot   0.97 - 4.35, raised panels 3.0 x 2.35         Plum Slate deep, panels Plum Slate
  dado rail  4.35 - 4.85, proud 0.20, 0.07 chamfers        Warm Marble
  upper wall 4.85 - 10.95                                  Plum Slate (calm field for signs and props)
  crown      45-degree cove 10.95 - 11.25, face to 11.80, 0.2 chamfer, proud 0.30   Warm Marble
  top cap    the cut-away top seen by the diorama camera   Plum Slate light
"""

H, D = 12.0, 2.0

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
    pts, cols = [], []
    for (y, z), c in FRONT:
        pts.append((y, z)); cols.append(c)
    back = [((D - y, z), c) for (y, z), c in FRONT]
    # walk down the back: point order reversed; the edge colour belongs to the segment below each point
    bpts = [p for p, _c in reversed(back)]
    bcols = [c for _p, c in reversed(back)][1:] + ["ink"]   # last edge = bottom (floor contact)
    return pts + bpts, cols + bcols


def wall(k, W):
    name = f"Bank_Wall_{int(W)}x{int(H)}"
    mb = k.MB(name)
    pts, cols = section()
    mb.prism(pts, "X", 0.0, W, cols, "plum_deep", part="Section")
    core_f, core_b = 0.30, D - 0.30
    for i in range(int(W // 4)):
        cx = 4 * i + 2
        x0, x1 = cx - PANEL["w"] / 2, cx + PANEL["w"] / 2
        for y0, y1 in ((core_f - PANEL["proud"], core_f + PANEL["bury"]),
                       (core_b - PANEL["bury"], core_b + PANEL["proud"])):
            mb.box((x0, y0, PANEL["z0"]), (x1, y1, PANEL["z1"]), "plum", chamfer=PANEL["chamfer"],
                   cham_col="plum_hi", part=f"Panel_{i}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return k.Asset(name, [k.Obj(ob, "module", role="env", symmetric="XY", pivot="corner", expect_dims=(W, D, H),
                                collision="Box", notes="kit wall; Anchored")],
                   grid=(W, D, H, 4), tile_x=W,
                   notes=f"Kit wall {int(W)}x{int(D)}x{int(H)} on the 4-stud grid; origin = front-bottom-left grid corner; tiles along X.")


def build(k):
    return [wall(k, 4.0), wall(k, 8.0)]
