# PROJECT_STATE

_Last updated: 2026-11-12_

## Done (v0.1 prototype)
- Rojo project, greybox bank level built from code (street, van, lobby, vault door, blue/red plates, laser grid, gold table, diamond pedestal).
- Loop system: 60 s loops, rewind when all players vote (R / button), banked loot persists, heist complete at $1,000 then reset.
- Echo recording (15 Hz position + yaw, grab/vanish events) and replay (ghost copy of the player's avatar, walk animation, holds final pose).
- Echo cap 4 per player (newest run replaces the last slot), 16 total.
- Plates/door/lasers react to players AND echoes. Guard patrols, catches players (sent home) and echoes (busted).
- HUD: loop and timer, loot progress, echo count, rewind button, objective list, big messages, rewind screen effect.
- LihFolk checker: 0 findings. Independent code review done: 8 bugs fixed (loot lost when an echo or player left or fell off the map, which locked the loop; guard reset per loop so echo replays stay in sync; partition wall so the guard can't see plate A; death records a vanish event; votes recounted when a player leaves; template leak).

## Done (W1, before the fun gate)
- `src/shared/Rec/` (pure Luau, not wired into v0.1 yet): `Codec` (versioned buffer v1: 20 Hz, 1/16-stud i16 keyframes + i8 deltas + idle repeats, u8 yaw, flags byte, 5-byte events with centisecond times; a 45 s run is ~2.5 KB), `Sampler` (tick-indexed recording with cuts for server teleports; Catmull-Rom playback, shortest-arc yaw, event cursor), `LoopClock` (server-time anchor/rate, fast-forward, squeeze, fixed-step ticks, lag-fairness rewind), `Validator` (leaky-bucket speed, teleport, rise, no-go/door segments, NaN/bounds, impossible events; clamp + taint). Tuning in `Config.Rec`.

## Plan (2026-11-12)
- Final master plan: `docs/MASTERPLAN.md` (the draft is deleted; research is in `docs/research/`). It applies three independent critiques (Appendix A).
- Key calls: a fun gate on v0.1 by Mon Nov 16 before any rewrite. W1 spikes S1-S6 are decided by Wed Nov 18 (S5, Open Cloud smoke, has already passed). Launch is Thu Dec 3 (gate Nov 30, fallback Dec 10) as the Christmas edition with 6 levels: L1-L4 Corner Shop, L5 Clone Party with 8 slots, L6 Big Score: Bank. Expedited Kids & Select review is submitted at launch. A public server is a garage lobby, with one heist instance per party. Levels are data built from an owner-imported `assets/Kit.rbxm`.
- Waiting on the owner: decisions D1-D10 in MASTERPLAN §11.2. D4 (time budget) and D5 (extra Open Cloud key scopes) are due Fri Nov 13; D1 (name) and D3 (scope) are due Mon Nov 16.

## Testing
- Local: `lune run tests/compile_check.luau`, `rojo build -o build/EchoHeist.rbxlx`, `lune run tests/place_check.luau` (all pass).
- Lint: `stylua --check src tests`, `selene src tests`, `selene --config src/shared/Sim/selene.toml src/shared/Sim src/shared/Rec src/shared/Levels`, `lune run tests/pure_check.luau` (all clean; README "Lint (L0)" has the Selene std workaround for TLS-intercepting proxies).
- L1 unit specs (Lune): `lune run tests/run_unit.luau` runs every `tests/unit/*.spec.luau` (96 pass, 2026-11-12, incl. 37 data specs).
- L2 sim specs (Lune, headless HeistSim): `lune run tests/run_sim.luau` runs every `tests/sim/*.spec.luau` (49 pass: determinism, 3x fast-forward equivalence, solvability of L1-L4, naive kid, latency injection 50-250 ms, divergence, 500-loop soak, lifecycle). L1 now 134 pass (incl. SimCore, SimLevelSpec, SimMechanisms, SimGuards). Both run in CI; place_check also resolves every relative require of Sim/Rec/Levels in the built place.
- Real Roblox engine: `ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 --place 70772627070328` publishes a Saved version and runs tests/engine_smoke.luau via Open Cloud Luau Execution. 2026-11-12: version 7, 20/20 pass (level boot, loop start, plates/door, lasers, loot grab/bank rules, guard vision).
- Publishing fails with HTTP 409 while Collaborative Editing is on or Studio holds the place: turn it off and close Studio.
- Still needs a human playtest in Studio: feel, echo smoothness, animations, 2-player flow.

## W1 progress (Nov 12)
- Spike S6 PASSED: "Heist Night" Lighting recipe lives in default.project.json (LightingStyle and PrioritizeLightingQuality are written by Rojo 7.7.1); LevelBuilder no longer sets Lighting; place_check asserts it.
- Spike S1 READY: clone phone bench (bench.project.json, src/bench). Waiting for the owner's phone results (README "Clone phone bench").
- shared/Rec (Codec, Sampler, LoopClock, Validator) with 59 Lune unit tests (`lune run tests/run_unit.luau`). Not wired into the v0.1 server yet (the fun gate runs v0.1).
- CI (GitHub Actions): compile check, StyLua check, Selene (two configs) + purity grep, LihFolk checker, rojo build (game, bench, S3/S4 spikes), place check on every place, unit tests on every push.
- Spike S3 READY: video capture place (spikes/capture.project.json, src/spikes/capture). Waiting for the owner's phone + PC results (README "Spike S3: video capture").
- Spike S4 READY: stem alignment place (spikes/stems.project.json, src/spikes/stems), Play(atTime) vs fallback with a drift meter; bundled footsteps loop until two Creator Store ids are pasted into StemsConfig. Waiting for owner results (README "Spike S4: stems").
- L0 lint: selene.toml (std roblox), second config src/shared/Sim/selene.toml + sim.yml (no task/os/math.random/clocks/DataModel) over Sim/ and Rec/, tests/pure_check.luau, stylua.toml (tabs, 120). Whole src/tests formatted once with StyLua 2.6.0. All clean.
- Name checked (knock-out): no title, app or trademark "Heist Yourself" found. Concept doc originality claim corrected.
- Art pipeline: bpy 5.3 + turntable/gate pipeline (`python3 tools/blender/build_asset.py --all`), bank kit v0 (6 assets, 16-17/18 self-review), docs/STYLE_BIBLE.md v0, docs/art/KIT_IMPORT.md. Spike S2 waits on the owner's Studio import (assets/Kit.rbxm); then paste kit.project.snippet.json into default.project.json and run tests/kit_check.luau.
- Spikes S3 (video capture) and S4 (stems) built as spike places; waiting on owner device runs. Selene (main + pure Sim std), StyLua and pure_check in CI.
- Open: confirm Alarm Red #FF3838 (plan colour was too close to Clone Magenta); loot always on dark display surfaces (gold vanishes on warm marble).
- Remaining W1 for Claude: bpy + turntable pipeline, mesh pipeline (S2).
- Owner: key scopes asset:write + DataStore (Nov 13), handles, ID/2SV, fun gate Mon Nov 16, bench results.

- Data layer installed (docs/DATA.md), not wired into gameplay yet: lihfolk-systems PlayerData (session lease, fenced saves, autosave, BindToClose), Policy, Currency (Cash, Stars mirror, CandyCanes), Receipts (the only ProcessReceipt), Shop (Robux prompts) as-is in `src/server/Data/` and `src/lihfolk/` (= ReplicatedStorage/LihFolk). `DataService` = server API for the heist server (`awardHeistResult`, `awardDailyVault`, `grantTrophy`, Cash earn/spend...) + validated client remotes (`Data.*`). Pure rules in `src/shared/Data/` (Schema v1, Progress medals/stars/unlocks/Cash, DailyVault advent + streak, Store, Keys `_TEST_` isolation, Calendar). Studio without API access runs "offline" (nobody kicked, nothing saved). Engine smoke section 6 added (data boot + `_TEST_` DataStore round trip): not run yet. Owner: Studio API access, Open Cloud DataStore scopes, create the 6 dev products and paste ids (DATA.md "Owner actions").

- Sim core (`src/shared/Sim/`, pure, NOT wired into v0.1): HeistSim (20 Hz fixed tick, run lifecycle, END RUN lock, timeout, squeeze, fast-forward, caps locked at heist start, orphans, Dawn, Alarm Run, completion + medal inputs in `Progress.HeistResult` shape), LevelSpec (format + validator incl. reachability), Mechanisms, Guards (patrol(t), 3-stage cone, LOS, hides, huh?, chase A*), Interact, Divergence (Stuck/Bonk), Loot, Alarm, Deck (Redo/Redo from/Delete/Delete busted/Undo), Scoring, EventLog (FNV hash), Rng. §8.10 lag rewind for lasers, doors and Gus. Levels L1-L4 in `src/shared/Levels/` with PLACEHOLDER scripted solutions (tests/sim/Solutions.luau) until the owner records `solution.bin`. Codec END gained `Zapped = 6` (append-only). See src/shared/Sim/README.md.

## Next (see MASTERPLAN §10.2 for the full W1 list)
1. Fun gate: owner plays v0.1 in Studio with 2-3 people by Mon Nov 16 (`rojo build -o EchoHeist.rbxlx`), solo and 2-client, once with 30 s loops via Config.
2. Feel pass: echo smoothness (consider client-side replay), guard readability (vision cone visual), sounds.
3. Second level and level select; time medals (fewest echoes / fastest) = replay value and a TikTok format.
4. Data: call `DataService.awardHeistResult` / `awardDailyVault` from the heist server; store + settings UI; ghost keys on `newBest`; daily board (Leaderboard) Dec 11.
5. Christmas event level: "Steal Back Christmas".
6. Thumbnail and icon, then soft launch.

## Known risks
- The guard probably slides without a walk animation (rigs have no Animate script). Cosmetic.
- The vault door becomes solid as soon as it starts closing and can push someone standing in the doorway.
- `Loot.park` errors if a loot part is destroyed in an unhandled way.
- Echo movement is set on the server every Heartbeat; replication can look choppy. Fix if needed by replaying on clients.
- The walk animation id is the default R15 walk; verify it loads.

## Sim game path behind a flag (2026-11-12)
- `Config.GAME_MODE = "v01"` (default, fun gate) | `"sim"`. Both entry scripts pick the path; v0.1 code untouched. README "Try the new sim path".
- Server `src/server/Heist/`: HeistService (garage lobby, crews via PartyId + Join friend, up to `Config.Heist.MAX_INSTANCES` instances 3,000 studs apart, LihFolk Net remotes `Heist.*`, FTUE autostart of L1, `FtueStep` signal, DataService medal resolver + `awardHeistResult` with friends/heistId), HeistInstance (HeistSim per party, input sampling + latency, 20 Hz via `HeistSim.update`, attributes for state, one reliable `Heist.Msg` push for Run/Ev/Clock/RunEnd/Deck/Over, recordings once per client as Codec buffers), LevelBuilder (greybox from LevelSpec, STYLE_BIBLE palette), Lobby, Avatars (stripped templates).
- Client `src/client/Heist/`: EchoView (pooled rigs, hue + glyph, age ramp, tape print, outcomes), GusView (patrol(t) + pose attributes, 12-ray cone, ?/!/huh?), WorldView (doors/lasers/plates/loot locally), RewindDirector (1.8/1.0/0.8 s), Hud (HUD v1, Clone Deck, results, garage), mobile-first.
- Engine smoke section 7 (2026-11-12, place v13): 57/57 pass (31 existing + 26 sim: L1 built at an offset, fake member runs the full FTUE heist to completion, views posed in-engine, L4 Gus, template strip).
- Not yet human-tested in Studio. Gaps: StreamingEnabled off; placeholder sounds; no Crew Line-up/Heist Reel, ping wheel, Quick Crew, planning camera, Comfort settings UI; Input Action System not used (ContextActionService).

## Integration check after the content / art / analytics / marketing tracks (2026-11-12)
- All green: unit 208, sim 168, compile 107 files, pure_check 41, Selene (both configs), StyLua, LihFolk 155 files 0 findings, 4 places build + place_check, kit_check skips (S2 pending), `build_asset.py --all` ALL GATES PASS (50 FBX, 92 MeshParts), `kit_docs.py` idempotent, `lune run docs/marketing/clips_check.luau` 62 checks hold (now a CI step; `docs/marketing/` must be committed with ci.yml).
- Fixed across tracks: `tests/kit_check.luau` finds kit pieces through a MeshPart name map + `model` check (the old `FindFirstChild(name, true)` failed 47 pieces named like their Model); `Data/DailyVault.vaultFor` is anchored at launch day, so rotation slot n = daily design n and `Orn_VaultNN` is design NN's ornament (same design per day as before; asserts in DataDaily + sim Daily specs); `eh_kit` `clip` sorts its BMesh input, so `VaultDoor` no longer re-exports on every `--all`.
- Open, cross-track: SwarmSeen by minute 10 (KPI `swarmSeen10`, Nov 30 gate, T1 thumbnail gate) conflicts with the Pacing model (swarm at minute 16-22 with the plan's L1-L4 estimate): owner decision. Level data vs kit (content track): L1 counter box 6 wide, L5 till outside its counter box, L6 open vault door over plate C / WestStack, no cover piece for L6 TellerDesk. Wiring agent: `Interact.FAIL.Locked` + loot `opensAt` (L5 till) and `lastRun.alarm.hint` need view text; analytics call sites (docs/ANALYTICS.md); `awardDailyVault` not called yet. Data owner (optional): board tie-break on the sim's daily `timeMs`; `created` in the snapshot and `Shop.ProductPrompted` for analytics. Owner: approve or drop the `Analytics.Ready` / `Analytics.Ui` client remotes (CLAUDE.md "clients only send RequestRewind").
