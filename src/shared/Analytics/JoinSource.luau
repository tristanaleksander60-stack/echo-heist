--!strict
-- Analytics/JoinSource: where a player came from (pure; Lune-tested). MASTERPLAN §9.3, §9.5, §9.7.
--
-- Every KPI is split by JoinSource (ad / share link / search / RFY / friend / creator). The server
-- reads Player:GetJoinData() (polled: launch data can arrive a few seconds late), Player.FollowUserId
-- and Player.PartyId, and passes the facts here. Launch data is player-controlled (anyone can craft a
-- link), so it is only a hint: it is parsed strictly, every tag is whitelisted (Config.Analytics
-- CHANNEL_TAGS, AD_TAGS, cr01..crNN) and nothing is ever granted from it.
--
-- Our launch data format (<= 200 bytes, "|" separated, URL-escaped "%7C" is accepted too):
--   v1|src|<tag>                 Creator Hub share link per channel (tt, yt, ...), ad join option
--                                (ad_plays, ad_eng) or a creator's personal link (cr07)
--   v1|reel|<levelId>[|<tag>]    a SAVE CLIP share (PromptShareCapture), §9.3
--   v1|share|<levelKey>[|<tag>]  a player-generated share link (PromptLinkSharingAsync)
--   v1|inv|<levelKey>[|<tag>]    an in-game invite (ExperienceInviteOptions.LaunchData)
--
-- Order of evidence: our launch data > ReferredByPlayerId > FollowUserId > a teleport from this
-- experience > the ConfigService acquisition hint > PartyId > organic. Search and Recommended
-- (RFY) cannot be told apart in game; without the hint both are "organic".

local Config = require("../Config")
local Events = require("./Events")

local A = Config.Analytics

export type Launch = { verb: string, arg: string, tag: string? }

export type JoinFacts = {
	launchData: any?, -- GetJoinData().LaunchData
	referredBy: number?, -- GetJoinData().ReferredByPlayerId
	followUserId: number?, -- Player.FollowUserId
	partyId: string?, -- Player.PartyId
	sourceGameId: number?, -- GetJoinData().SourceGameId
	gameId: number?, -- game.GameId
	hint: string?, -- ConfigService value of Config.Analytics.ACQ_HINT_KEY for this player
}

export type Result = {
	source: string, -- Events.DOMAINS.source
	tag: string, -- Events.DOMAINS.tag
	launch: Launch?, -- parsed launch data (routing hint for the heist server)
}

local JoinSource = {}

JoinSource.VERSION = "v1"
JoinSource.VERBS = table.freeze({ src = true, reel = true, share = true, inv = true })
JoinSource.MAX_ARG_BYTES = 32
JoinSource.MAX_TAG_BYTES = 16

-- Hint values the owner may target in ConfigService (EH_AcqSource), mapped to sources.
JoinSource.HINTS = table.freeze({
	rfy = "rfy",
	search = "search",
	ad = "ad",
	share = "share",
	friend = "friend",
	creator = "creator",
})

local function token(s: string?, maxBytes: number): boolean
	return type(s) == "string" and #s > 0 and #s <= maxBytes and string.match(s, "^[%w_]+$") ~= nil
end

local function unescape(s: string): string
	return (
		string.gsub(s, "%%(%x%x)", function(hex: string): string
			return string.char(tonumber(hex, 16) :: number)
		end)
	)
end

function JoinSource.isAdTag(tag: string?): boolean
	return type(tag) == "string" and table.find(A.AD_TAGS, tag) ~= nil
end

function JoinSource.isChannelTag(tag: string?): boolean
	return type(tag) == "string" and table.find(A.CHANNEL_TAGS, tag) ~= nil
end

function JoinSource.isCreatorTag(tag: string?): boolean
	if type(tag) ~= "string" then
		return false
	end
	local n = string.match(tag, "^cr(%d%d)$")
	local slot = if n then tonumber(n) else nil
	return slot ~= nil and slot >= 1 and slot <= A.CREATOR_SLOTS
end

-- Parses our launch data. Returns the parsed parts, or nil and a reason:
-- "empty" (none), "long", "version", "verb", "arg", "tag", "shape".
function JoinSource.parseLaunchData(raw: any, maxBytes: number?): (Launch?, string?)
	if type(raw) ~= "string" or raw == "" then
		return nil, "empty"
	end
	if #raw > (maxBytes or A.LAUNCH_DATA_MAX_BYTES) then
		return nil, "long"
	end
	local s = if string.find(raw, "%", 1, true) then unescape(raw) else raw
	local parts = string.split(s, "|")
	if parts[1] ~= JoinSource.VERSION then
		return nil, "version"
	end
	if #parts < 3 or #parts > 4 then
		return nil, "shape"
	end
	local verb, arg, tag = parts[2], parts[3], parts[4]
	if not JoinSource.VERBS[verb] then
		return nil, "verb"
	end
	if not token(arg, JoinSource.MAX_ARG_BYTES) then
		return nil, "arg"
	end
	if tag ~= nil and not token(tag, JoinSource.MAX_TAG_BYTES) then
		return nil, "tag"
	end
	return { verb = verb, arg = arg, tag = tag }, nil
end

-- Builds launch data for our own share/invite/clip prompts (the server and SAVE CLIP use this so
-- every link parses). Returns nil and a reason when a part is not allowed.
function JoinSource.build(verb: string, arg: string, tag: string?): (string?, string?)
	if not JoinSource.VERBS[verb] then
		return nil, "verb"
	end
	if not token(arg, JoinSource.MAX_ARG_BYTES) then
		return nil, "arg"
	end
	if tag ~= nil and not token(tag, JoinSource.MAX_TAG_BYTES) then
		return nil, "tag"
	end
	local s = `{JoinSource.VERSION}|{verb}|{arg}` .. (if tag then "|" .. tag else "")
	if #s > A.LAUNCH_DATA_MAX_BYTES then
		return nil, "long"
	end
	return s, nil
end

-- source, tag for a parsed launch, or nil when its tag is not whitelisted.
local function fromLaunch(launch: Launch): (string?, string?)
	if launch.verb == "src" then
		local tag = launch.arg
		if JoinSource.isAdTag(tag) then
			return "ad", tag
		elseif JoinSource.isCreatorTag(tag) then
			return "creator", tag
		elseif JoinSource.isChannelTag(tag) then
			return "share", tag
		end
		return nil, nil
	elseif launch.verb == "reel" then
		return "clip", Events.JOIN_TAG_KINDS.reel
	elseif launch.verb == "share" then
		return "share", Events.JOIN_TAG_KINDS.player
	elseif launch.verb == "inv" then
		return "friend", Events.JOIN_TAG_KINDS.invite
	end
	return nil, nil
end

local function positive(n: any): boolean
	return type(n) == "number" and n == n and n > 0
end

-- Classifies one join. Always returns a source and tag from the Events domains.
function JoinSource.classify(facts: JoinFacts): Result
	local K = Events.JOIN_TAG_KINDS
	local launch, why = JoinSource.parseLaunchData(facts.launchData)
	local invalid = why ~= nil and why ~= "empty"
	if launch then
		local source, tag = fromLaunch(launch)
		if source and tag then
			return { source = source, tag = tag, launch = launch }
		end
		invalid = true
	end
	if positive(facts.referredBy) then
		return { source = "friend", tag = K.referral }
	end
	if positive(facts.followUserId) then
		return { source = "friend", tag = K.follow }
	end
	if positive(facts.sourceGameId) and facts.sourceGameId == facts.gameId then
		return { source = "teleport", tag = K.internal }
	end
	local hinted = if type(facts.hint) == "string" then JoinSource.HINTS[facts.hint] else nil
	if hinted then
		return { source = hinted, tag = K.hint }
	end
	if type(facts.partyId) == "string" and facts.partyId ~= "" then
		return { source = "friend", tag = K.party }
	end
	return { source = "organic", tag = if invalid then K.invalid else K.none }
end

-- The level a link asks to open (reel/share/inv), for the heist server to validate and route.
-- Returns nil for src links. The caller must check the id is a real, unlocked level.
function JoinSource.requestedLevel(launch: Launch?): string?
	if launch and launch.verb ~= "src" then
		return launch.arg
	end
	return nil
end

-- InviteJoined kind for an arrival, or nil when the join was not social.
function JoinSource.inviteKind(result: Result): string?
	local K = Events.JOIN_TAG_KINDS
	if result.tag == K.invite or result.tag == K.referral or result.tag == K.party or result.tag == K.follow then
		return result.tag
	elseif result.tag == K.player then
		return "share"
	end
	return nil
end

return table.freeze(JoinSource)
