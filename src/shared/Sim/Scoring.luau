--!strict
-- Sim/Scoring: medal inputs and the 3 Stars of a story level (MASTERPLAN §5.2),
-- computed only from sim results (the server is the only judge, §8.8).
--   Haul  bank the goal value before Dawn (the heist completed)
--   Crew  finish with at most par clones
--   Clean no catches and no busted clones in the final run
-- A tainted heist (a recording the Validator clamped) plays on but earns nothing.
-- Party levels (Clone Party) have no Crew or Clean star: their 3 Stars are the haul
-- tiers (Haul1..3, $ banked by Dawn), the same rule as Data/Progress "party".

export type Inputs = {
	complete: boolean,
	banked: number,
	goal: number,
	clonesUsed: number,
	par: number,
	catchesFinal: number,
	bustedFinal: number,
	tainted: boolean,
}

export type Stars = { haul: boolean, crew: boolean, clean: boolean, count: number, tiers: { boolean }? }

local Scoring = {}

function Scoring.stars(i: Inputs): Stars
	if i.tainted then
		return { haul = false, crew = false, clean = false, count = 0 }
	end
	local haul = i.complete and i.banked >= i.goal
	local crew = i.complete and i.clonesUsed <= i.par
	local clean = i.complete and i.catchesFinal == 0 and i.bustedFinal == 0
	return {
		haul = haul,
		crew = crew,
		clean = clean,
		count = (if haul then 1 else 0) + (if crew then 1 else 0) + (if clean then 1 else 0),
	}
end

-- Party level: one Star per haul tier banked (tiers ascending). `haul` = Haul1 (the
-- level counts as cleared).
function Scoring.partyStars(banked: number, tiers: { number }, tainted: boolean): Stars
	local met: { boolean } = {}
	local count = 0
	for i, tier in tiers do
		met[i] = not tainted and banked >= tier
		if met[i] then
			count += 1
		end
	end
	return { haul = met[1] == true, crew = false, clean = false, count = count, tiers = met }
end

return table.freeze(Scoring)
