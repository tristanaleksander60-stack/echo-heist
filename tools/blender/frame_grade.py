#!/usr/bin/env python3
"""Grades a rendered frame against the golden-frame numbers (docs/GOLDEN_FRAMES.md, PLAN_STEAM_PLUS 3.1 and 8.2).
No bpy needed: `level_shots.py --golden` / `--world2` call it on every frame, and it runs on its own too:

    python3 tools/blender/frame_grade.py docs/audit/levels/golden/G1a_diorama.png [more.png ...]

What it measures (sRGB 8-bit pixels of the finished frame, after bloom, haze and vignette):
  * warm share: pixels with R - B >= WARM_MIN (8 levels) and luma >= WARM_LUMA (0.06, not black). Cool night
    surfaces under the indigo ambient have B > R; amber, pink, gold, brick and wood under warm light have R > B.
    This is the measure the world track used for LEVELS.md section 7 (it gives 3.6 / 2.5 / 2.6 % on those frames,
    reported there as "3-4 %").
  * median luma (Rec. 709 on sRGB values) and the glow share (luma >= GLOW_LUMA, 0.9: what bloom turns to glow).
  * with an ID mask (<frame>_ids.png from the Workbench pass in level_shots.py: one flat colour per element group,
    occlusion included): each group's share of the frame, its 95th-percentile luma, and which group owns the
    brightest 1 % of the frame. "The van must not be the brightest thing" = the van group's p95 is under the focal
    groups' (cash, plate) and it owns little of the brightest 1 %.
  * WORLD 2.0 (docs/audit/LEVELS.md section 10): the near-black share (luma < NEAR_BLACK, 5 %) and the dark share
    (< 10 %). With a source mask (<frame>_src.png from level_shots.src_mask: one flat colour per world layer, the sky
    transparent): each source's share of the frame, its median luma and how much of the frame is near-black there
    (where the black comes from). Signal pop (premium A1): the median HSV value of the plates / the clones against
    the band of pixels just around them; >= SIGNAL_POP (0.15) passes.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

WARM_MIN = 8
WARM_LUMA = 0.06
GLOW_LUMA = 0.9
TOP_SHARE = 0.01
NEAR_BLACK = 0.05
DARK = 0.10
SURROUND_PX = 0.02       # the surround band of a signal, as a share of the frame height
SIGNAL_POP = 0.15        # premium A1: value contrast of a signal against its surround

# ID colours of the mask pass (level_shots.ID_GROUPS uses the same table). Channels are 0 or 255 only, so the
# view transform cannot shift them.
ID_COLOURS = {
    "van": (255, 0, 0),
    "zone": (255, 255, 255),
    "cash": (0, 255, 0),
    "plate": (0, 0, 255),
    "lamp": (255, 0, 255),
    "board": (0, 255, 255),
    "rug": (255, 255, 0),
}

# Source mask colours (level_shots.src_mask): the layer of the world a pixel belongs to; transparent = the sky.
SRC_COLOURS = {
    "ground": (255, 0, 0),       # the ground plane, the town's streets, pavements and yards outside the lot
    "building": (0, 255, 0),     # facades, houses, roofs, windows round the lot
    "ring": (0, 0, 255),         # the skyline rings
    "level": (255, 255, 255),    # everything the server builds (the lot, the shop, the van, Gus)
    "lot": (255, 255, 0),        # the client's snow over the lot's outdoor floor
    "props": (255, 0, 255),      # lamps, cars, trees, snowmen in the surroundings
    "clone": (0, 255, 255),      # the clones (signals)
    "signal": (0, 0, 0),         # the world signals: plate rings, laser beams and lenses, need-all row lamps (opaque black)
}


def luma(a):
    return (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]) / 255.0


def _pop(a, mask, h, other=None):
    """Median HSV value of the masked pixels minus the median of the band around them (None when too small). `other`:
    pixels of other signals, left out of the band (a ring's surround is the world, not the clone standing on it)."""
    if mask.sum() < 12:
        return None
    r = max(3, int(h * SURROUND_PX))
    grown = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(r * 2 + 1))
    band = (np.asarray(grown) > 0) & ~mask
    if other is not None:
        band &= ~other
    if band.sum() < 12:
        return None
    v = a.max(axis=-1) / 255.0
    return round(float(np.median(v[mask]) - np.median(v[band])), 3)


def grade(path, ids=None, src=None):
    a = np.asarray(Image.open(path).convert("RGB"), np.float32)
    y = luma(a)
    warm = ((a[..., 0] - a[..., 2]) >= WARM_MIN) & (y >= WARM_LUMA)
    out = {
        "frame": os.path.basename(path),
        "warm_share": round(float(warm.mean()) * 100, 1),
        "median_luma": round(float(np.median(y)), 3),
        "glow_share": round(float((y >= GLOW_LUMA).mean()) * 100, 1),
        "near_black": round(float((y < NEAR_BLACK).mean()) * 100, 2),
        "dark_share": round(float((y < DARK).mean()) * 100, 1),
        # BIG (LEVELS.md 12): value contrast (the spread of luma, p90 - p10, and its RMS) and the pink cast: the mean
        # of min(R, B) - G over the mid tones (> 0 where red AND blue both sit over green: pink / lavender, the
        # washed-out complaint; warm brick, red and orange, and plain blue score <= 0)
        "value_spread": round(float(np.percentile(y, 90) - np.percentile(y, 10)), 3),
        "rms_contrast": round(float(y.std()), 3),
        "pink_cast": round(float(np.mean((np.minimum(a[..., 0], a[..., 2]) - a[..., 1])[(y > 0.2) & (y < 0.8)])
                                 / 255.0) if ((y > 0.2) & (y < 0.8)).any() else 0.0, 3),
    }
    if ids is None:
        guess = os.path.splitext(path)[0] + "_ids.png"
        ids = guess if os.path.isfile(guess) else None
    if ids and os.path.isfile(ids):
        m = np.asarray(Image.open(ids).convert("RGB").resize((a.shape[1], a.shape[0]), Image.NEAREST), np.int32)
        cut = np.quantile(y, 1 - TOP_SHARE)
        top = y >= cut
        groups = {}
        owned = {}
        for name, col in ID_COLOURS.items():
            mask = np.all(np.abs(m - np.array(col)) < 40, axis=-1)
            if not mask.any():
                continue
            groups[name] = {"share": round(float(mask.mean()) * 100, 2),
                            "p95_luma": round(float(np.quantile(y[mask], 0.95)), 3),
                            "warm": round(float(warm[mask].mean()) * 100, 1)}
            owned[name] = round(float((top & mask).sum()) / max(1, int(top.sum())) * 100, 1)
        owned["other"] = round(100 - sum(owned.values()), 1)
        out["groups"] = groups
        out["brightest_1pct_owner"] = owned
        best = max(groups.items(), key=lambda kv: kv[1]["p95_luma"]) if groups else None
        out["brightest_group"] = best[0] if best else None
        pm = np.all(np.abs(m - np.array(ID_COLOURS["plate"])) < 40, axis=-1)
        if pm.any():
            out["plate_pop"] = _pop(a, pm, a.shape[0])
    if src is None:
        guess = os.path.splitext(path)[0] + "_src.png"
        src = guess if os.path.isfile(guess) else None
    if src and os.path.isfile(src):
        sm = np.asarray(Image.open(src).convert("RGBA").resize((a.shape[1], a.shape[0]), Image.NEAREST), np.int32)
        sky = sm[..., 3] < 128
        masks = {"sky": sky}
        for name, col in SRC_COLOURS.items():
            masks[name] = np.all(np.abs(sm[..., :3] - np.array(col)) < 40, axis=-1) & ~sky
        nb, dk = y < NEAR_BLACK, y < DARK
        table = {}
        for name, mask in masks.items():
            if not mask.any():
                continue
            table[name] = {"share": round(float(mask.mean()) * 100, 1),
                           "median_luma": round(float(np.median(y[mask])), 3),
                           "p95_luma": round(float(np.quantile(y[mask], 0.95)), 3),
                           "near_black": round(float((nb & mask).mean()) * 100, 2),
                           "dark": round(float((dk & mask).mean()) * 100, 1)}
        out["sources"] = table
        if masks["clone"].any():
            out["clone_pop"] = _pop(a, masks["clone"], a.shape[0], masks["signal"])
        if masks["signal"].any():
            out["signal_pop"] = _pop(a, masks["signal"], a.shape[0], masks["clone"])
    return out


def main(argv):
    res = [grade(p) for p in argv if not p.endswith(("_ids.png", "_src.png"))]
    print(json.dumps(res, indent=1))


if __name__ == "__main__":
    main(sys.argv[1:])
