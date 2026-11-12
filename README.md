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

## Spike S3: video capture

A small separate place that checks whether `CaptureService` can record, save and share a ~12 s clip on the owner's phone and PC (MASTERPLAN §8.11 S3, used by SAVE CLIP in §9.3). Code: `src/spikes/capture/` (tuning in `src/spikes/capture/shared/CaptureConfig.luau`), project: `spikes/capture.project.json`. Same "Heist Night" Lighting as the game.

### Build and run
```bash
rojo build spikes/capture.project.json -o build/CaptureSpike.rbxlx
lune run tests/place_check.luau build/CaptureSpike.rbxlx   # optional layout + Lighting check
```
1. Open `build/CaptureSpike.rbxlx` in Studio and press **Play** once (capture is not expected to work in Studio; the panel should say why, not crash).
2. **File → Publish to Roblox As… → a new, private experience** (for example "Capture Spike"). Not over the game's test place.
3. Open it from the Roblox app on the phone and from the Roblox app on the PC, signed in as the owner.

### On the device
- Four walking dummy clones, a spinning vault ring and a 3D caption "◀ ME, 20 SEC AGO" give the clip motion and a burn-in test. The camera is fixed.
- The panel (top left) shows the platform, `CanCaptureVideo()` (an undocumented probe: `n/a` is fine), the state, FPS and an event log. Every CaptureService call is in `pcall`, so an unsupported device shows the error instead of breaking.
- Buttons: **RECORD** (`StartVideoCaptureAsync`, auto-stops after LEN with `StopVideoCapture`), **STOP**, **SAVE** (`PromptSaveCapturesToGallery`), **SHARE** (`PromptShareCapture` with launch data `v1|reel|spike`), **SHOT** (fallback screenshot with `TakeScreenshotCaptureAsync`, UI hidden), **LEN** 12/30/35 s (35 checks the 30 s engine limit), **CLEAN** (hide the panel while recording), **CHECKLIST**, **RESULTS** (copyable log).
- Nothing prompts on its own: Save and Share only run when pressed (§9.3).

### What to report back
Press **CHECKLIST** on the device; it lists the items. In short, per device (model, OS, Roblox app version):
1. `CanCaptureVideo` value; the RECORD start result (`Success`, `NoDeviceSupport`, ...); any OS permission prompt; start latency.
2. Clip result (`Success` / `TimeLimitReached`), clip length vs 12 s, FPS while recording vs idle.
3. SAVE: did a prompt appear, what the callback said, and where the clip shows up (Roblox Captures in the main menu, phone gallery).
4. SHARE: share sheet (phone) or download (PC)? Which apps? Did it carry the video and an invite link?
5. The clip itself: smooth, dummies walking, ring spinning, 3D caption visible? Is the bottom screen caption / the panel in the clip, and is the panel gone with CLEAN on?
6. LEN 35 stops by itself at 30 s? SHOT + SAVE/SHARE works?
7. Optional: a friend who joins through your shared invite sees `join launch data: v1|reel|spike` in their panel.

Then **RESULTS** → long-press → Select All → Copy (or a screenshot). Do not rotate the phone while recording (that ends the clip with `ScreenSizeChanged`).

Pass bar (S3): records and shares a 12 s reel. If not: SAVE CLIP becomes screenshot + a crop-safe reel for screen recording.

## Spike S4: stems

A small separate place that plays two stems on the new Audio API and measures whether they stay aligned over 8 loops (MASTERPLAN §8.11 S4, "Crew Layers" in §7.2). Code: `src/spikes/stems/` (asset ids and tuning in `src/spikes/stems/shared/StemsConfig.luau`), project: `spikes/stems.project.json`.

### Build and run
```bash
rojo build spikes/stems.project.json -o build/StemsSpike.rbxlx
lune run tests/place_check.luau build/StemsSpike.rbxlx   # optional
```
Play it in Studio first (audio timing in Studio is already a useful reading), then publish it as a new private experience and open it on the phone and the PC. Use headphones.

### How it works
- Graph: `AudioPlayer` → `Wire` → `AudioFader` → `Wire` → `AudioDeviceOutput`, one chain per stem, all on the client (game music is client-side too).
- A loop is 4 bars at 128 BPM (7.5 s), 8 loops per run. Every frame the spike reads both players' `TimePosition` and logs per loop the mean, range and worst drift (A − B, wrapped by the asset length), plus how far A is from where `GetMixerTime()` says it should be.
- Modes (**MODE** button):
  - **SCHEDULED**: each loop restarts on "GO" with `AudioPlayer:Play(atTime)` / `Stop(atTime)` on `SoundService:GetMixerTime()` (the plan's primary method).
  - **CONTINUOUS**: one `Play(atTime)` start, 8 loops with no restart (does drift build up?).
  - **FALLBACK**: each loop both start with plain `Play()` in the same frame, stem B at volume 0 on GO and faded in over one bar from loop 2 (§7.2 fallback).
- **OFFSET** 0/10/20/40 ms delays stem B on purpose: it checks the meter (it should read the offset) and lets you hear what drift sounds like.
- **RUN ALL** runs SCHEDULED, CONTINUOUS and FALLBACK at offset 0 (about 3 minutes). Verdict per mode: PASS if the worst drift is ≤ 20 ms (feel.md resync threshold). Results also print to Output with the prefix `[S4]`.

### Music
There is no uploaded music yet, so both stems default to the engine-bundled footsteps loop (`rbxasset://sounds/action_footsteps_plastic.mp3`). The same sound on both players makes misalignment easy to hear. To test real music, open `StemsConfig.luau` and follow the steps at the top: pick two Roblox-licensed Creator Store tracks (ideally two stems or two mixes of the same track), paste them as `STEM_A = "rbxassetid://<id>"` and `STEM_B = "rbxassetid://<id>"`, set `TRACK_BPM`, rebuild and republish.

### What to report back
Press **HELP** on the device for the full list. Per device (model, OS, Roblox app version):
1. **RUN ALL**, then **RESULTS** → copy or screenshot (summaries plus every loop).
2. Per mode: did it sound like one sound in all 8 loops, or did it flam/echo somewhere? Clicks at loop starts?
3. OFFSET 20 + SCHEDULED: does the meter read about +20 ms, and can you hear it?
4. FALLBACK: is the fade-in of stem B smooth?
5. Any `ERROR` lines or stems that never got ready; with Creator Store ids, which ids and whether they sounded in time.

Pass bar (S4): no audible drift over 8 loops with `Play(atTime)`. If not: the start-together-at-volume-0 fallback (§7.2).

## Lint (L0)

MASTERPLAN §8.9 L0 runs StyLua and two Selene configs (CI does the same):
```bash
cargo install selene --locked
cargo install stylua --locked --features luau     # the luau feature is needed for type annotations
stylua --check src tests                          # format: stylua src tests
selene src tests                                  # selene.toml, std "roblox"
selene --config src/shared/Sim/selene.toml src/shared/Sim src/shared/Rec   # pure layers, restricted std
lune run tests/pure_check.luau                    # Lune twin of the restricted std
```
- `std = "roblox"` is generated by Selene from the Roblox API dump on first use and cached in `~/.cache/selene/roblox.yml` (refreshed every 6 h; a failed refresh falls back to the cache).
- Behind a TLS-intercepting proxy the download fails with `invalid peer certificate: UnknownIssuer` (Selene's HTTP client only trusts its built-in roots). Workaround used here: build Selene once with native certificates and seed the cache: copy the `selene-0.31.0` crate source, change the `ureq` features in its `Cargo.toml` to `["json", "native-certs"]`, `cargo build --release`, then run `SSL_CERT_FILE=<proxy CA bundle> target/release/selene update-roblox-std`. The normal `selene` then uses the cached std. A `roblox.yml` in the repo root (`selene generate-roblox-std`) also works and is git-ignored.
- `src/shared/Sim/sim.yml` is the Roblox std minus `task`, `wait`/`delay`/`spawn`, `os`, `tick`/`time`, `DateTime.now`, `math.random`, `game`/`workspace`/`script`, `Instance.new`, `shared`/`_G` and `getfenv`/`setfenv` (§8.4). It also covers `src/shared/Rec/`, which is today's pure layer. Rojo skips the config files (`globIgnorePaths` in `default.project.json`).

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
| `src/spikes/capture/`, `src/spikes/stems/` | Spikes S3 (video capture) and S4 (stems), separate places in `spikes/*.project.json` |
| `src/shared/Sim/` | Planned pure sim (§8.4); holds the second Selene config for the pure layers |
| `selene.toml`, `stylua.toml` | L0 lint configs (see "Lint (L0)") |
| `tools/` | Trend radars (Steam and Roblox) and Roblox search |
| `docs/` | Game bible, viral playbook, concept docs |
