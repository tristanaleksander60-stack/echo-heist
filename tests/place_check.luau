-- Opens the Rojo-built place file and checks that every script landed where
-- the game expects it. Run after `rojo build -o build/EchoHeist.rbxlx`:
--   lune run tests/place_check.luau build/EchoHeist.rbxlx

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

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

local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")
local sp = game:GetService("StarterPlayer")

local shared = rs:FindFirstChild("Shared")
expect(shared ~= nil, "ReplicatedStorage.Shared exists")
local config = shared and shared:FindFirstChild("Config")
expect(config ~= nil and config.ClassName == "ModuleScript", "Shared.Config is a ModuleScript")

local server = sss:FindFirstChild("Server")
expect(server ~= nil and server.ClassName == "Script", "ServerScriptService.Server is a Script")
for _, name in { "LevelBuilder", "Actors", "Loot", "Mechanisms", "Guard", "Echoes" } do
	local m = server and server:FindFirstChild(name)
	expect(m ~= nil and m.ClassName == "ModuleScript", "Server." .. name .. " is a ModuleScript")
end

local sps = sp:FindFirstChild("StarterPlayerScripts")
local client = sps and sps:FindFirstChild("Client")
expect(client ~= nil and client.ClassName == "LocalScript", "StarterPlayerScripts.Client is a LocalScript")

-- Every require(script...:WaitForChild("X")) in the server script must resolve to a child.
if server then
	local src = server.Source
	for name in string.gmatch(src, 'require%(script:WaitForChild%("([%w_]+)"%)%)') do
		expect(server:FindFirstChild(name) ~= nil, "server require resolves: " .. name)
	end
end

print(string.format("\n%d problem(s)", problems))
process.exit(if problems > 0 then 1 else 0)
