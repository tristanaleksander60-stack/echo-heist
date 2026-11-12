# shared/Sim (planned)

The deterministic heist simulation from MASTERPLAN §8.4 lands here: `HeistSim`
(pure step), `Actors`, `Mechanisms`, `Guards`, `Loot`, `Interact`, `Divergence`,
`Alarm`. Nothing is in it yet; v0.1 still runs the server modules in `src/server/`.

Rules for every file in this folder (and in `../Rec/`, today's pure layer):

- No engine services, no `game`/`workspace`/`script`, no `Instance.new`.
- No `task.*`, `wait`/`delay`/`spawn`, `os.*`, `tick`/`time`, `DateTime.now`,
  `math.random`. Time comes from an injected clock (`LoopClock`), randomness from
  an injected `Random`.
- Take `Vector3`/`CFrame` and plain tables, so ~80% of the logic runs in Lune.
- Iterate arrays, not dictionaries, where order matters (the L2 event-log hash
  test catches dictionary-order bugs; lint cannot).

Checked by the second Selene config in this folder (`selene.toml` + `sim.yml`)
and by `lune run tests/pure_check.luau`:

```bash
selene --config src/shared/Sim/selene.toml src/shared/Sim src/shared/Rec
```

Rojo skips `selene.toml`, `sim.yml` and this README (`globIgnorePaths` in the
project files), so none of them end up in the place.
