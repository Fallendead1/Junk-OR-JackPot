local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)
local ShovelTable = require(ReplicatedStorage.Modules.ShovelTable)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local ShelfService = require(ServerScriptService.Services.ShelfService)

local SHELF_BASE_SLOTS = 12

local UpgradeService = {}

function UpgradeService.GetDigTimeMultiplier(profile)
	return ShovelTable[profile.Data.shovelTier].digTimeMultiplier
end

-- GDD §7.2: luck is recalculated from every source on every upgrade, then
-- hard-clamped. Only the shovel is a source until Phase 12/13 add the rest.
local function recalculateLuck(profile)
	local luck = ShovelTable[profile.Data.shovelTier].luckBonus
	profile.Data.luckBonus = math.min(luck, Config.LUCK_CAP)
end

function UpgradeService.GetLumpsPerDig(profile)
	return ShovelTable[profile.Data.shovelTier].lumpsPerDig
end

local function onBuyShovel(player, profile, tier)
	if tier ~= profile.Data.shovelTier + 1 then
		return -- must buy the next tier, one at a time -- also blocks skipping tiers
	end

	local tierInfo = ShovelTable[tier]
	if not tierInfo then
		return -- no such tier
	end

	local paid = EconomyService.RemoveCoins(player, tierInfo.cost, "Bought " .. tierInfo.name .. " Shovel")
	if not paid then
		ReplicatedStorage.Remotes.UpgradeRefused:FireClient(player, "Not enough coins")
		return
	end

	profile.Data.shovelTier = tier
	recalculateLuck(profile)

	ReplicatedStorage.Remotes.UpgradePurchased:FireClient(player, "shovel", tier)
end

local function onBuyZone(player, profile, zoneNumber)
	local zone = ZoneTable[zoneNumber]
	if not zone then
		return -- no such zone
	end

	if profile.Data.zonesUnlocked[zoneNumber] then
		return -- already unlocked
	end

	local requirement = zone.requirement or {}

	if requirement.catalogueEntries and profile.Data.catalogueCount < requirement.catalogueEntries then
		ReplicatedStorage.Remotes.UpgradeRefused:FireClient(player, "Need " .. requirement.catalogueEntries .. " catalogue entries")
		return
	end

	if requirement.shovelTier and profile.Data.shovelTier < requirement.shovelTier then
		ReplicatedStorage.Remotes.UpgradeRefused:FireClient(player, "Need a better shovel first")
		return
	end

	local paid = EconomyService.RemoveCoins(player, zone.unlockCost, "Unlocked " .. zone.name)
	if not paid then
		ReplicatedStorage.Remotes.UpgradeRefused:FireClient(player, "Not enough coins")
		return
	end

	profile.Data.zonesUnlocked[zoneNumber] = true
	ReplicatedStorage.Remotes.UpgradePurchased:FireClient(player, "zone", zoneNumber)
end

-- GDD §7.3: slotCost = round(SHELF_BASE_COST * SHELF_COST_MULT ^ n), where n
-- counts slots bought beyond the free base 12 (slot 13 is n=1, 14 is n=2...).
-- Verified against the GDD's own worked examples: n=1 -> 1700, n=6 -> 24138,
-- n=10 -> 201599, all matching exactly.
local function onBuyShelfSlot(player, profile, slotNumber)
	if slotNumber ~= profile.Data.shelfSlots + 1 then
		return -- must buy the next slot, one at a time
	end

	local n = slotNumber - SHELF_BASE_SLOTS
	if n < 1 then
		return -- slots 1-12 are already free
	end

	local cost = math.round(Config.SHELF_BASE_COST * Config.SHELF_COST_MULT ^ n)
	local paid = EconomyService.RemoveCoins(player, cost, "Bought shelf slot " .. slotNumber)
	if not paid then
		ReplicatedStorage.Remotes.UpgradeRefused:FireClient(player, "Not enough coins")
		return
	end

	profile.Data.shelfSlots = slotNumber
	ShelfService.NotifyShelfSlotsChanged(player, profile)
	ReplicatedStorage.Remotes.UpgradePurchased:FireClient(player, "shelfSlot", slotNumber)
end

local function onRequestBuyUpgrade(player, upgradeType, tier)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	if upgradeType == "shovel" then
		onBuyShovel(player, profile, tier)
	elseif upgradeType == "zone" then
		onBuyZone(player, profile, tier)
	elseif upgradeType == "shelfSlot" then
		onBuyShelfSlot(player, profile, tier)
	end
end

function UpgradeService.Init()
	ReplicatedStorage.Remotes.RequestBuyUpgrade.OnServerEvent:Connect(onRequestBuyUpgrade)

	-- Initial sync so the client can set up its own dig-prompt timings and shop
	-- display on join.
	PlayerDataService.ProfileLoaded.Event:Connect(function(player)
		local profile = PlayerDataService.GetProfile(player)
		if not profile then
			return
		end

		ReplicatedStorage.Remotes.UpgradePurchased:FireClient(player, "shovel", profile.Data.shovelTier)

		for zoneNumber, unlocked in pairs(profile.Data.zonesUnlocked) do
			if unlocked and zoneNumber > 1 then
				ReplicatedStorage.Remotes.UpgradePurchased:FireClient(player, "zone", zoneNumber)
			end
		end
	end)
end

return UpgradeService
