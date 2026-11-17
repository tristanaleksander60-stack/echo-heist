# Why "Heist Yourself" reads as 2/10

_Game director and art director review, 2026-11-17. Live build v152. Research only: no game code changed._

## Til ejeren (dansk resumé)

Du har ret. Spillet ser billigt ud, og der er for lidt spil. Det er ikke ét problem, men fire.

1. **Billedet er overbelyst og tomt.** På dit eget skærmbillede er 21 % af billedet helt hvidt, og 3/4 af skærmen er gulv og loft i et lille kasserum. Alle farver er flade, uden tekstur.
2. **De første minutter har ingen fare og ingen belønning, man kan mærke.** Bane 1 slutter din første runde efter 2 sekunder på pladen. Bane 1 og 2 har ingen vagt og ingen alarm. Vagten (Gus), der er på thumbnailen, møder man først i bane 3-4. Kun 7-10 % af spillerne nåede så langt.
3. **Der er intet at samle og intet at komme tilbage for.** Hele kampagnen er ca. 25-35 minutter. Der er 4 ting at købe for in-game penge. Alle 6 Robux-produkter har id 0, så ingen *kan* købe noget. Den daglige vault åbner først efter bane 4.
4. **Spillet tog sin egen bedste idé væk.** Idéen var "dine kloner er DIG, din egen Roblox-avatar". Nu er alle en fast figur (the Rookie) i førstepersonsvisning, så du ser aldrig dig selv, og klonerne er en fremmed mand.

Det kan reddes, men ikke med flere scripts og flere tests. Det kræver rigtige kunstnere (karakter, animation, musik), at man starter direkte i et røveri med en vagt og en jagt fra sekund 10, at man ser sin egen avatar i tredjeperson, og et samle- og opgraderingssystem, så børn har en grund til at komme tilbage. Første skridt (2-3 uger) bringer spillet til omkring 6-7/10. 8,5/10 kræver 2-3 måneder og et budget til freelancere.

---

## 0. Evidence used, and how much to trust it

| Source | What it is | Weight |
|---|---|---|
| `docs/audit/why_2_of_10/capture_11_run1.jpg` (owner capture 11, 1891 x 1014) | Live client, first person, run 1. **It is L2 Two Doors, not L1**: the HUD reads `$0 / $200` and L2's `goal = 200` (`src/shared/Levels/L2_TwoDoors.luau:30`); L1's is 100 (`L1_BackRoom.luau:30`). It shows two plates and the L2 objective line. | Highest |
| `capture_12_hand.png` (568 x 208) | Live close-up of the first-person glove | Highest |
| `capture_10_intro.jpg` (1725 x 967) | Live: the intro caption over the van-door wipe | Highest |
| `older_captures_5-9.jpg` | Earlier owner captures (Pick a Tape menu, L1 diorama, Heist Complete card, Run 6 deck, giant FP sleeves). The build version is unknown. | Medium |
| Blender renders (`docs/audit/blender_look/`, `levels/golden_fp/`, `marketing/final/`, turntables) | Offline approximations | **Low.** §2.3 shows why: they report 0.0 % clipped where the live capture is 21 % clipped. |
| Funnel (PROJECT_STATE.md lines 668-669) | 129 live profiles, games API | High |
| Sim pacing (`lune run tests/run_sim.luau`, printed `[model]` lines) | Bot and modelled kid timings | Medium (bots are not kids) |

I measured the captures with numpy, using per-pixel thresholds. Pixel areas below refer to the full-size files.

---

## 1. The first 10 seconds: a 10-year-old from a TikTok ad, on a phone

### 1.1 What they actually see

The ad and the thumbnail (`docs/marketing/final/thumb_1920x1080_2_rob-with-clones.png`) promise four things: a glowing cyan clone, a Santa-hat guard with a torch, a fat gold money bag in your hands, and "ROB WITH CLONES". Here is what the game delivers instead.

| t | Frame | Evidence | What the kid feels |
|---|---|---|---|
| 0-5 s | Roblox's own loading screen, then our loading card: a flat navy screen with a turning reel (`Config.Presentation.LOADING`, line 2760). | Capture 10 is the same family: **96.6 % of its pixels are one navy colour** (28, 31, 59). The "van doors" are a 4 px seam and two 10 x 64 px bars (`Config.Presentation.DOORS.HANDLE`); the caption is "SIR HOARDSWORTH WANTS IT ALL." (`Strings.luau:948`) over nothing. | "Is this broken?" A caption that names a villain the kid has never seen, over an empty screen, is the worst opening a story can have. The intro is now OFF (`Config.Intro.ENABLED = false`, line 3707), so the card is all that is left of it. |
| 5-10 s | Spawn in the hideout garage, in first person, at night (`FTUE_AUTOSTART = false`, `Config.luau:275`). | Golden frame G3 (`docs/audit/levels/golden_fp/G3_fp_hideout.png`) is the *best case*: a job board, a van, a dark garage, two mitts at the bottom. To start, the player must look at the board, open it, pick a job, then find a van ("Job picked! Now PICK A VAN.", `Strings.luau:441`). That is two first-person station interactions on two thumbsticks. | No other player is visible (8 private bays, `Config.Hideout.BAYS = 8`). Nothing moves and nothing is worth wanting. **44 of 129 players (34 %) never left this room** (PROJECT_STATE "Funnel check 2"). |
| ~60 s+ | L1 run 1: walk to a plate. Run 1 **auto-ends 2.0 s after you step on it** (`L1_BackRoom.luau:4-5`, `tutorial = { autoEnd ... untilDone = true }` line 52). The next run starts by itself after 0.4 s (`TUTORIAL_BETWEEN_SECONDS`, line 262). | Sim: coached kids bank L1 after a **median of 16.1 s of play** (bot 13.8 s), and L1 is done 1.1-2.0 min after the join. | This is literally the owner's "done in 2 seconds". The first loop the kid is ever given lasts 2 s and is taken out of their hands. There is no guard, no laser, no alarm, no chase and no fail state in L1 or L2 (`grep guards/lasers`: L1 0/0, L2 0/0; L3 lasers only; Gus first appears in play-order level 3, the Party, asleep, and awake in L4). |

**Why they leave:** the first 10 seconds show no danger, no other players, no reward and no "me". Then comes a lobby task. When the kid finally reaches the clone, it is a scripted 2-second demo in an empty room. 21 players saw their first clone and still quit before banking (ftueStep 5 / heists 0). The core "wow" did not land for about 1 in 4 of the people who saw it.

### 1.2 What the top games do in the same 10 seconds

| Game | First 10 s (vault notes, or labelled otherwise) | What we lack |
|---|---|---|
| **Steal a Brainrot** (vault: *Case Study - Steal a Brainrot* §3) | You spawn by your own base on a conveyor of characters with prices over their heads. Other players are already running and stealing. "The first five minutes show the entire game: buy, earn, defend, steal. No tutorial needed because the conveyor itself teaches the economy." | Other players visible at once. A number going up. Something to want (a price tag). Theft taught by having it done to you. |
| **Steal An Egg** (vault teardown, "First 60 seconds") | A treadmill: your speed number climbs. The first egg grab is within a minute and wakes a guardian, so **the first chase teaches the risk without any text.** | Ours has **no chase in the first 2 levels**. Gus is our guardian, and we hide him until L4. |
| **Grow a Garden** (vault §3) | Your own plot, visible to everyone; a carrot seed is affordable; "the first click after spawning can be a purchase... no lobby, no loading into a separate match". | We put a lobby and a two-step menu before the first verb. |
| **Doors** (vault §"First five minutes") | Lobby, but it is social (an elevator with strangers or friends), plus a pre-run shop. The first death within minutes is the tutorial; "the screams make Doors good on video". | Our lobby is solo bays, and our first two levels cannot be failed. No scream, no clip. |
| **Piggy** (vault teardown, "First 60 seconds") | 6-player servers ("you always see every other player"); the hunter's jump scare and chase music are short and loud. | Max players is 20 in the live settings and design is 8, but each crew is in its own instance 3,000 studs away (`INSTANCE_SPACING`). You see nobody. |
| **Heist Evolution** | The vault has no note, and I could not verify its first 10 seconds, so I make no claim about it. The nearest vault reference is *Case Study - Jailbreak*: "Timed, server-wide objectives that bring players together"; "visible possession as progression". | Our heists are private and solo by default, and possessions are invisible. |
| **Phasmophobia-style co-op lobbies** (general genre knowledge; no vault note) | The lobby *is* the fantasy: a van or HQ with the gear on the wall, your friends' avatars standing next to you, and a contract board. You choose a job **together** and drive off in one shared moment. | Our hideout has the props for this (vans, job board, trophies) but none of the social part: you are alone in your bay. |

**Vault rule we break** (*First-Time User Experience and Onboarding*): "Control within about 10 s of join... First verb by 30 s, first big reward by 40 s. Core loop closed three or more times in 5 minutes." We do give control early. But the first verb is a lobby menu, and the first *big* reward (8 OF ME) comes at **minute 8.1-11.9** in the model (`[model] 8 OF ME (party run 8) 8.1 / 10.0 / 11.9`). Only **13 of 129 players (10 %)** got there.

---

## 2. Visual quality, item by item

### 2.1 Art direction coherence

- **What is wrong:** there are three visual languages on one screen. (a) The world: flat-coloured low-poly kit, terracotta and plum, no outlines on level geometry (`BLENDER_LOOK.md`: "Level geometry: none (cost)"). (b) The characters and props: ink-outline cartoon hulls (`Config.Outline`). (c) The HUD: a generic dark-navy "simulator kit" with thick strokes, drop shadows and Luckiest Guy (`Config.Ui.DISPLAY_FACE`, line 2009). On top of that, the warm-pink Christmas street (G1) and the cyan sci-fi clone glow are a fourth tone.
- **Why it reads cheap:** nothing in capture 11 says "heist". Remove the HUD and it is a pink-and-orange sweet shop. There is no motif that runs through world, UI and characters: no blueprint, no tape, no vault, no spotlight. The concept's strongest image, a VHS tape that you rewind, is absent from the world. It exists only as the word REWIND on a cyan button (capture 11, x 1760-1891, y 700-850).
- **Target:** one sentence of art direction that every asset obeys, for example "a cartoon caper at night: cool blue night, warm pools of light, gold loot, cyan tape-ghost clones". Then the HUD borrows its shapes from that world (tape labels, blueprint paper, a vault dial for the timer) instead of from a generic UI kit.

### 2.2 Palette, value and contrast

- **What is wrong (capture 11):** the mean luminance is 0.63, so the whole frame is mid-to-bright with no darks. Mean saturation is 0.35, and 31 % of pixels are above 0.5 saturation, mostly orange, pink and purple at the *same value*. The terracotta walls, the orange checker, the plum skirting and the pink rug sit in one narrow value band. The two pressure plates, which are the gameplay objects, are **white discs on a light floor** (x 540-720, y 545-580 and x 1195-1370, y 545-575) and are among the least visible things in the frame. The brightest, most saturated thing is the pink-and-white diamond rug (x 560-1360, y 660-830), which is decoration.
- **Why it reads cheap:** good kid games are bright but **value-structured**: dark background, mid world, bright interactables. Here the decor outshouts the gameplay, so the eye has no focal point.
- **Target:** keep the world 1-2 value steps darker than the interactables. Plates, loot and clones carry the only saturated, emissive colours (gold, cyan). Decor stays at saturation below 0.4. Run the 160 x 90 thumbnail test (the repo already has `*_160x90.png` tooling) **on real captures**, not on renders.

### 2.3 Lighting and atmosphere

- **What is wrong:** capture 11 has **21.3 % of its pixels clipped to near-white** (all channels above 0.94); 30 % have luminance above 0.9. In the left third (x 0-450) 37 % is clipped and in the right third (x 1450-1891) 28.5 %. The door frame you stand in, the left shelf unit and the ceiling light strips (y 240-300) bloom into white slabs. The same scene in the "Roblox-faithful" Blender preview is graded "clipped 0.0 %" (`docs/audit/blender_look/frames.png`, caption under the L1 tiles), and the LIGHT AND SPRINT pass claims "clipped <= 0.04 % everywhere" (PROJECT_STATE, BLENDER LOOK track).
- **Why it reads cheap:** blown highlights are the most recognisable sign of an amateur Roblox game: Future lighting with near-white albedo, Neon trims and bloom stacked. Worse, **the team's measuring tool says the problem does not exist**, so it will never be fixed by the current loop. The Blender preview models neither the Roblox tonemapper, nor Neon's emissive contribution, nor bloom on near-white SmoothPlastic at close range.
- **Target:** no more than 1 % of pixels clipped in any first-person gameplay frame, **measured on a live client capture** (or a Studio screenshot through the Studio MCP), never a Blender render. Lower the albedo of every white or marble kit cell (`eh_palette`: Warm Marble and Bulb Warm) to a value of 0.75 or less. Give Neon only to bulbs. Make one darker "night interior" recipe where the light pools actually pool.

### 2.4 Materials and textures

- **Fact:** the whole kit is UV-mapped onto **one 256 x 256 atlas of 8 x 8 solid-colour cells of 32 px** (`tools/blender/eh_palette.py:6-14`). Each face samples the centre of one cell (`UV_HALF_PX = 1`), so **every surface is a single flat colour**. There is exactly **one** SurfaceAppearance in the game, `VaultDoor_DialFace` (`KitService.luau:360-467`). `assets/textures/` holds 3 palette atlases and that dial face. There are no tiling textures, no normal maps and no MaterialVariants. The "material" is SmoothPlastic, Fabric or Leather on a flat colour.
- **Why it reads cheap:** brick, wood, tile, cloth and metal all have identical surface response and zero micro-detail. In capture 11 the brick-red ceiling planks, the terracotta wall and the checker floor differ only in hue. On a phone at 6 inches that reads as "made of coloured plastic boxes": the default-Roblox look that kids associate with free models. The baked vertex AO (BLENDER_LOOK) is invisible in capture 11, because the pieces are too large and too flat for vertex AO to show.
- **Target:** stylised textures, not flat cells. On Roblox the cheapest high-impact route is **built-in materials plus MaterialVariant** (Brick, WoodPlanks, Concrete, Metal, Fabric, with stylised colour maps) on walls, floors and ceilings, and **SurfaceAppearance with hand-painted or trim-sheet maps** on hero props. A wall should show bricks, the floor tiles with grout, the counter wood grain.

### 2.5 Silhouettes and prop density

- **What is wrong (capture 11):** the room holds one shelf unit (x 610-815, y 355-530), one fridge (x 1230-1350, y 335-530), one cake stand, a clock, two pendant lamps and a door. That is about 6 props in a room of roughly 32 x 24 studs. The shelf contents are flat-colour rectangles. The ceiling band (y 0-290) and the floor (y 525-1014) together fill **about 75 % of the frame** with two flat planes. The interesting strip is about 1000 x 230 px, roughly 12 % of the screen.
- **Why it reads cheap:** top games are *busy* (Grow a Garden's plots and other players; Brainrot's conveyor). Empty rooms in first person look unfinished. REVIEW_STEAM_PLUS already said "Interiors are empty painted boxes", and "L1-L4 + DV01 share one shell" (`Levels/Shop.luau`: 12-stud walls, the same shell helpers).
- **Target:** three depth layers per view: foreground clutter (boxes, bags, a mop), mid gameplay, and a background silhouette through a window or doorway. Aim for 25-40 props per room, most of them small and cheap. Give each level a different floor plan, not one shell. Use shelving packed with *readable* products (cans, toys, cash bundles), not colour blocks.

### 2.6 Scale (the "huge buildings" request)

- **Fact:** the BIG track made the *exteriors* tall (`Config.Big`, `STOREY = 10`; the G1 street in `golden_fp/G1_fp_spawn.png` is the best image in the repo). But **the gameplay happens indoors** under a 12-stud ceiling (`Config.Big.CEIL_Y = 12`, line 3393; `Shop.luau:4`) with a 5-stud character. In first person, a 12-stud ceiling at FOV 70 means you see the ceiling in every shot (capture 11, top 28 %).
- **Why it reads cheap:** the huge buildings are seen for about 1 second on the street, then you are in a low box. The rooms feel like corridors, not "a heist".
- **Target:** interiors with height variation: a double-height shop floor (18-24 studs), a mezzanine, a vault room with a 30-stud ceiling and a giant vault door. Scale is felt inside, against your own hands and your clones, not on facades.

### 2.7 Character appeal: the Rookie, Gus and the clones

- **The Rookie** (`docs/art/turntables/Rookie.png`): a stocky, middle-aged, big-nosed man in a beige sweater with a bandolier. He is 15 rigid pieces (`Rookie_Head 644 tris`, limbs 120-180 tris), with stiff cylinder limbs, white mitts and a face that is a thin-browed scowl. **He has nothing a 10-year-old wants to be.** He is not cool, cute, funny or customisable in a way that shows (outfit slots: cap, scarf, sweater, gloves, mask, tone; `Config.Rookie.SLOTS`). His 64 px silhouettes (bottom row of the turntable) are a blob with stubs: no hat line, no scarf tail.
- **Gus** (`Gus.png`): better. The cap, moustache, torch and belly read, and the torch gives a clear silhouette. But he shares the Rookie's proportions and the same flat-shaded piece language, so hero and guard look like one family. He is in 3 of 6 levels and reached by fewer than 10 % of players.
- **The clones:** copies of the Rookie with a cyan tint (thumbnail). The concept's unique selling point was **"your own Roblox avatar as the clone"** (`docs/IDEA_ECHO_HEIST.md:30`, "What is ours"). The first-person pivot replaced it: "Your Roblox avatar; clones are copies of it" became "The Rookie... the Roblox avatar is never shown" (`docs/PLAN_FIRST_PERSON.md:15, 49`). **This removed the single strongest hook for Roblox kids, who spend Robux on their avatar and want to see it.** "Eight of ME" with eight copies of a stranger is not "me".
- **Target:** bring back the player's Roblox avatar for you and your clones (the clone pipeline already handled layered clothing, per the PROJECT_STATE clone engine fix). Keep the Rookie as an NPC (the tutorial mentor or the rival crew) or as an optional costume. Gus gets a professional redesign that is more exaggerated, with a readable face at 30 m and real animation.

### 2.8 First-person hands

- **Capture 12:** the glove reads as **a purple-brown faceted lump**. The mean colour is (98, 50, 69): the "Mustard" glove has gone magenta-brown under the lights. There are hard facet breaks across the knuckles (x 280-330, y 40-80) and along the fingers (x 330-440, y 30-130), and the fingertips are polygonal (x 400-440, y 30-60). In capture 11 the hands (left x 330-620, right x 1300-1560, y 880-1014) splay like rubber gloves and add nothing to the action.
- **History:** the hands have been "fixed" in 4 tracks (FP, FP HANDS, FP HANDS v2, BLENDER LOOK), each self-graded at 7.5/10 from Blender previews, while the owner's live verdict stayed "trash" (PROJECT_STATE lines 532-620). Older capture 9 shows sleeves filling half the screen.
- **Why it reads cheap:** procedurally meshed hands (SDF and Surface Nets, `tools/blender/sdf_mesh.py`) at 0.2 scale, vertex-shaded and posed by maths, cannot match a hand modelled and keyed by an artist. Hands are the one asset on screen 100 % of the time in first person.
- **Target:** either (a) **drop first person as the default** (see §2.11), which removes the problem, or (b) commission one rigged, textured first-person arms asset with 6-8 keyed poses from a freelance artist. Do not attempt a fifth procedural pass.

### 2.9 VFX and juice

- **Facts:** every particle effect uses Roblox's **built-in default textures**: coins, gold rain and the clone ribbon fallback all use `rbxasset://textures/particles/sparkles_main.dds`, and the door dust uses `smoke_main.dds` (`Config.luau:1612, 1627, 2737, 3129`). Hit-stop exists but is 0.066 s on 4 beats (`HIT_STOP_SECONDS`, line 3051). The particle budget system (`Heist/Particles.luau`) is more elaborate than the particles it governs.
- **What is missing in capture 11 and the flow:** loot pickup has no "cash explosion", no number pop-up flying into the `$0 / $200` counter, no screen-space coin trail and no camera kick. The clone spawn ("tape print") is the signature moment, and it has a sparkle texture every Roblox player has seen ten thousand times.
- **Target:** a custom VFX sheet of 6-10 flipbooks (tape ribbon, VHS scanline burst, coin burst, cash-note flutter, alarm strobe, laser spark). Every reward gets 3 layers: a world burst, a UI fly-to-counter, and a sound with pitch rising per item in a streak.

### 2.10 UI style

- **Capture 11 HUD inventory:** the Roblox top bar; the cash pill `$0 / $200` (x 10-280, y 60-130); MENU with an `M` chip (x 10-125, y 135-250); the RUN 1 / 0:29 slab (x 730-1190, y 58-135); a `1` clone bubble (x 935-985, y 145-190); an `A` plate marker over the door (x 985-1020, y 270-305); the reticle (x 950-970, y 515-535); the caption (x 585-890, y 850-872); CREW with `Q` (x 1610-1740, y 790-905); REWIND with `R` (x 1750-1891, y 695-850); SLIDE with `Ctrl` (x 1420-1535, y 915-1014). That is **11 elements, 5 of them key-cap chips** (M, Q, R, Ctrl, plus the A letter in the same chip style).
- **What is wrong:**
  - **Fonts.** Luckiest Guy is "the most common Roblox-sim face" (the repo's own review, REVIEW_STEAM_PLUS §1). Builder Sans ExtraBold is Roblox's own UI face. Together they say "default".
  - **Panels.** Dark navy slabs with ink strokes and drop shadows (`Config.Ui.STROKE = 2`, `SHADOW_OFFSET = 4`) look heavy and grey over a bright pink scene. The RUN slab alone is about 460 x 77 px of dead navy at the top centre.
  - **Buttons.** Three different button treatments: a grey CREW, a cyan REWIND and a grey SLIDE that is half off-screen at the bottom (it is cut at y 1014).
  - **The caption** "Two plates. You need two clones." is about 18 px tall, roughly 1.8 % of screen height, white on the orange-and-pink floor. On a phone it is about 9 pt and unreadable.
  - **Key caps everywhere.** On PC they add five white circles that compete with the action. They are hidden on touch (`Hud/Controls.luau:9`), which is correct, but on PC they are permanent.
- **Why it reads cheap:** the HUD is "clean" in the technical sense (`hud_layout 5,634/0` checks), but it has no personality and takes about 10 % of the frame on dull navy boxes. The best Roblox HUDs (Brainrot, Pet Sim) are chunky and colourful, and the *number* is the hero.
- **Target:** a themed HUD (the timer as a tape counter or a vault dial; cash as a stack of bills that grows), no more than 5 always-on elements, key caps shown only until the key has been used once, captions at least 28 px design size with a dark backing, and one bespoke display font picked by a human designer.

### 2.11 Camera and FOV

- **Facts:** first person is the default; `fpFov` is 60-90 with a default of 70 (`Config.luau:1128`). 123 of 129 players stayed in first person and **nobody changed any setting**, so the default *is* the game. Your hands are viewmodel FOV 50 (`Config.FirstPerson.VIEW_FOV`).
- **What first person costs this game:**
  1. You never see your own character, so the avatar and outfit are invisible.
  2. You see clones only when you look at them, and a crew of 8 does not fit in a first-person view (hence the separate hold-to-peek Crew View).
  3. On a phone, two thumbs are needed for look and move, an extra friction for 8-12-year-olds (REVIEW_STEAM_PLUS "Onboarding 35").
  4. The 12-stud rooms fill the frame with ceiling and floor.
  5. The hands are on screen all the time and are the weakest asset.
  6. It does not clip well for TikTok, because the "8 OF ME" beat needs a wide shot.
- **Target:** **third person by default** (the Roblox default camera, slightly raised and pulled back, at about FOV 70), with first person as an option. The game's core image (*many of me, at once*) is a third-person image. Every thumbnail and the G2 golden frame are third person, which proves the team already knows it.

---

## 3. Game design depth: is there enough game?

### 3.1 The core loop's fun, and when the "wow" comes

- The mechanic is genuinely good: record a run, rewind, and your past self does it again. The marketing beat "8 OF ME" is strong. But:
  - **The first "wow" is scripted away.** L1's first clone is made by an auto-ended 2-second run. The kid did not *decide* anything, so the clone is a cutscene, not an achievement.
  - **The puzzle has no pressure for the first two levels.** No guard, no lasers, no deadline ("no deadline", `L1_BackRoom.luau:6`, `L2_TwoDoors.luau:6`). Standing on a plate in an empty room is not a heist. Time-loop games are exciting when the loop is **a desperate plan coming together under a threat**: clone 1 distracts the guard, clone 2 holds the door, you grab the gold and the alarm goes off.
  - **The big wow is too late.** In the model, 8 OF ME arrives at minute 8.1-11.9; only 10 % reached it.
- **Verdict:** the clone mechanic can produce wow, but the current level order shows the *least* exciting version first and hides the exciting version behind about 10 minutes. Doors hits its first scare within minutes; Steal An Egg has its first chase within 60 s.

### 3.2 Level count and variety

- 6 story levels (`LEVEL_ORDER`, `Config.luau:1026`): runs of 30 s (L6: 45 s), a par of 1-4 clones and a cap of 3-8. L1-L4 and the first daily vault **share one shop shell** (REVIEW_STEAM_PLUS). There are 3 locations (CornerShop, ToyShop, Bank: `eh_palette` LOCATION_CELLS swap).
- There are 12 daily vault designs (`Config.Data.Daily.VAULT_COUNT`), and the daily **only unlocks after L4** (`Config.Onboarding.DAILY_UNLOCK_LEVEL = "cs4_night_clerk"`, line 2831), which 9 of 129 players (7 %) reached. Daily streak = 0 for all 129.
- Mechanics vocabulary: plates, doors, lasers, one guard type, loot, a till alarm, and the slide. There are no gadgets, no player-chosen tools, no randomness and no alternative routes beyond the solution.

### 3.3 Progression and rewards: what you earn, and why come back

- **Currency:** Cash = banked loot ($1 = 1 Cash), plus first-clear bonuses of 100 / 150 / 200 / 250 / 300 / 500 (`Config.luau:1037-1086`), or 1,500 Cash in total across the campaign. Stars are medals that are never spent. Candy Canes are an event currency that starts on Dec 3 (`Config.Data.Event.FIRST`).
- **Things to buy with Cash:** 2 van paints (2,500 and 6,000), 2 trails (1,500 and 4,000), and 3 bag levels (2,000 / 5,000 / 12,000, Clone Party only) (`Config.luau:1015-1017, 1162-1176`). **That is 7 purchasable items in the whole game.** Van paint and trails are seen in a private lobby bay, where nobody else sees them.
- **Robux:** all six dev products have **`id = 0`** (`Config.luau:1184` onward). Nothing can be bought. "Nobody bought anything" is not a conversion problem: **it is impossible to buy.** The owner action "create the six dev products" (PROJECT_STATE line 123) was never done.
- **Collection:** 8 trophies on the van shelf (`SHELF_SLOTS = 8`), 8 badges. There is no rarity, no random drops and no "rare loot appeared!" moment.
- **Why come back:** nothing changes while you are away. There is no timer that ticks (vault: Grow a Garden "Does leaving the game earn the player something they will see on return?"), no shared server event, and the daily is locked behind L4. **Nobody returned (0 of 129)**, which is consistent with this.

### 3.4 Goals beyond the tutorial: meta, collection, social, co-op

- **Social:** each crew is a private instance (`Config.Heist.INSTANCE_SPACING = 3000`). Solo is the default, and only 4 players earned `crew_up`. Private servers are disabled (`createVipServersAllowed false`) although the description says they are free (PROJECT_STATE funnel check 2). There is no public leaderboard in a shared space; the laptop board (`Config.Data.Board`) is inside your own bay.
- **Status:** nothing you own is visible to another player in a shared space.
- **Chaos with friends:** the design supports 16 robbers (4 players x 4 clones, `MAX_ECHOES_TOTAL = 16`), and that *is* the best idea in the game. But it is not surfaced: no matchmaking into crews, no "join a random crew" in the first minute, and 8 bays per server split into solo instances.

### 3.5 Is it "done in 2 seconds"? Quantified

From the sim (`lune run tests/run_sim.luau`, Pacing.spec `[model]` lines and the `[L1]` and `[tutorial]` lines):

| Milestone | Model (lo / mid / hi, minutes from join) | Real players who got there |
|---|---|---|
| First clone loop | **2.0 s on the plate**, then auto-rewind | 85 (`first_clone` badge) |
| L1 banked | 16.1 s median play (bot 13.8 s); 1.1 / 1.5 / 2.0 min | 59 (46 %) |
| L2 done | 4.1 / 5.5 / 7.0 (28.5 s median play, 3 runs) | 42 (33 %) |
| 8 OF ME | 8.1 / 10.0 / 11.9 | 13 (10 %) |
| L3 Lights Out | 11.9 / 15.0 / 18.1 | 9 (7 %) |
| L4 Night Clerk | 14.9 / 19.0 / 23.1 | 7 (5 %) |
| L6 Big Score (campaign end) | **22.9 / 29.0 / 35.1** | 5 (4 %) |

So the **entire game is 23-35 minutes** for a typical player. After that there are 12 daily vaults of 30-s runs, one per day, and 7 cosmetic purchases. Compare: Piggy's *average session* is 11.2 min (vault, Rolimons) across 14.4 B visits of replayable chapters. Grow a Garden and Brainrot are open-ended. The owner is right in spirit. The *first* loop is 2 s, the first level is 16 s of play, and there is no long-term goal at all.

### 3.6 What keeps kids in top Roblox games, and our score

| Driver | Top games | Heist Yourself |
|---|---|---|
| Progression (a number goes up) | Brainrot money/s, Garden Sheckles, Egg speed | Cash with 7 things to buy; no visible power or growth |
| Collection and rarity | Brainrot units by rarity; Garden mutations; eggs/pets | None (8 trophies, deterministic loot) |
| Social status | Your base or plot is seen by the server | Private bay, private instance |
| Fear and tension | Doors and Piggy: hunter, chase, jump scare | None in L1-L2; Gus from L4 |
| Chaos with friends | Steal-back raids; Doors elevator squads | Possible (16 robbers), not surfaced; solo default |
| Shared timers and events | Garden restock, Brainrot lock timers | None live until Dec 3 |

---

## 4. Audio

- **Status: the game is not silent in data.** 77 cues, **75 with ids**. Two are still empty: `VanDrive` (`Cues.luau:183`) and `GusStep` (`Cues.luau:348`; AUDIO.md mentions only GusStep). There are 7 music sets, all APM library tracks: "Paname's Rififi" / "Agent X" lounge jazz, "Sneaky Schemes", "Diamond Heist", "Code Heist" (`Cues.luau` sets, lines 987-1040). All ids loaded in a real server (AUDIO.md status).
- **But:**
  - **No human has listened to it in context.** The owner audition list (AUDIO.md §13) is open. REVIEW_STEAM_PLUS: "76/77 cues have ids, and none has been heard in context."
  - No capture or note confirms that the Audio API graph (`AudioDirector`: wires, buses, an `AudioDeviceOutput` per client) is audible on a **live client**. The proof is server-side (`tests/audio_engine.luau`).
  - Library lounge jazz is "a heist in a hotel lobby", not "8-12-year-old caper". There is no sound logo, no rewind signature sound (`RewindStinger` is "a stand-in... APM reverse swell at 1.9x", PROJECT_STATE line 416), no Gus voice and no footsteps.
  - The store video is **silent** (PROJECT_STATE line 650), and TikTok without sound is dead on arrival.
- **Owner check to do today (S):** play L1 with headphones. Is there music in the hideout, a sound on the plate, on REWIND, on loot? If anything is silent, that is a P0 bug.
- **Target:** a composer-made 3-loop package (lobby, heist with intensity layers, chase) plus a 2-second sound logo and a signature rewind "tape scrub" that every clip carries. Footsteps for everyone.

---

## 5. Feel and polish

- **Movement:** the stock Roblox humanoid at WalkSpeed 16, Shift sprint x1.4 (`Config.Sprint.MULT`, line 194), and a slide burst of +9 studs/s over 0.45 s (`Config.Slide`). Verbs: walk, slide, grab, rewind. There is no jump-based play, no crouch, no hide and no throw. The movement is functional and anonymous.
- **Animation:** the Rookie's locomotion is **generated from maths**. `Shared/Heist/RookieMoves.luau` computes poses with sine waves (16 `math.sin` calls) and bakes them into KeyframeSequences (`tools/rookie_clips.luau`). The clone acting clips (`assets/anim_ids.json`: carry, plate, busted, stuck) come from the same code-driven approach. Code can make clean cycles but not *acting*: anticipation, overlap, personality. In first person you see none of it anyway.
- **Feedback per action** (live capture evidence is thin, so this is from code):

| Action | Feedback today | Missing |
|---|---|---|
| Step on plate | plate hum (`PlateHum`), door opens | the camera does not glance at the door; no "clunk" hit-stop |
| Grab loot | `LootTinkle`, glints | cash burst, number flies to the counter, bag weight on the hands |
| Rewind | 0.066 s hit-stop, white flash 0.75, tape stinger (stand-in) | a VHS rewind visual on the world (scanlines, a reverse scrub of actors) |
| Caught | red vignette (`FLASH_RED_SECONDS = 0.5`) | Gus's voice, a slow-mo grab, a funny pose |
| Bank | "HEIST COMPLETE" card (older capture 8 shows "Couldn't save this one." in yellow on it) | a cash counter roll-up, the van driving off, loot visibly filling the hideout |

- **Polish slips seen in captures:** SLIDE button cut by the screen bottom (capture 11, y 915-1014). A debug chip "clones 1 drawn / 1 healthy / tier 1 / avatar" in older capture 9 (bottom left). "Couldn't save this one." shown to a player (older capture 8). Each is small, and kids read them as "broken game".

---

## 6. Ranked root causes: the top 10 reasons it reads as 2/10

| # | Root cause | Evidence | Impact | Fix | Effort |
|---|---|---|---|---|---|
| 1 | **No threat or stakes in the levels 90 % of players see.** L1-L2 have no guard, lasers, deadline or fail. L1 run 1 auto-ends after 2 s. | `L1_BackRoom.luau:4-6, 52`; L1/L2 have 0 guards and 0 lasers; funnel: only 7-10 % meet Gus | Retention: the 16 % mid-L1 quit and the 33 % L2 ceiling. Perception: "too simple, done in 2 s" | Rebuild L1 as a 60-90 s **real heist with Gus awake**: run 1 the kid gets caught (the Doors-style teaching death), run 2 the clone distracts, run 3 the kid gets the gold and the alarm goes off. Remove the auto-end. Gus is in every level. | M |
| 2 | **The player's own avatar was removed.** The first-person Rookie replaced "your avatar as your clones". | `IDEA_ECHO_HEIST.md:30` vs `PLAN_FIRST_PERSON.md:15, 49`; Rookie turntable | Perception: no "it's ME" and no self-expression. Retention: no status or identity hook | Clones and player use the Roblox avatar again (the clone pipeline supported layered clothing). The Rookie becomes an NPC mentor or an optional costume. | M |
| 3 | **First person by default.** You cannot see yourself or your crew; ceilings and floors fill the frame; the hands are the weakest asset; phone friction. | 123/129 in fp, 0 setting changes; capture 11 has ceiling and floor at about 75 % of the frame; capture 12 | Perception (cheap hands, empty boxes); clip value (8 OF ME needs a wide shot) | Third person default, first person optional. | S (switch) to M (tune the camera and occlusion) |
| 4 | **The lighting blows out and the measuring tools lie.** | Capture 11: 21.3 % clipped (37 % on the left); the preview grades say 0.0 % | The single biggest "amateur" tell in any screenshot | Lower the albedo of white and marble cells; Neon only on bulbs; one interior recipe tuned against **live captures**; a CI-style rule: no grade without a client capture | S-M |
| 5 | **Flat solid-colour art with no textures and empty rooms.** | 256 px atlas of 32 px cells (`eh_palette.py:6-14`); 1 SurfaceAppearance; about 6 props in capture 11; one shared shell for L1-L4 | Perception: "plastic free-model game" | Roblox materials and MaterialVariants on architecture, a bought or commissioned stylised prop pack, SurfaceAppearance on heroes, 25-40 props per room, a distinct layout per level | L |
| 6 | **No meta: nothing to collect, nothing to want, nothing to buy.** | 7 Cash items; products `id = 0`; no rarity; daily locked behind L4; 0 returners, 0 purchases | Retention D1 = 0; revenue = 0 | Loot rarity and a collection (a "vault" in the hideout that fills, visible to visitors), clone skins and gadgets as unlocks, upgrade tracks (more clones, faster carry, decoys), the daily open from day 1, dev products created | M-L |
| 7 | **The lobby before the game.** Spawn in a solo hideout, then a two-step job board and van flow. | `FTUE_AUTOSTART = false` (line 275); 44 of 129 (34 %) never started a heist | The largest single funnel loss | First join: drop straight into L1 (or a van that drives off on its own after 3 s). The hideout unlocks after L1. | S |
| 8 | **No social presence.** Private instances, solo bays, no crew matchmaking, private servers off. | `INSTANCE_SPACING = 3000`; crew_up 4 of 129; `createVipServersAllowed false` | No virality and no "chaos with friends", the genre's main driver | A shared hideout where you see others' vans and loot; "Quick Crew" as the default button; join-in-progress; private servers on | M |
| 9 | **Characters and animation made by code.** A stocky, unappealing Rookie; sine-wave locomotion; procedural SDF hands. | Turntables; `RookieMoves.luau`; `sdf_mesh.py`; 4 failed hand passes | Perception: stiff and charmless | A human character artist (Gus plus a mentor), a human animator for 10-15 clips (Gus patrol, alert, chase, catch; clone acting); the avatar for the player (#2) | L (external) |
| 10 | **Generic UI, VFX and audio identity.** Luckiest Guy plus navy slabs; default `sparkles_main.dds` on every effect; library lounge jazz; a silent trailer. | `Config.Ui.DISPLAY_FACE`; `Config.luau:1612-3129`; `Cues.luau` sets; PROJECT_STATE line 650 | Perception: "template game"; no recognisable clip | A themed HUD (tape counter, vault dial), a custom VFX flipbook sheet, a commissioned sound logo, a rewind sound and 3 music loops | M (with freelancers) |

**Underlying all ten (the process cause):** in about 5 days the project produced **464 commits, 95,381 lines of Luau in 252 files, and about 269,000 words of docs** (`git log`, `wc`). Around 700 unit tests and 240 sim tests pass. But there have been **0 real kid tests** (`docs/KID_TEST.md` has the script, but no results are recorded anywhere in the repo) and almost no live captures, and every visual track self-grades 7-7.5/10 from Blender renders. Meanwhile, each live capture the owner sends is graded "trash". The loop optimises what is measurable headless (budgets, layouts, determinism, triangle counts) instead of what a kid sees on a phone. **Engineering quality is high; the product is thin.** No more infrastructure tracks until the items above are done.

---

## 7. Plan: to 7/10, then 8.5/10

### Phase A, about 2-3 weeks: "a real game in the first 60 seconds" (target 6.5-7/10)

Ordered by impact per effort. All of this is AI-doable except where marked.

1. **Spawn into the heist.** `FTUE_AUTOSTART = true` for first joins, and the hideout unlocks after L1. (S)
2. **Third-person default, with the player's Roblox avatar** as player and clones. First person stays a setting. (S-M)
3. **Rebuild L1 as the hook level:** 60-90 s, Gus awake and patrolling with a torch cone, gold visible from the spawn, one plate-held door, and an alarm when you grab the gold. Run 1 will probably get the kid caught (a funny catch, not a fail screen). The REWIND prompt then appears *at the moment of the catch*: "Use your past self!" Remove the auto-end and the 2 s scripted run. Gus goes into L2 as well. (M; uses the sim, `Levels/*`, `tests/sim` Solutions and NaiveKid)
4. **Lighting: fix the blowout.** Albedo pass on the white and marble cells, Neon only on bulbs, one interior recipe. **Rule: no visual grade without a live client or Studio capture** (the Studio MCP screenshot is fine, a Blender render is not). (S-M)
5. **Juice the three money moments:** loot pickup (a burst plus a number flying to the counter), the rewind (a VHS scanline sweep on the world plus a reversed scrub of the actors), and the bank (cash roll-up plus a van drive-off). Custom flipbook textures replace `sparkles_main.dds`. AI can make simple flipbooks; a VFX freelancer is better. (M)
6. **HUD diet:** at most 5 always-on elements; key caps only until first use; captions at 28 px or more on a backing; SLIDE fully on screen; remove the debug chip and the "Couldn't save" text from player view. (S)
7. **Make the store work:** create the six dev products, open the daily vault from day 1, turn private servers on, set max players to 8. (S, owner in Creator Hub)
8. **Audio check plus quick wins:** the owner confirms on a live client that the music and cues play; fill `GusStep` and `VanDrive`; pick a punchier heist track than lounge jazz from the same licensed catalogues. (S)
9. **Process:** every track ends with a 30-s phone screen recording by the owner, and a kid test (1-2 kids) before Phase B starts. (S, owner)

Expected result: someone who spawns sees Gus, gold and danger within 10 s, gets caught, rewinds, and sees their own avatar distract the guard while they grab the gold. That is the TikTok clip. It does not fix the plastic look; that is Phase B.

### Phase B, about 6-10 weeks: "looks and plays like a top-100 game" (target 8-8.5/10)

1. **Art pivot (the honest answer to "can procedural Blender plus a solid-colour atlas ever look premium?"): no.** Flat-colour low-poly can look *clean*, but premium stylised on Roblox needs surface detail (painted or trim-sheet textures, real materials) and hand-authored silhouettes. Scripts cannot author taste: faces, appeal, wear, clutter variety. Recommended mix:
   - **Architecture:** keep the modular Blender walls and floors for layout (the grid and the sim colliders work), but surface them with **Roblox built-in materials plus MaterialVariant** (stylised Brick, Wood, Tile, Concrete). This is AI-doable, cheap and engine-native.
   - **Props:** **buy a stylised commercial asset pack** whose licence allows use in Roblox games (check the EULA; many low-poly packs allow it), or commission a 40-60 prop set on a shared trim sheet. Replace the flat-cell props room by room. (External: budget roughly a few hundred USD for a pack, or 1-3k USD for a commissioned set. These are estimates; get quotes.)
   - **Hero assets** (vault door, the van, Gus, loot rarities): SurfaceAppearance with painted maps from a **human 3D artist**.
   - **Characters:** the player = their Roblox avatar (Phase A). **Gus and 2-3 guard variants, plus a villain (Hoardsworth)**, from a **human character artist** (stylised, rigged R15, textured). Do not attempt this procedurally again.
2. **Animation (human animator):** Gus patrol, idle, suspicious, alert, chase, catch and sleep; clone acting (carry, hold the plate, cheer, panic); the bank celebration. About 15-20 clips. Code-generated cycles stay only as a fallback.
3. **Music and sound (human composer):** a sound logo, a rewind signature, a lobby loop, and a heist loop with 2-3 intensity layers (the existing Crew Layers system in `AudioDirector` already supports synced stems: `MUSIC_MODE = "stems"`), a chase loop, plus stingers. (External: on the order of 1-3k USD; `docs/marketing/MUSIC_BRIEF.md` exists.)
4. **Depth: the meta the genre expects:**
   - **Loot rarity and collection:** each heist rolls loot with rarities (common cash up to a mythic golden toy). A **hideout vault room** shows everything you have stolen, and other players in the shared hideout can see it. This is the Brainrot base and Garden plot equivalent.
   - **Upgrades with visible power:** clone slots, carry capacity, sprint, gadgets (a decoy noise-maker, a door jammer) recorded as echo events through `Actors` + `Echoes.recordEvent` as CLAUDE.md requires.
   - **Content cadence:** 3 more locations (not reskinned shells), procedural vault-room variations on fixed anchors (the vault's Doors note: "fixed anchors and randomised filler"), and a weekly "Big Score" with a server-wide timer.
   - **Social:** a shared hideout where crews form at the job board; join-in-progress; a public leaderboard wall.
5. **UI (a human UI designer for one week):** one bespoke style (tape and blueprint), a display font that is not Luckiest Guy, and the HUD rebuilt on it. AI implements it from the Figma frames (the `lihfolk-figma` path exists).

### What needs a human, and what cannot be done procedurally

| Needs a human | Why |
|---|---|
| Character artist (Gus, villain, guard variants) | Appeal, faces and silhouettes are taste. Four procedural hand passes prove the ceiling. |
| Animator | Acting, anticipation and comedy timing |
| Composer and sound designer | Identity (sound logo, rewind) and a non-library heist score |
| Environment or texture artist, *or* a bought pack | Surface detail, wear, clutter variety |
| UI designer (short engagement) | A distinct style and font choice |
| Kids (playtesters) | The only valid fun and clarity measure. Simulated "NaiveKid" bots are not kids. |

**AI-driven development stays excellent at:** the sim, the replication, level logic, the data and economy, tests, performance, wiring art into the engine, MaterialVariant setup, tuning and analytics. Keep it doing that, and stop asking it to be the art department.

### What not to do

- Do not run another procedural "look" pass graded on Blender renders.
- Do not simplify further. The fix for "done in 2 seconds" is **more threat, more stakes and more to collect**, not more hand-holding.
- Do not add new systems (badges, boards, bench tooling) before Phase A ships and a kid has played it.

---

## Appendix: found in passing (not visual, but urgent)

- **Live player data is written under test keys.** The live universe 10776026960 is in `Config.Data.TEST_UNIVERSE_IDS` (`Config.luau:981`). So live profiles are keyed `_TEST_U_*` and analytics run as "test" (PROJECT_STATE "Funnel check"). If anyone "fixes" this list later, every live player's progress silently disappears because the key prefix changes. This needs a deliberate decision and a migration plan before any change.
- The game is not found in Roblox search for its own name (PROJECT_STATE funnel check 2). Discovery is out of scope here, but the title and description should be checked against the vault's *Cross-Game Patterns - Thumbnails Icons and Titles* note.
