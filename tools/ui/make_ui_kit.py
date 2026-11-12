#!/usr/bin/env python3
"""Script-generated UI kit images (PLAN_STEAM_PLUS §4.3 U1/U2, roblox_quality §3.3-3.4, premium D8).

Writes, deterministically (no randomness except a seeded grain):
  assets/ui/EH_UI_Panel.png    96 x 96 9-slice: rounded body (value 0.80), 2 px inner top highlight
                               (1.0), 10 px bottom lip (0.50), 2 % grain. White-ish so ImageColor3 tints it
                               (Heist/Theme divides the target colour by BODY_VALUE). SliceScale 0.5.
  assets/ui/EH_UI_Shadow.png   96 x 96 9-slice soft shadow (ink alpha, 8 px blur). SliceScale 0.5.
  assets/ui/EH_UI_Icons.png    512 x 320 icon sheet: 8 x 5 cells of 64 px, one 24-unit grid, 2.5-unit
                               stroke, round caps and joins, white glyph + thin ink outline (tints with
                               ImageColor3). Drawn at 4x, downsampled with LANCZOS.
  src/client/Heist/IconsData.luau  name -> cell (generated: the Icons module reads it)

  python3 tools/ui/make_ui_kit.py                  # write the images + IconsData.luau
  python3 tools/ui/make_ui_kit.py --sheet OUT.png  # also a 16/24/32/48 px contact sheet on dark + light
  python3 tools/ui/make_ui_kit.py --specimen OUT.png --fonts DIR   # PIL approximation of the D8 type specimen

Upload: python3 tools/kit_upload.py --ui (Decals; ids in assets/kit_ids.json "ui" and the generated
src/shared/Heist/UiAssets.luau). The engine resolves Decal -> image id at boot (server Heist/UiImages).
"""
import argparse
import math
import pathlib
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets/ui"
ICONS_LUAU = ROOT / "src/client/Heist/IconsData.luau"

INK = (0x1C, 0x1F, 0x3B)
CELL = 64  # final px per icon cell
SS = 4  # supersampling
GRID = 24.0  # design grid units per cell
STROKE = 2.5  # grid units
COLS, ROWS = 8, 5
OUTLINE = 1.6  # final px of ink outline around each glyph

BODY_VALUE = 0.80  # Theme.PANEL_BODY_VALUE must match
HILITE_VALUE = 1.0
LIP_VALUE = 0.50


# ------------------------------------------------------------------------------------------- panels

def panel_image() -> Image.Image:
    size, r, lip, hl = 96, 24, 10, 4
    s = SS
    big = size * s
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=r * s, fill=255)
    val = Image.new("L", (big, big), int(255 * BODY_VALUE))
    d = ImageDraw.Draw(val)
    # bottom lip: the lowest `lip` px of the shape
    d.rectangle((0, big - lip * s, big, big), fill=int(255 * LIP_VALUE))
    # inner top highlight: a thin rounded band just inside the top edge
    hmask = Image.new("L", (big, big), 0)
    hd = ImageDraw.Draw(hmask)
    hd.rounded_rectangle((3 * s, 3 * s, big - 3 * s, big - lip * s), radius=(r - 3) * s, outline=255, width=hl * s // 2)
    hd.rectangle((0, (r + 6) * s, big, big), fill=0)  # only the top arc + top edge
    val.paste(int(255 * HILITE_VALUE), (0, 0), hmask)
    img = Image.merge("RGBA", (val, val, val, mask)).resize((size, size), Image.LANCZOS)
    # 2 % grain (seeded): kills banding on big tinted panels
    rng = random.Random(7)
    px = img.load()
    for y in range(size):
        for x in range(size):
            rr, gg, bb, aa = px[x, y]
            if aa:
                n = int(rng.uniform(-0.02, 0.02) * 255)
                v = max(0, min(255, rr + n))
                px[x, y] = (v, v, v, aa)
    return img


def shadow_image() -> Image.Image:
    size, r, blur = 96, 24, 8
    img = Image.new("L", (size, size), 0)
    ImageDraw.Draw(img).rounded_rectangle((blur, blur, size - 1 - blur, size - 1 - blur), radius=r - blur, fill=255)
    img = img.filter(ImageFilter.GaussianBlur(blur / 2))
    rgba = Image.new("RGBA", (size, size), INK + (0,))
    rgba.putalpha(img)
    return rgba


# -------------------------------------------------------------------------------------------- icons

class Pen:
    """Draws on a supersampled alpha mask in 24-unit grid coordinates."""

    def __init__(self) -> None:
        self.px = CELL * SS
        self.k = self.px / GRID
        self.mask = Image.new("L", (self.px, self.px), 0)
        self.d = ImageDraw.Draw(self.mask)

    def p(self, x: float, y: float) -> tuple:
        return (x * self.k, y * self.k)

    def w(self, units: float = STROKE) -> float:
        return units * self.k

    def dot(self, x: float, y: float, r: float, fill: int = 255) -> None:
        cx, cy = self.p(x, y)
        rr = r * self.k
        self.d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=fill)

    def line(self, pts: list, closed: bool = False, width: float = STROKE, fill: int = 255) -> None:
        pts = list(pts) + ([pts[0]] if closed else [])
        w = self.w(width)
        for a, b in zip(pts, pts[1:]):
            self.d.line((self.p(*a), self.p(*b)), fill=fill, width=int(round(w)))
        for x, y in pts:
            self.dot(x, y, width / 2, fill)

    def fill(self, pts: list, fill: int = 255) -> None:
        """Filled polygon with rounded corners (a stroke around it rounds the joins)."""
        self.d.polygon([self.p(*q) for q in pts], fill=fill)
        self.line(pts, closed=True, width=STROKE * 0.8, fill=fill)

    def ring(self, x: float, y: float, r: float, width: float = STROKE, fill: int = 255) -> None:
        cx, cy = self.p(x, y)
        rr, w = r * self.k, self.w(width)
        self.d.ellipse((cx - rr - w / 2, cy - rr - w / 2, cx + rr + w / 2, cy + rr + w / 2), outline=fill, width=int(round(w)))

    def arc(self, x: float, y: float, r: float, a0: float, a1: float, width: float = STROKE, caps: bool = True) -> None:
        """Arc in degrees, 0 = +x, clockwise (screen y down), round caps."""
        cx, cy = self.p(x, y)
        rr, w = r * self.k, self.w(width)
        self.d.arc((cx - rr - w / 2, cy - rr - w / 2, cx + rr + w / 2, cy + rr + w / 2), a0, a1, fill=255, width=int(round(w)))
        if caps:
            for a in (a0, a1):
                t = math.radians(a)
                self.dot(x + r * math.cos(t), y + r * math.sin(t), width / 2)

    def rrect(self, x0: float, y0: float, x1: float, y1: float, r: float, filled: bool = False, width: float = STROKE, fill: int = 255) -> None:
        if filled:
            self.d.rounded_rectangle((*self.p(x0, y0), *self.p(x1, y1)), radius=r * self.k, fill=fill)
        else:
            w = self.w(width)
            a, b = self.p(x0, y0), self.p(x1, y1)
            self.d.rounded_rectangle((a[0] - w / 2, a[1] - w / 2, b[0] + w / 2, b[1] + w / 2), radius=(r + width / 2) * self.k, outline=fill, width=int(round(w)))


def star_pts(cx: float, cy: float, ro: float, ri: float) -> list:
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def person(p: Pen, x: float, y: float) -> None:
    p.ring(x, y - 4.5, 3.2)
    p.arc(x, y + 7, 6, 180, 360)


def eye(p: Pen, pupil: float) -> None:
    p.arc(12, 19.5, 10.5, 222, 318)
    p.arc(12, 4.5, 10.5, 42, 138)
    p.dot(12, 12, pupil)


def icon_defs() -> list:
    """(name, draw function) in sheet order. Names are the Icons module's keys."""
    defs = []

    def add(name):
        def deco(fn):
            defs.append((name, fn))
            return fn
        return deco

    @add("rewind")
    def _(p):
        p.fill([(11.5, 6), (11.5, 18), (3.5, 12)])
        p.fill([(20.5, 6), (20.5, 18), (12.5, 12)])

    @add("fast_forward")
    def _(p):
        p.fill([(3.5, 6), (3.5, 18), (11.5, 12)])
        p.fill([(12.5, 6), (12.5, 18), (20.5, 12)])

    @add("play")
    def _(p):
        p.fill([(7.5, 5), (7.5, 19), (19, 12)])

    @add("pause")
    def _(p):
        p.line([(8.5, 6), (8.5, 18)], width=3.2)
        p.line([(15.5, 6), (15.5, 18)], width=3.2)

    @add("menu")
    def _(p):
        for y in (6.5, 12, 17.5):
            p.line([(5, y), (19, y)])

    @add("clone")
    def _(p):
        # the back copy (offset left and up) as a partial outline, then you in front
        p.arc(8.5, 6.5, 3, 150, 330)
        p.arc(8.5, 17.5, 5.5, 180, 235)
        person(p, 14, 11)

    @add("you")
    def _(p):
        p.fill([(12, 21), (5, 12.5), (9.5, 12.5), (9.5, 3.5), (14.5, 3.5), (14.5, 12.5), (19, 12.5)])

    @add("plate")
    def _(p):
        p.rrect(4, 15, 20, 19.5, 1.5)
        p.line([(12, 3.5), (12, 11)])
        p.line([(8.5, 8), (12, 11.5), (15.5, 8)])

    @add("door")
    def _(p):
        p.rrect(6.5, 3.5, 17.5, 20.5, 1.2)
        p.dot(14.5, 12.5, 1.5)
        p.line([(3, 20.5), (21, 20.5)])

    @add("laser")
    def _(p):
        p.rrect(3.5, 4, 5.5, 20, 0.8)
        p.rrect(18.5, 4, 20.5, 20, 0.8)
        p.line([(8, 9), (16, 9)], width=2)
        p.line([(8, 15), (16, 15)], width=2)

    @add("loot")
    def _(p):
        p.ring(12, 15.5, 5.8)
        p.fill([(8.5, 4), (15.5, 4), (12, 8.5)])
        p.line([(12, 12.5), (12, 18.5)], width=2)
        p.line([(10, 13.5), (14, 13.5)], width=2)

    @add("van")
    def _(p):
        p.rrect(2.5, 6.5, 21.5, 16.5, 2)
        p.line([(15.5, 6.5), (15.5, 11), (21.5, 11)], width=2)
        p.dot(7, 18, 2.6)
        p.dot(17, 18, 2.6)

    @add("gus")
    def _(p):
        p.ring(12, 14, 5.5)
        p.fill([(6, 8.5), (18, 8.5), (16.5, 4), (7.5, 4)])
        p.line([(4, 9), (20, 9)])
        p.dot(9.8, 14.3, 1.1)
        p.dot(14.2, 14.3, 1.1)
        p.line([(9.8, 17.3), (14.2, 17.3)], width=1.8)

    @add("star")
    def _(p):
        p.fill(star_pts(12, 12.6, 9.5, 4.2))

    @add("star_empty")
    def _(p):
        p.line(star_pts(12, 12.6, 9.5, 4.2), closed=True)

    @add("star_half")
    def _(p):
        pts = star_pts(12, 12.6, 9.5, 4.2)
        p.fill(pts)
        p.d.rectangle((*p.p(12, 0), *p.p(24, 24)), fill=0)
        p.line(pts, closed=True)

    @add("hidden")
    def _(p):
        eye(p, 2.4)
        p.line([(4, 21), (20, 3)], width=STROKE + 2.4, fill=0)
        p.line([(4.5, 20.5), (19.5, 3.5)])

    @add("alarm")
    def _(p):
        p.line([(6.5, 17), (6.5, 11)])
        p.arc(12, 11, 5.5, 180, 360)
        p.line([(17.5, 11), (17.5, 17)])
        p.line([(4, 17), (20, 17)])
        p.dot(12, 20.3, 1.8)
        p.line([(3, 5.5), (5, 7.5)], width=2)
        p.line([(21, 5.5), (19, 7.5)], width=2)

    @add("sunrise")
    def _(p):
        p.line([(2.5, 18.5), (21.5, 18.5)])
        p.arc(12, 18.5, 5.8, 180, 360)
        p.line([(12, 4.5), (12, 7.5)])
        p.line([(4.8, 9.5), (6.8, 11.5)])
        p.line([(19.2, 9.5), (17.2, 11.5)])

    @add("delete")
    def _(p):
        p.line([(4, 6.5), (20, 6.5)])
        p.line([(9.5, 6.5), (9.5, 4), (14.5, 4), (14.5, 6.5)], width=2)
        p.line([(6.5, 6.5), (7.8, 20.5), (16.2, 20.5), (17.5, 6.5)])
        p.line([(10.2, 10.5), (10.2, 16.5)], width=2)
        p.line([(13.8, 10.5), (13.8, 16.5)], width=2)

    @add("undo")
    def _(p):
        p.line([(8, 5), (4, 9), (8, 13)])
        p.line([(4, 9), (13, 9)])
        p.arc(13, 14, 5, 270, 450, caps=False)
        p.line([(13, 19), (8, 19)])

    @add("replay")
    def _(p):
        cx, cy, r, a0, a1 = 12, 13, 7, -50, 230
        p.arc(cx, cy, r, a0, a1)
        t = math.radians(a1)
        ex, ey = cx + r * math.cos(t), cy + r * math.sin(t)
        tx, ty = -math.sin(t), math.cos(t)  # direction of travel (clockwise)
        nx, ny = math.cos(t), math.sin(t)
        p.fill([(ex + tx * 3.6, ey + ty * 3.6), (ex + nx * 3.2, ey + ny * 3.2), (ex - nx * 3.2, ey - ny * 3.2)])

    @add("invite")
    def _(p):
        person(p, 9.5, 11.5)
        p.line([(19, 6.5), (19, 13.5)])
        p.line([(15.5, 10), (22.5, 10)])

    @add("settings")
    def _(p):
        for k in range(8):
            a = math.radians(k * 45 + 22.5)
            p.line([(12 + 6.6 * math.cos(a), 12 + 6.6 * math.sin(a)), (12 + 9.2 * math.cos(a), 12 + 9.2 * math.sin(a))], width=3.4)
        p.ring(12, 12, 6)
        p.ring(12, 12, 2.2, width=2)

    @add("close")
    def _(p):
        p.line([(6, 6), (18, 18)])
        p.line([(18, 6), (6, 18)])

    @add("cross")
    def _(p):
        p.ring(12, 12, 8.5)
        p.line([(8.5, 8.5), (15.5, 15.5)])
        p.line([(15.5, 8.5), (8.5, 15.5)])

    @add("check")
    def _(p):
        p.line([(4.5, 12.5), (9.8, 17.8), (19.5, 6.5)], width=3)

    @add("lock")
    def _(p):
        p.arc(12, 10, 4.6, 180, 360)
        p.line([(7.4, 10), (7.4, 11.5)])
        p.line([(16.6, 10), (16.6, 11.5)])
        p.rrect(4.5, 11, 19.5, 21, 2, filled=True)
        p.dot(12, 15.2, 1.7, fill=0)
        p.line([(12, 15.5), (12, 18)], width=1.6, fill=0)

    @add("crown")
    def _(p):
        p.fill([(3.5, 8), (7.5, 13), (12, 5), (16.5, 13), (20.5, 8), (18.5, 18), (5.5, 18)])
        p.line([(5.5, 20.8), (18.5, 20.8)], width=2)

    @add("camera")
    def _(p):
        p.rrect(3, 8, 21, 19.5, 2)
        p.fill([(8, 8), (9.5, 5), (14.5, 5), (16, 8)])
        p.ring(12, 13.7, 3.4)

    @add("gift")
    def _(p):
        p.rrect(4.5, 11.5, 19.5, 21, 1.2)
        p.rrect(3, 7.5, 21, 11.5, 1)
        p.line([(12, 7.5), (12, 21)])
        p.ring(9.6, 5, 2.2, width=2)
        p.ring(14.4, 5, 2.2, width=2)

    @add("coin")
    def _(p):
        p.ring(12, 12, 8.5)
        p.ring(12, 12, 4.2, width=2)

    @add("bolt")
    def _(p):
        p.fill([(14, 2.5), (5.5, 13.5), (11.5, 13.5), (9.5, 21.5), (18.5, 10), (12.5, 10)])

    @add("seat_circle")
    def _(p):
        p.dot(12, 12, 8)

    @add("seat_square")
    def _(p):
        p.rrect(4.5, 4.5, 19.5, 19.5, 2.2, filled=True)

    @add("seat_triangle")
    def _(p):
        p.fill([(12, 4), (20.5, 19.5), (3.5, 19.5)])

    @add("seat_diamond")
    def _(p):
        p.fill([(12, 3), (21, 12), (12, 21), (3, 12)])

    @add("gus_eye")
    def _(p):
        # Gus is looking (run-bar turn marker, amber): an open eye
        eye(p, 3)

    return defs


def render_icon(fn) -> Image.Image:
    pen = Pen()
    fn(pen)
    mask = pen.mask
    o = int(round(OUTLINE * SS))
    outline = mask.filter(ImageFilter.MaxFilter(2 * o + 1))
    big = Image.new("RGBA", mask.size, INK + (0,))
    big.putalpha(outline)
    white = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    white.putalpha(mask)
    big = Image.alpha_composite(big, white)
    return big.resize((CELL, CELL), Image.LANCZOS)


def icon_sheet() -> tuple:
    defs = icon_defs()
    assert len(defs) <= COLS * ROWS, f"{len(defs)} icons do not fit {COLS}x{ROWS}"
    sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    cells = []
    for i, (name, fn) in enumerate(defs):
        col, row = i % COLS, i // COLS
        sheet.paste(render_icon(fn), (col * CELL, row * CELL))
        cells.append((name, col * CELL, row * CELL))
    return sheet, cells


def icons_luau(cells: list) -> str:
    lines = [
        "--!strict",
        "-- GENERATED by tools/ui/make_ui_kit.py: do not edit. Icon name -> top-left px of its cell on",
        f"-- EH_UI_Icons ({COLS * CELL} x {ROWS * CELL}, cells of {CELL} px; 24-unit grid, 2.5-unit stroke, round caps).",
        "",
        "return table.freeze({",
        f"\tCELL = {CELL},",
        "\tcells = table.freeze({",
    ]
    for name, x, y in cells:
        lines.append(f"\t\t{name} = Vector2.new({x}, {y}),")
    lines += ["\t}),", "})", ""]
    return "\n".join(lines)


def contact_sheet(sheet: Image.Image, cells: list, out: pathlib.Path) -> None:
    sizes = [16, 24, 32, 48]
    pad = 6
    rowh = sum(sizes) + pad * (len(sizes) + 1)
    w = len(cells) * (48 + pad) + pad
    img = Image.new("RGBA", (w, rowh * 2), (0x1C, 0x1F, 0x3B, 255))
    ImageDraw.Draw(img).rectangle((0, rowh, w, rowh * 2), fill=(0xD8, 0xC8, 0xA8, 255))
    for band in range(2):
        for i, (_, x, y) in enumerate(cells):
            cell = sheet.crop((x, y, x + CELL, y + CELL))
            yy = band * rowh + pad
            for s in sizes:
                img.alpha_composite(cell.resize((s, s), Image.LANCZOS), (pad + i * (48 + pad), yy))
                yy += s + pad
    img.convert("RGB").save(out)


# ------------------------------------------------------------------------------------ type specimen

def specimen(out: pathlib.Path, font_dir: pathlib.Path) -> None:
    """A PIL approximation of the Studio specimen (GOLDEN_FRAMES "Typography specimen"). Builder Sans is
    not available as a file: Inter stands in for the UI face. Approximation only: the owner judges the
    Studio frame (EH_Scenario = "TYPE")."""
    faces = {}
    for name, pattern in (("Luckiest Guy", "luckiest-guy-latin-400-normal.woff*"), ("Fredoka One", "fredoka-one-latin-400-normal.woff2")):
        found = sorted(font_dir.rglob(pattern))
        for f in found:
            try:
                ImageFont.truetype(str(f), 20)
                faces[name] = str(f)
                break
            except OSError:
                continue
    ui_face = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
    if not faces:
        print("specimen: no display font files found; skipped")
        return
    W, H = 1600, 260 + 330 * len(faces)
    img = Image.new("RGB", (W, H), (0x1C, 0x1F, 0x3B))
    d = ImageDraw.Draw(img)
    # G1-like backdrop: a warm pool on indigo
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.25, -200, W * 0.95, H * 0.7), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    img.paste(Image.new("RGB", (W, H), (0xFF, 0xD2, 0x7A)), (0, 0), glow)
    d = ImageDraw.Draw(img)
    cyan, ink, gold, white, red = (0x3D, 0xE8, 0xFF), INK, (0xFF, 0xC2, 0x1F), (255, 255, 255), (0xFF, 0x38, 0x38)

    def text(xy, s, font, fill, stroke=0):
        d.text(xy, s, font=font, fill=fill, stroke_width=stroke, stroke_fill=ink)

    first = next(iter(faces.values()))
    wm = ImageFont.truetype(first, 110)
    text((64 + 10, 40 + 8), "HEIST YOURSELF", wm, cyan, 6)  # the cyan double exposure
    text((64, 40), "HEIST YOURSELF", wm, white, 6)
    small = ImageFont.truetype(ui_face, 22)
    text((64, 190), "Wordmark (" + next(iter(faces)) + ") with a cyan double-exposure offset. UI face: Builder Sans (Inter stands in here).", small, (0xA9, 0xB2, 0xCC))
    y = 250
    for name, path in faces.items():
        text((64, y), name, ImageFont.truetype(ui_face, 28), gold, 2)
        x = 64
        for s in (14, 24, 36, 64):
            f = ImageFont.truetype(path, s)
            text((x, y + 50 + (64 - s)), f"{s} PX", f, white, max(1, round(s * 0.06)))
            x += int(f.getlength(f"{s} PX")) + 40
        # stamp
        f = ImageFont.truetype(path, 64)
        stamp = Image.new("RGBA", (460, 120), (0, 0, 0, 0))
        sd = ImageDraw.Draw(stamp)
        sd.rounded_rectangle((6, 6, 454, 114), radius=16, fill=(0x1C, 0x1F, 0x3B, 235), outline=red, width=6)
        sd.text((230, 62), "BUSTED!", font=f, fill=red, anchor="mm", stroke_width=4, stroke_fill=ink)
        img.paste(stamp.rotate(-6, expand=True, resample=Image.BICUBIC), (64, y + 140), stamp.rotate(-6, expand=True, resample=Image.BICUBIC))
        # button (raised slab with a lip)
        bx, by = 600, y + 160
        d.rounded_rectangle((bx, by + 6, bx + 300, by + 86), radius=12, fill=(0x1F, 0x7F, 0x8C))
        d.rounded_rectangle((bx, by, bx + 300, by + 80), radius=12, fill=cyan, outline=ink, width=3)
        d.text((bx + 150, by + 42), "NEXT JOB", font=ImageFont.truetype(path, 36), fill=ink, anchor="mm")
        # results line
        rl = ImageFont.truetype(path, 36)
        text((980, y + 175), "HAUL: $1,000 STOLEN", rl, gold, 2)
        y += 330
    img.save(out)
    print(f"specimen: {out} ({', '.join(faces)})")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sheet", metavar="PNG", help="also write a contact sheet (16/24/32/48 px, dark + light)")
    ap.add_argument("--specimen", metavar="PNG", help="also write the PIL type specimen")
    ap.add_argument("--fonts", metavar="DIR", default=".", help="where to look for the display font files")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    panel_image().save(OUT / "EH_UI_Panel.png", optimize=True)
    shadow_image().save(OUT / "EH_UI_Shadow.png", optimize=True)
    sheet, cells = icon_sheet()
    sheet.save(OUT / "EH_UI_Icons.png", optimize=True)
    ICONS_LUAU.write_text(icons_luau(cells))
    print(f"wrote {OUT}/EH_UI_Panel.png, EH_UI_Shadow.png, EH_UI_Icons.png ({len(cells)} icons) and {ICONS_LUAU.relative_to(ROOT)}")
    if args.sheet:
        contact_sheet(sheet, cells, pathlib.Path(args.sheet))
        print(f"contact sheet: {args.sheet}")
    if args.specimen:
        specimen(pathlib.Path(args.specimen), pathlib.Path(args.fonts))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
