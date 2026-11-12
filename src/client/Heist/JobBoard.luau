--!strict
-- Heist/JobBoard (client): writes YOUR next job on the garage job board's NEXT card (garage v1, PLAN_STEAM_PLUS
-- §4.1 W6, GOLDEN_FRAMES G3). The server builds the card (Heist/Lobby, EH_Kind "jobCard") with the first job; each
-- client rewrites its own copy from the garage sync it already receives (Shared/Heist/JobCard). Visual only: no
-- remote, nothing replicates back. The level-select UI stays Hud/Garage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JobCard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist"):WaitForChild("JobCard"))

local JobBoard = {}

-- garage = the garage sync payload (state.garage); a missing garage or card is a no-op.
function JobBoard.show(garage: any)
	local title = JobCard.title(garage and garage.levels)
	local model = workspace:FindFirstChild("Garage")
	if title == nil or model == nil then
		return
	end
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

return JobBoard
