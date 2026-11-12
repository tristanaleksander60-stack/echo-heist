# Kit import: from FBX files to `assets/Kit.rbxm` (spike S2)

_For the owner. About 30 minutes the first time, 10 minutes after that. Written 2026-11-12._

**Goal.** Claude builds the art in Blender and writes FBX files to `assets/fbx/`. Roblox Studio must import them once and save them as one file, `assets/Kit.rbxm`. Rojo then puts that file into `ServerStorage/Kit`. The game only **clones** these pieces. It never creates meshes itself.

**Spike S2 passes when** the built place has every piece with the right size and the right collision (MASTERPLAN §8.11).

You import 6 FBX files and get 9 MeshParts. The table below shows what Studio must show after the import. Studio uses Y for up, so the numbers are X x Y x Z.

| FBX file | MeshPart | Size in Studio (X x Y x Z) | Tris | CollisionFidelity | Material | CanCollide | CastShadow |
|---|---|---|---|---|---|---|---|
| Bank_Wall_4x12.fbx | Bank_Wall_4x12 | 4 x 12 x 2 | 196 | Box | SmoothPlastic | on | on |
| Bank_Wall_8x12.fbx | Bank_Wall_8x12 | 8 x 12 x 2 | 284 | Box | SmoothPlastic | on | on |
| Diamond.fbx | Diamond | 2 x 1.75 x 2 | 94 | Box | SmoothPlastic | off | off |
| GoldBar.fbx | GoldBar | 2 x 0.6 x 1 | 52 | Box | SmoothPlastic | on | off |
| GoldStack.fbx | GoldStack | 2.04 x 1.8 x 3.1 | 312 | Box | SmoothPlastic | on | on |
| VaultDoor_Greybox.fbx | VaultDoor_Frame | 16 x 12 x 3.5 | 1196 | PreciseConvexDecomposition | SmoothPlastic | on | on |
| VaultDoor_Greybox.fbx | VaultDoor_Door | 11.6 x 8.6 x 2.75 | 1504 | Hull | SmoothPlastic | on | on |
| VaultDoor_Greybox.fbx | VaultDoor_Dial | 4.48 x 4.48 x 0.89 | 768 | Box | SmoothPlastic | off | on |
| VaultDoor_Greybox.fbx | VaultDoor_DialRing | 3.5 x 3.5 x 0.24 | 288 | Box | **Neon** | off | off |

The same numbers are in `assets/fbx/kit_manifest.json`. Claude rebuilds that file with every art change.

---

## Before you start

1. Pull the repo, so `assets/fbx/` has the 6 `.fbx` files.
2. Open Roblox Studio. Make a **new Baseplate place** called `KitWorkshop`. Do not use the live place or the test place.
3. Know who owns the game. The meshes must belong to the **same owner as the experience** (you, or your group). Otherwise they do not load in the game.

## Step 1. Import each FBX file (Import 3D)

Do this once for each of the 6 files.

1. Click **Home > Import 3D** (or **File > Import 3D**) and choose one file in `assets/fbx/`.
2. In the import window, under **File General**, set:
   - **Name**: keep the file name, for example `VaultDoor_Greybox`. Code finds pieces by name.
   - **Upload to Roblox**: **ON**. This is needed: the saved file only keeps a link to the uploaded mesh.
   - **Creator**: the owner of the experience (you or your group).
   - **Import Only As Model**: ON.
   - **Set Pivot to Scene Origin**: ON.
   - **Insert Using Scene Position**: ON.
   - **Anchored**: ON.
3. Under **File Transform**, set:
   - **World Forward**: Front.
   - **World Up**: Top.
   - **Scale Unit**: **Studs**.
   - **Merge Meshes**: **OFF**. Merged meshes lose their names and pivots.
4. Select each child in the list on the left. Check that **Use Imported Pivot** is ON. Check that **Make Double Sided** and **Ignore Vertex Colors** are OFF.
5. Look at **File Geometry**. The size must match the table above. A wall is 8 x 12 x 2, not 800 x 1200 x 200. If it is 100 times too big, stop and tell Claude: the export setting is wrong.
6. Read the warnings panel. "Missing texture" or "non-manifold" must not appear. Then click **Import**.

## Step 2. Put everything in one folder

1. In the Explorer, make a **Folder** in Workspace called **`Kit`**. Use this exact name, with a capital K.
2. Drag the 6 imported Models into `Kit`. The result looks like this:
   `Kit > Bank_Wall_4x12, Bank_Wall_8x12, Diamond, GoldBar, GoldStack, VaultDoor_Greybox (Frame, Door, Dial, DialRing)`.
3. If a Model is called `Scene`, rename it to its file name.
4. **Never resize or rotate a piece in Studio.** A wrong size is fixed in Blender, not in Studio.

## Step 3. Run the prepare script (command bar)

1. Click **View > Command Bar**.
2. In the Explorer, select the `Kit` folder.
3. Paste the script below into the command bar and press Enter.

The script sets the same look on every piece: SmoothPlastic, Color white, one shared atlas texture, Anchored. It removes any SurfaceAppearance that the importer made. It sets CanCollide and CastShadow. It also sets the glow ring to Neon with no texture. Then it prints a check line for each piece.

```lua
-- Echo Heist kit prepare + check. Select the Kit folder, then run in the command bar.
local Selection = game:GetService("Selection")
local kit = Selection:Get()[1]
assert(kit and kit.Name == "Kit", "Select the Kit folder first")

local WANT = {
	Bank_Wall_4x12 = { size = Vector3.new(4, 12, 2), collision = "Box", material = "SmoothPlastic", canCollide = true, castShadow = true, atlas = true },
	Bank_Wall_8x12 = { size = Vector3.new(8, 12, 2), collision = "Box", material = "SmoothPlastic", canCollide = true, castShadow = true, atlas = true },
	Diamond = { size = Vector3.new(2, 1.75, 2), collision = "Box", material = "SmoothPlastic", canCollide = false, castShadow = false, atlas = true },
	GoldBar = { size = Vector3.new(2, 0.6, 1), collision = "Box", material = "SmoothPlastic", canCollide = true, castShadow = false, atlas = true },
	GoldStack = { size = Vector3.new(2.04, 1.8, 3.1), collision = "Box", material = "SmoothPlastic", canCollide = true, castShadow = true, atlas = true },
	VaultDoor_Dial = { size = Vector3.new(4.482, 4.482, 0.885), collision = "Box", material = "SmoothPlastic", canCollide = false, castShadow = true, atlas = true },
	VaultDoor_DialRing = { size = Vector3.new(3.5, 3.5, 0.24), collision = "Box", material = "Neon", canCollide = false, castShadow = false, atlas = false },
	VaultDoor_Door = { size = Vector3.new(11.6, 8.6, 2.75), collision = "Hull", material = "SmoothPlastic", canCollide = true, castShadow = true, atlas = true },
	VaultDoor_Frame = { size = Vector3.new(16, 12, 3.5), collision = "PreciseConvexDecomposition", material = "SmoothPlastic", canCollide = true, castShadow = true, atlas = true },
}

-- 1. Find the atlas texture id the importer uploaded (first one found).
local atlas = ""
for _, d in kit:GetDescendants() do
	if d:IsA("MeshPart") and d.TextureID ~= "" then
		atlas = d.TextureID
		break
	elseif d:IsA("SurfaceAppearance") and d.ColorMap ~= "" then
		atlas = d.ColorMap
		break
	end
end
print("Kit atlas texture:", atlas ~= "" and atlas or "NOT FOUND (upload assets/textures/EH_Palette_Bank.png, paste its id here)")

-- 2. Same look on every piece, then check it.
local problems = 0
for name, w in WANT do
	local p = kit:FindFirstChild(name, true)
	if not (p and p:IsA("MeshPart")) then
		problems += 1
		warn("MISSING", name)
		continue
	end
	for _, sa in p:GetChildren() do
		if sa:IsA("SurfaceAppearance") then
			sa:Destroy()
		end
	end
	p.Material = Enum.Material[w.material]
	p.Color = if w.atlas then Color3.new(1, 1, 1) else Color3.fromRGB(216, 200, 168) -- Warm Marble idle glow
	p.TextureID = if w.atlas then atlas else ""
	p.Anchored = true
	p.CanCollide = w.canCollide
	p.CanTouch = w.canCollide
	p.CastShadow = w.castShadow
	local sizeOk = (p.Size - w.size).Magnitude < 0.05
	local nativeOk = (p.Size - p.MeshSize).Magnitude < 0.05
	local collOk = p.CollisionFidelity.Name == w.collision
	if not (sizeOk and nativeOk and collOk) then
		problems += 1
	end
	print(string.format("%-20s size %s %s | native %s | collision %s %s",
		name, tostring(p.Size), sizeOk and "ok" or ("WANT " .. tostring(w.size)),
		nativeOk and "ok" or "SCALED IN STUDIO", p.CollisionFidelity.Name, collOk and "ok" or ("SET TO " .. w.collision)))
end

-- 3. Front check: the dial must sit on the front (-Z, the LookVector side) of the vault frame.
local frame, dial = kit:FindFirstChild("VaultDoor_Frame", true), kit:FindFirstChild("VaultDoor_Dial", true)
if frame and dial then
	print("Vault front faces -Z:", dial.Position.Z < frame.Position.Z and "yes" or "NO, tell Claude (FBX axis)")
end
print(problems == 0 and "KIT OK" or (problems .. " problem(s): fix them, then run again"))
```

## Step 4. Set collision by hand (scripts cannot do this)

Roblox builds the collision shape when the part is made. A script cannot change `CollisionFidelity` later, so set it in the Properties window:

1. Hold Ctrl and click every piece whose table row says **Box**. In **Properties > Collision**, set **CollisionFidelity = Box**.
2. Select `VaultDoor_Door` and set **Hull**.
3. Select `VaultDoor_Frame` and set **PreciseConvexDecomposition**. The frame has a round opening, and Box would block the doorway.
4. Run the script from Step 3 again. It must print **KIT OK**.

To see the collision shapes, go to **File > Studio Settings > Physics** and turn on **Show Decomposition Geometry**. Walk an avatar through the vault opening: you must not get stuck.

## Step 5. Save the file

1. Right-click the `Kit` folder and choose **Save to File...**.
2. Choose the repo folder `assets/` and the name **`Kit.rbxm`**. It must be binary `.rbxm`, not `.rbxmx`.
3. The file should be small, well under 1 MB. The meshes stay on Roblox; the file only has links to them.
4. Tell Claude: "Kit.rbxm is saved." You can commit it, or let Claude do it.

## Step 6. What Claude does next (you do not need to do this)

1. Claude copies the node from `kit.project.snippet.json` into `default.project.json`:
   ```json
   "ServerStorage": { "Kit": { "$path": "assets/Kit.rbxm" } }
   ```
   It is not added before the file exists, because Rojo stops with an error when a `$path` is missing.
2. Claude runs `rojo build -o build/EchoHeist.rbxlx` and then `lune run tests/kit_check.luau build/EchoHeist.rbxlx`. The check compares the built place with `kit_manifest.json`: names, sizes, Material, CanCollide, CastShadow, a mesh link on every part, and one shared atlas. It also proves that the mesh links survive the Content-property serialization change.
   - Lune 0.11 cannot read `CollisionFidelity` from a file, so the check only warns about it. Your Step 4 check in Studio is the proof.
3. Claude runs the Open Cloud smoke test (`tools/cloud_test.py`). In the real engine, the server clones a kit piece and checks its size and collision.

## When the art changes later

1. Claude rebuilds the art (`python3 tools/blender/build_asset.py --all`) and tells you which FBX files changed.
2. Import only those files (Step 1), using the same settings.
3. Replace the old Model in `Kit`, keeping the same names.
4. Run Steps 3 to 5 again.

Every upload makes new mesh ids. That is fine: the ids are inside `Kit.rbxm`.

## Fallback if S2 fails: build the meshes on the server

Use this if the meshes, sizes or collision do not survive `rojo build`. Then we do not use `Kit.rbxm`:

1. Upload each mesh once. Either import it in Studio with Upload ON and copy each `MeshId`, or let Claude upload through Open Cloud. Open Cloud needs the **`asset:write`** scope on your API key (decision D5). The mesh ids must be owned by the **experience owner**.
2. Claude puts the ids in a data table (`src/shared/Config.luau`, `Config.Kit`).
3. At server boot, the server builds each piece **once** and caches it in `ServerStorage/Kit`:
   ```lua
   local part = AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
   	CollisionFidelity = Enum.CollisionFidelity.Box, -- per the table above
   	RenderFidelity = Enum.RenderFidelity.Automatic,
   })
   ```
   Then it sets Size, TextureID, Material and the other flags from the table. Each heist clones the cached parts.
4. This costs about 22 ms plus 0.27 ms per 1,000 triangles per mesh [UNVERIFIED, from a DevForum report]. That is about 0.1 s for this kit, so it runs at boot only, never per heist.
