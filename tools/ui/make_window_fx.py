#!/usr/bin/env python3
"""Town window grid texture (BIG buildings, PLAN_FIRST_PERSON 5; Config.Backdrop.TOWN.SKIN).

Writes, deterministically:
  assets/ui/EH_FX_Windows.png   256 x 512 RGBA: 4 window bays x 4 storeys (one bay = WINDOW.colPitch 4.5 studs,
                                one storey = TOWN.STOREY 9 studs, so the tile is 18 x 36 studs). Transparent wall
                                (the building's body colour shows through), cream surrounds and sills, a white mullion
                                cross, blue-night panes; about a quarter of the flats are warm (lamplight behind
                                burgundy curtains). The client (Heist/Backdrop) puts it as a Texture on each building
                                face's "Skin" part; a few Neon panes sit exactly on its cells for the brightest lights.

  python3 tools/ui/make_window_fx.py
Upload with the UI kit: python3 tools/kit_upload.py --ui (a Decal; the server resolves the image at boot, Heist/UiImages,
and publishes EH_UiImage_EH_FX_Windows; until then the faces show plain walls with their Neon panes).
WIN_W, WIN_H, WIN_TOP must match Config.Backdrop.TOWN.WINDOW.w / h and SKIN.winTop.
"""
import pathlib
import random

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets/ui/EH_FX_Windows.png"
COLS, ROWS = 4, 4
BAY, STOREY = 4.5, 9.0                 # studs
CW, CH = 64, 128                       # px per cell
WIN_W, WIN_H, WIN_TOP = 2.4, 4.6, 0.2  # studs; WIN_TOP = the window's top under the storey's top (share)

TRIM = (226, 214, 190, 255)
TRIM_LO = (176, 160, 136, 255)
GLASS = (64, 74, 124, 255)
GLASS_HI = (92, 104, 156, 255)
WARM = (236, 178, 128, 255)
WARM_HI = (250, 214, 168, 255)
CURTAIN = (140, 47, 75, 255)
CURTAIN_HI = (173, 83, 106, 255)
WARM_SHARE = 0.27


def main() -> None:
    rnd = random.Random(20261113)
    sx, sy = CW / BAY, CH / STOREY
    img = Image.new("RGBA", (COLS * CW, ROWS * CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ww, wh = round(WIN_W * sx), round(WIN_H * sy)
    for r in range(ROWS):
        for c in range(COLS):
            x0 = c * CW + (CW - ww) // 2
            y0 = r * CH + round(WIN_TOP * CH)
            x1, y1 = x0 + ww, y0 + wh
            # surround, lintel and sill
            d.rectangle((x0 - 4, y0 - 4, x1 + 3, y1 + 3), fill=TRIM)
            d.rectangle((x0 - 6, y0 - 9, x1 + 5, y0 - 4), fill=TRIM_LO)
            d.rectangle((x0 - 7, y1 + 3, x1 + 6, y1 + 8), fill=TRIM)
            warm = rnd.random() < WARM_SHARE
            if warm:
                d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=WARM)
                d.rectangle((x0 + 4, y0 + 4, x1 - 5, y0 + wh // 3), fill=WARM_HI)
                cw = ww // 5
                d.rectangle((x0, y0, x0 + cw, y1 - 1), fill=CURTAIN)
                d.rectangle((x1 - 1 - cw, y0, x1 - 1, y1 - 1), fill=CURTAIN)
                d.rectangle((x0 + cw // 2, y0, x0 + cw // 2 + 2, y1 - 1), fill=CURTAIN_HI)
                d.rectangle((x1 - 1 - cw // 2, y0, x1 + 1 - cw // 2, y1 - 1), fill=CURTAIN_HI)
            else:
                d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=GLASS)
                d.polygon([(x0, y0), (x0 + ww // 2, y0), (x0, y0 + wh // 2)], fill=GLASS_HI)
            # the mullion cross
            mx = (x0 + x1) // 2
            d.rectangle((mx - 1, y0, mx + 1, y1 - 1), fill=TRIM)
            ty = y0 + round(wh * 0.38)
            d.rectangle((x0, ty - 1, x1 - 1, ty + 1), fill=TRIM)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({img.width} x {img.height}, {COLS} x {ROWS} bays)")


if __name__ == "__main__":
    main()
