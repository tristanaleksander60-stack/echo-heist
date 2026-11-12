# shared/Sim

The deterministic heist simulation (MASTERPLAN §3, §8.2-8.5, §8.10). Pure Luau:
it runs in Lune for the L1/L2 tests and unchanged on the Roblox server. **Not
wired into the v0.1 server yet** (the Nov 16 fun gate runs v0.1).

| Module | Job |
|---|---|
| `HeistSim` | One heist instance: crew, Clone Decks, the run lifecycle, the fixed 20 Hz tick, results |
| `LevelSpec` | Level data format, validator (wiring, geometry, reachability, routes) and compiler |
| `Actors` | Live players and clones as plain data, in stable order |
| `Mechanisms` | Plates (grace), switches, doors (solid only when shut), lasers; per-run history for the lag rewind; client view helpers |
| `Guards` | `patrol(t)`, line of sight, the 3-stage cone, hide spots, "huh?", chase steering + A* |
| `Interact` | The only intent entry point (players and replaying clones) |
| `Divergence` | Clone path vs shut doors -> Stuck (Bonk) |
| `Loot` | Items: home, carried, dropped, banked (heist-persistent), respawning |
| `Alarm` | Alarm Run: chase, van countdown, alarmLock doors |
| `Deck` | Clone Deck: commit, Redo #N, Redo from #N, Delete, Delete busted, Undo |
| `Scoring` | Haul / Crew / Clean stars from sim results |
| `EventLog` | Ordered integer log of every outcome + FNV-1a hash (Rec/Codec) |
| `Geom`, `Rng` | Boxes, segment tests, yaw convention; seeded Random-shaped LCG |

Levels are data in `src/shared/Levels/` (L1-L4 Corner Shop, `Catalog`).

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
                               #     latency, divergence, soak, lifecycle
```

Rojo skips `selene.toml`, `sim.yml` and this README (`globIgnorePaths` in the
project files), so none of them end up in the place.
