# Critique B of PLAN_STEAM_PLUS (senior Roblox engineer/producer + kid-UX lens)

**Verdict: APPROVE WITH CHANGES.** The diagnosis and quality bar are right, but S1 misses the likeliest cause, the R3 PhotoBooth can't photograph clones, and the schedule hangs on owner clicks and on a Roblox review the plan never mentions. Fix the ten items below first.

---

## Top 10 required changes (ranked, paste-ready)

### 1. S1: replace the suspect list and the test (clone invisibility)

**What I found in the code:** the avatar path has never run in the engine. `tests/engine_smoke.luau:322-365` uses a fake member with no template, so it only draws the **mannequin**, and its check reads `echo.positionOf`, which is maths on the recording (`EchoView.luau:449-454`), not a part: it passes even if nothing renders. `engine_smoke.luau:776-806` strips a rig but never parents it to `workspace` or steps physics. So stripped template → client clone → root-only `BulkMoveTo` (`Rigs.luau:304-308`) is untested.

**Suspects, re-ranked:**

- **(A) The body comes apart and falls; only the root moves.** `Avatars.luau:94-111` destroys every `ValueBase` (body scales, `OriginalSize`) and every Attachment no accessory uses, including all `*RigAttachment`s. Only the root is anchored, and it is `Transparency 1` (`Avatars.luau:123-127`). If the Humanoid rescales or rebuilds joints from attachments once the copy enters `workspace`, the Motor6Ds go and the unanchored limbs fall into the void, taking the badge on the Head with them (`EchoView.luau:164-166`). Result: **no body and no badge**, as the owner saw, while `positionOf`, audio and every test stay green.
- **(B) Rendered but unseeable.** The avatar rig has no emissive part: SmoothPlastic (`Avatars.luau:85`) in a hue dimmed to as low as 35 % (`EchoView.luau:242-246`). The Highlight is outline-only (`EchoView.luau:140`) and is turned off at tier 4 (`EchoView.luau:143, 570-575`), and the governor only steps down (`Telemetry.luau:153`). At 1-3 % luminance that is black on black, though the badges would still show.
- **(C) Unlikely:** a skipped recording (`EchoView.luau:296`) or the 0.7 near-camera fade (Config 273-274).

**Ask the owner one question now:** "Did you see the floating ●1 badges?" No → A. Yes → B.

**The test that works headlessly (R1, Open Cloud on the server):**
1. Build real templates with `GetHumanoidDescriptionFromUserIdAsync` + `CreateHumanoidModelFromDescriptionAsync` + `Avatars.strip`. Use three descriptions: default, Rthro scales (BodyTypeScale 1), and one with layered clothing.
2. Put them in `ReplicatedStorage.HeistAvatars/<fakeId>`. Run `EchoView.setRun` and `update` from the L1 run-2 recording, over **3 s of real Heartbeats**. The server steps physics for unanchored parts exactly as a client would.
3. Assert, per clone: `rig.kind == "avatar"`; ≥ 15 Motor6Ds with `Part0` and `Part1` set; every BasePart parented and within 5 studs of the root; Head and badge alive; `Transparency + LocalTransparencyModifier < 0.5`; Highlight on at every tier; the walk track plays while moving.
4. "On screen" check: do the frustum maths yourself, because the server's `CurrentCamera` has no real viewport. Use FOV 70 at 16:9 and 19.5:9 from the default camera offset, and `workspace:Raycast` from the camera to the Head against the level, which must not be occluded.
5. Light check: the R0 luminance model applied to the clone material must give ≥ 25 %, or the clone must carry an unlit component.

**Ship as well, in phase 1:**
- Highlight `FillTransparency 0.55`, never turned off for your own clones.
- A runtime `CloneHealth` self-check every second (limb-to-root distance, Head alive). On failure, swap to the mannequin and send `Telemetry.ui("CloneHealth", reason)` (an already-approved remote).
- A **Studio-only diagnostic chip** ("clones 3 drawn / 3 healthy / tier 1 / avatar"), so every owner screenshot carries the diagnosis.

### 2. Rebuild R3/R4. A PhotoBooth in Edit mode can't photograph a clone

Clones, the backdrop (W4) and the LightDirector are all **built on the client**, so an Edit-mode capture shows none of them. A Play-mode capture needs `StudioCaptureService` in the client DataModel [verify], a GitHub PAT in plugin settings, a PNG encoder in Luau for an 8 MB frame, and a way to stage "L1, run 3, 2 clones".

Phone Photo mode is worse: `CreateEditableImageAsync` from a capture fails for some developers, it needs a new upload remote, and the DataStore scope (D5) is **still unconfirmed**.

**Replace with:**
- **(a) Day 1:** a pinned GitHub issue "Shots inbox". The owner drops Studio or phone screenshots into it from any device; Claude pulls them with `gh`. Zero code.
- **(b) A 2 h spike:** Remote Control on the owner's PC, so Claude can drive Studio MCP Play and capture.
- **(c) The PhotoBooth** only if (b) fails and a Play-mode capture spike passes. Stage scenes with a Studio-only `EH_Scenario` attribute, not a new remote.
- **Drop phone Photo mode before launch.**
- **Change the rule:** R3 is required **at phase gates (batched)**, not per item. Per item, owner clicks become the serial bottleneck for about 40 visual items.

### 3. Cut phase 1 to what can actually ship on Sun Nov 15

Phase 1 packs about 9 agent-days into 3 calendar days, and "all text glyphs replaced" needs the phase-2 icon sheet.

**Phase 1 =**
- the clone fix (item 1);
- recipe A plus pools in L1/L2, and the floor swatch;
- the player list fix, the Studio save chip, P0-1;
- ◀◀ REWIND (as an image);
- glyphs replaced by **words** as a stopgap ("MENU", "FAST").

**Move to phase 2:** backdrop v1 and any capture tooling.

### 4. Add a day-0 refactor so parallel tracks don't collide

`Hud.luau` is 2,382 lines. U3-U6, O, F2, C3, the words pass and stuck help all edit it, and every track edits `Config.luau`.

**Before tracks fork (1 agent-day):** split Hud into `TopBar`, `Deck`, `Results`, `Garage` and `Hints` modules, extract `Strings.luau`, and move `Config.Heist.UI/FX/CAMERA` into their own files.

**Then:** one owner per file; a single integrator merges daily with full CI plus the three engine suites; a serial publish slot (409 rule).

Add a Lune **HUD layout check** (boxes as data, no overlap at the 7 viewports): UI has almost no automated coverage today.

### 5. Re-plan around the real critical path: the Kids & Select review

Until review passes, a new game reaches only 16+ users. Review takes about 48 h, restarts after a fix, and 8+ day stalls are on record (MASTERPLAN). Dec 10 plus a stall misses the Dec 18 school break: the 8-13 audience is gated by review, not polish.

**Proposal:**
- **Go public Thu Dec 3** with the vertical slice (low exposure, 16+ only) and submit expedited review that hour.
- Ship polish as updates through Dec 10 [verify that updates don't restart the review].
- Start marketing and creators only once all ages are open **and** the Dec 10 build is in.
- Write the **Dec 10 cut list** now: L3, L6 and the 12 dailies at a "readability bar" (recipe, words, icons, no per-room dressing); garage v1; Gus with 6 beats, not 10.
- Add a 25 % integration tax to the 53 days.

### 6. Fix the kid-test protocol, and add a round 0

**Round 0 (Nov 15-16):** one or two kids on v24, 15 min. That is the cheapest signal in the whole plan.

**Missing from the protocol:**
- **The kid's own avatar:** "it's me" is the core fantasy, but a private place forces the owner's account. Confirm early-tester invites for under-13 accounts [verify], or let the kid restyle a spare account first.
- Written parental consent; film the **screen only**.
- The kid's own phone, plus one low Android.
- **20-25 min**, not 10 (the confusion starts after L1); half the kids start at L2.
- One co-op pair of friends; one weak or non-native reader.
- No helping: count help requests on a timestamp sheet.
- Neutral questions ("What happened when you pressed that?"), not the leading "What are the glowing people?".
- Pass bars written down before the test.

### 7. Adjust the onboarding for 8-13s on phones

**Flyovers:** play them only **inside time that already exists** (the van door, the rewind transition); any touch skips them; once per level per account; **never before first control on L1** (the 30 s first-clone bar).

**Kids don't read; they follow motion.** Add an animated **finger pointer** on REWIND and GRAB the first time each is the right move.

**Stuck help:**
- Make the WALKTHROUGH P0-4 world-state lines explicit for L2-L4. The plan only states the rule.
- The Mentor shows **the next step**, not the whole solution, and only after a "Show me?" chip, so kids who are exploring aren't spoiled.

**D3 reverses the owner's "party break" order** (PROJECT_STATE). Keep that order and give the Party a **dozing Gus** with a 3 s intro, or Catalog, funnel, Pacing and unlock specs churn again.

### 8. Bring performance forward to phase 1-2; it can't wait for phase 4

**Close the open benches first.** The S1 clone phone bench has been waiting for results since W1.

**Budget the 8-player case:** one Highlight per owner means up to 8 (the budget allows 4+1, and the first costs about 1 ms of GPU on mobile), plus 2-3 BillboardGuis per clone across 12 clones and 16 Line-up figures.

**Decide on StreamingEnabled.** It is off, so all 8 instances' kit levels replicate to every phone. Add an R1 count with 8 instances live, then either flip it (persistent level models) or accept it in writing with a memory number.

**Lighting by tier:** the LightDirector switches to recipe C at tier ≥ 3 by itself; luminance targets are checked at **Q1** (voxel leak through thin walls, black fog, no Bloom); the governor can step back up.

### 9. Time-box the animation path and verify it headlessly

**Spike, fully headless:** Lune writes a 2-key KeyframeSequence `.rbxm`, Open Cloud uploads it under the experience owner, and a server-side Animator plays it on an R15 rig; assert that `Motor6D.Transform` changes. **Default:** catalog packs for walking, the existing Lua pose player for plate, carry, stuck and busted. Uploads only if the spike passes within 2 h (D6 depends on it).

### 10. Make the owner's load honest, and automate more of it

The real load is **8-12 h**, not 2-3: kid tests with recruiting and consent (2 × 2 h), about 10 builds × 15 min, the audio pass (about 1 h), and the backlog (S1/S3/S4 benches, dev products, Max Players, ID/2SV, DataStore scopes, Robux for review).

**Automate:** dev products and Max Players through Open Cloud (scopes asked once) [verify the endpoints]; an **audio audition page** (Artifact) with keep/replace checkboxes; the screenshot inbox (item 2).

**Batch** owner work into three fixed sessions: Sun Nov 15, Sun Nov 22, Sat Nov 28. Not "after every publish".

**Answer the maturity questionnaire this week.** "Heist", "robbery" and "BUSTED" chases must still come out as Mild, or the label changes who can play.

---

## Feasibility of the risky techniques

PhotoBooth and Photo mode: item 2. KeyframeSequence upload: plausible, item 9. Recipe A on low phones: OK if read at Q1; watch Beam overdraw (item 8).
- **Oswald:** built in (`Font.fromName("Oswald")`), so low risk. Preload it, check the Bold weight in the engine test, and use it for stamps of ≤ 3 words only: condensed capitals slow early readers.

## Timeline: where it slips

- **Phase 1:** overfull (item 3).
- **Phase 2:** the UI kit and icons gate U3-U6 and every moment. The icon upload and moderation lag isn't scheduled.
- **Phase 4:** six days for three levels, 12 dailies, the phone pass, the bench, store art, 8 clips and kid test 2. It slips here.

**True critical path:** clone root cause → owner confirms v24 → UI kit and icons → slice moments → kid test 1 → fixes → **review lead time**. Owner R3 clicks are a hidden serial resource across all tracks.

As written, the full scope lands around **Dec 17-21**. Dec 10 is right only with item 5: public Dec 3 for the review, the cut list, and the go/no-go moved to **Thu Dec 3**.

## Other missing risks

- **Publishing:** a publish 409s while Studio holds the place, so each one needs the owner.
- **Regressions:** the words pass changes strings that tests assert. Migrate to `Strings.luau` first.
- **Proof limits:** "Never invisible at every quality level" can't be proven headlessly. The proof is the R1 check plus R3 at Q1 and Q10.
- **Self-grading:** blind agent reviews grade the same author's shots. Weight kid evidence above rubric scores.
