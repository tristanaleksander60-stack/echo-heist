--!strict
-- Sim/Scoring: medal inputs and the 3 Stars of a story level (MASTERPLAN §5.2),
-- computed only from sim results (the server is the only judge, §8.8).
--   Haul  bank the goal value before Dawn (the heist completed)
--   Crew  finish with at most par clones
--   Clean no catches and no busted clones in the final run
-- A tainted heist (a recording the Validator clamped) plays on but earns nothing.

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

export type Stars = { haul: boolean, crew: boolean, clean: boolean, count: number }

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

return table.freeze(Scoring)
