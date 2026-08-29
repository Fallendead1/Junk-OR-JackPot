local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local UIJuice = require(ReplicatedStorage.Modules.UIJuice)

-- GDD §10.1: VIP chat tag. VIP status is a replicated Attribute on the
-- Player instance (set server-side in MonetizationService), so any client
-- can check any other player's VIP status without a dedicated sync remote.
local ok = pcall(function()
	TextChatService.OnIncomingMessage = function(message)
		local sourcePlayer = message.TextSource and Players:GetPlayerByUserId(message.TextSource.UserId)
		if sourcePlayer and sourcePlayer:GetAttribute("VIP") then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = "[VIP] " .. message.PrefixText
			return properties
		end
		return nil
	end
end)
if not ok then
	warn("[MonetizationController] TextChatService.OnIncomingMessage hook failed -- VIP chat tag won't show")
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestPromptPurchase = remotes:WaitForChild("RequestPromptPurchase")
local passPurchased = remotes:WaitForChild("PassPurchased")

-- Display-only. Prices/effects from GDD §10.
local GAME_PASSES = {
	{ name = "scanner", label = "Scanner", price = 99, effect = "Adds a 4th hint" },
	{ name = "bigShelf", label = "Big Shelf", price = 149, effect = "+10 shelf slots" },
	{ name = "luckyCharm", label = "Lucky Charm", price = 249, effect = "+0.10 Luck" },
	{ name = "autoDig", label = "Auto-Dig", price = 149, effect = "Dig repeats automatically" },
	{ name = "doubleCoins", label = "2x Coins", price = 299, effect = "Doubles coin gains (and open cost)" },
	{ name = "vip", label = "VIP", price = 399, effect = "Chat tag, 2nd daily lump" },
}

local DEV_PRODUCTS = {
	{ name = "coinPouch", label = "Coin Pouch", price = 49, effect = "5,000 coins" },
	{ name = "coinSack", label = "Coin Sack", price = 199, effect = "40,000 coins" },
	{ name = "coinCrate", label = "Coin Crate", price = 699, effect = "350,000 coins" },
	{ name = "coinVault", label = "Coin Vault", price = 1999, effect = "3,000,000 coins" },
	{ name = "goldenLumpX3", label = "Golden Lump x3", price = 99, effect = "3 instant Golden Lumps" },
	{ name = "zoneSkip", label = "Zone Skip", price = 249, effect = "Waives the next zone's coin cost" },
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonetizationUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local storeButton = Instance.new("TextButton")
storeButton.Name = "StoreButton"
storeButton.Text = "STORE"
storeButton.Size = UDim2.fromOffset(160, 40)
storeButton.Position = UDim2.new(0, 870, 0, 20)
storeButton.BackgroundColor3 = Color3.fromRGB(150, 60, 150)
storeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
storeButton.TextScaled = true
storeButton.Parent = screenGui

local storeFrame = Instance.new("Frame")
storeFrame.Name = "StoreFrame"
storeFrame.Size = UDim2.fromOffset(420, 460)
storeFrame.Position = UDim2.fromScale(0.3, 0.08)
storeFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
storeFrame.Visible = false
storeFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.new(0, 5, 0, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Text = "STORE"
title.Parent = storeFrame

local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.fromOffset(30, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = storeFrame

UIJuice.MakeButtonJuicy(storeButton)
UIJuice.MakeButtonJuicy(closeButton)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -40)
scroll.Position = UDim2.new(0, 0, 0, 40)
scroll.BackgroundTransparency = 1
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 8
scroll.Parent = storeFrame

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.Parent = scroll

storeButton.Activated:Connect(function()
	storeFrame.Visible = not storeFrame.Visible
	if storeFrame.Visible then
		UIJuice.PopIn(storeFrame)
	end
end)

closeButton.Activated:Connect(function()
	storeFrame.Visible = false
end)

local ownedButtons = {}

local function addRow(kind, entry, sectionColor)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 50)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	row.Parent = scroll

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = sectionColor
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = entry.label .. "\n" .. entry.effect
	label.Parent = row

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(0.35, 0, 0.8, 0)
	buyButton.Position = UDim2.new(0.63, 0, 0.1, 0)
	buyButton.Text = "R$" .. entry.price
	buyButton.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.TextScaled = true
	buyButton.Parent = row

	buyButton.Activated:Connect(function()
		requestPromptPurchase:FireServer(kind, entry.name)
	end)
	UIJuice.MakeButtonJuicy(buyButton)

	if kind == "pass" then
		ownedButtons[entry.name] = buyButton
	end
end

for _, entry in ipairs(GAME_PASSES) do
	addRow("pass", entry, Color3.fromRGB(255, 255, 255))
end
for _, entry in ipairs(DEV_PRODUCTS) do
	addRow("product", entry, Color3.fromRGB(200, 220, 255))
end

passPurchased.OnClientEvent:Connect(function(passName)
	local button = ownedButtons[passName]
	if button then
		button.Text = "OWNED"
		button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		button.Active = false
	end
end)
