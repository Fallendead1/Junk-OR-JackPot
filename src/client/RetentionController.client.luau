local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestClaimDaily = remotes:WaitForChild("RequestClaimDaily")
local dailyRefused = remotes:WaitForChild("DailyRefused")
local requestLeaderboard = remotes:WaitForChild("RequestLeaderboard")
local leaderboardResult = remotes:WaitForChild("LeaderboardResult")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RetentionUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local dailyButton = Instance.new("TextButton")
dailyButton.Name = "DailyButton"
dailyButton.Text = "CLAIM DAILY"
dailyButton.Size = UDim2.fromOffset(160, 40)
dailyButton.Position = UDim2.new(0, 530, 0, 20)
dailyButton.BackgroundColor3 = Color3.fromRGB(180, 150, 30)
dailyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
dailyButton.TextScaled = true
dailyButton.Parent = screenGui

local leaderboardButton = Instance.new("TextButton")
leaderboardButton.Name = "LeaderboardButton"
leaderboardButton.Text = "LEADERBOARD"
leaderboardButton.Size = UDim2.fromOffset(160, 40)
leaderboardButton.Position = UDim2.new(0, 700, 0, 20)
leaderboardButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
leaderboardButton.TextColor3 = Color3.fromRGB(255, 255, 255)
leaderboardButton.TextScaled = true
leaderboardButton.Parent = screenGui

local leaderboardFrame = Instance.new("Frame")
leaderboardFrame.Name = "LeaderboardFrame"
leaderboardFrame.Size = UDim2.fromOffset(360, 200)
leaderboardFrame.Position = UDim2.new(0, 700, 0, 70)
leaderboardFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
leaderboardFrame.Visible = false
leaderboardFrame.Parent = screenGui

local leaderboardTitle = Instance.new("TextLabel")
leaderboardTitle.Size = UDim2.new(1, -10, 0, 30)
leaderboardTitle.Position = UDim2.new(0, 5, 0, 5)
leaderboardTitle.BackgroundTransparency = 1
leaderboardTitle.Font = Enum.Font.GothamBold
leaderboardTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
leaderboardTitle.TextScaled = true
leaderboardTitle.Text = "BEST FIND THIS WEEK"
leaderboardTitle.Parent = leaderboardFrame

local leaderboardList = Instance.new("TextLabel")
leaderboardList.Size = UDim2.new(1, -10, 1, -40)
leaderboardList.Position = UDim2.new(0, 5, 0, 35)
leaderboardList.BackgroundTransparency = 1
leaderboardList.Font = Enum.Font.Gotham
leaderboardList.TextColor3 = Color3.fromRGB(220, 220, 220)
leaderboardList.TextScaled = true
leaderboardList.TextWrapped = true
leaderboardList.TextXAlignment = Enum.TextXAlignment.Left
leaderboardList.TextYAlignment = Enum.TextYAlignment.Top
leaderboardList.Text = "Loading..."
leaderboardList.Parent = leaderboardFrame

dailyButton.Activated:Connect(function()
	requestClaimDaily:FireServer()
end)

leaderboardButton.Activated:Connect(function()
	leaderboardFrame.Visible = not leaderboardFrame.Visible
	if leaderboardFrame.Visible then
		requestLeaderboard:FireServer()
	end
end)

dailyRefused.OnClientEvent:Connect(function(reason)
	dailyButton.Text = reason
	task.delay(3, function()
		dailyButton.Text = "CLAIM DAILY"
	end)
end)

leaderboardResult.OnClientEvent:Connect(function(topFinds)
	if #topFinds == 0 then
		leaderboardList.Text = "No finds yet this week."
		return
	end

	local lines = {}
	for rank, entry in ipairs(topFinds) do
		table.insert(lines, rank .. ". " .. (entry.displayName or "?") .. " — " .. (entry.itemName or "?") .. " (" .. entry.value .. ")")
	end
	leaderboardList.Text = table.concat(lines, "\n")
end)
