# ICON AND THUMBNAILS: briefs, sketches and exact capture setups

_Marketing kit, file 4 of 5. Written 2026-11-12. Sources: MASTERPLAN §2.2 (brand), §6.2 and §6.5 (palette, clone look), §9.4 (icon, T1-T5, "only 2 active until DAU passes 1,000"); docs/STYLE_BIBLE.md §1-2, §7, §12-13; level data in `src/shared/Levels/` and Config (the capture runs for the icon, T1, T2, T3/F4, T4 and T5 are played through the headless sim by `docs/marketing/clips_check.luau`; revised 2026-11-12 after review: the 0:20 till lock, hats on clones, capture dates); vault *Game Icon Design*, *Thumbnail Composition for High CTR*, *Thumbnail Specs, Rules and Upload*, *Making Thumbnails in Studio and Blender*, *Thumbnail Review Checklist and Scoring Rubric*, *Thumbnail and Icon A-B Testing*; `tools/rbx_search.py` today. Notation: **[DECISION]**, **[UNVERIFIED]**, (H), [estimate] as in the plan._

**Every final image is a real in-game capture** (MASTERPLAN §9.4) from the capture setup in CLIPS.md §3, graded lightly, with text added on top. No paint-overs that change shapes, no characters or loot that the game doesn't have. Alt text and any text a player reads say **flashlight**, not "torch" (most players are American; "torch" stays fine in internal notes and the palette name Torch Amber).

---

## 1. Rules for every image

| Rule | Value | Source |
|---|---|---|
| Thumbnail size | **1920 × 1080**, 16:9 (other ratios are stretched), JPG quality ~90, **under 3 MB** | vault *Thumbnail Specs* (Roblox docs) |
| Icon size | Square, **≥ 512 × 512** (we master at 1024 × 1024); shown as small as ~150 px; **one icon per locale** | same |
| Home pool | 2-5 active for personalisation; **[plan] only 2 active until DAU > 1,000**: launch with **T5 + T3**; add **T1** once SwarmSeen ≥ 60 % by minute 10 is confirmed | MASTERPLAN §9.4; growth.md F1 |
| Video thumbnail | Real gameplay only, varied angles OK, no narration, no voice, no music with lyrics, sparing gameplay-only text; **3 uploads a month, rejections included** | vault *Thumbnail Specs* §4 |
| Truth gate (G1) | Every character, item, place, effect, number and UI element exists in the game; same art style | vault *Thumbnail Review Checklist* |
| Policy gate (G2) | No handles, links, QR codes; no Robux, "FREE", discounts, "UPDATE", "x2"; fits the Mild label; no other game's characters or branding; no heist masks | same; MASTERPLAN §1.3 |
| Text | **≤ 3 words**, upper third, cap height **≥ 90-110 px** at 1080p, outline 6-10 px in the darkest value | MASTERPLAN §9.4; vault *Composition* §6 |
| Focal subject | One hero at **30-45 % of the frame**, face on a rule-of-thirds point, looking into the frame or at the viewer | vault *Composition* §2 |
| Three-element limit | Hero + the promise (secondary) + text. Everything else is background | vault *Composition* §5 |
| Upload bar | Score **≥ 8.5 / 10** on the rubric (§7), both gates passed | vault *Review Checklist* |

### 1.1 Safe areas (16:9, 1920 × 1080)

```
+--------------------------------------------------------------------+
|[c]  corner 5 % (96 x 54 px): nothing essential               [c]   |
|     TEXT ZONE: upper third (y 54-360)                              |
|                                                                    |
|   . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .    |
|   .  ALL THREE ELEMENTS live in the centre 80 % x 70 %        .    |
|   .  (x 192-1728, y 162-918)                                  .    |
|   .  hero face on a thirds point: (640, 360) or (1280, 360)   .    |
|   . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .    |
|- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - | y 886
|     BOTTOM 18 %: player counts and metadata cover it. Nothing     |
|[c]  essential here.                                          [c]   |
+--------------------------------------------------------------------+
```

Make this a guide layer in the image editor (and, once the owner kit has it, a toggle in the capture place).

---

## 2. Brand constants for all art

| Element | Value |
|---|---|
| Ground / background | Ink Indigo `#1C1F3B` (never darker), Plum Slate `#3A3560` |
| **Clones** (the brand colour) | Clone Cyan `#3DE8FF` for the solo / P1 crew; Magenta `#FF4FD8`, Indigo `#6A5CFF`, Ghost White `#F4F7FF` only when other players' crews are in the shot. **Nothing else in the frame glows cyan** (STYLE_BIBLE §1.2-1.3) |
| Age ramp | As the game draws it: each older clone 12 % dimmer, older solo clones drift up to 25° toward violet. Capture it; don't recolour it |
| Loot | Heist Gold `#FFC21F` with a **sparkle** shape; always on a dark surface (gold vanishes on Warm Marble, STYLE_BIBLE §1.3) |
| Guard light | Torch Amber `#FFD27A`, only as Gus's cone |
| Danger | Alarm Red `#FF3838` (STYLE_BIBLE's proposed value) only as real alarm beacons and lasers, always with a shape; never decoration, never text |
| Christmas | Holly Green `#2FBF71`, Ribbon Burgundy `#8C2F4B` (Santa hats, berries), Snow `#C0C3D5` (small areas), warm-white fairy lights `#FFE7B8` |
| Characters | **The Rookie**: the capture avatar (flat cap, long scarf, smug side-eye; CLIPS.md §3.1). **The scarf and the face are on the live hero only**: a clone rig strips the face, layered clothing and every accessory except at most 2 hair / hat pieces (`src/server/Heist/Avatars.luau`, `Config.Heist.MAX_CLONE_ACCESSORIES`), so the cyan copies show hair + cap and never the scarf. **Gus**: big flashlight (the "torch" of the internal docs), peaked cap, handlebar moustache, Santa hat Dec 3 - Jan 4 (STYLE_BIBLE §12). **Sir Hoardsworth** appears only once he exists in the game (open question 3) |
| Text style | **[DECISION]** Heavy rounded caps in a free-licensed font (proposal: *Lilita One*, SIL Open Font License; the owner or the freelance artist may pick another OFL or owned font that matches the "HEIST YOURSELF" wordmark). Fill Getaway White `#F4F7FF`, outline Ink Indigo `#1C1F3B` 8-10 px, the key word in Clone Cyan |
| Never | Heist masks, guns, police, money piles with "$$$", Robux icons, emoji stickers, arrows, other games' looks, AI-generated art (MASTERPLAN §1.3, STYLE_BIBLE §9) |

**Standing apart from the heist row (checked today with `tools/rbx_search.py`):** the current heist and steal titles lean on money and gem emoji (💰 💎 🏦) and city / police framing (Criminal Simulator, ROB IT, Heist Evolution, Risky Heist, HEIST: Rob a Store); the clone games (Clone Engine, Clone Friends) are bright sandboxes. Our difference is **a face plus glowing cyan copies of the same character at night**: nobody in either row shows "many of me" in a heist. We couldn't load the competitors' icon images from this session (the image CDN was blocked), so the owner does the row test in §7 with real screenshots.

---

## 3. Icon brief

**Concept:** the Rookie's face (no mask), smug side-eye at the viewer, with **two cyan copies of the same head fanned out behind him**, on Ink Indigo with the warm glow of the vault dial behind his head, one gold glint, **no text**. Santa hat from Dec 3 to Jan 4 (MASTERPLAN §9.4).

### 3.1 Composition (1024 × 1024 master)

```
+--------------------------------+
|                                |
|    c2      c1                  |   c1, c2 = cyan copies of the head,
|   (  )   (  )   .--------.     |   offset ~8 % of the width each,
|    ''     ''   ( Santa hat)    |   up and to the left, older = dimmer
|        . o O(  -  o  )O o .    |   halo = vault dial ring glow (warm)
|       (    ( smug  side )   )  |   behind the head, partly cropped
|        ' o  (   eye     ) o '  |
|              \  ~~~  /    *    |   * = gold glint (bar edge), near
|           ____\_____/____      |       the eye line, <= 4 % of area
|          /  scarf   scarf \    |
|         /                   \  |   subject (head + copies + shoulders)
|________/_____________________\_|   = 60-80 % of the frame; shoulders
+--------------------------------+   break the bottom edge
```

| Item | Spec |
|---|---|
| Subject | Head and shoulders of the Rookie, **60-80 % of the frame**, face in the upper-middle (eyes ~38-42 % from the top), turned 3/4 toward the viewer, eyes to the viewer (side-eye smirk) |
| The twist | **2 cyan copies** (not 3: at 64 px a third becomes noise) of the same head, each offset ~8 % of the width up-left and a little smaller (they stand behind), the in-game clone look (opaque glow rig, outline) with the age ramp. Faces on clones are stripped in the game, so the copies are smooth cyan heads: that is the read ("ghosts of me") |
| Background | Ink Indigo field, a soft Plum Slate radial behind the head, the **vault dial ring** (in-game Neon, Warm Marble `#D8C8A8` glow) as a halo partly behind the head |
| Accent | One Heist Gold glint: the loot he holds at shoulder height (every loot item carries the gold sparkle shape, STYLE_BIBLE §1), with the sparkle near the eye line on the right. If no loot can be in his hand in the capture, leave the glint out: never paint one in |
| Christmas (Dec 3 - Jan 4) | A **catalog Santa hat** (accessory type **Hat**, red/burgundy with a white snow trim) on the Rookie **in place of the cap**: hair + this hat are the 2 pieces a clone rig keeps, so the copies show it as a cyan hat silhouette. **Not** the in-game `Hat_Santa`: that is a clone-only cosmetic (`cloneHat` slot, 25 Candy Canes, `Config.Data` Cosmetics), so the live hero can't wear it. The snow trim matters: Ribbon Burgundy alone is only 0.14 luma above Ink Indigo, below the 0.15 step |
| Evergreen (from Tue Jan 5) | Same capture without the hat (shoot both versions in the same session) |
| Text | None (vault: text at icon size is noise; one icon per locale, so text-free works for Danish too) |

### 3.2 Pass criteria (before upload)

- [ ] **64 px greyscale:** the face, the two copies and the background are three separate values. Numbers: copies (cyan luma 0.77) vs background (0.13-0.22) ≥ 0.15; face vs background ≥ 0.15 (depends on the avatar's skin tone: if it fails, the warm halo goes directly behind the face).
- [ ] Viewed at **150, 100, 64 and 48 px** on a real phone (light and dark app theme), with the vault's icon-test snippet in Studio (*Game Icon Design*, "Test at real sizes").
- [ ] Nothing important in the corners; no thin details (scarf fringe, hair strands) carrying the read.
- [ ] **Row test:** pasted into a row of screenshots of the current top results for `heist` and `clone` at the same size: the eye lands on ours, and ours is the only "copies of a face".
- [ ] **Stranger test:** shown for 2 s to someone who hasn't seen the game: "what do you think this game is about?" Good: "robber / clones / copies of himself". Bad: "ghost game", "puzzle".
- [ ] Owner (style owner) signs it off at 64 px (MASTERPLAN §10.3 #10).

### 3.3 Exact capture setup (icon)

| Step | Do |
|---|---|
| Where | **L6 The Big Score: Bank**, the scale room, facing the **vault door** (door plane at z -48). The dial is on the door face, 3.6 studs above the floor (STYLE_BIBLE §7 anchor T) |
| Avatar | The Rookie outfit + the smug face; for the Christmas version swap the cap for the catalog Santa hat (Hat type, §3.1). At most 2 hair / hat accessories in total, or a copy drops one |
| Clones | The vault door must stay **closed** (the dial is on it), so the path is lobby → staff door → hall → laser grid → scale room. Wait for every crossing beside the staff door in the lobby (x -4, z -11), out of Gus's sight. **Run 1:** stand on plate A (behind the teller desk, through the counter gate; holds the staff door), END there. **Run 2:** at **0:05.3** go through the staff door to plate B (under the fern, just inside on the west; turns the hall grid off), END there. **Run 3 (copy 2):** at **0:06.0** cross the hall and the (now dark) grid into the scale room and stand at (x -2.4, z -44.5): 2.4 studs left of the dial's centre line and 1 stud closer to the door than the hero mark; face +z (toward the arch), END at about 0:14. **Run 4 (copy 1):** the same to (x -1.2, z -44.0), END. **Run 5 (hero):** grab the lobby drawer cash (x 12, z -9, through the counter gate: its sparkle is the gold glint), wait beside the staff door, cross at **0:06.0**, stand on the hero mark (x 0, z -43.5: the dial's centre line, 4.5 studs in front of the door), face +z, then the freecam (you stand still). Crossing windows from beside the staff door (sim): **5.2-7.8 s**, then about every 9 s (9.4-16.8 s); a crossing outside them is caught. Gus paces the hall, not the scale room, so the room is quiet. Run budget: Dawn at run 8, the heist only completes on the gold: never touch it |
| Camera (`CAM_ICON`) | Freecam 6 studs in front of the hero's face, **at chin height**, pitched up 3-5° so the dial ring sits behind the head; FOV **30**; the head + two copies fill the centre square |
| Lighting | The project's "Heist Night" as shipped; no extra lights (truth rule). A light DepthOfField is allowed (the game uses it in menus and the reel): focus on the face, far intensity ~0.3 |
| HUD | Off (CLIPS.md §3.2) |
| Capture | Record a few seconds at the highest resolution (2560 × 1440 or more) and grab the best frame; crop a square around the subject; downscale to 1024 × 1024 |
| Finish | Levels (hero above mid-grey), 10-20 % vignette, light sharpen after downscale. No shape changes, no added glow beyond what the game shows |
| Files | `docs/marketing/art/YYYY-MM-DD_icon_xmas_v1.png` and `_evergreen_v1.png`, with the camera CFrame and FOV in a `.txt` next to them |

### 3.4 Icon schedule

- Draft from the golden room by **Fri Nov 27**, owner sign-off by **Mon Nov 30**, uploaded (private) by **Wed Dec 2**. The full capture calendar for the icon and T1-T5 is in §4.0.
- Christmas version live **Thu Dec 3** → evergreen version **Tue Jan 5**.
- No other icon changes in December. An icon change is a **time-sliced** test (14 days A, 14 days B, only trust a 30 %+ difference, not in update weeks, not during a thumbnail round; vault *A-B Testing* §5). Keep a dated archive with the metric window of each version.

---

## 4. Thumbnail briefs T1-T5

Each brief: the promise, the sketch (64 × 16 characters ≈ 16:9; `·` = corners, the dashed line = top of the bottom 18 %), what it tests, and the exact capture setup. Times are elapsed run time; positions are level coordinates (CLIPS.md §4 explains them and the run budget). A still where the hero stands on a mark can use the freecam; a still where the hero walks needs the pinned camera (CLIPS.md §3.2 #4) or a 60 fps recording of the follow camera.

### 4.0 Capture calendar (everything the Dec 3-6 Plays test needs is shot by Sun Nov 29)

| Image | Session | Date | Needs | Feeds |
|---|---|---|---|---|
| Icon (both versions) | own session | **Fri Nov 27** | L6 | sign-off Nov 30, upload Dec 2 |
| T3 | own session (same day) | **Fri Nov 27** | L4 (Christmas-dressed version again on Dec 1) | Home pool + Plays test |
| T5 v1 | own session | **Fri Nov 27**, or **Tue Dec 1** (C4) if the dressing isn't visible in Studio yet | DV04 on demand (or the L4 fallback), dressing layer | Home pool + Plays test |
| T1, T2 | **C3** (CLIPS.md §7) | **Fri Nov 27** | L5 Clone Party, the same set-up as F2-B | Plays test |
| T4 | 4 **test accounts** in one party | **by Sun Nov 29** **[UNVERIFIED: that 4 local Studio test clients can form one party; try it on Nov 27]** | L5, 4 clients | Plays test, if shot in time |
| T4 (fallback) | **C5 friend session** | Dec 4-5 | 3 friends + permissions (LAUNCH_CHECKLIST appendix B) | **not** in the first Plays test; joins the next ad round and the Home pool later |

Ad creatives are uploaded on **Mon Nov 30** (LAUNCH_CHECKLIST) for the Dec 3-6 Plays test, so anything not shot by Nov 29 sits that test out.

### T1 "8 OF ME": the swarm promise

```
+----------------------------------------------------------------+
|·                                                              ·|
|                                  ##  8 OF ME  ##               |
|                                                                |
|         ___                  c        c        c   (lit toy    |
|        /cap\                   c      c      c      aisles)    |
|       ( -o  )  smug              c    c    c                   |
|        \___/                       c     c                     |
|      __/scarf\__   *$                 V of 7 clones, each      |
|     |  HERO    |--[bag]               holding stolen toys,     |
|     |  (live)  |                      smaller toward the back  |
|     |          |                                                |
|- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - |
|      (floor, soft)                                             |
|·                                                              ·|
+----------------------------------------------------------------+
```

| Item | Spec |
|---|---|
| Promise | "Solo, there can be 8 of you." The game's own **"8 OF ME"** stamp (Clone Party run 8) is the text, so it is real UI text |
| Hero | The live Rookie at the **left third**, waist up, ~35 % of the frame, smug, holding the till's cash bag with a gold sparkle |
| Secondary | 7 cyan clones in a V receding to the right, each holding a toy, candy or teddy; the lit aisles behind |
| Text | `8 OF ME` upper right ("8" in Clone Cyan) |
| Tests | **The swarm promise.** Hypothesis: "copies of one robber" beats the seasonal promise (T5) for new players once the first session delivers it. Variable vs T5: subject (swarm vs Christmas). **Gate:** goes into the Home pool only after SwarmSeen ≥ 60 % by minute 10 (analytics); before that it runs in the Plays ad test only |
| **[DECISION] Location** | MASTERPLAN §9.4 says "hero with gold, vault light". In the Big Score, 4 of the 7 clones must stay on the 4 vault plates (2 of them out of sight in the lobby and hall), so only 5 copies could be in frame. **Clone Party** shows all 8 and is where "8 OF ME" really happens (minute ~8). A Bank variant (T1-B: 8 of you at the Crew Line-up by the van after the Big Score) is a later single-variable test |

**Capture setup T1**

| Step | Do |
|---|---|
| Level | **L5 Clone Party**, solo, Rookie, HUD off |
| Runs 1-7 | Each run: grab one item from a different shelf (front rows z -8 candy, mid z -14 toys, back z -20 teddies), bank nothing, walk to your V mark in the shop's front area and END there (by about 0:12) **holding the item, facing the entrance (+z)**. V marks (x, z): `(-2.5, 0)`, `(2.5, 0)`, `(-5, -2.5)`, `(5, -2.5)`, `(-7.5, -5)`, `(7.5, -5)`, and the 7th centred behind at `(0, -4)`. The apex (hero) is `(0, 3)` |
| Run 8 | "8 OF ME" stamps in at 0:01.5. Walk to the till (x -8.5, z -1) with **empty hands** and wait: it is **time-locked until 0:20** (`Config.Levels.PARTY_TILL_OPENS_SECONDS`; an earlier grab is refused). Grab it at 0:20: the alarm starts (red beacons; Gus wakes in the back office and comes up the aisles: about halfway, near x -3, z -17, at 0:21.5 in the sim). Walk to the apex `(0, 3)` (about 0.6 s), face the camera. Capture between about **0:20.6 and 0:21.8**, while Gus is still in the aisles |
| Run budget | Clone Party: Dawn after run 8, all 8 runs needed, so one image set per heist (~5 min) |
| Camera (`CAM_T1`) | Freecam 10 studs in front of the apex (z ≈ 13, by the door), 1.5 studs to the right, at 4.5 studs height, FOV **40**: the hero's face on the left-third line ~35 % from the top, the V spreading back to the right |
| Capture | 60 fps recording at the highest resolution; pick the frame where the hero's face is clear and the beacons are at the edges, not on a face |
| Takes | 3 distances (8, 10, 12 studs): dolly the freecam from 12 to 8 studs during the 0:20.6-0:21.8 window and pick frames, or one distance per heist. Without the alarm beacons: a separate heist where the hero holds a shelf item instead of the till cash. That is the next test round (vault *Making Thumbnails* §5) |
| Alt text | `Eight copies of the same robber, seven of them glowing clones, stealing toys from a shop at night.` |

### T2 "BETRAYED!": the clone-betrayal emotion

```
+----------------------------------------------------------------+
|·                                                              ·|
|    ##  BETRAYED!  ##                                           |
|                                                                |
|   (red beacon)                            .-----.              |
|        c  <- clone at the till,          ( O  O )  shocked     |
|       /|\    cash in hand                 ( 'o' )  face, lit   |
|      [till]                      GUS    __/scarf\__ in amber   |
|                                 (torch)>>>>>>  HERO   |        |
|                                  small,   |  (live)   |        |
|                                  behind   |           |        |
|                                           |           |        |
|- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - |
|                                                                |
|·                                                              ·|
+----------------------------------------------------------------+
```

| Item | Spec |
|---|---|
| Promise | "Your own clone can ruin your plan" (Mistakes are content, pillar 2) |
| Hero | The live Rookie at the **right third**, ~35 %, with a **shocked face** (a catalog face swap for this capture: any avatar may wear it), lit by Gus's amber flashlight cone |
| Secondary | A cyan clone at the till, cash bag in hand, under the red alarm beacon (left third, mid-ground); Gus small behind the hero in the aisle |
| Text | `BETRAYED!` upper left |
| Tests | **Emotion + betrayal.** Hypothesis: a shocked face + "my clone did it" beats the calm comedy of T3. Variable vs T3: the emotion and who the threat is. Runs in the Plays ad test first; enters the Home pool when the pool can hold 3+ |
| **[DECISION] Truth** | The plan's "a clone pressing the alarm": the game has no alarm button. What trips the alarm is **grabbing the top loot**, so the clone is shown robbing the till under the beacons |

**Capture setup T2**

| Step | Do |
|---|---|
| Level | **L5 Clone Party**, solo, HUD off, shocked face on the Rookie |
| Run 1 (traitor) | As CLIPS.md F2-B: rob one shelf item and **bank it** (the till needs empty hands at bag level 0), be at the till before 0:20, **grab it at about 0:20.5** (it is time-locked until 0:20), stay next to the till facing into the shop, END at about 0:22 |
| Run 2 (hero) | By 0:20 stand at the front end of the east aisle (x 4, z -6) facing the shop entrance. At 0:20.5 the alarm trips (your clone). Gus comes out of the office and straight up the aisle toward the nearest robber he can see (sim: he chases you from 0:20.6 and catches you at about 0:22.4). Stay put so he picks you; if a take misses, Undo and play run 2 again (each take costs a run; Dawn at run 8 leaves 6). In C3 this is run 4 of the F2-B heist (after its two takes) |
| Camera (`CAM_T2`) | Freecam near the door on the east side (x 6, z 4), height 3.5, looking back into the shop (toward x -2, z -10), FOV **45**: hero at the right third, the till and clone at the left third, Gus small in the aisle behind the hero |
| Moment | Gus 6-14 studs behind the hero in the aisle, his cone on the hero: about **0:21.5-0:22.2** (sim); his "!" pop above him is fine (real UI) |
| Alt text | `A robber lit by a guard's flashlight looks shocked as his own glowing clone robs the till and sets off the alarm.` |

### T3 "WRONG ONE!": the guard comedy (launch, Home pool)

```
+----------------------------------------------------------------+
|·                                                              ·|
|   ##  WRONG ONE!  ##                        (?)                 |
|                                          .------.              |
|                                         ( GUS   )  double-take |
|                                          \ o_O /   face        |
|     .--.                         c  <<<<<<<|=|  torch (amber)  |
|    (-o  )  smug, tiptoe          /|\ busted |  |  on the clone  |
|    /|bag|\  (left third,         / \ clone, |__|               |
|     /   \   mid-ground)             glitching  big, right      |
|  safe-room door behind                          third, ~35 %   |
|                                                                |
|- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - |
|                                                                |
|·                                                              ·|
+----------------------------------------------------------------+
```

| Item | Spec |
|---|---|
| Promise | "The guard catches your clone while the real you gets away" (the threat with a face + clones as decoys) |
| Hero | **Gus** at the **right third**, ~35 %, frozen in his real 2.0 s "huh?" double-take, the "huh?" bubble above (in-game UI), flashlight cone on the clone he just busted |
| Secondary | The busted cyan clone in the cone (centre), flickering into tape ribbons, and the live Rookie at the left third, smaller, stepping out of the safe-room door with the night-deposit bag, smug |
| Text | `WRONG ONE!` upper left |
| Tests | **The guard comedy** vs the seasonal T5 (the launch pair). Variable vs T5: Gus + decoy joke vs Christmas. This is the plan's "Gus as a character" positioning (§9.1) |
| **[DECISION] Truth** | MASTERPLAN §9.4 says "Gus holding a clone by the collar" and "the diamond". The game has no collar grab (Gus freezes with "?" and the clone glitches into tape ribbons) and **no diamond in the six launch levels** (loot is cash, toys, gold and presents). So: the real double-take pose, and the hero carries L4's **night-deposit bag**. If a diamond is added to a level later, a T3 variant with it becomes a single-variable test |

**Capture setup T3**

| Step | Do |
|---|---|
| Level | **L4 Night Clerk** (Christmas-dressed version from Dec 1: Gus wears the Santa hat; shoot both) |
| Runs 1-3 | Exactly CLIPS.md §4.4 (F4): run 1 holds plate A (back-room door), run 2 hides on plate B under the coat rack (safe-room door), run 3 is the decoy standing at (x 2, z -24), caught at about 0:18.6 when Gus turns west and walks toward it |
| Run 4 (hero) | As F4's hero: cross at 0:06.6 while Gus faces the till, grab the night deposit (x 0, z -42) and wait just inside the safe room (x 1.5, z -39). When Gus busts clone 3 (about 0:18.6) he freezes at about (x 9, z -28) facing the spot where it stood (west-north-west), vision paused: step out of the safe-room door (z -36) with the bag and walk north past him. The same heist gives F4's takes (runs 4-6, Dawn after run 6) |
| Camera (`CAM_T3`) | **Pinned** (the hero walks; CLIPS.md §3.2 #4), on Gus's line of sight so his face points at the lens: low (2.5 studs) in the back room's west part, about (x -6, z -31), looking toward his freeze spot (x 9, z -28), FOV **45-50**: Gus at the right third, the clone in his cone in the centre, the safe-room door at the left edge. Check the framing once with the freecam before you pin it |
| Moment | 0.15-0.35 s after the bust (about 0:18.75-0:18.95): the clone still flickering in its tape burst (it is gone 0.35 s after the bust), "huh?" up, the hero in the safe-room doorway with the bag. Record 60 fps and pick the frame |
| Alt text | `A night guard with a big flashlight stares at a glowing clone he just caught, while the real robber sneaks past him with a bag of cash.` |

### T4 "16 ROBBERS": the friends promise

```
+----------------------------------------------------------------+
|·                                                              ·|
|                       ##  16 ROBBERS  ##                       |
|                                                                |
|                m  m  i  i  w  w  c  c  m  i  w                 |
|     .--.     m  M  i  I  w  W  c  m  i  w   (4 colour crews,  |
|    (-o  )     m  i  w  c  m  i  w            synchronized     |
|   __/  \__      ..one mass, same pose..       victory pose)   |
|  |  OWNER |                                                    |
|  | (cyan  |          [ VAN ]                                   |
|  |  crew) |                                                    |
|  |        |                                                    |
|- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - |
|                                                                |
|·                                                              ·|
+----------------------------------------------------------------+
   c = Clone Cyan (owner), m = Magenta, i = Indigo, w = Ghost White;
   capitals = the 3 friends (live), lower case = clones
```

| Item | Spec |
|---|---|
| Promise | "With friends, 16 robbers in one heist" (pillar 5; the thing jams and Rewind Robbers can't do, §9.1) |
| Hero | The owner's Rookie at the **left third**, ~30-35 %, at the front of the line-up |
| Secondary | The other 15 as **one mass** in 4 hues with their glyph badges (●1 ■2 ▲3 ◆4), all in the same synchronized pose. The vault rule "no five-character line-ups" is about separate characters; here the crowd reads as one shape |
| Text | `16 ROBBERS` upper centre |
| Tests | **The social promise.** Hypothesis: "16 robbers with friends" pulls friend groups (sessions with a friend ≥ 20 % KPI). Variable vs T1: one player's swarm vs four players' crowd. Plays ad test first; Home pool when it has 4-5 slots |
| **[DECISION] Moment** | The **Crew Line-up** (every clone of every crew member + the players walk to the van and strike one synchronized pose, MASTERPLAN §3.2 #8): it exists in every heist, so the shot is always reproducible and every one of the 16 is in frame (in the Big Score's vault, 4 clones would be stuck on plates out of shot) |

**Capture setup T4**

| Step | Do |
|---|---|
| People | Owner + 3 friends with written permission (LAUNCH_CHECKLIST appendix B); or 4 test accounts. If friends use their own avatars, that's fine with their OK; name tags off on every client (CLIPS.md §3.2) |
| Level | **L5 Clone Party** with a party of 4 (cap per player `floor(12 / 4) = 3`, so 4 players + 12 clones = 16), or L6. Run budget: Dawn is **run 8**, so every player plays 8 runs (any jobs; END early to save time): runs 1-3 fill each deck, runs 4-8 each replace that player's newest clone, so the count stays 3 each (sim: run 8 has 16 robbers). The heist then ends into the Crew Line-up (~4-5 min in all) |
| Camera (`CAM_T4`) | Low (2.5 studs) on the street about 12 studs in front of the Line-up (it stands at z 28, facing the street, so the camera is at about z 40 looking back at the shop), FOV **50**, the owner front-left, the crowd and the van behind |
| Moment | The apex of the victory pose (60 ms stagger per clone in record order, so wait until the last clone hits it) |
| Alt text | `Four friends and twelve of their glowing clones, sixteen robbers in four colours, pose together in front of their getaway van.` (shot with 4 test accounts: `Four players and twelve of their glowing clones, ...`) |
| When | By Sun Nov 29 with 4 test accounts if that works, else the Dec 4-5 friend session: then T4 is not in the first Plays test (§4.0, §6) |

### T5 "STEAL BACK XMAS": the seasonal promise (launch control)

```
+----------------------------------------------------------------+
|·    (fairy lights, warm white)                                ·|
|                                       ##  STEAL BACK XMAS  ##  |
|                                                                |
|       .--.             |  back-room   |                        |
|      (Santa)   smug     |  doorway     |   (garland / lights   |
|      ( -o  )            |  GUS (Santa  |    on the front-room  |
|    __/scarf\__   c  <- clone  hat), small, facing   walls)     |
|   |  HERO   [PRESENT]  /|\[gift]  the east wall                |
|   | (live)  |  big,     / \                                   |
|   |         |  ribbon                                          |
|   |         |                                                  |
|- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - |
|   (garland, snow cap on the counter)                           |
|·                                                              ·|
+----------------------------------------------------------------+
```

| Item | Spec |
|---|---|
| Promise | "Steal the presents back: a Christmas heist with your clones" (§4.3) |
| Hero | The Rookie in a **catalog Santa hat** (Hat type, in place of the cap, §3.1: the in-game `Hat_Santa` is clone-only), left third, ~35 %, carrying the big wrapped present toward the camera |
| Secondary | A cyan clone right behind him with the second present (its silhouette wears the hat too); through the doorway, Gus in his Santa hat small in the back room, facing the other way; the dressing layer's garland and warm-white lights on the front-room walls if the layer puts them there. **No tree in this shot:** DV04's tree hide (x -15.5..-10.5, z -26.5..-21.5) is behind the z -20 wall, out of view through the 6-stud doorway (a back-room angle would show it but puts Gus right by the camera) |
| Text | `STEAL BACK XMAS` upper right (3 words, "XMAS" in Clone Cyan) |
| Tests | **The control at launch** (the event promise). Hypothesis: the seasonal promise wins Dec 3 - Jan 4 for new players. It is the baseline every other thumbnail is compared with |
| **[DECISION] v1 vs v2** | **v1 (Dec 3)** shows only launch content: a Christmas daily vault, presents, the dressing layer, Gus in a Santa hat. The growth report's "Snow Globe Vault cracked open, Sir Hoardsworth furious" is the finale (Dec 18) and Hoardsworth has no model yet, so that is **v2**, shot from the finale build once it exists, and swapped in on Dec 18 as a single change |

**Capture setup T5 (v1)**

| Step | Do |
|---|---|
| Level | **Daily vault 4 "Mistletoe Patrol"** (`DV04`): one plate (A, x 10, z -8) holds the back-room door, Gus paces the back room, a Christmas tree to hide behind, the big **Present** at (0, -34) and the **Ribbon** present at (-12, -34). Needs the capture build to load DV04 on demand (owner kit item 1; otherwise it is the daily vault only on its advent date). **Fallback:** the Christmas-dressed L4 Night Clerk (Gus in a Santa hat, the night-deposit bag, no presents: weaker) |
| Dressing | The Christmas layer on (server date Dec 3+, or the capture build's override) |
| Run 1 | Stand on plate A, END there |
| Run 2 | Wait beside the back-room door in the front room (x -5, z -12). When Gus passes the middle of the back room walking **east** (about 0:05.3; he stands at the east end facing the wall until about 0:09.3), go in, grab the Ribbon present, come back out and END just inside the front room behind the hero's path (x 1.5, z -18.5), holding it |
| Run 3 (hero) | Same window: grab the big Present (x 0, z -34), walk out through the doorway toward the camera (out by about 0:08 in the sim) |
| Run budget | A daily vault: Dawn at run 6; banking the Present meets the goal and ends the heist at the end of that run, so END before the van (Undo between takes: runs 3-6 give 4 takes) |
| Camera (`CAM_T5`) | **Pinned** (the hero walks), in the front room ~9 studs in front of the back-room doorway (z -20, so about z -11), height 4, looking back through the doorway, FOV **42**: hero at the left third coming toward the camera, the clone behind him at the doorway, Gus small in the back room through the doorway |
| Moment | The hero about 4 studs out of the doorway (z ≈ -16), face and present both clear, the clone with the Ribbon behind |
| Alt text | `A robber in a Santa hat carries a big present out of a shop at night while his glowing clone carries another one and the guard looks the other way.` |

---

## 5. Event and video thumbnails

| Image | What | When |
|---|---|---|
| **E1 event images** (Steal Back Christmas: The Wrapping Room) | Up to 5 per event. At submission (Dec 3-4) use **T5 + T1-style Christmas Clone Party shots only**: featuring submissions can't be edited later, and the Wrapping Room is built in launch week (MASTERPLAN §10.2 W4), so it can't be shown on Dec 3 unless it is real by then **[DECISION]** | Ready Wed Dec 2 |
| **E2 event images** (The Snow Globe Vault) | The real finale vault with 8 of you around the Giant Present, text `SNOW GLOBE VAULT`, **only if the finale build is capturable by the submission date**; else T5 v1. **[DECISION]** Submit E2 by **Fri Dec 11** at the latest (7 days before Dec 18), not Dec 10, to give the finale build one more day | Fri Dec 11 |
| **Video thumbnail v1** | 15-30 s of real gameplay from the golden room (the bank vault door opening as 4 clones hold the plates; a clone fail), varied angles, in-game UI text only, no narration, no music with lyrics. Upload by **Sun Nov 22** to the live experience (reviews can take weeks) | Nov 22 |
| **Video thumbnail v2** | Christmas Clone Party: the tape print of 8 of you and the Crew Line-up. Keep 1 of the 3 monthly uploads spare for a rejection | Mon Dec 7 |

---

## 6. Which images are active, by date

| Date | Home pool (personalisation) | Details page gallery (order) | Ads (creative set) |
|---|---|---|---|
| **Thu Dec 3** | **T5 + T3** | Video v1 (if approved) · T5 · T3 · 3 plain screenshots, no text: L1's first clone with the real "◀ YOU, 10 SEC AGO" label, Clone Party aisles with clones, the bank vault with 4 clones on plates | Plays test (Dec 3-6): **T1, T2, T3, T5**, plus **T4** only if it was shot with 4 test accounts by Nov 29 (§4.0). Engagement: T5 + T3 + T1 |
| SwarmSeen ≥ 60 % by minute 10 confirmed | **+ T1** (3 active) | + T1 after T3 | — |
| After the Dec 4-5 friend capture (if T4 wasn't shot by Nov 29) | unchanged | — | T4 joins the next ad round (a new Plays campaign or the Engagement set), never as a mid-test change |
| Fri Dec 11 | unchanged (don't start a round on an update day) | + one Wrapping Room screenshot (the "new thing") | + Wrapping Room screenshot |
| DAU > 1,000 for a week | Up to 5: T5 (control) + T3 + T1 + the ad-test winner of T2 / T4 | — | — |
| Fri Dec 18 | T5 v1 → **T5 v2** (one change) | + the finale screenshot | — |
| **Tue Jan 5** | Remove T5; keep T3 + T1 (+ T2 / T4); the Museum teaser image comes later | Remove Christmas images | Christmas creatives off |

Rules: keep a control in every round; one variable per pair; 7-14 days per round; never delete a loser, it may win a segment; note every change in a dated log (vault *A-B Testing*).

---

## 7. Review before upload

1. **Gates:** G1 truthful (tick each element against the build: avatar, clones, Gus, loot, UI text, dressing), G2 policy-safe (§1). Any fail = don't upload.
2. **Score the 10 criteria** (vault *Thumbnail Review Checklist* §3: focal subject, small-size readability, value contrast, genre clarity, emotion/action, text discipline, safe area, brand consistency, novelty in the row, clutter): upload at **8.5+**, fix the lowest at 7-8, re-shoot at 5-6.5.
3. **Size tests:** 320 × 180 and 160 × 90, greyscale, a blur of ~1 % of the width: the hero and the promise still read.
4. **Row test** among the current top `heist` and `clone` tiles.
5. **Stranger test** (1 s): "what do you do in this game?" Must hear heist / rob / steal / clones. "Puzzle" is a fail (MASTERPLAN risk 5).
6. File: `docs/marketing/art/YYYY-MM-DD_T3-wrong-one_v2.jpg`, with the layered source and the camera preset (CFrame + FOV) saved next to it; alt text pasted on upload.

---

## 8. Decisions and open questions

**Decisions made here:** a catalog Santa hat (Hat type) on the live hero, because `Hat_Santa` is clone-only; the scarf is a live-hero trait (§2, §3.1); every image that feeds the Dec 3-6 Plays test is shot by Nov 29, T1 and T2 in C3, T4 with test accounts or out of the first test (§4.0); T5 v1 without the tree (out of view from the doorway camera); T1 in Clone Party, not the Bank (§4 T1); T2 shows the clone robbing the till (no alarm button exists), timed to the 0:20 till lock; T3 uses the real double-take and the night-deposit bag (no collar grab, no diamond at launch); T4 at the Crew Line-up; T5 v1 without Hoardsworth or the Snow Globe Vault; E1 images limited to launch content; E2 submitted by Dec 11; 2 clone copies on the icon; free-licensed rounded font for text.

**Open questions:**
1. Who stages the captures, and when does the owner kit's "freeze at t" and level jump exist (T5 needs DV04 on demand)?
2. The Rookie's face: which catalog face gives the smug side-eye at 64 px? (Owner picks 2-3 candidates; the icon stranger test decides.)
3. Sir Hoardsworth: will he exist in the game (a model, a portrait in the bank) by Dec 18? Until then he is not shown in any image.
4. Is a diamond planned for any launch or December level? If yes, a T3 variant with it can be tested.
5. The owner confirms the Alarm Red value (`#FF3838`, STYLE_BIBLE §11) before beacons appear in T1 / T2.
