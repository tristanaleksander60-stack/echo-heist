# PERF: performance budgets, measurements and the streaming decision

_Performance track, 2026-11-12. PLAN_STEAM_PLUS §4.7 / §12 / §8.1 R1, MASTERPLAN §3.3 / §6.8 / §8.6, roblox_quality §1.4 / §2.2 / §6.4._

**In one paragraph:** with 8 heist instances live, every phone used to receive about 5,000 instances and about 450k triangles of level art, while it only plays in one level. **StreamingEnabled is now ON.** A phone in a Big Score now holds about 1,550 replicated instances (69% fewer), and other crews' level builds no longer reach it. The per-tier budgets are in `Config.Perf` and the pure `Shared/Heist/Budget`, and the views enforce them. At tier 3 and up, the LightDirector switches to recipe C "Soft Toybox" by itself and switches back as the governor steps up. Measured in the engine, every hard-counted budget holds at every tier: lights, shadowed lights, floor glows, Highlights, snow, the worst particle moment and live instances. Two numbers were **estimates over the low-phone budget**: triangles (~210k against 150k) and draw calls (~275 against 250) at tiers 3-4, driven by the 16 avatar bodies. The §6.4 **clone LOD is now built** (tech polish track): from tier 3 a clone beyond 18 studs draws as the 216-triangle mannequin in its crew hue, which brings tier 3 to ~129k triangles and ~210 draws by estimate (tier 4 stays a little over: ~128k / 120k, ~206 / 200). Clients also **start at the tier their device suggests** (§4), every particle effect shares **one live budget**, and the `LightingStyle = Soft` at boot has a cause and a one-line fix (§4).

## 1. How this was measured

`tests/perf_engine.luau` runs in a real Roblox server through Open Cloud Luau Execution:

```bash
ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 \
  --place 70772627070328 --script tests/perf_engine.luau --timeout 300
```

The numbers below come from Saved place version 43, which also passes engine_smoke 115 ok, client_engine 43/0, clone_engine 73 ok and kit_engine 283 ok.

- **What it can do:** build the garage and 8 kit-dressed heist instances at once (Christmas layer on), count instances, parts, guis, lights, emitters and Highlights, read `Stats` memory, and build the client-side pieces on the server the way a client builds them. That covers EchoView with 12 clones of 4 real avatar templates, 16 Line-up figures, 2 Gus, the Backdrop and snow, WorldView's extras and the LightDirector.
- **What it cannot do:** run frames. Luau Execution servers do not simulate (`RunService:IsRunning()` is false). There are no frame times, no GPU memory and no real draw calls.
- **Estimates:**
  - Triangles: from `kit_manifest.json` per kit piece, primitives at fixed counts, and avatars at `Config.Perf.AVATAR_TRIS_EST` = 7k each (Luau cannot read an avatar's triangles).
  - Draw calls: distinct mesh / material batches, about 17 per avatar look (one avatar's clones instance together), plus one per enabled gui. Treat both as ±50%.
- **Memory:** server-side `Stats`, sampled with a lag. These are proxies for the CPU-side cost on a client, not phone figures.

## 2. Server: garage + 8 instances (measured)

| What | Instances | Parts (visible / meshes) | Tris (est.) | Lights (shadowed) | SurfaceGuis | Billboards |
|---|---|---|---|---|---|---|
| Garage (kit-dressed) | 569 | 232 (183 / 174) | ~50k | 14 (1) | 22 | 0 |
| L1 Back Room | 267 | 129 (102 / 87) | ~30k | 5 (1) | 8 | 0 |
| L2 Two Doors | 360 | 162 (127 / 109) | ~38k | 7 (1) | 13 | 0 |
| L5 Clone Party | 339 | 186 (156 / 123) | ~50k | 6 (1) | 6 | 0 |
| L3 Lights Out | 369 | 170 (137 / 105) | ~37k | 7 (1) | 13 | 0 |
| L4 Night Clerk | 381 | 173 (129 / 111) | ~39k | 7 (1) | 15 | 0 |
| **L6 Big Score** (heaviest) | **862** | 376 (279 / 226) | **~84k** | 16 (1) | 38 | 1 |

- The heaviest level has 862 instances, against a MASTERPLAN §6.8 budget of 6k (ceiling 10k). That passes with room to spare.
- Memory for 8 instances (L1, L2, L5, L3, L4 and 3 × L6) is **+15.5 MB** on the server. One Big Score instance is about **3.3 MB**, so 8 × L6 is about 27 MB.
- The kit templates live in ServerStorage (165 instances) and are never replicated.
- ReplicatedStorage holds 115 instances plus one stripped avatar template per player: 119-144 instances each, so about 1.1k with 8 players.

## 3. Streaming decision: ON

| One phone in a Big Score | Streaming OFF (before) | Streaming ON (now) |
|---|---|---|
| Replicated instances | **4,987** (Workspace 4,872 = garage 569 + 8 instances 4,302; ReplicatedStorage 115) | **1,546** (garage 569 + its own level 862 + ReplicatedStorage 115) |
| Level art held | ~448k tris (8 × L6 worst case: ~675k) | ~84k tris + the garage's ~50k |
| CPU-side level memory (server proxy) | ~15.5 MB (8 × L6: ~27 MB) | ~3.3 MB |
| Another crew starts a heist | its whole level build (300-900 instances) replicates to every phone, a burst against §8.6's 40 KB per-burst budget | nothing reaches you |

**Why it is on:** a 69% cut in replicated instances and the end of the cross-crew build bursts. The memory win alone is modest: about 12-24 MB on a 2 GB phone whose budget is about 700 MB. The bursts matter more, because 8 crews in one server would otherwise interrupt each other's runs on cheap 4G phones. The code was already prepared for it, and I checked that below.

**Settings** (the `Workspace` node in `default.project.json`; `tests/place_check.luau` asserts them on the game place):

- `StreamingEnabled true`, `StreamingMinRadius 128`, `StreamingTargetRadius 512`, `StreamOutBehavior Opportunistic`, `ModelStreamingBehavior Improved`.
- `StreamingIntegrityMode PauseOutsideLoadedArea` (the docs' recommendation). If a server move ever lands a character in an area that has not loaded, it pauses instead of falling.
- Instances are ≥ 2,989 studs apart and a level reaches ≤ 65 studs from its origin, so no other crew's level comes within the 512-stud target radius.

**What each level and the garage stream as:**

- **Each heist level:** `PersistentPerPlayer` (LevelBuilder), with its crew added through `AddPersistentPlayer` when the instance is created (HeistInstance). That happens before the deck / ready phase, well before the first run's pivot.
- **The garage** (`Lobby`) is now **`Persistent`**. Every player starts there, and the server teleports each player back after every heist from 3,000+ studs away, where Opportunistic streaming may have dropped it. Its 569 instances are the only always-on cost.

**Client code audit (parts arriving late):**

| Module | Under streaming |
|---|---|
| HeistClient | Waits up to 10 s for the instance's `Level` (PersistentPerPlayer, so it arrives whole for the crew) before WorldView, LightDirector and Backdrop bind it |
| WorldView | Binds through `DescendantAdded` as well as at bind |
| LightDirector | Binds through `DescendantAdded` |
| Backdrop | Built on the client from `ReplicatedStorage/BackdropKit`, which never streams. It dresses the level front through `DescendantAdded`. It and the level are both there before the run-start camera beat: the level was sent at instance creation, and the backdrop needs no replication |
| EchoView, GusView, Line-up rigs | Client-built from templates in ReplicatedStorage. Client-made instances are never streamed out. GusView and EchoView read only the instance folder's attributes (a Folder, which is not streamed) |
| LineupDirector raycasts, the Hints plate Beam | Use the Level, which is persistent for the crew |
| JobBoard | Now waits (bounded, `Config.Perf.GARAGE_WAIT_SECONDS`) for a garage that has not arrived when the first garage sync comes in |
| CameraDirector | Looks the garage up on every call |

**Still open on streaming (needs Studio or a phone):**

- A 2-client Play test.
- The run-start camera beat for a brand-new account (FTUE autostart: the time from instance creation to the end of the intro on 4G is not measured).
- The garage return.
- Whether the "Gameplay paused" notice ever shows.
- The v0.1 path (`GAME_MODE = "v01"`) has not been checked under streaming. The default path is `"sim"`.

## 4. Tier behaviour (Config.Perf, Shared/Heist/Budget)

**Start tier** (Heist/Telemetry, pure rules in `Budget.startTier` / `Budget.probeTier`, numbers in `Config.Perf.START`): a client picks its tier at boot from what a script can read: the device class (touch-only phone or tablet: tier 2; PC, console, VR: tier 1), the player's manual graphics level (`UserGameSettings.SavedQualityLevel` 1-3: at least tier 3, 4-6: at least tier 2, 8-10: tier 1; Automatic says nothing, then `RenderSettings.QualityLevel` if readable), and a small, old phone screen (short side under 340 px: one tier lower when the quality level says nothing). A 2.5 s frame probe (after 0.5 s of boot hitches) while the loading card / title beat is up lowers it once more if the card's median frame is slower than 30 fps (two tiers under 20 fps), never past tier 3. A low phone is therefore at recipe C before its first run.

The PerfSample governor then steps down when p95 > 36 ms for 20 s (then a 30 s cooldown). It steps back up after 60 good seconds, and each step up doubles the next wait. The start counts as step-downs already taken (`PerfSample.seed`), so a pessimistic start climbs back to tier 1 with the same hysteresis. The governor now runs whether or not the analytics remotes arrive.

| | Tier 1 quality (high phone / PC) | Tier 2 balanced (mid Android) | Tier 3 performance (low Android, 30 fps) | Tier 4 minimum |
|---|---|---|---|---|
| Lighting | recipe A (project file) | A | **recipe C "Soft Toybox"** (LightingStyle Soft, Brightness 1.6, cool ColorShift, Ambient (120,110,170) ≤ Outdoor (135,125,185), EnvDiffuse 0.2, Spec 0, EV 0.2, GlobalShadows off, Bloom 0.9/24/1.0, CC 0.15/0.12) | C + Bloom off |
| Level lights | all | street lamps off | street + accent off; every Range ≤ 24; no shadows | + room lamps off; pools off |
| Your halo light | on | on | off | off |
| Clone floor glows | 12 | 12 | **6** (yours first, then nearest; rechecked every 0.5 s) | 3 |
| Clone LOD (`Config.Perf.CLONE_LOD`) | textured | textured | **crew-hue mannequin beyond 18 studs, textured again inside 15** (same pill, glow, Highlight; never your newest clone in the L1 tutorial); Line-up past the front row too | as tier 3 |
| Clone pill distance | 40 | 40 | 28 | 20 |
| Trails | on | off | off | off |
| Others' clone Highlights | on | on | on | off (yours stay) |
| Bursts (ribbons, sparks, zap, coins, dust, laser sparks, gold rain 40) | ×1 | ×1 | ×0.5 | ×0.35 (min 2) |
| One live particle budget (`Heist/Particles`, `Budget.particleCap`): snow + sparkles report in, every burst asks | 360 touch / 900 | 360 / 900 | 150 / 375 | 100 / 250 |
| Snow alive | 240 | 240 | **60** | 40 |
| Backdrop | all | all | far ring off | + facade windows off |
| Rewind blur | on | off | off | off |

- Recipe C restores recipe A exactly as it was read (every property, LightingStyle included). Tests: unit `HeistBudget` (8 specs) and perf_engine section C (tier 3 → C, tier 4 → Bloom off, back to tier 1 → A).
- In the engine, a script's write to `Lighting.LightingStyle` is accepted without an error. The server read `LightingStyle = Soft` at boot even though the place file holds `Realistic`. **Cause (tech polish track):** Rojo writes only the properties a project lists, so the built Lighting has no `Technology`; the service then loads with its class default, `Voxel` (rbx-dom's default Lighting is Technology Voxel + LightingStyle Soft), and the engine still maps `Technology` onto the new pair when it loads a place (Voxel = Soft + off, ShadowMap = Soft + on, Future = Realistic + on). A Studio-saved place always carries `Technology`. **Fix:** `"Technology": "Future"` next to `LightingStyle` in the project's Lighting `$properties` (done for bench and the spikes; `default.project.json` is the World 2.0 track's, the integrator adds it). `place_check` fails a place whose Technology disagrees with the pair and warns while it is missing (`REQUIRE_TECHNOLOGY` makes that a failure); `perf_engine` asserts Realistic + PrioritizeLightingQuality on at boot. **Studio check left:** does switching to Soft at runtime (recipe C) change the look?
- **Line-up:** it draws 1 BillboardGui (the "◀ ME" label) and 4 Highlights (one per owner). It never draws together with the clones (`hideAll`). `Budget.lineupLabels` (1 at every tier) is the number LineupDirector (MOMENTS track) must keep to if it adds labels.
- **Gold rain:** it does not exist yet. MomentDirector should emit `Budget.burst(tier, Config.Perf.GOLD_RAIN)`.

## 5. The busiest view per tier (Big Score: 4 players, 12 clones, 2 guards), measured vs budget

| Budget (Config.Perf; §6.8 / §6.4) | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| Local lights in view (incl. your halo) | **10** / 10 | **9** / 9 | **8** / 8 | 3 / 6 |
| Shadowed lights | 1 / 2 | 1 / 2 | 0 / 0 | 0 / 0 |
| Floor glows | 12 / 12 | 12 / 12 | 6 / 6 | 3 / 3 |
| Highlights (4 clone groups + your rim) | 5 / 10 | 5 / 10 | 5 / 5 | 2 / 2 |
| Live particles: snow + worst moment (busted + coins + gold rain + dust + laser) | 240 + 118 = **358** / 360 | 358 / 360 | 60 + 59 = 119 / 150 | 40 + 42 = 82 / 100 |
| Live client instances (streaming on) | 4,252 / 25k | 4,252 | 4,252 | 4,252 |
| Triangles in view (est., whole L6 counted) | ~216k / 450k | ~216k / 300k | **~210k / 150k** ⚠ | **~209k / 120k** ⚠ |
| Draw calls (est.) | ~283 / 450 | ~283 / 350 | **~275 / 250** ⚠ | **~271 / 200** ⚠ |

**Breakdown:**

- **The triangles** are L6 at ~84k (the whole level counted, not the view), the backdrop at 13k (6k without the far ring), 16 avatar bodies at ~112k (estimate: 12 clones + 4 players at 7k) and 2 Gus at ~7k.
- **12 clones + your halo:** 1,891 instances. EchoView builds 24 BillboardGuis (pill + bubble; the 12 bubbles stay off until used) and 13 SurfaceGuis (12 glows + the ring), plus 4 owner Highlights + your rim, 24 burst emitters (no steady rate) and 12 trails. Memory is **+21 MB** with the 4 avatar templates, against MASTERPLAN §6.8's ≤ 40 MB for the clone system.
- **The rest of the view:**
  - Line-up (16 figures): 2,051 instances, 1 billboard, 4 Highlights.
  - Gus × 2: 87 instances, 2 billboards on, about 4k tris of kit mesh.
  - Backdrop: 128 instances, 1 snow emitter.
  - WorldView adds 24 instances to the level on the client.

**Over budget, by estimate only (before the LOD):** at tiers 3-4, triangles and draw calls exceeded budget, and the avatar bodies are most of the cost. **The clone LOD is built** (roblox_quality §6.4): from tier 3 each pooled avatar entry also holds a crew-hue mannequin (built once, when the tier first asks), and a clone beyond `CLONE_LOD.FAR` (18 studs) from the camera draws as it, back to the textured avatar inside `NEAR` (15; `Budget.cloneFar` hysteresis, no per-frame allocation). The hidden avatar's root still carries the pill, bubble and emitters, and its clips stop. With all 12 clones light the estimate is ~129k triangles / ~210 draws at tier 3 (budget 150k / 250) and ~128k / ~206 at tier 4 (120k / 200: still a little over, ±50%). Line-up figures past the front row and beyond FAR from the shot's camera are built light (never you or your newest clone). `perf_engine` measures the light count per tier and folds it into the estimate; `clone_engine` asserts the swap, the L1 tutorial exemption and the way back.

## 6. Memory figure per client (for the record)

| Item | Memory |
|---|---|
| Replicated level art with streaming on | ~3.3 MB (own Big Score) + the garage (~1.3 MB) |
| Each other crew's level that streaming no longer sends | ~2-3.3 MB |
| The clone system | ~21 MB (12 clones + 4 templates) |
| Avatar templates (119-144 instances each, one per player) | included in the 21 MB above (not measured apart) |

Real client memory adds GPU meshes and textures: the kit meshes are shared by every instance, and the atlas, sky and ring textures are a few MB. Measure it on the phone (§7).

## 7. What still needs a real phone

1. **Frame time** in the busiest view at 30 fps on a low Android (2-3 GB) and at 60 fps on a mid Android, judged by the 1% low as well as the average. This is the only number that decides the clone LOD and the 12-clone cap.
2. **Thermal:** a 15-minute soak on the low Android (roblox_quality §6.4: throttling appears after 5-10 minutes). Record the frame time at minute 1 and at minute 15.
3. **Client memory** in the Developer Console (Memory tab), in the garage and in a Big Score, against 60% of device memory.
4. **Draw calls and triangles** (the bench's readout, or the MicroProfiler) to replace the §5 estimates.
5. **Recipe C on screen:** does it read at quality 1-3, and does the runtime switch look right (LightingStyle)?
6. **Streaming:** no fall-through or pop at the run start and the garage return, and no "Gameplay paused" notice.
7. **Start tier:** built (§4): phones start at tier 2, a low quality level or a slow loading card starts them at tier 3. Check on the bench that a low Android lands on tier 3 (the Studio debug chip shows the tier) and a mid one on tier 2.

## 8. Owner bench: 10 minutes, one low Android (and a mid one if you have it)

Uses the existing Clone Bench place (`bench.project.json`; README "Clone phone bench") and the game's test place.

| Time | Do | Record |
|---|---|---|
| 0:00 | Charge the phone to more than 50%, close other apps, Wi-Fi on. If the bench is not published yet: `rojo build bench.project.json -o build/CloneBench.rbxlx`, open it in Studio, **File → Publish to Roblox As…** a new private experience (once, about 2 min) | phone model, RAM, OS version |
| 1:00 | Open **Clone Bench** on the phone. Keep CAM on FIXED and press **AUTO RUN** (about 3 min: baseline, then looks A/B/C at 4/8/12/16) | — |
| 4:00 | Press **RESULTS** and take a screenshot | avg fps, 1% low, worst frame, `+dc` and triangles at N=12 and N=16 per look |
| 5:00 | Open the game's test place, play L1 to your first clone, then open the Developer Console (type `/console` in chat) → **Memory** | screenshot of the Memory tab (total, PlaceMemory, Instances) |
| 7:00 | Back in the garage, play the Clone Party (L5) for 2 runs. Watch for pop-in at the run start and on the way back to the garage, and for any "Gameplay paused" notice | yes / no for each |
| 9:00 | Developer Console → Memory again, in the run | screenshot |
| 10:00 | Send the screenshots to the Shots inbox issue with the phone line | — |

Pass bar (MASTERPLAN §8.11 S1, §6.8): at N=12, 30 fps or better (≤ 33 ms by the 1% low) on the low Android and 60 fps or better on the mid phone; clones ≤ 120 draw calls (`+dc`); client memory ≤ 60% of the device's. If look B misses on the low phone and look C passes, the tier 3 clone LOD (§5) is the next performance task. The 15-minute thermal soak is a separate run: leave the Clone Party going and note the fps at minute 1 and minute 15.
