local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BucketEV = require(ReplicatedStorage.Modules.BucketEV)
local Config = require(ReplicatedStorage.Modules.Config)
local GradeTable = require(ReplicatedStorage.Modules.GradeTable)
local HintTable = require(ReplicatedStorage.Modules.HintTable)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- Fixed iteration order for cumulative rolls. GradeTable/ZoneTable.gradeMix are
-- plain tables (pairs() order isn't guaranteed), but cumulative bucket
-- boundaries must be built in a stable order every time.
local GRADE_ORDER = { "Dud", "Plain", "Promising", "Charged" }
local HINT_LEVEL_ORDER = { "Low", "Mid", "High" }
local HINT_LEVEL_SCORE = { Low = 0, Mid = 1, High = 2 }
local HINT_TYPES = { "Weight", "Temperature", "Sheen" }

-- GDD §5.3
local BUCKET_BY_HINT_SCORE = { [0] = "LOW", [1] = "LOW", [2] = "MID", [3] = "MID", [4] = "MID", [5] = "HIGH", [6] = "HIGH" }

local LUMP_SIZE = Vector3.new(1.5, 1.5, 1.5)
local LUMP_COLOR = Color3.fromRGB(120, 120, 120)

local LumpService = {}

-- Session-only. { [player] = { lumpId, grade, zone, hints, hintScore, part } }
local activeLumps = {}
local nextLumpId = 0

local function getHandAttachPart(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

-- Picks the first key (in orderedKeys order) whose cumulative share of
-- totalWeight exceeds u. Falls back to the last key so float rounding on a
-- weight sum of e.g. 0.9999999 can never return nil.
local function rollFromCumulative(u, orderedKeys, weights, totalWeight)
	local cumulative = 0
	for _, key in ipairs(orderedKeys) do
		cumulative += weights[key] / totalWeight
		if u < cumulative then
			return key
		end
	end
	return orderedKeys[#orderedKeys]
end

-- Pure math, no player/profile lookup — this is what the exit-criteria
-- statistical tests (10,000 rolls at a fixed L) call directly.
function LumpService.RollGradeWithLuck(zoneNumber, luck)
	local zone = ZoneTable[zoneNumber]
	local clampedLuck = math.min(luck, Config.LUCK_CAP)

	local u = math.random()
	local uPrime = u ^ (1 / (1 + clampedLuck)) -- GDD §4.8 step 2: raises u toward 1, biasing toward better grades

	return rollFromCumulative(uPrime, GRADE_ORDER, zone.gradeMix, 100)
end

function LumpService.RollGrade(player, zoneNumber)
	local profile = PlayerDataService.GetProfile(player)
	local luck = profile and profile.Data.luckBonus or 0
	return LumpService.RollGradeWithLuck(zoneNumber, luck)
end

-- Also pure — three independent Low/Mid/High draws from the grade's row in
-- HintTable, mapped to display words. Returns the hints and their sum (0-6).
function LumpService.GenerateHints(grade)
	local distribution = HintTable[grade]
	local hints = {}
	local hintScore = 0

	for _, hintType in ipairs(HINT_TYPES) do
		local level = rollFromCumulative(math.random(), HINT_LEVEL_ORDER, distribution, 1)
		hints[hintType] = HintTable.Labels[hintType][level]
		hintScore += HINT_LEVEL_SCORE[level]
	end

	return hints, hintScore
end

-- GDD §5.3: blindPrice = round(BLIND_RATIO * BucketEV[zone][bucket]). Pure
-- function of the lump's own zone/hintScore — no player/profile lookup.
function LumpService.GetBlindOffer(lump)
	local bucket = BUCKET_BY_HINT_SCORE[lump.hintScore]
	local bucketEV = BucketEV[lump.zone][bucket]
	return math.round(Config.BLIND_RATIO * bucketEV)
end

function LumpService.HasActiveLump(player)
	return activeLumps[player] ~= nil
end

function LumpService.GetActiveLump(player)
	return activeLumps[player]
end

-- Rolls a grade, generates its hints, and spawns the physical lump welded to
-- the player's hand. Returns nil if the character isn't ready.
function LumpService.CreateLump(player, zoneNumber)
	local character = player.Character
	local handPart = character and getHandAttachPart(character)
	if not handPart then
		return nil
	end

	local grade = LumpService.RollGrade(player, zoneNumber)
	local hints, hintScore = LumpService.GenerateHints(grade)

	nextLumpId += 1
	local lumpId = tostring(nextLumpId)

	-- Named uniquely per lump (not just "Lump") so the client can reliably
	-- WaitForChild() for its own lump by name instead of racing replication
	-- with a raw Instance argument over a RemoteEvent.
	local part = Instance.new("Part")
	part.Name = "Lump_" .. lumpId
	part.Size = LUMP_SIZE
	part.Color = LUMP_COLOR
	part.Material = Enum.Material.Slate
	part.CanCollide = false
	part.CFrame = handPart.CFrame * CFrame.new(0, -1, 0)
	part.Parent = Workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = handPart
	weld.Parent = part

	local lump = {
		lumpId = lumpId,
		grade = grade,
		zone = zoneNumber,
		hints = hints,
		hintScore = hintScore,
		part = part,
	}
	activeLumps[player] = lump

	return lump
end

function LumpService.ClearLump(player)
	local lump = activeLumps[player]
	if lump then
		lump.part:Destroy()
	end
	activeLumps[player] = nil
end

-- No setup needed — DigService calls into this module directly.
function LumpService.Init() end

return LumpService
