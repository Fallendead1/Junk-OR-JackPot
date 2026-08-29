local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)
local ItemTable = require(ReplicatedStorage.Modules.ItemTable)
local TierColors = require(ReplicatedStorage.Modules.TierColors)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local RateLimiter = require(ServerScriptService.Services.RateLimiter)

local ShelfService = {}

-- GDD §8.2: a shared warehouse with a pool of Config.WAREHOUSE_PLOT_COUNT plots, assigned on join.
local PLOTS_PER_ROW = 6
local PLOT_SIZE = 20
local PLOT_SPACING = 26
local WAREHOUSE_ORIGIN = Vector3.new(-300, 1, 0) -- far from the dig zones

local SLOT_SIZE = Vector3.new(1.5, 1.5, 1.5)
local SLOTS_PER_ROW = 4
local SLOT_SPACING = 4

local availablePlotNumbers = {}
local plotByPlayer = {} -- [player] = plotNumber
local playerByPlot = {} -- [plotNumber] = player
local labelByPlot = {} -- [plotNumber] = TextLabel
local warehouseFolder

local function getPlotPosition(plotNumber)
	local index = plotNumber - 1
	local col = index % PLOTS_PER_ROW
	local row = math.floor(index / PLOTS_PER_ROW)
	return WAREHOUSE_ORIGIN + Vector3.new(col * PLOT_SPACING, 0, row * PLOT_SPACING)
end

local function getSlotOffset(slot)
	local index = slot - 1
	local col = index % SLOTS_PER_ROW
	local row = math.floor(index / SLOTS_PER_ROW)
	return Vector3.new((col - 1.5) * SLOT_SPACING, 1, (row - 1.5) * SLOT_SPACING)
end

local function createWarehouse()
	warehouseFolder = Instance.new("Folder")
	warehouseFolder.Name = "Warehouse"
	warehouseFolder.Parent = Workspace

	for plotNumber = 1, Config.WAREHOUSE_PLOT_COUNT do
		local pad = Instance.new("Part")
		pad.Name = "Plot" .. plotNumber
		pad.Anchored = true
		pad.CanCollide = true
		pad.Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE)
		pad.Position = getPlotPosition(plotNumber)
		pad.Color = Color3.fromRGB(120, 100, 80)
		pad.Material = Enum.Material.WoodPlanks
		pad.Parent = warehouseFolder

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PlotLabel"
		billboard.Size = UDim2.fromOffset(200, 50)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = pad

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Text = "Plot " .. plotNumber .. " (empty)"
		label.Parent = billboard

		labelByPlot[plotNumber] = label

		local itemsFolder = Instance.new("Folder")
		itemsFolder.Name = "Items"
		itemsFolder.Parent = pad
	end
end

local function getPlotPad(plotNumber)
	return warehouseFolder:FindFirstChild("Plot" .. plotNumber)
end

-- Server-created and server-owned, so it replicates to every client the same
-- way any other Workspace Part does -- no remote needed for other players to
-- see it. The label is always visible rather than hover-triggered, which is
-- what "walk up and read every item" actually needs.
local function renderShelfItem(plotNumber, slot, itemId)
	local pad = getPlotPad(plotNumber)
	if not pad then
		return
	end

	local itemsFolder = pad.Items
	local existing = itemsFolder:FindFirstChild("Slot" .. slot)
	if existing then
		existing:Destroy()
	end

	if not itemId then
		return
	end

	local item = ItemTable[itemId]
	local ownerPlayer = playerByPlot[plotNumber]

	local part = Instance.new("Part")
	part.Name = "Slot" .. slot
	part.Anchored = true
	part.CanCollide = false
	part.Size = SLOT_SIZE
	part.Position = pad.Position + getSlotOffset(slot)
	part.Color = TierColors[item.tier] or Color3.fromRGB(200, 200, 200)
	part.Material = Enum.Material.Neon
	part.Parent = itemsFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 60)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Gotham
	label.TextColor3 = TierColors[item.tier] or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Text = item.name .. "\n" .. string.upper(item.tier) .. " — " .. item.value .. "\n"
		.. (ownerPlayer and ownerPlayer.DisplayName or "")
	label.Parent = billboard
end

local function clearPlotItems(plotNumber)
	local pad = getPlotPad(plotNumber)
	if pad then
		pad.Items:ClearAllChildren()
	end
end

local function sendMyShelf(player, profile)
	ReplicatedStorage.Remotes.MyShelfUpdated:FireClient(player, profile.Data.shelf, profile.Data.shelfSlots)
end

local function sendMyInventory(player, profile)
	ReplicatedStorage.Remotes.MyInventoryUpdated:FireClient(player, profile.Data.inventory)
end

local function onProfileLoaded(player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	sendMyShelf(player, profile)

	if #availablePlotNumbers == 0 then
		return -- no plots left this session (more concurrent players than warehouse plots)
	end

	local plotNumber = table.remove(availablePlotNumbers, 1)
	plotByPlayer[player] = plotNumber
	playerByPlot[plotNumber] = player
	labelByPlot[plotNumber].Text = "Plot " .. plotNumber .. " — " .. player.DisplayName

	for slot, itemId in pairs(profile.Data.shelf) do
		renderShelfItem(plotNumber, slot, itemId)
	end
end

local function onPlayerRemoving(player)
	local plotNumber = plotByPlayer[player]
	if not plotNumber then
		return
	end

	clearPlotItems(plotNumber)
	labelByPlot[plotNumber].Text = "Plot " .. plotNumber .. " (empty)"

	playerByPlot[plotNumber] = nil
	plotByPlayer[player] = nil
	table.insert(availablePlotNumbers, plotNumber)
end

local function onRequestPlaceShelf(player, inventoryIndex, slot)
	if not RateLimiter.Allow(player, "RequestPlaceShelf") then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local plotNumber = plotByPlayer[player]
	if not plotNumber then
		return -- no plot assigned
	end

	if type(slot) ~= "number" or slot < 1 or slot > profile.Data.shelfSlots then
		return -- break test: out-of-range slot rejected
	end

	if profile.Data.shelf[slot] ~= nil then
		return -- slot already occupied
	end

	local entry = profile.Data.inventory[inventoryIndex]
	if not entry then
		return -- invalid inventory index
	end

	table.remove(profile.Data.inventory, inventoryIndex)
	profile.Data.shelf[slot] = entry.itemId

	renderShelfItem(plotNumber, slot, entry.itemId)
	sendMyShelf(player, profile)
	sendMyInventory(player, profile)
end

local function onRequestRemoveShelf(player, slot)
	if not RateLimiter.Allow(player, "RequestRemoveShelf") then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local plotNumber = plotByPlayer[player]
	if not plotNumber then
		return
	end

	local itemId = profile.Data.shelf[slot]
	if not itemId then
		return -- nothing there
	end

	profile.Data.shelf[slot] = nil
	table.insert(profile.Data.inventory, {
		itemId = itemId,
		value = ItemTable[itemId].value,
		rolledAt = os.time(),
	})

	renderShelfItem(plotNumber, slot, nil)
	sendMyShelf(player, profile)
	sendMyInventory(player, profile)
end

-- Called by UpgradeService right after a shelf slot purchase succeeds.
function ShelfService.NotifyShelfSlotsChanged(player, profile)
	sendMyShelf(player, profile)
end

function ShelfService.Init()
	for i = 1, Config.WAREHOUSE_PLOT_COUNT do
		table.insert(availablePlotNumbers, i)
	end

	createWarehouse()

	local remotes = ReplicatedStorage.Remotes
	remotes.RequestPlaceShelf.OnServerEvent:Connect(onRequestPlaceShelf)
	remotes.RequestRemoveShelf.OnServerEvent:Connect(onRequestRemoveShelf)

	PlayerDataService.ProfileLoaded.Event:Connect(onProfileLoaded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return ShelfService
