# WORKFLOW: How we build fast, cheap and well

Read this at the start of every session. It is short on purpose. Use GAME_BIBLE.md only by searching it (`grep -n`), never by reading it whole.

## 1. Cost rules (tokens are the budget)

| Do | Don't |
|---|---|
| `python3 "<vault>/_tools/vault.py" "<task in plain words>"` (about 575 tokens) | Open whole vault notes or folders |
| `vault.py --read "<title>" "<heading>"` for one section | Re-read the vault (the one-time digest cost about 4.5M tokens and is done) |
| `grep -n` in GAME_BIBLE.md, then read the matching lines | Read the 23k-word bible from top to bottom |
| One focused session per milestone, with clear acceptance criteria | Long, wandering sessions that drag a huge context along |
| Install `lihfolk-systems` modules (`/lihfolk:new-system`) | Have the AI write PlayerData, receipts or remotes from scratch |
| Code in files (Rojo + git), checked by the LihFolk hook | Big code edits through Studio MCP |
| Studio MCP for scene operations and reading numbers, in small calls | Asking MCP to "build the whole map" in one call |
| Multi-agent workflows and the council **only at milestones** | Running a council on every small change |
| Agents and workflows only for broad parallel reading or review | Spawning agents for things a single grep can answer |

**Session start (maximum about 5k tokens):** read `CLAUDE.md` (under 200 lines) and `PROJECT_STATE.md` (under 150 lines), then do the task. **Session end:** update PROJECT_STATE.md with what was done, what is next and any known bugs, then commit and push.

## 2. Which plugin skill to use when (LihFolk v2.5.0)

| Task | Skill / command |
|---|---|
| Concept, trend analysis, launch | `/lihfolk:trend-game` (roblox-trend-game) |
| New system (data, shop, quests, daily rewards, codes) | `/lihfolk:new-system` (lihfolk-systems, roblox-system-builder) |
| Remotes and network | roblox-secure-remotes, roblox-anti-exploit-review |
| DataStore and saves | roblox-datastore-safety |
| Purchases and policy | roblox-monetization-compliance |
| UI | lihfolk-ui, roblox-ui-builder, lihfolk-figma (from Figma) |
| Map and level | lihfolk-worldbuilding |
| Models | roblox-blender-modeling, then roblox-asset-import |
| Assets from the pack | `/lihfolk:assets` (requires `LIHFOLK_ASSETS` to point at the asset pack) |
| VFX / SFX | lihfolk-vfx / lihfolk-sfx |
| Onboarding | lihfolk-tutorial |
| Bugs / lag | roblox-debugging / roblox-performance-audit |
| Quality gate (at least 8.5/10) | quality-score; `/lihfolk:learn` logs the results |
| Independent verdict | `/lihfolk:council quick` (milestones only) |
| Whole-project audit | `/lihfolk:audit` (before launch) |

## 3. Originality gate (against "AI slop" and copies)

Run this before any concept or feature is locked in:

1. `python3 tools/rbx_search.py "<theme>" "<core verb>" "<synonyms>"`: 5-10 searches.
2. Search Steam and itch.io for the same theme and verb.
3. **Red:** the theme **and** the core verb are already a game with more than 1K CCU, or at least 3 games share the same theme and verb, even dead ones. Then the TikTok viewer thinks "another one".
4. **Yellow:** the theme exists, but our **core verb** is new and is visible in a 3-second clip without sound. Allowed only if the thumbnail shows the new verb.
5. **Green:** neither the theme nor the verb combination has been found.
6. **Hard checklist, all of it required before GREEN (added after the MUSH! mistake):**
   - search **at least 15 keywords**: the theme, the verb, synonyms, **seasonal variants** (sleigh/santa/christmas/halloween), and the name;
   - read the **descriptions** of the top results (games API), not just the titles: is the verb itself described?
   - look at **total visits and the created date**, not only current CCU. A game with 100M visits that is sleeping now still makes us look like a copy;
   - check Steam and itch.io for the theme and the verb;
   - **name:** a Roblox search for the name gives no game; it is not a generic word or term; it is searchable and easy to spell; there is no known trademark;
   - **timing assumptions** checked against the policy (new games are 16+ only until evaluation);
   - an **independent agent** tries to kill the concept before we lock it.
7. The hook must survive a "7-year-old test": a stranger understands a 15-second clip with the sound off.

**Lesson from 2026-11-11:** almost every theme exists on Roblox, usually as 3-10 low-effort attempts with fewer than 300 CCU. That includes moving companies, monster teeth, window washers and safari filming. Originality is therefore won on (a) **a core verb nobody has nailed**, (b) **craft**: feel, art direction and the first 60 seconds, and (c) **a thumbnail that shows that verb**. A theme alone is never unique.

## 4. Division of labour

- **Claude:** code (Luau in Rojo files), systems, tests, configs, data tables, research, competitor checks, documentation, review.
- **You (human):** taste and art direction, feel tuning in playtests, Studio settings, publishing, the account, Robux and the questionnaire, phone tests, TikTok clips.
- **Asset packs:** the LihFolk Asset Pack and the Folk Icon Pack are on your computer. Give the session access through Remote Control (Claude desktop app, Settings, Claude Code, Remote Control: add the folder) or upload them as a zip. Then set `LIHFOLK_ASSETS=<path>`. Use them before generating anything new. They are hand-made, which also guards against "AI slop".

## 5. Saving work

The cloud container gets deleted. **Everything must live in a GitHub repo** (code, CLAUDE.md, PROJECT_STATE.md, GAME_BIBLE.md, WORKFLOW.md, tools/). Commit and push at the end of every session.
