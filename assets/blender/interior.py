"""Interior dressing kit (INTERIORS track, 2026-11-13; docs/audit/REVIEW_STEAM_PLUS.md gaps 8, 9 and 12): the eye-level
props that fill the rooms in first person, a tintable wall frieze and a tintable ceiling tile.

Build: python3 tools/blender/build_asset.py assets/blender/interior.py
Placed by server Heist/DecorPlan (pure, Lune-tested in tests/unit/HeistInterior.spec.luau) through Heist/KitDresser;
the ceiling tile by Heist/TowerPlan. Every piece is visual only: CanCollide, CanTouch and CanQuery off, never on a
plate, door, loot point, hide, laser, the van zone or a route (the unit spec checks every level). The props never use
loot gold, Diamond Ice, a signal colour or a clone hue (role "story": env + Christmas cells), so the plates, loot,
lasers and doors stay the clearest things in a frame.

Conventions (STYLE_BIBLE 5): Blender x right, y depth with the FRONT at -Y (Roblox -Z, the LookVector), z up. Floor
props: origin at the bottom centre of their footprint, the back (+Y) is the side that stands against a wall. Wall
props (posters, the clock, the corkboard, the coat hooks, the card string, the deposit boxes, the frieze): origin at
the back centre at the bottom, the back plane y = 0 sits on the wall face, the front faces -Y into the room. Every
feature overlaps its support by 0.02-0.05 (no coplanar faces, no floating shells).

Groups (one FBX / one uploaded Model each):
  Decor_Shop    corner shop: stocked shelf, drinks fridge (+ glass door, + warm light strip), magazine rack, candy
                counter, mop bucket, cat bed with a sleeping cat, two posters, a wall clock, a Christmas card string
  Decor_Toy     toy shop: toy shelf (teddies, trains, blocks), rocking horse, gift-wrap table, giant candy cane,
                train track loop on a low plinth
  Decor_Bank    bank: brass teller rail, queue rope, marble bench, potted palm, deposit-box wall
  Decor_Office  back rooms and offices: desk with a lamp and papers, coat hooks with coats, stacked boxes, a
                corkboard with Gus's donut list
  Decor_Theme   each level's own shop (Config.Interior.THEMES): bakery cake stand, pharmacy counter with its cross,
                deli case, jeweller's velvet case, toy-repair bench, grocer's fruit stand
  Decor_Trim    Decor_Frieze_8 (a tintable band under the crown, the level's colour) and Ceiling_8x8_Tin (a tintable
                pressed-tin ceiling tile, the level's ceiling colour: about 0.6x the wall value in first person)
"""
import math
import random

import _kitlib as L
from mathutils import Matrix, Vector

E = 0.03   # how far a feature sinks into its support (no coplanar faces)


def floor_obj(k, ob, cls="small", notes="", layer="base", role="story", **kw):
    return k.Obj(ob, cls, role=role, pivot="point", collision="Box", can_collide=False, cast_shadow=kw.pop("cast", True),
                 sim="none", on_floor=True, layer=layer, notes=notes, **kw)


def wall_obj(k, ob, cls="small", notes="", layer="base", role="story", **kw):
    return k.Obj(ob, cls, role=role, pivot="point", collision="Box", can_collide=False, cast_shadow=False, sim="none",
                 layer=layer, notes=notes, **kw)


def can(mb, x, y, z, r, h, col, part, segs=6):
    """A can / bottle body standing on z (sunk E into its shelf), with a lighter lid."""
    mb.cylinder((x, y, z - E), (0, 0, 1), r, 0.0, h + E, segs, col, cap_col="steel_hi", part=part)


# ================================================================ Decor_Shop

def stock_shelf(k):
    """Wall shelf unit 8 x 2 x 7: pine carcass, dark back, four boards stocked with cereal boxes, tins and jars."""
    W, D, H = 8.0, 2.0, 7.2
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    mb = k.MB("Decor_StockShelf_8")
    mb.box((x0, y0, 0.0), (x0 + 0.25, y1, H), "wood_lo", chamfer=0.05, cham_col="wood", flat=("-z",), part="SideL")
    mb.box((x1 - 0.25, y0, 0.0), (x1, y1, H), "wood_lo", chamfer=0.05, cham_col="wood", flat=("-z",), part="SideR")
    mb.box((x0 + 0.2, y1 - 0.2, 0.0), (x1 - 0.2, y1, H - 0.1), "ink_hi", part="Back")
    mb.box((x0 - 0.1, y0 - 0.1, H - 0.05), (x1 + 0.1, y1, H + 0.3), "wood", chamfer=0.06, cham_col="wood_hi", part="Top")
    mb.box((x0 + 0.2, y0 + 0.05, 0.0), (x1 - 0.2, y1 - 0.15, 0.55), "wood_lo", part="Kick")
    boards = (0.55, 2.2, 3.85, 5.5)
    rng = random.Random(81)
    box_cols = ("marble_lo", "ribbon", "holly_lo", "marble", "leaf_hi", "steel")
    can_cols = ("ribbon", "holly", "steel_hi", "marble_hi", "leaf", "ribbon_hi")
    for i, z in enumerate(boards):
        mb.box((x0 + 0.2, y0, z), (x1 - 0.2, y1 - 0.15, z + 0.14), "wood", chamfer=0.04, cham_col="wood_hi",
               flat=("-x", "+x", "+y"), part=f"Board{i}")
        mb.box((x0 + 0.2, y0 - 0.06, z - 0.12), (x1 - 0.2, y0 + E, z + 0.14), "marble_hi", part=f"PriceRail{i}")
        top = z + 0.14
        room = 1.48 if i < 3 else 1.5
        x = x0 + 0.35
        n = 0
        while x < x1 - 0.6:
            kind = rng.choice(("box", "box", "cans", "tall"))
            if kind == "cans":
                for j in range(3):
                    if x + 0.5 > x1 - 0.3:
                        break
                    c = can_cols[(i + j + n) % len(can_cols)]
                    can(mb, x + 0.25, y0 + 0.45, top, 0.22, 0.62, c, f"Can{i}_{n}_{j}")
                    x += 0.5
            else:
                w = rng.choice((0.7, 0.85, 1.0))
                h = rng.uniform(0.8, room - 0.25) if kind == "box" else room - 0.15
                if x + w > x1 - 0.3:
                    break
                c = box_cols[(i * 3 + n) % len(box_cols)]
                mb.box((x, y0 + 0.2, top - E), (x + w - 0.05, y1 - 0.3, top + h), c, part=f"Box{i}_{n}")
                # a pale label band on the front (two values read as a product, not a block)
                mb.box((x + 0.1, y0 + 0.18, top + h * 0.35), (x + w - 0.15, y0 + 0.2 + E, top + h * 0.62),
                       "marble_hi" if c != "marble" else "ribbon_hi", part=f"Label{i}_{n}")
                x += w + 0.06
            n += 1
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="stocked wall shelf 8 x 2 x 7.5: boxes, tins and jars on four boards; "
                                            "its back stands on a wall")


def fridge(k):
    """Drinks fridge 4.4 x 2.6 x 8: steel body, a glass door over lit shelves of bottles, a warm light strip."""
    W, D, H = 4.4, 2.6, 8.0
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    mb = k.MB("Decor_Fridge_4")
    t = 0.3
    mb.box((x0, y0 + 0.2, 0.0), (x1, y1, 0.6), "ink_hi", flat=("-z",), part="Plinth")
    mb.box((x0, y0, 0.55), (x0 + t, y1, H), "steel", chamfer=0.08, cham_col="steel_hi", flat=("-z",), part="SideL")
    mb.box((x1 - t, y0, 0.55), (x1, y1, H), "steel", chamfer=0.08, cham_col="steel_hi", flat=("-z",), part="SideR")
    mb.box((x0 + 0.1, y0, H - 1.1), (x1 - 0.1, y1, H), "ribbon", chamfer=0.08, cham_col="ribbon_hi", part="Header")
    mb.box((x0 + 0.6, y0 - E, H - 0.85), (x1 - 0.6, y0 + 0.1, H - 0.3), "marble_hi", part="HeaderPanel")
    mb.box((x0 + 0.1, y1 - t, 0.55), (x1 - 0.1, y1, H - 1.05), "steel_hi", part="Back")
    mb.box((x0 + 0.1, y0 + 0.1, 0.55), (x1 - 0.1, y1 - 0.2, 0.8), "steel_lo", part="Floor")
    cols = ("ribbon", "holly", "marble_hi", "leaf_hi", "steel", "ribbon_hi", "holly_lo")
    for i, z in enumerate((0.8, 2.35, 3.9, 5.45)):
        mb.box((x0 + t - E, y0 + 0.3, z - 0.1), (x1 - t + E, y1 - t + E, z), "steel_hi", part=f"Rack{i}")
        for j in range(7):
            x = x0 + 0.62 + j * 0.53
            c = cols[(i * 2 + j) % len(cols)]
            # a bottle: body + a slimmer neck (6-sided: 24 tris each)
            mb.cylinder((x, y0 + 0.9, z - E), (0, 0, 1), 0.2, 0.0, 1.05 + E, 6, c, cap_col="steel_hi",
                        part=f"Bottle{i}_{j}")
    # the door frame round the glass (the glass is its own part) and a long handle
    for lo, hi in (((x0, y0 - 0.12, 0.55), (x0 + 0.35, y0 + 0.05, H - 1.1)), ((x1 - 0.35, y0 - 0.12, 0.55), (x1, y0 + 0.05, H - 1.1)),
                   ((x0, y0 - 0.12, 0.55), (x1, y0 + 0.05, 0.85))):
        mb.box(lo, hi, "steel_lo", part="DoorFrame")
    mb.box((x1 - 0.62, y0 - 0.35, 2.4), (x1 - 0.46, y0 - 0.1, 5.4), "steel_hi", chamfer=0.04, cham_col="steel_hi",
           part="Handle")
    for zz in (2.6, 5.2):
        mb.box((x1 - 0.6, y0 - 0.15, zz - 0.06), (x1 - 0.48, y0 - 0.1 + E, zz + 0.06), "steel_hi", part="HandleFoot")
    ob = k.finalize(mb, pivot=(0, 0, 0))

    mg = k.MB("Decor_Fridge_4_Glass")
    mg.box((x0 + 0.33, y0 - 0.06, 0.83), (x1 - 0.33, y0 - 0.02, H - 1.12), "steel_hi")
    gl = k.finalize(mg, pivot=(0, 0, 0))

    ml = k.MB("Decor_Fridge_4_Light")
    ml.box((x0 + t, y0 + 0.2, H - 1.25), (x1 - t, y0 + 0.4, H - 1.05), "white")
    lt = k.finalize(ml, pivot=(0, 0, 0))
    return [
        floor_obj(k, ob, "module", notes="drinks fridge 4.4 x 2.6 x 8: bottles on four racks behind a glass door"),
        k.Obj(gl, "tiny", role="story", pivot="point", collision="Box", material="Glass", can_collide=False,
              cast_shadow=False, atlas=False, transparency=0.6, tint="Vault Steel light #A9B2CC", free_shells=True,
              sim="none", notes="the fridge's glass door: Glass, Transparency 0.6"),
        k.Obj(lt, "tiny", role="story", pivot="point", collision="Box", material="Neon", can_collide=False,
              cast_shadow=False, atlas=False, free_shells=True, sim="none",
              notes="Bulb Warm Neon strip under the header (eh_palette.NEON): the fridge glows, small and warm"),
    ]


def mag_rack(k):
    """Magazine rack 3.2 x 1.6 x 4.6: three stepped tiers of covers on a steel frame."""
    mb = k.MB("Decor_MagRack_3")
    W = 3.2
    for sx in (-1, 1):
        mb.box((sx * W / 2 - 0.12, -0.8, 0.0), (sx * W / 2 + 0.12, 0.8, 0.12), "steel_lo", part=f"Foot{sx}")
        mb.box((sx * W / 2 - 0.08, 0.45, 0.1), (sx * W / 2 + 0.08, 0.6, 4.6), "steel", part=f"Post{sx}")
    covers = (("ribbon", "marble_hi"), ("holly", "snow"), ("steel_hi", "ribbon"), ("leaf_hi", "marble"),
              ("marble_lo", "holly_lo"), ("ribbon_hi", "ink_hi"))
    for i, (zb, yb) in enumerate(((0.35, -0.55), (1.75, -0.2), (3.15, 0.15))):
        mb.box((-W / 2, yb - 0.1, zb - 0.1), (W / 2, yb + 0.55, zb), "steel_lo", part=f"Tier{i}")
        mb.box((-W / 2, yb - 0.12, zb - 0.1), (W / 2, yb - 0.05, zb + 0.4), "steel", part=f"Lip{i}")
        mb.box((-W / 2 + 0.05, yb + 0.45, zb - 0.1), (W / 2 - 0.05, 0.5, zb + 0.05), "steel_lo", part=f"Brace{i}")
        for j in range(3):
            c, c2 = covers[(i * 3 + j) % len(covers)]
            x = -W / 2 + 0.2 + j * 1.0
            cv = mb.box((x, -0.06, 0.0), (x + 0.9, 0.0, 1.2), c, part=f"Cover{i}_{j}")
            mb.recolour(cv, c)
            band = mb.box((x + 0.1, -0.1, 0.75), (x + 0.8, -0.03, 1.05), c2, part=f"Title{i}_{j}")
            m = Matrix.Translation(Vector((0, yb + 0.05, zb - 0.02))) @ Matrix.Rotation(math.radians(-14), 4, "X")
            mb.xform(cv + band, m)
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="magazine rack 3.2 x 1.6 x 4.6, three tiers of covers")


def candy_counter(k):
    """Candy counter 6 x 2.6 x 4.3: pine body with a striped front, a marble top and a row of candy jars."""
    W, D = 6.0, 2.6
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    mb = k.MB("Decor_CandyCounter_6")
    mb.box((x0, y0 + 0.1, 0.0), (x1, y1, 3.1), "wood", chamfer=0.08, cham_col="wood_hi", flat=("-z",), part="Body")
    for i in range(6):
        c = "ribbon" if i % 2 == 0 else "marble_hi"
        xa = x0 + 0.3 + i * (W - 0.6) / 6
        mb.box((xa, y0 + 0.05, 0.5), (xa + (W - 0.6) / 6, y0 + 0.1 + E, 2.6), c, part=f"Stripe{i}")
    mb.box((x0 - 0.15, y0 - 0.05, 3.05), (x1 + 0.15, y1 + 0.05, 3.35), "marble", chamfer=0.08, cham_col="marble_hi",
           part="Top")
    jars = ("ribbon_hi", "holly", "snow", "ribbon", "leaf_hi")
    for j in range(5):
        x = x0 + 0.75 + j * 1.12
        mb.cylinder((x, 0.2, 3.35 - E), (0, 0, 1), 0.42, 0.0, 0.85, 8, jars[j], cap_col=jars[j], part=f"Jar{j}")
        mb.cylinder((x, 0.2, 4.15), (0, 0, 1), 0.46, 0.0, 0.15, 8, "steel_hi", part=f"Lid{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="candy counter 6.3 x 2.7 x 4.3: striped front, five candy jars")


def mop_bucket(k):
    mb = k.MB("Decor_MopBucket")
    mb.lathe([(0, 0.0), (0.7, 0.0), (0.85, 1.3), (0.78, 1.3), (0, 1.2)], 10, ["steel_lo", "steel", "steel_hi", "ink"],
             (0, 0, 0), part="Bucket")
    mb.box((-0.5, -0.3, 1.2), (0.5, 0.3, 1.75), "steel_lo", chamfer=0.05, cham_col="steel", part="Wringer")
    for sx in (-1, 1):
        mb.cylinder((sx * 0.55, 0.0, 0.25), (0, 1, 0), 0.18, -0.12, 0.12, 8, "ink_hi", part=f"Wheel{sx}")
    handle = mb.box((-0.06, -0.06, 0.0), (0.06, 0.06, 5.2), "wood_hi", part="Handle")
    mb.xform(handle, Matrix.Translation(Vector((0.1, 0.35, 0.9))) @ Matrix.Rotation(math.radians(-12), 4, "X"))
    mb.box((-0.35, 0.1, 0.9), (0.4, 0.55, 1.45), "marble_lo", part="MopHead")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="mop and bucket (the back room's working corner)")


def cat_bed(k):
    """A round cat bed (Ribbon) with a sleeping tabby curled up in it: the shop's storytelling prop."""
    mb = k.MB("Decor_CatBed")
    mb.lathe([(0, 0.0), (1.2, 0.0), (1.35, 0.35), (1.25, 0.6), (1.0, 0.55), (0.95, 0.25), (0, 0.25)], 14,
             ["ribbon", "ribbon", "ribbon_hi", "ribbon_hi", "ribbon", "marble"], (0, 0, 0), part="Bed")
    body = mb.sphere((0, 0, 0), 0.62, segs=10, rings=6, col="steel", part="Body")
    mb.xform(body, Matrix.Translation(Vector((0.05, 0.05, 0.5))) @ Matrix.Diagonal((1.15, 0.85, 0.55, 1)))
    head = mb.sphere((0, 0, 0), 0.32, segs=8, rings=5, col="steel_hi", part="Head")
    mb.move(head, (-0.62, -0.2, 0.55))
    for sx in (-1, 1):
        ear = [(0, 0), (0.24, 0), (0.12, 0.26)]
        ev = mb.prism(ear, "Y", -0.05, 0.05, "steel_lo", "steel_lo", part=f"Ear{sx}")
        mb.move(ev, (-0.62 + sx * 0.18 - 0.12, -0.2, 0.75))
    tail = [(0.7, 0.25, 0.42), (0.6, -0.4, 0.4), (0.1, -0.62, 0.4), (-0.4, -0.55, 0.42)]
    L.tube(mb, tail, 0.11, 6, "steel_lo", part="Tail", normal=(0, 0, 1))
    for i, x in enumerate((-0.15, 0.2, 0.5)):
        mb.box((x - 0.05, -0.4, 0.62), (x + 0.05, 0.45, 0.82), "steel_lo", part=f"Stripe{i}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="cat bed 2.7 wide with a sleeping tabby (storytelling prop)")


def posters(k):
    """Two shop posters 2.4 x 3.2 (wall props, back on the wall face): framed colour-block graphics, no text."""
    out = []
    for name, (bg, a, b) in (("Decor_Poster_A", ("ribbon", "marble_hi", "holly")),
                             ("Decor_Poster_B", ("holly_lo", "snow", "ribbon_hi"))):
        mb = k.MB(name)
        W, H = 2.4, 3.2
        mb.box((-W / 2, -0.06, 0.0), (W / 2, 0.0, H), "wood_lo", part="Frame")
        mb.box((-W / 2 + 0.12, -0.08, 0.12), (W / 2 - 0.12, -0.06 + E, H - 0.12), bg, part="Field")
        if name.endswith("A"):   # a big sun disc and a band: "SALE" energy without letters
            mb.cylinder((0, -0.08, 1.9), (0, -1, 0), 0.75, -E, 0.03, 16, a, part="Disc")
            mb.box((-0.95, -0.11, 0.45), (0.95, -0.08 + E, 0.85), b, part="Band")
        else:                    # a tilted bottle silhouette and a star
            bv = mb.box((-0.25, -0.11, 0.5), (0.25, -0.08 + E, 2.2), a, part="Bottle")
            mb.rotate(bv, 12, "Y", (0, -0.1, 1.3))
            star = [(math.cos(math.radians(90 + 36 * i)) * (0.5 if i % 2 == 0 else 0.2),
                     math.sin(math.radians(90 + 36 * i)) * (0.5 if i % 2 == 0 else 0.2)) for i in range(10)]
            sv = mb.prism([(p, q) for p, q in star], "Y", -0.11, -0.08 + E, b, b, part="Star")
            mb.move(sv, (0.55, 0, 2.5))
        ob = k.finalize(mb, pivot=(0, 0, 0))
        out.append(wall_obj(k, ob, "tiny", notes="shop poster 2.4 x 3.2 on a wall face"))
    return out


def wall_clock(k):
    mb = k.MB("Decor_WallClock")
    c = (0, -0.1, 1.0)
    mb.cylinder(c, (0, -1, 0), 1.0, -0.1, 0.12, 16, "wood_lo", part="Rim")
    mb.cylinder((0, -0.1, 1.0), (0, -1, 0), 0.86, 0.1, 0.14, 16, "marble_hi", part="Face")
    for i in range(12):
        a = math.radians(30 * i)
        x, z = 0.72 * math.sin(a), 1.0 + 0.72 * math.cos(a)
        w = 0.06 if i % 3 else 0.1
        mb.box((x - w, -0.27, z - w), (x + w, -0.2, z + w), "ink", part=f"Tick{i}")
    hv = mb.box((-0.04, -0.31, 1.0), (0.04, -0.26, 1.45), "ink", part="HourHand")
    mb.rotate(hv, -60, "Y", (0, 0, 1.0))
    mb.box((-0.03, -0.33, 1.0), (0.03, -0.29, 1.68), "ink", part="MinuteHand")
    mb.cylinder((0, -0.3, 1.0), (0, -1, 0), 0.08, -0.04, 0.05, 8, "ribbon", part="Hub")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return wall_obj(k, ob, "small", notes="wall clock, 2 wide, origin its back bottom")


def card_string(k):
    """A string of Christmas cards on a sagging cord, 8 long (Christmas layer, wall prop)."""
    mb = k.MB("Decor_CardString_8")
    W = 8.0
    pts = [(x, -0.08, z) for x, z in L.catenary(-W / 2, W / 2, 1.6, 0.45, 8)]
    L.tube(mb, pts, 0.03, 4, "marble_lo", part="Cord", normal=(0, 1, 0))
    for sx in (-1, 1):
        mb.box((sx * W / 2 - 0.08, -0.12, 1.5), (sx * W / 2 + 0.08, 0.0, 1.7), "steel", part=f"Pin{sx}")
    cols = ("ribbon", "holly", "snow", "ribbon_hi", "holly_lo", "marble_hi", "ribbon", "snow")
    for i in range(7):
        x = -W / 2 + 0.95 + i * (W - 1.9) / 6
        t = (x + W / 2) / W
        z = 1.6 - 0.45 * 4 * t * (1 - t)
        tilt = (-1) ** i * 6
        cv = mb.box((x - 0.33, -0.12, z - 0.95), (x + 0.33, -0.06, z + 0.02), cols[i], part=f"Card{i}")
        fv = mb.box((x - 0.2, -0.14, z - 0.7), (x + 0.2, -0.12 + 0.01, z - 0.3),
                    "marble_hi" if cols[i] != "snow" else "holly", part=f"Front{i}")
        mb.rotate(cv + fv, tilt, "Y", (x, -0.09, z))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return wall_obj(k, ob, "small", layer="xmas", role="xmas",
                    notes="Christmas card string 8 long (dressing layer), on a wall face")


def shop(k):
    objs = [stock_shelf(k)] + fridge(k) + [mag_rack(k), candy_counter(k), mop_bucket(k), cat_bed(k)] + posters(k) + \
        [wall_clock(k), card_string(k)]
    return k.Asset("Decor_Shop", objs, seats=[("Decor_Fridge_4_Glass", "Decor_Fridge_4"),
                                              ("Decor_Fridge_4_Light", "Decor_Fridge_4")],
                   notes="Corner Shop eye-level props: stocked shelf, fridge, magazines, candy, mop, cat, posters, clock, cards.")


# ================================================================ Decor_Toy

def toy_shelf(k):
    """Toy shelf 8 x 2 x 7: three boards of teddies, little trains, stacked blocks and boxed dolls."""
    W, D, H = 8.0, 2.0, 7.2
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    mb = k.MB("Decor_ToyShelf_8")
    mb.box((x0, y0, 0.0), (x0 + 0.25, y1, H), "wood", chamfer=0.05, cham_col="wood_hi", flat=("-z",), part="SideL")
    mb.box((x1 - 0.25, y0, 0.0), (x1, y1, H), "wood", chamfer=0.05, cham_col="wood_hi", flat=("-z",), part="SideR")
    mb.box((x0 + 0.2, y1 - 0.2, 0.0), (x1 - 0.2, y1, H - 0.1), "ribbon", part="Back")
    mb.box((x0 - 0.1, y0 - 0.1, H - 0.05), (x1 + 0.1, y1, H + 0.3), "marble", chamfer=0.06, cham_col="marble_hi",
           part="Top")
    for i, z in enumerate((0.0, 2.4, 4.8)):
        zb = max(z, 0.3)
        mb.box((x0 + 0.2, y0, zb), (x1 - 0.2, y1 - 0.15, zb + 0.14), "wood_hi", chamfer=0.04, cham_col="wood_hi",
               flat=("-x", "+x", "+y"), part=f"Board{i}")
        top = zb + 0.14
        if i == 0:   # teddies (marble_lo fur, dark eyes), not the loot teddy: small, sat in a row
            for j in range(4):
                x = x0 + 1.0 + j * 2.0
                bd = mb.sphere((x, y0 + 0.9, top + 0.55), 0.55, segs=8, rings=5, col="marble_lo", part=f"TedBody{j}")
                hd = mb.sphere((x, y0 + 0.85, top + 1.35), 0.4, segs=8, rings=5, col="marble_lo", part=f"TedHead{j}")
                for sx in (-1, 1):
                    mb.sphere((x + sx * 0.3, y0 + 0.88, top + 1.68), 0.15, segs=6, rings=4, col="wood_lo",
                              part=f"TedEar{j}{sx}")
                mb.box((x - 0.25, y0 + 0.42, top + 1.05), (x + 0.25, y0 + 0.55, top + 1.15),
                       ("ribbon", "holly", "steel_hi", "ribbon_hi")[j], part=f"TedBow{j}")
                _ = bd, hd
        elif i == 1:   # trains: a loco and two wagons per half
            for half in (0, 1):
                xb = x0 + 0.5 + half * 3.8
                mb.box((xb, y0 + 0.5, top - E), (xb + 1.2, y0 + 1.4, top + 0.75), "ribbon", chamfer=0.05,
                       cham_col="ribbon_hi", part=f"Loco{half}")
                mb.cylinder((xb + 0.85, y0 + 0.95, top + 0.75 - E), (0, 0, 1), 0.15, 0.0, 0.4, 6, "ink_hi",
                            part=f"Funnel{half}")
                mb.box((xb, y0 + 0.5, top + 0.7), (xb + 0.55, y0 + 1.4, top + 1.15), "holly_lo", part=f"Cab{half}")
                for w in range(2):
                    xw = xb + 1.3 + w * 1.05
                    mb.box((xw, y0 + 0.55, top - E), (xw + 0.95, y0 + 1.35, top + 0.55),
                           ("holly", "steel_hi")[w], chamfer=0.04, cham_col="snow", part=f"Wagon{half}{w}")
        else:          # stacked alphabet blocks and boxed dolls
            for j in range(3):
                x = x0 + 0.5 + j * 0.85
                for s in range(3 - j % 2):
                    mb.box((x, y0 + 0.5, top - E + s * 0.7), (x + 0.68, y0 + 1.18, top + 0.68 + s * 0.7),
                           ("ribbon", "holly", "marble_hi", "steel")[(j + s) % 4], part=f"Block{j}_{s}")
            for j in range(3):
                x = x0 + 3.3 + j * 1.45
                mb.box((x, y0 + 0.3, top - E), (x + 1.25, y1 - 0.4, top + 1.85), "ribbon_hi", part=f"DollBox{j}")
                mb.box((x + 0.2, y0 + 0.28, top + 0.25), (x + 1.05, y0 + 0.3 + E, top + 1.55), "ink_hi",
                       part=f"DollWin{j}")
                mb.sphere((x + 0.62, y0 + 0.5, top + 1.2), 0.22, segs=6, rings=4, col="marble_hi", part=f"DollHead{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="toy shelf 8 x 2 x 7.5: teddies, trains, blocks and boxed dolls")


def rocking_horse(k):
    mb = k.MB("Decor_RockingHorse")
    for sx in (-1, 1):
        rk = [(x, -sx * 0.0, z) for x, z in L.arc(0.0, 3.2, 3.2, 235, 305, 8)]
        L.tube(mb, [(p[0], sx * 0.55, p[2]) for p in rk], 0.1, 6, "wood_lo", part=f"Rocker{sx}", normal=(0, 1, 0))
        for x in (-1.0, 1.0):
            mb.box((x - 0.08, sx * 0.55 - 0.08, 0.1), (x + 0.08, sx * 0.55 + 0.08, 1.5), "wood", part=f"Leg{sx}{x}")
    mb.box((-1.25, -0.4, 1.4), (1.25, 0.4, 2.2), "marble_hi", chamfer=0.15, cham_col="snow", part="Body")
    for i, x in enumerate((-0.7, 0.1, 0.8)):
        mb.box((x - 0.12, -0.42, 1.6), (x + 0.12, 0.42, 1.9), "steel_lo", part=f"Dapple{i}")
    mb.box((-0.35, -0.42, 2.15), (0.45, 0.42, 2.35), "ribbon", part="Saddle")
    nk = mb.box((-0.3, -0.28, 0.0), (0.3, 0.28, 1.4), "marble_hi", part="Neck")
    mb.xform(nk, Matrix.Translation(Vector((-1.0, 0, 1.9))) @ Matrix.Rotation(math.radians(-25), 4, "Y"))
    mb.box((-2.15, -0.3, 2.8), (-1.15, 0.3, 3.35), "marble_hi", chamfer=0.1, cham_col="snow", part="Head")
    mb.box((-1.6, -0.12, 2.9), (-0.65, 0.12, 3.5), "ribbon", part="Mane")
    mb.box((1.15, -0.1, 1.5), (1.65, 0.1, 2.1), "ribbon_hi", part="Tail")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="rocking horse 4.6 long (cream, dappled, a red saddle)")


def gift_wrap(k):
    """Gift-wrap table 6 x 3: paper rolls on a rack, ribbon spools, wrapped boxes waiting."""
    W, D = 6.0, 3.0
    mb = k.MB("Decor_GiftWrap_6")
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.box((sx * 2.75 - 0.15, sy * 1.25 - 0.15, 0.0), (sx * 2.75 + 0.15, sy * 1.25 + 0.15, 3.0), "wood_lo",
                   part=f"Leg{sx}{sy}")
    mb.box((-W / 2, -D / 2, 2.95), (W / 2, D / 2, 3.25), "wood", chamfer=0.06, cham_col="wood_hi", part="Top")
    mb.box((-W / 2 + 0.3, -D / 2 + 0.3, 0.6), (W / 2 - 0.3, D / 2 - 0.3, 0.75), "wood_lo", part="Shelf")
    for i, c in enumerate(("ribbon", "holly", "snow", "ribbon_hi", "holly_lo")):   # rolls on the lower shelf
        mb.cylinder((-2.2 + i * 1.1, 0.0, 1.05), (0, 1, 0), 0.3, -1.1, 1.1, 8, c, cap_col="marble_lo", part=f"Roll{i}")
    for i, c in enumerate(("ribbon", "holly", "steel_hi")):                    # spools on the top
        mb.cylinder((1.6 + i * 0.5, 0.9, 3.25 - E), (0, 0, 1), 0.2, 0.0, 0.3, 8, c, part=f"Spool{i}")
    for i, (c, r) in enumerate((("holly", "ribbon"), ("ribbon", "snow"), ("marble_hi", "holly"))):
        x, s = -2.0 + i * 1.35, 0.55 + 0.12 * i
        mb.box((x - s, -0.3 - s, 3.25 - E), (x + s, -0.3 + s, 3.25 + 2 * s * 0.8), c, part=f"Gift{i}")
        mb.box((x - 0.08, -0.3 - s - 0.03, 3.25), (x + 0.08, -0.3 + s + 0.03, 3.25 + 2 * s * 0.8 + 0.03), r,
               part=f"GiftRibbon{i}")
    sheet = mb.box((0.0, -1.3, 3.25 - E), (2.6, 0.2, 3.27), "ribbon_hi", part="Sheet")
    _ = sheet
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="gift-wrap table 6 x 3: rolls, spools, wrapped boxes")


def giant_cane(k):
    """A giant candy cane 9 tall (Christmas layer): a striped shaft and crook on a snow base."""
    mb = k.MB("Decor_CandyCane_Giant")
    mb.cylinder((0, 0, 0), (0, 0, 1), 0.9, 0.0, 0.4, 12, "snow", chamfer=0.1, cham_col="snow", part="Base")
    n = 10
    for i in range(n):
        z0 = 0.35 + i * 0.75
        mb.cylinder((0, 0, z0), (0, 0, 1), 0.38, 0.0, 0.8, 10, "ribbon" if i % 2 == 0 else "snow", part=f"Band{i}")
    crook = [(0.0, 0.0, 0.35 + n * 0.75 - 0.05)] + [(1.0 - math.cos(math.radians(a)), 0.0,
                                                     0.35 + n * 0.75 + math.sin(math.radians(a)))
                                                    for a in range(20, 181, 20)]
    cols = ["snow" if i % 2 else "ribbon" for i in range(len(crook) - 1)]
    L.tube(mb, crook, 0.38, 10, "ribbon", cols=cols, part="Crook", normal=(0, 1, 0))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, layer="xmas", role="xmas", notes="giant candy cane 9.5 tall (dressing layer)")


def train_loop(k):
    """A toy train loop on a low round plinth 6 x 4 (a window or corner display): track, a loco and two wagons."""
    mb = k.MB("Decor_TrainLoop_6")
    mb.lathe([(0, 0.0), (1.0, 0.0), (1.0, 0.8), (0.94, 0.86), (0, 0.86)], 16, ["holly_lo", "holly_lo", "holly", "holly"],
             (0, 0, 0), part="Plinth")
    pl = mb.parts["Plinth"]
    mb.xform(pl, Matrix.Diagonal((3.0, 1.6, 1.0, 1)))
    pts = [(2.3 * math.cos(math.radians(a)), 1.05 * math.sin(math.radians(a)), 0.86) for a in range(0, 345, 15)]
    L.tube(mb, pts, 0.07, 4, "steel", part="Rail", normal=(0, 0, 1))
    for i, (a, c) in enumerate(((90, "ribbon"), (55, "holly"), (25, "marble_hi"))):
        x, y = 2.3 * math.cos(math.radians(a)), 1.05 * math.sin(math.radians(a))
        car = mb.box((-0.35, -0.22, 0.86 - E), (0.35, 0.22, 1.35 if i else 1.55), c, chamfer=0.04,
                     cham_col="snow", part=f"Car{i}")
        mb.xform(car, Matrix.Translation(Vector((x, y, 0))) @ Matrix.Rotation(math.radians(a + 90), 4, "Z"))
    mb.cylinder((0.0, 1.05, 1.5), (0, 0, 1), 0.1, 0.0, 0.3, 6, "ink_hi", part="Funnel")
    tree = mb.lathe([(0, 0.0), (0.55, 0.0), (0, 1.6)], 8, ["holly", "holly"], (0.0, 0.0, 0.86 - E), part="Tree")
    _ = tree
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="toy train loop on an oval plinth 6 x 3.2 x 2.4")


def toy(k):
    return k.Asset("Decor_Toy", [toy_shelf(k), rocking_horse(k), gift_wrap(k), giant_cane(k), train_loop(k)],
                   notes="Toy Shop eye-level props: toy shelf, rocking horse, gift-wrap table, giant candy cane, train loop.")


# ================================================================ Decor_Bank

def brass_rail(k):
    """Teller brass, 8 long: a brass (Warm Marble shade: never loot gold) rail with posts and a bell over a counter."""
    mb = k.MB("Decor_BrassRail_8")
    W = 8.0
    for i in range(5):
        x = -W / 2 + 0.2 + i * (W - 0.4) / 4
        mb.cylinder((x, 0.0, 0.0), (0, 0, 1), 0.08, 0.0, 2.2, 8, "marble_lo", part=f"Post{i}")
        mb.sphere((x, 0.0, 2.25), 0.14, segs=8, rings=4, col="marble", part=f"Knob{i}")
        mb.cylinder((x, 0.0, -E), (0, 0, 1), 0.18, 0.0, 0.1, 8, "marble_lo", part=f"Foot{i}")
    for z in (0.9, 2.0):
        mb.cylinder((-W / 2 + 0.1, 0.0, z), (1, 0, 0), 0.06, 0.0, W - 0.2, 6, "marble", part=f"Rail{z}")
    mb.cylinder((2.6, -0.5, -E), (0, 0, 1), 0.3, 0.0, 0.08, 10, "ink_hi", part="BellBase")
    mb.lathe([(0, 0.05), (0.22, 0.05), (0.14, 0.25), (0, 0.32)], 10, ["marble", "marble", "marble_hi"],
             (2.6, -0.5, 0.0), part="Bell")
    mb.box((-0.9, -0.08, 2.4), (0.9, 0.08, 3.0), "ink_hi", chamfer=0.04, cham_col="ink_hi", part="Plaque")
    mb.box((-0.75, -0.11, 2.5), (0.75, -0.07, 2.9), "marble", part="PlaqueFace")
    for sx in (-1, 1):
        mb.box((sx * 0.6 - 0.04, -0.04, 2.2), (sx * 0.6 + 0.04, 0.04, 2.45), "marble_lo", part=f"Hanger{sx}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="teller brass 8 long: rail, posts, bell and a plaque (stands on a counter top)")


def queue_rope(k):
    mb = k.MB("Decor_QueueRope_8")
    W = 8.0
    for i, x in enumerate((-W / 2 + 0.4, 0.0, W / 2 - 0.4)):
        mb.cylinder((x, 0.0, 0.0), (0, 0, 1), 0.45, 0.0, 0.15, 12, "marble_lo", part=f"Base{i}")
        mb.cylinder((x, 0.0, 0.15 - E), (0, 0, 1), 0.08, 0.0, 2.85, 8, "marble", part=f"Post{i}")
        mb.sphere((x, 0.0, 3.05), 0.17, segs=8, rings=4, col="marble_hi", part=f"Top{i}")
    for a, b in ((-W / 2 + 0.4, 0.0), (0.0, W / 2 - 0.4)):
        pts = [(x, 0.0, z) for x, z in L.catenary(a, b, 2.8, 0.6, 8)]
        L.tube(mb, pts, 0.1, 6, "ribbon", part=f"Rope{a}", normal=(0, 1, 0))
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="queue rope 8 long: brass posts and a burgundy velvet rope")


def bench(k):
    mb = k.MB("Decor_Bench_6")
    for sx in (-1, 1):
        mb.box((sx * 2.4 - 0.35, -0.7, 0.0), (sx * 2.4 + 0.35, 0.7, 1.5), "marble_lo", chamfer=0.08, cham_col="marble",
               flat=("-z",), part=f"Leg{sx}")
    mb.box((-3.0, -0.9, 1.45), (3.0, 0.9, 1.9), "marble", chamfer=0.12, cham_col="marble_hi", part="Seat")
    mb.box((-2.8, -0.75, 1.9 - E), (2.8, 0.7, 2.05), "ribbon", chamfer=0.05, cham_col="ribbon_hi", part="Cushion")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="marble bench 6 x 1.8 with a velvet cushion")


def palm(k):
    """A potted palm 7.5 tall: a big brass-rimmed pot and eight arching fronds (not the hide fern: taller, lighter)."""
    mb = k.MB("Decor_Palm")
    mb.lathe([(0, 0.0), (0.9, 0.0), (1.25, 1.8), (1.35, 1.9), (1.3, 2.05), (0, 1.95)], 12,
             ["marble_lo", "marble", "marble_lo", "marble_hi", "leaf_lo"], (0, 0, 0), part="Pot")
    mb.cylinder((0, 0, 1.9), (0, 0, 1), 0.18, 0.0, 3.9, 6, "wood_lo", part="Trunk")
    for i in range(8):
        a = math.radians(i * 45 + 10)
        d = Vector((math.cos(a), math.sin(a), 0))
        base = Vector((0, 0, 5.6))
        pts = [base + d * 0.1]
        for j in range(1, 6):
            t = j / 5
            pts.append(base + d * (1.6 * t) + Vector((0, 0, 1.0 * t - 2.0 * t * t)))
        L.tube(mb, [tuple(p) for p in pts], [0.32, 0.38, 0.34, 0.26, 0.16, 0.05], 4,
               "leaf_hi" if i % 2 else "leaf", part=f"Frond{i}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="potted palm 7.5 tall, brass-rimmed pot")


def deposit_wall(k):
    """Safe-deposit boxes on a wall, 8 x 7 x 0.6: a steel grid of small doors with brass keyholes (wall prop)."""
    mb = k.MB("Decor_DepositWall_8")
    W, H = 8.0, 7.0
    mb.box((-W / 2, -0.4, 0.0), (W / 2, 0.0, H), "steel_lo", part="Carcass")
    mb.box((-W / 2 - 0.1, -0.55, H - 0.3), (W / 2 + 0.1, 0.0, H), "steel", chamfer=0.05, cham_col="steel_hi",
           part="Cap")
    mb.box((-W / 2 - 0.1, -0.55, 0.0), (W / 2 + 0.1, 0.0, 0.5), "ink_hi", part="Kick")
    cols, rows = 8, 6
    for i in range(cols):
        for j in range(rows):
            x0 = -W / 2 + 0.15 + i * (W - 0.3) / cols
            z0 = 0.6 + j * (H - 1.0) / rows
            w, h = (W - 0.3) / cols - 0.1, (H - 1.0) / rows - 0.1
            mb.box((x0, -0.5, z0), (x0 + w, -0.4 + E, z0 + h), "steel" if (i + j) % 3 else "steel_hi",
                   part=f"Door{i}_{j}")
            mb.box((x0 + w / 2 - 0.06, -0.55, z0 + h / 2 - 0.06), (x0 + w / 2 + 0.06, -0.5 + E, z0 + h / 2 + 0.06),
                   "marble_lo", part=f"Key{i}_{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return wall_obj(k, ob, "module", notes="safe-deposit box wall 8 x 7, 0.55 proud of the wall face")


def bank(k):
    return k.Asset("Decor_Bank", [brass_rail(k), queue_rope(k), bench(k), palm(k), deposit_wall(k)],
                   notes="Bank eye-level props: teller brass, queue rope, marble bench, potted palm, deposit boxes.")


# ================================================================ Decor_Office

def desk(k):
    """Office desk 6 x 3 with a green-shaded desk lamp, papers, a mug and a ledger."""
    mb = k.MB("Decor_Desk_6")
    W, D = 6.0, 3.0
    mb.box((-W / 2, -D / 2, 2.85), (W / 2, D / 2, 3.2), "wood", chamfer=0.07, cham_col="wood_hi", part="Top")
    for sx in (-1, 1):
        mb.box((sx * (W / 2 - 0.9) - 0.75, -D / 2 + 0.15, 0.0), (sx * (W / 2 - 0.9) + 0.75, D / 2 - 0.1, 2.9),
               "wood_lo", chamfer=0.05, cham_col="wood", flat=("-z",), part=f"Pedestal{sx}")
        for j in range(3):
            z = 0.25 + j * 0.85
            mb.box((sx * (W / 2 - 0.9) - 0.65, -D / 2 + 0.1, z), (sx * (W / 2 - 0.9) + 0.65, -D / 2 + 0.15 + E, z + 0.72),
                   "wood", part=f"Drawer{sx}{j}")
            mb.box((sx * (W / 2 - 0.9) - 0.2, -D / 2 + 0.03, z + 0.3), (sx * (W / 2 - 0.9) + 0.2, -D / 2 + 0.1 + E, z + 0.4),
                   "marble_lo", part=f"Pull{sx}{j}")
    mb.box((-1.3, D / 2 - 0.2, 0.8), (1.3, D / 2 - 0.1, 2.9), "wood_lo", part="Modesty")
    # lamp: a base, a stem and a green glass shade (Leaf: the bank lamp's family)
    mb.cylinder((-2.1, 0.7, 3.2 - E), (0, 0, 1), 0.35, 0.0, 0.15, 10, "marble_lo", part="LampBase")
    mb.cylinder((-2.1, 0.7, 3.3), (0, 0, 1), 0.06, 0.0, 1.3, 6, "marble_lo", part="LampStem")
    mb.lathe([(0, 0.0), (0.55, 0.0), (0.3, 0.45), (0, 0.5)], 10, ["marble_hi", "leaf_hi", "leaf"],
             (-2.1, 0.7, 4.45), part="LampShade")
    # papers, a ledger, a mug
    for i, (x, y, r) in enumerate(((0.2, -0.3, 8), (0.8, 0.1, -14), (-0.5, 0.2, 3))):
        pv = mb.box((x - 0.45, y - 0.6, 3.2 - E), (x + 0.45, y + 0.6, 3.2 + 0.02 + i * 0.015), "marble_hi",
                    part=f"Paper{i}")
        mb.rotate(pv, r, "Z", (x, y, 3.2))
    mb.box((1.6, -0.6, 3.2 - E), (2.6, 0.5, 3.45), "ribbon", chamfer=0.04, cham_col="ribbon_hi", part="Ledger")
    mb.cylinder((-1.0, -0.8, 3.2 - E), (0, 0, 1), 0.2, 0.0, 0.45, 8, "snow", part="Mug")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="office desk 6 x 3 with a desk lamp (unlit mesh), papers, ledger, mug")


def coat_hooks(k):
    """Coat hooks 4 long with two coats and a scarf (wall prop): reads as 'staff room' at eye level."""
    mb = k.MB("Decor_CoatHooks_4")
    mb.box((-2.0, -0.2, 5.6), (2.0, 0.0, 6.0), "wood", chamfer=0.04, cham_col="wood_hi", part="Board")
    for i, x in enumerate((-1.4, -0.45, 0.45, 1.4)):
        mb.box((x - 0.06, -0.55, 5.7), (x + 0.06, -0.2 + E, 5.82), "marble_lo", part=f"Hook{i}")
    for i, (x, c, c2) in enumerate(((-1.0, "steel_lo", "steel"), (0.9, "ribbon", "ribbon_hi"))):
        mb.box((x - 0.55, -0.7, 2.6), (x + 0.55, -0.2, 5.72), c, chamfer=0.12, cham_col=c2, part=f"Coat{i}")
        mb.box((x - 0.45, -0.75, 5.0), (x + 0.45, -0.65, 5.75), c2, part=f"Collar{i}")
        for j in range(3):
            mb.box((x - 0.05, -0.74, 3.2 + j * 0.6), (x + 0.05, -0.68, 3.3 + j * 0.6), "marble_hi", part=f"Btn{i}{j}")
    mb.box((-0.1, -0.5, 3.4), (0.15, -0.18, 5.75), "holly", part="Scarf")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return wall_obj(k, ob, notes="coat hooks 4 long with two coats and a scarf, hung at 6 on a wall face")


def boxes(k):
    """A stack of cardboard stock boxes (taped, a printed band), 3.6 x 2.4 x 5."""
    mb = k.MB("Decor_Boxes")
    stack = (((-1.8, -1.2, 0.0), (0.0, 1.2, 1.7)), ((0.05, -1.1, 0.0), (1.8, 1.1, 1.5)),
             ((-1.6, -1.0, 1.7 - E), (0.2, 1.0, 3.2)), ((0.1, -0.8, 1.5 - E), (1.5, 0.9, 2.6)),
             ((-1.2, -0.7, 3.2 - E), (0.4, 0.8, 4.4)))
    for i, (lo, hi) in enumerate(stack):
        mb.box(lo, hi, "marble_lo" if i % 2 == 0 else "wood_hi", chamfer=0.05, cham_col="marble", part=f"Box{i}")
        cx = (lo[0] + hi[0]) / 2
        mb.box((cx - 0.12, lo[1] - 0.02, lo[2] + 0.02), (cx + 0.12, hi[1] + 0.02, hi[2] + 0.02), "marble",
               part=f"Tape{i}")
        mb.box((lo[0] + 0.2, lo[1] - 0.03, lo[2] + 0.3), (hi[0] - 0.2, lo[1] + E, lo[2] + 0.6),
               ("ribbon", "holly_lo", "steel_lo")[i % 3], part=f"Print{i}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="stacked cardboard stock boxes 3.6 x 2.4 x 4.4")


def corkboard(k):
    """Corkboard 4 x 3 with pinned notes and Gus's donut list (a ruled card with a donut doodle) (wall prop)."""
    mb = k.MB("Decor_Corkboard_4")
    W, H = 4.0, 3.0
    mb.box((-W / 2, -0.12, 0.0), (W / 2, 0.0, H), "wood", chamfer=0.04, cham_col="wood_hi", part="Frame")
    mb.box((-W / 2 + 0.15, -0.15, 0.15), (W / 2 - 0.15, -0.12 + E, H - 0.15), "wood_hi", part="Cork")
    notes = (((-1.55, 1.6), (0.9, 1.15), "marble_hi", 6), ((-0.4, 0.4), (0.8, 0.9), "snow", -5),
             ((0.6, 1.8), (0.85, 0.7), "holly", 4), ((1.1, 0.5), (0.7, 0.8), "ribbon_hi", -8))
    for i, ((x, z), (w, h), c, r) in enumerate(notes):
        nv = mb.box((x, -0.18, z), (x + w, -0.15 + E, z + h), c, part=f"Note{i}")
        pin = mb.box((x + w / 2 - 0.06, -0.24, z + h - 0.18), (x + w / 2 + 0.06, -0.18 + E, z + h - 0.06), "ribbon",
                     part=f"Pin{i}")
        mb.rotate(nv + pin, r, "Y", (x + w / 2, -0.17, z + h / 2))
    # Gus's donut list: the cream card, four ruled lines and a pink-iced donut doodle
    for j in range(4):
        mb.box((-1.45, -0.205, 1.75 + j * 0.2), (-0.8, -0.18 + 0.004, 1.79 + j * 0.2), "ink_hi", part=f"Line{j}")
    mb.cylinder((-0.95, -0.2, 2.45), (0, -1, 0), 0.22, -0.005, 0.02, 10, "ribbon_hi", part="Donut")
    mb.cylinder((-0.95, -0.2, 2.45), (0, -1, 0), 0.08, 0.015, 0.035, 8, "marble_hi", part="DonutHole")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return wall_obj(k, ob, notes="corkboard 4 x 3: notes and Gus's donut list, on a wall face")


def office(k):
    return k.Asset("Decor_Office", [desk(k), coat_hooks(k), boxes(k), corkboard(k)],
                   notes="Back-room and office props: desk with a lamp, coat hooks, stock boxes, a corkboard.")


# ================================================================ Decor_Theme (each level's own shop)

def cake_stand(k):
    """Bakery: a tiered cake stand on a little table, a layer cake on top, cupcakes on the tiers (window display)."""
    mb = k.MB("Decor_Bakery_Cakes")
    mb.cylinder((0, 0, 0), (0, 0, 1), 1.3, 0.0, 0.15, 14, "marble_lo", part="Foot")
    mb.cylinder((0, 0, 0.1), (0, 0, 1), 0.18, 0.0, 2.9, 8, "marble", part="Stem")
    for i, (z, r) in enumerate(((1.0, 1.4), (2.0, 1.05), (3.0, 0.75))):
        mb.cylinder((0, 0, z), (0, 0, 1), r, 0.0, 0.1, 14, "snow", chamfer=0.03, cham_col="marble_hi", part=f"Plate{i}")
        n = (6, 5, 0)[i]
        for j in range(n):
            a = math.radians(j * 360 / max(n, 1) + 15)
            x, y = (r - 0.38) * math.cos(a), (r - 0.38) * math.sin(a)
            mb.cylinder((x, y, z + 0.1 - E), (0, 0, 1), 0.22, 0.0, 0.25, 6, "wood_hi", part=f"Cup{i}{j}")
            mb.sphere((x, y, z + 0.38), 0.22, segs=6, rings=3, col=("ribbon_hi", "snow", "holly")[j % 3],
                      part=f"Icing{i}{j}")
    mb.cylinder((0, 0, 3.1 - E), (0, 0, 1), 0.6, 0.0, 0.55, 12, "snow", part="CakeLow")
    mb.cylinder((0, 0, 3.62), (0, 0, 1), 0.42, 0.0, 0.45, 12, "ribbon_hi", part="CakeTop")
    mb.sphere((0, 0, 4.12), 0.14, segs=6, rings=4, col="ribbon", part="Cherry")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, notes="bakery window display: tiered stand, cupcakes and a layer cake (4.3 tall)")


def pharmacy_counter(k):
    """Pharmacy: a dispensing counter 6 x 2.6 with jars and a standing green cross sign on a post (no glow)."""
    mb = k.MB("Decor_Pharmacy_Counter")
    mb.box((-3.0, -1.2, 0.0), (3.0, 1.3, 3.1), "marble", chamfer=0.08, cham_col="marble_hi", flat=("-z",), part="Body")
    mb.box((-2.8, -1.25, 0.5), (2.8, -1.2 + E, 2.6), "holly_lo", part="Front")
    mb.box((-3.15, -1.35, 3.05), (3.15, 1.4, 3.35), "steel_hi", chamfer=0.06, cham_col="snow", part="Top")
    for j in range(5):
        x = -2.3 + j * 1.15
        mb.cylinder((x, 0.4, 3.35 - E), (0, 0, 1), 0.3, 0.0, 0.8, 8, ("steel_hi", "snow", "leaf_hi")[j % 3],
                    part=f"Jar{j}")
        mb.cylinder((x, 0.4, 4.1), (0, 0, 1), 0.33, 0.0, 0.14, 8, "holly_lo", part=f"Cap{j}")
    mb.cylinder((2.3, 0.9, 3.35 - E), (0, 0, 1), 0.08, 0.0, 2.9, 6, "steel", part="SignPost")
    for lo, hi in (((1.95, 0.82, 5.4), (2.65, 0.98, 7.0)), ((1.5, 0.82, 5.85), (3.1, 0.98, 6.55))):
        mb.box(lo, hi, "holly", chamfer=0.04, cham_col="holly", part="Cross")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="pharmacy counter 6.3 x 2.75 with jars and a green cross sign (7 tall)")


def deli_case(k):
    """Deli: a chilled glass-topped case 6 x 2.6 with cheeses and hams, salamis hanging on a rail above it."""
    mb = k.MB("Decor_Deli_Case")
    mb.box((-3.0, -1.2, 0.0), (3.0, 1.3, 2.4), "steel", chamfer=0.08, cham_col="steel_hi", flat=("-z",), part="Body")
    mb.box((-2.8, -1.25, 0.4), (2.8, -1.2 + E, 2.0), "marble_hi", part="Front")
    for i in range(6):
        mb.box((-2.6 + i * 0.9, -1.28, 0.6), (-2.2 + i * 0.9, -1.25 + E, 1.8), "holly_lo", part=f"Stripe{i}")
    mb.box((-2.9, -1.1, 2.4 - E), (2.9, 1.2, 2.55), "snow", part="Bed")
    for i, (x, c, s) in enumerate(((-2.2, "marble", "wedge"), (-1.1, "ribbon_hi", "ham"), (0.1, "marble_lo", "wheel"),
                                   (1.3, "ribbon_hi", "ham"), (2.3, "marble", "wedge"))):
        if s == "wheel":
            mb.cylinder((x, 0.0, 2.55 - E), (0, 0, 1), 0.55, 0.0, 0.45, 10, c, cap_col="marble_hi", part=f"Food{i}")
        elif s == "ham":
            hv = mb.sphere((x, 0.0, 2.85), 0.45, segs=8, rings=4, col=c, part=f"Food{i}")
            mb.xform(hv, Matrix.Translation(Vector((x, 0, 2.85))) @ Matrix.Diagonal((1.0, 0.7, 0.75, 1)) @
                     Matrix.Translation(Vector((-x, 0, -2.85))))
        else:
            wv = mb.prism([(0, 0), (0.9, 0), (0, 0.5)], "Y", -0.35, 0.35, c, "marble_lo", part=f"Food{i}")
            mb.move(wv, (x - 0.4, 0.0, 2.55 - E))
    # the salami rail on two posts at the back
    for sx in (-1, 1):
        mb.box((sx * 2.8 - 0.07, 1.0, 2.4 - E), (sx * 2.8 + 0.07, 1.2, 6.3), "steel_lo", part=f"RailPost{sx}")
    mb.box((-2.9, 1.0, 6.2), (2.9, 1.2, 6.35), "steel", part="Rail")
    for i in range(7):
        x = -2.3 + i * 0.77
        mb.box((x - 0.02, 1.08, 5.55), (x + 0.02, 1.12, 6.25), "marble_lo", part=f"String{i}")
        mb.cylinder((x, 1.1, 4.2 + (i % 2) * 0.35), (0, 0, 1), 0.2, 0.0, 1.4, 6,
                    ("ribbon", "wood_lo", "ribbon")[i % 3], part=f"Salami{i}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="deli case 6 x 2.6: cheeses and hams, salamis on a rail (6.4 tall)")


def jewel_case(k):
    """Jeweller: a velvet-lined display case 5 x 2.4 (rings and watches in Vault Steel light: no gold, no ice) and a
    bust with a necklace of steel beads."""
    mb = k.MB("Decor_Jeweller_Case")
    mb.box((-2.5, -1.1, 0.0), (2.5, 1.2, 2.8), "wood_lo", chamfer=0.08, cham_col="wood", flat=("-z",), part="Body")
    mb.box((-2.3, -1.15, 0.4), (2.3, -1.1 + E, 2.4), "ink_hi", part="Panel")
    mb.box((-2.4, -1.0, 2.8 - E), (2.4, 1.1, 3.0), "ribbon", part="Velvet")
    for i in range(6):
        x = -1.9 + i * 0.75
        mb.cylinder((x, -0.4, 3.0 - E), (0, 0, 1), 0.17, 0.0, 0.2, 8, "ink_hi", part=f"RingBox{i}")
        mb.lathe([(0.12, 0.0), (0.16, 0.06), (0.12, 0.12), (0.08, 0.06)], 8, "steel_hi", (x, -0.4, 3.17),
                 axis=(0, 1, 0), closed=True, part=f"Ring{i}")
    for i in range(3):
        x = -1.3 + i * 1.3
        mb.box((x - 0.35, 0.3, 3.0 - E), (x + 0.35, 0.8, 3.12), "steel_hi", part=f"Watch{i}")
        mb.cylinder((x, 0.55, 3.1), (0, 0, 1), 0.2, 0.0, 0.08, 10, "marble_hi", part=f"Dial{i}")
    mb.lathe([(0, 3.0 - E), (0.4, 3.0 - E), (0.15, 3.3), (0.12, 4.2), (0.45, 4.4), (0.55, 4.9), (0.2, 5.3), (0, 5.3)],
             10, ["ink_hi", "ink_hi", "ink_hi", "ribbon", "ribbon", "ribbon", "ribbon"], (2.0, 0.6, 0.0), part="Bust")
    for j in range(9):
        a = math.radians(200 + j * 17.5)
        mb.sphere((2.0 + 0.47 * math.cos(a), 0.6 + 0.47 * math.sin(a), 4.62), 0.07, segs=6, rings=3,
                  col="steel_hi", part=f"Bead{j}")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="jeweller's velvet case 5 x 2.3 with rings, watches and a bust")


def repair_bench(k):
    """Toy repair: a workbench 6 x 2.6 with a pegboard of tools, a half-mended teddy and a wind-up robot."""
    mb = k.MB("Decor_Repair_Bench")
    for sx in (-1, 1):
        mb.box((sx * 2.8 - 0.15, -1.1, 0.0), (sx * 2.8 + 0.15, 1.1, 3.0), "wood_lo", part=f"Leg{sx}")
    mb.box((-3.0, -1.3, 2.9), (3.0, 1.3, 3.25), "wood", chamfer=0.06, cham_col="wood_hi", part="Top")
    mb.box((-2.8, -1.0, 0.7), (2.8, 1.1, 0.85), "wood_lo", part="Shelf")
    mb.box((-3.0, 1.1, 3.25 - E), (3.0, 1.3, 7.0), "marble_lo", part="Pegboard")
    for i, (x, z, w, h, c) in enumerate(((-2.4, 5.4, 0.15, 1.2, "steel"), (-1.8, 5.2, 0.5, 0.15, "steel_hi"),
                                         (-1.0, 5.6, 0.12, 1.0, "ribbon"), (-0.3, 5.0, 0.7, 0.5, "steel_lo"),
                                         (0.8, 5.5, 0.12, 1.1, "holly"), (1.5, 4.6, 0.9, 0.12, "steel"),
                                         (2.2, 5.3, 0.15, 1.3, "steel_hi"))):
        mb.box((x, 1.0, z), (x + w, 1.1 + E, z + h), c, part=f"Tool{i}")
    mb.box((-2.6, 0.95, 3.6), (2.6, 1.1 + E, 3.75), "steel_lo", part="ToolRail")
    # the teddy on the bench (patched, one arm off beside it): marble_lo, like the shelf teddies
    mb.sphere((-1.2, -0.2, 3.85), 0.6, segs=8, rings=5, col="marble_lo", part="TedBody")
    mb.sphere((-1.2, -0.25, 4.7), 0.42, segs=8, rings=5, col="marble_lo", part="TedHead")
    mb.box((-0.6, -0.6, 3.25 - E), (-0.1, -0.3, 3.45), "marble_lo", part="TedArm")
    mb.box((-1.45, -0.62, 3.9), (-1.0, -0.52, 4.25), "ribbon_hi", part="Patch")
    # the wind-up robot
    mb.box((0.8, -0.5, 3.25 - E), (1.6, 0.2, 4.4), "steel", chamfer=0.06, cham_col="steel_hi", part="RobotBody")
    mb.box((0.9, -0.42, 4.38), (1.5, 0.12, 4.95), "steel_hi", chamfer=0.05, cham_col="snow", part="RobotHead")
    mb.box((1.0, -0.47, 4.6), (1.4, -0.4, 4.75), "ink", part="RobotEyes")
    mb.cylinder((1.6, -0.15, 3.85), (1, 0, 0), 0.08, -E, 0.35, 6, "marble_lo", part="Key")
    mb.box((1.9, -0.25, 3.7), (1.98, -0.05, 4.05), "marble_lo", part="KeyWing")
    mb.cylinder((2.3, 0.4, 3.25 - E), (0, 0, 1), 0.25, 0.0, 0.1, 8, "ink_hi", part="LampBase")
    lv = mb.box((-0.05, -0.05, 0.0), (0.05, 0.05, 1.4), "steel", part="LampArm")
    mb.xform(lv, Matrix.Translation(Vector((2.3, 0.4, 3.3))) @ Matrix.Rotation(math.radians(20), 4, "X"))
    mb.lathe([(0, 0.0), (0.35, 0.0), (0.15, 0.35), (0, 0.4)], 8, ["marble_hi", "holly", "holly"], (2.3, -0.06, 4.45),
             axis=(0, 0, 1), part="LampShade")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="toy-repair workbench 6 x 2.6 with a pegboard, a teddy and a robot (7 tall)")


def fruit_stand(k):
    """Grocer: a stepped fruit stand 5 x 3 with crates of apples, oranges (marble_lo) and greens."""
    mb = k.MB("Decor_Grocer_Fruit")
    for i, (yb, zb) in enumerate(((-1.5, 0.0), (-0.5, 0.9), (0.5, 1.8))):
        mb.box((-2.5, yb, 0.0 if i == 0 else zb - 0.9), (2.5, yb + 1.0, zb + 0.9), "wood", chamfer=0.05,
               cham_col="wood_hi", flat=("-z",), part=f"Step{i}")
        for j in range(3):
            x = -2.4 + j * 1.6
            mb.box((x, yb + 0.05, zb + 0.9 - E), (x + 1.5, yb + 0.95, zb + 1.2), "wood_lo", part=f"Crate{i}{j}")
            c = ("ribbon", "marble_lo", "leaf_hi", "holly", "ribbon_hi", "marble")[(i + j * 2) % 6]
            for q in range(3):
                for r in range(2):
                    mb.sphere((x + 0.3 + q * 0.45, yb + 0.28 + r * 0.42, zb + 1.25), 0.21, segs=6, rings=3, col=c,
                              part=f"Fruit{i}{j}{q}{r}")
    mb.box((-2.5, -1.62, 0.3), (2.5, -1.5 + E, 0.8), "marble_hi", part="Price")
    ob = k.finalize(mb, pivot=(0, 0, 0))
    return floor_obj(k, ob, "module", notes="grocer's stepped fruit stand 5 x 3 x 3.2")


def theme(k):
    return k.Asset("Decor_Theme", [cake_stand(k), pharmacy_counter(k), deli_case(k), jewel_case(k), repair_bench(k),
                                   fruit_stand(k)],
                   notes="Each level's own shop: bakery, pharmacy, deli, jeweller, toy repair, grocer hero props.")


# ================================================================ Decor_Trim (tintable)

def frieze(k):
    """Decor_Frieze_8: a tintable band 8 long, 0.85 tall, 0.14 proud (wall prop, origin back bottom centre); code tints
    it with the level's colour (Config.Interior.THEMES frieze) and runs it under the crown of the room's walls."""
    mb = k.MB("Decor_Frieze_8")
    mb.box((-4.0, -0.14, 0.0), (4.0, 0.0, 0.85), "white", flat=("-x", "+x", "+y"), part="Band")
    for i in range(8):
        x = -3.5 + i
        mb.box((x - 0.18, -0.2, 0.25), (x + 0.18, -0.14 + E, 0.6), "white", part=f"Dentil{i}")
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0))
    return k.Obj(ob, "tiny", role="env", pivot="point", collision="Box", can_collide=False, cast_shadow=False,
                 atlas=False, sim="none", tint="runtime (Config.Interior theme frieze)",
                 notes="tintable wall frieze 8 x 0.85, tiles along X (code sets the colour)")


def ceiling_tin(k):
    """Ceiling_8x8_Tin: the BIG ceiling tile's coffers on the tint cell (atlas off): code gives it the level's
    ceiling colour, about 0.6x the wall value, so the ceiling never outshines the walls in first person."""
    mb = k.MB("Ceiling_8x8_Tin")
    mb.box((0.0, 0.0, 0.25), (8.0, 8.0, 0.55), "white", flat=("-x", "+x", "-y", "+y"), part="Plate")
    for i, (a, b) in enumerate(((0.0, 0.35), (3.82, 4.18), (7.65, 8.0))):
        mb.box((a, 0.0, 0.0), (b, 8.0, 0.25), "white", flat=("-y", "+y", "+z"), part="BeamX%d" % i)
    for i, (a, b) in enumerate(((0.0, 0.35), (3.82, 4.18), (7.65, 8.0))):
        for j, (c, d) in enumerate(((0.35, 3.82), (4.18, 7.65))):
            mb.box((c, a, 0.04), (d, b, 0.25), "white", flat=("-x", "+x", "+z"), part="BeamY%d_%d" % (i, j))
    for cx in (2.09, 5.91):
        for cy in (2.09, 5.91):
            mb.box((cx - 0.7, cy - 0.7, 0.13), (cx + 0.7, cy + 0.7, 0.25), "white", part="Boss")
    ob = k.finalize(mb, shading="flat", pivot=(0, 0, 0.55))
    return k.Obj(ob, "module", role="env", symmetric="XY", pivot="point", collision="Box", can_collide=False,
                 cast_shadow=False, atlas=False, sim="none", free_shells=True, tint="runtime (Config.Interior ceiling)",
                 notes="tintable pressed-tin ceiling tile (same frame as Ceiling_8x8): the level's ceiling colour")


def trim(k):
    return k.Asset("Decor_Trim", [frieze(k), ceiling_tin(k)],
                   notes="Tintable trims: the level's wall frieze and its ceiling tile colour.")


def build(k):
    return [shop(k), toy(k), bank(k), office(k), theme(k), trim(k)]
