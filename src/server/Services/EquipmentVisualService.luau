local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- dig-minigame-spec.md §6: always-visible carry state for the equipped
-- shovel (back) and detector (hip), driven purely by the player's real
-- equippedShovelTier/equippedDetectorTier -- no Backpack, no Equip. The
-- active two-hand hold during the minigame itself is a later step.
local EquipmentVisualService = {}

local shovelToolsFolder = ServerStorage:WaitForChild("ShovelTools")
local detectorToolsFolder = ServerStorage:WaitForChild("DetectorTools")

-- §6.1 attachment offsets, local to the named body part. R15 part names
-- first, R6 fallback -- matching the same fallback LumpService already uses
-- for hand-attaching a dug lump.
local SHOVEL_BACK_OFFSET = CFrame.new(0.2, 0.3, -0.5)
local DETECTOR_SIDE_OFFSET = CFrame.new(0, -0.5, 0)

local function findTorso(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function findLeftArm(character)
	return character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
end

-- Templates are stored as Tools (so the same piece can later be equipped to
-- the hand during the minigame). For the static carry state we don't want
-- Roblox's own Tool-equip-to-hand behavior fighting our weld, so the clone is
-- unpacked into a plain Model first.
local function toolToCarryModel(toolClone, tag)
	local model = Instance.new("Model")
	model.Name = toolClone.Name
	model:SetAttribute(tag, true)

	for _, child in ipairs(toolClone:GetChildren()) do
		child.Parent = model
	end
	toolClone:Destroy()

	return model
end

local function attachCarriedModel(character, model, bodyPart, offset)
	local handle = model:FindFirstChild("Handle")
	if not handle or not bodyPart then
		model:Destroy()
		return
	end

	model.Parent = character
	handle.CFrame = bodyPart.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = handle
	weld.Parent = handle
end

local function clearCarried(character, tag)
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute(tag) then
			child:Destroy()
		end
	end
end

local function equipVisuals(player)
	local character = player.Character
	if not character then
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	clearCarried(character, "IsCarriedShovel")
	clearCarried(character, "IsCarriedDetector")

	local shovelInfo = Config.SHOVEL_TIERS[profile.Data.equippedShovelTier]
	local torso = findTorso(character)
	if shovelInfo and torso then
		local template = shovelToolsFolder:FindFirstChild(shovelInfo.name)
		if template then
			local carryModel = toolToCarryModel(template:Clone(), "IsCarriedShovel")
			attachCarriedModel(character, carryModel, torso, SHOVEL_BACK_OFFSET)
		end
	end

	local detectorInfo = Config.DETECTOR_TIERS[profile.Data.equippedDetectorTier]
	local leftArm = findLeftArm(character)
	if detectorInfo and leftArm then
		local template = detectorToolsFolder:FindFirstChild(detectorInfo.name)
		if template then
			local carryModel = toolToCarryModel(template:Clone(), "IsCarriedDetector")
			attachCarriedModel(character, carryModel, leftArm, DETECTOR_SIDE_OFFSET)
		end
	end
end

-- Called by whatever purchase/equip flow lands later (System 5/7's
-- RequestEquipTool) once a player's equipped tier actually changes.
function EquipmentVisualService.RefreshForPlayer(player)
	equipVisuals(player)
end

function EquipmentVisualService.Init()
	PlayerDataService.ProfileLoaded.Event:Connect(equipVisuals)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2) -- let the rig's body parts finish loading
			equipVisuals(player)
		end)
	end)
end

return EquipmentVisualService
