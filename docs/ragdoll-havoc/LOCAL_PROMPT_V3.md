# Prompt for the local Claude Code session (PC, RagdollLab folder, Studio open with the Roblox Studio MCP)

Paste everything below the line into `claude` started in the RagdollLab folder, on the `release` branch.

---

You are the lead developer on Ragdoll Havoc. Follow CLAUDE.md, and talk to me in Danish, short and plain.

Read these two files from GitHub, repo tristanaleksander60-stack/echo-heist (they are not in this folder):
- docs/ragdoll-havoc/BUILD_V3.md
- docs/ragdoll-havoc/LOOK_PLAN.md

Fetch them with:

    gh api repos/tristanaleksander60-stack/echo-heist/contents/docs/ragdoll-havoc/BUILD_V3.md -H "Accept: application/vnd.github.raw"

BUILD_V3.md is the plan. Start with Phase 0 (research):
- Reddit, TikTok, YouTube, Roblox communities and Discords, the DevForum and the games API.
- Write research/RESEARCH_V3.md in the echo-heist repo and push it.
- Show me in Danish the top findings and the re-ranked build order.

Then build phase by phase: A, then B, then C, then D.

Rules:
- Free Creator Store models are allowed: maps, vehicles, props, animals. Insert them with the Studio MCP.
- Run a malware pass on EVERY inserted model:
  - delete all Scripts and LocalScripts we did not write;
  - search for require(, getfenv, loadstring, TeleportService, HttpService and hidden objects (Name with spaces or zero-width characters);
  - report what you removed.
- Vehicles use our own simple chassis code, never a free-model chassis script.
- New code goes in files (Script Sync), not big edits through MCP. Tuning numbers go in Config.
- Everything new sits behind `Config.LOOK_V3`.
- After every phase:
  - take Studio screenshots from the same 3 camera spots (spawn, cannon, crash wall) and from each new map, and show them to me;
  - run LayoutCheck and the affected SelfTests;
  - commit and push to the `release` branch;
  - tell me to save the place, since models live only in the place file.
- Start with Phase A (lighting, white talking dummies, HUD v3, world text off), then the Test Ground map.
