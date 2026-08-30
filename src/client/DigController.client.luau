local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemTable = require(ReplicatedStorage.Modules.ItemTable)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)
local ShovelTable = require(ReplicatedStorage.Modules.ShovelTable)
local Config = require(ReplicatedStorage.Modules.Config)
local UIJuice = require(ReplicatedStorage.Modules.UIJuice)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestSellBlind = remotes:WaitForChild("RequestSellBlind")
local requestOpen = remotes:WaitForChild("RequestOpen")
local requestSellItem = remotes:WaitForChild("RequestSellItem")
local requestBuyUpgrade = remotes:WaitForChild("RequestBuyUpgrade")
local lumpSpawned = remotes:WaitForChild("LumpSpawned")
local blindSold = remotes:WaitForChild("BlindSold")
local revealResult = remotes:WaitForChild("RevealResult")
local openRefused = remotes:WaitForChild("OpenRefused")
local catalogueUpdated = remotes:WaitForChild("CatalogueUpdated")
local upgradePurchased = remotes:WaitForChild("UpgradePurchased")
local upgradeRefused = remotes:WaitForChild("UpgradeRefused")
local myShelfUpdated = remotes:WaitForChild("MyShelfUpdated")

-- Each zone has its own physical dig spot + prompt. The prompt's HoldDuration
-- starts at the zone's base (Rusty shovel) time; onUpgradePurchased below
-- corrects it locally once we know the player's real shovel tier.
local ZONE_DIG_SPOTS = {
	[1] = Workspace:WaitForChild("DigSpot"),
	[2] = Workspace:WaitForChild("DigSpot2"),
	[3] = Workspace:WaitForChild("DigSpot3"),
	[4] = Workspace:WaitForChild("DigSpot4"),
	[5] = Workspace:WaitForChild("DigSpot5"),
}

local TIER_COLORS = require(ReplicatedStorage.Modules.TierColors)

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

UIJuice.MakeButtonJuicy(sellButton)
UIJuice.MakeButtonJuicy(openButton)

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

UIJuice.MakeButtonJuicy(keepButton)
UIJuice.MakeButtonJuicy(sellItemButton)

local currentInventoryIndex = nil
local currentShovelTier = 1
local currentCatalogueCount = 0
local currentShelfSlots = Config.SHELF_BASE_SLOTS
local myZonesUnlocked = { [1] = true }

-- Catalogue button + grid. Image-only icon button, no text or background box.
local catalogueButton = Instance.new("ImageButton")
catalogueButton.Name = "CatalogueButton"
catalogueButton.Size = UDim2.fromOffset(56, 56)
catalogueButton.Position = UDim2.new(0, 20, 0, 20)
catalogueButton.BackgroundTransparency = 1
catalogueButton.Image = "rbxassetid://110770558728732"
catalogueButton.Parent = screenGui

UIJuice.MakeButtonJuicy(catalogueButton)

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

UIJuice.MakeButtonJuicy(catalogueCloseButton)

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

-- Normal shovels only ever hold one lump, but the Excavator digs 2 at once
-- (GDD §7.1). Only one lump is ever shown/decided at a time through the
-- existing SELL BLIND / OPEN buttons; the rest wait here.
local pendingLumps = {}

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

	local words = { string.upper(hints.Weight), string.upper(hints.Temperature), string.upper(hints.Sheen) }
	if hints.Texture then -- Scanner's 4th hint (GDD §10.1)
		table.insert(words, string.upper(hints.Texture))
	end
	label.Text = table.concat(words, " · ")

	label.Parent = billboard
end

-- dig-minigame-spec.md replaces this hold-E interaction entirely (a
-- left-click commit on a detector find spot, System 3, takes its place).
-- Disabled rather than deleted so the old flow is easy to compare against
-- until the new commit trigger (build order Step 5) is actually in place.
for _, digSpot in pairs(ZONE_DIG_SPOTS) do
	local zonePrompt = digSpot:WaitForChild("ProximityPrompt")
	zonePrompt.Enabled = false
end

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
	if catalogueFrame.Visible then
		UIJuice.PopIn(catalogueFrame)
	end
end)

catalogueCloseButton.Activated:Connect(function()
	catalogueFrame.Visible = false
end)

-- Shop: shovel upgrade + Zone 2 unlock. Image-only icon button, no text or background box.
local shopButton = Instance.new("ImageButton")
shopButton.Name = "ShopButton"
shopButton.Size = UDim2.fromOffset(56, 56)
shopButton.Position = UDim2.new(0, 20, 0, 86)
shopButton.BackgroundTransparency = 1
shopButton.Image = "rbxassetid://125854557721187"
shopButton.Parent = screenGui

UIJuice.MakeButtonJuicy(shopButton)

local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.fromOffset(360, 330)
shopFrame.Position = UDim2.new(0, 20, 0, 120)
shopFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
shopFrame.Visible = false
shopFrame.Parent = screenGui

local shovelLabel = Instance.new("TextLabel")
shovelLabel.Name = "ShovelLabel"
shovelLabel.Size = UDim2.new(1, -20, 0, 50)
shovelLabel.Position = UDim2.new(0, 10, 0, 10)
shovelLabel.BackgroundTransparency = 1
shovelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
shovelLabel.TextWrapped = true
shovelLabel.TextScaled = true
shovelLabel.Font = Enum.Font.Gotham
shovelLabel.Parent = shopFrame

local buyShovelButton = Instance.new("TextButton")
buyShovelButton.Name = "BuyShovelButton"
buyShovelButton.Size = UDim2.new(1, -20, 0, 40)
buyShovelButton.Position = UDim2.new(0, 10, 0, 65)
buyShovelButton.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
buyShovelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
buyShovelButton.TextScaled = true
buyShovelButton.Parent = shopFrame

local zoneLabel = Instance.new("TextLabel")
zoneLabel.Name = "ZoneLabel"
zoneLabel.Size = UDim2.new(1, -20, 0, 70)
zoneLabel.Position = UDim2.new(0, 10, 0, 120)
zoneLabel.BackgroundTransparency = 1
zoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
zoneLabel.TextWrapped = true
zoneLabel.TextScaled = true
zoneLabel.Font = Enum.Font.Gotham
zoneLabel.Parent = shopFrame

local buyZoneButton = Instance.new("TextButton")
buyZoneButton.Name = "BuyZoneButton"
buyZoneButton.Text = "UNLOCK THE QUARRY"
buyZoneButton.Size = UDim2.new(1, -20, 0, 40)
buyZoneButton.Position = UDim2.new(0, 10, 0, 200)
buyZoneButton.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
buyZoneButton.TextColor3 = Color3.fromRGB(255, 255, 255)
buyZoneButton.TextScaled = true
buyZoneButton.Parent = shopFrame

local shelfLabel = Instance.new("TextLabel")
shelfLabel.Name = "ShelfLabel"
shelfLabel.Size = UDim2.new(1, -20, 0, 50)
shelfLabel.Position = UDim2.new(0, 10, 0, 250)
shelfLabel.BackgroundTransparency = 1
shelfLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
shelfLabel.TextWrapped = true
shelfLabel.TextScaled = true
shelfLabel.Font = Enum.Font.Gotham
shelfLabel.Parent = shopFrame

local buyShelfSlotButton = Instance.new("TextButton")
buyShelfSlotButton.Name = "BuyShelfSlotButton"
buyShelfSlotButton.Size = UDim2.new(1, -20, 0, 40)
buyShelfSlotButton.Position = UDim2.new(0, 10, 0, 285)
buyShelfSlotButton.BackgroundColor3 = Color3.fromRGB(140, 100, 40)
buyShelfSlotButton.TextColor3 = Color3.fromRGB(255, 255, 255)
buyShelfSlotButton.TextScaled = true
buyShelfSlotButton.Parent = shopFrame

UIJuice.MakeButtonJuicy(buyShovelButton)
UIJuice.MakeButtonJuicy(buyZoneButton)
UIJuice.MakeButtonJuicy(buyShelfSlotButton)

shopButton.Activated:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
	if shopFrame.Visible then
		UIJuice.PopIn(shopFrame)
	end
end)

buyShovelButton.Activated:Connect(function()
	requestBuyUpgrade:FireServer("shovel", currentShovelTier + 1)
end)

local function getNextLockedZone()
	for zoneNumber = 2, 5 do
		if not myZonesUnlocked[zoneNumber] then
			return zoneNumber
		end
	end
	return nil
end

buyZoneButton.Activated:Connect(function()
	local nextZone = getNextLockedZone()
	if nextZone then
		requestBuyUpgrade:FireServer("zone", nextZone)
	end
end)

buyShelfSlotButton.Activated:Connect(function()
	requestBuyUpgrade:FireServer("shelfSlot", currentShelfSlots + 1)
end)

-- GDD §7.3: matches UpgradeService's server-side formula exactly (this is
-- display-only; the server is what actually validates and charges).
local function nextShelfSlotCost()
	local n = (currentShelfSlots + 1) - Config.SHELF_BASE_SLOTS
	return math.round(Config.SHELF_BASE_COST * Config.SHELF_COST_MULT ^ n)
end

local function refreshShopUI()
	local currentShovel = ShovelTable[currentShovelTier]
	local nextShovel = ShovelTable[currentShovelTier + 1]

	if nextShovel then
		shovelLabel.Text = "Shovel: " .. currentShovel.name .. "\nNext: " .. nextShovel.name .. " — " .. nextShovel.cost .. " coins"
		buyShovelButton.Text = "BUY " .. string.upper(nextShovel.name) .. " — " .. nextShovel.cost
		buyShovelButton.Visible = true
	else
		shovelLabel.Text = "Shovel: " .. currentShovel.name .. " (max for now)"
		buyShovelButton.Visible = false
	end

	local nextZone = getNextLockedZone()
	if nextZone then
		local zone = ZoneTable[nextZone]
		local requirement = zone.requirement or {}
		local requirementText = ""
		if requirement.catalogueEntries then
			requirementText = requirementText .. " + " .. requirement.catalogueEntries .. " catalogue entries (you have " .. currentCatalogueCount .. ")"
		end
		if requirement.shovelTier then
			requirementText = requirementText .. " + " .. ShovelTable[requirement.shovelTier].name .. " Shovel"
		end

		zoneLabel.Text = zone.name .. ": " .. zone.unlockCost .. " coins" .. requirementText
		buyZoneButton.Text = "UNLOCK " .. string.upper(zone.name)
		buyZoneButton.Visible = true
	else
		zoneLabel.Text = "All zones unlocked!"
		buyZoneButton.Visible = false
	end

	local cost = nextShelfSlotCost()
	shelfLabel.Text = "Shelf slots: " .. currentShelfSlots .. "\nNext slot (" .. (currentShelfSlots + 1) .. "): " .. cost .. " coins"
	buyShelfSlotButton.Text = "BUY SLOT " .. (currentShelfSlots + 1) .. " — " .. cost
end

refreshShopUI()

local function showLump(lumpData)
	currentLumpId = lumpData.lumpId

	sellButton.Text = "SELL BLIND — " .. lumpData.blindOffer
	sellButton.Visible = true
	UIJuice.PopIn(sellButton)

	openButton.Text = lumpData.openCost <= 0 and "OPEN — FREE" or ("OPEN — " .. lumpData.openCost)
	openButton.Visible = true
	UIJuice.PopIn(openButton)

	showHints(lumpData.lumpId, lumpData.hints)
end

-- Auto-Dig (GDD §10.1) doesn't exist in dig-minigame-spec.md's replacement
-- system -- there's no equivalent of "auto-repeat" once digging is a
-- click-based minigame, and firing RequestDig on a timer here bypassed the
-- (now-disabled) ProximityPrompt entirely, which is what was popping the
-- SELL BLIND / OPEN panel on its own just from standing near a zone.
local function showNextPendingLump()
	local nextLump = table.remove(pendingLumps, 1)
	if nextLump then
		showLump(nextLump)
	else
		hideLumpButtons()
	end
end

lumpSpawned.OnClientEvent:Connect(function(lumpId, hints, blindOffer, openCost)
	local lumpData = { lumpId = lumpId, hints = hints, blindOffer = blindOffer, openCost = openCost }

	if currentLumpId == nil then
		showLump(lumpData)
	else
		-- Excavator's second lump of the dig waits its turn.
		table.insert(pendingLumps, lumpData)
	end
end)

blindSold.OnClientEvent:Connect(function(amount)
	showNextPendingLump()
end)

revealResult.OnClientEvent:Connect(function(itemId, tier, value, isNew, inventoryIndex)
	showNextPendingLump()

	currentInventoryIndex = inventoryIndex
	local item = ItemTable[itemId]

	revealNameLabel.TextColor3 = TIER_COLORS[tier] or Color3.fromRGB(255, 255, 255)
	revealNameLabel.Text = item.name .. (isNew and "   [NEW]" or "")
	revealDetailLabel.Text = string.upper(tier) .. " — " .. value .. " coins"

	revealPanel.Visible = true
	UIJuice.PopIn(revealPanel)
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
	currentCatalogueCount = catalogueCount or 0
	refreshShopUI()
end)

upgradePurchased.OnClientEvent:Connect(function(upgradeType, tier)
	if upgradeType == "shovel" then
		currentShovelTier = tier
		refreshShopUI()

		-- Correct each zone's prompt to this player's real hold time. A
		-- shared Part's property write from a LocalScript only affects this
		-- client's own view of it -- other players still see their own.
		local multiplier = ShovelTable[tier].digTimeMultiplier
		for zoneNumber, digSpot in pairs(ZONE_DIG_SPOTS) do
			local zonePrompt = digSpot:FindFirstChild("ProximityPrompt")
			if zonePrompt then
				zonePrompt.HoldDuration = ZoneTable[zoneNumber].digTime * multiplier
			end
		end
	elseif upgradeType == "zone" then
		myZonesUnlocked[tier] = true
		refreshShopUI()

		statusLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
		statusLabel.Text = "Unlocked " .. ZoneTable[tier].name .. "!"
		task.delay(3, function()
			statusLabel.Text = ""
		end)
	elseif upgradeType == "shelfSlot" then
		refreshShopUI() -- currentShelfSlots itself updates via MyShelfUpdated below
	end
end)

myShelfUpdated.OnClientEvent:Connect(function(shelf, shelfSlots)
	currentShelfSlots = shelfSlots
	refreshShopUI()
end)

upgradeRefused.OnClientEvent:Connect(function(reason)
	statusLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
	statusLabel.Text = reason

	task.delay(3, function()
		if statusLabel.Text == reason then
			statusLabel.Text = ""
		end
	end)
end)
