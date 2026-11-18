# Decision memo: keep going with Heist Yourself, or switch to the ragdoll game? (2026-11-18)

## The data

### Our game, live since Nov 13
- Store page: 382 visits, 0 playing, 4 upvotes / 1 downvote, 7 favourites.
- Our own data: 129 profiles. 34 % never started a heist, 16 % quit inside L1, and 10 % reached L3. Nobody came back on a second day and nobody bought anything.
- The game does not show up in Roblox search, even for its own name.
- docs/audit/WHY_2_OF_10.md rates it about 2/10 as players see it. Reaching ~7/10 takes 2-3 weeks; reaching 8.5/10 takes 6-10 weeks plus paid freelancers (characters, animation, music).
- **The clone idea has a weak market record.** "Clone" search results today total 15k CCU across the top 40. Clone Yourself has 184 CCU and Clone Ragdoll 218 CCU. ECHOES: Clone Puzzles had 0 players on Nov 12 (MASTERPLAN).

### Ragdoll games right now (Roblox games API, 2026-11-18)
- The "ragdoll" search returns **about 231k CCU** across its top 40 games. On Nov 11 it was about 150k, so the wave is still growing.

| Game | CCU | Created | Up / down votes |
|---|---|---|---|
| Hyper Realistic Ragdoll | 65,469 | Oct 29 | 23.5k / 2.7k |
| Ragdoll Soccer | 52,205 | Oct 13 | 21.9k / 7.8k |
| BloxNG [CRASH PHYSICS] | 35,077 | Oct 13 | |
| Realistic Ragdoll MMA | 23,309 | **Nov 5** | 8.3k / 2.6k |
| Ragdoll Research | 11,689 | Oct 28 | |
| Ragdoll Destruction Playground | 9,063 | **Nov 3** | |
| Ragdoll Experiment | 7,830 | **Nov 4** | |

- **Late entrants are still breaking through.** Games created Nov 3-5 reached 8-23k CCU within two weeks.
- **The open lane from FINAL_IDEA_STUNT_CREW.md is still open.** The leaders are violent sandboxes, MMA or soccer. None is a kid-friendly co-op game with goals and progression.
- For comparison, heist games excluding Steal An Egg: Criminal Simulator has 16k CCU and Risky Heist has 3.7k (created Oct 29).

## Recommendation: switch focus to the ragdoll game, and take the best parts of Heist Yourself with you

1. **Demand.** The ragdoll market is about 15x larger than the clone-plus-small-heist space and is still growing. Games created two weeks ago are at 8-23k CCU. Waves like this last weeks to months, so speed matters more than polish.
2. **Our game needs a rebuild either way.** Fixing Heist Yourself means new levels with danger, a new art approach, the avatar back, and a meta loop. That is close to new-game work, aimed at a market that has never carried a clone game.
3. **Ragdoll suits what we are good at.** Physics comedy reads at 2/10 graphics. Most top ragdoll games are simple-looking baseplates. Fun comes from physics and friends, not art. The art gap that sank Heist Yourself matters much less.
4. **Much of our tech carries over:**
   - the **recording/replay system**, which becomes the auto "BEST TAKE" replay clip (the viral lever in the Stunt Crew concept) and could become "your earlier takes as stunt doubles";
   - data and profile safety, analytics and funnel tools, LiveFlags, badges, secure remotes (Net), the UI kit, the Open Cloud test and publish pipeline, and the kit upload pipeline;
   - the lessons learned: avatar on, third person by default, straight into the action, live captures instead of Blender grades, and kid tests.

## What NOT to do
- Don't run both at full speed. Put Heist Yourself on maintenance: keep it live and keep the badges, but add no new features. Revisit it only if the ragdoll game is live and stable.
- Don't make yet another violent sandbox. The lane is **kid-friendly, goal-driven co-op ragdoll** (Mild rating), with a reason to come back every day.
- Don't spend weeks on art before the core is fun. Ship a playable core in about 7-10 days, then iterate on live data.

## Risks
- **Saturation.** 50+ ragdoll games launched in six weeks. Win on co-op goals, progression and the auto-clip, not on the physics alone.
- **Timing.** The wave may cool by January. Launch before Christmas, with a Christmas set.
- **Physics on phones.** Ragdolls are expensive. Budget the number of active ragdolls per server from day 1 (Config.Perf pattern).
- **"Ragdoll spillet" may already exist.** If the owner already has a ragdoll project in another repo or session, it should be attached here (add_repo) before planning work on it. This session only has the concept doc (game-brain/FINAL_IDEA_STUNT_CREW.md).

## Owner decisions needed
1. Approve the switch, with Heist Yourself on maintenance.
2. Confirm what "the ragdoll game" is: a new build from the Stunt Crew concept, or an existing project (repo name).
3. Set the ad budget only after the new game's first-session funnel passes a kid test.
