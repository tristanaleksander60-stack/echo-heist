# MASTER PLAN: "Heist Yourself: Rob With Your Clones" (code name Echo Heist)

_Game director's final plan, 2026-11-12. It merges the six research reports in `docs/research/` (visuals, design, tech, growth, feel, market), the v0.1 prototype in `src/`, the LihFolk Vault V2, web and live-Roblox checks run today, and three independent critiques (player and fun, feasibility and tech, market and virality). Every blocker and major critique point is applied or explicitly rejected in **Appendix A**. Notation: a fact carries a source (URL, vault note in italics, or a research report); **Decision** marks our call; (H) marks a heuristic; [UNVERIFIED] marks a claim we could not confirm; [estimate] marks our own arithmetic. All tuning numbers go into `src/shared/Config.luau`, never inline (CLAUDE.md rule)._

---

## Executive summary (one page)

**What it is.** A Roblox heist game where your crew is you. Each heist is played in short **runs** (30-45 s). Every run is recorded, and on the next run your past selves replay it as glowing clones of your own avatar. Plates, doors, lasers and Gus the night guard react to clones exactly as to players. Solo is complete; 2-4 friends make it a 16-robber party.

**Decisions taken in this plan**
- **Prove the fun before rebuilding.** Hard fun gate on the v0.1 prototype by **Mon Nov 16** (owner + 2-3 people, 30 min). Only the pure recording codec may start before it. Six tech spikes (phone clone bench, mesh pipeline, video capture, audio stems, Open Cloud smoke, lighting-in-project-file) decide architecture by **Wed Nov 18**.
- **Smaller launch, Christmas from day one.** Public launch **Thu Dec 3** (go/no-go Mon Nov 30, fallback **Thu Dec 10**) as the "Steal Back Christmas" edition on **one kit** with a removable Christmas dressing layer: **6 levels** (4 Corner Shop teaching levels, the **Clone Party** swarm level, **The Big Score: Bank**), a daily vault that doubles as the advent calendar, medals, Cash, a small store. Everything else is on a written cut list (§10.4).
- **"8 OF ME" in session 1.** Level 5, **Clone Party** (about minute 8), grants 8 clone slots, has unlimited loot and an Alarm Run. Every heist ends with a scripted **Crew Line-up** so the "synchronized copies" shot always exists.
- **Tension, not puzzles.** Big Scores and Clone Party have an **Alarm Run** (chase music, Gus sprints, van countdown, clones act as decoys). Story heists from L4 have a soft **Dawn** deadline. Guard detection is a forgiving 3-stage cone with hiding spots.
- **Kid-proof FTUE and phone controls.** Level 1's first run auto-ends on the plate, so the first clone always holds the door. One button, one meaning (END RUN); "Undo last run" lives in the between-runs Clone Deck; only REWIND and Interact are visible during a run.
- **No stranger chaos.** A public server is a shared garage lobby; each solo player or friend party runs its **own heist instance** in that server. Strangers team up only through opt-in **Quick Crew**. Clone caps lock at heist start; leavers' clones become grey "orphan tapes" the leader can eject.
- **Collection and show-off at launch.** Each heist and each daily vault drops a named trophy for your van (the advent ornament tree in December); Clone Party has a personal-best haul and a growing bag upgrade.
- **The under-16 gate.** Primary path is Roblox's **expedited Kids & Select review** (refundable 50,000-100,000 R$ deposit, about 48 h), submitted the day we go public. Engagement ads are the backup. Creator embargo and every "join now" call to action wait for the Audience Reach dashboard to show all ages. Kid playtests run **before** launch through **early-tester invites** on a private test place.
- **Tech.** Server-side 20 Hz sim with clones as data; clients draw clone rigs. Levels are data built from a Studio-imported kit file; the live place is only ever `rojo build` output, Lighting included. Lag-fairness rules and latency injection in headless tests. Lighting style is chosen once (it cannot be switched by script).
- **Look.** "Neon-Noir Diorama": chunky model-kit sets at night, warm pools of light, clones as the only glowing colour family. Launch kit cut to ~12 modules + 3 hero props; $300-600 freelance artist for the 5 golden reference assets.
- **Marketing.** Lead with what competitors can't do: **your own avatar** as the clone, **16 robbers with friends**, Gus as a character. Drop the claim that the tape motif is original (Rewind Robbers uses it). 1-2 clips a day from Nov 19 with a part-time editor.
- **Calendar.** Dec 3 launch → Fri Dec 11 drop 1 (Wrapping Room) → **Fri Dec 18 finale** (Snow Globe Vault, school break starts) → Dec 24-27 freeze with a Dec 25-26 gift beat → Jan 8 New Year patch → **Jan 22 Museum** → **Feb 12 co-op update** (Hub, crew servers, Season 1).

**Owner decisions needed** (full list with defaults in §11.2): name; fund expedited review; launch scope and date; weekly time commitment; Open Cloud test key (Nov 13); ad budget; freelance artist; clip editor; kid playtest recruitment; music.

---

## 0. The calls that resolve the reports' and critiques' conflicts

| # | Conflict | Options | **Decision** | Why |
|---|---|---|---|---|
| C1 | Store title | "Rob With Your Clones" (growth), "Repeat Offenders" (market), "Heist Yourself: Rob With Your Clones" (market critique) | **"Heist Yourself: Rob With Your Clones"**; short brand "Heist Yourself", #heistyourself | Brand + one accurate descriptor (vault *Experience Description and Search Keywords*); "clone + steal" alone sits among brainrot cash-ins (§2) |
| C2 | Player-facing nouns | echo vs clone; take vs run | **"clone"** and **"run"** in all UI and marketing ("RUN 3", "END RUN"); code and docs keep `Echo` and "take". "Run" vs "Try" is checked in kid wave 1 | Kid vocabulary; "take" is film jargon and is Rewind Robbers' word |
| C3 | Clone caps | 12/server (design) vs 16 (tech) | **12 clones per heist instance** (+ up to 4 players = 16 robbers). Per-player cap `min(level.cap, floor(12 / crewSize))` = 8/6/4/3, **locked at heist start**. 16 only if the W1 bench passes on a low Android | Quantum League found 12 the readable ceiling ([MP1st](https://mp1st.com/news/nimble-giant-entertainment-talks-about-their-latest-time-bending-shooter-quantum-league)); avatars are the biggest phone cost |
| C4 | Rewind length | 2.5 s vs 1.8 / 1.0 / 0.8 s | **1.8 s standard, 1.0 s quick (automatic from the 4th rewind and always in L1), 0.8 s reduced motion** | 2.5 s every 30 s eats 8% of playtime (feel D1) |
| C5 | Clone palette | visuals vs feel | **Feel's set + mandatory glyph and number** (●1 ■2 ▲3 ◆4) | Visuals' set fails the colour-blind audit (0.051-0.056) |
| C6 | Rewind control | all-player vote vs per-player End; tap/hold on one button | **Per-player END RUN, one meaning per button.** Disabled for the first 1.5 s of a run. No hold-to-scrap; **"Undo last run"** is a card in the between-runs Clone Deck | No player can force another to rewind; a 10-year-old's mis-tap is undoable |
| C7 | Getting caught | sent home vs run ends | **Your run ends** after a 3-stage detection (amber → "?" 0.6 s → "!" 1.2 s), a 1.2 s BUSTED beat and a 2 s busted-cam; your clone of that run repeats the mistake next run | The "my clone repeats my mistakes" clip, made fair for phone players |
| C8 | Stakes | no fail state vs a deadline | **Alarm Run** in Clone Party, every Big Score and the finale; a soft **Dawn** in story heists from L4 (`par + 4` runs) and daily vaults; L1-L3 have no deadline | Kid hits on this theme sell a threat, chase music and a deadline (critique 1, Criminal Simulator, Dig to Escape) |
| C9 | Launch date and scope | Dec 3 full scope vs Dec 8-12 | **Thu Dec 3 with a 6-level scope, go/no-go Mon Nov 30, fallback Thu Dec 10**; Christmas dressing from day one | 21 days remain; the prototype has never run in Studio |
| C10 | Location ladder | bank/museum/casino | **Corner Shop → Bank → Museum → Sky Lounge → Moon Base** (Moon Base cuttable) | Breaks Rewind Robbers' identical ladder ([Playgama](https://playgama.com/game/rewind-robbers)); no gambling risk |
| C11 | Co-op topology | public 4-player join-in-progress (draft) vs reserved crew servers (design) | **Public 8-player garage lobby; each party (solo or friends) gets its own heist instance in that server.** Strangers only via opt-in Quick Crew; joiners seat at the next heist | Ends stranger griefing without teleport loading in the FTUE (§3.3) |
| C12 | Swarm promise | 8 clones gated behind 35 Stars | **Clone Party (L5) grants 8 slots**; Big Scores and the finale grant 8; owned-slot progression removed | "8 OF ME" must be true in session 1 (critiques 1 and 3) |
| C13 | Under-16 gate | organic threshold + "RFY off/on" switch | **Expedited review first, Engagement ads as backup; no RFY switch exists** | Market critique; [Kids & Select docs](https://create.roblox.com/docs/production/publishing/kids-and-select) |
| C14 | Lighting fallback | runtime Soft kill switch | **Choose the LightingStyle once from W1 phone screenshots**; the runtime tier uses only scriptable controls | `LightingStyle` and `PrioritizeLightingQuality` are not scriptable ([Lighting reference](https://create.roblox.com/docs/reference/engine/classes/Lighting), [DevForum](https://devforum.roblox.com/t/prioritizelightingquality-not-accessible-in-scripts/3826475)) |

Smaller calls: record at **20 Hz**; **≤ 2** clone accessories; Highlight limit **255** (docs, Nov 2025); draw calls **350 target / 600 ceiling**; **6k** level-art instances and **25k** live client instances; guard "huh?" freeze **2.0 s**; no 3-2-1 countdown (the "RUN n" stamp on the downbeat is the GO); Kids & Select threshold **250 official, 100 reported for November [UNVERIFIED]; the Audience Reach dashboard is the truth**.

---

## 1. Vision and pillars

### 1.1 One-sentence pitch

**"Your past self is your crew: every run is recorded, and on the next one your clones replay it, until eight of you rob the vault together, or sixteen of you with friends."**

Store description, line one: *"Your past self is your crew. Rob it solo with 8 of you, or with friends: 16 robbers, 1 vault."* Line two: *"Every run is recorded. Rewind, and your clones replay your heist while you pull the next job. Outrun Gus the night guard and steal back Christmas!"* (contains: heist, rob, clone, christmas heist, past self, §9.1).

### 1.2 Pillars (every feature must serve at least one)

1. **Your crew is you.** The clone is your own avatar, readable in under half a second at 64 px with the sound off; nothing else glows in clone colours.
2. **Mistakes are content.** Clones repeat your errors exactly and fail out loud, comically. A failure is a clip and a clue, never a punishment.
3. **Heist, not puzzle.** A visible threat, chase music when it goes loud, loot from run 1, a soft deadline. Planning is optional; escaping is fun.
4. **Fast runs, no redo-everything.** 30-45 s runs; redo one clone (or "from #N") without replaying the chain; a heist takes minutes.
5. **Solo complete, friends multiply.** Every level is solvable alone; 2-4 friends make a 16-robber party; strangers never break your plan.
6. **Premium diorama craft.** Neon-Noir model-kit look, caper music, a satisfying rewind: "Steam indie" through coherence, not photorealism.

### 1.3 What we will NOT do

- No guns, blood, gore, jump scares or playable gambling: target the **Mild** label.
- No paid randomness, Robux-to-Cash, pay-to-skip, paid hints, or prompts during a heist.
- No "puzzle game" positioning: *ECHOES: Clone Puzzles*, the same mechanic, sits at **0 playing** (rbx_search, today).
- No borrowed IP (PAYDAY, Monaco, Jailbreak, Notoriety, Entry Point, Hitman, Ocean's, Ultra Ultra's ECHO), no heist masks, no green furry Christmas villain.
- No Toolbox assets, shipped AI meshes or AI textures. Freelance art is original, commissioned, with a written rights assignment.
- No gameplay that needs chat or voice; no rewards for likes, shares or watching media.
- No physics-driven gameplay objects, and no separate stealth/loud modes (the Alarm Run is a phase of the same heist, not a mode).
- No procedurally generated puzzles until a constraint checker exists (not before February).

---

## 2. Name and brand

### 2.1 Top 3, with conflict-check status (checked 2026-11-12)

| Rank | Name | Roblox search (`tools/rbx_search.py`) | Web search | Trademark (EUIPO/USPTO cl. 9/41) | Status |
|---|---|---|---|---|---|
| **1** | **Heist Yourself: Rob With Your Clones** | "heist yourself": clean (neighbours Egg Heist Roleplay, Heist Evolution, "Knock Yourself Out!"). "rob with your clones": clean (Build Anything With Clones!, Clone Engine) | No game with either title; *Heist Simulator* (No More Robots) is nearby but different | Not checked [UNVERIFIED]; knock-out search before buying anything branded | **Recommended** (36 characters; "[🎄] " seasonal tag fits) |
| 2 | **Rob With Your Clones** | Clean, but sits next to brainrot results: Clone to Steal Eggs (17.9M visits), Steal An Egg (472,473 playing today), "Clone Yourself" tycoons | — | Not checked | Fallback if the owner wants pure descriptor |
| 3 | **Repeat Offenders** | Clean, no search lift | Singular "Repeat Offender": a 2021 Trijam game ([itch](https://theoclarke.itch.io/repeat-offender)) and an s&box jam game ([itch](https://matt9440.itch.io/repeat-offender)) | Not checked | Brand fallback only |

Rejected: **Echo Heist** (two itch.io games, one with the same concept: [nitrous-studio](https://nitrous-studio.itch.io/echo-heist), [Geronimokuwait](https://geronimokuwait.itch.io/echo-heist); Roblox "ECHOES" titles; Ultra Ultra's ECHO). **Rewind Robbers** (Playgama, same concept). **Loop Heist** ([COGconnected](https://cogconnected.com/2026/10/loop-heist-browser-demo-turns-your-recorded-moves-into-a-heist-partner/)). **Rob It Again** (confusable with ROB IT). **Crew of Me** (unsearchable).

**Decision:** launch as **"Heist Yourself: Rob With Your Clones"**, confirmed by the owner by **Mon Nov 16**, before any icon, thumbnail or devlog shows a name; handles (@heistyourself on TikTok, YouTube, Instagram) reserved the same day; trademark knock-out search the same week (not legal advice). `docs/IDEA_ECHO_HEIST.md`'s line "no game uses recordings of your past runs" is false and gets corrected in W1: the mechanic exists (Rewind Robbers, ECHOES, Loop Heist, jams). What is ours is **your own Roblox avatar as the clone, 16 robbers live with friends, Gus, and a daily shared vault**.

### 2.2 Brand system

- **Motif: the tape, as dressing only.** The rewind looks like a VHS rewind, the timer is a tape counter, level select is a shelf of tapes. We **do not** claim it as original or lead with it: Rewind Robbers (Kai Chen, Playgama, Oct 2026) already describes "takes", "the tape rewinds so every earlier take replays", up to three stars for fewer takes, a getaway van, a bank and an art museum ([Playgama](https://playgama.com/game/rewind-robbers)). Marketing leads with the avatar clone, the 16-robber party and Gus.
- **Mascot:** "the Rookie", an original unmasked robber with a flat cap, long scarf and smug side-eye; human-finished, with an AI provenance log for any moodboard use.
- **Antagonist:** **Gus, the night guard** (huge flashlight, donut box, readable double-take, a sprint that is funny rather than scary): the threat with a face (market F2).
- **Event villain:** **Sir Hoardsworth**, a tall, thin toy tycoon in burgundy-and-gold velvet with a monocle; never green or furry.
- **Wordmark:** chunky rounded capitals "HEIST YOURSELF" with a cyan "double-exposure" offset copy behind; "Rob With Your Clones" in a small strap under it.
- **Collectables voice:** every trophy is a named, original object with a one-line joke (Golden Gum, Gus's Donut, the Bank Duck, Hoardsworth's Monocle).

---
## 3. Core game

### 3.1 The loop (run) rules

| Rule | Value / behaviour | Config key |
|---|---|---|
| Run length by location | Corner Shop **30 s**, Bank **45 s**, Christmas levels **45 s**, daily vaults **30 s**, Museum **60 s**, Sky Lounge **60 s**, Moon Base **75 s**. Hard ceiling 90 s. Before the sim refactor, the 30/45 s change is tested on v0.1 by editing one Config value | per level in `LevelData`, `LOOP_MAX_SECONDS = 90` |
| Start | The rewind ends with the "RUN n" stamp on the music downbeat; control returns at the end of the transition; the clock starts at that instant | `REWIND_TRANSITION = {1.8, 1.0, 0.8}` |
| END RUN | Tap the END RUN button / **R** / gamepad Y. **Disabled for the first 1.5 s** of a run (greyed ring fills). Your recording stops; **the clone holds its last pose in later runs**; you become a spectator (see "Waiting") | `END_RUN_LOCK_SECONDS = 1.5` |
| Undo last run | Between runs only, a card in the Clone Deck: removes the newest clone (yours) and replays the loop without it. Replaces the draft's hold-to-scrap | — |
| Loop end | All live runs ended, or the timer hits 0 (counts as END RUN, with a "tape runs out" flap) | — |
| **Waiting squeeze** (co-op) | When at least half the crew has ended, the others' timers jump to `min(remaining, 10 s)` with a visible "Crew is waiting" bar | `WAIT_SQUEEZE_SECONDS = 10` |
| **Fast-forward** | Solo, or co-op when **every** live player is standing still and at least one clone still has events left: a contextual "⏩" pill appears; holding it runs the loop at 3x (recorded as standing). Moving cancels it | `SKIP_SPEED = 3` |
| Caught (live player) | 3-stage cone: in the cone the meter goes amber; at **0.6 s** "?" and Gus turns toward you (you can still break line of sight or hide); at **1.2 s** "!" and your run ends with a 1.2 s BUSTED beat + 2 s busted-cam (the last 3 s from your own run buffer). First heist of a new account: all stage times x2. After 3 busts in one heist, "Relaxed" is offered | `GUARD_ALERT_SECONDS = 0.6`, `GUARD_CATCH_SECONDS = 1.2`, `FIRST_HEIST_GRACE_MULT = 2` |
| Hiding spots | Crates, plants, coat racks (`EH_Hide` boxes): an actor inside one is invisible to Gus unless he is within 3 studs. Clones hide too if their recording hid | `HIDE_REVEAL_RADIUS = 3` |
| **Alarm Run** | In Clone Party, every Big Score and the finale: grabbing the top loot trips the alarm (§3.6) | `ALARM_*` |
| Dawn | Story heists from L4: the heist ends after `par + 4` runs (minimum 6), keeping banked Cash and any medals met. Daily vaults: Dawn at run 6. Clone Party: Dawn at run 8. L1-L3: none | `DAWN_RUNS_OVER_PAR = 4` |
| Relaxed | Runs +50% and detection times x2; earns medals and trophies, flagged and excluded from boards. It changes loop **length**, never the clock rate | `RELAXED_*` |
| Persists inside a heist | Banked loot, "Prep" shortcuts (unscrewed vent, cut window), ghost trails of your last 3 runs, timed floor markers | — |
| Resets every loop | Guards, cameras, lasers, doors, carried (unbanked) loot, alarm state | — |
| Across heists | Cash, Stars, trophies, cosmetics, medals, bag level. Clones never carry between heists | — |
| Plate grace | 0.4 s after release, shown as a draining cable | `PLATE_GRACE = 0.4` |
| "Simultaneous" | Two actions within 1.0 s count as together; no window under 1.5 s anywhere | `SIMUL_WINDOW = 1.0` |

### 3.2 Clone rules

1. **A clone is a ghost on rails.** It replays recorded position, yaw and pose flags at 20 Hz plus timestamped intent events (grab, release, press, hold start/end, hide, emote). It never collides with players.
2. **Its actions are re-validated.** Every intent goes through the same `Interact.request` path a player uses. If the world differs, the clone fails **visibly, with a cause**:

| State | Trigger | What you see (Mild, mostly procedural animation, §6.7) | Run-bar marker |
|---|---|---|---|
| **Bonk** | Its path crosses a closed door's box | Flattens (scale tween), stars, shrugs, holds position | red ✕ at t |
| **Zap** | Walks into an active laser | Soot puff, hair-up, client-side cosmetic flop | ⚡ |
| **Busted** | Caught by Gus | Gus freezes 2.0 s with "?" (the "WRONG ONE" clip), the clone glitches into tape ribbons | 👮 |
| **Shrug** | Grabs loot that is gone, presses out of range | Shrug clip, "?" bubble | ? |
| **Stuck** | Path blocked by another dynamic blocker | Holds pose with a "..." bubble | ... |

3. **Determinism contract:** the world at loop time t is a pure function of (level, loop seed, actor positions and events up to t): time-parameterised guard patrols, deterministic chase steering (§3.6), A* on authored waypoints, `Random.new(levelSeed + loopIndex)`, stable actor order. Two loops with no live player moving give identical event logs; CI proves it.
4. **Physical items are single.** A carried keycard or present follows the carrier's recorded path; a live player can take it only where a clone drops it ("hand-off"), preventing Talos-style softlocks ([Thinky Games](https://thinkygames.com/features/the-talos-principle-reawakened-isnt-just-a-graphical-revamp-its-the-perfected-edition-of-a-modern-classic)).
5. **Cameras ignore clones** (from the Museum; "cameras see heat; clones have none"). Gus sees them.
6. **The Clone Deck** (between runs only): your clones as cards with glyph, number and a status dot. One-tap actions: **Redo #N** (the next run replays the others while you re-record that slot), **Redo from #N** (re-records #N and deletes everything after it), **Delete**, **Delete busted** (all your red-flagged clones), **Undo last run**. Only your own clones. While you redo slot N, the old path shows as a faint "ghost of the ghost" with timestamped footprints, and the run bar shows an "on time / late 2 s" strip against the old recording's key events. Dependency icons ("#3 relies on #2's plate", derived by the sim from the event log) follow on **Jan 8**.
7. **Caps are granted by the level, not bought.** Each level defines `level.cap` (teaching levels par + 2, Clone Party, Big Scores and finale **8**). Per-player cap in co-op: `min(level.cap, floor(12 / crewSize))`, **locked when the heist starts**. The draft's owned-slot progression (slots 5-8 for Cash and Stars) is removed: it hid the core promise behind 35 Stars.
8. **Crew Line-up (scripted, not recorded):** at heist end every clone of every crew member plus the players walk to the van and do one synchronized victory pose (stagger 60 ms per clone in record order). It does not touch the sim, so it never desyncs, and it guarantees the "8 synchronized copies" shot in every heist.

### 3.3 Solo vs co-op

- **Solo** is the default and complete: every level is CI-tested against a human-recorded solo solution (§8.9).
- **Launch topology (Decision C11):** a public server holds **8 players** in a shared **garage lobby** (vans parked side by side, trophies visible). Each **party** (a solo player, or friends who joined each other) runs its **own heist instance**: a copy of the level built at its own offset (3,000 studs apart; recordings are already stored relative to the level origin). StreamingEnabled keeps each client loading only its instance. Up to 4 instances per server. No teleports, so a new player reaches the first clone without a loading screen.
  - **Friends:** join-friend lands you in the same server; the host gets a "Join my crew" card. **Private servers are free** and count as intentional co-play ([Discovery docs](https://create.roblox.com/docs/discovery)); join/invite/private server count, matchmaking does not (growth.md, RFY signals).
  - **Strangers:** only through opt-in **Quick Crew** (a lobby board: "Looking for crew · Clone Party"). Quick Crew has a **Crew Vote: wipe this player's clones** (majority, one per heist per target).
  - **Late joiners** seat at the next heist; meanwhile they watch the crew's run from a spectator cam and see the last Heist Reel.
  - **Leavers:** their clones stay as grey **orphan tapes** (still replaying, still useful) until the heist ends; the crew leader can **Eject tape** on them between runs. Caps never re-split mid-heist.
- **Jan/Feb co-op update (Feb 12):** public **Hub** with hideouts, **reserved crew servers**, Crew Vaults that need 2+ live players, crew board.
- **Chaos control:** colour + glyph per player and one run-bar row each; levels scale by actors (a scale vault needs `max(4, crewSize + 2)`); Gus gets +10% vision range per extra player.
- **Talking without chat** (ping wheel only appears in co-op): 6 options ("Here", "Wait", "Go", "Guard!", "Plate", "Need 2") and **timed floor markers** ("be here at 0:24") that persist across runs. Chat needs an age check worldwide ([Roblox IR](https://ir.roblox.com/news/news-details/2026/Roblox-Requires-Users-Worldwide-to-Age-Check-to-Access-Chat/default.aspx)).
- **"Need 2" moments:** in a solo heist where a level would be faster with a friend (heavy loot from Dec 11), an **Invite a friend** button appears in the Clone Deck (`SocialService:PromptGameInvite`); never an automatic popup.
- **Spectators** (ended, caught or waiting) can drop timed floor markers, ping, and fly a top-down **planning camera** with the crew's current routes drawn; nothing they do is recorded.
- **Fairness:** no player collision; nobody touches another player's clones (except Eject on orphans and the Quick Crew vote); loot splits equally; +10% Cash per friend, capped at +30%. **Helper mode** (any crew member can toggle it, used for cousins on Dec 24): that player's clones don't count against the crew's Crew-medal clone total.

### 3.4 Controls (one verb per button, unlocked when taught)

| Verb | PC | Phone | Gamepad | Visible when | Unlocked |
|---|---|---|---|---|---|
| Move, jump, camera | default | default | default | always | L1 |
| Interact (grab, press, hide) | E | contextual tap prompt (≥ 64 px) | X | near a target | L1 |
| END RUN | R | 72 px button on the **right edge at ~45% height**, ≥ 140 px above the jump button, inside `CoreUISafeInsets`; locked for 1.5 s | Y | during a run | L1 |
| Clone Deck | Q | strip, top right | LB | **between runs only** | L2 |
| Ping / marker | G | long-press the ping button | RB | co-op only | first co-op heist |
| Fast-forward | hold F | hold the ⏩ pill | hold B | contextual (§3.1) | L3 |
| Planning camera | TAB | map button | View | in the van and while spectating | L5 |

All through the Input Action System; every input gets a pop and a sound within 100 ms (vault *Game Feel and Juice*). During a run a phone shows only the stick, jump, END RUN and the contextual prompt (vault *First-Time User Experience and Onboarding*: teach the rest just in time).

### 3.5 Camera

- Roblox third-person: zoom 16 studs (min 8, max 28), FOV 70, slight downward bias in diorama rooms. Walls between camera and player fade to 0.7 transparency (client raycast at 10 Hz).
- **Planning camera:** top-down, FOV 30 at about 120 studs, deep-blue grade, grid floor, clone routes drawn as Beams sampled every 0.5 s, plates with cables, Gus's route and cone, loot values. Ships as a simple version at launch (routes + Gus); the full Blueprint with editing tools is cut to January.
- **Heist Reel** and the rewind camera: §6.6 and §7.1.
- Comfort: never roll the camera; FOV kicks off under reduced motion.

### 3.6 The Alarm Run (the chase beat)

1. **Trigger:** grabbing the level's top loot (the diamond, the vault stack, the Giant Present), or Gus reaching "!" on a live player in a Big Score.
2. **What changes, all on the server sim from actor positions:** red rotating lights and the chase stem (S5) start; the **van countdown** appears ("VAN LEAVES 0:20"); Gus switches from patrol to **chase**: each sim tick he targets the nearest actor he can see (players and clones, ties broken by actor id), else walks to the last-seen point, at `GUARD_CHASE_SPEED = 0.9 × player WalkSpeed` so a kid can outrun him but not in a straight line forever. Doors marked `alarmLock` close 10 s after the alarm.
3. **Clones matter:** Gus chases whichever actor is nearest, so an earlier clone running a different route is a **decoy**, and a clone on a plate holds the escape door. Marketing line: "outrun the guard with your clones".
4. **Stakes:** caught during the alarm, your run ends and the loot you carry drops (it resets next loop anyway); **banked loot stays**. Van countdown at 0 ends every live run.
5. **Determinism:** chase steering is a pure function of actor positions; with no live player moving, two loops give the same log (CI).

---

## 4. Content plan

### 4.1 Mechanic introduction curve

Every verb is taught **Show → Try → Test → Combine**; a new verb combines only with known ones; a breather follows every hard combination (vault *Teaching Through Level Design*). "Show" is often a **Mentor tape**: a gold, pre-recorded developer clone performing the step once (recorded by the owner in Studio, §8.9). Par solutions must take at most `par runs × run length × 1.5` to execute. Every level also has a **"naive kid" check** (§8.9): a wandering, non-planning first run must still lead to a clone, a bank and a laugh within 2 runs.

### 4.2 Launch levels (Thu Dec 3: 6 levels, Christmas-dressed)

| # | Location (run) | Level | Teaches | Par clones | Cap | Big moment |
|---|---|---|---|---|---|---|
| 1 | Corner Shop / Toy Shop (30 s) | **Back Room** (FTUE) | Plate holds a door; rewind; **"your clone stops where you stop"** | 1 | 3 | "◀ YOU, 10 SEC AGO" |
| 2 | Corner Shop | **Two Doors** | Two plates; Clone Deck; Undo last run | 2 | 4 | First 3-of-you shot |
| 3 | Corner Shop | **Lights Out** | Laser grid switched by a plate; Zap; fast-forward | 2 | 4 | Your clone zaps itself on cue |
| 4 | Corner Shop | **Night Clerk** | Gus (3-stage cone), hiding spots, busted clones, **Redo #N**; first Dawn | 2 | 4 | First "WRONG ONE" |
| 5 | Corner Shop after hours (30 s) | **Clone Party** | 8 slots; unlimited loot respawning on shelves; Alarm Run on the cash register; bag upgrades; Dawn at run 8 | — (Haul tiers) | **8** | **"8 OF ME"**, about minute 8 |
| 6 | Hoardsworth Bank (45 s) | **The Big Score: Bank** | Scale vault needs 4 actors on 4 plates; Gus patrol; Alarm Run escape with decoys | 4 | **8** | First Heist Reel worth posting |

- **Session length** [estimate]: L1-L4 ≈ 12-18 min, Clone Party 5-8 min, Big Score 8-12 min: **≈ 30-40 min** of first-clear content. Sessions 2-5 (Dec 3-10) come from: the daily vault + advent ornament, Clone Party personal-best haul and bag level, missing medals (Haul/Crew/Clean), Diamond medals on L4 and L6, and co-op with friends.
- **Clone Party is the repeatable loop** (replaces Free Roam): "how much can 8 of you steal before Dawn?" Personal best and a server board in the garage (biggest haul today). Each bag level (Cash) lets an actor carry one more small item; bag runs are excluded from Diamond.
- **Gates:** L6 needs 6 Stars (of 12 from L1-L4 + 3 Haul tiers in Clone Party).

### 4.3 "Steal Back Christmas" (Dec 3 - Jan 4, one kit + a dressing layer)

- **Story:** Sir Hoardsworth has vacuumed every present in town into his Snow Globe Vault; your crew steals Christmas back before morning.
- **Day one (Dec 3):** the launch levels wear the **Christmas dressing layer** (fairy lights through emissive masks, snow decals, wreaths, candy-cane laser emitters, Gus in a Santa hat). The layer is data, switched on by server date and off on **Tue Jan 5** without a republish.
- **Daily vault = advent calendar (Dec 3-24):** one 30 s hand-authored mini-vault per day (§5.3); each first clear hangs a named **ornament** on your van's tree. Missed days can be caught up until Dec 31.
- **Drop 1, Fri Dec 11: "Wrapping Room"** (Toy Shop, same kit + conveyor module): 2 levels. **Gift Tag** teaches single-item hand-off (the key tag); **Wrapping Room** teaches **heavy loot** (a present needing 2 grips: you + your clone) on conveyors. Also: 2 more daily vaults, global daily board, blooper stitching.
- **Finale, Fri Dec 18 (school break starts): "The Snow Globe Vault"** (Hoardsworth's penthouse vault, same kit): **8 slots granted, par 4-5**, an Alarm Run, and the **Giant Present** that moves with 2 grips and moves faster with 3-4. Extra clones are a fun excess, never a requirement. Published Thu Dec 17, unlocked by server time.
- **Dec 25-26 gift beat** (pre-published Dec 23, server-time unlocked): a free fixed cosmetic (Gift-Wrap clone style), Stars doubled on the daily vault, the Christmas bundle featured **on the van screen only** (never during a heist).
- **Candy Canes** (earned only, from daily vaults and chapters) buy the event track: Santa clone hat, sleigh van paint, snow-globe trophy. Event ends **Mon Jan 4**; cosmetics stay owned.
- **Cut:** separate "12 Vaults of Christmas", the server-wide MessagingService presents meter (replaced by a per-server "presents recovered today" counter in the garage), the Christmas pass (replaced by one bundle), Midnight Vault.

### 4.4 Post-launch

| Date (Fri, 17:00 CET) | Drop | New verbs / systems |
|---|---|---|
| **Jan 8** | **New Year patch:** Contracts (weekly modifier: "Lights Out", "Faster Guards", "Mirror Map"), Diamond medals everywhere, clone dependency icons, catalog-emote support, Danish translation table, Museum teaser | — |
| **Jan 22** | **Museum** (60 s): Gallery, Dinosaur Hall (breather), Night Watch, The Big Score: Crown; first gadget (Noisemaker); full Blueprint | Cameras (clones invisible), vents (one actor at a time), noise distraction, alarm levels |
| **Feb 12** | **Co-op update + Season 1** (5 weeks): Hub and hideouts, reserved crew servers, Crew Vaults (2+ live players), crew board, free cosmetic ladder | Two-player-only mechanisms |
| ~Mar 5 | **Sky Lounge** (60 s): Lobby Floor, Count Room, Elevator Bank, The Big Score: Jewel Suite | Twin switches within 1.0 s, safe cracking under patrol, elevators |
| later | **Moon Base** (75 s), only if the Museum's D7 justifies it | Long jumps, airlock timers |
| Daily / weekly | 14+ daily vaults in rotation with date-seeded modifiers; a Contract weekly; module-generated vaults only after a constraint checker exists | — |

---
