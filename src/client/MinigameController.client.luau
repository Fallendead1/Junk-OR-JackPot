local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)
local SoundTable = require(ReplicatedStorage.Modules.SoundTable)

-- dig-minigame-spec.md Step 6: the click-to-fill bar. The bar shown here is
-- a preview only -- the server tracks its own authoritative value and is
-- what actually decides success/fail (MinigameService).
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local minigameStart = remotes:WaitForChild("MinigameStart")
local minigameWin = remotes:WaitForChild("MinigameWin")
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

-- §4.3.5: "the filled portion briefly brightens to white 30% then back."
-- A separate overlay rather than fighting the gradient's own Color property.
local fillFlash = Instance.new("Frame")
fillFlash.Name = "Flash"
fillFlash.Size = UDim2.new(1, 0, 1, 0)
fillFlash.BackgroundColor3 = Color3.new(1, 1, 1)
fillFlash.BackgroundTransparency = 1
fillFlash.BorderSizePixel = 0
fillFlash.Parent = fillFrame

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

-- §4.3.2: screen shake. Applied on top of whatever the default camera script
-- is already doing, at a render priority just after it, so it doesn't fight
-- for control of CameraType/CFrame the way setting it directly did during
-- Step 5 testing.
local shakeOffset = Vector3.new(0, 0, 0)
RunService:BindToRenderStep("MinigameShake", Enum.RenderPriority.Camera.Value + 1, function()
	if shakeOffset.Magnitude > 0.0001 then
		local camera = Workspace.CurrentCamera
		camera.CFrame = camera.CFrame * CFrame.new(shakeOffset)
	end
end)

local function triggerScreenShake()
	task.spawn(function()
		local startOffset = Vector3.new(
			(math.random() * 2 - 1) * Config.SCREEN_SHAKE_MAGNITUDE,
			(math.random() * 2 - 1) * Config.SCREEN_SHAKE_MAGNITUDE,
			0
		)
		local elapsed = 0
		while elapsed < Config.SCREEN_SHAKE_DURATION do
			local dt = task.wait()
			elapsed += dt
			local alpha = math.clamp(elapsed / Config.SCREEN_SHAKE_DURATION, 0, 1)
			shakeOffset = startOffset:Lerp(Vector3.new(0, 0, 0), alpha)
		end
		shakeOffset = Vector3.new(0, 0, 0)
	end)
end

-- §4.3.1: shovel swing. Tweens the Motor6D EquipmentVisualService set up for
-- the carried shovel -- doesn't queue, a new click just restarts it, matching
-- "a new click interrupts and restarts the animation."
local swingTween = nil
local function triggerSwing()
	local character = player.Character
	if not character then
		return
	end

	local shovelModel
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("IsCarriedShovel") then
			shovelModel = child
			break
		end
	end
	local motor = shovelModel and shovelModel:FindFirstChild("Handle") and shovelModel.Handle:FindFirstChild("CarryMotor")
	if not motor then
		return
	end

	if swingTween then
		swingTween:Cancel()
	end

	local restC0 = motor.C0
	motor.C0 = restC0 -- reset in case a prior swing was interrupted mid-tween
	local downTween = TweenService:Create(
		motor,
		TweenInfo.new(Config.SWING_DOWN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = restC0 * CFrame.Angles(math.rad(-40), 0, 0) }
	)
	downTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			swingTween = TweenService:Create(
				motor,
				TweenInfo.new(Config.SWING_RETURN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = restC0 }
			)
			swingTween:Play()
		end
	end)
	swingTween = downTween
	swingTween:Play()
end

-- §4.3.3: dirt particle burst at the find spot.
local function triggerDirtBurst(findSpotId)
	local part = Workspace:FindFirstChild("FindSpots") and Workspace.FindSpots:FindFirstChild("FindSpot_" .. findSpotId)
	if not part then
		return
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromHex("#8B6914"))
	emitter.Lifetime = NumberRange.new(0.4)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(8)
	task.delay(0.5, function()
		if emitter.Parent then
			emitter:Destroy()
		end
	end)
end

-- §4.3.4: click sound, pitch varied per play so it doesn't sound repetitive.
-- Silently does nothing if SoundTable.Dig is left blank.
local function triggerClickSound()
	local soundId = SoundTable.Dig
	if not soundId or soundId == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.6
	sound.PlaybackSpeed = math.random(95, 108) / 100
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function triggerFillFlash()
	fillFlash.BackgroundTransparency = 0.7
	TweenService:Create(fillFlash, TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play()
end

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

-- §3.2 / §4.4 / §4.5's camera zoom: 70 while searching, 65 during the
-- minigame. Only the FOV beat of the full commit/return transition -- the
-- detector-to-hip and shovel-to-two-hand-hold parts of §3.2 aren't built
-- (the shovel stays on the back and swings in place instead, see Step 7).
local DEFAULT_FOV = 70
local MINIGAME_FOV = 65

local function tweenFOV(target)
	TweenService:Create(Workspace.CurrentCamera, TweenInfo.new(0.3), { FieldOfView = target }):Play()
end

local function findSpotPart(findSpotId)
	local folder = Workspace:FindFirstChild("FindSpots")
	return folder and folder:FindFirstChild("FindSpot_" .. findSpotId)
end

-- §4.4: win particle fountain + sound + camera zoom-out + the spot shrinking
-- away. The server grants the actual item and fires the existing
-- RevealResult ~0.5s after MinigameWin, which the existing KEEP/SELL panel
-- already reacts to -- nothing new needed here for that part.
local function playWinSequence(rarity, findSpotId)
	tweenFOV(DEFAULT_FOV)

	local part = findSpotPart(findSpotId)
	if part then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(RARITY_LABEL_COLOR[rarity] or Color3.new(1, 1, 1))
		emitter.Lifetime = NumberRange.new(1.2)
		emitter.Speed = NumberRange.new(10, 16)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.Rate = 0
		emitter.Parent = part
		emitter:Emit(40)
		task.delay(1.3, function()
			if emitter.Parent then
				emitter:Destroy()
			end
		end)

		task.delay(0.3, function()
			if part.Parent then
				TweenService:Create(part, TweenInfo.new(0.2), { Size = Vector3.new(0.01, 0.01, 0.01) }):Play()
			end
		end)
	end

	local soundId = SoundTable[rarity]
	if soundId and soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

-- §4.5: bar shakes/flashes red, slides away, camera zooms out, then the spot
-- sinks and fades with a small dust puff. Triggered from local detection
-- (the moment our own bar hits zero) rather than waiting on FailConfirmed --
-- there's nothing at stake either way, so responsiveness wins here, unlike
-- the win case which waits for the server's say-so.
local function playFailSequence(findSpotId)
	local originalPosition = barContainer.Position
	-- Reuses the same white Flash overlay from the per-click feedback, just
	-- tinted red and left visible instead of pulsing once -- avoids fighting
	-- the UIGradient on Fill directly, which owns Fill's actual rendered color.
	fillFlash.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fillFlash.BackgroundTransparency = 0.4
	task.spawn(function()
		for _ = 1, 3 do
			TweenService:Create(barContainer, TweenInfo.new(0.05), { Position = originalPosition + UDim2.fromOffset(-10, 0) }):Play()
			task.wait(0.1)
			TweenService:Create(barContainer, TweenInfo.new(0.05), { Position = originalPosition + UDim2.fromOffset(10, 0) }):Play()
			task.wait(0.1)
		end
		TweenService:Create(barContainer, TweenInfo.new(0.05), { Position = originalPosition }):Play()
	end)

	tweenFOV(DEFAULT_FOV)

	local part = findSpotPart(findSpotId)
	if part then
		task.delay(0.3, function()
			if not part.Parent then
				return
			end

			local dust = Instance.new("ParticleEmitter")
			dust.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
			dust.Lifetime = NumberRange.new(0.6)
			dust.Speed = NumberRange.new(2, 5)
			dust.Rate = 0
			dust.Parent = part
			dust:Emit(12)
			task.delay(0.8, function()
				if dust.Parent then
					dust:Destroy()
				end
			end)

			TweenService:Create(part, TweenInfo.new(0.4), {
				Position = part.Position - Vector3.new(0, 2, 0),
				Transparency = 1,
			}):Play()
		end)
	end

	local soundId = SoundTable.Scrap -- §4.5: "use Reveal-Scrap sound as placeholder"
	if soundId and soundId ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
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

	fillFlash.BackgroundColor3 = Color3.new(1, 1, 1) -- reset in case the last minigame ended in a fail (which tints this red)
	fillFlash.BackgroundTransparency = 1

	updateBarVisual(Config.BAR_START_VALUE)
	container.Visible = true
	tweenFOV(MINIGAME_FOV)

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
			local findSpotId = currentMinigame.findSpotId
			requestMinigameFail:FireServer(findSpotId)
			endMinigameUI()
			playFailSequence(findSpotId)
		end
	end)

	shineTween:Play()
end)

minigameWin.OnClientEvent:Connect(function(payload)
	playWinSequence(payload.rarity, payload.findSpotId)
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

	-- §4.3: every accepted click fires all of these simultaneously.
	triggerSwing()
	triggerScreenShake()
	triggerDirtBurst(currentMinigame.findSpotId)
	triggerClickSound()
	triggerFillFlash()

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
