--!strict
-- Levels/Bank: geometry helpers for Hoardsworth Bank (L6 The Big Score: Bank and
-- the bank-kit daily vaults). Sim data only; the kit layout (assets/Kit.rbxm,
-- spike S2) replaces this with the same boxes. Same conventions as Levels/Shop:
-- floor y = 0, walls 12 tall and 1 thick, roots at y = 3, the street and the van at
-- z > 10 (Shop.VAN / Shop.SPAWNS: both locations park the van at the same kerb),
-- rooms toward -Z. The bank is wider (x = +-20) and sits on a fenced lot with a
-- service alley behind and beside it (the escape route out of the loading dock).

local LevelSpec = require("../Sim/LevelSpec")
local Shop = require("./Shop")

local Bank = {}

Bank.HALF_W = 20 -- bank walls at x = +-20
Bank.LOT_HALF_W = 30 -- lot fence at x = +-30
Bank.ROOT_Y = Shop.ROOT_Y
Bank.VAN = Shop.VAN
Bank.SPAWNS = Shop.SPAWNS

Bank.wallZ = Shop.wallZ
Bank.wallX = Shop.wallX
Bank.wallZGap = Shop.wallZGap
Bank.doorAt = Shop.doorAt
Bank.plate = Shop.plate

-- The bank shell: front at z = 10 with the entrance (x -4..4), side walls at
-- x = +-20, back wall at zBack with a loading-dock gap (x -3..3) when `dock`.
function Bank.shell(zBack: number, dock: boolean?): { any }
	local W = Bank.HALF_W
	local solids = {}
	Shop.wallZGap(solids, 10, -W - 0.5, W + 0.5, -4, 4)
	table.insert(solids, Shop.wallX(-W, zBack, 10))
	table.insert(solids, Shop.wallX(W, zBack, 10))
	if dock then
		Shop.wallZGap(solids, zBack, -W - 0.5, W + 0.5, -3, 3)
	else
		table.insert(solids, Shop.wallZ(zBack, -W - 0.5, W + 0.5))
	end
	return solids
end

-- The lot fence around the bank (sides and back; the street stays open), so the
-- service alley is a closed loop from the loading dock to the street.
function Bank.fence(solids: { any }, zBack: number)
	local F = Bank.LOT_HALF_W
	local zFence = zBack - 14
	table.insert(solids, Shop.wallX(-F, zFence, 10))
	table.insert(solids, Shop.wallX(F, zFence, 10))
	table.insert(solids, Shop.wallZ(zFence, -F - 0.5, F + 0.5))
end

-- A hide volume (EH_Hide) around a point: a desk, a fern, a stack of deposit boxes.
function Bank.hideAt(x: number, z: number, sx: number?, sz: number?): any
	local hx, hz = (sx or 6) / 2, (sz or 6) / 2
	return LevelSpec.span(x - hx, 0, z - hz, x + hx, 7, z + hz)
end

function Bank.bounds(zBack: number): any
	return LevelSpec.span(-34, -5, zBack - 18, 34, 25, 34)
end

return table.freeze(Bank)
