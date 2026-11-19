# RAGDOLL HAVOC: the deep plan (2026-11-19)

Built from:
- research/AUDIT.md: the code, every DataStore, a diff of 0.14 against 0.17, and the owner's phone captures;
- research/COMPETITORS.md: 240 ragdoll games fetched live, and the 11-11 to 11-19 trend;
- research/COMMUNITY.md: TikTok, YouTube, Reddit and devforum signals (mostly search snippets, because the proxy blocks those sites);
- FINDINGS.md;
- the lessons from Heist Yourself (docs/audit/WHY_2_OF_10.md).

## Danish summary for the owner
RAGDOLL HAVOC er værd at redde, men ikke som "endnu en blodig dummy-sandkasse". Den kamp er vundet af Hyper Realistic Ragdoll (43.500 spillere), og Roblox har lige fjernet eller straffet tre af de største blodige spil.

Spillet taber i dag folk af fem grunde:
1. Controller-spillere (28 % af besøgene) kan slet ikke spille.
2. Telefonen holdes på højkant, men alt er bygget til at ligge ned, så knapperne ligger oven på hinanden.
3. De første 45 sekunder er fulde af pop-ups.
4. Der er intet at jagte efter minut 2.
5. Blod, afskårne lemmer og rigtige våben holder børnene ude.

Planen tager tre skridt:
1. **Ret de fem dræbere på 2 dage.**
2. **Gør spillet til den sjove og børnevenlige ragdoll-legeplads med vennerne** på 2 uger: slow-motion røntgen-replays, man kan dele, daglige eksperimenter og en samling at fylde op.
3. **Jul den 1. december, faste opdateringer og annoncer** først, når tallene holder.

## 1. Where we stand (numbers)
- **Players:**
  - 930 players and 1,126 visits. Median session 52 s; 55 % gone within 60 s; 13 % came back. Store page: 0 CCU, 5 upvotes / 2 downvotes, 17 favourites.
  - First visits: 67 % fired a shot, 21 % stayed 2 minutes, 7 % stayed 5 minutes. The median player made 3 takedowns, and 4 players ever played a minigame.
- **Money:** zero revenue. The game has no soft currency, and the owner's account holds 19 unopened eggs.
- **Market (11-19):**
  - The realistic-sandbox wave peaked in the week of Oct 26. One winner took it: Hyper Realistic Ragdoll went from 29.5k to 43.5k CCU while the rest fell about 75 %.
  - Gore titles were removed or forced to tone down: Ragdoll Physics 🩸 38.5k is gone, and Bloody Ragdoll 37k is down to 2.5k.
  - Growth now comes from "ragdoll + format or theme": MMA has 16k CCU, BloxNG crash physics has 21k and is rated all ages.
  - The leaders run 1-player servers, update every 1-2 days, and sell 12-22 passes.

## 2. Positioning decision
**Old:** "A ragdoll sandbox where every hit matters. Dummies have bones and organs…". This line is a near-copy of a competitor's description and is gore-rated.

**New:** a cartoon crash-test lab you wreck with your friends.

| Pillar | What it means | Why |
|---|---|---|
| **Mild rating, all ages** | No blood or severing, cartoon X-ray bones, "goo" or stars; renamed toy-style weapons | The moderation wave, plus BloxNG and Ragdoll Wars like ratios of 91-94 % |
| **The replay is the product** | Every big hit gets an automatic slow-mo X-ray replay, with "CLIP IT" and a share code | The most-loved moment in the genre, and nobody builds it ready-made |
| **Goals in 60 s chunks** | Daily Experiments, a Bone Journal collection, score runs on a board | The 52 s median session; sandbox loops die at the first fall |
| **Friends make it better** | 2-6 player prank sessions that actually run smoothly, plus co-op experiments | Every leader is 1-player; "smooth multiplayer" is white space |
| **Alive every week** | Updates on Thursdays and Saturdays, a [UPD]/emoji title, events with countdowns | Every winner signals life |

Keep everything that already works: the lab, the dummies, the weapons, grab/throw, builds and share codes, the greeter.

## 3. Phase 0: stop the bleeding (48 hours)
| # | Fix | Evidence | Done when |
|---|---|---|---|
| 0.1 | Full gamepad support: R2 fire, L2 aim, D-pad or bumpers for slots, Y catalog, X grab, B ragdoll, Select view | 28 % of sessions have a pad, and 84 % of those never shoot; the only binding is L3 (`Sprint.luau:140`) | A pad session fires in ≤ 5 s in a Studio pad test |
| 0.2 | Portrait phones: lay the HUD out for portrait as well as landscape (or force `LandscapeSensor` while it is rebuilt) | 95 % of phone sessions are portrait; overlaps confirmed in the captures | No overlaps on 390x844 portrait or landscape (LayoutCheck gets portrait cases) |
| 0.3 | No interruptions for 90 s: drop the view card on first visits, move the egg modal to ≥ 90 s or the first lull, merge toasts into one line | 74 % never answer the view card; the egg modal hits 70 % of sessions at about 27 s | The first 90 s show at most one non-blocking hint |
| 0.4 | Undo the 0.15/0.16 bar changes for new players: 6 slots, NextUnlocks hidden until minute 3 | Organic sessions fell from 81 s to 62 s; the first 15 s are unchanged | A/B over 1 week: median session back above 80 s |
| 0.5 | Mild content: `SEVERING = false`, blood off by default (cartoon goo or stars), rename and restyle the real guns (G17 → "Popper", AK → "Rattler", and so on) | Restricted/Moderate risk; competitors were removed | Questionnaire answered honestly, target Mild |
| 0.6 | Store page: an original, honest description (no 🩸, no console or VR claims until they work), a new title such as `[🎄] Ragdoll Havoc 💥`, 3+ new thumbnails, a video | The description is copied from Realistic Ragdoll Engine | All claims true |
| 0.7 | Measurement: stamp `game.PlaceVersion`; record pad and keyboard separately; store funnel steps 5-7 | Builds can't be told apart today | Every session record carries the version |
| 0.8 | Hide the "SOON" product cards; check that every product works | Dead cards | — |
| 0.9 | Pause ads | Ad traffic leaves in 33 s | — |

## 4. Phase 1: a first 60 seconds that hooks (days 3-7)
1. **0-3 s:** you spawn facing a dummy and the first tap or click or R2 fires. The hit plays a 1.5 s slow-mo X-ray bone crack with a big "CRACK! +50". The hit must land within 3 s for 95 % of players.
2. **3-20 s:** "Try the Launcher!", one new toy at a time, each with a bigger flop. The chaos meter fills.
3. **20-45 s:** the first **Experiment card**, one line long, for example "Launch a dummy into the pool": a goal, a timer and a star reward.
4. **45-90 s:** the auto-replay of your best hit, with **CLIP IT** and a **SHARE CODE**, then "NEXT EXPERIMENT ▶".
5. **Phone HUD:** at most 7 elements. Fire, the move stick, one 4-slot bar, Experiment, Shop, Menu, Ragdoll. Everything else goes into Menu.
6. **Tech:** one network owner per ragdoll for its whole life, a cap and pool on active ragdolls per tier, replicated pose at about 20 Hz. This answers the top community complaint, "laggy ragdolls on others' screens".

## 5. Phase 2: reasons to stay and return (week 2-3)
- **Daily Experiments:** 3 a day, the same on every server, so they make a TikTok format ("can you do today's?"), plus a weekly Big Experiment.
- **Bone Journal:** collect fracture types, combos and special reactions, like Ragdoll Research's journal but original. Rewards cosmetics and lab decor.
- **Soft currency "Bolts":** earned from experiments, the journal and playtime. Spent on toys, dummy skins and lab rooms. **Ration eggs**: 1 a day plus milestones, never 19 waiting.
- **Retune the ladder:** the first 5 unlocks come within 10 minutes, then a curve with a reachable 1-hour goal. Today it is 1,600 takedowns against a median of 3.
- **Monetisation ladder,** modelled on the leaders and kept fair:
  - an entry pack at 39-79;
  - "All Explosives", "All Melee" and so on at 69-129;
  - VIP lab (bigger lab, more dummies) at 199;
  - Events Pass at 199-299;
  - 2x Bolts at 129;
  - Everything at 499-999.
  - Slow-mo and replay stay free; paywalling them invites copycat "FREE GAMEPASSES" games.
- **Like-gated codes** (1k likes → code), shown in the lobby.

## 6. Phase 3: social, Christmas, growth (from 1 December)
- **Christmas lab, Dec 1-Jan 4:** a chimney launcher, a sleigh crash ramp, snowball cannons, an elf dummy and a present-wrap trap, plus a daily advent experiment. No top-25 ragdoll title has a holiday tag yet.
- **Friends:**
  - Prank Party: 2-6 players with shared dummies, a co-op experiment and "throw your friend" combos.
  - Private servers free.
  - Default server size: tested between 1 (the leaders' choice) and 6.
- **Update rhythm:** Thursdays and Saturdays with a [UPD] title. Each update adds 1 toy, 1 experiment set and 1 journal page.
- **Creators:** a YouTuber guide kit, a codes page, and three TikTok formats of 7-15 s: the X-ray bone crack, the daily experiment fail, and a friend-launch prank.
- **Ads:** only once the gates below are met.

## 7. KPI gates (measured from Session_v1 and Profile_v1)
| Gate | Today | Phase 0 target | Ads-on target |
|---|---|---|---|
| Median session | 52 s | 90 s | ≥ 4 min |
| Pad sessions that fire | 16 % | ≥ 90 % | ≥ 95 % |
| First visits that fire | 67 % | ≥ 90 % | ≥ 95 % |
| Stayed 5 min | 7 % | 15 % | ≥ 30 % |
| Came back (D1 proxy) | 13 % | 15 % | ≥ 20 % |
| Like ratio | 71 % | — | ≥ 85 % |

## 8. Lessons carried over from Heist Yourself (do not repeat)
1. Grade only real captures from phone, PC and console. Never trust Blender or code-only "looks fine".
2. Get to the action in seconds: no lobby, card or modal first.
3. Measure every build: version stamps, a per-device funnel, and the funnel tools (tools/funnel_report.luau pattern).
4. Kid-test before buying ads.
5. Small, safe steps, each one published and measured, rather than big rewrites.
6. Every store claim must be true, and every asset original.

## 9. How we work on it
- **Source:** the owner's project folder RagdollLab on their PC. Attach it with Remote Control (update the Claude desktop app), or save a `.rbxl` from Studio. The read-only script snapshot of v465 sits in /home/user/ragdoll-havoc/place, but it has no models, so it cannot be published from here.
- **Open Cloud key:** it now covers RAGDOLL HAVOC for Luau Execution and DataStore reads. Publishing also needs Places write.
- **Heist Yourself:** maintenance only. It stays live with its badges. Fix the `_TEST_` key issue before any future relaunch.
