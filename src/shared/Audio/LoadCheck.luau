--!strict
-- Audio/LoadCheck: the live load check for every audio id (lihfolk-sfx "Review before shipping" 8, feel.md
-- D5 "live load checks catch silent ids"). Takedowns and permission problems fail silently in Roblox, so
-- this loads each Manifest id into a throwaway AudioPlayer in a real server or client and reports the ones
-- that never become ready. Run it from an Open Cloud Luau Execution task (docs/AUDIO.md "Live load check")
-- or the Studio command bar:
--   print(require(game.ReplicatedStorage.Shared.Audio.LoadCheck).run(20).text)
-- Not pure (it creates instances and yields); it is not required by the game at runtime.

local Manifest = require("./Manifest")

export type Report = {
	ok: number,
	failed: { number },
	lengths: { [number]: number }, -- id -> TimeLength (seconds) as the engine measured it
	text: string,
}

local LoadCheck = {}

function LoadCheck.run(timeoutSeconds: number?): Report
	local timeout = timeoutSeconds or 20
	local folder = Instance.new("Folder")
	folder.Name = "AudioLoadCheck"
	folder.Parent = game:GetService("SoundService")
	local players: { [number]: AudioPlayer } = {}
	local ids: { number } = {}
	for id in Manifest.assets do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local p = Instance.new("AudioPlayer")
		p.Name = tostring(id)
		p.Asset = "rbxassetid://" .. tostring(id)
		p.Parent = folder
		players[id] = p
	end
	local deadline = os.clock() + timeout
	local pending = #ids
	while pending > 0 and os.clock() < deadline do
		task.wait(0.25)
		pending = 0
		for _, id in ids do
			if not players[id].IsReady then
				pending += 1
			end
		end
	end
	local report: Report = { ok = 0, failed = {}, lengths = {}, text = "" }
	local lines: { string } = {}
	for _, id in ids do
		local p = players[id]
		if p.IsReady then
			report.ok += 1
			report.lengths[id] = p.TimeLength
			local want = Manifest.assets[id].seconds
			if math.abs(p.TimeLength - want) > 1.5 then
				table.insert(lines, string.format("LENGTH %d: store %d s, engine %.2f s", id, want, p.TimeLength))
			end
		else
			table.insert(report.failed, id)
			table.insert(
				lines,
				string.format("FAIL %d not ready after %d s (%s)", id, timeout, Manifest.assets[id].title)
			)
		end
	end
	folder:Destroy()
	table.insert(lines, 1, string.format("audio load check: %d/%d ready", report.ok, #ids))
	report.text = table.concat(lines, "\n")
	return report
end

return LoadCheck
