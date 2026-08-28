local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemTable = require(ReplicatedStorage.Modules.ItemTable)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDig = remotes:WaitForChild("RequestDig")
local requestSellBlind = remotes:WaitForChild("RequestSellBlind")
local requestOpen = remotes:WaitForChild("RequestOpen")
local requestSellItem = remotes:WaitForChild("RequestSellItem")
local lumpSpawned = remotes:WaitForChild("LumpSpawned")
local blindSold = remotes:WaitForChild("BlindSold")
local revealResult = remotes:WaitForChild("RevealResult")
local openRefused = remotes:WaitForChild("OpenRefused")
local catalogueUpdated = remotes:WaitForChild("CatalogueUpdated")

local digSpot = Workspace:WaitForChild("DigSpot")
local prompt = digSpot:WaitForChild("ProximityPrompt")

-- Display-only. Source: GDD §4.3.
local TIER_COLORS = {
	Scrap = Color3.fromHex("#6B6B6B"),
	Common = Color3.fromHex("#FFFFFF"),
	Good = Color3.fromHex("#4EC94E"),
	Rare = Color3.fromHex("#3B82F6"),
	Epic = Color3.fromHex("#A855F7"),
	Mythic = Color3.fromHex("#F59E0B"),
	Relic = Color3.fromHex("#EF4444"),
}

-- Stable display order for the 60 catalogue slots (ItemTable's pairs() order
-- isn't guaranteed).
local allItemIds = {}
for itemId in pairs(ItemTable) do
	table.insert(allItemIds, itemId)
end
table.sort(allItemIds)

-- TEMPORARY: this whole screen is replaced by the real HUD once the shelf and
-- shop exist starting Phase 7+.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TempDigUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local currentLumpId = nil

local sellButton = Instance.new("TextButton")
sellButton.Name = "SellBlindButton"
sellButton.Text = "SELL BLIND"
sellButton.Size = UDim2.fromOffset(200, 60)
sellButton.Position = UDim2.new(0.5, -220, 0.8, 0)
sellButton.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sellButton.TextScaled = true
sellButton.Visible = false
sellButton.Parent = screenGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenButton"
openButton.Text = "OPEN"
openButton.Size = UDim2.fromOffset(200, 60)
openButton.Position = UDim2.new(0.5, 20, 0.8, 0)
openButton.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.TextScaled = true
openButton.Visible = false
openButton.Parent = screenGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.fromOffset(500, 50)
statusLabel.Position = UDim2.new(0.5, -250, 0.72, 0)
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextStrokeTransparency = 0.5
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = ""
statusLabel.Parent = screenGui

-- Reveal / KEEP / SELL panel
local revealPanel = Instance.new("Frame")
revealPanel.Name = "RevealPanel"
revealPanel.Size = UDim2.fromOffset(420, 170)
revealPanel.Position = UDim2.new(0.5, -210, 0.3, 0)
revealPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
revealPanel.Visible = false
revealPanel.Parent = screenGui

local revealNameLabel = Instance.new("TextLabel")
revealNameLabel.Name = "NameLabel"
revealNameLabel.Size = UDim2.new(1, 0, 0.35, 0)
revealNameLabel.BackgroundTransparency = 1
revealNameLabel.Font = Enum.Font.GothamBold
revealNameLabel.TextScaled = true
revealNameLabel.Parent = revealPanel

local revealDetailLabel = Instance.new("TextLabel")
revealDetailLabel.Name = "DetailLabel"
revealDetailLabel.Size = UDim2.new(1, 0, 0.25, 0)
revealDetailLabel.Position = UDim2.new(0, 0, 0.35, 0)
revealDetailLabel.BackgroundTransparency = 1
revealDetailLabel.Font = Enum.Font.Gotham
revealDetailLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
revealDetailLabel.TextScaled = true
revealDetailLabel.Parent = revealPanel

local keepButton = Instance.new("TextButton")
keepButton.Name = "KeepButton"
keepButton.Text = "KEEP"
keepButton.Size = UDim2.new(0.45, 0, 0.3, 0)
keepButton.Position = UDim2.new(0.025, 0, 0.65, 0)
keepButton.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
keepButton.TextColor3 = Color3.fromRGB(255, 255, 255)
keepButton.TextScaled = true
keepButton.Parent = revealPanel

local sellItemButton = Instance.new("TextButton")
sellItemButton.Name = "SellItemButton"
sellItemButton.Text = "SELL"
sellItemButton.Size = UDim2.new(0.45, 0, 0.3, 0)
sellItemButton.Position = UDim2.new(0.525, 0, 0.65, 0)
sellItemButton.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
sellItemButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sellItemButton.TextScaled = true
sellItemButton.Parent = revealPanel

local currentInventoryIndex = nil

-- Catalogue button + grid
local catalogueButton = Instance.new("TextButton")
catalogueButton.Name = "CatalogueButton"
catalogueButton.Text = "CATALOGUE"
catalogueButton.Size = UDim2.fromOffset(160, 40)
catalogueButton.Position = UDim2.new(0, 20, 0, 20)
catalogueButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
catalogueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
catalogueButton.TextScaled = true
catalogueButton.Parent = screenGui

local catalogueFrame = Instance.new("Frame")
catalogueFrame.Name = "CatalogueFrame"
catalogueFrame.Size = UDim2.fromScale(0.6, 0.7)
catalogueFrame.Position = UDim2.fromScale(0.2, 0.1)
catalogueFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
catalogueFrame.Visible = false
catalogueFrame.Parent = screenGui

local catalogueTitle = Instance.new("TextLabel")
catalogueTitle.Name = "Title"
catalogueTitle.Size = UDim2.new(1, -40, 0, 40)
catalogueTitle.BackgroundTransparency = 1
catalogueTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
catalogueTitle.Font = Enum.Font.GothamBold
catalogueTitle.TextScaled = true
catalogueTitle.Text = "CATALOGUE (0 / " .. #allItemIds .. ")"
catalogueTitle.Parent = catalogueFrame

local catalogueCloseButton = Instance.new("TextButton")
catalogueCloseButton.Text = "X"
catalogueCloseButton.Size = UDim2.fromOffset(30, 30)
catalogueCloseButton.Position = UDim2.new(1, -35, 0, 5)
catalogueCloseButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
catalogueCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
catalogueCloseButton.Parent = catalogueFrame

local catalogueScroll = Instance.new("ScrollingFrame")
catalogueScroll.Size = UDim2.new(1, 0, 1, -40)
catalogueScroll.Position = UDim2.new(0, 0, 0, 40)
catalogueScroll.BackgroundTransparency = 1
catalogueScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
catalogueScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
catalogueScroll.ScrollBarThickness = 8
catalogueScroll.Parent = catalogueFrame

local catalogueGrid = Instance.new("UIGridLayout")
catalogueGrid.CellSize = UDim2.fromOffset(90, 90)
catalogueGrid.CellPadding = UDim2.fromOffset(6, 6)
catalogueGrid.Parent = catalogueScroll

local slotsByItemId = {}

for _, itemId in ipairs(allItemIds) do
	local slot = Instance.new("Frame")
	slot.Name = itemId
	slot.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	slot.Parent = catalogueScroll

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -4, 0.6, 0)
	nameLabel.Position = UDim2.new(0, 2, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(90, 90, 90)
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.Text = "?"
	nameLabel.Parent = slot

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, -4, 0.3, 0)
	countLabel.Position = UDim2.new(0, 2, 0.65, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	countLabel.TextScaled = true
	countLabel.Font = Enum.Font.Gotham
	countLabel.Text = ""
	countLabel.Parent = slot

	slotsByItemId[itemId] = slot
end

local function refreshCatalogue(catalogueData, catalogueCount)
	catalogueTitle.Text = "CATALOGUE (" .. (catalogueCount or 0) .. " / " .. #allItemIds .. ")"

	for _, itemId in ipairs(allItemIds) do
		local slot = slotsByItemId[itemId]
		local entry = catalogueData and catalogueData[itemId]

		if entry and entry.found then
			local item = ItemTable[itemId]
			slot.BackgroundColor3 = TIER_COLORS[item.tier] or Color3.fromRGB(45, 45, 50)
			slot.NameLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
			slot.NameLabel.Text = item.name
			slot.CountLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
			slot.CountLabel.Text = "x" .. entry.count
		else
			slot.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			slot.NameLabel.TextColor3 = Color3.fromRGB(90, 90, 90)
			slot.NameLabel.Text = "?"
			slot.CountLabel.Text = ""
		end
	end
end

refreshCatalogue({}, 0)

local function hideLumpButtons()
	currentLumpId = nil
	sellButton.Visible = false
	openButton.Visible = false
	statusLabel.Text = ""
end

local function showHints(lumpId, hints)
	local lumpPart = Workspace:WaitForChild("Lump_" .. lumpId, 5)
	if not lumpPart then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HintDisplay"
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = lumpPart

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.Text = string.upper(hints.Weight) .. " · " .. string.upper(hints.Temperature) .. " · " .. string.upper(hints.Sheen)
	label.Parent = billboard
end

prompt.Triggered:Connect(function(triggeringPlayer)
	if triggeringPlayer == player then
		requestDig:FireServer()
	end
end)

sellButton.Activated:Connect(function()
	if currentLumpId then
		requestSellBlind:FireServer(currentLumpId)
	end
end)

openButton.Activated:Connect(function()
	if currentLumpId then
		requestOpen:FireServer(currentLumpId)
	end
end)

keepButton.Activated:Connect(function()
	revealPanel.Visible = false
	currentInventoryIndex = nil
end)

sellItemButton.Activated:Connect(function()
	if currentInventoryIndex then
		requestSellItem:FireServer(currentInventoryIndex)
	end
	revealPanel.Visible = false
	currentInventoryIndex = nil
end)

catalogueButton.Activated:Connect(function()
	catalogueFrame.Visible = not catalogueFrame.Visible
end)

catalogueCloseButton.Activated:Connect(function()
	catalogueFrame.Visible = false
end)

lumpSpawned.OnClientEvent:Connect(function(lumpId, hints, blindOffer, openCost)
	currentLumpId = lumpId

	sellButton.Text = "SELL BLIND — " .. blindOffer
	sellButton.Visible = true

	openButton.Text = openCost <= 0 and "OPEN — FREE" or ("OPEN — " .. openCost)
	openButton.Visible = true

	showHints(lumpId, hints)
end)

blindSold.OnClientEvent:Connect(function(amount)
	hideLumpButtons()
end)

revealResult.OnClientEvent:Connect(function(itemId, tier, value, isNew, inventoryIndex)
	hideLumpButtons()

	currentInventoryIndex = inventoryIndex
	local item = ItemTable[itemId]

	revealNameLabel.TextColor3 = TIER_COLORS[tier] or Color3.fromRGB(255, 255, 255)
	revealNameLabel.Text = item.name .. (isNew and "   [NEW]" or "")
	revealDetailLabel.Text = string.upper(tier) .. " — " .. value .. " coins"

	revealPanel.Visible = true
end)

openRefused.OnClientEvent:Connect(function(reason)
	statusLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
	statusLabel.Text = reason

	task.delay(3, function()
		if statusLabel.Text == reason then
			statusLabel.Text = ""
		end
	end)
end)

catalogueUpdated.OnClientEvent:Connect(function(catalogueData, catalogueCount)
	refreshCatalogue(catalogueData, catalogueCount)
end)
