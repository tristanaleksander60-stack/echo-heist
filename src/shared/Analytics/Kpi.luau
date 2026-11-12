--!strict
-- Analytics/Kpi: reads a measured KPI against the §9.7 bars (pure; Lune-tested). For weekly
-- reports and the Nov 30 / Dec 9 gates (MASTERPLAN §9.7, §10.2). Bars are Config.Analytics.KPI.
--
--   Kpi.evaluate(id, value, { cohort = "organic" | "ad", n = cohortSize })
--     -> "kill" | "fix" | "healthy" | "double" | "insufficient"
--
-- Plan rules encoded here: ad cohorts use retention bars AD_SHIFT_POINTS lower, and kill/rework
-- fires only on organic cohorts (an ad cohort at worst reads "fix"); D1/D7 need a cohort of 300.

local Config = require("../Config")

export type Status = "kill" | "fix" | "healthy" | "double" | "insufficient"
export type Opts = { cohort: string?, n: number? }

local Kpi = {}

function Kpi.ids(): { string }
	local out = {}
	for id, bar in Config.Analytics.KPI do
		if type(bar) == "table" then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

function Kpi.evaluate(id: string, value: number, opts: Opts?): Status
	local bar = (Config.Analytics.KPI :: any)[id]
	assert(type(bar) == "table", "Kpi.evaluate: unknown KPI " .. tostring(id))
	local o: Opts = opts or {}
	if bar.minCohort and (o.n == nil or o.n < bar.minCohort) then
		return "insufficient"
	end
	local ad = o.cohort == "ad"
	local shift = if ad and bar.retention then Config.Analytics.KPI.AD_SHIFT_POINTS else 0
	local kill, healthy, double = bar.kill, bar.healthy, bar.double
	local status: Status
	if bar.higher then
		kill, healthy = math.max(0, kill - shift), math.max(0, healthy - shift)
		double = if double then math.max(0, double - shift) else nil
		if value < kill then
			status = "kill"
		elseif double and value >= double then
			status = "double"
		elseif value >= healthy then
			status = "healthy"
		else
			status = "fix"
		end
	else
		if value > kill then
			status = "kill"
		elseif double and value <= double then
			status = "double"
		elseif value <= healthy then
			status = "healthy"
		else
			status = "fix"
		end
	end
	if ad and status == "kill" then
		return "fix"
	end
	return status
end

return table.freeze(Kpi)
