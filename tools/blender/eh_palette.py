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
]

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


def audit(verbose=True):
    """Returns (ok, lines). Checks every swatch against the reserved clone hues, signal distances and the
    greyscale value test. Ghost White (P4) is near-neutral, so its hue test is skipped (chroma < 0.02)."""
    lines, ok = [], True
    env = [(k, h) for k, h, _n, r in SWATCHES if r == "env"]
    ground = ["ink", "plum_deep", "plum"]          # floors and walls
    metal = ["steel_lo", "steel"]                  # frames and doors: warning only (laser cores carry value)
    for ck, chex, cname, _g in CLONES:
        L, C, H = oklch(chex)
        for k, h, _n, r in SWATCHES:
            if r in ("tint", "exit"):
                continue
            l2, c2, h2 = oklch(h)
            dh = abs((h2 - H + 180) % 360 - 180)
            rel = c2 / C if C > 1e-6 else 0
            if C >= 0.02 and dh <= RESERVED_HUE_DEG and rel > RESERVED_REL_CHROMA:
                ok = False; lines.append(f"FAIL reserved hue: {k} {h} is {dh:.0f} deg from {cname} at {rel:.0%} of its chroma")
        for k in ground:
            d = ok_dist(chex, HEX[k])
            if d < MIN_DIST_SIGNAL:
                ok = False; lines.append(f"FAIL {cname} vs {k}: Oklab {d:.3f} < {MIN_DIST_SIGNAL}")
        d = ok_dist(HEX["alarm"], chex)
        if d < MIN_DIST_DANGER:
            ok = False; lines.append(f"FAIL Alarm Red vs {cname}: Oklab {d:.3f} < {MIN_DIST_DANGER}")
    for k in ("gold", "ice", "alarm", "amber", "exit"):
        for g in ground:
            dv = abs(luma(HEX[k]) - luma(HEX[g]))
            if dv < MIN_VALUE_STEP:
                ok = False; lines.append(f"FAIL value step {k} vs {g}: {dv:.2f} < {MIN_VALUE_STEP}")
    for k in ("gold", "ice", "alarm"):
        for g in metal:
            dv = abs(luma(HEX[k]) - luma(HEX[g]))
            if dv < MIN_VALUE_STEP:
                lines.append(f"WARN value step {k} vs {g}: {dv:.2f} < {MIN_VALUE_STEP} (needs a shape / white core)")
    for g in ground:
        if luma(HEX[g]) < luma(HEX["ink"]) - 1e-6:
            ok = False; lines.append(f"FAIL {g} darker than Ink Indigo")
    if verbose:
        lines.append("swatch       hex      L     C      h     value")
        for k, h, _n, r in SWATCHES:
            L, C, H = oklch(h)
            lines.append(f"{k:<12} {h}  {L:.3f} {C:.3f} {H:6.1f}  {luma(h):.2f}  [{r}]")
        for ck, h, n, g in CLONES:
            L, C, H = oklch(h)
            lines.append(f"{ck:<12} {h}  {L:.3f} {C:.3f} {H:6.1f}  {luma(h):.2f}  [clone {g}]")
        lines.append(f"gold vs amber Oklab {ok_dist(HEX['gold'], HEX['amber']):.3f} (shape carries it: sparkle vs cone)")
    lines.insert(0, "palette audit: " + ("PASS" if ok else "FAIL"))
    return ok, lines


ATLAS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "textures", "EH_Palette_Bank.png")

if __name__ == "__main__":
    p = write_atlas(os.path.normpath(ATLAS_PATH))
    ok, lines = audit()
    print("\n".join(lines))
    print("atlas:", os.path.normpath(p))
    sys.exit(0 if ok else 1)
