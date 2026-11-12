"""Plain night sky cubemap for lighting recipe A (docs/research/roblox_quality.md §1.2; PLAN_STEAM_PLUS §4.1 W1).

    python3 tools/blender/sky_faces.py [--size 512]

Writes assets/sky/EH_SkyNight_{Bk,Dn,Ft,Lf,Rt,Up}.png: a seamless indigo gradient by true elevation (horizon in the
Atmosphere colour (90,80,150), so the haze and the sky meet without a band; deep indigo at the zenith), sparse
faint stars above 12 degrees and a dark ground below the horizon. Recipe A keeps a ClockTime 15 sun as the key
light, so without these faces Roblox draws its default DAY sky: upload the six PNGs (Creator Hub or Open Cloud
as Decals, then use their image ids) and paste them as SkyboxBk/Dn/Ft/Lf/Rt/Up into the Sky node of
default.project.json (and bench / spikes). The Heist City cubemap with Hoardsworth's tower replaces this in
phase 2 (W4). No bpy needed (PIL + numpy).
"""
import argparse
import os

import numpy as np
from PIL import Image

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(REPO, "assets", "sky")

HORIZON = np.array((90, 80, 150), float)   # Atmosphere.Color (recipe A)
ZENITH = np.array((26, 24, 56), float)
GROUND = np.array((30, 27, 52), float)
STARS = 900
SEED = 7

# Face -> (forward, right, up) in Roblox axes (+Y up). Roblox's Ft looks toward -Z, Bk toward +Z, Rt +X, Lf -X.
FACES = {
    "Ft": ((0, 0, -1), (1, 0, 0), (0, 1, 0)),
    "Bk": ((0, 0, 1), (-1, 0, 0), (0, 1, 0)),
    "Rt": ((1, 0, 0), (0, 0, 1), (0, 1, 0)),
    "Lf": ((-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    "Up": ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
    "Dn": ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
}


def colour(elev):
    """elev in radians -> RGB (0-255)."""
    up = np.clip(elev / np.radians(70), 0, 1)[..., None] ** 0.6
    sky = HORIZON * (1 - up) + ZENITH * up
    down = np.clip(-elev / np.radians(8), 0, 1)[..., None]
    return sky * (1 - down) + GROUND * down


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=512)
    n = ap.parse_args().size
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(SEED)
    sd = rng.normal(size=(STARS, 3))
    sd /= np.linalg.norm(sd, axis=1, keepdims=True)
    sd = sd[np.degrees(np.arcsin(sd[:, 1])) > 12]
    sb = rng.uniform(0.25, 0.7, size=len(sd))
    t = (np.arange(n) + 0.5) / n * 2 - 1
    u, v = np.meshgrid(t, -t)   # image rows go down
    for name, (f, r, up) in FACES.items():
        f, r, up = np.array(f, float), np.array(r, float), np.array(up, float)
        d = f[None, None, :] + u[..., None] * r + v[..., None] * up
        d /= np.linalg.norm(d, axis=2, keepdims=True)
        img = colour(np.arcsin(np.clip(d[..., 1], -1, 1)))
        # stars that land on this face
        dots = sd @ f
        ok = dots > 1e-6
        for s, b in zip(sd[ok], sb[ok]):
            p = s / (s @ f)
            px = int((p @ r + 1) / 2 * n)
            py = int((1 - (p @ up)) / 2 * n)
            if 0 <= px < n and 0 <= py < n:
                img[py, px] = img[py, px] * (1 - b) + np.array((235, 235, 255)) * b
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, f"EH_SkyNight_{name}.png"),
                                                                     optimize=True)
        print("wrote", os.path.join("assets", "sky", f"EH_SkyNight_{name}.png"))


if __name__ == "__main__":
    main()
