# RAGDOLL HAVOC: why players leave (2026-11-19)

Source: the game's own DataStore `Session_v1` (one record per visit, 1,126 visits, 930 players), read only through Open Cloud Luau Execution on universe 10774775314. Store page data from the games API. A local script snapshot of live place version 465 is in /home/user/ragdoll-havoc/place. It is not pushed anywhere: the owner's project folder is RagdollLab on their PC.

## Headline numbers
- **Session length:** median 52 s. 31 % of sessions end within 30 s, 55 % within 60 s, 91 % within 5 min.
- **Returning players:** 123 of 930 came back (13 %). The median second visit lasts 35 s.
- **Traffic by day:** 11-10 284, 11-11 490, 11-14 277 (ads), then 1-7 a day.
- **Store page:** 1,302 visits, 0 playing, 5 upvotes / 2 downvotes, 17 favourites.

## Root causes, with evidence
1. **Console players cannot shoot.** 216 sessions (19 %) were on console, and 97 % of them never fired a shot. Shooting only listens to MouseButton1, Touch and the keyboard slot keys (`Client/TouchShoot.luau:117,124`, `Client/PokeController.luau:1704-1739`). There is no gamepad binding at all.
2. **26 % of PC sessions never fire a shot** (phone 13 %, tablet 18 %). The first shot was designed to land within 5 s, but the median is 9 s and the 90th percentile is 31 s.
3. **0.17.1 is worse than 0.14.0.** On the same day (11-10), the median session was 85 s on 0.14.0 and 54 s on 0.17.1. Something between place versions ~440 and ~465 shortened sessions. Candidates: the locked starter bar or `UNLOCK_FALLBACK`, the free-egg card, and the lab view choice. Next step: diff the two versions.
4. **Ad traffic left even faster:** median 33 s on 11-14.
5. **No differentiation, and no goal past minute 1.** It is the same organ/bones dummy sandbox as Hyper Realistic Ragdoll (65k CCU) and Ragdoll Research (11.7k CCU).
6. **Maturity.** `Config.SEVERING = true`, together with 🩸 and organs in the description. Roblox lists severed body parts as Restricted (18+, ID-checked).
