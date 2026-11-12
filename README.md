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

## Clone phone bench (spike S1)

A separate small place that measures how many avatar clones a real phone can draw, and which clone look (MASTERPLAN §6.5) to ship. It uses the same "Heist Night" Lighting as the game. Code: `src/bench/` (tuning in `src/bench/shared/BenchConfig.luau`), project: `bench.project.json`.

### Build and run
```bash
rojo build bench.project.json -o build/CloneBench.rbxlx
lune run tests/place_check.luau build/CloneBench.rbxlx   # optional: checks layout + Lighting
```
1. Open `build/CloneBench.rbxlx` in Studio and press **Play** once to check it works.
2. **File → Publish to Roblox As… → a new, private experience** (for example "Clone Bench"). Do not publish over the game's test place.
3. On each phone, sign in as the owner and open that experience from the Roblox app (Creations / the experience page). Plug the phone in and close other apps.

### On the phone
- The panel (top left) shows N, the look, FPS average, **1% low** and worst frame over a 10 s window (after a 2 s warm-up), draw calls (and the extra draw calls vs N=0), triangles, instance counts, memory and render times.
- Buttons (top right): **N** cycles 0/4/8/12/16 clones, **LOOK** cycles A/B/C, **CAM** fixed/free (keep FIXED so phones compare), **AUTO RUN**, **RESULTS**.
- Looks: **A** translucent rig (Transparency 0.45) + one Highlight per owner group (fill 0.85); **B** opaque owner hue + outline-only Highlight; **C** hologram mannequin (rigid parts, neon trim, your hair/hat). Clones come in groups of 4 with the 4 owner hues (one Highlight per group, like 4 players), are copies of **your own avatar** (stripped: no textures, face, layered clothing; max 2 hair/hat accessories) and walk rings, moved by the client.
- If the readout says **FALLBACK mannequin**, your avatar did not load; the A/B numbers are then not valid. Rejoin.

### What to report back
Press **AUTO RUN** (about 3 minutes: a baseline with 0 clones, then A, B and C at 4/8/12/16), then **RESULTS**, and send a screenshot of the box (or long-press → Select All → Copy). For each phone also write:
- phone model, RAM, Android/iOS version, and the graphics quality (Automatic unless you also test manual 1-3; it is printed in the header);
- anything that looked wrong (clones popping, flicker, sorting, outlines missing).

Pass bar (MASTERPLAN §8.11 S1): at **N=12**, ≥ 30 fps (≤ 33 ms) on a low Android and ≥ 60 fps (≤ 16.6 ms) on a mid phone, judged by the **1% low** as well as the average; clones ≤ 120 draw calls (the `+dc` column). If A and B miss it, C (mannequin) is used beyond 15 studs or everywhere, and the cap stays 12.

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
| `default.project.json` | Rojo tree, plus the "Heist Night" Lighting recipe (Lighting is set only here) |
| `src/shared/Config.luau` | All tuning numbers |
| `src/server/init.server.luau` | Loop coordinator: start/end loop, rewind votes, catching, banking |
| `src/server/Echoes.luau` | Recording (15 Hz) and replaying echoes |
| `src/server/Actors.luau` | Registry of players and echoes; mechanisms only look at actors |
| `src/server/Mechanisms.luau` | Plates, vault door and lasers |
| `src/server/Loot.luau` | Gold and diamond: grab, carry, drop, bank |
| `src/server/Guard.luau` | Patrolling guard with a vision cone |
| `src/server/LevelBuilder.luau` | Builds the greybox bank from code |
| `src/client/init.client.luau` | HUD, rewind button, messages |
| `src/bench/` | Clone phone bench (separate place, `bench.project.json`) |
| `tools/` | Trend radars (Steam and Roblox) and Roblox search |
| `docs/` | Game bible, viral playbook, concept docs |
