# Cognitive walkthrough: a new 10-year-old on a phone (sim path)

_2026-11-12. Read-only audit of the live sim path (`Config.GAME_MODE = "sim"`). Sources: CLAUDE.md, PROJECT_STATE.md, MASTERPLAN §3, §7 (esp. §7.4, §7.5) and §10.3. The trace comes from the code: `src/server/Heist/*`, `src/client/Heist/*` (HeistClient, Hud, Ui, EchoView, GusView, WorldView, RewindDirector, LineupDirector), `src/shared/Levels/*`, `src/shared/Heist/Protocol.luau`, `src/shared/Sim/*` and `src/shared/Config.luau`. I did not playtest it. Anything about camera framing, readability or feel is marked **[verify on device]**._

Persona: "Mia", 10. She is on a mid-range Android phone in landscape and has never seen the game. She doesn't read long text, taps whatever glows, knows what a "guard" is, half-knows "dawn", and doesn't know what a "tape" is.

The four questions at every step:
- **(a)** Does she know what to do?
- **(b)** Does she know why?
- **(c)** Does she know what just happened?
- **(d)** Does she know what the clones are, and that they are her?

---

## 0. Summary

The L1 FTUE is close to §7.5 in the happy path. First clone arrives about 8 s after control and first bank about 18 s after control. The clone walks out of her with "◀ YOU, 10 SEC AGO". Everything after L1 relies on her inferring things. Specifically:

- **L1 itself has a real bug.** Doing what the text says ("Stay on it. Tap END RUN.") leaves the tutorial auto-end armed. Run 2 then says "Step on the plate" while her clone is already on it. This also costs the CREW star.
- **No stuck help exists after L1.** There is no Ghost Hint, no Mentor and no Relaxed offer. The only help is that the level line comes back after 2 runs without a bank.
- **L2 never asks her to tap END RUN.** It then tells her "Grab the loot" while what she actually needs is a second plate clone. With cap 4 and no Dawn, a kid who makes 3 junk clones is soft-locked unless she discovers DELETE.
- **Play order puts the Clone Party (with a chasing Gus) before L4 teaches Gus.** The first-heist detection grace is used up on L1, which has no guard.
- **L6's four-plate vault is explained by one line:** "The vault. Every clone counts."
- **The daily vault opens right after L1.** It can contain Gus, lasers or need-all plates, with only "Grab the loot".
- **Jargon:** "END RUN", "RUN n", "tape", "Dawn", "HAUL/CREW/CLEAN", "REDO + LATER", "SHUTTER", "Finish the run".
- **Phone layout:** the top HUD row is 796 design px wide on a 720 design px canvas. On most phones (where width is the binding dimension) the three top boxes overlap.

---

## 1. Timeline table (happy path, then where it branches)

Times are approximate, from tapping Play. "Control" means the character can move. The sim facts behind each row are cited in §2.

| t (from join) | What Mia sees (exact strings) | World / camera | Hears | Must infer | a / b / c / d |
|---|---|---|---|---|---|
| 0:00-0:03 | Roblox loading screen | — | — | — | — |
| ~0:03 | Card, centre, gold 28 px: **"The van door opens..."** | Spawns at `GarageSpawn` in the grey garage lobby: 4 white van blocks and shelves, no labels. She can walk around | **Silence** (no music or ambience in `preparing`) | That she's waiting, not stuck | a ✗ (nothing to do, no spinner) |
| 0:03-0:14 | Same card for 1-11 s (`DATA_WAIT_SECONDS` 4 + `FLAGS_WAIT_SECONDS` 3 + `KIT_WAIT_SECONDS` 4 on a cold server) | Same | Silence | — | Risk to the ≤30 s / ≤45 s gates if counted from join |
| ~0:08 | HUD appears: top centre **"RUN 1"** + **"0:30"** + run bar; top left **"$0 / $100"**; top right an empty dark clone strip; right edge **"◀◀ END RUN"** (dimmed, grey lock ring); **"❚❚"** chip; objective **"Step on the plate"**. Big white stamp **"RUN 1"** | Hard teleport 3,000 studs into L1. Anchored 1.0 s at the van door, facing the shop front wall (8-stud doorway). The plate (10,-8) is inside the shop, off to the right. No establishing shot, no wall fade (§3.5 not built) | RunStamp; Caper music starts; room ambience | Where the plate is. It's a steel 4×4 pad with a 1.2-stud white neon square, **not glowing** (§7.5 wants it glowing) | a ~ (text yes, plate maybe off-screen **[verify on device]**), b ✗ (cash not visible: no glass, door shut) |
| ~0:09 | END RUN lock ring drains (1.5 s) | Control returns | — | — | — |
| ~0:09-0:13 | Unchanged | She walks in. The plate's dark cable runs to the back-room door | Footsteps | That the cable means plate → door | a ✓ |
| ~0:13 | Objective **"Stay on it. Tap END RUN."**; END RUN flashes white about 1.5 times a second | Plate sinks; rim + cable turn cyan neon; glyph **"●"** above the plate; back door slides up | PlatePress, CableWhum, DoorOpen | That END RUN won't quit the game | a ✓, b ✗ ("END RUN" sounds like giving up) |
| 0:13-0:15 | (8-24 s stuck hints only if she's off the plate) | — | — | — | — |
| **~0:15** | Run ends by itself after 2.0 s on the plate. END RUN vanishes, the timer freezes, the strip shows **"●1"**. 0.4 s with no message | World frozen | — | Why it ended. Nothing on the plate showed a 2-s countdown | **c ✗** (looks like a failure) |
| 0:15.4-0:16.4 | Quick rewind (1.0 s): white flash, cyan grade, VHS bands, **"◀◀"** top left, stamp **"RUN 2"** | No path reel in Quick | Tape-stop dive, whirr, (RewindStinger: **no sound id yet**), clunk, 1-note arpeggio | That time went back | c ~ (VHS reads as "rewind" to adults; the word REWIND never appears) |
| ~0:17 | Clone fades in 0.5 s after control, with a print ring, out of **her own spawn spot**. Label over it: **"◀ YOU, 10 SEC AGO"**. Objective **"Wait for your clone to open the door"** | Cyan-tinted copy of her avatar, badge **"●1"**, walks her exact path | Clone chime / arpeggio | — | **d ✓** (best moment in the game) |
| ~0:17 | If she stands still: pill **"⏩ HOLD"** appears on the left (unexplained, §3.4 says L3) | — | — | What ⏩ HOLD is | a ✗ (distracting) |
| ~0:21 | Objective **"Your clone stops where you stop."** (4 s) | Clone stands on the plate, door opens, ● glyph over the plate | PlatePress, DoorOpen | — | b ✓ (the core rule, said once) |
| ~0:23 | Objective **"Grab the cash"**; near the cash, a big gold **"GRAB $100"** button lower right | Cash spins on a dark stand in the back room | — | — | a ✓ |
| ~0:24 | Objective **"Bank it at the van"** | Cash floats over her head; the 3 chevrons on the white van pad pulse | Grab | Where "the van" is. It's behind the spawn; no trail from the back room | a ~ |
| **~0:26** | Toast **"+$100"**; meter counts up to **"$100 / $100"**; big gold stamp **"HEIST COMPLETE"** | Run ends at once (L1 haul = goal) | Ka-ching, coins, count ticks, fanfare | — | c ✓ |
| ~0:27-0:33 | Line-up cut: HUD hidden, caption **"RUN 2 · $100"**, **"◀ ME, 10 SEC AGO"** on the clone, chip **"SKIP ▶▶"** | Camera eases to a low street shot. Mia and her clone walk to a row, turn, cheer, hop | Music resolve | "RUN 2" here means "it took 2 runs" | d ✓ |
| ~0:33 | Results: **"HEIST COMPLETE"**, **"$100 / $100"**, stamps **"★ HAUL" "★ CREW" "★ CLEAN"** (0.25 s apart), **"1 clone · 2 runs · 0:14"**, award line e.g. **"NEW: CLEAN, CREW, HAUL · +3 ★ · NEW TAPE UNLOCKED · +$200"**; buttons **REPLAY / NEXT ▶ / GARAGE** | Held street shot | Results music | What HAUL / CREW / CLEAN mean; what "tape" means; what +$200 Cash is for (no store in the UI) | a ✓ (NEXT glows), b ✗ for stars |
| 0:33-1:18 | If she taps nothing for 45 s (`RESULTS_SECONDS`): back to the garage | Teleport to the lobby | Garage music | — | — |

§7.5 gates for this kid: the first clone arrives at ~8 s after control and ~16 s after join, which passes ≤30 s. The first bank arrives at ~18 s after control and ~26 s after join, which passes ≤45 s. A cold server adds up to 11 s of "The van door opens...". A kid who misses the plate gets the hint ring at 8 s, the beam at 16 s and the Mentor at 24 s, then the tape runs out at 30 s. That pushes the plate clone past 30 s and the bank past 45 s.

**Word budget (≤30):** the L1 objective lines alone are 4 + 6 + 8 + 6 + 3 + 5 = **32 words**. With the button, stamps, label and GRAB, it's about 50. The two lines the code added to §7.5's table are "Wait for your clone to open the door" (8) and "Grab the cash" (3).

---

## 2. Level by level

### 2.0 Join → "preparing" → (garage)

- `HeistService.onPlayerAdded` marks every joiner `preparing`, waits for data, flags and the kit, then calls `tryFtueStart` for a new account. Until then the client shows only "The van door opens..." (`Hud.luau` 565-584) over the live garage. `HeistClient.handle("Sync", where="preparing")` starts no music and no ambience.
- Returning players see the same card for up to ~7 s, then the garage.
- **(a)** Nothing to do. **(b/c)** No progress cue. If the server is full, the FTUE retries every 10 s for up to 6 tries, and the garage is shown in the meantime (`retryFtue`). The only text she'd get then is the toast "All the vans are out. Try again in a minute."

### 2.1 L1 "Back Room" (FTUE). Happy path in §1. What else can happen:

| She does... | Code path | What she sees | Verdict |
|---|---|---|---|
| **Taps END RUN on the plate, as the line tells her** | `HeistSim.liveIntents` handles `endRequested` (`HeistSim.luau` 612-615) **before** the auto-end block (838-857). So `a.autoEnded` stays false and `slot.auto` isn't set (729-740). `startRun` re-arms the auto-end because no slot has `auto` (282-301) | Run 2: her clone walks to the plate and opens the door. But the objective is sticky **"Step on the plate"**, END RUN is dimmed, and the hint ring, beam and Mentor (8/16/24 s) all point at the plate her clone is standing on. If she obeys, she stands on it for 2 s and gets auto-ended again. Run 3 makes 2 clones, which is over par 1, so **she loses the CREW star** | **P0/P1 bug.** Following the instruction is punished. There's no test for it: `tests/sim/Lifecycle.spec.luau` only covers END RUN *off* the plate |
| Taps END RUN at once (in the first 1.5 s) | `Hud` endBtn → `actions.endRun` plays **RewindClack** locally (`HeistClient.luau` 114-117); the sim refuses it | The tape-deck clack plays but nothing happens | P2: false feedback |
| Taps END RUN off the plate (after 1.5 s) | Run ends; clone 1 stands wherever she was; auto-end re-arms | Run 2: "◀ YOU, 10 SEC AGO" on a clone standing by the van; "Step on the plate" | OK (the §7.5 recovery works) |
| Ignores the plate | Hints at 8 s (breathing cyan ring), 16 s (white beam from her feet), 24 s (white Mentor mannequin walking spawn → plate). At 30 s, timeout | At timeout the event sets the spectate line "The tape ran out." but `onRunEnd` clears it in the same frame (`Hud.luau` 1743), so she never sees it. TapeStop sound, then rewind | (c) ✗: no visible reason |
| Never presses anything | Same as above every run; cap 3, then the newest slot is replaced | — | Not stuck; slow |
| Walks off the street edge | Floor = level bounds; beyond it is void. She falls 25 studs, then `placeCharacter` puts her back | No message | P2 |
| ❚❚ → "Leave this heist?" → **BACK TO GARAGE** | Solo heist destroyed; garage shows tape 1 only (others say "CLEAR BACK ROOM"); daily hidden | No warning that her clones will be lost; the FTUE doesn't auto-restart | P2 |
| Leaves the game | `removeMember`; nothing saved mid-heist. On rejoin, `isNewAccount` is still true, so L1 auto-starts again | — | OK |

### 2.2 Garage (after L1, or GARAGE / 45 s timeout)

Strings:
- Title "PICK A TAPE".
- Tapes (2×3 grid, play order): "1  BACK ROOM\n30 SEC RUNS\n★★★", "2  TWO DOORS\n30 SEC RUNS\n☆☆☆", "3  CLONE PARTY\nPARTY · 8 CLONES\nCLEAR TWO DOORS", "4  LIGHTS OUT\n…\nCLEAR TWO DOORS", "5  NIGHT CLERK\n…\nCLEAR LIGHTS OUT", "6  THE BIG SCORE: BANK\n…\nCLEAR NIGHT CLERK".
- Gold-bordered card "DAILY VAULT · NOV 12" + vault name + e.g. "FAST GUS · new in 11h", with **"PLAY"** (gold), and "CATCH UP (n)" in the advent window. Sleigh bells play once per visit in the advent.
- Crew box: "CREW", "● Mia (leader)", and "JOIN <friend>" if a friend is present.

The panel can't be closed and covers the screen.

- (a) ✓ (tap a tape). (b) "tape" and "30 SEC RUNS" are jargon.
- The gold daily card is the most eye-catching thing and is unlocked right after L1 (`dailyOpenFor`, `HeistService.luau` 390). See §2.8.
- L6's lock only says "CLEAR NIGHT CLERK". The 6-★ requirement shows only after Night Clerk is cleared.

### 2.3 L2 "Two Doors" (tape 2, via NEXT)

Setup: plate A (-10,-8) opens the back room; plate B (10,-8) opens the stockroom behind it. Safe $200 at (0,-40); tip jar $10 by the counter. Goal 200, haul 210, cap 4, **no Dawn**, deck unlocked.

| Step | Strings / world | a / b / c / d |
|---|---|---|
| Run 1 intro | Stamp "RUN 1"; objective **"Two plates. You need two clones."** for 6 s only (`OBJECTIVE_SECONDS`), then blank | a ✗: L1 never had her *tap* END RUN (the auto-end did it). Nothing pulses END RUN here; plates have **no A/B letters** |
| On a plate | Door rises, cable lights. No line, no END RUN pulse | a ✗ |
| Taps END RUN | Instant freeze; **Clone Deck** slides up (620×212, covers about 2/3 of a phone): "CLONES 1/4 · tap a card to redo it", card "●1\nNEW", **"UNDO"**, **"▶ RUN 2 · 0:25"** counting down | c ✗: no rewind yet (it plays only after ▶ RUN 2). "UNDO" is the only action button. One tap silently deletes the clone she just made |
| ▶ RUN 2 | Standard rewind (1.8 s, paths reel back, FOV 70→64→70), stamp "RUN 2" | c ✓ |
| Run 2 | Clone ●1 walks to its plate. **No "◀ YOU" label** after L1 (`EchoView.luau` 319: tutorial only; `CLONE_LABEL_SECONDS` is unused). Objective **"Grab the loot"** for 6 s (`Hud.luau` 2067) | a ✗: actively wrong. She needs a second plate clone. The tip jar lets her obey and bank $10 ("+$10"), which resets `noBankRuns`, so the level line never comes back |
| Run 3 (ideal) | Both doors open → "GRAB $200" → "Bank it at the van" → toast **"Goal banked! Finish the run."** → objective flips back to "Grab the loot" | a ✗: "Finish the run" means tap END RUN or wait up to 30 s. If Gus were here a catch would cost CLEAN |
| Wrong: 3 junk clones | Cap 4: every later run **replaces the newest slot** (`Deck.luau` 56-66) with no message. So at most one useful clone, and two are needed | **P0 soft lock** (no Dawn, no Ghost Hint). The only way out is discovering DELETE or "REDO + LATER" |
| Wrong: never presses END RUN | 30 s runs; clones still form; "The tape ran out." is wiped at once | Slow; (c) ✗ |
| Stands still | "⏩ HOLD" appears, unexplained | P2 |

### 2.4 L5 "Clone Party" (third in play order)

Strings and events:
- Top label "RUN 1/8"; the stamp still says "RUN 1".
- Objective **"Rob it all. Bank it before Dawn."** for 6 s.
- Meter "$0 / $1,000 ★1".
- GRAB "GRAB $15" / "$25" / "$40". The till shows the billboard "LOCKED 0:20" and the button "LOCKED 0:07" in grey. An early tap gives the toast "Locked: opens in 0:07" and an error sound.
- At 0:20 she can rob the till. That fires the big gold stamp **"GETAWAY!"**, the toast "Till alarm: everyone to the van!", the red pill **"◎ VAN LEAVES 0:20 · SHUTTER 0:06"**, rotating beacons, the alarm bell and the chase music.
- **Gus wakes and chases the nearest actor.** This is her first Gus ever, with no name tag and no intro. Contact means "BUSTED".
- Between runs: no deck. The right edge shows "▶ RUN 2/8 · 0:10"; objective **"Every clone stays for the party: 1"**.
- Toasts "☾ Dawn after 1 more run" and "☾ Last run before Dawn!"; label "LAST RUN" in amber.
- Run 8: stamp **"8 OF ME"** (if she made a clone every run).
- End: stamp "☾ DAWN" in amber, Line-up "RUN 8 · 8 OF ME · $1,234", results "PARTY OVER · ★1" with tier stamps "★ $1,000 / ☆ $2,500 / ☆ $5,000".

Assessment:
- (a) ✓: grab and bank is easy and fun.
- (b) "Dawn" and "SHUTTER" are jargon. The till lock makes sense from the countdown.
- (c) Gus's chase and catch come with no prior lesson. The first-heist ×2 grace is already used up (§3 P1-6).
- (d) ✓: seven copies of her avatar, badges ●1-●7.
- If she shelters inside after the till, the shutter drops at about 0:26 and the run times out with no message.

### 2.5 L3 "Lights Out"

- Objective **"Plate B turns the lasers off."** (6 s). There's **no letter on any plate** (`LevelBuilder.luau` 200-229), so "B" means nothing. She has to follow the cable from the plate inside the back room to the grid.
- Walking into a live grid: "ZAPPED" stamp, red flash, the spectate line "Zapped by a laser." (wiped at once in solo), caption "[Zapped]". The deck card reads "ZAPPED"; the button **"DELETE BUSTED ✕"** appears (it also deletes zapped clones, which the label doesn't say).
- A clone that walked the grid while it was off but is now early or late bubbles "ZAP!". Lasers coming back flicker 3 times with the caption "[Lasers back on]".
- "Teaches fast-forward": nothing explains "⏩ HOLD".
- Same junk-clone soft lock as L2 (cap 4, no Dawn).

### 2.6 L4 "Night Clerk"

- Objective **"Hide from Gus. Cross while he looks away."** (6 s). Label "RUN 1/6".
- Gus: amber floor cone. His head shows "?" at 0.6 s with a GusHuh sound and the caption "[Guard suspicious]", and "!" at 1.2 s. Then "BUSTED" stamp, red flash, brass "wah-wah", and the spectate line "[Guard spotted you]", which `onRunEnd` wipes at once in solo. The busted-cam (§3.1/§7.3) isn't built. The heartbeat and Gus footsteps have **no sound ids**.
- Hiding: walking into the coat rack or crate shows "◐ HIDDEN" and dark screen edges. Nothing marks hide spots beforehand. Plate B is *under* the coat rack, so she has to find that by accident.
- The first-heist ×2 grace doesn't apply: `firstHeistDone` was set by L1 (`Progress.luau` 309; `HeistService.luau` 761).
- After 3 busts there's **no Relaxed offer** (no client code).
- Dawn at run 6: toast "☾ Dawn after 1 more run", label "LAST RUN", stamp "☾ DAWN". The results title is **"DAWN"** in amber, "$10 / $200", "☆ HAUL ☆ CREW ☆ CLEAN", and the buttons REPLAY / GARAGE. **No line says why or what to try** (`resWait` is empty for the leader, `Hud.luau` 1101-1110).
- (c) ✗ for a fail. (b) "Dawn" is never explained.

### 2.7 L6 "The Big Score: Bank" (45 s runs, Dawn at run 8, needs 6 ★)

- The only line: **"The vault. Every clone counts."**
- The vault door opens only while **all four** plates are held. B, C and D sit under hide furniture. B also kills the laser grid; D holds the loading-dock door. Gus paces the hall. Grabbing the Gold trips the alarm; the front doors and dock lock 10 s later; the van leaves 20 s later. The alarm pill reads "◎ VAN LEAVES 0:20 · SHUTTER 0:10" ("SHUTTER" for bank doors). After banking, the toast "Goal banked! Finish the run."
- Nothing shows "need all 4": no lamp count on the vault door, no plate letters.
- Assessment: (a) ✗, (b) ✗. **A likely quit point** (P0).
- If she lacks 6 ★ after L4, the results say "2 more ★ opens the next tape". The stars' meanings (CREW = ≤ par clones, CLEAN = not caught or busted in the final run) are never shown.

### 2.8 Daily vault (open right after L1)

- Garage card, then PLAY. 30 s runs, cap 5, Dawn at run 6, a modifier label (e.g. "FAST GUS", "LIGHTS OUT", "LOOT MOVED").
- No level line exists for dailies (`LEVEL_LINES` has none), so the only objective is **"Grab the loot"**.
- Designs include Gus (DV04 Mistletoe Patrol), lasers (DV03), need-all plates (DV02 Twin Chimneys, DV07 Ornament Scale). A kid who has finished only L1 meets mechanics she hasn't been taught.
- Results: "VAULT CLEARED" / "DAWN" / "VAULT OVER". Award, e.g. "STREAK 1 · NEW ORNAMENT · +1 ★ · +$250". "Ornament" is unexplained, and there's no shelf in the UI.

---

## 3. Prioritized issues with exact fixes

P0 means a kid gets stuck or quits. P1 means confusing. P2 means polish. Each fix is copy text, a visual cue or a flow change. The code locations are where the change goes; no files were edited.

### P0

**P0-1. L1: tapping END RUN on the plate (what the line says) re-arms the tutorial.**
- Where: `src/shared/Sim/HeistSim.luau` 612-615 and 838-857 (`autoEnded` is set only by the timer).
- Effect: run 2 says "Step on the plate" while her clone holds it. The hints point there, an extra run follows, she loses the CREW star (2 clones > par 1), and the first bank is pushed past 45 s.
- Fix (flow):
  - In `liveIntents`, before `endLive(... EV.EndRun)`: if `HeistSim.autoEndArmed(sim)` and `Geom.contains(level.plates[ae.plate].box, a.x, a.y, a.z)`, set `a.autoEnded = true`. Do the same for a timeout that ends on the plate (`finishRun`).
  - In `Hud.objectiveText`, when armed but `P1Held` is true because of a clone, show the run-2 lines.
  - Add a Lifecycle spec: "END RUN on the plate → run 2 not armed".

**P0-2. No stuck help after L1.**
- Where: `Hud.luau` 2247-2271. Hints run only while the L1 auto-end is armed.
- Gap: §7.5's "after 2 failed runs on any level a Ghost Hint plays the solution once" isn't built. Neither is §3.1's Relaxed offer after 3 busts.
- Fix (flow):
  - After 2 runs with no progress (no new plate held by a clone, no goal bank), play the level's solution tape as the white Mentor mannequin (reuse `showHints` stage 3 with `Sampler.at` on the solution recording). Line: **"Watch the ghost. Copy it."**
  - After 3 catches in a heist, show a deck card: **"Too hard? RELAXED: slower Gus, longer runs"** with a single tap.

**P0-3. L2/L3 junk-clone soft lock at cap 4 (no Dawn).**
- Where: `Deck.luau` 56-66. A full deck silently replaces the newest slot, so a kid with 3 junk clones can never hold 2 plates.
- Fix (copy + flow):
  - When `#slots == cap`, the deck title becomes **"DECK FULL · tap a clone, then DELETE"**. Pulse the first card whose recording ended off every plate.
  - Toast at RunEnd: **"Deck full: your new clone replaced ●4"**.
  - After 2 no-progress runs with a full deck, offer a one-tap card **"START OVER (keep the doors)"**: delete all, then RUN.

**P0-4. L2 never teaches tapping END RUN, and then misdirects.**
- Where: `Hud.objectiveText` 2059-2067. L1's auto-end did the tapping for her. L2 shows "Two plates. You need two clones." for 6 s, then **"Grab the loot"**.
- Fix (copy + flow): world-state lines for L2-L4, the same model as L1.
  - Standing on a plate no clone holds: **"Stay here. Tap ◀◀ to make a clone."** and pulse END RUN (reuse the L1 pulse).
  - A plate with no clone and none under you: **"Next plate: make clone 2"**.
  - All doors open: **"Grab the cash"**.
  - Use "Grab the loot" only when no plate is needed.
  - Keep the level line sticky (`sticky = true`) until the first clone exists.

**P0-5. L6 four-plate vault explained by one line.**
- Where: `Hud.luau` 95.
- Fix (visual + copy):
  - A lamp row on the vault door (BillboardGui, 4 lamps lit in the presser hue) showing **"VAULT 2/4"**.
  - Letters "A"-"D" on the plates (see P1-3).
  - World-state lines:
    - **"The vault needs 4 plates at once."**
    - **"Find the hidden plates: 2/4"**
    - **"Vault open! Grab the gold."**
    - After the alarm: **"LOCKDOWN! Out the back door!"**

### P1

**P1-1. "END RUN" reads as "quit".**
- The word REWIND never appears. §7.5's own line says "Tap REWIND", which contradicts §7.4's "◀◀ END RUN". §10.3 gate: "run" vs "try" wording.
- Fix: button **"◀◀ REWIND"**. L1 line **"Stay on it. Tap REWIND."** Co-op: "◀◀ REWIND · 2/3". Rename "RUN n" to **"TRY n"** if the kid waves prefer it.

**P1-2. The L1 auto-end comes with no warning, so (c) "what just happened" fails.**
- Fix (visual): while she stands on an armed plate, a cyan ring fills around the plate over `L1_AUTO_END_SECONDS` (2.0 s), with a rising tick. At full, the rewind starts. Under reduced motion it's a static fill.

**P1-3. Plates have no letters, but L3/L6 copy names "Plate B".**
- Where: `LevelBuilder.luau` 200-229.
- Fix: a flat SurfaceGui letter ("A", "B"…) on each plate's icon when the level has more than one plate. Or drop letters from the copy: **"The plate in the back turns the lasers off."**

**P1-4. Gus is first met as a chaser in the Clone Party (play order 3), before L4 teaches him.**
- He has no name tag, yet L4's copy says "Gus".
- Fix:
  - A small "GUS" nameplate above his head (BillboardGui, 60 studs).
  - On the first Gus sight in any heist, toast **"That's Gus. Stay out of his light!"**
  - Party alarm toast **"Gus woke up! Run to the van!"** (replaces "Till alarm: everyone to the van!").

**P1-5. "Dawn" / "☾" is unexplained, and the fail result gives no reason.**
- Fix:
  - At run 1 on a Dawn level, objective **"Sunrise after run 6. Bank $200 before it!"**
  - Stamp **"☀ SUNRISE"**.
  - Results title **"OUT OF TIME"**, with `resWait` **"Try again: <level line>"**. For L4: **"Try again: hide under the coat rack."**

**P1-6. The first-heist ×2 detection grace is spent on L1, which has no guard.**
- Where: `HeistService.luau` 757-763, `Progress.luau` 309.
- Fix: base the grace on "first heist with a guard". For example, a `guardHeistsDone` counter < 2 in the profile, or pass `firstHeist` when the level has guards and the player has no guard-level clear yet.

**P1-7. The daily vault unlocks after L1 and can contain untaught Gus, lasers or need-all plates, with only "Grab the loot".**
- Fix:
  - Unlock the daily after Night Clerk (`dailyOpenFor` → check the NightClerk clear). The garage card shows **"DAILY VAULT · Clear Night Clerk"** in grey.
  - Add a `LEVEL_LINES` entry for each daily design, e.g. DV02 **"Both plates at once open the door."**

**P1-8. "Goal banked! Finish the run." is jargon, and the run keeps going.**
- The objective then flips to "Grab the loot". A catch after the goal costs CLEAN.
- Fix: toast **"You got it! Tap ◀◀ to finish, or grab more."** Pulse END RUN. Keep the objective at **"Done! Tap ◀◀ REWIND"**.

**P1-9. UNDO is the only deck action after every run, and it deletes the new clone silently.**
- Where: `Hud.luau` 662-669, 742.
- Fix: show UNDO only after a DELETE / REDO (`canUndo && lastOpWasDeck`). Label it **"TAKE BACK"**. After it, toast **"Clone ●2 removed"**.

**P1-10. Timeout, caught and zapped reasons are wiped in the same frame in solo.**
- Where: `Hud.onRunEnd` 1743.
- Fix: keep the spectate reason for 2 s, or put it in the deck title / ready card: **"Time's up! Your clone stops there."** / **"Gus caught you."** / **"Zapped!"**.

**P1-11. Hide spots are unmarked.**
- Fix: a faint steel outline and a "◐" icon on the furniture top when within 20 studs. First time, the line **"Walk into the coat rack to hide"**.

**P1-12. Stars HAUL / CREW / CLEAN are unexplained, but they gate L6 (6 ★).**
- Fix: under each results stamp, one line: **"Bank $200" / "Use ≤2 clones" / "Don't get caught"**. Show the same on the garage tape when it's tapped.

**P1-13. On phones, the top-row boxes overlap.**
- Loot 230 + top 330 + strip 220 + margins = 796 design px on a 720 px canvas whenever width is the binding dimension (most phones: `UI_DESIGN_SIZE` 720×330). The loot box overlaps the timer box by ~43 px and the clone strip by ~33 px.
- Fix: loot box 170, clone strip 170 (5 chips, then "+3"), or the top box 300. Assert in a layout test that the three widths + 24 ≤ 720.

**P1-14. No establishing view at L1 start.**
- The camera faces the shop wall. The plate may be off-screen **[verify on device]**, and the cash isn't visible (§7.5 says "cash glittering through glass").
- Fix: during the 1.0 s Intro, ease the camera from a high three-quarter shot over the plate → cable → door to behind the player. Or add a back-room window (glass `sight=false` occluder) so the cash glints.

**P1-15. L1 plate doesn't glow from t=0** (§7.5 says "glowing plate").
- Fix: start hint stage 1 (the breathing ring) at t=0 on run 1 of L1, and keep the 8/16/24 s escalation for the beam and Mentor.

### P2

- **P2-1. L1 copy is over 30 words.** Cut "Wait for your clone to open the door" → **"Watch your clone"**. Merge "Grab the cash" into the GRAB button only. That brings it to ~25 words.
- **P2-2. "⏩ HOLD" appears from L1 run 2** (§3.4: unlock at L3). Gate it to Catalog index ≥ 4 (Lights Out) or to the second heist. Text **"⏩ HOLD = FAST"**.
- **P2-3. END RUN during the 1.5 s lock plays the rewind clack** (`HeistClient.luau` 114-117). While locked, play `UIError` and pop the ring.
- **P2-4. The rewind plays after the deck, not at END RUN** (L2+). Play a 0.3 s freeze + "◀◀" overlay on RunEnd so cause and effect stay together; keep the full rewind on RUN.
- **P2-5. Jargon to replace:**
  - "PICK A TAPE" → **"PICK A HEIST"**
  - "30 SEC RUNS" → **"30 s"** with a clock icon
  - "NEW TAPE UNLOCKED" → **"NEW HEIST UNLOCKED"**
  - "Clear this tape to open the next one" → **"Win this to open the next one"**
  - "Rewinding the tape..." → **"One sec..."**
  - "SHUTTER" → **"DOORS LOCK"**
  - "REDO + LATER" → **"REDO ●2 (delete ●3-●4)"**
  - "DELETE BUSTED ✕" → **"DELETE ✕ CLONES"**
  - "Every clone stays for the party: 3" → **"Party! All 3 clones come back."**
- **P2-6. No "◀ YOU, N SEC AGO" after L1** (`CLONE_LABEL_SECONDS` is unused). Show it for 1 s on the newest own clone at the start of each story run, as Config says.
- **P2-7. ❚❚ implies pause; the run keeps going.** Use the glyph **"☰"** and the sheet text **"Leave this heist? Your clones will be lost."**
- **P2-8. "preparing" is silent and has no motion.** Start garage music, animate the van door, and cap the total wait at ~4 s (start the FTUE on greybox and dress later).
- **P2-9. Falling off the street edge** gives a 25-stud fall and a silent teleport. Add invisible walls at `bounds` on the street side.
- **P2-10. Line-up caption "RUN 2 · $100" is ambiguous.** Use **"2 RUNS · $100"**.
- **P2-11. Cash "+$200" has nothing to spend it on** in the sim UI (no store or bag screen). Hide Cash in the results until the store exists, or add a "Bag" card in the garage.
- **P2-12. The RUN stamp says "RUN 1" while the label says "RUN 1/8".** Use `runName` in `RewindDirector.play`.
- **P2-13. Missing sound ids (Heartbeat, GusStep, RewindStinger)** leave the detection and rewind beats silent (AUDIO.md §12 owner action).
- **P2-14. The Interact button's right edge sits at 120 design px from the right**, which is likely touching the Roblox jump button on small phones **[verify on device]**. Move it to −140.
- **P2-15. No bank burst / "+$100" flying to the meter** (§7.3). The toast is the only visual.

---

## 4. "Wrong thing" matrix

| Action | L1 | L2 / L3 | Party | L4 | L6 | Daily |
|---|---|---|---|---|---|---|
| Ignores the plate | Hints at 8/16/24 s, timeout, re-armed ✓ | Nothing; "Grab the loot" ✗ | n/a | Same as L2 | Same, and the vault never opens ✗ | Same ✗ |
| Walks into Gus | n/a | n/a | Only in the chase: BUSTED, no lesson | ?/! cone, BUSTED; reason wiped; no Relaxed | Also trips the alarm (`onCatch`) | Same as L4 |
| END RUN at once | Clack, nothing (lock); then a junk clone, re-armed ✓ | Junk clone; after 3 → **soft lock** | Fine (a clone keeps stealing) | Junk; Dawn at 6 ends it | Junk; Dawn at 8 | Junk; Dawn at 6 |
| Never presses END RUN | 30 s timeouts; fine | 30 s timeouts, slow; reason never shown | Fine | Fine until Dawn | 45 s runs | Fine until Dawn |
| END RUN on the plate (as told) | **Bug P0-1** | Correct move but never prompted | — | Correct | Correct | Correct |
| Leaves mid-heist (❚❚) | Garage, tape 1; no warning | Same | Same | Same | Same | Same |
| Closes the app | L1 auto-restarts on rejoin | Garage | Garage | Garage | Garage | Garage |

---

## 5. What already works (keep it)

- The clone walks out of her own spawn with "◀ YOU, 10 SEC AGO", then "Your clone stops where you stop." That is (d) done right.
- L1 recovery for END RUN off the plate, and the 8/16/24 s stuck hints with the Mentor walk.
- One verb at a time on the phone: GRAB is far from END RUN, with a 0.3 s thumb-slip guard.
- Plates show the presser's glyph and hue, the cable lights up, and the door moves: cause and effect stay visible.
- Party: the time-locked till with a countdown, "GETAWAY!" framed as fun rather than blame, the 10 s auto-start, and "8 OF ME".
- Captions are on by default; reduced motion is respected throughout.

## 6. Must still be human-tested (§10.3)

- Whether the L1 plate is in frame at spawn on a phone.
- Whether a kid reads the VHS effect as "rewind".
- Whether the cyan-tinted clone reads as "my avatar".
- Gus fairness without the first-heist grace.
- The top-row overlap on a 667×375 and a 360-dp phone.
- The jump / Interact spacing.
- The words kids use for "run".
