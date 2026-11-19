# Ragdoll/physics market: evening pull (2026-11-19, 17:35 UTC)

Follow-up to `COMPETITORS.md` (morning snapshot, ~08:00 UTC the same day). Public Roblox data only; nothing written anywhere.

## Method
- **Time of pull:** 2026-11-19, 17:25-17:40 UTC (search 17:25-17:33, game details + votes 17:35, passes/maturity 17:38). Morning baseline: ~08:00 UTC, so the gap is **~9.6 h**.
- **Discovery:** `apis.roblox.com/search-api/omni-search?searchQuery=<q>&sessionId=<uuid>&pageType=all`, up to 3 pages per query (`pageToken` = `nextPageToken`), 30 queries: ragdoll, ragdoll physics, ragdoll sandbox, dummy, physics, ragdoll soccer, ragdoll mma, crash physics, realistic ragdoll, ragdoll engine, ragdoll fight/boxing/tower/punch/launch/battle/obby, dummy lab, ragdoll lab, destruction physics, car crash, ragdoll playground/experiment/simulator/war/christmas/basketball/football/wrestling, fling. 1,044 distinct universes, plus the 29 universe ids from COMPETITORS.md and ours.
- **Details:** `games.roblox.com/v1/games?universeIds=` (playing, visits, created, updated, favoritedCount, maxPlayers, genre, description) and `games.roblox.com/v1/games/votes?universeIds=`, batches of 50. Genre filter: name matches ragdoll|physics|crash|dummy|fling|destruction|wreck|bone|soft body, or the game was in the morning table.
- **Passes:** `apis.roblox.com/game-passes/v1/universes/<id>/game-passes?passView=Full&pageSize=100`. (The `games.roblox.com/v1/games/<id>/game-passes` endpoint now returns an error.)
- **Maturity:** POST `apis.roblox.com/experience-guidelines-api/experience-guidelines/get-age-recommendation` `{"universeId": "<id>"}`.
- **Time-of-day bias (reversed from the morning):** 08:00 UTC is the US-night trough; 17:35 UTC is US late morning / EU evening, so evening CCU is naturally higher. Control: Fling Things and People (not updated since Oct 2025) went **22,648 -> 29,391 (+30 %)**. Read a CCU change of about +30 % as flat, well above as real growth, below as a real decline.
- **Visits/h** = (evening visits - morning visits) / 9.6 h. The morning table rounds visits to 0.1M, so each visits/h figure is +-5k/h.
- **Caveats:** the `updated` field moves on any publish (including config-only saves), so it shows activity, not content size. Search is survivor-biased (games with players rank first).

## 1. Top 30 ragdoll/physics/crash games (17:35 UTC)

| # | Game (universe) | CCU 17:35 | CCU 08:00 | Δ CCU | Visits | Visits/h since 08:00 | Created | Updated (UTC) | Upd. h ago | Up / Down | Like % | Favs | Max |
|---|---|---:|---:|---:|---:|---:|---|---|---:|---:|---:|---:|---:|
| 1 | Hyper Realistic Ragdoll (10773618503) | 90,857 | 43,533 | +109 % | 27.5M | 212k | 2026-10-29 | 2026-11-19 07:51 | 9.7 | 28,520 / 3,067 | 90.3 | 115k | 1 |
| 2 | Ragdoll Soccer (10770730129) | 49,496 | 16,712 | +196 % | 44.3M | 186k | 2026-10-13 | 2026-11-19 17:10 | 0.4 | 23,415 / 8,396 | 73.6 | 66k | 8 |
| 3 | BloxNG [CRASH PHYSICS] 💥 (10770604649) | 39,846 | 21,470 | +86 % | 14.9M | 146k | 2026-10-13 | 2026-11-19 16:57 | 0.6 | 16,038 / 1,673 | 90.6 | 55k | 10 |
| 4 | Fling Things and People (2668101271) | 29,391 | 22,648 | +30 % | 3754.0M | 143k | 2021-06-16 | 2025-10-29 20:26 | 9261.1 | 975,277 / 236,621 | 80.5 | 2.7M | 25 |
| 5 | Realistic Ragdoll MMA 🥊 (10774810800) | 23,909 | 16,270 | +47 % | 13.3M | 114k | 2026-11-05 | 2026-11-19 14:47 | 2.8 | 9,516 / 3,077 | 75.6 | 36k | 10 |
| 6 | Bloody Ragdoll Physics 🩸 (10773926254) | 21,296 | 2,462 | +765 % | 28.0M | 67k | 2026-10-31 | 2026-11-19 03:18 | 14.3 | 30,407 / 4,541 | 87.0 | 883k | 1 |
| 7 | [🐍] Ragdoll Research (10773425091) | 14,631 | 7,571 | +93 % | 28.6M | 44k | 2026-10-28 | 2026-11-19 17:01 | 0.6 | 19,935 / 3,998 | 83.3 | 785k | 1 |
| 8 | 💣 Ragdoll Destruction Playground (10774468211) | 11,825 | 6,492 | +82 % | 7.7M | 40k | 2026-11-03 | 2026-11-19 13:36 | 4.0 | 5,815 / 1,393 | 80.7 | 48k | 1 |
| 9 | [PHYSICS] Ragdoll Playground (10768383600) | 10,572 | 5,212 | +103 % | 34.1M | 31k | 2026-09-27 | 2026-11-19 17:19 | 0.3 | 87,104 / 5,192 | 94.4 | 1.1M | 6 |
| 10 | Technical Ragdoll MMA 🥊 (10772689425) | 8,649 | 5,006 | +73 % | 11.5M | 94k | 2026-10-24 | 2026-11-19 00:52 | 16.7 | 3,756 / 1,411 | 72.7 | 25k | 10 |
| 11 | [🦖T-REX] BoneBox Engine 🩸 (10773502711) | 8,403 | 4,605 | +82 % | 5.6M | 35k | 2026-10-28 | 2026-11-19 14:32 | 3.0 | 6,232 / 1,020 | 85.9 | 36k | 16 |
| 12 | [UPD] Dummy Lab 🩸 (10775166914) | 7,641 | 2,957 | +158 % | 3.8M | 51k | 2026-11-07 | 2026-11-19 10:23 | 7.2 | 1,046 / 325 | 76.3 | 8k | 6 |
| 13 | Ragdoll Wars! (10771544071) | 7,330 | 6,394 | +15 % | 10.9M | 25k | 2026-10-17 | 2026-11-19 09:08 | 8.4 | 29,667 / 1,873 | 94.1 | 84k | 1 |
| 14 | Ragdoll Sandbox (10771155665) | 7,248 | 4,156 | +74 % | 25.4M | 25k | 2026-10-16 | 2026-11-17 11:47 | 53.8 | 14,555 / 2,600 | 84.8 | 790k | 1 |
| 15 | [🍁] Fling Playground (9514625031) | 6,727 | n/a | new in set | 23.1M | n/a | 2026-01-06 | 2026-11-15 19:48 | 93.8 | 7,508 / 4,594 | 62.0 | 58k | 32 |
| 16 | Realistic Car Destruction (10771051754) | 6,695 | 3,069 | +118 % | 21.8M | 24k | 2026-10-15 | 2026-11-18 20:49 | 20.8 | 8,920 / 2,317 | 79.4 | 45k | 12 |
| 17 | Ragdoll Experiment (10774727554) | 6,505 | 4,056 | +60 % | 1.3M | 21k | 2026-11-04 | 2026-11-19 15:26 | 2.1 | 396 / 130 | 75.3 | 4k | 6 |
| 18 | Half Punch (10773149360) | 6,348 | 2,511 | +153 % | 1.7M | 22k | 2026-10-26 | 2026-11-18 13:00 | 28.6 | 9,207 / 707 | 92.9 | 14k | 7 |
| 19 | Ragdoll Frenzy (10774452423) | 5,732 | 3,284 | +75 % | 10.8M | 55k | 2026-11-03 | 2026-11-19 01:18 | 16.3 | 4,608 / 914 | 83.4 | 303k | 12 |
| 20 | [💥] Troll Ragdoll Tower (9395278151) | 5,232 | 4,981 | +5 % | 50.9M | 24k | 2025-12-21 | 2026-11-19 17:26 | 0.1 | 18,117 / 3,243 | 84.8 | 2.4M | 20 |
| 21 | Mechs vs Kaiju's Ragdoll / [DRILL UPDATE] (10775016983) | 4,166 | 3,530 | +18 % | 3.3M | 28k | 2026-11-06 | 2026-11-19 04:57 | 12.6 | 7,548 / 125 | 98.4 | 40k | 24 |
| 22 | Realistic Ragdoll Engine 🩸 (10770593871) | 4,079 | 2,508 | +63 % | 49.6M | 15k | 2026-10-12 | 2026-11-19 03:29 | 14.1 | 42,532 / 6,707 | 86.4 | 783k | 1 |
| 23 | 🍎[FLING] Newton's Sandbox (10768661782) | 3,516 | n/a | new in set | 2.3M | n/a | 2026-09-29 | 2026-11-18 16:12 | 25.4 | 2,063 / 639 | 76.4 | 52k | 28 |
| 24 | [UPD] Destruction Engine Testing 💥 (10418879884) | 3,489 | 1,748 | +100 % | 13.0M | 10k | 2026-06-29 | 2026-11-12 17:07 | 168.5 | 10,086 / 1,295 | 88.6 | 49k | 8 |
| 25 | Anime Ragdoll Engine 🩸 (10774140929) | 3,431 | 3,791 | -9 % | 5.1M | 15k | 2026-11-01 | 2026-11-18 21:38 | 19.9 | 4,554 / 949 | 82.8 | 167k | 1 |
| 26 | [UPD] Blood Lab (10773881289) | 3,409 | 1,958 | +74 % | 3.5M | 9k | 2026-10-30 | 2026-11-19 14:58 | 2.6 | 6,139 / 1,308 | 82.4 | 31k | 1 |
| 27 | [UPD 8] Pleb's Plane Crash Sandbox [ALPHA] (10774313244) | 3,335 | n/a | new in set | 828k | n/a | 2026-11-02 | 2026-11-19 13:06 | 4.5 | 4,936 / 387 | 92.7 | 14k | 1 |
| 28 | Ragdoll Animal Playground (10774857751) | 3,311 | n/a | new in set | 1.2M | n/a | 2026-11-05 | 2026-11-19 16:08 | 1.4 | 514 / 288 | 64.1 | 42k | 1 |
| 29 | Plane Crash Simulator (9067189974) | 3,147 | 2,870 | +10 % | 121.4M | 21k | 2025-10-30 | 2026-11-18 14:52 | 26.7 | 126,327 / 8,536 | 93.7 | 4.2M | 14 |
| 30 | Animal Ragdoll (10775306701) | 3,083 | n/a | new in set | 580k | n/a | 2026-11-08 | 2026-11-19 09:22 | 8.2 | 485 / 79 | 86.0 | 15k | 1 |

Two more from the morning table, outside the top 30:

| # | Game (universe) | CCU 17:35 | CCU 08:00 | Δ CCU | Visits | Visits/h since 08:00 | Created | Updated (UTC) | Upd. h ago | Up / Down | Like % | Favs | Max |
|---|---|---:|---:|---:|---:|---:|---|---|---:|---:|---:|---:|---:|
| 34 | Anime Ragdoll🩸 (10773200083) | 2,542 | 2,318 | +10 % | 2.7M | 10k | 2026-10-26 | 2026-11-19 16:19 | 1.3 | 2,797 / 362 | 88.5 | 9k | 4 |
| 35 | WRECKED💥[Realistic Crashes] (10773161216) | 2,449 | 1,733 | +41 % | 11.6M | 17k | 2026-10-26 | 2026-11-19 17:34 | 0.0 | 46,607 / 2,596 | 94.7 | 50k | 12 |

Also in the next band (2.0-2.8k CCU): [FIXES] Ragdoll Realism 2,774; Ragdoll Gladiator Arena 2,566; Car Destruction Engine [EARLY ACCESS] 2,542; [POWERS⚡️] Bad Physics💥 2,264; Ragdoll Craft Sandbox 2,183; 🩸Realistic Ragdoll Sandbox 2,130; [UPD2] +1 Super Saiyan Destruction 2,121; [WORKSHOP] Water Physics 2,099; Realistic Ragdoll Physics 2,077. [UPD] Control a Ragdoll Together! [1-5 Players] (the co-op one): 1,701 CCU, 95.9 % likes.

**Still removed:** Ragdoll Physics 🩸 (10770575733) and Ragdoll Reality 🩸 (10770605947) return no game details (votes still exist: 44.6k/5.3k and 38.3k/7.9k).

**Genre total:** the 26 morning-tracked games (Fling excluded) went **181.2k -> 358.9k CCU (+98 %)**, against +30 % for the control. Without HRR: 137.7k -> 268.1k (+95 %). The genre grew today across the board, not only the leader.

### What moved since the morning
- **Hyper Realistic Ragdoll: 43.5k -> 90.9k CCU** (+109 %), ~212k visits/h (about 5M/day, up from 2.9M/day over the previous 8 days). Search reports it as the #1 "ragdoll" result.
- **Bloody Ragdoll Physics 🩸: 2,462 -> 21,296 (+765 %).** Its label went from **Mild 16+** in the morning to **Mild, all ages** now (Blood Light/Unrealistic, Violence Repeated/Mild); updated 03:18 UTC, and 13 of its 18 passes are now off sale. Clear evidence that the 16+ gate was what was killing it, and that lifting it brings the audience back within hours.
- **Ragdoll Soccer: 16.7k -> 49.5k (+196 %)**, the biggest absolute riser after HRR, ~186k visits/h.
- **BloxNG [CRASH PHYSICS]: 21.5k -> 39.8k (+86 %).**
- **[UPD] Dummy Lab 🩸: 3.0k -> 7.6k (+158 %).** Its pitch is very close to ours: "Launch, drop and blast crash test dummies. Then check the X-ray to see exactly what happened! ... Cannon, rocket sled and drop tower ... Rank up and unlock new weapons". Rated Mild, all ages.
- **Half Punch: 2.5k -> 6.3k (+153 %)** at 92.9 % likes (physics fighting, "inspired by Half Sword").
- Below the control (relative losers): Anime Ragdoll Engine -9 %, Troll Ragdoll Tower +5 %, Plane Crash Simulator +10 %, Anime Ragdoll +10 %, Ragdoll Wars +15 %, Mechs vs Kaiju +18 % (still 98.4 % likes).

## 2. Newcomers (created in the last 14 days, i.e. on or after 2026-11-05, CCU > 2,000)

| Game (universe) | Created (UTC) | CCU | Like % | Max | Hook (description first line) |
|---|---|---:|---:|---:|---|
| Realistic Ragdoll MMA 🥊 (10774810800) | 11-05 14:25 | 23,909 | 75.6 | 10 | "Step into the cage in Realistic Ragdoll MMA, a physics-based fighting game where every hit can turn the fight around." |
| [UPD] Dummy Lab 🩸 (10775166914) | 11-07 15:32 | 7,641 | 76.3 | 6 | "THE MOST REALISTIC RAGDOLL ENGINE ON ROBLOX! 🩸" (then: crash test dummies + X-ray replay) |
| Mechs vs Kaiju's Ragdoll / [DRILL UPDATE] (10775016983) | 11-06 21:26 | 4,166 | 98.4 | 24 | "EARLY RELEASE: this game is still being built - expect some bugs and new updates often!" |
| Ragdoll Animal Playground (10774857751) | 11-05 20:30 | 3,311 | 64.1 | 1 | "🐾 Welcome to Ragdoll Animal Playground!" |
| Animal Ragdoll (10775306701) | 11-08 08:07 | 3,083 | 86.0 | 1 | "🦍 Animal Ragdoll – be the beast, wreck everything!" |
| Ragdoll Gladiator Arena (10775306547) | 11-08 08:06 | 2,566 | 88.8 | 1 | "⚔️ Step into the pit and take on a whole arena of ragdoll gladiators!" |

Just under the bar: BAD Ragdoll City 💥 (11-06) 1,960, "🏙️ Welcome to BAD RAGDOLL CITY, a whole PS2-style city that's yours to wreck!"; Ragdoll Destruction 💥 (11-12) 1,486, "💥 DESTROY EVERYTHING! 💥"; Very Realistic Ragdolls 🩸 (11-07) 1,061. Ragdoll Experiment (10774727554, 6,505 CCU) was created 11-04, one day outside the window. **Still no ragdoll game created after 11-08 is above 2k CCU**; the youngest above 1k is Ragdoll Destruction 💥 (11-12). Every newcomer above 2k has a twist: a competitive format (MMA, Gladiator), a theme (mechs/kaiju, animals) or a lab framing (Dummy Lab).

## 3. Game passes, top 5 (by CCU, Fling excluded as the control)

Prices in Robux, on sale unless marked.

- **Hyper Realistic Ragdoll** (17, all on sale): Everything Pass 699 (all tools, events, passes; no vehicles), Vehicle Pack 549, Battle Tank 399, Endless Events 299, Monster Truck 249, VIP 199 (all KO tools now, gold tools, Lab Controls), Plague Pack 199, All Powers 129, Double KO 129, All Guns 99, Heavy Pack 79 (Minigun), All Melee 79, Lab Controls 69 (fly, stop time, many dummies), All Throwables 69, All Medic 69, Dummy Wardrobe 49, Demolition Pack 39. Unchanged from the morning.
- **Ragdoll Soccer** (5): Siuuu Bundle 599, Leo Bundle 599, Legendary Bundle 299, Private 8v8 Servers 49, Starter Pack 19 (one time only).
- **BloxNG [CRASH PHYSICS]** (11 on sale + 1 off): Supercar Pack 1299, Flying Roadster 799 (new 11-12), Ramp Car 799 (Limited), Ventara GP26 599, V12 Supercar 499, Stage 3 Tuning 349, VIP 299 (x2 cash), Rocket Boosters 299, Starter Pack 199, Global Radio 149, Nitro 99; 2X Cash off sale.
- **Realistic Ragdoll MMA 🥊**: **0 passes** (still none at 23.9k CCU).
- **Bloody Ragdoll Physics 🩸** (5 on sale + 13 off sale): Everything 499, Arsenal 249, Injections 199, VIP 199 (double kills, gold tag), Sandbox 99. Off sale: 2x Kills, All Weapons, All Packs, Blood Colours Pack, Physics Pack, Blade & Blast Pack, Firearms Pack, Toy Tools Pack, Hunter Pack, Rainbow Blood, Rocket Launcher, Minigun, Flamethrower. The catalogue was cut to 5 at the same time as the blood was reduced.
- For reference, **[🐍] Ragdoll Research** (#7): 15 on sale (VIP 249, Jet Roadster 249, Unlimited Events 199, King of Curses 174, Strongest One 174, Superpower 129, Master of Elements 119, Sandbox+ 99, Build Mode 69, Home Bundle 49, Funny Bundle 49, Titan Gear 49, Friend Ragdolls 39, Silly Pack 39, Selfie Stick 29) plus 9 off sale, two of them created today ("Mastery Everything", "Unlock Everything").

## 4. Update rhythm (top 10 by CCU)

| Game | Updated (UTC) | Hours before pull |
|---|---|---:|
| Hyper Realistic Ragdoll | 11-19 07:51 | 9.7 |
| Ragdoll Soccer | 11-19 17:10 | 0.4 |
| BloxNG [CRASH PHYSICS] | 11-19 16:57 | 0.6 |
| Fling Things and People | 2025-10-29 20:26 | 9,261 (13 months; evergreen) |
| Realistic Ragdoll MMA | 11-19 14:47 | 2.8 |
| Bloody Ragdoll Physics | 11-19 03:18 | 14.3 |
| Ragdoll Research | 11-19 17:01 | 0.6 |
| Ragdoll Destruction Playground | 11-19 13:36 | 4.0 |
| [PHYSICS] Ragdoll Playground | 11-19 17:19 | 0.3 |
| Technical Ragdoll MMA | 11-19 00:52 | 16.7 |

Every new-wave game in the top 10 published within the last 17 h; five within the last 3 h. Compared with the morning pull, Soccer, BloxNG, MMA, Research, Destruction Playground and Ragdoll Playground all published again during the day, so **several publishes per day** is normal for the leaders. HRR's last publish is 07:51, so its +109 % today came without a new publish since the morning.

## 5. RAGDOLL HAVOC (universe 10774775314)

| Field | Morning (08:00) | Evening (17:35) |
|---|---|---|
| CCU | 0 | **0** |
| Visits | 1,304 | **1,305** |
| Votes up / down | 5 / 2 (71.4 %) | **5 / 2 (71.4 %)** |
| Favourites | 17 | **17** |
| Updated | 11-11 | **11-19 16:02 UTC** (published today) |
| maxPlayers | 10 | **6** |
| Maturity | Minimal, Ages 16+ | **Minimal, Ages 16+** (only Violence Occasional/Mild declared) |
| Passes | ULTRA 249, VIP 149 | same |
| Store media | 3 images | 3 images, no video |
| Description | copy of Realistic Ragdoll Engine | **new, original** ("💥 Crash-test dummies, a lab full of toys, and a cannon. Make them fly, then watch it again in X-ray slow-mo!" ... "Cartoon effects only: stars and sparks, no blood.") |

The 16+ gate is still on, even though the declared content is Minimal. Today's Bloody Ragdoll Physics recovery (+765 % after its label dropped 16+) shows what that gate costs.

## 6. Hyper Realistic Ragdoll (10773618503): passes and description

Creator: Emo Playworks (group). maxPlayers 1. Simulation / Physics Sim. Maturity Moderate, all ages. 90,857 CCU, 27.5M visits, 28,520 / 3,067 votes (90.3 %), 114,652 favourites.

**Passes (17, all on sale; created 10-29 unless noted):**

| Pass | R$ | What it says |
|---|---:|---|
| Everything Pass | 699 | All tools and all events, plus every other pass. Does not include vehicles. |
| Vehicle Pack | 549 | Monster Truck and Battle Tank, forever. Not in the Everything Pass. (11-01) |
| Battle Tank | 399 | Drive the Battle Tank, forever; its cannon fires. |
| Endless Events | 299 | Start every event any time with no charges, 20 s apart. |
| Monster Truck | 249 | Drive the Monster Truck, forever. Not in the Everything Pass. |
| VIP | 199 | Unlocks all KO tools now. Tools turn gold. Adds Lab Controls. |
| Plague Pack | 199 | Zombie Dart; start a Zombie Outbreak any time, 20 s apart. |
| All Powers | 129 | Every power now, forever, new ones included. |
| Double KO | 129 | Doubles every KO you earn (bought KO Boosts not doubled). |
| All Guns | 99 | Every gun now, forever, new ones included. |
| Heavy Pack | 79 | Adds the Minigun. |
| All Melee | 79 | Every melee tool now, forever, new ones included. |
| Lab Controls | 69 | Fly mode, stop time, spawn many dummies at once. |
| All Throwables | 69 | Every throwable now, forever, new ones included. |
| All Medic | 69 | Every medic tool now, forever, new ones included. (11-11) |
| Dummy Wardrobe | 49 | Pick colours for dummies' outfits and goo. |
| Demolition Pack | 39 | Rocket Launcher, plus barrels in the Lab window. |

Price ladder: 39 / 49 / 69 x3 / 79 x2 / 99 / 129 x2 / 199 x2 / 249 / 299 / 399 / 549 / 699.

**Description (verbatim):**

```
🩸 Hyper realistic ragdoll physics sandbox where every punch, shot and blast makes dummies stumble, limp and fall in a different way!

🎯 Real ragdoll physics: each body part reacts on its own
🦴 Shoot a leg and they limp, break it and they crawl
✋ Grab dummies, swing them and throw them
🔫 Unlock weapons: Katana, Sniper, Minigun, Rocket Launcher, Flamethrower and more
💥 Destroy everything: walls, towers, trees and cars break apart
🌪️ Start events: Tornado, Tsunami, Meteor Rain, Black Hole, animal raids
🦖 Wild animals: shark, crocodile, bear, gorilla, T-Rex and more
🧟 Zombies rise from the graveyard
🎡 Machines: giant fan, rocket, cannon, crusher, Fight Ring
💬 Talk to the dummies: they answer, follow orders and help each other
🩹 Play medic: X-ray broken bones, heal and revive dummies
🚗 Drive a car, Monster Truck or Battle Tank
🌅 Pick your map, weather and time of day

🎮 Supports PC, Mobile, Tablet and Console!
```

## 7. Takeaways for a kid-friendly ragdoll lab game
1. **The all-ages label is worth more than any feature.** Bloody Ragdoll Physics went from 2.5k to 21k CCU in under 10 hours once its 16+ gate was gone; HRR (Moderate, all ages) doubled to 91k. RAGDOLL HAVOC is still **Minimal 16+**. Fixing the questionnaire so the game shows as all ages (Minimal/Mild, cartoon stars, no blood) is the first job, before any marketing.
2. **The genre is growing today, and the lab niche is taken by a close rival.** The tracked games doubled against a +30 % control, so the audience is there. But [UPD] Dummy Lab 🩸 (12 days old, 7.6k CCU, Mild all ages) sells nearly our pitch: crash-test dummies, cannon/rocket sled/drop tower, X-ray replay, rank-up unlocks. We need our own angle up front: Daily Experiments that are the same for everyone, Prank Party co-op, phone/controller support, and a clean kid-safe look ("no blood" as a feature).
3. **Copy the leaders' live-ops and pass shape, not their gore.** The top 10 publish several times a day with a visible update tag. HRR's 17-pass ladder starts at 39 R$ with "All <category>" unlocks, an endless-events pass and a 699 bundle; we have 2 passes and nothing under 149. Realistic Ragdoll MMA shows that gameplay (24k CCU with 0 passes) comes first, but once players arrive we need a cheap entry pass (39-79), category unlocks and a bundle, plus a video and 5+ images on the store page.
