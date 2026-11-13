# CAPTURE: what the owner records, in what order (first-person build)

_Marketing kit. Written 2026-11-13 for the first-person pivot. One checklist for every capture the launch needs: the store page (icon, thumbnails, video thumbnail), the 30 s trailer (TRAILER.md) and the first 8 TikToks (CLIPS.md §6, Nov 19-24). The Blender candidates in `docs/marketing/thumbs/` and `trailer/` show the target frame of each item; the real image is always the capture. Studio staging uses `EH_Scenario` (docs/GOLDEN_FRAMES.md "Capture"; Studio only, a live server ignores it)._

Tick each box. Drop every file in the **Shots inbox** (GitHub issue #1) the same day; Claude grades and crops.

---

## 0. Once (30 min, before session 1)

- [ ] **Build:** `rojo build -o build/EchoHeist.rbxlx` from the latest main; open it in Studio. Nothing to change in Config (the sim path is the default since v35).
- [ ] **Progress that sticks:** Studio API access on the **test** experience (docs/DATA.md), play L1 once; after that every Play starts in the hideout with the levels on the job board.
- [ ] **Your character is the Rookie** (the game builds it; your Roblox avatar never shows). Wear the **default outfit** for every brand shot: Flat Cap, Long Scarf, Breton Stripes, Knit Gloves (hideout → wardrobe → reset any test picks). Crew colour = seat 1 (cyan) when you play alone.
- [ ] **Studio window:** Test tab → Device emulator → custom device **1920 × 1080** (landscape). Studio Settings → Rendering → **Quality Level 21**.
- [ ] **OBS:** canvas 1920 × 1080, **60 fps**, Window Capture of the Studio viewport, MKV, CQP 18, game audio on its own track; remux to MP4 after. Scene "Tall" (1080 × 1920) not needed: we crop 9:16 from the centre third.
- [ ] **The two commands** (client command bar, Play mode, context = Client). Hide Roblox's own UI: `game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)`. Hide our HUD (the reticle, prompts, pills, SKIP): `for _, g in game.Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui") then g.Enabled = false end end` (`true` brings it back). **The first-person hands are not HUD**: they stay, which is what we want in first-person shots.
- [ ] **Third-person shots:** in-game **Settings → Camera → CLASSIC** before the run (first person is the default). Freecam (Left Shift + P) only works while you stand still; **check once** that the freecam is not fought by the game's camera in CLASSIC (if it is, use the cameraman client below) **[UNVERIFIED]**.
- [ ] **Cameraman client (for stills where the live you moves):** Test tab → Clients and Servers → **2 players**. Player 1 plays. Player 2 sits in player 1's van as crew (CREW at the side door, SIT, READY: it joins the heist), switches to CLASSIC, stands in the van all heist and uses the freecam as the camera. Record player 2's window. Name pills: hide the HUD on player 2 only.
- [ ] **Phone:** Roblox app → Settings → **Graphics Quality manual, max**; Do Not Disturb on; battery saver off; brightness max; screen recording in the control centre (iOS) / the screen recorder (Android), **landscape**, mic off.

---

## 1. Session A, Studio (Wed Nov 18, ~50 min): golden frames, the intro, the first-person hook

Feeds: the golden-frame sign-off, trailer shots 1-7 and 11, TikToks #1, #2 and #4, the thumbnail **TH5 "THAT'S ME?!"**.

| # | Set (Workspace attribute `EH_Scenario`) | Do | Record | For |
|---|---|---|---|---|
| A1 | `G1` | Play; don't touch the mouse; screenshot (HUD on) | PNG + 3 s video | Golden G1 sign-off |
| A2 | `G2` | Play; let the tape print and the **8 OF ME** stamp land (first 3 s) | Video, HUD on | Golden G2, trailer 11, TikTok backup |
| A3 | `G3` | Play; screenshot the job board and van; then walk to your van → **PICK VAN** → cab → **SOLO · GO**; hands off the keys during the drive | Video from GO to the van-door wipe | Golden G3, **trailer 8 (the drive)** |
| A4 | `INTRO` | Play; don't press anything (any key skips) | The whole 33.7 s, HUD on (the captions are in-game), then again with our HUD hidden (no SKIP button) | **Trailer 2-7 and 14** |
| A5 | *(clear the attribute)* L1 Back Room | Run 1: look at the cash, GRAB, back to the van, **REWIND at ~0:18**. Run 2: **don't move** for 3 s (the clone tape-prints out of you and walks in) | Video, HUD on, first person | **Trailer 1**, **TikTok #1** (devlog 1) |
| A6 | L1, same heist | Run 3 (the clone of run 1 is still yours): walk back 6 studs toward the van, turn round, wait; at ~0:15 your clone walks out of the door with the cash toward you | Screenshot at the moment its face fills the door; HUD on (its pill "1") | **TH5 "THAT'S ME?!"** (`thumbs/TH5_thats-me.png`) |
| A7 | L2 Two Doors | CLIPS.md F2-A: run 1 the traitor (plate A until 0:10.0, tip jar, REWIND 0:18); run 2 the victim **in first person**: run at the back-room door, it shuts in your face at ~0:10.95 | Video, HUD on, 3 takes (Undo between) | **TikTok #2** (MY CLONE BETRAYED ME) |
| A8 | L2, a new heist | Run 1 plate A, REWIND 0:18; run 2 plate B, REWIND 0:18; run 3 walk to the safe and **hold Q from 0:04 for 2 s**, release | Video, HUD on | **Trailer 9 (Crew View)**, **TikTok #4** (devlog 2) |

## 2. Session B, Studio (Fri Nov 20, ~45 min): Gus, the zap, run 1 vs run 4

Feeds: TikToks #3, #5, #6, #8, the thumbnail **TH2 "WRONG ONE!"**, trailer 10, the pitch clip.

| # | Level | Do | Record | For |
|---|---|---|---|---|
| B1 | L4 Night Clerk | CLIPS.md §4.4 runs 1-3 exactly (plate A, plate B under the coat rack, the decoy at 0:15.3) | — | set-up |
| B2 | L4 takes 1-2 (runs 4-5) | **First person:** cross at 0:06.6, grab the deposit, wait inside the safe-room door (x 1.5, z -39) **looking at Gus**: at ~0:18.6 he busts your clone, "?" | Video, HUD on | **TikTok #3**, **trailer 10**, pitch clip |
| B3 | L4 take 3 (run 6) | **Cameraman client** (player 2 in CLASSIC, freecam low in the back room's south-west, about x -10, z -32, height 3, looking at x 8, z -25, FOV 50; the Blender `TH2` frame). Player 1 tiptoes past behind the frozen Gus with the bag | Player 2's video at 60 fps; pick the frame with Gus's "?" and your face | **TH2 "WRONG ONE!"** (`thumbs/TH2_wrong-one.png`), TikTok #8 (F4 v2) |
| B4 | L2 Two Doors | CLIPS.md F1 (RUN 1 vs RUN 4), the cameraman client at `CAM_F1` | Video | **TikTok #5** |
| B5 | L3 Lights Out | CLIPS.md F3 (the zap x3), freecam at `CAM_F3` (you stand still) | Video | **TikTok #6** |

TikTok #7 (Mon Nov 23) is a re-cut: no capture.

## 3. Session C, Studio (Fri Nov 27, ~60 min): Clone Party, the crew thumbnails

Feeds: **TH1 "8 OF ME"**, the T1/T2 stills, trailer 11 (a better take), CLIPS formats 1, 2-B, 5.

| # | Level | Do | Record | For |
|---|---|---|---|---|
| C1 | L5 Clone Party, own heist | CLIPS.md F5 runs 1-8 (each run a different aisle, REWIND 0:18) through Dawn into the **Crew Line-up** | Cameraman client at `CAM_F5B` (low on the street, z ~38, looking back at the crew, FOV 50) | **TH1 "8 OF ME"** (the Blender `TH1` is the target: you in front, the crew fanning back) |
| C2 | L5, F1 and F2-B as written in CLIPS.md | — | as CLIPS.md §7 C3 | formats 1, 2-B |

## 4. Session D, Studio, 4 clients (by Sun Nov 29; else the friend session Dec 4-5)

- [ ] Test tab → Clients and Servers → **4 players**. Player 1 PICKs a van, players 2-4 SIT as crew, READY, GO.
- [ ] Each client picks a **different outfit** at the wardrobe first (the Blender `TH4`: Flat/Long, Bobble/Chunky, Beanie/Knot, Trapper/Bandana); the crew colours come from the seats.
- [ ] Clone Party: 3 runs each, then the final run → the Line-up of **16** (4 × (1 + 3)).
- [ ] Record: the Line-up from the street (`CAM_F5B`) with a 5th client as the cameraman if Studio allows 5, else player 4 stands at the end of the line and records in CLASSIC. **Hide name pills on every client.**
- For: **TH4 "16 ROBBERS"**, trailer 12, format 7.

## 5. Session E, Studio (Tue Dec 1, Christmas dressing on)

- [ ] ICON_THUMBNAILS.md **T5** setup (the present-loot daily vault, DV04): the hero carries the Present out through the doorway, clone 2 behind. Cameraman client at `CAM_T5`. For: **T5 / TH3 "STEAL BACK XMAS"** (capture version), trailer 13.
- [ ] Repeat A2, B2 and C1 with the dressing (Gus in his Santa hat) for the seasonal cuts.

## 6. Phone session (15 min, any day after session A)

- [ ] **New-player first minute:** a fresh test account on the phone: join → intro (don't skip) → L1 until the first REWIND. Screen-record. For: the devlog "what a new player sees", the kid-test baseline, the 9:16 crop check of the intro captions.
- [ ] **Phone G1-G3:** the golden frames as the phone shows them (GOLDEN_FRAMES.md asks for this; the attribute can't be set on a phone, so play L1 to the street and the hideout to the job board by hand and screenshot).
- [ ] **Crew View on touch:** one L2 run holding the CREW button. For: the kid test question "first person vs Crew View", and a TikTok "on my phone" cut if it reads.
- [ ] Do not film other people's phones or faces; never film kid testers.

## 7. Key art (not capturable in a heist)

Some candidates are composed on the story intro's town (`thumbs/TH3`, `TH6`, the icons `IC1-IC3`). That stage exists only while the intro plays, so these can't be captured in normal play. Two routes (owner decides, ICON_THUMBNAILS.md §0.3):
1. **The illustrator** finishes the icon (and, if wanted, one key-art thumbnail) from the Blender render as the reference (ICON_THUMBNAILS.md §3.5 brief).
2. **A Studio key-art stage** (an owner-kit request for the code track: an `EH_Scenario` value that builds the intro town and poses Rookies from a data table). Not built; no code was changed for this checklist.

## 8. After every session (5 min)

- [ ] Name files `MMDD_<item>_<take>` (e.g. `1118_A5_t1.mp4`, `1120_TH2_t2.png`); back up the raw files the same day.
- [ ] Drop the stills and the take list in the Shots inbox; note which item each file is for (the item codes above).
- [ ] Delete any footage with a username, chat, a player list or someone who withdrew permission.
