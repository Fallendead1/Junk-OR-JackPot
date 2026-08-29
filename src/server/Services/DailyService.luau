local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local LumpService = require(ServerScriptService.Services.LumpService)
local RevealService = require(ServerScriptService.Services.RevealService)

local DailyService = {}

-- GDD §9.2: the Golden Lump is always Charged, rerolled until it clears
-- Rare. Reusing the real Charged tier weights (GDD §4.2) for the reroll
-- reproduces the GDD's own stated conditional odds exactly: Rare 2400,
-- Epic 750, Mythic 130, Relic 20 (out of the 3300 that are Rare+) works out
-- to 72.7% / 22.7% / 3.94% / 0.61% -- matching GDD §9.2 to the decimal
-- without a second table to keep in sync.
local RANK = { Scrap = 1, Common = 2, Good = 3, Rare = 4, Epic = 5, Mythic = 6, Relic = 7 }
local MIN_GOLDEN_RANK = RANK.Rare

function DailyService.RollGoldenTier()
	local tier
	repeat
		tier = RevealService.RollTier("Charged")
	until RANK[tier] >= MIN_GOLDEN_RANK
	return tier
end

-- The Golden Lump isn't dug from a specific mound, so it scales off the
-- player's highest unlocked zone (their current progress) rather than
-- requiring them to stand somewhere specific to claim it.
local function getHighestUnlockedZone(profile)
	local highest = 1
	for zoneNumber, unlocked in pairs(profile.Data.zonesUnlocked) do
		if unlocked and zoneNumber > highest then
			highest = zoneNumber
		end
	end
	return highest
end

local function onRequestClaimDaily(player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local onCooldown = os.time() - profile.Data.lastGoldenLump < Config.GOLDEN_LUMP_COOLDOWN
	if onCooldown and profile.Data.goldenLumpsOwed <= 0 then
		ReplicatedStorage.Remotes.DailyRefused:FireClient(player, "Come back later")
		return
	end

	if LumpService.GetActiveLumpCount(player) > 0 then
		ReplicatedStorage.Remotes.DailyRefused:FireClient(player, "Finish your current lump first")
		return
	end

	if profile.Data.goldenLumpsOwed > 0 then
		profile.Data.goldenLumpsOwed -= 1
	else
		profile.Data.lastGoldenLump = os.time()
	end

	local zoneNumber = getHighestUnlockedZone(profile)
	local lump = LumpService.CreateGoldenLump(player, zoneNumber)
	if not lump then
		return -- character not ready
	end

	local blindOffer = LumpService.GetBlindOffer(lump)
	-- Free to open (GDD §9.2 is a reward, not a purchase); freeOpensLeft is
	-- unaffected since it's a separate, unrelated counter.
	ReplicatedStorage.Remotes.LumpSpawned:FireClient(player, lump.lumpId, lump.hints, blindOffer, 0)
end

function DailyService.Init()
	ReplicatedStorage.Remotes.RequestClaimDaily.OnServerEvent:Connect(onRequestClaimDaily)
end

return DailyService
