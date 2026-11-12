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
- L1 unit specs (Lune): `lune run tests/run_unit.luau` runs every `tests/unit/*.spec.luau` (59 pass, 2026-11-12).
- Real Roblox engine: `ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 --place 70772627070328` publishes a Saved version and runs tests/engine_smoke.luau via Open Cloud Luau Execution. 2026-11-12: version 7, 20/20 pass (level boot, loop start, plates/door, lasers, loot grab/bank rules, guard vision).
- Publishing fails with HTTP 409 while Collaborative Editing is on or Studio holds the place: turn it off and close Studio.
- Still needs a human playtest in Studio: feel, echo smoothness, animations, 2-player flow.

## W1 progress (Nov 12)
- Spike S6 PASSED: "Heist Night" Lighting recipe lives in default.project.json (LightingStyle and PrioritizeLightingQuality are written by Rojo 7.7.1); LevelBuilder no longer sets Lighting; place_check asserts it.
- Spike S1 READY: clone phone bench (bench.project.json, src/bench). Waiting for the owner's phone results (README "Clone phone bench").
- shared/Rec (Codec, Sampler, LoopClock, Validator) with 59 Lune unit tests (`lune run tests/run_unit.luau`). Not wired into the v0.1 server yet (the fun gate runs v0.1).
- CI (GitHub Actions): compile check, LihFolk checker, rojo build (game + bench), place check, unit tests on every push.
- Name checked (knock-out): no title, app or trademark "Heist Yourself" found. Concept doc originality claim corrected.
- Remaining W1 for Claude: second selene config, bpy + turntable pipeline, stem test place (S4), mesh pipeline (S2), video capture (S3).
- Owner: key scopes asset:write + DataStore (Nov 13), handles, ID/2SV, fun gate Mon Nov 16, bench results.

## Next (see MASTERPLAN §10.2 for the full W1 list)
1. Fun gate: owner plays v0.1 in Studio with 2-3 people by Mon Nov 16 (`rojo build -o EchoHeist.rbxlx`), solo and 2-client, once with 30 s loops via Config.
2. Feel pass: echo smoothness (consider client-side replay), guard readability (vision cone visual), sounds.
3. Second level and level select; time medals (fewest echoes / fastest) = replay value and a TikTok format.
4. Data: save best medals and unlocks (lihfolk-systems PlayerData).
5. Christmas event level: "Steal Back Christmas".
6. Thumbnail and icon, then soft launch.

## Known risks
- The guard probably slides without a walk animation (rigs have no Animate script). Cosmetic.
- The vault door becomes solid as soon as it starts closing and can push someone standing in the doorway.
- `Loot.park` errors if a loot part is destroyed in an unhandled way.
- Echo movement is set on the server every Heartbeat; replication can look choppy. Fix if needed by replaying on clients.
- The walk animation id is the default R15 walk; verify it loads.
