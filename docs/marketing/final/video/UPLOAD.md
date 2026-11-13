# The experience-page video: what it is and how to upload it

_2026-11-13. Rendered by `python3 tools/blender/store_video.py --render-all` then `--edit` (the whole pipeline is in that file's docstring). One upload slot of three this month: read §3 before spending it._

## 1. The file

| | |
|---|---|
| File | [`experience_video.mp4`](experience_video.mp4) |
| Length | 27.6 s (662 frames) |
| Picture | 1920 × 1080, 16:9, 24 fps constant, H.264 High, yuv420p, `+faststart` |
| Size | 25.7 MB (25,706,215 bytes; CRF 17, preset slow) |
| Audio | **none** (silent; no audio track) |
| Poster frame | [`poster_1920x1080.png`](poster_1920x1080.png) (the 8 OF ME beat) |
| Contact sheet | [`frames.png`](frames.png) (0, 1, 3, 10, 20, 28 s; dashed lines = the 9:16 centre crop) |

**Specs [UNVERIFIED].** The vault (*Thumbnail Specs, Rules and Upload* §1 and §4; *Game Trailers and Clean Footage*, "Video thumbnails on the experience page") says the Roblox docs page lists **no** maximum length, file size or resolution for video thumbnails ("check the upload dialog for current constraints"). So this file uses the safe default: 1920 × 1080, 16:9, H.264 MP4, constant frame rate, ≤ 30 s, far under 50 MB. If the upload dialog states a different limit, it wins; re-encode with `--edit` after changing `FPS`/the ffmpeg line in `store_video.py`.

**Sound.** Silent on purpose. There is no commissioned music yet (MUSIC_BRIEF.md), the game's SFX are Roblox asset ids, not licensed local files, and the store video must not carry voice or lyrics. A silent video is allowed and reads with the sound off (every beat is a picture, a stamp or a label). When the commissioned track exists, add it (no lyrics) and re-upload as v2.

## 2. What it is (say this plainly)

**This video is rendered in Blender from the game's own models. It is not a capture from a live server or from Studio.** Everything in it is in the game: the kit FBX in `assets/fbx` (the Rookie and his Config.Rookie outfit, Gus in his Santa hat, the loot, the van, the levels rebuilt from KitPlan exactly as the server builds them, the hideout from LobbyPlan, the story town and Hoardsworth Tower from IntroPlan, the Heist City sky and the aurora), and the motion is the game's: every figure walks the path the sim gives it when it plays the level solutions (`tools/blender/video_paths.luau` runs `tests/sim/Solutions` through the same HeistSim the server runs, so the clones are the real echo replays, Gus patrols and turns Suspicious on his real schedule, doors open when the sim opens them). The tape print, the clone look (fill + outline + floor glow + age ramp), the pills, the stamps (RUN n, REWIND, 8 OF ME), CREW VIEW and Gus's "?" are drawn after the game's own HUD.

What differs from the live game: the lighting is Blender Eevee (not Roblox Future) with the game's tone map, Bloom and ColorCorrection redone in 2D; the walk cycle is a procedural swing of the Rookie's R15 joints, not the game's animation assets; the REWIND scrub is a 2D re-creation of RewindDirector; the title card is 2D.

**The policy risk (vault, Roblox docs): "authentic in-game footage only" and "graphics must match what players see".** A render is not footage. The pictures are close to what a player sees and show nothing the game lacks, but a reviewer can still reject it, and a rejection costs one of the 3 uploads this month. The owner decides:

- **Safer:** keep this file as the edit and the shot list, shoot the same beats in Studio (CAPTURE.md: A5 hook, A2 8 OF ME, A8 Crew View, B2 Gus, A3 hideout; `EH_Scenario` stagings), cut them to the same timings, and upload the capture. The owner may replace this video with a Studio capture at any time.
- **Faster:** upload this file now and keep one upload spare for a capture if it is rejected.

## 3. Upload steps (Creator Hub)

Uploads: **3 per month, rejected uploads included.** Check §4 twice before you press Save.

1. Open **create.roblox.com** → **Creations** → pick the experience **Heist Yourself: Rob With Your Clones** (signed in as the account or group that owns it).
2. In the left menu open **Configure** (Configurations) → **Places** → the **start place** (the one with the star).
3. Open the place's **Videos** section (Roblox docs: Configurations, Places, the place, Videos). If your dashboard shows videos under **Thumbnails** instead, use **Add video** there.
4. Upload `docs/marketing/final/video/experience_video.mp4`. Read any limits the dialog shows (length, size, format); if the file breaks one, stop and re-encode (§1).
5. Save. The video goes to moderation; until it is approved, the still thumbnails show. Once approved it is shown **first** on the experience details page and can appear on Home (not on Xbox, PlayStation or VR).
6. On the **Experience Detail Page** thumbnail list, check the order (the video first) and give the stills their alt text (UPLOAD.md in `docs/marketing/final/`).
7. Note the date in PROJECT_STATE and in ICON_THUMBNAILS.md §5 ("Video thumbnail v1"), and the result (approved / rejected, with the reason).

## 4. Pre-upload checklist (vault: *Game Trailers and Clean Footage* "Checklist"; *Thumbnail Specs* §4 allowed / not allowed)

| Rule | This video |
|---|---|
| Hook in the first 3 s | 0.0-2.0 s: your clone tape-prints out of you (RUN 2); 2.0-5.0 s: seven clones print out of you, 8 OF ME at 3.9 s (slightly after the 3 s mark: the sim's clones overlap in the doorway until they fan out) |
| Core verb by 10 s | run (RUN 1, 5.0 s) → rewind (REWIND, 6.6 s) → clones help, rob together (Crew View, RUN 3, from 7.8 s; the hook already shows a clone helping at 1 s) |
| Real gameplay, no UI or interactions the game lacks | All from the game's data; **rendered, not captured** (§2) |
| No real-life footage, no external content, no borrowed IP | None |
| No voice, narration, voice chat, no music with lyrics | Silent |
| Text sparing, describes gameplay only, no claims or promotions | Only in-game text: RUN 1/2/3, REWIND, 8 OF ME, CREW VIEW, the numbered pills, "?"; the end card is the game's name and subtitle (logo / branding is allowed). No "free", no "best", no date, no call to action |
| Graphics not beyond what players see | Eevee lighting with the game's grade; no depth of field, colour gels or glows the game lacks (unlike the store key art) |
| No usernames or player names | None (no nameplates, no chat) |
| Bottom edge clear | Stamps and the wordmark sit in the upper half |

### Self-score on the vault's trailer checklist (honest)

| Checklist item (vault, *Game Trailers and Clean Footage*) | Result |
|---|---|
| Edit permission for live-server filming | n/a (nothing filmed) |
| Freecam, Player Lock, nameplates hidden | n/a; no names or chat on screen |
| Hook in the first 3 s, core verb by 10 s | pass (print at 0.2 s, REWIND at 6.6 s, Crew View from 7.8 s) |
| Authentic footage, no voice, no lyrics, no claims, minimal text | **fail on "authentic footage"** (a render); the rest pass |
| Honesty pass at mid graphics settings | partial: no Roblox mid-settings pass possible; Eevee lighting is close to, not equal to, Future |
| Master exported; 16:9 and 9:16 derivatives | 16:9 master done; no 9:16 cut (the wordmark and the 8 OF ME stamp are wider than the 9:16 centre third) |

Quality pass (frames at 0, 1, 3, 10, 20, 28 s; [`frames.png`](frames.png)): every frame reads at 360 px wide except the Crew View shot, which was the weakest point (pills and the CREW VIEW label ~6 px tall at phone size, the figures tiny at 40 studs). **Fixed once:** the Crew View camera moved in (40 → 34 studs) and the pills and label were drawn 1.5x larger, and the shot was re-rendered. Still weak there: while you are at the safe, the two plate clones drop below the frame edge for about a second.

## 5. Shot list (as rendered)

| Time (s) | Shot | What you see | On-screen text (all in-game) |
|---|---|---|---|
| 0.0-2.0 | hook | L1 Back Room, run 2, first person (your gloves, the reticle): your run-1 clone tape-prints out of you (feet first, the scan band; the first 0.9 s at 0.6x) and runs to plate A; door A pockets | RUN 2 |
| 2.0-5.0 | eight | L5 Clone Party, run 8, from inside the shop: seven clones print out of you in the doorway (0.35x through the print) and pour into the aisles; the world dims 15 %, numbered pills | 8 OF ME, pills 1-8 |
| 5.0-6.6 | run1 | L2 Two Doors, run 1, raised camera: you walk onto plate A, door A opens | RUN 1 |
| 6.6-7.8 | rewind | The same run reels backwards (flash, desaturated cyan scrub, scanlines, tracking line), snap back | REWIND, RUN 2 |
| 7.8-12.4 | crew | L2 run 3 in Crew View: both clones print and hold plates A and B, both doors open, you take the safe's cash bag and carry it back | RUN 3, CREW VIEW, pills 1-3 |
| 12.4-15.4 | gus | L4 Night Clerk, run 3: you leave the safe room with the night deposit while Gus patrols with his torch cone; he turns Suspicious | ? |
| 15.4-17.8 | town | The story town under the aurora, snow falling, the camera cranes up to Hoardsworth Tower and its vacuum | none |
| 17.8-20.0 | hideout | The hideout in first person: a slow turn from the job board (NEXT JOB) to your van | (the board's own NEXT JOB card) |
| 20.0-23.6 | party | L5 Clone Party, run 8: you and seven clones hauling presents across the shop floor | none |
| 23.6-27.6 | title | The Rookie and three clones in the snow under the aurora; the wordmark drops in at 24.1 s | HEIST YOURSELF, ROB WITH YOUR CLONES |

## 6. Rebuild

```
lune run tools/blender/video_paths.luau 1   # (automatic) the sim paths, cached in build/video/
python3 tools/blender/store_video.py --list
python3 tools/blender/store_video.py --render-all --scale 0.6667 --chunk 10   # ~2-3 h on 4 CPU cores
python3 tools/blender/store_video.py --edit
```

Frames render at 1280 × 720 (Eevee, 3 samples, sun shadows only: the budget on a CPU-only box, 7-28 s a frame on 4 CPU cores: the hook shots at 3 samples with the haze pass, the rest at 2 samples without it; `SAMPLES` / `HAZED` in the script) and are upscaled to 1080p before the 2D layer, so stamps and text are sharp at 1080p. One Blender process renders at most `--chunk` frames (bpy segfaults after 10-20 Eevee renders in one process here); a crashed chunk is re-run and skips the frames on disk.
