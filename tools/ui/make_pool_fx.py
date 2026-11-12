#!/usr/bin/env python3
"""Soft light-pool texture (levels and world feedback track; LEVELS.md §8 "the pools read as flat stamped discs").

Writes, deterministically:
  assets/ui/EH_FX_Pool.png   256 x 256 RGBA radial falloff: white, alpha = (1 - u^2)^EXPONENT with u = r / 128
                             (0 at the edge, so no hard rim), dithered with a fixed ordered pattern so 8-bit
                             alpha shows no banding on a 20-stud pool. The server's floor pools (Heist/LevelBuilder)
                             draw it as one ImageLabel tinted with the pool colour; ImageTransparency = 1 - peak.

  python3 tools/ui/make_pool_fx.py
Upload with the UI kit: python3 tools/kit_upload.py --ui (a Decal; the engine resolves its image id at boot,
server Heist/UiImages; until then the pools draw Config.Lighting.POOL_SOFT.rings soft discs on the same curve).
EXPONENT must match Config.Lighting.POOL_SOFT.exponent.
"""
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "assets/ui/EH_FX_Pool.png"
SIZE = 256
EXPONENT = 1.5

# 4 x 4 Bayer matrix, in [0, 1)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float64) / 16.0


def main() -> None:
    c = (SIZE - 1) / 2.0
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    u = np.sqrt((x - c) ** 2 + (y - c) ** 2) / (SIZE / 2.0)
    a = np.clip(1.0 - u * u, 0.0, 1.0) ** EXPONENT
    dither = np.tile(BAYER, (SIZE // 4, SIZE // 4))
    alpha = np.floor(a * 255.0 + dither).clip(0, 255).astype(np.uint8)
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    rgba[..., 0:3] = 255
    rgba[..., 3] = alpha
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({SIZE} x {SIZE}, exponent {EXPONENT})")


if __name__ == "__main__":
    main()
