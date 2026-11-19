# Ragdoll genre: competitor and market teardown (2026-11-19)

For RAGDOLL HAVOC (universe 10774775314, place 126037745825106). Read with `../FINDINGS.md`.

## Sources and caveats
- **Live data:** Roblox public APIs, pulled 2026-11-19 at about 08:00 UTC: `games/v1/games`, `votes`, `favorites/count`, `v2/games/<id>/media`, the game-passes API (it works, not blocked), and `experience-guidelines-api/.../get-age-recommendation` for maturity labels (also open). There were 25 omni-search queries ("ragdoll", "ragdoll physics", "ragdoll sandbox", "dummy", "physics", "ragdoll soccer", "ragdoll mma", "crash physics", "organs", "gore", "ragdoll boxing/tower/engine/fight/punch/launch/battle/obby/universe" and more). Together they returned 340 distinct universes. 240 of them had ragdoll, physics or crash names and were fetched.
- **Trend baseline:** `/home/user/game-brain/radar/20261111T185716Z.json` is a sort-page snapshot taken 2026-11-11 at 18:57 UTC, which is 7.55 days earlier.
- **Time-of-day bias:** the old snapshot was taken at a US-afternoon peak and today's at a US-night trough. Fling Things and People is evergreen and stable, and it fell 18 % between the two. **Read any CCU change better than -18 % as real growth, and anything worse than about -40 % as a real decline.** Visits deltas carry no time-of-day bias, so they are the cleaner signal.
- **Blocked:** romonitorstats.com, bloxodes.com and progameguides.com do not resolve in this session. thumbnails and badges are blocked too. I found no CCU history site and no articles, so there are no thumbnail images or update logs beyond what the titles show. One web search turned up only SEO filler. A Bloxodes snippet put Hyper Realistic Ragdoll at global rank #23 on Nov 13.
- **Survivor bias:** search returns mostly games that already have players. The counts of new games are a floor, not a census.

## 1. Top ragdoll-genre games (live, 2026-11-19 ~08:00 UTC)

CCU/day is current CCU divided by days since creation. "Visits/day (last 8 d)" is the visits delta since the 11-11 snapshot. Max is maxPlayers.

| # | Game (universe) | CCU now | Visits | Created | Updated | Age d | Like % | Favs | Max | Genre (L1 / L2) | Maturity (Roblox label) | CCU/day | Visits/day (life) | Visits/day (last 8 d) | CCU 11-11 → now | Hook |
|---|---|---:|---:|---|---|---:|---:|---:|---:|---|---|---:|---:|---:|---|---|
| 1 | Hyper Realistic Ragdoll (10773618503) | 43,533 | 25.5M | 2026-10-29 | 2026-11-19 | 21 | 90.1 | 107k | 1 | Simulation / Physics Sim | Moderate (Blood (Light/Unrealistic), Fear (Occasional/Mild), Violence (Repeated/Moderate)) | 2,076 | 1.2M | 2.9M | 29,503 → 43,533 (+48 %) | 🩸 Hyper realistic ragdoll physics sandbox where every punch, shot and blast makes dummies stumble, limp and fa |
| 2 | Fling Things and People (2668101271) | 22,648 | 3752.6M | 2021-06-16 | 2025-10-29 | 1982 | 80.5 | 2.7M | 25 | Simulation / Physics Sim | Mild (Crude Humor (Mild), Violence (Repeated/Mild)) | 11 | 1.9M | 3.0M | 27,748 → 22,648 (-18 %) | A place where you can play with or fling various objects and players. |
| 3 | BloxNG [CRASH PHYSICS] 💥 (10770604649) | 21,470 | 13.5M | 2026-10-13 | 2026-11-18 | 37 | 90.7 | 52k | 10 | Simulation / Vehicle Sim | Minimal (Suitable for everyone) | 576 | 363k | n/a | n/a | ⚠️ The most realistic crash physics on Roblox. GAME IS IN BETA! |
| 4 | Ragdoll Soccer (10770730129) | 16,712 | 42.5M | 2026-10-13 | 2026-11-19 | 36 | 73.6 | 64k | 8 | Sports & Racing / Sports | Minimal (Suitable for everyone) | 459 | 1.2M | 5.2M | 26,045 → 16,712 (-36 %) | - 8v8 pro servers with referees, penalties, free kicks, throw-ins, VAR, and offsides |
| 5 | Realistic Ragdoll MMA 🥊 (10774810800) | 16,270 | 12.2M | 2026-11-05 | 2026-11-18 | 14 | 75.7 | 34k | 10 | Action / Battlegrounds & Fighting | Mild (Blood (Heavy/Unrealistic), Violence (Repeated/Mild)) | 1,185 | 885k | n/a | n/a | Step into the cage in Realistic Ragdoll MMA, a physics-based fighting game where every hit can turn the fight  |
| 6 | [🐍] Ragdoll Research (10773425091) | 7,571 | 28.2M | 2026-10-28 | 2026-11-18 | 22 | 83.2 | 772k | 1 | Simulation / Physics Sim | Moderate (Blood (Light/Realistic), Violence (Repeated/Moderate)) | 340 | 1.3M | 1.7M | 22,401 → 7,571 (-66 %) | Ragdolls + Silly Shenanigans. What could go wrong? |
| 7 | 💣 Ragdoll Destruction Playground (10774468211) | 6,492 | 7.3M | 2026-11-03 | 2026-11-19 | 16 | 80.6 | 45k | 1 | Simulation / Physics Sim | Moderate (Suitable for everyone) | 404 | 455k | n/a | n/a | Interactive physics sandbox featuring ragdolls and world destruction! |
| 8 | Ragdoll Wars! (10771544071) | 6,394 | 10.7M | 2026-10-17 | 2026-11-19 | 33 | 94.1 | 83k | 1 | Action / Battlegrounds & Fighting | Mild (Blood (Heavy/Unrealistic), Violence (Repeated/Mild)) | 196 | 328k | 619k | 9,210 → 6,394 (-31 %) | Ragdoll Wars is a realistic military Sandbox game. |
| 9 | [PHYSICS] Ragdoll Playground (10768383600) | 5,212 | 33.8M | 2026-09-27 | 2026-11-17 | 52 | 94.4 | 1.1M | 6 | Simulation / Physics Sim | Moderate (Blood (Heavy/Unrealistic), Violence (Repeated/Moderate)) | 99 | 645k | 1.2M | 14,937 → 5,212 (-65 %) | Your own 2D ragdoll sandbox. Shoot the dummy, blow him up, drop him in lava or let a dragon burn him. |
| 10 | Technical Ragdoll MMA 🥊 (10772689425) | 5,006 | 10.6M | 2026-10-24 | 2026-11-19 | 26 | 73.0 | 24k | 10 | Action / Battlegrounds & Fighting | Mild (Blood (Light/Unrealistic), Violence (Repeated/Mild)) | 192 | 409k | n/a | n/a | Technical MMA is a unique, physics-driven ragdoll MMA game where you have total control over your fighter's bo |
| 11 | [💥] Troll Ragdoll Tower (9395278151) | 4,981 | 50.7M | 2025-12-21 | 2026-11-19 | 333 | 84.8 | 2.4M | 20 | Obby & Platformer / Tower Obby | Mild (Violence (Repeated/Mild)) | 15 | 152k | n/a | n/a | 🔥💥 TROLL RAGDOLL TOWER! 💀🤡 |
| 12 | [🦖T-REX] BoneBox Engine 🩸 (10773502711) | 4,605 | 5.3M | 2026-10-28 | 2026-11-19 | 22 | 86.3 | 36k | 16 | Simulation / Physics Sim | Mild (Blood (Heavy/Unrealistic), Violence (Repeated/Mild)) | 212 | 244k | n/a | n/a | 💥 BONEBOX THE RAGDOLL PHYSICS SANDBOX 💥 |
| 13 | Ragdoll Sandbox (10771155665) | 4,156 | 25.2M | 2026-10-16 | 2026-11-17 | 34 | 84.9 | 784k | 1 | Simulation / Sandbox | Minimal (Blood (Light/Unrealistic), Violence (Occasional/Mild)) | 122 | 736k | 850k | 12,355 → 4,156 (-66 %) | 🚁 36 new vehicles: tanks, helis, jets |
| 14 | Ragdoll Experiment (10774727554) | 4,056 | 1.1M | 2026-11-04 | 2026-11-19 | 14 | 75.3 | 3,604 | 6 | Simulation /  | Mild (Blood (Light/Unrealistic), Violence (Repeated/Mild)) | 282 | 74k | n/a | n/a | 🧪 Welcome to Ragdoll Experiment! |
| 15 | Anime Ragdoll Engine 🩸 (10774140929) | 3,791 | 5.0M | 2026-11-01 | 2026-11-18 | 18 | 82.7 | 162k | 1 | Simulation / Physics Sim | Mild (Violence (Repeated/Mild)) | 211 | 275k | n/a | n/a | The game is in its Early Phase, Expect Bugs. |
| 16 | Mechs vs Kaiju's Ragdoll / [DRILL UPDATE] (10775016983) | 3,530 | 3.0M | 2026-11-06 | 2026-11-19 | 12 | 98.4 | 37k | 24 | Action /  | Moderate (Blood (Heavy/Unrealistic), Violence (Repeated/Moderate)) | 284 | 239k | n/a | n/a | EARLY RELEASE: this game is still being built - expect some bugs and new updates often! |
| 17 | Ragdoll Frenzy (10774452423) | 3,284 | 10.3M | 2026-11-03 | 2026-11-19 | 16 | 83.5 | 288k | 12 | Simulation / Physics Sim | Mild (Blood (Heavy/Unrealistic), Violence (Repeated/Mild)) | 203 | 634k | n/a | n/a | Ragdoll physics sandbox. Shoot, blast and grab robot dummies, ride the slow-mo, dodge the train and pull off c |
| 18 | Realistic Car Destruction (10771051754) | 3,069 | 21.6M | 2026-10-15 | 2026-11-18 | 35 | 79.4 | 44k | 12 | Simulation / Vehicle Sim | Minimal (Suitable for everyone) | 88 | 623k | 581k | 8,712 → 3,069 (-65 %) | 💥 The original soft body car crash game on Roblox |
| 19 | [UPD] Dummy Lab 🩸 (10775166914) | 2,957 | 3.3M | 2026-11-07 | 2026-11-19 | 12 | 76.3 | 7,459 | 6 | Simulation / Physics Sim | Mild (Blood (Heavy/Unrealistic), Violence (Repeated/Mild)) | 253 | 286k | n/a | n/a | THE MOST REALISTIC RAGDOLL ENGINE ON ROBLOX! 🩸 |
| 20 | Plane Crash Simulator (9067189974) | 2,870 | 121.2M | 2025-10-30 | 2026-11-18 | 384 | 93.7 | 4.2M | 14 | Simulation / Physics Sim | Mild (Violence (Repeated/Mild)) | 8 | 315k | n/a | n/a | Welcome to Plane Crash Simulator! |
| 21 | Half Punch (10773149360) | 2,511 | 1.5M | 2026-10-26 | 2026-11-18 | 24 | 93.0 | 13k | 7 | Action / Battlegrounds & Fighting | Minimal (Blood (Light/Unrealistic), Violence (Occasional/Mild)) | 106 | 65k | n/a | n/a | Half Punch is a physic-based fighting game inspired by Half Sword. |
| 22 | Realistic Ragdoll Engine 🩸 (10770593871) | 2,508 | 49.5M | 2026-10-12 | 2026-11-19 | 37 | 86.4 | 782k | 1 | Simulation / Physics Sim | Moderate (Blood (Light/Unrealistic), Violence (Repeated/Moderate)) | 67 | 1.3M | 1.0M | 9,818 → 2,508 (-74 %) | A Ragdoll sandbox where every hit matters. Dummies have bones and organs, reacting to exactly where and how yo |
| 23 | Bloody Ragdoll Physics 🩸 (10773926254) | 2,462 | 27.4M | 2026-10-31 | 2026-11-19 | 19 | 87.0 | 862k | 1 | Simulation / Sandbox | Mild 16+ (Blood (Light/Unrealistic), Violence (Repeated/Mild)) | 131 | 1.5M | 2.7M | 37,089 → 2,462 (-93 %) | 💥 Every dummy is a real physics body. Hit it, throw it, blow it up and watch what happens. |
| 24 | Anime Ragdoll🩸 (10773200083) | 2,318 | 2.6M | 2026-10-26 | 2026-11-18 | 23 | 88.6 | 9,119 | 4 | Simulation / Physics Sim | Mild (Blood (Light/Unrealistic), Violence (Repeated/Mild)) | 99 | 110k | n/a | n/a | 🌟 Welcome to Anime Ragdoll! 🌟 |
| 25 | [UPD] Blood Lab (10773881289) | 1,958 | 3.4M | 2026-10-30 | 2026-11-19 | 20 | 82.4 | 31k | 1 | Simulation / Physics Sim | Moderate (Blood (Heavy/Unrealistic), Violence (Repeated/Moderate)) | 101 | 174k | n/a | n/a | A physics sandbox where the blood actually flows. |
| 26 | [UPD] Destruction Engine Testing 💥 (10418879884) | 1,748 | 12.9M | 2026-06-29 | 2026-11-12 | 142 | 88.6 | 49k | 8 | Simulation / Physics Sim | Mild (Fear (Occasional/Mild), Violence (Repeated/Mild)) | 12 | 91k | 430k | 7,880 → 1,748 (-78 %) | Push Roblox and your computer to its absolute limits with a wide variety of overpowered gadgets on a variety o |
| 27 | WRECKED💥[Realistic Crashes] (10773161216) | 1,733 | 11.4M | 2026-10-26 | 2026-11-18 | 24 | 94.7 | 50k | 12 | Simulation / Vehicle Sim | Minimal (Violence (Occasional/Mild)) | 74 | 485k | 552k | 6,582 → 1,733 (-74 %) | 🚗💥 CRUSH, SMASH & DESTROY VHEICLES! 💥🚗 |

**RAGDOLL HAVOC on the same columns:** 0 CCU · 1,304 visits · created 2026-11-05 · updated 2026-11-11 (8 days ago) · 71.4 % likes (5/2) · 17 favourites · max 10 · Simulation / Physics Sim · **Minimal, Ages 16+** (Violence Occasional/Mild only) · 2 passes.

Fling Things and People (2021) is in the table as the time-of-day control, not as a competitor. Soccer and boxing games that are not ragdoll-led (Be a Soccer Legend, +1 Boxing Battle Evolution, Push the Patient) were left out.

### Two games missing from the table, both removed in the last 8 days
| Game | Created | CCU 11-11 | Now |
|---|---|---:|---|
| Ragdoll Physics 🩸 (10770575733) | 10-12 | **38,514** (#2 in genre) | `[TITLE UNAVAILABLE]`: the page is gone (moderated or made private) |
| Ragdoll Reality 🩸 (10770605947) | 10-13 | 8,731 | `[TITLE UNAVAILABLE]`. Its copy was "Shoot a leg and they limp or crawl", the same pitch as HRR and us. |

A third, **Bloody Ragdoll Physics 🩸** (10773926254), went from 37,089 to 2,462 (-93 %). Its description now opens with *"Blood effects have been reduced to comply with Roblox's content moderation guidelines"*, and its label is now **Mild 16+**. It once had 862k favourites, the most of any new game here. **In one week, moderation took out three of the genre's top ~6 sandboxes.** This is the single biggest market fact for us (see §5 and the maturity notes).

### Fastest growers (CCU per day since creation, then the 8-day visits rate)
1. **Hyper Realistic Ragdoll:** 2,076 CCU/day and **2.9M visits/day over the last 8 days**, up from 3.3M lifetime visits on 11-11 to 25.5M now. CCU rose +48 % despite the time-of-day penalty. This is the only sandbox still growing.
2. **Realistic Ragdoll MMA 🥊:** 1,185 CCU/day. It is 14 days old, has 16k CCU and **no game passes at all**.
3. **BloxNG [CRASH PHYSICS]:** 576 CCU/day. Soft-body cars, 21k CCU, rated Minimal.
4. **Ragdoll Soccer:** 459 CCU/day, but **5.2M visits/day**, the highest raw inflow in the genre. Its CCU is falling (26k to 17k), so many players try it and few stay.
5. Ragdoll Destruction Playground (404/day), Ragdoll Research (340/day, now falling hard), Mechs vs Kaiju's Ragdoll (284/day, **98.4 % likes**), Ragdoll Experiment (282/day), Dummy Lab (253/day).

---

## 2. Deep teardowns of the top 6

The six are picked for relevance to us, not by raw CCU: the two biggest dummy sandboxes (HRR, Ragdoll Research), the two biggest ragdoll **competitive** formats (MMA, Soccer), the crash-physics breakout (BloxNG), and the fastest young sandbox (Destruction Playground). [PHYSICS] Ragdoll Playground and Realistic Ragdoll Engine 🩸 are added as short notes because they explain the monetisation and the copy.

### 2.1 Hyper Realistic Ragdoll (Emo Playworks): genre leader, 43.5k CCU, still growing
- **Core loop:** pick a tool, hit dummies, watch each limb react on its own (limp, crawl), earn **KO** currency, unlock tools, then trigger bigger chaos (events, animals, vehicles).
- **First 60 s:** the description's first promise is "every punch, shot and blast makes dummies stumble, limp and fall in a different way". You act within seconds: punch or shoot, then grab and throw. Its own description stresses grab, swing and throw as a second verb.
- **Goals and progression:** a KO currency (passes sell "Double KO"), tool unlocks by category (guns, melee, throwables, powers, medic), **events with charges** (Tornado, Tsunami, Meteor Rain, Black Hole, animal raids, zombie outbreak), and a medic role (X-ray, heal, revive). Dummies **talk, follow orders and help each other**, which gives emergent stories.
- **Social:** maxPlayers **1**. Every visitor gets a private sandbox. There is no co-op; the game is a pure solo toy.
- **Monetisation:** 17 passes. Everything Pass 699, Battle Tank 399, Vehicle Pack 549, Endless Events 299, Monster Truck 249, VIP 199 ("tools turn gold"), Plague Pack 199, All Powers 129, Double KO 129, All Guns 99, Heavy Pack 79, All Melee 79, Lab Controls 69, All Throwables 69, All Medic 69, Dummy Wardrobe 49, Demolition Pack 39. The structure is **"All X" category unlocks, cheap 39-79 R$ entry points, an event-charge bypass and a 699 bundle**. Vehicles are kept *outside* the bundle so they sell twice.
- **Update cadence:** updated today (11-19). It went from 1 to 25.5M visits in 21 days. Bloxodes logged an 11-10 update with votes +126 %.
- **Maturity:** **Moderate, all ages** (Blood Light/Unrealistic, Fear Occasional/Mild, Violence Repeated/Moderate). The 🩸 stays in the description, but the blood is "goo" (the wardrobe pass colours "outfits and goo"). **Nothing is severed in the copy.** Broken bones and crawling stand in for gore.
- **Title and store page:** a plain title with no emoji and no tag. The description opens with 🩸 and lists 15 emoji bullets. The store page has 10 media items including **1 video**, the most in the set. The last line is "Supports PC, Mobile, Tablet and Console!"

### 2.2 [🐍] Ragdoll Research (Ragdoll Shenanigans): 7.6k CCU, down from 22.4k (-66 %)
- **Core loop:** experiment on reactive ragdolls with powers, weapons and **injected mutations**. Each new effect **unlocks a journal entry** (a collection log), and you earn accessories and faces to customise ragdolls.
- **First 60 s:** grab and fling, shoot, slice, bite, inject. "Silly shenanigans" framing.
- **Goals:** a mutation **journal (a collect-them-all list)**, weapon variants, a ragdoll editor with personalities.
- **Social:** the description says "Full MULTIPLAYER - Grab and Fling your Friends" and the Friend Ragdolls pass costs 39, but maxPlayers is 1 (presumably reserved or teleport servers). It supports **full motion-control VR**.
- **Monetisation:** 22 passes. Anime-IP-flavoured ability packs: "King of Curses" 174 and "Strongest One" 174 (JJK-style references), Master of Elements 119, Superpower 129, VIP 249, Jet Roadster 249, Unlimited Events 199, Sandbox+ 99, Build Mode 69, bundles at 29-49, plus off-sale Starter Pack and +5 Avatar Slots.
- **Cadence:** updated 11-18. **The emoji prefix rotates with each update** (`[🎩]` on 11-11, `[🐍]` now).
- **Maturity:** Moderate (Blood **Light/Realistic**, Violence Repeated/Moderate).
- **Takeaway:** a "journal" collection goal *did not* save its CCU. It lost the HRR head-to-head even with 772k favourites, which is 7x HRR's.

### 2.3 Realistic Ragdoll MMA 🥊 (Ultimate Champion): 16.3k CCU at 14 days, fastest new game
- **Core loop:** 1v1 cage fights with punches, kicks, throws and flying knees. Physics ragdoll reactions decide the fights ("every hit can turn the fight around").
- **First 60 s:** you are queued into a fight, or you fight on spawn. The verb is *fighting a person*, not hitting a dummy.
- **Goals:** win fights. The description names no progression, so the win itself is the goal.
- **Social:** maxPlayers 10. PvP is the whole product, and every spectator is a future fighter.
- **Monetisation:** **0 game passes** and no visible dev products. It reached 16k CCU on pure gameplay, so the monetisation layer is still to come (a big opening for them).
- **Cadence:** created 11-05, updated 11-18.
- **Maturity:** Mild (Blood Heavy/Unrealistic, Violence Repeated/Mild).
- **Title:** "Realistic Ragdoll + noun + 🥊". A clone, **Technical Ragdoll MMA 🥊**, is already at 5k CCU with the same title formula.
- **Lesson:** "ragdoll + a known competitive format" beats "ragdoll + more tools" for new entrants right now.

### 2.4 Ragdoll Soccer (Ragdoll Athletics): 16.7k CCU, highest visit inflow in the genre
- **Core loop:** ragdoll-physics football. The modes are 4v4 quickplay, **8v8 pro servers with referees, penalties, free kicks, throw-ins, VAR and offsides**, Clubs (queue 4v4 with friends), and practice.
- **First 60 s:** quickplay drops you into a 4v4 match. The description opens with `CODE: WELCOME`, a reward code as the first line.
- **Goals:** match wins, coins and cosmetics (faces, hairstyles, celebrations).
- **Social:** the strongest in the genre, with clubs, private 8v8 servers and the "Fun with Friends" sort.
- **Monetisation:** 5 passes, all cosmetic or social. Siuuu Bundle 599 and Leo Bundle 599 (celebrations named after real footballers' trademark moves, which is IP-adjacent), Legendary Bundle 299, Private 8v8 Servers 49, and a Starter Pack at 19 that is "one time only".
- **Cadence:** updated today. The description calls the game "early stages of development".
- **Maturity:** Minimal, Suitable for everyone, so it gets the widest audience.
- **Weakness:** 73.6 % likes and CCU down 36 % with 5.2M visits/day. It is a funnel with a leaky bottom.

### 2.5 BloxNG [CRASH PHYSICS] 💥 (Deform Dynamics): 21.5k CCU, the ragdoll-adjacent breakout
- **Core loop:** drive, crash and watch soft-body metal deform. Wheels snap, doors hang and glass shatters. You earn cash from driving, crashes, police chases and "skill chains".
- **First 60 s:** you are in a car and crash it.
- **Goals:** a cash economy that buys cars, plus tuning.
- **Social:** maxPlayers 10, a shared map, and a Global Radio pass (music others hear).
- **Monetisation:** 12 passes that are heavy on vehicles. Supercar Pack 1299, Flying Roadster 799, Ramp Car 799 ("Limited"), Ventara GP26 599, V12 499, Stage 3 Tuning 349, Rocket Boosters 299, VIP x2 Cash 299, Starter Pack 199, Global Radio 149, Nitro 99. **These are the highest price points in the genre.**
- **Cadence:** updated 11-18, labelled "GAME IS IN BETA!" Its sister game, WRECKED💥 by BloxNG, fell 6.6k to 1.7k.
- **Maturity:** **Minimal, Suitable for everyone.** It has no humans getting hurt at all.
- **Title:** `Brand [GENRE TAG] 💥`. The genre goes in brackets for search ("crash physics").

### 2.6 💣 Ragdoll Destruction Playground (Harpax Dev): 6.5k CCU at 16 days
- **Core loop:** a ragdoll plus a world-destruction sandbox, and you reset the map to wreck it again.
- **First 60 s:** blow things up, with slow motion as the headline feature ("Epic time slow down!").
- **Goals:** none stated beyond unlockable items.
- **Social:** maxPlayers 1, and "Multiplayer is planned".
- **Monetisation:** 4 passes, Plasma Pack 300, Slow motion UNLIMITED 199, Chainsaw 99, Jetpack UNLIMITED 99. It sells **the time limit on a feel feature** (slow-mo), not the feature itself.
- **Cadence:** updated today. The description is a changelog ("⏰ NEW UPDATE!💣 MINIGUN + CHAINSAW, SLOW MOTION").
- **Maturity:** Moderate.
- **Title:** an emoji-first title (`💣 ...`).

### 2.7 Short notes
- **[PHYSICS] Ragdoll Playground** (Speedwagon), 5.2k CCU, down from 14.9k: a "2D ragdoll sandbox… Inspired by: Granule". It has **1.14M favourites** and codes in the description (`RELEASE`, `30MVisits`, `JELLY!`). Its 15 passes are mostly **anime/hero IP packs** (JJK, JoJo, Naruto, Heroes "Mjolnir", Saiyan "Kamehameha"), plus Everything+ 999, Everything 599 and Character Builder 299. These sell, but they are borrowed IP, which our CLAUDE.md originality rule forbids and which carries DMCA risk.
- **Realistic Ragdoll Engine 🩸** (No Knees!), 2.5k CCU, down from 9.8k: VIP 199, Infection Pack 200, Unlimited Events 299, **x2 Milestone Progress 129** (so it has a milestone track), Heavy Arsenal 79, Explosion Pack 34. **Its description is word-for-word the RAGDOLL HAVOC description** (see §4).
- **Mechs vs Kaiju's Ragdoll | [DRILL UPDATE]**: 98.4 % likes and maxPlayers 24. Ragdoll physics applied to a *theme* (mechs and kaiju), with the update name in the title after a pipe.

### Cross-game monetisation summary
| Pattern | Who | Typical price |
|---|---|---|
| Everything / all-in bundle | HRR 699, Playground 599/999, Bloody 499, Ragdoll Wars Commander 339 | 339-999 |
| "All <category>" unlock | HRR (guns, melee, powers, medic, throwables) | 69-129 |
| Unlimited events / no cooldown | HRR 299, Research 199, Engine 299, Destruction slow-mo 199 | 199-299 |
| Vehicle sold separately | HRR tank 399 / truck 249, BloxNG 499-1299, Research jet 249 | 249-1299 |
| 2x currency / progress | HRR Double KO 129, Engine x2 Milestone 129, BloxNG VIP 299 | 129-299 |
| Sandbox / admin mode (spawn caps off, fly, stop time) | HRR Lab Controls 69, Research Sandbox+ 99, Ragdoll Wars 179, Bloody 99 | 69-179 |
| Cosmetic customising of dummies | HRR Wardrobe 49, Research Silly Pack 39, Ragdoll Wars skins 69-99 | 39-99 |
| One-time starter pack | Soccer 19, BloxNG 199, Research (off-sale) | 19-199 |
| **RAGDOLL HAVOC** | ULTRA 249, VIP 149 | 2 passes, no entry point under 149, no bundle, no category unlocks |

---

## 3. Patterns

### What every winner has that RAGDOLL HAVOC lacks
1. **A verb in the first 5 s that works on every device.** HRR, MMA, Soccer and BloxNG all advertise console. Our console players cannot shoot at all (FINDINGS #1), yet our description claims "Console, Mobile, Tablet, and VR".
2. **One specific, original sentence of promise.** HRR has "Shoot a leg and they limp, break it and they crawl". MMA has "every hit can turn the fight around". BloxNG has "Metal crumples and folds exactly where it's hit". Ours is a copy of another game's sentence.
3. **A spectacle ladder past minute 1:** world events (tornado, tsunami, meteor, black hole, nuke), vehicles, animals, zombies. HRR, Research, Bloody, Engine and Playground all have events *with charges*, which gives a reason to wait, return or pay. Ours shows no events in the copy.
4. **A currency named on the pass list** (KO, cash, kills) and a visible unlock track ("Unlock weapons: Katana, Sniper, Minigun…"). We have Progress and DailyGoals in code (`/home/user/ragdoll-havoc/place/ReplicatedStorage/Shared/Progress.luau`, `DailyGoals.luau`), but the store page does not surface them.
5. **A pass catalogue of 12-22 items with a 39-79 R$ entry tier and a 499-699 bundle.** We have 2 passes and nothing under 149.
6. **Store media:** HRR has 10 media items with a video, Research 5 with a video, Ragdoll Wars 7 with a video. We have 3 images and no video.
7. **An update signal.** Every top-6 game was updated in the last 24-48 h, and most show it in the title (`[UPD]`, `[🐍]`, `[DRILL UPDATE]`, `[FIXES]`). Ours was last updated 8 days ago, with no tag.
8. **A maturity label that matches the content, sitting at Moderate or below.** HRR keeps "goo" blood light and unrealistic. Severed limbs (our `Config.SEVERING = true`) are what the moderated games advertised ("Limbs come off" in Bloody Ragdoll Physics).

### Structural facts about the market
- **Dummy sandboxes are solo products.** HRR, Research, Destruction Playground, Ragdoll Sandbox, Realistic Ragdoll Engine and Bloody Ragdoll Physics all run **maxPlayers = 1**. A solo server is never empty, so a new player never lands in a dead lobby. RAGDOLL HAVOC runs 10-player servers with 0 CCU, so every player plays alone in a server built for 10. Solo is the same experience as the leaders' anyway, but our "Play with friends, and prank them too!" line over-promises.
- **Winner-take-all consolidation.** Taking the 11 genre games present in both snapshots plus the 2 removed ones, CCU fell from **231.8k to 95.1k**. Without HRR it fell from **202k to 51.6k (-75 %)**, while HRR alone rose 29.5k to 43.5k. HRR's growth has come from the other sandboxes.
- **Competitive ragdoll formats are the new growth vector.** MMA (16k at 14 days), Technical MMA (5k), Soccer (17k) and Half Punch (2.5k, "inspired by Half Sword", 93 % likes) all hold better than sandboxes of the same age.
- **Theme over realism.** Mechs vs Kaiju (98 % likes), Anime Ragdoll Engine, Ragdoll Wars (military, 94 %), and Animal Ragdoll or Ragdoll Animal Playground. Most new entrants put a theme on the same physics.

### White space nobody covers well
1. **Co-op objectives with dummies.** No top game has 2-4 players sharing a goal against the clock with ragdolls. The examples would be a rescue, a stunt score or a "keep the dummy alive" run. Only the small `[UPD] Control a Ragdoll Together! [1-5 Players]` (95.9 % likes, 740 CCU) and Push the Patient (organs, 1-2 player obby, 3.5k CCU) point at it, and both show high approval. That matches our game-brain note "Ragdoll Rescue Crew: rescue is small and fresh".
2. **Medic / reverse-violence.** HRR has a medic pack and Engine has "restart hearts", but **no game makes healing the main goal** (a triage ER with ragdolls). This route also keeps the label at Mild/Minimal and opens the under-13 audience that the gore race is losing.
3. **Score-chasing per run.** No sandbox has a 60 s "damage score / combo / launch distance" run with a leaderboard and a replay clip. Older games like Broken Bones IV (1.5B visits, "break your bones" score) proved this loop in 2018-2020, and no 2026 wave game has rebuilt it in the new realistic style.
4. **Console-first.** Every game *claims* console, but none shows gamepad controls in its media. A clear gamepad scheme is a genuine edge, and 19 % of our sessions are console.
5. **Building and sharing setups.** Playground sells a Character Builder (299) and Research sells Build Mode (69). Nobody ships **share codes for contraptions or scenarios**. RAGDOLL HAVOC already has `Build/ShareCode.luau` in its place snapshot.
6. **Christmas.** No top-25 ragdoll title carries a holiday tag yet (HRR, Research and Destruction carry none). Others use `[🎃]`, `[❄️UPD]` (Slice A Dummy) and `[🎄]`-style tags. We already have `Shared/Christmas.luau`.

---

## 4. Title, description and genre audit of RAGDOLL HAVOC

### Current store page
- **Title:** `RAGDOLL HAVOC`. All caps, no emoji, no tag, no update signal. It is original, which is good. "Havoc" is a fine brand but it is not a search term. The searches people run are "ragdoll", "realistic ragdoll", "ragdoll physics" and "ragdoll sandbox". The word "ragdoll" is first, which helps.
- **Description:** **a near verbatim copy of Realistic Ragdoll Engine 🩸 (No Knees!, 10770593871).** Every line is identical except the inserted "🩸 Play with friends, and prank them too!" That game is falling (9.8k to 2.5k). The copy is:
  - an originality problem (CLAUDE.md: "own name, art and characters");
  - a search de-duplication problem, since the two near-identical texts compete;
  - **false claims.** "Supports Console" while console cannot shoot, "VR Players" untested, and "Explore different maps… restart hearts… zombies" have to be checked against the build.
- **Genre:** Simulation / Physics Sim, which is right and the same as HRR and Research. Keep it. If we pivot to a competitive or co-op mode, Action / Battlegrounds & Fighting (MMA) and Obby & Platformer (Control a Ragdoll Together) are the alternatives.
- **Maturity:** **Minimal, 16+**, declaring only "Violence (Occasional/Mild)". Two problems:
  1. It **under-declares.** Severing is on, and the description uses 🩸, bones and organs. Under-declaring is the risk that removed Ragdoll Physics 🩸 and Ragdoll Reality this week.
  2. The **16+ gate** (a new-experience default, or a consequence of the questionnaire) cuts the under-16 audience that HRR (all ages, Moderate) gets. Bloody Ragdoll Physics fell to 16+ and lost 93 %.
- **Passes:** 2 (ULTRA 249, VIP 149). **Media:** 3 images, no video. **Updated:** 11-11.

### Rewrite suggestions (all original wording)

**Title options** (pick one, ≤ 30 visible characters, keep "Ragdoll" early for search):
- `[🎄 XMAS] Ragdoll Havoc 💥`: a seasonal tag plus the brand. Rotate the bracket each update, as Research does.
- `Ragdoll Havoc 💥 [CO-OP]`: only once a co-op goal exists (white space 1).
- `[UPD] Ragdoll Havoc: Dummy Lab`: if we stay a sandbox. "Dummy Lab" is the term searchers type, but `[UPD] Dummy Lab 🩸` already exists, so test this one.
- Avoid 🩸 in the title until the maturity questionnaire and the severing decision are settled. Use 💥 (BloxNG, Destruction, Troll Tower) instead.

**Description draft** (one promise, then proof bullets, then real platform support; every line has to be true in the build):
```
Every hit lands where you aim. Knock a dummy's legs out and it hobbles; crack its ribs and it doubles over. Then patch it up and go again.

💥 Punch, shoot, launch and drop dummies — each bone reacts on its own
🎯 Daily goals and takedown milestones unlock new tools
🥚 Free egg every 75 takedowns (VIP: every 50)
🧪 Build a contraption and share its code with friends
🎄 Christmas Lab: <event name> until Dec 31
👥 Bring friends into your lab — or launch them

🎮 PC, Mobile and Tablet. Controller support: <only once gamepad shooting ships>
```
Additional notes:
- **Put a code in the first line** (Soccer `CODE: WELCOME`, Playground's three codes). That is only worth doing if a codes system exists or gets added.
- Keep the description to 6-8 bullets. HRR's 15 is the ceiling.
- **Media:** add a 15-30 s video, since every top-3 sandbox has one. Show a limp or crawl reaction in the first 2 s. Add 5+ images showing distinct verbs (hit, grab and throw, event, vehicle, heal).
- **Passes:** add a 39-79 R$ entry tier (for example an "All Throwables" or Dummy Wardrobe style cosmetic), a 299 Unlimited Events pass if events exist, and a 499-699 "Everything" bundle. Keep ULTRA, since it is the same idea as "spam everything". The vault's monetisation compliance skill applies.

---

## 5. Timing: is the wave still growing?

**The wave peaked about 2 weeks ago, and the sandbox sub-genre has consolidated into one winner.**

Cohort of ragdoll, dummy and physics-sim games found by search, grouped by creation week (the sample is survivor-biased):

| Week created | Games found | Sum CCU now | Median CCU | Games ≥ 1k CCU | Best |
|---|---:|---:|---:|---:|---|
| before Sep 2026 | 60 | 40.7k | 37 | 6 | Fling, Troll Ragdoll Tower, Plane Crash Sim |
| Sep 21 | 6 | 6.8k | 41 | 2 | Ragdoll Playground 5.2k |
| Oct 12 | 21 | 34.8k | 204 | 6 | Ragdoll Soccer 16.7k |
| Oct 19 | 15 | 8.5k | 75 | 2 | Technical MMA 5.0k |
| **Oct 26** | **31** | **74.7k** | **370** | **11** | **HRR 43.5k**, Research 7.6k |
| Nov 2 | 32 | 46.2k | 191 | 9 | Realistic Ragdoll MMA 16.3k |
| Nov 9-14 | 6 | 0.8k | 29 | 0 | Ragdoll Test Physics 432 |

**In the last 14 days (created ≥ 11-05), 31 games were found, with 30.7k CCU in total.**
- Three games hold 74 % of it: Realistic Ragdoll MMA 16.3k, Mechs vs Kaiju 3.5k, Dummy Lab 3.0k.
- 15 of the 31 have under 100 CCU. Seven of them are a "Realistic / Hyper / Ultra / Mega Ragdoll" sandbox clone, at 8-870 CCU. One is a clone literally titled "Hyper Realistic Ragdoll", at 14 CCU.
- **Most plain-sandbox newcomers under 1k sit at 37-71 % likes. The exceptions are small niche ones (Ragdoll Test Physics 93 %, Plane Wreck Physics 95 %). Every newcomer above 1k has a twist:** a competitive format (MMA, Gladiator Arena 1.6k), a theme (Mechs vs Kaiju, Animal Ragdoll 1.3k) or a lab framing with live updates (Dummy Lab).
- **Since 11-09, no new ragdoll game found by search has reached 1k CCU.** Creation has slowed sharply: 6 found, against 31-32 a week in late Oct and early Nov.

**What this means for RAGDOLL HAVOC:**
1. "Another realistic dummy sandbox" is a closed window. HRR is at 43.5k and growing on 2.9M visits/day, and the other sandboxes lost about 75 % of their CCU in a week.
2. The genre's audience is still very large: about 95k concurrent on the tracked games, plus Fling at 22k. It is moving to **formats and themes**: competitive, themed and co-op.
3. Moderation is tightening on blood and dismemberment right now, with 2 removals and 1 forced toning-down in a week. Any relaunch should aim for **Moderate or lower**, with severing off (`Config.SEVERING = false`) and an honest questionnaire. That also lifts the 16+ gate, matching HRR's all-ages label.
4. The best entry points still open are a **co-op objective mode**, a **60 s score run with a leaderboard** (it fits the 52 s median session we already have), and **console-first controls**, all inside a Christmas update tag. A pure feature race against HRR's 17-pass, 15-system sandbox is the worst option.
