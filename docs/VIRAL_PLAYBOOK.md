# VIRAL PLAYBOOK: how we get one step ahead (2026-11-11)

Sources: two research agents (WebSearch, cited inline in their reports), the LihFolk vault (*Viral Game Anatomy*, roblox-trend-game research §2), and our own radars (tools/trend_radar.py, tools/steam_radar.py). Thresholds marked (H) are heuristics, not published rules.

## 1. What makes a game viral (shared by every case)
1. **A one-line rule you understand in 3 seconds.** "Don't splash", "type a word and it comes to life", "clean the moon with a toothbrush", "paint yourself to hide". It must survive a 15-second clip without sound.
2. **Group play (4+ players).** One purchase or one invite pulls in a whole friend group or a streamer's chat.
3. **A built-in clip engine:**
   - voice panic;
   - a fall or fail;
   - physics chaos;
   - a "reveal" (the disguise is found);
   - in Roblox's world, the visual must also work without voice (H).
4. **Cheap or free.** The Steam originals cost $5-10. The free Roblox versions overtook them in CCU (Meccha Chameleon clones beat the original within about 3 weeks).
5. **The spread chain:**
   - mid-size and genre streamers (days 0-7);
   - then TikTok, where one clip gets more than 1M views in 7 days;
   - then top streamers (Caseoh, xQc, Kai Cenat) who turn it into a peak.
   - On Roblox: Roblox's own channels or mid-size YouTubers (Flamingo, KreekCraft) → RFY amplifies.
6. **Updates every 5-7 days** keep it alive (Grow a Garden). Without updates it dies within weeks.

## 2. Timing: the race now starts at the trailer
| Era | Lag from Steam to Roblox copy |
|---|---|
| 2023-25 (Lethal Company, PEAK, R.E.P.O.) | 4-8 weeks |
| Mid-2026 (Meccha Chameleon) | from 3 days *before* the Steam launch to 3 weeks after |
| October 2026 (Escape the Walls) | **1 day after a gameplay video**, 7+ clones (some built with Claude); the game itself releases 2026-12-03 |

- Steam hits peak **5-14 days after launch** (Moon Sweepers 9, Probably Stolen 10, MECCHA about 11). Only slow burners (Lethal Company, R.E.P.O.) give 3-6 weeks.
- Mid-size Roblox breakouts peak 3-5 weeks after creation (Dig to Escape, DONT SPLASH, Survive Your Ideas).

## 3. First vs best: **the first GOOD version wins**
- PEAK: CLIFF (first and most blatant) was called out and shut down; CLIMB reached 13.9M visits.
- Lethal Company: the later, more complete Deadly Company beat the early clones.
- Moon Sweepers: Sweep The Moon (deeper incremental loop: robots, rovers, conveyor belts) beats Clean the Moon!.
- Meccha: winners were built for Roblox; a setting twist ([BACKROOMS] Chameleon) gave about 50K. **Nobody late broke in.**
- **Dead copies of games that never went viral:** Raccoon Heist / YOINK (built from the Dumpster Gang demo) have 0-1 CCU. Copying early only pays if the original takes off.

## 4. Early-warning signals and thresholds
**Tier A, pre-launch (2-6 weeks of warning):**
- Wishlist velocity: ≥50K in the first week after reveal (H). Dear Passengers did 700K in 36 hours; CRACK 120K in 4 weeks. Followers × 10-12 ≈ wishlists.
- Next Fest: top-20 most-played demos with a launch within 4 weeks (Probably Stolen: demo #1-2 → 184K CCU on day 10).
- Streaming during the demo or fest (Stream Hatchet: r = 0.76 with coverage at launch).
- Caveat: friendslop wishlists convert worse than average (7 in 10 sell below their rank). Velocity plus streamers beats totals.

**Tier B, the first 72 hours (0-2 weeks of warning):**
- A cheap co-op game with ≥20K CCU within 72 hours and still rising day over day, 90%+ positive reviews, and a Twitch top-20 placement or a top-100 streamer.

**Roblox side (window status):**
- A clone growing +500% week over week = the format is confirmed.
- **3 or more clones above 5K CCU = the window is closing. One clone above 50K = closed** (H).

## 5. Ship gate (our rule)
1. **Live within 7-14 days of the Steam spike** (ideally the day of the Steam launch, if Tier A was strong). That requires our **co-op framework to be ready in advance**.
2. Our **own name, characters and art**. Never mirror the original's name, art, UI or achievements (CLIFF shut down; Roblox deprioritises near-duplicates; Steal a Brainrot sued copiers over UI and art). Genre and mechanic are free.
3. **A Roblox-native twist:** an incremental/tycoon layer, co-op lobby and invites, or a setting twist, and a visible clip engine without voice.
4. Quality gates: first reward under 60 s, D1 ≥ 20% (H), low first-play bounce; the thumbnail shows the twist.
5. An update ready within 7 days of launch.

## 6. Daily routine
1. `python3 tools/steam_radar.py` (upcoming and new co-op games, live players, Roblox copy check).
2. `python3 tools/trend_radar.py` (young Roblox games and growth since the last run).
3. Weekly: Next Fest and "Popular Upcoming" lists, SteamDB followers, Twitch trackers, TikTok search on watchlist names.
4. Escalate a game when Tier A or Tier B triggers and the Roblox window is still open → 3-7 day build on the framework.

## 7. Watchlist (2026-11-11)
| Game | Signal | Roblox status | Verdict |
|---|---|---|---|
| Escape the Walls (12-03) | viral gameplay video | "[🚨] Escape The Walls" 1.8K CCU + 7 clones | Window closing |
| Dear Passengers (2026, date?) | 700K wishlists in 36 h (the strongest velocity measured) | Cabin Chaos 3.3K, Dear Passengers Chaos 467 | Open but crowded: needs a strong twist |
| Dumpster Gang (12-03) | demo 527 CCU, Next Fest top 50 | 4 dead raccoon clones | Weak signal: watch the launch |
| Carry On Together (November) | popular upcoming | Moving Out! 105, Carry the Glass obby | Watch the launch |
| Arctic Drive (11-25) | popular upcoming, winter | a snowy trip and others | Watch |
