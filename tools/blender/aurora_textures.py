"""Northern-lights curtain textures for the client Heist/Aurora (PLAN_FIRST_PERSON "SKY", STYLE_BIBLE §16).

    python3 tools/blender/aurora_textures.py [--width 1024] [--height 512] [--preview]

Writes assets/sky/EH_Aurora_{A,B,C}.png (RGBA, upload with `python3 tools/kit_upload.py --sky`, then
`--resolve-sky`) and, with --preview, docs/art/aurora/textures.png (the three tiles over the night sky colour,
each twice side by side, so the horizontal seam can be checked by eye).

The texture lies along a Beam: image x runs from Attachment0 to Attachment1 (the curtain's length, along its
spine), image y across the ribbon's width (the curtain's height; image top = curtain top). Every tile repeats
horizontally (each Beam of a chain shows one tile, TextureMode Stretch, TextureLength 1), and the three variants
share the same columns near both edges, so any variant can follow any other in a chain without a seam.

What is in a tile (all in float, then dithered to 8 bits: no banding in the long fades):
  * the lower hem: a sharp bright edge whose height wanders along x (folds), a pale green-white core on it;
  * fine rays rising from the hem: a few hundred thin Gaussian streaks, each with its own height, width and
    strength, so the curtain thins out upward in rays rather than as a flat gradient;
  * a soft body glow behind the rays (low-frequency, also wandering);
  * colour by height above the hem: green core -> green -> teal -> a violet tip (STYLE_BIBLE §16 hues: green
    h 150-160, teal h <= 185, violet h 300-315 in Oklch, clear of the clone hues' reserved bands);
  * RGB is the colour everywhere (never black where alpha is 0, so bilinear filtering cannot draw a dark fringe);
    alpha carries the intensity (LightEmission 1: the beam adds colour x alpha onto the sky).
"""
import argparse
import os

import numpy as np
from PIL import Image

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(REPO, "assets", "sky")
PREVIEW = os.path.join(REPO, "docs", "art", "aurora", "textures.png")

# Colour stops by height above the hem (share of the tile height), sRGB.
STOPS = (
    (0.00, (150, 255, 188)),   # hem core: pale green (Oklch h 154)
    (0.04, (96, 250, 152)),    # bright green
    (0.22, (54, 238, 136)),    # green body (#36EE88, h 153)
    (0.40, (40, 220, 160)),    # teal (#28DCA0, h 163)
    (0.55, (40, 196, 184)),    # teal (h 182, still clear of Clone Cyan's band)
    (0.68, (120, 130, 220)),   # the turn, where the alpha is already low
    (0.82, (168, 100, 224)),   # violet tip (#A864E0, h 307)
    (1.00, (176, 96, 222)),
)
HEM = 0.16          # mean hem height (share of the tile from the bottom)
EDGE = 0.10         # share of the width at each edge shared by every variant
SKY = (26, 24, 56)  # the zenith night colour behind the preview
VARIANTS = {"A": 11, "B": 23, "C": 37}
BASE_SEED = 5


def periodic_noise(rng, n, terms, lo, hi, amp_falloff=1.0):
    """A smooth function on [0, 1) that wraps: a sum of sines with integer frequencies in [lo, hi]."""
    x = np.arange(n) / n
    out = np.zeros(n)
    for _ in range(terms):
        f = rng.integers(lo, hi + 1)
        a = rng.uniform(0.4, 1.0) / (f ** amp_falloff)
        out += a * np.sin(2 * np.pi * (f * x + rng.uniform()))
    return out / max(1e-6, np.abs(out).max())


def edge_weight(n):
    """1 inside the tile, 0 at both edges (where every variant is the shared base), smooth in between."""
    x = np.arange(n) / n
    d = np.minimum(x, 1 - x) / EDGE
    t = np.clip((d - 0.25) / 0.75, 0, 1)
    return t * t * (3 - 2 * t)


def rays(rng, count, cluster):
    """Ray list: centre x (0-1), width (px), height (share of the tile above the hem), strength. Centres follow
    `cluster` (rays bunch where the curtain folds, with thin gaps between bunches)."""
    w = len(cluster)
    p = cluster / cluster.sum()
    out = []
    for i in rng.choice(w, size=count, p=p):
        out.append((
            (i + rng.uniform()) / w,
            rng.choice((0.7, 1.1, 1.6, 2.4, 3.6, 6.0), p=(0.22, 0.25, 0.22, 0.15, 0.10, 0.06)),
            rng.uniform(0.12, 0.72) ** 1.1 * (0.6 + 0.6 * cluster[i]),
            rng.uniform(0.2, 1.0) ** 1.5,
        ))
    return out


def colour_at(s):
    """s = height above the hem (share of the tile), any shape -> (..., 3) float sRGB 0-255."""
    s = np.clip(s, 0, 1)
    pos = np.array([p for p, _ in STOPS])
    cols = np.array([c for _, c in STOPS], float)
    return np.stack([np.interp(s, pos, cols[:, k]) for k in range(3)], axis=-1)


def tile(w, h, variant_seed):
    base = np.random.default_rng(BASE_SEED)
    var = np.random.default_rng(variant_seed)
    wgt = edge_weight(w)

    # The hem height along x: shared slow folds + the variant's own folds inside the tile.
    hem = HEM + 0.03 * periodic_noise(base, w, 4, 1, 3) + wgt * 0.035 * periodic_noise(var, w, 5, 2, 5, 0.8)
    # Curtain density (folds): high-contrast, so the curtain has bright bunches and dim gaps.
    cb = 0.5 + 0.5 * periodic_noise(base, w, 6, 2, 9, 0.4)
    cv = 0.5 + 0.5 * periodic_noise(var, w, 6, 2, 9, 0.4)
    cl_base = np.clip(cb, 0, 1) ** 1.8 + 0.06
    cl = np.clip((1 - wgt) * cb + wgt * cv, 0, 1) ** 1.8 + 0.06

    v = 1 - (np.arange(h) + 0.5) / h            # 0 at the bottom row, 1 at the top row
    s = v[:, None] - hem[None, :]               # height above the hem, per pixel
    sp = np.maximum(s, 0)

    # Body glow: brightest at the hem, a long tail upward; a fast fall below it.
    body = np.where(s >= 0, np.exp(-sp / 0.24), np.exp(-(s / 0.016) ** 2))
    inten = 0.42 * body * (0.25 + 0.75 * cl[None, :])

    # The hem: a bright edge, strongest in the bunches.
    core = np.exp(-((s - 0.004) / 0.012) ** 2) * (0.25 + 0.75 * cl[None, :])
    inten += 0.38 * core

    # Rays: the shared set (base rng) at both edges crossfading into the variant's own set inside the tile.
    px = np.arange(w)

    def field(ray_list):
        f = np.zeros((h, w))
        for cx, width, height, amp in ray_list:
            dx = (px - cx * w + w / 2) % w - w / 2      # wrapped distance in px
            m = np.abs(dx) < width * 4
            g = np.exp(-(dx[m] / width) ** 2)
            sm = s[:, m]
            # a ray: from the hem (a quick fall below it) up to a soft top at its own height
            prof = np.where(sm >= 0, np.exp(-(np.maximum(sm, 0) / height) ** 1.5), np.exp(-(sm / 0.014) ** 2))
            f[:, m] += amp * g[None, :] * prof
        return f

    ray_field = (1 - wgt)[None, :] * field(rays(base, 460, cl_base)) + wgt[None, :] * field(rays(var, 460, cl))
    ray_field /= max(1e-6, np.percentile(ray_field, 99.5))
    inten += 0.62 * np.clip(ray_field, 0, 1.5)

    # Fine vertical shimmer (thin brighter/darker columns), low amplitude, wraps.
    shimmer = 1 + 0.10 * periodic_noise(var, w, 18, 30, 120, 0.2)[None, :] * wgt[None, :] \
        + 0.06 * periodic_noise(base, w, 10, 30, 120, 0.2)[None, :]
    inten *= shimmer

    # Fade to nothing at the ribbon's two long edges (the beam's width ends must never show).
    top = np.clip((1 - v) / 0.12, 0, 1)
    bottom = np.clip(v / 0.05, 0, 1)
    inten *= (top * top * (3 - 2 * top))[:, None] * (bottom * bottom * (3 - 2 * bottom))[:, None]
    # The violet tips are faint: the alpha falls with height faster than the green body.
    inten *= np.exp(-sp / 0.9)
    inten = np.clip(inten, 0, 1)

    rgb = colour_at(np.clip(s, 0, None))
    alpha = inten ** 0.85 * 255
    return rgb, alpha


def dither(a, rng):
    """Triangular dither of +-1 LSB, then 8 bits: long fades stay smooth instead of stepping."""
    noise = rng.uniform(-0.5, 0.5, a.shape) + rng.uniform(-0.5, 0.5, a.shape)
    return np.clip(np.round(a + noise), 0, 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--width", type=int, default=1024)
    ap.add_argument("--height", type=int, default=512)
    ap.add_argument("--preview", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(99)
    tiles = {}
    for name, seed in VARIANTS.items():
        rgb, alpha = tile(a.width, a.height, seed)
        img = np.dstack([dither(rgb, rng), dither(alpha, rng)])
        path = os.path.join(OUT, f"EH_Aurora_{name}.png")
        Image.fromarray(img, "RGBA").save(path, optimize=True)
        tiles[name] = img
        print(f"wrote {os.path.relpath(path, REPO)} (mean alpha {img[..., 3].mean():.1f})")
    # Seams: the step from any tile's last column to any tile's first is no larger than a typical step between
    # two neighbouring columns inside a tile (thin rays make neighbours differ; a seam must not stand out).
    names = list(tiles)
    inner = np.mean([np.abs(np.diff(t[..., 3].astype(int), axis=1)).mean() for t in tiles.values()])
    for i in range(len(names)):
        for j in range(len(names)):
            a_, b_ = tiles[names[i]], tiles[names[j]]
            step = np.abs(a_[:, -1, 3].astype(int) - b_[:, 0, 3].astype(int)).mean()
            assert step < inner * 1.4, f"seam {names[i]} -> {names[j]}: {step:.2f} (inner {inner:.2f})"
    print(f"seams ok (inner column step {inner:.2f})")
    if a.preview:
        os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
        rows = []
        for name in names:
            t = tiles[name].astype(float)
            pair = np.concatenate([t, t, tiles[names[(names.index(name) + 1) % len(names)]].astype(float)], axis=1)
            al = pair[..., 3:4] / 255
            rows.append(np.array(SKY, float) + pair[..., :3] * al)   # additive, as LightEmission 1
            rows.append(np.full((8, pair.shape[1], 3), 12.0))
        Image.fromarray(np.clip(np.concatenate(rows[:-1], axis=0), 0, 255).astype(np.uint8)).save(PREVIEW)
        print("wrote", os.path.relpath(PREVIEW, REPO))


if __name__ == "__main__":
    main()
