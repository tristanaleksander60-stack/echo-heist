# GAME BIBLE: "Catch The Couch" / Feral Furniture Co. (working titles)

> **What this is.** The shared "brain" for every build session of our original co-op Roblox game. It condenses the LihFolk Vault V2 (about 1,300 notes) and plugin v2.5.0 (2026-10-29) into decisions, numbers and rules, so a future AI session can work **without re-reading the vault**. When a detail here isn't enough, use the cheap lookup in section 2 (`vault.py`). Don't open whole notes.
>
> **Dates.** Written 2026-11-11. Vault platform facts are "as of October 2026" unless stated. Re-check anything about policy, prices, discovery or APIs before you rely on it live.
>
> **Trust labels used below.**
> - **[Docs]**: Roblox Creator Hub or DevForum, as cited in the vault.
> - **[Measured]**: the vault's reference project, a live melee game built mostly by Claude Code agents, or the vault's own builds.
> - **[RoT]**: rule of thumb.
> - **[Reported]**: trackers, press, vendors.
> - **[Unverified]**: claims the vault itself could not confirm.
> - **[Inference]**: our own conclusion for this project, not stated by the vault.
>
> Note titles are in *italics*. Every title can be found with `vault.py --paths "<title words>"`.

> **⚠ CONCEPT STATUS (2026-11-11): ON HOLD.** An originality check on Roblox search (tools/rbx_search.py) found the moving/haunted-furniture theme already tried many times: "Moving Out!" (~105 CCU), "Moving House Simulator!" (~170), "Moving In!" (~290), "Clumsy Movers [CO-OP]" (~12), "Haunted Movers" (0), "MIDNIGHT MOVERS [HORROR]" (~4), "Flee the Furniture" (possessed furniture, ~100), "Load The Truck!". On Steam: Carry On Together (physics co-op moving, Nov 2026), Backrooms: Steal the Furniture, Furniture Busters. The *catch-living-furniture* mechanic itself was not found, but the theme fails the "not already made by 10 others" gate. Sections 4-10 (algorithm, architecture, art, workflow, rules) stay valid for any concept. See WORKFLOW.md section 3 for the originality gate.

---

## 0. Project identity (one screen)

| Field | Decision |
|---|---|
| Fantasy | You and your friends run a cheap moving company. The furniture doesn't want to move. |
| Genre | Co-op physics comedy with light "danger at night" (friendslop-inspired), 2-6 players, solo viable |
| Core verb | **Grab, carry, catch, stuff into the truck** |
| Twist (one sentence) | "Your crew has until sundown to catch the runaway furniture and stuff it in the truck, because after dark it fights back." |
| Platform target | Phone first: about 80% of DAU is on mobile [Reported, 2024]. Also PC, gamepad and tablet. |
| Tone / maturity | Bright, goofy-spooky, no blood or gore. Aim for a **Mild** label, Moderate at most, so 9-15 stays reachable. |
| Session | One job of 8-12 min. A 10-30 min session is a "shift streak" of 2-3 jobs. |
| Team | Danish owner, solo or small team. Claude Code writes most code (Rojo files plus Studio MCP). Humans own taste, feel tuning, playtests, publishing and account actions. |
| Non-goals | No drivable truck in the MVP. No PvP. No trading. No paid randomness. No proximity-voice dependence. No AI-generated meshes. No copying R.E.P.O., Lethal Company, Moving Out or Content Warning art, UI or names. |

---

## 1. TL;DR (10 bullets)

1. **Concept.** Pick **"Living-Furniture Movers"**. It merges panel concepts B, D and B+. Most furniture is ordinary physics cargo. A few pieces per house are *alive*: skittish by day, feral at night. You catch them, strap them, haul them, and they become your **Furniture-dex** collection (an internal working name; the player-facing name avoids "-dex", see 3.2). The antagonist is now **visible, has a face and can be clipped**, which was B's fatal flaw. It also solves the R.E.P.O. / Moving Out "knockoff" problem.
2. **Clips must work with the sound off.** Voice is limited to age-verified 13+ users, and most players don't have it [Docs]. Comedy therefore lives in the physical object: a wardrobe galloping off, a piano on the stairs, a teammate rolled up in a rug. Keep scenes bright, readable at 160x90, and have a failure or chaos moment every 20-40 s [RoT/Inference].
3. **The algorithm (June 2026, [Docs]).** Recommended For You ranks on **play-through rate**, **first-play bounce** (<60 s and 61-180 s), play days over **D1 / D2-7 / D8-28**, playtime capped at 60 min/user/day, and **intentional co-play days** (invites, joins, private/reserved servers). Only organic RFY joiners count, and ads and TikTok traffic do not feed ranking directly. Fix the first session **before** pushing clips.
4. **First 60 seconds.** Control in about 10 s. Spawn facing a snoring footstool beside the truck. First grab within 10-20 s, first payout within 30-40 s (bar: under 60 s for 85% or more of players). A second loop with a twist by about 40-60 s. No menu, no cutscene, no pop-ups. **Never gate playing with friends.**
5. **The networking core is carrying.** Use two carry tiers. **Light** items are carrier-owned with force-limited AlignPosition/AlignOrientation. **Heavy** items, and living pieces whenever their brain is active, are server-owned and pulled toward the carriers by capped movers. That mirrors the vault's "pushable crate" worked example (two players *pushing* one crate at 150 ms: 3 flings in 10 under auto ownership, 0 in 20 when server-owned; *Debugging Physics and Network Ownership* §8, a worked example, not labelled Measured). Nobody has tested a two-person *carry* (see 3.11). The server decides delivery, damage and payout. Velocity caps, the `WatchOwner` tag and a 300 studs/s watchdog go in on day 1.
6. **MVP scope.** The truck stays parked; travel is a fade or teleport. Ship 1 house layout plus 1 variant, 15-20 furniture props, and 2-3 living archetypes, with a night phase that turns unpacked living pieces feral. Downed players are "rolled in a rug" and carried to the truck. Reuse lihfolk-systems (PlayerData, Net, Currency, DailyRewards, Quests, Receipts, Shop), the Round-Based Loop, Horror Monster Chase numbers and Downed/Revive.
7. **Art against "AI slop".** Flat or untextured low-poly built with a **gradient palette atlas** and SmoothPlastic. Write a numeric style bible with 3-5 golden assets. Generate Blender meshes from scripts and run them through gates A1-A18. **No text-to-3D meshes.** One human art owner signs off every face expression. Nights are tinted, never black. Test at the lowest graphics quality, because phones below quality 4 render no shadows [Docs].
8. **Retention.** D1 comes from the first job. D2-7 come from a daily seeded "Featured House" plus verb quests plus a next upgrade 5-15 min away. D8-28 come from the Furniture-dex, neighbourhood unlocks, shift-streak records and a **weekly "new feral item" drop**, which is the cheapest content unit and a natural TikTok clip.
9. **Money, kept kind.** Cosmetics (uniforms, truck paint, strap trails, emotes, face stickers), a door-opener pass under 100 Robux, a "this server" crew boost, cheap private servers, and a starter pack offered only **after** the first job. No paid power, no paid randomness, no revive prompts mid-chase, no pop-ups during onboarding. Prices come from `GetProductInfoAsync`.
10. **Saving AI credits.** Use `vault.py` (about 575 tokens per search) instead of reading notes. Keep CLAUDE.md under 200 lines and PROJECT_STATE.md under 150 lines, with handoffs. Code lives in Rojo files plus git. Use MCP only for scene operations and numeric checks, in calls under 1.5 s. Install library modules instead of generating them. Run the council and the 8.5 quality gate only at milestones. Humans playtest feel, because **Edit mode cannot simulate physics**.

---

## 2. How the LihFolk plugin and vault work, and when to use each part

### 2.1 Install and layout
- Install: `/plugin marketplace add lihfolk-cy/v2-vault` then `/plugin install lihfolk@lihfolk`.
- Repo root: `/home/user/lihfolk-cy/v2-vault/`.
  - `LihFolk Vault V2/` is the Obsidian vault, about 1,300 notes in 59 sections.
  - `skills/` holds 22 skills.
  - `commands/` holds 6 commands.
  - `agents/` holds 3 agents.
  - `hooks/` holds the PostToolUse checker.
  - `benchmark/`.
- Every note has a TL;DR callout that states its own token cost (median TL;DR about 170 tokens against about 4,000 for the whole note [Measured]). Each note also has `## Common mistakes` and `## Checklist`.

### 2.2 The cheap lookup protocol (main token saver)

| Tool | Use | Cost [Measured] |
|---|---|---|
| `python "LihFolk Vault V2/_tools/vault.py" "<task in plain words>"` | The default. Prints the top 3 notes' TL;DRs, the top note's section list and matching `SYMPTOMS.md` lines. Right note in the top 3 for **93%** of tasks, against 60% for grep. | ~575 tok/search |
| `vault.py --read "<title>" "<heading words>"` | Read **one** `##` section. | one section |
| `vault.py --sections "<title>"` | List a note's headings. | tiny |
| `vault.py --paths "<words>"` | Titles and paths only (cheapest). | tiny |
| `vault.py --api Class.Member` | Check an API name against the dated snapshot (2026-10-29): current, deprecated → replacement, or unknown. | tiny |
| `vault.py -k 5`, `--brief`, `--full`, `--json` | More, fewer or raw results. | varies |
| grep `INDEX_SLIM.md` / `SYMPTOMS.md` | Fallback when Python isn't available. One line per note or symptom. **Never read INDEX files whole** (INDEX_SLIM is about 36.8k tokens). | ~25-40 tok/line |
| `ROUTER.md` | Topic-to-note map (about 1,250 tokens). Worth reading only in long multi-topic sessions; for a single lookup it costs more than it saves. | 1.25k |

**When to look up** (from the Benchmark note, [Measured]): the vault gained about +16 points over plain Claude, and about 14.7 of those came from **2025-2026 platform changes**. On evergreen basics both scored the same.
- **Always look up:** policy, monetisation, limits, prices, discovery, age rules, deprecations, Async renames, Server Authority, physics replication changes, Studio and MCP features, and Blender versions.
- **Skip:** CFrame maths, basic remotes, ModuleScripts, plain Luau.
- **Read the full** `Common mistakes` + `Checklist` for player data, purchases, remotes and security, and for anything that ships live. Never cite a number you only saw in a TL;DR.
- Ask at most 6 questions per lookup call, one lookup per topic per session.

### 2.3 Skills: when to use each

| Skill | Use it when | Notes |
|---|---|---|
| `lihfolk` (router) | Any Roblox knowledge question. | Delegates to the **`lihfolk-lookup` agent (haiku)**, which returns about 50 words per question as Facts, Gotchas and Sources and says "not in vault" when it can't find something. |
| `lihfolk-systems` (`/lihfolk:new-system <sys>`) | Installing data, net, currency, shop, receipts, daily, quests, codes or leaderboard. | 19 modules, "reviewed, not run". Score is capped at 5.0 until specs pass in Studio. **There is no physics, carry or vehicle module.** |
| `roblox-system-builder` | Building **custom** systems: carry, living furniture, job phases, delivery, rug-revive. | Start from the closest Worked Build. Include a decisions table, one server Script, startup asserts and 2-client tests. |
| `roblox-secure-remotes` | Every new remote. | Order: rate (1.5-2x the fastest legitimate use) → type → value (NaN, inf, range, distance) → context → lock and act with no yield → score, never kick. |
| `roblox-anti-exploit-review` | Before soft launch, and after any physics or remote change. | Physics claims are a threat class. Explicit ownership; one mover per assembly. |
| `roblox-datastore-safety` | Any save code. | One writer, a lease of 30 s or more, BindToClose within 30 s, never `SetAsync` on profiles. |
| `roblox-monetization-compliance` | Before adding any product or pass. | One ProcessReceipt, prices from `GetProductInfoAsync`, PolicyService fails closed. |
| `roblox-performance-audit` | At the end of each milestone. | Phone budget: render 8-10 ms, simulation 2-3 ms, **client scripts 2 ms**. 15-min soak on a real phone. |
| `roblox-debugging` | Any bug. | Reproduce, find the first wrong value, bisect, write a one-sentence cause, verify at 2x the runs, leave a guard. Never "fix" with `task.wait` or `pcall`. |
| `roblox-ui-builder` | HUD, menus, ping wheel, Furniture-dex. | 44 px taps, 12 px text, `Activated`, UIScale tweens, no Gotham. |
| `lihfolk-ui` | Only if we want the "Ink and Candy" simulator look. | Probably **not** our HUD style [Inference]. We may reuse its structure with our own tokens. |
| `lihfolk-tutorial` | First-session flow and the funnel. | Module `Tutorial.Server.new{...}`. Pattern "Social, never a gate". Two tutorial players can share one server. |
| `lihfolk-worldbuilding` | House blockouts, lighting presets, budget reports. | `LihFolkWorld.luau` (`budgetReport(root,"mobile")`, `auditWorld`, seeded `scatter`). Presets: Readable night and Fog horror. |
| `roblox-blender-modeling` | Every furniture prop, the house kit and the truck. | `lihfolk_bpy.py`, `lihfolk_house.py` (real door and window openings), `lihfolk_creature.py`. Blender 5.2, headless. |
| `roblox-asset-import` | Each GLB import. | Scale Unit Studs, reset PivotOffset, Merge Meshes off for kits, walk every doorway after import. |
| `lihfolk-assets` (`/lihfolk:assets`) | Looking for original assets in the LihFolk Asset Pack (`$LIHFOLK_ASSETS` or `~/LihFolk-Assets`). | Shippable rows only. Search `CATALOG.csv`s. Never use Toolbox assets or invent ids. |
| `lihfolk-vfx` | Dust puffs, slam impacts, telegraphs, camera shake. | The `LihFolkVFX_Abilities` module (Telegraph, CameraShake, HitStop) is UNTESTED in Studio. Particle cap 900 PC / 360 touch. |
| `lihfolk-sfx` | Furniture squeaks and shrieks, footsteps, bell, ambience. | Licensed sources only; Roblox-licensed Creator Store audio first. -18 LUFS, 3 or more variations. Audio API for directional sources. |
| `lihfolk-figma` | Only if the UI is designed in Figma. | Never paste web code from `get_design_context`. |
| `quality-score` (`/lihfolk:learn`) | Milestone gates on models, worlds, UI, tutorial and systems. | **Bar 8.5/10.** Any hard-gate failure caps the score at 5.0. One blind reviewer in fix rounds; **3 blind reviewers (median) for pass/fail**; at most 3 fix rounds. Ledger at `.lihfolk/ledger.jsonl`. |
| `council-method` (`/lihfolk:council [quick\|standard\|full] <q>`) | Decisions that are expensive to reverse (concept, economy, art direction). | Quick = 1 blind Skeptic seat. Standard = 3 seats that you rank. Full = 5 seats plus chair, only when asked. Fix the rubric first and keep the evidence pack short. **Playtests and Roblox docs override the council** (same model family). |
| `roblox-trend-game` (`/lihfolk:trend-game`) | Platform facts and the 7-day launch plan. | Its skeleton is a collect-upgrade-steal sim, not our genre. Use `references/trend-games-research.md` for RFY, the under-16 gate and thumbnails. |

### 2.4 Commands, agents and hooks
- **Commands:**
  - `/lihfolk:trend-game`: idea to launch plan.
  - `/lihfolk:new-system <sys>`: install a library module.
  - `/lihfolk:council`: blind verdict.
  - `/lihfolk:audit`: whole-project scan plus safety skills, ranked P0-P3. A clean run is not a security review.
  - `/lihfolk:learn`: distil the ledger into `.lihfolk/recipes.md`.
  - `/lihfolk:assets`.
- **Agents:**
  - `lihfolk-lookup` (haiku): cheap lookups.
  - `council-member` (sonnet): blind seats.
  - `council-chair`: Full tier only.
- **Hook.** A PostToolUse 17-rule Luau checker runs on every `.luau` Claude writes. It catches:
  - `wait`, `spawn`, `delay`;
  - `Instance.new(class, parent)`;
  - unvalidated remote args;
  - `InvokeClient`;
  - DataStore calls without pcall;
  - player `SetAsync`;
  - missing BindToClose;
  - bad ProcessReceipt returns;
  - no PurchaseId idempotency;
  - paid random items without PolicyService;
  - `Connect` in loops;
  - `while true` with no yield;
  - client-set currency;
  - FindFirstChild chains.

  Silence one line with `-- lihfolk-ignore: <id>` (a whole file with `-- lihfolk-ignore-file: <id>`), or disable everything with `LIHFOLK_HOOK=off`. After an Edit it reports only the lines that edit produced, at most 15 findings. It returns JSON `decision: block` for errors; PostToolUse cannot undo the write. In general, Claude Code policy hooks must **exit 2** to block; exit 1 does not block.
  - **The hook does not catch deprecated or renamed APIs** (the Async renames, `Humanoid:LoadAnimation`, `Body*` movers, `PhysicsService` collision groups and so on). Check those with `vault.py --api` and the table in 5.9.
  - It cannot see across `require`: a remote validated inside `Net` or a save done by `PlayerData` is invisible to it.

### 2.5 How the vault labels truth
"Reviewed, not run" means nobody executed the code. **All** Worked Build and library code carries this label, so test it in a scratch place first. Conflicts between notes are collected in *Open Questions - Whole Vault*; check it before quoting limits. The API snapshot is `_tools/roblox_api.json` (docs build 2026-10-27). `_data/roblox_facts_2026.json` holds deprecated-API maps and limits, and is cheaper to feed to Claude than notes.

---

## 3. Concept decision

### 3.1 The panel, weighed

| Concept | Virality lens | Retention lens | Feasibility lens | Notes |
|---|---|---|---|---|
| A: Island trash comes alive at night | 4 | 4.5 | **7.5** | Easiest to build, but reads as a 99 Nights reskin. Muddy palette, solo verb, weak clips. **Rejected.** |
| B: Moving company, house resists (original pick) | 6.5 | 6.5 | 6.5 (5 as pitched) | Best verb, but the antagonist is **invisible** (no icon or mascot), and the premise sits close to R.E.P.O. and Moving Out. No D8-28 engine. |
| C: Zoo night shift | 7 | 6 | 3.5 | Strongest meme subject, but animal rigs and AI, nets and darts, and trucks put it at 2-3 months, not 3-4 weeks. The night threat is unclear. **Rejected for now** (could be a later "neighbourhood" theme). |
| D: Living-furniture movers (virality lens proposal) | **8.5** | n/a | not scored | The cargo *is* the character, so it has a face, an icon and a clip. Risk: googly-eye "slop" if the art direction is weak. |
| B+ "Lodgers" (retention lens proposal) | n/a | **~8** | n/a | One cursed, capturable object per house plus a collection shelf plus shift streaks. |
| B-MVP (feasibility lens proposal) | n/a | n/a | best risk/reward | Parked truck, two carry tiers, server-owned heavy items, Horror Monster Chase reused. |

**Synthesis [Inference].** All three lenses converge once the hostility moves *into the furniture*. D supplies the face and the clip. B+ supplies the collection meta and the capture climax. B-MVP supplies the technical guardrails, and they fit D naturally: living furniture is **server-owned whenever it acts** (the server only ever pushes server-owned assemblies), which removes the hard problem "the house applies forces to a client-carried prop". A caught *light* piece may be handed to its carrier, but only with its brain suspended (see 5.3). So the answer to the user's original B pitch, "something in the house doesn't want you to move it", is: **the furniture itself doesn't want to be moved.**

### 3.2 Final concept: "Catch The Couch" (store title) / Feral Furniture Co. (brand)

**Pitch (one sentence):** *"Your moving crew has until sundown to catch the runaway furniture and stuff it in the truck, because after dark it fights back."*

**The 7-year-old test:** someone who has never played understands a 15-second clip of a wardrobe sprinting away with two kids hanging on.

**Why it is original** [Inference, still needs a store search; see 3.10]:
- Moving Out has inert furniture and no meta.
- R.E.P.O. has loot plus an external monster.
- Living furniture is a folk and fairy-tale motif, not anyone's IP.
- The core loop of co-op wrangling of living furniture into a truck, plus collecting it, does not match any hit in the vault.
- Use the genre conventions freely (quota, carry, night danger). **Never** copy their art, UI, names, layouts or thumbnail compositions (*Legal Basics - IP Licenses and Assets*; *Competitor Analysis Method*).

**Nearby works to keep visibly distinct from** [Inference, general knowledge; the vault does not cover these. Mechanisms are free to use, but surface, characters and names are not]:
- *Moving Out 1-2* and *Totally Reliable Delivery Service*: chaotic co-op moving and delivery. Don't copy their isometric camera, level-select van map, clipboard/score UI or character look.
- *R.E.P.O.* / *Lethal Company*: quota, carry loot to an extraction point, external monsters. Don't copy the cart, quota terminal or monster designs.
- *99 Nights in the Forest* (Roblox): we borrow three mechanisms (lit safe radius, night count as run record, earnable classes). Keep the surface different: a truck headlight pool in a suburb, never a campfire in a forest, and no deer-like monster.
- *Beauty and the Beast* (Disney): its living household objects (a talking mantel clock, candelabra, teapot) are protected character designs. Our grandfather-clock "boss" and lamp must not have arms, human mouths or butler/maître-d' personalities; keep our faces to the style-bible eye/mouth set.
- "Moves only when unwatched" is a common horror rule (SCP-173, the Weeping Angels). Use the rule, but not the statue look, names or "don't blink" lines.
- *The Mimic* is an existing Roblox horror title. Keep "Mimic" as an internal archetype id only; the player-facing name is something like "Fake Fridge".
- "-dex" is strongly associated with Pokémon. Keep `Dex` as the code/profile name, and give it a player-facing name such as **"Moving Ledger"** or **"Trophy Shelf"**.

### 3.3 Core loop
- **Micro (5-30 s):** spot a piece (it peeks, hides or twitches) → sneak up or chase → grab, pin or strap it → carry it to the truck ramp while it struggles (big pieces need 2-4 movers on handles) → it lands in the truck bed and the "PACKED!" stamp pays out. Damaged pieces pay less, so the carry has stakes.
- **Short (one job, 8-12 min):** a work order such as "1 sofa, 2 lamps, 1 piano, 1 ??? (mystery)". The quota is displayed **on the truck itself** (diegetic, so the HUD stays clean for clips).
- **Long (days-weeks):** Furniture-dex collection, company upgrades (bigger truck bed, better straps, dolly), neighbourhood unlocks, crew cosmetics, shift-streak records, and weekly new feral items.

**Loop sentence test** (*Core Loops and Session Design*): "Grab the furniture → haul it to the truck → get paid → upgrade your crew → take a harder house." It is a hand verb with a feedback arrow, and the first reward lands under 30-40 s.

### 3.4 Session structure (one job)

| Phase | Duration (tunable in Config) | What happens |
|---|---|---|
| Arrive | 0-5 s | The crew spawns on the truck ramp at the curb, facing the house. No cutscene. Travel between jobs is a fade or teleport (`RequestStreamAroundAsync` first). |
| Day | ~5-6 min | Inert furniture is ordinary physics cargo. **Living pieces are sleepy and skittish**: they flee, hide or play dead, which makes a catch-and-carry puzzle. The shared **House Awake** meter rises with noise (drops, breakage, shrieks). |
| Dusk | 45-60 s warning | Bell chime, sky colour shift, screen-edge pulse, captions ("[The house is waking up]"). There is always a tell (*Anticipation*: 500 ms or more for anything must-dodge). |
| Night | ~2-3 min | Unpacked living pieces go **feral**: they charge, nip, barricade doors and flick lights. The house dims room by room. The truck's **lit radius is the safe zone** (the 99 Nights campfire lesson). Finish the quota, or everyone gets inside the light and slams the truck door to leave early with partial pay. |
| Payout | 6-10 s | A count-up tally (log-scaled), a rating and stars, the Furniture-dex "NEW!" stamp, and the next-goal card. Then a vote between "Next job" and "Back to depot". |

- **Shift streak:** back-to-back jobs with a rising quota give a run-story record, like 99 Nights' night count. Failing ends the streak but **keeps meta progress** (no wipe). Run-based persistence: the house resets, the meta persists (*Genre Playbook - Survival and Crafting*).
- **Server model for the MVP:** a single place, server size 6, each server is one crew doing jobs in sequence [Inference; this avoids a whole class of teleport failures]. Party members spawn together via `Player.PartyId`. **Private servers are cheap and are a retention feature.** Post-MVP option: an HQ/depot lobby place plus reserved run servers per crew (Doors and Pressure pattern), using `TeleportOptions.ReservedServerId = HttpService:GenerateGUID(false)` and one `TeleportAsync` per party. Reserved servers count toward co-play [Docs].
- **Session-length targets:** comparable co-op horror averages are Grace 8.1, Piggy 11.2, Pressure 12.2 and Evade 12.8 min [Measured, Rolimons 2026-10-29]. Creator Rewards needs 10 min or more [Docs]. A phone session of 5 minutes must still complete something, so even the first job pays out within a minute.

### 3.5 Living-furniture archetypes (data rows, cheap to extend)
Each archetype has **one tell and one counter, and the counters use different verbs** (*Teardown - Grace*). Behaviour, mass, size, face set, sounds and payout are data rows in `shared/Config/Furniture.luau`. A new archetype is mostly data plus one behaviour function, which is cheap in tokens.

| Archetype | Day behaviour (tell) | Counter (verb) | Night (feral) | MVP? |
|---|---|---|---|---|
| **Footstool** | Puppy-like zoomies; it squeaks when it notices you | **Corner** it (walls or teammates) | Nips at ankles: a 0.4 s stumble, not a down | Yes (tutorial piece) |
| **Wardrobe** | Moves **only when nobody is looking**, judged over 0.2-0.4 s, never one frame | One player **keeps eyes on it** while others strap it | Charges whoever looks away | Yes |
| **Lamp** | Flickers the room's lights to blind you | **Unplug** it from behind (hold prompt at the cord) | Strobe-free "lights out" pulses: no more than 3 flashes per second, behind a flash-limiter setting | Yes, or the first post-launch drop |
| Sofa | Bucking bronco | **3 riders/straps** at once | Bucks off holders (ragdoll) | Post-MVP |
| Piano | Heavy; rolls downhill, especially down stairs | Wedge it with a dolly or chock | Rolls at the crew | Post-MVP (in the MVP it is an **inert** heavy item, which is the stair-disaster clip machine) |
| Fridge | "Mimic": pretends to be a normal appliance | Knock twice (inspect) before grabbing | Opens on you (a jump-scare-lite) | Post-MVP |
| Grandfather clock | The night "boss". Its chime is the countdown | Stop the pendulum (a co-op hold on two sides) | Rewinds carried items back out of the truck | Later event |

- **The mystery item:** each house rolls one living piece from a weighted, **server-only** table seeded per job. Featured House jobs use a daily shared seed so "today's house" is comparable on TikTok.
- **Lodger rule from B+:** in the MVP each house has **1 living piece** (bounded AI scope, per the retention lens). Use 2-3 in harder neighbourhoods later.

### 3.6 Co-op mechanics (2-6 players, solo viable)
1. **Heavy lifts.** Heavy items (piano, fridge, sofa, wardrobe) have 2-4 handle attachments. Per-carrier `MaxForce` is deliberately too low for one person, so co-op is physically required (`MaxForce = mass × accel`, *Mover Constraints and Physics Controllers*). **Solo path:** a dolly lets one player move a heavy item at half speed, so the first session never fails solo (Dead Rails and zombie co-op both list "solo impossible" as a mistake).
2. **Emergent roles.** Chaser, strapper, lookout (the wardrobe-watcher) and lifter. Post-MVP, the explicit **roles** Lifter, Packer (bubble-wrap reduces damage), Spotter (flashlight freezes or slows living pieces) and Wrangler (lasso strap at range) are bought with an **earnable** meta currency (Stars), never with Robux (the 99 Nights class pattern). Each role is an ability that changes play, not a stat bonus (*Teardown - Dandy's World*).
3. **Shared failure cost.** The noise from drops, breaks and shrieks fills one **House Awake** meter for everyone. Dusk comes sooner and nights start harder. The team cares and no single player is blamed (*Teardown - Dandy's World*).
4. **Full pay to every contributor.** Everyone with at least about 10% contribution gets full pay; nothing is split, so helping is never worse than solo (*Social Design and Multiplayer Play*). **Crew bonus** +10% per friend, capped at +30% (`IsFriendsWithAsync`, cached, in pcall).
5. **Downed means "rolled in a rug"** [Inference, our own twist on *Downed, Revive and Bleed-Out States*]:
   - When feral furniture downs a player (or after the second stumble in 6 s), the server sets `LifeState = Downed`.
   - The character is hidden or spectating, and a **rug-burrito prop** (light carryable, with the player's face sticker) spawns at the spot.
   - A teammate carries the rug into the truck's light to revive. A hold-prompt revive of 3-5 s is the fallback when you are already in the light.
   - Bleed-out 30/20/10 s on repeated downs. After that the player is a ghost who can push light objects (knocking over the lamp that wakes the house is a clip). Revive returns the player with 1-2 s of shield.
   - **Team wipe:** if every crew member is downed or a ghost at once, the job ends at once with partial pay for what is already packed. The meta is kept and the shift streak ends. Don't make players watch bleed-out timers (*Downed, Revive and Bleed-Out States* §7).
   - **Solo:** the vault says solo players "either skip downed state or get a self-revive". Ours: a solo player rolled in a rug **wriggles free** with a 3-4 s mash or hold, once per night. A second down ends the job with partial pay [Inference].
   - The ghost's pushes are server-validated like any carry: rate, distance and the per-player prop cap. A ghost never touches living pieces.
   - **Why a prop and not carrying the player character:** carrying a player means a weld, `RootPriority` changes, an ownership transfer and consent rules (*Grabs, Carries and Throws*). A rug prop reuses the light-carry code with no player-ownership hazards.
6. **Silent co-op.** It must work fully without voice or chat:
   - a ping wheel ("Lift!", "Over here!", "Behind you!", "Watch it!"), where the client sends only an index;
   - an auto "LIFT TOGETHER" prompt when 2 or more are near a heavy item;
   - emotes and teammate outlines through walls;
   - **game-generated proximity drama** from furniture shrieks and footsteps.

   Proximity voice is a bonus layer: the Audio API can put voices through emitters on characters with a "truck radio" EQ [Docs]. **Never** require it, never reward talking, and never let "the house hears your voice" drive gameplay (`AudioAnalyzer` is client-only and spoofable).
7. **Griefing guards** (*Teardown - Fling Things and People*):
   - Players can't grab other players.
   - Velocity is clamped on all props, and there is a per-player prop cap.
   - Nothing rewards harming teammates.
   - Dropping furniture on a teammate gives a stumble, not a down.
   - Chaos is aimed at the cargo, not at teammates.
8. **Scaling.** Quota and threat use `base × (1 + k(n−1))` with k = 0.5-0.7, counting only active players in the house. Smooth n over 10-20 s. Late joiners get a full join snapshot and full pay for the remaining portion (*Spawn Director - Credit Budgets and Player-Count Scaling*).

### 3.7 The 5 signature clip moments (designed in, not hoped for)
All five read **with sound off**, in daylight or warm-lit dusk.

1. **"It was RIGHT THERE"**: the wardrobe that only moves when unwatched. The camera pans back and it is gone, or right behind you. It costs almost nothing (an AI rule) and is made for comments.
2. **Piano down the stairs**: an inert heavy item with 2-4 carriers. One drops their handle and everyone ragdolls in a heap at the bottom. This is the vault's named high-performing format, "physics going wild on a group" (*Short-Form Video Marketing*).
3. **Footstool zoomies / wardrobe gallop**: a living piece bolting across the yard with a mover dragged behind on a strap. The dragged state is a capped 2-3 s client-side follow with mash-to-escape (prototype risk, see 5.3).
4. **Rug-burrito rescue**: a downed friend rolled in a rug, carried like cargo to the truck as night falls, sometimes dropped on the way.
5. **Door-slam finish**: the last piece is crammed in and the truck door slams just as feral furniture hits it. The whole crew ragdolls in the truck bed. A **before/after** cut of the empty truck against the stuffed truck makes a loopable ending.

Extras for later: the sofa rodeo (3 riders bucked off), the fridge mimic opening on someone, a ghost teammate knocking over the lamp, and cargo exploding out of the truck (only once driving exists).

**Tuning target [RoT/Inference]:** a readable failure or chaos beat every **20-40 s** of play. Measure it in playtests by counting drops, escapes and ragdolls per minute.

### 3.8 Progression and retention hooks
| Window | Hooks |
|---|---|
| **First session / D1** | First job in a small cottage. A sleeping footstool next to the truck gives the first catch in 10-20 s. First payout in under 60 s. The first living escape around 40 s. The **first dusk is telegraphed and survivable** ("a strong first night": players who survive night one stay). A next-goal card after every job. 3-5 server-tracked first-session goals ("Pack your first piece", "Catch a living one", "Finish a job", "Finish a job with a friend (optional)"). |
| **D2-7** | Something is **ready on every join**: <br>• a daily seeded **Featured House**, identical on every server via `GetServerTimeNow()`, so "can you beat today's house?" works as a TikTok format; <br>• the next upgrade affordable within 5-15 min; <br>• verb quests ("deliver 3 pianos", "catch a wardrobe without it moving"), **never "log in" or "play X minutes"**; <br>• daily rewards with a grace day; <br>• a shift-streak record. |
| **D8-28** | • The **Furniture-dex**: every living archetype and rare variant (golden toilet, disco lamp), earned and never sold as random, shown on a "Trophy Shelf" in the depot for visiting friends. <br>• Neighbourhood unlocks: suburb → farmhouse → apartment block with stairs and a lift → mansion → lighthouse → museum. Each is a content drop. <br>• Crew and company cosmetics. <br>• Weekly new feral item. <br>• Scheduled "Haunted Mansion Move" server-time events (Experience Events with RSVPs). |
| **Social (co-play signal)** | • Invite at "this job needs more hands" moments and after a proud payout, using `PromptGameInvite` with `LaunchData` (`v1\|crew\|<code>`). <br>• Reward the inviter **only after the friend plays about 10 minutes**, with a cosmetic. <br>• Friend boost capped at +30%. <br>• A "bring back your crew" panel (`GetFriendsWhoPlayedAsync`). <br>• Cheap private servers. |

**Rule:** every update adds a **mechanic** (a new living verb, a neighbourhood, a tool), not just bigger numbers (*Core Loop*: "loops wear out").

**Badges (optional, cheap):** award from the server only, with `BadgeService:AwardBadgeAsync` in pcall (`AwardBadge` is a deprecated pre-2026 name). Badges mirror profile progress and are never the source of truth. Each game gets **5 free badge creations per 24 h, then 100 Robux each** [Docs, *BadgeService - Engine Reference Card*]. Use a few for Ledger milestones ("First feral catch", "Piano Mover"), not one per archetype.

**Player-entered text:** no free-text crew or company names in the MVP; pick from preset name parts. If we add free text later, filter it with `TextService:FilterStringAsync`. Non-chat text is rate-limited to 1 submission per minute per player since the 2026-10-21 TextChatService update [Docs]. Never build a custom chat UI that reads `TextChatMessage.Text`: it is planned to return an empty string (auto opt-in February 2027, mandatory May 2027) [Docs].

### 3.9 Monetisation plan (policy-compliant, kind)
- **Economy:** one flat soft currency, **Pay** ("company cash"), plus one earnable meta currency, **Stars** (from job ratings and catches). The vault says round-based or party games need only "a flat price list and a weekly shop rotation" (*Economy Inflation Sinks and Faucets Math*). Time-to-afford bands: small upgrade 1-3 min, meaningful upgrade 5-15 min, neighbourhood gate 15-45 min. **No repair or maintenance sinks**; damage only lowers payout.
- **Products (build order: a small store first, then measure, then add):**
  1. **Cosmetics:** crew uniforms (HumanoidDescription layer over the player's avatar), truck paint, strap and dolly trails, emotes, face-sticker packs for your Trophy Shelf.
  2. A **door-opener pass under 100 Robux** (for example "Gold Dolly" cosmetic plus a cosmetic truck horn). No gameplay power.
  3. **"Crew Boost: this server"** developer product (+Pay for everyone in the server, timer extends on stacking, labelled "this server").
  4. **Cheap private servers.** Choose the price once: **changing it cancels every subscription** [Docs]. Roblox Plus subscribers get paid private servers free. We earn up to 100 Robux per subscriber, based on their time in our paid private servers (the facts file: counts among a subscriber's top 5 paid servers with 60+ min in 30 days, evaluated per renewal) [Docs].
  5. A **starter pack**, once per player, offered **after the first completed job, never on join**.
  6. Rewarded video, once eligible. The game needs 2,000+ unique monthly visitors, a public game with **no free-form user creation**, and a questionnaire **reviewed and approved**; the creator needs ID verification and 2SV. It is a deterministic "double this job's pay", capped 5-10 per day, with damage paused while it plays.
     - Flow [Docs, *Ads and Rewarded Video*]: the client checks `AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)`; the server calls `AdService:CreateAdRewardFromDevProductId(id)` then `AdService:ShowRewardedVideoAdAsync(player, reward)`. The method is **not** `ShowRewardedVideoAsync`, and `ShowVideoAd` is deprecated.
     - **The reward is granted only in `ProcessReceipt`** for that developer product, never after the show call returns.
     - Resubmitting the questionnaire removes ads eligibility while it is in review.
  7. Extra save or truck-paint slots (capacity and convenience).
- **Hard rules:**
  - No paid power over others, no paid roles, **no paid randomness** (this sidesteps the odds and PolicyService burden entirely).
  - **No revive prompts during night or chase.**
  - No purchase pop-ups during onboarding or on death screens, and at most one unprompted offer in a non-payer's first session.
  - Pop-up gate: not in onboarding, an open panel, a cutscene, death or combat, and not within 8 s of another pop-up.
  - Prices always from `GetProductInfoAsync`.
  - Exactly one `ProcessReceipt` (library `Receipts`), idempotent on `PurchaseId`, saved before `PurchaseGranted`.
  - Apply the "parent test".
- **Price ladder [RoT]:** impulse under 100, core 150-600, premium 700-1,500, prices ending in 9. Plan on **70% of list price** as income [Docs].
- **Regional pricing** has been on by default for **passes** since 2026-03-30 (opt out per pass); developer products are opt-in. Players in other regions see different numbers, so the UI must show the price from `GetProductInfoAsync`, never a hard-coded "99" [Docs]. Plus members also get a Roblox-funded 10-20% discount on the price they see; our earnings are unchanged [Docs].

### 3.10 Names, icon and thumbnails
- **Store title candidates** (verb + noun, per *Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks*): **Catch The Couch** (preferred), Haul The Haunted, Pack It Before Dark, Couch Catchers. Brand slot: **Feral Furniture Co.**
  - Keep a fixed brand plus one changing tag slot, with a dated log.
  - No "x2", "FREE" or "OP" in titles. No "Blox"-style names (banned for games created after 2022-06-22).
  - **Before committing:** search Roblox for "living furniture", "moving" and "couch" titles (*Competitor Analysis Method*), and check trademarks.
  - The description's first two lines say what you do: verb, subject, fantasy, social hook, plus a "NEW:" line.
- **Icon:**
  - A tight crop of **one grumpy armchair or couch face** with a single bright highlight in its eyes, on a distinct hue (mustard or teal, away from the dark horror crowd).
  - Readable at 50-64 px, passes the greyscale test, no text.
  - "8 of 10 icons are a face" (*Cross-Game Patterns*). At least 512x512, tested at about 150 px beside about 10 competitor icons.
  - Human-authored or substantially human-edited, since copyright needs human authorship (*Who Owns AI-Generated Code and Assets*).
- **Thumbnails** (16:9, 1920x1080, under 3 MB; 2-5 active for personalisation; **custom thumbnails are required for Home eligibility since 2026-10-19** [Docs]):
  - **A: "Small avatar, huge thing".** Tiny movers lassoing a huge angry wardrobe on a diagonal, with the truck in the background (danger and goal in one frame).
  - **B: Funny-scary dusk.** Glowing eyes in every window, the crew sprinting to the lit truck.
  - **C: Fail format.** The piano mid-tumble down the stairs with the crew ragdolling.
  - Rules for all three:
    - Real in-game captures only; AI art may be used for non-claim backgrounds at most.
    - One focal subject at 30-45% (or 40-60%) of the frame.
    - At most 3 words of text.
    - **Bottom 15-20% and corners clear.**
    - Each thumbnail sells a *different true promise*.
    - Test at 320x180 and 160x90 in a competitor row.
  - Use the funny-scary bright dialect: one accent colour, glowing eyes as the focal point (*Thumbnail Genre Patterns - What Top Games Show*).

### 3.11 Dissent and open risks (keep visible)
- **Feasibility lens (did not score D):** living furniture adds AI per archetype, which is more work than B's single threat. *Mitigation:* the MVP ships 1 living piece per house and 2-3 archetypes. Behaviours are short data-driven functions on a shared 10 Hz server brain, built on *Horror Monster Chase AI End to End* (5 states; chase speed below the unburdened player's speed, see the 5.3 speed table; catch cooldown 6 s). The feasibility lens rated A as technically safest (7.5). We reject A on virality and retention grounds.
- **Virality lens:** googly-eye or living-object faces can look like generic AI slop. *Mitigation:* one human art owner, 3-4 hand-tuned expressions per archetype, the style bible, and the 8.5 blind panel on faces.
- **Retention lens:** a numbers-only meta fades. *Mitigation:* the Dex, neighbourhoods and weekly new verbs.
- **Originality:** TikTok will still say "Roblox R.E.P.O." or "Moving Out". The visible living-furniture twist and the catch verb must lead every clip and thumbnail.
- **The two-person carry is unsolved in the vault** (there is no recipe for two players carrying one physics object). It is the #1 prototype risk; if it feels bad on mobile, D1 dies. Prototype it alone in week 1, with the server-owned plus capped-movers design and a fallback "attach-and-follow" carry with server-validated distance.
- **Audience gate:** a new game is 16+ only until it passes evaluation. The vault cites "250 plays by highly engaged age-checked users in 60 days" in one place and "500 Highly Engaged Players" in another; **trust the Audience Reach dashboard**. Plan for creator verification, 2SV, and either 2 months of Plus or the roughly 1,000 Robux refundable fee.
- **The council and panel are the same model family.** Real playtests (5 outsiders × 10 min, at least 3 wanting to continue) override every score here.

---

## 4. Algorithm and virality playbook (Roblox discovery 2026 plus TikTok)

### 4.1 How Roblox ranks you now
*Discovery and Monetization Changes 2025-2026*, *Discovery and the Algorithm*, trend research.

| Signal | Weight | Detail | Label |
|---|---|---|---|
| **Play-through rate** | "Most important" | Impressions → plays. Driven by thumbnail and icon. It **replaced qualified PTR** on 2026-06-15. The thumbnail dashboard still shows a "qPTR" column: use it only to compare thumbnails. | [Docs] |
| **First-play bounce rate** | Most important | Sessions **under 60 s** and **61-180 s** count against you. "The most controllable signal." | [Docs] |
| Play days per user | Most important | Measured over **D1, D2-7 and D8-28**. The window grew from 7 to 28 days. | [Docs] |
| Playtime per user | Most important | **Capped at 60 min/user/game/day.** AFK time beyond that doesn't help. | [Docs] |
| **Intentional co-play days** | Important | Invites, joins, private and reserved servers. Matchmaking does **not** count. | [Docs] |
| Qualified sessions, spend days, Robux per user | Important | Many small purchases beat one big one. Since 2026-08-20 Home rewards games that are strong in **both** retention and monetisation. | [Docs] |

- **Only organic RFY joiners count.** Signals are per-user averages, so a small game with strong numbers can be recommended. Ads, search, friend joins, share links and TikTok traffic **do not** feed ranking, though they "accelerate consideration" [Docs].
- Near-duplicate metadata or place files are deprioritised. Misleading thumbnails and giveaway titles are penalised. Bot engagement is excluded [Docs].
- More than 90% of traffic starts on Home, and Saturdays peak [Reported/Docs via trend research]. An April 2026 test cut some games' Home impressions by 70-80% [Reported].
- Analytics for Home, Search and Charts changed on 2026-10-12, so comparisons across that date are not like-for-like [Docs].
- **CCU identity** [RoT arithmetic]: average CCU = sessions/day × average session minutes / 1,440, and peak is 1.5-2.5x average. In the vault's sensitivity example, +50% impressions gave +37% CCU, session length 16→20 min gave +25%, and D8-30 return 5%→8% gave +22%. "CTR fills the funnel; retention widens it."
- **Order of attack once the thumbnail is fine** [RoT]:
  1. First-play bounce in the first 0-180 s.
  2. Delivering the promise in the first minutes.
  3. Reasons to return in D2-7 and D8-28.
  4. 30-60 focused minutes a day.
  5. Co-play.
  6. Kind monetisation.
  7. Filling servers at low CCU.
- **Diagnosis** [Docs/RoT]:

  | What fell | Likely cause |
  |---|---|
  | Impressions | Per-user signals fell |
  | PTR | Thumbnail |
  | D1 | First session |
  | D7 | A mid-game wall |

  Annotate every release date.

### 4.2 The under-16 gate and publishing (as of October 2026)
- **New games reach only age-checked 16+ players** until they pass the Kids/Select evaluation [Docs]. The threshold appears as "250 plays by highly engaged age-checked users in 60 days" or "500 Highly Engaged Players", depending on the source; trust the Audience Reach dashboard. A highly engaged player has account tenure, playtime and a purchase anywhere on Roblox in the last 60 days.
- All-ages reach requires:
  - creator ID/age verification and 2SV;
  - 2 months of Plus/Premium **or** a refundable fee of about 1,000 Robux;
  - the full maturity questionnaire;
  - a Minimal/Mild label (Kids, 5-8) or up to Moderate (Select, 9-15).

  **A game with no questionnaire is unplayable.** Strong violence or realistic blood means 18+. Crude humour beyond Mild excludes Kids. Fear content (jump scares) is answered separately [Docs]. Resubmit after content changes; resubmitting pauses ads eligibility.
- The Ads Manager "Engagement" objective helps clear the cold start. **Ads never raise RFY ranking** [Docs].
- Soft launch: the game can be public but **excluded from RFY** (Audience > Advanced) [Docs].
- Limits: 5 never-released games per day per creator; 100 MB per place [Docs].
- Chat requires a facial age check and is age-banded (since January 2026). Voice requires 13+ and age verification, defaults to proximity, and **doesn't work in places with max players above 100** [Docs].
- No external links or handles inside the game (January 2026). Game-page Social Links are visible only to age-checked 16+ (since 2026-06-30) [Docs].

### 4.3 Launch bars before opening RFY (*Launch Strategy - The First Two Weeks*, [RoT])

| Metric | Bar | Fix if |
|---|---|---|
| First reward within 60 s | 85%+ of new players | <70% |
| Biggest single funnel drop in the first 3 min | <15% | >25% |
| Median first session | 10+ min | <5 min |
| Join → control | ≤10 s on a mid-range phone (the reference project capped loading at 12 s) | |
| Per-step retention in early onboarding | ≥90% | |
| Tutorial completion | ≥70% | |
| D1 | Near the genre benchmark. Vendor benchmarks D1 20/30/40% = good/great/excellent and D7 8/15/20% are **[Unverified]**; the docs give no official benchmark. **Set targets from our own soft launch.** If D1 < ~20%, fix onboarding before adding content. | |

- Below about 300 players per cohort, D1 differences of a few points are noise.
- Benchmark scorecards and the Performance dashboard need 100+ DAU.
- Launch-day prerequisites:
  - an outsider plays the whole first session on a mid phone;
  - join time is measured;
  - the funnel logs from join to minute 10;
  - saves survive a forced shutdown;
  - 2-5 thumbnails, an icon tested at about 150 px, live config with kill switches, one upcoming Experience Event, one share link per channel.
- **Day 0:** release on a weekday morning, not a Friday evening (*Launch Strategy*). Do the RFY opening and big content drops at a fixed Friday/Saturday time (*Update Cadence and Hype Cycles*). These notes conflict with the trend skill's "Saturday launch"; we resolve it as **soft launch Tue-Wed, open RFY and the TikTok push Fri-Sat** [Inference]. Be online for 48 hours afterwards.
- **Day-7 branch decision:** Healthy / Leaky start / Weak promise / No pull. Fix crashes on days 1-2 and the biggest funnel leak on days 3-5.

### 4.4 TikTok and short-form playbook (*Short-Form Video Marketing*, *Game Trailers and Clean Footage*)
- **Clip structure** [RoT]:

  | Time | Content |
  |---|---|
  | 0-2 s | **Hook**, with no logo or title card |
  | 2-6 s | Context line |
  | 6-15 s | Payoff |
  | End | Loop, or "Play: Catch The Couch on Roblox" |

  Default length 15-30 s. Vertical 9:16 at 1080x1920. Keep text in the middle 70% of height and out of the right 15% (app UI).
- **Best formats:** fail/chaos ("physics going wild on a group"), reveal (a new feral item), before/after (empty truck → stuffed truck), challenge ("today's Featured House"), devlog. **Poor fit:** fun that takes 10 minutes to arrive, or a broken first session.
- **Filmability features** (ship at launch):
  - A **capture place**: a copy of the game with labelled debug flags, never shipped, with free camera and identical lighting.
  - A **hide-HUD toggle**.
  - Built-in **freecam**: owners and editors film live servers with Left Shift+P, and Ctrl+Shift+N hides nameplates [Docs].
  - **Photo mode** via `CaptureService`: `CaptureScreenshot` → `PromptShareCapture(capture, launchData)`, so viewers who join can be routed to the right place. It is client-only; never auto-prompt it.
  - A server feed of "epic fail" moments.
- **Cadence** [RoT]: 3-5 clips a week from playtests, one clip per live update, one devlog a month.
- **Share links** (Creator Dashboard, unlimited): one per channel and campaign. Their `LaunchData` may carry only a public-safe welcome perk, never anything valuable or stackable. **Log the join source as a funnel field and judge clips by D1 per link**, not by views.
- **Creator Rewards: Audience Expansion** [Docs]. We get 35% of a new or reactivated user's first $100 of purchases anywhere on Roblox in their first 60 days, if they:
  - arrive via our share link, direct link or a name search;
  - play 10+ min that day.

  Our game must average 100+ DAU for the following 60 days, and the owner must be ID-verified. There is a 60-day hold. Viral TikTok traffic through share links can therefore earn money even from non-buyers in our game.
- **Daily Engagement** [Docs]: 5 Robux/day per Active Spender (≥$9.99 spent in 60 days) who plays 10+ min with our game among their **first three launched that day**. This rewards a daily first-launch habit, which the daily Featured House supports.
- **Child-safety lines:**
  - No other players' names or voices in clips without consent (hide nameplates).
  - No external links in the game, so codes go in captions and update notes.
  - Paid creator promos disclosed in kid-friendly words ("I get paid when you use my code").
  - Never "free Robux".
  - Ads now reach all users (since 2026-04-30); assume under-13 viewers.
- **Music:** use only owned or commissioned music for TikTok and trailers. Whether the Roblox library licence covers off-platform use is **[Unverified]**. Add a streamer mode that swaps the music.
- **Peaks fall 90% or more** [Measured on trend hits]. Plan for the floor plus weekly bumps. "Games that stop updating decline within weeks" [Reported, RoWatcher].

### 4.5 Storefront specs [Docs]
- Icon at least 512x512, shown at about 150x150, one per locale.
- Thumbnails 16:9 at 1920x1080 and under 3 MB, up to 10 on the details page, 2-5 active on Home. Personalisation is a multi-armed bandit re-weighted hourly; it averaged **+8.5%**, up to +50%, but games under about 1,000 DAU may see little signal.
- Video thumbnails:
  - 3 uploads a month, and rejections count.
  - Real gameplay only: no narration, no voice chat, no music with lyrics, no "enhanced graphics".
- Thumbnail A/B sample size ≈ `16p(1−p)/d²` impressions per variant (at a 4% baseline, +25% relative needs about 6,100). Run 7-14 days, avoiding update days. Small games can only detect bold changes. Don't delete the "losers", since they may win a segment.
- Search is semantic, so keyword stuffing doesn't help. Description = verb + subject + fantasy + social hook.

### 4.6 Live-ops rhythm sized for a tiny team (*Event Calendars and Content Planning*, *Update Cadence and Hype Cycles*)
- **Weekly:** a new feral item **or** a rotation, plus a weekend 2x-Pay event via Configs (multiplier events last 2-3 days).
- **Every 2-3 weeks:** a content update (new neighbourhood or tool) containing **one new goal for existing players and one fix for new players**, with a new thumbnail, a code and an Experience Event. Each update needs **a reason to bring a friend**.
- **Seasonal:** every 2-3 months.
- Keep **one buffer week a month**. Maintenance eats 30-40% of throughput on 1-4-person teams. Allow at most one mechanic event a month and one headline event at a time. No big publish in an event's first 48 h. Feature freeze at T-10 days, event public at T-7.
- **Experience Events:** up to 10. An event with **1,000+ RSVPs** that started within the last 7 days can reach the Trending Events sort. Submit 7+ days ahead for featuring.
- **Notifications:**
  - Eligible from 100+ visits; strings of at most 99 characters; 1 per user per day; opted-in users 13+ only.
  - Call `PromptOptIn()` right after a delayed payoff ("Truck upgrade ready in 4 h"), never on join. It shows at most once per 30 days.
- **Update announcements:** 60 characters, at most once every 3 days.
- **Battle pass:** not until players return several days a week; not in the first month; not below a few hundred DAU.
- Ship features dark behind Configs flags: release flags default off, kill switches default on.
- When updating, use "Restart outdated servers" with a 10-15 min delay, and drain on `ServerRestartScheduled` (finish the job, start no new one, save early).

---

## 5. Technical architecture

### 5.1 Project structure (Rojo; *AI-Ready Project Boilerplate*, *Project Structure and Bootstrapping*)
```
catch-the-couch/
  CLAUDE.md                 # <200 lines: commands, layout, rules, vault lookup, session protocol
  PROJECT_STATE.md          # <150 lines: identity, works (how verified), in progress, broken, decisions, do-not-touch
  handoffs/YYYY-MM-DD-topic.md
  docs/GAME_BIBLE.md  ARCHITECTURE.md (services + remote manifest)  DECISIONS.md  STYLE_BIBLE.md  OWNERS.md
  default.project.json      # maps code containers ONLY, $ignoreUnknownInstances: true; servePlaceIds = dev place
  test.project.json         # adds qa/ specs
  rokit.toml wally.toml selene.toml stylua.toml .gitattributes (LF)
  tools/check.sh            # stylua --check, selene, luau-lsp analyze, rojo build, lune unit tests
  src/
    server/Main.server.luau             # the ONLY server Script (two-phase: init no-yield, start may yield)
    server/Services/  JobService (phase machine)  HouseService (spawn/cleanup)  FurnitureService (tags, anchor/unanchor)
                      CarryService (grab/release/lift tiers, ownership)  LivingService (AI brain 10 Hz)
                      DeliveryService (truck zone, PACKED)  DamageService (delta-v)  DownedService (rug revive)
                      PayoutService  ProgressionService (Dex, unlocks, Stars)  PartyService  FunnelService  TuningService (Configs)
    server/Remotes/   # thin handlers via lihfolk Net.Handle
    server/LihFolk/   # installed library: PlayerData Policy Currency Receipts Shop DailyRewards Quests Codes (+Leaderboard later)
    client/Main.client.luau             # the ONLY client entry
    client/Controllers/ CarryController  CameraController  RagdollController  HUDController  PingController
                        FurnitureFXController (faces, wobble, squash, blob shadows)  LightingController (sole Lighting owner)
                        AudioController  TutorialController  SettingsController
    shared/Config/    Furniture.luau (archetype rows)  Jobs.luau  Economy.luau  Tuning.luau  Neighbourhoods.luau  # data only
    shared/           Types.luau  Tags.luau (frozen registry)  Formulas.luau (pure, testable: quota, payout, scaling)
  qa/                 # specs + numeric harnesses (clone-require)
  blender/            # generator scripts, palette.png source, golden assets, gate reports
```
- **The map is built in Studio, and code lives in files.** Rojo must never own Workspace. A Rojo `$path` on Workspace without `$ignoreUnknownInstances` deletes a hand-built map [Measured].
- Use the same feature name in every layer: `CarryService` / `CarryController` / `Remotes/Carry` / `Config/Furniture`. No `_old` modules.
- Use `--!strict` everywhere and modern APIs only: `task.*`, `Animator:LoadAnimation`, `LinearVelocity`/Align*, `PreSimulation`, `FontFace`, the Async-renamed methods (2026-01-14). No `wait`, `spawn`, `tick()`, `Humanoid:LoadAnimation`, `Body*` movers or `Lighting.Technology`. The full list for this project is in **5.9**.
- **No scripts inside Workspace models.** Tag the models instead (`Carryable`, `Living`, `TruckBed`, `HouseRoot`) and drive them from one module per tag. Set attributes **first** and the tag **last**. Tag the model, not its parts.
- **Houses:** templates live in **ServerStorage**. On job start, *move* (don't clone into ReplicatedStorage) one house Model into Workspace (`ModelStreamingMode = Atomic`). At job end, **Destroy the whole job folder** so memory stays flat over 50 jobs (*Teardown - Natural Disaster Survival*).
- **Keep ReplicatedStorage tiny:** every instance in it downloads before `game.Loaded` [Measured: 100k+ instances made joins slow].
- **Streaming** (a human sets these in Studio; they can't be scripted): StreamingEnabled on, `StreamingMinRadius` 64-256 (the reference project used 256), TargetRadius 1024, `StreamOutBehavior = Opportunistic`, `ModelStreamingBehavior = Improved`, `StreamingIntegrityMode = PauseOutsideLoadedArea` (or MinimumRadiusPause). Never call `WaitForChild` without a timeout. Use CollectionService added and removed signals.
- **Avatar Settings** (Studio File menu): **constrain body scale and accessory bounds, or use Single Collider**, so doorways and carrying behave the same for every avatar. Write the settings down in DECISIONS.md. R15 only (all built-in systems assume it). R15 also unlocks the US 18+ DevEx rate.

### 5.2 Client/server split (*Client-Server Model* decision table)

| Server owns | Client owns |
|---|---|
| Job phase and end times (attributes on ReplicatedStorage, absolute `GetServerTimeNow()` ends), quota, House Awake meter, payouts, Dex, currency | Input (Input Action System; every action bound for touch, gamepad and keyboard), camera, HUD, VFX, SFX, Lighting (one LightingController), faces, wobble, squash |
| Living-furniture AI decisions, heavy and living item physics, delivery and damage judgement, LifeState, downed/revive | Light-item physics for the current carrier, its own character, ragdoll *application* (from a server decision), IK hands |
| Validation of every remote, ownership assignment, velocity watchdog | Prediction: grab feedback on the first frame (outline, click, squash) before the server confirms |

- **State goes through attributes, moments through remotes.** Late joiners get attributes for free. A countdown is one attribute (`PhaseEndsAt`), never a remote per second. Never use attributes for moments, because two events in one frame collapse into one.
- One shared loop over the active set, never a Heartbeat per object. AI runs at 5-10 Hz staggered, line of sight at 2-10 Hz, UI updates on change only.
- Every system needs a **join snapshot** plus deltas. "The late joiner is the most common real bug" (*Multi-Client and Live Testing*).

### 5.3 Networking of physics: carry, living furniture, ragdoll (the riskiest system)

**Ground truth** [Docs]:
- Ownership is per assembly.
- Anchored parts are always server-owned.
- Auto ownership goes to the nearby client, which causes **ping-pong stutter** and lets exploiters fling.
- An owning client "can move it anywhere".
- Server ownership "may result in jittery physics interactions for clients".
- `SetNetworkOwner` only works after parenting to Workspace and on unanchored roots. Re-assert ownership after **every** weld, anchor or ragdoll change. No event fires when ownership changes, so you have to poll.
- A server `ApplyImpulse` or `ChangeState` on a player's character arrives late or is ignored, so send it to the owner.
- In the June 2026 physics replication rewrite, if unexplained desync appears, test `Workspace.ImprovedPhysicsReplication = Disabled` first [Docs/Reported].

**Furniture assembly design** [Measured pattern + Inference]:
- One root collider of **invisible Box parts** (CollisionFidelity Box/Hull, never Precise) with a **massless, non-colliding visual MeshPart** welded on. This is the cheapest physics, and squash or wobble can play on the visual without changing collision (*Squash Stretch and Anticipation*).
- Furniture is **anchored until grabbed** and **re-anchored when delivered or settled** (asleep for more than about 1 s), so sleeping props cost nothing.
- Collision groups (on `workspace` since September 2026; at most 32): `Characters`, `Furniture`, `Living`, `Debris` (never collides with characters), `TruckBed`, `PlayerOnlyWalls`. Register them once at start.
- `Massless`/`RootPriority` rules apply: a large prop welded to a character steals the root. We **don't weld** carried furniture.

**Carry tiers:**

| Tier | Examples | Owner while carried | Mover | Notes |
|---|---|---|---|---|
| **Light** (one carrier) | Lamp (inert), box, chair, **rug-burrito**, and a *caught* small living piece (footstool) while its brain is suspended | **Carrier client** (`SetNetworkOwner(carrier)` on grab) | `AlignPosition` + `AlignOrientation` (OneAttachment) on the prop, targeting a hold point in front of the HRP. Responsiveness 30-60, `MaxForce = mass × accel`, `MaxVelocity` capped, **never `RigidityEnabled`** | Responsive. Bumping door frames is the comedy. The server checks distance at release and delivery. Throw velocity is clamped on the server and applied by the owner. |
| **Heavy** (needs 2+; solo with dolly at half speed) | Piano, sofa, fridge, wardrobe (inert variant) | **Server** (`SetNetworkOwner(nil)`) | Server `AlignPosition`/`AlignOrientation` pulling toward the **midpoint of the active handles**. Each carrier contributes a force budget; if the total is below the mass × g × k threshold it only drags | This is the documented crate fix applied to carrying (the worked example was pushing: 0 of 20 flings). The cost is that it feels "slightly less responsive at high ping". Mitigate with client-side visual smoothing of the mesh, and tune it on real phones. |
| **Living** (any size, brain active) | Footstool, wardrobe, lamp (live) | **Server, whenever the brain is active** | A server brain (5-10 Hz, within 200 studs, staggered) drives **one** mover (an AlignPosition goal) for "hops", with impulses applied by the server on the server-owned assembly | Heavy living pieces (wardrobe) stay server-owned while carried; the server jitters the carry goal so they struggle, and strapped pieces struggle less. Poltergeist effects (doors slamming, lights, idle furniture sliding) act **only on anchored or server-owned objects**. |

**Living-piece ownership handoff** [Inference; the vault has no recipe for this]:
- A *caught* small living piece goes to state `Caught`. The brain is **suspended**: it writes no forces and its mover is disabled. Then `SetNetworkOwner(carrier)`, and it is carried like any light item.
- Its struggle while carried is **cosmetic**: wobble and squash on the visual mesh, and squeaks.
- An escape is a server-decided roll (rising with carry time and drops). On escape the server **first** calls `SetNetworkOwner(nil)` and re-enables the brain, **then** applies the hop. The server never applies a force to a client-owned assembly.
- This keeps the tutorial footstool's first grab responsive. A first grab that lags on a phone at 150 ms would cost D1.

**One mover per assembly, across services:** CarryService and LivingService must never both drive the same assembly. The state attributes (`LivingState`, `CarryOwnerId`; attribute names allow only letters, digits and underscores) decide which service owns the mover. On every handoff, disable the old mover before enabling the new one, and re-assert network ownership.

**Straps and lassos:** never put a `RopeConstraint` between a client-owned character and a server-owned piece of furniture. A rope between two owners "fights across the network" (*Ropes Chains and Soft Bodies*: both ends must be owned by the same machine). The strap is a visual `Beam` between attachments; the pull is a server-validated distance rule plus the client-side drag below.

- **Carrier constraints:**
  - The carrier gets a `Carrying` speed multiplier in the one speed stack, never a direct WalkSpeed write.
  - Auto-release if the carrier drifts more than about 8-10 studs from their handle (ping-scaled; tune it).
  - A max carry time is not needed for objects, but **release must run on every exit path**: drop, death, leave, downed, phase change, stream-out, menu, focus loss. Guard it with a `released` flag.
  - Hold/Toggle carry option, force-released on death, menu or focus loss.
- **Two-person lift UX:** the "LIFT TOGETHER" auto-prompt; each handle is a ProximityPrompt on an Attachment (remap the gamepad key off ButtonX, short HoldDuration, `RequiresLineOfSight` off on enclosed parts).
- **The dragged-by-strap clip** [Inference, prototype]: when a strapped living piece breaks free, the holder gets a `DraggedUntil` server timestamp (2-3 s cap). On their own client, their character is pulled by AlignPosition toward a point behind the replicated furniture in a ragdoll-ish pose. Mash to escape (about 15 presses per second accepted, progress decays). Exempt it from movement checks. **If it feels bad, cut it** and keep a plain stumble.
- **Delivery:** the server polls a `GetPartBoundsInBox` truck-bed zone at 5-10 Hz (never `Touched`). The item's root must be inside the bed, not carried, below a speed threshold, and the item not already delivered. Then the server anchors it, parents it to `TruckCargo` and pays out (idempotent per item id).
- **Damage:** the server samples velocity deltas and uses **squared delta-v**, so small bumps are cheap and big drops count (reuse *Vehicle Damage, Repair and Wreck States*). Each item gets a `DamageImmuneUntil` after server teleports. Cosmetic breaks are client-only swaps with pooled debris.
- **Guards from day 1:**
  - A `WatchOwner` CollectionService tag polled every 0.25 s in Studio.
  - A velocity watchdog flagging more than 300 studs/s.
  - Flag `AssemblyLinearVelocity` above about 500 studs/s or angular velocity above about 100 rad/s live, then reset and log, **never ban**.
  - Per-player prop cap. NaN guards on every vector.
  - The Studio "Network owners" visualisation in 2-4-client tests at the **Standard Mobile** (45/20 ms) and **Bad 3G** (150/70 ms) Network Simulator presets.
- **Truck:** parked and anchored for the MVP. It is home base, quota display, safe light radius and exit in one. If driving is added later:
  - The driver owns it while seated (set on the `Occupant` change); the server owns it when empty.
  - One VehicleSeat; passengers **seated** while it moves (no walking on decks moving faster than about 30 studs/s).
  - Cargo welded and anchored on "secure".
  - Raycast chassis, auto-accelerate option, hold-to-exit, flip recovery.

  "Custom vehicles" is explicitly outside a 30-day solo scope (*Ship a Game in 30 Days*).

**Ragdoll (players)** (*Snippets - Ragdoll*, *Ragdolls and Physics-Based Animation*, *AnimationConstraint and Physically Simulated Characters*):
- **The server decides, the owning client applies.** The server sets `RagdollUntil` (a server-time attribute) and fires the owner. The owner calls `ChangeState(Physics)`, stops tracks, and calls `Animator:ApplyJointVelocities(joints)` and the impulse. `SetStateEnabled` does not replicate, so call it on the owning client too.
- Building the sockets and disabling the joints happens on the server.
- `BreakJointsOnDeath = false`, and `RequiresNeck = false` **before** touching the neck (otherwise instant death).
- BallSocket/Hinge on dedicated attachments, `NoCollisionConstraint` between neighbouring limbs, HRP `CanCollide = false`.
- **Avatar Joint Upgrade:** R15 joints are now `AnimationConstraint`. Phase 3 forced migration is targeted for the end of 2026, so code must accept `AnimationConstraint`, `Motor6D` and `Bone`, and never write `C0`.
- **Duration 1-2 s**, then get up once the pelvis is below 2 studs/s for 0.3 s, blending over 0.2-0.3 s.
- Cap simultaneous ragdolls per client and stagger their starts. One R15 ragdoll is about 15 parts plus 14 constraints, and a crowd ragdolling at once can drop a low-end phone under 30 fps.
- **Respawn and stuck watchdog:** for 4 s after spawn, clear PlatformStand/Sit/Physics and force GettingUp [Measured fix]. Add a client stuck detector for sustained input with no movement, re-checked by the server.
- Low-end fallback: a short stagger animation instead of a full ragdoll.
- Ragdolls must be on the movement-check exemption list, along with knockback, drags and server teleports.
- Optional "heavy arms" while carrying: AnimationConstraint `IsKinematic = false` on the arms with strength 0.2-0.4, Root and Waist kinematic [RoT]. It is funny, but tune it in Play, because the Animation Editor can't preview it.

**Living-furniture AI** (adapted from *Horror Monster Chase AI End to End*, [Docs + RoT]):
- Server-owned (`SetNetworkOwner(nil)` after spawn), with an AnimationController or plain movers, **no Humanoid** (Humanoids are expensive).
- States: Sleep / Skittish (flee) / Hide / Caught / Feral-Chase / Search / Return.
- **Feral chase speed stays below the speed of an unburdened player.** The reference build uses patrol 8, investigate 11, chase 15 and search 9 studs/s, but it **assumes walk 12 and sprint 18 with stamina** [RoT]. In that design the monster is faster than walking and slower than sprinting. Our game has no sprint in the MVP, so it needs its own table. Lose sight for 4 s → Search; search for 8 s → Return.

**Movement speed table** [Inference; tune in group playtests; all values in `Config/Tuning.luau`]:

| Who | Speed (studs/s) | Notes |
|---|---|---|
| Player, unburdened | 16 | Roblox default `WalkSpeed` [Docs]. **No sprint or stamina in the MVP** (touch players would auto-sprint anyway, per 7.2) |
| Player, light carry | ~13 (0.8x) | `Carrying` multiplier in the one speed stack |
| Player, heavy carry (2+) / dolly solo | ~9-10 (0.6x) / ~8 (0.5x) | Slow enough that stairs and doors are the drama |
| Day skittish flee | 12-14 | Catchable by cornering, never by straight pursuit |
| Night feral chase | 13-14 | Below an unburdened player, but above a carrier. The choice "drop it and run, or risk a nip" is the night tension. A nip is a stumble, never a down |
| Search / patrol | 8-9 | |

If a sprint is added later, re-derive this table from the reference build's 12/18 split.
- Senses at 5 Hz. Hearing is inferred on the server from replicated root velocity, plus the House Awake meter. **No client noise remotes.**
- Target stickiness 0.6. Use direct `MoveTo` or Align within 20 studs with line of sight, otherwise a path (repath at most 2/s, and only if the goal moved more than 4 studs). Doors use `PathfindingModifier` PassThrough.
- **Catch/nip cooldown 6 s per target**, so one piece can't chain-down a crew.
- Telegraph every attack by **≥0.45-0.5 s** (sound, colour and pose) and lock facing at the telegraph.
- Mix hearing with sight so the threat doesn't just punish the nearest or bravest player. Recover from stuck states only while unseen (blink).
- Variants are different `canSee`/speed rules, not new state machines. The wardrobe moves only when unseen; the lamp is light-sensitive.
- Night pacing via a light director (credit budget, build/peak/relax, relax cuts earning for 15-40 s), with **sub-linear player scaling** (*Spawn Director*).

### 5.4 Data and persistence
- **Use lihfolk-systems `PlayerData`:**
  - 90 s lease renewed with a token-fenced `UpdateAsync`.
  - `ready`/`locked`/`failed`/`corrupt`/`newer` are distinct, and **only `ready` can save**.
  - 30 s dirty-gated autosave, staggered.
  - Parallel `BindToClose` with a 26 s deadline.
  - Studio uses `<store>_STUDIO`, and `TestProfileKey` avoids the 90 s lease trap.
  - Alternative: ProfileStore (loleris). Don't use ProfileService or DataStore2.
- **Profile schema v1** (sketch):
  ```lua
  { Schema = 1, Pay = 0, Stars = 0,
    Dex = { [archetypeId] = { caught = 0, variants = { [variantId] = true } } },
    Unlocks = { neighbourhoods = {"suburb"}, tools = {} }, Cosmetics = { owned = {}, equipped = {} },
    Stats = { jobs = 0, bestStreak = 0, pianosDelivered = 0 }, Onboard = { step = 0 },   -- per-step, not one flag
    Daily = { lastDay = 0, streak = 0 }, Quests = {...}, Settings = { overridesOnly },
    Purchases = { [PurchaseId] = true } }  -- receipt ids live in the SAME document as the grant
  ```
- **Rules:**
  - Integer currency.
  - **A failed load never saves.**
  - Never save Vector3 or CFrame (error 104).
  - Migrations run on every load forever; never edit a shipped migration; old servers refuse newer schemas.
  - Coins and job pay change memory only. Save at checkpoints (job payout, purchase) plus autosave.
  - Settings are saved only as overrides, sanitised on the server (FOV 9e9 or NaN must be rejected).
- **DataStore limits** [Docs, Oct 2026; `_data/roblox_facts_2026.json`]:
  - 4 MB per key (4,194,304 characters of serialised JSON). Key and store names are 50 characters or fewer.
  - **Per-key throughput:** 4 MB/min write and 25 MB/min read. This replaces the old "one write per key every 6 s" rule, which AI models still quote.
  - **Experience-wide budgets** (shared by all servers **and** Open Cloud since 2026-07-29; this is now the binding limit): read 300 + 40×CCU, write 300 + 20×CCU, list 300 + 2×CCU. `UpdateAsync` costs 1 read + 1 write. Older Extended Services tables show a 250 base, which *Open Questions* resolves as the pre-July figure. The facts file still says "design for the lower figure", so budget against 250.
  - Per-server defaults are 60 + 40×players reads/writes per minute. They are configurable with `SetRateLimitForRequestType` and are no longer the binding constraint.
  - Request queue of 30. `GetAsync` results are cached for 4 s (bypass with `DataStoreGetOptions.UseCache = false`).
  - Storage: 500 MB + 1 MB per lifetime player per experience (since 2026-07-29; it was 100 MB).
  - A version is kept for the first write per key per UTC hour, for 30 days.
- **Purchases:** library `Receipts` is the **only** ProcessReceipt. It is idempotent on `PurchaseId`, grants and records in one write, returns `PurchaseGranted` only after the save, and never grants in `PromptProductPurchaseFinished`. Refuse at prompt time, not in the receipt. Product id 0 means "Coming soon" and is never prompted.
- **Live config:** `ConfigService` (Roblox Configs, up to 1,000 configs, published in about 15 s to 1 min) holds quota base, phase lengths, AI speeds, payouts, event multipliers, feature flags and **kill switches** (carry tier 2, dragged state, night). Every value is validated and clamped.
- **Analytics** (server only; published games only, so Studio sends nothing):
  - Onboarding funnel via `LogOnboardingFunnelStepEvent`.
  - Economy via `LogEconomyEvent` from the wallet after commit.
  - Custom events for join timing (loaded, ready, play) and fling or stuck counts.
  - At most 3 custom fields, no user ids in fields, 100 custom event names max.

### 5.5 Security: remote manifest
Validation order for every handler: **rate → type/shape → value (finite, range, known id) → permission and ownership → context/state → plausibility (distance, ping-scaled) → lock, act with no yield → score rejections** (never kick on one).

| Remote | Dir | Payload | Server checks | Rate (burst/refill) [RoT, tune] |
|---|---|---|---|---|
| `Carry.Grab` | C→S | `itemId: string(guid)` | Item exists, is `Carryable`, not delivered, within reach (about 7-10 studs + ping slack), player alive and not downed or busy, prop cap | 4 / 2 per s |
| `Carry.Release` | C→S | `throw: boolean` | The player holds it. Throw velocity is computed on the **server** and clamped | 6 / 3 |
| `Carry.Handle` | C→S | `itemId, handleIndex: int` | Free handle, distance, heavy tier | 4 / 2 |
| `Living.Strap` | C→S | `itemId` | Distance, line of sight, strap cooldown | 3 / 1 |
| `Ping` | C→S | `index: int (1..8)`, `pos: Vector3?` (clamped) | Index whitelist, pos finite and within 200 studs | 3 / 1 (cosmetic relay; drop overflow silently) |
| `Emote` | C→S | `index` | Whitelist | 2 / 0.5 |
| `Job.Vote` | C→S | `choice: oneOf` | Phase is Results | 2 / 0.5 |
| `Settings.Set` | C→S | `key, value` | Schema type, range, step | 5 / 2 |
| Prompts: revive, unplug, lift | ProximityPrompt | n/a | `Triggered` passes the player: re-check distance, state and cooldown on the server | n/a |
| `Fx.*` | S→C | ids + seed + server time | Built by the server. Send only to players within about 250 studs. Unreliable payloads <900 bytes for cosmetics | n/a |

- **Never** use `InvokeClient`. Identity is always the injected `player`. Instances from the client may be nil or foreign, so check class, ancestry and ownership. After any yield, check `player.Parent`.
- The client→server throttle is about **500 requests/s per client, shared by all remotes of a type**, so never fire a reliable remote per frame [Docs].
- **Make cheating worthless:** a co-op PvE game needs only a cheap speed check plus rubber-banding, with honest exemptions for ragdoll, drag, knockback, seats and server teleports routed through one exemption helper. Payout is computed from server state only. Fling protection matters more than speed detection.
- **Account hygiene:**
  - The game is owned by a **Roblox group** from day one. Upload every animation, sound and mesh as the group, or they are silent or broken live.
  - The owner account uses 2SV, and daily work happens on a separate account.
  - Open Cloud keys are scoped and never in git or chat.
  - No toolbox admin scripts or unread free models.
  - `Players.BanningEnabled` set, with neutral ban messages.
- Pre-release: run `/lihfolk:audit`, a fuzz harness on our handful of remotes (NaN, inf, huge values, deep tables, wrong types, concurrent `task.spawn`), and *Threat Modeling a Roblox Game* (top-5 threats).

### 5.6 Performance budgets (phone first: a mid-range phone from about 3 years ago is the baseline)

| Budget | Value | Label |
|---|---|---|
| Frame at 60 fps | 16.7 ms: render 8-10, simulation 2-3, **client scripts 2 ms**, headroom 2-3. A steady 30 beats swinging between 60 and 25 | [RoT/Docs] |
| Server scripts | <~5 ms per heartbeat at full player count | [RoT] |
| Visible triangles on phone | 300k-600k | [RoT] |
| Per mesh | ≤20,000 tris (hard) [Docs]. Small prop 100-800, medium 800-3,000, hero 5-10k, house 13-14k across 7-8 modules [Measured] | |
| Instances per house/zone | 3k-10k (reference zone budget: 6,000 instances, 40 emitters, 12 lights) | [Measured/RoT] |
| Local lights | 8-12 visibly affecting the screen, **2-3 shadowed**, range ≤120 studs | [RoT/Docs] |
| Unanchored props awake at once | Keep it small (props anchored until grabbed). Watch `MovingPrimitivesCount`, `ContactsCount`, `PhysicsSendKbps` and `stepWorldThrottled` | [Docs] |
| Ragdolls | 1-2 s each, staggered, capped per client | [RoT] |
| Particles | Rate ≤400/s per emitter (100 on mobile) [Docs]. Live cap 900 PC / 360 touch (lihfolk-vfx) | |
| Highlights | ≤255 engine limit [Docs]. Use a few container Highlights; the reference project capped flashes at 8 | |
| Network | Low tens of kbps per player. UnreliableRemoteEvent ≤900-1,000 bytes. "50 KB/s per client" is folklore | [RoT/Docs] |
| Textures | ≤512 for most, 256 for small details, 1024 only for a shared atlas | [Docs] |
| Server memory | About 6.25 GiB + 100 MiB per player; stay under 50% | [Docs] |
| Join → control | ≤10 s on a mid phone | [RoT] |

- Use a graphics preset (Performance/Balanced/Quality, phones default to Performance), with live tier changes by frame time (drop if over 1.15x target for 2 s, raise if under 0.8x for 10 s).
- **Information never degrades; decoration does.** Telegraphs, faces' alert states and quota display are identical on every tier.
- Pool all VFX and SFX instances. Never create an instance per event.
- Device protocol: a **15-minute soak on a real phone** every release, because phones throttle after 5-10 minutes. Use the densest house with 6 players. The Device Simulator is for layout only.
- Cull client zones for interior decor only, never gameplay collision or prompts (*Client Zone Culling for Interiors and Cities*).

### 5.7 lihfolk-systems and vault code reuse map

| Need | Reuse | Status |
|---|---|---|
| Profiles, leases, saving | `PlayerData` | Install as-is |
| Remotes plus validation | `Net`, `RateLimit` (+ `Signal`, `Janitor`) | Install |
| Pay / Stars wallet | `Currency` (one wallet, logs economy events) | Install |
| Daily login reward with grace | `DailyRewards` (UTC reset) | Install (post-W2) |
| Verb quests | `Quests` (`Quests.Report(player, "deliver", "piano", 1)`) | Install (post-W2) |
| Store, passes, dev products | `Shop`, `Receipts`, `Policy` | Install before soft launch |
| Codes | `Codes` | Post-launch |
| Weekly boards (streak records) | `Leaderboard` | Optional, later |
| Paid randomness | `EggHatch`, `Odds` | **Don't use** (no paid randomness) |
| `Inventory`, `Rewards`, `Rebirth` | | Not needed in the MVP (Dex is a profile slice) |
| Job phase machine | *Round-Based Minigame Loop End to End* (attributes on ReplicatedStorage, `GetServerTimeNow` ends, maps in ServerStorage, per-round connection list) | Adapt |
| Living AI | *Horror Monster Chase AI End to End* | Adapt |
| Downed and revive | *Downed, Revive and Bleed-Out States* (LifeState, bleed loop at 2-4 Hz, hold-prompt revive) | Adapt to the rug-burrito variant |
| Pacing and scaling | *Spawn Director - Credit Budgets and Player-Count Scaling* | Adapt |
| Ragdoll | *Snippets - Ragdoll* | Adapt for the Avatar Joint Upgrade |
| Tutorial | `lihfolk-tutorial` `LihFolkTutorial.luau` | Install |
| World tools and lighting presets | `lihfolk-worldbuilding` `LihFolkWorld.luau` | Use |
| VFX telegraph, shake, hit-stop | `LihFolkVFX_Abilities` | Use after a Studio test |
| SFX buses and caps | `LihFolkSFX` | Use |
| Invites and referrals | *Friend Invites Referrals and Experience Invites* (the note's own `ReferralService` ModuleScript; it is **not** an engine service). `LaunchData` is 200 characters or fewer and is read from `GetJoinData()`, so poll it for a few seconds, not once in `PlayerAdded`. Reward on qualified arrival, never on prompt open or close | Adapt |
| House meshes | `lihfolk_house.py` (real door and window openings) | Use |

**Missing, so custom (where most of the token budget goes):** CarryService (both tiers), LivingService, DeliveryService, DamageService, DownedService (rug), JobService glue, Furniture FX. Build them with `roblox-system-builder` on top of PlayerData and Net.

### 5.8 Server Authority mode: not for the MVP
`Workspace.AuthorityMode = Server` reached full release on 2026-07-09 [Docs; some vault pages still say beta]. It forces StreamingEnabled, NGR, Input Action System player scripts, Deferred signals and fixed simulation (`RunService:BindToSimulation`, `time()` as the clock). Only 8 animation tracks can play per Animator (a known issue at release), and only the first 64 attributes per instance replicate as predicted state (names and string values 50 characters or fewer). It raises server CPU. `SetNetworkOwner` is **not** equivalent to it, because it has no latency compensation. It is aimed at competitive games. **For our co-op PvE game:** stay on the classic model with explicit ownership plus server-validated outcomes. Re-evaluate only if fling griefing in public lobbies becomes visible on TikTok.

### 5.9 API names to use (2025-2026 renames and deprecations, checked with `vault.py --api` against the 2026-10-29 snapshot)
On 2026-01-14 Roblox renamed 46 yielding methods with an `Async` suffix; `_data/roblox_facts_2026.json` lists 44 of them. The old names still run but are deprecated, and **AI models default to the old names**. The hook does not catch them (2.4). Run `vault.py --api Class.Member` on any name you are unsure of.

| Use this | Not this | Where we need it |
|---|---|---|
| `MarketplaceService:GetProductInfoAsync` | `GetProductInfo` | Shop prices (regional pricing) |
| `MarketplaceService:PlayerOwnsAssetAsync` / `UserOwnsGamePassAsync` | `PlayerOwnsAsset` | Pass checks |
| `Player:IsFriendsWithAsync` | `IsFriendsWith` | Crew bonus |
| `Player:GetFriendsOnlineAsync`, `Player:GetFriendsWhoPlayedAsync` | `GetFriendsOnline` | "Bring back your crew" panel (`GetFriendsWhoPlayedAsync` is on **Player**, not Players) |
| `Player:LoadCharacterAsync` | `LoadCharacter` | Respawn after ghost or revive, if we spawn manually |
| `Humanoid:ApplyDescriptionAsync` | `ApplyDescription` | Crew uniforms as a HumanoidDescription layer |
| `Humanoid:PlayEmoteAsync` | `PlayEmote` | Emotes |
| `BadgeService:AwardBadgeAsync` | `AwardBadge` | Ledger badges |
| `Player:IsInGroupAsync`; for ranks/roles `GroupService:GetRolesInGroupAsync` | `IsInGroup`, `GetRankInGroup`, `GetRoleInGroup` (their `...Async` versions are deprecated too, Docs September 2026) | Group perks or tester access |
| `SocialService:PromptLinkSharingAsync` (server-only) | `PromptLinkSharing` | Generated share links from a payout screen |
| `TeleportAsync` with `TeleportOptions.ReservedServerId = HttpService:GenerateGUID(false)` (generated on the server, never sent to clients) | `ReserveServer`, **`ReserveServerAsync`** (deprecated since October 2026), `TeleportPartyAsync`, `TeleportToPlaceInstance`, `TeleportToPrivateServer` | Post-MVP party/run servers |
| `Animator:LoadAnimation`, `Animator:ApplyJointVelocities` | `Humanoid:LoadAnimation` | Carry layer, ragdoll |
| `AlignPosition`, `AlignOrientation`, `LinearVelocity`, `AngularVelocity`, `VectorForce` | `BodyPosition`, `BodyGyro`, `BodyVelocity`, `BodyAngularVelocity`, `BodyForce` | All movers |
| `AssemblyLinearVelocity` / `AssemblyAngularVelocity` | `Velocity` / `RotVelocity` | Watchdog, damage |
| `Model:PivotTo` / `GetPivot` | `SetPrimaryPartCFrame` | Recover furniture, place houses |
| `workspace:Raycast` + `RaycastParams` (`Exclude`/`Include`) | `FindPartOnRay`, `Ray.new`, `Blacklist`/`Whitelist` | Line of sight, blob shadows |
| `workspace:RegisterCollisionGroup` / `CollisionGroupSetCollidable` (on WorldRoot since September 2026, at most 32 groups) | `PhysicsService:RegisterCollisionGroup` | Collision groups |
| `os.clock()` (durations), `workspace:GetServerTimeNow()` (shared times) | `tick()` | Phase clock, cooldowns |
| `Lighting.LightingStyle` + `PrioritizeLightingQuality` | `Lighting.Technology` | Lighting |
| `FontFace = Font.fromName(...)` | `Enum.Font` (Gotham now maps to Montserrat) | UI |
| `AdService:ShowRewardedVideoAdAsync` | `ShowRewardedVideoAsync` (does not exist), `ShowVideoAd` | Rewarded video |
| `MarketplaceService:PromptRobloxSubscriptionPurchase`, `Player.HasRobloxSubscription` | `PromptPremiumPurchase`, `MembershipType` checks for Plus | Any Plus perk |
| Input Action System (`InputContext`/`InputAction`/`InputBinding`) | `require(PlayerModule):GetControls()` (may break when IAS player scripts become default, early 2027) | All input |
| `TextChatService` only | Legacy Chat (removed 2025-04-30); reading `TextChatMessage.Text` in custom UI | Chat |

**Not renamed** (don't add `Async`): `WaitForChild`, `RemoteFunction:InvokeServer`, `InvokeClient` (which we never use), and `BindableFunction:Invoke`. New yielding methods will end in `Async`.

**CI grep** (from *API Renames and Deprecations 2025-2026*; put it in `tools/check.sh`; it must return nothing in our `src/`):
```
rg -n ":(AwardBadge|UserHasBadge|GetProductInfo|PlayerOwnsAsset|LoadCharacter|IsInGroup|IsFriendsWith|GetRankInGroup|GetRoleInGroup|ApplyDescription|PlayEmote|ReserveServer|ReserveServerAsync|TeleportPartyAsync|TeleportToPlaceInstance|PromptPremiumPurchase)\(" src/
rg -n "ReservedServerAccessCode|MembershipType|ChatVersion|Humanoid:LoadAnimation|BodyVelocity|BodyPosition|BodyGyro|SetPrimaryPartCFrame|FindPartOnRay|Lighting.Technology|\btick\(" src/
```

**Platform changes landing in our launch window** (we soft-launch about December 2026) [Docs unless marked]:
- **Avatar Joint Upgrade Phase 3** (forced `AnimationConstraint` migration) is targeted for the end of 2026. Ragdoll, IK and carry code must accept `AnimationConstraint`, `Motor6D` and `Bone` from day 1 (5.3).
- **IAS player scripts default** early 2027, with the property removed mid-2027. We already use IAS (7.2).
- **TextChatService**: auto opt-in February 2027, mandatory for custom chat May 2027. We have no custom chat (3.8).
- `AvatarUnificationMode` is deprecated 2026-12-01 (one vault note could not verify the date). Set avatar collision and scale only through Avatar Settings (5.1).
- **Kids/Select thresholds** changed several times in 2026, and an IARC rating move is **[Unverified]**. Re-check the Audience Reach dashboard and *Policy and Age Rules 2026* in Week 3 before submitting the questionnaire.
- Mesh streaming (`Workspace.MeshStreamingAndImprovedLods`, as the API snapshot spells it) makes `MeshPart.RenderFidelity` ignored; whether it is now on by default is **[Unverified]**. Check thin furniture features (legs, lamp necks) at 250 and 500 studs.

---

## 6. Art, world, audio, VFX and animation direction (cheap to make, not "AI slop")

### 6.1 Style choice: flat, untextured, low-poly
- **Why:** it is the cheapest and most phone-consistent pipeline. It suits Roblox avatars and the friendslop look. Its rules can be written as numbers, so scripts can apply them, and it ages well (*Stylised vs Realistic Material Pipelines*; *Environment Art Styles*). "Players forgive low detail; they do not forgive inconsistency." Mixing Toolbox styles reads as "free model".
- **Colouring:** one **gradient palette atlas** (a tiny PNG) colours the whole game.
  - Strips at least 8 px (16 px for distant assets), UVs 2 px inside each strip, Closest filtering, PNG.
  - Per-instance variety comes from `MeshPart.Color`, never from new textures.
  - Every Roblox colour path multiplies, so author near-white wherever we want to tint, and set `Color` to white on vertex-coloured meshes. Convert hex to linear (power 2.2) in scripts.
  - Use SmoothPlastic by default and keep Neon on a budget.
  - Never give unique textures to individual props, because that breaks instancing and draw calls. Import each mesh once and clone it.
- **Value structure:**
  - 3-5 value bands per zone, roughly 60/30/10 by area.
  - **Interactables (furniture you can grab, the truck, living faces) own the lightest band or a saturation spike.**
  - Keep the ground mid-value so avatars don't disappear against it.
  - Neighbouring neighbourhoods differ in at least two of: hue, value key, saturation.
  - No pure black or pure white. Check every view in greyscale (`ColorCorrectionEffect.Saturation = -1`) and run a colour-blind check.
- **Shading:**
  - Smooth by Angle 30-40°.
  - 1-2 bevel segments (more costs about 9x the triangles), at least 2-3 px on screen, with Harden Normals.
  - Weighted Normal last in the modifier stack.
  - Bake contact darkening and AO into the colour at 0.2-0.5 strength.
  - Use blob shadows (a soft radial decal raycast to the ground) under moving furniture so it reads as grounded on phones with no shadows.
- **Silhouette and shape:**
  - Every furniture type must be identifiable as a black shape at 30-64 px. Run a **roster test**: each gameplay role needs a unique primary silhouette, with colour only as the second cue.
  - Size bands should step by at least 1.5x.
  - Pick one dominant shape family plus one accent.
  - Exaggerate in pairs (one feature up, its neighbour down). Lean on tapers, bulges and tilts instead of parallel lines.
  - **Physics props are the explicit exception to "delete undersides"**: furniture gets flipped, so it must be closed and watertight.
- **Faces (the identity asset, so a human art owner signs off):**
  - Each living archetype gets 3-4 hand-tuned expressions: sleepy, alert/peek, caught/grumpy, feral.
  - Use separate eye and mouth meshes or a small face decal set (a face texture when there are many). Follow the chibi rules: eyes below the middle with two catchlights, nothing pointing up (it reads as horns), and a top feature, because players see these from above.
  - **Feral state = glowing eyes** (Neon accent plus a small PointLight on hero pieces only). It must still read in greyscale at 50 px.
  - Inert furniture has **no face**. The contrast between faced and faceless pieces is the visual language for "alive".
- **Style bible** (*Style Bibles for Consistent Models*): 4-8 pages of numbers, not adjectives, written in week 3. Contents:
  - intent plus 3 references;
  - scale sheet (5- and 6.5-stud avatar proxies);
  - grid (**4-stud building grid, 2-stud interiors**), pivot at bottom centre, fronts facing -Y;
  - edge and segment tables, triangle targets;
  - palette and colouring method, allowed materials;
  - shape grammar;
  - **3-5 golden assets**: sofa, wardrobe-with-face, footstool, the truck, one house module;
  - automated checks;
  - changelog.

  Start with just the palette plus golden assets, so the bible doesn't block the prototype.

### 6.2 Making the art cheaply and well
- **Pipeline:**
  1. Blender **Python generators** (`roblox-blender-modeling`: `lihfolk_bpy.py`, `lihfolk_house.py`), run headless: `blender -b --factory-startup --python <script>.py`.
  2. The generator reads its parameters from the style bible.
  3. Brief → blockout → silhouette check → half plus mirror → exaggerate → `lf.finish(ob,"soft")` → vertex colours / palette UVs → origin at the bottom → `lf.gate(...)` (A1-A18: symmetry ≤1%, seating, no self-intersection, clean caps) → blind V1-V9 review (≥14/18, no zeros) → `lf.export_glb`.
  4. Import into Studio: Box/Hull collision, decoration non-colliding.
- **"Primitives are a blockout, not a model."** Stretched spheres and bare boxes read as programmer art. Use box-modelled single masses, extruded and bevelled silhouettes, and markings painted into the palette.
- **No text-to-3D meshes for anything identity-bearing.** The reference project banned generated meshes because of style mismatch and no control over LOD, collision or atlas. If you ever use one for background rubble, normalise it in this order: scale, shading, edges, palette, material. Keep a **provenance log** (tool, model, plan, date, human changes) for any AI-assisted asset. The **mascot and logo must be human-authored or heavily human-edited** (copyright needs human authorship).
- **Humans do these steps:** GLB import (File > Import 3D; MCP can't import local files), CollisionFidelity on import (scripts can't change it on a loaded MeshPart; otherwise use `AssetService:CreateMeshPartAsync`), and all uploads **as the group**.
- Each mesh class is built once as a parametric script and reused across houses and variants. This is also the token saver: Claude edits parameters, not geometry.

### 6.3 World and level design
- **Houses from a modular kit** (*House Construction Method - Modular Kit Workflow*, [Measured]):
  - Doors 3.6-4 × 7.5-8 studs. These are the kit's **avatar-only** doors (fine for closets and back rooms). Our carry-path doors are wider; see the gameplay dial below.
  - Storeys 10-12, interiors 2-3 avatar heights so the camera doesn't clip, walls 1-1.4 thick.
  - Real openings.
  - **Turn wall mesh collision off and add invisible box Parts per wall run.** Box/Hull collision fills door openings, so players can't get in.
  - 13-14k tris per house across 7-8 modules.
  - Emission doesn't light anything, so add PointLights or SurfaceLights.
- **Door, corridor and stair sizing is a gameplay dial** [Inference from *Proportion Exaggeration and Gameplay Distance*: doors 1.5-2.5x avatar width, corridors 8-12 studs]:
  - Main doors fit a two-person carry of the biggest sofa **with tilting**. As a starting point, carry-path doors are about 6-8 studs wide and the "PIVOT!" doors 4.5-5 [Inference; measure with the largest allowed avatar plus the biggest sofa collider in week 1].
  - Some doors deliberately need a pivot ("PIVOT!" ping), which is a chokepoint and a clip.
  - Leave 1 stud of margin per side for the largest allowed avatar.
  - Stairs use wedge colliders under the visual steps. Stairs are where pianos go wrong, on purpose.
- **Layout:** one fixed **anchor layout** per neighbourhood for the MVP, plus seeded variation of furniture placement. Later, generate floor plans from room modules with fixed anchor rooms and random filler (the Doors pattern; *Dungeon and Room Generation*). "Describe, then build": plain Luau tables first, instances last. `Random.new(seed)` per purpose. Loot and mystery rolls use server-only entropy. Save `{seed, genVersion}`.
- **Reading order** (*Teaching Through Level Design*): light/contrast → motion → skyline → openings → text. Put a **warm light at the truck**, keep the critical path lit, use **one cue per meaning** (danger, grabbable, locked), and audit after every art pass ("one broken promise costs the whole language"). About 80% of first-time testers should find the critical path without UI.
- **Composition passes** in order: layout → primary forms → composition → story groups → small detail. Dressing before the first three passes is "the root of most 'AI map' looks". One hero per exterior (a crooked chimney). Made things align, grown things vary. Environmental storytelling as a question: the previous family's dinner still on the table, a note saying "DON'T open the wardrobe".
- **The depot/hub** (if any) stays compact. Spawn facing the truck pad, with the first station within 15 s. A 6-player pad is about 24 studs, polled with `GetPartBoundsInBox`. Add a continue portal for veterans. The hub gets the tightest performance budget. Skip a hub entirely for the MVP (single place, job loop).
- **Falls are not death** in a non-obby game. Use recovery planes and a last-safe-spot server sweep with a per-zone threshold. Ragdoll launches exceed a fixed 55-stud rule, so tune it per area. Recover whole furniture assemblies with `PivotTo` and zero velocity.
- **Measurement table on day 1:** walk 16 studs/s (100 studs = 6 s), jump 7.2, gravity 196.2, and a reference character in every blockout.
- **Camera indoors** (*Camera Obstruction Handling - Occlusion Modes, Fades and Collision*): houses are full of occluders, and a camera that clips behind a wardrobe kills both play and clips.
  - Choose the occlusion mode per area: Zoom outdoors; Invisicam or a zoom limit indoors.
  - Build walls as split modules, never one huge part (Invisicam fades whole parts).
  - Keep thin decor out of occlusion.
  - Our invisible wall-collision boxes also keep Zoom mode from passing through decorative walls with collision off.
  - Test the camera during a two-person carry on the stairs.

### 6.4 Lighting moods (a client-only LightingController owns Lighting)
- **One clock:** the server publishes the phase epoch as attributes, and clients compute from `GetServerTimeNow()`. `ClockTime` is NotReplicated. Gameplay never reads client `ClockTime`.
- `LightingStyle = Soft` for low-poly (decide early, because changing it later means re-lighting every interior). Use Atmosphere **or** Fog, never both. Bloom threshold 1.2-2.
- **Day ("Bright cartoon")**: Soft, high OutdoorAmbient, specular 0, bloom threshold 1.2. Sun 30-50° up, lit faces 1.5-2.5x shadow faces, warm `ColorShift_Top`, cool ambient.
- **Dusk:** warm amber key, long shadows (on high tiers), with a screen-edge pulse and the bell as tells.
- **Night ("Readable night", lihfolk-worldbuilding preset):**
  - ClockTime 0, Brightness 0.6.
  - Ambient (60,70,110) / OutdoorAmbient (80,95,140), ColorShift_Top (150,170,255).
  - Saturation -0.1, bloom threshold 0.95.
  - **"Night is tinted, never black."** Silhouettes should be visible at 50 studs.
  - Run a greyscale check: if a character and the ground are within about 10% value of each other, it is too dark.
  - Feral eyes, the truck light pool and lamps carry the mood. **Paths always sit in the lit pools.**
- Interior lighting layer per house zone, blended over 0.5-1 s at doors.
- **Never rely on shadows for gameplay or scares.** Phones below quality 4 have none. Test at the lowest quality on a dim phone.
- Optional flashlight (a Spotter role): a SpotLight on an Attachment, range ≤120, shadowed only for the local player's own light.

### 6.5 Audio
- **Sources:** Roblox-licensed Creator Store audio first (MCP `search_asset` with verified creators), then commissioned or owned audio. Audio must be **uploaded under the group** (the vault's reference project found 55 sound ids that would not load live for this reason [Measured]). Keep an id manifest and run periodic load checks.
- **Mix:**
  - Master > Music / SFX / UI / Ambience / Voice buses, plus a **Warnings SoundGroup that the music slider can't mute** (the Pressure lesson).
  - -18 LUFS momentary max, mono for 3D, 3 or more variations per cue (4-6 for footsteps).
  - Pitch variance ±3-6%. Voice cap 24 PC / 16 touch.
  - Set custom rolloff, because the defaults (10/10,000) are almost never right: footsteps 5/50, furniture impacts 8/100, shrieks 12/200.
  - Sound 0-30 ms late fuses with the action; 80 ms or more feels like lag; **never play early**. Trim lead-ins to under 10 ms onset. Preload first-impression sounds.
- **The signature palette:**
  - **Furniture voices.** Each archetype has a squeak, grumble or shriek set (game-made proximity drama for the voiceless majority).
  - Wood-creak and thud impacts chosen by material (an impact-table pattern: attribute → variant → material), rate-limited to about 6 per second per object.
  - The dusk bell / clock chime, a "PACKED!" stamp, and the truck-door slam.
  - Creaky floors as a horror cue.
  - Captions for information-bearing sounds ("[Wardrobe moving upstairs]"), with a visual twin for each.
  - **A muted playthrough must contain no surprise downs.**
- **Music:** two-deck crossfades, a 2-3 s fade-in on join, an adaptive night layer, and a "streamer mode" toggle. Use only owned music in TikTok trailers.
- **Voice (bonus layer):** with `VoiceChatService.UseAudioApi`, route proximity voices through character `AudioEmitter`s, and optionally a "truck radio" EQ inside the cab. No rewards for speaking, no private channels between strangers, no "mute everyone".

### 6.6 VFX and juice
- **Rule** (*Game Feel and Juice*): every input gets at least a pop and a sound, every reward gets motion and a number, and only big moments get shake. **Show something on the frame the input is read, even when it's denied.** Never `InvokeServer` before animating.
- **Grab feedback:**
  - A thin white Highlight outline (DepthMode Occluded, fades in over 0.1 s), managed by one arbiter or a container Highlight. Never create and destroy Highlights per flash.
  - A click sound, plus a 15-30% squash on the visual mesh (not the collider), springing back with damping 0.4-0.6.
  - The interact buffer is none or 0.1 s, because grabbing the wrong target is worse than a missed press.
- **Teammates through walls:** outline only, AlwaysOnTop, team colour, outline transparency 0.3. **Living furniture never gets AlwaysOnTop** (that would be a free wallhack).
- **Impacts:** dust puffs, wood chips and star bursts, all pooled and client-built from one server event (id + seed + server time). Send to players within about 250 studs. Particle life ≤1.4 s.
- **Hit-stop:** 40-90 ms only on big drops and door slams, client-side, and never on onlookers. ≥66 ms to register at 30 fps.
- **Shake:** trauma², translational, short, and only for your own actions. A 0-100% slider, off under Reduced Motion. Offer an opt-in "Intense / Cinematic" preset for creators, because the vault warns creators push for strong shake, which causes nausea.
- **Payout tally:** a log-scaled count-up (0.35 s for +1 up to about 1.67 s for large amounts), ticks rising 4-7 semitones, a distinct "done" sound. Reward animations take under 10% of play time. The rare-variant reveal is the one big celebration (world dims, server banner).
- **Telegraphs** (four layers: dark outline, base fill, progress fill, bright rim). They are **never culled on low tiers**. Duration = 0.25 s reaction time + escape time at walk speed.
- Flashes ≤3 per second, behind a flash-limiter setting.

### 6.7 Animation
- **Players:** keep the default Animate script alive (seats, emotes and climbing T-pose without it). Add an **arms-only Carry layer** at Action priority over the normal gait, plus **IKControl hands** on the handle attachments:
  - Type Transform, `ChainRoot = UpperArm`, Weight faded (never toggle `Enabled`), `SmoothTime` 0.
  - Clamp targets to 98% of chain length.
  - Replicate *which handle* is held; every client runs the IK locally.
- Cache one track per Animator per clip. More than 256 tracks triggers a warning.
- Use `Animator:LoadAnimation`, preload clips on join (first plays can be 0.5-5 s late), and **publish every animation as the group**. Lint for `RegisterKeyframeSequence` ids, which are Studio-only and dead live.
- Mixamo clips are fine in our game but must never be redistributed. Keep a licence log per clip.
- **Furniture needs no rigs.** Liveliness is procedural on the client: hop impulses (server), wobble springs and squash on the visual mesh, a lid or door "mouth" on a hinge (hinged props: origin on the hinge, `Hinge_Att` marker), and eye blinks. Use time-formula animation, not accumulated angles. Distance LOD: full within 60 studs, every 2nd frame to 150, every 4th to 300. **LOD may skip writing poses, never time or gameplay events.** This is far cheaper than C's animal rigs.
- **Emotes:** up to 8 built-in, plus custom celebration emotes ("high-five over the couch") at Action priority, 2-8 s, cancelled by any gameplay action. Sync group emotes via `TimePosition = (now − t0) % Length`.
- Starter creature rigs exist in *Skeleton Library* (Quadruped, Spider, Serpent and others), but **they have not been Studio-tested**. They are only relevant if we ever add animal-like furniture (a dog bed?).

---

## 7. Onboarding, tutorial and UI/UX rules

### 7.1 The first-session script (timeline targets from *First-Time User Experience and Onboarding*, *Onboarding by Genre*, lihfolk-tutorial)

| Time | Beat | How it is taught |
|---|---|---|
| 0-10 s | Loading closes on a `ClientReady` attribute (20 s hard cap, skip after about 3 s, returning players skip at once). **Control within about 10 s.** | No menu, no name prompt, no "Press Play". |
| 10-20 s | Spawn **on the truck ramp facing a snoring footstool 6 studs away**. One pointer: a Highlight on the stool plus a ProximityPrompt showing the device-correct key ("Grab"). | Teach by doing. The objective text is 8 words or fewer: "Grab the footstool". |
| 20-35 s | The stool wriggles and squeaks while carried. "Drop it in the truck": a beam from the feet to the truck bed. | Cause and effect stay in one view. |
| 30-40 s | **PACKED!** stamp, a Pay count-up, a juicy sound. **First reward.** | Server-confirmed. |
| 40-60 s | An armchair across the yard opens one eye and **bolts**: a second loop with a twist (catch it by cornering). | "The first risk event teaches the rule" (trend row). |
| 1-3 min | The first heavy item (a sofa). With 2+ players a "LIFT TOGETHER" prompt appears. Solo players see the dolly next to the sofa. | Pattern "Social, never a gate": `optional = true`, completed by the server when a friend is present. |
| ~3-5 min | The **first dusk**: a long readable warning (bell, sky, caption), a visible countdown on the truck, and a short, survivable night that hands out the "the truck light is safe" lesson. | Horror row: "quiet first rooms, first threat with a long readable warning and a visible counter". Put failure-prone beats **after** safe ones (the reference funnel lost 31% / 34% / **82%** at combat and boss steps). |
| End of job 1 | Tally, Dex "NEW!" stamp, **next-goal card**, then (only now) an invite moment and the starter-pack offer if eligible. | At most one modal in the first minute, none before the first goal. |

- **Targets** [RoT]:
  - The core loop closes 3 or more times within 5 minutes.
  - The whole tutorial takes under about 3 minutes.
  - Each step keeps 90% or more of players, and 70% or more finish.
  - Stuck hints appear after 6-10 s without progress and escalate from a world cue to an edge arrow to text.
  - Tutorial steps are saved per step (skippable and resumable). A server skip grants what the steps would have paid.
- **Death teaches** (the Doors lesson): after a down, show one line: "The wardrobe moves when nobody watches. Keep eyes on it."
- **Never gate friends:** friends who join mid-tutorial drop straight into the job. The tutorial must work with **two tutorial players in one server** (rubric T7).
- **Funnel** (server-side `LogOnboardingFunnelStepEvent`, first session only, logged in order, 8-12 steps, published games only): `Loaded → FirstMove → FirstGrab → FirstPacked → FirstLivingCaught → FirstHeavyLift → FirstDusk → JobComplete → SecondJobStarted → Minute10`. Measure the time between steps, not just counts. Version the funnel name when steps change. Fix the earliest weak step first.

### 7.2 HUD and UI rules
- **The HUD is nearly empty, so clips read well.**
  - The quota and phase countdown live **on the truck** (a SurfaceGui with `MaxDistance` and a sensible `PixelsPerStud`), with a small mirrored quota chip in the top centre.
  - One objective line (8 words or fewer), one pointer at a time.
  - **Hide-HUD** keeps critical elements and leaves a restore button on mobile.
- **Zone map before building:**
  - Bottom-right: **one big primary Grab/Drop/Throw button** (the largest element, 48 px or more drawn, state visible at a glance) plus a Ping button.
  - Bottom-left: thumbstick, left free.
  - Top-centre: quota and time.
  - Off-screen arrows for the truck and downed teammates (flipped when Z<0, clamped to the safe rect, occlusion checks at 2-5 Hz).
  - Every popup goes through **one queue with gating**: no celebration over a down screen; the queue is capped at about 8 and merges by key ("+3 packed").
- **Numbers (phone pass criteria, [Measured]):**
  - Text ≥12 px drawn (≥14-16 px preferred on phones), taps ≥44 px (48 for HUD), gaps ≥8 px, 0 overlaps, 0 off-screen.
  - Test at 1920x1080, 1366x768, 1024x600, 932x430, **844x390 (primary phone)**, **667x375 (worst case)**, a notched phone, and gamepad/TV.
  - Classify by `GuiService.ViewportDisplaySize` and `UserInputService.PreferredInput`, **not** by `TouchEnabled`.
- **Implementation:**
  - Author in Offset at 1920x1080 with one clamped `UIScale` ("Fit").
  - Pops tween a child `UIScale`, never `Size`.
  - `ScreenInsets` set explicitly. `ResetOnSpawn = false` on persistent screens, as direct children of StarterGui.
  - `Activated` (never `MouseButton1Click`).
  - `FontFace` with at most 2 families (no Gotham).
  - Modal blockers use `InputSink`.
  - No idle per-frame Lua; write labels only on change.
- **Input:**
  - Use the **Input Action System** (`InputContext`/`InputAction`/`InputBinding`), with every action bound on keyboard, gamepad **and** touch. Don't bind the same key in both IAS and CAS.
  - **Hold vs Toggle option for carrying**, force-released on death, menu or focus loss.
  - Touch players auto-sprint. Stamina, if any, has its bar always visible.
  - Remap ProximityPrompt gamepad keys away from ButtonX. Use a short `HoldDuration` for "unplug" and "revive", never an instant `E` for destructive actions. No Shift sprint (it conflicts with shift-lock).
  - Device prompts come from tokens ("Tap / Click / ButtonX"); never hard-code "Press E".
- **Comfort settings on day 1** (all cheap; one schema, sanitised on the server, overrides-only saves):
  - Music slider plus mute, and separate SFX and Voice sliders.
  - Shake slider, flash limiter (≤3 per second), Reduced Motion honoured (it swaps motion for fades; it doesn't just shorten tweens).
  - FOV 60-100 with one FOV owner (total gameplay FOV change capped at 12°).
  - UI scale 0.8-1.3, hold/toggle carry, haptics on/off, graphics preset.
  - Honour `PreferredTextSize` (no `TextScaled`) and `PreferredTransparency`.
- **Accessibility:**
  - Colour is never the only channel (shape + icon + word). Faces' alert states also change shape.
  - Captions for threat sounds.
  - 4.5:1 contrast for body text.
  - Gameplay coordination never lives only in voice or chat.
- **Social UI:**
  - Client-created nametags: crew visible through walls (faded) at long range, `DisplayName` by default. Speaking icons only within voice range.
  - "Invite friends" sits in the results screen and the depot, never as a popup.
  - Block/mute is enforced both ways on custom interactions.
- **UI style:** our own tokens (one theme module: colour roles, type, spacing, radius, stroke, motion). Chunky, warm "moving-company stencil + sticker" look [Inference]. Only borrow the `lihfolk-ui` structure if it fits. Every component needs every state (default, hover, pressed, disabled, selected/gamepad, locked). The UI rubric bar is 8.5 or more ("knows what to press in 3 seconds").

---

## 8. Credit-saving AI workflow (Claude Code + Rojo + Studio MCP)

### 8.1 Principles
1. **Code lives in files** (Rojo + git). Studio is "an I/O device and a ground-truth oracle". Use MCP for scene operations, numeric checks and short probes only.
2. **Look up only what may have changed since training** (section 2.2). Use `vault.py`, not note reading, and grep `SYMPTOMS.md` before debugging. Feed Claude `_data/roblox_facts_2026.json` and the delta notes, not whole notes.
3. **Install, don't generate:** library modules for data, net, currency, quests, receipts and shop; worked builds for the round loop, monster, downed and ragdoll. Spend tokens on the unique systems (carry, living AI, delivery, rug-revive, furniture FX).
4. **Small focused sessions.** One feature per session, six 100-line changes rather than one 600-line change, PRs under about 400 lines. Ask for artefacts (grep output, compile output, counts, harness numbers), not reassurance. For creative work, ask for 3-5 options (an owner once rejected 20 agent-designed weapons after the fact).
5. **Data-driven everything:** furniture archetypes, jobs, economy, tuning and the event calendar are config tables (CSV → validated → generated Luau marked GENERATED, or JSON in Configs). Rebalancing then needs no code regeneration. Watch out for the Danish "0,5" decimal comma in CSV.
6. **Humans own** taste, feel tuning, playtests (physics, ownership, ragdoll and replication **cannot** be verified in Edit mode), GLB imports, CollisionFidelity, uploads as the group, Creator Dashboard, product ids, publishing, monetisation decisions and the maturity questionnaire.

### 8.2 Memory files (the main token saver between sessions)
- **`CLAUDE.md`** (<200 lines): commands (`tools/check.sh`, `rojo serve`), layout, house rules (strict Luau, modern APIs, remote order, one data writer / one ProcessReceipt / one bootstrap, no scripts in Workspace, tags plus attributes), the vault lookup recipe, and the session protocol. Put rules that matter in **permissions, hooks and CI**, because instruction files get dropped in long sessions.
- **`PROJECT_STATE.md`** (<150 lines): Identity; Works (with how it was verified: "Edit-verified" vs "play-tested"); In progress; Broken/risky; Decisions (date + reason); Open questions; Do-not-touch. **Don't `@import` it into CLAUDE.md.**
- **`handoffs/YYYY-MM-DD-topic.md`**: Goal, Done, Not done / next step, State left behind, Learned, Evidence.
- **Resume protocol:** read the state file and the newest handoff → verify git and Studio state → stop if reality differs.
- `docs/ARCHITECTURE.md` (services plus the remote manifest from 5.5), `docs/DECISIONS.md`, `OWNERS.md` (one owner per module and folder if several agents run).
- Claude Code transcripts are kept 30 days (`cleanupPeriodDays`).

### 8.3 Studio MCP rules (built into Studio since 2026; the old open-source server was archived 2026-04-03)
- Enable it via Assistant > ... > Manage MCP Servers > "Enable Studio as MCP server". For Claude Code: `claude mcp add --scope user Roblox_Studio -- cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"` (macOS: `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`).
- Call `list_roblox_studios` first every session (`studio_id` changes on every restart).
- **Each call under about 1.5 s, one at a time.** Studio froze for about 25 min with 18 parallel processes [Measured].
- **Edit mode only. Agents never start or stop Play** (deny `start_stop_play` in permissions) and **never use undo** (one undo went about 40 waypoints back) [Measured].
- **Clone-require** when testing edited modules, because `require` is cached. **Fresh `script_read` before every edit.**
- Save gate: compile with `loadstring`, use-before-definition scan, size under 190,000 characters (hard limit 200,000), module loads, numeric harness.
- **Numbers over screenshots:** raycast grids, overlap counts, budget reports. `screen_capture` comes out black when Studio isn't in the foreground. Filter `search_game_tree` and return counts, not trees.
- Never invent asset ids: use the placeholder `rbxassetid://0000000000` / `REPLACE_ME` and ask. Never use backtracking regex in Studio (one froze it for 40+ min); use plain `string.find(s, needle, 1, true)`.
- Backups go to disk or Version History, **never as folders in the place** (one place grew to 2.36M instances).
- Tag every agent edit with a grep-able marker (`-- [agent 2026-11-12 carry]`). Studio restarts can reopen an older autosave.
- **Permissions:** allow read-only tools, ask on `multi_edit`/`execute_luau`, deny `start_stop_play`, `insert_asset` and `generate_*` (`generate_material` failed almost every job [Measured]). Deny reads of `.env` and secrets.
- **The verification ladder**: compile → lint → load → probe → Edit integration → Play → Team Test/live → telemetry. Every report names the rung reached and includes a **"not play-tested"** section when it applies. Multiplayer features need rung 7: Server & Clients with 2-4 clients at the Network Simulator presets, plus a published private server with a second account and a real phone.
- **Testing realities:** teleports, real latency, DataStores and purchases behave differently in Studio. The Party Simulator fakes `PartyId`. Open Cloud Luau Execution CI runs **without physics**. Pure logic (quota, payout, scaling, schedules) goes in testable modules with injected time and RNG, so Claude can verify it cheaply.

### 8.4 Quality gates and when to use the council (milestones only)
| Moment | Tool | Tier |
|---|---|---|
| Concept lock (now) | `/lihfolk:council quick` with the Skeptic lens on the fixed rubric (verb clear in 10 s, co-op necessity, clip-ability, mobile physics cost, originality). Escalate to Standard only on a split. | Quick |
| Economy sheet (once, W2) | `/lihfolk:council standard` | Standard |
| Art direction / faces (W3) | Quick council, Art Director lens ("where AI slop is decided"), plus the `quality-score` model rubric (3 blind reviewers, median ≥8.5) on golden assets | Quick + 3 reviewers |
| Tutorial (W3-4) | `quality-score` tutorial rubric (hard gates: social never blocked, no purchase prompt in onboarding, per-step resume) | 3 reviewers |
| UI / world (W3-4) | `ui` and `world` rubrics | 3 reviewers |
| Every system | `system` rubric. Capped at 5.0 until it is actually run in Studio | 1 reviewer per fix round, 3 for pass |
| Before soft launch | `/lihfolk:audit`, anti-exploit review, performance audit, monetisation compliance, then *QA Checklists Before Release* | n/a |

- Fix only the lowest high-weight criterion per round, with at most 3 rounds. **Ship the best panel score, not the latest version.** Panel differences under about 1 point are noise. Single AI reviewers score about 1 point high, and self-review about 2 points high [Measured].
- Never run council or quality-score on routine coding.

### 8.5 Session template (copy into prompts)
```
Context: Catch The Couch (Roblox co-op). Read PROJECT_STATE.md + newest handoff only.
Task: <one feature>. Runs on: <server|client|shared>. Trusts: <nothing from client except intent ids>.
Rules: --!strict, modern APIs (task.*, Animator, Align*, PreSimulation, Async renames: bible 5.9; run vault.py --api on any doubtful name), Net.Handle for remotes,
       one mover per assembly, explicit SetNetworkOwner + re-assert after structural change, no scripts in Workspace.
Look up (vault.py) only: <post-2025 topics touched>.
Done = compiles + selene/luau-lsp clean + numeric harness output + "not play-tested" list + 2-client test steps for the human.
```

---

## 9. MVP plan: week by week to a testable vertical slice and launch

Templates: *Ship a Game in 30 Days*, *Roadmaps Milestones and Scope Control*, the feasibility lens. The plan targets 4 weeks to soft launch plus 2 weeks to launch. Three-point estimates with a visible 20-30% buffer; a 6-week total is realistic [Inference]. **Rule: one core verb (catch and carry), one progression axis (Dex plus upgrades), one reason to come back (daily Featured House and new items). At most 3 monetisation items at launch.**

### Week 0 (2-3 days): setup
- Create the **Roblox group** and make it the owner of the experience and all assets. Use a separate dev universe and test experience, 2SV, a separate daily account, and creator ID verification. Start the age check, Plus or fee, and questionnaire paperwork.
- Repo boilerplate: Rojo (code-only mapping, `$ignoreUnknownInstances`, `servePlaceIds` = the dev place), Rokit, Wally, StyLua, Selene, luau-lsp, `tools/check.sh`, `.gitattributes` LF, CLAUDE.md, PROJECT_STATE.md, `.claude/settings.json` permissions, and the LihFolk plugin with its hook.
- Studio settings, set by a human: streaming values, Avatar Settings (constrain scale / Single Collider), `Players.BanningEnabled`, collision groups registered at edit time.
- Install lihfolk-systems: `PlayerData`, `Net`, `RateLimit`, `Signal`, `Janitor`, `Currency`.
- Run `/lihfolk:council quick` on the concept rubric.

### Week 1: the ugly greybox loop (the feel gate)
- 1 greybox house (from `lihfolk_house.py` or blocks) with real doors, stairs and a parked truck with a bed zone.
- 8 props: box, chair, lamp, footstool, sofa, piano, wardrobe, rug.
- CarryService **light tier** and **heavy tier**, plus the dolly. DeliveryService with the "PACKED" stamp. Player ragdoll (owner-applied, 1-2 s), with `WatchOwner` and the velocity watchdog in from day 1.
- **One living piece (the footstool)** with Skittish/Caught states, including the Caught → carrier-owned → escape → server-owned handoff from 5.3. Log ownership flips with `WatchOwner` during the handoff.
- **Prototype the two-person heavy lift alone first.** Test it at 0/150/300 ms on 2-4 clients and a real phone, and compare against the fallback "attach-and-follow".
- **Gate:** 3-5 strangers play 10 minutes and at least 3 want a second session, with no fling in 20 two-person lifts at 150 ms. Record the first clip-able moments; that is the Day-3 "2-player test video".

### Week 2: the game around the loop
- JobService phase machine: Day/Dusk/Night/Payout attributes with server-time ends, the House Awake meter, and night feral behaviour for the footstool plus the **wardrobe** (unwatched rule). The truck light safe radius.
- DownedService **rug-burrito** plus a hold-revive fallback and ghosts.
- PayoutService, Pay and Stars, a minimal Dex slice, the profile schema v1, autosave and BindToClose. Kill the server mid-job and verify the save.
- Ping wheel, LIFT TOGETHER prompt, crew bonus, PartyId spawn-together.
- Analytics funnel and join-time telemetry. Configs for tuning and kill switches.
- **Gate:**
  - The multi-client matrix: A then B; B joins mid-carry; A leaves mid-carry; fast rejoin; simultaneous grab on one item; downed during carry; phase change during carry; stream-out and back.
  - 4-6 Studio clients, then a published private server with a second account.
  - Economy sheet through the Standard council once.

### Week 3: content, art and phone
- **15-20 Blender furniture props** through the generator pipeline and the A1-A18 gates. Golden assets and faces approved by the human art owner (blind panel ≥8.5). Style bible v1 and the palette atlas.
- 1 house layout plus 1 variant (or a second neighbourhood dressing), lit with the Day, Dusk and Readable-night presets.
- The **lamp** archetype (or keep it for the first post-launch drop if behind schedule).
- Audio pass (furniture voices, bell, slam, captions) and VFX pass (pooled dust and impacts, telegraphs).
- Tutorial via `lihfolk-tutorial` with the 7.1 timeline. Settings menu. HUD on the truck SurfaceGui.
- Phone pass: Performance tier default, the **15-minute soak on a 3-year-old mid phone** with 6 players in the densest house, and UI at 844x390 and 667x375.
- Start the store page on day 15: icon, 3-5 thumbnails from real captures in the capture place, title and description. Submit the maturity questionnaire, targeting Mild.
- **Gate:** a phone playtest where **first reward <60 s** holds for 2/2 fresh players, and a stable framerate within budget.

### Week 4: QA, compliance and soft launch
- Install `Receipts`, `Shop` and `Policy` with **≤3 items**: a cosmetic uniform pack, a door-opener pass under 100 Robux, and Crew Boost "this server". Private servers are enabled at a permanent price. Buy every product in the test experience.
- `/lihfolk:audit`, anti-exploit review with a fuzz harness on all remotes, performance audit, monetisation compliance, *QA Checklists Before Release*, and the multi-client matrix again.
- Test once with `TextChatService.PlatformIntegratedChat` and `Workspace.PlayerScriptsUseInputActionSystem` set to `Enabled` (both become defaults in early 2027), and run the 5.9 CI grep.
- Experience sessions: observe 5 new players silently for 20-40 min each.
- **Soft launch (around day 27, Tue-Wed): public but excluded from RFY.** Bring a few hundred controlled players (friends, small Discord, a small Engagement ad) and fix the top 3 issues.
- Feature freeze about 1 week before the end of the milestone. Use the cut list in order: second neighbourhood, roles, extra archetypes, dragged-by-strap, Leaderboard, codes, daily quests, extra monetisation. **Never cut:** data safety, receipts, server validation, mobile layout, the questionnaire.

### Weeks 5-6: launch and first live weeks
- Open RFY when the 4.3 bars pass. Activate 2-5 thumbnails and open the TikTok push (3-5 clips per week, one share link per clip) on a Friday or Saturday. Be online for 48 h, with an update queued for week two.
- Weekly: a new feral item (lamp → fridge mimic → sofa rodeo). A weekend 2x-Pay event. Then DailyRewards, Quests, the Featured House daily seed, invite/referral rewards on qualified arrival, and a "What's New" panel.
- **Kill or double-down rule** (written now): after a 2-week soft launch with a small ad budget, if D1 is below our threshold (start with 20%, adjust from our own data), fix onboarding. If it is still flat after 2 more fix cycles, rethink the promise before adding content.

### 9.1 Playtest and live metrics to watch
| Metric | Target / alarm | Source |
|---|---|---|
| Join → control | ≤10 s on a mid phone | Telemetry `LogCustomEvent` |
| First grab | 10-20 s after control | Funnel |
| First PACKED reward | <60 s for ≥85% (alarm <70%) | Funnel |
| Biggest funnel drop, first 3 min | <15% (alarm >25%) | Funnel |
| Per-step retention / tutorial completion | ≥90% / ≥70% | Funnel |
| Bounce <60 s and 61-180 s | Falling release over release | Creator Dashboard |
| Median first session | ≥10 min (alarm <5) | Dashboard |
| Chaos beats per minute | 1.5-3 (one every 20-40 s) | Playtest tally [Inference] |
| Fling / stuck incidents | 0 flings in 20 two-person lifts at 150 ms; stuck watchdog fires for <1% of sessions | Watchdog logs |
| Phone frame time | Within budget after a 15-min soak; no `stepWorldThrottled` | MicroProfiler, real device |
| D1 / D7 / D28, co-play days, share of sessions with 2+ friends | Our own soft-launch baseline (vendor benchmarks are Unverified) | Dashboard, cohorts by source |
| D1 per TikTok share link | Rank clips by it, not by views | Funnel field |
| Prototype gate | 5 outsiders × 10 min, ≥3 want to continue | Experience sessions |

---

## 10. Top 40 rules and mistakes checklist (with source note)

**Design and virality**
1. The first loop must be fun with **zero upgrades** and complete in 30-60 s. Always show a visible "next". (*Core Loop*)
2. Gain control in about 10 s, act within 10-20 s, get the first reward in under 60 s. No cutscene, menu, text wall or pop-up before the first verb. (*First-Time User Experience and Onboarding*; *Onboarding and FTUE*)
3. **Never gate social play.** Friends can join and play from second one, and any social step is optional. (*Onboarding and FTUE*; lihfolk-tutorial rubric)
4. Every threat gets **one tell and one counter**, and different threats use different verbs. Judge "looking" over 0.2-0.4 s. (*Teardown - Grace*; *What Craft Looks Like on Roblox*)
5. Telegraph anything the player must dodge by **≥500 ms**, and threat attacks by ≥0.45 s with facing locked. A muted playthrough must have no surprise downs. (*Anticipation*; *Animating Creatures and Monsters*; *Captions and Audio Accessibility*)
6. The monster or feral speed stays **below the unburdened player's speed** (the reference build means "below sprint", with walk 12 and sprint 18; we have no sprint, see the 5.3 speed table). Catch cooldown is 6 s. No omniscience; it gives up when it loses track. (*Horror Monster Chase AI End to End*; *Genre Playbook - Horror and Story*)
7. Scaling is sub-linear, `1+k(n−1)` with k 0.5-0.7. Solo must be viable, late joiners catch up, and only active players count. (*Spawn Director*; *Genre Playbook - Zombie and Wave Survival Co-op*)
8. Pay **full** rewards to every contributor. Never reward harming teammates. Shared failure costs, not individual blame. (*Social Design and Multiplayer Play*; *Teardown - Dandy's World*)
9. Gameplay must never depend on voice or chat. Use pings, emotes, quick phrases and game-made sounds. (*Voice Chat and Safety Features*; *Age Checks and Safety Features*)
10. Updates add **mechanics**, not just numbers. Plan for the floor, because peaks fall 90% or more. (*Viral Game Anatomy - Hooks, Loops and Timing*)
11. Use quests built on loop verbs. Never "log in" or "play X minutes" quests. At least one "ready" thing on every join, and at most one automatic pop-up. (*Retention and Return Hooks*)
12. Use other games' mechanisms freely, never their surface. Invent all characters and names. No third-party IP or brands. (*Legal Basics - IP Licenses and Assets*; *Competitor Analysis Method*)

**Discovery and marketing**
13. Optimise **PTR, first-play bounce and D1/D2-7/D8-28 play days**, not qPTR or raw clicks. Only organic RFY joiners count. (*Discovery and Monetization Changes 2025-2026*)
14. Ship a custom thumbnail (required for Home since 2026-10-19), with 2-5 variants that each sell a different **true** promise. Use real gameplay only and keep the bottom 15-20% clear. (*Thumbnails Icons and Store Page*; *Roblox Policies on AI-Generated Content*)
15. Don't buy ads or push TikTok before D1 is measured. Ads never raise RFY ranking. Fix the bounce first. (*Launch Strategy - The First Two Weeks*; *Sponsored Ads and Campaign Math*)
16. Use one share link per clip or channel, and judge clips by **D1 per link**. Reward invites only on qualified arrival (about 10 min played), never on click. (*Short-Form Video Marketing*; *Friend Invites Referrals and Experience Invites*)
17. No external links or handles in the game. Disclose paid promos in kid-friendly words. Never show other players' names or voices without consent. (*Policy and Age Rules 2026*; *Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure*)

**Networking, physics and security**
18. The server decides and the client sends intent. Never trust client prices, positions, damage or "delivered". (*Server Authority*; *Client-Server Model*)
19. Remote handler order: **rate → type → value (NaN/inf/range) → context → lock and act with no yield → score**. Never kick on one breach. Never use `InvokeClient`. (*Server Authority and Validation*; *Cookbook - Remotes and Networking*)
20. **Never leave carried or gameplay props on auto ownership.** Set the owner explicitly and re-assert it after every weld, anchor or ragdoll change. (*Network Ownership*; *Debugging Physics and Network Ownership*)
21. Shared or two-person props should be **server-owned with capped movers**. In the vault's pushable-crate worked example (pushing, not carrying; not labelled Measured) that gave 0 flings in 20, against 3 in 10 under auto ownership. The server never applies forces to a client-owned assembly; hand living pieces back to the server before they act. (*Debugging Physics and Network Ownership*, worked example)
22. Use one mover per assembly. Movers need force limits (`MaxForce = mass × accel`). Never set CFrame every frame on unanchored parts, and never use `RigidityEnabled` for grabs. (*Mover Constraints and Physics Controllers*)
23. A player's knockback, ragdoll or state is applied **by the owning client** from a server decision. Server impulses on characters arrive late or are ignored. (*Physics Assemblies and Constraints*; *Snippets - Ragdoll*)
24. Ragdoll: `BreakJointsOnDeath=false`, `RequiresNeck=false` first, `NoCollisionConstraint` between neighbouring limbs, 1-2 s duration, and code that accepts `AnimationConstraint`. Add a respawn and stuck watchdog. (*Ragdolls and Physics-Based Animation*; *A Stuck Player Watchdog That Logs the Cause*)
25. Release logic runs on **every exit path** (death, leave, down, phase change, timeout, menu), guarded by a flag. (*Grabs, Carries and Throws - Moving Players Safely*)
26. Zones (truck bed, house, safe light) use **polled spatial queries at 5-10 Hz**, never `Touched` or `TouchEnded`. (*Intersection and Collision Math*; *Physics Performance*)
27. State goes in attributes, moments in remotes. Countdowns are an absolute `GetServerTimeNow()` end time. Every system needs a join snapshot. (*Debugging Client-Server Desync*; *Round-Based Minigame Loop End to End*)
28. No drivable or walkable moving truck in the MVP. If added later: players sit while it moves, the driver owns it, it is server-owned when empty. (*Ship a Game in 30 Days*; *Standing on Moving Vehicles and Platforms*; *Case Study - Dead Rails*)

**Data and money**
29. Save with `UpdateAsync` plus a lease and token. **A failed load never saves.** Use a parallel `BindToClose`, staggered dirty autosave, and schema versions with migrations forever. (*Session Locking and Profile Libraries*; *Saving Correctly - Autosave and BindToClose*)
30. Exactly one `ProcessReceipt`, idempotent on `PurchaseId`, with the grant and the id in the same write, and `PurchaseGranted` only after saving. Prices come from `GetProductInfoAsync`. (*Developer Products and ProcessReceipt*; *Pricing and Store Design*)
31. No paid power over others, no paid randomness, no revive prompts mid-chase, no purchase pop-ups in onboarding or on death. Starter pack only after a success. Apply the parent test. (*Ethical Design and Player Trust*; *Robux Price Points and Offer Design*)
32. Choose the private-server price once, because changing it cancels every subscription. (*Reserved and Private Servers in Practice*)

**Performance and art**
33. Phones fail on **draw calls, texture memory and transparency** before triangles. Import once and clone, recolour with `Color`, use ≤512 textures, and never unique textures per prop. (*Mesh Optimization for Mobile*; *Draw Calls*)
34. Anchor everything that doesn't need to move. Props stay anchored until grabbed. Use Box/Hull or invisible colliders, and turn CanCollide/CanTouch/CanQuery off on decoration. (*Physics Performance*; *Collision and Physics Geometry*)
35. Client scripts get about 2 ms per frame on a mid phone. Use one loop over many objects, pools instead of create/destroy, and do a **15-min real-phone soak** with full servers. (*Performance Fundamentals*; *Mobile and Low-End Optimization*)
36. Nights are tinted, never black. Don't rely on shadows (none below quality 4). Information never degrades by tier; only decoration does. (*Stylized Lighting Recipes*; *Juice on a Budget - Mobile and Low-End*)
37. One style everywhere, written as numbers, with golden assets. No mixed Toolbox styles, no raw AI meshes, and the mascot and logo are human-authored. (*Environment Art Styles*; *Style Bibles for Consistent Models*; *Who Owns AI-Generated Code and Assets*)
38. Group-own the game and upload every animation, sound and mesh **as the group**. Personal or Studio-only ids are silent live. (*Animation Asset Permissions and Groups*; *Music Licensing and Audio Upload Rules for 2026*)

**AI workflow**
39. Agents work in Edit mode only: no Play, no undo, calls under 1.5 s, a fresh read and clone-require before edits, the save gate, and no invented ids. Every report says "Edit-verified" or "play-tested". (*Safety Rules for AI Agents in Studio*; *Working with AI Assistants in Studio*)
40. Never trust a single AI score. Use 3 blind reviewers (median ≥8.5) at milestones only, and ship the best-scored version, not the latest. Look up only 2025-2026-sensitive topics through `vault.py`. (*Blind Review Scores - Noise, Panels and Shipping the Best Version*; *Token Cost Benchmarks*; *Benchmark - Does a Knowledge Vault Make AI Better at Roblox*)

---

## 11. Reference map: the best notes per topic
All paths are under `/home/user/lihfolk-cy/v2-vault/LihFolk Vault V2/` unless they start with `skills/` (plugin root). Prefer `vault.py --read "<title>" "<heading>"` over opening the files.

**Lookup infrastructure**
- `ROUTER.md`, `INDEX_SLIM.md`, `SYMPTOMS.md`, `Open Questions - Whole Vault.md`, `_tools/README.md`, `_data/roblox_facts_2026.json`
- `15 AI Tools/Token Cost Benchmarks.md`, `15 AI Tools/Benchmark - Does a Knowledge Vault Make AI Better at Roblox.md`
- `skills/lihfolk/SKILL.md`, `agents/lihfolk-lookup.md`

**Design, concept and genre**
- `52 Core Concepts/Core Loop.md`, `10 Game Design and Genres/Core Loops and Session Design.md`
- `10 Game Design and Genres/First-Time User Experience and Onboarding.md`, `10 Game Design and Genres/Onboarding by Genre - The First Five Minutes.md`
- `10 Game Design and Genres/Retention and Return Hooks.md`, `10 Game Design and Genres/Social Design and Multiplayer Play.md`
- `10 Game Design and Genres/Genre Playbook - Horror and Story.md`, `Genre Playbook - Zombie and Wave Survival Co-op.md`, `Genre Playbook - Survival and Crafting.md`
- `10 Game Design and Genres/Ethical Design and Player Trust.md`
- `59 Viral and Trend Game Teardowns/Viral Game Anatomy - Hooks, Loops and Timing.md`, `59 .../Teardown - Fling Things and People.md`, `59 .../Teardown - Natural Disaster Survival.md`, `59 .../Teardown - Build A Boat For Treasure.md`
- `32 Case Studies of Top Roblox Games/Case Study - 99 Nights in the Forest.md`, `Case Study - Dead Rails.md`, `Case Study - Doors.md`
- `60 High-Craft Game Teardowns/What Craft Looks Like on Roblox - Lessons from Top Studios.md`, `Teardown - Dandy's World.md`, `Teardown - Piggy.md`, `Teardown - Pressure.md`, `Teardown - Grace.md`, `Teardown - Welcome to Bloxburg.md`

**Discovery, marketing and launch**
- `49 Roblox Platform Features/Discovery and Monetization Changes 2025-2026.md` (authoritative on RFY), `11 Monetization Publishing and Live Ops/Discovery and the Algorithm.md`
- `61 Thumbnails and CTR/From CTR to CCU - Impressions, Play-Through and the Discovery Loop.md`, `61 .../Thumbnail Genre Patterns - What Top Games Show.md`, `61 .../Thumbnail Review Checklist and Scoring Rubric.md`
- `32 Case Studies of Top Roblox Games/Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks.md`, `27 Marketing and Growth/Game Icon Design - Readable at Small Sizes.md`
- `27 Marketing and Growth/Short-Form Video Marketing.md`, `Game Trailers and Clean Footage - Capture, Freecam and Editing.md`, `Launch Strategy - The First Two Weeks.md`, `Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics.md`, `Competitor Analysis Method.md`, `Update Cadence and Hype Cycles.md`
- `11 Monetization Publishing and Live Ops/Publishing an Experience.md`, `Age Checks and Safety Features.md`, `Thumbnails Icons and Store Page.md`, `Measuring Onboarding - Funnels, Drop-off and A-B Tests.md`, `Analytics and Funnels.md`, `Community Building.md`, `Live Ops Events and Updates.md`
- `49 Roblox Platform Features/API Renames and Deprecations 2025-2026.md` (the rename map and CI grep behind 5.9), `Friend Invites Referrals and Experience Invites.md`, `Experience Notifications and Return Prompts.md`, `Photo Mode and In-Game Screenshots with CaptureService.md`, `Policy and Age Rules 2026.md`, `Roblox Changes 2025-2026.md`, `Engine Limits, Quotas and Defaults - Cheat Sheet.md`, `Server Authority and Input Migration 2026.md`
- `26 Community and Moderation/Voice Chat and Safety Features.md`, `Working with Content Creators.md`
- `skills/roblox-trend-game/references/trend-games-research.md`

**Monetisation, economy and live ops**
- `11 .../Monetization Overview.md`, `Developer Products and ProcessReceipt.md`, `Pricing and Store Design.md`, `Robux Price Points and Offer Design.md`, `Ads and Rewarded Video.md`, `Subscriptions and Premium Payouts.md`, `Economy Inflation Sinks and Faucets Math.md`, `Roblox Policies Ratings and Compliance.md`
- `48 Economy Design Deep Dive/Currency Architecture - Soft Hard and Event Currencies.md`
- `38 Live Ops Deep Dive/Event Calendars and Content Planning.md`, `Feature Flags and Staged Rollouts.md`, `Patch Notes and Player Communication.md`
- `41 Multiplayer Services/Reserved and Private Servers in Practice.md`, `Parties and Group Teleports.md`, `Server Shutdowns Soft Updates and Migration.md`
- `28 Business and Careers/Legal Basics - IP Licenses and Assets.md`, `Open-Source Licenses for Roblox Libraries - Quick Reference.md`, `DevEx and Cashing Out.md`

**Physics, carry, ragdoll and AI**
- `09 Gameplay Systems/Grabs, Carries and Throws - Moving Players Safely.md`, `Physics Assemblies and Constraints.md`, `Mover Constraints and Physics Controllers.md`, `Downed, Revive and Bleed-Out States.md`, `Spawn Director - Credit Budgets and Player-Count Scaling.md`, `Clickable and Interactive Parts - ClickDetector, ProximityPrompt and Touched.md`, `Custom Character Controllers.md`, `Camera Obstruction Handling - Occlusion Modes, Fades and Collision.md`
- `03 Architecture and Networking/Network Ownership.md`, `Client-Server Model.md`, `Server Authority and Validation.md`, `RemoteEvents RemoteFunctions and Unreliable Remotes.md`, `Instance Streaming.md`, `Project Structure and Bootstrapping.md`
- `23 Debugging Deep Dives/Debugging Physics and Network Ownership.md` (pushable crate, WatchOwner, fling causes)
- `12 Performance Testing and Debugging/Physics Performance.md`, `Multi-Client and Live Testing.md`, `Multi-Client and Device Playtesting Protocols.md`
- `43 Genre Systems End to End/Horror Monster Chase AI End to End.md`, `Genre Systems Start Here.md`
- `25 Physics and Vehicles/Vehicle Damage, Repair and Wreck States.md` (delta-v damage), `Standing on Moving Vehicles and Platforms - Keeping Players Glued.md`, `Destruction and Fracture.md`, `Ropes Chains and Soft Bodies.md`
- `08 Animation/04 Procedural/Ragdolls and Physics-Based Animation.md`, `08 Animation/08 Snippets/Snippets - Ragdoll.md`, `08 Animation/01 Fundamentals/AnimationConstraint and Physically Simulated Characters.md`, `08 Animation/04 Procedural/IKControl Reference.md`, `08 Animation/05 Systems/Locomotion Systems.md`, `08 Animation/05 Systems/Emotes and Social Animation.md`, `08 Animation/01 Fundamentals/Animation Asset Permissions and Groups.md`
- `56 Field Notes/A Stuck Player Watchdog That Logs the Cause.md`, `Server-Authoritative Freeze and Stun Timestamps.md`, `Streaming Joins - Frozen Players and Loading Screen Teardown.md`, `ProximityPrompt Gamepad Keys and the Hidden PlayerList Tab.md`
- `22 Anti-Exploit and Security/Detecting Movement Exploits - Speed Fly Noclip Teleport.md`, `How Exploits Work - The Client Boundary.md`, `Threat Modeling a Roblox Game.md`, `Economy Exploits - Dupes Races and Purchase Abuse.md`, `Creator Account Security and Takeover Recovery.md`
- `62 Engine Reference Cards/BasePart - Engine Reference Card.md`, `Humanoid - ...`, `RemoteEvent - ...`, `ProximityPrompt - ...`, `PhysicsService - ...`, `RunService - ...`, `TeleportService - ...`, `DataStoreService - ...`, `MarketplaceService - ...`

**Data and systems**
- `04 Data and Persistence/DataStore Fundamentals.md`, `Saving Correctly - Autosave and BindToClose.md`, `Session Locking and Profile Libraries.md`, `Purchase Data and Receipts.md`, `Global State and Live Config.md`
- `24 Worked Builds/LihFolk Systems Library.md`, `Round-Based Minigame Loop End to End.md`, `Worked Builds Start Here.md`
- `skills/lihfolk-systems/SKILL.md`, `skills/roblox-system-builder/SKILL.md`, `skills/roblox-secure-remotes/SKILL.md`, `skills/roblox-datastore-safety/SKILL.md`
- `29 Luau Cookbook/Cookbook - Remotes and Networking.md`, `Cookbook - Players and Characters.md`, `Cookbook - Data and Saving.md`; `02 Luau Scripting/CollectionService Patterns.md`, `Script Types and Run Context.md`, `Luau Performance Patterns with Benchmarks.md`; `40 Game Math/Intersection and Collision Math.md`, `Probability and Statistics for Designers.md`

**UI, UX, onboarding and accessibility**
- `05 UI and UX/Onboarding and FTUE - Tutorials That Keep Players.md`, `Tutorial Step Design Patterns - Teach by Doing.md`, `HUD Design.md`, `Responsive UI for Phone Tablet Console and PC.md`, `Input - UserInputService and ContextActionService.md`, `Nametags and Overhead Bars - Cost and Visibility Rules.md`, `Off-Screen Objective Markers and Waypoint Arrows.md`
- `58 Player QoL and Game Tweaks/Loading Screen Skip and First-Session Goals.md`, `Joining Friends Parties and Private Servers.md`, `Hold vs Toggle Auto-Sprint Auto-Equip and Quick Slots.md`, `Settings Menu Essentials and Persistence.md`, `Top 25 QoL Wins by Effort.md`, `QoL Audit Checklist.md`
- `42 Accessibility and Inclusive Design/Motion Sensitivity and Camera Comfort.md`, `Captions and Audio Accessibility.md`
- `skills/lihfolk-tutorial/SKILL.md` (+ `references/ftue-checklist.md`, `step-design-patterns.md`), `skills/roblox-ui-builder/SKILL.md`, `skills/quality-score/rubrics/tutorial.md`, `rubrics/ui.md`

**World, art, lighting, audio and VFX**
- `06 World Building and Art/House Construction Method - Modular Kit Workflow.md`, `Collision and Physics Geometry.md`, `Art Budgets - Triangles Draw Calls Memory.md`, `Environment Art Styles.md`, `World Composition and Set Dressing - Designed, Not Scattered.md`, `Water Sky and Atmosphere Art.md`
- `33 Level Design/Teaching Through Level Design.md`, `Kill Planes, Map Boundaries and Out-of-Bounds Recovery.md`, `Spawn Points Safe Zones and Respawn Flow.md`, `Lobby and Hub Design.md`, `Playtest Heatmaps - Position and Death Maps.md`; `34 Procedural Generation/Dungeon and Room Generation.md`, `Seeds Determinism and Reproducible Worlds.md`
- `14 3D Modeling/Mesh Optimization for Mobile.md`, `Modular Environment Kits.md`, `Exporting and Validating Models for Roblox.md`, `Modeling Weapons and Props.md`, `Mesh Gates for Generated Models - Symmetry, Seating and Caps.md`
- `54 Untextured Stylised Modelling/The Gradient Palette Texture Workflow.md`, `Lighting Untextured Art in Roblox.md`, `Colour Scripts and Value Structure for Untextured Art.md`, `Keeping a Mixed Asset Library Consistent.md`
- `55 Modelling Nuance and Readability/Modelling to the Roblox Camera and Player Scale.md`, `Proportion Exaggeration and Gameplay Distance.md`, `Shape Language and Silhouette Testing.md`, `Style Bibles for Consistent Models.md`, `Spending Triangles Where the Camera Looks.md`
- `45 Procedural Blender Assets/Procedural Blender Assets Start Here.md`, `Stylised Log Cabin Worked Example.md`, `Chibi Character Rules in Practice.md`, `Blender 5 Python Gotchas for Headless Builds.md`; `skills/roblox-blender-modeling/SKILL.md` (+ `scripts/lihfolk_bpy.py`, `lihfolk_house.py`)
- `07 Lighting VFX and Audio/Lighting Mood and Time of Day.md`, `Stylized Lighting Recipes.md`, `Light Sources and Shadows.md`, `Highlights and Selection Effects.md`, `The Audio API - Players Emitters Wires and Effects.md`, `Spatial Audio and Mixing.md`, `Ambient Soundscapes - Layer Stacks, Overlapping Zones and Voice Pools.md`, `Impact Decals and Material-Aware Hit Sparks.md`, `Music Licensing and Audio Upload Rules for 2026.md`, `Gore Policy and Kid-Friendly Hit Feedback.md`, `VFX Performance Budgets and Culling.md`, `Replicating VFX - Server Validates, Clients Render.md`
- `47 Game Feel and Juice/Juice on a Budget - Mobile and Low-End.md`, `Input Responsiveness Buffering and Coyote Time.md`, `Feedback Timing - Sound Visual and Haptic Sync.md`, `Reward Moments and Celebrations.md`, `Squash Stretch and Anticipation in UI and Characters.md`, `Hit-Stop and Screen Shake Tuning by Numbers.md`
- `skills/lihfolk-worldbuilding/SKILL.md` (+ `references/budgets.md`), `skills/lihfolk-sfx/SKILL.md`, `skills/lihfolk-vfx/SKILL.md`

**AI workflow, production and testing**
- `16 MCP and Agents/AI-Ready Project Boilerplate - Repo Layout Agents Navigate Well.md`, `Agent Handoff Notes - Project State and Resume Templates.md`, `Roblox Studio MCP Server.md`, `Safety Rules for AI Agents in Studio.md`, `Setting Up MCP Clients.md`, `MCP Workflows for Scripting and Debugging.md`, `Agent Review Loops and Guardrails in Practice.md`, `Case Study - Building a Game with AI Agents.md`
- `15 AI Tools/Prompting and Verifying AI Output.md`, `What AI Models Get Wrong in Roblox.md`, `AI Pitfalls - Physics and Animation.md`, `AI Pitfalls - Networking and Security.md`, `Roblox Policies on AI-Generated Content.md`, `AI Image Generation for Icons Thumbnails and Concepts.md`
- `01 Studio and Workflow/Testing Modes - Play Run and Multi-Client.md`, `External Tooling - Rojo Wally Selene StyLua.md`; `17 Pipelines/Code Pipeline - Rojo Git and CI.md`, `Pipeline Design Principles.md`, `Data and Config Pipeline - Spreadsheets to Game.md`, `Environment and Level Pipeline.md`
- `56 Field Notes/Running Many AI Agents on One Roblox Place.md`, `Studio Automation Without Freezing Studio.md`, `Blind Review Scores - Noise, Panels and Shipping the Best Version.md`
- `13 Production and Case Studies/Ship a Game in 30 Days - Week-by-Week Plan for a Solo Dev.md`, `Planning and Scoping a Roblox Game.md`, `Working with AI Assistants in Studio.md`, `Case Study - Building LihFolk V2 with AI Agents.md`, `Case Study - Fast Join and Deferred Loading.md`, `Release Process and Rollbacks.md`, `Live Incident Response and Post-Mortems.md`, `Lessons Learned Index.md`
- `50 Team Collaboration and Project Management/Roadmaps Milestones and Scope Control.md`
- `12 Performance Testing and Debugging/Performance Fundamentals.md`, `Mobile and Low-End Optimization.md`, `Network Bandwidth Budgets and Measuring Them.md`, `Client Zone Culling for Interiors and Cities.md`, `Automated Luau Checks - LihFolk Hook and Audit.md`
- `skills/quality-score/SKILL.md`, `skills/council-method/SKILL.md`, `skills/roblox-performance-audit/SKILL.md`, `skills/roblox-debugging/SKILL.md`, `skills/roblox-anti-exploit-review/SKILL.md`, `skills/roblox-monetization-compliance/SKILL.md`, `hooks/README.md`, `commands/audit.md`

---

*End of bible. Update rule: when a decision changes, edit the relevant section, add a dated line to `docs/DECISIONS.md`, and keep this file the single source of design truth. Keep platform facts dated and re-verify them with `vault.py` before acting on anything policy- or money-related.*
