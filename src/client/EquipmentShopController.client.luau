local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local UIJuice = require(ReplicatedStorage.Modules.UIJuice)

-- dig-minigame-spec.md Step 9 (System 5): buy/equip UI for shovels and
-- detectors. Simplified from the full spec -- one toggle panel with two
-- sections, matching every other shop UI already in this game, rather than
-- physical racks/pegs in the world (System 5.1) or a per-item confirmation
-- dialog (System 5.2). Coins only -- see EquipmentShopService for why Robux
-- isn't wired here yet.
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestBuyEquipment = remotes:WaitForChild("RequestBuyEquipment")
local requestEquipTool = remotes:WaitForChild("RequestEquipTool")
local equipmentPurchaseRefused = remotes:WaitForChild("EquipmentPurchaseRefused")
local ownedEquipmentUpdated = remotes:WaitForChild("OwnedEquipmentUpdated")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EquipmentShopUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "EquipmentShopButton"
toggleButton.Text = "GEAR"
toggleButton.Size = UDim2.fromOffset(160, 40)
toggleButton.Position = UDim2.new(0, 1040, 0, 20)
toggleButton.BackgroundColor3 = Color3.fromRGB(60, 140, 140)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextScaled = true
toggleButton.Parent = screenGui

UIJuice.MakeButtonJuicy(toggleButton)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(460, 500)
panel.Position = UDim2.fromScale(0.27, 0.08)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.Visible = false
panel.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.new(0, 5, 0, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Text = "EQUIPMENT"
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.fromOffset(30, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = panel

UIJuice.MakeButtonJuicy(closeButton)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -40)
scroll.Position = UDim2.new(0, 0, 0, 40)
scroll.BackgroundTransparency = 1
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 8
scroll.Parent = panel

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.Parent = scroll

local function addSectionHeader(text)
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -10, 0, 26)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextColor3 = Color3.fromRGB(200, 200, 200)
	header.TextScaled = true
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = text
	header.Parent = scroll
end

-- rows[toolType][tier] = { row, statusButton }
local rows = { shovel = {}, detector = {} }
local ownedState = {
	ownedShovels = {},
	ownedDetectors = {},
	equippedShovelTier = 1,
	equippedDetectorTier = 1,
}

local function buildRow(toolType, tier, tierInfo, statsText)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 50)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	row.Parent = scroll

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = tierInfo.name .. "\n" .. statsText
	label.Parent = row

	local statusButton = Instance.new("TextButton")
	statusButton.Size = UDim2.new(0.35, 0, 0.8, 0)
	statusButton.Position = UDim2.new(0.63, 0, 0.1, 0)
	statusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusButton.TextScaled = true
	statusButton.Parent = row

	UIJuice.MakeButtonJuicy(statusButton)

	statusButton.Activated:Connect(function()
		local owned = toolType == "shovel" and ownedState.ownedShovels or ownedState.ownedDetectors
		if owned[tier] then
			requestEquipTool:FireServer(toolType, tier)
		else
			requestBuyEquipment:FireServer(toolType, tier)
		end
	end)

	rows[toolType][tier] = { row = row, statusButton = statusButton }
end

addSectionHeader("Metal Detectors")
for tier = 1, 5 do
	local tierInfo = Config.DETECTOR_TIERS[tier]
	local stats = "Luck x" .. tierInfo.luck .. "   Range " .. tierInfo.range
	buildRow("detector", tier, tierInfo, stats)
end

addSectionHeader("Shovels")
for tier = 1, 5 do
	local tierInfo = Config.SHOVEL_TIERS[tier]
	local stats = "Power " .. tierInfo.power .. "   Speed +" .. math.floor(tierInfo.speed * 100) .. "%"
	buildRow("shovel", tier, tierInfo, stats)
end

local function refreshRow(toolType, tier)
	local entry = rows[toolType][tier]
	if not entry then
		return
	end

	local tierInfo = toolType == "shovel" and Config.SHOVEL_TIERS[tier] or Config.DETECTOR_TIERS[tier]
	local owned = toolType == "shovel" and ownedState.ownedShovels or ownedState.ownedDetectors
	local equippedTier = toolType == "shovel" and ownedState.equippedShovelTier or ownedState.equippedDetectorTier

	local button = entry.statusButton
	if equippedTier == tier then
		button.Text = "EQUIPPED"
		button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		button.Active = false
	elseif owned[tier] then
		button.Text = "EQUIP"
		button.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
		button.Active = true
	else
		button.Text = "BUY — " .. tierInfo.cost
		button.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
		button.Active = true
	end
end

local function refreshAllRows()
	for tier = 1, 5 do
		refreshRow("detector", tier)
	end
	for tier = 1, 5 do
		refreshRow("shovel", tier)
	end
end

refreshAllRows()

toggleButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

closeButton.Activated:Connect(function()
	panel.Visible = false
end)

ownedEquipmentUpdated.OnClientEvent:Connect(function(payload)
	ownedState = payload
	refreshAllRows()
end)

equipmentPurchaseRefused.OnClientEvent:Connect(function(reason)
	toggleButton.Text = reason
	task.delay(3, function()
		toggleButton.Text = "GEAR"
	end)
end)
