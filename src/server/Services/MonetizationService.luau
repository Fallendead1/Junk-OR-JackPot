local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MonetizationTable = require(ReplicatedStorage.Modules.MonetizationTable)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local UpgradeService = require(ServerScriptService.Services.UpgradeService)
local ShelfService = require(ServerScriptService.Services.ShelfService)

local MonetizationService = {}

-- Applies a gamepass's one-time/permanent effects exactly once, no matter how
-- many times it gets (re-)detected across a session or rejoins. GDD §10.1.
local function applyPassEffects(player, profile, passName)
	if profile.Data.passes[passName] then
		return -- already applied -- e.g. re-synced on every join
	end

	profile.Data.passes[passName] = true

	if passName == "bigShelf" then
		profile.Data.shelfSlots += 10
		ShelfService.NotifyShelfSlotsChanged(player, profile)
	elseif passName == "doubleCoins" then
		profile.Data.coinMultiplier = 2
	elseif passName == "luckyCharm" then
		UpgradeService.RecalculateLuck(profile)
	elseif passName == "vip" then
		-- Chat tag: read by each client's TextChatService.OnIncomingMessage
		-- hook. The extra daily Golden Lump is handled in DailyService (it
		-- reuses goldenLumpsOwed rather than needing its own counter).
		player:SetAttribute("VIP", true)
	end
	-- scanner, autoDig: read straight from profile.Data.passes elsewhere
	-- (LumpService, client Auto-Dig) -- no extra state to flip.
	--
	-- NOT built: VIP's private shelf plot and exclusive shovel skin. Both
	-- need real new systems (plot reservation beyond the shared pool; the
	-- game has no shovel tool/visual at all yet to skin) -- out of proportion
	-- for parts of VIP that no Phase 13 exit criterion tests.

	ReplicatedStorage.Remotes.PassPurchased:FireClient(player, passName)
end

-- Covers passes bought outside the current session (Roblox website, or a
-- previous session that ended before PromptGamePassPurchaseFinished fired).
local function syncOwnedPasses(player, profile)
	for passName, gamePassId in pairs(MonetizationTable.GamePasses) do
		if not profile.Data.passes[passName] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)
			if ok and owns then
				applyPassEffects(player, profile, passName)
			end
		end
	end
end

local function onPromptGamePassPurchaseFinished(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	for passName, id in pairs(MonetizationTable.GamePasses) do
		if id == gamePassId then
			applyPassEffects(player, profile, passName)
			break
		end
	end
end

local function findDevProduct(productId)
	for productName, info in pairs(MonetizationTable.DevProducts) do
		if info.id == productId then
			return productName, info
		end
	end
	return nil
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productName, info = findDevProduct(receiptInfo.ProductId)
	if not productName then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if info.coins then
		EconomyService.AddCoins(player, info.coins, "Dev product: " .. productName)
	elseif productName == "goldenLumpX3" then
		profile.Data.goldenLumpsOwed += 3
	elseif productName == "zoneSkip" then
		profile.Data.zoneSkipsOwed += 1
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onRequestPromptPurchase(player, kind, name)
	if kind == "pass" then
		local gamePassId = MonetizationTable.GamePasses[name]
		if gamePassId then
			MarketplaceService:PromptGamePassPurchase(player, gamePassId)
		end
	elseif kind == "product" then
		local info = MonetizationTable.DevProducts[name]
		if info then
			MarketplaceService:PromptProductPurchase(player, info.id)
		end
	end
end

function MonetizationService.Init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPromptGamePassPurchaseFinished)
	MarketplaceService.ProcessReceipt = processReceipt

	ReplicatedStorage.Remotes.RequestPromptPurchase.OnServerEvent:Connect(onRequestPromptPurchase)

	PlayerDataService.ProfileLoaded.Event:Connect(function(player)
		local profile = PlayerDataService.GetProfile(player)
		if not profile then
			return
		end

		task.spawn(syncOwnedPasses, player, profile)

		for passName, owned in pairs(profile.Data.passes) do
			if owned then
				ReplicatedStorage.Remotes.PassPurchased:FireClient(player, passName)
			end
		end
	end)
end

return MonetizationService
