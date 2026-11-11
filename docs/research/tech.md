# Echo Heist: Technical Architecture, Networking, Testing and Performance

_Dimension: technical architecture. Written 2026-11-12, English. It is grounded in prototype v0.1 (`src/`, 1,824 lines, read in full for Echoes, Actors, Main, Mechanisms, Guard, Loot and Config). **Fact** = cited (vault note in italics, web source as a URL). **Decision** / **Recommendation** = our call. [UNVERIFIED] = I could not confirm it._

---

## Summary

The prototype has the right core idea. Every mechanism reads `Actors`, and echoes go through the same rules as players. It also has three structural problems that will not survive a premium release:

1. **Echoes are server-side Instances moved every Heartbeat.** `Echoes.step` writes `root.CFrame` on up to 16 anchored R15 clones at about 60 Hz, and the walk track is played on the server. That cost is paid three times: server CPU, a replication stream to every client, and choppy visuals, because replicated CFrames are not interpolated the way physics is.
2. **The world is not deterministic across loops.** The guard uses `Humanoid:MoveTo` plus `task.wait`/`os.clock` timing. The logic tick is `task.wait(0.1)` and the recorder is `task.wait(1/15)`. So the same recording can produce a different outcome in the next loop, and that silently breaks the core promise "your echo does exactly what you did".
3. **Recording trusts client-owned movement.** The server samples `HumanoidRootPart.CFrame`, which the owning client controls. A speed or teleport hack gets recorded into an echo and then replays forever.

**The architecture in one line:** the server runs a **fixed-step 20 Hz heist simulation** in which echoes are **pure data**: a position sampled from a recording at loop time `t`, with no Instance on the server. Each client receives each recording **once** as a compact `buffer` (about 5-8 KB per echo) and **renders its own echo rigs locally**, sampled against `workspace:GetServerTimeNow()`. Guards, doors and lasers become functions of loop time plus actor state. Recordings are validated and clamped on the server before they become echoes. Every level must ship with a scripted **solution recording** that CI replays headlessly to prove the level can be beaten.

This removes the biggest bandwidth and CPU cost, makes echoes look smooth (client-side sampling plus Animation Graph locomotion), makes the core mechanic testable without Studio (the sim core is pure Luau and runs in Lune), and puts anti-cheat at the one place it matters: what goes into a recording.

---

## Findings (with citations)

### F1. Platform state, November 2026

- **Server Authority is fully released (July 2026).** Setting `Workspace.AuthorityMode = Server` makes the server simulation authoritative. Clients predict their own inputs and resimulate on mismatch, and speed hacks are blocked "without custom anti-cheat". Turning it on **forces** `StreamingEnabled`, `NextGenerationReplication`, `PlayerScriptsUseInputActionSystem`, `SignalBehavior = Deferred` and `UseFixedSimulation`. Simulation code goes in `RunService:BindToSimulation`, uses `time()`, cannot `Destroy` or reparent, and can replicate at most 64 predicted attributes. At release, Animators had a limit of 8 actively playing tracks. (https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993, https://create.roblox.com/docs/projects/server-authority, https://about.roblox.com/newsroom/2026/07/creating-responsive-cheat-resistant-games-roblox-server-authority; vault *Server Authority and Input Migration 2026* §1.) The docs and the DevForum post disagree slightly on which settings are forced, so check them in Studio.
- **Physics replication is unstable in 2026.** The improved physics replication rollout was **rolled back on 2026-05-05**. Ownership-change jitter bugs were reported afterwards and a staff fix was posted later (https://devforum.roblox.com/t/upcoming-improvements-to-physics-replication/4675512, https://devforum.roblox.com/t/character-replication-mismatch-with-improvedphysicsreplication-enabled/4734415). Auto ownership gives a nearby client control of unanchored parts (https://create.roblox.com/docs/physics/network-ownership).
- **Animation Graphs are fully released** and run in live games. A `Blend1DNode` driven by a `Speed` parameter via `AnimationTrack:SetParameter` is the documented locomotion setup (https://devforum.roblox.com/t/full-release-animation-graphs-create-complex-character-motion-visually/4739840, https://create.roblox.com/docs/animation/graph-editor-state-machine).
- **SLIM avatar optimisation excludes NPCs.** SLIM turns *player* R15 characters into lightweight stand-ins, but "NPC characters, even standard R15 ones" fall back to default rendering (https://create.roblox.com/docs/workspace/streaming/slim, https://about.roblox.com/newsroom/2025/12/introducing-roblox-slim-scalable-lightweight-interactive-models). **Our echoes are NPC rigs, so they pay full avatar cost.** Layered clothing is "generally more performance intensive" (https://create.roblox.com/docs/avatar/layered-accessories/specifications.md, https://devforum.roblox.com/t/making-avatar-rendering-more-performant/4147160).
- **Collision groups moved to `workspace`** (September 2026). Old PhysicsService calls still forward (vault *Replication and Ownership* symptom table).
- **The Studio MCP server is built into Studio.** It is enabled under Assistant → Manage MCP Servers. Its tools are `list_roblox_studios`, `search_game_tree`, `inspect_instance`, `script_read/grep/search`, `multi_edit`, `execute_luau` (Edit/Server/Client), `start_stop_play`, `get_console_output` and `get_studio_state`. The `studio_id` changes on every Studio restart (https://create.roblox.com/docs/studio/mcp; vault *Roblox Studio MCP Server* §3).

### F2. Networking limits that shape the design

- `UnreliableRemoteEvent` payloads above **900 bytes** (docs) are dropped silently. One patch note says 1,000 bytes (https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent, https://devforum.roblox.com/t/introducing-unreliableremoteevents/2724155). Recordings therefore cannot travel unreliably.
- All remotes of one type from one client share about **500 calls/s** (vault *RemoteEvents RemoteFunctions and Unreliable Remotes*).
- Large `buffer`s are compressed automatically in transit, and grouping small buffers helps (quoted in https://devforum.roblox.com/t/bytenet-an-advanced-modern-networking-library-for-roblox/2733365; exact threshold [UNVERIFIED]).
- The vault's worked budget for a phone is **about 30 kbps of steady server→client data**. Big data is fine "as a one-time, spread-out cost; never as a steady stream". One reference project streamed 1.6 MB of animation data once per client (vault *Network Bandwidth Budgets and Measuring Them* §2-3).
- Tweening a replicated property on the server sends an update every frame to every client (same note). Our `Mechanisms.setDoor` does exactly that.
- Multiplayer sync pattern: the server publishes `StartAt` and duration as attributes, and every client renders "from an arbitrary `t`" (vault *Multiplayer Cutscene Sync - Server Clock, Late Joiners and Skip Votes*). That is exactly an echo.

### F3. Record-and-replay prior art

- There are two families: **input recording** (small, needs a deterministic sim; Trackmania-style ghosts) and **state snapshots** (bigger, robust, no determinism needed) (https://kindatechnical.com/game-development/replay-systems-and-input-recording.html; Gaffer's taxonomy of lockstep, snapshot and state sync at https://gafferongames.com/post/snapshot_interpolation and https://gafferongames.com/categories/networked-physics/). Roblox character physics is not deterministic across machines, so **we record state (positions) plus intent events**. That is what the prototype does, and it is right.
- In Braid, rewind had to fit 30-60 minutes of gameplay into about 40 MB (GDC 2010, https://gdcvault.com/play/1012210/). A 3D follow-up got about 62.5% savings from quantising positions to shorts (https://gamedeveloper.com/programming/braid-style-rewind-system-03). Quantisation is the standard trick.
- Quantum League uses 10-second loops with 3 clones per player. A reviewer *speculates* that clones run from data already on each client, which hides latency (https://checkpointgaming.net/reviews/2021/04/quantum-league-review-not-on-my-watch/ [speculation, not confirmed]). Killed clones become "desynced" (https://darkzero.co.uk/game-articles/preview-quantum-league/). That is our "busted echo".
- Cursor*10 is praised as "the best possible form of co-op" (https://en.wikipedia.org/wiki/Cursor*10). Shadow Clone does frame-perfect input replays (https://tanvrit-website.pages.dev/games/shadow-clone/). Messenger Mouse warns that replays drift when the game runs at a different rate than it recorded at (https://troystorygames.itch.io/messenger-mouse/devlog/945109/record-and-replay-ghost-races). That is why we sample by **time**, never by frame index.

### F4. Many characters on Roblox

- DevForum consensus: Humanoids are the main NPC cost, so render on the client and keep one data record or anchored part per NPC on the server. Developers report hundreds of client-rendered NPCs, and a 70% FPS gain from client-side `BulkMoveTo`. Mobile is called out as the weak case ("ANY amount... on my phone (Pixel 7 Pro)") (https://devforum.roblox.com/t/optimizing-hundreds-of-moving-npcs-rendering/3074292, https://devforum.roblox.com/t/how-we-are-developing-an-rts-game-with-good-performance-for-more-than-200-units/3281168/8, https://devforum.roblox.com/t/client-rendering-zombie/3364745).
- Per the docs, setting `CFrame` per part is "fast enough in the majority of cases". `BulkMoveTo` pays off at about 100+ parts per frame (https://create.roblox.com/docs/en-us/reference/engine/classes/WorldRoot.md, https://devforum.roblox.com/t/bulkmoveto-vs-normal-cframe-ing/1278502).
- Animation LOD may skip *writing joints* but must never skip *advancing track time* or gameplay markers (vault *Animation LOD* §1). Use `AnimationController` + `Animator` instead of a Humanoid where you can (vault *Wildlife and Ambient Creature AI* §4).
- Use one `Highlight` adorned to a container for a whole class instead of one per object, because the client has a fixed Highlight slot budget (vault *Highlights and Selection Effects* §2; the exact slot count is [UNVERIFIED]).

### F5. Data, leaderboards, testing infrastructure

- DataStore budgets are **per experience and shared with Open Cloud** since 2026-07-29: reads 300 + 40×CCU per minute, writes 300 + 20×CCU. Each key holds up to 4 MB and has 4 MB/min write throughput. Storage is 500 MB + 1 MB per lifetime player (https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits, https://devforum.roblox.com/t/unifying-data-stores-open-cloud-and-game-apis-and-increasing-storage-limits/4739240; vault *Data and Cloud Changes 2025-2026* §2).
- MemoryStore sorted maps hold up to 1M items / 100 MB each and support sort keys. Durable rankings belong in OrderedDataStores (https://create.roblox.com/docs/cloud-services/memory-stores, https://devforum.roblox.com/t/memorystore-sortedmap-sortkey-full-release/2872814).
- lihfolk-systems `PlayerData` provides a 90 s session lease inside `UpdateAsync`, a token-fenced save, a 30 s dirty-gated autosave, and a parallel `BindToClose` (26 s). `Leaderboard` treats the profile as truth and the ordered store as an index, and writes at most every 120 s (`skills/lihfolk-systems/SKILL.md`; vault *LihFolk Systems - Data and Purchase Guarantees*).
- **Open Cloud Luau Execution facts.** The script can be up to 4 MB and run for up to 5 minutes. A place can have 10 incomplete tasks at once. Creating tasks is limited to **5/min on the versioned path** (40/min unversioned). **Physics does not run** in the sandbox, and changes are not saved (vault *Code Pipeline - Rojo Git and CI* §Stage 5; https://create.roblox.com/docs/cloud/reference/features/luau-execution.md, https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185). Our `tools/cloud_test.py` already uses the versioned path.
- Place publishing: POST `/universes/v1/{u}/places/{p}/versions?versionType=Saved|Published`. Reported quirks are a 401 on `Published` while `Saved` works, and 409 "server busy" (https://create.roblox.com/docs/cloud/open-cloud/usage-place-publishing, https://devforum.roblox.com/t/publish-endpoint-returning-401-yet-i-have-a-valid-api-key/4432135).
- Roblox's official `place-ci-cd-demo` runs Selene, StyLua, Rojo build, upload, then Luau Execution tests (https://github.com/Roblox/place-ci-cd-demo). Lune (installed locally: **lune 0.11.1**, **Rojo 7.7.1**) is a standalone Luau runtime with a `roblox` library for reading and writing place and model files and Roblox datatypes (https://github.com/lune-org/lune). Rojo 7 syncs `.rbxm`, `.rbxmx` and `.model.json`, and 7.7 adds syncback (https://rojo.space/docs/v7/sync-details, https://newreleases.io/project/github/rojo-rbx/rojo/release/v7.7.0).
- Anti-cheat: Hyperion protects the client binary, but speed and teleport defence is the game's job on the server. Use conservative thresholds and "mitigate on low confidence, punish on accumulated evidence". Legitimate players produce latency bursts, falls, server teleports and streaming pauses that look like cheating (vault *Detecting Movement Exploits* §Tolerances; https://create.roblox.com/docs/scripting/security/server-side-detection). In the Roblox Guinness speedrun case, records were taken by teleport scripts (https://www.pcgamesn.com/roblox/guiness-world-record-cheat). **Leaderboards attract cheaters.**
- Performance dashboard: client memory by device type, % of device memory used, and CPU ms per frame by category. **16 ms for 60 fps.** A crash spike after an update usually means a low-end memory regression (https://create.roblox.com/docs/production/analytics/performance, https://create.roblox.com/docs/performance-optimization/test-on-hardware).

### F5b. Live Roblox data (tools/rbx_search.py, 2026-11-12)

The live search shows the genre neighbourhood (CCU | likes):

- Clone Engine: 1,797 | 161k
- Clone Friends: 1,224 | 10.8k
- Clone Yourself: 587 | 68k
- ROB IT: 1,713 | 222k
- Notoriety (a PAYDAY experience): 1,420 | 606k
- Heist Evolution: 2,195

The search found no time-loop heist; "time loop" returns only tiny games. The technical moat is real: anyone can spawn clones that *follow* you, but a deterministic, well-replicated replay that holds up at 4 players on a phone is hard to copy.

---

## Recommendations / decisions

### D1. Replace server echo Instances with a "sim core + client view" split (Decision)

```
            SERVER (authoritative)                         EACH CLIENT (view)
 PlayerSampler 20 Hz ──► RecordingValidator ──► Codec ──► EchoStore ──(reliable, once)──► EchoCache
        ▲                    (clamp/flag)       (buffer)    per player                     │
 player chars (client-owned physics)                                                       ▼
                                                                   EchoView: local rigs sampled at
 HeistSim fixed 20 Hz on loopTime:                                 t = GetServerTimeNow() - LoopStartAt
   Actors = players (live root) + echoes (sampled point)           Animation Graph locomotion, LOD
   Mechanisms (plates, doors, lasers)  ──attributes──►             MechanismView (tweens door locally)
   Guards (time-parameterised paths)   ──attributes──►             GuardView (local rig on path)
   Loot (kinematic, anchored)          ──attributes──►             LootView
   Events (grab, bust, desync, bank)   ──reliable remote w/ t──►   FX/SFX/UI at event time
```

- **Server echo = data only.** `{ ownerId, slot, rec, alive, state, carrying }`. Position comes from `Sampler.at(rec, t)`, a pure function. Plates use point-in-box checks (they already do). Lasers use segment tests. The guard raycasts to the *sampled point*, so no echo Instance is needed.
- **Client echo = local rig.** It is built once per owner per session from `Players:CreateHumanoidModelFromDescriptionAsync` (already used). It is stripped (see D6) and pooled. Clients create these rigs locally, so they never replicate and are never subject to streaming.
- **Clock.** The server publishes the attributes `LoopStartAt` and `LoopIndex` on ReplicatedStorage. Clients compute `t = workspace:GetServerTimeNow() - LoopStartAt`. Echoes are deterministic from the recording, so clients render at **the current t with no interpolation buffer**. Only server-decided state changes (busted, desynced, dropped loot) arrive about one ping late. Those are sent as reliable events carrying `t`, and the client blends them over 150 ms.
- **Late joiners** get the full EchoStore (at most 16 × 8 KB) plus the current attributes. That is the vault's "join snapshot plus deltas" rule.

### D2. Recording format and size (Decision)

- **Rate: 20 Hz** (up from 15). It is cheap, and jumps read better. Samples are taken **inside the fixed-step sim**, not in a `task.wait` loop. Sample by time; replay by time.
- **Per sample: 8 bytes.** Position is three `i16` relative to the level origin at 1/16 stud (±2,048 studs: enough for every planned level, with a per-level origin). Yaw is a `u8` (1.4°). Flags are a `u8`: grounded, jumping, crouch, carrying-heavy, and a 4-bit pose/emote id.
- **Header:** version byte, level id, loop index, sample count, validator flags.
- **Events:** a separate array of `{ t_ms u16, kind u8, arg u16 }` covering grab, release, press, hold-start/hold-end, gadget, vanish and emote. Each is 5 bytes; a typical run has fewer than 30.
- **Size per 60 s echo:** 1,200 × 8 B = 9.6 KB raw. Delta coding (i8 deltas with an escape byte) gives about 5 KB. 16 echoes ≈ 80-150 KB per heist, sent **incrementally**: one new echo per player per loop, so roughly 8 KB per client per rewind. That fits the vault budget easily.
- **Transport:** a reliable `RemoteEvent` with a `buffer`. The codec lives in `shared/` so Lune can test it (round trip, error ≤ 1/32 stud, version branch).
- **Interpolation:** Catmull-Rom on position across 4 samples, shortest-arc on yaw. Velocity is derived from neighbouring samples and feeds the animation `Speed`.

### D3. Determinism contract (Decision; this is the core mechanic)

The rule: **the world state at loop time t is a pure function of (level, loop seed, actor positions and events up to t).** In practice:

1. **One fixed-step loop.** `HeistSim.step(dt = 0.05)` is driven by an accumulator on `RunService.Heartbeat`, ticking on `loopTime`, never on `task.wait` timing. Mechanisms, guards, lasers, loot, delivery and the timer all live in it. This replaces the three loops in `Main.luau`.
2. **Guards are kinematic.** A patrol is a time-parameterised path: waypoints with arrival times and dwell, so `position = path(t)`. When a guard is alerted or investigating, he follows a small hand-authored **waypoint graph** with Luau A* (deterministic) at fixed speeds, never `Humanoid:MoveTo` or PathfindingService (async and timing-dependent). Vision is checked at a fixed 10 Hz sim tick. The client renders the guard rig locally from the same path data plus state attributes. Result: a guard who saw nothing walks **exactly** the same route every loop. That makes routes learnable, which is the whole puzzle.
3. **Doors and lasers are state machines** on sim ticks, with timestamps in attributes (`DoorA_OpenUntil`, `Lasers_OffAt`). Clients tween visuals locally; the server never tweens.
4. **Randomness** comes from `Random.new(levelSeed + loopIndex)` inside the sim only. The daily "Vault of the Day" seed is derived from the UTC date.
5. **Ordering.** Iterate actors in a stable order (players by join slot, then echoes by `(ownerSlot, slot)`), never dictionary order. Ties (two actors grab the same loot on the same tick) go to the lowest order index.
6. **Live players are the only non-determinism**, which is intended. With no players moving, two identical loops must produce identical event logs. CI checks this (D9).

**Divergence ("my past self betrayed me").** An echo follows its recorded *path*. The world may differ from the recording: a door closed, loot already taken, a guard rerouted. The sim checks the echo against **dynamic blockers only**. Static geometry has not changed, so it needs no check. If the next sample crosses a closed door's box, the echo enters `Stuck` (bonk animation, then a shrug emote, then it holds its position until the loop ends). Failed intents (a grab with no loot, a press while out of range) trigger a "confused" emote. This is cheap: a few segment-vs-box tests per echo per tick. It also produces the funny clips the playbook wants.

### D4. Interactions are intents, re-validated on replay (Decision)

The prototype already does this for `grab`. Generalise it:

- Every player action goes through `Interact.request(actor, kind, targetId)`, which validates range from the actor's **sim position**, then target state, then the cooldown. On success it records the event. On replay the echo calls the **same function**. The `CLAUDE.md` rule "anything an echo can do must go through Actors + recorded events" stays and becomes enforced: there is no other entry point.
- ProximityPrompt `HoldDuration` interactions become two events (`holdStart`, `holdEnd`). The echo must stay in range between them, or the action fails visibly.
- Gadgets (smoke, magnet, decoy) are intents with a target point. Their effects are sim objects with deterministic lifetimes.

### D5. Physics, carrying and ownership (Decision)

- **No physics for anything echoes touch.** Loot, doors, carts and heavy loot are **anchored and kinematically placed by the sim**. Echoes are kinematic recordings, so a physics object pushed by an echo would diverge between loops and between machines. This also side-steps the 2026 physics-replication instability (F1). Only player characters are client-owned physics.
- **Light loot (one carrier):** attached to the carrier's sim position (as now). It is rendered at the hand bone on clients.
- **Heavy loot (needs N grips, e.g. a safe that needs 2):** an `Item` with `grips[]`. While `#grips < N` it does not move, and grippers are leashed: going more than 5 studs away releases the grip. While `#grips >= N` it follows the grippers' centroid, capped at `HEAVY_SPEED` (8 studs/s). Players gripping heavy loot get `WalkSpeed` lowered on the server. Echoes need nothing special because their recorded positions already contain the slowdown. If one gripper is busted or desynced, the item drops. **Solo works:** you plus your echo carry the safe. This is fully deterministic and needs no network ownership.
- **Ownership rule:** anything unanchored that is not a character gets `SetNetworkOwner(nil)` right after parenting, re-asserted after every anchor or weld change (vault *Network Ownership*). On day 1 we should have none.

### D6. Echo count and rig budget (Decision)

| Players | Echo slots per player | Max echoes | Rigs on screen (incl. players) |
|---|---|---|---|
| 1 | **8** | 8 | 9 |
| 2 | 6 | 12 | 14 |
| 3 | 5 | 15 | 18 |
| 4 | 4 | 16 | 20 |

Solo gets 8 for the "8 synchronized copies of me" TikTok clip. The total cap stays at 16 echoes.

The echo rig is **stripped**: no `WrapLayer` (layered clothing), at most 3 rigid accessories (hair, hat, face), and a shared "hologram" material treatment. There is **one `Highlight` per owner**, adorned to a per-owner container, so at most 4 slots are used. `CastShadow = false` on every echo part. Each echo has `Humanoid.EvaluateStateMachine = false` (already) and `Humanoid` collision and physics disabled. If profiling shows the Humanoid itself costs too much, switch to `AnimationController` + `Animator` with the avatar's parts (the vault's ambient-creature pattern).

**Animation:** an Animation Graph with a `Blend1DNode` over idle/walk/run by `Speed`, plus jump, fall and land states from the recorded flags, plus an emote/interact layer (grab, push, bonk, shrug, confused). Keep at most 4 active tracks per echo. **Animation LOD:** under 40 studs, full rate; 40-100 studs, joints written at 15 Hz; over 100 studs or off-screen, no joint writes, but track time and events keep advancing. Movement of all echo roots goes through one `BulkMoveTo` call per frame.

### D7. Anti-cheat for recordings, medals and leaderboards (Decision)

- **Phase 1 (default authority):** a `RecordingValidator` checks each 20 Hz sample from the server's own view:
  - horizontal speed ≤ `WalkSpeed × 1.35 + ping allowance`, through a leaky bucket rather than a single-sample threshold;
  - vertical rise ≤ jump apex + 1 stud unless a server-granted lift is active;
  - no segment crossing a closed dynamic blocker or a static "no-go" volume (vault room walls);
  - every server move (`sendHome`, spawn) issues an exemption token through one helper.

  A violating sample is **clamped**: replaced with the last valid sample advanced at max speed toward the reported position, and the recording is flagged `tainted`. Tainted runs still play (co-op with your friends is your own business) but **never award medals or leaderboard entries**. No kicks on movement alone. Repeat offenders are silently excluded from boards (Roblox's server-side detection guidance).
- **Medal and leaderboard claims are computed by the server only**, from sim events: completion time, echoes used, loot banked. Run time is measured on the server clock. A board entry also stores the recording hash, so "Vault of the Day" world records can be audited later by replaying them headlessly in CI.
- **Phase 2 spike: `AuthorityMode = Server`.** Our game is a 1-4 player co-op without fast PvP, and it already needs streaming-safe code. Server Authority would make recordings trustworthy by construction. **Decision:** run a 2-day spike in a branch place in Phase 2 (movement feel at 150 ms simulated ping, the 8-track limit, deferred-signal fallout). Adopt it for launch only if feel is equal or better. The validator stays either way, because it also catches teleports caused by bugs.

### D8. Level authoring pipeline (Decision)

`LevelBuilder.luau` (code greybox) cannot produce "vanvittigt grafisk" levels. The new pipeline:

1. **Geometry and art are Instances, not code.** Each level is a Model `Level_<id>` stored as `assets/levels/<id>.rbxm` in git and mapped by Rojo to `ServerStorage/Levels` (`$path` to the folder; Rojo 7 syncs `.rbxm`). **Rojo never maps Workspace.** On heist start the server clones the level into `workspace.ActiveLevel` (`ModelStreamingMode = Atomic` for mechanism models) and destroys it on reset.
2. **Mechanisms are tagged, never scripted.** Use CollectionService tags `EH_Plate`, `EH_Door`, `EH_Laser`, `EH_Loot`, `EH_HeavyLoot`, `EH_GuardPath`, `EH_GuardNode`, `EH_Spawn`, `EH_Van`, `EH_NoGo` and `EH_Camera`, with **attributes as the wiring** (`PlateId="A"`, `Opens="VaultDoor"`, `Value=500`, `Grips=2`, `PathTimes="0,4.5,9"`). Set attributes first and tags last. A `LevelSpec` module parses a level into plain data (`LevelData`) and **asserts** it at server start and in tests: every door has a plate, every guard path is closed, the spawn exists, the van is reachable, and the level fits in ±2,048 studs of its origin.
3. **Three ways to build, by who builds:**
   - **Claude from files (primary for layout):** a Lune script `tools/levelgen/build.luau` reads `levels/<id>.layout.luau` (rooms, kit pieces, mechanism placements) and writes `assets/levels/<id>.rbxm` with `@lune/roblox`, composing **kit meshes** (walls, floors, vault doors, props imported once as MeshParts and referenced by asset id). This is reproducible, diffable through the layout file, and testable.
   - **Studio MCP (when the owner has Studio open):** Claude uses `execute_luau` in Edit for lighting, set dressing and screenshots, then exports to `.rbxm` through the owner. One room per call, not a whole level in one `execute_luau` call (vault MCP note).
   - **The human in Studio** does the final art pass: lighting, decals, hand placement. The result is saved to the `.rbxm` file. Rule: whoever touched last exports; the file in git is the truth.
4. **Publishing:** `rojo build` → `cloud_test.py` publishes a **Saved** version to the *test* place → tests → a separate **Published** release to the live place, done by hand and only on a release tag.

### D9. Testing strategy (Decision)

| Layer | Runs where | What | When |
|---|---|---|---|
| **L0 Static** | local/CI | StyLua `--check`, Selene, `luau-lsp analyze`, `rojo build`, LihFolk checker | every commit |
| **L1 Unit (Lune)** | local/CI, seconds | Codec round trip and quantisation error; Sampler (Catmull-Rom, yaw wrap); RecordingValidator (fixtures: walk, sprint-jump, fall, teleport, speed hack, server-teleport-with-exemption); GuardPath `position(t)`; Medal scoring; Profile schema migrations; LevelSpec on parsed `.rbxm` (Lune can read model files) | every commit |
| **L2 Sim (Lune, headless)** | local/CI | The whole `HeistSim` with **synthetic recordings**: (a) **determinism**: the same inputs twice give an identical event-log hash; (b) **solvability**: every level ships `levels/<id>.solution.luau` (hand-written recordings for N echoes) that must bank the target; (c) **divergence**: close a door early and the echo must go `Stuck`; (d) **soak**: 500 loops show no table growth | every commit |
| **L3 Engine (Open Cloud Luau Execution)** | test place | Real `buffer` and remote encoding, CollectionService parse of the real level, mechanisms with fake actors (already in `tests/engine_smoke.luau`), DataStore against the test universe's store with `_TEST` keys. **No physics** runs there, which is fine because our sim is kinematic | merge to main (5 tasks/min) |
| **L4 Human playtest** | Studio / devices | Feel (camera, controls, jump timing), echo readability, guard telegraphing, 2-4 player sync at 150-250 ms (Studio Network Simulator), phone fps and thermals, late join, leave mid-carry, mobile touch for rewind | each milestone; first one now |

**Design consequence.** The sim core (`shared/Sim/*`) must not touch engine services. It takes `Vector3`/`CFrame` values (Lune provides these datatypes) and plain tables, plus an injected clock and `Random`. Engine glue (`server/Services/*`) stays thin. That is what lets 80% of the game's logic run in Lune.

**CI:** a GitHub Actions workflow on `ubuntu-latest` with Rokit-pinned `rojo`, `lune`, `selene`, `stylua` and `luau-lsp`. L0-L2 run on every push; L3 runs on main with secrets `ROBLOX_API_KEY`, `TEST_UNIVERSE_ID` and `TEST_PLACE_ID`. This follows Roblox's `place-ci-cd-demo`.

### D10. Data model (Decision)

- **Install lihfolk-systems `PlayerData`, `Net`, `RateLimit`, `Leaderboard`, `Receipts`, `Shop`, `DailyRewards` and `Quests` as-is.** One writer and one `ProcessReceipt`.
- **Profile slice `Heist`** (target < 16 KB; hard cap 64 KB):
  - `schemaVersion`;
  - `vaults[levelId] = { best = { timeMs, echoes, stars, recHash }, medals = bitset }`;
  - `unlocks` (levels, echo slots, gadgets), `cosmetics` (echo hologram colours, trails), `loot` (soft currency);
  - `daily = { lastDay, streak }`.
- **Ghosts:** your personal-best recording per vault goes in a **separate** key, `G_<levelId>_<userId>` (about 10-40 KB). It is written only when a new best is set, and is used for "race your best crew" and for audits.
- **Leaderboards:** an OrderedDataStore per `(levelId, period)`. The score encodes `echoesUsed × 10^7 + timeMs` (fewest echoes first, then time), written only on improvement and only for untainted runs. A MemoryStore sorted map caches the "Vault of the Day" top 100 for 60 s. Daily boards are new keys each UTC day.
- **Budget:** at 1,000 CCU, writes allow 20,300/min. Autosave every 30 s plus bests is under 2,500/min. Call `SetRateLimitForRequestType` at start, and make Open Cloud jobs self-throttle with `GetRequestBudgetForRequestType`.

### D11. Performance budgets (Recommendations; the reference device is a mid Android phone with about 4 GB RAM)

| Budget | Target | Hard ceiling |
|---|---|---|
| Client frame (busiest view: vault, 4 players + 16 echoes + 2 guards) | ≤ 16.6 ms (60 fps) on a mid phone | 33 ms (30 fps) on low-end |
| Echo system CPU (sample + BulkMoveTo + anim) | ≤ 1.5 ms for 16 echoes | 3 ms |
| Client memory (Performance dashboard, Android) | ≤ 60% of device memory | 75% (crash zone) |
| Instances in an active level | ≤ 25k | 40k |
| Unique meshes / textures per level | ≤ 150 / ≤ 60 (≤ 1024², most 512²) | — |
| Draw calls, busiest view [rule of thumb] | ≤ 600 | 1,000 |
| Server sim step at 20 Hz | ≤ 2 ms | 5 ms |
| Server→client steady data | ≤ 20 kbps | 30 kbps |
| Per-rewind burst | ≤ 40 KB | 100 KB |
| Join to playable | ≤ 8 s on 4G | 15 s |
| ReplicatedStorage | code + config only (no level art) | — |

**Settings:**
- StreamingEnabled **on** (required by Server Authority anyway): `StreamingMinRadius` 128, Target 512, `StreamOutBehavior = Opportunistic`, `ModelStreamingBehavior = Improved`, mechanisms `Atomic`.
- The client never indexes level parts directly. It binds through tags (streaming-safe).
- Graphics quality tiers scale VFX density and echo LOD distances.

**Profiling plan:**
1. Add `debug.profilebegin/end` labels (`EH.Sim`, `EH.EchoSample`, `EH.EchoAnim`, `EH.GuardVision`).
2. Build a client **bench mode** (a debug-only command) that spawns 16 synthetic echoes from a fixture recording in the vault, so a phone can be tested solo.
3. Take MicroProfiler captures of 30-90 frames on a real phone at each milestone.
4. After launch, check the Performance dashboard weekly by device category. Any crash spike after a release is treated as a memory regression and rolled back.

### D12. Module list (target layout)

```
src/shared/
  Config.luau                 tuning (exists)
  Sim/HeistSim.luau           fixed-step core: step(state, dt) — pure
  Sim/Actors.luau             player + echo actors, stable ordering (from server/Actors)
  Sim/Mechanisms.luau         plates/doors/lasers as state machines (from server/Mechanisms)
  Sim/Guards.luau             path(t), waypoint-graph A*, vision cone test
  Sim/Loot.luau               light + heavy (grips) kinematic carry
  Sim/Interact.luau           the only intent entry point (players + echoes)
  Sim/Divergence.luau         dynamic-blocker checks, Stuck/Confused states
  Rec/Codec.luau              buffer encode/decode, versioned
  Rec/Sampler.luau            Catmull-Rom + yaw, flags
  Rec/Validator.luau          speed/teleport/no-go rules, clamp + taint
  Level/LevelSpec.luau        tags+attributes -> LevelData, asserts
  Scoring.luau                medals, leaderboard score encoding
  Types.luau, Tags.luau       frozen registries
src/server/
  Main.server.luau            the only Script; two-phase init/start
  Services/LoopService        loop lifecycle, rewind votes, LoopStartAt/LoopIndex attributes
  Services/SimService         Heartbeat accumulator -> HeistSim.step; publishes attributes/events
  Services/RecordService      samples players inside the sim tick, validates, stores, ships buffers
  Services/LevelService       ServerStorage/Levels -> workspace.ActiveLevel, teardown
  Services/ProgressService    medals, unlocks, ghosts (via PlayerData)
  Services/PartyService       solo/co-op caps, join snapshot
  LihFolk/                    PlayerData Net RateLimit Leaderboard Receipts Shop DailyRewards Quests
src/client/
  Main.client.luau
  Controllers/EchoView        local rigs, pool, BulkMoveTo, anim LOD, highlights
  Controllers/WorldView       door/laser/guard/loot visuals from attributes
  Controllers/HUD, Input (Input Action System), Camera, FX, Audio, Tutorial
tests/  unit/*.spec.luau (Lune)  sim/*.spec.luau (Lune)  engine_smoke.luau (Open Cloud)
levels/<id>.layout.luau  <id>.solution.luau     assets/levels/<id>.rbxm
tools/levelgen/build.luau   tools/cloud_test.py   .github/workflows/ci.yml
```

**2026 API names used (all reported `current` by the vault `--api` check):**
- `Workspace.AuthorityMode`, `Workspace.UseFixedSimulation`, `Workspace.SignalBehavior`, `Workspace.ImprovedPhysicsReplication`, `Workspace.GetServerTimeNow`
- `RunService.BindToSimulation`, `RunService.PostSimulation`
- `UnreliableRemoteEvent`, `RemoteEvent.FireClient`
- `Animator.GetTrackByAnimationId`, `Animator.StepAnimations`, `AnimationController`, `AnimationTrack.TimePosition`, `Humanoid.EvaluateStateMachine`
- `Players.CreateHumanoidModelFromDescriptionAsync`, `Players.GetHumanoidDescriptionFromUserIdAsync`, `Player.GetCameraState`, `Player.AddReplicationFocus`
- `Model.ModelStreamingMode`, `WorldRoot.BulkMoveTo`, `BasePart.SetNetworkOwner`, `Highlight`
- `MemoryStoreService.GetSortedMap`, `OrderedDataStore.GetSortedAsync`, `DataStoreService.GetRequestBudgetForRequestType`, `DataStoreService.SetRateLimitForRequestType`
- `BadgeService.AwardBadgeAsync`, `HttpService.GenerateGUID`

---

## Phased plan for this dimension

**Phase 0: prove v0.1 (now, 1-2 days).** The human runs the first Studio solo plus 2-client test, and we log feel issues. Meanwhile, set up L0 CI and Rokit pins, and move the codec and sampler into `shared/Rec` with Lune specs. **Exit:** we have a Studio feedback list, and Lune runs green in CI.

**Phase 1: the sim refactor (week 1-2).** Build `HeistSim` with the fixed 20 Hz step and the kinematic guard path. Mechanisms become state machines; door tweens move to the client. Echoes become data on the server and render through EchoView on clients with buffer transport. Add the RecordingValidator (clamp plus taint), the divergence `Stuck`/`Confused` states, and Interact as the single entry point. Bring L2 determinism and solvability tests in for the bank level. **Exit:** the bank level passes headless solvability; a 2-player Studio test at 200 ms simulated ping shows smooth echoes; and the bench mode holds 16 echoes at ≤ 16.6 ms on the owner's phone.

**Phase 2: production pipeline (week 3-4).** LevelSpec and tags; the Lune levelgen writes `.rbxm`; Rojo maps `ServerStorage/Levels`; the bank is rebuilt from kit meshes. Heavy loot with grips. Animation Graph locomotion and the emote layer. Echo rig stripping and per-owner Highlights. **Server Authority spike** (2 days, go/no-go). Install lihfolk-systems data modules and the profile slice. **Exit:** two levels built from files, with L3 Open Cloud tests green on main.

**Phase 3: progression and boards (week 5-6).** Medals, unlocks, ghost keys, OrderedDataStore boards, the daily seed for Vault of the Day, MemoryStore cache, and a tainted-run exclusion audit. Streaming settings tuned; memory and instance audit per level. **Exit:** a 30-minute soak test with 4 humans or alt accounts shows flat memory, and Play/Stop/Play and server-hop tests lose no data.

**Phase 4: pre-launch hardening (week 7-8, before the Christmas event).** Device matrix (low Android, mid Android, an iPhone 3-4 generations old, tablet), Performance dashboard baselines, `ServerRestartScheduled` drain, live-ops release checklist, and the Christmas level through the same pipeline. **Exit:** all D11 budgets met on the mid phone and the low-end ceilings held.

---

## Risks

| # | Risk | Likelihood | Impact | Mitigation | Owner/trigger |
|---|---|---|---|---|---|
| R1 | **Sim/visual desync**: the client echo is at a slightly different spot than the server's sim echo, so "it was on the plate but the door didn't open" | Med | High (breaks trust in the core mechanic) | Same `Sampler` module on both sides; the client renders at exact server t; plate tolerance +0.5 stud (exists); the plate lights from the **server** attribute | Phase 1 two-client test |
| R2 | **Non-determinism creeps back** (a new feature uses `task.wait`, `os.clock`, `math.random` or dictionary order) | High | High | The L2 determinism hash test on every commit; Selene rule banning those globals in `shared/Sim` | CI red |
| R3 | **Mobile frame budget blown by 16-20 avatar rigs** (SLIM doesn't apply to NPCs) | Med-High | High | Rig stripping, anim LOD, BulkMoveTo, caps scaled by player count; fallback is a stylised low-poly "hologram mannequin" tinted by owner colour instead of the full avatar beyond 60 studs | Bench mode on phone, Phase 1 |
| R4 | **Speed or teleport hacks recorded into echoes and leaderboards** | Med | Med (boards), Low (co-op) | Validator clamp + taint; server-computed scores; recording hash audits; Server Authority spike | Phase 1/3 |
| R5 | **Validator false positives** on lag bursts, falls or server teleports, so honest runs get no medal | Med | Med | Leaky bucket, ping-scaled margins, an exemption helper, horizontal-only speed; log taint reasons to analytics; tune with the fixtures | Taint rate > 2% |
| R6 | **Server Authority adoption breaks feel or tooling** (forced deferred signals and streaming, the 8-track limit) | Med | Med | A time-boxed spike in a branch place; the validator is the fallback; no dependence before go | Phase 2 go/no-go |
| R7 | **Level pipeline friction**: Lune-written `.rbxm` loses properties, or the human's Studio edits fight files | Med | Med | Git `.rbxm` is the truth; the last editor exports; LevelSpec asserts catch broken wiring; Rojo never maps Workspace (vault, measured: a hand-built map was deleted) | Phase 2 |
| R8 | **Open Cloud limits** (5 tasks/min, no physics, 409/401 publish quirks) slow CI | Med | Low | L3 only on main; publish as Saved; retry 409 with backoff; keep physics out of the design | CI timing |
| R9 | **Heavy carry feels bad** (centroid follow at speed cap reads as sliding) | Med | Med | Client-side lean and IK hands, squash, and audio; tune speed per item; human playtest | Phase 2 playtest |
| R10 | **Echo animation mismatch** (foot sliding, jump pose late) because poses are derived, not recorded | Med | Low-Med | Speed-driven Blend1D, recorded flags for jump and land, Catmull-Rom velocity; match stride to speed at source | Phase 2 |
| R11 | **DataStore throttling** at a launch spike, or an Open Cloud job sharing the budget | Low-Med | High (data loss perception) | lihfolk `PlayerData` lease + backoff; writes only on change; `SetRateLimitForRequestType`; jobs self-throttle | Launch week |
| R12 | **Late join or leave mid-loop** corrupts the echo set (a known bug class in v0.1, fixed once) | Med | Med | Join snapshot; on leave, echoes persist until the loop ends and then retire; loot is returned by the sim | Multi-client matrix |
| R13 | **Physics replication engine changes** (rollback history in 2026) | Low | Low | No gameplay physics except characters (D5) | — |
| R14 | **The guard's vision cone reads differently on client and server** (a visual cone vs a 10 Hz server check) | Med | Med | The client draws the cone from the same `Guards` module; sample the visible cone at the sim tick; a 0.25 s "spotted" grace with a clear tell | Phase 1 |

---

## Sources

**Vault notes (LihFolk Vault V2):**
- *Server Authority and Input Migration 2026*
- *Network Bandwidth Budgets and Measuring Them*
- *RemoteEvents RemoteFunctions and Unreliable Remotes*
- *Detecting Movement Exploits - Speed Fly Noclip Teleport*
- *Exploits and Anti-Cheat*
- *Code Pipeline - Rojo Git and CI*
- *Automated Testing with TestEZ and Jest-Lua*
- *Data and Cloud Changes 2025-2026*
- *DataStore Fundamentals*
- *LihFolk Systems - Data and Purchase Guarantees*
- *LihFolk Systems Library* (skills/lihfolk-systems/SKILL.md)
- *Instance Streaming*
- *CollectionService Patterns*
- *Animation LOD*
- *Wildlife and Ambient Creature AI* §4
- *Replication and Ownership*
- *Roblox Studio MCP Server*
- *Multiplayer Cutscene Sync*
- *Multi-Client and Live Testing*
- *Highlights and Selection Effects*
- *MicroProfiler Guide*
- *Art Budgets - Triangles Draw Calls Memory*
- API check (`vault.py --api`, about 30 names)

**Web:**
- https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993
- https://create.roblox.com/docs/projects/server-authority
- https://about.roblox.com/newsroom/2026/07/creating-responsive-cheat-resistant-games-roblox-server-authority
- https://devforum.roblox.com/t/upcoming-improvements-to-physics-replication/4675512
- https://devforum.roblox.com/t/character-replication-mismatch-with-improvedphysicsreplication-enabled/4734415
- https://create.roblox.com/docs/physics/network-ownership
- https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent
- https://devforum.roblox.com/t/introducing-unreliableremoteevents/2724155
- https://devforum.roblox.com/t/bytenet-an-advanced-modern-networking-library-for-roblox/2733365
- https://devforum.roblox.com/t/full-release-animation-graphs-create-complex-character-motion-visually/4739840
- https://create.roblox.com/docs/animation/graph-editor-state-machine
- https://create.roblox.com/docs/workspace/streaming/slim
- https://about.roblox.com/newsroom/2025/12/introducing-roblox-slim-scalable-lightweight-interactive-models
- https://devforum.roblox.com/t/making-avatar-rendering-more-performant/4147160
- https://create.roblox.com/docs/avatar/layered-accessories/specifications.md
- https://devforum.roblox.com/t/optimizing-hundreds-of-moving-npcs-rendering/3074292
- https://devforum.roblox.com/t/how-we-are-developing-an-rts-game-with-good-performance-for-more-than-200-units/3281168/8
- https://devforum.roblox.com/t/client-rendering-zombie/3364745
- https://create.roblox.com/docs/en-us/reference/engine/classes/WorldRoot.md
- https://devforum.roblox.com/t/bulkmoveto-vs-normal-cframe-ing/1278502
- https://gafferongames.com/post/snapshot_interpolation
- https://gafferongames.com/categories/networked-physics/
- https://kindatechnical.com/game-development/replay-systems-and-input-recording.html
- https://gdcvault.com/play/1012210/
- https://gamedeveloper.com/programming/braid-style-rewind-system-03
- https://checkpointgaming.net/reviews/2021/04/quantum-league-review-not-on-my-watch/
- https://darkzero.co.uk/game-articles/preview-quantum-league/
- https://en.wikipedia.org/wiki/Cursor*10
- https://tanvrit-website.pages.dev/games/shadow-clone/
- https://troystorygames.itch.io/messenger-mouse/devlog/945109/record-and-replay-ghost-races
- https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits
- https://devforum.roblox.com/t/unifying-data-stores-open-cloud-and-game-apis-and-increasing-storage-limits/4739240
- https://create.roblox.com/docs/cloud-services/memory-stores
- https://devforum.roblox.com/t/memorystore-sortedmap-sortkey-full-release/2872814
- https://create.roblox.com/docs/cloud/reference/features/luau-execution.md
- https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185
- https://create.roblox.com/docs/cloud/open-cloud/usage-place-publishing
- https://devforum.roblox.com/t/publish-endpoint-returning-401-yet-i-have-a-valid-api-key/4432135
- https://github.com/Roblox/place-ci-cd-demo
- https://github.com/lune-org/lune
- https://rojo.space/docs/v7/sync-details
- https://newreleases.io/project/github/rojo-rbx/rojo/release/v7.7.0
- https://create.roblox.com/docs/studio/mcp
- https://create.roblox.com/docs/scripting/security/server-side-detection
- https://www.pcgamesn.com/roblox/guiness-world-record-cheat
- https://create.roblox.com/docs/production/analytics/performance
- https://create.roblox.com/docs/performance-optimization/test-on-hardware

**Live Roblox data:**
- `tools/rbx_search.py`, queries "clone yourself", "heist" and "time loop" (2026-11-12).

**Project code:**
- `src/server/{Main,Echoes,Actors,Mechanisms,Guard,Loot}.luau`, `src/shared/Config.luau`, `tools/cloud_test.py`, `tests/engine_smoke.luau`, `PROJECT_STATE.md`, `CLAUDE.md`, `docs/GAME_BIBLE.md` §5 (another concept, the architecture rules reused).
