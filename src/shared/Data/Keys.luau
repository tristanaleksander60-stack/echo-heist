--!strict
-- Data/Keys: which DataStore keys this server may touch (pure; Lune-tested).
--
-- Test isolation (MASTERPLAN §8.9 L3, docs/DATA.md): in Studio and in the test
-- experience (Config.Data.TEST_UNIVERSE_IDS) every key starts with "_TEST_", so a
-- play test, an Open Cloud Luau Execution task or a fuzzer can never read or write
-- a live profile, and Open Cloud can list and clear test data by prefix. PlayerData
-- also appends "_STUDIO" to the store name in Studio (lihfolk-systems default).

local Config = require("../Config")

local Keys = {}

-- True when this server must only use test keys.
function Keys.isTestEnvironment(isStudio: boolean, gameId: number, testUniverseIds: { number }?): boolean
	if isStudio then
		return true
	end
	for _, id in testUniverseIds or Config.Data.TEST_UNIVERSE_IDS do
		if id == gameId then
			return true
		end
	end
	return false
end

-- Prefix PlayerData puts in front of the user id ("U_" live, "_TEST_U_" in tests).
function Keys.profilePrefix(isTest: boolean): string
	local base = Config.Data.KEY_PREFIX
	return if isTest then Config.Data.TEST_PREFIX .. base else base
end

function Keys.profileKey(userId: number, isTest: boolean): string
	return Keys.profilePrefix(isTest) .. tostring(userId)
end

-- Personal-best recording key (§8.7): G_<levelId>_<userId>.
function Keys.ghostKey(levelId: string, userId: number, isTest: boolean): string
	assert(string.match(levelId, "^[%w]+$"), "Keys.ghostKey: level id must be alphanumeric")
	local key = `{Config.Data.GHOST_PREFIX}{levelId}_{userId}`
	return if isTest then Config.Data.TEST_PREFIX .. key else key
end

-- True if a key may be written from this environment (guards smoke tests and tools).
function Keys.isWritable(key: string, isTest: boolean): boolean
	local isTestKey = string.sub(key, 1, #Config.Data.TEST_PREFIX) == Config.Data.TEST_PREFIX
	return isTestKey == isTest
end

return Keys
