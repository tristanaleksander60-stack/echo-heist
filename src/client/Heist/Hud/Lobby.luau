--!strict
-- Hud/Lobby: the hideout's HUD (LOBBY track, Config.Hideout). Minimal by design: walking about in first person you
-- see the reticle and its prompt chip (Hud/Reticle: "JOB BOARD", "PICK VAN", "SOLO · GO", "SIT", "READY"...), the
-- toast rail low on the screen (HudLayout.RAIL_FP) and, on touch, a USE button (HudLayout.LOBBY_USE, where Interact
-- sits in a run) that does what E / X / a click do. Nothing else: the job board, the laptop and the wardrobe open
-- their sheets only at their stations (Heist/Hideout). The drive to the heist shows a SKIP chip
-- (HudLayout.LOBBY_SKIP; any key or tap skips too). While you look for a Quick Crew a chip top left says so
-- ("LOOKING FOR CREW", then "FOLLOW THE ARROW" once a seat is held) with STOP (HudLayout.LOBBY_QUICK): opt out any
-- time. Every word is in Shared/Heist/Strings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Heist = script.Parent.Parent
local Ui = require(Heist:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local U = Config.Ui

local Lobby = {}

function Lobby.build(ctx: any): any
	local lobby = {}
	local onUse: (() -> ())? = nil
	local onSkip: (() -> ())? = nil
	local use = Ui.button(ctx.root, {
		Name = "LobbyUse",
		BackgroundColor3 = Palette.gold,
		TextSize = 22,
		Text = Strings.LOBBY_USE,
		Visible = false,
	}, function()
		local fn = onUse
		if fn then
			fn()
		end
	end, "UIConfirm")
	Common.place(use, HudLayout.LOBBY_USE)
	Common.keyCap(use, "use")
	local skip = Ui.button(ctx.root, {
		Name = "DriveSkip",
		BackgroundColor3 = Palette.exit,
		TextSize = 20,
		Text = Strings.LOBBY_SKIP,
		Visible = false,
	}, function()
		local fn = onSkip
		if fn then
			fn()
		end
	end, "UIClick")
	Common.place(skip, HudLayout.LOBBY_SKIP)
	Ui.iconWord(skip, "fast_forward", "left", U.ICON_SMALL)
	lobby.use = use

	-- Quick Crew: the looking / matched chip with STOP
	local onStop: (() -> ())? = nil
	local quickChip = Ui.panel(ctx.root, { Name = "LobbyQuick", Visible = false }, Palette.gold)
	Common.place(quickChip, HudLayout.LOBBY_QUICK)
	local Q = HudLayout.LOBBY_QUICK
	local stopW = 108
	local quickLabel = Ui.label(quickChip, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -(stopW + 20), 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 18,
		TextColor3 = Palette.gold,
		Text = Strings.QUICK_SEEKING,
	})
	local stop = Ui.button(quickChip, {
		Name = "QuickStop",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(stopW, Q.h - 8),
		TextSize = 16,
		Text = Strings.QUICK_STOP,
	}, function()
		local fn = onStop
		if fn then
			fn()
		end
	end, "UIBack")
	Ui.iconWord(stop, "close", "left", U.ICON_SMALL)
	lobby.quickChip = quickChip

	local shown = false
	-- The lobby view: shown = you roam in first person (no station, no drive); prompt = the look target's chip.
	function lobby.set(on: boolean, prompt: any?, useFn: (() -> ())?)
		if on ~= shown then
			shown = on
			if on then
				ctx.fpLayout(true) -- the rail goes low, out of the reticle's way
			end
		end
		ctx.reticle.set(on, if on then prompt else nil)
		onUse = useFn
		local wantUse = on and prompt ~= nil and not prompt.locked and Common.usingTouch()
		if use.Visible ~= wantUse then
			use.Visible = wantUse
		end
		if wantUse and prompt and use.Text ~= prompt.text then
			use.Text = prompt.text
		end
	end

	-- q = the server's QuickCrew attribute: "" (not looking: hidden) | "seek" | "matched"; stopFn = STOP.
	function lobby.setQuick(q: string, stopFn: (() -> ())?)
		onStop = stopFn
		local on = q == "seek" or q == "matched"
		if quickChip.Visible ~= on then
			quickChip.Visible = on
		end
		local text = if q == "matched" then Strings.QUICK_MATCHED else Strings.QUICK_SEEKING
		if quickLabel.Text ~= text then
			quickLabel.Text = text
		end
	end

	function lobby.setSkip(on: boolean, fn: (() -> ())?)
		onSkip = fn
		skip.Visible = on
	end

	function lobby.hide()
		lobby.set(false, nil, nil)
		lobby.setSkip(false, nil)
		lobby.setQuick("", nil)
	end

	return lobby
end

return Lobby
