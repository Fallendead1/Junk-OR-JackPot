local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestDig = remotes:WaitForChild("RequestDig")
local requestDestroyLump = remotes:WaitForChild("RequestDestroyLump")
local lumpSpawned = remotes:WaitForChild("LumpSpawned")
local lumpCleared = remotes:WaitForChild("LumpCleared")

local digSpot = Workspace:WaitForChild("DigSpot")
local prompt = digSpot:WaitForChild("ProximityPrompt")

-- TEMPORARY: this whole button is replaced by the real KEEP/SELL prompt
-- starting Phase 3. Deleting it then is expected, not a regression.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TempDigUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local destroyButton = Instance.new("TextButton")
destroyButton.Name = "DestroyButton"
destroyButton.Text = "DESTROY"
destroyButton.Size = UDim2.fromOffset(160, 50)
destroyButton.Position = UDim2.new(0.5, -80, 0.8, 0)
destroyButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
destroyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
destroyButton.TextScaled = true
destroyButton.Visible = false
destroyButton.Parent = screenGui

prompt.Triggered:Connect(function(triggeringPlayer)
	if triggeringPlayer == player then
		requestDig:FireServer()
	end
end)

destroyButton.Activated:Connect(function()
	requestDestroyLump:FireServer()
end)

lumpSpawned.OnClientEvent:Connect(function()
	destroyButton.Visible = true
end)

lumpCleared.OnClientEvent:Connect(function()
	destroyButton.Visible = false
end)
