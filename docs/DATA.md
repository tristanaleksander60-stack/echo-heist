# DATA: player data, purchases and progress

The data layer for Heist Yourself (MASTERPLAN §5 and §8.7-8.8). It is installed from the LihFolk systems library as-is. Echo Heist's own rules are pure modules with Lune unit tests. Status: everything passes locally (build, lint, unit specs, place check). Nothing has run in Studio or Open Cloud yet; see "Owner actions".

## Layout

| Path (Rojo) | In the place | What |
|---|---|---|
| `src/lihfolk/` | `ReplicatedStorage/LihFolk` | Library shared modules: `Signal`, `Net`, `RateLimit`, `Janitor`, `Feedback` (client messages). This is the install path the library expects. It is a separate folder because Rojo cannot map a subfolder of `src/shared` to a second place without duplicating it |
| `src/server/Data/` | `ServerScriptService/Server/Data` | Library server modules: `PlayerData`, `Policy`, `Currency`, `Receipts`, `Shop`, plus `Rewards` and `Inventory`, which `Receipts` and `Shop` require. Inventory is not initialised (no slice, no remotes). Echo Heist's wiring and API: `DataService` |
| `src/shared/Data/` | `ReplicatedStorage/Shared/Data` | Pure rules (no engine services; Lune-tested): `Schema`, `Progress`, `DailyVault`, `Store`, `Keys`, `Calendar`. Client helper: `ProductPrices` |
| `src/shared/Config.luau` | `Shared/Config` | `Config.Data`: every tuning number, the catalog, the products and the level medal rules |

The library files are byte-for-byte copies, formatted with StyLua (whitespace only). Not installed, because nothing uses them yet: `DailyRewards` (it is a login-reward track; the daily vault is a level clear, so `DailyVault` reuses its streak rule), `Leaderboard` (the board arrives Dec 11), `Quests`, `Codes`, `Rebirth`, `EggHatch` and `Odds` (no paid randomness, ever).

Boot: `src/server/init.server.luau` calls `DataService.start()` inside a `pcall`, then `Main.start()`. If the data layer fails, the heist still runs; it just does not save (solo must always be playable).

## Keys and stores

| Where | Store | Profile key | Ghost key (§8.7, not written yet) |
|---|---|---|---|
| Live experience | `EH_Player_v1` | `U_<userId>` | `G_<levelId>_<userId>` |
| Test experience (`Config.Data.TEST_UNIVERSE_IDS` = 10776026960) | `EH_Player_v1` | `_TEST_U_<userId>` | `_TEST_G_<levelId>_<userId>` |
| Studio (any place) | `EH_Player_v1_STUDIO` (library default) | `_TEST_U_<userId>`; with the ServerStorage attribute `TestProfileKey = "a"`: `_TEST_U_T_a_<userId>` (a fresh profile) | as above |

Never rename `STORE_NAME` or `KEY_PREFIX` after launch. `Keys.isWritable` makes tools and tests refuse a live key in a test environment and a test key in a live one. Open Cloud can list and clear test data by the `_TEST_` prefix.

## The profile document (one key per player, written only by PlayerData)

```
{ Schema = 1,                       -- the schema version (record level)
  Data = {
    Currency   = { Balances = { Cash, Stars, CandyCanes }, Earned = {...} },   -- library Currency
    Purchases  = { [productKey] = timesGranted },                              -- library Receipts
    ShopBought = {},                                                           -- library Shop (unused)
    Heist      = <schema v1 slice, below> },
  Meta = { Created, Receipts = { [PurchaseId] = time } (last 500), ReceiptOrder, PurchaseLog (last 100) },
  Session = { Token, JobId, PlaceId, ExpiresAt } }  -- the 90 s lease; nil when released
```

### `Heist` slice, schema v1 (`src/shared/Data/Schema.luau`)

| Field | Type | Meaning |
|---|---|---|
| `levels[levelId]` | `{ medals, best?, haulBest, plays, clears, firstClearAt }` | `medals`: a set of `Haul`, `Crew`, `Clean`, `Diamond` (story) or `Haul1`-`Haul3` (Clone Party). `best = { stars, clones, timeMs, haul, at, recHash? }` is the best cleared, untainted run. `haulBest` is the biggest untainted haul |
| `unlocked[levelId]` | `true` | Open levels (the first level is always open) |
| `trophies[id]` | unix time | Level trophies, event trophies and ornaments (`Orn_Advent2026_DD`, `Orn_VaultNN`) |
| `shelf` | `{ id }`, max 8 | The van shelf, in order. Ornaments go on the advent tree, not the shelf |
| `bagLevel` | 0-3 | Clone Party carry upgrades (Cash) |
| `cosmetics.owned[id]`, `cosmetics.equipped[slot]` | `true`, id | Slots: `cloneStyle`, `cloneHat`, `vanPaint`, `trail`. Defaults are owned implicitly |
| `daily` | `{ lastClearDay, streak, bestStreak, stars, haulDay, haulBest, haulClones, haulTimeMs }` | Daily vault (UTC day numbers) and the "biggest haul today" entry with its tie-breaks (clones, then time) |
| `settings` | `{ reducedMotion, relaxed, colourBlindGlyphs }` | Booleans |
| `ftueStep`, `firstHeistDone`, `stats = { heists, clears }` | numbers, boolean | Onboarding and counters |

Stars are stored as a `Currency` balance so the UI gets a `Stars` attribute. The balance is a mirror: it is recomputed from the medals plus `daily.stars` after every award and on load, and it is never spent. Cash and Candy Canes are normal balances. None of them can be bought with Robux (`paid = false`).

Size: a stress profile (30 levels, every trophy and cosmetic, 40 future ornaments, a full shelf) is 13.7 KB of JSON. The budget is 16 KB, and a unit test enforces it.

**Analytics consent:** nothing is stored. The game sends no personal data off-platform, and Roblox `AnalyticsService` runs under Roblox's own terms. Ad eligibility (rewarded video, 13+) comes from `PolicyService` at runtime and is never saved. Add a flag here only if an off-platform analytics or ads SDK is ever added.

## Guarantees (lihfolk-systems PlayerData + Receipts, per roblox-datastore-safety)

- **One writer:** only `PlayerData` writes profiles, and the place has exactly one `ProcessReceipt` assignment. `tests/place_check.luau` asserts both.
- **Session lock:** a 90 s lease checked and renewed inside `UpdateAsync`. Every save is fenced by the session token, so a server that lost the lease can never overwrite data. A claim tries 6 times (about 7.5 s) while another server holds the lease.
- **Load outcomes:** `ready`, `locked`, `failed`, `corrupt` and `newer` are separate. Only `ready` has a save path. Any other outcome kicks with a clear message and never saves defaults over real data.
- **Autosave:** every 30 s, staggered and dirty-gated. It also renews the lease.
- **Leaving and shutdown:** on `PlayerRemoving` the profile saves and releases the lease. `BindToClose` saves everyone in parallel with a 26 s deadline (3 s in Studio).
- **Retries:** exponential backoff with jitter, a budget check before each call, and no retry on 1xx or 4xx errors.
- **Shape checks:** `findUnsavable` refuses NaN, infinity, Instances, and mixed or holed arrays before writing. `Schema.sanitize` repairs wrong types after load and logs what it changed.
- **Play/Stop/Play:** Stop releases the lease within the 3 s Studio window, and the next Play claims it. If a release did not land, the claim retries for about 7.5 s and then kicks with "still saving on another server": the data is kept, and you play again a minute later. **Server hop:** the old server's release, or at worst the lease expiring after 90 s, lets the new server claim the profile. A same-server rejoin waits for its own release first.
- **Purchases:** a grant, its `PurchaseId` and the purchase log entry are written in the same document and the same write. `PurchaseGranted` is returned only after that save succeeds. A redelivered receipt is a `duplicate` and is acknowledged without a second grant. Unknown products, absent players and unloaded profiles get `NotProcessedYet`.

**Offline mode:** in Studio without API access, or in an unpublished place, `DataService` reads one probe key before `PlayerData` starts. If the read fails, the data layer goes offline: `ReplicatedStorage.DataOffline = true`, nobody is kicked, nothing saves, awards return `NotReady` and every level counts as unlocked. Live servers have no probe. If `PlayerData.Start` fails there, the server warns loudly and plays without saving.

## Migration policy

1. Adding a field needs no migration. Add it to `Schema.defaultHeist()`: `PlayerData` reconciles missing keys on load, recursing into non-empty default tables but not into empty map tables, and `Schema.sanitize` repairs its type.
2. Renaming, moving, splitting or re-typing a field needs a migration. Add `Schema.MIGRATIONS[n]`, which upgrades a version n-1 document to n by mutating the whole `Data` table synchronously. Bump `Schema.VERSION` to n and add a unit test with a real fixture of the old shape (`Schema.migrate(data, n - 1, n)`).
3. Never edit a released migration. Never delete purchases or unknown cosmetic ids, because a rollback must not destroy them.
4. A server refuses documents newer than its own `VERSION`, so rolling back a schema change keeps players on newer servers. Before any release that touches data code, take a snapshot and soft-shut-down the old servers (MASTERPLAN §8.12).

## Rules (pure, `src/shared/Data/`)

- **Story medals:** a run is cleared when `haul >= haulTarget` and the target was banked before Dawn. **Haul** = cleared. **Crew** = cleared with `clones <= par`. **Clean** = cleared with no catches and no busted clones in the final run. **Diamond** = cleared with fewer clones than `devClones`; it only applies once that value is set, and it is not a Star.
- **Clone Party:** Haul1-3 for reaching each `haulTiers` value.
- **Stars and unlocks:** every medal except Diamond is one Star. Medals are a union across runs. A level opens once its `unlockAfter` level is cleared and the player has at least `starsRequired` Stars. Unlocks are never taken away. A clear always leaves the level unlocked.
- **Co-op carry** (default rule 2026-11-12, owner to confirm): a crewmate who plays a level the crew leader opened, but has not unlocked it themselves, gets the full result (Cash, medals, Stars, bests); clearing it unlocks it for them. The heist server passes `opts.crew = true`; a solo call on a locked level is still refused as `Locked`. Alternative if the owner prefers: Cash only, no medals (one line in `DataService.awardHeistResult`).
- **Play order** (`Config.Data.LEVEL_ORDER` = `Levels/Catalog`, owner decision 2026-11-12): Back Room → Two Doors → **Clone Party** (the "party break", design number L5) → Lights Out → Night Clerk → Big Score: Bank, so "8 OF ME" comes around minute 10 of a first session (`tests/sim/Pacing.spec.luau`). Clearing Two Doors opens **both** Clone Party and Lights Out: "NEXT" and the garage list lead to the party first, but a kid who leaves it or misses Haul1 keeps the story (in the sim's greedy-kid test 2 of 40 miss Haul1). Big Score: Bank needs Night Clerk cleared and 6 of the 15 Stars of L1-L5; a kid who skipped the party with only the four Haul Stars is sent back to it by the next-goal card (its Haul tiers are the easiest Stars).
- **Personal best order:** more Stars, then fewer clones, then less time, then a bigger haul. `summary.newBest` tells the heist server when to write the ghost key.
- **Tainted runs** (Validator, §8.8) earn Cash but no medals, bests, clears, trophies or board entries. **Relaxed** runs earn everything but are not board-eligible.
- **Cash:** `floor(haul × CASH_PER_HAUL × (1 + min(friends × 10%, 30%)))`, plus the level's first-clear bonus on a first clear, capped at `MAX_CASH_PER_HEIST`.
- **Daily vault:** the vault design is `(day - launchDay) % VAULT_COUNT + 1` (UTC; launch day Dec 3 = vault 1, so slot n = daily design n and `Orn_VaultNN` is design NN's ornament). The first clear of today gives 1 Star, 250 Cash, 5 Candy Canes (only during Dec 3 - Jan 4) and that vault's ornament; in December that is the day's advent ornament. The streak allows one grace day. A missed advent day can be cleared until Dec 31 for its ornament and the same rewards; catch-ups never touch the streak.
- **Board entry:** today's best run, untainted and not Relaxed: the bigger haul, then fewer clones, then less time (`DailyVault.beatsBoard`; `timeMs` is the sim's `result().daily.timeMs`). An exact tie keeps the earlier entry; an empty haul never boards.
- **All numbers are placeholders** until the level layouts exist: `haulTarget`, `maxHaul`, `firstClearCash`, the bag costs and the item prices are all in `Config.Data`. The heist server can supply level rules from `src/shared/Levels` with `DataService.setLevelResolver(lookup, order)` before `start()`.

## Server API (`DataService`, for the future heist server)

Every call validates its input, then mutates the profile with no yield in between. Calls return a `Net.Result` (`{ ok, code, data }`).

| Call | Notes |
|---|---|
| `awardHeistResult(player, levelId, result, opts?)` | `result = { haul, clones, timeMs, catches, busted, beforeDawn, tainted, relaxed, friends?, recHash?, heistId? }`. These facts are decided by the server from actor positions. `opts.crew = true`: co-op carry (above). Refused: `NotReady`, `UnknownLevel`, `Invalid` (anything out of range: haul above the level's `maxHaul`, clones above the cap, NaN, fractions), `Locked` (solo only), `TooFast` (under 10 s since the last award), `Duplicate` (a `heistId` already seen). `data` = `{ cleared, firstClear, newMedals, levelStars, starsGained, totalStars, newBest, newHaulBest, cash, trophy, unlocked, boardEligible }` |
| `awardDailyVault(player, vaultDay, result, startedDay?)` | `result = { cleared, haul, clones, timeMs, tainted, relaxed }` (pass the sim's `result().daily` as is; `timeMs` is required, 0..`MAX_HEIST_MS`). The server works out today from `os.time()`. `vaultDay` must be today or an advent catch-up day (`WrongDay` otherwise). `startedDay` = the server day when the heist began: a vault started before the daily reset and finished after it is judged on that day (at most one day back), so it keeps "today" and the streak |
| `grantTrophy(player, trophyId, reason)`, `grantCosmetic(player, id, reason)` | `grantCosmetic` is for free items only; paid cosmetics come only from receipts |
| `earnCash`, `spendCash`, `earnCandyCanes(player, amount, reason)` | Whole amounts from 1 to `MAX_CASH_PER_HEIST`. Candy Canes only during the event |
| `isLevelUnlocked`, `getBagLevel`, `getSettings`, `getSnapshot`, `isReady`, `waitForData`, `status`, `environment` | Reads |
| `setFtueStep(player, step)` | Only moves forward |
| `setPromptsBlocked(player, bool)` | Store prompts are refused while this is set (during a heist or a bust, §5.4) |
| `DataService.Loaded`, `DataService.Changed` | Signals |

Player attributes for the UI: `Cash`, `Stars`, `CandyCanes` (Currency), `Setting_ReducedMotion`, `Setting_Relaxed`, `Setting_ColourBlindGlyphs`, `Cosmetic_<slot>`, `BagLevel`, `DataReady`, `PaidRandomAllowed`.

## Client remotes (`Net`: rate limit, then argument count and types, then handler)

`Data.Snapshot()`, `Data.SetSetting(key, bool)`, `Data.Equip(slot, cosmeticId)`, `Data.Buy(itemId)` (Cash or Candy-Cane items and trophies; the price comes from server config), `Data.BuyBagLevel()`, `Data.SetShelf({ trophyId })`, and the push channel `Data.Changed(snapshot)`. From the library: `Shop.PromptProduct(productKey)`, which runs the prompt-time checks. `Shop.Buy` and `Shop.PromptPass` exist but have no items or passes configured. All remotes live in `ReplicatedStorage/LihFolkRemotes`.

These are menu intents with no say over outcomes in a heist. CLAUDE.md still says "clients only send `RequestRewind`"; MASTERPLAN §8.8 says that rule widens when this code lands, so CLAUDE.md needs updating.

## Store (launch, §5.4)

Robux developer products. Each has fixed cosmetic contents and is sold once per player (`limit = 1`). The prompt is refused when everything in it is already owned, when its `lastDay` has passed, or while prompts are blocked. Late receipts still grant. The `id` is 0 until the owner creates the product, and a 0 is never prompted. **Prices are never in code:** the UI calls `ProductPrices.new():getAsync(productKey)`, which uses `GetProductInfoAsync(id, Enum.InfoType.Product).PriceInRobux`. The prices below are the plan's targets for the Creator Dashboard.

| Product key | Grants | Planned price (dashboard) | Sold |
|---|---|---|---|
| `StyleGoldGhost` | Gold Ghost clone style | 149 R$ | launch |
| `StyleNoir` | Noir clone style | 99 R$ | launch |
| `StyleNeonOutline` | Neon Outline clone style | 79 R$ | launch |
| `ChristmasCrew` | Santa clone style + Sleigh Red van paint + Snow Trail (contents shown upfront) | 199 R$ | until Jan 4, 2027 |
| `PaintChrome` | Chrome van paint | 99 R$ | launch |
| `PaintGoldRush` | Gold Rush van paint | 49 R$ | launch |

Earned-currency items (`Data.Buy`):

| Item | Price | Notes |
|---|---|---|
| Midnight Blue paint | 2,500 Cash | |
| Getaway Green paint | 6,000 Cash | |
| Mint Trail | 1,500 Cash | |
| Sunset Trail | 4,000 Cash | |
| Santa Hat | 25 Candy Canes | until Jan 4 |
| Candy Stripe paint | 40 Candy Canes | until Jan 4 |
| Snow Globe trophy | 60 Candy Canes | until Jan 4 |
| Bag levels 1-3 | 2,000 / 5,000 / 12,000 Cash | |

No paid randomness, no Robux-to-Cash, no paid skips or hints: unit tests assert the config keeps these rules. Policy facts are as of October 2026; recheck the Creator Hub before shipping.

## Tests

- **L1 (Lune):** `lune run tests/run_unit.luau`. The data specs are `DataSchema` (defaults, the 16 KB budget, JSON round trip, migration harness, repair, keys, calendar), `DataProgress` (medals, best-run order, Cash maths, first clear, tainted and Relaxed runs, the first-session flow and the Big Score gate), `DataDaily` (streak and grace, rotation, advent, catch-up, board haul and its tie-breaks) and `DataStore` (catalog, monetization rules, buy, equip, bag, shelf, prices, product prompt checks).
- **Place check:** `tests/place_check.luau` checks that the library modules sit at their install paths and that the place has exactly one `ProcessReceipt`.
- **L3 (Open Cloud Luau Execution):** `tests/engine_smoke.luau` section 6 boots `DataService` in the real engine and checks that it uses `_TEST_` keys, comes online and creates its remotes. It also runs the library's `PlayerData.prepare` (new, newer, corrupt and old documents). Only when `game.GameId` is the test universe does it do one real `UpdateAsync` and uncached `GetAsync` on a throwaway `_TEST_smoke_<guid>` key, then `RemoveAsync`. No player profile is touched.

## Owner actions

1. **Studio:** Game Settings > Security > **Enable Studio Access to API Services** in the test experience (it must be published). Without it, Studio play is offline (nothing saves; this is safe).
2. **Open Cloud key (D5):** add DataStore scopes for the test experience: `universe-datastores.objects:read` and `universe-datastores.objects:list` to read `_TEST_` profiles and golden recordings, and the create/update/delete object scopes if Claude should write or clean `_TEST_` keys. Check the exact names in the Creator Hub. The Luau Execution smoke test itself needs no extra scope; its DataStore calls run as the experience.
3. **Developer products:** create the six products above, with their names, icons and prices, then paste the ids into `Config.Data.Products`. Compare the dashboard against the table: no dashboard product without a grant, and no prompted product missing from the dashboard.
4. **Run L3:** `ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 --place 70772627070328` (it publishes a Saved version). Expect 20 old checks plus the new data checks.
5. **Play/Stop/Play in Studio:** change a setting through `Data.SetSetting`, Stop, then Play: it should persist. Try `TestProfileKey = "a"` (a fresh profile) and `SimulateLoadFailure = true` (you are kicked and nothing is saved).
6. **Decide:** the level numbers (haul targets, `maxHaul`, first-clear Cash, Diamond `devClones`) and the Cash prices are placeholders. The plan lists the "sleigh van paint" both in the Robux bundle and in the Candy-Cane track; the code keeps Sleigh Red in the bundle and makes Candy Stripe the Candy-Cane paint.
7. **The live experience id** must never be added to `TEST_UNIVERSE_IDS`.

## Not built yet

- Ghost keys (written by the heist server on `newBest`).
- The daily board (`Leaderboard`, Dec 11).
- Rewarded video.
- Clone emotes and rewind styles (Jan).
- Trophy stands.
- The free Gift-Wrap style (use `grantCosmetic` after adding it to the catalog).
- The store and settings UI.
- Wiring the awards into v0.1 (unchanged for the fun gate). The sim path (`GAME_MODE = "sim"`) calls `awardHeistResult` and `awardDailyVault` from `Heist/HeistService` since 2026-11-12 (engine smoke checks both).
