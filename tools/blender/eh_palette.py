"""Echo Heist kit palette: the single source of truth for swatch colours, atlas cells and the palette audit.

No bpy needed. Run `python3 tools/blender/eh_palette.py` to rebuild assets/textures/EH_Palette_Bank.png and
print the audit (MASTERPLAN 6.2 rules, measured in Oklab / Oklch).

Atlas layout: 256 x 256 px, 8 x 8 cells of 32 px. Cell order is APPEND-ONLY: kit UVs point at cell indices,
so reordering breaks every exported mesh. An atlas swap for another location (Corner Shop, Toy Shop) keeps the
same cells and changes only their colours.
"""
import math, os, struct, sys, zlib

CELL_PX = 32
GRID = 8
ATLAS_PX = CELL_PX * GRID   # 256

# (key, hex, display name, role). Role decides where a swatch may be used (see ROLE_RULES).
SWATCHES = [
    # --- environment base (MASTERPLAN 6.2 base colours + one value step each way) ---
    ("ink",       "#1C1F3B", "Ink Indigo",        "env"),      # 0  base shadow; never darker
    ("ink_hi",    "#2A2D52", "Ink Indigo light",  "env"),      # 1  chamfers on ink
    ("plum_deep", "#2E2A50", "Plum Slate deep",   "env"),      # 2  wainscot, lower walls
    ("plum",      "#3A3560", "Plum Slate",        "env"),      # 3  most walls (30-55 % value band)
    ("plum_hi",   "#4D4778", "Plum Slate light",  "env"),      # 4  chamfers, cut-away wall tops
    ("marble_lo", "#A8987A", "Warm Marble shade", "env"),      # 5
    ("marble",    "#D8C8A8", "Warm Marble",       "env"),      # 6  trims, lit interior
    ("marble_hi", "#EDE2C8", "Warm Marble light", "env"),      # 7  chamfers on marble
    ("steel_lo",  "#4E5675", "Vault Steel shade", "env"),      # 8  frames, deep steel
    ("steel",     "#7C86A6", "Vault Steel",       "env"),      # 9  doors, safes, rails, plates
    ("steel_hi",  "#A9B2CC", "Vault Steel light", "env"),      # 10 bolts, chamfers on steel
    # --- loot (reserved: loot props only) ---
    ("gold_lo",   "#B87A0A", "Heist Gold shade",  "loot"),     # 11
    ("gold",      "#FFC21F", "Heist Gold",        "loot"),     # 12
    ("gold_hi",   "#FFE69C", "Heist Gold light",  "loot"),     # 13
    ("ice_lo",    "#8F98C4", "Diamond Ice shade", "loot"),     # 14
    ("ice",       "#C9D0EE", "Diamond Ice",       "loot"),     # 15
    ("ice_hi",    "#EEF1FB", "Diamond Ice light", "loot"),     # 16
    # --- tint cell: parts that take MeshPart.Color / Neon at runtime ---
    ("white",     "#FFFFFF", "Tint White",        "tint"),     # 17
    # --- signals (reserved: only on the object type named in ROLE_RULES) ---
    ("alarm",     "#FF3838", "Alarm Red",         "danger"),   # 18 lasers, alarm lamps; always with a shape.
    #    PROPOSED v0 tweak of the plan's #FF3348 (Oklab 0.194 to Clone Magenta, rule >= 0.20); owner to confirm
    ("amber",     "#FFD27A", "Torch Amber",       "guard"),    # 19 flashlight cones only
    ("exit",      "#F4F7FF", "Getaway White",     "exit"),     # 20 van, chevrons with arrows
    ("holly",     "#2FBF71", "Holly Green",       "xmas"),     # 21 Christmas dressing layer only
    ("ribbon",    "#8C2F4B", "Ribbon Burgundy",   "xmas"),     # 22 Christmas dressing layer only
    # --- launch kit additions (2026-11-12). Location cells (LOCATION_CELLS) change per atlas swap ---
    ("floor_a",   "#262942", "Floor A",           "env"),      # 23 floor checker, dark (a ground colour)
    ("floor_b",   "#36314D", "Floor B",           "env"),      # 24 floor checker, dark (a ground colour)
    ("wood_lo",   "#41261C", "Wood shade",        "env"),      # 25 counter tops, shelf boards (loot displays)
    ("wood",      "#59392E", "Wood",              "env"),      # 26 furniture bodies, crates, door leaves
    ("wood_hi",   "#704F42", "Wood light",        "env"),      # 27 chamfers on wood
    # --- characters (Gus). Never location cells, so Gus looks the same in every location ---
    ("skin_lo",   "#A87158", "Gus skin shade",    "char"),     # 28 ears, chin underside, hands' sides
    ("skin",      "#D09673", "Gus skin",          "char"),     # 29 face, nose, hands
    ("hair",      "#5A493E", "Gus moustache",     "char"),     # 30 moustache, brows: dark shape on a light face
    ("shirt_lo",  "#516F8E", "Guard shirt shade", "char"),     # 31 cuffs, collar, shirt chamfers facing down
    ("shirt",     "#6E90AF", "Guard shirt",       "char"),     # 32 the shirt: Gus's main value (luma 0.55 vs ground 0.2)
    # --- Christmas dressing extras ---
    ("holly_lo",  "#1C7C48", "Holly Green shade", "xmas"),     # 33 garland and tree bodies
    ("ribbon_hi", "#AD536A", "Ribbon light",      "xmas"),     # 34 chamfers on ribbon
    ("snow",      "#C0C3D5", "Snow",              "xmas"),     # 35 snow piles and caps (small areas only)
    # --- plants (hide spots); calmer and darker than Holly Green so the Christmas layer still pops ---
    ("leaf_lo",   "#1F4127", "Leaf shade",        "env"),      # 36
    ("leaf",      "#345B35", "Leaf",              "env"),      # 37
    ("leaf_hi",   "#52774A", "Leaf light",        "env"),      # 38
]

# Cells that a location atlas swap may recolour (walls, floors, furniture wood). Characters, loot, signals and
# metal never change between locations, so roles in FIXED_ROLES may not use these cells (rule P3).
LOCATION_CELLS = ("plum_deep", "plum", "plum_hi", "floor_a", "floor_b", "wood_lo", "wood", "wood_hi")
FIXED_ROLES = ("char",)

# Location atlases: same cells, new colours (MASTERPLAN 6.7 "atlas swaps"). Bank is the base atlas the kit is
# exported with (assets/textures/EH_Palette_Bank.png); the others are uploaded once and swapped in by code
# (MeshPart.TextureID per location). Each one passes the same audit as the base.
LOCATIONS = {
    "Bank": {},
    "CornerShop": {   # warm brick walls, pine furniture, a cool/warm dark checker floor [decision, owner review]
        "plum_deep": "#44281F", "plum": "#573429", "plum_hi": "#704B3E",
        "floor_a": "#2D2C3A", "floor_b": "#4D372E",
        "wood_lo": "#503721", "wood": "#6B4F34", "wood_hi": "#85684C",
    },
    "ToyShop": {      # sage walls, light pine, green-grey floor (Drop 1, Dec 11) [decision, owner review]
        "plum_deep": "#213625", "plum": "#284029", "plum_hi": "#465F4B",
        "floor_a": "#1C332E", "floor_b": "#2E3D2B",
        "wood_lo": "#5E492E", "wood": "#7C6445", "wood_hi": "#967F5E",
    },
}

# Clone colours never appear in kit meshes; they are listed for the audit only (MASTERPLAN 6.2).
CLONES = [
    ("clone_p1", "#3DE8FF", "Clone Cyan (P1 / solo)", "●1"),
    ("clone_p2", "#FF4FD8", "Clone Magenta (P2)",     "■2"),
    ("clone_p3", "#6A5CFF", "Clone Indigo (P3)",      "▲3"),
    ("clone_p4", "#F4F7FF", "Ghost White (P4)",       "◆4"),
]
ORPHAN = ("tape", "#8A8FA8", "Tape Grey (orphan clones)")

# Which asset roles may use which swatch roles.
ROLE_RULES = {
    "env":    {"env", "tint"},
    "hero":   {"env", "tint"},            # vault door, event centrepiece
    "loot":   {"loot", "env", "tint"},
    "danger": {"env", "danger", "tint"},  # laser emitters, alarm lamps
    "exit":   {"env", "exit", "tint"},
    "xmas":   {"env", "xmas", "tint"},
    "char":   {"env", "char", "tint"},            # Gus (rule P3: no location cells)
    "present": {"loot", "xmas", "env", "tint"},   # Giant Present: heavy loot wrapped for Christmas
}

INDEX = {k: i for i, (k, *_r) in enumerate(SWATCHES)}
HEX = {k: h for k, h, *_r in SWATCHES}
ROLE = {k: r for k, _h, _n, r in SWATCHES}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def oklab(h):
    r, g, b = (srgb_to_linear(c) for c in hex_rgb(h))
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (x ** (1 / 3) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def oklch(h):
    L, a, b = oklab(h)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def ok_dist(h1, h2):
    a, b = oklab(h1), oklab(h2)
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def luma(h):
    """Rec.709 relative value 0-1 in sRGB space, used for the greyscale / value-band tests."""
    r, g, b = hex_rgb(h)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def cell_rect(key):
    """(x0, y0, x1, y1) of a swatch's cell in pixels, origin top-left."""
    i = INDEX[key]
    cx, cy = i % GRID, i // GRID
    return cx * CELL_PX, cy * CELL_PX, (cx + 1) * CELL_PX, (cy + 1) * CELL_PX


def cell_uv(key):
    """UV centre of a swatch's cell (Blender UV, origin bottom-left) and the half-size of the safe square
    (a quarter cell, so bilinear filtering and the first 3 mips never bleed into a neighbour)."""
    x0, y0, x1, y1 = cell_rect(key)
    u = (x0 + x1) / 2 / ATLAS_PX
    v = 1 - (y0 + y1) / 2 / ATLAS_PX
    return u, v, (CELL_PX / 4) / ATLAS_PX


def _png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)


def write_atlas(path, overrides=None):
    """Writes the 256 px atlas. Unused cells are mid grey so a wrong UV shows up at once. overrides: {key: hex}
    for an atlas swap (same cells, new colours)."""
    cols = dict(HEX); cols.update(overrides or {})
    grid = [[(128, 128, 128)] * ATLAS_PX for _ in range(ATLAS_PX)]
    for k in INDEX:
        x0, y0, x1, y1 = cell_rect(k)
        rgb = tuple(round(c * 255) for c in hex_rgb(cols[k]))
        for y in range(y0, y1):
            grid[y][x0:x1] = [rgb] * (x1 - x0)
    rows = [[c for px in row for c in px] for row in grid]
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    _png(path, ATLAS_PX, ATLAS_PX, rows)
    return path


# ---------------------------------------------------------------- audit (MASTERPLAN 6.2 rules)

RESERVED_HUE_DEG = 20.0   # +- around each clone hue
RESERVED_REL_CHROMA = 0.40  # "saturation above 40 %": Oklch chroma relative to that clone colour's chroma
MIN_DIST_SIGNAL = 0.15    # clone vs base colours, loot vs base
MIN_DIST_DANGER = 0.20    # alarm red vs every clone hue (plus a shape)
MIN_VALUE_STEP = 0.15     # greyscale: loot / danger / clones vs the ground


def _audit_cols(cols, tag):
    """The colour rules for one atlas (cols: key -> hex). Returns (ok, lines)."""
    lines, ok = [], True
    env = [(k, cols[k]) for k, _h, _n, r in SWATCHES if r == "env"]
    ground = ["ink", "plum_deep", "plum", "floor_a", "floor_b"]   # floors and walls
    metal = ["steel_lo", "steel"]                  # frames and doors: warning only (laser cores carry value)
    for ck, chex, cname, _g in CLONES:
        L, C, H = oklch(chex)
        for k, _h, _n, r in SWATCHES:
            if r in ("tint", "exit"):
                continue
            l2, c2, h2 = oklch(cols[k])
            dh = abs((h2 - H + 180) % 360 - 180)
            rel = c2 / C if C > 1e-6 else 0
            if C >= 0.02 and dh <= RESERVED_HUE_DEG and rel > RESERVED_REL_CHROMA:
                ok = False; lines.append(f"FAIL [{tag}] reserved hue: {k} {cols[k]} is {dh:.0f} deg from {cname} at {rel:.0%} of its chroma")
        for k in ground:
            d = ok_dist(chex, cols[k])
            if d < MIN_DIST_SIGNAL:
                ok = False; lines.append(f"FAIL [{tag}] {cname} vs {k}: Oklab {d:.3f} < {MIN_DIST_SIGNAL}")
        d = ok_dist(cols["alarm"], chex)
        if d < MIN_DIST_DANGER:
            ok = False; lines.append(f"FAIL [{tag}] Alarm Red vs {cname}: Oklab {d:.3f} < {MIN_DIST_DANGER}")
        for k in ("snow", "shirt", "skin"):          # characters and big light dressing vs clone glows
            d = ok_dist(cols[k], chex)
            if d < MIN_DIST_SIGNAL:
                lines.append(f"WARN [{tag}] {k} vs {cname}: Oklab {d:.3f} < {MIN_DIST_SIGNAL} (small areas only, never a floor field)")
    for k in ("gold", "ice", "alarm", "amber", "exit", "shirt", "skin"):   # loot, danger, signals, Gus vs the ground
        for g in ground:
            dv = abs(luma(cols[k]) - luma(cols[g]))
            if dv < MIN_VALUE_STEP:
                ok = False; lines.append(f"FAIL [{tag}] value step {k} vs {g}: {dv:.2f} < {MIN_VALUE_STEP}")
    for k in ("gold", "ice", "alarm"):
        for g in metal:
            dv = abs(luma(cols[k]) - luma(cols[g]))
            if dv < MIN_VALUE_STEP:
                lines.append(f"WARN [{tag}] value step {k} vs {g}: {dv:.2f} < {MIN_VALUE_STEP} (needs a shape / white core)")
    for k in ("skin", "shirt", "skin_lo"):           # Gus must never read as loot
        d = ok_dist(cols[k], cols["gold"])
        if d < MIN_DIST_SIGNAL:
            ok = False; lines.append(f"FAIL [{tag}] {k} vs Heist Gold: Oklab {d:.3f} < {MIN_DIST_SIGNAL}")
    for lk in ("gold", "gold_hi", "ice", "ice_hi"):      # display rule: what loot may never sit on / against
        bad = [e for e, eh in env if ok_dist(cols[lk], eh) < MIN_DIST_SIGNAL or abs(luma(cols[lk]) - luma(eh)) < MIN_VALUE_STEP]
        if bad:
            lines.append(f"WARN [{tag}] display rule: never put {lk} loot on or against {', '.join(bad)} (Oklab < {MIN_DIST_SIGNAL} or value < {MIN_VALUE_STEP})")
    for g in ground:
        if luma(cols[g]) < luma(cols["ink"]) - 1e-6:
            ok = False; lines.append(f"FAIL [{tag}] {g} darker than Ink Indigo")
    for k in LOCATION_CELLS:                         # a location may recolour walls, not turn them into signals
        if cols[k] != HEX[k]:
            L, C, H = oklch(cols[k])
            if C > 0.093:
                ok = False; lines.append(f"FAIL [{tag}] location cell {k} {cols[k]} chroma {C:.3f} > 0.093 (walls stay calm)")
    return ok, lines


def location_cols(loc):
    cols = dict(HEX); cols.update(LOCATIONS[loc])
    return cols


def audit(verbose=True):
    """Returns (ok, lines). Checks every swatch of every location atlas against the reserved clone hues, signal
    distances and the greyscale value test. Ghost White (P4) is near-neutral, so its hue test is skipped
    (chroma < 0.02)."""
    lines, ok = [], True
    for loc in LOCATIONS:
        o, ls = _audit_cols(location_cols(loc), loc)
        ok &= o
        lines += ls
    if verbose:
        lines.append("swatch       hex      L     C      h     value")
        for k, h, _n, r in SWATCHES:
            L, C, H = oklch(h)
            lines.append(f"{k:<12} {h}  {L:.3f} {C:.3f} {H:6.1f}  {luma(h):.2f}  [{r}]" + ("  (location cell)" if k in LOCATION_CELLS else ""))
        for ck, h, n, g in CLONES:
            L, C, H = oklch(h)
            lines.append(f"{ck:<12} {h}  {L:.3f} {C:.3f} {H:6.1f}  {luma(h):.2f}  [clone {g}]")
        for loc, ov in LOCATIONS.items():
            if ov:
                lines.append(f"{loc}: " + ", ".join(f"{k} {v} (L {oklch(v)[0]:.2f} C {oklch(v)[1]:.3f} h {oklch(v)[2]:.0f})" for k, v in ov.items()))
        lines.append(f"gold vs amber Oklab {ok_dist(HEX['gold'], HEX['amber']):.3f} (shape carries it: sparkle vs cone)")
    lines.insert(0, "palette audit: " + ("PASS" if ok else "FAIL"))
    return ok, lines


def atlas_path(loc="Bank"):
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "textures",
                                         f"EH_Palette_{loc}.png"))


def write_atlases():
    """Writes one atlas per location (assets/textures/EH_Palette_<Location>.png). Returns the paths."""
    return [write_atlas(atlas_path(loc), LOCATIONS[loc]) for loc in LOCATIONS]


ATLAS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "textures", "EH_Palette_Bank.png")

if __name__ == "__main__":
    ps = write_atlases()
    ok, lines = audit()
    print("\n".join(lines))
    for p in ps:
        print("atlas:", p)
    sys.exit(0 if ok else 1)
