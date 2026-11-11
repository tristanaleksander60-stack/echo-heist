# Echo Heist (working title)

> Rob the vault with yourself. Every heist is a 60-second loop. On each new run, your past selves replay exactly what you did, so you become your own crew. Solo or with friends.

Status: **prototype v0.1**, one greybox bank level. No art pass and no saving yet.

## Play the prototype in Roblox Studio

### 1. Install the tools (once)
Install [Rokit](https://github.com/rojo-rbx/rokit), then run this in the project folder:
```bash
rokit add rojo-rbx/rojo
```
Then install the **Rojo plugin** in Studio (Plugins → Manage Plugins, search "Rojo", or run `rojo plugin install`).

### 2a. Build a place file (simplest)
```bash
rojo build -o EchoHeist.rbxlx
```
Open `EchoHeist.rbxlx` in Studio and press **Play**.

### 2b. Live sync while we develop
```bash
rojo serve
```
In Studio, open an empty Baseplate, then Plugins → Rojo → **Connect**. Code changes appear in Studio straight away.

### 3. Test multiplayer
In Studio, go to the **Test** tab → Clients and Servers → choose **2 players** → **Start**.

## How to play
1. Stand on the **blue plate** in the bank lobby. The vault door opens while someone stands on it.
2. Press **R** (or the REWIND button). The loop restarts, and your **echo** walks to the plate and holds it for you.
3. Go into the vault. The **red plate** turns off the lasers. Rewind again.
4. Now your echoes hold both plates. Grab gold or the diamond and carry it to the **van**.
5. Avoid the guard's flashlight. Getting caught sends you home, and a caught echo disappears.
6. Bank $1,000 to finish the heist.

Banked loot survives loops. Each player can have up to 4 echoes; when you rewind at the cap, your newest run replaces your last echo.

## Code layout
| File | Role |
|---|---|
| `src/shared/Config.luau` | All tuning numbers |
| `src/server/init.server.luau` | Loop coordinator: start/end loop, rewind votes, catching, banking |
| `src/server/Echoes.luau` | Recording (15 Hz) and replaying echoes |
| `src/server/Actors.luau` | Registry of players and echoes; mechanisms only look at actors |
| `src/server/Mechanisms.luau` | Plates, vault door and lasers |
| `src/server/Loot.luau` | Gold and diamond: grab, carry, drop, bank |
| `src/server/Guard.luau` | Patrolling guard with a vision cone |
| `src/server/LevelBuilder.luau` | Builds the greybox bank from code |
| `src/client/init.client.luau` | HUD, rewind button, messages |
| `tools/` | Trend radars (Steam and Roblox) and Roblox search |
| `docs/` | Game bible, viral playbook, concept docs |
