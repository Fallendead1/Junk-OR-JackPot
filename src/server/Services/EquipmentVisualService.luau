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

-- useMotor6D is for the shovel only -- a Motor6D's C0 can be tweened for the
-- per-click swing (§4.3), which a plain WeldConstraint can't do (it just
-- locks whatever relative CFrame existed at creation). The detector never
-- swings, so it stays on the simpler WeldConstraint.
local function attachCarriedModel(character, model, bodyPart, offset, useMotor6D)
	local handle = model:FindFirstChild("Handle")
	if not handle or not bodyPart then
		model:Destroy()
		return
	end

	model.Parent = character
	handle.CFrame = bodyPart.CFrame * offset

	if useMotor6D then
		local motor = Instance.new("Motor6D")
		motor.Name = "CarryMotor"
		motor.Part0 = bodyPart
		motor.Part1 = handle
		motor.C0 = offset
		motor.Parent = handle
	else
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bodyPart
		weld.Part1 = handle
		weld.Parent = handle
	end
end

local function clearCarried(character, tag)
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute(tag) then
			child:Destroy()
		end
	end
end

-- §5.3/Step 10: walkSpeedBonus is a fraction (0.05 = +5%), cached on the
-- profile whenever the equipped shovel changes. 16 is Roblox's own default
-- Humanoid.WalkSpeed, not a game-balance number -- it's the platform's
-- baseline the bonus applies on top of.
local BASE_WALK_SPEED = 16

local function applyWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local profile = PlayerDataService.GetProfile(player)
	if not humanoid or not profile then
		return
	end

	humanoid.WalkSpeed = BASE_WALK_SPEED * (1 + profile.Data.walkSpeedBonus)
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
			attachCarriedModel(character, carryModel, torso, SHOVEL_BACK_OFFSET, true)
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

-- Called by EquipmentShopService once a player's equipped tier actually
-- changes (buy or plain re-equip).
function EquipmentVisualService.RefreshForPlayer(player)
	equipVisuals(player)
	applyWalkSpeed(player)
end

function EquipmentVisualService.Init()
	PlayerDataService.ProfileLoaded.Event:Connect(function(player)
		equipVisuals(player)
		applyWalkSpeed(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2) -- let the rig's body parts finish loading
			applyWalkSpeed(player)
			equipVisuals(player)
		end)
	end)
end

return EquipmentVisualService
