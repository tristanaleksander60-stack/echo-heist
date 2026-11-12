# MASTER PLAN (draft): "Rob With Your Clones" (code name Echo Heist)

_Game director's plan, written 2026-11-12. It merges the six research reports in `docs/research/` (visuals, design, tech, growth, feel, market), the prototype v0.1 code in `src/`, the LihFolk Vault V2 and fresh web and live-Roblox checks run today. Where the reports disagree, this document makes **one** call and logs it in section 0. A fact carries a source (URL, vault note in italics, or a research report); **Decision** marks our call; (H) marks a heuristic; [UNVERIFIED] marks a claim we could not confirm. All tuning numbers named here go into `src/shared/Config.luau`, never inline (CLAUDE.md rule)._

---

## 0. The ten calls that resolve the reports' conflicts

| # | Conflict | Options in the reports | **Decision** | Why |
|---|---|---|---|---|
| C1 | Store title | "Rob With Your Clones" (growth) vs "Repeat Offenders" (market) | **"Rob With Your Clones"** as the Roblox title; "Heist Yourself" as slogan and hashtag; "Repeat Offenders" kept as the fallback brand | Verb + noun in kid vocabulary, next to two proven search clusters (rob/heist, clone); "Repeat Offenders" has no search lift (§2) |
| C2 | Player-facing noun | "echo" (design, visuals, feel) vs "clone" (growth) | **"clone"** in all UI, store and marketing text; `Echo` stays in code and docs | Matches the title and kid vocabulary |
| C3 | Clone caps | design: 12 clones per server, solo 8/duo 6/trio 4/quad 3; tech: 16 clones, 8/6/5/4 | **12 clones per server at launch** (plus up to 4 players = 16 robbers), per-player cap `min(owned, floor(12 / players))`, so 8/6/4/3. Raise the server cap to 16 only after the phone bench passes | Quantum League found 12 the readable ceiling ([MP1st](https://mp1st.com/news/nimble-giant-entertainment-talks-about-their-latest-time-bending-shooter-quantum-league)); avatars are the biggest phone cost |
| C4 | Rewind length | 2.5 s (visuals) vs 1.8 / 1.0 / 0.8 s (feel) | **1.8 s standard, 1.0 s quick (automatic from the 4th rewind), 0.8 s reduced motion** | 2.5 s every 30 s loop eats 8% of playtime (feel D1) |
| C5 | Clone palette | Cyan/Magenta/Violet/Lime (visuals) vs Cyan/Magenta/Indigo/Ghost White plus glyphs (feel) | **Feel's set plus a mandatory shape glyph and number** (●1 ■2 ▲3 ◆4) | Visuals' set fails the colour-blind audit (0.051-0.056) |
| C6 | Rewind control | all-player vote (v0.1) vs per-player "End take" (design) | **Per-player End take (tap R) and Scrap take (hold R 0.6 s)**; the loop ends when every live take has ended or the timer hits 0 | No player can force another to rewind |
| C7 | Getting caught | sent home (v0.1, feel's "tape-eject wipe home") vs take ends (design) | **Your take ends on the spot** (1.2 s BUSTED beat), you become a spectator ghost until the loop ends, and your clone of that take repeats the mistake next loop | The built-in "my clone repeats my mistakes" clip |
| C8 | Stakes / deadline | no fail state (design) vs a deadline (market) | **Story heists: no fail state, medals are the stakes. Vault of the Day and weekly Contracts: hard "Dawn" after N takes** | No hard walls for kids; real stakes in competitive modes |
| C9 | Launch date | soft launch Dec 3 (growth, design) vs Dec 8-12 (market) | **Soft launch Thu Dec 3, with a go/no-go on Mon Nov 30; fallback Tue Dec 8.** Christmas chapter 1 and RFY on Fri Dec 11 either way | The under-16 gate must clear before the US winter break (most districts Dec 21 - Jan 4, [us-school-calendar](https://us-school-calendar.com/winter-break-2026-2027)) |
| C10 | Location ladder | bank, museum, casino (design) vs rename casino (growth, market) | **Corner Shop → Bank → Museum → Sky Lounge (a penthouse jewel lounge, no gambling) → Moon Base** | Breaks *Rewind Robbers*' identical ladder ([Playgama](https://playgama.com/game/rewind-robbers)); no gambling-rating risk |

Smaller calls: record at **20 Hz** (not 15); **≤ 2** clone accessories (not 3); Highlight limit is **255** (docs, Nov 2025), so tech's "31" is superseded; draw calls **350 target / 600 ceiling** (not 600/1,000); **6k** level-art instances and **25k** live client instances; guard grace **0.35 s**; guard "huh?" freeze **2.0 s**; no 3-2-1 countdown (the "TAKE n" stamp on the downbeat is the GO); Kids & Select threshold planned at **250** plays, budgeted at 500 (§9.5).

---

## 1. Vision and pillars

### 1.1 One-sentence pitch

**"A co-op heist where your crew is you: every take is recorded, and on the next one your past selves replay it, until eight of you rob the vault in perfect sync."**

Store description, line one: *"Rob it with your clones! Every 30-60 second take is recorded. Rewind, and your past self runs your plan while you do the next job. Solo or with up to 3 friends: 16 robbers, 1 vault."*

### 1.2 Pillars (every feature must serve at least one)

1. **Your crew is you.** The clone is the star, readable in under half a second at 64 px with the sound off; nothing else may glow in clone colours.
2. **Mistakes are content.** Clones repeat your errors exactly and fail out loud, comically. A failure is a clip and a clue, never a punishment.
3. **Fast takes, no redo-everything.** 30-75 s loops; retake one clone without replaying the chain; a heist takes minutes.
4. **Solo complete, friends multiply.** Every level is solvable alone; 2-4 friends make it a 16-robber party.
5. **Premium diorama craft.** Neon-Noir model-kit look, tape-caper music, a satisfying rewind: "Steam indie" through coherence, not photorealism.

### 1.3 What we will NOT do

- No guns, blood, gore, jump scares or playable gambling: target the **Mild** label.
- No paid randomness, Robux-to-Cash, pay-to-skip, paid hints, or prompts during a heist.
- No "puzzle game" positioning: *ECHOES: Clone Puzzles*, the same mechanic, sits at **0 CCU with 20,926 visits** (games API, today).
- No borrowed IP (PAYDAY, Monaco, Jailbreak, Notoriety, Entry Point, Hitman, Ocean's, Ultra Ultra's ECHO), no heist masks, no green furry Christmas villain.
- No Toolbox assets, shipped AI meshes or AI textures.
- No gameplay that needs chat or voice; no rewards for likes, shares or watching media.
- No physics-driven gameplay objects, and no separate stealth/loud modes (Payday's "two games" trap).

---

## 2. Name and brand

### 2.1 Top 3, with conflict-check status (checked 2026-11-12)

| Rank | Name | Roblox search (`tools/rbx_search.py`) | Web search | Trademark (EUIPO/USPTO cl. 9/41) | Status |
|---|---|---|---|---|---|
| **1** | **Rob With Your Clones** | Clean. Neighbours: "Build Anything With Clones!" (192 CCU), Heist Evolution, Clone Engine | No game found (WebSearch today) | Not checked [UNVERIFIED] | **Recommended store title** |
| 2 | **Heist Yourself** | Clean. Neighbours: Heist Evolution, "Knock Yourself Out!" | No exact title; *Heist Simulator* (No More Robots) is nearby but different | Not checked | Slogan and hashtag (#heistyourself); fallback title |
| 3 | **Repeat Offenders** | Clean, but nothing relevant surfaces (no search lift) | Singular "Repeat Offender": a 2021 Trijam game ([itch](https://theoclarke.itch.io/repeat-offender)) and an s&box jam game about "versions of your past self" ([itch](https://matt9440.itch.io/repeat-offender)); a GTA Vice City trophy | Not checked | Fallback **brand** if the owner wants a premium coined name |

Rejected: **Echo Heist** (two itch.io games, one with the same concept: [nitrous-studio](https://nitrous-studio.itch.io/echo-heist), [Geronimokuwait](https://geronimokuwait.itch.io/echo-heist); plus Roblox "ECHOES" titles and Danish Ultra Ultra's ECHO). **Rewind Robbers** (Playgama, same concept). **Loop Heist** (HAESO GAMES press release, [COGconnected](https://cogconnected.com/2026/10/loop-heist-browser-demo-turns-your-recorded-moves-into-a-heist-partner/), plus jams). **Rob It Again** (confusable with ROB IT, 315M visits). **Crew of Me** (no verb, unsearchable).

**Decision:** launch as **"Rob With Your Clones"** (seasonal tag "[🎄] Rob With Your Clones"), confirmed by the owner by **Mon Nov 16**, before any icon, thumbnail or devlog uses a name; trademark searches the same week (not legal advice). `docs/IDEA_ECHO_HEIST.md`'s line "no game uses recordings of your past runs" is now false: the mechanic exists; what is ours is the co-op heist with everyone's clones at once.

### 2.2 Brand system

- **Motif: the tape.** A loop is a **take**, the timer is a **tape counter**, the rewind is a **tape rewind**, the replay is **"the tape"**, level select is a shelf of VHS tapes. It is original and explains the mechanic without words (feel D1).
- **Mascot:** "the Rookie", an original unmasked robber with a flat cap, long scarf and smug side-eye; human-finished, with an AI provenance log.
- **Antagonist:** **Gus, the night guard** (huge flashlight, donut box, readable double-take): the threat with a face (market F2).
- **Event villain:** **Sir Hoardsworth**, a tall, thin toy tycoon in burgundy-and-gold velvet with a monocle; never green or furry.
- **Wordmark:** chunky rounded capitals with a cyan "double-exposure" offset copy behind them.

---

## 3. Core game

### 3.1 The loop (take) rules

| Rule | Value / behaviour | Config key |
|---|---|---|
| Loop length by location | Corner Shop **30 s**, Bank **45 s**, Museum **60 s**, Sky Lounge **60 s**, Moon Base **75 s**, Christmas **45 s**, Vault of the Day **30 s**. Hard ceiling 90 s | per level in `LevelData`, `LOOP_MAX_SECONDS = 90` |
| Start | The rewind ends with the "TAKE n" stamp on the music downbeat; control returns at 1.8 s; the clock starts at that instant | `REWIND_TRANSITION = {1.8, 1.0, 0.8}` |
| End my take | Tap **R** / REWIND button (gamepad Y). Your recording stops; the clone holds its last pose in later takes; you become a free-camera spectator until the loop ends | `MIN_LOOP_SECONDS = 2` |
| Scrap take | Hold **R** 0.6 s. The take is thrown away; no clone is made | `SCRAP_HOLD_SECONDS = 0.6` |
| Loop end | All live takes ended or scrapped, or the timer hits 0 (counts as "End my take", with a "tape runs out" flap) | — |
| Solo skip-ahead | Solo only: hold **F** while standing still to run the loop at 3x (recorded as standing). Cancels on move | `SKIP_SPEED = 3` |
| Caught (live player) | 0.35 s detection grace, then the take ends with a 1.2 s BUSTED beat (§7) | `GUARD_DETECT_SECONDS = 0.35` |
| Persists inside a heist | Banked loot, "Prep" shortcuts (unscrewed vent, cut window), ghost trails of your last 3 takes, timed floor markers | — |
| Resets every loop | Guards, cameras, lasers, doors, carried (unbanked) loot, gadget charges, alarm level | — |
| Across heists | Cash, Stars, upgrades, cosmetics, medals. Clones never carry between heists | — |
| Fail state | **None in story heists.** After 8 takes without progress the hint ladder escalates. Vault of the Day and Contracts have a **Dawn** after N takes (default 6) | `DAWN_TAKES = 6` |
| Plate grace | 0.4 s after release, shown as a draining cable | `PLATE_GRACE = 0.4` |
| "Simultaneous" | Two actions within 1.0 s count as together; no window under 1.5 s anywhere | `SIMUL_WINDOW = 1.0` |

### 3.2 Clone rules

1. **A clone is a ghost on rails.** It replays recorded position, yaw and pose flags at 20 Hz plus timestamped intent events (grab, release, press, hold start/end, gadget, emote). It never collides with players.
2. **Its actions are re-validated.** Every intent goes through the same `Interact.request` path a player uses. If the world differs from the recording, the clone fails **visibly, with a cause**:

| State | Trigger | What you see (Mild) | Timeline marker |
|---|---|---|---|
| **Bonk** | Its path crosses a closed door's box | Flattens like a cartoon, stars, then shrugs and holds position | red ✕ at t |
| **Zap** | Walks into an active laser | Soot puff, hair stands on end, stylised flop (client-side cosmetic ragdoll) | ⚡ |
| **Busted** | Seen by Gus | Gus freezes 2.0 s with "?" (the "WRONG ONE" clip), the clone glitches into tape ribbons | 👮 |
| **Shrug** | Grabs loot that is gone, presses out of range | Shrug emote, "?" bubble | ? |
| **Stuck** | Path blocked by another dynamic blocker | Holds pose with a "..." bubble | ... |

3. **Determinism contract:** the world at loop time t is a pure function of (level, loop seed, actor positions and events up to t): time-parameterised guard paths, A* on authored waypoints, `Random.new(levelSeed + loopIndex)`, stable actor order. Two loops with no live player moving give identical event logs; CI proves it.
4. **Physical items are single.** If a clone carries the keycard, it carries it along its recorded path. A live player can take it only where a clone drops it ("hand-off"). This prevents Talos-style duplicate softlocks ([Thinky Games](https://thinkygames.com/features/the-talos-principle-reawakened-isnt-just-a-graphical-revamp-its-the-perfected-edition-of-a-modern-classic)).
5. **Cameras ignore clones** ("cameras see heat; clones have none"). Gus sees them. This gives two threat types with different rules, which is a puzzle lever.
6. **The Clone Deck:** your clones as cards. **Retake** one (the next take replays the others while you re-record that slot) or **Delete** it; only your own. This is the anti-"redo everything" fix, after *Talos Principle Reawakened*.
7. **Caps.** Owned slots start at **4**; slots 5 and 6 cost Cash (about 15 and 45 minutes of play); 7 and 8 unlock with Stars (20 and 35). The level's cap is `max(owned, level.minCap)`, so story levels always provide what par needs, and the Christmas Snow Globe Vault grants 8 to everyone. Per-player cap in co-op: `min(cap, floor(12 / players))`.

### 3.3 Solo vs co-op

- **Solo** is the default and complete: every level is designed and CI-tested against a solo solution recording.
- **Launch topology (decision, simpler than design.md's hub):** one place, **4-player servers**, join-in-progress (a joiner enters at the next take). The **crew leader** (longest-present player) picks the level; everyone earns its medals. **Private servers are free**, since they count as intentional co-play ([Discovery docs](https://create.roblox.com/docs/discovery)).
- **Jan 22 co-op update:** a public **Hub** with hideouts, and heists in **reserved crew servers**, which count as co-play since December 2025 ([Dubit](https://dubit.io/blog/roblox-top-20-rfy)).
- **Chaos control:** all crew clones replay together with colour + glyph per player and one take-bar row each; levels scale by *actors* (a scale vault needs `max(4, players + 2)`); Gus gets +10% vision per extra player.
- **Soft roles:** each player brings one gadget (Noisemaker, Smoke Puff, Magnet Glove, Grapple, Hacker Phone).
- **Talking without chat:** a 6-option ping wheel ("Here", "Wait", "Go", "Guard!", "Plate", "Need 2") and **timed floor markers** ("be here at 0:24") that persist across takes. Chat requires an age check worldwide ([Roblox IR](https://ir.roblox.com/news/news-details/2026/Roblox-Requires-Users-Worldwide-to-Age-Check-to-Access-Chat/default.aspx)).
- **Anti-grief and fairness:** no player collision; nobody can touch another player's clones; loot splits equally; +10% Cash per friend, capped at +30%.

### 3.4 Controls

Default Roblox movement on every device. **Interact** E / tap prompt / X. **End take** R / 72 px REWIND button / Y (hold = Scrap). **Clone Deck** Q / tap strip / LB. **Blueprint** hold TAB / map button / View. **Ping and marker** G / long-press / RB. **Skip-ahead** hold F / ⏩ button / B. All through the Input Action System; every input gets a pop and a sound within 100 ms (vault *Game Feel and Juice*).

### 3.5 Camera

- Roblox third-person: zoom 16 studs (min 8, max 28), FOV 70, slight downward bias in diorama rooms. Walls between camera and player fade to 0.7 transparency (client raycast at 10 Hz).
- **Blueprint plan view:** top-down, FOV 30 at about 120 studs, deep-blue grade and a grid floor, clone routes drawn as Beams (sampled every 0.5 s), plates with cables, Gus's route and cone, loot values. Off the clock: available from the van before take 1 and between takes.
- **Heist Reel** (end of heist) and the rewind camera are in §6.5 and §7.1.
- Comfort: never roll the camera; FOV kicks off under reduced motion.

---

## 4. Content plan

### 4.1 Mechanic introduction curve

Every verb is taught **Show → Try → Test → Combine**; a new verb combines only with known ones; a breather follows every hard combination (vault *Teaching Through Level Design*). "Show" is often a **Mentor tape**: a gold, pre-recorded developer clone performing the step once. Par solutions must take at most `par takes × loop length × 1.5` to execute.

### 4.2 Launch levels (Dec 3 soft launch: L1-L8; minimum shippable: L1-L5 + L8)

| # | Location (loop) | Level | Teaches | Par clones | Big moment |
|---|---|---|---|---|---|
| 1 | Corner Shop (30 s) | **Back Room** (FTUE) | Plate holds a door; Rewind; the clone exists | 1 | "That's you, 10 seconds ago." |
| 2 | Corner Shop | **Two Doors** | Two plates; End take vs Scrap | 2 | First 3-of-you shot |
| 3 | Corner Shop | **Lights Out** | Laser grid switched by a plate; Zap | 2 | Your clone zaps itself on cue |
| 4 | Corner Shop | **Night Clerk** | Gus: busts clones, catches you; **Retake** (the natural first path gets your clone busted next take) | 2 | First "WRONG ONE" |
| 5 | Bank (45 s) | **Teller Line** (breather) | Timed button; reading the take bar icons | 2 | — |
| 6 | Bank | **Keycard** | Single item hand-off | 3 | "My clone walked off with the card" |
| 7 | Bank | **Vault 101** | Heavy loot needs 2 carriers (you + your clone) | 3 | The slow two-person safe carry |
| 8 | Bank | **The Big Score: Bank** | Scale vault needs 4 actors + Gus | 4 | First Heist Reel worth posting |

Each location also unlocks **Free Roam** (randomised loot positions, Cash farming, no medals).

### 4.3 "Steal Back Christmas" (Dec 11 - Jan 4)

- **Story:** Sir Hoardsworth has vacuumed every present in town into his Snow Globe Vault; your crew steals Christmas back before morning.
- **Chapter 1, Fri Dec 11: "Wrapping Room"** (Toy Shop). Conveyor belts and gift-wrap lasers (still Alarm Red, candy-cane striped emitters).
- **Chapter 2, Fri Dec 18: "Nutcracker Patrol"** (Gift Factory). Toy-soldier guards and **Snow Footprints**: live players leave footprints that guards follow for 6 s; clones leave none, so the clones become the safe route.
- **Chapter 3, Thu Dec 24: "The Snow Globe Vault"** (published Dec 22, unlocked by server time). A scale vault of 8 (everyone gets 8 slots in this level) plus the **Giant Present**, heavy loot with 4 grips. If time runs short, cut the Giant Present before cutting the advent run.
- **"12 Vaults of Christmas"** (Dec 13-24, catch-up to Dec 31): one 30-second mini-vault per day, built from modules, with a fixed advent reward (deterministic, never random).
- **"Presents recovered" meter** (server-wide via MessagingService every 30-60 s) unlocks decorations and a Dec 25 finale. **Candy Canes** (earned only) buy the event track: Santa clone style, sleigh van, snow-globe trophy.
- **"Midnight Vault"** (Dec 31 - Jan 4) reskins the Bank for New Year. Event art comes off Jan 5; cosmetics stay owned.

### 4.4 Post-launch

| Date (Fri, 17:00 CET) | Drop | New verbs |
|---|---|---|
| **Jan 8** | **Museum** (60 s): Gallery, Dinosaur Hall (breather), Night Watch, The Big Score: Crown. New gadget: Noisemaker | Cameras (clones invisible), vents (one actor at a time), noise distraction, alarm levels (0-3 in 5-tick chunks) |
| **Jan 22** | **Co-op update + Season 1** (5 weeks): Hub and hideouts, reserved crew servers, "Crew Vaults" that need 2+ live players, crew leaderboard, free cosmetic ladder | Two-player-only mechanisms |
| ~Feb 5 | **Sky Lounge** (60 s): Lobby Floor, Count Room, Elevator Bank (breather), The Big Score: Jewel Suite | Twin switches within 1.0 s, safe cracking under patrol (hold 4 s), scheduled elevators |
| ~Feb 26 | **Moon Base** (75 s): Low Gravity, The Big Score: Moon Rock (scale vault 8, two heavy loots) | Long jumps, airlock timers |
| Weekly | Vault of the Day stays daily; a **Contract** modifier rotates weekly ("Lights Out", "Faster Guards", "Mirror Map") | — |

Market's rule applies: cut Moon Base if the numbers do not justify it (market risk 14).

---

## 5. Progression, retention and monetization

### 5.1 Economy (one job per currency)

- **Cash:** soft currency from banked loot. Spent on clone slots 5-6, gadgets (5-20 minutes of play each, plus level-2 versions), van skins and trophies (3-60 minutes).
- **Stars:** from medals, never sold. Gate locations and slots 7-8.
- **Candy Canes:** event-only, earned only.
- No Robux-to-Cash, ever. That keeps every random reward exempt from the paid-random-items rules (docs updated 2026-10-15, [Roblox Docs](https://create.roblox.com/docs/production/monetization/paid-random-items)).

### 5.2 Medals and gates

- Per level, 3 Stars: **Haul** (bank the target value), **Crew** (finish with at most par clones *used*), **Clean** (no catches and no busted clones in the final take).
- A shown-but-optional fourth **Diamond** medal: beat the developer's clone count ("DEV: 4 CLONES. ME: 3" clip).
- **Gates:** Bank 5 Stars, Museum 14, Sky Lounge 26, Moon Base 40 (of 54 regular Stars once all 18 levels exist). The next-goal card always shows the number.
- "Relaxed Time" (1.5x loops) earns medals but is flagged and excluded from leaderboards.

### 5.3 Retention hooks

| Horizon | Hook |
|---|---|
| Session | Next-goal card on every exit ("2 more Stars unlocks the Bank"); the Heist Reel; Free Roam |
| **D1** | **Vault of the Day:** one module-built heist per UTC day, same on every server, fixed loadout (5 clones, no owned slots), Dawn at take 6, global board for **fewest clones, then fastest final take**. First clear: 1 Star + fixed Cash. Daily streak with one grace day |
| D7 | Weekly Contract with a modifier; weekly crew board; a new drop every 1-2 weeks through February |
| D28 | 5-week Seasons with a free cosmetic ladder from Stars and dailies; "Legend" frame for 3-starring a location; hideout trophies others can visit (from Jan 22) |

Dig to Escape simplicity check: one goal, a visible threat (Gus), a number that grows (Cash), a shop. **Never more than 3 meters during a heist** (timer, haul, clones).

### 5.4 Monetization (ethical and 2026-compliant)

**Hard rules:** no paid randomness; no Robux-to-Cash; no pay-to-skip, paid hints, retakes or loops; no prompt during a heist or on a bust; at most one unprompted offer in a non-payer's first session, after Level 1. All prices from `GetProductInfoAsync`; exactly one idempotent `ProcessReceipt` (lihfolk-systems `Receipts`).

| Product | Price (R$) | Timing |
|---|---|---|
| **Clone styles** (VHS Glitch, Gold Ghost, Noir, Pixel, Neon Outline) | 79-199 each | Launch |
| **Clone emotes** (your clones perform it at a recorded moment) | 49-99 | Launch |
| Rewind styles, van skins | 79-149 | Launch |
| **Starter Crew pack** (style + van skin + emote, cosmetic only) | 199, once | After Level 1 |
| **Christmas Crew pass** (fixed, shown-upfront cosmetic ladder) | 249 | Dec 11 |
| Private servers | **Free** | Launch |
| **Rewarded video** "double this heist's Cash", 5/day, 13+ only | — | When eligible (the docs say ~2,000 monthly visitors and an ID-verified owner, [docs](https://create.roblox.com/docs/production/promotion/rewarded-video-ads); older posts said 100K DAU) |
| +1 clone slot pass | — | **Not at launch.** Owner decision after D7 data (§11) |

Revenue is not the launch goal; D1, D7 and co-play are.

---

## 6. Art direction and style bible

### 6.1 The look: "Neon-Noir Diorama"

Chunky, bevelled low-poly sets built like a model kit, lit at night in deep indigo (never black) with warm pools of light, and one glowing colour family reserved for clones. References: Hitman GO's miniature board ([Game Developer](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense)), Monaco 2's readable 3D, Teardown's simple shapes under rich light. It scored 8.5/10 against realistic PBR (4/10, Notoriety's look) and full toon (6.5/10) (visuals D1). On Roblox "premium" means coherent and readable (Pressure's palette is its brand, vault *Teardown - Pressure*).

**Shape rules:** props 1.5-2x real scale, buildings ~1.2x; one-segment bevels only (0.06-0.08 studs small, 0.12-0.2 medium, 0.2-0.3 building corners); one focal feature per prop at ≥ 1.5x any secondary; one storytelling prop per room (Gus's donut box). Each level is a cut-away model on a dark, hazy "table".

### 6.2 Palette and colour language

| Role | Name | Hex | Rule |
|---|---|---|---|
| Base shadow | Ink Indigo | `#1C1F3B` | Never darker |
| Base mid | Plum Slate | `#3A3560` | Most walls, 30-55% value |
| Lit interior | Warm Marble | `#D8C8A8` | Inside light pools |
| Metal | Vault Steel | `#7C86A6` | Doors, safes, rails, **plates** |
| **Danger** | Alarm Red | `#FF3348` | Lasers, alarms, "seen!" only; always with a shape (beam, zigzag, ring) |
| Guard light | Torch Amber | `#FFD27A` | Flashlight cones only; shape = cone |
| **Loot** | Heist Gold | `#FFC21F` | Loot only; shape = sparkle (Gold vs Amber fails colour-blind at 0.051, so shape carries it) |
| Exit | Getaway White | `#F4F7FF` | Van and chevrons, always with an arrow |
| **Clone P1 / solo** | Clone Cyan | `#3DE8FF` | Reserved |
| Clone P2 | Clone Magenta | `#FF4FD8` | Reserved |
| Clone P3 | Clone Indigo | `#6A5CFF` | Reserved |
| Clone P4 | Ghost White | `#F4F7FF` | Reserved for clones as a glow; exit uses the same white only as solid chevrons with arrows |

- **Reserved-hue rule:** no environment asset within ±20° of a clone hue at saturation above 40%. The v0.1 blue plate (`60,140,255`) becomes a steel plate with a white icon that takes the presser's hue and glyph.
- **Identity = glyph + number + hue.** ●1 ■2 ▲3 ◆4 badges are mandatory, not a setting.
- **CI audit (Lune):** Oklab distance ≥ 0.15 for small signals and ≥ 0.20 plus a shape for danger, run on every palette change (vault *Colour-Blind Safe Design*). Greyscale test: characters, loot and danger differ from the ground by 15% value or more.

### 6.3 Lighting: "Heist Night" recipe v1 (data, one `LightingController` owner)

- `Lighting`: LightingStyle **Realistic**, PrioritizeLightingQuality **true**, GlobalShadows on, ClockTime 0, Brightness 0.5, Ambient (55,55,95), OutdoorAmbient (75,80,130), ColorShift_Top (255,210,160), EnvironmentDiffuseScale 0.25, EnvironmentSpecularScale 0.35, ExposureCompensation 0.2 ([Unified Lighting](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512)).
- `Atmosphere` (streets only): Density 0.3, Color (70,60,120), Decay (35,30,75), Haze 0.8.
- `BloomEffect`: Intensity 0.8, Size 28, **Threshold 1.0** (0.5 intensity on the Performance tier). `ColorCorrection`: Contrast 0.12, Saturation 0.1, Tint (235,230,255). Default tonemapper. No SunRays. DepthOfField and Blur only in menus, the plan view and the reel.
- **Local lights:** shadows off by default; at most 4 shadow-casting hero lights per view; fake other light pools with floor decals or transparent Warm Marble discs; sleep lights beyond 120 studs.
- **Kill switch:** under 30 fps on a low Android (2-3 GB, Automatic) → switch to **Soft**, keep the colours. The look must read with **no shadows**, since phones at quality 1-3 draw none (vault *Stylized Lighting Recipes*; re-check on a device).
- Per-location recipes: Christmas Eve (warmer, Ambient +10%), Museum (cold moonlight), Sky Lounge (gold on plum), Moon (grey and white; cyan reads strongest).

### 6.4 Materials and textures

- **SmoothPlastic + `MeshPart.Color`, or one 256×256 palette atlas per kit** with UVs snapped to cells, so kit pieces instance.
- At most 3 hero SurfaceAppearances per level (vault door, diamond, event centrepiece): Color + Roughness at 1024 plus an **emissive mask** (live in published games, [DevForum](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705)). Emissive masks also drive signage, vault dials and Christmas lights instead of extra Neon parts.
- Neon at most about 1/6 of an object's pixels. No EditableMesh or EditableImage in the core.

### 6.5 The clone look (the hero visual)

Goal: "that's me, but a ghost from 20 seconds ago", readable at 64 px.

1. **Client-side rigs** (§8): built once per owner from `Players:CreateHumanoidModelFromDescriptionAsync`, pooled, never replicated.
2. **Stripped silhouette:** no SurfaceAppearance, textures, decals, face or layered clothing; at most 2 accessories (hair or hat); all parts SmoothPlastic tinted in the owner hue at Transparency 0.45; `CastShadow = false`. Note: SLIM optimisation does not apply to NPC rigs, so clones pay full avatar cost unless stripped ([SLIM docs](https://create.roblox.com/docs/workspace/streaming/slim)).
3. **Rim, not fill:** one persistent **Highlight per owner group** (at most 4): OutlineTransparency 0, FillTransparency 0.85, DepthMode Occluded. Animate properties; never create or destroy per loop (adding one can trigger a geometry rebuild; the first costs up to ~1 ms GPU on mobile, [Roblox docs](https://create.roblox.com/docs/en-us/effects/highlighting)). One extra **x-ray** group (AlwaysOnTop, OutlineTransparency 0.6) for *your* clones standing on plates behind walls.
4. **Age ramp:** each older take is 12% dimmer and +0.05 transparency; in solo only, older takes also drift up to 25° toward violet (the "8 copies" gradient).
5. **Badge and trail:** a 28 px glyph badge ("●3"), hidden beyond 40 studs; a 0.5 s owner-hue Trail only above walk speed.
6. **"Tape print" spawn:** clones form in record order 60 ms apart (stagger ≤ 0.4 s), with a scanline sweep, a floor ring and a rising chime (§7.2). Busted: glitch slices, then a tape-ribbon burst (≤ 30 particles).
7. **Readability guards:** 3+ clones within 2 studs show the newest fully and the rest outline-only with an "×3" badge; clones within 6 studs of the camera fade to 0.8; a clone-opacity slider (50-100%). Players stay opaque and shadow-casting; other players' clones render at 70% brightness on your screen.
8. **Open A/B and fallback:** Tint vs ForceField chosen on a phone in week 1; if one stripped clone costs more than 25 draw calls, clones beyond 60 studs swap to a shared "hologram mannequin".

**Gus and threats:** a flat floor cone in Torch Amber (Transparency 0.75, Neon edge, clipped by a 12-ray fan at 10 Hz), drawn from the same `Guards` module the server uses; the cone flashes red with "?" then "!" on detection. Lasers: dark-ink core, red body, thin white-hot core, red floor dot, 3 flickers before re-enabling.

### 6.6 Presentation

- **Rewind:** §7.1.
- **Heist Reel** (after every heist, 12-15 s, skippable after 1 s): the final take replayed client-side; 3 auto-picked shots (wide diorama, tracking the loot carrier, a hero moment at 0.35x for 1.5 s); a burned-in caption ("TAKE 6 · 8 OF ME · $1,000"); the subject kept in the **central 32% of frame width** so a 9:16 crop survives; HUD, chat and nameplates hidden. Optional Blueprint opening and "Then/Now" split.
- **Live slow-mo (cosmetic):** last loot banked with < 3 s left slows local animations to 0.5x for 0.6 s.

### 6.7 Asset pipeline

- **Model:** every shipped mesh comes from Claude's Blender scripts through the `roblox-blender-modeling` gates (A1-A18, visual rubric ≥ 14/18, no zeros). Budgets: small 600/1,500 tris, module 800/2k, hero 10k/20k; Gus is a 5k-tri rig. The LihFolk Asset Pack is not installed here, so there is no shortcut.
- **Golden assets first (W1-W2):** the vault door (8-10k tris, emissive dial), a bank wall module + counter, gold bars + diamond, Gus, and the clone look as a reference clip. The owner signs them off as the single **style owner** (vault *What Craft Looks Like on Roblox*).
- **Kits:** bank kit (~35 modules); the corner shop reuses ~50% through an atlas swap; Christmas reskins the bank kit.
- **Buy / generate:** nothing from the Toolbox; licensed SFX only; AI images for moodboards and Roblox Cube for blockout ideas only.
- **Audit and bible:** `budgetReport(root, "mobile")` (`LihFolkWorld.luau`) via Open Cloud against the test place, diffed per pass; `docs/STYLE_BIBLE.md`, 6 pages of numbers, not adjectives (vault *Style Bibles for Consistent Models*).

### 6.8 Mobile budgets (busiest view: the vault with 4 players, 12 clones and 2 guards)

| Budget | Target | Ceiling |
|---|---|---|
| Frame time | ≤ 16.6 ms on a mid Android (~4 GB) | 33 ms on a low Android (2-3 GB) |
| Draw calls | ≤ 350 | 600 ([Roblox docs](https://create.roblox.com/docs/performance-optimization/design)) |
| Triangles in view | ≤ 300k | 600k |
| Level art instances | ≤ 6k | 10k |
| All live client instances | ≤ 25k | 40k |
| Live particles (touch) | ≤ 360 | — |
| Highlights | ≤ 4 clone groups + 6 others | — |
| Textures per level | 1 atlas (256) + 1 trim sheet (1024) + ≤ 3 hero sets × 2 maps ≈ 10 "1024-equivalents" | — |
| Shadow-casting local lights | ≤ 4 per view | — |
| Client memory | ≤ 60% of device memory | 75% |

Presets Auto / Performance / Balanced / Quality; clones, cones and lasers are **exempt from culling**.

---

## 7. Game feel, audio, VFX, UI/UX and onboarding

### 7.1 The Rewind (the signature moment)

A client `RewindDirector` owns the sequence; the server only waits `Config.REWIND_TRANSITION` (the prototype's hard-coded `task.delay(0.9)` in `Main.luau` moves to Config).

| t (s) | Picture | Sound |
|---|---|---|
| 0.00 (input) | Button presses in; co-op pip fills | Tape-deck "clack", played locally before any server reply |
| 0.00 (server) | 66 ms freeze, 0.06 s white flash at 25% | Music PlaybackSpeed 1.0 → 0.25 over 0.3 s (tape-stop dive; verify pitch follows speed in Studio) |
| 0.10-1.35 | Saturation -0.8, cyan tint, Blur 6, VHS tracking bands, "◀◀"; **every actor's path reels backwards** as owner-coloured Beams (once client replay lands, the avatars themselves at ~25x); FOV 70 → 64 | Pre-reversed 1.2 s stinger (Roblox can't play audio backwards, [DevForum](https://devforum.roblox.com/t/how-can-i-make-a-sound-play-in-reverse/1847141)) |
| 1.35-1.55 | Grade snaps back; clones "tape print" in | "Clunk" on the bar line, then the clone arpeggio |
| 1.55-1.80 | "TAKE 4" stamps in (UIScale 1.25 → 1.0, Back Out) | Music restarts on the downbeat |

Quick (1.0 s) drops the path reel; reduced motion (0.8 s) is a crossfade. Effects live under `CurrentCamera`, not `Lighting` as in v0.1.

### 7.2 Audio direction: "tape caper"

- Upright bass, brushed kit, Rhodes/vibraphone, muted trumpet, analogue pad, light tape saturation and wow.
- **128 BPM**, so every loop is whole bars (30 s = 16, 45 s = 24, 60 s = 32, 75 s = 40); the music restarts on GO and the last 4 bars are the countdown.
- **Crew Layers:** S0 base always; S1 keys at 1+ clones; S2 lead at 3+; S3 brass at 6+; S4 full at 10+; S5 tension in the last 4 bars or on Gus's "!". All stems start sample-aligned with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()` (vault *Music and Adaptive Audio*); layers change only on GO.
- **Sourcing:** soft launch uses licensed library tracks on two crossfaded decks; **commission 3 stemmed tracks** (Shop, Bank, Christmas) with trailer rights (price [UNVERIFIED]). Library music off-platform is [UNVERIFIED], so **TikToks and trailers use owned music only**.
- **The clone arpeggio** (C-major pentatonic, one step higher per clone, 60 ms apart) is the game's sound logo.
- **Clone bus:** lowpass 5 kHz → 90 ms echo, 4 dB under player sounds; no clone footsteps; ≤ 6 clone sounds per second, nearest 4 voiced. Buses: Music, SFX (+ Clone), UI, Ambience, Warnings (Alerts floor 25%) → compressor → limiter.
- ~38 licensed launch SFX, 3+ variations for anything repeated, with an id manifest and live load checks (lihfolk-sfx).

### 7.3 World feedback and VFX

- **Plate:** sinks 0.15 studs in 0.06 s; the rim takes the presser's hue and glyph; a pulse runs along a floor **cable** to the device, and on release the cable **drains over the 0.4 s grace**, so you see the door about to close.
- **Vault door:** red → green lamp, slides open in 0.35 s, amber blink while closing, **solid only when fully shut** (fixes the v0.1 push bug). **Lasers:** hum, retract with sparks, 3 flickers before re-enabling.
- **Caught:** 66 ms freeze, red vignette pulse, a short camera ease toward Gus (skipped under reduced motion), BUSTED stamp, brass "wah-wah", caption "[Guard spotted you]"; no shake.
- **Banking:** "ka-ching", a 24-coin burst, a "+$100" label flying to the loot meter, a 0.35-1.0 s count-up with rising ticks; clone banks show the glyph ("◆2 +$100"). The **diamond** is the only mid-heist moment that dims the world (15% for 0.6 s).
- **Heist complete:** stamp, ≤ 120 money-rain particles, **"Watch the tape"** (the Heist Reel), then a results card stamping Haul, Crew and Clean 0.25 s apart, with "x clones · y takes · m:ss", the dev's count, and Replay / Next / Save Clip.
- Every effect follows the VFX value rule (dark ink, body, white-hot core, one accent hue; vault *VFX Readability and Value*); flashes are capped at 3 per second.

### 7.4 HUD and UI

Four elements, everything else contextual:
1. **Top centre:** tape counter ("0:27") + "TAKE 3" + a thin **take bar** with icons for your clones' recorded events and red failure markers. Last 10 s pulse; last 5 s Alarm Red with a ring glyph.
2. **Top left:** loot meter "$400 / $1,000".
3. **Top right:** Clone Deck strip (glyph, digit, hue per clone; busted = grey ✕; tap for Retake/Delete).
4. **Bottom right:** 72 px REWIND button ("◀◀"; in co-op "END TAKE · 2/3").

One objective line of 8 words or fewer, shown only when it changes or when stuck. Hide-HUD keeps the counter. Text ≥ 14 px on phones, taps ≥ 48 px on the HUD, inside `CoreUISafeInsets`; tested at 7 viewports (roblox-ui-builder). Level select: VHS tapes on a shelf with medal stickers.

**Accessibility at launch:** glyph + number + colour; captions on by default; a Comfort module (reduced motion, shake slider, 3/s flash cap, FOV-kick toggle, clone opacity); **Relaxed Time**; a photosensitivity line. **Localization:** every string a key via `FormatByKey`; auto-translation covers 16 languages but **not Danish**, which needs a manual table ([docs](https://create.roblox.com/docs/en-us/production/localization/automatic-translations.md)).

### 7.5 Onboarding: Level 1 "Back Room" (first clone ≤ 30 s, first bank ≤ 45 s, ≤ 30 words)

| t | Player | Game | Text |
|---|---|---|---|
| 0-8 s | Spawns in the open van door, facing the shop | Door shut; glowing plate with a cable to it; cash visible through glass | "Step on the plate" |
| 8-14 s | Steps on and off | Door opens; the cable drains; door shuts | — |
| 14-20 s | Realises they can't hold it and go in | REWIND pulses after 2 s near the door | "Rewind. Your past self will help." |
| 20-22 s | Rewinds (forced quick rewind) | The rewind look | — |
| 22-30 s | Watches | **The clone forms (chime) and walks to the plate**; the door opens | "That's you, 10 seconds ago." |
| 30-45 s | Grabs the cash, runs | Gold chevrons to the van | "Bank it at the van" |
| ≈45 s | **First reward** | Ka-ching, coins, "TAKE 2 · $100" | — |
| 45-180 s | Laser plate needs 2 clones; medals; first Heist Reel | Objective only when stuck | ≤ 9 more words |

- **Stuck hints** at 8, 16 and 24 s: re-pulse the plate → a beam from your feet → the **Mentor tape** ghost does the step. After 2 failed takes on any level a Ghost Hint plays the solution once (free on L1-L8, 3 a day later, **never sold**). No offers during the FTUE; returning accounts can skip.
- **Funnel `onb_v1`** (server-only, `LogOnboardingFunnelStepEvent`): Joined → FirstMove → FirstPlate → FirstRewind → FirstCloneSeen → FirstBank → L1Complete → ReelShown → L2Started → FirstCloneBusted → Minute10. Targets: ≥ 90% per step, ≥ 70% reach L1Complete.

---

## 8. Technical architecture

### 8.1 What changes from v0.1, and why

v0.1 (1,824 lines) has the right core (mechanisms read `Actors`; clones obey player rules) but three structural problems: (1) clones are server Instances whose `root.CFrame` is written every Heartbeat, costing CPU, bandwidth and smoothness; (2) the world is not deterministic (the guard uses `Humanoid:MoveTo`, ticks run on `task.wait`); (3) recordings trust client-owned movement, so a speed hack replays forever.

### 8.2 Target architecture: sim core + client view

- **Server:** one fixed-step **20 Hz `HeistSim`** on loop time (Heartbeat accumulator, never `task.wait`), containing mechanisms, guards, loot, banking and the timer. **Clones are pure data** on the server: `{ownerId, slot, rec, alive, state, carrying}`, with position from `Sampler.at(rec, t)`. Plates use point-in-box, lasers segment tests, Gus raycasts to sampled points. The server stays authoritative for every gameplay outcome (CLAUDE.md rule).
- **Clients:** receive each recording **once** as a compact `buffer` over a reliable RemoteEvent and **render local rigs** at `t = workspace:GetServerTimeNow() - LoopStartAt`. Server-decided changes (busted, stuck, dropped loot) arrive as reliable events stamped with t and blend in over 150 ms. Plates light from the **server** attribute, not from the client's guess.
- **Doors, lasers, Gus** are state machines with timestamps in attributes (`DoorA_OpenUntil`); clients tween locally, the server never tweens. Late joiners get the full clone store (≤ 12 × ~8 KB) plus attributes.

### 8.3 Recording format

- **20 Hz**, sampled inside the sim tick. **8 bytes per sample:** position as three `i16` at 1/16 stud relative to the level origin (±2,048 studs), yaw `u8`, flags `u8` (grounded, jumping, crouch, carrying-heavy, 4-bit pose/emote).
- Header: version, level id, loop index, sample count, validator flags. Events: `{t_ms u16, kind u8, arg u16}`, 5 bytes each, typically < 30 per take.
- 60 s take = 9.6 KB raw, ~5 KB delta-coded. One new clone per player per take, so ~8 KB per client per rewind. Recordings never travel unreliably (the 900-byte UnreliableRemoteEvent limit, [docs](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent)).
- Playback: Catmull-Rom on position across 4 samples, shortest-arc yaw, derived velocity feeds the animation `Speed`. **Sample by time, never by frame index** (replays drift otherwise, [Messenger Mouse devlog](https://troystorygames.itch.io/messenger-mouse/devlog/945109/record-and-replay-ghost-races)).

### 8.4 Module layout

```
src/shared/  Config, Types, Tags, Scoring
  Sim/  HeistSim (pure step) · Actors · Mechanisms · Guards (path(t), A*, vision) · Loot (light + heavy grips)
        Interact (the ONLY intent entry point) · Divergence (dynamic blockers, Stuck/Confused)
  Rec/  Codec (buffer, versioned) · Sampler · Validator
  Level/LevelSpec (tags + attributes -> LevelData, asserts)
src/server/  Main.server.luau + Services/ Loop · Sim · Record · Level · Progress · Party · Analytics
             LihFolk/ PlayerData Net RateLimit Leaderboard Receipts Shop DailyRewards Quests
src/client/  Controllers/ EchoView · WorldView · RewindDirector · HUD · Input · Camera · FX · Audio · Tutorial · Comfort
levels/<id>.layout.luau  levels/<id>.solution.luau  assets/levels/<id>.rbxm  tools/levelgen/build.luau
tests/unit/*.spec.luau  tests/sim/*.spec.luau  tests/engine_smoke.luau
```

`shared/Sim/*` must not touch engine services (it takes Vector3/CFrame, plain tables, an injected clock and `Random`), so ~80% of the game logic runs in Lune. A Selene rule bans `task.wait`, `os.clock`, `math.random` and `pairs` over dictionaries in `shared/Sim`.

### 8.5 Gameplay systems

- **Interactions are intents:** `Interact.request(actor, kind, targetId)` validates range from the actor's **sim position**, target state and cooldown, then records the event; replaying clones call the same function (holds are `holdStart`/`holdEnd` with the actor in range throughout).
- **No physics for anything clones touch.** Loot and doors are anchored and placed by the sim. **Heavy loot** has `grips[]`: it moves only when `#grips >= N`, follows the grippers' centroid at ≤ 8 studs/s, and drops if a gripper is busted or leashed beyond 5 studs.
- **Clone rig:** `Humanoid.EvaluateStateMachine = false`, physics off; an Animation Graph `Blend1DNode` by Speed plus jump/land from flags and an emote layer, ≤ 4 tracks; animation LOD (full < 40 studs, 15 Hz joints to 100, none beyond, track time always advancing); all roots in one `BulkMoveTo` per frame; fall back to `AnimationController` if the Humanoid costs too much.
- **Level pipeline:** levels are Instances, not code. A Lune `levelgen` turns `levels/<id>.layout.luau` into `assets/levels/<id>.rbxm` from kit meshes, mapped to `ServerStorage/Levels`; **Rojo never maps Workspace**. Mechanisms are **tagged** (`EH_Plate`, `EH_Door`, `EH_Laser`, `EH_Loot`, `EH_HeavyLoot`, `EH_GuardPath`, `EH_Spawn`, `EH_Van`, `EH_NoGo`, `EH_Camera`) with attributes as wiring, and `LevelSpec` asserts each level at start and in tests. After a Studio edit, the last editor exports; git is the truth.

### 8.6 Networking and performance budgets

| Budget | Target | Ceiling |
|---|---|---|
| Server sim step (20 Hz) | ≤ 2 ms | 5 ms |
| Clone system CPU on client (sample + BulkMoveTo + anim) | ≤ 1.5 ms for 12 clones | 3 ms |
| Server → client steady data | ≤ 20 kbps | 30 kbps (vault *Network Bandwidth Budgets*) |
| Per-rewind burst | ≤ 40 KB | 100 KB |
| Join to playable on 4G | ≤ 8 s | 15 s |

StreamingEnabled on (MinRadius 128, Target 512, Opportunistic, `ModelStreamingBehavior = Improved`), mechanism models **Atomic**, `MeshStreamingAndImprovedLoDs` on. Clients bind through tags, never by indexing level parts. Profiling labels `EH.Sim`, `EH.EchoSample`, `EH.EchoAnim`, `EH.GuardVision`; a debug-only **bench mode** spawns 12 (then 16) synthetic clones from a fixture in the vault so the owner can test one phone alone.

### 8.7 Data

- Install lihfolk-systems `PlayerData` (90 s session lease, token-fenced saves, 30 s dirty-gated autosave, parallel BindToClose), `Net`, `RateLimit`, `Leaderboard`, `Receipts`, `Shop`, `DailyRewards`, `Quests` as-is.
- Profile slice `Heist` (< 16 KB): `schemaVersion`, `vaults[levelId] = {best = {timeMs, clones, stars, recHash}, medals}`, `unlocks`, `cosmetics`, `cash`, `stars`, `daily = {lastDay, streak}`, `ftueStep`.
- **Ghost keys** `G_<levelId>_<userId>` hold your personal-best recording (10-40 KB), written only on a new best; used for "race your best crew" and audits.
- **Leaderboards:** OrderedDataStore per `(levelId, period)`, score = `clonesUsed × 10^7 + timeMs`, written on improvement and only for untainted runs; a MemoryStore sorted map caches the Vault of the Day top 100 for 60 s.
- Budgets are per experience and shared with Open Cloud since 2026-07-29 (writes 300 + 20 × CCU per minute, [docs](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits)); call `SetRateLimitForRequestType` and make jobs self-throttle.

### 8.8 Anti-exploit

- **`RecordingValidator`** on each 20 Hz sample: horizontal speed ≤ `WalkSpeed × 1.35 + ping allowance` (leaky bucket), vertical rise ≤ jump apex + 1 stud, no segment through closed blockers or `EH_NoGo` volumes, exemption tokens for server teleports. Violations are **clamped** and the run is **tainted**: it still plays but **never earns medals or board entries**. No kicks on movement alone ([server-side detection](https://create.roblox.com/docs/scripting/security/server-side-detection)).
- Medals and scores are computed **only on the server**; board entries store the recording hash so records can be replayed headlessly in CI.
- Clients send only validated, rate-limited intents (end take, scrap take, interact, ping, marker, Clone Deck). This widens CLAUDE.md's "clients only send `RequestRewind`" rule, so CLAUDE.md is updated when the code lands.
- **Server Authority** (`Workspace.AuthorityMode = Server`, fully released July 2026, [DevForum](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993)) would make recordings trustworthy by construction, but it forces deferred signals, streaming and an 8-track Animator limit. **Decision:** launch on the validator; run the 2-day spike in a branch place during the Jan 14-20 buffer week; adopt it only if movement feels equal or better at 150-250 ms.

### 8.9 Tests

| Layer | Where | What | When |
|---|---|---|---|
| L0 Static | Local + CI | StyLua, Selene (with the Sim bans), luau-lsp, `rojo build`, LihFolk checker, Oklab palette audit | Every commit |
| L1 Unit (Lune 0.11.1) | Local + CI | Codec round trip (≤ 1/32 stud error), Sampler, Validator fixtures (walk, jump, fall, teleport, speed hack), `GuardPath.position(t)`, scoring, migrations, LevelSpec | Every commit |
| L2 Sim (Lune, headless) | Local + CI | **Determinism** (identical event-log hash twice), **solvability** (each level's `solution.luau` banks the target solo), **divergence** (door closed early → Stuck), **soak** (500 loops) | Every commit |
| L3 Engine (Open Cloud Luau Execution) | Test place | Real buffers, remotes, tag parsing of real levels, DataStore `_TEST` keys; no physics there, which suits a kinematic sim; 5 tasks/min | Merge to main |
| L4 Human | Studio, phones | §10.3 | Every milestone |

CI: GitHub Actions, Rokit-pinned `rojo` 7.7.1, `lune`, `selene`, `stylua`, `luau-lsp`; L3 secrets `ROBLOX_API_KEY`, `TEST_UNIVERSE_ID`, `TEST_PLACE_ID`. Publishing: `rojo build` → `cloud_test.py` publishes a **Saved** version to a separate **test place** → tests → the owner publishes to live by hand on a release tag.

---

## 9. Virality and launch

### 9.1 What we sell in one second

The heist headline plus the swarm payoff: **"8 OF ME"**. Clone Engine (2,063 playing, 417M visits, games API today) proves people love watching many copies of themselves; Criminal Simulator (18,487 playing, created 2026-10-08, 1-4 crew, night, sneak, deadline) proves the heist audience is hot right now; ROB IT has 315M visits since 2025-12-31.

### 9.2 Eight signature clip formats (all readable with the sound off)

| # | Hook text | What the game generates |
|---|---|---|
| 1 | **8 OF ME** | Heist Reel of 8 synced copies, burned-in caption |
| 2 | **MY CLONE BETRAYED ME** | Server **blooper log** (cause-tagged failures); the results card offers a "Blooper" cut of the 2 funniest |
| 3 | **HE DOES IT EVERY TIME** | Blooper log stitches one clone's repeat failure at the same spot into 6 s |
| 4 | **WRONG ONE** | Gus's 2.0 s "huh?" freeze, auto-bookmarked when a live player sneaks past during it |
| 5 | **THE PLAN → THE HEIST** | Reel's optional 3 s Blueprint opening |
| 6 | **DEV: 4 CLONES. ME: 3** | Diamond medal card with the Vault of the Day date seed |
| 7 | **4 FRIENDS, 16 ROBBERS** | Reel picks the angle with the most actors in frame |
| 8 | **TAKE 1 vs TAKE 7** | Reel "Then/Now" split |

Seasonal: **"STEALING BACK CHRISTMAS WITH 8 OF ME"**. Every zap and bust ends in a bloodless stylised flop, riding this month's ragdoll wave (8 of the top 28 new Roblox games, market F4).

### 9.3 Built-in replay and share

1. **SAVE CLIP** records the reel with `CaptureService:StartVideoCaptureAsync` when `CanCaptureVideo()` is true, else a screenshot; then **Save** (`PromptSaveCapturesToGallery`) or **Share** (`PromptShareCapture`, launch data `v1|reel|<levelId>`). The reference (updated 2026-10-16) documents video capture and sharing but says not all devices support media plus an invite link ([CaptureService](https://create.roblox.com/docs/reference/engine/classes/CaptureService.md)); device coverage is [UNVERIFIED] until the W3 device test.
2. Clips fit **Roblox Moments** (≤ 30 s, 13+, [newsroom](https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery)); `UploadCaptureAsync` stays behind a flag. Share links (`SocialService:PromptLinkSharingAsync`) carry a whitelisted source tag per channel.
3. **Never auto-prompt and never reward sharing or watching** ([DevForum](https://devforum.roblox.com/t/roblox-kids-and-select-new-restrictions-on-reward-driven-media-feeds/4829188)); the only social reward is a referral cosmetic after the invited friend plays 10 minutes.
4. **Owner kit:** a capture place with the same lighting, a freecam and a "director" command that replays the day's best blooper; the owner films and posts.

### 9.4 Icon and thumbnails

- **Icon:** the Rookie's face (no mask) with a smug side-eye at the viewer, two or three cyan translucent copies fanned behind, Ink Indigo with a vault-door glow, a gold glint near the eyes, no text; passes greyscale at 64 px. Santa hats from Dec 11.
- **Thumbnails** (real in-game captures, staged): T1 **8 OF ME** (hero with gold, 7 clones in a V); T2 **BETRAYED!** (hero in Gus's torchlight, a clone pressing the alarm); T3 **WRONG ONE!** (Gus holding a clone by the collar, hero tiptoeing past with the diamond); T4 **16 ROBBERS**; T5 **STEAL BACK XMAS** (replaces T4 from Dec 11). ≤ 3 words in the upper third. Four active (personalisation averaged +8.5% PTR, [DevForum](https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233)).
- **Video thumbnail** (the reel) uploaded by **Mon Nov 30**, since reviews can take weeks ([DevForum](https://devforum.roblox.com/t/video-thumbnail-review-taking-weeks/4749618)).

### 9.5 The under-16 gate, soft launch and RFY

- **New games reach only age-checked 16+ users until they pass the Kids & Select evaluation** ([docs](https://create.roblox.com/docs/production/publishing/kids-and-select)). The threshold conflicts: a DevForum announcement cut it **from 500 to 250 highly engaged plays in 60 days, effective Aug 19, 2026** ([DevForum](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164)); some pages still say 500, and third parties report a drop to 100 [UNVERIFIED]. **Decision:** plan for 250, budget for 500, trust the Audience Reach dashboard.
- **Owner prerequisites by Mon Nov 16:** ID/age check, 2SV, the **1,000 R$ refundable fee**, the maturity questionnaire, and an 18+ card or ad credits for Ads Manager.
- **Thu Dec 3, 15:00 CET: soft launch.** Public, 16+ trial, **RFY excluded**, rated **Mild**. $300 **Engagement-objective** ads (they target players who count toward the threshold and do not auto-pause, [Ads Manager](https://create.roblox.com/docs/en-us/production/promotion/ads-manager)) plus a **$100 Plays test** (Dec 3-6) comparing T1-T4. **No more than $500 before D1 is known.**
- **Fri Dec 4:** create the "Steal Back Christmas" **Experience Event** for Dec 11 and submit it for featuring (7+ days' lead); add an RSVP prompt (`SocialService:PromptRsvpToEventAsync`) after the first heist. 1,000 RSVPs open Trending Events ([docs](https://create.roblox.com/docs/en-us/production/promotion/experience-events)).
- **Fri Dec 11: open RFY** with Christmas chapter 1 **only if** D1 ≥ 15% on 300+ players, bounce under 60 s ≤ 20% and no blocker bugs; otherwise fix the leak first. RFY ranks on organic play-through, first-play bounce, play days and intentional co-play, measured for D1, D2-7 and D8-28 ([Discovery FAQ](https://create.roblox.com/docs/en-us/discovery-faq.md), [newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)); ads and TikTok buy cohorts, not ranking.
- **Target ~Dec 15** for the threshold, before most US districts break (Dec 21 - Jan 4). If it is not trending by Dec 10, add $200 of Engagement spend.
- No 2026 Roblox winter platform event is announced (a Dec 17 "The Festive" event is one social-media rumour, [X](https://x.com/WhyIron_/status/2117388221726552152) [UNVERIFIED]); apply if one opens. **GTA 6 ships Nov 19** per Take-Two ([Khaleej Times](https://www.khaleejtimes.com/business/tech/gta-6-release-date-locked-take-two-ceo-shuts-down-delay-rumours)) and should raise heist appetite [inference]; we don't rush for it. Watch *Grand Theft Timeline* (Q4 2026, [Steam](https://store.steampowered.com/app/4928450/)).

### 9.6 Creators

- 20 micro (10K-200K) and 10 mid (200K-2M) Roblox duo/funny creators; no macro or drama channels until D1 is proven ([RoWatcher](https://rowatcher.com/news/why-macro-influencers-kill-small-roblox-games-and-what-works-instead)). DM pitches ≤ 150 words with a 15 s vertical clip, a private server for Dec 5-10, a personal share link and a "creator clone" colour. **Embargo lifts Sat Dec 12.** No paid deals until D1 ≥ 22%.
- **Devlog from Nov 16:** 4 greybox clips a week ("I made a Roblox game where your past self is your teammate"), owned music only.

### 9.7 KPIs and kill / double-down rules

Bars anchored to GameAnalytics medians over 500+ Roblox games (**D1 10.3%, D7 1.6%; top 1%: 22.2% and 9.1%**, [GameDevReports summary](https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox)).

| Metric | Kill / rework | Fix before scaling | Healthy | Double down |
|---|---|---|---|---|
| Join → control (mid phone) | > 20 s | 10-20 s | ≤ 10 s | — |
| First clone seen ≤ 45 s | < 60% | 60-80% | ≥ 85% | — |
| L1 complete / joined | < 50% | 50-70% | ≥ 70% | ≥ 80% |
| Bounce < 60 s (H) | > 35% | 20-35% | ≤ 20% | ≤ 12% |
| Median first session | < 5 min | 5-10 | ≥ 12 | ≥ 18 |
| **D1** (cohort ≥ 300) | **< 8%** | 8-15% | **15-22%** | **≥ 22%** |
| **D7** | < 1.5% | 1.5-4% | 4-6% | **≥ 6%** |
| Sessions with a friend | < 8% | 8-20% | ≥ 20% | ≥ 30% |
| SAVE CLIP taps / heists | < 1% | 1-4% | ≥ 5% | ≥ 10% |
| Share-link D1 ÷ organic D1 | < 0.5 | 0.5-0.8 | ≥ 0.8 | ≥ 1 |
| Describe it as a "heist" game (playtests) | < 50% | 50-70% | ≥ 70% | — |

- **Double down** (D1 ≥ 22%, D7 ≥ 6%, DAU > 1,000 in week 2): scale Plays ads while CPP < $0.02, pay mid creators, pull Sky Lounge forward.
- **Rework** (2 cohorts under 8% D1): stop spend, fix the first 3 minutes, test new thumbnail concepts.
- **Hard stop** (4 weeks under 10% D1 and PTR in the bottom quartile): change the framing (title, setting), keep the tech.

Analytics: one server-only module; funnels `onb_v1` and a per-heist funnel; low-cardinality custom events (`CloneFailed{cause}`, `RetakeUsed`, `ClipSaveTapped`, `InviteJoined`, `JoinSource`, `TaintedRun{reason}` and similar); a release annotation on every publish.

### 9.8 Live ops: first 8 weeks (drops Fridays 17:00 CET = 11:00 US Eastern, published 24 h earlier and unlocked by server time)

| Week | Dates | Content | Config / ops | Marketing |
|---|---|---|---|---|
| L1 | Dec 3-9 | Soft launch: L1-L8, medals, Vault of the Day, cosmetics store; locked snow-globe vault with a countdown at the van | RFY off, hotfixes only, ads, RSVP prompt | Creator servers Dec 5-10; a clip a day; event submitted Dec 4 |
| L2 | Dec 10-16 | **Fri Dec 11: Christmas ch. 1**; **12 Vaults of Christmas** from Dec 13 | RFY on (if bars hold); "[🎄]" tag, Santa-hat icon, T5; presents meter | Embargo lifts Dec 12; formats 1 and seasonal |
| L3 | Dec 17-23 | **Fri Dec 18: ch. 2**; Contract "Lights Out" | Double Cash Sat-Sun; notification opt-in after the first advent vault | Format 6 on the advent seed; creator wave 2 |
| L4 | Dec 24-30 | **Dec 24: ch. 3** (published Dec 22); meter finale Dec 25 | **Publish freeze Dec 24-27**; fixed Christmas-morning cosmetic | Format 7 "play with your cousins" |
| L5 | Dec 31 - Jan 6 | **Midnight Vault**; advent catch-up closes Dec 31; **event ends Jan 4** | Seasonal art off Jan 5; Museum teaser thumbnail | Format 5 Museum tease |
| L6 | Jan 7-13 | **Fri Jan 8: Museum** (4 levels, Noisemaker) + the funnel's top fix | New event and "MUSEUM HEIST" thumbnail | Formats 2-3 among museum lasers |
| L7 | Jan 14-20 | Buffer week: fixes, performance, Server Authority spike | Contract "Mirror Map" | Community clip reposts (with permission, no names) |
| L8 | Jan 21-27 | **Fri Jan 22: co-op update + Season 1** (Hub, hideouts, crew servers, Crew Vaults, crew board) | — | Format 7 headline; a paid mid creator only if D1 ≥ 22% |

The post-holiday cliff is real (the week after Halloween 2026, Murder Mystery 2 fell 84% and Steal a Brainrot 70%, [RoWatcher](https://rowatcher.com/news/roblox-week-in-numbers-2026-w44)); the Museum on Jan 8 and Season 1 on Jan 22 are there to catch it. Steady state afterwards: Vault of the Day daily, a Contract weekly, a location every 2-3 weeks, a seasonal event every 2-3 months.

---

## 10. Production plan

### 10.1 Who does what

| Claude Code (cloud session) | Owner (Danish, solo) |
|---|---|
| All code via Rojo files; Lune tests; CI; Open Cloud engine tests | **Runs Studio**: playtests, screenshots, clips, MicroProfiler readouts, phone bench |
| Level layouts, solutions, levelgen | **Style owner:** signs off golden assets, clone look, icon, thumbnails |
| Blender assets through the gates; budget audits | Uploads assets, or creates a test-universe Open Cloud key (asset upload, publish, luau execution) |
| Analytics, blooper log, store copy, creator pitches, localization keys | ID check, 2SV, fee, questionnaire, ads billing, trademark check |
| Thumbnail staging (capture place, director command) | Films and posts clips; creator DMs; Experience Event; publishes live on release tags |
| PROJECT_STATE, release checklists | Recruits outsider testers (with parental consent); Danish table; music contract |

### 10.2 Week-by-week milestones with exit criteria

**W1, Thu Nov 12 - Wed Nov 18: "Prove v0.1 and lock identity" (M0)**
- Owner: first Studio solo and 2-client test of v0.1 (`rojo build -o EchoHeist.rbxlx`); feedback list. Name confirmed Nov 16; ID, 2SV and fee done Nov 16; TikTok/YouTube handles reserved; first devlog clips.
- Claude: CI L0; `shared/Rec` (Codec, Sampler, Validator) with L1 specs; start `HeistSim` and `Guards.path(t)`; rule changes (End/Scrap take, caught ends take, 12-clone cap, 20 Hz, timings in Config); RewindDirector v1, AudioBus, Comfort; plate cables and door fix; the golden-room look-dev slice.
- **Exit:** feedback list exists; L0-L1 green; owner screenshots of the golden room at PC Quality 10, phone Automatic and phone quality 1-3; Realistic vs Soft and Tint vs ForceField decided; title locked.

**W2, Thu Nov 19 - Wed Nov 25: "The sim refactor and client clones" (M1)**
- Claude: clones as server data + `EchoView` client rigs (full §6.5 recipe); Interact as the single entry point; Divergence states; Clone Deck; take bar; L2 tests; levelgen + LevelSpec; Corner Shop L1-L4 from layout files; FTUE, Mentor tape and funnel; bench mode; Gus.
- Owner: 5-tester feel gate; phone bench at 8 and 12 clones; 2-client test at 200 ms simulated ping.
- **Exit:** L1-L4 solvable headless; determinism hash stable; 4 of 5 testers rewind unprompted and see their first clone within 30 s; 3+ say "funny" or "satisfying" unprompted; 0 desyncs in 20 loops; 12 clones ≤ 33 ms on the owner's phone (else the mannequin LOD); colour-blind audit passes.

**W3, Thu Nov 26 - Wed Dec 2: "Vertical slice to store-ready" (M2)**
- Claude: Bank L5-L8; profile slice, medals, Cash, Stars, slots, 3 gadgets; Vault of the Day with board and cache; Heist Reel, results card, SAVE CLIP and blooper log; HUD v1; SFX and library music; store, Starter pack and Receipts; analytics; localization keys; Relaxed Time; static Blueprint; L3 tests on main; bank kit through the gates.
- Owner: icon, T1-T4 and video thumbnail **by Mon Nov 30**; 10-20 outsider phone playtests; creator DMs; questionnaire; ads drafted; real-device SAVE CLIP test.
- **Go/no-go Mon Nov 30:** L1-L5 + L8 complete and solvable; ≥ 70% of outsiders reach L1Complete; median first bank ≤ 60 s; no data loss in Play/Stop/Play and server hops; flat memory in a 30-minute 4-client soak; frame budget met on the mid phone. **If no-go:** soft launch Tue Dec 8; Christmas ch. 1 still ships Dec 11.

**W4, Thu Dec 3 - Wed Dec 9: "Soft launch" (M3)**
- Soft launch Thu Dec 3 15:00 CET. Hotfixes only on the live place; ads managed daily; event created Dec 4; creator servers Dec 5-10.
- Claude in parallel: Christmas ch. 1, Christmas Eve lighting, snowy reskin, presents meter, Candy Canes, 12 advent mini-vaults, Christmas Crew pass; L6-L7 if they slipped.
- **Exit:** D1 ≥ 15% on 300+ players; bounce < 60 s ≤ 20%; threshold progress trending toward ~Dec 15; 0 blocker bugs.

**W5-W11 (Dec 10 - Jan 27)** follow the live-ops calendar in §9.8. Build-side exits:
- **W5 (Dec 10-16):** ch. 2 built; Kids & Select reached or on track by Dec 18; crash-free sessions ≥ 99%.
- **W6 (Dec 17-23):** ch. 3 **published Tue Dec 22** with a server-time unlock, passing L2 solvability with an 8-clone solo solution (or the Giant Present is cut); D7 of the Dec 3 cohort ≥ 4%.
- **W7-W8 (Dec 24 - Jan 6):** freeze holds with no rollback; Museum L9-L12 green in L2 and owner-playtested.
- **W9-W10 (Jan 7-20):** Museum live; D8-28 return stable after the cliff; performance dashboard reviewed by device; Server Authority go/no-go; Hub and crew servers integration-tested.
- **W11 (Jan 21-27):** co-op update live; sessions with a friend ≥ 20%; weekly cadence held 3 weeks running.

### 10.3 Testing gates and what must be human-playtested

Automated gates (every commit: L0-L2; main: L3) block merges. Claude cannot see Studio renders, so these **must** be human-tested by the owner or outsiders:
1. Movement and camera feel (jump timing, zoom, wall fade), on PC and a phone.
2. Clone readability: "which ones are past me?" in under 0.5 s (blind 3-person check on screenshots at 160×90 and 64 px).
3. Gus's telegraphing and the 0.35 s grace: does getting caught feel fair?
4. The rewind: satisfying, not tiring, after 20 takes.
5. Co-op sync at 150-250 ms ping: "it was on the plate but the door didn't open" must never happen.
6. Phone performance at 12 clones, and thermals after 15-20 minutes on a low Android and an iPhone 3-4 generations old.
7. Late join and leave mid-carry; Play/Stop/Play data safety; server hop.
8. FTUE with 5-10 kids/teens who have never seen it (parental consent): time to first clone, first bank, and whether they call it a heist or a puzzle game.
9. SAVE CLIP and Share on real iOS and Android devices.
10. Every golden asset and the icon at 64 px (style-owner sign-off).

---

## 11. Risk register and open decisions

### 11.1 Top 15 risks

| # | Risk | L / I | Mitigation | Trigger |
|---|---|---|---|---|
| 1 | **Mechanic unreadable** in a 3 s clip or a 60 s first session | High / High | Clone by 30 s; glyph + number; tape-print spawn; reel captions | First clone ≤ 45 s for < 80% |
| 2 | **Puzzle-game perception** (ECHOES: Clone Puzzles at 0 CCU) | Med / High | Heist-first title, copy, thumbnails; loot in take 1; "puzzle" banned from the store | < 70% of testers say "heist" |
| 3 | **Phone cost of 12-16 avatar rigs** (no SLIM for NPCs) | Med-High / High | Client rigs, stripping, group Highlights, anim LOD, stack rule, mannequin LOD, cap 12 | Bench > 33 ms (W2) |
| 4 | **Schedule** (prototype never run in Studio, solo owner, Dec 3) | High / High | Minimum scope L1-L5 + L8; Nov 30 gate, Dec 8 fallback; cut order Giant Present → L6/L7 → Blueprint polish → advent 12 → 8 | Any W1-W2 exit missed |
| 5 | **Sim/visual desync** ("my clone was on the plate") | Med / High | One Sampler both sides, render at server t, plates lit from server state, L2 tests | Any desync report |
| 6 | **Non-determinism creeps back** | High / High | Selene bans in `shared/Sim`; determinism hash per commit | CI red |
| 7 | **Under-16 gate not cleared before Dec 21** | Med / High | Dec 3 soft launch, Engagement ads, daily dashboard, +$200 | < 60% of target on Dec 10 |
| 8 | **"Copy of X" backlash** (itch Echo Heist, Rewind Robbers, ECHOES) | Med / Med | Own title and look, Sky Lounge, co-op-first marketing | Comments naming another game |
| 9 | **Fast-follow copies** past ~5K CCU | High / Med | Weekly drops, Vault of the Day, saved progress, owned art, the determinism moat | Copy > 1K CCU → next drop within 7 days |
| 10 | **Hacked runs on leaderboards** | Med / Med | Validator clamp + taint, server scores, recording hashes, Server Authority spike | Taint rate > 2% |
| 11 | **Video capture/share missing on many devices** [UNVERIFIED] | Med / Med | `CanCaptureVideo()` + screenshot fallback; crop-safe reel for screen recording | W3 device test |
| 12 | **Christmas cliff** (70-84% drops after Halloween) | High / Med | Museum Jan 8, Season 1 Jan 22, RSVPs and notification opt-ins | Week-after-event DAU |
| 13 | **Realistic lighting too slow** on low Android | Med / Med | Colour-first recipe, Soft kill switch, ≤ 4 shadow lights | < 30 fps |
| 14 | **Music/IP in clips** | Med / Med | Owned music off-platform, commissioned stems with trailer rights, no-IP list, provenance log | Any takedown |
| 15 | **Maturity label slip** | Low-Med / High | No weapons, blood or gambling; bloodless flops; re-answer the questionnaire after changes | Label above Mild |

### 11.2 Open decisions for the owner (please answer by the dates shown)

| # | Decision | Recommendation | Needed by |
|---|---|---|---|
| D1 | Store title: "Rob With Your Clones", "Heist Yourself" or "Repeat Offenders"? | **Rob With Your Clones**, slogan "Heist Yourself" | Mon Nov 16 |
| D2 | Player-facing noun "clone" (code stays Echo)? | **Yes** | Mon Nov 16 |
| D3 | Pay the 1,000 R$ fee and up to $500 of ads before D1 is known; is an 18+ card available for Ads Manager? | Yes; $300 Engagement + $100 Plays, $100 reserve | Mon Nov 16 |
| D4 | Trademark search (EUIPO/USPTO classes 9 and 41) for the chosen title: you, or a lawyer? | Do it this week; it is cheap insurance | Fri Nov 20 |
| D5 | Act as style owner and run the Studio test protocol (screenshots, clips, phone bench) in W1-W2? | Required; Claude cannot see renders | Nov 13 |
| D6 | A separate test universe/place and an Open Cloud API key (asset upload, place publish, luau execution): who creates and holds it? | You create it, scoped to the test universe only | Wed Nov 18 |
| D7 | Soft launch Thu Dec 3 (go/no-go Nov 30) or the safer Tue Dec 8? | Dec 3 with the gate | Mon Nov 30 |
| D8 | Commission 3 stemmed tracks with trailer rights, or library music only? | Commission if Christmas stems can arrive by Dec 9 | Fri Nov 20 |
| D9 | +1 clone slot game pass (149 R$, excluded from boards)? | **Not at launch**; revisit after D7 data in January | Jan 8 |
| D10 | Guard detection grace 0.35 s and cameras ignoring clones: accept as design rules? | Yes, tune in playtests | W2 playtest |
| D11 | When a player leaves mid-heist, do their clones stay until the heist resets or only until the loop ends? | Until the loop ends, then retire (simpler sim, frees caps) | W2 |
| D12 | Cut Moon Base if January numbers are weak? | Yes; decide after the Museum's D7 | Jan 22 |
| D13 | Raise the server clone cap from 12 to 16 (20 robbers on screen)? | Only if the bench passes on a low Android | After W2 bench |
| D14 | Correct `docs/IDEA_ECHO_HEIST.md`'s outdated originality claim now? | Yes (next session) | Nov 16 |

---

_Next step after owner review: rename this file to `docs/MASTERPLAN.md`, record decisions D1-D14 in PROJECT_STATE.md under "Decisions", and start W1. Known tool bug from the market research: `tools/trend_radar.py` crashes on a malformed snapshot in `radar/` (fix in a separate task)._
