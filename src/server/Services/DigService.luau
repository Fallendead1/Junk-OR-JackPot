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

local DigService = {}

local lastDigTimeByPlayer = {}

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

local function onRequestDig(player)
	if LumpService.HasActiveLump(player) then
		return -- already holding a lump
	end

	local zone = ZoneTable[1] -- only Zone 1 exists until Phase 7
	local lastDigTime = lastDigTimeByPlayer[player] or 0
	if os.clock() - lastDigTime < zone.digTime + Config.DIG_COOLDOWN_GRACE then
		return -- server-side cooldown not met; the client can't be trusted to have actually held the prompt
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local lump = LumpService.CreateLump(player, 1)
	if not lump then
		return -- character not ready
	end

	lastDigTimeByPlayer[player] = os.clock()

	local blindOffer = LumpService.GetBlindOffer(lump)
	local effectiveOpenCost = getEffectiveOpenCost(profile, zone)

	-- Hints, prices, and an opaque lump id only — the grade never leaves the server.
	ReplicatedStorage.Remotes.LumpSpawned:FireClient(player, lump.lumpId, lump.hints, blindOffer, effectiveOpenCost)
end

local function onRequestSellBlind(player, lumpId)
	local lump = LumpService.GetActiveLump(player)
	if not lump or lump.lumpId ~= lumpId then
		return
	end

	local blindOffer = LumpService.GetBlindOffer(lump)
	LumpService.ClearLump(player)
	EconomyService.AddCoins(player, blindOffer, "Blind sell (Zone " .. lump.zone .. ", hint score " .. lump.hintScore .. ")")
	ReplicatedStorage.Remotes.BlindSold:FireClient(player, blindOffer)
end

local function onRequestOpen(player, lumpId)
	local lump = LumpService.GetActiveLump(player)
	if not lump or lump.lumpId ~= lumpId then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local zone = ZoneTable[lump.zone]
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

	LumpService.ClearLump(player)

	local tier = RevealService.RollTier(lump.grade)
	local itemId, item = RevealService.PickItem(tier, lump.zone)

	-- Revealed items sell automatically for now — no inventory or keep/sell
	-- choice exists until Phase 6.
	EconomyService.AddCoins(player, item.value, "Reveal auto-sell: " .. item.name)

	ReplicatedStorage.Remotes.RevealResult:FireClient(player, item.name, tier, item.value)
end

function DigService.Init()
	local zone = ZoneTable[1]
	local digSpot = Workspace:WaitForChild("DigSpot")
	local prompt = digSpot:WaitForChild("ProximityPrompt")
	prompt.HoldDuration = zone.digTime

	local remotes = ReplicatedStorage.Remotes
	remotes.RequestDig.OnServerEvent:Connect(onRequestDig)
	remotes.RequestSellBlind.OnServerEvent:Connect(onRequestSellBlind)
	remotes.RequestOpen.OnServerEvent:Connect(onRequestOpen)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			LumpService.ClearLump(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		LumpService.ClearLump(player)
		lastDigTimeByPlayer[player] = nil
	end)
end

return DigService
