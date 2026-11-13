# ANALYTICS: events, funnels, KPIs, LiveFlags and PerfSample

The measurement layer for Heist Yourself (MASTERPLAN §7.5, §8.6, §8.7, §8.12, §9.3, §9.5-9.8, §10.2-10.3). It is built and unit-tested, but **nothing calls it yet**. The heist server, the client and the entry script add the calls listed in "Call sites". Status on 2026-11-12: all local checks pass (unit, sim, compile, purity, Selene, StyLua, rojo build, place check, LihFolk checker), and an independent review's findings are fixed (leave order, the 30 fps governor, frame-time buckets, device classes, store funnel limits, kill switches). The modules have not run in Studio or Open Cloud yet; one fact was checked in a live Open Cloud server: game scripts cannot read the device OS (see PerfSample).

Marks: **[DECISION]** means I chose something the plan leaves open. **[UNVERIFIED]** means a platform fact I could not confirm.

## Layout

| Path (Rojo) | In the place | What |
|---|---|---|
| `src/shared/Analytics/Events.luau` | `ReplicatedStorage/Shared/Analytics/Events` | The schema. It holds every custom event, funnel and step, progression path, economy mapping, field domain and bucket edge. `Events.validateCatalog()` checks the Roblox limits |
| `src/shared/Analytics/Tracker.luau` | `.../Tracker` | The pure core. It turns facts into AnalyticsService calls: the join-source gate, forward-only funnels, held steps, batching, budgets, kill switches, Minute10 and the session KPIs. The clock and flags are injected |
| `src/shared/Analytics/Funnel.luau` | `.../Funnel` | Step ordering. One-time funnels are forward-only with held steps and seeding. Recurring funnels have one cursor per session |
| `src/shared/Analytics/JoinSource.luau` | `.../JoinSource` | Launch data parse and build, and join classification |
| `src/shared/Analytics/Sampling.luau` | `.../Sampling` | Sticky salted percentages, experiment arms, token buckets |
| `src/shared/Analytics/PerfSample.luau` | `.../PerfSample` | Client frame-time histogram, the tier governor, device class, the remote payload and its validation |
| `src/shared/Analytics/LiveFlagSpec.luau` | `.../LiveFlagSpec` | LiveFlags definitions check, document parsing, layering, rollouts |
| `src/shared/Analytics/Kpi.luau` | `.../Kpi` | Reads a measured KPI against the §9.7 bars |
| `src/server/Analytics/Analytics.luau` | `ServerScriptService/Server/Analytics/Analytics` | The only module that touches `AnalyticsService` (server-only). It also owns the client remotes `Analytics.Ready`, `Analytics.Perf` and `Analytics.Ui` (approved by the owner on 2026-11-12, see the rules below) |
| `src/server/Analytics/LiveFlags.luau` | `.../LiveFlags` | Feature flags and kill switches. Sources are ConfigService and a DataStore document. It mirrors client flags as attributes |
| `src/shared/Config.luau` | `Shared/Config` | `Config.Analytics` holds the budgets, join tags, perf numbers and KPI bars. `Config.LiveFlags` holds the flag definitions |

Every shared module is pure (no engine services, no clock reads) and runs under Lune.

## Rules this layer keeps (vault *Analytics and Funnels*, *Measuring Onboarding*, *Feature Flags*)

- **Server only, all in `pcall`.** Every public function swallows its own errors, so analytics never breaks gameplay or solo play. Clients never log. They report a few facts through three validated, rate-limited LihFolk Net remotes, and the server decides what to log.
- **[DECISION, owner 2026-11-12] `Analytics.Ready` and `Analytics.Ui` are approved** (rate-limited, validated). `Analytics.Ready` (one device class, once per session) and `Analytics.Ui` (clip, store, hint, invite, RSVP, PerfStepDown and first-move UI facts) go through the LihFolk `Net` module with rate limits and validators, carry no gameplay effect, and the server re-validates every value. **[OPEN, owner] `Analytics.Perf`** (MASTERPLAN §8.6 "perf sample", one sample a minute, 10 validated numbers) is built and live in code but was **not** in the approval: the owner either signs it off too, or perf samples are folded into `Analytics.Ui` (a schema change). **[OPEN, coordinator]** CLAUDE.md's remote rule still lists only `RequestRewind` and the `Data.*` / `Shop.*` menu remotes; it should list the `Analytics.*` remotes and the `Heist.*` intent and menu remotes (`EndRun`, `Interact`, `Deck`, `Ready`, `FastForward`, `SelectLevel`, `SelectDaily`, `JoinFriend`, `Leave`, `Sync`).
- **Low cardinality.** Field values come only from the fixed domains in `Events.DOMAINS`, and an unknown value becomes the domain's `other`. There are 30 custom event names (the limit is 100; the largest field product is 1,350, for `JoinSource`) and at most 3 fields per event. Funnel step-1 fields are checked against the same limit (the largest is 1,800, for `onb_v2` and `ret_*`: source × tag × variant). `Events.validateCatalog()` and a unit test assert all of this.
- **Funnels respect Roblox's rules.** Only the first instance of a step counts, and a skipped step counts as complete. So steps are sent forward-only, and a step listed in `requires` waits for its prerequisite (see Minute10 below).
- **Economy is logged in the wallet, after the change.** It comes from `Currency.Changed`, with stable SKUs and positive amounts. The flow type sets the direction, and the ending balance is the balance after the change.
- **Batching.** High-frequency events (`CloneFailed`, `RedoUsed`, `UndoUsed`, `DeleteUsed`, `TaintedRun`, `FtueHint`, `InviteSent`) are summed per player and field combination. They flush every 60 s, on leave and in `BindToClose`.
- **Our own budgets** [DECISION]. Roblox does not publish AnalyticsService limits. The server bucket allows 120 calls of burst and refills at 120 + 20 × players per minute; we expect about 8 per player. Each player gets 30 unbatched custom events of burst at 30 a minute. The backlog holds 400 calls, and custom events are dropped first. Session events and the funnel steps the server reports are not metered per player. Store steps a client reports (`Analytics.Ui` StoreOpened and StoreItem) spend that player's budget, a StoreOpened within 10 s of the last one reuses its session, and a player opens at most 20 store sessions per session (`STORE_REOPEN_SECONDS`, `STORE_SESSIONS_MAX`), so one spamming client can neither inflate StoreOpened nor fill the server's budget.
- **Environments** (`Data/Keys.isTestEnvironment`). In **Studio** nothing is sent, because Roblox drops Studio events anyway. Calls are recorded in `Analytics.recent()` and printed when `Config.Analytics.STUDIO_PRINT` is set. The **test experience** (10776026960) sends, because it has its own dashboard. That is where the early-tester funnel for the Nov 30 gate lives (§9.5) [DECISION; `SEND_IN_TEST`]. **Live** sends.
- **Kill switches.** The LiveFlag `analytics` turns everything off. `analyticsCustom` turns off custom events and keeps funnels and economy. Both also drop the calls already queued (up to 400), so a switch thrown because AnalyticsService itself misbehaves stops the calls at once.
- **Leaving.** `PlayerRemoving` ends the session at the end of the same resumption cycle (`task.defer`), so another module's `PlayerRemoving` report (HeistService `removeMember` → `heistEnded(..., "left")`) lands in the session whichever order Roblox runs the handlers in. After that, a report for that Player is dropped and counted (`Analytics.stats().noSession`); it never opens a second session. A rejoin is a new Player object and a new session.

## Funnels (6 of the dashboard's 10)

| Funnel | API | Steps | Step-1 fields (dashboard filters apply to step 1 only) |
|---|---|---|---|
| `onb_v2` (§7.5) | `LogOnboardingFunnelStepEvent` (one-time) | 1 Joined · 2 FirstMove · 3 FirstPlate · 4 FirstRewind · 5 FirstCloneSeen · 6 FirstBank · 7 L1Complete · 8 ReelShown · 9 L2Started · 10 FirstCloneBusted · 11 SwarmSeen · 12 Minute10 | source, tag, variant |
| `heist_v1` (§9.7) | `LogFunnelStepEvent`, session = heistId | HeistStarted · FirstRewind · FirstBank · GoalMet · HeistComplete · ResultsShown · NextHeist | level, crew, source |
| `clip_v1` (§9.3) | session = heistId | ResultsShown · ClipTapped · ClipCaptured · ClipKept (saved or shared) | level, crew, source |
| `store_v1` (§5.4) | session = one per store open (only StoreOpened opens one) | StoreOpened · ItemViewed · PromptShown · PurchaseGranted | entry, cohort, source |
| `ret_d1` (§9.7) | session = `r<userId>` | FirstDay (the UTC day of profile creation) · ReturnedD1 (played the next UTC day) | source, tag, variant |
| `ret_d7` (§9.7) | session = `r<userId>` | FirstDay · ReturnedD7 (played on UTC day +7) | source, tag, variant |

Notes:
- **The order is stable.** It matches `HeistService.FTUE_STEPS`, whose index is saved as the profile's `ftueStep`, and a unit test asserts the match. A returning player is seeded from `ftueStep`, so earlier steps are not resent. Any reorder needs a new funnel name (`onb_v3`).
- **[DECISION] Minute10 waits for SwarmSeen.** Roblox counts skipped steps as complete. Without the hold, a slow player's 10-minute mark would mark SwarmSeen (the §9.7 KPI) as done. With the hold, step 12 means "saw the swarm and played 10 minutes". The KPI itself ("SwarmSeen by minute 10") comes from the `FtueMinute10` custom event.
- **[OPEN, analytics + heist server] FirstCloneBusted vs SwarmSeen after the party break.** Since 2026-11-12 Clone Party comes right after L2, so SwarmSeen (step 11, party run 7) usually comes **before** a kid's first busted clone (step 10: Gus in L4, or a clone caught after robbing the party till). Roblox then counts step 10 as complete by skipping, and the later real one is dropped (forward-only), so step 10 stops measuring anything. Recommended fix, before launch while no real profile has an `ftueStep`: a new funnel name `onb_v3` with **FirstCloneBusted taken out of the onboarding funnel** (it stays a `FtueTiming` step) and HeistService.FTUE_STEPS changed to match (the unit test that pins the order then follows). Changing `ftueStep` indices after launch would need a migration.
- **[DECISION] Joined is sent once the join source is known.** That is up to 10 GetJoinData polls 1 s apart, because launch data arrives late, plus up to 12 s for the profile. This way step 1 carries the JoinSource fields. Leaving forces it, so a 3-second bounce still counts as Joined.
- **[DECISION] ReelShown** is the `ResultsShown` step of a Back Room heist, logged by the server: the results card with the Crew Line-up.
- **[DECISION] Store sessions open only on StoreOpened.** A prompt or receipt with no open store session (an upsell outside the store, a receipt replayed after a rejoin) is logged as `OutOfStorePurchase`. A session starting at step 3 or 4 would make Roblox count steps 1-2 as complete with empty step-1 fields. A PromptShown that arrives after PurchaseGranted is dropped as a backwards step, which is harmless, because the later step already counts it.
- **[DECISION] Retention by JoinSource.** Built-in retention cannot be split by our fields. The two-step `ret_*` funnels give the D1 and D7 split by source, cohorted by entry date. Days are UTC from the profile's creation time.

## Custom events (30 names)

`value` is a count unless a unit is given. B means batched (summed and flushed every minute). The value sets are in `Events.DOMAINS`.

| Event | Fields | Value | When (who) |
|---|---|---|---|
| `JoinSource` | source, tag, cohort | 1 | Once per session, when the join resolves (server) |
| `InviteJoined` | invite, cohort | 1 | The arrival came from an invite, referral, party, follow or player share link (server) |
| `ServerBuild` | build (`pv` + `game.PlaceVersion` % 100, or `b<BUILD>` where PlaceVersion is 0) | 1 | Once per server. Use it to check rollout and old servers after a publish (§8.12); no manual bump needed |
| `SessionEnd` | len, cohort, source | minutes | On leave or shutdown. Gives bounce < 60 s and the median session |
| `SessionSocial` | yesno (friend in crew), crew (biggest), cohort | 1 | On leave. Gives "sessions with a friend" |
| `JoinToControl` | load, device, cohort | seconds | First `Analytics.Ready` from the client: PlayerAdded to control |
| `FtueTiming` | ftueStep, ftueTime, source | seconds since join | New players: first FirstPlate, FirstRewind, FirstCloneSeen, FirstBank, L1Complete, SwarmSeen |
| `FtueMinute10` | yesno (swarm), yesno (L1 done), source | 1 | New players at 10:00 of the first session |
| `FtueHint` B | hint, level, cohort | 1 | Stuck hints at 8/16/24 s (client) and Ghost Hint (server) |
| `HeistEnded` | level, outcome, runs | runs | Every heist end: complete, dawn, left, abandoned or aborted |
| `CloneFailed` B | cause, level | 1 | busted, zapped, bonk (door), blocked, orphaned |
| `RedoUsed` B | deckOp (redo / redoFrom), level | 1 | Clone Deck |
| `UndoUsed` B | level | 1 | Clone Deck |
| `DeleteUsed` B | deckOp (delete / deleteBusted), level | 1 | Clone Deck |
| `AlarmTripped` | level, alarmBy (live / clone / catch) | 1 | `AlarmOn` |
| `AlarmEscaped` | level, crew | 1 | The crew got away before the van left |
| `TaintedRun` B | taint (speed, teleport, rise, nogo, bounds, nonfinite, event, multi), level | 1 | A run's recording was tainted (Validator flags, §8.8; risk R5: taint rate > 2 %) |
| `MedalEarned` | medal, level | 1 | `awardHeistResult` `newMedals` |
| `DailyVaultPlayed` | vault (v01-v16), dailyResult, cohort | 1 | Daily vault award |
| `RelaxedChosen` | level, cohort | 1 | Relaxed turned on |
| `QuickCrewJoined` | crew, cohort | 1 | Quick Crew seat taken |
| `InviteSent` B | invite (invite / share) | 1 | Invite prompt or share sheet opened. Sends cannot be seen |
| `RsvpPrompted` | yesno (accepted) | 1 | Event RSVP prompt result |
| `ReferralQualified` | source | 1 | An invited friend played 10 minutes (when `referralReward` ships) |
| `ClipSaveTapped` | clipKind, level | 1 | SAVE CLIP tapped (client) |
| `ClipShareResult` | clipResult, clipKind | 1 | Saved, shared, cancelled, failed or unsupported (client) |
| `PerfSample` | device, ms (p95 bucket: `<14`, `14-18`, `18-28`, `28-36`, `36-50`, `50+`), clones | p95 ms | Once a minute per sampled client |
| `PerfDetail` | device, quality, mem | median ms | Same sample |
| `PerfStepDown` | device, perfTier | 1 | The client governor lowered the runtime tier |
| `CloneBroken` | device, rigFault | 1 | The client's CloneHealth check found a broken avatar clone rig (head gone, limbs off the root, a joint lost an end) and drew the mannequin instead; once per owner per session (`Analytics.Ui` "CloneBroken") |
| `OutOfStorePurchase` | storeStep (PromptShown / PurchaseGranted), product, cohort | 1 | A prompt or receipt with no open `store_v1` session |

**Progression** (`LogProgressionStart/Complete/FailEvent`): path `Heist` uses the level's index in `Config.Data.LEVEL_ORDER` (1-6, the play order: Clone Party is 3, Lights Out 4, Night Clerk 5) and its data key as the name. Path `Daily` uses the vault design number. Both carry the fields crew and source. Start is logged at heist start, Complete at HeistComplete, and Fail at Dawn.

**Economy** (`LogEconomyEvent`, from `Currency.Changed`): the currencies are `Cash`, `Stars` (source only: it is a mirror, so negative repairs are skipped) and `CandyCanes`. The fields are the stars band (`s0`, `s1-5`, `s6-13`, `s14-25`, `s26+`, matching the gates), cohort and source. The reasons map like this:

| Reason | Transaction type | SKU |
|---|---|---|
| `heist:<levelId>` | Gameplay | `Heist_<levelId>` |
| `daily` | Gameplay | `DailyVault` |
| `medals` | Gameplay | `Medals` |
| `buy:<item>` / `shop:<item>` | Shop | item id, or `Other` |
| `bag` | Shop | `BagLevel` |
| `load` | not logged | — |

Robux purchases are not currency flows (there is no Robux-to-Cash). The Monetization dashboard shows them, and `store_v1` shows the funnel.

## JoinSource (§9.3, §9.7)

Sources: `ad`, `share`, `creator`, `clip`, `friend`, `rfy`, `search`, `teleport`, `organic`. Tags: the channel tags `tt yt ig dc web devlog event`, the ad tags `ad_plays ad_eng ad_test`, the creator slots `cr01`-`cr30`, and the kinds `reel player invite referral follow party hint internal none invalid`.

Launch data format (≤ 200 bytes; parsed strictly and whitelisted, because anyone can craft a link; it only ever routes and is never granted on):

```
v1|src|<tag>                 Creator Hub share link per channel, Ads Manager join option, or a creator's own link
v1|reel|<levelId>[|<tag>]    SAVE CLIP share (PromptShareCapture)
v1|share|<levelKey>[|<tag>]  player share link (PromptLinkSharingAsync, server only)
v1|inv|<levelKey>[|<tag>]    in-game invite (ExperienceInviteOptions.LaunchData)
```

Evidence order: our launch data, then `ReferredByPlayerId` (referral), then `FollowUserId` (followed a friend), then a teleport from this experience, then the ConfigService hint, then `PartyId` (party), then organic. Build links with `Analytics.launchData(verb, arg, tag)` or `JoinSource.build`. The heist server may route a `reel`, `share` or `inv` join with `JoinSource.requestedLevel(Analytics.joinSource(player).launch)`, but only after checking the level exists and is unlocked.

- **[DECISION]** A party join counts as `friend`.
- **Search and Recommended (RFY) cannot be told apart from join data.** ConfigService targeting has an "acquisition source" condition (Roblox configs docs, October 2026; vault *Global State and Live Config*), so the owner creates a string config `EH_AcqSource` with targeted values `rfy`, `search` and the others (owner action 3). The server reads it per player with `GetConfigForPlayerAsync`, and the tag becomes `hint`. Until that config exists, both count as `organic`, and the built-in Acquisition page is the only split.

## KPIs and the rules (§9.7, §10.2)

The bars are in `Config.Analytics.KPI`, and `Kpi.evaluate(id, value, { cohort, n })` applies them. Ad cohorts use retention bars 4 points lower, and kill or rework never fires on them. D1 and D7 need a cohort of 300.

| KPI | Kill / rework | Fix | Healthy | Double down | Measured from |
|---|---|---|---|---|---|
| Join → control (phones) | > 20 s | 10-20 | ≤ 10 s | — | `JoinToControl` by load, filtered to device `phone`. The OS split (Android) is not readable in game; the built-in Performance page splits by platform |
| First clone seen ≤ 45 s | < 60 % | 60-85 | ≥ 85 % | — | `FtueTiming` FirstCloneSeen in `<15s`, `15-30s`, `30-45s` ÷ new Joined |
| L1 complete / joined | < 50 % | 50-70 | ≥ 70 % | ≥ 80 % | `onb_v2` step 7 ÷ step 1 |
| SwarmSeen by minute 10 | < 35 % | 35-60 | ≥ 60 % | ≥ 75 % | `FtueMinute10` swarm = yes ÷ all |
| Bounce < 60 s | > 35 % | 20-35 | ≤ 20 % | ≤ 12 % | `SessionEnd` cohort new, `<30s` + `30-60s` ÷ all |
| Median first session | < 5 min | 5-12 | ≥ 12 | ≥ 18 | `SessionEnd` cohort new, the bucket that holds the median |
| D1 (organic, ≥ 300) | < 8 % | 8-15 | 15-22 % | ≥ 22 % | Retention page; split by source: `ret_d1` |
| D7 | < 1.5 % | 1.5-4 | 4-6 % | ≥ 6 % | Retention page; `ret_d7` |
| Sessions with a friend | < 8 % | 8-20 | ≥ 20 % | ≥ 30 % | `SessionSocial` yes ÷ all |
| SAVE CLIP taps / heists | < 1 % | 1-4 | ≥ 5 % | ≥ 10 % | `ClipSaveTapped` ÷ `HeistEnded` outcome complete |
| Median first bank (Nov 30 gate) | > 90 s [DECISION] | 60-90 | ≤ 60 s | — | `FtueTiming` FirstBank |
| "Heist" not "puzzle" | < 50 % | 50-70 | ≥ 70 % | — | Playtests (human, not analytics) |

- **SwarmSeen by minute 10 vs the level order** (owner decision 2026-11-12: Clone Party, design number L5, is the "party break" right after L2). `tests/sim/Pacing.spec.luau` models a first session from the plan's own estimates (L1 = §7.5's first bank + results; L2 = an even share of §4.2's L1-L4 estimate; the party from its runs, rewinds and a 3-10 s pause, `PARTY_BETWEEN_SECONDS`, which gives §4.2's updated "Clone Party 5-6.5 min"): **SwarmSeen at minute 7.6 / 9.4 / 11.2** (fast / middle / slow end), "8 OF ME" at 8.1 / 10.0 / 11.9, a perfect player at 4.8. With the party after L4 it was 13.6-21.2. The 10 s party auto-start (since 2026-11-12, with the party deck read-only) moved the slow end from 12.7 to 11.2. So the ≥ 60 % bar needs most kids at or a little faster than the plan's middle. Remaining lever if kid wave 1 (Nov 21-22) is slow: L2 cleared in ≤ 4 min (stuck hints, the Ghost Hint after 2 failed runs): the slow end drops to 10.2.
- **Double down:** organic D1 ≥ 22 %, D7 ≥ 6 % and DAU > 1,000 in week 2. Then scale Plays ads while CPP < $0.02, pay mid creators and pull the Museum forward.
- **Rework:** two organic cohorts under 8 % D1. Stop spend, fix the first 3 minutes and test new thumbnail concepts.
- **Hard stop:** 4 weeks under 10 % organic D1 with PTR in the bottom quartile. Change the framing (title, setting) and keep the tech.
- **Go/no-go Mon Nov 30** (early testers, test experience dashboard): ≥ 70 % reach L1Complete, median first bank ≤ 60 s, SwarmSeen ≥ 60 % of testers who reach minute 10, and the frame budget met on the mid phone. For the frame budget, `PerfSample` p95 in `<14` or `14-18` (the 60 fps class) on the owner's mid phone, from that phone's own samples in the test session, since the dashboard cannot tell one phone from another.
- **W4 exit:** organic D1 ≥ 15 % on 300+ players, bounce < 60 s ≤ 20 %, and frame time by device tier reviewed.
- Thumbnail T1 is added once `FtueMinute10` swarm = yes ≥ 60 % (§9.4).
- The 16+ trial D1 is a floor. Re-baseline when the under-16 cohort arrives.

## Dashboards to build (Creator Hub > Analytics; owner, about 30 minutes, once events flow)

Custom event charts aggregate daily and can lag by up to 24 hours. Benchmark scorecards need 100+ DAU.

1. **Funnels:** open `onb_v2`, `heist_v1`, `clip_v1`, `store_v1`, `ret_d1` and `ret_d7`. Save one view per source using the step-1 filter `CustomField01` (ad, share, creator, clip, friend, organic).
2. **Explore (custom events), one saved chart each:**
   - Bounce: `SessionEnd`, filter CF02 = new, break down by CF01. Add a per-source copy filtered on CF03.
   - First session length: `SessionEnd`, CF02 = new, by CF01.
   - Join → control: `JoinToControl` by CF01, filter CF02 = phone (then each device class).
   - FTUE timings: `FtueTiming`, filter CF01 = FirstCloneSeen (then FirstBank), by CF02.
   - SwarmSeen by 10: `FtueMinute10` by CF01.
   - Friends: `SessionSocial` by CF01.
   - SAVE CLIP: `ClipSaveTapped` total next to `HeistEnded` with CF02 = complete.
   - Clone failures: `CloneFailed` by CF01 × CF02. These feed the blooper formats, §9.2.
   - Taint: `TaintedRun` by CF01. Watch for > 2 % of runs. Runs are the **sum** of `HeistEnded` values, not a count (see the open question on value sums); until that is confirmed, compare against `HeistEnded` count × the median runs bucket.
   - Frame time: `PerfSample` by CF02, filtered per device class (CF01). `<14` + `14-18` is the share of samples meeting the 60 fps budget. `28-36` is the 30 fps class, at the low-phone ceiling. `36-50` + `50+` is the rate of samples with p95 over the ceiling (36 ms, the governor's slow line). The edges sit clear of 16.7 and 33.3 because a sample's p95 is the upper edge of its 0.5 ms bin. The mean p95 needs the value sum (value ÷ count); the buckets alone answer the bars.
   - Sources: `JoinSource` by CF01 and by CF02.
   - Builds: `ServerBuild` by CF01 (old servers after a publish).
   - Alarm: `AlarmEscaped` against `AlarmTripped`, by level.
3. **Economy:** Cash sources and sinks by SKU, the average wallet, and Candy Canes during the event. Look for dead sinks and runaway balances.
4. **Retention:** D1, D7 and D30 by platform and age band. Use `ret_*` for the source split.
5. **Performance:** client memory and crashes by device after every release. A crash spike means a memory regression, so roll back (§8.12).
6. **Release annotation (§8.12):** on every publish, add an annotation in Creator Analytics with the place version and the release tag. `ServerBuild` reports `pv` + PlaceVersion % 100 by itself, so no manual bump is needed (`Config.Analytics.BUILD` is only the fallback where PlaceVersion is 0). The annotation is a manual owner step; I found no API for it [UNVERIFIED].

## PerfSample (§8.6, §6.3, §6.8)

The pure aggregation lives in `PerfSample`, and the client wiring comes later (see the client call sites). Each client fills a histogram of frame times: 0.5 ms bins up to 100 ms plus an overflow bin, with the exact worst frame kept. That means no allocation, and percentiles are exact to 0.5 ms. Gaps over 2 s are pauses, not frames. Once a minute (LiveFlag `perfIntervalSeconds`), if there are at least 300 frames, the client sends `PerfSample.pack(summary, device, quality, memMb, clones, tier)`. The payload is the median, p95, worst, frames, seconds, device class, `SavedQualityLevel`, `Stats:GetTotalMemoryUsageMb()`, clones on screen and the current runtime tier. The server checks the ranges, the order (median ≤ p95 ≤ worst) and plausibility (≤ 1,000 fps) with `PerfSample.unpack`. It samples per player with `perfSampleRate`, which is sticky by user id, accepts at most one sample per half interval, and logs `PerfSample` and `PerfDetail`.

The governor: if more than 5 % of a second's frames are slow for 20 seconds in a row, the client steps the runtime tier down once (§6.3 controls). It then cools down for 30 s and reports `PerfStepDown`. Seconds with fewer than 10 frames are loading hitches and are not judged.
- **[DECISION] Slow means slower than 30 fps.** The plan's "p95 > 33 ms" is read as "slower than the 33.3 ms low-phone ceiling", so a frame counts as slow only above 36 ms (`SLOW_MS`, the ceiling plus a vsync jitter margin). A device held at 30 fps by the OS (Low Power Mode, battery saver), or a 60 fps device that misses a vsync now and then (33.3 ms frames), is at the ceiling and never steps down. A unit test runs steady and jittered 30 fps for 300 s.
- **[DECISION] It stops when a step does not help.** After a step, the next 20 s slow streak must cut the slow share by at least 10 % (`STEP_MIN_GAIN`), or the governor stops for the session. Lowering quality cannot beat an OS frame cap or a CPU-bound device, and stepping on would only ratchet quality down to the minimum. A cap below 30 fps therefore costs one step, not four.
- **[DECISION]** It never steps up by itself, so it cannot oscillate. The player raises the preset in settings.

Device class **[DECISION]**: `phone`, `tablet` (touch without a keyboard; tablet from a short side of 600 px), `desktop` (a keyboard or no touch, touch laptops included), `console` (ten-foot UI), `vr` and `other`. **Game scripts cannot read the OS.** `UserInputService:GetPlatform()`, `GetDeviceType()` and `GetDeviceLevel()` all fail with "lacking capability RobloxScript". I checked this on 2026-11-12 in a live server of the test experience through Open Cloud Luau Execution, and DevForum threads report the same for clients. So there is no Android/iOS or Windows/Mac split in our events. That split comes from Roblox's built-in Performance and Retention pages, by platform. Roblox has no device-RAM API, so the plan's "memory tier" is the client's own memory in use, and "low versus mid phone" shows up in the frame-time distribution per device class.

## LiveFlags (§8.7, §8.12)

The layers, lowest first: the `Config.LiveFlags.Flags` defaults, then the **ConfigService** key `EH_<name>`, then the **DataStore** document, then a Studio/test-only testing value. For tune, release and experiment flags, the highest layer that sets a value wins. **[DECISION] Kill switches: off wins.** A switch is off when any layer sets it false, so a stale `{ "store": true }` left in the DataStore can never cancel the owner's `EH_store = false` in Creator Hub. To turn a switch back on, clear the false in every layer that set it. When the DataStore shadows a different ConfigService value, every server warns about it each time either layer is read. A failed read keeps the last good layer, so an outage never turns a killed feature back on (a unit test makes `GetAsync` throw). Values that are out of range are refused and never clamped, so a typo of 250 instead of 25 is ignored and warned about.

| Kind | Flags (default) | Effect |
|---|---|---|
| kill (on) | `analytics`, `analyticsCustom`, `perfSampling`*, `store`*, `cashShop`*, `quickCrew`*, `joinFriend`*, `saveClip`*, `saveClipVideo`*, `shareLinks`*, `invites`*, `rsvpPrompt`, `dailyVault`*, `boards`*, `dressing`*, `giftBeat`*, `alarmRun`, `ghostHint`* | false turns the system off |
| release (off) | `clipUpload`* (UploadCaptureAsync, §9.3), `referralReward`, `rewardedVideo`*, `globalBoard`* | true, or a 0-100 percent of players (sticky per player and salted per flag) |
| tune | `alarmVanSeconds` 20 [10, 40], `alarmLockSeconds` 10 [3, 20], `alarmChaseSpeedMult` 0.9 [0.5, 1.1], `crewCloneBudget` 12 [4, 16], `maxInstances` 8 [1, 8], `perfSampleRate`* 1 [0, 1], `perfIntervalSeconds`* 60 [30, 600] | Read **at heist start**, never mid-run. The defaults are the `Config.Sim` and `Config.Heist` numbers, and a test asserts they match |
| experiment | `ftueVariant` `base:100` | `arm:weight,...` with arms from `Config.Analytics.VARIANTS`, sticky per player. Sent as the `variant` field on step 1 of onb_v2 and ret_* |

\* `client = true`: mirrored as an attribute on `ReplicatedStorage.LiveFlags`. Release flags also get the player attribute `LF_<name>`, which holds that player's sticky answer.

**Incident runbook** (target: off within 2 minutes, no publish):
0. **ConfigService is the primary incident path for kill switches.** A switch killed only in the DataStore document is not applied on a server that has not read the DataStore yet: a fresh server during a DataStore outage starts from the defaults (on). The server warns (`... before any good read ...`), `LiveFlags.snapshot().status.storeKnown` is false, and a new player's first heist waits at most `FLAGS_WAIT_SECONDS` (3 s) for the first read. ConfigService has no such gap once it has been read.
1. **Owner, fastest path:** Creator Hub > Configs. Add or edit the boolean `EH_<flag>` (for example `EH_store` = false) and **Publish now**. It is live in about a minute, with History and Restore. In Studio, staged values show in team play sessions.
2. **Claude (Open Cloud, once the D5 DataStore scopes exist):** write the DataStore `EH_Live_v1` key `LiveFlags` (`_TEST_LiveFlags` on the test experience) as `{ "v": 1, "flags": { "store": false }, "note": "2026-12-05 prompt loop" }`. Servers pick it up within 60 s. For tune flags this layer beats ConfigService; for kill switches either layer can turn a switch off, and neither can turn on what the other turned off.
3. **Verify:** every server prints `[LiveFlags] store = false (from store)`. `LiveFlags.snapshot()` shows the values, sources and read status, and `ServerBuild` shows which builds are live.
4. **Clear afterwards:** delete the DataStore key or remove the entry. A stale `false` keeps the switch off whatever ConfigService says, and a stale tune value keeps winning over ConfigService. Servers warn about both (`... has no effect: the DataStore document sets ...`).
5. On a live server's console, `LiveFlags.setTestValue` is refused. In Studio and the test experience it overrides one server.

Tuning flags change sim numbers. When the heist server passes them into `HeistSim` at heist start, it must store them with the heist (`heistId` record or result), so that board replays and CI reproduce the run.

## Call sites (for the agent wiring the sim; analytics adds nothing to gameplay itself)

### `src/server/init.server.luau` (both GAME_MODEs)

```lua
local Analytics = require(script:WaitForChild("Analytics"):WaitForChild("Analytics"))
-- after DataService.start() (inside its pcall) and BEFORE HeistService.start() / Main.start():
local okAnalytics, analyticsErr = pcall(Analytics.start, {
	dataService = DataService,                                  -- Loaded -> cohort, ftueStep, first-seen day
	playerData = require(script.Data:WaitForChild("PlayerData")), -- read-only Meta.Created (until the snapshot has `created`)
	currency = require(script.Data:WaitForChild("Currency")),     -- Currency.Changed -> economy events
	receipts = require(script.Data:WaitForChild("Receipts")),     -- Receipts.Granted -> store_v1 PurchaseGranted
	shop = require(script.Data:WaitForChild("Shop")),             -- Shop.ProductPrompted -> PromptShown (once it exists)
	heistService = HeistService,                                -- sim path: HeistService.FtueStep -> onb_v2
})
if not okAnalytics then warn("[Server] analytics failed to start: " .. tostring(analyticsErr)) end
```
`Analytics.start` also starts LiveFlags. Other server code reads flags with `require(script.Analytics.LiveFlags)`.

### `src/server/Heist/HeistService.luau`

| Where | Call |
|---|---|
| `FtueStep` / `FTUE_STEPS` | Bound already through `heistService`. Optional: use `Events.FUNNELS.onb_v2.steps` as the list (a unit test asserts they match today) |
| After `HeistInstance.new(...)`, for each real member | `Analytics.heistStarted(player, { heistId = inst.heistId, level = Catalog[levelIndex].id, crew = #liveMembers, friends = m.friends, daily = <vault design number or nil> })` |
| Quick Crew seat taken (HeistService: a held seat sat in) | `Analytics.quickCrewJoined(player, crewSize)` |
| Relaxed accepted or turned on | `Analytics.relaxedChosen(player, dataKey)` |
| Share link (`SocialService:PromptLinkSharingAsync`) | `LaunchData = Analytics.launchData("share", dataKey)`, then `Analytics.inviteSent(player, "share")` |
| Optional deep-link route on join | `JoinSource.requestedLevel(Analytics.joinSource(player).launch)`, which can be nil for the first 10 s; open it only if it is unlocked |
| Gates | `LiveFlags.isOn("quickCrew")`, `isOn("joinFriend")`; at heist start `LiveFlags.get("maxInstances")`, `get("crewCloneBudget")`, `get("alarmVanSeconds")`, `get("alarmLockSeconds")`, `get("alarmChaseSpeedMult")`, `isOn("alarmRun")` into the sim opts (stored with the heist) |

### `src/server/Heist/HeistInstance.luau`

Most of these go in `scanFtue`, which already sees every event-log entry. Below, `level` is `inst.dataKey`.

| Sim event / place | Call |
|---|---|
| `EV.RunStart` with a ≥ 2 (first time) | `Analytics.heistStep(player, inst.heistId, "FirstRewind")` for each member |
| `EV.Bank` | `heistStep(owner, heistId, "FirstBank")` (repeats are dropped) |
| `EV.GoalMet` | `heistStep(each, heistId, "GoalMet")` |
| `EV.HeistComplete` | `heistStep(each, heistId, "HeistComplete")` |
| `EV.Busted` (b = clone) | `Analytics.cloneFailed(owner, "busted", level)` |
| `EV.Zap` on a clone actor | `cloneFailed(owner, "zapped", level)` |
| `EV.Stuck` (b = cause) | `cloneFailed(owner, if b == CAUSE.Door then "bonk" else "blocked", level)` |
| A failure of a clone whose owner left | `cloneFailed(<a crew member>, "orphaned", level)` (optional) |
| `EV.AlarmOn` (a = actor, 0 = catch) | `Analytics.alarmTripped(each, level, if a == 0 then "catch" elseif clone then "clone" else "live")` |
| Alarm Run won (banked before `VanLeft`) | `Analytics.alarmEscaped(each, level, crewSize)` |
| `sampleInputs`: a live actor ≥ 2 studs from its run-1 spawn | `ftue(inst, m, "FirstMove")`, which flows through `FtueStep`. The client fallback `Analytics.Ui("FirstMove")` exists, but server detection is better |
| `onRunEnded`: each live actor whose recording is tainted | `Analytics.taintedRun(player, actor.rec.vflags, level)` |
| `onOver`, per member | `Analytics.heistEnded(player, heistId, complete → "complete", Dawn → "dawn", Abandoned → "abandoned", result.runs)`. Then for each `award.data.newMedals`: `Analytics.medal(player, medal, level)`. When "Over" is sent: `Analytics.heistStep(player, heistId, "ResultsShown")` |
| `removeMember` (left mid-heist) | `Analytics.heistEnded(player, heistId, "left", sim.runIndex)` |
| `deckAction` when ok | `Analytics.deck(player, <op with a lower-case first letter: redo, redoFrom, delete, deleteBusted, undo>, level)` |
| Ghost Hint plays (server decision) | `Analytics.hint(player, "ghost", level)` |
| Daily vault award | `Analytics.dailyVault(player, design, "cleared" / "failed" / "catchup")` |

### Client (`src/client`)

| Where | Call |
|---|---|
| First control (first Run message or garage spawn with input on) | `Net.Send("Analytics.Ready", PerfSample.deviceClass(facts))`, once |
| New `Perf` controller | RenderStepped dt → `PerfSample.add(window, dt)` and `PerfSample.govern(gov, dt)`. Every `ReplicatedStorage.LiveFlags:GetAttribute("perfIntervalSeconds")` s → `Net.Send("Analytics.Perf", PerfSample.pack(summary, device, quality, memMb, clonesOnScreen, tierName))` and `PerfSample.reset`. Skip it when the attribute `perfSampling` is false. A governor step-down → lower the tier, then `Net.Send("Analytics.Ui", "PerfStepDown", tierName)` |
| Hud stuck hints (8 / 16 / 24 s) | `Net.Send("Analytics.Ui", "Hint", "plate" / "beam" / "mentor")` |
| SAVE CLIP | Tap → `"ClipTap", kind`. Capture done → `"ClipCaptured", kind`. Saved → `"ClipSaved"`. Shared → `"ClipShared"`. Cancelled, failed or no capture → `"ClipCancelled"`, `"ClipFailed"`, `"ClipUnsupported"`. Share launch data: `JoinSource.build("reel", levelSpecId)` |
| Store UI | Open → `"StoreOpened", "van" / "results" / "garage"`. Item card → `"StoreItem", category` |
| Invite button | `"InviteOpened", "invite"`, with `ExperienceInviteOptions.LaunchData = JoinSource.build("inv", dataKey)` |
| RSVP prompt result | `"Rsvp", "yes" / "no"` |
| Hide buttons | `ReplicatedStorage.LiveFlags` attributes `saveClip`, `saveClipVideo`, `store`, `cashShop`, `quickCrew`, `joinFriend`, `invites`, `shareLinks`, `dailyVault`, `boards`, `dressing`, `giftBeat`, `ghostHint`; `Player:GetAttribute("LF_clipUpload")` and similar for release flags |

Device facts for `deviceClass`: `touch` / `keyboard` / `gamepad` (`UserInputService.TouchEnabled`, `KeyboardEnabled`, `GamepadEnabled`), `vr` (`VRService.VREnabled`), `tenFoot` (`GuiService:IsTenFootInterface()`) and `viewportMin` (`math.min(camera.ViewportSize.X, camera.ViewportSize.Y)`). Do not call `UserInputService:GetPlatform()` (it needs the RobloxScript capability). Quality is `UserSettings().GameSettings.SavedQualityLevel.Value`, where 0 means automatic.

### Data layer (data agent, optional)

- Add `created = profile.Meta.Created` to `DataService` `buildSnapshot`. Analytics then stops reading `PlayerData` for the first-seen day.
- Add `Shop.ProductPrompted = Signal.new()` and fire `(player, productKey)` in `promptProduct` right before `MarketplaceService:PromptProductPurchase(player, def.id)`. The server opens every prompt, so this is the true PromptShown moment. `Analytics.start({ shop = Shop })` binds it, and then stops using `PromptProductPurchaseFinished`, which stands in for it today and can arrive after the receipt.
- `Currency.Changed` and `Receipts.Granted` already carry everything needed. Keep currency reasons in the forms above (`heist:<id>`, `buy:<item>`, `daily`, `bag`).
- The new-player rule: a profile created at most 30 s before this join is `new` (`NEW_PLAYER_GRACE_SECONDS`, clock skew only), so a crash rejoin minutes later is `returning` and never a second first session.

### Engine smoke (owner of `tests/engine_smoke.luau`)

A suggested section 8: `Analytics.start()` boots, `Analytics.environment() == "test"`, `LiveFlags.snapshot().status`, and the remotes `Analytics.Ready`, `Analytics.Perf` and `Analytics.Ui` exist in `ReplicatedStorage.LihFolkRemotes`. Luau Execution has no players, so player events cannot be checked there. `Analytics.setBackend(fn)` captures calls for a Studio play test.

## Tests

`lune run tests/run_unit.luau Analytics` runs 7 spec files and 60 tests:
- `AnalyticsEvents` covers the catalog limits, plan event names, the onb_v2 order against `HeistService.FTUE_STEPS`, domains, the economy mapping and the KPI bars.
- `AnalyticsFunnel` covers forward-only steps, held steps and seeding.
- `AnalyticsJoinSource` covers parse and build, classification, sampling uniformity and stickiness, experiment arms and token buckets.
- `AnalyticsLiveFlags` covers definitions, coercion, documents, layers, rollouts and arms.
- `AnalyticsPerf` covers percentiles against an exact sort, pauses, the governor (steps, cooldown, the stall rule, steady and jittered 30 fps, missed vsyncs), device classes and hostile payloads.
- `AnalyticsTracker` covers the gate, FTUE timings, Minute10, retention, the heist, clip and store funnels (out-of-store purchases, client spam), batching, budgets, kill switches (including queued calls), economy, session KPIs and perf.
- `AnalyticsServer` loads both server modules in Lune with a fake engine (with `task.defer`) and checks the exact AnalyticsService argument shapes, the remotes, Studio suppression, the leave order and rejoins, the new-player cohort, the Shop hook, LiveFlags layers (a throwing `GetAsync`, off wins), the kill switch and the shutdown flush.

## Owner actions

1. **Share links (Creator Hub):** create one per channel with launch data `v1|src|tt`, `v1|src|yt`, `v1|src|ig`, `v1|src|dc`, `v1|src|web` and `v1|src|devlog`, plus `v1|src|cr01`-`v1|src|cr30` for creators. Keep a sheet that maps each `crNN` to a creator; never put names in the game.
2. **Ads Manager:** set the advanced join option launch data to `v1|src|ad_plays` (Plays) and `v1|src|ad_eng` (Engagement).
3. **ConfigService (required for the RFY / search split):** create the string config `EH_AcqSource` with default `""` and one targeted value per acquisition source: `rfy` for Recommended, `search` for Search, and the others the targeting offers that match a source (`ad`, `share`, `friend`). Without it, Search and RFY both log as `organic`. Also create the boolean kill switches you may need in a hurry ahead of time, set to their defaults (`EH_store`, `EH_saveClip`, `EH_quickCrew`), so an incident is a one-click change.
4. **Dashboards:** follow the list above once events flow, which takes a day.
5. **Release:** add the annotation with the place version on every publish (`ServerBuild` follows PlaceVersion by itself).
6. **Decide:** whether the early-tester place belongs to the test experience (10776026960). Its dashboard then holds the Nov 30 gate numbers, and its players use `_TEST_` data keys. Never add the live experience id to `TEST_UNIVERSE_IDS`.

## Open questions

- [UNVERIFIED] Does AnalyticsService accept a call for a Player after `PlayerRemoving`? The session-end calls run at the end of the same resumption cycle as `PlayerRemoving` (`task.defer`), while the Player still exists. Calls the budget holds back keep the Player reference for 60 s (`LEFT_KEEP_SECONDS`), and a failure is caught.
- [UNVERIFIED] Does Explore offer a sum or an average of the value? Counts by field are certain, and most KPIs above are read from counts. Two are not: the taint rate needs the **sum** of `HeistEnded` values (runs), and the mean p95 needs value ÷ count. If Explore shows counts only, the taint rate uses `HeistEnded` count × the runs bucket, and frame time uses the p95 buckets (which already answer the bars).
