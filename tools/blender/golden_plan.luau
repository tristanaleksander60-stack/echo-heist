--!strict
-- Dumps what the first-person golden frames need (docs/GOLDEN_FRAMES.md G1-G3, REVIEW_STEAM_PLUS #4) as JSON for
-- tools/blender/level_shots.py --golden-fp: the staged looks (Config.Heist.CAMERA.GOLDEN + Shared/Heist/Scenario, the
-- same functions Heist/GoldenShots calls), the G2 clones where the staging tapes put them at the 8 OF ME moment
-- (src/server/Heist/StagingTapes: the Clone Party solution's first 7 runs, decoded with Rec/Codec and sampled at
-- `t` s into the run), each clone's crew hue as EchoView draws your solo runs (CloneState.driftHue + Palette.dim),
-- and the first-person hands' rest pose (Config.FirstPerson.VIEWMODEL.REST).
--   lune run tools/blender/golden_plan.luau [t] > golden_plan.json

local process = require("@lune/process")
local serde = require("@lune/serde")

local CloneState = require("../../src/shared/Heist/CloneState")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local L1 = require("../../src/shared/Levels/L1_BackRoom")
local L5 = require("../../src/shared/Levels/L5_CloneParty")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Scenario = require("../../src/shared/Heist/Scenario")
local StagingTapes = require("../../src/server/Heist/StagingTapes")

local t = tonumber(process.args[1]) or 5
local G = Config.Heist.CAMERA.GOLDEN
local EYE = 3.8 -- the Rookie's eye over the floor in first person (CameraDirector fp)

-- G1: the eye at L1's first spawn, the staged look at the cash
local level = LevelSpec.compile(L1)
local sp = level.spawns[1]
local stand = G.G1.STAND or { sp.x, sp.z }
local eye1 = { stand[1], (level.floorY or 0) + EYE, stand[2] }
local cash = { 0, 0, 0 }
for _, item in level.loot do
	if item.id == G.G1.LOOT then
		cash = { item.x, item.y, item.z }
	end
end
local yaw1, pitch1 = Scenario.fpLook(G.G1, eye1, cash)

-- G3: the stand in the hideout's aisle, the staged look between the job board and your van
local o = Config.Heist.LOBBY_ORIGIN
local eye3 = { o[1] + G.G3.STAND[1], o[2] + EYE, o[3] + G.G3.STAND[2] }
local yaw3, pitch3 =
	Scenario.fpLook(G.G3, eye3, { o[1] + G.G3.LOOK_AT[1], o[2] + G.G3.LOOK_AT[2], o[3] + G.G3.LOOK_AT[3] })

-- G2: the 7 tapes at t, oldest first, with EchoView's solo hue ramp (seat 1: Palette.CLONE_HUES[1])
local recs = {}
for _, buf in StagingTapes.buffers() do
	local rec = Codec.decode(buf)
	if rec then
		table.insert(recs, rec)
	end
end
local n = #recs
local clones = {}
for k, rec in recs do
	local i = math.clamp(math.floor(t * rec.hz) + 1, 1, rec.n)
	local rank = n - k -- clone 1 is the oldest run
	table.insert(clones, {
		x = rec.px[i],
		y = rec.py[i],
		z = rec.pz[i],
		yaw = rec.yaw[i],
		rank = rank,
		hueShift = CloneState.driftHue(0, rank, n, true),
		dim = math.max(1 - Config.Heist.CLONE_AGE_DIM * rank, 0.35),
	})
end

print(serde.encode("json", {
	eyeHeight = EYE,
	G1 = { eye = eye1, yaw = yaw1, pitch = pitch1, fov = G.G1.FOV, cash = cash },
	G2 = {
		t = t,
		level = StagingTapes.LEVEL,
		clones = clones,
		you = (function(): { number }
			local party = LevelSpec.compile(L5)
			local s5 = party.spawns[1]
			return { s5.x, s5.y, s5.z }
		end)(),
		pitch = G.G2.PITCH,
		fov = G.G2.FOV,
		yaw = G.G2.YAW,
		centralShare = Config.Heist.CAMERA.LINEUP.CENTRAL_SHARE,
		fill = Config.Heist.CLONE_FILL_TRANSPARENCY,
		bandAlpha = Config.Clone.PRINT_BAND_ALPHA,
	},
	G3 = { eye = eye3, yaw = yaw3, pitch = pitch3, fov = G.G3.FOV },
	hands = Config.FirstPerson.VIEWMODEL.REST,
}, false))
