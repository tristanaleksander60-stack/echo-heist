# Icon and thumbnail CONCEPTS (direction only)

**Nothing in this folder is ever uploaded.** Every icon and thumbnail that ships is a **real in-game capture** from the capture setups in `docs/marketing/ICON_THUMBNAILS.md` (§3.3, §4) and `CLIPS.md` §3 (MASTERPLAN §9.4, truth gate G1). These renders only fix the direction before the capture sessions on Fri Nov 27: framing, scale of the hero, where the text goes, and whether the promise reads at 64 px / 160 × 90. Each image carries a small "CONCEPT RENDER, NOT A CAPTURE" tag in its bottom-right corner (the metadata zone) so it can't be uploaded by mistake.

Regenerate (about 8 minutes, one Blender process per image, pip `bpy` 5.3 on Python 3.13):

```
python3 tools/blender/marketing_renders.py                  # everything + review_sheet.png
python3 tools/blender/marketing_renders.py --only T3 --scale 0.5 --samples 8   # a quick draft of one
EH_DRY=1 python3 tools/blender/marketing_renders.py --only T1                  # print head positions, no render
```

PNGs are written with 256 colours + dither to keep git small (`--truecolor` for 24-bit).

## Files and verdicts

| File | Brief | Verdict |
|---|---|---|
| `icon_xmas_concept.png` (1024) + `_64.png` | §3, Dec 3 - Jan 4 | Reads at 64 px: face with Santa hat and red scarf framing it, two cyan copies up-left, gold bag with sparkle on the right, warm dial glow behind the head; passes the greyscale check (face, copies and ground are three separate values) |
| `icon_evergreen_concept.png` (1024) + `_64.png` | §3, from Jan 5 | Same read; the flat cap is weaker than the Santa hat at 64 px (dark cap on a dark door), so the copies' cap silhouettes carry less |
| `T1_8-of-me_concept.png` + `_160x90.png` | T1 "8 OF ME" | Strong at 160 × 90: smug hero + gold bag at the left third, a wall of cyan copies shrinking to the right, text clear; the V reads as a receding crowd rather than a V, and the copies merge into one cyan mass, which is still the promise |
| `T2_betrayed_concept.png` + `_160x90.png` | T2 "BETRAYED!" | Reads: shocked hero right, cyan clone with the bag under the red beacon left, Gus with "!" small between; the "caught in the flashlight" read is carried by the floor cone, not by light on the hero |
| `T3_wrong-one_concept.png` + `_160x90.png` | T3 "WRONG ONE!" | Reads: Gus big at the right third with "?", the glitching cyan clone in his cone at the centre; the real robber sneaking out at the left is the weakest element at 160 × 90 (small and dark) |
| `T4_16-robbers_concept.png` + `_160x90.png` | T4 "16 ROBBERS" | Reads: owner front-left, then 15 robbers in four colour blocks with glyph badges; the bottom third is empty floor and the van is mostly hidden behind the crowd |
| `T5_steal-back-xmas_concept.png` + `_160x90.png` | T5 "STEAL BACK XMAS" | Strongest: hero in Santa hat with the present at the left third, cyan clone with the second present in the doorway, Gus in his Santa hat with his back turned in the back room, garland across the top |
| `review_sheet.png` | §3.2 / §7 size tests | Every image at real size, 3x nearest, 3x greyscale, and mid size with a 1 % blur |

## What is a stand-in (fix in the real capture)

| Element | In the concept | In the capture |
|---|---|---|
| The Rookie | A blocky R15-proportioned stand-in (flat cap, long scarf, smug side-eye), colours checked with `eh_palette` (skin vs Heist Gold Oklab 0.155, scarf vs Alarm Red 0.208, skin / jacket luma 0.64 / 0.48 vs the ground) | The catalog Rookie outfit (CLIPS.md §3.1) and, in December, a catalog Santa hat |
| Friends (T4) | The same stand-in in other jacket colours | Real friends or test accounts, with written permission |
| Clones | The stand-in stripped like `Avatars.luau` (no face, no scarf, hair + hat only), opaque glow in the owner hue + an outline (bench candidate B), the age ramp | The look picked by spike S1 |
| Glyph badges, loot sparkle, "?" / "!" pops | Drawn in 2D after the render | The game's own UI. Badges are drawn only in T4 (the brief asks for them); check whether HUD-off hides them in T1-T3 and T5 |
| Gus's cone and flashlight light, the busted clone's glitch slices and tape ribbons | Approximations | The game's code-drawn effects |
| T2 alarm beacon | **Placeholder**: no alarm beacon exists in `src/` (checked 2026-11-12) | Whatever the alarm run really draws. If it draws no beacon, T2 loses its red shape |
| Heist Night | Eevee: indigo world, warm key, cool rim, then Bloom and ColorCorrection (tint 235,230,255, contrast 0.12, saturation 0.1) applied in 2D | The `default.project.json` Lighting as shipped |
| Text font | Inter Display Black (OFL, installed here); Lilita One is used automatically if it is installed at `/usr/share/fonts/truetype/lilita/` | The wordmark font the owner picks (§2) |
| Kit, Gus, loot, Christmas layer | The exported FBX kit with the location atlas swap (Bank, Toy Shop, Corner Shop), Gus v0 with `Gus_SantaHat` | The same kit after the S2 import |

## Direction notes for the capture sessions

1. **Icon halo (§3.3).** A camera at chin height pitched up puts the dial ring at the hero's neck: from 6 studs in front, with the hero 4.5 studs from the door, the ring centre sits about 8° below the face. The ring frames the head only when the camera is on the face → dial line: about 6.6 studs high from 9 studs in front, looking slightly down. Looking down also lifts the copies standing behind him, so they fan **up**-left on their own, which the brief wants.
2. **Icon copies.** At the brief's 8 % offset the copies hide behind the hero's head and show as slivers at 64 px. Offsets of about 19 % and 36 % of the width (copies 2.4 and 4.6 studs further back) give two readable cyan shapes.
3. **T1 / T4 camera height.** At 4.5-5 studs (about head height) every head lands on the horizon line, under the upper-third text. A higher camera lifts the back rows into the text zone. A low camera on a two-row crowd hides the back row: one arc, grouped by crew, reads best at 160 × 90.
4. **T1 V.** At head height the V of 7 reads as a crowd shrinking toward the back, not as a V. That is fine for the promise ("many of me"). Keep the till bag clear of the nearest copy.
5. **T3 Gus.** For Gus to be big at the right third with his cone on a clone that stands at the same depth, his body faces the clone and his head turns toward the lens. That is a pose the capture can't set: check the real 2.0 s double-take frames for one where his face is visible. Light the safe-room doorway, or the real robber disappears at 160 × 90.
6. **T5 present.** Carried at chest height, the present hides the face. Carry it at belly height.
7. **Ghost White (P4).** At full glow it clips to a white blob with no form. Keep its glow lower than the other hues so the figure still shows.
