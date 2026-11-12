--!strict
-- Audio/AudioDirector: every sound and all music on the client (MASTERPLAN §7.1-7.3, feel.md D5,
-- docs/AUDIO.md). Cosmetic sounds play on each client from the same replicated events that drive the
-- views; the server never plays sound. Cue data is in Shared/Audio/Cues, shared numbers in Config.Audio.
--
-- Engine: the Audio API (AudioPlayer -> Wire -> AudioFader / AudioEmitter, AudioListener per bus,
-- AudioDeviceOutput), not Sound/SoundGroup: Crew Layers need sample-aligned AudioPlayer:Play(atTime) on
-- SoundService:GetMixerTime() (spike S4), and the clone bus needs a real effect chain (filter -> echo).
-- One graph, built once on first use:
--
--   cue voices (2D) ------------------------------> bus faders: SFX, UI, Ambience, Warnings, Music --\
--   cue voices (3D) -> AudioEmitter (group EH_<bus>)   AudioListener EH_<bus> on the camera -> bus  |
--   clone voices -> CloneIn -> Lowpass -> Echo -> Clone (-4 dB) -> SFX                               |
--   music set mixes -> mix faders -> set fader -> MusicDuck -> Music                                  |
--                                          Master -> Compressor -> Limiter -> AudioDeviceOutput <---/
--
-- API (views call these; docs/AUDIO.md "Call sites"):
--   AudioDirector.play(cue, opts?) -> stop()   opts: at (Vector3 | BasePart | Attachment = positional),
--       clone (a clone's version: Clone bus), step (tonal ladder index), volume, pitch (multipliers),
--       delay (seconds, sample-accurate when the mixer clock is there), caption (false = no caption)
--   AudioDirector.stopCue(cue)                    stop every live voice of a cue (loops: alarm, hum)
--   AudioDirector.music(state, opts?)             "Off" | "Garage" | "Heist" | "Alarm" | "Results";
--       opts: set (override, e.g. "BigScore"), restart (start from the top)
--   AudioDirector.layers(clones)                  Crew Layers tier from the clone count (call on GO)
--   AudioDirector.rewind()                        tape-stop dive + duck at the start of the transition
--   AudioDirector.go(clones?)                     the run starts: music restarts on the downbeat
--   AudioDirector.arpeggio(n)                     the clone arpeggio (sound logo), n clones
--   AudioDirector.duck(reason, seconds?)          music ducks Config.Audio.DUCK_DB (cues with duck do it)
--   AudioDirector.event(e, resolve)               the cues of one replicated sim event (Audio/EventCues)
--   AudioDirector.preload(sets?)                  first-impression cues (+ music sets) at boot
--   settings: setBusVolume(bus, 0..1), setMuted(bool), setReducedMotion(bool), setChristmas(bool?),
--       setCaptionHandler(fn(text, position?)), stopAll(), status()

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local AudioShared = Shared:WaitForChild("Audio")
local Cues = require(AudioShared:WaitForChild("Cues")) :: any
local Manifest = require(AudioShared:WaitForChild("Manifest")) :: any
local CueCheck = require(AudioShared:WaitForChild("CueCheck"))
local EventCues = require(AudioShared:WaitForChild("EventCues"))
local Voices = require(AudioShared:WaitForChild("Voices"))
local Mix = require(AudioShared:WaitForChild("Mix"))

local A = Config.Audio

export type PlayOptions = {
	at: (Vector3 | BasePart | Attachment)?,
	clone: boolean?,
	step: number?,
	volume: number?,
	pitch: number?,
	delay: number?,
	caption: boolean?,
}

export type MusicOptions = { set: string?, restart: boolean? }

-- How AudioDirector.event finds where a sim event happened (HeistClient builds it from its views):
--   position(what, index): what = "plate" | "door" | "laser" | "switch" | "loot" | "actor" | "van"; return a
--     part, attachment or point, or nil (the sound then plays 2D)
--   isClone(actorId), isMine(actorId): the actor is a clone / the local player's live actor
export type Resolver = {
	position: (what: string, index: number) -> (Vector3 | BasePart | Attachment)?,
	isClone: (actorId: number) -> boolean,
	isMine: (actorId: number) -> boolean,
}

export type SimEvent = { kind: number, a: number, b: number, c: number }

type VoiceObj = {
	player: AudioPlayer,
	id: number,
	wire: Wire,
	anchor: Attachment,
	emitter: AudioEmitter,
	rolloffKey: string,
	serial: number,
	cue: string,
	loop: boolean,
	endsAt: number,
	speed: number,
}

type Deck = {
	setName: string,
	set: any,
	players: { AudioPlayer },
	faders: { AudioFader },
	group: AudioFader,
	active: number, -- playlist track
	tween: Tween?,
}

local AudioDirector = {}

local BUSES = { "Music", "SFX", "UI", "Ambience", "Warnings" }
local SPATIAL_BUSES = { "SFX", "Clone", "Warnings" }
local EMPTY_OPTS: PlayOptions = {}

local built = false
local root: Folder
local busFader: { [string]: AudioFader } = {}
local busInput: { [string]: Instance } = {} -- where a 2D voice of each bus is wired
local listeners: { AudioListener } = {}
local musicDuck: AudioFader
local cloneOut: AudioFader

local rng = Random.new()
local state: Voices.State = Voices.new(A.MAX_VOICES, A.CLONE_MAX_PER_SECOND, A.CLONE_VOICED_NEAREST)
local lengthOf: { [number]: number } = {} -- asset id -> seconds, learned from loaded players
local pool: { VoiceObj } = {}
local active: { [number]: VoiceObj } = {}
local voiceCount = 0
local maxVoices = A.MAX_VOICES

local sliders: Mix.Sliders = { Master = 1, Music = 1, SFX = 1, UI = 1, Ambience = 1, Warnings = 1 }
local muted = false
local reducedMotion = false
local rewinding = false
local christmasOverride: boolean? = nil
local captionHandler: ((text: string, position: Vector3?) -> ())? = nil
local ducks: Mix.Ducks = {}
local duckOn = false
local warned: { [string]: boolean } = {}

local decks: { [string]: Deck } = {}
local current: Deck? = nil
local musicState = "Off"
local tier = 0
local firstMusic = true
local playlistTurn: { [string]: number } = {}

local mixerOk = pcall(function()
	return SoundService:GetMixerTime()
end)

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn("[AudioDirector] " .. message)
	end
end

local function mixerNow(): number
	if mixerOk then
		return SoundService:GetMixerTime()
	end
	return os.clock()
end

local function tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(math.max(seconds, 0), style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		props
	)
	t:Play()
	return t
end

local function wire(source: Instance, target: Instance, parent: Instance): Wire
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = parent
	return w
end

local function fader(name: string, volume: number): AudioFader
	local f = Instance.new("AudioFader")
	f.Name = name
	f.Volume = volume
	f.Parent = root
	return f
end

local function asset(id: number): string
	return "rbxassetid://" .. tostring(id)
end

-------------------------------------------------------------------------------------------------------------
-- Graph
-------------------------------------------------------------------------------------------------------------

local function rewindFactor(bus: string): number
	if rewinding and (bus == "Ambience" or bus == "Clone") then
		return Mix.dbToGain(A.REWIND_DUCK_DB)
	end
	return 1
end

local function applyBusGains(seconds: number)
	if not built then
		return
	end
	for _, bus in BUSES do
		local g = Mix.busGain(bus, A.BUS_DB, sliders, A.SLIDER_EXPONENT, A.WARNINGS_FLOOR, muted, A.MUTE_KEEPS_WARNINGS)
			* rewindFactor(bus)
		tween(busFader[bus], seconds, { Volume = g })
	end
	-- The Clone bus feeds the SFX fader, so only its own trim (and the rewind duck) apply here.
	tween(cloneOut, seconds, { Volume = Mix.dbToGain(A.BUS_DB.Clone) * rewindFactor("Clone") })
end

local function placeListeners()
	local cam = Workspace.CurrentCamera
	for _, l in listeners do
		l.Parent = cam or root
	end
end

local function build()
	if built then
		return
	end
	built = true
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	maxVoices = if touch then A.MAX_VOICES_TOUCH else A.MAX_VOICES
	state = Voices.new(maxVoices, A.CLONE_MAX_PER_SECOND, A.CLONE_VOICED_NEAREST)

	root = Instance.new("Folder")
	root.Name = "EchoHeistAudio"
	root.Parent = SoundService

	local output = Instance.new("AudioDeviceOutput")
	output.Name = "Output"
	output.Parent = root

	local limiter = Instance.new("AudioLimiter")
	limiter.Name = "Limiter"
	limiter.MaxLevel = A.LIMITER_DB
	limiter.Parent = root
	wire(limiter, output, root)

	local compressor = Instance.new("AudioCompressor")
	compressor.Name = "Compressor"
	compressor.Threshold = A.COMPRESSOR.threshold
	compressor.Ratio = A.COMPRESSOR.ratio
	compressor.Attack = A.COMPRESSOR.attack
	compressor.Release = A.COMPRESSOR.release
	compressor.Parent = root
	wire(compressor, limiter, root)

	local master = fader("Master", 1)
	wire(master, compressor, root)

	for _, bus in BUSES do
		local f = fader(bus, 1)
		wire(f, master, root)
		busFader[bus] = f
		busInput[bus] = f
	end

	-- Music: sets go through the duck fader, stingers (Music-bus cues) straight into the Music fader.
	musicDuck = fader("MusicDuck", 1)
	wire(musicDuck, busFader.Music, root)

	-- Clone bus: memories are muffled and echo (feel.md D2).
	local cloneIn = fader("CloneIn", 1)
	local lowpass = Instance.new("AudioFilter")
	lowpass.Name = "CloneLowpass"
	lowpass.FilterType = Enum.AudioFilterType.Lowpass12dB
	lowpass.Frequency = A.CLONE_LOWPASS_HZ
	lowpass.Parent = root
	local echo = Instance.new("AudioEcho")
	echo.Name = "CloneEcho"
	echo.DelayTime = A.CLONE_ECHO_DELAY
	echo.Feedback = A.CLONE_ECHO_FEEDBACK
	echo.WetLevel = A.CLONE_ECHO_WET_DB
	echo.DryLevel = 0
	echo.Parent = root
	cloneOut = fader("Clone", Mix.dbToGain(A.BUS_DB.Clone))
	wire(cloneIn, lowpass, root)
	wire(lowpass, echo, root)
	wire(echo, cloneOut, root)
	wire(cloneOut, busFader.SFX, root)
	busInput.Clone = cloneIn

	-- One listener per positional bus, separated by interaction group (vault: The Audio API §6). The
	-- engine's default listener (voice-chat experiences only) has no group, so it never hears these.
	for _, bus in SPATIAL_BUSES do
		local l = Instance.new("AudioListener")
		l.Name = bus .. "Listener"
		l.AudioInteractionGroup = "EH_" .. bus
		table.insert(listeners, l)
		wire(l, busInput[bus], root)
	end
	placeListeners()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placeListeners)

	applyBusGains(0)

	for _, problem in CueCheck.validate(Cues, Manifest, A) do
		warnOnce("check:" .. problem, problem)
	end
end

-------------------------------------------------------------------------------------------------------------
-- Voices
-------------------------------------------------------------------------------------------------------------

local function newVoice(): VoiceObj
	voiceCount += 1
	local player = Instance.new("AudioPlayer")
	player.Name = "Voice" .. voiceCount
	player.Parent = root
	local anchor = Instance.new("Attachment")
	anchor.Name = "EchoHeistAudioAnchor" .. voiceCount
	anchor.Parent = Workspace.Terrain
	local emitter = Instance.new("AudioEmitter")
	emitter.Name = "Emitter"
	emitter.Parent = anchor
	local w = wire(player, busInput.SFX, root)
	return {
		player = player,
		id = 0,
		wire = w,
		anchor = anchor,
		emitter = emitter,
		rolloffKey = "",
		serial = 0,
		cue = "",
		loop = false,
		endsAt = 0,
		speed = 1,
	}
end

local function recycle(obj: VoiceObj)
	active[obj.serial] = nil
	Voices.release(state, obj.serial)
	obj.serial = 0
	obj.loop = false
	pcall(function()
		obj.player:Stop()
	end)
	obj.player.Looping = false
	obj.emitter.PositionInstance = nil
	table.insert(pool, obj)
end

local function stopSerial(serial: number)
	local obj = active[serial]
	if obj then
		recycle(obj)
	else
		Voices.release(state, serial)
	end
end

local function takeVoice(): VoiceObj
	local obj = table.remove(pool)
	if obj then
		return obj
	end
	return newVoice()
end

local function positionOf(at: any): Vector3?
	if typeof(at) == "Vector3" then
		return at
	end
	if typeof(at) == "Instance" and (at :: Instance):IsDescendantOf(Workspace) then
		if (at :: Instance):IsA("Attachment") then
			return (at :: Attachment).WorldPosition
		elseif (at :: Instance):IsA("BasePart") then
			return (at :: BasePart).Position
		end
	end
	return nil
end

local function placeVoice(obj: VoiceObj, bus: string, cue: any, at: any)
	if at == nil then
		obj.wire.TargetInstance = busInput[bus]
		return
	end
	local roll = A.ROLLOFF[cue.rolloff or "mid"] or A.ROLLOFF.mid
	local key = tostring(cue.rolloff or "mid")
	if obj.rolloffKey ~= key then
		obj.rolloffKey = key
		obj.emitter:SetDistanceAttenuation({ [0] = 1, [roll.min] = 1, [roll.max] = 0 })
	end
	obj.emitter.AudioInteractionGroup = "EH_" .. bus
	if typeof(at) == "Vector3" then
		obj.emitter.PositionType = Enum.AudioPositionType.Parent
		obj.emitter.PositionInstance = nil
		obj.anchor.WorldPosition = at
	else
		obj.emitter.PositionType = Enum.AudioPositionType.Instance
		obj.emitter.PositionInstance = at
	end
	obj.wire.TargetInstance = obj.emitter
end

local function startVoice(obj: VoiceObj, delay: number)
	local player = obj.player
	player.TimePosition = 0 -- Play/Stop do not reset it (DevForum "AudioPlayer is debounced")
	if delay > 0 and mixerOk then
		local at = mixerNow() + delay
		local ok = pcall(function()
			player:Play(at)
		end)
		if ok then
			return
		end
	end
	if delay > 0 then
		local serial = obj.serial
		task.delay(delay, function()
			if active[serial] == obj then -- not stolen or stopped meanwhile
				player:Play()
			end
		end)
		return
	end
	player:Play()
end

function AudioDirector.play(cueName: string, opts: PlayOptions?): () -> ()
	build()
	local o = opts or EMPTY_OPTS
	local cue = Cues.cues[cueName]
	if cue == nil then
		warnOnce("cue:" .. cueName, "no cue named " .. cueName)
		return function() end
	end
	if #cue.ids == 0 then
		warnOnce("empty:" .. cueName, string.format("cue %s has no sound yet (search: %s)", cueName, cue.search))
		return function() end
	end
	local bus = if o.clone and cue.cloneable then "Clone" else cue.bus
	local at = o.at
	local distance = 0
	if at ~= nil then
		local pos = positionOf(at)
		if pos == nil then
			return function() end -- the part left the world
		end
		local roll = A.ROLLOFF[cue.rolloff or "mid"] or A.ROLLOFF.mid
		local cam = Workspace.CurrentCamera
		if cam then
			distance = (cam.CFrame.Position - pos).Magnitude
			if distance > roll.max then
				return function() end -- never start what nobody can hear
			end
		end
		if bus ~= "SFX" and bus ~= "Clone" and bus ~= "Warnings" then
			at = nil -- UI, Music and Ambience are always 2D
		end
	end

	local now = os.clock()
	local take = Voices.nextTake(state, cueName, #cue.ids, function(m: number): number
		return rng:NextInteger(1, m)
	end)
	local id = cue.ids[take]
	local stepSpeed = if cue.steps and o.step then Mix.stepSpeed(cue.steps, o.step) else 1
	local pj = cue.pitchJitter or A.DEFAULT_PITCH_JITTER
	local speed =
		math.clamp(Mix.jitter((cue.pitch or 1) * stepSpeed * (o.pitch or 1), pj, rng:NextNumber(-1, 1)), 0.05, 20)
	local known = lengthOf[id]
	local length = if cue.loop
		then math.huge
		else (if known then known / speed else A.UNLOADED_SECONDS) + (o.delay or 0)
	local decision = Voices.request(state, {
		cue = cueName,
		now = now,
		length = length,
		cooldown = cue.cooldown or A.DEFAULT_COOLDOWN,
		maxPerCue = cue.maxVoices or A.DEFAULT_MAX_PER_CUE,
		priority = cue.priority or A.DEFAULT_PRIORITY,
		choke = cue.choke,
		clone = bus == "Clone",
		distance = distance,
	})
	for _, v in decision.stop do
		stopSerial(v.serial)
	end
	local voice = decision.voice
	if not decision.ok or voice == nil then
		return function() end
	end

	local obj = takeVoice()
	obj.serial = voice.serial
	obj.cue = cueName
	obj.loop = cue.loop == true
	obj.endsAt = voice.endsAt
	obj.id = id
	obj.speed = speed
	active[voice.serial] = obj

	local player = obj.player
	local wanted = asset(id)
	if player.Asset ~= wanted then
		player.Asset = wanted
	end
	local vj = cue.volumeJitter or A.DEFAULT_VOLUME_JITTER
	player.PlaybackSpeed = speed
	player.Volume = math.clamp(Mix.jitter(cue.volume * (o.volume or 1), vj, rng:NextNumber(-1, 1)), 0, 10)
	player.Looping = obj.loop
	placeVoice(obj, bus, cue, at)
	startVoice(obj, o.delay or 0)

	if cue.duck then
		AudioDirector.duck(cueName)
	end
	local handler = captionHandler
	if cue.caption and o.caption ~= false and handler then
		task.spawn(handler, cue.caption, positionOf(at))
	end

	local serial = voice.serial
	return function()
		if active[serial] == obj then
			recycle(obj)
		end
	end
end

function AudioDirector.stopCue(cueName: string)
	if not built then
		return
	end
	for serial, obj in active do
		if obj.cue == cueName then
			stopSerial(serial)
		end
	end
end

function AudioDirector.stopAll()
	if not built then
		return
	end
	for serial in active do
		stopSerial(serial)
	end
end

-- The clone arpeggio, the sound logo (§7.2): one chime per clone, a pentatonic step higher each, 60 ms apart
-- (squeezed to 0.4 s in all), scheduled on the mixer clock so the spacing is exact.
function AudioDirector.arpeggio(clones: number)
	local offsets = Mix.arpeggioOffsets(math.max(0, math.floor(clones)), A.ARPEGGIO_STAGGER, A.ARPEGGIO_MAX_STAGGER)
	for i, offset in offsets do
		AudioDirector.play("CloneChime", { step = i - 1, delay = offset })
	end
end

-- Play what a replicated sim event sounds like (Audio/EventCues), for players and clones alike. Call it for
-- live events only (not when catching up after a Sync).
function AudioDirector.event(e: SimEvent, resolve: Resolver)
	local fields = e :: any
	for _, act in EventCues.forKind(e.kind) do
		if act.stop then
			AudioDirector.stopCue(act.stop)
		end
		if act.music then
			AudioDirector.music(act.music)
		end
		local cueName = act.cue
		if cueName == nil then
			continue
		end
		local actorId: number = if act.actor then (tonumber(fields[act.actor]) or 0) else 0
		local mine = actorId > 0 and resolve.isMine(actorId)
		if (act.mine == "only" and not mine) or (act.mine == "not" and mine) then
			continue
		end
		local at = nil
		if act.at and not (act.mine == "2d" and mine) then
			local index = if act.at == "actor" then actorId else (tonumber(fields[act.index or "a"]) or 0)
			at = resolve.position(act.at, index)
		end
		AudioDirector.play(cueName, {
			at = at,
			clone = actorId > 0 and resolve.isClone(actorId),
			caption = act.caption,
		})
	end
end

-------------------------------------------------------------------------------------------------------------
-- Music
-------------------------------------------------------------------------------------------------------------

local function isChristmas(): boolean
	if christmasOverride ~= nil then
		return christmasOverride
	end
	local t = DateTime.now():ToUniversalTime()
	return Mix.inWindow({ t.Year, t.Month, t.Day }, A.CHRISTMAS)
end

local function buildDeck(setName: string): Deck?
	local existing = decks[setName]
	if existing then
		return existing
	end
	local set = Cues.sets[setName]
	if set == nil or #set.ids == 0 then
		warnOnce("set:" .. setName, "no music set named " .. setName)
		return nil
	end
	local group = fader("Set_" .. setName, 0)
	wire(group, musicDuck, root)
	local deck: Deck = { setName = setName, set = set, players = {}, faders = {}, group = group, active = 1 }
	for i, id in set.ids do
		local p = Instance.new("AudioPlayer")
		p.Name = setName .. "_" .. i
		p.Looping = true
		p.Volume = set.volume
		p.Asset = asset(id)
		p.Parent = root
		local f = fader(setName .. "_Mix" .. i, 0)
		wire(p, f, root)
		wire(f, group, root)
		table.insert(deck.players, p)
		table.insert(deck.faders, f)
	end
	decks[setName] = deck
	return deck
end

local function deckGains(deck: Deck): { number }
	return Mix.setGains(deck.set.kind, A.MUSIC_MODE, tier, #deck.players, deck.set.tierToMix, deck.active)
end

-- Only the audible players of a playlist or a "mixes" set play (one decode, not five); in
-- "stems" mode every stem plays in sync so a higher tier can fade in on the beat.
local function playsSilent(deck: Deck): boolean
	return deck.set.kind ~= "playlist" and A.MUSIC_MODE == "stems"
end

local function setMixGains(deck: Deck, seconds: number)
	local gains = deckGains(deck)
	local ref: AudioPlayer? = nil
	for _, p in deck.players do
		if p.IsPlaying then
			ref = p
			break
		end
	end
	for i, g in gains do
		local p = deck.players[i]
		if g > 0 and not p.IsPlaying then
			-- a newly audible mix joins at the playing one's position, then crossfades in
			if ref then
				p.TimePosition = ref.TimePosition
			end
			p.PlaybackSpeed = 1
			p:Play()
		end
		local t = tween(deck.faders[i], seconds, { Volume = g })
		if g == 0 and not playsSilent(deck) then
			t.Completed:Once(function(status: Enum.PlaybackState)
				if status == Enum.PlaybackState.Completed and deckGains(deck)[i] == 0 then
					pcall(function()
						p:Stop()
					end)
				end
			end)
		end
	end
end

-- Start the deck's players from the top on the same sample (S4 primary) or in one frame (fallback).
local function startDeck(deck: Deck)
	local gains = deckGains(deck)
	local scheduled = A.STEM_START == "scheduled" and mixerOk
	local at = mixerNow() + A.SCHEDULE_LEAD
	local all = playsSilent(deck)
	for i, p in deck.players do
		pcall(function()
			p:Stop()
		end)
		p.PlaybackSpeed = 1
		p.TimePosition = 0
		deck.faders[i].Volume = gains[i]
		if gains[i] <= 0 and not all then
			continue -- silent mix: not decoded until layers() fades it in
		end
		local ok = false
		if scheduled then
			ok = pcall(function()
				p:Play(at)
			end)
		end
		if not ok then
			p:Play()
		end
	end
end

local function stopDeck(deck: Deck)
	for _, p in deck.players do
		pcall(function()
			p:Stop()
		end)
	end
end

local function fadeDeck(deck: Deck, to: number, seconds: number, thenStop: boolean)
	local old = deck.tween
	if old then
		old:Cancel()
	end
	local t = tween(deck.group, seconds, { Volume = to })
	deck.tween = t
	if thenStop then
		t.Completed:Once(function(status: Enum.PlaybackState)
			if status == Enum.PlaybackState.Completed and current ~= deck then
				stopDeck(deck)
			end
		end)
	end
end

local function setFor(stateName: string, opts: MusicOptions): string?
	if opts.set then
		return opts.set
	end
	local st = Cues.states[stateName]
	if st == nil then
		return nil
	end
	if st.xmas and isChristmas() then
		return st.xmas
	end
	return st.set
end

function AudioDirector.music(stateName: string, opts: MusicOptions?)
	build()
	local o: MusicOptions = opts or {}
	local fade = if firstMusic then A.JOIN_FADE_IN elseif stateName == "Alarm" then A.ALARM_FADE else A.STATE_FADE
	if stateName == "Off" then
		musicState = "Off"
		local cur = current
		current = nil
		if cur then
			fadeDeck(cur, 0, A.STATE_FADE, true)
		end
		return
	end
	local setName = setFor(stateName, o)
	if setName == nil then
		warnOnce("state:" .. stateName, "unknown music state " .. stateName)
		return
	end
	local cur = current
	if cur and cur.setName == setName and musicState == stateName and not o.restart then
		return
	end
	local deck = buildDeck(setName)
	if deck == nil then
		return
	end
	if deck.set.kind == "playlist" and (cur == nil or cur.setName ~= setName) then
		local turn = (playlistTurn[setName] or 0) % #deck.players + 1
		playlistTurn[setName] = turn
		deck.active = turn
	end
	if cur and cur ~= deck then
		fadeDeck(cur, 0, fade, true)
	end
	musicState = stateName
	current = deck
	startDeck(deck)
	fadeDeck(deck, 1, fade, false)
	firstMusic = false
end

-- Crew Layers: the tier follows the clone count. Call it on GO (layers change on GO and fade in over a bar).
function AudioDirector.layers(clones: number)
	build()
	local newTier = Mix.tierFor(clones, A.LAYER_THRESHOLDS)
	if newTier == tier then
		return
	end
	tier = newTier
	local cur = current
	if cur and cur.set.kind == "mixes" then
		setMixGains(cur, A.LAYER_FADE)
	end
end

-- The rewind starts (§7.1): the music dives 1.0 -> 0.25 over 0.3 s and stops until GO; Ambience and the
-- Clone bus duck. Under reduced motion the dive is a plain fade (no pitch bend). Play TapeStop with it.
function AudioDirector.rewind()
	build()
	rewinding = true
	applyBusGains(0.1)
	AudioDirector.play("TapeStop")
	local cur = current
	if cur then
		if not reducedMotion then
			for _, p in cur.players do
				tween(p, A.TAPE_STOP_SECONDS, { PlaybackSpeed = A.TAPE_STOP_SPEED }, Enum.EasingStyle.Quad)
			end
		end
		fadeDeck(cur, 0, A.TAPE_STOP_SECONDS, false)
	end
end

-- The run starts (GO): un-duck, apply the tier for this run's clones, restart the music on the downbeat.
function AudioDirector.go(clones: number?)
	build()
	rewinding = false
	applyBusGains(A.REWIND_DUCK_RELEASE)
	if clones then
		tier = Mix.tierFor(clones, A.LAYER_THRESHOLDS)
	end
	local cur = current
	if cur and (musicState == "Heist" or musicState == "Alarm") then
		startDeck(cur)
		fadeDeck(cur, 1, 0.05, false)
	elseif cur then
		fadeDeck(cur, 1, A.LAYER_FADE, false)
	end
end

function AudioDirector.duck(reason: string, seconds: number?)
	build()
	Mix.addDuck(ducks, reason, os.clock(), seconds or A.DUCK_SECONDS)
end

-------------------------------------------------------------------------------------------------------------
-- Settings hooks (the settings UI and DataService settings call these; docs/AUDIO.md "Settings")
-------------------------------------------------------------------------------------------------------------

function AudioDirector.setBusVolume(bus: string, slider: number)
	if sliders[bus] == nil then
		warnOnce("bus:" .. bus, "unknown bus " .. bus)
		return
	end
	sliders[bus] = math.clamp(slider, 0, 1)
	applyBusGains(0.1)
end

function AudioDirector.setMuted(on: boolean)
	muted = on
	applyBusGains(0.1)
end

function AudioDirector.setReducedMotion(on: boolean)
	reducedMotion = on
end

-- nil = follow the Config.Audio.CHRISTMAS window
function AudioDirector.setChristmas(on: boolean?)
	christmasOverride = on
end

function AudioDirector.setCaptionHandler(handler: ((text: string, position: Vector3?) -> ())?)
	captionHandler = handler
end

function AudioDirector.status(): { [string]: any }
	local cur = current
	return {
		built = built,
		voices = if built then Voices.live(state) else 0,
		pooled = #pool,
		music = musicState,
		set = if cur then cur.setName else nil,
		tier = tier,
		mixerClock = mixerOk,
		christmas = isChristmas(),
		muted = muted,
	}
end

-- Load the first-impression cues (and the music sets most likely next) so the first play is not late.
function AudioDirector.preload(extraSets: { string }?)
	build()
	local list: { string } = {}
	for _, name in A.PRELOAD do
		local cue = Cues.cues[name]
		for _, id in if cue then cue.ids else {} do
			table.insert(list, asset(id))
		end
	end
	for _, setName in extraSets or {} do
		local set = Cues.sets[setName]
		for _, id in if set then set.ids else {} do
			table.insert(list, asset(id))
		end
	end
	if #list > 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
			if not ok then
				warnOnce("preload", "preload failed: " .. tostring(err))
			end
		end)
	end
end

-------------------------------------------------------------------------------------------------------------
-- Housekeeping: free finished voices, follow the music duck (one connection, ~20 Hz)
-------------------------------------------------------------------------------------------------------------

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
	if not built then
		return
	end
	acc += dt
	if acc < 0.05 then
		return
	end
	acc = 0
	local now = os.clock()
	for serial, obj in active do
		if obj.loop or now < obj.endsAt then
			continue
		end
		local p = obj.player
		if p.TimeLength > 0 then
			lengthOf[obj.id] = p.TimeLength
		end
		if p.IsPlaying and p.TimeLength > 0 and p.TimePosition < p.TimeLength then
			-- still sounding (its length was only an estimate until the asset loaded): extend
			local rest = (p.TimeLength - p.TimePosition) / math.max(obj.speed, 0.05)
			obj.endsAt = now + rest + 0.05
			Voices.extend(state, serial, obj.endsAt)
		else
			recycle(obj)
		end
	end
	Mix.pruneDucks(ducks, now)
	local wantDuck = Mix.duckDb(ducks, now, A.DUCK_DB) ~= 0
	if wantDuck ~= duckOn then
		duckOn = wantDuck
		tween(
			musicDuck,
			if wantDuck then A.DUCK_ATTACK else A.DUCK_RELEASE,
			{ Volume = if wantDuck then Mix.dbToGain(A.DUCK_DB) else 1 }
		)
	end
end)

return AudioDirector
