# Echo Heist: Virality, Launch and Live-Ops Plan

_Dimension: virality, launch and live-ops (TikTok and Roblox discovery). Written 2026-11-12. English._

_How to read this: a fact carries a citation (web URL, or a vault note in italics). Anything labelled **Decision**, **Recommendation** or (H) for heuristic is our call, not a fact. [UNVERIFIED] marks claims I could not confirm. This document builds on `docs/VIRAL_PLAYBOOK.md` and aligns with the sibling reports `docs/research/design.md` (Heist Replay, medals, Vault of the Day, P0-P3 schedule) and `docs/research/visuals.md` (Neon-Noir Diorama, cyan echoes, 12-15 s Heist Reel)._

---

## Summary

**The mechanic is a clip engine; the name is not.** Every heist ends with up to 12 copies of you moving in sync. Nothing on Roblox looks like that, and it reads in one second with the sound off. The plan has three jobs:
1. make the game cut and offer that shot automatically;
2. make the first session good enough that the traffic it brings stays;
3. clear the 2026 under-16 gate before the Christmas school break.

**Decisions:**
1. **Don't ship as "Echo Heist".**
   - An itch.io *Echo Heist* (2026) has the same premise.
   - Roblox already has *ECHOES: Clone Puzzles*, the same mechanic, with 1 player online.
   - Kids search "clone", "rob" and "heist", not "echo".

   **Store title: "Rob With Your Clones".** Runners-up: "Heist Yourself" and "Rewind & Rob".
2. **Eight sound-off clip formats,** led by "8 OF ME" and "MY CLONE BETRAYED ME". The game produces them through a captioned 12-15 s **Heist Reel**, a server **blooper log** and a one-tap **SAVE CLIP** (`CaptureService` video, with a screenshot fallback). Shares carry launch data, so a viewer lands in the level from the clip.
3. **Launch dates:**
   - **Soft launch Thu Dec 3** (16+ trial, RFY off).
   - **~$300 of Engagement-objective ads** plus 20-30 micro creators push toward the Kids & Select threshold of 500 highly engaged plays.
   - **RFY opens Fri Dec 11** with the "Steal Back Christmas" update, and the creator embargo lifts Sat Dec 12.
4. **Bars anchored to GameAnalytics medians** (D1 10.3%, D7 1.6%; top 1%: 22.2% and 9.1%):
   - kill or rework: D1 under 8%;
   - healthy: D1 15% or more;
   - double down: D1 22% or more and D7 6% or more.
5. **8-week calendar** (Dec 3 to Jan 27): three Christmas chapters, a "12 Vaults of Christmas" advent run of daily mini-vaults (Dec 13-24), a publish freeze over Dec 24-27, the Museum on Jan 8 to catch the post-event cliff, and a co-op update with Season 1 on Jan 22.

---

## Findings (with citations)

### F1. Roblox discovery now
- **RFY signals.** Most important: play-through rate (PTR), first-play bounce (<60 s and 61-180 s), play days and playtime per user. Then intentional co-play days (join, invite or private server, never matchmaking), qualified sessions, spend days and Robux per user. PTR and bounce count **only organic RFY joiners in their first session** ([Discovery FAQ](https://create.roblox.com/docs/en-us/discovery-faq.md), [Discovery](https://create.roblox.com/docs/en-us/discovery.md)).
- **The window is 28 days.** Since June 2026, signals are measured separately for D1, D2-7 and D8-28 ([newsroom 2026-06](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox), [DevForum](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575)). A secondary report says Roblox accepted the short-term monetisation hit on purpose ([GodisaGeek](https://godisageek.com/2026/08/roblox-9-billion-algorithm-change/)).
- **Ads, TikTok and share links don't raise RFY ranking** (*Sponsored Ads and Campaign Math*; GAME_BIBLE 4.1).
- **Gameplay videos now play on Home** inside RFY ([DevForum](https://devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601)). The rules: 3 uploads a month, real footage only, no narration or lyrics ([Thumbnails docs](https://create.roblox.com/docs/production/publishing/thumbnails.md)). Reviews can take weeks ([DevForum](https://devforum.roblox.com/t/video-thumbnail-review-taking-weeks/4749618)).
- **Thumbnail personalisation:** 2-5 active, an hourly bandit scored on PTR. It averaged +8.5%, up to +50% ([DevForum](https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233)). There is little signal under about 1,000 DAU and no native icon test (*trend-games-research* §4.3).

### F2. The under-16 gate (with a conflict)
- **New games reach only age-checked 16+ users** until they pass the Kids & Select evaluation ([Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select)).
- **The threshold conflicts.** The English page says **500 unique plays by highly engaged players in 60 days**; some localised pages still say 250. *Decision: plan for 500 and trust the Audience Reach dashboard.*
- **Highly engaged** means account tenure, playtime in our game, and any Roblox purchase in the last 60 days.
- **All-ages requirements:** ID/age check, 2SV, two months of Plus **or** a refundable 1,000 R$ fee, the full questionnaire, and a Minimal/Mild rating (Kids) or up to Moderate (Select) (*Publishing an Experience*).
- **The Engagement ad objective (beta)** targets players who count toward the threshold. It has a higher CPP than Plays, does **not auto-pause**, and Roblox wants it on a separate budget ([Ads Manager](https://create.roblox.com/docs/en-us/production/promotion/ads-manager), [DevForum](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717)).
- **Ad costs.** Plays CPP runs about $0.007-0.011 [Reported, Naavik]; no Engagement CPP is published. Objective, audience and budget type can't be changed after creation. Join options carry launch data (*Sponsored Ads and Campaign Math*).
- **Kids & Select games may not reward watching media feeds** ([DevForum](https://devforum.roblox.com/t/roblox-kids-and-select-new-restrictions-on-reward-driven-media-feeds/4829188)).

### F3. Capture and sharing tools
- **CaptureService** (all current in the vault's API snapshot) has `CaptureScreenshot`, `CanCaptureVideo`, `StartVideoCaptureAsync`, `StopVideoCapture`, `PromptSaveCapturesToGallery`, `PromptShareCapture(content, launchData, …)` and `UploadCaptureAsync` ([reference](https://create.roblox.com/docs/reference/engine/classes/CaptureService#PromptShareCapture)). Video support in the share prompt was "planned soon" ([DevForum](https://devforum.roblox.com/t/beta-video-captures-api-bring-your-gameplay-moments-to-life/3823116)); whether every device can share video today is **[UNVERIFIED]**.
- **Roblox Moments** (13+ beta) is an in-app feed of clips up to 30 s, and experiences may prompt sharing of peak moments ([newsroom](https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery), [TechCrunch](https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more)). The Upload and Recommendations APIs are in beta ([DevForum](https://devforum.roblox.com/t/beta-content-sharing-apis-use-upload-api-and-recommendations-api-to-drive-discovery-and-engagement/4065417)).
- **Share links** come from `SocialService:PromptLinkSharingAsync` (the non-Async name is deprecated) and carry launch data of 200 bytes or less ([DevForum](https://devforum.roblox.com/t/introducing-the-share-link-api-deep-link-players-directly-into-the-action/3972678), [Deep links](https://create.roblox.com/docs/production/promotion/deeplinks)).
- **Audience Expansion** pays 35% of a new user's first $100 of spend in 60 days when they arrive by share link or name search and play 10+ minutes. The game needs 100+ DAU (*Short-Form Video Marketing* §4).
- **Experience Events.** Trending Events needs an event started in the last 7 days with 1,000+ RSVPs ([docs](https://create.roblox.com/docs/en-us/production/promotion/experience-events)). `SocialService:PromptRsvpToEventAsync` is current. Submit featuring 7+ days ahead ([DevForum](https://devforum.roblox.com/t/introducing-off-platform-featuring-for-creator-events/4142230)).

### F4. What spreads, and how traffic behaves
- **Clip craft:** hook in 1-2 s, no logo first, text in the middle 70%, 15-30 s at 9:16, and a twist visible in one sentence (*Short-Form Video Marketing*; *Viral Game Anatomy*). Clips with an unclear outcome get skipped [vendor] ([Eklipse](https://blog.eklipse.gg/basic-knowledge/best-games-to-stream-for-viral-clips.html)), so we burn in result text.
- **TikTok spikes are huge and short.** A viral TikTok can take a game from 0 to 100K CCU in under 48 h, then decay within days. YouTube effects last weeks [vendor] ([RoLearn](https://rolearn.dev/trend-reports/roblox-youtube-tiktok-content-trends-2026)).
- **Virality is distributed.** It often starts with mid or micro creators ([RoWatcher](https://rowatcher.com/news/how-youtubers-and-tiktokers-move-the-charts-in-2026)). RoWatcher advises against macro deals for games under 10K DAU, recommends 10K-50K genre-fit creators, and says to spend nothing on influencers below about 25% D1 [vendor opinion] ([macro](https://rowatcher.com/news/why-macro-influencers-kill-small-roblox-games-and-what-works-instead), [conversion](https://rowatcher.com/news/roblox-influencer-marketing-has-a-conversion-problem-not-a-reach-problem)). For outreach: start 4-6 weeks ahead, keep pitches under 150 words, send DMs, offer early access [vendor] ([RoLearn](https://rolearn.dev/guidance/partnering-with-roblox-content-creators)).
- **Seasonal cliffs are steep.** The week after Halloween 2026, Murder Mystery 2 fell 84% and Steal a Brainrot 70% ([RoWatcher W44](https://rowatcher.com/news/roblox-week-in-numbers-2026-w44), [Halloween](https://rowatcher.com/news/roblox-halloween-spike-hits-14-9m-ccu-winners-losers)).
- **The holiday season is big.** Q4 2025 DAU was a record 144M ([Statista](https://www.statista.com/statistics/1192573/daily-active-users-roblox/)). The 2024 Winter Spotlight featured 24 games, 4 a day over 17 days ([newsroom](https://about.roblox.com/newsroom/2024/12/roblox-winter-spotlight)). No 2026 winter platform event has been announced [Reported] ([ofzenandcomputing](https://www.ofzenandcomputing.com/what-is-the-next-roblox-event-winter/)).
- **Retention medians** from GameAnalytics (500+ Roblox games, Aug 2025 to Jul 2026): **median D1 10.3%, D7 1.6%; top 1% D1 22.2%, D7 9.1%** ([summary](https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox), [report](https://www.gameanalytics.com/reports/2025-roblox-report)). Vendor tables claiming a 10-20% D7 conflict with this ([RoWatcher](https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like)). The Creator Hub scorecard needs 100+ DAU ([Retention docs](https://create.roblox.com/docs/en-us/production/analytics/retention)).

### F5. Thumbnails, icons and titles (vault)
- **Icons are faces.** 8 of the 10 top icons are a face looking at the viewer, with a bright point near the eyes and almost no text (*Cross-Game Patterns - Thumbnails Icons and Titles*).
- **Thumbnails** (*Thumbnail Composition for High CTR*; *Thumbnail Specs*):
  - one focal subject at 30-45% of the frame, on a thirds point;
  - an emotional face;
  - value separation that passes a greyscale test;
  - no wide map shots and no five-character lineups;
  - no text along the bottom edge;
  - 1920×1080 and under 3 MB, plus an icon of 512 px or more checked at 150 px.
- **Show only what is in the game.** No Robux imagery and no external handles.
- **Titles are verb + noun** ("Steal An Egg", "ROB IT"). Seasonal bracket tags signal freshness. Never borrow a brand (*Viral Game Anatomy* §4).
- **Our rules:** cyan belongs to echoes, and no heist masks (Notoriety owns them) (`visuals.md`).

### F6. Live market and conflicts (measured 2026-11-12)
- **Heist demand is fresh:**

  | Game | Visits | Online now | Created |
  |---|---|---|---|
  | ROB IT | 315M | 1,701 | 2025-12 |
  | Heist Evolution | 2.4M | 2,172 | 2026-05 |
  | Risky Heist | 354K | 1,883 | **2026-10-29** |
  | Bobo Heist | 24M | 148 | Mild 9+ |

  None of them uses self-co-op.
- **"Clone" is a search magnet.** Clone Engine has 417M visits (1,792 online) and Clone Friends 151M (1,241). Both are follow-me sandboxes.
- **The same mechanic already exists on Roblox:** *ECHOES: Clone Puzzles* (universe 10769139317). Its pitch is "Record your movements. Create a clone. Solve puzzles with your past self". It has 28 levels, was created 2026-10-03, and has **20,925 visits and 1 player online**. Puzzle framing plus neon looks didn't pull. The heist fantasy, co-op chaos and the clip engine have to carry us.
- **Off-platform twins:**
  - itch.io ***Echo Heist*** (2026-01-08): a time-loop museum heist where "each loop creates an echo of your previous run" ([itch](https://geronimokuwait.itch.io/echo-heist), [devlog](https://geronimokuwait.itch.io/echo-heist/devlog), [nitrous-studio](https://nitrous-studio.itch.io/echo-heist)).
  - Playgama ***Rewind Robbers*** (Kai Chen, Oct 2026): earlier takes "act as your crew" across a **bank, art museum and casino**, "get the loot to the van", in a clay-toy style ([Playgama](https://playgama.com/game/rewind-robbers)).
  - Jam games *Loop Heist*, *Timeloop Heist* and *A heist in 60 seconds* ([itch](https://gohgames.itch.io/timeloop-heist), [itch](https://cswkr.itch.io/a-heist-in-60-seconds)).
  - Steam *Grand Theft Timeline* (co-op time-travel heist, Q4 2026) ([Steam](https://store.steampowered.com/app/4928450/)).
- **Implication:** the mechanic is free and unproven on Roblox. "First in the world" is false, so the title and the look must be clearly our own.

---

## Recommendations / decisions

### R1. Title: 10 candidates, checked; recommend 3

Every candidate was searched on Roblox and on the web on 2026-11-12. "Clean" means no title collision found.

| # | Candidate | Roblox search | Web search | Verdict |
|---|---|---|---|---|
| 1 | **Echo Heist** | No exact title, but *ECHOES: Clone Puzzles* (same mechanic) and *ECHOES* horror (300K visits) | **itch.io *Echo Heist* (2026) with the same premise** | **Reject** as a store title. Keep it as the code name |
| 2 | **Rob With Your Clones** | Clean. Neighbours are Clone Engine and Heist Evolution, which is good company for "Similar Experiences" | Clean | **Recommend #1** |
| 3 | **Heist Yourself** | Clean | Clean | **Recommend #2** |
| 4 | **Rewind & Rob** | Clean (closest match is "Rowind", a retro simulator) | Clean (only "Robo Rewind" jam games) | **Recommend #3** |
| 5 | Rewind Robbers | Clean | **Playgama *Rewind Robbers* (Oct 2026), same concept** | Reject |
| 6 | Loop Heist | Clean | **itch.io jam game *Loop Heist*** (and Timeloop Heist) | Reject |
| 7 | Rob It Again | Surfaces **ROB IT** (315M visits) first | Clean | Reject: confusable, and near-duplicate metadata is deprioritised |
| 8 | Clone Heist | Clean; Clone Engine and Clone Friends nearby | Clean | Backup. Noun + noun, so weaker than #2 |
| 9 | Crew of Me | Clean | Clean | Reject: no verb, nobody will search it |
| 10 | Steal With Yourself | Clean | Clean | Reject: awkward to say |

**Decision: launch as "Rob With Your Clones".**
- **It's the whole game in four words:** "Rob" is what you do, "Your Clones" is who helps.
- **It's kid vocabulary.** TikTok captions will say "clones" anyway.
- **It sits next to two proven search clusters:** rob/heist (ROB IT) and clone (Clone Engine, Clone Friends).
- **It fits a Home tile:** about 20 characters, no "x2", "Robux" or "Blox".

During events, use a seasonal tag: "[🎄] Rob With Your Clones".

**"Heist Yourself"** stays as the slogan and hashtag (#heistyourself), and as the fallback title if the owner prefers a two-word brand.

**Trademark:** check the EUIPO and USPTO registers before launch. I could not query them [UNVERIFIED]; this is not legal advice.

**Knock-on decision for the design dimension:** use "clone" as the player-facing noun ("Clone Deck", "Retake clone #2") and keep `Echo` in code and docs. This is an open question because `design.md` and `visuals.md` say "echo".

### R2. Signature TikTok clip formats

All eight are sound-off readable. The game produces each one on purpose.

| # | Format (on-screen hook text) | What we see in 0-2 s | How the game generates it |
|---|---|---|---|
| 1 | **"8 OF ME"** | The final loop: 8 cyan copies of one avatar moving in perfect sync, vault door opening | The **Heist Reel** auto-plays after every Big Score: 12-15 s, three cinematic angles, one slow-motion beat, framed for a 9:16 crop. A burned-in caption shows "LOOP 6 · 8 OF ME · $1,000" |
| 2 | **"MY CLONE BETRAYED ME"** | A clone presses the alarm or steps off the plate, and the door slams on the live player | A server **blooper log** records cause-tagged failures (blocked, zapped, busted, door-crushed) with timestamps. The reel's end card offers a "Blooper" cut of the 2 funniest |
| 3 | **"HE DOES IT EVERY TIME"** | The same clone walks into the same laser, loop after loop | The blooper log flags a clone that fails at the same spot in 2+ loops and stitches its failures into a 6 s cut |
| 4 | **"WRONG ONE"** | The guard grabs a clone, freezes in a "huh?" pose, and the real player sneaks past behind | The guard's fixed 2 s confused freeze (design rule) plus a "?" bubble, auto-bookmarked when a live player passes within the vision cone during the freeze |
| 5 | **"THE PLAN → THE HEIST"** | Top-down Blueprint with glowing route lines, then a hard cut to real-time execution | The **Blueprint plan view** (`visuals.md`) is recordable, and the reel can open with 3 s of Blueprint |
| 6 | **"DEV: 4 CLONES. ME: 3"** | Medal screen with the developer's count crossed out | The Diamond medal ("beat the developer's echo count") plus Vault of the Day. The result card shows the date seed, so viewers can try the *same* vault |
| 7 | **"4 FRIENDS, 16 THIEVES"** | Four colour-coded crews flooding the vault | Crew outline colours (blue, orange, green, pink) and number badges. The reel picks the angle with the most actors in frame |
| 8 | **"LOOP 1 vs LOOP 7"** | Split screen: alone and caught, then the full crew succeeding | The reel's optional "Then/Now" mode places the first loop's recording beside the final loop |

**Seasonal variant, Dec 11 to Jan 4:** "STEALING BACK CHRISTMAS WITH 8 OF ME". Clones carry presents out of Sir Hoardsworth's Snow Globe Vault.

**Clip pipeline** (recommendations, using current APIs):
1. **The reel is a client-side replay** of the final loop's recordings. It hides HUD, chat and all nameplates (child safety) and shows a small wordmark only in the last second.
2. **SAVE CLIP** records the reel with `StartVideoCaptureAsync`/`StopVideoCapture` when `CanCaptureVideo()` is true, and otherwise takes a screenshot. The player then picks **Save** (`PromptSaveCapturesToGallery`) or **Share** (`PromptShareCapture`) with launch data `v1|reel|<levelId>`, so viewers land in that level.
3. **Never auto-prompt, and never reward sharing or watching** (the F2 rule). The only reward is a referral cosmetic, granted after the invited friend plays 10 minutes.
4. **Moments upload** (`UploadCaptureAsync`, beta) stays behind a config flag until it has been tested on a real device.
5. **Owner kit:** a capture place, freecam, and a "director" command that replays the day's best blooper. The owner films and posts, because cloud sessions can't.

### R3. Icon and thumbnails

**Icon (one).**
- A tight crop of our own "rookie robber" face: an original character with a cap and a scarf, **no mask**. The face looks at the viewer with a smug side-eye.
- **Two to three cyan translucent copies of the same face** fan out behind it, offset by about 8% each. That is the twist at 150 px.
- Deep-indigo background, one gold glint near the eyes, no text.
- A Santa hat on every copy from Dec 11. It must read in greyscale at 64 px.

**Home thumbnails (five), each a different true promise and each a staged real scene:**

| # | Concept | Focal subject (30-45% of frame) | Text (3 words or fewer, upper third) |
|---|---|---|---|
| T1 | Sync heist | The hero in front carrying a gold bar, 7 cyan clones in a V formation behind, vault light pouring out | **8 OF ME** |
| T2 | Betrayal | The hero's shocked face, lit by a guard's flashlight. Behind him a cyan clone presses a big red alarm | **BETRAYED!** |
| T3 | Guard confusion | A guard holding a cyan clone by the collar with a "?" bubble, while the hero tiptoes behind with the diamond | **WRONG ONE!** |
| T4 | Co-op | Four colour-outlined crews colliding at the vault door | **16 ROBBERS** |
| T5 | Christmas (from Dec 11) | Snow-globe vault cracked open, clones hauling presents, Sir Hoardsworth furious in the background | **STEAL BACK XMAS** |

**Rules:**
- 4 active on Home (T5 replaces T4 during the event). Never delete a loser; it may win a segment.
- **Video thumbnail:** the Heist Reel, uploaded by **Mon Nov 30**, because reviews are slow. A Christmas video goes up Dec 7.
- Ads reuse the same set.

### R4. Launch plan (dated, under the 2026 rules)

| Date | Action | Why |
|---|---|---|
| **By Nov 16** | Owner: **ID/age check and 2SV**. Pay the **1,000 R$ refundable fee**, since two months of Plus is too slow unless already active. Ads billing needs an 18+ card or ad credits | All-ages publishing requires these (*Publishing an Experience*) |
| Nov 16-30 | **Greybox devlog clips**, 4 a week on TikTok and Shorts: "I made a Roblox game where your past self is your teammate" | A free hook test, before the art exists |
| Nov 19 - Dec 2 | Analytics (R5). 10-20 outsider phone playtests. Capture place | Fix bounce before any traffic |
| Nov 24 - Dec 1 | Creator shortlist and outreach (below) | |
| By Nov 30 | Upload the reel video thumbnail, T1-T4 and the icon. Share links per channel: `tt_bio`, `yt_bio`, `creator_<name>`, `ad_eng`, `ad_plays` | Reviews are slow; every source gets its own D1 |
| **Thu Dec 3, 15:00 CET** | **Soft launch:** public, 16+ trial, **RFY excluded**, full questionnaire submitted, aiming for **Mild** | Starts the evaluation clock |
| Dec 3-12 | **Engagement ads, $300 lifetime (H)**, ages 16+, creatives T1-T4. Check Audience Reach daily and **pause by hand**. A separate **$100 Plays test** (Dec 3-6) compares thumbnails and ad-cohort D1. **No more than $500 before D1 is known** | Clear the gate before school breaks |
| **Fri Dec 4** | Create the **"Steal Back Christmas" Experience Event** for Dec 11 and submit it for featuring. Add an in-game RSVP prompt after the first heist | 7-day lead time; 1,000 RSVPs opens Trending Events |
| **Fri Dec 11** | Christmas chapter 1, **open RFY**, start the event. Only if the soft-launch bars hold: D1 ≥ 15% on 300+ players, bounce under 60 s ≤ 20%, no blocker bugs. Otherwise keep RFY off and fix the leak (*Launch Strategy* branches) | |
| **Sat Dec 12** | Creator embargo lifts and the owner's TikTok push goes out. Owner online for 48 h | Saturdays peak |
| ~Dec 15 | **Target: 500 highly engaged plays reached**, so 9-15-year-olds can play over the US winter break (about Dec 18 - Jan 4) | |

**Maturity: Mild.**
- No weapons and no blood. Getting caught means "sent home" with a cartoon "busted" stamp.
- No jump scares.
- **The casino must have no playable gambling**; it is a vault with a casino skin [UNVERIFIED how Roblox rates themed-only casinos].
- Bobo Heist's Mild 9+ label shows heist themes can pass.

**Creators.**
- **Who:** 20 micro creators (10K-200K) who post Roblox duo, funny, puzzle or obby clips (found by TikTok search "roblox duo / heist / clone"), plus 10 mid creators (200K-2M). Family and duo channels such as ZoeTheNoob (2.1M) or MeganPlays (3.6M) fit the style but are reach goals ([Clickanalytic](https://www.clickanalytic.com/find-influencers/united-states/famous-roblox-youtubers/)).
- **Skip:** macro channels (KreekCraft, Flamingo) until D1 is proven, and drama channels.
- **Pitch:** under 150 words by DM. Reference one of their videos, attach a 15 s vertical clip, and include a private server for Dec 5-10, a personal share link and a "creator clone" outline colour.
- **No paid deals until D1 ≥ 22%,** and always disclosed in kid-friendly words (*Marketing to Kids and Teens*). Keep a 5-creator inner circle that gets every update 48 h early.

**Cadence:**
- a weekly Friday drop at 17:00 CET;
- a content update every 2-3 weeks, with one goal for existing players, one fix for new players, a new thumbnail, an event and a reason to bring a friend;
- one buffer week a month, feature freeze at T-10, event public at T-7 (*Update Cadence and Hype Cycles*).

### R5. KPIs, thresholds and analytics events

The bars are anchored to the GameAnalytics medians. (H) marks heuristics.

| Metric | Kill / rework | Fix before scaling | Healthy | Double down |
|---|---|---|---|---|
| Join → control (mid phone) | > 20 s | 10-20 s | ≤ 10 s | — |
| First clone seen ≤ 45 s | < 60% | 60-80% | ≥ 85% | — |
| Level 1 complete / joined | < 50% | 50-70% | ≥ 70% | ≥ 80% |
| Bounce < 60 s (H) | > 35% | 20-35% | ≤ 20% | ≤ 12% |
| Median first session | < 5 min | 5-10 min | ≥ 12 min | ≥ 18 min |
| **D1** (cohort ≥ 300) | **< 8%** | 8-15% | **15-22%** | **≥ 22%** |
| **D7** | < 1.5% | 1.5-4% | 4-6% | **≥ 6%** |
| Sessions with a friend | < 8% | 8-20% | ≥ 20% | ≥ 30% |
| SAVE CLIP taps / heists | < 1% | 1-4% | ≥ 5% | ≥ 10% |
| Share-link D1 ÷ organic D1 | < 0.5 | 0.5-0.8 | ≥ 0.8 | ≥ 1 |
| TikTok (own account) | median < 1K after 10 posts | — | a format ≥ 2× account median | a clip ≥ 100K, or 3 ≥ 30K in a week |
| Kids & Select reached | not by Dec 31 | — | by Dec 18 | by Dec 12 |

**What the outcomes trigger:**
- **Double down** (D1 ≥ 22%, D7 ≥ 6%, DAU > 1,000 in week 2): scale Plays ads while CPP stays under $0.02, pay mid creators, pull the Museum forward.
- **Rework** (2 cohorts under 8% D1): stop spend, fix the first 3 minutes, test new thumbnail *concepts*.
- **Hard stop** (4 weeks under 10% D1 and PTR in the bottom quartile): change the framing (title, setting) and keep the tech.

**Events.** All are server-only, sent through one `pcall`-wrapped module using `AnalyticsService` `LogFunnelStepEvent`, `LogCustomEvent` and economy events (*Analytics and Funnels*; *Measuring Onboarding*).
- **Onboarding funnel `onb_v1`** (one-time, forward-only): Joined → Loaded → FirstMove → FirstPlate → FirstRewind → FirstCloneSeen → FirstLoot → L1Complete → ReelShown → L2Start → Minute10.
- **Heist funnel** (one GUID per attempt): HeistStart → Loop2 → BigScoreAttempt → HeistComplete → ReelWatchedToEnd.
- **Custom events** (3 or fewer low-cardinality fields each):
  - `LoopEnded` (level, loop bucket, clones bucket)
  - `CloneFailed` (cause: blocked, zapped, busted or crushed)
  - `RetakeUsed`
  - `MedalEarned`
  - `ClipSaveTapped` (video or screenshot)
  - `ClipShareResult`
  - `InviteSent` / `InviteJoined` (invite, party or join)
  - `RsvpAccepted`
  - `NotifOptIn`
  - `VaultOfDayPlayed`
  - `JoinSource` (a whitelisted launch-data tag: tt, yt, creator_x, ad_eng, ad_plays, clip, organic)
- **Economy:** logged from the wallet after commit, using stable SKUs.
- **Annotations:** every release and campaign gets a date note, because Home analytics changed on 2026-10-12.

---

## Phased plan for this dimension

| Phase | Dates | Work (Claude Code builds; owner films, posts and pays) | Exit criteria |
|---|---|---|---|
| **G0 Identity** | Nov 12-18 | Lock the title (R1) and run a trademark check. Owner verification, 2SV and fee. Reserve TikTok and YouTube handles. Greybox devlog, 4 posts a week. `Analytics` module, `JoinSource` whitelist and blooper log as files | Title locked, account eligible, 4 clips posted |
| **G1 Clip engine + storefront** | Nov 19 - Dec 2 | Heist Reel with captions. SAVE CLIP/Share with launch data. RSVP and invite prompts. Referral cosmetic. Capture place. Icon, T1-T4 and video thumbnail (by Nov 30). Share links. Creator outreach. Ads drafted | 4 of 5 outsider phone testers press SAVE CLIP or say "I'd post that" without being prompted. Funnel visible from a private-server test |
| **G2 Soft launch + gate** | Dec 3-10 | Public 16+ with RFY off. Engagement ads ($300) and Plays test ($100). Creator servers. Hotfix rhythm. Event submitted Dec 4 | D1 ≥ 15% on 300+ players. Bounce under 60 s ≤ 20%. Threshold trending to about Dec 15 |
| **G3 Christmas open** | Dec 11 - Jan 5 | RFY on. Embargo lifts Dec 12. 1 TikTok a day. Calendar below | D7 ≥ 4%. Kids & Select reached. Week-2 branch chosen |
| **G4 Post-holiday hold** | Jan 6-27 | Museum, then a buffer week, then the co-op update and Season 1 | D8-28 return stable or rising after the cliff. Weekly cadence held 3 weeks |

### Live-ops calendar: first 8 weeks

Drops go live **Friday at 17:00 CET** (11:00 US Eastern). They are published 24 h earlier and unlocked by server time.

| Week | Dates | Content and event | Config, live-ops | Marketing |
|---|---|---|---|---|
| **W1** | Dec 3-9 | Soft launch: Shop + Bank (8 levels), medals, Vault of the Day. Locked snow-globe vault with a countdown in the hub | RFY off, hotfixes only, ads, RSVP prompt | Creator servers Dec 5-10. A clip a day. Event submitted Dec 4 |
| **W2** | Dec 10-16 | **Fri Dec 11: Steal Back Christmas, chapter 1** (Toy Shop). **"12 Vaults of Christmas"** advent mini-vaults daily from Dec 13 to 24, with catch-up to Dec 31 | RFY on. Santa-hat icon, "[🎄]" title tag, T5. "Presents recovered" meter | Embargo lifts Dec 12. Formats 1 and seasonal. Update announcement |
| **W3** | Dec 17-23 | **Fri Dec 18: chapter 2** (Gift Factory) as US schools break. Big Score modifier "Lights Out" | Double Cash Sat-Sun only. Notification opt-in after the first advent vault | Format 6 on the advent seed. Creator wave 2 |
| **W4** | Dec 24-30 | **Dec 24: chapter 3, the Snow Globe Vault** (published Dec 22, unlocked by server time). Meter finale Dec 25 | **Publish freeze Dec 24-27.** Fixed Christmas-morning cosmetic | Format 7: "play with your cousins" |
| **W5** | Dec 31 - Jan 6 | **"Midnight Vault"** New Year config event (reskinned Bank). Advent catch-up closes Dec 31. **Event ends Jan 4** | Seasonal art comes off Jan 5. Museum teaser thumbnail | Format 5 (Blueprint) Museum tease |
| **W6** | Jan 7-13 | **Fri Jan 8: Museum** (4 levels, a new gadget), plus the funnel's top new-player fix | New event, new "MUSEUM HEIST" thumbnail | Formats 2-3 among museum lasers. Devlog |
| **W7** | Jan 14-20 | **Buffer week:** fixes and performance | Config rotation "Mirror Map" | Community clip reposts (with permission, no names) |
| **W8** | Jan 21-27 | **Fri Jan 22: co-op update.** "Crew Vaults" that need 2+ live players. Crew leaderboard. **Season 1** (5 weeks, free cosmetic ladder) | Private servers at the minimum price (they count as co-play) | Format 7 headline. Paid mid creator only if D1 ≥ 22% |

**Steady state:**
- weekly: Vault of the Day plus a modifier;
- every 2-3 weeks: a new location (Casino around W10, Moon Base around W13);
- every 2-3 months: a seasonal event.

---

## Risks

| # | Risk | Mitigation |
|---|---|---|
| 1 | **The 16+ gate isn't cleared before Dec 18,** so the core 9-15 audience misses the break | Soft launch Dec 3 with an Engagement budget. Watch Audience Reach daily. Add $200 if the threshold isn't trending by Dec 10 |
| 2 | **"Copy of X" backlash** (itch *Echo Heist*; Playgama *Rewind Robbers* with the same bank, museum and casino ladder; Roblox *ECHOES*) | Our own title, the Neon-Noir look (never clay-toy). Lead with co-op ("16 THIEVES"), which none of them have. Consider renaming the casino to "Sky Lounge Vault" |
| 3 | **Fast-follow AI clones** if we hit (*Escape the Walls*: 7+ clones in 1 day) | Weekly drops. The determinism tech is the moat. Report clones that copy assets or UI |
| 4 | **TikTok traffic decays and doesn't feed RFY** | Judge clips by D1 per share link. Collect Audience Expansion. Convert spikes into RSVPs and notification opt-ins |
| 5 | **The Christmas cliff** (70-84% post-event drops) | Museum on Jan 8 and Season 1 on Jan 22 are already scheduled |
| 6 | **Video capture or share unavailable on some devices** [UNVERIFIED] | Check `CanCaptureVideo()` and fall back to screenshot plus a share link. The owner records clips outside the game anyway |
| 7 | **Phone performance with 12+ clones** drives bounce | Client-side replay and rig LOD (design/visuals). Measure join→control on a mid phone before Dec 3. Kill switch on clone count |
| 8 | **Rating creep** (casino theme, "crime") | No gambling, weapons or gore. Resubmit the questionnaire after changes; this pauses ads eligibility |
| 9 | **Solo owner in Denmark,** with US prime time at night in DK | 17:00 CET drops, publish ahead with server-time gating, no publishes Dec 24-27, the first 48 h covered |
| 10 | **Music and identity in clips** | Owned music only off-platform (Roblox library licensing is [UNVERIFIED]). No other players' names or voices. No external links in game |
| 11 | **Benchmarks disagree** (vendors say 20-40% D1; GameAnalytics' top 1% is 22%) | Recalibrate after W2 from our own cohorts and the Creator Hub scorecard |

---

## Sources

**Roblox official (docs, newsroom, DevForum)**
1. Discovery: https://create.roblox.com/docs/en-us/discovery.md
2. Discovery FAQ: https://create.roblox.com/docs/en-us/discovery-faq.md
3. Optimizing discovery (June 2026): https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
4. RFY long-term retention: https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
5. Kids and Select: https://create.roblox.com/docs/production/publishing/kids-and-select
6. Kids & Select global launch: https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717
7. Ads Manager: https://create.roblox.com/docs/en-us/production/promotion/ads-manager
8. Reward-driven media feeds restriction: https://devforum.roblox.com/t/roblox-kids-and-select-new-restrictions-on-reward-driven-media-feeds/4829188
9. CaptureService: https://create.roblox.com/docs/reference/engine/classes/CaptureService#PromptShareCapture
10. Video Captures beta: https://devforum.roblox.com/t/beta-video-captures-api-bring-your-gameplay-moments-to-life/3823116
11. Content Sharing APIs beta: https://devforum.roblox.com/t/beta-content-sharing-apis-use-upload-api-and-recommendations-api-to-drive-discovery-and-engagement/4065417
12. Roblox Moments: https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery
13. Share Link API: https://devforum.roblox.com/t/introducing-the-share-link-api-deep-link-players-directly-into-the-action/3972678
14. Deep links: https://create.roblox.com/docs/production/promotion/deeplinks
15. Experience events: https://create.roblox.com/docs/en-us/production/promotion/experience-events
16. Off-platform featuring: https://devforum.roblox.com/t/introducing-off-platform-featuring-for-creator-events/4142230
17. Thumbnails docs: https://create.roblox.com/docs/production/publishing/thumbnails.md
18. Gameplay videos on Home: https://devforum.roblox.com/t/gameplay-videos-on-home-help-your-games-get-discovered/4842601
19. Video thumbnail review delays: https://devforum.roblox.com/t/video-thumbnail-review-taking-weeks/4749618
20. Thumbnail personalization: https://devforum.roblox.com/t/live-now-personalize-your-thumbnails-to-attract-more-users/3257233
21. Retention analytics: https://create.roblox.com/docs/en-us/production/analytics/retention
22. Winter Spotlight 2024: https://about.roblox.com/newsroom/2024/12/roblox-winter-spotlight

**Industry and press**

23. TechCrunch, Moments: https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more
24. GameAnalytics Roblox report: https://www.gameanalytics.com/reports/2025-roblox-report ; summary: https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox
25. RoWatcher, creators and charts: https://rowatcher.com/news/how-youtubers-and-tiktokers-move-the-charts-in-2026
26. RoWatcher, macro influencers: https://rowatcher.com/news/why-macro-influencers-kill-small-roblox-games-and-what-works-instead
27. RoWatcher, conversion problem: https://rowatcher.com/news/roblox-influencer-marketing-has-a-conversion-problem-not-a-reach-problem
28. RoWatcher, Halloween 2026: https://rowatcher.com/news/roblox-halloween-spike-hits-14-9m-ccu-winners-losers ; week 44: https://rowatcher.com/news/roblox-week-in-numbers-2026-w44
29. RoWatcher, genre benchmarks: https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like
30. RoLearn, content trends 2026 [vendor]: https://rolearn.dev/trend-reports/roblox-youtube-tiktok-content-trends-2026 ; creator partnering: https://rolearn.dev/guidance/partnering-with-roblox-content-creators
31. GodisaGeek, algorithm change: https://godisageek.com/2026/08/roblox-9-billion-algorithm-change/
32. Statista DAU: https://www.statista.com/statistics/1192573/daily-active-users-roblox/ ; Outlook Respawn Q4 2025: https://respawn.outlookindia.com/gaming/gaming-news/roblox-daily-users-jump-69-to-record-144-million-in-q4-2025
33. Winter event rumours 2026: https://www.ofzenandcomputing.com/what-is-the-next-roblox-event-winter/
34. Eklipse, clip clarity [vendor]: https://blog.eklipse.gg/basic-knowledge/best-games-to-stream-for-viral-clips.html
35. Clickanalytic, Roblox YouTubers 2026: https://www.clickanalytic.com/find-influencers/united-states/famous-roblox-youtubers/

**Name and concept conflicts**

36. itch.io *Echo Heist*: https://geronimokuwait.itch.io/echo-heist ; devlog: https://geronimokuwait.itch.io/echo-heist/devlog ; https://nitrous-studio.itch.io/echo-heist
37. Playgama *Rewind Robbers*: https://playgama.com/game/rewind-robbers
38. Jam heists: https://gohgames.itch.io/timeloop-heist , https://cswkr.itch.io/a-heist-in-60-seconds
39. *Grand Theft Timeline*: https://store.steampowered.com/app/4928450/

**LihFolk Vault V2 notes** (verified to 2026-10-29)

40. *Short-Form Video Marketing*
41. *Sponsored Ads and Campaign Math*
42. *Launch Strategy - The First Two Weeks*
43. *Publishing an Experience*
44. *Analytics and Funnels*
45. *Measuring Onboarding*
46. *Viral Game Anatomy - Hooks, Loops and Timing*
47. *Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks*
48. *Thumbnail Composition for High CTR*
49. *Thumbnail Specs, Rules and Upload*
50. *Photo Mode and In-Game Screenshots with CaptureService*
51. *Event Calendars and Content Planning*
52. *Live Ops Events and Updates*
53. *Update Cadence and Hype Cycles*
54. *Experience Notifications and Return Prompts*
55. *Retention Cohorts*
56. *Marketing to Kids and Teens*
57. The roblox-trend-game skill reference `trend-games-research.md`
58. API checks: `CaptureService.*`, `SocialService.PromptLinkSharingAsync`, `PromptRsvpToEventAsync`, `AnalyticsService.*`, `Player.GetJoinData`

**Live Roblox data** (2026-11-12)

59. `tools/rbx_search.py` for all 10 title candidates plus "clone puzzle", "time clone", "past selves" and "record replay yourself"
60. The games API for ROB IT, Heist Evolution, Bobo Heist, Deadly Heist, Risky Heist, ECHOES: Clone Puzzles, ECHOES, Clone Engine, Clone Friends and Clone Yourself

**Internal**

61. `docs/VIRAL_PLAYBOOK.md`, `docs/IDEA_ECHO_HEIST.md`, `docs/GAME_BIBLE.md` §4, `docs/research/design.md`, `docs/research/visuals.md`, `PROJECT_STATE.md`
