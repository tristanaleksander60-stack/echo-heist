--!strict
-- Heist/UiImages: resolves the UI kit's Decal ids to image ids at server boot (a Decal id is not an
-- image id: docs/art/KIT_IMPORT.md "Atlas ids"; the same LoadAsset trick KitService uses) and
-- publishes each as the ReplicatedStorage attribute EH_UiImage_<stem> = "rbxassetid://<image>".
-- Client Heist/Theme reads it (Theme.onImage); until it arrives the UI renders without images.
-- Cosmetic only. Recorded image ids (Shared/Heist/UiAssets `image`) skip the lookup:
-- `python3 tools/kit_upload.py --set-ui-image <stem> <id>` with the id this prints in the log.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist"):WaitForChild("UiAssets"))

local UiImages = {}

local TRIES = 3

local function resolve(stem: string, decalId: number): string?
	for attempt = 1, TRIES do
		local ok, loaded = pcall(function()
			return InsertService:LoadAsset(decalId)
		end)
		if ok and loaded then
			local decal = if loaded:IsA("Decal") then loaded else loaded:FindFirstChildWhichIsA("Decal", true)
			local texture = if decal and decal:IsA("Decal") then decal.Texture else ""
			loaded:Destroy()
			local digits = string.match(texture, "(%d+)%s*$")
			if digits then
				return "rbxassetid://" .. digits
			end
			warn(string.format("[UiImages] %s: Decal %d has no texture id", stem, decalId))
			return nil
		end
		task.wait(attempt)
	end
	warn(string.format("[UiImages] %s: LoadAsset(%d) failed; the UI keeps its fallback", stem, decalId))
	return nil
end

function UiImages.start()
	for stem, entry in UiAssets do
		local attr = "EH_UiImage_" .. stem
		if entry.image > 0 then
			ReplicatedStorage:SetAttribute(attr, "rbxassetid://" .. tostring(entry.image))
		else
			task.spawn(function()
				local uri = resolve(stem, entry.decal)
				if uri then
					ReplicatedStorage:SetAttribute(attr, uri)
					print(string.format("[UiImages] %s: Decal %d -> image %s", stem, entry.decal, uri))
				end
			end)
		end
	end
end

return UiImages
