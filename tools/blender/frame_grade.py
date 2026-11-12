#!/usr/bin/env python3
"""Grades a rendered frame against the golden-frame numbers (docs/GOLDEN_FRAMES.md, PLAN_STEAM_PLUS 3.1 and 8.2).
No bpy needed: `level_shots.py --golden` calls it on every golden frame, and it runs on its own too:

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
"""
import json
import os
import sys

import numpy as np
from PIL import Image

WARM_MIN = 8
WARM_LUMA = 0.06
GLOW_LUMA = 0.9
TOP_SHARE = 0.01

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


def luma(a):
    return (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]) / 255.0


def grade(path, ids=None):
    a = np.asarray(Image.open(path).convert("RGB"), np.float32)
    y = luma(a)
    warm = ((a[..., 0] - a[..., 2]) >= WARM_MIN) & (y >= WARM_LUMA)
    out = {
        "frame": os.path.basename(path),
        "warm_share": round(float(warm.mean()) * 100, 1),
        "median_luma": round(float(np.median(y)), 3),
        "glow_share": round(float((y >= GLOW_LUMA).mean()) * 100, 1),
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
    return out


def main(argv):
    res = [grade(p) for p in argv if not p.endswith("_ids.png")]
    print(json.dumps(res, indent=1))


if __name__ == "__main__":
    main(sys.argv[1:])
