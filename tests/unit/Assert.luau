-- Tiny assertion helpers for the L1 specs (not a spec itself).

local Assert = {}

function Assert.eq(actual: any, expected: any, what: string?)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what or "eq", tostring(expected), tostring(actual)), 2)
	end
end

function Assert.near(actual: number, expected: number, tol: number, what: string?)
	if not (math.abs(actual - expected) <= tol) then
		error(string.format("%s: expected %.6f +- %.6f, got %.6f", what or "near", expected, tol, actual), 2)
	end
end

function Assert.truthy(v: any, what: string?)
	if not v then
		error((what or "truthy") .. ": expected truthy, got " .. tostring(v), 2)
	end
end

function Assert.falsy(v: any, what: string?)
	if v then
		error((what or "falsy") .. ": expected falsy, got " .. tostring(v), 2)
	end
end

function Assert.le(actual: number, limit: number, what: string?)
	if not (actual <= limit) then
		error(string.format("%s: expected <= %s, got %s", what or "le", tostring(limit), tostring(actual)), 2)
	end
end

function Assert.hasBit(flags: number, bit: number, what: string?)
	if bit32.band(flags, bit) == 0 then
		error(string.format("%s: flag %d not set in %d", what or "hasBit", bit, flags), 2)
	end
end

return Assert
