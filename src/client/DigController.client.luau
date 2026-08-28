local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDig = remotes:WaitForChild("RequestDig")
local requestSellBlind = remotes:WaitForChild("RequestSellBlind")
local requestOpen = remotes:WaitForChild("RequestOpen")
local lumpSpawned = remotes:WaitForChild("LumpSpawned")
local blindSold = remotes:WaitForChild("BlindSold")
local revealResult = remotes:WaitForChild("RevealResult")
local openRefused = remotes:WaitForChild("OpenRefused")

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

-- TEMPORARY: this whole screen is replaced by the real HUD once catalogue,
-- inventory, and keep/sell exist starting Phase 6.
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

revealResult.OnClientEvent:Connect(function(itemName, tier, value)
	hideLumpButtons()

	statusLabel.TextColor3 = TIER_COLORS[tier] or Color3.fromRGB(255, 255, 255)
	statusLabel.Text = itemName .. " — " .. string.upper(tier) .. " (" .. value .. " coins)"

	task.delay(4, function()
		if statusLabel.Text == itemName .. " — " .. string.upper(tier) .. " (" .. value .. " coins)" then
			statusLabel.Text = ""
		end
	end)
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
