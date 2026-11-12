# shared/Sim

The deterministic heist simulation (MASTERPLAN §3, §8.2-8.5, §8.10). Pure Luau:
it runs in Lune for the L1/L2 tests and unchanged on the Roblox server. The game
runs it behind `Config.GAME_MODE = "sim"` (`src/server/Heist`); the default `v01`
path (the Nov 16 fun gate) does not use it.

| Module | Job |
|---|---|
| `HeistSim` | One heist instance: crew, Clone Decks, the run lifecycle, the fixed 20 Hz tick, results |
| `LevelSpec` | Level data format, validator (wiring, geometry, reachability, routes) and compiler |
| `Actors` | Live players and clones as plain data, in stable order |
| `Mechanisms` | Plates (grace), switches, doors (solid only when shut), lasers; per-run history for the lag rewind; client view helpers |
| `Guards` | `patrol(t)`, line of sight, the 3-stage cone, hide spots, "huh?", chase steering + A* |
| `Interact` | The only intent entry point (players and replaying clones) |
| `Divergence` | Clone path vs shut doors -> Stuck (Bonk) |
| `Loot` | Items: home, carried (first item + bag), dropped, banked (heist-persistent), respawning |
| `Alarm` | Alarm Run: chase, van countdown, alarmLock doors |
| `Deck` | Clone Deck: commit, Redo #N, Redo from #N, Delete, Delete busted, Undo |
| `Scoring` | Haul / Crew / Clean stars; party levels: one Star per haul tier |
| `EventLog` | Ordered integer log of every outcome + FNV-1a hash (Rec/Codec) |
| `Geom`, `Rng` | Boxes, segment tests, yaw convention; seeded Random-shaped LCG |

Levels are data in `src/shared/Levels/`:

| File | What |
|---|---|
| `Catalog` | The 6 launch levels in play order: L1, L2, L5 Clone Party (the party break), L3, L4, L6 (`dataId` = `Config.Data.LEVEL_ORDER`; a level's design number is `num` - 100, never its Catalog index) |
| `L1`-`L4` | Corner Shop teaching levels (Back Room, Two Doors, Lights Out, Night Clerk) |
| `L5_CloneParty` | `kind = "party"`: 8 slots, respawning shelves, Alarm Run on the till (time-locked until 0:20, shutter 6 s later: always the last act of a run), bag levels, Haul tiers 1000/2500/5000, Dawn at run 8; run 8 = "8 OF ME"; Line-up on the street |
| `L6_BigScoreBank` | Hoardsworth Bank, 45 s, par 4, cap 8: scale vault (4 plates, `need = "all"`), Gus, lasers, hides, a pillar that keeps the staff-door wait spot hidden, LOCKDOWN + loading-dock escape, haul = all the loot, Dawn at run 8 |
| `DailyVaults` + `Daily/DV01`-`DV12` | 12 daily mini-vaults (advent Dec 3-14, then the rotation repeats), 30 s, 5-clone loadout, Dawn at run 6, par 1-3 (only DV07 is par 3), haul = all the loot (bonus counts after the goal); slot = `Data/DailyVault.vaultFor(day)`; date-seeded vetted modifiers that one recording survives (34 pairs: LootB/C move bonus loot only, GuardFast/Slow on DV04/DV10/DV12, LightsOff on the four Gus vaults) |
| `Shop`, `Bank` | Kit geometry helpers (the kit layout replaces them after spike S2) |

Sim features the content uses (all covered by L1/L2 specs):

- **Party levels** (`kind = "party"`, `tiers`): never complete; the crew steals until Dawn; `Tier` events; `result().stars` = tiers met; `result().complete` = Haul1.
- **Bag levels** (`bags = true` + `HeistSim.addPlayer(sim, id, { bag = n })`): an actor carries `1 + bag x Config.Data.Bag.EXTRA_CARRY_PER_LEVEL` items; `actor.carrying` stays the first item, `actor.bag` the rest; drop/bank move everything; clones keep their owner's capacity; `result().bag` reports it (bag runs are excluded from Diamond).
- **`guardVision`** multiplier (daily "lights off").
- **Time-locked loot** (`opensAt`): a grab before that loop time is refused (`FAIL.Locked`); the Clone Party till.
- **View hooks:** `Swarm` event `SWARM_FANOUT_SECONDS` into a run (after the tape-print fan-out; a = seat, b = copies of that player, c = the crew's copies) for each player with `SWARM_SEEN_CLONES` own or crew clones in the world (co-op crews of 3-4 count); the view stamps `hooks.swarm.stamp` ("%d OF ME") with b only when b >= `SWARM_OF_ME`; `HeistSim.ofMe`; `HeistSim.lineup` (Crew Line-up: record order left to right for the camera, 60 ms stagger, default row on the street side of the van facing +Z); `lastRun.alarm` (who tripped the alarm and when; `hint = "RedoAlarm"` when a clone did it in the first `ALARM_HINT_SECONDS`); `result().daily` = `DailyVault.DailyResult` (its `timeMs` is the board tie-break after haul and clones); party levels: `result().data.clones` = one player's clones (`clonesPerPlayer`; the data rules' cap is per player), `clonesUsed` = the crew's.

Rules for every file in this folder (and in `../Rec/` and `../Levels/`):

- No engine services, no `game`/`workspace`/`script`, no `Instance.new`.
- No `task.*`, `wait`/`delay`/`spawn`, `os.*`, `tick`/`time`, `DateTime.now`,
  `math.random`. Time is the tick index (or an injected `LoopClock` fed the
  caller's server time); randomness is an injected `Random` (`newRandom(seed)`).
- Plain numbers and tables (no Vector3/CFrame), so everything runs in Lune.
- Iterate arrays, not dictionaries, where order matters (the L2 event-log hash
  tests catch dictionary-order bugs; lint cannot).
- Tuning numbers live in `Config.Sim` (and `Config.Rec`).

Checked by the second Selene config in this folder (`selene.toml` + `sim.yml`)
and by `lune run tests/pure_check.luau`:

```bash
selene --config src/shared/Sim/selene.toml src/shared/Sim src/shared/Rec src/shared/Levels
lune run tests/run_unit.luau   # L1 (incl. SimCore, SimLevelSpec, SimMechanisms, SimGuards)
lune run tests/run_sim.luau    # L2: determinism, fast-forward, solvability, naive kid,
                               #     latency, divergence, soak, lifecycle, Clone Party,
                               #     Big Score, daily vaults (incl. frozen-tape replays),
                               #     first-session pacing (printed model)
```

Rojo skips `selene.toml`, `sim.yml` and this README (`globIgnorePaths` in the
project files), so none of them end up in the place.
