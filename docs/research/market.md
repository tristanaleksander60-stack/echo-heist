# Market research: competition, originality, risks and references (2026-11-12)

Dimension: competition, originality, risks & references. Owner: research pass for "Echo Heist" (working title), prototype v0.1.
Method: 45+ live Roblox searches (`tools/rbx_search.py`) plus descriptions and vote counts from the games API, both radars (`trend_radar.py --days 30`, `steam_radar.py --lists popularnew,popularcomingsoon --count 30`), 25 web searches and 9 LihFolk vault notes. Live numbers are a snapshot from 2026-11-11 23:30-23:45 UTC. They move hourly, so treat them as orders of magnitude. **Fact** = cited. **Rec** = my recommendation. Anything I could not confirm is marked [UNVERIFIED].

---

## Summary

1. **The mechanic is not new, and our own originality note is out of date.** Record-and-replay-yourself is a game-jam staple: GMTK Game Jam 2025's theme was "Loop", and there are dozens of entries. There are at least five commercial single-player puzzlers (2014-2026) and one Roblox game that does exactly this. That game, **"ECHOES: Clone Puzzles [MULTIPLAYER]"** (created 2026-10-03), sits at **0 CCU with 20,926 visits** and has not been updated since 2026-10-14. On the competition side, `docs/IDEA_ECHO_HEIST.md`'s line "No game uses recordings of your past runs as co-op partners" is now false.
2. **What is still original on Roblox: the mechanic used as the crew in a co-op stealth heist.** No Roblox heist game uses replays of your own runs. Every heist hit uses live players only. *Position the game as a heist game whose twist is the echoes, not as a clone puzzle game.* The puzzle framing already failed on Roblox.
3. **The name "Echo Heist" is taken.** At least two itch.io games use it. One (nitrous-studio) is the same concept: a single-player stealth museum heist where "each loop creates an echo of your previous run" to pass lasers and distract guards. A second (Geronimokuwait, GameJamPlus 2025/26) went public on 2026-01-08. ECHO (2017) by the **Danish** studio Ultra Ultra is also a stealth game about copies of yourself, and Roblox has several "ECHOES" titles. **Decision: rename before any art, thumbnail or icon work.**
4. **Demand is strong, and it sits in the heist/steal audience.** Criminal Simulator (Roblox, created 2026-10-08, 1-4 players, sneak and steal at night): **18,628 CCU**, 92.6% likes. BE TINY AND ROB GRANDPA: **5,233 CCU**, 54M visits, with the rule "grab $1,000 and escape". ROB IT: 315M visits since 2025-12-31. Off-platform, ROB RUN (Steam, free crime sandbox, launched 2026-11-04) showed **238,874 CCU** on our radar, and GTA 6 is due **2026-11-19**. Crime and heists are the hottest theme across platforms this month.
5. **The single-player and VR time-clone games never broke out. Quantum League, the one multiplayer clone shooter, shut down in December 2023.** The co-op heist genre on Steam is also soft: Monaco 2 has Mixed reviews and an estimated 6.3K units. On Roblox our risk is not copycats. It is that **the mechanic is hard to read in a 3-second clip and a 60-second first session.** Clarity, a visible clip engine and a fast first reward decide this game, not novelty.
6. **Verdict: AMBER-GREEN. Build it, but change four things:** rename; make "heist with friends" the headline and "your crew is you" the hook; add a ragdoll/fail clip engine (ragdolls own the Roblox trend radar this month); and plan to protect the idea, because once we pass 5K CCU, copies will follow within 1-3 weeks (our Viral Playbook data).

---

## Findings (with citations)

### F1. Roblox: does anyone do record-and-replay-yourself co-op?

Queries run (45+, among them): echo, echoes, clone, time clone(s), clone yourself, copies of yourself, multiply yourself, duplicate, shadow clone, time loop, rewind, replay yourself, record yourself, record and replay, recording replay puzzle, time rewind puzzle, past self, cooperate with your past self, ghost of yourself, ghost replay, ghost run, self co-op, time paradox, timeline, deja vu, groundhog day, heist, loop heist, echo heist, co-op heist, rob the bank, vault, laser, guard stealth, stealth, sneak, thief, burglar, robbery, loop robbery, entry point, jewelry/museum/casino heist, time travel heist, christmas heist, steal christmas, jailbreak, speedrun heist, plus four name candidates.

| Game (universeId) | Live CCU | Visits | Created | What it actually is |
|---|---|---|---|---|
| **ECHOES: Clone Puzzles [MULTIPLAYER]** (10769139317) | **0** | 20,926 | 2026-10-03 | "Record your movements. Create a clone. Solve puzzles with your past self." 28 levels, SP/MP/Duels. **Same core mechanic, puzzle framing, dead in 6 weeks.** |
| Clone Yourself (10774186645) | 25-31 | 32,885 | 2026-11-01 | No description, tycoon genre. Watch it. |
| Clone Engine (6128091457) | 1,831 | 417M | 2024-06-16 | Clones *follow* you; satisfying-swarm sandbox |
| Clone Friends (6417204510) | 1,341 | 151M | 2024-08-14 | Spawn clones and command them |
| Clone Yourself (1761773144) | 591 | 240M | 2020-05-25 | Clone sandbox |
| Loop [ALPHA] (10749778558) | 33 | 816K | 2026-08-21 | Liminal roguelike "day loop", not replay |
| POOL LOOP (10772175135) | 151 | 126K | 2026-10-21 | Anomaly-spotting loop (Exit 8 style) |
| Confronting Yourself Multiplayer (9417235913) | 22 | 3.5M | 2025-12-24 | Sonic fan game (borrowed IP) |

Fact: the only Roblox game with replay-of-yourself co-op is ECHOES: Clone Puzzles, and it failed. Clone sandboxes (followers, not recordings) earned 150-420M visits, so "lots of copies of me" is a proven visual. The *recording* mechanic has no demand signal on Roblox yet.
Rec: never describe the game as a "puzzle game". Thumbnails and title should say *heist*. The clone swarm is the visual payoff (Clone Engine proves people enjoy watching many copies of themselves).

### F2. Roblox: heist and stealth games (our audience)

| Game | Live CCU | Visits | Likes % | Created / updated | Lesson |
|---|---|---|---|---|---|
| Jailbreak | 4,363 | 8.09B | n/a | 2017 / 2026-11-05 | Timed server-wide robberies; "Go together or solo!" in the description |
| Notoriety: A PAYDAY® Experience | 1,544 | 566M | 92.5% (606K/49K) | 2010 / 2026-11-11 | Deep co-op heists. **Officially licensed since Dec 2024** after it was halted in 2023 over copyright concerns ([Starbreeze](https://starbreeze.com/news/notoriety-relaunches-on-roblox-as-an-official-payday-experience), [Automaton](https://automaton-media.com/articles/newsjp/20241213-321591/)). Starbreeze and Gamefam announced a second PAYDAY Roblox game on 2026-04-29 ([PocketGamer.biz](https://www.pocketgamer.biz/starbreeze-partners-with-gamefam-for-new-payday-game-on-roblox/)) |
| Entry Point | 112 | 349M | 90.5% | 2017 / **2025-07-10** | A stealth-heist classic that dies without updates |
| **Criminal Simulator** | **18,628** | 21.6M | 92.6% | **2026-10-08** | "Rob the city at night with your crew, sneak past residents, outrun police and dogs, sell loot before the deadline. Pay off the debt or face the sniper. 1-4 players." Tracker peak about 32K ([RoWatcher](https://rowatcher.com/games/10769851460/criminal-simulator-alpha), [GamesRadar codes](https://www.gamesradar.com/games/simulation/criminal-simulator-codes/)) |
| ROB IT | 1,945 | 315M | 95.8% | 2025-12-31 | "Select your mission, break in, don't let the guard see you." Runs of 6-7 min ([earnaldo guide](https://earnaldo.com/blog/rob-it)); about 6.3K CCU on a tracker earlier, falling ([RoWatcher](https://rowatcher.com/games/9472441390/rob-it)) |
| BE TINY AND ROB GRANDPA | 5,233 | 54M | n/a | 2026-02-15 | "Don't wake up Grandpa! Sneak in, grab $1,000, and escape." A one-line rule with a face as the threat |
| RUNAWAYS | 5,263 | 178M | n/a | 2025-04-23 | Rob, pawn, blow vaults, outrun police |
| Wanted / Riot City | 4,579 / 2,389 | 149M / 108M | n/a | 2023 / 2025 | Cops-and-robbers open world |
| HEIST: Rob a Store | 598 | 4.7M | **73.6%** | 2026-10-09 | Feature-rich stealth/loud (lockpicks, cameras, guns, rarity rolls), but the like ratio is weak. Proof that features without clarity get disliked |
| Risky Heist / Heist Evolution | 1,756 / 2,190 | 0.36M / 2.4M | 95.9% / 95.6% | 2026-10-29 / 2026-05-01 | Heist as a tycoon: break doors, steal, upgrade |
| HEISTBLOX | 1,024 | 0.8M | n/a | 2026-10-02 | Cops vs robbers PvP shooter |
| Cat Burglars | 14 | 2.4M | n/a | 2026-09-14 | **The closest theme to ours** (museum, lasers, guard dogs, van, team carry), now dead. Theme alone isn't enough |

Facts: four heist/steal games created in 2026 hold 1.7K-18.6K CCU right now. Live data says the newest hit, Criminal Simulator, is **night + sneak + crew of 1-4 + deadline + escalating threat**. The vault's *Case Study - Jailbreak* and *Genre Playbook - Open-World City and Crime Roleplay* add: robberies are multi-step, timed and validated by position on the server, and progression shows as visible possessions.

Recs (what our audience expects):
- **A heist of 5-8 minutes**, about 5-8 loops. ROB IT's 6-7 min runs are the benchmark. A 60 s loop is a beat, not a session.
- **A threat with a face.** Grandpa, the sniper and police dogs. Our guard needs a character, a name and a funny "huh?" animation when he catches an echo.
- **1-4 players and solo on the store page**, like Criminal Simulator and Jailbreak.
- **A price on failure, and a deadline.** "Sell before the deadline" and the debt in Criminal Simulator. Our equivalent is an alarm or dawn after loop N.
- **Clarity over features.** HEIST: Rob a Store's 74% like ratio is the warning.

### F3. Steam, itch, VR, mobile: who else does "your past self is your crew"?

| Title | Year / platform | Mode | Signal | Source |
|---|---|---|---|---|
| Causal Loop | Apr 2026, Steam | SP; record up to 3 past selves; narrative | Small | [Steam](https://store.steampowered.com/app/3374460/Causal_Loop/) |
| UnLoop | Nov 2025, Quest + Steam VR | "Self co-op"; past copies replay actions **and voice** | Praised, niche | [Meta blog](https://www.meta.com/blog/unloop-launch/), [SteamDB](https://steamdb.info/app/2672470/) |
| Record Rewind Repeat | Jun 2025, Steam | SP platformer, 50 levels | Small | [Steam](https://store.steampowered.com/app/3477030/Record_Rewind_Repeat/) |
| Loop Heist (HAESO GAMES) | Oct 2026, browser demo + Android | Raccoon thief, recorded route becomes a partner, up to 3 past selves, 63 puzzles | Press release only. A second search did not confirm the studio or the Android version [UNVERIFIED] | [COGconnected](https://cogconnected.com/2026/10/loop-heist-browser-demo-turns-your-recorded-moves-into-a-heist-partner/), [Games Press](https://www.gamespress.com/Loop-Heist-browser-demo-turns-your-recorded-moves-into-a-heist-partner) |
| Echo Heist (nitrous-studio) | itch, Windows | SP stealth museum heist, an echo per loop, lasers, guards | Jam scale | [itch](https://nitrous-studio.itch.io/echo-heist) |
| Echo Heist (Geronimokuwait) | itch, public 2026-01-08 | GameJamPlus 2025/26 entry | Jam scale | [itch](https://geronimokuwait.itch.io/echo-heist), [devlog](https://geronimokuwait.itch.io/echo-heist/devlog) |
| Repeat Offender (matt9440) | s&box Game Jam #1 | "Pull off the perfect crime with versions of your past self" | Jam | [itch](https://matt9440.itch.io/repeat-offender) |
| Timeloop Heist, Loop Heist (thebeanladder), Clone Loop, Past Loop, Time Clones | GMTK 2025/2026 and other jams, browser | Clone-of-last-run heists and puzzles | Jam | [itch](https://gohgames.itch.io/timeloop-heist), [itch](https://thebeanladder.itch.io/loop-heist), [itch](https://birikyc.itch.io/clone-loop), [GMTK 2025](https://itch.io/jam/gmtk-2025/rate/3780440), [web](https://timeclones.web.app/) |
| The Last Clockwinder | 2022, VR | Record 2-8 s loops of yourself; clones work "in harmony"; Quest GOTY 2022 | Acclaimed | [Meta interview](https://www.meta.com/blog/designing-last-clockwinder-best-of-quest-2022/), [GDC Art talk](https://www.gdcvault.com/play/1028958/Art-of-The-Last-Clockwinder) |
| Super Time Force | 2014 | "Single-player co-op" with your own past iterations | Cult hit | [GDC Vault](https://gdcvault.com/play/1020103/Super-Time-Force-Solving-the), [Game Developer](https://www.gamedeveloper.com/design/video-solving-the-time-travel-paradox-for-i-super-time-force-i-) |
| Quantum League | 2020-2023 | **PvP** time-loop clone shooter | **Shut down 2023-12-18** | [Kotaku](https://kotaku.com/dead-games-2023-delisted-servers-offline-1850083031/4), [GameGrin](https://www.gamegrin.com/news/quantum-league-to-receive-no-more-updates) |
| ECHO (Ultra Ultra, Denmark) | 2017 | Stealth; AI copies of you learn your actions | Name and concept neighbour | [PC Gamer](https://www.pcgamer.com/echo-is-a-third-person-sci-fi-action-puzzler-with-evil-clones/), [GamesRadar](https://www.gamesradar.com/these-ex-hitman-devs-are-messing-with-your-assumptions-about-enemy-ai-in-echo/) |

Neighbouring heist games on Steam: Monaco 2 (2025-04-10, $24.99, OpenCritic 75, Steam Mixed, an estimated 6.27K units [estimate]) ([OpenCritic](https://opencritic.com/game/18260/monaco-2), [steamdata](https://steamdata.ai/game/1063030)); Relooted (2026-02-10, heist as puzzle, OpenCritic 72, a modest launch) ([Gematsu](https://www.gematsu.com/2026/01/relooted-launches-february-10), [Edge](https://knowledge.edge-online.com/p/making-relooted-the-game-was-always-going-to-have-a-cultural-impact-vastly-exceeding-its-financial-i)); Robbing Time (co-op horror heist vs superheroes, Early Access) ([press](https://thegg.net/press-releases/the-co-op-horror-superhero-game-robbing-time-is-out-now-via-steam-early-access/)); Haunted Heist (claimed 70M social views [UNVERIFIED], but an estimated 30.6K wishlists and a 224 all-time CCU peak) ([Raijin](https://raijin.gg/app/4024440/Haunted_Heist), [Game Developer](https://www.gamedeveloper.com/press-release/game-announcement-haunt-your-friends-in-viral-horror-comedy-co-op-title-haunted-heist-)).

Facts: I found **no trending 2025-2026 indie with record-yourself co-op** on Steam, TikTok or YouTube. Searches for "past self clone time loop" on TikTok returned only lifestyle "future self" content and the titles above. No title gives us a halo to ride, and none will flood Roblox with copies of our exact mechanic.
Rec: the jam density is a warning. Developers love the idea, and players have mostly met it as a short puzzle. Our edge must come from what jams can't do: **live multiplayer with everyone's echoes at once (10-16 robbers), an avatar-based crew, persistent progression and a daily seeded vault.**

### F4. Trend radars (2026-11-11)

**Roblox (`trend_radar.py --days 30`, 94 games under 30 days old, out of 895 on explore).** Note: the default run crashed on a malformed earlier snapshot (`p["rows"]` on a string) in `radar/`. I re-ran it with `--snapdir` in my scratchpad. Someone should fix that tool in a separate task.
- #1 DONT SPLASH, 53.8K CCU (Poolrooms horror). Then a **ragdoll wave**: Bloody Ragdoll Physics 30.1K, Hyper Realistic Ragdoll 25.0K, Ragdoll Research 17.7K, Ragdoll Realism 11.4K, Ragdoll Sandbox 10.0K, Realistic Ragdoll Engine 9.3K, Ragdoll Wars 7.9K, Ragdoll Reality 7.8K. Eight of the top 28 new games are ragdoll sandboxes.
- Steal/escape themes: Tesla Roadster Chase (steal a car, escape police) 8.6K. Criminal Simulator is just past the 30-day window at 18.6K.
- Relevance: **physical comedy is today's clip currency.** Getting zapped by a laser or caught by the guard should end in a stylised ragdoll flop, with no blood so we keep a Minimal/Mild label (vault: *Gore Policy and Kid-Friendly Hit Feedback*). A stack of echoes all flopping into the same laser is our version of the trend.

**Steam (`steam_radar.py`, popular new and popular coming soon, online co-op).**
- **ROB RUN**: 238,874 CCU live, free, released 2026-11-04. Press reported a 140,440 peak on 2026-11-08 and about 60% positive reviews ([Mein-MMO](https://mein-mmo.de/rob-run-steam-early-access-start/), [Game*Spark](https://www.gamespark.jp/article/2026/11/09/174657.html), [games.gg](https://games.gg/rob-run/)). The radar finds no Roblox copy, but the genre is Roblox's own (Jailbreak, Criminal Simulator).
- **Grand Theft Timeline**: a 1-8 player time-travel heist (200+ era buttons). The radar lists it for 2026-11-19; the store says Q4 2026, and the developer aims for GTA 6 day ([Steam](https://store.steampowered.com/app/4928450/)). It drew controversy for teasing a 9/11 level ([InGameNews](https://ingamenews.com/pc-gaming/co-op-steam-game-grand-theft-timeline-teases-9-11-level/)). **Watch it.** If it pops, "time + heist" searches spike, and we should already have a playable build and a clean, kid-safe angle.
- **GTA 6 releases 2026-11-19** according to Take-Two ([Gameluster](https://gameluster.com/take-two-gta-6-november-2026-on-track/)). Most Roblox players are too young for it, so heist appetite on Roblox should rise in late November and December [inference].
- Also relevant: Dumpster Gang (2026-12-03, raccoon steal-everything co-op), PAYDAY 3 (5.4K CCU, the heist core audience on PC), FAKE ME, Big Climb.

### F5. IP and naming

- **"Echo Heist" collides** with two itch.io games, one with the same concept (F3), and sits close to ECHO (Ultra Ultra) and to the Roblox titles ECHOES [V1.7] and ECHOES: Clone Puzzles. A store search for "echo" on Roblox returns horror games. **Rename.**
- I checked candidate names on Roblox. "Repeat Offenders" has no Roblox game; small itch jams use "Repeat Offender" (singular), one of them a past-self heist ([itch](https://theoclarke.itch.io/repeat-offender), [itch](https://matt9440.itch.io/repeat-offender)), and it is a GTA achievement name. "Crew of Me" has no hits. "Rerun Heist" and "Me Myself Heist" have no exact hits.
- **Never use:** PAYDAY (the Dallas/Hoxton/Wolf/Chains crew, clown masks, the "PAYDAY" wordmark; Starbreeze licenses and enforces it on Roblox, see F2); Monaco (top-down colour-coded thieves, the Locksmith/Pickpocket/Lookout/Cleaner roles, the Monaco name and art); Jailbreak (its police/criminal bank-and-museum UI, the "Jailbreak" word, the Badimo look); Notoriety; Entry Point/Halcyon; Hitman (barcode, Agent 47); Ocean's (film names); the "How the Grinch Stole Christmas" look (a green, furry, Christmas-stealing villain) for our "Steal Back Christmas" event; Ultra Ultra's ECHO name and look (glowing white palace, "En").
- **Lawsuits are real now.** Steal a Brainrot's developers have filed at least four suits against copycats, aimed at interface, level design and animations ([Bloomberg via The Star](https://www.thestar.com.my/tech/tech-news/2026/03/25/robloxs-hit-game-steal-a-brainrot-battles-its-many-imitators), [PC Gamer](https://www.pcgamer.com/games/a-brainrot-themed-roblox-game-is-taking-a-brainrot-themed-fortnite-game-to-court-for-being-a-copy/)). Vault *Legal Basics - IP Licenses and Assets* §5: "inspired by" is fine for ideas and genres. Copying the layout, art and UI closely enough that players think it is the same game is not.
- **AI assets:** vault *Who Owns AI-Generated Code and Assets*: keep the mascot and logo human-authored or substantially human-edited, and keep a provenance log. That matters because Claude builds almost everything.

### F6. Platform policy facts that shape the market (vault, checked 2026-10-28/29, plus web)

- Maturity labels: Minimal/Mild reaches Kids (5-8), Select (9-15) and everyone else. Moderate reaches Select and 16+. Strong violence and heavy blood require 18+. **Games without a questionnaire are unplayable** (vault *Policy and Age Rules 2026*).
- All-ages reach needs an ID-verified creator with 2SV plus Plus/Premium or a refundable 1,000 Robux fee, and an evaluation. Third-party reports say the highly engaged threshold for Kids/Select drops from 250 to 100 this November ([walkthroughs.net](https://walkthroughs.net/roblox-highly-engaged-player-threshold-drops-to-100-explained)) [UNVERIFIED]. Trust the Audience Reach dashboard (vault *Publishing an Experience*).
- The default thumbnail has been ineligible for Home since 2026-10-19. qPTR no longer exists. RFY ranks on play-through, first-play bounce, D1/D2-7/D8-28 and intentional co-play (vault *Discovery and Monetization Changes 2025-2026*; GAME_BIBLE §4.1).
- Chat requires an age check worldwide, and age groups chat only with neighbouring groups ([Roblox IR](https://ir.roblox.com/news/news-details/2026/Roblox-Requires-Users-Worldwide-to-Age-Check-to-Access-Chat/default.aspx)). **Gameplay must not depend on chat.** In-game social links are gone, and rewarding likes/favourites is listed as a mistake (vault *Community Building*). Several competitors still do "2,000 likes = free code"; we won't.
- Discovery is becoming age-aware ([Roblox newsroom](https://about.roblox.com/newsroom/2026/11/david-baszucki-sits-down-with-bloxy-news)). A kid-safe, non-gun heist can reach the under-13 audience that Notoriety, HEISTBLOX and Entry Point (guns) cannot fully serve.
- Roblox Moments lets players capture clips of up to 30 s and post them to an in-app feed with a jump-in button; there is a Captures API for creators ([Roblox newsroom](https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery), [TechCrunch](https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more)). A 60 s loop fits a 30 s clip if we cut it in half.

### F7. Technical claims checked against our code

- `src/server/Echoes.luau` records at 15 Hz (`Config.RECORD_HZ`) and replays by setting `root.CFrame` on **anchored avatar clones on the server every Heartbeat**. The caps are 4 echoes per player and 16 in total (`Config.luau`). PROJECT_STATE already flags choppy replication.
- Vault *Replication and Ownership*: an Animator outside a player's character must start tracks on the server to replicate, or the server writes state and every client animates, which is the architecture that scales. Vault *Enemy and NPC Animation*: animation LOD and 10 Hz staggering for many NPCs.
- Vault *Deterministic Simulation*: fixed timestep, seeded `Random` per stream, sorted iteration. That matters for the guard reset each loop (already done) and for a daily seeded "Vault of the Day".
- Market implication: **16 full avatar clones on a 3-year-old phone** is the performance risk most likely to make mobile players bounce, and mobile is most of Roblox [inference]. The fix is client-side replay from a compact buffer, plus LOD (full avatar near, silhouette far). The tech research doc covers it.

---

## Recommendations / decisions

**D1. Rename now (before thumbnails, icon or a public test).** My pick is **"Repeat Offenders"**, a store title that is also the joke: your echoes literally repeat the offence. The backup is "Crew of Me". Rules: no "Echo" in the title; "echo" stays fine as the generic in-game noun. Before committing, run EUIPO/USPTO checks in class 9/41 and a Roblox search on the day of publish. Owner decides. If the owner prefers a coined brand, test 3 names as thumbnails A/B (D7).

**D2. Positioning: "a co-op heist where your crew is YOU."** Every store asset leads with the heist and shows 6-12 synchronized copies. Never use the words "puzzle" or "clone puzzle". The genre on the page is "heist / stealth, 1-4 players, solo OK". Model the description on Criminal Simulator and Rob Grandpa: one line, one goal, one threat.

**D3. A session shape that matches the audience.**
- Heist = 5-8 loops of 60 s, so 5-8 minutes. The first heist (corner shop) takes 3 loops and under 4 minutes.
- **First reward at 45 s or sooner.** The player grabs cash in loop 1 even if they fail. Then rewind, see the echo, "woah". The ECHOES: Clone Puzzles failure suggests a tutorial-first, puzzle-first opening loses players.
- A deadline: "the alarm trips after loop 6" or "dawn at loop 8" gives stakes (Criminal Simulator's debt/deadline pattern).

**D4. A clip engine on top of the mechanic, all kid-safe (Minimal/Mild):**
1. Stylised ragdoll flop when an echo or player hits a laser or gets grabbed (rides the ragdoll wave, F4).
2. The guard gets a face, a name and a 1.5 s "?!" double-take when he catches an echo. He is the Grandpa of our game.
3. Every loop ends on a "SYNC" replay: an automatic 10-15 s cinematic of all echoes from a high camera, built for Moments and TikTok, with a big counter ("x8 YOU").
4. A "Betrayed by Past Me" stinger: when an echo triggers a fail, freeze-frame plus a caption. This is the joke from the concept doc made into a system.

**D5. Scale the hook through friends.** 2-4 players with 4 echoes each = up to 16 robbers. Make co-op rewards real (RFY counts intentional co-play): a crew bonus on loot, a "whole crew synced" medal, and party invites using `CanSendGameInviteAsync` (vault *Community Building*). This is the thing jams and single-player puzzlers cannot copy.

**D6. Defend the idea before launch.** The Viral Playbook says the copy machine takes 1-3 weeks, sometimes 1 day. Moats to build:
(a) a daily seeded "Vault of the Day", the same on every server, with a leaderboard of "fewest echoes";
(b) progression saved per account (echo slots, gadgets, hideout trophies);
(c) a weekly target drop (shop → bank → museum → casino → moon);
(d) a distinctive, owned art identity (not "default Roblox heist"), with the mascot and logo human-finished;
(e) the lead: be live and updated weekly before anyone notices.

**D7. Test positioning with numbers, not opinions.** Once Roblox thumbnail tests (or private test servers) are live: compare 3 thumbnails ("8 of me robbing a vault", "my past self betrayed me", "heist with friends") on play-through and first-play bounce, keep the winner, and re-test monthly.

**D8. Timing.** Don't rush a soft launch to hit GTA 6 week (2026-11-19). The prototype hasn't run in Studio. **Target soft launch 2026-12-08 to 2026-12-12 with the "Steal Back Christmas" level**, then the RFY and TikTok push on a Friday-Saturday (GAME_BIBLE §4.3). Christmas competition on Roblox is tycoons and "Steal From Santa" (60 CCU), so a Christmas *heist* has room.

**D9. Fix the out-of-date originality claim.** `docs/IDEA_ECHO_HEIST.md` should say "the mechanic exists (ECHOES: Clone Puzzles, many jams); the heist co-op use is ours". I did not edit it here; this task only writes this file. Flag it for the owner or the next session.

---

## Phased plan for this dimension

| Phase | When | Work | Done when |
|---|---|---|---|
| 0. Name and claims | This week (by 2026-11-16) | Pick the name (D1); trademark and Roblox search; update IDEA doc originality; add ECHOES: Clone Puzzles, Criminal Simulator, ROB IT, Rob Grandpa, Clone Yourself (10774186645) and Grand Theft Timeline to the Viral Playbook watchlist | Name in PROJECT_STATE "Decisions" |
| 1. Benchmark the audience | Weeks 1-2, alongside the Studio test | Play Criminal Simulator, ROB IT, Rob Grandpa and Notoriety for 20 min each; write time-to-first-reward, run length, threat, invite flow and thumbnail per game in a table; set our targets (first reward ≤45 s, heist ≤8 min) | Targets in Config/PROJECT_STATE |
| 2. Clip-engine prototype | Weeks 2-3 | Ragdoll flop, guard double-take, SYNC replay cam, "Betrayed by Past Me" stinger (D4); record 5 test clips, 15 s each, muted | 3 of 5 clips readable without sound by someone outside the team |
| 3. Positioning test | Week 3-4 | 3 thumbnails and icons; private playtest with 5-10 kids/teens in the target age range (parental consent); measure bounce under 60 s and whether testers say "heist" or "puzzle" when they describe it | ≥70% describe it as a heist game |
| 4. Soft launch plus Christmas | 2026-12-08 to 12-12 | Christmas level, daily vault, saving; questionnaire answered for Minimal/Mild; custom thumbnails | D1 ≥ 20% (H), first-play bounce under the vault's thresholds |
| 5. Watch and defend | From launch, weekly | Radars twice a week; Roblox search for "loop heist / clone heist / past self" weekly; on a copy above 1K CCU, ship the next target within 7 days instead of complaining | Weekly update cadence held for 6 weeks |

---

## Risks

| # | Risk | Type | Likelihood / impact | Mitigation |
|---|---|---|---|---|
| 1 | **Mechanic unreadable in 3 s** (viewers see "ghosts", not "past me") | Design / market | High / High | Colour and number every echo ("RUN 2"), and show a trail of the path before replay; SYNC cam; the first loop shows the echo replaying within 60 s |
| 2 | **Puzzle-game perception** (ECHOES: Clone Puzzles died at 0 CCU) | Market | Medium / High | Heist-first copy, thumbnails and title (D2); loot in loop 1 |
| 3 | **Name collision / confusion** ("Echo Heist" on itch, ECHO by Ultra Ultra, Roblox horror "ECHOES") | IP / market | Certain / Medium | Rename now (D1); trademark check |
| 4 | **Fast copies** once we pass about 5K CCU (1-3 weeks; some built with AI) | Market | High / Medium | Moats D6; weekly updates; owned art; the multiplayer echo sync is hard to copy well |
| 5 | **First session too long or too thinky** for 9-13 year olds | Design | High / High | First reward ≤45 s; level 1 needs 1 echo; stuck hint after 2 failed loops (lihfolk-tutorial) |
| 6 | **Mobile performance with 16 avatar clones** | Tech | High / High | Client-side replay from buffers, animation and avatar LOD, an option to cap visible echoes at 8 on low-end devices; test on a 3-year-old phone |
| 7 | **Choppy echo replication** (server CFrame every Heartbeat) | Tech | Already seen / Medium | Interpolated client replay, server keeps an authoritative position for plates and guard (CLAUDE.md rule) |
| 8 | **Desync between what echoes "do" and world state** (door closed when the echo arrives) | Design / tech | Medium / Medium | Make it a feature: the echo bonks into the door and ragdolls ("betrayed"); all decisions go through Actors and recorded events (CLAUDE.md) |
| 9 | **Griefing in public co-op** (one player's bad echoes ruin the run) | Design | Medium / Medium | Per-player echo delete, a vote-to-skip loop, friends-only servers free, solo always available |
| 10 | **Maturity label slip** (guns, blood, realistic crime) cuts the under-13 audience | Policy | Low-Medium / High | No guns; stylised ragdoll, no blood; answer the questionnaire for the max content; aim for Minimal/Mild |
| 11 | **Chat-dependent coordination fails** under age-based chat | Policy / design | Medium / Medium | Pings, emotes and a "plan board" with icons; no gameplay needs typed chat |
| 12 | **Policy-breaking growth tricks** (likes-for-codes, social links, misleading thumbnails) | Policy | Medium (competitors do it) / High | Don't do it; honest 16:9 thumbnails rendered from the game (vault *Thumbnails Icons and Store Page*) |
| 13 | **Heist trend cools** after GTA 6 and ROB RUN hype fades | Market | Medium / Medium | The mechanic plus progression carry it; theme rotation (moon base, casino); a Christmas event as a second wave |
| 14 | **Solo team bandwidth** (art "vanvittigt grafisk" plus weekly updates) | Team | High / High | Small, dense levels; one kit per target; content as data rows; batch art; cut moon base until there is proof |
| 15 | **AI asset ownership and provenance** (mascot or logo not defensible) | Legal / team | Medium / Medium | Mascot and logo human-finished; provenance log (vault *Who Owns AI-Generated Code and Assets*) |

---

## Reference list: the 15 to study

1. **Criminal Simulator (Roblox, 10769851460)**: the current hit for our audience. 1-4 crew, night, sneak, deadline, a threat with a face. Benchmark the first 5 minutes.
2. **BE TINY AND ROB GRANDPA (Roblox, 9734324739)**: a one-line rule ("Don't wake Grandpa, grab $1,000"). Our README even uses $1,000. Steal the clarity, not the content.
3. **ROB IT (Roblox, 9472441390)**: stealth heist with 6-7 min runs and a mission select; 315M visits in 10 months.
4. **ECHOES: Clone Puzzles (Roblox, 10769139317)**: an anti-reference. Same mechanic, puzzle framing, 0 CCU. Play it and list why you'd leave.
5. **Clone Engine (Roblox, 6128091457)**: why watching many copies of yourself is satisfying (417M visits). Study the formation and swarm visuals for the SYNC replay.
6. **Jailbreak (Roblox) plus vault *Case Study - Jailbreak***: timed, server-validated robberies; visible progression; 9 years of updates.
7. **Notoriety (Roblox)**: depth in co-op heists, and the IP lesson (stopped, then licensed).
8. **Super Time Force: "Solving the Time Travel Paradox" (GDC 2014)**: "single-player co-op" with your past selves; "feel is more important than being logical" ([GDC Vault](https://gdcvault.com/play/1020103/Super-Time-Force-Solving-the)).
9. **Jonathan Blow on Braid's rewind (GDC 2010)**: storing and compressing world state over time; our replay buffer problem ([Game Developer](https://gamedeveloper.com/design/video-jonathan-blow-explains-i-braid-s-i-rewind-mechanic-at-gdc-2010)).
10. **The Last Clockwinder (play it) plus the Meta design interview and "Art of The Last Clockwinder" (GDC 2023)**: the best existing "your clones in harmony" feel; how readable loops look ([Meta](https://www.meta.com/blog/designing-last-clockwinder-best-of-quest-2022/), [GDC](https://www.gdcvault.com/play/1028958/Art-of-The-Last-Clockwinder)).
11. **UnLoop (Quest/Steam, 2025)**: self co-op where echoes also replay your voice. A great idea for a later "echo voice-line emotes" feature (no voice recording; use preset lines).
12. **Level Design in HITMAN: Guiding Players in a Non-Linear Sandbox (GDC, IO Interactive, Copenhagen)**: how to guide players through a heist sandbox without a tutorial ([GDC Vault](https://www.gdcvault.com/play/1023849/contactUs)). A Danish studio, too.
13. **Designing Procedural Stealth for Invisible Inc. (GDC, Klei)**: guard rules that are readable and fair ([GDC Vault](https://gdcvault.com/play/1021919/contactUs)), plus the Game Developer lesson on modern stealth problems ([link](https://www.gamedeveloper.com/design/lesson-the-problems-of-modern-stealth-design-and-how-invisible-inc-solves-them)).
14. **Monaco / Monaco 2**: co-op heist chaos and readable roles, and a warning that the premium co-op heist is a soft market on Steam ([OpenCritic](https://opencritic.com/game/18260/monaco-2), [Game Developer: Doing stealth the Monaco way](https://gamedeveloper.com/business/doing-stealth-the-i-monaco-i-way)). Do not copy its look.
15. **Game Maker's Toolkit: "Clockwork Games and Time Loops"**: why loops invite experiment, and Minit's "everything reachable in seconds" rule. Our bank must be crossable in about 10 s ([transcript](https://amara.org/subtitles/3ogCRpZfAjOh/en/1/download/Clockwork%20Games%20and%20Time%20Loops.en.txt)).

Also useful: Quantum League (why PvP clone complexity died), ECHO by Ultra Ultra (what a stealth game about copies of you looks like, and a name to avoid), PAYDAY 2 replayable stealth levels ([80.lv](https://80.lv/articles/designing-highly-replayable-stealth-levels-for-payday-2/)), Randy Smith "Level Building for Stealth Gameplay" ([GDC Vault](https://gdcvault.com/play/1013435/Level-Building-for-Stealth)).

---

## Sources

**Live Roblox data (2026-11-11):** `tools/rbx_search.py` (45+ queries listed in F1); `games.roblox.com/v1/games` and `/v1/games/votes` for universeIds 10769139317, 10774186645, 6128091457, 6417204510, 1761773144, 10749778558, 10772175135, 9417235913, 10766923544, 245662005, 16680835, 324740177, 10769851460, 9472441390, 9734324739, 7585140258, 4987856151, 9296042754, 10769938104, 10773629747, 10107832573, 10768934595, 10766398868, 10770287012, 7383133134, 10771277620, 10764463725, 10768755607, 6355103076, 9367417252, 8996304673, 9286558970, 10061909806, 10456881513, 10764646424, 10765309568, 10416092178, 9771929732, 10766058238, 9954447663, 10771421858.

**Radars:** `tools/trend_radar.py --days 30` (snapshot in scratchpad; the default `radar/` snapshot crashes the tool); `tools/steam_radar.py --lists popularnew,popularcomingsoon --count 30`.

**LihFolk vault notes:** Legal Basics - IP Licenses and Assets (§5); Who Owns AI-Generated Code and Assets; Policy and Age Rules 2026 (§3); Publishing an Experience (fees/evaluation); Discovery and Monetization Changes 2025-2026; Discovery and the Algorithm; Case Study - Jailbreak; Genre Playbook - Open-World City and Crime Roleplay; Community Building; Replication and Ownership; Enemy and NPC Animation; Deterministic Simulation; Gore Policy and Kid-Friendly Hit Feedback; Thumbnails Icons and Store Page.

**Project docs:** README.md, PROJECT_STATE.md, docs/IDEA_ECHO_HEIST.md, docs/VIRAL_PLAYBOOK.md, docs/STEAM_TO_ROBLOX_SCAN.md, docs/GAME_BIBLE.md (grep: §4.1, §4.3, §3.11), src/shared/Config.luau, src/server/Echoes.luau.

**Web:**
- Causal Loop: https://store.steampowered.com/app/3374460/Causal_Loop/
- UnLoop: https://www.meta.com/blog/unloop-launch/ ; https://steamdb.info/app/2672470/ ; https://store.steampowered.com/app/2672470/UnLoop/
- Record Rewind Repeat: https://store.steampowered.com/app/3477030/Record_Rewind_Repeat/
- Clone Loop: https://birikyc.itch.io/clone-loop ; Past Loop: https://itch.io/jam/gmtk-2025/rate/3780440 ; Time Clones: https://timeclones.web.app/
- Echo Heist (itch): https://nitrous-studio.itch.io/echo-heist ; https://geronimokuwait.itch.io/echo-heist ; https://geronimokuwait.itch.io/echo-heist/devlog
- Loop Heist: https://cogconnected.com/2026/10/loop-heist-browser-demo-turns-your-recorded-moves-into-a-heist-partner/ ; https://www.gamespress.com/Loop-Heist-browser-demo-turns-your-recorded-moves-into-a-heist-partner ; https://thebeanladder.itch.io/loop-heist ; Timeloop Heist: https://gohgames.itch.io/timeloop-heist
- Repeat Offender: https://matt9440.itch.io/repeat-offender ; https://theoclarke.itch.io/repeat-offender
- Grand Theft Timeline: https://store.steampowered.com/app/4928450/ ; https://ingamenews.com/pc-gaming/co-op-steam-game-grand-theft-timeline-teases-9-11-level/
- Robbing Time: https://store.steampowered.com/app/3626560 ; https://thegg.net/press-releases/the-co-op-horror-superhero-game-robbing-time-is-out-now-via-steam-early-access/
- Quantum League: https://kotaku.com/dead-games-2023-delisted-servers-offline-1850083031/4 ; https://www.gamegrin.com/news/quantum-league-to-receive-no-more-updates
- Monaco 2: https://opencritic.com/game/18260/monaco-2 ; https://steamdata.ai/game/1063030 ; https://www.slantmagazine.com/games/monaco-2-review/
- Relooted: https://www.gematsu.com/2026/01/relooted-launches-february-10 ; https://knowledge.edge-online.com/p/making-relooted-the-game-was-always-going-to-have-a-cultural-impact-vastly-exceeding-its-financial-i ; https://www.avclub.com/relooted-game-review
- Haunted Heist: https://www.gamedeveloper.com/press-release/game-announcement-haunt-your-friends-in-viral-horror-comedy-co-op-title-haunted-heist- ; https://raijin.gg/app/4024440/Haunted_Heist
- The Last Clockwinder: https://www.meta.com/blog/designing-last-clockwinder-best-of-quest-2022/ ; https://www.gdcvault.com/play/1028958/Art-of-The-Last-Clockwinder ; https://gdcvault.com/play/1029182/Independent-Games-Summit-Fixing-Bugs
- ECHO (Ultra Ultra): https://www.pcgamer.com/echo-is-a-third-person-sci-fi-action-puzzler-with-evil-clones/ ; https://www.gamesradar.com/these-ex-hitman-devs-are-messing-with-your-assumptions-about-enemy-ai-in-echo/
- Super Time Force GDC: https://gdcvault.com/play/1020103/Super-Time-Force-Solving-the ; https://www.gamedeveloper.com/design/video-solving-the-time-travel-paradox-for-i-super-time-force-i-
- Braid GDC: https://gamedeveloper.com/design/video-jonathan-blow-explains-i-braid-s-i-rewind-mechanic-at-gdc-2010
- Stealth GDC: https://gdcvault.com/play/1021919/contactUs ; https://www.gdcvault.com/play/1023849/contactUs ; https://gdcvault.com/play/1013435/Level-Building-for-Stealth ; https://80.lv/articles/designing-highly-replayable-stealth-levels-for-payday-2/ ; https://gamedeveloper.com/business/doing-stealth-the-i-monaco-i-way ; https://www.gamedeveloper.com/design/lesson-the-problems-of-modern-stealth-design-and-how-invisible-inc-solves-them
- GMTK: https://amara.org/subtitles/3ogCRpZfAjOh/en/1/download/Clockwork%20Games%20and%20Time%20Loops.en.txt
- Notoriety/PAYDAY: https://starbreeze.com/news/notoriety-relaunches-on-roblox-as-an-official-payday-experience ; https://automaton-media.com/articles/newsjp/20241213-321591/ ; https://www.pocketgamer.biz/starbreeze-partners-with-gamefam-for-new-payday-game-on-roblox/
- ROB IT: https://rowatcher.com/games/9472441390/rob-it ; https://earnaldo.com/blog/rob-it
- Criminal Simulator: https://rowatcher.com/games/10769851460/criminal-simulator-alpha ; https://www.gamesradar.com/games/simulation/criminal-simulator-codes/
- ROB RUN: https://mein-mmo.de/rob-run-steam-early-access-start/ ; https://www.gamespark.jp/article/2026/11/09/174657.html ; https://games.gg/rob-run/
- GTA 6 date: https://gameluster.com/take-two-gta-6-november-2026-on-track/
- Roblox trends: https://www.ggrecon.com/articles/fastest-growing-new-roblox-games-november-2026/ ; https://rowatcher.com/news/roblox-week-in-numbers-2026-w44
- Roblox policy: https://ir.roblox.com/news/news-details/2026/Roblox-Requires-Users-Worldwide-to-Age-Check-to-Access-Chat/default.aspx ; https://about.roblox.com/newsroom/2026/11/david-baszucki-sits-down-with-bloxy-news ; https://walkthroughs.net/roblox-highly-engaged-player-threshold-drops-to-100-explained ; https://devforum.roblox.com/t/making-publishing-easier-our-vision-and-whats-coming/4865780
- Roblox Moments: https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery ; https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more
- Copycat lawsuits: https://www.thestar.com.my/tech/tech-news/2026/03/25/robloxs-hit-game-steal-a-brainrot-battles-its-many-imitators ; https://www.pcgamer.com/games/a-brainrot-themed-roblox-game-is-taking-a-brainrot-themed-fortnite-game-to-court-for-being-a-copy/
