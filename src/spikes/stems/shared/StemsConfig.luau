-- Stem alignment spike (S4, MASTERPLAN §8.11 and §7.2 "Crew Layers"): every
-- tuning number and asset id for the spike lives here. The spike is a separate
-- place (spikes/stems.project.json), so it keeps its own config instead of the
-- game's src/shared/Config.luau.
--
-- HOW TO TEST WITH REAL MUSIC (owner)
--   1. In Studio open Toolbox > Creator Store > Audio (or create.roblox.com >
--      Creator Store > Audio) and pick two Roblox-licensed music tracks
--      (publisher "Roblox", APM or Monstercat; anything the Creator Store marks
--      as free to use in your experiences). Best: two stems or two mixes of the
--      SAME track, so they have the same tempo and length.
--   2. Copy each track's asset id (the number in its URL) and paste it below as
--      STEM_A = "rbxassetid://<id>" and STEM_B = "rbxassetid://<id>".
--   3. Set TRACK_BPM to the tracks' tempo (or keep 128 for the plan's grid).
--   4. Rebuild the spike place and publish it again (README "Spike S4: stems").
-- Your own uploaded audio also works if the asset is allowed for this experience.
--
-- The defaults are the engine-bundled running-footsteps loop on BOTH players:
-- identical audio makes any misalignment easy to hear (a doubled, flanging or
-- "jet" sound instead of one louder sound), and the measurement still works.

local StemsConfig = {}

StemsConfig.STEM_A = "rbxasset://sounds/action_footsteps_plastic.mp3"
StemsConfig.STEM_B = "rbxasset://sounds/action_footsteps_plastic.mp3"

-- Loop grid (§7.2: 128 BPM, runs are whole bars). A test loop is LOOP_BARS bars;
-- the asset itself loops (Looping = true) if it is shorter than that.
StemsConfig.TRACK_BPM = 128
StemsConfig.BEATS_PER_BAR = 4
StemsConfig.LOOP_BARS = 4 -- 4 bars at 128 BPM = 7.5 s per loop
StemsConfig.LOOPS = 8 -- the S4 pass bar: no audible drift over 8 loops

-- Scheduling
StemsConfig.LEAD_SECONDS = 0.3 -- Play(atTime) is scheduled this far ahead of GetMixerTime()
StemsConfig.GAP_SECONDS = 0.6 -- silence between loops (stands in for the rewind)
StemsConfig.SETTLE_SECONDS = 0.1 -- drift samples start this long after a loop starts
StemsConfig.FADE_BARS = 1 -- fallback: a layer fades in over one bar (1.875 s)

-- Deliberate offset for stem B in the scheduled modes. It calibrates both the
-- meter (the reading should match it) and your ear (what 10/20/40 ms sound like).
StemsConfig.OFFSETS_MS = { 0, 10, 20, 40 }

-- Verdicts
StemsConfig.PASS_DRIFT_MS = 20 -- feel.md: resync on the next bar if drift exceeds 20 ms
StemsConfig.LENGTH_TOLERANCE = 0.05 -- s; stems longer apart than this cannot be compared after a wrap

-- Mix
StemsConfig.VOLUME_A = 0.5
StemsConfig.VOLUME_B = 0.5
StemsConfig.LOAD_TIMEOUT = 20 -- s to wait for IsReady

-- Readout
StemsConfig.READOUT_HZ = 4

return StemsConfig
