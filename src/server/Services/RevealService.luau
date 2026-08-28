local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GradeTable = require(ReplicatedStorage.Modules.GradeTable)
local ItemTable = require(ReplicatedStorage.Modules.ItemTable)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- Fixed iteration order for the cumulative tier roll (GradeTable's per-grade
-- tables are plain tables — pairs() order isn't guaranteed).
local TIER_ORDER = { "Scrap", "Common", "Good", "Rare", "Epic", "Mythic", "Relic" }

local RevealService = {}

-- GDD §4.8 step 6: roll 1-10000 against the grade's cumulative tier weights.
function RevealService.RollTier(grade)
	local weights = GradeTable[grade]
	local roll = math.random(1, 10000)

	local cumulative = 0
	for _, tier in ipairs(TIER_ORDER) do
		cumulative += weights[tier]
		if roll <= cumulative then
			return tier
		end
	end

	return TIER_ORDER[#TIER_ORDER] -- safety net; weights always sum to exactly 10000
end

-- Picks uniformly among ItemTable entries matching this tier and zone.
-- Returns nil if no such item exists (shouldn't happen once all zones are
-- built out — every tier has at least one item per zone per the GDD).
function RevealService.PickItem(tier, zoneNumber)
	local candidateIds = {}
	for itemId, item in pairs(ItemTable) do
		if item.tier == tier and item.zone == zoneNumber then
			table.insert(candidateIds, itemId)
		end
	end

	if #candidateIds == 0 then
		return nil
	end

	local chosenId = candidateIds[math.random(1, #candidateIds)]
	return chosenId, ItemTable[chosenId]
end

local function sendCatalogue(player, profile)
	ReplicatedStorage.Remotes.CatalogueUpdated:FireClient(player, profile.Data.catalogue, profile.Data.catalogueCount)
end

-- Writes the catalogue entry for a reveal. Data shape exactly per GDD §8.1:
-- unfound items are simply absent from the table. Returns true if this is
-- the player's first-ever find of this item.
function RevealService.RecordCatalogue(player, profile, itemId, item)
	local catalogue = profile.Data.catalogue
	local entry = catalogue[itemId]
	local isNew = entry == nil or entry.found ~= true

	if isNew then
		catalogue[itemId] = {
			found = true,
			count = 1,
			bestValue = item.value,
			firstFound = os.time(),
		}
		profile.Data.catalogueCount += 1
	else
		entry.count += 1
		if item.value > entry.bestValue then
			entry.bestValue = item.value
		end
	end

	sendCatalogue(player, profile)

	return isNew
end

function RevealService.Init()
	PlayerDataService.ProfileLoaded.Event:Connect(function(player)
		local profile = PlayerDataService.GetProfile(player)
		if profile then
			sendCatalogue(player, profile)
		end
	end)
end

return RevealService
