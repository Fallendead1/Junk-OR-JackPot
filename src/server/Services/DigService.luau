local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)

local LumpService = require(ServerScriptService.Services.LumpService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local RevealService = require(ServerScriptService.Services.RevealService)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local UpgradeService = require(ServerScriptService.Services.UpgradeService)
local AnnounceService = require(ServerScriptService.Services.AnnounceService)
local BinService = require(ServerScriptService.Services.BinService)
local DailyService = require(ServerScriptService.Services.DailyService)
local LeaderboardService = require(ServerScriptService.Services.LeaderboardService)

local DigService = {}

local lastDigTimeByPlayer = {}

-- Each zone's dig region is anchored on its DigSpot part. "Region gating"
-- here means: the server checks the player's actual position against this
-- radius rather than trusting anything the client claims about where it is.
local ZONE_DIG_SPOT_NAMES = { [1] = "DigSpot", [2] = "DigSpot2", [3] = "DigSpot3", [4] = "DigSpot4", [5] = "DigSpot5" }
local ZONE_REGION_RADIUS = 15

local function getPlayerZone(player, profile)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	-- Checked deepest-zone-first so overlapping regions favor the deeper zone.
	for zoneNumber = 5, 1, -1 do
		if profile.Data.zonesUnlocked[zoneNumber] then
			local digSpot = Workspace:FindFirstChild(ZONE_DIG_SPOT_NAMES[zoneNumber])
			if digSpot and (rootPart.Position - digSpot.Position).Magnitude <= ZONE_REGION_RADIUS then
				return zoneNumber
			end
		end
	end

	return nil
end

-- GDD §5.4/§10.1: open cost is fixed per zone (already baked into ZoneTable
-- from Phase 0 as round(OPEN_COST_RATIO * BlendedEV[zone])), scaled by the
-- player's coin multiplier. Wired now, even though coinMultiplier is always 1
-- until Phase 13 -- retrofitting this later is how the GDD §10.1 balance leak
-- ships by accident. Free opens override this to 0.
local function getEffectiveOpenCost(profile, zone)
	if profile.Data.freeOpensLeft > 0 then
		return 0
	end
	return zone.openCost * profile.Data.coinMultiplier
end

local function sendMyInventory(player, profile)
	ReplicatedStorage.Remotes.MyInventoryUpdated:FireClient(player, profile.Data.inventory)
end

local function onRequestDig(player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local maxLumps = UpgradeService.GetLumpsPerDig(profile)
	if LumpService.GetActiveLumpCount(player) >= maxLumps then
		return -- already holding as many lumps as this shovel allows
	end

	local zoneNumber = getPlayerZone(player, profile)
	if not zoneNumber then
		return -- not standing in a zone the player has unlocked
	end

	local zone = ZoneTable[zoneNumber]
	local digTime = zone.digTime * UpgradeService.GetDigTimeMultiplier(profile)

	local lastDigTime = lastDigTimeByPlayer[player] or 0
	if os.clock() - lastDigTime < digTime + Config.DIG_COOLDOWN_GRACE then
		return -- server-side cooldown not met; the client can't be trusted to have actually held the prompt
	end

	lastDigTimeByPlayer[player] = os.clock()

	local effectiveOpenCost = getEffectiveOpenCost(profile, zone)

	-- Excavator (GDD §7.1) digs 2 lumps per action, each independently rolled.
	for i = 1, maxLumps do
		local lump = LumpService.CreateLump(player, zoneNumber, i - 1)
		if lump then
			local blindOffer = LumpService.GetBlindOffer(lump)
			-- Hints, prices, and an opaque lump id only — the grade never leaves the server.
			ReplicatedStorage.Remotes.LumpSpawned:FireClient(player, lump.lumpId, lump.hints, blindOffer, effectiveOpenCost)
		end
	end
end

local function onRequestSellBlind(player, lumpId)
	local lump = LumpService.GetActiveLump(player, lumpId)
	if not lump then
		return
	end

	local blindOffer = LumpService.GetBlindOffer(lump)
	LumpService.ClearLump(player, lumpId)
	EconomyService.AddCoins(player, blindOffer, "Blind sell (Zone " .. lump.zone .. ", hint score " .. lump.hintScore .. ")")
	ReplicatedStorage.Remotes.BlindSold:FireClient(player, blindOffer)

	-- The lump isn't destroyed by the sale (GDD §8.3) -- it lives on in the
	-- bin for another player to buy at 2x.
	BinService.PushLump(player, lump, blindOffer)
end

local function onRequestOpen(player, lumpId)
	local lump = LumpService.GetActiveLump(player, lumpId)
	if not lump then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local zone = ZoneTable[lump.zone]

	if not lump.isGolden then
		local usingFreeOpen = profile.Data.freeOpensLeft > 0
		local cost = getEffectiveOpenCost(profile, zone)

		if cost > 0 then
			local paid = EconomyService.RemoveCoins(player, cost, "Open (Zone " .. lump.zone .. ")")
			if not paid then
				ReplicatedStorage.Remotes.OpenRefused:FireClient(player, "Not enough coins")
				return
			end
		end

		if usingFreeOpen then
			profile.Data.freeOpensLeft -= 1
		end
	end

	LumpService.ClearLump(player, lumpId)

	local tier = lump.isGolden and DailyService.RollGoldenTier() or RevealService.RollTier(lump.grade)
	local itemId, item = RevealService.PickItem(tier, lump.zone)
	local isNew = RevealService.ProcessReveal(player, profile, tier, itemId, item)

	table.insert(profile.Data.inventory, {
		itemId = itemId,
		value = item.value,
		rolledAt = os.time(),
	})
	local inventoryIndex = #profile.Data.inventory
	sendMyInventory(player, profile)

	LeaderboardService.RecordFind(player, profile, item.name, item.value)
	AnnounceService.Announce(player, tier, item.name, item.value, zone.name)

	-- Extends GDD §12.2's RevealResult(itemId, tier, value, isNew) with the
	-- inventory index — the client needs it to fire RequestSellItem for the
	-- KEEP/SELL prompt shown immediately after this reveal.
	ReplicatedStorage.Remotes.RevealResult:FireClient(player, itemId, tier, item.value, isNew, inventoryIndex)
end

local function onRequestSellItem(player, inventoryIndex)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local entry = profile.Data.inventory[inventoryIndex]
	if not entry then
		return -- invalid index (e.g. already sold, or made up) — silent no-op
	end

	table.remove(profile.Data.inventory, inventoryIndex)
	EconomyService.AddCoins(player, entry.value, "Sold from inventory: " .. entry.itemId)
	sendMyInventory(player, profile)
end

function DigService.Init()
	-- Base (Rusty shovel) hold time per zone. A player with a better shovel
	-- gets their own local override to the true faster time -- see
	-- DigController's handling of UpgradePurchased.
	for zoneNumber, digSpotName in pairs(ZONE_DIG_SPOT_NAMES) do
		local digSpot = Workspace:WaitForChild(digSpotName)
		local prompt = digSpot:WaitForChild("ProximityPrompt")
		prompt.HoldDuration = ZoneTable[zoneNumber].digTime
	end

	local remotes = ReplicatedStorage.Remotes
	remotes.RequestDig.OnServerEvent:Connect(onRequestDig)
	remotes.RequestSellBlind.OnServerEvent:Connect(onRequestSellBlind)
	remotes.RequestOpen.OnServerEvent:Connect(onRequestOpen)
	remotes.RequestSellItem.OnServerEvent:Connect(onRequestSellItem)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			LumpService.ClearAllLumps(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		LumpService.ClearAllLumps(player)
		lastDigTimeByPlayer[player] = nil
	end)

	PlayerDataService.ProfileLoaded.Event:Connect(function(player)
		local profile = PlayerDataService.GetProfile(player)
		if profile then
			sendMyInventory(player, profile)
		end
	end)
end

return DigService
