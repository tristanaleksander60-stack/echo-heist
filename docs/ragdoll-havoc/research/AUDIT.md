# RAGDOLL HAVOC: deep audit (2026-11-19)

_Read-only research on universe 10774775314, root place 126037745825106. Nothing was published, nothing in the live game was changed, and no DataStore was written. User ids appear nowhere in this file._

## 0. Sources and how much to trust them

| Source | What it is | Weight |
|---|---|---|
| 3 owner phone captures (`docs/ragdoll-havoc/captures/phone_*.png`, 828x1792, portrait) | The live game on a phone | Highest |
| `Session_v1` (1,126 visit records, 930 players, 2026-11-10 to 11-19) | One record per visit, written by `SessionStats.luau` | High (but see the version-label caveat in §1.1) |
| `Onboarding_v1`, `Profile_v1`, `Orders_v1`, product info | Read through Open Cloud Luau Execution, aggregated inside the script | High |
| Live source, place version 465 (0.17.2): `/home/user/ragdoll-havoc/place/` (271 scripts) | What runs now | High |
| Place version 440 (0.14.0), 259 scripts, pulled the same way for this audit | The "85 s" build | High |
| Version sizes of places 453, 458, 460, 464 (LuaSourceContainer list only) | To date each change | High |

File references below are relative to `/home/user/ragdoll-havoc/place/` unless they say otherwise. "ReplicatedStorage/Shared" = `RS/Shared`, "ServerScriptService/Server/Systems" = `SSS/Systems`, "StarterPlayer/StarterPlayerScripts/Client" = `Client`.

Version map (read from `Config.Version` of each place version): 440-453 = **0.14.0**, 454-458 = **0.15.0**, 459-460 = **0.16.0**, 461?-464 = **0.17.1**, 465 = **0.17.2**. Almost all sessions in the data are 0.14.0 (106) or 0.17.1 (947); 0.17.2 (the MoveStick fix) has no data yet.

---

## 1. Regression hunt: why 0.14.0 looked like 85 s and 0.17.1 like 54 s

### 1.1 About 12 s of the ~31 s drop is the ad day; about 19 s is real

| Group (new players only) | n | Median session | 95 % CI (bootstrap) |
|---|---|---|---|
| 0.14.0, all | 90 | 81.2 s | |
| 0.14.0, not console | 74 | 81.2 s | 65.5-116.8 |
| 0.15.0, all (11-10 20:00-21:00 UTC) | 41 | 63.7 s | (small sample) |
| 0.17.1, not console, **11-10/11-11 (organic, before the ad)** | 382 | **62.0 s** | 53.6-66.4 |
| 0.17.1, not console, **11-14 (ad day)** | 214 | **33.1 s** | 28.6-38.0 |
| 0.17.1, not console, all days | 627 | 50.3 s | 45.9-54.9 |

- The ad day alone pulls the 0.17.1 median from 62 s to 50 s. Ad traffic is a different audience, not a code change.
- The 0.14.0 sessions all came 11-10 14:00-20:00 UTC; 0.17.1 ran 21:00 UTC onwards (US evening/night, Asia morning), plus the ad. The time of day and the platform mix differ (0.14.0: 57 % PC; 0.17.1: 44 % PC, 23 % phone).
- **The version label lies.** `Config.Version` was not bumped between place 440 and 453, yet 29 scripts changed in between (ChaseService, PortalService, VisitorService, the PUT RAGDOLL HERE stations, NpcGlow, ChaseHud, HudPlus +2.7k, LikePrompt...). So "0.14.0" sessions ran on a mix of builds 440-453, and some of the suspects were already in the "good" data. Fix: bump `Config.Version` (or store `game.PlaceVersion`) on every publish (`RS/Shared/Config.luau:8`).
- **Server hops do not explain it.** Re-joins within 40 s of leaving (teleports from the new SINGLEPLAYER/MULTIPLAYER portals, update restarts) are 9 % of 0.17.1 records. Merging them into one visit moves the 0.17.1 median from 47.7 s to 50.7 s only.

What is left after removing the ad and the console: **a real, smaller regression of about 20 s (81 → 62 s)**, which shows in the 15-60 s window and in the long tail:

| Leaving rate per window (new, non-console) | 0-15 s | 15-30 s | 30-45 s | 45-60 s | 60-90 s | 90-120 s | 120-180 s |
|---|---|---|---|---|---|---|---|
| 0.14.0 (n=74) | 9 % | 10 % | 10 % | 11 % | 31 % | 12 % | 34 % |
| 0.17.1 organic (n=382) | 9 % | **14 %** | **19 %** | **18 %** | 35 % | 19 % | 36 % |

Share of new players past 2 min: 36 % (0.14.0) → 19 % (0.17.1); past 5 min: 12 % → 6 %. The first 15 s are unchanged (9 % = 9 %; boot median 0.9 s in both), so loading and the spawn are not the cause.

### 1.2 Ruled out by the diff (identical code in 440 and 465)

`OnboardingController.luau`, `OnboardingService.luau`, `GreeterService.luau`, `ToolCatalog.luau`, `TouchShoot` logic (only a ZOOM parent fix), `LaunchGift.luau`, `PlaytimeGifts.luau`, `GiftClock.luau` and `Toys.UNLOCK_FALLBACK = 25` did not change. `ProgressUI.luau` changed by 69 characters (not the egg card logic). So **the first-minute tool lock, the greeter, the free-egg card and the view-choice card are not what changed**. They are still problems (§3), but they were the same in the 85 s build.

### 1.3 What did change, dated

| Place range | Version | Change (file) | Can it cost 15-60 s and the tail? |
|---|---|---|---|
| 440 → 453 | 0.14.0 (unlabelled) | NPC Chase: 4-10 red dummies punch a new player 90 s in, then every 6-8 min (`SSS/Systems/ChaseService.luau:27-40`) | Tail only (90 s+). Partly in the "good" data. |
| | | 3 VISITOR ragdolls walk your lab (`VisitorService.luau:19`), 3 launch stations behind the spawn (`Playground.luau:570`), purple NpcGlow on dummies | More bodies simulated on the player's own device (phones) |
| | | SINGLEPLAYER / MULTIPLAYER portals in every lab; walking into one opens a server-list window (`PortalService.luau:239-246`) and can teleport you away (`:128-137`) | A surprise modal; a hop counts as a new session |
| 453 → 458 | **0.15.0** | **The gun follows the mouse and a standing avatar turns to face the cursor** (`Client/AvatarMoves.luau:780-792`, +8 kB; `AimService` sends aim 10x/s) | PC: in the walk view the free cursor now spins your body whenever you move the mouse to a button |
| | | **NextUnlocks**: three dark, padlocked "next weapon" cards on the tool bar from second 0 (`Client/NextUnlocks.luau:1-5`, `PokeController.luau:916-929`) | The first thing a new player sees is three locked weapons and "0/3" counters |
| 458 → 460 | **0.16.0** | **Bar cut from 6 to 3 weapon slots** (`RS/Shared/Toys.luau:253`); every catalog pick or egg weapon now needs a "pick a slot to replace" step (`PokeController.luau:587-594`, `ProgressUI.luau:304-306`) | Friction exactly when the catalog opens at ~25 s |
| | | HUD drawn at 0.8 (`HudSlots.luau:165-181`), launchers at 0.85 (`HudMenu.luau:40`), level bubble 34 → 22 px and silent level-ups (`HudPlus.luau:450-475`) | Smaller, quieter rewards |
| 460 → 464 | 0.17.1 | Phone sound pool fix (`FxController.luau`, +1.9 kB: "phones were nearly silent for their first minutes"); LikePrompt asks after a high point (`LikePrompt.luau:85-123`, never before 3 min) | Sound fix should help; LikePrompt is after the median |
| 464 → 465 | 0.17.2 | MoveStick: the walking thumb no longer fires the gun (`Client/MoveStick.luau`) | No data yet |

**Verdict.** Of the headline 85 → 54 s, about 12 s is the ad day (33 s median) and the mix of hours and devices. The rest (~19 s, 81 → 62 s for organic new players, visible in the 15-60 s window and the 2-min tail) is real, and it is already there in 0.15.0 (64 s, n=41) the same evening. It lines up with **0.15-0.16's changes to the bar and aiming**: three locked weapons on the bar from second 0 (0.15), the bar cut to three slots so every new weapon needs a replace step right when the catalog unlocks (0.16), and on PC the avatar turning to the mouse (0.15). The new lab content shipped under the 0.14.0 label (chase, visitors, portals) can only be judged with a correct version stamp. Proof needs an A/B or a clean before/after with a version stamp; the cheapest test is to put SLOTS back to 6 and hide NextUnlocks for players under 25 takedowns for one week.

---

## 2. Funnel (Onboarding_v1, Profile_v1, Session_v1; aggregate only)

**What the stores can and cannot say.** The seven onboarding steps (Joined, Spawned, FirstOwnToy, ReplayEnded, ThreeToys, SixToys, TenToys) are only sent to Roblox Analytics (`AnalyticsService:LogOnboardingFunnelStepEvent`, `OnboardingService.luau:227-252`); no DataStore keeps them. `Onboarding_v1` stores only `{done, mode}` per player, written when step 4 is reached or a view is picked (`:113-118, 250-252`). So steps 5-7 must be read on the Creator Dashboard (Analytics → Funnels). Below, the steps are rebuilt from what the stores do hold. Method as in `echo-heist/tools/funnel_report.luau`: aggregates computed inside the Luau script, no ids out.

### 2.1 First visits (Session_v1, 930 players, 2026-11-10 to 11-19)

| Step | Players | Share |
|---|---|---|
| Joined (first visit) | 930 | 100 % |
| Spawned (client scripts running, `Hello`) | 919 | 99 % |
| Got their own lab | 773 | 83 % |
| **FirstOwnToy** (first shot) | 619 | **67 %** |
| First takedown | 602 | 65 % |
| Stayed 25 s (= **ReplayEnded** or the 25 s unlock) | 714 | 77 % |
| Saw the free-egg modal | 624 | 67 % |
| Opened an egg | 445 | 48 % |
| 10+ takedowns | 202 | 22 % |
| Stayed 2 min (first playtime egg) | 199 | 21 % |
| Stayed 5 min | 64 | 7 % |
| 75 takedowns (first earned egg) | 18 | 2 % |
| Came back another time | 123 | 13 % |

Cross-check: `Onboarding_v1` holds **888 players with `done = true`** (step 4 reached) against **1,119 profiles** in `Profile_v1` = **79 %**, matching the 77 % who stayed 25 s. Of a 230-record sample, 74 % never chose a view (the card timed out), 18 % chose WALK and 7 % LAB VIEW: the view card is ignored by three in four.

### 2.2 Everyone ever (Profile_v1, all 1,119 profiles, read in full)

| Measure | Value |
|---|---|
| Takedowns, all time | median **3**, p75 11, p90 33, max 621 |
| ≥1 / ≥10 / ≥25 / ≥75 / ≥100 / ≥300 takedowns | 67 % / 27 % / 13 % / **3 %** / 2 % / 0.4 % (4 players) |
| Nobody has reached the top of the ladder | 0 players past 621; 13 weapons unlock above 600 takedowns |
| Time played, all time | median **62 s**, p75 129 s, p90 317 s; ≥5 min 10 %; ≥15 min 3 %; ≥1 h 5 players |
| Unopened eggs | median 2 (the launch egg + a playtime/daily egg sitting unopened), 24 players hold 5+, max 21 |
| Weapons owned from eggs/purchases | 527 players (47 %) own at least one; most common: RPG 131, TNT 125, C4 119, Rocket 115, Grenade 105, Minigun 101 |
| Hats | 0 players (hats only come once every weapon is owned) |
| Daily streak ≥2 days | 23 players (2 %); ≥3 days: 1 |
| Daily goals ever claimed | 47 players (4 %) |
| Minigames ever played (a best score saved) | **4 players** |
| Purchases (weapon purchase ids in `bought`) | **0**; 4 players picked a weapon to buy and did not finish |
| Settings ever changed | 6 players (1 turned blood off) |
| Keybinds ever changed | 0 |

"Money": the game has no soft currency; takedowns are the only score and Robux the only money. Robux: see §4 Monetisation (0 developer-product orders).

What it says: most of the game is never seen. The arena minigames (4 players ever), the daily loop (2 % with a streak), the ladder past 75 takedowns (3 %), building, places and hats are behind a wall that 9 in 10 players never get past, because the first two minutes do not hold them.

---

## 3. The first 60 seconds, traced in code

### 3.1 Timeline for a new player (all platforms)

| t | What appears | Code |
|---|---|---|
| 0 s | Spawn in your own lab (the free plot nearest the plaza; plaza if 10 labs are taken). G17 in hand. Bar: 3 slots (G17, Grab, Punch) + 3 locked NEXT cards. Hint "Click/Tap the dummy to shoot!" over the bar and a gold diamond over a greeter dummy that walks up. HUD around it: chaos meter, WEAPONS/NEXT button, LAB VIEW, RAGDOLL, level bubble, Shop, Menu; on PC also "TODAY'S DEAL ... SOON" (a product that does not exist, `HudPlus.luau:356`) | `OnboardingController.luau:524-534`, `GreeterService.luau`, `Toys.luau:251` |
| median 9 s (p90 31 s) | First shot. Hint becomes "Now try another tool!" | `OnboardingController.luau:475-488` |
| first shot + 3 s, or 15 s | **Card: "Walk, or view from above?"** (WALK / LAB VIEW), 270x104 over the bar, stays 10 s, toasts pause under it | `:43-44, 268-270, 370-467` |
| first big hit | **Instant Replay** takes the camera and hides all UI (`:636-647`) | `ReplayController` |
| replay end, or 25 s | Toast "3 weapons unlocked! Tap WEAPONS" ("3": the starter count, `Toys.luau:301`); WEAPONS pulses | `:160, 518` |
| ~27-30 s | **Modal: "Free egg! You have N FREE eggs!"** (the launch egg, every player until 10 Dec, `LaunchGift.luau:21`), first calm 2.5 s after the unlock. Shown in 70 % of all sessions; 64 % of those open it | `ProgressUI.luau:330-371` |
| unlock + 7 s | Toast "Play 2 more min for a FREE weapon egg! The clock is on WEAPONS." (cut off on a phone, see §7) | `GiftClock.luau:17, 60-66` |
| first replay + 10 s | Toast "Press F / Tap RAGDOLL to flop yourself!" (only if you never ragdolled) | `OnboardingController.luau:201-206` |
| unlock + 16 s | Toast "Jump in the LAVA or blast off the CANNON at the BULLSEYE!" | `:75-80` |
| 90 s | **NPC Chase**: 4-10 red runners punch you (health bar, you ragdoll at 0) | `ChaseService.luau:27-40` |
| 2/5/10/15 min | Playtime eggs → the egg modal again | `PlaytimeGifts.luau` |
| 3 min+ | FAVORITE window after a high point | `LikePrompt.luau:85-123` |
| 5 min | Free ULTRA minutes start (180 s) | `MoneyService.luau:383-389`, `Shop.luau:34-35` |

**Per platform.**
- **Phone (portrait, 95 % of phones):** the same sequence, but the hint, toasts and the view card sit in a toast box only a few dozen px wide between the chaos column and LAB VIEW (§3.4), and THROW/RUN/GRAB/SHOOT cover the slots and NEXT cards. Shooting: tap a dummy or the SHOOT button. First shot median 9.3 s; 14 % never shoot; they leave fast (median 15 s).
- **PC (keyboard + mouse):** the same sequence plus TODAY'S DEAL (SOON) and, after the unlock, the sandbox column and three Robux event cards on the right (`HudSlots.luau:94-101, 134-148`). The avatar turns to the free cursor (0.15). First shot median 8.5 s; 17.6 % never shoot.
- **Console / gamepad:** the hint says "Click the dummy to shoot!" (`OnboardingController.luau:281`: anything not touch gets the mouse text) and nothing on the pad can do it. The unlock at 25 s and the egg modal still come; the modal takes gamepad focus, so consoles open eggs (45 %) for weapons they can never fire. Only L3 (sprint) does anything in the world.

Three windows/cards and four toasts compete in the first 45 s. The vault's FTUE rule ("first verb by 30 s, first big reward by 40 s") is met for touch and mouse; the problem is everything stacked on top of it.

### 3.2 Control schemes

| Action | PC (keyboard + mouse) | Phone / tablet | Gamepad (console) |
|---|---|---|---|
| Shoot / use tool | Left click on a dummy; in the walk view a press fires even at nothing (`PokeController.luau:1194-1200`); hold for automatic guns (`LabCamera.luau:180-188`) | Tap a dummy, or SHOOT button (touch, walk view, gun picked; `HudSlots.luau:118-123`) | **Nothing.** |
| Pick slot | 1, 2, 3 (`Keybinds.luau` Slot1-3; Slot4-6 still listed but there are 3 slots) | Tap a slot | **Nothing** |
| Catalog (WEAPONS) | T | WEAPONS tile | **Nothing** (only via Roblox's UI-selection mode) |
| Grab / throw | G, drag with mouse | GRAB / THROW buttons | **Nothing** |
| Ragdoll self | F | RAGDOLL | **Nothing** |
| View | C (lab view), V (first person) | LAB VIEW | **Nothing** |
| Sprint | Shift | RUN | **L3** (`Sprint.luau:140`) - the only gamepad binding in the game |
| Windows | M places, N eggs, Y shop, P friends, J rewards, K controls, B build... | Launchers | Windows take gamepad focus and close on B once open (`LihFolkUIController.luau:12, 569-608`), but nothing opens them |

Gamepad gaps beyond shooting: tool select, catalog, grab/throw, ragdoll, view, build and every HUD launcher. Only the minigame start buttons (ProximityPrompts) and Roblox's own movement, jump and camera work on a pad. The egg modal works on a pad because it opens by itself with focus on OPEN IT (`ProgressUI.luau:390`): consoles open eggs (45 %) for weapons they cannot fire.

### 3.3 Why 26 % of PC sessions never shoot

- **About half are gamepad players.** `SessionStats` calls a device "pc" whenever a keyboard is present (`SessionStats.luau:150-152`). 101 "pc" sessions also had a gamepad; 83 of them at exactly 1920x1080 full screen (console/TV-like); **59 of the 101 never shot (58 %)**. In 0.17.1, 54 of the 104 PC non-shooters had a pad.
- Keyboard-and-mouse only: 72 of 410 never shot (**17.6 %**). Their median stay is short: 50 of the 104 PC non-shooters left within 60 s, 38 within 20 s. They leave before they try, during the hint + greeter + view card stack.
- Counting gamepads properly: **319 of 1,126 sessions (28 %) had a gamepad, and 84 % of them never shot.**

### 3.4 Phone: the game is laid out for landscape, players hold it upright

- **95 % of phone sessions are portrait** (210 of 221 in 0.17.1; screen 390x763 is the most common). The owner's captures are portrait too.
- `LayoutCheck.SCREENS` tests only landscape phones (`LayoutCheck.luau:41-49`: 667x317, 800x302, 750x311, 832x351). Portrait is never checked.
- In portrait the bar falls back to the full width ("a phone held upright", `PokeController.luau:434`) while GRAB, THROW, RUN, SHOOT and ZOOM stay anchored bottom-right at landscape offsets (`HudSlots.luau:58-69, 108-123, 152-157`): they land on the slots. The toast box is squeezed between the chaos meter and LAB VIEW (`HudSlots.luau:198-210`), so long toasts are cut to three short lines.

### 3.5 HUD clutter (phone, portrait, from `phone_lab_hud.png`)

Counted on screen: **18 of our elements** (17 controls and a toast) plus Roblox's 3 top-bar buttons and the thumbstick: LAB VIEW, gift toast, NEXT: KABOOM / GIFT 1:53 (the WEAPONS button with its tag), Shop, Menu (with a "!" badge), RAGDOLL, BUILD, level bubble 15 + bar, WEAPONS (bar lead), 3 slots (Grab, Minigun, Anvil), 3 locked NEXT cards (KABOOM 544/560, ?, LASER 544/680), THROW, RUN, GRAB. Overlaps (verified on the capture):

| Overlap seen in the capture | Code that places the elements |
|---|---|
| THROW circle on slot 2 (Minigun) | THROW: `HudSlots.luau:64-69` (phone: anchor 1,1 at 1,-116 / 1,-112); bar: `PokeController.plan` full width in portrait (`PokeController.luau:434`) |
| RUN circle on slot 3 (Anvil) and its "3" key badge | `HudSlots.luau:108-113` (phone: 1,-25 / 1,-102) |
| GRAB circle on NEXT card 2 and the slot row | `HudSlots.luau:58-63` (phone: 1,-108 / 1,-24); SHOOT takes the same box (`:118-123`) |
| Roblox jump button on the LASER card | Roblox TouchGui vs the NEXT row (`PokeController.luau:510-521`, `NextUnlocks.luau`) |
| Thumbstick drawn over the WEAPONS lead button | Roblox DynamicThumbstick vs the bar's lead column; `MoveStick.luau:14-35` then treats taps there as walking |
| BUILD floating mid-left over the world | `HudSlots.luau:70-75` (phone: 0,12 / 0.5,50) |
| Level "15" bubble and a 3 px bar just above the bar, left | `HudPlus.luau:437-506` |
| Toasts cut: "Play 2 more min for a", "Daily egg! Come" | box `HudSlots.toastBox` (`:198-210`) squeezed between the chaos column and LAB VIEW; `Toast.luau:105-118` (3 lines max on a phone); texts `GiftClock.luau:65`, `ProgressUI.luau:551` |
| LAB VIEW and RAGDOLL beside the NEXT/GIFT panel; Shop and Menu (with "!") crammed under it | `HudSlots.luau:42-51` (View, Ragdoll), `:131-133` (Weapons 158x46 on a phone), `GiftClock.luau` (GIFT tag), `HudMenu.luau:38-41` (launcher column top 130 on a phone, scale 0.85) |
| World signs ("OWNER BULLSEYE", "VIP", the lab name) read through the left column | lab props behind the HUD (`Playground.luau`, `Lab.luau`) |
| WEAPONS tab "EXPLOSI / VES" broken over two lines | `ToolCatalog.luau:335-360` (four equal tabs on a 414 px screen) |
---

## 4. Content and depth

| What | Count / detail | Evidence |
|---|---|---|
| Weapons/tools | **69**: Guns 20, Melee 18, Specials 21, Explosives 10. Start: 3 (G17, Grab, Punch); the rest by takedowns up to 1,600 (Golden Deagle) | `RS/Shared/Toys.luau` (add() calls); header still says "five weapons" (`:11`) |
| Labs | 10 per server (6 dummies each, own playground: fall tower, cannon, wrecking ball, ramp, lava, bullseye, spikes, mace, 3 launch stations, 2 portals) | `Lab.luau:45, 75`, `Playground.luau:1-17, 570` |
| Places | Plaza (12-person crowd) + 6 rooms: night hangar, coffee bar, office, food court, supermarket, white test room | `WorldMaps.luau:1-8`, `CrowdService.luau:52` |
| Minigames | 2: Red Light Green Light (60 s), Shoot 'Em (45 s) in the Game Arena | `MinigameService.luau:1-14` |
| Co-op | Horde (up to 18 runners), NPC Chase, friend NUKE/PRANK, plaza PvP, lab invites | `HordeService.luau:34`, `FriendsService.luau:1-14` |
| Server events | 5 paid: Dummy Rain, Mega Bomb, Zero-G, Bouncy Floor, Flash Freeze | `RS/Shared/Events.luau:21-27` |
| Build | Workshop with a parts catalog, wiring, save codes (`Builds_v1`) | `BuildService.luau`, `Build/Catalog.luau` |
| Doctor mode | Vitals monitor, organs, wounds | `HospitalCharts.luau`, `VitalsService.luau` |
| Christmas | Hats, scarves, tree, presents, snow, **on since 7 Nov** (`Christmas.luau:16`) | Santa hats in mid-November in the captures |
| Retention systems | Daily egg + streak, 3 daily goals, playtime eggs (2/5/10/15 min), launch egg, group egg (SOON), trophies (5 of 8 badges made), leaderboards, Streamer Mode, clips | `Badges.luau:11-18`, `RewardsService.luau`, `DailyGoals.luau` |

**Progression and economy.** One currency: takedowns. The ladder runs 0 → 1,600 (`Toys.luau`); an egg every 75 takedowns (50 with VIP, `Progress.luau:13`, `Shop.luau:37`), holding a weapon you do not have. Median session takedowns: 2; mean 9.7; 22 % of sessions reach 10. A new player meets "NEXT: X, N kills to go" from second 0. Eggs are given away so often (launch, daily, 4 playtime eggs a day, 75-takedown eggs) that the owner's own account shows **19 unopened eggs** (`phone_free_egg_modal.png`), and the modal says "You have 19 FREE eggs!" - the egg has no value left. Eggs also skip the ladder: the weapons most owned from eggs are the RPG (131 players; it unlocks at 760 takedowns), TNT, C4, Rocket, Grenade and Minigun (`Profile_v1`), so the egg hands out the end-game explosives on day one and the kill ladder has little left to promise.

**Monetisation.** Everything is wired and on sale (checked live with `GetProductInfoAsync`):

| Item | Type | Price | On sale | Evidence of use |
|---|---|---|---|---|
| ULTRA (no cooldowns, 2x props, 2x big bangs) | Game pass | 249 R$ | yes | `Sales` reported 0 |
| VIP (tag, egg every 50 not 75, board tag) | Game pass | 149 R$ | yes | `Sales` reported 0 |
| Weapon (25 / 49 / 99 / 199) | Dev products, one per price tier | 25 / 49 / 99 / 199 R$ | yes | **0 orders** |
| Dummy Rain, Zero-G, Flash Freeze / Mega Bomb / Bouncy Floor | Dev products (server events) | 25 / 35 / 20 R$ | yes | **0 orders** |
| Starter Pack "3 weapon eggs + the Revolver" | Not created (`Shop.STARTER_PACK = 0`) | (29 R$) | no, card says SOON | - |
| Group egg | Not set (`Shop.GROUP_ID = 0`) | - | no, card says SOON | - |

- `Orders_v1` (every developer product goes through `Purchases.luau` and is saved there before it is granted) has **no keys at all**: no developer product has ever been bought. The pass `Sales` field reads 0 for both (the field can lag; confirm on the Creator Dashboard). No profile in the sample has a weapon purchase id (`bought`), 2 had picked a weapon to buy and not finished.
- The code path itself looks correct (one ProcessReceipt, order saved before `PurchaseGranted`, retries, claims; `Purchases.luau:1-22`, `WeaponShop.luau:1-14`).
- Why nothing sells: a free weapon egg arrives every few minutes (§4), so a 25-199 R$ weapon competes with a free one; ULTRA's value is given away free for 3 min a day after 5 min of play (`Shop.luau:34-35`), which only 7 % of first visits reach; events cost Robux to show something to a 10-player server of private labs.
- Compliance: the planned Starter Pack contains **3 weapon eggs (a paid random item)**. Before it goes on sale it needs numeric odds and `PolicyService.ArePaidRandomItemsRestricted` handling (vault: *Policy and Age Rules 2026*).

**Social.** Friend features need a Roblox friend in the same server; servers hold 10 and everyone is in a private lab (labs are private, `FriendsService.luau:11-13`), so strangers rarely meet. No trading, no shared goal with strangers except the Horde.

---

## 5. Maturity

What the game shows (most extreme content counts):
- **Severed limbs**: `Config.SEVERING = true` (`RS/Shared/Config.luau:13`); heavy blades, the shotgun up close and close blasts cut a limb off at the joint with purple caps on both stumps (`VitalsService.luau:330-380`, `Blasts.luau:18`).
- **Organs and wounds by name**: heart, lungs, liver, stomach, kidneys, intestines, aorta, spine, brain, femoral artery, with bleed rates (`RS/Shared/Anatomy.luau:7-13`), read out by HitInfo and the doctor monitor.
- **Blood**: purple flat drops and floor splats that stay a while (`Client/BloodFx.luau:2-8`), on by default (`Settings.luau:36`).
- **Real-world guns by model name**: G17, Deagle, AK Rifle, M4 Carbine, Micro SMG, Tommy Gun, LMG, RPG, Nuke (`Toys.luau`), with "A real handgun" on the G17 card (capture).

Vault (`Gore Policy and Kid-Friendly Hit Feedback`, `Policy and Age Rules 2026`): "dismemberment and visible organs push content to Restricted"; Restricted = ID-verified 18+ only; Moderate = Roblox Select (9-15, if selected) and 16+; Minimal/Mild = everyone including Roblox Kids (5-8). Purple blood can count as unrealistic, but **severing is listed by name** and the code comment admits it (`Config.luau:10-12`).

Likely label: **Restricted if the questionnaire was answered honestly** (severing), which would remove nearly the whole audience; with severing off, **Moderate** (realistic-looking guns, repeated violence, persistent splats), which keeps out under-9s and every 9-15 player not in Select. The live game has 1,302 visits and players aged under 13 on phones and consoles, so the current questionnaire probably under-states the content: a moderation risk. To reach Mild: `SEVERING = false`, make the "Stylised" hit style the default (`Settings.luau:97`), drop real gun model names (G17 → "Pistol", AK → "Rifle"), and keep organ names inside the opt-in doctor mode.

---

## 6. Tech health

- **Bodies a phone simulates**: its own lab's 6 dummies + greeter + 3 visitors + up to 10 chasers + launched props, each an `ActiveRagdoll` with ball sockets and align constraints (`RS/Shared/Ragdoll/ActiveRagdoll.luau`, 73 kB), owned by that client (`DummyControl.luau:88` SetNetworkOwner). Server extras capped at 24 (`EventService.luau:53`) plus the 12-person crowd. A horde (up to 18) or a Dummy Rain (12) adds on top for whoever owns them. Phones also draw blood parts, bullet holes and the snow.
- **Boot is fine**: median 0.9 s to client scripts (p90 2.4 s); phones 1.0 s.
- **Sound**: before 0.17.1 a phone made 230 Sounds at once and was "nearly silent for its first minutes" (`FxController.luau` header, fixed in 0.17.1). The 0.14.0 phone data was recorded with that bug.
- **Errors in code**: none fatal found in a read of the first-minute path. Stale items players see: "SOON" cards for a Starter Pack and a group that do not exist (`Shop.luau:50-55`, `HudPlus.luau:356`, `RewardsUI.luau:108,192`), What's New for returning players always shows the 0.13.0 entry (`Shop.luau:58-60`, `MoneyService.luau:391-399`), keybinds for slots 4-6 that no longer exist (`Keybinds.luau`), 3 of 8 badges with id 0 (`Badges.luau:16-18`).
- **Tests**: 56 modules in `SSS/Server/Tests`, Studio-only (`SelfTest.server.luau:14-16`). None test a gamepad, a portrait phone, or SessionStats; `LayoutCheck` covers landscape only.
- **Measurement**: `SessionStats` classifies keyboard+pad as PC (`:150-152`), and `Config.Version` was not bumped across 14 publishes (440-453).

---

## 7. "How bad does it look"

From the captures (weighted above anything inferred from code):
- **Overlapping HUD** (§3.5): THROW, RUN, GRAB circles on the bar; the thumbstick on WEAPONS; a jump circle on the LASER card. It reads as broken, not cluttered.
- **Truncated text**: "Play 2 more min for a", "Daily egg! Come", tab label "EXPLOSI / VES" broken over two lines in WEAPONS (`ToolCatalog.luau` tabs: four equal tabs on a 414 px screen).
- **Generic dark-slab UI kit** (LihFolk kit: dusk glass panels, black boxes with white caps). LAB VIEW, RAGDOLL, BUILD are plain rectangles with text and no icon; Shop and Menu are the only iconed tiles.
- **POWER/CHAOS bars nearly empty** for every gun (`Toys.luau:124`: power = speed / MAX_HIT_SPEED, MAX_HIT_SPEED 135 at `:107`; guns hit at 26-36), so the weapons look weak in their own shop.
- **Dummies**: plain grey R15 blocks with a crash-test badge and Santa hats in November (the sculpted `DummySkins` bodies do not show in the captures).
- **World**: flat grey floor with yellow lines, a sign with the owner's name, black-and-yellow boxes; snow particles. Third person puts the avatar over the lower third of a portrait screen.
- **Modals**: "Free egg!" covers the middle of the screen with "You have 19 FREE eggs!".

From code (lower weight): lighting by `ZoneLighting.luau` (atmosphere, bloom, colour correction, shadows soft 0.25, per-room profiles); rooms built from parts plus some Creator Store props (`WorldMaps.luau:1-8`); purple blood discs.

**Screenshots the owner should take** (each on a phone held upright, and the same on PC 1920x1080):
1. The first frame after spawning (no input), new account.
2. 3 s after the first shot (the view card).
3. The moment of "3 weapons unlocked!" and the egg modal after it.
4. WEAPONS open on each tab (MELEE, GUNS, EXPLOSIVES, SPECIALS), scrolled to the bottom.
5. The plaza crowd, and one room from Places (the night hangar).
6. A Horde and an NPC Chase in progress.
7. A severed limb close up, and the doctor monitor (for the maturity questionnaire).
8. Console: the first 30 s on an Xbox or PS controller.
9. The PC HUD with TODAY'S DEAL "SOON".
10. Landscape phone, same as 1-3, to compare with portrait.

---

## 8. Top 15 problems (ranked by players lost)

| # | Problem | Evidence | Who it hits |
|---|---|---|---|
| 1 | **Gamepads cannot play.** The only gamepad binding is L3 sprint; no fire, slot, catalog, grab, ragdoll or view | `Client/Sprint.luau:140` is the only `ButtonL3`/pad bind; fire listens to `MouseButton1`/`Touch` only (`TouchShoot.luau:117,124`, `LabCamera.luau:643-683`). 319 of 1,126 sessions (28 %) had a pad; **84 % never shot**; console median 47 s | 28 % of sessions |
| 2 | **Portrait phones get a landscape layout.** THROW/RUN/GRAB/SHOOT sit on the bar, toasts are cut | 95 % of phone sessions are portrait (210/221); `LayoutCheck.luau:41-49` tests landscape only; `HudSlots.luau:58-69,108-123,198-210`; all 3 captures | ~20 % of sessions |
| 3 | **The first 45 s are a stack of interruptions**: view card, replay that hides the UI, unlock toast, free-egg modal, 4 more toasts | §3.1; `OnboardingController.luau:43-44,370-467,636-647`; `ProgressUI.luau:330-371` (egg modal in 70 % of sessions, ~27-30 s in) | Everyone new; matches the 15-60 s leave spike |
| 4 | **0.15/0.16 bar changes**: 3 padlocked NEXT cards from second 0, bar cut from 6 to 3 slots with a replace step | `NextUnlocks.luau`, `Toys.luau:253`, `PokeController.luau:587-594`; dated in §1.3; leave rate 30-60 s up from ~10 % to ~18 % | Every new player |
| 5 | **Maturity: severed limbs, named organs, real gun models** → Restricted if answered honestly, Moderate at best; out of discovery for under-9s and most 9-15s; moderation risk if under-declared | `Config.luau:13`, `VitalsService.luau:330-380`, `Anatomy.luau:7-13`, `Toys.luau` names; vault: dismemberment and visible organs → Restricted | Reach of the whole game |
| 6 | **No goal past minute 2.** Median 2 takedowns a visit; the next weapon is a kill count; earned eggs need 75 takedowns (2 % of first visits get there) | Funnel §2; `Progress.luau:13`; 21 % of first visits reach 2 min, 7 % reach 5 min | Everyone who stays |
| 7 | **Egg economy without value**: free eggs everywhere (launch, daily, 4 playtime eggs, 75 takedowns), the owner's account holds 19; the egg modal returns after every egg | `phone_free_egg_modal.png`; `LaunchGift.luau:21`, `PlaytimeGifts.luau`, `ProgressUI.luau:308-311` | Progression and any future egg sales |
| 8 | **Monetisation earns nothing so far**: 0 developer-product orders ever (`Orders_v1` empty); passes are on sale but nothing pushes them; dead "SOON" cards | §4 Monetisation; `Shop.luau:50-55`, `HudPlus.luau:356` | Revenue |
| 9 | **Ad traffic bounces in 33 s** (11-14, n=214 new non-console) | §1.1 | Paid acquisition |
| 10 | **Measurement is blind**: `Config.Version` not bumped across 14 publishes (440-453); keyboard+pad counted as PC; funnel steps 5-7 only in Roblox Analytics, not in any store | `Config.luau:8`, `SessionStats.luau:150-152`, `OnboardingService.luau:113-118, 227-252` | Every decision |
| 11 | **PC: the avatar turns to face the free cursor** whenever a gun is held (0.15) | `AvatarMoves.luau:780-792` | PC walk view |
| 12 | **Looks cheap/broken on a phone**: overlaps, cut text, "EXPLOSI/VES", grey default dummies, Santa hats since 7 Nov, empty POWER bars on guns | §7; `Christmas.luau:16`; `Toys.luau:107,124` | First impression, store page clips |
| 13 | **Social pull is weak**: 10-player servers of private labs; friend features need a Roblox friend in the same server; portals send players to solo servers | `Lab.luau:75`, `FriendsService.luau:1-14`, `PortalService.luau:1-12` | Virality, retention (13 % return) |
| 14 | **More bodies on phones, and the NPC Chase on the newest players** (4-10 punching runners at 90 s, 3 visitors, stations) | `ChaseService.luau:27-40`, `VisitorService.luau:19`, `DummyControl.luau:88` | Phones, weak players |
| 15 | **Stale bits players see**: What's New stuck on 0.13.0, slot 4-6 keys, 3 badges with id 0, "five weapons" header vs 3 | `Shop.luau:58-60`, `Keybinds.luau`, `Badges.luau:16-18`, `Toys.luau:11` | Polish, trust |


## 9. Quick wins (each ≤ 1 day)

1. **Gamepad fire and basics** (`ContextActionService`, client): R2 = fire at the screen centre (reuse the touch SHOOT path in `TouchShoot.luau`, which already aims at the centre), L1/R1 = previous/next slot, Y = WEAPONS, X = grab/throw, B = ragdoll, D-pad up = view. Fixes problem 1 for 28 % of sessions.
2. **Lock phones to landscape**: `StarterGui.ScreenOrientation = LandscapeSensor` (one property in Studio). The tested layout then applies to the 95 % who hold the phone upright. Add a portrait screen to `LayoutCheck.SCREENS` anyway.
3. **Drop the view-choice card for first visits** (`OnboardingController.luau:487, 532`: remove both `askChoice` calls; keep the LAB VIEW button).
4. **Egg modal after 90 s, not 27 s**: `calm()` (`ProgressUI.luau:332-342`) also waits for `time() > 90`; show the egg count as a badge on WEAPONS instead of a modal before that.
5. **Hide NextUnlocks for the first visit** (until 25 takedowns) and put `Toys.SLOTS` back to 6 for one week; compare 15-60 s leave rates.
6. **Stamp every record with the build**: `game.PlaceVersion` into the Session record next to `Config.Version`; record `pad` and `keys` separately instead of folding pad+keys into PC (`SessionStats.luau:150-152`).
7. **Maturity**: `Config.SEVERING = false`; Blood default OFF (stylised, `Settings.luau:36,75`); rename real models (G17 → Pistol, AK Rifle → Rifle, M4 Carbine → Carbine, Deagle → Hand Cannon). Then answer the questionnaire again.
8. **Remove dead cards**: hide TODAY'S DEAL and the group card while their ids are 0 (`HudPlus.luau:356`, `RewardsUI.luau:108,192`), drop slot 4-6 keybinds, set What's New to 0.17.
9. **Christmas from 1 December** (`Christmas.luau:16`): Santa hats in mid-November read as stale.
10. **PC aim**: turn the body to the cursor only while the right mouse button or shift lock is held (`AvatarMoves.luau:783-792`).
11. **Toast width in portrait**: let `HudSlots.toastBox` use the screen width under the top row on narrow screens (`:198-210`).
12. **Power bars**: scale guns against the strongest gun, not against launch tools (`Toys.luau:107,124`), so the GUNS tab does not look empty.

