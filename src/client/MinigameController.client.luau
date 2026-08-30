local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Modules.Config)

-- dig-minigame-spec.md Step 6: the click-to-fill bar. The bar shown here is
-- a preview only -- the server tracks its own authoritative value and is
-- what actually decides success/fail (MinigameService).
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local minigameStart = remotes:WaitForChild("MinigameStart")
local requestMinigameClick = remotes:WaitForChild("RequestMinigameClick")
local requestMinigameSuccess = remotes:WaitForChild("RequestMinigameSuccess")
local requestMinigameFail = remotes:WaitForChild("RequestMinigameFail")
local failConfirmed = remotes:WaitForChild("FailConfirmed")

local function hex(value)
	return Color3.fromHex(value)
end

-- §4.1
local RARITY_TEXT = {
	Scrap = "SCRAP FIND",
	Common = "COMMON FIND!",
	Good = "GOOD FIND!",
	Rare = "RARE FIND!!",
	Epic = "EPIC FIND!!!",
	Mythic = "⚡ MYTHIC FIND ⚡",
	Relic = "🔴 RELIC FOUND 🔴",
}
-- Matches the color DetectorService already showed on the find spot itself
-- (§2.2's BrickColor table), so the label doesn't introduce a second palette.
local RARITY_LABEL_COLOR = {
	Scrap = BrickColor.new("Medium stone grey").Color,
	Common = BrickColor.new("White").Color,
	Good = BrickColor.new("Bright green").Color,
	Rare = BrickColor.new("Bright blue").Color,
	Epic = BrickColor.new("Bright violet").Color,
	Mythic = BrickColor.new("Bright yellow").Color,
	Relic = BrickColor.new("Bright red").Color,
}
-- §4.1's bar gradient colors (left -> right per rarity).
local RARITY_FILL_COLORS = {
	Scrap = { hex("#4A4A4A"), hex("#6B6B6B") },
	Common = { hex("#AAAAAA"), hex("#FFFFFF") },
	Good = { hex("#2D8C2D"), hex("#4EC94E") },
	Rare = { hex("#1A4FAF"), hex("#3B82F6") },
	Epic = { hex("#6B21A8"), hex("#A855F7") },
	Mythic = { hex("#B45309"), hex("#F59E0B") },
	Relic = { hex("#991B1B"), hex("#EF4444") },
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MinigameUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -60)
container.Size = UDim2.fromOffset(500, 90)
container.BackgroundTransparency = 1
container.Visible = false
container.Parent = screenGui

local rarityLabel = Instance.new("TextLabel")
rarityLabel.Name = "RarityLabel"
rarityLabel.Size = UDim2.new(1, 0, 0, 26)
rarityLabel.BackgroundTransparency = 1
rarityLabel.Font = Enum.Font.GothamBold
rarityLabel.TextSize = 20
rarityLabel.TextStrokeTransparency = 0.4
rarityLabel.Text = ""
rarityLabel.Parent = container

local barContainer = Instance.new("Frame")
barContainer.Name = "Bar"
barContainer.Position = UDim2.new(0, 0, 0, 30)
barContainer.Size = UDim2.fromOffset(500, 40)
barContainer.BackgroundColor3 = Color3.fromHex("#1A1A1A")
barContainer.ClipsDescendants = true
barContainer.Parent = container

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 8)
barCorner.Parent = barContainer

local fillFrame = Instance.new("Frame")
fillFrame.Name = "Fill"
fillFrame.Size = UDim2.new(1, 0, 1, 0)
fillFrame.BorderSizePixel = 0
fillFrame.Parent = barContainer

local fillGradient = Instance.new("UIGradient")
fillGradient.Parent = fillFrame

-- §4.1: "a white diagonal sweep, looping every 2s, 10% opacity"
local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.AnchorPoint = Vector2.new(0.5, 0.5)
shine.Size = UDim2.new(0, 30, 2, 0)
shine.Rotation = 20
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.BackgroundTransparency = 0.9
shine.BorderSizePixel = 0
shine.Parent = barContainer

-- §4.1: small shovel marker riding the fill edge, and the goal line at the end.
local shovelIcon = Instance.new("TextLabel")
shovelIcon.Name = "ShovelIcon"
shovelIcon.AnchorPoint = Vector2.new(0.5, 0.5)
shovelIcon.Size = UDim2.fromOffset(24, 24)
shovelIcon.BackgroundTransparency = 1
shovelIcon.Text = "⛏️"
shovelIcon.TextScaled = true
shovelIcon.Parent = barContainer

local goalMarker = Instance.new("Frame")
goalMarker.Name = "GoalMarker"
goalMarker.AnchorPoint = Vector2.new(1, 0.5)
goalMarker.Position = UDim2.new(1, -2, 0.5, 0)
goalMarker.Size = UDim2.new(0, 3, 1, 0)
goalMarker.BackgroundColor3 = Color3.new(1, 1, 1)
goalMarker.BorderSizePixel = 0
goalMarker.Parent = barContainer

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Position = UDim2.new(0, 0, 0, 74)
hintLabel.Size = UDim2.new(1, 0, 0, 20)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextTransparency = 0.2
hintLabel.Text = "CLICK TO DIG!"
hintLabel.Parent = container

local shineTween = TweenService:Create(
	shine,
	TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false),
	{ Position = UDim2.new(1, 30, 0.5, 0) }
)

local hintPulseTween = TweenService:Create(
	hintLabel,
	TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ TextTransparency = 0.7 }
)

local currentMinigame = nil
local heartbeatConn = nil
local clickCount = 0

local function updateBarVisual(barValue)
	fillFrame.Size = UDim2.new(barValue, 0, 1, 0)
	shovelIcon.Position = UDim2.new(barValue, 0, 0.5, 0)
end

local function endMinigameUI()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	shineTween:Cancel()
	hintPulseTween:Cancel()
	container.Visible = false
	currentMinigame = nil
end

minigameStart.OnClientEvent:Connect(function(payload)
	currentMinigame = {
		findSpotId = payload.findSpotId,
		rarity = payload.rarity,
		decayPerSecond = payload.decayPerSecond,
		fillPerClick = payload.fillPerClick,
		barValue = Config.BAR_START_VALUE,
	}
	clickCount = 0

	rarityLabel.Text = RARITY_TEXT[payload.rarity] or string.upper(payload.rarity)
	rarityLabel.TextColor3 = RARITY_LABEL_COLOR[payload.rarity] or Color3.new(1, 1, 1)

	local colors = RARITY_FILL_COLORS[payload.rarity] or RARITY_FILL_COLORS.Scrap
	fillGradient.Color = ColorSequence.new(colors[1], colors[2])

	hintLabel.Visible = true
	hintLabel.TextTransparency = 0.2
	hintPulseTween:Play()

	updateBarVisual(Config.BAR_START_VALUE)
	container.Visible = true

	if heartbeatConn then
		heartbeatConn:Disconnect()
	end
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if not currentMinigame then
			return
		end

		currentMinigame.barValue = math.clamp(currentMinigame.barValue - currentMinigame.decayPerSecond * deltaTime, 0, 1)
		updateBarVisual(currentMinigame.barValue)

		if currentMinigame.barValue <= 0 then
			requestMinigameFail:FireServer(currentMinigame.findSpotId)
			endMinigameUI()
		end
	end)

	shineTween:Play()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not currentMinigame then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	requestMinigameClick:FireServer(currentMinigame.findSpotId)
	currentMinigame.barValue = math.clamp(currentMinigame.barValue + currentMinigame.fillPerClick, 0, 1)
	updateBarVisual(currentMinigame.barValue)

	clickCount += 1
	if clickCount == 3 then
		hintPulseTween:Cancel()
		TweenService:Create(hintLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end

	if currentMinigame.barValue >= 1.0 then
		requestMinigameSuccess:FireServer(currentMinigame.findSpotId)
		endMinigameUI()
	end
end)

failConfirmed.OnClientEvent:Connect(function()
	endMinigameUI()
end)
