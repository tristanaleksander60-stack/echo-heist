--!strict
-- Heist/JobCard: what the garage job board's NEXT card says (garage v1, PLAN_STEAM_PLUS §4.1 W6, GOLDEN_FRAMES G3).
-- Pure: the server writes the first job when it builds the garage (Heist/Lobby), and each client rewrites the card
-- with its own next job from the garage sync it already gets (client Heist/JobBoard): visual only, no remote.
-- tests/unit/HeistJobCard.spec.luau.

local Strings = require("./Strings")

local JobCard = {}

-- The next job in play order: the first unlocked level without a medal (not cleared yet), else (everything
-- unlocked is cleared) ALL DONE. levels = the garage sync's list (Protocol "Sync": name, unlocked, medals).
function JobCard.title(levels: { any }?): string?
	if levels == nil or #levels == 0 then
		return nil
	end
	for _, lv in levels do
		if lv.unlocked and #(lv.medals or {}) == 0 then
			return string.upper(tostring(lv.name))
		end
	end
	return Strings.JOB_BOARD_ALL_DONE
end

-- The card before any sync (the server's text): the first level of the catalog.
function JobCard.first(catalog: { any }): string
	local first = catalog[1]
	return if first and first.name then string.upper(tostring(first.name)) else Strings.JOB_BOARD_ALL_DONE
end

return table.freeze(JobCard)
