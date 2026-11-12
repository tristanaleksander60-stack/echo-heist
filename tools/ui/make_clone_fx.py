#!/usr/bin/env python3
"""Clone VFX texture (PLAN_STEAM_PLUS §4.4 A2, FEEDBACK_TABLE "Busted (clone)", roblox_quality §5.1).

Writes, deterministically:
  assets/ui/EH_FX_Ribbon.png   256 x 256 particle flipbook, 2 x 2 cells of 128 px: four curls of cassette
                               tape ribbon (white body, a darker edge line and a light glint, so the
                               emitter's Color tints them: Tape Grey to the clone hue). Drawn at 4x and
                               downsampled with LANCZOS. Heist/EchoView's busted burst uses it with
                               FlipbookLayout Grid2x2, FlipbookStartRandom.

  python3 tools/ui/make_clone_fx.py
Upload with the UI kit: python3 tools/kit_upload.py --ui (a Decal; the engine resolves its image id at boot,
server Heist/UiImages; until then the burst uses a built-in sparkle texture).
"""
import math
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets/ui/EH_FX_Ribbon.png"
CELL = 128
SS = 4

# Each curl: (turns of the S-curve, amplitude as a share of the cell, ribbon width as a share, tilt degrees)
CURLS = [
    (1.0, 0.22, 0.13, 20),
    (1.6, 0.18, 0.11, -35),
    (0.7, 0.28, 0.14, 60),
    (2.2, 0.14, 0.10, -5),
]


def ribbon(turns: float, amp: float, width: float, tilt: float) -> Image.Image:
    size = CELL * SS
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    half = size / 2
    length = size * 0.68
    w = size * width
    steps = 160
    a = math.radians(tilt)
    ca, sa = math.cos(a), math.sin(a)

    def point(u: float, off: float) -> tuple:
        # centre line: an S-curve along x; `off` moves across the ribbon (its normal)
        x = (u - 0.5) * length
        y = math.sin(u * turns * 2 * math.pi) * amp * size
        dy = math.cos(u * turns * 2 * math.pi) * amp * size * turns * 2 * math.pi / length
        nx, ny = -dy, 1.0
        n = math.hypot(nx, ny)
        # the ribbon twists: its visible width breathes along the curl
        twist = 0.55 + 0.45 * abs(math.cos(u * turns * math.pi))
        px, py = x + nx / n * off * twist, y + ny / n * off * twist
        return (half + px * ca - py * sa, half + px * sa + py * ca)

    top = [point(i / steps, -w / 2) for i in range(steps + 1)]
    bottom = [point(i / steps, w / 2) for i in range(steps + 1)]
    draw.polygon(top + bottom[::-1], fill=(236, 238, 245, 255))
    # dark edge lines (ink at the tint's darker end) and a light glint down the middle
    draw.line(top, fill=(120, 124, 140, 255), width=int(SS * 2.2))
    draw.line(bottom, fill=(120, 124, 140, 255), width=int(SS * 2.2))
    glint = [point(i / steps, -w * 0.12) for i in range(int(steps * 0.15), int(steps * 0.85))]
    draw.line(glint, fill=(255, 255, 255, 255), width=int(SS * 1.6))
    return img.resize((CELL, CELL), Image.LANCZOS)


def main() -> None:
    sheet = Image.new("RGBA", (CELL * 2, CELL * 2), (0, 0, 0, 0))
    for i, curl in enumerate(CURLS):
        sheet.paste(ribbon(*curl), ((i % 2) * CELL, (i // 2) * CELL))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("wrote", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
