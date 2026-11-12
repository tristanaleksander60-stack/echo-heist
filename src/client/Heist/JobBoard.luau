--!strict
-- Heist/JobBoard (client): writes YOUR next job on the garage job board's NEXT card (garage v1, PLAN_STEAM_PLUS
-- §4.1 W6, GOLDEN_FRAMES G3). The server builds the card (Heist/Lobby, EH_Kind "jobCard") with the first job; each
-- client rewrites its own copy from the garage sync it already receives (Shared/Heist/JobCard). Visual only: no
-- remote, nothing replicates back. The level-select UI stays Hud/Garage.
-- StreamingEnabled: the garage is Persistent, but the first garage sync can arrive before it has streamed in, so a
-- missing garage is waited for once (bounded) and the newest title is written when it arrives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local JobCard = require(Shared:WaitForChild("Heist"):WaitForChild("JobCard"))

local GARAGE_WAIT = Config.Perf.GARAGE_WAIT_SECONDS

local JobBoard = {}

local pendingTitle: string? = nil
local waiting = false

local function write(model: Instance, title: string)
	for _, d in model:GetDescendants() do
		if d:GetAttribute("EH_Kind") == "jobCard" then
			local gui = d:FindFirstChild("Card")
			local label = gui and gui:FindFirstChild("Title")
			if label and label:IsA("TextLabel") and label.Text ~= title then
				label.Text = title
			end
		end
	end
end

-- garage = the garage sync payload (state.garage); a missing card is a no-op.
function JobBoard.show(garage: any)
	local title = JobCard.title(garage and garage.levels)
	if title == nil then
		return
	end
	local model = workspace:FindFirstChild("Garage")
	if model then
		write(model, title)
		return
	end
	pendingTitle = title
	if waiting then
		return
	end
	waiting = true
	task.spawn(function()
		local arrived = workspace:WaitForChild("Garage", GARAGE_WAIT)
		waiting = false
		local t = pendingTitle
		pendingTitle = nil
		if arrived and t then
			task.wait() -- a Persistent model arrives whole; its descendants are in by the next frame
			write(arrived, t)
		end
	end)
end

return JobBoard
