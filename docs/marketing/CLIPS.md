# CLIPS: the 8 signature formats, shot lists and the 30-day posting calendar

_Marketing kit, file 2 of 5. Written 2026-11-12. Sources: MASTERPLAN §9.2 (formats), §9.3, §9.5 (gate and CTA timing), §9.8, §10.2 (milestones), §3.1-3.6 and §6.5-6.6 (what the game really does); level data in `src/shared/Levels/` and Config (`Config.Levels.PARTY_TILL_OPENS_SECONDS`, `Config.Sim`); every timed shot list is played through the headless sim by `docs/marketing/clips_check.luau` (revised 2026-11-12 after review: run budgets, the 0:20 till lock, follow-only calls to action before all ages); vault *Short-Form Video Marketing*, *Marketing to Kids and Teens*; `docs/VIRAL_PLAYBOOK.md`; `docs/research/growth.md` R2. Notation: **[DECISION]**, **[UNVERIFIED]**, (H), [estimate] as in the plan._

**Who uses this:** the owner records raw footage twice a week (20-30 minutes, §3 and §7); the clip editor (owner, friend or sibling, decision D8) follows the **Daily 15** (§8) to turn it into 1-2 posts a day from **Thu Nov 19**, cross-posted to TikTok, YouTube Shorts and Instagram Reels, each cut 3 ways (3 hook texts).

---

## 1. Rules for every clip

### 1.1 The six musts

1. **Readable with the sound off.** The story is told by on-screen text and in-game stamps (RUN n, BUSTED, "?", "$" numbers). Audio is a bonus.
2. **Hook in the first second.** Frame 1 is the most interesting frame (a clone failing, a door slamming, 8 copies). No logo, no title card, no "hey guys" (vault: hook 0-2 s).
3. **"◀ ME, 20 SEC AGO" on a clone in the first second** (MASTERPLAN §9.2). Spec in §1.2.
4. **One idea per clip, 8-20 seconds** (formats below; the vault's safe default is 15-30 s, and loops can be shorter). End on a frame that loops into the start, or a clear result.
5. **Only real gameplay.** No fake UI, no edits that make clones do what the game can't, no numbers we didn't get. Speed ramps and multi-angle cuts of a real loop are fine.
6. **Child safety and privacy.** No usernames, display names, chat or player list on screen. Never film the kid testers. Friend groups only with written permission (parents too for anyone under 18), voices only, no names (MASTERPLAN §9.2). No Roblox voice chat recordings.

### 1.2 The "◀ ME, N SEC AGO" caption (exact spec)

| Item | Value |
|---|---|
| Text | `◀ ME, 20 SEC AGO` (all caps). **[DECISION] The number is always true:** N = the real time since that clone's moves were recorded, rounded to the nearest 10 s. For the newest clone this is simply **the length of the previous run + the rewind (1.8 s; 1.0 s from the 4th rewind)**. So the shot lists end the run before the hero run at about **0:18 elapsed** (18 + 1.8 ≈ 20) to make "20 SEC AGO" literally true; any end between about 0:13 and 0:23 still rounds to 20 (F2-B ends at 0:22, F4 at 0:18.6). **Retakes age the clone:** every run played after the clone's run (even one you then Undo) adds its length + its rewind, so only the first take after it is "20 SEC AGO"; later takes are typically `30-50 SEC AGO` or `1 MIN AGO`, so use take 1 for frame 1 or write the true number. If a format can't, write the true number (e.g. `◀ ME, 1 MIN AGO`, which is also funny) |
| Timing | In at **0.00 s** (pop: scale 115% → 100% over 0.10 s), hold to **1.50 s**, fade out **1.50-1.80 s**. Once per clip (in split screens: once, in the "now" half) |
| Placement | Next to the newest clone's head, the ◀ tip within about 40 px of the head; keyframe its position every 0.25 s if the clone moves. Inside the safe area (§1.3) |
| Look | Heavy rounded caps (the thumbnail font, ICON_THUMBNAILS.md §2), cap height 54-64 px on a 1080-wide frame, fill Getaway White `#F4F7FF`, outline Ink Indigo `#1C1F3B` 8 px, the ◀ in Clone Cyan `#3DE8FF` |
| If the footage is the in-game Heist Reel | The reel already burns the label (§6.6). Do not add a second one |

### 1.3 Frame, safe areas and text (9:16)

- **Export:** 1080 × 1920, 30 fps (60 if the footage is 60), H.264, ≤ 30 s, under 50 MB.
- **Safe area:** keep text and the subject between **12 % and 75 % of the height** and **6 % to 85 % of the width** (TikTok, Shorts and Reels put buttons on the right and captions at the bottom; the vault rule is "middle 70 % of height, away from the right 15 %").
- **Hook text:** top band (12-28 % height), **5 words or fewer**, cap height 90-120 px, white with a 10 px Ink Indigo outline, the key word in Clone Cyan. On screen from 0.00 s for at least 2.5 s (whole clip if it is under 10 s).
- **Result text** (last 1.5 s): the real outcome from the footage, e.g. `$2,350 · 8 OF ME`, `BUSTED`, `IT WAS ME`.
- **Wordmark:** `HEIST YOURSELF` small, centred, only in the **last second**. Never a URL or handle on the video.
- **Subject** in the central third of a landscape recording, so the 9:16 crop holds it (the reel's "central 32 % of frame width" rule, §6.6).

### 1.4 Three cuts per clip

Every clip is exported 3 times with a different hook text (and, if useful, a different first second). **Cut A → TikTok, cut B → Shorts, cut C → Reels**; the next Monday rotate (A → Shorts, B → Reels, C → TikTok) so every hook meets every platform. Never post the same cut twice on one platform. Hook variants are listed per format below.

### 1.5 Captions, hashtags and calls to action

**Hashtags:** 3-5 per post, `#heistyourself` first.
- Always: `#heistyourself #roblox #robloxgame`
- Devlog posts: add `#robloxdev #gamedev`
- From Dec 1: add `#robloxchristmas`
- **Never:** other games' or brands' names (`#gta6`, `#jailbreak`, `#payday`, `#robit`...), `#freerobux`, unrelated trending tags. GTA 6 ships Nov 19; we don't ride it (vault: no other games' names to catch their searches).

**Calls to action by stage** (MASTERPLAN §9.5 #5: no "join now" until the Audience Reach dashboard shows all ages; until then posts drive follows, Favorites and RSVPs, never joins):

| Stage | Dates | Line at the end of the caption |
|---|---|---|
| **1a Teaser, no date** | Nov 19 - Nov 30 (until the go / no-go says go) | `Coming to Roblox this December. Follow so you see it first.` |
| **1b Teaser, dated** | From the Nov 30 go to Dec 2 (no-go: Dec 1-9 with Dec 10) | `Coming to Roblox on Dec 3. Follow so you see it first.` (no-go: `on Dec 10`) |
| **2 Launch, 16+ trial** | Dec 3 until the dashboard shows all ages (expected ~Sat Dec 5) | `Christmas heists are coming to everyone on Roblox very soon. Follow so you know first.` |
| **3 All ages** | From the day the dashboard shows all ages | `Search "Heist Yourself" on Roblox.` (+ the share link in the bio, LAUNCH_CHECKLIST). `Tap Notify Me` lines also start here |

**[DECISION] Two hard rules.** (1) No launch date anywhere (caption, burned-in text, bio, DM) before the Nov 30 go: the plan keeps Dec 10 as the fallback, and 11 days of posts can't be taken back. (2) Nothing that reads as "it's out, go play" before stage 3: no `OUT NOW`, `search it`, `join`, `Notify Me` or "on the game page", in captions **or burned into a video**. During the 16+ trial an under-16 viewer who searches finds nothing (CREATORS.md §6 rule 3 uses the same reason), and burned-in text stays on that video for good. Launch-day clips carry dateless, join-free result text (`STEAL BACK CHRISTMAS`).

Caption style: one funny sentence in kid words + one question (comments help) + the stage line + hashtags. Example: `My clone had ONE job. 😭 Would you trust past you? Coming to Roblox this December. Follow so you see it first. #heistyourself #roblox #robloxgame`

**Posting times (H):** slot **A 17:30 CET** (Europe after school; US late morning at weekends) and slot **B 22:30 CET** (16:30 US Eastern, after school). Weekdays: slot B. Weekends and big days: both. Use each app's scheduler (TikTok allows scheduling about 10 days ahead **[UNVERIFIED for every account type]**).

### 1.6 Audio

- Clips must work muted, so audio choices never decide a clip.
- **Music:** only the platform's own licensed sounds (on a TikTok business account, the Commercial Music Library) or music we own. Never Roblox library music off-platform (licence for social video **[UNVERIFIED]**, MASTERPLAN §7.2) and never songs with lyrics on anything that becomes a Roblox video thumbnail.
- **In-game SFX** (tape clack, clone arpeggio, ka-ching, wah-wah): use them only once the SFX licence is confirmed to cover social video **[UNVERIFIED, open question 3]**. Until then, export with the in-game sound muted and add a platform sound.
- **Voice:** the owner may talk on devlog posts (with burned-in subtitles). Friend reactions (format 7) are recorded off-Roblox with written permission and are subtitled.

### 1.7 Platform settings

- Accounts are run by the owner (18+). Branded-content / paid-promotion toggles are only for paid partnerships (CREATORS.md).
- **YouTube "made for kids"**: answer honestly per video. Our clips are about an all-ages game and young viewers will watch; if the video is aimed at children, mark it, even though it turns off comments (vault *Marketing to Kids and Teens*: mislabelling is a legal risk). **Owner decision, not legal advice.**
- No giveaways, no "follow for a code", no "like for robux".

---

## 2. When each format can be shot (mapped to the build) [estimate]

| # | Format | Needs in the build | Earliest | Before that |
|---|---|---|---|---|
| 1 | RUN 1 vs RUN 8 | Sim path in Studio; L5 Clone Party for "8" | L2 now-ish (W2, ~Nov 19); L5 in W3 (~Nov 27) | `RUN 1 vs RUN 4` in L2 (cap 4) |
| 2 | MY CLONE BETRAYED ME | L2 (plate betrayal); L5 Alarm Run for the alarm version | W2 (L2); W3 (alarm) | — |
| 3 | HE DOES IT EVERY TIME | L3 laser grid and Zap; the blooper log's auto-stitch arrives **Dec 11** | W2 (editor stitches by hand) | — |
| 4 | WRONG ONE | L4 Gus with the 2.0 s "huh?" freeze (GusView pose attributes exist) | W2 | — |
| 5 | 8 OF ME | L5 swarm stamp + Crew Line-up | W3 (~Nov 27-28) | — |
| 6 | POV: night guard | Gus in L5 (awake after the alarm) or L6; the owner kit's Gus cam (fallback: freecam) | W3 | — |
| 7 | 1 ME vs 4 FRIENDS / 4 FRIENDS, 16 ROBBERS | 4 accounts in one party; L6 Big Score (or L2-L4, where 4 players × 3 clones = 16 also fits) | W3 for L6; W2 in L2-L4 if 4 accounts are available | — |
| 8 | DEV: 4 CLONES. ME: 3 | Diamond medal card | **Jan 8** (outside this calendar; shot list in §4.8) | — |
| S | STEALING BACK CHRISTMAS WITH 8 OF ME | L5 + the Christmas dressing layer visible | When the dressing layer shows in Studio (W3; it is live Dec 3) | — |

If a row in the calendar (§6) is not shootable yet, post its **backup** instead (the calendar names one). Never post a feature before it exists.

---

## 3. Capture setup (do this once, then every session)

### 3.1 One-time preparation (owner, ~45 minutes, before Wed Nov 18)

1. **The capture avatar = "the Rookie".** One owner test account wears the same outfit in every clip and thumbnail: flat cap, long scarf, a smug side-eye face (MASTERPLAN §2.2 mascot), from catalog items **[DECISION]**; the clones are copies of this avatar, so the brand character is in every frame. No heist mask, no outfit copied from another game. Long term, the cap and scarf become our own items (open question 2). **What the clones keep:** a clone rig is a stripped silhouette (`src/server/Heist/Avatars.luau`): no face, no layered clothing, no textures, and at most **2 hair / hat accessories** (`Config.Heist.MAX_CLONE_ACCESSORIES`). So the copies show the cap, never the scarf or the smug face; those are on the live hero only. Keep the Rookie to hair + cap (in December: hair + a catalog Santa hat of accessory type Hat) so both carry onto the copies. The in-game `Hat_Santa` is different: a clone-only cosmetic (`cloneHat` slot, 25 Candy Canes), so it puts Santa hats on the copies and never on the live hero.
2. **Progress that sticks.** Turn on Studio access to API services for the **test** experience (docs/DATA.md), so Studio saves progress under `_TEST_` keys. Play L1-L6 once (this also gives the golden solutions the plan needs, MASTERPLAN §8.9). After that, every Play starts in the garage with all levels on the van's tape shelf, so a session doesn't waste 15 minutes on L1-L4 **[UNVERIFIED until the sim path's level select is wired]**.
3. **Config for capture:** `src/shared/Config.luau` → `Config.GAME_MODE = "sim"` in the capture build only (v0.1 has no Gus cone, Clone Deck or stamps). Never commit that change to main.
4. **Recorder:** OBS Studio (free). Scene "Wide": canvas 1920 × 1080 (2560 × 1440 if the screen allows), 60 fps, Window Capture of the Studio window, cropped to the viewport. Scene "Tall": canvas 1080 × 1920 for portrait shots (Studio window made tall, or Studio's device emulator with a custom 1080 × 1920 portrait device). Recording: MKV, quality CQP/CRF 18, then Remux to MP4. Game audio on its own track.
5. **Studio quality:** Studio settings → Rendering → quality level 21 (highest). The look comes from the project's Lighting; never change Lighting for a clip.

### 3.2 Every session (2 minutes)

1. `rojo build -o build/EchoHeist.rbxlx` from the latest main, open it in Studio (with `GAME_MODE = "sim"`), Play (F5).
2. **Hide what must not be filmed.** Chat, player list and core menus: in the **client** command bar (Play mode: switch the command bar context to Client) run
   `game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)`
   For clean cinematic shots also hide our HUD:
   `for _, g in game.Players.LocalPlayer.PlayerGui:GetChildren() do if g:IsA("ScreenGui") then g.Enabled = false end end`
   (set `true` to bring it back). Keep the HUD **on** for shots that need the in-game RUN stamp, the BUSTED stamp or the loot meter, which are the best sound-off text there is. With 2+ players, hide name tags: on each client, `for _, p in game.Players:GetPlayers() do local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid") if h then h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end end`.
3. **Freecam:** Left Shift + P during a solo Play toggles the free camera (Roblox docs). Move slowly; 2-3 s holds are better than flying. **While the freecam is on, your character doesn't move** (WASD flies the camera), so one person can't play a moving live run and fly the freecam at the same time. Freecam shots are of clones, or of you standing still on a mark.
4. **Pinned camera (a fixed angle while you play):** set the angle with the freecam, then in the **client** command bar run `_G.pin = workspace.CurrentCamera.CFrame`, turn the freecam off, and run `local c = workspace.CurrentCamera c.CameraType = Enum.CameraType.Scriptable c.CFrame = _G.pin c.FieldOfView = 50`. The camera stays put and WASD still walks your character. `workspace.CurrentCamera.CameraType = Enum.CameraType.Custom` unpins it. The rewind effect resets the field of view, so run the pin line again after each rewind **[UNVERIFIED in the sim build until tried once; if `_G` doesn't keep the value, `print(workspace.CurrentCamera.CFrame)` and paste the numbers into `CFrame.new(...)`]**. Every `CAM_` preset below where the live you moves is a pinned camera; the rest can be the freecam.
5. **The multi-angle trick (works today):** the loop is deterministic. After your hero run is recorded as a clone, play one more run **standing still** somewhere off-camera (inside the van), fly the freecam and film the whole loop replaying. Then open the Clone Deck and tap **Undo last run** to delete that standing-still clone, and replay again for the next angle. Limits: (a) in the replay your hero run is a glowing clone, not the opaque live avatar, so use it for wide and swarm shots, not for shots where "you" must look like the live player; (b) **every replay costs a run.** Undo and Redo change the deck, never the run counter, so Dawn comes just as fast. Use the trick only where the shot list's **run budget** (§4) has spare runs: never in Clone Party or the Big Score once you need all 8 runs for 8 copies, and in L4 only within runs 4-6.
6. Write the take list as you go: `date_format_take_angle` (e.g. `1124_F4_t2_low`).

### 3.3 What the owner kit should add (request for the capture-place builder; not built yet)

MASTERPLAN §9.2 promises "a capture place with the live lighting, a freecam, a director command ... and the Gus cam". These shot lists use the fallbacks above until it exists. Requested features, in priority order:
1. **Capture build switch:** jump to any level with all levels unlocked, test universe and Studio only.
2. **Camera presets** as data (anchor + yaw / pitch / distance / FOV, like the STYLE_BIBLE §7 bookmarks), hotkeys 1-9, with the presets named in §4 (`CAM_F1` ...) and ICON_THUMBNAILS.md (`CAM_T1` ...), as **scriptable cameras that keep your character playable** (the §3.2 #4 pin, without the command bar) and that add the heist instance's offset to the level coordinates.
3. **Gus cam:** the camera on Gus's head, looking where he looks (format 6).
4. **Director:** "replay the last loop with every run as a clone" (the multi-angle trick without the Undo step and without spending a run), plus "replay today's best blooper from the server log".
5. **Freeze at loop time t** (pose everything, for thumbnails) and **0.35x slow motion** (the reel's hero moment).
6. **One toggle (F8) for HUD / core GUI / name tags**, with an option to keep only the stamps.
7. **Staging marks:** small floor marks at given level coordinates, hidden while recording.

---

## 4. The eight formats: shot lists

Positions below are level coordinates from `src/shared/Levels/` (x = left/right facing the shop, the shop's street wall at z = 10 with the entrance at x -4..4, the van zone at z 16-24, rooms go toward negative z; the greybox layout moves once the kit lands, so re-check marks then). Times are **elapsed** run time (the tape counter shows the time left: at 18 s elapsed a 30 s run shows 0:12). "END" = tap END RUN (locked for the first 1.5 s of a run).

**Run budget (every shot list has one).** A heist has a fixed number of runs: **Dawn** ends it after `dawnRuns` (L4 and the daily vaults: 6; Clone Party and the Big Score: 8; L1-L3: none). A **story level ends at once when its goal is banked** (L2 Safe, L3 register, L4 night deposit: each 200 = the goal; the Big Score ends at the end of the run that banks the gold). **Undo and Redo never give a run back** (the run counter only goes up), so a retake costs one of the budget's runs; a reshoot after the budget is gone is a new heist (replay the level from the van). The bots in `docs/marketing/clips_check.luau` play each timed list below; `lune run docs/marketing/clips_check.luau` after any change to the levels or `Config` says whether it still holds. Bot times are tight (straight lines at full speed), so the lists below give a margin where a human needs one.

### 4.1 Format 1: RUN 1 vs RUN 8 (most explainable: post first)

| Item | Spec |
|---|---|
| Hooks (A / B / C) | `RUN 1 vs RUN 8` / `1 OF ME vs 8 OF ME` / `HOW IT STARTED vs RUN 8` |
| Level | **L5 Clone Party** (30 s runs, 8 slots). Before L5 exists: **L2 Two Doors** as `RUN 1 vs RUN 4` (cap 4) |
| Run budget | **Dawn at run 8; Clone Party never ends on a bank. All 8 runs are needed** (run 8 = 7 clones + you), so no Undo, no retake inside the heist: a retake is a new Clone Party heist (~5 min). F5's run-8 shots can be cut from this heist's `CAM_F1` footage (its tape print and Line-up need their own cameras, so a full F5 is a second heist). L2 version: no Dawn, but banking the Safe (200 = the goal) ends the heist, so never bank it |
| Clones | Run 1: none. Run 8: 7 clones + you |
| Camera | `CAM_F1`, **pinned** (§3.2 #4, you walk under it): above the shop entrance (x 0, z 8, height 16), looking into the shop at about 35° down, all three aisles (shelves at x -8, 0, 8) and the van path in frame. **Identical** for both halves: pin the same CFrame for run 1 and run 8 |
| What you do | **Run 1:** walk in alone, grab the candy display by the door (WindowW, x -13, z 6), bank it at the van, try one shelf, END at about 0:12 (the "Then" half). **Runs 2-7:** each run rob a different aisle side (west of shelf 1, east of shelf 1, ... east of shelf 3), banking every item (one at a time at bag level 0); **leave the till alone** (it is time-locked until 0:20 and trips the alarm). END every run at **0:18** wherever you are. **Run 8:** the tape print fans the 7 copies out and the "8 OF ME" stamp lands at **0:01.5**; rob the back rows (teddies, z -20) while the 7 clones work |
| Caption | `◀ ME, 20 SEC AGO` on the run-7 clone in the bottom half, 0.00-1.50 s (run 7 ended at 0:18 + the 1.0 s quick rewind ≈ 19 s, true) |
| Edit (12 s) | Split screen top / bottom, each a 1080 × 960 crop from the centre of the wide recording. Labels `RUN 1` (top) and `RUN 8` (bottom), top-left of each half. 0.0-1.0 s: both halves from loop time **0:01.5** (the Swarm stamp fires 1.5 s into the run, `Config.Sim.SWARM_FANOUT_SECONDS`), hook in the seam between the halves; the in-game "8 OF ME" stamp landing in the bottom half. 1.0-9.0 s: both halves play the same 8 s of loop time. 9.0-10.5 s: freeze both on the loot meter (`$15` vs the real run-8 number). 10.5-12.0 s: result text `RUN 8: $____` (real number), wordmark, cut back to frame 1 (loop) |
| Sound off | Labels + the two loot numbers tell the whole story |
| Caption (post) | `Run 1: just me. Run 8: me, me, me, me, me, me, me and me. Which one would you be?` + stage line + `#heistyourself #roblox #robloxgame` |
| Christmas version (from Dec 1) | Same, with the dressing layer on; hook C becomes `RUN 1 vs RUN 8 🎄` |

### 4.2 Format 2: MY CLONE BETRAYED ME

| Item | Spec |
|---|---|
| Hooks | `MY CLONE BETRAYED ME` / `I TRUSTED PAST ME` / `NEVER TRUST 20-SEC-AGO ME` |
| **Version A (W2): the plate** | **L2 Two Doors.** Plate A (x -10, z -8) holds the back-room door (z -20). **Run 1 (the traitor):** step on plate A by 0:03, stay until **0:10.0**, then casually walk to the tip jar (x -8, z 4), grab it (about 0:10.8, the same moment the door shuts) and END at **0:18**. **Run 2 (the victim):** walk the long way round (in at the entrance, down the east side at x 14) and step into the back-room doorway at about **0:10.9**: the door starts closing at about 0:10.6 (0.4 s plate grace after the clone's feet leave the plate) and is shut at about **0:10.95**, in your face. Turn the camera toward your clone strolling off. Do 3-4 takes of run 2 (Undo last run between takes) until the timing is perfect (only take 1 is "20 SEC AGO"; take 2 ≈ 30 s, take 3 ≈ 50 s, §1.2) |
| Run budget A | L2 has no Dawn and this shot banks nothing (the tip jar is never banked; banking the Safe would end the heist), so takes are unlimited |
| Camera A | `CAM_F2A`, **pinned** (you are running): behind and above the doorway approach (about 10 studs back, height 12), looking down the shop toward the back-room door, with plate A in the left third, so the clone stepping off and the door shutting are in one frame. Or the follow camera zoomed out |
| **Version B (W3): the alarm** | **L5 Clone Party.** The till (x -8.5, z -1, the top loot) is **time-locked until 0:20 of every run** (`Config.Levels.PARTY_TILL_OPENS_SECONDS`; an earlier grab is refused). Robbing it trips the Alarm Run: Gus wakes in the back office and chases the nearest robber he can see; the shop shutter (the entrance) drops 6 s later. **Run 1 (the traitor):** rob one shelf item and **bank it** (at bag level 0 you carry one item, and the till needs empty hands), be at the till before 0:20, grab it at about **0:20.5** (alarm), stay by the counter and END at about **0:22** (22 + 1.8 s ≈ 24 s, which still rounds to 20 SEC AGO). **Run 2 (the victim, take 1, follow camera):** go in along the east aisle (x 12.5) and wait in the back aisle by the office doorway (x 4, z -25) by **0:19**, eyeing Gus's piggy bank (x 11, z -33). At 0:20.5 your clone robs the till, the red lights spin, Gus wakes and comes for you: run for the van down the east aisle. (Sim: a ~4 s chase, the bot is caught at about 0:24.8; a human may dodge. Harsher variant: wait at the piggy bank itself and you are caught within a second of the alarm.) **Run 3 (take 2, after Undo last run):** stand still in the van and film the clone at the till with the freecam (`CAM_F2B`, low by the counter); intercut the two takes |
| Run budget B | Clone Party: Dawn at run 8, never ends on a bank. This uses runs 1-3 of a heist of its own; every Undo still costs a run (5 spare) |
| Caption | `◀ ME, 20 SEC AGO` on the traitor clone, 0.00-1.50 s, frame 1 already shows it stepping off the plate (A, loop 0:10.0) / reaching for the till (B, loop 0:20.5) |
| Edit (10 s, A) | 0.0-1.0 s: clone steps off the plate (loop 0:10.0) + hook; you are running at the door. 1.0-2.5 s: the door shuts in your face (0:10.6-0:10.95, hold 0.5 s on the bonk). 2.5-4.0 s: whip-pan / cut to the clone walking away happily. 4.0-8.5 s: the clone grabbing the $10 tip jar (the same loop seconds from the other side: a cut of the real loop). 8.5-10 s: result text `IT WAS ME.` + wordmark |
| Edit (12 s, B) | 0.0-1.0 s: clone grabs the till (loop 0:20.5) + hook + caption. 1.0-2.0 s: red lights, "VAN LEAVES 0:20" counter. 2.0-4.0 s: you in the back aisle, Gus waking and turning toward you ("!"). 4.0-10.0 s: the chase toward the van (HUD on: the van counter is great sound-off text). 10-12 s: result (`BUSTED` or `ESCAPED`, whichever happened) |
| Sound off | The door shutting (A) or the red beacons and the van counter (B) carry it; result text names the outcome |
| Caption (post) | `My clone had ONE job. 😭 Would you trust past you?` + stage line + hashtags |

### 4.3 Format 3: HE DOES IT EVERY TIME

| Item | Spec |
|---|---|
| Hooks | `HE DOES IT EVERY TIME` / `EVERY. SINGLE. RUN.` / `MY CLONE NEVER LEARNS` |
| Level | **L3 Lights Out.** Plate A (x 10, z -8) opens the back room; plate B (x 12, z -26, in the back room) turns off the laser grid (z -34) in front of the register |
| Run budget | L3 has no Dawn, but **banking the register (200 = the goal) ends the run and the heist at once**. So nothing is banked until the last run, and that bank comes after the zap. 7 runs; Undo is free here (no Dawn) |
| What you do | **Run 1:** stand on plate A from 0:03, END there at 0:18 (the clone holds the door forever). **Run 2:** go to plate B, stand on it until **0:15** (from 0:05 at the latest), then step off and END at 0:16 (the grid comes back on at about **0:15.6**). **Run 3 (the fool):** wait in the back room in front of the grid, walk into it at about **0:17.5** (it is on): **Zap**, soot puff, flop, your run ends. **Runs 4, 5, 6 (the takes):** stand still by the van, fly the freecam to `CAM_F3` and film clone 3 zapping at 0:17.5 again; after the zap, freecam off and END. Don't grab the register. L3's cap is 4 clones and the deck is full from run 4, so each new standing run replaces slot 4 by itself (clone 3 keeps zapping; no Redo needed). **Run 7 (the payoff, optional):** grab the register while the grid is off (go through at about 0:05.5) and come back out before 0:15.6, wait at the shop door, and step into the van only **after** the zap (about 0:20): the bank ends the heist |
| Camera | `CAM_F3`: freecam at the grid, 6 studs to the side and 3 studs up, the zap spot in the centre third, same position for every run (you stand still, so the freecam is fine) |
| Caption | `◀ ME, 20 SEC AGO` on clone 3 in the first zap shot (run 4: run 3 ended at about 17.5 s + 1.8 s rewind ≈ 19 s, true) |
| Edit (8 s, loopable) | 0.0-1.0 s: zap #1 (run 4) starts + hook + caption. Then zap #2 (run 5) and zap #3 (run 6), each 2 s, with a counter text `x1`, `x2`, `x3`. Last 1 s: `x3`, wordmark, cut back to zap #1. From **Dec 11** the blooper log stitches this 6 s cut automatically (MASTERPLAN §9.2); use that footage instead |
| Sound off | The `x1 x2 x3` counter and the identical zap flop make the repeat obvious |
| Caption (post) | `Same laser. Same clone. Every. Single. Time. 💀 What would you name him?` + stage line + hashtags |

### 4.4 Format 4: WRONG ONE

| Item | Spec |
|---|---|
| Hooks | `WRONG ONE` / `GUS GRABBED THE WRONG ME` / `HE CAUGHT MY CLONE` |
| Level | **L4 Night Clerk.** Gus paces the back room along z -28: 2.5 s at the east end (x 13) facing the till, 1.5 s at the west end (x -6) facing the shelves. Plate A (x 10, z -8) opens the back room; plate B under the coat rack (x -12, z -23, a hide spot) opens the safe room (door at z -36); the night deposit is at x 0, z -42 |
| Run budget | **Dawn at run 6** (par 2 + 4), and **banking the night deposit (200 = the goal) ends the heist at once**. Runs 1-3 are the set-up; the hero has **3 takes: runs 4, 5 and 6**. Takes 1 and 2 END in the front room before the van (no bank), then Undo last run; take 3 (run 6, the last before Dawn) may bank. A 4th take is a new heist |
| What you do | **Run 1:** stand on plate A, END there at 0:18. **Run 2:** wait in the front room by the back-room door (x 0, z -10) until **0:04.2** (Gus walking east, away from you), slip to plate B under the coat rack (hidden), END there at 0:18. **Run 3 (the decoy):** wait by the back-room door until **0:15.3** (Gus at the east end, facing the till), walk in and stop in the middle of the room (x 2, z -24), standing still. When Gus turns west at about **0:17.4** he sees you: amber → "?" at 0:18.0 → caught at about **0:18.6** (live: you are sent home; from run 4 the clone is BUSTED instead). **Runs 4-6 (the hero):** wait by the back-room door; at **0:06.6** (Gus at the east end facing the till) cross straight to the safe room (door at z -36, held by clone 2), grab the night deposit (x 0, z -42) and wait just inside the safe room (x 1.5, z -39). At about **0:18.6** Gus busts clone 3 and freezes for **2.0 s** with "huh?" (his vision is paused): walk straight out and north, right past him (he stands at about x 9, z -28, staring at where the clone was), through the back-room door and on to the van. The capture account must be past its first heist (first-heist detection times are doubled) |
| Camera | `CAM_F4`, **pinned** (you are walking): low in the back room's south-west (x -6, z -33, height 2.5) looking toward Gus's freeze spot (x 9, z -28), FOV 50: Gus in the right third, 3/4 to the camera, staring at the clone; the busted clone between; you walking north across the frame from the safe-room door. Second angle: the follow camera on take 2 or 3 (one camera per take) |
| Caption | `◀ ME, 20 SEC AGO` on the busted clone in take 1 (run 3 ended at 18.6 s + 1.8 s ≈ 20 s, true). Take 2 is `◀ ME, 40 SEC AGO`, take 3 `◀ ME, 1 MIN AGO` (§1.2) |
| Edit (9 s) | 0.0-1.0 s: Gus turns onto the clone, amber → "?" (loop 0:17.4-0:18.0) + hook + caption. 1.0-2.5 s: the bust (0:18.6): the clone glitches into tape ribbons, Gus freezes with "huh?". 2.5-5.0 s: slow-mo 0.5x: you step out of the safe room with the bag and walk right past his frozen stare. 5.0-7.5 s: out through the door and to the van. 7.5-9.0 s: result text `WRONG ONE.` |
| Sound off | Gus's in-game "?" and "huh?" bubbles and the clone's glitch-out tell the joke; `WRONG ONE.` lands it |
| Caption (post) | `Gus caught the wrong one. 🤫 Who's the real me?` + stage line + hashtags |

### 4.5 Format 5: 8 OF ME

| Item | Spec |
|---|---|
| Hooks | `8 OF ME` / `ME x8` / `I AM THE WHOLE CREW` |
| Level | **L5 Clone Party** (Dawn at run 8) |
| Run budget | As format 1: all 8 runs, no Undo. Run 8 needs `CAM_F5A` here and `CAM_F1` in format 1, so shoot F5 as its own heist (or reuse F1's run-8 footage for the robbing shots and add only the Line-up) |
| What you do | As format 1, runs 2-7 (each run a different aisle, END at 0:18). **Run 8:** the "tape print" (clones appear one by one, 60 ms apart, scanline + floor ring + arpeggio) at 0:00-0:00.5, then the in-game **"8 OF ME"** stamp at **0:01.5** once the copies have fanned out. Stand still in the van for the first 2 s and film both with the freecam, then rob until Dawn: the heist ends into the **Crew Line-up** (every copy walks to its spot and strikes one synchronized pose) |
| Cameras | `CAM_F5A`: wide from the van looking into the shop for the tape print and the stamp. `CAM_F5B`: low (2 studs) on the street at about z 38, 10 studs in front of the Line-up (it stands at z 28, on the street side of the van, facing the street), looking back at the crew with the van and the lit shop front behind them, FOV 50 (the STYLE_BIBLE B4 idea) |
| Caption | `◀ ME, 20 SEC AGO` on the run-7 clone, as it prints in |
| Edit (14 s) | 0.0-1.0 s: from loop time **0:01.5**: the `8 OF ME` stamp landing over the 8 copies + caption (the stamp is the hook; add hook text only on cuts B and C). 1.0-2.0 s: a quick cut back to the tape print (loop 0:00-0:00.5 at half speed). 2.0-8.0 s: 3 short shots of 8 copies robbing (wide, aisle, the loot meter climbing). 8.0-12.5 s: Crew Line-up, the synchronized pose in slow motion. 12.5-14 s: result `RUN 8 · 8 OF ME · $____` + wordmark |
| Sound off | The in-game "8 OF ME" stamp, the copies printing in one by one, and the synchronized pose |
| Caption (post) | `I didn't need friends. I needed 7 more of me. 😎 How many of you would you need?` + stage line + hashtags |
| Seasonal: **STEALING BACK CHRISTMAS WITH 8 OF ME** | Same shot list in the Christmas-dressed Clone Party (fairy lights, wreaths, Gus in a Santa hat); every copy wears the in-game `Hat_Santa` clone hat (clone-only, 25 Candy Canes: grant it to the `_TEST_` profile) and the live Rookie wears a catalog Santa hat (accessory type Hat) in place of the cap, which also carries onto the copies' silhouettes (§3.1; check in Studio that the copies don't end up with two hats). Hook A `STEALING BACK CHRISTMAS WITH 8 OF ME` (2 lines), B `8 OF ME VS CHRISTMAS`, C `SANTA'S NEW HELPERS: ME x8` |

### 4.6 Format 6: POV: you're the night guard and 7 of the same robber walk in

| Item | Spec |
|---|---|
| Hooks (2 lines) | `POV: you're the night guard` + `and 7 of the same robber walk in` / `POV: you're Gus` + `and it's all the same guy` / `POV: night shift` + `and he brought himself x7` |
| Truth | **[DECISION]** In the Big Score one copy must stand on plate A (it holds the staff door) in the lobby, so the most Gus can see in the hall is **7** (6 clones + you); the heist itself still has 8 OF ME. The hook says 7. A 4-account capture (3 clones each, 16 copies) shows **15** in the hall: then `15 of the same robber`, all four in the Rookie outfit, and the 4 colours show. L5 version: count the copies really in his view in the footage and write that number |
| Level | **L6 The Big Score: Bank** (Gus paces the hall at z -24 between x 14 and x -6, 2.5 s facing the east wall, 1.5 s facing the west wall; the laser grid at z -33; a marble pillar at x 2..4, z -18..-16 just inside the staff door; 8 slots) or **L5** after the alarm (Gus awake and chasing) |
| Run budget | Dawn at run 8 (par 4 + 4); the heist only completes on the gold, which this shot never touches. All 8 runs are used: no retake inside the heist |
| What you do | **Run 1:** stand on plate A (behind the teller desk), END there at 0:18. **Runs 2-7:** wait beside the staff door in the lobby (x -4, z -11, out of Gus's sight); start the crossing between **0:10.5 and 0:11.75** (one run each, 0.25 s apart: Gus is walking west, then dwelling at the west end facing the wall), pass west of the pillar to your own mark in the hall (x -6 … 0, z -25.5 … -32, in front of the grid) and **END there at 0:17.5**, frozen mid-tiptoe. (Sim: crossings started at 0:04-0:09.5 are caught at about 0:10; an END after about 0:17.8 is seen when Gus turns west at the east end.) **Run 8 (with the Gus cam):** cross at 0:12 to your own mark and freeze. At about **0:17.9** Gus turns west and sees all 7 of you at once; "?" pops over every copy at **0:18.4**; at **0:19.0** he busts the oldest copy (tape ribbons) and freezes 2 s with "huh?": walk back out through the staff door now (his vision is paused, so he never catches you and no alarm trips). Then he busts the frozen copies one at a time (about 0:22.2, 0:25.3, …). **Fallback without the Gus cam:** the same run 8, but once you are on your mark (about 0:13) turn on the freecam and fly it to `CAM_F6` (your character is standing still anyway); at 0:19 turn it off and walk out |
| Camera | **Gus cam** (owner kit, a scriptable camera on his head that leaves you playable). Fallback `CAM_F6`: freecam just behind and above Gus's head (height 6.5, he is 6.5 studs tall), FOV 70, turning with him. The moment he turns back west (0:17.9), the hall is full of the same robber |
| Caption | `◀ ME, 20 SEC AGO` on the run-7 clone (run 7 ended at 0:17.5 + the 1.0 s quick rewind ≈ 19 s, true) |
| Edit (12 s) | 0.0-1.0 s: Gus's view turning west onto 7 frozen copies (loop 0:17.9) + hook + caption. 1.0-3.0 s: the double-take: "?" over every copy at once (0:18.4), comedic hold. 3.0-5.5 s: he busts one (0:19.0): tape ribbons, "huh?", while the real (opaque) you tiptoes out of frame. 5.5-10.5 s: speed-ramped, he busts the next copies one at a time, a "huh?" after each. 10.5-12 s: result `HE NEVER STOOD A CHANCE` + wordmark |
| Sound off | The 2-line hook sets up the POV; the identical copies and the "?" do the rest |
| Caption (post) | `Gus is having the longest night of his life. 🔦 POV or real job?` + stage line + hashtags |

### 4.7 Format 7: 1 ME vs 4 FRIENDS / 4 FRIENDS, 16 ROBBERS

| Item | Spec |
|---|---|
| Hooks | `4 FRIENDS, 16 ROBBERS` / `1 ME vs 4 FRIENDS` / `WE BROUGHT OURSELVES` |
| People | The owner + 3 friends, all 16+ (or under 18 with a parent's written OK, and they never post). Each friend signs the one-paragraph permission in LAUNCH_CHECKLIST appendix B. No names anywhere |
| Where | A private server on the **test** experience (early testers) before Dec 3; on the live game after all-ages clearance |
| Level | **L6 The Big Score: Bank**, a party of 4 → each player gets 3 clones (`floor(12 / 4)`), so the final run has **16 robbers**. Fallback before L6: L2-L4 (cap 4 → 3 each, still 16) |
| Run budget | L6: Dawn at run 8, and the heist ends at the end of the run that banks the gold, so the gold run is the last one. L2-L3: no Dawn, banking the goal ends it at once; L4: Dawn at run 6. Each player needs 3 runs before the final one |
| What you do | Each player records 3 runs with a job (plates A-D for the scale vault need 4 actors; extra clones haul loot or run decoy routes). In the final run all 4 go for the Hoardsworth Gold. Hide name tags on every client (§3.2 #2) |
| Camera | `CAM_F7`: wide at the vault doorway (z -48) from inside the scale room, height 10, FOV 60: the angle with the most actors in frame (the reel's rule) |
| Voice | Record the friends' reactions off-Roblox (phone or a call recorder, with permission), never Roblox voice chat. Burn in subtitles for every line (sound-off) |
| Caption | `◀ ME, 20 SEC AGO` on the owner's newest clone (Clone Cyan) |
| Edit (20 s) | Version "16 ROBBERS": 0.0-1.0 s: 16 robbers flooding the vault + hook + caption; then the funniest reaction lines over the heist; result `16 ROBBERS · $____`. Version "1 ME vs 4 FRIENDS": split screen, top = solo 8 OF ME (format 5 footage), bottom = the 16-robber run, labels `1 ME` / `4 FRIENDS` |
| Sound off | Burned-in subtitles for every reaction line; 4 clone colours make "4 friends" visible |
| Caption (post) | `We were 4. Then we were 16. 🤯 Who would be on your crew?` + stage line + hashtags. In week L3 (Dec 17-23) the angle is "play with your cousins this Christmas" (MASTERPLAN §9.8) |

### 4.8 Format 8: DEV: 4 CLONES. ME: 3 (from Jan 8, outside this calendar)

| Item | Spec |
|---|---|
| Hooks | `DEV: 4 CLONES. ME: 3` / `I BEAT THE DEVELOPER` / `THE DEV USED 4. I USED 3.` |
| Level | **L4 Night Clerk** or **L6 Big Score**, with the Diamond medal (beat the developer's clone count, `devClones` in Config, MASTERPLAN §5.2) |
| What you do | Clear the level with one clone fewer than the dev (only if that is really possible; the developer's count is set from the owner's own golden solution). Record the results card stamping Haul, Crew, Clean and the Diamond |
| Edit (11 s) | 0.0-1.0 s: the medal card with the dev's count crossed out + hook + a caption on a clone in the replay behind it. Then the 3-clone run at 2x. End: the Diamond stamp |
| Sound off | The medal card's crossed-out number is the whole story |
| Prep | Record on Wed Jan 6 from the Jan 8 build in Studio; post Fri Jan 8 17:00 CET with the update |

---

## 5. The pitch clip (for CREATORS.md, by Sun Nov 22)

One 15 s vertical clip attached to every creator DM: **format 4 (WRONG ONE) or format 2 version A**, whichever reads better on Nov 21, with hook text, the "◀ ME" caption and the result text, no CTA, no handle. File: `pitch_v1.mp4`. Replace it with format 5 (8 OF ME) once L5 is shootable, for the second wave of messages.

---

## 6. The 30-day calendar (Thu Nov 19 - Fri Dec 18)

Slots: **A** 17:30 CET, **B** 22:30 CET. "Stage" = the CTA line from §1.5 (stage 1 rows before the Nov 30 go use the undated line 1a). "Src" = the capture session that provides the footage (§7). Every post goes to all three platforms (cuts A/B/C). If a milestone slips, post the backup. If the Nov 16 fun gate fails, launch moves to Dec 10: shift every "Stage 2/3" row by 7 days and fill the gap with devlog and format 2-4 rows.

| Date | Dev / launch milestone (MASTERPLAN §9.5, §10.2) | Slot | Post (format, hook A) | Src | Stage | Backup |
|---|---|---|---|---|---|---|
| **Thu Nov 19** | W2 starts: sim in Studio, L1-L4 greybox. GTA 6 release day | B | Devlog 1: `I made a Roblox game where your past self is your teammate` (L1 first clone + quick RUN 1 vs RUN 3 in L2) | C0 | 1 | v0.1 bank footage |
| Fri Nov 20 | — | B | F2-A `MY CLONE BETRAYED ME` (L2 plate) | C0 | 1 | Devlog 1 re-cut |
| Sat Nov 21 | **Kid wave 1** (never film it) | A | F4 `WRONG ONE` (L4) | C1 | 1 | F3 |
| | | B | Devlog 2: `Every run is recorded. Then it helps you.` (the rewind effect + tape print) | C1 | 1 | F2-A cut B |
| Sun Nov 22 | **Kid wave 1**; video thumbnail v1 uploaded; pitch clip done | A | F1 `RUN 1 vs RUN 4` (L2) | C1 | 1 | F4 cut B |
| | | B | F3 `HE DOES IT EVERY TIME` (L3, hand-stitched) | C1 | 1 | Devlog 2 |
| Mon Nov 23 | **Creator pitches sent (deadline)** | B | Re-cut of the week's best clip with a new hook | C1 | 1 | — |
| Tue Nov 24 | Capture C2 | B | F4 v2 (different crossing, `HE CAUGHT MY CLONE`) | C2 | 1 | F3 v2 |
| Wed Nov 25 | **M1 exit:** L1-L4 solvable, desync-free | B | Devlog 3: `MEET GUS. Big flashlight. Bigger donut box.` (Gus patrol, double-take) | C2 | 1 | F2-A v2 |
| Thu Nov 26 | W3 starts: L5, L6, Alarm Run, Line-up | B | F2-A v3 (Two Doors, two clones betray) | C2 | 1 | F1 L4 |
| Fri Nov 27 | Deposit Robux bought (D2); capture C3 (first L5) | B | F3 v2 (a new zap spot) | C2 | 1 | F4 re-cut |
| Sat Nov 28 | **Kid wave 2** | A | F5 `8 OF ME` (first swarm, greybox OK: "first time it worked" devlog tone) | C3 | 1 | F1 L4 |
| | | B | F2-B `MY CLONE BETRAYED ME` (L5 till alarm) | C3 | 1 | F2-A re-cut |
| Sun Nov 29 | **Kid wave 2** | A | F1 `RUN 1 vs RUN 8` (L5) | C3 | 1 | F5 cut B |
| | | B | F6 `POV: you're the night guard` (L5 after the alarm) | C3 | 1 | F4 |
| Mon Nov 30 | **Go / no-go** | B | If go: F5 re-cut with `COMING DEC 3` as result text. If no-go: `COMING DEC 10` | C3 | 1 | — |
| Tue Dec 1 | Capture C4 (Christmas dressing) | B | Seasonal `STEALING BACK CHRISTMAS WITH 8 OF ME` | C4 | 1 | F5 re-cut |
| Wed Dec 2 | Events E1/E2 drafted; T-1 | B | F2-B Christmas (`I TRUSTED PAST ME`) | C4 | 1 | F1 L5 |
| **Thu Dec 3** | **Public 15:00 CET; expedited review submitted; E1 public** | A | Launch clip: format 5 in the Christmas Clone Party, hook `STEALING BACK CHRISTMAS WITH 8 OF ME`, result text `STEAL BACK CHRISTMAS` (no date, no "out now": the burned-in text must stay true while the game is 16+ only, §1.5) | C4 | 2 | — |
| | | B | F5 in the Bank (`8 OF ME` Big Score, vault opening) | C4 | 2 | F1 Christmas |
| Fri Dec 4 | E1 submitted for featuring by today at the latest; capture C5 | B | F4 Christmas (Gus in a Santa hat) + `Follow for the Christmas update on Fri Dec 11` (no "game page" or Notify Me at stage 2: under-16s can't open the page yet) | C4 | 2 | F3 |
| Sat Dec 5 | **Kid wave 3**; all ages expected | A | F1 `RUN 1 vs RUN 8` Christmas | C5 | 2 or 3 | F5 re-cut |
| | | B | F6 POV night guard (Big Score hall) | C5 | 2 or 3 | F2-B |
| Sun Dec 6 | Kid wave 3; creator private servers open the day after clearance | A | F7 `4 FRIENDS, 16 ROBBERS` (if the friend capture happened Dec 4-5; else F2-B) | C5 | 3 if cleared | F2-B |
| | | B | F4 re-cut | C5 | 3 if cleared | — |
| Mon Dec 7 | Video thumbnail v2 (Clone Party) uploaded | B | Seasonal 8 OF ME re-cut | C5 | 3 if cleared | F1 |
| Tue Dec 8 | Capture C6 (Wrapping Room build, for teasers) | B | F2-A/B best re-cut | C5 | 3 if cleared | — |
| Wed Dec 9 | **Fallback check:** not cleared → Engagement +$ (LAUNCH_CHECKLIST) | B | Teaser `THIS PRESENT NEEDS 2 OF ME` (heavy present, Wrapping Room build) + `Fri Dec 11` | C6 | 2/3 | F3 |
| Thu Dec 10 | E2 public + submitted for featuring (Fri Dec 11 at the latest) | B | F3 v3 | C6 | 2/3 | F4 |
| **Fri Dec 11** | **Drop 1 Wrapping Room 17:00; embargo lifts** if cleared by Dec 9; blooper stitching live | A (17:30) | `NEW: WRAPPING ROOM` (the new thing, live now): you + clone carrying a giant present on the conveyor | C7 | 3 | — |
| | | B | F3 auto-stitched `HE DOES IT EVERY TIME` (first blooper-log cut) | C7 | 3 | F3 v3 |
| Sat Dec 12 | Creator videos land (embargo lift) | A | F7 `4 FRIENDS, 16 ROBBERS` | C7 | 3 | F5 |
| | | B | F1 `RUN 1 vs RUN 8` (Wrapping Room) | C7 | 3 | F1 re-cut |
| Sun Dec 13 | — | A | F2 Wrapping Room (`MY CLONE DROPPED THE PRESENT`: your clone lets go of its end at its recorded time while you hold the other; only if the Dec 11 build really behaves this way) | C7 | 3 | F2-B re-cut |
| | | B | Seasonal 8 OF ME | C7 | 3 | — |
| Mon Dec 14 | — | B | F4 re-cut (Christmas) | C7 | 3 | — |
| Tue Dec 15 | Capture C8 | B | F6 `15 of the same robber` (if a 4-account capture exists: one copy holds plate A, §4.6) or F1 | C8 | 3 | F1 |
| Wed Dec 16 | Finale published-but-locked Thu | B | Teaser `THE SNOW GLOBE VAULT · FRI` + `Tap Notify Me` (only if stage 3; still at stage 2: the stage-2 line) | C8 | 3 | F5 |
| Thu Dec 17 | Capture C9 (finale build in Studio) | B | F7 `PLAY WITH YOUR COUSINS` angle (school break starts tomorrow) | C8 | 3 | F7 re-cut |
| **Fri Dec 18** | **Finale: The Snow Globe Vault 17:00** | A (17:30) | `NEW: THE SNOW GLOBE VAULT`: 8 of you moving the Giant Present | C9 | 3 | — |
| | | B | F5 finale `8 OF ME vs THE GIANT PRESENT` | C9 | 3 | F1 finale |

Total: **41 posts in 30 days** (11 days with 2). Each second post of a day is a **re-cut** (new hook, new first second) of an earlier clip where the table says so, so it fits the 15-minute day.

After 10 posts, compare each format's median 48-hour views to the account median: a format at **≥ 2× the median** gets more slots; one under 0.5× twice in a row is dropped for the backup (growth.md KPI table). Judge clips by **share-link D1** once links exist, not by views alone.

---

## 7. Capture sessions (owner, 20-30 minutes each, twice a week)

Each session records enough raw footage for the next 3-5 posts. Do the takes in this order; skip a line if its build isn't ready and record its backup.

| Session | Date | Record (formats, takes) | Feeds |
|---|---|---|---|
| **C0** | Wed Nov 18 | L1 first clone (3 takes, HUD on) · L2 RUN 1 vs RUN 3 (`CAM_F1`-style wide) · F2-A plate betrayal (4 takes of the victim run) · v0.1 bank as backup | Nov 19-20 |
| **C1** | Fri Nov 20 | F4 WRONG ONE (L4: runs 1-3 set-up, the 3 takes are runs 4-6 with Undo between, Dawn after run 6) · F3 zap x3 (L3: 6-7 runs, no bank before the last) · F1 RUN 1 vs RUN 4 (L2, never bank the Safe) · rewind effect close-up for devlog 2 · **pitch clip** source | Nov 21-23 |
| **C2** | Tue Nov 24 | F4 v2 (a new L4 heist: another crossing, low camera) · F3 v2 (different zap spot) · Gus patrol + double-take close-ups (devlog 3) · F2-A v3 with two traitor clones | Nov 24-27 |
| **C3** | Fri Nov 27 | **First L5** (one Clone Party heist per item, ~5 min each, so ~45 min: split it if needed): F1 RUN 1 vs RUN 8 (run 1 and run 8 from the pinned `CAM_F1`) · F5 8 OF ME (tape print + Line-up) · F2-B till alarm (runs 1-3: traitor, victim, till angle) then **T2** still in run 4 of the same heist · **T1** still (its own heist: 7 V marks, ICON_THUMBNAILS.md T1) · F6 POV after the alarm (freecam) | Nov 28 - Dec 2 |
| **C4** | Tue Dec 1 | Christmas dressing on: seasonal 8 OF ME · F2-B Christmas · F5 in the Bank (L6 vault opening) · the launch clip | Dec 1-4 |
| **C5** | Fri Dec 4 | F1 Christmas · F6 in the Bank hall · **friend session** (format 7 and the T4 still, 4 accounts, if the friends are available Dec 4-5) · F4 Christmas (Gus in a Santa hat) | Dec 5-8 |
| **C6** | Tue Dec 8 | Wrapping Room from the Dec 11 build in Studio: the heavy present with you + your clone (teaser) · F3 v3 | Dec 9-10 |
| **C7** | Fri Dec 11 (after 17:00) | The live drop: `NEW: WRAPPING ROOM` · the auto-stitched blooper cut (download from the game's end-of-heist card or re-record) · F1 Wrapping Room · F2 "dropped the present" | Dec 11-14 |
| **C8** | Tue Dec 15 | F6 with 4 accounts in one outfit (if friends are available) · Snow Globe Vault teaser from the build · F7 cousins angle | Dec 15-17 |
| **C9** | Thu Dec 17 | Finale build in Studio: 8 of you moving the Giant Present (`CAM_F5B` at the vault exit) · F5 finale | Dec 18 |

Rules for every session: same avatar (the Rookie), HUD choice per format, name tags off with 2+ players, write the take list, back up the raw files the same day, and delete raw footage of anyone who later withdraws permission.

---

## 8. The Daily 15 (editor, 15 minutes a day)

| Minute | Step |
|---|---|
| 0-2 | Open the calendar (§6): today's row, format, hook A/B/C, stage line. Open the edit template (1080 × 1920, safe-area guide layer, the three text styles from §1.2-1.3) |
| 2-5 | Pick the take from the session folder (the take list says which is best). Trim so **frame 1 is the hook moment** |
| 5-10 | Cut to the format's second-by-second edit (§4). Add the hook text, the `◀ ME, 20 SEC AGO` caption (0.00-1.50 s, true number), the result text, the wordmark in the last second. Mute in-game audio unless the SFX licence is confirmed; add a platform sound if wanted |
| 10-13 | Export 3 cuts (hooks A, B, C). Watch cut A once **muted on a phone**: if the story isn't clear without sound, fix the text, not the audio |
| 13-14 | Schedule: cut A on TikTok, B on Shorts, C on Reels (rotate on Mondays), with the caption, the stage line and hashtags (§1.5) |
| 14-15 | Log a row in the sheet: date, format, hook per platform, slot, 48 h views (filled in 2 days later), average watch %, comments of note, share-link visits (from Dec 3) |

On 2-post days the second post is a re-cut (5 minutes: new hook + new first second from the same take), so the day still fits.

**Sheet columns** (`clips_log.csv`): `date, slot, format, take, platform, hook, stage, views_48h, avg_watch_pct, likes, comments, shares, link_visits, notes`.

---

## 9. Decisions and open questions

**Decisions made here:** the caption number is always true and shot lists end the previous run at about 0:18 to make "20 SEC AGO" true; retakes write their own older number (§1.2); every shot list has a run budget and is sim-checked by `clips_check.luau` (§4); live moving shots use a pinned camera, freecam shots are of clones or of you standing still (§3.2); no date before the Nov 30 go and follow-only calls to action until all ages (§1.5); solo POV says "7 of the same robber" because one copy holds plate A (§4.6); the capture avatar is the Rookie outfit for brand consistency (§3.1); posting slots 17:30 and 22:30 CET (H) (§1.5); cut rotation by platform (§1.4); second daily posts are re-cuts (§6); stage lines tied to the Audience Reach dashboard, not to dates (§1.5).

**Open questions:**
1. Who builds the owner kit (§3.3), and by when? Formats 6 and the multi-angle work need it most; everything else has a fallback (the pinned camera of §3.2 #4 must be tried once in Studio first).
2. The Rookie outfit: catalog items for now; commission our own cap and scarf as UGC later (MASTERPLAN §2.2 wants the mascot human-finished and original)?
3. Does our SFX licence (lihfolk-sfx, ~38 licensed sounds) cover social video? Until confirmed, clips are exported with game audio muted.
4. YouTube "made for kids" setting: owner decision (§1.7).
5. Does Studio's progress persist with API access in the sim path (needed so captures start in the garage, §3.1 #2)?
6. Friend-group availability for format 7 (Dec 4-5 and Dec 15) and their parents' OK if under 18.
