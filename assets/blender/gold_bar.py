"""Golden asset (W1): Heist Gold bar and the 3-2-1 bar stack (loot hero props).

Build: python3 tools/blender/build_asset.py assets/blender/gold_bar.py
Brief: loot class "small" (600 / 1,500 tris). Carried bar reads at 64 px as a trapezoid ingot; props are about 2x
real size (a real 400 oz bar is 0.9 x 0.25 x 0.14 studs, ours is 2.0 x 1.0 x 0.6). Focal feature: the
recessed stamp on top (the "this is a bar" read). Palette: gold faces, gold_hi chamfers that catch light,
gold_lo stamp. Origin: bottom centre (floor/table prop). Front -Y.
"""

BAR = (2.0, 1.0, 0.6)          # length X, width Y, height Z (studs)
TAPER = (0.80, 0.66)           # top face scale
CHAMFER = 0.07                 # small-prop bevel (STYLE_BIBLE: 0.06-0.08)
STAMP = (0.13, 0.045, 0.035)   # rim width, groove width, groove depth: engraved plate outline


def bar(k, mb, cx, cy, z0, along="X", part=None):
    L, W, H = BAR
    if along == "X":
        lo, hi, taper = (cx - L / 2, cy - W / 2, z0), (cx + L / 2, cy + W / 2, z0 + H), TAPER
    else:
        lo, hi, taper = (cx - W / 2, cy - L / 2, z0), (cx + W / 2, cy + L / 2, z0 + H), (TAPER[1], TAPER[0])
    vs = mb.box(lo, hi, "gold", chamfer=CHAMFER, cham_col="gold_hi", taper=taper, flat=("-z",), part=part)
    vset = set(vs)
    faces = {f for v in vs for f in v.link_faces if all(x in vset for x in f.verts)}
    for f in faces:
        f.normal_update()
    top = max((f for f in faces if f.normal.z > 0.99), key=lambda f: f.calc_area())
    import bmesh
    rim = bmesh.ops.inset_individual(mb.bm, faces=[top], thickness=STAMP[0], depth=0.0, use_even_offset=True)
    for f in rim["faces"]:            # rim stays gold
        f[mb.col] = k.P.INDEX["gold"]
    groove = bmesh.ops.inset_individual(mb.bm, faces=[top], thickness=STAMP[1], depth=-STAMP[2],
                                        use_even_offset=True)
    for f in groove["faces"]:         # engraved groove walls dark, plate floor stays gold
        f[mb.col] = k.P.INDEX["gold_lo"]
    return vs


def build(k):
    mb = k.MB("GoldBar")
    bar(k, mb, 0, 0, 0)
    gb = k.finalize(mb, pivot=(0, 0, 0))

    ms = k.MB("GoldStack")
    L, W, H = BAR
    for i, y in enumerate((-1.05, 0.0, 1.05)):
        bar(k, ms, 0, y, 0, "X", part=f"L1_{i}")
    for i, x in enumerate((-0.52, 0.52)):
        bar(k, ms, x, 0, H, "Y", part=f"L2_{i}")
    bar(k, ms, 0, 0, 2 * H, "X", part="L3")
    gs = k.finalize(ms, pivot=(0, 0, 0))

    loot = dict(role="loot", pivot="bottom", collision="Box", material="SmoothPlastic")
    return [
        k.Asset("GoldBar", [k.Obj(gb, "small", symmetric="XY", expect_dims=BAR, cast_shadow=False,
                                  notes="carried loot; CanCollide off while carried", **loot)],
                notes="Loot: carried bar. Studio: SmoothPlastic, Color white, TextureID = kit atlas, Box, CastShadow off."),
        k.Asset("GoldStack", [k.Obj(gs, "small", symmetric="XY", expect_dims=(2.04, 3.1, 1.8), **loot)],
                notes="Loot: 6-bar table stack (3-2-1). One grab = one bar; the stack shrinks in code."),
    ]
