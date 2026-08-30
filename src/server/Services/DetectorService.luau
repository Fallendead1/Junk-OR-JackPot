local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local DigService = require(ServerScriptService.Services.DigService)
local LumpService = require(ServerScriptService.Services.LumpService)
local RevealService = require(ServerScriptService.Services.RevealService)

-- dig-minigame-spec.md System 2: the roaming metal-detector scan cycle.
-- Step 4 of that spec's build order -- spawns find spots with placeholder
-- parts, assigns attributes, and despawns them after FIND_DESPAWN_TIME.
-- The commit trigger (clicking a spot to start the minigame) is Step 5, not
-- built here.
local DetectorService = {}

local FIND_SIZE = Vector3.new(0.3, 2.0, 2.0)

-- Roblox's own literal names, matching the spec's table exactly (§2.2).
local RARITY_COLOR_NAME = {
	Scrap = "Medium stone grey",
	Common = "White",
	Good = "Bright green",
	Rare = "Bright blue",
	Epic = "Bright violet",
	Mythic = "Bright yellow",
	Relic = "Bright red",
}
local RARITY_MATERIAL = {
	Scrap = Enum.Material.SmoothPlastic,
	Common = Enum.Material.SmoothPlastic,
	Good = Enum.Material.Neon,
	Rare = Enum.Material.Neon,
	Epic = Enum.Material.Neon,
	Mythic = Enum.Material.Neon,
	Relic = Enum.Material.Neon,
}

-- Server-only. { [player] = { [findSpotId] = { part, grade, tier, zone, spawnTime } } }
-- The Grade is deliberately NOT a Part attribute -- GDD §12.3 (and CLAUDE.md's
-- server-authoritative rule) says the Grade roll must never reach the
-- client, and any Attribute on a Workspace Part replicates to everyone. The
-- Part's public attributes only ever carry OwnerId/Rarity/Zone/SpawnTime/
-- Active, matching what a player is meant to see before digging.
local activeFindsByPlayer = {}
local findsFolder
local nextFindSpotId = 0

local function countFinds(finds)
	local count = 0
	for _ in pairs(finds) do
		count += 1
	end
	return count
end

-- Picks a random point within `range` studs of the player and raycasts
-- straight down to find the ground. Returns nil (skip this cycle) if nothing
-- solid is found, e.g. the roll landed over a gap.
local function findGroundPosition(center, range, character)
	local angle = math.random() * 2 * math.pi
	local distance = math.random() * range
	local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	local origin = center + offset + Vector3.new(0, 20, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = Workspace:Raycast(origin, Vector3.new(0, -50, 0), raycastParams)
	return result and result.Position
end

-- §2.3's placeholder reveal sequence. Server-driven TweenService/Instance
-- properties replicate to every nearby client on their own -- no remote or
-- client script needed for a one-shot effect like this.
local function playRevealVFX(part, tier)
	local color = BrickColor.new(RARITY_COLOR_NAME[tier]).Color
	local billboard = part:FindFirstChildOfClass("BillboardGui")
	local label = billboard and billboard:FindFirstChildOfClass("TextLabel")

	local targetSize = part.Size
	part.Size = Vector3.new(0.01, 0.01, 0.01)
	TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = targetSize }):Play()

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(1.0)
	emitter.Speed = NumberRange.new(8, 12)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Rate = 0 -- burst-only via Emit(), not a continuous stream
	emitter.Parent = part
	emitter:Emit(20)
	task.delay(1.1, function()
		if emitter.Parent then
			emitter:Destroy()
		end
	end)

	task.delay(0.3, function()
		if not part.Parent then
			return
		end

		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Brightness = 2
		light.Parent = part

		task.spawn(function()
			while part.Parent and light.Parent do
				local upTween = TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 4 })
				upTween:Play()
				upTween.Completed:Wait()
				if not (part.Parent and light.Parent) then
					break
				end
				local downTween = TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 2 })
				downTween:Play()
				downTween.Completed:Wait()
			end
		end)
	end)

	task.delay(1.5, function()
		if billboard and label then
			billboard.Enabled = true
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end
	end)
end

local function createFindSpotPart(position, tier)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = FIND_SIZE
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.BrickColor = BrickColor.new(RARITY_COLOR_NAME[tier])
	part.Material = RARITY_MATERIAL[tier]
	part.Parent = findsFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RarityLabel"
	billboard.Size = UDim2.fromOffset(150, 40)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 40
	billboard.AlwaysOnTop = true
	billboard.Enabled = false -- fades in at the end of playRevealVFX
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = BrickColor.new(RARITY_COLOR_NAME[tier]).Color
	label.TextTransparency = 1 -- tweened to 0 by playRevealVFX
	label.TextStrokeTransparency = 0.5
	label.Text = tier
	label.Parent = billboard

	return part
end

local function spawnFindSpot(player, zoneNumber, position, grade, tier)
	nextFindSpotId += 1
	local findSpotId = tostring(nextFindSpotId)

	local part = createFindSpotPart(position, tier)
	part.Name = "FindSpot_" .. findSpotId

	part:SetAttribute("OwnerId", player.UserId)
	part:SetAttribute("Rarity", tier)
	part:SetAttribute("Zone", zoneNumber)
	part:SetAttribute("SpawnTime", os.time())
	part:SetAttribute("Active", true)
	part:SetAttribute("FindSpotId", findSpotId)

	-- dig-minigame-spec.md §3.1: the left-click commit trigger. MinigameService
	-- listens for these rather than DetectorService owning the click logic
	-- itself -- spawning/despawning finds and reacting to a commit are
	-- separate concerns.
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = Config.COMMIT_TRIGGER_RANGE
	clickDetector.Parent = part

	playRevealVFX(part, tier)

	activeFindsByPlayer[player] = activeFindsByPlayer[player] or {}
	activeFindsByPlayer[player][findSpotId] = {
		part = part,
		grade = grade,
		tier = tier,
		zone = zoneNumber,
		spawnTime = os.time(),
	}
end

local function tryScanForPlayer(player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local zoneNumber = DigService.GetPlayerZone(player, profile)
	if not zoneNumber then
		return -- not standing in a zone the player has unlocked
	end

	local playerFinds = activeFindsByPlayer[player]
	if playerFinds and countFinds(playerFinds) >= Config.MAX_ACTIVE_FINDS then
		return
	end

	if math.random() > Config.SCAN_BASE_CHANCE then
		return -- scan came up empty this cycle
	end

	local detectorTier = Config.DETECTOR_TIERS[profile.Data.equippedDetectorTier]
	if not detectorTier then
		return
	end

	local position = findGroundPosition(rootPart.Position, detectorTier.range, character)
	if not position then
		return -- nothing solid under the roll, try again next cycle
	end

	-- §1.2: effectiveLuck = (baseLuck + shardLuck + milestoneLuck) * detectorLuckMultiplier,
	-- capped at LUCK_CAP. profile.Data.luckBonus already sums the non-detector
	-- sources (shards, milestones, Lucky Charm) via UpgradeService.RecalculateLuck.
	local effectiveLuck = math.min(profile.Data.luckBonus * detectorTier.luck, Config.LUCK_CAP)

	local grade = LumpService.RollGradeWithLuck(zoneNumber, effectiveLuck)
	local tier = RevealService.RollTier(grade)

	spawnFindSpot(player, zoneNumber, position, grade, tier)
end

local function removeExpiredFinds()
	local now = os.time()
	for _, finds in pairs(activeFindsByPlayer) do
		for findSpotId, find in pairs(finds) do
			if now - find.spawnTime > Config.FIND_DESPAWN_TIME then
				find.part:Destroy()
				finds[findSpotId] = nil
			end
		end
	end
end

local function clearFindsForPlayer(player)
	local finds = activeFindsByPlayer[player]
	if not finds then
		return
	end

	for _, find in pairs(finds) do
		find.part:Destroy()
	end
	activeFindsByPlayer[player] = nil
end

-- Returns the server-only { part, grade, tier, zone, spawnTime } for a find
-- this player owns, or nil if it doesn't exist (expired, already claimed, or
-- never existed). MinigameService uses this to get the Grade for the reveal
-- roll -- Grade itself never left this table, so this is also the only way
-- to reach it.
function DetectorService.GetFindData(player, findSpotId)
	local finds = activeFindsByPlayer[player]
	return finds and finds[findSpotId]
end

-- Hands ownership of a find's lifecycle to whoever just claimed it (the
-- minigame) -- removes it from this service's own bookkeeping (the despawn
-- sweep, the MAX_ACTIVE_FINDS count) without touching the Part itself, since
-- the minigame still needs it visible on screen until it wins or fails.
function DetectorService.ReleaseFind(player, findSpotId)
	local finds = activeFindsByPlayer[player]
	if finds then
		finds[findSpotId] = nil
	end
end

function DetectorService.Init()
	findsFolder = Instance.new("Folder")
	findsFolder.Name = "FindSpots"
	findsFolder.Parent = Workspace

	task.spawn(function()
		while true do
			task.wait(Config.SCAN_INTERVAL)

			for _, player in ipairs(Players:GetPlayers()) do
				tryScanForPlayer(player)
			end
			removeExpiredFinds()
		end
	end)

	Players.PlayerRemoving:Connect(clearFindsForPlayer)
end

return DetectorService
