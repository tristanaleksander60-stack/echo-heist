--!strict
-- Data/Calendar: UTC day numbers (pure; Lune-tested). The server passes os.time();
-- nothing here reads a clock. Day 0 = 1970-01-01. Civil-date conversion is
-- Howard Hinnant's days_from_civil / civil_from_days (proleptic Gregorian).

local Calendar = {}

local DAY = 86400

export type Date = { number } -- { year, month, day }

-- Day number for a unix time, with the daily reset moved by offsetHours (0 = 00:00 UTC).
function Calendar.dayIndex(unix: number, offsetHours: number?): number
	return math.floor((unix - (offsetHours or 0) * 3600) / DAY)
end

-- Seconds from unix until the next reset.
function Calendar.secondsUntilReset(unix: number, offsetHours: number?): number
	local offset = (offsetHours or 0) * 3600
	return (Calendar.dayIndex(unix, offsetHours) + 1) * DAY + offset - unix
end

function Calendar.daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = if month > 2 then month - 3 else month + 9
	local doy = math.floor((153 * mp + 2) / 5) + day - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

function Calendar.civilFromDays(days: number): (number, number, number)
	local z = days + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local d = doy - math.floor((153 * mp + 2) / 5) + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	local y = yoe + era * 400
	return (if m <= 2 then y + 1 else y), m, d
end

-- Day number of a { year, month, day } config date.
function Calendar.dayOf(date: Date): number
	assert(type(date) == "table" and #date == 3, "Calendar.dayOf: expected { year, month, day }")
	local y, m, d = date[1], date[2], date[3]
	assert(m >= 1 and m <= 12 and d >= 1 and d <= 31, "Calendar.dayOf: bad month or day")
	return Calendar.daysFromCivil(y, m, d)
end

-- True if today is on or before the last day (nil lastDay = no end).
function Calendar.onOrBefore(today: number, lastDay: Date?): boolean
	return lastDay == nil or today <= Calendar.dayOf(lastDay)
end

return Calendar
