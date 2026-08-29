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
-- GDD §10.1: the Scanner gamepass adds a 4th independent hint draw.
local HINT_TYPES_WITH_SCANNER = { "Weight", "Temperature", "Sheen", "Texture" }

-- GDD §5.3. Scanner extends the hint score range from 0-6 to 0-8, and the
-- bucket boundaries shift accordingly (GDD §10.1) -- a lump's bucket table
-- depends on how many hints it actually has, tracked via lump.hasScanner.
local BUCKET_BY_HINT_SCORE_3 = { [0] = "LOW", [1] = "LOW", [2] = "MID", [3] = "MID", [4] = "MID", [5] = "HIGH", [6] = "HIGH" }
local BUCKET_BY_HINT_SCORE_4 = {
	[0] = "LOW", [1] = "LOW", [2] = "LOW",
	[3] = "MID", [4] = "MID", [5] = "MID",
	[6] = "HIGH", [7] = "HIGH", [8] = "HIGH",
}

local LUMP_SIZE = Vector3.new(1.5, 1.5, 1.5)
local LUMP_COLOR = Color3.fromRGB(120, 120, 120)

local LumpService = {}

-- Session-only. { [player] = { [lumpId] = { lumpId, grade, zone, hints, hintScore, part } } }
-- Keyed by lumpId (not a plain array) so the Excavator's 2-lumps-per-dig can
-- hold two lumps at once and either one can be sold/opened independently.
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

-- Also pure — three (or four, with Scanner) independent Low/Mid/High draws
-- from the grade's row in HintTable, mapped to display words. Returns the
-- hints and their sum (0-6, or 0-8 with Scanner).
function LumpService.GenerateHints(grade, hasScanner)
	local distribution = HintTable[grade]
	local hintTypes = hasScanner and HINT_TYPES_WITH_SCANNER or HINT_TYPES
	local hints = {}
	local hintScore = 0

	for _, hintType in ipairs(hintTypes) do
		local level = rollFromCumulative(math.random(), HINT_LEVEL_ORDER, distribution, 1)
		hints[hintType] = HintTable.Labels[hintType][level]
		hintScore += HINT_LEVEL_SCORE[level]
	end

	return hints, hintScore
end

-- GDD §5.3: blindPrice = round(BLIND_RATIO * BucketEV[zone][bucket]). Pure
-- function of the lump's own zone/hintScore/hasScanner — no player/profile lookup.
function LumpService.GetBlindOffer(lump)
	local bucketTable = lump.hasScanner and BUCKET_BY_HINT_SCORE_4 or BUCKET_BY_HINT_SCORE_3
	local bucket = bucketTable[lump.hintScore]
	local bucketEV = BucketEV[lump.zone][bucket]
	return math.round(Config.BLIND_RATIO * bucketEV)
end

function LumpService.GetActiveLumpCount(player)
	local lumps = activeLumps[player]
	if not lumps then
		return 0
	end

	local count = 0
	for _ in pairs(lumps) do
		count += 1
	end
	return count
end

function LumpService.GetActiveLump(player, lumpId)
	local lumps = activeLumps[player]
	return lumps and lumps[lumpId]
end

-- Shared by CreateLump and CreateGoldenLump. Spawns the physical lump welded
-- to the player's hand and registers it. Returns nil if the character isn't
-- ready. handOffset nudges the second lump in an Excavator's double-dig so
-- the two don't render on top of each other.
local function spawnLump(player, zoneNumber, grade, hints, hintScore, isGolden, handOffset, hasScanner)
	local character = player.Character
	local handPart = character and getHandAttachPart(character)
	if not handPart then
		return nil
	end

	nextLumpId += 1
	local lumpId = tostring(nextLumpId)

	-- Named uniquely per lump (not just "Lump") so the client can reliably
	-- WaitForChild() for its own lump by name instead of racing replication
	-- with a raw Instance argument over a RemoteEvent.
	local part = Instance.new("Part")
	part.Name = "Lump_" .. lumpId
	part.Size = LUMP_SIZE
	part.Color = isGolden and Color3.fromRGB(255, 215, 0) or LUMP_COLOR
	part.Material = isGolden and Enum.Material.Neon or Enum.Material.Slate
	part.CanCollide = false
	part.CFrame = handPart.CFrame * CFrame.new((handOffset or 0) * 2, -1, 0)
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
		isGolden = isGolden,
		hasScanner = hasScanner or false,
		part = part,
	}

	activeLumps[player] = activeLumps[player] or {}
	activeLumps[player][lumpId] = lump

	return lump
end

-- Rolls a grade, generates its hints, and spawns the physical lump welded to
-- the player's hand.
function LumpService.CreateLump(player, zoneNumber, handOffset)
	local profile = PlayerDataService.GetProfile(player)
	local hasScanner = profile ~= nil and profile.Data.passes.scanner

	local grade = LumpService.RollGrade(player, zoneNumber)
	local hints, hintScore = LumpService.GenerateHints(grade, hasScanner)
	return spawnLump(player, zoneNumber, grade, hints, hintScore, false, handOffset, hasScanner)
end

-- GDD §9.2: the Daily Golden Lump is always Charged, and its hints are always
-- forced all-High -- the player is meant to know it's special, not have to
-- read it. The actual reroll-until-Rare-or-better guarantee happens at open
-- time (DailyService.RollGoldenTier), not here.
local GOLDEN_HINTS_3 = { Weight = "Heavy", Temperature = "Hot", Sheen = "Shimmering" }
local GOLDEN_HINTS_4 = { Weight = "Heavy", Temperature = "Hot", Sheen = "Shimmering", Texture = "Polished" }
-- All-High hint scores, derived rather than hardcoded so they can't drift
-- from HINT_LEVEL_SCORE.High if that mapping ever changes.
local GOLDEN_HINT_SCORE_3 = #HINT_TYPES * HINT_LEVEL_SCORE.High
local GOLDEN_HINT_SCORE_4 = #HINT_TYPES_WITH_SCANNER * HINT_LEVEL_SCORE.High

function LumpService.CreateGoldenLump(player, zoneNumber)
	local profile = PlayerDataService.GetProfile(player)
	local hasScanner = profile ~= nil and profile.Data.passes.scanner

	if hasScanner then
		return spawnLump(player, zoneNumber, "Charged", GOLDEN_HINTS_4, GOLDEN_HINT_SCORE_4, true, 0, true)
	end
	return spawnLump(player, zoneNumber, "Charged", GOLDEN_HINTS_3, GOLDEN_HINT_SCORE_3, true, 0, false)
end

function LumpService.ClearLump(player, lumpId)
	local lumps = activeLumps[player]
	if not lumps then
		return
	end

	local lump = lumps[lumpId]
	if lump then
		lump.part:Destroy()
		lumps[lumpId] = nil
	end
end

function LumpService.ClearAllLumps(player)
	local lumps = activeLumps[player]
	if not lumps then
		return
	end

	for _, lump in pairs(lumps) do
		lump.part:Destroy()
	end
	activeLumps[player] = nil
end

-- No setup needed — DigService calls into this module directly.
function LumpService.Init() end

return LumpService
