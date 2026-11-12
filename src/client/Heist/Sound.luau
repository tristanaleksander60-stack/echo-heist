--!strict
-- Heist/Sound: the views' one door to Audio/AudioDirector (docs/AUDIO.md §8-9).
-- Every call is safe: on the server (the engine smoke test runs the views there) and
-- when the director fails to load, each call is a no-op, and a director error never
-- reaches the view that asked for a sound. Sounds are cosmetic: nothing here decides
-- anything (CLAUDE.md: the server decides every outcome).

local RunService = game:GetService("RunService")

local Sound = {}

local director: any = nil
local tried = false

local function ad(): any
	if director ~= nil or tried then
		return director
	end
	tried = true
	if not RunService:IsClient() then
		return nil
	end
	-- FindFirstChild, not WaitForChild: the first call may come from a RenderStepped
	-- handler, which must never yield. Rojo ships Client.Audio with Client.Heist.
	local ok, mod = pcall(function()
		local client = script.Parent.Parent
		local audio = client and client:FindFirstChild("Audio")
		local module = audio and audio:FindFirstChild("AudioDirector")
		if not module or not module:IsA("ModuleScript") then
			error("Audio/AudioDirector is missing")
		end
		return require(module) :: any
	end)
	if ok then
		director = mod
	else
		warn("[Heist/Sound] audio off: " .. tostring(mod))
	end
	return director
end

local function noop() end

-- Calls director[fn](...) safely; returns its first result (or nil).
local function call(fn: string, ...: any): any
	local d = ad()
	local f = d and d[fn]
	if type(f) ~= "function" then
		return nil
	end
	local ok, res = pcall(f, ...)
	if not ok then
		warn("[Heist/Sound] " .. fn .. ": " .. tostring(res))
		return nil
	end
	return res
end

-- play(cue, opts?) -> stop()   (opts: at, clone, step, volume, pitch, delay, caption)
function Sound.play(cue: string, opts: { [string]: any }?): () -> ()
	local stop = call("play", cue, opts)
	if type(stop) ~= "function" then
		return noop
	end
	return function()
		pcall(stop)
	end
end

function Sound.stopCue(cue: string)
	call("stopCue", cue)
end

function Sound.stopAll()
	call("stopAll")
end

-- "Off" | "Garage" | "Heist" | "Alarm" | "Results"; opts: set, restart
function Sound.music(stateName: string, opts: { [string]: any }?)
	call("music", stateName, opts)
end

function Sound.layers(clones: number)
	call("layers", clones)
end

function Sound.rewind()
	call("rewind")
end

function Sound.go(clones: number?)
	call("go", clones)
end

function Sound.arpeggio(clones: number)
	call("arpeggio", clones)
end

function Sound.event(e: any, resolver: any)
	call("event", e, resolver)
end

function Sound.duck(reason: string, seconds: number?)
	call("duck", reason, seconds)
end

function Sound.preload(sets: { string }?)
	call("preload", sets)
end

function Sound.setReducedMotion(on: boolean)
	call("setReducedMotion", on)
end

function Sound.setChristmas(on: boolean?)
	call("setChristmas", on)
end

function Sound.setCaptionHandler(handler: ((text: string, position: Vector3?) -> ())?)
	call("setCaptionHandler", handler)
end

function Sound.setBusVolume(bus: string, slider: number)
	call("setBusVolume", bus, slider)
end

function Sound.setMuted(on: boolean)
	call("setMuted", on)
end

function Sound.status(): { [string]: any }
	local s = call("status")
	return if type(s) == "table" then s else { built = false }
end

return Sound
