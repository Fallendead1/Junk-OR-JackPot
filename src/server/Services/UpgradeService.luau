local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)
local ShovelTable = require(ReplicatedStorage.Modules.ShovelTable)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)

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

local function onBuyShovel(player, profile, tier)
	if tier ~= profile.Data.shovelTier + 1 then
		return -- must buy the next tier, one at a time -- also blocks tier 4 from tier 1
	end

	local tierInfo = ShovelTable[tier]
	if not tierInfo then
		return -- doesn't exist yet (Powered/Excavator are Phase 11)
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
	if zoneNumber ~= 2 then
		return -- only Zone 2 exists to unlock until Phase 11
	end

	if profile.Data.zonesUnlocked[zoneNumber] then
		return -- already unlocked
	end

	local zone = ZoneTable[zoneNumber]
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

local function onRequestBuyUpgrade(player, upgradeType, tier)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	if upgradeType == "shovel" then
		onBuyShovel(player, profile, tier)
	elseif upgradeType == "zone" then
		onBuyZone(player, profile, tier)
	end
end

function UpgradeService.Init()
	ReplicatedStorage.Remotes.RequestBuyUpgrade.OnServerEvent:Connect(onRequestBuyUpgrade)

	-- Initial sync so the client can set up its own dig-prompt timings on join.
	PlayerDataService.ProfileLoaded.Event:Connect(function(player)
		local profile = PlayerDataService.GetProfile(player)
		if profile then
			ReplicatedStorage.Remotes.UpgradePurchased:FireClient(player, "shovel", profile.Data.shovelTier)
		end
	end)
end

return UpgradeService
