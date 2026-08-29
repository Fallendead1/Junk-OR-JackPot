local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)
local UIJuice = require(ReplicatedStorage.Modules.UIJuice)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestBuyBin = remotes:WaitForChild("RequestBuyBin")
local binUpdated = remotes:WaitForChild("BinUpdated")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BinUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local binButton = Instance.new("TextButton")
binButton.Name = "BinButton"
binButton.Text = "BIN"
binButton.Size = UDim2.fromOffset(160, 40)
binButton.Position = UDim2.new(0, 190, 0, 20)
binButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
binButton.TextColor3 = Color3.fromRGB(255, 255, 255)
binButton.TextScaled = true
binButton.Parent = screenGui

local binFrame = Instance.new("Frame")
binFrame.Name = "BinFrame"
binFrame.Size = UDim2.fromScale(0.6, 0.7)
binFrame.Position = UDim2.fromScale(0.2, 0.1)
binFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
binFrame.Visible = false
binFrame.Parent = screenGui

local binTitle = Instance.new("TextLabel")
binTitle.Name = "Title"
binTitle.Size = UDim2.new(1, -40, 0, 40)
binTitle.BackgroundTransparency = 1
binTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
binTitle.Font = Enum.Font.GothamBold
binTitle.TextScaled = true
binTitle.Text = "BLIND-SALE BIN"
binTitle.Parent = binFrame

local binCloseButton = Instance.new("TextButton")
binCloseButton.Text = "X"
binCloseButton.Size = UDim2.fromOffset(30, 30)
binCloseButton.Position = UDim2.new(1, -35, 0, 5)
binCloseButton.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
binCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
binCloseButton.Parent = binFrame

UIJuice.MakeButtonJuicy(binButton)
UIJuice.MakeButtonJuicy(binCloseButton)

local binScroll = Instance.new("ScrollingFrame")
binScroll.Size = UDim2.new(1, 0, 1, -40)
binScroll.Position = UDim2.new(0, 0, 0, 40)
binScroll.BackgroundTransparency = 1
binScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
binScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
binScroll.ScrollBarThickness = 8
binScroll.Parent = binFrame

local binList = Instance.new("UIListLayout")
binList.Padding = UDim.new(0, 4)
binList.Parent = binScroll

binButton.Activated:Connect(function()
	binFrame.Visible = not binFrame.Visible
	if binFrame.Visible then
		UIJuice.PopIn(binFrame)
	end
end)

binCloseButton.Activated:Connect(function()
	binFrame.Visible = false
end)

local function clearRows()
	for _, child in ipairs(binScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- The payload here is exactly what the seller saw: hints, zone, price,
-- seller name. Nothing about what's actually inside the lump.
binUpdated.OnClientEvent:Connect(function(entries)
	clearRows()

	for _, entry in ipairs(entries) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 60)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		row.Parent = binScroll

		local hintsLabel = Instance.new("TextLabel")
		hintsLabel.Size = UDim2.new(0.5, 0, 1, 0)
		hintsLabel.BackgroundTransparency = 1
		hintsLabel.Font = Enum.Font.Gotham
		hintsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		hintsLabel.TextScaled = true
		hintsLabel.TextXAlignment = Enum.TextXAlignment.Left
		hintsLabel.Text = string.upper(entry.hints.Weight) .. " · " .. string.upper(entry.hints.Temperature) .. " · " .. string.upper(entry.hints.Sheen)
			.. "\n" .. ZoneTable[entry.zone].name .. " — from " .. entry.sellerName
		hintsLabel.Parent = row

		local buyButton = Instance.new("TextButton")
		buyButton.Size = UDim2.new(0.4, 0, 0.8, 0)
		buyButton.Position = UDim2.new(0.58, 0, 0.1, 0)
		buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyButton.TextScaled = true
		buyButton.Parent = row

		if entry.sellerId == player.UserId then
			buyButton.Text = "YOUR LUMP"
			buyButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
			buyButton.Active = false
		else
			buyButton.Text = "BUY — " .. entry.price
			buyButton.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
			buyButton.Activated:Connect(function()
				requestBuyBin:FireServer(entry.binEntryId)
			end)
			UIJuice.MakeButtonJuicy(buyButton)
		end
	end
end)
