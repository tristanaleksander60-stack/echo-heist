--!strict
-- Data/ProductPrices: Robux prices for the store UI, from GetProductInfoAsync only
-- (MASTERPLAN §5.4; roblox-monetization-compliance: regional pricing means a
-- hard-coded label shows the wrong amount). Client-side helper; the server never needs
-- a Robux price. A product with id 0 (not created on the dashboard yet) has no price
-- and must not be shown as buyable. Errors are retried and never cached.
--
--   local prices = ProductPrices.new()          -- uses MarketplaceService
--   local robux = prices:getAsync("StyleNoir")  -- number, or nil (placeholder / failed)

local Config = require("../Config")

export type FetchInfo = (productId: number) -> { [string]: any }

export type Prices = {
	getAsync: (self: Prices, productKey: string) -> number?,
	_fetch: FetchInfo,
	_cache: { [number]: number },
}

local ProductPrices = {}
ProductPrices.__index = ProductPrices

local ATTEMPTS = 3

local function marketplaceFetch(productId: number): { [string]: any }
	local MarketplaceService = game:GetService("MarketplaceService")
	return MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)
end

-- fetch is injectable for tests; it must return the GetProductInfoAsync table or error.
function ProductPrices.new(fetch: FetchInfo?): Prices
	local self = { _fetch = fetch or marketplaceFetch, _cache = {} }
	return (setmetatable(self, ProductPrices) :: any) :: Prices
end

function ProductPrices.getAsync(self: Prices, productKey: string): number?
	local product = Config.Data.Products[productKey]
	if not product or product.id <= 0 then
		return nil
	end
	local cached = self._cache[product.id]
	if cached then
		return cached
	end
	for _ = 1, ATTEMPTS do
		local ok, info = pcall(self._fetch, product.id)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			self._cache[product.id] = info.PriceInRobux
			return info.PriceInRobux
		end
	end
	return nil
end

return ProductPrices
