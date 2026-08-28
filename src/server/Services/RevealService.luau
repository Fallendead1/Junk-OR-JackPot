local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GradeTable = require(ReplicatedStorage.Modules.GradeTable)
local ItemTable = require(ReplicatedStorage.Modules.ItemTable)

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

-- No setup needed — DigService calls into this module directly.
function RevealService.Init() end

return RevealService
