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

**Owner decisions needed** (full list with defaults in §11.2): name; fund expedited review; launch scope and date; weekly time commitment; extra scopes on the Open Cloud test key (Nov 13); ad budget; freelance artist; clip editor; kid playtest recruitment; music.

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
6. **The Clone Deck** (between runs only): your clones as cards with glyph, number and a status dot. One-tap actions: **Redo #N** (the next run replays the others while you re-record that slot), **Redo from #N** (re-records #N and deletes everything after it), **Delete**, **Delete busted** (all your red-flagged clones), **Undo last run**. Only your own clones. **Read-only on L1 and on party levels** (2026-11-12): on the Clone Party every clone stays in the party, because any Delete or Redo silently turns "8 OF ME" into "7 OF ME" at Dawn; party runs auto-start after 10 s (`PARTY_BETWEEN_SECONDS`) with a visible countdown. While you redo slot N, the old path shows as a faint "ghost of the ghost" with timestamped footprints, and the run bar shows an "on time / late 2 s" strip against the old recording's key events. Dependency icons ("#3 relies on #2's plate", derived by the sim from the event log) follow on **Jan 8**.
7. **Caps are granted by the level, not bought.** Each level defines `level.cap` (teaching levels par + 2, Clone Party, Big Scores and finale **8**). Per-player cap in co-op: `min(level.cap, floor(12 / crewSize))`, **locked when the heist starts**. The draft's owned-slot progression (slots 5-8 for Cash and Stars) is removed: it hid the core promise behind 35 Stars.
8. **Crew Line-up (scripted, not recorded):** at heist end every clone of every crew member plus the players walk to the van and do one synchronized victory pose (stagger 60 ms per clone in record order). It does not touch the sim, so it never desyncs, and it guarantees the "8 synchronized copies" shot in every heist.

### 3.3 Solo vs co-op

- **Solo** is the default and complete: every level is CI-tested against a human-recorded solo solution (§8.9).
- **Launch topology (Decision C11):** a public server holds **8 players** in a shared **garage lobby** (vans parked side by side, trophies visible). Each **party** (a solo player, or friends who joined each other) runs its **own heist instance**: a copy of the level built at its own offset (3,000 studs apart; recordings are already stored relative to the level origin). StreamingEnabled keeps each client loading only its instance. Up to **8** instances per server (owner decision 2026-11-12: 8 solo crews always fit), on a grid around the lobby (`Config.Heist.INSTANCE_SLOTS`: the four axis cells, then the diagonals, at most ~4,300 studs out, so float precision stays fine). **Streaming status (2026-11-12):** the code is ready (each instance's `Level` model is `PersistentPerPlayer` and its crew is added with `AddPersistentPlayer`; WorldView also binds parts that arrive later), but the place still has StreamingEnabled **off**: v0.1 (the Nov 16 fun gate build) was never checked under streaming. Flip it right after the fun gate by adding a `Workspace` node to `default.project.json` (`StreamingEnabled` true, `StreamingMinRadius` 128, `StreamingTargetRadius` 512, `StreamOutBehavior` Opportunistic, `ModelStreamingBehavior` Improved) and the matching asserts in `tests/place_check.luau`. Until then every client receives every crew's level (~300-400 parts per L6 build) and every instance folder's state attributes. A bigger later win: build the kit layer on the client from the pure KitPlan so the server replicates only the greybox colliders. **Required place setting:** Max Players = 8 (Creator Hub; not in the project file): more players than instance slots would leave a new player's FTUE start retrying. No teleports, so a new player reaches the first clone without a loading screen.
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
2. **What changes, all on the server sim from actor positions:** red rotating lights and the chase stem (stem S5) start; the **van countdown** appears ("VAN LEAVES 0:20"); Gus switches from patrol to **chase**: each sim tick he targets the nearest actor he can see (players and clones, ties broken by actor id), else walks to the last-seen point, at `GUARD_CHASE_SPEED = 0.9 × player WalkSpeed` so a kid can outrun him but not in a straight line forever. Doors marked `alarmLock` close 10 s after the alarm.
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

- **Play order ("party break", owner decision 2026-11-12):** L1 → L2 → **L5 Clone Party** → L3 → L4 → L6 (`Levels/Catalog` = `Config.Data.LEVEL_ORDER`; the `#` column above stays the design number). Clearing L2 opens both Clone Party and L3; "NEXT" leads to the party first, so "8 OF ME" lands around minute 8-10 of a first session (`tests/sim/Pacing.spec.luau`: SwarmSeen at minute 7.6 / 9.4 / 11.2; docs/ANALYTICS.md KPI notes; DATA.md "Play order").
- **Session length** [estimate]: L1-L4 ≈ 12-18 min, Clone Party 5-6.5 min (10 s auto-start between party runs; 5-8 min with the old 25 s pause), Big Score 8-12 min: **≈ 30-38 min** of first-clear content. Sessions 2-5 (Dec 3-10) come from: the daily vault + advent ornament, Clone Party personal-best haul and bag level, missing medals (Haul/Crew/Clean), Diamond medals on L4 and L6, and co-op with friends.
- **Clone Party is the repeatable loop** (replaces Free Roam): "how much can 8 of you steal before Dawn?" Personal best and a server board in the garage (biggest haul today). Each bag level (Cash) lets an actor carry one more small item; bag runs are excluded from Diamond.
- **Gates:** L6 needs 6 Stars (of 15: 3 per teaching level L1-L4, plus 3 Haul tiers in Clone Party).

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
## 5. Progression, retention and monetization

### 5.1 Economy (one job per currency)

- **Cash:** soft currency from banked loot. Spent on **bag levels** (Clone Party carry capacity, 3 levels), van paints, clone trail colours, trophy stands for the van. A big, growing number on the van screen.
- **Stars:** from medals, never sold. Gate the Big Score and later locations.
- **Trophies:** one named collectable per level (first clear) and one ornament per daily vault, shown in your van and visible to everyone in the garage lobby. This is the launch collection and show-off layer; the hideout (Feb 12) inherits it.
- **Candy Canes:** event-only, earned only.
- No Robux-to-Cash, ever. That keeps every reward outside the paid-random-items rules (docs updated 2026-10-15, [Roblox Docs](https://create.roblox.com/docs/production/monetization/paid-random-items)).

### 5.2 Medals and gates

- Per story level, 3 Stars: **Haul** (bank the target value before Dawn), **Crew** (finish with at most par clones), **Clean** (no catches and no busted clones in the final run; "Delete busted" makes this a one-tap clean-up).
- Clone Party: 3 **Haul tiers** ($ thresholds).
- A shown-but-optional **Diamond** medal from Jan 8 (L4 and L6 at launch): beat the developer's clone count ("DEV: 4 CLONES. ME: 3"). This is where the optimisers live; kids never need it.
- **Gates:** Big Score: Bank 6 Stars; Museum 14; Sky Lounge 26; Moon Base 40. The next-goal card always shows the number.

### 5.3 Retention hooks

| Horizon | Hook |
|---|---|
| Session | Next-goal card on every exit ("2 more Stars opens the Bank"); Heist Reel + Crew Line-up; Clone Party personal best; the trophy shelf |
| **D1** | **Daily vault** (= advent calendar in December): one of **12 hand-authored 30 s mini-vaults** at launch (14 from Dec 11), each with a human-recorded solution in CI, chosen by UTC date, with a **date-seeded modifier from a vetted set** (guard speed ±10%, loot position A/B/C, lights on/off). Fixed 5-clone loadout, Dawn at run 6. First clear: an ornament/trophy, 1 Star, fixed Cash. Board for kids: **biggest haul today** (server board at launch, global from Dec 11); "fewest clones" is the Diamond tier. Daily streak with one grace day |
| D7 | Advent tree filling up (24 slots); Dec 11 drop and Dec 18 finale; Clone Party bag levels; friends (co-op +Cash) |
| D28 | Jan 8 Contracts, Jan 22 Museum, Feb 12 Season 1 with a free cosmetic ladder; "Legend" frame for 3-starring a location; hideout trophies others can visit |

Dig to Escape simplicity check: one goal, a visible threat (Gus), a number that grows (Cash, haul), a shop, a chase. **Never more than 3 meters during a run** (timer, haul, clones).

### 5.4 Monetization (ethical and 2026-compliant)

**Hard rules:** no paid randomness; no Robux-to-Cash; no pay-to-skip, paid hints, redo or extra runs; no prompt during a heist or on a bust; at most one unprompted offer in a non-payer's first session, after Level 1, on the van screen. All prices from `GetProductInfoAsync`; exactly one idempotent `ProcessReceipt` (lihfolk-systems `Receipts`).

| Product | Price (R$) | Timing |
|---|---|---|
| **Clone styles** (Gold Ghost, Noir, Neon Outline): code-only material/colour presets on the clone rig | 79-149 each | Launch |
| **Christmas Crew bundle** (Santa clone style + sleigh van paint + snow trail), fixed contents shown upfront | 199, once | Launch, until Jan 4 |
| Van paints | 49-99 | Launch |
| Clone emotes (your clones perform an emote you own at a recorded moment) | — | Jan 8, from Roblox catalog emotes the player owns, or post-launch authored ones |
| Rewind styles | 79-149 | Jan 22 |
| Private servers | **Free** | Launch |
| **Rewarded video** "double this heist's Cash", 5/day, 13+ only | — | When eligible (~2,000 monthly visitors and an ID-verified owner per [docs](https://create.roblox.com/docs/production/promotion/rewarded-video-ads)) |

Revenue is not the launch goal; D1, D7 and co-play are. The draft's "+1 clone slot pass" is dropped with owned slots.

---

## 6. Art direction and style bible

### 6.1 The look: "Neon-Noir Diorama"

Chunky, bevelled low-poly sets built like a model kit, lit at night in deep indigo (never black) with warm pools of light, and one glowing colour family reserved for clones. References: Hitman GO's miniature board ([Game Developer](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense)), Monaco 2's readable 3D, Teardown's simple shapes under rich light. It scored 8.5/10 against realistic PBR (4/10) and full toon (6.5/10) (visuals D1). On Roblox "premium" means coherent and readable (vault *Teardown - Pressure*). **Most of "premium" is code and cheap:** the palette, the lighting recipe, the clone glow, the rewind and the reel.

**Shape rules:** props 1.5-2x real scale, buildings ~1.2x; one-segment bevels only (0.06-0.08 studs small, 0.12-0.2 medium, 0.2-0.3 building corners); one focal feature per prop at ≥ 1.5x any secondary; one storytelling prop per room (Gus's donut box). Each level is a cut-away model on a dark, hazy "table". **The art must read with shadows off** (phones at low quality draw none).

### 6.2 Palette and colour language

| Role | Name | Hex | Rule |
|---|---|---|---|
| Base shadow | Ink Indigo | `#1C1F3B` | Never darker |
| Base mid | Plum Slate | `#3A3560` | Most walls, 30-55% value |
| Lit interior | Warm Marble | `#D8C8A8` | Inside light pools |
| Metal | Vault Steel | `#7C86A6` | Doors, safes, rails, **plates** |
| **Danger** | Alarm Red | `#FF3838` | Lasers, alarms, "seen!" only; always with a shape (beam, zigzag, ring). Owner-confirmed 2026-11-12 (the draft's `#FF3348` was only 0.194 Oklab from Clone Magenta; STYLE_BIBLE §1.3) |
| Guard light | Torch Amber | `#FFD27A` | Flashlight cones only; shape = cone |
| **Loot** | Heist Gold | `#FFC21F` | Loot only; shape = sparkle (Gold vs Amber fails colour-blind at 0.051, so shape carries it) |
| Exit | Getaway White | `#F4F7FF` | Van and chevrons, always with an arrow |
| **Clone P1 / solo** | Clone Cyan | `#3DE8FF` | Reserved |
| Clone P2 | Clone Magenta | `#FF4FD8` | Reserved |
| Clone P3 | Clone Indigo | `#6A5CFF` | Reserved |
| Clone P4 | Ghost White | `#F4F7FF` | Reserved for clones as a glow; exit uses white only as solid chevrons with arrows |
| Orphan tape | Tape Grey | `#8A8FA8` | Clones of a player who left |
| Christmas accents | Holly Green / Ribbon Burgundy | `#2FBF71` / `#8C2F4B` | Dressing layer only; fairy lights are warm white; Alarm Red is never used as decoration |

- **Reserved-hue rule:** no environment asset within ±20° of a clone hue at saturation above 40%. The v0.1 blue plate becomes a steel plate with a white icon that takes the presser's hue and glyph.
- **Identity = glyph + number + hue.** ●1 ■2 ▲3 ◆4 badges are mandatory, not a setting.
- **CI audit (Lune):** Oklab distance ≥ 0.15 for small signals and ≥ 0.20 plus a shape for danger, on every palette change (vault *Colour-Blind Safe Design*). Greyscale test: characters, loot and danger differ from the ground by 15% value or more.

### 6.3 Lighting: "Heist Night" recipe v1 (in the project file, chosen once)

- **Where it lives:** `default.project.json` gets a `Lighting` node with `$properties` and the effect children, so `rojo build` produces the real look and the live place never depends on hand edits (§8.5). Spike S6 (W1) checks that Rojo/rbx-dom writes `LightingStyle` and `PrioritizeLightingQuality` [UNVERIFIED]; if it can't, those two are set in the one-time Kit/base file and a CI check compares the built place with `docs/STYLE_BIBLE.md`.
- **Style choice (once, Wed Nov 18):** from the W1 golden-room screenshots at PC Quality 10, phone Automatic and phone quality 1-3. Default **Realistic + PrioritizeLightingQuality on** if the phone shots read; otherwise **Soft**. There is **no runtime kill switch**: both properties are Studio-only ([Lighting reference](https://create.roblox.com/docs/reference/engine/classes/Lighting), [Unified Lighting](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512)).
- `Lighting`: GlobalShadows on, ClockTime 0, Brightness 0.5, Ambient (55,55,95), OutdoorAmbient (75,80,130), ColorShift_Top (255,210,160), EnvironmentDiffuseScale 0.25, EnvironmentSpecularScale 0.35, ExposureCompensation 0.2.
- `Atmosphere` (streets only): Density 0.3, Color (70,60,120), Decay (35,30,75), Haze 0.8.
- `BloomEffect`: Intensity 0.8, Size 28, **Threshold 1.0**. `ColorCorrection`: Contrast 0.12, Saturation 0.1, Tint (235,230,255). No SunRays. DepthOfField and Blur only in menus, the planning camera and the reel.
- **Local lights:** shadows off by default; ≤ 4 shadow-casting hero lights per view; fake other pools with floor decals or transparent Warm Marble discs; sleep lights beyond 120 studs.
- **Runtime performance tier** (scriptable controls only, picked by measured frame time, §8.6): `GlobalShadows`, per-light `Shadows`, Bloom/ColorCorrection `Enabled`, Atmosphere `Density`, particle rate caps, Highlight count, clone LOD distances.
- Per-location recipes as data: Christmas Eve (warmer, Ambient +10%), Museum (cold moonlight), Sky Lounge (gold on plum), Moon (grey and white).

### 6.4 Materials and textures

- **SmoothPlastic + `MeshPart.Color`, or one 256×256 palette atlas per kit** with UVs snapped to cells, so kit pieces instance.
- ≤ 3 hero SurfaceAppearances per level (vault door, diamond, event centrepiece): Color + Roughness at 1024 plus an **emissive mask** ([DevForum](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705)). Emissive masks also drive signage, dials and Christmas lights.
- Neon ≤ ~1/6 of an object's pixels. No EditableMesh or EditableImage in the core.

### 6.5 The clone look (the hero visual), decided by the W1 bench

Goal: "that's me, but a ghost from 20 seconds ago", readable at 64 px, **recognisably my own avatar** up close (our main marketing difference).

1. **Rig source:** the server builds **one stripped template per owner** from `Players:CreateHumanoidModelFromDescriptionAsync` into ReplicatedStorage (v0.1's `Echoes.luau` already does this); clients clone and **pool** it, showing a mannequin placeholder until it arrives. Joint code accepts both `AnimationConstraint` and `Motor6D` (Avatar Joint Upgrade, vault *AnimationConstraint and Physically Simulated Characters*).
2. **Stripped silhouette:** no SurfaceAppearance, textures, decals, face or layered clothing; ≤ 2 accessories (hair or hat); SmoothPlastic in the owner hue; `CastShadow = false`. SLIM does not apply to NPC rigs ([SLIM docs](https://create.roblox.com/docs/workspace/streaming/slim)).
3. **Three candidates, A/B'd on the owner's phone in W1 (spike S1):**
   - **A. Translucent rig:** Transparency 0.45 + one Highlight per owner group (OutlineTransparency 0, FillTransparency 0.85, DepthMode Occluded).
   - **B. Opaque glow rig (expected default near the camera):** opaque, saturated owner hue with a Highlight outline only (FillTransparency 1); avoids transparency sorting and overdraw on mobile.
   - **C. Hologram mannequin:** one shared mesh, owner hue + the owner's hair/hat accessory; expected beyond **25 studs**, or everywhere if A and B fail the budget.
   - Highlights are persistent and animated, never created per loop (the first costs up to ~1 ms GPU on mobile and cost grows with screen coverage, vault *Highlights and Selection Effects*, [docs](https://create.roblox.com/docs/en-us/effects/highlighting)). One extra **x-ray** group for your clones on plates behind walls.
4. **Age ramp:** each older run is 12% dimmer; in solo, older runs drift up to 25° toward violet (the "8 copies" gradient).
5. **Badge, label and trail:** a 28 px glyph badge ("●3"), hidden beyond 40 studs; in L1 and in every reel, a burned-in **"◀ YOU, 20 SEC AGO"** label on the newest clone (resolved 2026-11-12 with §7.5: in L1 the clone forms 0.5 s after control returns, so it visibly walks out of you, and the label stays until its recorded path ends on the plate + 1.5 s; "Your clone stops where you stop." shows when that clone first presses the plate; elsewhere the label is up for its first second); a 0.5 s owner-hue Trail only above walk speed.
6. **"Tape print" spawn:** clones form in record order 60 ms apart (≤ 0.4 s), with a scanline sweep, a floor ring and the clone arpeggio (§7.2). Busted: glitch slices, then a tape-ribbon burst (≤ 30 particles).
7. **Readability guards:** 3+ clones within 2 studs show the newest fully and the rest outline-only with "×3"; clones within 6 studs of the camera fade; a clone-opacity slider (50-100%). Players stay opaque and shadow-casting; other players' clones render at 70% brightness on your screen; orphan tapes in Tape Grey.

**Gus and threats:** Gus is a **rigid-part rig with R15 proportions** (separate Blender pieces, no skinning), drawn on clients like clones. A flat floor cone in Torch Amber (Transparency 0.75, Neon edge, clipped by a 12-ray fan at 10 Hz), drawn from the same `Guards` module as the server; the cone fills amber, shows "?" at 0.6 s and "!" at 1.2 s. Lasers: dark-ink core, red body, thin white-hot core, red floor dot, 3 flickers before re-enabling (timed to the server window, §8.10).

### 6.6 Presentation

- **Rewind:** §7.1.
- **End-of-heist cut (12-15 s; the built Line-up is ~6.8 s: a SKIP ▶▶ chip from 1 s, a tap anywhere only after the pose on a session's first cut, so a kid still mashing GRAB keeps the payoff):** a 6 s **blooper + win** combo by default: the funniest auto-tagged failure from the blooper log (Bonk/Zap/Busted, weighted by "repeat at the same spot"), then the **Crew Line-up** (§3.2 #8) at the van; then the final run's 3 auto-picked shots (wide diorama, tracking the loot carrier, a hero moment at 0.35x). Burned-in caption ("RUN 6 · 8 OF ME · $1,000"), the "◀ ME, 20 SEC AGO" label, subject inside the central 32% of frame width (9:16-safe), HUD, chat and nameplates hidden. **[Resolved 2026-11-12, camera track, PLAN_STEAM_PLUS C5]** the 32% rule: every figure stays inside the central 32% of the width (`Config.Heist.CAMERA.LINEUP`); a row whose spots sit inside the van body (every level's default row and the L5/L6 `lineup.z = 28`) keeps its facing and slides onto the pavement in front of the lit shop front, and the shot searches low-then-high for a clear lane over the van (client-side only, no level data moved; `tests/unit/HeistLineup.spec.luau` on every level and daily vault).
- **Garage lobby:** your van shows your trophy shelf and, on first join, a looping Crew Line-up of 8 copies of **your own avatar** (from Mentor-tape paths) as the promise of what's coming.
- **Live slow-mo (cosmetic):** last loot banked with < 3 s left slows local animations to 0.5x for 0.6 s.

### 6.7 Asset and animation pipeline

- **Model:** Claude's Blender scripts through the `roblox-blender-modeling` gates (A1-A18, visual rubric ≥ 14/18). `bpy` is not installed (`import bpy` fails); W1 installs it (pip `bpy`, version matched to the Python here) and every asset gets a **turntable PNG** that Claude reviews itself before the owner sees it. Budgets: small 600/1,500 tris, module 800/2k, hero 10k/20k; Gus ≤ 5k tris in rigid pieces.
- **Launch kit: ~12 modules + 3 hero props** (vault door, cash register/diamond, Giant Present), reused across Corner Shop, Toy Shop and Bank through atlas swaps and the Christmas dressing layer.
- **Golden assets (W1-W2):** the vault door (8-10k tris, emissive dial), a wall module + counter, gold bars + diamond, Gus, the clone look. **Recommended:** commission these 5 from a freelance Roblox environment artist ($300-600, original work, rights assigned in writing) as the style reference; Claude builds the rest of the kit to match.
- **Owner review:** a fixed **15-minute daily screenshot slot** (golden room, phone and PC, same 4 camera bookmarks).
- **Kit into the game:** the owner imports the kit once per revision in Studio (Import 3D, correct `InitialSize` and collision) and saves **`assets/Kit.rbxm`**, which Rojo maps into `ServerStorage/Kit`; Lune and the server only **clone** kit pieces, never create MeshParts. Fallback if spike S2 fails: the server builds each kit mesh once at boot with `AssetService:CreateMeshPartAsync(meshId, {CollisionFidelity = Box})` and caches it (a DevForum report puts the cost near 22 ms + 0.27 ms per 1k triangles each [UNVERIFIED], so at boot, never per heist). Mesh ids must be owned by the experience owner.
- **Animation:** avatar clones use Roblox's default R15 walk/run/jump clips (verify they load, v0.1 risk). Gus and all fail states are **procedural** (CFrame/scale tweens, a client-side cosmetic flop, particles) plus **3 authored clips** (Gus double-take, shrug, heavy carry) written in code as data and played by a small client **pose player** on the joints (no Studio-only `RegisterKeyframeSequence` in shipped code, vault *Publishing Animations*). Owner reviews each clip by screen recording in the daily slot. Animation Graph use is limited to Clip and Blend1D nodes ([full release](https://devforum.roblox.com/t/full-release-animation-graphs-create-complex-character-motion-visually/4739840)).
- **Buy / generate:** nothing from the Toolbox; licensed SFX only; AI images for moodboards only.
- **Audit and bible:** `budgetReport(root, "mobile")` (`LihFolkWorld.luau`) via Open Cloud against the test place, diffed per pass; `docs/STYLE_BIBLE.md`, 6 pages of numbers.

### 6.8 Mobile budgets (busiest view: a Big Score with 4 players, 12 clones and 2 guards)

| Budget | Target | Ceiling |
|---|---|---|
| Frame time | ≤ 16.6 ms on a mid Android (~4 GB) | 33 ms on a low Android (2-3 GB) |
| Draw calls | ≤ 350, of which clones ≤ 120 | 600 ([Roblox docs](https://create.roblox.com/docs/performance-optimization/design)) |
| Triangles in view | ≤ 300k | 600k |
| Level art instances (per heist instance) | ≤ 6k | 10k |
| All live client instances | ≤ 25k | 40k |
| Clone system client memory (16 pooled rigs + reel) | ≤ 40 MB [estimate] | 60 MB |
| Live particles (touch) | ≤ 360 | — |
| Highlights | ≤ 4 clone groups + 1 x-ray + 5 others | — |
| Textures per level | 1 atlas (256) + 1 trim sheet (1024) + ≤ 3 hero sets × 2 maps | — |
| Shadow-casting local lights | ≤ 4 per view | — |
| Client memory | ≤ 60% of device memory | 75% |

Presets Auto / Performance / Balanced / Quality; clones, cones and lasers are **exempt from culling**.

---
## 7. Game feel, audio, VFX, UI/UX and onboarding

### 7.1 The Rewind (the signature moment)

A client `RewindDirector` owns the sequence; the server only waits `Config.REWIND_TRANSITION` (v0.1's hard-coded `task.delay(0.9)` in `Main.luau` moves to Config).

| t (s) | Picture | Sound |
|---|---|---|
| 0.00 (input) | Button presses in; co-op pip fills | Tape-deck "clack", played locally before any server reply |
| 0.00 (server) | 66 ms freeze, 0.06 s white flash at 25% | Music PlaybackSpeed 1.0 → 0.25 over 0.3 s (tape-stop dive; verify pitch follows speed) |
| 0.10-1.35 | Saturation -0.8, cyan tint, Blur 6, VHS tracking bands, "◀◀"; **every actor's path reels backwards** as owner-coloured Beams; FOV 70 → 64 | Pre-reversed 1.2 s stinger (Roblox can't play audio backwards, [DevForum](https://devforum.roblox.com/t/how-can-i-make-a-sound-play-in-reverse/1847141)) |
| 1.35-1.55 | Grade snaps back; clones "tape print" in | "Clunk" on the bar line, then the clone arpeggio |
| 1.55-1.80 | "RUN 4" stamps in (UIScale 1.25 → 1.0, Back Out) | Music restarts on the downbeat |

Quick (1.0 s) drops the path reel; reduced motion (0.8 s) is a crossfade. Effects live under `CurrentCamera`, not `Lighting` as in v0.1.

### 7.2 Audio direction: "caper night"

- Upright bass, brushed kit, Rhodes/vibraphone, muted trumpet, analogue pad, light tape saturation; sleigh bells and celesta in the Christmas mix.
- **128 BPM**, so every run is whole bars (30 s = 16, 45 s = 24, 60 s = 32); the music restarts on GO and the last 4 bars are the countdown.
- **Crew Layers:** S0 base; S1 keys at 1+ clones; S2 lead at 3+; S3 brass at 6+; S4 full at 10+; **S5 chase** on the Alarm Run, in the last 4 bars or on Gus's "!". Primary method: all stems started sample-aligned with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()` (vault *Music and Adaptive Audio*), proven in spike S4. Fallback: start all stems together at volume 0 on GO and fade layers (alignment holds because they start together).
- **Sourcing:** soft launch uses licensed library tracks in-game; **TikToks and trailers use owned or platform-licensed music only** (library music off-platform is [UNVERIFIED]). Optional commission (owner decision): 2 stemmed tracks (main theme + Christmas) with trailer rights, only if they arrive by Dec 9.
- **The clone arpeggio** (C-major pentatonic, one step up per clone, 60 ms apart) is the sound logo.
- **Clone bus:** lowpass 5 kHz → 90 ms echo, 4 dB under player sounds; no clone footsteps; ≤ 6 clone sounds per second, nearest 4 voiced. Buses: Music, SFX (+ Clone), UI, Ambience, Warnings (floor 25%) → compressor → limiter.
- ~38 licensed launch SFX, 3+ variations for anything repeated, with an id manifest and live load checks (lihfolk-sfx).

### 7.3 World feedback and VFX

- **Plate:** sinks 0.15 studs in 0.06 s; the rim takes the presser's hue and glyph; a pulse runs along a floor **cable** to the device; on release the cable **drains over the 0.4 s grace**.
- **Vault door:** red → green lamp, slides open in 0.35 s, amber blink while closing, **solid only when fully shut** (fixes the v0.1 push bug). **Lasers:** hum, retract with sparks, 3 flickers before re-enabling.
- **Detection:** the cone fills amber, then "?" with Gus's head turn, then "!"; a heartbeat tick in the Warnings bus from "?".
- **Caught:** 66 ms freeze, red vignette pulse, a short camera ease toward Gus (skipped under reduced motion), BUSTED stamp, brass "wah-wah", caption "[Guard spotted you]", then the 2 s busted-cam; no shake.
- **Alarm Run:** rotating red lights (emissive, not extra lights), chase stem, "VAN LEAVES 0:20" counter in Alarm Red with a ring glyph, Gus's sprint dust puffs.
- **Banking:** "ka-ching", a 24-coin burst, "+$100" flying to the loot meter, a 0.35-1.0 s count-up; clone banks show the glyph ("◆2 +$100"). The **diamond** is the only mid-heist moment that dims the world (15% for 0.6 s).
- **Heist complete:** stamp, ≤ 120 money-rain particles, the end-of-heist cut (§6.6), then a results card stamping Haul, Crew and Clean 0.25 s apart, "x clones · y runs · m:ss", the new trophy flying to the van shelf, and Replay / Next / Save Clip.
- VFX value rule (dark ink, body, white-hot core, one accent hue; vault *VFX Readability and Value*); flashes capped at 3 per second.

### 7.4 HUD and UI

Four elements during a run, everything else contextual:
1. **Top centre:** tape counter ("0:27") + "RUN 3" + a thin **run bar** with icons for your clones' recorded events and red failure markers; during a redo, the "on time / late" strip. Last 10 s pulse; last 5 s Alarm Red with a ring glyph.
2. **Top left:** loot meter "$400 / $1,000" (Clone Party: "$2,350 · best $3,100").
3. **Top right:** clone strip (glyph, digit, hue per clone; busted = grey ✕); it opens the Clone Deck between runs.
4. **Right edge, ~35% height** (`END_RUN_Y`; 45% left it too close to the jump button on a 360-dp phone): 72 px END RUN button ("◀◀ END RUN"; co-op "END RUN · 2/3"), locked ring for 1.5 s.

One objective line of 8 words or fewer, shown only when it changes or when stuck. Text ≥ 14 px on phones, taps ≥ 48 px, inside `CoreUISafeInsets`; tested at 7 viewports (roblox-ui-builder), including a 360-dp Android phone in landscape (the HUD is designed at 720 × 330 so the garage and results fit at the smallest scale). Contextual extras (2026-11-12): **Interact** sits lower right, left of the jump button (never next to END RUN, which also ignores taps within 0.3 s of a GRAB); a **❚❚ menu** chip (upper left) leaves the heist at any time; **◐ HIDDEN** while you hide; one bottom **message rail** (toast, caption, spectate line in fixed slots); "▶ RUN n · 0:08" counts down to the auto-start (co-op "2/3 READY"). Level select: tapes on a shelf in the van with medal stickers.

**Accessibility at launch:** glyph + number + colour; captions on by default; a Comfort module (reduced motion, shake slider, 3/s flash cap, FOV-kick toggle, clone opacity); **Relaxed**; a photosensitivity line. **Localization:** every string a key via `FormatByKey`; auto-translation covers 16 languages but **not Danish**, which needs a manual table ([docs](https://create.roblox.com/docs/en-us/production/localization/automatic-translations.md)); Danish table ships Jan 8.

### 7.5 Onboarding: Level 1 "Back Room" (first clone ≤ 30 s, first bank ≤ 45 s, ≤ 30 words)

The key mental model, taught explicitly: **"where you stop is where your clone stays."**

| t | Player | Game | Text |
|---|---|---|---|
| 0-8 s | Spawns at the open van door, facing the shop | Door shut; glowing plate with a cable to it; cash glittering through glass | "Step on the plate" |
| 8-10 s | Steps on the plate | Door rises, the cash glitters; **REWIND pulses only while the player stands on the plate** | "Stay on it. Tap REWIND." |
| 10-12 s | Taps REWIND, **or** stays 2.0 s on the plate | **L1 run 1 auto-ends after 2.0 s on the plate** (forced quick rewind), so run 1 always ends on the plate. If the player steps off, REWIND stops pulsing and the plate re-pulses | — |
| 12-13 s | — | Quick rewind (1.0 s) | — |
| 13-22 s | Walks toward the door | **The clone forms (chime), walks from the van to the plate and stays there**; the door opens and stays open | "◀ YOU, 10 SEC AGO" (label on the clone) · "Your clone stops where you stop." |
| 22-38 s | Grabs the cash, runs | Gold chevrons to the van | "Bank it at the van" |
| ≈ 40 s | **First reward** | Ka-ching, coins, "RUN 2 · $100" | — |
| 40-180 s | Second room: a laser plate behind the first door needs a second clone; first Crew Line-up; first trophy (Golden Gum) | Objective only when stuck | ≤ 6 more words |

- **L1 recovery (2026-11-12):** the objective follows the world, not the run number. While no replayed clone stands on plate A (run 1, a run 1 that ended off the plate, or a plate clone replaced at the cap), the auto-end stays armed (`tutorial.autoEnd.untilDone`), the line says "Step on the plate", the stuck hints run and END RUN is dimmed off the plate. A new account never sees the garage first: its client shows a "the van door opens" card until L1 starts (a failed start retries), and the daily vault opens only after L1 is cleared.
- **Stuck hints** at 8, 16 and 24 s: re-pulse the plate → a beam from your feet → the **Mentor tape** ghost does the step. After 2 failed runs on any level a Ghost Hint plays the solution once (free on launch levels, 3 a day later, **never sold**). No offers during the FTUE; returning accounts can skip.
- **Naive-kid guarantee:** L2 headless tests replay recorded "wander" runs (plate on/off, explore, door) and assert FirstBank within 2 runs on L1 and a clone + bank within 3 runs on L2-L4 (§8.9).
- **Funnel `onb_v2`** (server-only, `LogOnboardingFunnelStepEvent`): Joined → FirstMove → FirstPlate → FirstRewind → FirstCloneSeen → FirstBank → L1Complete → ReelShown → L2Started → FirstCloneBusted → **SwarmSeen** (6+ own clones on screen) → Minute10. Targets: ≥ 90% per step to FirstBank, ≥ 70% reach L1Complete, **≥ 60% SwarmSeen by minute 10**.

---

## 8. Technical architecture

### 8.1 What changes from v0.1, and why

v0.1 (3,648 lines of Luau across `src/`) has the right core (mechanisms read `Actors`; clones obey player rules) but three structural problems, confirmed in code: (1) clones are server Instances whose `root.CFrame` is written every Heartbeat (`Echoes.luau`), costing CPU, bandwidth and smoothness; (2) the world is not deterministic (`Guard.luau` uses `Humanoid:MoveTo` with `task.wait`; the recorder in `Main.luau` runs on `task.wait`); (3) recordings trust client-owned movement, so a speed hack replays forever. v0.1 already passes 20/20 checks of `tests/engine_smoke.luau` in a real Roblox server via Open Cloud Luau Execution (test universe 10776026960, place version 7, 2026-11-12, PROJECT_STATE), but **no human has played it in Studio yet**, so the refactor starts only after the Nov 16 fun gate; only the pure `shared/Rec` codec and sampler may start before it.

### 8.2 Target architecture: sim core + client view

- **Server:** per heist instance, one fixed-step **20 Hz `HeistSim`** on loop time (Heartbeat accumulator, never `task.wait`) with mechanisms, guards, loot, banking, alarm and the timer. **Clones are pure data** on the server: `{ownerId, slot, rec, alive, state, carrying, orphan}`, position from `Sampler.at(rec, t)`. Plates use point-in-box, lasers segment tests, Gus raycasts against **sim boxes** (generated from the layout, §8.5) to sampled points. The server stays authoritative for every outcome (CLAUDE.md rule).
- **Loop clock:** replicated as `{anchorServerTime, anchorLoopT, rate}`; every view samples `loopT = anchorLoopT + (GetServerTimeNow() - anchorServerTime) × rate`. Fast-forward changes `rate` and re-anchors; the sim takes N substeps per tick at 3x. This keeps clients in sync during fast-forward.
- **Clients:** receive each recording **once** as a compact `buffer` over a reliable RemoteEvent and **render local rigs** from the loop clock. Server-decided changes (busted, stuck, dropped loot) arrive as reliable events stamped with t and blend in over 150 ms. Plates light from the **server** attribute.
- **Doors, lasers, Gus** are state machines with timestamps in attributes (`DoorA_OpenUntil`); clients tween locally, the server never tweens. Late joiners get the clone store (≤ 12 × ~8 KB) plus attributes.
- **Heist instances (§3.3):** a `HeistInstance` object owns a sim, a level copy at an offset, its party and its remotes' routing; up to 4 per server; server sim budget per instance ≤ 2 ms.

### 8.3 Recording format

- **20 Hz**, sampled inside the sim tick. **8 bytes per sample:** position as three `i16` at 1/16 stud relative to the level origin (±2,048 studs), yaw `u8`, flags `u8` (grounded, jumping, crouch, carrying-heavy, hidden, 3-bit pose/emote).
- Header: version, level id, loop index, sample count, validator flags. Events: `{t_ms u16, kind u8, arg u16}`, 5 bytes each, typically < 30 per run.
- 60 s run = 9.6 KB raw, ~5 KB delta-coded. One new clone per player per run, so ~8 KB per client per rewind. Recordings never travel unreliably (900-byte UnreliableRemoteEvent limit, [docs](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent)).
- Playback: Catmull-Rom on position across 4 samples, shortest-arc yaw, derived velocity feeds the animation speed. **Sample by time, never by frame index** ([Messenger Mouse devlog](https://troystorygames.itch.io/messenger-mouse/devlog/945109/record-and-replay-ghost-races)).

### 8.4 Module layout

```
src/shared/  Config, Types, Tags, Scoring, LoopClock
  Sim/  HeistSim (pure step) · Actors · Mechanisms · Guards (patrol(t), chase steering, A*, vision, hide) · Loot (light + heavy grips)
        Interact (the ONLY intent entry point) · Divergence (dynamic blockers, Stuck/Confused) · Alarm
  Rec/  Codec (buffer, versioned) · Sampler · Validator
  Level/LevelSpec (layout + kit metadata -> LevelData + sim boxes, asserts)
src/server/  Main.server.luau + Services/ Lobby · Instances · Loop · Sim · Record · Level · Progress · Party · Analytics · LiveFlags
             LihFolk/ PlayerData Net RateLimit Leaderboard Receipts Shop DailyRewards
src/client/  Controllers/ EchoView (pool) · GusView · WorldView · RewindDirector · HUD · Input · Camera · FX · Audio · Tutorial · Comfort · PosePlayer · Perf
assets/Kit.rbxm (owner-imported)   levels/<id>.layout.luau   levels/<id>.solution.bin (human-recorded)   levels/<id>.naive/*.bin
tests/unit/*.spec.luau  tests/sim/*.spec.luau  tests/engine_smoke.luau  selene.toml + shared/Sim/selene.toml
```

`shared/Sim/*` must not touch engine services (it takes Vector3/CFrame, plain tables, an injected clock and `Random`), so ~80% of the logic runs in Lune. A **second `selene.toml`** for `shared/Sim` uses a std without `task`, `os` or `math.random`, plus a Lune grep check; dictionary-order bugs are caught by the event-log hash test, not by lint (Selene cannot ban `pairs` over dictionaries).

### 8.5 Gameplay systems and level pipeline

- **Interactions are intents:** `Interact.request(actor, kind, targetId)` validates range from the actor's **sim position**, target state and cooldown, then records the event; replaying clones call the same function (holds are `holdStart`/`holdEnd`).
- **No physics for anything clones touch.** Loot and doors are anchored and placed by the sim. **Heavy loot** has `grips[]`: it moves only when `#grips >= N`, faster with more grips (Giant Present: 2 required, 4 max), follows the grippers' centroid at ≤ 8 studs/s, drops if a gripper is busted or leashed beyond 5 studs.
- **Clone rig:** `Humanoid.EvaluateStateMachine = false`, physics off; Blend1D by speed plus jump/land from flags and an emote layer, ≤ 4 tracks; animation LOD (full < 40 studs, 15 Hz joints to 100, none beyond); all roots in one `BulkMoveTo` per frame; `AnimationController` fallback if the Humanoid costs too much. Rigs are **pooled per owner** and never destroyed on rewind; the reel reuses the same pool.
- **Levels are data, not files of MeshParts:** `levels/<id>.layout.luau` lists kit piece names, transforms and tags (`EH_Plate`, `EH_Door`, `EH_Laser`, `EH_Loot`, `EH_HeavyLoot`, `EH_GuardPath`, `EH_Hide`, `EH_Spawn`, `EH_Van`, `EH_NoGo`, `EH_AlarmLock`) with attributes as wiring. At heist start the server clones kit pieces from `ServerStorage/Kit` into the instance. The **sim boxes** (blockers and Gus occluders) are generated from the same layout and kit metadata; `LevelSpec` asserts every collidable kit piece has a sim box. LevelSpec also runs in Open Cloud Luau Execution against the real kit.
- **One source of the place:** the live place is **always `rojo build` output from git**, including Lighting `$properties`, `assets/Kit.rbxm` and the layouts. The owner's Studio art and lighting experiments happen in a separate **art place**, and come back only as exported files committed by Claude. `servePlaceIds` lists the dev place only. CI checks the built place's Lighting against `docs/STYLE_BIBLE.md`.

### 8.6 Networking and performance budgets

| Budget | Target | Ceiling |
|---|---|---|
| Server sim step per instance (20 Hz) | ≤ 2 ms | 5 ms |
| Clone system CPU on client (sample + BulkMoveTo + anim) | ≤ 1.5 ms for 12 clones | 3 ms |
| Server → client steady data | ≤ 20 kbps | 30 kbps (vault *Network Bandwidth Budgets*) |
| Per-rewind burst | ≤ 40 KB | 100 KB |
| Join to playable on 4G | ≤ 8 s | 15 s |

StreamingEnabled on (MinRadius 128, Target 512, Opportunistic, `ModelStreamingBehavior = Improved`), mechanism models **Atomic**. Clients bind through tags, never by indexing level parts. Profiling labels `EH.Sim`, `EH.EchoSample`, `EH.EchoAnim`, `EH.GuardVision`; a debug-only **bench mode** spawns 12 (then 16) synthetic clones. **Telemetry from launch day:** the client `Perf` controller sends one rate-limited sample every 60 s (median and p95 frame time, device platform, memory tier, graphics quality, clone count on screen); analytics shows frame time by device tier from Dec 3, because the 12/16 cap and LOD distances depend on it. The performance tier (§6.3) steps down automatically when p95 > 33 ms for 20 s.

### 8.7 Data

- Install lihfolk-systems `PlayerData` (90 s session lease, token-fenced saves, 30 s dirty-gated autosave, parallel BindToClose), `Net`, `RateLimit`, `Leaderboard`, `Receipts`, `Shop`, `DailyRewards` as-is.
- Profile slice `Heist` (< 16 KB): `schemaVersion`, `vaults[levelId] = {best = {timeMs, clones, stars, recHash}, medals}`, `haulBest`, `bagLevel`, `trophies`, `ornaments`, `cosmetics`, `cash`, `stars`, `daily = {lastDay, streak}`, `ftueStep`, `firstHeistDone`.
- **Ghost keys** `G_<levelId>_<userId>` hold your personal-best recording (10-40 KB), written only on a new best.
- **Boards:** daily "biggest haul" (server board at launch; global OrderedDataStore per day from Dec 11), score written on improvement and only for untainted runs; MemoryStore sorted map caches the top 100 for 60 s.
- **LiveFlags:** a DataStore key polled every 60 s turns features off without a republish (SAVE CLIP, boards, Quick Crew, store items, dressing layer).
- Budgets are per experience and shared with Open Cloud since 2026-07-29 ([docs](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits)); `SetRateLimitForRequestType`; jobs self-throttle.

### 8.8 Anti-exploit

- **`RecordingValidator`** on each 20 Hz sample: horizontal speed ≤ `WalkSpeed × 1.35 + ping allowance` (leaky bucket), vertical rise ≤ jump apex + 1 stud, no segment through closed blockers or `EH_NoGo` volumes, exemption tokens for server teleports. Violations are **clamped** and the run is **tainted**: it plays but never earns medals or board entries. No kicks on movement alone ([server-side detection](https://create.roblox.com/docs/scripting/security/server-side-detection)).
- Medals and scores are computed **only on the server**; board entries store the recording hash for headless replay in CI.
- Clients send only validated, rate-limited intents (END RUN, Clone Deck actions, interact, ping, marker, crew/lobby actions, perf sample). This widens CLAUDE.md's "clients only send `RequestRewind`" rule; CLAUDE.md is updated when that code lands.
- **Server Authority** (`Workspace.AuthorityMode = Server`, [DevForum](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993)): not at launch; a 2-day spike in a branch place in the Jan 11-15 window; adopt only if movement feels equal or better at 150-250 ms.

### 8.9 Tests

| Layer | Where | What | When |
|---|---|---|---|
| L0 Static | Local + CI | StyLua, Selene (two configs), luau-lsp, `rojo build`, LihFolk checker, Oklab palette audit, built-place Lighting check | Every commit |
| L1 Unit (Lune 0.11.1) | Local + CI | Codec round trip (≤ 1/32 stud), Sampler, LoopClock, Validator fixtures (walk, jump, fall, teleport, speed hack), `Guards.patrol(t)` and chase steering, scoring, migrations, LevelSpec | Every commit |
| L2 Sim (Lune, headless) | Local + CI | **Determinism** (identical event-log hash twice); **fast-forward equivalence** (3x loop = 1x loop log); **solvability** from **human-recorded** `solution.bin`; **naive-kid** recordings (§7.5); **latency injection** (live-player streams delayed 50-250 ms, asserting the fairness rules of §8.10); divergence (door closed early → Stuck); soak (500 loops) | Every commit |
| L3 Engine (Open Cloud Luau Execution) | Test place | Real buffers, remotes, kit cloning, LevelSpec on real kit, DataStore `_TEST` keys. No players or physics; data-model changes are not saved; **5 task creations per minute per key owner**, so all L3 checks run as **one batched task per merge** (vault *Code Pipeline* Stage 5) | Merge to main |
| L4 Human | Studio, phones, early testers | §10.3 | Every milestone |

- **Golden solutions are human-recorded:** a debug command, after the owner (or a tester) clears a level in Studio, writes the run buffers to a `_TEST` DataStore key; Claude pulls them with the Open Cloud DataStore API into `levels/<id>.solution.bin` as CI fixtures. Hand-written recordings are only used for logic unit tests.
- **Client regression:** no automated multi-client tests exist, so each milestone runs a scripted Studio "Clients and Servers" checklist (3 clients, Incoming Replication Lag 150 ms) and client-side assertions are logged to the server and to analytics.
- CI: GitHub Actions, Rokit-pinned `rojo` 7.7.1, `lune`, `selene`, `stylua`, `luau-lsp`; L3 secrets `ROBLOX_API_KEY`, `TEST_UNIVERSE_ID`, `TEST_PLACE_ID`. Publishing: `rojo build` → `cloud_test.py` publishes a **Saved** version to the **test place** → tests → the live place is published from the **same built file** on a release tag.

### 8.10 Lag fairness between live players and clones

1. A live player's hazard checks (laser, door bonk, plate release) use the mechanism state at `t − the player's measured one-way latency`, capped at 150 ms: **the player is favoured**.
2. Doors and lasers re-enable with a **0.2 s visual lead**: the 3-flicker telegraph ends exactly when the server window closes, so what you see is never more generous than the server.
3. Plates count a live player as pressing from the server's receipt of their position; the 0.4 s plate grace and the 1.0 s simultaneity window absorb the rest.
4. Remote players' clones are drawn on the same interpolation delay as remote characters, so a friend handing off to their own clone looks in sync on third screens.
5. Gus's detection of live players uses the same latency rewind (≤ 150 ms).
6. All of this is asserted in L2 with latency injection; the human check is §10.3 #5.

### 8.11 Week-1 spikes (go/no-go Wed Nov 18; each decides architecture or art)

| # | Spike | Pass | If it fails |
|---|---|---|---|
| S1 | **Clone phone bench:** a ~50-line client script spawns 12 and 16 stripped rigs (candidates A, B, C of §6.5) on the v0.1 map; owner reads Shift+F2 and the MicroProfiler on their phone | 12 clones ≤ 33 ms on a low Android, ≤ 16.6 ms on mid; clones ≤ 120 draw calls | Mannequin (C) beyond 15 studs or everywhere; cap stays 12 |
| S2 | **Mesh pipeline:** one Blender mesh imported by the owner into `Kit.rbxm`, built by Rojo, cloned by code; size and collision checked; Content-property serialization (switched Nov 11, [DevForum](https://devforum.roblox.com/t/upcoming-changes-to-asset-properties-content-property-serialization-switch/4975546)) survives `rojo build` | Correct size and Box collision in the built place | `CreateMeshPartAsync` at server boot from uploaded mesh ids |
| S3 | **Video capture:** `CaptureService` video on the owner's phone and PC ([reference](https://create.roblox.com/docs/reference/engine/classes/CaptureService.md)) | Records and shares a 12 s reel | SAVE CLIP = screenshot + crop-safe reel for screen recording |
| S4 | **Stem alignment:** `AudioPlayer:Play(atTime)` with 2 stems | No audible drift over 8 loops | Start-together-at-volume-0 fallback (§7.2) |
| S5 | **Open Cloud smoke:** `tests/engine_smoke.luau` via `tools/cloud_test.py` against the test place | **Passed 2026-11-12** (20/20, place version 7). Remaining: confirm `asset:write` and DataStore scopes for S2 and golden recordings | Owner adds scopes (D5); publishing returns HTTP 409 while Collaborative Editing is on or Studio holds the place |
| S6 | **Lighting in the project file:** `default.project.json` sets `LightingStyle`/`PrioritizeLightingQuality` | Built place has the right values | Set them once in a base file; CI check |

### 8.12 Hotfix and rollback

- **Release path:** tag → `rojo build` → test place → L3 → publish live from the same file → release annotation in analytics.
- **Rollback:** revert the live place to the previous version in Creator Hub version history (owner, 2 minutes) or republish the previous tag (Claude via Open Cloud), then a soft shutdown of old servers only for data-schema changes.
- **Kill switches:** LiveFlags (§8.7) for any feature that misbehaves.
- **Content without republishing:** Christmas dressing, gift beat and chapter unlocks are pre-published and **unlocked by server time**, so the Dec 24-27 freeze needs no publish.
- **Freeze windows:** Dec 24-27 and the 24 h before each drop (only hotfixes with a rollback ready).

---
## 9. Virality and launch

### 9.1 What we sell in one second

The heist headline plus the swarm payoff, made true in session 1: **"8 OF ME"** (Clone Party at about minute 8), and with friends **"16 ROBBERS"**. Live context today (rbx_search / games API, 2026-11-12): Criminal Simulator **18,687 playing** (created 2026-10-08; "sneak past residents, outrun the police... sell your loot before the deadline"), Clone Engine **2,503 playing, 417.3M visits** (people love many copies of themselves), ROB IT 1,875, Heist Evolution 1,876, and *ECHOES: Clone Puzzles* **0 playing** (puzzle framing fails). Steal An Egg (472,473 playing) owns the "steal" keyword; we don't chase it.

**Positioning against Rewind Robbers and the jams:** they can't give you **your own Roblox avatar** as the clone, **4 friends × 3 clones = 16 robbers live**, **Gus** as a named character, or a **daily shared vault**. Every store line and trailer leads with those.

**Search:** title "Heist Yourself: Rob With Your Clones"; the first two description lines (§1.1) honestly contain heist, rob, clone, christmas heist and past self. Claude writes the 15-30 player search queries checklist (vault *Experience Description and Search Keywords*) in W3 and checks where we rank each week.

### 9.2 Eight signature clip formats (all readable with the sound off; every clip burns "◀ ME, 20 SEC AGO" on a clone in the first second)

Posting order (most explainable first):

| # | Hook text | What the game or the owner kit generates |
|---|---|---|
| 1 | **RUN 1 vs RUN 8** | Reel "Then/Now" split: one lonely robber vs the full crew |
| 2 | **MY CLONE BETRAYED ME** | Server **blooper log** (cause-tagged failures); the results card's default cut leads with it |
| 3 | **HE DOES IT EVERY TIME** | The blooper log stitches one clone's repeat failure at the same spot into 6 s (Dec 11) |
| 4 | **WRONG ONE** | Gus's 2.0 s "huh?" freeze on a clone while the live player sneaks past, auto-bookmarked |
| 5 | **8 OF ME** | Clone Party haul + Crew Line-up, burned-in caption |
| 6 | **POV: you're the night guard and 16 of the same robber walk in** | Owner kit "Gus cam" director command |
| 7 | **1 ME vs 4 FRIENDS** / **4 FRIENDS, 16 ROBBERS** | Reel angle with the most actors in frame; friend-group voice reactions |
| 8 | **DEV: 4 CLONES. ME: 3** | Diamond medal card (from Jan 8) |

Seasonal: **"STEALING BACK CHRISTMAS WITH 8 OF ME"**. Every zap and bust ends in a bloodless stylised flop (this month's ragdoll wave: 8 of the top 28 new Roblox games, market F4).

**Clip production (the real clip source is the owner kit, not in-game sharing, because TikTok and Roblox Moments are 13+):**
- **1-2 clips a day from Thu Nov 19**, cross-posted to TikTok, YouTube Shorts and Instagram Reels; each reel cut 3 ways (hook text variants).
- A **part-time clip editor** (owner decision; a friend or sibling is fine). Claude produces daily shot lists and director-command scripts; the owner records 20-30 minutes of raw capture twice a week.
- **3-5 friend groups** (16+, or kids with parental consent who don't post themselves) record voice reactions in private servers; we post with permission and no names.
- **Owner kit:** a capture place with the live lighting, a freecam, a "director" command that replays the day's best blooper from the server log, and the Gus cam.

### 9.3 Built-in replay and share

1. **SAVE CLIP:** if spike S3 passed, records the end-of-heist cut with `CaptureService:StartVideoCaptureAsync` when `CanCaptureVideo()` is true; else a screenshot; then Save (`PromptSaveCapturesToGallery`) or Share (`PromptShareCapture`, launch data `v1|reel|<levelId>`). A bonus, not a pillar: device coverage is [UNVERIFIED].
2. Clips fit **Roblox Moments** (≤ 30 s, 13+, [newsroom](https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery)); `UploadCaptureAsync` stays behind a LiveFlag. Share links (`SocialService:PromptLinkSharingAsync`) carry a whitelisted source tag per channel.
3. **Never auto-prompt and never reward sharing or watching** ([DevForum](https://devforum.roblox.com/t/roblox-kids-and-select-new-restrictions-on-reward-driven-media-feeds/4829188)); the only social reward is a referral cosmetic after the invited friend plays 10 minutes.

### 9.4 Icon and thumbnails

- **Icon:** the Rookie's face (no mask) with a smug side-eye, two or three cyan copies fanned behind, Ink Indigo with a vault-door glow, a gold glint, no text; passes greyscale at 64 px. Santa hat from day one (Christmas edition), removed Jan 5.
- **Thumbnails** (real in-game captures, staged in the capture place): T1 **8 OF ME** (hero with gold, 7 clones in a V); T2 **BETRAYED!** (hero in Gus's torchlight, a clone pressing the alarm); T3 **WRONG ONE!** (Gus holding a clone by the collar, hero tiptoeing past with the diamond); T4 **16 ROBBERS**; T5 **STEAL BACK XMAS**. ≤ 3 words in the upper third.
- **Only 2 active until DAU passes 1,000** (personalisation gets little signal below that, growth.md F1): launch with **T5 + T3**; add T1 once SwarmSeen ≥ 60% by minute 10 is confirmed in analytics.
- **Video thumbnail:** first real-footage version from the golden room **by Sun Nov 22** (no narration or lyrics; reviews can take weeks, ≤ 3 uploads a month, [DevForum](https://devforum.roblox.com/t/video-thumbnail-review-taking-weeks/4749618)); replace it with Clone Party footage in December.

### 9.5 The under-16 gate and launch path

**Facts (checked today):** a new game reaches only age-checked 16+ users until it passes the **Kids & Select evaluation** ([docs](https://create.roblox.com/docs/production/publishing/kids-and-select)). The organic threshold is **250 highly engaged plays in 60 days** since Aug 19 ([DevForum](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164)); a November drop to 100 is reported only by third parties [UNVERIFIED]. **Expedited review** costs a **refundable deposit per game, about 48 hours**, restarting if a minor violation needs a fix: the docs and launch post say **100,000 R$**, the vault's reading of the publish page and a DevForum user say **50,000 R$** ([launch post](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717), [refund thread](https://devforum.roblox.com/t/roblox-select-refund-request-for-full-100k/4873550); vault *Publishing an Experience* §3). The owner checks the live amount on Creator Hub; Robux only, no USD ([DevForum](https://devforum.roblox.com/t/a-simpler-path-to-publish-plus-invite-early-testers/4930524)). [estimate] 50k-100k R$ costs about $450-1,000 to buy. One developer reports a review banner stuck for 8+ days ([DevForum](https://devforum.roblox.com/t/17k-ccu-game-stuck-at-16-with-bugged-creator-hub-message-expedited-review-pending-approval-48-hours-for-over-8-days/4913112)), so we keep a backup. **There is no creator switch that keeps a public game out of RFY**; the draft's "RFY excluded / open RFY Dec 11" is removed. The point of no return is going public.

**Path:**
1. **By Mon Nov 16 (owner):** ID/age check, 2SV, the **1,000 R$ refundable publishing fee** (or 2 months of Plus/Premium), the maturity questionnaire (target **Mild**), ad billing (18+ card or ad credits).
2. **Nov 19 - Dec 2: private test place with early-tester invites** (up to 10 friends or group members per place, added Oct 12, 2026; parents can restrict under-16 testing, [GameBusiness.jp](https://www.gamebusiness.jp/article/2026/10/13/28297.html), [DevForum](https://devforum.roblox.com/t/a-simpler-path-to-publish-plus-invite-early-testers/4930524)). Kid waves (§10.3) and the first-session funnel run here. Early testers don't count toward the threshold.
3. **Mon Nov 30 go/no-go** on the first-session bars measured with early testers (§10.2). If go, the owner buys the deposit Robux (D2, by Fri Nov 27 so it's ready).
4. **Thu Dec 3, 15:00 CET: public** on the live place, rated Mild, 16+ trial, and **submit expedited review the same hour** → all ages expected **~Sat Dec 5**. Ads: **$100 Plays** (Dec 3-6, ad-creative concepts only, ad players don't count toward RFY ranking, vault *Discovery and the Algorithm*) and **$300 Engagement** as the backup path to the threshold if review is not funded or stalls ([Ads Manager](https://create.roblox.com/docs/en-us/production/promotion/ads-manager)). ≤ $500 before D1 is known.
5. **Creators and "join now" CTAs wait for the Audience Reach dashboard to show all ages.** Before that: devlogs and teasers drive Favorites, follows and the event RSVP, never joins; early creators are ones whose audience skews 13-17 and older.
6. **Fri Dec 4:** create the "Steal Back Christmas" **Experience Event** for the Dec 11 drop and submit it for featuring (7+ days' lead); RSVP prompt after the first heist (`SocialService:PromptRsvpToEventAsync`). RSVPs are a nice-to-have, not a KPI.
7. **Fallbacks:** if all ages is not cleared by **Wed Dec 9**, raise Engagement spend by $200 and check the review status with support; if not cleared by **Wed Dec 16**, move the creator wave to 48 h after clearance and the finale to **Mon Dec 21**.

**Market context:** **GTA 6 ships Nov 19** ([Khaleej Times](https://www.khaleejtimes.com/business/tech/gta-6-release-date-locked-take-two-ceo-shuts-down-delay-rumours)); it raises heist appetite but pulls Roblox creators' attention in late November, so **creator pitches go out by Mon Nov 23**. **ROB RUN** (free Steam crime sandbox, launched Nov 4, 238,874 CCU on our radar, [Steam](https://store.steampowered.com/app/4262460/ROB_RUN/), market.md F4) will likely spawn Roblox copies crowding "rob/heist" search in December: it joins the daily radar watchlist. No 2026 Roblox winter platform event is announced; apply if one opens.

### 9.6 Creators

- 20 micro (10K-200K) and 10 mid (200K-2M) Roblox duo/funny creators; no macro or drama channels until D1 is proven ([RoWatcher](https://rowatcher.com/news/why-macro-influencers-kill-small-roblox-games-and-what-works-instead)). DM pitches ≤ 150 words with a 15 s vertical clip, sent **by Nov 23**; private servers open **the day after all-ages clearance** (target Dec 6-10); **embargo lifts Fri Dec 11** with drop 1 if cleared at least 48 h before, else 48 h after clearance. Personal share link and a "creator clone" colour. No paid deals until D1 ≥ 22%.
- **Devlog from Nov 16:** "I made a Roblox game where your past self is your teammate", owned music only, at the clip rate in §9.2.

### 9.7 KPIs and kill / double-down rules

Bars anchored to GameAnalytics medians over 500+ Roblox games (**D1 10.3%, D7 1.6%; top 1%: 22.2% and 9.1%**, [GameDevReports summary](https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox)). **Every KPI is split by `JoinSource`** (ad / share link / search / RFY / friend / creator) and read against the Creator Analytics age bands. **Ad-sourced cohorts use bars 4 points lower** [estimate, ad cohorts usually retain worse]; kill and rework rules fire only on **organic** cohorts. The 16+ trial D1 is a floor, not proof: the funnel is re-baselined when the under-16 cohort arrives.

| Metric | Kill / rework | Fix before scaling | Healthy | Double down |
|---|---|---|---|---|
| Join → control (mid phone) | > 20 s | 10-20 s | ≤ 10 s | — |
| First clone seen ≤ 45 s | < 60% | 60-80% | ≥ 85% | — |
| L1 complete / joined | < 50% | 50-70% | ≥ 70% | ≥ 80% |
| **SwarmSeen by minute 10** | < 35% | 35-60% | ≥ 60% | ≥ 75% |
| Bounce < 60 s (H) | > 35% | 20-35% | ≤ 20% | ≤ 12% |
| Median first session | < 5 min | 5-10 | ≥ 12 | ≥ 18 |
| **D1** (organic cohort ≥ 300) | **< 8%** | 8-15% | **15-22%** | **≥ 22%** |
| **D7** | < 1.5% | 1.5-4% | 4-6% | **≥ 6%** |
| Sessions with a friend | < 8% | 8-20% | ≥ 20% | ≥ 30% |
| SAVE CLIP taps / heists | < 1% | 1-4% | ≥ 5% | ≥ 10% |
| Describe it as a "heist" game (playtests) | < 50% | 50-70% | ≥ 70% | — |

- **Double down** (organic D1 ≥ 22%, D7 ≥ 6%, DAU > 1,000 in week 2): scale Plays ads while CPP < $0.02, pay mid creators, pull Museum forward.
- **Rework** (2 organic cohorts under 8% D1): stop spend, fix the first 3 minutes, new thumbnail concepts.
- **Hard stop** (4 weeks under 10% organic D1 and PTR in the bottom quartile): change the framing (title, setting), keep the tech.

Analytics: one server-only module; funnels `onb_v2` and a per-heist funnel; low-cardinality custom events (`CloneFailed{cause}`, `RedoUsed`, `UndoUsed`, `AlarmTripped`, `AlarmEscaped`, `ClipSaveTapped`, `InviteJoined`, `JoinSource`, `QuickCrewJoined`, `TaintedRun{reason}`, `PerfSample{tier}`); a release annotation on every publish.

### 9.8 Live ops: first 10 weeks (drops Fridays 17:00 CET = 11:00 US Eastern, published 24 h earlier and unlocked by server time)

| Week | Dates | Content | Config / ops | Marketing |
|---|---|---|---|---|
| L1 | Thu Dec 3 - Wed Dec 9 | **Launch, Christmas edition:** L1-L6, daily vault/advent, trophies, store; Wrapping Room teased at the van | Expedited review Dec 3; hotfixes only; ads daily; event created Dec 4 | Devlog + teasers (follows, RSVPs); creator servers after clearance |
| L2 | Dec 10-16 | **Fri Dec 11: drop 1 "Wrapping Room"** (2 levels, heavy loot, hand-off), +2 daily vaults, global daily board, blooper stitching | "[🎄]" tag; T5 + T3 | **Embargo lift Dec 11** (if cleared); formats 1, 2, 5 |
| L3 | Dec 17-23 | **Fri Dec 18: finale "The Snow Globe Vault"** (break starts) | Double Cash Sat-Sun; gift beat pre-published Dec 23 | Creator wave 2; format 7 "play with your cousins" |
| L4 | Dec 24-30 | Dec 25-26 gift beat (free Gift-Wrap style, double daily Stars, bundle on the van screen) | **Publish freeze Dec 24-27** | Format 4 and seasonal |
| L5 | Dec 31 - Jan 6 | Advent catch-up closes Dec 31; **event ends Mon Jan 4**; dressing off Tue Jan 5 | Museum teaser thumbnail | Format 1 recap "RUN 1 vs RUN 8 of 2026" |
| L6 | Jan 7-13 | **Fri Jan 8: New Year patch** (Contracts, Diamond, dependency icons, emotes, Danish) + the funnel's top fix | Contract "Lights Out"; Server Authority spike Jan 11-15 | Format 8 |
| L7 | Jan 14-20 | Buffer: fixes, performance by device tier | Contract "Faster Guards" | Community reposts (with permission, no names) |
| L8 | Jan 21-27 | **Fri Jan 22: Museum** (4 levels, Noisemaker, Blueprint) | New event; "MUSEUM HEIST" thumbnail | Formats 2-3 among museum lasers |
| L9 | Jan 28 - Feb 10 | Museum follow-ups; Hub and crew servers integration-tested | Contract "Mirror Map" | Format 6 Gus POV |
| L10 | Feb 11-17 | **Fri Feb 12: co-op update + Season 1** | — | Format 7 headline; a paid mid creator only if D1 ≥ 22% |

The post-holiday cliff is real (the week after Halloween 2026, Murder Mystery 2 fell 84% and Steal a Brainrot 70%, [RoWatcher](https://rowatcher.com/news/roblox-week-in-numbers-2026-w44)); the Jan 8 patch and Jan 22 Museum catch it. Steady state: daily vault, a weekly Contract, a location every 3-4 weeks, a seasonal event every 2-3 months.

---

## 10. Production plan

### 10.1 Who does what, and the owner's time budget

| Claude Code (cloud session) | Owner (Danish, solo) |
|---|---|
| All code via Rojo files; Lune tests; CI; Open Cloud engine tests | **Runs Studio**: fun gate, playtests, screenshots, clips, MicroProfiler readouts, phone bench |
| Level layouts; sim boxes; naive-kid recordings; pulling human-recorded solutions | Clears each level once in Studio (records the golden solution); imports `Kit.rbxm` per kit revision |
| Blender assets through the gates with turntable self-review; budget audits | **Style owner:** 15-minute daily screenshot slot; signs off golden assets, clone look, icon, thumbnails |
| Code-authored animation clips | Reviews clips by screen recording |
| Analytics, blooper log, store copy, creator pitches, shot lists, localization keys | ID check, 2SV, fees, deposit, questionnaire, ads billing, trademark check, Open Cloud key scopes |
| Capture place, director and Gus-cam commands | Records raw capture; posts clips (or the editor does); creator DMs; Experience Event |
| PROJECT_STATE, release checklists, hotfix builds | Recruits kid testers with parental consent; publishes on release tags; music/artist contracts |

**Owner time budget** [estimate, to be confirmed in D4]: W1 ~12 h (fun gate 1 h, spikes 4 h, accounts 2 h, screenshots 2 h, devlog 3 h); W2 ~14 h (kid wave 3 h, bench and ping tests 3 h, solutions 2 h, daily slot 2 h, clips 4 h); W3 ~16 h (kid wave 3 h, outsider tests 4 h, thumbnails 3 h, creator DMs 2 h, clips 4 h); launch week ~15 h; then ~10 h/week. If the owner has less, the clip editor and freelance artist are not optional.

### 10.2 Week-by-week milestones with exit criteria

**W1, Thu Nov 12 - Wed Nov 18: "Prove the fun, spike the unknowns, lock identity" (M0)**
- **Fri Nov 13 (owner):** the test universe and key already work (engine smoke 20/20 on Nov 12); add `asset:write` and DataStore read/write on the test universe to the key for S2 and the golden-solution recordings, and keep Collaborative Editing off on the test place so publishes don't fail with HTTP 409.
- **Mon Nov 16: fun gate.** Owner + 2-3 people play v0.1 for 30 minutes, solo and 2-client (`rojo build -o EchoHeist.rbxlx`), including one round with run length set to 30 s in Config. Question: "did you rewind on your own, and did you laugh?" Name confirmed; ID, 2SV and fee done; handles reserved.
- Claude before the gate: `shared/Rec` (Codec, Sampler, LoopClock, Validator) with L1 specs; CI L0; second selene config; bpy install + turntable pipeline; bench script (S1); Lighting in the project file (S6); stem test place (S4); correct `docs/IDEA_ECHO_HEIST.md`.
- Claude after the gate: start `HeistSim`, `Guards.patrol(t)`, the 3-stage cone, rule changes (END RUN, Undo, caught ends run, caps); golden-room look-dev slice.
- **Exit (Wed Nov 18):** fun gate passed (else: a design fix week, launch slips to Dec 10); S1-S6 decided; LightingStyle and clone candidate chosen; title locked; freelance artist briefed.

**W2, Thu Nov 19 - Wed Nov 25: "The sim and the first four levels" (M1)**
- Claude: clones as server data + pooled `EchoView`; Interact; Divergence; Clone Deck (Redo, Redo from, Undo, Delete busted); run bar; L2 tests incl. naive-kid and latency injection; LevelSpec + layouts; Corner Shop L1-L4; FTUE + Mentor tape + funnel; Gus (rigid rig, pose player, hide spots); heist instances; Christmas dressing hooks.
- Owner: **kid wave 1 (Sat-Sun Nov 21-22)** on the private test place via early-tester invites (5+ kids 10-14, phones, parental consent); video thumbnail v1 by Nov 22; creator pitches by Nov 23; phone bench at 8 and 12 clones; 2-client test at 200 ms simulated ping. Clips 1-2 a day start.
- **Exit:** L1-L4 solvable headless with human solutions; naive-kid tests green; determinism hash stable; in wave 1, 4 of 5 kids reach the first clone **without help** and rewind unprompted, and 3+ call it a heist and say "again"; 0 desyncs in 20 loops; colour-blind audit passes.

**W3, Thu Nov 26 - Wed Dec 2: "Launch scope to store-ready" (M2)**
- Claude: L5 Clone Party and L6 Big Score; Alarm Run; profile slice, medals, Cash, Stars, bag levels, trophies and van shelf; 12 daily vaults (layouts; the owner records solutions); Crew Line-up and end-of-heist cut; results card; SAVE CLIP per S3; HUD v1; SFX and library music; store (3 styles, bundle, van paints) and Receipts; analytics with JoinSource and PerfSample; LiveFlags; Quick Crew and garage lobby; localization keys; Relaxed; L3 on main; kit through the gates.
- Owner: **kid wave 2 (Sat-Sun Nov 28-29)**; 10-20 outsider phone tests via early testers; icon, T3 and T5; questionnaire; ads drafted; deposit Robux bought by Fri Nov 27 (if D2 = yes).
- **Go/no-go Mon Nov 30:** L1-L6 complete and solvable; ≥ 70% of outsiders reach L1Complete; median first bank ≤ 60 s; SwarmSeen ≥ 60% of testers who reach minute 10; no data loss in Play/Stop/Play and server hops; flat memory in a 30-minute 4-client soak; frame budget met on the mid phone. **If no-go: public launch Thu Dec 10** with the Wrapping Room levels inside it; the Dec 18 finale holds.

**W4, Thu Dec 3 - Wed Dec 9: "Launch" (M3)**
- Public Thu Dec 3 15:00 CET; expedited review submitted; hotfixes only; ads daily; event created Dec 4.
- Owner: **kid wave 3 (Sat-Sun Dec 5-6)**, on the live game if all ages is cleared, else on the test place.
- Claude in parallel: drop 1 (Gift Tag, Wrapping Room, heavy loot, conveyor), 2 daily vaults, global daily board, blooper stitching.
- **Exit:** all ages cleared or on the fallback path; organic D1 ≥ 15% on 300+ players; bounce < 60 s ≤ 20%; 0 blocker bugs; frame-time telemetry by device tier reviewed.

**W5-W14 (Dec 10 - Feb 17)** follow §9.8. Build-side exits:
- **W5 (Dec 10-16):** drop 1 live; finale built and passing L2 with a human-recorded solution at par 4-5; crash-free sessions ≥ 99%.
- **W6 (Dec 17-23):** finale live Dec 18; gift beat pre-published and server-time tested; D7 of the Dec 3 cohort ≥ 4%.
- **W7-W8 (Dec 24 - Jan 6):** freeze holds with no rollback; Jan 8 patch green; Museum L2 green.
- **W9-W11 (Jan 7-27):** Jan 8 patch and Jan 22 Museum live; D8-28 return stable after the cliff; Server Authority go/no-go.
- **W12-W14 (Jan 28 - Feb 17):** Hub and crew servers integration-tested and live Feb 12; sessions with a friend ≥ 20%.

### 10.3 Testing gates and what must be human-playtested

Automated gates (every commit: L0-L2; main: L3) block merges. Claude cannot see Studio renders, so these **must** be human-tested:
1. Movement and camera feel (jump timing, zoom, wall fade), on PC and a phone.
2. Clone readability: "which ones are past me?" in under 0.5 s (blind 3-person check on screenshots at 160×90 and 64 px); "is that my avatar?" yes for the near clone.
3. Gus's 3-stage cone and hiding: does getting caught feel fair **to a 10-year-old on a phone**? Tune the Config values on kid waves, not adults.
4. The rewind: satisfying, not tiring, after 20 runs.
5. Co-op sync at 150-250 ms ping: "it was on the plate but the door didn't open" must never happen.
6. Phone performance at 12 clones, and thermals after 15-20 minutes on a low Android and an older iPhone.
7. Late join, leave mid-carry (orphan tapes), Quick Crew vote, Play/Stop/Play data safety, server hop.
8. **Kid waves (Nov 21-22, Nov 28-29, Dec 5-6):** 5+ kids aged 10-14 on phones, never seen it, parental consent, via early-tester invites. **Hard gates:** first clone without help; they call it a "heist", not a "puzzle"; a spontaneous "again!"; the END RUN button is not mis-tapped more than once per heist; "run" vs "try" wording.
9. SAVE CLIP and Share on real iOS and Android devices (if S3 passed).
10. Every golden asset and the icon at 64 px (style-owner sign-off).

### 10.4 Written cut list (decided now, not at the Nov 30 gate)

**Not in the Dec 3 launch:** gadgets (Jan 22), full Blueprint editing (Jan 22), separate advent mini-vault system (merged into the daily vault), procedural daily vaults (after a constraint checker), Free Roam (replaced by Clone Party), Giant Present grips beyond the finale, blooper stitching (Dec 11), global daily board (Dec 11), clone emotes and rewind styles (Jan), Christmas pass (one bundle instead), MessagingService presents meter, Midnight Vault, Danish table (Jan 8), Contracts (Jan 8), dependency icons (Jan 8), Hub/hideouts/crew servers (Feb 12), keycard and heavy-loot levels (Dec 11), Teller Line and Vault 101 levels (dropped; their verbs move into the Dec 11 levels).

**If W3 slips, cut in this order:** SAVE CLIP video (screenshot only) → bag levels → Quick Crew (friends-only co-op) → store cosmetics beyond the bundle → daily vault count 12 → 7 → Clone Party's Alarm Run (keep the 8 slots). **Never cut:** the FTUE fixes, Clone Party's 8 slots, the Crew Line-up, heist instances, the Big Score.

---

## 11. Risk register and decisions

### 11.1 Top risks

| # | Risk | L / I | Mitigation | Trigger |
|---|---|---|---|---|
| 1 | **The core isn't fun** (never played in Studio) | Med / High | Fun gate Nov 16 before any rewrite; kid waves as hard gates | Gate fails → design week, launch Dec 10 |
| 2 | **Schedule** (solo owner, 21 days) | High / High | 6-level scope, written cut list, Dec 10 fallback, owner time budget, editor and artist | Any W1-W2 exit missed |
| 3 | **Owner bottleneck** for every human gate | High / High | 15-min daily slot, batched tests, Claude self-reviews turntables, editor | Owner < 10 h in a week |
| 4 | **Mechanic unreadable** in a 3 s clip or the first 60 s | High / High | Auto-ending L1 run 1, "◀ YOU, 10 SEC AGO" label, glyphs, tape-print spawn | First clone ≤ 45 s for < 80% |
| 5 | **Puzzle-game perception** | Med / High | Alarm Run, Gus chase, heist-first copy, "puzzle" banned | < 70% say "heist" |
| 6 | **Phone cost of 12-16 avatar rigs** | Med-High / High | W1 bench, opaque glow rig, mannequin LOD, cap 12, telemetry | S1 > 33 ms |
| 7 | **Under-16 gate late** (review stuck, deposit not funded) | Med / High | Expedited review Dec 3, Engagement ads backup, dated fallbacks | Not cleared by Dec 9 |
| 8 | **Sim/visual desync, lag unfairness** | Med / High | One Sampler, loop clock, §8.10 rules, latency injection | Any desync report |
| 9 | **Non-determinism creeps back** | High / High | Sim-only Selene std, event-log hash per commit | CI red |
| 10 | **Mesh/Content pipeline breaks** (serialization switch Nov 11) | Med / Med | S2 spike, levels as data, CreateMeshPartAsync fallback | S2 fails |
| 11 | **"Copy of Rewind Robbers"** comments | Med / Med | Lead with avatar clones, 16 robbers, Gus; no originality claim | Comments naming it |
| 12 | **Fast-follow copies** past ~5K CCU | High / Med | Weekly drops, daily vault, saved trophies, owned art | Copy > 1K CCU |
| 13 | **Alarm Run too hard for kids** | Med / Med | Gus at 0.9x speed, decoys, Relaxed, first-heist x2 | Alarm escape rate < 50% |
| 14 | **Heist instance server load** (8 instances per server since 2026-11-12) | Low-Med / Med | ≤ 2 ms sim per instance (measured 0.06 ms mean, 0.29 ms worst per tick on L6 with 16 actors), attributes synced only on sim ticks, 6k instances per level copy, streaming (code ready, flip after the fun gate, §3.3), one new heist per player pick per 5 s | Server heartbeat < 50 Hz |
| 15 | **Christmas cliff** | High / Med | Jan 8 patch, Jan 22 Museum, Feb 12 Season 1 | Week-after-event DAU |
| 16 | **Music/IP in clips; maturity label slip** | Med / High | Owned music off-platform, no-IP list, bloodless flops, re-answer the questionnaire after changes | Takedown; label above Mild |

### 11.2 Decisions needed from the owner (max 10, each with a recommended default)

| # | Decision | **Recommended default** | Needed by |
|---|---|---|---|
| D1 | Store title, and run the trademark knock-out search (EUIPO/USPTO cl. 9/41) | **"Heist Yourself: Rob With Your Clones"**; owner runs the free knock-out search this week | Mon Nov 16 |
| D2 | Fund **expedited Kids & Select review** (refundable 50,000-100,000 R$, ≈ $450-1,000 of Robux) | **Yes**, buy by Fri Nov 27, submit at public launch Dec 3 if the Nov 30 gate passes | Fri Nov 27 |
| D3 | Launch scope and date: 6 levels on Thu Dec 3 (gate Nov 30, fallback Thu Dec 10), with the cut list in §10.4 | **Yes** | Mon Nov 16 |
| D4 | Weekly time commitment: ~12-16 h/week to Dec 18 (fun gate Nov 16, daily 15-min screenshot slot, 3 kid waves, golden-solution recordings) | **Yes**; if not possible, D7 and D8 become mandatory | Fri Nov 13 |
| D5 | Add `asset:write` and DataStore read/write to the existing Open Cloud key (test universe only), and keep Collaborative Editing off on the test place | **Yes**, scoped to the test universe only; a separate live-place key comes later for release publishing | Fri Nov 13 |
| D6 | Paid spend before D1 is known | **≤ $500**: $100 Plays test + $300 Engagement backup + $100 reserve | Mon Nov 16 |
| D7 | Freelance environment artist for the 5 golden assets | **Yes, $300-600**, original work with written rights assignment, briefed by Nov 18 | Wed Nov 18 |
| D8 | Part-time clip editor (or a friend/sibling) so we can post 1-2 clips a day | **Yes**, from Nov 19 [cost UNVERIFIED; a helper is fine] | Thu Nov 19 |
| D9 | Recruit 5+ kids aged 10-14 with parental consent for 3 waves (Nov 21-22, Nov 28-29, Dec 5-6) | **Yes**, through your network or a Danish school/club; consent form provided by Claude | Wed Nov 18 |
| D10 | Music: commission 2 stemmed tracks with trailer rights, or library-only | **Library in-game + platform-licensed sounds for TikTok**; commission only if delivery by Dec 9 is guaranteed | Fri Nov 20 |

Design rules that the draft had as owner decisions are now settled in the design: guard timings (Config, tuned on kid waves), leaver clones (orphan tapes), cap 12 → 16 (automatic if S1 passes on a low Android), Moon Base (decided after the Museum's D7), and the +1 slot pass (dropped).

---
## Appendix A. Addressed critiques

Three independent critiques reviewed the draft: **P** = player and fun (10-14 on a phone, day 7), **F** = feasibility and tech, **M** = market and virality. Verdicts: **Accepted** (applied as proposed), **Accepted, changed** (applied in a different form, reason given), **Partly rejected** (reason given). Every blocker and major is listed; minors are listed too.

### A.1 Player and fun (P)

| # | Sev. | Issue | Verdict | Where / how |
|---|---|---|---|---|
| P1 | Blocker | FTUE logic broken: run 1 records "step on, step off", so the clone never holds the door | **Accepted** | §7.5: REWIND pulses only while on the plate, "Stay on it. Tap REWIND.", L1 run 1 auto-ends after 2.0 s on the plate; "your clone stops where you stop" taught explicitly; naive-kid L2 tests (§8.9) |
| P2 | Blocker | "8 OF ME" unreachable for new players | **Accepted** | §4.2 L5 Clone Party grants 8 slots with unlimited loot (~minute 8); Big Scores and finale grant 8; owned-slot progression removed (§3.2 #7); scripted Crew Line-up every heist (§3.2 #8) and in the lobby (§6.6); SwarmSeen funnel step |
| P3 | Major | No tension, chase or consequence | **Accepted, changed** | §3.6 Alarm Run in Clone Party, every Big Score and the finale; soft Dawn from L4 (§3.1). **Not** in L1-L3: the FTUE must stay calm and readable; from the Museum on, most levels get an alarm |
| P4 | Major | Stranger co-op chaos, cap re-split, leavers | **Accepted, changed** | §3.3: per-party heist instances **inside** the public server instead of reserved-server teleports (a teleport would add a loading screen before the first clone); opt-in Quick Crew with a wipe vote; caps locked at heist start; late joiners seat at the next heist; orphan tapes + Eject |
| P5 | Major | Phone control overload; tap/hold mis-tap | **Accepted** | §3.1, §3.4, §7.4: one meaning per button, END RUN locked 1.5 s and placed away from jump, Undo last run in the Deck, verbs visible only in context and unlocked when taught |
| P6 | Major | Day-7 hooks favour optimisers | **Accepted** | §5.1-5.3: trophies and advent ornaments in the van (visible in the lobby), Clone Party personal-best haul and bag levels, "biggest haul today" board, Diamond = fewest clones for the hardcore |
| P7 | Major | Boring co-op spectator wait | **Accepted** | §3.1 waiting squeeze (10 s once half the crew ended), co-op fast-forward when all live players stand still; §3.3 spectators drop markers, ping, fly the planning camera; busted-cam for caught players |
| P8 | Major | Retake cascades | **Accepted, changed** | §3.2 #6: Redo from #N, Delete busted, ghost-of-the-ghost path with footprints, on-time strip at launch; **dependency icons deferred to Jan 8** (needs event-log analysis; scope) |
| P9 | Major | 0.35 s grace too harsh for kids | **Accepted** | §3.1: 3-stage cone (amber, "?" 0.6 s, "!" 1.2 s), hiding spots, first heist x2, Relaxed offered after 3 busts; tuned on kid waves (§10.3 #3) |
| P10 | Major | Soft-launch metrics measure 16+ only | **Accepted** | §10.3 #8 three kid waves as hard gates via early-tester invites; §9.7 16+ D1 is a floor, re-baseline with the under-16 cohort |
| P11 | Minor | Clips need clean play; kids can't post | **Accepted** | §6.6 blooper + win default cut with Crew Line-up; §9.2 the owner kit is the main clip source; creators over in-game sharing |
| P12 | Minor | Christmas finale too long and precise | **Accepted** | §4.3: finale par 4-5 with 8 slots granted, Giant Present 2 grips required (faster with 4); §3.3 Helper mode for cousins |
| — | Missing items | naive-kid path; tension; 8 OF ME; collection; join/leave rules; spectators; phone layout; "where you stop" show step; kid gates; replay value; session length | **All added** | §7.5 + §8.9; §3.6; §4.2; §5.1; §3.3; §3.1/§3.3; §3.4; §7.5; §10.3; §5.3 (daily rotation with modifiers, Clone Party); §4.2 session-length estimate |

### A.2 Feasibility and tech (F)

| # | Sev. | Issue | Verdict | Where / how |
|---|---|---|---|---|
| F1 | Blocker | Schedule not credible | **Accepted** (option A + Christmas dressing, with option B as the fallback date) | §4.2 six levels; §10.4 written cut list and cut order; Dec 10 fallback; §10.1 owner time budget |
| F2 | Blocker | Rewrite starts before the fun is proven | **Accepted** | §10.2 W1: fun gate Mon Nov 16; only `shared/Rec` before it; loop length tested on v0.1 via Config |
| F3 | Major | Soft-lighting kill switch impossible | **Accepted** | §6.3: style chosen once from phone screenshots, Lighting in `default.project.json` (spike S6), runtime tier from scriptable controls only; C14 |
| F4 | Major | Clone render cost measured too late | **Accepted** | §8.11 S1 bench in W1 with three candidates (translucent, opaque glow, mannequin); §6.5; clone draw-call sub-budget in §6.8 |
| F5 | Major | File-authored MeshParts collide with MeshPart/Content internals | **Accepted, changed** | §6.7/§8.5: levels as data; **primary** is an owner-imported `Kit.rbxm` that code only clones (simplest and gets InitialSize and collision right); `CreateMeshPartAsync` at server boot is the fallback; spike S2 |
| F6 | Major | No animation pipeline | **Accepted** | §6.7: rigid-part Gus, procedural fail states, 3 code-authored clips via a client pose player, owner review by screen recording, emotes only from catalog/post-launch |
| F7 | Major | No lag-fairness model | **Accepted** | §8.10 six rules; latency injection in L2 (§8.9) |
| F8 | Major | Solvability tests prove logic, not playability | **Accepted** | §8.9: human-recorded golden solutions via `_TEST` DataStore + Open Cloud; sim boxes generated from the layout with a LevelSpec assert |
| F9 | Major | Procedural daily vaults are a research problem | **Accepted** | §5.3: 12 (then 14) hand-authored daily vaults with human solutions, date-seeded modifiers only; generation after a constraint checker (§1.3) |
| F10 | Major | Two sources of the place file | **Accepted** | §8.5 "one source of the place"; art place; `servePlaceIds` dev only; CI Lighting check |
| F11 | Major | Open Cloud path not set up; D6 too late | **Accepted; partly resolved since the critique** | The test universe and key now work: engine smoke passed 20/20 on Nov 12 (§8.11 S5). Remaining scopes are D5 by Fri Nov 13; one batched L3 task per merge |
| F12 | Major | Blender throughput, no rework budget | **Accepted** | §6.7: install bpy, turntable self-review, kit cut to ~12 modules + 3 hero props, daily 15-min slot, $300-600 freelance golden assets (D7) |
| F13 | Minor | Skip-ahead breaks the client time model | **Accepted** | §8.2 loop clock `{anchorServerTime, anchorLoopT, rate}`; fast-forward equivalence test |
| F14 | Minor | Client rig building unverified, AJU joints | **Accepted** | §6.5 #1 server-built template, client pool, mannequin placeholder, both joint types |
| F15 | Minor | Over-promised tooling | **Accepted** | §8.4 second Selene std + grep + hash test; §6.7 Clip/Blend1D only; S3/S4 spikes before SAVE CLIP and Crew Layers |
| — | Missing items | spike list; animation pipeline; lag spec; human golden solutions; client regression; memory/pooling; owner time; Lighting location; rollback/hotfix; frame-time telemetry at launch | **All added** | §8.11; §6.7; §8.10; §8.9; §8.9; §6.8 + §8.5; §10.1; §6.3 + §8.5; §8.12; §8.6 |
| — | Option A "no video capture" and "one clone style" | **Partly rejected** | Video capture ships **only if** S3 passes in W1 (it is a small amount of code when the API works); the store has 3 clone styles because they are code-only colour/material presets (hours, not days) and give the store something at launch |

### A.3 Market and virality (M)

| # | Sev. | Issue | Verdict | Where / how |
|---|---|---|---|---|
| M1 | Blocker | Gate plan ignores expedited review; stale threshold | **Accepted** | §9.5: expedited review submitted at public launch Dec 3, deposit decision D2, threshold "250 official, 100 reported [UNVERIFIED], dashboard is truth", Engagement ads as backup, dated fallbacks |
| M2 | Blocker | Schedule for a 10-person studio | **Accepted** | (a) launch is the Christmas edition on one kit + dressing layer (§4.3); (b) 6 levels; (c) daily vault = advent; (d) Midnight Vault, presents meter and pass dropped, one bundle; (e) finale Fri Dec 18; (f) Museum Jan 22, Hub Feb 12; (g) gate: fun gate Nov 16 (owner + 2-3 people) and kid wave 1 Nov 21-22 instead of "3 outside testers by Nov 18", slip to Dec 10 if it fails |
| M3 | Major | "RFY excluded" and "open RFY Dec 11" don't exist | **Accepted** | §9.5: removed; private early-tester phase before public; going public is the point of no return, gated on first-session bars; Dec 11 = drop + embargo lift |
| M4 | Major | Tape/take motif belongs to Rewind Robbers | **Accepted** | §2.2 tape as dressing only, no originality claim; "run" in UI (C2); store line one rewritten (§1.1); positioning in §9.1 |
| M5 | Major | Hero promise vs first session | **Accepted** | Same fix as P2; SwarmSeen ≥ 60% by minute 10; T1 thumbnail only after SwarmSeen is confirmed (§9.4) |
| M6 | Major | Marketing timeline ignores the gate | **Accepted** | §9.5 #5 and §9.6: embargo and every "join now" CTA tied to all-ages clearance; pre-clearance content drives follows and RSVPs |
| M7 | Major | Clip production underpowered | **Accepted** | §9.2: 1-2 clips a day from Nov 19, 3 platforms, 3 cuts each, part-time editor (D8), "◀ ME, 20 SEC AGO" label, explainable formats first, Gus POV and friends formats, friend-group voice reactions, SAVE CLIP as a bonus |
| M8 | Minor | Name risks brainrot adjacency | **Accepted** | §2.1 "Heist Yourself: Rob With Your Clones" (D1) |
| M9 | Minor | Holiday behaviour ignored | **Accepted** | §4.3 finale Dec 18, Dec 25-26 gift beat, RSVPs not a KPI |
| M10 | Minor | Bars measured on the wrong cohort | **Accepted** | §9.7 JoinSource split, ad bars 4 points lower, kill rules on organic only; §9.4 two thumbnails until 1,000 DAU |
| M11 | Minor | Kid tests impossible in the 16+ trial | **Accepted** | §9.5 #2 and §10.3 #8 early-tester invites on the private test place |
| M12 | Minor | Thin market context (GTA 6, ROB RUN, keywords) | **Accepted** | §9.5 market context: pitches by Nov 23, ROB RUN on the radar, keyword checklist (§9.1) |
| M13 | Minor | Video thumbnail too late | **Accepted** | §9.4 first version by Sun Nov 22 |
| — | Missing items | expedited review; threshold drop; early testers; Rewind Robbers overlap; swarm moment; gate-aware creator timeline; clip staffing; Christmas-edition scope; Dec 25-26 beat; search queries; invite prompts at "need 2"; KPI split; fallback if not cleared by Dec 18 | **All added** | §9.5; §9.5; §9.5 + §10.3; §2.2 + §9.1; §4.2; §9.6; §9.2; §4.3; §4.3; §9.1; §3.3; §9.7; §9.5 #7 (dated Dec 9 and Dec 16 fallbacks) |

### A.4 Changes against the draft, in short

Title, "run" wording, owned slots, hold-to-scrap, all-player co-op servers, "no fail state" in story heists, 8-level launch, Free Roam, 12 advent vaults, presents meter, Christmas pass, Midnight Vault, Lighting kill switch, file-authored MeshPart levels, hand-written golden solutions, "RFY off/on", Museum Jan 8 and Hub Jan 22 were all changed as above. Unchanged: the server-authoritative sim with clones as data, the 20 Hz recording format, the palette and Neon-Noir look, the rewind sequence, the medal structure, the monetization rules and the location ladder.
