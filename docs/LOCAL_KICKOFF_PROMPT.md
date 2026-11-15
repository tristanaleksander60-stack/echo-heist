# Kickoff prompt for a local Claude Code session

Paste everything below the line into `claude` started in the `echo-heist` folder.

---

You are the lead developer on "Heist Yourself: Rob With Your Clones" (code name Echo Heist), a Roblox game built with Rojo. Your job this session: find and fix every bug you can, then raise the game's quality toward a polished, Steam-quality first-person co-op/solo heist game for kids 8-13 on phones. Players are already arriving from paid ads, so stability comes first.

## Before anything else
1. Read `CLAUDE.md`, all of it, and follow its rules: server authority, remotes, Config for numbers, echoes through Actors and recorded events, and originality.
2. Read `PROJECT_STATE.md`. Concentrate on the last ~40 entries and every line marked "Open", "Not seen in Studio", "Owner decision" or "Not published".
3. This is a Windows machine. Check which tools exist: `git`, `python`, `rojo`, `lune`, `stylua`, `selene`.
   - If any are missing, install them with Rokit. Use the PowerShell installer from the rojo-rbx/rokit GitHub README, then `rokit add` for `rojo-rbx/rojo@7.7.1`, `lune-org/lune`, `JohnnyMorganz/StyLua` and `Kampfkarren/selene`.
   - Tell me exactly what you installed.
   - The LihFolk vault and its check script do not exist on this machine. Skip them, and rely on the official Roblox Creator Docs for engine facts.
4. Run the local test suite and report the baseline before you change anything:
   - `lune run tests/compile_check.luau`
   - `stylua --check src tests`
   - `selene src tests`
   - `lune run tests/pure_check.luau`
   - `lune run tests/wait_check.luau`
   - `rojo build default.project.json -o build/t.rbxlx`, then `lune run tests/place_check.luau build/t.rbxlx`
   - `lune run tests/run_unit.luau`
   - `lune run tests/run_sim.luau`
   - `lune run tests/hud_layout.luau`
   - `lune run tests/glyph_check.luau`
   - `lune run tests/ui_kit_check.luau`

## How I test (you cannot see the game)
- I test in Roblox Studio through the Rojo plugin. Start `rojo serve default.project.json` when I ask to test, and tell me exactly what to try and what I should see.
- Engine tests on Roblox's servers use `python tools/cloud_test.py --universe 10776026960 --place 70772627070328 --script tests/<suite>.luau`. They need `ROBLOX_API_KEY` in my environment.
  - If it is missing, ask me to set it myself with `setx ROBLOX_API_KEY "..."` in PowerShell. Never ask me to paste any key into the chat.
  - On HTTP 409, 429 or 500, wait 90 s and retry.
  - Only publish with `--publish-type Published` after engine_smoke and client_engine both pass. Tell me to press "Restart Servers" in Creator Hub afterwards.

## Priorities, in order
1. **Joining must always work and be fast.**
   - Join → control in the hideout lobby in under ~6 s.
   - No frozen screens, no stuck HUD and no dead ends: back to garage, a failed run, a full server, a slow profile load.
   - The story intro is OFF (`Config.Intro.ENABLED = false`) and stays off unless I say so.
2. **Every bug in PROJECT_STATE "Open" items.** For each one: reproduce it from the code path, fix the root cause, add a regression test (unit, sim or engine), and run the suite.
3. **Feel and clarity for a 10-year-old.**
   - The L1 tutorial (~15 s) and run 2 must be obvious without reading.
   - Controls: Shift sprint, Ctrl slide, V camera view, E use, R rewind, Q crew view. Show key hints on screen.
   - The HUD must be readable on a 360-wide phone.
4. **Visual quality in the real engine, not in Blender.**
   - Toon outlines, baked AO, warm lighting without a violet cast, nothing blown out.
   - First-person gloves that look smooth.
   - Judge only by Studio screenshots I send you. Ask me for one when you need it.
5. **Performance on phones.** Stay inside `Config.Perf` budgets for every tier; tier 4 is at its limit.

## Working rules
- Work in small, safe steps. After each fix, run the local suite. Commit with a clear message and push to `main`. If I ask for risky work, use a branch.
- Never do big rewrites without asking me first. Never change remote names. Keep solo fully playable.
- Before you call something "fixed", show the test that proves it. If you could not verify it in the engine or in Studio, say so plainly.
- Add a short entry to `PROJECT_STATE.md` at the end of every work block, and push it.
- Talk to me in Danish, briefly. Tell me what you changed, what I should test in Studio, and what is still open.

Start now: do the setup and baseline steps, list the open problems you found ranked by player impact, then begin fixing from the top.
