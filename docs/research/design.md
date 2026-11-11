# Echo Heist: Core Game Design Research and Decisions

_Dimension: game design (loop mechanic, heist design, progression, solo and co-op). Written 2026-11-12. English. Facts carry a citation; anything marked **Decision** or **Recommendation** is our call, not a fact. Claims I could not verify are marked [UNVERIFIED]._

---

## Summary

Echo Heist sits in a known but under-used genre. Designers call it "record clones": you act, rewind, and a past copy of you repeats what you did. The best games in this genre (Cursor*10, Time Rifters, Quantum League, Lemnis Gate, Super Time Force) get praised for one thing: **you are your own co-op partner**. They get criticised for three things:

1. **"Redo everything" fatigue.** When one link breaks, you replay the whole chain.
2. **Waiting and precision busywork.** You stand on a button forever, or you need frame-perfect timing.
3. **Readability collapse** once there are too many copies on screen.

No current Roblox game uses past runs as co-op partners. Roblox's clone games are follow-me sandboxes (live data below). Heist demand on Roblox is real: ROB IT has 315M visits since 2025-12-31.

The design below keeps the mechanic, makes it fast and forgiving, and makes failure funny:

- **Short loops, 30 to 75 s by location.** No loop is ever longer than 90 s.
- **Echoes are dumb ghosts on rails.** They repeat your movement exactly, and they fail *visibly and comically* when the world differs from the recording: bonk, zap, busted, shrug.
- **Re-record only the broken echo.** "Retake echo #2" means you never redo the whole chain. This copies the 2025 Talos Principle Reawakened fix for its most hated mechanic.
- **Progress persists inside a heist.** Banked loot stays banked (Teardown's "prep persists" idea), so a bad loop costs seconds, not the heist.
- **No fail state.** There are unlimited loops, and three medals reward mastery: Haul, Crew (few echoes), Clean (no busts).
- **Co-op without forced votes.** Each player ends only their own take, and the loop ends when every take has ended. Friends' echoes are colour-coded, and the total echo budget is capped at 12 per server.
- **The clip engine is built in.** A real-time cinematic "Heist Replay" plays after each heist (Superhot's real-time replay lesson), with a blooper reel of the funniest echo failures.
- **Simple meta.** One soft currency (Cash) buys echo slots, gadgets and hideout trophies. Stars from medals unlock the next location. There is a daily "Vault of the Day" with a fewest-echoes leaderboard.
- **Monetisation is cosmetic and convenience only, with zero paid randomness.** This sidesteps the 2026-10-15 paid-random-items rules entirely.
- **"Steal Back Christmas" ships as a 3-level event** with an advent calendar of daily mini-vaults and a server-wide "presents recovered" meter.

---

## Findings (with citations)

### 1. The record-clone genre: what works

- **The self-co-op idea is the selling point.** Rock Paper Shotgun's John Walker called Cursor*10's one-player co-op "the best possible form of co-op", and Shacknews said it created its own category, "the single-player cooperative game" ([Wikipedia: Cursor*10](https://en.wikipedia.org/wiki/Cursor*10), [Shacknews](https://shacknews.com/article/51032/play-with-yourself-cooperatively-alone)). Time Rifters (each life joins as a ghost teammate) is "Very Positive" on Steam with 394 reviews ([Steam](https://store.steampowered.com/app/270010/Time_Rifters/), [Gamebrain](https://gamebrain.co/game/time-rifters)).
- **The genre has a taxonomy, and a named weakness.** knexator's "Record Clones" page names this exact model (act, rewind, the clone repeats). It warns that many implementations are "fiddly, requiring either superhuman amounts of precise planning or waiting forever on a button". That breaks the principle that a solution should take more effort to *find* than to *execute* ([knexator](https://knexator.github.io/time-genres/record-clones)).
- **Deterministic enemies prevent paradoxes.** Capy kept Super Time Force's loops consistent by giving enemies preset behaviour ([XBLAFans](https://xblafans.com/how-super-time-force-avoids-temporal-paradoxes-59645.html)).
- **Mistakes as fuel.** Critics praised Super Time Force for making "dying and then returning with the knowledge" the core, saying it is "not a game that demands pixel-perfect skills" ([Engadget 2012](https://www.engadget.com/2012/04/06/the-benefit-of-making-mistakes-in-super-time-force/)). It was also criticised: crowded replays were "maddening" to follow, and it is "frustrating to find yourself paying later for mistakes made earlier" ([Engadget review](https://www.engadget.com/2014/05/13/super-time-force-review-chronological-disorder/), [God is a Geek](https://godisageek.com/2014/05/super-time-force-review/)).
- **Clone count has a ceiling.** Quantum League's designers tested "5 clones per side, but that was impossible to handle". They settled on 2v2 with slightly longer loops and 12 clones in the final loop as the sweet spot ([MP1st](https://mp1st.com/news/nimble-giant-entertainment-talks-about-their-latest-time-bending-shooter-quantum-league), [Tencent GWB](https://gwb.tencent.com/news/10018)). Auger also said planning in documents was very hard because features had unintended side effects inside a loop, so **prototype and test, don't spec**.
- **Short loops work in multiplayer.** Lemnis Gate used a **25-second** loop and turn-by-turn operative adding, and it even had an "auto co-op" mode where you play against yourself ([GamesRadar](https://www.gamesradar.com/circular-warfare-lemnis-gate-brings-the-time-loop-craze-to-the-hero-shooter-and-finds-multiplayer-gold), [Push Square](https://www.pushsquare.com/news/2021/04/lemnis_gate_is_a_turn-based_time_looping_multiplayer_shooter_coming_to_ps5_ps4)). Its online services ended in 2023, a reminder that a clever loop needs content and a population ([Steam](https://store.steampowered.com/app/950180/_/)).

### 2. The genre: where it frustrates, and the fixes that worked

- **The Talos Principle recorder was "the most disliked mechanic".** It removed trial and error, and duplicated items made softlocks easy. The 2025 *Reawakened* remake **added checkpoints during recording, which pause the replay, plus a general rewind**, and reviewers called the recorder puzzles "much, much better now" ([Steam discussion](https://steamcommunity.com/app/2806640/discussions/0/830459392060095110), [Thinky Games](https://thinkygames.com/features/the-talos-principle-reawakened-isnt-just-a-graphical-revamp-its-the-perfected-edition-of-a-modern-classic)). This is the single most important precedent for us: **let players fix one segment without replaying everything.**
- **Twelve Minutes shows the risk of busywork.** Luis Antonio designed the loop as breadcrumbs ("every loop you learn two or three things") and cut the loop to "the shortest amount required" ([Game Developer Q&A](https://gamedeveloper.com/design/q-a-i-twelve-minutes-i-director-luis-antonio-on-making-good-time-loop-games)). Critics still said it "devolves into frustrating repetition" and is "repeating busy work in hopes of a breakthrough" ([PC Gamer](https://www.pcgamer.com/uk/12-minutes-review/), [Endless Mode](https://www.endlessmode.com/video-games/twelve-minutes/twelve-minutes-repetition)).
- **Persistent knowledge softens repetition.** The Sexy Brutale keeps codes and secrets on your map across rewinds, and masks are permanent upgrades. Reviewers still found reliving the day "tedious" at times ([PC Gamer](https://www.pcgamer.com/the-sexy-brutale-review/), [Kotaku](https://kotaku.com/the-sexy-brutale-is-a-game-about-stopping-murders-with-1794340749), [Game Informer](https://www.gameinformer.com/games/the_sexy_brutale/b/pc/archive/2017/04/10/the-sexy-brutale-game-informer-review.aspx)). Outer Wilds' Ship Log carries all knowledge across its 22-minute loop and highlights open threads ([Scientific Gamer](https://scientificgamer.com/thoughts-outer-wilds)). Deathloop keeps only "infused" gear plus knowledge, and loses everything else ([Looper](https://www.looper.com/610276/deathloop-residuum-and-infusion-explained/), [PC Gamer](https://www.pcgamer.com/deathloop-review/)).
- **Desync breaks trust.** Players of clone games complain that "sometimes the clone's movement wouldn't sync with my previous movements". One jam-game commenter said clones "randomly break and force you to redo everything" ([knexator/Chronotron search results](https://knexator.github.io/time-genres/record-clones), [itch.io comment](https://itch.io/post/13648249)). Braid avoids the "manipulate time while recording yourself" trap by concentrating on **one mechanic at a time** ([Game Developer: Design Lesson 101 Braid](https://www.gamedeveloper.com/design/design-lesson-101---em-braid-em-)).
- **Echo (2017) learned that opaque copying feels random.** Its early prototypes copied player behaviour over a long window and "felt random". The final design used a short, visible learning cycle ([PC Gamer](https://www.pcgamer.com/echo-is-a-third-person-sci-fi-action-puzzler-with-evil-clones/), [Fandom interview](https://www.fandom.com/articles/echo-ex-hitman-devs-brought-ai-to-forefront-of-gaming)). Lesson: what an echo will do must be **readable in advance**.

### 3. Heist games: what makes heists fun

- **Prep that persists plus a timed run.** Teardown has untimed preparation (holes and bridges stay) and then a **60-second alarm** once the first target is taken. Guides recommend spray-painting arrows on the route ([Teardown Heist Basics](https://get-teardown.readthedocs.io/en/latest/gameplay/heist-basics.html), [Voxagon design notes](https://blog.voxagon.se/2020/11/05/teardown-design-notes.html)). Our 60 s loop already rhymes with this.
- **Visible, chunked pressure.** Klei found that a 20-step alarm was unreadable. They moved to 6 levels of 5 ticks each so the next escalation is visible. They admit it was "too stressful for some", but it let them lower base difficulty ([Game Developer deep dive: Invisible Inc alarm](https://gamedeveloper.com/design/game-design-deep-dive-alarm-systems-in-klei-s-i-invisible-inc-i-)).
- **Co-op is the fun multiplier, but chaos needs readable systems.** Andy Schatz said single-player Monaco "will never have quite as much riotous fun" as co-op. For four-player co-op he added "vector-based line of sight that's friendlier" ([Shacknews](https://shacknews.com/article/77665/how-heist-films-influenced-monaco-whats-yours-is-mine), [Wikipedia: Monaco](https://en.wikipedia.org/wiki/Monaco:_What%27s_Yours_Is_Mine)).
- **Stealth plus a fallback.** In Payday 2, a detected stealth-only heist usually fails, while hybrid heists fall back to loud. Making both modes is "effectively making two games" ([Super Jump](https://superjumpmagazine.com/payday-2-so-much-more-than-heists), [80.lv interview](https://80.lv/articles/how-pubg-battlegrounds-became-a-co-op-heist-game-with-payday)). We should **not** build two modes. Our fallback is the next loop.
- **Guided first runs, open replays.** Hitman's Opportunities and Mission Stories exist "to be more accessible, especially for players new to stealth", and levels are built to be replayed ([SI Games interview](https://videogames.si.com/features/hitman-freelancer-interview), [CGMagazine](https://www.cgmagonline.com/articles/editorals/saying-goodbye-to-hitmans-world-of-assassination)).
- **Emergence from clear rules.** Tom Francis: "write clear rules and let players experiment". Heat Signature's stories come from interacting gadgets ([pentadact](https://pentadact.com/2014-01-25-game-design-the-non-stick-plan), [PC Gamer hands-on](https://pcgamer.com/hands-on-with-heat-signature-the-new-game-from-gunpoint-dev-tom-francis)).
- **The replay is the share button.** Superhot's instant replay plays in **real time**, without time stops, which "makes even the most hopeless shooters look like seasoned pros". The players trim the clips and share them ([Twinfinite](https://twinfinite.net/guides/superhot-mind-control-delete-watch-real-time-replays/), [Game Developer](https://www.gamedeveloper.com/disciplines/the-origin-and-future-of-frozen-time-fps-hit-superhot-and-the-positive-crunching-behind-it)). For us, the final loop played back in real time (12 copies of you moving in sync) is exactly the TikTok shot.

### 4. Roblox platform facts that shape the design

- **Live Roblox data (`tools/rbx_search.py` and the games API, 2026-11-12):**

  | Game | Players now | Visits | Created | Max players |
  |---|---|---|---|---|
  | ⛏️Dig to Escape | 3,071 | 618.7M | 2025-11-10 | 14 |
  | ROB IT ("break in, steal everything, don't let the guard see you") | 1,586 | 315.4M | 2025-12-31 | 20 |
  | Notoriety (Payday) | 1,364 | 566M | 2010 | n/a |
  | Deadly Heist | 307 | 121M | 2025-03-15 | 24 |

  Clone games: Clone Engine 1,678 players, Clone Friends 1,241, Clone Yourself 553. All are follow-me sandboxes, and **none uses recorded runs**. Dig to Escape's description sells one goal, a guard threat and "AVERAGE playtime 30-60m+". Its peak was 81K CCU in December 2025 ([RoWatcher](https://rowatcher.com/games/9145063979/dig-to-escape)).
- **ROB IT** uses classes unlocked with Diamonds or Robux; one class tier costs 2,500 Robux. Guides recommend coordinating "distractions and escape timing over voice chat or the ping system" ([Nerdschalk](https://nerdschalk.com/rob-it-classes-guide-all-roles-perks-and-unlock-methods/), [Pro Game Guides](https://progameguides.com/roblox/roblox-rob-it-classes-tier-list-dynamic_date-formatf-y/)). Heist players on Roblox already think in timing and distraction, which is our core verb.
- **Discovery rewards intentional co-play.** Roblox defines "intentional co-play days per user" as unique days users return to play *with friends* via join, invite or private servers; matchmaking does not count ([Roblox Docs: Discovery](https://create.roblox.com/docs/discovery)). Since December 2025, reserved-server sessions count as intentional co-play ([Dubit](https://dubit.io/blog/roblox-top-20-rfy)). In June 2026, Roblox moved away from 7-day proxies toward finer-grained signals ([Roblox Newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox)). The vault says the same: single-player games "often struggle", and D30 social mechanics matter (*Social Design and Multiplayer Play* §1).
- **Communication is restricted.** Chat requires a facial age check and is age-banded (since January 2026). Voice requires 13+ and verification (GAME_BIBLE §4.2, citing Docs). **Co-op must work without chat: pings and markers.**
- **Paid random items (Docs page updated 2026-10-15).** This covers anything random bought with Robux *or with currency purchasable with Robux*. All outcomes and their odds must sum to 100% and be shown before purchase. Luck boosts must update the displayed odds. Regional restriction via `PolicyService` applies ([Roblox Docs](https://create.roblox.com/docs/production/monetization/paid-random-items); vault *Roblox Policies Ratings and Compliance* §2).
- **Vault design rules we adopt:**
  - FTUE: control within about 10 s, first verb by 30 s, first big reward by 40 s, core loop closed 3 or more times in 5 minutes (*First-Time User Experience and Onboarding*).
  - Teach every mechanic as Show, Try, Test, Combine, and combine a new mechanic only with known ones (*Teaching Through Level Design* §3).
  - Puzzles: a sawtooth difficulty curve. Any puzzle where more than about 20% of groups quit is a cliff. Three hint tiers (*Genre Playbook - Puzzle and Escape Rooms*).
  - Daily streaks with a grace day (*Retention and Return Hooks* §3).
  - Friend boost capped low so solo players are not punished, and no reward for invites themselves (*Social Design* §4).
  - Players do not collide with each other, as a griefing guard (*Social Design* §9).
  - Every input gets a pop and a sound within 100 ms (*Game Feel and Juice*).
- **Seasonal timing.** One trend report claims a 12.5M CCU winter-break peak in Q4 2025 [UNVERIFIED] ([rolearn](https://rolearn.dev/trend-reports/q4-2025-market-trends)). Holiday updates in 2025 used event currencies (99 Nights' candy canes) and event islands (Fish It) ([BloxBit](https://thebloxbit.blogspot.com/2025/12/roblox-christmas-event-2025-festive.html)). Event traffic has natural "cliffs" afterwards ([RoWatcher](https://rowatcher.com/news/roblox-halloween-spike-hits-14-9m-ccu-winners-losers)).

### 5. Prototype grounding (read from `/home/user/echo-heist/src`)

- `Config.luau` sets loop 60 s, 15 Hz recording, 4 echoes per player and 16 total, and a 0.4 s plate grace.
- `Echoes.luau` replays position, yaw and events (`grab`, `vanish`), and the echo holds its final pose.
- `Main.luau` ends the loop when all players vote to rewind, keeps banked loot across loops, sends caught players home and removes caught echoes.
- Guards reset each loop, which already gives us determinism.

The design below keeps all of this and changes the rewind vote, the caught rule and the caps.

---

## Recommendations / decisions

### A. The loop rules

| Rule | Decision | Why |
|---|---|---|
| **Loop length** | Set per location: Corner Shop 30 s, Bank 45 s, Museum 60 s, Casino 60 s, Moon Base 75 s, Christmas 45 s. Hard ceiling 90 s. | Lemnis Gate's 25 s loop works. Twelve Minutes shows that long loops breed busywork. Short loops make a retake cheap. |
| **Loop start** | A 3-2-1 "GO" countdown, not recorded. The clock starts at GO. A big timeline bar shows 0:00 to loop end, with every echo's key events as icons on it. | The timeline makes echo behaviour readable in advance (the Echo 2017 lesson). |
| **What an echo is** | A ghost on rails. It replays position and yaw at 15 Hz plus action events. It has no collision with players. Its actions are re-checked against the current world. | Simple, deterministic, and funny when the world has changed. |
| **Echo failure states** | **Bonk** (closed door in the path: flattens like a cartoon and stops). **Zap** (walks into an active laser: skeleton flash, smoke puff). **Busted** (seen by a guard: handcuffs, "?!", poof). **Shrug** (tries to grab loot that is already gone). **Stuck** (its path is blocked: holds its pose with a "..." bubble). Each one plays a sting sound and leaves a red marker on the timeline. | Turns desync into comedy and information. The player always sees *why* an echo failed and *when*. |
| **Ending a take** | **R / button = "End my take".** Your recording stops, and your echo will hold its last pose there in future loops. You become a ghost spectator with a free camera until the loop ends. **Hold R (0.6 s) = "Scrap take"**: this take is thrown away and no echo is made. | No team vote can force anyone to rewind (this replaces the all-players vote). Scrap removes the "my bad run is now permanently in the chain" pain. |
| **Loop end** | When every live player has ended or scrapped their take, or when the timer hits 0 (the timer ending counts as "End my take"). | Fast solo flow. Fair in co-op. |
| **Retake** (the key anti-frustration tool) | Between loops, an **Echo Deck** shows your echoes as cards (#1, #2, #3). Tap a card, then **Retake**: the next loop replays all the *other* echoes, and you re-record that slot only. **Delete** removes a card. Only your own cards can be changed. | Talos Reawakened's fix. You never redo the whole chain. Directly answers "I have to redo everything". |
| **Solo skip-ahead** | Solo only: hold **F** while standing still to run the loop at 3x speed (recorded as standing). It turns off when you move. | Kills knexator's "waiting forever on a button". |
| **Caught (live player)** | A guard catching you **ends your take on the spot** with a 1.5 s "BUSTED" stamp. You are not sent home. The echo of that take will walk into the same guard next loop and get busted again, unless you Scrap or Retake it. | "My echo repeats my mistakes" becomes the default funny clip, and it costs one take at most. |
| **Echo caps** | Per player: 3 at start, then 4, 5 and 6 bought with Cash, then 7 and 8 via Stars (late game). **Server cap: 12 echoes plus up to 4 live players = 16 actors.** In co-op, per-player cap = min(own cap, floor(12 / players)): solo 8, duo 6, trio 4, quad 3. | Quantum League found 5 clones per side unmanageable and 12 manageable. 16 actors is also the performance ceiling. Solo still gets the "8 copies of me" clip. |
| **Within a heist, what persists** | Banked loot (in the van). Unlocked shortcuts marked as "Prep" (for example a vent cover unscrewed, a window cut). Ghost trails (your last 3 takes as faint lines on the floor). Notes and markers. | Teardown's "prep persists", The Sexy Brutale's map, Outer Wilds' log. A bad loop never erases progress. |
| **What resets every loop** | Guards, cameras, lasers, doors, carried (unbanked) loot, gadget charges, the alarm level. | Determinism. Guards stay predictable, as in Super Time Force. |
| **Across heists** | Cash, Stars, upgrades, cosmetics, medals, hideout trophies. Echoes do **not** carry between heists. | Clean slate per level. |
| **Fail state** | None. Loops are unlimited. After 8 loops without progress, the hint system escalates (see FTUE). | The Roblox audience bounces off hard walls (the vault funnel lost 82% at one blocking step). |

**Determinism rule (needed for the tech).** Everything except live players must be a pure function of (level seed, loop time, actor positions). Guards follow fixed patrol splines. On seeing an echo, a guard does a fixed 2 s "huh?" freeze and then resumes, so echo outcomes are identical every loop unless a *live* player changes something. Physics props that echoes interact with (heavy loot) are scripted carries, not free physics. **Recommendation:** move echo replay to clients (the server sends recordings once per loop, and clients interpolate against the shared server clock), while mechanisms stay on the server. The current per-Heartbeat server CFrame writes will not scale to 12 rigs on phones (PROJECT_STATE known risk).

### B. Heist structure and level design principles

**One heist = one location section = 2 to 4 loops at par**, ending with the **Big Score**: one loot item or vault that needs several echoes working together in a single loop. That loop is the real-time Heist Replay clip.

**Principles:**

1. **One new verb per level, introduced as Show, Try, Test, Combine.** "Show" can be a pre-recorded **tutorial echo** (a ghost "Mentor" run playing in loop 1), which is elegant for this game.
2. **Every gate is readable from the van.** Use a sightline from spawn to the goal (vault door, glinting diamond).
3. **One colour per mechanism family**, plus a shape as a second channel (colour-blind rule): plates blue with a circle icon, lasers red with zigzags, cameras yellow cones, guard cones white with a striped edge, heavy loot gold with a "2 hands" icon.
4. **Timing windows of at least 1.5 s.** Plate grace 0.4 s stays, but "simultaneous" means within 1.0 s. No frame-perfect demands (Super Time Force praise; knexator critique).
5. **The solution must be faster to execute than to find.** A par solution should take at most `loops x loop length` plus 50%.
6. **Sawtooth difficulty:** a breather level after every new hard combination.
7. **Physical items are single, never duplicated.** If an echo picks up the keycard, it carries the card along its recorded path. The live player can take a card only from where an echo *drops* it ("hand-off"). This avoids Talos' duplicate-item softlocks.

**Mechanism catalogue** (all react to players and echoes unless noted):

| Mechanism | Rule | Echo comedy |
|---|---|---|
| Pressure plate | Holds a door or laser while occupied | Your echo leaves the plate one second too early |
| Timed button | Opens a door for N s | |
| Twin switch | Two switches within 1.0 s | |
| Laser grid | Zaps the actor, off while its plate is held | Zap |
| Camera | Sweeps. Seeing a live player raises the alarm by one level. Echoes are *invisible* to cameras ("cameras see heat, echoes have none"). | |
| Guard | Patrol spline plus vision cone. Busts echoes and catches players. A **noise** (noisemaker, broken vase) at t pulls the guard for 4 s, deterministically. | Busted, the confused "huh?" |
| Keycard | Single physical item. Hand-off through drops. | Your echo walks away with the card |
| Vent | One actor at a time, a shortcut. | Two echoes stuck in a vent |
| Safe | Hold-to-crack 4 s. Interrupted if the actor is moved or busted. | |
| Heavy loot | Needs 2 actors on its handles. Moves at walk speed. | One carrier gets busted and the other drags it alone, comically slow |
| Scale vault | Needs N actors standing on it (4, 6, 8) | The "8 synchronised copies" shot |
| Alarm | 0 to 3 levels in 5-tick chunks (Klei). Each level speeds guards by 15% and closes one shutter. Resets every loop. | |
| Lights switch | Darkness shortens guard vision by 40% for 10 s | |
| Conveyor / elevator | Fixed schedule. Teaches waiting and timing. | |

**Mechanic curve: 18 levels**

| # | Location (loop) | Level | New verb (Show, Try, Test, Combine) | Echoes at par |
|---|---|---|---|---|
| 1 | Corner Shop (30 s) | "Back Room" (FTUE) | Plate holds door, Rewind | 1 |
| 2 | Corner Shop | "Two Doors" | Two plates, End take vs Scrap | 2 |
| 3 | Corner Shop | "Lights Out" | Laser grid with plate | 2 |
| 4 | Corner Shop | "Night Clerk" | First guard: busts echoes, catches you | 2 |
| 5 | Bank (45 s) | "Teller Line" (breather) | Timed button, timeline icons | 2 |
| 6 | Bank | "Keycard" | Single item hand-off | 3 |
| 7 | Bank | "Vault 101" | Heavy loot (2 carriers), Retake taught | 3 |
| 8 | Bank | "The Big Score: Bank" | Scale vault (4 actors) plus guard | 4 |
| 9 | Museum (60 s) | "Gallery" | Cameras (echoes invisible) | 3 |
| 10 | Museum | "Dinosaur Hall" (breather) | Vents | 3 |
| 11 | Museum | "Night Watch" | Noise distraction (gadget: Noisemaker) | 4 |
| 12 | Museum | "The Big Score: Crown" | Alarm levels plus a combine | 5 |
| 13 | Casino (60 s) | "Slot Floor" | Twin switches | 4 |
| 14 | Casino | "Count Room" | Safe cracking under patrol | 5 |
| 15 | Casino | "High Roller" (breather) | Elevators on a schedule | 4 |
| 16 | Casino | "The Big Score: Jackpot" | Everything, scale vault (6) | 6 |
| 17 | Moon Base (75 s) | "Low Gravity" | Long jumps, airlock timers | 5 |
| 18 | Moon Base | "The Big Score: Moon Rock" | Scale vault (8), 2 heavy loots | 7 (8 for gold) |

Each location also gets a **Free Roam** replay with randomised loot positions for Cash farming.

### C. FTUE: the first 60 seconds and the first session

| Time | Beat |
|---|---|
| 0-8 s | Join and load (skippable after 3 s). Spawn **in the open van door**, facing the Corner Shop. No menus. A boombox heist beat. |
| 8-15 s | One objective of 8 words or fewer: **"Stand on the blue plate."** A beam from your feet to the plate. The back-room door rises while you stand there, and a glittering cash bag is visible behind it. |
| 15-22 s | Step off: the door slams. A Mentor line: "You can't hold it AND go in..." The REWIND button pulses (device-correct key). |
| 22-26 s | **REWIND** plays a VHS rewind effect with tape squeal. A 3-2-1 GO. **Your echo walks out of the van and steps onto the plate.** This is the "wow" moment, at about 25 s. |
| 26-40 s | Walk in, grab the cash, carry it to the van: **BANKED +$100** with a count-up and confetti. First reward under 40 s. |
| 40-60 s | The red laser grid lights up in front of the safe. "One echo isn't enough." Loop closes number 2 and then number 3 inside 3 minutes. |
| 2-4 min | Level 1 complete. The first **Heist Replay** plays: 10 s, real time, cinematic. Then the medal screen (3 stars shown, 1 to 3 earned) and a next-goal card: "2 more stars unlocks the Bank". |
| 4-15 min | Levels 2 to 4. Level 4's guard busts your echo for the first time. A blooper stinger plays and the Echo Deck tutorial pops (Retake). |
| End of session 1 | Hub hideout appears with your first trophy (the shop's "Golden Gum"). Only now do the invite prompt and the starter-pack offer appear (once). |

**Hints.** After 8 s idle there is a world cue (a plate glow). After 15 s, an edge arrow. After 2 failed loops, a **Ghost Hint**: a faint pre-recorded solution echo plays for one loop. Ghost Hint is free and unlimited on levels 1 to 8 and limited to 3 per day later. It is never sold.

**Funnel events:** `Loaded, FirstMove, FirstPlate, FirstRewind, FirstEchoSeen, FirstBank, L1Complete, FirstBusted, FirstRetake, L4Complete, Minute10`.

### D. Solo vs 2-4 players

- **Instancing.** The **Hub** is a public server (hideouts, leaderboards, the van lineup). **Heists** run in **reserved servers per crew of 1 to 4** (party teleport with a shared ReservedServerId). This keeps strangers from griefing, and reserved sessions count as intentional co-play. "Quick Crew" matchmaking is optional for players who want strangers.
- **How echoes combine.** All crew echoes replay together. Each player gets an outline colour (blue, orange, green, pink) and a number badge (B1, B2, O1...). The timeline shows a row per player.
- **Chaos control.**
  - The 12-echo server cap.
  - Per-player caps (duo 6, trio 4, quad 3).
  - Co-op levels scale requirements by *actors*, not by players. A scale vault needs max(4, players + 2) actors.
  - Guards get +10% vision per extra player.
- **Roles without classes.** Each player brings one gadget: Noisemaker, Smoke Puff (guards blind for 3 s), Magnet Glove (pull loot 10 studs), Grapple, or Hacker Phone (camera off 5 s). This gives soft roles (Distractor, Carrier, Hacker) like Monaco's characters without splitting the game in two.
- **Talking without chat.**
  - A ping wheel: "Here", "Wait", "Go", "Guard!", "Plate", "Need 2".
  - **Timed floor markers**: drop a marker that says "be here at 0:24". This is Teardown's spray paint, upgraded.
  - Markers persist across loops.
- **Griefing rules.**
  - No player-player collision.
  - Nobody can delete or retake another player's echo.
  - The host can kick from a reserved crew server.
  - A player who ends their take early only affects their own slot.
  - Loot is split equally across the crew, so there is nothing to steal.
- **Friend reward.** +10% Cash per friend in the crew, capped at +30% (vault pattern). Solo players are never blocked: every level is solvable solo with the solo echo cap.

### E. Progression and retention (D1, D7, D28)

- **Currencies.** **Cash** (soft, flat scale, earned from loot) and **Stars** (from medals, never sold). That's all. One currency, one job each (vault *Currency Architecture*).
- **Medals per level (3 stars):**
  1. **Haul**: bank at least the target value.
  2. **Crew**: finish with at most the par echoes (the "how few did you need?" brag).
  3. **Clean**: no live-player catches and no busted echoes in the final loop.

  A **Diamond** fourth medal (beat the developer's echo count) is shown but optional. It is TikTok bait: "dev needed 4 echoes, I did it with 3".
- **Gates.** Bank 5 Stars, Museum 14, Casino 26, Moon 40 (of 54 regular stars). This is Cut-the-Rope style gating, a clear number on the next-goal card.
- **Cash sinks (priced in minutes of play).**
  - Echo slots: #4 at 10 min, #5 at 30 min, #6 at 75 min.
  - Gadgets: 5 to 20 min each, and level 2 versions.
  - Van skins and hideout trophies: 3 to 60 min.
  - Stars unlock echoes #7 and #8.
- **Hideout.** A personal vault room in the Hub with plinths for each Big Score trophy (Golden Gum, Bank Vault Door, Crown, Golden Slot Machine, Moon Rock). Others can visit it, and a "Most Wanted" board shows the top crews.
- **D1 hooks.** Next-goal card on exit. **Vault of the Day**:
  - One handcrafted-module heist per UTC day, the same on every server, with a fixed loadout (cap 5 echoes, no paid slots apply).
  - A global leaderboard for fewest echoes, then fastest final loop.
  - The first clear pays 1 Star plus a fixed Cash amount.
  - The daily streak has a grace day.
- **D7 hooks.**
  - Weekly "Big Score" contract (a remixed Big Score with a twist modifier: "guards are faster", "lights out", "mirror map").
  - A new location roughly every 2 weeks after launch.
  - Weekly crew leaderboard.
- **D28 hooks.** Seasons (5 weeks) with a free cosmetic ladder earned from Stars and dailies, seasonal locations, and a hideout prestige ("Legend" frame for 3-starring a location).
- **Dig to Escape simplicity check.** One sentence goal, a visible threat (the guard), a number that grows (Cash), a shop. **Never more than 3 HUD meters during a heist:** timer, haul, echoes.

### F. Monetisation (ethical, 2026-compliant)

**Hard rules:**
- **No paid randomness at all**, and no Robux-to-Cash conversion. That keeps every random reward exempt and removes the odds and PolicyService burden.
- No pay-to-skip levels, and no paid Ghost Hints, retakes or loops.
- No purchase prompt during a heist or on a bust.
- At most one unprompted offer in a non-payer's first session, after level 1.

**Products, in build order:**

1. **Cosmetics** (the main revenue):
   - Echo styles: VHS glitch, neon outline, gold ghost, pixel, noir.
   - **Echo emotes**: your echoes perform an emote at a recorded moment, a funny clip tool.
   - Rewind effect styles, van skins, hideout decor.
2. **Starter Crew pack** (about 199 R$, once): an echo style, a van skin and +1 echo slot early. It is shown after level 1.
3. **"+1 Echo Slot" game pass** (about 149 R$). This is PvE convenience. It is disabled in Vault of the Day and in Crew medals, which judge echoes *used*, not owned.
4. **Cheap or free private servers** (a social feature).
5. **Rewarded video**, once eligible: "double this heist's Cash", capped at 5 per day.
6. **Event pass** for Christmas cosmetics. It is deterministic: a fixed reward ladder shown upfront.

All prices come from `GetProductInfoAsync`, there is exactly one idempotent `ProcessReceipt`, and the "parent test" applies (vault *Ethical Design and Player Trust*).

### G. "Steal Back Christmas" (event design)

- **Story.** **Sir Hoardsworth**, a greedy toy tycoon (original character), has vacuumed every present in town into his Snow Globe Vault. Your crew steals Christmas back before morning.
- **Levels (45 s loops):**
  1. **"Wrapping Room"**: conveyor belts plus gift-wrap lasers.
  2. **"Nutcracker Patrol"**: guards in toy-soldier skins, and a new **Snow Footprints** twist: live players leave footprints that guards follow; echoes leave none.
  3. **"The Snow Globe Vault"**: a scale vault of 8 plus the **Giant Present** (heavy loot, 4 carriers). The getaway is a reindeer-drawn van.
- **Advent calendar.** Dec 1 to 24: one 30-second **mini-vault** per day, the Vault of the Day re-skinned. Each one gives a fixed advent reward (deterministic, not random). Grace days apply, and missed days can be caught up through Dec 31.
- **Community meter.** A server-wide "Presents recovered" counter aggregated across servers (MessagingService every 30 to 60 s). Milestones unlock hub decorations and a Christmas-morning finale cutscene on Dec 24 to 25.
- **Event currency.** **Candy Canes**, earned only and never sold. They are spent on the event's cosmetic track: Santa echo style, sleigh van, snow-globe hideout trophy.
- **Dates.** The event goes live by about Dec 10 (school break traffic starts mid-December) and runs to about Jan 5. Cosmetics stay ownable afterwards, and the levels return next year.

---

## Phased plan for this dimension

| Phase | Dates (2026) | Goal | Exit criteria |
|---|---|---|---|
| **P0: Feel gate** | Nov 12 to 19 | Studio test of v0.1, then rule changes: per-player End take and Scrap, caught ends the take, echo failure states (bonk, zap, busted, shrug), timeline bar, client-side echo replay. | 5 testers: first echo seen at 30 s or less, 4 of 5 say "funny" unprompted, 0 desync reports in 20 loops. |
| **P1: Vertical slice** | Nov 19 to Dec 3 | Levels 1 to 8 (Shop and Bank), Echo Deck with Retake and Delete, medals, Cash plus 3 gadgets, Hub and hideout v1, Heist Replay cam, pings and markers, reserved crew servers, saving. | FTUE funnel at least 70% reach L1Complete; median L1 under 3 min; duo playtest finishes Bank. |
| **P2: Christmas launch** | Dec 3 to 10 | Steal Back Christmas (3 levels), advent mini-vaults, Vault of the Day, cosmetics store plus Starter pack, compliance pass. | Soft launch excluded from RFY for 3 to 5 days; D1 of 20% or more [heuristic]; then open RFY. |
| **P3: Live event** | Dec 10 to Jan 5 | Weekly patch: advent content, Big Score modifiers, bug fixes, leaderboard seasons. | Updates every 5 to 7 days (VIRAL_PLAYBOOK). |
| **P4: Expansion** | Jan to Feb 2027 | Museum (L9 to 12), then Casino, then Moon Base; Season 1 ladder. | D7 of 8% or more [heuristic], intentional co-play share rising. |

---

## Risks

1. **Brain-burn for a young audience.** Record-clone puzzles can feel like programming (Project Temporality was described as "more akin to programming" ([Giant Bomb / Game Developer](https://gamedeveloper.com/design/playing-with-time-in-i-project-temporality-i-))). *Mitigation:* short loops, par echoes of 3 or fewer through level 7, Ghost Hints, a Free Roam Cash mode, comedy failure states.
2. **Desync destroys trust.** One unexplained echo failure and players blame the game. *Mitigation:* the determinism rule, failure states that always show a cause, server and client replay against one clock, Lune tests that replay a recording twice and assert identical mechanism events.
3. **Co-op chaos overload.** *Mitigation:* the 12-echo cap, colour rows, actor-scaled levels, per-player takes.
4. **Performance.** 16 R15 rigs on phones. *Mitigation:* client replay, simplified echo rigs (no accessories beyond the hat), LOD/impostors beyond 80 studs. To be verified by the performance dimension.
5. **Content treadmill.** Handcrafted levels are slow. *Mitigation:* a module-based Vault of the Day, Big Score modifiers and Free Roam multiply each level's lifetime.
6. **Thin demand signal for the mechanic.** No proven viral record-clone hit exists right now. *Mitigation:* the heist theme carries demand (ROB IT 315M visits). The thumbnail and the first clip must show "8 of me" in 1 second.
7. **The Christmas deadline is 4 weeks away.** *Mitigation:* the event reuses the Bank kit with re-skins. Cut level 3's Giant Present before cutting the advent calendar.
8. **Policy drift.** *Mitigation:* zero paid randomness. Recheck the paid-random-items and age-gate docs at each release.

---

## Sources

**Web**
1. Cursor*10, Wikipedia: https://en.wikipedia.org/wiki/Cursor*10
2. Shacknews, "Play With Yourself, Cooperatively (Alone)": https://shacknews.com/article/51032/play-with-yourself-cooperatively-alone
3. Time Rifters, Steam: https://store.steampowered.com/app/270010/Time_Rifters/ and Gamebrain: https://gamebrain.co/game/time-rifters
4. knexator, "Record Clones": https://knexator.github.io/time-genres/record-clones
5. Quantum League interviews: https://mp1st.com/news/nimble-giant-entertainment-talks-about-their-latest-time-bending-shooter-quantum-league and https://gwb.tencent.com/news/10018
6. Lemnis Gate: https://www.gamesradar.com/circular-warfare-lemnis-gate-brings-the-time-loop-craze-to-the-hero-shooter-and-finds-multiplayer-gold, https://www.pushsquare.com/news/2021/04/lemnis_gate_is_a_turn-based_time_looping_multiplayer_shooter_coming_to_ps5_ps4, https://store.steampowered.com/app/950180/_/
7. Talos Principle Reawakened: https://thinkygames.com/features/the-talos-principle-reawakened-isnt-just-a-graphical-revamp-its-the-perfected-edition-of-a-modern-classic and https://steamcommunity.com/app/2806640/discussions/0/830459392060095110
8. Super Time Force: https://www.engadget.com/2012/04/06/the-benefit-of-making-mistakes-in-super-time-force/, https://www.engadget.com/2014/05/13/super-time-force-review-chronological-disorder/, https://xblafans.com/how-super-time-force-avoids-temporal-paradoxes-59645.html, https://godisageek.com/2014/05/super-time-force-review/
9. Twelve Minutes: https://gamedeveloper.com/design/q-a-i-twelve-minutes-i-director-luis-antonio-on-making-good-time-loop-games, https://www.pcgamer.com/uk/12-minutes-review/, https://www.endlessmode.com/video-games/twelve-minutes/twelve-minutes-repetition
10. The Sexy Brutale: https://www.pcgamer.com/the-sexy-brutale-review/, https://kotaku.com/the-sexy-brutale-is-a-game-about-stopping-murders-with-1794340749, https://www.gameinformer.com/games/the_sexy_brutale/b/pc/archive/2017/04/10/the-sexy-brutale-game-informer-review.aspx
11. Outer Wilds: https://scientificgamer.com/thoughts-outer-wilds
12. Deathloop: https://www.looper.com/610276/deathloop-residuum-and-infusion-explained/, https://www.pcgamer.com/deathloop-review/
13. Braid: https://www.gamedeveloper.com/design/design-lesson-101---em-braid-em-, https://gamedeveloper.com/design/video-jonathan-blow-explains-i-braid-s-i-rewind-mechanic-at-gdc-2010
14. Echo (2017): https://www.pcgamer.com/echo-is-a-third-person-sci-fi-action-puzzler-with-evil-clones/, https://www.fandom.com/articles/echo-ex-hitman-devs-brought-ai-to-forefront-of-gaming
15. Teardown: https://get-teardown.readthedocs.io/en/latest/gameplay/heist-basics.html, https://blog.voxagon.se/2020/11/05/teardown-design-notes.html
16. Invisible Inc alarm deep dive: https://gamedeveloper.com/design/game-design-deep-dive-alarm-systems-in-klei-s-i-invisible-inc-i-
17. Monaco: https://shacknews.com/article/77665/how-heist-films-influenced-monaco-whats-yours-is-mine, https://en.wikipedia.org/wiki/Monaco:_What%27s_Yours_Is_Mine
18. Payday 2: https://superjumpmagazine.com/payday-2-so-much-more-than-heists, https://80.lv/articles/how-pubg-battlegrounds-became-a-co-op-heist-game-with-payday
19. Hitman: https://videogames.si.com/features/hitman-freelancer-interview, https://www.cgmagonline.com/articles/editorals/saying-goodbye-to-hitmans-world-of-assassination
20. Heat Signature / Tom Francis: https://pentadact.com/2014-01-25-game-design-the-non-stick-plan, https://pcgamer.com/hands-on-with-heat-signature-the-new-game-from-gunpoint-dev-tom-francis
21. Superhot replay: https://twinfinite.net/guides/superhot-mind-control-delete-watch-real-time-replays/, https://www.gamedeveloper.com/disciplines/the-origin-and-future-of-frozen-time-fps-hit-superhot-and-the-positive-crunching-behind-it
22. Project Temporality: https://gamedeveloper.com/design/playing-with-time-in-i-project-temporality-i-
23. Roblox Docs, Discovery: https://create.roblox.com/docs/discovery; Roblox Newsroom June 2026: https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox; Dubit: https://dubit.io/blog/roblox-top-20-rfy
24. Roblox Docs, Paid random items (updated 2026-10-15): https://create.roblox.com/docs/production/monetization/paid-random-items
25. ROB IT guides: https://nerdschalk.com/rob-it-classes-guide-all-roles-perks-and-unlock-methods/, https://progameguides.com/roblox/roblox-rob-it-classes-tier-list-dynamic_date-formatf-y/
26. Dig to Escape tracker: https://rowatcher.com/games/9145063979/dig-to-escape
27. Holiday trends: https://rolearn.dev/trend-reports/q4-2025-market-trends [UNVERIFIED figures], https://thebloxbit.blogspot.com/2025/12/roblox-christmas-event-2025-festive.html, https://rowatcher.com/news/roblox-halloween-spike-hits-14-9m-ccu-winners-losers

**LihFolk Vault V2 notes**
- *First-Time User Experience and Onboarding*
- *Onboarding and FTUE*
- *Teaching Through Level Design* (§1, §3)
- *Genre Playbook - Puzzle and Escape Rooms* (§3)
- *Puzzle Dependency Charts and Hint Systems*
- *Social Design and Multiplayer Play* (§1, §4, §5, §9)
- *Retention and Return Hooks* (§3)
- *Roblox Policies Ratings and Compliance* (§2)
- *Paid Random Items and Odds Disclosure in Practice*
- *Ethical Design and Player Trust*
- *Pricing and Store Design*
- *Currency Architecture*
- *Game Feel and Juice*
- *Community Building*
- *Friend Invites Referrals and Experience Invites*
- *Teardown - Piggy*
- *Genre Playbook - Obbies and Platformers*

**Live Roblox data (2026-11-12):** `tools/rbx_search.py` ("heist", "dig to escape", "clone yourself", "bank robbery", "rob a bank") and the games API for universes 9145063979, 16680835, 9472441390 and 7383133134.

**Project files:** `README.md`, `PROJECT_STATE.md`, `src/shared/Config.luau`, `src/server/Echoes.luau`, `src/server/Main.luau`, `docs/IDEA_ECHO_HEIST.md`, `docs/VIRAL_PLAYBOOK.md`, `docs/GAME_BIBLE.md` (§3.9, §4.2, §7.1).
