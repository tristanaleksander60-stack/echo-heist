"""Golden asset (W1): the Diamond (hero loot, faceted brilliant).

Build: python3 tools/blender/build_asset.py assets/blender/diamond.py
Brief: loot class "small" (600 / 1,500 tris), deliberately faceted (flat shading). 2.0 studs across, so it reads
next to a 5-stud avatar. Crown is exaggerated (21 % of width vs 15 % in a real brilliant), pavilion deep and straight so the facets catch
light from the third-person camera. Cut: 8-sided table, 8 star facets, 16 upper girdle facets, a 16-sided girdle
band, 16 lower girdle facets, 8 + 8 pavilion facets to the culet. Palette: Diamond Ice in three values; the
"loot" read comes from the sparkle VFX (shape), never a clone hue. Origin: centre (it hovers and spins on its
pedestal). Front -Y.
"""
import math

R = 1.0            # girdle radius
TABLE_R = 0.60     # table radius (60 % of the width, real 53-58 %: a bigger table reads at 64 px)
CROWN_H = 0.42
GIRDLE_H = 0.08
PAVILION_H = 1.25
PAV_RING = (0.47, 0.47)   # pavilion break ring on the straight girdle-culet line: a clean V silhouette


def build(k):
    mb = k.MB("Diamond")
    zc = 0.0                                   # culet at z = 0 while building
    z_gd = PAVILION_H
    z_gu = z_gd + GIRDLE_H
    z_t = z_gu + CROWN_H
    P = lambda r, a, z: mb.v((r * math.cos(math.radians(a)), r * math.sin(math.radians(a)), z))
    gu = [P(R, 22.5 * j, z_gu) for j in range(16)]
    gd = [P(R, 22.5 * j, z_gd) for j in range(16)]
    t = [P(TABLE_R, 22.5 * (2 * i + 1), z_t) for i in range(8)]
    p = [P(R * PAV_RING[0], 22.5 * (2 * i + 1), PAVILION_H * PAV_RING[1]) for i in range(8)]
    c = mb.v((0, 0, zc))
    mb.f(t, "ice_hi")                                                         # table
    for i in range(8):
        n = (i + 1) % 8
        mb.f([t[i], t[n], gu[(2 * i + 2) % 16]], "ice")                       # star
        mb.f([t[i], gu[2 * i], gu[2 * i + 1]], "ice_hi")                      # upper girdle (lit side)
        mb.f([t[i], gu[2 * i + 1], gu[(2 * i + 2) % 16]], "ice_lo")           # upper girdle (shade side)
    for j in range(16):
        n = (j + 1) % 16
        mb.f([gu[j], gu[n], gd[n], gd[j]], "ice_lo")                          # girdle band
    for i in range(8):
        n = (i + 1) % 8
        mb.f([gd[2 * i], gd[2 * i + 1], p[i]], "ice")                         # lower girdle
        mb.f([gd[2 * i + 1], gd[(2 * i + 2) % 16], p[i]], "ice_hi")
        mb.f([gd[(2 * i + 2) % 16], p[n], p[i]], "ice_lo")                    # pavilion main
        mb.f([p[i], p[n], c], "ice" if i % 2 else "ice_lo")                   # culet facets
    h = z_t
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, h / 2))
    return k.Asset("Diamond", [k.Obj(ob, "small", role="loot", symmetric="XY", pivot="center",
                                     expect_dims=(2 * R, 2 * R, round(h, 3)),
                                     collision="Box", can_collide=False, cast_shadow=False,
                                     notes="hovers + spins on the pedestal; sparkle VFX carries the loot read")],
                   notes="Hero loot. Studio: SmoothPlastic, Color white, atlas TextureID, Box, CanCollide off, CastShadow off.")
