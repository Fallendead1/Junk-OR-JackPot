local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local RevealService = require(ServerScriptService.Services.RevealService)

local BinService = {}

-- Server-scoped, FIFO, 12 slots, never persisted -- cleared on shutdown just
-- by virtue of being a plain in-memory table (GDD §8.3).
-- { binEntryId, grade, zone, hints, hintScore, price, sellerName, sellerId, pushedAt }
local bin = {}
local nextBinEntryId = 0

local function removeExpired()
	local now = os.clock()
	local i = 1
	while i <= #bin do
		if now - bin[i].pushedAt > Config.BIN_EXPIRY_SECONDS then
			table.remove(bin, i)
		else
			i += 1
		end
	end
end

-- The client-safe view: hints, zone, price, seller — nothing else. Never the
-- grade, never a resolved item.
local function broadcastBin()
	local publicView = {}
	for _, entry in ipairs(bin) do
		table.insert(publicView, {
			binEntryId = entry.binEntryId,
			hints = entry.hints,
			zone = entry.zone,
			price = entry.price,
			sellerName = entry.sellerName,
			sellerId = entry.sellerId,
		})
	end
	ReplicatedStorage.Remotes.BinUpdated:FireAllClients(publicView)
end

-- Called by DigService right after a blind sale pays out. The lump is not
-- destroyed by that sale -- it lives on here for another player to buy.
function BinService.PushLump(player, lump, blindPrice)
	removeExpired()

	nextBinEntryId += 1

	table.insert(bin, {
		binEntryId = nextBinEntryId,
		grade = lump.grade,
		zone = lump.zone,
		hints = lump.hints,
		hintScore = lump.hintScore,
		price = blindPrice * Config.BIN_PRICE_MULT,
		sellerName = player.DisplayName,
		sellerId = player.UserId,
		pushedAt = os.clock(),
	})

	if #bin > Config.BIN_SIZE then
		table.remove(bin, 1) -- oldest entry drops silently
	end

	broadcastBin()
end

local function onRequestBuyBin(player, binEntryId)
	removeExpired()

	local entryIndex, entry
	for i, e in ipairs(bin) do
		if e.binEntryId == binEntryId then
			entryIndex, entry = i, e
			break
		end
	end

	if not entry then
		return -- expired or made up
	end

	if entry.sellerId == player.UserId then
		return -- exploit guard: cannot buy your own lump
	end

	local buyerProfile = PlayerDataService.GetProfile(player)
	if not buyerProfile then
		return
	end

	local paid = EconomyService.RemoveCoins(player, entry.price, "Bought bin lump from " .. entry.sellerName)
	if not paid then
		ReplicatedStorage.Remotes.OpenRefused:FireClient(player, "Not enough coins")
		return
	end

	table.remove(bin, entryIndex)
	broadcastBin()

	-- Rolls immediately using the lump's stored grade -- no second open fee.
	local tier = RevealService.RollTier(entry.grade)
	local itemId, item = RevealService.PickItem(tier, entry.zone)
	local isNew = RevealService.RecordCatalogue(player, buyerProfile, itemId, item)

	table.insert(buyerProfile.Data.inventory, {
		itemId = itemId,
		value = item.value,
		rolledAt = os.time(),
	})
	local inventoryIndex = #buyerProfile.Data.inventory
	ReplicatedStorage.Remotes.MyInventoryUpdated:FireClient(player, buyerProfile.Data.inventory)

	ReplicatedStorage.Remotes.RevealResult:FireClient(player, itemId, tier, item.value, isNew, inventoryIndex)

	-- GDD §8.3: announced regardless of rarity, naming both players. This is
	-- deliberately separate from AnnounceService's Epic+ threshold/rate limit
	-- — every bin purchase announces, no exceptions. "BinPurchase" as the tier
	-- tells the client not to apply the Mythic/Relic visual effects to it.
	local message = player.DisplayName .. " bought " .. entry.sellerName .. "'s lump for "
		.. entry.price .. " and pulled… " .. string.upper(tier) .. " — " .. item.name .. " (" .. item.value .. " coins)."
	ReplicatedStorage.Remotes.Announce:FireAllClients(message, "BinPurchase")
end

function BinService.Init()
	ReplicatedStorage.Remotes.RequestBuyBin.OnServerEvent:Connect(onRequestBuyBin)

	-- Periodic sweep so expired entries visibly disappear client-side even
	-- when nothing else happens to trigger a broadcast.
	task.spawn(function()
		while true do
			task.wait(5)
			local before = #bin
			removeExpired()
			if #bin ~= before then
				broadcastBin()
			end
		end
	end)
end

return BinService
