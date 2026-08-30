local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)
local ZoneTable = require(ReplicatedStorage.Modules.ZoneTable)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local DetectorService = require(ServerScriptService.Services.DetectorService)
local RateLimiter = require(ServerScriptService.Services.RateLimiter)
local RevealService = require(ServerScriptService.Services.RevealService)
local LeaderboardService = require(ServerScriptService.Services.LeaderboardService)
local AnnounceService = require(ServerScriptService.Services.AnnounceService)

-- dig-minigame-spec.md Steps 5-6: the commit trigger and the click-to-fill
-- bar. Fully validated server-side (§3.1, §4.2) -- the client's own bar is a
-- preview only.
local MinigameService = {}

-- [player] = { findSpotId, part, tier, zone, decayPerSecond, fillPerClick,
--   barValue, lastUpdateTime, clickTimestamps }
-- Grade is deliberately not duplicated in here -- it stayed in
-- DetectorService's table and is no longer needed once Tier is already
-- decided (that happened back at spawn, per the confirmed spawn-time roll).
local activeMinigames = {}

function MinigameService.IsInMinigame(player)
	return activeMinigames[player] ~= nil
end

-- Reactive rather than a running per-player loop: decay is only ever
-- "settled" (applied for the elapsed real time) when something actually
-- happens -- a click, or a success/fail attempt. A legitimate client already
-- fires RequestMinigameFail the instant its own local bar hits zero, so the
-- server never needs to notice that on its own.
local function settleBarValue(minigame)
	local now = os.clock()
	local elapsed = now - minigame.lastUpdateTime
	minigame.barValue = math.clamp(minigame.barValue - minigame.decayPerSecond * elapsed, 0, 1)
	minigame.lastUpdateTime = now
end

local function endMinigame(player, minigame)
	if minigame.part then
		minigame.part:Destroy() -- plain removal for now; §4.4/§4.5's animated shrink/sink is Step 8
	end
	activeMinigames[player] = nil
end

local function onFindSpotClicked(player, part)
	if MinigameService.IsInMinigame(player) then
		return -- one minigame at a time
	end

	if part:GetAttribute("OwnerId") ~= player.UserId then
		return -- not this player's find -- no stealing
	end

	if not part:GetAttribute("Active") then
		return -- already claimed or expired
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	-- ClickDetector's own MaxActivationDistance already gates this client-side,
	-- but §3.1 calls the range check out explicitly as a server validation.
	if (rootPart.Position - part.Position).Magnitude > Config.COMMIT_TRIGGER_RANGE then
		return
	end

	local findSpotId = tostring(part:GetAttribute("FindSpotId"))
	local findData = DetectorService.GetFindData(player, findSpotId)
	if not findData then
		return -- never trust a client-reachable Part's attributes alone
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	part:SetAttribute("Active", false) -- prevents double-triggering

	local shovelInfo = Config.SHOVEL_TIERS[profile.Data.equippedShovelTier]
	local decayPerSecond = Config.SHOVEL_DECAY_BASE * Config.RARITY_DIFFICULTY[findData.tier] * (1 - (shovelInfo.power * Config.POWER_DECAY_SCALE))
	local fillPerClick = Config.CLICK_FILL_BASE + (shovelInfo.power * Config.POWER_FILL_SCALE)

	activeMinigames[player] = {
		findSpotId = findSpotId,
		part = part,
		tier = findData.tier,
		zone = findData.zone,
		decayPerSecond = decayPerSecond,
		fillPerClick = fillPerClick,
		barValue = Config.BAR_START_VALUE,
		lastUpdateTime = os.clock(),
		clickTimestamps = {},
	}

	-- Ownership of this find's lifecycle transfers to the minigame now -- the
	-- despawn sweep and MAX_ACTIVE_FINDS count shouldn't touch it anymore.
	DetectorService.ReleaseFind(player, findSpotId)

	-- §3.1/§7 payload, minus Grade -- GDD §12.3 says the Grade roll must
	-- never reach the client, and this is a plain RemoteEvent argument.
	ReplicatedStorage.Remotes.MinigameStart:FireClient(player, {
		rarity = findData.tier,
		zone = findData.zone,
		findSpotId = findSpotId,
		decayPerSecond = decayPerSecond,
		fillPerClick = fillPerClick,
	})
end

local function onRequestMinigameClick(player, findSpotId)
	if not RateLimiter.Allow(player, "RequestMinigameClick") then
		return
	end

	local minigame = activeMinigames[player]
	if not minigame or minigame.findSpotId ~= findSpotId then
		return
	end

	-- §4.2/§8: MAX_CLICK_RATE is a distinct, design-tunable cap on top of the
	-- generic per-remote RateLimiter above -- excess clicks are silently
	-- ignored, not an error.
	local now = os.clock()
	local timestamps = minigame.clickTimestamps
	local i = 1
	while i <= #timestamps do
		if now - timestamps[i] > 1 then
			table.remove(timestamps, i)
		else
			i += 1
		end
	end
	if #timestamps >= Config.MAX_CLICK_RATE then
		return
	end
	table.insert(timestamps, now)

	settleBarValue(minigame)
	minigame.barValue = math.clamp(minigame.barValue + minigame.fillPerClick, 0, 1)
end

-- §7: "Fires existing reveal flow, returns RevealResult" -- this reuses
-- RevealService/EconomyService/LeaderboardService/AnnounceService exactly as
-- DigService's own onRequestOpen does, since Tier was already decided back
-- when the find spot spawned (no re-roll here, matching the confirmed fix).
local function grantWin(player, profile, minigame)
	local itemId, item = RevealService.PickItem(minigame.tier, minigame.zone)
	local isNew = RevealService.ProcessReveal(player, profile, minigame.tier, itemId, item)

	table.insert(profile.Data.inventory, {
		itemId = itemId,
		value = item.value,
		rolledAt = os.time(),
	})
	local inventoryIndex = #profile.Data.inventory
	ReplicatedStorage.Remotes.MyInventoryUpdated:FireClient(player, profile.Data.inventory)

	LeaderboardService.RecordFind(player, profile, item.name, item.value)
	AnnounceService.Announce(player, minigame.tier, item.name, item.value, ZoneTable[minigame.zone].name)

	ReplicatedStorage.Remotes.RevealResult:FireClient(player, itemId, minigame.tier, item.value, isNew, inventoryIndex)
end

-- §4.4: the client's win VFX (particle fountain, sound, camera zoom, the
-- find spot shrinking) plays out over ~0.5s before "the existing reveal flow"
-- fires -- so MinigameWin goes out immediately, but the actual item grant
-- (and destroying the part the client is still animating) waits for that
-- window. activeMinigames stays populated the whole time, correctly blocking
-- a second minigame from starting mid-sequence.
local function onRequestMinigameSuccess(player, findSpotId)
	local minigame = activeMinigames[player]
	if not minigame or minigame.findSpotId ~= findSpotId then
		return
	end

	settleBarValue(minigame)
	if minigame.barValue < Config.SUCCESS_THRESHOLD then
		return -- silently rejected, matching every other made-up/invalid claim in this codebase
	end

	ReplicatedStorage.Remotes.MinigameWin:FireClient(player, { rarity = minigame.tier, findSpotId = minigame.findSpotId })

	task.delay(0.5, function()
		local profile = PlayerDataService.GetProfile(player)
		if profile then
			grantWin(player, profile, minigame)
		end
		endMinigame(player, minigame)
	end)
end

-- §4.5: same idea -- FailConfirmed fires immediately so the client can start
-- its fail sequence (bar shake, red flash, slide-down) against a part that
-- still exists, and the server only removes it once that sequence has had
-- time to play (0.3s to start the sink/fade + 0.4s to finish it).
local function onRequestMinigameFail(player, findSpotId)
	local minigame = activeMinigames[player]
	if not minigame or minigame.findSpotId ~= findSpotId then
		return
	end

	settleBarValue(minigame)
	if minigame.barValue > Config.FAIL_THRESHOLD then
		return
	end

	ReplicatedStorage.Remotes.FailConfirmed:FireClient(player)

	task.delay(0.7, function()
		endMinigame(player, minigame)
	end)
end

local function hookFindSpot(part)
	local clickDetector = part:WaitForChild("ClickDetector", 5)
	if not clickDetector then
		return
	end

	clickDetector.MouseClick:Connect(function(player)
		onFindSpotClicked(player, part)
	end)
end

function MinigameService.Init()
	local findsFolder = Workspace:WaitForChild("FindSpots")

	for _, part in ipairs(findsFolder:GetChildren()) do
		hookFindSpot(part)
	end
	findsFolder.ChildAdded:Connect(hookFindSpot)

	local remotes = ReplicatedStorage.Remotes
	remotes.RequestMinigameClick.OnServerEvent:Connect(onRequestMinigameClick)
	remotes.RequestMinigameSuccess.OnServerEvent:Connect(onRequestMinigameSuccess)
	remotes.RequestMinigameFail.OnServerEvent:Connect(onRequestMinigameFail)

	Players.PlayerRemoving:Connect(function(player)
		activeMinigames[player] = nil
	end)
end

return MinigameService
