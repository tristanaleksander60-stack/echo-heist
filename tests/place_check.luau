-- Opens a Rojo-built place file and checks that every script landed where it
-- is expected and that the "Heist Night" Lighting recipe v1 (MASTERPLAN §6.3,
-- spike S6) came out of the project file. Run after the builds:
--   rojo build -o build/EchoHeist.rbxlx
--   lune run tests/place_check.luau build/EchoHeist.rbxlx
--   rojo build bench.project.json -o build/CloneBench.rbxlx
--   lune run tests/place_check.luau build/CloneBench.rbxlx

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Config = require("../src/shared/Config")

local path = process.args[1] or "build/EchoHeist.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))

local problems = 0
local function expect(cond: boolean, msg: string)
	if cond then
		print("ok    " .. msg)
	else
		problems += 1
		print("FAIL  " .. msg)
	end
end

-- Lighting ("Heist Night" recipe v1) ----------------------------------------------

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-3
end

local function rgb(c: any): string
	return string.format("(%d,%d,%d)", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

-- expected: number | boolean | string (enum item name) | { r, g, b } (0-255)
local function expectProps(inst: any, label: string, props: { [string]: any })
	for name, want in props do
		local ok, got = pcall(function()
			return inst[name]
		end)
		local pass = false
		local shown = tostring(got)
		if not ok then
			shown = "unreadable"
		elseif type(want) == "number" then
			pass = type(got) == "number" and near(got, want)
		elseif type(want) == "boolean" then
			pass = got == want
		elseif type(want) == "string" then
			pass = typeof(got) == "EnumItem" and got.Name == want
			shown = if typeof(got) == "EnumItem" then got.Name else shown
		elseif type(want) == "table" then
			pass = typeof(got) == "Color3"
				and rgb(got) == rgb({ R = want[1] / 255, G = want[2] / 255, B = want[3] / 255 })
			shown = if typeof(got) == "Color3" then rgb(got) else shown
		end
		expect(
			pass,
			string.format(
				"%s.%s = %s (got %s)",
				label,
				name,
				tostring(
					if type(want) == "table"
						then rgb({ R = want[1] / 255, G = want[2] / 255, B = want[3] / 255 })
						else want
				),
				shown
			)
		)
	end
end

local lighting = game:GetService("Lighting")
expectProps(lighting, "Lighting", {
	LightingStyle = "Realistic", -- not scriptable: only the project file can set it
	PrioritizeLightingQuality = true, -- not scriptable either
	GlobalShadows = true,
	ClockTime = 0,
	Brightness = 0.5,
	Ambient = { 55, 55, 95 },
	OutdoorAmbient = { 75, 80, 130 },
	ColorShift_Top = { 255, 210, 160 },
	EnvironmentDiffuseScale = 0.25,
	EnvironmentSpecularScale = 0.35,
	ExposureCompensation = 0.2,
})

local LIGHTING_CHILDREN: { [string]: { class: string, props: { [string]: any } } } = {
	Atmosphere = {
		class = "Atmosphere",
		props = { Density = 0.3, Color = { 70, 60, 120 }, Decay = { 35, 30, 75 }, Haze = 0.8 },
	},
	Bloom = { class = "BloomEffect", props = { Intensity = 0.8, Size = 28, Threshold = 1.0 } },
	ColorCorrection = {
		class = "ColorCorrectionEffect",
		props = { Contrast = 0.12, Saturation = 0.1, TintColor = { 235, 230, 255 } },
	},
	ColorGrading = { class = "ColorGradingEffect", props = { TonemapperPreset = "Default" } },
}
for name, spec in LIGHTING_CHILDREN do
	local child = lighting:FindFirstChild(name)
	expect(child ~= nil and child.ClassName == spec.class, string.format("Lighting.%s is a %s", name, spec.class))
	if child then
		expectProps(child, "Lighting." .. name, spec.props)
	end
end
-- No SunRays; DepthOfField and Blur only in menus / plan camera / reel (added at runtime)
local banned = {}
for _, child in lighting:GetChildren() do
	if child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") or child:IsA("BlurEffect") then
		table.insert(banned, child.ClassName)
	end
end
expect(
	#banned == 0,
	"Lighting has no SunRays, DepthOfField or Blur"
		.. (if #banned > 0 then " (found " .. table.concat(banned, ", ") .. ")" else "")
)

-- Scripts ----------------------------------------------------------------------------

local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")
local sp = game:GetService("StarterPlayer")
local sps = sp:FindFirstChild("StarterPlayerScripts")

if sss:FindFirstChild("BenchServer") then
	-- Clone phone bench (bench.project.json, spike S1)
	local benchShared = rs:FindFirstChild("Bench")
	local benchConfig = benchShared and benchShared:FindFirstChild("BenchConfig")
	expect(
		benchConfig ~= nil and benchConfig.ClassName == "ModuleScript",
		"ReplicatedStorage.Bench.BenchConfig is a ModuleScript"
	)
	local benchServer = sss:FindFirstChild("BenchServer")
	expect(benchServer ~= nil and benchServer.ClassName == "Script", "ServerScriptService.BenchServer is a Script")
	local benchClient = sps and sps:FindFirstChild("BenchClient")
	expect(
		benchClient ~= nil and benchClient.ClassName == "LocalScript",
		"StarterPlayerScripts.BenchClient is a LocalScript"
	)
	for _, name in { "Looks", "Meter" } do
		local m = benchClient and benchClient:FindFirstChild(name)
		expect(m ~= nil and m.ClassName == "ModuleScript", "BenchClient." .. name .. " is a ModuleScript")
	end
	expect(rs:FindFirstChild("Shared") == nil and sss:FindFirstChild("Server") == nil, "bench place holds no game code")
	print(string.format("\n%d problem(s)", problems))
	process.exit(if problems > 0 then 1 else 0)
end

-- Spike places (spikes/*.project.json): S3 video capture and S4 stems
local SPIKES: { [string]: { config: string } } = {
	Capture = { config = "CaptureConfig" },
	Stems = { config = "StemsConfig" },
}
for key, spec in SPIKES do
	if sss:FindFirstChild(key .. "Server") then
		local spikeShared = rs:FindFirstChild(key .. "Spike")
		local spikeConfig = spikeShared and spikeShared:FindFirstChild(spec.config)
		expect(
			spikeConfig ~= nil and spikeConfig.ClassName == "ModuleScript",
			"ReplicatedStorage." .. key .. "Spike." .. spec.config .. " is a ModuleScript"
		)
		local spikeServer = sss:FindFirstChild(key .. "Server")
		expect(
			spikeServer ~= nil and spikeServer.ClassName == "Script",
			"ServerScriptService." .. key .. "Server is a Script"
		)
		local spikeClient = sps and sps:FindFirstChild(key .. "Client")
		expect(
			spikeClient ~= nil and spikeClient.ClassName == "LocalScript",
			"StarterPlayerScripts." .. key .. "Client is a LocalScript"
		)
		expect(
			rs:FindFirstChild("Shared") == nil and sss:FindFirstChild("Server") == nil,
			"spike place holds no game code"
		)
		print(string.format("\n%d problem(s)", problems))
		process.exit(if problems > 0 then 1 else 0)
	end
end

local shared = rs:FindFirstChild("Shared")
expect(shared ~= nil, "ReplicatedStorage.Shared exists")
local config = shared and shared:FindFirstChild("Config")
expect(config ~= nil and config.ClassName == "ModuleScript", "Shared.Config is a ModuleScript")
-- Lint configs (Sim/selene.toml, Sim/sim.yml) must not sync in as ModuleScripts
local leaked = {}
for _, d in (if shared then shared:GetDescendants() else {}) do
	if d.Name == "selene" or d.Name == "sim" or d.Name == "README" then
		table.insert(leaked, d:GetFullName())
	end
end
expect(
	#leaked == 0,
	"no lint config or README synced into Shared"
		.. (if #leaked > 0 then " (" .. table.concat(leaked, ", ") .. ")" else "")
)

local server = sss:FindFirstChild("Server")
expect(server ~= nil and server.ClassName == "Script", "ServerScriptService.Server is a Script")
for _, name in { "Main", "LevelBuilder", "Actors", "Loot", "Mechanisms", "Guard", "Echoes" } do
	local m = server and server:FindFirstChild(name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "Server." .. name .. " is a ModuleScript")
end

-- Sim game path (Config.GAME_MODE = "sim"): server, client and shared Heist modules
local heistServer = server and server:FindFirstChild("Heist")
expect(heistServer ~= nil and heistServer.ClassName == "Folder", "Server.Heist is a Folder")
for _, name in { "HeistService", "HeistInstance", "LevelBuilder", "KitPlan", "KitDresser", "Lobby", "Avatars" } do
	local m = heistServer and heistServer:FindFirstChild(name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "Server.Heist." .. name .. " is a ModuleScript")
end
-- The modules the entry script and the heist server require by path (sim path wiring:
-- analytics + LiveFlags, the art kit) are where those requires look for them.
for _, where in
	{ { "Analytics", "Analytics" }, { "Analytics", "LiveFlags" }, { "Kit", "KitService" }, { "Kit", "KitData" } }
do
	local folder = server and server:FindFirstChild(where[1])
	local m = folder and folder:FindFirstChild(where[2])
	expect(m ~= nil and m.ClassName == "ModuleScript", "Server." .. where[1] .. "." .. where[2] .. " is a ModuleScript")
end
-- Every require(script.Parent:WaitForChild("X")) in Server.Heist lands on a sibling module.
if heistServer then
	for _, m in heistServer:GetChildren() do
		if m:IsA("ModuleScript") then
			for name in string.gmatch(m.Source, 'require%(script%.Parent:WaitForChild%("([%w_]+)"%)%)') do
				local target = heistServer:FindFirstChild(name)
				expect(
					target ~= nil and target:IsA("ModuleScript"),
					"Server.Heist." .. m.Name .. " require resolves: " .. name
				)
			end
		end
	end
end
local heistShared = shared and shared:FindFirstChild("Heist")
for _, name in { "Protocol", "Palette" } do
	local m = heistShared and heistShared:FindFirstChild(name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "Shared.Heist." .. name .. " is a ModuleScript")
end
do
	local clientScript = sps and sps:FindFirstChild("Client")
	local heistClient = clientScript and clientScript:FindFirstChild("Heist")
	for _, name in { "HeistClient", "EchoView", "GusView", "WorldView", "RewindDirector", "Hud", "Rigs", "Ui" } do
		local m = heistClient and heistClient:FindFirstChild(name)
		expect(m ~= nil and m.ClassName == "ModuleScript", "Client.Heist." .. name .. " is a ModuleScript")
	end
end
-- The default game is the v0.1 prototype until the owner switches (fun gate, Nov 16).
expect(
	config ~= nil and string.find(config.Source, 'Config.GAME_MODE = "v01"', 1, true) ~= nil,
	'Config.GAME_MODE defaults to "v01"'
)

-- Data layer (docs/DATA.md): lihfolk-systems modules where the library expects them
local lihfolk = rs:FindFirstChild("LihFolk")
expect(lihfolk ~= nil and lihfolk.ClassName == "Folder", "ReplicatedStorage.LihFolk is a Folder")
for _, name in { "Signal", "Net", "RateLimit", "Janitor", "Feedback" } do
	local m = lihfolk and lihfolk:FindFirstChild(name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "LihFolk." .. name .. " is a ModuleScript")
end
local dataServer = server and server:FindFirstChild("Data")
expect(dataServer ~= nil and dataServer.ClassName == "Folder", "Server.Data is a Folder")
for _, name in { "DataService", "PlayerData", "Policy", "Currency", "Inventory", "Rewards", "Receipts", "Shop" } do
	local m = dataServer and dataServer:FindFirstChild(name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "Server.Data." .. name .. " is a ModuleScript")
end
local dataShared = shared and shared:FindFirstChild("Data")
for _, name in { "Schema", "Progress", "DailyVault", "Store", "Keys", "Calendar", "ProductPrices" } do
	local m = dataShared and dataShared:FindFirstChild(name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "Shared.Data." .. name .. " is a ModuleScript")
end
-- Exactly one ProcessReceipt assignment in the whole place (lihfolk-systems Receipts)
local receiptAssignments = {}
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		local src = d.Source
		for _ in string.gmatch(src, "%.ProcessReceipt%s*=[^=]") do
			table.insert(receiptAssignments, d:GetFullName())
		end
	end
end
expect(
	#receiptAssignments == 1,
	"exactly one ProcessReceipt assignment (found "
		.. #receiptAssignments
		.. ": "
		.. table.concat(receiptAssignments, ", ")
		.. ")"
)

local client = sps and sps:FindFirstChild("Client")
expect(client ~= nil and client.ClassName == "LocalScript", "StarterPlayerScripts.Client is a LocalScript")

-- Every require(script...:WaitForChild("X")) in the server script must resolve to a child.
if server then
	local main = server:FindFirstChild("Main")
	local src = main and main.Source or ""
	for name in string.gmatch(src, 'require%(script%.Parent:WaitForChild%("([%w_]+)"%)%)') do
		expect(server:FindFirstChild(name) ~= nil, "server require resolves: " .. name)
	end
end

-- Pure layers (shared/Sim, shared/Rec, shared/Levels) use relative string requires
-- ("./X" = sibling of the script, "../X" = sibling of its folder). Each one must land
-- on a ModuleScript in the built place, so the sim loads on Roblox as it does in Lune.
local sharedRoot = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
if sharedRoot and sharedRoot:FindFirstChild("Sim") then
	local function resolve(from: any, rel: string): any
		local node = from.Parent
		local rest = rel
		if string.sub(rest, 1, 2) == "./" then
			rest = string.sub(rest, 3)
		end
		while string.sub(rest, 1, 3) == "../" do
			node = node and node.Parent
			rest = string.sub(rest, 4)
		end
		for seg in string.gmatch(rest, "[^/]+") do
			node = node and node:FindFirstChild(seg)
		end
		return node
	end
	local checked, bad = 0, 0
	for _, folderName in { "Sim", "Rec", "Levels", "Heist" } do
		local folder = sharedRoot:FindFirstChild(folderName)
		for _, m in (if folder then folder:GetDescendants() else {}) do
			if m:IsA("ModuleScript") then
				for p in string.gmatch(m.Source, 'require%("(%.%.?/[^"]+)"%)') do
					checked += 1
					local target = resolve(m, p)
					if not (target and target:IsA("ModuleScript")) then
						bad += 1
						print("FAIL  " .. m:GetFullName() .. ' require("' .. p .. '")')
					end
				end
			end
		end
	end
	expect(
		bad == 0 and checked > 0,
		string.format("pure layers + Shared.Heist: %d relative require(s) resolve in the place", checked)
	)
end

-- Single source of truth: the level code must not set Lighting service properties
if server then
	local builder = server:FindFirstChild("LevelBuilder")
	local src = builder and builder.Source or ""
	local assigns = string.match(src, "Lighting%.[%w_]+%s*=") ~= nil
	expect(not assigns, "LevelBuilder does not assign Lighting properties (project file owns them)")
end

-- StreamingEnabled (MASTERPLAN §3.3, §8.6): off until the Nov 16 fun gate (v0.1 was never
-- checked under streaming). Once the project file turns it on, its settings must match.
do
	local ws = game:GetService("Workspace")
	local okOn, on = pcall(function()
		return (ws :: any).StreamingEnabled
	end)
	if okOn and on == true then
		expectProps(ws, "Workspace", {
			StreamingMinRadius = 128,
			StreamingTargetRadius = 512,
		})
		local okMode, mode = pcall(function()
			return tostring((ws :: any).StreamOutBehavior)
		end)
		expect(
			okMode and string.find(mode, "Opportunistic", 1, true) ~= nil,
			"Workspace.StreamOutBehavior Opportunistic"
		)
		expect(
			Config.Heist.INSTANCE_SPACING > 2 * 512,
			"instance spacing is wider than twice the streaming target radius"
		)
	else
		print("info  Workspace.StreamingEnabled is off (flip after the fun gate: MASTERPLAN §3.3)")
	end
end

print(string.format("\n%d problem(s)", problems))
process.exit(if problems > 0 then 1 else 0)
