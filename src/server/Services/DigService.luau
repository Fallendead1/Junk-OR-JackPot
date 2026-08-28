local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)

local ServerScriptService = game:GetService("ServerScriptService")
local EconomyService = require(ServerScriptService.Services.EconomyService)

local LUMP_SIZE = Vector3.new(1.5, 1.5, 1.5)
local LUMP_COLOR = Color3.fromRGB(120, 120, 120)

-- TEMPORARY flat rate. Replaced by the real BucketEV-based blind price in Phase 5.
local TEMP_BLIND_SELL_AMOUNT = 40

local DigService = {}

-- Session-only state. Phase 4's LumpService takes over tracking the active
-- lump (grade, hints, lumpId) once grading exists; for now the lump itself
-- (a plain grey Part) IS the state.
local activeLumpByPlayer = {}
local lastDigTimeByPlayer = {}

local function getHandAttachPart(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function clearLump(player)
	local lump = activeLumpByPlayer[player]
	if lump then
		lump:Destroy()
	end
	activeLumpByPlayer[player] = nil
end

local function onRequestDig(player)
	if activeLumpByPlayer[player] then
		return -- already holding a lump
	end

	local zone = ZoneTable[1] -- only Zone 1 exists until Phase 7
	local lastDigTime = lastDigTimeByPlayer[player] or 0
	if os.clock() - lastDigTime < zone.digTime + Config.DIG_COOLDOWN_GRACE then
		return -- server-side cooldown not met; the client can't be trusted to have actually held the prompt
	end

	local character = player.Character
	local handPart = character and getHandAttachPart(character)
	if not handPart then
		return -- character not ready
	end

	local lump = Instance.new("Part")
	lump.Name = "Lump"
	lump.Size = LUMP_SIZE
	lump.Color = LUMP_COLOR
	lump.Material = Enum.Material.Slate
	lump.CanCollide = false
	lump.CFrame = handPart.CFrame * CFrame.new(0, -1, 0)
	lump.Parent = Workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = lump
	weld.Part1 = handPart
	weld.Parent = lump

	activeLumpByPlayer[player] = lump
	lastDigTimeByPlayer[player] = os.clock()

	ReplicatedStorage.Remotes.LumpSpawned:FireClient(player)
end

local function onRequestSellBlind(player)
	if not activeLumpByPlayer[player] then
		return
	end

	clearLump(player)
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
			clearLump(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearLump(player)
		lastDigTimeByPlayer[player] = nil
	end)
end

return DigService
