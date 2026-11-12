--!strict
-- Heist/LevelIntro: a level's first look (PLAN_STEAM_PLUS §4.2 C2, §5 "L2 first look", "Party opening").
-- On the first entry to each level (once per account: FirstTime kind "intro:<data key>", seeded from the
-- profile's level plays) the camera glides over the key objects, plates -> doors -> loot (L2: plate A,
-- door A, plate B, door B, the safe), while the level's goal line comes up; the Party holds on Gus
-- dozing in the back office (his "zz", the GUS nameplate and "That's Gus. Don't wake him." are
-- GusView's and Hud/Hints' own). Then the run-start beat (CameraDirector.frameRunStart) holds on the
-- last stop and eases back to you.
--
-- Time: only the time that already exists. It runs inside the first run's transition, while the van
-- doors part, and always hands back before control returns (the server's clock, not ours); with a
-- short transition PresentPlan.introPlan keeps fewer stops instead of whip-panning. Never on L1 (its
-- first look is the title beat), never on a daily vault, never under reduced motion. Any touch, click,
-- key or button skips it (CameraDirector skips its own beat on the same input).
--
--   LevelIntro.new(camera) -> intro
--     intro.play(level, info, transition, party) -> boolean   played?
--     intro.stop()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local CameraMath = require(script.Parent:WaitForChild("CameraMath"))
local FirstTime = require(script.Parent:WaitForChild("FirstTime"))
local PresentPlan = require(script.Parent:WaitForChild("PresentPlan"))

local P = Config.Presentation
local I = P.INTRO
local H = Config.Heist

local LevelIntro = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

function LevelIntro.new(camera: any, state: any): any
	local intro = {}
	local running = false
	local inputConn: RBXScriptConnection? = nil

	function intro.stop()
		if not running then
			return
		end
		running = false
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		camera.setShot(nil)
	end

	function intro.play(level: any, info: any, transition: number, party: boolean): boolean
		intro.stop()
		if state.reduced or type(level) ~= "table" or camera.isSuspended() then
			return false
		end
		local kind = PresentPlan.introKind(info, H.FTUE_L1_LEVEL, H.LEVEL_DATA_KEYS)
		if not kind or FirstTime.seen(kind) then
			return false
		end
		local stops = PresentPlan.introStops(level, party, I.FOCUS_LIFT, I.MAX_STOPS)
		local plan = PresentPlan.introPlan(stops, transition, I)
		if not plan then
			return false
		end
		FirstTime.markSeen(kind)
		local origin: Vector3 = state.origin or Vector3.zero
		local yaw, pitch, dist, fov = camera.framing()
		local t0 = os.clock()
		local last = plan.stops[#plan.stops]
		running = true
		camera.setShot(function(): (CFrame?, number?)
			if not running then
				return nil, nil
			end
			local e = os.clock() - t0
			if e >= plan.glide then
				-- hand back: the run-start beat holds on the last stop, then eases to you
				task.defer(function()
					if running then
						intro.stop()
						camera.frameRunStart(last, plan.rest, nil)
					end
				end)
			end
			local focus = PresentPlan.introFocus(plan, math.min(e, plan.glide))
			local pos, look = CameraMath.orbit(focus, yaw, pitch, dist)
			return CFrame.lookAt(origin + v3(pos), origin + v3(look)), fov
		end)
		inputConn = UserInputService.InputBegan:Connect(function(io: InputObject)
			local t = io.UserInputType
			if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Focus then
				intro.stop() -- the director's own handler skips the run-start beat on the same input
			end
		end)
		return true
	end

	return intro
end

return LevelIntro
