# RAGDOLL HAVOC: what players and viewers say about Roblox ragdoll games (Oct-Nov 2026)

Researched 2026-11-19. Companion to `../FINDINGS.md`.

## Method and limits (read first)
- **Blocked by the session proxy:** reddit.com (incl. api.reddit.com), youtube.com, tiktok.com, devforum.roblox.com, x.com, medal.tv, bloxodes.com, rolimons.com, rowatcher.com, rotrends.com, statroblox.com, allthings.how, progameguides.com and the fan wikis. None of these pages could be opened. Everything from them comes from **search-result snippets** (titles, descriptions, scraped counts), so the URLs are cited but quotes are short and sometimes paraphrased.
- **Reachable and used directly:** the public Roblox web APIs (`games.roblox.com`, `apis.roblox.com`), read only, no login. The numbers in §0 are live readings taken on 2026-11-19.
- **Reddit:** web search returned **no indexed Reddit threads** on these games, so there are no Reddit quotes here. The player voice comes from YouTube/TikTok titles and captions, devforum threads, fan wikis and news.
- **View counts:** individual YouTube and TikTok view counts were mostly not available in snippets. Where a number appears, it is a hashtag total or a scraped like count, and it is labelled as such.

---

## 0. The competitive set, live from the Roblox API (2026-11-19)

| Game | Creator | Playing now | Visits | Like % | Max/server | Created | Maturity (API) |
|---|---|---:|---:|---:|---:|---|---|
| Hyper Realistic Ragdoll | Emo Playworks | 43,533 | 25.5M | 90.1 | **1** | 10-29 | Moderate: blood, fear, violence |
| BloxNG [CRASH PHYSICS] | Deform Dynamics | 21,470 | 13.5M | 90.7 | 10 | 10-13 | Minimal |
| Ragdoll Soccer | Ragdoll Athletics | 16,759 | 42.5M | **73.6** | 8 | 10-13 | Minimal |
| Realistic Ragdoll MMA | Ultimate Champion | 16,270 | 12.2M | **75.7** | 10 | 11-05 | Mild: blood, violence |
| Ragdoll Research | Ragdoll Shenanigans | 7,571 | 28.2M | 83.2 | **1** | 10-28 | Moderate: blood, violence |
| Ragdoll Destruction Playground | Harpax Dev | 6,466 | 7.3M | 80.6 | **1** | 11-03 | Moderate |
| Ragdoll Wars! | Ragdoll Wars Studios | 6,394 | 10.7M | **94.1** | **1** | 10-17 | Mild: blood, violence |
| [PHYSICS] Ragdoll Playground (2D) | Speedwagon Gaming Fdn. | 5,213 | 33.8M | **94.4** | 6 | 09-27 | Moderate: blood, violence |
| Technical Ragdoll MMA | Technical_MMA | 4,984 | 10.6M | 73.0 | 10 | 10-24 | n/a |
| Ragdoll Sandbox | Rise To Top | 4,156 | 25.2M | 84.9 | **1** | 10-16 | Minimal: blood, violence |
| Ragdoll Frenzy | JustEvolve | 3,295 | 10.3M | 83.5 | 12 | 11-03 | n/a |
| Realistic Ragdoll Engine | No Knees! | 2,508 | 49.5M | 86.4 | **1** | 10-12 | Moderate: blood, violence |
| [UPD] Ragdoll MMA | MattValidd | 213 | 22.4M | n/a | 10 | 10-20 | n/a |
| **RAGDOLL HAVOC** | (owner) | 0 | 1,304 | 71.4 | 10 | 11-05 | Minimal: violence |

Sources: https://games.roblox.com/v1/games?universeIds=10773618503,10770604649,10770730129,10774810800,10773425091,10774468211,10771544071,10768383600,10772689425,10771155665,10774452423,10770593871,10772041805,10774775314 · votes: https://games.roblox.com/v1/games/votes?universeIds=(same) · maturity: `POST https://apis.roblox.com/experience-guidelines-api/experience-guidelines/get-age-recommendation` · search listing: https://apis.roblox.com/search-api/omni-search?searchQuery=ragdoll

What the table says by itself:
- **The genre burns fast.** Realistic Ragdoll Engine has 49.5M visits but only 2.5k playing five weeks after launch. [UPD] Ragdoll MMA has 22.4M visits but 213 playing. The typical hit peaks 1-3 weeks after launch and then gets replaced by a newer one (same API sources).
- **The big sandboxes run one-player servers** (HRR, RRE, Research, Wars, Destruction Playground, Sandbox all have `maxPlayers = 1`). RAGDOLL HAVOC runs 10-player servers.
- **The best-liked games have something more than "hit dummy":** Ragdoll Playground (94.4 %: 2D, sand/water/lava, slow-mo, pause) and Ragdoll Wars (94.1 %: armies of ragdoll soldiers). The competitive games (Soccer 73.6 %, the two MMAs 73-76 %) collect the most dislikes.
- **RAGDOLL HAVOC's store description is almost word-for-word the Realistic Ragdoll Engine description** ("A Ragdoll sandbox where every hit matters. Dummies have bones and organs, reacting to exactly where and how you strike… Use tasers, restart hearts, or bring dummies back as zombies… Supports Desktop, Console, Mobile, Tablet, and VR Players!"). Compare the `description` fields of universes 10770593871 and 10774775314 at the URL above. That is the opposite of differentiation, and the console/VR claim is false given the shooting bug in FINDINGS.md.

---

## 1. What players love

| Moment / mechanic | Evidence | Source |
|---|---|---|
| **Locational damage you can see**: shoot a leg and the dummy limps; break it and it crawls | HRR leads its store page with this ("Shoot a leg and they limp, break it and they crawl"). Ragdoll Reality: "shooting a leg makes them collapse" | games API (10773618503); https://rolearn.dev/games/10770605947/ (snippet) |
| **X-ray / bone scan**: seeing *which* bone snapped | YouTube title "This Roblox Physics Game Has X-RAY BONE BREAKING..." (HRR, 2026-11-13). A guide says the Body Scan lets you "check whether the leg you targeted is the one that snapped" | https://www.youtube.com/watch?v=OKrqbbAkgH4 ; https://progameguides.com/roblox/complete-hyper-realistic-ragdoll-beginners-guide-roblox/ |
| **Slow-motion X-ray finish replays** (MMA) | Ragdoll MMA advertises "Knockouts, bone breaks and slow-motion X-ray finish replays"; a fan wiki has a whole page on them; Ragdoll X-Ray Reality: "X-ray cam shows broken arms and cracked skulls in slow motion" | games API (10772041805); https://www.ragdoll-mma.wiki/en/combat/ragdoll-mma-x-ray-finish-replays ; https://www.roblox.com/games/129022585182595/Ragdoll-X-Ray-Reality |
| **Slow-mo as a toy** | Ragdoll Destruction Playground's headline update is "SLOW MOTION… Epic time slow down!", sold as a R$199 "unlimited" pass. Ragdoll Playground binds G to slow-mo and Space to pause. Ragdoll Frenzy: "ride the slow-mo… pull off cool finishers". YouTube Short: "Ragdoll physics in SLOW MOTION 😂" | games API (10774468211, 10768383600, 10774452423); https://www.youtube.com/shorts/eGYFCMJd75M |
| **Dummies that react, talk and fight each other** | HRR: "Talk to the dummies: they answer, follow orders and help each other". Research: ragdolls "React to you, others, and the world… fight and be aggressive to one another". RRE: "Dummies interact with each other!" | games API (10773618503, 10773425091, 10770593871) |
| **Disaster events**: tornado, tsunami, meteor rain, black hole, nuke | In every top description (HRR, Playground, Wars "Nuke" pass, Experiment "nukes, tornadoes, crushers") | games API |
| **Anime / pop-culture powers** | Research sells "King of Curses" and "Strongest One" abilities and added "Sukuna-inspired powers" in Major Update 3. Ragdoll Playground sells JJK, JoJo, Naruto and Heroes packs. (These are borrowed IP, which this project's rules forbid; the lesson is "named superpowers", not the IP.) | https://apis.roblox.com/game-passes/v1/universes/10773425091/game-passes?passView=Full ; https://allthings.how/ragdoll-research-major-update-schedule/ (snippet) |
| **Collection / discovery loop** | Research: "Inject mutations into Ragdolls and unlock new journal entries". The guide says it "puts considerable emphasis on progression and discovery, giving you more reasons to keep experimenting than similar physics sandboxes" | games API; https://progameguides.com/roblox/top-5-ragdoll-physics-games-on-roblox/ (snippet) |
| **Squish / crush / fall off tall buildings** | Research: "Apply heavy weight and watch them SQUISH", "Throw ragdolls off TALL buildings and watch them CRUSH" | games API |
| **Grab and fling your friends** | Research: "Full MULTIPLAYER - Grab and Fling your Friends". Ragdoll Soccer and Football clips are about chaotic tackles and "trivela and bicycle kicks" | games API; https://www.tiktok.com/discover/ragdoll-football ; https://medal.tv/games/roblox/experiences/1beqsJFmxZqq93/ragdoll-soccer |
| **Ragdolling feels good when it's smooth** | A devforum commenter called a ragdoll "10/10"; another praised one as "buttery smooth, for you and for other clients aswell" | https://devforum.roblox.com/t/very-cool-fighting-game-i-made/2888452 ; https://devforum.roblox.com/t/smoothseamless-ragdoll-knockback/3173710 |
| **Bone-breaking as content** | Long-running YouTube format: "I BROKE ALL MY BONES…", "Roblox Ragdoll but I Jumped off a CLIFF and BROKE ALL My BONES", "Breaking Bones in Roblox… Most satisfying game" | https://www.youtube.com/watch?v=1LvdaN_vIS4 ; https://www.youtube.com/watch?v=TPZ8rZ-YeaM ; https://www.youtube.com/watch?v=xBwMYmlsGNU |
| **Soft-body destruction** (BloxNG) | "Metal crumples and folds exactly where it's hit… Wheels snap off, doors hang open, glass cracks". Roblox car-crash videos have been a meme format since 2018 and went big on TikTok in 2022 | games API (10770604649); https://amp.knowyourmeme.com/memes/roblox-car-crash-videos |

## 2. What players hate and complain about

| Complaint | Evidence | Source |
|---|---|---|
| **Lag / choppy ragdolls on other clients** | "Many popular games such as TSB or Heroes Battlegrounds suffer from this laggy ragdoll effect"; "the performance is killing my PC everything looks super choppy"; a developer "still hadn't found a way for a server to maintain many ragdolls without lag" | https://devforum.roblox.com/t/smoothseamless-ragdoll-knockback/3173710 ; https://devforum.roblox.com/t/very-cool-fighting-game-i-made/2888452 ; https://devforum.roblox.com/t/how-to-handle-mass-amounts-of-ragdolls/3599853 |
| **Ragdoll glitches**: flinging into space, exploding at speed, falling through the floor | Thread titles: "Ragdoll flinging into the stratosphere for no reason", "Ragdoll 'explodes' at high velocitys", "Ragdoll Goes Through Ground Due To NetworkOwnership Changing", "R15 Ragdoll Glitches out when hit hard" | https://devforum.roblox.com/t/2396417 ; https://devforum.roblox.com/t/ragdoll-explodes-at-high-velocitys/3539104 ; https://devforum.roblox.com/t/ragdoll-goes-through-ground-due-to-networkownership-changing/1119672 ; https://devforum.roblox.com/t/r15-ragdoll-glitches-out-when-hit-hard/2496066 |
| **Boring after the first fall** | A Broken Bones-style ragdoll dev reported "playtime (6-7mins) and D1 retention (3.70%) are pretty bad". A reviewer said players "tend to leave after completing their ragdoll fall". This matches RAGDOLL HAVOC's 52 s median session | search snippet of https://devforum.roblox.com/t/ragdoll-game-feedback/3924157 |
| **Competitive ragdoll games are frustrating** | Soccer (73.6 %), Realistic Ragdoll MMA (75.7 %) and Technical MMA (73.0 %) have the worst like ratios in the set, while sandboxes are at 83-94 %. Soccer's own page asks for "patience… early stages of development" | games votes API |
| **Paywalls on the fun parts** | HRR has 17 passes (Everything Pass R$699, Vehicle Pack R$549, Endless Events R$299, Double KO R$129…). Destruction Playground sells "Slow motion UNLIMITED!" R$199. Ragdoll Playground's Everything+ is R$999. Players respond with "free gamepasses" knock-offs ("Ultimate Ragdoll Engine🩸[FREE GAMEPASSES 📦]") | https://apis.roblox.com/game-passes/v1/universes/10773618503/game-passes?passView=Full (and per universe); omni-search listing |
| **Games vanish overnight (moderation)** | "Hyper Realistic Ragdoll just got deleted with 150k+ ccu at the time of the deletion" (X, ~11-15). YouTube: "Roblox Hyper Realistic Ragdoll SHUT DOWN!", "Roblox Just Removed 2 HUGE Ragdoll Games… 😳", "4 Roblox ragdoll games got BANNED? 😳". A fan wiki says it was "under review" and TikTok users were "expressing confusion". It is back (43k playing, updated 11-19) | https://x.com/ValraSwag/status/2122045577827381299 ; https://www.youtube.com/watch?v=OskAeu1eyNE ; https://www.youtube.com/shorts/XNTb2Ky7_Js ; https://www.youtube.com/shorts/cKFDKxjDvsI ; https://hyper-realistic-ragdoll.wiki/updates-and-availability/hyper-realistic-ragdoll-roblox-banned |
| **Gore and age concerns** | Commenters guessed the HRR takedown was over "the blood effects and the experience's age rating", and that it "was popular with a young audience". Roblox docs list "organs or intestines… dismemberment… severed body parts" as heavy / Restricted (18+ ID-checked) content | search snippet (wiki/YouTube comments) ; https://create.roblox.com/docs/production/promotion/content-maturity |
| **Clone fatigue** | Search for "ragdoll" returns ~40 near-identical "Realistic / Ultra / Super / Mega / Hyper Realistic Ragdoll 🩸" titles. "Mega Realistic Ragdoll" (created 11-13) copies HRR's weapon list. YouTube creator: Research is "the only ragdoll game left on Roblox" | omni-search listing; games API (10776343311); https://www.youtube.com/watch?v=NQ7xriHqqKo (snippet) |
| **Native Roblox ragdoll death split opinion** | When Roblox tested ragdoll deaths (March 2026), some found it "more natural and realistic", others saw it as "another step away from the old-school Roblox" | https://piunikaweb.com/2026/03/26/roblox-new-death-animation-ragdoll-physics/ ; https://mobilematters.gg/news/roblox/roblox-tests-new-death-animation-and-players-are-upset |
| **Exploit scripts** | "Hyper Realistic Ragdoll Script" videos promote godmode and bone healing | https://www.youtube.com/watch?v=E7SZKo7Kwws |

## 3. Viral clip formats

Hard numbers available (hashtag totals and scraped like counts, not single-video views):
- **#robloxragdoll ≈ 101.1M views** and **#ragdollphysics ≈ 73.5M views** (TikTok hashtag totals). Clips on the "ragdoll physics roblox" page range from 38 to 9k likes: https://www.tiktok.com/discover/ragdoll-physics-roblox · https://www.tiktok.com/discover/best-ragdoll-physics-in-roblox?lang=en
- The "roblox cool ragdoll physics" discover page shows a top figure of **38M** and is tagged #ragdoll #darkhumour #fyp: https://www.tiktok.com/discover/roblox-cool-ragdoll-physics
- Ragdoll Engine clips run up to **~34k likes / 454 comments**. Body-swap and spear-physics clips have **12.1k likes** and **36.3k likes**: https://www.tiktok.com/discover/ragdoll?lang=en · https://www.tiktok.com/discover/realistic-ragdoll-physics-body-swap
- Ragdoll MMA PvP clip "Best ragdoll game ever🥹 #ragdollmma": https://www.tiktok.com/@krxzy605/video/7700752162107739423
- Non-ragdoll comparison: "ragdoll physics in sewh will never not be funny" (horror game) shows ragdoll moments travel even outside ragdoll games: https://www.tiktok.com/@piplups._/video/7531749596809284894

Format patterns visible in titles and captions (none of the clips could be played, so the first 2 seconds are inferred from titles and descriptions, not watched):
1. **Impact first, no setup.** Titles promise the payoff: "X-RAY BONE BREAKING", "I BROKE ALL MY BONES", "Jumped off a CLIFF". Clips that stay on top open on the hit or the fall, with the X-ray or slow-mo replay as the second beat (https://www.youtube.com/watch?v=OKrqbbAkgH4 ; https://www.youtube.com/watch?v=TPZ8rZ-YeaM).
2. **Slow-mo replay of the knockout** is a built-in feature in MMA games because players clip it (https://www.ragdoll-mma.wiki/en/combat/ragdoll-mma-x-ray-finish-replays ; https://www.youtube.com/shorts/eGYFCMJd75M).
3. **Dark-humour caption + laughing emoji + trending sound**: #darkhumour tag, "😂", "will never not be funny" (https://www.tiktok.com/discover/roblox-cool-ragdoll-physics ; https://www.tiktok.com/@piplups._/video/7531749596809284894).
4. **Sports-fail compilations**: "best ragdoll goals, fails, and highlights", bicycle kicks, goal-line interceptions (https://www.tiktok.com/discover/ragdoll-football ; https://medal.tv/games/roblox/experiences/1beqsJFmxZqq93/ragdoll-soccer).
5. **Drama / news Shorts with 😳 and 😭**: "Roblox Just Removed 2 HUGE Ragdoll Games… 😳", "Hyper Realistic Ragdoll is GONE… play these instead 😭". The takedown made more Shorts than the game itself did (https://www.youtube.com/shorts/XNTb2Ky7_Js ; https://www.youtube.com/shorts/SaWaF8kK9ZQ).
6. **Long-form "guide" videos** within days of launch ("FULL GUIDE! (ALL Weapons Showcase, Get KILLS Fast)"), the standard push for every new hit (https://www.youtube.com/watch?v=ukS5YnIglM4 ; https://www.youtube.com/watch?v=ML_wYpjsYkI ; https://www.youtube.com/watch?v=QbWc-ZRKmyk).
7. **Clickbait adjectives**: "DIABOLICAL", "TOO FAR", "SHUT DOWN" (https://www.youtube.com/watch?v=HE_ksjpheZw ; https://www.youtube.com/watch?v=SoY9ijyKALk).

Length: Shorts/TikToks are the dominant format (most results are `/shorts/` or TikTok). Long-form reviews run around 10 min, e.g. Judge Holden "I Tested The Scariest Roblox Ragdoll Research Experiment!" at 10:51 (https://newgamescout.com/ragdoll-research, snippet).

## 4. The audience
- **Young.** GGRecon excluded Ragdoll Reality from its "fastest-growing" top 10 (it would have been #8) because "it isn't one we'd point younger readers towards" (https://www.ggrecon.com/articles/fastest-growing-new-roblox-games-november-2026/). Commenters say HRR "was popular with a young audience" (https://hyper-realistic-ragdoll.wiki/updates-and-availability/hyper-realistic-ragdoll-roblox-banned, snippet).
- **Speech register:** emoji-heavy, hype and drama words ("DIABOLICAL", "😳", "😭", "Best ragdoll game ever🥹"), kills/KOs as the number that matters ("Get KILLS Fast", "Get KOS FAST") (YouTube/TikTok URLs above). Indonesian-language Shorts also appear ("Main ini jadi psikopat #robloxindonesia"), so audiences outside English are real (https://www.youtube.com/shorts/22HIi1s5Syo).
- **Codes culture:** every hit runs codes ("WELCOME", "30MVisits", "Next code at 25k likes!"), and code articles from Destructoid, Dexerto and Pro Game Guides are the main press coverage (https://www.destructoid.com/ragdoll-soccer-codes/ ; https://progameguides.com/roblox/ragdoll-soccer-codes/ ; games API 10771155665).
- **Device mix:** every top game lists PC, mobile, tablet and console, and RRE and Research add VR (games API). FINDINGS.md shows 19 % of RAGDOLL HAVOC sessions are on console.
- **Platform scrutiny is rising:** Senate hearing on Roblox child safety, 2026-11-17 (https://www.deseret.com/family/2026/11/17/roblox-faces-scrutiny-as-survivors-tell-congress-their-stories/).

## 5. Requests and white space
Inferred from what top games advertise as "planned" or put behind paywalls, from what decays, and from what is missing. Direct player requests could not be read (Reddit and comment sections were blocked).
1. **Multiplayer sandbox that doesn't lag.** Destruction Playground: "*Multiplayer is planned*". The big sandboxes are all 1-player servers. Research is the exception and advertises "Full MULTIPLAYER - Grab and Fling your Friends" (games API). An open gap: **smooth 2-6 player co-op/prank sandbox**.
2. **A reason to come back.** Research is the only sandbox with a collection loop (mutations → journal) *and* a fixed update rhythm ("a new major update… roughly every ~4 days… Thursdays and Saturdays, 1:00 PM ET") (https://allthings.how/ragdoll-research-major-update-schedule/, snippet). Everyone else decays within weeks (§0).
3. **Shareable replay / slow-mo / X-ray cam in a sandbox.** MMA games have finish replays, but no sandbox auto-builds a clip-ready replay of your best moment (§1, §3).
4. **Free slow-mo and events.** Players see slow-mo and events as core fun, but they are paywalled (R$199-299) and get copied by "FREE GAMEPASSES" clones (§2).
5. **Non-gory "Minimal"/"Mild" physics comedy** that young players can reach: BloxNG (Minimal) and Ragdoll Wars (Mild) are top-liked, and organ/gore games get flagged or taken down (§0, §2).
6. **Goals inside the sandbox:** Ragdoll Sandbox added "Wanted stars + kill streaks", Rampage added "Scenarios: rob a house…", Frenzy added "dodge the train and pull off cool finishers". Small objectives are the current direction (games API 10771155665, 10772592155, 10774452423).
7. **Character building:** Ragdoll Playground's "Character Builder" (R$299), Research's "Ragdoll Editor" with custom names and accessories that "fly off with physics" (pass API; https://allthings.how/ragdoll-research-major-update-schedule/, snippet). Players want *their* dummy.

## 6. Developer lessons
**Tech**
- **Avatar Joint Upgrade is live (Jan 2026).** With `StarterPlayer.AvatarJointUpgrade = Enabled`, R15 characters spawn with AnimationConstraints + BallSocketConstraints instead of Motor6Ds. Weaken or disable the AnimationConstraints to ragdoll, and set `CharacterBreakJointsOnDeath = false`. Known issue: "choppy physics replication on other characters". R6 is not covered, and Motor6D is to be deprecated (https://devforum.roblox.com/t/avatar-joint-upgrade-for-physically-simulated-character-movement-is-now-live/4298561 ; https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint.md ; https://devforum.roblox.com/t/studio-beta-avatar-joint-upgrade-enabling-physically-simulated-characters/3266099).
- **Network ownership is the main cause of stutter.** "When network ownership changes there's effectively a pause in simulation of that body". Keep one owner for the whole ragdoll from start to finish, with the root part as the ownership unit. Breaking joints resets ownership on all parts. Server-owned NPC ragdolls are choppy, so give them to a nearby client or simulate client-side and sync state (https://devforum.roblox.com/t/r15-ragdoll-is-only-smooth-on-one-client/3448909 ; https://devforum.roblox.com/t/r15-ragdoll-public-domain/31291 ; https://devforum.roblox.com/t/choppy-npc-ragdolls-on-the-server/4252671 ; https://devforum.roblox.com/t/network-ownership-and-client-sided-ragdolls-messing-up/2866661).
- **BallSocket tuning:** problems were fixed by "altering the RootPriorities as well as disabling the BallSocketConstraint Limits". BallSockets break with custom client position replication (https://devforum.roblox.com/t/ballsocketconstraints-break-when-custom-client-position-replication-is-enabled/3561821 ; search snippet).
- **Scale:** HumanoidStateType.Physics is "extremely ineffective… 5-10 ragdolls at once". Despawn or pool ragdolls, cap active ones, and update at a 20 Hz cycle ("the biggest performance saver" in a 10,000-NPC demo). Client-side ragdolls with only the initial state synced is the Halo approach. Profile first (https://devforum.roblox.com/t/humanoidstatetype-physics-alternative/1282420 ; https://devforum.roblox.com/t/reduce-lag-when-having-alot-of-ragdolls/1876872 ; https://devforum.roblox.com/t/10000-physical-npcs-running-with-60-fps-on-low-end-device/3660293 ; https://devforum.roblox.com/t/how-to-handle-mass-amounts-of-ragdolls/3599853).
- **One-player servers sidestep all of this**, which is likely why the top sandboxes use them (§0).
- **Soft-body on Roblox is faked** with bones in a skinned mesh, or constraints ("can't… without killing everyone's frame rate, but we can definitely fake it") (BloxNG search snippets; https://devforum.roblox.com/t/cars-that-hit-and-be-hit/115505/14).

**Growth**
- **Launch timing:** 12 of 127 new games since September had "ragdoll" in the title, which GGRecon calls "a genuine trend" (https://www.ggrecon.com/articles/fastest-growing-new-roblox-games-november-2026/). Ragdoll Sandbox went from 118k to 4.07M visits in one week, 10-27 → 11-03 (https://ragdollsandbox.net/roblox/, snippet).
- **Scheduled updates as events:** Research runs a 2×/week update cadence. RRE ran "ADMIN ABUSE!!" (Oct 25-31) and a "HUGE UPDATE" event (Nov 14-16) with countdown pages that third-party sites track (https://allthings.how/ragdoll-research-major-update-schedule/ ; https://allthings.how/realistic-ragdoll-engine-events-schedule/).
- **YouTube guides and codes press** follow within days for every hit (§3, §4).
- **Like-gated codes and updates** ("Next code at 25k likes!", "👍 Like the game for more updates!") (games API).
- **Monetisation that works in the genre:** an "Everything" pass (R$499-999), category unlock packs (R$69-349), unlimited events/slow-mo (R$199-299), vehicles (R$249-1,299). There are no lootboxes in the top set (pass API per universe).
- **Moderation is a growth risk.** HRR lost a 150k-CCU peak to an "under review" takedown. Organs and dismemberment are Restricted under the docs (§2).

---

## 7. Implications for RAGDOLL HAVOC (prioritised)

**P0: fix before any more traffic**
1. **Rewrite the store description and thumbnail now.** It is a near-copy of Realistic Ragdoll Engine's text. Lead with what is unique, and drop "Console and VR" until gamepad shooting works (§0; FINDINGS.md #1).
2. **Ship gamepad shooting** (ButtonR2/ButtonA + aim assist). Every top competitor claims console support and 19 % of sessions are on console (§4; FINDINGS.md).
3. **Make the first impact happen in under 3 s, auto-aimed if need be, with a slow-mo + X-ray beat on the first big hit.** Players love seeing the bone break, and that moment is the clip (§1, §3). This targets the 52 s median.
4. **Decide the maturity lane deliberately.** Organs and severing put the game under Restricted (18+) and led to HRR's takedown. Recommended: turn `SEVERING` off, use stylised "goo"/X-ray bones instead of organs, and target Mild. BloxNG (Minimal) and Ragdoll Wars (Mild) prove the top like ratios don't need gore (§2, §0).
5. **Fix ragdoll ownership before adding content.** Use a single owner per dummy for its whole life (the spawning or nearest client for co-op, the server only if needed), a cap on active ragdolls, pooling, and `AvatarJointUpgrade` for player rigs. Lag is the #1 complaint in the genre (§2, §6).

**P1: differentiation (pick one hook and own it)**
6. **Own "multiplayer prank sandbox".** The leaders are 1-player and Destruction Playground says multiplayer is only "planned". Make 2-6 player co-op smooth (grab and fling friends, team events) and say so in the title/icon (§5.1).
7. **Built-in clip maker:** auto-record the last ~8 s, with a one-button slow-mo X-ray replay and a "share" pose/caption card. That turns players into TikTok marketers (§3, §5.3).
8. **A collection loop past minute 1:** a "Bone Journal"/injury codex (break every bone type, find combos, unlock reactions), like Research's mutation journal (§5.2).
9. **Small goals in the sandbox:** daily "experiments" (e.g. "break 3 femurs with one fall"), streaks and stars, following Sandbox/Rampage/Frenzy (§5.6).
10. **Free slow-mo and at least one free event.** Monetise "unlimited" and cosmetic variants, not the core fun, which competitors' "FREE GAMEPASSES" clones exploit (§2, §5.4).
11. **Customisable dummy** (name, face, outfit, accessories that fly off with physics), using own art, no borrowed anime IP (§1, §5.7; CLAUDE.md originality rule).
12. **Dummies that react to each other and to the player** (flinch, run, help an injured dummy). Reactive AI is a headline feature in HRR, RRE and Research (§1).

**P2: live ops and growth**
13. **Fixed public update rhythm** (e.g. Thu + Sat), each with a countdown and one headline toy or event, and a timed "admin abuse"-style event once a week (§6).
14. **Like-gated codes** ("next code at 1k likes") and a launch code in the description (§4, §6).
15. **Pitch small and mid YouTubers** with a guide-friendly kit: weapon list, best combos, codes. Every hit gets "FULL GUIDE!" videos within days (§3).
16. **Seed TikTok with 3 formats:** (a) hit-first slow-mo X-ray bone break with "😂" caption and trending sound, (b) friends-prank fail compilation, (c) "would you rather" or "which bone breaks first" quiz hooks. Keep them 7-15 s and show the impact in the first second (§3).
17. **Run ads only after P0 is fixed.** Ad traffic left at a 33 s median (FINDINGS.md #4), and the genre's lifetime is weeks (§0).
18. **Monetisation template:** an Everything pass (~R$499), category packs (R$69-149), unlimited events (R$199), a fun vehicle (R$249-399) and cosmetics. Avoid power multipliers in PvP (§6).

**P3: watch and avoid**
19. **Avoid head-to-head competitive modes** (soccer, MMA) as the core. They have the lowest like ratios and need netcode polish (§0, §2).
20. **Don't add a "Hyper/Ultra/Mega Realistic" name or 🩸 title.** It blends into ~40 clones and signals gore to moderators (§2).
21. **Track the next takedown wave and Roblox's ragdoll-death defaults.** If organ games get banned, a clean lane is a competitive advantage. Watch for the Motor6D deprecation (§2, §6).
22. **Treat exploit risk early.** Script videos target these games ("godmode, bone healing"), and RAGDOLL HAVOC's server-authoritative damage should stay that way (§2).
