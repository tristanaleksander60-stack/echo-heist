# PROJECT_STATE

_Last updated: 2026-11-11_

## Done (v0.1 prototype)
- Rojo project, greybox bank level built from code (street, van, lobby, vault door, blue/red plates, laser grid, gold table, diamond pedestal).
- Loop system: 60 s loops, rewind when all players vote (R / button), banked loot persists, heist complete at $1,000 then reset.
- Echo recording (15 Hz position + yaw, grab/vanish events) and replay (ghost copy of the player's avatar, walk animation, holds final pose).
- Echo cap 4 per player (newest run replaces the last slot), 16 total.
- Plates/door/lasers react to players AND echoes. Guard patrols, catches players (sent home) and echoes (busted).
- HUD: loop and timer, loot progress, echo count, rewind button, objective list, big messages, rewind screen effect.
- LihFolk checker: 0 findings. Independent code review done: 8 bugs fixed (loot lost when an echo or player left or fell off the map, which locked the loop; guard reset per loop so echo replays stay in sync; partition wall so the guard can't see plate A; death records a vanish event; votes recounted when a player leaves; template leak).

## Testing
- Local: `lune run tests/compile_check.luau`, `rojo build -o build/EchoHeist.rbxlx`, `lune run tests/place_check.luau` (all pass).
- Real Roblox engine: `ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 --place 70772627070328` publishes a Saved version and runs tests/engine_smoke.luau via Open Cloud Luau Execution. 2026-11-12: version 7, 20/20 pass (level boot, loop start, plates/door, lasers, loot grab/bank rules, guard vision).
- Publishing fails with HTTP 409 while Collaborative Editing is on or Studio holds the place: turn it off and close Studio.
- Still needs a human playtest in Studio: feel, echo smoothness, animations, 2-player flow.

## Next
1. Studio test and fix (user runs `rojo build`, or `rojo serve` + Connect).
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
