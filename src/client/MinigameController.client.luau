local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- dig-minigame-spec.md Step 5: just enough client-side to prove the commit
-- trigger fires with the right payload. The real bar UI, camera zoom, and
-- shovel-to-hand transition are Step 6+ -- this is a placeholder status
-- label only, the same way TempDigUI stood in for the real HUD in Phase 1.
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local minigameStart = remotes:WaitForChild("MinigameStart")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TempMinigameUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "MinigameStatusLabel"
statusLabel.Size = UDim2.fromOffset(500, 50)
statusLabel.Position = UDim2.new(0.5, -250, 0.55, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextStrokeTransparency = 0.3
statusLabel.TextScaled = true
statusLabel.Text = ""
statusLabel.Parent = screenGui

local currentMinigame = nil

minigameStart.OnClientEvent:Connect(function(payload)
	currentMinigame = payload

	statusLabel.Text = "MINIGAME STARTED — " .. string.upper(payload.rarity) .. " (Zone " .. payload.zone .. ")"
	task.delay(4, function()
		if currentMinigame == payload then
			statusLabel.Text = ""
		end
	end)
end)
