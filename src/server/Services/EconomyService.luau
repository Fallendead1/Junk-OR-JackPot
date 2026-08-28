local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- The only code in the game that changes coins, scrap, or relic shards.
local EconomyService = {}

local function updateLeaderstats(player, coins)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue then
		coinsValue.Value = coins
	end
end

local function createLeaderstats(player)
	local profile = PlayerDataService.GetProfile(player)
	if profile == nil then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Data.coins
	coins.Parent = leaderstats
end

function EconomyService.AddCoins(player, amount, reason)
	local profile = PlayerDataService.GetProfile(player)
	if profile == nil then
		return false
	end

	profile.Data.coins += amount
	updateLeaderstats(player, profile.Data.coins)
	ReplicatedStorage.Remotes.CoinsChanged:FireClient(player, profile.Data.coins)
	print("[EconomyService] " .. player.Name .. " +" .. amount .. " (" .. reason .. "), balance = " .. profile.Data.coins)

	return true
end

function EconomyService.RemoveCoins(player, amount, reason)
	local profile = PlayerDataService.GetProfile(player)
	if profile == nil then
		return false
	end

	if profile.Data.coins < amount then
		print("[EconomyService] " .. player.Name .. " refused -" .. amount .. " (" .. reason .. "), balance = " .. profile.Data.coins)
		return false
	end

	profile.Data.coins -= amount
	updateLeaderstats(player, profile.Data.coins)
	ReplicatedStorage.Remotes.CoinsChanged:FireClient(player, profile.Data.coins)
	print("[EconomyService] " .. player.Name .. " -" .. amount .. " (" .. reason .. "), balance = " .. profile.Data.coins)

	return true
end

function EconomyService.Init()
	PlayerDataService.ProfileLoaded.Event:Connect(createLeaderstats)
end

return EconomyService
