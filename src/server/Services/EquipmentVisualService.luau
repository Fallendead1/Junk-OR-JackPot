local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Modules.Config)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local DigService = require(ServerScriptService.Services.DigService)

-- dig-minigame-spec.md §6: the equipped shovel and detector are always
-- visible, welded to the character rather than living in a Backpack. Both
-- now swap between two poses each (a Motor6D's C0 can be tweened, which is
-- why neither uses a plain WeldConstraint anymore):
--   shovel:   back (idle) <-> digging (held out front, during the minigame)
--   detector: hip (idle)  <-> held (swept out front, while inside a zone)
local EquipmentVisualService = {}

local shovelToolsFolder = ServerStorage:WaitForChild("ShovelTools")
local detectorToolsFolder = ServerStorage:WaitForChild("DetectorTools")

-- All four offsets are relative to the torso, so switching pose is just
-- re-tweening the same Motor6D's C0 -- no re-parenting needed.
local SHOVEL_BACK_OFFSET = CFrame.new(0.3, 0.8, -0.3) * CFrame.Angles(math.rad(15), 0, math.rad(20))
local SHOVEL_DIG_OFFSET = CFrame.new(0.3, -0.4, -1.3) * CFrame.Angles(math.rad(70), 0, math.rad(15))
local DETECTOR_CARRY_OFFSET = CFrame.new(-0.7, -0.7, 0.2) * CFrame.Angles(math.rad(-10), 0, 0)
local DETECTOR_HELD_OFFSET = CFrame.new(0.1, -0.2, -0.9) * CFrame.Angles(0, 0, math.rad(95))

local POSE_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- How often each player's zone status is rechecked to decide whether the
-- detector should be held or carried. Not spec-derived -- just how often
-- this cosmetic check runs; no gameplay math depends on it.
local ZONE_CHECK_INTERVAL = 0.5

local function findTorso(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

-- Templates are stored as Tools (so the same piece can also be equipped to
-- the hand elsewhere later). For the always-visible carry state we don't
-- want Roblox's own Tool-equip-to-hand behavior fighting our weld, so the
-- clone is unpacked into a plain Model first.
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

local function attachCarriedModel(character, model, torso, offset)
	local handle = model:FindFirstChild("Handle")
	if not handle or not torso then
		model:Destroy()
		return
	end

	model.Parent = character
	handle.CFrame = torso.CFrame * offset

	local motor = Instance.new("Motor6D")
	motor.Name = "CarryMotor"
	motor.Part0 = torso
	motor.Part1 = handle
	motor.C0 = offset
	motor.Parent = handle
end

local function clearCarried(character, tag)
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute(tag) then
			child:Destroy()
		end
	end
end

local function findCarriedMotor(character, tag)
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute(tag) then
			local handle = child:FindFirstChild("Handle")
			return handle and handle:FindFirstChild("CarryMotor")
		end
	end
	return nil
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

	local torso = findTorso(character)
	if not torso then
		return
	end

	local shovelInfo = Config.SHOVEL_TIERS[profile.Data.equippedShovelTier]
	if shovelInfo then
		local template = shovelToolsFolder:FindFirstChild(shovelInfo.name)
		if template then
			local carryModel = toolToCarryModel(template:Clone(), "IsCarriedShovel")
			attachCarriedModel(character, carryModel, torso, SHOVEL_BACK_OFFSET)
		end
	end

	local detectorInfo = Config.DETECTOR_TIERS[profile.Data.equippedDetectorTier]
	if detectorInfo then
		local template = detectorToolsFolder:FindFirstChild(detectorInfo.name)
		if template then
			local carryModel = toolToCarryModel(template:Clone(), "IsCarriedDetector")
			carryModel:SetAttribute("Held", false)
			attachCarriedModel(character, carryModel, torso, DETECTOR_CARRY_OFFSET)
		end
	end
end

-- Called on every accepted commit (start digging) and again when the
-- minigame ends (win or fail) to bring the shovel back to the idle pose.
function EquipmentVisualService.SetShovelDigging(player, isDigging)
	local character = player.Character
	local motor = character and findCarriedMotor(character, "IsCarriedShovel")
	if not motor then
		return
	end

	TweenService:Create(motor, POSE_TWEEN_INFO, { C0 = isDigging and SHOVEL_DIG_OFFSET or SHOVEL_BACK_OFFSET }):Play()
end

-- Held while standing in a zone, carried otherwise -- also forced to
-- "carried" for the duration of a minigame (§3.2: "detector tweens back to
-- the player's side"), which MinigameService drives directly rather than
-- this service polling minigame state (avoids a circular require).
function EquipmentVisualService.SetDetectorHeld(player, isHeld)
	local character = player.Character
	if not character then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("IsCarriedDetector") then
			if child:GetAttribute("Held") == isHeld then
				return -- already in the requested pose
			end
			child:SetAttribute("Held", isHeld)

			local handle = child:FindFirstChild("Handle")
			local motor = handle and handle:FindFirstChild("CarryMotor")
			if motor then
				TweenService:Create(motor, POSE_TWEEN_INFO, { C0 = isHeld and DETECTOR_HELD_OFFSET or DETECTOR_CARRY_OFFSET }):Play()
			end
			return
		end
	end
end

-- Re-evaluates zone status immediately rather than waiting for the next
-- ZONE_CHECK_INTERVAL tick -- called right after a minigame ends so the
-- detector doesn't sit in "carried" for up to half a second longer than it
-- needs to if the player is still standing in a zone.
function EquipmentVisualService.RefreshDetectorForPlayer(player)
	local character = player.Character
	local profile = PlayerDataService.GetProfile(player)
	if not character or not profile then
		return
	end

	local inZone = DigService.GetPlayerZone(player, profile) ~= nil
	EquipmentVisualService.SetDetectorHeld(player, inZone)
end

-- Called by EquipmentShopService once a player's equipped tier actually
-- changes (buy or plain re-equip).
function EquipmentVisualService.RefreshForPlayer(player)
	equipVisuals(player)
	applyWalkSpeed(player)
end

local function zoneCheckLoop()
	while true do
		task.wait(ZONE_CHECK_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and not character:GetAttribute("InMinigame") then
				local profile = PlayerDataService.GetProfile(player)
				if profile then
					local inZone = DigService.GetPlayerZone(player, profile) ~= nil
					EquipmentVisualService.SetDetectorHeld(player, inZone)
				end
			end
		end
	end
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

	task.spawn(zoneCheckLoop)
end

return EquipmentVisualService
