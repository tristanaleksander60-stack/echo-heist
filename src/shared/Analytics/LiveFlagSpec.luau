--!strict
-- Analytics/LiveFlagSpec: LiveFlags definitions, parsing, validation and layering (pure;
-- Lune-tested). MASTERPLAN §8.7 ("a DataStore key polled every 60 s turns features off without a
-- republish"), §8.12 (kill switches). The server side is src/server/Analytics/LiveFlags.
--
-- Definitions are Config.LiveFlags.Flags. Kinds (vault "Feature Flags and Staged Rollouts" §2):
--   kill        boolean, default true (an unreadable config never turns a working system off)
--   release     boolean, or a 0-100 percent of players (sticky, salted per flag); default off
--   tune        number in [min, max]; out-of-range values are refused, never clamped
--   experiment  "arm:weight,arm:weight" with arms from Config.Analytics.VARIANTS; sticky per player
-- Layers, lowest first: default < "config" (ConfigService EH_<name>) < "store" (the DataStore
-- document) < "test" (Studio/test only). A layer that does not set a flag leaves it alone. Kill
-- switches are the exception: off wins, so a switch is off when any layer sets it false (a stale
-- `store = true` in the DataStore can never cancel the owner's EH_store = false in Creator Hub).

local Config = require("../Config")
local Sampling = require("./Sampling")

export type Kind = "kill" | "release" | "tune" | "experiment"

export type Def = {
	kind: Kind,
	default: any,
	min: number?,
	max: number?,
	client: boolean?,
	desc: string?,
}

export type Defs = { [string]: Def }
export type Layer = { name: string, values: { [string]: any } }

local LiveFlagSpec = {}

LiveFlagSpec.KINDS = table.freeze({ kill = true, release = true, tune = true, experiment = true })
LiveFlagSpec.LAYERS = table.freeze({ "config", "store", "test" })
LiveFlagSpec.MAX_NAME_BYTES = 32
LiveFlagSpec.DOC_VERSION = 1
LiveFlagSpec.META_KEYS = table.freeze({ v = true, note = true, updatedBy = true, updatedAt = true })

local function finite(v: any): boolean
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

function LiveFlagSpec.defs(): Defs
	return Config.LiveFlags.Flags :: any
end

-- ConfigService key for a flag (one typed key per flag: Creator Hub history is per switch).
function LiveFlagSpec.configKey(name: string): string
	return Config.LiveFlags.CONFIG_PREFIX .. name
end

-- The value a definition accepts for raw, or nil and a reason.
function LiveFlagSpec.coerce(def: Def, raw: any): (any, string?)
	if def.kind == "kill" then
		if type(raw) == "boolean" then
			return raw, nil
		end
		return nil, "type"
	elseif def.kind == "release" then
		if type(raw) == "boolean" then
			return raw, nil
		elseif finite(raw) then
			if raw >= 0 and raw <= 100 then
				return raw, nil
			end
			return nil, "range"
		end
		return nil, "type"
	elseif def.kind == "tune" then
		if not finite(raw) then
			return nil, "type"
		end
		if raw < (def.min :: number) or raw > (def.max :: number) then
			return nil, "range"
		end
		return raw, nil
	elseif def.kind == "experiment" then
		if type(raw) ~= "string" then
			return nil, "type"
		end
		local arms = Sampling.parseArms(raw, Config.Analytics.VARIANTS)
		if not arms then
			return nil, "arms"
		end
		return raw, nil
	end
	return nil, "kind"
end

-- Problems with the definitions themselves (CI asserts none).
function LiveFlagSpec.validateDefs(defs: Defs): { string }
	local errors: { string } = {}
	for name, def in defs do
		if type(name) ~= "string" or #name > LiveFlagSpec.MAX_NAME_BYTES or not string.match(name, "^%l[%w]*$") then
			table.insert(errors, `flag name '{tostring(name)}' must be camelCase alphanumeric`)
		end
		if not LiveFlagSpec.KINDS[def.kind] then
			table.insert(errors, `{name}: unknown kind {tostring(def.kind)}`)
			continue
		end
		if def.client ~= nil and type(def.client) ~= "boolean" then
			table.insert(errors, `{name}: client must be a boolean`)
		end
		if def.kind == "kill" and def.default ~= true then
			table.insert(errors, `{name}: a kill switch defaults to true (the system works)`)
		elseif def.kind == "release" and def.default ~= false and def.default ~= 0 then
			table.insert(errors, `{name}: a release flag defaults to off`)
		elseif def.kind == "tune" then
			if not (finite(def.min) and finite(def.max) and (def.min :: number) < (def.max :: number)) then
				table.insert(errors, `{name}: tune needs min < max`)
			elseif LiveFlagSpec.coerce(def, def.default) == nil then
				table.insert(errors, `{name}: default {tostring(def.default)} outside [{def.min}, {def.max}]`)
			end
		elseif def.kind == "experiment" and LiveFlagSpec.coerce(def, def.default) == nil then
			table.insert(errors, `{name}: default arms '{tostring(def.default)}' do not parse`)
		end
	end
	return errors
end

-- Parses an override document (the DataStore value, already a table; the server decodes JSON
-- strings first). Accepts { v = 1, flags = { name = value } } or a flat { name = value }.
-- Unknown names and bad values are reported and skipped; the rest still apply.
function LiveFlagSpec.parseDocument(defs: Defs, doc: any): ({ [string]: any }, { string })
	local out: { [string]: any } = {}
	local errors: { string } = {}
	if doc == nil then
		return out, errors
	end
	if type(doc) ~= "table" then
		table.insert(errors, "document is not a table")
		return out, errors
	end
	if doc.v ~= nil and doc.v ~= LiveFlagSpec.DOC_VERSION then
		table.insert(errors, `document version {tostring(doc.v)} is not {LiveFlagSpec.DOC_VERSION}`)
		return out, errors
	end
	local flags = if type(doc.flags) == "table" then doc.flags else doc
	for name, raw in flags do
		if flags == doc and LiveFlagSpec.META_KEYS[name] then
			continue
		end
		if name == "flags" then
			continue
		end
		local def = if type(name) == "string" then defs[name] else nil
		if not def then
			table.insert(errors, `unknown flag {tostring(name)}`)
			continue
		end
		local value, why = LiveFlagSpec.coerce(def, raw)
		if value == nil then
			table.insert(errors, `{name}: {why} ({tostring(raw)})`)
		else
			out[name] = value
		end
	end
	return out, errors
end

-- Effective values and the layer each came from ("default" when no layer sets it). The last
-- layer that sets a flag wins, except for kill switches, where the last layer that sets it false
-- wins (off wins; to turn a switch back on, every layer that set it false must clear it).
function LiveFlagSpec.resolve(defs: Defs, layers: { Layer }): ({ [string]: any }, { [string]: string })
	local values: { [string]: any } = {}
	local sources: { [string]: string } = {}
	for name, def in defs do
		values[name] = def.default
		sources[name] = "default"
		local killed = false
		for _, layer in layers do
			local v = layer.values[name]
			if v == nil then
				continue
			end
			if def.kind == "kill" then
				if v == false then
					killed = true
				elseif killed then
					continue -- a later "on" never cancels an earlier "off"
				end
			end
			values[name] = v
			sources[name] = layer.name
		end
	end
	return values, sources
end

-- Flags whose value in the lower layer `under` has no effect because the higher layer `over` sets
-- another value (sorted), e.g. a stale DataStore override shadowing a newer ConfigService value.
-- A kill switch that `under` turns off is never shadowed (off wins).
function LiveFlagSpec.shadowed(defs: Defs, under: { [string]: any }, over: { [string]: any }): { string }
	local out = {}
	for name, v in under do
		local def = defs[name]
		local o = over[name]
		if def and o ~= nil and o ~= v and not (def.kind == "kill" and v == false) then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

-- Whole-server reading: kill/release booleans as they are, a release percent counts as on only
-- at 100. Use forUser for per-player rollouts.
function LiveFlagSpec.isOn(def: Def, value: any): boolean
	if def.kind == "release" and type(value) == "number" then
		return value >= 100
	end
	return value == true
end

-- The value one player sees: a release percent becomes a sticky boolean, an experiment its arm.
function LiveFlagSpec.forUser(name: string, def: Def, value: any, userId: number): any
	if def.kind == "release" and type(value) == "number" then
		return Sampling.inPercent(userId, "lf:" .. name, value)
	elseif def.kind == "experiment" then
		local arms = Sampling.parseArms(value, Config.Analytics.VARIANTS)
			or Sampling.parseArms(def.default, Config.Analytics.VARIANTS)
		if not arms then
			return Config.Analytics.VARIANTS[1]
		end
		return Sampling.arm(userId, "lf:" .. name, arms)
	end
	return value
end

-- Names whose value differs between two resolved tables (sorted, for stable logs).
function LiveFlagSpec.changed(old: { [string]: any }, new: { [string]: any }): { string }
	local out = {}
	for name, v in new do
		if old[name] ~= v then
			table.insert(out, name)
		end
	end
	table.sort(out)
	return out
end

return table.freeze(LiveFlagSpec)
