local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local EquipmentVisualService = require(ServerScriptService.Services.EquipmentVisualService)
local RateLimiter = require(ServerScriptService.Services.RateLimiter)

-- dig-minigame-spec.md Step 9 (System 5): buying and equipping shovels and
-- detectors with coins. The spec's own remote table only lists
-- RequestEquipTool (for switching to an already-owned tier) -- it never
-- names a remote for the purchase transaction itself, so RequestBuyEquipment
-- is an addition to fill that gap, following the same shape as the existing
-- RequestBuyUpgrade/UpgradeRefused pattern.
--
-- Simplified from the full spec: no physical shop racks/pegs (System 5.1) --
-- a single toggle panel, matching every other shop UI already in this game.
-- Robux purchases aren't wired -- GDD-authorized real money paths need real
-- DevProduct/GamePass ids created on the Creator Dashboard, which is
-- deliberately being deferred until everything free-to-build is done first.
local EquipmentShopService = {}

local TIER_CONFIG = {
	shovel = {
		tiers = Config.SHOVEL_TIERS,
		ownedField = "ownedShovels",
		equippedField = "equippedShovelTier",
	},
	detector = {
		tiers = Config.DETECTOR_TIERS,
		ownedField = "ownedDetectors",
		equippedField = "equippedDetectorTier",
	},
}

local function sendOwnedEquipment(player, profile)
	ReplicatedStorage.Remotes.OwnedEquipmentUpdated:FireClient(player, {
		ownedShovels = profile.Data.ownedShovels,
		ownedDetectors = profile.Data.ownedDetectors,
		equippedShovelTier = profile.Data.equippedShovelTier,
		equippedDetectorTier = profile.Data.equippedDetectorTier,
	})
end

-- Shared by both a fresh purchase and a plain re-equip -- keeps
-- walkSpeedBonus in sync with whichever shovel just became equipped (§5.3).
local function setEquipped(profile, toolType, tier)
	local config = TIER_CONFIG[toolType]
	profile.Data[config.equippedField] = tier
	if toolType == "shovel" then
		profile.Data.walkSpeedBonus = config.tiers[tier].speed
	end
end

local function onRequestBuyEquipment(player, toolType, tier)
	if not RateLimiter.Allow(player, "RequestBuyEquipment") then
		return
	end

	local config = TIER_CONFIG[toolType]
	if not config then
		return
	end

	local tierInfo = config.tiers[tier]
	if not tierInfo then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local owned = profile.Data[config.ownedField]
	if owned[tier] then
		return -- already owned -- buying again makes no sense, use RequestEquipTool instead
	end

	local paid = EconomyService.RemoveCoins(player, tierInfo.cost, "Bought " .. tierInfo.name)
	if not paid then
		ReplicatedStorage.Remotes.EquipmentPurchaseRefused:FireClient(player, "Not enough coins")
		return
	end

	owned[tier] = true
	setEquipped(profile, toolType, tier)

	EquipmentVisualService.RefreshForPlayer(player)
	sendOwnedEquipment(player, profile)
	ReplicatedStorage.Remotes.EquipConfirmed:FireClient(player, toolType, tier)
end

local function onRequestEquipTool(player, toolType, tier)
	if not RateLimiter.Allow(player, "RequestEquipTool") then
		return
	end

	local config = TIER_CONFIG[toolType]
	if not config then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	if not profile.Data[config.ownedField][tier] then
		return -- doesn't own this tier -- must buy it first
	end

	setEquipped(profile, toolType, tier)

	EquipmentVisualService.RefreshForPlayer(player)
	sendOwnedEquipment(player, profile)
	ReplicatedStorage.Remotes.EquipConfirmed:FireClient(player, toolType, tier)
end

function EquipmentShopService.Init()
	local remotes = ReplicatedStorage.Remotes
	remotes.RequestBuyEquipment.OnServerEvent:Connect(onRequestBuyEquipment)
	remotes.RequestEquipTool.OnServerEvent:Connect(onRequestEquipTool)

	PlayerDataService.ProfileLoaded.Event:Connect(function(player)
		local profile = PlayerDataService.GetProfile(player)
		if profile then
			sendOwnedEquipment(player, profile)
		end
	end)
end

return EquipmentShopService
