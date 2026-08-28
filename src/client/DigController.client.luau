local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDig = remotes:WaitForChild("RequestDig")
local requestSellBlind = remotes:WaitForChild("RequestSellBlind")
local lumpSpawned = remotes:WaitForChild("LumpSpawned")
local blindSold = remotes:WaitForChild("BlindSold")

local digSpot = Workspace:WaitForChild("DigSpot")
local prompt = digSpot:WaitForChild("ProximityPrompt")

-- TEMPORARY: this single SELL button is replaced by the real two-button
-- OPEN / SELL BLIND decision prompt starting Phase 5. Deleting it then is
-- expected, not a regression.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TempDigUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local sellButton = Instance.new("TextButton")
sellButton.Name = "SellButton"
sellButton.Text = "SELL"
sellButton.Size = UDim2.fromOffset(160, 50)
sellButton.Position = UDim2.new(0.5, -80, 0.8, 0)
sellButton.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sellButton.TextScaled = true
sellButton.Visible = false
sellButton.Parent = screenGui

prompt.Triggered:Connect(function(triggeringPlayer)
	if triggeringPlayer == player then
		requestDig:FireServer()
	end
end)

sellButton.Activated:Connect(function()
	requestSellBlind:FireServer()
end)

lumpSpawned.OnClientEvent:Connect(function()
	sellButton.Visible = true
end)

blindSold.OnClientEvent:Connect(function()
	sellButton.Visible = false
end)
