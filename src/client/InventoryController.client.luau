local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemTable = require(ReplicatedStorage.Modules.ItemTable)
local TierColors = require(ReplicatedStorage.Modules.TierColors)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestPlaceShelf = remotes:WaitForChild("RequestPlaceShelf")
local requestRemoveShelf = remotes:WaitForChild("RequestRemoveShelf")
local myInventoryUpdated = remotes:WaitForChild("MyInventoryUpdated")
local myShelfUpdated = remotes:WaitForChild("MyShelfUpdated")

local myInventory = {}
local myShelf = {}
local myShelfSlots = 12

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local inventoryButton = Instance.new("TextButton")
inventoryButton.Name = "InventoryButton"
inventoryButton.Text = "INVENTORY"
inventoryButton.Size = UDim2.fromOffset(160, 40)
inventoryButton.Position = UDim2.new(0, 360, 0, 20)
inventoryButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
inventoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
inventoryButton.TextScaled = true
inventoryButton.Parent = screenGui

local inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryFrame"
inventoryFrame.Size = UDim2.fromScale(0.6, 0.7)
inventoryFrame.Position = UDim2.fromScale(0.2, 0.1)
inventoryFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
inventoryFrame.Visible = false
inventoryFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -40, 0, 40)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.Text = "INVENTORY & SHELF"
title.Parent = inventoryFrame

local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.fromOffset(30, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = inventoryFrame

local sectionLabel1 = Instance.new("TextLabel")
sectionLabel1.Size = UDim2.new(1, -20, 0, 30)
sectionLabel1.Position = UDim2.new(0, 10, 0, 40)
sectionLabel1.BackgroundTransparency = 1
sectionLabel1.Font = Enum.Font.GothamBold
sectionLabel1.TextColor3 = Color3.fromRGB(200, 200, 200)
sectionLabel1.TextScaled = true
sectionLabel1.TextXAlignment = Enum.TextXAlignment.Left
sectionLabel1.Text = "In your inventory (not on display):"
sectionLabel1.Parent = inventoryFrame

local inventoryScroll = Instance.new("ScrollingFrame")
inventoryScroll.Size = UDim2.new(1, 0, 0.4, -10)
inventoryScroll.Position = UDim2.new(0, 0, 0, 70)
inventoryScroll.BackgroundTransparency = 1
inventoryScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
inventoryScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
inventoryScroll.ScrollBarThickness = 8
inventoryScroll.Parent = inventoryFrame

local inventoryList = Instance.new("UIListLayout")
inventoryList.Padding = UDim.new(0, 4)
inventoryList.Parent = inventoryScroll

local sectionLabel2 = Instance.new("TextLabel")
sectionLabel2.Size = UDim2.new(1, -20, 0, 30)
sectionLabel2.Position = UDim2.new(0, 10, 0.4, 65)
sectionLabel2.BackgroundTransparency = 1
sectionLabel2.Font = Enum.Font.GothamBold
sectionLabel2.TextColor3 = Color3.fromRGB(200, 200, 200)
sectionLabel2.TextScaled = true
sectionLabel2.TextXAlignment = Enum.TextXAlignment.Left
sectionLabel2.Text = "On your shelf:"
sectionLabel2.Parent = inventoryFrame

local shelfScroll = Instance.new("ScrollingFrame")
shelfScroll.Size = UDim2.new(1, 0, 0.4, -10)
shelfScroll.Position = UDim2.new(0, 0, 0.4, 95)
shelfScroll.BackgroundTransparency = 1
shelfScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
shelfScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
shelfScroll.ScrollBarThickness = 8
shelfScroll.Parent = inventoryFrame

local shelfList = Instance.new("UIListLayout")
shelfList.Padding = UDim.new(0, 4)
shelfList.Parent = shelfScroll

inventoryButton.Activated:Connect(function()
	inventoryFrame.Visible = not inventoryFrame.Visible
end)

closeButton.Activated:Connect(function()
	inventoryFrame.Visible = false
end)

local function firstEmptySlot()
	for slot = 1, myShelfSlots do
		if not myShelf[slot] then
			return slot
		end
	end
	return nil
end

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function refreshInventoryList()
	clearChildren(inventoryScroll)

	for index, entry in ipairs(myInventory) do
		local item = ItemTable[entry.itemId]

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 44)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		row.Parent = inventoryScroll

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.6, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Gotham
		label.TextColor3 = TierColors[item.tier] or Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = item.name .. " (" .. string.upper(item.tier) .. ", " .. item.value .. ")"
		label.Parent = row

		local placeButton = Instance.new("TextButton")
		placeButton.Size = UDim2.new(0.35, 0, 0.8, 0)
		placeButton.Position = UDim2.new(0.63, 0, 0.1, 0)
		placeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		placeButton.TextScaled = true
		placeButton.Parent = row

		local emptySlot = firstEmptySlot()
		if emptySlot then
			placeButton.Text = "PLACE (slot " .. emptySlot .. ")"
			placeButton.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
			placeButton.Activated:Connect(function()
				requestPlaceShelf:FireServer(index, emptySlot)
			end)
		else
			placeButton.Text = "SHELF FULL"
			placeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			placeButton.Active = false
		end
	end
end

local function refreshShelfList()
	clearChildren(shelfScroll)

	for slot = 1, myShelfSlots do
		local itemId = myShelf[slot]
		if itemId then
			local item = ItemTable[itemId]

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 44)
			row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
			row.Parent = shelfScroll

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(0.6, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.Gotham
			label.TextColor3 = TierColors[item.tier] or Color3.fromRGB(255, 255, 255)
			label.TextScaled = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = "Slot " .. slot .. ": " .. item.name .. " (" .. string.upper(item.tier) .. ", " .. item.value .. ")"
			label.Parent = row

			local removeButton = Instance.new("TextButton")
			removeButton.Size = UDim2.new(0.35, 0, 0.8, 0)
			removeButton.Position = UDim2.new(0.63, 0, 0.1, 0)
			removeButton.Text = "REMOVE"
			removeButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
			removeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			removeButton.TextScaled = true
			removeButton.Parent = row

			removeButton.Activated:Connect(function()
				requestRemoveShelf:FireServer(slot)
			end)
		end
	end
end

myInventoryUpdated.OnClientEvent:Connect(function(inventory)
	myInventory = inventory
	refreshInventoryList()
end)

myShelfUpdated.OnClientEvent:Connect(function(shelf, shelfSlots)
	myShelf = shelf
	myShelfSlots = shelfSlots
	refreshShelfList()
	refreshInventoryList() -- the "first empty slot" hint on PLACE buttons may have changed
end)
