local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ShovelTable = require(ReplicatedStorage.Modules.ShovelTable)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- Purely cosmetic: gives the player a held Tool matching their real
-- shovelTier so the shovel they bought is actually visible, instead of only
-- affecting dig time/luck behind the scenes. Digging itself still happens
-- through the zone's ProximityPrompt (see DigService) -- holding the tool
-- doesn't gate or change that in any way.
local ShovelToolService = {}

local shovelToolsFolder = ServerStorage:WaitForChild("ShovelTools")

local function equipShovelForPlayer(player, tier)
	local shovelName = ShovelTable[tier] and ShovelTable[tier].name
	if not shovelName then
		return
	end

	local template = shovelToolsFolder:FindFirstChild(shovelName .. " Shovel")
	if not template then
		return
	end

	-- Remove any shovel tool this player is already holding, in the backpack
	-- or currently equipped, before giving the new one.
	for _, container in ipairs({ player.Backpack, player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("IsShovelTool") then
					child:Destroy()
				end
			end
		end
	end

	local clone = template:Clone()
	clone:SetAttribute("IsShovelTool", true)
	clone.Parent = player.Backpack

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:EquipTool(clone)
	end
end

local function equipCurrentShovel(player)
	local profile = PlayerDataService.GetProfile(player)
	if profile then
		equipShovelForPlayer(player, profile.Data.shovelTier)
	end
end

-- Called by UpgradeService right after a shovel purchase succeeds.
function ShovelToolService.OnShovelUpgraded(player, tier)
	equipShovelForPlayer(player, tier)
end

function ShovelToolService.Init()
	PlayerDataService.ProfileLoaded.Event:Connect(equipCurrentShovel)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			equipCurrentShovel(player)
		end)
	end)
end

return ShovelToolService
