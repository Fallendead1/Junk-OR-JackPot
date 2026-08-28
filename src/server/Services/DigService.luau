local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)

local LumpService = require(ServerScriptService.Services.LumpService)
local EconomyService = require(ServerScriptService.Services.EconomyService)

-- TEMPORARY flat rate. Replaced by the real BucketEV-based blind price in Phase 5.
local TEMP_BLIND_SELL_AMOUNT = 40

local DigService = {}

local lastDigTimeByPlayer = {}

local function onRequestDig(player)
	if LumpService.HasActiveLump(player) then
		return -- already holding a lump
	end

	local zone = ZoneTable[1] -- only Zone 1 exists until Phase 7
	local lastDigTime = lastDigTimeByPlayer[player] or 0
	if os.clock() - lastDigTime < zone.digTime + Config.DIG_COOLDOWN_GRACE then
		return -- server-side cooldown not met; the client can't be trusted to have actually held the prompt
	end

	local lump = LumpService.CreateLump(player, 1)
	if not lump then
		return -- character not ready
	end

	lastDigTimeByPlayer[player] = os.clock()

	-- Hints and the lump's name only — the grade never leaves the server.
	ReplicatedStorage.Remotes.LumpSpawned:FireClient(player, lump.lumpId, lump.hints)
end

local function onRequestSellBlind(player)
	if not LumpService.HasActiveLump(player) then
		return
	end

	LumpService.ClearLump(player)
	EconomyService.AddCoins(player, TEMP_BLIND_SELL_AMOUNT, "Blind sell (Zone 1, temp flat rate)")
	ReplicatedStorage.Remotes.BlindSold:FireClient(player, TEMP_BLIND_SELL_AMOUNT)
end

function DigService.Init()
	local zone = ZoneTable[1]
	local digSpot = Workspace:WaitForChild("DigSpot")
	local prompt = digSpot:WaitForChild("ProximityPrompt")
	prompt.HoldDuration = zone.digTime

	local remotes = ReplicatedStorage.Remotes
	remotes.RequestDig.OnServerEvent:Connect(onRequestDig)
	remotes.RequestSellBlind.OnServerEvent:Connect(onRequestSellBlind)

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
