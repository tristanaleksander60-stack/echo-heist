# STORE PAGE: "Heist Yourself: Rob With Your Clones"

_Marketing kit, file 1 of 5 (docs/marketing/). Written 2026-11-12 for the Thu Dec 3 "Steal Back Christmas" launch. Sources: MASTERPLAN §1.1, §2, §4.3, §5.4, §9.1, §9.5; vault *Experience Description and Search Keywords*, *Live Ops Events and Updates*, *Patch Notes and Player Communication*, *Marketing to Kids and Teens*; live `tools/rbx_search.py` and games API checks run today. Notation as in the plan: **[DECISION]** = our call, **[UNVERIFIED]** = not confirmed, (H) = heuristic, [estimate] = our arithmetic._

Everything on this page must be **true for every player who reads it**. When the game changes, this page changes the same day (§8 below).

> **Revised 2026-11-13 for the first-person pivot** (docs/PLAN_FIRST_PERSON.md). What changed on this page: you play **first person as the Rookie** (your outfit, your crew colour), never as your Roblox avatar, and your clones are copies of *your Rookie*; the button is **REWIND** (was END RUN); new true claims: **Crew View**, the **hideout and its vans** (SOLO or crew), **outfits**, the **story intro** (Sir Hoardsworth and the Snow Globe Vault). The description now teaches the game in a **3-verb block** (RUN IT / REWIND IT / ROB IT TOGETHER, §3), and the launch NEW line names the villain. Positioning note for MASTERPLAN §9.1 (outside this folder, for the owner or integrator): "your own Roblox avatar as the clone" no longer holds; the line becomes **"your own Rookie (your outfit, your crew colour) as the clone"**.

---

## 1. The rules this page follows (2026)

| Rule | What it means for us | Source |
|---|---|---|
| Title = brand + one accurate descriptor | "Heist Yourself" (brand) + "Rob With Your Clones" (what you do) | vault *Experience Description and Search Keywords* |
| First 2 lines do the work | Line 1: verb + fantasy + social hook. Line 2: the "NEW:" line, changed every update. Many surfaces cut the text after about 150 characters | same |
| No keyword lists, no other games' names | Synonyms go into normal sentences. Never "like Jailbreak", never "PAYDAY", "GTA", "ROB IT" or "Steal a ..." | same; Community Standards (misleading metadata) |
| No links, handles or QR codes in game text or the description | Social accounts only through the **Social Links** feature on the game page (shown to age-checked 16+) | vault *Community Building*, *Marketing to Kids and Teens* |
| No misleading claims | "up to 8" and "up to 16", because 8 needs Clone Party or a Big Score and 16 needs 4 players. No "best", no "FREE ROBUX", no "x2", no fake timers | vault *Experience Description...* "Keeping it honest and current" |
| Kids & Select friendly words | Rob, steal, sneak, heist, caught, busted, alarm. **Never:** crime, criminal, police, gun, kill, die, blood, gamble, casino. No pressure ("hurry", "only today", "everyone is buying") | MASTERPLAN §1.3 (target **Mild**); vault *Marketing to Kids and Teens* |
| Player nouns | "clone" and "run" (never "echo" or "take") | MASTERPLAN §0 C2 |
| Don't change everything at once | Title, description, icon and thumbnails change one at a time, with a dated note, so we can see what helped | vault *Experience Description...* "Common mistakes" |

---

## 2. Title

| Field | English | Danish | Length |
|---|---|---|---|
| **Title (default)** | `Heist Yourself: Rob With Your Clones` | `Heist Yourself: Stjæl med dine kloner` | 36 / 37 chars |
| **Title, Christmas edition** (Dec 3 - Jan 4) | `[🎄] Heist Yourself: Rob With Your Clones` | `[🎄] Heist Yourself: Stjæl med dine kloner` | 40 / 41 chars |
| **Short title** | `Heist Yourself` | `Heist Yourself` | 14 chars |

- **Seasonal tag.** Put `[🎄] ` in front on **Thu Dec 3** when the game goes public. Remove it on **Tue Jan 5** (the event ends Mon Jan 4; the dressing layer turns off Jan 5). Stale event text costs trust (vault).
- **Short title** is what we use when there is no room: social handles (@heistyourself), hashtag (#heistyourself), ad campaign names, event subtitles, spoken mentions in clips, and creator scripts. Roblox has no separate "short title" field that we could confirm **[UNVERIFIED]**; on phone Home tiles the long title is cut, so the brand must come first (it does).
- **Always say the exact title off-platform.** Search for the exact name is also how Audience Expansion attributes new players to us (vault *Experience Description...*, "Search attribution").
- **Title length limit:** we believe the field allows 50 characters **[UNVERIFIED]**; all four versions are 41 or fewer.
- **[DECISION] Danish title uses "Stjæl" (steal), not "Røv" (rob).** In Danish "røv" alone is also slang for "bum", which kids would joke about. "Røver" (robber) and "røverbande" are fine and are used in the description. The brand "Heist Yourself" stays English (Danish kids use "heist").
- **Names never in the title:** "Echo", "Rewind Robbers", "Loop Heist", "Rob It Again" (MASTERPLAN §2.1), and no "Simulator", "Tycoon", "Obby", "RNG" (keyword stuffing).

---

## 3. Description, English (889 characters, limit 1,000 **[UNVERIFIED]**: check the counter in Creator Hub)

Paste exactly (the bullets are the "•" character). **Revised 2026-11-13** for the first-person pivot; the 2026-11-12 text is in git history.

```text
Your past self is your crew! Rob it solo with up to 8 of you, or with friends: up to 16 robbers, 1 vault.
NEW: Steal Back Christmas! Sir Hoardsworth took every present in town. Steal them back, with a daily vault that doubles as an advent calendar.

RUN IT: sneak in as the Rookie, grab the loot, get back to the van.
REWIND IT: your run turns into a clone of you that does it all again.
ROB IT TOGETHER: one clone holds the door, one stands on the plate, you take the cash!

• Your clone stops where you stop, and repeats your mistakes. Every. Single. Time.
• Hide from Gus the night guard and his big flashlight, or let a clone distract him.
• Hold CREW VIEW to see your whole crew from above.
• Pick a van in your hideout: go SOLO (the full game) or bring up to 3 friends. Private servers are free.

6 heists, outfits for your Rookie, trophies for your hideout. Runs last 30-45 seconds.
```

### 3.0 The 3-verb block (the Fisch pattern)

The games that teach well on the store page (Fisch is the reference the owner named) use **one line per verb, in the order you play them**, so a reader learns the loop in three lines before the bullets. Ours is **RUN IT / REWIND IT / ROB IT TOGETHER**:

| Verb | What it teaches | Why this wording |
|---|---|---|
| **RUN IT** | You are one robber (the Rookie), you sneak, grab, and get back to the van | "Run" is the player noun (MASTERPLAN §0 C2) and the action; "the Rookie" names the character so "copies of you" later means copies of *him in your outfit*, not your Roblox avatar |
| **REWIND IT** | The button (REWIND) ends the run; the run becomes a clone that repeats it | Uses the real button label (`Strings.REWIND`); "turns into a clone of you" is the twist in 9 words |
| **ROB IT TOGETHER** | Clones are crew: door, plate, cash | The concrete picture a 10-year-old can repeat; "together" bridges to the friends line |

Rules: three lines, each **≤ 90 characters**, each starting with the verb in caps and a colon, kid words only (§1). If a future update changes the loop (e.g. a hand-off), the bullets change, not the three verbs.

### 3.1 Why each line is there

| Line | Job | Search ideas it carries in normal sentences |
|---|---|---|
| 1 "Your past self is your crew! Rob it solo with up to 8 of you, or with friends: up to 16 robbers, 1 vault." | Verb (rob) + fantasy (your past self is your crew) + social hook (friends, 16 robbers). The MASTERPLAN §1.1 line, with "up to" added for truth | rob, past self, crew, friends, robbers, vault |
| 2 "NEW: Steal Back Christmas! Sir Hoardsworth took every present..." | Freshness hook with the story's villain (the intro); replaced every update (§5) | steal, christmas, presents, daily, advent |
| RUN IT / REWIND IT / ROB IT TOGETHER | The loop in three verbs (§3.0), including the key picture "one clone holds the door" | run, sneak, loot, van, rewind, clone, cash |
| Bullets | The rule "your clone stops where you stop" (§7.5) and the mistakes joke; the threat with a face (Gus, market F2); Crew View (the first-person answer to "where are my clones?"); the hideout and the van choice (solo is complete, co-op is bigger, no stranger chaos, §3.3) | guard, flashlight, hide, crew, hideout, friends, private server |
| Last line | Size and length of the game, honestly, plus the two progression hooks (outfits, trophies) | heists, outfits, trophies |

**Words we deliberately left out:** "puzzle" (MASTERPLAN §1.3: puzzle framing failed for ECHOES: Clone Puzzles, 0 playing), "echo", "take", "free" except for private servers (a plain fact), "Robux", any price, "first person" / "FPS" (shooter connotation for parents and the Mild questionnaire: we say "sneak in as the Rookie" instead), "avatar" (your Roblox avatar is never shown in the game), "Santa hat" (moved out of line 2 to make room for the villain; Gus still wears it, so it can come back in a bullet if the count allows), "alarm" (the Alarm Run is still in Clone Party and the Big Score; it lost its bullet to Crew View and can return in the Dec 11 text).

### 3.2 Truth check (re-run after every update)

| Claim | True because | Breaks if |
|---|---|---|
| "up to 8 of you" | Clone Party and The Big Score grant 8 slots; Dawn at run 8 = 7 clones + you ("8 OF ME" stamp, `L5_CloneParty.luau` hooks) | Clone Party or Big Score caps drop below 8 |
| "up to 16 robbers" | 4 players × (1 + 3 clones) = 16 (cap 12 clones per heist instance, `floor(12 / 4) = 3`, §0 C3) | Crew size or the 12-clone instance cap changes |
| "Bring up to 3 friends" | Party of up to 4 per heist instance (§3.3) | Party size changes |
| "a daily vault that doubles as an advent calendar" | Daily vault = advent calendar Dec 3-24, ornament per first clear (§4.3); the hideout's laptop shows it and the catch-up | After Dec 31 this text must go (catch-up ends Dec 31) |
| "Sir Hoardsworth took every present in town" | The story intro (`Shared/Heist/IntroPlan`: the vacuum on his tower, the Snow Globe Vault), first join and the lobby TV (WATCH INTRO) | If the intro is cut or turned off (`Config.Intro.ENABLED`) |
| "sneak in as the Rookie" | Every player is a Rookie (`server/Heist/Characters`, StarterCharacter), first person by default (`CameraDirector` "fp") | If the Roblox avatar ever comes back as the character |
| "REWIND IT ... a clone of you" | The REWIND button (`Strings.REWIND`, R / Y / tap); clones are copies of your Rookie in your outfit (`Avatars.buildRookie`) | — |
| "Hold CREW VIEW" | Hold Q / LB / the touch CREW button in a first-person run (`Shared/Heist/CrewView`) | If Crew View is cut or renamed |
| "Pick a van in your hideout: go SOLO ... or bring up to 3 friends" | The hideout lobby: PICK VAN, SOLO · GO, CREW seats for friends (`Heist/Vans`, `VanRules`), seats = `Config.Sim.MAX_CREW` (4) | Crew size changes |
| "outfits for your Rookie" | Wardrobe: 5 slots, unlocks by stars or trophies (`Config.Rookie`, `Outfit`) | — |
| "trophies for your hideout" | The trophy shelf in the hideout | — |
| "Each party gets its own heist" (no longer in the text; kept for the creator and parent FAQ) | Per-party heist instances from a shared hideout (§0 C11); strangers only via opt-in Quick Crew (not built yet: the crew sign invites friends) | — |
| "Private servers are free" | §5.4 | If private servers get a price |
| "6 heists" | L1-L4, Clone Party, The Big Score: Bank | Dec 11 → "8 heists"; Dec 18 → "9 heists" |
| "Runs last 30-45 seconds" | Corner Shop 30 s, Bank and Christmas levels 45 s, daily vaults 30 s (§3.1) | Jan 22 Museum (60 s) → "30-60 seconds" |
| "Hide ... let a clone distract him" | Hiding spots (§3.1); Gus chases the nearest actor, so a clone is a decoy (§3.6 #3) | — |
| "Gus the night guard" (and his Santa hat in the art) | Gus is in L4, Clone Party and the Big Score; the Christmas dressing layer gives him the Santa hat Dec 3 - Jan 4 (`Gus_SantaHat`) | After Jan 4, no Santa hat in new art |

If the Nov 30 go/no-go slips launch to **Thu Dec 10** (§10.2), the Wrapping Room levels ship inside the launch: change "6 heists" to "8 heists" and use the Dec 11 NEW line from the start.

---

## 4. Description, Danish (960 characters; revised 2026-11-13 for the pivot)

**[DECISION]** Upload the Danish title and description on launch day if Creator Hub offers Danish for experience information (Localization → Danish → Experience information) **[UNVERIFIED that Danish is in that list]**. This is store metadata only; the in-game Danish table still ships Jan 8 (§4.4), so the last sentence says the game is in English for now. If the Danish field is not offered, use this text for Danish posts, the Danish kid-wave invitations and the Jan 8 table. The owner (native speaker) proofreads before upload.

```text
Dit gamle jeg er din røverbande! Lav kuppet alene med op til 8 udgaver af dig selv, eller med vennerne: op til 16 røvere, 1 boks.
NYT: Stjæl julen tilbage! Sir Hoardsworth har taget alle byens gaver. Stjæl dem tilbage, med en daglig boks, der også er julekalender.

SNIG: snig dig ind som Rookien, snup byttet, og kom tilbage til varevognen.
SPOL TILBAGE: din runde bliver til en klon af dig, der gør det hele igen.
STJÆL SAMMEN: én klon holder døren, én står på trykpladen, og du tager kassen!

• Din klon stopper, hvor du stopper, og gentager dine fejl. Hver. Eneste. Gang.
• Gem dig for nattevagten Gus og hans store lommelygte, eller lad en klon lokke ham væk.
• Hold CREW VIEW nede for at se hele din bande oppefra.
• Vælg en varevogn i skjulestedet: kør SOLO (hele spillet), eller tag op til 3 venner med. Private servere er gratis.

6 kup, tøj til din Rookie, trofæer til skjulestedet. En runde varer 30-45 sekunder. Spillet er på engelsk indtil videre.
```

Translator notes:
- "Heist" → **kup** (et kup = a heist; kids also know "heist"). "Vault" → **boks** (bankboks), **everywhere**, names included (*Snekugleboksen*, not *Snekuglehvælvingen*): one word per thing for kids; "advent calendar" → **julekalender** (Danish kids open one every day in December, so "daily vault = julekalender" lands perfectly). "Santa hat" → **nissehue**. "Crew" → **røverbande** (kid-book word, not "bande" alone, which sounds like a real gang).
- **Revised after review (2026-11-12), still for the owner's native proofread:** "8 of you" → **8 udgaver af dig (selv)**, never the word-for-word "8 af dig"; "Rob it solo" → **Lav kuppet alene** (not "Tag kuppet"); "the plate" → **trykpladen** ("pladen" alone can mean a record or a dinner plate); short event names a 10-year-old can say: Wrapping Room → **Gaverummet** (alternatives: *Pakkerummet*, *Indpakningsrummet*), Snow Globe Vault → **Snekugleboksen**, the Gift-Wrap clone style → **Gavepapir-klonstilen**. The owner picks the final words; keep them identical in the event titles, the NEW line and the announcements.
- "REWIND" and "CREW VIEW" stay English because they are the button and HUD texts until the Jan 8 table; the three verbs are Danish (**SNIG / SPOL TILBAGE / STJÆL SAMMEN**), never "RØV" alone (§2). Change the button names to the Danish button texts then.
- **"the Rookie"** is a name: **Rookien** (definite) / **din Rookie**; the owner checks it reads naturally to a 10-year-old (alternative: keep "the Rookie" in English in quotes). "Hideout" → **skjulested**; "outfits" → **tøj**.
- Danish search words we cover: røver, kup, stjæle, kloner, jul, julekalender, nattevagt, boks. Not covered on purpose: "bankrøveri" (sounds like real crime news).

---

## 5. The "NEW:" line, by date (line 2 of the description)

Change it the same hour the content goes live (drops are Fridays 17:00 CET, published 24 h earlier and unlocked by server time, §9.8). Keep line 1 unchanged so we can see what the NEW line does.

| Date (CET) | English line 2 | Danish line 2 | Also change |
|---|---|---|---|
| Thu Dec 3 15:00 | `NEW: Steal Back Christmas! Sir Hoardsworth took every present in town. Steal them back, with a daily vault that doubles as an advent calendar.` (revised 2026-11-13: the story intro gives the season a villain; the Santa-hat line is the fallback if the intro is off) | `NYT: Stjæl julen tilbage! Sir Hoardsworth har taget alle byens gaver. Stjæl dem tilbage, med en daglig boks, der også er julekalender.` | Title gets `[🎄] ` |
| Fri Dec 11 17:00 | `NEW: Wrapping Room! 2 new Christmas heists with presents so big your clone has to help carry them.` | `NYT: Gaverummet! 2 nye julekup med gaver så store, at din klon skal hjælpe med at bære dem.` | "6 heists" → "8 heists" / "6 kup" → "8 kup" |
| Fri Dec 18 17:00 | `NEW: The Snow Globe Vault! Steal back the Giant Present with 8 of you before morning.` | `NYT: Snekugleboksen! Stjæl kæmpegaven tilbage med 8 udgaver af dig selv, før det bliver morgen.` | "8 heists" → "9 heists" |
| Wed Dec 23 (the description cannot be unlocked by server time, so the owner edits it before the freeze; the wording names the dates) | `NEW: Gift for everyone: the Gift-Wrap clone style on Dec 25-26, plus double Stars in the daily vault.` | `NYT: Gave til alle: Gavepapir-klonstilen d. 25.-26. december, og dobbelte stjerner i den daglige boks.` | — |
| Sun Dec 27 | Back to the Dec 18 line | Back to the Dec 18 line | — |
| Fri Jan 1 | Remove "a daily vault that doubles as an advent calendar" wherever it still appears (catch-up closed Dec 31) | Same | — |
| Tue Jan 5 | `NEW: Christmas is saved! Thanks, robbers. Next: a New Year update on Fri Jan 8.` (only if Jan 8 is confirmed green) | `NYT: Julen er reddet! Tak, røvere. Næste: nytårsopdatering fredag d. 8. januar.` | Remove `[🎄] `; remove "Santa hat" wording |
| Fri Jan 8 17:00 | `NEW: Contracts! A new challenge every week, Diamond medals and Danish text.` | `NYT: Kontrakter! En ny udfordring hver uge, diamantmedaljer og dansk tekst.` | — |

---

## 6. Other store fields

| Field | Value | Why |
|---|---|---|
| Genre / subgenre | **[DECISION] Survival → Escape** | The live games API (today) puts ROB IT and BE TINY AND ROB GRANDPA, our closest "sneak, grab, escape" neighbours, in Survival / Escape; Criminal Simulator and Heist Evolution sit in Simulation. Our loop is sneak → grab → run for the van, not a simulator. **Never "Puzzle"** (MASTERPLAN §1.3). The owner picks the closest match if the dropdown has changed **[UNVERIFIED current list]** |
| Maturity | **Mild** (target), full Maturity & Compliance Questionnaire | Kids & Select needs Minimal/Mild; no weapons, blood, gore, jump scares or gambling (§1.3). Answer for what ships, see LAUNCH_CHECKLIST |
| Max players per server | 8 (garage lobby) | §3.3 |
| Private servers | On, price **0** | §5.4; private servers count as intentional co-play |
| Devices | Phone, tablet, computer, console | Mobile-first game; console only if gamepad controls pass testing (§3.4) |
| Social Links | Optional, after the handles have 5+ posts: TikTok, YouTube, Instagram (@heistyourself) | The only allowed place for handles; shown to age-checked 16+ only |
| Icon, thumbnails, video | See ICON_THUMBNAILS.md (Home pool at launch: T5 + T3) | §9.4 |
| Experience Events | See §9 below | §9.5 #6 |

---

## 7. Search: the player queries we write for (vault: 15-30 queries)

Roblox search is semantic and has no keyword field; it reads the title, the description and (probably) the genre. So the job is: each query below appears in a natural sentence in the title or the first two lines, or at least in the body. **[DECISION]** Written now instead of in W3 (MASTERPLAN §9.1) so the description is built on it.

"Top today" = the first results of `tools/rbx_search.py` on 2026-11-12 (players online in brackets). We do not use these names anywhere in our metadata.

| # | Query (what a player types) | Kind | Where we say it | Top today |
|---|---|---|---|---|
| 1 | heist | genre | Title, line 2, body | Heist (64), Notoriety (1,066), Deadly Heist (257) |
| 2 | heist game | genre | Title + body | (same cluster) |
| 3 | heist with friends | social | Title + line 1 ("with friends") | Heist Evolution (1,998) |
| 4 | rob | verb | Title, line 1 | ROB IT (1,316), Steal An Egg, Criminal Simulator (16,787) |
| 5 | rob the bank | verb + place | Line 1 ("1 vault"), body | ROB IT, Jailbreak |
| 6 | rob a store | verb + place | body ("heists") | HEIST: Rob a Store (358) |
| 7 | bank heist | place | body | [💰] Bank Heist (4), HEIST: Rob a Store |
| 8 | clone | twist | Title, body | Clone Engine (1,845), Clone Friends (913) |
| 9 | clones | twist | Title | (same) |
| 10 | clone yourself | twist | body ("your clone") | Clone Yourself (373) |
| 11 | play with your past self | fantasy | Line 1 | (no good match: our gap) |
| 12 | past self | fantasy | Line 1 | "I AM...?", unrelated |
| 13 | rewind | mechanic | body ("the tape rewinds") | ragdoll and obby games |
| 14 | christmas heist | season | Title tag + line 2 | Heist Evolution, Christmas Tower |
| 15 | steal christmas | season | Line 2 ("Steal Back Christmas") | Steal From Santa (53) |
| 16 | christmas game | season | Line 2 | tycoons and obbies |
| 17 | sneak past the guard | fantasy | body heading | (heist cluster) |
| 18 | night guard | threat | Line 2 ("Gus the night guard") | horror games |
| 19 | stealth | genre | body ("sneak", "hide") | (heist cluster) |
| 20 | escape the guard | fantasy | body ("Run for the van") | ROB IT (Survival / Escape) |
| 21 | vault | place | Line 1 | — |
| 22 | game to play with friends | parent / friend phrasing | Line 1, body | social hangouts |
| 23 | 2 player heist / co-op heist | social | body ("bring up to 3 friends") | Criminal Simulator ("1-4 players") |
| 24 | solo heist | mode | body ("Solo is the full game") | — |
| 25 | heist yourself | brand | Title | today: Heist Evolution, "Knock Yourself Out!" (no conflict) |
| 26 | rob with your clones | brand descriptor | Title | today: Heist Evolution, Build Anything With Clones! |

**Not targeted on purpose:** "steal" alone (Steal An Egg, 528,677 playing, owns it), "time loop" (dead games; puzzle signal), "brainrot", any competitor title.

**How we check our position (owner, 10 minutes every Monday from Dec 7):**
1. Use a logged-out browser window or a fresh test account (personalisation changes results).
2. Search each of the 26 queries; write the position (1-20) or "-" in a dated sheet (`search_positions.csv`: date, query, position, top result).
3. Change one thing per round (usually line 2), then re-check after a few days; the docs give no re-indexing delay.
4. What really counts is search-sourced plays in the Acquisition dashboard and `JoinSource` "search"/"organic" (docs/ANALYTICS.md), not one query's position.

---

## 8. Update-log template (one source, four channels)

The **in-game What's New panel is the full note**; every other channel points to the game (vault *Patch Notes and Player Communication*). Write the in-game note first, then cut the rest from it. Simple English, short sentences, the exact in-game names, no internal names, no hype words, no links.

### 8.1 In-game What's New (English)

```text
[HEADLINE: the biggest player-visible thing, one line]
e.g. Wrapping Room: 2 new Christmas heists.

NEW
• [Thing] - [where to find it]          e.g. Gift Tag and Wrapping Room - on the tape shelf in your van.
• [Thing] - [where to find it]          e.g. Heavy presents: you and your clone carry them together.
• [Thing] - [where to find it]          e.g. 2 more daily vaults.

CHANGES
• [What changed, with a number]          e.g. Gus walks 10% slower in Clone Party.

FIXES
• [What players saw, in their words]     e.g. Your clone no longer gets stuck in the shop door.

KNOWN ISSUES
• [What is still broken + workaround]    e.g. Some phones show the clone glow late. It fixes itself after one run.

NEXT (only if sure)
• [One line]                              e.g. Fri Dec 18: The Snow Globe Vault.
```

### 8.1b The launch note: the Christmas edition (Thu Dec 3; written 2026-11-13 for the pivot build)

The first What's New a player can open (the hideout TV or the What's New panel). Every line is true in the v97+ build; re-check against the launch build on Dec 1 (LAUNCH_CHECKLIST).

```text
Steal Back Christmas: Sir Hoardsworth took every present in town.

NEW
• Play as the Rookie - pick your outfit at the wardrobe in your hideout.
• Every run you REWIND turns into a clone of you. Hold CREW VIEW to see them all.
• Pick a van in your hideout. Go SOLO, or let up to 3 friends sit in the back.
• 6 heists, Gus the night guard (in a Santa hat), and a daily vault that is also an advent calendar - on the laptop.
• Missed the story? WATCH INTRO on the hideout TV.

KNOWN ISSUES
• [filled on Dec 1 from the launch build's open list]

NEXT
• Fri Dec 11: Wrapping Room.
```

Danish (for posts and the Jan 8 table; the owner proofreads):

```text
Stjæl julen tilbage: Sir Hoardsworth har taget alle byens gaver.

NYT
• Spil som Rookien - vælg dit tøj ved garderoben i skjulestedet.
• Hver runde, du spoler tilbage (REWIND), bliver til en klon af dig. Hold CREW VIEW nede for at se dem alle.
• Vælg en varevogn i skjulestedet. Kør SOLO, eller lad op til 3 venner sætte sig bagi.
• 6 kup, nattevagten Gus (med nissehue) og en daglig boks, der også er julekalender - på den bærbare.
• Gik du glip af historien? WATCH INTRO på tv'et i skjulestedet.

NÆSTE
• Fredag d. 11. december: Gaverummet.
```

The one-line **update log entry** for the change log (§8.4 step 6) and the creator FAQ: `Dec 3 - Christmas edition: first person as the Rookie, clones of your Rookie, Crew View, the hideout and its vans, the story intro, 6 heists.`

### 8.2 In-game What's New (Danish, from Jan 8 when the table ships)

```text
[OVERSKRIFT]
NYT
• [Ting] - [hvor du finder den]
ÆNDRINGER
• [Hvad er ændret, med et tal]
RETTELSER
• [Hvad spillerne så]
KENDTE FEJL
• [Hvad er stadig i stykker + hvad du kan gøre]
NÆSTE
• [Én linje]
```

### 8.3 Update announcement (Creator Dashboard → Engagement → Updates: 60 characters, at most one every 3 days)

| Date | English (chars) | Danish (chars) |
|---|---|---|
| Dec 11 | `Wrapping Room: 2 new heists + presents too big for 1!` (53) | `Gaverummet: 2 nye kup + gaver for store til 1!` (46) |
| Dec 18 | `The Snow Globe Vault is open! Steal back Christmas.` (51) | `Snekugleboksen er åben! Stjæl julen tilbage.` (44) |
| Dec 25 | `Merry Christmas! A Gift-Wrap clone style for everyone.` (54) | `Glædelig jul! Gavepapir-stilen til alle dine kloner.` (52) |
| Jan 8 | `New Year patch: Contracts and Diamond medals!` (45) | `Nytårsopdatering: Kontrakter og diamantmedaljer!` (48) |

No announcement on Dec 3: nobody has turned on notifications yet. Never send "Come back! New stuff!"; say what is new.

### 8.4 Per-update routine (owner, 10 minutes, on drop day)

1. In-game What's New text merged with the build (Claude writes it; owner reads it once).
2. Description line 2 → the row in §5; update the heist count in the last line.
3. Update announcement → §8.3 (check: 3+ days since the last one).
4. Check that the event for this drop is live (§9).
5. Add one thumbnail that shows the new content to the **details page** (not the Home pool; ICON_THUMBNAILS.md §6).
6. Write a dated line in the change log (`docs/marketing/` is fine, or the owner's sheet): what changed on the page, when.

---

## 9. Experience Event copy

Creator Dashboard → the experience → **Engagement → Events & Updates → Create Event or Update**. Fields: title, subtitle, description (optional, but use it), category, start and end time, up to 5 thumbnails (else the primary thumbnail is used), visibility, optional event place (Roblox docs, experience events page). Up to 10 ongoing or upcoming events. **Trending Events** needs an event that started in the last 7 days with 1,000+ RSVPs; **off-platform featuring** needs submission **7+ days before the start**, a public, time-limited event or significant update, and **no edits after submitting** (vault *Live Ops Events and Updates*). Title and subtitle limits are not documented in what we could find **[UNVERIFIED]**: the lines below are 55 characters or fewer.

**[DECISION]** One event per drop, each one week long, so each drop gets a fresh 7-day Trending window. E1 is the launch event from MASTERPLAN §9.5 #6. Draft E1 and E2 as **private** on Wed Dec 2; make E1 public and submit it for featuring right after the game goes public on Thu Dec 3 (the plan's deadline is Fri Dec 4, 7 days before Dec 11; doing it on Dec 3 gives one spare day). Make E2 public and submit it by **Fri Dec 11** at the latest (7 days before Dec 18), with real finale images only if the finale build can be captured by then (ICON_THUMBNAILS.md §5).

### E1: Steal Back Christmas: The Wrapping Room (the launch event)

| Field | English | Danish (if the event supports translations **[UNVERIFIED]**) |
|---|---|---|
| Title | `Steal Back Christmas: The Wrapping Room` | `Stjæl julen tilbage: Gaverummet` |
| Subtitle | `Presents so big you need your clone to help carry them` | `Gaver så store, at din klon skal hjælpe med at bære dem` |
| Category | Content update (or the closest in the dropdown) | — |
| Start | **Fri Dec 11, 17:00 CET** (11:00 US Eastern) | — |
| End | **Fri Dec 18, 16:59 CET** | — |
| Event place | Start place (the garage) | — |
| Thumbnails | T5 + Christmas Clone Party shots: launch content only, because a featured event can't be edited after submitting (ICON_THUMBNAILS.md §5) | — |

Description (English):

```text
Sir Hoardsworth has hidden the town's presents in his toy shop, and some of them are HUGE.

NEW HEISTS
• Gift Tag: your clone carries the key tag, then drops it right where you need it.
• Wrapping Room: presents too big for one robber. Grab one end, and let your clone grab the other!

ALSO NEW
• 2 more daily vaults for your advent calendar.
• A daily board for the biggest haul.

Play solo with your clones, or bring up to 3 friends.
```

Description (Danish):

```text
Sir Hoardsworth har gemt byens gaver i sin legetøjsbutik, og nogle af dem er KÆMPESTORE.

NYE KUP
• Gift Tag: din klon bærer nøgle-mærket og taber det lige der, hvor du skal bruge det.
• Wrapping Room: gaver for store til én røver. Tag fat i den ene ende, og lad din klon tage den anden!

OGSÅ NYT
• 2 nye daglige bokse til din julekalender.
• En daglig liste over det største bytte.

Spil alene med dine kloner, eller tag op til 3 venner med.
```

(Level names stay English in the Danish text until the Jan 8 table gives them Danish names.)

### E2: Steal Back Christmas: The Snow Globe Vault (the finale)

| Field | English | Danish |
|---|---|---|
| Title | `Steal Back Christmas: The Snow Globe Vault` | `Stjæl julen tilbage: Snekugleboksen` |
| Subtitle | `8 of you vs. Sir Hoardsworth's biggest vault` | `8 udgaver af dig mod Sir Hoardsworths største boks` |
| Start | **Fri Dec 18, 17:00 CET** (published Thu Dec 17, unlocked by server time) | — |
| End | **Mon Jan 4, 23:59 CET** (event end, §4.3) | — |
| Thumbnails | The real Snow Globe Vault if the finale build can be captured by the submission day; otherwise T5 v1 | — |

```text
The Giant Present is locked in the Snow Globe Vault. You get 8 clone slots, an alarm, and one night to steal it back.
• Two of you can drag the Giant Present. Three or four of you move it faster.
• When the alarm goes off, Gus runs. Your clones can lead him away.
Solo or with up to 3 friends. Christmas ends Jan 4!
```

```text
Kæmpegaven er låst inde i Snekugleboksen. Du får 8 kloner, en alarm og én nat til at stjæle den tilbage.
• To af jer kan slæbe kæmpegaven. Tre eller fire af jer flytter den hurtigere.
• Når alarmen går, løber Gus. Dine kloner kan lokke ham væk.
Alene eller med op til 3 venner. Julen slutter 4. januar!
```

"Christmas ends Jan 4" is a true date, not false scarcity; do not add countdowns or "last chance" wording.

### E3 (optional): Christmas Gift (Dec 25-26)

Only if the gift beat is green on Dec 23 (§4.3). Not submitted for featuring (too short a lead).

| Field | English | Danish |
|---|---|---|
| Title | `A Christmas Gift for Every Robber` | `En julegave til alle røvere` |
| Subtitle | `The Gift-Wrap clone style and double daily Stars` | `Gavepapir-klonstilen og dobbelte daglige stjerner` |
| Start / end | Fri Dec 25 00:00 UTC → Sun Dec 27 00:00 UTC (the server-time unlock uses UTC dates, like the daily vault) | — |

Description: `Log in on Dec 25 or 26 to get the Gift-Wrap clone style, free for everyone. Daily vault Stars count double.` / `Kom ind d. 25. eller 26. december og få Gavepapir-klonstilen, gratis for alle. Stjerner fra den daglige boks tæller dobbelt.`

### In-game RSVP

The game may show the RSVP prompt (`SocialService:PromptRsvpToEventAsync`, current API) **after the first completed heist, once**, never during a heist and never with a reward (MASTERPLAN §9.5 #6, §9.3 #3). RSVPs are a nice-to-have, not a KPI. Code is outside this folder.

---

## 10. Launch-day page check (Thu Dec 3, before 15:00 CET)

- [ ] Title with `[🎄] `, description §3 pasted, character count under the limit.
- [ ] Danish title and description (§4) if the language is offered.
- [ ] Genre Survival / Escape (or the decided one); questionnaire done (Mild).
- [ ] Icon (the Christmas version, ICON_THUMBNAILS.md §3.1 "Christmas"), Home pool **T5 + T3**, details page order (ICON_THUMBNAILS.md §6), alt text on every image.
- [ ] Private servers on at 0.
- [ ] No handle, link, Discord name or QR code anywhere in the description, images or the game.
- [ ] E1 drafted (private), ready to make public after 15:00.
- [ ] Truth check §3.2 passes against the launch build.
- [ ] One person (the owner) reads the whole page aloud once, as if to a 10-year-old.

---

## 11. Decisions and open questions

**Decisions made in this file:** Danish title uses "Stjæl" (§2); "up to 8" / "up to 16" wording (§3); genre Survival → Escape (§6); Danish store text at launch if offered, with "in English for now" (§4); one event per drop with Dec 3 submission (§9); search query list written now, not in W3 (§7).

**Open questions for the owner:**
1. Does Creator Hub offer Danish for experience information? (Check on Nov 16 when filling the page.)
2. Exact limits: title (50?) and description (1,000?) characters, event title and subtitle lengths.
3. Which genre list does the dropdown show today? If "Survival / Escape" is gone, pick the closest heist / escape option, never "Puzzle".
4. Level names in Danish (Gift Tag, Wrapping Room, Snow Globe Vault) for the Jan 8 table: proposals are in the Danish text above; the owner decides.
5. The vault's *Publishing an Experience* note mentions an "exclude from Recommended For You" option under Manage Audience → Advanced, while MASTERPLAN §9.5 says no such switch exists. Either way we **do not** use it: launch goes public with recommendations on (the plan's path). The owner just confirms the toggle is off on Dec 3.
