local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local announce = remotes:WaitForChild("Announce")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AnnounceUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Toast fallback: always shows the message on-screen, regardless of whether
-- this place's chat system accepts DisplaySystemMessage below.
local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "ToastLabel"
toastLabel.Size = UDim2.new(1, -40, 0, 40)
toastLabel.Position = UDim2.new(0, 20, 0, 130)
toastLabel.BackgroundTransparency = 1
toastLabel.Font = Enum.Font.GothamBold
toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
toastLabel.TextStrokeTransparency = 0.3
toastLabel.TextScaled = true
toastLabel.TextXAlignment = Enum.TextXAlignment.Left
toastLabel.Text = ""
toastLabel.Parent = screenGui

-- GDD §9.1: Mythic gets a 2s gold screen border.
local goldBorder = Instance.new("Frame")
goldBorder.Name = "GoldBorder"
goldBorder.Size = UDim2.fromScale(1, 1)
goldBorder.BackgroundTransparency = 1
goldBorder.Visible = false
goldBorder.ZIndex = 10
goldBorder.Parent = screenGui

local goldStroke = Instance.new("UIStroke")
goldStroke.Color = Color3.fromRGB(255, 215, 0)
goldStroke.Thickness = 14
goldStroke.Parent = goldBorder

-- GDD §9.1: Relic gets a full-screen flash (cross-server relay + Hall of
-- Finds are Phase 14 / post-launch; this is the local-server visual only).
local relicFlash = Instance.new("Frame")
relicFlash.Name = "RelicFlash"
relicFlash.Size = UDim2.fromScale(1, 1)
relicFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
relicFlash.BackgroundTransparency = 1
relicFlash.Visible = false
relicFlash.ZIndex = 11
relicFlash.Parent = screenGui

-- TODO: no sound assets exist yet for Epic/Mythic/Relic (GDD doesn't specify
-- asset ids — that's a content choice for the owner, not something to guess
-- at). Wire Sound instances here once real SoundIds are chosen.

local function postToChat(message)
	local ok = pcall(function()
		local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		channel:DisplaySystemMessage(message)
	end)

	toastLabel.Text = message
	task.delay(5, function()
		if toastLabel.Text == message then
			toastLabel.Text = ""
		end
	end)
end

announce.OnClientEvent:Connect(function(message, tier)
	postToChat(message)

	if tier == "Mythic" then
		goldBorder.Visible = true
		task.delay(2, function()
			goldBorder.Visible = false
		end)
	elseif tier == "Relic" then
		relicFlash.Visible = true
		relicFlash.BackgroundTransparency = 0.2
		local tween = TweenService:Create(relicFlash, TweenInfo.new(1), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			relicFlash.Visible = false
		end)
	end
end)
