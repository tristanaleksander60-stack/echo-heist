# CLAUDE.md: Echo Heist

Roblox co-op/solo game. Core mechanic: 60 s loops; each player's runs are recorded and replayed as "echoes" that act as crew. Solo must always be fully playable.

## Rules for every session
- Read PROJECT_STATE.md first (what's done, what's next, known bugs). Update it at the end, then commit and push.
- Code lives in `src/` (Rojo, see default.project.json). Never make big code edits through Studio MCP; use files.
- Roblox facts: use the LihFolk plugin. `python3 "<vault>/LihFolk Vault V2/_tools/vault.py" "<question>"` and `--api <Name>`; don't open whole notes. Use 2026 API names (`...Async` renames).
- The LihFolk hook checks every .luau file you write. Fix its findings.
- Server is authoritative: plates, lasers, guard, loot and banking are all decided on the server from actor positions. Gameplay input from clients is only `RequestRewind` (later END RUN / Interact intents). Menu remotes (`Data.*`, `Shop.*`) go through the LihFolk `Net` module with rate limits and validators (MASTERPLAN §8.8); the server re-validates everything.
- Anything an echo can do must go through `Actors` + recorded events (Echoes.recordEvent), or echoes will desync from players.
- Tuning numbers go in `src/shared/Config.luau`, never inline.
- Strategy docs: docs/VIRAL_PLAYBOOK.md (virality rules), docs/IDEA_ECHO_HEIST.md (concept), docs/GAME_BIBLE.md (search with grep, don't read whole).
- Originality: own name, art and characters; no borrowed IP.
